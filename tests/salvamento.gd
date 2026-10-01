extends SceneTree
## Confere o SAVE do vale (#7): as vagas, a partida que zera, a ida e a volta
## do que o vale guarda, e que nenhum estado do 3D escapa da conta.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/salvamento.gd
##
## O `Salvamento` é o do 2D, e o `testar_salvamento`/`testar_slots` de lá
## seguram a regra dele: escrita atômica, migração, limpeza. Este portão
## pergunta o que só o vale responde:
##
##   1. PARTIDA NOVA NÃO HERDA A ANTERIOR: `Partida.comecar` volta todos os
##      sistemas ao retrato de fábrica, e escolhe a vaga.
##   2. SEM VAGA NÃO SE SALVA — o EXPLORAR não grava nada.
##   3. FECHAR E REABRIR DEVOLVE O ESSENCIAL: a mochila, a vida, o dia, a HORA
##      (que no vale é do `Dia`, e não do `Relogio`), onde o jogador estava, o
##      passo do Pedro, e o bicho que caiu e ainda não voltou.
##   4. A QUEDA SALVA, como o dormir do 2D: a vaga guarda o dia novo.
##   5. O VALE QUE SAI DA ÁRVORE SAI DO SAVE: o `Salvamento` não fica
##      segurando a referência a um mundo liberado. Hoje isso não quebra —
##      o Godot compara o objeto morto igual a null —, e o portão existe para
##      o save não depender dessa comparação.
##   6. NENHUM ESTADO DO 3D ESCAPA: todo campo público dos autoloads que só o
##      vale tem está guardado pelo mundo ou declarado fora do save, com a
##      razão escrita. É a regra do 2D (`O_QUE_GUARDAR` ou `FORA_DO_SAVE`)
##      estendida ao que o 2D não tem.
##
## OS SAVES DE VERDADE NÃO SÃO TOCADOS. O portão os move para uma pasta de
## reserva no começo e os devolve no fim; se uma rodada anterior parou no
## meio, a primeira coisa que ele faz é devolver a reserva que ficou.

const RESERVA := "user://reserva_do_teste_de_salvamento"

## O que do 3D entra no save pela mão do vale (`estado_para_salvar`), com a
## MESMA chave lá. `horas_decorridas` é a conta que não volta a zero à
## meia-noite, e é por ela que o coqueiro cortado sabe quando voltar (ver
## arvores_info.gd): sem ela no save, o prazo guardado apontaria para longe.
const DO_MUNDO := {
	"Dia": ["hora", "horas_decorridas"],
	# O CADERNO DO VALE não é guardado campo a campo: o `estado()` dele devolve
	# os três de uma vez e o `restaurar()` os põe de volta, porque `ativas` é
	# lista de dicionários e o alvo de cada missão é um Vector3 — coisa que o
	# save escreve como array de três números e tem de voltar como Vector3.
	# Guardar campo a campo aqui seria refazer essa conversão do lado errado.
	"CadernoDoVale": ["ativas", "cumpridas", "em_foco"],
}

## O que do 3D fica FORA do save, campo a campo, com a razão.
const FORA_DO_SAVE := {
	"Dia": {
		"velocidade": "preferência do AJUSTAR (a velocidade do tempo), não da partida",
		"hora_inicial": "preferência do AJUSTAR: a hora em que uma partida NOVA começa",
		"pausado": "estado de tela: o relógio pausado pelo botão do HUD ou pelos ajustes",
		"pausa_no_jogo": "preferência do AJUSTAR: se o relógio pode ser pausado no jogo",
		"congelado_na_carga": "estado da tela de carregamento, que dura segundos",
		"latitude": "o lugar do vale no globo, para a curva do sol; não muda com a partida",
	},
	# A MOCHILA É TELA, e o que ela mostra mora no `Inventario`.
	#
	# Ela é arquivo compartilhado com o 2D e mora em `scripts/ui/`, fora de
	# `scripts/compartilhado/` — então o pulo por caminho lá embaixo não a
	# alcança, e é bom que não alcance: conferi, e o `testar_salvamento.gd` do
	# 2D NÃO a cobre. Aquele portão só percorre os autoloads que estão em
	# `O_QUE_GUARDAR` ou em `SALVOS_A_MAO`, e a mochila não está em nenhum dos
	# dois. Este aqui percorre TODOS, e por isso é ele que faz a pergunta.
	"Mochila": {
		"aberta": "estado de tela aberta, não de partida: carregar com ela salva abriria a mochila por cima do vale recém-carregado",
		"abrir_documento": "é a PERGUNTA sobre a interface, não estado de partida — mesma costura de `Vida.esta_lendo`: quem responde é o projeto, e salvar um Callable seria salvar um pedaço de código de uma execução para outra",
		"alguem_fala": "idem: quem responde é o projeto. No 2D é o `Dialogo`, pelo `Telas._ready`; no vale ninguém responde, e Callable inválido vale por 'ninguém fala'",
	},
}

## Autoloads do 3D que não guardam partida nenhuma, com a razão.
const SEM_PARTIDA := {
	"Audio": "volumes e opções de som do AJUSTAR, com arquivo de configuração próprio",
	"Estilo": "o estilo visual escolhido no AJUSTAR, com arquivo de configuração próprio",
	"Mare": "o modo da maré escolhido no AJUSTAR",
	"Versao": "a versão do jogo, lida do historico_3d.json",
	"Lugares": "tradutor de nome de lugar em ponto do vale; não guarda estado",
	"Partida": "o retrato de fábrica, tirado de novo toda vez que o jogo abre",
}

var falhas := 0
var salvamento
var partida
var inventario
var vida
var relogio
var dia
var regra


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("SALVAMENTO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	salvamento = root.get_node("/root/Salvamento")
	partida = root.get_node_or_null("/root/Partida")
	inventario = root.get_node("/root/Inventario")
	vida = root.get_node("/root/Vida")
	relogio = root.get_node("/root/Relogio")
	dia = root.get_node("/root/Dia")
	regra = root.get_node("/root/Luta")
	_conferir(partida != null, "o autoload Partida não subiu")
	if partida == null:
		_fechar()
		return
	_devolver_reserva_esquecida()
	_guardar_os_saves_de_verdade()

	# --- 1. PARTIDA NOVA NÃO HERDA A ANTERIOR ----------------------------------
	_conferir(not partida.fabrica.is_empty(), "o retrato de fábrica está vazio")
	var dia_de_fabrica: int = int(partida.fabrica["Relogio"]["dia"])
	inventario.adicionar("facao")
	vida.ferir(5.0)
	relogio.dia = dia_de_fabrica + 8
	regra.aprender("ginga")
	partida.comecar(1, true)
	_conferir(inventario.quantidade("facao") == 0, "a partida nova herdou o facão da anterior")
	_conferir(vida.atual == vida.maximo(), "a partida nova herdou a vida da anterior")
	_conferir(relogio.dia == dia_de_fabrica, "a partida nova herdou o dia %d da anterior" % relogio.dia)
	_conferir(not regra.sabe("ginga"), "a partida nova herdou a ginga da anterior")
	_conferir(salvamento.slot_atual == 1, "começar na vaga 1 não escolheu a vaga 1")

	# --- 2. SEM VAGA NÃO SE SALVA ----------------------------------------------
	partida.comecar(0)
	_conferir(not partida.salvar(), "sem vaga, a partida salvou")
	for slot in range(1, salvamento.QUANTOS_SLOTS + 1):
		_conferir(not salvamento.existe_partida(slot), "sem vaga, apareceu arquivo na vaga %d" % slot)

	# --- 3. FECHAR E REABRIR DEVOLVE O ESSENCIAL -------------------------------
	partida.comecar(1, true)
	var vale = await _abrir_o_vale()
	if vale == null:
		_fechar()
		return
	var player = vale.player
	var world = vale.world
	var luta = vale.get_node_or_null("Luta")
	var igreja: Vector3 = world.ground_position(root.get_node("/root/Lugares").ponto("igreja"), 0.07)
	player.global_position = igreja
	player.visual.rotation.y = 1.25
	inventario.adicionar("facao")
	vida.ferir(6.0)
	regra.aprender("ginga")
	relogio.dormir()
	dia.definir_hora(15.5)
	var dia_salvo: int = relogio.dia_absoluto()
	if vale.pedro != null:
		vale.pedro.missao = 2
		vale.pedro.set("_iniciado", true)
	var caititu = luta.criaturas[0] if luta != null and not luta.criaturas.is_empty() else null
	_conferir(caititu != null, "o vale não tem o caititu para cair")
	if caititu != null:
		caititu.ferir(9999.0)
	await _frames(2)
	# O que DO_MUNDO diz que o vale guarda, o vale guarda de fato, com a mesma
	# chave: declaração que ninguém confere é declaração que mente.
	#
	# A CHAVE PODE ESTAR UM NÍVEL ABAIXO, e o caderno de missões é o caso. Ele
	# não entra campo a campo no estado do vale: `CadernoDoVale.estado()` devolve
	# os três de uma vez sob a chave "caderno", porque `ativas` é lista de
	# dicionários e o alvo de cada missão é um Vector3 — coisa que o save escreve
	# como três números e que só ele sabe remontar. Espalhar os três no topo
	# poria a conversão do lado errado.
	#
	# Então a procura desce um nível: o campo vale se está no estado do vale OU
	# dentro de um dicionário dele. Mais fundo que isso não se procura — aninhar
	# sem limite seria a declaração deixando de significar alguma coisa.
	var do_vale: Dictionary = vale.estado_para_salvar()
	for nome in DO_MUNDO:
		for campo in DO_MUNDO[nome]:
			var achou: bool = do_vale.has(campo)
			if not achou:
				for chave in do_vale:
					var dentro = do_vale[chave]
					if dentro is Dictionary and (dentro as Dictionary).has(campo):
						achou = true
			_conferir(achou, "DO_MUNDO diz que o vale guarda %s.%s, e o estado_para_salvar não tem '%s' nem em grupo nenhum dele" % [nome, campo, campo])
	_conferir(partida.salvar(), "a vaga 1 não salvou")
	_conferir(salvamento.existe_partida(1), "salvou e não há arquivo na vaga 1")
	_conferir(int(salvamento.resumo(1).get("dia", 0)) == dia_salvo,
		"o resumo da vaga diz dia %s, e a partida estava no %d" % [str(salvamento.resumo(1).get("dia")), dia_salvo])

	# Fecha e reabre: o que a abertura faz ao continuar a vaga.
	partida.comecar(1, false)
	_conferir(inventario.quantidade("facao") == 0, "continuar não passou pela fábrica antes de carregar")
	vale = await _abrir_o_vale()
	if vale == null:
		_fechar()
		return
	player = vale.player
	luta = vale.get_node_or_null("Luta")

	# CONTINUAR NÃO REFAZ A FALA. O Pedro reanunciava o passo ao voltar, e quem
	# tivesse salvado no primeiro ouvia a abertura do jogo de novo — a partida
	# parecia ter recomeçado. O que volta é o OBJETIVO: o caderno e o marcador.
	# Escutado desde já, antes dos quadros que o reanúncio levava para sair.
	var falou_ao_voltar: Array[String] = []
	if vale.pedro != null and vale.pedro.has_signal("narrou"):
		vale.pedro.narrou.connect(func(texto: String) -> void: falou_ao_voltar.append(texto))
	await _frames(4)
	var longe: float = Vector2(player.global_position.x - igreja.x, player.global_position.z - igreja.z).length()
	_conferir(longe < 0.6, "o jogador voltou a %.1f u de onde estava" % longe)
	_conferir(absf(player.visual.rotation.y - 1.25) < 0.05, "o jogador voltou virado para outro lado")
	_conferir(absf(dia.hora - 15.5) < 0.3, "a hora voltou %s, e era 15h30: o Dia não recebeu a hora do save" % dia.texto_hora())
	_conferir(relogio.dia_absoluto() == dia_salvo, "o dia voltou %d, e era %d" % [relogio.dia_absoluto(), dia_salvo])
	_conferir(relogio.pausado, "depois de carregar, o calendário ficou solto do Dia")
	_conferir(inventario.quantidade("facao") == 1, "o facão não voltou na mochila")
	_conferir(is_equal_approx(vida.atual, vida.maximo() - 6.0), "a vida voltou %s" % str(vida.atual))
	_conferir(regra.sabe("ginga"), "a ginga aprendida não voltou")
	if vale.pedro != null:
		_conferir(vale.pedro.missao == 2, "o Pedro voltou no passo %d, e estava no 2" % vale.pedro.missao)
		# O ANÚNCIO VENCIA EM 1,4 s DE RELÓGIO, então a espera é de relógio e
		# com folga: contar quadros mediria outra coisa.
		var ate := Time.get_ticks_msec() + 2600
		while Time.get_ticks_msec() < ate:
			await process_frame
		_conferir(falou_ao_voltar.is_empty(),
			"ao continuar a partida o Pedro falou %d vez(es) — a primeira: '%s'"
				% [falou_ao_voltar.size(), falou_ao_voltar[0] if not falou_ao_voltar.is_empty() else ""])
		# E O OBJETIVO VOLTOU MESMO ASSIM: sem a fala, é o caderno que diz ao
		# jogador o que ele estava fazendo. Sem esta metade, calar o Pedro
		# passaria no portão deixando o jogador sem rumo nenhum.
		var caderno_do_vale = root.get_node_or_null("/root/CadernoDoVale")
		_conferir(caderno_do_vale != null and not caderno_do_vale.ativas.is_empty(),
			"continuar calou o Pedro e não deixou missão nenhuma aberta no caderno")
	if luta != null:
		await _frames(2)
		_conferir(luta.criaturas.is_empty(), "o caititu derrubado reapareceu ao reabrir")
		_conferir(luta.mortes.size() == 1, "a volta do caititu não foi guardada")

	# --- 4. A QUEDA SALVA ------------------------------------------------------
	var queda = vale.get_node_or_null("Queda")
	var acordou := [false]
	queda.acordou.connect(func(): acordou[0] = true)
	vida.ferir(9999.0)
	for i in range(600):
		if acordou[0]:
			break
		await process_frame
	_conferir(int(salvamento.resumo(1).get("dia", 0)) == dia_salvo + 1,
		"depois da queda a vaga diz dia %s, e o dia novo é %d" % [str(salvamento.resumo(1).get("dia")), dia_salvo + 1])

	# --- 5. O VALE QUE SAI DA ÁRVORE SAI DO SAVE -------------------------------
	var vazio := PackedScene.new()
	var no := Node.new()
	vazio.pack(no)
	no.free()
	change_scene_to_packed(vazio)
	await _frames(4)
	# No Godot 4.7 um objeto liberado compara IGUAL a null (e o `_mundo != null`
	# do Salvamento o pula, então hoje não quebra). Por isso a pergunta é pelo
	# TIPO: desregistrado de verdade é nulo, e não um objeto morto que por acaso
	# se parece com nulo.
	_conferir(typeof(salvamento.get("_mundo")) == TYPE_NIL, "o vale saiu e o Salvamento continua segurando a referência a ele")

	# --- 6. NENHUM ESTADO DO 3D ESCAPA -----------------------------------------
	_conferir_cobertura()

	# --- 7. AS VAGAS NA ABERTURA -----------------------------------------------
	await _conferir_as_vagas()

	_fechar()


## A tela de vagas: três, a ocupada com o nome de quem joga, e recomeçar uma
## ocupada só apaga no SEGUNDO clique.
func _conferir_as_vagas() -> void:
	for slot in range(1, salvamento.QUANTOS_SLOTS + 1):
		salvamento.apagar(slot)
	partida.comecar(2, true)
	root.get_node("/root/Jogo").nome_jogador = "Zé do Teste"
	_conferir(partida.salvar(), "não consegui preparar a vaga 2 para a tela")
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/abertura.tscn") == OK, "a abertura não carregou")
	await _frames(12)
	var abertura = current_scene
	abertura._vagas()
	await _frames(2)
	var vaga_1: Button = abertura.content.get_node_or_null("Vaga1")
	var vaga_2: Button = abertura.content.get_node_or_null("Vaga2")
	var vaga_3: Button = abertura.content.get_node_or_null("Vaga3")
	var recomecar: Button = abertura.content.get_node_or_null("Recomecar2")
	_conferir(vaga_1 != null and vaga_2 != null and vaga_3 != null, "a tela não mostra as três vagas")
	if vaga_1 == null or vaga_2 == null or recomecar == null:
		_conferir(recomecar != null, "a vaga ocupada não tem o botão de recomeçar")
		return
	_conferir(vaga_1.text.contains("VAZIA"), "a vaga 1, vazia, diz '%s'" % vaga_1.text)
	_conferir(vaga_2.text.contains("Zé do Teste"), "a vaga 2 não diz de quem é a partida: '%s'" % vaga_2.text)
	_conferir(abertura.content.get_node_or_null("Recomecar1") == null, "vaga vazia ganhou botão de recomeçar")
	var antes := recomecar.text
	recomecar.pressed.emit()
	await _frames(2)
	_conferir(salvamento.existe_partida(2), "um clique em recomeçar já apagou a partida")
	_conferir(recomecar.text != antes and recomecar.text.contains("Zé do Teste"),
		"o primeiro clique não disse o que vai ser apagado: '%s'" % recomecar.text)
	recomecar.pressed.emit()
	await _frames(2)
	_conferir(not salvamento.existe_partida(2), "o segundo clique em recomeçar não apagou a partida")
	_conferir(salvamento.slot_atual == 2, "recomeçar a vaga 2 não escolheu a vaga 2")
	_conferir(abertura.line_index >= 0, "recomeçar não abriu a travessia da partida nova")
	root.get_node("/root/Audio").parar_narracao()


func _conferir_cobertura() -> void:
	for propriedade in ProjectSettings.get_property_list():
		var chave: String = propriedade["name"]
		if not chave.begins_with("autoload/"):
			continue
		var nome := chave.trim_prefix("autoload/")
		var caminho := str(ProjectSettings.get_setting(chave)).trim_prefix("*")
		if caminho.contains("/compartilhado/"):
			continue            # do 2D: o testar_salvamento de lá cobre
		if SEM_PARTIDA.has(nome):
			_conferir(str(SEM_PARTIDA[nome]).length() > 20, "%s está fora do save sem razão escrita" % nome)
			continue
		var sistema := root.get_node_or_null("/root/" + nome)
		if sistema == null:
			continue
		var guardados: Array = DO_MUNDO.get(nome, [])
		var fora: Dictionary = FORA_DO_SAVE.get(nome, {})
		for p in sistema.get_property_list():
			if not (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			var campo: String = p["name"]
			if campo.begins_with("_"):
				continue
			_conferir(guardados.has(campo) or fora.has(campo),
				"%s.%s não está no save nem declarado fora dele, com a razão" % [nome, campo])
		for campo in fora:
			_conferir(str(fora[campo]).length() > 20, "%s.%s está fora do save sem razão escrita" % [nome, campo])
			_conferir(campo in sistema, "%s.%s está declarado fora do save e não existe mais: tire a linha" % [nome, campo])


func _abrir_o_vale():
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(6)
	await _mundo_pronto()
	await _frames(10)
	var vale = current_scene
	if vale == null or not ("player" in vale):
		_conferir(false, "o vale não ficou de pé")
		return null
	return vale


func _fechar() -> void:
	_devolver_os_saves_de_verdade()
	print("")
	if falhas == 0:
		print("SALVAMENTO_OK: partida nova volta à fábrica, sem vaga não salva, fechar e reabrir devolve mochila, vida, dia, hora do Dia, lugar, Pedro e o bicho caído, a queda salva o dia novo, o vale que sai sai do save, e todo estado do 3D está guardado ou declarado fora")
	else:
		print("salvamento: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


# --- os saves de verdade -----------------------------------------------------

func _arquivos_das_vagas() -> Array:
	var todos := []
	for slot in range(1, salvamento.QUANTOS_SLOTS + 1):
		for caminho in [salvamento.arquivo(slot), salvamento.anterior(slot), salvamento.rascunho(slot)]:
			todos.append(caminho)
	return todos


func _guardar_os_saves_de_verdade() -> void:
	DirAccess.make_dir_recursive_absolute(RESERVA)
	for caminho in _arquivos_das_vagas():
		if FileAccess.file_exists(caminho):
			DirAccess.rename_absolute(caminho, RESERVA.path_join(caminho.get_file()))


func _devolver_os_saves_de_verdade() -> void:
	# Primeiro some o que o teste escreveu; depois volta o que era do jogador.
	for caminho in _arquivos_das_vagas():
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(caminho)
	_devolver_reserva_esquecida()


func _devolver_reserva_esquecida() -> void:
	var pasta := DirAccess.open(RESERVA)
	if pasta == null:
		return
	# A RESERVA GANHA: ela só existe se uma rodada parou no meio, e então o
	# que está nas vagas foi o teste que escreveu, e o que está nela é do jogador.
	for nome in pasta.get_files():
		var destino := "user://".path_join(nome)
		if FileAccess.file_exists(destino):
			DirAccess.remove_absolute(destino)
		DirAccess.rename_absolute(RESERVA.path_join(nome), destino)
	if DirAccess.open(RESERVA).get_files().is_empty():
		DirAccess.remove_absolute(RESERVA)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
