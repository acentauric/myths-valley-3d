extends Node
## A JORNADA DA FAZENDA: o estado dos capítulos 6 e 7.
##
## Os dois capítulos são UM DIA e a noite dele — o convite, a travessia, o
## casarão, o quarto da velha, o revoar, as ruínas, o amanhecer. Por isso o
## estado inteiro deles cabe num número: o DIA em que aquilo caiu. Tudo o que o
## resto do jogo precisa perguntar — já foi chamado? é hoje? já passou? — se
## responde com ele e com o relógio.
##
## O QUE CADA FATIA FEZ NÃO MORA AQUI. Mora nas missões, que já vão no save e
## já sabem dizer o que foi cumprido (`Missoes.cumpridas`). Guardar aqui uma
## segunda lista dos mesmos passos seria manter duas verdades sobre o mesmo
## assunto, e a que fosse esquecida é a que o jogador encontraria.

## O Pedro bateu na porta: é hoje. Quem quiser saber sem perguntar todo quadro
## ouve daqui.
signal marcado(dia: int)

## O ÚLTIMO PASSO DA FILA DO ARRAIAL. Ver `pronto`.
const PASSO_QUE_FECHA_O_ARRAIAL := "fe_escolher"

## O dia absoluto em que o dia da fazenda caiu. ZERO é "ainda não chegou" — e
## não o primeiro dia, que `Relogio.dia_absoluto()` conta a partir de um.
var dia: int = 0


## O DIA CHEGOU.
##
## Chamado pelo condutor da jornada na manhã em que o Pedro aparece na porta, e
## uma vez só: a jornada da fazenda acontece UMA VEZ (VILA_E_EXPEDICOES, aposta
## 5). Marcar de novo apagaria o dia em que ela aconteceu, que é a única coisa
## que este arquivo tem para guardar.
func marcar() -> void:
	if dia != 0:
		return
	dia = Relogio.dia_absoluto()
	marcado.emit(dia)


func marcada() -> bool:
	return dia != 0


## HOJE é o dia da fazenda?
##
## Vale a NOITE inteira dele, até as duas da manhã, porque o dia deste jogo
## acaba na cama ou no desmaio e não na meia-noite — e o capítulo 7 corre
## justamente na noite do 6. Quem dorme nas ruínas atrás do monte ainda está no
## dia da fazenda.
func hoje() -> bool:
	return dia != 0 and Relogio.dia_absoluto() == dia


func passou() -> bool:
	return dia != 0 and Relogio.dia_absoluto() > dia


## O JOGADOR TERMINOU O QUE TINHA PARA FAZER?
##
## É a condição do dia da fazenda, e é a resposta do autor à pergunta P4 do
## PLANO.md: o dia chega "quando o usuário terminar todas as quests
## anteriores". Duas metades, e cada uma cobre o que a outra não alcança.
##
## A LINHA DA HISTÓRIA FECHOU. `fe_escolher` é o último passo da fila do
## arraial — canteiro, depois mirante, depois fé (ver `Arraial`) —, e a fila
## garante os anteriores: quem escolheu fé levantou o mirante, e quem levantou
## o mirante riscou o canteiro. Um passo responde pelos três.
##
## E é ele, e NÃO a lista `Missoes.PRINCIPAIS` inteira, por uma razão que só
## aparece lendo o tutorial: ele chama `Missoes.limpar()` ao encerrar, e
## `limpar` zera as CUMPRIDAS também. Os dez passos de tutorial que estão em
## PRINCIPAIS — subir, casa, vilarejo, convite, a ponte — não constam mais de
## `cumpridas` quando o arraial começa. Varrer PRINCIPAIS aqui seria esperar
## para sempre por dez missões que o jogador cumpriu e o jogo esqueceu de
## propósito.
##
## NADA MAIS PENDURADO. Nenhuma missão aberta. É a metade que cobre o dia a dia
## — o Tonho, o coveiro, as ervas da Zefa, as metas de bicho — e ela se mantém
## sozinha: frente nova que abra missão nova entra na conta sem ninguém
## precisar declarar nada aqui.
##
## DUAS NÃO CONTAM, e as duas por não serem tarefa:
##
##   a PASSIVA corre sozinha — esperar a mandioca crescer. Sempre há uma aberta
##   em quem planta, e cobrá-la faria o capítulo 6 esperar pelo dia em que o
##   jogador parasse de lavrar.
##
##   a CONGELADA é missão de fé de quem migrou (ver `Missoes.congelada`). Ela
##   espera por tempo indeterminado por definição: o dia em que ele voltar
##   àquela fé, se voltar.
func pronto() -> bool:
	if not Missoes.cumprida(PASSO_QUE_FECHA_O_ARRAIAL):
		return false
	for missao in Missoes.ativas:
		if bool(missao.get("passiva", false)):
			continue
		if Missoes.congelada(str(missao.get("id", ""))):
			continue
		return false
	return true


func limpar() -> void:
	dia = 0
