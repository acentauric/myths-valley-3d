extends SceneTree
## Confere A PONTE DO RIO GRANDE, a frente da trilha do 2D (docs/projeto/MISSOES_DO_2D.md,
## 1.3; data/missoes_ponte.json; scripts/prototipo_3d/ponte_vale.gd).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/ponte.gd
##
## Oito perguntas:
##
##   1. O RIO GRANDE TEM VAU E PONTE: os dois nomes resolvem; o vau é água rasa a
##      poucos passos da ponte, e não em cima dela.
##   2. A PONTE COMEÇA CERCADA: uma cerca em cada cabeceira, atravessada na
##      estrada, e quem vem pela estrada bate nela.
##   3. A FRENTE ESPERA A CHEGADA E VEM ANTES DO MIRANTE: com a chegada em curso o
##      E no Pedro não a abre; acabada, o primeiro E abre a ponte, e o mirante não
##      abre enquanto ela não acabar.
##   4. VER E CONTAR: chegar ao vau fecha o primeiro passo; o E no Pedro fecha o
##      segundo, com a resposta dele no balão.
##   5. A LENHA CONTA O QUE JÁ VIROU TÁBUA: a conta sai das receitas — trinta e
##      seis, como a fala diz —; trinta lenhas não fecham, e três tábuas a mais sim.
##   6. SERRAR: doze tábuas e quatro cordas fecham o passo, que paga três beijus e
##      ensina o plano da obra.
##   7. A OBRA TIRA A CERCA: ao pé da ponte o J tem a obra; feita, a cerca sai e o
##      passo fecha e paga; desfeita (a partida de antes da obra), a cerca volta.
##   8. O FIM NO PEDRO: o E nele fecha a frente, e o mirante passa a abrir.

var falhas := 0
var vale
var tecla
var jogador
var pedro


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("PONTE_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	vale = current_scene
	tecla = vale.get("tecla_dos_moradores")
	jogador = vale.player
	pedro = vale.get("pedro")
	var mundo = vale.world
	var lugares = root.get_node("/root/Lugares")
	var inv = root.get_node("/root/Inventario")
	var obras = root.get_node("/root/Obras")
	# Carregados aqui, e não no topo: os dois citam autoloads, que no --script só
	# existem depois que a árvore sobe.
	var bancadas = load("res://scripts/prototipo_3d/bancadas_vale.gd")
	var cadeias = load("res://scripts/prototipo_3d/cadeia_de_missoes.gd")
	var receitas = root.get_node("/root/Receitas")
	root.get_node("/root/Dia").pausado = true
	var ponte = vale._cadeias.get("pedro_ponte")
	var arraial = vale._cadeias.get("pedro_arraial")
	var ponte_do_rio = vale.get("ponte_do_rio")
	_conferir(ponte != null and arraial != null and ponte_do_rio != null and pedro != null,
		"o vale não tem a frente da ponte (%s), o mirante (%s) ou a ponte do rio (%s)" % [str(ponte), str(arraial), str(ponte_do_rio)])
	if ponte == null or arraial == null or ponte_do_rio == null or pedro == null:
		_fechar()
		return

	# --- 1. O RIO GRANDE TEM VAU E PONTE -------------------------------------------------
	var vau: Vector3 = lugares.ponto("vau")
	var na_ponte: Vector3 = lugares.ponto("ponte_do_vau")
	_conferir(vau.is_finite() and na_ponte.is_finite(), "o vau (%s) ou a ponte do vau (%s) não resolve no vale" % [str(vau), str(na_ponte)])
	if not vau.is_finite() or not na_ponte.is_finite():
		_fechar()
		return
	var do_vau_a_ponte := Vector2(vau.x - na_ponte.x, vau.z - na_ponte.z).length()
	_conferir(do_vau_a_ponte > 3.0 and do_vau_a_ponte < 20.0,
		"o vau está a %.1f u da ponte: é a passagem a pé AO LADO dela" % do_vau_a_ponte)
	var lamina: float = mundo.water_depth_at(vau)
	_conferir(lamina > 0.0 and lamina < 1.0, "o vau não é água rasa: lâmina de %.2f u" % lamina)

	# --- 2. A PONTE COMEÇA CERCADA -------------------------------------------------------
	var dados: Dictionary = ponte_do_rio.ponte()
	_conferir(ponte_do_rio.interditada(), "a ponte não começou cercada")
	var cercas: Array = ponte_do_rio.cercas()
	_conferir(cercas.size() == 2, "a ponte tem %d cerca(s), e são duas, uma em cada cabeceira" % cercas.size())
	if not dados.is_empty():
		var centro: Vector3 = dados["centro"]
		var ao_longo: Vector3 = dados["ao_longo"]
		for cerca: Dictionary in cercas:
			var meio: Vector3 = (cerca["a"] + cerca["b"]) * 0.5
			var ate_o_meio := absf((meio - centro).dot(ao_longo))
			_conferir(absf(ate_o_meio - float(dados["comprimento"]) * 0.5) < 1.5,
				"a cerca está a %.1f u do meio da ponte, e a cabeceira a %.1f" % [ate_o_meio, float(dados["comprimento"]) * 0.5])
			var largura := Vector2(cerca["b"].x - cerca["a"].x, cerca["b"].z - cerca["a"].z).length()
			_conferir(largura >= float(dados["largura"]), "a cerca tem %.1f u e a ponte %.1f: sobra passagem" % [largura, float(dados["largura"])])
		# Quem vem pela estrada bate na cerca: um raio na altura do peito, de fora
		# para dentro da cabeceira.
		await physics_frame
		await physics_frame
		var cabeceira: Vector3 = centro + ao_longo * (float(dados["comprimento"]) * 0.5)
		var de: Vector3 = mundo.ground_position(cabeceira + ao_longo * 2.5) + Vector3.UP * 0.6
		var ate: Vector3 = mundo.ground_position(cabeceira - ao_longo * 1.5) + Vector3.UP * 0.6
		var consulta := PhysicsRayQueryParameters3D.create(de, ate)
		var batida: Dictionary = vale.get_world_3d().direct_space_state.intersect_ray(consulta)
		var na_cerca: bool = not batida.is_empty() and batida["collider"] is Node and ponte_do_rio.is_ancestor_of(batida["collider"])
		_conferir(na_cerca, "quem vem pela estrada não bate na cerca da cabeceira: o raio %s" % ("não bateu em nada" if batida.is_empty() else "bateu em " + str(batida["collider"])))

	# --- 3. A FRENTE ESPERA A CHEGADA E VEM ANTES DO MIRANTE --------------------------------
	await _perto_do_pedro()
	for i in 3:
		tecla.usar(pedro)
		await _quadros(3)
	_conferir(not ponte.iniciado, "com a chegada em curso, o E no Pedro abriu a ponte")
	pedro.missao = pedro.MISSOES.size()
	pedro.set("_despedida_feita", true)
	await _perto_do_pedro()
	tecla.usar(pedro)
	_conferir(await _ate(func() -> bool: return ponte.iniciado, 4.0), "acabada a chegada, o primeiro E no Pedro não abriu a ponte")
	_conferir(not arraial.iniciado, "o E que abriu a ponte abriu o mirante junto")
	_conferir(arraial.o_que_o_e_faz(pedro) != "abrir", "o mirante abre com a ponte por fazer: no 2D ele é do arraial, depois do tutorial")

	# --- 4. VER E CONTAR -----------------------------------------------------------------
	await _ate(func() -> bool: return ponte.espera <= 0.0, 12.0)
	_conferir(str(ponte.passo_atual().get("id", "")) == "ponte_caida", "a frente não começou por ver a ponte: '%s'" % str(ponte.passo_atual().get("id", "")))
	jogador.teleportar(vau + Vector3(0, 0.4, 0), 0.0)
	_conferir(await _ate(func() -> bool: return ponte.missao >= 1, 8.0), "chegar ao vau não fechou o passo de ver a ponte")
	await _ate(func() -> bool: return ponte.espera <= 0.0, 12.0)
	await _perto_do_pedro()
	tecla.usar(pedro)
	_conferir(await _ate(func() -> bool: return ponte.missao >= 2, 8.0), "o E no Pedro não fechou o passo de contar o que viu")
	_conferir(_no_balao(pedro).contains("Cercada"), "o Pedro não respondeu sobre a cerca: '%s'" % _no_balao(pedro))

	# --- 5. A LENHA CONTA O QUE JÁ VIROU TÁBUA -------------------------------------------------
	await _ate(func() -> bool: return ponte.espera <= 0.0, 12.0)
	var da_lenha: Dictionary = ponte.passo_atual()
	_conferir(str(da_lenha.get("id", "")) == "ponte_lenha", "depois de contar não veio a lenha: '%s'" % str(da_lenha.get("id", "")))
	var conta: int = cadeias.alvo_da_equivalencia(da_lenha.get("meta", {}))
	_conferir(conta == 36, "a conta da lenha da ponte saiu %d das receitas, e a fala diz trinta e seis" % conta)
	_conferir(str(da_lenha.get("texto", "")).contains("trinta e seis"), "a fala da lenha não diz a conta que a missão cobra")
	for item in ["lenha", "tabua", "corda"]:
		inv.consumir(item, inv.quantidade(item))
	var assados: int = inv.quantidade("peixe_assado")
	inv.adicionar("lenha", 30)
	await _quadros(8)
	_conferir(ponte.missao == 2, "trinta lenhas fecharam o passo dos trinta e seis")
	inv.adicionar("tabua", 3)
	_conferir(await _ate(func() -> bool: return ponte.missao >= 3, 8.0),
		"trinta lenhas e três tábuas — seis lenhas serradas — não fecharam o passo: a tábua não conta como lenha")
	_conferir(inv.quantidade("peixe_assado") == assados + 2, "a lenha não pagou os dois peixes assados")

	# --- 6. SERRAR -------------------------------------------------------------------------
	await _ate(func() -> bool: return ponte.espera <= 0.0, 12.0)
	_conferir(str(ponte.passo_atual().get("id", "")) == "tabuas", "depois da lenha não veio serrar: '%s'" % str(ponte.passo_atual().get("id", "")))
	_conferir(receitas.sabe("ponte_levantar"), "o passo de serrar não ensinou o plano da obra da ponte")
	var beijus: int = inv.quantidade("beiju")
	inv.adicionar("tabua", 9)
	await _quadros(8)
	_conferir(ponte.missao == 3, "doze tábuas sem as cordas fecharam o passo de serrar")
	inv.adicionar("corda", 4)
	_conferir(await _ate(func() -> bool: return ponte.missao >= 4, 8.0), "doze tábuas e quatro cordas não fecharam o passo de serrar")
	_conferir(inv.quantidade("beiju") == beijus + 3, "serrar não pagou os três beijus")

	# --- 7. A OBRA TIRA A CERCA ------------------------------------------------------------
	await _ate(func() -> bool: return ponte.espera <= 0.0, 12.0)
	_conferir(str(ponte.passo_atual().get("id", "")) == "ponte", "depois de serrar não veio a obra: '%s'" % str(ponte.passo_atual().get("id", "")))
	if not dados.is_empty():
		var ao_pe: Vector3 = dados["centro"] + dados["ao_longo"] * (float(dados["comprimento"]) * 0.5 + 1.5)
		_conferir(bancadas.obra_perto(mundo, ao_pe) == "ponte", "ao pé da ponte o J não tem a aba de obras dela: '%s'" % bancadas.obra_perto(mundo, ao_pe))
	_conferir(obras.disponiveis("ponte").has("ponte_levantar"), "a obra da ponte não está na lista dela: %s" % str(obras.disponiveis("ponte")))
	var piroes: int = inv.quantidade("pirao")
	var cocadas: int = inv.quantidade("cocada")
	_conferir(obras.executar("ponte", "ponte_levantar"), "a obra da ponte não saiu: %s" % str(obras.impedimento("ponte", "ponte_levantar")))
	_conferir(await _ate(func() -> bool: return not ponte_do_rio.interditada(), 3.0), "a obra feita não tirou a cerca da ponte")
	_conferir(await _ate(func() -> bool: return ponte.missao >= 5, 8.0), "a obra feita não fechou o passo da ponte")
	_conferir(inv.quantidade("pirao") == piroes + 2 and inv.quantidade("cocada") == cocadas + 2,
		"a ponte não pagou os dois pirões e as duas cocadas")
	var feitas: Dictionary = (obras.feitas as Dictionary).duplicate(true)
	obras.feitas.erase("ponte")
	ponte_do_rio.acertar()
	_conferir(ponte_do_rio.interditada(), "na partida de antes da obra, a cerca não voltou")
	obras.feitas = feitas
	ponte_do_rio.acertar()
	_conferir(not ponte_do_rio.interditada(), "devolvida a obra, a cerca não saiu de novo")

	# --- 8. O FIM NO PEDRO ---------------------------------------------------------------
	await _ate(func() -> bool: return ponte.espera <= 0.0, 12.0)
	await _perto_do_pedro()
	tecla.usar(pedro)
	_conferir(await _ate(func() -> bool: return ponte.acabou(), 8.0), "o E no Pedro não fechou a frente da ponte")
	_conferir(_no_balao(pedro).contains("De pé"), "o Pedro não disse o fim da ponte: '%s'" % _no_balao(pedro))
	_conferir(arraial.o_que_o_e_faz(pedro) == "abrir", "acabada a ponte, o mirante não abre no E do Pedro: '%s'" % arraial.o_que_o_e_faz(pedro))
	_fechar()


func _perto_do_pedro() -> void:
	jogador.teleportar(pedro.global_position + Vector3(1.0, 0.1, 0.6), 0.0)
	await _quadros(5)


func _no_balao(morador) -> String:
	var rotulo = morador.balao.get("_texto")
	return str(rotulo.text) if rotulo != null else ""


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("PONTE_OK: o rio grande tem o vau ao lado da ponte, e a ponte começa cercada nas duas cabeceiras; a frente espera a chegada, abre no primeiro E do Pedro e segura o mirante; ver a ponte e contar ao Pedro fecham os dois primeiros passos; a lenha conta o que já virou tábua, na conta das receitas; serrar ensina o plano da obra e paga; a obra tira a cerca, e a partida de antes dela a põe de volta; e o fim no Pedro abre o mirante")
	else:
		print("ponte: %d falha(s)" % falhas)
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
