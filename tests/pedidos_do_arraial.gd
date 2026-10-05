extends SceneTree
## OS PEDIDOS DO ARRAIAL QUE A CHEGADA ABRE: a roça do Cosme e o mutirão da
## carroça do Seu Benedito (docs/mundo/CHEGADA_E_MUTIROES.md).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/pedidos_do_arraial.gd
##
## O que o portão da chegada (`cadeia_das_missoes.gd`) não cobre:
##
##   - QUEM PAGA. A recompensa diz o nome de quem pagou (`quem_paga`), e não o
##     do dono da cadeia: o peixe é do Tonho, a pirão da Filó, o milho do Benedito.
##   - A ROÇA espera a primeira leira, e então pede colher, torrar a farinha e
##     levar a primeira cuia à Dona Filó — que ensina o pirão.
##   - O MUTIRÃO. Quem ajuda é chamado ao lugar da obra no anúncio, entrega o
##     que traz AO CHEGAR, uma vez só, e volta ao posto quando a obra sai. Sem o
##     que o Cosme e o Tonho trazem, a carroça não sai: o jogador junta a parte
##     dele (8 tábuas, 4 cordas, 4 pedras) e a obra pede 20, 10 e 4.
##   - O SAVE DE ANTES DA CHEGADA NOVA (Builds #7 e #8): quem acabou a de nove
##     passos continua acabado, e quem estava no meio cai no passo que faz o
##     mesmo papel.
##
## As esperas são em segundo real, pela razão do cabeçalho do portão da chegada:
## a palavra dos moradores é medida em relógio de parede.

var falhas := 0
const SEGUNDOS := 15.0
## O que o jogador junta e o que a carroça pede (data/construcoes/obras.json).
const PARTE_DO_JOGADOR := {"tabua": 8, "corda": 4, "pedra": 4}
const A_CARROCA_PEDE := {"tabua": 20, "corda": 10, "pedra": 4}


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("PEDIDOS_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(3)
	var jogo := current_scene
	var pedro = jogo.get("pedro")
	var jogador = jogo.get("player")
	var inv := root.get_node("/root/Inventario")
	var energia := root.get_node("/root/Energia")
	var receitas := root.get_node("/root/Receitas")
	var oficina := root.get_node("/root/Oficina")
	var cozinha := root.get_node("/root/Cozinha")
	var obras := root.get_node("/root/Obras")
	var moradores := {}
	for morador in jogo.get("moradores"):
		moradores[str((morador.dados as Dictionary).get("id", ""))] = morador
	for quem in ["cosme", "benedito", "tonho", "filo"]:
		_conferir(moradores.has(quem), "o vale não tem '%s'" % quem)
	if pedro == null or jogador == null or not moradores.has("cosme") or not moradores.has("benedito"):
		_fechar()
		return

	# --- 1. QUEM PAGA ------------------------------------------------------------
	var chegada = pedro.get("_cadeia")
	var bom_dia: Dictionary = {}
	for passo in pedro.MISSOES:
		if str((passo as Dictionary).get("id", "")) == "bom_dia":
			bom_dia = passo
	_conferir(str(bom_dia.get("quem_paga", "")) == "tonho" and chegada._quem_paga(bom_dia) == _nome(moradores["tonho"]),
		"o peixe do bom-dia é do Tonho, e o HUD diria 'Recebido de %s'" % chegada._quem_paga(bom_dia))

	# --- 2. O SAVE DE ANTES DA CHEGADA NOVA --------------------------------------
	var total: int = pedro.MISSOES.size()
	_conferir(jogo._passo_da_chegada_salvo({"missao": 9, "iniciado": true, "despedida": true}) == total,
		"um save com a chegada de nove passos acabada voltou para dentro da chegada nova")
	var do_machado: int = jogo._passo_da_chegada_salvo({"missao": 5, "iniciado": true})
	_conferir(do_machado >= 0 and do_machado < total and str((pedro.MISSOES[do_machado] as Dictionary).get("id", "")) == "lenha",
		"um save no passo antigo do machado não caiu no passo da lenha (caiu no %d)" % do_machado)
	var da_corda: int = jogo._passo_da_chegada_salvo({"missao": 0, "passo": "corda"})
	_conferir(da_corda >= 0 and da_corda < total and str((pedro.MISSOES[da_corda] as Dictionary).get("id", "")) == "corda",
		"um save novo, guardado no passo da corda, não voltou a ele")
	pedro.missao = -1

	# --- 3. A ROÇA ESPERA A PRIMEIRA LEIRA ---------------------------------------
	var cosme: Node3D = moradores["cosme"]
	var roca = cosme.get_node_or_null("CadeiaDeMissoes_cosme_roca")
	_conferir(roca != null, "o Cosme não tem a fila da roça")
	if roca != null:
		jogador.teleportar(cosme.global_position + Vector3(1.2, 0.0, 1.0), 0.0)
		await _ate(func() -> bool: return false, 1.5)
		_conferir(not roca.iniciado, "a roça abriu antes da primeira leira da chegada")
		_conferir(pedro.ir_ao_passo("convite"), "a chegada não tem o passo do convite")
		jogador.teleportar(cosme.global_position + Vector3(1.2, 0.0, 1.0), 0.0)
		_conferir(await _ate(func() -> bool: return roca.iniciado, SEGUNDOS),
			"passada a leira, ao lado do Cosme, a roça não abriu")
		await _ate(func() -> bool: return roca.espera <= 0.0, SEGUNDOS)
		var pagamentos: Array[String] = []
		roca.pagou.connect(func(texto: String) -> void: pagamentos.append(texto))
		await _colher(jogo, inv)
		_conferir(await _ate(func() -> bool: return roca.missao >= 1, SEGUNDOS),
			"colhida a mandioca, o passo de colher não fechou: o 'colheu' da lavoura não chega à roça")
		# O passo seguinte ensina a farinha AO ANUNCIAR, e o anúncio vem depois da folga.
		await _ate(func() -> bool: return roca.espera <= 0.0, SEGUNDOS)
		energia.encher()
		inv.adicionar("lenha", 2)
		_conferir(receitas.sabe("farinha"), "o passo da farinha abriu e não ensinou a farinha")
		_conferir(cozinha.cozinhar("farinha"), "a farinha não saiu: %s" % cozinha.impedimento("farinha"))
		_conferir(await _ate(func() -> bool: return roca.missao >= 2, SEGUNDOS),
			"torrada a farinha, o passo não fechou: o 'cozinhou:farinha' não chega à roça")
		var filo: Node3D = moradores["filo"]
		jogador.teleportar(filo.global_position + Vector3(1.0, 0.0, 0.6), 0.0)
		_conferir(await _ate(func() -> bool: return roca.acabou(), SEGUNDOS),
			"ao lado da Dona Filó, com a farinha, a cuia não foi entregue")
		_conferir(inv.quantidade("pirao") >= 1, "a Dona Filó não deu o pirão")
		_conferir(receitas.sabe("pirao"), "o passo da cuia abriu e não ensinou o pirão")
		_conferir(pagamentos.any(func(t: String) -> bool: return t.contains(_nome(filo))),
			"o pirão é da Dona Filó, e o HUD disse: %s" % str(pagamentos))

	# --- 4. A CARROÇA ESPERA A PIAÇAVA DO SAVEIRO ----------------------------------
	pedro.missao = total
	pedro.set("_despedida_feita", true)
	var benedito: Node3D = moradores["benedito"]
	var carroca = benedito.get_node_or_null("CadeiaDeMissoes_benedito_carroca")
	var do_saveiro = benedito.get_node_or_null("CadeiaDeMissoes_benedito_saveiro")
	_conferir(carroca != null and do_saveiro != null, "o Seu Benedito não tem as filas do saveiro e da carroça")
	if carroca == null or do_saveiro == null:
		_fechar()
		return
	jogador.teleportar(benedito.global_position + Vector3(1.2, 0.0, 1.0), 0.0)
	await _ate(func() -> bool: return false, 1.5)
	_conferir(not carroca.iniciado, "a carroça abriu antes de o jogador juntar a piaçava do saveiro")
	do_saveiro.iniciado = true
	do_saveiro.missao = _indice_de(do_saveiro, "saveiro_piacava") + 1
	_conferir(await _ate(func() -> bool: return carroca.iniciado, SEGUNDOS),
		"juntada a piaçava, ao lado do Seu Benedito, a carroça não abriu")
	await _ate(func() -> bool: return carroca.espera <= 0.0, SEGUNDOS)
	var da_carroca: Array[String] = []
	carroca.pagou.connect(func(texto: String) -> void: da_carroca.append(texto))

	# A parte do jogador: tábua e corda na bancada, como o J faz.
	for material in ["tabua", "corda"]:
		var custo: Dictionary = oficina.dados(material).get("custo", {})
		for vez in int(PARTE_DO_JOGADOR[material]):
			for de_que in custo:
				inv.adicionar(str(de_que), int(custo[de_que]))
			energia.encher()
			_conferir(oficina.fabricar(material), "a bancada não fez %s: %s" % [material, oficina.impedimento(material)])
	inv.adicionar("pedra", int(PARTE_DO_JOGADOR["pedra"]))
	_conferir(await _ate(func() -> bool: return carroca.missao >= 2, SEGUNDOS),
		"com a parte do jogador na mochila, os dois primeiros passos não fecharam")
	await _ate(func() -> bool: return carroca.espera <= 0.0, SEGUNDOS)

	# --- 5. O MUTIRÃO -----------------------------------------------------------
	var passo: Dictionary = carroca.passo_atual()
	var cosme_ali: Vector3 = carroca._lugar_no_mutirao(passo, 0, 2)
	var tonho: Node3D = moradores["tonho"]
	var tonho_ali: Vector3 = carroca._lugar_no_mutirao(passo, 1, 2)
	_conferir(_chamado(cosme, cosme_ali) and _chamado(tonho, tonho_ali),
		"anunciado o mutirão, o Cosme e o Tonho não foram chamados à carroça")
	_conferir(not obras.pode("carroca", "arraial_carroca"),
		"a carroça saiu só com a parte do jogador: o mutirão não faz falta")
	_conferir(inv.quantidade("tabua") == int(PARTE_DO_JOGADOR["tabua"]),
		"antes de o Cosme chegar já havia %d tábuas: alguém entregou de longe" % inv.quantidade("tabua"))
	cosme.global_position = cosme_ali + Vector3(0, 0.1, 0)
	_conferir(await _ate(func() -> bool: return inv.quantidade("tabua") == int(A_CARROCA_PEDE["tabua"]), SEGUNDOS),
		"o Cosme chegou à carroça e as tábuas não vieram (%d)" % inv.quantidade("tabua"))
	tonho.global_position = tonho_ali + Vector3(0, 0.1, 0)
	_conferir(await _ate(func() -> bool: return inv.quantidade("corda") == int(A_CARROCA_PEDE["corda"]), SEGUNDOS),
		"o Tonho chegou à carroça e as cordas não vieram (%d)" % inv.quantidade("corda"))
	await _frames(20)
	_conferir(inv.quantidade("tabua") == int(A_CARROCA_PEDE["tabua"]),
		"o Cosme entregou as tábuas mais de uma vez (%d)" % inv.quantidade("tabua"))
	_conferir(da_carroca.any(func(t: String) -> bool: return t.contains(_nome(cosme)) and t.contains("12")),
		"o HUD não disse que o Cosme trouxe as tábuas: %s" % str(da_carroca))

	# A obra, no terreiro do Benedito.
	jogador.teleportar(benedito.global_position + Vector3(0.8, 0.0, 0.8), 0.0)
	await _frames(3)
	energia.encher()
	_conferir(obras.executar("carroca", "arraial_carroca"),
		"com o mutirão, a carroça não saiu: %s" % obras.impedimento("carroca", "arraial_carroca"))
	_conferir(await _ate(func() -> bool: return carroca.acabou(), SEGUNDOS), "a obra saiu e a carroça não fechou")
	_conferir(not _chamado(cosme, cosme_ali) and not _chamado(tonho, tonho_ali),
		"a carroça saiu e o Cosme e o Tonho continuam presos ao mutirão")
	_conferir(inv.quantidade("semente_milho") >= 6, "o Seu Benedito não pagou o milho de plantar")
	_conferir(da_carroca.any(func(t: String) -> bool: return t.contains(_nome(benedito)) and not t.contains(_nome(cosme))),
		"o milho é do Seu Benedito, e o HUD disse: %s" % str(da_carroca))
	_fechar()


## A MANDIOCA MADURA, pelo caminho da plantação: arar, plantar, e regar e virar o
## dia até a rama amarelar. Só a colheita é pelo gesto do jogador, de mão livre.
func _colher(jogo, inv) -> void:
	var lavoura = jogo.lavoura
	var plantacao = lavoura.plantacao
	var leito := Vector2i(1, 1)
	plantacao.arar(leito)
	plantacao.plantar(leito, "mandioca")
	for dia in 12:
		if plantacao.maduro(leito):
			break
		plantacao.regar(leito)
		plantacao.novo_dia()
	_conferir(plantacao.maduro(leito), "a mandioca não amadureceu em doze dias regados")
	for i in inv.ESPACOS_MAO:
		if inv.vazio(i):
			inv.selecionar(i)
			break
	jogo.player.teleportar(lavoura.posicao_da(leito) + Vector3(0.0, 0.0, -0.6), 0.0)
	await _frames(2)
	lavoura.usar(leito)
	await _frames(2)
	_conferir(inv.quantidade("mandioca") >= 2, "de mão livre, a mandioca madura não veio para a mochila")


static func _nome(morador: Node) -> String:
	return str((morador.dados as Dictionary).get("nome", ""))


static func _indice_de(cadeia, id: String) -> int:
	for i in cadeia.passos.size():
		if str((cadeia.passos[i] as Dictionary).get("id", "")) == id:
			return i
	return -1


## O morador foi chamado a este ponto (`ir_ate`) e ainda não foi liberado?
static func _chamado(morador: Node, ponto: Vector3) -> bool:
	var destino: Vector3 = morador.get("_destino_avulso")
	return destino.is_finite() and destino.distance_to(ponto) < 0.05


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("PEDIDOS_OK: a recompensa diz quem pagou; o save da chegada antiga volta ao passo que faz o mesmo papel; a roça espera a leira e pede colher, torrar e levar a cuia à Filó, que paga e ensina o pirão; a carroça espera a piaçava, e o mutirão chama o Cosme e o Tonho, que trazem o que faltava ao chegar, uma vez só, e voltam aos postos quando a obra sai")
	else:
		print("pedidos: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicao.call():
			return true
		await process_frame
	return condicao.call()


func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame


func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
