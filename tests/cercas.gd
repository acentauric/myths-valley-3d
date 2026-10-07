extends SceneTree
## AS CERCAS DE VARAS DAS ROÇAS, BEM POSTAS (playtest de 07/10: "as cercas continuam mal
## posicionadas... também aumente elas para realmente serem cercas que impedem a passagem").
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/cercas.gd
##
## O cercado de cada roça é traçado em lances retos de canto a canto sobre o contorno
## simplificado da roça (`PaisagismoVale._lances_do_cercado`), plantado em pé e com corpo
## (`plantar_cercas`). O que este portão mede, lance a lance:
##
##   1. SÃO CERCAS DE VERDADE: cada lance plantado mede ao menos ALTURA_MINIMA, e a caixa
##      de colisão dele ao menos CORPO_MINIMO — mais que o pulo do jogador: nem o passo
##      nem o pulo passam. Um corpo por lance, no lugar do lance.
##   2. FORA DA RUA, DA CASA E DA ÁGUA: nenhuma ponta e nenhum meio a menos de RUA de uma
##      rua, dentro da caixa de uma construção ou fora da terra.
##   3. NO CHÃO: o meio do lance a menos de DESNIVEL do chão (as pontas o
##      cercas_na_encosta já cobra).
##   4. NÃO SE CRUZAM: dois lances só se tocam nas pontas.
##   5. ABRAÇAM A ROÇA: o meio de cada lance a menos de DA_BORDA do contorno da roça
##      dele, e os cantos são cantos — ao menos CANTOS_FECHADOS das pontas têm outra ponta
##      colada (a menos de PONTA).
##   6. UMA CERCA SÓ ENTRE ROÇAS VIZINHAS: nenhum lance de uma roça corre colado e
##      paralelo a um lance de outra.
##   7. HÁ BASTANTE: ao menos MINIMO lances, e uma porteira em cada roça cercada.

const CatalogoAssets := preload("res://scripts/prototipo_3d/catalogo_assets.gd")

const ALTURA_MINIMA := 1.2
const CORPO_MINIMO := 1.8
const RUA := 2.0
const DESNIVEL := 0.6
const PONTA := 0.35
const DA_BORDA := 2.8
const CANTOS_FECHADOS := 0.85
const ENTRE_ROCAS := 2.0
const MINIMO := 30

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("CERCAS_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	var vale = current_scene
	var mundo = vale.world
	var regiao: Node3D = mundo._region

	var itens: Array = []
	var porteiras := {}
	for item: Dictionary in mundo.paisagismo_aderecos:
		if String(item["chave"]) == "cerca_varas":
			itens.append(item)
		elif String(item["chave"]) == "porteira":
			porteiras[String(item["zona"])] = true
	var plantadas: Array = regiao.get_meta("cercas_cerca_varas", [])
	_conferir(itens.size() >= MINIMO, "o plano tem %d lance(s) de cerca de varas, e são ao menos %d" % [itens.size(), MINIMO])
	_conferir(plantadas.size() == itens.size(), "a região plantou %d lance(s) e o plano tem %d" % [plantadas.size(), itens.size()])
	if itens.is_empty() or plantadas.size() != itens.size():
		_fechar()
		return
	var modelo: Dictionary = CatalogoAssets.malha("cerca_varas", 1.0)
	_conferir(not modelo.is_empty(), "o catálogo não tem a malha da cerca de varas")
	if modelo.is_empty():
		_fechar()
		return
	var base: Transform3D = modelo.base
	var caixa: AABB = base * (modelo.mesh as Mesh).get_aabb()

	# --- 1. SÃO CERCAS DE VERDADE ------------------------------------------------------
	var corpos := regiao.get_node_or_null("CorposDasCercas_cerca_varas")
	_conferir(corpos != null, "a região não tem os corpos das cercas de varas")
	var caixas: Array[Dictionary] = []
	if corpos != null:
		for corpo in corpos.get_children():
			for forma in (corpo as Node).get_children():
				if forma is CollisionShape3D and (forma as CollisionShape3D).shape is BoxShape3D:
					caixas.append({"tamanho": ((forma as CollisionShape3D).shape as BoxShape3D).size, "onde": (forma as CollisionShape3D).global_position})
	_conferir(caixas.size() == plantadas.size(), "são %d corpo(s) para %d lance(s)" % [caixas.size(), plantadas.size()])
	var baixas := 0
	var corpos_baixos := 0
	var corpos_fora := 0
	var menor_altura := INF
	var menor_corpo := INF
	for i in plantadas.size():
		var plantada: Transform3D = plantadas[i]
		var lance: Transform3D = plantada * base.affine_inverse()
		var altura: float = caixa.size.y * lance.basis.y.length()
		menor_altura = minf(menor_altura, altura)
		if altura < ALTURA_MINIMA:
			baixas += 1
		if i < caixas.size():
			var tamanho: Vector3 = caixas[i]["tamanho"]
			menor_corpo = minf(menor_corpo, tamanho.y)
			if tamanho.y < CORPO_MINIMO:
				corpos_baixos += 1
			var centro_do_corpo: Vector3 = lance.origin + lance.basis.y.normalized() * tamanho.y * 0.5
			if (caixas[i]["onde"] as Vector3).distance_to(centro_do_corpo) > 0.15:
				corpos_fora += 1
	_conferir(baixas == 0, "%d lance(s) de cerca com menos de %.2f de altura (a mais baixa: %.2f)" % [baixas, ALTURA_MINIMA, menor_altura])
	_conferir(corpos_baixos == 0, "%d corpo(s) de cerca com menos de %.2f de altura (o mais baixo: %.2f): o pulo passa" % [corpos_baixos, CORPO_MINIMO, menor_corpo])
	_conferir(corpos_fora == 0, "%d corpo(s) de cerca fora do lugar do lance" % corpos_fora)

	# --- 2 a 4. FORA DA RUA, NO CHÃO, SEM SE CRUZAR -----------------------------------------
	var casas: Array = []
	var construcoes: Dictionary = mundo.get("construcoes")
	for nome in construcoes:
		var corpo = (construcoes[nome] as Dictionary).get("colisao")
		if corpo == null or not is_instance_valid(corpo):
			continue
		for forma in (corpo as Node).get_children():
			if forma is CollisionShape3D and (forma as CollisionShape3D).shape is BoxShape3D:
				var tamanho: Vector3 = ((forma as CollisionShape3D).shape as BoxShape3D).size
				casas.append({"nome": str(nome), "centro": (forma as CollisionShape3D).global_position, "meia": Vector2(tamanho.x, tamanho.z) * 0.5, "giro": (corpo as Node3D).global_rotation.y})
	var lances: Array[Dictionary] = []
	var na_rua := 0
	var na_casa := 0
	var na_agua := 0
	var no_ar := 0
	var pior_rua := INF
	var pior_desnivel := 0.0
	for i in itens.size():
		var item: Dictionary = itens[i]
		var plantada: Transform3D = plantadas[i]
		var lance: Transform3D = plantada * base.affine_inverse()
		var de: Vector3 = lance * Vector3(caixa.position.x, 0.0, caixa.get_center().z)
		var ate: Vector3 = lance * Vector3(caixa.end.x, 0.0, caixa.get_center().z)
		var meio: Vector3 = de.lerp(ate, 0.5)
		var zona := String(item["zona"])
		var d_rua: float = INF
		for p: Vector3 in [de, meio, ate]:
			d_rua = minf(d_rua, float(regiao._distancia_da_rua(Vector2(p.x, p.z))))
		pior_rua = minf(pior_rua, d_rua)
		if d_rua < RUA:
			na_rua += 1
		var dentro := false
		for casa: Dictionary in casas:
			for p: Vector3 in [de, meio, ate]:
				var local: Vector3 = (p - (casa["centro"] as Vector3)).rotated(Vector3.UP, -float(casa["giro"]))
				if absf(local.x) < float((casa["meia"] as Vector2).x) + 0.3 and absf(local.z) < float((casa["meia"] as Vector2).y) + 0.3:
					dentro = true
		if dentro:
			na_casa += 1
		if not mundo.is_on_land(de) or not mundo.is_on_land(ate):
			na_agua += 1
		var chao: Vector3 = regiao.ground_position(meio)
		var desnivel := absf(meio.y - chao.y)
		pior_desnivel = maxf(pior_desnivel, desnivel)
		if desnivel > DESNIVEL:
			no_ar += 1
		lances.append({"zona": zona, "de": Vector2(de.x, de.z), "ate": Vector2(ate.x, ate.z), "meio": Vector2(meio.x, meio.z)})
	_conferir(na_rua == 0, "%d lance(s) de cerca a menos de %.1f de uma rua (o pior: %.2f)" % [na_rua, RUA, pior_rua])
	_conferir(na_casa == 0, "%d lance(s) de cerca dentro de uma construção" % na_casa)
	_conferir(na_agua == 0, "%d lance(s) de cerca com ponta na água" % na_agua)
	_conferir(no_ar == 0, "%d lance(s) de cerca com o meio a mais de %.2f do chão (o pior: %.2f)" % [no_ar, DESNIVEL, pior_desnivel])
	var cruzamentos := 0
	var exemplo := ""
	for i in lances.size():
		for j in range(i + 1, lances.size()):
			var a: Dictionary = lances[i]
			var b: Dictionary = lances[j]
			var cruza = Geometry2D.segment_intersects_segment(a["de"], a["ate"], b["de"], b["ate"])
			if cruza == null:
				continue
			var ponto: Vector2 = cruza
			var nas_pontas := false
			for p: Vector2 in [a["de"], a["ate"], b["de"], b["ate"]]:
				if p.distance_to(ponto) < PONTA:
					nas_pontas = true
			if nas_pontas:
				continue
			cruzamentos += 1
			if exemplo == "":
				exemplo = "%s %s × %s %s em %s" % [a["zona"], str(a["de"]), b["zona"], str(b["de"]), str(ponto)]
	_conferir(cruzamentos == 0, "%d par(es) de lances de cerca se cruzam fora das pontas (%s)" % [cruzamentos, exemplo])

	# --- 5. ABRAÇAM A ROÇA ---------------------------------------------------------------
	var zonas := {}
	var lido = JSON.parse_string(FileAccess.get_file_as_string("res://data/paisagismo/zonas_iniciais.json"))
	var lista: Array = lido if lido is Array else (lido.get("zonas", []) if lido is Dictionary else [])
	for zona in lista:
		if zona is Dictionary and zona.has("poligono"):
			var poligono := PackedVector2Array()
			for v in zona["poligono"]:
				poligono.append(Vector2(float(v[0]), float(v[1])))
			zonas[String(zona["nome"])] = poligono
	var longe_da_roca := 0
	var pior_borda := 0.0
	var pontas_soltas := 0
	for i in lances.size():
		var lance: Dictionary = lances[i]
		var poligono: PackedVector2Array = zonas.get(lance["zona"], PackedVector2Array())
		if poligono.size() >= 3:
			var d := INF
			for k in poligono.size():
				d = minf(d, (lance["meio"] as Vector2).distance_to(Geometry2D.get_closest_point_to_segment(lance["meio"], poligono[k], poligono[(k + 1) % poligono.size()])))
			pior_borda = maxf(pior_borda, d)
			if d > DA_BORDA:
				longe_da_roca += 1
		for ponta: Vector2 in [lance["de"], lance["ate"]]:
			var colada := false
			for j in lances.size():
				if j == i:
					continue
				if ponta.distance_to(lances[j]["de"]) < PONTA or ponta.distance_to(lances[j]["ate"]) < PONTA:
					colada = true
					break
			if not colada:
				pontas_soltas += 1
	_conferir(longe_da_roca == 0, "%d lance(s) de cerca a mais de %.1f da borda da roça deles (o pior: %.2f)" % [longe_da_roca, DA_BORDA, pior_borda])
	var fechadas := 1.0 - float(pontas_soltas) / float(lances.size() * 2)
	_conferir(fechadas >= CANTOS_FECHADOS, "só %.0f%% das pontas das cercas encontram outra ponta: cercado com buracos nos cantos" % (fechadas * 100.0))

	# --- 6. UMA CERCA SÓ ENTRE ROÇAS VIZINHAS ---------------------------------------------
	var coladas := 0
	for i in lances.size():
		for j in range(i + 1, lances.size()):
			var a: Dictionary = lances[i]
			var b: Dictionary = lances[j]
			if a["zona"] == b["zona"]:
				continue
			var rumo_a: Vector2 = ((a["ate"] as Vector2) - (a["de"] as Vector2)).normalized()
			var rumo_b: Vector2 = ((b["ate"] as Vector2) - (b["de"] as Vector2)).normalized()
			if absf(rumo_a.dot(rumo_b)) < 0.7:
				continue
			var d1: float = (a["de"] as Vector2).distance_to(Geometry2D.get_closest_point_to_segment(a["de"], b["de"], b["ate"]))
			var d2: float = (a["ate"] as Vector2).distance_to(Geometry2D.get_closest_point_to_segment(a["ate"], b["de"], b["ate"]))
			if d1 < ENTRE_ROCAS and d2 < ENTRE_ROCAS:
				coladas += 1
	_conferir(coladas == 0, "%d par(es) de lances de roças vizinhas correm colados: cerca dupla na divisa" % coladas)

	# --- 7. HÁ BASTANTE -------------------------------------------------------------------
	var cercadas := {}
	for lance: Dictionary in lances:
		cercadas[lance["zona"]] = true
	for zona in cercadas:
		_conferir(porteiras.has(zona), "a roça cercada '%s' não tem porteira" % zona)
	print("  %d lances em %d roças; a cerca mais baixa %.2f, o corpo mais baixo %.2f; rua mais perto %.2f; %.0f%% das pontas fechadas" % [lances.size(), cercadas.size(), menor_altura, menor_corpo, pior_rua, fechadas * 100.0])
	_fechar()


func _fechar() -> void:
	if falhas == 0:
		print("CERCAS_OK: as cercas de varas das roças são cercas de verdade (em pé, com corpo que o pulo não passa, um corpo por lance), fora da rua, da casa e da água, no chão, sem se cruzar, abraçando a roça de canto a canto, uma só entre roças vizinhas, e cada roça cercada tem a porteira")
		quit(0)
	else:
		print("cercas: %d falha(s)" % falhas)
		quit(1)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			return
		await process_frame
