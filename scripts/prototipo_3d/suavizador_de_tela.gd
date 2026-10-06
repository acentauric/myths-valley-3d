extends RefCounted
## O PESO DOS POPUPS NA TELA: uma mola criticamente amortecida por popup.
##
## "A animação de movimentação tem que ser resistente, no sentido de não variar
## tanto e tão rápido com a movimentação do personagem na câmera: devem deslizar
## com maior peso na tela, em vez de ficar gritando tentando se ajustar."
## (playtest da Build 9B, 06/10/2026)
##
##
## COMO ERA
##
## Cada popup do mundo (a placa de nome, a dica do E, o balão de fala, a vida da
## árvore, o chevron da missão) fazia `position = camera.unproject_position(...)`
## a cada quadro. Um pixel a mais na projeção da cabeça era um pixel a mais na
## tela; a câmera é filha do jogador, que anda no passo de física, e o popup
## desenha no passo de imagem — então o texto tremia sempre que as duas taxas
## não casavam, e girar a câmera arrastava todos de uma vez, colados à cabeça.
##
##
## COMO É
##
## `seguir(alvo, delta)` devolve onde o popup está agora, e o popup se põe aí. O
## alvo é a projeção crua; a posição é uma mola que o persegue:
##
##   - o PESO: amortecimento crítico (o `SmoothDamp` de quem faz câmera): sem
##     passar do alvo, sem balançar, e `tempo` é, mais ou menos, quanto leva para
##     chegar. Parado, o popup assenta em ~2,4 vezes o `tempo`;
##   - a ZONA MORTA: o alvo "firme" só anda quando o de verdade sai de um disco de
##     `zona` pixels em volta dele. O tremor de um ou dois pixels da câmera não
##     move o popup nem um pixel;
##   - a CORREIA: o popup não fica mais longe que `correia` pixels do alvo de verdade
##     (um degrau grande a mais que isso é desfeito a `PUXAO` px/s, e não de uma vez).
##     É o que impede a placa de largar a cabeça no meio de uma virada rápida da câmera;
##   - o SALTO: um alvo que andou mais de `SALTO` pixels de UM quadro para o outro
##     (corte de câmera, teletransporte, a tela que fechou) é outro lugar, não
##     movimento: o popup vai direto, em vez de varrer a tela.
##
## O popup que NASCE (ou volta a aparecer) chama `reiniciar(ponto)` antes: aparece
## onde deve, e só dali em diante tem peso.
##
## Sem `class_name`, e sem nome de autoload: um portão rodado com `--script` o
## carrega com `preload` (AGENTS.md).

## Só o portão liga isto (a falsificação): todo suavizador segue o alvo cru, sem
## peso nenhum, e o jogo volta a ser o de antes.
static var desligado := false

const TEMPO := 0.25
## A mola nunca anda mais depressa que isto (px/s).
const VELOCIDADE_MAXIMA := 900.0
const ZONA_MORTA := 2.0
const CORREIA := 110.0
## O que passa da correia volta a esta taxa (px/s), no máximo: em quadros, e não de uma vez.
const PUXAO := 2400.0
## O alvo que andou mais que isto (px) de um quadro para o outro "pulou": é outro lugar.
const SALTO := 220.0
## E o popup a mais que isto do alvo, por qualquer razão, também recomeça.
const DISTANCIA_LOUCA := 1400.0
## Um quadro que demorou mais que isto (a carga, um engasgo) não vira um pulo. A mola é estável com
## qualquer passo, e a engine já corta o delta de processo: o corte daqui é só de segurança — com
## 0,05 s, uma máquina a 12 quadros por segundo deixava o popup para trás, e a correia o puxava.
const QUADRO_MAXIMO := 0.1

## Onde o popup está (já com o peso) e a velocidade da mola, em px/s.
var posicao := Vector2.ZERO
var velocidade := Vector2.ZERO
## O alvo "firme": o de verdade, com a zona morta descontada.
var _firme := Vector2.ZERO
## O alvo do último passo: de um quadro ao outro, quanto ele andou.
var _ultimo_alvo := Vector2.ZERO
var _iniciado := false


## O popup está onde o último `seguir` o pôs?
func iniciado() -> bool:
	return _iniciado


## O popup aparece AQUI, parado: sem deslizar de onde ficou da última vez.
func reiniciar(ponto: Vector2) -> void:
	posicao = ponto
	velocidade = Vector2.ZERO
	_firme = ponto
	_ultimo_alvo = ponto
	_iniciado = true


## Um passo da mola rumo a `alvo`, `delta` segundos depois do último. Devolve a
## posição nova (sem arredondar: quem desenha texto arredonda, para não tremer). `salto` e
## `puxao` são o `SALTO` e o `PUXAO` de quem não os quer assim: o balão, que troca de canto
## (o alvo dele muda de lugar de uma vez, e isso não é corte de câmera), os quer maiores/menores.
func seguir(alvo: Vector2, delta: float, tempo: float = TEMPO, vmax: float = VELOCIDADE_MAXIMA,
		zona: float = ZONA_MORTA, correia: float = CORREIA, salto: float = SALTO, puxao: float = PUXAO) -> Vector2:
	var recomeca := desligado or tempo <= 0.0 or not _iniciado
	if not recomeca:
		recomeca = (alvo - _ultimo_alvo).length() > salto or posicao.distance_to(alvo) > DISTANCIA_LOUCA
	if recomeca:
		reiniciar(alvo)
		return posicao
	_ultimo_alvo = alvo
	var dt := clampf(delta, 0.0, QUADRO_MAXIMO)
	if dt <= 0.0:
		return posicao
	# A ZONA MORTA: o firme só anda quando o alvo sai do disco dele, e anda só o que sobrou.
	var folga := alvo - _firme
	if folga.length() > zona:
		_firme = alvo - folga.limit_length(zona)
	# O AMORTECIMENTO CRÍTICO rumo ao firme.
	var omega := 2.0 / tempo
	var x := omega * dt
	var freio := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var distancia := (posicao - _firme).limit_length(vmax * tempo)
	var meta := posicao - distancia
	var impulso := (velocidade + omega * distancia) * dt
	velocidade = ((velocidade - omega * impulso) * freio).limit_length(vmax)
	var saida := meta + (distancia + impulso) * freio
	# Sem passar do alvo.
	if (_firme - posicao).dot(saida - _firme) > 0.0:
		saida = _firme
		velocidade = Vector2.ZERO
	# A CORREIA, em volta do alvo de verdade: o que passa dela volta em quadros.
	var longe := saida - alvo
	if longe.length() > correia:
		saida -= longe.normalized() * minf(longe.length() - correia, puxao * dt)
	posicao = saida
	return posicao
