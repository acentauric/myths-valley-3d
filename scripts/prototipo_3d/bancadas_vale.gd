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
##
## O E TAMBÉM TOCA OBRA (`raio_do_e`): "não consegui interagir com o poço, logo
## essa missão quebrou". As obras do arraial só abriam no J, e o poço — onde o
## Pedro, a Dona Zefa e o Cosme ficam em volta — respondia ao E com a conversa de
## quem estivesse mais perto. O sítio que tem `raio_do_e` acende a dica da tecla e
## abre a aba de obras dele (`tecla_das_bancadas.gd`), e esse raio é MENOR que o
## do J, que é o do lugar inteiro (o cemitério vale o outeiro todo no J, e a dica
## acesa no outeiro todo brigaria com as lápides).
##
## NÃO ENTRAM o trapiche, a casa e o armazém: o ponto do trapiche é onde o Tonho
## fica parado (o E dele seria engolido), a casa e o armazém têm a porta e o
## balcão, e a oficina e o canteiro já respondem ao E como bancada.

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
	# O CANTEIRO DE OBRAS, provisório como a oficina e do lado dela: a mesa do
	# prumo, onde se risca a obra (`canteiro_prancheta` abate o material de toda
	# obra do mapa). A construção de verdade, com telheiro e guincho, é do Tripo.
	"canteiro": {"ancora": "Canteiro de obras", "raio": 3.0, "provisoria": true},
	"armazem": {"ancora": "Venda do Bar", "peca": "venda"},
	# O E do mirante cobre a plataforma de seis passos e a volta dela (a âncora é
	# o centro, e ninguém fica em cima do centro).
	"mirante": {"ancora": "Mirante", "raio": 8.0, "raio_do_e": 5.5},
	# O E do poço: a âncora é o poço, de cilindro de 0,8 — o chão livre começa a
	# dois passos dele, e o anel de moradores do mutirão fica a 2,4.
	"poco": {"ancora": "Poço", "raio": 4.0, "raio_do_e": 3.5},
	"trapiche": {"ancora": "PierPiso", "raio": 6.0},
	# A CARROÇA DO SEU BENEDITO, que dá nome à casa dele ("do carro quebrado"):
	# a obra do arraial "Recuperar a carroça" se toca no terreiro dele, e é o
	# fim do mutirão da carroça (data/missoes_carroca.json). O modelo da
	# carroça, quebrada e consertada, é do Tripo (#29). O E vale da parede para
	# fora: a casa tem cinco passos de largura, e o chão livre começa a três da
	# âncora, que é o centro dela.
	"carroca": {"ancora": "Casa de Carro Quebrado", "peca": "casa_carro_quebrado", "raio_do_e": 5.0},
	# O CERCADO DO CEMITÉRIO, o fim da missão do Damião: a aba vale no outeiro
	# inteiro, de dentro do cercado que vai subir (`cemiterio_vale.gd`). O E vale
	# do centro das covas até seis passos: dentro da cerca, que fica a oito e
	# meio, mas não no outeiro todo, onde as lápides têm o E delas.
	"cemiterio": {"ancora": "Cemitério", "raio": 12.0, "raio_do_e": 6.0},
	# A PONTE DO RIO GRANDE, cercada até a obra (`ponte_vale.gd`,
	# data/missoes_ponte.json): a aba vale nas duas cabeceiras, do lado de fora
	# da cerca. A âncora é o meio da ponte, e a cerca fica a quase cinco passos
	# dele (metade dos nove da ponte, mais a folga), então o E precisa passar
	# disso para valer do lado de fora dela.
	"ponte": {"ancora": "Ponte", "raio": 9.0, "raio_do_e": 7.5, "nome": "ponte do rio grande"},
}

const FALTAM := {
	"oficio": "a casa de farinha, o engenho e a cabana de pesca são do roçado e do rio (#27)",
	"forno_barro": "o forno do arraial ainda não foi posto no vale (#27)",
	"monjolo": "o monjolo fica na beira do rio grande, e ninguém o pôs lá ainda (#23)",
}


## O nome da construção na aba de obras: o do `Jogo` (o arquivo do 2D), ou o que
## a construção do vale traz — a ponte do rio grande não existe no 2D como obra.
static func nome(qual: String) -> String:
	var bancada := _bancada(qual)
	if bancada.has("nome"):
		return str(bancada["nome"])
	return Jogo.nome_da_construcao(qual)


static func _bancada(qual: String) -> Dictionary:
	return BANCADAS.get(qual, OBRAS.get(qual, {}))


static func raio(qual: String) -> float:
	var bancada := _bancada(qual)
	if bancada.has("raio"):
		return float(bancada["raio"])
	var peca: Dictionary = CatalogoAssets.PECAS.get(str(bancada.get("peca", "")), {})
	return float(peca.get("largura", 6.0)) * 0.5 + FOLGA


## Os sítios de obra que respondem ao E (`raio_do_e`), na ordem de `OBRAS`.
static func com_e() -> Array[String]:
	var lista: Array[String] = []
	for qual in OBRAS:
		if (OBRAS[qual] as Dictionary).has("raio_do_e"):
			lista.append(str(qual))
	return lista


## De quão perto o E toca a obra deste sítio; 0 se o E não responde ali.
static func raio_do_e(qual: String) -> float:
	return float(_bancada(qual).get("raio_do_e", 0.0))


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


## AS BANCADAS DE QUEM AINDA NÃO TEM CONSTRUÇÃO, no chão: a oficina é uma
## bancada na beira do roçado até a construção dela chegar (#27) — o trato da
## criatura (#14): a mecânica não espera o modelo.
##
## Era uma caixa cinza sem corpo, "marca, não parede". Quem jogou leu outra
## coisa: "a bancada não tem asset e não consegui interagir". Agora, no estilo
## Tripo, é a peça `bancada_oficina` do catálogo (a mesa rústica, sólida); no
## procedural, que é só comparação e não ganha arte nova, a caixa cinza ganhou
## corpo. Na beira do roçado, uma bancada de metro e meio não fecha caminho.
## Quem abre a oficina é o E (`tecla_das_bancadas.gd`) ou o J.
static func montar_as_provisorias(world, pai: Node) -> void:
	for qual in OBRAS:
		if not bool(OBRAS[qual].get("provisoria", false)):
			continue
		var ponto := ponto_da_provisoria(world, str(qual))
		if not ponto.is_finite():
			continue
		var peca := "bancada_" + str(qual)
		var bancada: Node3D = null
		if bool(world.call("estilo_tripo")) and CatalogoAssets.PECAS.has(peca):
			bancada = CatalogoAssets.instanciar(peca, pai, ponto)
			if bancada != null:
				CatalogoAssets.colisao(peca, bancada, pai, ponto)
		if bancada == null:
			bancada = _caixa_provisoria(pai, ponto)
		bancada.name = "Bancada_%s" % qual


static func _caixa_provisoria(pai: Node, ponto: Vector3) -> Node3D:
	var medida := Vector3(1.4, 0.85, 0.7)
	var bancada := MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = medida
	bancada.mesh = caixa
	var tinta := StandardMaterial3D.new()
	tinta.albedo_color = Color(0.52, 0.53, 0.52)
	bancada.material_override = tinta
	var corpo := StaticBody3D.new()
	corpo.name = "Corpo"
	var forma := CollisionShape3D.new()
	var caixa_do_corpo := BoxShape3D.new()
	caixa_do_corpo.size = medida
	forma.shape = caixa_do_corpo
	corpo.add_child(forma)
	bancada.add_child(corpo)
	pai.add_child(bancada)
	bancada.global_position = ponto + Vector3(0.0, medida.y * 0.5, 0.0)
	return bancada
