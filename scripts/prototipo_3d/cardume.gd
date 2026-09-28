extends Node3D
## Cardume de peixinhos no raso ao lado do píer: nadam em roda, a meia água, se
## espalham um pouco e fogem de quem chega perto (jogador ou morador). Peixe do Tripo no
## estilo Tripo; no procedural, um corpo simples de tainha.

const QUANTIDADE := 14
## Lâmina da batimetria para sumir na baixa-mar (a maré vem do autoload Mare).
const Mar = preload("res://scripts/prototipo_3d/mar.gd")
## Raio da roda em torno do centro e velocidades (unidades por segundo).
const RAIO := 4.5
const VELOCIDADE := 0.9
## Também é o teto da velocidade final: nenhum peixe dispara além disso.
const VELOCIDADE_FUGA := 2.2
const DISTANCIA_FUGA := 3.0
## Força máxima do puxão de volta ao centro: longe demais não vira estilingue.
const VOLTA_MAXIMA := 1.2
## Perigo quase em cima: a direção de fuga fica travada por um tempo para não saltar.
const PERTO_DEMAIS := 0.5
const TRAVA_FUGA := 0.8
## Só atualiza o rumo acima desta velocidade (u/s), senão o peixe roda no lugar.
const RUMO_MINIMO := 0.1
## Tamanho do peixe (maior dimensão, unidades) e quanto ele nada abaixo da superfície.
const TAMANHO := 0.38
const MEIA_AGUA := 0.45

var _peixes: Array[Node3D] = []
var _velocidades: Array[Vector3] = []
var _fases: Array[float] = []
## Rumo suavizado de cada peixe e a direção/prazo da fuga travada.
var _rumos: Array[float] = []
var _fuga_direcoes: Array[Vector3] = []
var _fuga_travas: Array[float] = []
var _centro := Vector3.ZERO
var _nivel := 0.0
var _fundo := 0.5


## `centro` no nível da água; `fundo` é a lâmina d'água ali, em unidades.
func montar(centro: Vector3, nivel: float, fundo: float, tripo: bool) -> void:
	_centro = centro
	# `nivel` chega com a maré do momento; a base é a preamar (a maré volta em _altura).
	_nivel = nivel - Mare.nivel_offset()
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
		var vel := Vector3(-sin(angulo), 0.0, cos(angulo)) * VELOCIDADE
		_velocidades.append(vel)
		_fases.append(rng.randf() * TAU)
		_rumos.append(atan2(-vel.x, -vel.z))
		_fuga_direcoes.append(Vector3.ZERO)
		_fuga_travas.append(0.0)
		peixe.rotation.y = _rumos[i]


func _altura(t: float) -> float:
	return _nivel + Mare.nivel_offset() - clampf(_fundo * lerpf(0.3, 0.7, t), 0.08, MEIA_AGUA)


func _physics_process(delta: float) -> void:
	if _peixes.is_empty():
		return
	# Baixa-mar: com menos de 0,3 u de lâmina no centro, o cardume some no fundo.
	var lamina_pre := Mar.lamina_em(Vector2(_centro.x, _centro.z))
	var lamina := (_fundo if is_nan(lamina_pre) else lamina_pre / Mare.METROS_POR_UNIDADE) + Mare.nivel_offset()
	if lamina < 0.3:
		visible = false
		return
	visible = true
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
		var dist := rel.length()
		# Roda em volta do centro, puxada de volta quando se afasta, com um vaivém próprio.
		var roda := Vector3(-rel.z, 0.0, rel.x).normalized() * VELOCIDADE
		var volta := Vector3.ZERO
		if dist > RAIO:
			# Puxão limitado: antes crescia com a distância e lançava o peixe em disparada.
			volta = (-rel / dist) * minf((dist - RAIO) * 0.6, VOLTA_MAXIMA)
		var vaivem := Vector3(sin(t * 0.7 + _fases[i]), 0.0, cos(t * 0.9 + _fases[i] * 1.3)) * 0.35
		var desejada := roda + volta + vaivem
		# Perigo mais próximo dentro do alcance de fuga (o mais perto manda na direção).
		var mais_perto := INF
		var afasta := Vector3.ZERO
		for perigo in perigos:
			var longe := Vector3(pos.x - perigo.x, 0.0, pos.z - perigo.z)
			var d := longe.length()
			if d < DISTANCIA_FUGA and d < mais_perto:
				mais_perto = d
				afasta = longe
		var fugindo := mais_perto < DISTANCIA_FUGA
		if fugindo:
			var direcao := _fuga_direcoes[i]
			if t >= _fuga_travas[i]:
				# Recalcula fora da trava; com o perigo quase em cima, guarda a direção
				# por um tempo em vez de inverter a cada quadro (o rumo saltava).
				if afasta.length_squared() > 0.000001:
					direcao = afasta / mais_perto
				elif direcao == Vector3.ZERO:
					direcao = Vector3(cos(_fases[i]), 0.0, sin(_fases[i]))
				_fuga_direcoes[i] = direcao
				if mais_perto < PERTO_DEMAIS:
					_fuga_travas[i] = t + TRAVA_FUGA
			if direcao == Vector3.ZERO:
				direcao = Vector3(cos(_fases[i]), 0.0, sin(_fases[i]))
			desejada = direcao * VELOCIDADE_FUGA
		_velocidades[i] = _velocidades[i].lerp(desejada, 1.0 - exp(-(6.0 if fugindo else 1.5) * delta))
		# Teto absoluto: fuga somada a qualquer outra força nunca passa disso.
		_velocidades[i] = _velocidades[i].limit_length(VELOCIDADE_FUGA)
		pos += _velocidades[i] * delta
		pos.y = lerpf(pos.y, _altura(0.5 + 0.5 * sin(t * 0.4 + _fases[i])), 1.0 - exp(-2.0 * delta))
		peixe.global_position = pos
		var rumo := Vector2(_velocidades[i].x, _velocidades[i].z)
		if rumo.length_squared() > RUMO_MINIMO * RUMO_MINIMO:
			# Rumo suavizado com lerp_angle: sem os saltos do atan2, o peixe não gira no lugar.
			_rumos[i] = lerp_angle(_rumos[i], atan2(-rumo.x, -rumo.y), 1.0 - exp(-(8.0 if fugindo else 4.0) * delta))
		# Rabeia: a cabeça balança em torno do rumo, mais rápido quando foge.
		var balanco := sin(t * (14.0 if fugindo else 9.0) + _fases[i]) * 0.15
		peixe.rotation.y = _rumos[i] + balanco


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
