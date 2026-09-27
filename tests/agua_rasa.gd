extends SceneTree
## O jogador entra no mar andando ao lado do píer: afunda aos poucos no fundo da
## batimetria, anda mais devagar e para com a água no peito, sem cair nem voltar à terra.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_assert(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "vale carrega")
	await _frames(6)
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
	Input.action_press("mv_forward")
	var mais_fundo := 0.0
	var velocidades: Array[float] = []
	for frame in range(4800):
		await physics_frame
		var profundidade: float = world.water_level() - player.global_position.y
		mais_fundo = maxf(mais_fundo, profundidade)
		if frame % 120 == 60:
			velocidades.append(Vector2(player.velocity.x, player.velocity.z).length())
		if mensagens.has("Daqui pra frente não dá pé."):
			break
	Input.action_release("mv_forward")
	var andou := Vector2(player.global_position.x - inicio.x, player.global_position.z - inicio.z).length()
	print("AGUA_RASA: andou %.1f u · água até %.2f u · velocidades %s · %s" % [andou, mais_fundo, velocidades, mensagens])
	_assert(not mensagens.has("De volta à terra firme."), "não cai nem volta à terra")
	_assert(mais_fundo > 0.6, "entra na água")
	_assert(mais_fundo < player.character_height * 0.7 + 0.15, "para com a água no peito")
	_assert(mensagens.has("Daqui pra frente não dá pé."), "avisa que não dá pé")
	_assert(velocidades.back() < velocidades.front() * 0.8, "anda mais devagar na água")
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
