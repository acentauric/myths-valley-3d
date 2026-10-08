extends "res://scripts/ui/mochila.gd"
## A MOCHILA NO VALE: a tela do 2D (`scripts/ui/mochila.gd`) desenhada na tela do
## vale, de 1280×720, e vestida com a identidade dos menus dele. Autoload `Mochila`.
##
## ESTENDE O ARQUIVO DO 2D, e não o copia (regra 3 do HISTORICO: regra migrada é
## compartilhada, nunca copiada). A regra inteira — os trinta espaços, o cursor
## que atravessa as três zonas, o E que arruma, o F que veste ou come, o baú, o
## mouse — continua lá, e o 2D continua dono dela. Aqui só o DESENHO: `_montar`,
## `_montar_espaco`, os dois estilos e a letra da lista dos efeitos, que é onde
## moram as medidas e as cores.
##
## Por quê (playtest de 07/10): a mochila era desenhada no quadro de 640×360 do
## 2D e ampliada 1,8× pelo vale (`prototype._ajustar_a_mochila`) — "a qualidade
## tá muito serrilhada". E "já traga o mesmo layout para os menus, como
## inventário": a laca verde-escura, o filete e a talha de ouro
## (`Identidade.emoldurar`), o título em Cinzel e o texto em Cormorant, como o
## painel do J e o menu das obras.
##
## As medidas são as da tela do vale: o espaço tem os 52 px da barra de mão
## (`barra_de_mao.gd`, LARGURA) — a fila de cima É a barra. Dez colunas de 52
## cabem ao lado da coluna dos encaixes e da dos efeitos (com o boneco em cima,
## `boneco_da_mochila.gd`, que entra na coluna daqui de fora) em 1204 px.

const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")

## O espaço, na tela do vale: o da barra de mão (52 px).
const LADO_NA_TELA := 52
const ESPACO_NA_TELA := 6
## A coluna dos efeitos: cabe o boneco (192 px) e duas linhas de texto por efeito.
const LARGURA_DOS_EFEITOS := 330
const LETRA_DOS_EFEITOS := 15
## A fila da mão em ouro, como a barra de mão do rodapé.
const COR_MAO_NO_VALE := Color(Identidade.OURO, 0.7)
const COR_MOLDURA_NO_VALE := Color(Identidade.OURO, 0.3)


# --- montagem (a do 2D, nas medidas e nas cores do vale) ---------------------------

func _montar() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0.02, 0.03, 0.03, 0.72)
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)

	var painel := PanelContainer.new()
	painel.name = "Painel"
	painel.add_theme_stylebox_override("panel", _estilo_do_painel())
	painel.set_anchors_preset(Control.PRESET_CENTER)
	painel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	painel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(painel)
	# A MOLDURA DE TALHA dos painéis do vale (o painel do J, o almanaque): dois
	# irmãos antes do painel, que o seguem.
	Identidade.emoldurar(painel)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 10)
	painel.add_child(coluna)

	_titulo = Label.new()
	_titulo.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600, 3))
	_titulo.add_theme_font_size_override("font_size", 22)
	_titulo.add_theme_color_override("font_color", Identidade.OURO)
	_titulo.uppercase = true
	Identidade.sombra_texto(_titulo)
	coluna.add_child(_titulo)
	coluna.add_child(Identidade.divisor())

	# O BAÚ, quando há um: em cima da mochila, com a mesma grade (ver o 2D).
	_bau_caixa = VBoxContainer.new()
	_bau_caixa.add_theme_constant_override("separation", ESPACO_NA_TELA)
	_bau_caixa.visible = false
	coluna.add_child(_bau_caixa)

	_bau_rotulo = Label.new()
	_bau_rotulo.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600, 1))
	_bau_rotulo.add_theme_font_size_override("font_size", 16)
	_bau_rotulo.add_theme_color_override("font_color", Color(Identidade.ROTULO, 0.9))
	_bau_caixa.add_child(_bau_rotulo)

	# A grade do baú nasce vazia e é preenchida no fim de `_montar`, para os
	# índices das molduras saírem na ordem mochila, encaixes, baú (ver o 2D).
	_bau_grade = GridContainer.new()
	_bau_grade.columns = COLUNAS
	_bau_grade.add_theme_constant_override("h_separation", ESPACO_NA_TELA)
	_bau_grade.add_theme_constant_override("v_separation", ESPACO_NA_TELA)
	_bau_caixa.add_child(_bau_grade)

	var fio := ColorRect.new()
	fio.color = Color(Identidade.OURO, 0.35)
	fio.custom_minimum_size = Vector2(0, 1)
	fio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bau_caixa.add_child(fio)

	# Mochila à esquerda, o que se veste no meio, os efeitos (com o boneco) à direita.
	var lado_a_lado := HBoxContainer.new()
	lado_a_lado.add_theme_constant_override("separation", 28)
	coluna.add_child(lado_a_lado)

	_grade = GridContainer.new()
	_grade.columns = COLUNAS
	_grade.add_theme_constant_override("h_separation", ESPACO_NA_TELA)
	_grade.add_theme_constant_override("v_separation", ESPACO_NA_TELA)
	_grade.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	lado_a_lado.add_child(_grade)
	for i in Inventario.ESPACOS:
		_grade.add_child(_montar_espaco(i))

	_encaixes_coluna = VBoxContainer.new()
	_encaixes_coluna.add_theme_constant_override("separation", ESPACO_NA_TELA)
	_encaixes_coluna.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	lado_a_lado.add_child(_encaixes_coluna)
	for encaixe in Equipamento.ENCAIXES:
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation", 12)
		linha.add_child(_montar_espaco(-1))
		var etiqueta := Label.new()
		etiqueta.name = "Rotulo"
		etiqueta.custom_minimum_size = Vector2(140, 0)
		etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		etiqueta.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600, 1))
		etiqueta.add_theme_font_size_override("font_size", 15)
		etiqueta.add_theme_color_override("font_color", Color(Identidade.ROTULO, 0.9))
		etiqueta.text = str(Equipamento.NOME_DO_ENCAIXE[encaixe])
		linha.add_child(etiqueta)
		_encaixes_coluna.add_child(linha)

	# O que está fazendo efeito no corpo, ao lado dos encaixes (ver o 2D); o
	# boneco entra no alto desta coluna (`boneco_da_mochila.montar`).
	var coluna_dos_efeitos := VBoxContainer.new()
	coluna_dos_efeitos.add_theme_constant_override("separation", 4)
	coluna_dos_efeitos.custom_minimum_size = Vector2(LARGURA_DOS_EFEITOS, 0)
	lado_a_lado.add_child(coluna_dos_efeitos)

	_titulo_dos_efeitos = Label.new()
	_titulo_dos_efeitos.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600, 1))
	_titulo_dos_efeitos.add_theme_font_size_override("font_size", 15)
	_titulo_dos_efeitos.add_theme_color_override("font_color", Color(Identidade.ROTULO, 0.9))
	coluna_dos_efeitos.add_child(_titulo_dos_efeitos)

	_efeitos = VBoxContainer.new()
	_efeitos.add_theme_constant_override("separation", 2)
	coluna_dos_efeitos.add_child(_efeitos)

	_nome_do_item = Label.new()
	_nome_do_item.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 600))
	_nome_do_item.add_theme_font_size_override("font_size", 22)
	_nome_do_item.add_theme_color_override("font_color", Identidade.TEXTO)
	_nome_do_item.custom_minimum_size = Vector2(0, 54)
	_nome_do_item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coluna.add_child(_nome_do_item)

	_rodape = Label.new()
	_rodape.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600, 1))
	_rodape.add_theme_font_size_override("font_size", 15)
	_rodape.add_theme_color_override("font_color", Color(Identidade.ROTULO, 0.85))
	coluna.add_child(_rodape)

	# As molduras do baú por último: o índice delas vem depois do da mochila e
	# do dos encaixes (ver o 2D).
	for k in BAU_MAXIMO:
		_bau_grade.add_child(_montar_espaco(-1))

	# A folha de vidro por cima de tudo, que recebe o mouse (ver o 2D).
	_vidro = Control.new()
	_vidro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vidro.mouse_filter = Control.MOUSE_FILTER_STOP
	_vidro.gui_input.connect(_mouse)
	add_child(_vidro)


func _montar_espaco(indice: int) -> Panel:
	var moldura := Panel.new()
	moldura.custom_minimum_size = Vector2(LADO_NA_TELA, LADO_NA_TELA)

	var icone := TextureRect.new()
	icone.name = "Icone"
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.set_anchors_preset(Control.PRESET_FULL_RECT)
	icone.offset_left = 6
	icone.offset_top = 6
	icone.offset_right = -6
	icone.offset_bottom = -6
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	moldura.add_child(icone)

	var quantidade := Label.new()
	quantidade.name = "Quantidade"
	quantidade.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	quantidade.offset_left = -36
	quantidade.offset_top = -24
	quantidade.offset_right = -3
	quantidade.offset_bottom = -2
	quantidade.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantidade.add_theme_font_override("font", Identidade.fonte_numeros(600))
	quantidade.add_theme_font_size_override("font_size", 16)
	quantidade.add_theme_color_override("font_color", Color(0.98, 0.94, 0.8))
	quantidade.add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.04))
	quantidade.add_theme_constant_override("outline_size", 4)
	quantidade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	moldura.add_child(quantidade)

	if indice >= 0 and indice < Inventario.ESPACOS_MAO:
		var numero := Label.new()
		numero.set_anchors_preset(Control.PRESET_TOP_LEFT)
		numero.offset_left = 4
		numero.offset_top = 0
		numero.text = Inventario.rotulo_do_espaco(indice)
		numero.add_theme_font_override("font", Identidade.fonte_numeros(600))
		numero.add_theme_font_size_override("font_size", 13)
		numero.add_theme_color_override("font_color", Color(Identidade.ROTULO, 0.8))
		numero.mouse_filter = Control.MOUSE_FILTER_IGNORE
		moldura.add_child(numero)

	_molduras.append(moldura)
	return moldura


## A laca verde-escura e o filete de ouro dos painéis do vale (a talha é a
## moldura, posta em `_montar`).
func _estilo_do_painel() -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(Identidade.LACA, 0.96)
	estilo.border_color = Color(Identidade.OURO, 0.8)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(10)
	estilo.set_content_margin_all(20)
	return estilo


func _estilo_do_espaco(indice: int) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.04, 0.07, 0.06, 0.92)
	if indice == _cursor:
		estilo.border_color = COR_CURSOR
		estilo.set_border_width_all(3)
	elif indice == _pego:
		estilo.border_color = COR_PEGO
		estilo.set_border_width_all(3)
	elif indice >= _primeiro_do_bau():
		estilo.border_color = COR_BAU
		estilo.set_border_width_all(2)
	elif indice >= Inventario.ESPACOS:
		estilo.border_color = COR_ENCAIXE
		estilo.set_border_width_all(2)
	elif indice < Inventario.ESPACOS_MAO:
		estilo.border_color = COR_MAO_NO_VALE
		estilo.set_border_width_all(2)
	else:
		estilo.border_color = COR_MOLDURA_NO_VALE
		estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(4)
	return estilo


## As linhas do 2D, na letra do vale: o texto delas continua lá.
func _listar_efeitos() -> void:
	super()
	for linha in _efeitos.get_children():
		if linha is Label and not linha.is_queued_for_deletion():
			linha.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 600))
			linha.add_theme_font_size_override("font_size", LETRA_DOS_EFEITOS)
			linha.custom_minimum_size = Vector2(LARGURA_DOS_EFEITOS, 0)
