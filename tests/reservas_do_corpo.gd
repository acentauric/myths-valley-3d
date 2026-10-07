extends SceneTree
## AS TRÊS CONTAS DO CORPO (#82): a reserva do dia, o vigor e o fôlego do nado.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/reservas_do_corpo.gd
##     ... --script res://tests/reservas_do_corpo.gd -- --somente-hud      (só a interface)
##     ... --script res://tests/reservas_do_corpo.gd -- --falsificar       (tem de reprovar)
##
## Entre 04/10 e 06/10 a reserva (`Energia`) espelhou o vigor do corpo, e o
## vigor volta sozinho: a comida, a cama e os talentos de reserva perderam a
## função. Decisão do autor em 06/10: a reserva volta a ser a que sempre foi.
##
##   1. EM TERRA, TRÊS CONTAS SEPARADAS. O esforço do braço (`gastar_vigor`) não
##      toca a reserva nem o fôlego do nado; o trabalho e a luta (`Energia.gastar`)
##      cobram a reserva e não o vigor; a comida repõe a reserva. No fim da
##      reserva o corpo cansa (passo curto, sem corrida) e a barra do meio — que
##      em terra mostra SÓ O NÚMERO da reserva — diz "cansado" e fica vermelha.
##      O vigor baixo fica âmbar, sem roubar a palavra.
##   2. NA ÁGUA a barra do meio vira o fôlego do nado: o nado gasta o vigor
##      primeiro e só depois o fôlego; sem fôlego a água tira 20% da vida por
##      segundo, também com o vale pausado; parar recupera os dois; o nado
##      rápido custa o dobro de vigor; a reserva do dia não entra na conta.
##   3. FORA DA ÁGUA a barra volta à reserva; quem apaga acorda respirando; o
##      esforço sem vigor é recusado sem cobrar conta nenhuma; a corrida em
##      terra gasta só vigor; o save guarda o fôlego do nado.
##   4. A APRESENTAÇÃO: o teto da reserva acompanha a progressão, os nomes vêm
##      traduzidos, o número cabe na barra, e as três ficam alinhadas na janela.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, motivo: String) -> void:
	if not ok:
		print("FALHA: ", motivo)
		falhas += 1


func _run() -> void:
	if "--somente-hud" in OS.get_cmdline_user_args():
		await _somente_hud()
		return
	var cena: PackedScene = load("res://scenes/prototipo_3d/vale.tscn")
	var instancia := cena.instantiate()
	# Falsificação em memória: simula a cobrança do nado ausente sem tocar no código
	# usado pela bateria ou pelo editor aberto do autor.
	if "--falsificar" in OS.get_cmdline_user_args():
		var original: Script = instancia.get_node("Jogador").get_script()
		var modelo: PackedScene = instancia.get_node("Jogador").model_scene
		var quebrado := GDScript.new()
		quebrado.source_code = original.source_code.replace("\t\t_cobrar_folego(CUSTO_FOLEGO_NADO_POR_SEGUNDO * (delta - tempo_com_vigor))", "\t\tpass # cobrança do nado ausente")
		_conferir(quebrado.source_code != original.source_code, "a falsificação não encontrou o consumo de fôlego no nado")
		_conferir(quebrado.reload() == OK, "a falsificação não compilou")
		instancia.get_node("Jogador").set_script(quebrado)
		instancia.get_node("Jogador").model_scene = modelo
	root.add_child(instancia)
	current_scene = instancia
	await process_frame
	await process_frame
	var jogo = current_scene
	var mundo = jogo.get_node("Cenario")
	if not mundo.construido:
		await mundo.pronto
	for i in range(12):
		await physics_frame
	var jogador = jogo.get_node("Jogador")
	var hud = jogo.get_node("HUD")
	var energia = root.get_node("Energia")
	var vida = root.get_node("Vida")
	jogador.set_physics_process(false)
	vida.dormir()
	jogador.definir_vigor(100.0)
	jogador.definir_folego(100.0)
	energia.encher()
	var saude: float = vida.atual

	# --- 1. EM TERRA, TRÊS CONTAS SEPARADAS -----------------------------------
	_conferir(not jogador.is_swimming(), "o jogador começa na água")
	_conferir(jogador.gastar_vigor(10.0), "o esforço foi recusado")
	_conferir(is_equal_approx(jogador.vigor_atual(), 90.0), "o esforço não gastou vigor")
	_conferir(is_equal_approx(energia.atual, energia.maximo()), "o esforço do braço gastou a reserva do dia")
	_conferir(jogador.folego_atual() == 100.0 and vida.atual == saude, "o esforço em terra gastou fôlego ou vida")
	_conferir(hud.barra_stamina.value == 90.0, "a barra de vigor não acompanhou o esforço")
	_conferir(is_equal_approx(hud.barra_folego.value, energia.atual) and hud.barra_folego.max_value == energia.maximo(),
		"em terra a barra do meio não é a reserva do dia")
	_conferir(hud._folego_texto.text == str(roundi(energia.atual)),
		"em terra a barra do meio não mostra só o número: '%s'" % hud._folego_texto.text)
	var custo_bater: float = energia.custo("bater")
	_conferir(energia.gastar("bater"), "a reserva cheia recusou bater")
	_conferir(is_equal_approx(energia.atual, energia.maximo() - custo_bater), "bater não cobrou a reserva")
	_conferir(is_equal_approx(jogador.vigor_atual(), 90.0), "bater cobrou o vigor")
	energia.repor(custo_bater)
	_conferir(is_equal_approx(energia.atual, energia.maximo()) and is_equal_approx(jogador.vigor_atual(), 90.0),
		"comida não repôs a reserva, ou mexeu no vigor")
	energia.definir(energia.maximo() * 0.1)
	_conferir(energia.cansado() and is_equal_approx(energia.passo(), energia.PESO_DO_CANSACO), "um décimo da reserva não cansou o corpo")
	_conferir(hud._folego_texto.text.contains("cansado") and hud._folego_preenchimento.bg_color == hud.COR_RESERVA_BAIXA,
		"no fim da reserva a barra do meio não diz 'cansado' nem muda de cor: '%s'" % hud._folego_texto.text)
	jogador.set("_run_toggled", true)
	_conferir(not jogador.is_running(), "cansado, o corpo ainda corre")
	energia.encher()
	_conferir(jogador.is_running(), "com a reserva cheia e o vigor em 90, a corrida não volta")
	jogador.set("_run_toggled", false)
	_conferir(not hud._folego_texto.text.contains("cansado") and hud._folego_preenchimento.bg_color == hud.COR_RESERVA,
		"a reserva cheia continuou 'cansada'")
	jogador.definir_vigor(15.0)
	_conferir(hud._stamina_preenchimento.bg_color == hud.COR_MEDIDOR_BAIXO and not hud._stamina_texto.text.contains("cansado"),
		"vigor baixo não ficou âmbar, ou roubou a palavra da reserva: '%s'" % hud._stamina_texto.text)
	jogador.definir_vigor(100.0)
	_conferir(hud._stamina_preenchimento.bg_color == hud.COR_VIGOR and hud._stamina_texto.text == "100/100",
		"a barra de vigor não voltou ao verde com o nome: '%s'" % hud._stamina_texto.text)

	# --- 2. NA ÁGUA, A BARRA DO MEIO VIRA O FÔLEGO DO NADO --------------------
	var reserva_antes: float = energia.atual
	jogador._definir_nado(true)
	_conferir(jogador.is_swimming(), "o corpo não entrou no nado")
	_conferir(hud.barra_folego.value == 100.0 and hud._folego_texto.text == "100/100"
		and hud._folego_preenchimento.bg_color == hud.COR_FOLEGO,
		"nadando, a barra do meio não virou o fôlego do nado: '%s'" % hud._folego_texto.text)
	var timer_afogamento: Timer = jogador.get_node("DanoSemFolego")
	timer_afogamento.wait_time = 0.05
	jogador.velocity = Vector3(1, 0, 0)
	jogador._atualizar_vigor(1.0, false)
	_conferir(is_equal_approx(jogador.vigor_atual(), 95.0) and jogador.folego_atual() == 100.0 and vida.atual == saude,
		"nadar com vigor deve gastar vigor (5/s), poupar o fôlego e não ferir")
	_conferir(is_equal_approx(energia.atual, reserva_antes), "o nado cobrou a reserva do dia")
	jogador.definir_vigor(2.0)
	jogador.definir_folego(3.0)
	jogador._atualizar_vigor(1.0, false)
	_conferir(jogador.vigor_atual() == 0.0 and is_equal_approx(jogador.folego_atual(), 1.0) and vida.atual == saude,
		"ao esgotar o vigor no meio do nado, só o tempo restante consome fôlego")
	jogador._atualizar_vigor(1.0, false)
	_conferir(jogador.folego_atual() == 0.0 and is_equal_approx(vida.atual, saude),
		"o fôlego zerado feriu antes de um segundo completo")
	# Sem fôlego o timer tem de estar ligado; esperar um timer parado travaria o
	# portão em vez de reprová-lo (é o que a falsificação faz: o fôlego nunca zera).
	_conferir(not timer_afogamento.is_stopped(), "sem fôlego no nado, o timer do afogamento não ligou")
	if timer_afogamento.is_stopped():
		jogador.definir_folego(0.0)
	await timer_afogamento.timeout
	_conferir(is_equal_approx(vida.atual, saude - vida.maximo() * 0.20),
		"o timer real não retirou 20% da vida depois de um segundo sem fôlego")
	await timer_afogamento.timeout
	_conferir(is_equal_approx(vida.atual, saude - vida.maximo() * 0.40),
		"o segundo consecutivo sem fôlego não retirou outros 20%")
	await timer_afogamento.timeout
	_conferir(is_equal_approx(vida.atual, saude - vida.maximo() * 0.60),
		"o terceiro segundo consecutivo sem fôlego não retirou outros 20%")
	_conferir(hud.barra_folego.value == 0.0 and hud.barra_vida.value == vida.atual, "o HUD não acompanhou o nado")
	_conferir(hud._folego_texto.text.contains("afogamento"), "o HUD não avisou o afogamento")
	jogador.velocity = Vector3.ZERO
	jogador._atualizar_vigor(1.0, false)
	_conferir(is_equal_approx(jogador.vigor_atual(), 20.0) and is_equal_approx(jogador.folego_atual(), 10.0)
		and is_equal_approx(vida.atual, saude - vida.maximo() * 0.60),
		"parar na água não recuperou vigor e fôlego, ou continuou ferindo")
	jogador.definir_vigor(0.0)
	jogador.definir_folego(0.0)
	jogador.velocity = Vector3(1, 0, 0)
	vida.dormir()
	_conferir(timer_afogamento.process_mode == Node.PROCESS_MODE_ALWAYS,
		"o timer de afogamento não continua durante pausas")
	paused = true
	await timer_afogamento.timeout
	paused = false
	_conferir(is_equal_approx(vida.atual, vida.maximo() * 0.80),
		"o timer não aplicou dano real com a física do vale pausada")
	jogador.definir_vigor(40.0)
	jogador.definir_folego(50.0)
	jogador._atualizar_vigor(1.0, true)
	_conferir(is_equal_approx(jogador.vigor_atual(), 30.0) and jogador.folego_atual() > 50.0,
		"nado rápido não gastou mais vigor que o nado normal")
	_conferir(is_equal_approx(energia.atual, reserva_antes), "o nado mexeu na reserva do dia")

	# --- 3. FORA DA ÁGUA A BARRA VOLTA À RESERVA ------------------------------
	jogador.definir_folego(0.0)
	jogador.sair_do_nado_ao_renascer()
	_conferir(not jogador.is_swimming() and timer_afogamento.is_stopped(), "o timer continuou ativo depois de sair do nado")
	_conferir(jogador.folego_atual() == jogador.folego_maximo(), "quem acordou em casa não voltou respirando")
	_conferir(is_equal_approx(hud.barra_folego.value, energia.atual) and hud._folego_texto.text == str(roundi(energia.atual)),
		"fora da água a barra do meio não voltou à reserva: '%s'" % hud._folego_texto.text)
	_conferir(hud.barra_vida.value == vida.atual and hud._vida_texto.text.contains("/"), "a barra de vida perdeu valor ou descrição")
	var vigor: float = jogador.vigor_atual()
	var saude_antes: float = vida.atual
	var reserva: float = energia.atual
	_conferir(not jogador.gastar_vigor(vigor + 1.0), "o corpo aceitou esforço sem vigor")
	_conferir(jogador.vigor_atual() == vigor and vida.atual == saude_antes and energia.atual == reserva,
		"esforço recusado cobrou alguma conta")
	jogador.definir_vigor(100.0)
	jogador.definir_folego(50.0)
	jogador._atualizar_vigor(1.0, true)
	_conferir(jogador.vigor_atual() == 95.0 and jogador.folego_atual() == 50.0 and is_equal_approx(energia.atual, reserva),
		"a corrida em terra cobrou o fôlego do nado ou a reserva")
	var estado: Dictionary = jogo.estado_para_salvar()
	jogador.definir_folego(99.0)
	jogo.restaurar_do_save(estado)
	_conferir(jogador.folego_atual() == 50.0, "o save não restaurou o fôlego do nado")

	# --- 4. A APRESENTAÇÃO ------------------------------------------------------
	await _conferir_apresentacao(hud, jogador)
	print("RESERVAS_DO_CORPO_OK: reserva, vigor e fôlego do nado em contas próprias; a barra do meio troca na água; HUD, descanso e save"
		if falhas == 0 else "reservas_do_corpo: %d falhas" % falhas)
	quit(1 if falhas > 0 else 0)


func _somente_hud() -> void:
	# Conferência gráfica leve: a mesma interface, sem renderizar a vila inteira.
	var jogador = load("res://scripts/prototipo_3d/player_controller.gd").new()
	var hud = load("res://scripts/prototipo_3d/prototype_hud.gd").new()
	root.add_child(hud)
	hud.configurar_corpo(jogador)
	jogador.definir_vigor(85.0)
	jogador.definir_folego(15.0)
	root.get_node("Vida").ferir(2.0)
	await process_frame
	await _conferir_apresentacao(hud, jogador)
	jogador.free()
	print("HUD_MEDIDORES_OK: rótulos, valores, idiomas e geometria" if falhas == 0 else "hud_medidores: %d falhas" % falhas)
	quit(1 if falhas > 0 else 0)


func _conferir_apresentacao(hud, jogador) -> void:
	var progressao = root.get_node("Progressao")
	progressao.energia_maxima = 120.0
	progressao.mudou.emit()
	hud._ao_mudar_o_nado(false)
	_conferir(hud.barra_folego.max_value == 120.0, "o HUD perdeu o teto da reserva ao progredir")
	var idioma = load("res://scripts/prototipo_3d/idioma_menu.gd")
	# Em terra: a vida e o vigor com o nome; a reserva só com o número. Na água, o
	# fôlego do nado com o nome.
	var rotulos := [["Vida", "Vigor", "Fôlego"], ["Health", "Stamina", "Breath"], ["Salud", "Resistencia", "Aliento"]]
	for indice in range(3):
		idioma.definir(indice)
		hud._atualizar_vida()
		hud._atualizar_vigor()
		hud._ao_mudar_o_nado(false)
		_conferir(hud.barra_vida.tooltip_text == rotulos[indice][0] and hud._vida_texto.text.contains("/"), "a vida perdeu o nome traduzido: '%s'" % hud._vida_texto.text)
		_conferir(hud.barra_stamina.tooltip_text == rotulos[indice][1] and hud._stamina_texto.text.contains("/"), "o vigor perdeu o nome traduzido: '%s'" % hud._stamina_texto.text)
		_conferir(hud._folego_texto.text.is_valid_int(), "em terra a barra do meio tem mais que o número: '%s'" % hud._folego_texto.text)
		hud._ao_mudar_o_nado(true)
		_conferir(hud.barra_folego.tooltip_text == rotulos[indice][2] and hud._folego_texto.text.contains("/"), "nadando, a barra do meio não diz o fôlego traduzido: '%s'" % hud._folego_texto.text)
		var textos: Array[Label] = [hud._vida_texto, hud._folego_texto, hud._stamina_texto]
		for texto in textos:
			var fonte: Font = texto.get_theme_font("font")
			_conferir(fonte.get_string_size(texto.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x <= 138.0, "descrição não cabe na barra: '%s'" % texto.text)
		hud._ao_mudar_o_nado(false)
	idioma.definir(0)
	hud._atualizar_vida()
	hud._atualizar_vigor()
	hud._ao_mudar_o_nado(jogador.is_swimming())
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://scratch/retomada-hud")
		root.get_texture().get_image().save_png("res://scratch/retomada-hud/medidores.png")
	# O agrupamento permanece dentro da janela ao redimensionar.
	for tamanho in [Vector2i(1280, 720), Vector2i(800, 600)]:
		root.size = tamanho
		await process_frame
		if "--falsificar-layout" in OS.get_cmdline_user_args():
			hud._clock_panel.size = Vector2(140, 54)
			hud.barra_vida.position.x = hud._clock_panel.position.x
		var relogio: Rect2 = hud._clock_panel.get_global_rect()
		_conferir(relogio.size.x < 140 and relogio.size.y < 54, "relogio nao foi compactado")
		_conferir(not relogio.intersects(hud._heading.get_global_rect()), "relogio cobre a missao")
		_conferir(hud._icones_medidores.size() == 3, "faltam os tres icones do corpo")
		var anterior := Rect2()
		for barra: ProgressBar in [hud.barra_vida, hud.barra_folego, hud.barra_stamina]:
			var quadro := barra.get_global_rect()
			_conferir(quadro.position.x >= relogio.end.x and not quadro.intersects(hud._heading.get_global_rect()), "recursos nao ficam a direita do relogio sem cobrir missao")
			# O projeto usa canvas_items: os retângulos estão no viewport lógico,
			# que é escalado para a janela física solicitada acima.
			_conferir(root.get_visible_rect().encloses(quadro), "medidor saiu da janela")
			_conferir(barra.mouse_filter == Control.MOUSE_FILTER_IGNORE, "medidor captura cliques do mundo")
			if anterior.size != Vector2.ZERO:
				_conferir(quadro.position.x == anterior.position.x and quadro.size == anterior.size and quadro.position.y >= anterior.end.y, "medidores não ficam alinhados e separados")
			anterior = quadro
