extends CanvasLayer
## Interface leve para o primeiro teste do personagem em 3D.

signal reset_requested
signal quit_requested

const INK := Color("e8e4d7")
const MUTED := Color("aebaae")
const GOLD := Color("d6ba78")

var _model_status := "Preparando personagem…"
var _telemetry := ""
var _notice := ""
var _objective := "Explore o vale e observe o personagem de todos os ângulos."
var _captured := false
var _refresh_time := 0.0
var _root: Control
var _model_label: Label
var _telemetry_label: Label
var _notice_label: Label
var _notice_panel: Panel
var _objective_label: Label
var _capture_prompt: Panel


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.name = "PrototypeHUD"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var heading := _panel(Color(0.055, 0.085, 0.075, 0.82))
	_place(heading, Vector2(18, 18), Vector2(500, 132))
	var title := _label("MYTHS’ VALLEY", 28, INK)
	_place(title, Vector2(33, 25), Vector2(435, 39))
	var subtitle := _label("PRIMEIROS PASSOS · 3D", 12, GOLD)
	_place(subtitle, Vector2(35, 67), Vector2(435, 23))
	_objective_label = _label(_objective, 15, MUTED)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_objective_label, Vector2(35, 101), Vector2(466, 42))

	var status := _panel(Color(0.055, 0.085, 0.075, 0.82))
	_root.add_child(status)
	status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	status.offset_left = -303
	status.offset_right = -28
	status.offset_top = 25
	status.offset_bottom = 111
	_telemetry_label = _label("", 13, GOLD)
	status.add_child(_telemetry_label)
	_telemetry_label.position = Vector2(16, 12)
	_telemetry_label.size = Vector2(243, 22)
	_model_label = _label(_model_status, 12, MUTED)
	_model_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_child(_model_label)
	_model_label.position = Vector2(16, 37)
	_model_label.size = Vector2(243, 41)

	var controls := _panel(Color(0.055, 0.085, 0.075, 0.88))
	_root.add_child(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_left = 24
	controls.offset_right = -24
	controls.offset_top = -91
	controls.offset_bottom = -23
	var primary := _label("WASD mover  ·  Shift correr  ·  Mouse câmera  ·  R reiniciar  ·  Esc liberar mouse", 14, INK)
	controls.add_child(primary)
	primary.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	primary.offset_left = 18
	primary.offset_right = -18
	primary.offset_top = 10
	primary.offset_bottom = 33
	primary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var secondary := _label("F observar  ·  1–8 testar animações  ·  Rodinha zoom", 12, MUTED)
	controls.add_child(secondary)
	secondary.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	secondary.offset_top = -29
	secondary.offset_bottom = -7
	secondary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_notice_panel = _panel(Color(0.055, 0.085, 0.075, 0.82))
	_root.add_child(_notice_panel)
	_notice_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_notice_panel.offset_left = -285
	_notice_panel.offset_right = 285
	_notice_panel.offset_top = -136
	_notice_panel.offset_bottom = -103
	_notice_panel.visible = not _notice.is_empty()
	_notice_label = _label(_notice, 14, GOLD)
	_root.add_child(_notice_label)
	_notice_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_notice_label.offset_left = 30
	_notice_label.offset_right = -30
	_notice_label.offset_top = -132
	_notice_label.offset_bottom = -103
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_capture_prompt = _panel(Color(0.055, 0.085, 0.075, 0.88))
	_root.add_child(_capture_prompt)
	_capture_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_capture_prompt.offset_left = -163
	_capture_prompt.offset_right = 163
	_capture_prompt.offset_top = -38
	_capture_prompt.offset_bottom = 38
	var prompt := _label("Clique para explorar", 21, INK)
	_capture_prompt.add_child(prompt)
	prompt.position = Vector2(12, 12)
	prompt.size = Vector2(302, 29)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := _label("Esc devolve o cursor", 12, MUTED)
	_capture_prompt.add_child(hint)
	hint.position = Vector2(12, 44)
	hint.size = Vector2(302, 21)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_capture_prompt.visible = not _captured
	_update_telemetry()


func _process(delta: float) -> void:
	_refresh_time += delta
	if _refresh_time >= 0.35:
		_refresh_time = 0.0
		_update_telemetry()


func set_model_status(value: String) -> void:
	_model_status = value
	if is_instance_valid(_model_label):
		_model_label.text = value


func set_telemetry(value: String) -> void:
	_telemetry = value
	_update_telemetry()


func set_notice(value: String) -> void:
	_notice = value
	if is_instance_valid(_notice_label):
		_notice_label.text = value
		_notice_panel.visible = not value.is_empty()


func set_objective(value: String) -> void:
	_objective = value
	if is_instance_valid(_objective_label):
		_objective_label.text = value


func set_captured(value: bool) -> void:
	_captured = value
	if is_instance_valid(_capture_prompt):
		_capture_prompt.visible = not value


func _update_telemetry() -> void:
	if is_instance_valid(_telemetry_label):
		var suffix := "  ·  " + _telemetry if not _telemetry.is_empty() else ""
		_telemetry_label.text = "%d FPS%s" % [Engine.get_frames_per_second(), suffix]


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _place(control: Control, at: Vector2, dimensions: Vector2) -> void:
	_root.add_child(control)
	control.position = at
	control.size = dimensions


func _panel(color: Color) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	style.border_color = Color(0.58, 0.64, 0.48, 0.2)
	panel.add_theme_stylebox_override("panel", style)
	return panel
