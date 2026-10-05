extends Node
## Relógio do vale: hora do dia contínua (0–24), velocidade da passagem do tempo e
## as curvas de sol, céu e luz que o cenário consome. Independente dos saves do 2D.

signal hora_mudou(hora: float)
signal periodo_mudou(periodo: String)
## PASSOU DAS DUAS SEM DORMIR (#50). O dia do 2D vai das 6h às 2h
## (`Relogio.HORA_LIMITE`, 26): quem não deitou até lá desmaia de cansaço e
## acorda em casa (`queda.gd`). Avisa só quando o relógio ANDA por cima das
## duas — o tempo correndo, ou a tecla de adiantar —, e não quando alguém põe a
## hora lá de uma vez: carregar uma partida das três, ou começar o vale de
## madrugada pela hora inicial do AJUSTAR, não é passar a noite acordado.
signal passou_das_duas

## A hora do desmaio: o `Relogio.HORA_LIMITE` do 2D, contado da meia-noite.
const HORA_DO_DESMAIO := 2.0

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
##
## "PARADA" CONTINUA NA ESCOLHA DO AJUSTAR, com o aviso. "Pode manter a
## possibilidade de alterar o relógio, desde que tenha o aviso, a confirmação e
## a alteração no backlog do save." Parar o relógio desliga as conquistas da
## partida: escolher "Parada" pergunta antes (`aviso_de_parar`), marca a
## partida (`relogio_alterado`) e vai para o registro do relógio, no save. A
## roda do menu do Esc gira só entre as que correm.
const VELOCIDADES := [0.0, 90.0, 30.0, 10.0]
const ROTULOS_VELOCIDADE := ["Parada", "Lenta", "Normal", "Rápida"]
const PARADA := 0
## A primeira das que correm: a roda do menu do Esc começa nela.
const PRIMEIRA_VELOCIDADE := 1
const VELOCIDADE_PADRAO := 2
## Quantas mudanças o registro do relógio guarda. A primeira fica sempre: é a
## que diz quando a partida deixou de contar conquista.
const LIMITE_DO_REGISTRO := 300
## Nascer e pôr do sol em Bom Jesus no fim de setembro (latitude -12,8°, hora solar).
const NASCER := 5.95
const POR := 18.0
## Hora em que o menu abre: o começo do dia.
const INICIO_DO_DIA := 6.5

var hora: float = 9.0
## Horas efetivamente transcorridas no relógio do jogo, inclusive após a meia-noite.
## `hora` sozinha volta a zero e não serve para esperas de 24 horas.
var horas_decorridas: float = 0.0
## Começa em "Normal" (2), e não em "Rápida": ver `VELOCIDADES`.
var velocidade: int = VELOCIDADE_PADRAO
## Hora em que o jogo começa (AJUSTAR → Cenário e tempo).
var hora_inicial: float = 7.0
## Congela a passagem do tempo (o menu controla o próprio relógio).
var pausado := false
## Se o jogador pode pausar o relógio no meio da partida (AJUSTAR → "Pausar o
## relógio no jogo"). Vem permitido: a pausa já pergunta antes e avisa das
## conquistas; quem não quer nem a possibilidade, bloqueia. Bloqueado só impede
## PARAR — religar um relógio parado sempre se pode, que foi o defeito do
## playtest de 02/10 ("o relógio parado no MENU não tá funcionando para voltar
## a fazer o tempo correr").
var pausa_no_jogo := true
## O REGISTRO DO RELÓGIO: cada mudança que o jogador fez nele nesta partida —
## parar, religar, adiantar a hora, trocar a velocidade, começar parada —, com
## o dia e a hora do jogo em que foi feita. Vai no save, como a marca
## `relogio_alterado`: a marca diz SE a partida deixou de contar conquista; o
## registro diz quando e como. Cada entrada: {dia, hora, o_que, de}.
var registro_do_relogio: Array = []
## O JOGADOR PAROU O RELÓGIO NESTA PARTIDA, e daí em diante ela não conta
## conquista.
##
## "Por padrão o relógio deve estar funcionando e se o jogador tentar
## desabilitar o relógio, deve informar que isso fará ele perder as conquistas
## dali para frente. Para isso é importante ter algum campo no save para
## indicar se o jogador mexeu nessa configuração."
##
## É da PARTIDA, e não preferência: vai no save pela mão do vale
## (`estado_para_salvar`), zera numa partida nova e não volta a ser falso
## religando o relógio — "dali para frente" é isso. Quem um dia der conquista
## pergunta a `conquistas_valem`.
var relogio_alterado := false
## Segura o relógio enquanto o vale do jogo se monta: o jogador chega exatamente na
## hora_inicial, a mesma que escolheu a capa (dia ou noite) da tela de carregamento.
## Separado de `pausado`, que é a escolha do jogador e aparece no HUD.
var congelado_na_carga := false
## O RELÓGIO SEGURADO PELA CONVERSA, pelo motivo de cada um.
##
## "O relógio deve parar quando o jogador estiver em uma interação de conversa
## com o NPC ou instruções nativas do jogo." A caixa de fala já parava o vale
## inteiro (`prototype._ao_abrir_a_fala`); o que corria era o resto: a fala da
## missão e a resposta do E no balão (`npc.narrar`, `npc.conversar`), a
## narração do vale e a festa da missão cumprida. Cada um segura com o seu
## motivo e solta o seu — dois ao mesmo tempo não se soltam um ao outro.
##
## NÃO É O RELÓGIO PARADO: `pausado` é escolha do jogador, custa as conquistas e
## vai para o registro do relógio; isto é o tempo de ler, e não custa nada nem
## vai para o save.
var _segurado_por: Dictionary = {}
var _periodo := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var preferencias := ConfigFile.new()
	if preferencias.load(ARQUIVO) == OK:
		velocidade = int(preferencias.get_value("dia", "velocidade", VELOCIDADE_PADRAO))
		if velocidade < 0 or velocidade >= VELOCIDADES.size():
			velocidade = VELOCIDADE_PADRAO
		hora_inicial = fmod(float(preferencias.get_value("dia", "hora_inicial", 7.0)), 24.0)
		pausa_no_jogo = bool(preferencias.get_value("dia", "pausa_no_jogo", true))
		hora = hora_inicial
	_atualizar_periodo()


func _process(delta: float) -> void:
	var segundos_por_hora: float = VELOCIDADES[velocidade]
	if pausado or congelado_na_carga or segurado() or segundos_por_hora <= 0.0:
		return
	avancar(delta / segundos_por_hora)


## Segura o relógio por `motivo` (ver `_segurado_por`). COM PRAZO, em segundos
## de relógio de parede, ele se solta sozinho: o balão de quem fala tem duração
## certa, e um balão que nunca avisasse o fim não pode parar o dia para sempre.
## Sem prazo (zero), vale até o `soltar`.
func segurar(motivo: String, prazo: float = 0.0) -> void:
	_segurado_por[motivo] = Time.get_ticks_msec() + int(prazo * 1000.0) if prazo > 0.0 else 0


func soltar(motivo: String) -> void:
	_segurado_por.erase(motivo)


## Alguém segura o relógio agora? Com `prefixo`, só os motivos que começam por
## ele ("fala:" é a conversa de qualquer morador).
func segurado(prefixo: String = "") -> bool:
	var agora := Time.get_ticks_msec()
	var achou := false
	for motivo: String in _segurado_por.keys():
		var prazo := int(_segurado_por[motivo])
		if prazo > 0 and prazo <= agora:
			_segurado_por.erase(motivo)
		elif prefixo == "" or motivo.begins_with(prefixo):
			achou = true
	return achou


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
## No vale é igual: a cama da casa herdada, a queda e o desmaio das duas
## (`passou_das_duas`) viram a noite pela `queda.gd`, que chama
## `Relogio.dormir()` e escreve a hora de acordar.
func _espelhar_no_calendario() -> void:
	var calendario := get_node_or_null("/root/Relogio")
	if calendario == null:
		return
	calendario.pausado = true
	calendario.minutos = hora * 60.0


func avancar(horas: float) -> void:
	var antes := hora
	if horas > 0.0:
		horas_decorridas += horas
	definir_hora(hora + horas)
	if horas > 0.0 and cruza(antes, horas, HORA_DO_DESMAIO):
		passou_das_duas.emit()


## Andar `horas` a partir de `antes` passa por cima da hora `marca` (de
## qualquer dia)? A próxima `marca` depois de `antes` cai antes de chegar?
static func cruza(antes: float, horas: float, marca: float) -> bool:
	var proxima := marca + 24.0 * ceilf((antes - marca) / 24.0 + 0.000001)
	return proxima <= antes + horas


## Toda troca entra no registro do relógio, e "Parada" marca a partida — quem a
## escolhe na tela já confirmou o `aviso_de_parar`.
func definir_velocidade(indice: int) -> void:
	var nova := clampi(indice, 0, VELOCIDADES.size() - 1)
	if nova != velocidade:
		registrar_no_relogio("velocidade", ROTULOS_VELOCIDADE[nova])
	velocidade = nova
	if velocidade == PARADA:
		marcar_relogio_alterado()
	var preferencias := ConfigFile.new()
	preferencias.load(ARQUIVO)
	preferencias.set_value("dia", "velocidade", velocidade)
	preferencias.save(ARQUIVO)


## A velocidade seguinte na roda Lenta → Normal → Rápida → Lenta, a do menu do
## Esc. De "Parada", a roda religa em "Normal".
func proxima_velocidade() -> int:
	if velocidade < PRIMEIRA_VELOCIDADE:
		return VELOCIDADE_PADRAO
	var escolhas := VELOCIDADES.size() - PRIMEIRA_VELOCIDADE
	return PRIMEIRA_VELOCIDADE + (velocidade - PRIMEIRA_VELOCIDADE + 1) % escolhas


## Marca a partida: o jogador parou o relógio. Não há volta (ver `relogio_alterado`).
func marcar_relogio_alterado() -> void:
	relogio_alterado = true


## A partida ainda conta conquista?
func conquistas_valem() -> bool:
	return not relogio_alterado


func definir_pausa_no_jogo(permitir: bool) -> void:
	pausa_no_jogo = permitir
	var preferencias := ConfigFile.new()
	preferencias.load(ARQUIVO)
	preferencias.set_value("dia", "pausa_no_jogo", pausa_no_jogo)
	preferencias.save(ARQUIVO)


## PARTIDA NOVA: a marca e o registro zeram, e o relógio corre. Quem carrega
## uma partida salva os põe de volta depois (`restaurar_do_save` do vale).
func zerar_a_partida() -> void:
	relogio_alterado = false
	registro_do_relogio = []
	pausado = false
	_segurado_por.clear()


## Escreve uma mudança no registro do relógio (ver `registro_do_relogio`).
## `o_que`: "parou", "voltou", "adiantou", "velocidade" ou "comecou_parada";
## `de`: de onde veio ("menu", "ajustar", "tecla"), ou a velocidade nova.
func registrar_no_relogio(o_que: String, de: String = "") -> void:
	var calendario := get_node_or_null("/root/Relogio")
	registro_do_relogio.append({
		"dia": calendario.dia_absoluto() if calendario != null else 0,
		"hora": texto_hora(),
		"o_que": o_que,
		"de": de,
	})
	if registro_do_relogio.size() > LIMITE_DO_REGISTRO:
		registro_do_relogio.remove_at(1)


## O AVISO ANTES DE PARAR O RELÓGIO, igual em toda porta que o para (a linha
## "Relógio" do Esc, o "Parada" do AJUSTAR): {titulo, texto, nao, sim} para a
## caixa de pergunta, ou {} quando a partida já não conta conquista — aí não há
## mais o que perder, e perguntar de novo só atrapalharia. `sempre` pergunta
## mesmo assim: no menu inicial a marca é a da partida que acabou.
func aviso_de_parar(sempre: bool = false) -> Dictionary:
	if relogio_alterado and not sempre:
		return {}
	return {
		"titulo": tr("Parar o relógio?"),
		"texto": "%s %s" % [tr("Com o relógio parado, esta partida perde as conquistas daqui para frente — mesmo que você volte a ligá-lo depois."),
			tr("A mudança fica no registro do relógio, no save.")],
		"nao": tr("DEIXAR CORRER"),
		"sim": tr("PARAR O RELÓGIO"),
	}


## O AVISO ANTES DE ADIANTAR A HORA (a tecla "Avançar a hora"): pular o tempo
## também é mexer no relógio. Mesma regra do `aviso_de_parar`.
func aviso_de_adiantar() -> Dictionary:
	if relogio_alterado:
		return {}
	return {
		"titulo": tr("Adiantar o relógio?"),
		"texto": "%s %s" % [tr("Pular uma hora tira as conquistas desta partida daqui para frente."),
			tr("A mudança fica no registro do relógio, no save.")],
		"nao": tr("DEIXAR COMO ESTÁ"),
		"sim": tr("ADIANTAR UMA HORA"),
	}


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
