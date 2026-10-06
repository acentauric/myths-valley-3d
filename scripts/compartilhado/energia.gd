extends Node
## Energia do jogador — o que limita o quanto se faz num dia.
##
## É o relógio da fazenda: o dia acaba não porque o sol se pôs, mas porque o
## corpo acabou.
##
## O custo NÃO é fixo por ação. Ele é
##
##     custo = base da ação  x  dureza do alvo  x  eficiência do personagem
##
## Ferramenta melhor não barateia o trabalho: ela DESTRAVA alvo mais duro, e
## alvo mais duro custa mais. Derrubar um pau mole com machado de ferro custa
## 1x; quando o machado de aço abrir a madeira de lei, aquele corte custa 2x.
## Quem quiser pagar menos sobe a eficiência na árvore de talentos, não a
## ferramenta.
##
## Teto e descanso ficam em `Progressao`, porque são coisa de personagem e não
## de momento.

signal mudou
signal esgotou

## Custo base de cada ação, antes da dureza do alvo.
const CUSTOS := {
	"arar": 4.0,
	"plantar": 1.0,
	"regar": 2.0,
	"colher": 2.0,
	"bater": 5.0,
	"ritual": 12.0,
	# O braço num golpe de ferramenta (vigor), já com o "bater" dentro (arvores_info).
	"golpe": 50.0,
}

## Os custos de agora: os de cima, ou os que o jogador acertou em Ajustes → Esforço
## (`definir_custo`). Os portões calculam a conta por `custo()`, então mudar o
## balanço do fôlego e do vigor não reprova teste nenhum.
var custos: Dictionary = CUSTOS.duplicate()
const PREFERENCIAS_ESFORCO := "user://esforco.cfg"

## Abaixo disto o HUD avisa e o passo encurta.
const LIMIAR_DE_CANSACO := 0.2
const PESO_DO_CANSACO := 0.62

## O CORPO PASSOU A PESAR, e o corpo voltou ao normal.
##
## O cansaço já mudava o jogo em duas coisas grandes — o passo cai para 62% e
## a corrida deixa de funcionar — e não avisava nenhuma delas. Do lado de cá do
## código isso é uma constante; do lado de lá é um jogo que de repente ficou
## lento, e a primeira suspeita de quem joga não é "estou cansado", é "travou".
##
## Estes dois sinais existem para que o jogo possa dizer. Ver
## `Mundo._ao_cansar`.
signal cansou
signal descansou

## A RESERVA É UMA CONTA PRÓPRIA. Entre 04/10 e 06/10 ela espelhou o vigor do
## corpo do 3D (`registrar_vigor`, `8413ae7`): como o vigor volta sozinho, a
## comida, a cama e os talentos de reserva perderam a função. Decisão do autor
## em 06/10 (#82): a reserva volta a ser a que sempre foi — gasta no trabalho e
## na luta, devolvida só pela comida, pela cama e pelo desmaio. O vigor, o fôlego
## curto da corrida e do golpe, mora no `player_controller`, na conta dele.
var atual: float = Progressao.ENERGIA_MAXIMA_INICIAL

## O estado do último aviso, para os sinais saírem só na VIRADA e não a cada
## machadada dada abaixo do limiar.
var _estava_cansado: bool = false


func _ready() -> void:
	_ler_custos()
	atual = Progressao.energia_maxima
	Progressao.mudou.connect(_ao_mudar_progressao)
	# Ouvir o próprio `mudou` pega TODO caminho que mexe no fôlego — gastar,
	# comer, dormir, desmaiar, carregar o save — sem ter de lembrar de avisar
	# em cada um deles. Esquecer um seria fácil; são oito.
	mudou.connect(_conferir_o_cansaco)


func _conferir_o_cansaco() -> void:
	var agora := cansado()
	if agora == _estava_cansado:
		return
	_estava_cansado = agora
	if agora:
		cansou.emit()
	else:
		descansou.emit()


func maximo() -> float:
	return Progressao.energia_maxima


func nome_recurso() -> String:
	return "fôlego"


func fracao() -> float:
	return atual / maxf(1.0, maximo())


func cansado() -> bool:
	return fracao() <= LIMIAR_DE_CANSACO


func esgotado() -> bool:
	return atual <= 0.0


## Multiplicador de velocidade: quem está no fim do dia anda arrastado.
func passo() -> float:
	return PESO_DO_CANSACO if cansado() else 1.0


## Quanto uma ação custa contra um alvo daquela dureza.
func custo(acao: String, dureza: float = 1.0) -> float:
	return float(custos.get(acao, 0.0)) * dureza * Progressao.eficiencia


## Muda o custo-base de uma ação (Ajustes → Esforço) e guarda a escolha.
func definir_custo(acao: String, valor: float) -> void:
	if not CUSTOS.has(acao):
		return
	custos[acao] = maxf(0.0, valor)
	var arquivo := ConfigFile.new()
	arquivo.load(PREFERENCIAS_ESFORCO)
	arquivo.set_value("custos", acao, custos[acao])
	if arquivo.save(PREFERENCIAS_ESFORCO) != OK:
		push_warning("Não foi possível salvar o custo de %s." % acao)


func _ler_custos() -> void:
	var arquivo := ConfigFile.new()
	if arquivo.load(PREFERENCIAS_ESFORCO) != OK:
		return
	for acao in CUSTOS:
		custos[acao] = maxf(0.0, float(arquivo.get_value("custos", acao, CUSTOS[acao])))


## Põe a reserva num valor exato.
func definir(valor: float) -> void:
	atual = clampf(valor, 0.0, maximo())
	mudou.emit()


## Tem fôlego para esta ação? Quem pergunta é o mundo, antes de deixar agir.
func aguenta(acao: String, dureza: float = 1.0) -> bool:
	return atual + 0.001 >= custo(acao, dureza)


## Cobra o custo. Devolve false — e não cobra nada — se não havia fôlego.
func gastar(acao: String, dureza: float = 1.0) -> bool:
	var preco := custo(acao, dureza)
	if preco <= 0.0:
		return true
	if atual < preco:
		return false

	atual -= preco
	mudou.emit()
	if atual <= 0.0:
		atual = 0.0
		esgotou.emit()
	return true


## Dormir devolve um VALOR FIXO, não uma fração. Ver Progressao.
func dormir() -> void:
	atual = minf(maximo(), atual + Progressao.recuperacao_ao_dormir)
	mudou.emit()


func desmaiar() -> void:
	atual = minf(maximo(), atual + Progressao.recuperacao_ao_desmaiar)
	mudou.emit()


## Comida e descanso curto entram aqui quando a cozinha existir.
func repor(quanto: float) -> void:
	atual = minf(maximo(), atual + quanto)
	mudou.emit()


func encher() -> void:
	atual = maximo()
	mudou.emit()


func _ao_mudar_progressao() -> void:
	atual = minf(atual, maximo())
	mudou.emit()
