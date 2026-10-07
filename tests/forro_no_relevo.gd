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
	var catalogo: GDScript = load("res://scripts/prototipo_3d/catalogo_assets.gd")
	var terreno: Node3D = load("res://tests/fixtures/relevo_do_forro.gd").new()
	root.add_child(terreno)
	for declive in [Vector2.ZERO, Vector2(0.2, -0.1), Vector2(-0.35, 0.4)]:
		terreno.declive = declive
		for especie in ["capim", "bromelia", "samambaia"]:
			var pe := Vector3(3, 0, 5)
			pe.y = terreno.ground_height_at(pe)
			var planta: Node3D = catalogo.instanciar(especie, terreno, pe, 1.0, 0.7)
			conferir(planta != null, "planta do catálogo carrega")
			if planta == null: continue
			catalogo.assentar_planta(planta, terreno, pe)
			if "--vertical" in OS.get_cmdline_user_args(): planta.rotation.x = 0.0; planta.rotation.z = 0.0
			var medidas: AABB = catalogo.limites(planta)
			var normais: Array[float] = []
			# Os cantos da base real do GLB devem tocar o mesmo plano do chão.
			for x in [medidas.position.x, medidas.end.x]:
				for z in [medidas.position.z, medidas.end.z]:
					var ponto: Vector3 = planta.transform * Vector3(x, medidas.position.y, z)
					normais.append(ponto.y - terreno.ground_height_at(ponto))
			conferir(normais.max() < 0.02 and normais.min() > -0.15, "base do GLB fica apoiada sem flutuar ou afundar demais")
			planta.free()
	terreno.free()
	print("FORRO_NO_RELEVO: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
