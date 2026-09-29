extends Node
## Obras: melhorar a casa e as outras construções.
##
## NÃO é uma escada. As obras formam um GRAFO: cada uma pede pré-requisitos e
## algumas se excluem entre si. Quem levanta parede e faz quarto não tem mais o
## salão aberto; quem vira a sala em oficina não vira em venda. Duas partidas
## não terminam com a mesma casa, e é esse o ponto.
##
## Três eixos, independentes:
##
## - **casca**  — o corpo da construção. Muda a arte externa e a pegada.
## - **planta** — o que existe dentro: parede, cômodo, piso.
## - **mobilia**— o que está dentro dos cômodos.
##
## Subir a casca não obriga a mexer na planta, e trocar mobília não pede casca
## nova. É por isso que são eixos e não níveis.
##
## Vale para construção de NPC também: a venda, o moinho, a cabana de pesca e a
## casa do Pedro usam o mesmo catálogo, e ali a obra costuma vir amarrada numa
## missão — o NPC pede, o jogador executa.
##
## O catálogo mora em data/construcoes/obras.json, separado do código para que
## preço e texto possam ser ajustados sem tocar em GDScript.

signal concluida(construcao: String, obra: String)
signal mudou

const ARQUIVO := "res://data/construcoes/obras.json"

## construcao -> Array[String] de obras já feitas.
var feitas: Dictionary = {}

var _catalogo: Dictionary = {}


func _ready() -> void:
	_catalogo = Jogo.dados(ARQUIVO).get("obras", {})
	if _catalogo.is_empty():
		push_warning("Catálogo de obras vazio: %s" % ARQUIVO)


# --- consulta -----------------------------------------------------------------

func catalogo() -> Dictionary:
	return _catalogo


func dados(obra: String) -> Dictionary:
	return _catalogo.get(obra, {})


func ja_feita(construcao: String, obra: String) -> bool:
	return feitas.get(construcao, []).has(obra)


## Tudo que uma construção já recebeu. Quem evolui a oficina e o canteiro lê
## isto para saber o que a bancada virou.
func tudo_da(construcao: String) -> Array:
	return feitas.get(construcao, [])


## TODA OBRA DO CATÁLOGO que serve a esta construção, sabida ou não, feita ou
## não. É a lista contra a qual o canteiro conta quantos planos faltam aprender:
## contra o catálogo inteiro diria "faltam 24" na frente do poço da praça, que
## recebe uma obra só.
func todas_de(construcao: String) -> Array:
	var lista: Array = []
	var qual := _familia(construcao)
	for obra in _catalogo:
		if (_catalogo[obra] as Dictionary).get("alvos", []).has(qual):
			lista.append(obra)
	return lista


## O quanto o CANTEIRO DE OBRAS perdoa de material.
##
## É por isto que o canteiro existe separado da oficina: a oficina é braço —
## serra tábua, torce corda — e o canteiro é prancheta. Melhorar o canteiro não
## fabrica nada; faz toda obra do mapa custar menos, porque o risco sai melhor
## medido. A árvore de talentos soma no mesmo lugar.
const DESCONTO_MAXIMO := 0.5

func desconto() -> float:
	var total := Talentos.bonus("desconto_de_obra")
	for obra in tudo_da("canteiro"):
		total += float(dados(str(obra)).get("desconto", 0.0))
	return minf(total, DESCONTO_MAXIMO)


## O que a obra cobra DE FATO, já com o desconto. Nunca zera um item: obra sem
## material nenhum deixaria de ser obra.
func custo(obra: String) -> Dictionary:
	var bruto: Dictionary = dados(obra).get("custo", {})
	var fator := 1.0 - desconto()
	var conta: Dictionary = {}
	for id in bruto:
		conta[id] = maxi(1, int(ceilf(float(bruto[id]) * fator)))
	return conta


## Obras que aquela construção pode receber agora: PLANO SABIDO, pré-requisito
## cumprido, nenhuma exclusão acionada, e ainda não feita.
##
## O plano sabido é a peça nova, e ela é de outra natureza que o `exige`. O
## `exige` é ESPAÇO: a cantareira não cabe antes da varanda, e não há o que
## aprender a respeito. O plano é CONHECIMENTO: a serra de fita não se inventa
## olhando a bancada, alguém mostra ou se compra a planta. Ver `Receitas` — a
## chave `abre` de cada obra está no JSON, ao lado do custo dela.
func disponiveis(construcao: String) -> Array:
	var lista: Array = []
	for obra in todas_de(construcao):
		var dado: Dictionary = _catalogo[obra]
		if not Receitas.sabe(str(obra)):
			continue
		if ja_feita(construcao, obra) or not _liberada(construcao, dado):
			continue
		lista.append(obra)
	# Agrupa por compartimento e, dentro dele, pela ordem. É o que deixa a tela
	# listar "Dormida / Cozinha / Guardado" em blocos, em vez de uma lista solta.
	lista.sort_custom(func(a, b):
		var ca := str(dados(str(a)).get("compartimento", ""))
		var cb := str(dados(str(b)).get("compartimento", ""))
		if ca != cb:
			return ca < cb
		return _ordem(str(a)) < _ordem(str(b)))
	return lista


## O que a construção virou em cada eixo. É isto que o mundo lê para saber qual
## arte desenhar e que parede levantar.
func estado(construcao: String, eixo: String) -> String:
	var atual := ""
	var melhor := -1
	for obra in feitas.get(construcao, []):
		var dado: Dictionary = dados(obra)
		if dado.get("eixo", "") != eixo:
			continue
		var ordem: int = int(dado.get("ordem", 0))
		if ordem > melhor:
			melhor = ordem
			atual = str(dado.get("vira", obra))
	return atual


## Tudo que foi feito num eixo — a planta é somatória, não substitutiva.
func tudo_de(construcao: String, eixo: String) -> Array:
	var lista: Array = []
	for obra in feitas.get(construcao, []):
		if dados(obra).get("eixo", "") == eixo:
			lista.append(obra)
	return lista


# --- execução -----------------------------------------------------------------

## Falta alguma coisa para pagar? Devolve "" quando dá para tocar a obra.
func impedimento(construcao: String, obra: String) -> String:
	var dado := dados(obra)
	if dado.is_empty():
		return "Obra desconhecida."
	if ja_feita(construcao, obra):
		return "Já foi feita."
	# O PLANO ANTES DO MATERIAL: ninguém toca obra que não sabe riscar. Mesma
	# trava que o fogão e a oficina ganharam, e pela mesma razão — esconder da
	# lista não pode ser a única coisa que impede.
	if not Receitas.sabe(obra):
		return "Você ainda não sabe fazer essa obra."
	if not _liberada(construcao, dado):
		return "Ainda não é hora dessa."

	var conta := custo(obra)
	for id in conta:
		var pedido: int = int(conta[id])
		var tem := Inventario.quantidade(id)
		if tem < pedido:
			return "Falta %s: %d de %d." % [Catalogo.nome(id), tem, pedido]
	return ""


func pode(construcao: String, obra: String) -> bool:
	return impedimento(construcao, obra) == ""


## Cobra o material e registra. Quem desenha é o mundo, ouvindo `concluida`.
func executar(construcao: String, obra: String) -> bool:
	if not pode(construcao, obra):
		return false

	var conta := custo(obra)
	for id in conta:
		Inventario.consumir(id, int(conta[id]))

	if not feitas.has(construcao):
		feitas[construcao] = []
	feitas[construcao].append(obra)

	# Obra dá XP, e das maiores do jogo.
	#
	# Faltava, e era incoerente: arar um tile rende 3, derrubar uma madeira de
	# lei rende 12, e levantar uma parede — que custou dias de tábua, corda e
	# ida e volta à oficina — rendia ZERO. Quem trabalha aprende é a regra da
	# árvore desde o começo; obra é o trabalho mais caro que existe aqui.
	#
	# Só em `executar`, e não em `conceder`: obra que o NPC dá de presente não
	# foi trabalho do jogador.
	Talentos.ganhar("obra", _peso_em_xp(obra))

	concluida.emit(construcao, obra)
	mudou.emit()
	return true


## Quantas vezes o XP de obra conta, conforme o tamanho dela.
##
## Casca é o que muda a construção por fora e por dentro — é a obra grande.
## Mobília é uma peça a mais no canto. Pagar igual pelas duas faria o jogador
## encher a casa de banquinho em vez de levantar parede.
func _peso_em_xp(obra: String) -> int:
	return 3 if str(dados(obra).get("eixo", "")) == "casca" else 1


## Usado pelas missões de NPC, que entregam a obra sem cobrar do jogador.
## O QUE CADA OBRA FAZ PELO CORPO DE QUEM MORA NELA.
##
## Uma casa melhor não é enfeite. Quem dorme em rede armada e não no chão de
## terra acorda melhor; quem tem cantareira com água limpa não passa o dia
## seco; quem tem assoalho não dorme com bicho subindo na perna. O jogo já
## dizia isso no texto de cada obra — "menos poeira, menos bicho" — e não
## cobrava a promessa: a melhoria mudava o desenho e mais nada.
##
## Os campos são os da Progressao, e são os que o jogo de fato usa hoje:
##
##   energia_maxima          o teto de fôlego. Casa maior, corpo que aguenta
##                           mais dia — é a casca que paga isto.
##   recuperacao_ao_dormir   quanto a noite devolve. É o eixo da DORMIDA:
##                           rede, quarto, assoalho.
##   recuperacao_ao_desmaiar quanto apagar no chão devolve. Só o assoalho
##                           mexe: apagar em tábua é menos ruim que em terra.
##   eficiencia              multiplicador de custo de toda ação. Desce com a
##                           oficina e com a mesa — trabalhar num lugar
##                           montado cansa menos.
##
## NÃO há defesa nem ataque aqui, e é de propósito: os dois campos existem na
## árvore de talentos ("Punho firme", "Pele grossa") marcados para o capítulo
## 7, e não há combate no jogo ainda. Obra que desse defesa hoje daria um
## número que ninguém lê. Quando o combate entrar, é aqui que a casca de
## sobrado vira parede que aguenta.
##
## Os números são pequenos por peça e somam alto no fim: a casa inteira vale
## cerca de +45 de teto e +16 de descanso, que é mais que dobrar a noite
## inicial de 40. É o maior investimento de longo prazo do jogo, e é o único
## que o jogador vê de pé no mapa.
const ATRIBUTOS := {
	# CASCA — o tamanho da casa. Mexe no teto, que é o quanto de dia cabe no
	# corpo: casa apertada é casa de quem trabalha de sol a sol e não guarda
	# nada.
	"casca_varanda": {"energia_maxima": 10.0},
	"casca_sobrado": {"energia_maxima": 18.0},

	# PLANTA — o que a casa tem por dentro.
	"planta_quarto": {"recuperacao_ao_dormir": 4.0},
	# O salão não dá dormida: dá CONVÍVIO, e convívio neste jogo é fôlego de
	# aguentar o dia. É o contrapeso do quarto, para a escolha entre os dois
	# não ser "um é melhor".
	"planta_salao": {"energia_maxima": 8.0},
	"planta_oficina": {"eficiencia": -0.06},
	"planta_venda": {"energia_maxima": 6.0},
	"planta_assoalho": {"recuperacao_ao_dormir": 3.0, "recuperacao_ao_desmaiar": 4.0},

	# MOBÍLIA — as peças. A rede é a maior de todas em descanso, e é o que ela
	# é de verdade: no Recôncavo se dormia em rede, e cama de tábua era pior.
	"mobilia_rede": {"recuperacao_ao_dormir": 6.0},
	"mobilia_altar": {"energia_maxima": 4.0},
	"mobilia_guardado": {"energia_maxima": 5.0},
	"mobilia_mesa_grande": {"eficiencia": -0.03},
	"mobilia_cozinha": {"recuperacao_ao_dormir": 3.0},
	"mobilia_tapete": {"recuperacao_ao_dormir": 2.0},
}


func conceder(construcao: String, obra: String) -> void:
	if ja_feita(construcao, obra):
		return
	if not feitas.has(construcao):
		feitas[construcao] = []
	feitas[construcao].append(obra)
	_pagar_o_atributo(obra)
	concluida.emit(construcao, obra)
	mudou.emit()


## Soma o ganho da obra na Progressao, de uma vez e para sempre.
##
## SOMA, e não define: as obras se empilham, e a conta é a soma de tudo que a
## casa virou. `Progressao.ajustar` recebe o valor final, então o ganho é lido
## do campo atual — é a mesma gramática que a tela de ajustes usa.
##
## Uma obra só paga UMA VEZ porque `conceder` desiste cedo se ela já foi feita.
## Vale para a casa e para qualquer construção: quem melhora a oficina do
## arraial também trabalha melhor nela.
func _pagar_o_atributo(obra: String) -> void:
	var ganhos: Dictionary = ATRIBUTOS.get(obra, {})
	for campo in ganhos:
		var agora := float(Progressao.get(str(campo)))
		Progressao.ajustar(str(campo), agora + float(ganhos[campo]))


# --- interno ------------------------------------------------------------------

## "casa" e "casa_avos" são a mesma família de obras: casa. Assim o catálogo não
## precisa listar cada construção do mapa uma por uma.
func _familia(construcao: String) -> String:
	var dado: Dictionary = Jogo.dados(ARQUIVO).get("familias", {})
	return str(dado.get(construcao, construcao))


## "MESTRE DE OBRAS" PULA UM DEGRAU DA CASCA.
##
## O talento promete "destrava obra de dois andares sem precisar da varanda
## antes", custa dois pontos, exige "Mão de obra" antes — e o campo
## `pula_varanda` não era lido em lugar nenhum. O jogador gastava três pontos
## de ofício ao todo e continuava tendo que erguer a varanda.
##
## Vale só para o eixo da CASCA, e só para o degrau anterior: é atalho de quem
## sabe construir, não licença para levantar sobrado sobre casa de um cômodo
## sem passar por nada. Planta e mobília continuam pedindo o que pedem, porque
## ali o pré-requisito é de ESPAÇO — a cantareira não cabe antes da varanda, e
## nenhum talento faz caber.
const PULA_SO_ESTAS := ["casca_varanda"]

func _liberada(construcao: String, dado: Dictionary) -> bool:
	var pula := str(dado.get("eixo", "")) == "casca" and Talentos.bonus("pula_varanda") > 0.0
	for exigida in dado.get("exige", []):
		if ja_feita(construcao, str(exigida)):
			continue
		if pula and PULA_SO_ESTAS.has(str(exigida)):
			continue
		return false
	for proibida in dado.get("exclui", []):
		if ja_feita(construcao, str(proibida)):
			return false
	return true


func _ordem(obra: String) -> int:
	return int(dados(obra).get("ordem", 0))
