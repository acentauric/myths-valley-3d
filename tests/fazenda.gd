extends SceneTree
## Confere A JORNADA DA FAZENDA, fatia 6.1, A IDA (docs/projeto/MISSOES_DO_2D.md, 4;
## data/missoes_fazenda.json; scripts/prototipo_3d/fazenda_vale.gd).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/fazenda.gd
##
## Oito perguntas (e as cabras da festa, que andam com o clipe de andar, no ritmo do chão —
## antes eram uma malha parada que escorregava):
##
##   1. O LUGAR: o portão e o pátio resolvem do outro lado do rio grande, o portão
##      é baixo como no capítulo 6, está fechado, e nenhum tronco atravessa a
##      fazenda.
##   2. O DIA ESPERA: com a ponte por fazer e a fé por escolher, a manhã não o
##      marca; com as duas, marca — e o arraial está sentado no pátio, a festa está
##      posta e o Pedro está na porta de casa.
##   3. O CHAMADO: perto do Pedro, a caixa diz "acorda, que é hoje".
##   4. A ESCOLTA: no passo da ida, o Pedro anda para o portão com o jogador.
##   5. O PORTÃO SE ABRE: chegar ao portão fecha a ida; o Pedro fala, a voz do mundo
##      narra, e o jogador está dentro do pátio, com o portão aberto.
##   6. O PÁTIO: chegar ao pé da escadaria fecha a fatia, com a fala do Pedro.
##   7. A VOLTA PARA CASA: na manhã seguinte o arraial sai do pátio.
##   8. O SAVE: a partida que volta tem o dia marcado, o portão aberto e a fila
##      acabada.

const RelogioDeJogo = preload("res://tests/fixtures/relogio_de_jogo.gd")

var falhas := 0
var vale
var jogador
var pedro
var dialogo


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("FAZENDA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	vale = current_scene
	jogador = vale.player
	pedro = vale.get("pedro")
	dialogo = root.get_node("/root/Dialogo")
	var mundo = vale.world
	var lugares = root.get_node("/root/Lugares")
	var relogio = root.get_node("/root/Relogio")
	root.get_node("/root/Dia").pausado = true
	var fazenda = vale.get("fazenda")
	var narracao = vale.get("narracao")
	var jornada = vale._cadeias.get("pedro_fazenda")
	var ponte = vale._cadeias.get("pedro_ponte")
	var fe = vale._cadeias.get("pedro_fe")
	_conferir(fazenda != null and narracao != null and jornada != null and ponte != null and fe != null and pedro != null,
		"o vale não tem a fazenda (%s), a narração (%s), a jornada (%s), a ponte (%s) ou a fé (%s)" % [str(fazenda), str(narracao), str(jornada), str(ponte), str(fe)])
	if fazenda == null or narracao == null or jornada == null or ponte == null or fe == null or pedro == null:
		_fechar()
		return

	# --- 1. O LUGAR -----------------------------------------------------------------
	var portao: Vector3 = lugares.ponto("portao_da_fazenda")
	var patio: Vector3 = lugares.ponto("patio_da_fazenda")
	var na_ponte: Vector3 = lugares.ponto("ponte_do_vau")
	_conferir(portao.is_finite() and patio.is_finite(), "o portão (%s) ou o pátio (%s) da fazenda não resolve" % [str(portao), str(patio)])
	if not portao.is_finite() or not patio.is_finite():
		_fechar()
		return
	_conferir(portao.z < na_ponte.z and patio.z < portao.z, "a fazenda não fica do outro lado do rio grande, para lá da ponte")
	_conferir(fazenda.altura_do_portao() > 0.3 and fazenda.altura_do_portao() < 1.3,
		"o portão tem %.2f de altura, e no capítulo 6 \"não chega a um\"" % fazenda.altura_do_portao())
	_conferir(not fazenda.portao_aberto(), "o portão da fazenda começa aberto")
	var regiao = mundo.get("_region")
	var atravessa := 0
	for tronco in regiao._tree_trunks:
		var ponto: Vector2 = tronco.get("point", Vector2.INF)
		if absf(ponto.x - patio.x) < 9.0 and ponto.y < portao.z + 1.0 and ponto.y > patio.z - 13.0:
			atravessa += 1
	_conferir(atravessa == 0, "%d tronco(s) da mata atravessam o pátio ou o casarão" % atravessa)

	# --- 2. O DIA ESPERA -------------------------------------------------------------
	pedro.missao = pedro.MISSOES.size()
	pedro.set("_despedida_feita", true)
	relogio.dia_comecou.emit(2, 0, 1)
	await _quadros(5)
	_conferir(not fazenda.dia_marcado(), "a manhã marcou o dia da fazenda com a ponte por fazer e a fé por escolher")
	var jornada_do_dia = root.get_node("/root/Jornada")
	_conferir(not jornada_do_dia.marcada(), "a Jornada foi marcada antes de o dia da fazenda chegar")
	ponte.iniciado = true
	ponte.missao = ponte.passos.size()
	ponte.despedida_feita = true
	fe.iniciado = true
	fe.missao = _indice(fe, "fe_escolher") + 1
	relogio.dia_comecou.emit(3, 0, 1)
	_conferir(await _ate(func() -> bool: return fazenda.dia_marcado() and jornada.iniciado, 4.0),
		"com a ponte de pé e a fé escolhida, a manhã seguinte não marcou o dia da fazenda")
	# O CARTÃO DO AMANHECER lê a `Jornada` (`queda._lembretes_do_dia`), e ninguém a marcava no 3D:
	# "hoje é o dia da fazenda" nunca aparecia. A manhã que marca o dia marca também a Jornada.
	_conferir(jornada_do_dia.marcada() and jornada_do_dia.hoje(),
		"a manhã marcou o dia da fazenda e deixou a Jornada sem marcar: o cartão do amanhecer não lembra dela")
	var lembretes_de_hoje: Array = vale.get_node("Queda")._lembretes_do_dia()
	_conferir(lembretes_de_hoje.size() == 1 and str(lembretes_de_hoje[0]).strip_edges() != "",
		"no dia da fazenda o cartão do amanhecer não traz o lembrete: %s" % str(lembretes_de_hoje))
	await _quadros(4)
	var sentados := 0
	for morador in vale.moradores:
		if morador.is_visible_in_tree() and Vector2(morador.global_position.x - patio.x, morador.global_position.z - patio.z).length() < 14.0:
			sentados += 1
	_conferir(sentados >= 4, "só %d morador(es) estão no pátio da fazenda no dia dela" % sentados)
	await _as_cabras_andam_com_as_pernas(fazenda)
	var interiores = vale.get("interiores")
	var porta: Vector3 = interiores.sala_de("casa").lugar_de_esperar_fora()
	_conferir(Vector2(pedro.global_position.x - porta.x, pedro.global_position.z - porta.z).length() < 3.0, "o Pedro não veio à porta de casa")

	# --- 3. O CHAMADO -------------------------------------------------------------------
	await _ate(func() -> bool: return jornada.espera <= 0.0, 12.0)
	jogador.teleportar(pedro.global_position + Vector3(1.0, 0.1, 0.6), 0.0)
	_conferir(await _ate(func() -> bool: return dialogo.ativo, 4.0), "perto do Pedro, a caixa não abriu com o chamado")
	_conferir(jornada.aconteceu("chamou"), "o chamado não ficou lembrado na fila")
	await _fechar_a_fala()

	# --- 4. A ESCOLTA -------------------------------------------------------------------
	var antes := Vector2(pedro.global_position.x - portao.x, pedro.global_position.z - portao.z).length()
	var andou := false
	var limite := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < limite:
		jogador.teleportar(pedro.global_position + Vector3(0.8, 0.1, 0.8), 0.0)
		await _ate(func() -> bool: return false, 0.5)
		if Vector2(pedro.global_position.x - portao.x, pedro.global_position.z - portao.z).length() < antes - 2.0:
			andou = true
			break
	_conferir(andou, "no passo da ida, o Pedro não andou para o portão")

	# --- 5. O PORTÃO SE ABRE ---------------------------------------------------------------
	jogador.teleportar(mundo.ground_position(portao + Vector3(0, 0, 3.0), 0.1), 0.0)
	_conferir(await _ate(func() -> bool: return jornada.missao >= 1, 6.0), "chegar ao portão não fechou a ida")
	_conferir(await _ate(func() -> bool: return dialogo.ativo, 4.0), "no portão, o Pedro não falou do portão")
	await _fechar_a_fala()
	_conferir(await _ate(func() -> bool: return narracao.tocando(), 4.0), "a voz do mundo não narrou a chegada")
	var primeira := ""
	await _ate(func() -> bool: return narracao.frase() != "", 3.0)
	primeira = narracao.frase()
	_conferir(primeira.contains("descampado"), "a narração não começou pelo descampado: '%s'" % primeira)
	var ate_o_fim := Time.get_ticks_msec() + 30000
	while narracao.tocando() and Time.get_ticks_msec() < ate_o_fim:
		narracao.pular()
		await _quadros(3)
	_conferir(not narracao.tocando(), "a narração não terminou")
	await _quadros(5)
	_conferir(fazenda.portao_aberto() and jornada.aconteceu("portao"), "depois da narração o portão continua fechado")
	_conferir(jogador.global_position.z < portao.z - 1.0, "depois da narração o jogador não está dentro do pátio (z %.1f, portão %.1f)" % [jogador.global_position.z, portao.z])
	_conferir(jogador.is_physics_processing(), "depois da narração o jogador continua parado")

	# --- 6. O PÁTIO ---------------------------------------------------------------------------
	await _ate(func() -> bool: return jornada.espera <= 0.0, 12.0)
	_conferir(str(jornada.passo_atual().get("id", "")) == "fazenda_chegada", "depois do portão não veio o pátio")
	jogador.teleportar(mundo.ground_position(patio, 0.1), PI)
	_conferir(await _ate(func() -> bool: return jornada.acabou(), 6.0), "chegar ao pé da escadaria não fechou a fatia")
	_conferir(await _ate(func() -> bool: return dialogo.ativo, 4.0), "no pé da escadaria, o Pedro não falou")
	_conferir(jornada.aconteceu("patio"), "o pátio não ficou lembrado na fila")
	await _fechar_a_fala()

	# --- 7. A VOLTA PARA CASA -------------------------------------------------------------------
	relogio.dia_comecou.emit(4, 0, 1)
	await _quadros(6)
	var ainda := 0
	for morador in vale.moradores:
		if morador.is_visible_in_tree() and Vector2(morador.global_position.x - patio.x, morador.global_position.z - patio.z).length() < 14.0:
			ainda += 1
	_conferir(ainda == 0 and jornada.aconteceu("liberou"), "no dia seguinte, %d morador(es) continuam no pátio da fazenda" % ainda)

	# --- 8. O SAVE ------------------------------------------------------------------------------------
	var guardado: Dictionary = vale.estado_para_salvar()
	vale.restaurar_do_save(guardado)
	await _quadros(10)
	await _ate(func() -> bool: return false, 0.8)
	_conferir(fazenda.dia_marcado() and fazenda.portao_aberto() and jornada.acabou(), "a partida que volta esqueceu o dia da fazenda")
	_fechar()


## As três cabras da festa: cada uma tem o clipe de andar, e quando passeiam (o Tween as leva) o
## clipe toca no ritmo do chão (0,7 u/s); paradas, ele congela. Em segundos de JOGO.
func _as_cabras_andam_com_as_pernas(fazenda) -> void:
	var cabras: Array = fazenda.get("_cabras")
	_conferir(cabras.size() == int(fazenda.CABRAS), "a festa devia ter %d cabras, tem %d" % [fazenda.CABRAS, cabras.size()])
	for cabra in cabras:
		_conferir(is_instance_valid(cabra) and cabra.has_method("animador") and cabra.animador().tem_clipe(),
			"uma cabra da festa não tem o clipe de andar (é a malha parada do adereço, que escorrega?)")
	var relogio := RelogioDeJogo.new()
	root.add_child(relogio)
	var visto := {"andaram": 0, "sem_clipe": 0, "ritmo": 0.0, "seguidos": 0}
	await relogio.ate(func() -> bool: return _cabras_passearam(cabras, visto), 40.0)
	_conferir(visto["andaram"] >= 30, "nenhuma cabra da festa saiu a passeio com o clipe tocando em 40 s de jogo: %s" % str(visto))
	_conferir(visto["sem_clipe"] == 0, "houve quadro em que uma cabra da festa andava sem o clipe tocando: %s" % str(visto))
	_conferir(float(visto["ritmo"]) > 0.3, "o clipe da cabra da festa toca devagar demais: %.2fx" % float(visto["ritmo"]))
	relogio.queue_free()


## Um quadro dos passeios: conta as cabras andando com o clipe tocando e as que andam sem ele.
func _cabras_passearam(cabras: Array, visto: Dictionary) -> bool:
	for cabra in cabras:
		if is_instance_valid(cabra) and cabra.has_method("andando") and cabra.andando():
			var an = cabra.animador()
			if an.animacao != null and an.animacao.is_playing() and an.animacao.speed_scale > 0.3:
				visto["andaram"] += 1
				visto["seguidos"] = 0
				visto["ritmo"] = maxf(float(visto["ritmo"]), an.animacao.speed_scale)
			else:
				# Um quadro sem o clipe é o `_process` do animador respondendo ao `andar`; quatro seguidos, não.
				visto["seguidos"] += 1
				if visto["seguidos"] > 3:
					visto["sem_clipe"] += 1
	return visto["andaram"] >= 30


func _indice(cadeia, id: String) -> int:
	for i in cadeia.passos.size():
		if str((cadeia.passos[i] as Dictionary).get("id", "")) == id:
			return i
	return -1


func _fechar_a_fala() -> void:
	var ate := Time.get_ticks_msec() + 6000
	while dialogo.ativo and Time.get_ticks_msec() < ate:
		dialogo._fechar()
		await process_frame
	await _quadros(3)


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("FAZENDA_OK: a fazenda fica do outro lado do rio grande, com o portão baixo do capítulo 6, fechado, e sem tronco no pátio; o dia espera a ponte e a fé e vem na manhã seguinte, com o arraial sentado no pátio e o Pedro na porta; o chamado abre a caixa; o Pedro conduz para o portão; no portão ele fala, a voz do mundo narra e o jogador passa para dentro com o portão aberto; o pé da escadaria fecha a fatia com a fala dele; no dia seguinte o arraial volta para casa; e a partida que volta lembra tudo")
	else:
		print("fazenda: %d falha(s)" % falhas)
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
