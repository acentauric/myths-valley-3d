extends SceneTree
## OS MORADORES ANDAM COM FOLGA DAS PAREDES E DAS ÁRVORES (07/10: "tem muito NPC andando colado na
## parede, batendo em árvore; o deslocamento entre esses objetos deve ser suave").
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/folga_dos_moradores.gd
##
## A malha dos moradores é assada com o raio curto (0,2) por causa das portas; o caminho dela
## passa a dois palmos das paredes e dos troncos, e o corpo (0,26) raspa. A malha LARGA (0,6,
## `Navegacao.RAIO_LARGO`) assa junto e responde primeiro ao ar livre.
##
##   1. A MALHA LARGA FICA PRONTA depois da estreita, e `caminho` a usa: ao ar livre, o caminho
##      que ela dá é diferente do da estreita em ao menos um dos passeios.
##   2. FOLGA DOS TRONCOS E DAS CASAS: fora das pontas, nenhum ponto de um passeio ao ar livre
##      fica a menos de FOLGA do pé de um tronco da mata (além do raio dele) nem dentro da caixa
##      de uma construção com FOLGA de margem.
##   3. ONDE A LARGA NÃO PASSA, A ESTREITA RESPONDE: o caminho até o altar da igreja (pela
##      porta) e o do píer à gameleira continuam existindo e chegando.
##   4. O PASSO SUAVE: perto do ponto da vez, o rumo do morador já se mistura com o ponto
##      seguinte — a curva é um arco, não uma quina.

## A folga mínima do caminho (além do raio do tronco; fora da caixa da casa): mais que o
## corpo do morador (0,26), que com a malha estreita passava a 0,2.
const FOLGA := 0.3
const PONTA := 2.5

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("FOLGA_DOS_MORADORES_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(4)
	await _mundo_pronto()
	await _frames(6)
	var vale = current_scene
	var mundo = vale.world
	var regiao = mundo.get("_region")
	var navegacao = vale.get("navegacao")
	_conferir(navegacao != null and await _ate(func() -> bool: return navegacao.esta_pronta(), 60.0), "a malha estreita não ficou pronta")
	_conferir(await _ate(func() -> bool: return bool(navegacao.larga_pronta()), 60.0), "a malha larga não ficou pronta em 60 s")
	if not bool(navegacao.larga_pronta()):
		_fechar()
		return
	var lugares = root.get_node("/root/Lugares")
	var ancoras: Dictionary = mundo.ancoras

	# Os troncos (no pé que barra) e as caixas das casas.
	var troncos: Array = []
	for tronco in regiao._tree_trunks:
		var p: Vector2 = tronco.get("point", Vector2.INF)
		if not p.is_finite():
			continue
		if regiao.has_method("base_do_tronco"):
			var base: Vector3 = regiao.base_do_tronco(tronco)
			p = Vector2(base.x, base.z)
		troncos.append([p, maxf(float(tronco.get("radius", 0.3)), 0.2)])
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

	# --- 1 e 2. OS PASSEIOS AO AR LIVRE -------------------------------------------------------
	var passeios := [
		["praça → casa da estrada", lugares.ponto("praca"), lugares.ponto("casa_da_estrada")],
		["praça → cemitério", lugares.ponto("praca"), lugares.ponto("cemiterio")],
		["casa de taipa → terreiro", lugares.ponto("casa_de_taipa"), lugares.ponto("terreiro")],
		["praça → cruzeiro", lugares.ponto("praca"), lugares.ponto("cruzeiro")],
		["casa da estrada → poço", lugares.ponto("casa_da_estrada"), lugares.ponto("poco")],
	]
	var diferentes := 0
	for passeio in passeios:
		var rotulo: String = passeio[0]
		var de: Vector3 = passeio[1]
		var para: Vector3 = passeio[2]
		if not de.is_finite() or not para.is_finite():
			_conferir(false, "%s: um dos lugares não resolve" % rotulo)
			continue
		# DE ONDE UM MORADOR SAI DE VERDADE: a âncora de uma casa é o meio dela, e corpo nenhum
		# fica dentro da parede; o morador está na malha estreita (a dois palmos da porta).
		var de_cru: PackedVector3Array = navegacao.caminho_estreito(de, para)
		if de_cru.size() >= 2:
			de = de_cru[0]
		# A ÂNCORA DENTRO DE UM CÔMODO (a casa de taipa é a casa do jogador, com cômodo): desde #205
		# a casca fecha, a malha larga lá dentro é uma ilha, e quem sai sai pela porta
		# (`navegacao.caminho` emenda a soleira). O passeio ao ar livre começa na soleira de fora.
		var interiores = vale.get("interiores")
		if interiores != null and str(interiores.contem(de)) != "":
			var sala = interiores.sala_de(str(interiores.contem(de)))
			if sala != null:
				de = sala.soleira_de_fora()
		var largo: PackedVector3Array = navegacao.caminho(de, para)
		var estreito: PackedVector3Array = navegacao.caminho_estreito(de, para)
		var cru: PackedVector3Array = navegacao.caminho_largo(de, para)
		_conferir(largo.size() >= 2, "%s: sem caminho" % rotulo)
		if largo.size() < 2:
			continue
		if largo != estreito:
			diferentes += 1
		var raspou_tronco := 0
		var raspou_casa := 0
		var pior_tronco := INF
		var onde: Array[String] = []
		var total := _comprimento(largo)
		var andado := 0.0
		for i in range(1, largo.size()):
			var a: Vector3 = largo[i - 1]
			var b: Vector3 = largo[i]
			var trecho := Vector2(b.x - a.x, b.z - a.z).length()
			var passos := maxi(1, ceili(trecho / 0.5))
			for k in passos:
				var p := a.lerp(b, (float(k) + 0.5) / float(passos))
				var aqui := andado + trecho * (float(k) + 0.5) / float(passos)
				if aqui < PONTA or aqui > total - PONTA:
					continue
				for tronco in troncos:
					var d := (tronco[0] as Vector2).distance_to(Vector2(p.x, p.z)) - float(tronco[1])
					pior_tronco = minf(pior_tronco, d)
					if d < FOLGA:
						raspou_tronco += 1
						onde.append("tronco %.2f em %s (%.0f u do início, %s)" % [d, str(Vector2(p.x, p.z)), aqui, "na larga" if _na_linha(cru, p) else "numa emenda estreita"])
						break
				for casa: Dictionary in casas:
					var local: Vector3 = (p - (casa["centro"] as Vector3)).rotated(Vector3.UP, -float(casa["giro"]))
					if absf(local.x) < float((casa["meia"] as Vector2).x) + FOLGA and absf(local.z) < float((casa["meia"] as Vector2).y) + FOLGA:
						raspou_casa += 1
						onde.append("%s em %s (%.0f u do início, %s)" % [str(casa["nome"]), str(Vector2(p.x, p.z)), aqui, "na larga" if _na_linha(cru, p) else "numa emenda estreita"])
						break
			andado += trecho
		var emenda_inicio := _plano(cru[0], de) if cru.size() >= 2 else INF
		var emenda_fim := _plano(cru[cru.size() - 1], para) if cru.size() >= 2 else INF
		print("  %-28s %5.1f u, %3d pontos%s; tronco mais perto a %.2f; larga crua %.1f u, sai a %.2f e chega a %.2f" % [rotulo, total, largo.size(), "" if largo != estreito else " [= estreita]", pior_tronco, _comprimento(cru), emenda_inicio, emenda_fim])
		for linha in onde:
			print("      ", linha)
		_conferir(raspou_tronco == 0, "%s: %d ponto(s) do caminho a menos de %.1f de um tronco (o mais perto: %.2f)" % [rotulo, raspou_tronco, FOLGA, pior_tronco])
		_conferir(raspou_casa == 0, "%s: %d ponto(s) do caminho colados numa casa (a menos de %.1f da parede)" % [rotulo, raspou_casa, FOLGA])
	_conferir(diferentes >= 1, "a malha larga não mudou nenhum passeio: o caminho é o da estreita em todos")

	# --- 3. ONDE A LARGA NÃO PASSA, A ESTREITA RESPONDE ----------------------------------------
	var igreja: Vector3 = lugares.ponto("igreja")
	var praca: Vector3 = lugares.ponto("praca")
	if igreja.is_finite() and praca.is_finite():
		var ate_a_igreja: PackedVector3Array = navegacao.caminho(praca, igreja)
		var chegou_a := _plano(ate_a_igreja[ate_a_igreja.size() - 1], igreja) if ate_a_igreja.size() >= 2 else INF
		print("  praça → igreja: %d pontos, para a %.2f da âncora" % [ate_a_igreja.size(), chegou_a])
		_conferir(chegou_a < 4.0, "o caminho da praça à igreja (pela porta) para a %.1f dela" % chegou_a)
	var pier: Vector3 = ancoras.get("PierPiso", Vector3.INF)
	var gameleira: Vector3 = lugares.ponto("gameleira")
	if pier.is_finite() and gameleira.is_finite() and praca.is_finite():
		var do_pier: PackedVector3Array = navegacao.caminho(pier, gameleira)
		var saiu_de := _plano(do_pier[0], pier) if do_pier.size() >= 2 else INF
		_conferir(saiu_de < 2.0, "o caminho do píer à gameleira não sai do píer (começa a %.1f dele)" % saiu_de)
		var ao_pier: PackedVector3Array = navegacao.caminho(praca, pier)
		var chegou_ao_pier := _plano(ao_pier[ao_pier.size() - 1], pier) if ao_pier.size() >= 2 else INF
		print("  píer → gameleira sai a %.2f do píer; praça → píer chega a %.2f dele" % [saiu_de, chegou_ao_pier])
		_conferir(chegou_ao_pier < 2.0, "o caminho da praça ao píer não chega ao tabuado (para a %.1f)" % chegou_ao_pier)

	# --- 4. O PASSO SUAVE -------------------------------------------------------------------
	var filo = vale._achar_morador("filo")
	if filo != null:
		var p0: Vector3 = filo.global_position
		var p1: Vector3 = p0 + Vector3(3.0, 0.0, 0.0)
		var p2: Vector3 = p1 + Vector3(0.0, 0.0, 3.0)
		filo.set("_caminho", PackedVector3Array([p0, p1, p2]))
		filo.set("_ponto_da_vez", 1)
		filo.set("_caminho_ate", p2)
		filo.set("_refazer_em", 100.0)
		# A 0,45 da quina: além do raio de "alcançado" (0,35) e dentro do de suavizar (0,8).
		filo.global_position = p1 - Vector3(0.45, 0.0, 0.0)
		var alvo: Vector3 = filo._ponto_do_caminho(p2, 0.0)
		var na_quina := alvo.is_equal_approx(p1)
		# O arco: já virado para o trecho seguinte, mas no máximo ESPIA_ADIANTE (0,6) dentro dele.
		var no_arco: bool = absf(alvo.x - p1.x) < 0.01 and alvo.z > p1.z + 0.15 and alvo.z <= p1.z + 0.61
		print("  a 0,45 da quina, o rumo da Filó vai para %s (quina em %s)" % [str(alvo), str(p1)])
		_conferir(not na_quina and no_arco, "perto da quina o morador ainda mira a quina em cheio, e não o arco curto para o trecho seguinte (%s)" % str(alvo))
		# E o giro é com calma: de costas para o rumo, um tique de física vira menos de 20°
		# (a 9/s de antes virava 25°; a 6/s, 17°).
		var visual: Node3D = filo.get("visual")
		if visual != null:
			visual.rotation.y = 0.0
			filo._mover(Vector3(0.0, 0.0, -1.0), 1.0, 1.0 / 60.0)
			var girou := absf(wrapf(visual.rotation.y, -PI, PI))
			print("  num tique de física o corpo girou %.1f° dos 180°" % rad_to_deg(girou))
			_conferir(girou > deg_to_rad(5.0) and girou < deg_to_rad(20.0), "o corpo vira de estalo (ou não vira): %.0f° num tique de física" % rad_to_deg(girou))
	_fechar()


static func _plano(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## O ponto está (a menos de 0,1) sobre a linha quebrada?
static func _na_linha(linha: PackedVector3Array, p: Vector3) -> bool:
	var q := Vector2(p.x, p.z)
	for i in range(1, linha.size()):
		var a := Vector2(linha[i - 1].x, linha[i - 1].z)
		var b := Vector2(linha[i].x, linha[i].z)
		if Geometry2D.get_closest_point_to_segment(q, a, b).distance_to(q) < 0.1:
			return true
	return false


static func _comprimento(pontos: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, pontos.size()):
		total += Vector2(pontos[i].x - pontos[i - 1].x, pontos[i].z - pontos[i - 1].z).length()
	return total


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("FOLGA_DOS_MORADORES_OK: a malha larga fica pronta e muda os passeios ao ar livre; neles o caminho passa com folga dos troncos e das casas; onde a larga não passa (a porta da igreja, o píer) a estreita responde; e perto da quina o morador já mira o arco para o ponto seguinte")
	else:
		print("folga_dos_moradores: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicao.call():
			return true
		await process_frame
	return condicao.call()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
