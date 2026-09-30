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
## coletar e interagir, e quem quiser reler abre o almanaque na tecla L — a
## mesma da coleção no jogo 2D.
##
## É a forma que o `Colecao` do 2D já usa para os bichos: "uma página por
## espécie, aberta na primeira que o jogador derruba". A diferença é que aquele
## é arquivo compartilhado e acrescentar "plantas" nele mexeria no jogo 2D por
## um recurso que é daqui. Quando as plantas do 2D quiserem almanaque, a lista
## muda de casa e esta tela passa a ler de lá.
##
##
## ONDE FICA GUARDADO
##
## `user://almanaque.cfg`, ao lado das preferências — e não no save da partida.
## A razão: o que o jogador APRENDEU sobre o mundo não é estado de partida, é
## dele. Recomeçar não desaprende que mangueira veio da Índia.

const DADOS := "res://data/arvores_3d.json"
const ARQUIVO := "user://almanaque.cfg"

const FUNDO := Color(0.043, 0.067, 0.059, 0.96)
const PAINEL := Color(0.094, 0.141, 0.125, 0.98)
const OURO := Color("c8a568")
const PAPEL := Color("f3ead3")
const APAGADO := Color(0.58, 0.55, 0.47)

## Espécie → ficha, lida do mesmo arquivo que as fichas do mundo usam.
static var _fichas: Dictionary = {}
## Espécies conhecidas, na ordem em que foram encontradas.
static var _conhecidas: Array = []
static var _lido := false

var _lista: VBoxContainer
var _titulo: Label
var _aberto := false


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
	cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cortina)

	var painel := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = PAINEL
	estilo.border_color = OURO
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(6)
	estilo.set_content_margin_all(24)
	painel.add_theme_stylebox_override("panel", estilo)
	add_child(painel)
	painel.anchor_left = 0.5
	painel.anchor_right = 0.5
	painel.anchor_top = 0.5
	painel.anchor_bottom = 0.5
	painel.offset_left = -360.0
	painel.offset_right = 360.0
	painel.offset_top = -260.0
	painel.offset_bottom = 260.0

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 10)
	painel.add_child(coluna)

	_titulo = Label.new()
	_titulo.add_theme_font_size_override("font_size", 26)
	_titulo.add_theme_color_override("font_color", OURO)
	coluna.add_child(_titulo)

	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(rolagem)

	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 16)
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(_lista)

	var rodape := Label.new()
	rodape.text = "L ou Esc: fechar"
	rodape.add_theme_font_size_override("font_size", 13)
	rodape.add_theme_color_override("font_color", APAGADO)
	coluna.add_child(rodape)


func aberto() -> bool:
	return _aberto


func alternar() -> void:
	if _aberto:
		fechar()
	else:
		abrir()


func abrir() -> void:
	_encher()
	visible = true
	_aberto = true


func fechar() -> void:
	visible = false
	_aberto = false


## A PÁGINA DE CADA ESPÉCIE CONHECIDA, na ordem em que foram encontradas.
##
## As não conhecidas não aparecem nem como silhueta. É de propósito: lista com
## buracos numerados vira caça ao item, e o almanaque é sobre o que se viu, não
## sobre o que falta ver.
func _encher() -> void:
	for filho in _lista.get_children():
		filho.queue_free()

	_titulo.text = "ALMANAQUE · %d de %d plantas" % [conhecidas().size(), total()]

	if conhecidas().is_empty():
		var vazio := Label.new()
		vazio.text = "Nada ainda. Chegue perto de uma planta e aperte E."
		vazio.add_theme_color_override("font_color", APAGADO)
		vazio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_lista.add_child(vazio)
		return

	for especie in conhecidas():
		var ficha: Dictionary = _fichas.get(especie, {})
		var nome := Label.new()
		nome.text = str(ficha.get("nome", especie))
		nome.add_theme_font_size_override("font_size", 19)
		nome.add_theme_color_override("font_color", PAPEL)
		_lista.add_child(nome)

		var cientifico := str(ficha.get("cientifico", ""))
		if cientifico != "":
			var latim := Label.new()
			latim.text = cientifico
			latim.add_theme_font_size_override("font_size", 13)
			latim.add_theme_color_override("font_color", APAGADO)
			_lista.add_child(latim)

		for pagina in ficha.get("paginas", []):
			var texto := Label.new()
			texto.text = str(pagina)
			texto.add_theme_font_size_override("font_size", 15)
			texto.add_theme_color_override("font_color", PAPEL)
			texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_lista.add_child(texto)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var esc: bool = _aberto and event.physical_keycode == KEY_ESCAPE
	if event.is_action_pressed("mv_almanaque") or esc:
		alternar()
		get_viewport().set_input_as_handled()
