extends CanvasLayer
## O cartão do AMANHECER: a folha do dia que aparece entre uma noite e outra.
##
## Uso:
##     await Amanhecer.mostrar(["Feira na praça"])
##
## Existe por um defeito de TEMPO. Dormir era: piscar a tela e, quando ela já
## tinha voltado, devolver o fôlego. O jogador via o boneco de pé, andando, com
## a barra ainda no fim do dia anterior — e por alguns segundos o jogo parecia
## não ter registrado a noite. Fôlego é o relógio da fazenda (ver energia.gd);
## ver o relógio atrasado é ver o jogo errado.
##
## A correção é de ordem, não de velocidade: o fôlego e a data viram ANTES da
## tela voltar, e o cartão é o que ocupa esse tempo. Em vez de um escuro mudo,
## a virada do dia passa a dizer o que virou — que dia é hoje, que estação, que
## ano, e com quanto fôlego o corpo levantou.
##
## O campo dos LEMBRETES é o lugar onde evento de arraial vai entrar quando
## houver: festa, feira, novena, chegada de barco. Hoje não há nenhum, e o
## cartão diz isso com todas as letras em vez de esconder a linha — é assim que
## o jogador aprende que aquele canto do cartão existe e que um dia terá coisa.

const COR_FUNDO := Color(0.04, 0.03, 0.03, 1.0)
const COR_DIA := Color(0.96, 0.87, 0.58)
const COR_DATA := Color(0.80, 0.72, 0.54)
const COR_MIUDO := Color(0.62, 0.57, 0.45)
const COR_LEMBRETE := Color(0.86, 0.80, 0.62)
const COR_RISCO := Color(0.42, 0.36, 0.26)

## Quanto o cartão fica parado depois de aberto. Tempo de ler três linhas sem
## pressa — e quem não quiser esperar aperta qualquer tecla.
const ENTRADA := 0.5
const PARADO := 1.9
const SAIDA := 0.45

var aberto: bool = false

var _raiz: Control
var _dia: Label
var _data: Label
var _folego: Label
var _lembretes: Label
var _risco: Control
var _pulou: bool = false


func _ready() -> void:
	# Acima do véu da `Tela` (camada 20): o cartão é lido NO escuro, e embaixo
	# do véu ele seria coberto justamente enquanto a tela está apagada.
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	visible = false


## Mostra a folha do dia e só devolve quando ela sai de cena. Quem chama já
## deve ter virado o relógio e o fôlego — é isso que o cartão está anunciando.
func mostrar(lembretes: Array = []) -> void:
	if aberto:
		return
	aberto = true
	_pulou = false
	_preencher(lembretes)
	visible = true
	_raiz.modulate.a = 0.0

	var entra := create_tween()
	entra.tween_property(_raiz, "modulate:a", 1.0, ENTRADA)
	await entra.finished
	await _esperar(PARADO)
	var sai := create_tween()
	sai.tween_property(_raiz, "modulate:a", 0.0, SAIDA)
	await sai.finished

	visible = false
	aberto = false


func _esperar(segundos: float) -> void:
	var fim := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < fim and not _pulou:
		await get_tree().process_frame


func _unhandled_input(evento: InputEvent) -> void:
	if not aberto:
		return
	var pediu := evento.is_action_pressed("interagir") or evento.is_action_pressed("cancelar")
	if evento is InputEventMouseButton:
		var botao: InputEventMouseButton = evento
		pediu = pediu or (botao.pressed and botao.button_index == MOUSE_BUTTON_LEFT)
	if not pediu:
		return
	_pulou = true
	get_viewport().set_input_as_handled()


# --- montagem -----------------------------------------------------------------

func _montar() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	var fundo := ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(fundo)

	_dia = _rotulo(26, COR_DIA)
	_dia.position = Vector2(0, 108)
	_dia.size = Vector2(640, 40)
	_raiz.add_child(_dia)

	_data = _rotulo(13, COR_DATA)
	_data.position = Vector2(0, 150)
	_data.size = Vector2(640, 20)
	_raiz.add_child(_data)

	_folego = _rotulo(10, COR_MIUDO)
	_folego.position = Vector2(0, 172)
	_folego.size = Vector2(640, 18)
	_raiz.add_child(_folego)

	_risco = Control.new()
	_risco.set_anchors_preset(Control.PRESET_FULL_RECT)
	_risco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_risco.draw.connect(func():
		_risco.draw_line(Vector2(240, 202), Vector2(400, 202), COR_RISCO, 1.0))
	_raiz.add_child(_risco)

	_lembretes = _rotulo(11, COR_LEMBRETE)
	_lembretes.position = Vector2(120, 214)
	_lembretes.size = Vector2(400, 80)
	_lembretes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_raiz.add_child(_lembretes)


func _rotulo(tamanho: int, cor: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.add_theme_font_size_override("font_size", tamanho)
	etiqueta.add_theme_color_override("font_color", cor)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return etiqueta


func _preencher(lembretes: Array) -> void:
	_dia.text = "Dia %d" % Relogio.dia
	_data.text = "%s · Ano %d" % [Relogio.nome_estacao(), Relogio.ano]
	_folego.text = "Fôlego %d de %d" % [roundi(Energia.atual), roundi(Energia.maximo())]

	if lembretes.is_empty():
		_lembretes.text = "Nada marcado no arraial."
		_lembretes.add_theme_color_override("font_color", COR_MIUDO)
		return
	var texto := ""
	for lembrete in lembretes:
		texto += "%s\n" % str(lembrete)
	_lembretes.text = texto.strip_edges()
	_lembretes.add_theme_color_override("font_color", COR_LEMBRETE)
