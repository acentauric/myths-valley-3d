extends CharacterBody3D
## A colisão e a câmera pertencem ao controlador; o FBX é uma cena substituível.

signal capture_changed(captured: bool)

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

func _ready() -> void:
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
	if model_scene:
		model = model_scene.instantiate() as Node3D
		visual.add_child(model)
		_measure_model(model)
		if _has_bounds and model_bounds.size.y > 0.001:
			var factor: float = character_height / model_bounds.size.y
			model.scale *= factor
			model.position = -Vector3(model_bounds.get_center().x, model_bounds.position.y, model_bounds.get_center().z) * factor
		model.rotation.y = model_yaw_offset
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
	camera.far = 220.0
	spring.add_child(camera)
	camera.current = true
	_apply_camera()

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

func _physics_process(delta: float) -> void:
	var input_vector := Vector2.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		input_vector = Input.get_vector("mv_left", "mv_right", "mv_forward", "mv_back")
	var direction: Vector3 = Basis(Vector3.UP, _yaw) * Vector3(input_vector.x, 0, input_vector.y)
	var speed: float = run_speed if Input.is_action_pressed("mv_run") else walk_speed
	velocity.x = move_toward(velocity.x, direction.x * speed, 18.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 18.0 * delta)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = -0.1
	move_and_slide()
	if direction.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-12.0 * delta))
	if animator:
		animator.update_motion(Vector2(velocity.x, velocity.z).length(), delta)
	if global_position.y < -6.0:
		reset_position()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -0.95, 0.35)
		_apply_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			set_captured(true)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(1.6, _distance - 0.35)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(8.0, _distance + 0.35)
		_apply_camera()
	if event.is_action_pressed("mv_release"):
		set_captured(false)
	if event.is_action_pressed("mv_reset"):
		reset_position()
	if event.is_action_pressed("mv_inspect"):
		inspecting = not inspecting
		_yaw = visual.rotation.y if inspecting else visual.rotation.y + PI
		_pitch = -0.08 if inspecting else -0.19
		_distance = 3.1 if inspecting else 5.0
		_apply_camera()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_captured(false)

func set_captured(value: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if value else Input.MOUSE_MODE_VISIBLE
	capture_changed.emit(value)

func reset_position() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	visual.rotation.y = 0.0
	_yaw = 0.0
	_pitch = -0.19
	_distance = 5.0
	inspecting = false
	_apply_camera()

func _apply_camera() -> void:
	camera_pivot.rotation.y = _yaw
	spring.rotation.x = _pitch
	spring.spring_length = _distance
