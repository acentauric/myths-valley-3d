extends "res://tests/suite/caso.gd"
## Confere que A CANOA É SÓLIDA NA MEDIDA DO DESENHO — e que quem pula nela fica
## dentro.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste canoas
##
## "Precisa corrigir a área de colisão dos barcos também. Pulei neles e
## atravessei a parede." A colisão eram caixas finas medidas como fração da
## caixa do modelo: o costado de colisão acabava abaixo da borda que se vê, e a
## proa e a popa não tinham colisão. Três perguntas, para cada canoa fundeada:
##
##   1. POR FORA, O CASCO É PAREDE: raios deitados de fora para dentro, na
##      altura da linha d'água — onde todo casco tem parede, e o toldo do bote
##      não confunde —, batem no corpo da canoa no costado e nas pontas, e não
##      passam até o meio dela.
##   2. POR DENTRO, TAMBÉM: os mesmos raios, do meio para fora, batem no costado.
##   3. QUEM PULA NELA FICA DENTRO: o jogador solto de cima, no meio da canoa,
##      para entre os costados e acima do fundo; e andando contra o costado por
##      um segundo e meio de passos de física, não sai.
##
## A boca e o comprimento vêm da MALHA do casco (os vértices da faixa da linha
## d'água), e não da colisão: medir a colisão por ela mesma não pegaria colisão
## errada.

## A altura dos raios, no referencial da canoa (a origem dela é a superfície da
## água): um palmo acima da linha d'água.
const NA_AGUA := 0.15

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("CANOAS_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	var vale = current_scene
	var jogador = vale.player
	var mundo = vale.world
	var frota: Node = mundo.get_node_or_null("Canoas")
	_conferir(frota != null and frota.get_child_count() > 0, "o vale não fundeou canoa nenhuma")
	if frota == null:
		_fechar()
		return
	root.get_node("/root/Dia").pausado = true
	var espaco: PhysicsDirectSpaceState3D = mundo.get_world_3d().direct_space_state
	var conferidas := 0
	for canoa: Node3D in frota.get_children():
		var corpo := canoa.find_child("Colisão da canoa", true, false) as CollisionObject3D
		_conferir(corpo != null, "a canoa '%s' não tem corpo" % canoa.name)
		if corpo == null:
			continue
		var medida := _medida_do_desenho(canoa, corpo)
		if medida.is_empty():
			_conferir(false, "a canoa '%s' não tem malha para medir" % canoa.name)
			continue
		conferidas += 1
		var boca: float = medida["boca"]
		var meio_comprimento: float = medida["comprimento"]
		var altura := NA_AGUA
		# --- 1. POR FORA ---------------------------------------------------------
		# O costado em duas alturas: na linha d'água e UM PALMO ABAIXO DA BORDA
		# QUE SE VÊ — era ali a queixa: o costado de colisão de antes acabava
		# meio metro abaixo da borda desenhada, e o pulo passava por cima dele e
		# através do desenho. As pontas, na linha d'água: a proa sobe e afina.
		var alturas_do_costado := [altura, float(medida["borda"]) - 0.12]
		for lado: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
			var onde := "costado" if lado.x == 0.0 else "ponta"
			for na_altura: float in (alturas_do_costado if lado.x == 0.0 else [altura]):
				var longe := (boca if lado.x == 0.0 else meio_comprimento) + 1.2
				var de := Vector3(lado.x * longe, na_altura, lado.z * longe)
				var ate := Vector3(0.0, na_altura, 0.0)
				var toque := _raio(espaco, canoa, de, ate, corpo)
				_conferir(toque.is_finite(), "na canoa '%s', o raio de fora pelo %s a %.2f da água não bate em nada: atravessa o casco" % [canoa.name, onde, na_altura])
				if toque.is_finite():
					var ate_o_meio := absf(toque.dot(lado))
					var parede := (boca if lado.x == 0.0 else meio_comprimento)
					_conferir(ate_o_meio > parede * 0.45, "na canoa '%s', o raio de fora pelo %s a %.2f da água bate a %.2f do meio, e a parede desenhada fica a %.2f" % [canoa.name, onde, na_altura, ate_o_meio, parede])
		# --- 2. POR DENTRO -------------------------------------------------------
		for lado: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1)]:
			for na_altura: float in alturas_do_costado:
				var de := Vector3(0.0, na_altura, 0.0)
				var ate := Vector3(0.0, na_altura, lado.z * (boca + 1.2))
				_conferir(_raio(espaco, canoa, de, ate, corpo).is_finite(), "na canoa '%s', de dentro o costado não segura a %.2f da água: o raio sai pelo lado" % [canoa.name, na_altura])
		_conferir(conferidas > 0, "nenhuma canoa medida")

	# --- 3. QUEM PULA NELA FICA DENTRO ------------------------------------------
	# Numa canoa sem toldo: no bote, quem pula de cima para no toldo, e é certo.
	var canoa: Node3D = null
	for candidata: Node3D in frota.get_children():
		if candidata.find_child("BoteTripo", false, false) == null:
			canoa = candidata
			break
	var corpo := canoa.find_child("Colisão da canoa", true, false) as CollisionObject3D if canoa != null else null
	var medida := _medida_do_desenho(canoa, corpo) if corpo != null else {}
	if not medida.is_empty():
		var borda: float = medida["borda"]
		var boca: float = medida["boca"]
		jogador.teleportar(canoa.to_global(Vector3(0.0, borda + 1.4, 0.0)), canoa.global_rotation.y)
		await _passos(150)
		var dentro: Vector3 = canoa.to_local(jogador.global_position)
		_conferir(absf(dentro.z) < boca and absf(dentro.x) < float(medida["comprimento"]), "quem pulou na canoa caiu fora dela: %s" % str(dentro))
		_conferir(dentro.y > float(medida["fundo"]) - 0.05, "quem pulou na canoa atravessou o fundo: %.2f, e o fundo é %.2f" % [dentro.y, float(medida["fundo"])])
		print("  pulou na canoa e parou em %s (borda %.2f, boca %.2f)" % [str(dentro), borda, boca])
		# Andando contra o costado: de frente para o +Z da canoa.
		var para_o_costado: Vector3 = canoa.global_transform.basis.z.normalized()
		jogador.teleportar(canoa.to_global(Vector3(0.0, maxf(dentro.y, float(medida["fundo"])) + 0.05, 0.0)), atan2(-para_o_costado.x, -para_o_costado.z) - PI)
		await _passos(4)
		Input.action_press("mv_forward")
		await _passos(90)
		Input.action_release("mv_forward")
		await _passos(4)
		var depois: Vector3 = canoa.to_local(jogador.global_position)
		_conferir(absf(depois.z) < boca + 0.05 or depois.y > borda, "andando contra o costado, o jogador atravessou a parede da canoa: %s (boca %.2f)" % [str(depois), boca])
		print("  andou contra o costado e ficou em %s" % str(depois))
	_fechar()


## A medida da canoa pelo DESENHO, no referencial dela (comprimento no X, boca
## no Z, a origem na superfície da água): a boca e meio comprimento na faixa da
## linha d'água, só casco; a borda no meio do comprimento (os vértices a menos
## de 0,4 do meio, abaixo de 1,2 — o toldo do bote fica acima); e o fundo, os
## vértices perto do eixo.
func _medida_do_desenho(canoa: Node3D, corpo: Node) -> Dictionary:
	var borda := -INF
	var boca := 0.0
	var fundo := INF
	var comprimento := 0.0
	var achou := false
	for no in canoa.find_children("*", "MeshInstance3D", true, false):
		var malha := no as MeshInstance3D
		if malha.mesh == null or corpo.is_ancestor_of(malha):
			continue
		var para_a_canoa: Transform3D = canoa.global_transform.affine_inverse() * malha.global_transform
		for superficie in malha.mesh.get_surface_count():
			var vertices = malha.mesh.surface_get_arrays(superficie)[Mesh.ARRAY_VERTEX]
			if not (vertices is PackedVector3Array):
				continue
			for vertice in (vertices as PackedVector3Array):
				var p: Vector3 = para_a_canoa * vertice
				achou = true
				if p.y > -0.05 and p.y < 0.35:
					comprimento = maxf(comprimento, absf(p.x))
					if absf(p.x) < 0.4:
						boca = maxf(boca, absf(p.z))
				if absf(p.x) < 0.4:
					if p.y < 1.2:
						borda = maxf(borda, p.y)
					if absf(p.z) < 0.15:
						fundo = minf(fundo, p.y)
	if not achou or not is_finite(borda):
		return {}
	return {"borda": borda, "boca": boca, "fundo": fundo, "comprimento": comprimento}


## Um raio de `de` até `ate`, no referencial da canoa; devolve onde bateu NO
## CORPO DA CANOA (no referencial dela), ou INF.
func _raio(espaco: PhysicsDirectSpaceState3D, canoa: Node3D, de: Vector3, ate: Vector3, corpo: CollisionObject3D) -> Vector3:
	# Na camada dos corpos: a água tem uma lâmina só da câmera, um plano sem fim
	# na camada dela, e o raio deitado de uma canoa que balança cruza com ele.
	var pergunta := PhysicsRayQueryParameters3D.create(canoa.to_global(de), canoa.to_global(ate), corpo.collision_layer)
	pergunta.hit_back_faces = true
	var toque := espaco.intersect_ray(pergunta)
	if toque.is_empty() or toque.get("collider") != corpo:
		return Vector3.INF
	return canoa.to_local(toque["position"])


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("CANOAS_OK: cada canoa é parede por fora e por dentro na medida do desenho, no costado e nas pontas, e quem pula nela fica dentro, sem atravessar o fundo nem o costado")
	else:
		print("canoas: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _passos(n: int) -> void:
	for i in n:
		await physics_frame


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
