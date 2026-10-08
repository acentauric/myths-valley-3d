extends RefCounted
## Identidade "Crônica do Recôncavo": as cores, fontes e peças visuais que a tela de
## carregamento, o menu (abertura.gd) e o HUD compartilham — filetes de ouro, losango
## de azulejo, brilhos aditivos, sombra de texto, moldura de talha em NinePatch e o
## fio de ouro. Tudo estático: quem usa chama Identidade.<peça>() e adiciona onde quiser.

const OURO := Color("e8c46a")
const CREME := Color("f6ead0")
const COBALTO := Color("1d3f8f")
const ROTULO := Color("e2c170")
const TEXTO := Color("f6eedb")
const LACA := Color(0.082, 0.129, 0.106)
const TERRACOTA := Color("e39475")

const PASTA := "res://assets/prototipo_3d/identidade/"
const LOGO := PASTA + "logo_myths_valley.png"
const ROSA := PASTA + "rosa_dos_ventos.png"
const MOLDURA := "res://assets/ui/moldura_idioma.svg"
const FONTE_TITULO := "res://assets/fonts/Cinzel-Variavel.ttf"
const FONTE_TEXTO := "res://assets/fonts/CormorantGaramond-Variavel.ttf"
const FONTE_ITALICO := "res://assets/fonts/CormorantGaramond-Italico-Variavel.ttf"

## De dia, fatos que o próprio jogo conta (fichas das árvores e a carta náutica); de
## noite, o que se diz no vale. As listas ficam em português; quem mostra traduz com tr().
const NOTAS_DIA := [
	"O mar do vale segue a carta náutica 1108 da Marinha, com a água da preamar de sizígia.",
	"Toda a costa da baía é franjada de coqueiro, inclinado para o mar como quem procura a água.",
	"Em 1887 a piaçava sai da Bahia em fardos para o mundo: vira vassoura, corda de navio e cobertura de rancho.",
	"Onde o rio encontra a baía, quem manda é o mangue-vermelho, de pé na lama salgada.",
	"O dendezeiro veio da costa da África; do dendê sai o azeite do acarajé, do vatapá e da moqueca.",
	"Em 1887 já é raro achar um pau-brasil de pé na mata.",
	"O jenipapo verde tinge a pele de azul-escuro por dias; maduro, vira o licor das festas de São João.",
]
const NOTAS_NOITE := [
	"Disse também, sem tirar a mão do leme, que ali a gente aprende a não andar na mata depois que escurece.",
	"Minha avó diz que o que troca com a gente à noite, cobra de dia. — Pedro",
	"Para o povo de santo, a gameleira é morada de Iroko, e não se corta. Os mais velhos passam longe dela à noite.",
	"Maré cheia, ninguém anda no mangue.",
	"Ninguém dorme debaixo de jaqueira carregada.",
]

## Moldura SVG da home: margens do NinePatch na textura e a escala
## em tela. Os cantos internos ficam com ~47 px; a moldura
## cresce CRESCIMENTO px para fora da caixa que emoldura.
const MOLDURA_MARGENS := [72, 72, 72, 72]
const MOLDURA_ESCALA := 0.65
const CRESCIMENTO := 12.0


## Fonte variável com o peso pedido. O eixo vem pela tag numérica: "wght" em texto é
## ignorado em silêncio.
static func fonte(caminho: String, peso: int, espaco_letras: int = 0) -> FontVariation:
	var variacao := FontVariation.new()
	variacao.base_font = load(caminho) as Font
	variacao.fallbacks = reservas_cjk()
	variacao.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): peso}
	variacao.spacing_glyph = espaco_letras
	return variacao


## A fonte padrão do HUD (a do Label sem tema) com a Cormorant de reserva. O que a
## padrão não desenha — os círculos "●" e "○" das etapas da missão, #186 — sai da
## Cormorant, que é do jogo, em vez de cair na fonte do sistema (pequena, fina e
## fora da linha de base). O texto comum continua na fonte de sempre.
static func fonte_do_hud() -> FontVariation:
	var variacao := FontVariation.new()
	variacao.base_font = ThemeDB.fallback_font
	var reservas: Array[Font] = [load(FONTE_TEXTO) as Font]
	reservas.append_array(reservas_cjk())
	variacao.fallbacks = reservas
	return variacao


## A RESERVA DO CHINÊS (#199). Nem a sans do HUD nem a Cinzel nem a Cormorant desenham
## ideograma: antes, o chinês dependia do que o Godot achasse no sistema, sem nome nem
## ordem. Agora a reserva é declarada: a primeira destas famílias que a máquina tiver, e só
## depois a busca livre (`allow_system_fallback`). Fica por último nas reservas, de modo
## que o latim sai sempre da fonte do jogo. Uma só instância: a leitura, o título e o
## rótulo a dividem, e o cache de glifos também.
const FAMILIAS_CJK := ["Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC",
	"Noto Sans SC", "Source Han Sans SC", "WenQuanYi Micro Hei", "SimHei", "sans-serif"]
static var _cjk: SystemFont


## A reserva só entra com o jogo em chinês. Fonte de reserva entra na altura de linha dos
## rótulos, e o Microsoft YaHei é mais alto que a Cormorant: com ela sempre ligada, o número
## da barra de mão e toda linha de texto latino mudavam de tamanho (portão `plaquetas_de_tecla`).
## Fora do chinês a lista é vazia e o layout é o de sempre.
static func reservas_cjk() -> Array[Font]:
	var reservas: Array[Font] = []
	if TranslationServer.get_locale().begins_with("zh"):
		reservas.append(fonte_cjk())
	return reservas


static func fonte_cjk() -> SystemFont:
	if _cjk == null:
		_cjk = SystemFont.new()
		_cjk.font_names = PackedStringArray(FAMILIAS_CJK)
		_cjk.allow_system_fallback = true
	return _cjk


## OS PAPÉIS DA TIPOGRAFIA DOS MODAIS (#199). Quatro funções, cada uma com a sua
## fonte, em vez de cada tela escolher a fonte que lhe pareceu bonita:
##
##   título    Cinzel versalete  — cabeçalhos, o nome grande da ficha, o "FÉ › ..."
##   rótulo    Cinzel menor, ouro — "ATÉ O PRÓXIMO GRAU", "HOJE", o nome de cada fé
##   leitura   a sans do HUD     — frase, regra, dica, valor, nome na lista, rodapé
##   ênfase    Cormorant itálico — só o destaque curto ("Desconhecido")
##
## A Cormorant fina é bela no título e cansa no texto corrido: em tela menor ou à
## distância ela some. Quem tem de ser LIDO usa a sans do HUD, em creme. O mesmo
## quarteto existe no tema como variações de Label (`TemaMenu`): TituloModal,
## RotuloSecao, TextoLeitura e Enfase. O tamanho passa por add_theme_font_size_override,
## então o "Tamanho do texto" dos Ajustes continua valendo para todos.
const COR_LEITURA := Color("f6ead0")
## O creme apagado do texto secundário: legível sobre a laca (o cinza de antes,
## 0,55/0,58/0,52, ficava abaixo de 4,5:1 nos corpos pequenos).
const COR_LEITURA_APAGADA := Color("cfc7b0")
const TAMANHO_TITULO_MODAL := 22
const TAMANHO_ROTULO := 14
const TAMANHO_LEITURA := 17
const TAMANHO_ENFASE := 18


static func papel_titulo(rotulo: Label, tamanho: int = TAMANHO_TITULO_MODAL, cor: Color = CREME) -> Label:
	rotulo.add_theme_font_override("font", fonte(FONTE_TITULO, 600, 1))
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	sombra_texto(rotulo)
	return rotulo


static func papel_rotulo(rotulo: Label, tamanho: int = TAMANHO_ROTULO, cor: Color = OURO) -> Label:
	rotulo.add_theme_font_override("font", fonte(FONTE_TITULO, 600, 2))
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	return rotulo


static func papel_leitura(rotulo: Label, tamanho: int = TAMANHO_LEITURA, cor: Color = COR_LEITURA) -> Label:
	rotulo.add_theme_font_override("font", fonte_do_hud())
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	return rotulo


static func papel_enfase(rotulo: Label, tamanho: int = TAMANHO_ENFASE, cor: Color = OURO) -> Label:
	rotulo.add_theme_font_override("font", fonte(FONTE_ITALICO, 500))
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	return rotulo


## O rodapé de teclas dos modais: "↑↓ ou W/S: andar · P ou Esc: fechar" vira uma
## fila de plaquetas (uma por tecla) com a ação em leitura ao lado, como os
## atalhos do HUD, e não texto corrido apagado. Devolve o HFlowContainer vazio, que
## quebra a linha em janela estreita; `refazer_rodape_de_teclas` o enche.
static func rodape_de_teclas(texto: String = "", tamanho: int = 14) -> HFlowContainer:
	var fila := HFlowContainer.new()
	fila.name = "Rodape"
	fila.add_theme_constant_override("h_separation", 18)
	fila.add_theme_constant_override("v_separation", 6)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.set_meta("tamanho_das_teclas", tamanho)
	refazer_rodape_de_teclas(fila, texto)
	return fila


## Esvazia e enche a fila a partir do texto de sempre ("tecla: ação · tecla: ação"
## ou "[tecla] ação · [tecla] ação"), para a tradução e as teclas remapeadas
## continuarem vindo de quem monta a frase.
static func refazer_rodape_de_teclas(fila: HFlowContainer, texto: String) -> void:
	for filho in fila.get_children():
		fila.remove_child(filho)
		filho.queue_free()
	var tamanho: int = int(fila.get_meta("tamanho_das_teclas", 14))
	for par in pares_do_rodape(texto):
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 6)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if str(par[0]) != "":
			var plaqueta := PanelContainer.new()
			plaqueta.name = "Plaqueta"
			var estilo := StyleBoxFlat.new()
			estilo.bg_color = Color(0.16, 0.2, 0.15, 0.95)
			estilo.border_color = Color(OURO, 0.7)
			estilo.set_border_width_all(1)
			estilo.set_corner_radius_all(4)
			estilo.content_margin_left = 7
			estilo.content_margin_right = 7
			estilo.content_margin_top = 1
			estilo.content_margin_bottom = 2
			plaqueta.add_theme_stylebox_override("panel", estilo)
			plaqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var tecla := papel_leitura(Label.new(), tamanho, CREME)
			tecla.name = "Tecla"
			tecla.text = str(par[0])
			tecla.mouse_filter = Control.MOUSE_FILTER_IGNORE
			plaqueta.add_child(tecla)
			item.add_child(plaqueta)
		var acao := papel_leitura(Label.new(), tamanho, COR_LEITURA_APAGADA)
		acao.name = "Acao"
		acao.text = str(par[1])
		acao.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(acao)
		fila.add_child(item)


## Parte o rodapé em [teclas, ação]. Os separadores são o "·" entre os pares, o
## "[tecla] ação" do painel e o "teclas: ação" das teias; o que não tem tecla
## (um recado) entra com as teclas vazias.
static func pares_do_rodape(texto: String) -> Array:
	var saida: Array = []
	for pedaco in texto.split("·"):
		var item := pedaco.strip_edges()
		if item.is_empty():
			continue
		if item.begins_with("[") and item.contains("]"):
			var fim := item.find("]")
			saida.append([item.substr(1, fim - 1), item.substr(fim + 1).strip_edges()])
		elif item.contains(": "):
			var corte := item.find(": ")
			saida.append([item.substr(0, corte).strip_edges(), item.substr(corte + 2).strip_edges()])
		else:
			saida.append(["", item])
	return saida


## A mesma talha SVG para painéis que desenham a moldura no próprio stylebox.
static func estilo_moldura(margem_h: float = 40, margem_v: float = 40) -> StyleBoxTexture:
	var estilo := StyleBoxTexture.new()
	estilo.texture = preload(MOLDURA)
	for lado in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		estilo.set_texture_margin(lado, 72)
		estilo.set_content_margin(lado, margem_h if lado in [SIDE_LEFT, SIDE_RIGHT] else margem_v)
	return estilo


## Cormorant com números oldstyle (para versões, horas e porcentagens).
static func fonte_numeros(peso: int = 500) -> FontVariation:
	var numeros := fonte(FONTE_TEXTO, peso)
	numeros.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("onum"): 1}
	return numeros


## Brilho redondo que some para as bordas (luzes, partículas, pontas de barra).
static func brilho(cor: Color, lado: int) -> GradientTexture2D:
	var cores := Gradient.new()
	cores.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	cores.colors = PackedColorArray([cor, Color(cor, cor.a * 0.35), Color(cor, 0.0)])
	var textura := GradientTexture2D.new()
	textura.gradient = cores
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.0, 0.5)
	textura.width = lado
	textura.height = lado
	return textura


static func aditivo() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


## Filete de ouro de 1 px que some na ponta de fora.
static func filete(para_direita: bool) -> TextureRect:
	var cores := Gradient.new()
	var ouro := Color(0.91, 0.77, 0.42, 0.85)
	cores.colors = PackedColorArray([ouro, Color(ouro, 0.0)] if para_direita else [Color(ouro, 0.0), ouro])
	var textura := GradientTexture2D.new()
	textura.gradient = cores
	textura.width = 64
	textura.height = 1
	var linha := TextureRect.new()
	linha.texture = textura
	linha.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	linha.stretch_mode = TextureRect.STRETCH_SCALE
	linha.custom_minimum_size = Vector2(16, 1)
	linha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return linha


## Filete simétrico (some nas duas pontas), para rodapés e sublinhados.
static func filete_centrado(altura: float = 1.0) -> TextureRect:
	var cores := Gradient.new()
	cores.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	cores.colors = PackedColorArray([Color(OURO, 0.0), Color(OURO, 0.55), Color(OURO, 0.0)])
	var textura := GradientTexture2D.new()
	textura.gradient = cores
	textura.width = 64
	textura.height = 1
	var linha := TextureRect.new()
	linha.texture = textura
	linha.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	linha.stretch_mode = TextureRect.STRETCH_SCALE
	linha.custom_minimum_size = Vector2(16, altura)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return linha


## Losango de azulejo (cobalto com filete de ouro), o mesmo do centro do logotipo.
static func losango() -> Control:
	var suporte := Control.new()
	suporte.custom_minimum_size = Vector2(12, 12)
	suporte.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	suporte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var peca := Panel.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COBALTO
	estilo.set_border_width_all(1)
	estilo.border_color = ROTULO
	peca.add_theme_stylebox_override("panel", estilo)
	peca.position = Vector2(2, 2)
	peca.size = Vector2(8, 8)
	peca.pivot_offset = Vector2(4, 4)
	peca.rotation_degrees = 45.0
	peca.mouse_filter = Control.MOUSE_FILTER_IGNORE
	suporte.add_child(peca)
	return suporte


## Linha "filete · losango · filete", usada como divisor de cabeçalhos e do menu.
static func divisor() -> HBoxContainer:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(filete(false))
	linha.add_child(losango())
	linha.add_child(filete(true))
	return linha


static func sombra_texto(rotulo: Label) -> void:
	rotulo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	rotulo.add_theme_constant_override("shadow_offset_x", 0)
	rotulo.add_theme_constant_override("shadow_offset_y", 1)
	rotulo.add_theme_constant_override("shadow_outline_size", 6)


## Rótulo pequeno em Cinzel versalete espaçado (DO ALMANAQUE, HISTÓRICO, capítulos).
static func rotulo(texto: String, tamanho: int = 13, cor: Color = ROTULO) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.uppercase = true
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_theme_font_override("font", fonte(FONTE_TITULO, 600, 4))
	etiqueta.add_theme_font_size_override("font_size", tamanho)
	etiqueta.add_theme_color_override("font_color", cor)
	sombra_texto(etiqueta)
	return etiqueta


## Véu em degradê: TextureRect de tela cheia (quem chama posiciona), sem mouse.
## `pontos` é {fração → alfa}; a cor é uma só, com o alfa variando.
static func veu(cor: Color, pontos: Dictionary, horizontal: bool = false) -> TextureRect:
	var cores := Gradient.new()
	var offsets := PackedFloat32Array()
	var lista := PackedColorArray()
	var chaves := pontos.keys()
	chaves.sort()
	for fracao: float in chaves:
		offsets.append(fracao)
		lista.append(Color(cor, pontos[fracao]))
	cores.offsets = offsets
	cores.colors = lista
	var textura := GradientTexture2D.new()
	textura.gradient = cores
	textura.fill_from = Vector2.ZERO
	textura.fill_to = Vector2(1, 0) if horizontal else Vector2(0, 1)
	textura.width = 256 if horizontal else 4
	textura.height = 4 if horizontal else 256
	var quadro := TextureRect.new()
	quadro.texture = textura
	quadro.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	quadro.stretch_mode = TextureRect.STRETCH_SCALE
	quadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return quadro


## Vinheta radial: transparente no miolo, escura na borda, com o centro deslocável.
static func vinheta(centro: Vector2 = Vector2(0.55, 0.47), alfa: float = 0.42) -> TextureRect:
	var cores := Gradient.new()
	cores.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	cores.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, alfa)])
	var textura := GradientTexture2D.new()
	textura.gradient = cores
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = centro
	textura.fill_to = centro + Vector2(0.6, 0)
	textura.width = 256
	textura.height = 256
	var quadro := TextureRect.new()
	quadro.texture = textura
	quadro.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	quadro.stretch_mode = TextureRect.STRETCH_SCALE
	quadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return quadro


## Emoldura `caixa` com a talha dourada: cria uma sombra e o NinePatch como irmãos
## logo antes dela, seguindo posição, tamanho e visibilidade. Devolve [sombra, moldura].
static func emoldurar(caixa: Control) -> Array[Control]:
	var pai := caixa.get_parent()
	var indice := caixa.get_index()
	var sombra := Panel.new()
	sombra.name = "SombraMoldura"
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0, 0, 0, 0)
	estilo.shadow_color = Color(0, 0, 0, 0.5)
	estilo.shadow_size = 28
	estilo.shadow_offset = Vector2(0, 8)
	estilo.set_corner_radius_all(8)
	sombra.add_theme_stylebox_override("panel", estilo)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(sombra)
	pai.move_child(sombra, indice)
	var moldura := NinePatchRect.new()
	moldura.name = "Moldura"
	moldura.texture = load(MOLDURA) as Texture2D
	moldura.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	moldura.patch_margin_left = MOLDURA_MARGENS[0]
	moldura.patch_margin_top = MOLDURA_MARGENS[1]
	moldura.patch_margin_right = MOLDURA_MARGENS[2]
	moldura.patch_margin_bottom = MOLDURA_MARGENS[3]
	moldura.scale = Vector2.ONE * MOLDURA_ESCALA
	moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(moldura)
	pai.move_child(moldura, indice + 1)
	var seguir := func() -> void:
		var origem := caixa.position + caixa.pivot_offset * (Vector2.ONE - caixa.scale)
		sombra.position = origem
		sombra.size = caixa.size
		sombra.scale = caixa.scale
		moldura.position = origem - Vector2.ONE * CRESCIMENTO * caixa.scale
		moldura.size = (caixa.size + Vector2.ONE * CRESCIMENTO * 2.0) / MOLDURA_ESCALA
		moldura.scale = caixa.scale * MOLDURA_ESCALA
		# A meta "sem_moldura" esconde a talha sem esconder a caixa (travessia).
		var mostrar: bool = caixa.visible and not caixa.get_meta("sem_moldura", false)
		sombra.visible = mostrar
		moldura.visible = mostrar
	caixa.item_rect_changed.connect(seguir)
	caixa.visibility_changed.connect(seguir)
	seguir.call()
	return [sombra, moldura]


## Fio de ouro de 3 px com brilho na ponta (a barra da tela de carregamento e o tempo
## da fala na travessia). Devolve a ProgressBar; a ponta acompanha o valor sozinha.
static func fio(pai: Control) -> ProgressBar:
	var barra := ProgressBar.new()
	barra.name = "Fio"
	barra.show_percentage = false
	barra.max_value = 1.0
	barra.step = 0.0
	barra.anchor_left = 0.0
	barra.anchor_right = 1.0
	barra.anchor_top = 1.0
	barra.anchor_bottom = 1.0
	barra.offset_top = -3.0
	barra.offset_bottom = 0.0
	barra.grow_vertical = Control.GROW_DIRECTION_BEGIN
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(1.0, 0.94, 0.82, 0.1)
	var cheio := StyleBoxFlat.new()
	cheio.bg_color = OURO
	cheio.shadow_color = Color(0.94, 0.81, 0.48, 0.55)
	cheio.shadow_size = 6
	barra.add_theme_stylebox_override("background", fundo)
	barra.add_theme_stylebox_override("fill", cheio)
	pai.add_child(barra)
	var ponta := TextureRect.new()
	ponta.name = "Ponta"
	ponta.texture = brilho(Color(1.0, 0.97, 0.85, 1.0), 64)
	ponta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ponta.material = aditivo()
	ponta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ponta.size = Vector2(30, 30)
	barra.add_child(ponta)
	var avancar := func() -> void:
		ponta.position = Vector2(barra.size.x * float(barra.value), barra.size.y * 0.5) - ponta.size * 0.5
	barra.value_changed.connect(avancar.unbind(1))
	barra.resized.connect(avancar)
	avancar.call()
	return barra
