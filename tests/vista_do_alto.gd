extends "res://tests/suite/caso.gd"
## #18: a referência abre no alto; uma parede continua cortando o braço real.
class Mundo extends Node3D:
	var ancoras := {"Cabra do alto": Vector3(0, 3, 0)}
var falhas := 0
func _initialize() -> void:
	_run.call_deferred()
func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: ", texto)
func _run() -> void:
	var talentos = root.get_node("Talentos")
	root.get_node("Fe").ativa = ""
	talentos.destravados.clear()
	var mundo := Mundo.new()
	root.add_child(mundo)
	var jogador = load("res://scripts/prototipo_3d/player_controller.gd").new()
	root.add_child(jogador)
	jogador.set_process(false)
	jogador.set_physics_process(false)
	jogador._click_world = mundo
	jogador.position = Vector3(0, 3, 0)
	jogador._distance = 8.0
	conferir(is_equal_approx(jogador.distancia_da_vista(), 8.0), "sem talento mudou distância")
	talentos.destravados.append("olho_de_mirante")
	if "--sem-vista" in OS.get_cmdline_user_args():
		talentos.destravados.clear()
	conferir(is_equal_approx(jogador.distancia_da_vista(), 8.8), "talento não abre dez por cento no topo")
	jogador._apply_camera()
	conferir(is_equal_approx(jogador.spring.spring_length, 8.8), "referência não chega ao braço")
	conferir(is_equal_approx(jogador._distance, 8.0), "distância escolhida acumulou bônus")
	jogador.position.y = 0
	conferir(is_equal_approx(jogador.distancia_da_vista(), 8.0), "embaixo do alto recebeu vista")
	jogador.position = Vector3(20, 3, 0)
	conferir(is_equal_approx(jogador.distancia_da_vista(), 8.0), "fora da pegada recebeu vista")
	jogador.position = Vector3(0, 3, 0)
	jogador._yaw = 0
	jogador._pitch = 0
	jogador._apply_camera()
	var parede := StaticBody3D.new()
	parede.collision_layer = load("res://scripts/prototipo_3d/camadas.gd").CAMERA
	var colisao := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(20, 20, 0.5)
	colisao.shape = caixa
	parede.add_child(colisao)
	root.add_child(parede)
	parede.position = Vector3(0, 3, 4)
	await physics_frame
	await physics_frame
	conferir(jogador._braco_livre(0, jogador.distancia_da_vista()) < 4.0, "vista atravessou parede da câmera")
	jogador._encaixar_a_camera()
	jogador._posicionar_camera(0)
	conferir(jogador._braco < 4.0, "posicionamento ignorou limite físico")
	jogador.queue_free()
	mundo.queue_free()
	parede.queue_free()
	await process_frame
	print("VISTA_DO_ALTO: %d falhas" % falhas)
	quit(1 if falhas else 0)
