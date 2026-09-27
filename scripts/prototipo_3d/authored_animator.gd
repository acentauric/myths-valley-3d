extends Node
## Reproduz os clipes incorporados ao GLB do Tripo.

const MOTION_CLIPS := {
	"idle": "idle",
	"walk": "walk",
	"run": "run",
	"swim": "swim",
}

const GESTURES := [
	{"clip": "greet_01", "label": "Saudação"},
	{"clip": "wave_goodbye_02", "label": "Dar tchau"},
	{"clip": "agree", "label": "Concordar"},
	{"clip": "look_around", "label": "Olhar ao redor"},
	{"clip": "afraid", "label": "Com medo"},
	{"clip": "fold_arms", "label": "Cruzar os braços"},
	{"clip": "chop", "label": "Golpear"},
	{"clip": "swim", "label": "Nadar"},
	{"clip": "jump_down", "label": "Pular baixo"},
]

var animation_player: AnimationPlayer
var _current_motion := ""
## Nome-base → nome real do clipe. O Tripo exporta clipes com sufixo ("walk.001") e o
## Godot os importa como "walk_001", "greet_01_002"; o sufixo de três dígitos some e o
## primeiro clipe de cada nome vence.
var _clips: Dictionary = {}
var _gesture_active := false
var _jump_active := false
## Na água funda o movimento vira nado (clipe "swim" em laço, se o modelo tiver).
var _swimming := false


func configure(model_root: Node) -> bool:
	var players := model_root.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_warning("O modelo não contém AnimationPlayer; usando animação provisória.")
		return false
	animation_player = players[0] as AnimationPlayer
	animation_player.animation_finished.connect(_on_animation_finished)
	_clips.clear()
	for real: StringName in animation_player.get_animation_list():
		var base := _nome_base(String(real))
		if not _clips.has(base):
			_clips[base] = String(real)
	for clip: String in MOTION_CLIPS.values():
		if _clips.has(clip):
			animation_player.get_animation(_clips[clip]).loop_mode = Animation.LOOP_LINEAR
	_play_motion("idle", 1.0)
	return true


func update_motion(speed: float, _delta: float) -> void:
	if animation_player == null:
		return
	if _jump_active:
		return
	if _gesture_active:
		if speed < 0.2 and not _swimming:
			return
		_gesture_active = false

	if _swimming and _clips.has("swim"):
		# Parado, bate as pernas devagar para se manter na superfície.
		_play_motion("swim", clampf(0.45 + speed / 2.0, 0.45, 1.3))
	elif speed > 4.25:
		_play_motion("run", clampf(speed / 5.8, 0.85, 1.25))
	elif speed > 0.2:
		_play_motion("walk", clampf(speed / 3.2, 0.7, 1.35))
	else:
		_play_motion("idle", 1.0)


func play_gesture(index: int) -> String:
	if animation_player == null or index < 0 or index >= GESTURES.size():
		return ""
	var entry: Dictionary = GESTURES[index]
	var clip: String = _clips.get(entry["clip"], "")
	if clip.is_empty():
		return ""
	_gesture_active = true
	_jump_active = index == 8
	_current_motion = ""
	animation_player.speed_scale = 4.8 if _jump_active else 1.0
	animation_player.play(clip, 0.18)
	var label: String = entry["label"]
	return label


func set_swimming(swimming: bool) -> void:
	if _swimming == swimming:
		return
	_swimming = swimming
	_current_motion = ""


func can_swim() -> bool:
	return _clips.has("swim")


func finish_jump(speed: float) -> void:
	if not _jump_active:
		return
	_jump_active = false
	_gesture_active = false
	_current_motion = ""
	update_motion(speed, 0.0)


func get_animation_names() -> PackedStringArray:
	return animation_player.get_animation_list() if animation_player else PackedStringArray()


func get_current_animation() -> StringName:
	return animation_player.current_animation if animation_player else &""


func is_using_authored_clips() -> bool:
	return animation_player != null


func _play_motion(role: String, speed_scale: float) -> void:
	var clip: String = _clips.get(MOTION_CLIPS.get(role, ""), "")
	if clip.is_empty():
		return
	animation_player.speed_scale = speed_scale
	if _current_motion == role and animation_player.is_playing():
		return
	_current_motion = role
	animation_player.play(clip, 0.18)


func _on_animation_finished(_animation_name: StringName) -> void:
	if not _gesture_active or _jump_active:
		return
	_gesture_active = false
	_play_motion("idle", 1.0)


static func _nome_base(nome: String) -> String:
	var regex := RegEx.create_from_string("^(.+)[._]\\d{3}$")
	var achado := regex.search(nome)
	return achado.get_string(1) if achado else nome
