extends Node
## Missões ativas.
##
## O jogo pode ter mais de uma tarefa aberta ao mesmo tempo — é o que evita o
## beco do "durma e espere": enquanto a mandioca cresce, há outra coisa para
## fazer. O jogador troca a missão em foco com Tab.

signal mudou
signal concluida(id: String)
## UM PASSO ABRIU. Serve ao `Receitas`, e a razão de ser a abertura e não o
## fecho está lá: lição se dá ANTES do trabalho. O passo que manda torrar
## farinha é o passo que ensina a torrar farinha — esperar ele fechar seria
## cobrar do jogador uma receita que ele não tem.
signal abriu(id: String)

## Cada item: {"id", "titulo", "passiva", "alvo"?, "lista"?}
## Passiva = corre sozinha (esperar a planta crescer); não some do HUD, mas o
## jogador não precisa persegui-la.
## `alvo` é o ponto no mundo que a bússola aponta. Missão sem alvo não ganha
## marcador — é o caso das passivas.
##
## `lista` é a CHECKLIST: uma missão pode pedir três coisas que não têm ordem
## entre si. Cada item é {"id", "texto", "feito"}, e a missão fecha quando
## todos estiverem feitos — na ordem que o jogador quiser.
##
## Isto existe porque o contrário quebrou: a primeira roça era arar, depois
## plantar, depois regar, cada passo esperando o anterior. Quem regou antes de
## plantar ficava preso, porque a terra já estava molhada e o passo "regar"
## nunca chegava. Tarefa sem ordem natural não pode virar fila.
var ativas: Array = []

## As já CUMPRIDAS, por id. Vai para o salvamento junto com `ativas`: é o que
## impede uma missão de fé de reabrir quando o arraial recomeça numa partida
## carregada. As outras frentes leem o mundo para saber o que já foi feito
## (terra comprada, obra de pé); a romaria não deixa nada no mundo além de ter
## sido andada. Ver `Arraial._frente_das_fes`.
var cumpridas: Array = []
var em_foco: int = 0

## A MISSÃO QUE ESTAVA EM FOCO FECHOU e ainda ninguém tomou o lugar dela.
##
## Vale até a próxima missão abrir — que herda o foco — ou até o jogador fixar
## uma à mão. Não é salvo: é um estado de meio segundo entre fechar um passo e
## abrir o seguinte, e carregar uma partida com ele de pé faria a primeira
## missão que abrisse roubar o foco sem razão.
## O FOCO FICOU VAGO: a missão em foco fechou e a próxima ainda não abriu.
##
## Era só um bool, e o bool tinha dois defeitos que o jogador viu como um:
## "quando completo uma task de uma linha de missão, está trocando a missão
## fixada". Entre fechar "as ervas" e abrir "o Cosme" há uma fala inteira da
## Dona Zefa — e nesse tempo `em_foco` apontava para quem quer que tivesse
## caído no índice vago, e a HUD mostrava a horta. Pior: se QUALQUER outra
## frente abrisse uma missão nesse intervalo, ela herdava o foco, e a linha
## que o jogador estava seguindo sumia da tela para sempre.
##
## Três coisas consertam isso, e as três moram aqui:
##
##   `_linha_orfa`   de que linha era a missão que fechou. Só missão da MESMA
##                   linha herda o foco. A linha é declarada por quem abre
##                   (ver `adicionar`), porque prefixo de id não serve — o
##                   tutorial não tem prefixo e a série do Tonho troca de
##                   prefixo no meio (`pescador_` -> `tonho_`).
##   `_orfao_desde`  quando ficou vago. Linha que não continua em pouco tempo
##                   é linha que acabou, e aí o foco cai na missão mais
##                   importante em vez de ficar vazio para sempre.
##   `atual()`       enquanto vago, devolve NADA — e não o vizinho de índice.
var _foco_orfao: bool = false
var _linha_orfa: String = ""
var _orfao_desde: int = 0
## Quanto tempo o foco fica vago à espera da mesma linha. Cobre a fala de
## arremate mais longa do jogo com folga; passou disso, a linha acabou.
const ESPERA_DA_LINHA := 15000


## A TECLA TAB MORA NO `Controles`, e não aqui — como a da mão.
##
## Este arquivo é regra: que missões existem, qual está em foco, o que conta
## como cumprida. A tecla que gira o foco depende do teclado e das telas que o
## projeto tem, e o protótipo 3D não tem nem a ação `trocar_missao` nem o
## `Telas`. Ver `Controles._unhandled_input`.
##
## Girar o foco continua sendo daqui, porque é regra: quem está em foco e o que
## acontece com a herança do foco órfão.
func girar_o_foco() -> void:
	if ativas.size() <= 1:
		return
	em_foco = (em_foco + 1) % ativas.size()
	# Escolha à mão manda: a herança do foco órfão perde a validade aqui.
	_foco_orfao = false
	mudou.emit()


## Fixa uma missão específica. O Tab continua girando, mas com muitas frentes
## abertas girar é ruim — a tela de missões (J) escolhe direto.
func fixar(id: String) -> void:
	var i := indice(id)
	if i < 0:
		return
	em_foco = i
	_foco_orfao = false
	mudou.emit()


## AS MISSÕES DE ENREDO, pelo id do passo.
##
## A lista mora aqui, e não espalhada pelos arquivos de fala, porque a pergunta
## "isto é enredo?" tem que ser respondida no MESMO lugar para todo mundo — o
## HUD, a tela de missões e quem vier depois. Passo que não está aqui é do dia
## a dia, e é esse o padrão: a maior parte do que o jogador faz neste jogo é
## trabalho, não história.
##
## O CRITÉRIO é um só: a missão move a história da fazenda do outro lado do
## rio, ou é uma decisão que muda o personagem?
##
##   Chegar, abrir a casa, conhecer o arraial, ler o convite, ver a ponte
##   caída, levantá-la e ver a chapada — é a linha inteira que leva o jogador
##   ao capítulo 6. A lenha e as tábuas entram porque são a ponte: cortar
##   fora o meio de uma missão de enredo e chamar de recado seria mentir
##   sobre o que o jogador está fazendo ali.
##
##   O mirante é a segunda obra pública e o arremate do arco do Pedro. A fé é
##   uma escolha que muda a conta de XP do personagem para sempre.
##
## Fora daqui: arar, plantar, colher, cozinhar, pescar, quebrar pedra, pomar,
## curral, capataz, canteiro, talentos. Tudo isso é ofício.
const PRINCIPAIS := [
	"subir", "casa", "vilarejo", "convite", "ponte_caida", "buscar_machado",
	"lenha", "tabuas", "ponte", "chapada",
	"mirante_ver", "mirante_material", "mirante_obra",
	"fe_zefa", "fe_marcos", "fe_escolher",
]


## OS PASSOS DA JORNADA DA FAZENDA — os capítulos 6 e 7.
##
## São de enredo como os de cima, e ficam em lista PRÓPRIA por uma razão que
## não é de arrumação: `PRINCIPAIS` é também a CONDIÇÃO da jornada. O dia da
## fazenda chega quando a fila do arraial fecha (ver `Jornada.pronto`), e pôr
## os passos da jornada na mesma lista faria a jornada esperar por si mesma.
const DA_JORNADA := [
	"fazenda_ida", "fazenda_chegada",
]


## A missão é de enredo? Vale pelo id, para quem anuncia não precisar lembrar.
##
## As duas listas, e não só a primeira: a jornada da fazenda é o enredo que
## sobra depois que a fila do arraial fecha, e o HUD tem de pôr os passos dela
## na frente da horta como põe os do mirante.
static func de_enredo(id: String) -> bool:
	return PRINCIPAIS.has(id) or DA_JORNADA.has(id)


## As missões abertas, as de enredo primeiro. É a ordem em que a tela de
## missões mostra e a ordem que o Tab percorre — quem tem enredo aberto quer
## cair nele antes de cair na horta.
func por_importancia() -> Array:
	var enredo: Array = []
	var resto: Array = []
	for missao in ativas:
		if bool(missao.get("principal", false)):
			enredo.append(missao)
		else:
			resto.append(missao)
	return enredo + resto


## `lista` é opcional e vem como [{"id", "texto"}, ...] — o "feito" nasce falso.
##
## `fe` amarra a missão a uma fé. Missão de fé só corre com aquela fé ATIVA: se
## o jogador migrar no meio dela, ela não some da lista nem se dá por perdida —
## fica CONGELADA, marcada como tal, esperando ele voltar. Ver `congelada`.
##
## `principal` diz se a missão é de ENREDO. Ver `PRINCIPAIS`, logo abaixo.
func adicionar(id: String, titulo: String, passiva: bool = false, lista: Array = [],
		fe: String = "", principal: bool = false, linha: String = "") -> void:
	if indice(id) >= 0:
		return
	var missao := {"id": id, "titulo": titulo, "passiva": passiva, "principal": principal}
	if fe != "":
		missao["fe"] = fe
	if linha != "":
		missao["linha"] = linha
	if not lista.is_empty():
		var itens: Array = []
		for item in lista:
			var entrada := {"id": str(item["id"]), "texto": str(item["texto"]), "feito": false}
			# Item que pede QUANTIDADE guarda de que item é e quantos faltam, e o
			# resto do jogo lê isso por `texto_do_item`.
			if item.has("item"):
				entrada["item"] = str(item["item"])
				entrada["alvo"] = int(item.get("alvo", 1))
			if item.has("equivale"):
				entrada["equivale"] = item["equivale"]
			if item.has("meta"):
				entrada["meta"] = int(item["meta"])
				entrada["conta"] = 0
			itens.append(entrada)
		missao["lista"] = itens

	# As de ENREDO entram NA FRENTE da lista, e não no fim dela.
	#
	# A ordenação mora aqui, num lugar só, porque `ativas` é lida como está por
	# todo mundo: o HUD mostra `ativas[em_foco]`, o Tab gira por índice, a tela
	# de missões percorre na ordem e a bússola aponta a que estiver em foco.
	# Ordenar aqui ordena em todos de uma vez; ordenar na tela deixaria o
	# cursor andando numa ordem e a lista mostrando outra.
	var onde := ativas.size()
	if principal:
		onde = 0
		while onde < ativas.size() and bool(ativas[onde].get("principal", false)):
			onde += 1
	ativas.insert(onde, missao)

	# A MISSÃO QUE FECHOU DEIXOU O FOCO VAGO: esta herda.
	#
	# É o caso do tutorial, e é por que consertar só o `concluir` não bastava.
	# Cada passo do tutorial é uma missão própria: fecha "ver a praça", abre
	# "pegar o convite". Com o foco no passo que fechou e uma frente lateral
	# aberta, o foco caía na lateral — e um quadro depois o passo seguinte
	# entrava na frente dela e empurrava o foco mais um. O jogador terminava um
	# passo do tutorial e a HUD passava a falar do arraial.
	#
	# Herdar é o que ele espera: fechou uma, abriu a seguinte, o olho segue.
	#
	# SÓ A MESMA LINHA HERDA. Missão de outra frente que abra no intervalo não
	# rouba o foco: ela entra na lista, e o foco continua vago à espera da
	# linha que o jogador estava seguindo. Missão sem linha declarada herda de
	# quem também não tinha — é o caso antigo, e continua valendo.
	if _foco_orfao and linha == _linha_orfa:
		em_foco = onde
		_foco_orfao = false
	# Inserir no meio empurra quem estava em foco um índice para a frente. Sem
	# isto, abrir uma missão de enredo trocava sozinha a missão que o HUD
	# mostrava — pela do vizinho de índice, que não era a de ninguém.
	elif onde <= em_foco and ativas.size() > 1:
		em_foco += 1
	abriu.emit(id)
	mudou.emit()


## Marca um item da checklist. Devolve true quando aquele foi o ÚLTIMO que
## faltava — é o sinal de que a missão pode fechar.
func marcar(id: String, item: String) -> bool:
	return conferir(id, item, true)


## Marca OU DESMARCA, conforme o mundo está agora.
##
## `marcar` é de mão única de propósito: arar, plantar e regar são coisas que
## aconteceram, e o que aconteceu não desacontece. Mas item na mochila não é
## acontecimento, é SALDO — e saldo desce.
##
## O jogador juntava as vinte tábuas do mirante, a checklist riscava tudo, e
## ele ia gastar as tábuas numa outra obra no caminho. Chegava no morro com
## seis tábuas, a HUD ainda dizia [x] em todas as linhas, e não havia nada na
## tela que explicasse por que a obra não saía. O risco mentia.
##
## Quem lida com saldo chama isto, todo quadro, com a verdade do momento.
func conferir(id: String, item: String, satisfeito: bool) -> bool:
	var i := indice(id)
	if i < 0 or not ativas[i].has("lista"):
		return false
	var mudou_algo := false
	for entrada in ativas[i]["lista"]:
		if entrada["id"] == item and bool(entrada["feito"]) != satisfeito:
			entrada["feito"] = satisfeito
			mudou_algo = true
	if mudou_algo:
		mudou.emit()
	return completa(id)


## Põe (ou troca) a checklist de uma missão JÁ ABERTA.
##
## Existe por causa do passo de LEVANTAR a obra, que vem depois do de juntar o
## material e não nascia com lista nenhuma — ele só dizia "levante o mirante".
## Quando o material sumia da mochila entre um passo e outro, esse passo era
## uma frase sem nada por baixo. Agora ele carrega a conta, e a conta se
## conserta sozinha por `conferir`.
##
## Só mexe quando a lista realmente mudou de formato: chamada todo quadro com a
## mesma conta, não fica emitindo `mudou` à toa nem zera o que já foi riscado.
func pendurar_lista(id: String, lista: Array) -> void:
	var i := indice(id)
	if i < 0:
		return
	var atual: Array = ativas[i].get("lista", [])
	var mesma := atual.size() == lista.size()
	if mesma:
		for n in lista.size():
			if str(atual[n].get("id", "")) != str(lista[n]["id"]) \
					or int(atual[n].get("alvo", 0)) != int(lista[n].get("alvo", 1)) \
					or atual[n].get("equivale", []) != lista[n].get("equivale", []):
				mesma = false
				break
	if mesma:
		return
	var itens: Array = []
	for item in lista:
		var entrada := {"id": str(item["id"]), "texto": str(item["texto"]), "feito": false}
		if item.has("item"):
			entrada["item"] = str(item["item"])
			entrada["alvo"] = int(item.get("alvo", 1))
		if item.has("equivale"):
			entrada["equivale"] = item["equivale"]
		if item.has("meta"):
			entrada["meta"] = int(item["meta"])
			entrada["conta"] = 0
		itens.append(entrada)
	ativas[i]["lista"] = itens
	mudou.emit()



## CONTA UM ACONTECIMENTO num item da checklist: um bote esquivado, um golpe
## que acertou. Devolve true quando aquela conta chegou na `meta`.
##
## Não é saldo, é acontecimento — conta e não desconta, como `marcar`. E a
## conta mora NA PRÓPRIA ENTRADA (`conta`), que vai no save junto com a missão:
## fechar o jogo no segundo bote de três e abrir de novo tem que voltar no
## segundo, e um contador guardado em quem conduz a missão morreria com ele.
##
## Missão congelada não conta: quem migrou de fé não está treinando a lição
## da fé que deixou (ver `congelada`).
func contar(id: String, item: String, quanto: int = 1) -> bool:
	var i := indice(id)
	if i < 0 or not ativas[i].has("lista") or congelada(id):
		return false
	for entrada in ativas[i]["lista"]:
		if entrada["id"] != item or not entrada.has("meta") or bool(entrada["feito"]):
			continue
		entrada["conta"] = mini(int(entrada["meta"]), int(entrada.get("conta", 0)) + quanto)
		entrada["feito"] = int(entrada["conta"]) >= int(entrada["meta"])
		mudou.emit()
	return completa(id)


## Troca o TEXTO de um item da checklist, sem mexer no resto dela.
##
## Serve a contagem que não é de mochila — o mato do cemitério é contado no
## CHÃO, e `texto_do_item` só sabe contar item de inventário. Só emite `mudou`
## quando o texto de fato mudou: é chamado todo quadro pela capina.
func retextar(id: String, item: String, texto: String) -> void:
	var i := indice(id)
	if i < 0 or not ativas[i].has("lista"):
		return
	for entrada in ativas[i]["lista"]:
		if entrada["id"] != item or str(entrada["texto"]) == texto:
			continue
		entrada["texto"] = texto
		mudou.emit()


## Quanto um item da checklist CONTA: o que está na mochila mais o que já
## virou outra coisa a caminho do mesmo fim.
##
## "Na missão de consertar a ponte, a quantidade de lenha que precisa pegar
## está em desacordo com a quantidade necessária pra craftar." A soma em si
## fechava: doze tábuas a duas lenhas e quatro cordas a três dão trinta e seis,
## que é o que o passo pede, e a simulação serrou tudo com zero de sobra. O
## desacordo estava no CONTADOR: ele media só a lenha crua na mochila, e a
## bancada fica no roçado desde o primeiro dia. Quem serrava uma tábua antes
## de o passo fechar via "Lenha 34/36" e ia derrubar mais duas — de uma ponte
## que já tinha as duas na tábua. Quanto mais cedo experimentasse a bancada,
## mais lenha o passo cobrava a mais.
##
## `equivale` é a lista do que vale como o item: cada crédito diz de que item
## é, quanta lenha custa uma fornada dele (`por_vez`), quantas peças a fornada
## dá (`rende`) e até quantas peças contam (`ate`) — a décima terceira tábua
## não é da ponte. Quem preenche esses números é quem sabe a receita (ver
## `Tutorial._lista_da_lenha`), e não o arquivo de falas.
##
## É A MESMA CONTA QUE FECHA O PASSO (ver `Tutorial._esperar_lista`): o que o
## contador mostra e o que a missão exige nunca podem divergir, senão é
## mentira na cara do jogador.
func contagem(entrada: Dictionary) -> int:
	var alvo := int(entrada.get("alvo", 0))
	var total := Inventario.quantidade(str(entrada.get("item", "")))
	for credito in entrada.get("equivale", []):
		var pecas := mini(Inventario.quantidade(str(credito["item"])), int(credito.get("ate", 0)))
		var rende := maxi(1, int(credito.get("rende", 1)))
		total += ceili(float(pecas) / float(rende)) * int(credito.get("por_vez", 0))
	return mini(alvo, total)


## Como um item da checklist se LÊ, já com o contador quando ele conta coisa.
##
## "Lenha 12/36" em vez de "Lenha". Missão que pede quantidade sem mostrar
## quanto já se juntou obriga o jogador a abrir a mochila e contar na mão a cada
## machadada — e a de trinta e seis paus é a mais longa do tutorial, justamente
## a que mais precisa de um número na tela.
##
## A conta é a mesma que a missão usa para se dar por cumprida: o que está na
## mochila AGORA, e não o que foi juntado desde que ela abriu. São as duas a
## mesma coisa para quem está jogando, e qualquer diferença entre o contador e a
## condição de fechar seria mentira na cara do jogador.
func texto_do_item(entrada: Dictionary) -> String:
	var texto := str(entrada.get("texto", ""))
	# Acontecimento contado (ver `contar`): "Botes esquivados 1/3".
	if entrada.has("meta") and int(entrada["meta"]) > 1:
		return "%s %d/%d" % [texto, int(entrada.get("conta", 0)), int(entrada["meta"])]
	var alvo := int(entrada.get("alvo", 0))
	if alvo <= 1 or not entrada.has("item"):
		return texto
	return "%s %d/%d" % [texto, contagem(entrada), alvo]




## A missão está congelada? É o que acontece com missão de fé quando o jogador
## migra para outra fé no meio dela.
##
## Congelar NÃO é cancelar, e a diferença importa: o jogador que largou a
## romaria pela metade para se iniciar no terreiro não perdeu a romaria. Ela
## fica na lista, marcada, e o dia em que ele voltar à fé católica ela volta a
## correr de onde parou. Perder o andado seria punir a curiosidade, que é
## justamente o que a migração existe para permitir.
func congelada(id: String) -> bool:
	var i := indice(id)
	if i < 0:
		return false
	var fe := str(ativas[i].get("fe", ""))
	return fe != "" and Fe.ativa != fe


## O título como o HUD e a tela de missões devem mostrá-lo — com o aviso de
## congelamento junto, senão o jogador fica olhando uma missão que não anda sem
## entender por quê.
func titulo_de(entrada: Dictionary) -> String:
	var texto := str(entrada.get("titulo", ""))
	var fe := str(entrada.get("fe", ""))
	if fe == "" or Fe.ativa == fe:
		return texto
	return "%s (parada: é da fé %s)" % [texto, Fe.nome(fe).to_lower()]


## Todos os itens da checklist estão feitos?
func completa(id: String) -> bool:
	var i := indice(id)
	if i < 0:
		return false
	if not ativas[i].has("lista"):
		return true
	for entrada in ativas[i]["lista"]:
		if not entrada["feito"]:
			return false
	return true


## Quantos itens já foram feitos, e de quantos. Para o HUD dizer "2/3".
func andamento(id: String) -> Vector2i:
	var i := indice(id)
	if i < 0 or not ativas[i].has("lista"):
		return Vector2i.ZERO
	var feitos := 0
	for entrada in ativas[i]["lista"]:
		if entrada["feito"]:
			feitos += 1
	return Vector2i(feitos, ativas[i]["lista"].size())


## Aponta (ou reaponta) a bússola de uma missão já aberta.
##
## `alvo` é **nome de lugar** (`"vau"`, `"aldeao:zefa"`) ou a posição pronta.
## O nome é o caminho preferido: missão que guarda coordenada guarda o mundo em
## que nasceu, e é o que impediria esta campanha de rodar em 3D. Ver
## `Lugares` e docs/MIGRACAO_2D_3D.md (branch prototype/myths-valley-3d), Fase 1.
##
## A posição continua aceita, e não é dívida: há alvos que não são lugar com
## nome — a célula que o jogador acabou de arar, o ponto que o arraial calculou
## para a obra da vez. Esses não ganham nada em virar texto.
func apontar(id: String, alvo) -> void:
	apontar_varios(id, [alvo])


## Aponta para VÁRIOS lugares ao mesmo tempo.
##
## Existe por causa da missão dos três marcos de fé, que não tem ordem: o
## cruzeiro é no meio da vila, o terreiro é na mata do poente e a gameleira é
## na ponta da praia, e o jogador visita na ordem que quiser. A bússola
## apontava só para o cruzeiro, e quem estivesse do lado da gameleira era
## mandado atravessar o mapa para trás sem precisar.
##
## `alvo` continua existindo e é sempre o PRIMEIRO da lista: metade do jogo lê
## `missao["alvo"]` e não precisa saber que agora pode haver mais de um.
func apontar_varios(id: String, alvos: Array) -> void:
	var i := indice(id)
	if i < 0 or alvos.is_empty():
		return
	var pontos := _resolver(alvos)
	if pontos.is_empty():
		return
	ativas[i]["alvo"] = pontos[0]
	ativas[i]["alvos"] = pontos
	mudou.emit()


## Troca os nomes de lugar por posição, deixando passar o que já é posição.
##
## Resolve AGORA, e não na hora de desenhar a bússola. Metade dos lugares é
## móvel — o bicho mais perto, a erva mais perto, o aldeão que anda —, e
## reresolver a cada quadro faria o losango perseguir um alvo que muda, que é
## outra missão e não esta. O nome é o que atravessa mundos; o ponto é o que
## aquela missão passou a ter como destino.
##
## Nome que não resolve **cai fora da lista** em vez de virar um infinito no
## meio dela: a missão dos três marcos aponta para vários, e um infinito entre
## eles mandaria o jogador para fora do mapa.
##
## O ponto NÃO É TIPADO aqui, e é de propósito: `Lugares.ponto` devolve
## `Vector2` neste jogo e `Vector3` no protótipo 3D, que usa este mesmo
## arquivo. Declarar o tipo faria a costura só servir de um lado — que é
## exatamente o que ela existe para evitar. `NENHUM` acompanha: é o infinito
## da dimensão certa em cada projeto.
func _resolver(alvos: Array) -> Array:
	var saida := []
	for alvo in alvos:
		if alvo is String:
			var p = Lugares.ponto(alvo)
			if p != Lugares.NENHUM:
				saida.append(p)
		else:
			saida.append(alvo)
	return saida


## Os lugares para onde esta missão aponta. Sempre uma lista, mesmo quando é um
## só — quem desenha não deveria ter que tratar dois casos.
func alvos_de(entrada: Dictionary) -> Array:
	if entrada.has("alvos"):
		return entrada["alvos"]
	if entrada.has("alvo"):
		return [entrada["alvo"]]
	return []


func desapontar(id: String) -> void:
	var i := indice(id)
	if i >= 0:
		ativas[i].erase("alvo")
		ativas[i].erase("alvos")
		mudou.emit()


## FECHAR UMA MISSÃO NÃO PODE TROCAR A QUE O JOGADOR FIXOU.
##
## Aqui estava a outra metade de um defeito que já tinha sido consertado pela
## metade. `adicionar` empurra o foco quando insere na frente dele — o
## comentário lá em cima conta por quê. `concluir` REMOVE e nunca ajustou nada:
## fechava a missão do índice 1, tudo que vinha depois escorregava um lugar
## para trás, e o `em_foco` continuava apontando para o mesmo NÚMERO, que agora
## era outra missão.
##
## Na prática: o jogador fixa a missão do arraial, termina um passo do tutorial
## — que é a missão de índice 0 —, e a HUD passa a mostrar outra coisa sem que
## ele tenha pedido. Era a queixa, e ela acontece toda vez que se fecha um
## passo de uma frente com outra frente aberta.
##
## Três casos, e cada um tem uma resposta diferente:
##
##   fechou ANTES da fixada   a lista escorregou; o índice acompanha.
##   fechou DEPOIS da fixada  nada muda de lugar antes dela.
##   fechou A PRÓPRIA fixada  o jogador ficou sem missão em foco. Ver
##                            `_foco_orfao`.
func concluir(id: String) -> void:
	var i := indice(id)
	if i < 0:
		return
	var linha := str(ativas[i].get("linha", ""))
	if not cumpridas.has(id):
		cumpridas.append(id)
	ativas.remove_at(i)
	if i < em_foco:
		em_foco -= 1
	elif i == em_foco:
		# O FOCO FICA VAGO, e vago é vago: nem cai no vizinho de índice, nem é
		# roubado pela primeira missão que aparecer. Ver `_foco_orfao`.
		_foco_orfao = true
		_linha_orfa = linha
		_orfao_desde = Time.get_ticks_msec()
	em_foco = clampi(em_foco, 0, maxi(0, ativas.size() - 1))
	concluida.emit(id)
	mudou.emit()


func cumprida(id: String) -> bool:
	return cumpridas.has(id)


func indice(id: String) -> int:
	for i in ativas.size():
		if ativas[i]["id"] == id:
			return i
	return -1


func tem(id: String) -> bool:
	return indice(id) >= 0


func atual() -> Dictionary:
	# VAGO É VAGO. Enquanto a linha que fechou não continua, a HUD não mostra
	# o vizinho de índice — mostrava, e era isso que o jogador lia como "trocou
	# a missão fixada". Passado o tempo de uma fala de arremate sem a linha
	# voltar, ela acabou: o foco cai na mais importante das que restam.
	if _foco_orfao:
		if Time.get_ticks_msec() - _orfao_desde < ESPERA_DA_LINHA:
			return {}
		_foco_orfao = false
		var restantes := por_importancia()
		if not restantes.is_empty():
			em_foco = indice(str(restantes[0]["id"]))
		mudou.emit()
	return ativas[em_foco] if em_foco < ativas.size() else {}


func limpar() -> void:
	ativas.clear()
	cumpridas.clear()
	em_foco = 0
	mudou.emit()
