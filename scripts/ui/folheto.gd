extends CanvasLayer
## O FOLHETO DE CORDEL aberto na tela.
##
## Uso:
##     await Folheto.ler("peso_falso")
##
## Antes o verso do cordel saía pela caixa de diálogo, uma linha por vez, com o
## jogador apertando E seis vezes para ler uma estrofe de seis. Isso errava por
## dois motivos. O primeiro é de leitura: verso cortado em balão perde a
## ESTROFE, que é a unidade do cordel — a sextilha só rima para quem a vê
## inteira. O segundo é de mundo: balão é gente falando, e cordel ninguém fala,
## se lê. Quem acha um folheto para o que está fazendo e abre o papel.
##
## Então o papel abre, e ocupa a tela como um menu ocupa. Fica pendurado no
## BARBANTE, que é de onde vem o nome da coisa: na feira os folhetos ficavam
## presos numa corda esticada entre dois postes, e o comprador escolhia o seu
## de lá.
##
## Duas páginas, como no folheto de verdade: a CAPA à esquerda, com o título em
## caixa alta em cima e a xilogravura embaixo — a desenhada para aquele folheto,
## ou o bloco de sempre enquanto ela não vem (`CapaDeCordel`); os VERSOS à
## direita, a estrofe de uma vez só. No pé da capa vai o que sempre vinha
## impresso embaixo — de quem é o folheto e quanto ele vale.
##
## NA TELA DO VALE, EM ALTA. O folheto veio do 2D desenhado para 640x360, e no
## vale (1280x720) abria pequeno no canto. Agora é medido na tela do vale, com
## as letras da Crônica do Recôncavo (`Identidade`): o título em Cinzel, o verso
## em Cormorant, a nota em Cormorant itálico — em papel de folheto, que é papel.

signal fechou

const CapaDeCordel = preload("res://scripts/prototipo_3d/capa_de_cordel.gd")
const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")

## A tela do vale. O `canvas_items` escala daqui para a janela.
const TELA := Vector2(1280, 720)
## Onde o papel fica: o folheto aberto na proporção do de verdade — duas páginas
## de 11 por 16 cm lado a lado —, com faixa em cima para o barbante e uma nesga
## embaixo para as teclas.
const PAPEL_EM := Rect2(220, 84, 840, 584)
const MARGEM := 30.0          ## do corte do papel até a mancha de tipo
const FENDA := 22.0           ## folga de cada lado da dobra do meio
## A capa desenhada tem a proporção do folheto (2 por 3).
const CAPA_PROPORCAO := 2.0 / 3.0
## O título cabe em duas linhas de Cinzel em cima da capa.
const ALTURA_DO_TITULO := 90.0

const COR_FUNDO := Color(0.05, 0.04, 0.03, 0.84)
const COR_PAPEL := Color(0.88, 0.82, 0.63)
const COR_PAPEL_SUJO := Color(0.82, 0.75, 0.56)
const COR_VINCO := Color(0.74, 0.66, 0.48)
const COR_SOMBRA := Color(0.04, 0.03, 0.02, 0.55)
const COR_TINTA := Color(0.15, 0.12, 0.09)
const COR_TINTA_FRACA := Color(0.38, 0.32, 0.25)
const COR_BARBANTE := Color(0.66, 0.56, 0.38)
const COR_PRENDEDOR := Color(0.55, 0.40, 0.24)

var aberto: bool = false

var _id: String = ""
var _tabua: Control
var _titulo: Label
var _capa: TextureRect
var _autor: Label
var _versos: Label
var _nota: Label
var _preco: Label
var _teclas: Label
## Quadro a partir do qual a tecla vale. O mesmo E que catou o folheto do chão
## chega aqui no mesmo quadro, e sem esta carência o papel abria e fechava no
## mesmo aperto.
var _aceita_a_partir_de: int = 0


func _ready() -> void:
	# Acima das outras telas: dá para abrir o folheto de dentro da coleção, e
	# nesse caso ele tem que cobrir a lista, não sumir atrás dela.
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	visible = false


## Abre o folheto e espera o jogador fechar. É esta que o mundo chama quando o
## cordel é catado — achar cordel sem poder ler seria só um item a mais.
func ler(id: String) -> void:
	abrir(id)
	if aberto:
		await fechou


func abrir(id: String = "") -> void:
	if aberto or id == "":
		return
	var dado := Colecao.dados("cordeis", id)
	if dado.is_empty():
		push_warning("Folheto desconhecido: %s" % id)
		return
	_id = id
	aberto = true
	visible = true
	Relogio.pausado = true
	_aceita_a_partir_de = Engine.get_process_frames() + 2
	_preencher(dado)
	_tabua.queue_redraw()


func fechar() -> void:
	if not aberto:
		return
	aberto = false
	visible = false
	if not Dialogo.ativo:
		Relogio.pausado = false
	fechou.emit()


func _unhandled_input(evento: InputEvent) -> void:
	if not aberto or Engine.get_process_frames() < _aceita_a_partir_de:
		return

	var fecha := evento.is_action_pressed("interagir") or evento.is_action_pressed("cancelar")
	if evento is InputEventMouseButton:
		var botao: InputEventMouseButton = evento
		fecha = fecha or (botao.pressed and botao.button_index == MOUSE_BUTTON_LEFT)
	if not fecha:
		return

	Audio.efeito("menu_confirma")
	fechar()
	get_viewport().set_input_as_handled()


# --- montagem -----------------------------------------------------------------

func _montar() -> void:
	var fundo := ColorRect.new()
	fundo.color = COR_FUNDO
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fundo)

	_tabua = Control.new()
	_tabua.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_tabua.offset_left = -TELA.x * 0.5
	_tabua.offset_right = TELA.x * 0.5
	_tabua.offset_top = -TELA.y * 0.5
	_tabua.offset_bottom = TELA.y * 0.5
	# O barbante atravessa a janela; papel, sombra e texto são os limites úteis.
	_tabua.set_meta("limites_interface", Rect2(220, 55, 849, 624))
	_tabua.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tabua.draw.connect(_desenhar)
	add_child(_tabua)
	Tela.vincular_componente(_tabua, "folheto", Vector2(0.5, 0.5))

	var capa := _pagina(true)
	var direita := _pagina(false)

	# CAPA: o título em caixa alta no alto — que é como o folheto se anuncia
	# para quem passa na corda — e a xilogravura embaixo dele.
	_titulo = _rotulo(Identidade.fonte(Identidade.FONTE_TITULO, 700, 1), 26, COR_TINTA, HORIZONTAL_ALIGNMENT_CENTER)
	_titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_titulo.position = capa.position
	_titulo.size = Vector2(capa.size.x, ALTURA_DO_TITULO)
	_tabua.add_child(_titulo)

	_capa = TextureRect.new()
	_capa.name = "Capa"
	_capa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_capa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa.position = _capa_em().position
	_capa.size = _capa_em().size
	_tabua.add_child(_capa)

	_autor = _rotulo(Identidade.fonte(Identidade.FONTE_ITALICO, 500), 19, COR_TINTA_FRACA, HORIZONTAL_ALIGNMENT_CENTER)
	_autor.position = Vector2(capa.position.x, capa.end.y - 50.0)
	_autor.size = Vector2(capa.size.x, 24)
	_tabua.add_child(_autor)

	_preco = _rotulo(Identidade.fonte(Identidade.FONTE_TEXTO, 600), 17, COR_TINTA_FRACA, HORIZONTAL_ALIGNMENT_CENTER)
	_preco.position = Vector2(capa.position.x, capa.end.y - 26.0)
	_preco.size = Vector2(capa.size.x, 22)
	_tabua.add_child(_preco)

	# VERSOS: a estrofe inteira de uma vez, que é o ponto desta tela.
	_versos = _rotulo(Identidade.fonte(Identidade.FONTE_TEXTO, 600), 26, COR_TINTA, HORIZONTAL_ALIGNMENT_LEFT)
	_versos.add_theme_constant_override("line_spacing", 6)
	_versos.position = Vector2(direita.position.x + 6.0, direita.position.y + 22.0)
	_versos.size = Vector2(direita.size.x - 6.0, 300)
	_tabua.add_child(_versos)

	# A nota fica no pé da segunda página, no corpo miúdo em que se imprimia o
	# que não era verso: de onde vem a história e o que ela esconde.
	_nota = _rotulo(Identidade.fonte(Identidade.FONTE_ITALICO, 500), 19, COR_TINTA_FRACA, HORIZONTAL_ALIGNMENT_LEFT)
	_nota.add_theme_constant_override("line_spacing", 2)
	_nota.position = Vector2(direita.position.x + 6.0, direita.end.y - 196.0)
	_nota.size = Vector2(direita.size.x - 6.0, 156)
	_tabua.add_child(_nota)

	# As teclas no pé da segunda página, nas letras de ação da Crônica, em tinta.
	_teclas = _rotulo(Identidade.fonte(Identidade.FONTE_TITULO, 600, 1), 14, COR_TINTA_FRACA, HORIZONTAL_ALIGNMENT_RIGHT)
	_teclas.position = Vector2(direita.position.x, direita.end.y - 26.0)
	_teclas.size = Vector2(direita.size.x, 22)
	_tabua.add_child(_teclas)


## A mancha de tipo de cada página: metade do papel, menos margem e fenda.
func _pagina(esquerda: bool) -> Rect2:
	var meio := PAPEL_EM.position.x + PAPEL_EM.size.x * 0.5
	var largura := PAPEL_EM.size.x * 0.5 - MARGEM - FENDA
	var x := PAPEL_EM.position.x + MARGEM if esquerda else meio + FENDA
	return Rect2(x, PAPEL_EM.position.y + MARGEM, largura, PAPEL_EM.size.y - MARGEM * 2.0)


## Onde a xilogravura é impressa: na proporção da capa, entre o título e o pé.
func _capa_em() -> Rect2:
	var capa := _pagina(true)
	var alto := capa.size.y - ALTURA_DO_TITULO - 70.0
	var largo := minf(capa.size.x, alto * CAPA_PROPORCAO)
	alto = largo / CAPA_PROPORCAO
	return Rect2(capa.position.x + (capa.size.x - largo) * 0.5, capa.position.y + ALTURA_DO_TITULO + 6.0, largo, alto)


func _rotulo(fonte: Font, tamanho: int, cor: Color, alinhamento: int) -> Label:
	var etiqueta := Label.new()
	etiqueta.add_theme_font_override("font", fonte)
	etiqueta.add_theme_font_size_override("font_size", tamanho)
	etiqueta.add_theme_color_override("font_color", cor)
	etiqueta.horizontal_alignment = alinhamento
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return etiqueta


func _preencher(dado: Dictionary) -> void:
	_titulo.text = str(dado.get("titulo", _id)).to_upper()
	_capa.texture = CapaDeCordel.textura(_id)
	# Folheto sem assinatura se anuncia assim mesmo; com autor, leva o "por".
	var autor := str(dado.get("autor", ""))
	_autor.text = autor if autor.begins_with("folheto") else tr("por %s") % autor
	_preco.text = tr("%d réis na feira") % int(dado.get("valor", 0))

	var estrofe := ""
	for verso in dado.get("versos", []):
		estrofe += "%s\n" % Jogo.texto(str(verso))
	_versos.text = estrofe.strip_edges()

	# Folheto inventado não precisa de etiqueta dizendo que é inventado: a
	# assinatura já diz ("folheto sem assinatura"), e a nota de vários deles
	# repete isso com as palavras dela. Carimbar por cima era dizer duas vezes.
	_nota.text = Jogo.texto(str(dado.get("nota", "")))
	# O L continua valendo com o papel aberto: `Telas` troca uma tela pela
	# outra, então daqui se cai direto na estante. É onde o jogador descobre
	# que o folheto não se perde depois de lido.
	_teclas.text = tr("[%s] guardar  ·  [%s] coleção") % [Atalhos.letra("interagir"), Atalhos.letra("almanaque")]


# --- desenho ------------------------------------------------------------------

func _desenhar() -> void:
	_barbante()

	_tabua.draw_rect(Rect2(PAPEL_EM.position + Vector2(9, 11), PAPEL_EM.size), COR_SOMBRA)
	_tabua.draw_rect(PAPEL_EM, COR_PAPEL)
	_manchas()
	_dobra()

	# A moldura de tipo: dois filetes, um grosso e um fino. É o enfeite mais
	# comum da capa de folheto, e o que separa a mancha do corte do papel.
	var moldura := PAPEL_EM.grow(-14.0)
	_tabua.draw_rect(moldura, COR_TINTA, false, 3.0)
	_tabua.draw_rect(moldura.grow(-7.0), COR_TINTA_FRACA, false, 1.5)

	# Um filete fino em volta da xilogravura, que é onde o bloco encostou.
	_tabua.draw_rect(_capa_em().grow(3.0), COR_TINTA, false, 2.0)

	# Filete separando o verso da nota, só na segunda página.
	var direita := _pagina(false)
	var risco := _nota.position.y - 12.0
	_tabua.draw_line(Vector2(direita.position.x, risco),
		Vector2(direita.end.x, risco), COR_TINTA_FRACA, 1.5)


## O barbante da feira, esticado de ponta a ponta, com o papel preso nele.
func _barbante() -> void:
	var altura := PAPEL_EM.position.y + 3.0
	var pontos := PackedVector2Array()
	for i in 65:
		var t := float(i) / 64.0
		# Corda esticada ainda barriga no meio, e é a barriga que diz que é
		# corda e não um risco.
		pontos.append(Vector2(t * TELA.x, altura - 28.0 + sin(t * PI) * 24.0))
	_tabua.draw_polyline(pontos, COR_BARBANTE, 2.0, true)

	for x in [PAPEL_EM.position.x + 104.0, PAPEL_EM.end.x - 104.0]:
		var t: float = float(x) / TELA.x
		var no := Vector2(float(x), altura - 28.0 + sin(t * PI) * 24.0)
		var prendedor := Rect2(no.x - 6.0, no.y - 4.0, 12.0, altura - no.y + 20.0)
		_tabua.draw_rect(prendedor, COR_PRENDEDOR)
		_tabua.draw_rect(prendedor, COR_TINTA, false, 2.0)
		_tabua.draw_line(Vector2(no.x, prendedor.position.y + 4.0), Vector2(no.x, prendedor.end.y - 3.0), COR_TINTA, 1.0)


## Papel de folheto é papel barato: fiapo, ponto escuro e tinta que vazou da
## folha de trás. As marcas nascem do ID do cordel, então cada folheto tem
## sempre as MESMAS — sujeira sorteada a cada abertura vira chuvisco.
func _manchas() -> void:
	var sorte := RandomNumberGenerator.new()
	sorte.seed = hash(_id)
	for i in 520:
		var x := PAPEL_EM.position.x + sorte.randf() * PAPEL_EM.size.x
		var y := PAPEL_EM.position.y + sorte.randf() * PAPEL_EM.size.y
		_tabua.draw_rect(Rect2(x, y, 1.5 + sorte.randf() * 3.5, 1.5), COR_PAPEL_SUJO)


## A dobra do meio, que é o que faz duas páginas de uma folha só, com os dois
## grampos que seguram o caderno.
func _dobra() -> void:
	var meio := PAPEL_EM.position.x + PAPEL_EM.size.x * 0.5
	_tabua.draw_line(Vector2(meio, PAPEL_EM.position.y + 6.0),
		Vector2(meio, PAPEL_EM.end.y - 6.0), COR_VINCO, 3.0)
	for t in [0.3, 0.7]:
		var y: float = PAPEL_EM.position.y + PAPEL_EM.size.y * float(t)
		_tabua.draw_rect(Rect2(meio - 2.5, y - 9.0, 5.0, 18.0), COR_TINTA_FRACA)
