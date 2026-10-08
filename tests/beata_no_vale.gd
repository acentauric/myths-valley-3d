extends SceneTree
var falhas := 0

func _initialize() -> void:
	_run.call_deferred()

func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: " + texto)

func _run() -> void:
	root.get_node("Estilo").modo = "tripo"
	change_scene_to_file("res://scenes/prototipo_3d/vale.tscn")
	for i in 8000:
		await process_frame
		if current_scene != null and bool(current_scene.get("carga_ok")):
			break
	var vale = current_scene
	var mundo = vale.world
	# A apresentação do povoado religa a física de quem o jogador encontra: aqui a
	# beata anda só pelo portão.
	vale.apresentacao_do_povoado.set_process(false)
	var beata
	for morador in vale.moradores:
		morador.set_physics_process(false)
		if str(morador.dados.get("id", "")) == "beata":
			beata = morador
	conferir(beata != null, "a beata não existe na cena real")
	if beata == null:
		quit(1)
		return
	conferir(beata.animador._clips["walk"] == "locomocao/walk", "o NPC real não usa a estabilização")
	beata.visible = true
	beata.animador.dormir(false)
	vale.player.set_physics_process(false)
	var camera := Camera3D.new()
	vale.add_child(camera)
	camera.current = true
	var casas = load("res://scripts/prototipo_3d/animador_bicho.gd")
	for modo in ["plano", "inclinado"]:
		var percurso: Array[Vector3] = []
		for ancora in ["Praça", "Igreja", "Cemitério", "Mirante"]:
			if not mundo.ancoras.has(ancora):
				continue
			for dx in range(-18, 19, 3):
				for dz in range(-18, 19, 3):
					var a: Vector3 = mundo.ground_position(mundo.ancoras[ancora] + Vector3(dx, 0, dz), 0.02)
					var b: Vector3 = mundo.ground_position(a + Vector3(5, 0, 0), 0.02)
					var altura := absf(b.y - a.y)
					if (modo == "plano" and altura > 0.1) or (modo == "inclinado" and (altura < 0.4 or altura > 1.5)):
						continue
					var seguro := true
					for fase in [0.0, 0.25, 0.5, 0.75, 1.0]:
						var p := a.lerp(b, fase)
						seguro = seguro and mundo.is_walkable_point(p) and not casas.dentro_de_casa(self, p, 0.5)
					if seguro:
						percurso = [a, b]
						break
				if not percurso.is_empty():
					break
			if not percurso.is_empty():
				break
		conferir(not percurso.is_empty(), "não encontrei trajeto " + modo)
		if percurso.is_empty():
			continue
		beata.global_position = percurso[0] + Vector3.UP * 0.1
		beata.velocity = Vector3.ZERO
		vale.player.global_position = percurso[0] + Vector3(0, 0, 3)
		for quadro in 240:
			await physics_frame
			var rumo: Vector3 = percurso[1] - beata.global_position
			rumo.y = 0
			beata._mover(rumo.normalized() if rumo.length() > 0.2 else Vector3.ZERO, 1.2, 1.0 / 60)
			beata._atualizar_animacao(1.0 / 60)
			conferir(beata.global_position.y - mundo.ground_height_at(beata.global_position) < 0.65, "a física salta acima do relevo")
			camera.global_position = beata.global_position + Vector3(3, 2, 4)
			camera.look_at(beata.global_position + Vector3.UP)
			if "--capturar" in OS.get_cmdline_user_args() and quadro in [60, 120, 180]:
				await process_frame
				await RenderingServer.frame_post_draw
				DirAccess.make_dir_recursive_absolute("res://scratch/beata-no-vale")
				root.get_texture().get_image().save_png("res://scratch/beata-no-vale/%s-%s.png" % [modo, quadro])
		conferir(beata.global_position.distance_to(percurso[0]) > 2.5, "a beata não caminhou no trajeto " + modo)
	print("BEATA_NO_VALE: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
