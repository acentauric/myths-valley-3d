extends Node3D

@onready var player = $Jogador
@onready var hud = $HUD
@onready var world = $Cenario
var _visited: Dictionary = {}
var _step_time := 0.0

func _enter_tree() -> void:
	_bind("mv_forward", [KEY_W, KEY_UP])
	_bind("mv_back", [KEY_S, KEY_DOWN])
	_bind("mv_left", [KEY_A, KEY_LEFT])
	_bind("mv_right", [KEY_D, KEY_RIGHT])
	_bind("mv_run", [KEY_SHIFT])
	_bind("mv_release", [KEY_ESCAPE])
	_bind("mv_reset", [KEY_R])
	_bind("mv_inspect", [KEY_F])
	for index in range(8):
		_bind("mv_animation_%d" % (index + 1), [KEY_1 + index])

func _ready() -> void:
	Audio.parar_narracao()
	Audio.tocar_musica()
	var spawn: Vector3 = world.get_spawn_position()
	player.spawn_position = spawn
	player.global_position = spawn
	player.capture_changed.connect(hud.set_captured)
	player.animation_requested.connect(_on_animation_requested)
	hud.menu_requested.connect(_return_to_menu)
	hud.set_region_title(world.get_region_title())
	hud.set_model_status("Seu modelo Tripo · 65 ossos\n11 animações incorporadas")
	hud.set_telemetry("GLB · 1,78 m")
	hud.set_objective("Explore os caminhos e pontos de interesse de %s." % world.get_region_title())
	hud.set_notice("Mapa geográfico em escala real · 1 unidade = 1 metro")
	print("PROTOTYPE_READY: modelo GLB com animações, câmera e cenário carregados; user_dir=", OS.get_user_data_dir())

func _process(_delta: float) -> void:
	_step_time -= _delta
	if player.is_on_floor() and Vector2(player.velocity.x, player.velocity.z).length() > 0.3:
		if _step_time <= 0:
			var running := Input.is_action_pressed("mv_run")
			var terrain: String = world.surface_at(player.global_position)
			if terrain == "agua":
				terrain = "areia"
			Audio.passo(terrain, running)
			_step_time = 0.32 if running else 0.48
	else:
		_step_time = 0
	for landmark: Dictionary in world.landmarks:
		var landmark_id: String = landmark["id"]
		var landmark_name: String = landmark["name"]
		var destination: Vector3 = landmark["position"]
		if not _visited.has(landmark_id) and player.global_position.distance_to(destination) < 7.0:
			_visited[landmark_id] = true
			hud.set_notice("Você chegou: %s  ·  %d/%d pontos explorados" % [landmark_name, _visited.size(), world.landmarks.size()])

func _bind(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key: int in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		_return_to_menu()

func _return_to_menu() -> void:
	player.set_captured(false)
	get_tree().change_scene_to_file("res://scenes/prototipo_3d/abertura.tscn")

func _on_animation_requested(label: String) -> void:
	hud.set_notice("Animação: %s · mova o personagem para interromper" % label)
