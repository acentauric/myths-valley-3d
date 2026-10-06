extends Node3D
## O CEMITÉRIO QUE A MISSÃO DO DAMIÃO CONSERTA (data/missoes_coveiro.json).
##
## Duas coisas do outeiro mudam com ela, e as duas se leem do estado do jogo,
## sem save próprio:
##
##   AS LAJES QUE A RAIZ LEVANTOU. Três túmulos começam tortos — uma ponta da
##   laje no ar, a cruz inclinada —, e o Damião pede pedra para o calço e tábua
##   para as cruzes (`coveiro_reparo`). Passado o conserto, endireitam. Quem diz
##   é a fila dele (`passou`), que vai no save.
##
##   O CERCADO, que é obra do J (`cemiterio_cercado`, em obras.json): pau
##   roliço em volta das covas, com a entrada onde a rua do cemitério chega e a
##   capelinha no meio da beira do mar — a porta dentro, os fundos fora
##   (`world_builder._capelinha_do_cemiterio`). Quem diz é o `Obras`, que vai no
##   save. De pé, a malha dos moradores se assa de novo (`navegacao_vale.gd`):
##   o Damião sai pela entrada, e não empurrando a cerca.
##
## No estilo Tripo o cercado é a cerca do catálogo, um lance por trecho, cada
## um com a sua caixa de colisão; no procedural, a cerca de FloraReconcavo, que
## traz a dela. Nada de arte nova em nenhum dos dois.

const CONSTRUCAO := "cemiterio"
const OBRA := "cemiterio_cercado"
const PASSO_DO_CONSERTO := "coveiro_reparo"
## Do centro do cemitério à cerca, em cada um dos quatro lados: as covas, o
## mato da missão e os postos do Damião ficam dentro.
const MEIO_LADO := 8.5
## O lance de cerca que se procura em cada trecho, e a largura da entrada.
const LANCE := 2.0
const PASSAGEM := 2.6
## O tamanho da cerca do catálogo (1,15 de altura) e a grossura da colisão.
const TAMANHO_DA_CERCA := 1.0
const GROSSURA := 0.3
const ALTURA := 1.2
## AS LAJES TORTAS, pela ordem de `world_builder.tumulos` (a de data/lapides_3d.json):
## uma em cada fileira. A ponta sobe o tanto que a laje inclina — doze graus.
const TORTAS := [1, 6, 10]
const INCLINACAO := 0.21
const ERGUIDA := 0.17
## De quanto em quanto tempo se confere a missão e a obra.
const CONFERIR_A_CADA := 0.25

var _mundo
var _cadeia
var _centro := Vector3.INF
var _bases: Dictionary = {}
var _tortas_agora := false
var _cercado_de_pe := false
## Cada lance do cercado de pé: {"a", "b"} no chão, e o nó dele.
var _lances: Array[Dictionary] = []
var _entrada: Dictionary = {}
var _conferir_em := 0.0


func configurar(mundo, cadeia_do_coveiro) -> void:
	_mundo = mundo
	_cadeia = cadeia_do_coveiro
	add_to_group("cemiterio")
	_centro = mundo.ancoras.get("Cemitério", Vector3.INF)
	for indice in TORTAS:
		if indice < mundo.tumulos.size() and is_instance_valid(mundo.tumulos[indice]):
			_bases[indice] = (mundo.tumulos[indice] as Node3D).transform
	# A obra feita levanta o cercado NA HORA; a conferência de quarto em quarto
	# de segundo cobre o resto (a fila que anda, a partida que volta).
	Obras.concluida.connect(func(construcao: String, _obra: String) -> void:
		if construcao == CONSTRUCAO:
			acertar())
	acertar()


func _process(delta: float) -> void:
	_conferir_em -= delta
	if _conferir_em > 0.0:
		return
	_conferir_em = CONFERIR_A_CADA
	acertar()


## O OUTEIRO COMO O JOGO DIZ QUE ELE ESTÁ: as lajes pela fila do Damião, o
## cercado pela obra. Para os dois lados — carregar uma partida mais antiga
## desfaz o que a mais nova tinha.
func acertar() -> void:
	if not _centro.is_finite():
		return
	var tortas: bool = _cadeia == null or not _cadeia.passou(PASSO_DO_CONSERTO)
	if tortas != _tortas_agora:
		_entortar(tortas)
	var cercado := Obras.ja_feita(CONSTRUCAO, OBRA)
	if cercado != _cercado_de_pe:
		if cercado:
			_levantar()
		else:
			_desmontar()


## Os índices das lajes tortas agora (vazio depois do conserto).
func lajes_tortas() -> Array:
	return TORTAS.duplicate() if _tortas_agora else []


func cercado_de_pe() -> bool:
	return _cercado_de_pe


## Os lances do cercado de pé, cada um {"a": Vector3, "b": Vector3} no chão.
func lances() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for lance in _lances:
		lista.append({"a": lance["a"], "b": lance["b"]})
	return lista


## A entrada do cercado: {"centro": Vector3, "ao_longo": Vector3, "largura": float}.
func entrada() -> Dictionary:
	return _entrada.duplicate()


# --- as lajes ------------------------------------------------------------------

## A ponta da laje no ar, uma para cada lado. O giro é no eixo CURTO da laje:
## no Tripo ela é comprida em X, no procedural em Z — a pegada diz qual.
func _entortar(tortas: bool) -> void:
	_tortas_agora = tortas
	var vez := 0
	for indice in _bases:
		var tumulo: Node3D = _mundo.tumulos[indice]
		if not is_instance_valid(tumulo):
			continue
		var base: Transform3D = _bases[indice]
		if not tortas:
			tumulo.transform = base
			continue
		var pegada: Vector3 = _mundo.lapides_pegada[indice] if indice < _mundo.lapides_pegada.size() else Vector3(1, 0, 0.5)
		var eixo := Vector3.BACK if pegada.x >= pegada.z else Vector3.RIGHT
		var lado := 1.0 if vez % 2 == 0 else -1.0
		vez += 1
		tumulo.transform = Transform3D(base.basis * Basis(eixo, INCLINACAO * lado), base.origin + Vector3.UP * ERGUIDA)


# --- o cercado -----------------------------------------------------------------

func _levantar() -> void:
	_desmontar()
	_cercado_de_pe = true
	var tripo: bool = _mundo.estilo_tripo()
	var largura_do_lance: float = CatalogoAssets.largura_da_cerca(self, TAMANHO_DA_CERCA, LANCE) if tripo else LANCE
	for trecho in _trechos():
		var a: Vector3 = trecho[0]
		var b: Vector3 = trecho[1]
		var comprimento := Vector2(b.x - a.x, b.z - a.z).length()
		var quantos := maxi(1, roundi(comprimento / LANCE))
		for k in quantos:
			# Cada lance de ponta a ponta no chão, deitado na encosta do outeiro
			# (#93; `CatalogoAssets.lance_de_cerca`).
			var de: Vector3 = _mundo.ground_position(a.lerp(b, float(k) / float(quantos)))
			var ate: Vector3 = _mundo.ground_position(a.lerp(b, float(k + 1) / float(quantos)))
			_lances.append({"a": de, "b": ate,
				"no": CatalogoAssets.lance_de_cerca(self, de, ate, tripo, TAMANHO_DA_CERCA, largura_do_lance, ALTURA, GROSSURA, "Lance", "LanceColisao")})
	# O caminho dos moradores muda: a malha se assa de novo, com o cercado.
	var navegacao := get_tree().get_first_node_in_group("navegacao") if is_inside_tree() else null
	if navegacao != null:
		navegacao.reassar()


func _desmontar() -> void:
	var havia := not _lances.is_empty()
	for lance in _lances:
		if is_instance_valid(lance["no"]):
			(lance["no"] as Node).queue_free()
	_lances.clear()
	_cercado_de_pe = false
	if havia:
		var navegacao := get_tree().get_first_node_in_group("navegacao") if is_inside_tree() else null
		if navegacao != null:
			navegacao.reassar()


## OS TRECHOS DE CERCA: os quatro lados do quadrado em volta das covas, menos a
## capelinha — que fica no meio da beira do mar — e menos a entrada, onde a rua
## do cemitério cruza a linha da cerca. Sem rua que cruze, a entrada fica no
## lado da praça.
func _trechos() -> Array:
	var h := MEIO_LADO
	var cantos := [Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)]
	var c2 := Vector2(_centro.x, _centro.z)
	var lados: Array = []
	for k in 4:
		lados.append([c2 + cantos[k], c2 + cantos[(k + 1) % 4]])
	var cortes: Array = [[], [], [], []]
	# A capelinha: o pedaço do lado que passa por dentro dela.
	var capelinha: Dictionary = _mundo.construcoes.get("Capelinha", {})
	if not capelinha.is_empty() and is_instance_valid(capelinha.get("modelo")):
		var limites: AABB = (capelinha["modelo"] as Node3D).get_meta("limites")
		var frente: Vector3 = _mundo.ancoras.get("CapelinhaFrente", Vector3.BACK)
		var meio: Vector3 = _mundo.ancoras.get("Capelinha", _centro)
		var meia := Vector2(limites.size.z, limites.size.x) * 0.5 if absf(frente.x) > 0.5 else Vector2(limites.size.x, limites.size.z) * 0.5
		var caixa := Rect2(Vector2(meio.x, meio.z) - meia - Vector2.ONE * 0.1, (meia + Vector2.ONE * 0.1) * 2.0)
		for k in 4:
			var corte := _corte_da_caixa(lados[k][0], lados[k][1], caixa)
			if not corte.is_empty():
				cortes[k].append(corte)
	# A entrada.
	var onde := _onde_a_rua_cruza(lados)
	if onde.is_empty():
		onde = _lado_da_praca(lados)
	if not onde.is_empty():
		var k: int = onde["lado"]
		var comprimento: float = (lados[k][1] - lados[k][0]).length()
		var t := clampf(float(onde["t"]), PASSAGEM * 0.5, comprimento - PASSAGEM * 0.5)
		cortes[k].append([t - PASSAGEM * 0.5, t + PASSAGEM * 0.5])
		var ao_longo: Vector2 = (lados[k][1] - lados[k][0]).normalized()
		var ponto: Vector2 = lados[k][0] + ao_longo * t
		_entrada = {"centro": _mundo.ground_position(Vector3(ponto.x, 0, ponto.y)),
			"ao_longo": Vector3(ao_longo.x, 0, ao_longo.y), "largura": PASSAGEM}
	var trechos: Array = []
	for k in 4:
		var a: Vector2 = lados[k][0]
		var b: Vector2 = lados[k][1]
		var comprimento := (b - a).length()
		var ao_longo := (b - a) / comprimento
		var livres := _sobra(comprimento, cortes[k])
		for livre in livres:
			if float(livre[1]) - float(livre[0]) < 0.4:
				continue
			var de := a + ao_longo * float(livre[0])
			var ate := a + ao_longo * float(livre[1])
			trechos.append([Vector3(de.x, 0, de.y), Vector3(ate.x, 0, ate.y)])
	return trechos


## Onde, ao longo do lado de `a` a `b`, ele passa por dentro da caixa: [t0, t1] ou [].
static func _corte_da_caixa(a: Vector2, b: Vector2, caixa: Rect2) -> Array:
	var comprimento := (b - a).length()
	var ao_longo := (b - a) / comprimento
	var dentro: Array[float] = []
	var passos := 200
	for i in passos + 1:
		var t := comprimento * float(i) / float(passos)
		if caixa.has_point(a + ao_longo * t):
			dentro.append(t)
	if dentro.is_empty():
		return []
	return [dentro[0], dentro[-1]]


## A RUA DO CEMITÉRIO CRUZANDO A CERCA: de todas as ruas que cruzam o quadrado, a
## que chega mais perto das covas. {"lado", "t"} ou {}.
func _onde_a_rua_cruza(lados: Array) -> Dictionary:
	var regiao = _mundo.get("_region")
	if regiao == null:
		return {}
	var c2 := Vector2(_centro.x, _centro.z)
	var melhor: Dictionary = {}
	var mais_perto := INF
	for rua in regiao._roads:
		var pontos: PackedVector2Array = rua.get("points", PackedVector2Array())
		var perto_da_rua := INF
		for i in pontos.size() - 1:
			perto_da_rua = minf(perto_da_rua, Geometry2D.get_closest_point_to_segment(c2, pontos[i], pontos[i + 1]).distance_to(c2))
		if perto_da_rua >= mais_perto:
			continue
		for i in pontos.size() - 1:
			for k in lados.size():
				var cruza = Geometry2D.segment_intersects_segment(pontos[i], pontos[i + 1], lados[k][0], lados[k][1])
				if cruza != null:
					mais_perto = perto_da_rua
					melhor = {"lado": k, "t": (cruza as Vector2).distance_to(lados[k][0])}
	return melhor


## Sem rua: o meio do lado que olha para a praça.
func _lado_da_praca(lados: Array) -> Dictionary:
	var praca: Vector3 = Lugares.ponto("praca")
	if not praca.is_finite():
		return {}
	var c2 := Vector2(_centro.x, _centro.z)
	var rumo := (Vector2(praca.x, praca.z) - c2).normalized()
	var melhor := 0
	var maior := -INF
	for k in lados.size():
		var meio: Vector2 = (lados[k][0] + lados[k][1]) * 0.5 - c2
		if meio.normalized().dot(rumo) > maior:
			maior = meio.normalized().dot(rumo)
			melhor = k
	return {"lado": melhor, "t": (lados[melhor][1] - lados[melhor][0]).length() * 0.5}


## O que sobra de [0, comprimento] tirando os cortes.
static func _sobra(comprimento: float, cortes: Array) -> Array:
	var ordenados := cortes.duplicate()
	ordenados.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	var livres: Array = []
	var desde := 0.0
	for corte in ordenados:
		var ini := clampf(float(corte[0]), 0.0, comprimento)
		var fim := clampf(float(corte[1]), 0.0, comprimento)
		if ini > desde:
			livres.append([desde, ini])
		desde = maxf(desde, fim)
	if desde < comprimento:
		livres.append([desde, comprimento])
	return livres
