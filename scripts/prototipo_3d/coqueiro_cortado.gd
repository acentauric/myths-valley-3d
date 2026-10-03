extends RefCounted
## Recorta a malha da própria árvore na altura do golpe, preservando seus materiais.
## Nasceu para o coqueiro e recorta qualquer malha: é o toco de toda árvore cortada.
## E a QUEDA: a copa, de cima do corte, cai para longe de quem cortou (`copa`,
## `derrubar`).

## A altura do toco de sempre, quando a copa começa acima dela.
const ALTURA_DO_TOCO := 0.85
## Abaixo disto é raiz e o pé que alarga: o toco nunca é mais baixo, e o que
## se abre aqui embaixo não conta como copa.
const TOCO_MINIMO := 0.3
## A faixa de altura em que a abertura da árvore é medida.
const FAIXA := 0.05


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


## A ALTURA DO CORTE DESTA ÁRVORE, e até onde vai o tronco dela.
##
## "Quando cortei a pitangueira, ficou uma mesa no lugar dela." A pitangueira
## tem galho e folha abaixo dos 0,85 do toco de sempre, e o corte ali passava
## pela copa: em cima do tronco fino ficava a copa cortada rente, com o tampo de
## madeira exposta do tamanho dela — uma mesa redonda de dois metros.
##
## Então a árvore é medida antes: de faixa em faixa de altura, o quanto ela se
## abre do pé (`abertura`). O tronco é a faixa mais estreita entre a raiz e o
## toco; a copa começa na primeira faixa que se abre bem mais que ele; e o
## corte fica logo abaixo dela — ou nos 0,85 de sempre, quando a copa começa
## acima. `abertura` é também o que o toco guarda: folha que desce até ali e
## fica longe do tronco não entra nele.
static func medir_o_corte(superficies: Array[Dictionary], pe: Vector3) -> Dictionary:
	var faixas := int(ceilf(ALTURA_DO_TOCO / FAIXA)) + 1
	# A caixa de cada faixa no chão: de quanto ela se abre, e onde fica o meio
	# dela. Em volta do MEIO DA FAIXA e não do ponto de plantio, porque o
	# coqueiro é inclinado e o tronco dele não sai do pé.
	var menor: Array[Vector2] = []
	var maior: Array[Vector2] = []
	menor.resize(faixas)
	maior.resize(faixas)
	menor.fill(Vector2(INF, INF))
	maior.fill(Vector2(-INF, -INF))
	for superficie: Dictionary in superficies:
		var transformacao: Transform3D = superficie["transformacao"]
		for vertice in (superficie["vertices"] as PackedVector3Array):
			var p := transformacao * vertice - pe
			if p.y < 0.0 or p.y > ALTURA_DO_TOCO + FAIXA:
				continue
			var faixa := mini(int(p.y / FAIXA), faixas - 1)
			var plano := Vector2(p.x, p.z)
			menor[faixa] = Vector2(minf(menor[faixa].x, plano.x), minf(menor[faixa].y, plano.y))
			maior[faixa] = Vector2(maxf(maior[faixa].x, plano.x), maxf(maior[faixa].y, plano.y))
	var abertura: Array[float] = []
	abertura.resize(faixas)
	abertura.fill(0.0)
	for i in faixas:
		if is_finite(menor[i].x):
			abertura[i] = maxf(maior[i].x - menor[i].x, maior[i].y - menor[i].y) * 0.5
	# O TRONCO é a faixa mais estreita acima da raiz; a copa, a primeira faixa
	# ACIMA DELE que se abre bem mais. A raiz larga das árvores da mata, que
	# sobe um palmo acima do chão, fica abaixo do tronco e não conta.
	var primeira := int(TOCO_MINIMO / FAIXA)
	var mais_estreita := -1
	for i in range(primeira, faixas):
		if abertura[i] > 0.0 and (mais_estreita < 0 or abertura[i] < abertura[mais_estreita]):
			mais_estreita = i
	if mais_estreita < 0:
		return {"altura": ALTURA_DO_TOCO, "abertura": INF, "tronco": INF, "eixo": Vector2.ZERO}
	var tronco := abertura[mais_estreita]
	var limite := maxf(tronco * 2.2, tronco + 0.2)
	var altura := ALTURA_DO_TOCO
	var copa := faixas
	for i in range(mais_estreita + 1, faixas):
		if abertura[i] > limite:
			copa = i
			altura = maxf(TOCO_MINIMO, float(i) * FAIXA - FAIXA)
			break
	# O EIXO do tronco: o meio das faixas de tronco, da mais estreita à copa.
	var eixo := Vector2.ZERO
	var contadas := 0
	for i in range(mais_estreita, copa):
		if is_finite(menor[i].x):
			eixo += (menor[i] + maior[i]) * 0.5
			contadas += 1
	eixo /= float(maxi(contadas, 1))
	return {"altura": altura, "abertura": limite, "tronco": tronco, "eixo": eixo}


static func criar(partes: Array[Dictionary], pe: Vector3, raio_tronco: float) -> Node3D:
	var modelo := Node3D.new()
	modelo.name = "CoqueiroCortado"
	# As superfícies de todas as partes, lidas uma vez: a medida do corte e o
	# recorte passam pelas mesmas.
	var superficies: Array[Dictionary] = []
	for parte: Dictionary in partes:
		var malha: Mesh = parte["mesh"]
		if malha == null:
			continue
		var transformacao: Transform3D = parte["transform"]
		for superficie in range(malha.get_surface_count()):
			if malha.surface_get_primitive_type(superficie) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var dados := malha.surface_get_arrays(superficie)
			if not (dados[Mesh.ARRAY_VERTEX] is PackedVector3Array):
				continue
			var materiais: Array = parte.get("materiais", [])
			var material: Material = materiais[superficie] if superficie < materiais.size() else null
			if material == null:
				material = malha.surface_get_material(superficie)
			superficies.append({
				"transformacao": transformacao,
				"vertices": dados[Mesh.ARRAY_VERTEX],
				"normais": dados[Mesh.ARRAY_NORMAL] if dados[Mesh.ARRAY_NORMAL] is PackedVector3Array else PackedVector3Array(),
				"uvs": dados[Mesh.ARRAY_TEX_UV] if dados[Mesh.ARRAY_TEX_UV] is PackedVector2Array else PackedVector2Array(),
				"cores": dados[Mesh.ARRAY_COLOR] if dados[Mesh.ARRAY_COLOR] is PackedColorArray else PackedColorArray(),
				"indices": dados[Mesh.ARRAY_INDEX] if dados[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array(),
				"material": material,
			})
	var corte := medir_o_corte(superficies, pe)
	var altura: float = corte["altura"]
	var abertura: float = corte["abertura"]
	var eixo: Vector2 = corte["eixo"]
	var malha_cortada := ArrayMesh.new()
	var bordas: Array[Vector3] = []
	for superficie: Dictionary in superficies:
		var transformacao: Transform3D = superficie["transformacao"]
		var matriz_normal := transformacao.basis.inverse().transposed()
		var vertices: PackedVector3Array = superficie["vertices"]
		var normais: PackedVector3Array = superficie["normais"]
		var uvs: PackedVector2Array = superficie["uvs"]
		var cores: PackedColorArray = superficie["cores"]
		var indices: PackedInt32Array = superficie["indices"]
		var quantidade := indices.size() if not indices.is_empty() else vertices.size()
		var ferramenta := SurfaceTool.new()
		ferramenta.begin(Mesh.PRIMITIVE_TRIANGLES)
		if superficie["material"] != null:
			ferramenta.set_material(superficie["material"])
		var adicionados := 0
		for inicio in range(0, quantidade - 2, 3):
			# A COPA FICA DE FORA ANTES DE CUSTAR: triângulo com os três cantos
			# acima do corte não entra no toco, e numa árvore da mata são
			# quase todos. Só a altura é conferida aqui; o resto do canto
			# (normal, UV, cor) só se monta para quem fica.
			var acima := true
			for canto in range(3):
				var no_canto: int = indices[inicio + canto] if not indices.is_empty() else inicio + canto
				if (transformacao * vertices[no_canto]).y - pe.y <= altura:
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
			var bordas_dele: Array[Vector3] = []
			var recorte := _recortar_triangulo(triangulo, altura, bordas_dele)
			if recorte.size() < 3 or _longe_do_tronco(recorte, abertura, eixo):
				continue
			bordas.append_array(bordas_dele)
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
	_adicionar_corte(modelo, bordas, raio_tronco, altura, corte)
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
	modelo.set_meta("altura", altura)
	modelo.set_meta("eixo", eixo)
	return modelo


## Pedaço de copa que desce abaixo do corte: todo canto acima da raiz e longe
## do tronco. A raiz, que se abre rente ao chão, fica.
static func _longe_do_tronco(recorte: Array[Dictionary], abertura: float, eixo: Vector2) -> bool:
	for vertice: Dictionary in recorte:
		var p: Vector3 = vertice["pos"]
		if p.y <= TOCO_MINIMO or Vector2(p.x, p.z).distance_to(eixo) <= abertura:
			return false
	return true


static func _recortar_triangulo(triangulo: Array[Dictionary], altura: float, bordas: Array[Vector3]) -> Array[Dictionary]:
	var recorte: Array[Dictionary] = []
	for i in range(3):
		var atual: Dictionary = triangulo[i]
		var proximo: Dictionary = triangulo[(i + 1) % 3]
		var atual_dentro: bool = atual["pos"].y <= altura
		var proximo_dentro: bool = proximo["pos"].y <= altura
		if atual_dentro:
			recorte.append(atual)
		if atual_dentro != proximo_dentro:
			var ponto_a: Vector3 = atual["pos"]
			var ponto_b: Vector3 = proximo["pos"]
			var fracao := (altura - ponto_a.y) / (ponto_b.y - ponto_a.y)
			var ponto: Vector3 = ponto_a.lerp(ponto_b, fracao)
			recorte.append({
				"pos": ponto,
				"normal": (atual["normal"] as Vector3).lerp(proximo["normal"], fracao).normalized(),
				"uv": (atual["uv"] as Vector2).lerp(proximo["uv"], fracao),
				"cor": (atual["cor"] as Color).lerp(proximo["cor"], fracao),
			})
			bordas.append(ponto)
	return recorte


## O CORTE À MOSTRA: o aro da casca e a madeira, na largura do TRONCO MEDIDO
## (`medir_o_corte`) — e não do raio de catálogo da árvore, que é a metade do
## tamanho dela e fazia o disco de dois metros da pitangueira.
static func _adicionar_corte(modelo: Node3D, bordas: Array[Vector3], raio_tronco: float, altura: float, corte: Dictionary) -> void:
	var medido: float = corte.get("tronco", INF)
	var abertura: float = corte.get("abertura", INF)
	var eixo: Vector2 = corte.get("eixo", Vector2.ZERO)
	# Só as bordas do TRONCO: a de um pedaço de folha que ficou no toco não
	# puxa o meio nem alarga o corte.
	var do_tronco: Array[Vector3] = []
	for ponto in bordas:
		if Vector2(ponto.x, ponto.z).distance_to(eixo) <= abertura:
			do_tronco.append(ponto)
	var centro := Vector3(eixo.x, altura, eixo.y)
	if not do_tronco.is_empty():
		centro = Vector3.ZERO
		for ponto in do_tronco:
			centro += ponto
		centro /= float(do_tronco.size())
		centro.y = altura
	var raio := maxf(medido * 0.9, 0.06) if is_finite(medido) else maxf(raio_tronco * 0.6, 0.1)
	for ponto in do_tronco:
		raio = maxf(raio, Vector2(ponto.x - centro.x, ponto.z - centro.z).length())
	raio = minf(raio, abertura if is_finite(abertura) else maxf(raio_tronco * 2.0, 0.3))
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
	var exposta := MeshInstance3D.new()
	exposta.name = "MadeiraExposta"
	exposta.mesh = topo
	exposta.material_override = madeira
	exposta.position = centro + Vector3(0, 0.019, 0)
	modelo.add_child(exposta)



# --- a queda ----------------------------------------------------------------------

## Quanto a queda leva: o tombo, o tranco no chão, o tempo deitada e o afundar.
const QUEDA_SEGUNDOS := 1.5
const DEITADA_SEGUNDOS := 1.2
const AFUNDAR_SEGUNDOS := 1.4
## Até onde ela tomba, em graus: quase deitada, que o chão tem relevo e a copa
## apoia nos galhos.
const TOMBO := 86.0


## A COPA QUE CAI: a árvore de cima do corte, para a queda.
##
## Não é recortada como o toco. A copa é quase todo triângulo da árvore, e
## recortar um por um — o que o toco faz com os poucos de baixo — travaria o
## quadro do último golpe. Aqui saem só os triângulos inteiros abaixo do corte,
## pelos ÍNDICES, sobre os vértices originais; os que atravessam o corte vão
## inteiros, e a sobra de um palmo some no primeiro instante do tombo.
##
## `pivo` é o ponto do corte no mundo (o eixo do tronco na altura do toco): as
## partes ficam postas em volta dele, para girar a partir dali.
static func copa(partes: Array[Dictionary], pivo: Vector3) -> Node3D:
	var no := Node3D.new()
	no.name = "CopaCaindo"
	for parte: Dictionary in partes:
		var malha: Mesh = parte["mesh"]
		if malha == null:
			continue
		var transformacao: Transform3D = parte["transform"]
		var materiais: Array = parte.get("materiais", [])
		var nova := ArrayMesh.new()
		for superficie in range(malha.get_surface_count()):
			if malha.surface_get_primitive_type(superficie) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var dados := malha.surface_get_arrays(superficie)
			if not (dados[Mesh.ARRAY_VERTEX] is PackedVector3Array):
				continue
			var vertices: PackedVector3Array = dados[Mesh.ARRAY_VERTEX]
			var acima := PackedByteArray()
			acima.resize(vertices.size())
			for i in vertices.size():
				acima[i] = 1 if (transformacao * vertices[i]).y > pivo.y else 0
			var indices := PackedInt32Array()
			if dados[Mesh.ARRAY_INDEX] is PackedInt32Array:
				indices = dados[Mesh.ARRAY_INDEX]
			else:
				indices.resize(vertices.size())
				for i in vertices.size():
					indices[i] = i
			var ficam := PackedInt32Array()
			for t in range(0, indices.size() - 2, 3):
				if acima[indices[t]] == 1 or acima[indices[t + 1]] == 1 or acima[indices[t + 2]] == 1:
					ficam.append(indices[t])
					ficam.append(indices[t + 1])
					ficam.append(indices[t + 2])
			if ficam.is_empty():
				continue
			dados[Mesh.ARRAY_INDEX] = ficam
			nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, dados)
			var material: Material = materiais[superficie] if superficie < materiais.size() else null
			if material == null:
				material = malha.surface_get_material(superficie)
			nova.surface_set_material(nova.get_surface_count() - 1, material)
		if nova.get_surface_count() == 0:
			continue
		var pedaco := MeshInstance3D.new()
		pedaco.name = "Copa"
		pedaco.mesh = nova
		pedaco.transform = Transform3D(transformacao.basis, transformacao.origin - pivo)
		no.add_child(pedaco)
	if no.get_child_count() == 0:
		no.free()
		return null
	return no


## A QUEDA: `o_que` gira em volta de `pivo` para o lado de `direcao` (no chão),
## começando devagar e acelerando, como árvore de verdade; dá um tranco no
## chão, fica um instante deitado e afunda na terra até sumir. É desenho e não
## corpo: não tem colisão, e o caminho fica livre quando ela some.
##
## Serve à copa que `copa` monta (posta em volta do pivô, sem pai) e a uma peça
## inteira já no mundo — a embaúba nova do cemitério —, que cai do próprio pé.
## Devolve o nó que gira, que se solta sozinho no fim.
static func derrubar(o_que: Node3D, onde: Node, pivo: Vector3, direcao: Vector3) -> Node3D:
	var giro := Node3D.new()
	giro.name = "ArvoreCaindo"
	# Nome legível mesmo com duas caindo ao mesmo tempo (ArvoreCaindo2…).
	onde.add_child(giro, true)
	giro.global_position = pivo
	if o_que.get_parent() != null:
		o_que.reparent(giro, true)
	else:
		giro.add_child(o_que)
		o_que.position = Vector3.ZERO
	var deitar := Vector3(direcao.x, 0.0, direcao.z)
	if deitar.length_squared() < 0.0001:
		deitar = Vector3.FORWARD
	deitar = deitar.normalized()
	# Girar em volta deste eixo leva o alto da árvore para o lado de `deitar`.
	var eixo := Vector3.UP.cross(deitar).normalized()
	var deitada := deg_to_rad(TOMBO)
	var afundar := maxf(_largura(o_que) * 0.6 + 0.5, 1.5)
	var tween := giro.create_tween()
	var girar := func(angulo: float) -> void: giro.basis = Basis(eixo, angulo)
	tween.tween_method(girar, 0.0, deitada, QUEDA_SEGUNDOS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_method(girar, deitada, deitada - deg_to_rad(7.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(girar, deitada - deg_to_rad(7.0), deitada - deg_to_rad(2.0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(DEITADA_SEGUNDOS)
	tween.tween_property(giro, "position:y", giro.position.y - afundar, AFUNDAR_SEGUNDOS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(giro.queue_free)
	return giro


## A maior largura das malhas de `no` no mundo, ainda de pé: o quanto a árvore
## deitada tem de afundar para sumir na terra. Chamada com ela já na árvore.
static func _largura(no: Node3D) -> float:
	var caixa := AABB()
	var primeira := true
	var malhas: Array = no.find_children("*", "MeshInstance3D", true, false)
	if no is MeshInstance3D:
		malhas.append(no)
	for malha: MeshInstance3D in malhas:
		var dela := malha.global_transform * malha.get_aabb()
		caixa = dela if primeira else caixa.merge(dela)
		primeira = false
	return maxf(caixa.size.x, caixa.size.z)
