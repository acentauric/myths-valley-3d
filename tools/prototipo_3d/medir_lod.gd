extends SceneTree
## A/B do LOD de vegetação na mesma carga do vale.
## Rodar com Godot (janela gráfica, não --headless):
##   godot --path prototipo_3d --script res://tools/prototipo_3d/medir_lod.gd

var _blocos: Array = []
var _bias_original: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(480.0).timeout.connect(func() -> void:
		push_error("BENCH_LOD: limite de 480 segundos excedido")
		quit(2))
	DisplayServer.window_set_size(Vector2i(1024, 576))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var game := (load("res://scenes/prototipo_3d/vale.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	var world: Node3D = game.get_node("Cenario")
	while not world.construido:
		await process_frame
	for i in range(20):
		await process_frame
	var player := game.get_node("Jogador") as Node3D
	player.set_physics_process(false)
	game.set_process(false)
	var dia := root.get_node("Dia")
	dia.set("pausado", true)
	dia.call("definir_hora", 9.0)
	var minimapas := 0
	for viewport in game.find_children("*", "SubViewport", true, false):
		var painel := viewport.get_parent().get_parent() as Control
		if painel != null:
			painel.set_process(false)
			painel.visible = false
		(viewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
		minimapas += 1
	var region := world.get("_region") as Node3D
	_blocos = region.get("_blocos_vegetacao_lod")
	for bloco in _blocos:
		var visual := bloco.visual as MultiMeshInstance3D
		_bias_original[visual.get_instance_id()] = visual.lod_bias
	var forest: PackedVector2Array = region.get("_forest")
	var forest_rect := Rect2(forest[0], Vector2.ZERO)
	for p in forest:
		forest_rect = forest_rect.expand(p)
	var center := forest_rect.get_center()
	var height: float = region.ground_height_at(Vector3(center.x, 0, center.y))
	var camera := Camera3D.new()
	camera.fov = 58.0
	camera.far = 2800.0
	game.add_child(camera)
	camera.current = true
	print("BENCH_LOD blocos=", _blocos.size(), " subviewports_desligados=", minimapas, " centro_mata=", center)
	print("BENCH_LOD_TELA janela=", DisplayServer.window_get_size(), " render=", root.get_texture().get_size())
	await _compare("perto", camera, Vector3(center.x, height + 4.0, center.y + 23.0), Vector3(center.x, height + 4.0, center.y))
	await _compare("acima", camera, Vector3(center.x, height + 55.0, center.y + 65.0), Vector3(center.x, height, center.y))
	await _compare("longe", camera, Vector3(center.x, height + 110.0, center.y + 165.0), Vector3(center.x, height, center.y))
	quit()


func _compare(label: String, camera: Camera3D, position: Vector3, target: Vector3) -> void:
	camera.position = position
	camera.look_at(target)
	var sem: Array[Dictionary] = []
	var com: Array[Dictionary] = []
	# ABBA reduz o viés de aquecimento/relógio de GPU da ordem das tomadas.
	for lod_ativo in [false, true, true, false]:
		var resultado: Dictionary = await _measure(label, lod_ativo)
		if lod_ativo:
			com.append(resultado)
		else:
			sem.append(resultado)
	print("BENCH_LOD_RESUMO %s fps_sem=%.2f fps_com=%.2f tri_sem=%.0f tri_com=%.0f draws_sem=%.0f draws_com=%.0f" % [label, _media(sem, "fps"), _media(com, "fps"), _media(sem, "triangulos"), _media(com, "triangulos"), _media(sem, "draws"), _media(com, "draws")])


func _measure(label: String, lod_ativo: bool) -> Dictionary:
	for bloco in _blocos:
		var visual := bloco.visual as MultiMeshInstance3D
		visual.visibility_range_end = float(bloco.distancia) if lod_ativo else 0.0
		visual.lod_bias = float(_bias_original[visual.get_instance_id()]) if lod_ativo else 1.0
	for i in range(40):
		await process_frame
	var triangulos := 0.0
	var draw_calls := 0.0
	var quadros := 120
	var inicio := Time.get_ticks_usec()
	for i in range(quadros):
		await process_frame
		triangulos += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var segundos := float(Time.get_ticks_usec() - inicio) / 1000000.0
	var resultado := {"fps": float(quadros) / segundos, "triangulos": triangulos / quadros, "draws": draw_calls / quadros}
	print("BENCH_LOD %s %s fps=%.2f triangulos=%.0f draws=%.0f" % [label, "com" if lod_ativo else "sem", resultado.fps, resultado.triangulos, resultado.draws])
	if "--capturar" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://scratch/lod34")
		root.get_texture().get_image().save_png("res://scratch/lod34/%s-%s.png" % [label, "com" if lod_ativo else "sem"])
	return resultado


func _media(amostras: Array[Dictionary], campo: String) -> float:
	var soma := 0.0
	for amostra in amostras:
		soma += float(amostra[campo])
	return soma / float(amostras.size())
