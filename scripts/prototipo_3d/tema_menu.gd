extends RefCounted
## Tema da interface na identidade "Crônica do Recôncavo" (menu, modais e HUD): corpo
## em Cormorant Garamond, ações em Cinzel versalete sobre laca verde-escura com bordas
## de ouro e canto chanfrado. Variações: BotaoCronica e BotaoCronicaNegativo (placas da
## home), BotaoLegenda (travessia), BotaoNegativo (SAIR), BotaoIcone e BotaoAjuda.

const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")

const LACA_NORMAL := Color(0.082, 0.129, 0.106, 0.92)
const LACA_HOVER := Color(0.114, 0.173, 0.141)
const LACA_PRESSED := Color(0.29, 0.24, 0.12)
const BORDA_SUAVE := Color(0.706, 0.604, 0.376, 0.55)
## Medidas globais dos botões comuns (Cinzel): a fonte vale para todo Button do tema, e
## a altura é a que as telas usam no custom_minimum_size. As placas do retábulo da home
## (BotaoCronica) seguem as mesmas medidas. Em tela cheia a interface é
## esticada da referência 1280×720, então 15 e 44 já saem com 22 e 66 px em 1080p.
const FONTE_BOTAO := 14
const ALTURA_BOTAO := 44
## As placas do retábulo da home ficam no tamanho de antes: só os botões comuns encolheram.
const FONTE_PLACA := 15
## Escala tipográfica do corpo e dos modais (#167). É o "Médio" do Tamanho do texto: o
## Pequeno, o Grande e o Muito grande multiplicam estes valores, então nenhum painel precisa
## de número solto. Em 1080p cada um sai 1,5 vez maior.
const FONTE_CORPO := 17
const FONTE_ROTULO := 15
const FONTE_SECAO := 18
const FONTE_TITULO_MODAL := 20
const FONTE_SUBTITULO_MODAL := 15
const FONTE_AJUDA_CAMPO := 12


## `fonte` vem da opção "Fonte do menu": "" é a Crônica (Cormorant no corpo e Cinzel
## nas ações), "padrao" é a fonte do Godot, e um caminho .ttf troca só o corpo.
static func criar(fonte: String = "") -> Theme:
	var theme := Theme.new()
	var cronica := fonte.is_empty()
	if cronica:
		theme.default_font = Identidade.fonte(Identidade.FONTE_TEXTO, 600)
		theme.default_font_size = FONTE_CORPO
	elif fonte != "padrao":
		theme.default_font = load(fonte) as Font
	_button_styles(theme, "Button", {
		"normal": [LACA_NORMAL, BORDA_SUAVE, 1],
		"hover": [LACA_HOVER, Identidade.OURO, 1],
		"pressed": [LACA_PRESSED, Identidade.OURO, 1],
		"hover_pressed": [LACA_PRESSED, Identidade.OURO, 1],
		"disabled": [Color(0.063, 0.094, 0.078, 0.7), Color(0.706, 0.604, 0.376, 0.25), 1],
		"focus": [Color(0, 0, 0, 0), Color("f5e3b3"), 2],
	})
	theme.set_color("font_color", "Button", Color(Identidade.CREME, 0.92))
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_focus_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Color("fff4d6"))
	theme.set_color("font_hover_pressed_color", "Button", Color("fff4d6"))
	theme.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.3))
	# Dicas (tooltip) de todo controle com este tema, iguais às dos botões do canto:
	# laca, fio de ouro e Cormorant itálico em creme.
	var dica := StyleBoxFlat.new()
	dica.bg_color = Color(0.055, 0.09, 0.075, 0.96)
	dica.border_color = Color(Identidade.OURO, 0.45)
	dica.set_border_width_all(1)
	dica.set_corner_radius_all(6)
	dica.corner_detail = 1
	dica.content_margin_left = 12
	dica.content_margin_right = 12
	dica.content_margin_top = 4
	dica.content_margin_bottom = 4
	theme.set_stylebox("panel", "TooltipPanel", dica)
	theme.set_font("font", "TooltipLabel", Identidade.fonte(Identidade.FONTE_ITALICO, 500))
	theme.set_font_size("font_size", "TooltipLabel", 18)
	theme.set_color("font_color", "TooltipLabel", Identidade.CREME)
	theme.set_color("font_shadow_color", "TooltipLabel", Color(0, 0, 0, 0))
	if cronica:
		# Ações em Cinzel; o corpo dos seletores e campos continua em Cormorant, que
		# tem minúsculas (OptionButton herdaria a fonte de Button pela árvore de tipos).
		theme.set_font("font", "Button", Identidade.fonte(Identidade.FONTE_TITULO, 600, 2))
		theme.set_font_size("font_size", "Button", FONTE_BOTAO)
		for corpo in ["OptionButton", "PopupMenu", "LineEdit", "TextEdit", "SpinBox"]:
			theme.set_font("font", corpo, theme.default_font)
			theme.set_font_size("font_size", corpo, FONTE_CORPO)
	# Placas do retábulo (home e confirmação de sair): Cinzel maior, canto chanfrado
	# e brilho dourado no foco — as rosas dos ventos entram por fora (abertura.gd).
	theme.set_type_variation("BotaoCronica", "Button")
	_button_styles(theme, "BotaoCronica", {
		"normal": [LACA_NORMAL, BORDA_SUAVE, 1],
		"hover": [LACA_HOVER, Color(Identidade.OURO, 0.9), 1],
		"pressed": [LACA_PRESSED, Identidade.OURO, 1],
		"hover_pressed": [LACA_PRESSED, Identidade.OURO, 1],
		"disabled": [Color(0.063, 0.094, 0.078, 0.6), Color(0.706, 0.604, 0.376, 0.2), 1],
		"focus": [Color(0, 0, 0, 0), Identidade.OURO, 2],
	}, 16, 8, true)
	theme.set_font("font", "BotaoCronica", Identidade.fonte(Identidade.FONTE_TITULO, 600, 3))
	theme.set_font_size("font_size", "BotaoCronica", FONTE_PLACA)
	theme.set_color("font_color", "BotaoCronica", Color(Identidade.CREME, 0.92))
	theme.set_color("font_hover_color", "BotaoCronica", Color("fff8e6"))
	theme.set_color("font_focus_color", "BotaoCronica", Color("fff8e6"))
	theme.set_color("font_pressed_color", "BotaoCronica", Color("fff4d6"))
	theme.set_color("font_hover_pressed_color", "BotaoCronica", Color("fff4d6"))
	theme.set_type_variation("BotaoCronicaNegativo", "Button")
	_button_styles(theme, "BotaoCronicaNegativo", {
		"normal": [Color(0.165, 0.09, 0.071, 0.92), Color(Identidade.TERRACOTA, 0.55), 1],
		"hover": [Color(0.227, 0.114, 0.082), Identidade.TERRACOTA, 1],
		"pressed": [Color(0.353, 0.165, 0.11), Identidade.TERRACOTA, 1],
		"hover_pressed": [Color(0.353, 0.165, 0.11), Identidade.TERRACOTA, 1],
		"disabled": [Color(0.09, 0.063, 0.055, 0.6), Color(Identidade.TERRACOTA, 0.2), 1],
		"focus": [Color(0, 0, 0, 0), Color("f4c2ad"), 2],
	}, 16, 8, true)
	theme.set_font("font", "BotaoCronicaNegativo", Identidade.fonte(Identidade.FONTE_TITULO, 600, 3))
	theme.set_font_size("font_size", "BotaoCronicaNegativo", FONTE_PLACA)
	theme.set_color("font_color", "BotaoCronicaNegativo", Color("f2d3c6"))
	theme.set_color("font_hover_color", "BotaoCronicaNegativo", Color.WHITE)
	theme.set_color("font_focus_color", "BotaoCronicaNegativo", Color.WHITE)
	theme.set_color("font_pressed_color", "BotaoCronicaNegativo", Color("fbe3d8"))
	theme.set_color("font_hover_pressed_color", "BotaoCronicaNegativo", Color("fbe3d8"))
	# CONTINUAR e PULAR da travessia: só o texto em Cinzel, sem caixa.
	theme.set_type_variation("BotaoLegenda", "Button")
	for estado in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var vazio := StyleBoxEmpty.new()
		vazio.content_margin_left = 8
		vazio.content_margin_right = 8
		vazio.content_margin_top = 6
		vazio.content_margin_bottom = 6
		theme.set_stylebox(estado, "BotaoLegenda", vazio)
	theme.set_font("font", "BotaoLegenda", Identidade.fonte(Identidade.FONTE_TITULO, 600, 3))
	theme.set_font_size("font_size", "BotaoLegenda", 16)
	theme.set_color("font_color", "BotaoLegenda", Color(Identidade.CREME, 0.8))
	theme.set_color("font_hover_color", "BotaoLegenda", Identidade.OURO)
	theme.set_color("font_pressed_color", "BotaoLegenda", Color("fff4d6"))
	theme.set_color("font_hover_pressed_color", "BotaoLegenda", Color("fff4d6"))
	theme.set_color("font_outline_color", "BotaoLegenda", Color(0, 0, 0, 0.7))
	theme.set_constant("outline_size", "BotaoLegenda", 6)
	# SAIR nos modais comuns (variação antiga, mantida para o resto da interface).
	theme.set_type_variation("BotaoNegativo", "Button")
	_button_styles(theme, "BotaoNegativo", {
		"normal": [Color(0.165, 0.09, 0.071, 0.92), Color(Identidade.TERRACOTA, 0.55), 1],
		"hover": [Color(0.227, 0.114, 0.082), Identidade.TERRACOTA, 1],
		"pressed": [Color(0.353, 0.165, 0.11), Identidade.TERRACOTA, 1],
		"hover_pressed": [Color(0.353, 0.165, 0.11), Identidade.TERRACOTA, 1],
		"disabled": [Color(0.09, 0.063, 0.055, 0.7), Color(Identidade.TERRACOTA, 0.25), 1],
		"focus": [Color(0, 0, 0, 0), Color("f4c2ad"), 2],
	})
	theme.set_color("font_color", "BotaoNegativo", Color("f2d3c6"))
	theme.set_color("font_hover_color", "BotaoNegativo", Color.WHITE)
	theme.set_color("font_focus_color", "BotaoNegativo", Color.WHITE)
	theme.set_color("font_pressed_color", "BotaoNegativo", Color("fbe3d8"))
	theme.set_color("font_hover_pressed_color", "BotaoNegativo", Color("fbe3d8"))
	# Botão de ícone dos cabeçalhos (casa, ×): borda fina, foco discreto.
	theme.set_type_variation("BotaoIcone", "Button")
	_button_styles(theme, "BotaoIcone", {
		"normal": [LACA_NORMAL, Color(0.706, 0.604, 0.376, 0.6), 1],
		"hover": [LACA_HOVER, Identidade.OURO, 1],
		"pressed": [LACA_PRESSED, Identidade.OURO, 1],
		"hover_pressed": [LACA_PRESSED, Identidade.OURO, 1],
		"focus": [Color(0, 0, 0, 0), Color(0.89, 0.77, 0.50, 0.9), 1],
	})
	# Em ícone (×, lápis, disquete) o foco por fora da borda virava um contorno duplo.
	(theme.get_stylebox("focus", "BotaoIcone") as StyleBoxFlat).set_expand_margin_all(0)
	theme.set_type_variation("BotaoAjuda", "Button")
	_button_styles(theme, "BotaoAjuda", {
		"normal": [LACA_NORMAL, BORDA_SUAVE, 1],
		"hover": [LACA_PRESSED, Identidade.OURO, 1],
		"pressed": [Color(0.38, 0.32, 0.18), Identidade.OURO, 1],
		"focus": [Color(0, 0, 0, 0), Color("f5e3b3"), 2],
	})
	for state in ["normal", "hover", "pressed", "focus"]:
		var round_box := theme.get_stylebox(state, "BotaoAjuda") as StyleBoxFlat
		round_box.set_corner_radius_all(12)
		round_box.corner_detail = 8
		round_box.content_margin_left = 0
		round_box.content_margin_right = 0
		round_box.content_margin_top = 0
		round_box.content_margin_bottom = 0
	theme.set_color("font_color", "BotaoAjuda", Color("e2c47f"))
	# Volumes: trilha clara com borda dourada (o limite da barra aparece sobre o fundo
	# escuro) e a parte preenchida em ouro.
	theme.set_stylebox("slider", "HSlider", _trilha(Color(0.30, 0.35, 0.31), Color(0.71, 0.60, 0.38, 0.7)))
	theme.set_stylebox("grabber_area", "HSlider", _trilha(Color("b99a58"), Color("b99a58")))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _trilha(Color("e2c47f"), Color("e2c47f")))
	return theme


## Cartela dos modais e caixas: a talha SVG compartilhada com a entrada.
static func estilo_painel() -> StyleBoxTexture:
	return Identidade.estilo_moldura()


static func _trilha(fundo: Color, borda: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fundo
	box.border_color = borda
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box


## Estados de um tipo de botão: estado → [fundo, borda, espessura da borda]. O canto
## chanfrado (corner_detail 1) é a assinatura das caixas da identidade; `brilho_foco`
## acende uma aura dourada em volta do estado de foco.
static func _button_styles(theme: Theme, type_name: String, states: Dictionary, margem_h := 12, margem_v := 6, brilho_foco := false) -> void:
	for state: String in states:
		var box := StyleBoxFlat.new()
		box.bg_color = states[state][0]
		box.border_color = states[state][1]
		box.set_border_width_all(states[state][2])
		box.set_corner_radius_all(6)
		box.corner_detail = 1
		box.content_margin_left = margem_h
		box.content_margin_right = margem_h
		box.content_margin_top = margem_v
		box.content_margin_bottom = margem_v
		box.draw_center = state != "focus"
		if state == "focus":
			box.expand_margin_left = 2
			box.expand_margin_right = 2
			box.expand_margin_top = 2
			box.expand_margin_bottom = 2
			if brilho_foco:
				box.shadow_color = Color(states[state][1], 0.22)
				box.shadow_size = 10
		theme.set_stylebox(state, type_name, box)
