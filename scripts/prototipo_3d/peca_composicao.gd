@tool
extends Node3D
## Objeto de uma construção (árvore, adereço, item ou luz). Mova e gire (Y) à vontade:
## o jogo lê esta posição relativa à casa. Duplicar (Ctrl+D) cria mais um no jogo;
## apagar remove do jogo. "No chão" mantém o objeto assentado no terreno.

@export var id: String = "":
	set(valor):
		id = valor
		update_configuration_warnings()
@export_enum("arvore", "adereco", "item", "candeeiro", "lampiao", "luz_janela", "fogueira", "construcao") var tipo: String = "adereco":
	set(valor):
		tipo = valor
		_agendar_previa()
@export var chave: String = "":
	set(valor):
		chave = valor
		_agendar_previa()
@export_range(0.2, 4.0, 0.05) var tamanho: float = 1.0:
	set(valor):
		tamanho = valor
		_agendar_previa()
@export var no_chao: bool = true:
	set(valor):
		no_chao = valor
		_assentar()

var _previa_pendente := false
var _assentando := false


func _ready() -> void:
	if Engine.is_editor_hint():
		add_to_group("composicao_previas")
		set_notify_transform(true)
		_agendar_previa()


func atualizar_previa() -> void:
	_assentar()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		_assentar()


func _agendar_previa() -> void:
	if not Engine.is_editor_hint() or _previa_pendente or not is_inside_tree():
		return
	_previa_pendente = true
	_montar_previa.call_deferred()


func _montar_previa() -> void:
	_previa_pendente = false
	var antiga := get_node_or_null("Previa")
	if antiga != null:
		remove_child(antiga)
		antiga.queue_free()
	var previa := Node3D.new()
	previa.name = "Previa"
	add_child(previa, false, Node.INTERNAL_MODE_BACK)
	var modelo := chave if not chave.is_empty() else String(PecasConstrucoes.CHAVE_LUZ.get(tipo, ""))
	if not modelo.is_empty() and CatalogoAssets.PECAS.has(modelo):
		var visual := CatalogoAssets.instanciar(modelo, previa, Vector3.ZERO, tamanho)
		if visual != null:
			visual.set_meta("_edit_lock_", true)
	if tipo in ["candeeiro", "lampiao", "luz_janela", "fogueira"]:
		var luz := OmniLight3D.new()
		luz.light_color = Color(1.0, 0.72, 0.4)
		luz.omni_range = 3.0
		luz.light_energy = 0.6
		luz.position = Vector3(0, 2.6, 0) if tipo == "lampiao" else Vector3(0, 0.1, 0.05)
		previa.add_child(luz)
	if previa.get_child_count() == 0:
		var marcador := MeshInstance3D.new()
		var esfera := SphereMesh.new()
		esfera.radius = 0.25
		esfera.height = 0.5
		marcador.mesh = esfera
		previa.add_child(marcador)
	_assentar()


## Mantém o objeto no terreno (altura vinda da base geográfica do editor).
func _assentar() -> void:
	if not Engine.is_editor_hint() or not no_chao or _assentando or not is_inside_tree():
		return
	var raiz := get_tree().edited_scene_root
	if raiz == null or not raiz.has_method("altura_em"):
		return
	var global := global_position
	var chao: float = raiz.altura_em(global)
	if is_finite(chao) and absf(global.y - chao) > 0.005:
		_assentando = true
		global_position = Vector3(global.x, chao, global.z)
		_assentando = false


func dados() -> Dictionary:
	return {
		"id": id, "tipo": tipo, "chave": chave, "tamanho": tamanho, "no_chao": no_chao,
		"visivel": visible, "transform": transform,
	}


func _get_configuration_warnings() -> PackedStringArray:
	if id.is_empty():
		return PackedStringArray(["Dê um id a este objeto (ex.: Bananeira 5)."])
	return PackedStringArray()
