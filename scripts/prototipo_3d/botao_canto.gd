extends RefCounted
## Botão do canto superior direito (menu e HUD do vale), na identidade "Crônica do
## Recôncavo": placa de laca com canto chanfrado e borda de ouro, ícone vetorial e dica
## própria à esquerda em Cormorant itálico. A dica aparece com o mouse em cima e com o
## foco vindo do teclado (não depois de um clique).
##
## Os botões empilham na coluna pela `posicao` (0 no alto). O tamanho segue o "Tamanho
## do HUD" de AJUSTAR (`Tela.escala_hud`): LADO e ESPACO são as medidas na escala 1, e
## `reaplicar` refaz a coluna inteira na hora quando o ajuste muda.

const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")

## Placa quadrada e passo entre placas, na escala 1 (era 52 e 64 antes de 04/10/2026).
const LADO := 40.0
const ESPACO := 50.0
## Distância da coluna à borda direita e ao alto da tela (fixas, não escalam).
const MARGEM := 36.0
const TOPO := 32.0
## O ícone desenha numa grade de 24 e aparece com 16 na escala 1.
const ICONE_VISIVEL := 16.0
const FUNDO := Color(0.055, 0.09, 0.075, 0.94)
const BORDA := Color(0.788, 0.647, 0.353, 0.8)
const GRUPO := &"botoes_canto"


## Devolve [Button, Label da dica]. `lado_icone` é a grade em que o ícone desenha.
static func criar(pai: Node, posicao: int, icone: Control, lado_icone := 24.0) -> Array:
	var canto := PanelContainer.new()
	canto.anchor_left = 1.0
	canto.anchor_right = 1.0
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = FUNDO
	estilo.border_color = BORDA
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(8)
	estilo.corner_detail = 1
	estilo.shadow_color = Color(0, 0, 0, 0.35)
	estilo.shadow_size = 5
	estilo.shadow_offset = Vector2(0, 2)
	canto.add_theme_stylebox_override("panel", estilo)
	pai.add_child(canto)
	var dica := PanelContainer.new()
	dica.anchor_left = 1.0
	dica.anchor_right = 1.0
	dica.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dica.visible = false
	var estilo_dica := estilo.duplicate() as StyleBoxFlat
	estilo_dica.set_corner_radius_all(6)
	estilo_dica.shadow_size = 0
	estilo_dica.border_color = Color(Identidade.OURO, 0.45)
	estilo_dica.content_margin_left = 12
	estilo_dica.content_margin_right = 12
	estilo_dica.content_margin_top = 4
	estilo_dica.content_margin_bottom = 4
	dica.add_theme_stylebox_override("panel", estilo_dica)
	var rotulo := Label.new()
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotulo.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_ITALICO, 500))
	rotulo.add_theme_font_size_override("font_size", 18)
	rotulo.add_theme_color_override("font_color", Identidade.CREME)
	dica.add_child(rotulo)
	pai.add_child(dica)
	var botao := Button.new()
	botao.flat = true
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
	icone.size = Vector2(lado_icone, lado_icone)
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	botao.add_child(icone)
	canto.add_child(botao)
	canto.set_meta("posicao", posicao)
	canto.set_meta("dica", dica)
	canto.set_meta("botao", botao)
	canto.set_meta("icone", icone)
	canto.add_to_group(GRUPO)
	canto.set_meta("componente_interface", "atalhos")
	reaplicar(pai.get_tree())
	return [botao, rotulo]


## TELA CHEIA da coluna do canto (menu e vale usam este mesmo código): alterna tela
## cheia e janela, como o F11 (o autoload `Tela`); o ícone fica dourado em tela cheia e
## a dica ensina o atalho. Acompanha `Tela.modo_mudou`, então também muda com o F11.
## `pode` (opcional) devolve falso quando o clique deve ser ignorado (o menu, ao partir
## para o vale). Devolve [Button, Label da dica], como `criar`.
static func criar_tela_cheia(pai: Node, posicao: int, pode := Callable()) -> Array:
	var arvore := pai.get_tree()
	var tela := arvore.root.get_node_or_null("Tela")
	var icone: Control = preload("res://scripts/prototipo_3d/hud_icon.gd").new().configurar("tela_cheia")
	var partes := criar(pai, posicao, icone)
	var botao: Button = partes[0]
	var dica: Label = partes[1]
	if tela == null:
		return partes
	var atualizar := func(cheia: bool) -> void:
		icone.definir(cheia)
		dica.text = tela.dica()
	atualizar.call(tela.get("cheia"))
	tela.modo_mudou.connect(atualizar)
	botao.tree_exiting.connect(func() -> void:
		if tela.modo_mudou.is_connected(atualizar):
			tela.modo_mudou.disconnect(atualizar))
	botao.pressed.connect(func() -> void:
		if pode.is_valid() and not pode.call():
			return
		var audio := arvore.root.get_node_or_null("Audio")
		if audio:
			audio.efeito("ui_confirmar")
		tela.alternar())
	return partes


## Escala do HUD escolhida em AJUSTAR; 1 sem o autoload (testes com --script).
static func escala() -> float:
	var arvore := Engine.get_main_loop() as SceneTree
	var tela := arvore.root.get_node_or_null("Tela") if arvore else null
	if tela == null:
		return 1.0
	var fator := float(tela.get("escala_hud")) * float(tela.escala_componente("atalhos"))
	var ultima := 0
	for canto in arvore.get_nodes_in_group(GRUPO):
		ultima = maxi(ultima, int(canto.get_meta("posicao", 0)))
	var altura: float = arvore.root.get_visible_rect().size.y
	return minf(fator, maxf(0.4, (altura - TOPO - 28.0) / (ultima * ESPACO + LADO)))


## Altura ocupada por `n` botões da coluna (para quem posiciona algo logo abaixo dela).
static func fim_da_coluna(n: int) -> float:
	return TOPO + n * ESPACO * escala()


## Refaz todas as colunas abertas com a escala atual.
static func reaplicar(arvore: SceneTree) -> void:
	var e := escala()
	for canto in arvore.get_nodes_in_group(GRUPO):
		_geometria(canto as PanelContainer, e)


static func _geometria(canto: PanelContainer, e: float) -> void:
	var lado := roundf(LADO * e)
	var folga := roundf(4.0 * e)
	var topo := TOPO + int(canto.get_meta("posicao")) * roundf(ESPACO * e)
	canto.offset_right = -MARGEM
	canto.offset_left = -MARGEM - lado
	canto.offset_top = topo
	canto.offset_bottom = topo + lado
	var estilo := canto.get_theme_stylebox("panel") as StyleBoxFlat
	if estilo:
		estilo.set_content_margin_all(folga)
	var botao := canto.get_meta("botao") as Button
	var interno := lado - 2.0 * folga
	botao.custom_minimum_size = Vector2(interno, interno)
	# O ícone encolhe por escala (ele desenha na própria grade) e fica no centro.
	var icone := canto.get_meta("icone") as Control
	var visivel := ICONE_VISIVEL * e
	icone.scale = Vector2.ONE * (visivel / icone.size.x)
	icone.position = Vector2.ONE * (interno - visivel) * 0.5
	var tecla := botao.get_node_or_null("TeclaDeAtalho") as Label
	if tecla:
		tecla.scale = Vector2.ONE * e
		tecla.position = Vector2(-20 * e, 0)
	var dica := canto.get_meta("dica") as Control
	dica.offset_right = -MARGEM - lado - 10.0
	dica.offset_left = dica.offset_right
	dica.offset_top = topo + lado * 0.5 - 17.0
	dica.offset_bottom = topo + lado * 0.5 + 17.0


## Exibe a tecla de atalho sobre o ícone, sem capturar clique nem foco.
static func marcar_atalho(botao: Button, tecla: String) -> Label:
	var marca := Label.new()
	marca.name = "TeclaDeAtalho"
	marca.text = tecla
	estilizar_tecla(marca)
	marca.scale = Vector2.ONE * escala()
	marca.position = Vector2(-20 * escala(), 0)
	botao.add_child(marca)
	return marca


## Plaqueta de tecla comum aos atalhos e números da mão.
static func estilizar_tecla(marca: Label) -> void:
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color("f3e5bb")
	fundo.border_color = Color("806734")
	fundo.set_border_width_all(1)
	fundo.set_corner_radius_all(3)
	fundo.content_margin_left = 3
	fundo.content_margin_right = 3
	marca.add_theme_stylebox_override("normal", fundo)
	marca.add_theme_font_override("font", Identidade.fonte_numeros(600))
	marca.add_theme_font_size_override("font_size", 10)
	marca.add_theme_color_override("font_color", Color("1a241f"))
	marca.custom_minimum_size = Vector2(16, 14)
	marca.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marca.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
