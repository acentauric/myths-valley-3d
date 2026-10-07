extends Node
## #126: galhos/raízes têm geometria que o cilindro do tronco não descreve.
## Até oito árvores/barcos próximos; malhas de colisão reutilizadas.
const Catalogo = preload("res://scripts/prototipo_3d/catalogo_assets.gd")
const Camadas = preload("res://scripts/prototipo_3d/camadas.gd")
var _formas: Dictionary = {}
var _corpos: Dictionary = {}
var _espera := 0.0
var _apagadas: Dictionary = {}

## Quando o jogador está entre raízes e nenhum braço tem folga, desvanecer
## apenas a árvore que encobre o corpo evita colocar a câmera dentro dele.
func mostrar_jogador(camera: Camera3D, centro: Vector3, delta: float) -> void:
	var encobrindo: Dictionary = {}
	var consulta := PhysicsRayQueryParameters3D.new()
	consulta.collision_mask = Camadas.CAMERA_VEGETACAO
	consulta.hit_back_faces = true
	for altura in [-0.6, 0.0, 0.5]:
		consulta.from = camera.global_position
		consulta.to = centro + Vector3.UP * altura
		var resultado := camera.get_world_3d().direct_space_state.intersect_ray(consulta)
		if not resultado.is_empty():
			var corpo = resultado.get("collider")
			for id in _corpos:
				if corpo in _corpos[id]:
					encobrindo[id] = true
	for id in _corpos:
		for corpo in _corpos[id]:
			if not is_instance_valid(corpo):
				continue
			var malha: MeshInstance3D = corpo.get_parent()
			var chave := malha.get_instance_id()
			if encobrindo.has(id) and not _apagadas.has(chave):
				_apagadas[chave] = {"no": weakref(malha), "antes": malha.transparency}
			if _apagadas.has(chave):
				var antes: float = _apagadas[chave]["antes"]
				var alvo := maxf(antes, 0.88) if encobrindo.has(id) else antes
				malha.transparency = move_toward(malha.transparency, alvo, delta * 3)
				if is_equal_approx(malha.transparency, antes):
					_apagadas.erase(chave)

func _restaurar() -> void:
	for entrada in _apagadas.values():
		var no = entrada["no"].get_ref()
		if is_instance_valid(no):
			no.transparency = entrada["antes"]
	_apagadas.clear()

func atualizar(ativo: bool, posicao: Vector3, alcance: float, delta: float) -> void:
	_espera -= delta
	if not ativo:
		if not _corpos.is_empty():
			_limpar()
		return
	if _espera > 0.0:
		return
	_espera = 0.7
	var proximas: Array[Node3D] = []
	for peca in get_tree().get_nodes_in_group("obstaculos_visuais_da_camera"):
		if not peca is Node3D or not peca.is_visible_in_tree():
			continue
		var limites: AABB = peca.get_meta("limites", AABB())
		var raio := maxf(limites.size.x, limites.size.z) * 0.5
		if peca.global_position.distance_to(posicao) <= alcance + raio + 2:
			proximas.append(peca)
	proximas.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.distance_squared_to(posicao) < b.global_position.distance_squared_to(posicao))
	var desejadas: Dictionary = {}
	for peca in proximas.slice(0, 8):
		var id: int = peca.get_instance_id()
		desejadas[id] = true
		if not _corpos.has(id):
			var novos: Array[StaticBody3D] = []
			_montar(peca, novos)
			_corpos[id] = novos
	for id in _corpos.keys():
		if not desejadas.has(id):
			_retirar(id)

func _montar(no: Node, novos: Array[StaticBody3D]) -> void:
	if no is MeshInstance3D and no.mesh != null:
		var id: int = no.mesh.get_instance_id()
		if not _formas.has(id):
			var forma: ConcavePolygonShape3D = no.mesh.create_trimesh_shape()
			forma.backface_collision = true
			_formas[id] = forma
		var corpo := StaticBody3D.new()
		corpo.name = "GeometriaDaCameraAutomatica"
		corpo.collision_layer = Camadas.CAMERA_VEGETACAO
		corpo.collision_mask = 0
		var colisao := CollisionShape3D.new()
		colisao.shape = _formas[id]
		corpo.add_child(colisao)
		no.add_child(corpo)
		novos.append(corpo)
	for filho in no.get_children():
		if not filho is StaticBody3D:
			_montar(filho, novos)

func _retirar(id: int) -> void:
	for corpo in _corpos[id]:
		if is_instance_valid(corpo):
			var malha = corpo.get_parent()
			var chave: int = malha.get_instance_id()
			if _apagadas.has(chave):
				malha.transparency = _apagadas[chave]["antes"]
				_apagadas.erase(chave)
			corpo.collision_layer = 0
			corpo.queue_free()
	_corpos.erase(id)

func _limpar() -> void:
	_restaurar()
	for id in _corpos.keys():
		_retirar(id)

func _exit_tree() -> void:
	_limpar()
