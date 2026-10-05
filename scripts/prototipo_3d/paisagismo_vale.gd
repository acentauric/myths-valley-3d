extends RefCounted
## O PAISAGISMO DO VALE: onde cresce cada bananal, pomar, roça e mata ciliar do
## arraial, lido da cena `paisagismo_vale.tscn` (as zonas, que o dono edita) e de
## `data/paisagismo/receitas.json` (o que cada zona planta e como).
##
## POR QUE NÃO É UM SORTEIO SOLTO. A mata do vale (`_build_forest`) é um sorteio
## uniforme e o arraial, onde ela não entra, ficou 78% vazio. Aqui o plantio é
## de AGRUPAMENTOS DE UMA ESPÉCIE SÓ, como o lavrador planta: o bananal é de
## bananeira em touceira, a roça de mandioca é de mandioca em fileira, o pomar
## de quintal é feito de bosquetes, cada um de uma fruta, e a mata ciliar segue
## o rio, por trecho. A repetição é melhor que a mistura.
##
## DETERMINÍSTICO E LOCAL. Cada candidato (um ponto da malha da zona) tira TODOS
## os números dele de uma função de hash da semente e da posição na malha — a
## falha, o tamanho, o giro, o desvio, a espécie da quadra ou da mancha — ANTES de
## perguntar pelas reservas. Mover uma casa só tira as árvores que ela passou a
## cobrir; nenhuma outra sai do lugar (é a lição das clareiras, em
## geo_region_renderer.gd).
##
## AS RESERVAS (`reservas`, montadas por `reservas_do_mundo`) são o que o paisagismo
## nunca cobre: rua, casa e a faixa da porta até a rua, árvore nomeada, âncora,
## cemitério, a faixa da orla (que é do bioma da orla), o leito dos rios, as
## veredas, o corredor do sobrevoo do menu (só entra pé baixo) e o tronco que já
## existe. A copa de cada pé soma à folga. Coqueiro e mangue são da orla: nenhuma
## receita os planta.
##
## `gerar` é PURO: zonas + receitas + reservas entram, a lista de pés sai. Reservas
## vazias (`{}`) desligam todas elas — é o que o portão usa para provar que as
## reservas funcionam.

const CENA := "res://scenes/prototipo_3d/paisagismo_vale.tscn"
const RECEITAS := "res://data/paisagismo/receitas.json"
const SOBREVOO := "res://data/sobrevoo_menu.json"
## Célula da grade das reservas circulares (u).
const CELULA := 16.0
## A costa só importa até esta margem: a faixa da orla tem 18 u.
const MARGEM_DA_COSTA := 26.0
## O raio de busca das reservas de copa: nenhuma copa de receita passa disto.
const COPA_MAXIMA := 4.0
## A malha de um pé de forro (capim, bromélia) some mais cedo que a das árvores.
const LOD_DO_FORRO := 60.0
## O chão em que a muda não pega: rente ao nível do mar não se planta.
const FOLGA_DA_AGUA := 0.05


# --- Leitura -------------------------------------------------------------------

static func ler_receitas(caminho: String = RECEITAS) -> Dictionary:
	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null:
		push_error("As receitas do paisagismo não foram encontradas: " + caminho)
		return {}
	var dados: Variant = JSON.parse_string(arquivo.get_as_text())
	return dados if dados is Dictionary else {}


## As zonas da cena: {"nome", "receita", "semente", "densidade", "rumo_graus",
## "ativa", "poligono"}, na ordem da cena. A cena é a fonte: nada daqui a regera.
static func ler(caminho: String = CENA) -> Array[Dictionary]:
	var zonas: Array[Dictionary] = []
	var recurso := load(caminho) as PackedScene
	if recurso == null:
		push_error("A cena do paisagismo não pôde ser lida: " + caminho)
		return zonas
	var cena := recurso.instantiate()
	var grupo := cena.get_node_or_null("Zonas")
	if grupo == null:
		push_error("A cena do paisagismo precisa do grupo Zonas: " + caminho)
		cena.free()
		return zonas
	for no in grupo.get_children():
		if not no.has_method("poligono"):
			continue
		var poligono: PackedVector2Array = no.poligono()
		if poligono.size() < 3:
			continue
		zonas.append({
			"nome": String(no.name), "receita": String(no.receita), "semente": int(no.semente),
			"densidade": float(no.densidade), "rumo_graus": float(no.rumo_graus),
			"ativa": bool(no.ativa), "poligono": poligono,
		})
	cena.free()
	return zonas


# --- Sorteio por hash ------------------------------------------------------------

## Um número em [0, 1) que só depende dos quatro inteiros: o mesmo ponto da malha
## tira sempre o mesmo número, haja o que houver em volta dele.
static func ruido(semente: int, a: int, b: int, k: int) -> float:
	var h := (semente * 374761393 + a * 668265263 + b * 2246822519 + k * 3266489917) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = ((h ^ (h >> 16)) * 2246822519) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 3266489917) & 0xFFFFFFFF
	h = (h ^ (h >> 16)) & 0xFFFFFFFF
	return float(h) / 4294967296.0


static func _sorteios(semente: int, a: int, b: int) -> PackedFloat64Array:
	var lista := PackedFloat64Array()
	for k in 6:
		lista.append(ruido(semente, a, b, k + 1))
	return lista


static func _peso(valor: Variant) -> float:
	return float((valor as Dictionary).get("peso", 1.0)) if valor is Dictionary else float(valor)


static func _porte(valor: Variant) -> float:
	return float((valor as Dictionary).get("porte", 1.0)) if valor is Dictionary else 1.0


## A espécie sorteada pelos pesos (`r` em [0, 1)).
static func _sortear(especies: Dictionary, r: float) -> String:
	var total := 0.0
	for chave in especies:
		total += _peso(especies[chave])
	var alvo := r * total
	var acumulado := 0.0
	var ultima := ""
	for chave in especies:
		acumulado += _peso(especies[chave])
		ultima = String(chave)
		if alvo < acumulado:
			return ultima
	return ultima


# --- A geração -------------------------------------------------------------------

## Os pés do vale inteiro: [{"chave", "ponto" (Vector2), "escala", "giro", "zona",
## "lod", "forro"}]. Puro: o mesmo trio de entradas dá sempre a mesma lista.
static func gerar(zonas: Array, receitas: Dictionary, reservas: Dictionary) -> Array[Dictionary]:
	var plantas: Array[Dictionary] = []
	var modelos: Dictionary = receitas.get("receitas", {})
	for zona: Dictionary in zonas:
		if not bool(zona.get("ativa", true)):
			continue
		var receita: Dictionary = modelos.get(String(zona.get("receita", "")), {})
		if receita.is_empty():
			continue
		var poligono: PackedVector2Array = zona["poligono"]
		var ctx := {
			"zona": zona, "receita": receita, "poligono": poligono, "caixa": _caixa(poligono),
			"info": receitas.get("info_das_especies", {}), "regras": receitas.get("reservas", {}),
			"reservas": reservas, "semente": int(zona.get("semente", 1)),
			"densidade": maxf(float(zona.get("densidade", 1.0)), 0.05),
			"rumo": deg_to_rad(float(zona.get("rumo_graus", 0.0))),
		}
		match String(receita.get("padrao", "esparso")):
			"fileiras":
				_fileiras(ctx, plantas)
			"touceiras":
				_touceiras(ctx, plantas)
			"manchas":
				_manchas(ctx, plantas)
			"faixa":
				_faixa(ctx, plantas)
			_:
				_esparso(ctx, plantas)
		_forro(ctx, plantas)
	return plantas


static func _caixa(poligono: PackedVector2Array) -> Rect2:
	var caixa := Rect2(poligono[0], Vector2.ZERO)
	for ponto in poligono:
		caixa = caixa.expand(ponto)
	return caixa


## A caixa do polígono no referencial girado (u, v) da zona.
static func _caixa_girada(ctx: Dictionary) -> Rect2:
	var volta := Transform2D(-float(ctx.rumo), Vector2.ZERO)
	var caixa := Rect2()
	var primeiro := true
	for ponto: Vector2 in ctx.poligono:
		var local := volta * ponto
		if primeiro:
			caixa = Rect2(local, Vector2.ZERO)
			primeiro = false
		else:
			caixa = caixa.expand(local)
	return caixa


static func _escala_da(receita: Dictionary, sorteio: float) -> float:
	var faixa: Array = receita.get("escala", [1.0, 1.0])
	return lerpf(float(faixa[0]), float(faixa[1]), sorteio)


## Tenta plantar `chave` em `ponto`: a falha, a zona, as reservas e o corredor do
## sobrevoo, nesta ordem. Os números do candidato já foram tirados (`sorteios`).
static func _tentar(ctx: Dictionary, ponto: Vector2, chave: String, sorteios: PackedFloat64Array,
		escala_receita: Variant, lod: float, falhas: float, beira: bool, saida: Array[Dictionary], forro: bool = false) -> void:
	if sorteios[0] < falhas:
		return
	if not (ctx.caixa as Rect2).has_point(ponto) or not Geometry2D.is_point_in_polygon(ponto, ctx.poligono):
		return
	var info: Dictionary = ctx.info
	var dados: Dictionary = info.get(chave, {})
	if dados.is_empty():
		return
	var faixa: Array = escala_receita if escala_receita is Array else (ctx.receita as Dictionary).get("escala", [1.0, 1.0])
	var escala := lerpf(float(faixa[0]), float(faixa[1]), sorteios[1])
	var copa := float(dados.copa) * escala
	var reservas: Dictionary = ctx.reservas
	var regras: Dictionary = ctx.regras
	if bloqueado(reservas, regras, ponto, copa, beira) != "":
		return
	# O corredor do sobrevoo do menu: só entra pé baixo. O que passa da altura
	# encolhe até a escala mínima; passando disso, vira a planta baixa da receita
	# (ou sai).
	if reservas.has("voo") and no_corredor_do_voo(reservas["voo"], ponto, copa, regras):
		var limite := float(regras.get("altura_no_voo", 2.4))
		if float(dados.altura) * escala > limite:
			var encolhida := limite / float(dados.altura)
			if encolhida >= float(regras.get("escala_minima_no_voo", 0.7)):
				escala = encolhida
			else:
				var baixa := String((ctx.receita as Dictionary).get("baixa_no_voo", ""))
				if baixa == "" or not info.has(baixa):
					return
				chave = baixa
				escala = lerpf(0.85, 1.1, sorteios[1])
				if float((info[baixa] as Dictionary).altura) * escala > limite:
					return
	saida.append({"chave": chave, "ponto": ponto, "escala": escala, "giro": sorteios[2] * TAU,
		"zona": String((ctx.zona as Dictionary).get("nome", "")), "lod": lod, "forro": forro})


## O que impede de plantar em `p` um pé de copa `copa`: o nome da reserva violada,
## ou "" quando está livre. `beira`: a planta que nasce na água (a taboa) chega
## mais perto do leito.
static func bloqueado(reservas: Dictionary, regras: Dictionary, p: Vector2, copa: float, beira: bool = false) -> String:
	if reservas.is_empty():
		return ""
	var terra: Variant = reservas.get("terra")
	if terra is Callable and not (terra as Callable).call(p):
		return "terra"
	var rua: Variant = reservas.get("rua")
	if rua is Callable and float((rua as Callable).call(p)) < float(regras.get("rua", 3.0)) + copa:
		return "rua"
	var costa: Variant = reservas.get("costa")
	if costa is Callable and float((costa as Callable).call(p)) < float(regras.get("costa", 18.0)):
		return "costa"
	var rio: Variant = reservas.get("rio")
	if rio is Callable:
		var perto: Vector3 = (rio as Callable).call(p)
		var folga := (float(regras.get("leito_beira", 0.5)) + copa * 0.5) if beira else (float(regras.get("leito", 3.0)) + copa)
		if perto.x < folga:
			return "leito"
	var circulos: Array = reservas.get("circulos", [])
	var grade: Dictionary = reservas.get("grade", {})
	var celula := Vector2i(floori(p.x / CELULA), floori(p.y / CELULA))
	for i: int in grade.get(celula, []):
		var c: Vector4 = circulos[i]
		var raio := c.z + c.w * copa
		if p.distance_squared_to(Vector2(c.x, c.y)) < raio * raio:
			return String((reservas["tipos"] as PackedStringArray)[i])
	for segmento: Dictionary in reservas.get("segmentos", []):
		var folga_do_segmento := float(segmento.folga) + copa * 0.5
		if not (segmento.caixa as Rect2).grow(folga_do_segmento).has_point(p):
			continue
		var a: Vector2 = segmento.a
		var b: Vector2 = segmento.b
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) < folga_do_segmento:
			return String(segmento.tipo)
	return ""


## `p` (com a copa) cai no corredor do sobrevoo do menu?
static func no_corredor_do_voo(voo: Dictionary, p: Vector2, copa: float, regras: Dictionary) -> bool:
	var folga := float(regras.get("voo", 9.0)) + copa * 0.5
	if not (voo.caixa as Rect2).grow(folga).has_point(p):
		return false
	var pontos: PackedVector2Array = voo.pontos
	for i in pontos.size() - 1:
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, pontos[i], pontos[i + 1])) < folga:
			return true
	return false


# --- Os padrões ------------------------------------------------------------------

## FILEIRAS: a roça em quadras de fileiras retas, com corredor entre elas e quadra
## em pousio. Cada quadra é de uma espécie só.
static func _fileiras(ctx: Dictionary, saida: Array[Dictionary]) -> void:
	var receita: Dictionary = ctx.receita
	var s: int = ctx.semente
	var dx := float(receita.espacamento) * float(ctx.densidade)
	var dy := float(receita.get("entre_fileiras", receita.espacamento)) * float(ctx.densidade)
	var quadra: Array = receita.get("quadra", [24.0, 14.0])
	var corredor := float(receita.get("corredor", 2.6))
	var periodo_u := float(quadra[0]) + corredor
	var periodo_v := float(quadra[1]) + corredor
	var pousio := float(receita.get("pousio", 0.0))
	var giro := Transform2D(float(ctx.rumo), Vector2.ZERO)
	var caixa := _caixa_girada(ctx)
	for iv in range(floori(caixa.position.y / dy), floori(caixa.end.y / dy) + 1):
		for iu in range(floori(caixa.position.x / dx), floori(caixa.end.x / dx) + 1):
			var sorteios := _sorteios(s, iu, iv)
			var u := float(iu) * dx
			var v := float(iv) * dy
			if fposmod(u, periodo_u) >= float(quadra[0]) or fposmod(v, periodo_v) >= float(quadra[1]):
				continue
			var qi := floori(u / periodo_u)
			var qj := floori(v / periodo_v)
			if ruido(s, qi, qj, 90) < pousio:
				continue
			var chave := _sortear(receita.especies, ruido(s, qi, qj, 91))
			var ponto: Vector2 = giro * Vector2(u + (sorteios[3] - 0.5) * 0.3 * dx, v + (sorteios[4] - 0.5) * 0.2 * dy)
			_tentar(ctx, ponto, chave, sorteios, null, float(receita.get("lod", 120.0)), float(receita.get("falhas", 0.0)), false, saida)


## TOUCEIRAS: moitas de vários pés juntos, como a bananeira brota, numa malha
## frouxa. Cada moita é de uma espécie só.
static func _touceiras(ctx: Dictionary, saida: Array[Dictionary]) -> void:
	var receita: Dictionary = ctx.receita
	var s: int = ctx.semente
	var passo := float(receita.espacamento) * float(ctx.densidade)
	var tamanho: Array = receita.get("touceira", [3, 5])
	var raio := float(receita.get("raio_touceira", 1.5))
	var giro := Transform2D(float(ctx.rumo), Vector2.ZERO)
	var caixa := _caixa_girada(ctx)
	for iv in range(floori(caixa.position.y / passo), floori(caixa.end.y / passo) + 1):
		for iu in range(floori(caixa.position.x / passo), floori(caixa.end.x / passo) + 1):
			if ruido(s, iu, iv, 11) < float(receita.get("falhas", 0.0)):
				continue
			var centro := Vector2((float(iu) + 0.5 + (ruido(s, iu, iv, 12) - 0.5) * 0.7) * passo, (float(iv) + 0.5 + (ruido(s, iu, iv, 13) - 0.5) * 0.7) * passo)
			var chave := _sortear(receita.especies, ruido(s, iu, iv, 14))
			var n := int(tamanho[0]) + int(ruido(s, iu, iv, 15) * float(int(tamanho[1]) - int(tamanho[0]) + 1))
			for m in n:
				var angulo := ruido(s, iu, iv, 20 + m * 3) * TAU
				var distancia := sqrt(ruido(s, iu, iv, 21 + m * 3)) * raio
				var ponto: Vector2 = giro * (centro + Vector2.RIGHT.rotated(angulo) * distancia)
				_tentar(ctx, ponto, chave, _sorteios(s + 1000 * (m + 1), iu, iv), null, float(receita.get("lod", 230.0)), 0.0, false, saida)


## MANCHAS: bosquetes de uma espécie, com vão entre eles — o pomar de quintal, o
## cajual, o sítio das mangueiras. A mancha é a célula de Voronoi de uma malha de
## sementes; a espécie sai do hash da mancha; o vão é a faixa junto da fronteira
## entre duas manchas, onde não se planta, e a mancha vazia é clareira.
static func _manchas(ctx: Dictionary, saida: Array[Dictionary]) -> void:
	var receita: Dictionary = ctx.receita
	var s: int = ctx.semente
	var passo := float(receita.espacamento) * float(ctx.densidade)
	var tamanho := float(receita.get("mancha", 18.0))
	var vao := float(receita.get("vao", passo * 0.6))
	var vazias := float(receita.get("vazias", 0.0))
	var giro := Transform2D(float(ctx.rumo), Vector2.ZERO)
	var caixa := _caixa_girada(ctx)
	for iv in range(floori(caixa.position.y / passo), floori(caixa.end.y / passo) + 1):
		for iu in range(floori(caixa.position.x / passo), floori(caixa.end.x / passo) + 1):
			var sorteios := _sorteios(s, iu, iv)
			var ponto: Vector2 = giro * Vector2((float(iu) + (sorteios[3] - 0.5) * 0.7) * passo, (float(iv) + (sorteios[4] - 0.5) * 0.7) * passo)
			var perto := _mancha_de(ponto, s, tamanho)
			if perto[1] - perto[0] < vao:
				continue
			var ci := int(perto[2])
			var cj := int(perto[3])
			if ruido(s, ci, cj, 42) < vazias:
				continue
			var chave := _sortear(receita.especies, ruido(s, ci, cj, 41))
			# Árvore de porte grande pede mais chão: planta menos pés por mancha.
			var porte := _porte((receita.especies as Dictionary)[chave])
			if porte > 1.0 and sorteios[5] > 1.0 / (porte * porte):
				continue
			_tentar(ctx, ponto, chave, sorteios, null, float(receita.get("lod", 230.0)), float(receita.get("falhas", 0.0)), false, saida)


## A mancha de `ponto`: [distância à semente mais perto, distância à segunda,
## coluna e linha da célula da mancha]. A diferença das duas distâncias diz o
## quanto o ponto está longe da fronteira entre duas manchas.
static func _mancha_de(ponto: Vector2, s: int, tamanho: float) -> PackedFloat64Array:
	var ci0 := floori(ponto.x / tamanho)
	var cj0 := floori(ponto.y / tamanho)
	var d1 := INF
	var d2 := INF
	var melhor_i := ci0
	var melhor_j := cj0
	for dj in range(-1, 2):
		for di in range(-1, 2):
			var ci := ci0 + di
			var cj := cj0 + dj
			var semente := Vector2((float(ci) + 0.5 + (ruido(s, ci, cj, 40) - 0.5) * 0.7) * tamanho, (float(cj) + 0.5 + (ruido(s, ci, cj, 43) - 0.5) * 0.7) * tamanho)
			var d := ponto.distance_to(semente)
			if d < d1:
				d2 = d1
				d1 = d
				melhor_i = ci
				melhor_j = cj
			elif d < d2:
				d2 = d
	return PackedFloat64Array([d1, d2, float(melhor_i), float(melhor_j)])


## ESPARSO: pés soltos, um a um, numa malha com desvio (o dendezal).
static func _esparso(ctx: Dictionary, saida: Array[Dictionary]) -> void:
	var receita: Dictionary = ctx.receita
	var s: int = ctx.semente
	var passo := float(receita.get("espacamento", 6.0)) * float(ctx.densidade)
	var giro := Transform2D(float(ctx.rumo), Vector2.ZERO)
	var caixa := _caixa_girada(ctx)
	for iv in range(floori(caixa.position.y / passo), floori(caixa.end.y / passo) + 1):
		for iu in range(floori(caixa.position.x / passo), floori(caixa.end.x / passo) + 1):
			var sorteios := _sorteios(s, iu, iv)
			var ponto: Vector2 = giro * Vector2((float(iu) + (sorteios[3] - 0.5) * 0.8) * passo, (float(iv) + (sorteios[4] - 0.5) * 0.8) * passo)
			var chave := _sortear(receita.especies, ruido(s, iu, iv, 50))
			_tentar(ctx, ponto, chave, sorteios, null, float(receita.get("lod", 230.0)), float(receita.get("falhas", 0.0)), false, saida)


## FAIXA: a mata ciliar, em faixas paralelas ao rio — taboa na água, helicônia,
## samambaia e bambu na sombra, ingá e jenipapo no alto da barranca. Em cada
## faixa a espécie muda por TRECHO do rio, não por pé.
static func _faixa(ctx: Dictionary, saida: Array[Dictionary]) -> void:
	var receita: Dictionary = ctx.receita
	var reservas: Dictionary = ctx.reservas
	var rio: Variant = reservas.get("rio")
	if not rio is Callable:
		return
	var s: int = ctx.semente
	var caixa: Rect2 = ctx.caixa
	var banda := 0
	for faixa: Dictionary in receita.get("faixas", []):
		banda += 1
		var passo := float(faixa.espacamento) * float(ctx.densidade)
		var trecho := float(faixa.get("trecho", 20.0))
		for iv in range(floori(caixa.position.y / passo), floori(caixa.end.y / passo) + 1):
			for iu in range(floori(caixa.position.x / passo), floori(caixa.end.x / passo) + 1):
				var sorteios := _sorteios(s + 97 * banda, iu, iv)
				var ponto := Vector2((float(iu) + (sorteios[3] - 0.5) * 0.8) * passo, (float(iv) + (sorteios[4] - 0.5) * 0.8) * passo)
				if sorteios[0] < float(faixa.get("vazios", 0.0)):
					continue
				if not caixa.has_point(ponto):
					continue
				var perto: Vector3 = (rio as Callable).call(ponto)
				if perto.x < float(faixa.de) or perto.x > float(faixa.ate):
					continue
				var id_do_trecho := int(perto.z) * 1000 + floori(perto.y / trecho)
				var chave := _sortear(faixa.especies, ruido(s, id_do_trecho, banda, 60))
				_tentar(ctx, ponto, chave, sorteios, faixa.get("escala", null), float(faixa.get("lod", receita.get("lod", 120.0))),
					float(receita.get("falhas", 0.0)), bool(faixa.get("beira", false)), saida)


## O FORRO: o que cobre o chão entre os pés (capim, bromélia), em pés por 100 u².
## Não conta na pureza.
static func _forro(ctx: Dictionary, saida: Array[Dictionary]) -> void:
	var forro: Dictionary = (ctx.receita as Dictionary).get("forro", {})
	if forro.is_empty():
		return
	var s: int = ctx.semente
	var caixa: Rect2 = ctx.caixa
	var celula := 10.0
	var k := 0
	for chave in forro:
		k += 1
		var densidade := float(forro[chave]) / float(ctx.densidade)
		for jv in range(floori(caixa.position.y / celula), floori(caixa.end.y / celula) + 1):
			for ju in range(floori(caixa.position.x / celula), floori(caixa.end.x / celula) + 1):
				var n := int(densidade) + (1 if ruido(s + 311 * k, ju, jv, 70) < densidade - floorf(densidade) else 0)
				for m in n:
					var sorteios := _sorteios(s + 313 * k + 17 * (m + 1), ju, jv)
					var ponto := Vector2((float(ju) + ruido(s + 311 * k, ju, jv, 71 + m)) * celula, (float(jv) + ruido(s + 311 * k, ju, jv, 72 + m)) * celula)
					_tentar(ctx, ponto, String(chave), sorteios, [0.8, 1.2], LOD_DO_FORRO, 0.0, false, saida, true)


# --- As reservas do mundo ----------------------------------------------------------

## As reservas do vale montado: ver o cabeçalho. `wb` é o WorldBuilder, com as
## casas (`_house_sites`), as nomeadas, as âncoras e a região. O que o próprio
## paisagismo plantou não entra: remontar dá o mesmo resultado.
static func reservas_do_mundo(wb: Node, receitas: Dictionary) -> Dictionary:
	var regiao: Node3D = wb._region
	var regras: Dictionary = receitas.get("reservas", {})
	var circulos: Array[Vector4] = []
	var tipos := PackedStringArray()
	var segmentos: Array[Dictionary] = []
	# Casas, com a folga do quintal.
	for sitio: Dictionary in wb._house_sites:
		var pos: Vector3 = sitio["position"]
		circulos.append(Vector4(pos.x, pos.z, float(sitio["radius"]) + float(regras.get("casa", 4.0)), 1.0))
		tipos.append("casa")
	# Os lotes dos moradores, mesmo antes de a casa existir.
	var lotes: Dictionary = receitas.get("lotes_dos_moradores", {})
	for lote: Dictionary in lotes.get("lotes", []):
		var pos_do_lote: Array = lote["pos"]
		circulos.append(Vector4(float(pos_do_lote[0]), float(pos_do_lote[1]), float(lotes.get("raio", 10.0)), 1.0))
		tipos.append("lote")
	# Árvores nomeadas (copa grande, que o raio do tronco não diz).
	for nomeada: Dictionary in wb._arvores_nomeadas:
		var pos_da_nomeada: Vector3 = nomeada["pos"]
		circulos.append(Vector4(pos_da_nomeada.x, pos_da_nomeada.z, float(nomeada.get("raio", 1.0)) + float(regras.get("nomeada", 1.0)) + 2.5, 0.5))
		tipos.append("nomeada")
	# Âncoras (posições; os "...Frente" são direções).
	for nome: String in wb.ancoras:
		if nome.ends_with("Frente") or nome.ends_with("Direcao") or nome.ends_with("Lado"):
			continue
		var ancora: Variant = wb.ancoras[nome]
		if not ancora is Vector3:
			continue
		var raio := float(regras.get("cemiterio", 16.0)) if nome == "Cemitério" else float(regras.get("ancora", 7.0))
		circulos.append(Vector4((ancora as Vector3).x, (ancora as Vector3).z, raio, 1.0))
		tipos.append("cemiterio" if nome == "Cemitério" else "ancora")
	# O tronco que já existe (a mata, a orla, o rio): não se planta em cima dele.
	for tronco: Dictionary in regiao._tree_trunks:
		if tronco.has("paisagismo"):
			continue
		var ponto: Vector2 = tronco["point"]
		circulos.append(Vector4(ponto.x, ponto.y, float(tronco["radius"]) + 0.8, 0.5))
		tipos.append("tronco")
	var grade := {}
	for i in circulos.size():
		var c := circulos[i]
		var alcance := c.z + c.w * COPA_MAXIMA
		for cy in range(floori((c.y - alcance) / CELULA), floori((c.y + alcance) / CELULA) + 1):
			for cx in range(floori((c.x - alcance) / CELULA), floori((c.x + alcance) / CELULA) + 1):
				var celula := Vector2i(cx, cy)
				if not grade.has(celula):
					grade[celula] = []
				grade[celula].append(i)
	# A faixa da porta até a rua.
	for nome_lote in wb._lotes:
		if not wb.ancoras.has(nome_lote) or not wb.ancoras.has(String(nome_lote) + "Frente"):
			continue
		var centro: Vector3 = wb.ancoras[nome_lote]
		var frente: Vector3 = wb.ancoras[String(nome_lote) + "Frente"]
		var porta3: Vector3 = centro + frente * wb._raio_do_lote(String(wb._lotes[nome_lote].get("chave", ""))) * 0.55
		var porta := Vector2(porta3.x, porta3.z)
		var rua: Vector2 = regiao._ponto_mais_perto_das_ruas(porta, 40.0)
		if rua.is_finite():
			segmentos.append(_segmento(porta, rua, float(regras.get("porta", 2.5)), "porta"))
	# As veredas: da rua até o lugar para onde elas levam.
	for vereda: Dictionary in receitas.get("veredas", []):
		var destino: Variant = wb.ancoras.get(String(vereda.get("para", "")))
		if not destino is Vector3:
			continue
		var alvo := Vector2((destino as Vector3).x, (destino as Vector3).z)
		var saida := Vector2.INF
		var menor := INF
		for estrada: Dictionary in regiao._roads:
			if String(estrada.name) != String(vereda.get("de", "")):
				continue
			var pontos: PackedVector2Array = estrada.points
			for i in pontos.size() - 1:
				var q := Geometry2D.get_closest_point_to_segment(alvo, pontos[i], pontos[i + 1])
				if q.distance_to(alvo) < menor:
					menor = q.distance_to(alvo)
					saida = q
		if saida.is_finite():
			segmentos.append(_segmento(saida, alvo, float(regras.get("vereda", 1.5)), "vereda"))
	var reservas := {
		"circulos": circulos, "tipos": tipos, "grade": grade, "segmentos": segmentos,
		"terra": func(p: Vector2) -> bool: return Geometry2D.is_point_in_polygon(p, regiao._land),
		"rua": func(p: Vector2) -> float: return regiao._distancia_da_rua(p),
		"costa": func(p: Vector2) -> float:
			return regiao._distancia_costa(p, MARGEM_DA_COSTA) if (regiao._costa_limites as Rect2).grow(MARGEM_DA_COSTA).has_point(p) else INF,
		"rio": _medidor_de_rios(regiao),
	}
	var voo := _corredor_do_voo()
	if not voo.is_empty():
		reservas["voo"] = voo
	return reservas


static func _segmento(a: Vector2, b: Vector2, folga: float, tipo: String) -> Dictionary:
	return {"a": a, "b": b, "folga": folga, "tipo": tipo, "caixa": Rect2(a, Vector2.ZERO).expand(b)}


## O corredor do sobrevoo do menu: o traçado do olho (`data/sobrevoo_menu.json`)
## em x e z, com uma amostra a cada ~6 u.
static func _corredor_do_voo() -> Dictionary:
	var arquivo := FileAccess.open(SOBREVOO, FileAccess.READ)
	if arquivo == null:
		return {}
	var dados: Variant = JSON.parse_string(arquivo.get_as_text())
	if not dados is Dictionary or not (dados as Dictionary).has("olho"):
		return {}
	var pontos := PackedVector2Array()
	for amostra: Array in (dados as Dictionary)["olho"]:
		var ponto := Vector2(float(amostra[0]), float(amostra[2]))
		if pontos.is_empty() or ponto.distance_to(pontos[pontos.size() - 1]) >= 6.0:
			pontos.append(ponto)
	if pontos.size() < 2:
		return {}
	return {"pontos": pontos, "caixa": _caixa(pontos)}


## Mede um ponto contra os rios: Vector3(distância da margem da água, posição ao
## longo do rio, número do rio). Com uma grade de segmentos, para custar pouco.
static func _medidor_de_rios(regiao: Node3D) -> Callable:
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	var meia := PackedFloat64Array()
	var arco := PackedFloat64Array()
	var numero := PackedInt32Array()
	var grade := {}
	var celula := 16.0
	var margem := 24.0
	for r in regiao._rivers.size():
		var rio: Dictionary = regiao._rivers[r]
		var pontos: PackedVector2Array = rio.points
		var andado := 0.0
		for i in pontos.size() - 1:
			var id := a.size()
			a.append(pontos[i])
			b.append(pontos[i + 1])
			meia.append(float(rio.width) * 0.5)
			arco.append(andado)
			numero.append(r)
			andado += pontos[i].distance_to(pontos[i + 1])
			var caixa := Rect2(pontos[i], Vector2.ZERO).expand(pontos[i + 1]).grow(margem + float(rio.width) * 0.5)
			for cy in range(floori(caixa.position.y / celula), floori(caixa.end.y / celula) + 1):
				for cx in range(floori(caixa.position.x / celula), floori(caixa.end.x / celula) + 1):
					var chave := Vector2i(cx, cy)
					if not grade.has(chave):
						grade[chave] = []
					grade[chave].append(id)
	return func(p: Vector2) -> Vector3:
		var lista: Variant = grade.get(Vector2i(floori(p.x / celula), floori(p.y / celula)))
		var melhor := Vector3(INF, 0.0, -1.0)
		if lista == null:
			return melhor
		for id: int in lista:
			var segmento := b[id] - a[id]
			var comprimento := segmento.length_squared()
			var t := 0.0 if comprimento < 0.000001 else clampf((p - a[id]).dot(segmento) / comprimento, 0.0, 1.0)
			var d := p.distance_to(a[id] + segmento * t) - meia[id]
			if d < melhor.x:
				melhor = Vector3(d, arco[id] + t * sqrt(comprimento), float(numero[id]))
		return melhor


# --- O plantio ---------------------------------------------------------------------

## Põe os pés no vale: uma MultiMesh por espécie e por LOD, em blocos (como a
## mata) — `Paisagismo: <chave>` —, e as espécies com tronco no conjunto de
## troncos da região (`_tree_trunks`): colisão, corte, navegação e o folhiço
## no chão seguem valendo. Devolve {"plantados", "troncos"}.
static func plantar(regiao: Node3D, plantas: Array, receitas: Dictionary) -> Dictionary:
	var info: Dictionary = receitas.get("info_das_especies", {})
	var grupos := {}
	for planta: Dictionary in plantas:
		var chave := "%s|%d" % [planta["chave"], int(planta["lod"])]
		if not grupos.has(chave):
			grupos[chave] = []
		grupos[chave].append(planta)
	# O nível fixo do mar, e não `water_level()`: a maré muda a cada hora e a plantação não pode mudar com ela.
	var nivel_da_agua: float = regiao.SEA_SURFACE_Y
	var plantados := 0
	var troncos := 0
	for grupo in grupos:
		var lista: Array = grupos[grupo]
		var especie: String = lista[0]["chave"]
		var lod := float(lista[0]["lod"])
		var modelo: Dictionary = CatalogoAssets.malha(especie, 1.0) if CatalogoAssets.tem_tripo(especie) else {}
		if modelo.is_empty():
			continue
		var dados: Dictionary = info[especie]
		var base: Transform3D = modelo.base
		var transforms: Array[Transform3D] = []
		var registros: Array[int] = []
		for planta: Dictionary in lista:
			var ponto: Vector2 = planta["ponto"]
			var chao: float = regiao.ground_height_at(Vector3(ponto.x, 0.0, ponto.y))
			if chao < nivel_da_agua + FOLGA_DA_AGUA:
				continue
			var escala := float(planta["escala"])
			var transformacao := Transform3D(Basis.from_euler(Vector3(0.0, float(planta["giro"]), 0.0)).scaled(Vector3.ONE * escala), Vector3(ponto.x, chao - regiao.ARVORE_AFUNDADA, ponto.y)) * base
			transforms.append(transformacao)
			if bool(dados.get("tronco", false)):
				regiao._tree_trunks.append({"point": ponto, "ground": chao, "height": minf(float(modelo.altura) * escala, 4.0),
					"radius": float(dados.get("raio", 0.3)) * escala, "especie": String(dados.get("ficha", especie)),
					"transformacao": transformacao, "paisagismo": true})
				registros.append(regiao._tree_trunks.size() - 1)
				troncos += 1
		if transforms.is_empty():
			continue
		plantados += transforms.size()
		# O LOD no nome: a mesma espécie com dois alcances (o capim de forro e o de corredor) não pode repetir nome de bloco.
		regiao._multimesh_em_blocos("Paisagismo: %s %d" % [especie, int(lod)], modelo.mesh, transforms, lod, registros)
	return {"plantados": plantados, "troncos": troncos}


# --- Os adereços de roça e de quintal ----------------------------------------------------

## O PLANO INTEIRO do vale montado: as reservas, os adereços (cerca, porteira,
## estaleiro de fumo, carro de boi, monjolo, barraca de feira) e os pés, que
## planejam em volta dos adereços. {"reservas", "aderecos", "plantas"}.
static func planejar(wb: Node, zonas: Array, receitas: Dictionary) -> Dictionary:
	var reservas := reservas_do_mundo(wb, receitas)
	var itens := aderecos(wb, zonas, receitas, reservas)
	reservas = com_circulos(reservas, itens)
	return {"reservas": reservas, "aderecos": itens, "plantas": gerar(zonas, receitas, reservas)}


## Uma cópia das reservas com um círculo para cada adereço: os pés das zonas
## respeitam o chão que o estaleiro, a barraca e a cerca ocupam.
static func com_circulos(reservas: Dictionary, itens: Array) -> Dictionary:
	var nova := reservas.duplicate()
	var circulos: Array = (reservas["circulos"] as Array).duplicate()
	var tipos: PackedStringArray = (reservas["tipos"] as PackedStringArray).duplicate()
	var grade := {}
	for celula in (reservas["grade"] as Dictionary):
		grade[celula] = (reservas["grade"][celula] as Array).duplicate()
	for item: Dictionary in itens:
		var ponto: Vector2 = item["ponto"]
		var raio := float(item.get("raio", 1.0))
		circulos.append(Vector4(ponto.x, ponto.y, raio, 0.5))
		tipos.append("adereco")
		var indice := circulos.size() - 1
		var alcance := raio + 0.5 * COPA_MAXIMA
		for cy in range(floori((ponto.y - alcance) / CELULA), floori((ponto.y + alcance) / CELULA) + 1):
			for cx in range(floori((ponto.x - alcance) / CELULA), floori((ponto.x + alcance) / CELULA) + 1):
				var celula := Vector2i(cx, cy)
				if not grade.has(celula):
					grade[celula] = []
				grade[celula].append(indice)
	nova["circulos"] = circulos
	nova["tipos"] = tipos
	nova["grade"] = grade
	return nova


## Os pontos do contorno a cada `passo` de perímetro, do primeiro vértice em diante.
static func _amostras_do_perimetro(poligono: PackedVector2Array, passo: float) -> PackedVector2Array:
	var saida := PackedVector2Array()
	var falta := 0.0
	for i in poligono.size():
		var a := poligono[i]
		var b := poligono[(i + 1) % poligono.size()]
		var comprimento := a.distance_to(b)
		var andado := falta
		while andado <= comprimento:
			saida.append(a.lerp(b, andado / comprimento) if comprimento > 0.0001 else a)
			andado += passo
		falta = andado - comprimento
	return saida


static func _no_corredor(reservas: Dictionary, regras: Dictionary, p: Vector2, folga: float) -> bool:
	return reservas.has("voo") and no_corredor_do_voo(reservas["voo"], p, folga, regras)


## Cabe uma peça grande de pegada `raio` em `p`? Pelas reservas e, sendo alta, fora
## do corredor do sobrevoo.
static func _cabe(reservas: Dictionary, regras: Dictionary, p: Vector2, raio: float, alta: bool, beira: bool = false) -> bool:
	if bloqueado(reservas, regras, p, raio, beira) != "":
		return false
	return not (alta and _no_corredor(reservas, regras, p, raio))


static func _tem(lista: Array, chave: String) -> bool:
	for item: Dictionary in lista:
		if item["chave"] == chave:
			return true
	return false


static func _area(poligono: PackedVector2Array) -> float:
	var soma := 0.0
	for i in poligono.size():
		var a := poligono[i]
		var b := poligono[(i + 1) % poligono.size()]
		soma += a.x * b.y - b.x * a.y
	return soma * 0.5


static func _item(chave: String, ponto: Vector2, giro: float, zona: String, raio: float, corpo: bool) -> Dictionary:
	return {"chave": chave, "ponto": ponto, "giro": giro, "zona": zona, "raio": raio, "corpo": corpo}


## Os adereços do vale: [{"chave", "ponto", "giro", "zona", "raio", "corpo"}].
## Determinístico: nada é sorteado, tudo sai da forma das zonas e das reservas.
static func aderecos(wb: Node, zonas: Array, receitas: Dictionary, reservas: Dictionary) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var config: Dictionary = receitas.get("aderecos", {})
	if config.is_empty() or reservas.is_empty():
		return saida
	var regras: Dictionary = receitas.get("reservas", {})
	var rua: Variant = reservas.get("rua")
	var rio: Variant = reservas.get("rio")
	var cerca: Dictionary = config.get("cerca", {})
	var porteira: Dictionary = config.get("porteira", {})
	var carro: Dictionary = config.get("carro_de_boi", {})
	var estaleiro: Dictionary = config.get("estaleiro_fumo", {})
	var monjolo: Dictionary = config.get("monjolo", {})
	var zona_do_carro := ""
	var area_do_carro := 0.0
	for zona: Dictionary in zonas:
		if not bool(zona.get("ativa", true)):
			continue
		var nome := String(zona["nome"])
		var poligono: PackedVector2Array = zona["poligono"]
		var receita := String(zona.get("receita", ""))
		var area := absf(_area(poligono))
		if not carro.is_empty() and receita == String(carro.get("receita", "")) and area > area_do_carro:
			area_do_carro = area
			zona_do_carro = nome
		# A CERCA DE VARAS em volta da roça, com a porteira onde a roça chega mais perto da rua.
		if not cerca.is_empty() and (cerca.get("receitas", []) as Array).has(receita):
			var amostras := _amostras_do_perimetro(poligono, float(cerca.get("passo", 3.0)))
			var portao := -1
			var menor := float(porteira.get("alcance_da_rua", 8.0))
			if not porteira.is_empty() and rua is Callable:
				for i in amostras.size():
					var d := float((rua as Callable).call(amostras[i]))
					if d < menor and _cabe(reservas, regras, (amostras[i] + amostras[(i + 1) % amostras.size()]) * 0.5, 1.2, true):
						menor = d
						portao = i
			var n := amostras.size()
			for i in n:
				var a := amostras[i]
				var b := amostras[(i + 1) % n]
				var direcao := b - a
				if direcao.length_squared() < 0.01:
					continue
				var meio := (a + b) * 0.5
				var giro := atan2(-direcao.y, direcao.x)
				if i == portao:
					saida.append(_item(String(porteira.get("chave", "porteira")), meio, giro, nome, 1.8, true))
					continue
				if portao >= 0 and (i == (portao + 1) % n or i == (portao + n - 1) % n):
					continue
				if bloqueado(reservas, regras, meio, float(cerca.get("folga", 0.6))) != "":
					continue
				saida.append(_item(String(cerca.get("chave", "cerca_varas")), meio, giro, nome, 0.9, false))
		# O ESTALEIRO DE FUMO dentro da roça de fumo.
		if not estaleiro.is_empty() and receita == String(estaleiro.get("receita", "")):
			var raio := float(estaleiro.get("raio", 2.6))
			var centro := _caixa(poligono).get_center()
			var candidatos: Array[Vector2] = []
			for miolo: PackedVector2Array in Geometry2D.offset_polygon(poligono, -float(estaleiro.get("recuo", 7.0))):
				var caixa := _caixa(miolo)
				var z := caixa.position.y
				while z < caixa.end.y:
					var x := caixa.position.x
					while x < caixa.end.x:
						if Geometry2D.is_point_in_polygon(Vector2(x, z), miolo):
							candidatos.append(Vector2(x, z))
						x += 3.0
					z += 3.0
			candidatos.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.distance_squared_to(centro) < q.distance_squared_to(centro))
			var postos: Array[Vector2] = []
			for p in candidatos:
				if postos.size() >= int(estaleiro.get("quantidade", 2)):
					break
				if not _cabe(reservas, regras, p, raio, true):
					continue
				var longe := true
				for q in postos:
					if p.distance_to(q) < float(estaleiro.get("afastar", 14.0)):
						longe = false
				if longe:
					postos.append(p)
					saida.append(_item(String(estaleiro.get("chave", "estaleiro_fumo")), p, -deg_to_rad(float(zona.get("rumo_graus", 0.0))), nome, raio, true))
		# O MONJOLO na beira do rio, na mata ciliar.
		if not monjolo.is_empty() and receita == String(monjolo.get("receita", "")) and rio is Callable and not _tem(saida, String(monjolo.get("chave", "monjolo"))):
			var raio_do_monjolo := float(monjolo.get("raio", 2.8))
			var faixa: Array = monjolo.get("beira", [2.6, 4.0])
			var caixa_da_zona := _caixa(poligono)
			var medidor: Callable = rio
			var z := caixa_da_zona.position.y
			var achou := false
			while z < caixa_da_zona.end.y and not achou:
				var x := caixa_da_zona.position.x
				while x < caixa_da_zona.end.x and not achou:
					var p := Vector2(x, z)
					x += 1.5
					if not Geometry2D.is_point_in_polygon(p, poligono):
						continue
					var perto: Vector3 = medidor.call(p)
					if perto.x < float(faixa[0]) or perto.x > float(faixa[1]):
						continue
					if not _cabe(reservas, regras, p, raio_do_monjolo, true, true):
						continue
					# A margem corre perpendicular ao gradiente da distância: o monjolo deita ao longo dela.
					var gx: float = (medidor.call(p + Vector2(0.5, 0.0)) as Vector3).x - (medidor.call(p - Vector2(0.5, 0.0)) as Vector3).x
					var gz: float = (medidor.call(p + Vector2(0.0, 0.5)) as Vector3).x - (medidor.call(p - Vector2(0.0, 0.5)) as Vector3).x
					var normal := Vector2(gx, gz)
					if normal.length_squared() < 0.0001:
						continue
					var tangente := normal.normalized().orthogonal()
					saida.append(_item(String(monjolo.get("chave", "monjolo")), p, atan2(-tangente.y, tangente.x), nome, raio_do_monjolo, true))
					achou = true
				z += 1.5
	# O CARRO DE BOI parado junto da estrada, na beira da maior roça de mandioca.
	if not carro.is_empty() and zona_do_carro != "" and rua is Callable:
		for zona: Dictionary in zonas:
			if String(zona["nome"]) != zona_do_carro:
				continue
			var poligono: PackedVector2Array = zona["poligono"]
			var raio_do_carro := float(carro.get("raio", 2.6))
			var melhor := INF
			var escolhido := {}
			var amostras := _amostras_do_perimetro(poligono, 3.0)
			for i in amostras.size():
				var a := amostras[i]
				var b := amostras[(i + 1) % amostras.size()]
				var direcao := b - a
				if direcao.length_squared() < 0.01:
					continue
				var normal := direcao.normalized().orthogonal()
				for sinal in [1.0, -1.0]:
					var p: Vector2 = (a + b) * 0.5 + normal * float(sinal) * float(carro.get("fora", 3.8))
					if Geometry2D.is_point_in_polygon(p, poligono):
						continue
					var d := float((rua as Callable).call(p))
					if d >= float(carro.get("alcance_da_rua", 8.0)) or d >= melhor:
						continue
					if not _cabe(reservas, regras, p, raio_do_carro, false):
						continue
					melhor = d
					escolhido = _item(String(carro.get("chave", "carro_de_boi")), p, atan2(-direcao.y, direcao.x) + PI * 0.5, zona_do_carro, raio_do_carro, true)
			if not escolhido.is_empty():
				saida.append(escolhido)
	# A BARRACA DE FEIRA na praça.
	var barraca: Dictionary = config.get("barraca_feira", {})
	if not barraca.is_empty():
		saida.append_array(_barracas_da_praca(wb, reservas, regras, barraca))
	return saida


## As barracas da feira, na praça, de frente para o centro dela: nos pontos da
## praça mais perto do centro que cabem — longe das âncoras (o poço, o cruzeiro),
## dos bancos e das casas, e a um palmo da rua.
static func _barracas_da_praca(wb: Node, reservas: Dictionary, regras: Dictionary, config: Dictionary) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var regiao: Node3D = wb._region
	var centro3: Vector3 = regiao.get_feature_center("Praça", "poi")
	var centro := Vector2(centro3.x, centro3.z)
	var praca := PackedVector2Array()
	for area: PackedVector2Array in regiao._open_areas:
		if area.size() >= 3 and Geometry2D.is_point_in_polygon(centro, area):
			praca = area
	if praca.is_empty():
		return saida
	var raio := float(config.get("raio", 1.8))
	var folga := float(config.get("folga_das_pecas", 4.5))
	var candidatos: Array[Vector2] = []
	var caixa := _caixa(praca)
	var z := caixa.position.y
	while z < caixa.end.y:
		var x := caixa.position.x
		while x < caixa.end.x:
			if Geometry2D.is_point_in_polygon(Vector2(x, z), praca):
				candidatos.append(Vector2(x, z))
			x += 1.5
		z += 1.5
	candidatos.sort_custom(func(p: Vector2, q: Vector2) -> bool:
		var dp := p.distance_squared_to(centro)
		var dq := q.distance_squared_to(centro)
		if not is_equal_approx(dp, dq):
			return dp < dq
		return p.x < q.x if not is_equal_approx(p.x, q.x) else p.y < q.y)
	var circulos: Array = reservas.get("circulos", [])
	var tipos: PackedStringArray = reservas.get("tipos", PackedStringArray())
	var rua: Variant = reservas.get("rua")
	for p in candidatos:
		if saida.size() >= int(config.get("quantidade", 2)):
			break
		if p.distance_to(centro) < float(config.get("raio_minimo", 5.0)):
			continue
		var livre := true
		for i in circulos.size():
			var c: Vector4 = circulos[i]
			# O que a praça já tem — âncora, nomeada, casa, tronco —, pelo centro e não pela folga.
			if tipos[i] != "lote" and p.distance_to(Vector2(c.x, c.y)) < folga + (c.z if tipos[i] == "casa" else 0.0):
				livre = false
				break
		if not livre:
			continue
		if rua is Callable and float((rua as Callable).call(p)) < float(config.get("rua_minima", 1.5)):
			continue
		var proxima := false
		for item: Dictionary in saida:
			if p.distance_to(item["ponto"]) < float(config.get("afastar", 7.0)):
				proxima = true
		if proxima or _no_corredor(reservas, regras, p, raio):
			continue
		var para_o_centro := centro - p
		var barraca := _item(String(config.get("chave", "barraca_feira")), p, atan2(para_o_centro.x, para_o_centro.y), "Praça", raio, true)
		barraca["rua_minima"] = float(config.get("rua_minima", 1.5))
		saida.append(barraca)
	return saida


## Põe os adereços no mundo: o que tem corpo (porteira, estaleiro, carro de boi,
## monjolo, barraca) como peça com colisão do catálogo; a cerca, que não tem, em
## MultiMesh na região (`plantar_cercas`).
static func plantar_aderecos(wb: Node, itens: Array, receitas: Dictionary) -> int:
	var postos := 0
	for item: Dictionary in itens:
		if not bool(item["corpo"]):
			continue
		var chave: String = item["chave"]
		var ponto: Vector2 = item["ponto"]
		if not CatalogoAssets.tem_tripo(chave):
			continue
		var chao: Vector3 = wb.ground_position(Vector3(ponto.x, 0.0, ponto.y))
		var no := CatalogoAssets.instanciar(chave, wb, chao, 1.0, float(item["giro"]))
		if no == null:
			continue
		no.name = "Paisagismo: %s %d" % [chave, postos]
		no.set_meta("paisagismo", true)
		CatalogoAssets.colisao(chave, no, wb, chao, 1.0, float(item["giro"]))
		postos += 1
	plantar_cercas(wb._region, itens, receitas)
	return postos


## As cercas de varas (os adereços sem corpo), em blocos de MultiMesh na região,
## como a mata. É o que a cópia do sobrevoo (`extrair_geometria.gd`) replanta.
static func plantar_cercas(regiao: Node3D, itens: Array, receitas: Dictionary) -> void:
	var cercas := {}
	for item: Dictionary in itens:
		if bool(item["corpo"]) or not CatalogoAssets.tem_tripo(String(item["chave"])):
			continue
		if not cercas.has(item["chave"]):
			cercas[item["chave"]] = []
		cercas[item["chave"]].append(item)
	var lod := float(((receitas.get("aderecos", {}) as Dictionary).get("cerca", {}) as Dictionary).get("lod", 110.0))
	for chave in cercas:
		var modelo: Dictionary = CatalogoAssets.malha(chave, 1.0)
		if modelo.is_empty():
			continue
		var transforms: Array[Transform3D] = []
		for item: Dictionary in cercas[chave]:
			var ponto: Vector2 = item["ponto"]
			var chao: float = regiao.ground_height_at(Vector3(ponto.x, 0.0, ponto.y))
			transforms.append(Transform3D(Basis.from_euler(Vector3(0.0, float(item["giro"]), 0.0)), Vector3(ponto.x, chao - 0.02, ponto.y)) * (modelo.base as Transform3D))
		regiao._multimesh_em_blocos("Paisagismo: " + String(chave), modelo.mesh, transforms, lod)
