extends SceneTree
## #130/#135: efeito real em exterior/interior, dia/noite e conclusÃµes seguidas.
var falhas := 0
var vale
func _initialize() -> void:
	_run.call_deferred()
func conferir(ok: bool, motivo: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: " + motivo)
func _run() -> void:
	root.get_node("Partida").comecar(1, true)
	change_scene_to_file("res://scenes/prototipo_3d/vale.tscn")
	for i in 3000:
		await process_frame
		var mundo = get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
	vale = current_scene
	await create_timer(0.5).timeout
	for cadeia in get_nodes_in_group("cadeias_de_missoes"):
		cadeia.set_physics_process(false)
	for morador in vale.moradores:
		morador.set("_ultima_saudacao_ms", Time.get_ticks_msec() + 60000)
		vale.fila_de_falas.calar_falante(morador)
	vale.fila_de_falas.calar_falante(vale.pedro)
	vale.pedro.set_physics_process(false)
	root.get_node("Dia").pausado = true
	var sala = vale.interiores.sala_de("casa")
	conferir(sala != null, "casa nÃ£o montada")
	if sala == null:
		quit(1)
		return
	var caderno = root.get_node("CadernoDoVale")
	for interior in [false, true]:
		for hora in [9.0, 20.0]:
			root.get_node("Dia").definir_hora(hora)
			var ponto: Vector3 = sala.ponto_do_bau() if interior else sala.soleira_de_fora() + sala.global_basis.z * 5.0
			vale.player.teleportar(ponto, 0.0)
			await create_timer(0.8).timeout
			conferir(vale.interiores.dentro() == ("casa" if interior else ""), "cÃ¢mera no ambiente errado")
			vale._seta.definir_alvo(sala.ponto_do_bau(), "")
			await process_frame
			await process_frame
			if interior:
				conferir(not vale._seta._cone.is_visible_in_tree() and not vale._seta._anel.is_visible_in_tree(),
					"marcaÃ§Ã£o 3D invade a cÃ¢mera interna")
			var id := "efeito_%s_%s" % [interior, hora]
			caderno.abrir_missao(id, "Uma leira pronta", "pedro")
			caderno.concluir(id)
			var limite := Time.get_ticks_msec() + 10000
			while not vale.conquista.ativa() and Time.get_ticks_msec() < limite:
				await process_frame
			conferir(vale.conquista.ativa(), "conquista real nÃ£o aparece no vale")
			await create_timer(0.5).timeout
			conferir(vale.conquista._sombra.color.a == 0.0 and vale.conquista._veu.color.a == 0.0,
				"conquista altera exposiÃ§Ã£o do ambiente")
			conferir(not vale.conquista._raiz.get_global_rect().intersects(vale.hud._heading.get_global_rect()),
				"conquista cobre missÃ£o")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://tools/temp/efeito-%s-%s.png" % [interior, int(hora)])
			await create_timer(3.0).timeout
			if interior and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://tools/temp/parede-interna-%s.png" % int(hora))
			conferir(not vale.conquista.ativa() and not vale.conquista.esperando(),
				"efeitos consecutivos acumulam ou persistem")
	vale.player.teleportar(sala.ponto_da_cama(), 0.0)
	await create_timer(0.8).timeout
	vale._seta.definir_alvo(sala.ponto_da_cama(), "")
	conferir(not vale._seta._cone.is_visible_in_tree() and not vale._seta._anel.is_visible_in_tree(),
		"marcador cobre a cama na câmera interna")
	print("EFEITOS_NO_VALE: %d falha(s), exterior/interior de dia/noite e cama" % falhas)
	current_scene.queue_free()
	await process_frame
	await process_frame
	quit(1 if falhas else 0)
