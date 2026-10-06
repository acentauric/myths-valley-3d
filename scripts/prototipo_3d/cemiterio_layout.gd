extends RefCounted
## O DESENHO DAS COVAS DO CEMITÉRIO: onde cada laje fica, para que lado ela
## aponta e de que tamanho é. Fonte única (`world_builder._assentar_as_covas`
## põe as lajes, `lapides.gd` tira daqui o vão por onde o coveiro passa, e o
## portão `lapides_no_chao.gd` confere o resultado).
##
## "As lápides estão mal posicionadas." A grade era a das 12 lajes do estilo
## procedural, compridas em Z, a 2,3 x 3,0 u: com a laje do Tripo, que é comprida em
## X (a cruz no -X), as lajes de uma fileira ficavam de ponta com ponta, a 0,6 e 0,86 u
## uma da outra, como uma cerca; a base seguia a altura do centro (a ponta ficava
## no ar); a mesma guinada em todas; e dois pés de capim e o posto do sacristão
## caíam dentro de laje.
##
## COMO FICA AGORA:
##   - FILEIRAS de lajes LADO A LADO no sentido leste-oeste, todas com a CABECEIRA (a
##     cruz) a OESTE e os pés a leste, que é como se enterra, e como a laje do Tripo já
##     vem (guinada 0); a procedural, comprida em Z, gira um quarto de volta para ficar igual;
##   - o corredor do meio, entre a 2ª e a 3ª fileira, fica na altura da PORTA da
##     capelinha (`_capelinha_do_cemiterio`: a leste, de frente para as covas e
##     0,6 u ao norte do centro): de lá se vê o corredor, e não o pé de uma laje;
##   - vão entre lajes de 0,9 u para mais (a cápsula do jogador tem 0,56) e corredor
##     entre fileiras de 1,3 u para mais;
##   - cada laje com um desvio de até 4 cm e uma guinada de até 3 graus, os mesmos a
##     cada montagem (sorteio por índice): a grade deixa de ser um quartel;
##   - a base de cada laje acompanha o TERRENO nos quatro cantos (`world_builder`).
##
## As posições foram achadas contra tudo o que mora no cemitério — os oito pés de
## capim e as quatro embaúbas de `data/recursos_3d.json`, as três pedras, as três
## galhadas e os postos do Damião, do padre e do sacristão de `data/npcs_3d.json` —
## de modo que nenhum cai dentro de laje (o portão `lapides_no_chao.gd` cobra).
## Mexeu aqui, rode o portão.

## Quatro fileiras de três covas: a ordem é a de `data/lapides_3d.json`, fileira por fileira.
const FILEIRAS := 4
const COLUNAS := 3
## Entre os centros de duas covas da mesma fileira (leste-oeste) e de duas fileiras
## (norte-sul), em u.
const ESPACO_X := 2.6
const ESPACO_Z := 2.3
## O centro da cova 0 (a do canto noroeste), a partir do centro do cemitério.
const ORIGEM := Vector2(-2.9, -4.05)
## O tamanho de cada laje (× o do catálogo), em diagonal, para a coluna não ter um
## tamanho só.
const TAMANHOS := [0.9, 0.98, 1.06]
## Desvio de posição (u) e de guinada (rad) de cada laje, no máximo.
const DESVIO_MAXIMO := 0.04
const GIRO_MAXIMO := 0.05
## O quanto a base afunda além do ponto do terreno que ela escolhe (u): a malha do
## chão fica até 8 cm abaixo da fórmula, e uma laje de ponta no ar é o que se vê.
const AFUNDADA := 0.045
## De onde entre o canto mais baixo e o mais alto da laje a base sai (0 = no mais
## baixo, 1 = no mais alto). O terreno inclina até 4 graus sob uma laje: a ponta alta
## entra no chão, o que ninguém vê, e a baixa não fica no ar.
const BASE_ENTRE_OS_CANTOS := 0.3


static func quantas() -> int:
	return FILEIRAS * COLUNAS


## O lugar da cova `indice`: {"fileira", "coluna", "desvio" (Vector2: x e z a partir
## do centro do cemitério), "giro" (rad, o desvio de guinada: some o de base de cada
## estilo, ver `giro_de_base`), "tamanho"}.
static func lugar(indice: int) -> Dictionary:
	var fileira := indice / COLUNAS
	var coluna := indice % COLUNAS
	var desvio := ORIGEM + Vector2(float(coluna) * ESPACO_X, float(fileira) * ESPACO_Z)
	desvio += Vector2(_sorte(indice, 1), _sorte(indice, 2)) * DESVIO_MAXIMO
	return {
		"fileira": fileira, "coluna": coluna, "desvio": desvio,
		"giro": _sorte(indice, 3) * GIRO_MAXIMO,
		"tamanho": float(TAMANHOS[(fileira + coluna) % TAMANHOS.size()]),
	}


## A guinada em que a laje fica com a cabeceira a oeste: a do Tripo, comprida em X
## e com a cruz no -X, já vem assim; a procedural, comprida em Z e com a cruz no -Z,
## gira um quarto de volta.
static func giro_de_base(tripo: bool) -> float:
	return 0.0 if tripo else PI * 0.5


## O eixo curto da laje no espaço dela, em volta do qual se levanta uma ponta (o
## conserto do Damião: `cemiterio_vale._entortar`): o Z da laje do Tripo e o X da procedural.
static func eixo_curto(tripo: bool) -> Vector3:
	return Vector3.BACK if tripo else Vector3.RIGHT


## Número de -1 a 1 que só depende do índice e do sal: o mesmo em toda montagem.
static func _sorte(indice: int, sal: int) -> float:
	var h := (indice * 73856093) ^ (sal * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 32768.0 - 1.0
