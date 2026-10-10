extends "res://tests/suite/caso.gd"
## AS ÁRVORES EM BLOCO ESMAECEM NA SESSÃO DE TESTE (10/10/2026): o mangue do rio, a mata, a
## restinga e os coqueiros da orla são instâncias de MultiMesh, e a copa na frente do viajante
## não esmaecia (`tools/jev/copas_do_teste.gd`). Num vale montado, com uma árvore de bloco
## entre a câmera e o viajante:
##   1. a instância sai do bloco e entra uma cópia avulsa, que esmaece;
##   2. com a árvore fora da frente, a cópia volta ao normal, sai, e a instância volta inteira;
##   3. cortada com a cópia na frente, a cópia sai na hora e a instância fica sumida.

const CopasDoTeste = preload("res://tools/jev/copas_do_teste.gd")

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: ", rotulo)


func _frames(quantos: int) -> void:
	for i in quantos:
		await process_frame


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await _frames(3)
	var cena := current_scene
	var regiao = cena.get("world").get("_region")
	var jogador: CharacterBody3D = cena.get("player")
	_conferir(regiao != null and jogador != null, "o vale tem região e viajante")
	if regiao == null or jogador == null:
		quit(1)
		return
	# Uma árvore de bloco (de pé, com instância registrada).
	var indice := -1
	for i in regiao._tree_trunks.size():
		var t: Dictionary = regiao._tree_trunks[i]
		if t.get("visual") is MultiMeshInstance3D and int(t.get("instancia", -1)) >= 0 and t.has("transformacao") and not bool(t.get("cortado", false)):
			indice = i
			break
	_conferir(indice >= 0, "o vale tem árvore em bloco")
	if indice < 0:
		quit(1)
		return
	var tronco: Dictionary = regiao._tree_trunks[indice]
	var visual: MultiMeshInstance3D = tronco["visual"]
	var copas = CopasDoTeste.new()
	copas.jogador = jogador
	root.add_child(copas)
	copas.set_process(false)
	var caixa: AABB = copas._caixa_do_tronco(visual, tronco)
	var centro := caixa.get_center()
	# O viajante de um lado da copa, a câmera do outro, na altura dela.
	var ponto := Vector3(centro.x + caixa.size.x, centro.y, centro.z)
	var camera := Vector3(centro.x - caixa.size.x, centro.y, centro.z)
	jogador.global_position = Vector3(ponto.x, jogador.global_position.y, ponto.z)
	copas._sondar_os_blocos(camera, [ponto])
	_conferir(copas._troncos.has(indice), "1. a árvore na frente sai do bloco")
	if copas._troncos.has(indice):
		var copia: MeshInstance3D = copas._troncos[indice]["copia"]
		_conferir(is_instance_valid(copia) and copia.mesh == visual.multimesh.mesh, "1. no lugar entra a cópia da mesma malha")
		_conferir(regiao._tree_trunks[indice]["transformacao"] == tronco["transformacao"], "1. o tronco guarda a transformação de antes")
		# Sem sondar de novo pela câmera de verdade: a frente é a desta montagem.
		copas._sonda_s = 999.0
		copas._process(1.0)
		_conferir(copia.transparency > 0.5, "1. a cópia esmaece (%.2f)" % copia.transparency)
		# 2. Fora da frente: a câmera ao lado do viajante.
		for _i in 3:
			if copas._troncos.has(indice):
				copas._troncos[indice]["frente"] = false
			copas._process(1.0)
		_conferir(not is_instance_valid(copia) or copia.is_queued_for_deletion(), "2. fora da frente, a cópia sai")
		var t2: Transform3D = visual.multimesh.get_instance_transform(int(tronco["instancia"])) if DisplayServer.get_name() != "headless" else regiao._tree_trunks[indice]["transformacao"]
		_conferir(t2.basis.get_scale().x > 0.01, "2. a instância volta inteira")
		_conferir(not copas._troncos.has(indice), "2. a árvore volta ao bloco")
	# 3. Cortada com a cópia na frente.
	copas._sondar_os_blocos(camera, [ponto])
	if copas._troncos.has(indice):
		var pe: Vector3 = regiao.to_global(Vector3(tronco["point"].x, float(tronco["ground"]), tronco["point"].y))
		_conferir(regiao.cortar_arvore(pe, false), "3. a árvore corta")
		copas._sondar_os_blocos(camera, [ponto])
		_conferir(not copas._troncos.has(indice), "3. cortada, a cópia sai na hora")
		var t3: Transform3D = regiao._tree_trunks[indice]["transformacao"]
		_conferir(t3.basis.get_scale().x < 0.01, "3. a instância da cortada fica sumida")
		regiao.restaurar_arvore(pe)
	copas.queue_free()
	print("COPAS_DO_TESTE_OK: a árvore em bloco esmaece na frente do viajante e volta ao bloco" if falhas == 0 else "copas_do_teste: Falhas: %d" % falhas)
	quit(1 if falhas else 0)
