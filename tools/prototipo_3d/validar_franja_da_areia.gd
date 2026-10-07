extends SceneTree
## Prova gráfica do shader real; executar com janela, não --headless.
var falhas := 0
func _initialize() -> void: _run.call_deferred()
func conferir(ok: bool, texto: String) -> void:
	if not ok: falhas += 1; print("FALHA: ", texto)
func _run() -> void:
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("FRANJA_DA_AREIA: requer renderização gráfica")
		quit(2)
		return
	var vista := SubViewport.new()
	vista.size = Vector2i(256, 256)
	vista.own_world_3d = true
	vista.transparent_bg = true
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vista)
	var plano := MeshInstance3D.new()
	var malha := PlaneMesh.new()
	malha.size = Vector2(16, 16)
	plano.mesh = malha
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/prototipo_3d/mar/areia_praia.gdshader")
	material.set_shader_parameter("textura_areia", load("res://assets/prototipo_3d/materiais/areia_praia_v1.png"))
	if "--sem-franja" in OS.get_cmdline_user_args(): material.set_shader_parameter("franja_mar", 0.001)
	plano.material_override = material
	vista.add_child(plano)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 16
	vista.add_child(camera)
	camera.position = Vector3(0, 20, 0)
	camera.look_at(Vector3.ZERO, Vector3.BACK)
	camera.current = true
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var foto := vista.get_texture().get_image()
	# UV.x cresce para a esquerda nesta orientação de PlaneMesh. A faixa central opaca
	# e pixels recortados em posições diferentes comprovam a franja real.
	var vazios := 0
	var cheios := 0
	var cortes := {}
	for y in range(16, 240):
		var primeiro := -1
		for x in range(0, 32):
			if foto.get_pixel(x, y).a < 0.5:
				vazios += 1
				primeiro = x
			else: cheios += 1
		cortes[primeiro] = true
	conferir(foto.get_pixel(128, 128).a > 0.9, "centro da areia permanece opaco")
	conferir(vazios > 500 and cheios > 500, "franja mistura areia e fundo")
	conferir(cortes.size() > 3, "recorte acompanha o ruído sem régua reta")
	print("FRANJA_DA_AREIA: %d falha(s), %d vazios, %d cheios, %d cortes" % [falhas, vazios, cheios, cortes.size()])
	vista.queue_free()
	await process_frame
	quit(1 if falhas else 0)
