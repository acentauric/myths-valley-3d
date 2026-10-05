@tool
extends Node3D
## Host leve salvo nas cenas principais. A composição com base geográfica só é mostrada pelo editor;
## numa execução normal este nó não carrega recurso algum e o WorldBuilder o remove.

const PREVIA := "res://scenes/prototipo_3d/composicao_vale.tscn"


func _ready() -> void:
	if Engine.is_editor_hint():
		_mostrar.call_deferred()


func _mostrar() -> void:
	if not Engine.is_editor_hint() or get_child_count(true) > 0:
		return
	var recurso := load(PREVIA) as PackedScene
	if recurso == null:
		push_warning("A composição autoral não foi encontrada: " + PREVIA)
		return
	var composicao := recurso.instantiate()
	composicao.name = "Previa"
	# Filho interno: aparece no viewport, mas não é incorporado à abertura ou ao
	# vale quando essas cenas são salvas. Para editar as casas, abra PREVIA.
	add_child(composicao, false, Node.INTERNAL_MODE_BACK)
