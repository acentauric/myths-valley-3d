extends SceneTree
var falhas := 0

func _initialize() -> void:
	_run.call_deferred()

func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: " + texto)

func hips(animacao: Animation) -> int:
	for t in animacao.get_track_count():
		if animacao.track_get_type(t) == Animation.TYPE_POSITION_3D and String(animacao.track_get_path(t)).to_lower().contains("hips"):
			return t
	return -1

func _run() -> void:
	var arena := Node3D.new()
	root.add_child(arena)
	var catalogo = load("res://scripts/prototipo_3d/catalogo_assets.gd")
	var modelo: Node3D = catalogo.instanciar("beata", arena, Vector3.ZERO)
	conferir(modelo != null, "modelo da beata ausente")
	if modelo == null:
		quit(1)
		return
	var player: AnimationPlayer = modelo.find_children("*", "AnimationPlayer", true, false)[0]
	var original: Animation
	for real in player.get_animation_list():
		if String(real).begins_with("run"):
			original = player.get_animation(real)
	var t_original := hips(original)
	var valor_original: Vector3 = original.track_get_key_value(t_original, 0)
	var animador = load("res://scripts/prototipo_3d/authored_animator.gd").new()
	arena.add_child(animador)
	conferir(animador.configure(modelo, not "--falsificar" in OS.get_cmdline_user_args()), "animador não configurou")
	var idle: Animation = player.get_animation(animador._clips["idle"])
	var base: Vector3 = idle.track_get_key_value(hips(idle), 0)
	for role in ["walk", "run"]:
		var clipe: Animation = player.get_animation(animador._clips[role])
		var t := hips(clipe)
		conferir(t >= 0, "clipe perdeu Hips")
		for k in clipe.track_get_key_count(t):
			var p: Vector3 = clipe.track_get_key_value(t, k)
			conferir(Vector2(p.x - base.x, p.z - base.z).length() < 0.001, "o clipe desloca o corpo da posição conduzida pela física")
			conferir(absf(p.y - base.y) * modelo.scale.y <= 0.0251, "a troca de clipe salta a altura do corpo")
		conferir(clipe.get_track_count() == original.get_track_count(), "a estabilização removeu membros do clipe")
	conferir(original.track_get_key_value(t_original, 0) == valor_original, "a cópia alterou o recurso original compartilhado")
	animador.update_motion(0.9, 1.0 / 60)
	conferir(animador.get_current_animation() == StringName(animador._clips["walk"]), "caminhar não usa o clipe escolhido")
	conferir(float(animador._passada.get("walk", 0)) > 0, "a passada não é medida pela velocidade")
	# PÉ SEM DESLIZAR (#209): a velocidade do clipe no chão (passada medida x speed_scale) acompanha a
	# velocidade horizontal real, no andar e na corrida, dentro do que o clipe aguenta (0,5 a 2,5 vezes).
	var natural_andar := float(animador._passada.get("walk", 0))
	for fator in [0.7, 1.0, 1.8]:
		var real: float = natural_andar * fator
		animador.update_motion(real, 1.0 / 60)
		conferir(animador.get_current_animation() == StringName(animador._clips["walk"]), "a %.2f da passada o viajante devia andar" % fator)
		conferir(absf(animador.animation_player.speed_scale * natural_andar - real) < 0.02, "o pé desliza no andar: clipe a %.2f u/s para %.2f u/s reais" % [animador.animation_player.speed_scale * natural_andar, real])
	var natural_correr := float(animador._passada.get("run", 0))
	if natural_correr > animador._limite_da_corrida():
		animador.update_motion(natural_correr, 1.0 / 60)
		conferir(animador.get_current_animation() == StringName(animador._clips["run"]), "à passada da corrida o viajante devia correr")
		conferir(absf(animador.animation_player.speed_scale * natural_correr - natural_correr) < 0.02, "o pé desliza na corrida")
	animador.update_motion(0.0, 1.0 / 60)
	conferir(animador.get_current_animation() == StringName(animador._clips["idle"]), "parar não volta ao repouso")
	if "--capturar" in OS.get_cmdline_user_args():
		var camera := Camera3D.new()
		arena.add_child(camera)
		camera.position = Vector3(2.8, 1.5, 3.8)
		camera.look_at(Vector3(0, 0.9, 0))
		camera.current = true
		var luz := DirectionalLight3D.new()
		arena.add_child(luz)
		luz.rotation_degrees = Vector3(-40, -20, 0)
		var chao := MeshInstance3D.new()
		var malha := PlaneMesh.new()
		malha.size = Vector2(10, 10)
		chao.mesh = malha
		arena.add_child(chao)
		DirAccess.make_dir_recursive_absolute("res://scratch/beata-locomocao")
		animador.update_motion(0.9, 1.0 / 60)
		for fase in [0.25, 0.5, 0.75]:
			player.seek(player.current_animation_length * fase, true)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://scratch/beata-locomocao/passo-%s.png" % fase)
	print("BEATA_LOCOMOCAO: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
