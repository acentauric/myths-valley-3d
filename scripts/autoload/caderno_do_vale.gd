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
## Qual da lista está em foco — a que o marcador segue. Índice em `por_importancia`.
var em_foco: int = 0


## Abre uma missão. Reabrir a mesma id não duplica.
func abrir_missao(id: String, titulo: String, dono: String = "",
		principal: bool = false) -> void:
	if id == "" or indice(id) >= 0:
		return
	ativas.append({"id": id, "titulo": titulo, "dono": dono, "principal": principal,
		"linha": "", "feito": 0, "total": 0, "alvo": Vector3.ZERO})
	abriu.emit(id)
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
	em_foco = clampi(em_foco, 0, maxi(0, ativas.size() - 1))
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


## A missão em foco, ou {} quando não há nenhuma.
func atual() -> Dictionary:
	var ordem := por_importancia()
	if ordem.is_empty():
		return {}
	return ordem[clampi(em_foco, 0, ordem.size() - 1)]


func fixar(id: String) -> void:
	var ordem := por_importancia()
	for i in ordem.size():
		if str((ordem[i] as Dictionary)["id"]) == id:
			em_foco = i
			mudou.emit()
			return


## Gira o foco para a próxima da lista. É o que a tecla de missão faz.
func girar_o_foco() -> void:
	var ordem := por_importancia()
	if ordem.size() <= 1:
		return
	em_foco = wrapi(em_foco + 1, 0, ordem.size())
	mudou.emit()


## Esvazia o caderno. Partida nova começa sem missão nenhuma.
func limpar() -> void:
	ativas.clear()
	cumpridas.clear()
	em_foco = 0
	mudou.emit()


## O QUE ENTRA NO SAVE. Missão em curso é estado de partida, e perder a lista ao
## recarregar seria o jogador voltando sem saber o que estava fazendo.
func estado() -> Dictionary:
	return {"ativas": ativas.duplicate(true), "cumpridas": cumpridas.duplicate(),
		"em_foco": em_foco}


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
	em_foco = int(guardado.get("em_foco", 0))
	mudou.emit()
