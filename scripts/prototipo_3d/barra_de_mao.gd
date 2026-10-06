extends Control
## A BARRA DE MÃO do vale: os dez primeiros espaços do `Inventario`, embaixo.
##
## O `Inventario` é o do jogo 2D, compartilhado, e ele já tinha tudo — trinta
## espaços, os dez primeiros de mão, `selecionar`, `alternar` e o estado de mão
## livre. O que faltava aqui era MOSTRAR: sem barra na tela, ganhar um machado
## não tem efeito visível, e o jogador não tem como saber que a ferramenta está
## com ele. Foi a queixa exata de quem jogou.
##
## Não é a barra do 2D copiada. A de lá mora dentro do `hud.gd` daquele jogo,
## junto com o relógio e o fôlego, e o vale tem HUD próprio — trazer o arquivo
## inteiro seria trocar o HUD do protótipo, que é o que este plano não faz. O
## que veio de lá foi a REGRA, que é a parte que importa: quantos espaços, qual
## é o da mão, o que é estar de mão livre.
##
## O ícone do item é o PNG de 32px do 2D (`assets/sprites/itens/`, iguais byte a
## byte aos de lá) — `Catalogo.icone` procura e devolve `null` sem reclamar.
## Item sem PNG mostra a inicial, que é o que o próprio 2D faz com nó de
## talento sem ícone.

const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const FocoDoE = preload("res://scripts/prototipo_3d/foco_do_e.gd")

const LARGURA := 52.0
const ALTURA := 52.0
const VAO := 6.0
const MARGEM_DE_BAIXO := 18.0

const FUNDO := Color(0.055, 0.085, 0.075, 0.86)
const BORDA := Color(0.42, 0.36, 0.22, 0.9)
const BORDA_NA_MAO := Color("e0c179")
const PAPEL := Color("f3ead3")
const APAGADO := Color(0.62, 0.58, 0.48)

var _espacos: Array[Panel] = []
var _rotulo_do_item: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Continua ouvindo com o jogo pausado: é ela que fecha a mochila.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# A BARRA OCUPA A TELA INTEIRA e põe a fila onde quer, em vez de tentar ser
	# uma faixa no rodapé.
	#
	# A primeira versão usava `PRESET_BOTTOM_WIDE` neste nó e depois mexia em
	# `position` da fila antes de mexer nas âncoras — e a barra não aparecia.
	# Dois enganos somados: o preset num nó recém-criado calcula os offsets a
	# partir de um tamanho que ainda é zero, e escrever `position` ANTES das
	# âncoras é escrever num valor que a âncora recalcula em seguida.
	#
	# Âncora primeiro, offset depois. É a ordem que o Godot espera, e não há
	# atalho para ela.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_montar()
	Inventario.mudou.connect(_repintar)
	_repintar()


func _montar() -> void:
	var total := Inventario.ESPACOS_MAO
	var largura_total := total * LARGURA + (total - 1) * VAO

	var fila := HBoxContainer.new()
	fila.name = "Fila"
	fila.add_theme_constant_override("separation", int(VAO))
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fila)
	# Presa ao meio de baixo: âncoras nos dois lados no centro e no rodapé, e
	# os offsets medindo a partir dali.
	fila.anchor_left = 0.5
	fila.anchor_right = 0.5
	fila.anchor_top = 1.0
	fila.anchor_bottom = 1.0
	fila.offset_left = -largura_total * 0.5
	fila.offset_right = largura_total * 0.5
	fila.offset_top = -ALTURA - MARGEM_DE_BAIXO
	fila.offset_bottom = -MARGEM_DE_BAIXO

	for i in total:
		var espaco := Panel.new()
		espaco.custom_minimum_size = Vector2(LARGURA, ALTURA)
		# O ESPAÇO ACEITA CLIQUE. Antes a barra inteira era `IGNORE` — desenho e
		# nada mais —, e a única forma de comer era abrir a mochila. Agora clicar
		# num espaço o põe na mão, e clicar no que JÁ está na mão come, se der.
		espaco.mouse_filter = Control.MOUSE_FILTER_STOP
		espaco.gui_input.connect(_ao_clicar_no_espaco.bind(i))
		fila.add_child(espaco)
		_espacos.append(espaco)

		# O NÚMERO DA TECLA no canto, pequeno. Sem ele a barra é bonita e muda:
		# o jogador vê dez quadrados e não sabe que são teclas.
		var numero := Label.new()
		numero.text = "0" if i == 9 else str(i + 1)
		numero.add_theme_font_size_override("font_size", 11)
		numero.add_theme_color_override("font_color", APAGADO)
		numero.position = Vector2(5.0, 2.0)
		numero.mouse_filter = Control.MOUSE_FILTER_IGNORE
		espaco.add_child(numero)

		# O que está no espaço: a inicial do item enquanto não há ícone, e a
		# quantidade quando é mais de um.
		var conteudo := Label.new()
		conteudo.name = "Conteudo"
		conteudo.add_theme_font_size_override("font_size", 18)
		conteudo.add_theme_color_override("font_color", PAPEL)
		conteudo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		conteudo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		conteudo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		conteudo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		conteudo.z_index = 2
		conteudo.add_theme_color_override("font_shadow_color", Color(0.02, 0.025, 0.02, 0.95))
		conteudo.add_theme_constant_override("shadow_offset_x", 1)
		conteudo.add_theme_constant_override("shadow_offset_y", 1)
		espaco.add_child(conteudo)

		var icone := TextureRect.new()
		icone.name = "Icone"
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icone.offset_left = 6.0
		icone.offset_top = 6.0
		icone.offset_right = -6.0
		icone.offset_bottom = -6.0
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		espaco.add_child(icone)

	# O NOME DO QUE ESTÁ NA MÃO, acima da barra. É o que responde "o que eu
	# estou segurando?" sem o jogador ter de decorar ícone.
	_rotulo_do_item = Label.new()
	_rotulo_do_item.name = "NaMao"
	_rotulo_do_item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo_do_item.add_theme_font_size_override("font_size", 14)
	_rotulo_do_item.add_theme_color_override("font_color", BORDA_NA_MAO)
	_rotulo_do_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rotulo_do_item)
	_rotulo_do_item.anchor_left = 0.0
	_rotulo_do_item.anchor_right = 1.0
	_rotulo_do_item.anchor_top = 1.0
	_rotulo_do_item.anchor_bottom = 1.0
	_rotulo_do_item.offset_left = 0.0
	_rotulo_do_item.offset_right = 0.0
	_rotulo_do_item.offset_top = -ALTURA - MARGEM_DE_BAIXO - 24.0
	_rotulo_do_item.offset_bottom = -ALTURA - MARGEM_DE_BAIXO - 4.0


func _repintar() -> void:
	for i in _espacos.size():
		var espaco := _espacos[i]
		var na_mao := Inventario.selecionado == i
		espaco.add_theme_stylebox_override("panel", _moldura(na_mao))

		var id := ""
		var quantos := 0
		if i < Inventario.espacos.size():
			var dado: Dictionary = Inventario.espacos[i]
			id = str(dado.get("id", ""))
			quantos = int(dado.get("qtd", 0))

		var conteudo := espaco.get_node("Conteudo") as Label
		var icone := espaco.get_node("Icone") as TextureRect
		if id == "":
			conteudo.text = ""
			icone.texture = null
			continue

		var textura := Catalogo.icone(id)
		icone.texture = textura
		var nome := str(Catalogo.ITENS.get(id, {}).get("nome", id))
		# Com ícone, o texto é só a quantidade; sem ícone, a inicial faz as
		# vezes dele — é o que o 2D faz com nó de talento sem arte.
		if textura != null:
			conteudo.text = str(quantos) if quantos > 1 or id == "madeira_de_coqueiro" else ""
			conteudo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			conteudo.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			conteudo.add_theme_font_size_override("font_size", 14)
		else:
			conteudo.text = nome.substr(0, 2) if quantos <= 1 else "%s %d" % [nome.substr(0, 2), quantos]
			conteudo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_rotulo_do_item.text = _nome_na_mao()


func _nome_na_mao() -> String:
	var id := Inventario.na_mao()
	if id == "":
		return "mão livre"
	return str(Catalogo.ITENS.get(id, {}).get("nome", id))


func _moldura(na_mao: bool) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = FUNDO
	estilo.border_color = BORDA_NA_MAO if na_mao else BORDA
	estilo.set_border_width_all(2 if na_mao else 1)
	estilo.set_corner_radius_all(4)
	return estilo


## AS TECLAS DA MÃO, 1 a 0.
##
## A regra é a do 2D e vem do `Inventario`: apertar o número que já está na mão
## SOLTA o item — é assim que se fica de mão livre, que é o estado de colher.
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	# O I E O ESC SAÍRAM DAQUI. Quem abre e fecha a mochila agora é o
	# `telas_do_vale.gd`, porque abrir uma tela tem de fechar a outra — e uma
	# tela que só conhece a própria tecla não pode saber disso. Ver o cabeçalho
	# de lá: foi assim que o almanaque abriu ATRÁS do painel e devolveu a câmera
	# solta.
	#
	# O que ficou aqui é o que é da barra: as dez teclas da mão.
	#
	# COM O VALE PARADO, A TECLA É DE QUEM O PAROU. Toda tela para o vale — a
	# mochila, o painel, o almanaque, o menu, o papel do cordel —, e a fala e o
	# cartão do amanhecer também (#21). Esta barra ouve com o vale parado, e
	# ouve ANTES das telas que escutam no `_unhandled_input` (no Godot 4 o
	# `_unhandled_key_input` vem antes): o número trocava a mão por baixo de
	# qualquer tela, e o E comia o que estava na mão com o arraial, o papel ou
	# o cartão abertos. A fala conta também um quadro depois de fechar
	# (`ocupado`), quando o vale já voltou a andar.
	if get_tree().paused or Mochila.aberta or Dialogo.ocupado():
		return

	# Alt segurado é gesto do personagem, não barra de mão.
	if event.alt_pressed:
		return
	for i in Inventario.ESPACOS_MAO:
		if event.is_action_pressed("mv_mao_%d" % (i + 1)):
			Inventario.alternar(i)
			get_viewport().set_input_as_handled()
			return

	# O E COME O QUE ESTÁ NA MÃO, e é o último da fila do E: só quando o foco não
	# deu a tecla a ninguém (`foco_do_e.gd`). Ver `_comer_da_mao`.
	if event.physical_keycode == Atalhos.tecla("interagir") and _corpo_de_pe() \
			and not FocoDoE.alguem(self) and _comer_da_mao():
		get_viewport().set_input_as_handled()


## O CORPO DO JOGADOR ESTÁ DE PÉ? No escuro da queda (e no susto do tubarão) ele
## está parado, e o E que o mundo não pega — achados, pesca, luta, recursos,
## árvores e lápides perguntam pelo corpo — caía aqui e comia: desacordado não
## come. Sem jogador na árvore (um portão sem o vale), vale de pé.
func _corpo_de_pe() -> bool:
	var jogador := get_tree().get_first_node_in_group("map_player")
	return jogador == null or jogador.is_physics_processing()


## A MOCHILA ABRE E FECHA DAQUI, e não do `Prototype`.
##
## A razão é a pausa. Abrir a mochila pausa o vale com `get_tree().paused`, e
## nó pausável não recebe mais tecla — o `Prototype` inclusive. Se o `I`
## morasse lá, ele abriria a mochila e nunca mais a fecharia.
##
## Esta barra roda em `PROCESS_MODE_ALWAYS` justamente para continuar ouvindo
## com o jogo parado, e é o lugar coerente: ela já é a mão do jogador na tela.
signal mochila_mudou(aberta: bool)


func _abrir_ou_fechar_a_mochila() -> void:
	if Mochila.aberta:
		Mochila.fechar()
	else:
		Mochila.abrir()
	mochila_mudou.emit(Mochila.aberta)


## QUANTO DO RODAPÉ A BARRA OCUPA, do fundo da tela para cima.
##
## Existe para quem desenha por perto não ter de adivinhar. O aviso de
## interação ficava a 31–64 px do rodapé, dentro desta faixa, e a barra — que
## entra depois no HUD — o cobria. Um número mágico no outro arquivo
## consertaria hoje e quebraria na próxima vez que a barra mudasse de altura.
static func altura_ocupada() -> float:
	# A fila, a margem de baixo e o rótulo do que está na mão, com folga.
	return MARGEM_DE_BAIXO + ALTURA + 24.0 + 8.0


## COMER O QUE ESTÁ NA MÃO, pela tecla de interagir.
##
## "Apertando E ou clicando com o mouse em itens consumíveis na mão ativa do
## jogador, deve ser consumido. Só consegui consumir clicando dentro do
## inventário."
##
## A regra de comer é do `Cozinha.comer`, compartilhado com o 2D: ele repõe
## fôlego, cura vida quando o item cura, corta peçonha quando corta, concede o
## efeito de dias e soma os talentos da panela. Nada disso está reescrito aqui —
## esta barra só pergunta "o que está na mão dá para comer?" e manda comer.
##
##
## POR QUE O E DAQUI É O ÚLTIMO DA FILA
##
## O E é disputado: perto de uma árvore ele abre a ficha, perto de um tronco ele
## golpeia, perto de uma lápide ele lê. Comer é o que sobra — e sobra de fato,
## porque esta barra mora DENTRO do HUD, que entra no vale antes dos nós do mundo
## (`Recursos3D`, `ArvoresInfo`, `Lapides`). O Godot entrega `_unhandled_input`
## de baixo para cima na árvore, então quem entrou depois responde primeiro: eles
## consomem a tecla quando têm o que fazer, e ela só chega aqui quando não têm.
##
## Isso é ordem de árvore, que é coisa que muda quando alguém acrescenta um nó —
## e é por isso que `tests/barra_de_mao.gd` mede a precedência de verdade: com um
## alvo de trabalho ao alcance, o E tem de golpear e NÃO comer.
func _comer_da_mao() -> bool:
	var id := Inventario.na_mao()
	if not Cozinha.e_comida(id):
		return false
	# ACIMA DO TETO, PERGUNTA (#105): o que a comida repõe além do máximo da
	# reserva vai fora. A caixa pergunta, e só o "sim" come — o item fica na mão
	# até lá. Pedido do autor, duas vezes.
	var sobra: float = Energia.atual + Cozinha.reposicao(id) - Energia.maximo()
	if sobra > 0.5:
		_perguntar_e_comer(id, sobra)
		return true
	return Cozinha.comer(id)


func _perguntar_e_comer(id: String, sobra: float) -> void:
	var sim: bool = await Dialogo.perguntar("", tr("Comer agora joga fora %d de fôlego. Comer assim mesmo?") % roundi(sobra))
	if sim and Inventario.na_mao() == id:
		Cozinha.comer(id)


## Clique num espaço da barra: põe na mão, e no que já está na mão, come.
##
## Duas coisas na mesma tecla, e a ordem é a que o jogador espera: o primeiro
## clique escolhe, o segundo usa. Quando o que está na mão não é comida, o
## segundo clique faz o que o número da tecla faz — solta o item e deixa a mão
## livre, que é o estado de colher (regra do `Inventario`, do 2D).
func _ao_clicar_no_espaco(evento: InputEvent, qual: int) -> void:
	if not (evento is InputEventMouseButton and evento.pressed
			and (evento as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return
	if Inventario.selecionado == qual:
		if not _comer_da_mao():
			Inventario.alternar(qual)
	else:
		Inventario.selecionar(qual)
	accept_event()
