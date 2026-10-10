extends "res://tests/suite/caso.gd"
## The current hull mesh drives a double-sided collision body recognized by the swimmer.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var canoas_script = load("res://scripts/prototipo_3d/canoas.gd")
	var raiz := Node3D.new()
	var visual: Node3D = canoas_script._casco_procedural()
	raiz.add_child(visual)
	var casco: AnimatableBody3D = canoas_script._colisao_do_casco(visual, raiz)
	raiz.add_child(casco)
	root.add_child(raiz)
	await physics_frame
	var formas := casco.find_children("*", "CollisionShape3D", true, false)
	_conferir(not formas.is_empty(), "the hull has no collision shapes")
	_conferir(casco.is_in_group("embarcacao_piso"), "the player cannot identify the boat floor")
	for no in formas:
		var shape := (no as CollisionShape3D).shape
		_conferir(shape is ConcavePolygonShape3D and (shape as ConcavePolygonShape3D).backface_collision,
			"hull collision must block from inside and outside")
	raiz.queue_free()
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "the valley loads")
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	var vale = current_scene
	var frota: Node = vale.world.get_node_or_null("Canoas")
	_conferir(frota != null and frota.get_child_count() > 0, "the fleet is built")
	if frota != null and frota.get_child_count() > 0:
		var canoa: Node3D = frota.get_child(0)
		var jogador: CharacterBody3D = vale.player
		jogador.global_position = canoa.global_position + Vector3.UP * 1.3
		jogador.velocity = Vector3.ZERO
		for i in 180:
			await physics_frame
		_conferir(jogador.is_on_floor(), "the player lands on the boat")
		_conferir(not jogador.is_swimming(), "the player is not swimming on the boat")
		_conferir(jogador.global_position.y > canoa.global_position.y, "the player's feet stay above water")
	print("CANOA_COLISAO_OK")
	quit()


func _conferir(ok: bool, mensagem: String) -> void:
	if not ok:
		push_error("CANOA_COLISAO_FALHOU: " + mensagem)
		quit(1)
		assert(false, mensagem)
