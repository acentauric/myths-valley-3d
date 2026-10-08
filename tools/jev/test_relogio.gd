extends "res://tools/jev/sessao.gd"
## #192: o vigia registra o relógio parado sem tela, fala ou motivo à vista — uma vez
## por parada —, ignora o que parou de propósito e rearma quando o dia volta a andar;
## e o catálogo e o menu de pausa não deixam o testador mexer no tempo.
class FalsoDia extends RefCounted:
	var hora := 6.0
	var pausado := false
	var velocidade := 2
	var congelado_na_carga := false
	var motivos: Array = []

	func segurado() -> bool:
		return not motivos.is_empty()

	func motivos_da_segurada() -> Array:
		return motivos


class Cena extends Node3D:
	var carga_ok := true


var dia_falso := FalsoDia.new()
var agora_falso := 0
var modal_falso := false
var registrados: PackedStringArray = []


func _initialize() -> void:
	_conferir_relogio.call_deferred()


func _dia():
	return dia_falso


func _agora() -> int:
	return agora_falso


func _no_vale() -> bool:
	return true


func _ha_modal() -> bool:
	return modal_falso


func _registrar_relogio_parado(motivo: String) -> void:
	registrados.append(motivo)


func _atualizar_painel() -> void:
	pass


func _lista() -> String:
	return ",".join(registrados)


func _passar(segundos: float, andando: bool) -> void:
	# Um quadro por segundo de jogo: a hora anda junto, ou fica onde está.
	for i in int(segundos):
		agora_falso += 1000
		if andando:
			dia_falso.hora += 1.0 / 30.0
		_vigiar_o_relogio()


func _conferir_relogio() -> void:
	var cena := Cena.new()
	root.add_child(cena)
	current_scene = cena
	inicio_jogo = 0
	var falhas := 0

	_passar(30.0, true)
	if not registrados.is_empty():
		push_error("Relógio andando não pode gerar achado: %s" % _lista())
		falhas += 1

	# O jogador (ou o robô, por engano) pausa o relógio: um achado só, depois da tolerância.
	dia_falso.pausado = true
	_passar(1.0, false)
	if not registrados.is_empty():
		push_error("A pausa dura menos que a tolerância e ainda não é achado")
		falhas += 1
	_passar(60.0, false)
	if _lista() != "pausado":
		push_error("Pausa sem tela aberta precisa virar UM achado 'pausado': %s" % _lista())
		falhas += 1

	# Voltou a andar: rearma. Com uma tela aberta, parar é de propósito.
	dia_falso.pausado = false
	_passar(5.0, true)
	modal_falso = true
	dia_falso.pausado = true
	_passar(60.0, false)
	if registrados.size() != 1:
		push_error("Relógio parado atrás de uma tela não é achado: %s" % _lista())
		falhas += 1
	modal_falso = false
	dia_falso.pausado = false
	_passar(5.0, true)

	# Velocidade em Parada, sem tela.
	dia_falso.velocidade = 0
	_passar(5.0, false)
	if _lista() != "pausado,velocidade_zero":
		push_error("Velocidade parada sem tela precisa virar achado: %s" % _lista())
		falhas += 1
	dia_falso.velocidade = 2
	_passar(5.0, true)

	# A hora não anda e nada explica: só depois de 20 s de jogo.
	_passar(15.0, false)
	if registrados.size() != 2:
		push_error("Quinze segundos sem andar ainda não são achado: %s" % _lista())
		falhas += 1
	_passar(10.0, false)
	if registrados[registrados.size() - 1] != "hora_parada":
		push_error("Hora parada por mais de vinte segundos precisa virar achado: %s" % _lista())
		falhas += 1
	_passar(5.0, true)

	# Segurado por uma fala: de propósito, até passar de 45 s.
	dia_falso.motivos = ["narracao"]
	_passar(40.0, false)
	var antes := registrados.size()
	_passar(10.0, false)
	if registrados.size() != antes + 1 or registrados[registrados.size() - 1] != "segurado":
		push_error("Segurada longa sem tela precisa virar achado 'segurado': %s" % _lista())
		falhas += 1

	# O catálogo e a execução não aceitam controle de tempo.
	for acao in ["inspect_time", "clock_toggle", "speed_next", "time_advance"]:
		if not _acao_do_relogio(acao):
			push_error("A ação %s mexe no relógio e precisa estar bloqueada" % acao)
			falhas += 1
	if _acao_do_relogio("inspect_journal") or _acao_do_relogio("wait"):
		push_error("Ações comuns não podem ser bloqueadas como relógio")
		falhas += 1
	var resultado: String = await _executar("inspect_time")
	if resultado != "clock_control_not_allowed":
		push_error("Executar o controle do relógio precisa ser recusado: %s" % resultado)
		falhas += 1
	var botao := Button.new()
	botao.name = "BotaoDoRelogio"
	cena.add_child(botao)
	var outro := Button.new()
	outro.name = "Jogar"
	cena.add_child(outro)
	if not _e_controle_do_relogio(botao) or _e_controle_do_relogio(outro):
		push_error("O botão do relógio é bloqueado pelo nome; os outros seguem livres")
		falhas += 1

	print("AUTOPLAYER_RELOGIO: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
