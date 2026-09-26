extends Node3D
## Região geográfica com detalhes artesanais junto aos pontos de interesse.
## O catálogo define quantos metros reais cabem em uma unidade do Godot (`scale_m_per_unit`).

const PATH := Color("c5ad7a")
const WOOD := Color("735139")
const LEAVES := Color("487557")
const GeoRegionRenderer = preload("res://scripts/prototipo_3d/geo_region_renderer.gd")
const MAP_CATALOG := "res://data/mapas/regioes.json"
const TRIPO_HOUSE_SCENE := preload("res://assets/prototipo_3d/casas/casa_carro_quebrado_tripo.glb")
const TRIPO_HOUSE_WIDTH := 5.2
const PAU_BRASIL_SCENE := preload("res://assets/prototipo_3d/arvores/pau_brasil_tripo.glb")
const CASA_TAIPA_CAL_TEXTURE := preload("res://assets/prototipo_3d/materiais/cal_taipa_envelhecida_v1.png")
const TELHA_COLONIAL_TEXTURE := preload("res://assets/prototipo_3d/materiais/telha_colonial_envelhecida_v1.png")
var _materials: Dictionary = {}
var landmarks: Array[Dictionary] = []
var areas: Array[Dictionary] = []
var region_title := "Vale"
var _region = null
var _meters_per_unit := 1.0


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


func get_feature_center(feature_name: String, kind: String = "") -> Vector3:
	return _region.get_feature_center(feature_name, kind) if _region else Vector3.ZERO


func get_region_title() -> String:
	return region_title


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
	_region.build_region(String(region_data["geometry"]), String(region_data["scenario"]))
	landmarks = _region.landmarks
	areas = _region.areas
	if region_data["id"] == "bom_jesus_dos_pobres":
		_casa_de_taipa_referencia(_u(Vector3(-52, 0, -27)))
		_tripo_house(_u(Vector3(40, 0, -35)))
		_house(Vector3(32, 0, 72), Color("dfb980"), Color("ae6950"))
		_build_farm()
		_build_trees()
		_build_details()
		_build_landmark_details()
		_build_pecas()


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


func _build_lighting() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("709aaa")
	sky_material.sky_horizon_color = Color("e8d9bc")
	sky_material.ground_bottom_color = Color("586957")
	sky_material.ground_horizon_color = Color("e8d9bc")
	sky_material.sun_angle_max = 12.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("cad9d5")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = false
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "GoldenHourSun"
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_color = Color("fff0d0")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	add_child(sun)


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


func _tripo_house(origin: Vector3) -> void:
	var house := TRIPO_HOUSE_SCENE.instantiate() as Node3D
	house.name = "CasaCarroQuebradoTripo"
	add_child(house)
	var bounds := _node_bounds(house)
	var uniform_scale := TRIPO_HOUSE_WIDTH / bounds.size.x
	house.scale = Vector3.ONE * uniform_scale
	house.position = origin + Vector3(
		-bounds.get_center().x * uniform_scale,
		-bounds.position.y * uniform_scale,
		-bounds.get_center().z * uniform_scale
	)
	var collision_size := bounds.size * uniform_scale
	var collision_center := origin + Vector3(0, collision_size.y * 0.5, 0)
	var shape := BoxShape3D.new()
	shape.size = collision_size
	_body(shape, collision_center, "CasaCarroQuebradoColisao")


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

func _build_farm() -> void:
	var origin: Vector3 = _region.get_feature_center("Fazenda", "area")
	for row in range(3):
		_box(Vector3(5.6, 0.1, 0.88), origin + Vector3(0, 0.055, row * 1.35), Color("826346"))
		for column in range(7):
			var crop := CylinderMesh.new()
			crop.top_radius = 0.02
			crop.bottom_radius = 0.24
			crop.height = 0.54 + row * 0.09
			crop.radial_segments = 5
			_mesh(crop, origin + Vector3(-2.3 + column * 0.75, 0.35, row * 1.35), Color("8fa85e"))
	_fence(origin + Vector3(-4, 0, 6), 6, 1.65)
	_fence(origin + Vector3(-4, 0, -3), 6, 1.65)
	_box(Vector3(0.85, 1.0, 0.85), origin + Vector3(5.2, 0.5, 2), WOOD, true)
	_box(Vector3(0.95, 0.11, 0.95), origin + Vector3(5.2, 1.0, 2), Color("b1966c"))


func _build_trees() -> void:
	# Posições anotadas em metros reais ao redor da Praça (a cena converte para unidades).
	# Espécies de docs/AMBIENTACAO.md §4; o pau-brasil continua sendo o modelo do Tripo.
	_pau_brasil(_u(Vector3(-82, 0, 5)))
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
	# Bananal atrás da casa de taipa, dendezeiros junto ao bar, cajueiros e mangueira na fazenda.
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


func _pau_brasil(origin: Vector3) -> void:
	var tree := PAU_BRASIL_SCENE.instantiate() as Node3D
	tree.name = "PauBrasilTripo"
	add_child(tree)
	var bounds := AABB()
	var has_bounds := false
	for node in tree.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		var part_bounds: AABB = (tree.global_transform.affine_inverse() * part.global_transform) * part.get_aabb()
		bounds = bounds.merge(part_bounds) if has_bounds else part_bounds
		has_bounds = true
	if has_bounds and bounds.size.y > 0.001:
		var factor := 5.6 / bounds.size.y
		tree.scale = Vector3.ONE * factor
		tree.position = origin - Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.38
	trunk_shape.height = 2.4
	_body(trunk_shape, origin + Vector3(0, 1.2, 0))


func _arvore(especie: String, origin: Vector3, size: float = 1.0, yaw: float = 0.0) -> void:
	var built: Dictionary = FloraReconcavo.especie(especie, size)
	var instance := MeshInstance3D.new()
	instance.name = especie.capitalize()
	instance.mesh = built.mesh
	instance.position = origin
	instance.rotation.y = yaw
	add_child(instance)
	var shape := CylinderShape3D.new()
	shape.radius = float(built.trunk_radius) + 0.08
	shape.height = float(built.trunk_height)
	_body(shape, origin + Vector3(0, float(built.trunk_height) * 0.5, 0))


func _peca(node: Node3D, origin: Vector3, yaw: float = 0.0) -> void:
	node.position = origin
	node.rotation.y = yaw
	add_child(node)


func _build_pecas() -> void:
	# Peças soltas do 2D (gerador_mundo.gd ADORNOS): poço e bancos na praça, cruzeiro na
	# igreja, varal, lenha e pote na casa de taipa, carroça na fazenda.
	_peca(FloraReconcavo.poco(), Vector3(4.2, 0, 5.4), 0.6)
	_peca(FloraReconcavo.banco_praca(), _u(Vector3(-4.6, 0, -0.1)))
	_peca(FloraReconcavo.banco_praca(), Vector3(3.2, 0, -7.0), PI)
	var taipa := _u(Vector3(-52, 0, -27))
	_peca(FloraReconcavo.varal(), taipa + Vector3(-4.9, 0, 1.4), 0.35)
	_peca(FloraReconcavo.pilha_lenha(), taipa + Vector3(3.6, 0, -0.4), 0.0)
	_peca(FloraReconcavo.pote_agua(), taipa + Vector3(2.4, 0, 2.9))
	var church: Vector3 = _region.get_feature_center("Igreja", "poi")
	_peca(FloraReconcavo.cruzeiro(), church + Vector3(0, 0, 11.5))
	var farm: Vector3 = _region.get_feature_center("Fazenda", "area")
	_peca(FloraReconcavo.carroca(), farm + Vector3(8.5, 0, -5.5), -0.6)
	var pier: Vector3 = _region.get_feature_center("Pier", "poi")
	_peca(FloraReconcavo.pote_agua(), pier + Vector3(1.4, 0.1, -6.5))


func _build_details() -> void:
	for i in range(28):
		var x: float = (-25.0 + float(i % 7) * 8.0) / _meters_per_unit
		var z: float = (-21.0 + floorf(float(i) / 7.0) * 14.0) / _meters_per_unit
		if absf(x) < 3.0 / _meters_per_unit:
			continue
		for j in range(3):
			_box(Vector3(0.05, 0.28, 0.05), Vector3(x + j * 0.21, 0.14, z + (j % 2) * 0.25), LEAVES)
			_box(Vector3(0.16, 0.10, 0.16), Vector3(x + j * 0.21, 0.30, z + (j % 2) * 0.25), Color("e4c782") if i % 2 == 0 else Color("ce9d99"))


func _build_landmark_details() -> void:
	var church: Vector3 = _region.get_feature_center("Igreja", "poi")
	_box(Vector3(8, 0.25, 13), church + Vector3(0, 0.125, 0), Color("958d79"), true)
	_box(Vector3(7.4, 5.2, 12), church + Vector3(0, 2.7, 0), Color("eee5cf"), true)
	var roof := PrismMesh.new()
	roof.size = Vector3(8.8, 2.6, 13.3)
	_mesh(roof, church + Vector3(0, 6.4, 0), Color("a55b3c"))
	_box(Vector3(2.3, 8.2, 2.3), church + Vector3(0, 4.2, 6.0), Color("e5dcc8"), true)
	_box(Vector3(0.22, 2.0, 0.22), church + Vector3(0, 9.2, 6.0), WOOD)
	_box(Vector3(1.4, 0.2, 0.22), church + Vector3(0, 9.45, 6.0), WOOD)
	_house(_region.get_feature_center("Bar", "poi") + Vector3(8, 0, 3), Color("c6a16d"), Color("8b523b"))
	_house(_region.get_feature_center("Restaurante", "poi") + Vector3(7, 0, 4), Color("cdbb92"), Color("97563f"))
	var pier: Vector3 = _region.get_feature_center("Pier", "poi")
	_box(Vector3(4.5, 0.2, 17), pier + Vector3(0, -0.1, 0), Color("85684b"), true)
	for offset in [-7.0, 0.0, 7.0]:
		for side in [-1.8, 1.8]:
			_box(Vector3(0.3, 1.5, 0.3), pier + Vector3(side, -0.75, offset), WOOD)
	var bridge: Vector3 = _region.get_feature_center("Ponte", "poi")
	_box(Vector3(11, 0.35, 6), bridge + Vector3(0, 0.22, 0), Color("987b57"), true)
	for side in [-2.8, 2.8]:
		_box(Vector3(11, 0.18, 0.15), bridge + Vector3(0, 0.95, side), WOOD)
	var lookout: Vector3 = _region.get_feature_center("Mirante", "poi")
	_box(Vector3(6, 0.24, 6), lookout + Vector3(0, 0.65, 0), Color("9c7a52"), true)
	for x in [-2.8, 2.8]:
		for z in [-2.8, 2.8]:
			_box(Vector3(0.22, 1.45, 0.22), lookout + Vector3(x, 0.73, z), WOOD)
	var cemetery: Vector3 = _region.get_feature_center("Cemitério", "poi")
	for index in range(12):
		var grave := cemetery + Vector3((index % 4) * 2.3 - 3.45, 0, floorf(index / 4.0) * 3.0 - 3.0)
		_box(Vector3(0.72, 0.15, 1.45), grave + Vector3(0, 0.08, 0), Color("a9a9a0"))
		_box(Vector3(0.12, 0.9, 0.12), grave + Vector3(0, 0.6, -0.55), WOOD)
		_box(Vector3(0.48, 0.12, 0.12), grave + Vector3(0, 0.72, -0.55), WOOD)
	var stones: Vector3 = _region.get_feature_center("Pedras", "poi")
	for index in range(13):
		var rock := SphereMesh.new()
		rock.radius = 0.8 + (index % 3) * 0.4
		rock.height = 0.8 + (index % 4) * 0.3
		rock.radial_segments = 7
		rock.rings = 4
		_mesh(rock, stones + Vector3((index % 5) * 2.8 - 5.6, 0.35, floorf(index / 5.0) * 2.9 - 2.9), Color("929c92"))


func _fence(origin: Vector3, count: int, spacing: float) -> void:
	for i in range(count):
		_box(Vector3(0.15, 1.12, 0.15), origin + Vector3(i * spacing, 0.56, 0), WOOD, true)
	var width: float = (count - 1) * spacing
	for height in [0.4, 0.87]:
		_box(Vector3(width, 0.12, 0.12), origin + Vector3(width * 0.5, height, 0), Color("987650"), true)


func _box(size: Vector3, position: Vector3, color: Color, solid: bool = false, material_override: Material = null) -> void:
	var box := BoxMesh.new()
	box.size = size
	_mesh(box, position, color, material_override)
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		_body(shape, position)


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


func _body(shape: Shape3D, position: Vector3, body_name: String = "") -> void:
	var body := StaticBody3D.new()
	if not body_name.is_empty():
		body.name = body_name
	body.position = position
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
