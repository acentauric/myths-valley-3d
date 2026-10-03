extends Node
## O CADERNO DE MISSÕES DO VALE — o mecanismo do 3D, e não o checklist do 2D.
##
## POR QUE ELE EXISTE, e por que a primeira tentativa foi desfeita.
##
## Quando a aba de missões do painel J apareceu vazia, eu liguei as cadeias do
## vale ao `Missoes` compartilhado com o jogo 2D: cada passo entrava lá com a
## checklist de itens daquele autoload, e o painel lia dali. Funcionou, e estava
## errado — pela razão que o autor deu:
##
##     "Não devemos usar o checklist in-game. O objetivo é que o jogo 3D tenha
##      seus próprios mecanismos de missões, sem dependência desse checklist,
##      porque no futuro podemos criar novas missões e/ou adaptar missões que já
##      existem em um padrão, formato e ordem diferente do 2D."
##
## É uma razão de projeto, não de gosto. O `Missoes` do 2D carrega a forma das
## missões DE LÁ: lista de itens que se risca e desrisca, foco que gira, missão
## passiva, missão de fé que congela, `PRINCIPAIS` como condição da jornada da
## fazenda. Cada uma dessas coisas é uma decisão do jogo 2D, e amarrar o vale a
## elas seria escrever as missões do 3D no formato de outro jogo antes de saber
## qual é o formato do 3D.
##
## O 2D continua sendo a referência — as falas, os passos, o que cada morador
## pede vieram de lá e vão continuar vindo. O que não vem é o MECANISMO.
##
##
## O QUE ESTE CADERNO SABE, E O QUE ELE NÃO SABE
##
## Uma missão aqui é pequena de propósito:
##
##     id        quem ela é, com o dono na frente ("damiao_coveiro_limpar")
##     titulo    a frase que o morador disse, que é o que o jogador leu
##     dono      o id do morador que a deu, para a tela agrupar por pessoa
##     principal se ela é de enredo — as de enredo vêm primeiro na lista
##     linha     UMA linha de andamento, escrita por quem conduz
##     feito     quanto já foi, e de quanto (`total`); 0/0 quer dizer "sem conta"
##     alvo      onde o marcador aponta, ou `Vector3.ZERO`
##     texto     a fala inteira de quem pediu, que só o diário (J) mostra
##
## E, escrito por `descrever`, o que o diário e o HUD mostram da missão
## inteira: `missao` (o nome dela), `quem` (o nome de quem a deu), `resumo` (a
## linha do HUD), `passo` e `passos` (em qual está, de quantos) e `feitos` (os
## resumos dos passos já cumpridos, que o diário risca).
##
## NÃO HÁ CHECKLIST. Uma missão tem uma linha de andamento e não uma lista de
## itens, e é essa a diferença que importa: quem conduz decide o que escrever
## nela — "2 de 4 pés de capim", "levar o pirão ao Tonho" —, e o caderno não
## tenta entender. Missão nova com regra nova não precisa de campo novo aqui.
##
## E ele NÃO sabe cumprir nada. Não conta item, não olha o mundo, não decide
## quando um passo fecha. Quem sabe disso é a cadeia (`cadeia_de_missoes.gd`),
## que é quem tem o dado e o jogador na mão. O caderno é onde o que ela sabe
## fica escrito para a tela ler.

signal mudou
signal abriu(id: String)
signal concluiu(id: String)

## As missões em curso, na ordem em que foram abertas.
var ativas: Array[Dictionary] = []
## Os ids já cumpridos, para não reabrir e para a tela poder dizer "já fiz".
var cumpridas: Array[String] = []

## A MISSÃO ACOMPANHADA, pelo ID — e não pela posição na lista.
##
## "No MENU J, de missões, eu tô clicando para trocar a missão de resumo, mas
## não muda. O comportamento tem que ser muito próximo de jogos de RPG como The
## Witcher 3." Eram dois defeitos. O HUD e a seta seguiam a última cadeia que
## FALOU, e não esta escolha; e a escolha era um ÍNDICE em `por_importancia` —
## missão que abria ou fechava antes dela na lista mudava, calada, qual estava
## em foco. Acompanhar é escolher UMA missão, e o nome de uma missão é o id.
##
## Como no Witcher: o que o jogador escolhe fica escolhido. O passo seguinte da
## missão acompanhada herda o acompanhamento (`_cadeia_do_foco`); missão nova
## de outra pessoa NÃO o rouba — só é acompanhada sozinha quando não há nenhuma.
var foco: String = ""
## A mesma escolha como posição em `por_importancia`, que é como a lista do
## painel a desenha. Escrever aqui escolhe a missão daquela posição.
var em_foco: int:
	get:
		var ordem := por_importancia()
		for i in ordem.size():
			if str((ordem[i] as Dictionary)["id"]) == str(atual().get("id", "")):
				return i
		return 0
	set(valor):
		var ordem := por_importancia()
		if ordem.is_empty():
			return
		var escolhida: Dictionary = ordem[clampi(valor, 0, ordem.size() - 1)]
		foco = str(escolhida["id"])
		_cadeia_do_foco = str(escolhida.get("dono", ""))
## De quem é a missão acompanhada. Quando ela se cumpre, o próximo passo DA
## MESMA PESSOA é acompanhado ao abrir — é a mesma missão andando.
var _cadeia_do_foco := ""


## Abre uma missão. Reabrir a mesma id não duplica.
##
## `texto` é a fala inteira de quem pediu. O HUD mostra só o resumo; a fala
## inteira mora aqui, e é o painel do J que a mostra. Missão aberta por uma
## partida de antes do campo ganha o texto quando o passo se reabre.
func abrir_missao(id: String, titulo: String, dono: String = "",
		principal: bool = false, texto: String = "") -> void:
	if id == "":
		return
	var ja := indice(id)
	if ja >= 0:
		if texto != "" and str(ativas[ja].get("texto", "")) == "":
			ativas[ja]["texto"] = texto
			mudou.emit()
		return
	ativas.append({"id": id, "titulo": titulo, "dono": dono, "principal": principal,
		"texto": texto, "linha": "", "feito": 0, "total": 0, "alvo": Vector3.ZERO})
	# QUEM HERDA O ACOMPANHAMENTO: o passo seguinte da missão acompanhada, ou
	# qualquer missão quando não há nenhuma acompanhada.
	if not tem(foco) and (foco == "" or dono == _cadeia_do_foco):
		foco = id
		_cadeia_do_foco = dono
	abriu.emit(id)
	mudou.emit()


## O QUE A MISSÃO É, além do passo: o nome dela (a missão inteira, e não o
## passo), quem a deu, o resumo do HUD, em que passo está e os passos já
## feitos. É o que o diário do J desenha à direita — nome, quem pediu, a fala,
## os objetivos riscados e o de agora — e o que o HUD mostra da acompanhada.
## Só emite `mudou` quando algo mudou, porque a cadeia chama isto a cada pulso.
func descrever(id: String, dados: Dictionary) -> void:
	var i := indice(id)
	if i < 0:
		return
	var mexeu := false
	for chave in dados:
		if ativas[i].get(chave) != dados[chave]:
			ativas[i][chave] = dados[chave]
			mexeu = true
	if mexeu:
		mudou.emit()


## O ANDAMENTO, numa linha só, escrita por quem conduz.
##
## `feito` e `total` são para a barra e para o "2 de 4"; `linha` é a frase. Quem
## não tem conta manda 0 e 0, e a tela mostra só a frase.
##
## Só emite `mudou` quando algo de fato mudou: isto é chamado a cada pulso da
## cadeia, e tela que se redesenha sessenta vezes por segundo pisca.
func andar(id: String, feito: int, total: int, linha: String = "") -> void:
	var i := indice(id)
	if i < 0:
		return
	var antes: Dictionary = ativas[i]
	if int(antes["feito"]) == feito and int(antes["total"]) == total \
			and str(antes["linha"]) == linha:
		return
	ativas[i]["feito"] = feito
	ativas[i]["total"] = total
	ativas[i]["linha"] = linha
	mudou.emit()


## Onde o marcador desta missão aponta. `Vector3.ZERO` quer dizer "em lugar nenhum".
func apontar(id: String, alvo: Vector3) -> void:
	var i := indice(id)
	if i < 0 or (ativas[i]["alvo"] as Vector3).is_equal_approx(alvo):
		return
	ativas[i]["alvo"] = alvo
	mudou.emit()


func alvo_de(id: String) -> Vector3:
	var i := indice(id)
	return ativas[i]["alvo"] if i >= 0 else Vector3.ZERO


func concluir(id: String) -> void:
	var i := indice(id)
	if i < 0:
		return
	ativas.remove_at(i)
	if not cumpridas.has(id):
		cumpridas.append(id)
	# O `foco` fica apontando a cumprida de propósito: é assim que o próximo
	# passo da mesma pessoa o herda ao abrir (ver `abrir_missao`). Até lá,
	# `atual` cai na primeira da lista.
	concluiu.emit(id)
	mudou.emit()


func tem(id: String) -> bool:
	return indice(id) >= 0


func cumprida(id: String) -> bool:
	return cumpridas.has(id)


func indice(id: String) -> int:
	for i in ativas.size():
		if str(ativas[i]["id"]) == id:
			return i
	return -1


func de(id: String) -> Dictionary:
	var i := indice(id)
	return ativas[i] if i >= 0 else {}


## "2 de 4" desta missão, ou (0, 0) quando ela não tem conta.
func andamento(id: String) -> Vector2i:
	var missao := de(id)
	if missao.is_empty():
		return Vector2i.ZERO
	return Vector2i(int(missao["feito"]), int(missao["total"]))


## AS MISSÕES EM ORDEM DE LEITURA: as de enredo primeiro.
##
## Quem tem enredo aberto quer cair nele antes de cair num favor de vizinho — é
## a mesma ideia do 2D, mas a lista de quais são de enredo NÃO É UMA CONSTANTE
## AQUI: quem abre a missão diz se ela é, no `principal`. No 2D aquela lista
## também era a condição da jornada da fazenda, e é justamente o tipo de
## amarração que este caderno não tem.
func por_importancia() -> Array:
	var enredo: Array = []
	var resto: Array = []
	for missao in ativas:
		if bool(missao.get("principal", false)):
			enredo.append(missao)
		else:
			resto.append(missao)
	return enredo + resto


## A missão acompanhada, ou {} quando não há nenhuma aberta. Com a acompanhada
## cumprida e o passo seguinte ainda por abrir, vale a primeira da lista.
func atual() -> Dictionary:
	var i := indice(foco)
	if i >= 0:
		return ativas[i]
	var ordem := por_importancia()
	return {} if ordem.is_empty() else ordem[0]


## ACOMPANHA ESTA MISSÃO. É o "Acompanhar" do diário: o HUD, a seta e a bússola
## passam a seguir esta, e ela fica escolhida até o jogador escolher outra.
func fixar(id: String) -> void:
	var i := indice(id)
	if i < 0 or foco == id:
		return
	foco = id
	_cadeia_do_foco = str(ativas[i].get("dono", ""))
	mudou.emit()


func acompanhada(id: String) -> bool:
	return id != "" and str(atual().get("id", "")) == id


## Gira o foco para a próxima da lista. É o que a tecla de missão faz.
func girar_o_foco() -> void:
	var ordem := por_importancia()
	if ordem.size() <= 1:
		return
	fixar(str((ordem[wrapi(em_foco + 1, 0, ordem.size())] as Dictionary)["id"]))


## Esvazia o caderno. Partida nova começa sem missão nenhuma.
func limpar() -> void:
	ativas.clear()
	cumpridas.clear()
	foco = ""
	_cadeia_do_foco = ""
	mudou.emit()


## O QUE ENTRA NO SAVE. Missão em curso é estado de partida, e perder a lista ao
## recarregar seria o jogador voltando sem saber o que estava fazendo. O `foco`
## vai pelo id; `em_foco` continua indo, para a partida salva antes dele.
func estado() -> Dictionary:
	return {"ativas": ativas.duplicate(true), "cumpridas": cumpridas.duplicate(),
		"em_foco": em_foco, "foco": foco}


func restaurar(guardado: Dictionary) -> void:
	ativas.clear()
	for bruta in guardado.get("ativas", []):
		var missao: Dictionary = (bruta as Dictionary).duplicate(true)
		# O alvo volta como Vector3: o JSON o guarda como array de três números.
		var alvo = missao.get("alvo", Vector3.ZERO)
		if typeof(alvo) == TYPE_ARRAY and (alvo as Array).size() == 3:
			missao["alvo"] = Vector3(float(alvo[0]), float(alvo[1]), float(alvo[2]))
		ativas.append(missao)
	cumpridas.clear()
	for id in guardado.get("cumpridas", []):
		cumpridas.append(str(id))
	foco = ""
	_cadeia_do_foco = ""
	if str(guardado.get("foco", "")) != "":
		foco = str(guardado["foco"])
		var i := indice(foco)
		_cadeia_do_foco = str(ativas[i].get("dono", "")) if i >= 0 else ""
	else:
		em_foco = int(guardado.get("em_foco", 0))
	mudou.emit()
