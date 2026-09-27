extends RefCounted
## Tema dos painéis do menu (e da confirmação de saída no jogo): botões, abas,
## seletores e as variações BotaoNegativo, BotaoIcone e BotaoAjuda.


## Botões do painel destacados do fundo verde-escuro: base mais clara com borda dourada,
## hover mais claro, foco com contorno dourado e aba/botão ativo em tom de ouro.
## Vale também para OptionButton, que herda os estilos de Button. A variação
## BotaoNegativo (SAIR) usa o terracota das telhas do vale para marcar ação destrutiva.
static func criar(fonte: String = "") -> Theme:
	var theme := Theme.new()
	if not fonte.is_empty():
		theme.default_font = load(fonte) as Font
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
	# Volumes: trilha clara com borda dourada (o limite da barra aparece sobre o fundo
	# escuro) e a parte preenchida em ouro.
	theme.set_stylebox("slider", "HSlider", _trilha(Color(0.30, 0.35, 0.31), Color(0.71, 0.60, 0.38, 0.7)))
	theme.set_stylebox("grabber_area", "HSlider", _trilha(Color("b99a58"), Color("b99a58")))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _trilha(Color("e2c47f"), Color("e2c47f")))
	return theme


## Fundo dos painéis e modais: verde-escuro com borda dourada fina.
static func estilo_painel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.09, 0.075, 0.94)
	style.border_color = Color("b49a60")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	return style


static func _trilha(fundo: Color, borda: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fundo
	box.border_color = borda
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box


## Estados de um tipo de botão: estado → [fundo, borda, espessura da borda].
static func _button_styles(theme: Theme, type_name: String, states: Dictionary) -> void:
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
