extends Node
## AS COPAS NA FRENTE DO VIAJANTE (#201): a folhagem fina da palmeira (e das copas em geral)
## passa entre os raios da `camera_do_teste.gd`, e o viajante ficava coberto pelas folhas.
## Aqui a copa é tratada como oclusora pelo volume: se o trecho da câmera ao peito ou à cabeça
## do viajante atravessa a caixa de uma malha de árvore por perto, a malha é esmaecida (como
## o `obstaculos_camera.gd` do jogo faz com a árvore que encobre o corpo) e volta ao normal
## quando sai da frente. Só existe na sessão de teste; o jogo comum não muda.

const GRUPO := "obstaculos_visuais_da_camera"
const ALTURA_DO_PEITO := 1.1
const ALTURA_DA_CABECA := 1.65
const ESMAECIDA := 0.82
const RITMO := 4.0
const SONDA_A_CADA_S := 0.12
## A caixa da malha encolhe um pouco: a copa de palmeira é uma estrela, e a quina vazia não esconde.
const ENCOLHE := 0.12

var jogador: Node3D
var _sonda_s := 0.0
## id da malha -> {"no": weakref, "antes": float, "frente": bool}
var _malhas: Dictionary = {}


func _process(delta: float) -> void:
	if jogador == null or not is_instance_valid(jogador) or not jogador.is_inside_tree():
		return
	_sonda_s -= delta
	if _sonda_s <= 0.0:
		_sonda_s = SONDA_A_CADA_S
		_sondar()
	for id in _malhas.keys():
		var entrada: Dictionary = _malhas[id]
		var malha = entrada["no"].get_ref()
		if not is_instance_valid(malha):
			_malhas.erase(id)
			continue
		var antes: float = entrada["antes"]
		var alvo := maxf(antes, ESMAECIDA) if bool(entrada["frente"]) else antes
		malha.transparency = move_toward(malha.transparency, alvo, delta * RITMO)
		if not bool(entrada["frente"]) and is_equal_approx(malha.transparency, antes):
			_malhas.erase(id)


func _sondar() -> void:
	var camera: Camera3D = jogador.get_viewport().get_camera_3d()
	for id in _malhas:
		_malhas[id]["frente"] = false
	if camera == null or bool(jogador.get("_de_cima")):
		return
	var de := camera.global_position
	var pontos := [jogador.global_position + Vector3.UP * ALTURA_DO_PEITO, jogador.global_position + Vector3.UP * ALTURA_DA_CABECA]
	var alcance := de.distance_to(jogador.global_position) + 2.0
	for peca in get_tree().get_nodes_in_group(GRUPO):
		if not (peca is Node3D) or not (peca as Node3D).is_visible_in_tree():
			continue
		var limites: AABB = peca.get_meta("limites", AABB())
		var raio := maxf(limites.size.x, limites.size.z) * 0.5 + 1.0
		var centro := (peca as Node3D).global_position
		if Vector2(centro.x - jogador.global_position.x, centro.z - jogador.global_position.z).length() > alcance + raio:
			continue
		for malha in peca.find_children("*", "MeshInstance3D", true, false):
			var m := malha as MeshInstance3D
			if m.mesh == null or not m.is_visible_in_tree():
				continue
			var caixa: AABB = m.global_transform * m.get_aabb()
			caixa = caixa.grow(-minf(caixa.size.x, caixa.size.z) * ENCOLHE)
			var frente := false
			for ponto in pontos:
				if caixa.intersects_segment(de, ponto) or caixa.has_point(de):
					frente = true
					break
			if not frente:
				continue
			var id := m.get_instance_id()
			if not _malhas.has(id):
				_malhas[id] = {"no": weakref(m), "antes": m.transparency, "frente": true}
			else:
				_malhas[id]["frente"] = true


func _exit_tree() -> void:
	for entrada in _malhas.values():
		var malha = entrada["no"].get_ref()
		if is_instance_valid(malha):
			malha.transparency = entrada["antes"]
	_malhas.clear()
