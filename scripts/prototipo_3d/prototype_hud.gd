extends CanvasLayer
## Interface leve para o primeiro teste do personagem em 3D. No canto direito, a mesma
## coluna de botões redondos do menu (som e relógio na mesma posição), seguida de HOME,
## câmera, velocidade do tempo e estilo visual; as informações técnicas ficam na dica
## do estilo. No alto, ao centro, só a hora e o período do dia.

const BotaoCanto = preload("res://scripts/prototipo_3d/botao_canto.gd")
const AudioToggleIcon = preload("res://scripts/prototipo_3d/audio_toggle_icon.gd")
const ClockIcon = preload("res://scripts/prototipo_3d/clock_icon.gd")
const HudIcon = preload("res://scripts/prototipo_3d/hud_icon.gd")

signal reset_requested
signal quit_requested
signal menu_requested
signal camera_lock_requested(locked: bool)
signal house_info_close_requested

const INK := Color("e8e4d7")
const MUTED := Color("aebaae")
const GOLD := Color("d6ba78")
## Largura do painel do canto superior esquerdo (título, região e objetivo).
const HEADING_WIDTH := 360.0

var _model_status := "Preparando personagem…"
var _telemetry := ""
var _notice := ""
var _objective := "Explore o vale e observe o personagem de todos os ângulos."
var _captured := false
var _camera_locked := false
var _refresh_time := 0.0
var _root: Control
var _region_label: Label
var _style_hint: Label
var _speed_hint: Label
var _speed_icon	# hud_icon.gd
var _camera_icon	# hud_icon.gd
var _camera_hint: Label
var _notice_label: Label
var _notice_panel: Panel
var _objective_label: Label
var _heading: Panel
var _control_mode_label: Label
var _camera_lock_button: Button
var _clock_hint: Label
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

	_heading = _panel(Color(0.055, 0.085, 0.075, 0.82))
	_place(_heading, Vector2(18, 18), Vector2(HEADING_WIDTH, 132))
	var title := _label("MYTHS’ VALLEY", 28, INK)
	_place(title, Vector2(33, 25), Vector2(435, 39))
	_region_label = _label("REGIÃO INICIAL", 12, GOLD)
	_place(_region_label, Vector2(35, 67), Vector2(435, 23))
	_objective_label = _label(_objective, 15, MUTED)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_objective_label, Vector2(35, 101), Vector2(HEADING_WIDTH - 34, 42))

	_create_corner_buttons()

	_house_info_panel = _panel(Color(0.055, 0.085, 0.075, 0.92))
	_root.add_child(_house_info_panel)
	# Abaixo do bloco do canto superior esquerdo; _fit_heading acompanha a altura dele.
	_house_info_panel.position = Vector2(18, 162)
	_house_info_panel.size = Vector2(HEADING_WIDTH, 155)
	_house_info_panel.visible = false
	var house_heading := _label("INFORMAÇÕES DA CASA", 13, GOLD)
	_house_info_panel.add_child(house_heading)
	house_heading.position = Vector2(16, 10)
	house_heading.size = Vector2(270, 24)
	_house_info_label = _label("", 15, INK)
	_house_info_panel.add_child(_house_info_label)
	_house_info_label.position = Vector2(16, 39)
	_house_info_label.size = Vector2(HEADING_WIDTH - 32, 108)
	var close_house_info := Button.new()
	close_house_info.text = "×"
	close_house_info.tooltip_text = "Fechar informações da casa"
	close_house_info.position = Vector2(HEADING_WIDTH - 41, 7)
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
	var primary := _label("WASD mover  ·  Shift: corrida (parar desliga)  ·  Direito: andar  ·  Duplo direito: correr  ·  Esquerdo na casa: dados", 14, INK)
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

	# Relógio do vale: só a hora e o período do dia.
	var clock_panel := _panel(Color(0.055, 0.085, 0.075, 0.82))
	_root.add_child(clock_panel)
	clock_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	clock_panel.offset_left = -70
	clock_panel.offset_right = 70
	clock_panel.offset_top = 18
	clock_panel.offset_bottom = 72
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
	_update_telemetry()


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
		var font := _notice_label.get_theme_font("font")
		var half := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x * 0.5 + 24.0
		_notice_panel.offset_left = -half
		_notice_panel.offset_right = half


func show_house_info(value: String) -> void:
	_house_info_label.text = value
	_house_info_panel.visible = true


func clear_house_info() -> void:
	_house_info_panel.visible = false


func set_objective(value: String) -> void:
	_objective = value
	if is_instance_valid(_objective_label):
		_objective_label.text = value
		_fit_heading()


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
		_camera_icon.definir(value)
		_camera_hint.text = "Câmera travada · Tab destrava" if value else "Câmera livre · Esc trava"
	_update_control_mode()


func _update_control_mode() -> void:
	if is_instance_valid(_control_mode_label):
		var mode := "Câmera destravada: mova o mouse" if _captured else "Câmera travada: arraste o cenário"
		var gestures := "1–8 gestos · Espaço: pular"
		_control_mode_label.text = "%s  ·  Tab alterna os modos  ·  Esc trava a câmera  ·  F observar  ·  %s  ·  T avança hora  ·  Rodinha zoom  ·  R reinicia  ·  M HOME" % [mode, gestures]


func _update_telemetry() -> void:
	if not is_instance_valid(_style_hint):
		return
	var triangles := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var vram := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	var suffix := "  ·  " + _telemetry if not _telemetry.is_empty() else ""
	_style_hint.text = "%d FPS%s\n%s\n%s tri · %d draws · %d MB VRAM" % [Engine.get_frames_per_second(), suffix, _model_status, _compact(triangles), int(draws), int(vram)]
	_speed_icon.definir(false, Dia.velocidade)
	_speed_hint.text = "Tempo: %s · clique para mudar" % String(Dia.ROTULOS_VELOCIDADE[Dia.velocidade])
	_update_clock_hint()


func _update_clock_hint() -> void:
	if not is_instance_valid(_clock_hint):
		return
	if Dia.pausa_no_jogo:
		_clock_hint.text = "%s · %s" % [Dia.texto_hora(), "Retomar" if Dia.pausado else "Pausar"]
	else:
		_clock_hint.text = Dia.texto_hora()


## O painel do canto esquerdo cresce só o necessário para o objetivo caber.
func _fit_heading() -> void:
	if not is_instance_valid(_heading):
		return
	var lines := maxi(1, _objective_label.get_line_count())
	var height := 101.0 + lines * _objective_label.get_line_height() + 14.0
	_objective_label.size.y = lines * _objective_label.get_line_height()
	_heading.size.y = height - 18.0
	if is_instance_valid(_house_info_panel):
		_house_info_panel.position.y = height + 12.0


## Coluna de botões redondos: som e relógio na mesma posição do menu, depois HOME,
## câmera, velocidade do tempo e estilo visual (dica com as medições de desempenho).
func _create_corner_buttons() -> void:
	var top := 32.0
	var audio_icon := AudioToggleIcon.new()
	audio_icon.set_active(Audio.som_ativo)
	var audio: Array = BotaoCanto.criar(_root, top, audio_icon)
	var audio_hint: Label = audio[1]
	audio_hint.text = "Desativar" if Audio.som_ativo else "Ativar"
	_corner_setup(audio[0], func() -> void:
		Audio.definir_som_ativo(not Audio.som_ativo)
		audio_icon.set_active(Audio.som_ativo)
		audio_hint.text = "Desativar" if Audio.som_ativo else "Ativar")

	top += BotaoCanto.ESPACO
	var clock_icon := ClockIcon.new()
	clock_icon.set_running(not Dia.pausado)
	var clock: Array = BotaoCanto.criar(_root, top, clock_icon)
	clock_icon.position = Vector2(6, 6)
	clock_icon.size = Vector2(28, 28)
	_clock_hint = clock[1]
	_corner_setup(clock[0], func() -> void:
		if not Dia.pausa_no_jogo:
			return
		Dia.pausado = not Dia.pausado
		clock_icon.set_running(not Dia.pausado)
		_update_clock_hint())
	(clock[0] as Button).mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if Dia.pausa_no_jogo else Control.CURSOR_ARROW
	Dia.hora_mudou.connect(_update_clock_hint.unbind(1))

	top += BotaoCanto.ESPACO
	var home: Array = BotaoCanto.criar(_root, top, HudIcon.new().configurar("casa"))
	(home[1] as Label).text = "HOME · voltar ao menu (M)"
	_corner_setup(home[0], func() -> void: menu_requested.emit())

	top += BotaoCanto.ESPACO
	_camera_icon = HudIcon.new().configurar("camera")
	var camera: Array = BotaoCanto.criar(_root, top, _camera_icon)
	_camera_lock_button = camera[0]
	_camera_hint = camera[1]
	_camera_lock_button.toggle_mode = true
	_camera_lock_button.focus_mode = Control.FOCUS_NONE
	_camera_lock_button.toggled.connect(func(locked: bool): camera_lock_requested.emit(locked))

	top += BotaoCanto.ESPACO
	_speed_icon = HudIcon.new().configurar("velocidade")
	var speed: Array = BotaoCanto.criar(_root, top, _speed_icon)
	_speed_hint = speed[1]
	_corner_setup(speed[0], func() -> void:
		Dia.definir_velocidade((Dia.velocidade + 1) % Dia.VELOCIDADES.size())
		_update_telemetry())

	top += BotaoCanto.ESPACO
	var style_icon = HudIcon.new().configurar("estilo")
	style_icon.definir(Estilo.tripo())
	var style: Array = BotaoCanto.criar(_root, top, style_icon)
	_style_hint = style[1]
	_style_hint.add_theme_font_size_override("font_size", 13)
	(style[0] as Button).focus_mode = Control.FOCUS_NONE
	set_camera_locked(_camera_locked)


## Botões do HUD não roubam o foco do teclado (WASD, Espaço, Tab seguem com o jogador).
func _corner_setup(button: Button, action: Callable) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)


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
