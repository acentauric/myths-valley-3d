extends Control
## Divisas cadastrais projetadas pela câmera real do mapa, sem corpos no vale.
var world: Node3D
var camera: Camera3D
var _nomes: Dictionary = {}

func configurar(mundo: Node3D, olho: Camera3D) -> void:
	world = mundo
	camera = olho
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for id in Jogo.dados(Terras.ARQUIVO).get("lotes", {}):
		var rotulo := Label.new()
		rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rotulo.add_theme_constant_override("outline_size", 4)
		rotulo.add_theme_color_override("font_outline_color", Color("19211e"))
		add_child(rotulo)
		_nomes[id] = rotulo

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(camera) or not is_instance_valid(world):
		return
	for id in _nomes:
		var pontos := PackedVector2Array()
		var centro := Vector2.ZERO
		for ponto in Terras.poligono(id, world):
			var pixel := camera.unproject_position(ponto)
			pontos.append(pixel)
			centro += pixel
		var rotulo: Label = _nomes[id]
		rotulo.visible = pontos.size() == 4
		if pontos.size() != 4:
			continue
		centro /= 4.0
		var cor := Color("70d58c") if Terras.meu(id) else Color("d8ae5e")
		draw_colored_polygon(pontos, Color(cor, 0.10))
		pontos.append(pontos[0])
		draw_polyline(pontos, cor, 2.0, true)
		rotulo.text = Terras.nome(id) + " · " + (Terras.texto("sua") if Terras.meu(id) else _dono(id))
		rotulo.add_theme_color_override("font_color", cor)
		rotulo.reset_size()
		rotulo.position = centro - rotulo.size * 0.5
		rotulo.visible = get_viewport_rect().has_point(centro)

func _dono(id: String) -> String:
	var dono := str(Terras.dados(id).get("dono", ""))
	return Jogo.nome_do_morador(dono)
