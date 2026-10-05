extends CanvasLayer
## A NARRAÇÃO DO VALE: a voz do mundo, sem nome, por cima de tudo.
##
## No 2D a chegada à fazenda é um quadro com a narração por baixo (`Tela.narrar`,
## data/dialogos/fazenda.json, "chegada_na_fazenda") — "a voz do mundo, sem nome,
## como a da travessia e a da vista do mirante". A da travessia, no vale, mora na
## abertura e anda com a voz gravada de cada trecho; esta é a do meio do jogo, sem
## voz: o escuro sobe, as frases entram uma de cada vez, cada uma o tempo de ser
## lida, e o escuro desce.
##
## Segura o jogo enquanto fala (`tocando`), como a caixa de fala: quem chama
## espera `terminou`. A tecla de interagir (E de fábrica, a do AJUSTAR), o
## espaço e o Enter passam a frase — quem já leu não espera o relógio dela.

const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")

signal terminou
## O escuro cobriu a tela: quem chama pode mudar o mundo por trás dele.
signal escureceu

const FUNDO := Color(0.03, 0.025, 0.02)
const LETRA := Color(0.95, 0.91, 0.82)
const FONTE := "res://assets/fonts/CormorantGaramond-Variavel.ttf"
const ENTRA := 0.9
const SAI := 1.1
## Quanto cada frase fica, por letra, e o mínimo; e o respiro entre elas.
const POR_LETRA := 0.055
const MINIMO := 3.2
const RESPIRO := 0.5

var _fundo: ColorRect
var _frase: Label
var _tocando := false
var _pular := false


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fundo = ColorRect.new()
	_fundo.name = "Escuro"
	_fundo.color = Color(FUNDO, 0.0)
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fundo)
	_fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frase = Label.new()
	_frase.name = "Frase"
	_frase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_frase.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_frase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_frase.add_theme_font_size_override("font_size", 30)
	_frase.add_theme_color_override("font_color", LETRA)
	if ResourceLoader.exists(FONTE):
		_frase.add_theme_font_override("font", load(FONTE))
	_frase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo.add_child(_frase)
	_frase.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frase.offset_left = 160
	_frase.offset_right = -160
	_frase.modulate.a = 0.0
	_fundo.visible = false


## Passa a frase da vez (a tecla de interagir, o espaço, o Enter; e o portão).
func pular() -> void:
	if _tocando:
		_pular = true


func _unhandled_input(evento: InputEvent) -> void:
	if not _tocando or not (evento is InputEventKey):
		return
	var tecla := evento as InputEventKey
	if not tecla.pressed or tecla.echo:
		return
	var codigo := tecla.physical_keycode
	if codigo == Atalhos.tecla("interagir") or codigo in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		pular()


## Está narrando agora?
func tocando() -> bool:
	return _tocando


## A frase na tela agora (para o portão).
func frase() -> String:
	return _frase.text if _frase != null else ""


## Quanto tempo uma frase fica, pelo tamanho dela.
static func duracao(texto: String) -> float:
	return maxf(MINIMO, texto.length() * POR_LETRA)


## Narra as frases, uma de cada vez, e emite `terminou`.
func narrar(frases: Array) -> void:
	if _tocando:
		return
	_tocando = true
	_fundo.visible = true
	var escuro := create_tween()
	escuro.tween_property(_fundo, "color:a", 1.0, ENTRA)
	await escuro.finished
	escureceu.emit()
	for bruta in frases:
		var texto := str(bruta)
		_pular = false
		_frase.text = texto
		var entra := create_tween()
		entra.tween_property(_frase, "modulate:a", 1.0, 0.6)
		await entra.finished
		var ate := Time.get_ticks_msec() + int(duracao(texto) * 1000.0)
		while Time.get_ticks_msec() < ate and not _pular:
			await get_tree().process_frame
		var sai := create_tween()
		sai.tween_property(_frase, "modulate:a", 0.0, 0.25 if _pular else 0.5)
		if not _pular:
			sai.tween_interval(RESPIRO)
		await sai.finished
	_frase.text = ""
	var clareia := create_tween()
	clareia.tween_property(_fundo, "color:a", 0.0, SAI)
	await clareia.finished
	_fundo.visible = false
	_tocando = false
	terminou.emit()
