extends Node3D
## O RASTRO DO CURUPIRA: trilhas de pegadas de pé de criança, com os dedos virados PARA TRÁS, na mata
## funda. Saem da borda de uma clareira e entram no mato, longe de rua e de casa (o planejamento está
## em `tools/mapas/planejar_rastro_do_curupira.py`; o jogo só LÊ `data/rastro_do_curupira.json`).
##
## Quem pisa perto de uma pegada da parte funda ouve um assobio fino vindo do fim do rastro — o lado
## para onde o dono delas foi, que é o contrário do que os dedos mostram — e o MAPA enlouquece
## (`loucura_do_mapa.gd`). O achado vai para o caderno como o sinal "Pegadas ao contrário", sem dizer
## de quem são (a regra dos sinais: o nome só entra quando o encontro acontece).
##
## O desenho: uma `MultiMesh` por trilha, com quads de alfa deitados no chão, na inclinação do terreno
## (`ground_height_at` e, quando a física já responde, o raio contra o chão de verdade). Pegada que cairia
## DENTRO de um tronco não é desenhada: um buraco no rastro é mato, e não defeito.

const MataFunda = preload("res://scripts/prototipo_3d/mata_funda.gd")
const SustosDaMata = preload("res://scripts/prototipo_3d/sustos_da_mata.gd")

signal achou(id: String, onde: Vector3)
## O sinal foi para o caderno agora (a primeira vez, e só ela).
signal anotou

const ARQUIVO := "res://data/rastro_do_curupira.json"
const SINAL := "pegadas_ao_contrario"
## Pé de criança, grande: 0,26 x 0,58 u (o dobro do pé do personagem) para ser visto de uns 8 u com a câmera
## do jogo, que olha o chão de raspão e achata qualquer marca.
const TAMANHO := Vector2(0.26, 0.58)
## Acima do chão, para o decalque não brigar com a malha do terreno (que tem células de 4 u).
const ACIMA_DO_CHAO := 0.035
## Até onde se está "pisando" no rastro (u), e de quanto em quanto tempo se pergunta (s).
const RAIO_DO_GATILHO := 3.0
const CONSULTA_A_CADA := 0.5
## Pegada a menos disto de um tronco (u, da casca) é dele, e não do chão.
const FOLGA_DO_TRONCO := 0.35
## Cinza de brasa, escuro: de dia lê sobre o capim (o claro sumia nele); à noite brilha frio e de leve — a
## 0,08 já se contam os dedos; a 0,3 a pegada vira um risco branco que parece faixa de rua.
const COR := Color(0.2, 0.17, 0.14, 0.88)
const BRILHO_DA_NOITE := 0.08
const BRILHO_DO_DIA := 0.0
## O assobio vem desta distância do jogador, no rumo do fim do rastro (u).
const DISTANCIA_DO_ASSOBIO := 26.0

## Cada trilha: {"id", "marco": Vector3, "pegadas": Array[Dictionary{pos, normal, yaw, esquerdo, funda, transformacao}],
## "visual": MultiMeshInstance3D, "caixa": AABB}.
var trilhas: Array[Dictionary] = []
var _world
var _jogador
var _loucura
var _livre := Callable()
var _espera := 0.0
var _material: StandardMaterial3D


func configurar(world: Object, jogador: Node3D, loucura: Node, livre: Callable = Callable()) -> void:
	_world = world
	_jogador = jogador
	_loucura = loucura
	_livre = livre
	_montar()


func _process(delta: float) -> void:
	_espera -= delta
	if _espera > 0.0 or _jogador == null or trilhas.is_empty():
		return
	_espera = CONSULTA_A_CADA
	_acender_para_a_hora()
	if not SustosDaMata.ligado() or (_livre.is_valid() and not _livre.call()):
		return
	var onde: Vector3 = _jogador.global_position
	for trilha: Dictionary in trilhas:
		var caixa: AABB = trilha["caixa"]
		if not caixa.grow(RAIO_DO_GATILHO).has_point(onde):
			continue
		for pegada: Dictionary in trilha["pegadas"]:
			if bool(pegada["funda"]) and (pegada["pos"] as Vector3).distance_to(onde) <= RAIO_DO_GATILHO:
				pisou(trilha, onde)
				return


## O jogador pisou no rastro `trilha`: o assobio, a loucura do mapa e o sinal no caderno. Devolve se a
## loucura começou (não começa se ainda está esfriando da última vez, ou se já está louca).
func pisou(trilha: Dictionary, onde: Vector3) -> bool:
	if _loucura == null or not _loucura.iniciar():
		return false
	achou.emit(String(trilha["id"]), onde)
	_assobiar(onde, trilha["marco"])
	_anotar_o_sinal()
	return true


func _assobiar(de: Vector3, marco: Vector3) -> void:
	var rumo := Vector3(marco.x - de.x, 0.0, marco.z - de.z)
	var longe := minf(rumo.length(), DISTANCIA_DO_ASSOBIO)
	var onde := de + (rumo.normalized() if rumo.length() > 0.01 else Vector3.FORWARD) * longe + Vector3(0.0, 2.2, 0.0)
	SustosDaMata.tocar_3d(self, "curupira_assobio", onde, 110.0, 14.0)


func _anotar_o_sinal() -> void:
	var colecao := get_node_or_null("/root/Colecao")
	if colecao != null and colecao.achar("sinais", SINAL):
		anotou.emit()


## À noite as pegadas brilham de leve (frio, para serem achadas no escuro); de dia quase não.
func _acender_para_a_hora() -> void:
	if _material == null:
		return
	var escuro := 1.0 - clampf(float(Dia.luz_do_dia()), 0.0, 1.0)
	_material.emission_energy_multiplier = lerpf(BRILHO_DO_DIA, BRILHO_DA_NOITE, escuro)


func _montar() -> void:
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
	if not (dados is Dictionary):
		push_warning("Rastro do Curupira: arquivo inválido " + ARQUIVO)
		return
	var textura := _desenhar_a_pegada()
	var malha := QuadMesh.new()
	malha.size = TAMANHO
	malha.orientation = PlaneMesh.FACE_Y
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_texture = textura
	_material.albedo_color = COR
	_material.roughness = 1.0
	_material.metallic_specular = 0.0
	_material.emission_enabled = true
	_material.emission = Color(0.52, 0.66, 0.6)
	_material.emission_texture = textura
	_material.emission_energy_multiplier = BRILHO_DO_DIA
	_material.render_priority = 2
	for item: Dictionary in (dados as Dictionary).get("trilhas", []):
		var pegadas: Array[Dictionary] = []
		for p: Array in item["pegadas"]:
			var plano := Vector2(float(p[0]), float(p[1]))
			if float(MataFunda.tronco_mais_perto(_world, plano)["distancia"]) < FOLGA_DO_TRONCO:
				continue
			var chao := _chao(plano)
			pegadas.append({"pos": chao["pos"], "normal": chao["normal"], "yaw": float(p[2]),
				"esquerdo": int(p[3]) == 1, "funda": int(p[4]) == 1})
		if pegadas.is_empty():
			continue
		var visual := MultiMeshInstance3D.new()
		visual.name = String(item["id"])
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = malha
		multi.instance_count = pegadas.size()
		var caixa := AABB(pegadas[0]["pos"], Vector3.ZERO)
		for i in range(pegadas.size()):
			var pegada: Dictionary = pegadas[i]
			# A transformação fica no dado também: sem tela o MultiMesh não devolve o que recebeu.
			pegada["transformacao"] = _transformacao(pegada)
			multi.set_instance_transform(i, pegada["transformacao"])
			caixa = caixa.expand(pegada["pos"])
		visual.multimesh = multi
		visual.material_override = _material
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(visual)
		var marco: Array = item["marco"]
		trilhas.append({"id": String(item["id"]), "marco": Vector3(float(marco[0]), 0.0, float(marco[1])),
			"pegadas": pegadas, "visual": visual, "caixa": caixa})


## A transformação de uma pegada: deitada no chão (de normal `normal`), com os dedos para o `yaw` (a
## convenção de `pegadas.gd`: meio giro, porque os dedos ficam no -Z do quad), espelhada no pé esquerdo.
func _transformacao(pegada: Dictionary) -> Transform3D:
	var normal: Vector3 = pegada["normal"]
	var base := Basis(Quaternion(Vector3.UP, normal)) * Basis(Vector3.UP, float(pegada["yaw"]) + PI)
	if bool(pegada["esquerdo"]):
		base = base * Basis.from_scale(Vector3(-1.0, 1.0, 1.0))
	return Transform3D(base, (pegada["pos"] as Vector3) + normal * ACIMA_DO_CHAO)


## O chão sob (x, z): a altura do terreno e a inclinação dele, e — se a física já responde — o ponto
## do chão de verdade (só vale perto da conta, para o raio não parar num teto ou numa copa).
func _chao(plano: Vector2) -> Dictionary:
	var altura: float = _world.ground_height_at(Vector3(plano.x, 0.0, plano.y))
	var e := 0.6
	var dx: float = (_world.ground_height_at(Vector3(plano.x + e, 0.0, plano.y)) - _world.ground_height_at(Vector3(plano.x - e, 0.0, plano.y))) / (2.0 * e)
	var dz: float = (_world.ground_height_at(Vector3(plano.x, 0.0, plano.y + e)) - _world.ground_height_at(Vector3(plano.x, 0.0, plano.y - e))) / (2.0 * e)
	var normal := Vector3(-dx, 1.0, -dz).normalized()
	var pos := Vector3(plano.x, altura, plano.y)
	if is_inside_tree():
		var pergunta := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 3.0, pos - Vector3.UP * 3.0, 1)
		var acerto := get_world_3d().direct_space_state.intersect_ray(pergunta)
		if not acerto.is_empty() and absf(float((acerto["position"] as Vector3).y) - altura) < 0.6:
			pos = acerto["position"]
			normal = acerto["normal"]
	return {"pos": pos, "normal": normal}


## A pegada de um pé de criança, uma vez só: sola, arco, calcanhar e cinco dedos, em branco com alfa
## suave (a cor vem do material). Dedos no topo da imagem (v = 0, o -Z do quad FACE_Y).
func _desenhar_a_pegada() -> ImageTexture:
	var imagem := Image.create_empty(32, 48, false, Image.FORMAT_RGBA8)
	for py in 48:
		for px in 32:
			var alfa := 0.0
			alfa = maxf(alfa, _alfa_elipse(px, py, 16.0, 19.0, 9.0, 9.5))
			alfa = maxf(alfa, _alfa_elipse(px, py, 14.5, 29.0, 6.0, 7.5))
			alfa = maxf(alfa, _alfa_elipse(px, py, 15.0, 39.0, 7.0, 7.0))
			alfa = maxf(alfa, _alfa_elipse(px, py, 7.5, 8.0, 3.2, 3.6))
			alfa = maxf(alfa, _alfa_elipse(px, py, 13.0, 5.5, 2.4, 2.6))
			alfa = maxf(alfa, _alfa_elipse(px, py, 18.0, 4.8, 2.2, 2.4))
			alfa = maxf(alfa, _alfa_elipse(px, py, 22.5, 5.5, 2.0, 2.2))
			alfa = maxf(alfa, _alfa_elipse(px, py, 26.0, 7.5, 1.8, 2.0))
			imagem.set_pixel(px, py, Color(1.0, 1.0, 1.0, alfa))
	imagem.generate_mipmaps()
	return ImageTexture.create_from_image(imagem)


func _alfa_elipse(px: int, py: int, cx: float, cy: float, rx: float, ry: float) -> float:
	var dx := (float(px) - cx) / rx
	var dy := (float(py) - cy) / ry
	return clampf((1.0 - sqrt(dx * dx + dy * dy)) * 2.2, 0.0, 1.0)
