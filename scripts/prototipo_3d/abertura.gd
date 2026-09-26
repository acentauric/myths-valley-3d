extends Node3D
## Interface 3D; contrato de áudio e narrativa idênticos aos da versão 2D.
const AudioToggleIcon = preload("res://scripts/prototipo_3d/audio_toggle_icon.gd")
const VISUAL_PREFERENCES := "user://preferencias_visuais.cfg"
const FLYOVER_SECONDS := 36.0
var camera := Camera3D.new()
var camera_target := Vector3(0, 1.5, 0)
var map_target := Vector3.ZERO
var map_marker_root: Control
var map_markers: Array[Dictionary] = []
var panel: PanelContainer
var content: VBoxContainer
var version_link: Button
var caption: Label
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

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	layer.add_child(panel)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	_create_quick_mute(layer)
	Audio.tocar_musica(Audio.obter_caminho_musica_menu())
	Audio.iniciar_ambiente_menu()
	_home()
	print("OPENING_READY: audio compartilhado e abertura 3D")

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
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(120.0, camera.size * 0.78)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(3800.0, camera.size * 1.28)
	if event is InputEventMouseMotion and (event.button_mask & (MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT)):
		var meters_per_pixel := camera.size / maxf(1.0, get_viewport().get_visible_rect().size.y)
		map_target.x -= event.relative.x * meters_per_pixel
		map_target.z -= event.relative.y * meters_per_pixel
		var bounds: Rect2 = $Cenario.get_map_bounds()
		map_target.x = clampf(map_target.x, bounds.position.x - 300.0, bounds.end.x + 300.0)
		map_target.z = clampf(map_target.z, bounds.position.y - 300.0, bounds.end.y + 300.0)

func _clear() -> void:
	history_open = false
	map_open = false
	if map_marker_root:
		map_marker_root.queue_free()
		map_marker_root = null
	map_markers.clear()
	_place_panel(false)
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

func _create_quick_mute(layer: CanvasLayer) -> void:
	var corner := PanelContainer.new()
	corner.anchor_left = 1.0
	corner.anchor_right = 1.0
	corner.offset_left = -88.0
	corner.offset_right = -36.0
	corner.offset_top = 32.0
	corner.offset_bottom = 84.0
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
	var quick_mute := Button.new()
	quick_mute.flat = true
	quick_mute.toggle_mode = true
	quick_mute.tooltip_text = "Desativar som" if Audio.som_ativo else "Ativar som"
	quick_mute.button_pressed = Audio.som_ativo
	quick_mute.custom_minimum_size = Vector2(40, 40)
	var audio_icon := AudioToggleIcon.new()
	audio_icon.position = Vector2(8, 8)
	audio_icon.size = Vector2(24, 24)
	audio_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	audio_icon.set_active(Audio.som_ativo)
	quick_mute.add_child(audio_icon)
	quick_mute.toggled.connect(func(active: bool):
		Audio.definir_som_ativo(active)
		audio_icon.set_active(active)
		quick_mute.tooltip_text = "Desativar som" if active else "Ativar som")
	corner.add_child(quick_mute)

func _create_version_link() -> void:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	version_link = Button.new()
	version_link.text = version_text
	version_link.tooltip_text = "Ver o histórico desta experiência 3D"
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
	label.custom_minimum_size.x = 375
	label.add_theme_font_size_override("font_size", size)
	content.add_child(label)
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
	content.add_child(button)
	return button

func _home() -> void:
	line_index = -1
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 55
	Audio.parar_narracao()
	_clear()
	_label("Myths’ Valley", 46)
	_label("Uma herança. Uma travessia.\nUm vale cheio de histórias.", 21)
	_button("JOGAR", _intro).grab_focus()
	_button("EXPLORAR", _start_game)
	_button("MAPA", _open_map)
	_button("AJUSTAR", _options)
	_button("CONHECER", _credits)
	_button("SAIR", _confirm_exit)
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
	_label("%s · 1 unidade = 1 m" % $Cenario.get_region_title(), 16)
	_label("N ↑ · roda: zoom · botão direito: mover", 14)
	_button("VOLTAR", _home).grab_focus()
	var bounds: Rect2 = $Cenario.get_map_bounds()
	var center := bounds.get_center()
	map_target = Vector3(center.x, 0, center.y)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var aspect := get_viewport().get_visible_rect().size.aspect()
	camera.size = maxf(bounds.size.y + 300.0, (bounds.size.x + 300.0) / maxf(aspect, 0.5))
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
	camera.size = minf(camera.size, 420.0)


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
	_place_panel(true)
	history_open = true
	var entry: Dictionary = history_entries[history_index]
	_label("Histórico 3D", 30)
	_label("%s · %s" % [entry.get("data", ""), entry.get("estado", "")], 16)
	_label(str(entry.get("titulo", "")), 22)
	for change in entry.get("mudancas", []):
		var change_label := _label("• " + str(change), 18)
		change_label.autowrap_mode = TextServer.AUTOWRAP_OFF
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
	_button("SAIR", func(): get_tree().quit())

func _options() -> void:
	_clear()
	content.add_theme_constant_override("separation", 7)
	_label("Ajustes", 30)
	_choice("Cenário do menu", ["Parado", "Sobrevoo"], 1 if flyover_active else 0, _set_flyover)
	_slider("Música", Audio.volume_musica, Audio.definir_volume_musica)
	_slider("Efeitos e passos", Audio.volume_efeitos, Audio.definir_volume_efeitos)
	_slider("Ambiente", Audio.volume_ambiente, Audio.definir_volume_ambiente)
	_choice("Trilha do menu", ["Introdução", "Menu I", "Menu II", "Recôncavo"], Audio.musica_menu_opcao - 1, func(i): Audio.definir_musica_menu(i + 1))
	_choice("Som dos botões", ["Original", "Madeira"], Audio.efeitos_menu_opcao - 1, func(i):
		Audio.definir_efeitos_menu(i + 1)
		Audio.testar_efeito_menu())
	_choice("Paisagem sonora", ["Silêncio", "Mar", "Aves", "Mar e aves"], Audio.ambiente_menu_opcao, Audio.definir_ambiente_menu)
	_button("VOLTAR", _home)

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
	content.add_child(slider)

func _choice(title: String, entries: Array, selected: int, callback: Callable) -> void:
	_label(title, 16)
	var option := OptionButton.new()
	for entry in entries:
		option.add_item(entry)
	option.select(selected)
	option.item_selected.connect(callback)
	content.add_child(option)

func _credits() -> void:
	_clear()
	_label("Por trás do vale", 30)
	_label("Myths’ Valley é uma criação da equipe da Alpha Centauri.", 20)
	_label("O vale nasceu do encontro entre paisagens, memórias e histórias brasileiras. Entre casas, caminhos e mata, cada lugar convida a uma descoberta.", 20)
	_label("Música, narração e efeitos acompanham a travessia e dão voz aos lugares e personagens.", 20)
	_label("Esta é uma primeira visita a esse mundo. Obrigado por caminhar conosco enquanto a jornada cresce.", 20)
	_button("VOLTAR", _home).grab_focus()

func _intro() -> void:
	_clear()
	chapter = _label("A travessia", 30)
	caption = _label("", 25)
	caption.custom_minimum_size.y = 300
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

func _start_game() -> void:
	if starting:
		return
	starting = true
	set_process(false)
	Audio.parar_narracao()
	get_tree().change_scene_to_file("res://scenes/prototipo_3d/vale.tscn")
