extends SceneTree
## Executar com --path prototipo_3d --script res://tools/prototipo_3d/smoke_test.gd.

var game: Node3D
var player: CharacterBody3D
var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(50.0).timeout.connect(func() -> void:
		push_error("FAIL: limite de 50 segundos excedido")
		quit(2))
	var packed := load("res://scenes/prototipo_3d/vale.tscn") as PackedScene
	if not _check(packed != null, "cena principal disponível"):
		quit(1)
		return
	game = packed.instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	player = game.get_node_or_null("Jogador") as CharacterBody3D
	if not _check(player != null and player.get("model") != null, "personagem instanciado"):
		quit(1)
		return
	player.call("set_captured", true)
	game.hud.set_captured(true)
	await _frames(45)
	var model: Node3D = player.get("model")
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	_check(skeletons.size() == 1 and skeletons[0].get_bone_count() == 65, "esqueleto com 65 ossos")
	var expected_animations := ["afraid", "agree", "chop", "fold_arms", "greet_01", "idle", "jump_down", "look_around", "run", "swim", "walk", "wave_goodbye_02"]
	var animation_names: Array = Array(player.call("get_animation_names"))
	animation_names.sort()
	_check(animation_names == expected_animations, "12 clipes de animação disponíveis")
	_check(player.call("get_current_animation") == &"idle", "idle inicia automaticamente")
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var textured := false
	var double_sided := true
	for mesh: MeshInstance3D in meshes:
		for surface in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface) as BaseMaterial3D
			if material != null and material.albedo_texture != null:
				textured = true
			if material == null or material.cull_mode != BaseMaterial3D.CULL_DISABLED:
				double_sided = false
	_check(not meshes.is_empty() and textured, "malha com textura albedo")
	_check(double_sided, "material de roupa visível dos dois lados")
	var bounds: AABB = player.get("model_bounds")
	_check(absf(bounds.size.y * model.scale.y - 1.78) < 0.03, "altura normalizada em 1,78 m")
	_check(absf(model.position.y + bounds.position.y * model.scale.y) < 0.03, "pés alinhados à origem visual")
	_check(player.is_on_floor() and absf(player.global_position.y) < 0.12, "personagem apoiado no chão")

	var directions := {"mv_forward": Vector3.FORWARD, "mv_back": Vector3.BACK, "mv_left": Vector3.LEFT, "mv_right": Vector3.RIGHT}
	for action: String in directions:
		player.call("reset_position")
		await _frames(3)
		var origin := player.global_position
		Input.action_press(action)
		await _frames(30)
		Input.action_release(action)
		_check((player.global_position - origin).dot(directions[action]) > 0.65, "movimento " + action)
	var walking: float = await _travel(false)
	var running: float = await _travel(true)
	_check(running > walking * 1.35, "Shift aumenta a velocidade")
	player.call("reset_position")
	await _frames(18)
	var animator: Node = player.get("animator")
	var animation_player: AnimationPlayer = animator.get("animation_player")
	var skeleton: Skeleton3D = skeletons[0]
	var gesture_clips := ["greet_01", "wave_goodbye_02", "agree", "look_around", "afraid", "fold_arms", "chop", "swim", "jump_down"]
	for index in range(gesture_clips.size()):
		_trigger_animation(index + 1)
		animation_player.advance(0.0)
		_check(player.call("get_current_animation") == StringName(gesture_clips[index]), "gesto %d reproduz %s" % [index + 1, gesture_clips[index]])
		_check(_pose_changes(skeleton, animation_player, animation_player.current_animation_length * 0.5), "gesto %d altera a pose" % (index + 1))
	_trigger_animation(2)
	animation_player.advance(animation_player.current_animation_length * 0.5)
	await process_frame
	await _screenshot("animation_wave.png")
	animator.call("update_motion", 1.0, 0.0)
	_check(player.call("get_current_animation") == &"walk", "movimento interrompe gesto e retoma locomoção")

	player.call("reset_position")
	player.global_position = Vector3(10, 0.05, -1)
	player.velocity = Vector3.ZERO
	Input.action_press("mv_forward")
	await _frames(160)
	Input.action_release("mv_forward")
	_check(player.global_position.z > -5.65 and player.global_position.z < -4.0, "colisão impede atravessar casa")
	player.global_position = Vector3(10, 0.05, -4.2)
	player.velocity = Vector3.ZERO
	player.set("_yaw", PI)
	player.call("_apply_camera")
	await _frames(12)
	var spring: SpringArm3D = player.get("spring")
	_check(spring.get_hit_length() < spring.spring_length - 0.5, "câmera recua diante da parede")

	player.call("reset_position")
	await _frames(6)
	var spawn: Vector3 = player.get("spawn_position")
	_check(Vector2(player.global_position.x - spawn.x, player.global_position.z - spawn.z).length() < 0.05, "reiniciar retorna ao ponto inicial")
	game.hud.set_notice("Modelo importado · passeio livre pelo vale")
	await _screenshot("preview.png")
	player.set("_yaw", player.get("visual").rotation.y)
	player.set("_pitch", -0.08)
	player.set("_distance", 3.1)
	player.call("_apply_camera")
	await _frames(6)
	await _screenshot("front.png")
	for landmark: Dictionary in game.world.landmarks:
		player.global_position = landmark["position"] + Vector3(0, 0.05, 0)
		player.velocity = Vector3.ZERO
		await _frames(3)
		# process_frame é emitido antes de Node._process: aguardar o quadro seguinte
		# deixa a detecção de proximidade concluir antes de conferir o destino.
		await process_frame
		await process_frame
		var visited: Dictionary = game.get("_visited")
		print("LANDMARK: ", landmark["name"], " player=", player.global_position,
			" distance=", player.global_position.distance_to(landmark["position"]),
			" visited=", visited.keys())
		_check(visited.has(landmark["name"]), "destino reconhecido: " + str(landmark["name"]))
	_check(game.get("_visited").size() == 3, "três destinos do passeio reconhecidos")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("SMOKE_RESULT: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _travel(run: bool) -> float:
	player.call("reset_position")
	await _frames(3)
	var origin := player.global_position
	Input.action_press("mv_forward")
	if run:
		Input.action_press("mv_run")
	await _frames(45)
	if run:
		await _screenshot("running.png")
	Input.action_release("mv_forward")
	Input.action_release("mv_run")
	return Vector2(player.global_position.x - origin.x, player.global_position.z - origin.z).length()


func _frames(count: int) -> void:
	for _frame in range(count):
		player.call("set_captured", true)
		await physics_frame
	await process_frame


func _trigger_animation(number: int) -> void:
	var event := InputEventAction.new()
	event.action = "mv_animation_%d" % number
	event.pressed = true
	player.call("_unhandled_input", event)


func _pose_changes(skeleton: Skeleton3D, animation_player: AnimationPlayer, seconds: float) -> bool:
	var before: Array[Transform3D] = []
	for bone in range(skeleton.get_bone_count()):
		before.append(skeleton.get_bone_pose(bone))
	animation_player.advance(seconds)
	for bone in range(skeleton.get_bone_count()):
		if not before[bone].is_equal_approx(skeleton.get_bone_pose(bone)):
			return true
	return false


func _screenshot(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP: captura de imagem em modo headless")
		return
	game.hud.set_captured(true)
	await RenderingServer.frame_post_draw
	var directory := "res://scratch/prototipo_3d"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var result := root.get_texture().get_image().save_png(directory.path_join(filename))
	_check(result == OK, "captura " + filename)


func _check(condition: bool, label: String) -> bool:
	print("PASS: " if condition else "FAIL: ", label)
	failed = failed or not condition
	return condition
