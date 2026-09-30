extends Node
## A PARTIDA DO VALE: em que vaga o jogador está, e como começar outra limpa.
##
## O `Salvamento` é o do 2D, compartilhado e sem uma linha mudada: três vagas,
## escrita atômica com releitura, migração em escada, limpeza do que sumiu.
## O que ele não faz — porque no 2D ninguém precisava — é ZERAR a partida.
##
## PARTIDA NOVA NÃO PODE HERDAR A ANTERIOR. Os sistemas são autoloads: vivem
## da abertura até o jogo fechar, e trocar de cena não os toca. Quem joga na
## vaga 1, volta ao menu e começa na vaga 2 levaria a mochila, a vida, o
## calendário e as missões da 1. Então, ao subir o jogo — antes de haver
## partida —, este nó tira um RETRATO DE FÁBRICA de tudo o que o save guarda,
## no mesmo formato do arquivo, e toda partida começa restaurando esse retrato.
## É o `carregar` do próprio `Salvamento`, com um "arquivo" que é o jogo no
## instante em que abriu: uma porta só para entrar no estado, e não duas.
##
## Entra por último na lista de autoloads, para o retrato sair depois de todos
## os sistemas terem feito o `_ready` deles.
##
## SEM VAGA NÃO SE SALVA, como no 2D. É o EXPLORAR da abertura: um passeio
## livre, que não grava nada e não apaga nada.

## O estado de todos os sistemas salvos no instante em que o jogo abriu.
var fabrica: Dictionary = {}


func _ready() -> void:
	fabrica = instantaneo()


## O estado de hoje, no formato do arquivo, sem escrever nada: a mesma tabela
## que o `Salvamento` percorre ao salvar. Cópia funda — o que os sistemas
## entregam é deles, e o retrato não pode mudar quando eles mudarem.
func instantaneo() -> Dictionary:
	var tudo := {"versao": Salvamento.VERSAO}
	for nome in Salvamento.O_QUE_GUARDAR:
		var sistema := get_node_or_null("/root/" + str(nome))
		if sistema == null:
			continue
		var secao := {}
		for campo in Salvamento.O_QUE_GUARDAR[nome]:
			secao[str(campo)] = sistema.get(str(campo))
		tudo[str(nome)] = secao
	# Fé, afinidade, cartas e terrenos têm estado privado: o `Salvamento` sabe
	# pegá-lo, e é ele quem pega. O mundo fica de fora: não há mundo no retrato.
	Salvamento._guardar_especiais(tudo)
	tudo.erase("Mundo")
	return tudo.duplicate(true)


## Começa a partida da vaga `slot` (0: passeio sem vaga). `apagar` apaga o que
## havia na vaga antes: é começar por cima, e só a tela de vagas, com a
## confirmação dela, chama assim.
##
## Sempre volta à fábrica primeiro, mesmo para CONTINUAR: o save traz todos os
## campos que guarda, mas um sistema que o save não conhece ficaria com o
## estado da partida anterior. O vale carrega o arquivo da vaga depois de
## montado (ver `prototype.gd`), como o 2D faz.
func comecar(slot: int, apagar: bool = false) -> void:
	if apagar and slot > 0:
		Salvamento.apagar(slot)
	# Mundo nenhum registrado enquanto a fábrica volta: o vale que se
	# apresentou pode já ter saído da árvore.
	Salvamento.registrar_mundo(null)
	Salvamento.carregar(fabrica.duplicate(true))
	Salvamento.ultimo_relato.clear()
	Salvamento.slot_atual = slot


## Salva a partida em curso, se ela tem vaga. Devolve false no passeio.
func salvar() -> bool:
	if Salvamento.slot_atual <= 0:
		return false
	return Salvamento.salvar()


func tem_vaga() -> bool:
	return Salvamento.slot_atual > 0
