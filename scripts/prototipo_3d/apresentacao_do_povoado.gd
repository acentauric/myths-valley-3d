extends Node
## A chegada apresenta o povoado em pequenos grupos (#155). As missões continuam
## vivas nos moradores fora de cena; somente corpo, animação e voz ficam em repouso.
## Depois de entrar em cena, ninguém desaparece perto do jogador por orçamento.
const ESSENCIAIS := ["pedro", "tonho", "candinha", "zefa"]
const RAIO := 65.0
const SAIDA := 85.0
const INTERVALO := 45.0
var segundos := 0.0
var _vale: Node
var _conferir := 0.0
var _vistos: Dictionary = {}
var _ocultos: Dictionary = {}
var _todos_liberados := false

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
	if _vale.pedro != null and _vale.pedro.missao >= 6:
		fase = 20
	_escolher(get_tree().get_nodes_in_group("moradores"), 2 + fase * 2, true)
	_escolher(get_tree().get_nodes_in_group("bichos_de_casa"), 3 + fase * 2, false)
	_escolher(get_tree().get_nodes_in_group("bandos_de_chao"), 1 + fase, false)

func _escolher(atores: Array[Node], limite: int, moradores: bool) -> void:
	var jogador: Vector3 = _vale.player.global_position
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var olho: Vector3 = camera.global_position if camera != null else jogador
	atores.sort_custom(func(a, b): return onde_esta(a).distance_squared_to(jogador) < onde_esta(b).distance_squared_to(jogador))
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
		var mostrar := essencial or (perto and (conhecido or apresentados < limite))
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
