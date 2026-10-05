extends RefCounted
## A MATA EM MANCHAS: que espécie nasce em cada ponto da mata (estilo Tripo).
##
## O sorteio uniforme deixava a mata sal-e-pimenta: só 19% dos vizinhos de uma
## árvore eram da mesma espécie, e a serra, a baixada e a beira do rio tinham as
## mesmas proporções — piaçava de restinga no topo do morro, 1.506 gameleiras de
## Iroko espalhadas pelo vale. Mata de verdade é feita de manchas: um jatobazal
## na baixada, uma encosta de jequitibás, ingás e jenipapos ao longo do rio.
##
## Aqui cada ponto ganha uma CLASSE pelo lugar (restinga, beira de rio, borda de
## rua, topo, encosta, baixada, a Mata do mapa) e uma MANCHA de Voronoi de uns
## 44 u, que escolhe a espécie dominante da classe. Dentro da mancha, moitas de
## 16 u: três em cada quatro são da dominante e a quarta de uma companheira, em
## bloco — árvore companheira solta no meio da dominante era a mesma mistura de
## antes. Tudo sai de hash da posição, sem número nenhum da fila do plantio.
##
## O SORTEIO DA FILA CONTINUA SENDO TIRADO (`rng.randi_range` em `_build_forest`):
## é ele que mantém, bit a bit, as posições, o sub-bosque, o rio e a orla que vêm
## depois. Ele só decide na borda das ruas, que é mata pioneira misturada
## (embaúba com aroeira, árvore a árvore).
##
## As chaves são as ESPÉCIES (ficha, madeira e corte leem essas); a malha que se
## planta é a versão leve do Tripo quando existe (`malha`): a mesma forma e a
## mesma textura com 3,4 a 6 mil faces, no lugar das 12 a 16 mil.
## Coqueiro e mangue são da orla e nunca entram aqui.

const LADO_DA_MANCHA := 44.0
const LADO_DA_MOITA := 16.0
## Fração das moitas de uma mancha que é da espécie dominante.
const DOMINANTE := 0.75
## Faixas da classe, em unidades.
const RESTINGA_ATE_A_COSTA := 30.0
const CILIAR_ATE_O_RIO := 20.0
const BORDA_ATE_A_RUA := 6.0
const TOPO_ACIMA_DE := 30.0
const ENCOSTA_ACIMA_DE := 10.0

## Paletas por classe: a dominante da mancha sai de "dominantes" (repetir uma
## espécie dá peso a ela) e a moita companheira de "companheiras". "sal"
## separa o hash de cada classe, para as manchas de classes vizinhas não
## coincidirem.
const PALETAS := {
	# A Mata desenhada no mapa, em volta da gameleira: restinga arbórea.
	"mata_do_mapa": {"sal": 11, "dominantes": ["clusia", "aroeira", "pitangueira"], "companheiras": ["cajueiro", "piacava"]},
	"restinga": {"sal": 23, "dominantes": ["piacava", "piacava", "clusia", "cajueiro"], "companheiras": ["aroeira", "pitangueira"]},
	"ciliar": {"sal": 37, "dominantes": ["ingazeiro", "ingazeiro", "jenipapeiro"], "companheiras": ["embauba", "dendezeiro"]},
	# Borda de rua e da vila: pioneira, árvore a árvore (o sorteio da fila).
	"borda": {"sal": 41, "dominantes": ["embauba"], "companheiras": ["aroeira"]},
	"topo": {"sal": 53, "dominantes": ["angico", "aroeira", "angico"], "companheiras": ["ipe_amarelo", "embauba"]},
	"encosta": {"sal": 67, "dominantes": ["mata_alta", "jequitiba", "massaranduba", "jatoba"], "companheiras": ["embauba", "embauba", "ipe_amarelo", "pau_brasil"]},
	"baixada": {"sal": 79, "dominantes": ["jatoba", "jatoba", "jequitiba", "jenipapeiro"], "companheiras": ["jaqueira", "dendezeiro", "embauba"]},
}


## A classe do ponto pelas medidas do lugar: {"no_mapa": bool (dentro da Mata do
## KML), "costa", "rio", "rua": distâncias em u (INF quando longe), "vila": bool
## (a menos de BORDA_ATE_A_RUA do contorno da vila), "altura": chão em u}.
static func classe(medidas: Dictionary) -> String:
	if bool(medidas.get("no_mapa", false)):
		return "mata_do_mapa"
	if float(medidas.get("costa", INF)) < RESTINGA_ATE_A_COSTA:
		return "restinga"
	if float(medidas.get("rio", INF)) < CILIAR_ATE_O_RIO:
		return "ciliar"
	if float(medidas.get("rua", INF)) < BORDA_ATE_A_RUA or bool(medidas.get("vila", false)):
		return "borda"
	var altura := float(medidas.get("altura", 0.0))
	if altura > TOPO_ACIMA_DE:
		return "topo"
	if altura >= ENCOSTA_ACIMA_DE:
		return "encosta"
	return "baixada"


## A espécie do ponto: dominante da mancha ou companheira da moita. `sorteio` é o
## número da fila do plantio (0 a quantos-1); só a borda o usa.
static func especie(ponto: Vector2, sorteio: int, quantos: int, nome_da_classe: String) -> String:
	var paleta: Dictionary = PALETAS.get(nome_da_classe, PALETAS["encosta"])
	var sal := int(paleta["sal"])
	var dominantes: Array = paleta["dominantes"]
	var companheiras: Array = paleta["companheiras"]
	if nome_da_classe == "borda":
		var fracao := float(sorteio) / float(maxi(quantos, 1))
		return String(dominantes[0]) if fracao < DOMINANTE else String(companheiras[sorteio % companheiras.size()])
	var mancha := _mancha(ponto, LADO_DA_MANCHA, sal)
	var dominante := String(dominantes[mini(int(_sorte(mancha.x, mancha.y, sal + 2) * dominantes.size()), dominantes.size() - 1)])
	var moita := _mancha(ponto, LADO_DA_MOITA, sal + 5)
	if _sorte(moita.x, moita.y, sal + 7) < DOMINANTE:
		return dominante
	var outras: Array = companheiras.filter(func(nome): return nome != dominante)
	if outras.is_empty():
		return dominante
	return String(outras[mini(int(_sorte(moita.x, moita.y, sal + 8) * outras.size()), outras.size() - 1)])


## A chave da malha no catálogo: a versão leve quando o GLB dela existe.
static func malha(nome_da_especie: String) -> String:
	var leve := nome_da_especie + "_leve"
	if CatalogoAssets.tem_tripo(leve):
		return leve
	return nome_da_especie


## Toda espécie que a mata pode plantar (o portão confere a malha de cada uma).
static func todas() -> Array[String]:
	var lista: Array[String] = []
	for nome_da_classe in PALETAS:
		for chave in ["dominantes", "companheiras"]:
			for nome in PALETAS[nome_da_classe][chave]:
				if not lista.has(String(nome)):
					lista.append(String(nome))
	return lista


## A célula de Voronoi do ponto: o semeador mais perto entre as nove células da
## grade em volta, cada uma com um semeador deslocado por hash.
static func _mancha(ponto: Vector2, lado: float, sal: int) -> Vector2i:
	var cx := floori(ponto.x / lado)
	var cz := floori(ponto.y / lado)
	var melhor := Vector2i(cx, cz)
	var menor := INF
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var i := cx + dx
			var j := cz + dz
			var semeador := Vector2((float(i) + 0.15 + 0.7 * _sorte(i, j, sal)) * lado, (float(j) + 0.15 + 0.7 * _sorte(i, j, sal + 1)) * lado)
			var distancia := ponto.distance_squared_to(semeador)
			if distancia < menor:
				menor = distancia
				melhor = Vector2i(i, j)
	return melhor


## Número de 0 a 1 que só depende dos três inteiros (o mesmo em toda montagem).
static func _sorte(a: int, b: int, sal: int) -> float:
	var h := (a * 73856093) ^ (b * 19349663) ^ (sal * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65536.0
