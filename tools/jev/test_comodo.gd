extends "res://tools/jev/sessao.gd"
## #191: dentro de um cômodo o estado diz quais destinos ficam do lado de fora, e o
## Pedro só vira alvo de "seguir" enquanto conduz.
class Sala extends Node3D:
	func contem(ponto: Vector3, mais: float = 0.0) -> bool:
		return absf(ponto.x) <= 2.0 + mais and absf(ponto.z) <= 2.0 + mais

	func soleira_de_dentro() -> Vector3:
		return Vector3(0, 0, 1.5)

	func soleira_de_fora() -> Vector3:
		return Vector3(0, 0, 3.0)


class Interiores extends RefCounted:
	var sala: Sala

	func sala_de(_qual: String) -> Sala:
		return sala


class Cena extends Node3D:
	var interiores: Interiores


class FalsoPedro extends Node3D:
	var terminou := false
	var conduzindo: Node = null

	func terminou_o_tutorial() -> bool:
		return terminou

	func _outra_que_conduz() -> Node:
		return conduzindo


func _initialize() -> void:
	_conferir_comodo.call_deferred()


func _conferir_comodo() -> void:
	var cena := Cena.new()
	root.add_child(cena)
	current_scene = cena
	var sala := Sala.new()
	cena.add_child(sala)
	var interiores := Interiores.new()
	interiores.sala = sala
	cena.interiores = interiores
	var falhas := 0

	var dentro := Node3D.new()
	dentro.position = Vector3(1, 0, -1)
	var fora := Node3D.new()
	fora.position = Vector3(10, 0, 0)
	cena.add_child(dentro)
	cena.add_child(fora)
	catalogo = {"objective": Vector3(8, 0, 8), "approach_bed": Vector3(1, 0, 0), "approach_Tonho": fora,
		"approach_cozinheira": dentro, "exit_home": sala, "explore_Praia": Vector3(-30, 0, 4)}
	var opcoes := {}
	for id in catalogo:
		opcoes[id] = "x"
	var estado := {"interior": "casa"}
	_marcar_alvos_fora_do_comodo(estado, opcoes)
	var fora_do_comodo: Array = estado.get("room", {}).get("outside_targets", [])
	fora_do_comodo.sort()
	if fora_do_comodo != ["approach_Tonho", "explore_Praia", "objective"]:
		push_error("Fora do cômodo: objetivo, Tonho e a praia; dentro: cama e cozinheira. Veio %s" % [fora_do_comodo])
		falhas += 1

	var sem_comodo := {"interior": ""}
	_marcar_alvos_fora_do_comodo(sem_comodo, opcoes)
	if sem_comodo.has("room"):
		push_error("Fora de qualquer cômodo não há regra de porta")
		falhas += 1

	var pedro := FalsoPedro.new()
	cena.add_child(pedro)
	if not _guia_conduz(pedro):
		push_error("Durante o tutorial o Pedro conduz")
		falhas += 1
	pedro.terminou = true
	if _guia_conduz(pedro):
		push_error("Acabado o tutorial, sem fila que conduza, o Pedro não conduz mais")
		falhas += 1
	pedro.conduzindo = Node.new()
	if not _guia_conduz(pedro):
		push_error("Depois do tutorial ele ainda conduz quando uma fila pede (a jornada da fazenda)")
		falhas += 1
	pedro.conduzindo.free()

	print("AUTOPLAYER_COMODO: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
