extends CanvasLayer
## O MENU DO ESC: o que estava na coluna de ícones do canto esquerdo.
##
## Aquela coluna tinha nove botões redondos — HOME, ajustes, som, relógio, mapa,
## câmera, velocidade do tempo, estilo visual e controles — empilhados na borda
## esquerda da tela, por cima do vale, o tempo todo. "Os ícones na esquerda do
## HUD podem ser todos dentro do menu ESC."
##
## Estão aqui, em linhas com nome e estado escrito. Um ícone redondo sem rótulo
## obriga a passar o mouse para descobrir o que ele faz e não diz em que estado
## está: o do som era um desenho diferente ligado e desligado, e o do relógio
## também. Em linha, "Som: ligado" responde as duas coisas de uma vez.
##
##
## O QUE ELE NÃO É
##
## Não é o painel do J. Aquele é do PERSONAGEM — missões, cartas, venda —, e o
## jogo continua existindo atrás dele. Este é do JOGO: som, tempo, câmera,
## salvar, sair. A divisão é a do gênero, e é a razão de os dois existirem.
##
## Também não substitui o AJUSTAR: ajustes é tela de configuração, com abas e
## muitos campos, e continua sendo aberta por uma linha daqui. O que mora neste
## menu é o punhado de coisas que se quer trocar no meio de uma partida.
##
##
## AS TECLAS
##
## Esc abre e fecha, ↑↓ ou W/S andam, Enter ou E confirmam. É a mesma navegação
## do almanaque e do painel, de propósito: três telas com teclas diferentes é o
## jogador tendo de lembrar qual é qual.

signal pediu(acao: String)
signal abriu
signal fechou

const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")

const COR_FUNDO := Color(0.055, 0.082, 0.070, 0.985)
const COR_TEXTO := Identidade.TEXTO
const COR_APAGADA := Color(0.55, 0.58, 0.52)
const TAMANHO := Vector2(520, 560)
const ALTURA_DA_LINHA := 40.0

## Cada linha: a ação que ela pede e o rótulo, que pode dizer o estado.
##
## O rótulo é um `Callable` e não um texto porque metade delas ALTERNA algo: o
## som, o relógio, a câmera, a velocidade e o estilo mudam de estado quando
## apertados, e linha que não mostra o estado novo é linha que mente.
var _itens: Array[Dictionary] = []
var _linhas: Array[Button] = []
var _cursor := 0
var aberto := false

var _caixa: PanelContainer
var _lista: VBoxContainer
var _rodape: Label


func _ready() -> void:
	# Acima do HUD (20) e do painel (25), abaixo da tela da queda (30): o menu do
	# jogo cobre as telas do personagem, e não o contrário.
	layer = 27
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	visible = false


func _montar() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0.02, 0.03, 0.03, 0.72)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fundo)

	_caixa = PanelContainer.new()
	_caixa.name = "Caixa"
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_FUNDO
	estilo.border_color = Color(Identidade.OURO.r, Identidade.OURO.g, Identidade.OURO.b, 0.55)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(4)
	estilo.set_content_margin_all(26)
	_caixa.add_theme_stylebox_override("panel", estilo)
	_caixa.set_anchors_preset(Control.PRESET_CENTER)
	_caixa.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caixa.grow_vertical = Control.GROW_DIRECTION_BOTH
	_caixa.custom_minimum_size = TAMANHO
	_caixa.offset_left = -TAMANHO.x * 0.5
	_caixa.offset_right = TAMANHO.x * 0.5
	_caixa.offset_top = -TAMANHO.y * 0.5
	_caixa.offset_bottom = TAMANHO.y * 0.5
	add_child(_caixa)
	Identidade.emoldurar(_caixa)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 10)
	_caixa.add_child(coluna)

	var titulo := Label.new()
	titulo.name = "Titulo"
	titulo.text = "O vale, parado"
	titulo.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 500, 2))
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", Identidade.OURO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Identidade.sombra_texto(titulo)
	coluna.add_child(titulo)
	coluna.add_child(Identidade.divisor())

	_lista = VBoxContainer.new()
	_lista.name = "Linhas"
	_lista.add_theme_constant_override("separation", 2)
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(_lista)

	_rodape = Label.new()
	_rodape.name = "Rodape"
	_rodape.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 400))
	_rodape.add_theme_font_size_override("font_size", 14)
	_rodape.add_theme_color_override("font_color", COR_APAGADA)
	_rodape.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(_rodape)


## AS LINHAS DO MENU, e é quem monta o vale que as declara.
##
## Este nó não sabe pausar o relógio nem trocar o estilo: quem sabe é o
## `Prototype`, que é o dono dessas coisas. Aqui só se desenha a linha, se lê o
## rótulo dela e se chama o que ela pede. É a mesma costura do
## `telas_do_vale.gd` — a tela não conhece a cena.
func definir(itens: Array[Dictionary]) -> void:
	_itens = itens
	_redesenhar()


func _redesenhar() -> void:
	for filho in _lista.get_children():
		filho.queue_free()
	_linhas.clear()
	for i in _itens.size():
		var item: Dictionary = _itens[i]
		var botao := Button.new()
		botao.focus_mode = Control.FOCUS_NONE
		botao.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		botao.custom_minimum_size = Vector2(0, ALTURA_DA_LINHA)
		botao.alignment = HORIZONTAL_ALIGNMENT_LEFT
		botao.text = _rotulo_de(item)
		botao.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 500))
		botao.add_theme_font_size_override("font_size", 19)
		botao.add_theme_color_override("font_color", COR_TEXTO)
		botao.add_theme_color_override("font_hover_color", Identidade.CREME)
		var indice := i
		botao.pressed.connect(func() -> void:
			_cursor = indice
			_fazer())
		_lista.add_child(botao)
		_linhas.append(botao)
	_cursor = clampi(_cursor, 0, maxi(0, _linhas.size() - 1))
	_pintar()
	_rodape.text = "↑↓ ou W/S: andar    ·    E ou Enter: escolher    ·    Esc: voltar ao vale"


func _rotulo_de(item: Dictionary) -> String:
	var rotulo = item.get("rotulo", "")
	return str(rotulo.call()) if rotulo is Callable else str(rotulo)


func _pintar() -> void:
	for i in _linhas.size():
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = Color(0.19, 0.21, 0.15, 0.96) if i == _cursor else Color(0, 0, 0, 0)
		if i == _cursor:
			estilo.border_color = Color(Identidade.OURO.r, Identidade.OURO.g, Identidade.OURO.b, 0.75)
			estilo.border_width_left = 2
		estilo.content_margin_left = 14
		estilo.content_margin_right = 14
		_linhas[i].add_theme_stylebox_override("normal", estilo)
		var realce := StyleBoxFlat.new()
		realce.bg_color = Color(0.13, 0.16, 0.12, 0.9)
		realce.content_margin_left = 14
		realce.content_margin_right = 14
		for estado in ["hover", "pressed"]:
			_linhas[i].add_theme_stylebox_override(estado, estilo if i == _cursor else realce)


func abrir() -> void:
	if aberto:
		return
	aberto = true
	visible = true
	_redesenhar()
	abriu.emit()


func fechar() -> void:
	if not aberto:
		return
	aberto = false
	visible = false
	fechou.emit()


func alternar() -> void:
	if aberto:
		fechar()
	else:
		abrir()


func _andar(passo: int) -> void:
	if _linhas.is_empty():
		return
	_cursor = wrapi(_cursor + passo, 0, _linhas.size())
	_pintar()


## Faz o que a linha do cursor pede, e REDESENHA.
##
## O redesenho é o ponto: metade das linhas alterna algo, e o rótulo delas diz o
## estado. Sem redesenhar, apertar "Som: ligado" desligaria o som e a linha
## continuaria dizendo "ligado" — o menu mentindo sobre o que ele mesmo acabou
## de fazer.
func _fazer() -> void:
	if _cursor < 0 or _cursor >= _itens.size():
		return
	var item: Dictionary = _itens[_cursor]
	var acao = item.get("fazer", null)
	if acao is Callable:
		acao.call()
	if bool(item.get("fecha", false)):
		fechar()
		return
	_redesenhar()


func _unhandled_key_input(event: InputEvent) -> void:
	if not aberto:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_UP, KEY_W:
			_andar(-1)
		KEY_DOWN, KEY_S:
			_andar(1)
		KEY_ENTER, KEY_KP_ENTER:
			_fazer()
		_:
			if event.physical_keycode == Atalhos.tecla("interagir"):
				_fazer()
			else:
				return
	get_viewport().set_input_as_handled()
