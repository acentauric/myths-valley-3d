extends SceneTree
## A seleção do E não depende do último quadro desenhado pela dica (#128).
class Jogador extends Node3D:
	var camera: Camera3D
class Hud extends Node:
	var camada: Control
	func map_layer() -> Control:
		return camada
var falhas := 0
func _initialize() -> void:
	_run.call_deferred()
func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: " + texto)
func _run() -> void:
	await process_frame
	var cena := Node3D.new()
	root.add_child(cena)
	var jogador := Jogador.new()
	cena.add_child(jogador)
	jogador.set_physics_process(true)
	jogador.camera = Camera3D.new()
	jogador.add_child(jogador.camera)
	jogador.camera.make_current()
	var tonho := Node3D.new()
	tonho.name = "Tonho"
	cena.add_child(tonho)
	tonho.position = Vector3(0, 0, 1.9)
	var hud := Hud.new()
	hud.camada = Control.new()
	cena.add_child(hud)
	cena.add_child(hud.camada)
	var tecla = load("res://scripts/prototipo_3d/tecla_dos_moradores.gd").new()
	cena.add_child(tecla)
	tecla.configurar(jogador, hud, func(): return [tonho], func(): return true)
	tecla.set_process(false) # Ainda não desenhou a dica: a pergunta vem antes.
	var foco = load("res://scripts/prototipo_3d/foco_do_e.gd").new()
	cena.add_child(foco)
	foco.configurar(jogador)
	conferir(foco.dono() == tecla, "a conversa leva o E")
	var perto: Node3D = tecla._perto if "--alvo-atrasado" in OS.get_cmdline_user_args() else tecla.perto()
	conferir(perto == tonho, "o dono atual encontra Tonho antes do process da dica")
	tonho.position = Vector3(0, 0, 20)
	conferir(tecla.perto() == null, "alvo saiu do alcance: não conversa com dado antigo")
	print("CONVERSA_NO_QUADRO: %d falhas" % falhas)
	quit(0 if falhas == 0 else 1)
