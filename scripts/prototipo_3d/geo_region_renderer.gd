extends Node3D
## Renders one geographic region from metric KML data and a separately curated scenario.
## Coordinates are local meters: X points east and Z points south.
## The region catalog defines how many meters one Godot unit represents (`scale_m_per_unit`);
## positions are divided by that factor while walkable widths keep a playable minimum.

const LAND_COLOR := Color("9bbf7c")
const FOREST_COLOR := Color("719968")
const VILLAGE_COLOR := Color("bbcb98")
const SEA_COLOR := Color("5e9fa9")
const BEACH_COLOR := Color("e6d2a1")
const ROAD_COLOR := Color("cfb78b")
const MAIN_ROAD_COLOR := Color("e5c994")
const ROAD_EDGE_COLOR := Color("8e795b")
const SHORE_ACCESS_COLOR := Color("a47d50")
const RIVER_COLOR := Color("76b5b6")
const TREE_COLLISION_RADIUS := 28.0
const TREE_COLLISION_POOL_SIZE := 24
const TREE_COLLISION_INTERVAL := 0.25

var landmarks: Array[Dictionary] = []
var areas: Array[Dictionary] = []
var _features: Array[Dictionary] = []
var _bounds := Rect2()
var _background_kind := "land"
var _land := PackedVector2Array()
var _forest := PackedVector2Array()
var _kml_forest := PackedVector2Array()
var _village := PackedVector2Array()
var _coast := PackedVector2Array()
var _roads: Array[Dictionary] = []
var _rivers: Array[Dictionary] = []
var _point_positions: Array[Vector2] = []
var _open_areas: Array[PackedVector2Array] = []
var _tree_trunks: Array[Dictionary] = []
var _tree_collision_pool: Array[Dictionary] = []
var _tree_collision_elapsed := 0.0
var _meters_per_unit := 1.0


func set_meters_per_unit(value: float) -> void:
	_meters_per_unit = maxf(value, 0.01)


func get_meters_per_unit() -> float:
	return _meters_per_unit


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
	var bounds_data: Dictionary = scenario.get("bounds_m", geographic.get("bounds_m", {}))
	_background_kind = String(scenario.get("background_kind", "land"))
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
	if _bounds.size.x <= 0.0 or _bounds.size.y <= 0.0 or _land.size() < 3:
		push_error("A região não contém limites e polígono de terra válidos.")
		return
	for feature_value in geographic.get("features", []):
		var feature: Dictionary = feature_value
		_features.append(feature)
		var points := _to_points(feature.get("coordinates_m", []))
		if feature.get("kind", "") == "area":
			var center := Vector2.ZERO
			for point in points:
				center += point
			if not points.is_empty():
				center /= float(points.size())
				areas.append({"id": String(feature.get("id", "")), "name": String(feature.get("name", "")), "position": Vector3(center.x, 0.05, center.y)})
			match String(feature.get("name", "")):
				"Mata": _kml_forest = points
				"Fazenda", "Praça": _open_areas.append(points)
		match String(feature.get("kind", "")):
			"poi":
				if not points.is_empty():
					var point := points[0]
					_point_positions.append(point)
					landmarks.append({
						"id": String(feature.get("id", "")),
						"name": String(feature.get("name", "")),
						"position": Vector3(point.x, 0.05, point.y),
					})
			"road":
				if points.size() >= 2:
					_roads.append({"name": String(feature.get("name", "")), "points": points, "width": _road_width(feature)})
			"river":
				if points.size() >= 2:
					_rivers.append({"name": String(feature.get("name", "")), "points": points, "width": _units(9.0, 4.0)})
	_build_background()
	_add_polygon("Terra", _land, 0.0, LAND_COLOR, true)
	_add_polygon("Cobertura florestal", _forest, 0.012, FOREST_COLOR)
	_add_polygon("Área ocupada", _village, 0.018, VILLAGE_COLOR)
	for feature in _features:
		if feature.get("kind", "") == "area":
			var color := LAND_COLOR
			match String(feature.get("name", "")):
				"Mata": color = Color("648a5c")
				"Fazenda": color = Color("86aa67")
				"Praça": color = Color("d9c39a")
			_add_polygon(String(feature.get("name", "Área")), _to_points(feature.get("coordinates_m", [])), 0.027, color)
	_add_ribbon("Orla de areia", _coast, _units(17.0, 6.0), 0.038, BEACH_COLOR)
	for river in _rivers:
		_add_ribbon("Rio", river.points, river.width, 0.046, RIVER_COLOR)
	for road in _roads:
		var color := MAIN_ROAD_COLOR if road.name == "Rua Principal" else ROAD_COLOR
		_add_ribbon("Borda " + road.name, road.points, road.width + 1.2, 0.052, ROAD_EDGE_COLOR)
		_add_ribbon(road.name, road.points, road.width, 0.058, color, true)
	_build_shore_access()
	_build_forest(scenario.get("vegetation", {}))


func get_map_bounds() -> Rect2:
	return _bounds


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
			return Vector3(inside.x, 0.12, inside.y)
	var center := _bounds.get_center()
	return Vector3(center.x, 0.12, center.y)


func _is_on_land(position: Vector3) -> bool:
	return _land.size() >= 3 and Geometry2D.is_point_in_polygon(Vector2(position.x, position.z), _land)


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
		return Vector3(center.x, 0.0, center.y)
	return Vector3.ZERO


func surface_at(world_position: Vector3) -> String:
	var point := Vector2(world_position.x, world_position.z)
	if _distance_to_line(point, _coast) < _units(13.0, 4.5):
		return "areia"
	for road in _roads:
		if _distance_to_line(point, road.points) < road.width * 0.5 + 1.0:
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
	_roads.clear()
	_rivers.clear()
	_point_positions.clear()
	_open_areas.clear()
	_tree_trunks.clear()
	_tree_collision_pool.clear()
	_tree_collision_elapsed = 0.0
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


func _material(color: Color, roughness: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _build_background() -> void:
	var mesh := BoxMesh.new()
	# O fundo ultrapassa a borda da região para a vista aérea não revelar um retângulo vazio.
	mesh.size = Vector3(_bounds.size.x + 8000.0, 0.3, _bounds.size.y + 8000.0)
	mesh.material = _material(SEA_COLOR, 0.36) if _background_kind == "sea" else _material(LAND_COLOR)
	var center := _bounds.get_center()
	var visual := MeshInstance3D.new()
	visual.name = "Mar" if _background_kind == "sea" else "Terreno distante"
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.position = Vector3(center.x, -0.27, center.y)
	add_child(visual)


func _add_polygon(label: String, points: PackedVector2Array, y: float, color: Color, with_collision: bool = false) -> void:
	if points.size() < 3:
		return
	var indices := Geometry2D.triangulate_polygon(points)
	if indices.is_empty():
		push_warning("Não foi possível triangular o polígono: " + label)
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(_material(color))
	for i in range(0, indices.size(), 3):
		var a := Vector3(points[indices[i]].x, y, points[indices[i]].y)
		var b := Vector3(points[indices[i + 1]].x, y, points[indices[i + 1]].y)
		var c := Vector3(points[indices[i + 2]].x, y, points[indices[i + 2]].y)
		_add_up_triangle(surface, a, b, c)
	var mesh := surface.commit()
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	add_child(visual)
	if with_collision:
		var body := StaticBody3D.new()
		body.name = "Colisão da terra"
		var collision := CollisionShape3D.new()
		var shape := mesh.create_trimesh_shape()
		shape.backface_collision = true
		collision.shape = shape
		body.add_child(collision)
		add_child(body)


func _add_up_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	if (b - a).cross(c - a).y < 0.0:
		var swapped := b
		b = c
		c = swapped
	for vertex in [a, b, c]:
		surface.set_normal(Vector3.UP)
		surface.set_uv(Vector2(vertex.x, vertex.z) / 10.0)
		surface.add_vertex(vertex)


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
		_add_ribbon("Acesso " + String(landmark.name), route, _units(4.5, 3.0), 0.058, SHORE_ACCESS_COLOR, true)


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


func _add_ribbon(label: String, points: PackedVector2Array, width: float, y: float, color: Color, with_collision: bool = false) -> void:
	if points.size() < 2:
		return
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in range(points.size()):
		var previous := (points[i] - points[maxi(i - 1, 0)]).normalized()
		var following := (points[mini(i + 1, points.size() - 1)] - points[i]).normalized()
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
		var offset := miter * minf(width * 0.5 / denominator, width)
		left.append(points[i] + offset)
		right.append(points[i] - offset)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(_material(color))
	for i in range(points.size() - 1):
		var a := Vector3(left[i].x, y, left[i].y)
		var b := Vector3(right[i].x, y, right[i].y)
		var c := Vector3(left[i + 1].x, y, left[i + 1].y)
		var d := Vector3(right[i + 1].x, y, right[i + 1].y)
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
		if _village.size() >= 3 and Geometry2D.is_point_in_polygon(point, _village):
			continue
		if _inside_open_area(point):
			continue
		if _distance_to_line(point, _coast) < coast_clearing:
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
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.27
	trunk.height = 1.0
	trunk.radial_segments = 6
	trunk.material = _material(Color("70553b"))
	var canopy := SphereMesh.new()
	canopy.radius = 1.0
	canopy.height = 2.0
	canopy.radial_segments = 7
	canopy.rings = 4
	canopy.material = _material(Color("4e7954"))
	var trunks := MultiMesh.new()
	trunks.transform_format = MultiMesh.TRANSFORM_3D
	trunks.mesh = trunk
	trunks.instance_count = positions.size()
	var canopies := MultiMesh.new()
	canopies.transform_format = MultiMesh.TRANSFORM_3D
	canopies.mesh = canopy
	canopies.instance_count = positions.size()
	for i in range(positions.size()):
		var height := rng.randf_range(5.0, 10.5)
		var radius := rng.randf_range(1.9, 3.9)
		var point := positions[i]
		_tree_trunks.append({"point": point, "height": height * 0.64})
		trunks.set_instance_transform(i, Transform3D(
			Basis().scaled(Vector3(1.0, height * 0.64, 1.0)),
			Vector3(point.x, height * 0.32, point.y)
		))
		canopies.set_instance_transform(i, Transform3D(
			Basis().scaled(Vector3(radius, height * 0.32, radius)),
			Vector3(point.x, height * 0.73, point.y)
		))
	var trunk_visual := MultiMeshInstance3D.new()
	trunk_visual.name = "Troncos da mata"
	trunk_visual.multimesh = trunks
	trunk_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trunk_visual)
	var canopy_visual := MultiMeshInstance3D.new()
	canopy_visual.name = "Copas da mata"
	canopy_visual.multimesh = canopies
	canopy_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(canopy_visual)


func _process(delta: float) -> void:
	if _tree_trunks.is_empty():
		return
	_tree_collision_elapsed += delta
	if _tree_collision_elapsed < TREE_COLLISION_INTERVAL:
		return
	_tree_collision_elapsed = 0.0
	_refresh_tree_collisions()


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
		var distance_squared: float = player_point.distance_squared_to(trunk.point)
		if distance_squared <= TREE_COLLISION_RADIUS * TREE_COLLISION_RADIUS:
			nearby.append({"point": trunk.point, "height": trunk.height, "distance_squared": distance_squared})
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
		body.position = Vector3(tree.point.x, tree.height * 0.5, tree.point.y)
		if not slot.active:
			collider.set_deferred("disabled", false)
			slot.active = true


func _collision_nearer(a: Dictionary, b: Dictionary) -> bool:
	return float(a.distance_squared) < float(b.distance_squared)


func _ensure_tree_collision_pool() -> void:
	if not _tree_collision_pool.is_empty():
		return
	for i in range(TREE_COLLISION_POOL_SIZE):
		var body := StaticBody3D.new()
		body.name = "Colisão de tronco %02d" % (i + 1)
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
	for road in _roads:
		if _distance_to_line(point, road.points) < clearing + road.width * 0.5:
			return true
	for river in _rivers:
		if _distance_to_line(point, river.points) < clearing + river.width * 0.5:
			return true
	return false


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
