extends Control
## O ALMANAQUE: as plantas que o jogador já conheceu, para reler quando quiser.
##
## O que mudou e por quê. Antes o E perto de uma árvore abria a ficha dela, e
## fazia isso TODA VEZ — então o E era duas coisas ao mesmo tempo, e a que ele
## fazia dependia de onde o jogador estava. Tecla que faz duas coisas é tecla
## que faz a errada na hora errada.
##
## Agora o encontro acontece UMA VEZ. Na primeira aproximação de cada espécie,
## o E abre a ficha e a espécie entra aqui; da segunda em diante o E é só
## coletar e interagir, e quem quiser reler abre o almanaque na tecla dele.
##
## É a forma que o `Colecao` do 2D já usa para os bichos: "uma página por
## espécie, aberta na primeira que o jogador derruba". A diferença é que aquele
## é arquivo compartilhado e acrescentar "plantas" nele mexeria no jogo 2D por
## um recurso que é daqui. Quando as plantas do 2D quiserem almanaque, a lista
## muda de casa e esta tela passa a ler de lá.
##
##
## A CADEIA DE ÍNDICES, E POR QUE ELA SUBSTITUIU A LISTA CORRIDA
##
## A primeira versão desta tela era uma coluna só: título, e embaixo as
## espécies conhecidas emendadas uma na outra, nome, latim e as duas páginas de
## cada uma, tudo numa rolagem. Funcionava com três plantas. Com dezoito — que
## é quantas o vale tem — vira um rolo: não se acha nada, não se sabe quanto
## falta, e não há como voltar a uma ficha lida.
##
## A forma agora é a do diário do Witcher 3, que foi o pedido, e ela é de
## ÍNDICE E PÁGINA em vez de rolo:
##
##   coluna da esquerda   a cadeia — os grupos, e dentro do grupo escolhido as
##                        espécies dele. Entrar num grupo não troca de tela:
##                        a cadeia se abre no lugar, e o caminho fica escrito
##                        no alto ("Almanaque › Frutíferas do quintal ›
##                        Mangueira"), que é o fio para voltar.
##   página da direita    a ficha da espécie escolhida: nome, o latim em
##                        itálico, um filete de ouro e o texto em corpo de
##                        leitura, uma página por parágrafo.
##
## Os grupos vêm do DADO (`data/arvores_3d.json`, bloco "grupos"), e não de uma
## constante aqui: grupo é texto que o jogador lê, e texto que o jogador lê
## precisa poder ganhar as outras duas línguas. Espécie sem grupo cai em
## "outras" — acrescentar planta nova nunca a faz desaparecer da tela.
##
## AS NÃO CONHECIDAS NÃO APARECEM, nem como silhueta, e isto não mudou: lista
## com buraco numerado vira caça ao item, e o almanaque é sobre o que se viu. O
## que aparece é a CONTA de cada grupo ("4 de 6"), que responde "falta muito?"
## sem dizer o que falta.
##
##
## ONDE FICA GUARDADO
##
## `user://almanaque.cfg`, ao lado das preferências — e não no save da partida.
## A razão: o que o jogador APRENDEU sobre o mundo não é estado de partida, é
## dele. Recomeçar não desaprende que mangueira veio da Índia.

const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")

const DADOS := "res://data/arvores_3d.json"
const ARQUIVO := "user://almanaque.cfg"

const FUNDO := Color(0.02, 0.03, 0.03, 0.72)
const PAINEL := Color(0.055, 0.082, 0.070, 0.985)
const OURO := Identidade.OURO
const PAPEL := Identidade.TEXTO
const APAGADO := Color(0.55, 0.58, 0.52)
const REALCE := Color(0.13, 0.16, 0.12, 0.9)
const ESCOLHIDO := Color(0.19, 0.21, 0.15, 0.96)

const TAMANHO := Vector2(940, 560)
const LARGURA_DA_CADEIA := 300.0
const ALTURA_DA_LINHA := 30.0

## Espécie → ficha, lida do mesmo arquivo que as fichas do mundo usam.
static var _fichas: Dictionary = {}
## Chave do grupo → {"nome", "resumo"}, na ordem do arquivo.
static var _grupos: Dictionary = {}
## Espécies conhecidas, na ordem em que foram encontradas.
static var _conhecidas: Array = []
static var _lido := false

var _caminho: Label
var _cadeia: VBoxContainer
var _pagina: VBoxContainer
var _rodape: Label
var _aberto := false

## Grupo aberto na cadeia, "" quando ela mostra só os grupos.
var _grupo := ""
## Espécie aberta na página, "" quando nenhuma.
var _especie := ""
## Onde está o cursor do teclado, na ordem em que as linhas aparecem.
var _cursor := 0
## As linhas de agora, na ordem da tela: {"tipo": "grupo"|"especie", "chave"}.
var _linhas: Array = []


# --- o registro, que é estático porque o mundo pergunta antes de haver tela ---

static func _garantir() -> void:
	if _lido:
		return
	_lido = true
	var arquivo := FileAccess.open(DADOS, FileAccess.READ)
	if arquivo != null:
		var dado = JSON.parse_string(arquivo.get_as_text())
		arquivo.close()
		if typeof(dado) == TYPE_DICTIONARY:
			_fichas = dado.get("arvores", {})
			_grupos = dado.get("grupos", {})
	var cfg := ConfigFile.new()
	if cfg.load(ARQUIVO) == OK:
		var guardadas = cfg.get_value("almanaque", "especies", [])
		if typeof(guardadas) == TYPE_ARRAY:
			for especie in guardadas:
				if _fichas.has(str(especie)):
					_conhecidas.append(str(especie))


## O jogador já conheceu esta espécie? É o que decide se o E abre a ficha ou
## deixa a tecla passar para quem coleta.
static func conhece(especie: String) -> bool:
	_garantir()
	return _conhecidas.has(especie)


## Registra o encontro. Devolve `true` quando é a primeira vez — que é quando
## a ficha deve abrir.
static func registrar(especie: String) -> bool:
	_garantir()
	if especie == "" or not _fichas.has(especie):
		return false
	if _conhecidas.has(especie):
		return false
	_conhecidas.append(especie)
	var cfg := ConfigFile.new()
	cfg.load(ARQUIVO)
	cfg.set_value("almanaque", "especies", _conhecidas)
	if cfg.save(ARQUIVO) != OK:
		push_warning("Almanaque: não consegui guardar as espécies conhecidas.")
	return true


static func conhecidas() -> Array:
	_garantir()
	return _conhecidas.duplicate()


static func total() -> int:
	_garantir()
	return _fichas.size()


## A QUE GRUPO A ESPÉCIE PERTENCE, com "outras" como rede.
##
## Espécie sem `grupo`, ou com grupo que o bloco "grupos" não declara, cai em
## "outras". Sem isto, acrescentar uma planta e esquecer o campo a faria
## desaparecer da tela — e desaparecer calado é o pior jeito de faltar.
static func grupo_de(especie: String) -> String:
	_garantir()
	var chave := str((_fichas.get(especie, {}) as Dictionary).get("grupo", ""))
	return chave if _grupos.has(chave) else "outras"


## As espécies conhecidas daquele grupo, na ordem em que foram encontradas.
static func conhecidas_do_grupo(grupo: String) -> Array:
	var lista: Array = []
	for especie in conhecidas():
		if grupo_de(str(especie)) == grupo:
			lista.append(especie)
	return lista


## Quantas espécies o grupo tem no total, conhecidas ou não. É a outra metade da
## conta "4 de 6", que responde "falta muito?" sem dizer o que falta.
static func total_do_grupo(grupo: String) -> int:
	_garantir()
	var conta := 0
	for especie in _fichas:
		if grupo_de(str(especie)) == grupo:
			conta += 1
	return conta


## Os grupos que têm pelo menos uma espécie conhecida, na ordem do arquivo.
##
## Grupo vazio não entra: cabeçalho de gaveta vazia é a mesma caça ao item que
## a silhueta seria.
static func grupos_com_algo() -> Array:
	_garantir()
	var lista: Array = []
	for chave in _grupos:
		if not conhecidas_do_grupo(str(chave)).is_empty():
			lista.append(str(chave))
	return lista


# --- a tela ------------------------------------------------------------------

func _ready() -> void:
	_garantir()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_montar()


func _montar() -> void:
	var cortina := ColorRect.new()
	cortina.color = FUNDO
	cortina.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cortina.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cortina)

	var painel := PanelContainer.new()
	painel.name = "Retabulo"
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = PAINEL
	estilo.border_color = Color(OURO.r, OURO.g, OURO.b, 0.55)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(4)
	estilo.set_content_margin_all(26)
	painel.add_theme_stylebox_override("panel", estilo)
	add_child(painel)
	painel.anchor_left = 0.5
	painel.anchor_right = 0.5
	painel.anchor_top = 0.5
	painel.anchor_bottom = 0.5
	painel.offset_left = -TAMANHO.x * 0.5
	painel.offset_right = TAMANHO.x * 0.5
	painel.offset_top = -TAMANHO.y * 0.5
	painel.offset_bottom = TAMANHO.y * 0.5
	# A MOLDURA DE TALHA do resto do vale. Vem da identidade "Retábulo" e não de
	# uma borda desenhada aqui: tela nova com borda própria é tela que envelhece
	# sozinha quando a identidade muda.
	Identidade.emoldurar(painel)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 12)
	painel.add_child(coluna)

	# O CAMINHO, que é o fio para voltar. "Almanaque › Frutíferas › Mangueira".
	_caminho = Label.new()
	_caminho.name = "Caminho"
	_caminho.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 500, 2))
	_caminho.add_theme_font_size_override("font_size", 19)
	_caminho.add_theme_color_override("font_color", OURO)
	Identidade.sombra_texto(_caminho)
	coluna.add_child(_caminho)
	coluna.add_child(Identidade.divisor())

	var lado_a_lado := HBoxContainer.new()
	lado_a_lado.add_theme_constant_override("separation", 26)
	lado_a_lado.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(lado_a_lado)

	# A cadeia rola: dezoito espécies não cabem sem cortar, e o que corta no
	# rodapé é justamente o fim da lista.
	var rolagem_cadeia := ScrollContainer.new()
	rolagem_cadeia.custom_minimum_size = Vector2(LARGURA_DA_CADEIA, 0)
	rolagem_cadeia.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem_cadeia.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lado_a_lado.add_child(rolagem_cadeia)
	_cadeia = VBoxContainer.new()
	_cadeia.name = "Cadeia"
	_cadeia.add_theme_constant_override("separation", 2)
	_cadeia.custom_minimum_size = Vector2(LARGURA_DA_CADEIA - 14.0, 0)
	rolagem_cadeia.add_child(_cadeia)

	var fio := VSeparator.new()
	fio.add_theme_constant_override("separation", 1)
	lado_a_lado.add_child(fio)

	var rolagem_pagina := ScrollContainer.new()
	rolagem_pagina.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem_pagina.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem_pagina.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lado_a_lado.add_child(rolagem_pagina)
	_pagina = VBoxContainer.new()
	_pagina.name = "Pagina"
	_pagina.add_theme_constant_override("separation", 10)
	_pagina.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem_pagina.add_child(_pagina)

	_rodape = Label.new()
	_rodape.name = "Rodape"
	_rodape.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 400))
	_rodape.add_theme_font_size_override("font_size", 14)
	_rodape.add_theme_color_override("font_color", APAGADO)
	coluna.add_child(_rodape)


## ABRIU OU FECHOU, para quem pausa o vale.
##
## O almanaque era a única tela do vale que não parava nada atrás dela: o
## jogador abria a lista das plantas e os moradores continuavam andando, os
## bichos caçando e o dia correndo. A regra pedida é para toda tela — "quando
## se abre qualquer menu, o jogo atrás deve ser pausado".
##
## Quem pausa não é esta tela, é o `Prototype`: ele é o dono do modo de câmera
## guardado (`_camera_travada_antes`), e duas casas guardando o mesmo número é
## uma delas com o número velho. Mesma costura da mochila, que avisa pela
## `BarraDeMao.mochila_mudou`.
signal mudou(aberto: bool)


func aberto() -> bool:
	return _aberto


func alternar() -> void:
	if _aberto:
		fechar()
	else:
		abrir()


func abrir() -> void:
	if _aberto:
		return
	# ABRE ONDE O JOGADOR PAROU, e não sempre na raiz: quem fecha o almanaque no
	# meio de uma ficha e reabre quer aquela ficha. Se a espécie não é mais
	# conhecida — não acontece hoje, mas custa uma linha —, cai na raiz.
	if _especie != "" and not conhece(_especie):
		_especie = ""
		_grupo = ""
	_encher()
	visible = true
	_aberto = true
	mudou.emit(true)


func fechar() -> void:
	if not _aberto:
		return
	visible = false
	_aberto = false
	mudou.emit(false)


## A CADEIA E A PÁGINA, redesenhadas do zero.
##
## Redesenhar tudo a cada mexida em vez de remendar a linha que mudou: são
## dezenas de nós, não milhares, e tela que se remenda é tela que guarda estado
## em dois lugares — o dado e o que está desenhado — e os dois divergem.
func _encher() -> void:
	_linhas = []
	for filho in _cadeia.get_children():
		filho.queue_free()
	for filho in _pagina.get_children():
		filho.queue_free()

	_caminho.text = _texto_do_caminho()

	if conhecidas().is_empty():
		var vazio := _corpo("Nada ainda. Chegue perto de uma planta e aperte E: a primeira vez que você olha uma espécie, ela entra aqui.")
		_pagina.add_child(vazio)
		_rodape.text = "%s ou Esc: fechar" % OS.get_keycode_string(Atalhos.tecla("almanaque"))
		return

	_montar_cadeia()
	_montar_pagina()
	_cursor = clampi(_cursor, 0, maxi(0, _linhas.size() - 1))
	_pintar_cursor()
	_rodape.text = "↑↓ ou W/S: andar    ·    E ou Enter: abrir    ·    ←: voltar    ·    %s ou Esc: fechar" \
		% OS.get_keycode_string(Atalhos.tecla("almanaque"))


func _texto_do_caminho() -> String:
	var partes: Array[String] = ["Almanaque"]
	if _grupo != "":
		partes.append(str((_grupos.get(_grupo, {}) as Dictionary).get("nome", _grupo)))
	if _especie != "":
		partes.append(str((_fichas.get(_especie, {}) as Dictionary).get("nome", _especie)))
	var conta := "  ·  %d de %d" % [conhecidas().size(), total()]
	return "  ›  ".join(partes) + conta


## A coluna da esquerda: os grupos, e as espécies do grupo aberto logo abaixo
## dele. A cadeia se ABRE NO LUGAR — entrar num grupo não troca de tela, e é o
## que deixa o caminho de volta visível sem botão de voltar.
func _montar_cadeia() -> void:
	for chave in grupos_com_algo():
		var grupo := str(chave)
		var ficha: Dictionary = _grupos.get(grupo, {})
		var quantas := conhecidas_do_grupo(grupo).size()
		var linha := _linha_da_cadeia(
			str(ficha.get("nome", grupo)),
			"%d de %d" % [quantas, total_do_grupo(grupo)],
			0, grupo == _grupo)
		linha.pressed.connect(_escolher_grupo.bind(grupo))
		_cadeia.add_child(linha)
		_linhas.append({"tipo": "grupo", "chave": grupo, "no": linha})

		if grupo != _grupo:
			continue
		for bruto in conhecidas_do_grupo(grupo):
			var especie := str(bruto)
			var nome := str((_fichas.get(especie, {}) as Dictionary).get("nome", especie))
			var filha := _linha_da_cadeia(nome, "", 1, especie == _especie)
			filha.pressed.connect(_escolher_especie.bind(especie))
			_cadeia.add_child(filha)
			_linhas.append({"tipo": "especie", "chave": especie, "no": filha})


func _linha_da_cadeia(texto: String, conta: String, nivel: int, escolhida: bool) -> Button:
	var botao := Button.new()
	botao.focus_mode = Control.FOCUS_NONE
	botao.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	botao.custom_minimum_size = Vector2(0, ALTURA_DA_LINHA)
	botao.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# O nível vira recuo: grupo na margem, espécie um passo dentro. É o que faz
	# a cadeia parecer cadeia sem precisar de desenho.
	botao.text = ("      " if nivel > 0 else "") + ("▸ " if nivel == 0 and not escolhida else "") \
		+ ("▾ " if nivel == 0 and escolhida else "") + texto
	if conta != "":
		botao.text += "    " + conta
	var fonte := Identidade.FONTE_TITULO if nivel == 0 else Identidade.FONTE_TEXTO
	botao.add_theme_font_override("font", Identidade.fonte(fonte, 600 if nivel == 0 else 400))
	botao.add_theme_font_size_override("font_size", 16 if nivel == 0 else 17)
	botao.add_theme_color_override("font_color", OURO if nivel == 0 else PAPEL)
	botao.add_theme_color_override("font_hover_color", Identidade.CREME)
	for estado in ["normal", "hover", "pressed"]:
		botao.add_theme_stylebox_override(estado, _estilo_da_linha(escolhida, estado != "normal"))
	return botao


func _estilo_da_linha(escolhida: bool, realce: bool) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	if escolhida:
		estilo.bg_color = ESCOLHIDO
		estilo.border_color = Color(OURO.r, OURO.g, OURO.b, 0.75)
		estilo.border_width_left = 2
	elif realce:
		estilo.bg_color = REALCE
	else:
		estilo.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	estilo.content_margin_left = 10
	estilo.content_margin_right = 10
	return estilo


## A página da direita: a ficha da espécie escolhida; sem espécie, o resumo do
## grupo; sem grupo, o convite a abrir um.
func _montar_pagina() -> void:
	if _especie != "":
		var ficha: Dictionary = _fichas.get(_especie, {})
		var nome := Label.new()
		nome.text = str(ficha.get("nome", _especie))
		nome.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600, 1))
		nome.add_theme_font_size_override("font_size", 30)
		nome.add_theme_color_override("font_color", Identidade.CREME)
		Identidade.sombra_texto(nome)
		_pagina.add_child(nome)

		var cientifico := str(ficha.get("cientifico", ""))
		if cientifico != "":
			var latim := Label.new()
			latim.text = cientifico
			latim.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_ITALICO, 400))
			latim.add_theme_font_size_override("font_size", 18)
			latim.add_theme_color_override("font_color", APAGADO)
			_pagina.add_child(latim)

		_pagina.add_child(_filete())
		for pagina in ficha.get("paginas", []):
			_pagina.add_child(_corpo(str(pagina)))
		return

	if _grupo != "":
		var ficha: Dictionary = _grupos.get(_grupo, {})
		var titulo := Label.new()
		titulo.text = str(ficha.get("nome", _grupo))
		titulo.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600, 1))
		titulo.add_theme_font_size_override("font_size", 26)
		titulo.add_theme_color_override("font_color", Identidade.CREME)
		_pagina.add_child(titulo)
		_pagina.add_child(_filete())
		_pagina.add_child(_corpo(str(ficha.get("resumo", ""))))
		_pagina.add_child(_corpo("%d de %d espécies deste grupo você já viu de perto."
			% [conhecidas_do_grupo(_grupo).size(), total_do_grupo(_grupo)]))
		return

	_pagina.add_child(_corpo("Abra um grupo à esquerda. Cada planta entra aqui na primeira vez que você chega perto dela e aperta E."))



## O filete de ouro da identidade, esticado na largura da página. Sem o esticão
## ele sai com os 16 px do mínimo dele, e um filete de 16 px no meio de uma
## página de 600 parece sujeira e não ornamento.
func _filete() -> TextureRect:
	var linha := Identidade.filete_centrado(1.0)
	linha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return linha

func _corpo(texto: String) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 400))
	rotulo.add_theme_font_size_override("font_size", 19)
	rotulo.add_theme_color_override("font_color", PAPEL)
	rotulo.add_theme_constant_override("line_spacing", 4)
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return rotulo


# --- andar na cadeia ---------------------------------------------------------

func _escolher_grupo(grupo: String) -> void:
	# Apertar o grupo aberto FECHA ele, como toda árvore de índice faz.
	if _grupo == grupo:
		_grupo = ""
		_especie = ""
	else:
		_grupo = grupo
		_especie = ""
	_encher()


func _escolher_especie(especie: String) -> void:
	_especie = especie
	_grupo = grupo_de(especie)
	_encher()


## O cursor do teclado, marcado por cima do que a escolha já marca. São duas
## coisas diferentes: a escolha é onde o jogador ESTÁ lendo, o cursor é onde a
## próxima tecla vai agir.
func _pintar_cursor() -> void:
	for i in _linhas.size():
		var linha: Dictionary = _linhas[i]
		var botao := linha["no"] as Button
		if not is_instance_valid(botao):
			continue
		var escolhida: bool = (linha["tipo"] == "grupo" and str(linha["chave"]) == _grupo and _especie == "") \
			or (linha["tipo"] == "especie" and str(linha["chave"]) == _especie)
		var estilo := _estilo_da_linha(escolhida, i == _cursor)
		if i == _cursor and not escolhida:
			estilo.border_color = Color(OURO.r, OURO.g, OURO.b, 0.45)
			estilo.border_width_left = 2
		botao.add_theme_stylebox_override("normal", estilo)


func _andar(passo: int) -> void:
	if _linhas.is_empty():
		return
	_cursor = wrapi(_cursor + passo, 0, _linhas.size())
	_pintar_cursor()


func _abrir_no_cursor() -> void:
	if _cursor < 0 or _cursor >= _linhas.size():
		return
	var linha: Dictionary = _linhas[_cursor]
	var guardado := _cursor
	if str(linha["tipo"]) == "grupo":
		_escolher_grupo(str(linha["chave"]))
	else:
		_escolher_especie(str(linha["chave"]))
	# Depois de abrir um grupo, a lista cresceu: o cursor fica onde estava, que
	# é a linha do próprio grupo, e não salta para o começo.
	_cursor = clampi(guardado, 0, maxi(0, _linhas.size() - 1))
	_pintar_cursor()


## Um passo atrás na cadeia: da ficha para o grupo, do grupo para a raiz.
func _voltar() -> void:
	if _especie != "":
		_especie = ""
	elif _grupo != "":
		_grupo = ""
	else:
		return
	_encher()


## AS TECLAS DA NAVEGAÇÃO, e só elas.
##
## A tecla que ABRE e o Esc que FECHA saíram daqui: quem cuida deles é o
## `telas_do_vale.gd`, porque abrir uma tela tem de fechar a outra, e uma tela
## que só conhece a própria tecla não tem como saber disso. Foi assim que este
## almanaque abriu ATRÁS do painel de missões e devolveu a câmera solta ao
## fechar.
##
## Fechado, este nó não escuta nada.
func _unhandled_key_input(event: InputEvent) -> void:
	if not _aberto:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.physical_keycode:
		KEY_UP, KEY_W:
			_andar(-1)
		KEY_DOWN, KEY_S:
			_andar(1)
		KEY_LEFT, KEY_A, KEY_BACKSPACE:
			_voltar()
		KEY_RIGHT, KEY_D, KEY_ENTER, KEY_KP_ENTER:
			_abrir_no_cursor()
		_:
			if event.physical_keycode == Atalhos.tecla("interagir"):
				_abrir_no_cursor()
			else:
				return
	get_viewport().set_input_as_handled()
