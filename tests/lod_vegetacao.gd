extends SceneTree
## O LOD precisa cortar blocos no passeio sem apagar a vegetação no mapa alto.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var regiao: Node3D = (load("res://scripts/prototipo_3d/geo_region_renderer.gd") as GDScript).new()
	root.add_child(regiao)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	var posicoes: Array[Transform3D] = [Transform3D.IDENTITY]
	regiao.call("_multimesh_em_blocos", "Teste", BoxMesh.new(), posicoes, 85.0)
	regiao.call("_multimesh_em_blocos", "Decalque", PlaneMesh.new(), posicoes)
	var visual := regiao.get_child(0) as MultiMeshInstance3D
	var decalque := regiao.get_child(1) as MultiMeshInstance3D
	_verificar(visual != null, "bloco da vegetação foi criado")
	_verificar(decalque != null and decalque.visibility_range_end == 0.0, "decalque no pé da árvore não recebe LOD")
	if visual != null:
		_verificar(visual.visibility_range_end == 85.0, "passeio usa corte por distância")
		_verificar(visual.lod_bias < 1.0, "LOD importado entra mais cedo")
		_verificar(visual.visibility_range_fade_mode == GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED, "corte sem custo de desvanecimento")
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		await _frames(3)
		_verificar(visual.visibility_range_end == 0.0, "mapa alto mostra toda a vegetação")
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		await _frames(3)
		_verificar(visual.visibility_range_end == 85.0, "volta ao passeio restaura o LOD")
		regiao.call("_clear_region")
		_verificar((regiao.get("_blocos_vegetacao_lod") as Array).is_empty(), "reconstrução descarta blocos antigos")
		regiao.call("_multimesh_em_blocos", "Nova mata", BoxMesh.new(), posicoes, 85.0)
		await _frames(3)
		var novo_visual := regiao.get_child(0) as MultiMeshInstance3D
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		await _frames(3)
		_verificar(novo_visual.visibility_range_end == 0.0, "mapa funciona após reconstruir região")
	print("LOD_VEGETACAO_OK: passeio, mapa, retorno e reconstrução" if falhas == 0 else "lod_vegetacao: Falhas: %d" % falhas)
	quit(1 if falhas else 0)


func _frames(count: int) -> void:
	for i in range(count):
		await process_frame


func _verificar(condicao: bool, descricao: String) -> void:
	if not condicao:
		falhas += 1
		push_error("FALHOU: " + descricao)
