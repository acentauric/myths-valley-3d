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
## A TEIA DA FÉ, NO TAB (#52)
##
## "Aperte K e depois Tab: a teia da fé é outra teia", diz a Dona Zefa no 2D. É
## a mesma tela com outra fonte: o `Fe` compartilhado responde às mesmas
## perguntas que o `Talentos` (raízes, nós, quem exige quem, o impedimento, o
## destravar) sobre a árvore da fé ATIVA — e o que ele não sabe responder, esta
## tela não inventa. Sem fé ainda, a página diz as três e onde cada uma se
## pratica. E há uma raiz a mais, "Regras da fé", que não é árvore: é o que a
## fé cobra e o que ela dá — a espera de cada marco, a bênção de agora, as
## festas, as fés congeladas e o preço de trocar.
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
const COR_APAGADA := Identidade.COR_LEITURA_APAGADA
const COR_PRONTO := Color("9fd89a")
const COR_TRAVADO := Color(0.46, 0.49, 0.44)

const TAMANHO := Vector2(980, 600)
const LARGURA_DAS_RAIZES := 250.0
const ALTURA_DA_LINHA := 30.0
## A largura do texto da página da fé: linhas curtas, de uns 60 caracteres, que se
## leem sem pular de uma ponta à outra (#199).
const LARGURA_DO_TEXTO_DA_FE := 560.0

## Medidas do desenho da árvore, em pixels.
const NO_LARGURA := 168.0
const NO_ALTURA := 54.0
## O ÍCONE DO TALENTO vem do jogo 2D (`assets/sprites/talentos`), copiado para
## cá enquanto não houver arte própria do 3D: é decisão do autor, e é melhor um
## desenho feito para o talento certo do que caixa de texto sozinha. Quem não
## tiver arquivo fica só com o nome, e a teia não quebra por isso.
const PASTA_DOS_ICONES := "res://assets/sprites/talentos/"
const LADO_DO_ICONE := 32.0
const RECUO_DO_ICONE := 9.0
## Onde o texto começa quando há ícone, para o nome não sair por cima dele.
const MARGEM_SIMPLES := 8
const MARGEM_COM_ICONE := int(RECUO_DO_ICONE + LADO_DO_ICONE + 6.0)
const VAO_COLUNA := 56.0
const VAO_LINHA := 18.0

## As duas teias que o Tab alterna.
const MODO_OFICIO := "oficio"
const MODO_FE := "fe"
## A raiz da fé que não é árvore: a página das regras.
const REGRAS := "regras"
## As palavras da fé nos três idiomas: nomes, resumos e onde cada uma se pratica.
const TEXTOS_DA_FE := "res://data/marcos_fe.json"
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
## O nome de cada marco na página das regras.
const NOMES_DOS_MARCOS := {
	"cruzeiro": "Cruzeiro", "capela": "Igreja do Bom Jesus", "capela_estrada": "Capela velha",
	"cemiterio": "Cemitério", "terreiro": "Terreiro", "gameleira": "Gameleira",
}

var aberta := false

var _caixa: PanelContainer
var _caminho: Label
var _raizes_coluna: VBoxContainer
var _tela_da_arvore: Control
var _ficha: VBoxContainer
var _rodape: HFlowContainer

## Raiz aberta, e o nó em foco dentro dela.
var _raiz := ""
var _no := ""
## Os nós na ordem em que o teclado anda: por coluna, de cima para baixo.
var _ordem: Array[String] = []
## Qual teia está aberta: a de ofício (`Talentos`) ou a da fé (`Fe`).
var _modo := MODO_OFICIO
var _textos_da_fe: Dictionary = {}
## id do nó → o painel dele na tela, para pintar o foco sem redesenhar tudo.
var _caixinhas: Dictionary = {}
var _rolagem: ScrollContainer
var _espaco_da_arvore: Control
var _zoom := 1.0
var _arrastando := false


func _ready() -> void:
	# Acima do HUD (20) e do painel (25), junto do menu do Esc (27).
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar()
	visible = false
	Talentos.mudou.connect(func() -> void: if aberta: _encher())
	Fe.mudou.connect(func() -> void: if aberta: _encher())
	# FÉ NOVA, ÁRVORE NOVA: a raiz que estava aberta era a da fé de antes (ou a
	# página das regras, a única que há sem fé). A próxima abertura começa na
	# primeira raiz da fé de agora.
	Fe.adotou.connect(func(_fe: String) -> void: _raiz = "")
	Fe.migrou.connect(func(_de: String, _para: String) -> void: _raiz = "")
	var lido = JSON.parse_string(FileAccess.get_file_as_string(TEXTOS_DA_FE))
	_textos_da_fe = lido if lido is Dictionary else {}


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
	Tela.vincular_componente(_caixa, "talentos", Vector2(0.5, 0.5))
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
	_rolagem = rolagem
	rolagem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	direita.add_child(rolagem)
	_espaco_da_arvore = Control.new()
	_espaco_da_arvore.name = "EspacoDaArvore"
	rolagem.add_child(_espaco_da_arvore)
	_tela_da_arvore = Control.new()
	_tela_da_arvore.name = "Arvore"
	_espaco_da_arvore.add_child(_tela_da_arvore)
	_tela_da_arvore.minimum_size_changed.connect(_dimensionar_zoom)
	var navegacao: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/navegacao_teia.json"))
	rolagem.tooltip_text = str(IdiomaMenu.campo(navegacao, "ajuda"))

	_ficha = VBoxContainer.new()
	_ficha.name = "Ficha"
	_ficha.add_theme_constant_override("separation", 4)
	_ficha.custom_minimum_size = Vector2(0, 104)
	direita.add_child(_ficha)

	# O rodapé de teclas é plaqueta + ação em leitura, como os atalhos do HUD (#199).
	_rodape = Identidade.rodape_de_teclas()
	coluna.add_child(_rodape)


## Quem responde pela teia aberta.
func _fonte() -> Node:
	return Fe if _modo == MODO_FE else Talentos


## As raízes da teia aberta. A da fé tem uma a mais, a das regras.
func _raizes() -> Array:
	var todas: Array = _fonte().raizes().duplicate()
	if _modo == MODO_FE:
		todas.append(REGRAS)
	return todas


## O Tab: da teia de ofício para a da fé, e de volta.
func trocar_de_teia() -> void:
	_modo = MODO_FE if _modo == MODO_OFICIO else MODO_OFICIO
	var todas := _raizes()
	_raiz = str(todas[0]) if not todas.is_empty() else ""
	_no = ""
	Audio.efeito("ui_confirmar")
	_encher()


func modo() -> String:
	return _modo


func abrir() -> void:
	if aberta:
		return
	if _raiz == "" or not _raizes().has(_raiz):
		var todas := _raizes()
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
	if _modo == MODO_FE:
		if Fe.ativa == "":
			_caminho.text = tr("Fé  ›  nenhuma ainda")
		else:
			_caminho.text = tr("Fé %s  ›  %s        nível %d  ·  %d/%d de experiência  ·  %s") % [
				_da_fe(Fe.ativa, "nome"), _nome_da_raiz(_raiz), Fe.nivel, int(Fe.xp),
				Fe.xp_do_nivel(), _texto_dos_pontos()]
	else:
		_caminho.text = "Habilidades  ›  %s        nível %d  ·  %d/%d de experiência  ·  %s" % [
			_raiz if _raiz != "" else "—", Talentos.nivel, int(Talentos.xp),
			Talentos.xp_do_nivel(), _texto_dos_pontos()]
	_montar_raizes()
	_montar_arvore()
	_montar_ficha()
	Identidade.refazer_rodape_de_teclas(_rodape, tr("↑↓ ou W/S: andar    ·    ←→ ou A/D: trocar de raiz    ·    E ou Enter: destravar    ·    Tab: %s    ·    %s ou Esc: fechar") \
		% [tr("a teia da fé") if _modo == MODO_OFICIO else tr("a teia de ofício"), OS.get_keycode_string(Atalhos.tecla("talentos"))])


func _nome_da_raiz(raiz: String) -> String:
	if raiz == REGRAS:
		return tr("Regras da fé")
	return raiz if raiz != "" else "—"


func _texto_dos_pontos() -> String:
	var pontos: int = int(_fonte().pontos)
	if pontos == 0:
		return "nenhum ponto para gastar"
	return "1 ponto para gastar" if pontos == 1 else "%d pontos para gastar" % pontos


func _montar_raizes() -> void:
	for filho in _raizes_coluna.get_children():
		filho.queue_free()
	for bruta in _raizes():
		var raiz := str(bruta)
		var aberta_agora: bool = raiz == _raiz
		var linha := Button.new()
		linha.focus_mode = Control.FOCUS_NONE
		linha.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		linha.custom_minimum_size = Vector2(0, ALTURA_DA_LINHA + 4.0)
		linha.alignment = HORIZONTAL_ALIGNMENT_LEFT
		linha.text = ("▾ " if aberta_agora else "▸ ") + _nome_da_raiz(raiz) + "    " + _conta_da_raiz(raiz)
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
	if raiz == REGRAS:
		return ""
	var nos: Array = _fonte().nos_da_raiz(raiz)
	var tem := 0
	for no in nos:
		if _fonte().tem(str(no)):
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
	if _modo == MODO_FE and (_raiz == REGRAS or Fe.ativa == ""):
		_no = ""
		_montar_pagina_da_fe()
		return
	if _raiz == "":
		return

	var nos: Array = _fonte().nos_da_raiz(_raiz)
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
		for exigido in (_fonte().dados(str(no)).get("exige", []) as Array):
			if not _caixinhas.has(str(exigido)):
				continue
			var de: Vector2 = centro[str(exigido)]
			var para: Vector2 = (_caixinhas[str(no)] as Control).position + Vector2(0.0, NO_ALTURA * 0.5)
			var fio := _fio(de, para, _fonte().tem(str(exigido)))
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
	for exigido in (_fonte().dados(no).get("exige", []) as Array):
		if not nos_da_raiz.has(str(exigido)):
			continue
		maior = maxi(maior, _degrau_de(str(exigido), nos_da_raiz, profundidade + 1))
	return maior + 1


## O desenho do talento, ou null quando não há arquivo para ele.
func _icone_do_talento(no: String) -> TextureRect:
	var caminho := PASTA_DOS_ICONES + no + ".png"
	if not ResourceLoader.exists(caminho):
		return null
	var arte := load(caminho)
	if arte == null:
		return null
	var quadro := TextureRect.new()
	quadro.texture = arte
	quadro.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	quadro.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	quadro.custom_minimum_size = Vector2(LADO_DO_ICONE, LADO_DO_ICONE)
	quadro.size = Vector2(LADO_DO_ICONE, LADO_DO_ICONE)
	quadro.position = Vector2(RECUO_DO_ICONE, (NO_ALTURA - LADO_DO_ICONE) * 0.5)
	# O clique é do nó inteiro: ícone que engole clique é meia caixinha morta.
	quadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# TALENTO TRAVADO FICA APAGADO, como o nome dele: o desenho tem de contar a
	# mesma coisa que a cor da letra, senão a teia diz duas coisas ao mesmo tempo.
	if not _fonte().tem(no):
		quadro.modulate = Color(1, 1, 1, 0.85 if _fonte().pode(no) else 0.45)
	return quadro


func _caixinha_do_no(no: String) -> Button:
	var dado: Dictionary = _fonte().dados(no)
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
	if _fonte().tem(no):
		cor = Identidade.OURO
	elif _fonte().pode(no):
		cor = COR_PRONTO
	botao.add_theme_color_override("font_color", cor)
	botao.add_theme_color_override("font_hover_color", Identidade.CREME)
	for estado in ["normal", "hover", "pressed"]:
		botao.add_theme_stylebox_override(estado, _estilo_do_no(no, estado != "normal"))
	var arte := _icone_do_talento(no)
	if arte != null:
		botao.add_child(arte)
	botao.pressed.connect(func() -> void:
		_no = no
		_montar_ficha()
		_pintar_foco())
	return botao


func _estilo_do_no(no: String, realce: bool) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	var dono: bool = _fonte().tem(no)
	var pronto: bool = not dono and _fonte().pode(no)
	estilo.bg_color = Color(0.13, 0.17, 0.12, 0.95) if not realce else Color(0.18, 0.22, 0.16, 0.98)
	estilo.border_color = Identidade.OURO if dono else (COR_PRONTO if pronto else Color(0.3, 0.33, 0.29, 0.9))
	estilo.set_border_width_all(2 if dono or pronto else 1)
	estilo.set_corner_radius_all(4)
	estilo.content_margin_left = MARGEM_COM_ICONE if ResourceLoader.exists(PASTA_DOS_ICONES + no + ".png") else MARGEM_SIMPLES
	estilo.content_margin_right = MARGEM_SIMPLES
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
	if _modo == MODO_FE and (_raiz == REGRAS or Fe.ativa == ""):
		return
	if _no == "":
		_ficha.add_child(_corpo("Escolha uma raiz à esquerda."))
		return
	var dado: Dictionary = _fonte().dados(_no)

	var nome := Label.new()
	nome.text = str(dado.get("nome", _no))
	Identidade.papel_titulo(nome)
	_ficha.add_child(nome)
	_ficha.add_child(_corpo(str(dado.get("resumo", ""))))

	var estado := ""
	if _fonte().tem(_no):
		estado = "Você tem este talento."
	else:
		var trava := str(_fonte().impedimento(_no))
		var custo := int(dado.get("custo", 1))
		estado = "Custa %s.  %s" % [
			"1 ponto" if custo == 1 else "%d pontos" % custo,
			"Aperte E para destravar." if trava == "" else trava]
	var linha := _corpo(estado)
	linha.add_theme_color_override("font_color",
		Identidade.OURO if _fonte().tem(_no) else (COR_PRONTO if _fonte().pode(_no) else COR_APAGADA))
	_ficha.add_child(linha)


## A PÁGINA DA FÉ QUE NÃO É ÁRVORE: sem fé, as três e onde cada uma se pratica;
## com fé, as regras — o que ela cobra e o que ela dá agora. Tudo lido do `Fe`
## e do `Ritos`; esta tela não guarda regra nenhuma.
##
## É TEXTO PARA LER, então segue os papéis da tipografia (#199): o nome de cada fé
## (e de cada marco) é subtítulo em ouro na Cinzel, o corpo é a sans do HUD em
## creme, em linhas curtas e parágrafos com respiro.
func _montar_pagina_da_fe() -> void:
	var pagina := VBoxContainer.new()
	pagina.name = "PaginaDaFe"
	pagina.add_theme_constant_override("separation", 14)
	pagina.custom_minimum_size = Vector2(LARGURA_DO_TEXTO_DA_FE + 10.0, 0)
	_tela_da_arvore.add_child(pagina)
	for bloco in blocos_da_pagina_da_fe():
		var caixa := VBoxContainer.new()
		caixa.add_theme_constant_override("separation", 3)
		if bool(bloco.get("recuo", false)):
			var recuado := MarginContainer.new()
			recuado.add_theme_constant_override("margin_left", 18)
			recuado.add_child(caixa)
			pagina.add_child(recuado)
		else:
			pagina.add_child(caixa)
		var titulo := str(bloco.get("titulo", ""))
		if titulo != "":
			var subtitulo := Identidade.papel_rotulo(Label.new(), 17)
			subtitulo.name = "NomeDaFe"
			subtitulo.text = titulo
			caixa.add_child(subtitulo)
		for paragrafo in (bloco.get("paragrafos", []) as Array):
			var rotulo := _corpo(str(paragrafo))
			rotulo.custom_minimum_size = Vector2(LARGURA_DO_TEXTO_DA_FE, 0)
			rotulo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			caixa.add_child(rotulo)
	_tela_da_arvore.custom_minimum_size = Vector2(LARGURA_DO_TEXTO_DA_FE + 10.0, 10.0)


## As linhas da página, sem a divisão em blocos. Pública para o portão ler.
func linhas_da_pagina_da_fe() -> Array:
	var linhas: Array = []
	for bloco in blocos_da_pagina_da_fe():
		var titulo := str(bloco.get("titulo", ""))
		var partes := PackedStringArray()
		for paragrafo in (bloco.get("paragrafos", []) as Array):
			partes.append(str(paragrafo))
		var corpo := " ".join(partes)
		linhas.append(corpo if titulo == "" else "%s — %s" % [titulo, corpo])
	return linhas


## Os blocos da página (ver `_montar_pagina_da_fe`): cada um é {titulo, paragrafos,
## recuo}. O título vazio é um parágrafo solto; `recuo` é o marco dentro da lista.
func blocos_da_pagina_da_fe() -> Array:
	var blocos: Array = []
	if Fe.ativa == "":
		blocos.append(_bloco("", [tr("Você ainda não é de fé nenhuma. No arraial há três, e cada uma se escolhe com os pés: no marco dela.")]))
		for fe in Fe.ids():
			blocos.append(_bloco(_da_fe(str(fe), "nome"), [_da_fe(str(fe), "resumo"), _da_fe(str(fe), "pratica")]))
		blocos.append(_bloco("", [tr("Uma fé por vez. A que você deixar congela inteira, e trocar de novo não apaga nada.")]))
		return blocos
	blocos.append(_bloco("", [tr("Você é %s: nível %d, %d ponto(s) para gastar.") % [_da_fe(Fe.ativa, "de"), Fe.nivel, Fe.pontos]]))
	for fe in Fe.ids():
		if str(fe) != Fe.ativa and Fe.conhecida(str(fe)):
			blocos.append(_bloco("", [tr("%s está congelada no nível %d, com %d ponto(s) e %d de acumulado. Voltar a ela devolve a teia como ficou.") % [
				_da_fe(str(fe), "nome"), Fe.nivel_da(str(fe)), Fe.pontos_da(str(fe)), Fe.total(str(fe))]]))
	blocos.append(_bloco("", [tr("Cada marco da sua fé dá graça uma vez a cada %d dia(s): fôlego, experiência de fé e uma bênção que dura %d dia(s).") % [Ritos.espera(), Ritos.duracao()]]))
	for marco in (Fe.dados_da_fe(Fe.ativa).get("marcos", []) as Array):
		var nome := tr(str(NOMES_DOS_MARCOS.get(str(marco), str(marco))))
		var estado: String
		if Ritos.pode_celebrar(str(marco)):
			estado = tr("dá graça hoje")
		else:
			estado = tr("a graça volta no %s") % Relogio.texto_do_dia(Ritos.dia_liberado(str(marco)))
		var bloco := _bloco(nome, [estado])
		bloco["recuo"] = true
		blocos.append(bloco)
	var bencao := Ritos.bencao_ativa()
	if bencao != "":
		blocos.append(_bloco("", [tr("Bênção de agora: %s, por mais %d dia(s).") % [bencao, Ritos.dias_de_bencao()]]))
	else:
		blocos.append(_bloco("", [tr("Nenhuma bênção agora.")]))
	var festa: Dictionary = Fe.festa(Fe.ativa)
	if not festa.is_empty():
		blocos.append(_bloco("", [tr("A festa da sua fé: %s. Nesse dia o marco dá graça mesmo fora do prazo, e quem é da fé se junta lá à tarde.") % str(festa.get("nome", ""))]))
	blocos.append(_bloco("", [tr("Trocar de fé não apaga nada: a teia de agora congela inteira e para de valer. Levar o acumulado junto custa caro: de cada cem pontos, chegam quinze.")]))
	return blocos


func _bloco(titulo: String, paragrafos: Array) -> Dictionary:
	var limpos: Array = []
	for paragrafo in paragrafos:
		if str(paragrafo).strip_edges() != "":
			limpos.append(str(paragrafo))
	return {"titulo": titulo, "paragrafos": limpos, "recuo": false}


func _da_fe(fe: String, campo: String) -> String:
	var dado: Dictionary = _textos_da_fe.get("fes", {}).get(fe, {})
	var escrito := str(IdiomaMenu.campo(dado, campo, ""))
	return escrito if escrito != "" else Fe.nome(fe)


## Texto para ler: a sans do HUD, em creme (papel de leitura, #199).
func _corpo(texto: String) -> Label:
	var rotulo := Label.new()
	rotulo.text = texto
	Identidade.papel_leitura(rotulo)
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
	var todas := _raizes()
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
	if _fonte().destravar(_no):
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
		KEY_TAB:
			trocar_de_teia()
		_:
			if event.physical_keycode == Atalhos.tecla("interagir"):
				_destravar()
			else:
				return
	get_viewport().set_input_as_handled()


## A escala pertence só à árvore; ficha, rodapé e teclas conservam o tamanho.
func _dimensionar_zoom() -> void:
	_tela_da_arvore.scale = Vector2.ONE * _zoom
	_tela_da_arvore.size = _tela_da_arvore.custom_minimum_size
	_espaco_da_arvore.custom_minimum_size = _tela_da_arvore.custom_minimum_size * _zoom

func _input(event: InputEvent) -> void:
	if not aberta:
		_arrastando = false
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
			_arrastando = false
			return
		var cursor: Vector2 = _rolagem.get_global_transform_with_canvas().affine_inverse() * event.position
		if not Rect2(Vector2.ZERO, _rolagem.size).has_point(cursor):
			return
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_arrastando = event.pressed
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var foco := (cursor + Vector2(_rolagem.scroll_horizontal, _rolagem.scroll_vertical)) / _zoom
			_zoom = clampf(_zoom * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 0.65, 1.8)
			_dimensionar_zoom()
			get_viewport().set_input_as_handled()
			await get_tree().process_frame
			if is_instance_valid(_rolagem):
				_rolagem.scroll_horizontal = roundi(foco.x * _zoom - cursor.x)
				_rolagem.scroll_vertical = roundi(foco.y * _zoom - cursor.y)
	elif event is InputEventMouseMotion and _arrastando:
		var movimento := _rolagem.get_global_transform_with_canvas().affine_inverse().basis_xform(event.relative)
		_rolagem.scroll_horizontal -= roundi(movimento.x)
		_rolagem.scroll_vertical -= roundi(movimento.y)
		get_viewport().set_input_as_handled()
