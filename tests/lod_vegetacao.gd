extends "res://tests/suite/caso.gd"
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
		if "--sem-corte" in OS.get_cmdline_user_args(): visual.visibility_range_end = 0.0
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
	await _copas_distantes(regiao, camera)
	print("LOD_VEGETACAO_OK: passeio, mapa, retorno, reconstrução e copas de longe" if falhas == 0 else "lod_vegetacao: Falhas: %d" % falhas)
	if falhas > 0:
		print("FALHA: lod_vegetacao com %d falha(s)" % falhas)
	quit(1 if falhas else 0)


func _frames(count: int) -> void:
	for i in range(count):
		await process_frame


func _verificar(condicao: bool, descricao: String) -> void:
	if not condicao:
		falhas += 1
		push_error("FALHOU: " + descricao)


## A COPA DISTANTE: o bloco de árvores que some a `distancia` tem um irmão com
## uma copa low-poly por tronco, que entra exatamente onde a árvore sai.
func _copas_distantes(regiao: Node3D, camera: Camera3D) -> void:
	const Copas := preload("res://scripts/prototipo_3d/copas_distantes.gd")
	regiao.call("_clear_region")
	# Nomes: só bloco de árvore com tronco ganha copa (sub-bosque e decalque não).
	_verificar(Copas.especie_do_bloco("Mata: jatoba") == "jatoba", "a copa sabe a espécie do bloco da mata")
	_verificar(Copas.especie_do_bloco("Coqueiros da orla") == "coqueiro", "a copa sabe o coqueiro da orla")
	_verificar(Copas.especie_do_bloco("Manguezal") == "mangue", "a copa sabe o mangue")
	_verificar(Copas.especie_do_bloco("Restinga da orla: piacava") == "piacava", "a copa sabe a restinga")
	_verificar(Copas.especie_do_bloco("Sub-bosque") == "" and Copas.especie_do_bloco("Decalque") == "", "sub-bosque e decalque não ganham copa")
	# Orçamento: ~64 triângulos por copa.
	var triangulos: int = Copas.triangulos_por_copa()
	_verificar(triangulos >= 48 and triangulos <= 80, "a copa tem uns 64 triângulos (tem %d)" % triangulos)
	# A cor da espécie casa com o verde que o chão pinta ao longe.
	for especie in Copas.CORES.keys():
		var cor: Color = Copas.cor_da_especie(String(especie))
		var longe := Vector3(cor.r - Copas.COR_DO_CHAO.r, cor.g - Copas.COR_DO_CHAO.g, cor.b - Copas.COR_DO_CHAO.b).length()
		_verificar(cor.g > cor.r and cor.g > cor.b and longe < 0.2, "a cor da copa de %s é verde-copa e perto da do chão (%.2f)" % [especie, longe])
	# O bloco de longe: mesma distância e margem da árvore, sem fade, até 1.200 u.
	var posicoes: Array[Transform3D] = []
	var registros: Array[int] = []
	var troncos: Array = regiao.get("_tree_trunks")
	for i in range(3):
		posicoes.append(Transform3D(Basis(), Vector3(5.0 + i, 0.0, 5.0)))
		troncos.append({"point": Vector2(5.0 + i, 5.0), "ground": 0.0, "height": 3.0, "radius": 0.3, "especie": "jatoba", "transformacao": posicoes[i]})
		registros.append(troncos.size() - 1)
	var arvore := BoxMesh.new()
	arvore.size = Vector3(4.0, 10.0, 4.0)
	regiao.call("_multimesh_em_blocos", "Mata: jatoba", arvore, posicoes, 280.0, registros)
	regiao.call("_multimesh_em_blocos", "Sub-bosque", arvore, posicoes, 85.0)
	var copas: Array[MultiMeshInstance3D] = []
	var visual_da_arvore: MultiMeshInstance3D = null
	for filho in regiao.get_children():
		if (filho as Node).name.begins_with(Copas.NOME):
			copas.append(filho as MultiMeshInstance3D)
		elif filho is MultiMeshInstance3D and (filho as Node).name.begins_with("Mata: jatoba"):
			visual_da_arvore = filho as MultiMeshInstance3D
	_verificar(copas.size() == 1, "um bloco de copas para um bloco de árvores, e nenhum para o sub-bosque (%d)" % copas.size())
	if copas.size() == 1 and visual_da_arvore != null:
		var copa := copas[0]
		_verificar(copa.visibility_range_begin == visual_da_arvore.visibility_range_end, "a copa entra onde a árvore sai (%.0f e %.0f)" % [copa.visibility_range_begin, visual_da_arvore.visibility_range_end])
		_verificar(copa.visibility_range_begin_margin == visual_da_arvore.visibility_range_end_margin, "a copa tem a mesma margem da árvore")
		_verificar(copa.visibility_range_fade_mode == GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED, "troca sem desvanecer")
		_verificar(copa.visibility_range_end == Copas.FIM, "a copa vai até %.0f u" % Copas.FIM)
		_verificar(copa.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "a copa de longe não faz sombra")
		_verificar(copa.multimesh.instance_count == visual_da_arvore.multimesh.instance_count, "uma copa para cada tronco")
		# O tronco guarda a copa: o corte, o crescimento e a restauração a movem.
		var com_copa := 0
		for indice in registros:
			var tronco: Dictionary = (regiao.get("_tree_trunks") as Array)[indice]
			var longe: Array = tronco.get("longe", [])
			if longe.size() == 1 and (longe[0] as Dictionary)["visual"] == copa and (longe[0] as Dictionary).has("forma"):
				com_copa += 1
		_verificar(com_copa == 3, "cada tronco guarda a sua copa (%d de 3)" % com_copa)
		# No mapa alto as copas se escondem (a árvore de verdade aparece).
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		await _frames(3)
		_verificar(not copa.visible, "mapa alto esconde as copas de longe")
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		await _frames(3)
		_verificar(copa.visible, "a volta ao passeio mostra as copas")
	# A reconstrução leva as copas junto.
	regiao.call("_clear_region")
	await _frames(3)
	var sobrou := 0
	for filho in regiao.get_children():
		if not (filho as Node).is_queued_for_deletion():
			sobrou += 1
	_verificar(sobrou == 0, "reconstruir a região descarta as copas (%d filhos)" % sobrou)
	await _modelo_de_longe(regiao)


## A palmeira e o ingá têm o modelo de longe do Tripo de `distancia` a 600 u, e a
## copa low-poly entra onde ele sai; o jatobá (sem modelo de longe) fica só com a copa.
func _modelo_de_longe(regiao: Node3D) -> void:
	const Copas := preload("res://scripts/prototipo_3d/copas_distantes.gd")
	var conferidas := 0
	for especie in ["piacava", "dendezeiro", "coqueiro"]:
		var da_arvore: Dictionary = CatalogoAssets.malha(especie + "_leve", 1.0) if especie != "coqueiro" else CatalogoAssets.malha(especie, 1.0)
		if da_arvore.is_empty() or not CatalogoAssets.tem_tripo(especie + "_longe"):
			continue
		var t := Transform3D(Basis(), Vector3(7.0, 0.0, 9.0)) * (da_arvore.base as Transform3D)
		var camadas: Array[Dictionary] = Copas.montar("Teste 0,0", especie, da_arvore.mesh, [t], 280.0, 20.0)
		_verificar(camadas.size() == 2, "%s tem o modelo de longe e a copa (%d camadas)" % [especie, camadas.size()])
		if camadas.size() != 2:
			continue
		conferidas += 1
		var modelo := camadas[0]["visual"] as MultiMeshInstance3D
		var copa := camadas[1]["visual"] as MultiMeshInstance3D
		_verificar(modelo.visibility_range_begin == 280.0 and modelo.visibility_range_end == Copas.LONGE_ATE_O_TRIPO, "%s: o modelo de longe vai de 280 a %.0f u" % [especie, Copas.LONGE_ATE_O_TRIPO])
		_verificar(copa.visibility_range_begin == modelo.visibility_range_end and copa.visibility_range_end == Copas.FIM, "%s: a copa entra onde o modelo sai e vai a %.0f u" % [especie, Copas.FIM])
		_verificar(modelo.visibility_range_begin_margin == 20.0 and modelo.visibility_range_end_margin == 20.0 and copa.visibility_range_begin_margin == 20.0, "%s: a troca tem a mesma margem dos dois lados" % especie)
		_verificar(modelo.visibility_range_fade_mode == GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED and copa.visibility_range_fade_mode == GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED, "%s: sem desvanecer" % especie)
		# O modelo de longe tem a altura da árvore (mesma forma, menos faces).
		var altura_arvore: float = (t * da_arvore.mesh.get_aabb()).size.y
		var longe: Dictionary = CatalogoAssets.malha(especie + "_longe", 1.0)
		var altura_longe: float = ((t * (camadas[0]["formas"][0] as Transform3D)) * longe.mesh.get_aabb()).size.y
		_verificar(absf(altura_longe - altura_arvore) < altura_arvore * 0.2, "%s: o modelo de longe tem a altura da árvore (%.1f e %.1f)" % [especie, altura_longe, altura_arvore])
		for camada in camadas:
			(camada["visual"] as Node).free()
	_verificar(conferidas == 3, "as três espécies de palmeira têm modelo de longe no catálogo (%d de 3)" % conferidas)
	# Sem versão de longe: só a copa.
	var jatoba: Dictionary = CatalogoAssets.malha("jatoba", 1.0)
	if not jatoba.is_empty():
		var so_copa: Array[Dictionary] = Copas.montar("Teste 0,0", "jatoba", jatoba.mesh, [Transform3D.IDENTITY], 280.0, 20.0)
		_verificar(so_copa.size() == 1 and (so_copa[0]["visual"] as MultiMeshInstance3D).visibility_range_begin == 280.0, "jatobá não tem modelo de longe: só a copa, de 280 u")
		(so_copa[0]["visual"] as Node).free()

