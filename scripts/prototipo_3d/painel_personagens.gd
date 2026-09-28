extends Control
## PERSONAGENS: painel do menu com os moradores do vale (dados, postos e falas com
## áudio) e o catálogo de peças do Tripo (catalogo_assets.gd), com filtro por nome.
## O anfitrião (abertura.gd) adiciona o painel à camada do menu e chama abrir(tema);
## o × do cabeçalho e o FECHAR emitem `fechado`, e quem hospeda libera o nó.

const TemaMenu = preload("res://scripts/prototipo_3d/tema_menu.gd")
const PainelAjustes = preload("res://scripts/prototipo_3d/painel_ajustes.gd")

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
	caixa.add_theme_stylebox_override("panel", TemaMenu.estilo_painel())
	caixa.custom_minimum_size = TAMANHO
	caixa.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	caixa.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caixa.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(caixa)
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
	var rodape := HBoxContainer.new()
	rodape.alignment = BoxContainer.ALIGNMENT_CENTER
	coluna.add_child(rodape)
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
		_titulo_bloco(nome, 24)
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
			_linha_peca(chave, CatalogoAssets.PECAS[chave])
		_respiro()
	if not achou:
		_detalhe(tr("Nada com esse nome por aqui."))


## Uma peça: chave, nome do arquivo, medida e as marcações do catálogo quando existem.
func _linha_peca(chave: String, spec: Dictionary) -> void:
	var bloco := VBoxContainer.new()
	bloco.add_theme_constant_override("separation", 2)
	_lista.add_child(bloco)
	var nome := Label.new()
	nome.text = chave
	nome.add_theme_font_size_override("font_size", 16)
	bloco.add_child(nome)
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
