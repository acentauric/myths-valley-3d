extends CanvasLayer
## A CONQUISTA DA MISSÃO: toda missão cumprida escurece a tela e festeja.
##
## "Sempre que concluir uma missão, deve aparecer uma animação na tela,
## sombreando toda a tela e dando um destaque para a animação. O intuito é
## demonstrar que o jogador conquistou a conclusão daquela missão."
##
## Ouve o caderno do vale (`CadernoDoVale.concluiu`), que é por onde passa toda
## missão cumprida — os passos de cada fila, a encomenda do saveiro —, e mostra
## a última (`ultima_concluida`): a sombra sobre a tela inteira, o emblema que
## cresce girando, "Missão concluída", o nome do passo e a missão de que ele é.
## Não segura o jogo nem o mouse: dura pouco e some sozinha. Várias de uma vez
## entram em fila.

const FONTE_DO_TITULO := "res://assets/fonts/Cinzel-Variavel.ttf"
const FONTE_DO_NOME := "res://assets/fonts/CormorantGaramond-Variavel.ttf"
const OURO := Color(0.96, 0.78, 0.36)
const SOMBRA := 0.62
const ENTRA := 0.35
const FICA := 1.9
const SAI := 0.5

var _fila: Array[Dictionary] = []
var _mostrando := false
var _raiz: Control
var _sombra: ColorRect
var _emblema: Control
var _titulo: Label
var _nome: Label
var _missao: Label
## A última mostrada, para o portão perguntar.
var mostrada: Dictionary = {}


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	_raiz.visible = false
	if not CadernoDoVale.concluiu.is_connected(_ao_concluir):
		CadernoDoVale.concluiu.connect(_ao_concluir)


func _exit_tree() -> void:
	if CadernoDoVale.concluiu.is_connected(_ao_concluir):
		CadernoDoVale.concluiu.disconnect(_ao_concluir)


## Está festejando agora?
func ativa() -> bool:
	return _mostrando


func _ao_concluir(_id: String) -> void:
	_fila.append(CadernoDoVale.ultima_concluida.duplicate(true))
	if not _mostrando:
		_proxima()


func _proxima() -> void:
	if _fila.is_empty():
		_mostrando = false
		_raiz.visible = false
		return
	_mostrando = true
	mostrada = _fila.pop_front()
	var passo := str(mostrada.get("titulo", ""))
	var de_quem := str(mostrada.get("missao", ""))
	if str(mostrada.get("quem", "")) != "" and de_quem != "":
		de_quem = "%s · %s" % [de_quem, str(mostrada["quem"])]
	_titulo.text = tr("Missão concluída").to_upper()
	_nome.text = passo
	_missao.text = de_quem if de_quem != passo else ""
	_raiz.visible = true
	_sombra.color.a = 0.0
	_emblema.scale = Vector2.ONE * 0.35
	_emblema.rotation = -0.6
	for rotulo: Label in [_titulo, _nome, _missao]:
		rotulo.modulate.a = 0.0
	Audio.efeito("menu_confirma")
	var animacao := create_tween()
	animacao.set_parallel(true)
	animacao.tween_property(_sombra, "color:a", SOMBRA, ENTRA)
	animacao.tween_property(_emblema, "scale", Vector2.ONE, ENTRA + 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	animacao.tween_property(_emblema, "rotation", 0.0, ENTRA + 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for rotulo: Label in [_titulo, _nome, _missao]:
		animacao.tween_property(rotulo, "modulate:a", 1.0, ENTRA).set_delay(0.15)
	animacao.chain().tween_interval(FICA)
	animacao.chain().set_parallel(true)
	animacao.tween_property(_sombra, "color:a", 0.0, SAI)
	animacao.tween_property(_emblema, "scale", Vector2.ONE * 1.25, SAI)
	for rotulo: Label in [_titulo, _nome, _missao]:
		animacao.tween_property(rotulo, "modulate:a", 0.0, SAI)
	animacao.chain().tween_callback(_proxima)


func _process(delta: float) -> void:
	if _mostrando and _emblema != null:
		(_emblema as Emblema).giro += delta * 0.6
		_emblema.queue_redraw()


func _montar() -> void:
	_raiz = Control.new()
	_raiz.name = "Conquista"
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sombra = ColorRect.new()
	_sombra.name = "Sombra"
	_sombra.color = Color(0.02, 0.015, 0.01, 0.0)
	_sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_sombra)
	_sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var meio := CenterContainer.new()
	meio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(meio)
	meio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var coluna := VBoxContainer.new()
	coluna.alignment = BoxContainer.ALIGNMENT_CENTER
	coluna.add_theme_constant_override("separation", 10)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meio.add_child(coluna)
	var lugar_do_emblema := Control.new()
	lugar_do_emblema.custom_minimum_size = Vector2(220, 220)
	lugar_do_emblema.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coluna.add_child(lugar_do_emblema)
	_emblema = Emblema.new()
	_emblema.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_emblema.position = Vector2(110, 110)
	lugar_do_emblema.add_child(_emblema)
	_titulo = _rotulo(FONTE_DO_TITULO, 40, OURO)
	coluna.add_child(_titulo)
	_nome = _rotulo(FONTE_DO_NOME, 30, Color(0.98, 0.95, 0.88))
	coluna.add_child(_nome)
	_missao = _rotulo(FONTE_DO_NOME, 20, Color(0.85, 0.8, 0.7))
	coluna.add_child(_missao)


func _rotulo(fonte: String, tamanho: int, cor: Color) -> Label:
	var rotulo := Label.new()
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	rotulo.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02, 0.9))
	rotulo.add_theme_constant_override("outline_size", 6)
	if ResourceLoader.exists(fonte):
		rotulo.add_theme_font_override("font", load(fonte))
	return rotulo


## O EMBLEMA: um sol de raios dourados que gira devagar, com o anel e a estrela
## no meio — desenhado, sem textura, para valer nos dois estilos.
class Emblema extends Control:
	var giro := 0.0

	func _draw() -> void:
		var ouro := Color(0.96, 0.78, 0.36)
		for i in 16:
			var angulo := giro + TAU * float(i) / 16.0
			var comprido := 104.0 if i % 2 == 0 else 78.0
			var lado := Vector2.from_angle(angulo + PI * 0.5) * 7.0
			var ponta := Vector2.from_angle(angulo) * comprido
			var base := Vector2.from_angle(angulo) * 52.0
			draw_colored_polygon(PackedVector2Array([base + lado, ponta, base - lado]), Color(ouro, 0.55))
		draw_circle(Vector2.ZERO, 54.0, Color(0.14, 0.09, 0.04, 0.95))
		draw_arc(Vector2.ZERO, 54.0, 0.0, TAU, 64, ouro, 4.0, true)
		draw_arc(Vector2.ZERO, 44.0, 0.0, TAU, 64, Color(ouro, 0.6), 2.0, true)
		var estrela := PackedVector2Array()
		for i in 10:
			var raio := 30.0 if i % 2 == 0 else 12.0
			estrela.append(Vector2.from_angle(-PI * 0.5 + TAU * float(i) / 10.0) * raio)
		draw_colored_polygon(estrela, ouro)
