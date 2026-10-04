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
## `raio` fixo onde não há peça que diga a largura (o mirante, o poço, o píer).
const BANCADAS := {
	"venda": {"ancora": "Venda do Bar", "peca": "venda"},
	# O FOGO DO TERREIRO faz as vezes do fogão de barro (#11). No 2D o fogão
	# fica dentro da casa, e o vale não tem cômodo (#26); a fogueira é do
	# terreiro da própria Casa de taipa, e cozinhar nela é o que a issue pede
	# — o sistema funcionando antes de a lareira ter modelo. Quando houver
	# cômodo, a cozinha vai para dentro e esta linha muda de âncora.
	"cozinha": {"ancora": "Fogueira", "raio": 3.5},
}

## ONDE SE TOCA OBRA (#15): id da construção, como o `obras.json` e o
## `Jogo.NOME_DAS_CONSTRUCOES` a chamam → onde ela está no vale. Perto de uma
## delas, o painel ganha a aba de obras daquela construção.
##
## A CASA AINDA NÃO MUDA POR FORA NEM POR DENTRO: a casca troca a arte, a
## pegada e a colisão, e isso pede os modelos `casa_n1` a `casa_n3` (#27); a
## planta e a mobília mudam o cômodo, e o vale não tem cômodo (#26). O que já
## vale é o ganho da obra no corpo — o fôlego, o descanso — e o registro dela
## no save. Decisão do usuário: obra com efeito, sem esperar a arte.
const OBRAS := {
	"casa": {"ancora": "Casa de taipa", "peca": "casa_taipa"},
	# A OFICINA É PROVISÓRIA (#11): a construção dela é do Tripo (#27), e até
	# ela chegar a bancada é uma caixa cinza na beira do roçado — onde a
	# oficina fica no 2D. Serra tábua e torce corda, e a aba de obras dela vale
	# para melhorar a própria oficina, como lá.
	"oficina": {"ancora": "Oficina", "raio": 3.0, "provisoria": true},
	"armazem": {"ancora": "Venda do Bar", "peca": "venda"},
	"mirante": {"ancora": "Mirante", "raio": 8.0},
	"poco": {"ancora": "Poço", "raio": 4.0},
	"trapiche": {"ancora": "PierPiso", "raio": 6.0},
	# O CERCADO DO CEMITÉRIO, o fim da missão do Damião: a aba vale no outeiro
	# inteiro, de dentro do cercado que vai subir (`cemiterio_vale.gd`).
	"cemiterio": {"ancora": "Cemitério", "raio": 12.0},
}

const FALTAM := {
	"canteiro": "o canteiro, onde se decidem as obras e que abate o material delas, também é do roçado (#27)",
	"oficio": "a casa de farinha, o engenho e a cabana de pesca são do roçado e do rio (#27)",
	"forno_barro": "o forno do arraial ainda não foi posto no vale (#27)",
	"monjolo": "o monjolo fica na beira do rio grande, que o vale ainda não tem (#23)",
	"carroca": "a carroça do armazém ainda não foi posta no vale (#29)",
}


static func _bancada(qual: String) -> Dictionary:
	return BANCADAS.get(qual, OBRAS.get(qual, {}))


static func raio(qual: String) -> float:
	var bancada := _bancada(qual)
	if bancada.has("raio"):
		return float(bancada["raio"])
	var peca: Dictionary = CatalogoAssets.PECAS.get(str(bancada.get("peca", "")), {})
	return float(peca.get("largura", 6.0)) * 0.5 + FOLGA


## Quão longe (no chão) o ponto está da bancada; INF se ela não existe no vale.
static func distancia(world, ponto: Vector3, qual: String) -> float:
	var bancada := _bancada(qual)
	if bancada.is_empty():
		return INF
	var onde: Vector3 = world.ancoras.get(str(bancada["ancora"]), Vector3.INF)
	if not onde.is_finite():
		return INF
	return Vector2(ponto.x - onde.x, ponto.z - onde.z).length()


static func perto(world, ponto: Vector3, qual: String) -> bool:
	return distancia(world, ponto, qual) <= raio(qual)


## A construção com obra mais perto, ao alcance, ou "".
static func obra_perto(world, ponto: Vector3) -> String:
	var melhor := ""
	var melhor_d := INF
	for qual in OBRAS:
		var d := distancia(world, ponto, str(qual))
		if d <= raio(str(qual)) and d < melhor_d:
			melhor = str(qual)
			melhor_d = d
	return melhor


## Liga no painel as abas do lugar onde o jogador está.
static func aplicar(painel, world, ponto: Vector3) -> void:
	painel.na_venda = perto(world, ponto, "venda")
	# O SAVEIRO, perto do mestre Quirino no dia dele (`saveiro_vale.gd`).
	var saveiro = painel.get_tree().get_first_node_in_group("saveiro") if painel.is_inside_tree() else null
	painel.saveiro = saveiro if saveiro != null and saveiro.perto(ponto) else null
	painel.na_cozinha = perto(world, ponto, "cozinha")
	painel.obra_em_foco = obra_perto(world, ponto)


## Onde fica a bancada provisória, no chão.
static func ponto_da_provisoria(world, qual: String) -> Vector3:
	var bancada := _bancada(qual)
	var onde: Vector3 = world.ancoras.get(str(bancada.get("ancora", "")), Vector3.INF)
	return world.ground_position(onde, 0.0) if onde.is_finite() else Vector3.INF


## AS BANCADAS PROVISÓRIAS NO CHÃO: uma caixa cinza onde a construção ainda não
## tem modelo, para o jogador achar onde ela fica — o trato da criatura (#14):
## a mecânica não espera o modelo, e o modelo entra depois sem tocar nela.
## Sem colisão: é marca, não parede, e não pode fechar caminho no roçado.
static func montar_as_provisorias(world, pai: Node) -> void:
	for qual in OBRAS:
		if not bool(OBRAS[qual].get("provisoria", false)):
			continue
		var ponto := ponto_da_provisoria(world, str(qual))
		if not ponto.is_finite():
			continue
		var bancada := MeshInstance3D.new()
		bancada.name = "Bancada_%s" % qual
		var caixa := BoxMesh.new()
		caixa.size = Vector3(1.4, 0.85, 0.7)
		bancada.mesh = caixa
		var tinta := StandardMaterial3D.new()
		tinta.albedo_color = Color(0.52, 0.53, 0.52)
		bancada.material_override = tinta
		pai.add_child(bancada)
		bancada.global_position = ponto + Vector3(0.0, 0.425, 0.0)
