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
##
## A PRIMEIRA ASSADA ESPERA O `_ready` DO VALE ACABAR (`_primeira_assada`): a malha era
## assada no meio dele, antes de o saveiro, o cercado da ponte e o resto nascerem, e a
## segunda assada que as obras da ponte pediam era um acaso — entre uma e outra a malha
## já estava "pronta" e não conhecia o barco atracado, que o morador (o Pedro, na ponta
## da prancha, no primeiro minuto do jogo) atravessava. Uma assada só, com tudo.
##
## O CASCO DO SAVEIRO ATRACADO é obstáculo declarado (`_casco_do_saveiro`), e não o que a
## malha acha do triângulo dele: o convés do casco virava chão ligado ao píer pela
## prancha, e o contorno simplificado da malha raspava a quina do barco.

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
	"Gameleira", "Cemitério", "Bar", "Restaurante", "Casa da estrada", "Casa de Carro Quebrado", "Poço",
	# As casas dos moradores novos e os lugares da jornada deles.
	"Casa do arraial 1", "Casa do arraial 4", "Casa do arraial 7", "Casa do guarda", "Casa do pescador",
	"Casa da marisqueira", "Casa da lavadeira", "Casa da rendeira", "Casa da quituteira", "Casa do carpinteiro",
	"Casa de farinha", "Rio 2", "Ponte do rio central",
	# O convite conduz além da área dos postos do arraial. Sem estas âncoras,
	# a malha projetava o Pedro de volta para a borda sul antes do portão.
	"Portão da fazenda", "Pátio da fazenda", "Casarão"]

var _mundo
var _raiz: Node
var _regiao: NavigationRegion3D
var _pronta := false
var _malha: NavigationMesh
var _agua := -INF
var _sonda := Vector3.INF
var _assando := false
var _de_novo := false
## Verdadeiro entre `configurar` e a primeira assada, que espera o `_ready` do vale
## acabar: quem pede `reassar()` nesse intervalo não precisa de assada própria.
var _adiada := false
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
	_agua = _nivel_da_preamar()
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
	# Adiada: o `_ready` do vale ainda cria o saveiro, o cercado da ponte e o cemitério.
	_adiada = true
	_primeira_assada.call_deferred()


## O MAR NA PREAMAR, e não o do instante. A malha se assa uma vez e o mar sobe e desce (a maré vem ligada): assada
## com a água do instante, na baixa-mar ela guardava a faixa de areia que a cheia cobre, e na cheia o Pedro e
## os moradores seguiam um caminho que entra no mar. Com o nível da preamar a malha é só do chão que nunca molha,
## seja a hora em que o vale se monta — `tests/navegacao.gd` monta o vale na baixa-mar e confere.
func _nivel_da_preamar() -> float:
	var regiao = _mundo.get("_region")
	if regiao != null and regiao.has_method("water_level"):
		var nivel := float(regiao.water_level())
		if is_finite(nivel):
			return nivel
	return float(_mundo.water_level()) if _mundo.has_method("water_level") else -INF


## A primeira assada, depois de o `_ready` que chamou `configurar` terminar de montar o vale.
func _primeira_assada() -> void:
	_adiada = false
	_assar()


## O VALE MUDOU: assa de novo. Durante uma assada, fica pedida a próxima.
func reassar() -> void:
	if _malha == null or _adiada:
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
	_casco_do_saveiro(fonte)
	_alicerces(fonte)
	_corrimaos_das_pontes(fonte)
	_obstaculos_das_pontes(fonte)
	NavigationServer3D.bake_from_source_geometry_data_async(_malha, fonte, _ao_assar)


## O tabuleiro fica livre; a pegada dos corrimãos não vira piso nem atalho
## pela quina. O raio da malha dá a folga física ao lado da madeira.
func _obstaculos_das_pontes(fonte: NavigationMeshSourceGeometryData3D) -> void:
	for ponte in _mundo.pontes.values():
		var modelo: Node3D = (ponte.get("modelos", {}) as Dictionary).get("de_pe")
		if modelo == null or not modelo.visible or not modelo.has_meta("piso_do_tabuleiro"):
			continue
		var centro: Vector3 = ponte.centro
		var eixo: Vector3 = ponte.ao_longo
		var lado := Vector3(-eixo.z, 0, eixo.x)
		var fator := float(ponte.comprimento) / 9.0
		var piso := float(modelo.get_meta("piso_do_tabuleiro"))
		for sinal: float in [-1.0, 1.0]:
			var contorno := PackedVector3Array()
			for canto in [Vector2(-4.5, 0.5), Vector2(4.5, 0.5), Vector2(4.5, 1.1), Vector2(-4.5, 1.1)]:
				contorno.append(centro + (eixo * canto.x + lado * canto.y * sinal) * fator)
			fonte.add_projected_obstruction(contorno, piso - 0.2, ALTURA + 0.4, false)


## O corrimão importado não é piso. Remover suas faces da fonte evita
## que a simplificação ligue um caminho sobre ele ao tabuleiro. A geometria
## de colisão e o modelo permanecem completos; somente a leitura da malha muda.
func _corrimaos_das_pontes(fonte: NavigationMeshSourceGeometryData3D) -> void:
	var vertices := fonte.get_vertices()
	var indices := fonte.get_indices()
	var filtrados := PackedInt32Array()
	for i in range(0, indices.size(), 3):
		var meio := Vector3.ZERO
		var alto := -INF
		for j in 3:
			var v := indices[i + j] * 3
			meio += Vector3(vertices[v], vertices[v + 1], vertices[v + 2]) / 3.0
			alto = maxf(alto, vertices[v + 1])
		var corrimao := false
		for ponte in _mundo.pontes.values():
			var centro: Vector3 = ponte.centro
			var modelo: Node3D = (ponte.get("modelos", {}) as Dictionary).get("de_pe")
			var piso := float(modelo.get_meta("piso_do_tabuleiro", centro.y + 0.31)) if modelo != null else centro.y + 0.31
			var eixo: Vector3 = ponte.ao_longo
			var lado := Vector3(-eixo.z, 0, eixo.x)
			var relativo := meio - centro
			if alto > piso + 0.09 and absf(relativo.dot(eixo)) < float(ponte.comprimento) * 0.5 + 0.3 and absf(relativo.dot(lado)) < float(ponte.largura) * 0.5 + 0.3:
				corrimao = true
				break
		if not corrimao:
			filtrados.append_array(indices.slice(i, i + 3))
	fonte.set_indices(filtrados)


## O CASCO DO SAVEIRO ATRACADO como obstáculo: o retângulo dele (`SaveiroVale.pegada_do_casco`),
## do fundo da quilha até além da borda. SEM "carve", como os troncos: o buraco cresce do raio
## do agente, e o caminho não raspa o casco. O mesmo obstáculo come o convés e o pedaço da
## prancha que ficam dentro dele. Barco fora do píer: nada.
func _casco_do_saveiro(fonte: NavigationMeshSourceGeometryData3D) -> void:
	if not is_inside_tree():
		return
	var saveiro := get_tree().get_first_node_in_group("saveiro")
	if saveiro == null or not saveiro.has_method("pegada_do_casco"):
		return
	var pegada: Dictionary = saveiro.pegada_do_casco()
	if pegada.is_empty():
		return
	fonte.add_projected_obstruction(pegada["contorno"], float(pegada["elevacao"]), float(pegada["altura"]), false)


## OS ALICERCES — plataforma baixa debaixo de uma construção (o da capelinha: 1,07 de altura, 0,35 maior que
## ela de cada lado) — são obstáculo com FOLGA. A parede de um alicerce passa do degrau do agente (`DEGRAU`) e a
## malha o contorna rente, e o contorno simplificado da malha (o `edge_max_error` do Recast, 0,26 m aqui) cortava
## a quina dele: o caminho da praça à casa de taipa raspava a esquina e o corpo, mais largo que o agente, prendia
## (`tests/colisoes_de_passeio.gd`, que o conferia andando e carregava isto como exceção). Cada alicerce entra na
## fonte da malha como obstáculo projetado, com a pegada aberta em `FOLGA_DO_ALICERCE` de cada lado; sem "carve"
## o buraco ainda cresce do raio do agente, e o caminho passa a uns 0,55 da parede. Alicerce = corpo de caixa,
## direto no mundo, mais alto que o degrau e mais baixo que o agente, com 3 u ou mais de lado.
const FOLGA_DO_ALICERCE := 0.35
const LADO_MINIMO_DO_ALICERCE := 3.0


func _alicerces(fonte: NavigationMeshSourceGeometryData3D) -> void:
	for alicerce in alicerces():
		fonte.add_projected_obstruction(alicerce["contorno"], float(alicerce["base"]) - 0.2, float(alicerce["altura"]) + 0.4, false)


## Os alicerces do mundo: {"nome", "contorno" (a pegada com folga, no chão), "base", "altura"}.
func alicerces() -> Array[Dictionary]:
	var achados: Array[Dictionary] = []
	if _mundo == null:
		return achados
	for corpo in _mundo.get_children():
		if corpo is not StaticBody3D or ((corpo as StaticBody3D).collision_layer & 1) == 0:
			continue
		for filho in corpo.get_children():
			if filho is not CollisionShape3D or (filho as CollisionShape3D).disabled or (filho as CollisionShape3D).shape is not BoxShape3D:
				continue
			var caixa: Vector3 = ((filho as CollisionShape3D).shape as BoxShape3D).size
			if caixa.y < DEGRAU + 0.1 or caixa.y > ALTURA - 0.2 or minf(caixa.x, caixa.z) < LADO_MINIMO_DO_ALICERCE:
				continue
			var t: Transform3D = (filho as CollisionShape3D).global_transform
			var metade := Vector2(caixa.x * 0.5 + FOLGA_DO_ALICERCE, caixa.z * 0.5 + FOLGA_DO_ALICERCE)
			var contorno := PackedVector3Array()
			for sinal in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(-1.0, 1.0)]:
				var canto: Vector3 = t * Vector3(sinal.x * metade.x / maxf(t.basis.x.length(), 0.0001), 0.0, sinal.y * metade.y / maxf(t.basis.z.length(), 0.0001))
				canto.y = 0.0
				contorno.append(canto)
			achados.append({"nome": str(corpo.name), "contorno": contorno, "base": t.origin.y - caixa.y * 0.5, "altura": caixa.y})
	return achados


func esta_pronta() -> bool:
	return _pronta


## O caminho de `de` até `para` pela malha, ou vazio sem malha.
## Entre cômodos, chega pela soleira e cruza o vão alinhado. Cortar a quina
## do umbral prendia a cápsula da igreja com a passagem central livre.
func caminho(de: Vector3, para: Vector3) -> PackedVector3Array:
	if not _pronta:
		return PackedVector3Array()
	var interiores: Node = _raiz.get("interiores")
	if interiores == null:
		return _caminho_na_malha(de, para)
	var saida: String = interiores.contem(de)
	var entrada: String = interiores.contem(para)
	if saida == entrada:
		return _caminho_na_malha(de, para)
	var sala_saida: Node3D = interiores.sala_de(saida)
	var sala_entrada: Node3D = interiores.sala_de(entrada)
	# Uma porta fechada não ganha um trecho que a atravesse à força.
	if (sala_saida != null and sala_saida.trancada()) or (sala_entrada != null and sala_entrada.trancada()):
		return _caminho_na_malha(de, para)
	var pontos := PackedVector3Array()
	var inicio := de
	var fim := para
	if sala_saida != null:
		pontos.append_array(_caminho_na_malha(de, sala_saida.soleira_de_dentro()))
		inicio = sala_saida.soleira_de_fora()
		pontos.append(inicio)
	if sala_entrada != null:
		fim = sala_entrada.soleira_de_fora()
	pontos.append_array(_caminho_na_malha(inicio, fim))
	if sala_entrada != null:
		pontos.append(sala_entrada.soleira_de_dentro())
		pontos.append_array(_caminho_na_malha(sala_entrada.soleira_de_dentro(), para))
	return pontos


## Segmento livre calculado pela malha, preservando o raio das portas.
func _caminho_na_malha(de: Vector3, para: Vector3) -> PackedVector3Array:
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


## OS TRONCOS DA MATA como obstáculos: um octógono no pé de cada um, do chão a
## quatro metros.
func _troncos_da_mata(fonte: NavigationMeshSourceGeometryData3D, area: AABB) -> void:
	var regiao = _mundo.get("_region")
	if regiao == null:
		return
	for tronco in regiao._tree_trunks:
		var ponto: Vector2 = tronco.get("point", Vector2.INF)
		if not ponto.is_finite() or not area.has_point(Vector3(ponto.x, area.position.y + 1.0, ponto.y)):
			continue
		# NO PÉ DO TRONCO QUE SE VÊ, o mesmo do corpo (`base_do_tronco`): o ponto
		# de plantio é o meio da copa, e na mata fica a quase um metro da madeira.
		if regiao.has_method("base_do_tronco"):
			var base: Vector3 = regiao.base_do_tronco(tronco)
			ponto = Vector2(base.x, base.z)
		# O octógono POR FORA do tronco: com o raio nos vértices ele ficava por
		# dentro do círculo, e o caminho raspava no tronco pelo meio das arestas.
		# A colisão do coqueiro inclui sua base: usar apenas o raio nominal
		# deixava a rota atravessar a borda do corpo físico (#99/#150).
		var raio_fisico: float = regiao.raio_fisico_do_tronco(tronco)
		var raio := maxf(raio_fisico, 0.2) / cos(PI / 8.0)
		# O cilindro físico acompanha a inclinação do tronco. Um octógono só
		# no pé deixava a parte à altura do corpo atravessar o caminho (orla,
		# tronco com eixo Y = 0,75). Reserva a projeção até a altura do agente,
		# incluindo seu degrau; a copa alta não vira parede de navegação.
		var base_eixo: Vector3 = regiao.base_do_tronco(tronco)
		var alto_eixo: Vector3 = tronco.get("alto_tronco", base_eixo + Vector3.UP)
		var eixo := (alto_eixo - base_eixo).normalized()
		if eixo.y < 0.1:
			eixo = Vector3.UP
		var trecho := minf(float(tronco.get("height", ALTURA)), (ALTURA + DEGRAU) / eixo.y)
		var deslocamento := Vector2(eixo.x, eixo.z) * trecho
		var pegada := PackedVector2Array()
		for ponta in [Vector2.ZERO, deslocamento]:
			for k in 8:
				var angulo := TAU * float(k) / 8.0
				pegada.append(ponto + ponta + Vector2(cos(angulo), sin(angulo)) * raio)
		var contorno := PackedVector3Array()
		for vertice in Geometry2D.convex_hull(pegada):
			contorno.append(Vector3(vertice.x, 0.0, vertice.y))
		# O PÉ DO TRONCO é o chão do vale ali, e não o "ground" da lista, que nem
		# todo tronco traz: sem ele o octógono ficava embaixo da terra.
		var pe: float = _mundo.ground_height_at(Vector3(ponto.x, 0.0, ponto.y))
		# SEM "carve": o obstáculo cortado (carve = true) escapa da erosão do raio
		# do agente, e o contorno simplificado (edge_max_error de 1,3 u) virava
		# uma aresta que passava pelo meio do tronco — o caminho do píer à
		# gameleira raspava a 0,17 u do eixo de um coqueiro de raio 0,24. Sem o
		# corte, o buraco cresce do raio do agente e o caminho contorna o tronco.
		fonte.add_projected_obstruction(contorno, pe - 1.0, 5.0, false)


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

const CORTAR_O_LEITO := false


func _leito_dos_rios(fonte: NavigationMeshSourceGeometryData3D, area: AABB) -> void:
	# Os rios rasos podem ser atravessados a pé no tutorial. O rio grande
	# exige a ponte, depois da obra; não pode oferecer seu fundo como atalho.
	var regiao = _mundo.get("_region")
	if regiao == null:
		return
	var caixa := Rect2(area.position.x, area.position.z, area.size.x, area.size.z)
	for rio in regiao._rivers:
		# Os rios rasos continuam atravessáveis, preservando o tutorial.
		if not CORTAR_O_LEITO and not bool(rio.get("grande", false)):
			continue
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
