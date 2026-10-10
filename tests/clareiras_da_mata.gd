extends "res://tests/suite/caso.gd"
## Confere AS CLAREIRAS-DESTAQUE DA MATA (data/mapas/clareiras_da_mata.json,
## GeoRegionRenderer.clareiras_da_mata, WorldBuilder._build_clareiras_da_mata).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste clareiras_da_mata
##
## A mata perdeu metade das árvores para aliviar o quadro, e no lugar ficaram
## clareiras isoladas. O que se cobra:
##
##   1. DEZ OU MAIS clareiras, cada uma com UMA árvore de espécie DIFERENTE no
##      centro (ou uma casa de taipa isolada), no modelo cheio e com colisão de
##      tronco, e nenhuma outra árvore da mata dentro dela nem em cima da trilha.
##   2. PEDRAS em volta, com colisão (2 a 6 por clareira).
##   3. O CHÃO PINTADO no mapa de solo: terra batida na trilha até a rua (e o
##      passo dela é de terra) e no descampado, ou folhiço.
##   4. LONGE DE TUDO que tem dono: o corredor do sobrevoo do menu, a vila, a
##      costa, os rios e as clareiras antigas.
##   5. O CACHE de `WorldBuilder.arvores()`: a mesma lista a cada chamada, e ela
##      se refaz quando uma árvore é cortada.

const MapaDeSolo = preload("res://scripts/prototipo_3d/mapa_de_solo.gd")
const Camada = MapaDeSolo.Camada
const DA_VILA := 20.0
const DA_COSTA := 30.0
const DO_RIO := 12.0
const DO_SOBREVOO := 60.0

var falhas := 0
var verificacoes := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_verificar(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(4)
	var vale := current_scene
	var mundo = vale.get("world") if vale != null else null
	var regiao = mundo.get("_region") if mundo != null else null
	_verificar(regiao != null, "o vale tem a região do mapa")
	if regiao == null:
		_fechar()
		return
	var clareiras: Array = regiao.clareiras_da_mata
	_verificar(clareiras.size() >= 10, "o mapa tem %d clareiras-destaque (esperado 10 ou mais)" % clareiras.size())
	_as_arvores_e_a_mata(mundo, regiao, clareiras)
	_as_pedras(mundo, clareiras)
	_o_chao(regiao, clareiras)
	_longe_de_tudo(regiao, clareiras)
	_o_cache(mundo)
	_fechar()


## UMA árvore por clareira, cada uma de uma espécie, e nada da mata ali.
func _as_arvores_e_a_mata(mundo, regiao, clareiras: Array) -> void:
	var especies := {}
	var casas := 0
	var nomeadas: Array = mundo.get("_arvores_nomeadas")
	for clareira: Dictionary in clareiras:
		var centro: Vector2 = clareira["centro"]
		var raio: float = clareira["raio"]
		var casa := String(clareira.get("casa", ""))
		if casa != "":
			casas += 1
			var corpo := _corpo_perto(mundo, casa.capitalize() + "Colisao", centro, 3.0)
			_verificar(corpo != null, "a casa %s está no centro da clareira %s, com colisão" % [casa, str(centro)])
			if corpo != null:
				_verificar(corpo.get_child_count() > 0, "a casa da clareira %s tem forma de colisão" % str(centro))
		else:
			var especie := String(clareira["especie"])
			_verificar(not especies.has(especie), "a espécie %s se repete em outra clareira" % especie)
			especies[especie] = true
			var achada := {}
			for arvore: Dictionary in nomeadas:
				var pe: Vector3 = arvore["pos"]
				if String(arvore["especie"]) == especie and Vector2(pe.x, pe.z).distance_to(centro) < 1.5:
					achada = arvore
			_verificar(not achada.is_empty(), "a árvore-destaque %s está no centro da clareira %s" % [especie, str(centro)])
			if not achada.is_empty():
				_verificar(is_instance_valid(achada.get("colisao")), "%s da clareira %s tem colisão de tronco" % [especie, str(centro)])
				_verificar(is_instance_valid(achada.get("visual")), "%s da clareira %s tem o modelo" % [especie, str(centro)])
		# Nenhuma outra árvore (mata, orla, paisagismo, nomeada) dentro do descampado.
		var dentro := 0
		for tronco: Dictionary in regiao._tree_trunks:
			if (tronco["point"] as Vector2).distance_to(centro) < raio:
				dentro += 1
		for arvore: Dictionary in nomeadas:
			var pe: Vector3 = arvore["pos"]
			if Vector2(pe.x, pe.z).distance_to(centro) < raio and Vector2(pe.x, pe.z).distance_to(centro) > 1.5:
				dentro += 1
		_verificar(dentro == 0, "%d árvore(s) a mais dentro da clareira %s" % [dentro, str(centro)])
		# E nenhuma em cima da trilha.
		var na_trilha := 0
		var trilha: PackedVector2Array = clareira["trilha"]
		for tronco: Dictionary in regiao._tree_trunks:
			var ponto: Vector2 = tronco["point"]
			if (clareira["caixa_trilha"] as Rect2).has_point(ponto) and regiao._distance_to_line(ponto, trilha) < regiao.MEIA_LARGURA_DA_TRILHA + float(tronco["radius"]):
				na_trilha += 1
		_verificar(na_trilha == 0, "%d tronco(s) em cima da trilha da clareira %s" % [na_trilha, str(centro)])
	_verificar(especies.size() >= 8, "as clareiras de árvore têm %d espécies diferentes" % especies.size())
	print("clareiras: %d de árvore (%s) e %d de casa" % [especies.size(), ", ".join(especies.keys()), casas])


## Pedras: 2 a 6 por clareira, com colisão de caixa.
func _as_pedras(mundo, clareiras: Array) -> void:
	for clareira: Dictionary in clareiras:
		var centro: Vector2 = clareira["centro"]
		var pedras: Array = clareira["pedras"]
		_verificar(pedras.size() >= 2 and pedras.size() <= 6, "a clareira %s tem %d pedras (esperado 2 a 6)" % [str(centro), pedras.size()])
		var com_colisao := 0
		for pedra: Dictionary in pedras:
			var onde := centro + Vector2(float(pedra["dx"]), float(pedra["dz"]))
			var nome := String(pedra["tipo"]).capitalize() + "Colisao"
			if _corpo_perto(mundo, nome, onde, 4.0) != null:
				com_colisao += 1
		_verificar(com_colisao == pedras.size(), "pedras com colisão na clareira %s: %d de %d" % [str(centro), com_colisao, pedras.size()])


## O chão: a trilha é terra (no mapa e no passo), e o descampado tem o chão dele.
func _o_chao(regiao, clareiras: Array) -> void:
	var solo = regiao.get("solo")
	_verificar(solo != null and solo.pronto(), "o mapa de solo está pronto")
	if solo == null or not solo.pronto():
		return
	for clareira: Dictionary in clareiras:
		var centro: Vector2 = clareira["centro"]
		var raio: float = clareira["raio"]
		var trilha: PackedVector2Array = clareira["trilha"]
		_verificar(trilha.size() >= 4, "a clareira %s tem trilha (%d pontos)" % [str(centro), trilha.size()])
		# A trilha acaba na rua: a ponta dela encosta no eixo de alguma.
		var rua: Vector2 = regiao._ponto_mais_perto_das_ruas(trilha[0], 6.0)
		_verificar(rua.is_finite(), "a trilha da clareira %s começa na rua" % str(centro))
		var medidos := 0
		var de_terra := 0
		var passo_de_terra := 0
		# O meio da trilha, longe do halo da rua (4 u) e do descampado (raio).
		for i in trilha.size() - 1:
			for passo in 4:
				var ponto := trilha[i].lerp(trilha[i + 1], float(passo) / 4.0)
				var dist_rua: float = regiao._distancia_da_rua(ponto)
				if dist_rua > 5.0 and ponto.distance_to(centro) > raio * 0.8:
					medidos += 1
					if solo.peso(Camada.TERRA, ponto) >= 0.5:
						de_terra += 1
					if regiao.surface_at(Vector3(ponto.x, 0.0, ponto.y)) == "terra":
						passo_de_terra += 1
		if medidos > 0:
			_verificar(de_terra >= medidos * 0.93, "a trilha da clareira %s é terra em %d de %d pontos" % [str(centro), de_terra, medidos])
			_verificar(passo_de_terra >= medidos * 0.93, "o passo na trilha da clareira %s é de terra em %d de %d pontos" % [str(centro), passo_de_terra, medidos])
		# O descampado: de "terra", terra no meio da clareira (longe da árvore e das
		# pedras não importa: o miolo do anel); "folhico", folhiço no mesmo lugar.
		var ponto_do_chao := centro + Vector2(raio * 0.4, 0.0).rotated(float(clareira["giro"]))
		if String(clareira["chao"]) == "terra":
			_verificar(solo.peso(Camada.TERRA, centro + Vector2(raio * 0.2, 0.0)) >= 0.6, "o descampado de terra da clareira %s é terra (%.2f)" % [str(centro), solo.peso(Camada.TERRA, centro + Vector2(raio * 0.2, 0.0))])
		else:
			_verificar(solo.peso(Camada.COPA, ponto_do_chao) >= 0.5, "o folhiço da clareira %s é folhiço (%.2f)" % [str(centro), solo.peso(Camada.COPA, ponto_do_chao)])


## Longe da vila, da costa, dos rios, das clareiras antigas e do corredor do voo do menu.
func _longe_de_tudo(regiao, clareiras: Array) -> void:
	var voo: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/sobrevoo_menu.json"))
	var olho := PackedVector2Array()
	for amostra in voo["olho"]:
		olho.append(Vector2(float(amostra[0]), float(amostra[2])))
	var aberto: Array[PackedVector2Array] = []
	for clareira: Dictionary in clareiras:
		var centro: Vector2 = clareira["centro"]
		var raio: float = clareira["raio"]
		_verificar(Geometry2D.is_point_in_polygon(centro, regiao._land), "a clareira %s está em terra" % str(centro))
		var mata_ok: bool = (regiao._forest.size() >= 3 and Geometry2D.is_point_in_polygon(centro, regiao._forest)) \
			or (regiao._kml_forest.size() >= 3 and Geometry2D.is_point_in_polygon(centro, regiao._kml_forest))
		_verificar(mata_ok, "a clareira %s está dentro da mata" % str(centro))
		_verificar(regiao._distance_to_line(centro, olho) >= DO_SOBREVOO + raio, "a clareira %s está a %.0f u do corredor do sobrevoo" % [str(centro), regiao._distance_to_line(centro, olho)])
		_verificar(regiao._distance_to_line(centro, regiao._coast) >= DA_COSTA + raio, "a clareira %s está a %.0f u da costa" % [str(centro), regiao._distance_to_line(centro, regiao._coast)])
		var d_rio := INF
		for rio: Dictionary in regiao._rivers:
			d_rio = minf(d_rio, regiao._distance_to_line(centro, rio.points))
		_verificar(d_rio >= DO_RIO + raio, "a clareira %s está a %.0f u de um rio" % [str(centro), d_rio])
		if regiao._village.size() >= 3:
			var na_vila := Geometry2D.is_point_in_polygon(centro, regiao._village) and not Geometry2D.is_point_in_polygon(centro, regiao._kml_forest)
			_verificar(not na_vila, "a clareira %s cai dentro da vila" % str(centro))
		for velha: Vector2 in regiao.clareiras:
			_verificar(centro.distance_to(velha) >= raio + regiao.RAIO_DAS_CLAREIRAS + 10.0, "a clareira %s encosta numa clareira antiga %s" % [str(centro), str(velha)])
		for outra: Dictionary in clareiras:
			if outra != clareira:
				_verificar(centro.distance_to(outra["centro"]) >= raio + float(outra["raio"]) + 10.0, "a clareira %s encosta na clareira %s" % [str(centro), str(outra["centro"])])
		# O chão é manso: a diferença de altura entre o centro e a borda.
		var h0: float = regiao.ground_height_at(Vector3(centro.x, 0.0, centro.y))
		var pior := 0.0
		for k in 12:
			var ponto := centro + Vector2.from_angle(TAU * float(k) / 12.0) * raio
			pior = maxf(pior, absf(regiao.ground_height_at(Vector3(ponto.x, 0.0, ponto.y)) - h0))
		_verificar(pior / raio <= 0.4, "o chão da clareira %s é torto: %.2f u de desnível em %.0f u de raio" % [str(centro), pior, raio])


## O cache de `arvores()`: a mesma lista a cada chamada, refeita depois de um corte.
func _o_cache(mundo) -> void:
	var primeira: Array = mundo.arvores()
	var segunda: Array = mundo.arvores()
	_verificar(primeira.size() > 1000, "o mundo tem %d árvores na lista" % primeira.size())
	_verificar(is_same(primeira, segunda), "arvores() devolve a mesma lista (cache) a cada chamada")
	var nomeada := {}
	for arvore: Dictionary in mundo.get("_arvores_nomeadas"):
		if arvore.get("visual") != null and not bool(arvore.get("cortado", false)):
			nomeada = arvore
			break
	_verificar(not nomeada.is_empty(), "há uma árvore nomeada para o corte")
	if nomeada.is_empty():
		return
	var pe: Vector3 = nomeada["pos"]
	_verificar(mundo.cortar_arvore(pe, false), "a árvore nomeada se corta")
	var depois: Array = mundo.arvores()
	_verificar(not is_same(primeira, depois), "o corte invalida o cache de arvores()")
	_verificar(depois.size() == primeira.size(), "o corte não muda quantas árvores a lista tem (%d e %d)" % [primeira.size(), depois.size()])
	_verificar(mundo.restaurar_arvore(pe), "a árvore volta")
	_verificar(not is_same(mundo.arvores(), depois), "a restauração invalida o cache de arvores()")


## O corpo de colisão em caixa (pedra, casa) mais perto de `onde` (plano XZ), até
## `ate` u; null se nenhum. Pela forma e não pelo nome: o Godot renomeia os
## corpos repetidos ("@PedrasColisao@5").
func _corpo_perto(mundo, _nome: String, onde: Vector2, ate: float) -> StaticBody3D:
	var melhor: StaticBody3D = null
	var menor := ate
	for filho in mundo.get_children():
		var corpo := filho as StaticBody3D
		if corpo == null or corpo.get_child_count() == 0 or not (corpo.get_child(0) is CollisionShape3D):
			continue
		if not ((corpo.get_child(0) as CollisionShape3D).shape is BoxShape3D):
			continue
		var d := Vector2(corpo.position.x, corpo.position.z).distance_to(onde)
		if d < menor:
			menor = d
			melhor = corpo
	return melhor


func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame


func _frames(quantos: int) -> void:
	for i in quantos:
		await process_frame


func _verificar(condicao: bool, descricao: String) -> void:
	verificacoes += 1
	if not condicao:
		falhas += 1
		print("FALHA: ", descricao)
		push_error("CLAREIRAS_DA_MATA_FALHOU: " + descricao)


func _fechar() -> void:
	if falhas == 0:
		print("CLAREIRAS_DA_MATA_OK: %d verificações — uma árvore (ou casa) por clareira, espécies diferentes, pedras com colisão, trilha de terra até a rua, longe do sobrevoo, da costa, dos rios e da vila; cache de arvores()" % verificacoes)
	else:
		print("clareiras_da_mata: %d falha(s) em %d verificações" % [falhas, verificacoes])
	quit(1 if falhas > 0 else 0)
