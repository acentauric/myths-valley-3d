extends Node
## Relógio do vale: hora do dia contínua (0–24), velocidade da passagem do tempo e
## as curvas de sol, céu e luz que o cenário consome. Independente dos saves do 2D.

signal hora_mudou(hora: float)
signal periodo_mudou(periodo: String)

const ARQUIVO := "user://preferencias_visuais.cfg"
## Segundos reais por hora do jogo em cada velocidade (Parada, Lenta, Normal,
## Rápida).
##
## A ESCALA MUDOU, e o padrão com ela. O vale abria em "Rápida" — dez segundos
## por hora, ou um dia inteiro em QUATRO MINUTOS. Dava para atravessar a vila e
## anoitecer no caminho, e o relógio do HUD virava um cronômetro correndo.
##
## A referência para o novo "Normal" é o jogo 2D, que roda dois minutos de jogo
## por segundo real — trinta segundos por hora, ou doze minutos de dia. É o
## ritmo que o irmão mais velho deste projeto já provou: tempo de atravessar o
## mapa sem correria. "Lenta" é o triplo disso, para quem quer passear; e
## "Rápida" continua existindo em dez, que é onde ela serve, que é teste.
const VELOCIDADES := [0.0, 90.0, 30.0, 10.0]
const ROTULOS_VELOCIDADE := ["Parada", "Lenta", "Normal", "Rápida"]
## Nascer e pôr do sol em Bom Jesus no fim de setembro (latitude -12,8°, hora solar).
const NASCER := 5.95
const POR := 18.0
## Hora em que o menu abre: o começo do dia.
const INICIO_DO_DIA := 6.5

var hora: float = 9.0
## Começa em "Normal" (2), e não em "Rápida": ver `VELOCIDADES`.
var velocidade: int = 2
## Hora em que o jogo começa (AJUSTAR → Cenário e tempo).
var hora_inicial: float = 7.0
## Congela a passagem do tempo (o menu controla o próprio relógio).
var pausado := false
## Se o botão de relógio do HUD pode pausar o dia dentro do jogo (AJUSTAR).
var pausa_no_jogo := false
## Segura o relógio enquanto o vale do jogo se monta: o jogador chega exatamente na
## hora_inicial, a mesma que escolheu a capa (dia ou noite) da tela de carregamento.
## Separado de `pausado`, que é a escolha do jogador e aparece no HUD.
var congelado_na_carga := false
var _periodo := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var preferencias := ConfigFile.new()
	if preferencias.load(ARQUIVO) == OK:
		velocidade = clampi(int(preferencias.get_value("dia", "velocidade", 2)), 0, VELOCIDADES.size() - 1)
		hora_inicial = fmod(float(preferencias.get_value("dia", "hora_inicial", 7.0)), 24.0)
		pausa_no_jogo = bool(preferencias.get_value("dia", "pausa_no_jogo", false))
		hora = hora_inicial
	_atualizar_periodo()


func _process(delta: float) -> void:
	var segundos_por_hora: float = VELOCIDADES[velocidade]
	if pausado or congelado_na_carga or segundos_por_hora <= 0.0:
		return
	definir_hora(hora + delta / segundos_por_hora)


func definir_hora(nova: float) -> void:
	hora = fposmod(nova, 24.0)
	_espelhar_no_calendario()
	hora_mudou.emit(hora)
	_atualizar_periodo()


## O CALENDÁRIO DO JOGO 2D ANDA JUNTO COM A HORA DAQUI.
##
## O `Relogio` é arquivo do 2D, compartilhado (ver `scripts/compartilhado/`), e
## lá ele é o dono do tempo. Aqui ele é **calendário**: quem manda na hora
## continua sendo este autoload, porque é ele que o céu, as luzes de 1887, o
## som do ambiente e a tela de carregamento consultam — trocar esse dono seria
## mexer em cinco sistemas que funcionam para não ganhar nada.
##
## O que o vale não tinha e o calendário traz é o que vem DEPOIS da hora: o
## contador de dia, a estação e o ano. É disso que dependem a planta que
## cresce, a obra que fica pronta, o efeito que vence e o talento que se gasta
## uma vez por dia — todos escutam o virar do dia, nenhum escuta a hora.
##
## A porta para isso já existia no próprio `Relogio`, e não foi preciso mudar
## uma linha dele: com `pausado` ligado, o `_process` de lá não anda e quem
## manda na hora é quem está de fora. Daqui se escreve `minutos`, que é como
## ele guarda a hora — e é por isso que `hora()` responde igual nos dois.
##
## O DIA NÃO VIRA SOZINHO, e é de propósito. No 2D o contador só avança quando
## o jogador dorme ou desmaia, para a noite acontecer dentro do dia corrente.
## O vale ainda não tem cama; quando tiver, ela chama `Relogio.dormir()` e o
## resto segue por conta.
func _espelhar_no_calendario() -> void:
	var calendario := get_node_or_null("/root/Relogio")
	if calendario == null:
		return
	calendario.pausado = true
	calendario.minutos = hora * 60.0


func avancar(horas: float) -> void:
	definir_hora(hora + horas)


func definir_velocidade(indice: int) -> void:
	velocidade = clampi(indice, 0, VELOCIDADES.size() - 1)
	var preferencias := ConfigFile.new()
	preferencias.load(ARQUIVO)
	preferencias.set_value("dia", "velocidade", velocidade)
	preferencias.save(ARQUIVO)


func definir_pausa_no_jogo(permitir: bool) -> void:
	pausa_no_jogo = permitir
	var preferencias := ConfigFile.new()
	preferencias.load(ARQUIVO)
	preferencias.set_value("dia", "pausa_no_jogo", pausa_no_jogo)
	preferencias.save(ARQUIVO)


func definir_hora_inicial(nova: float) -> void:
	hora_inicial = fposmod(nova, 24.0)
	var preferencias := ConfigFile.new()
	preferencias.load(ARQUIVO)
	preferencias.set_value("dia", "hora_inicial", hora_inicial)
	preferencias.save(ARQUIVO)


## "madrugada", "manha", "tarde", "entardecer" ou "noite".
func periodo() -> String:
	if hora < NASCER - 0.5:
		return "madrugada"
	if hora < 12.0:
		return "manha"
	if hora < POR - 1.0:
		return "tarde"
	if hora < POR + 0.8:
		return "entardecer"
	return "noite"


func eh_noite() -> bool:
	return eh_noite_em(hora)


## A mesma regra de eh_noite() para uma hora qualquer (0–24), como a hora em que o jogo
## vai começar.
func eh_noite_em(outra_hora: float) -> bool:
	var h := fposmod(outra_hora, 24.0)
	return h < NASCER or h >= POR + 0.3


## 0 no fundo da noite, 1 ao meio-dia; transição suave no nascer e no pôr.
func luz_do_dia() -> float:
	var alvorada := smoothstep(NASCER - 0.8, NASCER + 1.2, hora)
	var crepusculo := 1.0 - smoothstep(POR - 1.2, POR + 0.8, hora)
	return clampf(minf(alvorada, crepusculo), 0.0, 1.0)


## Posição do sol de verdade para Bom Jesus dos Pobres: latitude do KML (a Praça, que
## world_builder informa em definir_latitude) e declinação do dia DIA_DO_ANO. A hora do
## jogo é a hora solar média do lugar — em 1887 não havia fuso, cada vila tinha a sua —,
## então o sol culmina ao meio-dia. No hemisfério sul, fora do verão, ele passa ao norte.
const DIA_DO_ANO := 270
var latitude := -12.8123


func definir_latitude(graus: float) -> void:
	latitude = graus


func _declinacao() -> float:
	return deg_to_rad(-23.44) * cos(TAU / 365.0 * (DIA_DO_ANO + 10))


## Elevação do sol em graus acima do horizonte (negativa à noite).
func elevacao_solar() -> float:
	var fi := deg_to_rad(latitude)
	var delta := _declinacao()
	var angulo_horario := deg_to_rad(15.0 * (hora - 12.0))
	return rad_to_deg(asin(sin(fi) * sin(delta) + cos(fi) * cos(delta) * cos(angulo_horario)))


## Azimute do sol em graus a partir do norte, no sentido do leste (90 = leste).
func azimute_solar() -> float:
	var fi := deg_to_rad(latitude)
	var delta := _declinacao()
	var angulo_horario := deg_to_rad(15.0 * (hora - 12.0))
	return fposmod(rad_to_deg(atan2(-cos(delta) * sin(angulo_horario), sin(delta) * cos(fi) - cos(delta) * sin(fi) * cos(angulo_horario))), 360.0)


## Direção em que a luz do sol viaja no mundo (x leste, z sul, y para cima).
func direcao_da_luz_solar() -> Vector3:
	var elevacao := deg_to_rad(elevacao_solar())
	var azimute := deg_to_rad(azimute_solar())
	var para_o_sol := Vector3(sin(azimute) * cos(elevacao), sin(elevacao), -cos(azimute) * cos(elevacao))
	return -para_o_sol.normalized()


func texto_hora() -> String:
	var h := int(hora)
	var m := int((hora - h) * 60.0)
	return "%02d:%02d" % [h, m]


func _atualizar_periodo() -> void:
	var atual := periodo()
	if atual != _periodo:
		_periodo = atual
		periodo_mudou.emit(atual)
