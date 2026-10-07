extends CanvasLayer
## A TELA DE CONTROLES: as teclas do vale, e cada atalho trocável ali mesmo.
##
## "Quando abri MENU > Controles, ele travou o jogo. Esse caminho deve ser igual
## aos outros jogos, permitindo que o jogador edite suas preferências de teclas
## como uma tela de MENU e não como pop-up."
##
## Era o painelzinho do canto do HUD, só de leitura, aberto pelo menu do Esc — e
## o menu fechava por fora do dono das telas, deixando o vale parado atrás de
## nada. Agora é tela como as outras: registrada no `telas_do_vale.gd`, para o
## vale pausar e voltar num lugar só, e com o Esc devolvendo ao menu de onde se
## veio, que é o que todo jogo faz com a tela de controles.
##
## O QUE SE TROCA AQUI é o que o AJUSTAR já trocava: os atalhos de letra da
## tabela `Atalhos` — mesma regra, mesmo arquivo (`user://controles.cfg`), mesma
## troca entre duas ações quando a letra já tem dono. A diferença é o gesto: em
## vez de rolar uma lista de letras, clica-se na tecla e aperta-se a nova, como
## nos outros jogos. W, A, S e D não se escolhem, porque andam e navegam as
## telas (`Atalhos.RESERVADAS`).
##
## AS TECLAS FIXAS aparecem embaixo, só para ler: andar, correr, pular, a barra
## de mão, a câmera, o menu. Tela de controles que esconde metade das teclas é
## o jogador procurando no escuro.
##
## Teclado: ↑↓ ou W/S andam, Enter ou E escolhem, Esc volta (ou desiste da
## tecla que estava esperando).

signal voltar_pedido
## Um atalho mudou de letra: quem escreve teclas na tela (o HUD) se refaz.
signal teclas_mudaram

const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const TeclasMovimento = preload("res://scripts/prototipo_3d/teclas_movimento.gd")

const TAMANHO := Vector2(760, 620)
const ALTURA_DA_LINHA := 38.0
const LARGURA_DA_TECLA := 132.0
const COR_FUNDO := Color(0.055, 0.082, 0.070, 0.985)
const COR_APAGADA := Color(0.55, 0.58, 0.52)

var aberta := false

var _lista: VBoxContainer
var _rodape: Label
var _rolagem: ScrollContainer
## Os botões de tecla, na ordem de `Atalhos.DEFINICOES`, e as ações deles.
var _teclas: Array[Button] = []
var _acoes: Array[String] = []
var _cursor := 0
## A ação que espera a tecla nova, ou "".
var _esperando := ""
var _recado := ""


func _ready() -> void:
	# Na mesma altura do menu do Esc: é um degrau dele, e cobre o HUD e o painel.
	layer = 27
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	visible = false


func _montar() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0.02, 0.03, 0.03, 0.72)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fundo)

	var caixa := PanelContainer.new()
	caixa.name = "Caixa"
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_FUNDO
	estilo.border_color = Color(Identidade.OURO.r, Identidade.OURO.g, Identidade.OURO.b, 0.55)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(4)
	estilo.set_content_margin_all(26)
	caixa.add_theme_stylebox_override("panel", estilo)
	# Ancorada no meio, com folga da borda: numa janela menor que o tamanho
	# pedido ela encolhe, e a lista rola.
	caixa.anchor_left = 0.5
	caixa.anchor_right = 0.5
	caixa.anchor_top = 0.5
	caixa.anchor_bottom = 0.5
	caixa.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caixa.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(caixa)
	Tela.vincular_componente(caixa, "controles", Vector2(0.5, 0.5))
	Identidade.emoldurar(caixa)
	_encaixar(caixa)
	caixa.get_viewport().size_changed.connect(_encaixar.bind(caixa))

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 10)
	caixa.add_child(coluna)

	var titulo := Label.new()
	titulo.name = "Titulo"
	titulo.text = tr("Controles")
	titulo.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 500, 2))
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.add_theme_color_override("font_color", Identidade.OURO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Identidade.sombra_texto(titulo)
	coluna.add_child(titulo)
	coluna.add_child(Identidade.divisor())

	_rolagem = ScrollContainer.new()
	_rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	coluna.add_child(_rolagem)
	_lista = VBoxContainer.new()
	_lista.name = "Linhas"
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 2)
	_rolagem.add_child(_lista)

	coluna.add_child(Identidade.divisor())
	var botoes := HBoxContainer.new()
	botoes.add_theme_constant_override("separation", 12)
	botoes.alignment = BoxContainer.ALIGNMENT_CENTER
	coluna.add_child(botoes)
	var restaurar := _botao_de_baixo(tr("Restaurar padrão"))
	restaurar.name = "Restaurar"
	restaurar.pressed.connect(_restaurar_padrao)
	botoes.add_child(restaurar)
	var voltar := _botao_de_baixo(tr("Voltar"))
	voltar.name = "Voltar"
	voltar.pressed.connect(func() -> void:
		Audio.efeito("ui_voltar")
		voltar_pedido.emit())
	botoes.add_child(voltar)

	_rodape = Label.new()
	_rodape.name = "Rodape"
	_rodape.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rodape.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 400))
	_rodape.add_theme_font_size_override("font_size", 14)
	_rodape.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(_rodape)


## A caixa no tamanho pedido, ou no que couber com 24 de folga em cada borda.
func _encaixar(caixa: Control) -> void:
	var janela := caixa.get_viewport().get_visible_rect().size
	var medida := Vector2(minf(TAMANHO.x, janela.x - 48.0), minf(TAMANHO.y, janela.y - 48.0))
	caixa.offset_left = -medida.x * 0.5
	caixa.offset_right = medida.x * 0.5
	caixa.offset_top = -medida.y * 0.5
	caixa.offset_bottom = medida.y * 0.5


func _botao_de_baixo(texto: String) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.focus_mode = Control.FOCUS_NONE
	botao.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	botao.custom_minimum_size = Vector2(190, 40)
	botao.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 500))
	botao.add_theme_font_size_override("font_size", 17)
	return botao


func abrir() -> void:
	if aberta:
		return
	aberta = true
	visible = true
	_esperando = ""
	_recado = ""
	_cursor = 0
	_redesenhar()


func fechar() -> void:
	if not aberta:
		return
	aberta = false
	visible = false
	_esperando = ""


func _redesenhar() -> void:
	for filho in _lista.get_children():
		_lista.remove_child(filho)
		filho.queue_free()
	_teclas.clear()
	_acoes.clear()

	_secao(tr("Atalhos"))
	for acao: String in Atalhos.DEFINICOES:
		var letra := tr("Aperte uma letra…") if acao == _esperando else Atalhos.letra(acao)
		var botao := _linha(TranslationServer.translate(String(Atalhos.DEFINICOES[acao]["rotulo"])), letra, true)
		var indice := _teclas.size()
		botao.pressed.connect(func() -> void:
			_cursor = indice
			_esperar(acao))
		_teclas.append(botao)
		_acoes.append(acao)

	_secao(tr("Teclas fixas"))
	for par in _fixas():
		_linha(str(par[0]), str(par[1]), false)

	_cursor = clampi(_cursor, 0, maxi(0, _teclas.size() - 1))
	_pintar()
	_escrever_rodape()


## As teclas que não se trocam aqui, com o que fazem.
func _fixas() -> Array:
	return [
		[tr("Andar"), TeclasMovimento.rotulo()],
		[tr("Correr"), "Shift"],
		[tr("Pular"), tr("Espaço")],
		[tr("Item na mão"), tr("1 a 0 · rodinha")],
		[tr("Gestos"), "Alt + 1 a 8"],
		[tr("Alternar a câmera"), "Tab"],
		[tr("Aproximar e afastar"), tr("Ctrl + rodinha · + e −")],
		[tr("Andar até o ponto"), tr("Botão direito (duplo: correr)")],
		[tr("Menu"), "Esc"],
	]


func _secao(texto: String) -> void:
	var rotulo := Label.new()
	rotulo.text = texto.to_upper()
	rotulo.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 600))
	rotulo.add_theme_font_size_override("font_size", 13)
	rotulo.add_theme_color_override("font_color", Identidade.OURO)
	if _lista.get_child_count() > 0:
		var respiro := Control.new()
		respiro.custom_minimum_size = Vector2(0, 10)
		_lista.add_child(respiro)
	_lista.add_child(rotulo)


## Uma linha: o que a tecla faz à esquerda, a tecla à direita. Na trocável a
## tecla é botão; na fixa, texto. Devolve o botão, ou null.
func _linha(oque: String, tecla: String, trocavel: bool) -> Button:
	var linha := HBoxContainer.new()
	linha.custom_minimum_size = Vector2(0, ALTURA_DA_LINHA)
	linha.add_theme_constant_override("separation", 12)
	_lista.add_child(linha)
	var nome := Label.new()
	nome.text = oque
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nome.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 500))
	nome.add_theme_font_size_override("font_size", 18)
	nome.add_theme_color_override("font_color", Identidade.TEXTO if trocavel else COR_APAGADA)
	linha.add_child(nome)
	if not trocavel:
		var fixa := Label.new()
		fixa.text = tecla
		fixa.custom_minimum_size = Vector2(LARGURA_DA_TECLA, 0)
		fixa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fixa.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fixa.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 500))
		fixa.add_theme_font_size_override("font_size", 16)
		fixa.add_theme_color_override("font_color", COR_APAGADA)
		linha.add_child(fixa)
		return null
	var botao := Button.new()
	botao.text = tecla
	botao.focus_mode = Control.FOCUS_NONE
	botao.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	botao.custom_minimum_size = Vector2(LARGURA_DA_TECLA, ALTURA_DA_LINHA - 4.0)
	botao.add_theme_font_override("font", Identidade.fonte_numeros(600))
	botao.add_theme_font_size_override("font_size", 17)
	botao.add_theme_color_override("font_color", Identidade.CREME)
	linha.add_child(botao)
	return botao


func _pintar() -> void:
	for i in _teclas.size():
		var estilo := StyleBoxFlat.new()
		var escolhida := i == _cursor
		var esperando := _acoes[i] == _esperando
		estilo.bg_color = Color(0.19, 0.21, 0.15, 0.96) if escolhida else Color(0.08, 0.11, 0.09, 0.9)
		estilo.border_color = Identidade.OURO if esperando else Color(Identidade.OURO.r, Identidade.OURO.g, Identidade.OURO.b, 0.75 if escolhida else 0.3)
		estilo.set_border_width_all(2 if esperando else 1)
		estilo.set_corner_radius_all(4)
		for estado in ["normal", "hover", "pressed"]:
			_teclas[i].add_theme_stylebox_override(estado, estilo)
	if _cursor >= 0 and _cursor < _teclas.size():
		_rolagem.ensure_control_visible(_teclas[_cursor])


func _escrever_rodape() -> void:
	var texto := _recado
	if texto == "":
		texto = tr("Aperte a letra nova    ·    Esc: desistir") if _esperando != "" \
			else tr("↑↓ ou W/S: andar    ·    E ou Enter: trocar a tecla    ·    Esc: voltar ao menu")
	_rodape.text = texto
	_rodape.add_theme_color_override("font_color", Identidade.CREME if _recado != "" else COR_APAGADA)


func _esperar(acao: String) -> void:
	Audio.efeito("ui_confirmar")
	_esperando = acao
	_recado = ""
	_redesenhar()


func _desistir() -> void:
	_esperando = ""
	_recado = ""
	Audio.efeito("ui_voltar")
	_redesenhar()


## A TECLA NOVA CHEGOU. Só letra de A a Z, e nenhuma das que andam; quando a
## letra já tem dono, os dois trocam (`Atalhos.definir`), e o recado diz isso
## — troca calada é o jogador achando o mapa noutra tecla sem saber por quê.
func _receber(codigo: int) -> void:
	var acao := _esperando
	if Atalhos.RESERVADAS.has(codigo):
		_recado = tr("W, A, S e D andam e navegam as telas. Escolha outra letra.")
		Audio.efeito("ui_trava")
		_escrever_rodape()
		return
	# O que a tabela aceita é a regra dela, e não um A–Z escrito aqui.
	if not Atalhos.letras_livres().has(codigo):
		_recado = tr("Só letras de A a Z. Escolha outra, ou Esc para desistir.")
		Audio.efeito("ui_trava")
		_escrever_rodape()
		return
	var dono := ""
	for outra: String in Atalhos.DEFINICOES:
		if outra != acao and Atalhos.tecla(outra) == codigo:
			dono = outra
	var antiga := Atalhos.letra(acao)
	Atalhos.definir(acao, codigo)
	Atalhos.aplicar()
	_esperando = ""
	Audio.efeito("ui_confirmar")
	var nome := TranslationServer.translate(String(Atalhos.DEFINICOES[acao]["rotulo"]))
	if dono != "":
		_recado = tr("%s agora na %s. %s passou para a %s.") % [nome, Atalhos.letra(acao),
			TranslationServer.translate(String(Atalhos.DEFINICOES[dono]["rotulo"])), antiga]
	else:
		_recado = tr("%s agora na %s.") % [nome, Atalhos.letra(acao)]
	_redesenhar()
	teclas_mudaram.emit()


## Todas as letras de fábrica de volta. Uma a uma pelo mesmo `definir`: as de
## fábrica são todas diferentes, então cada troca só mexe nas que ainda vêm.
func _restaurar_padrao() -> void:
	for acao: String in Atalhos.DEFINICOES:
		Atalhos.definir(acao, int(Atalhos.DEFINICOES[acao]["padrao"]))
	Atalhos.aplicar()
	_esperando = ""
	_recado = tr("As teclas voltaram ao padrão.")
	Audio.efeito("ui_confirmar")
	_redesenhar()
	teclas_mudaram.emit()


## Em `_input`, e não no `_unhandled_*`: esperando a tecla, ela é TODA desta
## tela — o Esc inclusive, que o dono das telas também ouve no `_input` e
## usaria para voltar ao menu. Este nó entra no vale depois do dono das telas,
## e por isso ouve antes dele.
func _input(event: InputEvent) -> void:
	if not aberta:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var codigo: int = (event as InputEventKey).physical_keycode
	if _esperando != "":
		if codigo == KEY_ESCAPE:
			_desistir()
		else:
			_receber(codigo)
		get_viewport().set_input_as_handled()
		return
	match codigo:
		KEY_UP, KEY_W:
			_andar(-1)
		KEY_DOWN, KEY_S:
			_andar(1)
		KEY_ENTER, KEY_KP_ENTER:
			_esperar(_acoes[_cursor])
		KEY_ESCAPE:
			# O dono das telas devolve ao menu (`volta` do registro).
			return
		_:
			if codigo == Atalhos.tecla("interagir") and not _acoes.is_empty():
				_esperar(_acoes[_cursor])
			else:
				return
	get_viewport().set_input_as_handled()


func _andar(passo: int) -> void:
	if _teclas.is_empty():
		return
	_cursor = wrapi(_cursor + passo, 0, _teclas.size())
	_recado = ""
	_pintar()
	_escrever_rodape()
