extends RefCounted
## Tela de carregamento entre o menu e o vale (nos dois sentidos), na identidade
## "Crônica do Recôncavo": a capa pintada do vale — de dia ou de noite, pela hora em que
## o jogador chega ou sai —, o logotipo em talha dourada, uma nota do almanaque, a etapa
## com a porcentagem, a rosa dos ventos girando e um fio de ouro na base como barra.
## `trocar_cena` carrega a cena em segundo plano, avança a barra e troca de cena; a tela
## some quando o vale fica pronto.

const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")

const OURO := Identidade.OURO
const CREME := Identidade.CREME
const COBALTO := Identidade.COBALTO
const LOGO := Identidade.LOGO
const ROSA := Identidade.ROSA
const CAPA_DIA := Identidade.PASTA + "capa_dia.webp"
const CAPA_NOITE := Identidade.PASTA + "capa_noite.webp"
const FONTE_TITULO := Identidade.FONTE_TITULO
const FONTE_TEXTO := Identidade.FONTE_TEXTO
const FONTE_ITALICO := Identidade.FONTE_ITALICO

## A capa da noite entra espelhada: a lua sai de trás do logotipo e a igreja de trás do
## almanaque (e a torre fica à esquerda, como na igreja do jogo).
const ESPELHAR_NOITE := true
## Pontos na arte original (frações da largura e da altura): para onde a câmera lenta
## avança, o lampião do viajante e os olhos na mata. Espelhados junto com a capa.
const FOCO_DIA := Vector2(0.70, 0.56)
const FOCO_NOITE := Vector2(0.60, 0.62)
const LAMPIAO := Vector2(0.668, 0.615)
const OLHOS := Vector2(0.895, 0.355)
## Medidas na tela-base de 1280×720 (o projeto escala a interface com a janela).
const MARGEM := 54.0
const LARGURA_LOGO := 397.0
const LARGURA_NOTA := 470.0
## De noite a nota fica mais estreita para não passar por cima do viajante.
const LARGURA_NOTA_NOITE := 380.0
const TEMPO_NOTA := 7.0

## De dia, o almanaque traz fatos que o próprio jogo conta; de noite, o que se diz no
## vale. As listas moram na identidade, compartilhadas com a home (abertura.gd).
const NOTAS_DIA := Identidade.NOTAS_DIA
const NOTAS_NOITE := Identidade.NOTAS_NOITE


## Monta a tela sobre `pai` (CanvasLayer ou Control de tela cheia) e devolve a barra.
## `hora` escolhe a capa (dia ou noite); negativa, vale a hora atual do relógio.
static func mostrar(pai: Node, tema: Theme, mensagem: String, hora: float = -1.0) -> ProgressBar:
	var noite: bool = Dia.eh_noite_em(Dia.hora if hora < 0.0 else hora)
	var screen := mostrar_capa(pai, tema, noite)
	screen.name = "TelaCarregamento"
	_almanaque(screen, noite)
	var textos := _situacao(screen, mensagem)
	var bar := _barra(screen, textos[1])
	screen.modulate.a = 0.0
	var entrada := screen.create_tween()
	entrada.tween_property(screen, "modulate:a", 1.0, 0.2)
	screen.set_meta("entrada", entrada)
	bar.set_meta("tela", screen)
	bar.set_meta("mensagem", textos[0])
	return bar


## Capa e marca compartilhadas com a seleção inicial; só recursos de interface.
static func mostrar_capa(pai: Node, tema: Theme, noite: bool = false) -> Control:
	var screen := Control.new()
	screen.name = "SelecaoIdioma"
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.theme = tema
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.clip_contents = true
	screen.process_mode = Node.PROCESS_MODE_ALWAYS
	screen.set_meta("noite", noite)
	pai.add_child(screen)
	var fundo := ColorRect.new()
	fundo.color = Color(0.02, 0.02, 0.03)
	_cobrir(fundo)
	screen.add_child(fundo)
	_capa(screen, noite)
	_veus(screen)
	_marca(screen)
	return screen


## A capa pintada cobre a tela e avança devagar sobre o foco (46 s para ir, 46 para voltar).
static func _capa(tela: Control, noite: bool) -> void:
	var espelhada := noite and ESPELHAR_NOITE
	var capa := TextureRect.new()
	capa.name = "Capa"
	capa.texture = load(CAPA_NOITE if noite else CAPA_DIA) as Texture2D
	capa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	capa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	capa.flip_h = espelhada
	capa.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_cobrir(capa)
	tela.add_child(capa)
	var foco := _na_capa(FOCO_NOITE if noite else FOCO_DIA, espelhada)
	capa.resized.connect(func() -> void: capa.pivot_offset = capa.size * foco)
	capa.pivot_offset = capa.size * foco
	capa.scale = Vector2.ONE * 1.03
	var camera := capa.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	camera.tween_property(capa, "scale", Vector2.ONE * 1.12, 46.0)
	camera.tween_property(capa, "scale", Vector2.ONE * 1.03, 46.0)
	if noite:
		_lampiao(capa, _na_capa(LAMPIAO, espelhada))
		_olhos(capa, _na_capa(OLHOS, espelhada))


## Luz quente e trêmula no lampião do viajante (capa da noite). Filha da capa, acompanha
## a câmera lenta.
static func _lampiao(capa: Control, ponto: Vector2) -> void:
	var luz := TextureRect.new()
	luz.texture = _brilho(Color(1.0, 0.62, 0.25, 0.42), 128)
	luz.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	luz.material = _aditivo()
	luz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ancorar(luz, ponto, Vector2(430, 430))
	capa.add_child(luz)
	var tremor := luz.create_tween().set_loops()
	for passo in [[0.78, 0.13], [1.0, 0.21], [0.86, 0.09], [0.97, 0.17], [0.82, 0.11], [1.0, 0.24]]:
		tremor.tween_property(luz, "modulate:a", passo[0], passo[1])


## Um par de olhos âmbar que de vez em quando se acende na mata e pisca (capa da noite).
static func _olhos(capa: Control, ponto: Vector2) -> void:
	var par := Control.new()
	par.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ancorar(par, ponto, Vector2(20, 8))
	capa.add_child(par)
	for x in [4.0, 16.0]:
		var olho := TextureRect.new()
		olho.texture = _brilho(Color(1.0, 0.74, 0.32, 1.0), 32)
		olho.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		olho.material = _aditivo()
		olho.mouse_filter = Control.MOUSE_FILTER_IGNORE
		olho.position = Vector2(x - 5.0, -1.0)
		olho.size = Vector2(10, 10)
		par.add_child(olho)
	par.modulate.a = 0.0
	var espreita := par.create_tween().set_loops()
	espreita.tween_interval(8.0)
	espreita.tween_property(par, "modulate:a", 0.95, 0.7)
	espreita.tween_interval(1.4)
	espreita.tween_property(par, "modulate:a", 0.0, 0.06)
	espreita.tween_property(par, "modulate:a", 0.95, 0.08)
	espreita.tween_interval(1.8)
	espreita.tween_property(par, "modulate:a", 0.0, 0.9)


## Faixas escuras no alto (logotipo) e na base (textos), mais uma vinheta leve.
static func _veus(tela: Control) -> void:
	var vertical := Gradient.new()
	vertical.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.58, 0.83, 1.0])
	vertical.colors = PackedColorArray([
		Color(0.04, 0.035, 0.055, 0.66), Color(0.04, 0.035, 0.055, 0.28), Color(0.04, 0.035, 0.055, 0.0),
		Color(0.035, 0.024, 0.008, 0.0), Color(0.035, 0.024, 0.008, 0.6), Color(0.035, 0.024, 0.008, 0.94),
	])
	var faixa := GradientTexture2D.new()
	faixa.gradient = vertical
	faixa.fill_from = Vector2(0, 0)
	faixa.fill_to = Vector2(0, 1)
	faixa.width = 4
	faixa.height = 256
	var bordas := Gradient.new()
	bordas.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	bordas.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.42)])
	var vinheta := GradientTexture2D.new()
	vinheta.gradient = bordas
	vinheta.fill = GradientTexture2D.FILL_RADIAL
	vinheta.fill_from = Vector2(0.55, 0.47)
	vinheta.fill_to = Vector2(1.15, 0.47)
	vinheta.width = 256
	vinheta.height = 256
	for textura in [faixa, vinheta]:
		var veu := TextureRect.new()
		veu.texture = textura
		veu.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		veu.stretch_mode = TextureRect.STRETCH_SCALE
		_cobrir(veu)
		tela.add_child(veu)


## Logotipo em talha dourada com o lugar e o ano entre filetes de ouro, no alto à esquerda.
static func _marca(tela: Control) -> void:
	var textura := load(LOGO) as Texture2D
	var altura_logo := LARGURA_LOGO * float(textura.get_height()) / float(textura.get_width())
	# Sombra difusa atrás do logotipo: separa o ouro do céu claro do entardecer.
	var sombra := TextureRect.new()
	sombra.texture = _brilho(Color(0.02, 0.02, 0.04, 0.5), 128)
	sombra.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sombra.position = Vector2(MARGEM - 70.0, -40.0)
	sombra.size = Vector2(LARGURA_LOGO + 140.0, altura_logo + 130.0)
	tela.add_child(sombra)
	var marca := VBoxContainer.new()
	marca.position = Vector2(MARGEM, 24.0)
	marca.custom_minimum_size = Vector2(LARGURA_LOGO, 0)
	marca.add_theme_constant_override("separation", 8)
	marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tela.add_child(marca)
	var logo := TextureRect.new()
	logo.name = "Logo"
	logo.texture = textura
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(LARGURA_LOGO, altura_logo)
	marca.add_child(logo)
	var margem := MarginContainer.new()
	margem.add_theme_constant_override("margin_left", 18)
	margem.add_theme_constant_override("margin_right", 18)
	marca.add_child(margem)
	var lugar := HBoxContainer.new()
	lugar.add_theme_constant_override("separation", 12)
	margem.add_child(lugar)
	lugar.add_child(_filete(false))
	var nome := Label.new()
	nome.text = "Bom Jesus dos Pobres · 1887"
	nome.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	nome.uppercase = true
	nome.add_theme_font_override("font", _fonte(FONTE_TITULO, 600, 4))
	nome.add_theme_font_size_override("font_size", 12)
	nome.add_theme_color_override("font_color", CREME)
	_sombra_texto(nome)
	lugar.add_child(nome)
	lugar.add_child(_filete(true))
	marca.modulate.a = 0.0
	marca.create_tween().tween_property(marca, "modulate:a", 1.0, 1.2).set_delay(0.15)


## Nota do almanaque (ou dito do vale, à noite) no canto de baixo à esquerda, trocada a
## cada TEMPO_NOTA segundos. Os textos já saem traduzidos no idioma de quem abriu a tela.
static func _almanaque(tela: Control, noite: bool) -> void:
	var notas: Array[String] = []
	for texto in (NOTAS_NOITE if noite else NOTAS_DIA):
		notas.append(String(TranslationServer.translate(texto)))
	var bloco := VBoxContainer.new()
	bloco.anchor_top = 1.0
	bloco.anchor_bottom = 1.0
	bloco.offset_left = MARGEM
	var largura := LARGURA_NOTA_NOITE if noite else LARGURA_NOTA
	bloco.offset_right = MARGEM + largura
	bloco.offset_top = -58.0
	bloco.offset_bottom = -58.0
	bloco.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bloco.add_theme_constant_override("separation", 9)
	bloco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tela.add_child(bloco)
	var titulo := HBoxContainer.new()
	titulo.add_theme_constant_override("separation", 10)
	bloco.add_child(titulo)
	titulo.add_child(_losango())
	var rotulo := Label.new()
	rotulo.text = String(TranslationServer.translate("Dizem no vale" if noite else "Do almanaque"))
	rotulo.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	rotulo.uppercase = true
	rotulo.add_theme_font_override("font", _fonte(FONTE_TITULO, 600, 4))
	rotulo.add_theme_font_size_override("font_size", 11)
	rotulo.add_theme_color_override("font_color", Color("e2c170"))
	_sombra_texto(rotulo)
	titulo.add_child(rotulo)
	var nota := Label.new()
	nota.name = "Nota"
	nota.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.custom_minimum_size = Vector2(largura, 0)
	nota.add_theme_font_override("font", _fonte(FONTE_ITALICO, 500))
	nota.add_theme_font_size_override("font_size", 22)
	nota.add_theme_color_override("font_color", Color("f6eedb"))
	nota.add_theme_constant_override("line_spacing", 0)
	_sombra_texto(nota)
	bloco.add_child(nota)
	var indice := [Time.get_ticks_msec() % notas.size()]
	nota.text = notas[indice[0]]
	var relogio := Timer.new()
	relogio.wait_time = TEMPO_NOTA
	relogio.autostart = true
	relogio.timeout.connect(func() -> void:
		indice[0] = (indice[0] + 1) % notas.size()
		var troca := nota.create_tween()
		troca.tween_property(nota, "modulate:a", 0.0, 0.35)
		troca.tween_callback(func() -> void: nota.text = notas[indice[0]])
		troca.tween_property(nota, "modulate:a", 1.0, 0.6))
	tela.add_child(relogio)


## Etapa, porcentagem e a rosa dos ventos girando no canto de baixo à direita.
## Devolve [Label da etapa, Label da porcentagem].
static func _situacao(tela: Control, mensagem: String) -> Array[Label]:
	var linha := HBoxContainer.new()
	linha.anchor_left = 1.0
	linha.anchor_right = 1.0
	linha.anchor_top = 1.0
	linha.anchor_bottom = 1.0
	linha.offset_left = -MARGEM
	linha.offset_right = -MARGEM
	linha.offset_top = -50.0
	linha.offset_bottom = -50.0
	linha.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	linha.grow_vertical = Control.GROW_DIRECTION_BEGIN
	linha.alignment = BoxContainer.ALIGNMENT_END
	linha.add_theme_constant_override("separation", 18)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tela.add_child(linha)
	var textos := VBoxContainer.new()
	textos.alignment = BoxContainer.ALIGNMENT_CENTER
	textos.add_theme_constant_override("separation", 2)
	linha.add_child(textos)
	var message := Label.new()
	# O texto já chega traduzido: não muda quando o locale troca durante a carga.
	message.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	message.text = mensagem
	message.uppercase = true
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	message.add_theme_font_override("font", _fonte(FONTE_TITULO, 600, 3))
	message.add_theme_font_size_override("font_size", 13)
	message.add_theme_color_override("font_color", CREME)
	_sombra_texto(message)
	textos.add_child(message)
	var pct := Label.new()
	pct.name = "Porcentagem"
	pct.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	pct.text = "0%"
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var numeros := _fonte(FONTE_TEXTO, 500)
	numeros.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("onum"): 1}
	pct.add_theme_font_override("font", numeros)
	pct.add_theme_font_size_override("font_size", 32)
	pct.add_theme_color_override("font_color", OURO)
	_sombra_texto(pct)
	textos.add_child(pct)
	# A rosa gira dentro de um suporte simples: contêineres zeram a rotação dos filhos.
	var suporte := Control.new()
	suporte.custom_minimum_size = Vector2(70, 70)
	suporte.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	suporte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(suporte)
	var rosa := TextureRect.new()
	rosa.name = "Rosa"
	rosa.texture = load(ROSA) as Texture2D
	rosa.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rosa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rosa.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rosa.size = Vector2(70, 70)
	rosa.pivot_offset = Vector2(35, 35)
	rosa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	suporte.add_child(rosa)
	rosa.create_tween().set_loops().tween_property(rosa, "rotation", TAU, 26.0).from(0.0)
	return [message, pct]


## Fio de ouro na base da tela, com um brilho na ponta; atualiza a porcentagem.
static func _barra(tela: Control, pct: Label) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = "Barra"
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.step = 0.0
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top = -3.0
	bar.offset_bottom = 0.0
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1.0, 0.94, 0.82, 0.1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = OURO
	fill.shadow_color = Color(0.94, 0.81, 0.48, 0.55)
	fill.shadow_size = 6
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	tela.add_child(bar)
	var ponta := TextureRect.new()
	ponta.texture = _brilho(Color(1.0, 0.97, 0.85, 1.0), 64)
	ponta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ponta.material = _aditivo()
	ponta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ponta.size = Vector2(30, 30)
	bar.add_child(ponta)
	bar.value_changed.connect(func(_valor: float) -> void: _avancar(bar, ponta, pct))
	bar.resized.connect(func() -> void: _avancar(bar, ponta, pct))
	_avancar(bar, ponta, pct)
	return bar


static func _avancar(bar: ProgressBar, ponta: Control, pct: Label) -> void:
	ponta.position = Vector2(bar.size.x * float(bar.value), bar.size.y * 0.5) - ponta.size * 0.5
	pct.text = "%d%%" % floori(float(bar.value) * 100.0 + 0.001)


# As peças visuais compartilhadas (losango, filete, fonte, sombra, brilho, aditivo)
# moram na identidade; os nomes locais ficam para as chamadas desta tela.
static func _losango() -> Control:
	return Identidade.losango()


static func _filete(para_direita: bool) -> TextureRect:
	return Identidade.filete(para_direita)


static func _fonte(caminho: String, peso: int, espaco_letras: int = 0) -> FontVariation:
	return Identidade.fonte(caminho, peso, espaco_letras)


static func _sombra_texto(rotulo: Label) -> void:
	Identidade.sombra_texto(rotulo)


static func _brilho(cor: Color, lado: int) -> GradientTexture2D:
	return Identidade.brilho(cor, lado)


static func _aditivo() -> CanvasItemMaterial:
	return Identidade.aditivo()


static func _cobrir(item: Control) -> void:
	item.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Centra `item` em `ponto` (frações do pai) com o tamanho dado.
static func _ancorar(item: Control, ponto: Vector2, tamanho: Vector2) -> void:
	item.anchor_left = ponto.x
	item.anchor_right = ponto.x
	item.anchor_top = ponto.y
	item.anchor_bottom = ponto.y
	item.offset_left = -tamanho.x * 0.5
	item.offset_right = tamanho.x * 0.5
	item.offset_top = -tamanho.y * 0.5
	item.offset_bottom = tamanho.y * 0.5


static func _na_capa(ponto: Vector2, espelhada: bool) -> Vector2:
	return Vector2(1.0 - ponto.x, ponto.y) if espelhada else ponto


## Carrega `cena` em segundo plano e troca para ela. Os arquivos ocupam o primeiro
## quarto da barra; o resto é a montagem do vale (world_builder, grupo "mundo"), que
## acontece ao longo de vários quadros. A tela passa para uma camada própria na raiz
## antes da troca, sobrevive a ela, mostra cada etapa e some quando o vale fica pronto.
const FATIA_ARQUIVOS := 0.25
const TEMPO_LEITURA_MS := 1100


static func trocar_cena(arvore: SceneTree, cena: String, barra: ProgressBar) -> void:
	ResourceLoader.load_threaded_request(cena)
	var progress: Array = []
	while true:
		var status := ResourceLoader.load_threaded_get_status(cena, progress)
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			break
		barra.value = maxf(barra.value, float(progress[0]) * FATIA_ARQUIVOS)
		await arvore.process_frame
	barra.value = FATIA_ARQUIVOS
	var packed := ResourceLoader.load_threaded_get(cena) as PackedScene
	var tela: Control = barra.get_meta("tela", null)
	var camada := CanvasLayer.new()
	camada.layer = 100
	arvore.root.add_child(camada)
	if tela != null:
		# A montagem do vale trava os quadros: a tela entra nela já opaca, nunca no meio
		# do fade, senão o cenário aparece por trás durante todo o carregamento.
		var entrada: Tween = tela.get_meta("entrada", null)
		if entrada != null and entrada.is_valid():
			entrada.kill()
		tela.modulate.a = 1.0
		tela.reparent(camada, false)
	if packed == null:
		arvore.change_scene_to_file(cena)
	else:
		arvore.change_scene_to_packed(packed)
	await arvore.process_frame
	await arvore.process_frame
	# A etapa escrita troca no máximo a cada TEMPO_LEITURA_MS, sempre para a mais
	# recente: dá para ler cada texto sem atrasar a montagem (etapas-relâmpago pulam).
	var mundo := arvore.get_first_node_in_group("mundo")
	# Sem VSync durante a montagem: cada quadro cedido à tela custa só o desenho dela,
	# não a espera pelo monitor (eram segundos somados no carregamento).
	var vsync := DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if mundo != null and not mundo.construido:
		var alvo := [FATIA_ARQUIVOS]
		var mensagem: Label = barra.get_meta("mensagem", null)
		var pendente := [""]
		var ultima_troca := [0]
		mundo.progresso.connect(func(fracao: float, etapa: String) -> void:
			alvo[0] = FATIA_ARQUIVOS + (1.0 - FATIA_ARQUIVOS) * fracao
			pendente[0] = etapa)
		# A barra desliza até o alvo em vez de pular: a montagem cede um quadro por vez.
		while is_instance_valid(mundo) and not mundo.construido:
			barra.value = lerpf(barra.value, alvo[0], 0.15)
			if mensagem != null and is_instance_valid(mensagem) and pendente[0] != "" \
					and Time.get_ticks_msec() - ultima_troca[0] >= TEMPO_LEITURA_MS:
				mensagem.text = mensagem.tr(pendente[0]) + "…"
				pendente[0] = ""
				ultima_troca[0] = Time.get_ticks_msec()
			await arvore.process_frame
	DisplayServer.window_set_vsync_mode(vsync)
	barra.value = 1.0
	if tela != null:
		var sumir := tela.create_tween()
		sumir.tween_property(tela, "modulate:a", 0.0, 0.35)
		await sumir.finished
	camada.queue_free()
