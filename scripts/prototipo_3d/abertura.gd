extends Node3D
## Interface 3D; contrato de áudio e narrativa idênticos aos da versão 2D.
var camera := Camera3D.new()
var panel: PanelContainer
var content: VBoxContainer
var caption: Label
var chapter: Label
var lines: Array = []
var line_index := -1
var elapsed := 0.0
var line_time := 0.0
var starting := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	add_child(camera)
	camera.current = true
	camera.fov = 55
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogos/pedro.json"))
	if data is Dictionary:
		lines = data.get("travessia", [])
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
	Audio.tocar_musica(Audio.obter_caminho_musica_menu())
	Audio.iniciar_ambiente_menu()
	_home()
	print("OPENING_READY: audio compartilhado e abertura 3D")

func _process(delta: float) -> void:
	elapsed += delta
	var target := Vector3(3, 1.5, -6)
	var eye := Vector3(24, 12, 20)
	if line_index >= 0:
		var phase := mini(line_index / 3, 2)
		eye = [Vector3(-28, 7, 23), Vector3(-21, 5, 13), Vector3(18, 8, 12)][phase]
		target = [Vector3(-15, 0, 0), Vector3(-9, 1, -4), Vector3(5, 1, -7)][phase]
		line_time -= delta
		if line_time <= 0:
			_next_line()
	camera.position = eye + Vector3(sin(elapsed * 0.08) * 1.2, 0, cos(elapsed * 0.08))
	camera.look_at(target)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if line_index >= 0:
			if event.keycode == KEY_ESCAPE:
				_start_game()
			elif event.keycode in [KEY_ENTER, KEY_SPACE, KEY_E]:
				_next_line()
		elif event.keycode == KEY_ESCAPE:
			_home()

func _clear() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

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
	Audio.parar_narracao()
	_clear()
	_label("RECÔNCAVO BAIANO · 1887", 16)
	_label("Myths’ Valley", 46)
	_label("Uma herança. Uma travessia.\nUm vale cheio de histórias.", 21)
	_label("PROTÓTIPO 3D", 16)
	_button("JOGAR · a travessia", _intro).grab_focus()
	_button("Explorar diretamente", _start_game)
	_button("Opções de áudio", _options)
	_button("Créditos e bastidores", _credits)
	_button("Sair", func(): get_tree().quit())
	_label("WASD: andar · Shift: correr\nMouse: câmera · Esc: soltar mouse\nM: voltar à abertura", 16)

func _options() -> void:
	_clear()
	_label("Opções de áudio", 30)
	var mute := CheckButton.new()
	mute.text = "Som ativado"
	mute.button_pressed = Audio.som_ativo
	mute.toggled.connect(Audio.definir_som_ativo)
	content.add_child(mute)
	_slider("Música", Audio.volume_musica, Audio.definir_volume_musica)
	_slider("Efeitos e passos", Audio.volume_efeitos, Audio.definir_volume_efeitos)
	_slider("Ambiente", Audio.volume_ambiente, Audio.definir_volume_ambiente)
	_choice("Trilha do menu", ["Introdução", "Menu I", "Menu II", "Recôncavo"], Audio.musica_menu_opcao - 1, func(i): Audio.definir_musica_menu(i + 1))
	_choice("Interface", ["Original", "Madeira"], Audio.efeitos_menu_opcao - 1, func(i):
		Audio.definir_efeitos_menu(i + 1)
		Audio.testar_efeito_menu())
	_choice("Paisagem sonora", ["Silêncio", "Mar", "Aves", "Mar e aves"], Audio.ambiente_menu_opcao, Audio.definir_ambiente_menu)
	_button("Voltar", _home)

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
	_label("Feito no mesmo vale", 30)
	_label("Myths’ Valley · equipe acentauric\n\nHistória, músicas, narração e efeitos reutilizados da versão 2D.\n\nCenário em tempo real: construção procedural e modelos Tripo já integrados ao protótipo. Nenhum sprite 2D usado na abertura.\n\nEsta é uma demonstração de exploração: ainda não inclui o tutorial completo, missões ou saves do jogo 2D.", 20)
	_label("Proveniência dos áudios: assets/audio/fontes.\nCompatibilidade e sincronização: docs/ABERTURA_E_AUDIO_3D.md.", 16)
	_button("Voltar", _home).grab_focus()

func _intro() -> void:
	_clear()
	chapter = _label("A travessia", 30)
	_label("As mesmas palavras do jogo 2D, sob um novo olhar.", 16)
	caption = _label("", 25)
	caption.custom_minimum_size.y = 300
	_button("Continuar · Enter", _next_line)
	_button("Pular introdução · Esc", _start_game)
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
