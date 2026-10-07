extends RefCounted
## Dica flutuante de interação (tecla em papel claro e o que ela faz, no fundo escuro do
## HUD), presa a um ponto do mundo. Usada por tudo o que responde ao E.
##
## Na identidade do jogo (`identidade.gd`), como o balão de fala: a laca com o
## filete de ouro, a letra da tecla em Cinzel no papel creme, e a ação em
## Cormorant Garamond — "melhore o design dos balões de interação de acordo com o
## visual do MythsValley 3D".

const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")
const SuavizadorDeTela = preload("res://scripts/prototipo_3d/suavizador_de_tela.gd")
const PopupsDoMundo = preload("res://scripts/prototipo_3d/popups_do_mundo.gd")

const FUNDO := Color(Identidade.LACA, 0.94)
const OURO := Color(Identidade.OURO, 0.7)
const PAPEL := Identidade.CREME
const TINTA := Color("2b2a22")
## O PESO da dica (`suavizador_de_tela.gd`): ela desliza para o ponto em vez de
## colar nele a cada quadro, e o tremor da câmera não a mexe.
const TEMPO_DE_SEGUIR := 0.22
const CORREIA := 110.0
## Entre a dica e a placa de nome que ela sobe por cima, e o peso desse empurrão.
const FOLGA_DAS_PLACAS := 3.0
const TEMPO_DO_EMPURRAO := 0.12
const CORREIA_DO_EMPURRAO := 400.0


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
	estilo.content_margin_left = 6
	estilo.content_margin_right = 12
	estilo.content_margin_top = 5
	estilo.content_margin_bottom = 5
	estilo.shadow_color = Color(0, 0, 0, 0.3)
	estilo.shadow_size = 4
	dica.add_theme_stylebox_override("panel", estilo)
	pai.add_child(dica)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 8)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dica.add_child(linha)
	var tecla := PanelContainer.new()
	tecla.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var estilo_tecla := StyleBoxFlat.new()
	estilo_tecla.bg_color = PAPEL
	estilo_tecla.set_corner_radius_all(4)
	estilo_tecla.content_margin_left = 7
	estilo_tecla.content_margin_right = 7
	estilo_tecla.content_margin_top = 1
	estilo_tecla.content_margin_bottom = 1
	tecla.add_theme_stylebox_override("panel", estilo_tecla)
	linha.add_child(tecla)
	var letra := Label.new()
	letra.text = tecla_texto
	letra.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 700))
	letra.add_theme_font_size_override("font_size", 14)
	letra.add_theme_color_override("font_color", TINTA)
	tecla.add_child(letra)
	var texto := Label.new()
	texto.name = "Acao"
	texto.text = acao
	texto.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 600))
	texto.add_theme_font_size_override("font_size", 17)
	texto.add_theme_color_override("font_color", Identidade.TEXTO)
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	linha.add_child(texto)
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
	# O empurrão também tem peso: a placa que some (o morador começou a falar) não faz a dica
	# despencar de uma vez, e a que chega não a faz saltar.
	var empurrao := _mola_do_empurrao(dica)
	var alvo_do_empurrao := Vector2(0.0, afastada.position.y - caixa.position.y)
	if not estava_acesa:
		empurrao.reiniciar(alvo_do_empurrao)
	var sobe := empurrao.seguir(alvo_do_empurrao, dica.get_process_delta_time(), TEMPO_DO_EMPURRAO,
		SuavizadorDeTela.VELOCIDADE_MAXIMA, 0.0, CORREIA_DO_EMPURRAO)
	dica.position = (Vector2(caixa.position.x, caixa.position.y + sobe.y) - origem).round()


## Alvo primeiro, requisito depois, independentemente do idioma. Não quebra
## nomes procurando palavras traduzidas; as fontes já separam as partes com ·.
static func _texto_em_linhas(acao: String) -> String:
	var partes := acao.split(" · ", true, 1)
	if partes.size() < 2:
		return acao
	var requisito := partes[1].strip_edges()
	if requisito != "":
		requisito = requisito.substr(0, 1).to_upper() + requisito.substr(1)
	return partes[0].strip_edges() + "\n" + requisito


static func _preparar_texto(dica: PanelContainer, acao: String) -> void:
	var texto := dica.find_child("Acao", true, false) as Label
	texto.text = _texto_em_linhas(acao)
	var largura := 24.0
	var fonte := texto.get_theme_font("font")
	var tamanho := texto.get_theme_font_size("font_size")
	for linha in texto.text.split("\n"):
		largura = maxf(largura, fonte.get_string_size(linha, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x + 2.0)
	# A dica simples mantém largura natural; requisitos longos ganham mais linhas
	# em janelas menores, em vez de cortar o E ou ocupar a largura toda da tela.
	var limite := minf(280.0, maxf(120.0, dica.get_viewport_rect().size.x * 0.4))
	texto.custom_minimum_size.x = minf(largura, limite)


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
