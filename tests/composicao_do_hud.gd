extends "res://tests/suite/caso.gd"
## Composição real da chegada: missão, fala e aviso de espera juntos (#120).
var falhas := 0
func _initialize() -> void:
	_run.call_deferred()
	create_timer(180).timeout.connect(func(): quit(2))
func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: " + texto)
func _run() -> void:
	await process_frame
	if "--componentes" in OS.get_cmdline_user_args():
		var tela := root.get_node("Tela")
		for chave: String in tela.COMPONENTES:
			tela.definir_componente(chave, 5)
		# Contraste proposital: relógio pequeno junto de medidores grandes.
		tela.definir_componente("relogio", 0)
	root.get_node("Estilo").modo = "tripo"
	change_scene_to_file("res://scenes/prototipo_3d/vale.tscn")
	await process_frame
	while current_scene == null or current_scene.get("carga_ok") != true:
		await process_frame
	var vale := current_scene
	vale.apresentacao_do_povoado.set_process(false)
	root.get_node("Dia").pausado = true
	for pessoa in get_nodes_in_group("moradores"):
		pessoa._calar_a_boca()
		pessoa.set_physics_process(false)
		for filho in pessoa.get_children():
			if filho.get_script() == load("res://scripts/prototipo_3d/cadeia_de_missoes.gd"):
				filho.set_process(false)
	var pedro: Node3D = vale.pedro
	pedro._cadeia.set_process(false)
	var candinha: Node3D = vale._achar_morador("candinha")
	vale.player.global_position = vale.world.ground_position(candinha.global_position + Vector3(0, 0, 5), 0.07)
	vale.player.set_physics_process(false)
	pedro.global_position = vale.world.ground_position(vale.player.global_position + Vector3(-1, 0, -2), 0.07)
	var camera := Camera3D.new()
	vale.add_child(camera)
	camera.global_position = vale.player.global_position + Vector3(0, 4, 8)
	camera.look_at(vale.player.global_position + Vector3.UP * 1.1)
	camera.make_current()
	var hud: Node = vale.hud
	var barra: Control = hud.barra_de_mao()
	var passo: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/missoes_guia.json")).passos[3]
	var idioma = load("res://scripts/prototipo_3d/idioma_menu.gd")
	var textos := ["Pedro está esperando você: volte para perto para seguir.", "Pedro is waiting for you: come closer to continue.", "Pedro te espera: acércate para continuar."]
	for i in 3:
		idioma.definir(i)
		hud.set_objective(str(idioma.campo(passo, "resumo")), str(idioma.campo(passo, "titulo")))
		hud.set_mission_step(4, 16)
		hud.set_aviso_de_espera(textos[i])
		hud.set_notice("")
		pedro.balao.mostrar(str(idioma.campo(passo, "texto")))
		if "--mostrar-nome" in OS.get_cmdline_user_args():
			barra.get_node("NaMao").show()
		for _j in 10:
			await process_frame
		conferir(not barra.get_node("NaMao").visible, "sem rótulo persistente acima da barra, idioma " + str(i))
		conferir(hud._heading.visible and not hud._objective_label.text.is_empty(), "missão permanece compreensível")
		conferir(pedro.balao.visible and pedro.balao.retangulo().has_area(), "fala real permanece legível")
		if hud._espera_panel.visible:
			conferir(not hud._espera_panel.get_global_rect().intersects(pedro.balao.retangulo()), "aviso e fala não se cobrem")
			conferir(not hud._espera_panel.get_global_rect().intersects(hud._heading.get_global_rect()), "aviso não cobre missão ampliada")
		conferir(not hud._notice.contains(str(idioma.campo(passo, "texto"))), "sem repetição da fala no rodapé")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var pasta := "res://scratch/componentes-interface" if "--componentes" in OS.get_cmdline_user_args() else "res://scratch/composicao-hud"
			DirAccess.make_dir_recursive_absolute(pasta)
			root.get_texture().get_image().save_png(pasta + "/idioma-%d.png" % i)
		pedro.balao.esconder()
	idioma.definir(0)
	print("COMPOSICAO_HUD: %d falhas" % falhas)
	quit(0 if falhas == 0 else 1)
