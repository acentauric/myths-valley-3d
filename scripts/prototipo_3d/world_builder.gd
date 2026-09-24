extends Node3D
## A hand-placed coastal hamlet for validating the character in a playable space.

const GRASS := Color("789b63")
const PATH := Color("c5ad7a")
const WOOD := Color("735139")
const LEAVES := Color("487557")
const TRIPO_HOUSE_SCENE := preload("res://assets/prototipo_3d/casas/casa_carro_quebrado_tripo.glb")
const TRIPO_HOUSE_WIDTH := 5.2
const PAU_BRASIL_SCENE := preload("res://assets/prototipo_3d/arvores/pau_brasil_tripo.glb")
const CASA_TAIPA_CAL_TEXTURE := preload("res://assets/prototipo_3d/materiais/cal_taipa_envelhecida_v1.png")
const TELHA_COLONIAL_TEXTURE := preload("res://assets/prototipo_3d/materiais/telha_colonial_envelhecida_v1.png")
var _materials: Dictionary = {}
var landmarks: Array[Dictionary] = [
	{"name": "Praça da vila", "position": Vector3(0, 0, -3)},
	{"name": "Horta", "position": Vector3(10, 0, 7)},
	{"name": "Costa", "position": Vector3(-19, 0, 5)},
]


func get_spawn_position() -> Vector3:
	return Vector3(0, 0.05, 6)


func _ready() -> void:
	_build_lighting()
	_build_ground()
	_build_paths()
	_casa_de_taipa_referencia(Vector3(-10, 0, -6))
	_tripo_house(Vector3(10, 0, -8))
	_house(Vector3(1, 0, -16), Color("dfb980"), Color("ae6950"))
	_build_farm()
	_build_trees()
	_build_details()
	_build_boundary()


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
	environment.fog_enabled = true
	environment.fog_light_color = Color("c4d3c4")
	environment.fog_density = 0.002
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "GoldenHourSun"
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_color = Color("fff0d0")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)


func _build_ground() -> void:
	_box(Vector3(46, 1, 44), Vector3(0, -0.5, 0), GRASS, true)
	_box(Vector3(5, 0.035, 44), Vector3(-20.5, 0.018, 0), Color("d9c596"))
	_box(Vector3(75, 0.2, 130), Vector3(-60.5, -0.34, -10), Color("669ba3"))
	for i in range(7):
		_box(Vector3(0.10, 0.012, 6.0), Vector3(-23.8 - i * 1.7, -0.225, -16 + i * 5), Color("bbd5ce"))
	for position: Vector3 in [Vector3(-10, -4, -42), Vector3(15, -5, -48), Vector3(36, -5, -36)]:
		var hill := SphereMesh.new()
		hill.radius = 17.0
		hill.height = 21.0
		hill.radial_segments = 12
		hill.rings = 6
		_mesh(hill, position, Color("658571"))


func _build_paths() -> void:
	# Broad center lane and short branches leave the full starting view unobstructed.
	_box(Vector3(3.4, 0.035, 30), Vector3(0, 0.024, -2), PATH)
	_box(Vector3(21, 0.035, 2.6), Vector3(0, 0.026, -3), PATH)
	_box(Vector3(10, 0.035, 2.2), Vector3(5, 0.026, 7), PATH)
	_box(Vector3(19, 0.035, 2.2), Vector3(-9, 0.025, 11), PATH)
	var plaza := CylinderMesh.new()
	plaza.top_radius = 4.0
	plaza.bottom_radius = 4.0
	plaza.height = 0.045
	plaza.radial_segments = 20
	_mesh(plaza, Vector3(0, 0.03, -3), PATH)


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
	for row in range(3):
		_box(Vector3(5.6, 0.1, 0.88), Vector3(10.5, 0.055, 4.8 + row * 1.35), Color("826346"))
		for column in range(7):
			var crop := CylinderMesh.new()
			crop.top_radius = 0.02
			crop.bottom_radius = 0.24
			crop.height = 0.54 + row * 0.09
			crop.radial_segments = 5
			_mesh(crop, Vector3(8.2 + column * 0.75, 0.35, 4.8 + row * 1.35), Color("8fa85e"))
	_fence(Vector3(7, 0, 9), 5, 1.65)
	_fence(Vector3(7, 0, 3), 5, 1.65)
	_box(Vector3(0.85, 1.0, 0.85), Vector3(15.2, 0.5, 7), WOOD, true)
	_box(Vector3(0.95, 0.11, 0.95), Vector3(15.2, 1.0, 7), Color("b1966c"))


func _build_trees() -> void:
	var positions: Array[Vector3] = [Vector3(-15, 0, -11), Vector3(-16, 0, -4), Vector3(-12, 0, 3), Vector3(-17, 0, 7), Vector3(-9, 0, 15), Vector3(9, 0, 15), Vector3(17, 0, 12), Vector3(18, 0, 2), Vector3(17, 0, -12), Vector3(10, 0, -18), Vector3(-7, 0, -18)]
	for i in range(positions.size()):
		if i == 2:
			_pau_brasil(positions[i])
		else:
			_tree(positions[i], 0.82 + (i % 4) * 0.13)


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


func _tree(origin: Vector3, size: float) -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.17 * size
	trunk.bottom_radius = 0.31 * size
	trunk.height = 2.7 * size
	trunk.radial_segments = 7
	_mesh(trunk, origin + Vector3(0, 1.35 * size, 0), WOOD)
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.35 * size
	trunk_shape.height = 2.7 * size
	_body(trunk_shape, origin + Vector3(0, 1.35 * size, 0))
	for layer in range(2):
		var foliage := SphereMesh.new()
		foliage.radius = (1.75 - layer * 0.36) * size
		foliage.height = (3.0 - layer * 0.55) * size
		foliage.radial_segments = 9
		foliage.rings = 5
		_mesh(foliage, origin + Vector3(layer * 0.36, (3.15 + layer * 1.15) * size, 0), LEAVES.lightened(layer * 0.08))


func _build_details() -> void:
	_fence(Vector3(-15, 0, 16), 5, 1.8)
	_fence(Vector3(5, 0, 18), 7, 1.8)
	for i in range(9):
		var rock := SphereMesh.new()
		rock.radius = 0.4 + (i % 3) * 0.15
		rock.height = 0.55 + (i % 2) * 0.28
		rock.radial_segments = 6
		rock.rings = 3
		_mesh(rock, Vector3(-19 + (i % 3) * 0.45, 0.2, -17 + i * 4), Color("a4a99a"))
	for i in range(28):
		var x: float = -15.0 + float(i % 7) * 5.0
		var z: float = -19.0 + floorf(float(i) / 7.0) * 11.0
		if absf(x) < 3.0:
			continue
		for j in range(3):
			_box(Vector3(0.05, 0.28, 0.05), Vector3(x + j * 0.21, 0.14, z + (j % 2) * 0.25), LEAVES)
			_box(Vector3(0.16, 0.10, 0.16), Vector3(x + j * 0.21, 0.30, z + (j % 2) * 0.25), Color("e4c782") if i % 2 == 0 else Color("ce9d99"))
	# A bench near the square gives the village a readable human scale.
	_box(Vector3(2.3, 0.14, 0.65), Vector3(-4.6, 0.62, -0.1), WOOD, true)
	_box(Vector3(2.3, 0.52, 0.12), Vector3(-4.6, 1.04, -0.42), WOOD)
	for x in [-5.45, -3.75]:
		_box(Vector3(0.16, 0.6, 0.5), Vector3(x, 0.3, -0.1), Color("544b40"))


func _fence(origin: Vector3, count: int, spacing: float) -> void:
	for i in range(count):
		_box(Vector3(0.15, 1.12, 0.15), origin + Vector3(i * spacing, 0.56, 0), WOOD, true)
	var width: float = (count - 1) * spacing
	for height in [0.4, 0.87]:
		_box(Vector3(width, 0.12, 0.12), origin + Vector3(width * 0.5, height, 0), Color("987650"), true)


func _build_boundary() -> void:
	for position: Vector3 in [Vector3(-22.7, 2, 0), Vector3(22.7, 2, 0)]:
		var side := BoxShape3D.new()
		side.size = Vector3(0.4, 5, 44)
		_body(side, position)
	for position: Vector3 in [Vector3(0, 2, -21.7), Vector3(0, 2, 21.7)]:
		var edge := BoxShape3D.new()
		edge.size = Vector3(46, 5, 0.4)
		_body(edge, position)


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
