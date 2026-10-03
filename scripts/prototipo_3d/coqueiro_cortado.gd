extends RefCounted
## Recorta a malha da própria árvore na altura do golpe, preservando seus materiais.
## Nasceu para o coqueiro e recorta qualquer malha: é o toco de toda árvore cortada.

const ALTURA_DO_TOCO := 0.85


## O centro da caixa completa cai no meio da copa dos coqueiros inclinados.
## Amostrar apenas o começo e o meio baixo da malha localiza o tronco real.
static func referencias_tronco(malha: Mesh) -> Dictionary:
	if malha == null:
		return {}
	var limites: AABB = malha.get_aabb()
	var altura := maxf(limites.size.y, 0.001)
	var base_min := Vector2(INF, INF)
	var base_max := Vector2(-INF, -INF)
	var alto_min := Vector2(INF, INF)
	var alto_max := Vector2(-INF, -INF)
	for superficie in range(malha.get_surface_count()):
		var dados := malha.surface_get_arrays(superficie)
		if not (dados[Mesh.ARRAY_VERTEX] is PackedVector3Array):
			continue
		var vertices: PackedVector3Array = dados[Mesh.ARRAY_VERTEX]
		for vertice in vertices:
			var fracao := (vertice.y - limites.position.y) / altura
			var plano := Vector2(vertice.x, vertice.z)
			if fracao <= 0.08:
				base_min.x = minf(base_min.x, plano.x)
				base_min.y = minf(base_min.y, plano.y)
				base_max.x = maxf(base_max.x, plano.x)
				base_max.y = maxf(base_max.y, plano.y)
			elif fracao >= 0.22 and fracao <= 0.38:
				alto_min.x = minf(alto_min.x, plano.x)
				alto_min.y = minf(alto_min.y, plano.y)
				alto_max.x = maxf(alto_max.x, plano.x)
				alto_max.y = maxf(alto_max.y, plano.y)
	if not is_finite(base_min.x):
		return {}
	var centro_base := (base_min + base_max) * 0.5
	var centro_alto := (alto_min + alto_max) * 0.5 if is_finite(alto_min.x) else centro_base
	return {
		"base": Vector3(centro_base.x, limites.position.y, centro_base.y),
		"alto": Vector3(centro_alto.x, limites.position.y + altura * 0.3, centro_alto.y),
		"raio_base": maxf(base_max.x - base_min.x, base_max.y - base_min.y) * 0.5,
	}


static func criar(partes: Array[Dictionary], pe: Vector3, raio_tronco: float) -> Node3D:
	var modelo := Node3D.new()
	modelo.name = "CoqueiroCortado"
	var malha_cortada := ArrayMesh.new()
	var bordas: Array[Vector3] = []
	for parte: Dictionary in partes:
		var malha: Mesh = parte["mesh"]
		if malha == null:
			continue
		var transformacao: Transform3D = parte["transform"]
		var matriz_normal := transformacao.basis.inverse().transposed()
		for superficie in range(malha.get_surface_count()):
			if malha.surface_get_primitive_type(superficie) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var dados := malha.surface_get_arrays(superficie)
			if not (dados[Mesh.ARRAY_VERTEX] is PackedVector3Array):
				continue
			var vertices: PackedVector3Array = dados[Mesh.ARRAY_VERTEX]
			var normais := PackedVector3Array()
			if dados[Mesh.ARRAY_NORMAL] is PackedVector3Array:
				normais = dados[Mesh.ARRAY_NORMAL]
			var uvs := PackedVector2Array()
			if dados[Mesh.ARRAY_TEX_UV] is PackedVector2Array:
				uvs = dados[Mesh.ARRAY_TEX_UV]
			var cores := PackedColorArray()
			if dados[Mesh.ARRAY_COLOR] is PackedColorArray:
				cores = dados[Mesh.ARRAY_COLOR]
			var indices := PackedInt32Array()
			if dados[Mesh.ARRAY_INDEX] is PackedInt32Array:
				indices = dados[Mesh.ARRAY_INDEX]
			var quantidade := indices.size() if not indices.is_empty() else vertices.size()
			var ferramenta := SurfaceTool.new()
			ferramenta.begin(Mesh.PRIMITIVE_TRIANGLES)
			var materiais: Array = parte.get("materiais", [])
			var material: Material = materiais[superficie] if superficie < materiais.size() else null
			if material == null:
				material = malha.surface_get_material(superficie)
			if material != null:
				ferramenta.set_material(material)
			var adicionados := 0
			for inicio in range(0, quantidade - 2, 3):
				# A COPA FICA DE FORA ANTES DE CUSTAR: triângulo com os três cantos
				# acima do corte não entra no toco, e numa árvore da mata são
				# quase todos. Só a altura é conferida aqui; o resto do canto
				# (normal, UV, cor) só se monta para quem fica.
				var acima := true
				for canto in range(3):
					var no_canto: int = indices[inicio + canto] if not indices.is_empty() else inicio + canto
					if (transformacao * vertices[no_canto]).y - pe.y <= ALTURA_DO_TOCO:
						acima = false
						break
				if acima:
					continue
				var triangulo: Array[Dictionary] = []
				for canto in range(3):
					var indice: int = indices[inicio + canto] if not indices.is_empty() else inicio + canto
					var normal := (matriz_normal * normais[indice]).normalized() if indice < normais.size() else Vector3.UP
					triangulo.append({
						"pos": transformacao * vertices[indice] - pe,
						"normal": normal,
						"uv": uvs[indice] if indice < uvs.size() else Vector2.ZERO,
						"cor": cores[indice] if indice < cores.size() else Color.WHITE,
					})
				var recorte := _recortar_triangulo(triangulo, bordas)
				for canto in range(1, recorte.size() - 1):
					for vertice: Dictionary in [recorte[0], recorte[canto], recorte[canto + 1]]:
						ferramenta.set_normal(vertice["normal"])
						ferramenta.set_uv(vertice["uv"])
						ferramenta.set_color(vertice["cor"])
						ferramenta.add_vertex(vertice["pos"])
						adicionados += 1
			if adicionados > 0:
				ferramenta.commit(malha_cortada)
	if malha_cortada.get_surface_count() == 0:
		modelo.free()
		return null
	var tronco := MeshInstance3D.new()
	tronco.name = "TroncoOriginalRecortado"
	tronco.mesh = malha_cortada
	modelo.add_child(tronco)
	_adicionar_corte(modelo, bordas, raio_tronco)
	# O toco alarga na base e pode ficar deslocado pelo tronco inclinado.
	# A malha recortada fornece uma colisao que acompanha essa silhueta.
	var corpo := StaticBody3D.new()
	corpo.name = "ColisaoDoToco"
	corpo.collision_layer = 1
	corpo.collision_mask = 1
	var colisao := CollisionShape3D.new()
	colisao.shape = malha_cortada.create_convex_shape()
	corpo.add_child(colisao)
	modelo.add_child(corpo)
	return modelo


static func _recortar_triangulo(triangulo: Array[Dictionary], bordas: Array[Vector3]) -> Array[Dictionary]:
	var recorte: Array[Dictionary] = []
	for i in range(3):
		var atual: Dictionary = triangulo[i]
		var proximo: Dictionary = triangulo[(i + 1) % 3]
		var atual_dentro: bool = atual["pos"].y <= ALTURA_DO_TOCO
		var proximo_dentro: bool = proximo["pos"].y <= ALTURA_DO_TOCO
		if atual_dentro:
			recorte.append(atual)
		if atual_dentro != proximo_dentro:
			var ponto_a: Vector3 = atual["pos"]
			var ponto_b: Vector3 = proximo["pos"]
			var fracao := (ALTURA_DO_TOCO - ponto_a.y) / (ponto_b.y - ponto_a.y)
			var ponto: Vector3 = ponto_a.lerp(ponto_b, fracao)
			recorte.append({
				"pos": ponto,
				"normal": (atual["normal"] as Vector3).lerp(proximo["normal"], fracao).normalized(),
				"uv": (atual["uv"] as Vector2).lerp(proximo["uv"], fracao),
				"cor": (atual["cor"] as Color).lerp(proximo["cor"], fracao),
			})
			bordas.append(ponto)
	return recorte


static func _adicionar_corte(modelo: Node3D, bordas: Array[Vector3], raio_tronco: float) -> void:
	var centro := Vector3(0.0, ALTURA_DO_TOCO, 0.0)
	if not bordas.is_empty():
		centro = Vector3.ZERO
		for ponto in bordas:
			centro += ponto
		centro /= float(bordas.size())
		centro.y = ALTURA_DO_TOCO
	var raio := maxf(raio_tronco * 0.6, 0.1)
	for ponto in bordas:
		raio = maxf(raio, Vector2(ponto.x - centro.x, ponto.z - centro.z).length())
	raio = minf(raio, maxf(raio_tronco * 2.0, 0.3))
	var borda := CylinderMesh.new()
	borda.top_radius = raio * 1.04
	borda.bottom_radius = raio * 0.98
	borda.height = 0.07
	borda.radial_segments = 16
	var casca := StandardMaterial3D.new()
	casca.albedo_color = Color("5b3f2a")
	casca.roughness = 1.0
	var aro := MeshInstance3D.new()
	aro.name = "BordaDaCasca"
	aro.mesh = borda
	aro.material_override = casca
	aro.position = centro - Vector3(0, 0.025, 0)
	modelo.add_child(aro)
	var topo := CylinderMesh.new()
	topo.top_radius = raio * 0.94
	topo.bottom_radius = raio * 0.94
	topo.height = 0.018
	topo.radial_segments = 20
	var madeira := StandardMaterial3D.new()
	madeira.albedo_color = Color("c6a677")
	madeira.roughness = 1.0
	var corte := MeshInstance3D.new()
	corte.name = "MadeiraExposta"
	corte.mesh = topo
	corte.material_override = madeira
	corte.position = centro + Vector3(0, 0.019, 0)
	modelo.add_child(corte)
