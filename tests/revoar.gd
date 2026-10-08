extends SceneTree
## Confere O CAPÍTULO 7, O REVOAR DAS ASAS NEGRAS (docs/projeto/MISSOES_DO_2D.md, 4;
## docs/enredo/capitulo-07.md; data/missoes_revoar.json; scripts/prototipo_3d/revoar_vale.gd; #31).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/revoar.gd
##
## Dez perguntas:
##
##   1. O LUGAR: as ruínas, a torre e a estátua resolvem no `Lugares`, em terra firme, atrás do
##      monte a oeste da fazenda; o piso de cima da torre é chão de verdade, a 3,6 do pé.
##   2. A FILA ESPERA: com a porta estreita por fechar, o capítulo não começa; fechada, começa
##      sozinho, e o quarto fecha no pátio.
##   3. O QUARTO (7.1): a voz conta, a velha oferece três trocas; aceitar a primeira tira
##      fôlego e paga os réis; recusar as outras é o caminho; as miragens voltam-se ao Pedro.
##   4. A MÃO (7.1): o E no Pedro fecha o passo com a resposta dele; a voz conta a fuga, a
##      moça pede perdão, a voz conta o revoar — e o arraial corre para as ruínas.
##   5. O ABRIGO (7.2): chegar às ruínas fecha o passo; a voz conta a noite, a anciã conta,
##      a voz conta o senhor, e o Pedro fala da torre.
##   6. AS ARMAS (7.3): no alto da torre o E é do capítulo e dá a lança e o escudo.
##   7. O CHAMADO (7.3): sem a lança na mão e o escudo nas Mãos o E não chama; com eles,
##      chama — a fera nasce nas ruínas, caçando, com o senhor ao lado do jogador.
##   8. O EMBATE (7.4): a lança derruba a fera; abaixo de um terço da vida o senhor dá o
##      sinal e ela fica tonta; derrubada, a voz conta a pedra, a estátua fica e a fera não
##      volta com os dias.
##   9. A LIBERTAÇÃO (7.5): o E na estátua traz o pedido e a pergunta; deixar o escudo o tira
##      da mochila e o põe de pedra ao lado da coruja; o amanhecer fecha a fila, e o Pedro
##      fica livre.
##  10. A LÍNGUA E O SAVE: as trocas têm oferta e pergunta nos três idiomas; a fila leva o
##      capítulo no save.
var falhas := 0
var vale
var jogador
var pedro
var dialogo
var narracao
var revoar
var fila


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("REVOAR_FALHOU: " + rotulo)
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
	narracao = vale.get("narracao")
	revoar = vale.get("revoar")
	fila = vale._cadeias.get("pedro_revoar")
	var jornada = vale._cadeias.get("pedro_fazenda")
	var mundo = vale.world
	var lugares = root.get_node("/root/Lugares")
	var inv = root.get_node("/root/Inventario")
	var equip = root.get_node("/root/Equipamento")
	var energia = root.get_node("/root/Energia")
	var jogo = root.get_node("/root/Jogo")
	var luta = vale.get_node_or_null("Luta")
	var tecla = vale.get("tecla_dos_moradores")
	root.get_node("/root/Dia").pausado = true
	_conferir(revoar != null and fila != null and jornada != null and pedro != null and narracao != null and luta != null,
		"o vale não montou o capítulo 7: revoar %s, fila %s, fazenda %s, Pedro %s, narração %s, luta %s" % [str(revoar), str(fila), str(jornada), str(pedro), str(narracao), str(luta)])
	if revoar == null or fila == null or jornada == null or pedro == null or narracao == null or luta == null:
		_fechar()
		return

	# --- 1. O LUGAR ------------------------------------------------------------------------------
	var patio: Vector3 = lugares.ponto("patio_da_fazenda")
	for nome in ["ruinas_do_palacete", "torre_da_capela", "estatua_da_coruja"]:
		var p: Vector3 = lugares.ponto(nome)
		_conferir(p != lugares.NENHUM, "o Lugares não resolve '%s'" % nome)
		if p != lugares.NENHUM:
			_conferir(mundo.is_on_land(p), "'%s' (%s) não é terra firme" % [nome, str(p)])
			_conferir(p.x < patio.x - 20.0, "'%s' (%s) não está a oeste da fazenda (pátio em %s)" % [nome, str(p), str(patio)])
	var topo: Vector3 = revoar.topo_da_torre()
	var pe: Vector3 = lugares.ponto("torre_da_capela")
	_conferir(topo.y - pe.y > 3.0 and topo.y - pe.y < 4.5, "o alto da torre fica a %.1f do pé, e era 3,6" % (topo.y - pe.y))
	var espaco := root.get_world_3d().direct_space_state
	var raio := PhysicsRayQueryParameters3D.create(topo + Vector3.UP * 2.0, topo - Vector3.UP * 1.0)
	var batida := espaco.intersect_ray(raio)
	_conferir(not batida.is_empty() and absf(float((batida.get("position", Vector3.ZERO) as Vector3).y) - topo.y) < 0.3,
		"o piso de cima da torre não é chão de verdade (raio bateu em %s, e o alto é %s)" % [str(batida.get("position", "nada")), str(topo)])
	_conferir(revoar.get_node_or_null("Rampa") != null and revoar.get_node_or_null("RampaCorpo") != null, "a torre não tem a rampa de pedra com corpo")
	_conferir(not revoar.estatua_posta(), "a estátua está nas ruínas antes do embate")

	# --- 2. A FILA ESPERA ----------------------------------------------------------------------------
	await _quadros(6)
	_conferir(not fila.iniciado, "o capítulo 7 começou com a porta estreita por fechar")
	jornada.iniciado = true
	jornada.missao = jornada.passos.size()
	jornada.despedida_feita = true
	for evento in ["dia_da_fazenda", "chamou", "portao", "patio", "corajosos", "porta_estreita"]:
		jornada.registrar_evento(evento)
	jogador.teleportar(patio + Vector3(0.0, 0.1, 2.0), PI)
	pedro.global_position = patio + Vector3(1.2, 0.05, 2.6)
	await _quadros(3)
	_conferir(await _ate(func() -> bool: return fila.iniciado, 8.0), "com a porta estreita fechada o capítulo 7 não começou sozinho")
	if not fila.iniciado:
		_fechar()
		return

	# --- 3. O QUARTO -----------------------------------------------------------------------------------
	energia.definir(energia.maximo())
	var folego_antes: float = energia.atual
	var reis_antes: int = jogo.dinheiro
	var quarto := await _tocar_a_cena(func() -> bool: return fila.passou("revoar_quarto") and not revoar.em_cena(), [true, false, false], 120000)
	_conferir(bool(quarto["acabou"]), "a cena do quarto não terminou (vozes %d, falas %d, perguntas %d, passo %s, em cena %s)" % [quarto["vozes"], quarto["falas"], quarto["perguntas"], str(fila.passo_atual().get("id", "")), str(revoar.em_cena())])
	_conferir(int(quarto["perguntas"]) == 3, "a velha fez %d pergunta(s), e eram 3 trocas" % int(quarto["perguntas"]))
	_conferir(int(quarto["vozes"]) >= 3, "o quarto teve %d narração(ões): faltam a cama, o aceite ou as miragens" % int(quarto["vozes"]))
	_conferir(fila.aconteceu("troca:1") and fila.aconteceu("recusa:2") and fila.aconteceu("recusa:3"), "as trocas não ficaram na memória da fila: %s" % str(fila._levados.keys()))
	_conferir(energia.atual < folego_antes - energia.maximo() * 0.3, "aceitar a troca não tirou o fôlego (%.0f → %.0f)" % [folego_antes, energia.atual])
	_conferir(jogo.dinheiro == reis_antes + 1200, "a primeira troca não pagou os 1.200 réis (%d → %d)" % [reis_antes, jogo.dinheiro])

	# --- 4. A MÃO ----------------------------------------------------------------------------------------
	await _ate(func() -> bool: return fila.espera <= 0.0 and not dialogo.ativo and not narracao.tocando(), 20.0)
	_conferir(str(fila.passo_atual().get("id", "")) == "revoar_mao", "depois do quarto não veio a mão do Pedro: '%s'" % str(fila.passo_atual().get("id", "")))
	var aviso = vale.get("aviso_da_primeira_vez")
	for i in 4:
		jogador.teleportar(pedro.global_position + Vector3(1.0, 0.05, 0.6), 0.0)
		await _quadros(3)
		tecla.usar(pedro)
		var limite := Time.get_ticks_msec() + 3000
		while Time.get_ticks_msec() < limite and not fila.passou("revoar_mao"):
			if aviso != null and aviso.aberto():
				aviso.fechar()
				await _quadros(3)
			await process_frame
		if fila.passou("revoar_mao"):
			break
		await _fechar_a_fala()
	_conferir(fila.passou("revoar_mao"), "o E no Pedro não fechou a mão (passo %s, o E faz '%s')" % [str(fila.passo_atual().get("id", "")), str(fila.o_que_o_e_faz(pedro))])
	var fuga := await _tocar_a_cena(func() -> bool: return fila.aconteceu("fuga") and not revoar.em_cena(), [], 90000)
	_conferir(bool(fuga["acabou"]), "a cena da fuga não terminou")
	_conferir(int(fuga["vozes"]) >= 2 and int(fuga["falas"]) >= 1, "a fuga teve %d narração(ões) e %d fala(s): faltam os corredores, a moça ou o revoar" % [int(fuga["vozes"]), int(fuga["falas"])])
	var ruinas: Vector3 = revoar.ruinas()
	var correndo := 0
	for morador in vale.moradores:
		var destino = morador.get("_destino_avulso")
		if destino is Vector3 and (destino as Vector3).is_finite() and Vector2((destino as Vector3).x - ruinas.x, (destino as Vector3).z - ruinas.z).length() < 8.0:
			correndo += 1
	_conferir(correndo >= 3, "só %d morador(es) correram para as ruínas" % correndo)

	# --- 5. O ABRIGO ---------------------------------------------------------------------------------------
	await _ate(func() -> bool: return fila.espera <= 0.0 and not dialogo.ativo, 20.0)
	_conferir(str(fila.passo_atual().get("id", "")) == "revoar_abrigo", "depois da fuga não veio o abrigo: '%s'" % str(fila.passo_atual().get("id", "")))
	jogador.teleportar(ruinas + Vector3(0.0, 0.1, 0.5), 0.0)
	pedro.global_position = ruinas + Vector3(1.5, 0.05, 1.5)
	var relato := await _tocar_a_cena(func() -> bool: return fila.aconteceu("relato") and not revoar.em_cena(), [], 120000)
	_conferir(bool(relato["acabou"]), "a cena do abrigo não terminou (passo %s)" % str(fila.passo_atual().get("id", "")))
	_conferir(int(relato["vozes"]) >= 2 and int(relato["falas"]) >= 2, "o abrigo teve %d narração(ões) e %d fala(s): faltam a noite, a anciã, o senhor ou o Pedro" % [int(relato["vozes"]), int(relato["falas"])])

	# --- 6. AS ARMAS -----------------------------------------------------------------------------------------
	await _ate(func() -> bool: return fila.espera <= 0.0 and not dialogo.ativo, 20.0)
	_conferir(str(fila.passo_atual().get("id", "")) == "revoar_armas", "depois do abrigo não vieram as armas: '%s'" % str(fila.passo_atual().get("id", "")))
	jogador.teleportar(topo + Vector3(0.0, 0.15, 0.3), PI)
	await _quadros(6)
	_conferir(not revoar.alvo_do_e().is_empty(), "no alto da torre o capítulo não responde ao E")
	var foco = get_first_node_in_group("foco_do_e")
	_conferir(foco != null and foco.dono() == revoar, "no alto da torre o E é de %s, e não do capítulo" % (str(foco.dono()) if foco != null else "?"))
	revoar.usar_o_e()
	await _quadros(3)
	_conferir(inv.tem("lanca_de_safira") and inv.tem("escudo_de_safira"), "o E nos destroços não deu a lança e o escudo")
	_conferir(await _ate(func() -> bool: return fila.passou("revoar_armas"), 8.0), "a lança na mochila não fechou o passo das armas")

	# --- 7. O CHAMADO -----------------------------------------------------------------------------------------
	await _ate(func() -> bool: return fila.espera <= 0.0 and not dialogo.ativo, 20.0)
	_conferir(str(fila.passo_atual().get("id", "")) == "revoar_chamado", "depois das armas não veio o chamado: '%s'" % str(fila.passo_atual().get("id", "")))
	inv.selecionar(inv.MAO_LIVRE)
	revoar.usar_o_e()
	await _quadros(3)
	_conferir(not fila.aconteceu("chamou_a_fera"), "sem a lança na mão o E chamou a fera")
	_conferir(_por_na_mao(inv, "lanca_de_safira"), "não achei a lança na mochila para pôr na mão")
	revoar.usar_o_e()
	await _quadros(3)
	_conferir(not fila.aconteceu("chamou_a_fera"), "sem o escudo vestido o E chamou a fera")
	var vestiu := false
	for i in inv.espacos.size():
		if str((inv.espacos[i] as Dictionary).get("id", "")) == "escudo_de_safira":
			vestiu = equip.equipar_do_espaco(i, "maos")
			break
	_conferir(vestiu and equip.em_uso("escudo_de_safira"), "o escudo de safiras não vestiu nas Mãos")
	_conferir(_por_na_mao(inv, "lanca_de_safira"), "a lança saiu da mão ao vestir o escudo")
	revoar.usar_o_e()
	_conferir(await _ate(func() -> bool: return fila.aconteceu("chamou_a_fera"), 2.0), "com a lança e o escudo o E não chamou a fera")
	var chamado := await _tocar_a_cena(func() -> bool: return fila.passou("revoar_chamado") and not revoar.em_cena(), [], 90000)
	_conferir(bool(chamado["acabou"]), "a cena da fera que vem não terminou")
	var fera = revoar.fera()
	_conferir(fera != null, "a fera não nasceu nas ruínas")
	if fera == null:
		_fechar()
		return
	_conferir(fera.especie == "matinta" and fera.cacando and luta.criaturas.has(fera), "a fera nasceu errada: espécie %s, caçando %s, na luta %s" % [str(fera.especie), str(fera.cacando), str(luta.criaturas.has(fera))])
	_conferir(Vector2(fera.global_position.x - ruinas.x, fera.global_position.z - ruinas.z).length() < 16.0, "a fera nasceu longe das ruínas: %s" % str(fera.global_position))
	_conferir(revoar.espirito() != null, "o espírito do senhor não apareceu")
	_conferir(fera.get_node_or_null("Corpo") != null and not fera.find_children("Olho", "", true, false).is_empty(), "a fera não tem os olhos acesos")

	# --- 8. O EMBATE -------------------------------------------------------------------------------------------
	await _ate(func() -> bool: return fila.espera <= 0.0 and not dialogo.ativo, 20.0)
	_conferir(str(fila.passo_atual().get("id", "")) == "revoar_embate", "depois do chamado não veio o embate: '%s'" % str(fila.passo_atual().get("id", "")))
	var vida_cheia: float = float(fera.dados().get("vida", 1.0))
	var sinal_visto := false
	var tonta_no_sinal := false
	var golpes := 0
	# A LUZ AZUL acende com a fera viva e a lança na mão; apaga (e some) na cena da pedra, então
	# se confere aqui, antes da última lançada.
	var luz_acendeu := false
	for i in 40:
		if fera.morto():
			break
		var para: Vector3 = fera.global_position - jogador.global_position
		para.y = 0.0
		var atras: Vector3 = fera.global_position - para.normalized() * 0.5
		jogador.teleportar(Vector3(atras.x, fera.global_position.y + 0.05, atras.z), atan2(para.x, para.z))
		await _quadros(2)
		var luz: OmniLight3D = jogador.get_node_or_null("LuzDaSafira") as OmniLight3D
		luz_acendeu = luz_acendeu or (luz != null and luz.light_energy > 0.0)
		luta.acertar("golpe", "lanca_de_safira")
		golpes += 1
		await _quadros(2)
		if not fera.morto() and fera.vida / vida_cheia <= 0.35:
			await _quadros(3)
			if revoar.get("_sinal_dado"):
				sinal_visto = true
				if fera.tonto():
					tonta_no_sinal = true
	_conferir(fera.morto(), "quarenta lançadas não derrubaram a fera (vida %.0f de %.0f)" % [fera.vida, vida_cheia])
	_conferir(golpes <= 12, "a fera levou %d lançadas; a lança devia derrubar em menos de doze" % golpes)
	_conferir(sinal_visto and tonta_no_sinal, "o senhor não deu o sinal abaixo de um terço da vida (sinal %s, tonta %s)" % [str(sinal_visto), str(tonta_no_sinal)])
	_conferir(luz_acendeu, "a luz azul da safira não acendeu no jogador durante o embate")
	var pedra := await _tocar_a_cena(func() -> bool: return fila.passou("revoar_embate") and not revoar.em_cena(), [], 90000)
	_conferir(bool(pedra["acabou"]), "a cena da pedra não terminou (passo %s)" % str(fila.passo_atual().get("id", "")))
	_conferir(revoar.estatua_posta(), "a estátua da coruja não ficou nas ruínas")
	_conferir(revoar.espirito() == null, "o espírito do senhor não se despediu")
	var volta := false
	for morte in luta.mortes:
		if str((morte as Dictionary).get("especie", "")) == "matinta":
			volta = true
	_conferir(not volta, "a fera entrou na lista dos que voltam com os dias")

	# --- 9. A LIBERTAÇÃO ---------------------------------------------------------------------------------------
	await _ate(func() -> bool: return fila.espera <= 0.0 and not dialogo.ativo, 20.0)
	_conferir(str(fila.passo_atual().get("id", "")) == "revoar_libertacao", "depois da pedra não veio a libertação: '%s'" % str(fila.passo_atual().get("id", "")))
	var estatua: Vector3 = revoar.estatua()
	jogador.teleportar(estatua + Vector3(1.6, 0.1, 0.0), -PI * 0.5)
	await _quadros(4)
	_conferir(not revoar.alvo_do_e().is_empty(), "ao lado da estátua o capítulo não responde ao E")
	revoar.usar_o_e()
	var fim := await _tocar_a_cena(func() -> bool: return fila.acabou() and not revoar.em_cena(), [true], 90000)
	_conferir(bool(fim["acabou"]), "a libertação não fechou a fila (passo %s, perguntas %d, falas %d)" % [str(fila.passo_atual().get("id", "")), int(fim["perguntas"]), int(fim["falas"])])
	_conferir(fila.aconteceu("escudo_ficou") and not fila.aconteceu("escudo_levado"), "deixar o escudo não ficou na memória da fila")
	_conferir(not inv.tem("escudo_de_safira") and not equip.em_uso("escudo_de_safira"), "o escudo deixado continua com o jogador")
	_conferir(revoar.get_node_or_null("EstatuaDaCoruja/Escudo") != null, "o escudo não virou pedra ao lado da coruja")
	_conferir(int(fim["vozes"]) >= 1, "o amanhecer não foi contado")
	await _ate(func() -> bool:
		var destino = pedro.get("_destino_avulso")
		return not (destino is Vector3 and (destino as Vector3).is_finite()), 4.0)
	var destino_do_pedro = pedro.get("_destino_avulso")
	_conferir(not (destino_do_pedro is Vector3 and (destino_do_pedro as Vector3).is_finite()), "no fim do capítulo o Pedro continua preso nas ruínas")

	# --- 10. A LÍNGUA E O SAVE ----------------------------------------------------------------------------------
	var dados = JSON.parse_string(FileAccess.get_file_as_string("res://data/missoes_revoar.json"))
	for troca in (dados as Dictionary).get("trocas", []):
		for campo in ["oferta", "pergunta"]:
			_conferir(str(troca.get(campo, "")) != "" and str(troca.get(campo + "_en", "")) != "" and str(troca.get(campo + "_es", "")) != "", "a troca não tem '%s' nos três idiomas" % campo)
	var estado: Dictionary = vale.estado_para_salvar()
	var cadeias: Dictionary = estado.get("cadeias", {})
	_conferir(cadeias.has("pedro_revoar"), "o save não leva a fila do capítulo 7: %s" % str(cadeias.keys()))
	_fechar()


## Toca a cena: pula as narrações, fecha as falas, responde as perguntas (na ordem de
## `respostas`; o resto é não) até `ate` valer. Fecha também o aviso da primeira vez.
func _tocar_a_cena(ate: Callable, respostas: Array, teto_ms: int) -> Dictionary:
	var vozes := 0
	var falas := 0
	var perguntas := 0
	var aviso = vale.get("aviso_da_primeira_vez")
	var limite := Time.get_ticks_msec() + teto_ms
	while Time.get_ticks_msec() < limite and not bool(ate.call()):
		if aviso != null and aviso.aberto():
			aviso.fechar()
			await _quadros(3)
		elif narracao.tocando():
			vozes += 1
			await _pular_a_narracao()
		elif dialogo.ativo and dialogo._modo == dialogo.Modo.PERGUNTA:
			var sim: bool = bool(respostas[perguntas]) if perguntas < respostas.size() else false
			perguntas += 1
			dialogo._escolha = sim
			dialogo._escolheu = true
			dialogo._fechar()
			await _quadros(3)
		elif dialogo.ativo:
			falas += 1
			await _fechar_a_fala()
		else:
			await process_frame
	return {"vozes": vozes, "falas": falas, "perguntas": perguntas, "acabou": bool(ate.call())}


## Põe o item na mão pela mochila (o índice do espaço dele).
func _por_na_mao(inv, id: String) -> bool:
	for i in inv.espacos.size():
		var espaco: Dictionary = inv.espacos[i]
		if str(espaco.get("id", "")) == id:
			inv.selecionar(i)
			return inv.na_mao() == id
	return false


## Pula a narração frase a frase até ela terminar.
func _pular_a_narracao() -> void:
	var ate := Time.get_ticks_msec() + 30000
	while narracao.tocando() and Time.get_ticks_msec() < ate:
		narracao.pular()
		await _quadros(3)
	await _quadros(3)


func _fechar_a_fala() -> void:
	var ate := Time.get_ticks_msec() + 6000
	while dialogo.ativo and dialogo._modo != dialogo.Modo.PERGUNTA and Time.get_ticks_msec() < ate:
		dialogo._fechar()
		await process_frame
	await _quadros(3)


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("REVOAR_OK: as ruínas, a torre e a estátua resolvem a oeste da fazenda, em terra, com o alto da torre a 3,6 do pé; o capítulo começa com a porta estreita fechada; a velha oferece três trocas, aceitar tira fôlego e paga, recusar é o caminho; o E no Pedro fecha a mão e a fuga leva o arraial às ruínas; o abrigo traz o relato; o E no alto da torre dá a lança e o escudo, e com os dois na mão e no braço chama a fera, que nasce caçando com o senhor ao lado; a lança a derruba, com o sinal; a estátua fica e a fera não volta; deixar o escudo o põe de pedra e o amanhecer fecha a fila; e a fila vai no save")
	else:
		print("revoar: %d falha(s)" % falhas)
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
