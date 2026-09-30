extends RefCounted
## AS BANCADAS DO VALE: perto de quê cada aba de lugar do painel aparece (#19).
##
## No 2D quem liga as abas de lugar é o `Mundo`, pela célula à frente do
## jogador. No vale é a DISTÂNCIA até a âncora do lugar, medida quando o painel
## abre — com o painel aberto o jogador não anda, então não há o que remedir.
##
## O raio é o meio da largura da construção (`CatalogoAssets`) mais uns passos
## de folga: o balcão é a frente da casa, e quem encosta na parede do lado
## também está na venda.
##
## O QUE O VALE AINDA NÃO TEM mora em `FALTAM`, com a razão, no mesmo trato do
## `FALTAM_NO_VALE` do `Lugares`: dívida declarada, e não aba que some sem
## ninguém saber por quê. Quando o lugar existir, ele sai de lá e entra aqui.

const FOLGA := 3.0

## Aba de lugar → âncora do `world_builder` e peça do catálogo (para a largura).
const BANCADAS := {
	"venda": {"ancora": "Venda do Bar", "peca": "venda"},
}

const FALTAM := {
	"oficina": "a oficina é construção do roçado que o vale ainda não tem (#27); sem ela não há aba de oficina nem obra dela",
	"canteiro": "o canteiro, onde se decidem as obras, também é do roçado (#27)",
	"casa": "as obras da casa mudam o cômodo, e o vale ainda não tem cômodo nenhum (#26)",
	"cozinha": "o fogão de barro fica dentro da casa, e o vale ainda não tem cômodo (#26)",
}


static func raio(qual: String) -> float:
	var bancada: Dictionary = BANCADAS.get(qual, {})
	var peca: Dictionary = CatalogoAssets.PECAS.get(str(bancada.get("peca", "")), {})
	return float(peca.get("largura", 6.0)) * 0.5 + FOLGA


static func perto(world, ponto: Vector3, qual: String) -> bool:
	var bancada: Dictionary = BANCADAS.get(qual, {})
	if bancada.is_empty():
		return false
	var onde: Vector3 = world.ancoras.get(str(bancada["ancora"]), Vector3.INF)
	if not onde.is_finite():
		return false
	return Vector2(ponto.x - onde.x, ponto.z - onde.z).length() <= raio(qual)


## Liga no painel as abas do lugar onde o jogador está.
static func aplicar(painel, world, ponto: Vector3) -> void:
	painel.na_venda = perto(world, ponto, "venda")
	painel.na_cozinha = false
	painel.obra_em_foco = ""
