extends SceneTree
class Cao extends Node3D:
	var jogador: Node3D
	var perto := true
	var deitado := false
class Fala extends Node:
	func livre() -> bool:
		return false
var falhas := 0
func _initialize() -> void:
	_run.call_deferred()
func conferir(ok: bool, motivo: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: " + motivo)
func _run() -> void:
	await process_frame
	var audio = root.get_node("Audio")
	var cao := Cao.new()
	root.add_child(cao)
	cao.jogador = Node3D.new()
	cao.add_child(cao.jogador)
	var som = load("res://scripts/prototipo_3d/latido_caramelo.gd").new()
	cao.add_child(som)
	som.set_process(false)
	som.ultimo_global = -100
	var tocador: AudioStreamPlayer3D = som._tocador
	conferir(tocador.stream != null and tocador.stream.get_length() > 1 and tocador.stream.get_length() < 3, "asset inválido")
	conferir(tocador.max_distance == 22 and tocador.unit_size == 3 and tocador.attenuation_model == AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE, "latido não atenua com distância")
	cao.position = Vector3(4, 0, 7)
	conferir(tocador.global_position.distance_to(cao.global_position) < 1, "som separado do cachorro")
	audio.definir_mudo("efeitos", false)
	audio.definir_volume_efeitos(0.8)
	conferir(not som._observar(10, true, false, false, 100), "latido sem aproximação")
	conferir(som._observar(4, true, false, false, 100), "aproximação não late")
	var pitch: float = tocador.pitch_scale
	if "--falsificar" in OS.get_cmdline_user_args():
		som._dentro = false
	conferir(not som._observar(4, true, false, false, 200), "repete sem novo encontro")
	som._observar(10, true, false, false, 101)
	conferir(not som._observar(4, true, false, false, 102), "não respeita intervalo")
	conferir(som._observar(4, true, false, false, 120), "novo encontro não late após intervalo")
	conferir(tocador.pitch_scale != pitch, "sem variação")
	var fala := Fala.new()
	root.add_child(fala)
	fala.add_to_group("fila_de_falas")
	conferir(som._fala_ocupa(), "fila não recebe prioridade")
	som._observar(10, true, false, true, 140)
	conferir(not som._observar(4, true, false, true, 140) and not tocador.playing, "latido disputa fala")
	conferir(not som._observar(4, true, true, false, 140), "cachorro dormindo late")
	conferir(not som._observar(4, false, false, false, 140), "cachorro distante/inativo late")
	audio.definir_volume_efeitos(0.2)
	conferir(is_equal_approx(tocador.volume_db, audio.volume_efeitos_db() - 8), "volume não segue ajuste")
	audio.definir_mudo("efeitos", true)
	conferir(not som._observar(4, true, false, false, 140) and not tocador.playing, "mute ignorado")
	cao.queue_free()
	fala.queue_free()
	await process_frame
	print("LATIDO_CARAMELO: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
