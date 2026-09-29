extends Node
## Relógio do jogo: horas, dias, estações e anos.
##
## O dia NÃO vira à meia-noite. O dia começa às 6h e
## segue madrugada adentro até as 2h; o contador de dias só avança quando o
## jogador dorme na cama ou desmaia de cansaço. Assim a noite sempre acontece
## dentro do dia corrente, em vez de o número do dia trocar no meio do escuro.
##
## Tudo que depende do tempo (iluminação, plantas, rotina de NPC, clima) deve
## reagir aos SINAIS daqui, e não consultar o relógio a cada frame.
##
##
## COMPARTILHADO COM O PROTÓTIPO 3D, e lá ele é CALENDÁRIO e não relógio.
##
## O vale 3D já tem um dono da hora — o autoload `Dia`, que o céu, as luzes de
## 1887, o som do ambiente e a tela de carregamento consultam. Trocar esse dono
## seria mexer em cinco sistemas que funcionam para não ganhar nada.
##
## O que falta lá não é a hora: é o que vem depois dela. Contador de dia,
## estação, ano, e a regra de que o dia TERMINA. É disso que a planta que
## cresce, a obra que fica pronta, a fé que congela e o talento que se gasta
## uma vez por dia dependem — todos escutam o virar do dia, nenhum escuta a
## hora.
##
## E este arquivo já tinha a porta para isso, sem precisar de nada novo: o
## `pausado`. Com ele ligado, `_process` não anda, e quem manda na hora é quem
## estiver de fora. No 3D o `Dia` liga o `pausado` e espelha a hora dele aqui;
## os dias, as estações e os anos continuam saindo daqui, que é o lugar onde
## eles são contados desde sempre.
##
## Ver docs/MIGRACAO_2D_3D.md (branch prototype/myths-valley-3d), Fase 5.

signal hora_mudou(hora: int)
signal dia_comecou(dia: int, estacao: int, ano: int)
signal estacao_mudou(estacao: int)
signal desmaiou()

enum Estacao { PRIMAVERA, VERAO, OUTONO, INVERNO }

const NOMES_ESTACAO := ["Primavera", "Verão", "Outono", "Inverno"]
const DIAS_POR_ESTACAO := 28

## 1 segundo real = 2 minutos de jogo. Das 6h às 2h são 1200 minutos, ou seja
## cerca de 10 minutos reais por dia — tempo de atravessar o mapa sem correria.
const MINUTOS_POR_SEGUNDO := 2.0

const HORA_DE_ACORDAR := 6
const HORA_LIMITE := 26   ## 2h da madrugada; passou disso, o jogador desmaia

## Minutos desde a meia-noite do dia corrente. Vai de 360 (6h) até 1560 (2h),
## podendo passar de 1440 — a hora exibida é o resto da divisão por 24.
var minutos: float = HORA_DE_ACORDAR * 60.0
var dia: int = 1
var estacao: int = Estacao.PRIMAVERA
var ano: int = 1
var pausado: bool = false

var _ultima_hora: int = HORA_DE_ACORDAR


## Dia corrido desde o começo da partida. É o que serve para contar espera de
## dias — o `dia` sozinho volta a 1 quando a estação vira.
func dia_absoluto() -> int:
	return ((ano - 1) * 4 + estacao) * DIAS_POR_ESTACAO + dia


func _process(delta: float) -> void:
	if pausado:
		return

	minutos += delta * MINUTOS_POR_SEGUNDO

	if minutos >= HORA_LIMITE * 60.0:
		pausado = true   # quem tratar o desmaio chama dormir(), que despausa
		desmaiou.emit()
		return

	var hora_atual := hora()
	if hora_atual != _ultima_hora:
		_ultima_hora = hora_atual
		hora_mudou.emit(hora_atual)


func hora() -> int:
	return int(minutos / 60.0) % 24


func minuto() -> int:
	return int(minutos) % 60


## Hora com casas decimais, já dentro de 0..24. Usada pela iluminação.
func hora_fracionaria() -> float:
	return fmod(minutos / 60.0, 24.0)


## Verdadeiro depois das 24h, quando o jogador já está virando a noite.
func madrugada() -> bool:
	return minutos >= 1440.0


func nome_estacao() -> String:
	return NOMES_ESTACAO[estacao]


func texto() -> String:
	return "%s · Dia %d · %02d:%02d" % [nome_estacao(), dia, hora(), minuto()]


## Um dia ABSOLUTO escrito como o jogador o vê no alto da tela.
##
## Existe porque "volte daqui a 5 dias" obriga o jogador a fazer a conta e a
## guardar o resultado na cabeça — e ele não vai. "Volte no dia 12 do verão" é
## a mesma informação num formato que ele pode conferir a qualquer hora, porque
## é o mesmo que está escrito no relógio.
func texto_do_dia(absoluto: int) -> String:
	var desde_o_comeco := maxi(0, absoluto - 1)
	var qual := desde_o_comeco % DIAS_POR_ESTACAO + 1
	var estacao_de := int(desde_o_comeco / DIAS_POR_ESTACAO) % NOMES_ESTACAO.size()
	return "dia %d d%s %s" % [qual,
		"o" if estacao_de != 0 else "a", NOMES_ESTACAO[estacao_de]]



## Dormir na cama: acorda às 6h do dia seguinte.
func dormir() -> void:
	minutos = HORA_DE_ACORDAR * 60.0
	_ultima_hora = HORA_DE_ACORDAR
	pausado = false
	_avancar_dia()


func _avancar_dia() -> void:
	dia += 1
	if dia > DIAS_POR_ESTACAO:
		dia = 1
		estacao = (estacao + 1) % NOMES_ESTACAO.size()
		if estacao == Estacao.PRIMAVERA:
			ano += 1
		estacao_mudou.emit(estacao)
	dia_comecou.emit(dia, estacao, ano)
