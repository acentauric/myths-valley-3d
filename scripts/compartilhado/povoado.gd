extends Node
## O ARRAIAL COMO COISA QUE CRESCE: a perícia dos moradores, a amizade e as obras comunitárias (#9).
##
## Veio do `Povoado` do 2D, com a mesma conta. O que muda é de onde ela lê: quem está trabalhando e
## onde vem do `Terrenos` (o ofício de cada um, em lote que o `Terras` diz ser do jogador), e os
## números (degraus, amizade, obras) moram em data/povoado_3d.json, com os nomes nos idiomas do jogo.
##
## O jogo já sabe mandar um morador lavrar (`Terrenos.trabalho`), e o rendimento dele seria um número
## fixo: dois de mandioca por dia, para sempre, fosse o primeiro dia ou o centésimo. Mandar trabalhar
## seria uma decisão que se toma uma vez e nunca mais.
##
## É a peça mais subaproveitada de um jogo de fazenda, e é a que o Graveyard Keeper acerta com os
## zumbis: em certo ponto o jogador PARA DE FAZER e passa a MANDAR FAZER, e o jogo muda de escala sem
## mudar de mecânica.
##
##
## TRÊS COISAS MEXEM NO QUE UM MORADOR RENDE
##
##   PERÍCIA      quantos dias ele já fez AQUELE ofício. Sobe sozinha, com o trabalho, e é por ofício:
##                o Cosme que passou quarenta dias na roça não vira mestre de farinha ao ser mandado
##                para a casa de farinha. É isto que faz duas partidas divergirem: não dá para ter
##                todo mundo mestre em tudo, porque cada um só faz uma coisa por vez e o dia é um só.
##
##   AFINIDADE    quem gosta de você trabalha melhor. Não é bônus de simpatia: é a convivência
##                pagando na produção, e é o que faz visitar gente valer para quem só quer produzir.
##
##   O ARRAIAL    as obras comunitárias. Ver `obras_do_arraial`.
##
## As três se MULTIPLICAM, e é de propósito: um mestre querido num arraial bem montado rende umas três
## vezes o que rende um estranho recém-chegado fazendo o mesmo serviço. É essa distância que faz o meio
## do jogo ter para onde ir. Somam-se a elas, por fora, os dois talentos do patrão: "Palavra de patrão"
## (quem trabalha para você rende mais) e "Mestre de ofício" (cada dia de serviço conta por dois).
##
##
## O QUE ISTO NÃO É
##
## Não é árvore de talentos por morador. A divergência vem do TEMPO gasto, que é mais barato de
## implementar e já produz o efeito que importa: o Cosme de uma partida não é o Cosme de outra.
##
##
## UMA FÓRMULA SÓ
##
## `renderia_exata` é a ÚNICA conta de produção do jogo: quem entrega de manhã (`entregar_o_dia`) e
## quem mostra na tela antes de o jogador decidir (`renderia`, `producao_do_dia`) passam os dois por
## ela. Duas cópias da mesma fórmula divergem, é questão de tempo, e aí a tela promete uma coisa e a
## mochila recebe outra.

signal mudou

const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const ARQUIVO := "res://data/povoado_3d.json"
## A folga da conta de ponto flutuante. 0,1 somado dez vezes dá 0,9999999999999999, e sem folga o item
## que fecha EXATAMENTE no dia só sairia no dia seguinte.
const FOLGA := 0.000000001

## morador -> {ofício: dias feitos}. Vai no save.
var pericia: Dictionary = {}

## O QUE SOBROU DE ONTEM. item -> fração menor que 1. Vai no save.
##
## É o que faz a conta fechar. A conta é de ponto flutuante (perícia, amizade, idade e obras são todos
## multiplicadores), e o resultado de um dia, jogado num arredondamento, perderia a parte decimal TODO
## DIA, por morador, por item. Duas consequências, e a segunda é pior:
##
##   O SALDO NÃO FECHA. Quem rende 2,3 entrega 2; quem rende 2,7 entrega 3. Os degraus de perícia e
##   os graus de amizade mexem no número e o jogador não vê a diferença, porque ela morre no
##   arredondamento.
##
##   QUEM RENDE POUCO NÃO RENDE NADA. Um morador de 0,4 por dia entregaria ZERO, hoje, amanhã e
##   daqui a cem dias. Não é lentidão: é uma torneira fechada com cara de aberta.
##
## Com a sobra, 0,4 por dia é um item a cada dois dias e meio, e os degraus passam a valer exatamente
## o que prometem. Por ITEM e não por morador: o jogador recebe um monte de mandioca, não a mandioca
## do Cosme e a do Tonho em pilhas separadas. Nada disso aparece na tela: meia mandioca não é coisa
## que se mostre a ninguém.
##
## PÚBLICA porque é estado de partida: entra na tabela do `Salvamento` como qualquer outro campo.
## Guardada como privada, voltaria zerada a cada carregamento e o jogador perderia a sobra do dia toda
## vez que salvasse.
var sobra: Dictionary = {}


# --- os dados --------------------------------------------------------------------------

## Os degraus de perícia, do aprendiz ao mestre: {de: dias de serviço, nome, rende: multiplicador}.
## Os dias são a estação: 28 é uma estação inteira, e chegar a mestre custa mais de duas. Devagar de
## propósito: perícia que sobe depressa é perícia que ninguém nota subindo.
func degraus() -> Array:
	return Jogo.dados(ARQUIVO).get("degraus", [])


## Quanto a amizade soma, do desconhecido ao da família, um número por grau de `Afinidade`. Não zera
## para quem é estranho: um estranho pago trabalha, só não se esforça. Zerar faria o jogador que não
## visita ninguém ficar sem automação nenhuma, e a automação é o que sustenta o meio do jogo.
func por_grau_de_afinidade() -> Array:
	return Jogo.dados(ARQUIVO).get("por_grau_de_afinidade", [1.0])


## AS OBRAS QUE SERVEM AO ARRAIAL, e não a você.
##
## É a diferença entre elas e as da sua casa: a varanda aumenta o SEU fôlego, o açude rega o SEU
## roçado. Estas melhoram o que os OUTROS rendem, e por isso só valem para quem tem gente
## trabalhando. São o investimento de quem parou de fazer e passou a mandar fazer.
##
## NENHUMA PEÇA NOVA. Todas as cinco se penduram em coisa que já está de pé no mapa e que antes era
## enfeite puro: o poço da praça, o forno de barro, o monjolo do riacho, a carroça e o trapiche da
## praia. Cada uma serve a UM OU DOIS ofícios, pelo que a peça faz de verdade, e o trapiche serve a
## todos (lista vazia): o que ele melhora não é a ferramenta, é ter para quem vender.
func obras_do_arraial() -> Dictionary:
	return Jogo.dados(ARQUIVO).get("obras_do_arraial", {})


# --- a perícia -------------------------------------------------------------------------

## O dia de serviço entra no caderno. "Mestre de ofício" faz cada dia contar por dois, e nunca por
## menos de um: senão o talento poderia parar o aprendizado.
func _somar_dia(morador: String, oficio: String) -> void:
	if not pericia.has(morador):
		pericia[morador] = {}
	var dele: Dictionary = pericia[morador]
	var quanto := maxi(1, roundi(1.0 + Talentos.bonus("pericia_do_morador")))
	dele[oficio] = int(dele.get(oficio, 0)) + quanto


func dias_de(morador: String, oficio: String) -> int:
	return int((pericia.get(morador, {}) as Dictionary).get(oficio, 0))


func grau_de_pericia(morador: String, oficio: String) -> int:
	var dias := dias_de(morador, oficio)
	var lista := degraus()
	var qual := 0
	for i in lista.size():
		if dias >= int((lista[i] as Dictionary).get("de", 0)):
			qual = i
	return qual


## O multiplicador de um degrau.
func rende_do_degrau(grau: int) -> float:
	var lista := degraus()
	if lista.is_empty():
		return 1.0
	return float((lista[clampi(grau, 0, lista.size() - 1)] as Dictionary).get("rende", 1.0))


## "Aprendiz", "mestre": o degrau, no idioma do jogo.
func nome_da_pericia(morador: String, oficio: String) -> String:
	var lista := degraus()
	if lista.is_empty():
		return ""
	return str(IdiomaMenu.campo(lista[grau_de_pericia(morador, oficio)], "nome", ""))


## Quantos dias de serviço faltam para o próximo degrau, ou -1 no último.
func falta_para_o_proximo(morador: String, oficio: String) -> int:
	var lista := degraus()
	var qual := grau_de_pericia(morador, oficio)
	if qual >= lista.size() - 1:
		return -1
	return int((lista[qual + 1] as Dictionary).get("de", 0)) - dias_de(morador, oficio)


## Conta o dia de serviço de quem está trabalhando. Chamado pelo `Terrenos` DEPOIS de entregar o dia,
## nunca antes: o que o morador entrega de manhã é o que a perícia dele valia ontem, e o dia que ele
## acabou de trabalhar só passa a contar para amanhã. Invertida a ordem, o morador renderia no degrau
## novo um dia antes de tê-lo.
##
## Só conta o dia em terra que é SUA (é o que `Terrenos.trabalhando` já garante): morador em terra de
## outro está cuidando do que é dele, e isso não é serviço que o jogador mandou fazer.
func contar_o_dia() -> void:
	var quem: Dictionary = Terrenos.trabalhando()
	for morador in quem:
		_somar_dia(str(morador), str(quem[morador]))
	mudou.emit()


# --- o arraial -------------------------------------------------------------------------

func obra_do_arraial_feita(obra: String) -> bool:
	var dado: Dictionary = obras_do_arraial().get(obra, {})
	if dado.is_empty():
		return false
	return Obras.ja_feita(str(dado.get("construcao", "")), obra)


## Quanto as obras do arraial somam NAQUELE ofício. Somam entre si: quem consertou o poço e o monjolo
## tem as duas, e é isso que faz valer a pena continuar levantando depois da primeira.
func rende_do_arraial(oficio: String) -> float:
	var soma := 0.0
	var obras := obras_do_arraial()
	for obra in obras:
		var dado: Dictionary = obras[obra]
		var quais: Array = dado.get("oficios", [])
		if not quais.is_empty() and not quais.has(oficio):
			continue
		if obra_do_arraial_feita(str(obra)):
			soma += float(dado.get("rende", 0.0))
	return soma


## O MULTIPLICADOR INTEIRO de um morador naquele ofício: perícia, amizade e obras do arraial. É o que
## `renderia_exata` pergunta na hora de contar a produção.
func rendimento(morador: String, oficio: String) -> float:
	var por_pericia := rende_do_degrau(grau_de_pericia(morador, oficio))
	var afetos := por_grau_de_afinidade()
	var por_afeto := 1.0
	if not afetos.is_empty():
		por_afeto = float(afetos[clampi(Afinidade.grau(morador), 0, afetos.size() - 1)])
	return por_pericia * por_afeto * (1.0 + rende_do_arraial(oficio))


## O RETRATO DO ARRAIAL, num punhado de números.
##
## Existe porque crescimento que não se mede não se sente. O jogador vê a fazenda mudar de aparência;
## o arraial é abstrato, e precisa de um lugar onde o progresso apareça. Os quatro números são os que
## o jogador de fato move: terra que ele tomou (fora o roçado, que já era dele), gente que ele pôs
## para trabalhar, obra que ele levantou para os outros, e o que tudo isso entrega por dia.
func retrato() -> Dictionary:
	var minhas := 0
	var lotes: Dictionary = Jogo.dados(Terras.ARQUIVO).get("lotes", {})
	for id in lotes:
		if str((lotes[id] as Dictionary).get("dono", "")) != "" and Terras.meu(str(id)):
			minhas += 1

	var trabalhando := 0
	var mestres := 0
	var quem: Dictionary = Terrenos.trabalhando()
	for morador in quem:
		trabalhando += 1
		if grau_de_pericia(str(morador), str(quem[morador])) >= degraus().size() - 1:
			mestres += 1

	var comunitarias := 0
	for obra in obras_do_arraial():
		if obra_do_arraial_feita(str(obra)):
			comunitarias += 1

	return {
		"terras": minhas,
		"trabalhando": trabalhando,
		"mestres": mestres,
		"comunitarias": comunitarias,
		"por_dia": producao_do_dia(),
	}


# --- a produção ------------------------------------------------------------------------

## O QUE UM MORADOR ENTREGA POR DIA naquele ofício, item a item, em inteiros: a vista da conta, para a
## tela. Não confere se a terra é sua nem mexe na sobra — quem chama é que sabe se está entregando o
## dia ou mostrando um "renderia". A tela precisa poder responder "quanto ele renderia se eu mandasse"
## antes de a resposta existir.
func renderia(morador: String, oficio: String) -> Dictionary:
	var conta: Dictionary = {}
	var exata := renderia_exata(morador, oficio)
	for item in exata:
		var inteiro := roundi(float(exata[item]))
		if inteiro > 0:
			conta[item] = inteiro
	return conta


## A MESMA CONTA, SEM ARREDONDAR. É esta que manda; `renderia` é a vista dela. Quem fecha o saldo é
## `entregar_o_dia`, guardando a sobra de um dia para o outro (ver `sobra`).
##
## A ordem dos fatores é a do 2D: o que o ofício rende por dia, devagar com o idoso (ele trabalha, mas
## no ritmo dele), vezes perícia, amizade e obras, vezes o talento do patrão.
func renderia_exata(morador: String, oficio: String) -> Dictionary:
	var conta: Dictionary = {}
	var rende: Dictionary = Terrenos.rende(oficio)
	for item in rende:
		var quanto := float(rende[item])
		if Terrenos.e_idoso(morador):
			quanto *= Terrenos.ritmo_do_idoso()
		quanto *= rendimento(morador, oficio)
		# "Palavra de patrão": quem sabe pedir é melhor servido.
		quanto *= 1.0 + Talentos.bonus("rendimento_do_morador")
		conta[item] = quanto
	return conta


## O que o arraial entrega HOJE, somado, contando a sobra de ontem. NÃO MEXE EM NADA.
##
## Prever e entregar são duas funções, e a separação é obrigatória desde que a sobra existe. A conta
## consome a sobra, e uma consulta que consome é uma armadilha: a tela pergunta, a sobra anda, e de
## manhã a mochila recebe um número diferente do que a tela tinha prometido.
func producao_do_dia() -> Dictionary:
	return _contar_o_dia(false)


## Fecha o dia: entrega os inteiros e guarda a fração para amanhã. Chamada uma vez por dia, pelo
## `Terrenos`, quando amanhece.
func entregar_o_dia() -> Dictionary:
	return _contar_o_dia(true)


func _contar_o_dia(guardar: bool) -> Dictionary:
	var exato: Dictionary = {}
	var quem: Dictionary = Terrenos.trabalhando()
	for morador in quem:
		var conta := renderia_exata(str(morador), str(quem[morador]))
		for item in conta:
			exato[item] = float(exato.get(item, 0.0)) + float(conta[item])

	var total: Dictionary = {}
	for item in exato:
		var com_a_sobra: float = float(exato[item]) + float(sobra.get(item, 0.0))
		# FLOOR e não ROUND, e é o que torna a sobra honesta: arredondar já adianta meia unidade, e
		# aí a sobra guardada seria negativa — o jogador receberia hoje o que ia produzir amanhã, e
		# amanhã receberia de menos sem saber por quê.
		var inteiro := floori(com_a_sobra + FOLGA)
		if guardar:
			sobra[item] = maxf(0.0, com_a_sobra - float(inteiro))
		if inteiro > 0:
			total[item] = inteiro
	return total
