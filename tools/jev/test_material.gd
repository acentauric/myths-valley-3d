extends "res://tools/jev/sessao.gd"
## A fonte extra observa o mundo e mantém o destino, sem conceder material.
var falhas := 0

class Cena extends Node3D:
	var player: Node3D

class Fonte extends Node:
	var pontos: Array[Vector3] = [Vector3(6, 0, 0), Vector3(10, 0, 0)]
	func mais_perto_que_rende(item: String, de: Vector3) -> Vector3:
		if item != "lenha":
			return Vector3.INF
		var perto := Vector3.INF
		for ponto in pontos:
			if not perto.is_finite() or ponto.distance_to(de) < perto.distance_to(de):
				perto = ponto
		return perto

func _initialize() -> void:
	_testar.call_deferred()

func _conferir(ok: bool, texto: String) -> void:
	if not ok:
		print("FALHA: ", texto)
		falhas += 1

func _testar() -> void:
	var cena := Cena.new()
	var jogador := Node3D.new()
	jogador.name = "player"
	cena.player = jogador
	cena.add_child(jogador)
	var fonte := Fonte.new()
	fonte.name = "Recursos3D"
	cena.add_child(fonte)
	root.add_child(cena)
	current_scene = cena
	var antes: Array = root.get_node("Inventario").espacos.duplicate(true)
	_conferir(_ponto_de_material("lenha") == Vector3(6, 0, 0), "observar fonte elegível mais próxima")
	jogador.position = Vector3(11, 0, 0)
	_conferir(_ponto_de_material("lenha") == Vector3(6, 0, 0), "movimento não alterna fonte durante aproximação")
	fonte.pontos.remove_at(0)
	_conferir(_ponto_de_material("lenha") == Vector3(10, 0, 0), "esgotamento da fonte permite próximo destino")
	_conferir(not _ponto_de_material("pedra").is_finite(), "não inventar fonte inexistente")
	_conferir(root.get_node("Inventario").espacos == antes, "observar fontes nunca concede material")
	cena.free()
	print("MATERIAL_TESTADOR: ", falhas, " falhas")
	quit(1 if falhas else 0)
