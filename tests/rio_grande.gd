extends SceneTree
## O RIO GRANDE NÃO DÁ PASSAGEM FORA DA PONTE (#81), E QUEM CAI NELE VOLTA PELA
## MARGEM DE CÁ (#115).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/rio_grande.gd
##
## No 2D o rio tem barranco e só se cruza pela ponte: a fazenda do convite fica
## do outro lado, e a ponte caída é a trava da jornada. No vale o rio do norte
## era raso de dar pé, com um vau ao lado da ponte, e o jogador nada. Decisão do
## autor em 06/10: fundo E barranco na margem norte (`GeoRegionRenderer`, RIO
## GRANDE); o vau acabou.
##
##   1. O VAU ACABOU: "vau" não resolve; "ponte_do_rio_grande" resolve na ponte.
##   2. A CALHA É FUNDA ao longo do rio inteiro: no meio não dá pé (lâmina acima
##      do limiar do nado), e do lado de cá o leito sobe em RAMPA QUE SE ANDA
##      (#115): da profundidade do nado à margem, nada passa de 42 graus.
##   3. O BARRANCO: ao longo do rio inteiro e da cabeceira até a moldura, o chão a
##      um passo da beira de lá fica mais alto que a água por mais que o degrau
##      sobe, e a face da calha ao alto passa de 60 graus.
##   4. A PONTE ASSENTA NO ATERRO: as duas cabeceiras na mesma altura, o
##      tabuleiro entre elas, e a estrada chega a elas em rampa que se anda.
##   5. NADANDO PARA LÁ em três pontos, com o pulo apertado, o corpo não sai da
##      água pelo lado de lá: avança até a parede e fica, nadando ou em pé no
##      fundo, sempre aquém da linha da beira.
##   6. SOB A PONTE a estrada não é rampa pelo lado de lá: entre a água e a
##      cabeceira não há chão na altura da água.
##   7. NADANDO PARA CÁ, em cinco pontos do rio e dos dois lados da ponte, o
##      corpo sai da água e pisa na margem de cá (#115: "cai no rio e não
##      consigo voltar para nenhum dos 2 lados").
##   8. A ÁGUA CORRE PARA A FOZ (#115): a correnteza do shader segue para o
##      extremo do rio que toca a costa, e não ao contrário.

const PASSO := 2.0
## Quanto a cabeceira de lá fica acima da água, no mínimo (o degrau sobe 0,4).
const ACIMA_DA_AGUA := 0.8
const TANGENTE_60 := 1.732
## O que a beira de cá pode subir por unidade (42 graus; o corpo sobe 46).
const TANGENTE_42 := 0.9
## Quanto a estrada pode subir por unidade andada (40 graus; o corpo sobe 45).
const RAMPA_QUE_SE_ANDA := 0.84

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("RIO_GRANDE_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	var vale = current_scene
	# O cartão da água funda (#96) para o vale no primeiro nado: aqui o nado é a
	# prova, e o aviso conta como já dado.
	vale._avisou_agua_funda = true
	var jogador = vale.player
	var mundo = vale.world
	var lugares = root.get_node("/root/Lugares")
	var regiao = mundo.get("_region")
	var rio: Dictionary = regiao.get("_rio_grande")
	var linha: PackedVector2Array = regiao.get("_linha_do_barranco")
	_conferir(not rio.is_empty() and linha.size() >= 3, "o vale não marcou o rio grande nem traçou o barranco")
	if rio.is_empty() or linha.size() < 3:
		_fechar()
		return
	var pontos: PackedVector2Array = rio.points
	var meia := float(rio.width) * 0.5
	var nada_a_partir: float = jogador.character_height * jogador.NADA_A_PARTIR
	root.get_node("/root/Dia").pausado = true

	# --- 1. O VAU ACABOU ---------------------------------------------------------
	_conferir(not lugares.ponto("vau").is_finite(), "o vau ainda resolve")
	var na_ponte: Vector3 = lugares.ponto("ponte_do_rio_grande")
	_conferir(na_ponte.is_finite(), "a ponte do rio grande não resolve")

	# --- 2 e 3. A CALHA E O BARRANCO, amostra a amostra -------------------------------
	var amostras := 0
	var rasas := 0
	var baixas := 0
	var suaves := 0
	var ingremes := 0
	var ultimo_do_rio := pontos.size() - 1
	for i in range(linha.size() - 1):
		var a := linha[i]
		var b := linha[i + 1]
		var comprimento := a.distance_to(b)
		if comprimento < 0.01:
			continue
		var ao_longo := (b - a) / comprimento
		var normal := Vector2(-ao_longo.y, ao_longo.x)
		if float(regiao._lado_do_barranco(a + ao_longo * minf(1.0, comprimento * 0.5) + normal * 1.0)) < 0.0:
			normal = -normal
		var s := 0.5
		while s < comprimento - 0.5:
			var c := a + ao_longo * s
			s += PASSO
			if not Geometry2D.is_point_in_polygon(c, regiao._land):
				continue
			amostras += 1
			var no_meio := Vector3(c.x, 0.0, c.y)
			var agua: float = mundo.water_level_at(no_meio)
			var de_la := c + normal * (meia + 0.8)
			var pe := c + normal * (meia - 0.3)
			var alto: float = mundo.ground_height_at(Vector3(de_la.x, 0.0, de_la.y))
			var fundo: float = mundo.ground_height_at(Vector3(pe.x, 0.0, pe.y))
			if i < ultimo_do_rio:
				# No rio: a calha funda no meio, a beira de cá rasa, e a parede de lá.
				if mundo.water_depth_at(no_meio) < nada_a_partir:
					rasas += 1
				# A BEIRA DE CÁ É RAMPA QUE SE ANDA (#115): da profundidade do nado à
				# margem, nenhum quarto de unidade sobe mais que 42 graus.
				var anterior_h := INF
				var d := 0.75
				while d <= meia + 1.6:
					var ali := c - normal * d
					var h: float = mundo.ground_height_at(Vector3(ali.x, 0.0, ali.y))
					if anterior_h != INF and h - anterior_h > 0.25 * TANGENTE_42:
						ingremes += 1
						break
					anterior_h = h
					d += 0.25
				if is_finite(agua) and alto - agua < ACIMA_DA_AGUA:
					baixas += 1
			else:
				# Da cabeceira à moldura: só o desnível, o lado de lá acima do de cá.
				var de_ca := c - normal * (meia + 0.8)
				if alto - float(mundo.ground_height_at(Vector3(de_ca.x, 0.0, de_ca.y))) < ACIMA_DA_AGUA:
					baixas += 1
			if (alto - fundo) / 1.1 < TANGENTE_60:
				suaves += 1
	_conferir(amostras > 40, "o rio grande rendeu só %d amostras" % amostras)
	_conferir(rasas == 0, "em %d de %d amostras o meio do rio grande dá pé" % [rasas, amostras])
	_conferir(baixas == 0, "em %d de %d amostras a beira de lá fica a menos de %.1f u acima da água (ou do lado de cá)" % [baixas, amostras, ACIMA_DA_AGUA])
	_conferir(suaves == 0, "em %d de %d amostras a face do barranco tem menos de 60 graus" % [suaves, amostras])
	_conferir(ingremes == 0, "em %d de %d amostras a beira de cá sobe mais de 42 graus: quem cai não sai" % [ingremes, amostras])

	# --- 4. A PONTE ASSENTA NO ATERRO ---------------------------------------------
	var ponte_do_rio = vale.get("ponte_do_rio")
	var dados: Dictionary = ponte_do_rio.ponte() if ponte_do_rio != null else {}
	_conferir(not dados.is_empty(), "o vale não tem a ponte do rio grande")
	var cabeceira_de_ca := Vector3.INF
	var para_ca := Vector3.ZERO
	if not dados.is_empty():
		var centro: Vector3 = dados["centro"]
		var ao_longo: Vector3 = dados["ao_longo"]
		var ponta := ao_longo * (float(dados["comprimento"]) * 0.5)
		var a: Vector3 = centro + ponta
		var b: Vector3 = centro - ponta
		var chao_a: float = mundo.ground_height_at(a)
		var chao_b: float = mundo.ground_height_at(b)
		_conferir(absf(chao_a - chao_b) < 0.35, "as cabeceiras da ponte ficaram em alturas diferentes: %.2f e %.2f" % [chao_a, chao_b])
		_conferir(absf(centro.y - 0.1 - maxf(chao_a, chao_b)) < 0.4, "o tabuleiro (%.2f) não assenta nas cabeceiras (%.2f, %.2f)" % [centro.y, chao_a, chao_b])
		var lado_a: float = regiao._lado_do_barranco(Vector2(a.x, a.z))
		cabeceira_de_ca = a if lado_a < 0.0 else b
		para_ca = ao_longo if lado_a < 0.0 else -ao_longo
		# A estrada chega à cabeceira de cá em rampa que se anda.
		var anterior: float = mundo.ground_height_at(cabeceira_de_ca)
		var s := 1.0
		while s <= 10.0:
			var ali: Vector3 = cabeceira_de_ca + para_ca * s
			var chao: float = mundo.ground_height_at(ali)
			_conferir(absf(chao - anterior) <= RAMPA_QUE_SE_ANDA + 0.01, "a %.0f u da cabeceira de cá a estrada sobe %.2f numa unidade" % [s, absf(chao - anterior)])
			anterior = chao
			s += 1.0
		# --- 6. SOB A PONTE a beira de lá não é rampa.
		var de_la: Vector3 = b if lado_a < 0.0 else a
		var para_la := -para_ca
		var agua: float = mundo.water_level_at(centro)
		var meio := Vector2(centro.x, centro.z)
		for lado: float in [0.2, 0.5, 0.9]:
			var ali: Vector2 = meio + Vector2(para_la.x, para_la.z) * (meia + lado)
			var chao: float = mundo.ground_height_at(Vector3(ali.x, 0.0, ali.y))
			_conferir(chao - agua >= 0.6 or chao - agua <= -0.9, "sob a ponte, a %.1f u da beira de lá, o chão fica na altura da água (%.2f acima dela): rampa" % [lado, chao - agua])
		_conferir(mundo.ground_height_at(de_la) - agua >= ACIMA_DA_AGUA, "a cabeceira de lá fica a %.2f da água" % (mundo.ground_height_at(de_la) - agua))

	# --- 5. NADANDO PARA LÁ --------------------------------------------------------
	jogador.set("_run_toggled", false)
	var provas := 0
	var escapou := 0
	var parou_cedo := 0
	var comprimento_total := 0.0
	for i in range(ultimo_do_rio):
		comprimento_total += pontos[i].distance_to(pontos[i + 1])
	for fracao: float in [0.22, 0.5, 0.78]:
		var alvo: float = comprimento_total * fracao
		var andado := 0.0
		for i in range(ultimo_do_rio):
			var trecho := pontos[i].distance_to(pontos[i + 1])
			if andado + trecho < alvo:
				andado += trecho
				continue
			var ao_longo := (pontos[i + 1] - pontos[i]) / trecho
			var c := pontos[i] + ao_longo * (alvo - andado)
			var normal := Vector2(-ao_longo.y, ao_longo.x)
			if float(regiao._lado_do_barranco(c + normal * 1.0)) < 0.0:
				normal = -normal
			if na_ponte.is_finite() and Vector2(na_ponte.x, na_ponte.z).distance_to(c) < 15.0:
				c = pontos[i] + ao_longo * clampf(alvo - andado + 18.0, 0.0, trecho)
			var partida := c - normal * 0.4
			var agua: float = mundo.water_level_at(Vector3(partida.x, 0.0, partida.y))
			jogador.teleportar(Vector3(partida.x, agua + 0.3, partida.y), atan2(normal.x, normal.y))
			await _passos_de_fisica(10)
			provas += 1
			var lado_inicial: float = regiao._lado_do_barranco(Vector2(jogador.global_position.x, jogador.global_position.z))
			Input.action_press("mv_forward")
			for tique in 420:
				if tique % 30 == 0:
					Input.action_press("mv_animation_9")
				elif tique % 30 == 2:
					Input.action_release("mv_animation_9")
				await physics_frame
			Input.action_release("mv_forward")
			Input.action_release("mv_animation_9")
			var onde := Vector2(jogador.global_position.x, jogador.global_position.z)
			var lado_final: float = regiao._lado_do_barranco(onde)
			var chao: float = mundo.ground_height_at(jogador.global_position)
			if lado_final > meia + 0.3 or (chao - agua > 0.3 and not jogador.is_swimming()):
				escapou += 1
				print("  escapou em %s: lado %.2f (beira %.2f), chão %.2f acima da água, nadando %s" % [str(c), lado_final, meia, chao - agua, str(jogador.is_swimming())])
			if lado_final - lado_inicial < 0.5:
				parou_cedo += 1
				print("  não avançou em %s: de %.2f a %.2f" % [str(c), lado_inicial, lado_final])
			break
	_conferir(provas == 3, "só %d provas de nado" % provas)
	_conferir(escapou == 0, "nadando para lá, o corpo saiu da água do lado de lá em %d de %d provas" % [escapou, provas])
	_conferir(parou_cedo == 0, "em %d provas o corpo nem chegou perto da beira de lá: a prova não provou nada" % parou_cedo)

	# --- 7. NADANDO PARA CÁ, o corpo sai (#115) ---------------------------------------
	var partidas: Array[float] = []
	for fracao: float in [0.1, 0.3, 0.5, 0.7, 0.9]:
		partidas.append(comprimento_total * fracao)
	if na_ponte.is_finite():
		var perto_da_ponte := _ao_longo_mais_perto(pontos, Vector2(na_ponte.x, na_ponte.z))
		partidas.append(perto_da_ponte - 6.0)
		partidas.append(perto_da_ponte + 6.0)
	var presos := 0
	for ao_longo_s in partidas:
		var ponto := _ponto_ao_longo(pontos, clampf(ao_longo_s, 1.0, comprimento_total - 1.0))
		var c: Vector2 = ponto["c"]
		var normal: Vector2 = ponto["normal"]
		if float(regiao._lado_do_barranco(c + normal * 1.0)) < 0.0:
			normal = -normal
		var rumo_de_ca := -normal
		var agua: float = mundo.water_level_at(Vector3(c.x, 0.0, c.y))
		var partida := c + rumo_de_ca * 0.4
		jogador.teleportar(Vector3(partida.x, agua + 0.3, partida.y), atan2(rumo_de_ca.x, rumo_de_ca.y))
		await _passos_de_fisica(10)
		Input.action_press("mv_forward")
		var saiu := false
		for tique in 360:
			if tique % 30 == 0:
				Input.action_press("mv_animation_9")
			elif tique % 30 == 2:
				Input.action_release("mv_animation_9")
			await physics_frame
			var avancou: float = (Vector2(jogador.global_position.x, jogador.global_position.z) - c).dot(rumo_de_ca)
			var chao: float = mundo.ground_height_at(jogador.global_position)
			if not jogador.is_swimming() and chao - agua > -0.1 and avancou >= meia + 1.2:
				saiu = true
				break
		Input.action_release("mv_forward")
		Input.action_release("mv_animation_9")
		if not saiu:
			presos += 1
			var onde := Vector2(jogador.global_position.x, jogador.global_position.z)
			print("  preso a %.0f u do início do rio (ponte a %.1f): parou em %s, a %.2f u do meio, chão %.2f da água, nadando %s" % [ao_longo_s, Vector2(na_ponte.x, na_ponte.z).distance_to(c) if na_ponte.is_finite() else INF, str(onde), (onde - c).dot(rumo_de_ca), mundo.ground_height_at(jogador.global_position) - agua, str(jogador.is_swimming())])
	_conferir(presos == 0, "nadando para cá, o corpo ficou preso na água em %d de %d pontos" % [presos, partidas.size()])

	# --- 8. A ÁGUA CORRE PARA A FOZ (#115) ----------------------------------------------
	var foz_no_fim: bool = regiao._tem_foz_no_extremo(pontos, true)
	var foz_no_inicio: bool = regiao._tem_foz_no_extremo(pontos, false)
	_conferir(foz_no_fim != foz_no_inicio, "o rio grande não tem a foz num só extremo (início %s, fim %s)" % [str(foz_no_inicio), str(foz_no_fim)])
	var esperado := 1.0 if foz_no_fim else -1.0
	_conferir(is_equal_approx(float(regiao._sentido_da_correnteza(rio)), esperado), "o sentido da correnteza do rio grande é %.0f, e a foz pede %.0f" % [float(regiao._sentido_da_correnteza(rio)), esperado])
	var agua_rio = load("res://assets/prototipo_3d/mar/agua_rio.gdshader")
	var sentidos: Array[float] = []
	for malha in regiao.find_children("*", "MeshInstance3D", true, false):
		var material: Material = malha.material_override
		if material == null and malha.mesh != null and malha.mesh.get_surface_count() > 0:
			material = malha.mesh.surface_get_material(0)
		if material is ShaderMaterial and (material as ShaderMaterial).shader == agua_rio:
			sentidos.append(float((material as ShaderMaterial).get_shader_parameter("sentido")))
	_conferir(esperado in sentidos, "nenhuma água de rio no vale corre com o sentido %.0f (sentidos postos: %s)" % [esperado, str(sentidos)])
	_fechar()


func _fechar() -> void:
	Input.action_release("mv_forward")
	Input.action_release("mv_animation_9")
	print("")
	if falhas == 0:
		print("RIO_GRANDE_OK: o vau acabou; o rio grande é fundo no meio e sobe em rampa que se anda pela beira de cá; a margem de lá é barranco acima da água, com face de mais de 60 graus, do mar à moldura; a ponte assenta num aterro plano com rampa que se anda, sem rampa pelo lado de lá; nadando para lá, com o pulo, o corpo não sai da água; nadando para cá, sai em todo ponto, inclusive ao lado da ponte; e a água corre para a foz")
	else:
		print("rio_grande: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


## O ponto a `alvo` unidades do início da linha do rio, e a normal dela ali.
func _ponto_ao_longo(linha: PackedVector2Array, alvo: float) -> Dictionary:
	var andado := 0.0
	for i in range(linha.size() - 1):
		var trecho := linha[i].distance_to(linha[i + 1])
		if andado + trecho < alvo and i < linha.size() - 2:
			andado += trecho
			continue
		var ao_longo := (linha[i + 1] - linha[i]) / maxf(trecho, 0.001)
		return {"c": linha[i] + ao_longo * clampf(alvo - andado, 0.0, trecho), "normal": Vector2(-ao_longo.y, ao_longo.x)}
	return {"c": linha[0], "normal": Vector2.UP}


## Quanto do rio já se andou até o ponto da linha mais perto de `p`.
func _ao_longo_mais_perto(linha: PackedVector2Array, p: Vector2) -> float:
	var melhor := INF
	var s_melhor := 0.0
	var andado := 0.0
	for i in range(linha.size() - 1):
		var trecho := linha[i].distance_to(linha[i + 1])
		var seg := linha[i + 1] - linha[i]
		var t := clampf((p - linha[i]).dot(seg) / maxf(seg.length_squared(), 0.001), 0.0, 1.0)
		var d := p.distance_to(linha[i] + seg * t)
		if d < melhor:
			melhor = d
			s_melhor = andado + trecho * t
		andado += trecho
	return s_melhor


func _passos_de_fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
