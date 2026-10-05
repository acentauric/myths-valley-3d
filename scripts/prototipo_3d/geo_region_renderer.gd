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
const CopasDistantes = preload("res://scripts/prototipo_3d/copas_distantes.gd")
const AREIA_PRAIA := preload("res://assets/prototipo_3d/mar/areia_praia.gdshader")
const FOZ_RIO := preload("res://assets/prototipo_3d/mar/foz_rio.gdshader")
const AGUA_RIO := preload("res://assets/prototipo_3d/mar/agua_rio.gdshader")
const LEITO_RIO := preload("res://assets/prototipo_3d/mar/leito_rio.gdshader")
const AREIA_TEXTURE := preload("res://assets/prototipo_3d/materiais/areia_praia_v1.png")
## Tinta da textura de grama/terra: com o sol batendo no chão (não mais só a luz
## ambiente), a textura crua fica ocre; puxa de volta para o verde do Recôncavo.
const TINTA_GRAMA := Color(0.74, 0.86, 0.6)
## O CHÃO EM CAMADAS (docs/mundo/SOLO_E_FRANJAS.md): o shader do terreno mistura oito
## texturas pelo mapa de solo, pelo declive e pela altura guardada no alfa de cada
## uma. As texturas vêm do OpenAI (tools/openai/texturas_chao.json), preparadas
## pelo tools/materiais/preparar_textura_chao.py.
const TERRENO_SHADER := preload("res://assets/prototipo_3d/materiais/terreno.gdshader")
const ESTRADA_ACOSTAMENTO := preload("res://assets/prototipo_3d/materiais/estrada_acostamento.gdshader")
const CRUZAMENTO_SHADER := preload("res://assets/prototipo_3d/materiais/cruzamento.gdshader")
const MapaDeSolo = preload("res://scripts/prototipo_3d/mapa_de_solo.gd")
## Camada do shader: [textura, ladrilho em u, tinta]. A tinta acerta a média medida
## de cada textura com a paleta da AMBIENTACAO §7.
const CAMADAS_DO_CHAO := {
	"grama": [preload("res://assets/prototipo_3d/materiais/grama_baixa_v1.png"), 4.0, Color(1.0, 1.0, 1.0)],
	"capim": [preload("res://assets/prototipo_3d/materiais/capim_seco_v1.png"), 5.0, Color(0.92, 0.95, 0.95)],
	"folhico": [preload("res://assets/prototipo_3d/materiais/folhico_mata_v1.png"), 3.5, Color(1.3, 1.25, 1.2)],
	"terra": [preload("res://assets/prototipo_3d/materiais/terra_batida_varrida_v1.png"), 4.0, Color(1.0, 0.94, 0.86)],
	"barro": [preload("res://assets/prototipo_3d/materiais/barro_vermelho_v1.png"), 5.0, Color(0.95, 1.1, 1.1)],
	"pedrisco": [preload("res://assets/prototipo_3d/materiais/pedrisco_v1.png"), 3.0, Color(1.0, 1.0, 1.0)],
	"areia": [preload("res://assets/prototipo_3d/materiais/areia_restinga_v1.png"), 5.0, Color(1.0, 1.0, 1.0)],
	"lama": [preload("res://assets/prototipo_3d/materiais/lama_mangue_v1.png"), 4.0, Color(1.0, 1.0, 1.0)],
}
## Tinta da estrada, quente como a terra batida da vila em volta dela.
const TINTA_ESTRADA := Color("e8d2ae")
const TINTA_ESTRADA_PRINCIPAL := Color("eedbb8")
## Tinta do remendo dos cruzamentos. Ele usa a terra batida (sem direção) e não o
## ocre da estrada, que é ~28% mais claro em média (linear: 0,48/0,29/0,11 contra
## 0,35/0,20/0,07): com a tinta da estrada, cada cruzamento virava uma mancha escura
## e redonda no meio da praça. Esta tinta leva a média da terra à da estrada.
const TINTA_CRUZAMENTO := Color(1.05, 0.96, 0.8)
## Acostamento de cada lado da rua (u): a fita da estrada se esfarela nele sobre a
## terra batida do mapa de solo, que por sua vez se desfaz em tufos na grama.
const ACOSTAMENTO := 2.5
## O mapa de solo da região (mapa_de_solo.gd): montado com o terreno, recebe a copa
## e as trilhas de pé quando o mundo termina (`pintar_vida`).
var solo: RefCounted = null
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
## Lâmina no centro: 0,27 de calha mais 0,025 acima da margem, rasa para a canela.
const RIVER_BED_DEPTH := 0.27
const RIVER_WATER_OFFSET := 0.025
## Fica acima das camadas de grama (até 0,027), sem expor o leito no centro da água.
const RIVER_BED_SAND_OFFSET := 0.06
const RIVER_TERRAIN_CELL_SIZE := 0.8
const RIVER_BANK_RISE := 0.07
const BEACH_BERM_RISE := 0.08
enum BankProfile { FLAT, RIVER, BEACH, MOUTH }

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
var _beach_gap_coast_points := PackedVector2Array()
var _roads: Array[Dictionary] = []
var _rivers: Array[Dictionary] = []
var _mouth_extensions: Array[Dictionary] = []
var _shore_access_routes: Array[Dictionary] = []
var _point_positions: Array[Vector2] = []
## CLAREIRAS PEDIDAS DE FORA, em unidades: lugares que o mapa não tem e o vale
## põe — o terreiro e a gameleira do sambaqui (#52). A mata, a restinga da orla e
## o sub-bosque não plantam nelas.
##
## SEM MEXER NO RESTO DA MATA. O plantio é um sorteio com semente: cada árvore
## aceita puxa a espécie, o tamanho e o giro da mesma fila de números. Recusar o
## ponto da clareira na hora do sorteio desloca a fila, e a mata INTEIRA nasce em
## outro lugar — o tronco que estava longe da lenha da casa de taipa passou a
## estar perto dela. Então a árvore da clareira é sorteada como antes, e só não
## é plantada (`_em_clareira`, no instante de plantar).
var clareiras: Array[Vector2] = []
const RAIO_DAS_CLAREIRAS := 8.0
## OS VÃOS DO SOBREVOO DO MENU, em unidades: por onde o voo gravado
## (`data/sobrevoo_menu.json`) cruza a fileira de árvores da orla ("Sobrevoo da
## abertura", no VALE_VIVO_3D.md). O manguezal, os coqueiros e a restinga da
## orla não plantam tronco neles.
##
## A fileira é sorteada ao longo da costa e da foz: quando o desenho delas muda,
## cada árvore cai em outro lugar, e uma pode cair bem no vão. Foi o que a
## revisão da foz fez com o vão norte: um mangue a 8 m do eixo do voo, com a
## copa na altura da câmera, e a fileira fechada dos dois lados dele — sem outro
## vão por onde replanejar. Como nas clareiras, a árvore do vão é sorteada como
## antes e só não é plantada, para o resto da fileira não sair do lugar.
var vaos_do_sobrevoo: Array[Vector2] = []
## Tronco a menos disto do centro do vão põe a copa dentro da folga do voo.
const RAIO_DO_VAO := 2.5
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
## As grades já montadas, uma por margem (ver `_distancia_costa`).
var _grades_costa := {}
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
## Encurtados em 05/10 para cerca de 0,6 dos valores de 30/09: dentro de 280 u cabiam 8
## milhões de triângulos, quase o vale inteiro, e a copa distante já cobre o longe
## (docs/projeto/DESEMPENHO_05_10_2026.md, F1).
const LOD_SUB_BOSQUE := 55.0
const LOD_RESTINGA := 130.0
const LOD_ARVORE_RIO := 150.0
const LOD_COQUEIRO := 160.0
const LOD_MATA := 170.0
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
	_beach_gap_coast_points = _to_points(scenario.get("beach_gap_coast_points_m", []))
	if _beach_gap_coast_points.size() == 2:
		_land = _smooth_mouth_outline(_land)
		_forest = _smooth_mouth_outline(_forest)
		_coast = _smooth_mouth_outline(_coast)
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
					var river_width := _units(9.0, 4.0)
					_rivers.append({"name": String(feature.get("name", "")), "points": points, "width": river_width, "bounds": _points_bounds(points).grow(river_width * 0.5)})
	_curve_roads()
	_prepare_mouth_extensions()
	_montar_mapa_de_solo()
	if not terrain_only:
		await _marcar(0.02, "Enchendo a baía")
		_build_background()
	var mata_material := _terrain_texture_material()
	# A franja recortada da areia deixa o terreno aparecer nas margens. Na foz
	# central, esse terreno precisa passar de areia para grama junto com a calha.
	for river in _rivers:
		if _is_northern_river(river):
			continue
		for from_end in [false, true]:
			var points: PackedVector2Array = river.points
			if not _tem_foz_no_extremo(points, from_end):
				continue
			var approach_far := _mouth_approach_on_river(points, from_end, _units(80.0, 20.0))
			var approach_mid := _mouth_approach_on_river(points, from_end, _units(45.0, 11.25))
			var approach_near := _mouth_approach_on_river(points, from_end, _units(15.0, 3.75))
			var tip: Vector2 = points[-1] if from_end else points[0]
			var before: Vector2 = points[-2] if from_end else points[1]
			var direction := (tip - before).normalized()
			mata_material.set_shader_parameter("mouth_sand_enabled", true)
			mata_material.set_shader_parameter("mouth_a", approach_far[0])
			mata_material.set_shader_parameter("mouth_b", approach_mid[0])
			mata_material.set_shader_parameter("mouth_c", approach_near[0])
			mata_material.set_shader_parameter("mouth_d", tip)
			mata_material.set_shader_parameter("mouth_e", tip + direction * _units(24.0, 6.0))
			break
	await _marcar(0.05, "Moldando o terreno")
	await _add_polygon("Terra", _land, 0.0, LAND_COLOR, true, mata_material, true)
	await _marcar(0.38, "Moldando o terreno")
	if terrain_only:
		await _marcar(1.0, "Terreno pronto")
		return
	# AS SOBREPOSIÇÕES DO KML SAÍRAM. "Cobertura florestal", "Área ocupada", "Mata" e
	# "Fazenda" eram malhas inteiras por cima da terra com o MESMO material dela: não
	# mudavam nada na tela (e a cor de cada uma nunca aparecia). A praça era uma
	# placa de aresta reta. Agora tudo isso é o mapa de solo, que o shader do
	# terreno lê: terra na praça, com borda ruidosa; capim na fazenda; folhiço sob a
	# copa (docs/mundo/SOLO_E_FRANJAS.md).
	# A areia fica acima do chão (as sobreposições antigas iam até 0.027): sem essa
	# margem, a grama cobria trechos da praia apesar de a faixa e sua colisão já
	# existirem na mesma linha costeira.
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
		# Margens de lama (a mesma do terreno embaixo, que o mapa de solo pinta ao
		# longo do rio), calha de areia de rio mais escura: no mapa o rio deixa de
		# parecer uma estrada de areia, e o manguezal da orla não pisa em praia.
		material_leito.set_shader_parameter("lama", CAMADAS_DO_CHAO["lama"][0])
		material_leito.set_shader_parameter("ladrilho_lama", CAMADAS_DO_CHAO["lama"][1])
		material_leito.set_shader_parameter("tinta_lama", CAMADAS_DO_CHAO["lama"][2])
		material_leito.set_shader_parameter("mistura_lama", 1.0)
		material_leito.set_shader_parameter("franja", 0.35)
		# Uma só malha de areia evita frestas com grama entre leito e margens.
		# Na faixa central, os vértices coincidem com os da água acima dela.
		_add_ribbon("Areia do rio", river.points, largura_total, RIVER_BED_SAND_OFFSET, Color.WHITE, true, material_leito, NAN, 6, 0.8, fracao_canal, null, false, northern, false, NAN, false, BankProfile.RIVER)
		# Água doce de mata: escura, âmbar, correnteza lenta (agua_rio.gdshader).
		var material_rio := ShaderMaterial.new()
		material_rio.shader = AGUA_RIO
		material_rio.set_shader_parameter("ondas_a", Mar.textura_ruido("ondas_a", 0.035, true))
		material_rio.set_shader_parameter("ondas_b", Mar.textura_ruido("ondas_b", 0.05, true))
		var comprimento_rio := 0.0
		for i in range(river.points.size() - 1):
			comprimento_rio += river.points[i].distance_to(river.points[i + 1])
		material_rio.set_shader_parameter("comprimento", comprimento_rio / float(river.width))
		# Na foz central a malha da foz cobre a junta. Dissolver a ponta do
		# canal revelava a areia do leito como uma faixa atravessando a agua.
		material_rio.set_shader_parameter("suavizar_inicio", false)
		material_rio.set_shader_parameter("suavizar_fim", false)
		material_rio.set_shader_parameter("transicao_foz_larguras", _units(100.0, 25.0) / float(river.width) if northern else 1.0)
		_add_ribbon("Rio", river.points, river.width, RIVER_WATER_OFFSET, RIVER_COLOR, false, material_rio, NAN, 6, 1.5, 0.0, null, false, northern, false, 0.015 if not northern else NAN, true)
	for mouth in _mouth_extensions:
		var bank_width := _units(12.0, 3.0)
		var total_width := float(mouth.width) + bank_width * 2.0
		var bed_material := ShaderMaterial.new()
		bed_material.shader = LEITO_RIO
		bed_material.set_shader_parameter("areia", AREIA_TEXTURE)
		bed_material.set_shader_parameter("fracao_canal", float(mouth.width) / total_width)
		bed_material.set_shader_parameter("franja", 0.22)
		_add_ribbon("Ladeira da foz", mouth.points, total_width, RIVER_BED_SAND_OFFSET, Color.WHITE, true, bed_material, NAN, 6, 0.8, float(mouth.width) / total_width, null, false, false, false, NAN, false, BankProfile.MOUTH)
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
		var tint := TINTA_ESTRADA_PRINCIPAL if road.name == "Rua Principal" else TINTA_ESTRADA
		var transition_width: float = road_width + ACOSTAMENTO * 2.0
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
func _terrain_height_at(position: Vector3) -> float:
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


## A calha acompanha o relevo, mas só afunda o terreno sob a largura da água.
## O platô central mantém a profundidade estável; as laterais sobem até as margens.
func _riverbed_profile(point: Vector2) -> float:
	var deepest := 0.0
	for river in _rivers:
		var width := float(river.width)
		if not (river.bounds as Rect2).has_point(point):
			continue
		var distance := _distance_to_line(point, river.points)
		var shape := 1.0 - smoothstep(width * 0.25, width * 0.58, distance)
		deepest = maxf(deepest, RIVER_BED_DEPTH * shape)
	for mouth in _mouth_extensions:
		if not (mouth.bounds as Rect2).has_point(point):
			continue
		var width := float(mouth.width)
		var distance := _distance_to_line(point, mouth.points)
		var shape := 1.0 - smoothstep(width * 0.25, width * 0.58, distance)
		deepest = maxf(deepest, RIVER_BED_DEPTH * shape)
	return deepest


func _riverbed_lowering(point: Vector2) -> float:
	var depth := _riverbed_profile(point)
	return depth if depth > 0.0 and _land.size() >= 3 and Geometry2D.is_point_in_polygon(point, _land) else 0.0


## A areia elevada da margem afunda antes de alcançar o mar, sem um degrau
## exatamente sobre o limite do polígono de terra.
func _river_shore_weight(point: Vector2) -> float:
	if _background_kind != "sea":
		return 1.0
	if not Geometry2D.is_point_in_polygon(point, _land):
		return 0.0
	var shore_span := _units(16.0, 4.0)
	if not _costa_limites.grow(shore_span).has_point(point):
		return 1.0
	return smoothstep(0.0, shore_span, _distancia_costa(point, shore_span))


func ground_height_at(position: Vector3) -> float:
	return _terrain_height_at(position) - _riverbed_lowering(Vector2(position.x, position.z))


## A altura da água usa o relevo sem o corte da calha; o fundo fica abaixo dela.
func river_water_level_at(position: Vector3) -> float:
	var point := Vector2(position.x, position.z)
	if _land.size() < 3 or not Geometry2D.is_point_in_polygon(point, _land):
		return -INF
	for river in _rivers:
		var width := float(river.width)
		if (river.bounds as Rect2).has_point(point) and _distance_to_line(point, river.points) <= width * 0.5:
			var offset := _coastal_ribbon_height(point, RIVER_WATER_OFFSET, 0.015) if not _is_northern_river(river) else RIVER_WATER_OFFSET
			return _terrain_height_at(position) + offset
	return -INF


func river_water_depth_at(position: Vector3) -> float:
	var level := river_water_level_at(position)
	# O jogador pisa na malha de areia, ligeiramente acima do terreno esculpido.
	return maxf(level - ground_height_at(position) - RIVER_BED_SAND_OFFSET, 0.0) if is_finite(level) else 0.0


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
	# O resto do chão diz o que é pelo mapa de solo, o mesmo que o shader pinta: o
	# passo na lama da margem, na areia da restinga, na terra da praça e das trilhas.
	if solo != null:
		if solo.peso(MapaDeSolo.Camada.LAMA, point) > 0.6:
			return "lama"
		if solo.peso(MapaDeSolo.Camada.AREIA, point) > 0.5:
			return "areia"
		if solo.peso(MapaDeSolo.Camada.TERRA, point) > 0.5:
			return "terra"
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
	_mouth_extensions.clear()
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
	_grade_costa_n = -1
	_beach_gap_coast_points.clear()
	solo = null


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


## Arredonda apenas a pequena curva da foz central, mantendo os pontos do
## cenário e os marcadores onde a faixa de praia termina.
func _smooth_mouth_outline(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 5:
		return points
	var markers := PackedInt32Array()
	for marker in _beach_gap_coast_points:
		var nearest := -1
		var best := 0.001
		for i in range(points.size()):
			var distance := points[i].distance_squared_to(marker)
			if distance < best:
				nearest = i
				best = distance
		if nearest < 0:
			return points
		markers.append(nearest)
	var first := mini(markers[0], markers[1])
	var last := maxi(markers[0], markers[1])
	if last <= first + 1:
		return points
	var start := maxi(0, first - 1)
	var finish := mini(points.size() - 1, last + 1)
	var smoothed := PackedVector2Array()
	for i in range(start):
		smoothed.append(points[i])
	for i in range(start, finish):
		var p0 := points[maxi(0, i - 1)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(points.size() - 1, i + 2)]
		for step in range(4):
			var t := float(step) / 4.0
			var t2 := t * t
			var t3 := t2 * t
			smoothed.append(0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3))
	smoothed.append(points[finish])
	for i in range(finish + 1, points.size()):
		smoothed.append(points[i])
	return smoothed


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


## O material do chão inteiro (terreno.gdshader): oito camadas misturadas pelo mapa
## de solo, pelo declive e pela altura de cada textura, projetadas pelo mundo (X/Z),
## sem depender dos UVs da malha. Ao longe, a copa pintada e erguida.
func _terrain_texture_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TERRENO_SHADER
	for camada: String in CAMADAS_DO_CHAO:
		var dados: Array = CAMADAS_DO_CHAO[camada]
		material.set_shader_parameter("tex_" + camada, dados[0])
		material.set_shader_parameter("ladrilho_" + camada, dados[1])
		material.set_shader_parameter("tinta_" + camada, dados[2])
	material.set_shader_parameter("sand_texture", AREIA_TEXTURE)
	material.set_shader_parameter("forca_declive", 1.0)
	material.set_shader_parameter("variacao_grande", 0.1)
	# O Mirante tem 45,6 u: o pedrisco cobre o topo, acima de 38.
	material.set_shader_parameter("altura_pedrisco", 38.0)
	# A copa é pintada antes de o bloco de árvores sumir (LOD_MATA + a margem, medidos
	# do centro de um bloco de 40 u): de LOD_MATA - 80 a LOD_MATA - 30, ela já cobre.
	# Ergue 3 u do chão a partir de LOD_MATA - 60, quando a mata ainda esconde o degrau.
	material.set_shader_parameter("copa_inicio", LOD_MATA - 80.0)
	material.set_shader_parameter("copa_cheia", LOD_MATA - 30.0)
	material.set_shader_parameter("copa_ergue", 3.0)
	material.set_shader_parameter("ergue_inicio", LOD_MATA - 60.0)
	material.set_shader_parameter("ergue_cheio", LOD_MATA - 10.0)
	material.set_shader_parameter("mouth_sand_inner", _units(16.0, 4.0))
	material.set_shader_parameter("mouth_sand_outer", _units(19.0, 4.75))
	_ligar_mapa_de_solo(material)
	return material


## Põe o mapa de solo (se já montado) num material do chão.
func _ligar_mapa_de_solo(material: ShaderMaterial) -> void:
	if solo == null or not solo.pronto():
		return
	material.set_shader_parameter("solo_ativo", true)
	material.set_shader_parameter("solo", solo.textura)
	material.set_shader_parameter("solo_origem", solo.origem)
	material.set_shader_parameter("solo_tamanho", Vector2(solo.tamanho))


## O acostamento (estrada_acostamento.gdshader): a fita mais larga embaixo da rua que
## desenha só a estrada, esfarelada para fora, sobre a terra batida do mapa de solo.
func _road_shoulder_material(road_ratio: float, road_tint: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = ESTRADA_ACOSTAMENTO
	material.set_shader_parameter("road_texture", ESTRADA_OCRE_TEXTURE)
	material.set_shader_parameter("road_fraction", clampf(road_ratio, 0.1, 0.9))
	material.set_shader_parameter("road_tint", road_tint)
	return material


## MAPA DE SOLO, camadas fixas (mapa_de_solo.gd): terra nas ruas, na praça e nos
## cruzamentos; areia ao longo da costa; lama nos rios; pasto na fazenda e, ralo, na
## vila. A copa e as trilhas de pé vêm depois, em `pintar_vida`, quando as árvores e
## as casas existem. Larguras em unidades (docs/mundo/SOLO_E_FRANJAS.md).
func _montar_mapa_de_solo() -> void:
	solo = MapaDeSolo.new()
	solo.comecar(_points_bounds(_land))
	for parte in _on_land(_village):
		solo.poligono(MapaDeSolo.Camada.PASTO, parte, 0.35)
	for feature in _features:
		if feature.get("kind", "") != "area":
			continue
		var pontos := _to_points(feature.get("coordinates_m", []))
		match String(feature.get("name", "")):
			"Fazenda":
				solo.poligono(MapaDeSolo.Camada.PASTO, pontos, 1.0)
			"Praça":
				solo.poligono(MapaDeSolo.Camada.TERRA, _ampliar_poligono(pontos, PRACA_AMPLIACAO), 1.0)
	for road in _roads:
		solo.faixa(MapaDeSolo.Camada.TERRA, road.points, float(road.width) * 0.5 + ACOSTAMENTO)
	for junction in _road_junctions:
		solo.faixa(MapaDeSolo.Camada.TERRA, PackedVector2Array([junction.point, junction.point + Vector2(0.01, 0.0)]), float(junction.width) * 0.96 + 1.0)
	if _coast.size() >= 2:
		solo.faixa(MapaDeSolo.Camada.AREIA, _coast, 9.0)
	# Rio: a cauda (meio-tom) é a umidade da mata ciliar; o núcleo, lama de margem.
	for river in _rivers:
		solo.faixa(MapaDeSolo.Camada.LAMA, river.points, float(river.width) * 0.5 + 7.0, 0.45)
	for mouth in _mouth_extensions:
		solo.faixa(MapaDeSolo.Camada.LAMA, mouth.points, float(mouth.width) * 0.5 + 7.0, 0.45)
	for river in _rivers:
		solo.faixa(MapaDeSolo.Camada.LAMA, river.points, float(river.width) * 0.5 + 3.5, 1.0)
	solo.publicar()


## MAPA DE SOLO, o que nasce com o mundo: a copa de cada árvore (folhiço embaixo
## dela, verde-mata ao longe) e as trilhas de pé da porta de cada casa até a rua.
## `arvores` é a lista do world_builder.arvores() (espécie, pé e raio do tronco);
## `portas`, os pontos de porta (Vector2). Chamado de novo, repinta as duas coisas.
func pintar_vida(arvores: Array, portas: Array) -> void:
	if solo == null:
		return
	solo.limpar(MapaDeSolo.Camada.COPA)
	# O mangue cobre pela metade (a copa é rala e a lama aparece); o coqueiro não
	# cobre: a orla continua de areia. Os de peso cheio por último, por cima.
	for cheio in [false, true]:
		for arvore: Dictionary in arvores:
			var especie := String(arvore.get("especie", ""))
			if especie.contains("coqueiro") or especie.contains("dende"):
				continue
			if (especie == "mangue") == cheio:
				continue
			var pe: Vector3 = arvore["pos"]
			var lado := clampf(float(arvore.get("raio", 0.4)) * 7.0, 2.0, 5.0) * 1.7
			solo.mancha(MapaDeSolo.Camada.COPA, Vector2(pe.x, pe.z), lado, 1.0 if cheio else 0.5)
	for porta: Vector2 in portas:
		var rua := _ponto_mais_perto_das_ruas(porta, 40.0)
		if rua.is_finite():
			solo.faixa(MapaDeSolo.Camada.TERRA, PackedVector2Array([porta, rua]), 1.0)
	solo.publicar([MapaDeSolo.Camada.TERRA, MapaDeSolo.Camada.COPA])


## Ponto do eixo de rua mais perto de `ponto`, até `alcance` u; INF se nenhum.
func _ponto_mais_perto_das_ruas(ponto: Vector2, alcance: float) -> Vector2:
	var melhor := Vector2.INF
	var melhor_d := alcance * alcance
	for road in _roads:
		if not (road.bounds as Rect2).grow(alcance).has_point(ponto):
			continue
		var pontos: PackedVector2Array = road.points
		for i in pontos.size() - 1:
			var perto := Geometry2D.get_closest_point_to_segment(ponto, pontos[i], pontos[i + 1])
			var d := ponto.distance_squared_to(perto)
			if d < melhor_d:
				melhor_d = d
				melhor = perto
	return melhor


func _build_background() -> void:
	# O fundo ultrapassa a borda da região para a vista aérea não revelar um retângulo vazio.
	if _background_kind == "sea" and not _bathymetry.is_empty():
		Mar.montar(self, _bathymetry, SEA_SURFACE_Y, _meters_per_unit, _bounds.grow(4000.0), get_map_frame(), _rivers, _land)
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
	# Normal suave: os vértices repetidos viram um só (index) e a normal de cada um
	# é a média das faces em volta. Com uma normal por face, a luz facetava o morro
	# e a camada do declive no shader desenhava os triângulos.
	surface.index()
	surface.generate_normals()
	var mesh := surface.commit()
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	# O chão recebe sombra, não projeta: as 130 mil faces do terreno eram redesenhadas
	# em cada cascata do sol para quase nenhuma sombra visível.
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	if with_collision:
		var body := StaticBody3D.new()
		body.name = "Colisão da terra"
		# O chão barra o corpo e a câmera (`camadas.gd`).
		body.collision_layer = preload("res://scripts/prototipo_3d/camadas.gd").MUNDO_E_CAMERA
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
	var cell_size := TERRAIN_CELL_SIZE
	var center := (a + b + c) / 3.0
	var radius := sqrt(maxf(ab, maxf(bc, ca)))
	for river in _rivers:
		if (river.bounds as Rect2).grow(radius).has_point(center) and _distance_to_line(center, river.points) < radius + float(river.width):
			cell_size = RIVER_TERRAIN_CELL_SIZE
			break
	if depth < 22 and maxf(ab, maxf(bc, ca)) > cell_size * cell_size * 2.0:
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
	_add_up_triangle(surface, Vector3(a.x, _altura_vertice(a) + offset_y, a.y), Vector3(b.x, _altura_vertice(b) + offset_y, b.y), Vector3(c.x, _altura_vertice(c) + offset_y, c.y), false)


func _altura_vertice(ponto: Vector2) -> float:
	var altura: Variant = _alturas_vertices.get(ponto)
	if altura == null:
		altura = ground_height_at(Vector3(ponto.x, 0, ponto.y))
		_alturas_vertices[ponto] = altura
	return altura


## `com_normal` falso deixa a normal para o generate_normals de quem monta a malha
## (o chão drapeado de _add_polygon, que quer normal suave).
func _add_up_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, com_normal: bool = true) -> void:
	if (b - a).cross(c - a).y < 0.0:
		var swapped := b
		b = c
		c = swapped
	var normal := (b - a).cross(c - a).normalized()
	# a, c, b: horário visto de cima, a face da frente no Godot. Na ordem a, b, c o
	# material sem descarte de faces via o verso, invertia a normal e o chão só
	# recebia sol e lua por baixo.
	for vertex in [a, c, b]:
		if com_normal:
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


func _triangle_height_at(point: Vector2, a: Vector3, b: Vector3, c: Vector3) -> float:
	var pa := Vector2(a.x, a.z)
	var ab := Vector2(b.x, b.z) - pa
	var ac := Vector2(c.x, c.z) - pa
	var denominator := ab.cross(ac)
	if absf(denominator) < 0.000001:
		return (a.y + b.y + c.y) / 3.0
	var relative := point - pa
	var weight_b := relative.cross(ac) / denominator
	var weight_c := ab.cross(relative) / denominator
	return a.y * (1.0 - weight_b - weight_c) + b.y * weight_b + c.y * weight_c


## Corta a superfície na costa para que o rio norte nunca cubra o oceano.
func _add_land_clipped_triangle_uv(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2, _y: float) -> void:
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
			var v0 := Vector3(p0.x, _triangle_height_at(p0, a, b, c), p0.y)
			var v1 := Vector3(p1.x, _triangle_height_at(p1, a, b, c), p1.y)
			var v2 := Vector3(p2.x, _triangle_height_at(p2, a, b, c), p2.y)
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
		var curved := _chaikin(river.points)
		# A foz central agora tem um pequeno canal aberto na costa. Mantém o
		# trecho da linha do rio nesse canal para a água chegar até a baía.
		river.points = _river_path_on_land(curved) if _is_northern_river(river) else curved
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


## O fundo caminhável continua sob a água da foz até ultrapassar a praia.
## A linha do rio termina antes disso; sem esta continuação a colisão sobe na ponta.
func _prepare_mouth_extensions() -> void:
	_mouth_extensions.clear()
	for river in _rivers:
		var points: PackedVector2Array = river.points
		for from_end in [false, true]:
			if not _tem_foz_no_extremo(points, from_end):
				continue
			var tip: Vector2 = points[-1] if from_end else points[0]
			var before: Vector2 = points[-2] if from_end else points[1]
			var direction := (tip - before).normalized()
			if direction == Vector2.ZERO:
				continue
			var extension := PackedVector2Array([tip])
			var point := tip
			for step in 200:
				point += direction
				extension.append(point)
				if not Geometry2D.is_point_in_polygon(point, _land):
					break
			var tail := _units(24.0, 6.0)
			extension.append(point + direction * tail)
			var width := float(river.width)
			_mouth_extensions.append({"points": extension, "width": width, "bounds": _points_bounds(extension).grow(width * 0.5 + _units(12.0, 3.0))})


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
## duas ruas, com a terra batida sem direção (cruzamento.gdshader) e a borda
## esfarelada sobre a terra do mapa de solo.
func _build_road_junctions() -> void:
	for junction in _road_junctions:
		var center: Vector2 = junction.point
		var radius: float = float(junction.width) * 0.8
		var circle := PackedVector2Array()
		for i in 16:
			circle.append(center + Vector2.RIGHT.rotated(TAU * i / 16.0) * radius * 1.2)
		var material := ShaderMaterial.new()
		material.shader = CRUZAMENTO_SHADER
		material.set_shader_parameter("road_texture", CAMADAS_DO_CHAO["terra"][0])
		material.set_shader_parameter("ladrilho", CAMADAS_DO_CHAO["terra"][1])
		material.set_shader_parameter("tint", TINTA_CRUZAMENTO)
		material.set_shader_parameter("center", center)
		material.set_shader_parameter("radius", radius * 1.2)
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


func _beach_height_under_flow(point: Vector2, height: float) -> float:
	var result := height
	for river in _rivers:
		var bounds: Rect2 = river.bounds
		if not bounds.has_point(point):
			continue
		var width := float(river.width)
		var distance := _distance_to_line(point, river.points)
		var submerged := 1.0 - smoothstep(width * 0.35, width * 0.5, distance)
		result = minf(result, lerpf(height, -0.06, submerged))
	for mouth in _mouth_extensions:
		if not (mouth.bounds as Rect2).has_point(point):
			continue
		var width := float(mouth.width)
		var distance := _distance_to_line(point, mouth.points)
		var submerged := 1.0 - smoothstep(width * 0.35, width * 0.5, distance)
		result = minf(result, lerpf(height, -0.06, submerged))
	return result


func _coastal_ribbon_height(point: Vector2, inland_height: float, sea_height: float) -> float:
	if not Geometry2D.is_point_in_polygon(point, _land):
		return sea_height
	var shore_band := _units(28.0, 7.0)
	if not _costa_limites.grow(shore_band).has_point(point):
		return inland_height
	var distance := _distancia_costa(point, shore_band)
	return lerpf(sea_height, inland_height, smoothstep(0.0, shore_band, distance))


## Faixa ao longo de `points`, `y` acima do chão; `y_right` (se dado) é a altura do lado
## direito, para faixas em rampa como a praia entrando na água.
func _add_ribbon(label: String, points: PackedVector2Array, width: float, y: float, color: Color, with_collision: bool = false, material_override: Material = null, y_right_padrao: Variant = null, cross_steps: int = 1, segment_size: float = SURFACE_SEGMENT_SIZE, channel_fraction: float = 0.0, width_profile: Variant = null, lower_under_rivers: bool = false, clip_to_land: bool = false, bury_beach_in_river: bool = false, coastal_height_padrao: Variant = null, use_uncarved_ground: bool = false, bank_profile: BankProfile = BankProfile.FLAT) -> void:
	# NaN marca "sem valor", mas como padrão de parâmetro ele quebra o JSON do LSP do editor
	# (aviso de NaN no JSON.stringify ao conectar o VS Code). O padrão é null e vira NaN aqui.
	var y_right: float = NAN if y_right_padrao == null else float(y_right_padrao)
	var coastal_height: float = NAN if coastal_height_padrao == null else float(coastal_height_padrao)
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
			var shore_weight := 1.0
			var bank_fraction := 0.0
			if bank_profile == BankProfile.RIVER or bank_profile == BankProfile.MOUTH:
				shore_weight = _river_shore_weight(ponta)
				var side := absf(t_j - 0.5) * 2.0
				bank_fraction = clampf((side - channel_fraction) / maxf(1.0 - channel_fraction, 0.001), 0.0, 1.0)
				base += RIVER_BANK_RISE * smoothstep(0.0, 0.45, bank_fraction) * (1.0 - smoothstep(0.7, 1.0, bank_fraction)) * shore_weight
			elif bank_profile == BankProfile.BEACH:
				base += BEACH_BERM_RISE * smoothstep(0.0, 0.15, t_j) * (1.0 - smoothstep(0.55, 0.85, t_j))
			var altura := _beach_height_under_flow(ponta, base) if bury_beach_in_river else (_road_height_under_rivers(ponta, base) if lower_under_rivers else base)
			if not is_nan(coastal_height) and bank_profile != BankProfile.RIVER and bank_profile != BankProfile.MOUTH:
				altura = _coastal_ribbon_height(ponta, altura, coastal_height)
			var position := Vector3(ponta.x, 0, ponta.y)
			var terrain_height := 0.0
			if bank_profile == BankProfile.RIVER or bank_profile == BankProfile.MOUTH:
				var river_depth := _riverbed_profile(ponta)
				# O afundamento da foz age na borda externa; sob a correnteza a
				# areia continua por cima do terreno e da grama sobreposta.
				var submerged_bank := (RIVER_BED_DEPTH - river_depth) * (1.0 - shore_weight) * smoothstep(0.15, 0.8, bank_fraction)
				terrain_height = _terrain_height_at(position) - river_depth - submerged_bank
				if bank_profile == BankProfile.MOUTH and not Geometry2D.is_point_in_polygon(ponta, _land):
					var sea_depth := Mar.lamina_em(ponta)
					if not is_nan(sea_depth):
						var sea_floor := SEA_SURFACE_Y - sea_depth / _meters_per_unit
						var ramp_length := _units(24.0, 6.0)
						var slope := smoothstep(0.0, ramp_length, _distancia_costa(ponta, ramp_length))
						terrain_height = lerpf(terrain_height, sea_floor + 0.02 - altura, slope)
			else:
				terrain_height = _terrain_height_at(position) if use_uncarved_ground else ground_height_at(position)
			grade[i * colunas + j] = Vector3(ponta.x, terrain_height + altura, ponta.y)
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
	# Fita deitada no chão (rua, areia, rio): a sombra dela não aparece, e projetá-la
	# redesenhava a fita em cada cascata do sol.
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	if with_collision:
		var body := StaticBody3D.new()
		body.name = "Colisão " + label
		# Rua, areia e orla: chão para o corpo e para a câmera (`camadas.gd`).
		body.collision_layer = preload("res://scripts/prototipo_3d/camadas.gd").MUNDO_E_CAMERA
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
	# A franja tinha encolhido para 0,10 porque a transparência revelava grama ao
	# longo da praia. Agora o chão embaixo é a areia de restinga do mapa de solo, e a
	# praia volta a se desfazer devagar sobre ela.
	material.set_shader_parameter("franja", 0.25)
	# A faixa úmida acompanha a maré: o material recebe "mare_offset_m" do Mare.
	var mare := get_node_or_null("/root/Mare")
	if mare != null:
		mare.call("registrar_material", material)
	var mouth_tips: Array[Vector2] = []
	for river in _rivers:
		for from_end in [true, false]:
			if _tem_foz_no_extremo(river.points, from_end):
				mouth_tips.append(river.points[river.points.size() - 1] if from_end else river.points[0])
	var widths := PackedFloat32Array()
	for point in coast:
		var local_width := width
		for tip in mouth_tips:
			var narrowing := 1.0 - smoothstep(_units(35.0, 9.0), _units(70.0, 18.0), point.distance_to(tip))
			local_width = minf(local_width, lerpf(width, _units(8.0, 2.0), narrowing))
		widths.append(local_width)
	# A pequena enseada da foz ja tem margens de areia no leito do rio. Fazer
	# a faixa da praia contornar essa curva estreita sobrepunha as duas malhas
	# e desenhava uma ponte de areia sobre a correnteza.
	var sections: Array[Vector2i] = [Vector2i(0, coast.size() - 1)]
	if _beach_gap_coast_points.size() == 2:
		var gap_indices := PackedInt32Array()
		for marker in _beach_gap_coast_points:
			var closest_index := 0
			var closest_distance := INF
			for i in range(coast.size()):
				var distance := coast[i].distance_squared_to(marker)
				if distance < closest_distance:
					closest_distance = distance
					closest_index = i
			gap_indices.append(closest_index)
		var first := mini(gap_indices[0], gap_indices[1])
		var last := maxi(gap_indices[0], gap_indices[1])
		if first > 0 and last < coast.size() - 1 and last > first + 1:
			sections = [Vector2i(0, first), Vector2i(last, coast.size() - 1)]
	for section in sections:
		var section_coast := PackedVector2Array()
		var section_widths := PackedFloat32Array()
		for i in range(section.x, section.y + 1):
			section_coast.append(coast[i])
			section_widths.append(widths[i])
		# A faixa termina afinando sob a areia do rio; um corte reto em toda a
		# largura aparecia como uma placa quadrada na entrada da foz.
		if sections.size() == 2:
			var cap_length := _units(20.0, 5.0)
			var cap_width := _units(0.5, 0.12)
			var walked := 0.0
			if section.x > 0:
				for i in range(section_coast.size()):
					if i > 0:
						walked += section_coast[i].distance_to(section_coast[i - 1])
					section_widths[i] = lerpf(cap_width, section_widths[i], smoothstep(0.0, cap_length, walked))
			else:
				for i in range(section_coast.size() - 1, -1, -1):
					if i < section_coast.size() - 1:
						walked += section_coast[i].distance_to(section_coast[i + 1])
					section_widths[i] = lerpf(cap_width, section_widths[i], smoothstep(0.0, cap_length, walked))
		# Só a praia dentro da correnteza desce sob a agua; o leito cobre
		# as duas margens durante o intervalo sem faixa costeira.
		_add_ribbon("Orla de areia", section_coast, width, 0.035, BEACH_COLOR, true, material, -0.06, 8, 1.0, 0.0, section_widths, false, false, true, NAN, false, BankProfile.BEACH)


## Rios que terminam perto da costa seguem até o mar: a foz atravessa a areia e a água
## do rio se desfaz na do mar.
func _tem_foz_no_extremo(points: PackedVector2Array, from_end: bool) -> bool:
	if _background_kind != "sea" or _land.size() < 3 or points.size() < 2:
		return false
	var tip: Vector2 = points[points.size() - 1] if from_end else points[0]
	return _distance_to_line(tip, _coast) <= _units(60.0, 15.0)


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
			var direction := (tip - before).normalized()
			if direction == Vector2.ZERO:
				continue
			# O rio norte também cruza a praia e alcança a baía. A sobreposição
			# curta mantém a correnteza contínua sobre a junção com o canal.
			mouth = _mouth_approach_on_river(points, from_end, float(river.width) * 2.0)
			if mouth.size() < 2:
				continue
			var point := tip
			for step in 200:
				point += direction
				mouth.append(point)
				if not Geometry2D.is_point_in_polygon(point, _land):
					break
			for i in range(mouth.size() - 1):
				shore_length += mouth[i].distance_to(mouth[i + 1])
			tail = _units(24.0, 6.0)
			for step in range(1, 7):
				mouth.append(point + direction * tail * float(step) / 6.0)
			if mouth.size() < 2:
				continue
			var length := 0.0
			for i in range(mouth.size() - 1):
				length += mouth[i].distance_to(mouth[i + 1])
			var mouth_widths := PackedFloat32Array()
			# A foz central abre com suavidade no trecho final do rio e termina
			# um pouco mais larga que o canal, sem o alargamento excessivo anterior.
			var width_start := float(river.width)
			var flare_length := maxf(shore_length - float(river.width) + tail * 0.7, float(river.width) * 1.5)
			var flare_amount := 0.8
			var traveled := 0.0
			for i in range(mouth.size() - 1):
				var widening := clampf((traveled - width_start) / flare_length, 0.0, 1.0)
				widening = widening * widening * (3.0 - 2.0 * widening)
				mouth_widths.append(float(river.width) * (1.0 + flare_amount * widening))
				traveled += mouth[i].distance_to(mouth[i + 1])
			var widening_final := clampf((length - float(river.width)) / flare_length, 0.0, 1.0)
			widening_final = widening_final * widening_final * (3.0 - 2.0 * widening_final)
			mouth_widths.append(float(river.width) * (1.0 + flare_amount * widening_final))
			var material := ShaderMaterial.new()
			material.shader = FOZ_RIO
			material.set_shader_parameter("ondas_a", Mar.textura_ruido("ondas_a", 0.035, true))
			material.set_shader_parameter("ondas_b", Mar.textura_ruido("ondas_b", 0.05, true))
			material.set_shader_parameter("comprimento", length / float(river.width))
			material.set_shader_parameter("inicio_sumir", clampf((shore_length - float(river.width) * 0.15) / length, 0.0, 0.96))
			material.set_shader_parameter("entrada_suave", float(river.width) / length)
			material.set_shader_parameter("limite_na_costa", false)
			var overlap_lengths := 1.0
			material.set_shader_parameter("deslocamento_percurso", comprimento_rio / float(river.width) - overlap_lengths if from_end else overlap_lengths)
			material.set_shader_parameter("sentido_percurso", 1.0 if from_end else -1.0)
			_add_ribbon("Foz do rio", mouth, float(river.width), RIVER_WATER_OFFSET + 0.01, RIVER_COLOR, false, material, NAN, 10, 1.0, 0.0, mouth_widths, false, false, false, 0.015, true)


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


func _near_river(point: Vector2, clearance: float) -> bool:
	for river in _rivers:
		var width := float(river.width)
		var bounds: Rect2 = river.bounds
		if bounds.grow(clearance).has_point(point) and _distance_to_line(point, river.points) < width * 0.5 + clearance:
			return true
	return false


## TRONCO DA MATA A MENOS DISTO DA BEIRA DE UMA RUA (u) é sorteado e não
## plantado: eram 66 pés colados às ruas (33 na Rua do mirante), e a câmera, que
## bate nos troncos, pulava ao passar por eles.
const AFASTAMENTO_DA_RUA := 4.0


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
	# NO TRIPO, A MATA EM MANCHAS (`especies_da_mata.gd`): a classe do lugar e a
	# mancha escolhem a espécie. O número da fila continua sendo tirado aqui, um
	# por árvore como antes — é o que deixa idênticos, bit a bit, o tamanho e o
	# giro de cada pé, o sub-bosque, o rio e a orla que vêm depois.
	const EspeciesDaMata := preload("res://scripts/prototipo_3d/especies_da_mata.gd")
	var classes: PackedStringArray = _classes_da_mata(positions) if _estilo_tripo else PackedStringArray()
	for i in range(positions.size()):
		var sorteio := rng.randi_range(0, lista.size() - 1)
		var species: String = lista[sorteio]
		if _estilo_tripo:
			var da_mancha := EspeciesDaMata.especie(positions[i], sorteio, lista.size(), classes[i])
			# Sem o GLB, o procedural da espécie puxaria números da fila: fica a da fila.
			if CatalogoAssets.tem_tripo(EspeciesDaMata.malha(da_mancha)):
				species = da_mancha
			elif species == "mata_larga":
				# A gameleira é uma só (a de Iroko): na mata, a copa larga é o jatobá.
				species = "jatoba"
		if not by_species.has(species):
			by_species[species] = []
		by_species[species].append(positions[i])
	for species in by_species.keys():
		var group: Array = by_species[species]
		# A versão leve do Tripo (mesma forma, 3 a 6 mil faces) quando existe; a
		# espécie do tronco, que a ficha e o corte leem, continua a de sempre.
		var built: Dictionary = _malha_da_especie(EspeciesDaMata.malha(species) if _estilo_tripo else species, rng)
		var base: Transform3D = built.base
		var transforms: Array[Transform3D] = []
		# TODA ÁRVORE DA MATA SE CORTA, e por isso cada uma guarda a instância
		# dela na MultiMesh (`registros`) e a própria transformação: é o que o
		# corte usa para sumir com ela, pôr o toco e fazê-la crescer de novo.
		var registros: Array[int] = []
		for i in range(group.size()):
			if i % 150 == 0:
				await _marcar(0.7 + 0.28 * float(i) / float(maxi(group.size(), 1)), "Plantando a mata", false)
			var point: Vector2 = group[i]
			var scale := rng.randf_range(0.8, 1.25)
			var yaw := rng.randf_range(0.0, TAU)
			if _em_clareira(point):
				continue
			var ground := ground_height_at(Vector3(point.x, 0, point.y))
			var transformacao := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(Vector3.ONE * scale), Vector3(point.x, ground - ARVORE_AFUNDADA, point.y)) * base
			# Beira de rua: também sorteia e não planta (como a clareira), medindo
			# o ponto e o pé do tronco que se vê, que na aroeira fica a 1,6 u dele.
			if _perto_da_rua_para_plantar(point, built.mesh, transformacao, float(built.tronco) * scale):
				continue
			# `base` centraliza a malha do GLB e desloca a origem local. O ponto
			# de plantio continua sendo `point`; usar transformacao.origin aqui
			# desloca o colisor para fora do tronco visual.
			var tronco: Dictionary = {"point": point, "ground": ground, "height": minf(float(built.altura) * scale, 4.0), "radius": float(built.tronco) * scale, "especie": species, "transformacao": transformacao}
			_tree_trunks.append(tronco)
			registros.append(_tree_trunks.size() - 1)
			# Afundada um palmo: o pé entra no chão em vez de pousar sobre ele.
			transforms.append(transformacao)
		_multimesh_em_blocos("Mata: " + species, built.mesh, transforms, LOD_MATA, registros)
	await _marcar(0.98, "Plantando a mata", false)
	_build_sub_bosque(positions, rng)
	_build_margens_do_rio(rng)
	_build_coast_palms(rng)


## Distância do ponto à beira da rua mais perto (u), medida só nas ruas da grade
## de rotas (não nos rios); INF além de FOLGA_MAXIMA_ROTAS.
func _distancia_da_rua(point: Vector2) -> float:
	_garantir_grade_rotas()
	# A grade numera primeiro os segmentos das ruas, depois os dos rios.
	var segmentos_de_rua := 0
	for road in _roads:
		segmentos_de_rua += maxi((road.points as PackedVector2Array).size() - 1, 0)
	var lista: Variant = _grade_rotas.get(Vector2i(floori(point.x / CELULA_ROTAS), floori(point.y / CELULA_ROTAS)))
	if lista == null:
		return INF
	var menor := INF
	for id: int in lista:
		if id >= segmentos_de_rua:
			continue
		var inicio := _rotas_a[id]
		var segment := _rotas_b[id] - inicio
		if segment.length_squared() < 0.000001:
			continue
		var t := clampf((point - inicio).dot(segment) / segment.length_squared(), 0.0, 1.0)
		menor = minf(menor, point.distance_to(inicio + segment * t) - _rotas_meia[id])
	return menor if menor < FOLGA_MAXIMA_ROTAS else INF


## O tronco plantado em `point` fica a menos de AFASTAMENTO_DA_RUA da beira de
## uma rua, pelo ponto ou pelo pé medido na malha (`CatalogoAssets.tronco_da_malha`,
## o mesmo de `base_do_tronco`)?
func _perto_da_rua_para_plantar(point: Vector2, malha: Mesh, transformacao: Transform3D, raio: float) -> bool:
	if _distancia_da_rua(point) < AFASTAMENTO_DA_RUA:
		return true
	if not _estilo_tripo:
		return false
	var local := CatalogoAssets.tronco_da_malha(malha, transformacao)
	if not local.is_finite():
		return false
	var pe := transformacao * local
	var pe_2d := Vector2(pe.x, pe.z)
	# Desvio maior que a copa é medida errada (malha sem tronco), como em `base_do_tronco`.
	if pe_2d.distance_to(point) > maxf(raio * 6.0, 2.0):
		return false
	return _distancia_da_rua(pe_2d) < AFASTAMENTO_DA_RUA


## A classe de cada ponto da mata (`especies_da_mata.gd`): Mata do mapa,
## restinga, beira de rio, borda de rua ou da vila, topo, encosta ou baixada.
func _classes_da_mata(positions: Array[Vector2]) -> PackedStringArray:
	const EspeciesDaMata := preload("res://scripts/prototipo_3d/especies_da_mata.gd")
	# A costa primeiro, toda de uma vez: a grade dela se refaz quando a margem
	# pedida muda, e o chão (ground_height_at) pede outra.
	var costa := PackedFloat64Array()
	costa.resize(positions.size())
	var margem_costa := EspeciesDaMata.RESTINGA_ATE_A_COSTA
	for i in range(positions.size()):
		costa[i] = _distancia_costa(positions[i], margem_costa) if _costa_limites.grow(margem_costa).has_point(positions[i]) else INF
	var borda := EspeciesDaMata.BORDA_ATE_A_RUA
	var classes := PackedStringArray()
	classes.resize(positions.size())
	for i in range(positions.size()):
		var ponto := positions[i]
		var rio := INF
		for river in _rivers:
			if (river.bounds as Rect2).grow(EspeciesDaMata.CILIAR_ATE_O_RIO).has_point(ponto):
				rio = minf(rio, _distance_to_line(ponto, river.points) - float(river.width) * 0.5)
		var perto_da_vila := false
		if _village.size() >= 3:
			for desvio in [Vector2(borda, 0), Vector2(-borda, 0), Vector2(0, borda), Vector2(0, -borda)]:
				if Geometry2D.is_point_in_polygon(ponto + desvio, _village):
					perto_da_vila = true
					break
		classes[i] = EspeciesDaMata.classe({
			"no_mapa": _kml_forest.size() >= 3 and Geometry2D.is_point_in_polygon(ponto, _kml_forest),
			"costa": costa[i], "rio": rio, "rua": _distancia_da_rua(ponto), "vila": perto_da_vila,
			"altura": ground_height_at(Vector3(ponto.x, 0.0, ponto.y)),
		})
	return classes


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
		# O tufo tem volume para fora do ponto de plantio; deixa uma faixa livre
		# além da margem do rio para ele não aparecer dentro da correnteza.
		if not Geometry2D.is_point_in_polygon(ponto, _land) or _near_route(ponto, _units(4.0, 1.5)) or _near_river(ponto, _units(5.0, 2.0)):
			continue
		var chao := ground_height_at(Vector3(ponto.x, 0, ponto.y))
		var escala := rng.randf_range(0.7, 1.3)
		var giro_do_tufo := rng.randf() * TAU
		if _em_clareira(ponto):
			continue
		transforms.append(Transform3D(Basis.from_euler(Vector3(0, giro_do_tufo, 0)).scaled(Vector3.ONE * escala), Vector3(ponto.x, chao - 0.03, ponto.y)) * (tufo.base as Transform3D))
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
	# Os índices dos troncos de cada um, para o corte achar a instância.
	var registros_mangue: Array[int] = []
	var registros_inga: Array[int] = []
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
					# O modelo do ingazeiro inclui uma pedra de ate 4,8 u de raio
					# na maior escala; mantenha a base inteira fora da agua.
					var recuo := rng.randf_range(0.8, 2.5) if no_mangue else rng.randf_range(5.2, 6.0)
					var ponto: Vector2 = base + normal * float(lado) * (largura * 0.5 + recuo)
					if not Geometry2D.is_point_in_polygon(ponto, _land) or _near_route(ponto, _units(5.0, 2.0)):
						continue
					var chao := ground_height_at(Vector3(ponto.x, 0, ponto.y))
					var escala := rng.randf_range(0.8, 1.2)
					var giro := Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3.ONE * escala)
					if no_mangue:
						# No vão do sobrevoo o mangue já foi sorteado, e só não nasce.
						if _no_vao_do_sobrevoo(ponto):
							continue
						var no_rio := Transform3D(giro, Vector3(ponto.x, chao - ARVORE_AFUNDADA, ponto.y)) * (mangue.base as Transform3D)
						do_mangue.append(no_rio)
						_tree_trunks.append({"point": ponto, "ground": chao, "height": minf(float(mangue.altura) * escala, 4.0), "radius": float(mangue.tronco) * escala, "especie": "mangue", "transformacao": no_rio})
						registros_mangue.append(_tree_trunks.size() - 1)
					elif tem_inga and rng.randf() < 0.55:
						var na_beira := Transform3D(giro, Vector3(ponto.x, chao - ARVORE_AFUNDADA, ponto.y)) * (inga.base as Transform3D)
						do_inga.append(na_beira)
						_tree_trunks.append({"point": ponto, "ground": chao, "height": minf(float(inga.altura) * escala, 4.0), "radius": float(inga.tronco) * escala, "especie": "ingazeiro", "transformacao": na_beira})
						registros_inga.append(_tree_trunks.size() - 1)
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
						var na_foz := Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3.ONE * escala), Vector3(ponto.x, chao - ARVORE_AFUNDADA, ponto.y)) * (mangue.base as Transform3D)
						# No vão do sobrevoo o mangue já foi sorteado, e só não nasce.
						if _no_vao_do_sobrevoo(ponto):
							continue
						do_mangue.append(na_foz)
						_tree_trunks.append({"point": ponto, "ground": chao, "height": minf(float(mangue.altura) * escala, 4.0), "radius": float(mangue.tronco) * escala, "especie": "mangue", "transformacao": na_foz})
						registros_mangue.append(_tree_trunks.size() - 1)
	if not do_mangue.is_empty():
		_multimesh_em_blocos("Manguezal", mangue.mesh, do_mangue, LOD_ARVORE_RIO, registros_mangue)
	if not do_inga.is_empty():
		_multimesh_em_blocos("Ingazeiros do rio", inga.mesh, do_inga, LOD_ARVORE_RIO, registros_inga)


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
		# A COPA DISTANTE entra onde a árvore sai (`copas_distantes.gd`): só nos
		# blocos de árvore que têm tronco registrado e LOD (mata, rio, restinga e
		# coqueiros da orla). Não passa por esta função de novo: o extrator do
		# sobrevoo só grava o que ela recebe.
		var camadas: Array[Dictionary] = []
		var especie_da_copa := CopasDistantes.especie_do_bloco(nome)
		if distancia_lod > 0.0 and especie_da_copa != "" and not registros.is_empty():
			var daqui: Array[Transform3D] = []
			for indice in lista:
				daqui.append(transforms[int(indice)])
			camadas = CopasDistantes.montar("%s %d,%d" % [nome, chave.x, chave.y], especie_da_copa, mesh, daqui, distancia_lod, LOD_MARGEM)
			for camada in camadas:
				add_child(camada["visual"])
		for i in range(lista.size()):
			var indice: int = lista[i]
			if indice >= registros.size():
				continue
			var tronco: Dictionary = _tree_trunks[registros[indice]]
			tronco["visual"] = visual
			tronco["instancia"] = i
			if not camadas.is_empty():
				var de_longe: Array[Dictionary] = []
				for camada in camadas:
					de_longe.append({"visual": camada["visual"], "forma": (camada["formas"] as Array[Transform3D])[i]})
				tronco["longe"] = de_longe
			_tree_trunks[registros[indice]] = tronco
		if distancia_lod > 0.0:
			var bloco := {"visual": visual, "distancia": distancia_lod}
			if not camadas.is_empty():
				var visuais: Array[MultiMeshInstance3D] = []
				for camada in camadas:
					visuais.append(camada["visual"])
				bloco["longe"] = visuais
			_blocos_vegetacao_lod.append(bloco)


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
	var registros_restinga: Dictionary = {}
	for local in restinga:
		if not malhas_restinga.has(local):
			malhas_restinga[local] = _malha_da_especie(local, rng)
			transforms_restinga[local] = [] as Array[Transform3D]
			registros_restinga[local] = [] as Array[int]
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
					if not _em_clareira(candidate) and not _no_vao_do_sobrevoo(candidate):
						var na_restinga := Transform3D(Basis.from_euler(Vector3(0, giro_livre, 0)).scaled(Vector3.ONE * scale), Vector3(candidate.x, ground - ARVORE_AFUNDADA, candidate.y)) * (malha_local.base as Transform3D)
						(transforms_restinga[local] as Array[Transform3D]).append(na_restinga)
						_tree_trunks.append({"point": candidate, "ground": ground, "height": minf(float(malha_local.altura) * scale, 4.0), "radius": float(malha_local.tronco) * scale, "especie": local, "transformacao": na_restinga})
						(registros_restinga[local] as Array[int]).append(_tree_trunks.size() - 1)
				elif not _em_clareira(candidate) and not _no_vao_do_sobrevoo(candidate):
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
			_multimesh_em_blocos("Restinga da orla: " + local, (malhas_restinga[local] as Dictionary).mesh, lista_local, LOD_RESTINGA, registros_restinga[local])
	if transforms.is_empty():
		return
	_multimesh_em_blocos("Coqueiros da orla", built.mesh, transforms, LOD_COQUEIRO, registros_coqueiros)


## CORTA A ÁRVORE com o pé neste ponto — da mata, da orla ou da beira do rio,
## de qualquer espécie. A instância dela na MultiMesh encolhe a nada e, no
## lugar, fica o toco: a malha dela mesma recortada na altura do golpe
## (`CoqueiroCortado`). Precisa da instância registrada (`registros` em
## `_multimesh_em_blocos`), que toda árvore com tronco passou a ter.
func cortar_arvore(posicao: Vector3, deixar_toco: bool = true, cair_para: Vector3 = Vector3.ZERO) -> bool:
	var indice := _indice_do_tronco(posicao, false)
	if indice < 0:
		return false
	var tronco: Dictionary = _tree_trunks[indice]
	var visual := tronco.get("visual") as MultiMeshInstance3D
	var instancia := int(tronco.get("instancia", -1))
	if visual == null or instancia < 0 or not tronco.has("transformacao"):
		return false
	var multimesh := visual.multimesh
	var transformacao: Transform3D = tronco["transformacao"]
	var ponto: Vector2 = tronco["point"]
	var pe := to_global(Vector3(ponto.x, float(tronco["ground"]), ponto.y))
	# Sem toco (`deixar_toco` falso) é a carga de uma árvore que já passou dele.
	if deixar_toco:
		var partes: Array[Dictionary] = [{"mesh": multimesh.mesh, "transform": visual.global_transform * transformacao}]
		var toco: Node3D = CoqueiroCortado.criar(partes, pe, float(tronco["radius"]))
		if toco == null:
			return false
		add_child(toco)
		toco.global_position = pe
		tronco["toco"] = toco
		# A COPA CAI longe de quem cortou, enquanto a instância some.
		if cair_para != Vector3.ZERO:
			var eixo: Vector2 = toco.get_meta("eixo", Vector2.ZERO)
			var pivo := pe + Vector3(eixo.x, float(toco.get_meta("altura", CoqueiroCortado.ALTURA_DO_TOCO)), eixo.y)
			var copa := CoqueiroCortado.copa(partes, pivo)
			if copa != null:
				CoqueiroCortado.derrubar(copa, self, pivo, cair_para)
	# `transformacao` passa a ser a de AGORA — a que a instância mostra —, e a
	# inteira fica em `transformacao_original` até a árvore voltar adulta. A
	# MultiMesh não devolve a transformação no servidor de renderização sem
	# tela (o dos portões); o tronco devolve.
	_mostrar_instancia(tronco, _instancia_sumida(transformacao))
	tronco["transformacao_original"] = transformacao
	tronco["altura_original"] = tronco["height"]
	tronco["height"] = CoqueiroCortado.ALTURA_DO_TOCO
	tronco["cortado"] = true
	_tree_trunks[indice] = tronco
	call_deferred("_refresh_tree_collisions")
	return true


## A ÁRVORE CORTADA CRESCE DE NOVO: `escala` é o tamanho de agora, de 0 (só o
## toco) até perto de 1. A muda e a árvore nova são a instância dela mesma,
## menor, crescendo do pé. Continua `cortado` até `restaurar_arvore`: sem
## colisão do conjunto de troncos, que é de árvore adulta.
func crescer_arvore(posicao: Vector3, escala: float) -> bool:
	var indice := _indice_do_tronco(posicao, true)
	if indice < 0:
		return false
	var tronco: Dictionary = _tree_trunks[indice]
	var visual := tronco.get("visual") as MultiMeshInstance3D
	var instancia := int(tronco.get("instancia", -1))
	if visual == null or instancia < 0 or not tronco.has("transformacao_original"):
		return false
	var inteira: Transform3D = tronco["transformacao_original"]
	if escala <= 0.0:
		_mostrar_instancia(tronco, _instancia_sumida(inteira))
		return is_instance_valid(tronco.get("toco"))
	var toco = tronco.get("toco")
	if is_instance_valid(toco):
		(toco as Node3D).queue_free()
	tronco.erase("toco")
	# O pé, no espaço da MultiMesh: o ponto de plantio, afundado como a árvore.
	var ponto: Vector2 = tronco["point"]
	var pe := visual.global_transform.affine_inverse() * to_global(Vector3(ponto.x, float(tronco["ground"]) - ARVORE_AFUNDADA, ponto.y))
	_mostrar_instancia(tronco, Transform3D(Basis().scaled(Vector3.ONE * escala), pe * (1.0 - escala)) * inteira)
	tronco["escala"] = escala
	_tree_trunks[indice] = tronco
	return true


## A árvore volta a ser adulta: a instância inteira, a altura do tronco para a
## colisão, e o toco (se ainda houver) fora.
func restaurar_arvore(posicao: Vector3) -> bool:
	var indice := _indice_do_tronco(posicao, true)
	if indice < 0:
		return false
	var tronco: Dictionary = _tree_trunks[indice]
	var visual := tronco.get("visual") as MultiMeshInstance3D
	var instancia := int(tronco.get("instancia", -1))
	if visual == null or instancia < 0 or not tronco.has("transformacao_original"):
		return false
	_mostrar_instancia(tronco, tronco["transformacao_original"])
	var toco = tronco.get("toco")
	if is_instance_valid(toco):
		(toco as Node3D).queue_free()
	tronco["height"] = float(tronco.get("altura_original", tronco["height"]))
	tronco["cortado"] = false
	tronco.erase("transformacao_original")
	tronco.erase("altura_original")
	tronco.erase("toco")
	tronco.erase("escala")
	_tree_trunks[indice] = tronco
	call_deferred("_refresh_tree_collisions")
	return true


## O tronco com o pé neste ponto (cortado ou de pé, conforme pedido), ou -1.
## Pela grade dos troncos: a mata tem milhares, e a carga de uma partida com
## muitas árvores cortadas pergunta por todas.
func _indice_do_tronco(posicao: Vector3, cortado: bool) -> int:
	_garantir_grade_troncos()
	# No mesmo referencial de `WorldBuilder.arvores`, que dá o ponto do tronco
	# como posição do mundo.
	var ponto := Vector2(posicao.x, posicao.z)
	var celula := Vector2i(floori(ponto.x / CELULA_TRONCOS), floori(ponto.y / CELULA_TRONCOS))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for i: int in _grade_troncos.get(celula + Vector2i(dx, dy), []):
				var tronco: Dictionary = _tree_trunks[i]
				if bool(tronco.get("cortado", false)) != cortado:
					continue
				if (tronco["point"] as Vector2).distance_squared_to(ponto) <= 0.01:
					return i
	return -1


## A instância do tronco na MultiMesh passa a mostrar `transformacao`, e o
## tronco guarda qual é.
func _mostrar_instancia(tronco: Dictionary, transformacao: Transform3D) -> void:
	(tronco["visual"] as MultiMeshInstance3D).multimesh.set_instance_transform(int(tronco["instancia"]), transformacao)
	# O que se vê dela de longe (modelo e copa) acompanha a árvore: some com ela,
	# encolhe e cresce com ela.
	for camada: Dictionary in tronco.get("longe", []):
		(camada["visual"] as MultiMeshInstance3D).multimesh.set_instance_transform(int(tronco["instancia"]), transformacao * (camada["forma"] as Transform3D))
	tronco["transformacao"] = transformacao


static func _instancia_sumida(transformacao: Transform3D) -> Transform3D:
	return Transform3D(Basis().scaled(Vector3.ONE * 0.00001), transformacao.origin)


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
		# O mapa alto mostra as árvores de verdade: a copa de longe se esconde.
		for de_longe: MultiMeshInstance3D in bloco.get("longe", []):
			de_longe.visible = not mapa


func _refresh_tree_collisions() -> void:
	var player := get_tree().get_first_node_in_group("map_player") as Node3D
	if player == null:
		_disable_tree_collisions()
		return
	_ensure_tree_collision_pool()
	var player_local := to_local(player.global_position)
	var nearby := troncos_para_o_conjunto(Vector2(player_local.x, player_local.z))
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
		# Os coqueiros ficam muito juntos na orla: uma pequena margem ao
		# cilindro deixa a colisão acompanhar a malha.
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


## OS TRONCOS QUE GANHAM CORPO com o jogador em `ponto` (no referencial da
## região): os de pé num raio de `TREE_COLLISION_RADIUS`, do mais perto ao mais
## longe, até as vagas do conjunto. É a escolha do jogo, e o portão
## `colisoes_do_vale.gd` a usa para cobrar que nenhum tronco ao alcance fique
## sem corpo.
##
## A DISTÂNCIA É ATÉ O PÉ DO TRONCO (`base_do_tronco`), não até o ponto de
## plantio, e é ela que manda. O coqueiro passava na frente de qualquer outra
## árvore, a qualquer distância: na foz, um mangue a um metro perdia a vaga
## para um coqueiro a vinte e sete. Agora ele só desempata.
func troncos_para_o_conjunto(ponto: Vector2) -> Array[Dictionary]:
	_garantir_grade_troncos()
	var nearby: Array[Dictionary] = []
	var celulas := int(ceil(TREE_COLLISION_RADIUS / CELULA_TRONCOS)) + 1
	var celula := Vector2i(floori(ponto.x / CELULA_TRONCOS), floori(ponto.y / CELULA_TRONCOS))
	for dx in range(-celulas, celulas + 1):
		for dy in range(-celulas, celulas + 1):
			for i: int in _grade_troncos.get(celula + Vector2i(dx, dy), []):
				var trunk: Dictionary = _tree_trunks[i]
				if bool(trunk.get("cortado", false)):
					continue
				if ponto.distance_squared_to(trunk.point) > TREE_COLLISION_RADIUS * TREE_COLLISION_RADIUS:
					continue
				var base := base_do_tronco(trunk)
				nearby.append({"point": trunk.point, "ground": trunk.ground, "height": trunk.height, "radius": trunk.get("radius", 0.36), "especie": trunk.get("especie", ""), "base_tronco": base, "alto_tronco": trunk.get("alto_tronco", base + Vector3.UP), "raio_base": trunk.get("raio_base", 0.0), "distance_squared": ponto.distance_squared_to(Vector2(base.x, base.z))})
	nearby.sort_custom(Callable(self, "_collision_nearer"))
	if nearby.size() > TREE_COLLISION_POOL_SIZE:
		nearby.resize(TREE_COLLISION_POOL_SIZE)
	return nearby


## O PÉ DO TRONCO QUE SE VÊ, no referencial da região. O coqueiro da orla já
## nasce com ele (`base_tronco`, da malha inclinada). As outras árvores eram
## postas no ponto de plantio, que é o MEIO DA CAIXA do GLB — o meio da copa: a
## mata_alta e a mata_larga, oito em cada dez árvores da mata, tinham o corpo a
## quase um metro da madeira, e a aroeira a 1,35. O jogador atravessava o tronco
## e batia no ar ao lado. Agora o pé é medido na malha da própria instância
## (`CatalogoAssets.tronco_da_malha`, uma vez por malha) e guardado no tronco.
## O plantio, o clique e o corte continuam no ponto de plantio.
func base_do_tronco(trunk: Dictionary) -> Vector3:
	if trunk.has("base_tronco"):
		return trunk["base_tronco"]
	var ponto: Vector2 = trunk["point"]
	var pe := Vector3(ponto.x, float(trunk["ground"]), ponto.y)
	if not _estilo_tripo or not trunk.has("transformacao") or bool(trunk.get("cortado", false)):
		return pe
	var visual := trunk.get("visual") as MultiMeshInstance3D
	if visual == null or visual.multimesh == null:
		return pe
	var local := CatalogoAssets.tronco_da_malha(visual.multimesh.mesh, trunk["transformacao"])
	if not local.is_finite():
		return pe
	var base: Vector3 = (trunk["transformacao"] as Transform3D) * local
	base.y = pe.y
	# Desvio maior que a copa é medida errada (malha sem tronco): fica o plantio.
	if Vector2(base.x - pe.x, base.z - pe.z).length() > maxf(float(trunk.get("radius", 0.36)) * 6.0, 2.0):
		return pe
	trunk["base_tronco"] = base
	trunk["alto_tronco"] = base + Vector3.UP
	return base


func _collision_nearer(a: Dictionary, b: Dictionary) -> bool:
	var da := float(a.distance_squared)
	var db := float(b.distance_squared)
	if not is_equal_approx(da, db):
		return da < db
	# Só no empate o coqueiro vem antes: é ele que fica colado aos outros na orla.
	return a.get("especie", "") == "coqueiro" and b.get("especie", "") != "coqueiro"


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
##
## UMA GRADE POR MARGEM. Desde 04/10 a distância é pedida com margens diferentes (4,
## 6, 7, 20 e 26 u), alternando até no mesmo vértice, e a grade única era refeita a
## cada troca: 23 mil vezes ao estender a praia e os rios (19 s num quadro só, na
## carga do menu e na do jogo) e duas por consulta de água no rio central durante o
## jogo. Guardada por margem, cada grade nasce uma vez e a resposta é a mesma
## (docs/projeto/DESEMPENHO_05_10_2026.md, seção 5.2).
func _distancia_costa(point: Vector2, margem: float) -> float:
	if _grade_costa_n != _coast.size():
		_grades_costa = {}
		_grade_costa_n = _coast.size()
		_grade_costa_margem = -1.0
	if _grade_costa_margem != margem:
		if not _grades_costa.has(margem):
			var grade := {}
			for i in range(_coast.size() - 1):
				var caixa := Rect2(_coast[i], Vector2.ZERO).expand(_coast[i + 1]).grow(margem)
				for cx in range(floori(caixa.position.x / CELULA_COSTA), floori(caixa.end.x / CELULA_COSTA) + 1):
					for cy in range(floori(caixa.position.y / CELULA_COSTA), floori(caixa.end.y / CELULA_COSTA) + 1):
						var celula := Vector2i(cx, cy)
						if not grade.has(celula):
							grade[celula] = []
						grade[celula].append(i)
			_grades_costa[margem] = grade
		_grade_costa = _grades_costa[margem]
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


## O ponto cai numa clareira pedida de fora? (Ver `clareiras`.)
func _em_clareira(point: Vector2) -> bool:
	for clareira in clareiras:
		if point.distance_squared_to(clareira) < RAIO_DAS_CLAREIRAS * RAIO_DAS_CLAREIRAS:
			return true
	return false


## O ponto cai num vão do sobrevoo do menu? (Ver `vaos_do_sobrevoo`.)
func _no_vao_do_sobrevoo(point: Vector2) -> bool:
	for vao in vaos_do_sobrevoo:
		if point.distance_squared_to(vao) < RAIO_DO_VAO * RAIO_DO_VAO:
			return true
	return false


func _inside_open_area(point: Vector2) -> bool:
	for area in _open_areas:
		if area.size() >= 3 and Geometry2D.is_point_in_polygon(point, area):
			return true
	return false
