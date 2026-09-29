extends Node
## Colecionáveis: o que o jogador acha pelo mapa e guarda para sempre.
##
## A primeira coleção são os CORDÉIS — folhetos de verso espalhados pelo
## arraial, uns famosos de verdade e outros inventados no mesmo tom. Achar um
## rende um dinheirinho, e é de propósito: o troco é o que faz o jogador
## olhar embaixo do banco da capela em vez de passar reto.
##
## O que ele rende de fato, porém, é OUTRA COISA. Os cordéis inventados falam
## da fazenda do capítulo 6, da moça que mora na água, do santo de pau oco. É
## por eles que o jogador vai desconfiando do que está acontecendo muito antes
## de alguém explicar — e sem nenhuma fala expositiva.
##
## A estrutura já nasce com mais de uma coleção em mente: cordel hoje, e
## depois receita, ex-voto, moeda antiga. O menu lê `COLECOES` e se vira.

signal achou(colecao: String, id: String)
signal mudou

const COLECOES := {
	"cordeis": {
		"nome": "Cordéis",
		"resumo": "Folhetos de verso, achados pelo caminho. Leia com calma: há mais neles do que rima.",
		"arquivo": "res://data/colecionaveis/cordeis.json",
		"chave": "cordeis",
		"tipo": "folheto",
	},
	## SINAIS: o que as entidades deixam para trás.
	##
	## Menu separado dos cordéis, e a separação é a razão de ele existir. Cordel
	## é história que ALGUÉM CONTOU — chega pronta, rimada, com moral. Sinal é
	## coisa que o JOGADOR VIU, e chega crua: um fio de cabelo numa pedra, uma
	## pegada virada para trás. Misturar os dois na mesma lista transformaria a
	## prova em folclore, que é justamente o contrário do que ela é.
	##
	## E NENHUM SINAL NOMEIA QUEM O DEIXOU — não na hora de achar. O caderno
	## registra o fenômeno, porque foi isso que aconteceu com o jogador: ele viu
	## uma coisa e não sabe o que foi. O nome só entra depois de o encontro
	## acontecer de verdade. Ver `revelado` e `nomeia`.
	"sinais": {
		"nome": "Sinais",
		"resumo": "O que fica para trás quando alguma coisa passa. Você viu, anotou, e não sabe o nome.",
		"arquivo": "res://data/colecionaveis/sinais.json",
		"chave": "sinais",
		"tipo": "sinal",
	},
	## BICHOS: uma página por espécie, aberta na primeira que o jogador derruba,
	## com quantas já caíram. É o quadro de metas da Guilda do Stardew no
	## tamanho deste jogo. Quem abre a página e conta é o `Luta`.
	"bichos": {
		"nome": "Bichos",
		"resumo": "O que se aprende brigando. Uma página por bicho, e quantos já caíram.",
		"arquivo": "res://data/colecionaveis/bichos.json",
		"chave": "bichos",
		"tipo": "bicho",
	},
}

## colecao -> Array de ids já achados, na ordem em que foram achados.
var achados: Dictionary = {}


func catalogo(colecao: String) -> Dictionary:
	var dados: Dictionary = COLECOES.get(colecao, {})
	if dados.is_empty():
		return {}
	return Jogo.dados(str(dados["arquivo"])).get(str(dados["chave"]), {})


func dados(colecao: String, id: String) -> Dictionary:
	return catalogo(colecao).get(id, {})


func tem(colecao: String, id: String) -> bool:
	return achados.get(colecao, []).has(id)


func quantos(colecao: String) -> int:
	return achados.get(colecao, []).size()


func total(colecao: String) -> int:
	return catalogo(colecao).size()


## Registra o achado e paga o troco. Devolve false se já tinha.
func achar(colecao: String, id: String) -> bool:
	if tem(colecao, id):
		return false
	var dado := dados(colecao, id)
	if dado.is_empty():
		push_warning("Colecionável desconhecido: %s/%s" % [colecao, id])
		return false
	if not achados.has(colecao):
		achados[colecao] = []
	achados[colecao].append(id)
	# "Olho de colecionador" faz o folheto render metade a mais.
	Jogo.dinheiro += int(roundf(int(dado.get("valor", 0))
		* (1.0 + Talentos.bonus("valor_de_cordel"))))
	Talentos.ganhar("rezar")      # achar coisa é olhar o mundo, e isso ensina
	achou.emit(colecao, id)
	mudou.emit()
	return true


## Ids na ordem do catálogo, para a tela listar sempre igual — inclusive os que
## o jogador ainda não achou, que aparecem como vaga em branco.
func ordem(colecao: String) -> Array:
	return catalogo(colecao).keys()


func tipo(colecao: String) -> String:
	return str(COLECOES.get(colecao, {}).get("tipo", "folheto"))


## ESTE SINAL JÁ PODE SER NOMEADO?
##
## Não na hora de achar, e é o ponto do sistema inteiro. O caderno registra o
## que o jogador viu — um fio de cabelo numa pedra, uma pegada virada para trás
## — e não diz de quem é, porque ele não sabe. Dizer na hora seria o jogo
## entregando a resposta do enigma junto com o enigma.
##
## O nome entra quando o ENCONTRO acontece: quando a carta daquele mito está na
## mão do jogador. Aí ele já ouviu a prosa dela, já sabe com quem falou, e o
## caderno só passa a registrar o que ele passou a saber.
##
## Sinal sem `de_quem` nunca é revelado — é fenômeno solto, e há de haver.
func nomeia(colecao: String, id: String) -> bool:
	var de_quem := str(dados(colecao, id).get("de_quem", ""))
	return de_quem != "" and Cartas.tem(de_quem)
