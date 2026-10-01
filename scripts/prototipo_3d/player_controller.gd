extends CharacterBody3D
## A colisão e a câmera pertencem ao controlador; o corpo é escolhido pelo estilo visual
## (autoload Estilo): humanoide procedural ou a cena GLB configurada (modo Tripo).

signal capture_changed(captured: bool)
signal camera_lock_changed(locked: bool)
signal animation_requested(label: String)
signal navigation_status(message: String)
signal vigor_mudou(valor: float)

const ClickNavigation = preload("res://scripts/prototipo_3d/click_navigation.gd")
const TeclasMovimento = preload("res://scripts/prototipo_3d/teclas_movimento.gd")
const Mar = preload("res://scripts/prototipo_3d/mar.gd")
const EspumaAgua = preload("res://scripts/prototipo_3d/espuma_agua.gd")
const HOUSE_INTERACTION_LAYER := 1 << 12
const ARRIVAL_DISTANCE := 0.7
const CAMERA_DRAG_THRESHOLD := 6.0
const JUMP_SPEED_MULTIPLIER := 1.5
const JUMP_VELOCITY := 6.7 * JUMP_SPEED_MULTIPLIER
const JUMP_GRAVITY_UP := 15.0 * JUMP_SPEED_MULTIPLIER * JUMP_SPEED_MULTIPLIER
const JUMP_GRAVITY_DOWN := 25.0 * JUMP_SPEED_MULTIPLIER * JUMP_SPEED_MULTIPLIER
const JUMP_BUFFER_TIME := 0.16
const JUMP_COYOTE_TIME := 0.16
const RUN_STOP_SPEED := 0.15
const VIGOR_MAXIMO := 100.0
const VIGOR_MINIMO_PARA_CORRER := 0.5
const CUSTO_CORRIDA_POR_SEGUNDO := 5.0
const VIGOR_RECUPERACAO_ANDANDO := 2.5
const VIGOR_RECUPERACAO_PARADO := 20.0
## Água: o jogador entra andando no raso, mais devagar conforme ela sobe; onde o fundo
## passa do peito (fração da altura) ele nada, com os ombros e a cabeça de fora. Entra
## no nado e volta a andar em profundidades diferentes, para não ficar alternando.
const NADA_A_PARTIR := 0.72
const ANDA_ATE := 0.66
const VELOCIDADE_NA_AGUA := 0.45
const VELOCIDADE_NADO := 1.5
## Quanto do corpo fica abaixo da superfície nadando (fração da altura): entre ANDA_ATE
## e NADA_A_PARTIR, então os pés só roçam o fundo perto da hora de voltar a andar.
const SUBMERSO_NADANDO := 0.68
## Degrau que o jogador sobe sem pular (borda da areia, meio-fio, píer).
const DEGRAU := 0.4
## Altura do pivô da câmera (acima dos pés); nadando ele sobe para a cabeça, acima da
## superfície que barra a câmera.
const PIVO_CAMERA := 1.18
const PIVO_CAMERA_NADANDO := 1.66
## O clipe "swim" deita o corpo na altura da raiz (os pés): nadando, o modelo sobe esta
## fração da altura para as costas ficarem na linha d'água.
const MODELO_ACIMA_NADANDO := 0.44

@export var model_scene: PackedScene
@export var character_height: float = 1.78
## Velocidades casadas com a passada dos clipes (authored_animator mede): mais rápido que
## isso o pé desliza no chão.
@export var walk_speed: float = 2.1
@export var run_speed: float = 5.2
@export var mouse_sensitivity: float = 0.0025
@export var model_yaw_offset: float = 0.0
@export var double_sided_materials: bool = true

var visual: Node3D
var model: Node3D
var camera_pivot: Node3D
var spring: SpringArm3D
var camera: Camera3D
var animator: Node
var model_bounds := AABB()
var _has_bounds := false
var spawn_position := Vector3(0, 0.05, 6)
var inspecting := false
var _yaw: float = 0.0
var _pitch: float = -0.19
## A câmera abre já recuada (o antigo máximo) e pode afastar um pouco além.
var _distance: float = 8.0
var _click_world: Node3D
var _navigator = ClickNavigation.new()
var _walk_path := PackedVector3Array()
var _walk_index := 0
var _walk_destination := Vector3.INF
var _stuck_time := 0.0
var _replan_attempts := 0
var _hovered_house: Object
var _pending_walk_click := Vector2.INF
var _pending_walk_run := false
var _walk_run := false
var _pending_interact_click := Vector2.INF
var _pending_house_click := Vector2.INF
var _camera_locked := false
## Soltamos o cursor porque a janela perdeu o foco? Se sim, ele volta a ser
## capturado quando o foco voltar — sem trocar o MODO escolhido pelo jogador.
var _solto_pelo_foco := false
var _camera_drag_pressed := false
var _camera_drag_moved := false
var _camera_drag_double_click := false
var _camera_drag_start := Vector2.ZERO
var _jump_buffer_remaining := 0.0
var _grounded_grace_remaining := 0.0
var _jumping := false
## Último ponto em terra firme onde o jogador pisou: quem cai no mar (fora da passarela
## ou do píer) volta para cá, e não para o ponto de chegada.
var _last_land := Vector3.INF
var _knockback_remaining := 0.0
var _nadando := false
var _land_check := 0.0
var _run_toggled := false
var _ran_since_toggle := false
var _vigor := VIGOR_MAXIMO
var _machado_ancora: Node3D
var _machado_pivo: Node3D
var _machado_ancora_posicao_base := Vector3.ZERO
var _machado_angulo_lateral := 0.0
var _acao_golpe_restante := 0.0
var _acao_golpe_espera_animacao := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group("map_player")
	spawn_position = position
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(46)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = character_height
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = character_height * 0.5
	add_child(collision)
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	# No estilo Tripo o viajante gerado no Studio substitui o GLB medieval só quando já
	# tiver rig e clipes (AnimationPlayer); um modelo estático deslizaria sem andar.
	var scene: PackedScene = model_scene
	if Estilo.tripo() and CatalogoAssets.tem_tripo("viajante"):
		var candidato := CatalogoAssets.cena("viajante")
		if candidato != null and _tem_animacoes(candidato):
			scene = candidato
	if Estilo.procedural():
		var procedural := PersonagemProcedural.novo("viajante", character_height)
		visual.add_child(procedural)
		model = procedural
		animator = procedural
	elif scene:
		model = scene.instantiate() as Node3D
		visual.add_child(model)
		_measure_model(model)
		if _has_bounds and model_bounds.size.y > 0.001:
			var factor: float = character_height / model_bounds.size.y
			model.scale *= factor
			model.position = -Vector3(model_bounds.get_center().x, model_bounds.position.y, model_bounds.get_center().z) * factor
		model.rotation.y = model_yaw_offset
		animator = load("res://scripts/prototipo_3d/authored_animator.gd").new()
		add_child(animator)
		if not animator.configure(model):
			animator.queue_free()
			animator = load("res://scripts/prototipo_3d/provisional_animator.gd").new()
			add_child(animator)
			animator.configure(model)
	else:
		push_error("A cena do personagem não foi configurada.")
	camera_pivot = Node3D.new()
	camera_pivot.position.y = PIVO_CAMERA
	add_child(camera_pivot)
	spring = SpringArm3D.new()
	spring.spring_length = _distance
	spring.margin = 0.18
	var camera_shape := SphereShape3D.new()
	camera_shape.radius = 0.18
	spring.shape = camera_shape
	# A câmera não mergulha: o braço também bate na superfície da água (camada própria).
	spring.collision_mask |= Mar.CAMADA_CAMERA_AGUA
	spring.add_excluded_object(get_rid())
	camera_pivot.add_child(spring)
	camera = Camera3D.new()
	camera.fov = 58.0
	camera.near = 0.08
	camera.far = 2800.0
	spring.add_child(camera)
	camera.current = true
	_apply_camera()

func _process(delta: float) -> void:
	_atualizar_machado_na_mao()
	_atualizar_pose_machado(delta)


func machado_na_mao() -> bool:
	return Equipamento.no_encaixe("maos") == "machado"


func travar_acao_de_golpe(duracao: float, aguardar_animacao: bool) -> void:
	_cancel_walk()
	velocity.x = 0.0
	velocity.z = 0.0
	_acao_golpe_espera_animacao = aguardar_animacao
	_acao_golpe_restante = maxf(duracao, 0.0) if aguardar_animacao else minf(maxf(duracao, 0.0), 0.55)
	_jump_buffer_remaining = 0.0


func liberar_acao_de_golpe() -> void:
	_acao_golpe_restante = 0.0
	_acao_golpe_espera_animacao = false


func _atualizar_machado_na_mao() -> void:
	var deve_mostrar := machado_na_mao()
	if deve_mostrar == (_machado_ancora != null):
		return
	if not deve_mostrar:
		_machado_ancora.queue_free()
		_machado_ancora = null
		_machado_pivo = null
		_machado_angulo_lateral = 0.0
		return
	_machado_ancora = _criar_ancora_da_mao()
	if _machado_ancora == null:
		return
	_machado_ancora_posicao_base = _machado_ancora.position
	if Estilo.procedural():
		_criar_machado_procedural(_machado_ancora)
	else:
		var machado := CatalogoAssets.instanciar("machado", _machado_ancora, Vector3.ZERO, 0.46)
		if machado != null:
			machado.rotation = Vector3(deg_to_rad(1.0), deg_to_rad(2.0), deg_to_rad(92.0))
			machado.basis = machado.basis * Basis(Vector3.UP, PI)
			# A pegada fica logo acima da ponta real do cabo no GLB.
			var pegada_cabo := Vector3(0.34, 0.12, 0.0)
			machado.position -= machado.transform * pegada_cabo
			machado.position += Vector3(0.0, 0.06, 0.0)
			machado.position += _machado_ancora.global_basis.inverse() * (visual.global_basis.x * 0.08)
			# Gira em torno da pegada para a ponta do cabo permanecer na mão direita.
			_machado_pivo = Node3D.new()
			_machado_pivo.name = "PivoDaPegada"
			_machado_ancora.add_child(_machado_pivo)
			_machado_pivo.position = machado.transform * pegada_cabo
			machado.reparent(_machado_pivo, true)


func _atualizar_pose_machado(delta: float) -> void:
	if _machado_ancora == null:
		return
	var parado := Vector2(velocity.x, velocity.z).length_squared() < 0.04
	var em_golpe := _acao_golpe_restante > 0.0
	if animator != null and animator.has_method("gesture_ativa") and animator.gesture_ativa():
		em_golpe = true
	var em_idle := parado and not _jumping and not _nadando and not em_golpe
	var afastamento := -0.01 if em_idle else 0.0
	_machado_ancora.position = _machado_ancora_posicao_base + _machado_ancora.global_basis.inverse() * (visual.global_basis.x * afastamento)
	if _machado_pivo != null:
		var angulo_alvo := 0.0 if em_golpe or _nadando else deg_to_rad(-30.0)
		_machado_angulo_lateral = move_toward(_machado_angulo_lateral, angulo_alvo, 4.0 * delta)
		var eixo_vertical_local := (_machado_ancora.global_basis.inverse() * visual.global_basis.y).normalized()
		_machado_pivo.basis = Basis(eixo_vertical_local, _machado_angulo_lateral)


func _criar_ancora_da_mao() -> Node3D:
	if model is PersonagemProcedural:
		var cotovelo := model.find_child("CotoveloD", true, false) as Node3D
		if cotovelo == null:
			return null
		var ancora := Node3D.new()
		ancora.name = "MachadoNaMao"
		ancora.position = Vector3(0.0, -character_height * 0.16, 0.0)
		cotovelo.add_child(ancora)
		return ancora
	for encontrado in model.find_children("*", "Skeleton3D", true, false):
		var esqueleto := encontrado as Skeleton3D
		for indice in esqueleto.get_bone_count():
			var nome := String(esqueleto.get_bone_name(indice)).to_lower()
			if not nome.ends_with("righthand"):
				continue
			var anexo := BoneAttachment3D.new()
			anexo.name = "MachadoNaMao"
			anexo.bone_name = esqueleto.get_bone_name(indice)
			esqueleto.add_child(anexo)
			var ancora := Node3D.new()
			anexo.add_child(ancora)
			return ancora
	var ancora := Node3D.new()
	ancora.name = "MachadoNaMao"
	ancora.position = Vector3(0.34, 0.9, 0.08)
	visual.add_child(ancora)
	return ancora


func _criar_machado_procedural(pai: Node3D) -> void:
	var cabo := MeshInstance3D.new()
	var malha_cabo := CylinderMesh.new()
	malha_cabo.top_radius = 0.018
	malha_cabo.bottom_radius = 0.024
	malha_cabo.height = 0.52
	cabo.mesh = malha_cabo
	cabo.position.y = -0.19
	var madeira := StandardMaterial3D.new()
	madeira.albedo_color = Color("70492d")
	cabo.material_override = madeira
	pai.add_child(cabo)
	var lamina := MeshInstance3D.new()
	var malha_lamina := BoxMesh.new()
	malha_lamina.size = Vector3(0.23, 0.15, 0.055)
	lamina.mesh = malha_lamina
	lamina.position = Vector3(0.07, -0.4, 0.0)
	var ferro := StandardMaterial3D.new()
	ferro.albedo_color = Color("777a78")
	ferro.metallic = 0.55
	lamina.material_override = ferro
	pai.add_child(lamina)


func _tem_animacoes(scene: PackedScene) -> bool:
	var probe := scene.instantiate()
	var animado := not probe.find_children("*", "AnimationPlayer", true, false).is_empty()
	probe.free()
	return animado


func _measure_model(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var bounds: AABB = (model.global_transform.affine_inverse() * mesh_node.global_transform) * mesh_node.get_aabb()
		model_bounds = model_bounds.merge(bounds) if _has_bounds else bounds
		_has_bounds = true
		# O FBX fornecido possui faces de roupa com orientação invertida.
		# Corrigir a visibilidade só nesta instância, preservando o arquivo original.
		if double_sided_materials:
			for index in mesh_node.mesh.get_surface_count():
				var original := mesh_node.get_active_material(index) as BaseMaterial3D
				if original:
					var material := original.duplicate() as BaseMaterial3D
					material.cull_mode = BaseMaterial3D.CULL_DISABLED
					mesh_node.set_surface_override_material(index, material)
	for child in node.get_children():
		_measure_model(child)


func configure_click_world(world: Node3D) -> void:
	_click_world = world
	_navigator.configure(world)
	var espuma := EspumaAgua.new()
	espuma.name = "Espuma"
	espuma.mundo = world
	add_child(espuma)


func _update_house_hover() -> void:
	if _click_world == null:
		return
	if _camera_drag_pressed and _camera_drag_moved:
		if _hovered_house != null:
			_hovered_house = null
			_click_world.set_hovered_house(null)
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		var hit := _pointed_house(get_viewport().get_mouse_position())
		var collider: Object = hit.get("collider")
		if collider != _hovered_house:
			_hovered_house = collider
			_click_world.set_hovered_house(collider)
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if collider != null else Input.CURSOR_ARROW)
	elif _hovered_house != null:
		_hovered_house = null
		_click_world.set_hovered_house(null)
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _physics_process(delta: float) -> void:
	_update_house_hover()
	if _acao_golpe_restante > 0.0:
		_acao_golpe_restante = maxf(0.0, _acao_golpe_restante - delta)
		if _acao_golpe_espera_animacao and animator != null and animator.has_method("gesture_ativa") and not animator.gesture_ativa():
			_acao_golpe_restante = 0.0
	if Input.is_action_just_pressed("mv_animation_9") and _acao_golpe_restante <= 0.0:
		_jump_buffer_remaining = JUMP_BUFFER_TIME
	if is_on_floor():
		_grounded_grace_remaining = JUMP_COYOTE_TIME
	else:
		_grounded_grace_remaining = maxf(0.0, _grounded_grace_remaining - delta)
	if _pending_house_click.is_finite():
		var pointed_house := _pointed_house(_pending_house_click)
		_pending_house_click = Vector2.INF
		if _click_world != null:
			if pointed_house.is_empty():
				_click_world.clear_house_interaction()
			else:
				_click_world.interact_with_house(pointed_house["collider"])
	if _pending_interact_click.is_finite():
		var house_hit := _pointed_house(_pending_interact_click)
		_pending_interact_click = Vector2.INF
		if not house_hit.is_empty() and _click_world != null:
			_click_world.interact_with_house(house_hit["collider"])
	if _pending_walk_click.is_finite():
		_request_walk_at_cursor(_pending_walk_click, _pending_walk_run)
		_pending_walk_click = Vector2.INF
		_pending_walk_run = false
	var input_vector := Input.get_vector("mv_left", "mv_right", "mv_forward", "mv_back")
	if _acao_golpe_restante > 0.0:
		input_vector = Vector2.ZERO
		_cancel_walk()
	if input_vector.length_squared() > 0.001:
		_cancel_walk()
	var direction: Vector3 = Basis(Vector3.UP, _yaw) * Vector3(input_vector.x, 0, input_vector.y)
	if input_vector.length_squared() <= 0.001 and not _walk_path.is_empty():
		direction = _next_walk_direction()
	var corrida_ativa := is_running() and direction.length_squared() > 0.01 and _acao_golpe_restante <= 0.0
	if _run_toggled and direction.length_squared() > 0.01:
		_ran_since_toggle = true
	var speed: float = run_speed if is_running() else walk_speed
	_atualizar_nado()
	var profundidade := _profundidade()
	if _nadando:
		speed = VELOCIDADE_NADO * (2.0 if is_running() else 1.0)
	elif profundidade > 0.0:
		speed *= lerpf(1.0, VELOCIDADE_NA_AGUA, clampf(profundidade / (character_height * NADA_A_PARTIR), 0.0, 1.0))
	# O CANSAÇO PESA NO CORPO, exatamente como no jogo 2D: abaixo de um quinto
	# do fôlego o passo cai para 62% e a corrida deixa de responder. A regra é
	# do `Energia`, que os dois projetos compartilham — aqui só se lê o número,
	# e é por isso que ela não precisou ser reescrita.
	#
	# NADA GASTA FÔLEGO NO VALE AINDA, porque não há trabalho aqui: no 2D quem
	# cobra é a enxada, o machado e a picareta. Então isto é regra ligada e
	# dormente, e é o estado certo — inventar um custo de corrida seria
	# escrever mecânica nova em nome de migrar uma antiga.
	speed *= Energia.passo()
	if _knockback_remaining > 0.0:
		# Empurrão (ex.: o coveiro): o impulso manda até o fim, sem controle do jogador.
		_knockback_remaining -= delta
		direction = Vector3.ZERO
	else:
		velocity.x = move_toward(velocity.x, direction.x * speed, 18.0 * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, 18.0 * delta)
	if _jump_buffer_remaining > 0.0 and _grounded_grace_remaining > 0.0 and not _jumping and not _nadando and _acao_golpe_restante <= 0.0:
		velocity.y = JUMP_VELOCITY
		_jumping = true
		_jump_buffer_remaining = 0.0
		_grounded_grace_remaining = 0.0
		if animator and animator.has_method("play_gesture"):
			var label: String = animator.play_gesture(8)
			if not label.is_empty():
				animation_requested.emit(label)
	_jump_buffer_remaining = maxf(0.0, _jump_buffer_remaining - delta)
	if _nadando:
		# Boia: puxa o corpo para a altura de nado, sem gravidade.
		var altura_nado: float = _click_world.water_level() - character_height * SUBMERSO_NADANDO
		velocity.y = clampf((altura_nado - global_position.y) * 5.0, -3.0, 3.0)
		# Roçando o fundo, não empurra contra ele (o fundo virava parede e prendia).
		if is_on_floor():
			velocity.y = maxf(velocity.y, 0.0)
	elif _jumping:
		velocity.y -= (JUMP_GRAVITY_UP if velocity.y > 0.0 else JUMP_GRAVITY_DOWN) * delta
	elif not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = -0.1
	var distance_before := _distance_to_next_waypoint()
	move_and_slide()
	_subir_degrau(direction)
	_atualizar_vigor(delta, corrida_ativa)
	if _run_toggled and _ran_since_toggle and direction.length_squared() <= 0.01 and Vector2(velocity.x, velocity.z).length_squared() <= RUN_STOP_SPEED * RUN_STOP_SPEED:
		_run_toggled = false
		_ran_since_toggle = false
		navigation_status.emit("Modo corrida desativado ao parar")
	if _jumping and is_on_floor():
		_jumping = false
		if animator and animator.has_method("finish_jump"):
			animator.finish_jump(Vector2(velocity.x, velocity.z).length())
	if not _walk_path.is_empty() and direction.length_squared() > 0.01:
		var progress := distance_before - _distance_to_next_waypoint()
		_stuck_time = 0.0 if progress > 0.003 else _stuck_time + delta
		if _stuck_time > 1.4:
			_retry_walk()
	if direction.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-12.0 * delta))
	if animator:
		animator.update_motion(Vector2(velocity.x, velocity.z).length(), delta)
	_land_check -= delta
	if _land_check <= 0.0 and is_on_floor() and _click_world != null:
		_land_check = 0.25
		if _click_world.is_on_land(global_position):
			_last_land = global_position
	# Mar e rio não têm chão: 2,5 m abaixo da última terra firme já é queda na água.
	if not _nadando and (global_position.y < -6.0 or (_last_land.is_finite() and global_position.y < _last_land.y - 2.5 and not is_on_floor())):
		_back_to_land()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_action_pressed("mv_run") and not event.echo:
		_run_toggled = not _run_toggled and _vigor >= VIGOR_MINIMO_PARA_CORRER
		_ran_since_toggle = false
		navigation_status.emit("Modo corrida %s" % ("ativado" if _run_toggled else "desativado"))
	if event is InputEventMouseMotion and _camera_locked and _camera_drag_pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		if not _camera_drag_moved and event.position.distance_to(_camera_drag_start) >= CAMERA_DRAG_THRESHOLD:
			_camera_drag_moved = true
		if _camera_drag_moved:
			_rotate_camera(-event.relative)
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _camera_drag_pressed:
		if not _camera_drag_moved:
			if _camera_drag_double_click:
				_pending_interact_click = event.position
			else:
				_pending_house_click = event.position
		_camera_drag_pressed = false
		_camera_drag_moved = false
		_camera_drag_double_click = false
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		# O ESC NÃO SOLTA MAIS O MOUSE: ele abre o menu, como em todo jogo do
		# gênero. Quem quer soltar o cursor usa a tecla da câmera (Tab, ou a
		# letra escolhida em AJUSTAR → Atalhos), que é o que ela sempre fez.
		#
		# A troca conserta a queixa de "tenho que clicar e arrastar": quem
		# apertava Esc procurando o menu caía no modo de arrastar sem saber por
		# quê, e não tinha como adivinhar que voltava no Tab.
		if event.is_action_pressed("mv_cursor"):
			set_camera_locked(not _camera_locked)
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(event.relative)
	if event is InputEventMouseButton and event.pressed:
		if _camera_locked and event.button_index == MOUSE_BUTTON_LEFT:
			_camera_drag_pressed = true
			_camera_drag_moved = false
			_camera_drag_double_click = event.double_click
			_camera_drag_start = event.position
		elif Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and event.button_index == MOUSE_BUTTON_RIGHT:
			_pending_walk_click = event.position
			_pending_walk_run = event.double_click
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# A RODA TROCA O ITEM DA MÃO, como no 2D (#2): é o gesto que se faz o
			# tempo todo no meio do trabalho. O zoom ficou no Ctrl+roda e no
			# mais e menos (`mv_zoom_in`/`mv_zoom_out`). Para baixo é o espaço
			# seguinte, como lá. Com mapa ou tela aberta este nó não ouve nada,
			# então a roda de lá continua sendo de lá.
			var para_cima: bool = event.button_index == MOUSE_BUTTON_WHEEL_UP
			if event.ctrl_pressed:
				_aproximar_a_camera(para_cima)
			else:
				Inventario.selecionar(Inventario.anterior_da_mao() if para_cima else Inventario.proximo_da_mao())
				get_viewport().set_input_as_handled()
		_apply_camera()
	if event.is_action_pressed("mv_zoom_in", true):
		_aproximar_a_camera(true)
		_apply_camera()
	elif event.is_action_pressed("mv_zoom_out", true):
		_aproximar_a_camera(false)
		_apply_camera()
	if event.is_action_pressed("mv_reset"):
		reset_position()
	if event.is_action_pressed("mv_inspect"):
		inspecting = not inspecting
		_yaw = visual.rotation.y if inspecting else visual.rotation.y + PI
		_pitch = -0.08 if inspecting else -0.19
		_distance = 3.1 if inspecting else 8.0
		_apply_camera()
	if _acao_golpe_restante > 0.0:
		return
	if not _jumping:
		for index in range(8):
			if event.is_action_pressed("mv_animation_%d" % (index + 1)) and animator and animator.has_method("play_gesture"):
				var label: String = animator.play_gesture(index)
				if not label.is_empty():
					animation_requested.emit(label)
				break

## Um passo de zoom: perto é para cima na roda, e o mais no teclado.
func _aproximar_a_camera(perto: bool) -> void:
	_distance = maxf(1.6, _distance - 0.35) if perto else minf(12.0, _distance + 0.35)


## PERDER O FOCO SOLTA O MOUSE, MAS NÃO TROCA O MODO.
##
## Era aqui o defeito de "a câmera fica soltando sem motivo e sem eu apertar
## C". Ao perder o foco — alt-tab, um clique fora da janela, o Windows
## roubando a atenção por um instante — isto chamava `set_camera_locked(true)`,
## que é a MUDANÇA DE MODO. O jogador voltava para a janela no modo de
## arrastar, sem ter pedido, e sem ter como saber que voltava no Tab.
##
## Soltar o cursor ao perder o foco continua certo: mouse capturado numa janela
## que não está na frente é mouse preso num jogo que o jogador não está vendo.
## O que mudou é que agora ele VOLTA — o modo de antes é lembrado e reposto
## quando a janela recebe o foco de novo.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_camera_drag_pressed = false
		_camera_drag_moved = false
		if not _camera_locked:
			_solto_pelo_foco = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and _solto_pelo_foco:
		_solto_pelo_foco = false
		if not _camera_locked:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func set_captured(value: bool) -> void:
	set_camera_locked(not value)


func set_camera_locked(value: bool) -> void:
	_camera_locked = value
	_camera_drag_pressed = false
	_camera_drag_moved = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
	if not value and _click_world != null:
		_click_world.clear_house_interaction()
		_hovered_house = null
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	capture_changed.emit(not value)
	camera_lock_changed.emit(value)


func _rotate_camera(relative: Vector2) -> void:
	_yaw -= relative.x * mouse_sensitivity
	_pitch = clampf(_pitch - relative.y * mouse_sensitivity, -0.95, 0.35)
	_apply_camera()

## Derruba o jogador: impulso horizontal `impulso` (m/s) mais um pequeno salto, sem
## controle por `segundos`. Usa a mesma queda do pulo, então aterrissa com a animação.
func empurrar(impulso: Vector3, segundos: float = 0.45) -> void:
	_cancel_walk()
	velocity.x = impulso.x
	velocity.z = impulso.z
	velocity.y = 3.2
	_jumping = true
	_knockback_remaining = segundos
	if impulso.length_squared() > 0.01:
		visual.rotation.y = atan2(-impulso.x, -impulso.z)


## Quanto de água há acima dos pés (0 fora d'água ou sem mar com fundo).
func _profundidade() -> float:
	if _click_world == null or not _click_world.has_method("water_level"):
		return 0.0
	return maxf(_click_world.water_level() - global_position.y, 0.0)


## Lâmina d'água sobre o fundo no ponto do jogador (0 em terra), para decidir o nado.
func _fundo_da_agua() -> float:
	if _click_world == null or not _click_world.has_method("water_depth_at"):
		return 0.0
	return _click_world.water_depth_at(global_position)


func _atualizar_nado() -> void:
	var fundo := _fundo_da_agua()
	var nadar := fundo > character_height * (ANDA_ATE if _nadando else NADA_A_PARTIR)
	if nadar == _nadando:
		return
	_nadando = nadar
	if _nadando:
		_cancel_walk()
		_jumping = false
		navigation_status.emit("Nadando: aqui a água já não dá pé.")
	if animator and animator.has_method("set_swimming"):
		animator.set_swimming(_nadando)
	var ajuste := create_tween().set_parallel()
	ajuste.tween_property(camera_pivot, "position:y", PIVO_CAMERA_NADANDO if _nadando else PIVO_CAMERA, 0.35)
	ajuste.tween_property(visual, "position:y", character_height * MODELO_ACIMA_NADANDO if _nadando else 0.0, 0.35)


func is_swimming() -> bool:
	return _nadando


## Chão sob os pés para o som do passo: madeira no píer, na ponte e na canoa; água rasa
## ou funda conforme a lâmina; senão o que o cenário diz (grama, terra, areia).
func chao_dos_pes() -> String:
	var profundidade := _profundidade()
	if profundidade > 0.35:
		return "agua_funda"
	if profundidade > 0.03:
		# Restinho da baixa-mar: até ~25 cm de lâmina soa como poça, não como mar.
		var lamina := _fundo_da_agua()
		return "poca" if lamina > 0.01 and lamina <= 0.06 else "agua"
	# Fundo do mar exposto pela baixa-mar: lama, mesmo onde o cenário diz areia.
	if _click_world != null and _click_world.has_method("fundo_exposto") and _click_world.fundo_exposto(global_position):
		return "lama"
	for i in get_slide_collision_count():
		var colisao := get_slide_collision(i)
		var corpo := colisao.get_collider() as Node
		if colisao.get_normal().y > 0.6 and corpo != null:
			var nome := String(corpo.name).to_lower()
			if "pier" in nome or "ponte" in nome or "canoa" in nome:
				return "madeira"
	var chao: String = _click_world.surface_at(global_position) if _click_world != null else "grama"
	return "areia" if chao == "agua" else chao


## Intervalo entre passos (ou braçadas) no ritmo do clipe em curso; sem clipe, um
## valor fixo por passo e corrida.
func step_interval() -> float:
	var intervalo := 0.0
	if animator and animator.has_method("step_interval"):
		intervalo = animator.step_interval()
	if intervalo <= 0.05:
		intervalo = 0.32 if is_running() else 0.48
	return intervalo


## Bordas baixas (a areia da praia saindo da água, meio-fio, rampa do píer) viram
## parede para o CharacterBody3D: se o que barra o passo cabe em DEGRAU, sobe nele.
func _subir_degrau(direcao: Vector3) -> void:
	if _nadando or not is_on_wall() or direcao.length_squared() < 0.01 or get_wall_normal().y > 0.3:
		return
	var passo := Vector3(direcao.x, 0.0, direcao.z).normalized() * 0.2
	var em_cima := global_transform.translated(Vector3.UP * DEGRAU)
	if test_move(global_transform, Vector3.UP * DEGRAU) or test_move(em_cima, passo):
		return
	global_position += Vector3.UP * DEGRAU + passo


func _back_to_land() -> void:
	if not _last_land.is_finite():
		reset_position()
		return
	_cancel_walk()
	global_position = _last_land + Vector3(0, 0.1, 0)
	velocity = Vector3.ZERO
	_jumping = false
	if animator and animator.has_method("finish_jump"):
		animator.finish_jump(0.0)
	navigation_status.emit("De volta à terra firme.")


func reset_position() -> void:
	_cancel_walk()
	global_position = spawn_position
	velocity = Vector3.ZERO
	_last_land = Vector3.INF
	_run_toggled = false
	_ran_since_toggle = false
	_jump_buffer_remaining = 0.0
	_grounded_grace_remaining = 0.0
	_jumping = false
	if animator and animator.has_method("finish_jump"):
		animator.finish_jump(0.0)
	visual.rotation.y = 0.0
	_yaw = 0.0
	_pitch = -0.19
	_distance = 8.0
	inspecting = false
	_apply_camera()


func _raycast_cursor(mouse: Vector2, mask: int, areas: bool = false) -> Dictionary:
	var ray_from := camera.project_ray_origin(mouse)
	var ray_to := ray_from + camera.project_ray_normal(mouse) * camera.far
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to, mask, [get_rid()])
	query.collide_with_areas = areas
	query.collide_with_bodies = not areas
	return get_world_3d().direct_space_state.intersect_ray(query)


func _pointed_house(mouse: Vector2) -> Dictionary:
	var house_hit := _raycast_cursor(mouse, HOUSE_INTERACTION_LAYER, true)
	if house_hit.is_empty():
		return house_hit
	var body_hit := _raycast_cursor(mouse, 1)
	if not body_hit.is_empty():
		var body: Object = body_hit["collider"]
		if body is Node3D and (body as Node3D).is_in_group("moradores"):
			var ray_origin := camera.project_ray_origin(mouse)
			if ray_origin.distance_squared_to(body_hit["position"]) < ray_origin.distance_squared_to(house_hit["position"]):
				return {}
	return house_hit


func _request_walk_at_cursor(mouse: Vector2, run_to_destination: bool = false) -> void:
	if _click_world == null:
		return
	_cancel_walk()
	_click_world.clear_house_interaction()
	_hovered_house = null
	var house_hit := _pointed_house(mouse)
	var destination := Vector3.INF
	if not house_hit.is_empty():
		destination = _click_world.get_house_destination(house_hit["collider"], global_position)
	else:
		var ground_hit := _raycast_cursor(mouse, 1)
		if not ground_hit.is_empty():
			var collider: Object = ground_hit["collider"]
			if collider is Node3D and (collider as Node3D).is_in_group("moradores"):
				destination = _approach_npc(collider as Node3D)
			else:
				destination = ground_hit["position"]
	if not destination.is_finite() or not _click_world.is_walkable_point(destination):
		navigation_status.emit("Esse ponto não tem acesso caminhável.")
		return
	var path: PackedVector3Array = _navigator.find_path(global_position, destination)
	if path.is_empty():
		navigation_status.emit("Não encontrei um caminho até esse ponto.")
		return
	_walk_path = path
	_walk_run = run_to_destination and _vigor >= VIGOR_MINIMO_PARA_CORRER
	_walk_index = 0
	_walk_destination = destination
	_stuck_time = 0.0
	_replan_attempts = 0
	navigation_status.emit("%s até o ponto selecionado. %s cancela o trajeto." % ["Correndo" if run_to_destination else "Caminhando", TeclasMovimento.rotulo()])


## Inicia o mesmo caminho usado pelo clique, para interações que precisam de
## uma aproximação antes de acontecer (como parar diante de um tronco).
func caminhar_ate(destino: Vector3) -> bool:
	if _click_world == null or not _click_world.is_walkable_point(destino):
		return false
	_cancel_walk()
	var caminho: PackedVector3Array = _navigator.find_path(global_position, destino)
	if caminho.is_empty():
		return false
	_walk_path = caminho
	_walk_run = false
	_walk_index = 0
	_walk_destination = destino
	_stuck_time = 0.0
	_replan_attempts = 0
	navigation_status.emit("Caminhando até o ponto selecionado. %s cancela o trajeto." % TeclasMovimento.rotulo())
	return true


func caminhando_para(destino: Vector3) -> bool:
	return _walk_destination.is_finite() and _walk_destination.distance_squared_to(destino) < 0.01


func _approach_npc(npc: Node3D) -> Vector3:
	var away := global_position - npc.global_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.FORWARD
	for angle in [0.0, PI * 0.5, -PI * 0.5, PI]:
		var point := npc.global_position + away.normalized().rotated(Vector3.UP, angle) * 2.2
		if _click_world.is_walkable_point(point):
			return point
	return Vector3.INF


func _next_walk_direction() -> Vector3:
	while _walk_index < _walk_path.size():
		var waypoint := _walk_path[_walk_index]
		var offset := Vector3(waypoint.x - global_position.x, 0, waypoint.z - global_position.z)
		if offset.length() >= ARRIVAL_DISTANCE:
			return offset.normalized()
		_walk_index += 1
	_cancel_walk()
	navigation_status.emit("Destino alcançado.")
	return Vector3.ZERO


func _distance_to_next_waypoint() -> float:
	if _walk_index >= _walk_path.size():
		return 0.0
	var waypoint := _walk_path[_walk_index]
	return Vector2(global_position.x, global_position.z).distance_to(Vector2(waypoint.x, waypoint.z))


func _retry_walk() -> void:
	_stuck_time = 0.0
	_replan_attempts += 1
	if _replan_attempts > 2:
		_cancel_walk()
		navigation_status.emit("Caminho bloqueado. Escolha outro destino.")
		return
	var path: PackedVector3Array = _navigator.find_path(global_position, _walk_destination)
	if path.is_empty():
		_cancel_walk()
		navigation_status.emit("Caminho bloqueado. Escolha outro destino.")
		return
	_walk_path = path
	_walk_index = 0


func _cancel_walk() -> void:
	_walk_path.clear()
	_walk_run = false
	_walk_index = 0
	_walk_destination = Vector3.INF
	_stuck_time = 0.0
	_replan_attempts = 0


func get_animation_names() -> PackedStringArray:
	if animator and animator.has_method("get_animation_names"):
		return animator.get_animation_names()
	return PackedStringArray()


func get_current_animation() -> StringName:
	if animator and animator.has_method("get_current_animation"):
		return animator.get_current_animation()
	return &"procedural"


func is_running() -> bool:
	return _vigor >= VIGOR_MINIMO_PARA_CORRER and (_run_toggled or (_walk_run and not _walk_path.is_empty()))


func vigor_atual() -> float:
	return _vigor


func gastar_vigor(quantidade: float) -> bool:
	if quantidade <= 0.0:
		return true
	if _vigor + 0.001 < quantidade:
		return false
	_definir_vigor(_vigor - quantidade)
	return true


func _atualizar_vigor(delta: float, corrida_ativa: bool) -> void:
	if corrida_ativa:
		_definir_vigor(_vigor - CUSTO_CORRIDA_POR_SEGUNDO * delta)
		if _vigor <= 0.0:
			_run_toggled = false
			_walk_run = false
			_ran_since_toggle = false
		return
	if _vigor >= VIGOR_MAXIMO:
		return
	var gesticulando := animator != null and animator.has_method("gesture_ativa") and bool(animator.call("gesture_ativa"))
	if _acao_golpe_restante > 0.0 or gesticulando or not is_on_floor():
		return
	var andando := Vector2(velocity.x, velocity.z).length_squared() > 0.04
	var taxa := VIGOR_RECUPERACAO_ANDANDO if andando else VIGOR_RECUPERACAO_PARADO
	_definir_vigor(_vigor + taxa * delta)


func _definir_vigor(valor: float) -> void:
	var novo := clampf(valor, 0.0, VIGOR_MAXIMO)
	if novo < VIGOR_MINIMO_PARA_CORRER:
		_run_toggled = false
		_walk_run = false
		_ran_since_toggle = false
	if is_equal_approx(novo, _vigor):
		return
	_vigor = novo
	vigor_mudou.emit(_vigor)


func _apply_camera() -> void:
	camera_pivot.rotation.y = _yaw
	spring.rotation.x = _pitch
	spring.spring_length = _distance


## A câmera está no modo de arrastar? Quem pergunta é quem vai pausar o jogo e
## precisa devolver o modo depois — ver `Prototype._pause_valley`.
func camera_travada() -> bool:
	return _camera_locked
