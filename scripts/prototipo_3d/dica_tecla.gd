extends RefCounted
## Dica flutuante de interação (tecla em papel claro e o que ela faz, no fundo escuro do
## HUD), presa a um ponto do mundo. Usada por tudo o que responde ao E.
##
## Na identidade do jogo (`identidade.gd`), como o balão de fala: a laca com o
## filete de ouro e a letra da tecla em Cinzel no papel creme — "melhore o design dos
## balões de interação de acordo com o visual do MythsValley 3D".
##
## OS PAPÉIS DA TIPOGRAFIA (#188, os mesmos da #199): a plaqueta do E ocupa a altura das
## duas linhas, quadrada, com a letra grande (é o que o jogador procura de relance); a
## linha de cima, o ALVO ("Tronco caído"), é o título, em Cinzel ouro; a de baixo, o
## REQUISITO ("Ponha na mão: Machado"), é leitura, na sans legível do HUD, em creme e
## menor. Dica de uma linha só: o título em ouro, com a plaqueta da altura dessa linha.

const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")
const SuavizadorDeTela = preload("res://scripts/prototipo_3d/suavizador_de_tela.gd")
const PopupsDoMundo = preload("res://scripts/prototipo_3d/popups_do_mundo.gd")

const FUNDO := Color(Identidade.LACA, 0.94)
const OURO := Color(Identidade.OURO, 0.7)
const PAPEL := Identidade.CREME
const TINTA := Color("2b2a22")
## O alvo é título (ouro, Cinzel); o requisito, leitura (creme, a sans do HUD, menor).
const COR_DO_ALVO := Identidade.OURO
const COR_DO_REQUISITO := Identidade.TEXTO
const TAMANHO_DO_ALVO := 15
const TAMANHO_DO_REQUISITO := 14
## A letra da plaqueta é esta fração da altura dela (mínimo de `TAMANHO_MINIMO_DA_LETRA`).
const PROPORCAO_DA_LETRA := 0.56
const TAMANHO_MINIMO_DA_LETRA := 14
## O PESO da dica (`suavizador_de_tela.gd`): ela desliza para o ponto em vez de
## colar nele a cada quadro, e o tremor da câmera não a mexe.
const TEMPO_DE_SEGUIR := 0.22
const CORREIA := 110.0
## Entre a dica e a placa de nome que ela sobe por cima, e o peso desse empurrão.
const FOLGA_DAS_PLACAS := 3.0
const TEMPO_DO_EMPURRAO := 0.12
const CORREIA_DO_EMPURRAO := 400.0
## Entre a dica e o painel do HUD de que ela se afasta (#184).
const FOLGA_DO_HUD := 6.0


static func criar(pai: Control, tecla_texto: String, acao: String) -> PanelContainer:
	var dica := PanelContainer.new()
	dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dica.visible = false
	# Como a placa e o balão a acham: para não se cobrirem (`popups_do_mundo.gd`).
	dica.add_to_group(PopupsDoMundo.GRUPO_DICAS)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = FUNDO
	estilo.border_color = OURO
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(7)
	# Margens parelhas: a caixa é justa ao conteúdo, sem sobra de nenhum lado.
	estilo.content_margin_left = 6
	estilo.content_margin_right = 11
	estilo.content_margin_top = 6
	estilo.content_margin_bottom = 6
	estilo.shadow_color = Color(0, 0, 0, 0.3)
	estilo.shadow_size = 4
	dica.add_theme_stylebox_override("panel", estilo)
	pai.add_child(dica)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 9)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dica.add_child(linha)
	var tecla := PanelContainer.new()
	tecla.name = "Tecla"
	# Enche a altura das duas linhas (o HBox a estica); a largura a faz quadrada (abaixo).
	tecla.size_flags_vertical = Control.SIZE_FILL
	tecla.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo_tecla := StyleBoxFlat.new()
	estilo_tecla.bg_color = PAPEL
	estilo_tecla.set_corner_radius_all(5)
	estilo_tecla.content_margin_left = 3
	estilo_tecla.content_margin_right = 3
	estilo_tecla.content_margin_top = 0
	estilo_tecla.content_margin_bottom = 0
	tecla.add_theme_stylebox_override("panel", estilo_tecla)
	linha.add_child(tecla)
	var letra := Label.new()
	letra.name = "Letra"
	letra.text = tecla_texto
	letra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letra.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	letra.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 700))
	letra.add_theme_font_size_override("font_size", TAMANHO_MINIMO_DA_LETRA)
	letra.add_theme_color_override("font_color", TINTA)
	tecla.add_child(letra)
	# Quadrada e com a letra na medida: quando o HBox dá a altura à plaqueta, a largura a iguala.
	tecla.resized.connect(_quadrar_a_tecla.bind(tecla, letra))
	var textos := VBoxContainer.new()
	textos.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	textos.add_theme_constant_override("separation", 1)
	textos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(textos)
	var texto := Label.new()
	texto.name = "Acao"
	texto.text = acao
	texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texto.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600, 1))
	texto.add_theme_font_size_override("font_size", TAMANHO_DO_ALVO)
	texto.add_theme_color_override("font_color", COR_DO_ALVO)
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	textos.add_child(texto)
	var requisito := Label.new()
	requisito.name = "Requisito"
	requisito.visible = false
	requisito.mouse_filter = Control.MOUSE_FILTER_IGNORE
	requisito.add_theme_font_override("font", Identidade.fonte_do_hud())
	requisito.add_theme_font_size_override("font_size", TAMANHO_DO_REQUISITO)
	requisito.add_theme_color_override("font_color", COR_DO_REQUISITO)
	requisito.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	textos.add_child(requisito)
	_preparar_texto(dica, acao)
	return dica


## Mostra a dica sobre `ponto` (pela câmera do jogo) com o texto de ação dado; some se o
## ponto estiver atrás da câmera.
##
## COM PESO: o ponto projetado é o ALVO de uma mola (`suavizador_de_tela.gd`), e a dica
## desliza até ele; o tremor de um ou dois pixels da câmera não a move. Uma dica que
## acaba de acender aparece no lugar, sem deslizar de onde ficou da última vez. Quem
## chama continua chamando todo quadro, com o ponto de verdade.
##
## SEM COBRIR NINGUÉM: a placa de nome de quem vai receber o E fica por baixo — a dica sobe
## para cima dela (`popups_do_mundo.gd`). O empurrão é o que falta para não cobrir, calculado
## depois da mola e com uma mola mais leve só dele: a placa que some (o morador começou a
## falar) não derruba a dica de uma vez, e a que chega não a faz saltar.
static func mostrar_em(dica: PanelContainer, camera: Camera3D, ponto: Vector3, acao: String = "") -> void:
	if camera == null or camera.is_position_behind(ponto):
		dica.visible = false
		return
	if acao != "":
		_preparar_texto(dica, acao)
	var estava_acesa := dica.visible
	dica.visible = true
	dica.reset_size()
	dica.scale = Vector2.ONE * Tela.escala_componente("interacao")
	var tamanho := dica.size * dica.scale
	var ancora := camera.unproject_position(ponto)
	var mola := _mola(dica)
	if not estava_acesa:
		mola.reiniciar(ancora)
	var onde := mola.seguir(ancora, dica.get_process_delta_time(), TEMPO_DE_SEGUIR,
		SuavizadorDeTela.VELOCIDADE_MAXIMA, SuavizadorDeTela.ZONA_MORTA, CORREIA)
	# As placas estão em coordenadas de tela; a dica, nas do pai (o mesmo, na prática).
	var origem := dica.global_position - dica.position if dica.is_inside_tree() else Vector2.ZERO
	var caixa := Rect2((onde - Vector2(tamanho.x * 0.5, tamanho.y)).round() + origem, tamanho)
	var afastada := PopupsDoMundo.afastar_de(caixa, PopupsDoMundo.retangulos(dica, PopupsDoMundo.GRUPO_PLACAS), FOLGA_DAS_PLACAS)
	# DEPOIS DAS PLACAS, O HUD (#184): a dica do E, dona da vaga, também respeita as barras, o relógio
	# e os painéis essenciais. Desce para baixo deles, encosta ao lado ou, sem lugar, se apaga.
	var tela := dica.get_viewport_rect().size
	var paineis := PopupsDoMundo.retangulos(dica, PopupsDoMundo.GRUPO_HUD, dica, PopupsDoMundo.PRIORIDADE_INTERACAO + 1)
	var livre := PopupsDoMundo.livre_do_hud(afastada, paineis, FOLGA_DO_HUD, tela)
	if livre.size == Vector2.ZERO:
		dica.visible = false
		return
	# O empurrão também tem peso: a placa que some (o morador começou a falar) não faz a dica
	# despencar de uma vez, e a que chega não a faz saltar.
	var empurrao := _mola_do_empurrao(dica)
	var alvo_do_empurrao := livre.position - caixa.position
	if not estava_acesa:
		empurrao.reiniciar(alvo_do_empurrao)
	var sobe := empurrao.seguir(alvo_do_empurrao, dica.get_process_delta_time(), TEMPO_DO_EMPURRAO,
		SuavizadorDeTela.VELOCIDADE_MAXIMA, 0.0, CORREIA_DO_EMPURRAO)
	dica.position = (caixa.position + sobe - origem).round()


## O alvo e o requisito, independentemente do idioma. Não quebra nomes procurando
## palavras traduzidas; as fontes já separam as partes com ·. Sem requisito, o segundo é "".
static func _partes(acao: String) -> PackedStringArray:
	var partes := acao.split(" · ", true, 1)
	if partes.size() < 2:
		return PackedStringArray([acao, ""])
	var requisito := partes[1].strip_edges()
	if requisito != "":
		requisito = requisito.substr(0, 1).to_upper() + requisito.substr(1)
	return PackedStringArray([partes[0].strip_edges(), requisito])


static func _preparar_texto(dica: PanelContainer, acao: String) -> void:
	var alvo := dica.find_child("Acao", true, false) as Label
	var requisito := dica.find_child("Requisito", true, false) as Label
	var partes := _partes(acao)
	alvo.text = partes[0]
	requisito.text = partes[1]
	requisito.visible = partes[1] != ""
	# A caixa acompanha a linha mais longa, cada uma medida na sua própria fonte.
	var largura := 24.0
	for etiqueta: Label in [alvo, requisito]:
		if not etiqueta.visible:
			continue
		var fonte := etiqueta.get_theme_font("font")
		var tamanho := etiqueta.get_theme_font_size("font_size")
		largura = maxf(largura, fonte.get_string_size(etiqueta.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x + 2.0)
	# A dica simples mantém largura natural; requisitos longos ganham mais linhas
	# em janelas menores, em vez de cortar o E ou ocupar a largura toda da tela.
	var limite := minf(280.0, maxf(120.0, dica.get_viewport_rect().size.x * 0.4))
	alvo.custom_minimum_size.x = minf(largura, limite)
	requisito.custom_minimum_size.x = minf(largura, limite)


## A plaqueta do E é quadrada, da altura das linhas, e a letra cresce com ela.
static func _quadrar_a_tecla(tecla: PanelContainer, letra: Label) -> void:
	var lado := roundf(tecla.size.y)
	if lado >= 1.0 and not is_equal_approx(tecla.custom_minimum_size.x, lado):
		tecla.custom_minimum_size.x = lado
	var tamanho := maxi(TAMANHO_MINIMO_DA_LETRA, int(lado * PROPORCAO_DA_LETRA))
	if letra.get_theme_font_size("font_size") != tamanho:
		letra.add_theme_font_size_override("font_size", tamanho)


## A mola desta dica, guardada nela mesma (as nove fontes do E continuam como eram).
static func _mola(dica: PanelContainer) -> SuavizadorDeTela:
	return _guardada(dica, "mola")


## A mola do empurrão por cima das placas.
static func _mola_do_empurrao(dica: PanelContainer) -> SuavizadorDeTela:
	return _guardada(dica, "mola_do_empurrao")


static func _guardada(dica: PanelContainer, chave: String) -> SuavizadorDeTela:
	if dica.has_meta(chave):
		var guardada = dica.get_meta(chave)
		if guardada is SuavizadorDeTela:
			return guardada
	var nova := SuavizadorDeTela.new()
	dica.set_meta(chave, nova)
	return nova
