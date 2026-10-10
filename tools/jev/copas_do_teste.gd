extends Node
## AS COPAS NA FRENTE DO VIAJANTE (#201): a folhagem fina da palmeira (e das copas em geral)
## passa entre os raios da `camera_do_teste.gd`, e o viajante ficava coberto pelas folhas.
## Aqui a copa é tratada como oclusora pelo volume: se o trecho da câmera ao peito ou à cabeça
## do viajante atravessa a caixa de uma malha de árvore por perto, a malha é esmaecida (como
## o `obstaculos_camera.gd` do jogo faz com a árvore que encobre o corpo) e volta ao normal
## quando sai da frente. Só existe na sessão de teste; o jogo comum não muda.
##
## AS ÁRVORES EM BLOCO (10/10/2026): a mata, o mangue do rio, a restinga e os coqueiros da orla
## não são peças soltas, mas instâncias de MultiMesh (`geo_region_renderer.gd`), e a malha do
## bloco inteiro não pode esmaecer por uma árvore só. A que fica na frente sai do bloco (a
## instância encolhe a nada) e, no lugar, entra uma cópia avulsa da mesma malha, que esmaece;
## quando sai da frente e volta ao normal, a instância volta e a cópia sai. A instância volta
## com a transformação que o tronco tiver na hora, então árvore cortada ou crescendo não erra.

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
## índice do tronco -> {"copia": MeshInstance3D, "frente": bool, "regiao": Node3D}
var _troncos: Dictionary = {}
var _alvo := Vector3.INF


func _e_o_alvo(pos: Vector3) -> bool:
	return _alvo.is_finite() and Vector2(pos.x - _alvo.x, pos.z - _alvo.z).length() < 1.6


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
	for indice in _troncos.keys():
		var tronco_esmaecido: Dictionary = _troncos[indice]
		var copia: MeshInstance3D = tronco_esmaecido["copia"]
		if not is_instance_valid(copia):
			_devolver(indice)
			continue
		copia.transparency = move_toward(copia.transparency, ESMAECIDA if bool(tronco_esmaecido["frente"]) else 0.0, delta * RITMO)
		if not bool(tronco_esmaecido["frente"]) and is_zero_approx(copia.transparency):
			_devolver(indice)


func _sondar() -> void:
	var camera: Camera3D = jogador.get_viewport().get_camera_3d()
	for id in _malhas:
		_malhas[id]["frente"] = false
	for indice in _troncos:
		_troncos[indice]["frente"] = false
	if camera == null or bool(jogador.get("_de_cima")):
		return
	var de := camera.global_position
	var pontos := [jogador.global_position + Vector3.UP * ALTURA_DO_PEITO, jogador.global_position + Vector3.UP * ALTURA_DA_CABECA]
	# A árvore em que o viajante vai mexer não esmaece: transparente, não se via o que se cortava.
	_alvo = load("res://scripts/prototipo_3d/arvores_info.gd").alvo_em(jogador.get_tree())
	_sondar_os_blocos(de, pontos)
	var alcance := de.distance_to(jogador.global_position) + 2.0
	for peca in get_tree().get_nodes_in_group(GRUPO):
		if not (peca is Node3D) or not (peca as Node3D).is_visible_in_tree():
			continue
		var limites: AABB = peca.get_meta("limites", AABB())
		var raio := maxf(limites.size.x, limites.size.z) * 0.5 + 1.0
		var centro := (peca as Node3D).global_position
		if Vector2(centro.x - jogador.global_position.x, centro.z - jogador.global_position.z).length() > alcance + raio:
			continue
		if _e_o_alvo(centro):
			continue
		for malha in peca.find_children("*", "MeshInstance3D", true, false):
			var m := malha as MeshInstance3D
			if m.mesh == null or not m.is_visible_in_tree():
				continue
			var caixa: AABB = m.global_transform * m.get_aabb()
			caixa = caixa.grow(-minf(caixa.size.x, caixa.size.z) * ENCOLHE)
			var frente := _na_frente(caixa, de, pontos)
			if not frente:
				continue
			var id := m.get_instance_id()
			if not _malhas.has(id):
				_malhas[id] = {"no": weakref(m), "antes": m.transparency, "frente": true}
			else:
				_malhas[id]["frente"] = true


## As árvores de MultiMesh entre a câmera e o viajante, pela grade de troncos da região.
func _sondar_os_blocos(de: Vector3, pontos: Array) -> void:
	var cena := jogador.get_tree().current_scene
	var mundo = cena.get("world") if cena != null else null
	var regiao = mundo.get("_region") if mundo != null else null
	if regiao == null or not (regiao is Node3D):
		return
	regiao._garantir_grade_troncos()
	var celula: float = regiao.CELULA_TRONCOS
	var grade: Dictionary = regiao._grade_troncos
	var troncos: Array = regiao._tree_trunks
	var a: Vector3 = (regiao as Node3D).to_local(de)
	var b: Vector3 = (regiao as Node3D).to_local(jogador.global_position)
	var folga := 6.0
	for cx in range(floori((minf(a.x, b.x) - folga) / celula), floori((maxf(a.x, b.x) + folga) / celula) + 1):
		for cy in range(floori((minf(a.z, b.z) - folga) / celula), floori((maxf(a.z, b.z) + folga) / celula) + 1):
			for i: int in grade.get(Vector2i(cx, cy), []):
				var tronco: Dictionary = troncos[i]
				var visual := tronco.get("visual") as MultiMeshInstance3D
				# Cortada com a cópia na frente: a cópia sai na hora, sem fantasma da árvore inteira.
				if _troncos.has(i) and bool(tronco.get("cortado", false)):
					_devolver(i)
					continue
				if visual == null or int(tronco.get("instancia", -1)) < 0 or not tronco.has("transformacao") or bool(tronco.get("cortado", false)):
					continue
				var pe_do_tronco: Vector3 = (visual.global_transform * (tronco["transformacao"] as Transform3D)).origin
				if _troncos.has(i):
					var caixa_ja: AABB = _caixa_do_tronco(visual, tronco)
					_troncos[i]["frente"] = _na_frente(caixa_ja, de, pontos) and not _e_o_alvo(pe_do_tronco)
					continue
				if _e_o_alvo(pe_do_tronco):
					continue
				if not visual.is_visible_in_tree() or visual.multimesh == null or visual.multimesh.mesh == null:
					continue
				if _na_frente(_caixa_do_tronco(visual, tronco), de, pontos):
					_tirar_do_bloco(i, tronco, regiao)


func _caixa_do_tronco(visual: MultiMeshInstance3D, tronco: Dictionary) -> AABB:
	var caixa: AABB = (visual.global_transform * (tronco["transformacao"] as Transform3D)) * visual.multimesh.mesh.get_aabb()
	return caixa.grow(-minf(caixa.size.x, caixa.size.z) * ENCOLHE)


## A copa está ENTRE a câmera e o viajante? (10/10/2026: debaixo de uma árvore, a câmera ficava dentro
## da caixa da árvore da frente, e a árvore à frente do viajante sumia.) Só conta a copa cujo centro,
## no rumo da câmera ao viajante, fica antes dele.
static func _na_frente(caixa: AABB, de: Vector3, pontos: Array) -> bool:
	if pontos.is_empty():
		return false
	var ate: Vector3 = pontos[0]
	var rumo := Vector2(ate.x - de.x, ate.z - de.z)
	var distancia := rumo.length()
	if distancia > 0.01:
		var centro := caixa.get_center()
		var adiante := Vector2(centro.x - de.x, centro.z - de.z).dot(rumo / distancia)
		if adiante > distancia - 0.3:
			return false
	if caixa.has_point(de):
		return true
	for ponto in pontos:
		if caixa.intersects_segment(de, ponto):
			return true
	return false


## A árvore sai do bloco e entra a cópia avulsa, que vai esmaecer.
func _tirar_do_bloco(indice: int, tronco: Dictionary, regiao: Node3D) -> void:
	var visual := tronco["visual"] as MultiMeshInstance3D
	var transformacao: Transform3D = tronco["transformacao"]
	var copia := MeshInstance3D.new()
	copia.name = "CopaEsmaecidaDoTeste"
	copia.add_to_group("copas_esmaecidas_do_teste")
	copia.mesh = visual.multimesh.mesh
	copia.cast_shadow = visual.cast_shadow
	regiao.add_child(copia)
	copia.global_transform = visual.global_transform * transformacao
	visual.multimesh.set_instance_transform(int(tronco["instancia"]), Transform3D(Basis().scaled(Vector3.ONE * 0.00001), transformacao.origin))
	_troncos[indice] = {"copia": copia, "frente": true, "regiao": regiao}


## A instância volta ao bloco, na transformação que o tronco tiver agora, e a cópia sai.
func _devolver(indice: int) -> void:
	var entrada: Dictionary = _troncos[indice]
	_troncos.erase(indice)
	var regiao = entrada["regiao"]
	if is_instance_valid(regiao) and indice < regiao._tree_trunks.size():
		var tronco: Dictionary = regiao._tree_trunks[indice]
		var visual := tronco.get("visual") as MultiMeshInstance3D
		if is_instance_valid(visual) and tronco.has("transformacao"):
			visual.multimesh.set_instance_transform(int(tronco["instancia"]), tronco["transformacao"])
	var copia = entrada["copia"]
	if is_instance_valid(copia):
		copia.queue_free()


func _exit_tree() -> void:
	for indice in _troncos.keys():
		_devolver(indice)
	for entrada in _malhas.values():
		var malha = entrada["no"].get_ref()
		if is_instance_valid(malha):
			malha.transparency = entrada["antes"]
	_malhas.clear()
