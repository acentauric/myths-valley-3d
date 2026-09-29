extends Node
## A LUTA: o que o jogador sabe fazer no combate, e o que cada golpe faz.
##
## A fase 6-A deixou o combate de pé — vida, criatura, o E com arma na mão —, e
## deixou o jogador aprendendo tudo sozinho: ninguém dizia que o bicho morde,
## que se bate de frente, que o facão sai da oficina. "Precisa inserir uma série
## de missões para introduzir o combate, podendo ter golpes com armas, golpes de
## luta como capoeira (vinculada às missões do candomblé) e as lutas com poderes
## (essa não agora)."
##
## TRÊS ARTES, e cada uma tem quem ensine:
##
##   ARMA        o Pedro, antes da trilha da fazenda. O golpe é de todo mundo; o
##               GOLPE FORTE (segurar o E) é lição dele.
##   CAPOEIRA    o Cosme, no terreiro, para quem é do candomblé. A GINGA (a
##               esquiva, tecla V), a MEIA-LUA (o E de mão vazia) e a RASTEIRA
##               (segurar o E de mão vazia, que derruba o bicho tonto).
##   PODER       ainda não. Entra quando o jogador entrar no místico, e não
##               antes: luta com poder antes de haver quem a explique é poder
##               sem história. Ver docs/PLANO.md.
##
## O QUE SE APRENDE FICA. Migrar de fé congela as missões do candomblé e os nós
## da teia dele (ver Fe), mas não desaprende a ginga: capoeira é do corpo de
## quem jogou, e não de santo nenhum. O que para é a lição que falta e o que a
## teia punha por cima.

signal aprendeu(golpe: String)
## Um golpe acertou alguém. `derrubou`: a criatura caiu; `tonteou`: ficou tonta.
signal acertou(golpe: String, especie: String, derrubou: bool, tonteou: bool)
## A ginga livrou o jogador de um bote que ia acertar.
signal esquivou(especie: String)

## OS GOLPES.
##
##   arma       precisa de arma na mão (`Catalogo.dano`); sem, é de mão vazia.
##   dano       multiplica o da arma; de mão vazia, `dano_base` é o dano.
##   folego     quanto de "bater" o golpe gasta.
##   alcance    até onde acerta, em pixels, do centro do jogador.
##   frente     o mínimo do produto escalar com a frente: 0,2 é de frente;
##              -0,35 é quase meia volta, que é a meia-lua.
##   varios     acerta todo mundo no arco, e não só o mais perto.
##   empurra    quanto o bicho recua com a pancada, em pixels.
##   tonteia    por quanto tempo o bicho fica tonto: não caça e não morde.
##   impacto    quanto depois de começar o golpe a pancada chega — o braço tem
##              de descer antes de acertar.
##   segurar    o golpe sai SEGURANDO o E (`SEGURAR`), e não tocando.
const GOLPES := {
	"golpe": {"nome": "Golpe", "arma": true, "dano": 1.0, "folego": 1.0,
		"alcance": 26.0, "frente": 0.2, "varios": false, "empurra": 6.0,
		"tonteia": 0.0, "impacto": 0.12, "segurar": false},
	"golpe_forte": {"nome": "Golpe forte", "arma": true, "dano": 1.8, "folego": 2.2,
		"alcance": 30.0, "frente": 0.2, "varios": false, "empurra": 22.0,
		"tonteia": 0.7, "impacto": 0.2, "segurar": true},
	"meia_lua": {"nome": "Meia-lua", "arma": false, "dano_base": 3.0, "folego": 1.4,
		"alcance": 32.0, "frente": -0.35, "varios": true, "empurra": 14.0,
		"tonteia": 0.0, "impacto": 0.22, "segurar": false},
	"rasteira": {"nome": "Rasteira", "arma": false, "dano_base": 2.0, "folego": 1.8,
		"alcance": 28.0, "frente": 0.2, "varios": false, "empurra": 8.0,
		"tonteia": 1.8, "impacto": 0.22, "segurar": true},
}

## A GINGA: o passo de lado que livra do bote. `livre` é quanto tempo o corpo
## fica fora do alcance da mordida — um pouco mais que o próprio passo, que é
## o que faz ela valer quando o bicho já baixou a cabeça: apertada no
## instante do aviso, ela ainda cobre a boca fechando (0,41 s depois, no
## caititu), e sobra o tempo de uma reação de gente.
const GINGA := {"folego": 0.8, "distancia": 34.0, "duracao": 0.3, "livre": 0.5}

## Quanto tempo segurando o E para o golpe virar o forte (ou a rasteira).
const SEGURAR := 0.32

## O punho firme (raiz Combate): um quarto a mais no golpe de arma por nó.
const FORCA_POR_NO := 0.25

## O que o jogador já aprendeu, além do golpe, que é de todo mundo. Vai no save.
var aprendidos: Array = []

## QUANTOS DE CADA ESPÉCIE JÁ CAÍRAM, e a página do bicho no caderno (ver
## Colecao, "bichos"), aberta no primeiro. É a contagem da parede da Guilda do
## Stardew; a recompensa por meta, que lá é o que a contagem existe para
## pagar, fica declarada no PLANO.md. Vai no save.
var abates: Dictionary = {}


func _ready() -> void:
	acertou.connect(_ao_acertar)


func _ao_acertar(_golpe: String, especie: String, derrubou: bool, _tonteou: bool) -> void:
	if not derrubou or especie == "":
		return
	abates[especie] = int(abates.get(especie, 0)) + 1
	Colecao.achar("bichos", especie)


func abatidos(especie: String) -> int:
	return int(abates.get(especie, 0))


func sabe(golpe: String) -> bool:
	return golpe == "golpe" or aprendidos.has(golpe)


func aprender(golpe: String) -> void:
	if sabe(golpe) or not (GOLPES.has(golpe) or golpe == "ginga"):
		return
	aprendidos.append(golpe)
	aprendeu.emit(golpe)


## O golpe que o E daria agora, com esta mão: o forte (segurando) ou o de
## sempre. "" quando a mão não luta — ferramenta sem dano, semente, trouxa.
func golpe_da_mao(mao: String, segurando: bool) -> String:
	if mao != "" and Catalogo.dano(mao) > 0.0:
		if segurando and sabe("golpe_forte"):
			return "golpe_forte"
		return "golpe"
	if mao == "":
		if segurando and sabe("rasteira"):
			return "rasteira"
		if sabe("meia_lua"):
			return "meia_lua"
	return ""


## O dano do golpe com esta mão, já com o que a teia põe.
##
## A FORÇA da raiz Combate (o punho firme) pesa no golpe de arma; a da
## CAPOEIRA, na teia do candomblé, pesa no de mão vazia. As duas teias não se
## somam no mesmo golpe: braço de facão e perna de roda são treinos diferentes.
func dano(golpe: String, mao: String) -> float:
	var g: Dictionary = GOLPES.get(golpe, {})
	if g.is_empty():
		return 0.0
	if bool(g["arma"]):
		return Catalogo.dano(mao) * float(g["dano"]) * (1.0 + Talentos.bonus("forca") * FORCA_POR_NO)
	return float(g["dano_base"]) * (1.0 + Fe.bonus("forca_da_capoeira"))


## Quanto tempo o golpe tonteia, já com a teia (a rasteira de mestre dobra).
func tontura(golpe: String) -> float:
	var t := float(GOLPES.get(golpe, {}).get("tonteia", 0.0))
	if golpe == "rasteira":
		t *= 1.0 + Fe.bonus("tontura")
	return t


## Fôlego do golpe, já com a teia (o braço pesado alivia o forte).
func folego(golpe: String) -> float:
	var f := float(GOLPES.get(golpe, {}).get("folego", 0.0))
	if golpe == "golpe_forte":
		f *= 1.0 - minf(0.9, Talentos.bonus("golpe_de_peso"))
	return f


## Fôlego da ginga, já com a teia (a ginga de roda gasta metade).
func folego_da_ginga() -> float:
	return float(GINGA["folego"]) * (1.0 - 0.5 * minf(1.0, Fe.bonus("ginga_leve")))
