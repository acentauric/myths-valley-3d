extends RefCounted
## Botão do canto superior direito (menu e HUD do vale), na identidade "Crônica do
## Recôncavo": placa de laca com canto chanfrado e borda de ouro, ícone vetorial e dica
## própria à esquerda em Cormorant itálico. A dica aparece com o mouse em cima e com o
## foco vindo do teclado (não depois de um clique). Os botões empilham a partir de
## `topo`, de ESPACO em ESPACO.

const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")

const ESPACO := 64.0
const FUNDO := Color(0.055, 0.09, 0.075, 0.94)
const BORDA := Color(0.788, 0.647, 0.353, 0.8)


## Devolve [Button, Label da dica]. O ícone ocupa 24×24 no centro do botão.
static func criar(pai: Node, topo: float, icone: Control) -> Array:
	var canto := PanelContainer.new()
	canto.anchor_left = 1.0
	canto.anchor_right = 1.0
	canto.offset_left = -88.0
	canto.offset_right = -36.0
	canto.offset_top = topo
	canto.offset_bottom = topo + 52.0
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = FUNDO
	estilo.border_color = BORDA
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(10)
	estilo.corner_detail = 1
	estilo.shadow_color = Color(0, 0, 0, 0.35)
	estilo.shadow_size = 6
	estilo.shadow_offset = Vector2(0, 2)
	estilo.content_margin_left = 6
	estilo.content_margin_right = 6
	estilo.content_margin_top = 6
	estilo.content_margin_bottom = 6
	canto.add_theme_stylebox_override("panel", estilo)
	pai.add_child(canto)
	var dica := PanelContainer.new()
	dica.anchor_left = 1.0
	dica.anchor_right = 1.0
	dica.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	dica.offset_left = -98.0
	dica.offset_right = -98.0
	dica.offset_top = topo + 8.0
	dica.offset_bottom = topo + 44.0
	dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dica.visible = false
	var estilo_dica := estilo.duplicate() as StyleBoxFlat
	estilo_dica.set_corner_radius_all(6)
	estilo_dica.shadow_size = 0
	estilo_dica.border_color = Color(Identidade.OURO, 0.45)
	estilo_dica.content_margin_left = 14
	estilo_dica.content_margin_right = 14
	estilo_dica.content_margin_top = 6
	estilo_dica.content_margin_bottom = 6
	dica.add_theme_stylebox_override("panel", estilo_dica)
	var rotulo := Label.new()
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotulo.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_ITALICO, 500))
	rotulo.add_theme_font_size_override("font_size", 20)
	rotulo.add_theme_color_override("font_color", Identidade.CREME)
	dica.add_child(rotulo)
	pai.add_child(dica)
	var botao := Button.new()
	botao.flat = true
	botao.custom_minimum_size = Vector2(40, 40)
	botao.mouse_entered.connect(func(): dica.visible = true)
	# Com o foco do teclado a dica também aparece; depois de um clique, não (o foco
	# fica no botão, e a dica presa na tela seria um estorvo).
	botao.focus_entered.connect(func() -> void:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			botao.set_meta("dica_teclado", true)
			dica.visible = true)
	botao.focus_exited.connect(func() -> void:
		botao.set_meta("dica_teclado", false)
		dica.visible = false)
	botao.mouse_exited.connect(func() -> void:
		if not botao.get_meta("dica_teclado", false):
			dica.visible = false)
	icone.position = Vector2(8, 8)
	icone.size = Vector2(24, 24)
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	botao.add_child(icone)
	canto.add_child(botao)
	return [botao, rotulo]


## Letra sempre visível, no mesmo canto usado pelos números da barra de itens.
## Fica sobre o ícone sem capturar cliques ou foco do botão.
static func marcar_atalho(botao: Button, tecla: String) -> Label:
	var marca := Label.new()
	marca.name = "TeclaDeAtalho"
	marca.text = tecla
	marca.position = Vector2(2, 1)
	marca.add_theme_font_size_override("font_size", 11)
	marca.add_theme_color_override("font_color", Identidade.OURO)
	marca.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	marca.add_theme_constant_override("shadow_offset_x", 1)
	marca.add_theme_constant_override("shadow_offset_y", 1)
	marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
	botao.add_child(marca)
	return marca
