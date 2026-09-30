extends Control
## PERSONAGENS: painel do menu com os moradores do vale (dados, postos e falas com
## áudio) e o catálogo de peças do Tripo (catalogo_assets.gd), com filtro por nome.
## EDITAR abre os campos de cada morador (nome, altura, volume da voz, falas e o posto
## de cada período) e de cada peça (medida, afundar, tronco); tudo é salvo na hora em
## ajustes_conteudo.gd e vale na próxima montagem do vale.
## O anfitrião (abertura.gd) adiciona o painel à camada do menu e chama abrir(tema);
## o × do cabeçalho e o FECHAR emitem `fechado`, e quem hospeda libera o nó.

const TemaMenu = preload("res://scripts/prototipo_3d/tema_menu.gd")
const PainelAjustes = preload("res://scripts/prototipo_3d/painel_ajustes.gd")
const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")

## Pedido de fechar (×, FECHAR): o anfitrião volta à Home e libera o painel.
signal fechado

const TAMANHO := Vector2(860, 680)
const CAMINHO_NPCS := "res://data/npcs_3d.json"
const PASTA_VOZES := "res://assets/audio/vozes/"
const DOURADO := Color("e2c47f")
const COR_DETALHE := Color(0.78, 0.79, 0.72)
## Ordem e rótulo dos períodos dos postos (chaves de npcs_3d.json).
const PERIODOS := [["manha", "manhã"], ["tarde", "tarde"], ["entardecer", "entardecer"], ["noite", "noite"], ["madrugada", "madrugada"]]
## Ordem e rótulo das pastas do catálogo (primeiro trecho do caminho em PECAS).
const PASTAS := [["arvores", "Árvores"], ["construcoes", "Construções"], ["casas", "Casas"], ["aderecos", "Adereços"], ["personagens", "Personagens"], ["itens", "Itens"]]

## Aba aberta: 0 = MORADORES, 1 = ASSETS.
var aba := 0
## Filtro por nome (minúsculas), aplicado na aba aberta.
var filtro := ""
## Pedro primeiro, depois os moradores e por fim o viajante (dicionários de npcs_3d.json).
var _pessoas: Array = []
var _botoes_abas: Array[Button] = []
var _lista: VBoxContainer
var _rolagem: ScrollContainer
## Tocador único das falas: começar uma fala para a anterior.
var _voz: AudioStreamPlayer
## Ids de moradores e chaves de peças com o editor aberto.
var _editando: Dictionary = {}
## Âncoras do vale montado atrás do menu (destinos possíveis dos postos).
var _ancoras: Array[String] = []


## Monta o painel centrado, no estilo dos outros painéis do menu (tema recebido).
func abrir(tema: Theme) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Cliques fora da caixa passam ao anfitrião, que fecha o modal (padrão dos outros).
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = tema if tema else TemaMenu.criar()
	_carregar_pessoas()
	_voz = AudioStreamPlayer.new()
	add_child(_voz)
	var caixa := PanelContainer.new()
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
	Identidade.emoldurar(caixa)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 10)
	caixa.add_child(coluna)
	PainelAjustes.cabecalho(coluna, tr("Personagens"), func() -> void: fechado.emit(),
		tr("Moradores e peças do vale, com falas e medidas."))
	var abas := HBoxContainer.new()
	abas.add_theme_constant_override("separation", 8)
	coluna.add_child(abas)
	var rotulos_abas := [tr("MORADORES"), tr("ASSETS")]
	for indice in range(rotulos_abas.size()):
		var botao := Button.new()
		botao.text = String(rotulos_abas[indice])
		botao.toggle_mode = true
		botao.custom_minimum_size.y = 40
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		botao.mouse_entered.connect(func() -> void: Audio.efeito("ui_hover"))
		botao.pressed.connect(func() -> void:
			Audio.efeito("ui_confirmar")
			_trocar_aba(indice))
		abas.add_child(botao)
		_botoes_abas.append(botao)
	var campo := LineEdit.new()
	campo.placeholder_text = tr("Filtrar por nome…")
	campo.custom_minimum_size.y = 36
	campo.clear_button_enabled = true
	campo.text_changed.connect(func(texto: String) -> void:
		filtro = texto.strip_edges().to_lower()
		_reconstruir_lista())
	coluna.add_child(campo)
	_rolagem = ScrollContainer.new()
	_rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	coluna.add_child(_rolagem)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 6)
	_rolagem.add_child(_lista)
	var aviso := Label.new()
	aviso.text = tr("Os ajustes valem na próxima vez que o vale for montado (JOGAR).")
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.add_theme_font_size_override("font_size", 13)
	aviso.add_theme_color_override("font_color", COR_DETALHE)
	coluna.add_child(aviso)
	var rodape := HBoxContainer.new()
	rodape.alignment = BoxContainer.ALIGNMENT_CENTER
	rodape.add_theme_constant_override("separation", 12)
	coluna.add_child(rodape)
	if AjustesConteudo.pode_gravar_no_projeto():
		# Só pelo editor: grava os ajustes nos arquivos do projeto (vão para o git).
		var gravar := Button.new()
		gravar.text = tr("GRAVAR NO PROJETO")
		gravar.custom_minimum_size = Vector2(220, 44)
		gravar.pressed.connect(func() -> void:
			var feitos := AjustesConteudo.gravar_no_projeto()
			Audio.efeito("ui_confirmar")
			gravar.text = tr("GRAVADO: %d moradores, %d peças") % [feitos.x, feitos.y]
			_carregar_pessoas()
			_reconstruir_lista())
		rodape.add_child(gravar)
	var fechar := Button.new()
	fechar.text = tr("FECHAR")
	fechar.custom_minimum_size = Vector2(220, 44)
	fechar.mouse_entered.connect(func() -> void: Audio.efeito("ui_hover"))
	fechar.pressed.connect(func() -> void:
		Audio.efeito("ui_voltar")
		fechado.emit())
	rodape.add_child(fechar)
	_trocar_aba(0)
	fechar.grab_focus()


## Pedro (guia) primeiro, depois os moradores e por fim o viajante (altura do catálogo).
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
	_ancoras.clear()
	var mundo := get_tree().get_first_node_in_group("mundo") if is_inside_tree() else null
	if mundo != null and mundo.get("ancoras") is Dictionary:
		for nome: String in mundo.ancoras:
			# Direções e frentes das casas não são lugares.
			if nome.ends_with("Frente") or nome == "PierDirecao":
				continue
			_ancoras.append(nome)
	_ancoras.sort()


func _trocar_aba(nova: int) -> void:
	aba = nova
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
	for filho in _lista.get_children():
		_lista.remove_child(filho)
		filho.queue_free()
	_rolagem.scroll_vertical = 0
	if aba == 0:
		_montar_moradores()
	else:
		_montar_assets()


## MORADORES: nome dourado, linha de dados, postos por período e as falas com ▶.
func _montar_moradores() -> void:
	var achou := false
	for pessoa: Dictionary in _pessoas:
		var id := str(pessoa.get("id", ""))
		var nome := str(pessoa.get("nome", id))
		if not _passa_filtro([nome, id]):
			continue
		achou = true
		var editavel := id != "viajante"
		_titulo_com_editar(nome, 24, "m:" + id if editavel else "", AjustesConteudo.morador_ajustado(id))
		var dados: Array = [id]
		if pessoa.has("altura"):
			dados.append("%s m" % _numero(float(pessoa["altura"])))
		var voz: Dictionary = pessoa.get("voz", {})
		if voz.has("nome"):
			dados.append(tr("voz %s") % str(voz["nome"]))
		_detalhe(" · ".join(PackedStringArray(dados)))
		var postos: Dictionary = pessoa.get("postos", {})
		if not postos.is_empty():
			var linhas := PackedStringArray()
			for periodo: Array in PERIODOS:
				if postos.has(periodo[0]):
					var posto: Array = postos[periodo[0]]
					linhas.append("%s · %s" % [tr(String(periodo[1])), tr(str(posto[0]))])
			_detalhe("\n".join(linhas))
		elif id == "pedro":
			# O guia não tem postos: acompanha o jogador (guia_pedro.gd).
			_detalhe(tr("Sem posto fixo: acompanha o viajante pelo vale."))
		if pessoa.has("nota"):
			_detalhe(str(pessoa["nota"]))
		for fala in pessoa.get("falas", []):
			if fala is Dictionary:
				_linha_fala(fala)
		if editavel and _editando.has("m:" + id):
			_editor_morador(pessoa)
		_respiro()
	if not achou:
		_detalhe(tr("Nada com esse nome por aqui."))


## Uma fala: botão ▶ (toca assets/audio/vozes/<audio>.mp3) e o texto ao lado.
func _linha_fala(fala: Dictionary) -> void:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	_lista.add_child(linha)
	var tocar := Button.new()
	tocar.text = "▶"
	tocar.theme_type_variation = &"BotaoIcone"
	tocar.custom_minimum_size = Vector2(32, 32)
	tocar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tocar.focus_mode = Control.FOCUS_NONE
	var audio := str(fala.get("audio", ""))
	var caminho := PASTA_VOZES + audio + ".mp3"
	if audio.is_empty() or not ResourceLoader.exists(caminho):
		tocar.disabled = true
		tocar.tooltip_text = tr("Áudio ainda não gravado")
	else:
		tocar.tooltip_text = tr("Ouvir a fala")
		tocar.pressed.connect(func() -> void:
			Audio.efeito("ui_confirmar")
			_tocar(caminho))
	linha.add_child(tocar)
	var texto := Label.new()
	texto.text = "“%s”" % str(fala.get("texto", ""))
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texto.add_theme_font_size_override("font_size", 15)
	linha.add_child(texto)


## Toca uma fala no tocador local, parando a anterior; o volume segue o canal de vozes.
func _tocar(caminho: String) -> void:
	if not ResourceLoader.exists(caminho):
		return
	_voz.stop()
	_voz.stream = load(caminho)
	_voz.volume_db = Audio.volume_vozes_db()
	_voz.play()


## ASSETS: peças de catalogo_assets.gd agrupadas pela pasta do GLB, na ordem de PASTAS;
## pastas novas (fora da lista) aparecem no fim para nenhuma peça ficar escondida.
func _montar_assets() -> void:
	var grupos: Dictionary = {}
	for chave: String in CatalogoAssets.PECAS:
		var spec: Dictionary = CatalogoAssets.PECAS[chave]
		var pasta := str(spec.get("tripo", "")).get_slice("/", 0)
		if not grupos.has(pasta):
			grupos[pasta] = []
		(grupos[pasta] as Array).append(chave)
	var ordem: Array = []
	for pasta: Array in PASTAS:
		ordem.append([String(pasta[0]), String(pasta[1])])
	for pasta_extra: String in grupos:
		var conhecida := false
		for pasta: Array in PASTAS:
			if String(pasta[0]) == pasta_extra:
				conhecida = true
		if not conhecida:
			ordem.append([pasta_extra, pasta_extra.capitalize()])
	var achou := false
	for pasta: Array in ordem:
		var chaves: Array = grupos.get(pasta[0], [])
		var visiveis: Array = chaves.filter(func(chave: String) -> bool: return _passa_filtro([chave]))
		if visiveis.is_empty():
			continue
		achou = true
		_titulo_bloco(tr(String(pasta[1])), 20)
		for chave: String in visiveis:
			_linha_peca(chave, AjustesConteudo.peca(chave))
		_respiro()
	if not achou:
		_detalhe(tr("Nada com esse nome por aqui."))


## Uma peça: chave, nome do arquivo, medida e as marcações do catálogo quando existem.
func _linha_peca(chave: String, spec: Dictionary) -> void:
	var bloco := VBoxContainer.new()
	bloco.add_theme_constant_override("separation", 2)
	_lista.add_child(bloco)
	var cabeca := HBoxContainer.new()
	cabeca.add_theme_constant_override("separation", 10)
	bloco.add_child(cabeca)
	var nome := Label.new()
	nome.text = chave + ("  •" if AjustesConteudo.peca_ajustada(chave) else "")
	nome.add_theme_font_size_override("font_size", 16)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabeca.add_child(nome)
	cabeca.add_child(_botao_editar("p:" + chave))
	var partes := PackedStringArray([str(spec.get("tripo", "")).get_file()])
	if spec.has("altura"):
		partes.append(tr("altura %s u") % _numero(float(spec["altura"])))
	elif spec.has("largura"):
		partes.append(tr("largura %s u") % _numero(float(spec["largura"])))
	if spec.has("tronco"):
		partes.append(tr("tronco %s") % _numero(float(spec["tronco"])))
	if spec.get("caixa", false):
		partes.append(tr("caixa"))
	if spec.has("girar"):
		partes.append(tr("girar"))
	if spec.has("afundar"):
		partes.append(tr("afundar %s") % _numero(float(spec["afundar"])))
	if spec.has("piso"):
		partes.append(tr("piso %s") % _numero(float(spec["piso"])))
	var detalhe := Label.new()
	detalhe.text = " · ".join(partes)
	detalhe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detalhe.add_theme_font_size_override("font_size", 13)
	detalhe.add_theme_color_override("font_color", COR_DETALHE)
	bloco.add_child(detalhe)
	if _editando.has("p:" + chave):
		_editor_peca(bloco, chave, spec)


## Título dourado com o botão EDITAR ao lado (sem `chave`, só o título). O ponto marca
## quem já tem ajuste salvo.
func _titulo_com_editar(texto: String, tamanho: int, chave: String, ajustado: bool) -> void:
	if chave.is_empty():
		_titulo_bloco(texto, tamanho)
		return
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	_lista.add_child(linha)
	var rotulo := Label.new()
	rotulo.text = texto + ("  •" if ajustado else "")
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", DOURADO)
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(rotulo)
	linha.add_child(_botao_editar(chave))


func _botao_editar(chave: String) -> Button:
	var botao := Button.new()
	botao.text = tr("FECHAR EDIÇÃO") if _editando.has(chave) else tr("EDITAR")
	botao.custom_minimum_size = Vector2(130, 30)
	botao.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	botao.pressed.connect(func() -> void:
		Audio.efeito("ui_confirmar")
		if _editando.has(chave):
			_editando.erase(chave)
		else:
			_editando[chave] = true
		var rolagem := _rolagem.scroll_vertical
		_reconstruir_lista()
		# Reabrir a lista não pode jogar a rolagem para o topo.
		await get_tree().process_frame
		_rolagem.scroll_vertical = rolagem)
	return botao


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
	_botao_restaurar(caixa, func() -> void: AjustesConteudo.restaurar_morador(id))


## Campos de uma peça: a medida que normaliza o modelo, afundar e tronco.
func _editor_peca(bloco: VBoxContainer, chave: String, spec: Dictionary) -> void:
	var caixa := _caixa_editor(bloco)
	var medida := "altura" if spec.has("altura") else "largura"
	_campo(caixa, tr("Altura (u)") if medida == "altura" else tr("Largura (u)"),
		_numero_editavel(float(spec.get(medida, 1.0)), 0.05, 40.0, 0.05,
			func(v: float) -> void: AjustesConteudo.definir_peca(chave, medida, v)))
	_campo(caixa, tr("Afundar (u)"), _numero_editavel(float(spec.get("afundar", 0.0)), -2.0, 6.0, 0.05,
		func(v: float) -> void: AjustesConteudo.definir_peca(chave, "afundar", v)))
	if spec.has("tronco"):
		_campo(caixa, tr("Tronco (raio, u)"), _numero_editavel(float(spec["tronco"]), 0.05, 3.0, 0.01,
			func(v: float) -> void: AjustesConteudo.definir_peca(chave, "tronco", v)))
	_botao_restaurar(caixa, func() -> void: AjustesConteudo.restaurar_peca(chave))


func _caixa_editor(pai: Control = null) -> VBoxContainer:
	var moldura := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(1, 1, 1, 0.04)
	estilo.border_color = Color(DOURADO, 0.45)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(6)
	estilo.set_content_margin_all(10)
	moldura.add_theme_stylebox_override("panel", estilo)
	if pai != null:
		pai.add_child(moldura)
	else:
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


func _botao_restaurar(caixa: VBoxContainer, restaurar: Callable) -> void:
	var botao := Button.new()
	botao.text = tr("Restaurar o padrão")
	botao.size_flags_horizontal = Control.SIZE_SHRINK_END
	botao.pressed.connect(func() -> void:
		restaurar.call()
		Audio.efeito("ui_voltar")
		_carregar_pessoas()
		_reconstruir_lista())
	caixa.add_child(botao)


## Título dourado de um bloco (nome do morador ou pasta de peças).
func _titulo_bloco(texto: String, tamanho: int) -> void:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", DOURADO)
	_lista.add_child(rotulo)


## Linha secundária esmaecida (dados, postos, avisos).
func _detalhe(texto: String) -> void:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.add_theme_font_size_override("font_size", 14)
	rotulo.add_theme_color_override("font_color", COR_DETALHE)
	_lista.add_child(rotulo)


## Sem filtro tudo passa; com filtro, basta um dos textos conter o trecho.
func _passa_filtro(textos: Array) -> bool:
	if filtro.is_empty():
		return true
	for texto in textos:
		if str(texto).to_lower().contains(filtro):
			return true
	return false


## Respiro entre blocos da lista.
func _respiro() -> void:
	var vao := Control.new()
	vao.custom_minimum_size.y = 10
	_lista.add_child(vao)


## 7.2 → "7,2": números curtos no formato do jogo, sem zeros à direita.
func _numero(valor: float) -> String:
	var texto := String.num(valor, 2)
	if texto.contains("."):
		texto = texto.rstrip("0").rstrip(".")
	return texto.replace(".", ",")
