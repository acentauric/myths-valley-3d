extends SceneTree
## OS TRÊS VARAIS AO LADO DO VIAJANTE (#194): a conferência visual de escala que o portão
## `varais_em_escala` não faz (ele só mede a altura que o catálogo define; a roupa e a
## corda se veem aqui). Precisa de janela, como a galeria de Modelos.
##   Godot --path . --script res://tools/prototipo_3d/fotografar_varais.gd -- --saida=<pasta> [--prefixo=varais]
## Tira duas fotos: de frente e de três quartos.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		push_error("FOTOS_VARAIS: limite de 120 segundos excedido")
		quit(2))
	var args := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			args[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	var saida := String(args.get("saida", OS.get_user_data_dir()))
	var prefixo := String(args.get("prefixo", "varais"))
	DirAccess.make_dir_recursive_absolute(saida)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.get_node("Estilo").set("modo", "tripo")
	var cena := Node3D.new()
	root.add_child(cena)
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_COLOR
	ambiente.environment.background_color = Color(0.62, 0.78, 0.92)
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color(0.85, 0.85, 0.85)
	cena.add_child(ambiente)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	cena.add_child(sol)
	var chao := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(40.0, 40.0)
	chao.mesh = plano
	var tinta := StandardMaterial3D.new()
	tinta.albedo_color = Color(0.45, 0.6, 0.3)
	chao.material_override = tinta
	cena.add_child(chao)
	var lugares := {"viajante": -6.0, "varal": -3.0, "varal_bambu": 1.0, "varal_estacas": 5.0}
	for chave: String in lugares:
		var no := Node3D.new()
		cena.add_child(no)
		no.position = Vector3(float(lugares[chave]), 0.0, 0.0)
		var peca = CatalogoAssets.instanciar(chave, no, Vector3.ZERO)
		var caixa: AABB = peca.get_meta("limites") if peca != null else AABB()
		print("VARAIS ", chave, " altura ", snappedf(caixa.size.y, 0.01), " largura ", snappedf(maxf(caixa.size.x, caixa.size.z), 0.01))
	var camera := Camera3D.new()
	camera.fov = 45.0
	cena.add_child(camera)
	camera.current = true
	var vistas := {"frente": [Vector3(-0.5, 1.6, 11.0), Vector3(-0.5, 1.0, 0.0)], "tres_quartos": [Vector3(7.0, 2.4, 9.0), Vector3(-0.5, 0.9, 0.0)]}
	for nome: String in vistas:
		camera.global_position = vistas[nome][0]
		camera.look_at(vistas[nome][1])
		for i in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		var caminho := saida.path_join("%s_%s.png" % [prefixo, nome])
		root.get_texture().get_image().save_png(caminho)
		print("FOTO_VARAIS ", caminho)
	quit()
