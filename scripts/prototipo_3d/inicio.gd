extends Node
## Entrada leve: a abertura 3D só é solicitada depois da escolha do idioma.

const TelaCarregamento = preload("res://scripts/prototipo_3d/tela_carregamento.gd")
const TemaMenu = preload("res://scripts/prototipo_3d/tema_menu.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const BotaoCanto = preload("res://scripts/prototipo_3d/botao_canto.gd")
const HudIcon = preload("res://scripts/prototipo_3d/hud_icon.gd")
const ABERTURA := "res://scenes/prototipo_3d/abertura.tscn"
## Largura do modal; os textos são medidos nela menos as duas margens de 40 da moldura.
const LARGURA_PAINEL := 560.0
## Respiros do modal: título e descrição formam um bloco; os botões têm o mesmo vão
## acima e abaixo.
const RESPIRO_TITULO := 6.0
const RESPIRO_BOTOES := 24.0

var carregando := false
var _camada: CanvasLayer
var _tela: Control
var _botoes: Array[Button] = []
var _dados: Dictionary
var _titulo: Label
var _descricao: Label
var _aviso: Label
var _canto: Control
## Marcas no canto dos botões: [marca, chave do texto da dica].
var _marcas: Array = []
var _dica_sair: Label


func _ready() -> void:
	IdiomaMenu.aplicar_menu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_camada = CanvasLayer.new()
	_camada.name = "CanvasLayer"
	add_child(_camada)
	_tela = TelaCarregamento.mostrar_capa(_camada, TemaMenu.criar(), false, true)
	var sombra := ColorRect.new()
	sombra.color = Color(0, 0, 0, 0.24)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.add_child(sombra)
	_tela.move_child(_tela.get_node("Marca"), _tela.get_child_count() - 1)
	var centro := CenterContainer.new()
	centro.name = "CentroIdioma"
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.offset_top = 92.0
	_tela.add_child(centro)
	var bloco := VBoxContainer.new()
	bloco.name = "BlocoIdioma"
	bloco.add_theme_constant_override("separation", 8)
	centro.add_child(bloco)
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/selecao_idioma.json"))
	_dados = dados
	var painel := PanelContainer.new()
	painel.name = "OpcoesIdioma"
	painel.custom_minimum_size = Vector2(LARGURA_PAINEL, 0)
	painel.add_theme_stylebox_override("panel", TemaMenu.Identidade.estilo_moldura())
	bloco.add_child(painel)
	var build := Label.new()
	build.name = "IdentificacaoBuild"
	build.text = Versao.texto()
	build.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	build.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build.add_theme_font_size_override("font_size", 16)
	build.add_theme_color_override("font_color", Color("e2c170"))
	TemaMenu.Identidade.sombra_texto(build)
	bloco.add_child(build)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 0)
	coluna.alignment = BoxContainer.ALIGNMENT_CENTER
	painel.add_child(coluna)
	var titulo := Label.new()
	_titulo = titulo
	titulo.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	titulo.add_theme_font_size_override("font_size", 24)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_color_override("font_color", Color("e8c46a"))
	coluna.add_child(titulo)
	_respiro(coluna, RESPIRO_TITULO)
	var descricao := Label.new()
	_descricao = descricao
	descricao.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	descricao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	descricao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Uma linha em todos os idiomas: em 19 o inglês quebrava e a reserva de duas linhas
	# deixava um vão vazio em volta da frase.
	descricao.add_theme_font_size_override("font_size", 18)
	coluna.add_child(descricao)
	_respiro(coluna, RESPIRO_BOTOES)
	var grade := GridContainer.new()
	grade.columns = 2
	grade.add_theme_constant_override("h_separation", 12)
	grade.add_theme_constant_override("v_separation", 12)
	coluna.add_child(grade)
	_respiro(coluna, RESPIRO_BOTOES)
	for i in IdiomaMenu.LOCALES.size():
		var botao := Button.new()
		botao.name = "Idioma%d" % i
		botao.text = str(dados["opcoes"][i])
		botao.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		botao.toggle_mode = true
		botao.custom_minimum_size = Vector2(200, TemaMenu.ALTURA_BOTAO)
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botao.pressed.connect(_escolher.bind(i))
		botao.mouse_entered.connect(_previsualizar_idioma.bind(i))
		botao.focus_entered.connect(_mostrar_idioma.bind(i))
		grade.add_child(botao)
		_botoes.append(botao)
	var aviso := Label.new()
	_aviso = aviso
	aviso.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.add_theme_font_size_override("font_size", 16)
	coluna.add_child(aviso)
	_criar_sair()
	_marcar_botoes()
	_reservar_textos()
	_mostrar_idioma(IdiomaMenu.indice())
	_botoes[IdiomaMenu.indice()].grab_focus.call_deferred()


## Marcas mínimas em todos os botões, uma sobre a outra à direita: o marcador (última
## escolha salva) e o monitor (idioma do sistema, quando o jogo o tem). Douradas no idioma
## a que se referem; nos demais, verdes e apagadas. As dicas dizem o que cada uma marca.
func _marcar_botoes() -> void:
	var salva := IdiomaMenu.escolha_salva()
	var sistema := IdiomaMenu.idioma_do_sistema(OS.get_locale_language())
	for i in _botoes.size():
		var coluna := VBoxContainer.new()
		coluna.name = "Marcas"
		coluna.alignment = BoxContainer.ALIGNMENT_CENTER
		coluna.add_theme_constant_override("separation", 4)
		coluna.anchor_left = 1.0
		coluna.anchor_right = 1.0
		coluna.anchor_top = 0.5
		coluna.anchor_bottom = 0.5
		coluna.offset_left = -26.0
		coluna.offset_right = -12.0
		coluna.offset_top = -14.0
		coluna.offset_bottom = 14.0
		coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_botoes[i].add_child(coluna)
		for tipo in ["escolha", "sistema"]:
			var ativa: bool = i == (salva if tipo == "escolha" else sistema)
			var marca := Control.new()
			marca.name = "MarcaEscolha" if tipo == "escolha" else "MarcaSistema"
			marca.set_meta("ativa", ativa)
			marca.custom_minimum_size = Vector2(12, 12)
			# PASS: a dica da marca aparece e o botão continua recebendo o mouse.
			marca.mouse_filter = Control.MOUSE_FILTER_PASS if ativa else Control.MOUSE_FILTER_IGNORE
			marca.draw.connect(_desenhar_marca.bind(marca, tipo, ativa))
			coluna.add_child(marca)
			if ativa:
				_marcas.append([marca, "marca_escolha" if tipo == "escolha" else "marca_sistema"])


func _desenhar_marca(marca: Control, tipo: String, ativa: bool) -> void:
	# Discretas: informam sem disputar com o nome do idioma.
	var cor := Color(Color("e2c47f"), 0.65) if ativa else Color(0.45, 0.6, 0.5, 0.22)
	if tipo == "escolha":
		# Marcador de página: a escolha guardada.
		marca.draw_colored_polygon(PackedVector2Array([Vector2(2.5, 1), Vector2(9.5, 1), Vector2(9.5, 11), Vector2(6, 8), Vector2(2.5, 11)]), cor)
	else:
		marca.draw_rect(Rect2(1.5, 1.5, 9, 6.5), cor, false, 1.2, true)
		marca.draw_line(Vector2(6, 8), Vector2(6, 10.5), cor, 1.2, true)
		marca.draw_line(Vector2(3.5, 10.5), Vector2(8.5, 10.5), cor, 1.2, true)


## × no canto superior direito, no lugar do HOME do menu: fecha o jogo antes de escolher
## o idioma. A dica segue o idioma em prévia.
func _criar_sair() -> void:
	_canto = Control.new()
	_canto.name = "CantoIdioma"
	_canto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.add_child(_canto)
	var icone: Control = HudIcon.new().configurar("fechar")
	var partes := BotaoCanto.criar(_canto, 0, icone)
	var botao: Button = partes[0]
	botao.name = "SairIdioma"
	_dica_sair = partes[1]
	_discreto(botao)
	_dica_sair.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	botao.pressed.connect(func() -> void:
		if carregando:
			return
		Audio.efeito("ui_voltar")
		get_tree().quit())


## O × da entrada não pode disputar atenção com a escolha do idioma: sem borda e quase
## sem fundo, meio apagada. Com o mouse em cima (ou o foco), acende e a
## borda aparece no mesmo ouro da dica, junto com ela.
func _discreto(botao: Button) -> void:
	var placa := botao.get_parent() as PanelContainer
	var apagado := (placa.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	apagado.bg_color = Color(apagado.bg_color, 0.35)
	apagado.border_color = Color(apagado.border_color, 0.0)
	apagado.shadow_size = 0
	var aceso := apagado.duplicate() as StyleBoxFlat
	aceso.bg_color = Color(aceso.bg_color, 0.94)
	aceso.border_color = Color(TemaMenu.Identidade.OURO, 0.45)
	placa.add_theme_stylebox_override("panel", apagado)
	placa.modulate.a = 0.6
	var acender := func(ligado: bool) -> void:
		placa.modulate.a = 1.0 if ligado else 0.6
		placa.add_theme_stylebox_override("panel", aceso if ligado else apagado)
	botao.mouse_entered.connect(acender.bind(true))
	botao.mouse_exited.connect(func() -> void: acender.call(botao.has_focus()))
	botao.focus_entered.connect(acender.bind(true))
	botao.focus_exited.connect(acender.bind(false))


func _respiro(pai: Container, altura: float) -> void:
	var vao := Control.new()
	vao.custom_minimum_size.y = altura
	vao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(vao)


func _mostrar_idioma(indice: int) -> void:
	if carregando:
		return
	for i in _botoes.size():
		_botoes[i].set_pressed_no_signal(i == indice)
	_titulo.text = str(IdiomaMenu.campo_no_idioma(_dados, "titulo", indice))
	_descricao.text = str(IdiomaMenu.campo_no_idioma(_dados, "descricao", indice))
	_aviso.text = str(IdiomaMenu.campo_no_idioma(_dados, "aviso", indice))
	_dica_sair.text = str(IdiomaMenu.campo_no_idioma(_dados, "sair", indice))
	for marca: Array in _marcas:
		(marca[0] as Control).tooltip_text = str(IdiomaMenu.campo_no_idioma(_dados, marca[1], indice))


func _reservar_textos() -> void:
	# Mede todos os idiomas com a fonte real (inclusive o fallback chinês).
	for par in [[_titulo, "titulo"], [_descricao, "descricao"], [_aviso, "aviso"]]:
		var rotulo: Label = par[0]
		var altura := 0.0
		for i in IdiomaMenu.LOCALES.size():
			var paragrafo := TextParagraph.new()
			paragrafo.width = LARGURA_PAINEL - 80.0
			paragrafo.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
			paragrafo.add_string(str(IdiomaMenu.campo_no_idioma(_dados, par[1], i)), rotulo.get_theme_font("font"), rotulo.get_theme_font_size("font_size"))
			altura = maxf(altura, paragrafo.get_size().y)
		rotulo.custom_minimum_size.y = ceilf(altura) + 4
		rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _previsualizar_idioma(indice: int) -> void:
	if carregando:
		return
	# O destaque acompanha a prévia; Enter confirma o idioma que está sendo lido.
	_botoes[indice].grab_focus()
	_mostrar_idioma(indice)


func _escolher(indice: int) -> void:
	if carregando:
		return
	carregando = true
	for botao in _botoes:
		botao.disabled = true
	IdiomaMenu.definir(indice)
	var barra := TelaCarregamento.mostrar(_camada, TemaMenu.criar(), tr("Carregando o vale…"), Dia.INICIO_DO_DIA)
	_tela.get_node("CentroIdioma").hide()
	_canto.hide()
	# Mostra a tela traduzida antes de iniciar a montagem do cenário.
	await get_tree().create_timer(0.25).timeout
	_tela.queue_free()
	TelaCarregamento.trocar_cena(get_tree(), ABERTURA, barra)
