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
const FichasDaColecao = preload("res://scripts/prototipo_3d/fichas_da_colecao.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
## De onde vem a dica de reler o cordel no papel: é o que se lê sobre cordel.
const TEXTOS_DOS_ACHADOS := "res://data/achados.json"

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

## AS SEÇÕES DO ALMANAQUE, e de onde cada uma tira o que mostra.
##
## O almanaque nasceu só das plantas, ganhou as três coleções e agora as
## receitas. A cada uma que chegava, três funções desta tela ganhavam um `if` a
## mais — a lista, a conta e a página —, e a quarta ia ganhar outro. Isso é o
## arquivo crescendo por dentro sem crescer em ideia.
##
## Então a seção passou a DIZER DE ONDE VEM o que ela mostra, em vez de a tela
## adivinhar. Cada uma traz `fonte`, com três perguntas:
##
##     ids()        quais peças existem, na ordem em que se leem
##     conhece(id)  o jogador já tem essa?
##     nome(id)     como ela se chama (ou a vaga em branco)
##     pagina(id)   o texto da ficha dela
##
## As PLANTAS não usam `fonte`: elas têm um elo a mais na cadeia — o grupo —,
## porque dezoito espécies numa lista são um rolo. Seção nova que precise de dois
## níveis vai precisar de código; as que cabem numa lista, não.
const PLANTAS := "plantas"
const SECOES := [
	{"chave": PLANTAS, "nome": "Plantas do vale",
		"resumo": "O que cresce aqui, e para que serve. Cada espécie entra na primeira vez que você chega perto e olha."},
	{"chave": "cordeis", "nome": "Cordéis",
		"resumo": "Folhetos de verso, achados pelo caminho. Leia com calma: há mais neles do que rima."},
	{"chave": "sinais", "nome": "Sinais",
		"resumo": "O que fica para trás quando alguma coisa passa. Você viu, anotou, e não sabe o nome."},
	{"chave": "bichos", "nome": "Bichos",
		"resumo": "Quem mora na mata e no mar. Bicho se conhece brigando com ele."},
	{"chave": "receitas", "nome": "Receitas de cozinha",
		"resumo": "O que a panela do vale sabe fazer. Cada uma se aprende de um jeito: vendo, comprando, cumprindo um favor ou abrindo um passo."},
]

## Seção aberta na cadeia, "" quando ela mostra só as seções.
var _secao := PLANTAS
## Grupo de plantas aberto, "" quando nenhum. Só vale na seção das plantas.
var _grupo := ""
## A peça aberta na página: espécie nas plantas, id da peça nas coleções.
var _escolhido := ""
## Onde está o cursor do teclado, na ordem em que as linhas aparecem.
var _cursor := 0
## As linhas de agora, na ordem da tela: {"tipo": "secao"|"grupo"|"item", "chave"}.
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
## Pedido para reler um cordel no papel (#21). Quem abre o `Folheto` é o vale,
## que é o dono das telas: este almanaque fecha e, guardado o papel, reabre
## onde estava.
signal ler_no_papel(id: String)

var _dica_do_papel := ""


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
	# meio de uma página e reabre quer aquela página. Se a peça deixou de valer
	# — planta que não está mais na lista —, cai no elo de cima.
	if _secao == PLANTAS and _escolhido != "" and not conhece(_escolhido):
		_escolhido = ""
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
	_montar_cadeia()
	_montar_pagina()
	_cursor = clampi(_cursor, 0, maxi(0, _linhas.size() - 1))
	_pintar_cursor()
	_rodape.text = "↑↓ ou W/S: andar    ·    E ou Enter: abrir    ·    ←: voltar    ·    %s ou Esc: fechar" \
		% OS.get_keycode_string(Atalhos.tecla("almanaque"))
	if _secao == "cordeis" and _escolhido != "" and Colecao.tem("cordeis", _escolhido):
		_rodape.text += "    ·    " + _dica_de_reler()


func _dica_de_reler() -> String:
	if _dica_do_papel == "":
		var lido = JSON.parse_string(FileAccess.get_file_as_string(TEXTOS_DOS_ACHADOS))
		var dado = lido.get("ler_no_papel", {}) if lido is Dictionary else {}
		_dica_do_papel = str(IdiomaMenu.campo(dado if dado is Dictionary else {}, "texto", ""))
	return _dica_do_papel


func _texto_do_caminho() -> String:
	var partes: Array[String] = ["Almanaque"]
	if _secao != "":
		partes.append(_nome_da_secao(_secao))
	if _secao == PLANTAS and _grupo != "":
		partes.append(str((_grupos.get(_grupo, {}) as Dictionary).get("nome", _grupo)))
	if _escolhido != "":
		partes.append(_nome_do_escolhido())
	return "  ›  ".join(partes) + "  ·  " + _conta_da_secao(_secao if _secao != "" else PLANTAS)


func _nome_do_escolhido() -> String:
	if _secao == PLANTAS:
		return str((_fichas.get(_escolhido, {}) as Dictionary).get("nome", _escolhido))
	return str((_fonte(_secao)["nome"] as Callable).call(_escolhido))


## A coluna da esquerda: as seções, e dentro da seção aberta o que ela guarda.
##
## A cadeia se ABRE NO LUGAR — entrar numa seção não troca de tela, e é o que
## deixa o caminho de volta visível sem botão de voltar. Nas plantas há um elo a
## mais, o grupo, porque dezoito espécies numa lista são um rolo; nas coleções
## não, porque cada uma tem dez peças e a lista cabe.
func _montar_cadeia() -> void:
	for dados in SECOES:
		var secao := str(dados["chave"])
		if secao == PLANTAS and conhecidas().is_empty() and _secao != PLANTAS:
			# Seção vazia continua aparecendo: diferente das peças, ela não é
			# spoiler — o jogador precisa saber que existe um lugar para plantas.
			pass
		var aberta: bool = secao == _secao
		var linha := _linha_da_cadeia(str(dados["nome"]), _conta_da_secao(secao), 0, aberta)
		linha.pressed.connect(_escolher_secao.bind(secao))
		_cadeia.add_child(linha)
		_linhas.append({"tipo": "secao", "chave": secao, "no": linha})
		if not aberta:
			continue
		if secao == PLANTAS:
			_montar_plantas()
		else:
			_montar_pecas(secao)


func _montar_plantas() -> void:
	for chave in grupos_com_algo():
		var grupo := str(chave)
		var ficha: Dictionary = _grupos.get(grupo, {})
		var quantas := conhecidas_do_grupo(grupo).size()
		var linha := _linha_da_cadeia(str(ficha.get("nome", grupo)),
			"%d de %d" % [quantas, total_do_grupo(grupo)], 1, grupo == _grupo)
		linha.pressed.connect(_escolher_grupo.bind(grupo))
		_cadeia.add_child(linha)
		_linhas.append({"tipo": "grupo", "chave": grupo, "no": linha})
		if grupo != _grupo:
			continue
		for bruto in conhecidas_do_grupo(grupo):
			var especie := str(bruto)
			var nome := str((_fichas.get(especie, {}) as Dictionary).get("nome", especie))
			var filha := _linha_da_cadeia(nome, "", 2, especie == _escolhido)
			filha.pressed.connect(_escolher_item.bind(especie))
			_cadeia.add_child(filha)
			_linhas.append({"tipo": "item", "chave": especie, "no": filha})


## As peças de uma seção, COM AS VAGAS EM BRANCO.
##
## Aqui a regra é a oposta da das plantas, e as duas estão certas. Planta não
## conhecida não aparece: o almanaque é sobre o que se viu, e lista com buraco
## numerado viraria caça ao item. Peça de coleção e receita aparecem como
## "— — —", porque são COLEÇÃO: é o buraco na estante que faz procurar, e é
## assim no 2D.
##
## Quem sabe quais peças existem é a FONTE da seção, e não esta função. Ver
## `_fonte`.
func _montar_pecas(secao: String) -> void:
	var fonte := _fonte(secao)
	for bruto in (fonte["ids"] as Callable).call():
		var id := str(bruto)
		var linha := _linha_da_cadeia((fonte["nome"] as Callable).call(id), "", 1, id == _escolhido)
		if not bool((fonte["conhece"] as Callable).call(id)):
			linha.add_theme_color_override("font_color", APAGADO)
		linha.pressed.connect(_escolher_item.bind(id))
		_cadeia.add_child(linha)
		_linhas.append({"tipo": "item", "chave": id, "no": linha})


func _nome_da_secao(secao: String) -> String:
	for dados in SECOES:
		if str(dados["chave"]) == secao:
			return str(dados["nome"])
	return secao


func _resumo_da_secao(secao: String) -> String:
	for dados in SECOES:
		if str(dados["chave"]) == secao:
			return str(dados["resumo"])
	return ""


## "4 de 18" da seção. As plantas contam aqui; o resto pergunta à fonte.
func _conta_da_secao(secao: String) -> String:
	if secao == PLANTAS:
		return "%d de %d" % [conhecidas().size(), total()]
	var fonte := _fonte(secao)
	return "%d de %d" % [int((fonte["sabidas"] as Callable).call()),
		int((fonte["quantas"] as Callable).call())]


## A página da direita: a peça escolhida; sem peça, o resumo da seção; sem
## seção, o convite.
func _montar_pagina() -> void:
	if _secao == PLANTAS and _escolhido != "":
		_pagina_da_planta()
		return
	if _secao != "" and _secao != PLANTAS and _escolhido != "":
		var fonte := _fonte(_secao)
		_titulo_da_pagina(str((fonte["nome"] as Callable).call(_escolhido)))
		_pagina.add_child(_filete())
		_pagina.add_child(_corpo(str((fonte["pagina"] as Callable).call(_escolhido))))
		return
	if _secao == PLANTAS and _grupo != "":
		var ficha: Dictionary = _grupos.get(_grupo, {})
		_titulo_da_pagina(str(ficha.get("nome", _grupo)))
		_pagina.add_child(_filete())
		_pagina.add_child(_corpo(str(ficha.get("resumo", ""))))
		_pagina.add_child(_corpo("%s espécies deste grupo você já viu de perto."
			% ("%d de %d" % [conhecidas_do_grupo(_grupo).size(), total_do_grupo(_grupo)])))
		return
	if _secao != "":
		_titulo_da_pagina(_nome_da_secao(_secao))
		_pagina.add_child(_filete())
		_pagina.add_child(_corpo(_resumo_da_secao(_secao)))
		if _secao == PLANTAS and conhecidas().is_empty():
			_pagina.add_child(_corpo("Nada ainda. Chegue perto de uma planta e aperte E: a primeira vez que você olha uma espécie, ela entra aqui."))
		return
	_pagina.add_child(_corpo("Abra uma seção à esquerda. As plantas entram na primeira vez que você chega perto delas; os cordéis, os sinais e os bichos, quando você os encontra pelo vale."))


func _pagina_da_planta() -> void:
	var ficha: Dictionary = _fichas.get(_escolhido, {})
	_titulo_da_pagina(str(ficha.get("nome", _escolhido)))
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


func _titulo_da_pagina(texto: String) -> void:
	var nome := Label.new()
	nome.text = texto
	nome.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600, 1))
	nome.add_theme_font_size_override("font_size", 28)
	nome.add_theme_color_override("font_color", Identidade.CREME)
	nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Identidade.sombra_texto(nome)
	_pagina.add_child(nome)


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


func _linha_da_cadeia(texto: String, conta: String, nivel: int, escolhida: bool) -> Button:
	var botao := Button.new()
	botao.focus_mode = Control.FOCUS_NONE
	botao.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	botao.custom_minimum_size = Vector2(0, ALTURA_DA_LINHA)
	botao.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# O nível vira recuo: seção na margem, e um passo por elo. É o que faz a
	# cadeia parecer cadeia sem precisar de desenho.
	var marca := ""
	if nivel < 2:
		marca = "▾ " if escolhida else "▸ "
	botao.text = "    ".repeat(nivel) + marca + texto
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


# --- andar na cadeia ---------------------------------------------------------

func _escolher_secao(secao: String) -> void:
	# Apertar a seção aberta FECHA ela, como toda árvore de índice faz.
	if _secao == secao:
		_secao = ""
	else:
		_secao = secao
	_grupo = ""
	_escolhido = ""
	_encher()


func _escolher_grupo(grupo: String) -> void:
	_grupo = "" if _grupo == grupo else grupo
	_escolhido = ""
	_encher()


func _escolher_item(item: String) -> void:
	# O CORDEL JÁ ABERTO, ESCOLHIDO DE NOVO, SE LÊ NO PAPEL (#21): o segundo E,
	# ou o segundo clique, como o da barra de mão. A ficha mostra a primeira
	# estrofe; o papel é o folheto inteiro, como a coleção do 2D abre.
	if item == _escolhido and _secao == "cordeis" and Colecao.tem("cordeis", item):
		ler_no_papel.emit(item)
		return
	_escolhido = item
	if _secao == PLANTAS:
		_grupo = grupo_de(item)
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
		var chave := str(linha["chave"])
		var escolhida := false
		match str(linha["tipo"]):
			"secao":
				escolhida = chave == _secao and _grupo == "" and _escolhido == ""
			"grupo":
				escolhida = chave == _grupo and _escolhido == ""
			"item":
				escolhida = chave == _escolhido
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
	match str(linha["tipo"]):
		"secao":
			_escolher_secao(str(linha["chave"]))
		"grupo":
			_escolher_grupo(str(linha["chave"]))
		_:
			_escolher_item(str(linha["chave"]))
	# Depois de abrir um elo, a lista cresceu: o cursor fica onde estava, que é
	# a linha do próprio elo, e não salta para o começo.
	_cursor = clampi(guardado, 0, maxi(0, _linhas.size() - 1))
	_pintar_cursor()


## Um passo atrás na cadeia: da página para o elo de cima, até a raiz.
func _voltar() -> void:
	if _escolhido != "":
		_escolhido = ""
	elif _grupo != "":
		_grupo = ""
	elif _secao != "":
		_secao = ""
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


## DE ONDE UMA SEÇÃO TIRA O QUE MOSTRA.
##
## Quatro perguntas, e a tela não sabe responder nenhuma: quais peças existem,
## se o jogador já tem cada uma, como ela se chama e o que a ficha dela diz.
##
## As três coleções vêm do `Colecao` compartilhado com o 2D; as receitas, do
## `Receitas` e do `Cozinha`, também compartilhados. Nenhuma dessas regras foi
## reescrita aqui — o que é daqui é a cadeia de índices em volta delas.
func _fonte(secao: String) -> Dictionary:
	if secao == "receitas":
		return {
			"ids": func() -> Array: return _receitas_do_vale(),
			"conhece": func(id: String) -> bool: return Receitas.sabe(id),
			"nome": func(id: String) -> String:
				return str(Cozinha.RECEITAS.get(id, {}).get("nome", id)) if Receitas.sabe(id) else "— — —",
			"quantas": func() -> int: return _receitas_do_vale().size(),
			"sabidas": func() -> int:
				var conta := 0
				for id in _receitas_do_vale():
					if Receitas.sabe(str(id)):
						conta += 1
				return conta,
			"pagina": func(id: String) -> String: return _pagina_da_receita(id),
		}
	return {
		"ids": func() -> Array: return Colecao.ordem(secao),
		"conhece": func(id: String) -> bool: return Colecao.tem(secao, id),
		"nome": func(id: String) -> String: return FichasDaColecao.nome_na_lista(secao, id),
		"quantas": func() -> int: return Colecao.total(secao),
		"sabidas": func() -> int: return Colecao.quantos(secao),
		"pagina": func(id: String) -> String: return FichasDaColecao.pagina(secao, id),
	}


## AS RECEITAS DE PANELA, e só elas.
##
## O `Receitas.tudo()` junta panela, oficina e obra — é o que as bancadas usam.
## Aqui a seção é "receitas de cozinha", e pôr o banco de carpinteiro dentro dela
## seria o almanaque dizendo uma coisa e mostrando outra. Quando a oficina e as
## obras quiserem seção, elas ganham a sua.
func _receitas_do_vale() -> Array:
	var lista: Array = Cozinha.RECEITAS.keys()
	lista.sort()
	return lista


## A FICHA DE UMA RECEITA: o que ela faz, o que custa e o que rende.
##
## Receita não sabida não mostra nada disso — mostra COMO SE APRENDE, que é a
## informação útil de uma vaga em branco. As portas são as do `Receitas`:
## "comeco", "missao", "morador", "grau", "achado", "compra".
func _pagina_da_receita(id: String) -> String:
	var dado: Dictionary = Cozinha.RECEITAS.get(id, {})
	if dado.is_empty():
		return "Esta receita não existe mais."
	if not Receitas.sabe(id):
		return "Você ainda não sabe fazer isto.\n\n%s" % _como_se_aprende(id)
	var texto := "%s\n\n" % str(dado.get("resumo", ""))
	var custo: Dictionary = dado.get("custo", {})
	if not custo.is_empty():
		var partes: Array[String] = []
		for item in custo:
			partes.append("%s ×%d" % [Catalogo.nome(str(item)), int(custo[item])])
		texto += "Leva: %s.\n" % ", ".join(partes)
	texto += "Rende %d.\n" % int(dado.get("rende", 1))
	if float(dado.get("folego", 0.0)) > 0.0:
		texto += "Alimenta %d de %s." % [int(dado["folego"]), Energia.nome_recurso()]
	return texto


func _como_se_aprende(id: String) -> String:
	var portas: Dictionary = Receitas.portas_de(id)
	if portas.is_empty():
		return "Ninguém no vale ensina esta ainda."
	for porta in portas:
		match str(porta):
			"comeco":
				return "Esta você já devia saber — é das de começo."
			"compra":
				return "Vende-se no balcão, por %d réis." % int(portas[porta])
			"morador":
				return "Alguém do arraial ensina esta."
			"grau":
				return "Alguém do arraial ensina esta, quando houver confiança."
			"achado":
				return "Está escrita em alguma coisa que se acha por aí."
			"missao":
				return "Aprende-se fazendo: um passo do vale ensina esta."
	return "Há como aprender esta, e ainda não se sabe qual é o caminho."
