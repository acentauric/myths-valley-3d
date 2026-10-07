extends SceneTree
## O jogador entra no mar andando ao lado do píer: afunda aos poucos no fundo da
## batimetria, anda mais devagar, passa a nadar onde não dá pé (cabeça de fora, sem
## afundar), e depois volta nadando e andando até a areia, sem pular.
##
## E A CÂMERA, a cada quadro da travessia, na ida (atrás do jogador, em terra e depois
## sobre o raso) e na volta (atrás dele, sobre o mar): fica acima da água de onde está
## e não chega ao corpo (`tests/camera_resiliente.gd` varre as poses; este mede a
## caminhada de verdade).

## Quanto a câmera fica acima da água, no mínimo (a garantia é 0,35).
const CAMERA_ACIMA_DA_AGUA := 0.30
## A menor distância da câmera ao pivô (a garantia é 1,25).
const BRACO_MINIMO := 1.2

var menor_folga := INF
var menor_braco := INF


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_assert(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "vale carrega")
	await _frames(6)
	await _mundo_pronto()
	var vale = current_scene
	# O cartão da água funda (#96) para o vale no primeiro nado: aqui o nado é a
	# prova, e o aviso conta como já dado.
	vale._avisou_agua_funda = true
	var world = vale.world
	var player: CharacterBody3D = vale.player
	_assert(is_finite(world.water_level()), "mar com fundo")
	var mensagens: Array[String] = []
	player.navigation_status.connect(func(texto: String) -> void: mensagens.append(texto))

	# Parte da areia, a 6 unidades do lado do píer, e caminha para o mar.
	var direcao: Vector3 = world.ancoras["PierDirecao"]
	var lado := Vector3(-direcao.z, 0.0, direcao.x) * 6.0
	var inicio: Vector3 = world.ground_position(world.ancoras["PierPiso"] - direcao * 10.0 + lado, 0.05)
	player.global_position = inicio
	player.velocity = Vector3.ZERO
	player.set("_yaw", atan2(-direcao.x, -direcao.z))
	await _physics_frames(10)
	# Correndo: a planície rasa tem ~170 unidades até a água funda.
	#
	# O TETO DE QUADROS SUBIU, e a razão é o VIGOR. Correr passou a gastar vigor
	# (`CUSTO_CORRIDA_POR_SEGUNDO`, 10 por segundo, de 100): depois de dez
	# segundos o `_run_toggled` cai sozinho e o jogador segue a pé. Com 6000
	# quadros ele cobria 155,4 das ~170 unidades e parava na areia molhada, e o
	# portão dizia "nada onde não dá pé" — quando o que faltava era distância,
	# não nado.
	#
	# Não se refaz o `_run_toggled` a cada volta de propósito: isso seria o
	# portão fingindo um vigor infinito que o jogador não tem, e a travessia
	# deixaria de medir o que ela mede. O que se dá é TEMPO, que é o que o
	# jogador também tem.
	player.set("_run_toggled", true)
	var folego_em_terra: float = player.folego_atual()
	Input.action_press("mv_forward")
	var velocidades: Array[float] = []
	var quadros_nadando := 0
	var folego_no_inicio_nado := -1.0
	var vigor_no_inicio_nado := -1.0
	var cabeca_fora := true
	for frame in range(14000):
		await physics_frame
		_medir_a_camera(world, player)
		if frame % 120 == 60 and not player.is_swimming():
			velocidades.append(Vector2(player.velocity.x, player.velocity.z).length())
		if player.is_swimming():
			quadros_nadando += 1
			if quadros_nadando == 1:
				folego_no_inicio_nado = player.folego_atual()
				vigor_no_inicio_nado = player.vigor_atual()
			if quadros_nadando > 60 and player.global_position.y + player.character_height < world.water_level() + 0.2:
				cabeca_fora = false
			if quadros_nadando > 240:
				break
	Input.action_release("mv_forward")
	var andou := Vector2(player.global_position.x - inicio.x, player.global_position.z - inicio.z).length()
	print("AGUA_RASA: andou %.1f u · nadou %d quadros · velocidades %s · %s" % [andou, quadros_nadando, velocidades, mensagens])
	_assert(not mensagens.has("De volta à terra firme."), "não cai nem volta à terra")
	_assert(quadros_nadando > 240, "nada onde não dá pé")
	_assert(folego_no_inicio_nado >= folego_em_terra - 0.2, "correr ou andar em terra gastou fôlego")
	_assert(player.vigor_atual() < vigor_no_inicio_nado, "nadar na água funda não gastou vigor")
	_assert(player.folego_atual() >= folego_no_inicio_nado - 0.2, "nadar com vigor gastou fôlego")
	_assert(cabeca_fora, "nada com a cabeça fora d'água")
	_assert(velocidades.size() > 2 and velocidades.back() < velocidades.front() * 0.8, "anda mais devagar na água")

	# Meia-volta: nada e anda de volta até a terra firme, só com o direcional.
	player.set("_yaw", atan2(direcao.x, direcao.z))
	Input.action_press("mv_forward")
	var em_terra := false
	# Mesma razão do teto de cima: a volta é a pé, e a pé leva mais tempo.
	for frame in range(16000):
		await physics_frame
		_medir_a_camera(world, player)
		if frame % 600 == 0:
			print("VOLTA %d pos %s vel %s nadando %s chao %s parede %s fundo %.2f" % [frame, player.global_position, player.velocity, player.is_swimming(), player.is_on_floor(), player.is_on_wall(), world.water_depth_at(player.global_position)])
		if player.is_on_floor() and world.is_on_land(player.global_position):
			em_terra = true
			break
	Input.action_release("mv_forward")
	print("AGUA_RASA: volta à terra %s · nadando %s · %s" % [em_terra, player.is_swimming(), player.global_position])
	_assert(em_terra, "sai da água andando até a terra, sem pular")
	_assert(not player.is_swimming(), "para de nadar em terra")
	print("AGUA_RASA: câmera: folga mínima sobre a água %+.2f m, braço mínimo %.2f m" % [menor_folga, menor_braco])
	_assert(is_finite(menor_folga), "a câmera nunca esteve sobre a água na travessia: o portão não mediu nada")
	_assert(menor_folga >= CAMERA_ACIMA_DA_AGUA, "a câmera chegou a %+.2f m da água na travessia (mínimo %.2f)" % [menor_folga, CAMERA_ACIMA_DA_AGUA])
	_assert(menor_braco >= BRACO_MINIMO, "a câmera chegou a %.2f m do pivô na travessia (mínimo %.2f): dentro do personagem" % [menor_braco, BRACO_MINIMO])
	print("AGUA_RASA_OK")
	quit()


## A câmera deste quadro: a folga sobre a água de onde ela está (só sobre água) e o braço.
func _medir_a_camera(world, player) -> void:
	var camera: Camera3D = player.get("camera")
	var onde: Vector3 = camera.global_position
	if world.water_depth_at(onde) > 0.0:
		menor_folga = minf(menor_folga, onde.y - world.water_level_at(onde))
	menor_braco = minf(menor_braco, onde.distance_to((player.get("camera_pivot") as Node3D).global_position))


func _assert(condition: bool, label: String) -> void:
	if not condition:
		push_error("AGUA_RASA_FALHOU: " + label)
		quit(1)
		assert(false, label)


func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame


func _physics_frames(count: int) -> void:
	for frame in range(count):
		await physics_frame


## O vale se monta ao longo de vários quadros (world_builder): espera ficar pronto.
func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
