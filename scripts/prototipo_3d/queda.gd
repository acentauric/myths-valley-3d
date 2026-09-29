extends Node
## VIDA NO CHÃO É NOITE NO CHÃO — a queda do jogo 2D, no vale.
##
## A regra é a do 2D (`Mundo._ao_cair` e `_apagar`): cair não é morrer. Alguém
## traz para casa, o dia vira, e o corpo acorda inteiro — mas acorda, e alguém
## diz o que houve, porque quem caiu no mato não sabe. O `Vida` compartilhado
## avisa (`caiu`) uma vez só por queda; este nó é o que o vale faz com o aviso.
##
## O QUE MUDA DO 2D PARA CÁ é só o lugar e o relógio:
##
## - CASA É A PORTA DA CASA DE TAIPA, e não o chão do quarto. O vale ainda não
##   tem cômodo nenhum (#26); quando tiver, o destino passa a ser ao pé da
##   cama, e é a única linha que muda.
## - A HORA É DO `Dia`, e o calendário é do `Relogio` (ver `dia.gd`). O
##   `Relogio.dormir()` vira o dia e SOLTA o `pausado` dele — no 2D é o que o
##   faz voltar a contar. Aqui quem conta é o `Dia`, então logo depois ele
##   escreve a hora de acordar, e escrever a hora é o que prende o calendário
##   de novo. Na ordem inversa, o calendário andaria sozinho até o próximo
##   quadro, que é o defeito que `tests/calendario.gd` procura.
## - A FALA VAI NO AVISO DO HUD, uma de cada vez: a caixa de fala longa do 2D
##   ainda não chegou (#21), e o balão 3D é para cumprimento de passagem.
##
## O que NÃO muda: a mesma trava de uma noite só (`_virando_a_noite`), o
## `Energia.desmaiar()` e o `Vida.dormir()` — cair é a mesma virada do desmaio
## de cansaço, com outra fala.

const FALAS := "res://data/queda.json"
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
## A dois passos da porta, do lado de fora: longe da parede o bastante para a
## cápsula do jogador não nascer encostada nela.
const DIANTE_DA_PORTA := 2.4
const ESCURECER := 0.9
const CLAREAR := 1.2
## Quanto cada fala fica no aviso antes da próxima.
const POR_FALA := 3.2

signal acordou

var _world
var _player
var _hud
var _virando_a_noite := false
var _preto: ColorRect


func configurar(world, player, hud) -> void:
	_world = world
	_player = player
	_hud = hud
	var tela := CanvasLayer.new()
	tela.name = "TelaDaQueda"
	# Por cima do HUD (camada 20): quem caiu não vê relógio nem barra até acordar.
	tela.layer = 30
	add_child(tela)
	_preto = ColorRect.new()
	_preto.color = Color.BLACK
	_preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preto.modulate.a = 0.0
	_preto.visible = false
	tela.add_child(_preto)
	var vida := get_node_or_null("/root/Vida")
	if vida != null:
		vida.caiu.connect(_ao_cair)


## Onde o jogador acorda: diante da porta da casa herdada, no chão.
func ponto_de_casa() -> Vector3:
	var ancoras: Dictionary = _world.ancoras
	var casa: Vector3 = ancoras.get("Casa de taipa", Vector3.INF)
	if not casa.is_finite():
		return Vector3.INF
	var frente: Vector3 = ancoras.get("Casa de taipaFrente", Vector3.BACK)
	frente.y = 0.0
	frente = frente.normalized() if frente.length_squared() > 0.001 else Vector3.BACK
	return _world.ground_position(casa + frente * (_raio_da_casa() + DIANTE_DA_PORTA), 0.05)


func _raio_da_casa() -> float:
	var spec: Dictionary = CatalogoAssets.PECAS.get("casa_taipa", {})
	return float(spec.get("largura", 6.5)) * 0.5


func _ao_cair() -> void:
	if _virando_a_noite:
		return                      # já há uma noite em curso: esta não conta
	_virando_a_noite = true
	_player.set_physics_process(false)
	_player.set_process_unhandled_input(false)
	_player.velocity = Vector3.ZERO
	if _player.has_method("_cancel_walk"):
		_player._cancel_walk()
	Audio.efeito("dormir")
	_preto.visible = true
	var escurece := create_tween()
	escurece.tween_property(_preto, "modulate:a", 1.0, ESCURECER)
	await escurece.finished

	_levar_para_casa()
	Energia.desmaiar()
	Vida.dormir()
	Relogio.dormir()
	Dia.definir_hora(float(Relogio.HORA_DE_ACORDAR))

	var clareia := create_tween()
	clareia.tween_property(_preto, "modulate:a", 0.0, CLAREAR)
	await clareia.finished
	_preto.visible = false
	_player.set_physics_process(true)
	_player.set_process_unhandled_input(true)
	_virando_a_noite = false
	acordou.emit()
	await _contar_o_que_houve()


func _levar_para_casa() -> void:
	var destino := ponto_de_casa()
	if not destino.is_finite():
		_player.reset_position()
		return
	_player.global_position = destino
	_player.velocity = Vector3.ZERO
	# Terra firme conhecida passa a ser a porta de casa: se a próxima volta à
	# terra (o tubarão, o fundo do mar) vier antes de o jogador pisar em outro
	# chão, ela o traz para cá, e não para onde ele estava antes de cair.
	if "_last_land" in _player:
		_player._last_land = destino


func _contar_o_que_houve() -> void:
	for fala in _falas():
		if not is_inside_tree():
			return
		_hud.set_notice(fala)
		await get_tree().create_timer(POR_FALA).timeout


func _falas() -> Array:
	var dado = JSON.parse_string(FileAccess.get_file_as_string(FALAS))
	if typeof(dado) != TYPE_DICTIONARY:
		push_warning("Queda: arquivo de falas inválido " + FALAS)
		return []
	var falas := []
	for entrada in dado.get("fala", []):
		falas.append(str(IdiomaMenu.campo(entrada, "texto")))
	return falas
