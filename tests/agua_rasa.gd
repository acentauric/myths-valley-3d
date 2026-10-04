extends SceneTree
## O jogador entra no mar andando ao lado do píer: afunda aos poucos no fundo da
## batimetria, anda mais devagar, passa a nadar onde não dá pé (cabeça de fora, sem
## afundar), e depois volta nadando e andando até a areia, sem pular.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_assert(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "vale carrega")
	await _frames(6)
	await _mundo_pronto()
	var vale = current_scene
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
		if frame % 600 == 0:
			print("VOLTA %d pos %s vel %s nadando %s chao %s parede %s fundo %.2f" % [frame, player.global_position, player.velocity, player.is_swimming(), player.is_on_floor(), player.is_on_wall(), world.water_depth_at(player.global_position)])
		if player.is_on_floor() and world.is_on_land(player.global_position):
			em_terra = true
			break
	Input.action_release("mv_forward")
	print("AGUA_RASA: volta à terra %s · nadando %s · %s" % [em_terra, player.is_swimming(), player.global_position])
	_assert(em_terra, "sai da água andando até a terra, sem pular")
	_assert(not player.is_swimming(), "para de nadar em terra")
	print("AGUA_RASA_OK")
	quit()


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
