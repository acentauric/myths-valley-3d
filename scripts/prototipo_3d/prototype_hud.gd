extends CanvasLayer
## Interface leve para o primeiro teste do personagem em 3D.

signal reset_requested
signal quit_requested
signal menu_requested
signal camera_lock_requested(locked: bool)
signal house_info_close_requested

const INK := Color("e8e4d7")
const MUTED := Color("aebaae")
const GOLD := Color("d6ba78")

var _model_status := "Preparando personagem…"
var _telemetry := ""
var _notice := ""
var _objective := "Explore o vale e observe o personagem de todos os ângulos."
var _captured := false
var _camera_locked := false
var _refresh_time := 0.0
var _root: Control
var _model_label: Label
var _region_label: Label
var _telemetry_label: Label
var _render_label: Label
var _notice_label: Label
var _notice_panel: Panel
var _objective_label: Label
var _control_mode_label: Label
var _camera_lock_button: Button
var _house_info_panel: Panel
var _house_info_label: Label
var _clock_label: Label


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
	_region_label = _label("REGIÃO INICIAL", 12, GOLD)
	_place(_region_label, Vector2(35, 67), Vector2(435, 23))
	_objective_label = _label(_objective, 15, MUTED)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_objective_label, Vector2(35, 101), Vector2(466, 42))

	var status := _panel(Color(0.055, 0.085, 0.075, 0.82))
	_root.add_child(status)
	status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	status.offset_left = -303
	status.offset_right = -28
	status.offset_top = 25
	status.offset_bottom = 131
	_telemetry_label = _label("", 13, GOLD)
	status.add_child(_telemetry_label)
	_telemetry_label.position = Vector2(16, 12)
	_telemetry_label.size = Vector2(243, 22)
	_model_label = _label(_model_status, 12, MUTED)
	_model_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_child(_model_label)
	_model_label.position = Vector2(16, 37)
	_model_label.size = Vector2(243, 41)
	# Medição de desenvolvimento: triângulos e chamadas de desenho do quadro, memória de vídeo.
	_render_label = _label("", 11, MUTED)
	status.add_child(_render_label)
	_render_label.position = Vector2(16, 82)
	_render_label.size = Vector2(243, 20)
	var back_to_menu := Button.new()
	back_to_menu.text = "HOME"
	back_to_menu.tooltip_text = "Ir para o menu inicial. Pressione Esc para liberar o cursor."
	back_to_menu.add_theme_font_size_override("font_size", 16)
	back_to_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(back_to_menu)
	back_to_menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	back_to_menu.offset_left = -303
	back_to_menu.offset_right = -28
	back_to_menu.offset_top = 143
	back_to_menu.offset_bottom = 186
	back_to_menu.pressed.connect(func(): menu_requested.emit())
	_camera_lock_button = Button.new()
	_camera_lock_button.text = "TRAVAR CÂMERA (Esc)"
	_camera_lock_button.tooltip_text = "Esc trava a câmera. Tab alterna entre travada e destravada."
	_camera_lock_button.toggle_mode = true
	_camera_lock_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_camera_lock_button)
	_camera_lock_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_camera_lock_button.offset_left = -303
	_camera_lock_button.offset_right = -28
	_camera_lock_button.offset_top = 194
	_camera_lock_button.offset_bottom = 237
	_camera_lock_button.toggled.connect(func(locked: bool): camera_lock_requested.emit(locked))

	_house_info_panel = _panel(Color(0.055, 0.085, 0.075, 0.92))
	_root.add_child(_house_info_panel)
	_house_info_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_house_info_panel.offset_left = -368
	_house_info_panel.offset_right = -28
	_house_info_panel.offset_top = 250
	_house_info_panel.offset_bottom = 405
	_house_info_panel.visible = false
	var house_heading := _label("INFORMAÇÕES DA CASA", 13, GOLD)
	_house_info_panel.add_child(house_heading)
	house_heading.position = Vector2(16, 10)
	house_heading.size = Vector2(270, 24)
	_house_info_label = _label("", 15, INK)
	_house_info_panel.add_child(_house_info_label)
	_house_info_label.position = Vector2(16, 39)
	_house_info_label.size = Vector2(309, 108)
	var close_house_info := Button.new()
	close_house_info.text = "×"
	close_house_info.tooltip_text = "Fechar informações da casa"
	close_house_info.position = Vector2(299, 7)
	close_house_info.size = Vector2(32, 28)
	close_house_info.mouse_filter = Control.MOUSE_FILTER_STOP
	_house_info_panel.add_child(close_house_info)
	close_house_info.pressed.connect(func(): house_info_close_requested.emit())

	var controls := _panel(Color(0.055, 0.085, 0.075, 0.88))
	_root.add_child(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls.offset_left = 24
	controls.offset_right = -24
	controls.offset_top = -91
	controls.offset_bottom = -23
	var primary := _label("WASD mover  ·  Shift correr  ·  Direito: andar  ·  Duplo direito: correr  ·  Esquerdo na casa: dados", 14, INK)
	controls.add_child(primary)
	primary.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	primary.offset_left = 18
	primary.offset_right = -18
	primary.offset_top = 10
	primary.offset_bottom = 33
	primary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_control_mode_label = _label("", 12, MUTED)
	controls.add_child(_control_mode_label)
	_control_mode_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_control_mode_label.offset_top = -29
	_control_mode_label.offset_bottom = -7
	_control_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

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

	# Relógio do vale: hora, período do dia e estilo visual em uso.
	var clock_panel := _panel(Color(0.055, 0.085, 0.075, 0.82))
	_root.add_child(clock_panel)
	clock_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	clock_panel.offset_left = -215
	clock_panel.offset_right = 215
	clock_panel.offset_top = 18
	clock_panel.offset_bottom = 52
	_clock_label = _label("", 15, GOLD)
	clock_panel.add_child(_clock_label)
	_clock_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_update_control_mode()
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


func set_region_title(value: String) -> void:
	if is_instance_valid(_region_label):
		_region_label.text = value.to_upper()


func set_telemetry(value: String) -> void:
	_telemetry = value
	_update_telemetry()


func set_notice(value: String) -> void:
	_notice = value
	if is_instance_valid(_notice_label):
		_notice_label.text = value
		_notice_panel.visible = not value.is_empty()


func show_house_info(value: String) -> void:
	_house_info_label.text = value
	_house_info_panel.visible = true


func clear_house_info() -> void:
	_house_info_panel.visible = false


func set_objective(value: String) -> void:
	_objective = value
	if is_instance_valid(_objective_label):
		_objective_label.text = value


func set_clock(value: String) -> void:
	if is_instance_valid(_clock_label):
		_clock_label.text = value


func set_captured(value: bool) -> void:
	_captured = value
	_update_control_mode()


func set_camera_locked(value: bool) -> void:
	_camera_locked = value
	if is_instance_valid(_camera_lock_button):
		_camera_lock_button.set_pressed_no_signal(value)
		_camera_lock_button.text = "DESTRAVAR CÂMERA (Tab)" if value else "TRAVAR CÂMERA (Esc)"
	_update_control_mode()


func _update_control_mode() -> void:
	if is_instance_valid(_control_mode_label):
		var mode := "Câmera destravada: mova o mouse" if _captured else "Câmera travada: clique e arraste para girar"
		_control_mode_label.text = "%s  ·  Tab alterna os modos  ·  Esc trava a câmera  ·  F observar  ·  1–8 gestos  ·  T avança hora  ·  Rodinha zoom  ·  R reinicia  ·  M HOME" % mode


func _update_telemetry() -> void:
	if is_instance_valid(_telemetry_label):
		var suffix := "  ·  " + _telemetry if not _telemetry.is_empty() else ""
		_telemetry_label.text = "%d FPS%s" % [Engine.get_frames_per_second(), suffix]
	if is_instance_valid(_render_label):
		var triangles := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var vram := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
		_render_label.text = "%s tri · %d draws · %d MB VRAM" % [_compact(triangles), int(draws), int(vram)]


func _compact(value: float) -> String:
	if value >= 1000000.0:
		return "%.2f M" % (value / 1000000.0)
	if value >= 1000.0:
		return "%d mil" % int(value / 1000.0)
	return str(int(value))


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
