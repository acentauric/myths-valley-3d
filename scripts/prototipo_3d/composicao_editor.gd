@tool
extends Node3D
## Base de referência carregada somente no editor, sem entrar no arquivo autoral.
## Também responde a altura do terreno (altura_em) para as prévias de alicerce e o
## assentamento das peças; a malha é a mesma prévia gerada pelo GeoRegionRenderer.

const CELULA := 4.0

var _triangulos := PackedVector3Array()
var _grade: Dictionary = {}


func _get_configuration_warnings() -> PackedStringArray:
	if not transform.is_equal_approx(Transform3D.IDENTITY):
		return PackedStringArray(["Mova os nós dentro de Casas. A raiz e a base geográfica devem permanecer na origem."])
	return PackedStringArray()


func _ready() -> void:
	if Engine.is_editor_hint():
		_mostrar_base.call_deferred()


func _mostrar_base() -> void:
	if not Engine.is_editor_hint() or get_node_or_null("BaseGeografica") != null:
		return
	var base := Node3D.new()
	base.name = "BaseGeografica"
	add_child(base, false, Node.INTERNAL_MODE_BACK)
	for caminho in ["res://scenes/prototipo_3d/terreno_editavel.tscn", "res://scenes/prototipo_3d/ruas_referencia.tscn"]:
		var recurso := load(caminho) as PackedScene
		if recurso != null:
			base.add_child(recurso.instantiate(), false, Node.INTERNAL_MODE_BACK)
	_indexar_terreno(base)
	# Casas e peças recalculam a prévia agora que o relevo responde.
	get_tree().call_group("composicao_previas", "atualizar_previa")


func _indexar_terreno(base: Node) -> void:
	_triangulos.clear()
	_grade.clear()
	var terra := base.find_child("Terra", true, false) as MeshInstance3D
	if terra == null or terra.mesh == null:
		push_warning("Prévia sem terreno: alicerces e peças não serão assentados.")
		return
	var malha := terra.mesh
	var transformacao := terra.global_transform
	for superficie in range(malha.get_surface_count()):
		var arrays := malha.surface_get_arrays(superficie)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var total := indices.size() if not indices.is_empty() else vertices.size()
		for i in range(0, total - 2, 3):
			var a := transformacao * vertices[indices[i] if not indices.is_empty() else i]
			var b := transformacao * vertices[indices[i + 1] if not indices.is_empty() else i + 1]
			var c := transformacao * vertices[indices[i + 2] if not indices.is_empty() else i + 2]
			var indice := _triangulos.size()
			_triangulos.append(a)
			_triangulos.append(b)
			_triangulos.append(c)
			var x0 := floori(minf(a.x, minf(b.x, c.x)) / CELULA)
			var x1 := floori(maxf(a.x, maxf(b.x, c.x)) / CELULA)
			var z0 := floori(minf(a.z, minf(b.z, c.z)) / CELULA)
			var z1 := floori(maxf(a.z, maxf(b.z, c.z)) / CELULA)
			for gx in range(x0, x1 + 1):
				for gz in range(z0, z1 + 1):
					var chave := Vector2i(gx, gz)
					if not _grade.has(chave):
						_grade[chave] = PackedInt32Array()
					var lista: PackedInt32Array = _grade[chave]
					lista.append(indice)
					_grade[chave] = lista


## Altura do terreno da prévia em (x, z); NAN fora do terreno ou antes de carregar.
func altura_em(posicao: Vector3) -> float:
	var lista: PackedInt32Array = _grade.get(Vector2i(floori(posicao.x / CELULA), floori(posicao.z / CELULA)), PackedInt32Array())
	var p := Vector2(posicao.x, posicao.z)
	var melhor := -INF
	for indice in lista:
		var a := _triangulos[indice]
		var b := _triangulos[indice + 1]
		var c := _triangulos[indice + 2]
		var a2 := Vector2(a.x, a.z)
		var b2 := Vector2(b.x, b.z)
		var c2 := Vector2(c.x, c.z)
		var v0 := b2 - a2
		var v1 := c2 - a2
		var v2 := p - a2
		var den := v0.x * v1.y - v1.x * v0.y
		if absf(den) < 1e-9:
			continue
		var u := (v2.x * v1.y - v1.x * v2.y) / den
		var v := (v0.x * v2.y - v2.x * v0.y) / den
		if u < -1e-5 or v < -1e-5 or u + v > 1.00001:
			continue
		melhor = maxf(melhor, a.y + u * (b.y - a.y) + v * (c.y - a.y))
	return melhor if is_finite(melhor) else NAN
