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
## O ícone do item é o PNG de 32px do 2D, quando ele existe — `Catalogo.icone`
## já procura e devolve `null` sem reclamar. Enquanto as artes não vierem para
## cá (Fase 6 do plano de migração), cada espaço mostra a inicial do item, que
## é o que o próprio 2D faz com nó de talento sem ícone.

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
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	custom_minimum_size.y = ALTURA + 34.0
	_montar()
	Inventario.mudou.connect(_repintar)
	_repintar()


func _montar() -> void:
	var total := Inventario.ESPACOS_MAO
	var largura_total := total * LARGURA + (total - 1) * VAO

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", int(VAO))
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fila)
	fila.position = Vector2(-largura_total * 0.5, -ALTURA - MARGEM_DE_BAIXO)
	fila.anchor_left = 0.5
	fila.anchor_right = 0.5
	fila.anchor_top = 1.0
	fila.anchor_bottom = 1.0

	for i in total:
		var espaco := Panel.new()
		espaco.custom_minimum_size = Vector2(LARGURA, ALTURA)
		espaco.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_rotulo_do_item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotulo_do_item.add_theme_font_size_override("font_size", 14)
	_rotulo_do_item.add_theme_color_override("font_color", BORDA_NA_MAO)
	_rotulo_do_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rotulo_do_item.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_rotulo_do_item.offset_top = -ALTURA - MARGEM_DE_BAIXO - 24.0
	_rotulo_do_item.offset_bottom = -ALTURA - MARGEM_DE_BAIXO - 4.0
	add_child(_rotulo_do_item)


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
			conteudo.text = "" if quantos <= 1 else str(quantos)
			conteudo.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
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
	# Alt segurado é gesto do personagem, não barra de mão.
	if event.alt_pressed:
		return
	for i in Inventario.ESPACOS_MAO:
		if event.is_action_pressed("mv_mao_%d" % (i + 1)):
			Inventario.alternar(i)
			get_viewport().set_input_as_handled()
			return
