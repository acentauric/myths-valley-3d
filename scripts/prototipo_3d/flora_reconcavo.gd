class_name FloraReconcavo
extends RefCounted
## Flora procedural do Recôncavo (docs/mundo/AMBIENTACAO.md, §4) e peças soltas do arraial.
## Cada espécie vira um ArrayMesh de poucas superfícies, com uma silhueta própria,
## pronto para MeshInstance3D ou MultiMesh. Modelos do Tripo podem substituir uma
## espécie por vez sem mudar quem chama: basta trocar o retorno de `especie()`.
##
## Unidades são as da cena (escala humana: o personagem tem 1,78). As alturas
## não acompanham a escala horizontal do mapa, para a mata continuar alta.

const TRONCO := Color("6a4a32")
const TRONCO_ESCURO := Color("4f3624")
const TRONCO_PALMEIRA := Color("8a7a5c")
const TRONCO_EMBAUBA := Color("c9c4b4")
const COPA_MANGUEIRA := Color("2f5a34")
const COPA_JAQUEIRA := Color("3d6b3a")
const COPA_CAJUEIRO := Color("6e9a4f")
const COPA_MATA := Color("3a6a3c")
const COPA_MATA_CLARA := Color("4f7f45")
const FRONDE := Color("4c8a3f")
const FRONDE_DENDE := Color("3f7236")
const FOLHA_BANANEIRA := Color("6fae4a")
const IPE_AMARELO := Color("f0c12e")
const IPE_ROXO := Color("b46cc0")
const FOLHA_EMBAUBA := Color("8fa67f")
const JACA := Color("a9b04a")
const MADEIRA := Color("735139")
const MADEIRA_VELHA := Color("4b3327")
const PEDRA := Color("8f8f86")
const CAL := Color("f2ead8")
const BARRO := Color("a9815d")
const TECIDO := Color("e8dcc4")
const TECIDO_AZUL := Color("8ea3b8")

const ESPECIES_MATA := ["mata_alta", "jaqueira", "dendezeiro", "mata_alta", "embauba"]

static var _materials: Dictionary = {}


static func material(color: Color, roughness: float = 0.95) -> StandardMaterial3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		_materials[color] = material
	return _materials[color]


## Devolve {"mesh": ArrayMesh, "trunk_radius": float, "trunk_height": float} para o nome pedido.
static func especie(nome: String, size: float = 1.0, rng: RandomNumberGenerator = null) -> Dictionary:
	match nome:
		"mangueira": return mangueira(size)
		"jaqueira": return jaqueira(size)
		"cajueiro": return cajueiro(size)
		"dendezeiro": return palmeira(size, true)
		"coqueiro": return palmeira(size, false)
		"bananeira": return bananeira(size)
		"ipe_amarelo": return ipe(size, IPE_AMARELO)
		"ipe_roxo": return ipe(size, IPE_ROXO)
		"embauba": return embauba(size)
		"mata_alta": return mata_alta(size, rng)
	return mata_alta(size, rng)


static func _group(mesh: ArrayMesh, parts: Array, color: Color) -> void:
	# parts: [[PrimitiveMesh, Transform3D], ...] com a mesma cor viram uma superfície só.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		surface.append_from(part[0], 0, part[1])
	surface.set_material(material(color))
	surface.commit(mesh)


static func _at(position: Vector3, yaw: float = 0.0, tilt: Vector3 = Vector3.ZERO) -> Transform3D:
	var basis := Basis.from_euler(Vector3(tilt.x, yaw, tilt.z))
	return Transform3D(basis, position)


static func _cylinder(top: float, bottom: float, height: float, segments: int = 7) -> CylinderMesh:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top
	cylinder.bottom_radius = bottom
	cylinder.height = height
	cylinder.radial_segments = segments
	cylinder.rings = 1
	return cylinder


static func _blob(radius: float, height: float, segments: int = 8, rings: int = 5) -> SphereMesh:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = height
	sphere.radial_segments = segments
	sphere.rings = rings
	return sphere


static func _slab(size: Vector3) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	return box


static func _result(mesh: ArrayMesh, trunk_radius: float, trunk_height: float) -> Dictionary:
	return {"mesh": mesh, "trunk_radius": trunk_radius, "trunk_height": trunk_height}


## Mangueira: a rainha do terreiro. Tronco curto e grosso, copa larguíssima e escura.
static func mangueira(size: float) -> Dictionary:
	var mesh := ArrayMesh.new()
	var trunk_height := 1.6 * size
	_group(mesh, [
		[_cylinder(0.34 * size, 0.5 * size, trunk_height, 8), _at(Vector3(0, trunk_height * 0.5, 0))],
		[_cylinder(0.12 * size, 0.22 * size, 2.2 * size, 5), _at(Vector3(0.9 * size, trunk_height + 0.6 * size, 0.3 * size), 0.0, Vector3(0.0, 0, -0.9))],
		[_cylinder(0.12 * size, 0.22 * size, 2.2 * size, 5), _at(Vector3(-0.8 * size, trunk_height + 0.7 * size, -0.4 * size), 0.0, Vector3(0.3, 0, 0.9))],
	], TRONCO_ESCURO)
	_group(mesh, [
		[_blob(3.4 * size, 3.6 * size, 10, 6), _at(Vector3(0, trunk_height + 2.4 * size, 0))],
		[_blob(2.6 * size, 2.8 * size, 9, 5), _at(Vector3(1.9 * size, trunk_height + 1.9 * size, 0.8 * size))],
		[_blob(2.5 * size, 2.6 * size, 9, 5), _at(Vector3(-1.8 * size, trunk_height + 2.0 * size, -0.9 * size))],
		[_blob(2.2 * size, 2.3 * size, 8, 5), _at(Vector3(0.4 * size, trunk_height + 2.1 * size, -2.1 * size))],
	], COPA_MANGUEIRA)
	return _result(mesh, 0.5 * size, trunk_height)


## Jaqueira: tronco reto e alto, copa densa arredondada, jacas penduradas no tronco.
static func jaqueira(size: float) -> Dictionary:
	var mesh := ArrayMesh.new()
	var trunk_height := 3.4 * size
	_group(mesh, [
		[_cylinder(0.24 * size, 0.36 * size, trunk_height, 8), _at(Vector3(0, trunk_height * 0.5, 0))],
	], TRONCO)
	_group(mesh, [
		[_blob(2.6 * size, 4.2 * size, 10, 6), _at(Vector3(0, trunk_height + 1.6 * size, 0))],
		[_blob(1.9 * size, 2.6 * size, 8, 5), _at(Vector3(1.3 * size, trunk_height + 2.6 * size, 0.6 * size))],
		[_blob(1.8 * size, 2.4 * size, 8, 5), _at(Vector3(-1.2 * size, trunk_height + 0.9 * size, -0.8 * size))],
	], COPA_JAQUEIRA)
	_group(mesh, [
		[_blob(0.26 * size, 0.62 * size, 6, 4), _at(Vector3(0.36 * size, 1.5 * size, 0.1 * size))],
		[_blob(0.22 * size, 0.5 * size, 6, 4), _at(Vector3(-0.3 * size, 2.3 * size, 0.24 * size))],
		[_blob(0.24 * size, 0.56 * size, 6, 4), _at(Vector3(0.05 * size, 1.05 * size, -0.36 * size))],
	], JACA)
	return _result(mesh, 0.36 * size, trunk_height)


## Cajueiro: tronco baixo e torto, copa espalhada e clara.
static func cajueiro(size: float) -> Dictionary:
	var mesh := ArrayMesh.new()
	var trunk_height := 1.4 * size
	_group(mesh, [
		[_cylinder(0.2 * size, 0.3 * size, trunk_height, 7), _at(Vector3(0, trunk_height * 0.5, 0), 0.0, Vector3(0.0, 0, 0.35))],
		[_cylinder(0.1 * size, 0.18 * size, 2.4 * size, 5), _at(Vector3(-0.5 * size, trunk_height + 0.8 * size, 0), 0.0, Vector3(0.0, 0, 1.05))],
		[_cylinder(0.1 * size, 0.18 * size, 2.0 * size, 5), _at(Vector3(0.6 * size, trunk_height + 0.7 * size, 0.5 * size), 0.0, Vector3(-0.5, 0, -0.75))],
	], TRONCO)
	_group(mesh, [
		[_blob(2.3 * size, 1.9 * size, 9, 5), _at(Vector3(-1.4 * size, trunk_height + 1.7 * size, 0.2 * size))],
		[_blob(2.0 * size, 1.7 * size, 9, 5), _at(Vector3(1.3 * size, trunk_height + 1.5 * size, 0.9 * size))],
		[_blob(1.7 * size, 1.5 * size, 8, 5), _at(Vector3(0.2 * size, trunk_height + 2.2 * size, -1.2 * size))],
	], COPA_CAJUEIRO)
	return _result(mesh, 0.3 * size, trunk_height)


## Dendezeiro (tronco grosso, frondes densas) ou coqueiro (tronco fino e alto, inclinado).
static func palmeira(size: float, dende: bool) -> Dictionary:
	var mesh := ArrayMesh.new()
	var trunk_height := (5.2 if dende else 7.6) * size
	var trunk_radius := (0.32 if dende else 0.17) * size
	var lean := 0.0 if dende else 0.16
	_group(mesh, [
		[_cylinder(trunk_radius * 0.8, trunk_radius, trunk_height, 7), _at(Vector3(0, trunk_height * 0.5, 0), 0.0, Vector3(0, 0, lean))],
	], TRONCO_PALMEIRA)
	var crown := Vector3(0, trunk_height, 0)
	if not dende:
		# O tronco inclina no eixo Z; a coroa acompanha o topo deslocado.
		crown = Vector3(-sin(lean) * trunk_height, cos(lean) * trunk_height, 0)
	var fronds: Array = []
	var count := 9 if dende else 7
	for i in range(count):
		var yaw := TAU * float(i) / float(count)
		var droop := (0.55 if dende else 0.42) + 0.08 * float(i % 2)
		var length := (2.6 if dende else 3.0) * size
		var frond := _slab(Vector3(length, 0.1 * size, (0.7 if dende else 0.55) * size))
		var offset := Vector3(cos(yaw) * length * 0.45, 0.25 * size, sin(yaw) * length * 0.45)
		fronds.append([frond, _at(crown + offset, -yaw, Vector3(0, 0, -droop))])
	fronds.append([_blob(0.7 * size, 0.9 * size, 7, 4), _at(crown + Vector3(0, 0.2 * size, 0))])
	_group(mesh, fronds, FRONDE_DENDE if dende else FRONDE)
	if not dende:
		_group(mesh, [
			[_blob(0.22 * size, 0.3 * size, 6, 4), _at(crown + Vector3(0.3 * size, -0.25 * size, 0.2 * size))],
			[_blob(0.22 * size, 0.3 * size, 6, 4), _at(crown + Vector3(-0.25 * size, -0.3 * size, -0.25 * size))],
		], Color("b39a5a"))
	return _result(mesh, trunk_radius, trunk_height)


## Bananeira: touceira de folhas largas e arqueadas, sem tronco lenhoso.
static func bananeira(size: float) -> Dictionary:
	var mesh := ArrayMesh.new()
	var stem_height := 2.1 * size
	_group(mesh, [
		[_cylinder(0.12 * size, 0.2 * size, stem_height, 6), _at(Vector3(0, stem_height * 0.5, 0))],
		[_cylinder(0.09 * size, 0.15 * size, 1.5 * size, 6), _at(Vector3(0.45 * size, 0.75 * size, 0.3 * size), 0.0, Vector3(0, 0, -0.2))],
	], Color("8fb56a"))
	var leaves: Array = []
	for i in range(6):
		var yaw := TAU * float(i) / 6.0 + 0.3
		var leaf := _slab(Vector3(2.0 * size, 0.06 * size, 0.62 * size))
		var offset := Vector3(cos(yaw) * 0.9 * size, stem_height + 0.1 * size, sin(yaw) * 0.9 * size)
		leaves.append([leaf, _at(offset, -yaw, Vector3(0, 0, -0.65 - 0.1 * float(i % 3)))])
	_group(mesh, leaves, FOLHA_BANANEIRA)
	return _result(mesh, 0.2 * size, stem_height)


## Ipê na florada: tronco médio, copa de cachos amarelos ou roxos, quase sem folha.
static func ipe(size: float, flower: Color) -> Dictionary:
	var mesh := ArrayMesh.new()
	var trunk_height := 3.0 * size
	_group(mesh, [
		[_cylinder(0.16 * size, 0.26 * size, trunk_height, 7), _at(Vector3(0, trunk_height * 0.5, 0))],
		[_cylinder(0.08 * size, 0.14 * size, 1.8 * size, 5), _at(Vector3(0.6 * size, trunk_height + 0.6 * size, 0.2 * size), 0.0, Vector3(0, 0, -0.7))],
		[_cylinder(0.08 * size, 0.14 * size, 1.8 * size, 5), _at(Vector3(-0.55 * size, trunk_height + 0.7 * size, -0.3 * size), 0.0, Vector3(0.2, 0, 0.7))],
	], TRONCO)
	_group(mesh, [
		[_blob(1.5 * size, 1.6 * size, 8, 5), _at(Vector3(0, trunk_height + 1.9 * size, 0))],
		[_blob(1.2 * size, 1.3 * size, 7, 4), _at(Vector3(1.3 * size, trunk_height + 1.5 * size, 0.5 * size))],
		[_blob(1.15 * size, 1.25 * size, 7, 4), _at(Vector3(-1.2 * size, trunk_height + 1.6 * size, -0.6 * size))],
		[_blob(1.0 * size, 1.1 * size, 7, 4), _at(Vector3(0.2 * size, trunk_height + 1.2 * size, -1.3 * size))],
	], flower)
	return _result(mesh, 0.26 * size, trunk_height)


## Embaúba: tronco fino e claro, guarda-chuva de poucas folhas grandes no topo.
static func embauba(size: float) -> Dictionary:
	var mesh := ArrayMesh.new()
	var trunk_height := 6.0 * size
	_group(mesh, [
		[_cylinder(0.11 * size, 0.18 * size, trunk_height, 6), _at(Vector3(0, trunk_height * 0.5, 0), 0.0, Vector3(0, 0, 0.05))],
	], TRONCO_EMBAUBA)
	var leaves: Array = []
	for i in range(5):
		var yaw := TAU * float(i) / 5.0
		var leaf := _blob(0.75 * size, 0.28 * size, 7, 3)
		var offset := Vector3(cos(yaw) * 0.85 * size, trunk_height + 0.15 * size, sin(yaw) * 0.85 * size)
		leaves.append([leaf, _at(offset, -yaw, Vector3(0, 0, -0.2))])
	_group(mesh, leaves, FOLHA_EMBAUBA)
	return _result(mesh, 0.18 * size, trunk_height)


## Árvore genérica da mata fechada e alta: tronco alto, copa em camadas escuras.
static func mata_alta(size: float, rng: RandomNumberGenerator = null) -> Dictionary:
	var mesh := ArrayMesh.new()
	var trunk_height := 4.6 * size
	var tone := COPA_MATA if rng == null or rng.randf() < 0.6 else COPA_MATA_CLARA
	_group(mesh, [
		[_cylinder(0.2 * size, 0.32 * size, trunk_height, 6), _at(Vector3(0, trunk_height * 0.5, 0))],
	], TRONCO)
	_group(mesh, [
		[_blob(2.1 * size, 3.2 * size, 8, 5), _at(Vector3(0, trunk_height + 1.2 * size, 0))],
		[_blob(1.6 * size, 2.2 * size, 7, 4), _at(Vector3(1.1 * size, trunk_height + 2.4 * size, 0.5 * size))],
		[_blob(1.5 * size, 2.0 * size, 7, 4), _at(Vector3(-1.0 * size, trunk_height + 0.6 * size, -0.7 * size))],
	], tone)
	return _result(mesh, 0.32 * size, trunk_height)


# ---------------------------------------------------------------------------
# Peças soltas do arraial (as mesmas do 2D: poço, cruzeiro, carroça, varal...).
# Cada uma devolve um Node3D já montado, com colisão simples quando faz sentido.
# ---------------------------------------------------------------------------

static func _mesh_instance(mesh: Mesh, position: Vector3, color: Color, yaw: float = 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material(color)
	instance.position = position
	instance.rotation.y = yaw
	return instance


static func _box_node(parent: Node3D, size: Vector3, position: Vector3, color: Color, yaw: float = 0.0) -> void:
	parent.add_child(_mesh_instance(_slab(size), position, color, yaw))


static func _collision(parent: Node3D, shape: Shape3D, position: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = position
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


## Poço de pedra com cobertura de telha e balde.
static func poco() -> Node3D:
	var root := Node3D.new()
	root.name = "Poco"
	root.add_child(_mesh_instance(_cylinder(0.95, 1.0, 0.9, 10), Vector3(0, 0.45, 0), PEDRA))
	root.add_child(_mesh_instance(_cylinder(0.72, 0.72, 0.95, 10), Vector3(0, 0.5, 0), Color("2c2f2e")))
	for side in [-1.0, 1.0]:
		_box_node(root, Vector3(0.14, 2.1, 0.14), Vector3(side * 0.85, 1.05, 0), MADEIRA_VELHA)
	_box_node(root, Vector3(1.95, 0.1, 0.1), Vector3(0, 2.05, 0), MADEIRA_VELHA)
	var roof := PrismMesh.new()
	roof.size = Vector3(2.4, 0.7, 1.6)
	root.add_child(_mesh_instance(roof, Vector3(0, 2.45, 0), Color("a8442f")))
	_box_node(root, Vector3(0.3, 0.32, 0.3), Vector3(0.2, 1.55, 0), Color("6c6c66"))
	var shape := CylinderShape3D.new()
	shape.radius = 1.0
	shape.height = 1.0
	_collision(root, shape, Vector3(0, 0.5, 0))
	return root


## Cruzeiro de madeira em base de pedra, diante da igreja.
static func cruzeiro() -> Node3D:
	var root := Node3D.new()
	root.name = "Cruzeiro"
	_box_node(root, Vector3(1.6, 0.5, 1.6), Vector3(0, 0.25, 0), PEDRA)
	_box_node(root, Vector3(1.0, 0.4, 1.0), Vector3(0, 0.7, 0), PEDRA)
	_box_node(root, Vector3(0.22, 4.2, 0.22), Vector3(0, 2.9, 0), MADEIRA_VELHA)
	_box_node(root, Vector3(1.6, 0.22, 0.22), Vector3(0, 4.1, 0), MADEIRA_VELHA)
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, 1.2, 1.6)
	_collision(root, shape, Vector3(0, 0.6, 0))
	return root


## Carroça de boi parada, com rodas de madeira e caçamba.
static func carroca() -> Node3D:
	var root := Node3D.new()
	root.name = "Carroca"
	_box_node(root, Vector3(2.6, 0.12, 1.4), Vector3(0, 0.75, 0), MADEIRA)
	for side in [-0.66, 0.66]:
		_box_node(root, Vector3(2.6, 0.55, 0.08), Vector3(0, 1.05, side), MADEIRA)
	_box_node(root, Vector3(0.08, 0.55, 1.4), Vector3(-1.28, 1.05, 0), MADEIRA)
	_box_node(root, Vector3(2.4, 0.12, 0.12), Vector3(2.3, 0.6, 0), MADEIRA_VELHA)
	for side in [-0.78, 0.78]:
		var wheel := _cylinder(0.62, 0.62, 0.12, 12)
		var instance := _mesh_instance(wheel, Vector3(0, 0.62, side), MADEIRA_VELHA)
		instance.rotation.x = PI * 0.5
		root.add_child(instance)
	_box_node(root, Vector3(1.6, 0.35, 1.1), Vector3(0.2, 0.98, 0), Color("c9a86a"))
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.8, 1.4, 1.6)
	_collision(root, shape, Vector3(0, 0.7, 0))
	return root


## Varal com panos ao vento entre dois mourões.
static func varal() -> Node3D:
	var root := Node3D.new()
	root.name = "Varal"
	for x in [-1.9, 1.9]:
		_box_node(root, Vector3(0.12, 2.0, 0.12), Vector3(x, 1.0, 0), MADEIRA_VELHA)
	_box_node(root, Vector3(3.9, 0.03, 0.03), Vector3(0, 1.85, 0), Color("d9d0bd"))
	var colors := [TECIDO, TECIDO_AZUL, TECIDO, Color("c98b7a")]
	for i in range(4):
		_box_node(root, Vector3(0.7, 0.9 - 0.12 * float(i % 2), 0.03), Vector3(-1.3 + float(i) * 0.86, 1.4, 0.02), colors[i])
	return root


## Pilha de lenha rachada encostada num canto.
static func pilha_lenha() -> Node3D:
	var root := Node3D.new()
	root.name = "PilhaLenha"
	for row in range(3):
		for i in range(5 - row):
			var log := _cylinder(0.13, 0.13, 1.0, 6)
			var instance := _mesh_instance(log, Vector3(-0.55 + float(i) * 0.28 + float(row) * 0.14, 0.14 + float(row) * 0.24, 0), Color("8a6b4a") if i % 2 == 0 else TRONCO)
			instance.rotation.x = PI * 0.5
			root.add_child(instance)
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, 0.8, 1.0)
	_collision(root, shape, Vector3(0, 0.4, 0))
	return root


## Pote de barro para água, à porta de casa.
static func pote_agua() -> Node3D:
	var root := Node3D.new()
	root.name = "PoteAgua"
	root.add_child(_mesh_instance(_blob(0.42, 0.7, 9, 5), Vector3(0, 0.4, 0), BARRO))
	root.add_child(_mesh_instance(_cylinder(0.24, 0.2, 0.18, 9), Vector3(0, 0.78, 0), Color("8f6a4a")))
	root.add_child(_mesh_instance(_cylinder(0.3, 0.3, 0.06, 9), Vector3(0, 0.03, 0), PEDRA))
	return root


## Cerca de mourões e duas ripas, com o comprimento pedido.
static func cerca(length: float, spacing: float = 1.65) -> Node3D:
	var root := Node3D.new()
	root.name = "Cerca"
	var count := maxi(int(length / spacing) + 1, 2)
	for i in range(count):
		_box_node(root, Vector3(0.15, 1.12, 0.15), Vector3(float(i) * spacing, 0.56, 0), MADEIRA)
	var width := float(count - 1) * spacing
	for height in [0.4, 0.87]:
		_box_node(root, Vector3(width, 0.12, 0.12), Vector3(width * 0.5, height, 0), Color("987650"))
	var shape := BoxShape3D.new()
	shape.size = Vector3(width + 0.15, 1.1, 0.2)
	_collision(root, shape, Vector3(width * 0.5, 0.55, 0))
	return root


## Banco de praça de madeira.
static func banco_praca() -> Node3D:
	var root := Node3D.new()
	root.name = "BancoPraca"
	_box_node(root, Vector3(2.3, 0.14, 0.65), Vector3(0, 0.62, 0), MADEIRA)
	_box_node(root, Vector3(2.3, 0.52, 0.12), Vector3(0, 1.04, -0.32), MADEIRA)
	for x in [-0.85, 0.85]:
		_box_node(root, Vector3(0.16, 0.6, 0.5), Vector3(x, 0.3, 0), Color("544b40"))
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.3, 1.3, 0.7)
	_collision(root, shape, Vector3(0, 0.65, 0))
	return root


## Lampião de poste a óleo (1887): poste de madeira, braço de ferro e lanterna de vidro.
static func lampiao_poste() -> Node3D:
	var root := Node3D.new()
	root.name = "LampiaoPoste"
	_box_node(root, Vector3(0.18, 3.0, 0.18), Vector3(0, 1.5, 0), MADEIRA_VELHA)
	_box_node(root, Vector3(0.6, 0.06, 0.06), Vector3(0.25, 2.85, 0), Color("3a3a3a"))
	_box_node(root, Vector3(0.28, 0.42, 0.28), Vector3(0.5, 2.95, 0), Color("d9c98a"))
	var roof := PrismMesh.new()
	roof.size = Vector3(0.4, 0.16, 0.4)
	root.add_child(_mesh_instance(roof, Vector3(0.5, 3.24, 0), Color("3a3a3a")))
	_box_node(root, Vector3(0.04, 0.42, 0.04), Vector3(0.36, 2.95, 0.12), Color("3a3a3a"))
	_box_node(root, Vector3(0.04, 0.42, 0.04), Vector3(0.64, 2.95, -0.12), Color("3a3a3a"))
	var shape := CylinderShape3D.new()
	shape.radius = 0.16
	shape.height = 3.0
	_collision(root, shape, Vector3(0, 1.5, 0))
	return root


## Candeeiro de querosene pendurado numa porta.
static func candeeiro() -> Node3D:
	var root := Node3D.new()
	root.name = "Candeeiro"
	root.add_child(_mesh_instance(_cylinder(0.07, 0.09, 0.14, 8), Vector3(0, 0.07, 0), Color("7a6a55")))
	root.add_child(_mesh_instance(_cylinder(0.05, 0.06, 0.16, 8), Vector3(0, 0.22, 0), Color("e8dcae")))
	_box_node(root, Vector3(0.02, 0.12, 0.02), Vector3(0, 0.36, 0), Color("3a3a3a"))
	return root


## Fogueira do terreiro: somente toras cruzadas; a chama vem das partículas.
static func fogueira() -> Node3D:
	var root := Node3D.new()
	root.name = "Fogueira"
	for i in range(3):
		var log := _cylinder(0.08, 0.08, 0.9, 6)
		var instance := _mesh_instance(log, Vector3(0, 0.12 + float(i) * 0.05, 0), TRONCO)
		instance.rotation = Vector3(0.35, TAU * float(i) / 3.0, PI * 0.5)
		root.add_child(instance)
	return root


## Túmulo de pedra com cruz de madeira.
static func tumulo() -> Node3D:
	var root := Node3D.new()
	root.name = "Tumulo"
	_box_node(root, Vector3(0.72, 0.15, 1.45), Vector3(0, 0.08, 0), Color("a9a9a0"))
	_box_node(root, Vector3(0.12, 0.9, 0.12), Vector3(0, 0.6, -0.55), MADEIRA_VELHA)
	_box_node(root, Vector3(0.48, 0.12, 0.12), Vector3(0, 0.72, -0.55), MADEIRA_VELHA)
	return root


## Pedras: rochedo de esferas achatadas.
static func pedras() -> Node3D:
	var root := Node3D.new()
	root.name = "Pedras"
	for index in range(13):
		var rock := _blob(0.8 + float(index % 3) * 0.4, 0.8 + float(index % 4) * 0.3, 7, 4)
		root.add_child(_mesh_instance(rock, Vector3(float(index % 5) * 2.8 - 5.6, 0.35, floorf(float(index) / 5.0) * 2.9 - 2.9), PEDRA))
	var shape := BoxShape3D.new()
	shape.size = Vector3(13.0, 1.4, 7.0)
	_collision(root, shape, Vector3(0, 0.7, 0))
	return root


## Canteiro de mandioca: leiras de terra e pés com hastes avermelhadas.
static func canteiro_mandioca() -> Node3D:
	var root := Node3D.new()
	root.name = "CanteiroMandioca"
	for row in range(3):
		_box_node(root, Vector3(5.6, 0.1, 0.88), Vector3(0, 0.055, float(row) * 1.35), Color("826346"))
		for column in range(7):
			var stem := _cylinder(0.02, 0.04, 0.9 + float(row) * 0.1, 5)
			root.add_child(_mesh_instance(stem, Vector3(-2.3 + float(column) * 0.75, 0.5, float(row) * 1.35), Color("8d4a3c")))
			var leaves := _blob(0.28, 0.2, 6, 3)
			root.add_child(_mesh_instance(leaves, Vector3(-2.3 + float(column) * 0.75, 0.98 + float(row) * 0.1, float(row) * 1.35), COPA_CAJUEIRO))
	return root


## Moita florida (maria-sem-vergonha).
static func moita() -> Node3D:
	var root := Node3D.new()
	root.name = "Moita"
	root.add_child(_mesh_instance(_blob(0.55, 0.7, 7, 4), Vector3(0, 0.35, 0), COPA_CAJUEIRO))
	for i in range(5):
		var angle := TAU * float(i) / 5.0
		root.add_child(_mesh_instance(_blob(0.09, 0.09, 5, 3), Vector3(cos(angle) * 0.4, 0.62, sin(angle) * 0.4), Color("e4c782") if i % 2 == 0 else Color("ce9d99")))
	return root
