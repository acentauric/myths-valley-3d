class_name CatalogoAssets
extends RefCounted
## Catálogo único das peças do vale: para cada chave, o GLB do Tripo (linha mestra)
## e a medida usada para normalizar o modelo na cena. O construtor procedural de cada
## peça vive em FloraReconcavo / world_builder e é escolhido quando Estilo.procedural().
##
## "altura" normaliza pela altura visual; "largura" pela maior dimensão horizontal.
## "tronco" é o raio da colisão cilíndrica (árvores); "caixa" pede colisão em caixa.

const PASTA := "res://assets/prototipo_3d/"

const PECAS := {
	# Árvores nomeadas (perto do jogador)
	"mangueira": {"tripo": "arvores/mangueira_tripo.glb", "altura": 7.2, "tronco": 0.55},
	"jaqueira": {"tripo": "arvores/jaqueira_tripo.glb", "altura": 8.4, "tronco": 0.4},
	"cajueiro": {"tripo": "arvores/cajueiro_tripo.glb", "altura": 5.4, "tronco": 0.42},
	"coqueiro": {"tripo": "arvores/coqueiro_tripo.glb", "altura": 9.5, "tronco": 0.24},
	"pau_brasil": {"tripo": "arvores/pau_brasil_tripo.glb", "altura": 5.6, "tronco": 0.38},
	"dendezeiro": {"tripo": "arvores/dende_tripo.glb", "altura": 6.5, "tronco": 0.4},
	"bananeira": {"tripo": "arvores/bananeira_tripo.glb", "altura": 3.2, "tronco": 0.25},
	"ipe_amarelo": {"tripo": "arvores/ipe_amarelo_tripo.glb", "altura": 6.5, "tronco": 0.3},
	"ipe_roxo": {"tripo": "arvores/ipe_roxo_tripo.glb", "altura": 6.5, "tronco": 0.3},
	"embauba": {"tripo": "arvores/embauba_tripo.glb", "altura": 8.0, "tronco": 0.2},
	"mata_alta": {"tripo": "arvores/mata_a_tripo.glb", "altura": 11.0, "tronco": 0.45},
	"mata_larga": {"tripo": "arvores/mata_b_tripo.glb", "altura": 9.0, "tronco": 0.5},
	"moita": {"tripo": "arvores/moita_tripo.glb", "altura": 1.1},
	"capim": {"tripo": "arvores/capim_tripo.glb", "altura": 0.9},
	# Construções
	"capela": {"tripo": "construcoes/capela_tripo.glb", "largura": 9.0, "caixa": true},
	"casa_taipa": {"tripo": "construcoes/casa_taipa_tripo.glb", "largura": 6.5, "caixa": true},
	"casa_carro_quebrado": {"tripo": "casas/casa_carro_quebrado_tripo.glb", "largura": 5.2, "caixa": true},
	"venda": {"tripo": "construcoes/venda_tripo.glb", "largura": 8.0, "caixa": true},
	"casa_pasto": {"tripo": "construcoes/casa_pasto_tripo.glb", "largura": 8.5, "caixa": true},
	"pier": {"tripo": "construcoes/pier_tripo.glb", "largura": 14.0},
	"ponte": {"tripo": "construcoes/ponte_tripo.glb", "largura": 9.0},
	"mirante": {"tripo": "construcoes/mirante_tripo.glb", "altura": 3.6, "caixa": true},
	# Adereços
	"poco": {"tripo": "construcoes/poco_tripo.glb", "altura": 3.1, "tronco": 1.05},
	"cerca": {"tripo": "aderecos/cerca_tripo.glb", "largura": 4.0, "caixa": true},
	"cruzeiro": {"tripo": "aderecos/cruzeiro_tripo.glb", "altura": 4.5, "caixa": true},
	"tumulo": {"tripo": "aderecos/tumulo_tripo.glb", "largura": 1.6},
	"carroca": {"tripo": "aderecos/carroca_tripo.glb", "largura": 3.2, "caixa": true},
	"varal": {"tripo": "aderecos/varal_tripo.glb", "largura": 3.8},
	"lenha": {"tripo": "aderecos/lenha_tripo.glb", "largura": 1.5, "caixa": true},
	"pote": {"tripo": "aderecos/pote_tripo.glb", "altura": 0.95},
	"banco": {"tripo": "aderecos/banco_tripo.glb", "largura": 2.2, "caixa": true},
	"lampiao_poste": {"tripo": "aderecos/lampiao_poste_tripo.glb", "altura": 3.4, "tronco": 0.15},
	"candeeiro": {"tripo": "aderecos/candeeiro_tripo.glb", "altura": 0.42},
	"fogueira": {"tripo": "aderecos/fogueira_tripo.glb", "largura": 1.6},
	"mandioca_canteiro": {"tripo": "aderecos/mandioca_canteiro_tripo.glb", "largura": 3.5},
	"pedras": {"tripo": "aderecos/pedras_tripo.glb", "largura": 3.0, "caixa": true},
	# Personagens
	"pedro": {"tripo": "personagens/pedro_tripo.glb", "altura": 1.75},
	"benedito": {"tripo": "personagens/benedito_tripo.glb", "altura": 1.68},
	"zefa": {"tripo": "personagens/zefa_tripo.glb", "altura": 1.58},
	"cosme": {"tripo": "personagens/cosme_tripo.glb", "altura": 1.5},
	"tonho": {"tripo": "personagens/tonho_tripo.glb", "altura": 1.72},
	"filo": {"tripo": "personagens/filo_tripo.glb", "altura": 1.6},
	"damiao": {"tripo": "personagens/damiao_tripo.glb", "altura": 1.74},
	"candinha": {"tripo": "personagens/candinha_tripo.glb", "altura": 1.62},
	"viajante": {"tripo": "personagens/viajante_tripo.glb", "altura": 1.78},
	# Itens de mão (os mesmos do 2D)
	"machado": {"tripo": "itens/machado_tripo.glb", "largura": 0.9},
	"enxada": {"tripo": "itens/enxada_tripo.glb", "largura": 1.4},
	"balde": {"tripo": "itens/balde_tripo.glb", "altura": 0.35},
	"picareta": {"tripo": "itens/picareta_tripo.glb", "largura": 0.9},
	"foice": {"tripo": "itens/foice_tripo.glb", "largura": 0.5},
	"regador": {"tripo": "itens/regador_tripo.glb", "altura": 0.4},
	"vara_pescar": {"tripo": "itens/vara_pescar_tripo.glb", "largura": 2.2},
	"mandioca": {"tripo": "itens/mandioca_tripo.glb", "largura": 0.5},
	"lenha_feixe": {"tripo": "itens/lenha_feixe_tripo.glb", "largura": 0.6},
	"pedra": {"tripo": "itens/pedra_tripo.glb", "largura": 0.25},
	"peixe": {"tripo": "itens/peixe_tripo.glb", "largura": 0.35},
	"cesto": {"tripo": "itens/cesto_tripo.glb", "altura": 0.4},
	"facao": {"tripo": "itens/facao_tripo.glb", "largura": 0.6},
	"corda": {"tripo": "itens/corda_tripo.glb", "largura": 0.35},
	"tabua": {"tripo": "itens/tabua_tripo.glb", "largura": 1.6},
	"farinha": {"tripo": "itens/farinha_tripo.glb", "altura": 0.6},
	"chapeu": {"tripo": "itens/chapeu_tripo.glb", "largura": 0.4},
	"milho": {"tripo": "itens/milho_tripo.glb", "largura": 0.3},
	"cana": {"tripo": "itens/cana_tripo.glb", "altura": 1.6},
	"moringa": {"tripo": "itens/moringa_tripo.glb", "altura": 0.35},
	"prato_comida": {"tripo": "itens/prato_comida_tripo.glb", "largura": 0.3},
	"cacho_banana": {"tripo": "itens/cacho_banana_tripo.glb", "altura": 0.45},
	"jaca": {"tripo": "itens/jaca_tripo.glb", "altura": 0.45},
}

static var _cenas: Dictionary = {}
static var _malhas: Dictionary = {}
static var faltando: Array[String] = []


static func caminho(chave: String) -> String:
	if not PECAS.has(chave):
		return ""
	return PASTA + String(PECAS[chave]["tripo"])


static func tem_tripo(chave: String) -> bool:
	var path := caminho(chave)
	return not path.is_empty() and ResourceLoader.exists(path)


## Cena do Tripo para a chave, ou null (registrando a falta) quando o GLB ainda não existe.
static func cena(chave: String) -> PackedScene:
	if _cenas.has(chave):
		return _cenas[chave]
	var path := caminho(chave)
	if path.is_empty() or not ResourceLoader.exists(path):
		if not faltando.has(chave):
			faltando.append(chave)
		_cenas[chave] = null
		return null
	var scene := load(path) as PackedScene
	_cenas[chave] = scene
	return scene


## Instancia o modelo do Tripo com a base no chão em `origin`, normalizado pela medida
## do catálogo (× size) e girado em `yaw`. Devolve null quando o GLB não existe.
static func instanciar(chave: String, parent: Node, origin: Vector3, size: float = 1.0, yaw: float = 0.0) -> Node3D:
	var scene := cena(chave)
	if scene == null:
		return null
	var node := scene.instantiate() as Node3D
	node.name = chave.capitalize() + "Tripo"
	parent.add_child(node)
	var bounds := limites(node)
	var spec: Dictionary = PECAS[chave]
	var factor := 1.0
	if spec.has("altura"):
		factor = float(spec["altura"]) * size / maxf(bounds.size.y, 0.001)
	else:
		factor = float(spec["largura"]) * size / maxf(maxf(bounds.size.x, bounds.size.z), 0.001)
	node.scale = Vector3.ONE * factor
	node.rotation.y = yaw
	var center := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor
	node.position = origin - center.rotated(Vector3.UP, yaw)
	node.set_meta("limites", AABB(bounds.position * factor, bounds.size * factor))
	return node


## Colisão simples para um modelo instanciado por `instanciar`: cilindro no tronco ou caixa.
static func colisao(chave: String, node: Node3D, parent: Node, origin: Vector3, size: float = 1.0, yaw: float = 0.0) -> void:
	if node == null:
		return
	var spec: Dictionary = PECAS[chave]
	var bounds: AABB = node.get_meta("limites", AABB())
	var body := StaticBody3D.new()
	body.name = chave.capitalize() + "Colisao"
	var collision := CollisionShape3D.new()
	if spec.has("tronco"):
		var shape := CylinderShape3D.new()
		shape.radius = float(spec["tronco"]) * size
		shape.height = minf(bounds.size.y, 3.0)
		collision.shape = shape
		body.position = origin + Vector3(0, shape.height * 0.5, 0)
	elif spec.get("caixa", false):
		var shape := BoxShape3D.new()
		shape.size = bounds.size
		collision.shape = shape
		body.position = origin + Vector3(0, bounds.size.y * 0.5, 0)
		body.rotation.y = yaw
	else:
		return
	body.add_child(collision)
	parent.add_child(body)


## Malha + transformação-base para usar o modelo do Tripo em MultiMesh (mata, orla, itens).
## Devolve {} quando o GLB não existe.
static func malha(chave: String, size: float = 1.0) -> Dictionary:
	var cache_key := "%s@%.3f" % [chave, size]
	if _malhas.has(cache_key):
		return _malhas[cache_key]
	var scene := cena(chave)
	if scene == null:
		return {}
	var node := scene.instantiate() as Node3D
	var instances: Array = node.find_children("*", "MeshInstance3D", true, false)
	if instances.is_empty():
		node.free()
		return {}
	var bounds := limites(node)
	var spec: Dictionary = PECAS[chave]
	var factor := 1.0
	if spec.has("altura"):
		factor = float(spec["altura"]) * size / maxf(bounds.size.y, 0.001)
	else:
		factor = float(spec["largura"]) * size / maxf(maxf(bounds.size.x, bounds.size.z), 0.001)
	# Funde todas as MeshInstance3D numa ArrayMesh única, já com a transformação relativa.
	var merged := ArrayMesh.new()
	for instance in instances:
		var mesh_instance := instance as MeshInstance3D
		var relative: Transform3D = _relativa(node, mesh_instance)
		for surface in range(mesh_instance.mesh.get_surface_count()):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tool.append_from(mesh_instance.mesh, surface, relative)
			var material := mesh_instance.get_active_material(surface)
			if material != null:
				tool.set_material(material)
			tool.commit(merged)
	var base := Transform3D(Basis().scaled(Vector3.ONE * factor), -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor)
	var result := {"mesh": merged, "base": base, "altura": bounds.size.y * factor, "tronco": float(spec.get("tronco", 0.3)) * size}
	_malhas[cache_key] = result
	node.free()
	return result


static func limites(node: Node3D) -> AABB:
	var combined := AABB()
	var has_bounds := false
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var relative: Transform3D = _relativa(node, mesh_instance)
		var bounds := relative * mesh_instance.get_aabb()
		combined = combined.merge(bounds) if has_bounds else bounds
		has_bounds = true
	return combined


## Transformação de `child` no espaço de `root`, sem depender de estar na árvore de cena.
static func _relativa(root: Node3D, child: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = child
	while current != null and current != root:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


static func relatorio_faltando() -> String:
	if faltando.is_empty():
		return ""
	return "Peças Tripo ainda não exportadas: " + ", ".join(faltando)
