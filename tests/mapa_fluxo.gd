extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_assert(change_scene_to_file("res://scenes/prototipo_3d/abertura.tscn") == OK, "abertura carrega")
	await _frames(4)
	var opening = current_scene
	_assert(opening != null and opening.name == "Abertura", "HOME")
	_assert(opening.version_link != null and opening.version_link.visible, "versão clicável")
	var audio = root.get_node("Audio")
	var mute: Button
	for button in opening.find_children("*", "Button", true, false):
		if button.tooltip_text in ["Ativar som", "Desativar som"]:
			mute = button
			break
	_assert(mute != null, "ícone de áudio")
	var sound_initial: bool = audio.som_ativo
	mute.button_pressed = not sound_initial
	_assert(audio.som_ativo != sound_initial, "ícone alterna áudio")
	mute.button_pressed = sound_initial
	_assert(audio.som_ativo == sound_initial, "ícone restaura áudio")
	await _capture("home")

	opening._open_map()
	await _frames(3)
	_assert(opening.map_open, "tela MAPA")
	_assert(opening.map_markers.size() >= 11, "pontos de interesse no mapa")
	_assert(opening.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "câmera superior")
	await _capture("mapa")
	var initial_zoom: float = opening.camera.size
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	opening._unhandled_input(wheel)
	_assert(opening.camera.size < initial_zoom, "zoom do mapa")
	var initial_target: Vector3 = opening.map_target
	var pan := InputEventMouseMotion.new()
	pan.button_mask = MOUSE_BUTTON_MASK_RIGHT
	pan.relative = Vector2(40, 20)
	opening._unhandled_input(pan)
	_assert(opening.map_target.distance_to(initial_target) > 1.0, "deslocamento do mapa")
	opening._focus_map_marker(opening.map_markers[0].position)
	_assert(opening.camera.size <= 420.0, "foco em ponto de interesse")
	opening._home()
	_assert(not opening.map_open, "retorno do MAPA")

	opening._options()
	await _frames(2)
	_assert(_count_controls(opening.content, "HSlider") == 3, "ajustes de volume")
	_assert(_count_controls(opening.content, "OptionButton") == 4, "seletores de áudio e cenário")
	await _capture("ajustes")
	opening._home()
	opening._credits()
	await _frames(2)
	_assert(opening.content.get_child_count() >= 6, "tela CONHECER")
	await _capture("conhecer")
	opening._home()
	opening._open_history()
	await _frames(2)
	_assert(opening.history_open, "histórico de versão")
	if opening.history_entries.size() > 1:
		opening._change_history(1)
		_assert(opening.history_index == 1, "próxima página do histórico")
		opening._change_history(-1)
		_assert(opening.history_index == 0, "página anterior do histórico")
	await _capture("historico")
	opening._home()
	opening._confirm_exit()
	await _frames(2)
	_assert(_has_button(opening.content, "CANCELAR"), "confirmação para SAIR")
	opening._home()
	opening._intro()
	_assert(opening.line_index == 0 and not opening.caption.text.is_empty(), "tela JOGAR")
	await _capture("travessia")
	opening._start_game()
	await _frames(3)
	var game = current_scene
	_assert(game != null and game.name == "Vale3D", "entrada no jogo")
	var player: CharacterBody3D = game.get_node("Jogador")
	var world: Node3D = game.get_node("Cenario")
	var region: Node3D = world.get_node("bom_jesus_dos_pobres")
	await _physics_frames(30)
	_assert(player.is_on_floor() and absf(player.global_position.y) < 0.2, "personagem apoiado no terreno")
	await _capture("jogo")
	var start_position: Vector3 = player.global_position
	player.set_captured(true)
	Input.action_press("mv_forward")
	await _physics_frames(90)
	Input.action_release("mv_forward")
	print("MAPA_WALK mode=", Input.mouse_mode, " start=", start_position, " end=", player.global_position, " floor=", player.is_on_floor())
	_assert(player.global_position.distance_to(start_position) > 3.0, "caminhada")
	_assert(player.is_on_floor() and player.global_position.y > -0.2, "caminhada sem queda")
	Input.action_press("mv_run")
	Input.action_press("mv_right")
	var run_start: Vector3 = player.global_position
	await _physics_frames(90)
	Input.action_release("mv_right")
	Input.action_release("mv_run")
	_assert(player.global_position.distance_to(run_start) > 5.0, "corrida")
	_assert(player.is_on_floor() and player.global_position.y > -0.2, "corrida sem queda")
	player.set_captured(false)
	player.reset_position()
	await _physics_frames(12)
	var road_target := _closest_point_on_road(region.get("_roads")[0].points, Vector2(player.global_position.x, player.global_position.z))
	var route := road_target - Vector2(player.global_position.x, player.global_position.z)
	player._yaw = atan2(-route.x, -route.y)
	player._apply_camera()
	player.set_captured(true)
	Input.action_press("mv_forward")
	await _physics_frames(int(route.length() / player.walk_speed * 60.0) + 24)
	Input.action_release("mv_forward")
	_assert(player.is_on_floor(), "travessia da praça até a rua")
	_assert(world.surface_at(player.global_position) == "terra", "personagem alcança a Rua Principal")
	print("MAPA_ROAD_WALK position=", player.global_position, " target=", road_target)
	player.set_captured(false)
	var road_count := 0
	var samples := 0
	for road in region.get("_roads"):
		road_count += 1
		for point in road.points:
			samples += 1
			var hit := _floor_hit(game, Vector3(point.x, 0, point.y), player)
			_assert(not hit.is_empty(), "colisão na rua %s, ponto %d" % [road.name, samples])
	_assert(road_count >= 8 and samples >= 100, "oito ruas vetoriais percorríveis")
	for landmark in world.landmarks:
		var destination: Vector3 = landmark.position
		var hit := _floor_hit(game, destination, player)
		_assert(not hit.is_empty(), "terreno no ponto %s" % landmark.name)
	_assert(world.landmarks.size() == 12, "pontos de interesse")
	var offshore_visits := 0
	for landmark in world.landmarks:
		var destination: Vector3 = landmark.position
		if region._is_on_land(destination):
			continue
		player.global_position = destination + Vector3.UP * 0.35
		player.velocity = Vector3.ZERO
		await _physics_frames(35)
		_assert(player.is_on_floor(), "acesso caminhável a %s" % landmark.name)
		_assert(game._visited.has(landmark.id), "exploração de %s" % landmark.name)
		offshore_visits += 1
		await _capture("acesso_%d" % offshore_visits)
	_assert(offshore_visits == 2, "dois acessos sobre a água")
	player.reset_position()
	await _physics_frames(20)
	_assert(player.is_on_floor(), "reinício de posição")
	game._return_to_menu()
	await _frames(3)
	_assert(current_scene.name == "Abertura", "HOME a partir do jogo")
	print("MAPA_FLUXO_OK: HOME, MAPA, AJUSTAR, CONHECER, histórico, SAIR, JOGAR, caminhada, corrida, ruas e HOME")
	quit()


func _floor_hit(game: Node3D, point: Vector3, player: CharacterBody3D) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 30.0, point + Vector3.DOWN * 30.0)
	ray.exclude = [player.get_rid()]
	return game.get_world_3d().direct_space_state.intersect_ray(ray)


func _closest_point_on_road(points: PackedVector2Array, point: Vector2) -> Vector2:
	var closest := points[0]
	var best_distance := INF
	for i in range(points.size() - 1):
		var segment := points[i + 1] - points[i]
		if segment.length_squared() < 0.000001:
			continue
		var fraction := clampf((point - points[i]).dot(segment) / segment.length_squared(), 0.0, 1.0)
		var candidate := points[i] + segment * fraction
		var distance := point.distance_squared_to(candidate)
		if distance < best_distance:
			best_distance = distance
			closest = candidate
	return closest


func _count_controls(node: Node, type_name: String) -> int:
	var count := 0
	for child in node.get_children():
		if child.is_class(type_name):
			count += 1
	return count


func _has_button(node: Node, label: String) -> bool:
	for child in node.get_children():
		if child is Button and child.text == label:
			return true
	return false


func _assert(condition: bool, label: String) -> void:
	if not condition:
		push_error("MAPA_FLUXO_FALHOU: " + label)
		quit(1)
		assert(false, label)


func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame


func _physics_frames(count: int) -> void:
	for frame in range(count):
		await physics_frame


func _capture(label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await _frames(5)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/fluxo_%s.png" % label)
