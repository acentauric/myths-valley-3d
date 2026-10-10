extends Node
## A chegada apresenta o povoado em pequenos grupos (#155). As missões continuam
## vivas nos moradores fora de cena; somente corpo, animação e voz ficam em repouso.
## Depois de entrar em cena, ninguém desaparece perto do jogador por orçamento.
##
## A INTRODUÇÃO (#155, reaberta em 09/10). No passo 4/16, perto da Dona Candinha, o autor viu três
## cabras e o bode soltos no terreiro, entre os moradores, e 19 FPS (numa segunda captura, 9).
## Até o Pedro entrar com o viajante na casa do tio (passo 7, `FIM_DA_INTRODUCAO`), os bichos de
## casa (cabras, bode, porcos, cães, gatos) e os bandos de aves (galinhas) NÃO entram em cena a
## menos de `INTRODUCAO_LONGE` do jogador e da câmera: ficam nos quintais mais longe do caminho, no
## máximo um bicho e um bando, e o tempo não os amplia. Fora de cena não andam, não animam e não
## colidem (`_definir`). Terminada a introdução, entram aos poucos (`ENTRADA_DOS_BICHOS`,
## `ENTRADA_DOS_BANDOS`), e não de uma vez como os moradores.
const ESSENCIAIS := ["pedro", "tonho", "candinha", "zefa"]
const RAIO := 65.0
const SAIDA := 85.0
const INTERVALO := 45.0
## O passo do Pedro (`missao`) em que a introdução termina: depois da entrada na casa herdada.
const FIM_DA_INTRODUCAO := 6
## Na introdução, quanto (u) um bicho ou bando tem de estar longe do jogador e da câmera para entrar,
## e quantos de cada podem estar em cena ao mesmo tempo.
const INTRODUCAO_LONGE := 40.0
const INTRODUCAO_BICHOS := 1
const INTRODUCAO_BANDOS := 1
## Depois da introdução: os bichos de casa começam em dois e ganham mais um a cada tanto (s); os
## bandos começam em um e ganham mais um a cada tanto.
const BICHOS_AO_ACABAR := 2
const ENTRADA_DOS_BICHOS := 12.0
const BANDOS_AO_ACABAR := 1
const ENTRADA_DOS_BANDOS := 20.0
var segundos := 0.0
var _vale: Node
var _conferir := 0.0
var _vistos: Dictionary = {}
var _ocultos: Dictionary = {}
var _todos_liberados := false
## Quando (no relógio `segundos`) a introdução acabou: INF enquanto ela dura; -INF se o vale já abriu
## depois dela (um save), caso em que nada entra aos poucos: o povoado já se conhece.
var _fim_da_introducao := INF
var _viu_a_introducao := false

func configurar(vale: Node) -> void:
	_vale = vale
	atualizar()

func _process(delta: float) -> void:
	segundos += delta
	_conferir -= delta
	if _conferir <= 0.0:
		_conferir = 0.5
		atualizar()

func atualizar() -> void:
	if _vale == null or _vale.player == null:
		return
	if _todos_liberados:
		_liberar_presencas()
		return
	var fase := int(segundos / INTERVALO)
	if not em_introducao():
		fase = 20
	_marcar_o_fim_da_introducao()
	_escolher(get_tree().get_nodes_in_group("moradores"), 2 + fase * 2, true)
	if em_introducao():
		_escolher(get_tree().get_nodes_in_group("bichos_de_casa"), INTRODUCAO_BICHOS, false, INTRODUCAO_LONGE)
		_escolher(get_tree().get_nodes_in_group("bandos_de_chao"), INTRODUCAO_BANDOS, false, INTRODUCAO_LONGE)
	else:
		var depois := minf(segundos - _fim_da_introducao, 100000.0)
		_escolher(get_tree().get_nodes_in_group("bichos_de_casa"), BICHOS_AO_ACABAR + int(depois / ENTRADA_DOS_BICHOS), false)
		_escolher(get_tree().get_nodes_in_group("bandos_de_chao"), BANDOS_AO_ACABAR + int(depois / ENTRADA_DOS_BANDOS), false)


## A introdução da chegada dura até o Pedro entrar com o viajante na casa do tio. Sem Pedro ainda
## (o vale se monta), ela dura.
func em_introducao() -> bool:
	return _vale == null or _vale.pedro == null or int(_vale.pedro.missao) < FIM_DA_INTRODUCAO


## Anota quando a introdução acabou: agora, se a vimos acabar; -INF se o vale já abriu depois dela.
func _marcar_o_fim_da_introducao() -> void:
	var com_pedro: bool = _vale != null and _vale.pedro != null
	if em_introducao():
		_viu_a_introducao = _viu_a_introducao or com_pedro
		_fim_da_introducao = INF
	elif is_inf(_fim_da_introducao) and _fim_da_introducao > 0.0:
		_fim_da_introducao = segundos if _viu_a_introducao else -INF

func _escolher(atores: Array[Node], limite: int, moradores: bool, afastar: float = 0.0) -> void:
	var jogador: Vector3 = _vale.player.global_position
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var olho: Vector3 = camera.global_position if camera != null else jogador
	# Bichos e bandos que já estão em cena contam primeiro no limite: medidos só pela distância, os
	# recém-chegados (perto) tomavam as vagas e o bicho da introdução (longe, mas já visto) ficava
	# por cima delas, e ao acabar a introdução entravam três em vez de dois (#155).
	atores.sort_custom(func(a, b):
		if not moradores:
			var a_visto := _vistos.has(a.get_instance_id())
			if a_visto != _vistos.has(b.get_instance_id()):
				return a_visto
		return onde_esta(a).distance_squared_to(jogador) < onde_esta(b).distance_squared_to(jogador))
	var apresentados := 0
	for ator in atores:
		var visita := ator.has_meta("presenca_do_calendario")
		if visita and not bool(ator.get_meta("presenca_do_calendario")):
			if not _ocultos.has(ator.get_instance_id()):
				_definir(ator, false, false)
			continue
		var essencial := visita
		if moradores:
			essencial = essencial or str(ator.dados.get("id", "")) in ESSENCIAIS or ator.falando_agora()
			for filho in ator.get_children():
				if filho.get_script() == load("res://scripts/prototipo_3d/cadeia_de_missoes.gd") and filho.iniciado and filho.missao < filho.passos.size():
					essencial = true
		var id := ator.get_instance_id()
		var distancia: float = onde_esta(ator).distance_to(jogador)
		var conhecido := _vistos.has(id)
		# Quem já entrou em cena só sai quando a câmera TAMBÉM está longe: o fade das
		# malhas (80 a 84 u) é medido dela, e com a câmera girada para a frente ou
		# afastada ela chega a 25 u mais perto do ator que o jogador (#193).
		if conhecido:
			distancia = minf(distancia, onde_esta(ator).distance_to(olho))
		var perto := distancia < (SAIDA + alcance_do_ator(ator) if conhecido else RAIO)
		# Na introdução quem ainda não entrou só entra longe do jogador e da câmera (`afastar`).
		var longe_o_bastante := afastar <= 0.0 or minf(distancia, onde_esta(ator).distance_to(olho)) >= afastar
		var mostrar := essencial or (perto and (conhecido or (apresentados < limite and longe_o_bastante)))
		if mostrar and not essencial:
			apresentados += 1
		if mostrar and not conhecido:
			_vistos[id] = true
			_definir(ator, true, not essencial)
		elif mostrar and _ocultos.has(id):
			_definir(ator, true, true)
		elif not mostrar and not _ocultos.has(id):
			_definir(ator, false, false)

## Quanto (u) o ator se estende além do centro. O ator só some de vez depois que a
## parte mais próxima dele já saiu do fade da malha (80 a 84 u): o bando conta o raio do
## terreiro e a folga do voo, o bicho a folga do corpo (#193).
const FOLGA_DO_CORPO := 2.0


static func alcance_do_ator(ator: Node3D) -> float:
	if not (ator.get("centro") is Vector3):
		return FOLGA_DO_CORPO
	return float(ator.get("raio")) + 6.0


## Onde o ator está de verdade. O bando de aves é um nó parado na origem do vale
## (as aves andam, cada uma com a sua posição): quem mede pelo nó acha que todo
## bando mora no (0, 0, 0) e o faz entrar e sair de cena conforme o jogador passa
## a 65 e 85 m da origem, longe do terreiro. O bando diz o centro dele (#193).
static func onde_esta(ator: Node3D) -> Vector3:
	var centro = ator.get("centro")
	return centro if centro is Vector3 else ator.global_position

func _definir(ator: Node3D, sim: bool, suave: bool) -> void:
	var id := ator.get_instance_id()
	ator.set_meta("presenca_liberada", sim)
	ator.set_physics_process(sim)
	ator.set_process(sim)
	if ator is CollisionObject3D:
		if not ator.has_meta("camada_presenca"):
			var camada: int = ator.collision_layer
			if ator.has_method("esta_recolhido") and ator.esta_recolhido():
				camada = ator._camadas_de_fora.x
			ator.set_meta("camada_presenca", camada)
		var dentro: bool = ator.has_method("esta_recolhido") and ator.esta_recolhido()
		ator.collision_layer = int(ator.get_meta("camada_presenca")) if sim and not dentro else 0
	if not sim:
		_ocultos[id] = weakref(ator)
		ator.hide()
		if ator.has_method("_calar_a_boca"):
			ator._calar_a_boca()
	else:
		_ocultos.erase(id)
		if not ator.has_method("esta_recolhido") or not ator.esta_recolhido():
			ator.show()
	# Desliga também AnimationPlayer/Skeleton3D, sem desligar as cadeias de missão.
	for filho in ator.get_children():
		if filho is Node3D or filho.name == "Animador" or filho.get_script() == load("res://scripts/prototipo_3d/authored_animator.gd"):
			if not filho.has_meta("processo_presenca"):
				filho.set_meta("processo_presenca", filho.process_mode)
			filho.process_mode = int(filho.get_meta("processo_presenca")) if sim else Node.PROCESS_MODE_DISABLED
	if sim and suave:
		var malhas := ator.find_children("*", "GeometryInstance3D", true, false)
		var entrada := create_tween().set_parallel(true)
		for malha in malhas:
			malha.transparency = 1.0
			entrada.tween_property(malha, "transparency", 0.0, 0.8)

func liberar_todos() -> void:
	_todos_liberados = true
	set_process(false)
	_liberar_presencas()

func _liberar_presencas() -> void:
	for grupo in ["moradores", "bichos_de_casa", "bandos_de_chao"]:
		for ator in get_tree().get_nodes_in_group(grupo):
			_definir(ator, bool(ator.get_meta("presenca_do_calendario", true)), false)

func contagem() -> Dictionary:
	var resultado := {}
	for grupo in ["moradores", "bichos_de_casa", "bandos_de_chao"]:
		var ativos := 0
		var todos := get_tree().get_nodes_in_group(grupo)
		for ator in todos:
			if ator.is_physics_processing() or ator.is_processing():
				ativos += 1
		resultado[grupo] = {"ativos": ativos, "total": todos.size()}
	return resultado
