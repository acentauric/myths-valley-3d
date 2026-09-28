extends RefCounted
## Dica flutuante de interação (tecla em papel claro e o que ela faz, no fundo escuro do
## HUD), presa a um ponto do mundo. Usada pelas lápides e pelas árvores.

const FUNDO := Color(0.055, 0.085, 0.075, 0.92)
const OURO := Color("b49a60")
const PAPEL := Color("f3ead3")
const TINTA := Color("2b2a22")


static func criar(pai: Control, tecla_texto: String, acao: String) -> PanelContainer:
	var dica := PanelContainer.new()
	dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dica.visible = false
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = FUNDO
	estilo.border_color = OURO
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(8)
	estilo.content_margin_left = 6
	estilo.content_margin_right = 10
	estilo.content_margin_top = 5
	estilo.content_margin_bottom = 5
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
	letra.add_theme_font_size_override("font_size", 15)
	letra.add_theme_color_override("font_color", TINTA)
	tecla.add_child(letra)
	var texto := Label.new()
	texto.name = "Acao"
	texto.text = acao
	texto.add_theme_font_size_override("font_size", 14)
	texto.add_theme_color_override("font_color", Color("e8e4d7"))
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
