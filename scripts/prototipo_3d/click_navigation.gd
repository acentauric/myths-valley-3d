extends RefCounted
## Grade de caminhos para o terreno gerado em tempo de execução.

const CELL_SIZE := 2.5
const OBSTACLE_CLEARANCE := 0.55
const MAX_SNAP_CELLS := 8
## A CASA É UM BLOCO PARA QUEM ANDA POR FORA DELA. As paredes, as portas e os móveis moram nos
## interiores (`Interiores/Interior_*`), e o `AlvoCasaN` é uma `Area3D`: nada disso é filho direto do
## mundo, e a grade tinha a casa inteira por chão livre. A célula "mais perto" de um destino colado
## numa casa (o tronco do quintal da casa de taipa) caía DENTRO dela, junto da porta trancada, e o
## corpo ia bater na parede: "Caminho bloqueado", e quem clica não chega ao tronco. A pegada de cada
## casa (`house_bounds`, a caixa que o `world_builder` registra no grupo `interactive_house`) entra
## na grade como obstáculo — menos para a casa em que o trajeto COMEÇA ou ACABA: quem está dentro dela
## (a pegada, mais `HOUSE_INSIDE_MARGIN`) e quem clica na casa, que vai ao ponto da porta
## (`world_builder.get_house_destination`: a `HOUSE_DOOR_MARGIN` da pegada, no meio de um lado).
## Um destino só PERTO da casa — o pé de cana a 1,3 u da parede — não a solta: cortaria a sala.
const HOUSE_GROUP := "interactive_house"
const HOUSE_INSIDE_MARGIN := 0.5
## O `margin` do `get_house_destination`: se mudar lá, muda aqui.
const HOUSE_DOOR_MARGIN := 1.2
const HOUSE_DOOR_SLACK := 0.3

var _world: Node3D
var _grid := AStarGrid2D.new()
var _origin := Vector2.ZERO
var _size := Vector2i.ZERO
var _terrain_walkable := PackedByteArray()
var _obstacle_cells: Array[Vector2i] = []
var _built := false


func configure(world: Node3D) -> void:
	_world = world
	_built = false
	_obstacle_cells.clear()
	_terrain_walkable.clear()


func find_path(start: Vector3, destination: Vector3) -> PackedVector3Array:
	if _world == null or not destination.is_finite() or not _world.is_walkable_point(destination):
		return PackedVector3Array()
	if not _built:
		_build_grid()
	_refresh_obstacles(start, destination)
	var first := _nearest_open(_cell_at(start))
	var last := _nearest_open(_cell_at(destination))
	if not _inside(first) or not _inside(last):
		return PackedVector3Array()
	var ids: Array[Vector2i] = _grid.get_id_path(first, last)
	if ids.is_empty():
		return PackedVector3Array()
	var result := PackedVector3Array()
	for i in range(1, ids.size() - 1):
		if ids[i] - ids[i - 1] != ids[i + 1] - ids[i]:
			result.append(_cell_center(ids[i]))
	result.append(_cell_center(last))
	if last == _cell_at(destination):
		result.append(_world.ground_position(destination, 0.08))
	return result


func _build_grid() -> void:
	var bounds: Rect2 = _world.get_map_bounds()
	_origin = bounds.position - Vector2.ONE * CELL_SIZE * 2.0
	_size = Vector2i(ceili(bounds.size.x / CELL_SIZE) + 4, ceili(bounds.size.y / CELL_SIZE) + 4)
	_grid.region = Rect2i(Vector2i.ZERO, _size)
	_grid.cell_size = Vector2.ONE
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	_terrain_walkable.resize(_size.x * _size.y)
	for z in range(_size.y):
		for x in range(_size.x):
			var cell := Vector2i(x, z)
			var flat_center := Vector3(_origin.x + (x + 0.5) * CELL_SIZE, 0.0, _origin.y + (z + 0.5) * CELL_SIZE)
			var open: bool = _world.is_walkable_point(flat_center)
			_terrain_walkable[_index(cell)] = 1 if open else 0
			if not open:
				_grid.set_point_solid(cell)
	_built = true


func _refresh_obstacles(start: Vector3 = Vector3.INF, destination: Vector3 = Vector3.INF) -> void:
	for cell in _obstacle_cells:
		_grid.set_point_solid(cell, false)
	_obstacle_cells.clear()
	_mark_obstacles_in(_world)
	for child in _world.get_children():
		if child.has_method("is_walkable_point"):
			_mark_obstacles_in(child)
	_mark_houses(start, destination)


## As casas fora do caminho entram na grade pela pegada inteira (ver `HOUSE_GROUP`).
func _mark_houses(start: Vector3, destination: Vector3) -> void:
	if not _world.is_inside_tree():
		return
	for node in _world.get_tree().get_nodes_in_group(HOUSE_GROUP):
		if node is not Node3D or not node.has_meta("house_bounds"):
			continue
		var house := node as Node3D
		var bounds: Vector3 = house.get_meta("house_bounds")
		var half_x := bounds.x * 0.5
		var half_z := bounds.z * 0.5
		if _inside_house(house, half_x, half_z, start) or _inside_house(house, half_x, half_z, destination) \
				or _is_house_door_point(house, half_x, half_z, destination):
			continue
		var basis := house.global_transform.basis
		var extent_x := absf(basis.x.x) * half_x + absf(basis.z.x) * half_z
		var extent_z := absf(basis.x.z) * half_x + absf(basis.z.z) * half_z
		_mark_rectangle(house.global_position, extent_x, extent_z)


func _inside_house(house: Node3D, half_x: float, half_z: float, point: Vector3) -> bool:
	if not point.is_finite():
		return false
	var local := house.to_local(point)
	return absf(local.x) <= half_x + HOUSE_INSIDE_MARGIN and absf(local.z) <= half_z + HOUSE_INSIDE_MARGIN


## O ponto que o clique numa casa escolhe: no meio de um dos quatro lados, a `HOUSE_DOOR_MARGIN` da pegada.
func _is_house_door_point(house: Node3D, half_x: float, half_z: float, point: Vector3) -> bool:
	if not point.is_finite():
		return false
	var local := house.to_local(point)
	var on_z_side := absf(local.x) < HOUSE_DOOR_SLACK and absf(absf(local.z) - (half_z + HOUSE_DOOR_MARGIN)) < HOUSE_DOOR_SLACK
	var on_x_side := absf(local.z) < HOUSE_DOOR_SLACK and absf(absf(local.x) - (half_x + HOUSE_DOOR_MARGIN)) < HOUSE_DOOR_SLACK
	return on_z_side or on_x_side


func _mark_obstacles_in(parent: Node) -> void:
	for child in parent.get_children():
		if child is not StaticBody3D:
			continue
		for candidate in child.get_children():
			if candidate is not CollisionShape3D:
				continue
			var collider := candidate as CollisionShape3D
			if collider.disabled or collider.shape == null:
				continue
			var center := collider.global_position
			if collider.shape is BoxShape3D:
				var half := (collider.shape as BoxShape3D).size * 0.5
				if half.y < 0.25 or center.y - half.y > _world.ground_height_at(center) + 1.7:
					continue
				var basis := collider.global_transform.basis
				var extent_x := absf(basis.x.x) * half.x + absf(basis.y.x) * half.y + absf(basis.z.x) * half.z
				var extent_z := absf(basis.x.z) * half.x + absf(basis.y.z) * half.y + absf(basis.z.z) * half.z
				_mark_rectangle(center, extent_x, extent_z)
			elif collider.shape is CylinderShape3D:
				var cylinder := collider.shape as CylinderShape3D
				if center.y - cylinder.height * 0.5 > _world.ground_height_at(center) + 1.7:
					continue
				_mark_rectangle(center, cylinder.radius, cylinder.radius)


func _mark_rectangle(center: Vector3, half_x: float, half_z: float) -> void:
	var padding := OBSTACLE_CLEARANCE
	var corner_a := _cell_at(center - Vector3(half_x + padding, 0, half_z + padding))
	var corner_b := _cell_at(center + Vector3(half_x + padding, 0, half_z + padding))
	for z in range(maxi(0, corner_a.y), mini(_size.y - 1, corner_b.y) + 1):
		for x in range(maxi(0, corner_a.x), mini(_size.x - 1, corner_b.x) + 1):
			var cell := Vector2i(x, z)
			if _terrain_walkable[_index(cell)] == 1 and not _grid.is_point_solid(cell):
				_grid.set_point_solid(cell)
				_obstacle_cells.append(cell)


func _nearest_open(cell: Vector2i) -> Vector2i:
	if _inside(cell) and not _grid.is_point_solid(cell):
		return cell
	for radius in range(1, MAX_SNAP_CELLS + 1):
		var best := Vector2i(-1, -1)
		var best_distance := INF
		for z in range(cell.y - radius, cell.y + radius + 1):
			for x in range(cell.x - radius, cell.x + radius + 1):
				if absi(x - cell.x) != radius and absi(z - cell.y) != radius:
					continue
				var candidate := Vector2i(x, z)
				if not _inside(candidate) or _grid.is_point_solid(candidate):
					continue
				var distance := candidate.distance_squared_to(cell)
				if distance < best_distance:
					best_distance = distance
					best = candidate
		if _inside(best):
			return best
	return Vector2i(-1, -1)


func _cell_at(point: Vector3) -> Vector2i:
	return Vector2i(floori((point.x - _origin.x) / CELL_SIZE), floori((point.z - _origin.y) / CELL_SIZE))


func _cell_center(cell: Vector2i) -> Vector3:
	return _world.ground_position(Vector3(_origin.x + (cell.x + 0.5) * CELL_SIZE, 0.0, _origin.y + (cell.y + 0.5) * CELL_SIZE), 0.08)


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _size.x and cell.y < _size.y


func _index(cell: Vector2i) -> int:
	return cell.y * _size.x + cell.x
