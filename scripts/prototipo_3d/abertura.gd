extends Node3D
## Interface 3D; contrato de áudio e narrativa idênticos aos da versão 2D.
const AudioToggleIcon = preload("res://scripts/prototipo_3d/audio_toggle_icon.gd")
const ClockIcon = preload("res://scripts/prototipo_3d/clock_icon.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const BotaoCanto = preload("res://scripts/prototipo_3d/botao_canto.gd")
const AjudaMenu = preload("res://scripts/prototipo_3d/ajuda_menu.gd")
const HudIcon = preload("res://scripts/prototipo_3d/hud_icon.gd")
const VISUAL_PREFERENCES := "user://preferencias_visuais.cfg"
const FLYOVER_SECONDS := 36.0
const HISTORY_SIZE := Vector2(640, 600)
## Altura de cada campo de AJUSTAR e do controle dentro dele (seleção ou volume).
const FIELD_HEIGHT := 66.0
## Altura comum do cabeçalho dos modais (título + botão do canto).
const MODAL_HEADER_HEIGHT := 44.0
## Equipe exibida em CONHECER.
const COLLABORATORS := ["Ramon Santos", "Renato Leal", "Matheus Ché", "Pedro Almeida"]
const FIELD_CONTROL_HEIGHT := 36.0
## Fonte do menu (AJUSTAR → Cenário): padrão do Godot ou as duas fontes do 2D.
const MENU_FONTS := ["", "res://assets/fonts/Almendra-Bold.ttf", "res://assets/fonts/miva.ttf"]
const MENU_FONT_LABELS := ["Padrão", "Almendra", "Miva"]
const OPTIONS_SIZE := Vector2(860, 620)
const OPTIONS_TABS := ["Geral", "Sons do vale", "Cenário"]
const HORAS_INICIAIS := [4.5, 7.0, 12.0, 15.0, 17.5, 20.5]
const ROTULOS_HORAS := ["Madrugada (4h30)", "Manhã (7h)", "Meio-dia", "Tarde (15h)", "Entardecer (17h30)", "Noite (20h30)"]
## Trocar o estilo visual reconstrói a cena do menu; ao voltar, reabre a página de ajustes.
static var _reabrir_ajustes := false
var camera := Camera3D.new()
var camera_target := Vector3(0, 1.5, 0)
var map_target := Vector3.ZERO
var map_full_size := 0.0
var map_marker_root: Control
var map_markers: Array[Dictionary] = []
var panel: PanelContainer
var content: VBoxContainer
## Onde _label/_button/_slider/_choice inserem controles; volta a `content` a cada _clear().
var ui_parent: Container
## Modal de ajuda aberto pelo botão "?" de um campo de AJUSTAR (null quando fechado).
var help_modal: Control
var version_link: Button
var caption: Label
## Quanto falta do trecho da travessia na tela (1 → 0), para o jogador saber quando passa.
var line_bar: ProgressBar
var line_total := 1.0
var chapter: Label
var lines: Array = []
var dialog_data: Dictionary = {}
var history_entries: Array = []
var version_text := ""
var history_index := 0
var history_open := false
## Setas de página do histórico, para as teclas ← → animarem o botão correspondente.
var history_buttons: Array[Button] = []
var map_open := false
var line_index := -1
var elapsed := 0.0
var line_time := 0.0
var starting := false
var flyover_active := true
var menu_font_option := 0
var clock_running := true
var clock_hint: Label

func _ready() -> void:
	IdiomaMenu.aplicar_menu()
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
		dialog_data = data
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
		menu_font_option = clampi(int(preferences.get_value("menu", "fonte", 0)), 0, MENU_FONTS.size() - 1)

func _set_menu_font(option: int) -> void:
	menu_font_option = option
	var preferences := ConfigFile.new()
	preferences.load(VISUAL_PREFERENCES)
	preferences.set_value("menu", "fonte", option)
	if preferences.save(VISUAL_PREFERENCES) != OK:
		push_warning("Não foi possível salvar a fonte do menu.")
	panel.theme = _menu_theme()
	_options(2)


func _set_flyover(option: int) -> void:
	flyover_active = option == 1
	var preferences := ConfigFile.new()
	preferences.load(VISUAL_PREFERENCES)
	preferences.set_value("menu", "sobrevoo", flyover_active)
	if preferences.save(VISUAL_PREFERENCES) != OK:
		push_warning("Não foi possível salvar a preferência de cenário do menu.")

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if help_modal and event.keycode == KEY_ESCAPE:
			_close_help()
		elif line_index >= 0:
			if event.keycode == KEY_ESCAPE:
				_start_game()
			elif event.keycode in [KEY_ENTER, KEY_SPACE, KEY_E]:
				_next_line()
		elif history_open and event.keycode in [KEY_LEFT, KEY_RIGHT]:
			_press_history_arrow(1 if event.keycode == KEY_RIGHT else 0)
		elif event.keycode == KEY_ESCAPE:
			_home()


func _unhandled_input(event: InputEvent) -> void:
	if not map_open:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(30.0, camera.size * 0.78)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(map_full_size, camera.size * 1.28)
		_limit_map_target()
	if event is InputEventMouseMotion and (event.button_mask & (MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT)):
		var meters_per_pixel := camera.size / maxf(1.0, get_viewport().get_visible_rect().size.y)
		map_target.x -= event.relative.x * meters_per_pixel
		map_target.z -= event.relative.y * meters_per_pixel
		_limit_map_target()


func _limit_map_target() -> void:
	var frame: Rect2 = $Cenario.get_map_frame()
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var half_width := camera.size * aspect * 0.5
	var half_height := camera.size * 0.5
	var min_x := frame.position.x + half_width
	var max_x := frame.end.x - half_width
	var min_z := frame.position.y + half_height
	var max_z := frame.end.y - half_height
	map_target.x = clampf(map_target.x, min_x, max_x) if min_x <= max_x else frame.get_center().x
	map_target.z = clampf(map_target.z, min_z, max_z) if min_z <= max_z else frame.get_center().y

func _clear() -> void:
	_close_help()
	history_open = false
	map_open = false
	camera.environment = null
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
	if menu_font_option > 0:
		theme.default_font = load(MENU_FONTS[menu_font_option]) as Font
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
	# Botão de ícone dos cabeçalhos (casa, ×): borda fina, foco discreto.
	theme.set_type_variation("BotaoIcone", "Button")
	_button_styles(theme, "BotaoIcone", {
		"normal": [Color(0.17, 0.22, 0.19), Color(0.71, 0.60, 0.38, 0.6), 1],
		"hover": [Color(0.24, 0.30, 0.25), Color("e2c47f"), 1],
		"pressed": [Color(0.33, 0.28, 0.16), Color("e2c47f"), 1],
		"hover_pressed": [Color(0.38, 0.32, 0.18), Color("e2c47f"), 1],
		"focus": [Color(0, 0, 0, 0), Color(0.89, 0.77, 0.50, 0.9), 1],
	})
	theme.set_type_variation("BotaoAjuda", "Button")
	_button_styles(theme, "BotaoAjuda", {
		"normal": [Color(0.17, 0.22, 0.19), Color(0.71, 0.60, 0.38, 0.85), 1],
		"hover": [Color(0.33, 0.28, 0.16), Color("e2c47f"), 1],
		"pressed": [Color(0.38, 0.32, 0.18), Color("e2c47f"), 1],
		"focus": [Color(0, 0, 0, 0), Color("f5e3b3"), 2],
	})
	for state in ["normal", "hover", "pressed", "focus"]:
		var round_box := theme.get_stylebox(state, "BotaoAjuda") as StyleBoxFlat
		round_box.set_corner_radius_all(12)
		round_box.content_margin_left = 0
		round_box.content_margin_right = 0
		round_box.content_margin_top = 0
		round_box.content_margin_bottom = 0
	theme.set_color("font_color", "BotaoAjuda", Color("e2c47f"))
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


## Botões redondos do canto superior direito (som, relógio): ver botao_canto.gd.
## Devolve [botão, rótulo da dica].
func _corner_button(layer: CanvasLayer, top: float, icon: Control) -> Array:
	var parts := BotaoCanto.criar(layer, top, icon)
	(parts[0] as Button).toggle_mode = true
	return parts


func _create_quick_mute(layer: CanvasLayer) -> void:
	var audio_icon := AudioToggleIcon.new()
	audio_icon.set_active(Audio.som_ativo)
	var parts := _corner_button(layer, 32.0, audio_icon)
	var quick_mute: Button = parts[0]
	var hint_label: Label = parts[1]
	quick_mute.button_pressed = Audio.som_ativo
	hint_label.text = "Desativar" if Audio.som_ativo else "Ativar"
	quick_mute.toggled.connect(func(active: bool):
		Audio.definir_som_ativo(active)
		audio_icon.set_active(active)
		hint_label.text = "Desativar" if active else "Ativar")


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
	clock_hint = hint_label
	_refresh_clock_hint()
	# Método (não lambda): o Godot desconecta sozinho quando a cena do menu é liberada.
	Dia.hora_mudou.connect(_refresh_clock_hint)
	clock_button.toggled.connect(func(active: bool) -> void:
		clock_running = active
		Dia.pausado = not active
		clock_icon.set_running(active)
		_refresh_clock_hint())


func _refresh_clock_hint(_hora: float = 0.0) -> void:
	clock_hint.text = "%s · %s" % [Dia.texto_hora(), tr("Pausar") if clock_running else tr("Retomar")]

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
	_label("%s · %s" % [$Cenario.get_region_title(), tr("1 unidade = %s m") % _formatar_escala($Cenario.get_meters_per_unit())], 16)
	_label("N ↑ · roda: zoom · botão direito: mover", 14)
	_button("VOLTAR", _home).grab_focus()
	var frame: Rect2 = $Cenario.get_map_frame()
	var center := frame.get_center()
	map_target = Vector3(center.x, 0, center.y)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# A câmera fica a 3000 unidades do chão. O nevoeiro do cenário apaga
	# quase toda a imagem nessa distância; só esta vista precisa vê-lo sem névoa.
	var scene_environment: Environment = get_world_3d().environment
	if scene_environment != null:
		camera.environment = scene_environment.duplicate() as Environment
		camera.environment.fog_enabled = false
	var aspect := get_viewport().get_visible_rect().size.aspect()
	# Usa o maior recorte 16:9 dentro do quadro do KML; a roda não afasta além dele.
	var size_by_width := frame.size.x / maxf(aspect, 0.5)
	if $Cenario.has_map_frame():
		map_full_size = minf(frame.size.y, size_by_width)
	else:
		map_full_size = maxf(frame.size.y, size_by_width)
	map_full_size = maxf(30.0, map_full_size)
	camera.size = map_full_size
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
		var base_name: String = landmark["name"]
		var marker_name := tr(base_name)
		var landmark_position: Vector3 = landmark["position"]
		if int(name_totals[base_name]) > 1:
			name_seen[base_name] = int(name_seen.get(base_name, 0)) + 1
			marker_name = "%s %d" % [marker_name, name_seen[base_name]]
		_add_map_marker(marker_name, landmark_position)
	for area: Dictionary in $Cenario.areas:
		if area["name"] != "Praça":
			_add_map_marker(tr(area["name"]), area["position"])
	_position_map_markers()


func _add_map_marker(label: String, position: Vector3) -> void:
	var marker := Button.new()
	marker.text = "● " + label
	marker.tooltip_text = tr("Centralizar em %s") % label
	marker.custom_minimum_size = Vector2(0, 26)
	marker.add_theme_font_size_override("font_size", 13)
	marker.pressed.connect(_focus_map_marker.bind(position))
	map_marker_root.add_child(marker)
	map_markers.append({"control": marker, "position": position})


func _focus_map_marker(position: Vector3) -> void:
	map_target = position
	camera.size = minf(camera.size, 420.0 / $Cenario.get_meters_per_unit())
	_limit_map_target()


func _position_map_markers() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	for entry: Dictionary in map_markers:
		var marker: Button = entry["control"]
		var projected := camera.unproject_position(entry["position"])
		var marker_size := marker.get_combined_minimum_size()
		marker.position = (projected + Vector2(5, -13)).clamp(Vector2.ZERO, (viewport_size - marker_size).max(Vector2.ZERO))
		marker.visible = projected.x > 0 and projected.y > 0 and projected.x < viewport_size.x and projected.y < viewport_size.y

func _open_history() -> void:
	if history_entries.is_empty():
		return
	history_index = 0
	_render_history()

## Tecla ← / →: o botão da seta aparece pressionado por um instante (como no clique)
## e só então a página muda.
func _press_history_arrow(index: int) -> void:
	if index >= history_buttons.size():
		return
	var button := history_buttons[index]
	if not is_instance_valid(button) or button.disabled or button.has_meta("pressionando"):
		return
	button.set_meta("pressionando", true)
	button.add_theme_stylebox_override("normal", button.get_theme_stylebox("pressed"))
	button.add_theme_stylebox_override("hover", button.get_theme_stylebox("pressed"))
	button.add_theme_color_override("font_color", button.get_theme_color("font_pressed_color"))
	Audio.efeito("ui_hover")
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(button) and history_open:
		_change_history(1 if index == 1 else -1)


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
	# Sem foco em botão: as teclas ← → ficam livres para trocar de página.
	_modal_header("Histórico", _home, "O que mudou no vale a cada versão.")
	_label("%s · %s" % [entry.get("data", ""), IdiomaMenu.campo(entry, "estado")], 16)
	_label(str(IdiomaMenu.campo(entry, "titulo")), 22)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var changes := VBoxContainer.new()
	changes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	changes.add_theme_constant_override("separation", 10)
	scroll.add_child(changes)
	for change in IdiomaMenu.campo(entry, "mudancas", []):
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
	history_buttons = [previous]
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
	history_buttons.append(next)

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
	_modal_header("Ajustes", _home, "Idioma, tempo, sons e aparência do vale.")
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
	active_tab.grab_focus()


func _options_column(columns: HBoxContainer) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	columns.add_child(column)
	return column


## Geral: à esquerda o que vale para todo o jogo (idioma e relógio do vale), à direita
## os volumes principais.
func _options_geral(left: VBoxContainer, right: VBoxContainer) -> void:
	ui_parent = left
	_section("Jogo")
	_choice("Idioma", IdiomaMenu.ROTULOS, IdiomaMenu.indice(), func(i: int) -> void:
		IdiomaMenu.definir(i)
		_options(0))
	_choice("Passagem do tempo", Dia.ROTULOS_VELOCIDADE, Dia.velocidade, Dia.definir_velocidade)
	var hora_indice := 1
	for indice in range(HORAS_INICIAIS.size()):
		if absf(float(HORAS_INICIAIS[indice]) - Dia.hora_inicial) < 0.75:
			hora_indice = indice
	_choice("Hora inicial", ROTULOS_HORAS, hora_indice, func(i: int) -> void: Dia.definir_hora_inicial(float(HORAS_INICIAIS[i])))
	_choice("Pausar o relógio no jogo", ["Permitido", "Bloqueado"], 0 if Dia.pausa_no_jogo else 1, func(i: int) -> void: Dia.definir_pausa_no_jogo(i == 0))
	ui_parent = right
	_section("Volume")
	_slider("Música", Audio.volume_musica, Audio.definir_volume_musica)
	_slider("Narração", Audio.volume_narracao, Audio.definir_volume_narracao)
	_slider("Falas dos personagens", Audio.volume_vozes, Audio.definir_volume_vozes)
	_slider("Efeitos e passos", Audio.volume_efeitos, Audio.definir_volume_efeitos)
	_slider("Ambiente", Audio.volume_ambiente, Audio.definir_volume_ambiente)


## Sons: à esquerda as escolhas sonoras do menu, à direita o volume de cada camada do
## ambiente (aplicado sobre o volume geral de Ambiente).
func _options_sons(left: VBoxContainer, right: VBoxContainer) -> void:
	ui_parent = left
	_section("Menu")
	_choice("Trilha do menu", ["Introdução", "Menu I", "Menu II", "Recôncavo"], Audio.musica_menu_opcao - 1, func(i): Audio.definir_musica_menu(i + 1))
	_choice("Som dos botões", ["Original", "Madeira"], Audio.efeitos_menu_opcao - 1, func(i):
		Audio.definir_efeitos_menu(i + 1)
		Audio.testar_efeito_menu())
	_choice("Paisagem sonora do menu", ["Silêncio", "Mar", "Aves", "Mar e aves"], Audio.ambiente_menu_opcao, Audio.definir_ambiente_menu)
	ui_parent = right
	_section("Sons do vale")
	for camada: String in Audio.CAMADAS_AMBIENTE:
		_slider(String(Audio.ROTULOS_CAMADAS[camada]), float(Audio.volume_camadas[camada]), func(v: float) -> void: Audio.definir_volume_camada(camada, v))


## Cenário: estilo visual do vale (Tripo ou procedural) e o fundo do menu.
func _options_mundo(left: VBoxContainer, right: VBoxContainer) -> void:
	ui_parent = left
	_section("Vale")
	_choice("Estilo visual", ["Tripo (modelos gerados)", "Procedural (por código)"], 0 if Estilo.tripo() else 1, _set_estilo)
	ui_parent = right
	_section("Menu")
	_choice("Cenário do menu", ["Parado", "Sobrevoo"], 1 if flyover_active else 0, _set_flyover)
	_choice("Fonte do menu", MENU_FONT_LABELS, menu_font_option, _set_menu_font)


func _set_estilo(option: int) -> void:
	var novo: String = Estilo.TRIPO if option == 0 else Estilo.PROCEDURAL
	if novo == Estilo.modo:
		return
	Estilo.definir(novo)
	_reabrir_ajustes = true
	get_tree().reload_current_scene()

func _slider(title: String, value: float, callback: Callable) -> void:
	var previous := _begin_field()
	var label := _field_label(title, "%s · %d%%" % [tr(title), roundi(value * 100)])
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 1
	slider.step = 0.01
	slider.value = value
	# Mesma altura do OptionButton: a trilha fica centrada e as linhas das colunas batem.
	slider.custom_minimum_size.y = FIELD_CONTROL_HEIGHT
	slider.value_changed.connect(func(v):
		callback.call(v)
		label.text = "%s · %d%%" % [tr(title), roundi(v * 100)])
	ui_parent.add_child(slider)
	ui_parent = previous

func _choice(title: String, entries: Array, selected: int, callback: Callable) -> void:
	var previous := _begin_field()
	_field_label(title, title)
	var option := OptionButton.new()
	option.custom_minimum_size.y = FIELD_CONTROL_HEIGHT
	for entry in entries:
		option.add_item(entry)
	option.select(selected)
	option.item_selected.connect(callback)
	ui_parent.add_child(option)
	ui_parent = previous


## Campo de AJUSTAR (rótulo + controle) num bloco de altura fixa: seleções e volumes
## ocupam a mesma altura, então os rótulos das duas colunas ficam na mesma linha.
func _begin_field() -> Container:
	var previous := ui_parent
	var field := VBoxContainer.new()
	field.add_theme_constant_override("separation", 4)
	field.custom_minimum_size.y = FIELD_HEIGHT
	previous.add_child(field)
	ui_parent = field
	return previous


## Título de seção de uma coluna de AJUSTAR, com respiro antes dos campos.
func _section(title: String) -> void:
	var label := _label(title, 20)
	label.add_theme_color_override("font_color", Color("e2c47f"))
	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	ui_parent.add_child(gap)

## Rótulo de um campo de AJUSTAR com o botão "?" à esquerda, que abre a ajuda do campo.
func _field_label(title: String, text: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	ui_parent.add_child(row)
	if AjudaMenu.tem(title):
		var help := Button.new()
		help.text = "?"
		help.theme_type_variation = &"BotaoAjuda"
		help.custom_minimum_size = Vector2(24, 24)
		help.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		help.add_theme_font_size_override("font_size", 13)
		help.tooltip_text = ""
		help.pressed.connect(func() -> void:
			Audio.efeito("ui_confirmar")
			_open_help(title))
		row.add_child(help)
	var previous := ui_parent
	ui_parent = row
	var label := _label(text, 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui_parent = previous
	return label


## Modal de ajuda sobre o painel: escurece o fundo, mostra título e texto do campo;
## fecha com FECHAR, Esc ou clique fora.
func _open_help(title: String) -> void:
	_close_help()
	var layer := panel.get_parent()
	help_modal = Control.new()
	help_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	help_modal.theme = panel.theme
	layer.add_child(help_modal)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_close_help())
	help_modal.add_child(shade)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", panel.get_theme_stylebox("panel"))
	box.custom_minimum_size = Vector2(520, 0)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	help_modal.add_child(box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	box.add_child(column)
	var previous := ui_parent
	ui_parent = column
	var close := _modal_header(title, func() -> void:
		Audio.efeito("ui_voltar")
		_close_help(), "Como funciona este ajuste.", "fechar")
	ui_parent = previous
	var body := Label.new()
	body.text = AjudaMenu.texto(title, IdiomaMenu.indice())
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 464
	body.add_theme_font_size_override("font_size", 17)
	column.add_child(body)
	close.grab_focus()


## Cabeçalho padrão dos modais: título e subtítulo descritivo à esquerda, botão com ícone no canto direito
## (casa volta ao menu inicial; × fecha a janela) e um divisor dourado antes do corpo.
## Devolve o botão do canto, para receber o foco.
func _modal_header(title: String, action: Callable, subtitle: String = "", icon: String = "casa") -> Button:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = MODAL_HEADER_HEIGHT
	ui_parent.add_child(row)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_theme_constant_override("separation", 0)
	row.add_child(titles)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 28)
	titles.add_child(heading)
	if not subtitle.is_empty():
		var description := Label.new()
		description.text = subtitle
		description.add_theme_font_size_override("font_size", 14)
		description.add_theme_color_override("font_color", Color("c9b98f"))
		titles.add_child(description)
	var button := Button.new()
	button.custom_minimum_size = Vector2(MODAL_HEADER_HEIGHT, MODAL_HEADER_HEIGHT)
	button.theme_type_variation = &"BotaoIcone"
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var glyph = HudIcon.new().configurar(icon)
	glyph.position = Vector2(10, 10)
	glyph.size = Vector2(24, 24)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(glyph)
	button.mouse_entered.connect(func(): Audio.efeito("ui_hover"))
	button.pressed.connect(func() -> void:
		Audio.efeito("ui_confirmar")
		action.call())
	row.add_child(button)
	var divider := ColorRect.new()
	divider.color = Color(0.71, 0.60, 0.38, 0.55)
	divider.custom_minimum_size.y = 1
	ui_parent.add_child(divider)
	return button


func _close_help() -> void:
	if help_modal:
		help_modal.queue_free()
		help_modal = null


func _credits() -> void:
	_clear()
	_place_modal(HISTORY_SIZE)
	var home := _modal_header("Por trás do vale", _home, "Quem faz o vale e de onde ele vem.")
	_label("O vale nasceu do encontro entre paisagens, memórias e histórias brasileiras. Entre casas, caminhos e mata, cada lugar convida a uma descoberta.", 20)
	_label("Música, narração e efeitos acompanham a travessia e dão voz aos lugares e personagens. Esta é uma primeira visita a esse mundo. Obrigado por caminhar conosco enquanto a jornada cresce.", 20)
	_label("Myths’ Valley é uma criação da equipe da Alpha Centauri, um spin-off do projeto Batalha de Mitos. Você pode saber mais acessando:", 20)
	# Ícone de link externo antes do endereço: avisa que o clique abre o navegador.
	var open_site := func() -> void: OS.shell_open("https://www.batalhademitos.com.br")
	var link_row := HBoxContainer.new()
	link_row.add_theme_constant_override("separation", 8)
	content.add_child(link_row)
	var external := Button.new()
	external.flat = true
	external.focus_mode = Control.FOCUS_NONE
	external.custom_minimum_size = Vector2(28, 28)
	external.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	external.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var external_icon = HudIcon.new().configurar("externo")
	external_icon.position = Vector2(2, 2)
	external_icon.size = Vector2(24, 24)
	external_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	external.add_child(external_icon)
	external.pressed.connect(open_site)
	link_row.add_child(external)
	var site := LinkButton.new()
	site.text = "batalhademitos.com.br"
	site.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	site.add_theme_font_size_override("font_size", 20)
	site.add_theme_color_override("font_color", Color("e2c47f"))
	site.add_theme_color_override("font_hover_color", Color("f5e3b3"))
	site.pressed.connect(open_site)
	link_row.add_child(site)
	for hoverable: Control in [external, site]:
		hoverable.mouse_entered.connect(func() -> void: external_icon.definir(true))
		hoverable.mouse_exited.connect(func() -> void: external_icon.definir(false))
	var team_gap := Control.new()
	team_gap.custom_minimum_size.y = 6
	content.add_child(team_gap)
	var team_title := _label("Colaboradores", 16)
	team_title.add_theme_color_override("font_color", Color("e2c47f"))
	_label(" · ".join(COLLABORATORS), 18)
	home.grab_focus()

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
	lines = IdiomaMenu.campo(dialog_data, "travessia", [])
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
	IdiomaMenu.restaurar_jogo()
	Audio.parar_narracao()
	get_tree().change_scene_to_file("res://scenes/prototipo_3d/vale.tscn")


func _formatar_escala(meters_per_unit: float) -> String:
	if is_equal_approx(meters_per_unit, roundf(meters_per_unit)):
		return str(int(roundf(meters_per_unit)))
	return String.num(meters_per_unit, 2)
