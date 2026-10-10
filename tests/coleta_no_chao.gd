extends "res://tests/suite/caso.gd"
var falhas := 0
func _initialize() -> void:
	_run.call_deferred()
	create_timer(180).timeout.connect(func(): quit(2))
func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: " + texto)
func tecla() -> void:
	var e := InputEventKey.new()
	e.physical_keycode = KEY_E
	e.pressed = true
	root.push_input(e, true)
	await process_frame
	e = InputEventKey.new()
	e.physical_keycode = KEY_E
	root.push_input(e, true)
	await process_frame
func _run() -> void:
	await process_frame
	change_scene_to_file("res://scenes/prototipo_3d/vale.tscn")
	await process_frame
	var mundo := get_first_node_in_group("mundo")
	while mundo == null or not mundo.construido:
		await process_frame
		mundo = get_first_node_in_group("mundo")
	for _i in 10:
		await process_frame
	var vale := current_scene
	var jogador: Node3D = vale.player
	var coleta: Node3D = vale.get_node("Luta").coleta
	if "--sem-e" in OS.get_cmdline_user_args():
		coleta.set_process_unhandled_key_input(false)
	var inventario := root.get_node("Inventario")
	for i in inventario.ESPACOS:
		inventario.espacos[i] = {}
	var ponto: Vector3 = mundo.ground_position(mundo.ancoras["Praça"] + Vector3(16, 0, 8), 0.1)
	jogador.global_position = ponto
	jogador.velocity = Vector3.ZERO
	jogador.set_physics_process(true)
	conferir(coleta.deixar("carne_de_caca", 2, ponto), "deixa carne válida")
	conferir(inventario.quantidade("carne_de_caca") == 0, "não concede item ao cair")
	conferir(coleta.caidos[0].gravura.texture != null, "gravura visível existente")
	var estado: Dictionary = JSON.parse_string(JSON.stringify(vale.estado_para_salvar()))
	conferir(estado.get("coleta_no_chao", []).size() == 1, "save guarda espólio")
	coleta.restaurar(estado.coleta_no_chao)
	coleta.restaurar(estado.coleta_no_chao)
	conferir(coleta.caidos.size() == 1, "restaurar não duplica espólio")
	for _i in 3:
		await process_frame
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		vale.add_child(camera)
		camera.global_position = ponto + Vector3(2.5, 2.0, 3.0)
		camera.look_at(ponto + Vector3.UP * 0.4)
		camera.make_current()
		for _i in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://scratch/coleta")
		root.get_texture().get_image().save_png("res://scratch/coleta/antes-do-e.png")
	await tecla()
	conferir(coleta.caidos.is_empty() and inventario.quantidade("carne_de_caca") == 2, "E recolhe pelo foco real")
	await tecla()
	conferir(inventario.quantidade("carne_de_caca") == 2, "E repetido não duplica item")
	for i in inventario.ESPACOS:
		inventario.espacos[i] = {"id": "machado", "qtd": 1}
	coleta.deixar("carne_de_caca", 1, jogador.global_position)
	for _i in 3:
		await process_frame
	await tecla()
	conferir(coleta.caidos.size() == 1 and inventario.quantidade("carne_de_caca") == 0, "mochila cheia preserva item")
	inventario.espacos[0] = {}
	jogador.global_position += Vector3(5, 0, 0)
	await tecla()
	conferir(coleta.caidos.size() == 1, "não recolhe fora de alcance")
	jogador.global_position = coleta.caidos[0].ponto
	for _i in 3:
		await process_frame
	await tecla()
	conferir(coleta.caidos.is_empty() and inventario.quantidade("carne_de_caca") == 1, "item continua recolhível depois de liberar espaço")
	coleta.restaurar([{}, {"item": "carne_de_caca", "quantidade": -1, "ponto": [0.0, 0.0, 0.0]}])
	conferir(coleta.caidos.is_empty(), "save inválido não cria itens")
	print("COLETA_NO_CHAO: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
