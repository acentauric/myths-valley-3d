extends Node3D
## Renders one geographic region from metric KML data and a separately curated scenario.
## Coordinates are local meters: X points east and Z points south.
## The region catalog defines how many meters one Godot unit represents (`scale_m_per_unit`)
## and may exaggerate altitude independently (`vertical_exaggeration`). Horizontal positions
## are divided by the scale while walkable widths keep a playable minimum.

const LAND_COLOR := Color("9bbf7c")
const FOREST_COLOR := Color("719968")
const VILLAGE_COLOR := Color("bbcb98")
const SEA_COLOR := Color("5e9fa9")
const SEA_SURFACE_Y := -0.12
const BEACH_COLOR := Color("e6d2a1")
const ROAD_COLOR := Color("cfb78b")
const MAIN_ROAD_COLOR := Color("e5c994")
const SHORE_ACCESS_COLOR := Color("a47d50")
const RIVER_COLOR := Color("76b5b6")
const ESTRADA_OCRE_TEXTURE := preload("res://assets/prototipo_3d/materiais/estrada_terra_ocre_v1.png")
const CHAO_PRACA_TEXTURE := preload("res://assets/prototipo_3d/materiais/chao_praca_v1.png")
const GRAMA_TERRA_MATA_TEXTURE := preload("res://assets/prototipo_3d/materiais/grama_terra_mata_v1.png")
const Mar = preload("res://scripts/prototipo_3d/mar.gd")
const CoqueiroCortado = preload("res://scripts/prototipo_3d/coqueiro_cortado.gd")
const AREIA_PRAIA := preload("res://assets/prototipo_3d/mar/areia_praia.gdshader")
const FOZ_RIO := preload("res://assets/prototipo_3d/mar/foz_rio.gdshader")
const AGUA_RIO := preload("res://assets/prototipo_3d/mar/agua_rio.gdshader")
const LEITO_RIO := preload("res://assets/prototipo_3d/mar/leito_rio.gdshader")
const AREIA_TEXTURE := preload("res://assets/prototipo_3d/materiais/areia_praia_v1.png")
## Tinta da textura de grama/terra: com o sol batendo no chão (não mais só a luz
## ambiente), a textura crua fica ocre; puxa de volta para o verde do Recôncavo.
const TINTA_GRAMA := Color(0.74, 0.86, 0.6)
## Montagem aos poucos: nos laços pesados (terreno, mata) a região devolve o controle
## para o Godot desenhar um quadro a cada ORCAMENTO_QUADRO_US, e avisa o progresso
## (0 a 1) e a etapa — a tela de carregamento anda em vez de congelar.
signal etapa(fracao: float, texto: String)
const ORCAMENTO_QUADRO_US := 80000
const TREE_COLLISION_RADIUS := 28.0
## Quanto as árvores entram no chão (unidades), para não parecerem pousadas.
const ARVORE_AFUNDADA := 0.06
const TREE_COLLISION_POOL_SIZE := 48
const TREE_COLLISION_INTERVAL := 0.25
const TERRAIN_CELL_SIZE := 4.0
## A praça real de Bom Jesus é um largo triangular maior que o desenho do KML.
const PRACA_AMPLIACAO := 1.5
const SURFACE_SEGMENT_SIZE := 3.0
const NORTHERN_RIVER_WIDTH_FACTOR := 0.8

var landmarks: Array[Dictionary] = []
var areas: Array[Dictionary] = []
var _features: Array[Dictionary] = []
var _projection: Dictionary = {}
var _bounds := Rect2()
var _map_frame := Rect2()
var _background_kind := "land"
## Bloco "bathymetry" do cenário: com ele, o mar ganha fundo real e água transparente.
var _bathymetry: Dictionary = {}
var _land := PackedVector2Array()
var _forest := PackedVector2Array()
var _kml_forest := PackedVector2Array()
var _village := PackedVector2Array()
var _coast := PackedVector2Array()
var _roads: Array[Dictionary] = []
var _rivers: Array[Dictionary] = []
var _shore_access_routes: Array[Dictionary] = []
var _point_positions: Array[Vector2] = []
var _elevation_samples: Array[Dictionary] = []
## Altura já calculada de cada vértice das malhas do terreno: vizinhos da subdivisão
## repetem os mesmos pontos, e ground_height_at percorre todas as amostras a cada vez.
var _alturas_vertices: Dictionary = {}
var _inicio_do_quadro_us := 0
## Retângulo que envolve a linha da costa: ponto mais longe que a margem pedida não
## precisa medir a distância segmento a segmento.
var _costa_limites := Rect2()
var _open_areas: Array[PackedVector2Array] = []
## Cruzamentos das ruas (ponta de uma rua emendada em outra): ponto e largura da rua.
var _road_junctions: Array[Dictionary] = []
var _tree_trunks: Array[Dictionary] = []
## ÍNDICES ESPACIAIS DA MONTAGEM. O vale media cada ponto contra TODOS os ~1.340
## segmentos de rua e rio (sorteio da mata), os 141 da costa (cada altura na faixa da
## praia) e os ~6.300 troncos (cada lugar de casa ou árvore): 29 s de montagem, duas
## vezes (menu e jogo). Com grades de células só se mede o que pode estar perto, e a
## resposta é a mesma, bit a bit (montagem comparada inteira: troncos, lotes, árvores,
## vértices de todas as malhas, MultiMesh e colisões). Cada grade se refaz se a lista
## dela mudar de tamanho.
const CELULA_ROTAS := 16.0
## Maior folga que o jogo pede a _near_route (mata 2,5; sub-bosque 1,5): cada segmento
## entra na grade com esta margem; pedido maior mede tudo, como antes.
const FOLGA_MAXIMA_ROTAS := 8.0
const CELULA_COSTA := 16.0
const CELULA_TRONCOS := 8.0
var _grade_rotas := {}
var _rotas_a := PackedVector2Array()
var _rotas_b := PackedVector2Array()
var _rotas_meia := PackedFloat64Array()
var _grade_rotas_chave := Vector2i(-1, -1)
var _grade_costa := {}
var _grade_costa_n := -1
var _grade_costa_margem := -1.0
var _grade_troncos := {}
var _grade_troncos_n := -1
var _maior_raio_tronco := 2.0
var _tree_collision_pool: Array[Dictionary] = []
var _tree_collision_elapsed := 0.0
var _meters_per_unit := 1.0
var _vertical_exaggeration := 1.0
var _estilo_tripo := false
## O gerador de prévia usa exatamente a mesma leitura geográfica e a mesma malha
## drapeada do jogo, mas para depois da terra. Assim o editor não mantém uma
## segunda interpretação do KML só para conseguir mostrar o chão.
var terrain_only := false
## Espécies da mata no estilo Tripo (chaves do CatalogoAssets) e no procedural (FloraReconcavo).
## Só modelos leves (~2,5 mil triângulos): o dendê (15 mil) fica para as árvores nomeadas.
const ESPECIES_MATA_TRIPO := ["mata_alta", "mata_larga", "mata_alta", "embauba", "mata_larga"]
## Lado do bloco (unidades) em que a mata e a orla são divididas: cada bloco é uma
## MultiMesh própria, descartada fora da câmera e com LOD escolhido pela distância.
const BLOCO_MATA := 40.0
## O GLB já traz LOD de malha quando o importador consegue simplificá-lo. O segundo
## nível aqui é a ocultação gradual do bloco inteiro: plantas baixas desaparecem
## antes das copas, que ainda compõem a paisagem vista à distância.
const LOD_SUB_BOSQUE := 85.0
const LOD_RESTINGA := 200.0
const LOD_ARVORE_RIO := 230.0
const LOD_COQUEIRO := 250.0
const LOD_MATA := 280.0
const LOD_MARGEM := 20.0
const LOD_BIAS := 0.65
var _blocos_vegetacao_lod: Array[Dictionary] = []
var _camera_de_mapa := false


func set_estilo_tripo(value: bool) -> void:
	_estilo_tripo = value


## Malha e transformação-base de uma espécie para MultiMesh, no estilo ativo.
## Devolve {"mesh", "base", "altura", "tronco"}; no procedural, a base é a identidade.
func _malha_da_especie(species: String, rng: RandomNumberGenerator) -> Dictionary:
	if _estilo_tripo:
		var tripo: Dictionary = CatalogoAssets.malha(species, 1.0)
		if not tripo.is_empty():
			return tripo
	var built: Dictionary = FloraReconcavo.especie(species, 1.0, rng)
	return {"mesh": built.mesh, "base": Transform3D.IDENTITY, "altura": float(built.trunk_height), "tronco": float(built.trunk_radius)}


func set_meters_per_unit(value: float) -> void:
	_meters_per_unit = maxf(value, 0.01)


func get_meters_per_unit() -> float:
	return _meters_per_unit


func set_vertical_exaggeration(value: float) -> void:
	_vertical_exaggeration = maxf(value, 0.01)


func get_vertical_exaggeration() -> float:
	return _vertical_exaggeration


## Converts a real-world width in meters to Godot units, never below a playable minimum.
func _units(meters: float, minimum: float) -> float:
	return maxf(meters / _meters_per_unit, minimum)


func build_region(kml_json_path: String, scenario_json_path: String) -> void:
	_clear_region()
	var geographic := _read_json(kml_json_path)
	var scenario := _read_json(scenario_json_path)
	if geographic.is_empty() or scenario.is_empty():
		return
	if geographic.get("region_id", "") != scenario.get("region_id", ""):
		push_error("Os dados geográficos e o cenário pertencem a regiões diferentes.")
		return
	_projection = geographic.get("projection", {})
	var bounds_data: Dictionary = scenario.get("bounds_m", geographic.get("bounds_m", {}))
	_background_kind = String(scenario.get("background_kind", "land"))
	_bathymetry = scenario.get("bathymetry", {})
	_bounds = Rect2(
		Vector2(float(bounds_data.get("min_x", 0.0)), float(bounds_data.get("min_z", 0.0))) / _meters_per_unit,
		Vector2(
			float(bounds_data.get("max_x", 0.0)) - float(bounds_data.get("min_x", 0.0)),
			float(bounds_data.get("max_z", 0.0)) - float(bounds_data.get("min_z", 0.0))
		) / _meters_per_unit
	)
	_land = _to_points(scenario.get("land_polygon_m", []))
	_forest = _to_points(scenario.get("forest_polygon_m", []))
	_village = _to_points(scenario.get("village_polygon_m", []))
	_coast = _to_points(scenario.get("coastline_m", []))
	_costa_limites = _points_bounds(_coast) if _coast.size() >= 2 else Rect2()
	if _bounds.size.x <= 0.0 or _bounds.size.y <= 0.0 or _land.size() < 3:
		push_error("A região não contém limites e polígono de terra válidos.")
		return
	# Apenas Point/POI no KML possui altitude medida. Zeros de linhas e polígonos
	# significam ausência de medição e não entram na interpolação.
	for feature_value in geographic.get("features", []):
		var elevation_feature: Dictionary = feature_value
		if elevation_feature.get("kind", "") != "poi" or not elevation_feature.has("source_altitude_m"):
			continue
		var elevation_points := _to_points(elevation_feature.get("coordinates_m", []))
		if not elevation_points.is_empty():
			_elevation_samples.append({"point": elevation_points[0], "height": float(elevation_feature["source_altitude_m"]) / _meters_per_unit * _vertical_exaggeration})
	for feature_value in geographic.get("features", []):
		var feature: Dictionary = feature_value
		_features.append(feature)
		var points := _to_points(feature.get("coordinates_m", []))
		if feature.get("kind", "") == "map_frame" and points.size() >= 3:
			_map_frame = _points_bounds(points)
		if feature.get("kind", "") == "area":
			var center := Vector2.ZERO
			for point in points:
				center += point
			if not points.is_empty():
				center /= float(points.size())
				areas.append({"id": String(feature.get("id", "")), "name": String(feature.get("name", "")), "position": ground_position(Vector3(center.x, 0.05, center.y), 0.05)})
			match String(feature.get("name", "")):
				"Mata": _kml_forest = points
				"Fazenda": _open_areas.append(points)
				"Praça": _open_areas.append(_ampliar_poligono(points, PRACA_AMPLIACAO))
		match String(feature.get("kind", "")):
			"poi":
				if not points.is_empty():
					var point := points[0]
					_point_positions.append(point)
					landmarks.append({
						"id": String(feature.get("id", "")),
						"name": String(feature.get("name", "")),
						"position": ground_position(Vector3(point.x, 0.05, point.y), 0.05),
					})
			"road":
				if points.size() >= 2:
					var width := _road_width(feature)
					_roads.append({"name": String(feature.get("name", "")), "points": points, "width": width, "bounds": _points_bounds(points).grow(width * 0.5)})
			"river":
				if points.size() >= 2:
					_rivers.append({"name": String(feature.get("name", "")), "points": points, "width": _units(9.0, 4.0)})
	_curve_roads()
	if not terrain_only:
		await _marcar(0.02, "Enchendo a baía")
		_build_background()
	# Ladrilho maior deixa folhas e tufos mais legiveis no terreno ao redor da via.
	var mata_material := _terrain_texture_material(GRAMA_TERRA_MATA_TEXTURE, 12.0)
	await _marcar(0.05, "Moldando o terreno")
	await _add_polygon("Terra", _land, 0.0, LAND_COLOR, true, mata_material, true)
	await _marcar(0.38, "Moldando o terreno")
	if terrain_only:
		await _marcar(1.0, "Terreno pronto")
		return
	# Quando a mata acompanha todo o continente, evita criar uma segunda malha
	# sobre a terra. As duas malhas tinham triangulações diferentes e podiam
	# deixar a textura parecer recortada após a interpolação das elevações.
	if _forest.size() >= 3 and _forest != _land:
		_add_polygon("Cobertura florestal", _forest, 0.012, FOREST_COLOR, false, mata_material)
	# Vila e áreas do KML só existem em terra: sem o recorte, a vila avançava sobre
	# o mar ao lado do píer como um gramado.
	for parte in _on_land(_village):
		_add_polygon("Área ocupada", parte, 0.018, VILLAGE_COLOR, false, mata_material)
	for feature in _features:
		if feature.get("kind", "") == "area":
			var color := LAND_COLOR
			match String(feature.get("name", "")):
				"Mata": color = Color("648a5c")
				"Fazenda": color = Color("86aa67")
				"Praça": color = Color("d9c39a")
			var area_material: Material = mata_material
			var pontos_area := _to_points(feature.get("coordinates_m", []))
			if String(feature.get("name", "")) == "Praça":
				area_material = _textured_material(CHAO_PRACA_TEXTURE, Color("f2e6c8"), 6.0)
				pontos_area = _ampliar_poligono(pontos_area, PRACA_AMPLIACAO)
			for parte in _on_land(pontos_area):
				_add_polygon(String(feature.get("name", "Área")), parte, 0.027, color, false, area_material)
	# Mantém a areia acima das sobreposições da Mata (offset 0.027). Sem essa
	# margem, a textura de grama cobre trechos da praia apesar de a faixa e sua
	# colisão já existirem na mesma linha costeira.
	await _marcar(0.42, "Estendendo a praia e os rios")
	_add_beach()
	for river in _rivers:
		if river.points.size() < 2:
			continue
		var northern := _is_northern_river(river)
		var largura_margem := _units(12.0, 3.0)
		var largura_total := float(river.width) + largura_margem * 2.0
		var material_leito := ShaderMaterial.new()
		material_leito.shader = LEITO_RIO
		material_leito.set_shader_parameter("areia", AREIA_TEXTURE)
		var fracao_canal := float(river.width) / largura_total
		material_leito.set_shader_parameter("fracao_canal", fracao_canal)
		material_leito.set_shader_parameter("franja", minf(1.0, 1.6 / largura_margem))
		# Uma só malha de areia evita frestas com grama entre leito e margens.
		# Na faixa central, os vértices coincidem com os da água acima dela.
		_add_ribbon("Areia do rio", river.points, largura_total, 0.05, Color.WHITE, false, material_leito, NAN, 6, 1.5, fracao_canal, null, false, northern)
		# Água doce de mata: escura, âmbar, correnteza lenta (agua_rio.gdshader).
		var material_rio := ShaderMaterial.new()
		material_rio.shader = AGUA_RIO
		material_rio.set_shader_parameter("ondas_a", Mar.textura_ruido("ondas_a", 0.035, true))
		material_rio.set_shader_parameter("ondas_b", Mar.textura_ruido("ondas_b", 0.05, true))
		var comprimento_rio := 0.0
		for i in range(river.points.size() - 1):
			comprimento_rio += river.points[i].distance_to(river.points[i + 1])
		material_rio.set_shader_parameter("comprimento", comprimento_rio / float(river.width))
		material_rio.set_shader_parameter("suavizar_inicio", _tem_foz_no_extremo(river.points, false))
		material_rio.set_shader_parameter("suavizar_fim", _tem_foz_no_extremo(river.points, true))
		material_rio.set_shader_parameter("transicao_foz_larguras", _units(100.0, 25.0) / float(river.width) if northern else 1.0)
		_add_ribbon("Rio", river.points, river.width, 0.09, RIVER_COLOR, false, material_rio, NAN, 6, 1.5, 0.0, null, false, northern)
	_add_river_mouths()
	# A rua mais larga fica por cima nas sobreposições (as ramificações entram por baixo
	# dela), e cada cruzamento ganha um remendo de terra batida que cobre a emenda.
	await _marcar(0.46, "Abrindo as ruas")
	var widest := 0.0
	for road in _roads:
		widest = maxf(widest, float(road.width))
	for road_index in _roads.size():
		var road: Dictionary = _roads[road_index]
		await _marcar(0.46 + 0.03 * float(road_index) / float(_roads.size()), "Abrindo as ruas", false)
		var road_width: float = float(road.width)
		var road_y := 0.064 if road_width >= widest else 0.058
		var road_path := _soften_road_corners(road.points, road_width)
		var tint := Color("fff8e8") if road.name == "Rua Principal" else Color("f7e7c6")
		var shoulder_width := _units(4.0, 1.15)
		var transition_width: float = road_width + shoulder_width * 2.0
		var transition_material := _road_shoulder_material(road_width / transition_width, tint)
		_add_ribbon("Transição " + road.name, road_path, transition_width, 0.052, ROAD_COLOR, false, transition_material, NAN, 4, 1.5, 0.0, null, true)
		_add_ribbon(road.name, road_path, road_width, road_y, ROAD_COLOR, true, _textured_material(ESTRADA_OCRE_TEXTURE, tint), NAN, 4, 1.5, 0.0, null, true)
	_build_road_junctions()
	await _marcar(0.49, "Abrindo as ruas", false)
	_build_shore_access()
	await _marcar(0.5, "Plantando a mata")
	await _build_forest(scenario.get("vegetation", {}))
	await _marcar(1.0, "Plantando a mata")


## Altura da superfície do mar com fundo real (dá para entrar andando); -INF sem ele.
func water_level() -> float:
	return SEA_SURFACE_Y if _background_kind == "sea" and not _bathymetry.is_empty() else -INF


## Partes do polígono que ficam dentro da terra (sem mar de fundo, o polígono inteiro).
func _on_land(points: PackedVector2Array) -> Array[PackedVector2Array]:
	var partes: Array[PackedVector2Array] = []
	if points.size() < 3:
		return partes
	if _background_kind != "sea" or _land.size() < 3:
		partes.append(points)
		return partes
	for parte in Geometry2D.intersect_polygons(points, _land):
		partes.append(parte)
	return partes


## Avisa a etapa e, passado o orçamento do quadro (ou sempre, com `forcar`), cede um
## quadro para a tela de carregamento andar. Fora da árvore de cena, não espera.
func _marcar(fracao: float, texto: String, forcar: bool = true) -> void:
	etapa.emit(fracao, texto)
	if not is_inside_tree():
		return
	if not forcar and Time.get_ticks_usec() - _inicio_do_quadro_us < ORCAMENTO_QUADRO_US:
		return
	await get_tree().process_frame
	_inicio_do_quadro_us = Time.get_ticks_usec()


func get_map_bounds() -> Rect2:
	return _bounds


func get_map_frame() -> Rect2:
	return _map_frame if _map_frame.has_area() else _bounds


func has_map_frame() -> bool:
	return _map_frame.has_area()


## Altitude KML em metros convertida pela mesma escala X/Z da região.
## Interpolação IDW dos pontos medidos; o KML não fornece um DEM contínuo.
func ground_height_at(position: Vector3) -> float:
	var point := Vector2(position.x, position.z)
	var weighted_height := 0.0
	var total_weight := 0.0
	var sampled_height := 0.0
	var has_exact_sample := false
	for sample in _elevation_samples:
		var distance_squared: float = point.distance_squared_to(sample.point)
		if distance_squared < 0.000001:
			sampled_height = float(sample.height)
			has_exact_sample = true
			break
		var weight: float = 1.0 / distance_squared
		weighted_height += float(sample.height) * weight
		total_weight += weight
	if not has_exact_sample and total_weight > 0.0:
		sampled_height = weighted_height / total_weight
	if _background_kind != "sea" or _coast.size() < 2:
		return sampled_height
	if _land.size() < 3 or not Geometry2D.is_point_in_polygon(point, _land):
		return SEA_SURFACE_Y
	# POIs espalhados nao formam um DEM costeiro confiavel. Aproxima a terra
	# gradualmente do nivel da agua para evitar degraus e lacunas na praia.
	var shore_width := _units(80.0, 18.0)
	if not _costa_limites.grow(shore_width).has_point(point):
		return sampled_height
	var coast_distance := _distancia_costa(point, shore_width)
	var inland_weight := smoothstep(0.0, shore_width, coast_distance)
	return lerpf(SEA_SURFACE_Y, sampled_height, inland_weight)


func ground_position(position: Vector3, offset_y: float = 0.0) -> Vector3:
	return Vector3(position.x, ground_height_at(position) + offset_y, position.z)


func get_spawn_position() -> Vector3:
	for landmark in landmarks:
		if landmark.get("name", "") == "Praça" and _is_on_land(landmark["position"]):
			return landmark["position"] + Vector3(0.0, 0.07, 0.0)
	for landmark in landmarks:
		if _is_on_land(landmark["position"]):
			return landmark["position"] + Vector3(0.0, 0.07, 0.0)
	if _land.size() >= 3:
		var indices := Geometry2D.triangulate_polygon(_land)
		if indices.size() >= 3:
			var inside := (_land[indices[0]] + _land[indices[1]] + _land[indices[2]]) / 3.0
			return ground_position(Vector3(inside.x, 0.0, inside.y), 0.12)
	var center := _bounds.get_center()
	return ground_position(Vector3(center.x, 0.0, center.y), 0.12)


func is_walkable_point(position: Vector3) -> bool:
	var point := Vector2(position.x, position.z)
	if _land.size() >= 3 and Geometry2D.is_point_in_polygon(point, _land):
		return true
	for road in _roads:
		if road.bounds.has_point(point) and _distance_to_line(point, road.points) <= road.width * 0.5:
			return true
	for access in _shore_access_routes:
		if access.bounds.has_point(point) and _distance_to_line(point, access.points) <= access.width * 0.5:
			return true
	return false


## O círculo inteiro da construção deve ficar em terra e fora de todas as vias e árvores do mapa.
func is_build_site_clear(position: Vector3, radius: float) -> bool:
	if not position.is_finite() or _land.size() < 3:
		return false
	var center := Vector2(position.x, position.z)
	if not Geometry2D.is_point_in_polygon(center, _land):
		return false
	for index in range(12):
		var edge := center + Vector2.RIGHT.rotated(TAU * float(index) / 12.0) * radius
		if not Geometry2D.is_point_in_polygon(edge, _land):
			return false
	for road in _roads:
		var clearance: float = float(road.width) * 0.5 + radius + 1.5
		if road.bounds.grow(clearance).has_point(center) and _distance_to_line(center, road.points) < clearance:
			return false
	# Rio não é terreno de árvore nem de casa: nada plantado dentro da calha.
	for river in _rivers:
		var folga_rio: float = float(river.width) * 0.5 + radius + 1.0
		# A caixa do rio já vem crescida de meia largura + 1 u (ou mais): crescida do
		# raio, contém todo ponto a menos de folga_rio da calha.
		if (river.bounds as Rect2).grow(radius).has_point(center) and _distance_to_line(center, river.points) < folga_rio:
			return false
	for access in _shore_access_routes:
		var clearance: float = float(access.width) * 0.5 + radius + 1.5
		if access.bounds.grow(clearance).has_point(center) and _distance_to_line(center, access.points) < clearance:
			return false
	_garantir_grade_troncos()
	var alcance := radius + _maior_raio_tronco + 1.0
	for cx in range(floori((center.x - alcance) / CELULA_TRONCOS), floori((center.x + alcance) / CELULA_TRONCOS) + 1):
		for cy in range(floori((center.y - alcance) / CELULA_TRONCOS), floori((center.y + alcance) / CELULA_TRONCOS) + 1):
			var lista: Variant = _grade_troncos.get(Vector2i(cx, cy))
			if lista == null:
				continue
			for i: int in lista:
				var trunk: Dictionary = _tree_trunks[i]
				var tree_center: Vector2 = trunk.point
				var separation: float = radius + maxf(float(trunk.radius), 2.0) + 1.0
				if center.distance_squared_to(tree_center) < separation * separation:
					return false
	return true


func _is_on_land(position: Vector3) -> bool:
	return _land.size() >= 3 and Geometry2D.is_point_in_polygon(Vector2(position.x, position.z), _land)


## Escala o polígono a partir do centróide (praça ampliada mantendo o formato).
func _ampliar_poligono(points: PackedVector2Array, fator: float) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var centro := Vector2.ZERO
	for point in points:
		centro += point
	centro /= float(points.size())
	var ampliado := PackedVector2Array()
	for point in points:
		ampliado.append(centro + (point - centro) * fator)
	return ampliado


func get_feature_center(feature_name: String, kind: String = "") -> Vector3:
	for feature in _features:
		if feature.get("name", "") != feature_name:
			continue
		if not kind.is_empty() and feature.get("kind", "") != kind:
			continue
		var points := _to_points(feature.get("coordinates_m", []))
		if points.is_empty():
			continue
		var center := Vector2.ZERO
		for point in points:
			center += point
		center /= float(points.size())
		return ground_position(Vector3(center.x, 0.0, center.y))
	return Vector3.ZERO


## Caminho gerado entre a costa e um marco no mar, usado para alinhar o modelo do píer.
func shore_access_route(landmark_name: String) -> PackedVector2Array:
	for access in _shore_access_routes:
		if String(access.get("name", "")) == landmark_name:
			return access["points"]
	return PackedVector2Array()


## Usa a projeção gerada do KML local para converter latitude/longitude em unidades Godot.
func wgs84_to_world(latitude: float, longitude: float) -> Vector3:
	if _projection.is_empty():
		push_error("A projeção geográfica da região não está disponível.")
		return Vector3.INF
	var x := (longitude - float(_projection["origin_lon"])) * float(_projection["meters_per_degree_lon"])
	var z := (float(_projection["origin_lat"]) - latitude) * float(_projection["meters_per_degree_lat"])
	return ground_position(Vector3(x / _meters_per_unit, 0.0, z / _meters_per_unit))


## Afasta um ponto do eixo da rua, mantendo-o no mesmo lado em que já estava.
func position_beside_road(reference: Vector3, road_name: String, distance_from_center: float) -> Vector3:
	var source := Vector2(reference.x, reference.z)
	var nearest := Vector2.ZERO
	var side := Vector2.ZERO
	var best_distance_squared := INF
	for road in _roads:
		if road.name != road_name:
			continue
		var points: PackedVector2Array = road.points
		for index in range(points.size() - 1):
			var segment := points[index + 1] - points[index]
			var length_squared := segment.length_squared()
			if length_squared < 0.0001:
				continue
			var fraction := clampf((source - points[index]).dot(segment) / length_squared, 0.0, 1.0)
			var closest := points[index] + segment * fraction
			var distance_squared := source.distance_squared_to(closest)
			if distance_squared < best_distance_squared:
				best_distance_squared = distance_squared
				nearest = closest
			side = Vector2(-segment.y, segment.x).normalized()
	if best_distance_squared == INF:
		push_error("Rua não encontrada para posicionar construção: " + road_name)
		return reference
	if (source - nearest).dot(side) < 0.0:
		side = -side
	var placed := nearest + side * distance_from_center
	return ground_position(Vector3(placed.x, 0.0, placed.y))


func surface_at(world_position: Vector3) -> String:
	var point := Vector2(world_position.x, world_position.z)
	var areia := _units(13.0, 4.5)
	# As caixas antes da distância: a da costa crescida da faixa de areia, e a da rua,
	# que já tem meia largura, de mais 1 u. Ponto fora delas não está a essa distância.
	if _costa_limites.grow(areia).has_point(point) and _distance_to_line(point, _coast) < areia:
		return "areia"
	for road in _roads:
		if road.bounds.grow(1.0).has_point(point) and _distance_to_line(point, road.points) < road.width * 0.5 + 1.0:
			return "terra"
	if not _land.is_empty() and not Geometry2D.is_point_in_polygon(point, _land):
		return "agua" if _background_kind == "sea" else "grama"
	return "grama"


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Arquivo de mapa ausente: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("JSON de mapa inválido: " + path)
		return {}
	return parsed


func _clear_region() -> void:
	for child in get_children():
		child.queue_free()
	landmarks.clear()
	areas.clear()
	_features.clear()
	_projection.clear()
	_roads.clear()
	_rivers.clear()
	_shore_access_routes.clear()
	_point_positions.clear()
	_elevation_samples.clear()
	_alturas_vertices.clear()
	_open_areas.clear()
	_road_junctions.clear()
	_tree_trunks.clear()
	_tree_collision_pool.clear()
	_tree_collision_elapsed = 0.0
	_blocos_vegetacao_lod.clear()
	_camera_de_mapa = false
	_map_frame = Rect2()
	_background_kind = "land"
	_land.clear()
	_forest.clear()
	_kml_forest.clear()
	_village.clear()
	_coast.clear()


func _to_points(coordinates: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for coordinate in coordinates:
		if coordinate is Array and coordinate.size() >= 2:
			var point := Vector2(float(coordinate[0]), float(coordinate[1])) / _meters_per_unit
			if result.is_empty() or result[-1].distance_squared_to(point) > 0.0001:
				result.append(point)
	if result.size() > 2 and result[0].distance_squared_to(result[-1]) < 0.0001:
		result.remove_at(result.size() - 1)
	return result


func _points_bounds(points: PackedVector2Array) -> Rect2:
	var result := Rect2(points[0], Vector2.ZERO)
	for point in points:
		result = result.expand(point)
	return result


func _material(color: Color, roughness: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## Material com textura repetida; `world_tile_units` > 0 projeta a textura pelo mundo (X/Z) a cada N unidades.
func _textured_material(texture: Texture2D, tint: Color, world_tile_units: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = tint
	material.roughness = 0.94
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_repeat = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if world_tile_units > 0.0:
		# _add_up_triangle grava UV = posição / 10; reescala para o tamanho de ladrilho pedido.
		material.uv1_scale = Vector3.ONE * (10.0 / world_tile_units)
	return material


## Projeta o chão usando coordenadas do mundo, sem depender dos UVs da malha.
## Assim cada fragmento acompanha o relevo e a textura não se perde nas subdivisões.
func _terrain_texture_material(texture: Texture2D, tile_units: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D terrain_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float tile_size = 8.0;
uniform vec3 tint : source_color = vec3(1.0);
varying vec2 world_xz;

void vertex() {
	vec3 world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_xz = world_vertex.xz;
}

void fragment() {
	ALBEDO = texture(terrain_texture, world_xz / tile_size).rgb * tint;
	ROUGHNESS = 0.94;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("terrain_texture", texture)
	material.set_shader_parameter("tile_size", maxf(tile_units, 0.1))
	material.set_shader_parameter("tint", TINTA_GRAMA)
	return material


## Mistura os materiais reais de estrada e mata ao longo do acostamento.
## As bordas externas usam a mesma projeção do terreno; as internas coincidem
## com o UV da estrada para nao criar uma linha de cor entre as malhas.
func _road_shoulder_material(road_ratio: float, road_tint: Color) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D forest_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D road_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float forest_tile_size = 12.0;
uniform float road_fraction = 0.65;
uniform vec4 road_tint : source_color = vec4(1.0);
uniform vec3 forest_tint : source_color = vec3(1.0);
varying vec2 shoulder_uv;
varying vec2 world_xz;

void vertex() {
	shoulder_uv = UV;
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 fraction = fract(point);
	fraction = fraction * fraction * (3.0 - 2.0 * fraction);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, fraction.x), mix(c, d, fraction.x), fraction.y);
}

void fragment() {
	float shoulder_span = max((1.0 - road_fraction) * 0.5, 0.001);
	float local_u = shoulder_uv.x < 0.5
		? shoulder_uv.x / shoulder_span
		: (1.0 - shoulder_uv.x) / shoulder_span;
	float road_u = (shoulder_uv.x - shoulder_span) / max(road_fraction, 0.001);
	float road_v = shoulder_uv.y / max(road_fraction, 0.001);
	vec3 forest = texture(forest_texture, world_xz / forest_tile_size).rgb * forest_tint;
	vec3 road = texture(road_texture, vec2(road_u, road_v)).rgb * road_tint.rgb;
	float organic_offset = (value_noise(world_xz * 0.28) - 0.5) * 0.28;
	float blend_start = 0.39 + organic_offset;
	float blend = smoothstep(blend_start, blend_start + 0.36, clamp(local_u, 0.0, 1.0));
	ALBEDO = mix(forest, road, blend);
	ROUGHNESS = 0.94;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("forest_texture", GRAMA_TERRA_MATA_TEXTURE)
	material.set_shader_parameter("forest_tile_size", 12.0)
	material.set_shader_parameter("forest_tint", TINTA_GRAMA)
	material.set_shader_parameter("road_texture", ESTRADA_OCRE_TEXTURE)
	material.set_shader_parameter("road_fraction", clampf(road_ratio, 0.1, 0.9))
	material.set_shader_parameter("road_tint", road_tint)
	return material


func _build_background() -> void:
	# O fundo ultrapassa a borda da região para a vista aérea não revelar um retângulo vazio.
	if _background_kind == "sea" and not _bathymetry.is_empty():
		Mar.montar(self, _bathymetry, SEA_SURFACE_Y, _meters_per_unit, _bounds.grow(4000.0), get_map_frame())
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(_bounds.size.x + 8000.0, 0.3, _bounds.size.y + 8000.0)
	mesh.material = _material(SEA_COLOR, 0.36) if _background_kind == "sea" else _material(LAND_COLOR)
	var center := _bounds.get_center()
	var visual := MeshInstance3D.new()
	visual.name = "Mar" if _background_kind == "sea" else "Terreno distante"
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.position = Vector3(center.x, SEA_SURFACE_Y - mesh.size.y * 0.5, center.y)
	add_child(visual)


func _add_polygon(label: String, points: PackedVector2Array, y: float, color: Color, with_collision: bool = false, material_override: Material = null, pausavel: bool = false) -> void:
	if points.size() < 3:
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material_override if material_override != null else _material(color))
	# Triangulate the full polygon, then subdivide triangles to follow terrain height.
	# Cell-by-cell clipping had fragmented the visual ground on uneven areas.
	await _add_draped_polygon(surface, points, y, pausavel)
	var mesh := surface.commit()
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	add_child(visual)
	if with_collision:
		var body := StaticBody3D.new()
		body.name = "Colisão da terra"
		var collision := CollisionShape3D.new()
		collision.name = "Forma"
		var shape := mesh.create_trimesh_shape()
		shape.backface_collision = true
		collision.shape = shape
		body.add_child(collision)
		add_child(body)


func _add_draped_polygon(surface: SurfaceTool, points: PackedVector2Array, offset_y: float, pausavel: bool = false) -> void:
	var indices := Geometry2D.triangulate_polygon(points)
	for i in range(0, indices.size(), 3):
		_add_draped_triangle(surface, points[indices[i]], points[indices[i + 1]], points[indices[i + 2]], offset_y)
		if pausavel:
			# O terreno é a parte mais demorada: progresso de 0,05 a 0,38.
			await _marcar(0.05 + 0.33 * float(i) / float(indices.size()), "Moldando o terreno", false)


func _add_draped_triangle(surface: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, offset_y: float, depth: int = 0) -> void:
	# Divide a maior aresta até que a superfície siga a curvatura interpolada.
	var ab := a.distance_squared_to(b)
	var bc := b.distance_squared_to(c)
	var ca := c.distance_squared_to(a)
	if depth < 18 and maxf(ab, maxf(bc, ca)) > TERRAIN_CELL_SIZE * TERRAIN_CELL_SIZE * 2.0:
		if ab >= bc and ab >= ca:
			var middle := (a + b) * 0.5
			_add_draped_triangle(surface, a, middle, c, offset_y, depth + 1)
			_add_draped_triangle(surface, middle, b, c, offset_y, depth + 1)
		elif bc >= ca:
			var middle := (b + c) * 0.5
			_add_draped_triangle(surface, a, b, middle, offset_y, depth + 1)
			_add_draped_triangle(surface, a, middle, c, offset_y, depth + 1)
		else:
			var middle := (c + a) * 0.5
			_add_draped_triangle(surface, a, b, middle, offset_y, depth + 1)
			_add_draped_triangle(surface, middle, b, c, offset_y, depth + 1)
		return
	_add_up_triangle(surface, Vector3(a.x, _altura_vertice(a) + offset_y, a.y), Vector3(b.x, _altura_vertice(b) + offset_y, b.y), Vector3(c.x, _altura_vertice(c) + offset_y, c.y))


func _altura_vertice(ponto: Vector2) -> float:
	var altura: Variant = _alturas_vertices.get(ponto)
	if altura == null:
		altura = ground_height_at(Vector3(ponto.x, 0, ponto.y))
		_alturas_vertices[ponto] = altura
	return altura


func _add_up_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	if (b - a).cross(c - a).y < 0.0:
		var swapped := b
		b = c
		c = swapped
	var normal := (b - a).cross(c - a).normalized()
	# a, c, b: horário visto de cima, a face da frente no Godot. Na ordem a, b, c o
	# material sem descarte de faces via o verso, invertia a normal e o chão só
	# recebia sol e lua por baixo.
	for vertex in [a, c, b]:
		surface.set_normal(normal)
		surface.set_uv(Vector2(vertex.x, vertex.z) / 10.0)
		surface.add_vertex(vertex)


## Triângulo com UVs explícitos (u atravessa a faixa, v acompanha o percurso).
func _add_up_triangle_uv(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2) -> void:
	if (b - a).cross(c - a).y < 0.0:
		var swapped := b
		b = c
		c = swapped
		var swapped_uv := uv_b
		uv_b = uv_c
		uv_c = swapped_uv
	var normal := (b - a).cross(c - a).normalized()
	# a, c, b: face da frente para cima (ver _add_up_triangle).
	for i in range(3):
		surface.set_normal(normal)
		surface.set_uv([uv_a, uv_c, uv_b][i])
		surface.add_vertex([a, c, b][i])


func _triangle_uv_at(point: Vector2, a: Vector2, b: Vector2, c: Vector2, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2) -> Vector2:
	var ab := b - a
	var ac := c - a
	var denominator := ab.cross(ac)
	if absf(denominator) < 0.000001:
		return uv_a
	var ap := point - a
	var weight_b := ap.cross(ac) / denominator
	var weight_c := ab.cross(ap) / denominator
	return uv_a * (1.0 - weight_b - weight_c) + uv_b * weight_b + uv_c * weight_c


## Corta a superfície na costa para que o rio norte nunca cubra o oceano.
func _add_land_clipped_triangle_uv(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2, y: float) -> void:
	var pa := Vector2(a.x, a.z)
	var pb := Vector2(b.x, b.z)
	var pc := Vector2(c.x, c.z)
	if Geometry2D.is_point_in_polygon(pa, _land) and Geometry2D.is_point_in_polygon(pb, _land) and Geometry2D.is_point_in_polygon(pc, _land):
		_add_up_triangle_uv(surface, a, b, c, uv_a, uv_b, uv_c)
		return
	for polygon in Geometry2D.intersect_polygons(PackedVector2Array([pa, pb, pc]), _land):
		var indices := Geometry2D.triangulate_polygon(polygon)
		for i in range(0, indices.size(), 3):
			var p0: Vector2 = polygon[indices[i]]
			var p1: Vector2 = polygon[indices[i + 1]]
			var p2: Vector2 = polygon[indices[i + 2]]
			var v0 := ground_position(Vector3(p0.x, 0, p0.y), y)
			var v1 := ground_position(Vector3(p1.x, 0, p1.y), y)
			var v2 := ground_position(Vector3(p2.x, 0, p2.y), y)
			var t0 := _triangle_uv_at(p0, pa, pb, pc, uv_a, uv_b, uv_c)
			var t1 := _triangle_uv_at(p1, pa, pb, pc, uv_a, uv_b, uv_c)
			var t2 := _triangle_uv_at(p2, pa, pb, pc, uv_a, uv_b, uv_c)
			_add_up_triangle_uv(surface, v0, v1, v2, t0, t1, t2)


func _road_width(feature: Dictionary) -> float:
	var name := String(feature.get("name", ""))
	if name == "Rua Principal":
		return _units(11.0, 4.6)
	if name == "Rua do mirante":
		return _units(4.2, 2.6)
	return _units(5.0, 3.2)


func _build_shore_access() -> void:
	for landmark in landmarks:
		var destination := Vector2(landmark.position.x, landmark.position.z)
		if Geometry2D.is_point_in_polygon(destination, _land):
			continue
		var shore := _nearest_land_edge(destination)
		var inland := (shore - destination).normalized()
		var route := PackedVector2Array([shore + inland * _units(6.0, 3.0), destination])
		var width := _units(4.5, 3.0)
		_shore_access_routes.append({"name": String(landmark.name), "points": route, "width": width, "bounds": _points_bounds(route).grow(width * 0.5)})
		# Pontos do rio podem ficar fora da costa no KML, mas isso nÃ£o representa
		# um acesso construÃ­do. NÃ£o desenha a faixa ocre (nem sua colisÃ£o) no mar.
		if String(landmark.name) != "Pier" and String(landmark.name) != "Rio":
			_add_ribbon("Acesso " + String(landmark.name), route, width, 0.058, SHORE_ACCESS_COLOR, true)


func _nearest_land_edge(point: Vector2) -> Vector2:
	var closest := _land[0]
	var best_distance := INF
	for i in range(_land.size()):
		var a := _land[i]
		var b := _land[(i + 1) % _land.size()]
		var segment := b - a
		if segment.length_squared() < 0.000001:
			continue
		var fraction := clampf((point - a).dot(segment) / segment.length_squared(), 0.0, 1.0)
		var candidate := a + segment * fraction
		var distance := point.distance_squared_to(candidate)
		if distance < best_distance:
			best_distance = distance
			closest = candidate
	return closest


## O KML traz as ruas como linhas quebradas, com cantos vivos. Chaikin (corta cada canto
## a 1/4 e 3/4 do trecho, ROAD_CURVE_PASSES vezes, com o corte limitado a
## ROAD_CURVE_MAX_CUT) as deixa em curvas de estrada de terra, mantendo as pontas. Depois
## a ponta de cada rua é reemendada na rua vizinha que ela tocava.
const ROAD_CURVE_PASSES := 3
const ROAD_CURVE_MAX_CUT := 25.0
const ROAD_JOIN_DISTANCE := 15.0


func _curve_roads() -> void:
	for road in _roads:
		road.points = _chaikin(road.points)
	# O rio do KML também vem em segmentos retos com quinas: as mesmas curvas.
	for river in _rivers:
		river.points = _river_path_on_land(_chaikin(river.points))
		river.bounds = _points_bounds(river.points).grow(float(river.width) * 0.5 + _units(12.0, 3.0) + 1.0)
	# A foz maior continua alargando, mas toda a calha do rio norte fica 20% mais estreita.
	for river in _rivers:
		if _is_northern_river(river):
			river.width = float(river.width) * NORTHERN_RIVER_WIDTH_FACTOR
			river.bounds = _points_bounds(river.points).grow(float(river.width) * 0.5 + _units(12.0, 3.0) + 1.0)
	for road in _roads:
		var points: PackedVector2Array = road.points
		for tip_index in [0, points.size() - 1]:
			var tip := points[tip_index]
			var best := tip
			var best_distance := ROAD_JOIN_DISTANCE
			for other in _roads:
				if other == road:
					continue
				var other_points: PackedVector2Array = other.points
				for i in other_points.size() - 1:
					var candidate := Geometry2D.get_closest_point_to_segment(tip, other_points[i], other_points[i + 1])
					var distance := candidate.distance_to(tip)
					if distance < best_distance:
						best_distance = distance
						best = candidate
			if best != tip:
				_road_junctions.append({"point": best, "width": float(road.width)})
			points[tip_index] = best
		road.points = points
		road.bounds = _points_bounds(points).grow(float(road.width) * 0.5)


## O KML do rio norte começa no mar; encontra o último ponto em terra da travessia.
func _landward_shore_point(inside: Vector2, outside: Vector2) -> Vector2:
	var land := inside
	var sea := outside
	for step in 20:
		var middle := (land + sea) * 0.5
		if Geometry2D.is_point_in_polygon(middle, _land):
			land = middle
		else:
			sea = middle
	return land


func _river_path_on_land(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 2 or _land.size() < 3:
		return points
	var first := 0
	while first < points.size() and not Geometry2D.is_point_in_polygon(points[first], _land):
		first += 1
	if first >= points.size():
		return PackedVector2Array()
	var last := points.size() - 1
	while last > first and not Geometry2D.is_point_in_polygon(points[last], _land):
		last -= 1
	var on_land := PackedVector2Array()
	if first > 0:
		on_land.append(_landward_shore_point(points[first], points[first - 1]))
	for i in range(first, last + 1):
		on_land.append(points[i])
	if last < points.size() - 1:
		on_land.append(_landward_shore_point(points[last], points[last + 1]))
	return on_land


func _is_northern_river(river: Dictionary) -> bool:
	if _rivers.size() < 2:
		return false
	var north_z := INF
	for other in _rivers:
		if other.points.size() >= 2:
			var other_bounds: Rect2 = other.bounds
			north_z = minf(north_z, other_bounds.get_center().y)
	var river_bounds: Rect2 = river.bounds
	return river.points.size() >= 2 and river_bounds.get_center().y <= north_z + 0.01


## Remendo de terra batida em cada cruzamento: um disco drapeado no chão, acima das
## duas ruas, com a textura da estrada projetada pelo mundo e a borda irregular.
func _build_road_junctions() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_back;

uniform sampler2D road_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 center;
uniform float radius = 3.0;
varying vec2 world_xz;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 c = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(c), hash21(c + vec2(1.0, 0.0)), f.x), mix(hash21(c + vec2(0.0, 1.0)), hash21(c + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	ALBEDO = texture(road_texture, world_xz / 6.0).rgb * tint.rgb;
	ROUGHNESS = 0.95;
	float edge = distance(world_xz, center) / radius + (value_noise(world_xz * 0.9) - 0.5) * 0.35;
	ALPHA = 1.0 - step(1.0, edge);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""
	for junction in _road_junctions:
		var center: Vector2 = junction.point
		var radius: float = float(junction.width) * 0.8
		var circle := PackedVector2Array()
		for i in 16:
			circle.append(center + Vector2.RIGHT.rotated(TAU * i / 16.0) * radius * 1.2)
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("road_texture", ESTRADA_OCRE_TEXTURE)
		material.set_shader_parameter("tint", Color("f7e7c6"))
		material.set_shader_parameter("center", center)
		material.set_shader_parameter("radius", radius)
		_add_polygon("Cruzamento", circle, 0.07, ROAD_COLOR, false, material)


func _chaikin(points: PackedVector2Array) -> PackedVector2Array:
	var current := points
	for pass_index in ROAD_CURVE_PASSES:
		if current.size() < 3:
			return current
		var next := PackedVector2Array([current[0]])
		for i in current.size() - 1:
			var a := current[i]
			var b := current[i + 1]
			var length := a.distance_to(b)
			if length < 0.001:
				continue
			var cut := minf(0.25, ROAD_CURVE_MAX_CUT / length)
			if i > 0:
				next.append(a.lerp(b, cut))
			if i < current.size() - 2:
				next.append(b.lerp(a, cut))
		next.append(current[current.size() - 1])
		current = next
	return current


func _soften_road_corners(points: PackedVector2Array, width: float) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var softened := PackedVector2Array([points[0]])
	for i in range(1, points.size() - 1):
		var corner := points[i]
		var incoming := corner - points[i - 1]
		var outgoing := points[i + 1] - corner
		var cut := minf(width * 0.45, minf(incoming.length(), outgoing.length()) * 0.25)
		if cut <= 0.05 or incoming.length_squared() < 0.0001 or outgoing.length_squared() < 0.0001:
			softened.append(corner)
			continue
		var before := corner - incoming.normalized() * cut
		var after := corner + outgoing.normalized() * cut
		if softened[-1].distance_squared_to(before) > 0.0001:
			softened.append(before)
		for step in range(1, 5):
			var t := float(step) / 4.0
			var inverse := 1.0 - t
			var rounded := before * inverse * inverse + corner * 2.0 * inverse * t + after * t * t
			if softened[-1].distance_squared_to(rounded) > 0.0001:
				softened.append(rounded)
	if softened[-1].distance_squared_to(points[-1]) > 0.0001:
		softened.append(points[-1])
	return softened


## Rebaixa a estrada dentro da calha, inclusive sua colisão, sem afetar o acesso nas margens.
func _road_height_under_rivers(point: Vector2, height: float) -> float:
	var result := height
	for river in _rivers:
		var bounds: Rect2 = river.bounds
		if not bounds.has_point(point):
			continue
		var inner_radius := float(river.width) * 0.5 + 0.5
		var outer_radius := float(river.width) * 0.5 + _units(12.0, 3.0) - 0.2
		var distance := _distance_to_line(point, river.points)
		var submerge := 1.0 - smoothstep(inner_radius, outer_radius, distance)
		result = minf(result, lerpf(height, -0.03, submerge))
	return result


## Faixa ao longo de `points`, `y` acima do chão; `y_right` (se dado) é a altura do lado
## direito, para faixas em rampa como a praia entrando na água.
func _add_ribbon(label: String, points: PackedVector2Array, width: float, y: float, color: Color, with_collision: bool = false, material_override: Material = null, y_right: float = NAN, cross_steps: int = 1, segment_size: float = SURFACE_SEGMENT_SIZE, channel_fraction: float = 0.0, width_profile: Variant = null, lower_under_rivers: bool = false, clip_to_land: bool = false) -> void:
	if points.size() < 2:
		return
	var widths := PackedFloat32Array()
	if width_profile is PackedFloat32Array:
		widths = width_profile
	var has_profile := widths.size() == points.size()
	var sampled := PackedVector2Array([points[0]])
	var sampled_widths := PackedFloat32Array()
	sampled_widths.append(widths[0] if has_profile else width)
	for i in range(points.size() - 1):
		var divisions := maxi(1, ceili(points[i].distance_to(points[i + 1]) / maxf(segment_size, 0.1)))
		for step in range(1, divisions + 1):
			var t := float(step) / float(divisions)
			sampled.append(points[i].lerp(points[i + 1], t))
			sampled_widths.append(lerpf(widths[i], widths[i + 1], t) if has_profile else width)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var along := PackedFloat32Array()
	var travelled := 0.0
	for i in range(sampled.size()):
		if i > 0:
			travelled += sampled[i].distance_to(sampled[i - 1])
		along.append(travelled / maxf(width, 0.01))
		var previous := (sampled[i] - sampled[maxi(i - 1, 0)]).normalized()
		var following := (sampled[mini(i + 1, sampled.size() - 1)] - sampled[i]).normalized()
		if previous == Vector2.ZERO:
			previous = following
		if following == Vector2.ZERO:
			following = previous
		var before := Vector2(-previous.y, previous.x)
		var after := Vector2(-following.y, following.x)
		var miter := (before + after).normalized()
		if miter == Vector2.ZERO:
			miter = after
		var denominator := maxf(absf(miter.dot(after)), 0.45)
		var local_width := sampled_widths[i]
		var offset := miter * minf(local_width * 0.5 / denominator, local_width)
		left.append(sampled[i] + offset)
		right.append(sampled[i] - offset)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material_override if material_override != null else _material(color))
	var cross_positions := PackedFloat32Array()
	if channel_fraction > 0.0:
		var canal_esquerdo := (1.0 - channel_fraction) * 0.5
		var canal_direito := (1.0 + channel_fraction) * 0.5
		for passo in range(5):
			cross_positions.append(lerpf(0.0, canal_esquerdo, float(passo) / 4.0))
		for passo in range(1, maxi(cross_steps, 1) + 1):
			cross_positions.append(lerpf(canal_esquerdo, canal_direito, float(passo) / float(maxi(cross_steps, 1))))
		for passo in range(1, 5):
			cross_positions.append(lerpf(canal_direito, 1.0, float(passo) / 4.0))
	else:
		for passo in range(maxi(cross_steps, 1) + 1):
			cross_positions.append(float(passo) / float(maxi(cross_steps, 1)))
	# Cada vértice da faixa medido UMA vez: a célula vizinha repete os mesmos pontos, e
	# ground_position (IDW + distância à costa) era pedido quatro vezes por vértice.
	var colunas := cross_positions.size()
	var grade := PackedVector3Array()
	grade.resize(sampled.size() * colunas)
	for i in range(sampled.size()):
		for j in range(colunas):
			var t_j := cross_positions[j]
			var ponta := left[i].lerp(right[i], t_j)
			var base := lerpf(y, y_right, t_j) if not is_nan(y_right) else y
			var altura := _road_height_under_rivers(ponta, base) if lower_under_rivers else base
			grade[i * colunas + j] = ground_position(Vector3(ponta.x, 0, ponta.y), altura)
	for i in range(sampled.size() - 1):
		for lateral_index in range(colunas - 1):
			var t_a := cross_positions[lateral_index]
			var t_b := cross_positions[lateral_index + 1]
			var a := grade[i * colunas + lateral_index]
			var b := grade[i * colunas + lateral_index + 1]
			var c := grade[(i + 1) * colunas + lateral_index]
			var d := grade[(i + 1) * colunas + lateral_index + 1]
			if material_override != null:
				var uv_a := Vector2(t_a, along[i])
				var uv_b := Vector2(t_b, along[i])
				var uv_c := Vector2(t_a, along[i + 1])
				var uv_d := Vector2(t_b, along[i + 1])
				if clip_to_land:
					_add_land_clipped_triangle_uv(surface, a, b, c, uv_a, uv_b, uv_c, y)
					_add_land_clipped_triangle_uv(surface, c, b, d, uv_c, uv_b, uv_d, y)
				else:
					_add_up_triangle_uv(surface, a, b, c, uv_a, uv_b, uv_c)
					_add_up_triangle_uv(surface, c, b, d, uv_c, uv_b, uv_d)
			else:
				_add_up_triangle(surface, a, b, c)
				_add_up_triangle(surface, c, b, d)
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = surface.commit()
	add_child(visual)
	if with_collision:
		var body := StaticBody3D.new()
		body.name = "Colisão " + label
		var collision := CollisionShape3D.new()
		var shape := visual.mesh.create_trimesh_shape()
		shape.backface_collision = true
		collision.shape = shape
		body.add_child(collision)
		add_child(body)


## Praia: faixa de areia centrada na costa que desce em rampa para dentro d'água (o lado
## do mar fica abaixo da superfície), sem degrau entre o fundo do mar e a areia.
func _add_beach() -> void:
	if _coast.size() < 2:
		return
	var width := _units(22.0, 8.0)
	var coast := _coast
	# _add_ribbon põe a esquerda em +normal: a terra precisa ficar à esquerda.
	var direction := (coast[1] - coast[0]).normalized()
	var left_side := coast[0] + Vector2(-direction.y, direction.x) * width * 0.5
	if not Geometry2D.is_point_in_polygon(left_side, _land):
		coast = coast.duplicate()
		coast.reverse()
	var material := ShaderMaterial.new()
	material.shader = AREIA_PRAIA
	material.set_shader_parameter("textura_areia", AREIA_TEXTURE)
	# A faixa úmida acompanha a maré: o material recebe "mare_offset_m" do Mare.
	var mare := get_node_or_null("/root/Mare")
	if mare != null:
		mare.call("registrar_material", material)
	_add_ribbon("Orla de areia", coast, width, 0.075, BEACH_COLOR, true, material, -0.06)


## Rios que terminam perto da costa seguem até o mar: a foz atravessa a areia e a água
## do rio se desfaz na do mar.
func _tem_foz_no_extremo(points: PackedVector2Array, from_end: bool) -> bool:
	if _background_kind != "sea" or _land.size() < 3 or points.size() < 2:
		return false
	var tip: Vector2 = points[points.size() - 1] if from_end else points[0]
	return _distance_to_line(tip, _coast) <= _units(60.0, 15.0) and Geometry2D.is_point_in_polygon(tip, _land)


func _mouth_approach_on_river(points: PackedVector2Array, from_end: bool, distance: float) -> PackedVector2Array:
	var inland := points.duplicate()
	if from_end:
		inland.reverse()
	var approach := PackedVector2Array([inland[0]])
	var walked := 0.0
	for i in range(inland.size() - 1):
		var segment := inland[i].distance_to(inland[i + 1])
		if segment < 0.0001:
			continue
		var portion := minf(1.0, (distance - walked) / segment)
		approach.append(inland[i].lerp(inland[i + 1], portion))
		walked += segment * portion
		if walked >= distance - 0.0001:
			break
	approach.reverse()
	return approach


func _add_river_mouths() -> void:
	if _background_kind != "sea" or _land.size() < 3:
		return
	for river in _rivers:
		var points: PackedVector2Array = river.points
		if points.size() < 2:
			continue
		var northern := _is_northern_river(river)
		var comprimento_rio := 0.0
		for i in range(points.size() - 1):
			comprimento_rio += points[i].distance_to(points[i + 1])
		for from_end in [true, false]:
			var tip: Vector2 = points[points.size() - 1] if from_end else points[0]
			var before: Vector2 = points[points.size() - 2] if from_end else points[1]
			if not _tem_foz_no_extremo(points, from_end):
				continue
			var mouth := PackedVector2Array()
			var shore_length := 0.0
			var tail := 0.0
			if northern:
				mouth = _mouth_approach_on_river(points, from_end, _units(100.0, 25.0))
			else:
				var direction := (tip - before).normalized()
				if direction == Vector2.ZERO:
					continue
				mouth = PackedVector2Array([tip - direction * float(river.width), tip])
				var point := tip
				for step in 200:
					point += direction
					mouth.append(point)
					if not Geometry2D.is_point_in_polygon(point, _land):
						break
				shore_length = mouth[0].distance_to(point)
				tail = _units(24.0, 6.0)
				for step in range(1, 7):
					mouth.append(point + direction * tail * float(step) / 6.0)
			if mouth.size() < 2:
				continue
			var length := 0.0
			for i in range(mouth.size() - 1):
				length += mouth[i].distance_to(mouth[i + 1])
			if northern:
				shore_length = length
			var mouth_widths := PackedFloat32Array()
			var flare_length := length if northern else maxf(shore_length - float(river.width) + tail * 0.7, float(river.width) * 1.5)
			var traveled := 0.0
			for i in range(mouth.size() - 1):
				var widening := clampf((traveled if northern else traveled - float(river.width)) / flare_length, 0.0, 1.0)
				widening = widening * widening * (3.0 - 2.0 * widening)
				mouth_widths.append(float(river.width) * (1.0 + (2.6 if northern else 1.2) * widening))
				traveled += mouth[i].distance_to(mouth[i + 1])
			var widening_final := clampf((length if northern else length - float(river.width)) / flare_length, 0.0, 1.0)
			widening_final = widening_final * widening_final * (3.0 - 2.0 * widening_final)
			mouth_widths.append(float(river.width) * (1.0 + (2.6 if northern else 1.2) * widening_final))
			var material := ShaderMaterial.new()
			material.shader = FOZ_RIO
			material.set_shader_parameter("ondas_a", Mar.textura_ruido("ondas_a", 0.035, true))
			material.set_shader_parameter("ondas_b", Mar.textura_ruido("ondas_b", 0.05, true))
			material.set_shader_parameter("comprimento", length / float(river.width))
			material.set_shader_parameter("inicio_sumir", 0.72 if northern else clampf((shore_length - float(river.width) * 0.15) / length, 0.25, 0.82))
			material.set_shader_parameter("entrada_suave", 0.62 if northern else float(river.width) / length)
			material.set_shader_parameter("limite_na_costa", northern)
			var overlap_lengths := length / float(river.width) if northern else 1.0
			material.set_shader_parameter("deslocamento_percurso", comprimento_rio / float(river.width) - overlap_lengths if from_end else overlap_lengths)
			material.set_shader_parameter("sentido_percurso", 1.0 if from_end else -1.0)
			_add_ribbon("Foz do rio", mouth, float(river.width), 0.10, RIVER_COLOR, false, material, NAN, 10, 1.0, 0.0, mouth_widths, false, northern)


func _distance_to_line(point: Vector2, line: PackedVector2Array) -> float:
	if line.size() < 2:
		return INF
	var closest := INF
	for i in range(line.size() - 1):
		var segment := line[i + 1] - line[i]
		if segment.length_squared() < 0.000001:
			continue
		var t := clampf((point - line[i]).dot(segment) / segment.length_squared(), 0.0, 1.0)
		closest = minf(closest, point.distance_to(line[i] + segment * t))
	return closest


func _build_forest(configuration: Dictionary) -> void:
	if _forest.size() < 3 and _kml_forest.size() < 3:
		return
	var target := maxi(int(configuration.get("tree_count", 1800)), 0)
	if target == 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(configuration.get("seed", 1887))
	var clearing := _units(float(configuration.get("clearing_m", 8.0)), 2.5)
	var positions: Array[Vector2] = []
	var occupied := {}
	var cell_size := _units(12.0, 3.6)
	var coast_clearing := _units(18.0, 5.0)
	var interest_clearing := _units(16.0, 6.0)
	var attempts := 0
	while positions.size() < target and attempts < target * 35:
		attempts += 1
		if attempts % 200 == 0:
			await _marcar(0.5 + 0.2 * float(positions.size()) / float(target), "Plantando a mata", false)
		var point := Vector2(
			rng.randf_range(_bounds.position.x, _bounds.end.x),
			rng.randf_range(_bounds.position.y, _bounds.end.y)
		)
		var in_scenic_forest := _forest.size() >= 3 and Geometry2D.is_point_in_polygon(point, _forest)
		var in_kml_forest := _kml_forest.size() >= 3 and Geometry2D.is_point_in_polygon(point, _kml_forest)
		if not in_scenic_forest and not in_kml_forest:
			continue
		if not Geometry2D.is_point_in_polygon(point, _land):
			continue
		# A área "Mata" desenhada no mapa vale mais que o contorno da vila: lá dentro
		# também é mata fechada.
		if not in_kml_forest and _village.size() >= 3 and Geometry2D.is_point_in_polygon(point, _village):
			continue
		if _inside_open_area(point):
			continue
		if _costa_limites.grow(coast_clearing).has_point(point) and _distance_to_line(point, _coast) < coast_clearing:
			continue
		if _near_route(point, clearing) or _near_interest(point, interest_clearing):
			continue
		var cell := Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))
		var crowded := false
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var neighbor := cell + Vector2i(dx, dz)
				if occupied.has(neighbor) and point.distance_squared_to(occupied[neighbor]) < cell_size * cell_size:
					crowded = true
		if crowded:
			continue
		occupied[cell] = point
		positions.append(point)
	if positions.is_empty():
		return
	# Mata fechada e alta do Recôncavo: espécies procedurais com silhuetas distintas,
	# uma MultiMesh por espécie. Modelos do Tripo entram trocando `FloraReconcavo.especie`.
	var by_species: Dictionary = {}
	var lista: Array = ESPECIES_MATA_TRIPO.duplicate() if _estilo_tripo else FloraReconcavo.ESPECIES_MATA
	# As espécies locais novas entram na mistura assim que o GLB do Tripo existe.
	for local in ["aroeira", "jenipapeiro", "piacava"]:
		if _estilo_tripo and CatalogoAssets.tem_tripo(local):
			lista.append(local)
	for i in range(positions.size()):
		var species: String = lista[rng.randi_range(0, lista.size() - 1)]
		if not by_species.has(species):
			by_species[species] = []
		by_species[species].append(positions[i])
	for species in by_species.keys():
		var group: Array = by_species[species]
		var built: Dictionary = _malha_da_especie(species, rng)
		var base: Transform3D = built.base
		var transforms: Array[Transform3D] = []
		for i in range(group.size()):
			if i % 150 == 0:
				await _marcar(0.7 + 0.28 * float(i) / float(maxi(group.size(), 1)), "Plantando a mata", false)
			var point: Vector2 = group[i]
			var scale := rng.randf_range(0.8, 1.25)
			var yaw := rng.randf_range(0.0, TAU)
			var ground := ground_height_at(Vector3(point.x, 0, point.y))
			var transformacao := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3.ONE * scale), Vector3(point.x, ground - ARVORE_AFUNDADA, point.y)) * base
			# `base` centraliza a malha do GLB e desloca a origem local. O ponto
			# de plantio continua sendo `point`; usar transformacao.origin aqui
			# desloca o colisor para fora do tronco visual.
			var tronco: Dictionary = {"point": point, "ground": ground, "height": minf(float(built.altura) * scale, 4.0), "radius": float(built.tronco) * scale, "especie": species}
			if species == "coqueiro":
				tronco["transformacao"] = transformacao
			_tree_trunks.append(tronco)
			# Afundada um palmo: o pé entra no chão em vez de pousar sobre ele.
			transforms.append(transformacao)
		_multimesh_em_blocos("Mata: " + species, built.mesh, transforms, LOD_MATA)
	await _marcar(0.98, "Plantando a mata", false)
	_build_sub_bosque(positions, rng)
	_build_margens_do_rio(rng)
	_build_coast_palms(rng)


## Sub-bosque da Mata Atlântica (helicônias, bromélias, samambaias) espalhado entre as
## árvores da mata: um tufo a cada poucas árvores, deslocado para o vão entre elas.
## Sem colisão (é de passar por dentro) e só no estilo Tripo.
func _build_sub_bosque(arvores_mata: Array[Vector2], rng: RandomNumberGenerator) -> void:
	if not _estilo_tripo or not CatalogoAssets.tem_tripo("sub_bosque"):
		return
	var tufo: Dictionary = _malha_da_especie("sub_bosque", rng)
	var transforms: Array[Transform3D] = []
	for i in range(0, arvores_mata.size(), 3):
		var ponto: Vector2 = arvores_mata[i] + Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(2.0, 4.5)
		if not Geometry2D.is_point_in_polygon(ponto, _land) or _near_route(ponto, _units(4.0, 1.5)):
			continue
		var chao := ground_height_at(Vector3(ponto.x, 0, ponto.y))
		var escala := rng.randf_range(0.7, 1.3)
		transforms.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3.ONE * escala), Vector3(ponto.x, chao - 0.03, ponto.y)) * (tufo.base as Transform3D))
	if not transforms.is_empty():
		_multimesh_em_blocos("Sub-bosque", tufo.mesh, transforms, LOD_SUB_BOSQUE)


## Margens do rio: manguezal (mangue-vermelho) perto da foz e da água salgada, como no
## estuário real de Saubara, e ingazeiros de beira-rio mais para dentro.
func _build_margens_do_rio(rng: RandomNumberGenerator) -> void:
	if not _estilo_tripo:
		return
	var tem_mangue := CatalogoAssets.tem_tripo("mangue")
	var tem_inga := CatalogoAssets.tem_tripo("ingazeiro")
	if not tem_mangue and not tem_inga:
		return
	var mangue: Dictionary = _malha_da_especie("mangue", rng) if tem_mangue else {}
	var inga: Dictionary = _malha_da_especie("ingazeiro", rng) if tem_inga else {}
	var do_mangue: Array[Transform3D] = []
	var do_inga: Array[Transform3D] = []
	var perto_do_mar := _units(70.0, 18.0)
	for river in _rivers:
		var pontos: PackedVector2Array = river.points
		var largura: float = float(river.width)
		var percorrido := 0.0
		var proximo := 0.0
		for i in pontos.size() - 1:
			var a := pontos[i]
			var b := pontos[i + 1]
			var trecho := a.distance_to(b)
			if trecho < 0.01:
				continue
			var direcao := (b - a) / trecho
			var normal := Vector2(-direcao.y, direcao.x)
			while proximo <= percorrido + trecho:
				var base := a + direcao * (proximo - percorrido)
				var no_mangue := tem_mangue and _distance_to_line(base, _coast) < perto_do_mar
				for lado in [-1.0, 1.0]:
					var ponto: Vector2 = base + normal * float(lado) * (largura * 0.5 + rng.randf_range(0.8, 2.5))
					if not Geometry2D.is_point_in_polygon(ponto, _land) or _near_route(ponto, _units(5.0, 2.0)):
						continue
					var chao := ground_height_at(Vector3(ponto.x, 0, ponto.y))
					var escala := rng.randf_range(0.8, 1.2)
					var giro := Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3.ONE * escala)
					if no_mangue:
						do_mangue.append(Transform3D(giro, Vector3(ponto.x, chao - ARVORE_AFUNDADA, ponto.y)) * (mangue.base as Transform3D))
						_tree_trunks.append({"point": ponto, "ground": chao, "height": minf(float(mangue.altura) * escala, 4.0), "radius": float(mangue.tronco) * escala, "especie": "mangue"})
					elif tem_inga and rng.randf() < 0.55:
						do_inga.append(Transform3D(giro, Vector3(ponto.x, chao - ARVORE_AFUNDADA, ponto.y)) * (inga.base as Transform3D))
						_tree_trunks.append({"point": ponto, "ground": chao, "height": minf(float(inga.altura) * escala, 4.0), "radius": float(inga.tronco) * escala, "especie": "ingazeiro"})
				# Mangue fechado perto do mar, ingazeiros esparsos rio acima.
				proximo += rng.randf_range(3.5, 6.0) if no_mangue else rng.randf_range(12.0, 22.0)
			percorrido += trecho
	# Estuário: o manguezal se espalha pela beira da costa dos dois lados de cada foz
	# (até ESTUARIO unidades), rente à água, como na foz real.
	if tem_mangue:
		var estuario := _units(160.0, 30.0)
		for river in _rivers:
			var pontos: PackedVector2Array = river.points
			for ponta in [pontos[0], pontos[pontos.size() - 1]]:
				if _distance_to_line(ponta, _coast) > perto_do_mar:
					continue
				for i in _coast.size() - 1:
					var a := _coast[i]
					var b := _coast[i + 1]
					var trecho := a.distance_to(b)
					if trecho < 0.01 or Geometry2D.get_closest_point_to_segment(ponta, a, b).distance_to(ponta) > estuario:
						continue
					var passos := int(trecho / 4.0)
					for k in passos:
						var base := a.lerp(b, (float(k) + rng.randf()) / float(maxi(passos, 1)))
						if base.distance_to(ponta) > estuario:
							continue
						var normal := Vector2(-(b - a).y, (b - a).x).normalized()
						var ponto: Vector2 = base + normal * rng.randf_range(1.5, 6.0)
						if not Geometry2D.is_point_in_polygon(ponto, _land):
							ponto = base - normal * rng.randf_range(1.5, 6.0)
						if not Geometry2D.is_point_in_polygon(ponto, _land) or _near_route(ponto, _units(5.0, 2.0)):
							continue
						var chao := ground_height_at(Vector3(ponto.x, 0, ponto.y))
						var escala := rng.randf_range(0.75, 1.2)
						do_mangue.append(Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3.ONE * escala), Vector3(ponto.x, chao - ARVORE_AFUNDADA, ponto.y)) * (mangue.base as Transform3D))
						_tree_trunks.append({"point": ponto, "ground": chao, "height": minf(float(mangue.altura) * escala, 4.0), "radius": float(mangue.tronco) * escala, "especie": "mangue"})
	if not do_mangue.is_empty():
		_multimesh_em_blocos("Manguezal", mangue.mesh, do_mangue, LOD_ARVORE_RIO)
	if not do_inga.is_empty():
		_multimesh_em_blocos("Ingazeiros do rio", inga.mesh, do_inga, LOD_ARVORE_RIO)


## Divide instâncias em blocos de BLOCO_MATA: cada bloco vira uma MultiMeshInstance3D
## com AABB pequena, então o Godot descarta blocos fora da câmera, escolhe o LOD
## importado e oculta o bloco quando ele não contribui mais para a paisagem.
func _multimesh_em_blocos(nome: String, mesh: Mesh, transforms: Array[Transform3D], distancia_lod: float = 0.0, registros: Array[int] = []) -> void:
	var blocos: Dictionary = {}
	for indice in range(transforms.size()):
		var t: Transform3D = transforms[indice]
		var chave := Vector2i(floori(t.origin.x / BLOCO_MATA), floori(t.origin.z / BLOCO_MATA))
		if not blocos.has(chave):
			blocos[chave] = []
		blocos[chave].append(indice)
	for chave in blocos.keys():
		var lista: Array = blocos[chave]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = lista.size()
		for i in range(lista.size()):
			multimesh.set_instance_transform(i, transforms[int(lista[i])])
		var visual := MultiMeshInstance3D.new()
		visual.name = "%s %d,%d" % [nome, chave.x, chave.y]
		visual.multimesh = multimesh
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if distancia_lod > 0.0:
			visual.lod_bias = LOD_BIAS
			visual.visibility_range_end = distancia_lod
			visual.visibility_range_end_margin = LOD_MARGEM
		add_child(visual)
		for i in range(lista.size()):
			var indice: int = lista[i]
			if indice >= registros.size():
				continue
			var tronco: Dictionary = _tree_trunks[registros[indice]]
			tronco["visual"] = visual
			tronco["instancia"] = i
			_tree_trunks[registros[indice]] = tronco
		if distancia_lod > 0.0:
			_blocos_vegetacao_lod.append({"visual": visual, "distancia": distancia_lod})


## Coqueiros ao longo da orla, do lado da terra, inclinados para o mar.
func _build_coast_palms(rng: RandomNumberGenerator) -> void:
	if _coast.size() < 2 or _land.size() < 3:
		return
	var spacing := _units(34.0, 9.0)
	var offset_min := _units(6.0, 2.0)
	var offset_max := _units(14.0, 5.0)
	var built: Dictionary = _malha_da_especie("coqueiro", rng)
	var modelo_base: Transform3D = built.base
	var referencias_tronco: Dictionary = CoqueiroCortado.referencias_tronco(built.mesh)
	# Castanholas (amendoeiras-da-praia) se misturam aos coqueiros da orla, como na
	# vila real; só quando o GLB existe.
	# Restinga da orla: além das castanholas, clúsias baixas e piaçavas (Arecaceae
	# e Clusiaceae dominam as restingas da Bahia). Só entram as que têm GLB.
	var restinga: Array[String] = []
	for local in ["castanhola", "castanhola", "clusia", "piacava"]:
		if _estilo_tripo and CatalogoAssets.tem_tripo(local):
			restinga.append(local)
	var malhas_restinga: Dictionary = {}
	var transforms_restinga: Dictionary = {}
	for local in restinga:
		if not malhas_restinga.has(local):
			malhas_restinga[local] = _malha_da_especie(local, rng)
			transforms_restinga[local] = [] as Array[Transform3D]
	var transforms: Array[Transform3D] = []
	var registros_coqueiros: Array[int] = []
	var travelled := 0.0
	var next_at := spacing * 0.5
	for i in range(_coast.size() - 1):
		var a := _coast[i]
		var b := _coast[i + 1]
		var segment := b - a
		var length := segment.length()
		if length < 0.001:
			continue
		var direction := segment / length
		while next_at <= travelled + length:
			var t := (next_at - travelled) / length
			var base := a + segment * t
			var normal := Vector2(-direction.y, direction.x)
			var offset := rng.randf_range(offset_min, offset_max)
			var candidate := base + normal * offset
			if not Geometry2D.is_point_in_polygon(candidate, _land):
				normal = -normal
				candidate = base + normal * offset
			if Geometry2D.is_point_in_polygon(candidate, _land) and not _near_route(candidate, _units(6.0, 2.0)) and not _near_interest(candidate, _units(10.0, 4.0)) and not (_village.size() >= 3 and Geometry2D.is_point_in_polygon(candidate, _village)):
				# O modelo inclina no eixo Z local (-X vai para o topo); gira para o topo apontar ao mar.
				var seaward := -normal
				# Rotação em Y que leva o -X local (para onde o topo pende) até `seaward` no plano XZ.
				var yaw := atan2(seaward.y, -seaward.x)
				var scale := rng.randf_range(0.75, 1.15)
				var lean := Transform3D.IDENTITY if modelo_base == Transform3D.IDENTITY else Transform3D(Basis.from_euler(Vector3(0, 0, 0.14)), Vector3.ZERO)
				var ground := ground_height_at(Vector3(candidate.x, 0, candidate.y))
				if not restinga.is_empty() and rng.randi_range(0, 4) <= 1:
					var local: String = restinga[rng.randi_range(0, restinga.size() - 1)]
					var malha_local: Dictionary = malhas_restinga[local]
					var giro_livre := rng.randf_range(0.0, TAU)
					(transforms_restinga[local] as Array[Transform3D]).append(Transform3D(Basis.from_euler(Vector3(0, giro_livre, 0)).scaled(Vector3.ONE * scale), Vector3(candidate.x, ground - ARVORE_AFUNDADA, candidate.y)) * (malha_local.base as Transform3D))
					_tree_trunks.append({"point": candidate, "ground": ground, "height": minf(float(malha_local.altura) * scale, 4.0), "radius": float(malha_local.tronco) * scale, "especie": local})
				else:
					var transformacao := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3.ONE * scale), Vector3(candidate.x, ground - ARVORE_AFUNDADA, candidate.y)) * lean * modelo_base
					transforms.append(transformacao)
					# O ponto de plantio serve à interação; a colisão segue a base
					# visível do tronco, deslocada pelo coqueiro inclinado do GLB.
					var tronco: Dictionary = {"point": candidate, "ground": ground, "height": minf(float(built.altura) * scale, 4.0), "radius": float(built.tronco) * scale, "especie": "coqueiro", "transformacao": transformacao}
					if not referencias_tronco.is_empty():
						tronco["base_tronco"] = transformacao * (referencias_tronco["base"] as Vector3)
						tronco["alto_tronco"] = transformacao * (referencias_tronco["alto"] as Vector3)
						tronco["raio_base"] = float(referencias_tronco["raio_base"]) * transformacao.basis.get_scale().x
					_tree_trunks.append(tronco)
					registros_coqueiros.append(_tree_trunks.size() - 1)
			next_at += spacing * rng.randf_range(0.7, 1.4)
		travelled += length
	for local in transforms_restinga:
		var lista_local: Array[Transform3D] = transforms_restinga[local]
		if not lista_local.is_empty():
			_multimesh_em_blocos("Restinga da orla: " + local, (malhas_restinga[local] as Dictionary).mesh, lista_local, LOD_RESTINGA)
	if transforms.is_empty():
		return
	_multimesh_em_blocos("Coqueiros da orla", built.mesh, transforms, LOD_COQUEIRO, registros_coqueiros)


func cortar_coqueiro(posicao: Vector3) -> bool:
	var ponto := Vector2(posicao.x, posicao.z)
	for indice in range(_tree_trunks.size()):
		var tronco: Dictionary = _tree_trunks[indice]
		if tronco.get("especie", "") != "coqueiro" or tronco.get("cortado", false):
			continue
		if (tronco["point"] as Vector2).distance_squared_to(ponto) > 0.01:
			continue
		var visual := tronco.get("visual") as MultiMeshInstance3D
		if visual == null:
			return false
		var instancia: int = tronco.get("instancia", -1)
		if instancia < 0:
			return false
		var multimesh := visual.multimesh
		var transformacao: Transform3D = tronco["transformacao"]
		var pe := to_global(Vector3(ponto.x, float(tronco["ground"]), ponto.y))
		var partes: Array[Dictionary] = [{"mesh": multimesh.mesh, "transform": visual.global_transform * transformacao}]
		var toco: Node3D = CoqueiroCortado.criar(partes, pe, float(tronco["radius"]))
		if toco == null:
			return false
		add_child(toco)
		toco.global_position = pe
		multimesh.set_instance_transform(instancia, Transform3D(Basis().scaled(Vector3.ONE * 0.00001), transformacao.origin))
		tronco["transformacao_original"] = transformacao
		tronco["transformacao"] = transformacao
		tronco["altura_original"] = tronco["height"]
		tronco["toco"] = toco
		tronco["height"] = CoqueiroCortado.ALTURA_DO_TOCO
		tronco["cortado"] = true
		_tree_trunks[indice] = tronco
		call_deferred("_refresh_tree_collisions")
		return true
	return false


func restaurar_coqueiro(posicao: Vector3) -> bool:
	var ponto := Vector2(posicao.x, posicao.z)
	for indice in range(_tree_trunks.size()):
		var tronco: Dictionary = _tree_trunks[indice]
		if tronco.get("especie", "") != "coqueiro" or not tronco.get("cortado", false):
			continue
		if (tronco["point"] as Vector2).distance_squared_to(ponto) > 0.01:
			continue
		var visual := tronco.get("visual") as MultiMeshInstance3D
		var instancia := int(tronco.get("instancia", -1))
		if visual == null or instancia < 0 or not tronco.has("transformacao_original"):
			return false
		visual.multimesh.set_instance_transform(instancia, tronco["transformacao_original"])
		var toco := tronco.get("toco") as Node3D
		if is_instance_valid(toco):
			toco.queue_free()
		tronco["height"] = float(tronco.get("altura_original", tronco["height"]))
		tronco["cortado"] = false
		tronco["transformacao"] = tronco["transformacao_original"]
		tronco.erase("transformacao_original")
		tronco.erase("altura_original")
		tronco.erase("toco")
		_tree_trunks[indice] = tronco
		call_deferred("_refresh_tree_collisions")
		return true
	return false


func _process(delta: float) -> void:
	_atualizar_lod_da_camera()
	if _tree_trunks.is_empty():
		return
	_tree_collision_elapsed += delta
	if _tree_collision_elapsed < TREE_COLLISION_INTERVAL:
		return
	_tree_collision_elapsed = 0.0
	_refresh_tree_collisions()


## Os mapas da abertura e do jogo usam câmeras ortográficas a 3000 unidades.
## Sem esta exceção, o corte da câmera de passeio apagaria todas as árvores neles.
## O minimapa usa outro viewport e continua com o LOD de passeio.
func _atualizar_lod_da_camera() -> void:
	if _blocos_vegetacao_lod.is_empty():
		return
	var camera := get_viewport().get_camera_3d()
	var mapa := camera != null and camera.projection == Camera3D.PROJECTION_ORTHOGONAL
	if mapa == _camera_de_mapa:
		return
	_camera_de_mapa = mapa
	for bloco in _blocos_vegetacao_lod:
		var visual := bloco.visual as MultiMeshInstance3D
		visual.visibility_range_end = 0.0 if mapa else float(bloco.distancia)


func _refresh_tree_collisions() -> void:
	var player := get_tree().get_first_node_in_group("map_player") as Node3D
	if player == null:
		_disable_tree_collisions()
		return
	_ensure_tree_collision_pool()
	var player_local := to_local(player.global_position)
	var player_point := Vector2(player_local.x, player_local.z)
	var nearby: Array[Dictionary] = []
	for trunk in _tree_trunks:
		if bool(trunk.get("cortado", false)):
			continue
		var distance_squared: float = player_point.distance_squared_to(trunk.point)
		if distance_squared <= TREE_COLLISION_RADIUS * TREE_COLLISION_RADIUS:
			nearby.append({"point": trunk.point, "ground": trunk.ground, "height": trunk.height, "radius": trunk.get("radius", 0.36), "especie": trunk.get("especie", ""), "base_tronco": trunk.get("base_tronco", Vector3(trunk.point.x, float(trunk.ground), trunk.point.y)), "alto_tronco": trunk.get("alto_tronco", Vector3(trunk.point.x, float(trunk.ground) + 1.0, trunk.point.y)), "raio_base": trunk.get("raio_base", 0.0), "distance_squared": distance_squared})
	nearby.sort_custom(Callable(self, "_collision_nearer"))
	for i in range(_tree_collision_pool.size()):
		var slot := _tree_collision_pool[i]
		var collider: CollisionShape3D = slot.collision
		if i >= nearby.size():
			if slot.active:
				collider.set_deferred("disabled", true)
				slot.active = false
			continue
		var tree := nearby[i]
		var body: StaticBody3D = slot.body
		var shape: CylinderShape3D = slot.shape
		shape.height = tree.height
		var raio := float(tree.get("radius", 0.36))
		# Os coqueiros ficam muito juntos na orla; prioriza seus troncos no pool
		# e dá uma pequena margem ao cilindro para a colisão acompanhar a malha.
		shape.radius = maxf(raio * 1.25, float(tree.get("raio_base", 0.0)) * 0.9) if tree.get("especie", "") == "coqueiro" else raio
		var base_tronco: Vector3 = tree["base_tronco"]
		var alto_tronco: Vector3 = tree["alto_tronco"]
		var eixo_tronco := (alto_tronco - base_tronco).normalized()
		if eixo_tronco.length_squared() < 0.5:
			eixo_tronco = Vector3.UP
		var centro: Vector3 = base_tronco + eixo_tronco * (float(tree.height) * 0.5)
		body.transform = Transform3D(Basis(Quaternion(Vector3.UP, eixo_tronco)), centro)
		if not slot.active:
			collider.set_deferred("disabled", false)
			slot.active = true


func _collision_nearer(a: Dictionary, b: Dictionary) -> bool:
	var a_coqueiro: bool = a.get("especie", "") == "coqueiro"
	var b_coqueiro: bool = b.get("especie", "") == "coqueiro"
	if a_coqueiro != b_coqueiro:
		return a_coqueiro
	return float(a.distance_squared) < float(b.distance_squared)


func _ensure_tree_collision_pool() -> void:
	if not _tree_collision_pool.is_empty():
		return
	for i in range(TREE_COLLISION_POOL_SIZE):
		var body := StaticBody3D.new()
		body.name = "Colisão de tronco %02d" % (i + 1)
		body.collision_layer = 1
		body.collision_mask = 1
		var collider := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.36
		shape.height = 3.0
		collider.shape = shape
		collider.disabled = true
		body.add_child(collider)
		add_child(body)
		_tree_collision_pool.append({"body": body, "collision": collider, "shape": shape, "active": false})


func _disable_tree_collisions() -> void:
	for slot in _tree_collision_pool:
		if slot.active:
			(slot.collision as CollisionShape3D).set_deferred("disabled", true)
			slot.active = false


func _near_route(point: Vector2, clearing: float) -> bool:
	if clearing > FOLGA_MAXIMA_ROTAS:
		for road in _roads:
			if _distance_to_line(point, road.points) < clearing + road.width * 0.5:
				return true
		for river in _rivers:
			if _distance_to_line(point, river.points) < clearing + river.width * 0.5:
				return true
		return false
	_garantir_grade_rotas()
	var lista: Variant = _grade_rotas.get(Vector2i(floori(point.x / CELULA_ROTAS), floori(point.y / CELULA_ROTAS)))
	if lista == null:
		return false
	for id: int in lista:
		var inicio := _rotas_a[id]
		var segment := _rotas_b[id] - inicio
		if segment.length_squared() < 0.000001:
			continue
		var t := clampf((point - inicio).dot(segment) / segment.length_squared(), 0.0, 1.0)
		if point.distance_to(inicio + segment * t) < clearing + _rotas_meia[id]:
			return true
	return false


## Cada segmento de rua e de rio entra nas células que a caixa dele, crescida de meia
## largura + FOLGA_MAXIMA_ROTAS, toca: ponto a menos dessa distância cai numa delas.
func _garantir_grade_rotas() -> void:
	var chave := Vector2i(_roads.size(), _rivers.size())
	if chave == _grade_rotas_chave:
		return
	_grade_rotas = {}
	_rotas_a = PackedVector2Array()
	_rotas_b = PackedVector2Array()
	_rotas_meia = PackedFloat64Array()
	for linhas in [_roads, _rivers]:
		for linha in linhas:
			var pontos: PackedVector2Array = linha.points
			var meia := float(linha.width) * 0.5
			for i in range(pontos.size() - 1):
				var id := _rotas_a.size()
				_rotas_a.append(pontos[i])
				_rotas_b.append(pontos[i + 1])
				_rotas_meia.append(meia)
				var caixa := Rect2(pontos[i], Vector2.ZERO).expand(pontos[i + 1]).grow(meia + FOLGA_MAXIMA_ROTAS)
				for cx in range(floori(caixa.position.x / CELULA_ROTAS), floori(caixa.end.x / CELULA_ROTAS) + 1):
					for cy in range(floori(caixa.position.y / CELULA_ROTAS), floori(caixa.end.y / CELULA_ROTAS) + 1):
						var celula := Vector2i(cx, cy)
						if not _grade_rotas.has(celula):
							_grade_rotas[celula] = []
						_grade_rotas[celula].append(id)
	_grade_rotas_chave = chave


## Distância à costa medida só nos segmentos da célula do ponto. Cada segmento entra nas
## células da sua caixa crescida de margem; ponto mais longe que isso de toda a costa
## recebe INF, e quem chama só usa a distância até a margem (o smoothstep satura em 1).
func _distancia_costa(point: Vector2, margem: float) -> float:
	if _grade_costa_n != _coast.size() or _grade_costa_margem != margem:
		_grade_costa = {}
		for i in range(_coast.size() - 1):
			var caixa := Rect2(_coast[i], Vector2.ZERO).expand(_coast[i + 1]).grow(margem)
			for cx in range(floori(caixa.position.x / CELULA_COSTA), floori(caixa.end.x / CELULA_COSTA) + 1):
				for cy in range(floori(caixa.position.y / CELULA_COSTA), floori(caixa.end.y / CELULA_COSTA) + 1):
					var celula := Vector2i(cx, cy)
					if not _grade_costa.has(celula):
						_grade_costa[celula] = []
					_grade_costa[celula].append(i)
		_grade_costa_n = _coast.size()
		_grade_costa_margem = margem
	var lista: Variant = _grade_costa.get(Vector2i(floori(point.x / CELULA_COSTA), floori(point.y / CELULA_COSTA)))
	if lista == null:
		return INF
	var closest := INF
	for i: int in lista:
		var segment := _coast[i + 1] - _coast[i]
		if segment.length_squared() < 0.000001:
			continue
		var t := clampf((point - _coast[i]).dot(segment) / segment.length_squared(), 0.0, 1.0)
		closest = minf(closest, point.distance_to(_coast[i] + segment * t))
	return closest


func _garantir_grade_troncos() -> void:
	if _grade_troncos_n == _tree_trunks.size():
		return
	_grade_troncos = {}
	_maior_raio_tronco = 2.0
	for i in range(_tree_trunks.size()):
		var ponto: Vector2 = _tree_trunks[i].point
		var celula := Vector2i(floori(ponto.x / CELULA_TRONCOS), floori(ponto.y / CELULA_TRONCOS))
		if not _grade_troncos.has(celula):
			_grade_troncos[celula] = []
		_grade_troncos[celula].append(i)
		_maior_raio_tronco = maxf(_maior_raio_tronco, float(_tree_trunks[i].radius))
	_grade_troncos_n = _tree_trunks.size()


func _near_interest(point: Vector2, radius: float) -> bool:
	for interest in _point_positions:
		if point.distance_squared_to(interest) < radius * radius:
			return true
	return false


func _inside_open_area(point: Vector2) -> bool:
	for area in _open_areas:
		if area.size() >= 3 and Geometry2D.is_point_in_polygon(point, area):
			return true
	return false
