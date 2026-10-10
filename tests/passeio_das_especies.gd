extends "res://tests/suite/caso.gd"
## Auditoria dos modelos do catálogo, sem construir o vale ou alterar saves.
## Confere o passeio sem salto artificial e o fim do passo de cada quadrúpede.

var falhas := 0
var camera: Camera3D
var legenda: Label
var quadro_video := 0
var capturas := "D:/MythsValleyPlaytestRuns/animais149-capturas"
func _initialize() -> void:
	_run.call_deferred()

func _confere(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas += 1
		push_error("PASSEIO_DAS_ESPECIES_FALHOU: " + mensagem)

func _run() -> void:
	var Animador = load("res://scripts/prototipo_3d/animador_bicho.gd")
	var especies: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/bichos_de_casa.json"))["especies"]
	especies["onca_pintada"] = {"passo": 4.06 * 0.4}
	especies["onca_preta"] = {"passo": 4.06 * 0.4}
	especies["caititu"] = {"passo": 1.56 * 0.5}
	especies["jararaca"] = {"passo": 1.016 * 0.5}
	var arena := Node3D.new()
	root.add_child(arena)
	if "--visual" in OS.get_cmdline_user_args():
		_palco_visual(arena)
	for chave: String in especies:
		if not especies[chave] is Dictionary:
			continue
		if "--somente-caramelo" in OS.get_cmdline_user_args() and chave != "cachorro_caramelo":
			continue
		var sp: Dictionary = especies[chave]
		var ator := Node3D.new()
		arena.add_child(ator)
		var pose := Node3D.new()
		ator.add_child(pose)
		var modelo = Animador.vestir(chave, pose, Vector3(0.3, 0.5, 0.9), Color.WHITE)
		var an = Animador.new()
		arena.add_child(an)
		an.set_process(false)
		var ave := str(sp.get("tipo", "")) == "ave"
		var velocidade := float(sp.get("passo", 1.0))
		an.configurar(pose, modelo, ave, chave, velocidade)
		var ossos := 0
		for rig: Skeleton3D in modelo.find_children("*", "Skeleton3D", true, false):
			ossos += rig.get_bone_count()
		print("ESPECIE: %s | ossos=%d | clipe=%s | passada=%.3f | passo=%.3f" % [chave, ossos, an._clipe, an.passada, velocidade])
		if an.tem_clipe() and not ave:
			if "--falsificar-passo" in OS.get_cmdline_user_args():
				an.velocidade_do_passo = an.passada
			an.velocidade = velocidade
			var salto := 0.0
			for quadro in 120:
				an.animacao.advance(1.0 / 60.0)
				an._process(1.0 / 60.0)
				salto = maxf(salto, pose.position.y)
			_confere(salto < 0.001, "%s ganhou salto artificial no passeio: %.3f u" % [chave, salto])
			an.velocidade = 0.0
			for quadro in 240:
				an.animacao.advance(1.0 / 60.0)
				an._process(1.0 / 60.0)
			_confere(not an.animacao.is_playing(), "%s não terminou o passo em 4 s" % chave)
		if camera != null:
			await _filmar(chave, sp, ator, an)
		an.queue_free()
		ator.queue_free()
		await process_frame
	# A montagem de produção distingue a ronda da carga, sem mudar a caça.
	var Criatura = load("res://scripts/prototipo_3d/criatura_vale.gd")
	for especie: String in ["onca", "caititu", "jararaca"]:
		var criatura = Criatura.new()
		criatura.especie = especie
		criatura.u_por_px = 2.1 / 62.0
		arena.add_child(criatura)
		criatura.set_physics_process(false)
		var carga: float = criatura._u("passo")
		var ronda: float = carga * float(criatura.dados().get("passeio", 0.5))
		if "--falsificar-ronda" in OS.get_cmdline_user_args():
			criatura._animador.velocidade_do_passo = carga
		_confere(absf(criatura._animador.velocidade_do_passo - ronda) < 0.001,
			"%s confunde a velocidade da carga com a ronda" % especie)
		_confere(carga / ronda > 1.35, "%s perdeu a diferença entre ronda e carga" % especie)
		criatura.queue_free()
		await process_frame
	print("PASSEIO_DAS_ESPECIES: %d falha(s)" % falhas)
	arena.queue_free()
	_terminar.call_deferred()

func _terminar() -> void:
	# Solta os modelos e as referências locais antes de desmontar o renderizador.
	await process_frame
	await process_frame
	quit(1 if falhas > 0 else 0)

func _palco_visual(arena: Node3D) -> void:
	if not OS.get_environment("MV_ANIMAIS_CAPTURAS").is_empty():
		capturas = OS.get_environment("MV_ANIMAIS_CAPTURAS")
	DirAccess.make_dir_recursive_absolute(capturas)
	var mundo := WorldEnvironment.new()
	var ambiente := Environment.new()
	ambiente.background_mode = Environment.BG_COLOR
	ambiente.background_color = Color("323c43")
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color.WHITE
	ambiente.ambient_light_energy = 0.7
	mundo.environment = ambiente
	arena.add_child(mundo)
	var luz := DirectionalLight3D.new()
	arena.add_child(luz)
	luz.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	luz.light_energy = 1.3
	var piso := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(20.0, 20.0)
	piso.mesh = plano
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("5b685b")
	piso.material_override = material
	arena.add_child(piso)
	camera = Camera3D.new()
	arena.add_child(camera)
	camera.current = true
	legenda = Label.new()
	root.add_child(legenda)
	legenda.position = Vector2(16.0, 16.0)
	legenda.add_theme_font_size_override("font_size", 22)

func _filmar(chave: String, sp: Dictionary, ator: Node3D, an) -> void:
	if an.tem_clipe():
		an.animacao.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var andando := float(sp.get("passo", 1.0))
	var correndo := float(sp.get("corrida", andando * 2.5))
	for estado: String in ["passeio", "corrida", "parado"]:
		an.velocidade = andando if estado == "passeio" else correndo if estado == "corrida" else 0.0
		legenda.text = "%s — %s (%.2f u/s)" % [chave, estado, an.velocidade]
		for quadro in 20:
			var dt := 1.0 / 30.0
			if estado != "parado":
				ator.rotation.y += dt * 0.7
				ator.position += Vector3.BACK.rotated(Vector3.UP, ator.rotation.y) * an.velocidade * dt
			if an.tem_clipe():
				an.animacao.advance(dt)
			an._process(dt)
			camera.position = ator.position + Vector3(1.8, 1.0, 2.0)
			camera.look_at(ator.position + Vector3(0.0, 0.35, 0.0))
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_jpg(capturas.path_join("quadro_%04d.jpg" % quadro_video), 0.82)
			quadro_video += 1
