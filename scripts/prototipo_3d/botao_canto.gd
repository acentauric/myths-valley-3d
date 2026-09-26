extends RefCounted
## Botão redondo do canto superior direito (menu e HUD do vale): painel escuro com
## borda dourada, ícone vetorial e dica própria à esquerda, que aparece só com o mouse
## em cima (o tooltip nativo destoa da identidade). Os botões empilham a partir de
## `topo`, de ESPACO em ESPACO.

const ESPACO := 64.0
const FUNDO := Color(0.055, 0.09, 0.075, 0.94)
const BORDA := Color("b49a60")


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
	estilo.set_corner_radius_all(12)
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
	estilo_dica.set_corner_radius_all(8)
	estilo_dica.content_margin_left = 14
	estilo_dica.content_margin_right = 14
	estilo_dica.content_margin_top = 6
	estilo_dica.content_margin_bottom = 6
	dica.add_theme_stylebox_override("panel", estilo_dica)
	var rotulo := Label.new()
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotulo.add_theme_font_size_override("font_size", 15)
	rotulo.add_theme_color_override("font_color", Color("ece6d6"))
	dica.add_child(rotulo)
	pai.add_child(dica)
	var botao := Button.new()
	botao.flat = true
	botao.custom_minimum_size = Vector2(40, 40)
	botao.mouse_entered.connect(func(): dica.visible = true)
	botao.mouse_exited.connect(func(): dica.visible = false)
	icone.position = Vector2(8, 8)
	icone.size = Vector2(24, 24)
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	botao.add_child(icone)
	canto.add_child(botao)
	return [botao, rotulo]
