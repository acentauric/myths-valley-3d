extends SceneTree
## O MAPA DE SOLO é o que o shader do terreno lê para misturar as camadas e o que os
## passos consultam (`surface_at`): terra nas ruas e na praça, areia na costa, lama
## nas margens dos rios, pasto na fazenda, copa sob as árvores e trilhas de pé até
## as casas. Se o mapa sumir, o chão volta a ser um carpete de grama só e o passo
## na lama soa como grama. Ver docs/mundo/SOLO_E_FRANJAS.md.
##
##   Godot --headless --path . --script res://tests/mapa_de_solo.gd
##   ... -- --falsificar-solo     zera o mapa: o portão TEM de reprovar.

const MapaDeSolo = preload("res://scripts/prototipo_3d/mapa_de_solo.gd")
const Camada = MapaDeSolo.Camada

var falhas := 0
var verificacoes := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_verificar(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(4)
	var vale := current_scene
	var mundo = vale.get("world") if vale != null else null
	var regiao = mundo.get("_region") if mundo != null else null
	_verificar(regiao != null, "o vale tem a região do mapa")
	if regiao == null:
		_fechar()
		return
	var solo = regiao.get("solo")
	_verificar(solo != null and solo.pronto(), "a região montou o mapa de solo")
	if solo == null or not solo.pronto():
		_fechar()
		return
	if OS.get_cmdline_user_args().has("--falsificar-solo"):
		print("FALSIFICANDO: o mapa de solo foi zerado de propósito")
		for camada in MapaDeSolo.NOMES.size():
			solo.limpar(camada)
		solo.publicar()

	_a_praca(regiao, solo)
	_a_costa(regiao, solo)
	_o_rio(regiao, solo)
	_a_fazenda(regiao, solo)
	_a_rua(regiao, solo)
	_a_copa(mundo, solo)
	_as_trilhas(mundo, regiao, solo)
	_as_normais(regiao)
	_o_material(regiao)
	_fechar()


## A praça é terra batida: o miolo dela, pelo menos 0,9.
func _a_praca(regiao, solo) -> void:
	var centro: Vector3 = regiao.get_feature_center("Praça", "area")
	var peso: float = solo.peso(Camada.TERRA, Vector2(centro.x, centro.z))
	_verificar(peso >= 0.9, "centro da praça é terra (%.2f, esperado >= 0,9)" % peso)
	_verificar(regiao.surface_at(centro) == "terra", "o passo na praça é de terra (%s)" % regiao.surface_at(centro))


## A 2 u da costa, para dentro da terra, é areia (restinga). A costa tem reentrâncias e
## fozes, por isso vale a regra da maioria dos pontos medidos, não todos.
func _a_costa(regiao, solo) -> void:
	var costa: PackedVector2Array = regiao.get("_coast")
	var terra: PackedVector2Array = regiao.get("_land")
	_verificar(costa.size() > 20, "a região tem costa")
	var medidos := 0
	var areia := 0
	var passo_de_areia := 0
	var salto := maxi(costa.size() / 40, 1)
	for i in range(2, costa.size() - 2, salto):
		var tangente := (costa[i + 1] - costa[i - 1]).normalized()
		for lado in [1.0, -1.0]:
			var ponto: Vector2 = costa[i] + tangente.orthogonal() * lado * 2.0
			if not Geometry2D.is_point_in_polygon(ponto, terra):
				continue
			if _perto_de_rio_ou_rua(regiao, ponto, 12.0):
				continue
			medidos += 1
			if solo.peso(Camada.AREIA, ponto) >= 0.8:
				areia += 1
			if regiao.surface_at(Vector3(ponto.x, 0.0, ponto.y)) == "areia":
				passo_de_areia += 1
	_verificar(medidos >= 10, "pontos de costa medidos (%d)" % medidos)
	_verificar(areia >= medidos * 0.9, "a 2 u da costa é areia em %d de %d pontos" % [areia, medidos])
	_verificar(passo_de_areia >= medidos * 0.9, "o passo na costa é de areia em %d de %d pontos" % [passo_de_areia, medidos])


## Na margem de um rio, longe da costa, é lama; e o passo ali é de lama.
func _o_rio(regiao, solo) -> void:
	var medidos := 0
	var lama := 0
	var passo_de_lama := 0
	for rio: Dictionary in regiao.get("_rivers"):
		var pontos: PackedVector2Array = rio.points
		for i in range(4, pontos.size() - 4, 6):
			var tangente := (pontos[i + 1] - pontos[i - 1]).normalized()
			var ponto: Vector2 = pontos[i] + tangente.orthogonal() * (float(rio.width) * 0.5 + 1.5)
			if _perto_da_costa(regiao, ponto, 24.0) or _perto_de_rua(regiao, ponto, 14.0):
				continue
			medidos += 1
			if solo.peso(Camada.LAMA, ponto) >= 0.8:
				lama += 1
			if regiao.surface_at(Vector3(ponto.x, 0.0, ponto.y)) == "lama":
				passo_de_lama += 1
	_verificar(medidos >= 5, "pontos de margem de rio medidos (%d)" % medidos)
	_verificar(lama >= medidos * 0.9, "a margem do rio é lama em %d de %d pontos" % [lama, medidos])
	_verificar(passo_de_lama >= medidos * 0.9, "o passo na margem é de lama em %d de %d pontos" % [passo_de_lama, medidos])


## O miolo da Fazenda é pasto: o ponto mais fundo dentro dela, pelo menos 0,8.
func _a_fazenda(regiao, solo) -> void:
	var pontos := PackedVector2Array()
	for feature: Dictionary in regiao.get("_features"):
		if feature.get("kind", "") == "area" and String(feature.get("name", "")) == "Fazenda":
			pontos = regiao._to_points(feature.get("coordinates_m", []))
	_verificar(pontos.size() >= 3, "o KML tem a Fazenda")
	if pontos.size() < 3:
		return
	var melhor := Vector2.INF
	var melhor_folga := -1.0
	var caixa := Rect2(pontos[0], Vector2.ZERO)
	for p in pontos:
		caixa = caixa.expand(p)
	var y := caixa.position.y
	while y <= caixa.end.y:
		var x := caixa.position.x
		while x <= caixa.end.x:
			var candidato := Vector2(x, y)
			if Geometry2D.is_point_in_polygon(candidato, pontos) and not _perto_de_rua(regiao, candidato, 6.0):
				var folga := INF
				for i in pontos.size():
					var perto := Geometry2D.get_closest_point_to_segment(candidato, pontos[i], pontos[(i + 1) % pontos.size()])
					folga = minf(folga, candidato.distance_to(perto))
				if folga > melhor_folga:
					melhor_folga = folga
					melhor = candidato
			x += 4.0
		y += 4.0
	_verificar(melhor.is_finite() and melhor_folga >= 6.0, "a Fazenda tem um miolo (folga %.1f u)" % melhor_folga)
	if melhor.is_finite():
		var peso: float = solo.peso(Camada.PASTO, melhor)
		_verificar(peso >= 0.8, "o miolo da Fazenda é pasto (%.2f, esperado >= 0,8)" % peso)


## A rua é terra no eixo e nas trilhas do acostamento; o passo é de terra.
func _a_rua(regiao, solo) -> void:
	var principal := PackedVector2Array()
	for rua: Dictionary in regiao.get("_roads"):
		if String(rua.get("name", "")) == "Rua Principal":
			principal = rua.points
	_verificar(principal.size() >= 4, "a região tem a Rua Principal")
	if principal.size() < 4:
		return
	var meio := principal[principal.size() / 2]
	_verificar(solo.peso(Camada.TERRA, meio) >= 0.9, "o eixo da Rua Principal é terra (%.2f)" % solo.peso(Camada.TERRA, meio))
	_verificar(regiao.surface_at(Vector3(meio.x, 0.0, meio.y)) == "terra", "o passo na Rua Principal é de terra")


## Sob as árvores da mata, a copa pintada: folhiço embaixo, verde-mata ao longe.
func _a_copa(mundo, solo) -> void:
	var medidas := 0
	var com_copa := 0
	var coqueiros := 0
	var coqueiros_com_copa := 0
	var dendes := 0
	var dendes_com_copa := 0
	var regiao = mundo.get("_region")
	for arvore: Dictionary in mundo.arvores():
		var pe: Vector3 = arvore["pos"]
		var peso: float = solo.peso(Camada.COPA, Vector2(pe.x, pe.z))
		var especie := String(arvore.get("especie", ""))
		if especie.contains("dende"):
			# O dendezal tem chão próprio (#195); o dendê da areia fica de areia.
			if regiao != null and regiao.surface_at(pe) != "areia":
				dendes += 1
				if peso > 0.3:
					dendes_com_copa += 1
			continue
		if especie.contains("coqueiro"):
			coqueiros += 1
			if peso > 0.3:
				coqueiros_com_copa += 1
			continue
		medidas += 1
		if peso >= 0.4:
			com_copa += 1
	_verificar(medidas > 1000, "o mundo plantou árvores de mata (%d)" % medidas)
	_verificar(com_copa >= medidas * 0.9, "sob a árvore há copa em %d de %d pés" % [com_copa, medidas])
	_verificar(dendes >= 20, "o mundo plantou dendezeiros fora da areia (%d)" % dendes)
	_verificar(dendes_com_copa >= dendes * 0.9, "sob o dendezeiro há folhiço em %d de %d pés" % [dendes_com_copa, dendes])
	_verificar(coqueiros == 0 or coqueiros_com_copa <= coqueiros * 0.5, "o coqueiral da orla segue de areia, sem folhiço (%d de %d)" % [coqueiros_com_copa, coqueiros])


## A trilha de pé liga a porta de cada casa à rua mais perto: terra no meio dela.
func _as_trilhas(mundo, regiao, solo) -> void:
	var medidas := 0
	var com_trilha := 0
	var lotes: Dictionary = mundo.get("_lotes")
	for nome in lotes:
		if not mundo.ancoras.has(nome) or not mundo.ancoras.has(String(nome) + "Frente"):
			continue
		var centro: Vector3 = mundo.ancoras[nome]
		var frente: Vector3 = mundo.ancoras[String(nome) + "Frente"]
		var porta3: Vector3 = centro + frente * mundo._raio_do_lote(String(lotes[nome].get("chave", ""))) * 0.55
		var porta := Vector2(porta3.x, porta3.z)
		var rua: Vector2 = regiao._ponto_mais_perto_das_ruas(porta, 40.0)
		# Só a trilha que passa longe do halo da rua (2,3 + 2,5 u) prova alguma coisa.
		if not rua.is_finite() or porta.distance_to(rua) < 10.0 or _perto_da_costa(regiao, porta.lerp(rua, 0.5), 14.0):
			continue
		medidas += 1
		if solo.peso(Camada.TERRA, porta.lerp(rua, 0.5)) >= 0.5:
			com_trilha += 1
	_verificar(medidas >= 2, "casas com trilha longa até a rua medidas (%d)" % medidas)
	_verificar(com_trilha >= medidas * 0.9, "a trilha de pé é terra em %d de %d casas" % [com_trilha, medidas])


## Normais suaves na terra: todas para cima, sem faces viradas para baixo.
func _as_normais(regiao) -> void:
	var terra := regiao.get_node_or_null("Terra") as MeshInstance3D
	_verificar(terra != null and terra.mesh != null, "a região tem a malha 'Terra'")
	if terra == null or terra.mesh == null:
		return
	var matrizes := terra.mesh.surface_get_arrays(0)
	var normais: PackedVector3Array = matrizes[Mesh.ARRAY_NORMAL]
	var vertices: PackedVector3Array = matrizes[Mesh.ARRAY_VERTEX]
	_verificar(normais.size() > 1000 and normais.size() == vertices.size(), "a malha da terra tem uma normal por vértice")
	var menor := 1.0
	for n in normais:
		menor = minf(menor, n.y)
	_verificar(menor > 0.0, "todas as normais da terra apontam para cima (menor y %.2f)" % menor)
	# Suave: bem menos normais distintas que vértices (com normal por face, são 1 por triângulo).
	var distintas := {}
	for n in normais:
		distintas[Vector3i((n * 1000.0).round())] = true
	_verificar(distintas.size() > 50, "as normais variam com o relevo (%d distintas)" % distintas.size())
	var indices = matrizes[Mesh.ARRAY_INDEX]
	_verificar(indices != null and (indices as PackedInt32Array).size() > 0 and (indices as PackedInt32Array).size() > vertices.size(), "os vértices da terra são compartilhados entre triângulos (malha indexada)")


## O material do chão é o do shader em camadas e está ligado ao mapa.
func _o_material(regiao) -> void:
	var terra := regiao.get_node_or_null("Terra") as MeshInstance3D
	if terra == null:
		return
	var material := terra.material_override as ShaderMaterial
	if material == null:
		material = terra.get_surface_override_material(0) as ShaderMaterial
	if material == null and terra.mesh != null:
		material = terra.mesh.surface_get_material(0) as ShaderMaterial
	_verificar(material != null and material.shader == regiao.TERRENO_SHADER, "o chão usa o shader do terreno em camadas")
	if material != null:
		_verificar(bool(material.get_shader_parameter("solo_ativo")), "o shader do terreno está ligado ao mapa de solo")
		_verificar(material.get_shader_parameter("solo") is Texture2DArray, "o mapa de solo chega ao shader como Texture2DArray")


func _perto_de_rua(regiao, ponto: Vector2, folga: float) -> bool:
	for rua: Dictionary in regiao.get("_roads"):
		if (rua.bounds as Rect2).grow(folga + float(rua.width)).has_point(ponto) \
				and regiao._distance_to_line(ponto, rua.points) < float(rua.width) * 0.5 + folga:
			return true
	return false


func _perto_de_rio_ou_rua(regiao, ponto: Vector2, folga: float) -> bool:
	if _perto_de_rua(regiao, ponto, folga):
		return true
	for rio: Dictionary in regiao.get("_rivers"):
		if (rio.bounds as Rect2).grow(folga + float(rio.width)).has_point(ponto) \
				and regiao._distance_to_line(ponto, rio.points) < float(rio.width) * 0.5 + folga:
			return true
	return false


func _perto_da_costa(regiao, ponto: Vector2, folga: float) -> bool:
	return regiao._distance_to_line(ponto, regiao.get("_coast")) < folga


func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame


func _frames(quantos: int) -> void:
	for i in quantos:
		await process_frame


func _verificar(condicao: bool, descricao: String) -> void:
	verificacoes += 1
	if not condicao:
		falhas += 1
		print("FALHA: ", descricao)
		push_error("MAPA_DE_SOLO_FALHOU: " + descricao)


func _fechar() -> void:
	if falhas == 0:
		print("MAPA_DE_SOLO_OK: %d verificações — terra na praça, na rua e nas trilhas de pé; areia na costa; lama nas margens dos rios; pasto na fazenda; copa sob a mata e coqueiral de areia; normais suaves; o shader do terreno ligado ao mapa" % verificacoes)
	else:
		print("mapa_de_solo: %d falha(s) em %d verificações" % [falhas, verificacoes])
	quit(1 if falhas > 0 else 0)
