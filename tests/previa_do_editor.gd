extends SceneTree
## Executar também com --editor para provar o carregamento sob editor_hint real.
var falhas := 0
func _initialize() -> void:
	_run.call_deferred()
func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: ", texto)
func _run() -> void:
	await process_frame
	var vista := SubViewport.new()
	vista.size = Vector2i(1280, 720)
	vista.own_world_3d = true
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vista)
	var host: Node3D = load("res://scripts/prototipo_3d/terreno_editor_preview.gd").new()
	vista.add_child(host)
	for i in 10: await process_frame
	if "--sem-previa" in OS.get_cmdline_user_args():
		if Engine.is_editor_hint():
			for filho in host.get_children(true): filho.free()
		else:
			host.add_child(Node3D.new())
	if Engine.is_editor_hint():
		var previa: Node = host.get_node_or_null("Previa")
		conferir(previa != null, "editor instancia a composição sem executar o jogo")
		if previa != null:
			var base: Node = previa.get_node_or_null("BaseGeografica")
			conferir(base != null, "editor carrega a base geográfica interna")
			if base != null:
				var terras: Array[Node] = base.find_children("Terra", "MeshInstance3D", true, false)
				conferir(terras.size() == 1, "prévia contém uma malha de terra")
				if not terras.is_empty():
					var terra := terras[0] as MeshInstance3D
					conferir(terra.mesh != null and terra.mesh.get_aabb().size.y > 40.0, "malha renderizável contém o relevo persistido")
			conferir(host.get_children().is_empty(), "prévia interna não entra na cena autoral salva")
		if "--capturar" in OS.get_cmdline_user_args():
			var camera := Camera3D.new()
			vista.add_child(camera)
			camera.position = Vector3(60, 100, 0)
			camera.look_at(Vector3(40, 0, -90))
			camera.far = 2000.0
			camera.current = true
			var luz := DirectionalLight3D.new()
			luz.rotation_degrees = Vector3(-55, -25, 0)
			vista.add_child(luz)
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://scratch/previa-editor")
			vista.get_texture().get_image().save_png("res://scratch/previa-editor/terreno.png")
	else:
		host._mostrar()
		conferir(host.get_child_count(true) == 0, "runtime não instancia a prévia pesada")
	vista.queue_free()
	await process_frame
	await process_frame
	print("PREVIA_DO_EDITOR: editor=%s, %d falha(s)" % [Engine.is_editor_hint(), falhas])
	quit(1 if falhas else 0)
