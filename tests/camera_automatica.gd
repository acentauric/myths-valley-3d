extends "res://tests/suite/caso.gd"

## Recebe o vale montado do zero: reprovava no vale deixado pelos casos anteriores (a suíte, #242).
const VALE_NOVO := true
const CameraMouse = preload("res://scripts/prototipo_3d/camera_mouse.gd")
const Camadas = preload("res://scripts/prototipo_3d/camadas.gd")
var falhas := 0
func _initialize() -> void:
	_run.call_deferred()
func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		push_error("CAMERA_AUTO_FALHOU: " + texto)
func _run() -> void:
	change_scene_to_file("res://scenes/prototipo_3d/vale.tscn")
	for i in 3000:
		var mundo = get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	for i in 8:
		await physics_frame
	var jogador = current_scene.player
	var salvo := CameraMouse.modo()
	jogador.set_camera_modo(0)
	for esperado in [1, 2, 0]:
		jogador.alternar_camera()
		conferir(jogador._camera_modo == esperado and CameraMouse.modo() == esperado, "ciclo de três modos persistido")
	jogador.set_physics_process(false)
	jogador.set_process(false)
	jogador.global_position = Vector3(0, 80, 0)
	jogador.set_camera_modo(2)
	jogador._yaw = 0.0
	jogador.velocity = Vector3(3, 0, 0)
	for i in 180:
		var antes: float = jogador._yaw
		jogador._acompanhar_camera(1.0 / 60.0)
		conferir(absf(wrapf(jogador._yaw - antes, -PI, PI)) <= 0.021, "giro não salta entre quadros")
	conferir(absf(wrapf(jogador._yaw + PI / 2, -PI, PI)) < 0.08, "enquadra atrás da direção de movimento")
	# Parede física: árvore na camada MUNDO também precisa provocar desvio.
	for camada in [Camadas.CAMERA, Camadas.MUNDO]:
		jogador.set_camera_modo(2)
		jogador._yaw = 0.0
		jogador._pitch = -0.25
		jogador.velocity = Vector3(0, 0, -3)
		jogador._apply_camera()
		var corpo := StaticBody3D.new()
		corpo.collision_layer = camada
		var forma := CollisionShape3D.new()
		var caixa := BoxShape3D.new()
		caixa.size = Vector3(3, 7, 0.7)
		forma.shape = caixa
		corpo.add_child(forma)
		current_scene.add_child(corpo)
		corpo.global_position = jogador.camera_pivot.global_position + Vector3(0, 0, 2.5)
		await physics_frame
		await physics_frame
		for i in 240:
			jogador._acompanhar_camera(1.0 / 60.0)
			jogador._apply_camera()
		if "--sem-desvio" in OS.get_cmdline_user_args():
			jogador._auto_desvio = 0.0
		conferir(absf(jogador._auto_desvio) > 0.1, "obstáculo físico provoca enquadramento lateral")
		conferir(jogador._braco_livre(jogador._pitch, jogador._distance) > jogador._distance * 0.55, "lado escolhido dá espaço à câmera")
		corpo.queue_free()
		await physics_frame
		await physics_frame
		for i in 480:
			jogador._acompanhar_camera(1.0 / 60.0)
		conferir(absf(jogador._auto_desvio) < 0.01, "retoma enquadramento após sair do obstáculo")
	# Percursos reais: vegetação, casa, píer e proximidade do guia.
	for cadeia in get_nodes_in_group("cadeias_de_missoes"):
		cadeia.set_physics_process(false)
	for pessoa in get_nodes_in_group("moradores"):
		pessoa._calar_a_boca()
		pessoa.set_physics_process(false)
	var mundo = current_scene.world
	var a: Dictionary = mundo.ancoras
	var pontos: Dictionary = {
		# Entre as raízes da gameleira: a 2,6 m do tronco na árvore de 11 m (#228); eram 4 m na de 18,2 m.
		"vegetacao": mundo.ground_position(a["Gameleira"] + Vector3(2.6, 0, 0), 0.1),
		"casa": mundo.ground_position(a["Casa de taipa"] + a["Casa de taipaFrente"] * 7, 0.1),
		"pier": a["PierPiso"],
		"pedro": mundo.ground_position(current_scene.pedro.global_position + Vector3(3, 0, 0), 0.1),
	}
	if "--capturar" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scratch/camera-automatica"))
	for lugar in pontos:
		jogador.global_position = pontos[lugar]
		jogador._cancel_walk()
		jogador.velocity = Vector3.ZERO
		jogador.set_camera_modo(2)
		jogador._yaw = 0.0
		jogador._pitch = -0.35
		jogador._encaixar_a_camera()
		jogador.set_process(true)
		for i in 120:
			await physics_frame
		conferir(jogador.camera.global_position.distance_to(jogador.camera_pivot.global_position) >= 1.19, "%s mantém folga do corpo" % lugar)
		if lugar == "vegetacao":
			if "--sem-visibilidade" in OS.get_cmdline_user_args():
				jogador._obstaculos_auto._restaurar()
			conferir(not jogador._obstaculos_auto._apagadas.is_empty(), "%s: geometria que encobre o corpo desvanece" % lugar)
		if "--capturar" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://scratch/camera-automatica/%s.png" % lugar)
		jogador.set_process(false)
	# Caminhada real por clique perto de Pedro: a câmera segue sem impedir
	# deslocamento, e deixa as árvores como estavam ao trocar de modo.
	jogador.set_process(true)
	jogador.set_physics_process(true)
	jogador.global_position = mundo.ground_position(a["Lavoura"] + Vector3(0, 0, 2), 0.1)
	var inicio: Vector3 = jogador.global_position
	var destino: Vector3 = mundo.ground_position(a["Lavoura"] + Vector3(3, 0, -2), 0.1)
	conferir(jogador.caminhar_ate(destino), "clique calcula percurso no modo automático")
	for i in 480:
		await physics_frame
		if jogador.global_position.distance_to(destino) < 1.0:
			break
	conferir(jogador.global_position.distance_to(inicio) > 2.0, "percorre fisicamente o trajeto perto de Pedro")
	conferir(jogador.global_position.distance_to(destino) < 1.0, "chega ao destino sem giro bloquear a caminhada")
	jogador.set_camera_modo(0)
	jogador._obstaculos_auto.atualizar(false, jogador.global_position, 10, 1)
	conferir(jogador._obstaculos_auto._apagadas.is_empty(), "trocar modo restaura as malhas")
	CameraMouse.definir(salvo)
	print("CAMERA_AUTOMATICA: ", falhas, " falhas")
	quit(0 if falhas == 0 else 1)
