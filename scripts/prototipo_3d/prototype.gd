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
	player.capture_changed.connect(hud.set_captured)
	player.animation_requested.connect(_on_animation_requested)
	hud.set_model_status("Seu modelo Tripo · 65 ossos\n11 animações incorporadas")
	hud.set_telemetry("GLB · 1,78 m")
	hud.set_objective("Praça à frente · Horta à direita · Costa à esquerda.")
	hud.set_notice("Personagem animado! Mova-se ou use as teclas 1–8.")
	print("PROTOTYPE_READY: modelo GLB com animações, câmera e cenário carregados; user_dir=", OS.get_user_data_dir())

func _process(_delta: float) -> void:
	_step_time -= _delta
	if player.is_on_floor() and Vector2(player.velocity.x, player.velocity.z).length() > 0.3:
		if _step_time <= 0:
			var running := Input.is_action_pressed("mv_run")
			var terrain := "areia" if player.position.x < -17 else "grama"
			if absf(player.position.x) < 2 or absf(player.position.z + 3) < 1.5:
				terrain = "terra"
			Audio.passo(terrain, running)
			_step_time = 0.32 if running else 0.48
	else:
		_step_time = 0
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

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://scenes/prototipo_3d/abertura.tscn")


func _on_animation_requested(label: String) -> void:
	hud.set_notice("Animação: %s · mova o personagem para interromper" % label)
