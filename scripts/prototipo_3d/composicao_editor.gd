@tool
extends Node3D
## Base de referência carregada somente no editor, sem entrar no arquivo autoral.


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
