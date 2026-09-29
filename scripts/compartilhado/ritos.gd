extends Node
## O RITO num marco de fé: parar, pedir, e o que se ganha com isso.
##
## Era `Cruzeiro`, e só sabia de um: a cruz da praça matriz. Com três fés no
## jogo (ver fe.gd) a cruz virou um marco entre outros — o terreiro e a
## gameleira fazem a mesma coisa, com outro nome e outra graça —, e um sistema
## que se chama pelo nome de um único lugar não aceita o segundo sem mentir.
##
## O que continua igual, porque continua certo:
##
## Três coisas ao celebrar: fôlego, experiência e uma bênção com prazo.
##
## O que segura o equilíbrio é a ESPERA. Sem ela o marco vira cama de graça e a
## noite deixa de importar. Sete dias — uma semana de jogo, um quarto de
## estação — é curto o bastante para ser hábito e longo o bastante para não
## substituir dormir.
##
## E O QUE MUDOU COM A FÉ: o marco só responde a quem é daquela fé. Rezar no
## cruzeiro sendo do candomblé não dá graça nenhuma — dá uma fala. É isso que
## faz a escolha da fé pesar, e é por isso que a conferência de fé fica aqui e
## não na boca de quem chama.

signal celebrou(marco: String, bencao: String)
signal mudou

## Dias entre um rito e outro no MESMO marco.
##
## A conta é por marco, e não por fé, de propósito: quem tem três capelas
## católicas no mapa pode rezar em cada uma no seu tempo. É o que faz sair de
## casa valer a pena, e é o que a fé católica tem de vantagem — ela é a única
## com mais de um marco.
const ESPERA_EM_DIAS := 7

## Fôlego devolvido: uma fração do TETO, e não um valor fixo. Ver a nota das
## bênçãos em fe.gd — vale o mesmo motivo.
const FRACAO_DE_FOLEGO := 0.35

## Duração base de uma bênção, em dias.
const DURACAO_EM_DIAS := 2

## Nome do efeito da bênção em `Efeitos` — quem cuida do prazo é ele.
const EFEITO := "bencao"

## id do marco -> dia em que pode celebrar de novo.
var _liberado_em: Dictionary = {}


func espera() -> int:
	# "Devoção", da árvore católica, corta o tempo pela metade.
	var corte := Talentos.bonus("espera_do_rito")
	return maxi(1, int(roundf(ESPERA_EM_DIAS * (1.0 + corte))))


func duracao() -> int:
	# "Promessa" e "Encantado da mata" dobram a duração.
	return DURACAO_EM_DIAS + int(Talentos.bonus("duracao_da_bencao")) * DURACAO_EM_DIAS


func dias_para_celebrar(marco: String) -> int:
	return maxi(0, int(_liberado_em.get(marco, 0)) - Relogio.dia_absoluto())


## Em que dia este marco volta a dar graça. É o que o jogo diz ao jogador, em
## vez de "daqui a N dias": data se confere no relógio do alto da tela, conta
## de cabeça não.
func dia_liberado(marco: String) -> int:
	return int(_liberado_em.get(marco, 0))


## No DIA DA FESTA da fé do marco a graça sai mesmo fora do prazo — é o que
## faz o dia ser dia. Só no marco daquela fé: a festa da igreja não abre o
## terreiro. Ver Fe.FESTAS.
func pode_celebrar(marco: String) -> bool:
	if Fe.festa_de_hoje() != "" and Fe.festa_de_hoje() == Fe.fe_do_marco(marco):
		return true
	return dias_para_celebrar(marco) <= 0


## Este marco é da fé que o personagem pratica?
##
## Marco de fé alheia não é marco proibido: é marco mudo. O jogador chega,
## repara, e nada acontece — o que é exatamente o que acontece quando alguém
## para na frente de uma coisa em que não crê.
func atende(marco: String) -> bool:
	var fe := Fe.fe_do_marco(marco)
	return fe != "" and Fe.praticada(fe)


## Celebra no marco. Devolve {} quando não deu — sem fé, fé errada, ou o tempo
## ainda não fechou. Quem chama pergunta antes o motivo, para poder dizê-lo.
func celebrar(marco: String) -> Dictionary:
	if not atende(marco) or not pode_celebrar(marco):
		return {}
	var fe := Fe.fe_do_marco(marco)

	_liberado_em[marco] = Relogio.dia_absoluto() + espera()
	Energia.repor(Progressao.energia_maxima * folego())
	Talentos.ganhar("rezar")
	Fe.ganhar("rito")
	# A FESTA: celebrar no dia dela, no marco dela, rende por cima do rito — e
	# rende com GENTE, porque todo mundo da fé está ali (ver `Mundo._posto_de`).
	if Fe.festa_de_hoje() == fe:
		Fe.ganhar("festa")
		for morador in Afinidade.da_fe(fe):
			Afinidade.somar(str(morador), Afinidade.POR_FESTA)

	var pote: Dictionary = Fe.BENCAOS.get(fe, {})
	if pote.is_empty():
		mudou.emit()
		return {}
	var chaves := pote.keys()
	var escolhida := str(chaves[randi() % chaves.size()])
	var dado: Dictionary = pote[escolhida]
	Efeitos.conceder(EFEITO, str(dado["nome"]), str(dado["campo"]),
		quanto_vale(fe, escolhida), duracao(), "bencao")
	celebrou.emit(marco, escolhida)
	mudou.emit()
	return dado


## Quanto do teto de fôlego o rito devolve hoje. "Ladainha", "Ebó" e "Mesa de
## caboclo" mexem aqui — cada fé tem o seu, e é de propósito: é o primeiro nó
## que quase todo mundo compra, e ele tem que se sentir no mesmo dia.
func folego() -> float:
	return FRACAO_DE_FOLEGO * (1.0 + Talentos.bonus("folego_do_rito"))


## Quanto a bênção soma de fato, com o personagem de hoje.
func quanto_vale(fe: String, bencao: String) -> float:
	var dado: Dictionary = Fe.BENCAOS.get(fe, {}).get(bencao, {})
	if dado.is_empty():
		return 0.0
	var forca := 1.0 + Talentos.bonus("forca_da_bencao")
	return float(Progressao.get(str(dado["campo"]))) * float(dado["fracao"]) * forca


func bencao_ativa() -> String:
	return Efeitos.nome(EFEITO)


func dias_de_bencao() -> int:
	return Efeitos.dias_restantes(EFEITO)
