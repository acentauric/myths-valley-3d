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

const IconeRelacao = preload("res://scripts/prototipo_3d/icone_relacao.gd")
## Os corações do grau, rosados como nos jogos do gênero e não no ouro da
## moldura: ouro aqui é enfeite, e o coração é dado.
const COR_CORACAO := Color("e2857a")

const TAMANHO := Vector2(980, 620)
const LARGURA_DA_COLUNA := 330.0
const ALTURA_DA_LINHA := 56.0
## O canto direito de cada linha: corações do grau e os gestos de hoje.
const LARGURA_DOS_SINAIS := 76.0
const LADO_DO_CORACAO_PEQUENO := 13.0
const LADO_DO_CORACAO := 22.0
const LADO_DO_RETRATO_GRANDE := 88.0
## A ficha de um presente na grade da página.
const LADO_DA_FICHA := 52.0
## O RETRATO DE CADA UM, como no 2D: o mesmo boneco que anda no mapa, de frente
## e parado. A folha tem quatro colunas e quatro linhas, e o quadro de frente
## parado é o primeiro — é a conta do `arraial_tela.gd` de lá. Os arquivos vieram
## do 2D enquanto não houver arte própria do 3D; quem não tiver fica com a
## moldura vazia e o nome, que é melhor do que a tela não abrir.
const PASTA_DOS_RETRATOS := "res://assets/sprites/moradores/"
const LADO_DO_RETRATO := 40.0
const RECUO_DO_RETRATO := 8.0
const QUADROS_DA_FOLHA := 4
## Onde o nome começa quando há retrato, para não sair por cima dele.
const MARGEM_SIMPLES := 14
const MARGEM_COM_RETRATO := int(RECUO_DO_RETRATO + LADO_DO_RETRATO + 10.0)
## A barra do grau tinha 4 px e passava batida. A do 2D é um medidor que se lê
## de relance; esta engrossa e ganha moldura.
const ALTURA_DA_BARRA := 10.0
## O lado do ícone de presente na página.
const LADO_DO_MIMO := 34.0
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
		linha.add_theme_font_size_override("font_size", 15)
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
		var cara := _retrato_de(id, LADO_DO_RETRATO)
		if cara != null:
			cara.position = Vector2(RECUO_DO_RETRATO, (ALTURA_DA_LINHA - LADO_DO_RETRATO) * 0.5)
			linha.add_child(cara)
		linha.add_child(_sinais_da_linha(id))
		_coluna.add_child(linha)

		# A BARRINHA DO GRAU, na linha e não só na página: a pergunta que se faz
		# ao abrir esta tela é comparativa — de quem eu estou mais perto? —, e
		# isso se responde de relance com sete barras lado a lado.
		var barra := _barra(float(Afinidade.de(id)), 0.0, float(Afinidade.MAXIMO), ALTURA_DA_BARRA)
		barra.name = "Barra_" + id
		_coluna.add_child(barra)


## OS SINAIS DA LINHA, no canto direito dela: os corações do grau em cima e, em
## baixo, a conversa e o presente de hoje — acesos quando ainda dá. É o que
## responde "com quem eu ainda falo hoje?" passando o olho pelos sete, sem
## abrir página nenhuma.
func _sinais_da_linha(id: String) -> Control:
	var bloco := VBoxContainer.new()
	bloco.name = "Sinais"
	bloco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloco.add_theme_constant_override("separation", 4)
	bloco.alignment = BoxContainer.ALIGNMENT_CENTER
	bloco.anchor_left = 1.0
	bloco.anchor_right = 1.0
	bloco.anchor_top = 0.0
	bloco.anchor_bottom = 1.0
	bloco.offset_left = -LARGURA_DOS_SINAIS - 8.0
	bloco.offset_right = -8.0
	var coracoes := _coracoes(Afinidade.grau(id), LADO_DO_CORACAO_PEQUENO)
	coracoes.alignment = BoxContainer.ALIGNMENT_END
	bloco.add_child(coracoes)
	var hoje := HBoxContainer.new()
	hoje.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hoje.alignment = BoxContainer.ALIGNMENT_END
	hoje.add_theme_constant_override("separation", 6)
	hoje.add_child(_icone("conversa", 16.0, COR_BOM, Afinidade.pode_conversar(id)))
	hoje.add_child(_icone("presente", 16.0, COR_BOM, Afinidade.pode_presentear(id)))
	bloco.add_child(hoje)
	return bloco


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
	estilo.content_margin_right = int(LARGURA_DOS_SINAIS + 12.0)
	estilo.content_margin_top = 4
	estilo.content_margin_bottom = 4
	return estilo


## A PÁGINA DO MORADOR, desenhada antes de escrita.
##
## Cada bloco tem a forma da informação, e o texto vem embaixo como apoio:
## o retrato e os corações dizem quem é e quão perto; a barra diz quanto falta
## para o próximo grau; os dois selos de HOJE dizem o que ainda dá para fazer; a
## grade de presentes diz o que levar, com o selo de gosta/não aceita e quantos
## o jogador já tem na mochila; e a régua de "quanto rende" diz o valor de cada
## gesto. É a página social dos jogos do gênero — Stardew mostra corações e
## presentes, não parágrafos.
func _montar_pagina() -> void:
	for filho in _pagina.get_children():
		_pagina.remove_child(filho)
		filho.queue_free()
	if _quem == "":
		_pagina.add_child(_corpo("Escolha alguém à esquerda."))
		return

	# --- QUEM: retrato grande, nome, grau e corações -------------------------
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 16)
	_pagina.add_child(topo)
	var moldura := PanelContainer.new()
	var estilo_moldura := StyleBoxFlat.new()
	estilo_moldura.bg_color = Color(0.09, 0.12, 0.10, 0.95)
	estilo_moldura.border_color = Color(Identidade.OURO.r, Identidade.OURO.g, Identidade.OURO.b, 0.6)
	estilo_moldura.set_border_width_all(1)
	estilo_moldura.set_corner_radius_all(4)
	estilo_moldura.set_content_margin_all(4)
	moldura.add_theme_stylebox_override("panel", estilo_moldura)
	moldura.custom_minimum_size = Vector2(LADO_DO_RETRATO_GRANDE, LADO_DO_RETRATO_GRANDE) + Vector2(8, 8)
	topo.add_child(moldura)
	var grande := _retrato_de(_quem, LADO_DO_RETRATO_GRANDE)
	if grande != null:
		grande.name = "RetratoGrande"
		moldura.add_child(grande)
	var quem := VBoxContainer.new()
	quem.add_theme_constant_override("separation", 4)
	quem.alignment = BoxContainer.ALIGNMENT_CENTER
	quem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(quem)
	var nome := Label.new()
	nome.text = _nome_de(_quem)
	nome.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600, 1))
	nome.add_theme_font_size_override("font_size", 26)
	nome.add_theme_color_override("font_color", Identidade.CREME)
	Identidade.sombra_texto(nome)
	quem.add_child(nome)
	var coracoes := _coracoes(Afinidade.grau(_quem), LADO_DO_CORACAO)
	coracoes.name = "Coracoes"
	quem.add_child(coracoes)
	var grau := Label.new()
	grau.text = Afinidade.nome_do_grau(_quem)
	grau.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_ITALICO, 400))
	grau.add_theme_font_size_override("font_size", 18)
	grau.add_theme_color_override("font_color", Identidade.OURO)
	quem.add_child(grau)
	var fe_dele := str(Afinidade.fe_de(_quem))
	if fe_dele != "" and Afinidade.grau(_quem) >= GRAU_DO_GOSTO:
		# A fé só com convivência: é assunto de quem se conhece.
		var fe := _corpo("É de %s." % Fe.nome(fe_dele))
		fe.add_theme_font_size_override("font_size", 15)
		fe.add_theme_color_override("font_color", COR_APAGADA)
		quem.add_child(fe)

	# --- QUANTO FALTA: a barra do grau, de um degrau ao outro ----------------
	_pagina.add_child(_titulo_de_bloco("Até o próximo grau"))
	var degrau := Afinidade.grau(_quem)
	var de_agora := float(Afinidade.GRAUS[degrau]["de"])
	var falta := Afinidade.falta_para_o_proximo(_quem)
	var linha_da_barra := HBoxContainer.new()
	linha_da_barra.add_theme_constant_override("separation", 10)
	_pagina.add_child(linha_da_barra)
	if falta > 0:
		var ate := float(Afinidade.GRAUS[degrau + 1]["de"])
		var barra := _barra(float(Afinidade.de(_quem)), de_agora, ate, 14.0)
		barra.name = "BarraDoGrau"
		barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		linha_da_barra.add_child(barra)
		linha_da_barra.add_child(_icone("coracao", 18.0, Identidade.OURO, false))
		var conta := _corpo("%d / %d" % [Afinidade.de(_quem) - int(de_agora), int(ate - de_agora)])
		# Número não quebra linha: com quebra e sem largura, o "12 / 30" saía
		# empilhado letra a letra.
		conta.autowrap_mode = TextServer.AUTOWRAP_OFF
		conta.size_flags_horizontal = Control.SIZE_SHRINK_END
		conta.add_theme_font_override("font", Identidade.fonte_numeros(600))
		conta.add_theme_font_size_override("font_size", 15)
		linha_da_barra.add_child(conta)
		var apoio := _corpo("Falta %d para %s." % [falta, str(Afinidade.GRAUS[degrau + 1]["nome"])])
		apoio.add_theme_font_size_override("font_size", 15)
		apoio.add_theme_color_override("font_color", COR_APAGADA)
		_pagina.add_child(apoio)
	else:
		var barra := _barra(1.0, 0.0, 1.0, 14.0)
		barra.name = "BarraDoGrau"
		barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha_da_barra.add_child(barra)
		linha_da_barra.add_child(_icone("estrela", 18.0, Identidade.OURO, true))
		_pagina.add_child(_corpo("Não há mais grau depois deste."))

	# --- HOJE: os dois gestos do dia, como selos -----------------------------
	#
	# Dito como TAREFA e não como estado — é do 2D: "ainda dá para conversar
	# hoje" é convite para fechar a tela e ir até lá. O selo aceso é o convite.
	_pagina.add_child(_titulo_de_bloco("Hoje"))
	var selos := HBoxContainer.new()
	selos.name = "Hoje"
	selos.add_theme_constant_override("separation", 10)
	_pagina.add_child(selos)
	var conversa := Afinidade.pode_conversar(_quem)
	var presente := Afinidade.pode_presentear(_quem)
	selos.add_child(_selo("conversa", conversa,
		"Ainda dá para conversar hoje" if conversa else "Já conversaram hoje"))
	selos.add_child(_selo("presente", presente,
		"Ainda dá para dar alguma coisa hoje" if presente else "Já ganhou alguma coisa hoje"))

	# --- PRESENTES: o que levar, em desenho ----------------------------------
	#
	# O GOSTO SÓ DE "GENTE BOA" PARA CIMA. A razão é do 2D e está no cabeçalho:
	# o que alguém gosta de ganhar se descobre convivendo. Mas o que está
	# escondido também aparece — como VAGA FECHADA, um cadeado por presente —,
	# para o jogador ver que há o que descobrir e quanto, sem ler o quê.
	_pagina.add_child(_titulo_de_bloco("Presentes"))
	var dele: Dictionary = Jogo.dados(Afinidade.ARQUIVO_DOS_MORADORES).get(_quem, {})
	var bons: Array = dele.get("gosta", [])
	var ruins: Array = dele.get("desgosta", [])
	var grade := HFlowContainer.new()
	grade.name = "GradeDePresentes"
	grade.add_theme_constant_override("h_separation", 8)
	grade.add_theme_constant_override("v_separation", 8)
	_pagina.add_child(grade)
	if Afinidade.grau(_quem) >= GRAU_DO_GOSTO:
		for item in bons:
			grade.add_child(_ficha_de_mimo(str(item), true))
		for item in ruins:
			grade.add_child(_ficha_de_mimo(str(item), false))
		if not bons.is_empty():
			var nomes_bons := _corpo("Gosta de ganhar: %s." % _nomes_dos_itens(bons))
			nomes_bons.add_theme_color_override("font_color", COR_BOM)
			nomes_bons.add_theme_font_size_override("font_size", 15)
			_pagina.add_child(nomes_bons)
		if not ruins.is_empty():
			var nomes_ruins := _corpo("Não aceita: %s." % _nomes_dos_itens(ruins))
			nomes_ruins.add_theme_color_override("font_color", COR_RUIM)
			nomes_ruins.add_theme_font_size_override("font_size", 15)
			_pagina.add_child(nomes_ruins)
	else:
		for i in bons.size() + ruins.size():
			grade.add_child(_ficha_fechada())
		var dica := _corpo("Converse e apareça mais para saber do que gosta. Abre em %s."
			% str(Afinidade.GRAUS[GRAU_DO_GOSTO]["nome"]))
		dica.add_theme_font_size_override("font_size", 15)
		dica.add_theme_color_override("font_color", COR_APAGADA)
		_pagina.add_child(dica)

	# --- QUANTO RENDE: o valor de cada gesto, numa régua ---------------------
	_pagina.add_child(_titulo_de_bloco("Quanto rende"))
	var regua := HFlowContainer.new()
	regua.name = "QuantoRende"
	regua.add_theme_constant_override("h_separation", 14)
	regua.add_theme_constant_override("v_separation", 6)
	_pagina.add_child(regua)
	regua.add_child(_valor("conversa", COR_TEXTO, "", Afinidade.POR_CONVERSA, "Conversa"))
	regua.add_child(_valor("presente", COR_BOM, "coracao", Afinidade.POR_PRESENTE_BOM, "Presente que gosta"))
	regua.add_child(_valor("presente", COR_TEXTO, "", Afinidade.POR_PRESENTE_QUALQUER, "Outro presente"))
	regua.add_child(_valor("presente", COR_RUIM, "nao", Afinidade.POR_PRESENTE_RUIM, "Presente que não aceita"))
	regua.add_child(_valor("estrela", Identidade.OURO, "", Afinidade.POR_FAVOR, "Favor cumprido"))


## Os corações do grau: um por degrau acima de "Desconhecido", cheios até onde
## o jogador chegou.
func _coracoes(grau_atual: int, lado: float) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_theme_constant_override("separation", 3 if lado < 16.0 else 5)
	for i in range(1, Afinidade.GRAUS.size()):
		var coracao := _icone("coracao", lado, COR_CORACAO, i <= grau_atual)
		coracao.tooltip_text = str(Afinidade.GRAUS[i]["nome"])
		fila.add_child(coracao)
	return fila


func _icone(tipo: String, lado: float, cor: Color, aceso: bool) -> Control:
	return IconeRelacao.new().configurar(tipo, lado, cor, aceso)


## Barra de `de` a `ate`, com moldura, cheia até `valor`.
func _barra(valor: float, de: float, ate: float, altura: float) -> ProgressBar:
	var barra := ProgressBar.new()
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(0, altura)
	barra.min_value = de
	barra.max_value = ate
	barra.value = valor
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.13, 0.16, 0.12, 0.9)
	fundo.border_color = Color(0.32, 0.35, 0.30, 0.9)
	fundo.set_border_width_all(1)
	fundo.set_corner_radius_all(3)
	var cheio := StyleBoxFlat.new()
	cheio.bg_color = COR_CORACAO
	cheio.set_corner_radius_all(3)
	barra.add_theme_stylebox_override("background", fundo)
	barra.add_theme_stylebox_override("fill", cheio)
	return barra


func _titulo_de_bloco(texto: String) -> Control:
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 2)
	var respiro := Control.new()
	respiro.custom_minimum_size = Vector2(0, 6)
	caixa.add_child(respiro)
	var rotulo := Label.new()
	rotulo.text = texto.to_upper()
	rotulo.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 600))
	rotulo.add_theme_font_size_override("font_size", 13)
	rotulo.add_theme_color_override("font_color", Identidade.OURO)
	caixa.add_child(rotulo)
	return caixa


## Um selo do dia: o ícone do gesto aceso (ainda dá) ou apagado (já foi), o
## certo quando já foi, e a frase pequena embaixo de apoio.
func _selo(tipo: String, ainda_da: bool, frase: String) -> Control:
	var selo := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.10, 0.17, 0.11, 0.95) if ainda_da else Color(0.09, 0.10, 0.09, 0.9)
	estilo.border_color = Color(COR_BOM.r, COR_BOM.g, COR_BOM.b, 0.7) if ainda_da else Color(0.3, 0.32, 0.28, 0.8)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(4)
	estilo.set_content_margin_all(8)
	selo.add_theme_stylebox_override("panel", estilo)
	selo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 8)
	selo.add_child(linha)
	linha.add_child(_icone(tipo, 26.0, COR_BOM if ainda_da else COR_APAGADA, ainda_da))
	var rotulo := _corpo(frase + ".")
	rotulo.add_theme_font_size_override("font_size", 14)
	rotulo.add_theme_color_override("font_color", Identidade.CREME if ainda_da else COR_APAGADA)
	rotulo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	linha.add_child(rotulo)
	if not ainda_da:
		linha.add_child(_icone("certo", 18.0, COR_APAGADA, true))
	return selo


## A ficha de um presente: o desenho do item, o selo de gosta (coração) ou de
## não aceita (X) no canto, e quantos o jogador tem na mochila — o número que
## decide se dá para levar hoje. Item sem desenho entra com a inicial.
func _ficha_de_mimo(item: String, gosta: bool) -> Control:
	var cor := COR_BOM if gosta else COR_RUIM
	var ficha := PanelContainer.new()
	ficha.name = "Ficha_" + item
	ficha.tooltip_text = "%s · %s" % [str(Catalogo.nome(item)), "gosta" if gosta else "não aceita"]
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.08, 0.11, 0.09, 0.95)
	estilo.border_color = Color(cor.r, cor.g, cor.b, 0.75)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(4)
	ficha.add_theme_stylebox_override("panel", estilo)
	ficha.custom_minimum_size = Vector2(LADO_DA_FICHA, LADO_DA_FICHA)
	var dentro := Control.new()
	dentro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ficha.add_child(dentro)
	var caminho := "res://assets/sprites/itens/%s.png" % item
	if ResourceLoader.exists(caminho):
		var quadro := TextureRect.new()
		quadro.name = "Mimo_" + item
		quadro.texture = load(caminho)
		quadro.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		quadro.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		quadro.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		quadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quadro.position = Vector2(8, 6)
		quadro.size = Vector2(LADO_DO_MIMO, LADO_DO_MIMO)
		dentro.add_child(quadro)
	else:
		var inicial := Label.new()
		inicial.text = str(Catalogo.nome(item)).substr(0, 2)
		inicial.position = Vector2(12, 12)
		inicial.add_theme_color_override("font_color", cor)
		dentro.add_child(inicial)
	var selo := _icone("coracao" if gosta else "nao", 16.0, cor, true)
	selo.position = Vector2(LADO_DA_FICHA - 18.0, 2.0)
	dentro.add_child(selo)
	var tem := Inventario.quantidade(item)
	var conta := Label.new()
	conta.text = "×%d" % tem
	conta.add_theme_font_override("font", Identidade.fonte_numeros(600))
	conta.add_theme_font_size_override("font_size", 12)
	conta.add_theme_color_override("font_color", Identidade.CREME if tem > 0 else COR_APAGADA)
	conta.position = Vector2(LADO_DA_FICHA - 26.0, LADO_DA_FICHA - 18.0)
	conta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dentro.add_child(conta)
	return ficha


## A vaga de um presente que ainda não se sabe: só o cadeado.
func _ficha_fechada() -> Control:
	var ficha := PanelContainer.new()
	ficha.name = "FichaFechada"
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.07, 0.08, 0.07, 0.9)
	estilo.border_color = Color(0.3, 0.32, 0.28, 0.8)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(4)
	ficha.add_theme_stylebox_override("panel", estilo)
	ficha.custom_minimum_size = Vector2(LADO_DA_FICHA, LADO_DA_FICHA)
	var centro := CenterContainer.new()
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ficha.add_child(centro)
	centro.add_child(_icone("cadeado", 22.0, COR_APAGADA, true))
	return ficha


## Um valor da régua de "quanto rende": o ícone do gesto (com selo, quando o
## presente é o que gosta ou o que não aceita), o número com sinal e cor, e o
## nome do gesto no tooltip e em letra pequena.
func _valor(tipo: String, cor: Color, selo: String, pontos: int, nome: String) -> Control:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 4)
	linha.tooltip_text = nome
	var icone := Control.new()
	icone.custom_minimum_size = Vector2(24, 24)
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icone.add_child(_icone(tipo, 22.0, cor, true))
	if selo != "":
		var marca := _icone(selo, 11.0, cor, true)
		marca.position = Vector2(14, 13)
		icone.add_child(marca)
	linha.add_child(icone)
	var numero := Label.new()
	numero.text = "%+d" % pontos
	numero.add_theme_font_override("font", Identidade.fonte_numeros(700))
	numero.add_theme_font_size_override("font_size", 16)
	numero.add_theme_color_override("font_color", COR_RUIM if pontos < 0 else COR_BOM)
	linha.add_child(numero)
	var legenda := Label.new()
	legenda.text = nome.to_lower()
	legenda.add_theme_font_size_override("font_size", 12)
	legenda.add_theme_color_override("font_color", COR_APAGADA)
	linha.add_child(legenda)
	return linha


## O retrato do morador, ou null quando não há folha para ele.
##
## A folha é uma grade de quadros; o de frente parado é o primeiro, e é o que o
## 2D usa nesta mesma lista. Recorta-se com AtlasTexture em vez de desenhar a
## folha inteira — sem o recorte apareceriam os dezesseis quadros espremidos.
func _retrato_de(id: String, lado: float) -> TextureRect:
	var caminho := PASTA_DOS_RETRATOS + id + ".png"
	if not ResourceLoader.exists(caminho):
		return null
	var folha: Texture2D = load(caminho)
	if folha == null:
		return null
	var quadro := AtlasTexture.new()
	quadro.atlas = folha
	# O QUADRO É QUADRADO, e a conta é pela LARGURA. As folhas têm quatro
	# colunas de 48 px e um número de linhas que muda — sete na maioria, uma
	# só na da Candinha e na do Damião. Dividir a altura por quatro cortava
	# dois bonecos empilhados nas folhas altas e uma fatia de 12 px nas baixas.
	var lado_do_quadro := folha.get_width() / float(QUADROS_DA_FOLHA)
	quadro.region = Rect2(Vector2.ZERO, Vector2(lado_do_quadro, minf(lado_do_quadro, folha.get_height())))
	var moldura := TextureRect.new()
	moldura.name = "Retrato_" + id
	moldura.texture = quadro
	moldura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	moldura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	moldura.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	moldura.custom_minimum_size = Vector2(lado, lado)
	moldura.size = Vector2(lado, lado)
	# O clique é da linha inteira: retrato que engole clique é meia linha morta.
	moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return moldura


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
