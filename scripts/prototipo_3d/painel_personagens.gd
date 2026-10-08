extends Control
## MODELOS: painel do menu com os moradores do vale e as peças do catálogo, no mesmo
## formato nas duas abas: cartões paginados com filtro por nome e, ao escolher um cartão,
## a ficha (prévia 3D à esquerda, dados em linhas fixas à direita, navegação no rodapé,
## também pelas setas do teclado). Clicar na aba de novo volta aos cartões.
## A prévia tem tamanho fixo e uma escala comum entre os moradores (a altura de cada um
## aparece), luz de cima e sombra no chão; arrastar gira, a roda aproxima, o botão
## direito move e o duplo clique (ou o botão do canto) centraliza.
## No cabeçalho, à esquerda do ×: RESTAURAR (só na edição), EDITAR (lápis; vira ✓ para
## concluir) e GRAVAR (disquete, só pelo editor), que funde os ajustes nos arquivos do
## projeto e fica dourado enquanto houver ajuste não gravado. Fechar com ajuste
## pendente pede confirmação.
## O anfitrião (abertura.gd) adiciona o painel à camada do menu, chama abrir(tema) e,
## para fechar por Esc, clique fora ou HOME, chama pedir_fechar(); o painel emite
## `fechado` quando pode fechar, e quem hospeda libera o nó.

const TemaMenu = preload("res://scripts/prototipo_3d/tema_menu.gd")
const PainelAjustes = preload("res://scripts/prototipo_3d/painel_ajustes.gd")
const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const HudIcon = preload("res://scripts/prototipo_3d/hud_icon.gd")
const Humanoide = preload("res://scripts/prototipo_3d/personagem_procedural.gd")
## Cartão da grade: tamanho mínimo e separação. Colunas e linhas por página saem do espaço
## que o modal deixa à lista (`_capacidade()`), e os cartões esticam para preencher a grade.
const CARTAO_MIN := Vector2(140, 56)
const SEPARACAO_GRADE := 8
## Margens internas do modal (as da moldura) e separação entre os blocos da coluna.
const MARGEM_CAIXA := Vector2(56, 44)
const SEPARACAO_COLUNA := 10

## Pode fechar: o anfitrião volta à Home e libera o painel.
signal fechado

## Mesma altura dos outros modais do menu (histórico, créditos); só a largura é maior.
const TAMANHO := Vector2(940, 600)
## Prévia 3D: tamanho fixo para todo modelo.
const PREVIA := Vector2(320, 340)
## Altura de referência que enquadra os moradores: cada um aparece na sua altura.
const ALTURA_QUADRO := 2.0
const CAMINHO_NPCS := "res://data/npcs_3d.json"
const PASTA_VOZES := "res://assets/audio/vozes/"
const DOURADO := Color("e2c47f")
const COR_DETALHE := Color(0.78, 0.79, 0.72)
## Setas de navegação, compactas e juntas do "N / M" (as mesmas do histórico).
const SETA := Vector2(44, 32)
## Ordem e rótulo dos períodos dos postos (chaves de npcs_3d.json).
const PERIODOS := [["manha", "manhã"], ["tarde", "tarde"], ["entardecer", "entardecer"], ["noite", "noite"], ["madrugada", "madrugada"]]
## Falas mostradas na ficha (linhas reservadas mesmo para quem tem menos).
const FALAS_NA_FICHA := 3

## Aba aberta: 0 = MORADORES, 1 = ASSETS.
var aba := 0
## Ficha aberta na aba (id do morador ou chave da peça); vazio mostra os cartões.
var selecionado := ""
## Página dos cartões de cada aba.
var _paginas := [0, 0]
## Edição aberta na ficha selecionada.
var editando := false
var _caixa: PanelContainer
var _preview_modelo: Node3D
var _preview_viewport: SubViewport
var _textos: Dictionary
## Filtro por nome (minúsculas), aplicado aos cartões da aba aberta.
var filtro := ""
var _campo_filtro: LineEdit
## Pedro, os moradores e, por fim, o viajante (dicionários de npcs_3d.json).
var _pessoas: Array = []
var _botoes_abas: Array[Button] = []
var _lista: VBoxContainer
var _rolagem: ScrollContainer
## Rodapé do modal: a navegação (páginas de cartões ou fichas) fica sempre embaixo.
var _rodape: HBoxContainer
var _botao_restaurar: Button
var _botao_editar: Button
var _icone_editar: HudIcon
var _botao_gravar: Button
var _icone_gravar: HudIcon
var _aviso_gravado: Label
var _confirmacao: Control
var _desde_conferencia := 0.0
## Tocador único das falas: começar uma fala para a anterior.
var _voz: AudioStreamPlayer
## Botão ▶ da fala que está tocando (vira ❚❚ e para no segundo clique).
var _fala_tocando: Button
## Prévia 3D: pivô (gira o modelo), câmera e o enquadramento atual e o inicial.
var _preview_pivo: Node3D
var _camera: Camera3D
var _alvo := Vector3.ZERO
var _alvo_inicial := Vector3.ZERO
var _distancia := 1.0
var _distancia_inicial := 1.0
var _elevacao := 0.06
## Âncoras do vale montado atrás do menu (destinos possíveis dos postos).
var _ancoras: Array[String] = []
## A grade que está montada: colunas e linhas da última `_montar_cartoes` (zero sem cartões).
var _capacidade_montada := Vector2i.ZERO


## Monta o painel centrado, no estilo dos outros painéis do menu (tema recebido).
func abrir(tema: Theme) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Cliques fora da caixa passam ao anfitrião, que pede para fechar (padrão dos modais).
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = tema if tema else TemaMenu.criar()
	_textos = JSON.parse_string(FileAccess.get_file_as_string("res://data/galeria_personagens.json"))
	_carregar_pessoas()
	_voz = AudioStreamPlayer.new()
	# A fala é pedida com um clique: toca mesmo com o som geral desligado.
	_voz.bus = Audio.ESCUTA
	_voz.finished.connect(_parar_fala)
	add_child(_voz)
	var caixa := PanelContainer.new()
	_caixa = caixa
	# O fundo vem da moldura de talha, como nos outros modais; o stylebox só guarda as
	# margens (28/22, as mesmas do estilo_painel).
	var vazio := StyleBoxEmpty.new()
	vazio.content_margin_left = 28
	vazio.content_margin_right = 28
	vazio.content_margin_top = 22
	vazio.content_margin_bottom = 22
	caixa.add_theme_stylebox_override("panel", vazio)
	caixa.custom_minimum_size = TAMANHO
	caixa.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	caixa.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caixa.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(caixa)
	Tela.vincular_componente(caixa, "modelos", Vector2(0.5, 0.5))
	Identidade.emoldurar(caixa)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 10)
	caixa.add_child(coluna)
	var fechar := PainelAjustes.cabecalho(coluna, tr("Modelos"), pedir_fechar,
		tr("Moradores e peças do vale, com falas e medidas."))
	_botoes_do_cabecalho(fechar)
	var abas := HBoxContainer.new()
	abas.add_theme_constant_override("separation", 8)
	coluna.add_child(abas)
	var rotulos_abas := [tr("MORADORES"), tr("ASSETS")]
	for indice in range(rotulos_abas.size()):
		var botao := Button.new()
		botao.text = String(rotulos_abas[indice])
		botao.toggle_mode = true
		botao.custom_minimum_size.y = TemaMenu.ALTURA_BOTAO
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botao.mouse_entered.connect(func() -> void: Audio.efeito("ui_hover"))
		botao.pressed.connect(func() -> void:
			Audio.efeito("ui_confirmar")
			_trocar_aba(indice))
		abas.add_child(botao)
		_botoes_abas.append(botao)
	_campo_filtro = LineEdit.new()
	_campo_filtro.placeholder_text = tr("Filtrar por nome…")
	_campo_filtro.custom_minimum_size.y = 36
	_campo_filtro.clear_button_enabled = true
	_campo_filtro.text_changed.connect(func(texto: String) -> void:
		filtro = texto.strip_edges().to_lower()
		_paginas[aba] = 0
		_reconstruir_lista())
	coluna.add_child(_campo_filtro)
	_rolagem = ScrollContainer.new()
	_rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	coluna.add_child(_rolagem)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 8)
	_rolagem.add_child(_lista)
	_rodape = HBoxContainer.new()
	_rodape.name = "Rodape"
	_rodape.alignment = BoxContainer.ALIGNMENT_CENTER
	_rodape.custom_minimum_size.y = SETA.y
	coluna.add_child(_rodape)
	_trocar_aba(0)
	coluna.sort_children.connect(_conferir_capacidade)
	fechar.grab_focus()


## RESTAURAR, EDITAR e GRAVAR entram à esquerda do ×, no mesmo formato dele.
func _botoes_do_cabecalho(fechar: Button) -> void:
	var linha := fechar.get_parent() as HBoxContainer
	linha.add_theme_constant_override("separation", 8)
	_aviso_gravado = Label.new()
	_aviso_gravado.add_theme_font_size_override("font_size", 14)
	_aviso_gravado.add_theme_color_override("font_color", DOURADO)
	_aviso_gravado.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	linha.add_child(_aviso_gravado)
	linha.move_child(_aviso_gravado, fechar.get_index())
	_botao_restaurar = _botao_icone(HudIcon.new().configurar("restaurar"))
	(_botao_restaurar.get_child(0) as HudIcon).definir(true)
	_botao_restaurar.tooltip_text = tr("Restaurar o padrão")
	_botao_restaurar.pressed.connect(_restaurar_selecionado)
	linha.add_child(_botao_restaurar)
	linha.move_child(_botao_restaurar, fechar.get_index())
	_icone_editar = HudIcon.new().configurar("editar")
	_botao_editar = _botao_icone(_icone_editar)
	_botao_editar.pressed.connect(func() -> void:
		Audio.efeito("ui_confirmar")
		editando = not editando
		_reconstruir_lista())
	linha.add_child(_botao_editar)
	linha.move_child(_botao_editar, fechar.get_index())
	if AjustesConteudo.pode_gravar_no_projeto():
		# Só pelo editor os arquivos res:// são graváveis (os ajustes vão para o git).
		_icone_gravar = HudIcon.new().configurar("salvar")
		_botao_gravar = _botao_icone(_icone_gravar)
		_botao_gravar.tooltip_text = tr("Gravar no projeto. Os ajustes valem na próxima montagem do vale.")
		_botao_gravar.pressed.connect(_gravar)
		linha.add_child(_botao_gravar)
		linha.move_child(_botao_gravar, fechar.get_index())


func _botao_icone(icone: Control) -> Button:
	var botao := Button.new()
	botao.custom_minimum_size = Vector2(PainelAjustes.ALTURA_CABECALHO, PainelAjustes.ALTURA_CABECALHO)
	botao.theme_type_variation = &"BotaoIcone"
	botao.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icone.position = Vector2(10, 10)
	icone.size = Vector2(24, 24)
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	botao.add_child(icone)
	botao.mouse_entered.connect(func():
		if not botao.disabled:
			Audio.efeito("ui_hover"))
	return botao


func _restaurar_selecionado() -> void:
	if aba == 0:
		AjustesConteudo.restaurar_morador(selecionado)
	else:
		AjustesConteudo.restaurar_peca(selecionado)
	Audio.efeito("ui_voltar")
	_reconstruir_lista()


func _gravar() -> bool:
	var feitos := AjustesConteudo.gravar_no_projeto()
	Audio.efeito("ui_confirmar")
	_aviso_gravado.text = tr("Gravado: %d moradores, %d peças") % [feitos.x, feitos.y]
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if is_instance_valid(_aviso_gravado):
			_aviso_gravado.text = "")
	_carregar_pessoas()
	_reconstruir_lista()
	return not AjustesConteudo.tem_pendencias()


## Estado dos botões do cabeçalho: EDITAR só numa ficha editável (o viajante não é) e,
## com a edição aberta, vira ✓ (concluir) e mostra RESTAURAR ao lado; GRAVAR fica
## dourado (borda e ícone) com ajuste pendente e fica desativado e apagado, como a seta
## da paginação, quando não há nada a gravar.
func _atualizar_cabecalho() -> void:
	_botao_editar.visible = not selecionado.is_empty() and selecionado != "viajante"
	_botao_restaurar.visible = editando and _botao_editar.visible
	_icone_editar.configurar("concluir" if editando else "editar")
	_icone_editar.queue_redraw()
	_botao_editar.tooltip_text = tr("Fechar a edição") if editando else tr("Editar")
	if _botao_gravar == null:
		return
	var pendente := AjustesConteudo.tem_pendencias()
	if _icone_gravar.ativo != pendente:
		_icone_gravar.definir(pendente)
	_botao_gravar.disabled = not pendente
	_icone_gravar.modulate = Color.WHITE if pendente else Color(1, 1, 1, 0.3)
	_botao_gravar.tooltip_text = tr("Gravar no projeto. Os ajustes valem na próxima montagem do vale.") if pendente else tr("Nada para gravar")
	for estado in ["normal", "hover", "pressed", "focus"]:
		if pendente:
			var caixa := _botao_gravar.get_theme_stylebox(estado).duplicate() as StyleBoxFlat
			if caixa:
				caixa.border_color = DOURADO
				_botao_gravar.add_theme_stylebox_override(estado, caixa)
		else:
			_botao_gravar.remove_theme_stylebox_override(estado)


# Os campos gravam a cada mudança: o destaque do disquete acompanha sem depender deles.
func _process(delta: float) -> void:
	_desde_conferencia += delta
	if _botao_gravar != null and _desde_conferencia > 0.25:
		_desde_conferencia = 0.0
		if _icone_gravar.ativo != AjustesConteudo.tem_pendencias():
			_atualizar_cabecalho()


## ← → trocam de ficha (ou de página nos cartões), como as setas do rodapé. Não vale com
## a edição aberta, a confirmação na tela ou um campo de texto em foco.
func _input(evento: InputEvent) -> void:
	var tecla := evento as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo or not (tecla.keycode in [KEY_LEFT, KEY_RIGHT]):
		return
	if editando or is_instance_valid(_confirmacao):
		return
	var foco := get_viewport().gui_get_focus_owner()
	if foco is LineEdit or foco is TextEdit:
		return
	var navegacao := _rodape.get_node_or_null("Navegacao")
	if navegacao == null:
		return
	var seta := navegacao.get_child(2 if tecla.keycode == KEY_RIGHT else 0) as Button
	get_viewport().set_input_as_handled()
	if seta.disabled:
		Audio.efeito("ui_trava")
		return
	seta.pressed.emit()


## Com ajuste não gravado no projeto, pergunta antes de fechar; sem, fecha.
func pedir_fechar() -> void:
	if is_instance_valid(_confirmacao):
		_fechar_confirmacao()
		return
	if _botao_gravar != null and AjustesConteudo.tem_pendencias():
		_confirmar_saida()
		return
	_parar_fala()
	fechado.emit()


func _confirmar_saida() -> void:
	_confirmacao = Control.new()
	_confirmacao.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Por cima de tudo e segurando o clique: clicar fora não fecha o painel por baixo.
	_confirmacao.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_confirmacao)
	var sombra := ColorRect.new()
	sombra.color = Color(0, 0, 0, 0.55)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirmacao.add_child(sombra)
	var caixa := PanelContainer.new()
	caixa.add_theme_stylebox_override("panel", TemaMenu.estilo_painel())
	caixa.custom_minimum_size = Vector2(520, 0)
	caixa.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	caixa.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caixa.grow_vertical = Control.GROW_DIRECTION_BOTH
	_confirmacao.add_child(caixa)
	Tela.vincular_componente(caixa, "pergunta", Vector2(0.5, 0.5))
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 14)
	caixa.add_child(coluna)
	var fechar := PainelAjustes.cabecalho(coluna, tr("Sair sem gravar?"), _fechar_confirmacao,
		tr("Há ajustes que ainda não foram gravados no projeto."))
	var texto := Label.new()
	texto.text = tr("Sem gravar, eles ficam só nesta máquina.")
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.add_theme_font_size_override("font_size", 16)
	coluna.add_child(texto)
	var botoes := HBoxContainer.new()
	botoes.alignment = BoxContainer.ALIGNMENT_CENTER
	botoes.add_theme_constant_override("separation", 10)
	coluna.add_child(botoes)
	var gravar := Button.new()
	gravar.text = tr("GRAVAR E SAIR")
	gravar.custom_minimum_size.y = TemaMenu.ALTURA_BOTAO
	gravar.pressed.connect(func() -> void:
		if _gravar():
			_parar_fala()
			fechado.emit())
	botoes.add_child(gravar)
	var sair := Button.new()
	sair.text = tr("SAIR SEM GRAVAR")
	sair.theme_type_variation = &"BotaoNegativo"
	sair.custom_minimum_size.y = TemaMenu.ALTURA_BOTAO
	sair.pressed.connect(func() -> void:
		Audio.efeito("ui_voltar")
		_parar_fala()
		fechado.emit())
	botoes.add_child(sair)
	fechar.grab_focus()


func _fechar_confirmacao() -> void:
	if is_instance_valid(_confirmacao):
		_confirmacao.queue_free()
	_confirmacao = null


## Pedro (guia) primeiro, depois os moradores e, por fim, o viajante (você).
func _carregar_pessoas() -> void:
	_pessoas = []
	var dados = JSON.parse_string(FileAccess.get_file_as_string(CAMINHO_NPCS))
	if dados is Dictionary:
		dados = AjustesConteudo.npcs(dados)
		if dados.get("guia") is Dictionary:
			_pessoas.append(dados["guia"])
		for morador in dados.get("moradores", []):
			if morador is Dictionary:
				_pessoas.append(morador)
	var viajante: Dictionary = CatalogoAssets.PECAS.get("viajante", {})
	_pessoas.append({
		"id": "viajante",
		"nome": tr("Viajante (você)"),
		"altura": float(viajante.get("altura", 1.78)),
		"nota": tr("É você: o recém-chegado da capital."),
	})
	var mundo := get_tree().get_first_node_in_group("mundo") if is_inside_tree() else null
	if mundo != null and mundo.get("ancoras") is Dictionary:
		_ancoras.clear()
		for nome: String in mundo.ancoras:
			# Direções e frentes das casas não são lugares.
			if nome.ends_with("Frente") or nome == "PierDirecao":
				continue
			_ancoras.append(nome)
	_ancoras.sort()


## Trocar de aba (ou clicar na aba aberta) volta aos cartões.
func _trocar_aba(nova: int) -> void:
	# Voltar da ficha leva à página em que o cartão dela está, e não à que ficou aberta antes.
	if not selecionado.is_empty() and nova == aba:
		# A capacidade é a dos cartões: o filtro, escondido na ficha, volta a ocupar espaço.
		_campo_filtro.visible = true
		var posicao := _itens().map(func(item: Array) -> String: return item[0]).find(selecionado)
		if posicao >= 0:
			_paginas[aba] = floori(float(posicao) / _cartoes_por_pagina())
	aba = nova
	selecionado = ""
	editando = false
	_parar_fala()
	# A aba ativa fica dourada, como nas abas do painel de ajustes.
	for indice in range(_botoes_abas.size()):
		var botao := _botoes_abas[indice]
		botao.set_pressed_no_signal(indice == aba)
		for cor in ["font_color", "font_pressed_color", "font_focus_color", "font_hover_color"]:
			if indice == aba:
				botao.add_theme_color_override(cor, DOURADO)
			else:
				botao.remove_theme_color_override(cor)
	_reconstruir_lista()


func _reconstruir_lista() -> void:
	for pai: Node in [_lista, _rodape]:
		for filho in pai.get_children():
			pai.remove_child(filho)
			filho.queue_free()
	_rolagem.scroll_vertical = 0
	_preview_modelo = null
	_preview_viewport = null
	_preview_pivo = null
	_camera = null
	_carregar_pessoas()
	# Na ficha o filtro some; a edição pode passar da altura e rola.
	_campo_filtro.visible = selecionado.is_empty()
	_rolagem.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if editando else ScrollContainer.SCROLL_MODE_DISABLED
	if selecionado.is_empty():
		_montar_cartoes()
	else:
		_montar_ficha()
	_atualizar_cabecalho()


## [chave, nome, ajustado] de cada item da aba, já filtrado.
func _itens() -> Array:
	var itens: Array = []
	if aba == 0:
		for pessoa: Dictionary in _pessoas:
			var id := str(pessoa.get("id", ""))
			if _passa_filtro([pessoa.get("nome", ""), id]):
				itens.append([id, str(pessoa.get("nome", id)), AjustesConteudo.morador_ajustado(id)])
	else:
		var chaves: Array = CatalogoAssets.PECAS.keys()
		chaves.sort()
		for chave: String in chaves:
			# Os modelos dos moradores têm a aba MORADORES; ASSETS são as demais peças.
			if str(CatalogoAssets.PECAS[chave].get("tripo", "")).begins_with("personagens/"):
				continue
			if _passa_filtro([chave, chave.replace("_", " ")]):
				itens.append([chave, chave.replace("_", " ").capitalize(), AjustesConteudo.peca_ajustada(chave)])
	return itens


## Espaço que sobra à lista de cartões: o interior do modal menos o que os outros blocos da
## coluna (cabeçalho, abas, filtro e navegação) pedem. É medido dos mínimos dos próprios
## blocos, e não do tamanho atual da rolagem, para não depender de a coluna já ter sido
## disposta nem de uma ficha anterior ter esticado o modal.
func _espaco_cartoes() -> Vector2:
	var coluna := _rolagem.get_parent() as Control
	var altura := TAMANHO.y - MARGEM_CAIXA.y
	var visiveis := 0
	for filho in coluna.get_children():
		var bloco := filho as Control
		if bloco == null or not bloco.visible:
			continue
		visiveis += 1
		if bloco != _rolagem:
			altura -= bloco.get_combined_minimum_size().y
	altura -= SEPARACAO_COLUNA * maxi(visiveis - 1, 0)
	return Vector2(TAMANHO.x - MARGEM_CAIXA.x, altura)


## Colunas e linhas que cabem no espaço da lista, com o cartão no tamanho mínimo.
func _capacidade() -> Vector2i:
	var espaco := _espaco_cartoes()
	var colunas := maxi(1, floori((espaco.x + SEPARACAO_GRADE) / (CARTAO_MIN.x + SEPARACAO_GRADE)))
	var linhas := maxi(1, floori((espaco.y + SEPARACAO_GRADE) / (CARTAO_MIN.y + SEPARACAO_GRADE)))
	return Vector2i(colunas, linhas)


## Cartões por página: a grade inteira, nas duas abas.
func _cartoes_por_pagina() -> int:
	var capacidade := _capacidade()
	return capacidade.x * capacidade.y


## A primeira montagem mede o cabeçalho antes de a coluna ter largura: o título, com quebra
## de linha, pede uma letra por linha, e a grade nascia com uma linha só. Quando a coluna se
## dispõe e a capacidade muda, a grade se remonta com as linhas que de fato cabem.
func _conferir_capacidade() -> void:
	if selecionado.is_empty() and _capacidade_montada != Vector2i.ZERO and _capacidade() != _capacidade_montada:
		_capacidade_montada = Vector2i.ZERO
		_remontar_grade.call_deferred()


func _remontar_grade() -> void:
	_reconstruir_lista()
	# A caixa cresceu com o cabeçalho esticado da primeira medida e não encolhe sozinha:
	# volta ao mínimo, centrada.
	_caixa.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


## Cartões paginados, preenchendo a largura e a altura da lista, os mesmos nas duas abas.
func _montar_cartoes() -> void:
	var itens := _itens()
	_capacidade_montada = Vector2i.ZERO
	if itens.is_empty():
		_detalhe(tr("Nada com esse nome por aqui."))
		return
	var capacidade := _capacidade()
	_capacidade_montada = capacidade
	var por_pagina := capacidade.x * capacidade.y
	var paginas := ceili(float(itens.size()) / por_pagina)
	_paginas[aba] = clampi(_paginas[aba], 0, paginas - 1)
	var grade := GridContainer.new()
	grade.name = "GradeMoradores" if aba == 0 else "GradeAssets"
	grade.columns = capacidade.x
	grade.add_theme_constant_override("h_separation", SEPARACAO_GRADE)
	grade.add_theme_constant_override("v_separation", SEPARACAO_GRADE)
	_lista.add_child(grade)
	# Cartões mais altos que o mínimo ocupam a sobra, sem faixa vazia antes da navegação. A
	# página que não enche a grade (24 moradores numa grade de 30) divide a altura pelas
	# linhas que usa, até 1,6 vez o mínimo, para a última página filtrada não virar tijolo.
	var da_pagina := itens.slice(_paginas[aba] * por_pagina, (_paginas[aba] + 1) * por_pagina)
	var linhas := clampi(ceili(float(da_pagina.size()) / capacidade.x), 1, capacidade.y)
	var altura_cartao := minf(floorf((_espaco_cartoes().y - SEPARACAO_GRADE * (linhas - 1)) / linhas), CARTAO_MIN.y * 1.6)
	for item: Array in da_pagina:
		var chave: String = item[0]
		var cartao := Button.new()
		cartao.name = ("Morador_" if aba == 0 else "Peca_") + chave
		cartao.text = str(item[1]) + ("  •" if item[2] else "")
		# O nome pode cortar no cartão: o tooltip o mostra inteiro, e a chave embaixo.
		cartao.tooltip_text = str(item[1]) if str(item[1]) == chave else "%s\n%s" % [item[1], chave]
		cartao.clip_text = true
		cartao.add_theme_font_size_override("font_size", 14)
		cartao.custom_minimum_size = Vector2(CARTAO_MIN.x, maxf(CARTAO_MIN.y, altura_cartao))
		cartao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cartao.pressed.connect(func() -> void: _abrir(chave))
		grade.add_child(cartao)
	if paginas > 1:
		_navegacao(_paginas[aba], paginas, func(passo: int) -> void:
			_paginas[aba] += passo
			_reconstruir_lista())


func _abrir(chave: String) -> void:
	Audio.efeito("ui_confirmar")
	selecionado = chave
	editando = false
	_parar_fala()
	_reconstruir_lista()


## Ficha, igual nas duas abas: título dourado (com • se há ajuste), prévia 3D à esquerda
## e dados à direita em linhas fixas; com a edição aberta, os campos ocupam a largura toda.
## Embaixo, a navegação entre as fichas da aba.
func _montar_ficha() -> void:
	var itens := _itens()
	var posicao := itens.map(func(item: Array) -> String: return item[0]).find(selecionado)
	var pessoa := {}
	if aba == 0:
		for p: Dictionary in _pessoas:
			if str(p.get("id", "")) == selecionado:
				pessoa = p
	var ajustado := AjustesConteudo.morador_ajustado(selecionado) if aba == 0 else AjustesConteudo.peca_ajustada(selecionado)
	var nome := str(pessoa.get("nome", selecionado)) if aba == 0 else selecionado.replace("_", " ").capitalize()
	_lista.set_meta("ficha", selecionado)
	_titulo_bloco(nome + ("  •" if ajustado else ""), 22)
	if editando:
		if aba == 0:
			_editor_morador(pessoa)
		else:
			_editor_peca(selecionado, AjustesConteudo.peca(selecionado))
	else:
		var ficha := HBoxContainer.new()
		ficha.name = "Ficha"
		ficha.add_theme_constant_override("separation", 22)
		_lista.add_child(ficha)
		var altura := float(pessoa.get("altura", 1.7)) if aba == 0 else 0.0
		_montar_previa(ficha, selecionado, altura)
		var detalhes := VBoxContainer.new()
		detalhes.name = "Detalhes"
		detalhes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detalhes.add_theme_constant_override("separation", 10)
		ficha.add_child(detalhes)
		var principal := _lista
		_lista = detalhes
		if aba == 0:
			_dados_morador(pessoa)
		else:
			_dados_peca(AjustesConteudo.peca(selecionado))
		_lista = principal
	if posicao >= 0 and itens.size() > 1:
		_navegacao(posicao, itens.size(), func(passo: int) -> void:
			selecionado = str(itens[posicao + passo][0])
			editando = false
			_parar_fala()
			_reconstruir_lista())


## Linhas fixas "rótulo · valor": as mesmas para todo morador (ou toda peça), com "—"
## onde não há dado, para nada mudar de lugar entre uma ficha e outra.
func _linhas(linhas: Array) -> void:
	var grade := GridContainer.new()
	grade.name = "Linhas"
	grade.columns = 2
	grade.add_theme_constant_override("h_separation", 14)
	grade.add_theme_constant_override("v_separation", 4)
	_lista.add_child(grade)
	for linha: Array in linhas:
		var rotulo := Label.new()
		rotulo.text = str(linha[0])
		rotulo.custom_minimum_size.x = 96
		rotulo.add_theme_font_size_override("font_size", 13)
		rotulo.add_theme_color_override("font_color", Color(DOURADO, 0.8))
		grade.add_child(rotulo)
		var valor := Label.new()
		valor.text = str(linha[1]) if not str(linha[1]).is_empty() else "—"
		valor.tooltip_text = valor.text
		valor.mouse_filter = Control.MOUSE_FILTER_PASS
		valor.clip_text = true
		valor.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		valor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Identidade.papel_leitura(valor, 13, COR_DETALHE)
		grade.add_child(valor)


## Morador: altura, voz, os cinco períodos, nota e três falas com ▶ (vagas reservadas).
func _dados_morador(pessoa: Dictionary) -> void:
	var id := str(pessoa.get("id", ""))
	var voz: Dictionary = pessoa.get("voz", {})
	var postos: Dictionary = pessoa.get("postos", {})
	var linhas: Array = [
		[tr("Altura"), "%s m" % _numero(float(pessoa.get("altura", 1.7)))],
		[tr("Voz"), str(voz.get("nome", ""))],
	]
	for periodo: Array in PERIODOS:
		linhas.append([tr(String(periodo[1])).capitalize(), tr(str(postos[periodo[0]][0])) if postos.has(periodo[0]) else ""])
	var nota := str(pessoa.get("nota", ""))
	if nota.is_empty() and postos.is_empty() and id == "pedro":
		nota = tr("Sem posto fixo: acompanha o viajante pelo vale.")
	linhas.append([tr("Nota"), nota])
	_linhas(linhas)
	var falas: Array = pessoa.get("falas", [])
	for i in FALAS_NA_FICHA:
		_linha_fala(falas[i] if i < falas.size() and falas[i] is Dictionary else {})


## Peça: arquivo, medida, tronco, afundar, piso e as marcações do catálogo.
func _dados_peca(spec: Dictionary) -> void:
	var medida := ""
	if spec.has("altura"):
		medida = tr("altura %s u") % _numero(float(spec["altura"]))
	elif spec.has("largura"):
		medida = tr("largura %s u") % _numero(float(spec["largura"]))
	var marcacoes := PackedStringArray()
	if spec.get("caixa", false):
		marcacoes.append(tr("caixa"))
	if spec.has("girar"):
		marcacoes.append(tr("girar"))
	_linhas([
		[tr("Arquivo"), str(spec.get("tripo", "")).get_file()],
		[tr("Medida"), medida],
		[tr("Tronco"), _numero(float(spec["tronco"])) if spec.has("tronco") else ""],
		[tr("Afundar"), _numero(float(spec["afundar"])) if spec.has("afundar") else ""],
		[tr("Piso"), _numero(float(spec["piso"])) if spec.has("piso") else ""],
		[tr("Marcações"), " · ".join(marcacoes)],
	])


## Setas pequenas e o "N / M" juntos no centro do rodapé, como no histórico.
func _navegacao(indice: int, quantidade: int, mudar: Callable) -> void:
	var linha := HBoxContainer.new()
	linha.name = "Navegacao"
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override("separation", 14)
	_rodape.add_child(linha)
	linha.add_child(_seta(-1, tr("Anterior"), indice == 0, mudar))
	var contador := Label.new()
	contador.text = "%d / %d" % [indice + 1, quantidade]
	contador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contador.custom_minimum_size.x = 64
	linha.add_child(contador)
	linha.add_child(_seta(1, tr("Próximo"), indice >= quantidade - 1, mudar))


func _seta(passo: int, dica: String, desativada: bool, mudar: Callable) -> Button:
	var botao := Button.new()
	botao.tooltip_text = dica
	botao.custom_minimum_size = SETA
	botao.disabled = desativada
	botao.pressed.connect(func() -> void:
		Audio.efeito("ui_hover")
		mudar.call(passo))
	var chevron := Control.new()
	chevron.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chevron.draw.connect(func() -> void:
		var centro := chevron.size * 0.5
		var cor := Color(1, 1, 1, 0.3) if botao.disabled else Color(Identidade.CREME, 0.92)
		var ponta := Vector2(4.0 * passo, 0)
		chevron.draw_polyline(PackedVector2Array([centro - ponta + Vector2(0, -6), centro + ponta, centro - ponta + Vector2(0, 6)]), cor, 1.8, true))
	botao.add_child(chevron)
	return botao


func _texto(chave: String) -> String:
	return str(IdiomaMenu.campo(_textos, chave))


## Mundo 3D isolado: reutiliza o catálogo, sem adicionar moradores ao vale. O fundo é um
## padrão de azulejo desenhado atrás do 3D (transparente), com moldura; a luz vem de
## cima e a sombra é um disco no chão, centrado nos pés. Moradores usam uma altura de
## referência comum (ALTURA_QUADRO): cada um aparece no seu tamanho, no mesmo quadro.
func _montar_previa(pai: Control, chave: String, altura: float = 0) -> void:
	var fundo := Control.new()
	fundo.name = "FundoPrevia"
	fundo.custom_minimum_size = PREVIA
	fundo.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	fundo.clip_contents = true
	fundo.draw.connect(_desenhar_fundo_previa.bind(fundo))
	pai.add_child(fundo)
	var suporte := SubViewportContainer.new()
	suporte.name = "Previa3D"
	suporte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	suporte.stretch = true
	suporte.tooltip_text = tr("Arrastar: girar · roda: zoom · botão direito: mover · duplo clique: centralizar")
	suporte.gui_input.connect(_girar_previa)
	fundo.add_child(suporte)
	var viewport := SubViewport.new()
	_preview_viewport = viewport
	viewport.size = Vector2i(PREVIA)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	suporte.add_child(viewport)
	var mundo := Node3D.new()
	viewport.add_child(mundo)
	var ambiente := WorldEnvironment.new()
	var luz_ambiente := Environment.new()
	luz_ambiente.background_mode = Environment.BG_CLEAR_COLOR
	luz_ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	luz_ambiente.ambient_light_color = Color.WHITE
	luz_ambiente.ambient_light_energy = 0.75
	ambiente.environment = luz_ambiente
	mundo.add_child(ambiente)
	# Luz de cima, quase a pino, com um leve ângulo para dar volume ao rosto.
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-72, -15, 0)
	luz.light_energy = 1.35
	mundo.add_child(luz)
	_preview_pivo = Node3D.new()
	mundo.add_child(_preview_pivo)
	var modelo: Node3D
	var dimensao := Vector3(1, maxf(altura, 1.7), 1)
	if Estilo.tripo():
		var escala := altura / float(AjustesConteudo.peca(chave).get("altura", altura)) if altura > 0 else 1.0
		modelo = CatalogoAssets.instanciar(chave, _preview_pivo, Vector3.ZERO, escala)
		if modelo != null:
			dimensao = (modelo.get_meta("limites") as AABB).size
	elif altura > 0:
		modelo = Humanoide.novo(chave, altura)
		_preview_pivo.add_child(modelo)
	_preview_modelo = modelo
	if modelo == null:
		var aviso := Label.new()
		aviso.text = _texto("indisponivel")
		aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		aviso.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		aviso.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fundo.add_child(aviso)
		return
	# Usa uma pose do idle autoral, em vez de apresentar o rig em T.
	for tocador: AnimationPlayer in modelo.find_children("*", "AnimationPlayer", true, false):
		for clipe: StringName in tocador.get_animation_list():
			if str(clipe).to_lower().contains("idle"):
				tocador.play(clipe)
				tocador.advance(0.2)
				tocador.pause()
				break
	# Sombra concêntrica: disco com gradiente radial, logo acima do chão, sob o modelo.
	var raio := 0.42 if altura > 0 else maxf(dimensao.x, dimensao.z) * 0.6
	var disco := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2.ONE * raio * 2.0
	disco.mesh = plano
	var gradiente := Gradient.new()
	gradiente.set_color(0, Color(0, 0, 0, 0.55))
	gradiente.set_color(1, Color(0, 0, 0, 0))
	var textura := GradientTexture2D.new()
	textura.gradient = gradiente
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(0.5, 0.0)
	var material_sombra := StandardMaterial3D.new()
	material_sombra.albedo_texture = textura
	material_sombra.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_sombra.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disco.material_override = material_sombra
	disco.position.y = 0.005
	mundo.add_child(disco)
	_camera = Camera3D.new()
	_camera.fov = 35
	mundo.add_child(_camera)
	# Moradores: quadro da altura de referência (cada um no seu tamanho). Peças: pela
	# maior medida, como antes.
	var quadro := ALTURA_QUADRO if altura > 0 else maxf(maxf(dimensao.x, dimensao.y), dimensao.z)
	_distancia_inicial = quadro * (1.95 if altura > 0 else 2.3)
	_alvo_inicial = Vector3(0, quadro * 0.5 if altura > 0 else dimensao.y * 0.5, 0)
	_centralizar_previa()


## Volta a prévia ao enquadramento inicial (duplo clique ou botão do canto).
func _centralizar_previa() -> void:
	if _preview_pivo == null:
		return
	_preview_pivo.rotation = Vector3.ZERO
	_alvo = _alvo_inicial
	_distancia = _distancia_inicial
	_elevacao = 0.06
	_aplicar_camera()


func _aplicar_camera() -> void:
	if _camera == null:
		return
	var direcao := Vector3(0.15, _elevacao, 1.0).normalized()
	_camera.position = _alvo + direcao * _distancia
	_camera.look_at(_alvo)
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Controles da prévia: arrastar com o esquerdo gira o modelo (horizontal) e inclina a
## câmera (vertical); a roda aproxima e afasta; o botão direito ou o do meio movem o
## enquadramento; o duplo clique centraliza.
func _girar_previa(evento: InputEvent) -> void:
	if _preview_pivo == null:
		return
	var botao := evento as InputEventMouseButton
	if botao != null and botao.pressed:
		if botao.double_click and botao.button_index == MOUSE_BUTTON_LEFT:
			_centralizar_previa()
		elif botao.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var fator := 0.9 if botao.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1
			_distancia = clampf(_distancia * fator, _distancia_inicial * 0.35, _distancia_inicial * 2.5)
			_aplicar_camera()
		accept_event()
		return
	var movimento := evento as InputEventMouseMotion
	if movimento == null:
		return
	if movimento.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_preview_pivo.rotate_y(movimento.relative.x * 0.012)
		_elevacao = clampf(_elevacao + movimento.relative.y * 0.006, -0.25, 1.2)
		_aplicar_camera()
	elif movimento.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
		var passo := _distancia * 0.0022
		_alvo += (-_camera.global_basis.x * movimento.relative.x + _camera.global_basis.y * movimento.relative.y) * passo
		_aplicar_camera()


## Fundo da prévia: laca com luz de cima, treliça de azulejo (losangos cobalto e pontos de
## ouro) e uma moldura de dois fios dourados com losangos nos cantos.
func _desenhar_fundo_previa(fundo: Control) -> void:
	var area := Rect2(Vector2.ZERO, fundo.size)
	fundo.draw_rect(area, Color("0f1d16"))
	# Luz de cima: faixas suaves que clareiam o alto do quadro.
	for i in 6:
		var altura := area.size.y * (0.55 - i * 0.08)
		fundo.draw_rect(Rect2(0, 0, area.size.x, altura), Color(1, 0.95, 0.8, 0.018))
	var passo := 26.0
	var cobalto := Color(0.29, 0.43, 0.75, 0.15)
	var ouro := Color(DOURADO, 0.15)
	var y := 0.0
	var linha := 0
	while y <= area.size.y + passo:
		var x := (passo * 0.5) if linha % 2 else 0.0
		while x <= area.size.x + passo:
			var c := Vector2(x, y)
			fundo.draw_polyline(PackedVector2Array([c + Vector2(0, -7), c + Vector2(7, 0), c + Vector2(0, 7), c + Vector2(-7, 0), c + Vector2(0, -7)]), cobalto, 1.0, true)
			fundo.draw_circle(c + Vector2(passo * 0.5, 0), 1.2, ouro)
			x += passo
		y += passo * 0.5
		linha += 1
	fundo.draw_rect(area.grow(-0.5), Color(DOURADO, 0.55), false, 1.0)
	fundo.draw_rect(area.grow(-5.5), Color(DOURADO, 0.22), false, 1.0)
	for canto in [Vector2(0, 0), Vector2(area.size.x, 0), Vector2(0, area.size.y), area.size]:
		var c := (canto as Vector2) + ((area.size * 0.5 - canto) as Vector2).sign() * 5.5
		fundo.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4), c + Vector2(4, 0), c + Vector2(0, 4), c + Vector2(-4, 0)]), DOURADO)


## Uma fala: ▶ (toca assets/audio/vozes/<audio>.mp3) e o texto ao lado, em até duas
## linhas (o inteiro fica na dica). Sem fala, a vaga fica reservada e vazia.
func _linha_fala(fala: Dictionary) -> void:
	var linha := HBoxContainer.new()
	linha.name = "Fala"
	linha.custom_minimum_size.y = 40
	linha.add_theme_constant_override("separation", 10)
	_lista.add_child(linha, true)
	if fala.is_empty():
		return
	var icone: HudIcon = HudIcon.new().configurar("tocar")
	var tocar := Button.new()
	tocar.set_meta("icone", icone)
	tocar.theme_type_variation = &"BotaoIcone"
	tocar.custom_minimum_size = Vector2(32, 32)
	tocar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tocar.focus_mode = Control.FOCUS_NONE
	# O ícone desenha na grade de 24 e aparece com 16, no centro dos 32 do botão.
	icone.size = Vector2(24, 24)
	icone.scale = Vector2.ONE * (16.0 / 24.0)
	icone.position = Vector2(8, 8)
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tocar.add_child(icone)
	var audio := str(fala.get("audio", ""))
	var caminho := PASTA_VOZES + audio + ".mp3"
	if audio.is_empty() or not ResourceLoader.exists(caminho):
		tocar.disabled = true
		icone.modulate.a = 0.35
		tocar.tooltip_text = tr("Áudio ainda não gravado")
	else:
		tocar.tooltip_text = tr("Ouvir a fala")
		tocar.pressed.connect(func() -> void:
			Audio.efeito("ui_confirmar")
			if _fala_tocando == tocar:
				_parar_fala()
				return
			_tocar(caminho)
			_fala_tocando = tocar
			icone.configurar("pausar")
			icone.queue_redraw()
			tocar.tooltip_text = tr("Parar a fala"))
	linha.add_child(tocar)
	var texto := Label.new()
	texto.text = "“%s”" % str(fala.get("texto", ""))
	texto.tooltip_text = texto.text
	texto.mouse_filter = Control.MOUSE_FILTER_PASS
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.max_lines_visible = 2
	texto.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Identidade.papel_leitura(texto, 13)
	linha.add_child(texto)


## Para a fala e devolve o ▶ ao botão que tocava.
func _parar_fala() -> void:
	if _voz.playing:
		_voz.stop()
	if is_instance_valid(_fala_tocando):
		var icone: HudIcon = _fala_tocando.get_meta("icone")
		icone.configurar("tocar")
		icone.queue_redraw()
		_fala_tocando.tooltip_text = tr("Ouvir a fala")
	_fala_tocando = null


## Toca uma fala no tocador local, parando a anterior; o volume segue o canal de vozes.
func _tocar(caminho: String) -> void:
	if not ResourceLoader.exists(caminho):
		return
	_parar_fala()
	_voz.stream = load(caminho)
	_voz.volume_db = Audio.volume_escuta_vozes_db()
	_voz.play()


## Campos de um morador: nome, altura, volume da voz, postos por período e falas.
func _editor_morador(pessoa: Dictionary) -> void:
	var id := String(pessoa.get("id", ""))
	var caixa := _caixa_editor()
	var nome := LineEdit.new()
	nome.text = String(pessoa.get("nome", id))
	nome.custom_minimum_size.x = 260
	nome.text_changed.connect(func(texto: String) -> void:
		if not texto.strip_edges().is_empty():
			AjustesConteudo.definir_morador(id, "nome", texto.strip_edges()))
	_campo(caixa, tr("Nome"), nome)
	_campo(caixa, tr("Altura (m)"), _numero_editavel(float(pessoa.get("altura", 1.7)), 1.2, 2.2, 0.01,
		func(v: float) -> void: AjustesConteudo.definir_morador(id, "altura", v)))
	var volume := _numero_editavel(float(pessoa.get("volume_voz_db", 0.0)), -12.0, 6.0, 0.5,
		func(v: float) -> void: AjustesConteudo.definir_morador(id, "volume_voz_db", v))
	_campo(caixa, tr("Volume da voz (dB)"), volume)
	var postos: Dictionary = pessoa.get("postos", {})
	if not postos.is_empty():
		var titulo := Label.new()
		titulo.text = tr("Postos (lugar e deslocamento em unidades)")
		titulo.add_theme_color_override("font_color", DOURADO)
		caixa.add_child(titulo)
		for periodo: Array in PERIODOS:
			if not postos.has(periodo[0]):
				continue
			var posto: Array = postos[periodo[0]]
			var desl: Array = posto[1] if posto.size() > 1 and posto[1] is Array else [0, 0, 0]
			var estado := {"ancora": String(posto[0]), "dx": float(desl[0]), "dz": float(desl[2])}
			var chave_periodo := String(periodo[0])
			var gravar := func() -> void:
				AjustesConteudo.definir_posto(id, chave_periodo, estado["ancora"], Vector3(estado["dx"], 0, estado["dz"]))
			var linha := HBoxContainer.new()
			linha.add_theme_constant_override("separation", 8)
			var rotulo := Label.new()
			rotulo.text = tr(String(periodo[1]))
			rotulo.custom_minimum_size.x = 110
			linha.add_child(rotulo)
			var lugares := OptionButton.new()
			var opcoes: Array[String] = _ancoras.duplicate()
			if not opcoes.has(estado["ancora"]):
				opcoes.push_front(estado["ancora"])
			for lugar: String in opcoes:
				lugares.add_item(lugar)
			lugares.select(opcoes.find(estado["ancora"]))
			lugares.custom_minimum_size.x = 250
			lugares.item_selected.connect(func(i: int) -> void:
				estado["ancora"] = opcoes[i]
				gravar.call())
			linha.add_child(lugares)
			linha.add_child(_numero_editavel(estado["dx"], -30.0, 30.0, 0.1, func(v: float) -> void:
				estado["dx"] = v
				gravar.call(), "x "))
			linha.add_child(_numero_editavel(estado["dz"], -30.0, 30.0, 0.1, func(v: float) -> void:
				estado["dz"] = v
				gravar.call(), "z "))
			caixa.add_child(linha)
	var falas: Array = pessoa.get("falas", [])
	for indice in falas.size():
		if not (falas[indice] is Dictionary):
			continue
		var texto := LineEdit.new()
		texto.text = String(falas[indice].get("texto", ""))
		texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var i := indice
		texto.text_changed.connect(func(novo: String) -> void: AjustesConteudo.definir_fala(id, i, novo))
		_campo(caixa, tr("Fala %d (balão)") % (indice + 1), texto)


## Campos de uma peça: a medida que normaliza o modelo, afundar e tronco.
func _editor_peca(chave: String, spec: Dictionary) -> void:
	var caixa := _caixa_editor()
	var medida := "altura" if spec.has("altura") else "largura"
	_campo(caixa, tr("Altura (u)") if medida == "altura" else tr("Largura (u)"),
		_numero_editavel(float(spec.get(medida, 1.0)), 0.05, 40.0, 0.05,
			func(v: float) -> void: AjustesConteudo.definir_peca(chave, medida, v)))
	_campo(caixa, tr("Afundar (u)"), _numero_editavel(float(spec.get("afundar", 0.0)), -2.0, 6.0, 0.05,
		func(v: float) -> void: AjustesConteudo.definir_peca(chave, "afundar", v)))
	if spec.has("tronco"):
		_campo(caixa, tr("Tronco (raio, u)"), _numero_editavel(float(spec["tronco"]), 0.05, 3.0, 0.01,
			func(v: float) -> void: AjustesConteudo.definir_peca(chave, "tronco", v)))


func _caixa_editor() -> VBoxContainer:
	var moldura := PanelContainer.new()
	moldura.name = "Editor"
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(1, 1, 1, 0.04)
	estilo.border_color = Color(DOURADO, 0.45)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(6)
	estilo.set_content_margin_all(10)
	moldura.add_theme_stylebox_override("panel", estilo)
	_lista.add_child(moldura)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 6)
	moldura.add_child(caixa)
	return caixa


func _campo(caixa: VBoxContainer, rotulo_texto: String, controle: Control) -> void:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	var rotulo := Label.new()
	rotulo.text = rotulo_texto
	rotulo.custom_minimum_size.x = 170
	linha.add_child(rotulo)
	linha.add_child(controle)
	caixa.add_child(linha)


func _numero_editavel(valor: float, minimo: float, maximo: float, passo: float, ao_mudar: Callable, prefixo: String = "") -> SpinBox:
	var campo := SpinBox.new()
	campo.min_value = minimo
	campo.max_value = maximo
	campo.step = passo
	campo.value = valor
	campo.prefix = prefixo
	campo.custom_minimum_size.x = 110
	campo.value_changed.connect(func(v: float) -> void: ao_mudar.call(v))
	return campo


## Título dourado da ficha.
func _titulo_bloco(texto: String, tamanho: int) -> void:
	var rotulo := Label.new()
	rotulo.name = "Titulo"
	rotulo.text = texto
	# Título da ficha: Cinzel em ouro (papel da tipografia, #199).
	Identidade.papel_rotulo(rotulo, tamanho, DOURADO)
	_lista.add_child(rotulo)


## Linha secundária esmaecida (avisos).
func _detalhe(texto: String) -> void:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Identidade.papel_leitura(rotulo, 14, COR_DETALHE)
	_lista.add_child(rotulo)


## Sem filtro tudo passa; com filtro, basta um dos textos conter o trecho.
func _passa_filtro(textos: Array) -> bool:
	if filtro.is_empty():
		return true
	for texto in textos:
		if str(texto).to_lower().contains(filtro):
			return true
	return false


## 7.2 → "7,2": números curtos no formato do jogo, sem zeros à direita.
func _numero(valor: float) -> String:
	var texto := String.num(valor, 2)
	if texto.contains("."):
		texto = texto.rstrip("0").rstrip(".")
	return texto.replace(".", ",")
