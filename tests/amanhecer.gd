extends "res://tests/suite/caso.gd"
## Confere O AMANHECER NO VALE (#21): o cartão do dia que começa, lido no
## escuro da queda, e a fala de quem acorda na caixa de fala longa.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste amanhecer
##
## A tela pertence ao vale. O portão mede apresentação, queda e lembretes
## usando apenas os recursos deste projeto.
##
##   2. O CARTÃO CABE NA TELA em qualquer data, com e sem lembrete, e sai
##      sozinho, sem ninguém apertar nada.
##   3. O CARTÃO NO VALE: acima da tela preta da queda, no tamanho do vale.
##   4. A QUEDA MOSTRA O CARTÃO no escuro, com o dia novo já virado, e o vale
##      para atrás dele: I, M, E e Esc nele não abrem tela nem mapa, não comem o
##      que está na mão e não abrem o menu. Acordado, a fala de quem caiu vem na
##      caixa de fala, com o vale parado, e o E a passa até o vale voltar a andar.
##   5. OS LEMBRETES SÃO OS DO 2D: o dia da fazenda, ou a festa da fé do dia;
##      sem nenhum dos dois, nada.

var falhas := 0
var amanhecer
var relogio
var dia
var dialogo
var vale


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("AMANHECER_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	amanhecer = root.get_node_or_null("/root/Amanhecer")
	relogio = root.get_node("/root/Relogio")
	dia = root.get_node("/root/Dia")
	dialogo = root.get_node("/root/Dialogo")
	_conferir(amanhecer != null, "não há autoload Amanhecer no vale")
	if amanhecer == null:
		_fechar()
		return

	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(6)
	await _mundo_pronto()
	await _frames(10)
	vale = current_scene

	# --- 2. O CARTÃO CABE NA TELA ----------------------------------------------
	# O quadro da tela do vale (`amanhecer_vale.gd`): o cartão deixou o 640×360 do 2D em 07/10.
	var quadro := Rect2(Vector2.ZERO, amanhecer.DESENHADA_PARA)
	var guardado := [relogio.dia, relogio.estacao, relogio.ano]
	for caso in [{"dia": 1, "estacao": 0, "ano": 1, "lembretes": []},
			{"dia": 28, "estacao": 3, "ano": 12, "lembretes": []},
			{"dia": 14, "estacao": 1, "ano": 2,
				"lembretes": ["Feira na praça", "Novena na capela"]}]:
		relogio.dia = int(caso["dia"])
		relogio.estacao = int(caso["estacao"])
		relogio.ano = int(caso["ano"])
		amanhecer.mostrar(caso["lembretes"])
		await _frames(4)
		_conferir(amanhecer.aberto, "o cartão não abriu no dia %d" % relogio.dia)
		for campo in ["_dia", "_data", "_folego", "_lembretes"]:
			var etiqueta: Label = amanhecer.get(campo)
			_conferir(etiqueta.get_visible_line_count() >= etiqueta.get_line_count(),
				"dia %d: %s não cabe na caixa" % [relogio.dia, campo])
			_conferir(quadro.encloses(etiqueta.get_global_rect()),
				"dia %d: %s saiu da tela (%s)" % [relogio.dia, campo, etiqueta.get_global_rect()])
		# Sai sozinho. Teto pelo relógio de parede: o cartão mede tempo, e quadro
		# sem janela passa mais rápido que isso.
		await _esperar_ate(func() -> bool: return not amanhecer.aberto, 8.0)
		_conferir(not amanhecer.aberto, "o cartão do dia %d não saiu sozinho" % relogio.dia)
	relogio.dia = guardado[0]
	relogio.estacao = guardado[1]
	relogio.ano = guardado[2]

	# --- 3. O CARTÃO NO VALE ---------------------------------------------------
	var queda = vale.get_node("Queda")
	var preto: CanvasLayer = queda.get_node("TelaDaQueda")
	_conferir(amanhecer.layer > preto.layer,
		"o cartão está na camada %d e a tela preta da queda na %d: ele seria lido embaixo do escuro" % [amanhecer.layer, preto.layer])
	var tela: Vector2 = vale.get_viewport().get_visible_rect().size
	var na_tela: Rect2 = amanhecer.transform * quadro
	_conferir(Rect2(Vector2.ZERO, tela).encloses(na_tela.grow(-0.5)),
		"o cartão sai da janela: %s numa tela de %s" % [str(na_tela), str(tela)])
	_conferir(na_tela.size.x >= tela.x * 0.9, "o cartão tem %.0f px numa tela de %.0f: abriu no tamanho do 2D" % [na_tela.size.x, tela.x])
	_conferir(amanhecer.transform.get_scale().x <= 1.05,
		"o cartão é ampliado %.2f vezes: é o quadro do 2D esticado, e a letra serrilha" % amanhecer.transform.get_scale().x)

	# --- 4. A QUEDA MOSTRA O CARTÃO --------------------------------------------
	dia.pausado = true
	var dia_antes: int = relogio.dia_absoluto()
	var inventario = root.get_node("/root/Inventario")
	inventario.adicionar("banana", 2)
	inventario.selecionar(_espaco_de(inventario, "banana"))
	var acordou := [false]
	queda.acordou.connect(func(): acordou[0] = true)
	root.get_node("/root/Vida").ferir(9999.0)
	await _esperar_ate(func() -> bool: return amanhecer.aberto, 8.0)
	_conferir(amanhecer.aberto, "a queda não mostrou o cartão do amanhecer")
	if amanhecer.aberto:
		_conferir(queda._preto.modulate.a > 0.95, "o cartão abriu com a tela clara: ele é lido no escuro, antes de clarear")
		_conferir(relogio.dia_absoluto() == dia_antes + 1, "o cartão abriu antes de o dia virar")
		_conferir(str(amanhecer._dia.text).contains(str(relogio.dia)),
			"o cartão diz '%s', e o dia é %d" % [amanhecer._dia.text, relogio.dia])
		_conferir(not acordou[0], "o jogador acordou com o cartão ainda na tela")
		_conferir(paused, "o cartão abriu com o vale andando: o E que pula a espera vale para o mundo (bater na árvore da porta)")
		# A TECLA É DO CARTÃO. Com fome, para que comer seja possível.
		root.get_node("/root/Energia").atual = 5.0
		var bananas: int = inventario.quantidade("banana")
		await _tecla(KEY_I)
		_conferir(vale.telas.aberta() == "", "o I no cartão abriu '%s'" % vale.telas.aberta())
		await _tecla(load("res://scripts/prototipo_3d/atalhos.gd").tecla("mapa"))
		_conferir(not vale.mapa.aberto, "o M no cartão abriu o mapa")
		await _tecla(KEY_E)
		_conferir(inventario.quantidade("banana") == bananas, "o E no cartão comeu a banana da mão")
		await _tecla(KEY_ESCAPE)
		await _frames(2)
		_conferir(vale.telas.aberta() == "", "o Esc no cartão abriu '%s'" % vale.telas.aberta())
	await _esperar_ate(func() -> bool: return acordou[0], 10.0)
	_conferir(acordou[0], "a queda não terminou: o jogador ficou no escuro")
	await _frames(3)
	var hud = vale.hud
	var falas: Array = queda._falas()
	_conferir(not dialogo.ativo, "a queda ainda abriu o diálogo modal antigo")
	_conferir(hud._house_info_panel.visible, "acordado, a explicação da queda não veio no painel com fechar")
	_conferir(hud._house_info_label.text.contains(str(falas[0])) if not falas.is_empty() else false,
		"o painel da queda não mostra a explicação")
	_conferir(not paused, "a explicação da queda abriu com o vale parado")
	var botoes_fechar: Array[Node] = hud._house_info_panel.find_children("*", "Button", true, false)
	_conferir(botoes_fechar.size() == 1, "a explicação da queda não tem o botão de fechar")
	if botoes_fechar.size() == 1:
		(botoes_fechar[0] as Button).pressed.emit()
		_conferir(not hud._house_info_panel.visible, "o botão não fechou a explicação da queda")
	dia.pausado = false

	# --- 5. OS LEMBRETES SÃO OS DO 2D ------------------------------------------
	var jornada = root.get_node("/root/Jornada")
	var fe = root.get_node("/root/Fe")
	var dia_da_fazenda: int = jornada.dia
	jornada.dia = relogio.dia_absoluto()
	var lembretes: Array = queda._lembretes_do_dia()
	_conferir(lembretes.size() == 1 and str(lembretes[0]).contains("fazenda"),
		"no dia da fazenda, o cartão não lembra dela: %s" % str(lembretes))
	jornada.dia = 0
	var guardado2 := [relogio.dia, relogio.estacao]
	var uma_festa := ""
	for f in fe.FESTAS:
		uma_festa = str(f)
		break
	if uma_festa != "":
		relogio.estacao = int(fe.FESTAS[uma_festa]["estacao"])
		relogio.dia = int(fe.FESTAS[uma_festa]["dia"])
		lembretes = queda._lembretes_do_dia()
		_conferir(lembretes.size() == 1 and str(lembretes[0]) == str(fe.festa(uma_festa).get("aviso", "")),
			"no dia da festa '%s', o cartão não lembra dela: %s" % [uma_festa, str(lembretes)])
		relogio.dia = int(fe.FESTAS[uma_festa]["dia"]) % 28 + 1
		if fe.festa_de_hoje() == "":
			_conferir(queda._lembretes_do_dia().is_empty(), "num dia sem nada marcado, o cartão lembrou alguma coisa")
	relogio.dia = guardado2[0]
	relogio.estacao = guardado2[1]
	jornada.dia = dia_da_fazenda

	_fechar()


func _espaco_de(inventario, id: String) -> int:
	for i in inventario.ESPACOS_MAO:
		if str(inventario.espacos[i].get("id", "")) == id:
			return i
	return 0


func _tecla(codigo: int) -> void:
	for apertada in [true, false]:
		var evento := InputEventKey.new()
		evento.physical_keycode = codigo
		evento.keycode = codigo
		evento.pressed = apertada
		Input.parse_input_event(evento)
		await _frames(2)


func _esperar(segundos: float) -> void:
	var ate := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < ate:
		await process_frame


func _esperar_ate(pronto: Callable, segundos: float) -> void:
	var ate := Time.get_ticks_msec() + int(segundos * 1000.0)
	while not bool(pronto.call()) and Time.get_ticks_msec() < ate:
		await process_frame


func _fechar() -> void:
	if dialogo != null:
		dialogo.calar()
	print("")
	if falhas == 0:
		print("AMANHECER_OK: o cartão cabe na tela em qualquer data e sai sozinho, fica acima da tela preta da queda no tamanho do vale, o painel fechável mostra a explicação sem parar o jogo, sem tecla que abra tela, mapa ou menu ou que coma, e os lembretes são o dia da fazenda e a festa da fé")
	else:
		print("amanhecer: %d falha(s)" % falhas)
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
