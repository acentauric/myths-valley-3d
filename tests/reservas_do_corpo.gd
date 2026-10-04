extends SceneTree
## Vigor no esforço; fôlego e vida no nado, com HUD e restauração.

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
	var saude: float = vida.atual
	_conferir(jogador.gastar_vigor(10.0), "o esforço foi recusado")
	_conferir(is_equal_approx(jogador.vigor_atual(), 90.0) and is_equal_approx(energia.atual, 90.0), "vigor e Energia divergiram")
	_conferir(is_equal_approx(jogador.folego_atual(), 100.0) and vida.atual == saude, "o esforço em terra gastou fôlego ou vida")
	_conferir(hud.barra_stamina.value == 90.0 and hud.barra_folego.value == 100.0, "o HUD não separou vigor e fôlego")
	jogador.definir_folego(3.0)
	_conferir(jogador.gastar_vigor(5.0), "o esforço com pouco fôlego foi recusado")
	_conferir(jogador.folego_atual() == 3.0 and vida.atual == saude, "o esforço em terra atingiu o fôlego baixo ou a vida")
	jogador.set("_nadando", true)
	jogador.velocity = Vector3(1, 0, 0)
	jogador._atualizar_vigor(1.0, false)
	_conferir(jogador.vigor_atual() == 80.0 and jogador.folego_atual() > 3.0 and vida.atual == saude,
		"nadar com vigor deve gastar vigor e recuperar fôlego sem ferir")
	jogador.definir_vigor(2.0)
	jogador.definir_folego(3.0)
	jogador._atualizar_vigor(1.0, false)
	_conferir(jogador.vigor_atual() == 0.0 and is_equal_approx(jogador.folego_atual(), 1.0) and vida.atual == saude,
		"ao esgotar vigor no meio do nado, só o tempo restante deve consumir fôlego")
	jogador._atualizar_vigor(1.0, false)
	_conferir(jogador.folego_atual() == 0.0 and is_equal_approx(vida.atual, saude - 4.0),
		"nadar sem vigor deve consumir fôlego e só o excedente deve atingir a vida")
	_conferir(hud.barra_folego.value == 0.0 and hud.barra_vida.value == vida.atual, "o HUD não acompanhou o nado")
	jogador.set("_nadando", false)
	_conferir(hud.barra_vida.value == vida.atual and hud._vida_texto.text.begins_with("Vida "), "a barra de vida perdeu valor ou descrição")
	_conferir(hud._folego_texto.text.contains("cansado"), "o HUD não avisa sobre pouco fôlego")
	var vigor: float = jogador.vigor_atual()
	var saude_antes: float = vida.atual
	_conferir(not jogador.gastar_vigor(vigor + 1.0), "o corpo aceitou esforço sem vigor")
	_conferir(jogador.vigor_atual() == vigor and vida.atual == saude_antes, "esforço recusado cobrou reservas")
	jogador.definir_vigor(100.0)
	_conferir(vida.atual == saude_antes and jogador.folego_atual() == 0.0, "restaurar vigor cobrou ou repôs outra reserva")
	# Respiração recupera mesmo quando o vigor já está cheio.
	jogador.velocity = Vector3.ZERO
	jogador._atualizar_vigor(1.0, false)
	_conferir(jogador.folego_atual() > 0.0 and vida.atual == saude_antes, "descansar não recuperou fôlego ou curou vida")
	jogador.definir_folego(50.0)
	jogador._atualizar_vigor(1.0, true)
	_conferir(jogador.vigor_atual() == 95.0 and jogador.folego_atual() == 50.0, "corrida alterou o fôlego fora d'água")
	energia.gastar("bater")
	_conferir(jogador.vigor_atual() == 90.0 and jogador.folego_atual() == 50.0, "trabalho/luta alteraram o fôlego fora d'água")
	energia.repor(5.0)
	_conferir(jogador.vigor_atual() == 95.0 and jogador.folego_atual() == 50.0, "comida não repôs vigor ou alterou fôlego")
	var estado: Dictionary = jogo.estado_para_salvar()
	jogador.definir_folego(99.0)
	jogo.restaurar_do_save(estado)
	_conferir(jogador.folego_atual() == 50.0 and hud.barra_folego.value == 50.0, "save não restaurou fôlego e HUD")
	energia.dormir()
	_conferir(jogador.folego_atual() == jogador.folego_maximo(), "sono não recuperou respiração")
	jogador.definir_folego(0.0)
	energia.desmaiar()
	_conferir(jogador.folego_atual() == jogador.folego_maximo(), "desmaio não recuperou respiração")
	await _conferir_apresentacao(hud)
	print("RESERVAS_DO_CORPO_OK: vigor antes do fôlego no nado, vida, HUD, descanso e save" if falhas == 0 else "reservas_do_corpo: %d falhas" % falhas)
	quit(1 if falhas > 0 else 0)

func _somente_hud() -> void:
	# Conferência gráfica leve: a mesma interface, sem renderizar a vila inteira.
	var jogador = load("res://scripts/prototipo_3d/player_controller.gd").new()
	var energia = root.get_node("Energia")
	energia.registrar_vigor(jogador)
	var hud = load("res://scripts/prototipo_3d/prototype_hud.gd").new()
	root.add_child(hud)
	hud.configurar_folego(jogador)
	jogador.definir_vigor(85.0)
	jogador.definir_folego(15.0)
	root.get_node("Vida").ferir(2.0)
	await process_frame
	await _conferir_apresentacao(hud)
	energia.desregistrar_vigor(jogador)
	jogador.free()
	print("HUD_MEDIDORES_OK: rótulos, valores, idiomas e geometria" if falhas == 0 else "hud_medidores: %d falhas" % falhas)
	quit(1 if falhas > 0 else 0)

func _conferir_apresentacao(hud) -> void:
	var progressao = root.get_node("Progressao")
	progressao.energia_maxima = 120.0
	progressao.mudou.emit()
	_conferir(hud.barra_stamina.max_value == 120.0, "o HUD perdeu o teto de vigor ao progredir")
	var idioma = load("res://scripts/prototipo_3d/idioma_menu.gd")
	var rotulos := [["Vida", "Fôlego", "Vigor"], ["Health", "Breath", "Stamina"], ["Salud", "Aliento", "Resistencia"]]
	for indice in range(3):
		idioma.definir(indice)
		hud._atualizar_vida()
		hud._atualizar_folego()
		hud._atualizar_vigor()
		var textos: Array[Label] = [hud._vida_texto, hud._folego_texto, hud._stamina_texto]
		for i in range(3):
			_conferir(textos[i].text.begins_with(rotulos[indice][i] + " "), "medidor perdeu o nome traduzido")
			var fonte: Font = textos[i].get_theme_font("font")
			_conferir(fonte.get_string_size(textos[i].text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x <= 220.0, "descrição não cabe na barra")
	idioma.definir(0)
	hud._atualizar_vida()
	hud._atualizar_folego()
	hud._atualizar_vigor()
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://scratch/retomada-hud")
		root.get_texture().get_image().save_png("res://scratch/retomada-hud/medidores.png")
	# O agrupamento permanece dentro da janela ao redimensionar.
	for tamanho in [Vector2i(1280, 720), Vector2i(800, 600)]:
		root.size = tamanho
		await process_frame
		var anterior := Rect2()
		for barra: ProgressBar in [hud.barra_vida, hud.barra_folego, hud.barra_stamina]:
			var quadro := barra.get_global_rect()
			_conferir(Rect2(Vector2.ZERO, Vector2(tamanho)).encloses(quadro), "medidor saiu da janela")
			_conferir(barra.mouse_filter == Control.MOUSE_FILTER_IGNORE, "medidor captura cliques do mundo")
			if anterior.size != Vector2.ZERO:
				_conferir(quadro.position.x == anterior.position.x and quadro.size == anterior.size and quadro.position.y >= anterior.end.y, "medidores não ficam alinhados e separados")
			anterior = quadro
