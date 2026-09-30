@tool
extends Node3D
## Host leve salvo nas cenas principais. A malha grande só é lida pelo editor;
## numa execução normal este nó não carrega recurso algum e o WorldBuilder o remove.

const PREVIA := "res://scenes/prototipo_3d/terreno_editavel.tscn"


func _ready() -> void:
	if Engine.is_editor_hint():
		_mostrar.call_deferred()


func _mostrar() -> void:
	if not Engine.is_editor_hint() or get_child_count(true) > 0:
		return
	var recurso := load(PREVIA) as PackedScene
	if recurso == null:
		push_warning("Gere a prévia do terreno: " + PREVIA)
		return
	var terreno := recurso.instantiate()
	terreno.name = "Previa"
	# Filho interno: aparece no viewport, mas não é incorporado à abertura ou ao
	# vale quando essas cenas são salvas. Para editar a malha, abra PREVIA.
	add_child(terreno, false, Node.INTERNAL_MODE_BACK)
