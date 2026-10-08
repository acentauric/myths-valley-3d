extends CharacterBody3D
## A colisão e a câmera pertencem ao controlador; o corpo é escolhido pelo estilo visual
## (autoload Estilo): humanoide procedural ou a cena GLB configurada (modo Tripo).

signal capture_changed(captured: bool)
signal camera_lock_changed(locked: bool)
signal animation_requested(label: String)
signal navigation_status(message: String)
signal vigor_mudou(valor: float)
signal folego_mudou(valor: float)
## Entrou na água, ou saiu dela: o HUD troca a barra do meio (#82).
signal nado_mudou(nadando: bool)

const ClickNavigation = preload("res://scripts/prototipo_3d/click_navigation.gd")
const AltoDaLombada = preload("res://scripts/prototipo_3d/lombada_vale.gd")
const TeclasMovimento = preload("res://scripts/prototipo_3d/teclas_movimento.gd")
const Mar = preload("res://scripts/prototipo_3d/mar.gd")
const Camadas = preload("res://scripts/prototipo_3d/camadas.gd")
const EspumaAgua = preload("res://scripts/prototipo_3d/espuma_agua.gd")
## O que o corpo mostra do que veste: o chapéu, o machado e o facão — o mesmo
## caminho do boneco da mochila (`boneco_da_mochila.gd`).
const Vestimenta3D = preload("res://scripts/prototipo_3d/vestimenta_3d.gd")
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
const FOLEGO_MAXIMO := 100.0
const CUSTO_FOLEGO_NADO_POR_SEGUNDO := 5.0
const INTERVALO_DANO_SEM_FOLEGO := 1.0
const FRACAO_DANO_SEM_FOLEGO := 0.20
const CUSTO_VIGOR_NADO_POR_SEGUNDO := 5.0
const CUSTO_VIGOR_NADO_RAPIDO_POR_SEGUNDO := 10.0
const FOLEGO_RECUPERACAO_ANDANDO := 2.5
const FOLEGO_RECUPERACAO_PARADO := 10.0
const VIGOR_MINIMO_PARA_CORRER := 0.5
const CUSTO_CORRIDA_POR_SEGUNDO := 5.0
const CUSTO_PULO_FRACAO := 0.10
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
## Parado, sem a elevação do clipe de nado, a superfície fica junto ao pescoço.
const SUBMERSO_NADO_PARADO := 0.84
## Degrau que o jogador sobe sem pular (borda da areia, meio-fio, píer).
const DEGRAU := 0.4
## Altura do pivô da câmera (acima dos pés); nadando ele sobe para a cabeça, acima da
## superfície que barra a câmera.
const PIVO_CAMERA := 1.18
const PIVO_CAMERA_NADANDO := 1.66
## O BRAÇO DA CÂMERA É SUAVE ("a câmera dá um pulo ao passar na frente do
## cruzeiro"). O SpringArm3D mede até onde a câmera cabe a cada tick de física,
## e a câmera ia direto para lá: de 8 m para 1 m num quadro, e de volta no
## seguinte. Agora o braço mede e a câmera segue (`_posicionar_camera`): ENTRA
## depressa (a esta taxa, por segundo), para não ficar atrás da parede; SAI
## devagar, e só depois de `BRACO_ESPERA` segundos livre, para não sanfonar ao
## passar rente a uma quina. Quem barra o braço é só a camada `CAMERA`
## (`camadas.gd`): chão, parede e água, e não poste, tronco ou morador.
const BRACO_ENTRA := 24.0
const BRACO_SAI := 3.0
const BRACO_ESPERA := 0.3
## O zoom sem obstáculo, mais ligeiro que a volta depois de uma parede.
const BRACO_ZOOM := 10.0
## O ATRASO VERTICAL: o degrau de 0,4 m (`_subir_degrau`) e o pulo não
## sacodem a câmera; ela alcança o corpo a esta taxa, sem ficar mais de
## `ATRASO_MAXIMO` m para trás.
const ATRASO_VOLTA := 10.0
const ATRASO_MAXIMO := 0.6
## A câmera de cima entra e sai do cômodo em tanto tempo (s).
const DE_CIMA_TRANSICAO := 0.3
## A CÂMERA RESILIENTE: o que a câmera NUNCA faz, venha o que vier do cenário
## (parede, porta, teleporte, maré). Duas garantias, e nenhuma depende de o
## `SpringArm3D` ter visto o obstáculo — o corte dele IGNORA o que já cobre a
## esfera no ponto de partida (o motor ignora a sobreposição inicial), e foi
## assim que a água do mar, que a câmera "não podia" atravessar, e a quina da
## porta, que o braço "não podia" atravessar, deixaram de barrar:
##
##   1. NUNCA DENTRO DO PERSONAGEM: o braço não fica menor que `braco_minimo`. Parede
##      atrás do jogador não aproxima a câmera, SOBE-A: a câmera passa por cima
##      da cabeça, numa inclinação mais alta, até achar um braço livre
##      (`_elevacao_que_liberta`), com mola criticamente amortecida.
##   2. NUNCA DEBAIXO D'ÁGUA: sobre o mar ou o rio, a câmera fica pelo menos
##      `camera_acima_da_agua` acima da água DAQUI E AGORA (`water_level_at`: com
##      a maré), segura pela conta e não pela física.
const BRACO_MINIMO := 1.25
const CAMERA_ACIMA_DA_AGUA := 0.35
## A elevação é procurada de tanto em tanto (rad), até a vertical, quando o braço
## livre fica a menos que isto acima do mínimo.
const ELEVACAO_PASSO := 0.12
const BRACO_FOLGA_DA_ELEVACAO := 0.15
## A mola da elevação: sobe depressa (a parede já está em cima), desce devagar
## (para a câmera não sanfonar numa quina). Segundos até quase chegar.
const ELEVACAO_TEMPO_SOBE := 0.07
const ELEVACAO_TEMPO_DESCE := 0.35
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
## O braço que se vê: a distância da câmera ao pivô agora, que persegue a que o
## SpringArm3D mede (`_posicionar_camera`).
var _braco: float = 8.0
var _espera_para_sair := 0.0
## Quantos ticks de física a câmera ainda vai direto ao ponto medido, sem
## suavizar: depois de um teleporte o braço precisa de um tick para medir o
## lugar novo (`_encaixar_a_camera`).
var _encaixe_restante := 3
var _atraso_y := 0.0
var _y_anterior := NAN
## A altura do pivô sem o atraso: a do corpo andando, a da cabeça nadando.
var _altura_do_pivo: float = PIVO_CAMERA
var _transicao_de_cima: Tween
## O braço está voltando de um obstáculo (sai devagar) ou só seguindo o zoom.
var _voltando_de_obstaculo := false
var _tick_do_encaixe := -1
## O braço mínimo e a folga sobre a água: `var`, e não `const`, para o portão
## (`tests/camera_resiliente.gd`) poder desligá-los e ver a câmera falhar.
var braco_minimo := BRACO_MINIMO
var camera_acima_da_agua := CAMERA_ACIMA_DA_AGUA
## Sobe a borda de face torta (ver `_subir_degrau`): `var` para o portão desligar e ver o corpo parar nela.
var sobe_borda_torta := true
## Quanto a câmera subiu além da inclinação do jogador para não entrar no corpo
## (rad, >= 0), a velocidade dessa subida, e a pergunta que mede o braço livre.
var _elevacao_extra := 0.0
var _elevacao_vel := 0.0
var _consulta_camera: PhysicsShapeQueryParameters3D
## A volta do pivô ao subir ou descer da água: um tween só, o novo mata o velho.
var _tween_pivo: Tween
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
var _camera_modo := 0
var _rumo_teclas_auto := NAN
var _auto_desvio := 0.0
var _auto_sondagem := 0.0
var _auto_espera := 0.0
var _obstaculos_auto: Node
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
var _sonda_barco: RayCast3D
var _visual_nado_elevado := false
var _tween_altura_nado: Tween
var _land_check := 0.0
var _run_toggled := false
var _ran_since_toggle := false
## O VIGOR, o fôlego curto do corpo (corrida, pulo, golpe; volta sozinho), e o
## FÔLEGO DO NADO, o ar debaixo d'água. A reserva do dia é outra conta, o
## `Energia` compartilhado (#82): o trabalho e a luta gastam dela, e só a comida,
## a cama e o desmaio devolvem.
var _vigor := VIGOR_MAXIMO
var _folego := FOLEGO_MAXIMO
var _timer_dano_sem_folego: Timer
## O que está na mão (o machado, o facão, a foice...) e a peça que ela mostra
## (`Vestimenta3D.item_na_mao`), "" quando nada.
var _machado_ancora: Node3D
var _machado_pivo: Node3D
var _item_visualizado := ""
var _machado_ancora_posicao_base := Vector3.ZERO
var _machado_angulo_lateral := 0.0
## O chapéu na cabeça, com o id dele ("" quando nada).
var _chapeu_ancora: Node3D
var _chapeu_id := ""
## As luvas nas duas mãos (o encaixe das Mãos), e o id delas.
var _luvas: Array[Node3D] = []
var _luvas_id := ""
var _acao_golpe_restante := 0.0
var _acao_golpe_espera_animacao := false

func _ready() -> void:
	# O cursor NÃO é preso aqui: o jogador nasce com a tela de carregamento por
	# cima, e prender agora sumia com o mouse durante toda a montagem do vale.
	# Quem decide o modo é o `prototype.gd`, quando o vale fica pronto
	# (`set_camera_locked(CameraMouse.travada())`).
	add_to_group("map_player")
	_timer_dano_sem_folego = Timer.new()
	_timer_dano_sem_folego.name = "DanoSemFolego"
	_timer_dano_sem_folego.wait_time = INTERVALO_DANO_SEM_FOLEGO
	_timer_dano_sem_folego.one_shot = true
	_timer_dano_sem_folego.process_callback = Timer.TIMER_PROCESS_PHYSICS
	_timer_dano_sem_folego.process_mode = Node.PROCESS_MODE_ALWAYS
	_timer_dano_sem_folego.timeout.connect(_ao_timer_dano_sem_folego)
	add_child(_timer_dano_sem_folego)
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
	_sonda_barco = RayCast3D.new()
	_sonda_barco.position.y = 0.25
	_sonda_barco.target_position = Vector3(0.0, -0.95, 0.0)
	add_child(_sonda_barco)
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	# Confere o rig e os clipes do viajante antes de usá-lo no estilo Tripo.
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
	# SÓ A CAMADA DA CÂMERA barra o braço (`camadas.gd`): o chão, as paredes, a
	# borda do quadro e a superfície da água (ela não mergulha).
	spring.collision_mask = Camadas.CAMERA
	# As cercas de varas (#104) barram o corpo; a malha dos moradores não as lê.
	collision_mask |= Camadas.CERCA
	spring.add_excluded_object(get_rid())
	camera_pivot.add_child(spring)
	# A MESMA pergunta do braço, feita por nós a cada quadro (`_braco_livre`): o
	# `SpringArm3D` mede na física, com um tick de idade, e só na inclinação em que está.
	_consulta_camera = PhysicsShapeQueryParameters3D.new()
	_consulta_camera.shape = camera_shape
	_consulta_camera.collision_mask = Camadas.CAMERA
	_consulta_camera.exclude = [get_rid()]
	# O braço só MEDE: a ponta dele é um nó vazio, e a câmera é filha do pivô,
	# posta por `_posicionar_camera` no comprimento que se vê.
	var ponta := Node3D.new()
	ponta.name = "Ponta"
	spring.add_child(ponta)
	camera = Camera3D.new()
	camera.fov = 58.0
	camera.near = 0.08
	camera.far = 2800.0
	camera_pivot.add_child(camera)
	camera.current = true
	_apply_camera()
	_encaixar_a_camera()
	_posicionar_camera(0.0)

func _process(delta: float) -> void:
	_posicionar_camera(delta)
	_atualizar_machado_na_mao()
	_atualizar_pose_machado(delta)
	_atualizar_vestimenta()


## Machado de ferro ou de aço: os dois são da família do machado (`Catalogo.familia`).
func machado_na_mao() -> bool:
	return Equipamento.da_familia_em_uso("machado") != ""


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


## A FERRAMENTA OU A ARMA NA MÃO, a que a barra escolheu (`Vestimenta3D`, o
## mesmo caminho do boneco da mochila). O machado de aço mostra o de ferro.
func _atualizar_machado_na_mao() -> void:
	var id := Vestimenta3D.item_na_mao()
	if id == _item_visualizado and (id == "" or _machado_ancora != null):
		return
	if _machado_ancora != null:
		_soltar(_machado_ancora)
		_machado_ancora = null
		_machado_pivo = null
		_machado_angulo_lateral = 0.0
	_item_visualizado = id
	if id == "" or model == null:
		return
	_machado_ancora = Vestimenta3D.ancora_da_mao(model, character_height, visual, Vestimenta3D.nome_da_ancora(id))
	if _machado_ancora == null:
		return
	_machado_ancora_posicao_base = _machado_ancora.position
	_machado_pivo = Vestimenta3D.na_mao(_machado_ancora, visual, id)


## O CHAPÉU NA CABEÇA E AS LUVAS NAS MÃOS, pelo que está vestido agora
## (`Vestimenta3D`). O que vai na mão tem o caminho dele, acima, por causa do
## balanço do braço.
func _atualizar_vestimenta() -> void:
	var luvas := Vestimenta3D.item_nas_maos()
	if luvas != _luvas_id:
		for ancora in _luvas:
			_soltar(ancora)
		_luvas.clear()
		_luvas_id = luvas
		if luvas != "" and model != null:
			_luvas = Vestimenta3D.luvas(model, luvas)
	var chapeu := Vestimenta3D.item_na_cabeca()
	if chapeu != _chapeu_id:
		_soltar(_chapeu_ancora)
		_chapeu_ancora = null
		_chapeu_id = chapeu
		if chapeu != "" and model != null:
			_chapeu_ancora = Vestimenta3D.ancora_da_cabeca(model)
			if _chapeu_ancora != null:
				Vestimenta3D.na_cabeca(_chapeu_ancora, chapeu)


## Tira uma âncora do corpo, com o anexo do osso que ela tinha.
func _soltar(ancora: Node3D) -> void:
	if ancora == null:
		return
	if ancora.get_parent() is BoneAttachment3D:
		ancora.get_parent().queue_free()
	else:
		ancora.queue_free()


## A LIDA QUE NÃO É GOLPE (regar, pescar): por quanto tempo ainda a peça na
## mão fica na pose de "uso" (`Vestimenta3D.pose_de`). INF até alguém dizer 0.
var _uso_restante := 0.0
## O sacolejo da peça (a vara quando o peixe fisga), em segundos que faltam.
var _sacolejo := 0.0
## A inclinação da peça (radianos), que anda junto do giro, e o pivô que já foi
## posado: peça nova começa na pose dela, sem varrer o ar até lá.
var _machado_inclinacao := 0.0
var _pivo_posado: Node3D


## A peça na mão em "uso" por `segundos` (0 encerra; INF até encerrar).
func usar_item_na_mao(segundos: float) -> void:
	_uso_restante = maxf(segundos, 0.0)


## Um tranco curto na peça da mão: o peixe pegou.
func sacudir_item_na_mao() -> void:
	_sacolejo = 0.4


## A POSE DA PEÇA NA MÃO pelo estado do corpo: parado, andando, golpe ou uso
## (`Vestimenta3D.pose_de`). Nadando a peça some — uma vara de 2,4 m no meio da
## braçada, ou um machado, é o que ninguém leva nadando.
func _atualizar_pose_machado(delta: float) -> void:
	if _machado_ancora == null:
		return
	_uso_restante = maxf(_uso_restante - delta, 0.0)
	_sacolejo = maxf(_sacolejo - delta, 0.0)
	_machado_ancora.visible = not _nadando
	var parado := Vector2(velocity.x, velocity.z).length_squared() < 0.04
	var em_golpe := _acao_golpe_restante > 0.0
	if animator != null and animator.has_method("gesture_ativa") and animator.gesture_ativa():
		em_golpe = true
	var em_idle := parado and not _jumping and not _nadando and not em_golpe
	var afastamento := -0.01 if em_idle else 0.0
	_machado_ancora.position = _machado_ancora_posicao_base + _machado_ancora.global_basis.inverse() * (visual.global_basis.x * afastamento)
	if _machado_pivo != null:
		var estado := "golpe" if em_golpe else ("uso" if _uso_restante > 0.0 else ("parado" if parado else "andando"))
		var alvo := Vestimenta3D.pose_de(_item_visualizado, estado)
		if estado == "golpe" and animator != null and animator.has_method("fase_do_golpe"):
			alvo = Vestimenta3D.pose_no_golpe(_item_visualizado, animator.fase_do_golpe())
		if _pivo_posado != _machado_pivo:
			_pivo_posado = _machado_pivo
			_machado_angulo_lateral = deg_to_rad(alvo.x)
			_machado_inclinacao = deg_to_rad(alvo.y)
		# 4 rad/s, como o machado sempre andou; a distância grande (a enxada do
		# ombro ao golpe) chega em ~0,15 s, para o golpe não cair a meio caminho.
		var giro_alvo := deg_to_rad(alvo.x)
		var inclinacao_alvo := deg_to_rad(alvo.y)
		_machado_angulo_lateral = move_toward(_machado_angulo_lateral, giro_alvo, maxf(4.0, absf(giro_alvo - _machado_angulo_lateral) / 0.15) * delta)
		_machado_inclinacao = move_toward(_machado_inclinacao, inclinacao_alvo, maxf(4.0, absf(inclinacao_alvo - _machado_inclinacao) / 0.15) * delta)
		var tranco := sin(_sacolejo * 45.0) * 9.0 * (_sacolejo / 0.4)
		Vestimenta3D.posar(_machado_ancora, _machado_pivo, visual, Vector2(rad_to_deg(_machado_angulo_lateral), rad_to_deg(_machado_inclinacao) + tranco))


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

## Talento e fé ativa entram juntos; cansaço continua encurtando o passo.
func multiplicador_do_passo() -> float:
	return (1.0 + maxf(0.0, Talentos.bonus("passo"))) * Energia.passo()


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
	# Ao acompanhar a passada, girar a câmera não gira também o rumo de uma
	# tecla que continua segurada. Isso evita caminhar em círculos no automático.
	if _camera_modo == 2:
		if input_vector.length_squared() <= 0.001:
			_rumo_teclas_auto = NAN
		else:
			if is_nan(_rumo_teclas_auto):
				_rumo_teclas_auto = _yaw
			direction = Basis(Vector3.UP, _rumo_teclas_auto) * Vector3(input_vector.x, 0, input_vector.y)
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
	# Energia acompanha o vigor do corpo. Abaixo de um quinto do teto,
	# a regra de cansaço encurta o passo para 62%.
	speed *= multiplicador_do_passo()
	if _knockback_remaining > 0.0:
		# Empurrão (ex.: o coveiro): o impulso manda até o fim, sem controle do jogador.
		_knockback_remaining -= delta
		direction = Vector3.ZERO
	else:
		velocity.x = move_toward(velocity.x, direction.x * speed, 18.0 * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, 18.0 * delta)
	if _jump_buffer_remaining > 0.0 and _grounded_grace_remaining > 0.0 and not _jumping and not _nadando and _acao_golpe_restante <= 0.0 and gastar_vigor(vigor_maximo() * CUSTO_PULO_FRACAO):
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
		# Nadando em movimento, o clipe deita e o modelo sobe um pouco. Parado,
		# o corpo fica na água até o pescoço e a animação de escada não o ergue.
		var submersao := SUBMERSO_NADANDO if _visual_nado_elevado else SUBMERSO_NADO_PARADO
		# O rio acompanha o relevo: o mar pode ficar vários metros abaixo
		# dele e empurraria o nadador contra o fundo.
		var lamina: float = _click_world.water_level_at(global_position) if _click_world.has_method("water_level_at") else _click_world.water_level()
		var altura_nado: float = lamina - character_height * submersao
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
	_empurrar_quem_barra(direction)
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
	_atualizar_altura_visual_nado()
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
		_run_toggled = not _run_toggled and _vigor >= VIGOR_MINIMO_PARA_CORRER and not Energia.cansado()
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
			alternar_camera()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(event.relative)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_aproximar_a_camera(event.button_index == MOUSE_BUTTON_WHEEL_UP)
			get_viewport().set_input_as_handled()
		elif _camera_locked and event.button_index == MOUSE_BUTTON_LEFT:
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
		_encaixar_a_camera()
	if _acao_golpe_restante > 0.0:
		return
	if not _jumping:
		for index in range(8):
			if event.is_action_pressed("mv_animation_%d" % (index + 1)) and animator and animator.has_method("play_gesture"):
				var label: String = animator.play_gesture(index)
				if not label.is_empty():
					animation_requested.emit(label)
				break

## Um passo de zoom: a roda afasta ou aproxima a câmera; + e - também funcionam.
func _aproximar_a_camera(perto: bool) -> void:
	_distance = maxf(1.6, _distance - 0.35) if perto else minf(12.0, _distance + 0.35)
	if _de_cima:
		_distance = clampf(_distance, DE_CIMA_PERTO, DE_CIMA_LONGE)


## A CÂMERA DE CIMA, num cômodo pequeno (a casa herdada). A câmera de passeio,
## oito metros atrás e quase na altura dos olhos, não cabe num quarto de três
## por quatro: o braço bate na parede, encolhe, e a câmera ia parar dentro da
## cabeça do jogador. Lá dentro ela sobe e olha de cima — o cômodo some o teto
## para ela (`comodo.gd`, `por_dentro`) —, e ao sair volta como estava.
const DE_CIMA_DISTANCIA := 4.4
const DE_CIMA_INCLINACAO := -1.2
const DE_CIMA_PERTO := 3.2
const DE_CIMA_LONGE := 5.6
var _de_cima := false
var _antes_de_cima := Vector2.ZERO
## As paredes do cômodo que o braço da câmera atravessa enquanto ela está de
## cima: sem isso, junto da parede, o braço batia nela e encolhia.
var _atravessa: Array[RID] = []


func camera_de_cima(ativa: bool, corpos_do_comodo: Array[RID] = []) -> void:
	if ativa == _de_cima:
		return
	_de_cima = ativa
	for corpo in _atravessa:
		spring.remove_excluded_object(corpo)
	_atravessa.clear()
	var ate := Vector2(DE_CIMA_DISTANCIA, DE_CIMA_INCLINACAO)
	if ativa:
		_antes_de_cima = Vector2(_distance, _pitch)
		for corpo in corpos_do_comodo:
			spring.add_excluded_object(corpo)
			_atravessa.append(corpo)
	else:
		ate = _antes_de_cima
	_atualizar_exclusao_da_camera()
	# A CÂMERA SOBE E DESCE EM TRÂNSITO, e não de um quadro para o outro; o
	# modo (`esta_de_cima`) muda na hora.
	if _transicao_de_cima != null and _transicao_de_cima.is_valid():
		_transicao_de_cima.kill()
	_transicao_de_cima = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transicao_de_cima.tween_property(self, "_distance", ate.x, DE_CIMA_TRANSICAO)
	_transicao_de_cima.tween_property(self, "_pitch", ate.y, DE_CIMA_TRANSICAO)
	_apply_camera()


func esta_de_cima() -> bool:
	return _de_cima


## Quem o braço da câmera atravessa: o próprio corpo e, de cima, as paredes do cômodo.
func _atualizar_exclusao_da_camera() -> void:
	if _consulta_camera == null:
		return
	var excluidos: Array[RID] = [get_rid()]
	excluidos.append_array(_atravessa)
	_consulta_camera.exclude = excluidos


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


func set_camera_modo(modo: int) -> void:
	_camera_modo = clampi(modo, 0, 2)
	_rumo_teclas_auto = NAN
	_auto_desvio = 0.0
	_auto_sondagem = 0.0
	_auto_espera = 0.0
	if _obstaculos_auto == null:
		_obstaculos_auto = load("res://scripts/prototipo_3d/obstaculos_camera.gd").new()
		add_child(_obstaculos_auto)
	set_camera_locked(_camera_modo != 0)


func alternar_camera() -> void:
	var preferencia = load("res://scripts/prototipo_3d/camera_mouse.gd")
	var proximo := (_camera_modo + 1) % 3
	preferencia.definir(proximo)
	set_camera_modo(proximo)


func _acompanhar_camera(delta: float) -> void:
	if _camera_modo != 2 or _de_cima:
		return
	var andando := Vector2(velocity.x, velocity.z).length_squared() > 0.16
	var rumo := atan2(-velocity.x, -velocity.z) if andando else _yaw - _auto_desvio
	_auto_sondagem -= delta
	_auto_espera = maxf(_auto_espera - delta, 0.0)
	# Sonda de esfera compartilhada com o braço: testa lados, nunca teleporta
	# a câmera para a posição livre. A mola existente continua cuidando de
	# distância, elevação, paredes e água em todos os modos.
	if _auto_sondagem <= 0.0:
		_auto_sondagem = 0.3
		var guardado := camera_pivot.rotation.y
		camera_pivot.rotation.y = rumo
		var central := _braco_livre(_pitch, _distance)
		camera_pivot.rotation.y = rumo + _auto_desvio
		var melhor := _braco_livre(_pitch, _distance)
		var desvio := _auto_desvio
		if melhor < _distance * 0.55:
			for lado in [-0.5, 0.5, -1.0, 1.0, -1.5, 1.5, -2.0, 2.0, PI]:
				camera_pivot.rotation.y = rumo + lado
				var livre := _braco_livre(_pitch, _distance)
				if livre > melhor + 0.6:
					melhor = livre
					desvio = lado
			if not is_equal_approx(desvio, _auto_desvio):
				_auto_desvio = desvio
				_auto_espera = 1.5
		elif central > _distance * 0.8 and _auto_espera <= 0.0:
			_auto_desvio = move_toward(_auto_desvio, 0.0, 0.15)
		camera_pivot.rotation.y = guardado
	var diferenca := wrapf(rumo + _auto_desvio - _yaw, -PI, PI)
	if absf(diferenca) > 0.02:
		_yaw += clampf(diferenca * (1.0 - exp(-2.5 * delta)), -delta * 1.2, delta * 1.2)


func _rotate_camera(relative: Vector2) -> void:
	_yaw -= relative.x * mouse_sensitivity
	if _de_cima:
		_pitch = clampf(_pitch - relative.y * mouse_sensitivity, -1.4, -0.85)
	else:
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
	if _sobre_barco():
		return 0.0
	var level: float = _click_world.water_level_at(global_position) if _click_world.has_method("water_level_at") else _click_world.water_level()
	return maxf(level - global_position.y, 0.0)


## Lâmina d'água sobre o fundo no ponto do jogador (0 em terra), para decidir o nado.
func _fundo_da_agua() -> float:
	if _click_world == null or not _click_world.has_method("water_depth_at"):
		return 0.0
	return _click_world.water_depth_at(global_position)


func _atualizar_nado() -> void:
	var fundo := _fundo_da_agua()
	var nadar := fundo > character_height * (ANDA_ATE if _nadando else NADA_A_PARTIR) and not _sobre_barco()
	if nadar == _nadando:
		return
	_definir_nado(nadar)
	if _nadando:
		_cancel_walk()
		_jumping = false
		navigation_status.emit("Nadando: aqui a água já não dá pé.")
	if animator and animator.has_method("set_swimming"):
		animator.set_swimming(_nadando)
	# A altura do pivô é variável (a câmera suave a lê a cada quadro); o corpo sobe na água
	# só nadando em movimento (`_atualizar_altura_visual_nado`).
	if _tween_pivo != null and _tween_pivo.is_valid():
		_tween_pivo.kill()
	_tween_pivo = create_tween()
	_tween_pivo.tween_property(self, "_altura_do_pivo", PIVO_CAMERA_NADANDO if _nadando else PIVO_CAMERA, 0.35)


func _atualizar_altura_visual_nado() -> void:
	var velocidade_horizontal := Vector2(velocity.x, velocity.z).length()
	var elevar := _nadando and velocidade_horizontal > 0.2
	if elevar == _visual_nado_elevado:
		return
	_visual_nado_elevado = elevar
	if _tween_altura_nado != null and _tween_altura_nado.is_running():
		_tween_altura_nado.kill()
	_tween_altura_nado = create_tween()
	_tween_altura_nado.tween_property(visual, "position:y", character_height * MODELO_ACIMA_NADANDO if elevar else 0.0, 0.35)


func _sobre_barco() -> bool:
	if _sonda_barco == null or not _sonda_barco.is_inside_tree():
		return false
	_sonda_barco.force_raycast_update()
	var corpo := _sonda_barco.get_collider() as Node
	return corpo != null and corpo.is_in_group("embarcacao_piso")


func is_swimming() -> bool:
	return _nadando


## Entra no nado ou sai dele, e avisa quem ouve: o HUD troca a barra do meio
## entre a reserva do dia e o fôlego do nado (`nado_mudou`).
func _definir_nado(nadar: bool) -> void:
	if nadar == _nadando:
		return
	_nadando = nadar
	_atualizar_timer_dano_sem_folego()
	nado_mudou.emit(_nadando)


## O respawn acontece com a física parada; não espera um quadro para sair da pose de nado.
func sair_do_nado_ao_renascer() -> void:
	_definir_nado(false)
	# Quem foi levado para casa acordou respirando: o ar do nado volta inteiro.
	definir_folego(FOLEGO_MAXIMO)
	if animator and animator.has_method("set_swimming"):
		animator.set_swimming(false)
	# A câmera suave relê a altura do pivô desta variável a cada quadro.
	_altura_do_pivo = PIVO_CAMERA
	if is_instance_valid(camera_pivot):
		camera_pivot.position.y = PIVO_CAMERA
	if is_instance_valid(visual):
		visual.position.y = 0.0


## ACORDAR PARADO (#189): depois de dormir, desmaiar ou cair, o corpo está em pé
## e quieto, com a pose do `papel` (hoje o parado; "levantar da cama" um dia) já
## no primeiro quadro, e nada do que fazia antes sobrevive à noite: corrida
## ligada, passeio clicado, pulo, nado, golpe e ferramenta em uso. O processo
## físico está desligado nessa hora, e é ele quem, andando, trocaria o clipe.
func acordar_parado(papel: String = "idle") -> void:
	_cancel_walk()
	velocity = Vector3.ZERO
	_run_toggled = false
	_ran_since_toggle = false
	_jumping = false
	_jump_buffer_remaining = 0.0
	_grounded_grace_remaining = 0.0
	_knockback_remaining = 0.0
	_uso_restante = 0.0
	_sacolejo = 0.0
	liberar_acao_de_golpe()
	_definir_nado(false)
	if animator and animator.has_method("acordar_parado"):
		animator.acordar_parado(papel)


## Chão sob os pés para o som do passo: madeira no píer, na ponte e na canoa; água rasa
## ou funda conforme a lâmina; senão o que o cenário diz (grama, terra, areia).
func chao_dos_pes() -> String:
	# Dentro de uma construção o chão é de lajota e tábua, e não o do mapa —
	# que, embaixo do assoalho, responderia o chão do lote.
	if dentro_de != "":
		return "madeira"
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


## QUEM BARRA O CAMINHO DÁ PASSAGEM. Andando contra um morador — de frente, e
## não roçando de lado —, ele sai do caminho (`MoradorNPC.dar_passagem`). Era a
## queixa: o Pedro parou no vão da porta da casa herdada, e o jogador não saía
## mais de casa. Vale para qualquer morador, em qualquer porta ou corredor.
func _empurrar_quem_barra(direcao: Vector3) -> void:
	if direcao.length_squared() < 0.01:
		return
	var rumo := Vector3(direcao.x, 0.0, direcao.z).normalized()
	for i in get_slide_collision_count():
		var colisao := get_slide_collision(i)
		var corpo := colisao.get_collider()
		if corpo == null or not corpo.has_method("dar_passagem"):
			continue
		var empurrao := -colisao.get_normal()
		empurrao.y = 0.0
		if empurrao.length_squared() > 0.0001 and empurrao.normalized().dot(rumo) > 0.3:
			corpo.dar_passagem(empurrao)


## Bordas baixas (a areia da praia saindo da água, meio-fio, rampa do píer) viram
## parede para o CharacterBody3D: se o que barra o passo cabe em DEGRAU, sobe nele.
##
## A BORDA TORTA TAMBÉM É DEGRAU. O corte antigo só subia onde a parede era quase
## vertical (`normal.y <= 0.3`), e a borda da faixa de rua, o pé da cabeceira da ponte
## e a areia da orla têm a face inclinada entre 47 e 65 graus — mais íngreme que os 46
## do chão (`floor_max_angle`), e menos que a parede: o corpo não a pisava, não a
## subia, e parava ali, de frente, com o chão do outro lado 11 a 22 cm mais alto
## (`tests/colisoes_de_passeio.gd` achou quatro). Agora sobe também essas, desde que
## seja só uma borda: a 0,6 m dali o chão não passa de DEGRAU acima dos pés — o que
## deixa a ladeira íngreme de verdade (0,62 m ou mais em 0,6 m) como parede.
func _subir_degrau(direcao: Vector3) -> void:
	if _nadando or not is_on_wall() or direcao.length_squared() < 0.01:
		return
	var passo := Vector3(direcao.x, 0.0, direcao.z).normalized() * 0.2
	var em_cima := global_transform.translated(Vector3.UP * DEGRAU)
	if test_move(global_transform, Vector3.UP * DEGRAU) or test_move(em_cima, passo):
		return
	if get_wall_normal().y > 0.3 and not (sobe_borda_torta and _so_uma_borda(passo.normalized())):
		return
	global_position += Vector3.UP * DEGRAU + passo


## O chão, 0,6 m adiante de `rumo`, não passa de DEGRAU acima dos pés?
func _so_uma_borda(rumo: Vector3) -> bool:
	var de := global_position + rumo * 0.6 + Vector3.UP * (DEGRAU + 0.6)
	var raio := PhysicsRayQueryParameters3D.create(de, de + Vector3.DOWN * 2.0, collision_mask)
	raio.exclude = [get_rid()]
	var bateu := get_world_3d().direct_space_state.intersect_ray(raio)
	return not bateu.is_empty() and float(bateu["position"].y) <= global_position.y + DEGRAU + 0.02


func _back_to_land() -> void:
	if not _last_land.is_finite():
		reset_position()
		return
	_cancel_walk()
	global_position = _last_land + Vector3(0, 0.1, 0)
	velocity = Vector3.ZERO
	_jumping = false
	_encaixar_a_camera()
	if animator and animator.has_method("finish_jump"):
		animator.finish_jump(0.0)
	navigation_status.emit("De volta à terra firme.")


## Em que construção o jogador está, ou "" ao ar livre. Quem escreve é o
## `interiores.gd`; o cômodo mora dentro da casca da construção, no lugar dela
## no vale, então o resto do jogo vê o jogador onde ele está.
var dentro_de := ""


## Põe o corpo noutro lugar de uma vez, de frente para `rumo` (ângulo em Y) e
## com a câmera atrás dele. A TERRA FIRME DE REFERÊNCIA RECOMEÇA ALI, como no
## `reset_position`: chegar de uma vez num chão mais baixo — do terreiro, no
## alto, à praia da gameleira — não é cair no mar, e a regra dos 2,5 m devolvia
## o corpo ao lugar de onde ele saiu.
func teleportar(destino: Vector3, rumo: float) -> void:
	_cancel_walk()
	global_position = destino
	velocity = Vector3.ZERO
	_last_land = Vector3.INF
	_jumping = false
	_jump_buffer_remaining = 0.0
	visual.rotation.y = rumo
	_yaw = rumo + PI
	# O cômodo do lugar novo decide, AGORA, se a câmera é a de cima: encaixar a
	# câmera antes disso a media com as paredes (e o modo) do lugar de onde o corpo saiu.
	var interiores := get_tree().get_first_node_in_group("interiores") if is_inside_tree() else null
	if interiores != null and interiores.has_method("atualizar_agora"):
		interiores.atualizar_agora()
	# Dentro da casa a câmera continua de cima (ver `camera_de_cima`).
	_pitch = DE_CIMA_INCLINACAO if _de_cima else -0.19
	inspecting = false
	_apply_camera()
	_encaixar_a_camera()


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
	_encaixar_a_camera()


## Na chegada nova, o jogador olha para a praia e a câmera fica à frente dele.
## O movimento continua relativo à câmera: avançar leva para dentro do vale.
func iniciar_de_frente(direcao: Vector3) -> void:
	direcao.y = 0.0
	if direcao.length_squared() < 0.001:
		return
	visual.rotation.y = atan2(direcao.x, direcao.z)
	_yaw = visual.rotation.y
	_pitch = -0.19
	_distance = 8.0
	inspecting = false
	_apply_camera()
	_encaixar_a_camera()


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


## Corre com vigor no corpo e a reserva do dia fora do fim: "no fim dele o corpo
## fica cansado, o passo encurta e não dá pra correr" (`Energia.cansado`).
func is_running() -> bool:
	return _vigor >= VIGOR_MINIMO_PARA_CORRER and not Energia.cansado() \
		and (_run_toggled or (_walk_run and not _walk_path.is_empty()))


func vigor_atual() -> float:
	return _vigor


## O VIGOR É O FÔLEGO CURTO DO CORPO, e não a reserva do dia: corre, pula e
## golpeia, e volta sozinho em segundos. A reserva (o `Energia`, o fôlego do 2D)
## é outra conta, que só a comida, a cama e o desmaio devolvem, e que a
## bênção, o talento e a luva mexem. Por isso o teto aqui é o dele.
func vigor_maximo() -> float:
	return VIGOR_MAXIMO


func definir_vigor(valor: float) -> void:
	_definir_vigor(valor)


func repor_vigor(quantidade: float) -> void:
	_definir_vigor(_vigor + quantidade)


func folego_atual() -> float:
	return _folego


func folego_maximo() -> float:
	return FOLEGO_MAXIMO


func definir_folego(valor: float) -> void:
	var novo := clampf(valor, 0.0, FOLEGO_MAXIMO)
	var mudou := not is_equal_approx(novo, _folego)
	_folego = novo
	_atualizar_timer_dano_sem_folego()
	if mudou:
		folego_mudou.emit(_folego)


func gastar_folego(quantidade: float) -> bool:
	if quantidade <= 0.0:
		return true
	if _folego + 0.001 < quantidade:
		return false
	definir_folego(_folego - quantidade)
	return true


func repor_folego(quantidade: float) -> void:
	definir_folego(_folego + quantidade)


func gastar_vigor(quantidade: float) -> bool:
	if quantidade <= 0.0:
		return true
	if _vigor + 0.001 < quantidade:
		return false
	_definir_vigor(_vigor - quantidade)
	return true


## Nadar sem vigor consome respiração. Ao zerar no nado, perde 20% da vida
## por segundo. O timer sempre ativo continua durante falas que pausam a física.
func _cobrar_folego(quantidade: float) -> void:
	if quantidade > 0.0:
		definir_folego(_folego - quantidade)


func _atualizar_timer_dano_sem_folego() -> void:
	if _timer_dano_sem_folego == null:
		return
	if _nadando and is_zero_approx(_folego) and Vida.atual > 0.0:
		if _timer_dano_sem_folego.is_stopped():
			_timer_dano_sem_folego.start()
	else:
		_timer_dano_sem_folego.stop()


func _ao_timer_dano_sem_folego() -> void:
	if not _nadando or not is_zero_approx(_folego) or Vida.atual <= 0.0:
		_atualizar_timer_dano_sem_folego()
		return
	Vida.ferir(Vida.maximo() * FRACAO_DANO_SEM_FOLEGO)
	_atualizar_timer_dano_sem_folego()


func _atualizar_vigor(delta: float, corrida_ativa: bool) -> void:
	if _nadando:
		var movendo := Vector2(velocity.x, velocity.z).length_squared() > 0.04
		if not movendo:
			_definir_vigor(_vigor + VIGOR_RECUPERACAO_PARADO * delta)
			if _vigor > 0.0:
				repor_folego(FOLEGO_RECUPERACAO_PARADO * delta)
			return
		var custo := CUSTO_VIGOR_NADO_RAPIDO_POR_SEGUNDO if corrida_ativa else CUSTO_VIGOR_NADO_POR_SEGUNDO
		var tempo_com_vigor := minf(delta, _vigor / custo)
		_definir_vigor(_vigor - custo * delta)
		# No quadro em que o vigor acaba, só o tempo restante cobra fôlego.
		repor_folego(FOLEGO_RECUPERACAO_ANDANDO * tempo_com_vigor)
		_cobrar_folego(CUSTO_FOLEGO_NADO_POR_SEGUNDO * (delta - tempo_com_vigor))
		return
	if corrida_ativa:
		gastar_vigor(minf(_vigor, CUSTO_CORRIDA_POR_SEGUNDO * delta))
		if _vigor <= 0.0:
			_run_toggled = false
			_walk_run = false
			_ran_since_toggle = false
		return
	var gesticulando := animator != null and animator.has_method("gesture_ativa") and bool(animator.call("gesture_ativa"))
	if _nadando or _acao_golpe_restante > 0.0 or gesticulando or not is_on_floor():
		return
	var andando := Vector2(velocity.x, velocity.z).length_squared() > 0.04
	var taxa := VIGOR_RECUPERACAO_ANDANDO if andando else VIGOR_RECUPERACAO_PARADO
	_definir_vigor(_vigor + taxa * delta)
	repor_folego((FOLEGO_RECUPERACAO_ANDANDO if andando else FOLEGO_RECUPERACAO_PARADO) * delta)


func _definir_vigor(valor: float) -> void:
	var novo := clampf(valor, 0.0, vigor_maximo())
	if novo < VIGOR_MINIMO_PARA_CORRER:
		_run_toggled = false
		_walk_run = false
		_ran_since_toggle = false
	if is_equal_approx(novo, _vigor):
		return
	_vigor = novo
	vigor_mudou.emit(_vigor)


## A vista se abre no topo físico da Lombada. A distância escolhida pelo
## jogador continua intacta; a esfera do braço ainda limita esta referência.
func distancia_da_vista() -> float:
	if _click_world == null or not is_inside_tree():
		return _distance
	var ancoras: Dictionary = _click_world.get("ancoras")
	if not ancoras.has("Cabra do alto"):
		return _distance
	var topo: Vector3 = ancoras["Cabra do alto"]
	var aqui := global_position
	if absf(aqui.x - topo.x) > AltoDaLombada.ALTO.x * 0.5 or absf(aqui.z - topo.z) > AltoDaLombada.ALTO.z * 0.5 or absf(aqui.y - topo.y) > 0.6:
		return _distance
	return _distance * (1.0 + maxf(0.0, Talentos.bonus("vista_do_alto")))


func _apply_camera() -> void:
	camera_pivot.rotation.y = _yaw
	spring.rotation.x = _pitch
	spring.spring_length = distancia_da_vista()


## A CÂMERA VAI DIRETO ao ponto que o braço medir, nos próximos ticks: depois
## de teleporte, volta à terra, reinício, chegada e inspeção, perseguir o braço
## de longe seria a câmera voando pelo vale.
func _encaixar_a_camera() -> void:
	_encaixe_restante = 3
	_atraso_y = 0.0
	_y_anterior = NAN
	_elevacao_extra = 0.0
	_elevacao_vel = 0.0


## A CÂMERA NO COMPRIMENTO QUE SE VÊ (ver `BRACO_ENTRA`). No `_process`, e não
## na física: o clique do mouse é lido no `_physics_process` com a câmera de
## antes (tests/click_controls.gd move a câmera à mão e conta com isso).
func _posicionar_camera(delta: float) -> void:
	if camera == null or spring == null:
		return
	if _obstaculos_auto != null:
		_obstaculos_auto.atualizar(_camera_modo == 2, global_position, distancia_da_vista(), delta)
	_acompanhar_camera(delta)
	_apply_camera()
	# O atraso vertical: o corpo subiu `dy` desde o quadro passado, e o pivô
	# fica para trás e alcança.
	var y := global_position.y
	if is_nan(_y_anterior) or _encaixe_restante > 0:
		_atraso_y = 0.0
	else:
		_atraso_y = clampf(_atraso_y - (y - _y_anterior), -ATRASO_MAXIMO, ATRASO_MAXIMO)
		_atraso_y *= exp(-ATRASO_VOLTA * delta)
	_y_anterior = y
	camera_pivot.position.y = _altura_do_pivo + _atraso_y
	# O BRAÇO LIVRE, medido agora, na inclinação em que a câmera está: a do jogador
	# mais a elevação que a parede pediu. Se ele não chega ao mínimo, a câmera sobe
	# por cima da cabeça em vez de encolher até ela (`_elevacao_que_liberta`).
	var comprimento := distancia_da_vista()
	var livre := _braco_livre(_pitch, comprimento)
	var elevar := 0.0
	if livre < braco_minimo + BRACO_FOLGA_DA_ELEVACAO:
		elevar = _elevacao_que_liberta(_pitch, comprimento)
	if _encaixe_restante > 0:
		_elevacao_extra = elevar
		_elevacao_vel = 0.0
	else:
		var mola := _amortecer(_elevacao_extra, elevar, _elevacao_vel, ELEVACAO_TEMPO_SOBE if elevar > _elevacao_extra else ELEVACAO_TEMPO_DESCE, delta)
		_elevacao_extra = maxf(mola.x, 0.0)
		_elevacao_vel = mola.y
	var inclinacao := maxf(_pitch - _elevacao_extra, -PI * 0.5)
	if _elevacao_extra > 0.001:
		livre = _braco_livre(inclinacao, comprimento)
	# NUNCA MENOR QUE O MÍNIMO: a câmera pode atravessar uma parede por um instante,
	# o que ela não faz é entrar no corpo.
	var alvo := maxf(livre, braco_minimo)
	var barrado := alvo < spring.spring_length - 0.05
	# Enquanto uma parede encurta o braço, a saída dela é a devagar, mesmo depois
	# de ele ter parado de encurtar: quem para rente a uma quina e depois anda
	# não vê a câmera dar um pulo ao se soltar.
	if barrado:
		_voltando_de_obstaculo = true
	if _encaixe_restante > 0:
		_braco = alvo
		_espera_para_sair = 0.0
		if Engine.get_physics_frames() != _tick_do_encaixe:
			_tick_do_encaixe = Engine.get_physics_frames()
			_encaixe_restante -= 1
	elif alvo < _braco:
		_braco = lerpf(_braco, alvo, 1.0 - exp(-BRACO_ENTRA * delta))
		if barrado:
			_espera_para_sair = BRACO_ESPERA
			_voltando_de_obstaculo = true
	elif _espera_para_sair > 0.0:
		_espera_para_sair = maxf(_espera_para_sair - delta, 0.0)
	else:
		_braco = lerpf(_braco, alvo, 1.0 - exp(-(BRACO_SAI if _voltando_de_obstaculo else BRACO_ZOOM) * delta))
		if not barrado and alvo - _braco < 0.05:
			_voltando_de_obstaculo = false
	# NUNCA DEBAIXO D'ÁGUA, pela conta (ver `_inclinacao_acima_da_agua`).
	spring.rotation.x = _inclinacao_acima_da_agua(inclinacao, _braco)
	camera.transform = spring.transform * Transform3D(Basis(), Vector3(0.0, 0.0, _braco))
	if _camera_modo == 2 and _obstaculos_auto != null:
		_obstaculos_auto.mostrar_jogador(camera, camera_pivot.global_position, delta)


## Até onde o braço chega, em `comprimento`, na inclinação `pitch` e no giro de agora,
## a partir do pivô: o mesmo corte com esfera do `SpringArm3D`, feito ao vivo.
func _braco_livre(pitch: float, comprimento: float) -> float:
	if _consulta_camera == null:
		return comprimento
	var origem := camera_pivot.global_position
	_consulta_camera.transform = Transform3D(Basis(), origem)
	_consulta_camera.motion = camera_pivot.global_basis * (Basis(Vector3.RIGHT, pitch) * Vector3.BACK) * comprimento
	var mascara_guardada := _consulta_camera.collision_mask
	if _camera_modo == 2:
		_consulta_camera.collision_mask |= Camadas.MUNDO | Camadas.CAMERA_VEGETACAO
	var r := get_world_3d().direct_space_state.cast_motion(_consulta_camera)
	_consulta_camera.collision_mask = mascara_guardada
	return comprimento * float(r[0]) if r.size() >= 2 else comprimento


## O MENOR AUMENTO DE INCLINAÇÃO (rad, >= 0) com que o braço livre passa do mínimo:
## a câmera olha mais de cima, até a vertical. Se nenhuma chega lá (o vão de uma
## porta baixa), a que mais liberta.
func _elevacao_que_liberta(pitch: float, comprimento: float) -> float:
	var melhor := 0.0
	var melhor_braco := -1.0
	var elevacao := 0.0
	while pitch - elevacao > -PI * 0.5:
		elevacao = minf(elevacao + ELEVACAO_PASSO, pitch + PI * 0.5)
		var livre := _braco_livre(pitch - elevacao, comprimento)
		if livre >= braco_minimo + BRACO_FOLGA_DA_ELEVACAO:
			return elevacao
		if livre > melhor_braco:
			melhor_braco = livre
			melhor = elevacao
	return melhor


## A MOLA CRITICAMENTE AMORTECIDA (a `SmoothDamp` clássica): leva `atual` a `alvo`
## em cerca de `tempo` segundos, sem passar do alvo. Devolve (valor, velocidade).
func _amortecer(atual: float, alvo: float, velocidade: float, tempo: float, delta: float) -> Vector2:
	var omega := 2.0 / maxf(tempo, 0.0001)
	var x := omega * delta
	var freio := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var mudanca := atual - alvo
	var impulso := (velocidade + omega * mudanca) * delta
	return Vector2(alvo + (mudanca + impulso) * freio, (velocidade - omega * impulso) * freio)


## A inclinação mais alta (mais perto da horizontal) que mantém a câmera, a `braco`
## do pivô, `camera_acima_da_agua` acima da água de onde ela ficaria: o nível
## DAQUI E AGORA (`water_level_at`: o mar com a maré, ou o rio). Sobre terra não
## faz nada — o chão barra o braço —, e só sobe a câmera, nunca a desce.
func _inclinacao_acima_da_agua(pitch: float, braco: float) -> float:
	if _click_world == null or not _click_world.has_method("water_depth_at"):
		return pitch
	var pivo := camera_pivot.global_position
	var horizontal := Vector3(sin(_yaw), 0.0, cos(_yaw))
	for volta in 2:
		var onde := pivo + horizontal * (braco * cos(pitch))
		if _click_world.water_depth_at(onde) <= 0.0:
			return pitch
		var minimo: float = _click_world.water_level_at(onde) + camera_acima_da_agua
		pitch = minf(pitch, asin(clampf((pivo.y - minimo) / maxf(braco, 0.01), -1.0, 1.0)))
	return pitch


## A câmera está no modo de arrastar? Quem pergunta é quem vai pausar o jogo e
## precisa devolver o modo depois — ver `Prototype._pause_valley`.
func camera_travada() -> bool:
	return _camera_locked
