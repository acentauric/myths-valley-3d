extends SceneTree
## Confere O E NOS MORADORES e A CONQUISTA DA MISSÃO.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/interacao.gd
##
## "Quando fui falar com Dona Candinha para pegar a chave, não consegui
## interagir. Eu tinha deletado o save e abri um novo em cima do mesmo slot. [...]
## O ideal é o Pedro ensinar a apertar E para iniciar as interações com os NPCs,
## incluindo cumprir etapas de missões. Sempre que concluir uma missão, deve
## aparecer uma animação na tela, sombreando toda a tela e dando um destaque para
## a animação." Sete perguntas:
##
##   1. A PARTIDA NOVA ZERA O CADERNO: missões da partida anterior (ativas,
##      cumpridas e a acompanhada) não passam para a nova no mesmo slot.
##   2. O E NUM MORADOR SEM MISSÃO É CONVERSA: ao lado dele, a dica do E está
##      nele, e o E o faz dizer a fala inteira, e não a curta da saudação.
##   3. O PASSO SE CUMPRE NO E: ao lado do Pedro, no desembarque, nada fecha
##      sozinho; o E fecha, com a resposta dele.
##   4. A CONQUISTA: o passo cumprido escurece a tela e mostra "Missão
##      concluída" com o nome do passo — DEPOIS da resposta de quem fala, com o
##      relógio parado durante a fala e durante a festa, entrando devagar e
##      ficando pelo menos cinco segundos, com as plaquinhas de nome dos
##      moradores recolhidas enquanto dura.
##   5. A FILA DE UM MORADOR ABRE NO E: depois da chegada, ao lado do Tonho, a
##      fila dele não abre sozinha; o E a abre.
##   6. A VEZ DE FALAR TEM PRAZO: com alguém falando sem parar ao lado do
##      jogador, o passo seguinte se anuncia mesmo assim.
##   7. O E EM QUEM NÃO FALA É ACENO: num morador novo, que não tem fala, o E não
##      abre balão vazio, não põe aviso no HUD e não segura o relógio.

var falhas := 0
var dialogo


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("INTERACAO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	# --- 1. A PARTIDA NOVA ZERA O CADERNO ---------------------------------------
	var caderno = root.get_node("/root/CadernoDoVale")
	var partida = root.get_node("/root/Partida")
	caderno.abrir_missao("pedro_chave", "Quem guardou a chave", "pedro", true, "A partida apagada.")
	caderno.abrir_missao("pedro_bom_dia", "Quem chega, cumprimenta", "pedro", true, "")
	caderno.concluir("pedro_bom_dia")
	caderno.fixar("pedro_chave")
	partida.comecar(1, true)
	_conferir(caderno.ativas.is_empty() and caderno.cumpridas.is_empty() and caderno.foco == "",
		"a partida nova no mesmo slot ficou com o caderno da anterior: %d ativa(s), %d cumprida(s), foco '%s'" % [caderno.ativas.size(), caderno.cumpridas.size(), caderno.foco])

	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	dialogo = root.get_node("/root/Dialogo")
	var vale = current_scene
	var jogador = vale.player
	var pedro = vale.get("pedro")
	var tecla = vale.get("tecla_dos_moradores")
	var conquista = vale.get("conquista")
	_conferir(pedro != null and tecla != null and conquista != null, "o vale não tem o Pedro, o E dos moradores ou a tela da conquista")
	if pedro == null or tecla == null or conquista == null:
		_fechar()
		return
	root.get_node("/root/Dia").pausado = true

	# --- 2. O E NUM MORADOR SEM MISSÃO É CONVERSA --------------------------------
	var filo = vale._achar_morador("filo")
	_conferir(filo != null, "o vale não tem a Dona Filó")
	if filo != null:
		_ao_lado_de(jogador, filo, Vector3(1.2, 0.1, 0.0))
		await _passos_de_fisica(10)
		_conferir(tecla.perto() == filo, "ao lado da Dona Filó, o E não está nela (está em %s)" % str(tecla.perto()))
		_apertar_e(tecla)
		await _quadros(2)
		var dita := _no_balao(filo)
		_conferir(filo._balao_tempo > 0.0 and dita != "", "o E na Dona Filó não a fez conversar")
		_conferir(dita.length() > 60, "a conversa do E é a fala curta da saudação, e não a inteira: '%s'" % dita)

	# --- 3. O PASSO SE CUMPRE NO E -----------------------------------------------
	_conferir(pedro.passo_em_curso() == "desembarque", "a chegada não começou pelo desembarque")
	await _ate(func() -> bool: return float(pedro.get("_espera")) <= 0.0, 15.0)
	_ao_lado_de(jogador, pedro, Vector3(1.0, 0.1, 0.6))
	await _passos_de_fisica(60)
	_conferir(pedro.passo_em_curso() == "desembarque", "ao lado do Pedro o desembarque fechou sozinho, sem o E")
	_conferir(tecla.perto() == pedro, "ao lado do Pedro, o E não está nele")
	_apertar_e(tecla)
	await _quadros(2)
	_conferir(_no_balao(pedro).contains("Bom Jesus dos Pobres"), "o E no Pedro não trouxe a resposta do desembarque: '%s'" % _no_balao(pedro))

	# --- 4. A CONQUISTA ------------------------------------------------------------
	# DEPOIS DA CONVERSA: o passo fechou no E, com a resposta do Pedro ainda no
	# balão, e a festa espera ele acabar ("o efeito também só deve aparecer depois
	# que terminar a interação com o NPC"). Enquanto ele fala, o relógio do vale
	# fica parado ("o relógio deve parar quando o jogador estiver em uma interação
	# de conversa com o NPC").
	var dia_do_vale = root.get_node("/root/Dia")
	_conferir(pedro.conversando() and dia_do_vale.segurado("fala:"),
		"com o Pedro respondendo no balão, o relógio do vale não parou")
	var por_cima := await _ate(func() -> bool: return conquista.ativa(), 2.0)
	_conferir(not por_cima and conquista.esperando(),
		"a conquista entrou por cima da resposta do Pedro, com ele ainda falando")
	var festejou := await _ate(func() -> bool: return conquista.ativa(), 15.0)
	_conferir(festejou, "acabada a resposta do Pedro, o desembarque cumprido não mostrou a tela da conquista")
	if festejou:
		var desde := Time.get_ticks_msec()
		_conferir(not pedro.conversando(), "a conquista entrou com o Pedro ainda no balão")
		_conferir(dia_do_vale.segurado("conquista"), "a festa da conquista não segurou o relógio do vale")
		# AS PLAQUINHAS DE NOME SE RECOLHEM: são do HUD, que desenha por cima da
		# festa, e o nome do Pedro — parado na frente do jogador — caía no emblema.
		_conferir(not vale.placas._permitido,
			"durante a festa da missão, as plaquinhas de nome dos moradores continuam acesas por cima dela")
		_conferir(str(conquista.mostrada.get("titulo", "")) == "As pernas de terra firme",
			"a conquista mostra '%s', e o passo cumprido é 'As pernas de terra firme'" % str(conquista.mostrada.get("titulo", "")))
		# SUAVE: a sombra sobe numa curva de segundos (`ENTRA`), e não num estalo —
		# com um terço de segundo ela ainda mal começou. Medido em segundo de
		# relógio, e não em quadros: sem tela, o quadro dura o que a máquina deixa.
		var sombra: ColorRect = conquista.get("_sombra")
		await _ate(func() -> bool: return false, 0.3)
		_conferir(sombra != null and sombra.color.a < 0.2,
			"a sombra da conquista já estava em %.2f com um terço de segundo: a entrada é um estalo" % (sombra.color.a if sombra != null else -1.0))
		var escureceu: bool = sombra != null and await _ate(func() -> bool: return sombra.color.a > 0.3, 3.0)
		_conferir(escureceu, "a conquista não escureceu a tela (sombra %.2f)" % (sombra.color.a if sombra != null else -1.0))
		_conferir(str(conquista.get("_titulo").text) == "MISSÃO CONCLUÍDA", "o título da conquista é '%s'" % str(conquista.get("_titulo").text))
		# MAIS TEMPO NA TELA: "aumentar o tempo de efeito dela em tela".
		_conferir(await _ate(func() -> bool: return not conquista.ativa(), 14.0), "a tela da conquista não sumiu sozinha")
		var durou := (Time.get_ticks_msec() - desde) / 1000.0
		_conferir(durou >= 5.0, "a conquista ficou %.1f s na tela, e o pedido é ela durar mais" % durou)
		_conferir(not dia_do_vale.segurado("conquista"), "a festa acabou e o relógio continuou segurado por ela")
		_conferir(vale.placas._permitido, "a festa acabou e as plaquinhas de nome dos moradores não voltaram")

	# --- 5. A FILA DE UM MORADOR ABRE NO E -----------------------------------------
	pedro.missao = pedro.MISSOES.size()
	pedro.set("_despedida_feita", true)
	# A rede do Tonho é de madeira: a fila dele espera os machados do avô, na
	# ponte (`prototype._ja_recebeu_o_machado`). Aqui a ponte já passou deles.
	var da_ponte = vale._cadeias.get("pedro_ponte")
	if da_ponte != null:
		da_ponte.iniciado = true
		for i in da_ponte.passos.size():
			if str((da_ponte.passos[i] as Dictionary).get("id", "")) == "buscar_machado":
				da_ponte.missao = i + 1
	var tonho = vale._achar_morador("tonho")
	var fila = vale._cadeias.get("tonho")
	_conferir(fila != null, "o Tonho não tem fila de pedidos")
	if fila != null:
		_ao_lado_de(jogador, tonho, Vector3(1.0, 0.1, 0.6))
		await _ate(func() -> bool: return false, 2.0)
		_conferir(not fila.iniciado, "ao lado do Tonho, a fila dele abriu sozinha, sem o E")
		_conferir(tecla.perto() == tonho, "ao lado do Tonho, o E não está nele")
		_apertar_e(tecla)
		_conferir(fila.iniciado, "o E no Tonho, depois da chegada, não abriu a fila dele")
		await _quadros(2)
		_conferir(tonho._balao_tempo > 0.0 and _no_balao(tonho) != "", "o E abriu a fila do Tonho, mas ele não disse o pedido")

	# --- 6. A VEZ DE FALAR TEM PRAZO -------------------------------------------------
	# A fila do Tonho anuncia de novo o passo em que está; com o Pedro falando sem
	# parar ao lado do jogador, ela espera a vez — e anuncia mesmo assim.
	if fila != null and fila.iniciado:
		var antes: int = fila.missao
		pedro.global_position = jogador.global_position + Vector3(2.0, 0.1, 0.0)
		fila.espera = 0.05
		var limite := Time.get_ticks_msec() + 12000
		var anunciou := false
		while Time.get_ticks_msec() < limite:
			pedro._tomar_palavra(30.0)
			if float(fila.espera) <= 0.0:
				anunciou = true
				break
			await process_frame
		_conferir(anunciou and fila.missao == antes, "com alguém falando sem parar, o passo não se anunciou em 12 s: a vez não tem prazo")
		await _fechar_a_fala()

	# --- 7. O E EM QUEM NÃO FALA É ACENO ---------------------------------------------
	# Os moradores novos tinham jornada e ofício, e nenhuma fala (`npc._eh_mudo`). A
	# conversa do E neles abria um balão sem texto, punha "Nome: " no HUD e segurava
	# o relógio por dez segundos de uma fala que não havia. Desde a #85 todos falam:
	# a pergunta do aceno cala um deles por um instante.
	# Um morador SEM FILA DE MISSÃO: no Benedito, na Zefa ou no Tonho o E abre a
	# fala da missão, que não é o aceno.
	var calado = null
	for id in ["guarda", "lavadeira", "rendeira", "pescador", "marisqueira", "sacristao", "beata", "quituteira", "carpinteiro"]:
		var morador = vale._achar_morador(id)
		if morador != null and morador.is_visible_in_tree() and not morador.esta_recolhido():
			calado = morador
			break
	_conferir(calado != null, "o vale não tem morador de corpo presente para a pergunta do aceno")
	if calado != null:
		# Sem balão nem relógio de uma fala anterior: a pergunta é só sobre o aceno.
		calado.calar()
		calado.dados["mudo"] = true
		var avisos := [0]
		calado.saudou.connect(func(_quem, _texto: String) -> void: avisos[0] += 1)
		# Ao lado dele: a trava do relógio só pega com o jogador ao alcance da conversa.
		_ao_lado_de(jogador, calado, Vector3(1.0, 0.1, 0.6))
		await _passos_de_fisica(4)
		tecla.usar(calado)
		await _quadros(2)
		_conferir(float(calado._balao_tempo) <= 0.0, "o E em quem não fala (%s) abriu um balão sem texto" % str(calado.dados.get("id", "")))
		_conferir(not calado.conversando(), "o E em quem não fala segurou o relógio do vale por uma fala que não há")
		_conferir(avisos[0] == 0, "o E em quem não fala pôs um aviso vazio no HUD")
		calado.dados.erase("mudo")
	_fechar()


## AO LADO DE QUEM SE FALA, VIRADO PARA ELE: o E vai para o que está na frente do
## corpo (`foco_do_e.gd`), e no píer o cordel pendurado fica a dois passos do
## Tonho. Quem quer conversar se vira para a pessoa.
func _ao_lado_de(jogador, morador, desvio: Vector3) -> void:
	var onde: Vector3 = morador.global_position + desvio
	var para_ele: Vector3 = morador.global_position - onde
	jogador.teleportar(onde, atan2(para_ele.x, para_ele.z))


## O que está no balão de quem fala.
func _no_balao(morador) -> String:
	var rotulo = morador.balao.get("_texto")
	return str(rotulo.text) if rotulo != null else ""


## O E, pelo caminho do jogo: a tecla de interagir, a quem conversa com os
## moradores.
func _apertar_e(tecla) -> void:
	var evento := InputEventKey.new()
	evento.keycode = KEY_E
	evento.physical_keycode = KEY_E
	evento.pressed = true
	tecla._unhandled_key_input(evento)


func _fechar_a_fala() -> void:
	var ate := Time.get_ticks_msec() + 4000
	while dialogo.ativo and Time.get_ticks_msec() < ate:
		dialogo._fechar()
		await process_frame
	await _quadros(3)


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("INTERACAO_OK: a partida nova zera o caderno da anterior; o E num morador sem missão o faz dizer a fala inteira; o passo que manda falar com alguém fecha no E, e não ao chegar perto; o relógio para enquanto ele responde; a conquista espera a resposta acabar, entra devagar, escurece a tela com o nome do passo, segura o relógio, fica mais de cinco segundos e some sozinha; a fila de um morador abre no E, e não sozinha; com alguém falando sem parar o passo se anuncia mesmo assim; e o E em quem não fala é só o aceno, sem balão vazio nem relógio parado")
	else:
		print("interacao: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _passos_de_fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


## Roda quadros até `condicao` valer, com teto em SEGUNDO REAL.
func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicao.call():
			return true
		await process_frame
	return condicao.call()


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
