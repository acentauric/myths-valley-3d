extends Node3D
## Interface 3D; contrato de áudio e narrativa idênticos aos da versão 2D.
const AudioToggleIcon = preload("res://scripts/prototipo_3d/audio_toggle_icon.gd")
const ClockIcon = preload("res://scripts/prototipo_3d/clock_icon.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const BotaoCanto = preload("res://scripts/prototipo_3d/botao_canto.gd")
const HudIcon = preload("res://scripts/prototipo_3d/hud_icon.gd")
const TemaMenu = preload("res://scripts/prototipo_3d/tema_menu.gd")
const PainelAjustes = preload("res://scripts/prototipo_3d/painel_ajustes.gd")
const TelaCarregamento = preload("res://scripts/prototipo_3d/tela_carregamento.gd")
const VISUAL_PREFERENCES := "user://preferencias_visuais.cfg"
const FLYOVER_SECONDS := 36.0
const HISTORY_SIZE := Vector2(640, 600)
const GAME_SCENE := "res://scenes/prototipo_3d/vale.tscn"
## Equipe exibida em SOBRE.
const CREDITS_HIGHLIGHTS := [
	"histórias brasileiras", "Brazilian", "historias brasileñas",
	"primeira visita", "first visit", "primera visita",
	"Batalha de Mitos",
]
const COLLABORATORS := ["Ramon Santos", "Renato Leal", "Matheus Ché", "Pedro Almeida"]
## Fonte do menu (AJUSTAR → Cenário): padrão do Godot ou as duas fontes do 2D.
const MENU_FONTS := PainelAjustes.FONTES_MENU
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
## Histórico, AJUSTAR ou SOBRE abertos no centro da tela (clique fora fecha).
var modal_open := false
var home_corner: Button
var home_icon	# hud_icon.gd
var map_icon	# hud_icon.gd
var ajustes_icon	# hud_icon.gd
var ajustes	# painel_ajustes.gd
var options_open := false
## Botões HOME e "?" que o MAPA acrescenta à coluna do canto (removidos ao sair).
var map_corner_nodes: Array[Control] = []
## Deslize/zoom gradual até um ponto de interesse (lista do painel ou marcador).
var map_tween: Tween
var map_help_button: Button
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
		lines = IdiomaMenu.campo(dialog_data, "travessia", [])
	var history_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/historico_3d.json"))
	if history_data is Dictionary:
		history_entries = history_data.get("entradas", [])
		version_text = "v%s · Build #%d" % [str(history_data.get("versao_atual", "0.1.0-dev")), int(history_data.get("build_numero", 1))]
	var layer := CanvasLayer.new()
	add_child(layer)
	ajustes = PainelAjustes.new()
	ajustes.fechar_pedido.connect(_home)
	ajustes.estilo_mudou.connect(func() -> void:
		# Trocar o estilo reconstrói a cena do menu; ao voltar, reabre em Cenário.
		_reabrir_ajustes = true
		get_tree().reload_current_scene())
	ajustes.fonte_menu_mudou.connect(func(option: int) -> void:
		menu_font_option = option
		panel.theme = _menu_theme()
		ajustes.tema = panel.theme)
	ajustes.cenario_menu_mudou.connect(func(sobrevoo: bool) -> void: flyover_active = sobrevoo)
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
	_create_home_button(layer)
	_create_ajustes_button(layer)
	_create_quick_mute(layer)
	_create_clock(layer)
	_create_map_button(layer)
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


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if ajustes.ajuda_aberta() and event.keycode == KEY_ESCAPE:
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
	# Clique fora de um modal (fora do painel e dos botões do canto) fecha e volta ao menu.
	if modal_open and not ajustes.ajuda_aberta() and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Audio.efeito("ui_voltar")
		_home()
		return
	if not map_open:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_stop_map_tween()
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(30.0, camera.size * 0.78)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(map_full_size, camera.size * 1.28)
		_limit_map_target()
	if event is InputEventMouseMotion and (event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT)):
		_stop_map_tween()
		var meters_per_pixel := camera.size / maxf(1.0, get_viewport().get_visible_rect().size.y)
		map_target.x -= event.relative.x * meters_per_pixel
		map_target.z -= event.relative.y * meters_per_pixel
		_limit_map_target()


func _limit_map_target() -> void:
	map_target = _clamped_map_target(map_target, camera.size)


## Centro da vista mais próximo de `target` que não mostra nada fora do quadro do mapa
## com a câmera de tamanho `view_size`.
func _clamped_map_target(target: Vector3, view_size: float) -> Vector3:
	var frame: Rect2 = $Cenario.get_map_frame()
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var half_width := view_size * aspect * 0.5
	var half_height := view_size * 0.5
	var min_x := frame.position.x + half_width
	var max_x := frame.end.x - half_width
	var min_z := frame.position.y + half_height
	var max_z := frame.end.y - half_height
	target.x = clampf(target.x, min_x, max_x) if min_x <= max_x else frame.get_center().x
	target.z = clampf(target.z, min_z, max_z) if min_z <= max_z else frame.get_center().y
	return target

func _clear() -> void:
	_close_help()
	history_open = false
	map_open = false
	modal_open = false
	_set_home_corner(false)
	if map_icon:
		map_icon.definir(false)
	options_open = false
	if ajustes_icon:
		ajustes_icon.definir(false)
	camera.environment = null
	if map_marker_root:
		map_marker_root.queue_free()
		map_marker_root = null
	for node in map_corner_nodes:
		node.queue_free()
	map_corner_nodes.clear()
	_stop_map_tween()
	panel.visible = true
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
	modal_open = true
	panel.custom_minimum_size = modal_size
	panel.offset_left = -modal_size.x * 0.5
	panel.offset_right = modal_size.x * 0.5
	panel.offset_top = -modal_size.y * 0.5
	panel.offset_bottom = modal_size.y * 0.5

func _menu_theme() -> Theme:
	return TemaMenu.criar(MENU_FONTS[menu_font_option])


## Botões redondos do canto superior direito (som, relógio): ver botao_canto.gd.
## Devolve [botão, rótulo da dica].
func _corner_button(layer: CanvasLayer, top: float, icon: Control) -> Array:
	var parts := BotaoCanto.criar(layer, top, icon)
	(parts[0] as Button).toggle_mode = true
	return parts


## HOME no alto da coluna do canto (mesma posição no jogo): de qualquer tela do menu
## (modal, mapa, travessia) volta direto ao menu inicial, sem carregamento.
func _create_home_button(layer: CanvasLayer) -> void:
	home_icon = HudIcon.new().configurar("casa")
	var parts := BotaoCanto.criar(layer, 32.0, home_icon)
	home_corner = parts[0]
	(parts[1] as Label).text = "Home"
	home_corner.pressed.connect(func() -> void:
		if starting:
			return
		Audio.efeito("ui_confirmar")
		_home())


## AJUSTAR na coluna do canto, logo abaixo de HOME (mesma posição no jogo): abre os
## ajustes; aberto, fica dourado e fecha de volta para a Home.
func _create_ajustes_button(layer: CanvasLayer) -> void:
	ajustes_icon = HudIcon.new().configurar("ajustes")
	var parts := BotaoCanto.criar(layer, 96.0, ajustes_icon)
	(parts[1] as Label).text = tr("Ajustes")
	(parts[0] as Button).pressed.connect(func() -> void:
		if starting:
			return
		Audio.efeito("ui_confirmar")
		if options_open:
			_home()
		else:
			_options())


## MAPA na coluna do canto, abaixo do relógio (mesma posição no jogo): abre o mapa do
## vale; com o mapa aberto fica dourado e fecha de volta para a Home.
func _create_map_button(layer: CanvasLayer) -> void:
	map_icon = HudIcon.new().configurar("mapa")
	var parts := BotaoCanto.criar(layer, 288.0, map_icon)
	(parts[1] as Label).text = tr("Mapa")
	(parts[0] as Button).pressed.connect(func() -> void:
		if starting:
			return
		Audio.efeito("ui_confirmar")
		if map_open:
			_home()
		else:
			_open_map())


## Na Home a casa fica dourada e não responde (já se está lá); em qualquer outra tela
## (modal, mapa, travessia) volta a ser clicável.
func _set_home_corner(at_home: bool) -> void:
	if home_corner == null:
		return
	home_icon.definir(at_home)
	home_corner.disabled = at_home
	home_corner.mouse_default_cursor_shape = Control.CURSOR_ARROW if at_home else Control.CURSOR_POINTING_HAND


func _create_quick_mute(layer: CanvasLayer) -> void:
	var audio_icon := AudioToggleIcon.new()
	audio_icon.set_active(Audio.som_ativo)
	var parts := _corner_button(layer, 160.0, audio_icon)
	var quick_mute: Button = parts[0]
	var hint_label: Label = parts[1]
	quick_mute.button_pressed = Audio.som_ativo
	hint_label.text = "Desativar" if Audio.som_ativo else "Ativar"
	quick_mute.toggled.connect(func(active: bool):
		Audio.definir_som_ativo(active)
		Audio.efeito("ui_confirmar")
		audio_icon.set_active(active)
		hint_label.text = "Desativar" if active else "Ativar")


## Relógio do menu: os ponteiros acompanham a hora do vale, que corre desde o começo
## do dia na velocidade de Passagem do tempo; o botão pausa e retoma o dia.
func _create_clock(layer: CanvasLayer) -> void:
	var clock_icon := ClockIcon.new()
	clock_icon.set_running(clock_running)
	var parts := _corner_button(layer, 224.0, clock_icon)
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
		Audio.efeito("ui_confirmar")
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
	_button("SOBRE", _credits)
	_button("SAIR", _confirm_exit).theme_type_variation = &"BotaoNegativo"
	if not history_entries.is_empty():
		_create_version_link()
	_set_home_corner(true)

func _open_map() -> void:
	_clear()
	map_open = true
	panel.custom_minimum_size = Vector2(440, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 36
	panel.offset_right = 476
	panel.offset_top = 32
	panel.offset_bottom = 32
	_modal_header("Mapa do Vale", func() -> void: map_help_button.button_pressed = false,
		"%s · %s" % [$Cenario.get_region_title(), tr("1 unidade = %s m") % _formatar_escala($Cenario.get_meters_per_unit())])
	_label("N ↑ · roda: zoom · arrastar: mover", 14)
	var points_title := _label("Pontos de interesse", 16)
	points_title.add_theme_color_override("font_color", Color("e2c47f"))
	# Clicar num ponto desliza e aproxima o mapa até ele.
	var points := GridContainer.new()
	points.columns = 2
	points.add_theme_constant_override("h_separation", 8)
	points.add_theme_constant_override("v_separation", 6)
	content.add_child(points)
	for point: Array in _map_points():
		var button := Button.new()
		button.text = "● " + String(point[0])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 32)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		button.focus_mode = Control.FOCUS_NONE
		var destination: Vector3 = point[1]
		button.pressed.connect(func() -> void:
			Audio.efeito("ui_confirmar")
			_focus_map_marker(destination, true))
		points.add_child(button)
	# O mapa ocupa a tela toda: as informações ficam ocultas e o "?" do canto (abaixo de
	# HOME, som, relógio e mapa) as mostra.
	panel.visible = false
	map_icon.definir(true)
	var layer := panel.get_parent()
	var help_icon: Control = HudIcon.new().configurar("ajuda")
	var help_parts := BotaoCanto.criar(layer, 352.0, help_icon)
	var help_button: Button = help_parts[0]
	map_help_button = help_button
	var help_hint: Label = help_parts[1]
	help_button.toggle_mode = true
	help_hint.text = tr("Mostrar informações")
	help_button.toggled.connect(func(active: bool) -> void:
		Audio.efeito("ui_confirmar")
		panel.visible = active
		help_icon.definir(active)
		help_hint.text = tr("Ocultar informações") if active else tr("Mostrar informações"))
	map_corner_nodes.append(help_button.get_parent())
	map_corner_nodes.append(help_hint.get_parent())
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
	for point: Array in _map_points():
		_add_map_marker(point[0], point[1])
	_position_map_markers()


## Pontos de interesse e áreas do mapa como [nome traduzido, posição]; nomes repetidos
## ganham número (Rio 1, Rio 2).
func _map_points() -> Array:
	var points: Array = []
	var name_totals: Dictionary = {}
	var name_seen: Dictionary = {}
	for landmark: Dictionary in $Cenario.landmarks:
		var name: String = landmark["name"]
		name_totals[name] = int(name_totals.get(name, 0)) + 1
	for landmark: Dictionary in $Cenario.landmarks:
		var base_name: String = landmark["name"]
		var marker_name := tr(base_name)
		if int(name_totals[base_name]) > 1:
			name_seen[base_name] = int(name_seen.get(base_name, 0)) + 1
			marker_name = "%s %d" % [marker_name, name_seen[base_name]]
		points.append([marker_name, landmark["position"]])
	for area: Dictionary in $Cenario.areas:
		if area["name"] != "Praça":
			points.append([tr(area["name"]), area["position"]])
	return points


func _add_map_marker(label: String, position: Vector3) -> void:
	var marker := Button.new()
	marker.text = "● " + label
	marker.tooltip_text = tr("Centralizar em %s") % label
	marker.custom_minimum_size = Vector2(0, 26)
	marker.add_theme_font_size_override("font_size", 13)
	marker.pressed.connect(_focus_map_marker.bind(position, true))
	map_marker_root.add_child(marker)
	map_markers.append({"control": marker, "position": position})


## Centraliza e aproxima um ponto. Com `animate`, desliza e aproxima aos poucos.
func _focus_map_marker(position: Vector3, animate := false) -> void:
	var view_size := minf(camera.size, 420.0 / $Cenario.get_meters_per_unit())
	var target := _clamped_map_target(position, view_size)
	_stop_map_tween()
	if not animate:
		camera.size = view_size
		map_target = target
		return
	map_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	map_tween.tween_property(self, "map_target", target, 0.9)
	map_tween.tween_property(camera, "size", view_size, 0.9)


func _stop_map_tween() -> void:
	if map_tween and map_tween.is_valid():
		map_tween.kill()
	map_tween = null


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
	if not is_instance_valid(button) or button.has_meta("pressionando"):
		return
	if button.disabled:
		# Já na primeira/última página: som de trava, sem mudar de página.
		Audio.efeito("ui_trava")
		return
	button.set_meta("pressionando", true)
	button.add_theme_stylebox_override("normal", button.get_theme_stylebox("pressed"))
	button.add_theme_stylebox_override("hover", button.get_theme_stylebox("pressed"))
	button.add_theme_color_override("font_color", button.get_theme_color("font_pressed_color"))
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(button) and history_open:
		_change_history(1 if index == 1 else -1)


## Troca de página (clique na seta ou tecla ← →), sempre com o mesmo som.
func _change_history(step: int) -> void:
	Audio.efeito("ui_hover")
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
	# Os termos entre *asteriscos* no historico_3d.json aparecem em dourado.
	for change in IdiomaMenu.campo(entry, "mudancas", []):
		var change_label := RichTextLabel.new()
		change_label.bbcode_enabled = true
		change_label.fit_content = true
		change_label.scroll_active = false
		change_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		change_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		change_label.add_theme_font_size_override("normal_font_size", 17)
		change_label.add_theme_color_override("default_color", Color.WHITE)
		var parts := ("• " + str(change)).replace("[", "[lb]").split("*")
		for i in range(1, parts.size(), 2):
			parts[i] = "[color=#e2c47f]%s[/color]" % parts[i]
		change_label.text = "".join(parts)
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
	# Clique numa seta desativada (primeira/última página) toca o som de trava.
	for arrow in history_buttons:
		arrow.gui_input.connect(func(event: InputEvent) -> void:
			if arrow.disabled and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				Audio.efeito("ui_trava"))

func _confirm_exit() -> void:
	_clear()
	_label("Sair do jogo?", 30)
	_label("Deseja encerrar Myths’ Valley?", 18)
	_button("CANCELAR", _home).grab_focus()
	_button("SAIR", func(): get_tree().quit()).theme_type_variation = &"BotaoNegativo"

## AJUSTAR (painel_ajustes.gd) no modal central. `tab`: Geral, Sons do vale ou Cenário.
func _options(tab: int = 0) -> void:
	_clear()
	_place_modal(PainelAjustes.TAMANHO)
	options_open = true
	ajustes_icon.definir(true)
	ajustes.tema = panel.theme
	ajustes.construir(content, panel.get_parent(), tab)


## Cabeçalho padrão dos modais (painel_ajustes.gd): título, subtítulo, × e divisor.
func _modal_header(title: String, action: Callable, subtitle: String = "", icon: String = "fechar") -> Button:
	return PainelAjustes.cabecalho(ui_parent, title, action, subtitle, icon)


func _close_help() -> void:
	ajustes.fechar_ajuda()


func _credits() -> void:
	_clear()
	_place_modal(HISTORY_SIZE)
	var home := _modal_header("Por trás do vale", _home, "Quem faz o vale e de onde ele vem.")
	_highlighted("O vale nasceu do encontro entre paisagens, memórias e histórias brasileiras. Entre casas, caminhos e mata, cada lugar convida a uma descoberta.")
	_highlighted("Música, narração e efeitos acompanham a travessia e dão voz aos lugares e personagens. Esta é uma primeira visita a esse mundo. Obrigado por caminhar conosco enquanto a jornada cresce.")
	_highlighted("Myths’ Valley é uma criação da equipe da Alpha Centauri, um spin-off do projeto Batalha de Mitos. Você pode saber mais acessando:")
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

## Parágrafo com os termos de CREDITS_HIGHLIGHTS em dourado, para a leitura correr
## pelos pontos principais. O texto é traduzido antes; os termos cobrem os três idiomas.
func _highlighted(text: String) -> void:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich.custom_minimum_size.x = 375
	rich.add_theme_font_size_override("normal_font_size", 20)
	rich.add_theme_color_override("default_color", Color.WHITE)
	var translated := tr(text).replace("[", "[lb]")
	for term: String in CREDITS_HIGHLIGHTS:
		translated = translated.replace(term, "[color=#e2c47f]%s[/color]" % term)
	rich.text = translated
	content.add_child(rich)


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
	Audio.parar_narracao()
	# A tela de carregamento é montada ainda no idioma do menu; os textos já vêm
	# traduzidos e não mudam quando o locale volta ao português do jogo.
	var loading := _show_loading()
	Dia.pausado = false
	Dia.definir_hora(Dia.hora_inicial)
	IdiomaMenu.restaurar_jogo()
	TelaCarregamento.trocar_cena(get_tree(), GAME_SCENE, loading)


## Tela de carregamento sobre o menu (tela_carregamento.gd). Devolve a barra.
func _show_loading() -> ProgressBar:
	_close_help()
	return TelaCarregamento.mostrar(panel.get_parent(), panel.theme, tr("Carregando o vale…"))


func _formatar_escala(meters_per_unit: float) -> String:
	if is_equal_approx(meters_per_unit, roundf(meters_per_unit)):
		return str(int(roundf(meters_per_unit)))
	return String.num(meters_per_unit, 2)
