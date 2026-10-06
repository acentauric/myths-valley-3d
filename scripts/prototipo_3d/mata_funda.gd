extends RefCounted
## ONDE FICA "BEM DENTRO DA MATA" — o lugar dos dois sustos (o vulto, o rastro do Curupira).
##
## `WorldBuilder.na_mata_fechada` é só o polígono pequeno do KML (62 mil m², a uns 160 u da
## praça): serve para a música de tensão, e não para dizer "isto é o fundo da mata". A mata de
## verdade é quase toda a terra firme do oeste; o fundo dela é o que sobra quando se tira o que
## tem gente: a vila, as ruas, os pontos do mapa, as clareiras (e as trilhas até elas), a costa,
## o rio — e o que tem pouco tronco, que é descampado, e não mata.
##
## Sem estado: cada pergunta vai direto à região (`world._region`), como a `criatura_vale.gd` já
## faz com a grade de troncos. Sem `class_name`: quem usa carrega com `preload`.

## Folgas, em unidades do mundo (1 u = 4 m no mapa; o personagem tem 1,78 u).
const DA_RUA := 24.0
const DA_VILA := 30.0
const DOS_PONTOS := 28.0
const DA_CLAREIRA := 14.0
const DA_AREA_ABERTA := 20.0
const DA_COSTA := 30.0
const DO_RIO := 14.0
## A densidade de troncos: quantos em volta (raio em u). O mínimo vem da medida da mata que ficou
## depois de "mata pela metade": nos 3.400 pontos de terra sem outro defeito a mediana é de 20
## troncos em 20 u, o percentil 5 é 11 e o menor é 3. Com 12, só o descampado reprova.
const RAIO_DA_DENSIDADE := 20.0
const TRONCOS_MINIMOS := 12
## Altura dos olhos e do peito de quem é visto ou vê (u), para a linha livre.
const ALTURA_DOS_OLHOS := 1.7
const ALTURA_DO_PEITO := 1.2


## Por que o ponto NÃO é mata funda ("" quando é). O motivo é o que o portão e o log leem.
static func porque_nao(world: Object, posicao: Vector3) -> String:
	var regiao = world.get("_region") if world != null else null
	if regiao == null:
		return "sem_regiao"
	var ponto := Vector2(posicao.x, posicao.z)
	if not world.is_on_land(posicao):
		return "fora_da_terra"
	# `water_depth_at` não serve em terra: a lâmina do mar lá é um resto constante (0,07 u em todo
	# chão), então a pergunta é se o chão está acima da água de verdade (o mar com a maré, ou o rio).
	if world.ground_height_at(posicao) < world.water_level_at(posicao) + 0.5 or float(regiao.river_water_depth_at(posicao)) > 0.0:
		return "na_agua"
	var vila: PackedVector2Array = regiao._village
	if vila.size() >= 3:
		if Geometry2D.is_point_in_polygon(ponto, vila):
			return "na_vila"
		if _distancia_ao_contorno(ponto, vila) < DA_VILA:
			return "perto_da_vila"
	if _distancia_as_ruas(regiao, ponto, DA_RUA) < DA_RUA:
		return "perto_da_rua"
	if regiao._em_clareira(ponto):
		return "na_clareira"
	for destaque: Dictionary in regiao.clareiras_da_mata:
		if ponto.distance_to(destaque["centro"]) < float(destaque["raio"]) + DA_CLAREIRA:
			return "perto_da_clareira"
	for clareira: Vector2 in regiao.clareiras:
		if ponto.distance_to(clareira) < regiao.RAIO_DAS_CLAREIRAS + DA_CLAREIRA:
			return "perto_da_clareira"
	for area: PackedVector2Array in regiao._open_areas:
		if area.size() >= 3 and (Geometry2D.is_point_in_polygon(ponto, area) or _distancia_ao_contorno(ponto, area) < DA_AREA_ABERTA):
			return "perto_de_area_aberta"
	for lugar: Vector2 in _lugares(world):
		if ponto.distance_to(lugar) < DOS_PONTOS:
			return "perto_de_lugar"
	if regiao._coast.size() >= 2 and regiao._distance_to_line(ponto, regiao._coast) < DA_COSTA:
		return "perto_da_costa"
	if regiao._near_river(ponto, DO_RIO):
		return "perto_do_rio"
	if troncos_em_volta(world, posicao) < TRONCOS_MINIMOS:
		return "mata_rala"
	return ""


static func e_funda(world: Object, posicao: Vector3) -> bool:
	return porque_nao(world, posicao) == ""


## Troncos de pé a menos de `raio` do ponto, pela grade de troncos da região (células de 8 u).
static func troncos_em_volta(world: Object, posicao: Vector3, raio: float = RAIO_DA_DENSIDADE) -> int:
	var regiao = world.get("_region") if world != null else null
	if regiao == null:
		return 0
	regiao._garantir_grade_troncos()
	var ponto := Vector2(posicao.x, posicao.z)
	var celula: float = regiao.CELULA_TRONCOS
	var grade: Dictionary = regiao._grade_troncos
	var quantos := 0
	for cx in range(floori((ponto.x - raio) / celula), floori((ponto.x + raio) / celula) + 1):
		for cy in range(floori((ponto.y - raio) / celula), floori((ponto.y + raio) / celula) + 1):
			for i: int in grade.get(Vector2i(cx, cy), []):
				var tronco: Dictionary = regiao._tree_trunks[i]
				if bool(tronco.get("cortado", false)):
					continue
				if (tronco["point"] as Vector2).distance_squared_to(ponto) <= raio * raio:
					quantos += 1
	return quantos


## O tronco mais perto do ponto: {"distancia": u (do eixo, já sem o raio), "ponto": Vector2}, ou
## distância INF sem tronco numa vizinhança de 3 células. Para os pés do rastro não caírem num tronco.
static func tronco_mais_perto(world: Object, ponto: Vector2) -> Dictionary:
	var regiao = world.get("_region") if world != null else null
	var melhor := {"distancia": INF, "ponto": Vector2.ZERO}
	if regiao == null:
		return melhor
	regiao._garantir_grade_troncos()
	var celula: float = regiao.CELULA_TRONCOS
	var base := Vector2i(floori(ponto.x / celula), floori(ponto.y / celula))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for i: int in regiao._grade_troncos.get(base + Vector2i(dx, dy), []):
				var tronco: Dictionary = regiao._tree_trunks[i]
				if bool(tronco.get("cortado", false)):
					continue
				var d: float = (tronco["point"] as Vector2).distance_to(ponto) - float(tronco["radius"])
				if d < float(melhor["distancia"]):
					melhor = {"distancia": d, "ponto": tronco["point"]}
	return melhor


## A LINHA LIVRE entre dois pontos: um raio na camada 1 (chão, pedra, casa e os troncos que têm
## colisão perto do jogador) e, só lendo, a grade de troncos da região — longe do jogador a mata
## tem só um punhado de colisões de tronco, e o vulto fica longe. `excluir` tira o corpo de quem olha.
static func linha_livre(no: Node3D, world: Object, de: Vector3, ate: Vector3, excluir: Array = []) -> bool:
	if no != null and no.is_inside_tree():
		var pergunta := PhysicsRayQueryParameters3D.create(de, ate, 1)
		# `Array` solto, e não `Array[RID]`: quem chama de fora de um script tipado (um portão) manda lista sem tipo.
		var fora: Array[RID] = []
		for corpo: Variant in excluir:
			fora.append(corpo)
		pergunta.exclude = fora
		if not no.get_world_3d().direct_space_state.intersect_ray(pergunta).is_empty():
			return false
	return not _tronco_no_caminho(world, de, ate)


static func _tronco_no_caminho(world: Object, de: Vector3, ate: Vector3) -> bool:
	var regiao = world.get("_region") if world != null else null
	if regiao == null:
		return false
	regiao._garantir_grade_troncos()
	var a := Vector2(de.x, de.z)
	var b := Vector2(ate.x, ate.z)
	var celula: float = regiao.CELULA_TRONCOS
	for cx in range(floori((minf(a.x, b.x) - 1.0) / celula), floori((maxf(a.x, b.x) + 1.0) / celula) + 1):
		for cy in range(floori((minf(a.y, b.y) - 1.0) / celula), floori((maxf(a.y, b.y) + 1.0) / celula) + 1):
			for i: int in regiao._grade_troncos.get(Vector2i(cx, cy), []):
				var tronco: Dictionary = regiao._tree_trunks[i]
				if bool(tronco.get("cortado", false)):
					continue
				var pe: Vector2 = tronco["point"]
				# O pé de quem olha e o de quem é olhado não tapam a vista.
				if pe.distance_to(a) < 0.5 or pe.distance_to(b) < 0.5:
					continue
				if Geometry2D.get_closest_point_to_segment(pe, a, b).distance_to(pe) < float(tronco["radius"]):
					return true
	return false


## Os pontos do mapa, as âncoras e as áreas com dono (menos a "Mata" do KML, que é mata): o que a
## mata funda precisa ficar longe. "…Frente" é direção, e não lugar.
static func _lugares(world: Object) -> Array[Vector2]:
	var lista: Array[Vector2] = []
	for nome: Variant in world.ancoras:
		if String(nome).ends_with("Frente"):
			continue
		var onde: Variant = world.ancoras[nome]
		if onde is Vector3:
			lista.append(Vector2(onde.x, onde.z))
	for marco: Dictionary in world.landmarks:
		var onde_marco: Vector3 = marco["position"]
		lista.append(Vector2(onde_marco.x, onde_marco.z))
	for area: Dictionary in world.areas:
		if String(area.get("name", "")) == "Mata":
			continue
		var onde_area: Vector3 = area["position"]
		lista.append(Vector2(onde_area.x, onde_area.z))
	return lista


static func _distancia_as_ruas(regiao: Object, ponto: Vector2, limite: float) -> float:
	var menor := INF
	for rua: Dictionary in regiao._roads:
		var caixa: Rect2 = rua["bounds"]
		if not caixa.grow(limite).has_point(ponto):
			continue
		menor = minf(menor, regiao._distance_to_line(ponto, rua["points"]) - float(rua["width"]) * 0.5)
	return menor


static func _distancia_ao_contorno(ponto: Vector2, poligono: PackedVector2Array) -> float:
	var menor := INF
	for i in range(poligono.size()):
		var proximo := poligono[(i + 1) % poligono.size()]
		menor = minf(menor, Geometry2D.get_closest_point_to_segment(ponto, poligono[i], proximo).distance_to(ponto))
	return menor
