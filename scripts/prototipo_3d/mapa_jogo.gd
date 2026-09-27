extends Node
## Mapa do vale dentro do jogo (botão de mapa do canto): câmera ortográfica de cima,
## marcadores dos pontos de interesse e "Você" no lugar do jogador. Roda com zoom e
## arraste para mover (qualquer botão do mouse), como o MAPA do menu.
## A câmera do jogador volta a valer ao fechar.

signal fechado

const ALTURA := 3000.0

var aberto := false
var _world: Node3D
var _jogador: Node3D
var _camera := Camera3D.new()
var _camera_anterior: Camera3D
var _alvo := Vector3.ZERO
var _tamanho_total := 0.0
var _marcadores_raiz: Control
var _marcadores: Array[Dictionary] = []
var _voce: Label


func _ready() -> void:
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.far = ALTURA + 1000.0
	add_child(_camera)


## `pai_ui` recebe os marcadores (atrás dos botões do canto).
func abrir(world: Node3D, jogador: Node3D, pai_ui: Control) -> void:
	if aberto:
		return
	aberto = true
	_world = world
	_jogador = jogador
	_camera_anterior = get_viewport().get_camera_3d()
	var frame: Rect2 = world.get_map_frame()
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var por_largura := frame.size.x / maxf(aspect, 0.5)
	_tamanho_total = maxf(30.0, minf(frame.size.y, por_largura) if world.has_map_frame() else maxf(frame.size.y, por_largura))
	# Começa aproximado no jogador, para ver logo onde se está.
	_camera.size = minf(_tamanho_total, 420.0 / world.get_meters_per_unit())
	_alvo = Vector3(jogador.global_position.x, 0, jogador.global_position.z)
	_limitar()
	# Da altura da câmera o nevoeiro apagaria tudo: só esta vista fica sem névoa.
	var ambiente: Environment = get_viewport().world_3d.environment
	if ambiente != null:
		_camera.environment = ambiente.duplicate() as Environment
		_camera.environment.fog_enabled = false
	_camera.make_current()
	_marcadores_raiz = Control.new()
	_marcadores_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marcadores_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai_ui.add_child(_marcadores_raiz)
	pai_ui.move_child(_marcadores_raiz, 0)
	for landmark: Dictionary in world.landmarks:
		_marcador(String(landmark["name"]), landmark["position"])
	for area: Dictionary in world.areas:
		if area["name"] != "Praça":
			_marcador(String(area["name"]), area["position"])
	_voce = Label.new()
	_voce.text = "▼ Você"
	_voce.add_theme_font_size_override("font_size", 15)
	_voce.add_theme_color_override("font_color", Color("f5e3b3"))
	_voce.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.07))
	_voce.add_theme_constant_override("outline_size", 6)
	_marcadores_raiz.add_child(_voce)
	_atualizar()


func fechar() -> void:
	if not aberto:
		return
	aberto = false
	if is_instance_valid(_marcadores_raiz):
		_marcadores_raiz.queue_free()
	_marcadores.clear()
	if is_instance_valid(_camera_anterior):
		_camera_anterior.make_current()
	fechado.emit()


func _process(_delta: float) -> void:
	if aberto:
		_atualizar()


func _unhandled_input(event: InputEvent) -> void:
	if not aberto:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.size = maxf(30.0, _camera.size * 0.78)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.size = minf(_tamanho_total, _camera.size * 1.28)
		_limitar()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and event.button_mask != 0:
		var por_pixel := _camera.size / maxf(1.0, get_viewport().get_visible_rect().size.y)
		_alvo.x -= event.relative.x * por_pixel
		_alvo.z -= event.relative.y * por_pixel
		_limitar()
		get_viewport().set_input_as_handled()


func _marcador(nome: String, posicao: Vector3) -> void:
	var marcador := Button.new()
	marcador.text = "● " + nome
	marcador.tooltip_text = "Centralizar em %s" % nome
	marcador.focus_mode = Control.FOCUS_NONE
	marcador.custom_minimum_size = Vector2(0, 26)
	marcador.add_theme_font_size_override("font_size", 13)
	marcador.pressed.connect(func() -> void:
		_alvo = posicao
		_camera.size = minf(_camera.size, 420.0 / _world.get_meters_per_unit())
		_limitar())
	_marcadores_raiz.add_child(marcador)
	_marcadores.append({"control": marcador, "posicao": posicao})


func _atualizar() -> void:
	_camera.global_position = _alvo + Vector3(0, ALTURA, 0)
	_camera.look_at(_alvo, Vector3(0, 0, -1))
	var tela := get_viewport().get_visible_rect().size
	for entrada: Dictionary in _marcadores:
		var marcador: Button = entrada["control"]
		var ponto := _camera.unproject_position(entrada["posicao"])
		marcador.position = ponto + Vector2(5, -13)
		marcador.visible = Rect2(Vector2.ZERO, tela).has_point(ponto)
	if is_instance_valid(_voce) and is_instance_valid(_jogador):
		var ponto := _camera.unproject_position(_jogador.global_position)
		# Acima do ponto, para não cobrir o marcador de um lugar onde o jogador está.
		_voce.reset_size()
		_voce.position = ponto - Vector2(_voce.size.x * 0.5, _voce.size.y + 18.0)
		_voce.visible = Rect2(Vector2.ZERO, tela).has_point(ponto)


func _limitar() -> void:
	var frame: Rect2 = _world.get_map_frame()
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var meia_largura := _camera.size * aspect * 0.5
	var meia_altura := _camera.size * 0.5
	var min_x := frame.position.x + meia_largura
	var max_x := frame.end.x - meia_largura
	var min_z := frame.position.y + meia_altura
	var max_z := frame.end.y - meia_altura
	_alvo.x = clampf(_alvo.x, min_x, max_x) if min_x <= max_x else frame.get_center().x
	_alvo.z = clampf(_alvo.z, min_z, max_z) if min_z <= max_z else frame.get_center().y
