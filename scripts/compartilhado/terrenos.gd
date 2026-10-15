extends Node
## O TRABALHO NAS TERRAS: quem mora num lote que passou a ser do jogador pode ser posto para
## trabalhar nele, e o que faz depende de QUEM É (#9: a regra da aba Trabalho; a tela vem depois).
##
## Veio do `Terrenos` do 2D, REESCRITO e não copiado. No 2D um autoload só cuidava de tudo: a posse
## do chão, o preço, a divisa, a dívida do Tonho e o trabalho. Aqui cada coisa tem um dono, e este é
## o último da fila:
##
##   Terras     de quem é cada lote: posse, preço, divisa, compra       (scripts/autoload/terras.gd)
##   Terrenos   o que o morador de um lote SEU faz nele: ofício, idade  (este arquivo)
##   Povoado    quanto ele rende: perícia, amizade, obras do arraial    (povoado.gd)
##   FiadoTonho a dívida do Tonho, que no vale tem livro e armazém      (fiado_tonho.gd)
##
## Posse mora num lugar só. Este arquivo pergunta ao `Terras` se o lote é do jogador e nunca guarda
## essa resposta: dois donos da mesma informação divergem, e é o `Terras` que o mapa, a compra e o
## save já leem.
##
##
## COMPRAR NÃO DESPEJA NINGUÉM
##
## O morador continua na casa dele e passa a trabalhar para a casa do jogador. O que ele PODE fazer
## depende de quem ele é: o Seu Benedito tem setenta e poucos anos e a Dona Zefa não é muito mais
## nova, e mandar os dois capinar roçado o dia inteiro não é progressão de jogo, é desaforo. Eles
## fazem o que se faz sentado e com as mãos (farinha, cestaria, bicho pequeno). Serviço de enxada e
## machado é do Cosme.
##
## Idade é coisa de personagem, não de fórmula: a lista dos idosos é curta e explícita
## (`idosos`, em data/terras_3d.json), e o idoso rende `ritmo_do_idoso` do que rende quem tem
## braço. O ofício "braçal" (roçado, lenha) nem aparece na lista dele.
##
## O TRABALHO É DE CADA UM, NÃO DO TERRENO: a Dona Zefa pode estar trançando cesto enquanto o Cosme
## capina o mesmo chão. Por isso `trabalho` é morador -> ofício.
##
##
## O QUE ESTÁ NOS DADOS
##
## data/terras_3d.json: quem mora em cada lote (`moradores`), quem é idoso, o ritmo dele, e os
## ofícios, cada um com nome e resumo nos idiomas do jogo (texto de jogador não mora em constante),
## o que rende por dia e se é braçal. Os ids dos ofícios (roca, lenha, farinha, artesanato,
## criacao, nada) são os do 2D, porque vão para o save.

signal mudou

const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
## O ofício de quem não foi posto para trabalhar. Todo morador de lote seu começa nele.
const NADA := "nada"

## morador -> id do ofício. Quem não está aqui está em "nada". Vai no save.
var trabalho: Dictionary = {}


# --- os ofícios ------------------------------------------------------------------------

func oficios() -> Dictionary:
	return Jogo.dados(Terras.ARQUIVO).get("oficios", {})


func oficio(id: String) -> Dictionary:
	return oficios().get(id, {})


func existe(id: String) -> bool:
	return oficios().has(id)


func nome_do_oficio(id: String) -> String:
	return str(IdiomaMenu.campo(oficio(id), "nome", id))


func resumo_do_oficio(id: String) -> String:
	return str(IdiomaMenu.campo(oficio(id), "resumo", ""))


## Serviço de sol e lombo, que quem é idoso não faz.
func e_bracal(id: String) -> bool:
	return bool(oficio(id).get("bracal", false))


## O que UM DIA do ofício rende, item a item, ANTES de perícia, amizade, obras e idade. É a tabela
## do ofício; quem faz a conta de quanto ele de fato entrega é o `Povoado`.
##
## O rendimento é MODESTO de propósito. Um morador não substitui o jogador: ele mantém um fio de
## renda entrando enquanto o jogador está longe, na pedreira ou na mata do dendê. Automação que
## rende mais que o braço próprio acaba com o jogo.
func rende(id: String) -> Dictionary:
	return oficio(id).get("rende", {})


# --- quem é quem -----------------------------------------------------------------------

func ritmo_do_idoso() -> float:
	return float(Jogo.dados(Terras.ARQUIVO).get("ritmo_do_idoso", 1.0))


func e_idoso(morador: String) -> bool:
	return (Jogo.dados(Terras.ARQUIVO).get("idosos", []) as Array).has(morador)


## Quem mora naquele lote. Mais de um por casa: a Zefa mora com o neto.
func moradores_de(lote: String) -> Array:
	return Terras.dados(lote).get("moradores", [])


## Em que lote o morador vive, ou "" se não vive em nenhum dos que o vale vende (o Tonho e a Dona
## Filó esperam o lote deles, #9).
func terreno_de(morador: String) -> String:
	var lotes: Dictionary = Jogo.dados(Terras.ARQUIVO).get("lotes", {})
	for id in lotes:
		if ((lotes[id] as Dictionary).get("moradores", []) as Array).has(morador):
			return str(id)
	return ""


## O lote onde ele mora é do jogador?
func em_terra_minha(morador: String) -> bool:
	var lote := terreno_de(morador)
	return lote != "" and Terras.meu(lote)


# --- pôr para trabalhar ----------------------------------------------------------------

func trabalho_de(morador: String) -> String:
	return str(trabalho.get(morador, NADA))


## O que aquele morador PODE fazer, pela idade: o idoso fica sem os ofícios braçais.
func trabalhos_de(morador: String) -> Array:
	var lista: Array = []
	for id in oficios():
		if e_idoso(morador) and e_bracal(str(id)):
			continue
		lista.append(str(id))
	return lista


## Por que o morador não pode fazer aquele ofício. "" quando pode. O código é de dentro (a tela
## escolhe o texto, nos idiomas do jogo):
##
##   oficio_desconhecido   o ofício não existe nos dados
##   sem_lote              o morador não vive em lote nenhum que o vale venda
##   terra_alheia          o lote dele ainda não é do jogador
##   idoso                 serviço braçal e o morador é idoso
func impedimento(morador: String, id: String) -> String:
	if not existe(id):
		return "oficio_desconhecido"
	var lote := terreno_de(morador)
	if lote == "":
		return "sem_lote"
	if not Terras.meu(lote):
		return "terra_alheia"
	if e_idoso(morador) and e_bracal(id):
		return "idoso"
	return ""


func pode(morador: String, id: String) -> bool:
	return impedimento(morador, id) == ""


## Põe o morador para fazer aquele ofício. Devolve se pôde.
func mandar_trabalhar(morador: String, id: String) -> bool:
	if not pode(morador, id):
		return false
	trabalho[morador] = id
	mudou.emit()
	return true


## Moradores daquele lote que estão no roçado. É o que decide se a roça aparece pintada no chão.
func lavradores(terreno: String) -> Array:
	var lista: Array = []
	if not Terras.meu(terreno):
		return lista
	for morador in moradores_de(terreno):
		if trabalho_de(str(morador)) == "roca":
			lista.append(str(morador))
	return lista


## Quem está DE FATO trabalhando para o jogador: ofício de verdade, que a idade dele permite, em
## lote que é do jogador. morador -> ofício. É daqui que o `Povoado` parte para contar o dia e a
## produção.
##
## A terra que deixasse de ser do jogador tiraria o morador desta lista: o combinado morre com a
## posse. O ofício continua guardado em `trabalho`, e volta a valer se a terra voltar.
func trabalhando() -> Dictionary:
	var quem := {}
	for morador in trabalho:
		var id := str(trabalho[morador])
		if id == NADA or not pode(str(morador), id):
			continue
		quem[str(morador)] = id
	return quem
