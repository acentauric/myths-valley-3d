extends SceneTree
## Confere o RELÓGIO DA PARTIDA: mexer nele pode, com aviso, confirmação e
## registro no save.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/relogio.gd
##
## "Pode manter a possibilidade de alterar o relógio, desde que tenha o aviso,
## a confirmação e a alteração no backlog do save." A linha "Relógio" do menu
## do Esc já tinha a pergunta, e o `menu_pausa.gd` a confere; aqui ficam as
## outras portas, e o começo de partida:
##
##   1. "PARADA" NO AJUSTAR PERGUNTA ANTES. Escolher abre a caixa que fala das
##      conquistas; "não" devolve o seletor ao que estava e não mexe em nada;
##      "sim" para o tempo, marca a partida e escreve no registro.
##   4. DUAS TELAS ANINHADAS NÃO DEIXAM O DIA PRESO (#100): as telas seguram o dia
##      por motivo, contadas; a pausa do jogador atravessa as telas; e o HUD diz
##      "parado" ou "tela" ao lado da hora.
##   2. A TECLA DE ADIANTAR A HORA PERGUNTA NA PRIMEIRA VEZ, com o vale parado
##      atrás da caixa; "não" não adianta; "sim" adianta uma hora, marca e
##      registra. Com a partida já marcada, a tecla adianta sem perguntar, e o
##      registro anota de novo.
##   3. A PARTIDA QUE COMEÇA EM "PARADA" já começa marcada, e o registro diz.
##
## A VELOCIDADE É PREFERÊNCIA DO JOGADOR, gravada em user://. O portão a
## devolve ao que era ao sair, inclusive se reprovar no meio.

var falhas := 0
var _velocidade_do_jogador := -1


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("RELOGIO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	var dia := root.get_node("/root/Dia")
	_velocidade_do_jogador = dia.velocidade
	# O portão parte do relógio correndo, qualquer que seja a escolha de quem o roda.
	dia.velocidade = dia.VELOCIDADE_PADRAO
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(8)
	var vale = current_scene
	var hud = vale.get("hud")
	_conferir(not dia.relogio_alterado and dia.registro_do_relogio.is_empty(),
		"a partida nova já começou com o relógio marcado: %s" % str(dia.registro_do_relogio))

	# --- 1. "PARADA" NO AJUSTAR ------------------------------------------------
	hud.open_settings()
	await _frames(2)
	var painel = hud.get("_ajustes")
	var seletor: OptionButton = painel.get("_seletor_do_tempo") if painel != null else null
	_conferir(seletor != null, "o AJUSTAR não tem o seletor da passagem do tempo")
	if seletor != null:
		var rotulos: Array = []
		for i in seletor.item_count:
			rotulos.append(seletor.get_item_text(i))
		_conferir(rotulos.has("Parada"), "a passagem do tempo não oferece \"Parada\": %s" % str(rotulos))
		var antes: int = dia.velocidade
		seletor.select(dia.PARADA)
		seletor.item_selected.emit(dia.PARADA)
		await _frames(2)
		var pergunta = painel.get("_pergunta_do_tempo")
		_conferir(pergunta != null, "escolher \"Parada\" não pediu confirmação")
		if pergunta != null:
			var texto: String = (pergunta.find_child("Texto", true, false) as Label).text
			_conferir(texto.contains("conquistas") and texto.contains("registro"),
				"a confirmação do \"Parada\" não fala das conquistas e do registro: '%s'" % texto)
			_conferir(dia.velocidade == antes, "o tempo parou antes de o jogador confirmar")
			pergunta.responder(false)
			await _frames(2)
			_conferir(dia.velocidade == antes and seletor.selected == antes,
				"\"não\" deixou o tempo em %d e o seletor em %d, e estava em %d" % [dia.velocidade, seletor.selected, antes])
			_conferir(not dia.relogio_alterado and dia.registro_do_relogio.is_empty(),
				"desistir do \"Parada\" marcou a partida mesmo assim")
		seletor.select(dia.PARADA)
		seletor.item_selected.emit(dia.PARADA)
		await _frames(2)
		pergunta = painel.get("_pergunta_do_tempo")
		if pergunta != null:
			pergunta.responder(true)
			await _frames(2)
		_conferir(dia.velocidade == dia.PARADA, "confirmar o \"Parada\" não parou o tempo")
		_conferir(dia.relogio_alterado, "confirmar o \"Parada\" não marcou a partida")
		_conferir(not dia.registro_do_relogio.is_empty()
				and str(dia.registro_do_relogio[-1].get("o_que", "")) == "velocidade"
				and str(dia.registro_do_relogio[-1].get("de", "")) == "Parada",
			"o \"Parada\" não entrou no registro do relógio: %s" % str(dia.registro_do_relogio))
	hud.close_settings()
	await _frames(2)
	# Volta a correr e desmarca, para a pergunta da tecla aparecer.
	dia.velocidade = dia.VELOCIDADE_PADRAO
	dia.zerar_a_partida()

	# --- 2. A TECLA DE ADIANTAR A HORA -------------------------------------------
	dia.definir_hora(9.0)
	_apertar_a_hora()
	await _frames(3)
	var caixa = vale.get("_pergunta_do_relogio")
	_conferir(caixa != null, "adiantar a hora não pediu confirmação")
	_conferir(paused, "com a pergunta de adiantar aberta, o vale continuou andando")
	if caixa != null:
		var texto_da_tecla: String = (caixa.find_child("Texto", true, false) as Label).text
		_conferir(texto_da_tecla.contains("conquistas"), "a pergunta de adiantar não fala das conquistas: '%s'" % texto_da_tecla)
		caixa.responder(false)
		await _frames(3)
	_conferir(not paused, "desistir de adiantar deixou o vale parado")
	_conferir(absf(dia.hora - 9.0) < 0.1 and not dia.relogio_alterado,
		"\"não\" adiantou a hora (%s) ou marcou a partida" % dia.texto_hora())
	_apertar_a_hora()
	await _frames(3)
	caixa = vale.get("_pergunta_do_relogio")
	if caixa != null:
		caixa.responder(true)
		await _frames(3)
	_conferir(absf(dia.hora - 10.0) < 0.1, "confirmar não adiantou uma hora: %s" % dia.texto_hora())
	_conferir(dia.relogio_alterado, "adiantar a hora não marcou a partida")
	_conferir(not dia.registro_do_relogio.is_empty() and str(dia.registro_do_relogio[-1].get("o_que", "")) == "adiantou",
		"adiantar a hora não entrou no registro: %s" % str(dia.registro_do_relogio))
	var anotados: int = dia.registro_do_relogio.size()
	_apertar_a_hora()
	await _frames(3)
	_conferir(vale.get("_pergunta_do_relogio") == null, "com a partida já marcada, a tecla perguntou de novo")
	_conferir(absf(dia.hora - 11.0) < 0.1 and dia.registro_do_relogio.size() == anotados + 1,
		"a segunda tecla não adiantou (%s) ou não anotou" % dia.texto_hora())

	# --- 3. A PARTIDA QUE COMEÇA EM "PARADA" -------------------------------------
	dia.velocidade = dia.PARADA
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale recarrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(8)
	_conferir(dia.relogio_alterado, "a partida que começou em \"Parada\" não ficou marcada")
	_conferir(dia.registro_do_relogio.size() == 1 and str(dia.registro_do_relogio[0].get("o_que", "")) == "comecou_parada",
		"o registro da partida que começou parada diz %s" % str(dia.registro_do_relogio))

	# --- 4. DUAS TELAS ANINHADAS NÃO DEIXAM O DIA PRESO (#100) --------------------
	# Na live de 06/10 o relógio travou às 07:14: as telas guardavam "estava pausado
	# antes?" num booleano só, e a segunda tela aberta por cima da primeira
	# devolvia "pausado" ao fechar. Agora as telas seguram o dia por motivo,
	# contadas, e `Dia.pausado` é só a pausa que o jogador pediu.
	vale = current_scene
	hud = vale.get("hud")
	dia.velocidade = dia.VELOCIDADE_PADRAO
	dia.pausado = false
	vale._pause_valley()
	vale._pause_valley()
	_conferir(paused and dia.segurado("tela"), "com duas telas abertas o vale (%s) ou o dia (%s) não parou" % [str(paused), str(dia.segurado("tela"))])
	vale._retomar_o_vale()
	_conferir(paused and dia.segurado("tela"), "fechada a tela de cima, com a de baixo aberta, o vale (%s) ou o dia (%s) voltou a andar" % [str(paused), str(dia.segurado("tela"))])
	vale._retomar_o_vale()
	_conferir(not paused and not dia.segurado("tela") and not dia.pausado,
		"fechadas as duas telas o dia ficou preso: vale parado %s, segurado %s, pausado %s" % [str(paused), str(dia.segurado("tela")), str(dia.pausado)])
	# A pausa do jogador atravessa as telas inteira: abrir e fechar não a mexe.
	dia.pausado = true
	vale._pause_valley()
	vale._retomar_o_vale()
	_conferir(dia.pausado, "abrir e fechar uma tela religou o relógio que o jogador parou")
	# O HUD DIZ POR QUÊ: "parado" pela pausa do jogador, "tela" pela tela.
	var estado: Label = hud.get("_clock_estado")
	_conferir(estado != null, "o HUD não tem o estado do relógio ao lado da hora")
	if estado != null:
		_conferir(await _ate(func() -> bool: return estado.visible and estado.text == tr("parado"), 2.0), "com o relógio parado pelo jogador o HUD não diz \"parado\" ('%s')" % estado.text)
		dia.pausado = false
		vale._pause_valley()
		# Só a pausa do jogador tem rótulo (07/10): a tela segura o dia, e o HUD não escreve "tela".
		_conferir(await _ate(func() -> bool: return not estado.visible, 2.0), "com uma tela aberta, e o relógio andando por fora dela, o HUD escreveu um motivo ('%s'): só \"parado\" tem rótulo" % estado.text)
		_conferir(dia.segurado("tela"), "a tela aberta não segura o dia")
		vale._retomar_o_vale()
		_conferir(await _ate(func() -> bool: return not estado.visible, 2.0), "fechada a tela o estado do relógio não sumiu ('%s')" % estado.text)
	_fechar()


## A TECLA DE VERDADE, a que o jogador escolheu para "Avançar a hora": o vale
## a lê no `_unhandled_key_input`, que só ouve tecla.
func _apertar_a_hora() -> void:
	var letra: int = load("res://scripts/prototipo_3d/atalhos.gd").tecla("hora")
	for apertada in [true, false]:
		var tecla := InputEventKey.new()
		tecla.keycode = letra
		tecla.physical_keycode = letra
		tecla.pressed = apertada
		Input.parse_input_event(tecla)


func _fechar() -> void:
	var dia := root.get_node("/root/Dia")
	if _velocidade_do_jogador >= 0 and dia.velocidade != _velocidade_do_jogador:
		dia.definir_velocidade(_velocidade_do_jogador)
	print("")
	if falhas == 0:
		print("RELOGIO_OK: \"Parada\" no AJUSTAR pergunta antes, o \"não\" devolve a escolha e o \"sim\" para, marca e registra; a tecla de adiantar a hora pergunta na primeira vez com o vale parado, e depois só anota; e a partida que começa parada já começa marcada e registrada")
	else:
		print("relogio: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame


func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame


## Roda quadros até `condicao` valer, com teto em segundo real.
func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if bool(condicao.call()):
			return true
		await process_frame
	return bool(condicao.call())
