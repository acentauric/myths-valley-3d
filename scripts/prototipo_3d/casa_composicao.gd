@tool
extends Node3D
## Mova este nó (não o filho Visual). A transformação salva é lida pelo jogo.
## Identidade e referência inicial ficam estáveis para edição manual e por código.

@export var identificador: String = ""
@export var chave: String = ""
@export_storage var posicao_inicial: Vector3
@export_storage var posicao_lote_inicial: Vector3
@export_storage var giro_inicial: float = 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		_mostrar_visual.call_deferred()


func _mostrar_visual() -> void:
	if get_child_count(true) > 0 or not CatalogoAssets.PECAS.has(chave):
		return
	# A mesma normalização do jogo, sem persistir cópias de GLBs no arquivo autoral.
	var visual := CatalogoAssets.instanciar(chave, self, Vector3.ZERO)
	if visual != null:
		remove_child(visual)
		visual.name = "Visual"
		add_child(visual, false, Node.INTERNAL_MODE_BACK)
		visual.set_meta("_edit_lock_", true)


func _get_configuration_warnings() -> PackedStringArray:
	var avisos := PackedStringArray()
	if identificador.is_empty() or chave.is_empty():
		avisos.append("Mantenha o identificador e a chave do catálogo da construção.")
	if not scale.is_equal_approx(Vector3.ONE) or absf(rotation.x) > 0.001 or absf(rotation.z) > 0.001:
		avisos.append("Nesta etapa, edite posição e rotação Y. Escala e inclinação não são suportadas no jogo.")
	return avisos
