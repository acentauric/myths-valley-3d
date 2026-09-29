extends Node
## VIDA do jogador — o que o corpo aguenta de pancada. Separada do fôlego.
##
## O fôlego (`Energia`) é o relógio da fazenda: acaba porque o dia de trabalho
## acabou. A vida é outra coisa: acaba porque alguma coisa bateu. As duas
## podiam ter sido uma conta só, e não podem ser — se cansaço e ferimento
## descontassem do mesmo número, arar a roça deixaria o jogador mais fraco para
## a mata, e a mata o deixaria mais fraco para a roça. Cada uma tem o seu
## remédio: o fôlego se come de volta; a vida, a noite devolve inteira e o chá
## de folha devolve um pedaço (ver Cozinha). Comida não cura, e a mochila diz
## qual é o remédio: é a lição do Graveyard Keeper.
##
## É a primeira peça do COMBATE NO MUNDO (fase 6-A do PLANO.md), decidido em
## setembro de 2026 com o autor: em tempo real, no mundo, com o que se tem na
## mão, e a qualquer hora fora da vila. Antes de haver criatura, há corpo:
## quem sabe cair sabe o que está em jogo.
##
## TETO: `Progressao.vida_maxima` mais o que a teia dá — "vigor", dez de vida
## por nó. É o `pele_grossa`, que prometia "aguentar mais pancada" desde antes
## de existir pancada, e estava na lista de espera do portão dos talentos.
##
## CAIR NÃO É MORRER. Vida no chão vira noite no chão, como o desmaio de
## cansaço: alguém traz para casa, o dia vira, e o corpo acorda inteiro — mas
## acorda. Ver `Mundo._ao_cair`. Morrer de verdade seria outro jogo, e este é
## um jogo de plantar.

signal mudou
signal ferido(quanto: float)
signal caiu
## A peçonha entrou (`envenenado` true) ou saiu (false). Ver `envenenar`.
signal envenenado(esta: bool)

## Quanto cada nó de "vigor" da teia põe no teto.
const VIDA_POR_VIGOR := 10.0

var atual: float = Progressao.VIDA_MAXIMA_INICIAL


func _ready() -> void:
	atual = maximo()
	Progressao.mudou.connect(_ao_mudar_progressao)


func maximo() -> float:
	return Progressao.vida_maxima + Talentos.bonus("vigor") * VIDA_POR_VIGOR


func fracao() -> float:
	var teto := maximo()
	return atual / teto if teto > 0.0 else 0.0


## Levar pancada. Devolve quanto de fato entrou. Quem chega a zero CAI, e cair
## é um sinal só, uma vez: pancada em quem já está no chão não conta, senão a
## criatura que continuasse batendo faria o jogador "cair" dez vezes na mesma
## noite, e o mundo levaria dez vezes para casa.
func ferir(quanto: float) -> float:
	if quanto <= 0.0 or atual <= 0.0:
		return 0.0
	var antes := atual
	atual = maxf(0.0, atual - quanto)
	var entrou := antes - atual
	if entrou > 0.0:
		_respiro_por = RESPIRO + Equipamento.bonus("respiro")
	ferido.emit(entrou)
	mudou.emit()
	if atual <= 0.0:
		caiu.emit()
	return entrou


func curar(quanto: float) -> void:
	if quanto <= 0.0:
		return
	atual = minf(maximo(), atual + quanto)
	mudou.emit()


## A GINGA tira o corpo do bote por um instante (ver Luta.GINGA). Enquanto
## `livre()`, a mordida que chega não entra — o bicho a gasta no vazio, e é
## isso que a criatura conta como esquiva.
##
## CONTADO EM TEMPO DE FÍSICA, o mesmo relógio do bote (ver
## `Criatura._seguir_o_bote`). Com o relógio de parede, uma máquina carregada
## atrasava a física e não atrasava a janela: a boca fechava depois de a
## janela vencer, e a ginga feita na hora certa não livrava ninguém.
var _livre_por: float = 0.0


func livrar(segundos: float) -> void:
	_livre_por = maxf(_livre_por, segundos)


func livre() -> bool:
	return _livre_por > 0.0


## O RESPIRO DEPOIS DA PANCADA. Quem acabou de apanhar fica `RESPIRO` segundos
## sem que mordida nova entre: o corpo pisca, e a boca que fecha nesse tempo
## fecha no vazio.
##
## É do Stardew Valley, e com o número dele: 1,2 s depois de cada pancada (o
## anel de proteção de lá soma 0,4). Sem isso, três caititus da mesma
## clareira mordiam na mesma meia volta de relógio — o bote de cada um avisa,
## mas três avisos juntos não se esquivam, e o jogador ia ao chão sem ter
## errado nada. O respiro NÃO é esquiva: não conta para a lição da ginga.
##
## O PATUÁ da Dona Zefa alonga o respiro (`respiro` do que está vestido), que
## é o que o anel de proteção faz lá: 0,4 s a mais.
##
## `ferir` não recusa pancada no respiro — quem recusa é a criatura, na hora
## de morder (ver `Criatura._morder`). Queda, conta e portão continuam podendo
## tirar vida de quem quer que seja.
const RESPIRO := 1.2
var _respiro_por: float = 0.0


func respirando() -> bool:
	return _respiro_por > 0.0


func _physics_process(delta: float) -> void:
	if _livre_por > 0.0:
		_livre_por -= delta
	if _respiro_por > 0.0:
		_respiro_por -= delta
	_correr_a_peconha(delta)


## A PEÇONHA: o que fica depois da mordida da jararaca (ver Criatura).
##
## É o que o Stardew chama de "debuff", e o que a imunidade de lá encurta: um
## mal que continua depois da pancada. Tira `veneno_ritmo` de vida por
## segundo durante `veneno_por` segundos — devagar, sem respiro, sem número
## subindo a cada quadro (só a barra escurece, ver a HUD) —, e para com o CHÁ
## DE FOLHA (`curar_veneno`), com a noite, ou quando o jogador cai.
##
## Em TEMPO DE FÍSICA, como o respiro, e parado enquanto a conversa e a tela
## param o mundo: bicho não morde quem está lendo, e peçonha não corre em
## quem está lendo.
##
## O SANGUE GROSSO da teia (raiz Combate, `imunidade`) encurta o tempo dela:
## a mesma coisa que a imunidade faz no Stardew, medida em tempo e não em
## sorteio. Vai no save: fechar o jogo não cura mordida de cobra.
var veneno_por: float = 0.0
var veneno_ritmo: float = 0.0


func envenenar(dura: float, por_segundo: float) -> void:
	if dura <= 0.0 or por_segundo <= 0.0 or atual <= 0.0:
		return
	var estava := envenenado_agora()
	veneno_por = maxf(veneno_por, dura * (1.0 - clampf(Talentos.bonus("imunidade"), 0.0, 0.9)))
	veneno_ritmo = maxf(veneno_ritmo, por_segundo)
	if not estava:
		envenenado.emit(true)
	mudou.emit()


func envenenado_agora() -> bool:
	return veneno_por > 0.0


func curar_veneno() -> void:
	if not envenenado_agora():
		return
	veneno_por = 0.0
	veneno_ritmo = 0.0
	envenenado.emit(false)
	mudou.emit()


## QUEM SABE DIZER "AGORA NÃO".
##
## A peçonha não corre com caixa de fala aberta nem com tela cheia na frente:
## o jogador não pode perder vida lendo. Só que QUAIS telas existem é coisa do
## projeto — este arquivo é compartilhado com o protótipo 3D, que não tem o
## `Telas` e cuja caixa de fala é outra.
##
## Então o arquivo não pergunta a ninguém em particular: ele pergunta a quem
## foi apresentado. O 2D liga isto ao `Dialogo` e ao `Telas` no `Telas._ready`;
## o protótipo liga ao que tiver, ou não liga, e aí a peçonha corre sempre —
## que é o certo num vale onde ninguém abriu tela nenhuma.
##
## É a mesma separação da tecla da mão e do Tab: o que depende do projeto fica
## no projeto, a regra viaja. Aqui ela aparece pela terceira forma — não é
## entrada nem tipo, é uma PERGUNTA sobre o estado da interface.
var esta_lendo: Callable = Callable()


func _correr_a_peconha(delta: float) -> void:
	if not envenenado_agora():
		return
	if esta_lendo.is_valid() and esta_lendo.call():
		return
	veneno_por -= delta
	atual = maxf(0.0, atual - veneno_ritmo * delta)
	mudou.emit()
	if atual <= 0.0:
		curar_veneno()
		caiu.emit()
	elif veneno_por <= 0.0:
		curar_veneno()


## Dormir cura inteiro. O chá de folha cura um pedaço; a noite, tudo — e a
## peçonha também sai com ela.
func dormir() -> void:
	atual = maximo()
	_respiro_por = 0.0
	curar_veneno()
	mudou.emit()


func _ao_mudar_progressao() -> void:
	atual = minf(atual, maximo())
	mudou.emit()
