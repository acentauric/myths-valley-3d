extends CanvasLayer
## A TEIA DE TALENTOS no vale (tecla K), lida do `Talentos` compartilhado.
##
## O SISTEMA JÁ ESTAVA AQUI. `Talentos` é autoload compartilhado com o jogo 2D
## desde a Fase 2 da migração: os 37 nós, as raízes, o custo, as exigências, o
## XP por ação, o nível e a soma dos bônus — inclusive a soma com a fé — são de
## lá, byte a byte, e nada disso foi reescrito. O que faltava no vale era só
## PODER OLHAR: sem tela, o jogador subia de nível e os pontos ficavam num
## número que ninguém via.
##
##
## POR QUE É ÁRVORE E NÃO LISTA
##
## A tela do 2D (`scripts/ui/talentos_tela.gd`, 1495 linhas) desenha uma teia
## numa tela própria: nós espalhados, fios curvos, três faixas que não se
## pisam. Trazer aquele arquivo seria trazer o desenho de um jogo de cima para
## um jogo de trás, com a resolução e a fonte de lá.
##
## Mas uma LISTA também não serve, e essa era a tentação: a informação que
## importa num talento é de quem ele depende, e lista não mostra dependência.
## Um nó que exige outro é a razão de a teia existir.
##
## Então: a coluna da esquerda é o ÍNDICE DAS RAÍZES, como as seções do
## almanaque — Terra, Mata, Água, o que o `Talentos.raizes()` devolver. À
## direita, a raiz escolhida é desenhada como ÁRVORE DE VERDADE: uma coluna por
## degrau de exigência, e um fio de cada nó para quem ele exige. Quem não exige
## ninguém fica na primeira coluna; quem exige, uma coluna à frente de quem
## exige.
##
## É a mesma divisão índice-e-página do almanaque e do painel, de propósito: três
## telas com formas diferentes é o jogador reaprendendo a ler em cada uma.
##
##
## GASTAR PONTO ACONTECE AQUI, e o `Talentos` é quem decide
##
## O E sobre um nó chama `Talentos.destravar`, que recusa sozinho quando falta
## ponto ou falta o nó de antes — e o `impedimento` devolve a frase de por quê,
## escrita no 2D. Esta tela não repete nenhuma dessas regras: ela pergunta e
## mostra a resposta. Repetir seria ter duas versões da regra, e uma delas fica
## velha.

signal abriu
signal fechou

const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")

const COR_FUNDO := Color(0.055, 0.082, 0.070, 0.985)
const COR_TEXTO := Identidade.TEXTO
const COR_APAGADA := Color(0.55, 0.58, 0.52)
const COR_PRONTO := Color("9fd89a")
const COR_TRAVADO := Color(0.46, 0.49, 0.44)

const TAMANHO := Vector2(980, 600)
const LARGURA_DAS_RAIZES := 250.0
const ALTURA_DA_LINHA := 30.0

## Medidas do desenho da árvore, em pixels.
const NO_LARGURA := 168.0
const NO_ALTURA := 54.0
const VAO_COLUNA := 56.0
const VAO_LINHA := 18.0

var aberta := false

var _caixa: PanelContainer
var _caminho: Label
var _raizes_coluna: VBoxContainer
var _tela_da_arvore: Control
var _ficha: VBoxContainer
var _rodape: Label

## Raiz aberta, e o nó em foco dentro dela.
var _raiz := ""
var _no := ""
## Os nós na ordem em que o teclado anda: por coluna, de cima para baixo.
var _ordem: Array[String] = []
## id do nó → o painel dele na tela, para pintar o foco sem redesenhar tudo.
var _caixinhas: Dictionary = {}


func _ready() -> void:
	# Acima do HUD (20) e do painel (25), junto do menu do Esc (27).
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	visible = false
	Talentos.mudou.connect(func() -> void: if aberta: _encher())


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

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 12)
	_caixa.add_child(coluna)

	_caminho = Label.new()
	_caminho.name = "Caminho"
	_caminho.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 500, 2))
	_caminho.add_theme_font_size_override("font_size", 19)
	_caminho.add_theme_color_override("font_color", Identidade.OURO)
	Identidade.sombra_texto(_caminho)
	coluna.add_child(_caminho)
	coluna.add_child(Identidade.divisor())

	var lado_a_lado := HBoxContainer.new()
	lado_a_lado.add_theme_constant_override("separation", 22)
	lado_a_lado.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(lado_a_lado)

	_raizes_coluna = VBoxContainer.new()
	_raizes_coluna.name = "Raizes"
	_raizes_coluna.add_theme_constant_override("separation", 2)
	_raizes_coluna.custom_minimum_size = Vector2(LARGURA_DAS_RAIZES, 0)
	lado_a_lado.add_child(_raizes_coluna)
	lado_a_lado.add_child(VSeparator.new())

	var direita := VBoxContainer.new()
	direita.add_theme_constant_override("separation", 10)
	direita.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	direita.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lado_a_lado.add_child(direita)

	# A ÁRVORE ROLA NOS DOIS EIXOS: uma raiz larga não cabe, e cortar o fio de
	# uma exigência é esconder justamente o que a teia serve para mostrar.
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	direita.add_child(rolagem)
	_tela_da_arvore = Control.new()
	_tela_da_arvore.name = "Arvore"
	rolagem.add_child(_tela_da_arvore)

	_ficha = VBoxContainer.new()
	_ficha.name = "Ficha"
	_ficha.add_theme_constant_override("separation", 4)
	_ficha.custom_minimum_size = Vector2(0, 104)
	direita.add_child(_ficha)

	_rodape = Label.new()
	_rodape.name = "Rodape"
	_rodape.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 400))
	_rodape.add_theme_font_size_override("font_size", 14)
	_rodape.add_theme_color_override("font_color", COR_APAGADA)
	coluna.add_child(_rodape)


func abrir() -> void:
	if aberta:
		return
	if _raiz == "" or not Talentos.raizes().has(_raiz):
		var todas := Talentos.raizes()
		_raiz = str(todas[0]) if not todas.is_empty() else ""
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
	_caminho.text = "Habilidades  ›  %s        nível %d  ·  %d/%d de experiência  ·  %s" % [
		_raiz if _raiz != "" else "—", Talentos.nivel, int(Talentos.xp),
		Talentos.xp_do_nivel(), _texto_dos_pontos()]
	_montar_raizes()
	_montar_arvore()
	_montar_ficha()
	_rodape.text = "↑↓ ou W/S: andar    ·    ←→ ou A/D: trocar de raiz    ·    E ou Enter: destravar    ·    %s ou Esc: fechar" \
		% OS.get_keycode_string(Atalhos.tecla("talentos"))


func _texto_dos_pontos() -> String:
	if Talentos.pontos == 0:
		return "nenhum ponto para gastar"
	return "1 ponto para gastar" if Talentos.pontos == 1 else "%d pontos para gastar" % Talentos.pontos


func _montar_raizes() -> void:
	for filho in _raizes_coluna.get_children():
		filho.queue_free()
	for bruta in Talentos.raizes():
		var raiz := str(bruta)
		var aberta_agora: bool = raiz == _raiz
		var linha := Button.new()
		linha.focus_mode = Control.FOCUS_NONE
		linha.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		linha.custom_minimum_size = Vector2(0, ALTURA_DA_LINHA + 4.0)
		linha.alignment = HORIZONTAL_ALIGNMENT_LEFT
		linha.text = ("▾ " if aberta_agora else "▸ ") + raiz + "    " + _conta_da_raiz(raiz)
		linha.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600))
		linha.add_theme_font_size_override("font_size", 16)
		linha.add_theme_color_override("font_color",
			Identidade.OURO if aberta_agora else COR_APAGADA)
		linha.add_theme_color_override("font_hover_color", Identidade.CREME)
		for estado in ["normal", "hover", "pressed"]:
			linha.add_theme_stylebox_override(estado, _estilo_da_linha(aberta_agora, estado != "normal"))
		linha.pressed.connect(func() -> void: _escolher_raiz(raiz))
		_raizes_coluna.add_child(linha)


## "3 de 8" da raiz: quantos nós dela o jogador já destravou.
func _conta_da_raiz(raiz: String) -> String:
	var nos: Array = Talentos.nos_da_raiz(raiz)
	var tem := 0
	for no in nos:
		if Talentos.tem(str(no)):
			tem += 1
	return "%d de %d" % [tem, nos.size()]


## A ÁRVORE DA RAIZ: uma coluna por degrau de exigência, e um fio para cada
## exigência.
##
## O degrau de um nó é UM MAIS o maior degrau dos que ele exige — quem não exige
## ninguém está no degrau zero. É a única conta desta tela, e ela é sobre o dado
## do `Talentos`, não sobre desenho: nó que ganhar uma exigência nova anda de
## coluna sozinho.
func _montar_arvore() -> void:
	for filho in _tela_da_arvore.get_children():
		filho.queue_free()
	_caixinhas.clear()
	_ordem.clear()
	if _raiz == "":
		return

	var nos: Array = Talentos.nos_da_raiz(_raiz)
	var degrau: Dictionary = {}
	for no in nos:
		degrau[str(no)] = _degrau_de(str(no), nos)

	# Agrupa por coluna, mantendo a ordem do dado dentro de cada uma.
	var colunas: Dictionary = {}
	for no in nos:
		var d: int = int(degrau[str(no)])
		if not colunas.has(d):
			colunas[d] = []
		(colunas[d] as Array).append(str(no))

	var chaves := colunas.keys()
	chaves.sort()
	var centro: Dictionary = {}
	var maior_altura := 0.0
	for d in chaves:
		var lista: Array = colunas[d]
		var x: float = float(d) * (NO_LARGURA + VAO_COLUNA)
		for i in lista.size():
			var no := str(lista[i])
			var y: float = float(i) * (NO_ALTURA + VAO_LINHA)
			var caixinha := _caixinha_do_no(no)
			caixinha.position = Vector2(x, y)
			_tela_da_arvore.add_child(caixinha)
			_caixinhas[no] = caixinha
			centro[no] = Vector2(x + NO_LARGURA, y + NO_ALTURA * 0.5)
			_ordem.append(no)
			maior_altura = maxf(maior_altura, y + NO_ALTURA)
	_tela_da_arvore.custom_minimum_size = Vector2(
		float(chaves[chaves.size() - 1] + 1) * (NO_LARGURA + VAO_COLUNA), maior_altura + 8.0)

	# OS FIOS, desenhados por baixo dos nós: entram como primeiros filhos.
	for no in nos:
		for exigido in (Talentos.dados(str(no)).get("exige", []) as Array):
			if not _caixinhas.has(str(exigido)):
				continue
			var de: Vector2 = centro[str(exigido)]
			var para: Vector2 = (_caixinhas[str(no)] as Control).position + Vector2(0.0, NO_ALTURA * 0.5)
			var fio := _fio(de, para, Talentos.tem(str(exigido)))
			_tela_da_arvore.add_child(fio)
			_tela_da_arvore.move_child(fio, 0)

	if _no == "" or not _ordem.has(_no):
		_no = str(_ordem[0]) if not _ordem.is_empty() else ""
	_pintar_foco()


## O degrau do nó: um mais o maior degrau dos que ele exige, dentro desta raiz.
func _degrau_de(no: String, nos_da_raiz: Array, profundidade: int = 0) -> int:
	if profundidade > 12:
		return 0            # exigência circular: para de descer em vez de travar
	var maior := -1
	for exigido in (Talentos.dados(no).get("exige", []) as Array):
		if not nos_da_raiz.has(str(exigido)):
			continue
		maior = maxi(maior, _degrau_de(str(exigido), nos_da_raiz, profundidade + 1))
	return maior + 1


func _caixinha_do_no(no: String) -> Button:
	var dado: Dictionary = Talentos.dados(no)
	var botao := Button.new()
	botao.name = "No_" + no
	botao.focus_mode = Control.FOCUS_NONE
	botao.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	botao.custom_minimum_size = Vector2(NO_LARGURA, NO_ALTURA)
	botao.size = Vector2(NO_LARGURA, NO_ALTURA)
	botao.alignment = HORIZONTAL_ALIGNMENT_CENTER
	botao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	botao.text = str(dado.get("nome", no))
	botao.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 500))
	botao.add_theme_font_size_override("font_size", 16)
	# A COR DIZ O ESTADO, e são três: destravado, pronto para destravar, e
	# travado. É a informação que o jogador procura ao abrir a tela.
	var cor := COR_TRAVADO
	if Talentos.tem(no):
		cor = Identidade.OURO
	elif Talentos.pode(no):
		cor = COR_PRONTO
	botao.add_theme_color_override("font_color", cor)
	botao.add_theme_color_override("font_hover_color", Identidade.CREME)
	for estado in ["normal", "hover", "pressed"]:
		botao.add_theme_stylebox_override(estado, _estilo_do_no(no, estado != "normal"))
	botao.pressed.connect(func() -> void:
		_no = no
		_montar_ficha()
		_pintar_foco())
	return botao


func _estilo_do_no(no: String, realce: bool) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	var dono: bool = Talentos.tem(no)
	var pronto: bool = not dono and Talentos.pode(no)
	estilo.bg_color = Color(0.13, 0.17, 0.12, 0.95) if not realce else Color(0.18, 0.22, 0.16, 0.98)
	estilo.border_color = Identidade.OURO if dono else (COR_PRONTO if pronto else Color(0.3, 0.33, 0.29, 0.9))
	estilo.set_border_width_all(2 if dono or pronto else 1)
	estilo.set_corner_radius_all(4)
	estilo.content_margin_left = 8
	estilo.content_margin_right = 8
	return estilo


## O FIO DE UMA EXIGÊNCIA. Dourado quando o de trás já é do jogador, apagado
## quando não — o fio conta o caminho já andado.
func _fio(de: Vector2, para: Vector2, andado: bool) -> Line2D:
	var linha := Line2D.new()
	linha.width = 2.0 if andado else 1.0
	linha.default_color = Color(Identidade.OURO.r, Identidade.OURO.g, Identidade.OURO.b,
		0.7 if andado else 0.22)
	# Curva em S: dois pontos de meio-caminho, que é o que faz o fio não cortar
	# a caixa do vizinho quando os dois nós estão em linhas diferentes.
	var meio := (de.x + para.x) * 0.5
	linha.points = PackedVector2Array([de, Vector2(meio, de.y), Vector2(meio, para.y), para])
	# `Line2D` é Node2D e não Control: não tem `mouse_filter`, e por ser Node2D
	# ele não intercepta clique de Control nenhum. O fio é só desenho.
	return linha


## A FICHA DO NÓ EM FOCO: o que ele faz, o que custa, e por que não dá ainda.
##
## A frase do impedimento é do `Talentos` — "Precisa de X antes", "Falta ponto:
## 0 de 1" —, escrita no 2D. Reescrevê-la aqui seria ter duas versões da mesma
## explicação.
func _montar_ficha() -> void:
	for filho in _ficha.get_children():
		filho.queue_free()
	if _no == "":
		_ficha.add_child(_corpo("Escolha uma raiz à esquerda."))
		return
	var dado: Dictionary = Talentos.dados(_no)

	var nome := Label.new()
	nome.text = str(dado.get("nome", _no))
	nome.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600, 1))
	nome.add_theme_font_size_override("font_size", 22)
	nome.add_theme_color_override("font_color", Identidade.CREME)
	_ficha.add_child(nome)
	_ficha.add_child(_corpo(str(dado.get("resumo", ""))))

	var estado := ""
	if Talentos.tem(_no):
		estado = "Você tem este talento."
	else:
		var trava := str(Talentos.impedimento(_no))
		var custo := int(dado.get("custo", 1))
		estado = "Custa %s.  %s" % [
			"1 ponto" if custo == 1 else "%d pontos" % custo,
			"Aperte E para destravar." if trava == "" else trava]
	var linha := _corpo(estado)
	linha.add_theme_color_override("font_color",
		Identidade.OURO if Talentos.tem(_no) else (COR_PRONTO if Talentos.pode(_no) else COR_APAGADA))
	_ficha.add_child(linha)


func _corpo(texto: String) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 400))
	rotulo.add_theme_font_size_override("font_size", 18)
	rotulo.add_theme_color_override("font_color", COR_TEXTO)
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return rotulo


func _estilo_da_linha(escolhida: bool, realce: bool) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	if escolhida:
		estilo.bg_color = Color(0.19, 0.21, 0.15, 0.96)
		estilo.border_color = Color(Identidade.OURO.r, Identidade.OURO.g, Identidade.OURO.b, 0.75)
		estilo.border_width_left = 2
	elif realce:
		estilo.bg_color = Color(0.13, 0.16, 0.12, 0.9)
	else:
		estilo.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	estilo.content_margin_left = 10
	estilo.content_margin_right = 10
	return estilo


## O foco é um anel a mais em volta do nó, por cima da cor de estado. São duas
## coisas: a cor diz o que o nó É, o anel diz onde a próxima tecla vai agir.
func _pintar_foco() -> void:
	for no in _caixinhas:
		var botao := _caixinhas[no] as Button
		if not is_instance_valid(botao):
			continue
		var estilo := _estilo_do_no(str(no), false)
		if str(no) == _no:
			estilo.border_color = Identidade.CREME
			estilo.set_border_width_all(3)
		botao.add_theme_stylebox_override("normal", estilo)


func _escolher_raiz(raiz: String) -> void:
	if _raiz == raiz:
		return
	_raiz = raiz
	_no = ""
	_encher()


func _andar_raiz(passo: int) -> void:
	var todas := Talentos.raizes()
	if todas.is_empty():
		return
	var onde := todas.find(_raiz)
	_escolher_raiz(str(todas[wrapi(onde + passo, 0, todas.size())]))


func _andar(passo: int) -> void:
	if _ordem.is_empty():
		return
	var onde := _ordem.find(_no)
	_no = _ordem[wrapi(onde + passo, 0, _ordem.size())]
	_montar_ficha()
	_pintar_foco()


## Gasta o ponto, e quem decide é o `Talentos`.
##
## `destravar` recusa sozinho quando falta ponto ou falta o nó de antes; esta
## tela só refaz o desenho depois. Ela não repete nenhuma dessas regras.
func _destravar() -> void:
	if _no == "":
		return
	if Talentos.destravar(_no):
		Audio.efeito("ui_confirmar")
	else:
		Audio.efeito("ui_trava")
	_encher()


func _unhandled_key_input(event: InputEvent) -> void:
	if not aberta:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_UP, KEY_W:
			_andar(-1)
		KEY_DOWN, KEY_S:
			_andar(1)
		KEY_LEFT, KEY_A:
			_andar_raiz(-1)
		KEY_RIGHT, KEY_D:
			_andar_raiz(1)
		KEY_ENTER, KEY_KP_ENTER:
			_destravar()
		_:
			if event.physical_keycode == Atalhos.tecla("interagir"):
				_destravar()
			else:
				return
	get_viewport().set_input_as_handled()
