extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# O lobby 3D (o `-- --lobby-3d` por código): desde o lobby em vídeo (05/10) a
	# abertura solta o vale de fundo, e este portão confere o HOME com ele.
	(load("res://scripts/prototipo_3d/abertura.gd") as GDScript).set("lobby_3d_pedido", true)
	_assert(change_scene_to_file("res://scenes/prototipo_3d/abertura.tscn") == OK, "abertura carrega")
	await _frames(4)
	await _mundo_pronto()
	var opening = current_scene
	_assert(opening != null and opening.name == "Abertura", "HOME")
	_assert(opening.version_link != null and opening.version_link.visible, "versão clicável")
	var opening_region: Node3D = opening.get_node("Cenario/bom_jesus_dos_pobres")
	var opening_trees := _first_lod_block(opening_region)
	_assert(opening_trees != null, "bloco real de vegetação no HOME")
	var opening_range := opening_trees.visibility_range_end
	_assert(opening_range > 0.0, "LOD da vegetação ativo no HOME")
	var audio = root.get_node("Audio")
	var mute: Button
	# Botão de som do canto: o que tem o ícone de alto-falante (AudioToggleIcon).
	for button in opening.find_children("*", "Button", true, false):
		for child in button.get_children():
			if child.get_script() == opening.AudioToggleIcon:
				mute = button
		if mute != null:
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
	_assert(opening_trees.visibility_range_end == 0.0, "vegetação visível no MAPA do menu")
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
	await _frames(3)
	_assert(not opening.map_open, "retorno do MAPA")
	_assert(opening_trees.visibility_range_end == opening_range, "LOD restaurado no HOME")

	opening._options()
	await _frames(2)
	# Aba Geral: cinco volumes à direita; idioma, tempo, hora inicial, pausa e teclas à esquerda.
	_assert(_count_controls(opening.content, "HSlider") == 5, "ajustes de volume")
	# Idioma, tempo, hora, pausa, teclas e câmera; os atalhos têm a aba própria.
	_assert(_count_controls(opening.content, "OptionButton") >= 6, "seletores de jogo, tempo, teclas e câmera")
	await _capture("ajustes")
	opening._home()
	opening._credits()
	await _frames(2)
	_assert(opening.content.get_child_count() >= 6, "tela SOBRE")
	await _capture("conhecer")
	# Clique fora do modal fecha e volta ao menu inicial.
	var outside := InputEventMouseButton.new()
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true
	opening._unhandled_input(outside)
	_assert(not opening.modal_open and _has_button(opening.content, "JOGAR"), "clique fora fecha SOBRE")
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
	# A entrada no vale carrega em segundo plano (tela de carregamento).
	var limite_da_cena := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < limite_da_cena:
		if current_scene != null and current_scene.name == "Vale3D":
			break
		await process_frame
	await _mundo_pronto()
	await _frames(3)
	var game = current_scene
	_assert(game != null and game.name == "Vale3D", "entrada no jogo")
	var player: CharacterBody3D = game.get_node("Jogador")
	var world: Node3D = game.get_node("Cenario")
	var region: Node3D = world.get_node("bom_jesus_dos_pobres")
	var game_trees := _first_lod_block(region)
	_assert(game_trees != null, "bloco real de vegetação no jogo")
	var game_range := game_trees.visibility_range_end
	_assert(game_range > 0.0, "LOD da vegetação ativo no passeio")
	game._toggle_map()
	await _frames(3)
	_assert(game.mapa.aberto and game_trees.visibility_range_end == 0.0, "vegetação visível no MAPA do jogo")
	game._toggle_map()
	await _frames(3)
	_assert(not game.mapa.aberto and game_trees.visibility_range_end == game_range, "LOD restaurado no passeio")
	await _physics_frames(30)
	# A PARTIDA NOVA NASCE NO CONVÉS DO SAVEIRO (`tests/chegada.gd`): apoiado é de
	# pé no convés dele ou no terreno.
	var ground: Vector3 = world.call("ground_position", player.global_position)
	var saveiro = game.get("saveiro")
	var no_conves: bool = saveiro != null and saveiro.na_chegada() and saveiro.ponto_do_conves().is_finite() \
		and player.global_position.distance_to(saveiro.ponto_do_conves()) < 1.0
	_assert(player.is_on_floor() and (no_conves or absf(player.global_position.y - ground.y) < 0.2), "personagem apoiado no terreno")
	# O PASSEIO é o de quem já desceu: do ponto de chegada em terra, de frente
	# para o píer, com o andar levando para dentro do vale — a partida de antes
	# do saveiro. Do convés, andar desce a prancha e correr cruza o píer até a água.
	player.reset_position()
	player.iniciar_de_frente(world.ancoras.get("Pier", player.global_position) - player.global_position)
	await _physics_frames(12)
	await _capture("jogo")
	var start_position: Vector3 = player.global_position
	player.set_captured(true)
	Input.action_press("mv_forward")
	await _physics_frames(90)
	Input.action_release("mv_forward")
	print("MAPA_WALK mode=", Input.mouse_mode, " start=", start_position, " end=", player.global_position, " floor=", player.is_on_floor())
	_assert(player.global_position.distance_to(start_position) > 3.0, "caminhada")
	_assert(player.is_on_floor() and _above_ground(world, player), "caminhada sem queda")
	# Shift liga o modo corrida com um toque; outro toque desliga.
	# Continua rumo à terra: ao nascer no píer, correr de lado entra na água
	# e mede a velocidade de nado em vez da corrida.
	await _tap_shift()
	Input.action_press("mv_forward")
	var run_start: Vector3 = player.global_position
	await _physics_frames(90)
	Input.action_release("mv_forward")
	print("MAPA_RUN start=", run_start, " end=", player.global_position, " vigor=", player.vigor_atual())
	await _tap_shift()
	_assert(player.global_position.distance_to(run_start) > 5.0, "corrida")
	_assert(player.is_on_floor() and _above_ground(world, player), "corrida sem queda")
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
	var spawn_original: Vector3 = player.spawn_position
	var offshore_visits := 0
	for landmark in world.landmarks:
		var destination: Vector3 = landmark.position
		if region._is_on_land(destination):
			continue
		# Teleportar do morro até a água não é uma queda: a referência de
		# terra firme do trajeto anterior deve ser descartada.
		player.spawn_position = destination + Vector3.UP * 0.35
		player.reset_position()
		await _physics_frames(35)
		_assert(player.is_on_floor(), "acesso caminhável a %s" % landmark.name)
		_assert(game._visited.has(landmark.id), "exploração de %s" % landmark.name)
		offshore_visits += 1
		await _capture("acesso_%d" % offshore_visits)
	# A Casa da estrada passou a terra firme na revisão do KML. Todos os
	# pontos que ainda ficam sobre a água são medidos acima, sem fixar o total antigo.
	_assert(offshore_visits >= 1, "ao menos um acesso sobre a água foi conferido")
	player.spawn_position = spawn_original
	player.reset_position()
	await _physics_frames(20)
	_assert(player.is_on_floor(), "reinício de posição")
	# HOME no jogo: confirma com o vale pausado, cancelar retoma, confirmar carrega o menu.
	var hud = game.get_node("HUD")
	game._ask_return_to_menu()
	await _frames(2)
	_assert(hud.menu_confirm_open() and paused, "confirmação de HOME no jogo")
	hud._close_menu_confirm(false)
	_assert(not hud.menu_confirm_open() and not paused, "cancelar volta ao passeio")
	game._ask_return_to_menu()
	hud._close_menu_confirm(true)
	var limite_do_menu := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < limite_do_menu:
		if current_scene != null and current_scene.name == "Abertura":
			break
		await process_frame
	await _mundo_pronto()
	await _frames(3)
	_assert(current_scene.name == "Abertura" and not paused, "HOME a partir do jogo")
	print("MAPA_FLUXO_OK: HOME, MAPA, AJUSTAR, SOBRE, histórico, SAIR, JOGAR, caminhada, corrida, ruas e HOME")
	quit()


## O terreno tem relevo: "sem queda" é estar sobre o chão do terreno, não acima de y = 0.
func _above_ground(world: Node3D, player: CharacterBody3D) -> bool:
	var ground: Vector3 = world.call("ground_position", player.global_position)
	return player.global_position.y > ground.y - 0.2


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
	return node.find_children("*", type_name, true, false).size()


func _has_button(node: Node, label: String) -> bool:
	for child in node.get_children():
		if child is Button and child.text == label:
			return true
	return false


func _first_lod_block(region: Node3D) -> MultiMeshInstance3D:
	var blocks: Array = region.get("_blocos_vegetacao_lod")
	for block in blocks:
		var visual := block.get("visual") as MultiMeshInstance3D
		if is_instance_valid(visual) and visual.multimesh != null and visual.multimesh.instance_count > 0:
			return visual
	return null


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


## Toque em Shift pelo caminho real da entrada; espera o evento chegar ao jogador
## (parse_input_event só entrega no quadro seguinte).
func _tap_shift() -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.physical_keycode = KEY_SHIFT
		key.keycode = KEY_SHIFT
		key.pressed = pressed
		Input.parse_input_event(key)
	await _frames(2)


func _capture(label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await _frames(5)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/fluxo_%s.png" % label)


## O vale se monta ao longo de vários quadros (world_builder): espera ficar pronto.
func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
