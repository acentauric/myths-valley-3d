extends SceneTree
## Confere AS FRENTES DO 2D que não pedem lugar novo no vale: as armas e o ofício
## do Pedro, a capoeira do Cosme, a meta dos caititus, a caderneta e a primeira
## refeição (docs/projeto/MISSOES_DO_2D.md, 1.2, 1.5, 1.6, 3.9 a 3.11).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/frentes.gd
##
## Os acontecimentos chegam pelo fio do vale — o `Luta` emite o golpe e o bote
## esquivado, a `Pesca` o peixe, a teia o talento —, e não por
## `registrar_evento` chamado daqui. Nove perguntas:
##
##   1. AS FRENTES ESPERAM A CHEGADA E ABREM NO E: com a chegada em curso, o E no
##      Pedro não abre as armas nem o ofício; acabada, cada E abre uma frente.
##   2. A VARA E A PESCA: o ofício dá a vara; um peixe não fecha, dois fecham, e
##      paga a cocada.
##   3. O TALENTO: destravar um nó da teia fecha o passo da teia.
##   4. O FACÃO: o passo ensina a receita do facão, e o facão batido na oficina
##      fecha o passo.
##   5. O CAITITU: derrubar um caititu fecha o passo, e paga os dois peixes.
##   6. O GOLPE DE PESO: o passo ensina o golpe forte; dois não fecham, três sim.
##   7. A CAPOEIRA: só abre com o candomblé e a mesa da folha; a ginga se ensina
##      no anúncio, três esquivas fazem a lição, e ela fecha voltando ao Cosme.
##   8. A META: dez caititus abrem a do gibão sozinha, e o E no Pedro paga.
##   8b. A META DA ONÇA (#117): duas onças abrem a do patuá sozinha, na Dona
##      Zefa; o couro de onça levado a ela paga o patuá.
##   9. A CONTA SOBREVIVE A RECARREGAR: o save leva quantas vezes já aconteceu.
##  10. A CAPOEIRA ATÉ O FIM: a meia-lua volta ao Cosme, a rasteira (duas tonteadas, mungunzá) e a
##      volta final fecham a fila.

var falhas := 0
var vale
var tecla


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("FRENTES_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	vale = current_scene
	tecla = vale.get("tecla_dos_moradores")
	var jogador = vale.player
	var pedro = vale.get("pedro")
	var luta = root.get_node("/root/Luta")
	var pesca = root.get_node("/root/Pesca")
	var talentos = root.get_node("/root/Talentos")
	var inv = root.get_node("/root/Inventario")
	var receitas = root.get_node("/root/Receitas")
	var oficina = root.get_node("/root/Oficina")
	var fe = root.get_node("/root/Fe")
	var energia = root.get_node("/root/Energia")
	root.get_node("/root/Dia").pausado = true
	var armas = vale._cadeias.get("pedro_armas")
	var oficio = vale._cadeias.get("pedro_oficio")
	var metas = vale._cadeias.get("pedro_metas")
	var cosme = vale._achar_morador("cosme")
	var capoeira = vale._cadeias.get("cosme_capoeira")
	_conferir(armas != null and oficio != null and metas != null and capoeira != null and cosme != null,
		"o vale não pendurou as frentes: armas %s, ofício %s, metas %s, capoeira %s" % [str(armas), str(oficio), str(metas), str(capoeira)])
	if armas == null or oficio == null or metas == null or capoeira == null or cosme == null:
		_fechar()
		return

	# --- 1. AS FRENTES ESPERAM A CHEGADA E ABREM NO E --------------------------------
	jogador.teleportar(pedro.global_position + Vector3(1.0, 0.1, 0.6), 0.0)
	await _quadros(5)
	for i in 3:
		tecla.usar(pedro)
		await _quadros(3)
	_conferir(not armas.iniciado and not oficio.iniciado, "com a chegada em curso, o E no Pedro abriu as armas ou o ofício")
	pedro.missao = pedro.MISSOES.size()
	pedro.set("_despedida_feita", true)
	for i in 5:
		jogador.teleportar(pedro.global_position + Vector3(1.0, 0.1, 0.6), 0.0)
		await _quadros(3)
		tecla.usar(pedro)
		await _ate(func() -> bool: return false, 0.3)
	_conferir(armas.iniciado and oficio.iniciado, "acabada a chegada, o E no Pedro não abriu as frentes: armas %s, ofício %s" % [str(armas.iniciado), str(oficio.iniciado)])
	await _ate(func() -> bool: return armas.espera <= 0.0 and oficio.espera <= 0.0, 12.0)

	# --- 2. A VARA E A PESCA -----------------------------------------------------------
	_conferir(oficio.passo_atual().get("id", "") == "pesca", "o ofício não começou pela pesca")
	_conferir(inv.tem("vara_de_pescar") or root.get_node("/root/Equipamento").em_uso("vara_de_pescar"), "o passo da pesca não deu a vara do pai do Pedro")
	var cocadas: int = inv.quantidade("cocada")
	pesca.terminou.emit("robalo", 1)
	await _quadros(5)
	_conferir(oficio.missao == 0, "um peixe só fechou o passo dos dois")
	pesca.terminou.emit("traira", 1)
	_conferir(await _ate(func() -> bool: return oficio.missao >= 1, 8.0), "dois peixes não fecharam o passo da pesca")
	_conferir(inv.quantidade("cocada") == cocadas + 1, "a pesca não pagou a cocada")

	# --- 3. O TALENTO ------------------------------------------------------------------
	await _ate(func() -> bool: return oficio.espera <= 0.0, 12.0)
	talentos.pontos = maxi(int(talentos.pontos), 1)
	var no := ""
	for qual in talentos.NOS:
		if talentos.pode(str(qual)):
			no = str(qual)
			break
	_conferir(no != "", "com um ponto, nenhum nó da teia pode ser destravado")
	if no != "":
		talentos.destravar(no)
	_conferir(await _ate(func() -> bool: return oficio.acabou(), 8.0), "destravar um talento não fechou o passo da teia")

	# --- 4. O FACÃO ----------------------------------------------------------------------
	_conferir(armas.passo_atual().get("id", "") == "armas_facao", "as armas não começaram pelo facão")
	_conferir(receitas.sabe("facao"), "o passo do facão não ensinou a receita do facão")
	inv.consumir("facao", inv.quantidade("facao"))
	root.get_node("/root/Equipamento").desequipar("maos")
	inv.consumir("facao", inv.quantidade("facao"))
	inv.adicionar("lenha", 2)
	inv.adicionar("pedra", 1)
	energia.encher()
	_conferir(oficina.fabricar("facao"), "com duas lenhas e uma pedra, a oficina não bateu o facão: %s" % str(oficina.impedimento("facao")) if oficina.has_method("impedimento") else "")
	_conferir(await _ate(func() -> bool: return armas.missao >= 1, 8.0), "o facão batido não fechou o passo do facão")

	# --- 5. O CAITITU --------------------------------------------------------------------
	await _ate(func() -> bool: return armas.espera <= 0.0, 12.0)
	var assados: int = inv.quantidade("peixe_assado")
	luta.acertou.emit("golpe", "caititu", false, false)
	await _quadros(5)
	_conferir(armas.missao == 1, "acertar um caititu sem derrubar fechou o passo de derrubar")
	luta.acertou.emit("golpe", "caititu", true, false)
	_conferir(await _ate(func() -> bool: return armas.missao >= 2, 8.0), "derrubar um caititu não fechou o passo")
	_conferir(inv.quantidade("peixe_assado") == assados + 2, "o caititu derrubado não pagou os dois peixes assados")

	# --- 6. O GOLPE DE PESO --------------------------------------------------------------
	await _ate(func() -> bool: return armas.espera <= 0.0, 12.0)
	_conferir(luta.sabe("golpe_forte"), "o passo do golpe de peso não ensinou o golpe forte")
	luta.acertou.emit("golpe_forte", "caititu", false, false)
	luta.acertou.emit("golpe_forte", "caititu", false, false)
	await _quadros(5)
	_conferir(armas.missao == 2, "dois golpes fortes fecharam o passo dos três")
	luta.acertou.emit("golpe_forte", "caititu", false, false)
	_conferir(await _ate(func() -> bool: return armas.acabou(), 8.0), "três golpes fortes não fecharam o passo")

	# --- 7. A CAPOEIRA -------------------------------------------------------------------
	jogador.teleportar(cosme.global_position + Vector3(1.0, 0.1, 0.6), 0.0)
	await _quadros(5)
	tecla.usar(cosme)
	await _quadros(3)
	_conferir(not capoeira.iniciado, "a capoeira abriu sem o candomblé")
	fe.adotar("candomble")
	var mesa = vale._cadeias.get("fe_candomble")
	if mesa != null:
		mesa.iniciado = true
		mesa.missao = mesa.passos.size()
	jogador.teleportar(cosme.global_position + Vector3(1.0, 0.1, 0.6), 0.0)
	await _quadros(5)
	tecla.usar(cosme)
	_conferir(await _ate(func() -> bool: return capoeira.iniciado, 6.0), "com o candomblé e a mesa da folha, o E no Cosme não abriu a capoeira")
	_conferir(luta.sabe("ginga"), "a lição da ginga não ensinou a ginga")
	for i in 3:
		luta.esquivou.emit("caititu")
	_conferir(await _ate(func() -> bool: return capoeira.missao >= 1, 8.0), "três esquivas não fecharam a lição da ginga")
	await _ate(func() -> bool: return capoeira.espera <= 0.0, 12.0)
	jogador.teleportar(cosme.global_position + Vector3(1.0, 0.1, 0.6), 0.0)
	await _quadros(5)
	tecla.usar(cosme)
	_conferir(await _ate(func() -> bool: return capoeira.missao >= 2, 8.0), "voltar ao Cosme (E) não fechou a lição da ginga")

	# --- 8. A META -------------------------------------------------------------------------
	_conferir(not metas.iniciado, "a meta dos caititus abriu antes dos dez")
	luta.abates["caititu"] = 10
	_conferir(await _ate(func() -> bool: return metas.iniciado, 6.0), "com dez caititus, a meta do gibão não abriu")
	await _ate(func() -> bool: return metas.espera <= 0.0, 12.0)
	jogador.teleportar(pedro.global_position + Vector3(1.0, 0.1, 0.6), 0.0)
	await _quadros(5)
	tecla.usar(pedro)
	_conferir(await _ate(func() -> bool: return metas.acabou(), 8.0), "o E no Pedro não fechou a meta do gibão")

	# --- 8b. A META DA ONÇA (#117) -----------------------------------------------------
	var metas_da_onca = vale._cadeias.get("zefa_metas")
	var zefa = vale._achar_morador("zefa")
	_conferir(metas_da_onca != null and zefa != null, "o vale não pendurou a meta da onça na Dona Zefa")
	if metas_da_onca != null and zefa != null:
		_conferir(not metas_da_onca.iniciado, "a meta da onça abriu antes das duas")
		luta.abates["onca"] = 2
		_conferir(await _ate(func() -> bool: return metas_da_onca.iniciado, 6.0), "com duas onças, a meta do patuá não abriu")
		await _ate(func() -> bool: return metas_da_onca.espera <= 0.0, 12.0)
		_conferir(str(metas_da_onca.passo_atual().get("id", "")) == "meta_onca", "a meta da onça não abriu no passo do couro")
		inv.adicionar("couro_de_onca", 1)
		var patuas: int = inv.quantidade("patua")
		for i in 3:
			jogador.teleportar(zefa.global_position + Vector3(1.0, 0.1, 0.6), 0.0)
			await _quadros(3)
			tecla.usar(zefa)
			await _ate(func() -> bool: return metas_da_onca.acabou(), 2.0)
			if metas_da_onca.acabou():
				break
		_conferir(metas_da_onca.acabou(), "levar o couro de onça à Dona Zefa não fechou a meta do patuá")
		_conferir(not inv.tem("couro_de_onca"), "a Dona Zefa não ficou com o couro de onça")
		_conferir(inv.quantidade("patua") == patuas + 1, "a meta da onça não pagou o patuá")
	_conferir(inv.tem("gibao_de_couro") or root.get_node("/root/Equipamento").em_uso("gibao_de_couro"), "a meta não deu o gibão de couro")

	# --- 9. A CONTA SOBREVIVE A RECARREGAR ------------------------------------------------
	await _ate(func() -> bool: return capoeira.espera <= 0.0, 12.0)
	_conferir(capoeira.passo_atual().get("id", "") == "capoeira_meia_lua", "a capoeira não seguiu para a meia-lua")
	luta.acertou.emit("meia_lua", "caititu", false, false)
	luta.acertou.emit("meia_lua", "caititu", false, false)
	await _quadros(3)
	var guardado: Dictionary = vale.estado_para_salvar()
	capoeira._levados.clear()
	vale.restaurar_do_save(guardado)
	await _quadros(3)
	luta.acertou.emit("meia_lua", "caititu", false, false)
	await _quadros(3)
	_conferir(capoeira.missao == 2, "recarregar no meio da conta: três meias-luas fecharam o passo das quatro")
	luta.acertou.emit("meia_lua", "caititu", false, false)
	_conferir(await _ate(func() -> bool: return capoeira.missao >= 3, 8.0), "a quarta meia-lua, depois de recarregar, não fechou o passo: o save esqueceu a conta")

	# --- 10. A CAPOEIRA ATÉ O FIM ---------------------------------------------------------
	# A meia-lua volta ao Cosme, a rasteira (duas tonteadas) e a volta final: os três últimos passos
	# da fila não eram jogados por nenhum portão, e a recompensa deles (mungunzá) nunca se via paga.
	await _ate(func() -> bool: return capoeira.espera <= 0.0, 12.0)
	_conferir(str(capoeira.passo_atual().get("id", "")) == "capoeira_meia_lua_volta",
		"depois das quatro meias-luas o passo devia ser o de voltar ao Cosme: é '%s'" % str(capoeira.passo_atual().get("id", "")))
	jogador.teleportar(cosme.global_position + Vector3(1.0, 0.1, 0.6), 0.0)
	await _quadros(5)
	tecla.usar(cosme)
	_conferir(await _ate(func() -> bool: return capoeira.missao >= 4, 8.0), "voltar ao Cosme (E) não fechou a lição da meia-lua")
	await _ate(func() -> bool: return capoeira.espera <= 0.0, 12.0)
	_conferir(str(capoeira.passo_atual().get("id", "")) == "capoeira_rasteira", "depois da meia-lua o passo devia ser a rasteira")
	_conferir(luta.sabe("rasteira"), "o anúncio da lição da rasteira não ensinou a rasteira")
	var mungunzas_antes: int = inv.quantidade("mungunza")
	# Tonteou = o golpe que deixa o bicho tonto (`Luta.acertou` com `tonteou`), como a rasteira faz.
	luta.acertou.emit("rasteira", "caititu", false, true)
	await _quadros(3)
	_conferir(capoeira.missao == 4, "uma tonteada fechou o passo das duas")
	luta.acertou.emit("rasteira", "caititu", false, true)
	_conferir(await _ate(func() -> bool: return capoeira.missao >= 5, 8.0), "duas tonteadas não fecharam a lição da rasteira")
	_conferir(inv.quantidade("mungunza") >= mungunzas_antes + 2, "a lição da rasteira não pagou os dois mungunzás (%d -> %d)" % [mungunzas_antes, inv.quantidade("mungunza")])
	await _ate(func() -> bool: return capoeira.espera <= 0.0, 12.0)
	_conferir(str(capoeira.passo_atual().get("id", "")) == "capoeira_rasteira_volta", "depois da rasteira o passo devia ser o último, de voltar ao Cosme")
	jogador.teleportar(cosme.global_position + Vector3(1.0, 0.1, 0.6), 0.0)
	await _quadros(5)
	tecla.usar(cosme)
	_conferir(await _ate(func() -> bool: return capoeira.acabou(), 8.0), "o E no Cosme não fechou a capoeira: o último passo não acaba")
	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("FRENTES_OK: as armas e o ofício esperam a chegada e abrem no E no Pedro; a pesca dá a vara e conta dois peixes; o talento destravado fecha a teia; o facão sai da receita que o passo ensina; o caititu derrubado paga; o golpe forte se ensina e conta três; a capoeira só abre com o candomblé e a mesa, ensina a ginga e fecha no Cosme; dez caititus abrem a meta do gibão, que o E no Pedro paga; e a conta sobrevive a recarregar")
	else:
		print("frentes: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


## Roda quadros até `condicao` valer, com teto em SEGUNDO REAL.
func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicao.call():
			return true
		await process_frame
	return condicao.call()


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
