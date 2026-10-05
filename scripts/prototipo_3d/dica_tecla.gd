extends RefCounted
## Dica flutuante de interação (tecla em papel claro e o que ela faz, no fundo escuro do
## HUD), presa a um ponto do mundo. Usada por tudo o que responde ao E.
##
## Na identidade do jogo (`identidade.gd`), como o balão de fala: a laca com o
## filete de ouro, a letra da tecla em Cinzel no papel creme, e a ação em
## Cormorant Garamond — "melhore o design dos balões de interação de acordo com o
## visual do MythsValley 3D".

const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")

const FUNDO := Color(Identidade.LACA, 0.94)
const OURO := Color(Identidade.OURO, 0.7)
const PAPEL := Identidade.CREME
const TINTA := Color("2b2a22")


static func criar(pai: Control, tecla_texto: String, acao: String) -> PanelContainer:
	var dica := PanelContainer.new()
	dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dica.visible = false
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
	linha.add_child(texto)
	return dica


## Mostra a dica sobre `ponto` (pela câmera do jogo) com o texto de ação dado; some se o
## ponto estiver atrás da câmera.
static func mostrar_em(dica: PanelContainer, camera: Camera3D, ponto: Vector3, acao: String = "") -> void:
	if camera == null or camera.is_position_behind(ponto):
		dica.visible = false
		return
	if acao != "":
		(dica.find_child("Acao", true, false) as Label).text = acao
	dica.visible = true
	dica.reset_size()
	dica.position = camera.unproject_position(ponto) - Vector2(dica.size.x * 0.5, dica.size.y)
