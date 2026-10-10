extends "res://tests/suite/caso.gd"
## A vara de cenário sai; peixe, pote, piso e ferramenta de pesca permanecem.
var falhas := 0

func _initialize() -> void:
	_run.call_deferred()

func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		push_error("PIER_LEGIVEL: " + texto)
		print("FALHA: " + texto)

func _run() -> void:
	root.get_node("Estilo").modo = "tripo"
	change_scene_to_file("res://scenes/prototipo_3d/vale.tscn")
	for i in 5000:
		await process_frame
		if current_scene != null and current_scene.world != null and current_scene.world.construido:
			break
	var mundo = current_scene.world
	var catalogo = load("res://scripts/prototipo_3d/catalogo_assets.gd")
	var piso: Vector3 = mundo.ancoras.get("PierPiso", Vector3.INF)
	conferir(piso.is_finite(), "o píer perdeu sua âncora")
	if "--falsificar" in OS.get_cmdline_user_args():
		catalogo.instanciar("vara_pescar", mundo, piso)
	var varas := 0
	var peixes := 0
	var potes := 0
	for no in mundo.get_children():
		if not no is Node3D or no.global_position.distance_to(piso) > 8:
			continue
		if str(no.get_meta("peca", "")) == "vara_pescar":
			varas += 1
		if str(no.get_meta("peca", "")) == "peixe":
			peixes += 1
		if str(no.get_meta("peca", "")) == "pote":
			potes += 1
	conferir(varas == 0, "a vara decorativa continua no caminho dos personagens")
	conferir(peixes > 0 and potes > 0, "a remoção atingiu os demais objetos do píer")
	conferir(catalogo.tem_tripo("vara_pescar"), "a ferramenta funcional de pesca foi removida do catálogo")
	await physics_frame
	var consulta := PhysicsRayQueryParameters3D.create(piso + Vector3.UP * 2, piso - Vector3.UP * 2, 1)
	conferir(not current_scene.get_world_3d().direct_space_state.intersect_ray(consulta).is_empty(), "o piso do píer perdeu colisão")
	if "--capturar" in OS.get_cmdline_user_args():
		var camera := Camera3D.new()
		current_scene.add_child(camera)
		camera.global_position = piso + mundo.ancoras.get("PierDirecao", Vector3.FORWARD) * 7 + Vector3.UP * 4
		camera.look_at(piso + Vector3.UP)
		camera.current = true
		await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://scratch/pier-legivel")
		root.get_texture().get_image().save_png("res://scratch/pier-legivel/pier.png")
	print("PIER_LEGIVEL: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
