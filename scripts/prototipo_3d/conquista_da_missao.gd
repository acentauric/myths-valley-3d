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
## Não segura o mouse: dura o tempo dela e some sozinha. Várias de uma vez entram
## em fila.
##
##
## MAIS SUAVE, MAIS TEMPO, E DEPOIS DA CONVERSA
##
## "A animação de missão concluída está boa, mas deve ser mais suave, quase que
## com efeito de embranquecimento e esvaimento. A transição está muito abrupta.
## Aumentar o tempo de efeito dela em tela é uma excelente solução. Caso ela
## conclua em uma interação com NPC, o efeito também só deve aparecer depois que
## terminar a interação com o NPC."
##
## Ela entrava em 0,35 s, com o emblema saltando por cima do tamanho
## (TRANS_BACK), ficava 1,9 s e saía em meio segundo: um estalo. Agora a sombra
## sobe devagar e uma luz clara se abre do meio, atrás do emblema — o
## embranquecer —; o emblema cresce sem salto e os nomes entram um depois do
## outro; tudo fica mais de três segundos; e no fim a luz clareia a tela inteira
## um pouco mais e tudo se desfaz nela — o esvair. Cada fase é uma conta só,
## numa curva suave (`_entrar`, `_esvair`).
##
## E A FESTA ESPERA A VEZ (`_pode_festejar`): o passo que fecha no E fecha
## enquanto o morador ainda responde no balão, e a festa por cima da resposta
## escondia o que ele dizia. A fala no balão, a caixa de fala, a narração e as
## telas abertas vêm antes; ela entra um respiro depois de a conversa acabar.
## Enquanto festeja, o relógio do vale fica segurado (`Dia.segurar`).

const FONTE_DO_TITULO := "res://assets/fonts/Cinzel-Variavel.ttf"
const FONTE_DO_NOME := "res://assets/fonts/CormorantGaramond-Variavel.ttf"
const OURO := Color(0.96, 0.78, 0.36)
## Quanto a sombra escurece, e quanto o véu claro cobre no auge do esvair.
const SOMBRA := 0.5
const VEU := 0.32
## Os tempos de cada fase, em segundos.
const ENTRA := 1.4
const FICA := 3.2
const SAI := 1.8
## Depois de a última conversa acabar, o respiro antes de a festa entrar.
const RESPIRO := 0.5
## O motivo com que ela segura o relógio.
const MOTIVO := "conquista"

var _fila: Array[Dictionary] = []
var _mostrando := false
var _raiz: Control
var _sombra: ColorRect
var _veu: ColorRect
var _clarao: TextureRect
var _emblema: Control
var _titulo: Label
var _nome: Label
var _missao: Label
## O tamanho da luz que a fase manda, e o respirar dela por cima.
var _clarao_escala := 1.0
var _tempo := 0.0
## Desde quando nada impede a festa (relógio de parede), ou -1.
var _livre_desde := -1
var _animacao: Tween
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
	Dia.soltar(MOTIVO)


## Está festejando agora?
func ativa() -> bool:
	return _mostrando


## Há festa esperando a vez?
func esperando() -> bool:
	return not _mostrando and not _fila.is_empty()


func _ao_concluir(_id: String) -> void:
	# Só entra na fila: quem decide a hora é o `_process`, que espera a conversa.
	_fila.append(CadernoDoVale.ultima_concluida.duplicate(true))


## NADA NA FRENTE DA FESTA: nenhuma tela parando o vale, a caixa de fala fechada,
## e ninguém segurando o relógio — a fala no balão ("fala:"), a narração, o
## aviso de instrução. A própria festa só segura quando já entrou.
func _pode_festejar() -> bool:
	if get_tree().paused:
		return false
	var dialogo := get_node_or_null("/root/Dialogo")
	if dialogo != null and bool(dialogo.call("ocupado")):
		return false
	return not Dia.segurado()


func _process(delta: float) -> void:
	if _mostrando:
		_tempo += delta
		(_emblema as Emblema).giro += delta * 0.45
		_emblema.queue_redraw()
		# A luz respira devagar enquanto a festa está na tela.
		_clarao.scale = Vector2.ONE * _clarao_escala * (1.0 + 0.025 * sin(_tempo * 2.2))
		return
	if _fila.is_empty() or not _pode_festejar():
		_livre_desde = -1
		return
	if _livre_desde < 0:
		_livre_desde = Time.get_ticks_msec()
	elif Time.get_ticks_msec() - _livre_desde >= int(RESPIRO * 1000.0):
		_livre_desde = -1
		_mostrar()


## Festeja a primeira da fila. A seguinte espera a vez de novo, no `_process`:
## entre uma festa e outra pode ter começado uma conversa.
func _mostrar() -> void:
	_mostrando = true
	Dia.segurar(MOTIVO)
	mostrada = _fila.pop_front()
	var passo := str(mostrada.get("titulo", ""))
	var de_quem := str(mostrada.get("missao", ""))
	if str(mostrada.get("quem", "")) != "" and de_quem != "":
		de_quem = "%s · %s" % [de_quem, str(mostrada["quem"])]
	_titulo.text = tr("Missão concluída").to_upper()
	_nome.text = passo
	_missao.text = de_quem if de_quem != passo else ""
	_raiz.visible = true
	_tempo = 0.0
	_entrar(0.0)
	Audio.efeito("menu_confirma")
	if _animacao != null:
		_animacao.kill()
	_animacao = create_tween()
	_animacao.tween_method(_entrar, 0.0, 1.0, ENTRA)
	_animacao.tween_interval(FICA)
	_animacao.tween_method(_esvair, 0.0, 1.0, SAI)
	_animacao.tween_callback(_terminar)


func _terminar() -> void:
	_mostrando = false
	_raiz.visible = false
	Dia.soltar(MOTIVO)


## A ENTRADA, de 0 a 1: a sombra sobe numa curva suave; a luz se abre do meio; o
## emblema cresce sem saltar e endireita; os nomes entram um depois do outro.
func _entrar(p: float) -> void:
	_sombra.color.a = SOMBRA * _suave(p)
	_veu.color.a = 0.0
	_clarao.modulate.a = 0.8 * _suave(minf(p * 1.25, 1.0))
	_clarao_escala = lerpf(0.55, 1.0, _suave(p))
	_clarao.scale = Vector2.ONE * _clarao_escala
	var do_emblema := _suave(clampf((p - 0.1) / 0.8, 0.0, 1.0))
	_emblema.modulate.a = do_emblema
	_emblema.scale = Vector2.ONE * lerpf(0.7, 1.0, do_emblema)
	_emblema.rotation = lerpf(-0.25, 0.0, do_emblema)
	var rotulos: Array[Label] = [_titulo, _nome, _missao]
	for i in rotulos.size():
		rotulos[i].modulate.a = _suave(clampf((p - 0.3 - 0.15 * i) / 0.45, 0.0, 1.0))


## O ESVAIR, de 0 a 1: primeiro a luz clareia a tela inteira (o véu claro sobe e
## o clarão cresce), e o emblema e os nomes vão se desfazendo nela; depois a
## claridade baixa junto com a sombra, e não sobra nada.
func _esvair(p: float) -> void:
	var clareia := _suave(minf(p / 0.45, 1.0))
	var apaga := _suave(clampf((p - 0.45) / 0.55, 0.0, 1.0))
	_veu.color.a = VEU * clareia * (1.0 - apaga)
	_clarao.modulate.a = lerpf(0.8, 1.0, clareia) * (1.0 - apaga)
	_clarao_escala = lerpf(1.0, 1.7, _suave(p))
	_emblema.scale = Vector2.ONE * lerpf(1.0, 1.3, _suave(p))
	_emblema.modulate.a = 1.0 - _suave(minf(p / 0.75, 1.0))
	for rotulo: Label in [_titulo, _nome, _missao]:
		rotulo.modulate.a = 1.0 - _suave(minf(p / 0.6, 1.0))
	_sombra.color.a = SOMBRA * (1.0 - _suave(p))


## A curva suave de 0 a 1 (smoothstep): começa e acaba sem tranco.
static func _suave(x: float) -> float:
	var t := clampf(x, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


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
	# O VÉU CLARO, que só aparece no esvair: a tela inteira embranquece um pouco.
	_veu = ColorRect.new()
	_veu.name = "Veu"
	_veu.color = Color(1.0, 0.97, 0.9, 0.0)
	_veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_veu)
	_veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# O CLARÃO atrás do emblema: uma luz morna, redonda, que se soma à tela.
	var gradiente := Gradient.new()
	gradiente.set_color(0, Color(1.0, 0.97, 0.88, 0.9))
	gradiente.set_color(1, Color(1.0, 0.92, 0.75, 0.0))
	gradiente.add_point(0.4, Color(1.0, 0.94, 0.8, 0.45))
	var textura := GradientTexture2D.new()
	textura.gradient = gradiente
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.0, 0.5)
	textura.width = 256
	textura.height = 256
	_clarao = TextureRect.new()
	_clarao.name = "Clarao"
	_clarao.texture = textura
	_clarao.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_clarao.stretch_mode = TextureRect.STRETCH_SCALE
	_clarao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var somar := CanvasItemMaterial.new()
	somar.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_clarao.material = somar
	_raiz.add_child(_clarao)
	# No meio do emblema, que fica no alto da coluna (220 do emblema mais os três
	# nomes, uns 370 ao todo): 75 acima do meio da tela.
	_clarao.set_anchors_preset(Control.PRESET_CENTER)
	_clarao.offset_left = -460.0
	_clarao.offset_right = 460.0
	_clarao.offset_top = -535.0
	_clarao.offset_bottom = 385.0
	_clarao.pivot_offset = Vector2(460.0, 460.0)
	_clarao.modulate.a = 0.0
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
