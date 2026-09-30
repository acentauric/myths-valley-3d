extends SceneTree
## Confere PESCA, COZINHA E OFICINA no vale (#11).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/oficio.gd
##
## As regras são o `Pesca`, o `Cozinha` e o `Oficina` compartilhados. Este
## portão pergunta o que é do vale:
##
##   1. A ÁGUA DECIDE O PEIXE: na calha do rio a água é doce, no mar é mar, e o
##      tanque de cada uma é o do `Pesca` — traíra só no rio, robalo só no mar.
##   2. A PESCARIA INTEIRA no píer: com a vara na mão e a água à frente o E
##      lança, a bóia vai para a água, a fisgada a afunda e acende o "!", e
##      ferrar põe o peixe na mochila. Sem vara, o E não lança; andar recolhe.
##   3. A COZINHA NO FOGO DO TERREIRO: perto da fogueira da Casa de taipa a aba
##      do fogão aparece, e o prato sabido, com o ingrediente, sai da panela.
##   4. A OFICINA PROVISÓRIA na beira do roçado, marcada no chão: a aba dela
##      aparece ali, e a lenha vira tábua e corda.

var falhas := 0
var pesca_regra
var inventario
var receitas
var energia
var cozinha


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("OFICIO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	pesca_regra = root.get_node("/root/Pesca")
	inventario = root.get_node("/root/Inventario")
	receitas = root.get_node("/root/Receitas")
	energia = root.get_node("/root/Energia")
	cozinha = root.get_node("/root/Cozinha")
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(6)
	await _mundo_pronto()
	await _frames(10)
	var vale = current_scene
	var player = vale.player
	var world = vale.world
	var pesca = vale.get_node_or_null("Pesca")
	var painel = vale.painel
	_conferir(pesca != null, "o vale não montou a pesca")
	if pesca == null:
		_fechar()
		return

	# --- 1. A ÁGUA DECIDE O PEIXE ----------------------------------------------
	var regiao = world.get("_region")
	var rios: Array = regiao.get("_rivers") if regiao != null else []
	_conferir(not rios.is_empty(), "o vale não tem rio no mapa")
	if not rios.is_empty():
		var linha: PackedVector2Array = rios[0]["points"]
		var meio: Vector2 = linha[linha.size() / 2]
		_conferir(pesca.tipo_de_agua(Vector3(meio.x, 0.0, meio.y)) == "doce", "o meio do rio não é água doce")
	var pier: Vector3 = world.ancoras["PierPiso"]
	var mar: Vector3 = world.ancoras.get("PierDirecao", Vector3.FORWARD)
	mar.y = 0.0
	var no_mar: Vector3 = pier + mar.normalized() * 30.0
	_conferir(pesca.tipo_de_agua(no_mar) == "mar", "a água em frente ao píer não é mar")
	var visto := {"mar": {}, "doce": {}}
	for agua in visto:
		for i in 400:
			visto[agua][str(pesca_regra._sortear(agua, false)["id"])] = true
	_conferir(not visto["doce"].has("robalo") and visto["mar"].has("robalo"), "o robalo não é só do mar: %s" % str(visto))
	_conferir(not visto["mar"].has("traira") and visto["doce"].has("traira"), "a traíra não é só do rio: %s" % str(visto))

	# --- 2. A PESCARIA INTEIRA NO PÍER ------------------------------------------
	_ficar_de_frente(player, world, pier, mar)
	await _frames(3)
	_conferir(pesca.agua_a_frente().is_finite(), "na ponta do píer, virado para o mar, não há água à frente")
	# Sem vara, o E não lança.
	inventario.selecionar(inventario.MAO_LIVRE)
	pesca._unhandled_key_input(_evento_e())
	_conferir(not pesca_regra.pescando, "de mão vazia o E lançou a linha")
	inventario.adicionar("vara_de_pescar")
	inventario.selecionar(_espaco_de("vara_de_pescar"))
	_conferir(inventario.na_mao() == "vara_de_pescar", "não consegui pôr a vara na mão")
	energia.encher()
	var viu_o_sinal := [false]
	pesca_regra.fisgou.connect(func():
		viu_o_sinal[0] = pesca._sinal.visible
		pesca.ferrar(), CONNECT_DEFERRED)
	var antes: Dictionary = _mochila()
	var premio: Dictionary = await pesca.lancar()
	_conferir(pesca.agua_do_lance == "mar", "no píer a linha caiu em água '%s'" % pesca.agua_do_lance)
	_conferir(viu_o_sinal[0], "a fisgada não acendeu o \"!\" sobre a bóia")
	_conferir(not premio.is_empty(), "ferrou na janela e a pescaria voltou vazia")
	if not premio.is_empty():
		var id := str(premio["id"])
		_conferir(id in ["peixe", "robalo", ""], "do mar veio '%s'" % id)
		if id != "":
			_conferir(inventario.quantidade(id) == int(antes.get(id, 0)) + int(premio["qtd"]),
				"o peixe ferrado não entrou na mochila")
	# Andar recolhe a linha.
	pesca.lancar()
	await _frames(3)
	_conferir(pesca_regra.pescando, "o segundo lance não começou")
	player.global_position += Vector3(0.0, 0.0, pesca.DESISTE + 1.0)
	await _frames(3)
	_conferir(not pesca_regra.pescando, "andar com a linha na água não recolheu")

	# --- 3. A COZINHA NO FOGO DO TERREIRO ----------------------------------------
	var Bancadas = load("res://scripts/prototipo_3d/bancadas_vale.gd")
	var fogo: Vector3 = world.ancoras["Fogueira"]
	player.global_position = world.ground_position(fogo + Vector3(1.5, 0.0, 0.0), 0.07)
	await _frames(2)
	vale.abrir_o_painel()
	await _frames(2)
	_conferir(painel.na_cozinha, "perto da fogueira do terreiro não há cozinha")
	_conferir(painel.abas_validas().has(painel.Aba.COZINHA), "perto da fogueira a aba do fogão não apareceu: %s" % str(painel.abas_validas()))
	var prato := "beiju"
	receitas.aprender(prato, "teste")
	var custo: Dictionary = cozinha.dados(prato).get("custo", {})
	for item in custo:
		inventario.adicionar(str(item), int(custo[item]))
	energia.encher()
	var tinha: int = inventario.quantidade(prato)
	# Laço LIMITADO: se a aba não existe, girar para sempre trava o portão
	# em vez de reprová-lo.
	for _volta in painel.abas_validas().size():
		if painel.aba() == painel.Aba.COZINHA:
			break
		painel._proxima_aba(1)
	_conferir(painel.aba() == painel.Aba.COZINHA, "não cheguei à aba cozinha: %s" % str(painel.abas_validas()))
	painel.escolher(cozinha.receitas().find(prato))
	painel._confirmar()
	_conferir(inventario.quantidade(prato) == tinha + int(cozinha.dados(prato).get("rende", 1)), "o fogo do terreiro não fez o %s" % prato)
	painel.fechar()

	# --- 4. A OFICINA PROVISÓRIA -----------------------------------------------
	var marca = vale.get_node_or_null("Bancada_oficina")
	_conferir(marca != null, "a bancada provisória da oficina não está no chão")
	var bancada: Vector3 = Bancadas.ponto_da_provisoria(world, "oficina")
	player.global_position = bancada + Vector3(1.2, 0.07, 0.0)
	await _frames(2)
	vale.abrir_o_painel()
	await _frames(2)
	_conferir(painel.obra_em_foco == "oficina", "na bancada a obra em foco é '%s'" % painel.obra_em_foco)
	_conferir(painel.abas_validas().has(painel.Aba.OFICINA), "na bancada a aba de oficina não apareceu: %s" % str(painel.abas_validas()))
	inventario.adicionar("lenha", 5)
	var tabua: int = inventario.quantidade("tabua")
	var corda: int = inventario.quantidade("corda")
	# Laço LIMITADO: se a aba não existe, girar para sempre trava o portão
	# em vez de reprová-lo.
	for _volta in painel.abas_validas().size():
		if painel.aba() == painel.Aba.OFICINA:
			break
		painel._proxima_aba(1)
	_conferir(painel.aba() == painel.Aba.OFICINA, "não cheguei à aba oficina: %s" % str(painel.abas_validas()))
	for receita in ["tabua", "corda"]:
		energia.encher()
		painel.escolher(root.get_node("/root/Oficina").receitas().find(receita))
		painel._confirmar()
	_conferir(inventario.quantidade("tabua") == tabua + 1, "a oficina não serrou a tábua")
	_conferir(inventario.quantidade("corda") == corda + 1, "a oficina não torceu a corda")
	painel.fechar()
	_fechar()


func _ficar_de_frente(player, world, onde: Vector3, rumo: Vector3) -> void:
	player.global_position = onde + Vector3(0.0, 0.1, 0.0)
	player.velocity = Vector3.ZERO
	player.visual.rotation.y = atan2(rumo.x, rumo.z)


func _mochila() -> Dictionary:
	var conta := {}
	for id in ["peixe", "robalo", "traira"]:
		conta[id] = inventario.quantidade(id)
	return conta


func _espaco_de(id: String) -> int:
	for i in inventario.ESPACOS_MAO:
		if inventario.espacos[i].get("id", "") == id:
			return i
	return -1


func _evento_e() -> InputEventKey:
	var evento := InputEventKey.new()
	evento.physical_keycode = KEY_E
	evento.keycode = KEY_E
	evento.pressed = true
	return evento


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("OFICIO_OK: o rio é doce e o mar é mar, com a traíra num e o robalo no outro; no píer a vara lança, a fisgada acende o sinal e o peixe vai para a mochila, sem vara não lança e andar recolhe; o fogo do terreiro cozinha; e a oficina provisória da beira do roçado serra tábua e torce corda")
	else:
		print("oficio: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


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
