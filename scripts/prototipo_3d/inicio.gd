extends Node
## Entrada leve: a abertura 3D só é solicitada depois da escolha do idioma.

const TelaCarregamento = preload("res://scripts/prototipo_3d/tela_carregamento.gd")
const TemaMenu = preload("res://scripts/prototipo_3d/tema_menu.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const ABERTURA := "res://scenes/prototipo_3d/abertura.tscn"

var carregando := false
var _camada: CanvasLayer
var _tela: Control
var _botoes: Array[Button] = []


func _ready() -> void:
	IdiomaMenu.aplicar_menu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_camada = CanvasLayer.new()
	_camada.name = "CanvasLayer"
	add_child(_camada)
	_tela = TelaCarregamento.mostrar_capa(_camada, TemaMenu.criar())
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/selecao_idioma.json"))
	var painel := PanelContainer.new()
	painel.name = "OpcoesIdioma"
	painel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	painel.offset_left = 54
	painel.offset_top = -385
	painel.offset_right = 614
	painel.offset_bottom = -40
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.035, 0.055, 0.045, 0.92)
	estilo.border_color = Color("b89c60")
	estilo.set_border_width_all(1)
	estilo.set_content_margin_all(22)
	painel.add_theme_stylebox_override("panel", estilo)
	_tela.add_child(painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 12)
	painel.add_child(coluna)
	var titulo := Label.new()
	titulo.text = str(dados["titulo"])
	titulo.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	titulo.add_theme_font_size_override("font_size", 24)
	titulo.add_theme_color_override("font_color", Color("e8c46a"))
	coluna.add_child(titulo)
	var descricao := Label.new()
	descricao.text = str(IdiomaMenu.campo(dados, "descricao"))
	descricao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(descricao)
	var grade := GridContainer.new()
	grade.columns = 2
	grade.add_theme_constant_override("h_separation", 12)
	grade.add_theme_constant_override("v_separation", 12)
	coluna.add_child(grade)
	for i in IdiomaMenu.LOCALES.size():
		var botao := Button.new()
		botao.name = "Idioma%d" % i
		botao.text = str(dados["opcoes"][i])
		botao.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		botao.custom_minimum_size = Vector2(230, 52)
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botao.pressed.connect(_escolher.bind(i))
		grade.add_child(botao)
		_botoes.append(botao)
	var aviso := Label.new()
	aviso.text = str(IdiomaMenu.campo(dados, "aviso"))
	if IdiomaMenu.indice() != 3:
		aviso.text = str(dados["nota_zh"]) + "\n" + aviso.text
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.add_theme_font_size_override("font_size", 16)
	coluna.add_child(aviso)
	_botoes[IdiomaMenu.indice()].grab_focus.call_deferred()


func _escolher(indice: int) -> void:
	if carregando:
		return
	carregando = true
	for botao in _botoes:
		botao.disabled = true
	IdiomaMenu.definir(indice)
	var barra := TelaCarregamento.mostrar(_camada, TemaMenu.criar(), tr("Carregando o vale…"), Dia.INICIO_DO_DIA)
	_tela.get_node("OpcoesIdioma").hide()
	# Mostra a tela traduzida antes de iniciar a montagem do cenário.
	await get_tree().create_timer(0.25).timeout
	_tela.queue_free()
	TelaCarregamento.trocar_cena(get_tree(), ABERTURA, barra)
