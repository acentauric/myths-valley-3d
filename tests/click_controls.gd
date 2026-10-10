extends "res://tests/suite/caso.gd"
## Verifica alvos de casas, acesso ao terreno e rota a partir do píer.



var falhas := 0

func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		falhas += 1
		push_error("CLICK_CONTROLS_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "Condição do teste: change_scene_to_file(\"res://scenes/prototipo_3d/vale.tscn\") == OK")
	if falhas > 0:
		quit(1)
		return
	for frame in range(4):
		await process_frame
	await _mundo_pronto()
	for frame in range(4):
		await physics_frame
	var game := current_scene
	_conferir(game != null, "Condição do teste: game != null")
	if game == null:
		quit(1)
		return
	var world: Node3D = game.get_node("Cenario")
	var player: CharacterBody3D = game.get_node("Jogador")
	var houses := get_nodes_in_group("interactive_house")
	_conferir(houses.size() >= 5, "Condição do teste: houses.size() >= 5")
	var offshore: Area3D
	var restaurant: Area3D
	for house in houses:
		var properties: Dictionary = world.get_house_properties(house)
		if properties.get("name") == "Casa da estrada":
			offshore = house
		elif properties.get("name") == "Restaurante":
			restaurant = house
	_conferir(offshore != null and restaurant != null, "Condição do teste: offshore != null and restaurant != null")
	if offshore == null or restaurant == null:
		quit(1)
		return
	# Desde a revisão de 26/09/2026 do KML, a Casa da estrada fica em terra firme: tem destino a pé.
	_conferir(world.get_house_destination(offshore, player.global_position).is_finite(), "Condição do teste: world.get_house_destination(offshore, player.global_position).is_finite()")
	world.set_hovered_house(restaurant)
	var label: Label3D = restaurant.get_meta("house_label")
	_conferir(label.visible and label.text.contains("Clique para ver propriedades"), "Condição do teste: label.visible and label.text.contains(\"Clique para ver propriedades\")")
	world.interact_with_house(restaurant)
	_conferir(label.visible and label.text.contains("Objeto: casa_pasto"), "Condição do teste: label.visible and label.text.contains(\"Objeto: casa_pasto\")")
	var target: Vector3 = world.get_house_destination(restaurant, player.global_position)
	_conferir(target.is_finite() and world.is_walkable_point(target), "Condição do teste: target.is_finite() and world.is_walkable_point(target)")
	var started_ms := Time.get_ticks_msec()
	var path: PackedVector3Array = player._navigator.find_path(player.global_position, target)
	var route_ms := Time.get_ticks_msec() - started_ms
	_conferir(not path.is_empty(), "Condição do teste: not path.is_empty()")
	world.clear_house_interaction()
	player.set_captured(false)
	player.camera.global_position = restaurant.global_position + Vector3(0, 15, 17)
	player.camera.look_at(restaurant.global_position + Vector3.UP * 2.0)
	var screen_center := root.get_viewport().get_visible_rect().size * 0.5
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.position = screen_center
	right_click.pressed = true
	player._unhandled_input(right_click)
	for frame in range(2):
		await physics_frame
	_conferir(not label.visible or not label.text.contains("Objeto: casa_pasto"), "Condição do teste: not label.visible or not label.text.contains(\"Objeto: casa_pasto\")")
	_conferir(not player._walk_path.is_empty(), "Condição do teste: not player._walk_path.is_empty()")
	var walking_start: Vector3 = player.global_position
	for frame in range(40):
		await physics_frame
	_conferir(player.global_position.distance_to(walking_start) > 1.0, "Condição do teste: player.global_position.distance_to(walking_start) > 1.0")
	Input.action_press("mv_forward")
	for frame in range(2):
		await physics_frame
	Input.action_release("mv_forward")
	_conferir(player._walk_path.is_empty(), "Condição do teste: player._walk_path.is_empty()")
	player.camera.global_position = restaurant.global_position + Vector3(0, 15, 17)
	player.camera.look_at(restaurant.global_position + Vector3.UP * 2.0)
	var double_click := InputEventMouseButton.new()
	double_click.button_index = MOUSE_BUTTON_LEFT
	double_click.position = screen_center
	double_click.double_click = true
	double_click.pressed = true
	player._unhandled_input(double_click)
	var double_release := InputEventMouseButton.new()
	double_release.button_index = MOUSE_BUTTON_LEFT
	double_release.position = screen_center
	double_release.pressed = false
	player._input(double_release)
	for frame in range(2):
		await physics_frame
	_conferir(label.visible and label.text.contains("Objeto: casa_pasto"), "Condição do teste: label.visible and label.text.contains(\"Objeto: casa_pasto\")")
	var empty_click := InputEventMouseButton.new()
	empty_click.button_index = MOUSE_BUTTON_LEFT
	empty_click.position = Vector2(1, 1)
	empty_click.pressed = true
	player._unhandled_input(empty_click)
	var empty_release := InputEventMouseButton.new()
	empty_release.button_index = MOUSE_BUTTON_LEFT
	empty_release.position = Vector2(1, 1)
	empty_release.pressed = false
	player._input(empty_release)
	for frame in range(2):
		await physics_frame
	_conferir(not label.visible, "Condição do teste: not label.visible")
	print("CLICK_CONTROLS_OK houses=", houses.size(), " route_points=", path.size(), " route_ms=", route_ms, " destination=", target)
	quit(1 if falhas > 0 else 0)


## O vale se monta ao longo de vários quadros (world_builder): espera ficar pronto.
func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
