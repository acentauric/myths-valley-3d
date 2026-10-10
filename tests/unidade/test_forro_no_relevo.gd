extends "res://tests/unidade/base.gd"
## Forro (capim, bromélia, samambaia) assentado no relevo sem flutuar nem afundar.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste forro_no_relevo


func test_forro_no_relevo() -> void:
	await process_frame
	var catalogo: GDScript = load("res://scripts/prototipo_3d/catalogo_assets.gd")
	var terreno: Node3D = load("res://tests/fixtures/relevo_do_forro.gd").new()
	pendurar(terreno)
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
