extends RefCounted
## Tela de carregamento entre o menu e o vale (nos dois sentidos): fundo escuro, título,
## frase e barra dourada. `trocar_cena` carrega a cena em segundo plano, avança a barra
## e troca de cena; a tela some junto com a cena antiga.

const OURO := Color("e2c47f")


## Monta a tela sobre `pai` (CanvasLayer ou Control de tela cheia) e devolve a barra.
static func mostrar(pai: Node, tema: Theme, mensagem: String) -> ProgressBar:
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.theme = tema
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	pai.add_child(screen)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.07, 0.06, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(shade)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.custom_minimum_size = Vector2(460, 0)
	column.add_theme_constant_override("separation", 14)
	screen.add_child(column)
	var title := Label.new()
	title.text = "Myths’ Valley"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	column.add_child(title)
	var message := Label.new()
	# O texto já chega traduzido: não muda quando o locale troca durante a carga.
	message.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	message.text = mensagem
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 18)
	message.add_theme_color_override("font_color", Color("c9b98f"))
	column.add_child(message)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.step = 0.0
	bar.custom_minimum_size.y = 8
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.12)
	back.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = OURO
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	column.add_child(bar)
	var place := Label.new()
	place.text = "Bom Jesus dos Pobres · 1887"
	place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place.add_theme_font_size_override("font_size", 14)
	place.add_theme_color_override("font_color", Color(0.72, 0.73, 0.66))
	column.add_child(place)
	screen.modulate.a = 0.0
	screen.create_tween().tween_property(screen, "modulate:a", 1.0, 0.2)
	return bar


## Carrega `cena` em segundo plano e troca para ela. Os recursos lidos ocupam até 85% da
## barra; o restante é a montagem da cena nova.
static func trocar_cena(arvore: SceneTree, cena: String, barra: ProgressBar) -> void:
	ResourceLoader.load_threaded_request(cena)
	var progress: Array = []
	while true:
		var status := ResourceLoader.load_threaded_get_status(cena, progress)
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			break
		barra.value = maxf(barra.value, float(progress[0]) * 0.85)
		await arvore.process_frame
	barra.value = 0.9
	await arvore.process_frame
	var packed := ResourceLoader.load_threaded_get(cena) as PackedScene
	if packed == null:
		arvore.change_scene_to_file(cena)
		return
	arvore.change_scene_to_packed(packed)
