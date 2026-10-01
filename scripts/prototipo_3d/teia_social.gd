extends CanvasLayer
## A TEIA SOCIAL do vale (tecla P): quem mora aqui e o quanto cada um gosta de você.
##
## O SISTEMA JÁ ESTAVA AQUI. `Afinidade` é autoload compartilhado com o jogo 2D:
## os sete moradores, os cinco graus com os nomes que uma pessoa do Recôncavo de
## 1887 usaria, quanto rende uma conversa, um presente e um favor, o teto e o
## piso, e o gosto de cada um lido do `aldeoes.json`. Nada disso foi reescrito —
## o portão `tests/fe.gd` já confere aquele arquivo.
##
## O que faltava era a tela. Sem ela, a afinidade era um número que subia sem
## ninguém ver, e o jogador não tinha como saber de quem se aproximar.
##
##
## O QUE ELA MOSTRA, E O QUE ELA ESCONDE DE PROPÓSITO
##
## O GOSTO SÓ APARECE DE "GENTE BOA" PARA CIMA, e essa regra é do 2D, com a
## razão escrita lá: saber o que alguém gosta de ganhar é coisa que se descobre
## convivendo, e mostrar tudo no primeiro dia transformaria o arraial numa lista
## de compras. Abaixo disso a tela diz o que fazer para descobrir, e não o que
## está escondido.
##
## E O QUE HÁ PARA FAZER HOJE é dito como TAREFA, não como estado — também do
## 2D: "ainda dá para conversar hoje" é um convite para fechar a tela e ir até
## lá; "você já conversou" é só informação.
##
##
## A FORMA
##
## Índice e página, como o almanaque, o painel e a teia de talentos: os sete
## moradores à esquerda, com o grau de cada um numa linha; a página do escolhido
## à direita. Quatro telas com a mesma forma é o jogador aprendendo a ler uma
## vez.
##
## A BARRINHA DO GRAU está na linha do morador, e não só na página, porque a
## pergunta que se faz ao abrir esta tela é comparativa: de quem eu estou mais
## perto? Isso se responde de relance, com sete barras lado a lado.

signal abriu
signal fechou

const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")

const COR_FUNDO := Color(0.055, 0.082, 0.070, 0.985)
const COR_TEXTO := Identidade.TEXTO
const COR_APAGADA := Color(0.55, 0.58, 0.52)
const COR_BOM := Color("9fd89a")
const COR_RUIM := Identidade.TERRACOTA

const TAMANHO := Vector2(900, 560)
const LARGURA_DA_COLUNA := 280.0
const ALTURA_DA_LINHA := 46.0
## O RETRATO DE CADA UM, como no 2D: o mesmo boneco que anda no mapa, de frente
## e parado. A folha tem quatro colunas e quatro linhas, e o quadro de frente
## parado é o primeiro — é a conta do `arraial_tela.gd` de lá. Os arquivos vieram
## do 2D enquanto não houver arte própria do 3D; quem não tiver fica com a
## moldura vazia e o nome, que é melhor do que a tela não abrir.
const PASTA_DOS_RETRATOS := "res://assets/sprites/moradores/"
const LADO_DO_RETRATO := 34.0
const RECUO_DO_RETRATO := 8.0
const QUADROS_DA_FOLHA := 4
## Onde o nome começa quando há retrato, para não sair por cima dele.
const MARGEM_SIMPLES := 14
const MARGEM_COM_RETRATO := int(RECUO_DO_RETRATO + LADO_DO_RETRATO + 10.0)
## A barra do grau tinha 4 px e passava batida. A do 2D é um medidor que se lê
## de relance; esta engrossa e ganha moldura.
const ALTURA_DA_BARRA := 8.0
## O lado do ícone de presente na página.
const LADO_DO_MIMO := 30.0
## Grau a partir do qual o gosto do morador aparece. Dois é "Gente boa" — a
## mesma régua do 2D, e a razão está no cabeçalho.
const GRAU_DO_GOSTO := 2

var aberta := false

var _caixa: PanelContainer
var _caminho: Label
var _coluna: VBoxContainer
var _pagina: VBoxContainer
var _rodape: Label

var _quem := ""


func _ready() -> void:
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	visible = false
	Afinidade.mudou.connect(func(_morador: String) -> void: if aberta: _encher())


func _montar() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0.02, 0.03, 0.03, 0.72)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fundo)

	_caixa = PanelContainer.new()
	_caixa.name = "Caixa"
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_FUNDO
	estilo.border_color = Color(Identidade.OURO.r, Identidade.OURO.g, Identidade.OURO.b, 0.55)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(4)
	estilo.set_content_margin_all(26)
	_caixa.add_theme_stylebox_override("panel", estilo)
	_caixa.set_anchors_preset(Control.PRESET_CENTER)
	_caixa.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caixa.grow_vertical = Control.GROW_DIRECTION_BOTH
	_caixa.custom_minimum_size = TAMANHO
	_caixa.offset_left = -TAMANHO.x * 0.5
	_caixa.offset_right = TAMANHO.x * 0.5
	_caixa.offset_top = -TAMANHO.y * 0.5
	_caixa.offset_bottom = TAMANHO.y * 0.5
	add_child(_caixa)
	Identidade.emoldurar(_caixa)

	var coluna_geral := VBoxContainer.new()
	coluna_geral.add_theme_constant_override("separation", 12)
	_caixa.add_child(coluna_geral)

	_caminho = Label.new()
	_caminho.name = "Caminho"
	_caminho.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 500, 2))
	_caminho.add_theme_font_size_override("font_size", 19)
	_caminho.add_theme_color_override("font_color", Identidade.OURO)
	Identidade.sombra_texto(_caminho)
	coluna_geral.add_child(_caminho)
	coluna_geral.add_child(Identidade.divisor())

	var lado_a_lado := HBoxContainer.new()
	lado_a_lado.add_theme_constant_override("separation", 22)
	lado_a_lado.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna_geral.add_child(lado_a_lado)

	var rolagem := ScrollContainer.new()
	rolagem.custom_minimum_size = Vector2(LARGURA_DA_COLUNA, 0)
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lado_a_lado.add_child(rolagem)
	_coluna = VBoxContainer.new()
	_coluna.name = "Moradores"
	_coluna.add_theme_constant_override("separation", 2)
	_coluna.custom_minimum_size = Vector2(LARGURA_DA_COLUNA - 14.0, 0)
	rolagem.add_child(_coluna)

	lado_a_lado.add_child(VSeparator.new())

	var rolagem_pagina := ScrollContainer.new()
	rolagem_pagina.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem_pagina.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem_pagina.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lado_a_lado.add_child(rolagem_pagina)
	_pagina = VBoxContainer.new()
	_pagina.name = "Pagina"
	_pagina.add_theme_constant_override("separation", 6)
	_pagina.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem_pagina.add_child(_pagina)

	_rodape = Label.new()
	_rodape.name = "Rodape"
	_rodape.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 400))
	_rodape.add_theme_font_size_override("font_size", 14)
	_rodape.add_theme_color_override("font_color", COR_APAGADA)
	coluna_geral.add_child(_rodape)


func abrir() -> void:
	if aberta:
		return
	if _quem == "" or not Afinidade.MORADORES.has(_quem):
		_quem = str(Afinidade.MORADORES[0])
	aberta = true
	visible = true
	_encher()
	abriu.emit()


func fechar() -> void:
	if not aberta:
		return
	aberta = false
	visible = false
	fechou.emit()


func _encher() -> void:
	_caminho.text = "O arraial  ›  %s" % _nome_de(_quem)
	_montar_coluna()
	_montar_pagina()
	_rodape.text = "↑↓ ou W/S: andar    ·    %s ou Esc: fechar" \
		% OS.get_keycode_string(Atalhos.tecla("arraial"))


func _nome_de(id: String) -> String:
	# O `Afinidade` já sabe o nome de cada um, lido do mesmo arquivo da fala.
	# Perguntar a ele em vez de reler o JSON aqui é não ter duas leituras do
	# mesmo dado.
	return str(Afinidade.nome_de(id))


func _montar_coluna() -> void:
	# TIRA DA ÁRVORE ANTES DE LIBERAR, e não é preciosismo.
	#
	# `queue_free` ADIA: o nó sai no fim do quadro. Redesenhando a coluna, a
	# barra nova nasce enquanto a velha ainda está lá com o mesmo nome, e o
	# Godot renomeia a nova para "". Quem procurar a barra do
	# Benedito pelo nome não acha — foi assim que o portão desta tela reprovou.
	#
	# `remove_child` tira na hora e o nome fica livre.
	for filho in _coluna.get_children():
		_coluna.remove_child(filho)
		filho.queue_free()
	for bruto in Afinidade.MORADORES:
		var id := str(bruto)
		var escolhido: bool = id == _quem
		var linha := Button.new()
		linha.focus_mode = Control.FOCUS_NONE
		linha.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		linha.custom_minimum_size = Vector2(0, ALTURA_DA_LINHA)
		linha.alignment = HORIZONTAL_ALIGNMENT_LEFT
		linha.text = "%s\n%s" % [_nome_de(id), Afinidade.nome_do_grau(id)]
		linha.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 500))
		linha.add_theme_font_size_override("font_size", 16)
		linha.add_theme_color_override("font_color",
			Identidade.CREME if escolhido else COR_TEXTO)
		linha.add_theme_color_override("font_hover_color", Identidade.CREME)
		for estado in ["normal", "hover", "pressed"]:
			linha.add_theme_stylebox_override(estado,
				_estilo_da_linha(escolhido, estado != "normal",
					ResourceLoader.exists(PASTA_DOS_RETRATOS + id + ".png")))
		linha.pressed.connect(func() -> void:
			_quem = id
			_encher())
		var cara := _retrato_de(id)
		if cara != null:
			linha.add_child(cara)
		_coluna.add_child(linha)

		# A BARRINHA DO GRAU, na linha e não só na página: a pergunta que se faz
		# ao abrir esta tela é comparativa — de quem eu estou mais perto? —, e
		# isso se responde de relance com sete barras lado a lado.
		var barra := ProgressBar.new()
		barra.name = "Barra_" + id
		barra.show_percentage = false
		barra.custom_minimum_size = Vector2(0, ALTURA_DA_BARRA)
		barra.max_value = float(Afinidade.MAXIMO)
		barra.value = float(Afinidade.de(id))
		var fundo := StyleBoxFlat.new()
		fundo.bg_color = Color(0.13, 0.16, 0.12, 0.9)
		fundo.border_color = Color(0.32, 0.35, 0.30, 0.9)
		fundo.set_border_width_all(1)
		fundo.set_corner_radius_all(2)
		var cheio := StyleBoxFlat.new()
		cheio.bg_color = Identidade.OURO
		cheio.set_corner_radius_all(2)
		barra.add_theme_stylebox_override("background", fundo)
		barra.add_theme_stylebox_override("fill", cheio)
		_coluna.add_child(barra)


## O estilo da linha. `com_retrato` recua o nome para ele não sair por cima do
## boneco — o retrato mora DENTRO do botão, e a margem é quem decide onde o
## texto começa.
func _estilo_da_linha(escolhida: bool, realce: bool, com_retrato: bool = false) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	if escolhida:
		estilo.bg_color = Color(0.19, 0.21, 0.15, 0.96)
		estilo.border_color = Color(Identidade.OURO.r, Identidade.OURO.g, Identidade.OURO.b, 0.75)
		estilo.border_width_left = 2
	elif realce:
		estilo.bg_color = Color(0.13, 0.16, 0.12, 0.9)
	else:
		estilo.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	estilo.content_margin_left = MARGEM_COM_RETRATO if com_retrato else MARGEM_SIMPLES
	estilo.content_margin_right = MARGEM_SIMPLES
	estilo.content_margin_top = 4
	estilo.content_margin_bottom = 4
	return estilo


func _montar_pagina() -> void:
	for filho in _pagina.get_children():
		filho.queue_free()
	if _quem == "":
		_pagina.add_child(_corpo("Escolha alguém à esquerda."))
		return

	var nome := Label.new()
	nome.text = _nome_de(_quem)
	nome.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600, 1))
	nome.add_theme_font_size_override("font_size", 26)
	nome.add_theme_color_override("font_color", Identidade.CREME)
	Identidade.sombra_texto(nome)
	_pagina.add_child(nome)

	var grau := Label.new()
	grau.text = "%s  ·  %d de %d" % [Afinidade.nome_do_grau(_quem),
		Afinidade.de(_quem), Afinidade.MAXIMO]
	grau.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_ITALICO, 400))
	grau.add_theme_font_size_override("font_size", 18)
	grau.add_theme_color_override("font_color", Identidade.OURO)
	_pagina.add_child(grau)

	var filete := Identidade.filete_centrado(1.0)
	filete.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pagina.add_child(filete)

	var falta := Afinidade.falta_para_o_proximo(_quem)
	if falta > 0:
		_pagina.add_child(_corpo("Falta %d para o próximo grau." % falta))
	else:
		_pagina.add_child(_corpo("Não há mais grau depois deste."))

	# O QUE HÁ PARA FAZER HOJE, dito como TAREFA e não como estado — é do 2D:
	# "ainda dá para conversar hoje" é convite para fechar a tela e ir até lá;
	# "você já conversou" é só informação.
	_pagina.add_child(_corpo("· Ainda dá para conversar hoje." if Afinidade.pode_conversar(_quem)
		else "· Já conversaram hoje."))
	_pagina.add_child(_corpo("· Ainda dá para dar alguma coisa hoje." if Afinidade.pode_presentear(_quem)
		else "· Já ganhou alguma coisa hoje."))

	# O GOSTO SÓ DE "GENTE BOA" PARA CIMA. A razão é do 2D e está no cabeçalho:
	# o que alguém gosta de ganhar se descobre convivendo, e mostrar tudo no
	# primeiro dia transformaria o arraial numa lista de compras.
	var respiro := Control.new()
	respiro.custom_minimum_size = Vector2(0, 8)
	_pagina.add_child(respiro)
	if Afinidade.grau(_quem) >= GRAU_DO_GOSTO:
		var dele: Dictionary = Jogo.dados(Afinidade.ARQUIVO_DOS_MORADORES).get(_quem, {})
		# EM DESENHO, E NÃO SÓ EM NOME. O 2D escreve a lista; aqui ela vira
		# fileira de ícones, com o nome no tooltip e o nome escrito abaixo para
		# quem lê devagar. São os mesmos desenhos da mochila, então o que o
		# jogador vê aqui é o que ele vai procurar lá.
		var bons: Array = dele.get("gosta", [])
		if not bons.is_empty():
			var titulo_bom := _corpo("Gosta de ganhar:")
			titulo_bom.add_theme_color_override("font_color", COR_BOM)
			_pagina.add_child(titulo_bom)
			_pagina.add_child(_fileira_de_mimos(bons, COR_BOM))
			var nomes_bons := _corpo(_nomes_dos_itens(bons) + ".")
			nomes_bons.add_theme_color_override("font_color", COR_BOM)
			nomes_bons.add_theme_font_size_override("font_size", 15)
			_pagina.add_child(nomes_bons)
		var ruins: Array = dele.get("desgosta", [])
		if not ruins.is_empty():
			var titulo_ruim := _corpo("Não aceita:")
			titulo_ruim.add_theme_color_override("font_color", COR_RUIM)
			_pagina.add_child(titulo_ruim)
			_pagina.add_child(_fileira_de_mimos(ruins, COR_RUIM))
			var nomes_ruins := _corpo(_nomes_dos_itens(ruins) + ".")
			nomes_ruins.add_theme_color_override("font_color", COR_RUIM)
			nomes_ruins.add_theme_font_size_override("font_size", 15)
			_pagina.add_child(nomes_ruins)
	else:
		_pagina.add_child(_corpo("Converse e apareça mais para saber do que ele gosta."))

	# A FÉ DE CADA UM, que é onde esta tela encontra a do talento: migrar de fé
	# tem preço social, e o preço é aqui (ver `Afinidade`, "o preço social de
	# migrar"). Só aparece quando já há convivência: fé é assunto de quem se
	# conhece.
	if Afinidade.grau(_quem) >= GRAU_DO_GOSTO:
		var fe_dele := str(Afinidade.fe_de(_quem))
		if fe_dele != "":
			_pagina.add_child(_corpo("É de %s." % Fe.nome(fe_dele)))


## O retrato do morador, ou null quando não há folha para ele.
##
## A folha é uma grade de quadros; o de frente parado é o primeiro, e é o que o
## 2D usa nesta mesma lista. Recorta-se com AtlasTexture em vez de desenhar a
## folha inteira — sem o recorte apareceriam os dezesseis quadros espremidos.
func _retrato_de(id: String) -> TextureRect:
	var caminho := PASTA_DOS_RETRATOS + id + ".png"
	if not ResourceLoader.exists(caminho):
		return null
	var folha: Texture2D = load(caminho)
	if folha == null:
		return null
	var quadro := AtlasTexture.new()
	quadro.atlas = folha
	quadro.region = Rect2(Vector2.ZERO,
		Vector2(folha.get_width() / float(QUADROS_DA_FOLHA),
			folha.get_height() / float(QUADROS_DA_FOLHA)))
	var moldura := TextureRect.new()
	moldura.name = "Retrato_" + id
	moldura.texture = quadro
	moldura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	moldura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	moldura.custom_minimum_size = Vector2(LADO_DO_RETRATO, LADO_DO_RETRATO)
	moldura.size = Vector2(LADO_DO_RETRATO, LADO_DO_RETRATO)
	moldura.position = Vector2(RECUO_DO_RETRATO, (ALTURA_DA_LINHA - LADO_DO_RETRATO) * 0.5)
	# O clique é da linha inteira: retrato que engole clique é meia linha morta.
	moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return moldura


## A FILEIRA DE ÍCONES DOS PRESENTES, que é o que faltava desta tela.
##
## O 2D escreve os nomes; aqui eles viram desenho, com o nome no `tooltip`. A
## razão é a mesma que vale para o menu do Esc: ícone se acha de relance, e o
## jogador abre esta tela justamente para decidir o que levar a quem. Os
## desenhos são os mesmos da mochila (`assets/sprites/itens`), então o que ele
## vê aqui é o que ele vai procurar lá.
##
## Item sem desenho entra como nome, para a fileira nunca ficar com buraco mudo.
func _fileira_de_mimos(itens: Array, cor: Color) -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	for bruto in itens:
		var item := str(bruto)
		var caminho := "res://assets/sprites/itens/%s.png" % item
		var nome := str(Catalogo.nome(item))
		if not ResourceLoader.exists(caminho):
			var escrito := Label.new()
			escrito.text = nome
			escrito.add_theme_font_size_override("font_size", 15)
			escrito.add_theme_color_override("font_color", cor)
			fila.add_child(escrito)
			continue
		var quadro := TextureRect.new()
		quadro.name = "Mimo_" + item
		quadro.texture = load(caminho)
		quadro.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		quadro.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		quadro.custom_minimum_size = Vector2(LADO_DO_MIMO, LADO_DO_MIMO)
		quadro.tooltip_text = nome
		quadro.modulate = cor
		fila.add_child(quadro)
	return fila


func _nomes_dos_itens(itens: Array) -> String:
	var nomes: Array[String] = []
	for item in itens:
		nomes.append(str(Catalogo.nome(str(item))).to_lower())
	return ", ".join(nomes)


func _corpo(texto: String) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 400))
	rotulo.add_theme_font_size_override("font_size", 18)
	rotulo.add_theme_color_override("font_color", COR_TEXTO)
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return rotulo


func _andar(passo: int) -> void:
	var todos: Array = Afinidade.MORADORES
	if todos.is_empty():
		return
	var onde := todos.find(_quem)
	_quem = str(todos[wrapi(onde + passo, 0, todos.size())])
	_encher()


func _unhandled_key_input(event: InputEvent) -> void:
	if not aberta:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_UP, KEY_W, KEY_LEFT, KEY_A:
			_andar(-1)
		KEY_DOWN, KEY_S, KEY_RIGHT, KEY_D:
			_andar(1)
		_:
			return
	get_viewport().set_input_as_handled()
