extends SceneTree
## Confere A FALA LONGA DO VALE, com a escolha de Sim e Não (#21).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/escolha.gd
##
## A caixa é a do 2D, adaptada (`dialogo_vale.gd`). As perguntas de 4 a 6 são
## as do `tools/gdscript/testar_escolha.gd` de lá, que atravessa com ela (#18):
## a cópia é adaptada, então o portão vem junto. As de 1 a 3 e a 7 são do vale.
##
##   1. A CAIXA ESTÁ NO VALE: por cima do HUD, inteira na janela, no tamanho
##      do vale e não no do 2D.
##   2. ELA PARA O VALE COMO UMA TELA: fecha a tela aberta, pausa a árvore e o
##      `Dia`, e o calendário continua preso — mesmo com a mochila, que o solta
##      ao fechar, fechada para a fala abrir. Fechar devolve tudo como estava.
##   3. A TECLA É DELA: com a caixa aberta, o I não abre a mochila, o Esc não
##      abre o menu, o E que passa a linha não come o que está na mão, o
##      número não troca a mão e o D não anda.
##   4. A FILA: uma fala pedida com outra aberta espera a vez, na ordem, e o
##      vale não volta a andar entre uma e outra.
##   5. A PERGUNTA NASCE SEM LADO: o rodapé mostra [A] e [D] e não oferece o
##      [E]; cinco E não respondem. A e E é Sim, D e E é Não, Esc é Não.
##   6. A TRAVA DO MARTELO, só na fala corrida: o E não passa a linha antes da
##      carência de abertura, nem a seguinte antes do respiro entre linhas.
##   7. O BALÃO CONTINUA para a fala de passagem: mostrar o balão de um
##      morador não abre a caixa nem para o vale.

var falhas := 0
var dialogo
var inventario
var dia
var relogio
var mochila
var vale


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("ESCOLHA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	dialogo = root.get_node_or_null("/root/Dialogo")
	inventario = root.get_node("/root/Inventario")
	dia = root.get_node("/root/Dia")
	relogio = root.get_node("/root/Relogio")
	mochila = root.get_node("/root/Mochila")
	_conferir(dialogo != null, "não há autoload Dialogo no vale")
	if dialogo == null:
		_fechar()
		return
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(6)
	await _mundo_pronto()
	await _frames(10)
	vale = current_scene
	dia.pausado = false

	# --- 1. A CAIXA ESTÁ NO VALE -----------------------------------------------
	_conferir(dialogo.layer > vale.hud.layer,
		"a caixa está na camada %d e o HUD na %d: o HUD desenha por cima dela" % [dialogo.layer, vale.hud.layer])
	dialogo.falar("", ["Uma fala para medir a caixa."])
	await _frames(3)
	var tela: Vector2 = vale.get_viewport().get_visible_rect().size
	var xform: Transform2D = dialogo._painel.get_global_transform_with_canvas()
	var na_tela := Rect2(xform.origin, dialogo._painel.size * xform.get_scale())
	_conferir(Rect2(Vector2.ZERO, tela).encloses(na_tela),
		"a caixa sai da janela: %s numa tela de %s" % [str(na_tela), str(tela)])
	_conferir(na_tela.size.x >= tela.x * 0.8,
		"a caixa tem %.0f px numa tela de %.0f: abriu no tamanho do 2D" % [na_tela.size.x, tela.x])
	_conferir(na_tela.end.y >= tela.y * 0.9, "a caixa não está no rodapé (acaba em %.0f de %.0f)" % [na_tela.end.y, tela.y])
	dialogo._fechar()
	await _frames(3)

	# --- 2. ELA PARA O VALE COMO UMA TELA --------------------------------------
	vale.telas.abrir("mochila")
	await _frames(3)
	_conferir(mochila.aberta, "não consegui abrir a mochila antes da fala")
	dialogo.falar("", ["A mochila fecha?", "E o vale para?"])
	await _frames(3)
	_conferir(not mochila.aberta, "a fala abriu com a mochila aberta por cima dela")
	_conferir(vale.telas.aberta() == "", "a fala abriu com a tela '%s' aberta" % vale.telas.aberta())
	_conferir(paused, "a fala abriu com o vale andando atrás dela")
	_conferir(dia.pausado, "a fala abriu com o relógio do vale andando")
	_conferir(relogio.pausado, "a mochila fechou para a fala e soltou o calendário: ele anda sozinho com o Dia parado")

	# --- 3. A TECLA É DELA -----------------------------------------------------
	inventario.adicionar("banana", 2)
	var espaco := _espaco_de("banana")
	inventario.selecionar(espaco)
	var bananas: int = inventario.quantidade("banana")
	var onde_estava: Vector3 = vale.player.global_position
	await _tecla(KEY_I)
	_conferir(not mochila.aberta, "o I abriu a mochila por cima da conversa")
	await _tecla(KEY_D)
	await _frames(4)
	_conferir(vale.player.global_position.distance_to(onde_estava) < 0.01, "o D andou com a fala aberta")
	# Com fome, para que comer seja possível: senão "não comeu" não prova nada.
	root.get_node("/root/Energia").atual = 5.0
	await _esperar(dialogo.CARENCIA_DE_ABERTURA + 0.05)
	await _tecla(KEY_E)
	_conferir(inventario.quantidade("banana") == bananas, "o E que passou a linha comeu a banana da mão")
	_conferir(dialogo.ativo and dialogo._indice == 1, "o E não passou para a segunda linha (linha %d)" % dialogo._indice)
	await _tecla(KEY_2 if espaco != 1 else KEY_3)
	_conferir(inventario.selecionado == espaco, "o número trocou a mão com a fala aberta")
	await _esperar(dialogo.CARENCIA_DA_LINHA + 0.05)
	await _tecla(KEY_ESCAPE)
	await _frames(3)
	_conferir(not dialogo.ativo, "o Esc na última linha não fechou a fala")
	_conferir(vale.telas.aberta() == "", "o Esc da fala abriu '%s'" % vale.telas.aberta())
	_conferir(not paused, "a fala fechou e deixou o vale parado")
	_conferir(not dia.pausado, "a fala fechou e deixou o relógio parado")
	_conferir(relogio.pausado, "a fala fechou e soltou o calendário")
	# Quem tinha pausado o relógio antes continua com ele pausado depois.
	dia.pausado = true
	dialogo.falar("", ["Relógio parado antes."])
	await _frames(3)
	dialogo._fechar()
	await _frames(3)
	_conferir(dia.pausado, "o relógio pausado pelo jogador voltou a andar depois da fala")
	dia.pausado = false

	# --- 4. A FILA ---------------------------------------------------------------
	dialogo.falar("", ["primeira"])
	dialogo.falar("Pedro", ["segunda"])
	await _frames(3)
	_conferir(dialogo._texto.text == "primeira", "a fila começou por '%s'" % dialogo._texto.text)
	dialogo._fechar()
	await _frames(2)
	_conferir(dialogo.ativo and dialogo._texto.text == "segunda", "a segunda fala não veio depois da primeira")
	_conferir(dialogo._nome.text == root.get_node("/root/Jogo").nome_pedro, "o Pedro não falou pelo nome dele")
	_conferir(paused, "o vale voltou a andar entre uma fala e a seguinte")
	dialogo._fechar()
	await _frames(3)
	_conferir(not paused, "a fila acabou e o vale ficou parado")

	# --- 5. A PERGUNTA NASCE SEM LADO ------------------------------------------
	var resposta := {}
	var perguntar := func() -> void:
		resposta["sim"] = await dialogo.perguntar("", "Firmar?")
	perguntar.call()
	await _frames(3)
	_conferir(not dialogo._escolheu, "a pergunta nasceu com um lado escolhido")
	var rodape := str(dialogo._rodape.text)
	_conferir(rodape.contains("[A]") and rodape.contains("[D]"), "o rodapé da pergunta não mostra [A] e [D]: '%s'" % rodape)
	_conferir(not rodape.contains("[E]"), "o rodapé oferece o [E] antes da escolha: '%s'" % rodape)
	for i in 5:
		await _tecla(KEY_E)
	_conferir(dialogo.ativo and not resposta.has("sim"), "cinco E responderam a pergunta sem escolha feita")
	await _tecla(KEY_A)
	await _tecla(KEY_E)
	await _frames(2)
	_conferir(resposta.get("sim", null) == true, "A e E não responderam Sim (%s)" % str(resposta.get("sim", "nada")))
	resposta.clear()
	perguntar.call()
	await _frames(3)
	await _tecla(KEY_D)
	await _tecla(KEY_E)
	await _frames(2)
	_conferir(resposta.get("sim", null) == false, "D e E não responderam Não (%s)" % str(resposta.get("sim", "nada")))
	resposta.clear()
	perguntar.call()
	await _frames(3)
	await _tecla(KEY_A)
	await _tecla(KEY_ESCAPE)
	await _frames(2)
	_conferir(resposta.get("sim", null) == false, "o Esc não respondeu Não (%s)" % str(resposta.get("sim", "nada")))
	_conferir(vale.telas.aberta() == "", "o Esc da pergunta abriu '%s'" % vale.telas.aberta())
	await _frames(3)

	# --- 6. A TRAVA DO MARTELO -----------------------------------------------
	dialogo.falar("", ["um", "dois", "três"])
	await _frames(3)
	await _tecla(KEY_E)
	_conferir(dialogo._indice == 0, "o E passou a linha antes da carência de abertura")
	await _esperar(dialogo.CARENCIA_DE_ABERTURA + 0.05)
	await _tecla(KEY_E)
	_conferir(dialogo._indice == 1, "depois da carência, o E não passou a linha")
	await _tecla(KEY_E)
	_conferir(dialogo._indice == 1, "o E passou duas linhas sem o respiro entre elas")
	await _esperar(dialogo.CARENCIA_DA_LINHA + 0.05)
	await _tecla(KEY_E)
	_conferir(dialogo._indice == 2, "depois do respiro, o E não passou a linha")
	dialogo._fechar()
	await _frames(3)

	# --- 7. O BALÃO CONTINUA ---------------------------------------------------
	var morador = get_first_node_in_group("moradores")
	_conferir(morador != null, "não achei um morador para o balão")
	if morador != null:
		morador.mostrar_balao("Bom dia.", 2.0)
		await _frames(2)
		_conferir(morador.balao.visible, "o balão do morador não apareceu")
		_conferir(not dialogo.ativo, "a fala de passagem abriu a caixa de fala longa")
		_conferir(not paused, "a fala de passagem parou o vale")

	_fechar()


func _espaco_de(id: String) -> int:
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


## Espera pelo relógio de parede, que é o que as carências da caixa medem.
func _esperar(segundos: float) -> void:
	var ate := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < ate:
		await process_frame


func _fechar() -> void:
	if dialogo != null and dialogo.ativo:
		dialogo._fechar()
	print("")
	if falhas == 0:
		print("ESCOLHA_OK: a caixa de fala fica por cima do HUD, inteira na janela e no tamanho do vale, para o vale e o relógio como uma tela e fecha a que estava aberta sem soltar o calendário, segura o teclado (I, Esc, E da mão, números, andar), enfileira as falas sem soltar o vale entre elas, a pergunta nasce sem lado e responde Sim, Não e Esc, a trava do martelo segura o E, e o balão continua para a fala de passagem")
	else:
		print("escolha: %d falha(s)" % falhas)
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
