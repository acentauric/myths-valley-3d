extends "res://tests/suite/caso.gd"
## Confere A MATA EM MANCHAS (especies_da_mata.gd, GeoRegionRenderer._build_forest).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste mata_em_manchas
##
## Monta só a região do vale, duas vezes, no estilo Tripo, e pergunta:
##
##   1. A MATA É FEITA DE MANCHAS: em média, pelo menos 55% dos oito vizinhos de
##      uma árvore da mata são da espécie dela (o sorteio uniforme dava 19%).
##   2. CADA ESPÉCIE NO SEU LUGAR: piaçava só na restinga e na Mata do mapa,
##      ingá fora do topo do morro, e nada de coqueiro, mangue ou gameleira na
##      mata — a gameleira é uma só, a de Iroko.
##   3. NENHUM TRONCO A MENOS DE 4 u DA BEIRA DE UMA RUA, nem pelo ponto de
##      plantio nem pelo pé que se vê (`base_do_tronco`).
##   4. A MATA É LEVE: cada malha da mata tem no máximo 6.500 triângulos, e a
##      média por árvore fica abaixo de 4.500 (a mistura antiga dava 6.700).
##   5. A MONTAGEM É DETERMINÍSTICA: as duas montagens dão os mesmos troncos, na
##      mesma ordem, com a mesma espécie e a mesma transformação, e o mesmo
##      sub-bosque, rio e orla.

const RENDERER := "res://scripts/prototipo_3d/geo_region_renderer.gd"
const CATALOGO_DE_REGIOES := "res://data/mapas/regioes.json"
## Com a mata pela metade (uma árvore a cada duas do sorteio de antes), os oito
## vizinhos mais perto de cada árvore ficam ~40% mais longe e cruzam a divisa da
## mancha mais vezes: a pureza medida ficou em 0,59, e o piso foi de 0,60 para 0,55. O sorteio uniforme continua dando 0,19.
const PUREZA_MINIMA := 0.55
const AFASTAMENTO_DA_RUA := 4.0
const TRIANGULOS_POR_MALHA := 6500
const TRIANGULOS_MEDIOS := 4500.0
## Só na restinga e na Mata do mapa (`especies_da_mata.gd`).
const SO_NA_RESTINGA := ["piacava", "clusia", "cajueiro", "pitangueira"]
## Nunca na mata: coqueiro e mangue são da orla; a gameleira, única.
const NUNCA_NA_MATA := ["coqueiro", "mangue", "mata_larga"]

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("MATA_EM_MANCHAS_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	var regiao: Node3D = await _montar()
	var outra: Node3D = await _montar()
	var mata := _troncos_da_mata(regiao)
	# A mata foi pela metade (tree_count 3117 de um sorteio de 6234) e perdeu o que
	# caía nas clareiras-destaque e nas trilhas: entre 2.400 e 3.200 troncos.
	_conferir(mata.size() > 2400 and mata.size() < 3200, "a mata tem %d troncos (esperado de 2.400 a 3.200, a metade da de antes)" % mata.size())
	if mata.is_empty():
		_fechar()
		return
	_falsificar(regiao, mata)

	# --- 1. MANCHAS -------------------------------------------------------------
	var grade := {}
	for i in mata.size():
		var p: Vector2 = mata[i].point
		var celula := Vector2i(floori(p.x / 10.0), floori(p.y / 10.0))
		if not grade.has(celula):
			grade[celula] = []
		grade[celula].append(i)
	var soma := 0.0
	var medidas := 0
	for i in mata.size():
		var p: Vector2 = mata[i].point
		var celula := Vector2i(floori(p.x / 10.0), floori(p.y / 10.0))
		var vizinhos: Array = []
		for dz in range(-2, 3):
			for dx in range(-2, 3):
				for j in grade.get(celula + Vector2i(dx, dz), []):
					if j != i:
						vizinhos.append([p.distance_squared_to(mata[j].point), j])
		if vizinhos.size() < 8:
			continue
		vizinhos.sort_custom(func(a, b): return a[0] < b[0])
		var iguais := 0
		for k in 8:
			if mata[vizinhos[k][1]].especie == mata[i].especie:
				iguais += 1
		soma += float(iguais) / 8.0
		medidas += 1
	var pureza := soma / float(maxi(medidas, 1))
	print("pureza da mata: %.3f (%d árvores medidas)" % [pureza, medidas])
	_conferir(pureza >= PUREZA_MINIMA, "a mata está misturada: pureza %.3f, abaixo de %.2f" % [pureza, PUREZA_MINIMA])

	# --- 2. CADA ESPÉCIE NO SEU LUGAR -----------------------------------------
	var pontos: Array[Vector2] = []
	for tronco in mata:
		pontos.append(tronco.point)
	var classes: PackedStringArray = regiao._classes_da_mata(pontos)
	var contagem := {}
	var fora_do_lugar := {}
	for i in mata.size():
		var especie: String = mata[i].especie
		contagem[especie] = int(contagem.get(especie, 0)) + 1
		_conferir(not NUNCA_NA_MATA.has(especie), "%s plantado na mata em %s" % [especie, str(mata[i].point)])
		var errado := (SO_NA_RESTINGA.has(especie) and not ["restinga", "mata_do_mapa"].has(classes[i])) \
			or (especie == "ingazeiro" and classes[i] == "topo")
		if errado:
			fora_do_lugar[especie] = int(fora_do_lugar.get(especie, 0)) + 1
	print("espécies da mata: ", contagem)
	_conferir(fora_do_lugar.is_empty(), "espécie fora do lugar dela: %s" % str(fora_do_lugar))
	_conferir(contagem.size() >= 8, "a mata tem só %d espécies: a repetição é por mancha, não o vale inteiro" % contagem.size())

	# --- 3. LONGE DAS RUAS ------------------------------------------------------
	var colados := 0
	var exemplo := ""
	for tronco in mata:
		var base: Vector3 = regiao.base_do_tronco(tronco)
		for ponto in [tronco.point, Vector2(base.x, base.z)]:
			var beira := _distancia_da_rua(regiao, ponto)
			if beira < AFASTAMENTO_DA_RUA:
				colados += 1
				if exemplo == "":
					exemplo = "%s em %s a %.2f u (%s)" % [tronco.especie, str(ponto), beira, beira_nome(regiao, ponto)]
				break
	_conferir(colados == 0, "%d tronco(s) da mata a menos de %.0f u da beira da rua; o primeiro: %s" % [colados, AFASTAMENTO_DA_RUA, exemplo])

	# --- 4. LEVE ----------------------------------------------------------------
	var triangulos := 0.0
	var por_malha := {}
	for tronco in mata:
		var malha: Mesh = (tronco.visual as MultiMeshInstance3D).multimesh.mesh
		if not por_malha.has(malha):
			por_malha[malha] = _triangulos(malha)
			_conferir(int(por_malha[malha]) <= TRIANGULOS_POR_MALHA, "a malha da mata de %s tem %d triângulos" % [tronco.especie, por_malha[malha]])
		triangulos += float(por_malha[malha])
	var media := triangulos / float(mata.size())
	print("triângulos da mata: %.0f no total, %.0f por árvore" % [triangulos, media])
	_conferir(media <= TRIANGULOS_MEDIOS, "a árvore média da mata tem %.0f triângulos" % media)

	# --- 5. DETERMINÍSTICA --------------------------------------------------------
	var troncos_a: Array = regiao._tree_trunks
	var troncos_b: Array = outra._tree_trunks
	_conferir(troncos_a.size() == troncos_b.size(), "as duas montagens dão %d e %d troncos" % [troncos_a.size(), troncos_b.size()])
	var diferentes := 0
	for i in mini(troncos_a.size(), troncos_b.size()):
		var a: Dictionary = troncos_a[i]
		var b: Dictionary = troncos_b[i]
		if a.point != b.point or a.especie != b.especie or a.get("transformacao") != b.get("transformacao"):
			diferentes += 1
	_conferir(diferentes == 0, "%d tronco(s) mudaram de uma montagem para a outra" % diferentes)
	var multimeshes_a := _transformacoes(regiao)
	var multimeshes_b := _transformacoes(outra)
	_conferir(multimeshes_a == multimeshes_b, "a vegetação (sub-bosque, rio, orla) mudou de uma montagem para a outra")
	_fechar()


## FALSIFICAÇÃO: `-- --falsificar=sorteio` volta ao sorteio uniforme (a espécie de cada
## tronco sai de um número ao acaso) e `-- --falsificar=rua` encosta um tronco na
## beira de uma rua. O portão tem de reprovar nos dois; sem o argumento, não mexe em nada.
func _falsificar(regiao: Node3D, mata: Array) -> void:
	var modo := ""
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--falsificar="):
			modo = argumento.trim_prefix("--falsificar=")
	if modo == "sorteio":
		var sorte := RandomNumberGenerator.new()
		sorte.seed = 7
		var todas: Array[String] = ["cedro", "angico", "jatoba", "mata_alta", "ipe_amarelo", "jequitiba", "embauba", "aroeira"]
		for tronco in mata:
			tronco["especie"] = todas[sorte.randi_range(0, todas.size() - 1)]
	elif modo == "rua":
		var rua = regiao._roads[0]
		mata[0]["point"] = (rua.points[0] as Vector2) + Vector2(0.0, float(rua.width) * 0.5 + 1.0)
		mata[0]["transformacao"] = Transform3D(Basis.IDENTITY, Vector3(mata[0].point.x, 0.0, mata[0].point.y))


func _montar() -> Node3D:
	var catalogo: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOGO_DE_REGIOES))
	var dados: Dictionary = {}
	for entrada in catalogo.get("regions", []):
		if entrada.get("id", "") == catalogo.get("active_region", ""):
			dados = entrada
	var regiao: Node3D = (load(RENDERER) as GDScript).new()
	root.add_child(regiao)
	var metros := float(dados.get("scale_m_per_unit", 1.0))
	regiao.set_meters_per_unit(metros)
	regiao.set_vertical_exaggeration(float(dados.get("vertical_exaggeration", 1.0)))
	regiao.set_estilo_tripo(true)
	# As mesmas clareiras do vale (terreiro e gameleira, `WorldBuilder`).
	regiao.clareiras.assign([Vector2(-262, -238) / metros, Vector2(-300, 560) / metros])
	await regiao.build_region(String(dados["geometry"]), String(dados["scenario"]))
	return regiao


## Os troncos plantados por `_build_forest` (os da MultiMesh "Mata_ …" (o Godot troca o ":" do nome por "_")).
func _troncos_da_mata(regiao: Node3D) -> Array:
	var lista: Array = []
	for tronco in regiao._tree_trunks:
		var visual := tronco.get("visual") as MultiMeshInstance3D
		if visual != null and String(visual.name).begins_with("Mata_"):
			lista.append(tronco)
	return lista


func _distancia_da_rua(regiao: Node3D, ponto: Vector2) -> float:
	var menor := INF
	for rua in regiao._roads:
		menor = minf(menor, regiao._distance_to_line(ponto, rua.points) - float(rua.width) * 0.5)
	return menor


func beira_nome(regiao: Node3D, ponto: Vector2) -> String:
	var menor := INF
	var nome := ""
	for rua in regiao._roads:
		var d: float = regiao._distance_to_line(ponto, rua.points) - float(rua.width) * 0.5
		if d < menor:
			menor = d
			nome = String(rua.get("name", "?"))
	return nome


func _triangulos(malha: Mesh) -> int:
	var total := 0
	for s in malha.get_surface_count():
		var indices: int = malha.surface_get_array_index_len(s)
		total += (indices if indices > 0 else malha.surface_get_array_len(s)) / 3
	return total


## Toda MultiMesh de vegetação que não é a mata, por nome: as transformações.
func _transformacoes(regiao: Node3D) -> Dictionary:
	var resultado := {}
	for filho in regiao.get_children():
		var visual := filho as MultiMeshInstance3D
		if visual == null or String(visual.name).begins_with("Mata_"):
			continue
		var lista: Array = []
		for i in visual.multimesh.instance_count:
			lista.append(visual.multimesh.get_instance_transform(i))
		resultado[String(visual.name)] = lista
	return resultado


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("MATA_EM_MANCHAS_OK: a mata é feita de manchas de uma espécie, cada uma no seu lugar, longe das ruas, leve e igual a cada montagem")
	else:
		print("mata em manchas: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)
