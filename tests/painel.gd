extends SceneTree
## Confere o PAINEL da tecla J no vale (#19).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/painel.gd
##
## A regra de cada aba é dos autoloads compartilhados, com portão no 2D. Este
## pergunta o que é do vale:
##
##   1. O J É DO PAINEL e não colide com tecla nenhuma dos atalhos.
##   2. ABRIR PARA O MUNDO DO JOGADOR, e não o mundo: o jogador para, o cursor
##      solta, o `Dia` pausa, a ÁRVORE PARA — e o painel fica por cima do
##      HUD. A peçonha espera, e o bicho não caça quem está lendo.
##   3. AS TECLAS DO VALE funcionam dentro dele: Tab troca de aba, E confirma,
##      J fecha — e fechar devolve o jogador e o relógio como estavam.
##   4. ABA DE LUGAR POR PROXIMIDADE: longe da venda só há Missões; no balcão
##      da Venda do Bar aparece a Venda, e comprar e vender mexem na mochila e
##      nos réis pelo preço do `Venda`. Os lugares que o vale não tem estão
##      declarados, com a razão.
##   5. A ABA DO JOGO é sozinha, fora do giro: salvar grava a vaga em curso, e
##      voltar ao menu pede o segundo E antes de acontecer.
##
## Os saves de verdade vão para uma reserva e voltam no fim (ver salvamento.gd).

const RESERVA := "user://reserva_do_teste_do_painel"

var falhas := 0
var salvamento
var partida
var inventario
var dia
var vida
var jogo
var missoes
var venda


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("PAINEL_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	salvamento = root.get_node("/root/Salvamento")
	partida = root.get_node("/root/Partida")
	inventario = root.get_node("/root/Inventario")
	dia = root.get_node("/root/Dia")
	vida = root.get_node("/root/Vida")
	jogo = root.get_node("/root/Jogo")
	missoes = root.get_node("/root/Missoes")
	venda = root.get_node("/root/Venda")
	_devolver_reserva_esquecida()
	_guardar_os_saves_de_verdade()

	# --- 1. O J É DO PAINEL ----------------------------------------------------
	var Atalhos = load("res://scripts/prototipo_3d/atalhos.gd")
	_conferir(Atalhos.tecla("painel") == KEY_J, "o painel não está no J")
	var vistas := {}
	for acao in Atalhos.DEFINICOES:
		var tecla: int = Atalhos.tecla(acao)
		_conferir(not vistas.has(tecla), "%s e %s estão na mesma tecla" % [acao, vistas.get(tecla, "")])
		vistas[tecla] = acao

	partida.comecar(1, true)
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(6)
	await _mundo_pronto()
	await _frames(10)
	var vale = current_scene
	var player = vale.player
	var world = vale.world
	var painel = vale.get_node_or_null("Painel")
	_conferir(painel != null, "o vale não montou o painel")
	if painel == null:
		_fechar()
		return
	var Bancadas = load("res://scripts/prototipo_3d/bancadas_vale.gd")

	# --- 2. ABRIR PARA O JOGADOR, E NÃO O MUNDO --------------------------------
	dia.pausado = false
	vale.abrir_o_painel()
	await _frames(2)
	_conferir(painel.aberto and painel.visible, "abrir_o_painel não abriu o painel")
	_conferir(painel.layer > vale.hud.layer, "o painel ficou por baixo do HUD")
	_conferir(not player.is_physics_processing(), "com o painel aberto o jogador continua andando")
	_conferir(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, "com o painel aberto o cursor continua preso")
	_conferir(dia.pausado, "com o painel aberto o relógio do vale continua andando")
	# A ÁRVORE PARA ATRÁS DELE — e esta linha dizia o contrário.
	#
	# O painel nasceu parando só o relógio: o jogador para, o `Dia` para, a
	# peçonha espera e o bicho não caça quem está lendo. Resolve o que importa
	# para quem lê, e deixa os moradores andando por baixo da tela.
	#
	# Passou a parar tudo por um pedido que é geral, e não sobre esta tela:
	# "quando se abre qualquer menu, o jogo atrás deve ser pausado". A mochila
	# e a confirmação do menu já paravam a árvore; o painel era o terceiro
	# menu do vale e parava outra coisa. Tela de menu que se comporta diferente
	# das irmãs é o formato exato do defeito que voltou quatro vezes na câmera.
	#
	# Nada do painel depende de a árvore andar: ele roda em
	# `PROCESS_MODE_ALWAYS`, e as perguntas 3, 4 e 5 deste portão — teclas,
	# compra, venda e salvar — continuam passando com ela parada. Foi medido,
	# não suposto.
	_conferir(paused, "o painel não pausou o vale atrás dele")
	# --- A FORMA: ÍNDICE À ESQUERDA, PÁGINA À DIREITA ------------------------
	#
	# O painel passou a ter a cara do almanaque — "tente deixar o menu de missão
	# similar ao do Almanaque". As abas saíram de uma linha horizontal
	# ("[ Missões ]  Cartas  Venda", que aperta com seis) e viraram coluna, com
	# marca de aberta e conta em cada linha.
	#
	# Estas duas perguntas vêm da lição da barra de mão, que passou por quinze
	# portões verdes estando invisível: regra certa não é a mesma coisa que o
	# jogador ver.
	var abas := painel.find_children("Abas", "", true, false)
	_conferir(not abas.is_empty(), "o painel não tem a coluna das abas: a forma nova não montou")
	if not abas.is_empty():
		var coluna := abas[0] as VBoxContainer
		_conferir(coluna.get_child_count() >= 1,
			"a coluna das abas está vazia: nem a aba de missões apareceu")
		var so_missoes: bool = painel.abas_validas().size() == 1
		if coluna.get_child_count() > 0:
			var primeira := coluna.get_child(0) as Button
			_conferir(primeira != null and primeira.text.contains("Missões"),
				"a primeira aba da coluna não é Missões: '%s'"
					% (primeira.text if primeira != null else "—"))
			_conferir(primeira != null and primeira.text.contains("▾"),
				"a aba aberta não se marca como aberta: '%s'"
					% (primeira.text if primeira != null else "—"))
		_conferir(so_missoes or coluna.get_child_count() > 1,
			"há mais de uma aba válida e a coluna mostra só %d" % coluna.get_child_count())

	var caixa := painel.find_children("Caixa", "", true, false)
	_conferir(not caixa.is_empty(), "não achei a caixa do painel")
	if not caixa.is_empty():
		var quadro := (caixa[0] as Control).get_global_rect()
		var janela: Vector2 = (caixa[0] as Control).get_viewport_rect().size
		_conferir(quadro.position.x >= -1.0 and quadro.position.y >= -1.0
				and quadro.end.x <= janela.x + 1.0 and quadro.end.y <= janela.y + 1.0,
			"o painel cresceu para fora da janela: %s numa tela de %s" % [str(quadro), str(janela)])

	_conferir(vida.esta_lendo.is_valid() and vida.esta_lendo.call(), "a peçonha não sabe que o jogador está lendo")
	_conferir(painel.abas_validas() == [painel.Aba.MISSOES], "longe de tudo, as abas são %s" % str(painel.abas_validas()))
	# O bicho não caça quem está lendo: o jogador parado pelo painel é jogador
	# travado para a criatura (ver criatura_vale._alvo_travado).
	var luta = vale.get_node_or_null("Luta")
	if luta != null and not luta.criaturas.is_empty():
		var chegada: Vector3 = player.global_position
		var bicho = luta.criaturas[0]
		player.global_position = world.ground_position(bicho.global_position + Vector3(1.0, 0.0, 0.0), 0.07)
		for i in 8:
			await physics_frame
		_conferir(not bicho.cacando, "o caititu caçou quem está com o painel aberto")
		player.global_position = chegada

	# --- 3. AS TECLAS DO VALE --------------------------------------------------
	missoes.adicionar("teste_do_painel", "Um passo de teste", false, [], "", true)
	missoes.adicionar("outro_do_painel", "Outro passo", false, [], "", false)
	await _frames(2)
	var tem_titulo := false
	for linha in painel._escolhiveis:
		if linha is Button and linha.text.contains("Um passo de teste"):
			tem_titulo = true
	_conferir(tem_titulo, "a aba de missões não mostra a missão aberta")
	_tecla(painel, KEY_TAB)
	_conferir(painel.aba() == painel.Aba.MISSOES, "Tab saiu de Missões sem ter outra aba")
	painel.escolher(1)
	_tecla(painel, KEY_E)
	_conferir(missoes.em_foco == missoes.indice("outro_do_painel"), "o E não fixou a missão escolhida")
	_tecla(painel, KEY_J)
	await _frames(2)
	_conferir(not painel.aberto, "o J não fechou o painel")
	_conferir(player.is_physics_processing(), "fechou o painel e o jogador continuou parado")
	_conferir(not dia.pausado, "fechou o painel e o relógio continuou parado")

	# --- 4. ABA DE LUGAR POR PROXIMIDADE ----------------------------------------
	for qual in Bancadas.BANCADAS:
		var ancora := str(Bancadas.BANCADAS[qual]["ancora"])
		_conferir(world.ancoras.has(ancora), "a bancada '%s' aponta para a âncora '%s', que o vale não tem" % [qual, ancora])
	for qual in Bancadas.FALTAM:
		_conferir(str(Bancadas.FALTAM[qual]).length() > 20, "o lugar '%s' falta sem razão escrita" % qual)
	var balcao: Vector3 = world.ancoras["Venda do Bar"] + world.ancoras.get("Venda do BarFrente", Vector3.BACK) * (Bancadas.raio("venda") - 1.0)
	player.global_position = world.ground_position(balcao, 0.07)
	await _frames(2)
	vale.abrir_o_painel()
	await _frames(2)
	_conferir(painel.abas_validas().has(painel.Aba.VENDA), "no balcão da venda, a aba de venda não apareceu: %s" % str(painel.abas_validas()))
	# No balcão há DUAS abas de lugar — as obras do armazém e a venda —, e o Tab
	# anda por elas; chega à venda em no máximo tantos toques quantas abas há.
	for i in painel.abas_validas().size():
		if painel.aba() == painel.Aba.VENDA:
			break
		_tecla(painel, KEY_TAB)
	_conferir(painel.aba() == painel.Aba.VENDA, "Tab não levou à aba de venda")
	var mercadorias: Array = venda.mercadorias()
	_conferir(not mercadorias.is_empty(), "a venda não tem mercadoria")
	if not mercadorias.is_empty():
		var item := str(mercadorias[0])
		jogo.dinheiro = 500
		var antes: int = inventario.quantidade(item)
		var preco: int = venda.preco_de_compra(item)
		painel.escolher(0)
		_tecla(painel, KEY_E)
		_conferir(inventario.quantidade(item) == antes + 1, "comprar não pôs %s na mochila" % item)
		_conferir(jogo.dinheiro == 500 - preco, "comprar cobrou %d, e o preço é %d" % [500 - jogo.dinheiro, preco])
		var recebe: int = venda.preco_de_venda(item)
		var com: int = jogo.dinheiro
		painel.vender()
		_conferir(inventario.quantidade(item) == antes, "vender não tirou %s da mochila" % item)
		_conferir(jogo.dinheiro == com + recebe, "vender pagou %d, e o preço é %d" % [jogo.dinheiro - com, recebe])
	painel.fechar()
	player.global_position = world.ground_position(world.ancoras["Venda do Bar"] + Vector3(60, 0, 60), 0.07)
	vale.abrir_o_painel()
	_conferir(not painel.abas_validas().has(painel.Aba.VENDA), "longe do balcão, a aba de venda continuou")

	# --- 5. A ABA DO JOGO ------------------------------------------------------
	painel._ir_para_o_jogo()
	_conferir(painel.abas_validas() == [painel.Aba.AJUSTES], "a aba do jogo não é sozinha: %s" % str(painel.abas_validas()))
	_tecla(painel, KEY_TAB)
	_conferir(painel.aba() == painel.Aba.AJUSTES, "Tab saiu da aba do jogo")
	painel.escolher(0)
	_tecla(painel, KEY_E)
	_conferir(salvamento.existe_partida(1), "Salvar agora não gravou a vaga 1")
	_conferir(painel._aviso.contains("vaga 1"), "salvou e o painel não disse: '%s'" % painel._aviso)
	painel.escolher(1)
	_tecla(painel, KEY_E)
	_conferir(painel.aberto and painel._confirmando == 1, "voltar ao menu não pediu o segundo E")
	painel.escolher(0)
	_conferir(painel._confirmando == -1, "andar de linha não desfez a confirmação pendurada")
	painel.fechar()

	_fechar()


func _tecla(painel, codigo: int) -> void:
	var evento := InputEventKey.new()
	evento.physical_keycode = codigo
	evento.keycode = codigo
	evento.pressed = true
	painel._unhandled_input(evento)


func _fechar() -> void:
	_devolver_os_saves_de_verdade()
	print("")
	if falhas == 0:
		print("PAINEL_OK: o J é do painel; abrir para o jogador, o relógio e o vale inteiro, por cima do HUD e dentro da janela, com as abas em coluna como no almanaque; Tab, E e J funcionam dentro; a venda aparece no balcão e compra e vende pelo preço; a aba do jogo é sozinha, salva a vaga e pede o segundo E para sair")
	else:
		print("painel: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


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
	for caminho in _arquivos_das_vagas():
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(caminho)
	_devolver_reserva_esquecida()


## A RESERVA GANHA: ela só existe se uma rodada parou no meio (ver salvamento.gd).
func _devolver_reserva_esquecida() -> void:
	var pasta := DirAccess.open(RESERVA)
	if pasta == null:
		return
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
