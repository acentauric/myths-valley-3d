extends SceneTree
## Confere O MACHADO QUE CHEGA NA PONTE (data/missoes_ponte.json, "buscar_machado";
## `prototype._ja_recebeu_o_machado`; `CadeiaDeMissoes._por_na_barra`).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/machado.gd
##
## "Quando conclui a quest de agricultura regando com o balde, ele trocou
## automaticamente para o machado de madeira. Isso não deve acontecer. Também
## lembre-se que o machado só é introduzido na missão da ponte, com o Pedro indo
## buscar o machado em casa."
##
## Sete perguntas:
##
##   1. JOGO NOVO NÃO TEM MACHADO: nem na mochila, nem na mão.
##   2. A CHEGADA NÃO DÁ MACHADO, e o fogo da primeira noite sai sem ele: há
##      galhada seca no terreiro, catada na mão, que SE REFAZ enquanto não há
##      machado, e é ela que o marcador da lenha aponta.
##   3. A GALHADA SE QUEBRA NA MÃO, E SE REFAZ: de mão livre, junto dela, os
##      golpes da ficha rendem a lenha, leva após leva, até o que o passo pede e
##      a folga — e o monte continua lá.
##   4. A PONTE TRAZ O MACHADO: "Os machados do avô" vem antes da lenha da
##      ponte, o Pedro conduz até a casa dele e para na porta, do lado de fora; e
##      o passo da lenha o entrega.
##   5. A MÃO É DO JOGADOR: com o balde na mão, a entrega põe o machado na barra
##      e não troca o balde; o HUD diz o número que o põe na mão.
##   6. AS FILAS DE MADEIRA ESPERAM O MACHADO: o Damião, o Tonho e a carroça do
##      Seu Benedito não abrem antes dos machados do avô, e abrem depois.
##   7. COM O MACHADO, A GALHADA RENDE A ÚLTIMA VEZ e cai como qualquer alvo: daí
##      em diante a lenha é dele.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("MACHADO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	var vale = current_scene
	var inv = root.get_node("/root/Inventario")
	var equipamento = root.get_node("/root/Equipamento")
	var energia = root.get_node("/root/Energia")
	root.get_node("/root/Dia").pausado = true
	var pedro = vale.get("pedro")
	var recursos = vale.get_node_or_null("Recursos3D")
	var ponte = vale._cadeias.get("pedro_ponte")
	_conferir(pedro != null and recursos != null and ponte != null,
		"o vale não tem o Pedro (%s), os alvos (%s) ou a frente da ponte (%s)" % [str(pedro), str(recursos), str(ponte)])
	if pedro == null or recursos == null or ponte == null:
		_fechar()
		return

	# --- 1. JOGO NOVO NÃO TEM MACHADO ------------------------------------------------------
	_conferir(not inv.tem("machado") and not inv.tem("machado_de_aco") and equipamento.da_familia_em_uso("machado") == "",
		"o jogo novo começou com machado: o machado só chega na missão da ponte")

	# --- 2. A CHEGADA NÃO DÁ MACHADO ------------------------------------------------------
	var guia = JSON.parse_string(FileAccess.get_file_as_string("res://data/missoes_guia.json"))
	var pede_na_lenha := 0
	for passo: Dictionary in guia.get("passos", []):
		var entregas: Array = passo.get("entrega") if passo.get("entrega") is Array else [passo.get("entrega", {})]
		for entrega in entregas:
			if entrega is Dictionary:
				_conferir(not str((entrega as Dictionary).get("item", "")).begins_with("machado"),
					"o passo '%s' da chegada entrega machado" % str(passo.get("id", "")))
		if str(passo.get("id", "")) == "lenha":
			pede_na_lenha = int((passo.get("meta", {}) as Dictionary).get("quantos", 0))
	_conferir(pede_na_lenha > 0, "a chegada não tem o passo da lenha, ou ele não diz quantas pede")
	var casa: Vector3 = root.get_node("/root/Lugares").ponto("casa_de_taipa")
	var galhada := ""
	for id in recursos._alvos:
		var ficha: Dictionary = recursos._alvos[id]["ficha"]
		if str(ficha.get("rende", "")) != "lenha" or str(ficha.get("ferramenta", "")) != "":
			continue
		var pos: Vector3 = recursos._alvos[id]["pos"]
		if Vector2(pos.x - casa.x, pos.z - casa.z).length() > 12.0:
			continue
		if galhada == "" or str(ficha.get("renova_sem", "")) == "machado":
			galhada = str(id)
	_conferir(galhada != "",
		"perto da casa não há lenha que se cate na mão: o fogo da primeira noite pediria o machado, que só chega na ponte")
	# A LENHA DA CHEGADA NÃO PODE SER CONTADA. Sem machado não há outra, e quem
	# gastasse uma a mais na bancada ficava com a janta por assar.
	_conferir(galhada != "" and str(recursos._alvos[galhada]["ficha"].get("renova_sem", "")) == "machado",
		"a galhada da casa não se refaz sem machado: gasta a lenha contada, o jogador fica sem ter onde buscar mais antes da ponte")
	if galhada != "":
		var da_galhada: Vector3 = recursos._alvos[galhada]["pos"]
		_conferir(recursos.mais_perto_que_rende("lenha", casa).distance_to(da_galhada) < 0.1,
			"sem machado, o marcador da lenha não aponta a galhada da casa: manda bater no tronco que pede machado")

	# --- 3. A GALHADA SE QUEBRA NA MÃO, E SE REFAZ ------------------------------------------
	if galhada != "":
		var jogador = vale.player
		inv.selecionar(-1)
		jogador.teleportar(recursos._alvos[galhada]["pos"] + Vector3(1.2, 0.3, 0.0), 0.0)
		var chegou := await _ate(func() -> bool: return recursos._perto == galhada, 4.0)
		_conferir(chegou, "junto da galhada, o alvo perto é '%s'" % recursos._perto)
		if chegou:
			var ficha: Dictionary = recursos._alvos[galhada]["ficha"]
			var antes: int = inv.quantidade("lenha")
			var por_leva := int(ficha.get("quantidade", 1))
			var levas := 0
			# Do mesmo monte, o que o passo pede e a folga de quem gasta no caminho.
			while inv.quantidade("lenha") - antes < pede_na_lenha + 2 and levas < 12 and recursos._alvos.has(galhada):
				for golpe in int(ficha.get("golpes", 1)):
					energia.encher()
					_conferir(recursos.bater(), "de mão livre, a galhada recusou o golpe %d da leva %d" % [golpe + 1, levas + 1])
				levas += 1
				_conferir(inv.quantidade("lenha") == antes + levas * por_leva,
					"na leva %d a galhada quebrada na mão rendeu %d lenha(s) ao todo, e a ficha diz %d por leva" % [levas, inv.quantidade("lenha") - antes, por_leva])
			_conferir(inv.quantidade("lenha") - antes >= pede_na_lenha + 2,
				"sem machado, a galhada da casa rendeu %d lenha(s) e parou: o passo pede %d, mais a folga" % [inv.quantidade("lenha") - antes, pede_na_lenha])
			_conferir(recursos._alvos.has(galhada) and not recursos.caidos().has(galhada),
				"sem machado, a galhada sumiu depois de render: não há outra lenha antes da ponte")

	# --- 4. A PONTE TRAZ O MACHADO --------------------------------------------------------
	var ids: Array[String] = []
	for passo: Dictionary in ponte.passos:
		ids.append(str(passo.get("id", "")))
	var buscar := ids.find("buscar_machado")
	var lenha := ids.find("ponte_lenha")
	_conferir(buscar >= 0 and lenha == buscar + 1, "na frente da ponte, os machados do avô não vêm logo antes da lenha: %s" % str(ids))
	if buscar >= 0 and lenha == buscar + 1:
		var o_passo: Dictionary = ponte.passos[buscar]
		_conferir(bool(o_passo.get("conduz", false)) and str(o_passo.get("lugar", "")) == "casa_do_pedro",
			"os machados do avô não são o Pedro conduzindo até a casa dele")
		var entregas: Array = ponte.entregas_do_passo(ponte.passos[lenha])
		_conferir(entregas.any(func(e) -> bool: return str((e as Dictionary).get("item", "")) == "machado"),
			"a lenha da ponte não entrega o machado do avô")
		pedro.missao = pedro.MISSOES.size()
		pedro.set("_despedida_feita", true)
		ponte.iniciado = true
		ponte.missao = buscar
		ponte.espera = 0.0
		_conferir(pedro._outra_que_conduz() == ponte, "nos machados do avô, o Pedro não conduz")
		var porta: Vector3 = pedro._destino_da_conducao(ponte)
		var da_casa: Vector3 = root.get_node("/root/Lugares").ponto("casa_do_pedro")
		_conferir(vale.interiores.contem(porta) == "",
			"o Pedro conduz para dentro da casa dele (%s), e não até a porta" % vale.interiores.contem(porta))
		_conferir(Vector2(porta.x - da_casa.x, porta.z - da_casa.z).length() < float(o_passo.get("raio", 5.0)),
			"a porta da casa do Pedro fica fora do raio do passo: chegar com ele não fecharia")

	# --- 6. AS FILAS DE MADEIRA ESPERAM O MACHADO ----------------------------------------------
	# Antes do 5, que entrega o machado: com ele na mochila a espera acaba.
	var saveiro = vale._cadeias.get("benedito_saveiro")
	if saveiro != null:
		saveiro.iniciado = true
		for i in saveiro.passos.size():
			if str((saveiro.passos[i] as Dictionary).get("id", "")) == "saveiro_piacava":
				saveiro.missao = i + 1
	var filas := {"o Damião": vale._cadeias.get("damiao"), "o Tonho": vale._cadeias.get("tonho"), "a carroça": vale._cadeias.get("benedito_carroca")}
	for quem in filas:
		var fila = filas[quem]
		_conferir(fila != null and fila.depois_de.is_valid(), "%s não tem fila, ou ela não espera nada" % quem)
		if fila != null and fila.depois_de.is_valid():
			_conferir(not bool(fila.depois_de.call()), "%s abre a fila antes dos machados do avô: ela pede madeira" % quem)
	if buscar >= 0:
		ponte.missao = buscar + 1
		for quem in filas:
			var fila = filas[quem]
			if fila != null and fila.depois_de.is_valid():
				_conferir(bool(fila.depois_de.call()), "%s não abre a fila depois dos machados do avô" % quem)

	# --- 5. A MÃO É DO JOGADOR ----------------------------------------------------------
	if lenha >= 0:
		inv.adicionar("balde", 1)
		var do_balde := -1
		for i in inv.ESPACOS_MAO:
			if str((inv.espacos[i] as Dictionary).get("id", "")) == "balde":
				do_balde = i
		inv.selecionar(do_balde)
		_conferir(inv.na_mao() == "balde", "não consegui pôr o balde na mão para a pergunta")
		var avisos: Array[String] = []
		ponte.entregou.connect(func(texto: String) -> void: avisos.append(texto))
		ponte.missao = lenha
		ponte.entregar(ponte.passo_atual())
		_conferir(inv.tem("machado"), "a lenha da ponte não entregou o machado")
		_conferir(inv.na_mao() == "balde", "a entrega do machado trocou o balde da mão pelo '%s'" % inv.na_mao())
		var do_machado := -1
		for i in inv.ESPACOS_MAO:
			if str((inv.espacos[i] as Dictionary).get("id", "")) == "machado":
				do_machado = i
		_conferir(do_machado >= 0, "o machado entregue não está em nenhum dos dez da barra de mão")
		_conferir(avisos.size() == 1 and do_machado >= 0 and avisos[0].contains(inv.rotulo_do_espaco(do_machado)),
			"o HUD não diz o número que põe o machado na mão: %s" % str(avisos))

	# --- 7. COM O MACHADO, A GALHADA RENDE A ÚLTIMA VEZ ----------------------------------------
	# Depois do 5, que entrega o machado: daí em diante a lenha é dele.
	if galhada != "" and recursos._alvos.has(galhada) and inv.tem("machado"):
		var ficha: Dictionary = recursos._alvos[galhada]["ficha"]
		vale.player.teleportar(recursos._alvos[galhada]["pos"] + Vector3(1.2, 0.3, 0.0), 0.0)
		var chegou := await _ate(func() -> bool: return recursos._perto == galhada, 4.0)
		_conferir(chegou, "(preparo) de volta à galhada, o alvo perto é '%s'" % recursos._perto)
		if chegou:
			var antes: int = inv.quantidade("lenha")
			for golpe in int(ficha.get("golpes", 1)):
				energia.encher()
				recursos.bater()
			_conferir(inv.quantidade("lenha") == antes + int(ficha.get("quantidade", 1)),
				"com o machado na mochila, a última leva da galhada rendeu %d lenha(s)" % (inv.quantidade("lenha") - antes))
			_conferir(not recursos._alvos.has(galhada) and recursos.caidos().has(galhada),
				"com o machado na mochila a galhada continuou se refazendo: lenha de graça à porta de casa, para sempre")
	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("MACHADO_OK: jogo novo começa sem machado; a chegada não o dá, e o fogo da primeira noite sai da galhada do terreiro, catada na mão, que se refaz enquanto não há machado e rende a última vez quando ele chega; os machados do avô vêm antes da lenha da ponte, com o Pedro conduzindo até a porta da casa dele; a entrega põe o machado na barra sem tirar o balde da mão, e o HUD diz o número; e o Damião, o Tonho e a carroça esperam o machado")
	else:
		print("machado: %d falha(s)" % falhas)
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
