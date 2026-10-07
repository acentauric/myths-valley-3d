extends "res://tools/jev/sessao.gd"
## Aproximar o guia parado deve comprovar que E conversa com ele.
class Dono extends RefCounted:
	var alvo: Node3D
	func perto() -> Node3D:
		return alvo
class Foco extends RefCounted:
	var atual: Dono
	func dono() -> Dono:
		return atual
class Cena extends Node3D:
	var foco_do_e: Foco
class Jogada extends RefCounted:
	func virar_para(_ponto: Vector3) -> void:
		pass

func _initialize() -> void:
	_conferir_guia.call_deferred()

func _conferir_guia() -> void:
	var cena := Cena.new()
	root.add_child(cena)
	current_scene = cena
	var alvo := Node3D.new()
	cena.add_child(alvo)
	cena.foco_do_e = Foco.new()
	cena.foco_do_e.atual = Dono.new()
	cena.foco_do_e.atual.alvo = alvo
	jogada = Jogada.new()
	var resultado := await _conferir_chegada(alvo, Vector3.ZERO, true)
	var ok := resultado == "arrived_with_correct_E_target"
	print("AUTOPLAYER_GUIA: %d falha(s)" % (0 if ok else 1))
	quit(0 if ok else 1)
