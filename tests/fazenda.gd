extends SceneTree
## Confere A JORNADA DA FAZENDA, fatias 6.1, A IDA, e 6.2, O CHAMADO (#114)
## (docs/projeto/MISSOES_DO_2D.md, 4; data/missoes_fazenda.json;
## scripts/prototipo_3d/fazenda_vale.gd).
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
##   6. O PÁTIO: chegar ao pé da escadaria fecha a ida, com a fala do Pedro.
##   6b. O CHAMADO AOS CORAJOSOS (#114): no pátio, o passo fecha sozinho; a voz do
##      mundo conta o silêncio, a anfitriã fala da escadaria, a voz conta os homens
##      de pé, e o Pedro diz que vai. O passo paga 10 de XP.
##   6c. A PORTA ESTREITA (#114): falar com o Pedro fecha a fila; a voz conta a
##      subida, a moça e a anfitriã falam, a voz conta a porta e os cinco que
##      voltam, e o Pedro fica. O capítulo 6 acaba com a fila acabada, e o passo
##      também paga 10 de XP (a recompensa dos dois passos novos é critério da #114).
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
	# O ACEITE É AUTOMÁTICO AQUI (08/10): este portão abre filas pelo E e segue; a tela de aceite
	# pausaria o vale no meio da medida (a tela tem portão próprio, tests/missao_a_vista.gd).
	if vale.get("aceite") != null:
		vale.aceite.automatico = true
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
	var na_ponte: Vector3 = lugares.ponto("ponte_do_rio_grande")
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
	_conferir(await _ate(func() -> bool: return jornada.missao >= 2, 6.0), "chegar ao pé da escadaria não fechou o passo do pátio")
	_conferir(await _ate(func() -> bool: return dialogo.ativo, 4.0), "no pé da escadaria, o Pedro não falou")
	_conferir(jornada.aconteceu("patio"), "o pátio não ficou lembrado na fila")
	await _fechar_a_fala()

	# --- 6b. O CHAMADO AOS CORAJOSOS (#114) ---------------------------------------------
	# O XP que os dois passos novos pagam (`recompensa.xp`, #107) chega pela teia de talentos.
	var xp_pago: Array[float] = []
	var talentos = root.get_node_or_null("/root/Talentos")
	_conferir(talentos != null, "o autoload Talentos não existe")
	if talentos != null:
		talentos.ganhou_xp.connect(func(quanto: float) -> void: xp_pago.append(quanto))
	for passo: Dictionary in jornada.passos:
		if str(passo.get("id", "")) in ["fazenda_chamado", "fazenda_porta_estreita"]:
			_conferir(int((passo.get("recompensa", {}) as Dictionary).get("xp", 0)) == 10, "o passo '%s' não paga 10 de XP" % str(passo.get("id", "")))
	await _ate(func() -> bool: return jornada.espera <= 0.0, 12.0)
	_conferir(await _ate(func() -> bool: return jornada.missao >= 3 or narracao.tocando(), 8.0), "com o jogador no pátio, o passo do chamado não fechou")
	_conferir(await _ate(func() -> bool: return narracao.tocando(), 6.0), "a voz do mundo não contou o silêncio")
	await _ate(func() -> bool: return narracao.frase() != "", 3.0)
	_conferir(narracao.frase().contains("silêncio"), "a cena do chamado não começou pelo silêncio: '%s'" % narracao.frase())
	await _pular_a_narracao(narracao)
	_conferir(await _ate(func() -> bool: return dialogo.ativo, 6.0), "a anfitriã não falou da escadaria")
	_conferir(dialogo._falas.size() > 0 and str(dialogo._falas[0]).contains("Bem-vindos"), "a anfitriã não deu as boas-vindas: '%s'" % (str(dialogo._falas[0]) if dialogo._falas.size() > 0 else ""))
	await _fechar_a_fala()
	_conferir(await _ate(func() -> bool: return narracao.tocando(), 6.0), "a voz do mundo não contou os homens de pé")
	await _pular_a_narracao(narracao)
	_conferir(await _ate(func() -> bool: return dialogo.ativo, 6.0), "o Pedro não disse que vai")
	_conferir(dialogo._falas.size() > 0 and str(dialogo._falas[0]).contains("Eu vou"), "o Pedro não disse 'Eu vou': '%s'" % (str(dialogo._falas[0]) if dialogo._falas.size() > 0 else ""))
	await _fechar_a_fala()
	_conferir(jornada.aconteceu("corajosos"), "o chamado aos corajosos não ficou lembrado na fila")
	_conferir(await _ate(func() -> bool: return not fazenda._em_cena, 4.0), "a cena do chamado não terminou")

	# --- 6c. A PORTA ESTREITA (#114) --------------------------------------------------------
	await _ate(func() -> bool: return jornada.espera <= 0.0 and not dialogo.ativo, 12.0)
	_conferir(str(jornada.passo_atual().get("id", "")) == "fazenda_porta_estreita", "depois do chamado não veio a porta estreita: '%s'" % str(jornada.passo_atual().get("id", "")))
	jogador.teleportar(pedro.global_position + Vector3(1.0, 0.0, 0.6), 0.0)
	await _quadros(2)
	# Nova conversa espera a fala do Pedro acabar (#121, `TeclaDosMoradores.usar`).
	await _ate(func() -> bool: return not pedro.falando_agora(), 30.0)
	vale.get("tecla_dos_moradores").usar(pedro)
	# UM AVISO DA PRIMEIRA VEZ pode abrir por cima (o da água funda, o da árvore):
	# ele para o vale, e a fila só anda com ele fechado — como o jogador faria.
	var aviso_6c = vale.get("aviso_da_primeira_vez")
	var limite_6c := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < limite_6c and not jornada.acabou():
		if aviso_6c != null and aviso_6c.aberto():
			print("  (6c) o aviso da primeira vez '%s' abriu depois do E no Pedro; fechado" % str(aviso_6c.qual))
			aviso_6c.fechar()
			await _quadros(3)
		await process_frame
	if not jornada.acabou():
		_pausa("6c depois do E no Pedro (falhou)")
		var amanhecer = root.get_node_or_null("/root/Amanhecer")
		print("  [pausa] amanhecer visível=%s; dialogo quem=%s falas=%s; queda escuro=%s" % [str(amanhecer.get("visible") if amanhecer != null else "?"), str(dialogo.quem_fala), str(dialogo._falas), str(vale.get("queda").get("_preto").modulate.a if vale.get("queda") != null else "?")])
		# Quem levou o E: o que cada fila do vale diz que o E faz no Pedro, e o passo da jornada.
		var quem_leva: Array[String] = []
		for cadeia in get_nodes_in_group(load("res://scripts/prototipo_3d/cadeia_de_missoes.gd").GRUPO):
			var faz := str(cadeia.o_que_o_e_faz(pedro))
			if faz != "":
				quem_leva.append("%s=%s" % [str(cadeia.name), faz])
		var fila = get_first_node_in_group(load("res://scripts/prototipo_3d/fila_de_falas.gd").GRUPO)
		var no_ar := str(fila._atual.get("origem", "")) + "/" + str(fila._atual.get("classe", "")) + "/modal=" + str(fila._atual.get("modal", false)) if fila != null and not fila._atual.is_empty() else "(nada no ar)"
		var na_fila: Array[String] = []
		if fila != null:
			for fala in fila._fila:
				na_fila.append(str(fala.get("origem", "")) + "/" + str(fala.get("classe", "")))
		_conferir(false, "falar com o Pedro não fechou a porta estreita (passo %s, missao %d, espera %.2f, levados %s, o_que_o_e_faz=%s, recebe=%s, pedro id=%s visível=%s, filas no E do Pedro: %s, dialogo %s, fala do Pedro %s, paused %s, fila no ar %s, fila esperando %s, cena %s)" % [str(jornada.passo_atual().get("id", "")), jornada.missao, jornada.espera, str(jornada._levados), str(jornada.o_que_o_e_faz(pedro)), str(jornada._recebe(jornada.passo_atual(), pedro)), str((pedro.get("dados") as Dictionary).get("id", "?")), str(pedro.is_visible_in_tree()), str(quem_leva), str(dialogo.ativo), str(pedro.balao.visible), str(paused), no_ar, str(na_fila), str(fazenda._em_cena)])
	await _fechar_a_fala()
	var vozes := 0
	var falas := 0
	var ate_o_fim_da_cena := Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < ate_o_fim_da_cena:
		if narracao.tocando():
			vozes += 1
			await _pular_a_narracao(narracao)
		elif dialogo.ativo:
			falas += 1
			await _fechar_a_fala()
		elif jornada.aconteceu("porta_estreita") and not fazenda._em_cena:
			break
		else:
			await process_frame
	_conferir(jornada.aconteceu("porta_estreita") and not fazenda._em_cena, "a cena da porta estreita não terminou")
	_conferir(vozes >= 3 and falas >= 3, "a porta estreita teve %d narração(ões) e %d fala(s): faltam a subida, a moça, o cerco, a anfitriã, a porta ou o Pedro" % [vozes, falas])
	_conferir(jornada.acabou(), "a fila da fazenda não acabou no fim do capítulo 6")
	_conferir(xp_pago.count(10.0) >= 2, "os dois passos novos do capítulo 6 deviam pagar 10 de XP cada, e a teia recebeu %s" % str(xp_pago))

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


## Quem segura o vale neste instante (diagnóstico #114 pós-junção).
func _pausa(rotulo: String) -> void:
	var aviso = vale.get("aviso_da_primeira_vez")
	var conquista = vale.get("conquista")
	print("  [pausa] %s: paused=%s telas_que_param=%d fala_parou=%s telas='%s' aviso=%s festa=%s dialogo=%s narracao=%s Dia=%s" % [rotulo, str(paused), int(vale.get("_telas_que_param")), str(vale.get("_fala_parou_o_vale")), str(vale.telas.aberta()), str(aviso.aberto() if aviso != null else "?"), str(conquista.ativa() if conquista != null else "?"), str(dialogo.ativo), str(vale.get("narracao").tocando()), str(root.get_node("/root/Dia").motivos_da_segurada())])


func _indice(cadeia, id: String) -> int:
	for i in cadeia.passos.size():
		if str((cadeia.passos[i] as Dictionary).get("id", "")) == id:
			return i
	return -1


## Pula a narração frase a frase até ela terminar.
func _pular_a_narracao(narracao) -> void:
	var ate := Time.get_ticks_msec() + 30000
	while narracao.tocando() and Time.get_ticks_msec() < ate:
		narracao.pular()
		await _quadros(3)
	await _quadros(3)


func _fechar_a_fala() -> void:
	var ate := Time.get_ticks_msec() + 6000
	while dialogo.ativo and Time.get_ticks_msec() < ate:
		dialogo._fechar()
		await process_frame
	await _quadros(3)


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("FAZENDA_OK: a fazenda fica do outro lado do rio grande, com o portão baixo do capítulo 6, fechado, e sem tronco no pátio; o dia espera a ponte e a fé e vem na manhã seguinte, com o arraial sentado no pátio e o Pedro na porta; o chamado abre a caixa; o Pedro conduz para o portão; no portão ele fala, a voz do mundo narra e o jogador passa para dentro com o portão aberto; o pé da escadaria fecha a ida com a fala dele; no pátio a voz conta o silêncio, a anfitriã chama os corajosos e o Pedro vai; falar com ele fecha a porta estreita, com a subida, a moça, a anfitriã, a porta e o Pedro que fica, e o capítulo 6 acaba; no dia seguinte o arraial volta para casa; e a partida que volta lembra tudo")
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
