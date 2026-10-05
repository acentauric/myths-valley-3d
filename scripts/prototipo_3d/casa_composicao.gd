@tool
extends Node3D
## Mova este nó (não o filho Visual). A transformação salva é lida pelo jogo.
## Identidade e referência inicial ficam estáveis para edição manual e por código.
## Filhos editáveis: "Terreiro" (chão de terra) e os objetos da casa (peca_composicao.gd).
## O alicerce é calculado pelo relevo (prévia aqui, igual ao jogo); ajuste no grupo Alicerce.

@export var identificador: String = ""
@export var chave: String = ""
@export_storage var posicao_inicial: Vector3
@export_storage var posicao_lote_inicial: Vector3
@export_storage var giro_inicial: float = 0.0
## Depois que os objetos padrão são criados, o jogo passa a usar só os nós desta casa.
@export_storage var pecas_criadas: bool = false

@export_group("Alicerce")
@export var alicerce_visivel: bool = true:
	set(valor):
		alicerce_visivel = valor
		_agendar_alicerce()
## Folga do alicerce além da planta. Negativo = padrão (0,16 casas; 0,36 igreja).
@export_range(-1.0, 3.0, 0.01) var alicerce_margem: float = -1.0:
	set(valor):
		alicerce_margem = valor
		_agendar_alicerce()
## Só a igreja tem escadaria.
@export var escadaria: bool = true:
	set(valor):
		escadaria = valor
		_agendar_alicerce()
@export_group("")

const TERREIRO := preload("res://scenes/prototipo_3d/terreiro_casa.tscn")
const PECA := preload("res://scripts/prototipo_3d/peca_composicao.gd")
## Folga do terreiro além da planta da casa, em unidades (cada lado).
const FOLGA_TERREIRO := 1.6

var _alicerce_pendente := false
var _material_terreiro: StandardMaterial3D


func _ready() -> void:
	if Engine.is_editor_hint():
		add_to_group("composicao_previas")
		set_notify_transform(true)
		_mostrar_visual.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		_agendar_alicerce()


func atualizar_previa() -> void:
	_agendar_alicerce()


func ajustes_alicerce() -> Dictionary:
	return {"visivel": alicerce_visivel, "margem": alicerce_margem, "escadaria": escadaria}


func _mostrar_visual() -> void:
	if get_node_or_null("Visual") != null or not CatalogoAssets.PECAS.has(chave):
		return
	# A mesma normalização do jogo, sem persistir cópias de GLBs no arquivo autoral.
	var visual := CatalogoAssets.instanciar(chave, self, Vector3.ZERO)
	if visual != null:
		remove_child(visual)
		visual.name = "Visual"
		add_child(visual, false, Node.INTERNAL_MODE_BACK)
		visual.set_meta("_edit_lock_", true)
		_garantir_terreiro(visual)
		_garantir_pecas()
		_agendar_alicerce()


func _raiz_editada() -> Node:
	if not is_inside_tree():
		return null
	var raiz := get_tree().edited_scene_root
	return raiz if raiz != null and raiz.is_ancestor_of(self) else null


## Cria o filho "Terreiro" (Decal) uma única vez; depois ele é do autor e fica salvo na cena.
func _garantir_terreiro(visual: Node3D) -> void:
	var raiz := _raiz_editada()
	if raiz == null or get_node_or_null("Terreiro") != null:
		return
	var terreiro := TERREIRO.instantiate() as Decal
	if visual.has_meta("limites"):
		var limites: AABB = visual.get_meta("limites")
		terreiro.size = Vector3(limites.size.x + FOLGA_TERREIRO * 2.0, 2.4, limites.size.z + FOLGA_TERREIRO * 2.0)
	# Centro abaixo da base: alcança o declive do terreno sem sujar muito as paredes.
	terreiro.position = Vector3(0, -0.7, 0)
	add_child(terreiro)
	terreiro.owner = raiz


## Cria os objetos padrão desta casa (PecasConstrucoes) uma única vez, como nós editáveis.
func _garantir_pecas() -> void:
	var raiz := _raiz_editada()
	if raiz == null or pecas_criadas:
		return
	for item in PecasConstrucoes.padrao_da_casa(identificador):
		var peca := Node3D.new()
		peca.set_script(PECA)
		peca.name = String(item["id"])
		peca.set("id", item["id"])
		peca.set("tipo", item["tipo"])
		peca.set("chave", item["chave"])
		peca.set("tamanho", item["tamanho"])
		peca.set("no_chao", item["no_chao"])
		peca.position = item["desloc"]
		peca.rotation.y = float(item["giro"])
		add_child(peca)
		peca.owner = raiz
	pecas_criadas = true


func _agendar_alicerce() -> void:
	if not Engine.is_editor_hint() or _alicerce_pendente or not is_inside_tree():
		return
	_alicerce_pendente = true
	_montar_alicerce.call_deferred()


## Prévia do alicerce com a mesma conta do jogo (AlicerceConstrucao). Não é salva.
func _montar_alicerce() -> void:
	_alicerce_pendente = false
	var antiga := get_node_or_null("PreviaAlicerce")
	if antiga != null:
		remove_child(antiga)
		antiga.queue_free()
	var raiz := _raiz_editada()
	var visual := get_node_or_null("Visual") as Node3D
	if raiz == null or visual == null or not visual.has_meta("limites") or not raiz.has_method("altura_em"):
		return
	var limites: AABB = visual.get_meta("limites")
	var yaw := global_rotation.y
	var caixas := AlicerceConstrucao.caixas(Callable(raiz, "altura_em"), global_position, Vector2(limites.size.x, limites.size.z), yaw, chave == "igreja", ajustes_alicerce())
	if caixas.is_empty():
		return
	var previa := Node3D.new()
	previa.name = "PreviaAlicerce"
	add_child(previa, false, Node.INTERNAL_MODE_BACK)
	for caixa in caixas:
		var malha := BoxMesh.new()
		malha.size = caixa["size"]
		var instancia := MeshInstance3D.new()
		instancia.mesh = malha
		instancia.material_override = _material(caixa, chave == "igreja")
		previa.add_child(instancia)
		instancia.global_transform = Transform3D(Basis(Vector3.UP, yaw), caixa["center"])


func _material(caixa: Dictionary, igreja: bool) -> Material:
	if caixa["tipo"] == "alicerce" and not igreja:
		# Cor do _terreiro_material do jogo. Sem a textura do chão da praça: usá-la em 3D
		# no editor faz o Godot trocar as opções de importação dela (detect_3d).
		if _material_terreiro == null:
			_material_terreiro = StandardMaterial3D.new()
			_material_terreiro.albedo_color = Color("b8a27e")
			_material_terreiro.roughness = 0.9
		return _material_terreiro
	var material := StandardMaterial3D.new()
	material.albedo_color = caixa["cor"]
	material.roughness = 0.9
	return material


func _get_configuration_warnings() -> PackedStringArray:
	var avisos := PackedStringArray()
	if identificador.is_empty() or chave.is_empty():
		avisos.append("Mantenha o identificador e a chave do catálogo da construção.")
	if not scale.is_equal_approx(Vector3.ONE) or absf(rotation.x) > 0.001 or absf(rotation.z) > 0.001:
		avisos.append("Nesta etapa, edite posição e rotação Y. Escala e inclinação não são suportadas no jogo.")
	return avisos
