extends Control
## Balão de fala em tela, com tamanho fixo na interface (não encolhe com a distância),
## fundo claro, nome em cima e a ponta apontando para a cabeça de quem fala.
## A posição é escolhida a cada quadro entre cinco lugares em volta da cabeça (acima,
## acima à direita/esquerda, ao lado direito/esquerdo): ganha o que menos cobre quem
## fala, o jogador e os painéis do HUD. Uma folga (histerese) evita que o balão pule
## de um lado para o outro. Some quando quem fala sai da câmera ou fica longe demais.

const LARGURA_MAX := 270.0
const ALCANCE := 45.0
const MARGEM := 12.0
## Espaço livre no pé da tela (aviso do HUD).
const RODAPE := 110.0
## Distância entre o balão e a cabeça (onde cabe a ponta).
const FOLGA := 16.0
const PONTA := 12.0
## Painéis fixos do HUD que o balão evita: bloco do título (esquerda), relógio (centro)
## e coluna de botões (direita, medida a partir da borda).
const HUD_TITULO := Rect2(0, 0, 395, 215)
const HUD_RELOGIO := Rect2(-90, 0, 180, 118)
const HUD_COLUNA := 110.0
const PAPEL := Color("f3ead3")
const TINTA := Color("2b2a22")
const OURO := Color("b49a60")

var alvo: Node3D
var altura := 2.0
var _painel: PanelContainer
var _nome: Label
var _texto: Label
var _ponta: Control
var _escolha := 0
var _cabeca_tela := Vector2.ZERO


func configurar(novo_alvo: Node3D, nova_altura: float, nome: String) -> void:
	alvo = novo_alvo
	altura = nova_altura
	_nome.text = nome


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_ponta = Control.new()
	_ponta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ponta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ponta.draw.connect(_desenhar_ponta)
	add_child(_ponta)
	_painel = PanelContainer.new()
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = PAPEL
	estilo.border_color = OURO
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(10)
	estilo.content_margin_left = 12
	estilo.content_margin_right = 12
	estilo.content_margin_top = 6
	estilo.content_margin_bottom = 8
	estilo.shadow_color = Color(0, 0, 0, 0.22)
	estilo.shadow_size = 3
	_painel.add_theme_stylebox_override("panel", estilo)
	add_child(_painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 1)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_child(coluna)
	_nome = Label.new()
	_nome.add_theme_font_size_override("font_size", 12)
	_nome.add_theme_color_override("font_color", Color("8a6a2c"))
	coluna.add_child(_nome)
	_texto = Label.new()
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.add_theme_font_size_override("font_size", 14)
	_texto.add_theme_color_override("font_color", TINTA)
	coluna.add_child(_texto)


func mostrar(texto: String) -> void:
	_texto.text = texto
	var fonte := _texto.get_theme_font("font")
	var largura := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 2.0
	_texto.custom_minimum_size.x = minf(largura, LARGURA_MAX)
	_painel.reset_size()
	visible = texto != ""
	_escolha = 0
	_posicionar()


func esconder() -> void:
	visible = false


func _process(_delta: float) -> void:
	if visible:
		_posicionar()


func _posicionar() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or alvo == null:
		return
	var cabeca := alvo.global_position + Vector3(0, altura, 0)
	var longe := camera.global_position.distance_to(cabeca) > ALCANCE
	var atras := camera.is_position_behind(cabeca)
	_painel.visible = not (longe or atras)
	_ponta.visible = _painel.visible
	if not _painel.visible:
		return
	var tela := get_viewport().get_visible_rect().size
	# O rótulo com quebra só sabe a própria altura depois de ter largura: encolhe o
	# painel ao mínimo atual a cada quadro para não herdar uma altura errada.
	_painel.reset_size()
	var tamanho := _painel.size
	_cabeca_tela = camera.unproject_position(cabeca)
	var falante := _retangulo_do_corpo(camera, alvo, altura)
	var jogador := Rect2()
	var no_jogador := get_tree().get_first_node_in_group("map_player") as Node3D
	if no_jogador != null and no_jogador != alvo:
		jogador = _retangulo_do_corpo(camera, no_jogador, 1.8)
	var hud: Array[Rect2] = [
		HUD_TITULO,
		Rect2(tela.x * 0.5 + HUD_RELOGIO.position.x, 0, HUD_RELOGIO.size.x, HUD_RELOGIO.size.y),
		Rect2(tela.x - HUD_COLUNA, 0, HUD_COLUNA, tela.y),
	]
	var candidatos := _candidatos(tamanho, falante)
	var notas: Array[float] = []
	for indice in range(candidatos.size()):
		var caixa := _dentro_da_tela(Rect2(candidatos[indice], tamanho), tela)
		var nota := _cobertura(caixa, falante) * 3.0 + _cobertura(caixa, jogador) * 2.5
		for painel in hud:
			nota += _cobertura(caixa, painel) * 2.0
		# Deslocado pela borda da tela, o balão se afasta da cabeça: pesa um pouco.
		nota += caixa.position.distance_to(candidatos[indice]) * 4.0 + indice * 30.0
		notas.append(nota)
	var melhor := notas.find(notas.min())
	# Histerese: só troca de lugar se o novo for bem melhor que o atual.
	if _escolha >= notas.size() or notas[melhor] < notas[_escolha] * 0.75 - 40.0:
		_escolha = melhor
	_painel.position = _dentro_da_tela(Rect2(candidatos[_escolha], tamanho), tela).position
	_ponta.queue_redraw()


## Lugares do balão (canto superior esquerdo) em volta da cabeça, em ordem de preferência.
func _candidatos(tamanho: Vector2, falante: Rect2) -> Array[Vector2]:
	var c := _cabeca_tela
	return [
		Vector2(c.x - tamanho.x * 0.5, c.y - tamanho.y - FOLGA),
		Vector2(c.x + 18.0, c.y - tamanho.y - FOLGA),
		Vector2(c.x - tamanho.x - 18.0, c.y - tamanho.y - FOLGA),
		Vector2(falante.end.x + FOLGA, c.y - tamanho.y * 0.5),
		Vector2(falante.position.x - tamanho.x - FOLGA, c.y - tamanho.y * 0.5),
	]


func _dentro_da_tela(caixa: Rect2, tela: Vector2) -> Rect2:
	caixa.position.x = clampf(caixa.position.x, MARGEM, tela.x - caixa.size.x - MARGEM)
	caixa.position.y = clampf(caixa.position.y, MARGEM, tela.y - caixa.size.y - RODAPE)
	return caixa


## Área (px²) de `caixa` que cobre `outro`.
func _cobertura(caixa: Rect2, outro: Rect2) -> float:
	if outro.size == Vector2.ZERO:
		return 0.0
	var corte := caixa.intersection(outro)
	return corte.get_area()


## Retângulo em tela do corpo de alguém (da cabeça aos pés, largura ~ 45% da altura).
func _retangulo_do_corpo(camera: Camera3D, corpo: Node3D, alto: float) -> Rect2:
	var pes := corpo.global_position
	var topo := pes + Vector3(0, alto, 0)
	if camera.is_position_behind(pes) or camera.is_position_behind(topo):
		return Rect2()
	var p_topo := camera.unproject_position(topo)
	var p_pes := camera.unproject_position(pes)
	var altura_tela := absf(p_pes.y - p_topo.y)
	var largura := maxf(30.0, altura_tela * 0.45)
	return Rect2(p_topo.x - largura * 0.5, minf(p_topo.y, p_pes.y), largura, maxf(altura_tela, 30.0))


## Ponta do balão: sai da borda mais perto da cabeça de quem fala e aponta para ela.
func _desenhar_ponta() -> void:
	var caixa := Rect2(_painel.position, _painel.size)
	var alvo_ponta := _cabeca_tela
	var base := Vector2(clampf(alvo_ponta.x, caixa.position.x + 16.0, caixa.end.x - 16.0), clampf(alvo_ponta.y, caixa.position.y + 12.0, caixa.end.y - 12.0))
	var lado := Vector2.ZERO
	if alvo_ponta.y > caixa.end.y:
		base.y = caixa.end.y - 1.0
		lado = Vector2(1, 0)
	elif alvo_ponta.y < caixa.position.y:
		base.y = caixa.position.y + 1.0
		lado = Vector2(1, 0)
	elif alvo_ponta.x > caixa.end.x:
		base.x = caixa.end.x - 1.0
		lado = Vector2(0, 1)
	elif alvo_ponta.x < caixa.position.x:
		base.x = caixa.position.x + 1.0
		lado = Vector2(0, 1)
	else:
		return
	var direcao := (alvo_ponta - base).normalized()
	var bico := base + direcao * minf(PONTA, base.distance_to(alvo_ponta))
	var a := base - lado * 8.0
	var b := base + lado * 8.0
	_ponta.draw_colored_polygon(PackedVector2Array([a, b, bico]), PAPEL)
	_ponta.draw_polyline(PackedVector2Array([a, bico, b]), OURO, 2.0, true)
