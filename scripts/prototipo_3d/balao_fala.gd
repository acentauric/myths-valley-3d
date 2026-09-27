extends Control
## Balão de fala em tela: fica acima da cabeça de quem fala, mas com tamanho fixo na
## interface (não encolhe com a distância), fundo claro, nome em cima e a ponta do
## balão apontando para o personagem. Some quando o personagem sai da câmera ou fica
## longe demais; se a cabeça sair pela borda, o balão encosta na borda da tela.

const LARGURA_MAX := 340.0
const ALCANCE := 45.0
const MARGEM := 14.0
## Espaço livre no pé da tela para não cobrir o painel de controles e o aviso.
const RODAPE := 150.0
## Espaço livre no alto da tela para não cobrir o relógio e o painel do objetivo.
const TOPO := 150.0
const PAPEL := Color("f3ead3")
const TINTA := Color("2b2a22")
const OURO := Color("b49a60")

var alvo: Node3D
var altura := 2.0
var _painel: PanelContainer
var _nome: Label
var _texto: Label
var _ponta: Control
var _ponta_x := 0.0


func configurar(novo_alvo: Node3D, nova_altura: float, nome: String) -> void:
	alvo = novo_alvo
	altura = nova_altura
	_nome.text = nome


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_painel = PanelContainer.new()
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = PAPEL
	estilo.border_color = OURO
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(12)
	estilo.content_margin_left = 14
	estilo.content_margin_right = 14
	estilo.content_margin_top = 8
	estilo.content_margin_bottom = 10
	estilo.shadow_color = Color(0, 0, 0, 0.25)
	estilo.shadow_size = 4
	_painel.add_theme_stylebox_override("panel", estilo)
	add_child(_painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 2)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_child(coluna)
	_nome = Label.new()
	_nome.add_theme_font_size_override("font_size", 13)
	_nome.add_theme_color_override("font_color", Color("8a6a2c"))
	coluna.add_child(_nome)
	_texto = Label.new()
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.add_theme_font_size_override("font_size", 16)
	_texto.add_theme_color_override("font_color", TINTA)
	coluna.add_child(_texto)
	_ponta = Control.new()
	_ponta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ponta.draw.connect(_desenhar_ponta)
	add_child(_ponta)


func mostrar(texto: String) -> void:
	_texto.text = texto
	var fonte := _texto.get_theme_font("font")
	var largura := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 2.0
	_texto.custom_minimum_size.x = minf(largura, LARGURA_MAX)
	_painel.reset_size()
	visible = texto != ""
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
	var ponto := camera.unproject_position(cabeca)
	# O rótulo com quebra só sabe a própria altura depois de ter largura: encolhe o
	# painel ao mínimo atual a cada quadro para não herdar uma altura errada.
	_painel.reset_size()
	var tamanho := _painel.size
	var x := clampf(ponto.x - tamanho.x * 0.5, MARGEM, tela.x - tamanho.x - MARGEM)
	var y := clampf(ponto.y - tamanho.y - 14.0, TOPO, tela.y - tamanho.y - RODAPE)
	_painel.position = Vector2(x, y)
	_ponta.position = Vector2(x, y + tamanho.y - 2.0)
	_ponta.size = Vector2(tamanho.x, 14.0)
	_ponta_x = clampf(ponto.x - x, 22.0, tamanho.x - 22.0)
	_ponta.queue_redraw()


func _desenhar_ponta() -> void:
	var pontos := PackedVector2Array([Vector2(_ponta_x - 9, 0), Vector2(_ponta_x + 9, 0), Vector2(_ponta_x, 12)])
	_ponta.draw_colored_polygon(pontos, PAPEL)
	_ponta.draw_polyline(PackedVector2Array([Vector2(_ponta_x - 9, 1), Vector2(_ponta_x, 12), Vector2(_ponta_x + 9, 1)]), OURO, 2.0, true)
