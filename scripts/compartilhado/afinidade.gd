extends Node
## AFINIDADE com os moradores do arraial.
##
## O GDD promete "sistema de afinidade e ofícios dos moradores" desde a
## primeira versão, e não havia uma linha disso. O arraial tinha seis pessoas
## que andavam, tinham casa e falavam — e nenhuma delas guardava memória de
## você. Falar com o Seu Benedito no dia 1 e no dia 90 dava exatamente a mesma
## conversa.
##
## É o segundo motor de Stardew, e é independente da fazenda de propósito: quem
## está cansado de arar tem outra coisa para fazer que também anda. Aqui ele
## tem uma função a mais, que é do nosso enredo — o jogador chegou de fora,
## herdeiro de uma terra que não é dele por trabalho, e o arraial precisa
## decidir o que pensa disso.
##
##
## COMO SE GANHA
##
##   conversar    uma vez por dia, com quem for. Pouco, e é de propósito: é o
##                chão da relação, não o caminho dela.
##   presentear   uma vez por dia, e é aqui que está o jogo. O que a pessoa
##                GOSTA vale muito; o que ela não gosta TIRA.
##   favor        cumprir a missão dela. É o salto.
##
## O teto diário existe para a afinidade não virar moagem: dar trinta mangas
## seguidas ao Seu Benedito não compra amizade, compra estranheza.
##
##
## POR QUE O DESGOSTO TIRA PONTO
##
## Porque sem isso presentear é só apertar E com qualquer coisa na mão, e a
## escolha morre. O que faz o presente valer alguma coisa é ele poder estar
## errado — e o que faz o jogador prestar atenção em quem é cada um.
##
## O gosto de cada um está em `data/dialogos/aldeoes.json`, junto da fala,
## porque é a mesma coisa: é caracterização. Quem escrever o próximo morador
## escreve as duas juntas.

signal mudou(morador: String)
signal subiu_de_grau(morador: String, grau: int)

const ARQUIVO_DOS_MORADORES := "res://data/dialogos/aldeoes.json"

## Quem mora no arraial, na ordem em que a tela lista.
##
## A ordem não é alfabética: é a de quem o jogador conhece primeiro. O Seu
## Benedito e a Dona Zefa são os dois donos de terra que ele precisa enfrentar
## para crescer; o Cosme, o Tonho e a Dona Filó vêm da vila, e chegam depois.
##
## O Pedro fica de fora: ele é o guia, tem sistema de fala próprio e a relação
## com ele é contada pelo tutorial, não medida em pontos.
const MORADORES := ["benedito", "zefa", "cosme", "tonho", "filo", "candinha", "damiao"]

## Os graus, e o que cada um é na boca de quem mora aqui.
##
## Os nomes não são "nível 1, nível 2": são o que uma pessoa do Recôncavo de
## 1887 diria de outra. É a mesma régua da fala — o número é de dentro, o nome
## é o que o jogador lê.
const GRAUS := [
	{"de": 0, "nome": "Desconhecido"},
	{"de": 10, "nome": "Conhecido de vista"},
	{"de": 30, "nome": "Gente boa"},
	{"de": 60, "nome": "Amigo"},
	{"de": 100, "nome": "Da família"},
]

const POR_CONVERSA := 1
const POR_PRESENTE_BOM := 8
const POR_PRESENTE_QUALQUER := 2
const POR_PRESENTE_RUIM := -5
const POR_FAVOR := 25

## O teto, que é onde "Da família" mora. Sem teto, o número cresce para sempre
## e o último grau deixa de significar alguma coisa.
const MAXIMO := 120
## E o piso. Negativo faria sentido no papel — inimizade — e não tem nenhuma
## consequência implementada, então seria número sem mecânica, que é o defeito
## que a árvore de talentos já custou caro.
const MINIMO := 0

## morador -> pontos
var pontos: Dictionary = {}
## morador -> dia absoluto em que já se conversou e em que já se deu presente.
## Dois contadores e não um: conversar e presentear são dois gestos.
var _falou_no_dia: Dictionary = {}
var _deu_no_dia: Dictionary = {}


func _ready() -> void:
	Relogio.dia_comecou.connect(_ao_comecar_dia)
	# O preço social de migrar de fé. Ver `_ao_migrar`.
	Fe.migrou.connect(_ao_migrar)


func _ao_comecar_dia(_dia: int, _estacao: int, _ano: int) -> void:
	# Não limpa: os contadores guardam o DIA, e comparar com o dia de hoje é o
	# bastante. Limpar exigiria que este sinal chegasse antes de qualquer
	# conversa do dia, e ordem de sinal é coisa que se quebra sozinha.
	pass


func de(morador: String) -> int:
	return int(pontos.get(morador, 0))


func grau(morador: String) -> int:
	var quanto := de(morador)
	var qual := 0
	for i in GRAUS.size():
		if quanto >= int(GRAUS[i]["de"]):
			qual = i
	return qual


func nome_do_grau(morador: String) -> String:
	return str(GRAUS[grau(morador)]["nome"])


## Quanto falta para o próximo grau, ou -1 quando já está no último.
func falta_para_o_proximo(morador: String) -> int:
	var qual := grau(morador)
	if qual >= GRAUS.size() - 1:
		return -1
	return int(GRAUS[qual + 1]["de"]) - de(morador)


## Soma (ou tira) pontos. Devolve quanto de fato entrou, já com teto e piso —
## quem chama usa isso para saber se vale dizer alguma coisa ao jogador.
func somar(morador: String, quanto: int) -> int:
	var antes := de(morador)
	var grau_antes := grau(morador)
	pontos[morador] = clampi(antes + quanto, MINIMO, MAXIMO)
	var entrou := de(morador) - antes
	if entrou != 0:
		mudou.emit(morador)
		if grau(morador) > grau_antes:
			subiu_de_grau.emit(morador, grau(morador))
	return entrou


# --- os gestos ------------------------------------------------------------------

func pode_conversar(morador: String) -> bool:
	return int(_falou_no_dia.get(morador, -1)) != Relogio.dia_absoluto()


## Registra a conversa do dia. Quem chama é o morador, depois de falar.
func conversou(morador: String) -> int:
	if not pode_conversar(morador):
		return 0
	_falou_no_dia[morador] = Relogio.dia_absoluto()
	return somar(morador, POR_CONVERSA)


func pode_presentear(morador: String) -> bool:
	return int(_deu_no_dia.get(morador, -1)) != Relogio.dia_absoluto()


## O que este item vale para esta pessoa: "bom", "ruim" ou "qualquer".
##
## Lê de `aldeoes.json`, ao lado da fala, porque gosto é caracterização e não
## tabela de balanço. O que o Seu Benedito gosta diz quem ele é tanto quanto o
## que ele fala.
func juizo(morador: String, item: String) -> String:
	var dele: Dictionary = Jogo.dados(ARQUIVO_DOS_MORADORES).get(morador, {})
	if (dele.get("desgosta", []) as Array).has(item):
		return "ruim"
	if (dele.get("gosta", []) as Array).has(item):
		return "bom"
	return "qualquer"


func quanto_vale(morador: String, item: String) -> int:
	match juizo(morador, item):
		"bom":
			return POR_PRESENTE_BOM
		"ruim":
			return POR_PRESENTE_RUIM
	return POR_PRESENTE_QUALQUER


## Entrega o presente. Consome o item e devolve quanto entrou de afinidade.
## Devolve 0 e não consome nada se já houve presente hoje.
func presentear(morador: String, item: String) -> int:
	if not pode_presentear(morador) or not Inventario.consumir(item, 1):
		return 0
	_deu_no_dia[morador] = Relogio.dia_absoluto()
	return somar(morador, quanto_vale(morador, item))


## O favor cumprido. Vale muito porque é o único que custa dias de trabalho.
func fez_o_favor(morador: String) -> int:
	return somar(morador, POR_FAVOR)


# --- a fé de cada um ------------------------------------------------------------

## O PREÇO SOCIAL DE MIGRAR.
##
## A fase 5 do PLANO.md pede que a fé tenha consequência fora da planilha, e a
## primeira consequência é esta: migrar tem preço com GENTE, não só com XP. Num
## arraial de trezentas almas, quem deixa a igreja pelo terreiro é notado antes
## de chegar em casa — e quem é da fé que você deixou desconta isso na conta
## que este arquivo guarda.
##
## Deixar custa mais do que chegar rende, de propósito: se fosse ao contrário,
## migrar em roda seria lucro. E chegar rende ALGUMA coisa porque a fé de cá
## também é comunidade: quem entra para o terreiro passa a ser gente da casa.
const POR_ABANDONO := -15
const POR_CHEGADA := 5

## O que celebrar no dia da festa rende com cada um da fé que está lá. Menos
## que o presente bom, porque não é para ninguém em particular; mais que a
## conversa, porque é o dia inteiro do arraial. Ver `Ritos.celebrar`.
const POR_FESTA := 6

## De que fé é este morador. Lido do arquivo ao lado da fala, como o gosto (ver
## `juizo`): fé é caracterização, não tabela de balanço. A Dona Zefa que vai na
## missa de manhã e no terreiro de noite "por dentro sabe de qual é", e o
## arquivo diz de qual.
func fe_de(morador: String) -> String:
	var dele: Dictionary = Jogo.dados(ARQUIVO_DOS_MORADORES).get(morador, {})
	return str(dele.get("fe", ""))


func da_fe(fe: String) -> Array:
	var quem: Array = []
	for morador in MORADORES:
		if fe_de(str(morador)) == fe:
			quem.append(str(morador))
	return quem


func nome_de(morador: String) -> String:
	var dele: Dictionary = Jogo.dados(ARQUIVO_DOS_MORADORES).get(morador, {})
	return str(dele.get("nome", morador))


## Quem é da fé deixada desconta; quem é da fé de chegada abre um pouco a porta.
## Ligado ao `Fe.migrou` no `_ready`: é o `Fe` quem sabe que houve migração, e
## é este arquivo quem sabe o que isso custa.
func _ao_migrar(de: String, para: String) -> void:
	for morador in da_fe(de):
		somar(str(morador), POR_ABANDONO)
	for morador in da_fe(para):
		somar(str(morador), POR_CHEGADA)


# --- salvar ---------------------------------------------------------------------

func estado() -> Dictionary:
	return {
		"pontos": pontos.duplicate(true),
		"falou": _falou_no_dia.duplicate(true),
		"deu": _deu_no_dia.duplicate(true),
	}


func restaurar(dados: Dictionary) -> void:
	pontos = (dados.get("pontos", {}) as Dictionary).duplicate(true)
	_falou_no_dia = (dados.get("falou", {}) as Dictionary).duplicate(true)
	_deu_no_dia = (dados.get("deu", {}) as Dictionary).duplicate(true)
	mudou.emit("")
