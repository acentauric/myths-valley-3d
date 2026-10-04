extends Node
## A venda do arraial: comprar e vender.
##
## Preço não é simétrico. O que o Recôncavo produz — mandioca, farinha, lenha —
## o vendeiro compra barato e revende caro, porque tem de sobra. O que vem de
## fora — ferramenta, corda, tábua serrada — entra caro. É o que faz valer a
## pena plantar em vez de comprar, e comprar em vez de fabricar tudo.
##
## A estação mexe no preço: na estiagem a farinha sobe, na chuva a lenha seca
## sobe. Ainda é um multiplicador simples, mas já é motivo para guardar colheita
## em vez de despejar tudo no primeiro dia.

signal negociou

## id -> {"base": preço de compra em réis, "margem": quanto do base ele paga}
const MERCADORIAS := {
	"semente_mandioca": {"base": 30, "margem": 0.4},
	# As duas que passaram a ser plantáveis. Preço acima da maniva porque as
	# duas rendem mais por pé — e o rebolo é o mais caro dos três: cana se
	# planta uma vez e se corta por anos.
	"semente_milho": {"base": 40, "margem": 0.4},
	"rebolo_cana": {"base": 70, "margem": 0.4},
	"mandioca": {"base": 55, "margem": 0.6},
	"farinha": {"base": 90, "margem": 0.6},
	"milho": {"base": 45, "margem": 0.6},
	"cana": {"base": 40, "margem": 0.6},
	"peixe": {"base": 70, "margem": 0.65},
	"ostra": {"base": 40, "margem": 0.65},
	# OS DOIS PEIXES DE LUGAR, e o preço é a razão de ir atrás deles. O robalo
	# vale três peixes comuns e a traíra vale dois — é o que paga a caminhada
	# até a baía ou até a lagoa, em vez de lançar a linha no riacho da porta.
	"robalo": {"base": 210, "margem": 0.65},
	"traira": {"base": 140, "margem": 0.65},
	"lenha": {"base": 25, "margem": 0.5},
	# A PIAÇAVA: a venda paga pouco (14) e cobra acima do que o mestre do saveiro
	# paga (34), para ninguém comprar aqui e vender lá. Quem quer o preço bom
	# espera o saveiro (ver saveiro_vale.gd).
	"piacava": {"base": 36, "margem": 0.4},
	"pedra": {"base": 20, "margem": 0.5},
	"tabua": {"base": 120, "margem": 0.35},
	"corda": {"base": 80, "margem": 0.35},
	"machado": {"base": 600, "margem": 0.3},
	"picareta": {"base": 650, "margem": 0.3},
	"foice": {"base": 420, "margem": 0.3},
	"facao": {"base": 380, "margem": 0.3},
	# O AÇO VEM DE FORA, e mais caro que o ferro: um machado de aço custa dois e
	# meio dos de ferro. É ele que abre a madeira de lei dura e a picareta de
	# aço, o matacão — o que o talento sozinho não abre (ver arvores_3d.json e
	# recursos_3d.json).
	"machado_de_aco": {"base": 1500, "margem": 0.3},
	"picareta_de_aco": {"base": 1600, "margem": 0.3},
	# A CARNE DE CAÇA vale mais que o peixe comum e menos que o robalo: é
	# trabalho de ir à mata funda, mas quem compra no arraial come peixe todo
	# dia e caça de vez em quando.
	"carne_de_caca": {"base": 120, "margem": 0.6},
	# O COURO DA ONÇA vale quatro caças: é uma onça por vez, a cinco dias uma
	# da outra, e cada uma custa vida. Menos que isso e ninguém sobe o penedo.
	"couro_de_onca": {"base": 480, "margem": 0.6},
	"banha_de_jararaca": {"base": 90, "margem": 0.6},
	"vara_de_pescar": {"base": 380, "margem": 0.3},
	"lampiao": {"base": 260, "margem": 0.35},
}

## Multiplicador por estação. Índices seguem Relogio.Estacao.
const ESTACAO := {
	0: {"mandioca": 1.0, "lenha": 1.0},
	1: {"mandioca": 1.2, "farinha": 1.25, "lenha": 0.9},   # estiagem: comida sobe
	2: {"mandioca": 0.9, "lenha": 1.15},
	3: {"mandioca": 0.95, "lenha": 1.35},                  # chuva: lenha seca vale
}


func mercadorias() -> Array:
	return MERCADORIAS.keys()


## Quanto o jogador paga para levar.
## O TALENTO ENTRA NO PREÇO, e é aqui que ele passou a entrar.
##
## "Olho de mercador" prometia compra 10% mais barata, "Bom de papo" e
## "Cordelista" prometiam o vendeiro pagando 10% a mais. Os três estavam
## escritos na árvore, custavam ponto, apareciam riscados na tela — e NINGUÉM
## LIA os campos. O jogador gastava ponto de ofício num número que não existia.
##
## Os dois bônus se somam: quem tem "Bom de papo" e "Cordelista" vende 20% mais
## caro. É de propósito, e é a leitura certa dos dois: um é saber conversar, o
## outro é saber os versos de cor, e os dois abrem a mesma porta.
##
## O teto de 60% existe porque margem é fração do preço base: sem ele, talento
## somado a talento acabaria fazendo o vendeiro pagar mais do que cobra, e o
## jogo viraria comprar e vender no mesmo balcão.
const LIMITE_DO_TALENTO := 0.6

func preco_de_compra(id: String) -> int:
	var dado: Dictionary = MERCADORIAS.get(id, {})
	if dado.is_empty():
		return 0
	var desconto := minf(Talentos.bonus("desconto_de_compra"), LIMITE_DO_TALENTO)
	return int(roundf(float(dado["base"]) * _peso_da_estacao(id) * (1.0 - desconto)))


## Quanto o vendeiro paga para ficar.
func preco_de_venda(id: String) -> int:
	var dado: Dictionary = MERCADORIAS.get(id, {})
	if dado.is_empty():
		return 0
	# O cordel NÃO passa por aqui: quem paga por folheto é a `Colecao`, que já
	# aplica o `valor_de_cordel` dela. Somar de novo seria pagar duas vezes o
	# mesmo talento.
	var a_mais := minf(Talentos.bonus("margem_de_venda"), LIMITE_DO_TALENTO)
	return int(roundf(float(dado["base"]) * float(dado["margem"])
		* _peso_da_estacao(id) * (1.0 + a_mais)))


func comprar(id: String, quantos: int = 1) -> bool:
	var preco := preco_de_compra(id) * quantos
	if preco <= 0 or Jogo.dinheiro < preco:
		return false
	if not Inventario.adicionar(id, quantos):
		return false
	Jogo.dinheiro -= preco
	negociou.emit()
	return true


func vender(id: String, quantos: int = 1) -> bool:
	if Inventario.quantidade(id) < quantos:
		return false
	var preco := preco_de_venda(id) * quantos
	if preco <= 0:
		return false
	Inventario.consumir(id, quantos)
	Jogo.dinheiro += preco
	negociou.emit()
	return true


func _peso_da_estacao(id: String) -> float:
	return float(ESTACAO.get(Relogio.estacao, {}).get(id, 1.0))
