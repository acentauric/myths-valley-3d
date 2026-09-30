extends Node
## A oficina: transformar recurso bruto em material.
##
## Lenha vira tábua, tábua e pedra viram peça de ponte. É o elo que faltava
## entre derrubar mata e levantar coisa: sem ele a lenha só serve para vender.
##
## Receita é dado, não código — igual às obras. Quando a oficina for melhorada
## (docs/mundo/CONSTRUCAO.md), receitas novas entram aqui com `exige`.
##
## E cada uma declara a sua chave `abre`, que diz por onde se aprende. Ver
## `Receitas`.

signal fabricou(id: String, quantos: int)

const RECEITAS := {
	## TÁBUA E CORDA NASCEM SABIDAS, e é a única exceção da bancada — a razão
	## está inteira em `Receitas`, no bloco "o que nasce sabido". Resumindo: as
	## duas são cobradas pelo cabo da foice do Damião, pela rede do Tonho e pelo
	## mirante do arraial, três séries que correm em paralelo e sem ordem entre
	## si. Trancar material que três frentes independentes pedem é montar um beco
	## que só aparece na partida de quem fez as coisas em outra ordem.
	"tabua": {
		"nome": "Serrar tábua",
		"resumo": "Duas lenhas viram uma tábua serrada. É o material de quase toda obra.",
		"custo": {"lenha": 2},
		"rende": 1,
		"folego": 3.0,
		"abre": {"comeco": true},
	},
	"corda": {
		"nome": "Torcer corda de piaçava",
		"resumo": "Três lenhas de dendê viram uma corda. Amarra ponte, cerca e rede.",
		"custo": {"lenha": 3},
		"rende": 1,
		"folego": 2.0,
		"abre": {"comeco": true},
	},
	# A ARMA SAI DA MESMA BANCADA que a tábua, e é de propósito: a oficina é o
	# lugar onde lenha vira coisa, e facão é coisa. Ver Catalogo "facao".
	"facao": {
		"nome": "Bater um facão",
		"resumo": "Duas lenhas de cabo e uma pedra de amolar viram um facão de mato. Bate mais que o machado.",
		"custo": {"lenha": 2, "pedra": 1},
		"rende": 1,
		"folego": 4.0,
		## A LIÇÃO DO FACÃO É O PASSO QUE MANDA BATER UM. Por isso a porta abre na
		## ABERTURA do passo: o Pedro explica a bancada e manda forjar, e a
		## bancada tem que listar o facão na hora em que ele terminar de falar.
		## Quem preferir réis compra a receita no balcão — sai por dois terços do
		## preço do facão pronto, o que é o negócio certo para quem vai bater
		## mais de um.
		"abre": {"missao": "armas_facao", "compra": 240},
	},
}


## O QUE A BANCADA LISTA: só o que o jogador sabe fazer. Mesma regra do fogão —
## ver `Cozinha.receitas`.
func receitas() -> Array:
	var lista: Array = []
	for id in RECEITAS:
		if Receitas.sabe(str(id)):
			lista.append(id)
	return lista


func dados(id: String) -> Dictionary:
	return RECEITAS.get(id, {})


## Quanto a receita RENDE hoje. A oficina de material evolui por aqui: a serra
## de fita tira uma tábua a mais da mesma lenha, o tear tira uma corda a mais.
## O custo em lenha não muda — o que melhora é o aproveitamento, que é o que
## uma oficina melhor faz de verdade.
func rende(id: String) -> int:
	var total: int = int(dados(id).get("rende", 1))
	for obra in Obras.tudo_da("oficina"):
		total += int(Obras.dados(str(obra)).get("rende_mais", {}).get(id, 0))
	return maxi(1, total)


## Fôlego que a peça custa, já com o alívio das obras da oficina.
func folego(id: String) -> float:
	var total: float = float(dados(id).get("folego", 3.0))
	for obra in Obras.tudo_da("oficina"):
		total -= float(Obras.dados(str(obra)).get("alivio", 0.0))
	return maxf(1.0, total)


## "" quando dá para fabricar; senão, o que falta.
func impedimento(id: String) -> String:
	var dado := dados(id)
	if dado.is_empty():
		return "Receita desconhecida."
	if not Receitas.sabe(id):
		return "Você ainda não sabe fazer isso."
	for item in dado.get("custo", {}):
		var pedido: int = int(dado["custo"][item])
		if Inventario.quantidade(item) < pedido:
			return "Falta %s: %d de %d." % [Catalogo.nome(item), Inventario.quantidade(item), pedido]
	if not Energia.aguenta("arar", folego(id) / Energia.CUSTOS["arar"]):
		return "Sem fôlego para isto."
	return ""


func pode(id: String) -> bool:
	return impedimento(id) == ""


func fabricar(id: String) -> bool:
	if not pode(id):
		return false
	var dado := dados(id)
	for item in dado.get("custo", {}):
		Inventario.consumir(item, int(dado["custo"][item]))
	Energia.gastar("arar", folego(id) / Energia.CUSTOS["arar"])
	var quantos: int = rende(id)
	Inventario.adicionar(id, quantos)
	Talentos.ganhar("plantar")
	fabricou.emit(id, quantos)
	return true


func custo_em_texto(id: String) -> String:
	var partes: Array = []
	for item in dados(id).get("custo", {}):
		partes.append("%d %s" % [int(dados(id)["custo"][item]), Catalogo.nome(item).to_lower()])
	return ", ".join(partes)
