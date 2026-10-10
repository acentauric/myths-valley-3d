extends "res://tests/suite/caso.gd"
## Cercas visíveis são obstáculos reais, e Candinha ainda chega à Zefa (#125).
var falhas := 0

func _initialize() -> void:
	_run.call_deferred()
	create_timer(240).timeout.connect(func():
		print("FALHA: circulação excede o tempo de prova")
		quit(2))

func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: ", texto)

func _run() -> void:
	change_scene_to_file("res://scenes/prototipo_3d/vale.tscn")
	await process_frame
	while current_scene == null or current_scene.get("carga_ok") != true:
		await process_frame
	var vale: Node = current_scene
	var nav: Node = get_first_node_in_group("navegacao")
	while not nav.esta_pronta(): await physics_frame
	root.get_node("Dia").pausado = true
	vale.apresentacao_do_povoado.set_process(false)
	vale.pedro.set_physics_process(false)
	var candinha: CharacterBody3D = vale._achar_morador("candinha")
	var zefa: CharacterBody3D = vale._achar_morador("zefa")
	var destino: Vector3 = zefa.global_position
	for pessoa in get_nodes_in_group("moradores"):
		pessoa.set_physics_process(false)
		pessoa.set_process(false)
		pessoa.collision_layer = 0
	candinha.collision_layer = 1
	var corpos := get_nodes_in_group("cercas_do_paisagismo")
	conferir(not corpos.is_empty(), "cercas visíveis possuem corpo")
	if "--sem-corpos" in OS.get_cmdline_user_args():
		for corpo in corpos: corpo.collision_layer = 0
	var quantidade := 0
	for corpo in corpos:
		conferir(corpo.collision_layer & 1 != 0, "o mesmo corpo entra na leitura da navegação")
		for forma in corpo.get_children():
			if forma is CollisionShape3D:
				quantidade += 1
				var centro: Vector3 = forma.global_position
				var consulta := PhysicsPointQueryParameters3D.new()
				consulta.position = centro
				consulta.collision_mask = 1
				consulta.exclude = [candinha.get_rid()]
				var colisoes: Array[Dictionary] = candinha.get_world_3d().direct_space_state.intersect_point(consulta, 32)
				conferir(colisoes.any(func(hit: Dictionary) -> bool: return hit.get("collider") == corpo),
					"cada lance contém seu próprio corpo físico no centro")
	conferir(quantidade == (vale.world._region.get_meta("cercas_cerca_varas", []) as Array).size(), "cada lance desenhado tem uma colisão")
	if "--apenas-colisoes" in OS.get_cmdline_user_args():
		print("CERCAS_E_CIRCULACAO: %d falha(s)" % falhas)
		quit(1 if falhas else 0)
		return
	for i in 7200:
		await physics_frame
		var ponto: Vector3 = candinha._ponto_do_caminho(destino, 1.0 / 60.0)
		var rumo := Vector3(ponto.x - candinha.global_position.x, 0, ponto.z - candinha.global_position.z).normalized()
		candinha._mover(rumo, 3.0, 1.0 / 60.0)
		if i % 600 == 0: print("CIRCULACAO: ", candinha.global_position, " rumo ", ponto)
		if Vector2(candinha.global_position.x - destino.x, candinha.global_position.z - destino.z).length() < 1.5:
			break
	conferir(Vector2(candinha.global_position.x - destino.x, candinha.global_position.z - destino.z).length() < 1.5,
		"Candinha chega fisicamente à Zefa sem atravessar cerca ou tronco")
	print("CERCAS_E_CIRCULACAO: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
