extends Node3D
## Canoas de pescador fundeadas no raso diante da vila, como na foto aérea de Bom Jesus
## dos Pobres: os GLBs de casco do catálogo (canoa, canoa_amarela, bote). Ficam onde a lâmina d'água da preamar tem de 0,8 a 2,6 m e balançam
## de leve.

const Mar = preload("res://scripts/prototipo_3d/mar.gd")
const QUANTIDADE := 7
const LAMINA_MIN_M := 0.8
const LAMINA_MAX_M := 2.6
## Faixa da costa usada (unidades a partir do píer) e distância mar adentro.
const ALCANCE_NA_COSTA := 140.0
const AFASTAMENTO_MIN := 8.0
const AFASTAMENTO_MAX := 40.0
const DISTANCIA_ENTRE_CANOAS := 7.0
const LONGE_DO_PIER := 9.0
## Quanto o casco afunda, quando a canoa não guardou o dela (`calado`).
const CALADO := 0.12
## O GLB tem quilha e leme abaixo do casco: afunda mais para a água chegar ao costado.
const CALADO_TRIPO := 0.32
## A frota do arraial mistura os três cascos do Tripo (a canoa azul e branca, a canoa
## amarela e o bote de toldo), como na praia real; a sequência evita dois botes juntos.
const FROTA := ["canoa", "canoa_amarela", "canoa", "bote", "canoa_amarela", "canoa", "bote"]
var _proximo_da_frota := 0

var _canoas: Array[Node3D] = []
var _bases: Array[Vector3] = []
var _fases: Array[float] = []
## Superfície do mar NA PREAMAR: a maré do momento entra em _process via Mare.
var _nivel_preamar := 0.0


## `costa` em unidades (XZ), `pier` e `mar_adentro` do píer, `nivel` a superfície da água.
func montar(costa: PackedVector2Array, pier: Vector3, mar_adentro: Vector3, nivel: float) -> void:
	# `nivel` chega já com a maré do momento; a base de tudo aqui é a preamar.
	_nivel_preamar = nivel - Mare.nivel_offset()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1652
	var candidatos: Array[int] = []
	for i in range(1, costa.size() - 1):
		if costa[i].distance_to(Vector2(pier.x, pier.z)) < ALCANCE_NA_COSTA:
			candidatos.append(i)
	if candidatos.is_empty():
		return
	var pier_2d := Vector2(pier.x, pier.z)
	var direcao_pier := Vector2(mar_adentro.x, mar_adentro.z).normalized()
	# Fundeadas, as canoas se alinham com a corrente: rumo comum com pouca variação.
	var rumo := atan2(direcao_pier.x, direcao_pier.y) + PI * 0.5
	var tentativas := 0
	while _canoas.size() < QUANTIDADE and tentativas < 400:
		tentativas += 1
		var i: int = candidatos[rng.randi_range(0, candidatos.size() - 1)]
		var tangente := (costa[i + 1] - costa[i - 1]).normalized()
		var normal := Vector2(-tangente.y, tangente.x)
		if normal.dot(direcao_pier) < 0.0:
			normal = -normal
		var ponto := costa[i] + normal * rng.randf_range(AFASTAMENTO_MIN, AFASTAMENTO_MAX)
		var lamina := Mar.lamina_em(ponto)
		if is_nan(lamina) or lamina < LAMINA_MIN_M or lamina > LAMINA_MAX_M:
			continue
		# Fora do caminho do píer (a faixa estreita que ele ocupa mar adentro).
		var rel := ponto - pier_2d
		if absf(rel.cross(direcao_pier)) < LONGE_DO_PIER and rel.dot(direcao_pier) > -LONGE_DO_PIER:
			continue
		var livre := true
		for outra in _bases:
			if Vector2(outra.x, outra.z).distance_to(ponto) < DISTANCIA_ENTRE_CANOAS:
				livre = false
				break
		if not livre:
			continue
		var canoa := _criar()
		if canoa == null:
			return
		canoa.rotation.y = rumo + rng.randf_range(-0.45, 0.45)
		canoa.position = Vector3(ponto.x, nivel, ponto.y)
		add_child(canoa)
		_canoas.append(canoa)
		_bases.append(canoa.position)
		_fases.append(rng.randf() * TAU)


## O BALANÇO NO PASSO DE FÍSICA: o casco é corpo (`AnimatableBody3D`), e quem
## está dentro dele anda com ele. Movido no `_process`, ele pulava entre dois
## passos de física, e o corpo de dentro levava o tranco contra o costado.
func _physics_process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var nivel := _nivel_preamar + Mare.nivel_offset()
	for i in _canoas.size():
		var canoa := _canoas[i]
		var fase := _fases[i]
		# Lâmina d'água do momento no ponto, em unidades (a batimetria fala em
		# metros na preamar); fora da grade, considera água de sobra.
		var lamina_pre := Mar.lamina_em(Vector2(_bases[i].x, _bases[i].z))
		var lamina := (LAMINA_MAX_M if is_nan(lamina_pre) else lamina_pre) / Mare.METROS_POR_UNIDADE + Mare.nivel_offset()
		var calado := float(canoa.get_meta("calado", CALADO))
		# 0 = flutuando solta; 1 = encalhada de vez (a lâmina não cobre o calado).
		var encalhe := clampf(1.0 - lamina / maxf(calado, 0.01), 0.0, 1.0)
		var flutuando_y := nivel + sin(t * 0.9 + fase) * 0.025
		# Encalhada: o fundo do casco assenta no leito (leito = nível - lâmina).
		var encalhada_y := nivel - lamina + calado
		canoa.position.y = lerpf(flutuando_y, encalhada_y, encalhe)
		# No seco a canoa tomba de leve para um lado fixo, sem balanço.
		var tombo := 0.25 if fase > PI else -0.25
		canoa.rotation.z = lerpf(sin(t * 0.7 + fase * 1.3) * 0.035, tombo, encalhe)
		canoa.rotation.x = sin(t * 0.5 + fase * 0.7) * 0.015 * (1.0 - encalhe)


func _criar() -> Node3D:
	var chave: String = FROTA[_proximo_da_frota % FROTA.size()]
	_proximo_da_frota += 1
	if not CatalogoAssets.tem_tripo(chave):
		chave = "canoa"
	var raiz := Node3D.new()
	raiz.name = "Canoa"
	# instanciar() põe a base na origem: afunda o casco até a linha d'água. Os GLBs
	# vêm com o comprimento em Z; o giro os deita no eixo X.
	var modelo := CatalogoAssets.instanciar(chave, raiz, Vector3(0, -CALADO_TRIPO, 0), 1.0, PI * 0.5)
	if modelo == null:
		push_error("Canoa sem GLB no catálogo: %s" % chave)
		raiz.free()
		return null
	raiz.add_child(_colisao_do_casco(modelo, raiz))
	# O calado decide quando a maré baixa encalha a canoa (unidades).
	raiz.set_meta("calado", CALADO_TRIPO)
	return raiz


## A COLISÃO É O PRÓPRIO CASCO: a malha dele, dos dois lados, num corpo que
## acompanha o balanço. Por fora é parede; por dentro é fundo e costado, e
## quem pula a borda fica dentro da canoa, no fundo, e não em cima.
##
## "Pulei neles e atravessei a parede." A colisão eram caixas de doze dedos,
## medidas como fração da caixa do modelo: o costado de colisão acabava abaixo
## da borda que se vê — a altura era 40% do modelo inteiro, e a proa alta conta
## no modelo —, e a proa e a popa não tinham colisão nenhuma. O pulo passava
## por cima do costado de colisão e através do costado desenhado.
##
## `teto` (altura no referencial de `raiz`): só entram os triângulos inteiros
## abaixo dele. O saveiro tem mastro, retranca e vela acima da borda, e a malha
## inteira fazia da vela uma parede a 1,76 m do convés — o jogador batia nela
## andando para a popa. Quem tem teto põe o mastro à parte
## (`SaveiroVale._montar_o_barco`).
static func _colisao_do_casco(visual: Node3D, raiz: Node3D, teto: float = INF) -> AnimatableBody3D:
	var corpo := AnimatableBody3D.new()
	corpo.add_to_group("embarcacao_piso")
	corpo.name = "Colisão da canoa"
	var malhas: Array = visual.find_children("*", "MeshInstance3D", true, false)
	if visual is MeshInstance3D:
		malhas.push_front(visual)
	for no in malhas:
		var malha := no as MeshInstance3D
		if malha.mesh == null:
			continue
		var forma: ConcavePolygonShape3D = malha.mesh.create_trimesh_shape() if is_inf(teto) else _abaixo_do_teto(malha, raiz, teto)
		if forma == null:
			continue
		# Os dois lados: o casco do Tripo e o de tábuas são cascas, e de dentro
		# o lado de fora delas é o avesso.
		forma.backface_collision = true
		var colisao := CollisionShape3D.new()
		colisao.shape = forma
		colisao.transform = _relativo(malha, raiz)
		corpo.add_child(colisao)
	return corpo


## A malha de colisão de `malha` só com os triângulos que ficam inteiros abaixo
## de `teto` (no referencial de `raiz`), ou null quando não sobra nenhum.
static func _abaixo_do_teto(malha: MeshInstance3D, raiz: Node3D, teto: float) -> ConcavePolygonShape3D:
	var para_a_raiz := _relativo(malha, raiz)
	var faces := malha.mesh.get_faces()
	var ficam := PackedVector3Array()
	for i in range(0, faces.size() - 2, 3):
		if (para_a_raiz * faces[i]).y > teto or (para_a_raiz * faces[i + 1]).y > teto or (para_a_raiz * faces[i + 2]).y > teto:
			continue
		ficam.append(faces[i])
		ficam.append(faces[i + 1])
		ficam.append(faces[i + 2])
	if ficam.is_empty():
		return null
	var forma := ConcavePolygonShape3D.new()
	forma.set_faces(ficam)
	return forma


## A transformação de `no` vista de `ate`, pela cadeia de pais: a canoa ainda
## não está no mundo quando a colisão é montada.
static func _relativo(no: Node3D, ate: Node3D) -> Transform3D:
	var transformacao := Transform3D()
	var atual: Node = no
	while atual != null and atual != ate:
		if atual is Node3D:
			transformacao = (atual as Node3D).transform * transformacao
		atual = atual.get_parent()
	return transformacao
