extends Node3D
## Interface 3D; contrato de áudio e narrativa idênticos aos da versão 2D.
const AudioToggleIcon = preload("res://scripts/prototipo_3d/audio_toggle_icon.gd")
const ClockIcon = preload("res://scripts/prototipo_3d/clock_icon.gd")
const VISUAL_PREFERENCES := "user://preferencias_visuais.cfg"
const FLYOVER_SECONDS := 36.0
const HISTORY_SIZE := Vector2(640, 600)
const OPTIONS_SIZE := Vector2(860, 600)
const OPTIONS_TABS := ["Geral", "Sons do vale", "Cenário e tempo"]
const HORAS_INICIAIS := [4.5, 7.0, 12.0, 15.0, 17.5, 20.5]
const ROTULOS_HORAS := ["Madrugada (4h30)", "Manhã (7h)", "Meio-dia", "Tarde (15h)", "Entardecer (17h30)", "Noite (20h30)"]
## Trocar o estilo visual reconstrói a cena do menu; ao voltar, reabre a página de ajustes.
static var _reabrir_ajustes := false
var camera := Camera3D.new()
var camera_target := Vector3(0, 1.5, 0)
var map_target := Vector3.ZERO
var map_marker_root: Control
var map_markers: Array[Dictionary] = []
var panel: PanelContainer
var content: VBoxContainer
## Onde _label/_button/_slider/_choice inserem controles; volta a `content` a cada _clear().
var ui_parent: Container
var version_link: Button
var caption: Label
## Quanto falta do trecho da travessia na tela (1 → 0), para o jogador saber quando passa.
var line_bar: ProgressBar
var line_total := 1.0
var chapter: Label
var lines: Array = []
var history_entries: Array = []
var version_text := ""
var history_index := 0
var history_open := false
var map_open := false
var line_index := -1
var elapsed := 0.0
var line_time := 0.0
var starting := false
var flyover_active := true
var clock_running := true

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# O menu sempre abre no começo do dia; o dia corre na velocidade de Passagem do tempo.
	Dia.pausado = false
	Dia.definir_hora(Dia.INICIO_DO_DIA)
	add_child(camera)
	camera.current = true
	camera.fov = 55
	camera.far = 7000.0
	camera.position = Vector3(105, 70, 115)
	camera.look_at(camera_target)
	_load_visual_preference()
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogos/pedro.json"))
	if data is Dictionary:
		lines = data.get("travessia", [])
	var history_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/historico_3d.json"))
	if history_data is Dictionary:
		history_entries = history_data.get("entradas", [])
		version_text = "v%s · Build #%d" % [str(history_data.get("versao_atual", "0.1.0-dev")), int(history_data.get("build_numero", 1))]
	var layer := CanvasLayer.new()
	add_child(layer)
	panel = PanelContainer.new()
	panel.position = Vector2(36, 32)
	panel.custom_minimum_size = Vector2(440, 640)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.09, 0.075, 0.94)
	style.border_color = Color("b49a60")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	panel.theme = _menu_theme()
	layer.add_child(panel)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	_create_quick_mute(layer)
	_create_clock(layer)
	Audio.tocar_musica(Audio.obter_caminho_musica_menu())
	Audio.iniciar_ambiente_menu()
	_home()
	if _reabrir_ajustes:
		_reabrir_ajustes = false
		_options(2)
	print("OPENING_READY: audio compartilhado e abertura 3D · estilo=%s" % Estilo.modo)

func _process(delta: float) -> void:
	elapsed += delta
	if map_open:
		camera.position = map_target + Vector3(0, 3000, 0)
		camera_target = map_target
		camera.look_at(map_target, Vector3(0, 0, -1))
		_position_map_markers()
		return
	var target := Vector3(0, 1.5, 0)
	var eye := Vector3(105, 70, 115)
	if line_index >= 0:
		var phase := mini(line_index / 3, 2)
		eye = [Vector3(-110, 65, 55), Vector3(-76, 35, 43), Vector3(75, 48, 75)][phase]
		target = [Vector3(-30, 0, 0), Vector3(-20, 1, -20), Vector3(10, 1, 10)][phase]
		line_time -= delta
		if line_bar:
			line_bar.value = clampf(line_time / line_total, 0.0, 1.0)
		if line_time <= 0:
			_next_line()
		camera.position = eye + Vector3(sin(elapsed * 0.08) * 1.2, 0, cos(elapsed * 0.08))
		camera_target = target
	else:
		if flyover_active:
			var progress := (1.0 - cos(elapsed * TAU / FLYOVER_SECONDS)) * 0.5
			eye = _flyover_eye(progress)
			target = Vector3(10, 1.5, 10).lerp(Vector3(-20, 1.5, -10), progress)
		var blend := clampf(delta * 1.4, 0.0, 1.0)
		camera.position = camera.position.lerp(eye, blend)
		camera_target = camera_target.lerp(target, blend)
	camera.look_at(camera_target)

func _flyover_eye(progress: float) -> Vector3:
	var start := Vector3(105, 70, 115)
	var control_a := Vector3(60, 95, 135)
	var control_b := Vector3(-70, 95, 100)
	var end := Vector3(-110, 65, 55)
	var first := start.lerp(control_a, progress)
	var second := control_a.lerp(control_b, progress)
	var third := control_b.lerp(end, progress)
	return first.lerp(second, progress).lerp(second.lerp(third, progress), progress)

func _load_visual_preference() -> void:
	var preferences := ConfigFile.new()
	if preferences.load(VISUAL_PREFERENCES) == OK:
		flyover_active = bool(preferences.get_value("menu", "sobrevoo", true))

func _set_flyover(option: int) -> void:
	flyover_active = option == 1
	var preferences := ConfigFile.new()
	preferences.load(VISUAL_PREFERENCES)
	preferences.set_value("menu", "sobrevoo", flyover_active)
	if preferences.save(VISUAL_PREFERENCES) != OK:
		push_warning("Não foi possível salvar a preferência de cenário do menu.")

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if line_index >= 0:
			if event.keycode == KEY_ESCAPE:
				_start_game()
			elif event.keycode in [KEY_ENTER, KEY_SPACE, KEY_E]:
				_next_line()
		elif history_open and event.keycode in [KEY_LEFT, KEY_RIGHT]:
			_change_history(1 if event.keycode == KEY_RIGHT else -1)
		elif event.keycode == KEY_ESCAPE:
			_home()


func _unhandled_input(event: InputEvent) -> void:
	if not map_open:
		return
	if event is InputEventMouseButton and event.pressed:
		var bounds_zoom: Rect2 = $Cenario.get_map_bounds()
		var zoom_max := maxf(bounds_zoom.size.x, bounds_zoom.size.y) * 2.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(30.0, camera.size * 0.78)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(zoom_max, camera.size * 1.28)
	if event is InputEventMouseMotion and (event.button_mask & (MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT)):
		var meters_per_pixel := camera.size / maxf(1.0, get_viewport().get_visible_rect().size.y)
		map_target.x -= event.relative.x * meters_per_pixel
		map_target.z -= event.relative.y * meters_per_pixel
		var bounds: Rect2 = $Cenario.get_map_bounds()
		var margin := maxf(bounds.size.x, bounds.size.y) * 0.16
		map_target.x = clampf(map_target.x, bounds.position.x - margin, bounds.end.x + margin)
		map_target.z = clampf(map_target.z, bounds.position.y - margin, bounds.end.y + margin)

func _clear() -> void:
	history_open = false
	map_open = false
	if map_marker_root:
		map_marker_root.queue_free()
		map_marker_root = null
	map_markers.clear()
	_place_panel(false)
	ui_parent = content
	content.add_theme_constant_override("separation", 12)
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func _place_panel(centered: bool) -> void:
	panel.custom_minimum_size = Vector2(440, 640)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER if centered else Control.PRESET_TOP_LEFT)
	panel.offset_left = -220 if centered else 36
	panel.offset_right = 220 if centered else 476
	panel.offset_top = -320 if centered else 32
	panel.offset_bottom = 320 if centered else 672

## Modal centrado de tamanho fixo (histórico, ajustes): não muda entre páginas.
func _place_modal(modal_size: Vector2) -> void:
	_place_panel(true)
	panel.custom_minimum_size = modal_size
	panel.offset_left = -modal_size.x * 0.5
	panel.offset_right = modal_size.x * 0.5
	panel.offset_top = -modal_size.y * 0.5
	panel.offset_bottom = modal_size.y * 0.5

## Botões do painel destacados do fundo verde-escuro: base mais clara com borda dourada,
## hover mais claro, foco com contorno dourado e aba/botão ativo em tom de ouro.
## Vale também para OptionButton, que herda os estilos de Button. A variação
## BotaoNegativo (SAIR) usa o terracota das telhas do vale para marcar ação destrutiva.
func _menu_theme() -> Theme:
	var theme := Theme.new()
	_button_styles(theme, "Button", {
		"normal": [Color(0.17, 0.22, 0.19), Color(0.71, 0.60, 0.38, 0.85), 2],
		"hover": [Color(0.24, 0.30, 0.25), Color("e2c47f"), 2],
		"pressed": [Color(0.33, 0.28, 0.16), Color("e2c47f"), 2],
		"hover_pressed": [Color(0.38, 0.32, 0.18), Color("e2c47f"), 2],
		"disabled": [Color(0.10, 0.13, 0.11, 0.7), Color(0.71, 0.60, 0.38, 0.25), 2],
		"focus": [Color(0, 0, 0, 0), Color("f5e3b3"), 3],
	})
	theme.set_color("font_color", "Button", Color("ece6d6"))
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_focus_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color("f5e3b3"))
	theme.set_color("font_hover_pressed_color", "Button", Color("f5e3b3"))
	theme.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.3))
	theme.set_type_variation("BotaoNegativo", "Button")
	_button_styles(theme, "BotaoNegativo", {
		"normal": [Color(0.25, 0.14, 0.11), Color(0.80, 0.45, 0.33, 0.85), 2],
		"hover": [Color(0.36, 0.18, 0.13), Color("e39475"), 2],
		"pressed": [Color(0.45, 0.21, 0.15), Color("e39475"), 2],
		"hover_pressed": [Color(0.50, 0.24, 0.17), Color("e39475"), 2],
		"disabled": [Color(0.14, 0.10, 0.09, 0.7), Color(0.80, 0.45, 0.33, 0.25), 2],
		"focus": [Color(0, 0, 0, 0), Color("f4c2ad"), 3],
	})
	theme.set_color("font_color", "BotaoNegativo", Color("f2d3c6"))
	theme.set_color("font_hover_color", "BotaoNegativo", Color.WHITE)
	theme.set_color("font_focus_color", "BotaoNegativo", Color.WHITE)
	theme.set_color("font_pressed_color", "BotaoNegativo", Color("fbe3d8"))
	theme.set_color("font_hover_pressed_color", "BotaoNegativo", Color("fbe3d8"))
	return theme


## Estados de um tipo de botão: estado → [fundo, borda, espessura da borda].
func _button_styles(theme: Theme, type_name: String, states: Dictionary) -> void:
	for state: String in states:
		var box := StyleBoxFlat.new()
		box.bg_color = states[state][0]
		box.border_color = states[state][1]
		box.set_border_width_all(states[state][2])
		box.set_corner_radius_all(8)
		box.content_margin_left = 12
		box.content_margin_right = 12
		box.content_margin_top = 6
		box.content_margin_bottom = 6
		box.draw_center = state != "focus"
		theme.set_stylebox(state, type_name, box)


## Botões redondos do canto superior direito (som, relógio), empilhados a partir de
## `top`. Cada um tem uma dica própria à esquerda, na identidade do painel (o tooltip
## nativo destoa). Devolve [botão, rótulo da dica].
func _corner_button(layer: CanvasLayer, top: float, icon: Control) -> Array:
	var corner := PanelContainer.new()
	corner.anchor_left = 1.0
	corner.anchor_right = 1.0
	corner.offset_left = -88.0
	corner.offset_right = -36.0
	corner.offset_top = top
	corner.offset_bottom = top + 52.0
	var corner_style := StyleBoxFlat.new()
	corner_style.bg_color = Color(0.055, 0.09, 0.075, 0.94)
	corner_style.border_color = Color("b49a60")
	corner_style.set_border_width_all(1)
	corner_style.set_corner_radius_all(12)
	corner_style.content_margin_left = 6
	corner_style.content_margin_right = 6
	corner_style.content_margin_top = 6
	corner_style.content_margin_bottom = 6
	corner.add_theme_stylebox_override("panel", corner_style)
	layer.add_child(corner)
	var hint := PanelContainer.new()
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.offset_left = -98.0
	hint.offset_right = -98.0
	hint.offset_top = top + 8.0
	hint.offset_bottom = top + 44.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.visible = false
	var hint_style := corner_style.duplicate() as StyleBoxFlat
	hint_style.set_corner_radius_all(8)
	hint_style.content_margin_left = 14
	hint_style.content_margin_right = 14
	hint_style.content_margin_top = 4
	hint_style.content_margin_bottom = 4
	hint.add_theme_stylebox_override("panel", hint_style)
	var hint_label := Label.new()
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_color", Color("ece6d6"))
	hint.add_child(hint_label)
	layer.add_child(hint)
	var button := Button.new()
	button.flat = true
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(40, 40)
	button.mouse_entered.connect(func(): hint.visible = true)
	button.mouse_exited.connect(func(): hint.visible = false)
	icon.position = Vector2(8, 8)
	icon.size = Vector2(24, 24)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	corner.add_child(button)
	return [button, hint_label]


func _create_quick_mute(layer: CanvasLayer) -> void:
	var audio_icon := AudioToggleIcon.new()
	audio_icon.set_active(Audio.som_ativo)
	var parts := _corner_button(layer, 32.0, audio_icon)
	var quick_mute: Button = parts[0]
	var hint_label: Label = parts[1]
	quick_mute.button_pressed = Audio.som_ativo
	hint_label.text = "Desativar som" if Audio.som_ativo else "Ativar som"
	quick_mute.toggled.connect(func(active: bool):
		Audio.definir_som_ativo(active)
		audio_icon.set_active(active)
		hint_label.text = "Desativar som" if active else "Ativar som")


## Relógio do menu: os ponteiros acompanham a hora do vale, que corre desde o começo
## do dia na velocidade de Passagem do tempo; o botão pausa e retoma o dia.
func _create_clock(layer: CanvasLayer) -> void:
	var clock_icon := ClockIcon.new()
	clock_icon.set_running(clock_running)
	var parts := _corner_button(layer, 96.0, clock_icon)
	var clock_button: Button = parts[0]
	var hint_label: Label = parts[1]
	clock_icon.position = Vector2(6, 6)
	clock_icon.size = Vector2(28, 28)
	clock_button.button_pressed = clock_running
	var refresh := func() -> void:
		hint_label.text = "%s · %s" % [Dia.texto_hora(), "Pausar o dia" if clock_running else "Retomar o dia"]
	refresh.call()
	Dia.hora_mudou.connect(func(_hora: float) -> void: refresh.call())
	clock_button.toggled.connect(func(active: bool) -> void:
		clock_running = active
		Dia.pausado = not active
		clock_icon.set_running(active)
		refresh.call())

func _create_version_link() -> void:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	version_link = Button.new()
	version_link.text = version_text
	version_link.tooltip_text = "Ver o histórico"
	version_link.flat = true
	version_link.add_theme_font_size_override("font_size", 13)
	version_link.add_theme_color_override("font_color", Color(0.72, 0.73, 0.66))
	version_link.add_theme_color_override("font_hover_color", Color.WHITE)
	version_link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	version_link.custom_minimum_size.y = 24
	content.add_child(version_link)
	version_link.pressed.connect(_open_history)

func _label(text: String, size: int = 18) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 375 if ui_parent == content else 0
	label.add_theme_font_size_override("font_size", size)
	ui_parent.add_child(label)
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.mouse_entered.connect(func(): Audio.efeito("ui_hover"))
	button.focus_entered.connect(func(): Audio.efeito("ui_hover"))
	button.pressed.connect(func():
		Audio.efeito("ui_confirmar")
		callback.call())
	ui_parent.add_child(button)
	return button

func _home() -> void:
	line_index = -1
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 55
	Audio.parar_narracao()
	_clear()
	_label("Myths’ Valley", 46)
	_label("Um vale cheio de histórias.", 21)
	_button("JOGAR", _intro).grab_focus()
	_button("EXPLORAR", _start_game)
	_button("MAPA", _open_map)
	_button("AJUSTAR", _options)
	_button("CONHECER", _credits)
	_button("SAIR", _confirm_exit).theme_type_variation = &"BotaoNegativo"
	if not history_entries.is_empty():
		_create_version_link()

func _open_map() -> void:
	_clear()
	map_open = true
	panel.custom_minimum_size = Vector2(440, 230)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 36
	panel.offset_right = 476
	panel.offset_top = 32
	panel.offset_bottom = 262
	_label("Mapa do vale", 24)
	_label("%s · 1 unidade = %s m" % [$Cenario.get_region_title(), _formatar_escala($Cenario.get_meters_per_unit())], 16)
	_label("N ↑ · roda: zoom · botão direito: mover", 14)
	_button("VOLTAR", _home).grab_focus()
	var bounds: Rect2 = $Cenario.get_map_bounds()
	var center := bounds.get_center()
	var margin := maxf(bounds.size.x, bounds.size.y) * 0.16
	map_target = Vector3(center.x, 0, center.y)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var aspect := get_viewport().get_visible_rect().size.aspect()
	camera.size = maxf(bounds.size.y + margin, (bounds.size.x + margin) / maxf(aspect, 0.5))
	camera.position = map_target + Vector3(0, 3000, 0)
	camera_target = map_target
	camera.look_at(map_target, Vector3(0, 0, -1))
	_create_map_markers()


func _create_map_markers() -> void:
	map_marker_root = Control.new()
	map_marker_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_marker_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.get_parent().add_child(map_marker_root)
	panel.get_parent().move_child(map_marker_root, 0)
	var name_totals: Dictionary = {}
	var name_seen: Dictionary = {}
	for landmark: Dictionary in $Cenario.landmarks:
		var name: String = landmark["name"]
		name_totals[name] = int(name_totals.get(name, 0)) + 1
	for landmark: Dictionary in $Cenario.landmarks:
		var marker_name: String = landmark["name"]
		var landmark_position: Vector3 = landmark["position"]
		if int(name_totals[marker_name]) > 1:
			name_seen[marker_name] = int(name_seen.get(marker_name, 0)) + 1
			marker_name = "%s %d" % [marker_name, name_seen[marker_name]]
		_add_map_marker(marker_name, landmark_position)
	for area: Dictionary in $Cenario.areas:
		if area["name"] != "Praça":
			_add_map_marker(area["name"], area["position"])
	_position_map_markers()


func _add_map_marker(label: String, position: Vector3) -> void:
	var marker := Button.new()
	marker.text = "● " + label
	marker.tooltip_text = "Centralizar em %s" % label
	marker.custom_minimum_size = Vector2(0, 26)
	marker.add_theme_font_size_override("font_size", 13)
	marker.pressed.connect(_focus_map_marker.bind(position))
	map_marker_root.add_child(marker)
	map_markers.append({"control": marker, "position": position})


func _focus_map_marker(position: Vector3) -> void:
	map_target = position
	camera.size = minf(camera.size, 420.0 / $Cenario.get_meters_per_unit())


func _position_map_markers() -> void:
	for entry: Dictionary in map_markers:
		var marker: Button = entry["control"]
		var projected := camera.unproject_position(entry["position"])
		marker.position = projected + Vector2(5, -13)
		marker.visible = projected.x > 0 and projected.y > 0 and projected.x < get_viewport().get_visible_rect().size.x and projected.y < get_viewport().get_visible_rect().size.y

func _open_history() -> void:
	if history_entries.is_empty():
		return
	history_index = 0
	_render_history()

func _change_history(step: int) -> void:
	history_index = clampi(history_index + step, 0, history_entries.size() - 1)
	_render_history()

func _render_history() -> void:
	_clear()
	# Todas as páginas têm o mesmo tamanho: as mudanças quebram linha e rolam dentro
	# da área do meio; paginação e VOLTAR ficam presos ao pé do painel.
	_place_modal(HISTORY_SIZE)
	history_open = true
	var entry: Dictionary = history_entries[history_index]
	_label("Histórico", 30)
	_label("%s · %s" % [entry.get("data", ""), entry.get("estado", "")], 16)
	_label(str(entry.get("titulo", "")), 22)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var changes := VBoxContainer.new()
	changes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	changes.add_theme_constant_override("separation", 10)
	scroll.add_child(changes)
	for change in entry.get("mudancas", []):
		var change_label := Label.new()
		change_label.text = "• " + str(change)
		change_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		change_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		change_label.add_theme_font_size_override("font_size", 17)
		changes.add_child(change_label)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 8)
	content.add_child(navigation)
	var previous := Button.new()
	previous.text = "‹"
	previous.tooltip_text = "Página anterior"
	previous.custom_minimum_size = Vector2(72, 40)
	previous.disabled = history_index == 0
	previous.pressed.connect(func(): _change_history(-1))
	navigation.add_child(previous)
	var position := Label.new()
	position.text = "%d / %d" % [history_index + 1, history_entries.size()]
	position.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	position.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	position.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_child(position)
	var next := Button.new()
	next.text = "›"
	next.tooltip_text = "Próxima página"
	next.custom_minimum_size = Vector2(72, 40)
	next.disabled = history_index == history_entries.size() - 1
	next.pressed.connect(func(): _change_history(1))
	navigation.add_child(next)
	_button("VOLTAR", _home)

func _confirm_exit() -> void:
	_clear()
	_label("Sair do jogo?", 30)
	_label("Deseja encerrar Myths’ Valley?", 18)
	_button("CANCELAR", _home).grab_focus()
	_button("SAIR", func(): get_tree().quit()).theme_type_variation = &"BotaoNegativo"

## Ajustes num modal centrado com abas (Geral, Sons do vale, Cenário e tempo). O modal
## tem tamanho fixo; cada aba divide o conteúdo em duas colunas e VOLTAR fica no pé.
func _options(tab: int = 0) -> void:
	_clear()
	_place_modal(OPTIONS_SIZE)
	content.add_theme_constant_override("separation", 10)
	_label("Ajustes", 30)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	content.add_child(tabs)
	var active_tab: Button
	for index in range(OPTIONS_TABS.size()):
		var tab_button := Button.new()
		tab_button.text = OPTIONS_TABS[index]
		tab_button.toggle_mode = true
		tab_button.button_pressed = index == tab
		tab_button.custom_minimum_size.y = 40
		tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if index == tab:
			tab_button.add_theme_color_override("font_color", Color("e2c47f"))
			tab_button.add_theme_color_override("font_pressed_color", Color("e2c47f"))
			tab_button.add_theme_color_override("font_focus_color", Color("e2c47f"))
			active_tab = tab_button
		tab_button.pressed.connect(func() -> void:
			Audio.efeito("ui_confirmar")
			_options(index))
		tabs.add_child(tab_button)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 32)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(columns)
	var left := _options_column(columns)
	var right := _options_column(columns)
	match tab:
		1: _options_sons(left, right)
		2: _options_mundo(left, right)
		_: _options_geral(left, right)
	ui_parent = content
	_button("VOLTAR", _home)
	active_tab.grab_focus()


func _options_column(columns: HBoxContainer) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	columns.add_child(column)
	return column


func _options_geral(left: VBoxContainer, right: VBoxContainer) -> void:
	ui_parent = left
	_label("Volume", 20)
	_slider("Música", Audio.volume_musica, Audio.definir_volume_musica)
	_slider("Narração", Audio.volume_narracao, Audio.definir_volume_narracao)
	_slider("Falas dos personagens", Audio.volume_vozes, Audio.definir_volume_vozes)
	_slider("Efeitos e passos", Audio.volume_efeitos, Audio.definir_volume_efeitos)
	_slider("Ambiente", Audio.volume_ambiente, Audio.definir_volume_ambiente)
	ui_parent = right
	_label("Menu", 20)
	_choice("Cenário do menu", ["Parado", "Sobrevoo"], 1 if flyover_active else 0, _set_flyover)
	_choice("Trilha do menu", ["Introdução", "Menu I", "Menu II", "Recôncavo"], Audio.musica_menu_opcao - 1, func(i): Audio.definir_musica_menu(i + 1))
	_choice("Som dos botões", ["Original", "Madeira"], Audio.efeitos_menu_opcao - 1, func(i):
		Audio.definir_efeitos_menu(i + 1)
		Audio.testar_efeito_menu())


## Camadas do ambiente: cada som do vale com volume próprio, sobre o volume geral de Ambiente.
func _options_sons(left: VBoxContainer, right: VBoxContainer) -> void:
	var camadas: Array = Audio.CAMADAS_AMBIENTE
	ui_parent = left
	_label("Sons do vale", 20)
	for indice in range(camadas.size()):
		if indice == 3:
			ui_parent = right
			_label(" ", 20)
		var camada: String = camadas[indice]
		_slider(String(Audio.ROTULOS_CAMADAS[camada]), float(Audio.volume_camadas[camada]), func(v: float) -> void: Audio.definir_volume_camada(camada, v))
	_choice("Paisagem sonora do menu", ["Silêncio", "Mar", "Aves", "Mar e aves"], Audio.ambiente_menu_opcao, Audio.definir_ambiente_menu)
	_label("Cada som tem volume próprio, aplicado sobre o volume geral de Ambiente (aba Geral).", 14)


## Mundo: estilo visual (linha mestra Tripo ou tudo procedural), passagem do tempo
## e hora em que o vale começa.
func _options_mundo(left: VBoxContainer, right: VBoxContainer) -> void:
	ui_parent = left
	_label("Cenário", 20)
	_choice("Estilo visual", ["Tripo (modelos gerados)", "Procedural (por código)"], 0 if Estilo.tripo() else 1, _set_estilo)
	_label("O vale inteiro é construído num só estilo — modelos do Tripo Studio ou tudo por código, até o personagem.", 14)
	ui_parent = right
	_label("Tempo", 20)
	_choice("Passagem do tempo", Dia.ROTULOS_VELOCIDADE, Dia.velocidade, Dia.definir_velocidade)
	var hora_indice := 1
	for indice in range(HORAS_INICIAIS.size()):
		if absf(float(HORAS_INICIAIS[indice]) - Dia.hora_inicial) < 0.75:
			hora_indice = indice
	_choice("Hora inicial", ROTULOS_HORAS, hora_indice, func(i: int) -> void: Dia.definir_hora_inicial(float(HORAS_INICIAIS[i])))
	_label("O menu abre sempre no começo do dia e o relógio do canto mostra o dia correndo nesta velocidade.", 14)


func _set_estilo(option: int) -> void:
	var novo: String = Estilo.TRIPO if option == 0 else Estilo.PROCEDURAL
	if novo == Estilo.modo:
		return
	Estilo.definir(novo)
	_reabrir_ajustes = true
	get_tree().reload_current_scene()

func _slider(title: String, value: float, callback: Callable) -> void:
	var label := _label("%s · %d%%" % [title, roundi(value * 100)], 16)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.01
	slider.value = value
	slider.custom_minimum_size.y = 22
	slider.value_changed.connect(func(v):
		callback.call(v)
		label.text = "%s · %d%%" % [title, roundi(v * 100)])
	ui_parent.add_child(slider)

func _choice(title: String, entries: Array, selected: int, callback: Callable) -> void:
	_label(title, 16)
	var option := OptionButton.new()
	for entry in entries:
		option.add_item(entry)
	option.select(selected)
	option.item_selected.connect(callback)
	ui_parent.add_child(option)

func _credits() -> void:
	_clear()
	_place_modal(HISTORY_SIZE)
	_label("Por trás do vale", 30)
	_label("O vale nasceu do encontro entre paisagens, memórias e histórias brasileiras. Entre casas, caminhos e mata, cada lugar convida a uma descoberta.", 20)
	_label("Música, narração e efeitos acompanham a travessia e dão voz aos lugares e personagens. Esta é uma primeira visita a esse mundo. Obrigado por caminhar conosco enquanto a jornada cresce.", 20)
	_label("Myths’ Valley é uma criação da equipe da Alpha Centauri, um spin-off do projeto Batalha de Mitos. Você pode saber mais acessando:", 20)
	var site := LinkButton.new()
	site.text = "batalhademitos.com.br"
	site.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	site.add_theme_font_size_override("font_size", 20)
	site.add_theme_color_override("font_color", Color("e2c47f"))
	site.add_theme_color_override("font_hover_color", Color("f5e3b3"))
	site.pressed.connect(func(): OS.shell_open("https://www.batalhademitos.com.br"))
	content.add_child(site)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	_button("VOLTAR", _home).grab_focus()

func _intro() -> void:
	_clear()
	chapter = _label("A travessia", 30)
	caption = _label("", 25)
	caption.custom_minimum_size.y = 300
	line_bar = ProgressBar.new()
	line_bar.show_percentage = false
	line_bar.max_value = 1.0
	line_bar.step = 0.0
	line_bar.custom_minimum_size.y = 6
	var bar_back := StyleBoxFlat.new()
	bar_back.bg_color = Color(1, 1, 1, 0.12)
	bar_back.set_corner_radius_all(3)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color("e2c47f")
	bar_fill.set_corner_radius_all(3)
	line_bar.add_theme_stylebox_override("background", bar_back)
	line_bar.add_theme_stylebox_override("fill", bar_fill)
	content.add_child(line_bar)
	_button("CONTINUAR", _next_line)
	_button("PULAR", _start_game)
	Audio.narrar_abertura()
	line_index = -1
	_next_line()

func _next_line() -> void:
	line_index += 1
	if line_index >= lines.size():
		_start_game()
		return
	caption.text = str(lines[line_index])
	chapter.text = ["A partida", "A travessia", "A chegada"][mini(line_index / 3, 2)]
	line_time = maxf(6.0, caption.text.length() * 0.065)
	line_total = line_time
	line_bar.value = 1.0

func _start_game() -> void:
	if starting:
		return
	starting = true
	set_process(false)
	Dia.pausado = false
	Dia.definir_hora(Dia.hora_inicial)
	Audio.parar_narracao()
	get_tree().change_scene_to_file("res://scenes/prototipo_3d/vale.tscn")


func _formatar_escala(meters_per_unit: float) -> String:
	if is_equal_approx(meters_per_unit, roundf(meters_per_unit)):
		return str(int(roundf(meters_per_unit)))
	return String.num(meters_per_unit, 2)
