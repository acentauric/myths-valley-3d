extends Node
## Relógio do vale: hora do dia contínua (0–24), velocidade da passagem do tempo e
## as curvas de sol, céu e luz que o cenário consome. Independente dos saves do 2D.

signal hora_mudou(hora: float)
signal periodo_mudou(periodo: String)

const ARQUIVO := "user://preferencias_visuais.cfg"
## Segundos reais por hora do jogo em cada velocidade (Parada, Lenta, Normal, Rápida).
const VELOCIDADES := [0.0, 120.0, 45.0, 10.0]
const ROTULOS_VELOCIDADE := ["Parada", "Lenta", "Normal", "Rápida"]
const NASCER := 5.5
const POR := 18.0
## Hora em que o menu abre: o começo do dia.
const INICIO_DO_DIA := 6.5

var hora: float = 9.0
var velocidade: int = 3
## Hora em que o jogo começa (AJUSTAR → Cenário e tempo).
var hora_inicial: float = 7.0
## Congela a passagem do tempo (o menu controla o próprio relógio).
var pausado := false
## Se o botão de relógio do HUD pode pausar o dia dentro do jogo (AJUSTAR).
var pausa_no_jogo := false
var _periodo := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var preferencias := ConfigFile.new()
	if preferencias.load(ARQUIVO) == OK:
		velocidade = clampi(int(preferencias.get_value("dia", "velocidade", 3)), 0, VELOCIDADES.size() - 1)
		hora_inicial = fmod(float(preferencias.get_value("dia", "hora_inicial", 7.0)), 24.0)
		pausa_no_jogo = bool(preferencias.get_value("dia", "pausa_no_jogo", false))
		hora = hora_inicial
	_atualizar_periodo()


func _process(delta: float) -> void:
	var segundos_por_hora: float = VELOCIDADES[velocidade]
	if pausado or segundos_por_hora <= 0.0:
		return
	definir_hora(hora + delta / segundos_por_hora)


func definir_hora(nova: float) -> void:
	hora = fposmod(nova, 24.0)
	hora_mudou.emit(hora)
	_atualizar_periodo()


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
	return hora < NASCER or hora >= POR + 0.3


## 0 no fundo da noite, 1 ao meio-dia; transição suave no nascer e no pôr.
func luz_do_dia() -> float:
	var alvorada := smoothstep(NASCER - 0.8, NASCER + 1.2, hora)
	var crepusculo := 1.0 - smoothstep(POR - 1.2, POR + 0.8, hora)
	return clampf(minf(alvorada, crepusculo), 0.0, 1.0)


## Elevação do sol em graus (negativa à noite) e azimute girando de leste para oeste.
func elevacao_solar() -> float:
	var fracao := (hora - NASCER) / (POR - NASCER)
	return sin(clampf(fracao, 0.0, 1.0) * PI) * 68.0 - (0.0 if fracao >= 0.0 and fracao <= 1.0 else 18.0)


func azimute_solar() -> float:
	var fracao := clampf((hora - NASCER) / (POR - NASCER), 0.0, 1.0)
	return lerpf(-100.0, 100.0, fracao)


func texto_hora() -> String:
	var h := int(hora)
	var m := int((hora - h) * 60.0)
	return "%02d:%02d" % [h, m]


func _atualizar_periodo() -> void:
	var atual := periodo()
	if atual != _periodo:
		_periodo = atual
		periodo_mudou.emit(atual)
