extends SceneTree
## Confere AS CONSTRUÇÕES POR DENTRO, a começar pela igreja (#26).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/interiores.gd
##
## "Vamos começar a criar os ambientes internos das construções também. Comece
## pela igreja." O cômodo mora longe do vale (ver `interiores.gd`), e a porta da
## fachada leva até ele. Seis perguntas:
##
##   1. A PORTA DE FORA EXISTE, rente ao chão da fachada, e a dica aparece nela.
##   2. O E ENTRA: o corpo vai para a soleira de dentro, e o vale passa a vê-lo na
##      porta de fora (`posicao_no_mapa`) — é o que a bússola, o mapa, o Pedro e o
##      save leem.
##   3. LÁ DENTRO HÁ CHÃO: o corpo assenta e não cai, que é o defeito mais caro de
##      um cômodo montado à parte.
##   4. A IGREJA TEM O QUE UMA IGREJA TEM: os bancos com colisão, o altar, as velas
##      acesas e a luz de dentro (a sonda que troca o céu pela luz da sala).
##   5. SALVAR LÁ DENTRO GUARDA A PORTA, e não o lugar longe do vale.
##   6. O E NA PORTA DE DENTRO SAI para a soleira de fora; e sair por outro lado
##      (o destravar, a queda) desfaz o "dentro" sozinho.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("INTERIORES_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(6)
	var vale = current_scene
	var interiores = vale.get("interiores")
	var jogador = vale.get("player")
	_conferir(interiores != null and jogador != null, "o vale não montou as construções por dentro")
	if interiores == null or jogador == null:
		_fechar()
		return

	# --- 1. A PORTA DE FORA ----------------------------------------------------
	var porta: Vector3 = interiores.porta_de("igreja")
	_conferir(porta.is_finite(), "a igreja não tem porta de fora")
	var sala: Node3D = interiores.sala_de("igreja")
	_conferir(sala != null, "a igreja não tem cômodo")
	if not porta.is_finite() or sala == null:
		_fechar()
		return
	var igreja: Vector3 = vale.world.ancoras["Igreja"]
	var da_igreja := Vector2(porta.x - igreja.x, porta.z - igreja.z).length()
	_conferir(da_igreja > 3.0 and da_igreja < 14.0,
		"a porta está a %.1f do meio da igreja: não está na fachada" % da_igreja)
	_conferir(absf(porta.y - vale.world.ground_height_at(porta)) < 0.6,
		"a porta flutua ou afunda: %.2f contra o chão em %.2f" % [porta.y, vale.world.ground_height_at(porta)])
	jogador.teleportar(porta, 0.0)
	await _frames(3)
	_conferir(interiores._na_porta == "igreja", "de pé na porta da igreja, ela não oferece a entrada")

	# --- 2. O E ENTRA ----------------------------------------------------------
	_tecla_de_interagir()
	await _segundos(1.2)
	_conferir(interiores.dentro() == "igreja", "o E na porta não entrou na igreja")
	_conferir(jogador.no_interior(), "o jogador entrou e não sabe que está dentro")
	_conferir(jogador.global_position.distance_to(sala.chegada()) < 1.5,
		"o corpo foi para %s, e a soleira de dentro é %s" % [str(jogador.global_position), str(sala.chegada())])
	_conferir(jogador.posicao_no_mapa().distance_to(porta) < 0.01,
		"lá dentro, o vale vê o jogador em %s, e não na porta %s" % [str(jogador.posicao_no_mapa()), str(porta)])

	# --- 3. LÁ DENTRO HÁ CHÃO --------------------------------------------------
	await _quadros_de_fisica(90)
	var altura_do_chao: float = sala.global_position.y
	_conferir(absf(jogador.global_position.y - altura_do_chao) < 0.5,
		"o corpo não assentou no chão da nave: está em %.2f e o chão em %.2f" % [jogador.global_position.y, altura_do_chao])
	_conferir(jogador.is_on_floor(), "dentro da igreja o corpo não está no chão")
	_conferir(not jogador.is_swimming(), "dentro da igreja o corpo está nadando")

	# --- 4. O QUE UMA IGREJA TEM -----------------------------------------------
	var bancos := sala.find_children("BancoColisao_*", "", true, false).size()
	_conferir(bancos >= 8, "a nave tem %d banco(s); uma capela de arraial tem pelo menos oito" % bancos)
	_conferir(not sala.find_children("Altar_*", "", true, false).is_empty(), "a igreja não tem altar")
	var velas := sala.find_children("Vela_*", "OmniLight3D", true, false).size()
	_conferir(velas >= 2, "o altar tem %d vela(s) acesa(s)" % velas)
	_conferir(not sala.find_children("LuzDeDentro", "ReflectionProbe", true, false).is_empty(),
		"a igreja não tem a luz de dentro: as paredes sairiam claras como as de fora")

	# --- 5. SALVAR LÁ DENTRO GUARDA A PORTA ------------------------------------
	var onde: Array = vale.estado_para_salvar().get("jogador", [])
	_conferir(onde.size() == 3 and Vector3(onde[0], onde[1], onde[2]).distance_to(porta) < 0.01,
		"salvar dentro da igreja guardou %s, e não a porta %s" % [str(onde), str(porta)])

	# --- 6. SAIR ---------------------------------------------------------------
	jogador.teleportar(sala.porta() - Vector3(0, 1.15, 0) + Vector3(0, 0, -0.6), 0.0)
	await _frames(3)
	_conferir(interiores._na_porta == "igreja", "de pé na porta de dentro, ela não oferece a saída")
	_tecla_de_interagir()
	await _segundos(1.2)
	_conferir(interiores.dentro() == "", "o E na porta de dentro não saiu da igreja")
	_conferir(not jogador.no_interior(), "o jogador saiu e continua achando que está dentro")
	_conferir(Vector2(jogador.global_position.x - porta.x, jogador.global_position.z - porta.z).length() < 2.0,
		"o corpo saiu para %s, longe da porta %s" % [str(jogador.global_position), str(porta)])

	# E SAIR POR OUTRO LADO: entra, e o corpo vai embora sem passar pela porta.
	interiores.entrar("igreja")
	await _segundos(1.2)
	_conferir(interiores.dentro() == "igreja", "não consegui entrar de novo para a pergunta do outro lado")
	jogador.teleportar(porta + Vector3(0, 0, 4.0), 0.0)
	await _frames(4)
	_conferir(interiores.dentro() == "", "o corpo foi embora da igreja sem passar pela porta e o 'dentro' ficou valendo")
	_conferir(not jogador.no_interior(), "saiu por outro lado e o jogador continua com a porta de dentro")
	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("INTERIORES_OK: a igreja tem porta na fachada com a dica, o E entra e o vale vê o jogador na porta; lá dentro o corpo assenta no chão; a nave tem bancos, altar, velas e a luz de dentro; salvar lá dentro guarda a porta; o E na porta de dentro sai, e sair por outro lado desfaz o dentro")
	else:
		print("interiores: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _tecla_de_interagir() -> void:
	var Atalhos = load("res://scripts/prototipo_3d/atalhos.gd")
	var evento := InputEventKey.new()
	evento.physical_keycode = Atalhos.tecla("interagir")
	evento.pressed = true
	Input.parse_input_event(evento)


func _segundos(quanto: float) -> void:
	var ate := Time.get_ticks_msec() + int(quanto * 1000.0)
	while Time.get_ticks_msec() < ate:
		await process_frame


func _quadros_de_fisica(quantos: int) -> void:
	for i in quantos:
		await physics_frame


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
