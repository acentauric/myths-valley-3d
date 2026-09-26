extends SceneTree
## Verifica alvos de casas, acesso ao terreno e rota a partir do píer.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	assert(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK)
	for frame in range(4):
		await process_frame
	for frame in range(4):
		await physics_frame
	var game := current_scene
	assert(game != null)
	var world: Node3D = game.get_node("Cenario")
	var player: CharacterBody3D = game.get_node("Jogador")
	var houses := get_nodes_in_group("interactive_house")
	assert(houses.size() >= 5)
	var offshore: Area3D
	var restaurant: Area3D
	for house in houses:
		var properties: Dictionary = world.get_house_properties(house)
		if properties.get("name") == "Casa da estrada":
			offshore = house
		elif properties.get("name") == "Restaurante":
			restaurant = house
	assert(offshore != null and restaurant != null)
	assert(not world.get_house_destination(offshore, player.global_position).is_finite())
	world.set_hovered_house(restaurant)
	var label: Label3D = restaurant.get_meta("house_label")
	assert(label.visible and label.text.contains("Clique para ver propriedades"))
	world.interact_with_house(restaurant)
	assert(label.visible and label.text.contains("Objeto: casa_pasto"))
	var target: Vector3 = world.get_house_destination(restaurant, player.global_position)
	assert(target.is_finite() and world.is_walkable_point(target))
	var started_ms := Time.get_ticks_msec()
	var path: PackedVector3Array = player._navigator.find_path(player.global_position, target)
	var route_ms := Time.get_ticks_msec() - started_ms
	assert(not path.is_empty())
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
	assert(not label.visible or not label.text.contains("Objeto: casa_pasto"))
	assert(not player._walk_path.is_empty())
	var walking_start: Vector3 = player.global_position
	for frame in range(40):
		await physics_frame
	assert(player.global_position.distance_to(walking_start) > 1.0)
	Input.action_press("mv_forward")
	for frame in range(2):
		await physics_frame
	Input.action_release("mv_forward")
	assert(player._walk_path.is_empty())
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
	assert(label.visible and label.text.contains("Objeto: casa_pasto"))
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
	assert(not label.visible)
	print("CLICK_CONTROLS_OK houses=", houses.size(), " route_points=", path.size(), " route_ms=", route_ms, " destination=", target)
	quit()
