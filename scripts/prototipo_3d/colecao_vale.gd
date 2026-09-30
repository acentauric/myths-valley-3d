extends CanvasLayer
## A COLEÇÃO (tecla L) no vale: cordéis, sinais e bichos. É a
## `scripts/ui/colecao_tela.gd` do 2D trazida para cá (#20), e pela mesma
## razão do painel é cópia adaptada: o 2D a abre pelo `Telas` e lê o cordel no
## `Folheto`, que o vale ainda não tem. A regra é o `Colecao` compartilhado.
##
## Duas colunas: à esquerda a lista do que existe, com as VAGAS EM BRANCO de
## quem ainda não foi achado — coleção que só mostra o que se tem é
## inventário, e é o buraco na estante que faz procurar (ver o 2D); à direita
## a ficha da peça escolhida.
##
## O QUE MUDOU DO 2D PARA CÁ:
##
## - A medida e a cara do HUD do vale, e as linhas são botões de verdade (no
##   2D, uma folha de vidro convertia a altura do ponteiro em linha).
## - As teclas do vale: Tab troca de coleção, W/S ou as setas escolhem, L ou
##   Esc fecham. O relógio que para é o `Dia`.
## - O CORDEL AINDA NÃO SE LÊ: no 2D o E abre o folheto, com a xilogravura e a
##   estrofe no papel, e o folheto é da #21. Até lá a ficha mostra a primeira
##   linha do verso — que é o que ela já mostrava no 2D, de chamariz —, e o
##   rodapé não oferece um [E] que não abriria nada.

signal abriu
signal fechou

const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")

const COR_TITULO := Color("d6ba78")
const COR_TEXTO := Color("e8e4d7")
const COR_APAGADA := Color("8f9a8f")
const COR_CURSOR := Color("f2d27a")
const COR_VERSO := Color("e0dac8")
const COR_FUNDO := Color(0.055, 0.085, 0.075, 0.97)
const COR_BORDA := Color(0.84, 0.73, 0.47, 0.8)

const TAMANHO := Vector2(900, 520)
const LARGURA_DA_LISTA := 330.0
const ALTURA_DA_LINHA := 28.0

var aberta: bool = false

var _colecao: String = "cordeis"
var _cursor: int = 0
var _dia_pausado_antes := false

var _titulo: Label
var _lista: VBoxContainer
var _peca: Label
var _rodape: Label
var _linhas: Array = []


func _ready() -> void:
	# No mesmo andar do painel: por cima do HUD, abaixo da tela da queda.
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	visible = false
	Colecao.mudou.connect(func(): if aberta: _redesenhar())


func abrir() -> void:
	if aberta:
		return
	aberta = true
	_cursor = 0
	visible = true
	_dia_pausado_antes = Dia.pausado
	Dia.pausado = true
	abriu.emit()
	_redesenhar()


func fechar() -> void:
	if not aberta:
		return
	aberta = false
	visible = false
	Dia.pausado = _dia_pausado_antes
	fechou.emit()


func colecao() -> String:
	return _colecao


func _unhandled_input(evento: InputEvent) -> void:
	if not aberta:
		return
	if not (evento is InputEventKey and evento.pressed and not evento.echo):
		return
	var tecla: int = evento.physical_keycode
	if tecla == KEY_ESCAPE or tecla == Atalhos.tecla("colecao"):
		fechar()
	elif tecla == KEY_TAB:
		proxima_colecao()
	elif evento.is_action_pressed("mv_forward"):
		_mover(-1)
	elif evento.is_action_pressed("mv_back"):
		_mover(1)
	else:
		return
	get_viewport().set_input_as_handled()


func escolher(indice: int) -> void:
	var total := Colecao.ordem(_colecao).size()
	if total == 0:
		return
	_cursor = clampi(indice, 0, total - 1)
	_redesenhar()


func _mover(passo: int) -> void:
	var total := Colecao.ordem(_colecao).size()
	if total == 0:
		return
	_cursor = wrapi(_cursor + passo, 0, total)
	Audio.efeito("menu_mover")
	_redesenhar()


func proxima_colecao() -> void:
	var nomes := Colecao.COLECOES.keys()
	var onde := nomes.find(_colecao)
	_colecao = str(nomes[(onde + 1) % nomes.size()])
	_cursor = 0
	Audio.efeito("menu_mover")
	_redesenhar()


# --- montagem ----------------------------------------------------------------

func _montar() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0.02, 0.03, 0.03, 0.62)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fundo)

	var caixa := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_FUNDO
	estilo.border_color = COR_BORDA
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(10)
	estilo.set_content_margin_all(18)
	caixa.add_theme_stylebox_override("panel", estilo)
	caixa.set_anchors_preset(Control.PRESET_CENTER)
	caixa.custom_minimum_size = TAMANHO
	caixa.offset_left = -TAMANHO.x * 0.5
	caixa.offset_right = TAMANHO.x * 0.5
	caixa.offset_top = -TAMANHO.y * 0.5
	caixa.offset_bottom = TAMANHO.y * 0.5
	add_child(caixa)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 10)
	caixa.add_child(coluna)

	var topo := HBoxContainer.new()
	coluna.add_child(topo)
	_titulo = _rotulo("", 22, COR_TITULO)
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(_titulo)
	topo.add_child(_botao_pequeno("OUTRA ▶", proxima_colecao))
	topo.add_child(_botao_pequeno("×", fechar))

	var lado_a_lado := HBoxContainer.new()
	lado_a_lado.add_theme_constant_override("separation", 22)
	lado_a_lado.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(lado_a_lado)

	# A coluna dos títulos rola: coleção que corta no rodapé esconde justamente
	# o que falta achar (ver o 2D).
	var rolagem := ScrollContainer.new()
	rolagem.custom_minimum_size = Vector2(LARGURA_DA_LISTA, 0)
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lado_a_lado.add_child(rolagem)
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 3)
	_lista.custom_minimum_size = Vector2(LARGURA_DA_LISTA - 12, 0)
	rolagem.add_child(_lista)

	_peca = _rotulo("", 16, COR_VERSO)
	_peca.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_peca.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_peca.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lado_a_lado.add_child(_peca)

	_rodape = _rotulo("", 13, COR_APAGADA)
	_rodape.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(_rodape)


func _rotulo(texto: String, tamanho: int, cor: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.add_theme_font_size_override("font_size", tamanho)
	etiqueta.add_theme_color_override("font_color", cor)
	return etiqueta


func _botao_pequeno(texto: String, ao_apertar: Callable) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.focus_mode = Control.FOCUS_NONE
	botao.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	botao.custom_minimum_size = Vector2(30, 26)
	botao.add_theme_font_size_override("font_size", 15)
	botao.add_theme_color_override("font_color", COR_APAGADA)
	botao.add_theme_color_override("font_hover_color", COR_CURSOR)
	for estado in ["normal", "hover", "pressed", "focus"]:
		botao.add_theme_stylebox_override(estado, _estilo_da_linha(false, estado != "normal"))
	botao.pressed.connect(ao_apertar)
	return botao


func _estilo_da_linha(escolhida: bool, realce: bool) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	if escolhida:
		estilo.bg_color = Color(0.2, 0.22, 0.16, 0.95)
		estilo.border_color = COR_CURSOR
		estilo.set_border_width_all(1)
	elif realce:
		estilo.bg_color = Color(0.14, 0.17, 0.13, 0.85)
	else:
		estilo.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	estilo.set_corner_radius_all(5)
	estilo.content_margin_left = 8
	estilo.content_margin_right = 8
	return estilo


func _redesenhar() -> void:
	if not aberta:
		return
	for linha in _linhas:
		linha.queue_free()
	_linhas.clear()

	var dados: Dictionary = Colecao.COLECOES[_colecao]
	_titulo.text = "%s      %d de %d" % [dados["nome"], Colecao.quantos(_colecao), Colecao.total(_colecao)]

	var ids := Colecao.ordem(_colecao)
	for i in ids.size():
		var id := str(ids[i])
		var achado := Colecao.tem(_colecao, id)
		# Vaga em branco: o jogador vê QUANTOS faltam sem saber quais são.
		var nome := str(Colecao.dados(_colecao, id).get("titulo", id)) if achado else "— — —"
		var cor := COR_CURSOR if i == _cursor else (COR_TEXTO if achado else COR_APAGADA)
		var botao := Button.new()
		botao.text = "%s  %s" % ["✓" if achado else "·", nome]
		botao.alignment = HORIZONTAL_ALIGNMENT_LEFT
		botao.focus_mode = Control.FOCUS_NONE
		botao.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		botao.custom_minimum_size = Vector2(0, ALTURA_DA_LINHA)
		botao.clip_text = true
		botao.add_theme_font_size_override("font_size", 16)
		botao.add_theme_color_override("font_color", cor)
		botao.add_theme_color_override("font_hover_color", COR_CURSOR)
		for estado in ["normal", "hover", "pressed", "focus"]:
			botao.add_theme_stylebox_override(estado, _estilo_da_linha(i == _cursor, estado == "hover"))
		var indice := i
		botao.pressed.connect(func(): escolher(indice))
		_lista.add_child(botao)
		_linhas.append(botao)

	_peca.text = ficha(str(ids[_cursor]) if _cursor < ids.size() else "")
	_rodape.text = "[W/S] escolher · [Tab] outra coleção · [%s] fechar      %s" % [
		Atalhos.letra("colecao"), dados["resumo"]]


## A FICHA da peça: o que é, de quem é, onde estava e quanto vale (ver o 2D).
func ficha(id: String) -> String:
	if Colecao.tipo(_colecao) == "sinal":
		return _ficha_de_sinal(id)
	if Colecao.tipo(_colecao) == "bicho":
		return _ficha_de_bicho(id)
	if id == "" or not Colecao.tem(_colecao, id):
		return "Esta vaga está vazia.\n\nHá folhetos embaixo de banco de capela, dentro de lata no píer, presos em pedra na beira do rio. Quem anda olhando acha."
	var dado := Colecao.dados(_colecao, id)
	var texto := "%s\n%s\n\n" % [dado.get("titulo", id), dado.get("autor", "")]
	var versos: Array = dado.get("versos", [])
	if not versos.is_empty():
		texto += "   %s…\n\n" % Jogo.texto(str(versos[0]))
	texto += "Achado %s.\nVale %d réis." % [str(dado.get("onde", "por aí")), int(dado.get("valor", 0))]
	return texto


## A página de um bicho: o que se aprendeu brigando com ele, onde mora e quantos
## já caíram — a parede da Guilda do Stardew (ver o 2D).
func _ficha_de_bicho(id: String) -> String:
	if id == "" or not Colecao.tem(_colecao, id):
		return "Esta vaga está vazia.\n\nBicho se conhece brigando com ele. Há mais na mata do que nesta página."
	var dado := Colecao.dados(_colecao, id)
	var texto := "%s\n\n" % str(dado.get("titulo", id))
	for linha in (dado.get("ficha", []) as Array):
		texto += "%s\n" % Jogo.texto(str(linha))
	texto += "\nMora %s.\nJá caíram: %d.\n" % [str(dado.get("onde", "na mata")), Luta.abatidos(id)]
	var meta: Dictionary = dado.get("meta", {})
	if not meta.is_empty():
		if Missoes.cumprida(str(meta.get("missao", ""))):
			texto += "\n%s\n" % Jogo.texto(str(meta.get("premio", "")))
		else:
			texto += "\n%s (%d de %d)\n" % [Jogo.texto(str(meta.get("promessa", ""))),
				mini(Luta.abatidos(id), int(meta.get("conta", 1))), int(meta.get("conta", 1))]
	return texto


## A ficha de um sinal, que NÃO TEM NOME até o encontro acontecer (ver
## `Colecao.nomeia` e o 2D): pôr o nome antes seria o jogo respondendo o
## enigma na mesma tela em que o propõe.
func _ficha_de_sinal(id: String) -> String:
	if id == "" or not Colecao.tem(_colecao, id):
		return "Esta vaga está vazia.\n\nSinal não se procura: se topa. Água parada, mata que cala de repente, bicho que some do caminho. Quando acontecer, olhe o chão antes de ir embora."
	var dado := Colecao.dados(_colecao, id)
	var texto := "%s\n\n" % str(dado.get("titulo", id))
	for linha in (dado.get("sinal", []) as Array):
		texto += "%s\n" % Jogo.texto(str(linha))
	texto += "\nVisto %s, %s.\n" % [str(dado.get("onde", "por aí")), str(dado.get("quando", "num dia qualquer"))]
	if Colecao.nomeia(_colecao, id):
		texto += "\n"
		for linha in (dado.get("revelado", []) as Array):
			texto += "%s\n" % Jogo.texto(str(linha))
	else:
		texto += "\nVocê não sabe de quem era. Ainda."
	return texto
