extends Node3D
## A MALHA DE NAVEGAÇÃO DOS MORADORES — o caminho de verdade, e não a linha reta.
##
## O morador andava em linha reta até o posto, com um desvio local quando batia
## (`npc.gd`, `_contornar_bloqueio`): "decisão local não vê o mapa inteiro". Com
## a festa de cada fé o caminho ficou longo — do píer à gameleira, da casa da
## estrada ao cruzeiro, passando por casa, cerca e mata —, e "andar o caminho
## inteiro pede navegação de verdade". É esta.
##
## A MALHA SE ASSA AO MONTAR O VALE, e não sai pronta do disco: o vale é feito em
## tempo de execução, nos dois estilos, e uma malha guardada envelheceria a cada
## árvore mudada de lugar. Assar é barato (medido em 03/10/2026: uns 50 ms para
## ler o vale e 1,7 s para assar a área dos moradores, 7.000 polígonos), e ainda
## assim vai numa linha de execução à parte: enquanto a malha não fica pronta, o
## morador anda reto, como antes.
##
## O QUE ENTRA: o chão e o que tem colisão no vale — casas, cômodos por dentro
## (com a porta e as rampas), cercas, pedras —, e os troncos da mata como
## obstáculos, tirados da lista da mata e não das colisões: a colisão dos troncos
## é um punhado de cilindros que acompanha o jogador, e longe dele não há tronco
## nenhum para a malha ver.
##
## O QUE SAI: o FUNDO DO MAR, que tem colisão para o corpo andar no raso, mas
## que morador não atravessa — fica só o que está acima da preamar, o que mantém
## o píer e a ponte —; o LEITO DOS RIOS, pelo mesmo motivo (ver `_leito_dos_rios`);
## e as ILHAS: assada das colisões, a malha punha chão no
## telhado de cada casa e no tampo de cada caixote, e o ponto mais perto de quem
## está junto de uma casa podia cair lá em cima, num pedaço sem saída. Fica só o
## pedaço ligado maior, o chão do vale.
##
## E SE ASSA DE NOVO QUANDO O VALE MUDA: obra que levanta parede no caminho — o
## cercado do cemitério (`cemiterio_vale.gd`) — pede `reassar()`. A malha velha
## vale até a nova entrar no mapa, e quem pede durante uma assada ganha outra
## logo depois, com o que mudou nesse meio tempo.

signal pronta

## O tamanho da célula da malha e da sola do morador. O RAIO É CURTO POR CAUSA
## DA PORTA: o Recast arredonda o raio para células inteiras, e a parede que não
## cai na beira de uma célula ainda come mais uma. Com 0,3 de raio a porta da
## igreja (1,2) fechava — com célula de 0,3, de 0,2 e de 0,15 —; com 0,2 a
## erosão é de uma célula, e passam as portas e o corredor entre os bancos. O
## corpo do morador (0,26) é um pouco mais largo: quem o segura na quina é a
## colisão, e o morador não corta a quina (`npc.gd`, `PONTO_ALCANCADO`).
const CELULA := 0.2
const ALTURA_DA_CELULA := 0.2
const RAIO := 0.2
const ALTURA := 1.6
const DEGRAU := 0.4
const RAMPA := 40.0
## A folga em volta da área dos postos e dos marcos.
const FOLGA := 20.0
## As âncoras por onde os moradores andam: os postos e os marcos da festa.
const LUGARES := ["Praça", "Igreja", "Cruzeiro", "PierPiso", "Casa de taipa", "Lavoura", "Terreiro",
	"Gameleira", "Cemitério", "Bar", "Restaurante", "Casa da estrada", "Casa de Carro Quebrado", "Poço"]

var _mundo
var _raiz: Node
var _regiao: NavigationRegion3D
var _pronta := false
var _malha: NavigationMesh
var _agua := -INF
var _sonda := Vector3.INF
var _assando := false
var _de_novo := false
## Quantas malhas já entraram no mapa: a primeira, e uma a cada `reassar`.
var versao := 0


## `raiz` é de onde se lê o que tem colisão: o vale inteiro, e não só o mundo
## — os cômodos (paredes, porta, rampas) moram no nó dos interiores.
func configurar(mundo, raiz: Node) -> void:
	_mundo = mundo
	_raiz = raiz
	add_to_group("navegacao")
	var area := _area()
	if not area.has_volume():
		return
	_agua = float(mundo.water_level()) if mundo.has_method("water_level") else -INF
	_sonda = mundo.ancoras.get("Praça", Vector3.INF)
	_malha = NavigationMesh.new()
	_malha.cell_size = CELULA
	_malha.cell_height = ALTURA_DA_CELULA
	_malha.agent_radius = RAIO
	_malha.agent_height = ALTURA
	_malha.agent_max_climb = DEGRAU
	_malha.agent_max_slope = RAMPA
	_malha.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	_malha.geometry_collision_mask = 1
	_malha.filter_baking_aabb = area
	var mapa: RID = get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(mapa, CELULA)
	NavigationServer3D.map_set_cell_height(mapa, ALTURA_DA_CELULA)
	_assar()


## O VALE MUDOU: assa de novo. Durante uma assada, fica pedida a próxima.
func reassar() -> void:
	if _malha == null:
		return
	if _assando:
		_de_novo = true
		return
	_assar()


func _assar() -> void:
	_assando = true
	# Ler o vale é coisa da linha principal; assar, da outra.
	var fonte := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(_malha, fonte, _raiz)
	_troncos_da_mata(fonte, _malha.filter_baking_aabb)
	_leito_dos_rios(fonte, _malha.filter_baking_aabb)
	NavigationServer3D.bake_from_source_geometry_data_async(_malha, fonte, _ao_assar)


func esta_pronta() -> bool:
	return _pronta


## O caminho de `de` até `para` pela malha, ou vazio sem malha.
func caminho(de: Vector3, para: Vector3) -> PackedVector3Array:
	if not _pronta:
		return PackedVector3Array()
	return NavigationServer3D.map_get_path(get_world_3d().navigation_map, de, para, true)


## A área por onde os moradores andam, com folga, do fundo da água para cima.
func _area() -> AABB:
	var ancoras: Dictionary = _mundo.ancoras
	var caixa := AABB()
	var primeiro := true
	for nome in LUGARES:
		if not ancoras.has(nome):
			continue
		var ponto: Vector3 = ancoras[nome]
		if primeiro:
			caixa = AABB(ponto, Vector3.ZERO)
			primeiro = false
		else:
			caixa = caixa.expand(ponto)
	if primeiro:
		return AABB()
	caixa = caixa.grow(FOLGA)
	var agua := float(_mundo.water_level()) if _mundo.has_method("water_level") else caixa.position.y
	caixa.position.y = (agua if is_finite(agua) else caixa.position.y) - 3.0
	caixa.size.y = 80.0
	return caixa


## ONDE O TRONCO TOCA O CHÃO. Quase sempre é o ponto de plantio; o COQUEIRO DA
## ORLA, que pende para o mar, tem a base visível deslocada dele
## (`geo_region_renderer`, "base_tronco") — é ali que a colisão fica. O
## obstáculo no ponto de plantio deixava o caminho do píer à gameleira cortar
## por dentro do coqueiro.
static func tronco_no_chao(tronco: Dictionary) -> Vector2:
	var base = tronco.get("base_tronco", null)
	if base is Vector3:
		return Vector2((base as Vector3).x, (base as Vector3).z)
	return tronco.get("point", Vector2.INF)


## O RAIO DO TRONCO NO CHÃO: o da base visível do coqueiro, mais uma célula da
## malha — o Recast desenha o buraco em células de CELULA e simplifica a borda,
## e um tronco fino de base larga sobrava por dentro do caminho.
static func raio_no_chao(tronco: Dictionary) -> float:
	if tronco.has("raio_base"):
		return float(tronco["raio_base"]) + CELULA
	return float(tronco.get("radius", 0.3))


## OS TRONCOS DA MATA como obstáculos: um octógono no pé de cada um, do chão a
## quatro metros.
func _troncos_da_mata(fonte: NavigationMeshSourceGeometryData3D, area: AABB) -> void:
	var regiao = _mundo.get("_region")
	if regiao == null:
		return
	for tronco in regiao._tree_trunks:
		var ponto: Vector2 = tronco_no_chao(tronco)
		if not ponto.is_finite() or not area.has_point(Vector3(ponto.x, area.position.y + 1.0, ponto.y)):
			continue
		# O octógono POR FORA do tronco: com o raio nos vértices ele ficava por
		# dentro do círculo, e o caminho raspava no tronco pelo meio das arestas.
		var raio := maxf(raio_no_chao(tronco), 0.2) / cos(PI / 8.0)
		var contorno := PackedVector3Array()
		for k in 8:
			var angulo := TAU * float(k) / 8.0
			contorno.append(Vector3(ponto.x + cos(angulo) * raio, 0.0, ponto.y + sin(angulo) * raio))
		# O PÉ DO TRONCO é o chão do vale ali, e não o "ground" da lista, que nem
		# todo tronco traz: sem ele o octógono ficava embaixo da terra.
		var pe: float = _mundo.ground_height_at(Vector3(ponto.x, 0.0, ponto.y))
		fonte.add_projected_obstruction(contorno, pe - 1.0, 5.0, true)


## O LEITO DOS RIOS como obstáculo: um quadrilátero por trecho da linha do rio,
## da largura da água e um palmo de margem, do fundo até um pouco acima da lâmina.
##
## "Quando Pedro chama o jogador para ir a casa de Dona Zefa na primeira missão,
## faça eles irem atravessando a ponte." O rio central é raso de dar pé, e o
## leito tem colisão — o corpo do jogador anda nele —, então a malha o tinha como
## chão: da praça à Dona Zefa o caminho mais curto molhava o pé a sete unidades
## da ponte, e o Pedro, que vai na frente pela malha, entrava no rio. Morador
## atravessa rio pela ponte, como atravessa o mar pelo píer.
##
## A PONTE FICA porque o obstáculo é PROJETADO até uma altura: o Recast só marca
## o chão que cai entre o fundo e a lâmina d'água mais a folga, e o tabuleiro da
## ponte passa por cima disso.
const MARGEM_DO_RIO := 0.3
const ACIMA_DA_AGUA := 0.3

func _leito_dos_rios(fonte: NavigationMeshSourceGeometryData3D, area: AABB) -> void:
	var regiao = _mundo.get("_region")
	if regiao == null:
		return
	var caixa := Rect2(area.position.x, area.position.z, area.size.x, area.size.z)
	for rio in regiao._rivers:
		if not (rio.bounds as Rect2).intersects(caixa):
			continue
		var pontos: PackedVector2Array = rio.points
		var meia := float(rio.width) * 0.5 + MARGEM_DO_RIO
		for i in range(pontos.size() - 1):
			var a: Vector2 = pontos[i]
			var b: Vector2 = pontos[i + 1]
			if not caixa.grow(meia).has_point(a) and not caixa.grow(meia).has_point(b):
				continue
			var ao_longo := b - a
			if ao_longo.length() < 0.01:
				continue
			ao_longo = ao_longo.normalized()
			# Um pouco além das pontas do trecho, para as juntas das curvas não
			# deixarem fresta de chão no meio da água.
			var a2 := a - ao_longo * meia * 0.5
			var b2 := b + ao_longo * meia * 0.5
			var lado := Vector2(-ao_longo.y, ao_longo.x) * meia
			var contorno := PackedVector3Array([
				Vector3(a2.x + lado.x, 0.0, a2.y + lado.y), Vector3(b2.x + lado.x, 0.0, b2.y + lado.y),
				Vector3(b2.x - lado.x, 0.0, b2.y - lado.y), Vector3(a2.x - lado.x, 0.0, a2.y - lado.y)])
			var fundo := minf(_mundo.ground_height_at(Vector3(a.x, 0.0, a.y)), _mundo.ground_height_at(Vector3(b.x, 0.0, b.y)))
			var lamina := maxf(regiao.river_water_level_at(Vector3(a.x, 0.0, a.y)), regiao.river_water_level_at(Vector3(b.x, 0.0, b.y)))
			if not is_finite(lamina):
				continue
			fonte.add_projected_obstruction(contorno, fundo - 1.0, lamina + ACIMA_DA_AGUA - (fundo - 1.0), true)


## ASSADA: fora o fundo do mar e as ilhas, e a malha entra no vale.
func _ao_assar() -> void:
	var vertices := _malha.get_vertices()
	var secos: Array[int] = []
	for i in _malha.get_polygon_count():
		var poligono := _malha.get_polygon(i)
		var meio := Vector3.ZERO
		for indice in poligono:
			meio += vertices[indice]
		meio /= float(poligono.size())
		if is_finite(_agua) and meio.y < _agua + 0.05:
			continue
		secos.append(i)
	var chao := NavigationMesh.new()
	chao.cell_size = _malha.cell_size
	chao.cell_height = _malha.cell_height
	chao.agent_radius = _malha.agent_radius
	chao.agent_height = _malha.agent_height
	chao.agent_max_climb = _malha.agent_max_climb
	chao.agent_max_slope = _malha.agent_max_slope
	chao.set_vertices(vertices)
	for i in _o_pedaco_maior(secos):
		chao.add_polygon(_malha.get_polygon(i))
	var mapa: RID = get_world_3d().navigation_map
	var iteracao := NavigationServer3D.map_get_iteration_id(mapa)
	if _regiao == null:
		_regiao = NavigationRegion3D.new()
		_regiao.name = "MalhaDosMoradores"
		_regiao.navigation_mesh = chao
		add_child(_regiao)
	else:
		_regiao.navigation_mesh = chao
	# O MAPA SÓ VÊ A REGIÃO depois de sincronizar, e isso leva alguns quadros de
	# física (medido: seis não bastavam). Pronta é quando ele responde de fato —
	# e, ao assar de novo, quando a malha que entrou é a nova.
	for i in 600:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(mapa) == iteracao:
			continue
		var perto := NavigationServer3D.map_get_closest_point(mapa, _sonda) if _sonda.is_finite() else Vector3.ZERO
		if perto != Vector3.ZERO:
			break
	_pronta = true
	versao += 1
	_assando = false
	pronta.emit()
	if _de_novo:
		_de_novo = false
		_assar()


## O PEDAÇO LIGADO MAIOR: os polígonos que se tocam por aresta formam pedaços;
## fica o maior — o chão do vale —, e saem os telhados e os tampos.
func _o_pedaco_maior(poligonos: Array[int]) -> Array[int]:
	var por_aresta := {}
	for i in poligonos:
		var p := _malha.get_polygon(i)
		for k in p.size():
			var aresta := Vector2i(mini(p[k], p[(k + 1) % p.size()]), maxi(p[k], p[(k + 1) % p.size()]))
			if not por_aresta.has(aresta):
				por_aresta[aresta] = []
			(por_aresta[aresta] as Array).append(i)
	var pedaco := {}
	var tamanhos: Array[int] = []
	for i in poligonos:
		if pedaco.has(i):
			continue
		var qual := tamanhos.size()
		var fila: Array[int] = [i]
		pedaco[i] = qual
		var quantos := 0
		while not fila.is_empty():
			var atual: int = fila.pop_back()
			quantos += 1
			var p := _malha.get_polygon(atual)
			for k in p.size():
				var aresta := Vector2i(mini(p[k], p[(k + 1) % p.size()]), maxi(p[k], p[(k + 1) % p.size()]))
				for vizinho in por_aresta[aresta]:
					if not pedaco.has(vizinho):
						pedaco[vizinho] = qual
						fila.append(vizinho)
		tamanhos.append(quantos)
	if tamanhos.is_empty():
		return poligonos
	var maior := tamanhos.find(tamanhos.max())
	var ficam: Array[int] = []
	for i in poligonos:
		if pedaco[i] == maior:
			ficam.append(i)
	return ficam
