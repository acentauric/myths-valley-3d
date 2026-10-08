extends SceneTree
## A FOLHA DE CONFERÊNCIA DOS CLIPES DO MIXAMO (#190): cada clipe redirecionado,
## tocado no corpo do morador, em quadros ao longo do clipe, de frente e de lado,
## sobre um chão quadriculado na altura zero — onde se vê pé enterrado, pé
## flutuando, mão atravessando o corpo e pele esticada.
##
##     Godot_v4.7.2-stable_win64_console.exe --path . \
##         --script res://tools/prototipo_3d/mixamo/fotografar_clipes.gd -- --saida=C:/caminho/pasta [--so=pedro]
##
## Precisa de janela (sem --headless): a foto é o que a placa de vídeo desenha.
## Grava uma folha por clipe, `<saida>/<modelo>-<clipe>.png`. Só lê o projeto.

const USO := "res://data/mixamo_uso.json"
const PASTA := "res://assets/prototipo_3d/personagens/"
const QUADRO := Vector2i(320, 400)
const AMOSTRAS := 6

var _saida := ""
var _so := ""
## O quadro que se fotografa (a janela do jogo tem o tamanho do projeto, e não o da foto).
var _janela: SubViewport


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(300.0).timeout.connect(func() -> void:
		push_error("FOTOGRAFAR_CLIPES: passou de 300 s")
		quit(2))
	for bruto in OS.get_cmdline_user_args():
		var arg := str(bruto)
		if arg.begins_with("--saida="):
			_saida = arg.trim_prefix("--saida=").replace("\\", "/").rstrip("/")
		elif arg.begins_with("--so="):
			_so = arg.trim_prefix("--so=")
	if _saida.is_empty():
		push_error("FOTOGRAFAR_CLIPES: passe --saida=<pasta>")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_saida)
	var uso: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(USO))
	var mundo := _montar_mundo()
	for pessoa: Dictionary in uso.get("personagens", []):
		var modelo := str(pessoa.get("modelo", ""))
		if (pessoa.get("clipes_mixamo", []) as Array).is_empty() or (not _so.is_empty() and _so != modelo and _so != str(pessoa.get("id", ""))):
			continue
		var corpo := (load(PASTA + modelo + "_tripo.glb") as PackedScene).instantiate() as Node3D
		mundo.add_child(corpo)
		var tocador := corpo.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		tocador.add_animation_library("mixamo", load(PASTA + "mixamo/" + modelo + ".res") as AnimationLibrary)
		for clipe: Dictionary in pessoa.get("clipes_mixamo", []):
			var nome := "mixamo/" + str(clipe.get("id", ""))
			var duracao := tocador.get_animation(nome).length
			var folha := Image.create(QUADRO.x * AMOSTRAS, QUADRO.y * 2, false, Image.FORMAT_RGBA8)
			for vista in 2:
				corpo.rotation.y = 0.0 if vista == 0 else -PI * 0.5
				for k in AMOSTRAS:
					tocador.play(nome)
					tocador.seek(duracao * k / (AMOSTRAS - 1), true)
					tocador.pause()
					await process_frame
					await RenderingServer.frame_post_draw
					var foto := _janela.get_texture().get_image()
					foto.convert(Image.FORMAT_RGBA8)
					folha.blit_rect(foto, Rect2i(Vector2i.ZERO, QUADRO), Vector2i(QUADRO.x * k, QUADRO.y * vista))
			var arquivo := "%s/%s-%s.png" % [_saida, modelo, str(clipe.get("id", ""))]
			folha.save_png(arquivo)
			print("FOTOGRAFAR_CLIPES: ", arquivo)
		corpo.queue_free()
		await process_frame
	print("FOTOGRAFAR_CLIPES_OK")
	quit(0)


## Câmera de frente na altura do peito do modelo (0,98 de altura), luz de cima e
## o chão quadriculado em y = 0.
func _montar_mundo() -> Node3D:
	_janela = SubViewport.new()
	_janela.size = QUADRO
	_janela.own_world_3d = true
	_janela.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_janela)
	var mundo := Node3D.new()
	_janela.add_child(mundo)
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_COLOR
	ambiente.environment.background_color = Color("2b3a33")
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color.WHITE
	ambiente.environment.ambient_light_energy = 0.7
	mundo.add_child(ambiente)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-60, -25, 0)
	mundo.add_child(luz)
	var camera := Camera3D.new()
	camera.fov = 40
	mundo.add_child(camera)
	camera.position = Vector3(0, 0.55, 2.0)
	camera.look_at(Vector3(0, 0.45, 0))
	var chao := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(3, 3)
	chao.mesh = plano
	var material := StandardMaterial3D.new()
	var xadrez := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for x in 8:
		for y in 8:
			xadrez.set_pixel(x, y, Color(0.75, 0.72, 0.62, 0.55) if (x + y) % 2 == 0 else Color(0.45, 0.43, 0.38, 0.55))
	material.albedo_texture = ImageTexture.create_from_image(xadrez)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.uv1_scale = Vector3(4, 4, 1)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	chao.material_override = material
	mundo.add_child(chao)
	return mundo
