extends Node3D
## Cardume de peixinhos no raso ao lado do píer: nadam em roda, a meia água, se
## espalham um pouco e fogem de quem chega perto (jogador ou morador). Peixe do Tripo no
## estilo Tripo; no procedural, um corpo simples de tainha.

const QUANTIDADE := 14
## Raio da roda em torno do centro e velocidades (unidades por segundo).
const RAIO := 4.5
const VELOCIDADE := 0.9
const VELOCIDADE_FUGA := 3.2
const DISTANCIA_FUGA := 3.0
## Tamanho do peixe (maior dimensão, unidades) e quanto ele nada abaixo da superfície.
const TAMANHO := 0.38
const MEIA_AGUA := 0.45

var _peixes: Array[Node3D] = []
var _velocidades: Array[Vector3] = []
var _fases: Array[float] = []
var _centro := Vector3.ZERO
var _nivel := 0.0
var _fundo := 0.5


## `centro` no nível da água; `fundo` é a lâmina d'água ali, em unidades.
func montar(centro: Vector3, nivel: float, fundo: float, tripo: bool) -> void:
	_centro = centro
	_nivel = nivel
	_fundo = fundo
	var rng := RandomNumberGenerator.new()
	rng.seed = 1887
	for i in QUANTIDADE:
		var peixe := _criar(tripo)
		var angulo := rng.randf() * TAU
		peixe.position = centro + Vector3(cos(angulo), 0.0, sin(angulo)) * rng.randf_range(0.5, RAIO)
		peixe.position.y = _altura(rng.randf())
		add_child(peixe)
		_peixes.append(peixe)
		_velocidades.append(Vector3(-sin(angulo), 0.0, cos(angulo)) * VELOCIDADE)
		_fases.append(rng.randf() * TAU)


func _altura(t: float) -> float:
	return _nivel - clampf(_fundo * lerpf(0.3, 0.7, t), 0.08, MEIA_AGUA)


func _physics_process(delta: float) -> void:
	if _peixes.is_empty():
		return
	var perigos: Array[Vector3] = []
	for grupo in ["map_player", "moradores"]:
		for no in get_tree().get_nodes_in_group(grupo):
			if no is Node3D and (no as Node3D).global_position.distance_to(_centro) < RAIO + DISTANCIA_FUGA * 2.0:
				perigos.append((no as Node3D).global_position)
	var t := Time.get_ticks_msec() / 1000.0
	for i in _peixes.size():
		var peixe := _peixes[i]
		var pos := peixe.global_position
		var rel := Vector3(pos.x - _centro.x, 0.0, pos.z - _centro.z)
		# Roda em volta do centro, puxada de volta quando se afasta, com um vaivém próprio.
		var roda := Vector3(-rel.z, 0.0, rel.x).normalized() * VELOCIDADE
		var volta := -rel * maxf(rel.length() - RAIO, 0.0) * 0.6
		var vaivem := Vector3(sin(t * 0.7 + _fases[i]), 0.0, cos(t * 0.9 + _fases[i] * 1.3)) * 0.35
		var desejada := roda + volta + vaivem
		var fugindo := false
		for perigo in perigos:
			var longe := Vector3(pos.x - perigo.x, 0.0, pos.z - perigo.z)
			if longe.length() < DISTANCIA_FUGA:
				desejada = longe.normalized() * VELOCIDADE_FUGA
				fugindo = true
		_velocidades[i] = _velocidades[i].lerp(desejada, 1.0 - exp(-(6.0 if fugindo else 1.5) * delta))
		pos += _velocidades[i] * delta
		pos.y = lerpf(pos.y, _altura(0.5 + 0.5 * sin(t * 0.4 + _fases[i])), 1.0 - exp(-2.0 * delta))
		peixe.global_position = pos
		var rumo := Vector2(_velocidades[i].x, _velocidades[i].z)
		if rumo.length_squared() > 0.0004:
			# Rabeia: a cabeça balança em torno do rumo, mais rápido quando foge.
			var balanco := sin(t * (18.0 if fugindo else 9.0) + _fases[i]) * 0.18
			peixe.rotation.y = atan2(-rumo.x, -rumo.y) + balanco


func _criar(tripo: bool) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Peixe"
	if tripo and CatalogoAssets.tem_tripo("peixe"):
		# instanciar() mede pela maior dimensão; a cabeça do GLB deitado fica em -Z.
		var modelo := CatalogoAssets.instanciar("peixe", raiz, Vector3.ZERO, TAMANHO / float(CatalogoAssets.PECAS["peixe"]["largura"]))
		if modelo != null:
			modelo.position.y -= TAMANHO * 0.15
			return raiz
	var corpo := MeshInstance3D.new()
	var capsula := CapsuleMesh.new()
	capsula.radius = TAMANHO * 0.14
	capsula.height = TAMANHO * 0.8
	corpo.mesh = capsula
	corpo.rotation.x = PI * 0.5
	corpo.scale = Vector3(0.7, 1.0, 1.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("9fb2b8")
	material.metallic = 0.35
	material.roughness = 0.35
	corpo.material_override = material
	raiz.add_child(corpo)
	var rabo := MeshInstance3D.new()
	var nadadeira := PrismMesh.new()
	nadadeira.size = Vector3(TAMANHO * 0.28, TAMANHO * 0.22, 0.01)
	rabo.mesh = nadadeira
	rabo.material_override = material
	rabo.rotation = Vector3(0.0, PI * 0.5, PI * 0.5)
	rabo.position.z = TAMANHO * 0.45
	raiz.add_child(rabo)
	return raiz
