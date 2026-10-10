extends CanvasLayer
## O AVISO DA PRIMEIRA VEZ: um cartão no meio da tela que diz onde as coisas
## ficam guardadas — e, no cordel, o que é um cordel.
##
## "Ao pegar o primeiro cordel no jogo, deve aparecer um pop-up informando que
## eles ficam localizados no almanaque. O mesmo vale para a primeira interação
## com árvore. No caso dos cordéis, nesse pop-up deve contextualizar o que é um
## cordel, partindo do princípio que somente a gente do Nordeste conhece, mas as
## pessoas de fora não."
##
## Uso:
##     await aviso.mostrar("cordel", capa)   # os textos de data/avisos.json
##
## É INSTRUÇÃO DO JOGO, e segura o jogo como a caixa de fala: avisa ao abrir
## (`abriu`) e ao fechar (`fechou`), e o vale para atrás dele — e o relógio com
## ele (`prototype._ao_abrir_a_fala`, "o relógio deve parar quando o jogador
## estiver em [...] instruções nativas do jogo"). Fecha no E, no espaço, no
## Enter, no Esc ou no clique, depois de um respiro: o E que pegou o cordel não
## pode fechar o aviso que ele mesmo abriu.
##
## O DESENHO é o da caixa de fala do vale (`dialogo_vale.gd`): o castanho
## escuro, a borda dourada, a letra clara — o título na Cinzel, o texto na
## Cormorant. Com imagem (a capa do cordel), ela vem à esquerda.

signal abriu
signal fechou

const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const TEXTOS := "res://data/avisos.json"
const FONTE_DO_TITULO := "res://assets/fonts/Cinzel-Variavel.ttf"
const FONTE_DO_TEXTO := "res://assets/fonts/CormorantGaramond-Variavel.ttf"
const FUNDO := Color(0.09, 0.07, 0.05, 0.97)
const BORDA := Color(0.79, 0.64, 0.35, 1.0)
const OURO := Color(0.85, 0.7, 0.36, 1.0)
const TINTA := Color(0.93, 0.88, 0.76, 1.0)
const APAGADA := Color(0.72, 0.64, 0.48, 1.0)
## O respiro antes de o aviso aceitar a tecla que o fecha, em segundos de relógio.
const RESPIRO := 0.6
const ENTRA := 0.35
## ACIMA DO HUD (que é a 20), na camada das telas do vale: a caixa de fala, o
## folheto e a mochila já moram na 25 (`prototype.CAMADA_DAS_TELAS`). O cartão
## nasceu na 11, e as plaquinhas de nome dos moradores, que são do HUD,
## desenhavam por cima dele — o nome de quem estava ao lado do cordel riscava o
## texto que o jogador tinha de ler.
const CAMADA := 25

var _textos: Dictionary = {}
var _aberto := false
var _aceita_depois_de := 0.0
var _raiz: Control
var _veu: ColorRect
var _cartao: PanelContainer
var _imagem: TextureRect
var _titulo: Label
var _texto: Label
var _rodape: Label
## O que está aberto agora ("cordel", "arvore"), para o portão.
var qual := ""


func _ready() -> void:
	layer = CAMADA
	process_mode = Node.PROCESS_MODE_ALWAYS
	var lido = JSON.parse_string(FileAccess.get_file_as_string(TEXTOS))
	_textos = lido if lido is Dictionary else {}
	_montar()
	_raiz.visible = false


func aberto() -> bool:
	return _aberto


## O texto do aviso aberto agora (para o portão).
func texto() -> String:
	return _texto.text if _aberto else ""


## Mostra o aviso `qual_aviso` e só devolve quando ele fecha.
func mostrar(qual_aviso: String, imagem: Texture2D = null) -> void:
	var dado: Dictionary = _textos.get(qual_aviso, {})
	if dado.is_empty() or _aberto:
		return
	qual = qual_aviso
	_aberto = true
	_titulo.text = str(IdiomaMenu.campo(dado, "titulo", "")).to_upper()
	var corpo := str(IdiomaMenu.campo(dado, "texto", ""))
	_texto.text = corpo % Atalhos.letra("almanaque") if corpo.contains("%s") else corpo
	_rodape.text = "[%s]  %s" % [Atalhos.letra("interagir"), str(IdiomaMenu.campo(_textos.get("fechar", {}), "texto", "Entendi"))]
	_imagem.texture = imagem
	_imagem.visible = imagem != null
	_raiz.visible = true
	_raiz.modulate.a = 0.0
	_aceita_depois_de = Time.get_ticks_msec() / 1000.0 + RESPIRO
	abriu.emit()
	Audio.efeito("ui_confirmar")
	var entra := create_tween()
	entra.tween_property(_raiz, "modulate:a", 1.0, ENTRA).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fechou


func fechar() -> void:
	if not _aberto:
		return
	_aberto = false
	qual = ""
	_raiz.visible = false
	fechou.emit()


func _input(evento: InputEvent) -> void:
	if not _aberto:
		return
	var pediu := false
	if evento is InputEventKey:
		var tecla := evento as InputEventKey
		pediu = tecla.pressed and not tecla.echo and tecla.physical_keycode in [
			Atalhos.tecla("interagir"), KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]
	elif evento is InputEventMouseButton:
		var botao := evento as InputEventMouseButton
		pediu = botao.pressed and botao.button_index == MOUSE_BUTTON_LEFT
	if not pediu:
		return
	# Toda tecla com o aviso aberto é dele: a que chega antes do respiro é engolida.
	get_viewport().set_input_as_handled()
	if Time.get_ticks_msec() / 1000.0 >= _aceita_depois_de:
		fechar()


func _montar() -> void:
	_raiz = Control.new()
	_raiz.name = "Aviso"
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veu = ColorRect.new()
	_veu.color = Color(0.02, 0.015, 0.01, 0.55)
	_veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_veu)
	_veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var meio := CenterContainer.new()
	meio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(meio)
	meio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cartao = PanelContainer.new()
	_cartao.name = "Cartao"
	_cartao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = FUNDO
	estilo.set_border_width_all(2)
	estilo.border_color = BORDA
	estilo.set_corner_radius_all(6)
	estilo.content_margin_left = 28.0
	estilo.content_margin_right = 28.0
	estilo.content_margin_top = 22.0
	estilo.content_margin_bottom = 18.0
	estilo.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	estilo.shadow_size = 12
	_cartao.add_theme_stylebox_override("panel", estilo)
	meio.add_child(_cartao)
	Tela.vincular_componente(_cartao, "aviso", Vector2(0.5, 0.5))
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 24)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cartao.add_child(linha)
	_imagem = TextureRect.new()
	_imagem.name = "Imagem"
	_imagem.custom_minimum_size = Vector2(170, 255)
	_imagem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_imagem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_imagem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_imagem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(_imagem)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 10)
	coluna.custom_minimum_size = Vector2(520, 0)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(coluna)
	_titulo = _rotulo(FONTE_DO_TITULO, 30, OURO)
	coluna.add_child(_titulo)
	var fio := ColorRect.new()
	fio.color = Color(BORDA, 0.55)
	fio.custom_minimum_size = Vector2(0, 2)
	fio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(fio)
	_texto = _rotulo(FONTE_DO_TEXTO, 23, TINTA)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.custom_minimum_size = Vector2(520, 0)
	coluna.add_child(_texto)
	_rodape = _rotulo(FONTE_DO_TITULO, 15, APAGADA)
	_rodape.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coluna.add_child(_rodape)


func _rotulo(fonte: String, tamanho: int, cor: Color) -> Label:
	var rotulo := Label.new()
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	if ResourceLoader.exists(fonte):
		rotulo.add_theme_font_override("font", load(fonte))
	return rotulo
