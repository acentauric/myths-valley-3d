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
## Amanheceu e os moradores entregaram: o que rendeu hoje (item -> quantidade), já com perícia,
## amizade e obras. É o que a HUD diz de manhã.
signal renderam(colhido: Dictionary)

const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
## O ofício de quem não foi posto para trabalhar. Todo morador de lote seu começa nele.
const NADA := "nada"

## morador -> id do ofício. Quem não está aqui está em "nada". Vai no save.
var trabalho: Dictionary = {}

## O que rendeu de manhã e NÃO COUBE NA MOCHILA: item -> quantidade. Vai no save.
##
## O que um morador colhe é do jogador, e mochila cheia não pode comer a colheita em silêncio: o
## `Inventario.adicionar` recusa o que não cabe, e quem entrega sem olhar para a resposta perde o
## trabalho de um dia sem que ninguém saiba. Fica aqui, no paiol, e entra quando abre espaço (na
## próxima manhã, ou quando a tela pedir `esvaziar_o_paiol`).
var no_paiol: Dictionary = {}


func _ready() -> void:
	Relogio.dia_comecou.connect(_ao_comecar_dia)


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


## Quem trabalha num lote SEM morar nele: o Cosme no roçado do jogador (o dia de roçado do segundo
## tutorial é a primeira designação deste sistema, #9). `trabalhadores` no lote.
func trabalhadores_de(lote: String) -> Array:
	return Terras.dados(lote).get("trabalhadores", [])


## Os lotes onde o morador pode ser posto para trabalhar, na ordem de preferência: o que ele mora e
## depois os que o recebem de fora.
func lotes_de(morador: String) -> Array:
	var lista: Array = []
	var casa := terreno_de(morador)
	if casa != "":
		lista.append(casa)
	var lotes: Dictionary = Jogo.dados(Terras.ARQUIVO).get("lotes", {})
	for id in lotes:
		if str(id) != casa and trabalhadores_de(str(id)).has(morador):
			lista.append(str(id))
	return lista


## Em que lote DO JOGADOR o morador faria aquele ofício, ou "". O lote pode limitar os ofícios que
## recebe (`oficios`, lista vazia = todos): o roçado do jogador só recebe roçado.
func lote_do_trabalho(morador: String, id: String) -> String:
	for lote in lotes_de(morador):
		if not Terras.meu(str(lote)):
			continue
		var aceitos: Array = Terras.dados(str(lote)).get("oficios", [])
		if aceitos.is_empty() or aceitos.has(id):
			return str(lote)
	return ""


## O morador tem algum lote que é do jogador para trabalhar?
func em_terra_minha(morador: String) -> bool:
	for lote in lotes_de(morador):
		if Terras.meu(str(lote)):
			return true
	return false


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
##   sem_lote              o morador não vive nem trabalha em lote nenhum que o vale venda
##   terra_alheia          nenhum lote dele que receba esse ofício é do jogador ainda
##   idoso                 serviço braçal e o morador é idoso
func impedimento(morador: String, id: String) -> String:
	if not existe(id):
		return "oficio_desconhecido"
	if lotes_de(morador).is_empty():
		return "sem_lote"
	if lote_do_trabalho(morador, id) == "":
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
	for morador in moradores_de(terreno) + trabalhadores_de(terreno):
		if trabalho_de(str(morador)) == "roca" and lote_do_trabalho(str(morador), "roca") == terreno 				and not lista.has(str(morador)):
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


# --- a tela e o posto ------------------------------------------------------------------

## Quem a aba Trabalho lista: os moradores dos lotes que são do jogador (na ordem em que os lotes
## aparecem nos dados) e quem já foi posto para trabalhar, mesmo que more fora (o Cosme no roçado).
func moradores_meus() -> Array:
	var lista: Array = []
	var lotes: Dictionary = Jogo.dados(Terras.ARQUIVO).get("lotes", {})
	for lote in lotes:
		if not Terras.meu(str(lote)):
			continue
		for morador in moradores_de(str(lote)):
			if not lista.has(str(morador)):
				lista.append(str(morador))
	for morador in trabalhando():
		if not lista.has(str(morador)):
			lista.append(str(morador))
	return lista


## Hora de trabalho: da manhã ao fim da tarde. De noite e ao entardecer o morador volta à rotina dele.
func em_horario_de_trabalho() -> bool:
	return Dia.periodo() in ["manha", "tarde"]


## O posto onde o morador faz o ofício dele hoje, como [âncora, deslocamento], ou [] se ele não está
## trabalhando, ou se o lote não diz onde (aí ele segue a rotina e a mochila recebe do mesmo jeito).
## O lote é que sabe onde se faz cada coisa: `postos` em data/terras_3d.json, por ofício.
func posto_de_trabalho(morador: String) -> Array:
	var id := trabalho_de(morador)
	if id == NADA or not pode(morador, id):
		return []
	var lote := lote_do_trabalho(morador, id)
	var posto = Terras.dados(lote).get("postos", {}).get(id, [])
	return (posto as Array) if posto is Array else []


## O gesto do ofício no posto (a ação da rotina que o `npc.gd` conhece: capinar, rachar...).
func acao_do_oficio(id: String) -> String:
	return str(oficio(id).get("acao", ""))


# --- o amanhecer -----------------------------------------------------------------------

func _ao_comecar_dia(_dia: int, _estacao: int, _ano: int) -> void:
	_render_o_dia()


## Amanheceu: cada morador posto para trabalhar entrega o que fez ontem.
##
## Vai direto para a mochila, sem o jogador ter de ir buscar. Obrigar a ronda diária de coleta seria
## transformar a automação em mais trabalho, que é o contrário do que ela existe para fazer.
##
## QUEM FAZ A CONTA É O `Povoado`, e não aqui. A conta cresceu: já não é a tabela do ofício vezes o
## ritmo do idoso, entram a perícia de quem trabalha, o quanto ele gosta do jogador e as obras do
## arraial. E ela precisa ser feita DUAS vezes: aqui, para entregar, e na tela do morador, para o
## jogador ver quanto vai render antes de decidir. Uma só, no `Povoado.renderia_exata`, e o que a
## tela promete é por construção o que a mochila recebe.
##
## `entregar_o_dia` e não `producao_do_dia`: esta é a única chamada do dia que FECHA a conta e guarda
## a fração que sobrou para amanhã. A outra é a consulta que a tela faz, e consulta não pode mexer
## na sobra. E o dia de serviço só entra na perícia DEPOIS da entrega (ver `Povoado.contar_o_dia`).
func _render_o_dia() -> void:
	var total: Dictionary = Povoado.entregar_o_dia()
	for item in total:
		no_paiol[item] = int(no_paiol.get(item, 0)) + int(total[item])
	esvaziar_o_paiol()
	Povoado.contar_o_dia()
	if not total.is_empty():
		renderam.emit(total)


## Passa para a mochila o que está no paiol, o que couber. O resto fica, para a próxima.
func esvaziar_o_paiol() -> void:
	var mexeu := false
	for item in no_paiol.keys():
		var quanto := int(no_paiol[item])
		# Item que o jogo não tem mais não pode ficar esperando espaço para sempre.
		if quanto <= 0 or not Catalogo.existe(str(item)):
			no_paiol.erase(item)
			mexeu = true
		elif Inventario.adicionar(str(item), quanto):
			no_paiol.erase(item)
			mexeu = true
	if mexeu:
		mudou.emit()
