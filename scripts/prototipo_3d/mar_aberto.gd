extends RefCounted
## O MAR ABERTO É O LIMITE DO MUNDO (#260): a conta que põe a linha fatal antes de a borda do mapa aparecer.
##
## A regra do autor: "toda vez que a borda aparecer no minimapa, o tubarão já tem que ter matado o jogador" — o
## mar aberto é o limite natural do mundo, e ninguém chega à borda. Aqui mora SÓ A GEOMETRIA (distâncias, zonas e as
## medidas que as seguram), pura e testável sem o vale; quem age é o `tubarao.gd`, e quem prova é
## `tests/unidade/test_mar_aberto.gd` (as contas) e `tests/tubarao_borda.gd` (o jogador nadando de verdade).
##
##
## O QUE O MINIMAPA MOSTRA (conferido em minimapa.gd, 15/10/2026)
##
## A foto do minimapa cobre EXATAMENTE o quadro do mapa (`get_map_frame()`), e fora dela a vista é o fundo escuro. A
## vista é um círculo centrado no jogador, e `Minimapa.VISTA` (55 u) é o LADO do quadrado da vista, não o raio: o
## círculo tem raio 27,5 u (0,5 em UV no shader) e 1 u são 4 m. A issue supunha 55 m de raio; a borda entra no
## círculo quando o jogador está a menos de 27,5 u (110 m) dela. Com o mapa doido (`loucura_do_mapa.gd`) a foto
## escorrega até `ALCANCE_DA_DERIVA` (38 u) do jogador, e a borda pode aparecer a até 65,5 u.
##
##
## AS TRÊS ZONAS, medidas a partir da borda do quadro (a mais perto das quatro)
##
##   NENHUMA   mais longe que FAIXA_DE_AVISO: o mar de sempre; o tubarão patrulha o pesqueiro dele.
##   AVISO     de FAIXA_DE_AVISO até LINHA_FATAL: a barbatana aparece a ~26 u do jogador e o rodeia, a música de tensão
##             entra e o HUD avisa. Dá para voltar.
##   FATAL     a menos de LINHA_FATAL: o tubarão dá o bote, sem cooldown e sem alcance de percepção, em velocidade de
##             bote, e o ataque (o susto de sempre, que devolve o jogador à terra) acontece em no máximo PRAZO_DO_BOTE.
##
## POR QUE 70 u: o jogador, depois de cruzar a linha, ainda anda enquanto o tubarão chega e enquanto a tela escurece
## (`PRAZO_DO_BOTE` + `DO_ATAQUE_AO_PRETO` s), no pior ritmo que ele tem na água (`RITMO_MAXIMO`). Esse caminho,
## somado ao raio da vista, é a distância mínima da linha: `LINHA_FATAL >= borda_no_minimapa() + folga_da_perseguicao()`.
## O teste unitário cobra a desigualdade — baixar a linha, ou alongar o prazo, reprova.

enum Zona { NENHUMA, AVISO, FATAL }

## A linha fatal, em unidades do mundo a partir da borda do quadro.
const LINHA_FATAL := 70.0
## Onde a barbatana passa a rondar: o jogador ainda tem esta faixa para entender e voltar.
const FAIXA_DE_AVISO := 110.0
## Folga de quem sai de uma zona (u): quem beira a linha não faz a barbatana aparecer e sumir a cada passo.
const HISTERESE := 8.0
## Daqui para cima a água é "mar" (u de lâmina): acima do joelho. Menos que isso é praia molhada, e na praia vale o que
## vale em terra, a parede invisível.
const LAMINA_DO_MAR := 0.4
## O pior ritmo de quem foge para a borda (u/s): a corrida a vau (5,2 u/s) com a água a 0,4 u já freando (x0,83) e até 40%
## de passo a mais dos talentos e da fé (x1,4) dá ~6,0; o nado de corrida (3,0 x 1,4) dá 4,2. Margem até 6,5.
const RITMO_MAXIMO := 6.5
## O tempo que o tubarão tem, depois de a linha ser cruzada, para dar o bote (s); passado ele, o mar não espera.
const PRAZO_DO_BOTE := 5.0
## Do começo do ataque até a tela preta, quando o jogador volta à terra (s): flash, vinheta e cortina de `tubarao.gd`.
const DO_ATAQUE_AO_PRETO := 1.0

## O raio da vista do minimapa, lido do próprio minimapa (e não copiado). Carregado quando se pergunta, e não na compilação:
## `minimapa.gd` cita autoloads, e um teste rodado com `--script` o compilaria antes deles.
static var _raio_da_vista := 0.0
static var _deriva_do_mapa := -1.0


## O raio do círculo do minimapa (u): a borda entra na vista quando o jogador está mais perto dela que isto.
static func borda_no_minimapa() -> float:
	if _raio_da_vista <= 0.0:
		_raio_da_vista = float(load("res://scripts/prototipo_3d/minimapa.gd").VISTA) * 0.5
	return _raio_da_vista


## Quanto o mapa doido desloca a foto do jogador, no máximo (u).
static func deriva_maxima_do_mapa() -> float:
	if _deriva_do_mapa < 0.0:
		_deriva_do_mapa = float(load("res://scripts/prototipo_3d/loucura_do_mapa.gd").ALCANCE_DA_DERIVA)
	return _deriva_do_mapa


## O caminho que o jogador ainda faz, no pior ritmo, entre cruzar a linha fatal e voltar à terra (u).
static func folga_da_perseguicao() -> float:
	return RITMO_MAXIMO * (PRAZO_DO_BOTE + DO_ATAQUE_AO_PRETO)


## A distância de `ponto` à borda mais perto do `quadro` (u), em x e z: zero na borda e fora dela.
static func distancia_a_borda(ponto: Vector3, quadro: Rect2) -> float:
	return maxf(minf(minf(ponto.x - quadro.position.x, quadro.end.x - ponto.x), minf(ponto.z - quadro.position.y, quadro.end.y - ponto.z)), 0.0)


## A borda do quadro aparece na vista do minimapa de quem está a `distancia` dela? `deriva` é o quanto o mapa doido
## desloca a foto (u) naquele instante; a conta é a do pior lado.
static func borda_a_vista(distancia: float, deriva: float = 0.0) -> bool:
	return distancia - maxf(deriva, 0.0) < borda_no_minimapa()


## Em que zona está quem está a `distancia` da borda, vindo da zona `atual` (a folga de `HISTERESE` segura quem sai).
static func zona(distancia: float, atual: int = Zona.NENHUMA, linha_fatal: float = LINHA_FATAL) -> int:
	if distancia < linha_fatal or (atual == Zona.FATAL and distancia < linha_fatal + HISTERESE):
		return Zona.FATAL
	if distancia < FAIXA_DE_AVISO or (atual != Zona.NENHUMA and distancia < FAIXA_DE_AVISO + HISTERESE):
		return Zona.AVISO
	return Zona.NENHUMA


## Esta água é o mar? Dentro d'água o bastante e fora da terra: o rio, a poça e a praia molhada não contam.
static func no_mar(lamina: float, em_terra: bool) -> bool:
	return not em_terra and lamina >= LAMINA_DO_MAR


## O rumo (unitário, em x e z) de `ponto` para a borda mais perto do `quadro`: é para onde a barbatana se põe, entre o
## jogador e o fim do mundo.
static func rumo_da_borda(ponto: Vector3, quadro: Rect2) -> Vector3:
	var oeste := ponto.x - quadro.position.x
	var leste := quadro.end.x - ponto.x
	var norte := ponto.z - quadro.position.y
	var sul := quadro.end.y - ponto.z
	var menor := minf(minf(oeste, leste), minf(norte, sul))
	if is_equal_approx(menor, leste):
		return Vector3.RIGHT
	if is_equal_approx(menor, sul):
		return Vector3.BACK
	if is_equal_approx(menor, oeste):
		return Vector3.LEFT
	return Vector3.FORWARD
