extends Node
## Inventário: barra de mão + mochila.
##
## Os DEZ primeiros espaços são a BARRA DE MÃO, que aparece no rodapé e é o
## que o jogador troca com as teclas 1 a 9 e 0. O resto é MOCHILA, que só se vê
## abrindo o inventário (tecla I). É uma lista só por baixo do pano: assim
## empilhar, consumir e mover item não precisam saber de qual metade se trata.
##
## Dez e não seis porque com seis o jogador vivia abrindo a mochila: enxada,
## regador, machado, picareta e vara já eram cinco, e sobrava um espaço para
## semente, comida, isca e tábua ao mesmo tempo. Ferramenta que não cabe na
## mão vira menu, e menu no meio do trabalho quebra o ritmo da roça.

signal mudou
signal item_recebido(id: String, quantidade: int)
## Quiseram guardar `id` e não coube: a mochila está cheia (o viajante comenta, `falas_do_viajante.gd`).
signal sem_espaco(id: String)
## A MÃO mudou de espaço — e só isso.
##
## Separado de `mudou` porque os dois têm plateias diferentes. `mudou` dispara
## a cada machadada, a cada peixe, a cada tábua serrada; quem só quer saber que
## o jogador trocou o que tem na mão não pode ficar ouvindo isso. O balãozinho
## com o nome do item existe por causa desta diferença: ligado em `mudou`, ele
## piscaria na cara do jogador toda vez que um pau de lenha entrasse na
## mochila.
signal mao_trocada(indice: int)

const ESPACOS_MAO := 10
## Duas filas de dez embaixo da barra de mão, para a grade fechar certinho.
const ESPACOS_MOCHILA := 20
const ESPACOS := ESPACOS_MAO + ESPACOS_MOCHILA
const PILHA_MAXIMA := 99

## Nenhum espaço selecionado: o jogador está de mão livre.
const MAO_LIVRE := -1

## Cada espaço é {} (vazio) ou {"id": String, "qtd": int}.
var espacos: Array = []
var selecionado: int = MAO_LIVRE


func _ready() -> void:
	espacos.resize(ESPACOS)
	for i in ESPACOS:
		espacos[i] = {}


## A TECLA DA MÃO MORA NA BARRA, e não aqui.
##
## Este arquivo é regra: quantos espaços há, o que cabe em cada um, o que é
## estar de mão livre. A tecla que aciona a regra é outra coisa — depende do
## teclado, das telas que o projeto tem e de quem está na frente. Este
## sistema pertence ao vale; a interface escuta as teclas e chama a regra.
##
## Ver `barra_de_mao.gd`, que chama `alternar` e `selecionar`.


func proximo_da_mao() -> int:
	return 0 if selecionado == MAO_LIVRE else (selecionado + 1) % ESPACOS_MAO


func anterior_da_mao() -> int:
	return ESPACOS_MAO - 1 if selecionado == MAO_LIVRE else (selecionado - 1 + ESPACOS_MAO) % ESPACOS_MAO


## Aperta o número do espaço: pega o item, ou guarda o que já estava na mão.
## Sem isto não há como ficar de mão livre, que é o estado de colher.
func alternar(indice: int) -> void:
	selecionar(MAO_LIVRE if indice == selecionado else indice)


func selecionar(indice: int) -> void:
	var antes := selecionado
	selecionado = indice if indice >= 0 and indice < ESPACOS_MAO else MAO_LIVRE
	if selecionado != antes:
		mao_trocada.emit(selecionado)
	mudou.emit()


## O que vai escrito no canto do espaço: 1..9 e depois 0, a ordem do teclado.
## Fica aqui e não na HUD porque o rodapé e a tela do inventário desenham o
## mesmo número, e já divergiram uma vez.
func rotulo_do_espaco(indice: int) -> String:
	if indice == ESPACOS_MAO - 1:
		return "0"
	return str(indice + 1)


## Id do item na mão, ou "" se a mão estiver livre ou o espaço vazio.
func na_mao() -> String:
	if selecionado == MAO_LIVRE:
		return ""
	return espacos[selecionado].get("id", "")


func tipo_na_mao() -> String:
	var id := na_mao()
	return Catalogo.tipo(id) if id != "" else ""


func adicionar(id: String, quantidade: int = 1) -> bool:
	if not Catalogo.existe(id):
		push_error("Item desconhecido: %s" % id)
		return false

	var empilhavel: bool = Catalogo.dados(id).get("empilhavel", true)

	if empilhavel:
		for espaco in espacos:
			if espaco.get("id", "") == id and espaco["qtd"] < PILHA_MAXIMA:
				espaco["qtd"] += quantidade
				mudou.emit()
				item_recebido.emit(id, quantidade)
				return true

	# Enche a barra de mão primeiro: o que se pega é o que se vai usar.
	for i in ESPACOS:
		if espacos[i].is_empty():
			espacos[i] = {"id": id, "qtd": quantidade}
			mudou.emit()
			item_recebido.emit(id, quantidade)
			return true

	sem_espaco.emit(id)
	return false   # inventário cheio


## Troca dois espaços de lugar. É o que a tela da mochila usa para arrumar.
func trocar(a: int, b: int) -> void:
	if a == b or a < 0 or b < 0 or a >= ESPACOS or b >= ESPACOS:
		return
	var guardado = espacos[a]
	espacos[a] = espacos[b]
	espacos[b] = guardado
	mudou.emit()


## A FERRAMENTA DE ENCAIXE MORA NA BARRA DE MÃO, como as outras.
##
## O machado chegou a morar só na reserva — usado encaixando-o em "Mãos" na
## mochila —, e quem jogou apertava o número dele e nada acontecia: "o machado
## no inventário não tá subindo para a mão, os outros itens estão normal". Ele
## voltou a ser item de mão como a picareta e a foice, e o encaixe das Mãos
## ficou para as luvas.
##
## Partida salva no tempo da reserva tem o machado lá embaixo, onde o número
## não alcança. Este passo o sobe para o primeiro espaço livre da barra; sem
## espaço livre ele fica onde está, e o jogador o arrasta.
## As ferramentas que já moraram no encaixe das Mãos (que hoje é das luvas) e
## que uma partida antiga pode ter guardado na reserva.
const FERRAMENTAS_QUE_FORAM_DE_ENCAIXE := ["machado", "machado_de_aco", "facao"]

func trazer_ferramentas_para_a_mao() -> void:
	var mudou_de_lugar := false
	for origem in range(ESPACOS_MAO, ESPACOS):
		var id := str(espacos[origem].get("id", ""))
		if not FERRAMENTAS_QUE_FORAM_DE_ENCAIXE.has(id):
			continue
		var destino := -1
		for indice in ESPACOS_MAO:
			if espacos[indice].is_empty():
				destino = indice
				break
		if destino < 0:
			break
		espacos[destino] = espacos[origem]
		espacos[origem] = {}
		mudou_de_lugar = true
	if mudou_de_lugar:
		mudou.emit()


func vazio(indice: int) -> bool:
	return indice < 0 or indice >= ESPACOS or espacos[indice].is_empty()


func ocupados() -> int:
	var total := 0
	for espaco in espacos:
		if not espaco.is_empty():
			total += 1
	return total


## Quantos deste item a mochila tem, somando as pilhas.
##
## ID VAZIO É ZERO, e não "todos os espaços vazios". Um espaço livre é `{}`, e
## `get("id", "")` devolve "" nele — perguntar a conta de "" casava com cada
## espaço livre e morria no `qtd` que ele não tem. Quem chegava aqui era o
## trabalho: alvo cuja ficha não nomeia ferramenta pergunta por "".
func quantidade(id: String) -> int:
	if id == "":
		return 0
	var total := 0
	for espaco in espacos:
		if espaco.get("id", "") == id:
			total += int(espaco.get("qtd", 0))
	return total


func tem(id: String) -> bool:
	return quantidade(id) > 0


## Tira `quantidade` do item. Devolve false se não houver o bastante.
func consumir(id: String, quantidade_pedida: int = 1) -> bool:
	if quantidade(id) < quantidade_pedida:
		return false

	var falta := quantidade_pedida
	for i in ESPACOS:
		if espacos[i].get("id", "") != id:
			continue
		var tirar: int = mini(falta, espacos[i]["qtd"])
		espacos[i]["qtd"] -= tirar
		falta -= tirar
		if espacos[i]["qtd"] <= 0:
			espacos[i] = {}
		if falta <= 0:
			break

	mudou.emit()
	return true
