extends Node
## Pescar.
##
## É a outra metade do sustento: a roça dá mandioca e milho, o mar dá peixe. E
## o peixe é o que a cozinha precisa para os pratos que sustentam de verdade —
## sem pescar, o pirão do tutorial seria o único da partida.
##
## A regra é de UMA TECLA, como o resto do jogo:
##
##   1. com a vara na mão, de frente para a água, E lança a linha;
##   2. a espera é aleatória — nem sempre o peixe vem quando se quer;
##   3. quando ferra, aparece o aviso e há uma JANELA curta para apertar E;
##   4. acertou a janela, o peixe vem; perdeu, a linha volta vazia.
##
## O acerto não é sorte pura: é tempo de reação. Quem está prestando atenção
## pesca; quem está olhando outra coisa perde a isca — e isso é o que faz
## pescar ser uma atividade, e não um botão de gerar item.

signal lancou
signal fisgou
signal terminou(peixe: String, quantos: int)

## O que a espera pode demorar, em segundos.
const ESPERA_MINIMA := 1.6
const ESPERA_MAXIMA := 5.0

## Quanto tempo a janela de ferrar fica aberta. Três décimos é apertado o
## bastante para exigir atenção e folgado o bastante para não punir quem tem
## reflexo normal.
const JANELA := 0.75

## Fôlego por lançada. Barato: pescar é atividade de esperar, não de lombo.
const FOLEGO := 2.0

## O QUE CADA ÁGUA DÁ, e o peso de cada coisa. O "nada" existe para a espera
## ter risco — pescaria que sempre rende não é pescaria.
##
## Era um tanque só, e toda água do mapa dava o mesmo peixe: a baía, o riacho
## da vila, o rio grande e a lagoa nova eram, para quem pescava, o mesmo lugar.
## O mapa tem água em quatro lugares diferentes e nenhum motivo para escolher
## entre eles — e lugar sem motivo para ir é lugar que o jogador atravessa.
##
## Dois tanques, pela única divisão que o terreno já conhece (`GeradorMundo.
## MAR_Y`): do mar para baixo é sal, daí para cima é doce.
##
##   ROBALO   da baía. É o peixe de Todos os Santos, e é o que dá o dinheiro:
##            vale três peixes comuns no balcão do armazém.
##   TRAÍRA   de remanso. Menos dinheiro que o robalo e mais que o peixe — e
##            mais fácil de achar, porque água doce aqui é o riacho que passa
##            no meio da vila.
##
## O peixe comum continua em toda água, e de propósito: metade das receitas da
## cozinha pede `peixe`, e a missão do Pedro manda trazer dois. Uma água que
## deixasse de dar peixe comum quebraria o começo do jogo em silêncio.
const TANQUES := {
	"mar": [
		{"id": "peixe", "qtd": 1, "peso": 46},
		{"id": "peixe", "qtd": 2, "peso": 20},
		{"id": "robalo", "qtd": 1, "peso": 16},
		{"id": "", "qtd": 0, "peso": 18},
	],
	"doce": [
		{"id": "peixe", "qtd": 1, "peso": 48},
		{"id": "peixe", "qtd": 2, "peso": 14},
		{"id": "traira", "qtd": 1, "peso": 20},
		{"id": "", "qtd": 0, "peso": 18},
	],
}

## A água de quem não disse qual. Mar, porque o píer é onde o tutorial ensina.
const AGUA_PADRAO := "mar"

var pescando: bool = false
## Verdadeiro só durante a janela em que dá para ferrar.
var ferrando: bool = false

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


## A janela e a espera saem dos talentos: "Linha firme" alarga o tempo de
## ferrar, "Mão de pescador" faz o peixe morder mais cedo.
func janela() -> float:
	return JANELA * (1.0 + Talentos.bonus("janela_de_pesca"))


func espera() -> Vector2:
	var corte := 1.0 + Talentos.bonus("espera_de_pesca")
	return Vector2(ESPERA_MINIMA * corte, ESPERA_MAXIMA * corte)


func pode_pescar() -> bool:
	return not pescando and Energia.aguenta("plantar", FOLEGO / Energia.CUSTOS["plantar"])


## A pescaria inteira, do lance ao peixe. Quem chama é o mundo, que sabe se o
## jogador está de frente para água.
## `raro` é a bóia ter caído num CÍRCULO DE PESCA (ver `Mundo._circulos`):
## o cardume à vista, onde o peixe grande pesa mais na sorte.
func pescar(agua: String = AGUA_PADRAO, raro: bool = false) -> Dictionary:
	if not pode_pescar():
		return {}
	pescando = true
	Energia.gastar("plantar", FOLEGO / Energia.CUSTOS["plantar"])
	lancou.emit()

	var quanto := espera()
	await get_tree().create_timer(_rng.randf_range(quanto.x, quanto.y)).timeout
	if not pescando:                      # o jogador desistiu no meio
		return {}

	ferrando = true
	fisgou.emit()
	var fim := Time.get_ticks_msec() + int(janela() * 1000.0)
	while ferrando and Time.get_ticks_msec() < fim:
		await get_tree().process_frame
	var ferrou := not ferrando            # `ferrar()` desliga a janela
	ferrando = false
	pescando = false

	if not ferrou:
		terminou.emit("", 0)
		return {}

	var premio := _sortear(agua, raro)
	if str(premio["id"]) != "":
		# "Mão de pescador" tira um peixe a mais de cada fisgada.
		var quantos := int(premio["qtd"]) + int(Talentos.bonus("sorte_de_pesca"))
		premio = {"id": premio["id"], "qtd": quantos}
		Inventario.adicionar(str(premio["id"]), quantos)
		Talentos.ganhar("colher")
	terminou.emit(str(premio["id"]), int(premio["qtd"]))
	return premio


## O jogador apertou E na hora certa.
func ferrar() -> bool:
	if not ferrando:
		return false
	ferrando = false
	return true


## Largou a vara no meio da espera.
func desistir() -> void:
	pescando = false
	ferrando = false


## QUANTO O CÍRCULO PESA. No cardume, todo peixe que não é o comum tem a sorte
## multiplicada por isto, e a chance de a isca ir embora cai pela metade. Não
## é garantia — círculo que garantisse robalo viraria máquina de robalo —, é
## o lugar onde vale a pena lançar.
const PESO_DO_CARDUME := 4

func _sortear(agua: String = AGUA_PADRAO, raro: bool = false) -> Dictionary:
	var tanque: Array = TANQUES.get(agua, TANQUES[AGUA_PADRAO])
	if raro:
		var no_cardume: Array = []
		for premio in tanque:
			var copia: Dictionary = (premio as Dictionary).duplicate()
			var id := str(copia["id"])
			if id == "":
				copia["peso"] = maxi(1, int(copia["peso"]) / 2)
			elif id != "peixe":
				copia["peso"] = int(copia["peso"]) * PESO_DO_CARDUME
			no_cardume.append(copia)
		tanque = no_cardume
	var total := 0
	for premio in tanque:
		total += int(premio["peso"])
	# TANQUE VAZIO É A LINHA SEM NADA, e não uma divisão por zero. Água que o
	# mapa conheça e a tabela não deveria render "levou a isca", que é uma
	# resposta que o jogo já sabe dar — e não um erro no meio da pescaria.
	if tanque.is_empty() or total <= 0:
		push_warning("Pesca: a água '%s' não tem tanque nenhum." % agua)
		return {"id": "", "qtd": 0, "peso": 0}
	var sorte := _rng.randi() % total
	for premio in tanque:
		sorte -= int(premio["peso"])
		if sorte < 0:
			return premio
	return tanque[0]
