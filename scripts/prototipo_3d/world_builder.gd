extends Node3D
## O vale de Bom Jesus dos Pobres: terreno geográfico (KML) + peças perto dos pontos de
## interesse. Cada peça existe em dois estilos escolhidos em AJUSTAR (autoload Estilo):
## "tripo" usa os GLBs do catálogo (CatalogoAssets); "procedural" usa FloraReconcavo e os
## construtores deste script. Terreno, ruas, rios e mar são iguais nos dois.
## O catálogo de regiões define quantos metros reais cabem em uma unidade (`scale_m_per_unit`).

const PATH := Color("c5ad7a")
const WOOD := Color("735139")
const LEAVES := Color("487557")
const GeoRegionRenderer = preload("res://scripts/prototipo_3d/geo_region_renderer.gd")
const LuzesEpoca = preload("res://scripts/prototipo_3d/luzes_epoca.gd")
const MAP_CATALOG := "res://data/mapas/regioes.json"
const CASA_TAIPA_CAL_TEXTURE := preload("res://assets/prototipo_3d/materiais/cal_taipa_envelhecida_v1.png")
const TELHA_COLONIAL_TEXTURE := preload("res://assets/prototipo_3d/materiais/telha_colonial_envelhecida_v1.png")
## Bancada de comparação (desenvolvimento): três mangueiras lado a lado ao sul da Praça.
const COMPARAR_MANGUEIRAS := false
## Camada reservada para raycasts de interação com casas (bit 13 no inspetor).
const HOUSE_INTERACTION_LAYER := 1 << 12
const SITE_SEARCH_STEP := 1.5
const SITE_SEARCH_DIRECTIONS := 24

signal house_interacted(properties: Dictionary)
signal house_interaction_cleared

var _materials: Dictionary = {}
var landmarks: Array[Dictionary] = []
var areas: Array[Dictionary] = []
var region_title := "Vale"
var _region = null
var _meters_per_unit := 1.0
var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _environment: Environment
var _sky_material: ProceduralSkyMaterial
var _luzes: Node3D
## Pontos de interesse e âncoras que os NPCs e as luzes usam (nome → posição no chão).
var ancoras: Dictionary = {}
var _house_targets: Array[Area3D] = []
var _hovered_house: Area3D
var _selected_house: Area3D
var _house_sites: Array[Dictionary] = []
var _manual_tree_sites: Array[Dictionary] = []


func get_meters_per_unit() -> float:
	return _meters_per_unit


## Converte um deslocamento medido em metros reais para unidades da cena.
func _u(meters: Vector3) -> Vector3:
	return meters / _meters_per_unit


func get_spawn_position() -> Vector3:
	return _region.get_spawn_position() if _region else Vector3(0, 0.05, 0)


func get_map_bounds() -> Rect2:
	return _region.get_map_bounds() if _region else Rect2(-1200, -1300, 1800, 1950)


func surface_at(world_position: Vector3) -> String:
	return _region.surface_at(world_position) if _region else "grama"


func is_walkable_point(world_position: Vector3) -> bool:
	return _region != null and _region.is_walkable_point(world_position)


## O raycast deve usar HOUSE_INTERACTION_LAYER e collide_with_areas = true.
func get_house_properties(collider: Object) -> Dictionary:
	var house := _house_from_collider(collider)
	if house == null:
		return {}
	return (house.get_meta("house_properties") as Dictionary).duplicate(true)


func format_house_properties(properties: Dictionary) -> String:
	var point: Vector3 = properties["position"]
	return "%s\nObjeto: %s\nPosição: X %s · Y %s · Z %s\nEstilo: %s" % [properties["name"], properties["object_key"], str(snappedf(point.x, 0.01)), str(snappedf(point.y, 0.01)), str(snappedf(point.z, 0.01)), properties["style"]]


## Mostra apenas o nome e a dica de interação enquanto o cursor está sobre a casa.
func set_hovered_house(collider: Object) -> void:
	var house := _house_from_collider(collider)
	if house == _hovered_house:
		return
	var previous := _hovered_house
	_hovered_house = house
	if is_instance_valid(previous):
		_update_house_label(previous)
	if house != null:
		_update_house_label(house)


## Clique esquerdo: mantém o balão de propriedades aberto para a casa escolhida.
func interact_with_house(collider: Object) -> void:
	var house := _house_from_collider(collider)
	if house == null:
		return
	var previous := _selected_house
	_selected_house = house
	if is_instance_valid(previous):
		_update_house_label(previous)
	_update_house_label(house)
	house_interacted.emit(get_house_properties(house))


func clear_house_interaction() -> void:
	var previous_hover := _hovered_house
	var previous_selected := _selected_house
	_hovered_house = null
	_selected_house = null
	if is_instance_valid(previous_hover):
		_update_house_label(previous_hover)
	if is_instance_valid(previous_selected) and previous_selected != previous_hover:
		_update_house_label(previous_selected)
	if is_instance_valid(previous_selected):
		house_interaction_cleared.emit()


## Um ponto livre junto à construção; Vector3.INF indica alvo sem acesso por terra.
func get_house_destination(collider: Object, from_position: Vector3 = Vector3.ZERO) -> Vector3:
	var house := _house_from_collider(collider)
	if house == null or not is_walkable_point(house.global_position):
		return Vector3.INF
	var bounds: Vector3 = house.get_meta("house_bounds")
	var margin := 1.2
	var candidates: Array[Vector3] = [
		Vector3(0, 0, bounds.z * 0.5 + margin),
		Vector3(0, 0, -bounds.z * 0.5 - margin),
		Vector3(bounds.x * 0.5 + margin, 0, 0),
		Vector3(-bounds.x * 0.5 - margin, 0, 0),
	]
	var result := Vector3.INF
	var best_distance := INF
	for offset in candidates:
		var candidate := house.to_global(offset)
		candidate.y = house.global_position.y
		if not is_walkable_point(candidate):
			continue
		var distance := candidate.distance_squared_to(from_position)
		if distance < best_distance:
			best_distance = distance
			result = candidate
	return result


func get_feature_center(feature_name: String, kind: String = "") -> Vector3:
	return _region.get_feature_center(feature_name, kind) if _region else Vector3.ZERO


func get_region_title() -> String:
	return region_title


func estilo_tripo() -> bool:
	return Estilo.tripo()


func _ready() -> void:
	_build_lighting()
	var region_data := _active_region_data()
	if region_data.is_empty():
		return
	region_title = String(region_data.get("title", region_data.get("id", "Vale")))
	_meters_per_unit = maxf(float(region_data.get("scale_m_per_unit", 1.0)), 0.01)
	_region = GeoRegionRenderer.new()
	_region.name = String(region_data.get("id", "Regiao"))
	add_child(_region)
	_region.set_meters_per_unit(_meters_per_unit)
	_region.set_estilo_tripo(estilo_tripo())
	_region.build_region(String(region_data["geometry"]), String(region_data["scenario"]))
	landmarks = _region.landmarks
	areas = _region.areas
	for landmark in landmarks:
		var nome := String(landmark["name"])
		var contador := 2
		while ancoras.has(nome):
			nome = "%s %d" % [String(landmark["name"]), contador]
			contador += 1
		ancoras[nome] = landmark["position"]
	if region_data["id"] == "bom_jesus_dos_pobres":
		_construir_vila()
	var faltando := CatalogoAssets.relatorio_faltando()
	if estilo_tripo() and not faltando.is_empty():
		print("CATALOGO: ", faltando)


func _active_region_data() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAP_CATALOG))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Catálogo de regiões inválido: " + MAP_CATALOG)
		return {}
	for entry_value in data.get("regions", []):
		var entry: Dictionary = entry_value
		if entry.get("id", "") == data.get("active_region", ""):
			var scale := float(entry.get("scale_m_per_unit", 1.0))
			if scale <= 0.0:
				push_error("A escala da região (scale_m_per_unit) precisa ser positiva.")
				return {}
			return entry
	push_error("A região ativa não foi encontrada no catálogo.")
	return {}


# ---------------------------------------------------------------------------
# Luz: sol, lua, céu e ambiente seguem o relógio do autoload Dia.
# ---------------------------------------------------------------------------

func _build_lighting() -> void:
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sun_angle_max = 12.0
	var sky := Sky.new()
	sky.sky_material = _sky_material
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.fog_enabled = true
	_environment.fog_density = 0.0
	_environment.fog_sky_affect = 0.25
	var world_environment := WorldEnvironment.new()
	world_environment.environment = _environment
	add_child(world_environment)
	_sun = DirectionalLight3D.new()
	_sun.name = "Sol"
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 180.0
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(_sun)
	_moon = DirectionalLight3D.new()
	_moon.name = "Lua"
	_moon.light_color = Color("9fb3d6")
	_moon.shadow_enabled = false
	add_child(_moon)
	_aplicar_hora(Dia.hora)
	Dia.hora_mudou.connect(_aplicar_hora)


## Curvas de cor por hora: madrugada azul, alvorada rosada, meio-dia claro, entardecer dourado.
func _aplicar_hora(hora: float) -> void:
	var luz := Dia.luz_do_dia()
	var elevacao := Dia.elevacao_solar()
	var azimute := Dia.azimute_solar()
	var horizonte := 1.0 - smoothstep(6.0, 22.0, absf(elevacao))
	_sun.rotation_degrees = Vector3(-maxf(elevacao, 2.0), azimute, 0.0)
	_sun.light_energy = lerpf(0.0, 1.15, luz)
	_sun.light_color = Color("fff0d0").lerp(Color("ff9d5c"), horizonte * 0.85)
	_sun.visible = luz > 0.02
	_moon.rotation_degrees = Vector3(-52.0, -azimute + 180.0, 0.0)
	_moon.light_energy = lerpf(0.26, 0.0, luz)
	_moon.visible = luz < 0.98
	var noite := 1.0 - luz
	_sky_material.sky_top_color = Color("709aaa").lerp(Color("0b1327"), noite).lerp(Color("5e6fa8"), horizonte * luz * 0.4)
	_sky_material.sky_horizon_color = Color("e8d9bc").lerp(Color("1a2440"), noite).lerp(Color("f2a266"), horizonte * luz * 0.7)
	_sky_material.ground_bottom_color = Color("586957").lerp(Color("0a0e18"), noite)
	_sky_material.ground_horizon_color = Color("e8d9bc").lerp(Color("1a2440"), noite)
	_sky_material.sun_angle_max = lerpf(4.0, 14.0, horizonte)
	_environment.ambient_light_color = Color("cad9d5").lerp(Color("2b3454"), noite)
	_environment.ambient_light_energy = lerpf(0.3, 0.65, luz)
	_environment.fog_light_color = Color("e8d9bc").lerp(Color("111a2e"), noite)
	_environment.fog_density = lerpf(0.004, 0.0008, luz) + horizonte * luz * 0.003
	if _luzes != null:
		_luzes.aplicar_hora(hora)


# ---------------------------------------------------------------------------
# A vila: cada função decide o estilo pelo catálogo.
# ---------------------------------------------------------------------------

func _construir_vila() -> void:
	var praca := Vector3.ZERO
	var taipa := _u(Vector3(-52, 0, -27))
	ancoras["Casa de taipa"] = taipa
	ancoras["Casa de Carro Quebrado"] = _u(Vector3(40, 0, -35))
	# Casas da praça
	_construcao("casa_taipa", taipa, 0.0, func(at: Vector3): _casa_de_taipa_referencia(at), 1.0, "Casa de taipa")
	_construcao("casa_carro_quebrado", ancoras["Casa de Carro Quebrado"], 0.0, func(at: Vector3): _house(at, Color("e8dcc4"), Color("a8442f")), 1.0, "Casa de Carro Quebrado")
	# Referência: 12°48'46.28"S 38°46'49.07"W; afastar a casa do eixo da Rua Principal.
	var casa_estrada_referencia: Vector3 = _region.wgs84_to_world(-12.812855555555556, -38.780297222222224)
	ancoras["Casa da estrada"] = _region.position_beside_road(casa_estrada_referencia, "Rua Principal", 10.0)
	_construcao("casa_taipa", ancoras["Casa da estrada"], 0.0, func(at: Vector3): _house(at, Color("dfb980"), Color("ae6950")), 1.0, "Casa da estrada")
	_build_farm()
	_build_trees()
	_build_details()
	_build_landmark_details()
	_build_pecas()
	_build_luzes_epoca()
	if COMPARAR_MANGUEIRAS:
		_bancada_mangueiras(Vector3(-2, 0, -30))


## Construção: GLB do Tripo com colisão em caixa; senão o construtor procedural.
func _construcao(chave: String, origin: Vector3, yaw: float, procedural: Callable, size: float = 1.0, nome: String = "") -> Node3D:
	var is_house := _is_house_key(chave)
	var placed_origin := origin
	if is_house:
		var spec: Dictionary = CatalogoAssets.PECAS.get(chave, {})
		var footprint_radius := maxf(5.5, float(spec.get("largura", 6.5)) * size * 0.75 + 1.0)
		placed_origin = _reserve_house_site(origin, footprint_radius, nome)
		if not placed_origin.is_finite():
			return null
		if not nome.is_empty():
			ancoras[nome] = placed_origin
	if estilo_tripo():
		var node := CatalogoAssets.instanciar(chave, self, placed_origin, size, yaw)
		if node != null:
			CatalogoAssets.colisao(chave, node, self, placed_origin, size, yaw)
			var piso := float(CatalogoAssets.PECAS[chave].get("piso", 0.0))
			var limites: AABB = node.get_meta("limites")
			_box(Vector3(limites.size.x + 1.6, 0.16, limites.size.z + 1.6), placed_origin + Vector3(0, piso + 0.08, 0), Color("958d79"), true, null, yaw)
			if is_house:
				_register_house(nome if not nome.is_empty() else chave.capitalize(), chave, placed_origin, yaw, limites.size, "Tripo")
			return node
	if is_house:
		procedural.call(placed_origin)
		_register_house(nome if not nome.is_empty() else chave.capitalize(), chave, placed_origin, yaw, Vector3(5.9, 5.4, 5.1), "Procedural")
	else:
		procedural.call()
	return null


func _is_house_key(chave: String) -> bool:
	return chave.begins_with("casa_") or chave == "venda"


func _reserve_house_site(preferred: Vector3, radius: float, name: String) -> Vector3:
	var placed := _find_clear_site(preferred, radius, 40)
	if not placed.is_finite():
		push_error("Não há terreno livre para a casa: " + name)
		return Vector3.INF
	_house_sites.append({"position": placed, "radius": radius})
	return placed


func _find_clear_site(preferred: Vector3, radius: float, rings: int, check_manual_trees: bool = true) -> Vector3:
	if _site_is_clear(preferred, radius, check_manual_trees):
		return preferred
	for ring in range(1, rings + 1):
		var distance := float(ring) * SITE_SEARCH_STEP
		for direction in range(SITE_SEARCH_DIRECTIONS):
			var angle := TAU * float(direction) / float(SITE_SEARCH_DIRECTIONS)
			var candidate := preferred + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
			if _site_is_clear(candidate, radius, check_manual_trees):
				return candidate
	return Vector3.INF


func _site_is_clear(position: Vector3, radius: float, check_manual_trees: bool = true) -> bool:
	if not _region.is_build_site_clear(position, radius):
		return false
	var center := Vector2(position.x, position.z)
	for site in _house_sites:
		var other: Vector3 = site["position"]
		var separation: float = radius + float(site["radius"]) + 1.0
		if center.distance_squared_to(Vector2(other.x, other.z)) < separation * separation:
			return false
	if check_manual_trees:
		for site in _manual_tree_sites:
			var other: Vector3 = site["position"]
			var separation: float = radius + float(site["radius"]) + 1.0
			if center.distance_squared_to(Vector2(other.x, other.z)) < separation * separation:
				return false
	return true


func _register_house(nome: String, chave: String, origin: Vector3, yaw: float, bounds: Vector3, style: String) -> void:
	var house := Area3D.new()
	house.name = "AlvoCasa%s" % (_house_targets.size() + 1)
	house.position = origin
	house.rotation.y = yaw
	house.collision_layer = HOUSE_INTERACTION_LAYER
	house.collision_mask = 0
	house.monitoring = false
	house.add_to_group("interactive_house")
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(bounds.x, 3.0), maxf(bounds.y, 3.0), maxf(bounds.z, 3.0))
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = shape.size.y * 0.5
	house.add_child(collision)
	var properties := {"name": nome, "object_key": chave, "position": origin, "style": style}
	house.set_meta("house_properties", properties)
	house.set_meta("house_bounds", shape.size)
	var label := Label3D.new()
	label.name = "PropriedadesCasa"
	label.font_size = 30
	label.outline_size = 8
	label.pixel_size = 0.0034
	label.width = 720.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("f2dc9a")
	label.position.y = maxf(shape.size.y + 1.0, 6.0)
	house.add_child(label)
	house.set_meta("house_label", label)
	add_child(house)
	_house_targets.append(house)
	_update_house_label(house)


func _house_from_collider(collider: Object) -> Area3D:
	if collider == null or not is_instance_valid(collider):
		return null
	var node := collider as Node
	while node != null:
		if node is Area3D and _house_targets.has(node):
			return node as Area3D
		node = node.get_parent()
	return null


func _update_house_label(house: Area3D) -> void:
	var label: Label3D = house.get_meta("house_label")
	var properties: Dictionary = house.get_meta("house_properties")
	if house == _selected_house:
		label.text = format_house_properties(properties)
		label.visible = true
	elif house == _hovered_house:
		label.text = "%s\nClique para ver propriedades" % properties["name"]
		label.visible = true
	else:
		label.visible = false


## Adereço: GLB do Tripo ou peça procedural de FloraReconcavo.
func _adereco(chave: String, origin: Vector3, yaw: float = 0.0, size: float = 1.0) -> Node3D:
	if estilo_tripo():
		var node := CatalogoAssets.instanciar(chave, self, origin, size, yaw)
		if node != null:
			CatalogoAssets.colisao(chave, node, self, origin, size, yaw)
			return node
	var peca: Node3D = null
	match chave:
		"poco": peca = FloraReconcavo.poco()
		"cruzeiro": peca = FloraReconcavo.cruzeiro()
		"carroca": peca = FloraReconcavo.carroca()
		"varal": peca = FloraReconcavo.varal()
		"lenha": peca = FloraReconcavo.pilha_lenha()
		"pote": peca = FloraReconcavo.pote_agua()
		"banco": peca = FloraReconcavo.banco_praca()
		"cerca": peca = FloraReconcavo.cerca(4.0 * size)
		"lampiao_poste": peca = FloraReconcavo.lampiao_poste()
		"fogueira": peca = FloraReconcavo.fogueira()
		"tumulo": peca = FloraReconcavo.tumulo()
		"pedras": peca = FloraReconcavo.pedras()
		"mandioca_canteiro": peca = FloraReconcavo.canteiro_mandioca()
		"moita": peca = FloraReconcavo.moita()
		"candeeiro": peca = FloraReconcavo.candeeiro()
		_:
			return null
	peca.position = origin
	peca.rotation.y = yaw
	peca.scale = Vector3.ONE * size
	add_child(peca)
	return peca


## Árvore com nome: GLB do Tripo (colisão no tronco) ou espécie procedural.
func _arvore(especie: String, origin: Vector3, size: float = 1.0, yaw: float = 0.0) -> void:
	var tree_radius := maxf(2.0, size * 2.4)
	var placed_origin := _find_clear_site(origin, tree_radius, 24, false)
	if not placed_origin.is_finite():
		push_warning("Não há terreno livre para a árvore: " + especie)
		return
	_manual_tree_sites.append({"position": placed_origin, "radius": tree_radius})
	if estilo_tripo():
		var node := CatalogoAssets.instanciar(especie, self, placed_origin, size, yaw)
		if node != null:
			CatalogoAssets.colisao(especie, node, self, placed_origin, size, yaw)
			return
	var built: Dictionary = FloraReconcavo.especie(especie, size)
	var instance := MeshInstance3D.new()
	instance.name = especie.capitalize()
	instance.mesh = built.mesh
	instance.position = placed_origin
	instance.rotation.y = yaw
	add_child(instance)
	var shape := CylinderShape3D.new()
	shape.radius = float(built.trunk_radius) + 0.08
	shape.height = float(built.trunk_height)
	_body(shape, placed_origin + Vector3(0, float(built.trunk_height) * 0.5, 0))


func _build_farm() -> void:
	var origin: Vector3 = _region.get_feature_center("Fazenda", "area")
	ancoras["Roçado"] = origin
	if _adereco("mandioca_canteiro", origin, 0.2) == null:
		for row in range(3):
			_box(Vector3(5.6, 0.1, 0.88), origin + Vector3(0, 0.055, row * 1.35), Color("826346"))
			for column in range(7):
				var crop := CylinderMesh.new()
				crop.top_radius = 0.02
				crop.bottom_radius = 0.24
				crop.height = 0.54 + row * 0.09
				crop.radial_segments = 5
				_mesh(crop, origin + Vector3(-2.3 + column * 0.75, 0.35, row * 1.35), Color("8fa85e"))
	_adereco("cerca", origin + Vector3(-4, 0, 6), 0.0, 2.0)
	_adereco("cerca", origin + Vector3(-4, 0, -3), 0.0, 2.0)
	_box(Vector3(0.85, 1.0, 0.85), origin + Vector3(5.2, 0.5, 2), WOOD, true)
	_box(Vector3(0.95, 0.11, 0.95), origin + Vector3(5.2, 1.0, 2), Color("b1966c"))


func _build_trees() -> void:
	# Posições anotadas em metros reais ao redor da Praça (a cena converte para unidades).
	# Espécies de docs/AMBIENTACAO.md §4.
	_arvore("pau_brasil", _u(Vector3(-82, 0, 5)))
	var plan: Array = [
		["mangueira", Vector3(-75, 0, -70), 1.0, 0.4],
		["cajueiro", Vector3(-78, 0, -35), 1.0, 1.9],
		["ipe_amarelo", Vector3(-85, 0, 47), 1.0, 0.0],
		["jaqueira", Vector3(-44, 0, 93), 1.0, 2.6],
		["mangueira", Vector3(55, 0, 99), 1.1, 3.1],
		["ipe_roxo", Vector3(72, 0, 77), 0.95, 1.2],
		["cajueiro", Vector3(85, 0, 30), 1.05, 4.0],
		["jaqueira", Vector3(85, 0, -60), 0.9, 0.7],
		["embauba", Vector3(44, 0, -86), 1.0, 0.0],
		["dendezeiro", Vector3(-46, 0, -95), 1.0, 2.2],
		["mangueira", Vector3(-34, 0, 38), 0.9, 5.2],
		["mangueira", Vector3(22, 0, -44), 0.85, 1.6],
	]
	for entry in plan:
		_arvore(String(entry[0]), _u(entry[1]), float(entry[2]), float(entry[3]))
	var taipa := _u(Vector3(-52, 0, -27))
	for offset in [Vector3(-3.2, 0, -4.6), Vector3(-1.6, 0, -5.9), Vector3(0.4, 0, -4.9), Vector3(-4.6, 0, -3.0)]:
		_arvore("bananeira", taipa + offset, 0.9, offset.x * 1.3)
	var bar: Vector3 = _region.get_feature_center("Bar", "poi")
	for offset in [Vector3(-6.0, 0, 5.5), Vector3(-9.5, 0, 2.0)]:
		_arvore("dendezeiro", bar + offset, 0.95, offset.z)
	var farm: Vector3 = _region.get_feature_center("Fazenda", "area")
	_arvore("mangueira", farm + Vector3(-9.5, 0, -6.5), 1.15, 0.9)
	_arvore("cajueiro", farm + Vector3(9.0, 0, -8.0), 1.0, 2.4)
	_arvore("cajueiro", farm + Vector3(11.0, 0, 8.5), 0.9, 0.3)
	var church: Vector3 = _region.get_feature_center("Igreja", "poi")
	_arvore("ipe_roxo", church + Vector3(-8.5, 0, 9.0), 1.0, 0.0)
	_arvore("ipe_amarelo", church + Vector3(8.5, 0, 9.5), 1.0, 1.1)
	var pier: Vector3 = _region.get_feature_center("Pier", "poi")
	var toward_praca: Vector3 = (_region.get_feature_center("Praça", "poi") - pier).normalized()
	for step in [Vector3(14.0, 0, 5.0), Vector3(20.0, 0, -4.0)]:
		_arvore("coqueiro", pier + toward_praca * step.x + Vector3(0, 0, step.z), 1.0, step.z)


func _build_details() -> void:
	# Canteiros de flores da praça: moitas do Tripo ou caixinhas coloridas.
	for i in range(28):
		var x: float = (-25.0 + float(i % 7) * 8.0) / _meters_per_unit
		var z: float = (-21.0 + floorf(float(i) / 7.0) * 14.0) / _meters_per_unit
		if absf(x) < 3.0 / _meters_per_unit:
			continue
		if _adereco("moita", Vector3(x, 0, z), float(i) * 0.7, 0.55 + float(i % 3) * 0.12) != null:
			continue
		for j in range(3):
			_box(Vector3(0.05, 0.28, 0.05), Vector3(x + j * 0.21, 0.14, z + (j % 2) * 0.25), LEAVES)
			_box(Vector3(0.16, 0.10, 0.16), Vector3(x + j * 0.21, 0.30, z + (j % 2) * 0.25), Color("e4c782") if i % 2 == 0 else Color("ce9d99"))


func _build_landmark_details() -> void:
	var church: Vector3 = _region.get_feature_center("Igreja", "poi")
	ancoras["Igreja"] = church
	_construcao("capela", church, 0.0, func(): _igreja_procedural(church))
	var bar: Vector3 = _region.get_feature_center("Bar", "poi") + Vector3(8, 0, 3)
	ancoras["Bar"] = bar
	_construcao("venda", bar, 0.0, func(at: Vector3): _house(at, Color("c6a16d"), Color("8b523b")), 1.0, "Venda do Bar")
	var restaurante: Vector3 = _region.get_feature_center("Restaurante", "poi") + Vector3(7, 0, 4)
	ancoras["Restaurante"] = restaurante
	_construcao("casa_pasto", restaurante, 0.0, func(at: Vector3): _house(at, Color("cdbb92"), Color("97563f")), 1.0, "Restaurante")
	var pier: Vector3 = _region.get_feature_center("Pier", "poi")
	ancoras["Pier"] = pier
	var pier_dir: Vector3 = (pier - _region.get_feature_center("Praça", "poi")).normalized()
	# O modelo do Tripo é centrado; empurra-o mar adentro para começar na areia.
	var pier_origin: Vector3 = pier + pier_dir * 4.0 if estilo_tripo() else pier
	_construcao("pier", pier_origin, atan2(pier_dir.x, pier_dir.z), func():
		_box(Vector3(4.5, 0.2, 17), pier + Vector3(0, -0.1, 0), Color("85684b"), true)
		for offset in [-7.0, 0.0, 7.0]:
			for side in [-1.8, 1.8]:
				_box(Vector3(0.3, 1.5, 0.3), pier + Vector3(side, -0.75, offset), WOOD))
	var bridge: Vector3 = _region.get_feature_center("Ponte", "poi")
	ancoras["Ponte"] = bridge
	_construcao("ponte", bridge, 0.0, func():
		_box(Vector3(11, 0.35, 6), bridge + Vector3(0, 0.22, 0), Color("987b57"), true)
		for side in [-2.8, 2.8]:
			_box(Vector3(11, 0.18, 0.15), bridge + Vector3(0, 0.95, side), WOOD))
	var lookout: Vector3 = _region.get_feature_center("Mirante", "poi")
	ancoras["Mirante"] = lookout
	_construcao("mirante", lookout, 0.0, func():
		_box(Vector3(6, 0.24, 6), lookout + Vector3(0, 0.65, 0), Color("9c7a52"), true)
		for x in [-2.8, 2.8]:
			for z in [-2.8, 2.8]:
				_box(Vector3(0.22, 1.45, 0.22), lookout + Vector3(x, 0.73, z), WOOD))
	var cemetery: Vector3 = _region.get_feature_center("Cemitério", "poi")
	ancoras["Cemitério"] = cemetery
	for index in range(12):
		var grave := cemetery + Vector3((index % 4) * 2.3 - 3.45, 0, floorf(index / 4.0) * 3.0 - 3.0)
		if _adereco("tumulo", grave, 0.0, 0.9 + float(index % 3) * 0.08) == null:
			_box(Vector3(0.72, 0.15, 1.45), grave + Vector3(0, 0.08, 0), Color("a9a9a0"))
			_box(Vector3(0.12, 0.9, 0.12), grave + Vector3(0, 0.6, -0.55), WOOD)
			_box(Vector3(0.48, 0.12, 0.12), grave + Vector3(0, 0.72, -0.55), WOOD)
	var stones: Vector3 = _region.get_feature_center("Pedras", "poi")
	ancoras["Pedras"] = stones
	if _adereco("pedras", stones, 0.4, 1.4) == null:
		for index in range(13):
			var rock := SphereMesh.new()
			rock.radius = 0.8 + (index % 3) * 0.4
			rock.height = 0.8 + (index % 4) * 0.3
			rock.radial_segments = 7
			rock.rings = 4
			_mesh(rock, stones + Vector3((index % 5) * 2.8 - 5.6, 0.35, floorf(index / 5.0) * 2.9 - 2.9), Color("929c92"))


func _igreja_procedural(church: Vector3) -> void:
	_box(Vector3(8, 0.25, 13), church + Vector3(0, 0.125, 0), Color("958d79"), true)
	_box(Vector3(7.4, 5.2, 12), church + Vector3(0, 2.7, 0), Color("eee5cf"), true)
	var roof := PrismMesh.new()
	roof.size = Vector3(8.8, 2.6, 13.3)
	_mesh(roof, church + Vector3(0, 6.4, 0), Color("a55b3c"))
	_box(Vector3(2.3, 8.2, 2.3), church + Vector3(0, 4.2, 6.0), Color("e5dcc8"), true)
	_box(Vector3(0.22, 2.0, 0.22), church + Vector3(0, 9.2, 6.0), WOOD)
	_box(Vector3(1.4, 0.2, 0.22), church + Vector3(0, 9.45, 6.0), WOOD)


func _build_pecas() -> void:
	# Peças soltas do 2D (gerador_mundo.gd ADORNOS): poço e bancos na praça, cruzeiro na
	# igreja, varal, lenha e pote na casa de taipa, carroça na fazenda.
	ancoras["Poço"] = Vector3(4.2, 0, 5.4)
	_adereco("poco", Vector3(4.2, 0, 5.4), 0.6)
	_adereco("banco", _u(Vector3(-4.6, 0, -0.1)))
	_adereco("banco", Vector3(3.2, 0, -7.0), PI)
	var taipa := _u(Vector3(-52, 0, -27))
	_adereco("varal", taipa + Vector3(-4.9, 0, 1.4), 0.35)
	_adereco("lenha", taipa + Vector3(3.6, 0, -0.4), 0.0)
	_adereco("pote", taipa + Vector3(2.4, 0, 2.9))
	var church: Vector3 = _region.get_feature_center("Igreja", "poi")
	_adereco("cruzeiro", church + Vector3(0, 0, 9.0))
	var farm: Vector3 = _region.get_feature_center("Fazenda", "area")
	_adereco("carroca", farm + Vector3(8.5, 0, -5.5), -0.6)
	var pier: Vector3 = _region.get_feature_center("Pier", "poi")
	_adereco("pote", pier + Vector3(1.4, 0.1, -6.5))
	# Itens de mão espalhados como cenário (só no estilo Tripo, quando existirem).
	if estilo_tripo():
		var itens := [
			["machado", taipa + Vector3(3.9, 0.55, 0.6), 0.9],
			["cesto", taipa + Vector3(1.6, 0, 3.4), 0.2],
			["moringa", taipa + Vector3(-1.0, 0, 3.1), 0.0],
			["enxada", farm + Vector3(5.6, 0.0, 1.2), 1.2],
			["balde", ancoras["Poço"] + Vector3(1.3, 0, 0.4), 0.0],
			["peixe", pier + Vector3(-1.2, 0.05, -4.0), 1.0],
			["vara_pescar", pier + Vector3(1.6, 0.05, -2.0), 0.3],
			["farinha", _region.get_feature_center("Bar", "poi") + Vector3(6.0, 0, 6.5), 0.0],
			["cacho_banana", _region.get_feature_center("Restaurante", "poi") + Vector3(5.0, 0.0, 7.6), 0.0],
		]
		for item in itens:
			CatalogoAssets.instanciar(String(item[0]), self, item[1], 1.0, float(item[2]))


## Luzes de 1887: lampiões a óleo nas esquinas da Praça, candeeiros nas portas, fogueira
## no terreiro e velas nas janelas. Acendem ao entardecer e apagam ao amanhecer.
func _build_luzes_epoca() -> void:
	_luzes = LuzesEpoca.new()
	_luzes.name = "LuzesDeEpoca"
	add_child(_luzes)
	var praca := Vector3.ZERO
	var taipa := _u(Vector3(-52, 0, -27))
	var church: Vector3 = _region.get_feature_center("Igreja", "poi")
	var bar: Vector3 = ancoras.get("Bar", Vector3.ZERO)
	var restaurante: Vector3 = ancoras.get("Restaurante", Vector3.ZERO)
	var farm: Vector3 = _region.get_feature_center("Fazenda", "area")
	var pier: Vector3 = _region.get_feature_center("Pier", "poi")
	for corner in [Vector3(-9.0, 0, 8.5), Vector3(7.5, 0, -12.0), Vector3(8.0, 0, 9.5)]:
		_luzes.lampiao(praca + corner, _adereco("lampiao_poste", praca + corner, 0.0))
	_luzes.lampiao(church + Vector3(-6.0, 0, 8.0), _adereco("lampiao_poste", church + Vector3(-6.0, 0, 8.0)))
	_luzes.candeeiro(taipa + Vector3(0.92, 2.55, 2.4), _adereco("candeeiro", taipa + Vector3(0.92, 2.45, 2.35)))
	_luzes.candeeiro(bar + Vector3(0.0, 2.6, 3.2), _adereco("candeeiro", bar + Vector3(0.0, 2.5, 3.15)))
	_luzes.candeeiro(restaurante + Vector3(0.0, 2.6, 3.2), _adereco("candeeiro", restaurante + Vector3(0.0, 2.5, 3.15)))
	_luzes.candeeiro(pier + Vector3(0.0, 1.9, -7.0), _adereco("candeeiro", pier + Vector3(0.3, 1.8, -7.0)))
	ancoras["Fogueira"] = farm + Vector3(7.0, 0, 4.5)
	_luzes.fogueira(farm + Vector3(7.0, 0, 4.5), _adereco("fogueira", farm + Vector3(7.0, 0, 4.5)))
	_luzes.janela(taipa + Vector3(-1.35, 1.9, 2.2))
	_luzes.janela(church + Vector3(0, 3.6, 4.6))
	_luzes.aplicar_hora(Dia.hora)


func _bancada_mangueiras(origin: Vector3) -> void:
	var spacing := 10.0
	var procedural: Dictionary = FloraReconcavo.especie("mangueira", 1.0)
	var proc := MeshInstance3D.new()
	proc.name = "ComparaProcedural"
	proc.mesh = procedural.mesh
	proc.position = origin + Vector3(-spacing, 0, 0)
	add_child(proc)
	var tripo := CatalogoAssets.instanciar("mangueira", self, origin + Vector3(spacing, 0, 0), 1.0, 0.0)
	for entry in [["Procedural", proc, origin + Vector3(-spacing, 0, 0)], ["Tripo Malha Smart", tripo, origin + Vector3(spacing, 0, 0)]]:
		if entry[1] == null:
			continue
		var label := Label3D.new()
		label.text = "%s\n%s triângulos" % [entry[0], _milhar(_contar_triangulos(entry[1]))]
		label.font_size = 64
		label.outline_size = 12
		label.pixel_size = 0.006
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = (entry[2] as Vector3) + Vector3(0, 9.2, 0)
		add_child(label)


func _contar_triangulos(node: Node) -> int:
	var total := 0
	var instances: Array = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		instances.append(node)
	for child in instances:
		var mesh: Mesh = (child as MeshInstance3D).mesh
		if mesh == null:
			continue
		for surface in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			total += indices.size() / 3 if indices.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


func _milhar(value: int) -> String:
	var text := str(value)
	var result := ""
	while text.length() > 3:
		result = "." + text.substr(text.length() - 3) + result
		text = text.substr(0, text.length() - 3)
	return text + result


# ---------------------------------------------------------------------------
# Construtores procedurais (estilo "procedural"): casas de caixas e materiais simples.
# ---------------------------------------------------------------------------

func _house(origin: Vector3, wall: Color, roof_color: Color) -> void:
	_box(Vector3(5.6, 0.25, 4.8), origin + Vector3(0, 0.125, 0), Color("96968b"), true)
	_box(Vector3(5.0, 3.1, 4.2), origin + Vector3(0, 1.7, 0), wall, true)
	var roof := PrismMesh.new()
	roof.size = Vector3(5.9, 2.0, 5.1)
	_mesh(roof, origin + Vector3(0, 4.0, 0), roof_color)
	_box(Vector3(0.58, 1.7, 0.62), origin + Vector3(1.65, 4.2, -0.9), Color("9b8b77"))
	_box(Vector3(0.76, 0.18, 0.79), origin + Vector3(1.65, 5.1, -0.9), Color("c4b59c"))
	_box(Vector3(1.12, 2.05, 0.13), origin + Vector3(0, 1.28, 2.14), WOOD)
	_box(Vector3(1.6, 0.22, 0.8), origin + Vector3(0, 0.13, 2.5), Color("aea78d"), true)
	_box(Vector3(5.08, 0.16, 0.17), origin + Vector3(0, 2.94, 2.16), WOOD)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.17, 3.15, 0.17), origin + Vector3(side * 2.4, 1.73, 2.16), WOOD)
		_box(Vector3(1.03, 1.0, 0.15), origin + Vector3(side * 1.5, 1.93, 2.17), WOOD)
		_box(Vector3(0.8, 0.77, 0.17), origin + Vector3(side * 1.5, 1.93, 2.19), Color("b6d5cd"))
		_box(Vector3(0.07, 0.85, 0.19), origin + Vector3(side * 1.5, 1.93, 2.21), WOOD)
		_box(Vector3(0.85, 0.07, 0.19), origin + Vector3(side * 1.5, 1.93, 2.21), WOOD)
		_box(Vector3(1.23, 0.27, 0.46), origin + Vector3(side * 1.5, 1.29, 2.35), WOOD)
		_box(Vector3(1.09, 0.22, 0.37), origin + Vector3(side * 1.5, 1.49, 2.36), LEAVES)


func _node_bounds(node: Node3D) -> AABB:
	var combined := AABB()
	var has_bounds := false
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var relative_transform := node.global_transform.affine_inverse() * mesh_instance.global_transform
		var bounds := relative_transform * mesh_instance.get_aabb()
		combined = combined.merge(bounds) if has_bounds else bounds
		has_bounds = true
	assert(has_bounds, "A casa importada precisa conter uma malha 3D")
	return combined


func _casa_de_taipa_referencia(origin: Vector3) -> void:
	# Casa pequena da rua do Carro Quebrado, reinterpretada para Bom Jesus em 1887.
	# A volumetria simples deixa a porta e a janela de folha cega legíveis a pé.
	var cal := Color("f2ead8")
	var cal_suja := Color("d7c8a7")
	var barro_exposto := Color("a9815d")
	var telha := Color("a8442f")
	var madeira_velha := Color("4b3327")
	var parede_material := _material_de_superficie(CASA_TAIPA_CAL_TEXTURE, Vector3(1.65, 1.20, 1.0))
	var telhado_material := _material_de_superficie(TELHA_COLONIAL_TEXTURE, Vector3(2.0, 1.55, 1.0))

	# Alicerce baixo e piso de terreiro, antes das paredes caiadas de taipa.
	_box(Vector3(5.65, 0.28, 4.85), origin + Vector3(0, 0.14, 0), Color("8c8879"), true)
	_box(Vector3(6.5, 0.035, 1.4), origin + Vector3(0, 0.03, 2.65), PATH)
	_box(Vector3(5.0, 3.1, 4.2), origin + Vector3(0, 1.83, 0), cal, true, parede_material)

	# Telhado de duas águas com beiral curto e fileiras de telha-canal desbotada.
	var roof := PrismMesh.new()
	roof.size = Vector3(5.9, 1.72, 5.1)
	_mesh(roof, origin + Vector3(0, 3.82, 0), telha, telhado_material)

	# Frente: porta escura à direita, janela única à esquerda, como a casa observada.
	_box(Vector3(1.15, 2.26, 0.12), origin + Vector3(0.92, 1.27, 2.14), madeira_velha)
	for plank in range(5):
		var plank_color := Color("5b3d2d") if plank % 2 == 0 else madeira_velha
		_box(Vector3(0.18, 2.15, 0.035), origin + Vector3(0.51 + plank * 0.20, 1.28, 2.215), plank_color)
	_box(Vector3(1.36, 0.12, 0.33), origin + Vector3(0.92, 0.18, 2.39), Color("8b7354"))
	_box(Vector3(0.10, 0.10, 0.06), origin + Vector3(1.34, 1.30, 2.29), Color("c8922e"))

	_box(Vector3(1.08, 1.18, 0.10), origin + Vector3(-1.35, 1.91, 2.15), Color("332923"))
	_box(Vector3(1.24, 0.12, 0.18), origin + Vector3(-1.35, 2.55, 2.21), madeira_velha)
	_box(Vector3(1.24, 0.12, 0.18), origin + Vector3(-1.35, 1.27, 2.21), madeira_velha)
	for plank in range(5):
		var shutter_color := Color("80614b") if plank == 1 else madeira_velha
		_box(Vector3(0.16, 1.13, 0.06), origin + Vector3(-1.76 + plank * 0.205, 1.91, 2.23), shutter_color)

	# Cal descascada deixa aparecer barro nas partes baixas e perto da porta.
	_box(Vector3(1.75, 0.34, 0.025), origin + Vector3(-1.45, 0.54, 2.115), cal_suja)
	_box(Vector3(0.63, 0.22, 0.025), origin + Vector3(1.82, 0.67, 2.115), barro_exposto)
	_box(Vector3(0.32, 0.54, 0.025), origin + Vector3(2.08, 2.06, 2.115), cal_suja)
	_box(Vector3(0.58, 0.18, 0.025), origin + Vector3(-0.23, 2.76, 2.115), cal_suja)

func _fence(origin: Vector3, count: int, spacing: float) -> void:
	for i in range(count):
		_box(Vector3(0.15, 1.12, 0.15), origin + Vector3(i * spacing, 0.56, 0), WOOD, true)
	var width: float = (count - 1) * spacing
	for height in [0.4, 0.87]:
		_box(Vector3(width, 0.12, 0.12), origin + Vector3(width * 0.5, height, 0), Color("987650"), true)


func _box(size: Vector3, position: Vector3, color: Color, solid: bool = false, material_override: Material = null, yaw: float = 0.0) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var instance := _mesh(box, position, color, material_override)
	instance.rotation.y = yaw
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		_body(shape, position, "", yaw)
	return instance


func _mesh(mesh: Mesh, position: Vector3, color: Color, material_override: Material = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	if material_override != null:
		instance.material_override = material_override
	else:
		if not _materials.has(color):
			var material := StandardMaterial3D.new()
			material.albedo_color = color
			material.roughness = 0.9
			_materials[color] = material
		instance.material_override = _materials[color] as StandardMaterial3D
	add_child(instance)
	return instance


func _material_de_superficie(texture: Texture2D, uv_scale: Vector3) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_repeat = 1
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.uv1_scale = uv_scale
	material.roughness = 0.92
	return material


func _body(shape: Shape3D, position: Vector3, body_name: String = "", yaw: float = 0.0) -> void:
	var body := StaticBody3D.new()
	if not body_name.is_empty():
		body.name = body_name
	body.position = position
	body.rotation.y = yaw
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
