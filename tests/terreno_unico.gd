extends SceneTree
var falhas := 0
func _initialize() -> void:
	_run.call_deferred()
func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: ", texto)
func _run() -> void:
	await process_frame
	load("res://scripts/prototipo_3d/abertura.gd").lobby_3d_pedido = true
	for caminho in ["abertura", "vale"]:
		conferir(change_scene_to_file("res://scenes/prototipo_3d/%s.tscn" % caminho) == OK, "cena carrega")
		await process_frame
		for i in 3600:
			var esperando := get_first_node_in_group("mundo")
			if esperando != null and esperando.construido: break
			await process_frame
		await process_frame
		var mundo: Node = get_first_node_in_group("mundo")
		conferir(mundo != null and mundo.construido, "terreno termina de carregar")
		if mundo != null:
			var terras: Array[Node] = mundo.find_children("Terra", "MeshInstance3D", true, false)
			conferir(terras.size() == 1, caminho + " gera uma única malha de terra")
			conferir(mundo.get_node_or_null("TerrenoEditor") == null, caminho + " remove o host antes da geração")
			for terra in terras:
				conferir((terra as MeshInstance3D).mesh != null, "terreno gerado tem malha renderizável")
	print("TERRENO_UNICO: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
