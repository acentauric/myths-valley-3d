extends SceneTree
## O marcador de lenha não termina na oficina quando os troncos acabam.
var falhas := 0
class RecursosEsgotados extends Node:
	func mais_perto_que_rende(_item: String, _de: Vector3) -> Vector3:
		return Vector3.INF

func _initialize() -> void:
	_run.call_deferred()

func conferir(ok: bool, texto: String) -> void:
	if not ok:
		print("FALHA: ", texto)
		falhas += 1

func _run() -> void:
	var arvores = load("res://scripts/prototipo_3d/arvores_info.gd").new()
	root.add_child(arvores)
	if not arvores.has_method("mais_perto_que_rende"):
		conferir(false, "árvores devem oferecer alvo de madeira quando os troncos acabam")
		arvores.free()
		quit(1)
		return
	arvores._madeiras = {"branca": {"rende": "lenha", "nivel": 1}, "lei": {"rende": "lenha", "nivel": 999}, "dura": {"rende": "lenha", "aco": true}}
	arvores._especies = {"dificil": {"madeira": "lei"}, "aco": {"madeira": "dura"}, "fibra": {"rende": "piacava"}}
	arvores._nao_se_corta = {"protegida": {"texto": "protegida"}}
	var cortaveis: Array[Dictionary] = [
		{"especie": "cortada", "pos": Vector3(1, 0, 0), "cortado": true},
		{"especie": "protegida", "pos": Vector3(2, 0, 0)},
		{"especie": "dificil", "pos": Vector3(3, 0, 0)},
		{"especie": "aco", "pos": Vector3(4, 0, 0)},
		{"especie": "fibra", "pos": Vector3(5, 0, 0)},
		{"especie": "comum", "pos": Vector3(6, 0, 0)},
		{"especie": "comum", "pos": Vector3(10, 0, 0)},
	]
	arvores._cortaveis = cortaveis
	conferir(arvores.mais_perto_que_rende("lenha", Vector3.ZERO) == Vector3(6, 0, 0), "selecionar árvore adulta acessível, excluindo protegidas, tocos, talento e aço")
	conferir(arvores.mais_perto_que_rende("lenha", Vector3(11, 0, 0)) == Vector3(10, 0, 0), "selecionar árvore acessível mais próxima")
	conferir(arvores.mais_perto_que_rende("tabua", Vector3.ZERO) == Vector3.INF, "tábuas continuam sendo receita, sem árvore falsa")
	arvores.add_to_group("arvores_do_vale")
	var cadeia = load("res://scripts/prototipo_3d/cadeia_de_missoes.gd").new()
	var jogador := Node3D.new()
	var recursos := RecursosEsgotados.new()
	root.add_child(jogador)
	root.add_child(cadeia)
	root.add_child(recursos)
	cadeia.jogador = jogador
	cadeia.recursos = recursos
	var passos: Array[Dictionary] = [{"id": "ponte_lenha", "lugar": "oficina", "meta": {"tipo": "juntar", "item": "lenha", "quantos": 36}}]
	cadeia.passos = passos
	conferir(cadeia.posicao_do_passo(0) == Vector3(6, 0, 0), "missão aponta árvore em vez da oficina após esgotar troncos")
	cadeia.passos[0]["meta"] = {"tipo": "juntar", "itens": {"tabua": 8, "lenha": 12}}
	conferir(cadeia.posicao_do_passo(0) == Vector3(6, 0, 0), "pedido composto busca matéria-prima faltante mesmo após receita sem alvo")
	arvores._jogador = jogador
	jogador.set_physics_process(true)
	arvores._em_golpe = 5
	conferir(bool(arvores.alvo_do_e().get("em_trabalho", false)), "oferta informa golpe em andamento para não cancelar a animação")
	arvores._em_golpe = -1
	cadeia.free()
	jogador.free()
	recursos.free()
	arvores._cortaveis[5]["cortado"] = true
	arvores._cortaveis[6]["cortado"] = true
	conferir(arvores.mais_perto_que_rende("lenha", Vector3.ZERO) == Vector3.INF, "esgotamento não oferece árvore impossível")
	arvores.free()
	print("ALVO_MADEIRA: ", falhas, " falhas")
	quit(1 if falhas else 0)
