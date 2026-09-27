extends CharacterBody3D
## A colisão e a câmera pertencem ao controlador; o corpo é escolhido pelo estilo visual
## (autoload Estilo): humanoide procedural ou a cena GLB configurada (modo Tripo).

signal capture_changed(captured: bool)
signal camera_lock_changed(locked: bool)
signal animation_requested(label: String)
signal navigation_status(message: String)

const ClickNavigation = preload("res://scripts/prototipo_3d/click_navigation.gd")
const HOUSE_INTERACTION_LAYER := 1 << 12
const ARRIVAL_DISTANCE := 0.7
const CAMERA_DRAG_THRESHOLD := 6.0
const JUMP_VELOCITY := 6.7
const JUMP_GRAVITY_UP := 15.0
const JUMP_GRAVITY_DOWN := 25.0

@export var model_scene: PackedScene
@export var character_height: float = 1.78
@export var walk_speed: float = 3.2
@export var run_speed: float = 5.8
@export var mouse_sensitivity: float = 0.0025
@export var model_yaw_offset: float = 0.0
@export var double_sided_materials: bool = true

var visual: Node3D
var model: Node3D
var camera_pivot: Node3D
var spring: SpringArm3D
var camera: Camera3D
var animator: Node
var model_bounds := AABB()
var _has_bounds := false
var spawn_position := Vector3(0, 0.05, 6)
var inspecting := false
var _yaw: float = 0.0
var _pitch: float = -0.19
var _distance: float = 5.0
var _click_world: Node3D
var _navigator = ClickNavigation.new()
var _walk_path := PackedVector3Array()
var _walk_index := 0
var _walk_destination := Vector3.INF
var _stuck_time := 0.0
var _replan_attempts := 0
var _hovered_house: Object
var _pending_walk_click := Vector2.INF
var _pending_walk_run := false
var _walk_run := false
var _pending_interact_click := Vector2.INF
var _pending_house_click := Vector2.INF
var _camera_locked := false
var _camera_drag_pressed := false
var _camera_drag_moved := false
var _camera_drag_double_click := false
var _camera_drag_start := Vector2.ZERO
var _jump_requested := false
var _jumping := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group("map_player")
	spawn_position = position
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(46)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = character_height
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = character_height * 0.5
	add_child(collision)
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	# No estilo Tripo o viajante gerado no Studio substitui o GLB medieval só quando já
	# tiver rig e clipes (AnimationPlayer); um modelo estático deslizaria sem andar.
	var scene: PackedScene = model_scene
	if Estilo.tripo() and CatalogoAssets.tem_tripo("viajante"):
		var candidato := CatalogoAssets.cena("viajante")
		if candidato != null and _tem_animacoes(candidato):
			scene = candidato
	if Estilo.procedural():
		var procedural := PersonagemProcedural.novo("viajante", character_height)
		visual.add_child(procedural)
		model = procedural
		animator = procedural
	elif scene:
		model = scene.instantiate() as Node3D
		visual.add_child(model)
		_measure_model(model)
		if _has_bounds and model_bounds.size.y > 0.001:
			var factor: float = character_height / model_bounds.size.y
			model.scale *= factor
			model.position = -Vector3(model_bounds.get_center().x, model_bounds.position.y, model_bounds.get_center().z) * factor
		model.rotation.y = model_yaw_offset
		animator = load("res://scripts/prototipo_3d/authored_animator.gd").new()
		add_child(animator)
		if not animator.configure(model):
			animator.queue_free()
			animator = load("res://scripts/prototipo_3d/provisional_animator.gd").new()
			add_child(animator)
			animator.configure(model)
	else:
		push_error("A cena do personagem não foi configurada.")
	camera_pivot = Node3D.new()
	camera_pivot.position.y = 1.18
	add_child(camera_pivot)
	spring = SpringArm3D.new()
	spring.spring_length = _distance
	spring.margin = 0.18
	var camera_shape := SphereShape3D.new()
	camera_shape.radius = 0.18
	spring.shape = camera_shape
	spring.add_excluded_object(get_rid())
	camera_pivot.add_child(spring)
	camera = Camera3D.new()
	camera.fov = 58.0
	camera.near = 0.08
	camera.far = 2800.0
	spring.add_child(camera)
	camera.current = true
	_apply_camera()

func _tem_animacoes(scene: PackedScene) -> bool:
	var probe := scene.instantiate()
	var animado := not probe.find_children("*", "AnimationPlayer", true, false).is_empty()
	probe.free()
	return animado


func _measure_model(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var bounds: AABB = (model.global_transform.affine_inverse() * mesh_node.global_transform) * mesh_node.get_aabb()
		model_bounds = model_bounds.merge(bounds) if _has_bounds else bounds
		_has_bounds = true
		# O FBX fornecido possui faces de roupa com orientação invertida.
		# Corrigir a visibilidade só nesta instância, preservando o arquivo original.
		if double_sided_materials:
			for index in mesh_node.mesh.get_surface_count():
				var original := mesh_node.get_active_material(index) as BaseMaterial3D
				if original:
					var material := original.duplicate() as BaseMaterial3D
					material.cull_mode = BaseMaterial3D.CULL_DISABLED
					mesh_node.set_surface_override_material(index, material)
	for child in node.get_children():
		_measure_model(child)


func configure_click_world(world: Node3D) -> void:
	_click_world = world
	_navigator.configure(world)


func _update_house_hover() -> void:
	if _click_world == null:
		return
	if _camera_drag_pressed and _camera_drag_moved:
		if _hovered_house != null:
			_hovered_house = null
			_click_world.set_hovered_house(null)
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		var hit := _pointed_house(get_viewport().get_mouse_position())
		var collider: Object = hit.get("collider")
		if collider != _hovered_house:
			_hovered_house = collider
			_click_world.set_hovered_house(collider)
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if collider != null else Input.CURSOR_ARROW)
	elif _hovered_house != null:
		_hovered_house = null
		_click_world.set_hovered_house(null)
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _physics_process(delta: float) -> void:
	_update_house_hover()
	if _pending_house_click.is_finite():
		var pointed_house := _pointed_house(_pending_house_click)
		_pending_house_click = Vector2.INF
		if _click_world != null:
			if pointed_house.is_empty():
				_click_world.clear_house_interaction()
			else:
				_click_world.interact_with_house(pointed_house["collider"])
	if _pending_interact_click.is_finite():
		var house_hit := _pointed_house(_pending_interact_click)
		_pending_interact_click = Vector2.INF
		if not house_hit.is_empty() and _click_world != null:
			_click_world.interact_with_house(house_hit["collider"])
	if _pending_walk_click.is_finite():
		_request_walk_at_cursor(_pending_walk_click, _pending_walk_run)
		_pending_walk_click = Vector2.INF
		_pending_walk_run = false
	var input_vector := Input.get_vector("mv_left", "mv_right", "mv_forward", "mv_back")
	if input_vector.length_squared() > 0.001:
		_cancel_walk()
	var direction: Vector3 = Basis(Vector3.UP, _yaw) * Vector3(input_vector.x, 0, input_vector.y)
	if input_vector.length_squared() <= 0.001 and not _walk_path.is_empty():
		direction = _next_walk_direction()
	var speed: float = run_speed if Input.is_action_pressed("mv_run") or (_walk_run and not _walk_path.is_empty()) else walk_speed
	velocity.x = move_toward(velocity.x, direction.x * speed, 18.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 18.0 * delta)
	if _jump_requested and is_on_floor():
		velocity.y = JUMP_VELOCITY
		_jumping = true
		if animator and animator.has_method("play_gesture"):
			var label: String = animator.play_gesture(8)
			if not label.is_empty():
				animation_requested.emit(label)
	_jump_requested = false
	if _jumping:
		velocity.y -= (JUMP_GRAVITY_UP if velocity.y > 0.0 else JUMP_GRAVITY_DOWN) * delta
	elif not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = -0.1
	var distance_before := _distance_to_next_waypoint()
	move_and_slide()
	if _jumping and is_on_floor():
		_jumping = false
		if animator and animator.has_method("finish_jump"):
			animator.finish_jump(Vector2(velocity.x, velocity.z).length())
	if not _walk_path.is_empty() and direction.length_squared() > 0.01:
		var progress := distance_before - _distance_to_next_waypoint()
		_stuck_time = 0.0 if progress > 0.003 else _stuck_time + delta
		if _stuck_time > 1.4:
			_retry_walk()
	if direction.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-12.0 * delta))
	if animator:
		animator.update_motion(Vector2(velocity.x, velocity.z).length(), delta)
	if global_position.y < -6.0:
		reset_position()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _camera_locked and _camera_drag_pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		if not _camera_drag_moved and event.position.distance_to(_camera_drag_start) >= CAMERA_DRAG_THRESHOLD:
			_camera_drag_moved = true
		if _camera_drag_moved:
			_rotate_camera(event.relative)
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _camera_drag_pressed:
		if not _camera_drag_moved:
			if _camera_drag_double_click:
				_pending_interact_click = event.position
			else:
				_pending_house_click = event.position
		_camera_drag_pressed = false
		_camera_drag_moved = false
		_camera_drag_double_click = false
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("mv_release"):
			set_camera_locked(true)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("mv_cursor"):
			set_camera_locked(not _camera_locked)
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(event.relative)
	if event is InputEventMouseButton and event.pressed:
		if _camera_locked and event.button_index == MOUSE_BUTTON_LEFT:
			_camera_drag_pressed = true
			_camera_drag_moved = false
			_camera_drag_double_click = event.double_click
			_camera_drag_start = event.position
		elif Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and event.button_index == MOUSE_BUTTON_RIGHT:
			_pending_walk_click = event.position
			_pending_walk_run = event.double_click
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(1.6, _distance - 0.35)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(8.0, _distance + 0.35)
		_apply_camera()
	if event.is_action_pressed("mv_reset"):
		reset_position()
	if event.is_action_pressed("mv_inspect"):
		inspecting = not inspecting
		_yaw = visual.rotation.y if inspecting else visual.rotation.y + PI
		_pitch = -0.08 if inspecting else -0.19
		_distance = 3.1 if inspecting else 5.0
		_apply_camera()
	if event.is_action_pressed("mv_animation_9"):
		_jump_requested = true
	if not _jumping:
		for index in range(8):
			if event.is_action_pressed("mv_animation_%d" % (index + 1)) and animator and animator.has_method("play_gesture"):
				var label: String = animator.play_gesture(index)
				if not label.is_empty():
					animation_requested.emit(label)
				break

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_camera_drag_pressed = false
		_camera_drag_moved = false
		set_camera_locked(true)


func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func set_captured(value: bool) -> void:
	set_camera_locked(not value)


func set_camera_locked(value: bool) -> void:
	_camera_locked = value
	_camera_drag_pressed = false
	_camera_drag_moved = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
	if not value and _click_world != null:
		_click_world.clear_house_interaction()
		_hovered_house = null
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	capture_changed.emit(not value)
	camera_lock_changed.emit(value)


func _rotate_camera(relative: Vector2) -> void:
	_yaw -= relative.x * mouse_sensitivity
	_pitch = clampf(_pitch - relative.y * mouse_sensitivity, -0.95, 0.35)
	_apply_camera()

func reset_position() -> void:
	_cancel_walk()
	global_position = spawn_position
	velocity = Vector3.ZERO
	_jump_requested = false
	_jumping = false
	if animator and animator.has_method("finish_jump"):
		animator.finish_jump(0.0)
	visual.rotation.y = 0.0
	_yaw = 0.0
	_pitch = -0.19
	_distance = 5.0
	inspecting = false
	_apply_camera()


func _raycast_cursor(mouse: Vector2, mask: int, areas: bool = false) -> Dictionary:
	var ray_from := camera.project_ray_origin(mouse)
	var ray_to := ray_from + camera.project_ray_normal(mouse) * camera.far
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to, mask, [get_rid()])
	query.collide_with_areas = areas
	query.collide_with_bodies = not areas
	return get_world_3d().direct_space_state.intersect_ray(query)


func _pointed_house(mouse: Vector2) -> Dictionary:
	var house_hit := _raycast_cursor(mouse, HOUSE_INTERACTION_LAYER, true)
	if house_hit.is_empty():
		return house_hit
	var body_hit := _raycast_cursor(mouse, 1)
	if not body_hit.is_empty():
		var body: Object = body_hit["collider"]
		if body is Node3D and (body as Node3D).is_in_group("moradores"):
			var ray_origin := camera.project_ray_origin(mouse)
			if ray_origin.distance_squared_to(body_hit["position"]) < ray_origin.distance_squared_to(house_hit["position"]):
				return {}
	return house_hit


func _request_walk_at_cursor(mouse: Vector2, run_to_destination: bool = false) -> void:
	if _click_world == null:
		return
	_cancel_walk()
	_click_world.clear_house_interaction()
	_hovered_house = null
	var house_hit := _pointed_house(mouse)
	var destination := Vector3.INF
	if not house_hit.is_empty():
		destination = _click_world.get_house_destination(house_hit["collider"], global_position)
	else:
		var ground_hit := _raycast_cursor(mouse, 1)
		if not ground_hit.is_empty():
			var collider: Object = ground_hit["collider"]
			if collider is Node3D and (collider as Node3D).is_in_group("moradores"):
				destination = _approach_npc(collider as Node3D)
			else:
				destination = ground_hit["position"]
	if not destination.is_finite() or not _click_world.is_walkable_point(destination):
		navigation_status.emit("Esse ponto não tem acesso caminhável.")
		return
	var path: PackedVector3Array = _navigator.find_path(global_position, destination)
	if path.is_empty():
		navigation_status.emit("Não encontrei um caminho até esse ponto.")
		return
	_walk_path = path
	_walk_run = run_to_destination
	_walk_index = 0
	_walk_destination = destination
	_stuck_time = 0.0
	_replan_attempts = 0
	navigation_status.emit("%s até o ponto selecionado. WASD cancela o trajeto." % ("Correndo" if run_to_destination else "Caminhando"))


func _approach_npc(npc: Node3D) -> Vector3:
	var away := global_position - npc.global_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.FORWARD
	for angle in [0.0, PI * 0.5, -PI * 0.5, PI]:
		var point := npc.global_position + away.normalized().rotated(Vector3.UP, angle) * 2.2
		if _click_world.is_walkable_point(point):
			return point
	return Vector3.INF


func _next_walk_direction() -> Vector3:
	while _walk_index < _walk_path.size():
		var waypoint := _walk_path[_walk_index]
		var offset := Vector3(waypoint.x - global_position.x, 0, waypoint.z - global_position.z)
		if offset.length() >= ARRIVAL_DISTANCE:
			return offset.normalized()
		_walk_index += 1
	_cancel_walk()
	navigation_status.emit("Destino alcançado.")
	return Vector3.ZERO


func _distance_to_next_waypoint() -> float:
	if _walk_index >= _walk_path.size():
		return 0.0
	var waypoint := _walk_path[_walk_index]
	return Vector2(global_position.x, global_position.z).distance_to(Vector2(waypoint.x, waypoint.z))


func _retry_walk() -> void:
	_stuck_time = 0.0
	_replan_attempts += 1
	if _replan_attempts > 2:
		_cancel_walk()
		navigation_status.emit("Caminho bloqueado. Escolha outro destino.")
		return
	var path: PackedVector3Array = _navigator.find_path(global_position, _walk_destination)
	if path.is_empty():
		_cancel_walk()
		navigation_status.emit("Caminho bloqueado. Escolha outro destino.")
		return
	_walk_path = path
	_walk_index = 0


func _cancel_walk() -> void:
	_walk_path.clear()
	_walk_run = false
	_walk_index = 0
	_walk_destination = Vector3.INF
	_stuck_time = 0.0
	_replan_attempts = 0


func get_animation_names() -> PackedStringArray:
	if animator and animator.has_method("get_animation_names"):
		return animator.get_animation_names()
	return PackedStringArray()


func get_current_animation() -> StringName:
	if animator and animator.has_method("get_current_animation"):
		return animator.get_current_animation()
	return &"procedural"


func _apply_camera() -> void:
	camera_pivot.rotation.y = _yaw
	spring.rotation.x = _pitch
	spring.spring_length = _distance
