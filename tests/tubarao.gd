extends SceneTree
## O tubarão existe na água funda, persegue o jogador que nada lá, ataca (tela escura)
## e devolve o jogador à terra firme; o Pedro nunca é alvo.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_assert(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "vale carrega")
	await _frames(6)
	await _mundo_pronto()
	var vale = current_scene
	var world = vale.world
	var player: CharacterBody3D = vale.player
	var tubarao = vale.get_node_or_null("Tubarao")
	_assert(tubarao != null, "tubarão criado")
	_assert(tubarao.get("_ativo") == true, "tubarão ativo (achou água funda)")
	_assert(tubarao.get("_modelo_tripo") != null, "modelo Tripo do tubarão em uso")
	_assert((tubarao.get("_ossos_cauda") as Array).size() == 2, "rig da cauda em uso")
	var esqueleto: Skeleton3D = tubarao.get("_esqueleto")
	var osso_cauda: int = (tubarao.get("_ossos_cauda") as Array)[0]
	var pose_inicial := esqueleto.get_bone_pose_rotation(osso_cauda)
	var maior_giro := 0.0
	for frame in 24:
		await physics_frame
		maior_giro = maxf(maior_giro, pose_inicial.angle_to(esqueleto.get_bone_pose_rotation(osso_cauda)))
	_assert(maior_giro > 0.01,
		"cauda do tubarão oscila durante a patrulha")
	print("TUBARAO: centro %s · lâmina no centro %.2f u · elipse %.1f × %.1f" % [tubarao.get("_centro"), world.water_depth_at(tubarao.get("_centro")), tubarao.get("_a"), tubarao.get("_b")])

	# Terra firme conhecida: o jogador parte da praça (vira a última terra firme).
	await _physics_frames(30)
	var terra: Vector3 = player.global_position
	# Joga o jogador nadando a 12 u do tubarão, em água funda.
	var t: Vector3 = tubarao.global_position
	var fora := Vector3(12.0, 0.0, 0.0)
	var ponto := t + fora
	for tentativa in 12:
		if world.water_depth_at(ponto) > 1.9:
			break
		fora = fora.rotated(Vector3.UP, PI / 6.0)
		ponto = t + fora
	player.global_position = Vector3(ponto.x, world.water_level() - 1.2, ponto.z)
	player.velocity = Vector3.ZERO
	await _physics_frames(20)
	_assert(player.is_swimming(), "jogador nadando na água funda")
	var d0 := Vector2(tubarao.global_position.x - player.global_position.x, tubarao.global_position.z - player.global_position.z).length()
	var atacou := false
	var mensagens: Array[String] = []
	var d_min := d0
	for frame in 1800:
		await physics_frame
		var d := Vector2(tubarao.global_position.x - player.global_position.x, tubarao.global_position.z - player.global_position.z).length()
		d_min = minf(d_min, d)
		if tubarao.get("_atacando") == true:
			atacou = true
			break
	print("TUBARAO: distância inicial %.1f · mínima %.1f · atacou %s" % [d0, d_min, atacou])
	_assert(atacou, "tubarão alcança e ataca quem nada no fundo")
	# Espera a sequência do susto terminar (~1,6 s) e confere o resgate.
	await create_timer(2.5).timeout
	var lamina_depois: float = world.water_depth_at(player.global_position)
	print("TUBARAO: depois do ataque em %s · lâmina %.2f · nadando %s" % [player.global_position, lamina_depois, player.is_swimming()])
	_assert(not player.is_swimming() and lamina_depois < 0.8, "jogador volta à terra firme")
	_assert(tubarao.get("_atacando") == false, "susto termina")
	print("TUBARAO_OK")
	quit()


func _assert(condition: bool, label: String) -> void:
	if not condition:
		push_error("TUBARAO_FALHOU: " + label)
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
