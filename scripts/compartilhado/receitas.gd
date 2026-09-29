extends Node
## O QUE O JOGADOR SABE FAZER — e como ele veio a saber.
##
## "Considere que o NPC precisa encontrar, desbloquear, cumprir missões ou
## qualquer outra forma similar para desbloquear receitas e poder ver elas na
## lista de receitas no fogão. Isso vai impactar a missão de aprender a
## cozinhar. Faça isso também para receitas da Oficina de materiais e
## ferramentas e da Oficina de Construção."
##
## Até aqui as três bancadas mostravam o catálogo inteiro desde o primeiro dia.
## O jogador abria o fogão no segundo dia e lia "Mungunzá — milho branco cozido
## devagar com a doçura da cana", que é prato de quem já plantou milho e cana e
## está fazendo festa. A lista servia de vitrine do que ele NÃO podia fazer, em
## vez de lista do que ele sabe — e as três bancadas do jogo tinham o mesmo
## defeito, do fogão ao canteiro de obras.
##
##
## AS QUATRO PORTAS, e a regra que o autor deu para elas
##
## "Deve implementar todas as opções acima. Mas nem todas receitas deve ser
## possível obter em todos os modos. Algumas obrigatoriamente consegue cumprindo
## missão... Outras achando no mundo... Outras o morador ensina... Outras
## comprando... Outras podem ser um mix de 2 dessas opções anteriores, valendo a
## que o jogador atingir primeiro."
##
##   missao    o passo ensina. É o gancho que o jogo já tem em mais lugares — o
##             fogão do Pedro, o facão, a prancheta do canteiro.
##   morador   conviver com quem sabe. Sobe de grau na caderneta e ele conta.
##   achado    coisa que se acha: um cordel lido, um bicho carneado.
##   compra    réis no balcão, que é o destino que o dinheiro do meio da
##             campanha quase não tinha.
##
## VALE A PRIMEIRA QUE ACONTECER, e isso sai de graça: aprender é idempotente.
## Uma receita com duas portas é uma receita que o jogador alcança pelo caminho
## que ele estiver trilhando, e não pelo que o jogo escolheu por ele.
##
##
## A PORTA DA MISSÃO ABRE QUANDO O PASSO ABRE, e não quando ele fecha
##
## É a decisão que faz o sistema inteiro não travar, e ela não é arrumação: há
## seis passos neste jogo que MANDAM FABRICAR alguma coisa. "Torre duas
## farinhas". "Bata um facão na oficina". "Toque a obra do canteiro". Se a
## receita só entrasse na cabeça do jogador ao fechar o passo, o passo pediria
## uma coisa que a bancada não lista — e o jogador ficaria na frente do fogão
## lendo uma lista vazia com a missão aberta na tela.
##
## Lição se dá antes do trabalho. É por isso que quem avisa é `Missoes.abriu`.
##
##
## ONDE A PORTA DE CADA RECEITA MORA
##
## COM A RECEITA, e não numa tabela central aqui. É a mesma decisão que
## `Oficina` já anunciava — "receita é dado, não código" —, e a razão é que
## tabela central envelhece: quem acrescentar um prato mexe no arquivo do prato
## e não vem aqui. O portão cobra que toda receita declare a sua, e é isso que
## impede o esquecimento de virar receita invisível para sempre.
##
## A chave é `abre`, um dicionário cujas CHAVES são as portas:
##
##     "abre": {"comeco": true}                   nasce sabida
##     "abre": {"missao": "coveiro_foice"}        o passo ensina, ao abrir
##     "abre": {"morador": "zefa", "grau": 2}     a convivência ensina
##     "abre": {"achado": "boi_do_reconcavo"}     o mundo ensina
##     "abre": {"compra": 240}                    o balcão vende
##     "abre": {"missao": "x", "compra": 300}     as duas, a primeira que vier
##
##
## O QUE NASCE SABIDO, E POR QUE SÃO TÃO POUCOS
##
## Tábua, corda, o quarto, o salão, a varanda, a estante e a bancada de ofício.
## Sete, e não é timidez: TÁBUA E CORDA SÃO PEDIDAS POR TRÊS SÉRIES QUE CORREM
## EM PARALELO — o cabo da foice do Damião, a rede do Tonho e o mirante do
## arraial —, e nenhuma delas tem ordem garantida em relação às outras. Trancar
## um material que três frentes independentes cobram é montar um beco sem saída
## que só aparece na partida de quem fez as coisas na ordem errada.
##
## A régua, então, é esta: material que mais de uma frente cobra nasce sabido.
## Prato, plano de obra e arma se aprendem.

## Aprendeu uma receita agora. `de_onde` é a porta por onde ela entrou.
signal aprendeu(id: String, de_onde: String)

## As portas que existem, para o portão poder cobrar que não haja outra escrita
## por engano. `comeco` está aqui porque é uma porta como as outras — a que já
## estava aberta.
const PORTAS := ["comeco", "missao", "morador", "grau", "achado", "compra"]

## O que já se sabe fazer. Vai no save.
var aprendidas: Array = []


func _ready() -> void:
	Missoes.abriu.connect(_ao_abrir_passo)
	Afinidade.subiu_de_grau.connect(_ao_subir_de_grau)
	Colecao.achou.connect(_ao_achar)
	Inventario.item_recebido.connect(_ao_receber_item)
	conferir()


## As receitas de TODAS as bancadas, com os dados de cada uma.
##
## As obras moram num JSON e as outras duas em autoloads; esta função é o único
## lugar do jogo que precisa saber disso.
func tudo() -> Dictionary:
	var lista: Dictionary = {}
	for id in Cozinha.RECEITAS:
		lista[str(id)] = Cozinha.RECEITAS[id]
	for id in Oficina.RECEITAS:
		lista[str(id)] = Oficina.RECEITAS[id]
	for id in Obras.catalogo():
		lista[str(id)] = Obras.dados(str(id))
	return lista


func portas_de(id: String) -> Dictionary:
	return tudo().get(str(id), {}).get("abre", {})


func sabe(id: String) -> bool:
	return aprendidas.has(str(id))


## Quantas receitas de uma lista ainda não se sabe. É o que as bancadas dizem
## no pé, para lista curta não parecer bancada quebrada.
func quantas_faltam(ids: Array) -> int:
	var conta := 0
	for id in ids:
		if not sabe(str(id)):
			conta += 1
	return conta


## APRENDER É IDEMPOTENTE, e é o que faz a regra das duas portas funcionar sem
## ninguém decidir qual vale: vale a que chegar primeiro, e a segunda não faz
## nada. Devolve true só quando a receita era nova.
func aprender(id: String, de_onde: String = "") -> bool:
	if sabe(id):
		return false
	aprendidas.append(str(id))
	aprendeu.emit(str(id), de_onde)
	return true


## VARRE O ESTADO ATUAL e abre tudo que ele já permitia.
##
## Roda ao subir e depois de carregar uma partida, e é o que faz este sistema
## poder entrar num jogo que já está sendo jogado. Sem isto, quem carregasse um
## save de antes desta rodada perderia de uma vez o fogão inteiro: as receitas
## ficariam à espera de sinais que já aconteceram — a missão já cumprida, o
## cordel já achado, a amizade já feita — e sinal não se repete.
##
## Vale para conteúdo novo também, e é o caso que vai acontecer mais vezes: uma
## receita acrescentada amanhã com `{"comeco": true}` tem que nascer sabida em
## toda partida que existe, e não só nas que começarem depois.
##
## A porta da MISSÃO é conferida por `cumprida`, e não pela abertura, porque
## abertura é um instante e não deixa rastro. Perde-se, com isso, o caso do
## passo que está aberto agora e ainda não fechou — e é aceitável: esse passo
## já ensinou quando abriu, nesta mesma sessão ou na que gravou o save.
func conferir() -> void:
	var todas := tudo()
	for id in todas:
		var portas: Dictionary = todas[id].get("abre", {})
		if portas.is_empty() or sabe(str(id)):
			continue
		if bool(portas.get("comeco", false)):
			aprender(str(id), "comeco")
		elif portas.has("missao") and Missoes.cumprida(str(portas["missao"])):
			aprender(str(id), "missao")
		elif portas.has("morador") \
				and Afinidade.grau(str(portas["morador"])) >= int(portas.get("grau", 1)):
			aprender(str(id), "morador")
		elif portas.has("achado") and _ja_achou(str(portas["achado"])):
			aprender(str(id), "achado")


## Esse achado já passou pela mão do jogador? Vale a peça de coleção em qualquer
## coleção e o item na mochila — as duas coisas que `achado` pode nomear.
func _ja_achou(chave: String) -> bool:
	for colecao in Colecao.COLECOES:
		if Colecao.tem(str(colecao), chave):
			return true
	return Inventario.quantidade(chave) > 0


func _ao_abrir_passo(missao: String) -> void:
	_abrir_por("missao", missao)


func _ao_achar(_colecao: String, id: String) -> void:
	_abrir_por("achado", id)


func _ao_receber_item(id: String, _quantidade: int) -> void:
	_abrir_por("achado", id)


## Subiu de grau com alguém: ele ensina o que sabe até aquele grau.
##
## Pelo GRAU e não pelos pontos: grau é o que a caderneta mostra e o que o
## jogador sente mudar. E `>=` e não `==`, senão uma receita de grau 2 se perde
## para sempre em quem pular direto para o 3 com um presente grande.
func _ao_subir_de_grau(morador: String, grau: int) -> void:
	var todas := tudo()
	for id in todas:
		var portas: Dictionary = todas[id].get("abre", {})
		if str(portas.get("morador", "")) != morador:
			continue
		if grau >= int(portas.get("grau", 1)):
			aprender(str(id), "morador")


func _abrir_por(porta: String, chave: String) -> void:
	if chave == "":
		return
	var todas := tudo()
	for id in todas:
		var portas: Dictionary = todas[id].get("abre", {})
		if str(portas.get(porta, "")) == chave:
			aprender(str(id), porta)


# --- o balcão -----------------------------------------------------------------

## O que o balcão tem à venda hoje: o que abre por compra e ainda não se sabe.
##
## Em ordem alfabética de id, e não na ordem do catálogo, porque as três
## bancadas entram na mesma lista — sem ordem fixa, o prato apareceria entre
## duas obras conforme o dicionário resolvesse iterar.
func a_venda() -> Array:
	var lista: Array = []
	var todas := tudo()
	for id in todas:
		var portas: Dictionary = todas[id].get("abre", {})
		if portas.has("compra") and not sabe(str(id)):
			lista.append(str(id))
	lista.sort()
	return lista


func preco(id: String) -> int:
	return int(portas_de(id).get("compra", 0))


## O nome que o balcão escreve. Sai da própria receita, que é onde o nome dela
## já está escrito para a bancada.
func nome(id: String) -> String:
	return str(tudo().get(str(id), {}).get("nome", id))


func resumo(id: String) -> String:
	return str(tudo().get(str(id), {}).get("resumo", ""))


## De que bancada é esta receita. O balcão diz, senão "Serra de fita" e "Pirão
## de peixe" viram a mesma coisa numa lista só.
func bancada_de(id: String) -> String:
	if Cozinha.RECEITAS.has(str(id)):
		return "fogão"
	if Oficina.RECEITAS.has(str(id)):
		return "oficina"
	return "obra"


## Compra a receita no balcão. Devolve false se não dá — sem porta de compra,
## sem réis, ou já sabida.
func comprar(id: String) -> bool:
	var quanto := preco(id)
	if quanto <= 0 or sabe(id) or Jogo.dinheiro < quanto:
		return false
	Jogo.dinheiro -= quanto
	return aprender(id, "compra")


func limpar() -> void:
	aprendidas.clear()
	conferir()
