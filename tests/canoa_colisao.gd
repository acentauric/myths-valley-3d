extends SceneTree
## O fundo segura o jogador e as bordas formam rampas para sair do casco.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var canoas_script = load("res://scripts/prototipo_3d/canoas.gd")
	var casco: AnimatableBody3D = canoas_script._colisao(Vector3(5.6, 0.85, 1.7), -0.10)
	root.add_child(casco)
	await physics_frame
	await physics_frame
	var centro := _altura(Vector3(0.0, 0.0, 0.0))
	var proa := _altura(Vector3(2.5, 0.0, 0.0))
	var costado := _altura(Vector3(0.0, 0.0, 0.75))
	_conferir(centro > 0.0, "fundo interno acima da água")
	_conferir(proa > centro + 0.10, "proa sobe em rampa")
	_conferir(costado > centro + 0.10, "costado sobe em rampa")
	_conferir(casco.is_in_group("embarcacao_piso"), "jogador reconhece o piso do barco")
	casco.queue_free()
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "vale carrega")
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	var vale = current_scene
	var frota: Node = vale.world.get_node_or_null("Canoas")
	_conferir(frota != null and frota.get_child_count() > 0, "frota montada")
	var canoa: Node3D = frota.get_child(0)
	var jogador: CharacterBody3D = vale.player
	jogador.global_position = canoa.global_position + Vector3.UP * 1.3
	jogador.velocity = Vector3.ZERO
	for i in 180:
		await physics_frame
	_conferir(jogador.is_on_floor(), "jogador pousa no fundo do barco")
	_conferir(not jogador.is_swimming(), "jogador sobre o barco não fica em modo nado")
	_conferir(jogador.global_position.y > canoa.global_position.y, "pés acima da linha d'água")
	var altura_inicial := jogador.global_position.y
	jogador.set("_yaw", canoa.rotation.y)
	Input.action_press("mv_right")
	var altura_maxima := altura_inicial
	for i in 100:
		await physics_frame
		altura_maxima = maxf(altura_maxima, jogador.global_position.y)
	Input.action_release("mv_right")
	_conferir(altura_maxima > altura_inicial + 0.08, "jogador sobe pela borda ao sair")
	print("CANOA_COLISAO_OK")
	quit()


func _altura(ponto: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(ponto + Vector3.UP * 2.0, ponto + Vector3.DOWN)
	var hit := root.world_3d.direct_space_state.intersect_ray(query)
	return float(hit.get("position", Vector3(0, -99, 0)).y)


func _conferir(ok: bool, mensagem: String) -> void:
	if not ok:
		push_error("CANOA_COLISAO_FALHOU: " + mensagem)
		quit(1)
		assert(false, mensagem)
