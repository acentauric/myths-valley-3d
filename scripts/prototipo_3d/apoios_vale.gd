extends CanvasLayer
## #64: escolha explícita; abrir não gasta carta nem habilidade.
signal fechou
signal usou(texto: String)
const Idioma = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const Tema = preload("res://scripts/prototipo_3d/tema_menu.gd")
var aberta := false
var _raiz: Control
var _lista: VBoxContainer
var _entradas: Array[Dictionary] = []
var _botoes: Array[Button] = []
var _cursor := 0
var _textos: Dictionary

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 35
	_textos = Jogo.dados("res://data/apoios_vale.json")
	_raiz = Control.new()
	_raiz.theme = Tema.criar()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_raiz)
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.7)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(fundo)
	var painel := PanelContainer.new()
	painel.add_theme_stylebox_override("panel", Tema.estilo_painel())
	painel.anchor_left = 0.22
	painel.anchor_right = 0.78
	painel.anchor_top = 0.18
	painel.anchor_bottom = 0.82
	_raiz.add_child(painel)
	var margem := MarginContainer.new()
	for lado in ["left", "top", "right", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 20)
	painel.add_child(margem)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 14)
	coluna.add_theme_font_override("font", load("res://assets/fonts/CormorantGaramond-Variavel.ttf"))
	coluna.add_theme_font_size_override("font_size", 26)
	margem.add_child(coluna)
	var titulo := Label.new()
	titulo.text = _texto("titulo")
	coluna.add_child(titulo)
	var ajuda := Label.new()
	ajuda.text = _texto("ajuda")
	ajuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(ajuda)
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(rolagem)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(_lista)
	var fechar := Button.new()
	fechar.text = _texto("fechar")
	fechar.pressed.connect(fechar_tela)
	coluna.add_child(fechar)
	_raiz.hide()

func _texto(chave: String) -> String:
	return Idioma.campo(_textos, chave)

func abrir() -> void:
	_entradas.clear()
	_botoes.clear()
	for filho in _lista.get_children():
		_lista.remove_child(filho)
		filho.queue_free()
	for id in Cartas.minhas("apoio"):
		_entradas.append({"id": str(id), "carta": true,
			"nome": Idioma.campo(Cartas.dados(str(id)), "nome"),
			"pronto": Cartas.apoio_pronto(str(id))})
	for id in Talentos.ativos():
		_entradas.append({"id": str(id), "carta": false,
			"nome": _texto("segundo_folego") if id == "segundo_folego" else str(Talentos.NOS[id].nome),
			"pronto": Talentos.ativo_pronto(str(id))})
	for i in _entradas.size():
		var entrada: Dictionary = _entradas[i]
		var botao := Button.new()
		botao.text = "%s · %s" % [entrada.nome, _texto("pronto") if entrada.pronto else _texto("usado")]
		botao.disabled = not bool(entrada.pronto)
		botao.pressed.connect(func() -> void: confirmar(i))
		_lista.add_child(botao)
		_botoes.append(botao)
	if _entradas.is_empty():
		var vazio := Label.new()
		vazio.text = _texto("vazio")
		vazio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_lista.add_child(vazio)
	_cursor = 0
	aberta = true
	_raiz.show()
	_focar(0)

func fechar_tela() -> void:
	if not aberta:
		return
	aberta = false
	_raiz.hide()
	fechou.emit()

func confirmar(indice: int) -> void:
	if not aberta or indice < 0 or indice >= _entradas.size():
		return
	var entrada: Dictionary = _entradas[indice]
	var id := str(entrada.id)
	# Reconsulta ao confirmar: uma tela antiga nunca autoriza uso repetido.
	if bool(entrada.carta):
		if not Cartas.apoio_pronto(id):
			return
		Cartas.usar_apoio(id)
	else:
		if not Talentos.ativo_pronto(id):
			return
		Talentos.acionar(id)
	fechar_tela()
	usou.emit(_texto("sucesso") % str(entrada.nome))

func _focar(passo: int) -> void:
	if _botoes.is_empty():
		return
	_cursor = posmod(_cursor + passo, _botoes.size())
	for tentativa in _botoes.size():
		if not _botoes[_cursor].disabled:
			_botoes[_cursor].grab_focus()
			return
		_cursor = posmod(_cursor + (1 if passo >= 0 else -1), _botoes.size())

func _unhandled_input(evento: InputEvent) -> void:
	if not aberta or not evento is InputEventKey or not evento.pressed or evento.echo:
		return
	var tecla: int = evento.keycode
	if tecla == KEY_UP or tecla == KEY_DOWN:
		_focar(-1 if tecla == KEY_UP else 1)
	elif tecla == Atalhos.tecla("interagir") or tecla == KEY_ENTER:
		# A seleção por mouse/foco também vale para a tecla de interação.
		for i in _botoes.size():
			if _botoes[i].has_focus():
				confirmar(i)
				break
	else:
		return
	get_viewport().set_input_as_handled()
