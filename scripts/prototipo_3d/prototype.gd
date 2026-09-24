extends Node3D

@onready var player = $Jogador
@onready var hud = $HUD
@onready var world = $Cenario
var _visited: Dictionary = {}

func _enter_tree() -> void:
	_bind("mv_forward", [KEY_W, KEY_UP])
	_bind("mv_back", [KEY_S, KEY_DOWN])
	_bind("mv_left", [KEY_A, KEY_LEFT])
	_bind("mv_right", [KEY_D, KEY_RIGHT])
	_bind("mv_run", [KEY_SHIFT])
	_bind("mv_release", [KEY_ESCAPE])
	_bind("mv_reset", [KEY_R])
	_bind("mv_inspect", [KEY_F])

func _ready() -> void:
	player.capture_changed.connect(hud.set_captured)
	hud.set_model_status("Seu modelo Tripo · 65 ossos\nCaminhada provisória por código")
	hud.set_telemetry("FBX · 1,78 m")
	hud.set_objective("Praça à frente · Horta à direita · Costa à esquerda.")
	hud.set_notice("Seu personagem está pronto. Explore os três lugares do vale.")
	print("PROTOTYPE_READY: modelo FBX, câmera e cenário carregados; user_dir=", OS.get_user_data_dir())

func _process(_delta: float) -> void:
	for landmark: Dictionary in world.landmarks:
		var landmark_name: String = landmark["name"]
		var destination: Vector3 = landmark["position"]
		if not _visited.has(landmark_name) and player.global_position.distance_to(destination) < 3.2:
			_visited[landmark_name] = true
			hud.set_notice("Você chegou: %s  ·  %d/3 lugares explorados" % [landmark_name, _visited.size()])
			if _visited.size() == 3:
				hud.set_objective("Passeio concluído! Use F e o mouse para examinar seu personagem.")

func _bind(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key: int in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
