extends "res://tests/suite/caso.gd"
## O PEDRO CONDUZ PELA ESTRADA E PELA PONTE (playtest de 07/10: "ao sair da praça, o Pedro tá
## correndo por trás da casa ao invés de pegar a estrada; o mesmo se repete na água do rio, ao
## invés dele passar na ponte").
##
##     .\tools\prototipo_3d\testar.ps1 -Teste pedro_pela_estrada
##
## O caminho da malha é o mais curto, e o mais curto corta por trás das casas e beira a água.
## `Navegacao.caminho_pela_estrada` vai pela rua: da partida à rua pela malha, pela rua (as
## linhas das ruas ligadas nos cruzamentos — a ponte é rua) e da rua à chegada pela malha.
##
##   1. O CAMINHO PELA ESTRADA EXISTE entre os lugares da chegada que o Pedro conduz — do
##      píer à praça, da praça à casa da Zefa, da casa da Zefa à casa de taipa — e chega.
##   2. ELE VAI PELA RUA: fora dos trechos de ponta (os primeiros e os últimos metros, da
##      partida até a rua e da rua até a porta), ao menos NA_RUA do comprimento dele está em
##      cima de uma rua, e mais do que o caminho da malha estaria.
##   3. ATRAVESSA O RIO PELA PONTE: o ponto do caminho que cruza o rio central está a até
##      PONTE_ATE da ponte, e nenhum ponto molha o pé fora dela.
##   4. É ESSE O CAMINHO QUE O PEDRO SEGUE conduzindo: no passo da chave, o caminho dele
##      prefere a estrada.

const NA_RUA := 0.7
const PONTA := 7.0
const PONTE_ATE := 6.0
const BEIRA_DA_RUA := 0.6

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("PEDRO_PELA_ESTRADA_FALHOU: " + rotulo)
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
	_conferir(navegacao != null and await _ate(func() -> bool: return navegacao.esta_pronta(), 60.0), "a malha de navegação não ficou pronta")
	if navegacao == null or not navegacao.esta_pronta():
		_fechar()
		return
	var lugares = root.get_node("/root/Lugares")
	var ancoras: Dictionary = mundo.ancoras
	var ponte: Vector3 = ancoras.get("Ponte do rio central", Vector3.INF)
	_conferir(ponte.is_finite(), "o vale não tem a ponte do rio central")
	# Os trechos que o Pedro conduz na chegada e que têm rua: o do píer à praça não tem (a
	# praia), e a malha sozinha serve nele. O da praça à casa da Zefa é o da queixa — "ao sair
	# da praça, o Pedro tá correndo por trás da casa" — e cruza o rio central.
	var trechos := [
		["praça → casa da Zefa", lugares.ponto("praca"), lugares.ponto("casa_da_zefa"), true],
		["casa da Zefa → casa de taipa", lugares.ponto("casa_da_zefa"), lugares.ponto("casa_de_taipa"), false],
		["casa de taipa → lavoura", lugares.ponto("casa_de_taipa"), lugares.ponto("lavoura"), false],
		["praça → poço", lugares.ponto("praca"), lugares.ponto("poco"), false],
	]
	var melhorou := 0
	for trecho in trechos:
		var rotulo: String = trecho[0]
		var de: Vector3 = trecho[1]
		var para: Vector3 = trecho[2]
		if not de.is_finite() or not para.is_finite():
			_conferir(false, "%s: um dos lugares não resolve" % rotulo)
			continue
		var direto: PackedVector3Array = navegacao.caminho(de, para)
		var pela_rua: PackedVector3Array = navegacao.caminho_pela_estrada(de, para)
		_conferir(pela_rua.size() >= 2, "%s: não há caminho pela estrada" % rotulo)
		if pela_rua.size() < 2:
			continue
		var fim: Vector3 = pela_rua[pela_rua.size() - 1]
		_conferir(Vector2(fim.x - para.x, fim.z - para.z).length() < 3.5, "%s: o caminho pela estrada acaba a %.1f da chegada" % [rotulo, Vector2(fim.x - para.x, fim.z - para.z).length()])
		var na_rua := _fracao_na_rua(pela_rua, regiao)
		var na_rua_direto := _fracao_na_rua(direto, regiao)
		var pela_malha := pela_rua == direto
		print("  %-30s %5.1f u, %3.0f%% na rua%s (a malha sozinha: %3.0f%%)" % [rotulo, _comprimento(pela_rua), na_rua * 100.0, " [caiu na malha]" if pela_malha else "", na_rua_direto * 100.0])
		# No trecho da queixa a rua tem de ser escolhida e andada; nos outros, quando a rua é
		# escolhida ela tem de ser andada de verdade.
		if bool(trecho[3]):
			_conferir(not pela_malha, "%s: o caminho pela estrada caiu no da malha" % rotulo)
		if not pela_malha:
			_conferir(na_rua >= NA_RUA, "%s: só %.0f%% do caminho pela estrada está na rua" % [rotulo, na_rua * 100.0])
		if na_rua > na_rua_direto + 0.05:
			melhorou += 1
		# O RIO: onde o caminho cruza a água, é na ponte.
		# (Fora das pontas: o cais do píer é sobre a água, e é de onde se parte.)
		var cruzou_fora := false
		var andado_ate := 0.0
		var total_do_trecho := _comprimento(pela_rua)
		for i in range(1, pela_rua.size()):
			var p: Vector3 = pela_rua[i]
			andado_ate += Vector2(p.x - pela_rua[i - 1].x, p.z - pela_rua[i - 1].z).length()
			if andado_ate < PONTA or andado_ate > total_do_trecho - PONTA:
				continue
			if not mundo.is_on_land(p) and ponte.is_finite() and Vector2(p.x - ponte.x, p.z - ponte.z).length() > PONTE_ATE:
				cruzou_fora = true
				_conferir(false, "%s: o caminho molha o pé em %s, a %.1f da ponte" % [rotulo, str(p), Vector2(p.x - ponte.x, p.z - ponte.z).length()])
				break
		if not cruzou_fora and _cruza_o_rio(pela_rua, regiao):
			var perto_da_ponte := false
			for p in pela_rua:
				if Vector2(p.x - ponte.x, p.z - ponte.z).length() <= PONTE_ATE:
					perto_da_ponte = true
			_conferir(perto_da_ponte, "%s: o caminho cruza o rio central longe da ponte" % rotulo)
	_conferir(melhorou >= 1, "em nenhum trecho o caminho pela estrada ficou mais na rua que o da malha: a estrada não está sendo preferida")

	# --- 4. É ESSE O CAMINHO QUE O PEDRO SEGUE -------------------------------------------------
	# Na chave da Zefa (da praça à casa dela), com o Pedro saindo da praça.
	var pedro = vale.pedro
	var praca: Vector3 = lugares.ponto("praca")
	if pedro != null and praca.is_finite() and pedro.ir_ao_passo("chave_zefa"):
		pedro.global_position = mundo.ground_position(praca + Vector3(2.0, 0.0, 2.0)) + Vector3(0.0, 0.1, 0.0)
		pedro.velocity = Vector3.ZERO
		pedro.retomar()
		for i in 8:
			vale.player.teleportar(pedro.global_position + Vector3(1.0, 0.1, 1.0), 0.0)
			await _frames(10)
		_conferir(bool(pedro.get("_prefere_a_estrada")), "conduzindo, o Pedro não prefere a estrada")
		var caminho_dele: PackedVector3Array = pedro.get("_caminho")
		_conferir(caminho_dele.size() >= 2, "conduzindo a chave da Zefa, o Pedro não tem caminho")
		if caminho_dele.size() >= 2:
			var na_rua_dele := _fracao_na_rua(caminho_dele, regiao)
			print("  o caminho do Pedro da praça à Zefa: %d pontos, %.0f%% na rua" % [caminho_dele.size(), na_rua_dele * 100.0])
			_conferir(na_rua_dele >= NA_RUA * 0.8, "o caminho que o Pedro segue da praça à Zefa está só %.0f%% na rua" % (na_rua_dele * 100.0))
	_fechar()


## A fração do comprimento do caminho (fora das pontas) que está em cima de uma rua.
func _fracao_na_rua(pontos: PackedVector3Array, regiao) -> float:
	var total := _comprimento(pontos)
	if total <= PONTA * 2.0 + 1.0:
		return 1.0
	var andado := 0.0
	var medido := 0.0
	var na_rua := 0.0
	for i in range(1, pontos.size()):
		var a: Vector3 = pontos[i - 1]
		var b: Vector3 = pontos[i]
		var trecho := Vector2(b.x - a.x, b.z - a.z).length()
		var passos := maxi(1, ceili(trecho / 1.0))
		for k in passos:
			var p := a.lerp(b, (float(k) + 0.5) / float(passos))
			var aqui := andado + trecho * (float(k) + 0.5) / float(passos)
			if aqui < PONTA or aqui > total - PONTA:
				continue
			var pedaco := trecho / float(passos)
			medido += pedaco
			if float(regiao._distancia_da_rua(Vector2(p.x, p.z))) <= BEIRA_DA_RUA:
				na_rua += pedaco
		andado += trecho
	return 1.0 if medido <= 0.0 else na_rua / medido


func _cruza_o_rio(pontos: PackedVector3Array, regiao) -> bool:
	if not ("_rivers" in regiao):
		return false
	for rio in regiao._rivers:
		var linha: PackedVector2Array = rio["points"]
		for i in range(1, pontos.size()):
			var a := Vector2(pontos[i - 1].x, pontos[i - 1].z)
			var b := Vector2(pontos[i].x, pontos[i].z)
			for k in range(1, linha.size()):
				if Geometry2D.segment_intersects_segment(a, b, linha[k - 1], linha[k]) != null:
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
		print("PEDRO_PELA_ESTRADA_OK: o caminho pela estrada existe entre os lugares da chegada, vai pela rua mais que o da malha, atravessa o rio só na ponte, e é o caminho que o Pedro segue quando conduz")
	else:
		print("pedro_pela_estrada: %d falha(s)" % falhas)
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
