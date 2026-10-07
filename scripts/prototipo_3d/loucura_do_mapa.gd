extends Node
## O MAPA ENLOUQUECE: quem achou as pegadas do Curupira bem dentro da mata perde o norte por uns
## 75 segundos. A bússola do canto e o mapa grande (M) giram e escorregam para o lugar errado, a seta
## do jogador e a da missão apontam para qualquer lado, o losango da missão pula pelo aro, o Pedro
## some da bússola e os nomes dos lugares trocam de dono. Depois o norte volta ao lugar, como se nada.
##
## ESTE NÓ SÓ DIZ O QUANTO E PARA ONDE; quem desenha é cada tela (`minimapa.gd`, `mapa_jogo.gd`,
## `seta_missao.gd`), que o acha pelo grupo `loucura_do_mapa` e pergunta a cada quadro. Ele nunca
## mexe no corpo do jogador, nem no relógio, nem no save: é só o que a bússola mostra, e fora da
## loucura tudo o que ele devolve é EXATAMENTE o valor de sempre (zero, ou a identidade).
##
## Tudo é função do tempo da loucura (`_t`), e não de sorteio a cada quadro: o portão confere a
## curva, e a bússola não treme à toa. As curvas são somas de senos lentos — a rotação oscila em
## vez de acumular, para o fim da loucura não precisar "desenrolar" voltas.

signal comecou
signal acabou

const GRUPO := &"loucura_do_mapa"
## Quanto dura, e quanto leva para chegar ao máximo e para se desfazer (s de jogo).
const DURACAO := 75.0
const SUBIDA := 2.0
const DESCIDA := 6.0
## Depois de começar, o mapa só enlouquece de novo daqui a tanto (s de jogo): o rastro não é pedágio.
const ESFRIAR := 420.0
## Quanto a foto do minimapa escorrega do jogador no máximo (u), e quanto a seta da missão se
## afasta do alvo no mundo (u).
const ALCANCE_DA_DERIVA := 38.0
const ALCANCE_DO_ALVO := 14.0
## Acima disto, o "Você" vira "???" e o Pedro some da bússola: a loucura já pegou.
const LIMIAR_DOS_NOMES := 0.35
## Os nomes dos lugares trocam de dono a cada tanto (s).
const TROCA_DOS_NOMES := 1.6

var _t := 0.0
var _duracao := 0.0
var _ativa := false
var _esfriando := 0.0
## A troca de nomes da vez: a fase (qual sorteio) e a ordem sorteada para `n` nomes.
var _fase_dos_nomes := -1
var _ordem: Array[int] = []


func _ready() -> void:
	add_to_group(GRUPO)


func _process(delta: float) -> void:
	_esfriando = maxf(_esfriando - delta, 0.0)
	if not _ativa:
		return
	_t += delta
	if _t >= _duracao:
		terminar()


## Pode começar agora? Não, se já está enlouquecida ou se acabou de enlouquecer.
func pode_iniciar() -> bool:
	return not _ativa and _esfriando <= 0.0


## Começa a loucura. Devolve false se ela não pode começar (ver `pode_iniciar`).
func iniciar(duracao: float = DURACAO) -> bool:
	if not pode_iniciar():
		return false
	_t = 0.0
	_duracao = maxf(duracao, SUBIDA + DESCIDA)
	_ativa = true
	_esfriando = ESFRIAR
	_fase_dos_nomes = -1
	comecou.emit()
	return true


## Encerra já, sem esperar o fim: a bússola volta ao valor de sempre.
func terminar() -> void:
	if not _ativa:
		return
	_ativa = false
	_t = 0.0
	_fase_dos_nomes = -1
	acabou.emit()


func ativa() -> bool:
	return _ativa


## O quanto o mapa está louco, de 0 a 1: sobe em `SUBIDA` s, fica no máximo, e desce em `DESCIDA` s.
func intensidade() -> float:
	if not _ativa:
		return 0.0
	return clampf(minf(_t / SUBIDA, (_duracao - _t) / DESCIDA), 0.0, 1.0)


## Quanto tempo falta para o norte voltar (s), ou 0.
func resta() -> float:
	return maxf(_duracao - _t, 0.0) if _ativa else 0.0


## Quanto o mapa gira (rad). Oscila entre as voltas e o contrário delas: o norte "passeia".
func rotacao_do_mapa() -> float:
	return intensidade() * _onda(_t)


## Para onde a foto do minimapa escorrega do jogador (u, em x e z): o mapa fica centrado num lugar
## ERRADO, e o triângulo do jogador, que fica no meio, passa a estar onde não está.
func deriva_do_mapa() -> Vector2:
	return Vector2(sin(0.31 * _t + 0.7), cos(0.23 * _t + 2.0)) * ALCANCE_DA_DERIVA * intensidade()


## O erro das setas (rad): quanto cada uma aponta para o lado errado.
func erro_da_seta() -> float:
	return intensidade() * (2.3 * sin(0.7 * _t + 0.4) + 1.2 * sin(1.9 * _t))


## Onde a seta da missão flutua no mundo, a mais que o alvo de verdade (u, em x e z).
func deriva_do_alvo() -> Vector2:
	return Vector2(sin(0.5 * _t + 1.1), cos(0.41 * _t)) * ALCANCE_DO_ALVO * intensidade()


## Passa a loucura a um `Vector2` de tela (px): o "Você" do mapa grande vagueia.
func deriva_na_tela(alcance_px: float) -> Vector2:
	return Vector2(sin(1.3 * _t), cos(1.7 * _t + 0.6)) * alcance_px * intensidade()


## Os nomes de `n` lugares, na ordem em que a tela deve MOSTRÁ-LOS: a identidade fora da loucura,
## e um embaralhado novo a cada `TROCA_DOS_NOMES` s dentro dela. O item i da tela mostra o nome
## `ordem[i]`. O embaralhado é função da fase (o mesmo em todo quadro da fase).
func ordem_dos_nomes(n: int) -> Array[int]:
	if intensidade() < LIMIAR_DOS_NOMES or n <= 1:
		_ordem = []
		for i in range(n):
			_ordem.append(i)
		return _ordem
	var fase := int(_t / TROCA_DOS_NOMES)
	if fase != _fase_dos_nomes or _ordem.size() != n:
		_fase_dos_nomes = fase
		var sorteio := RandomNumberGenerator.new()
		sorteio.seed = hash("curupira%d" % fase)
		_ordem = []
		for i in range(n):
			_ordem.append(i)
		for i in range(n - 1, 0, -1):
			var j := sorteio.randi_range(0, i)
			var troca := _ordem[i]
			_ordem[i] = _ordem[j]
			_ordem[j] = troca
	return _ordem


## A "loucura" ligada o bastante para pegar nos nomes e no Pedro?
func pegou_nos_nomes() -> bool:
	return intensidade() >= LIMIAR_DOS_NOMES


func _onda(t: float) -> float:
	return 2.4 * sin(0.38 * t) + 1.1 * sin(0.93 * t + 1.3) + 0.35 * sin(2.1 * t)
