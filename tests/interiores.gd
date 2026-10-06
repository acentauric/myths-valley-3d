extends SceneTree
## Confere AS CONSTRUÇÕES POR DENTRO, a começar pela igreja (#26) — dentro da
## própria construção, no lugar dela no vale.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/interiores.gd
##
## `interiores_procedural.gd` faz o outro estilo: lá a casca é outra (a torre no
## meio da fachada, o cruzeiro a um passo dela), e o cômodo mede a casca que há.
##
## "Os cômodos têm que ser em 3D mesmo. O 2D é só referência", com a escolha de
## que o interior fica dentro da construção. Oito perguntas:
##
##   1. O CÔMODO ESTÁ DENTRO DA IGREJA: perto do meio dela, de costas para a
##      fachada, e no tamanho que a casca do modelo mediu — nem maior que ela.
##   2. A PORTA ESTÁ ABERTA E AS PAREDES FECHADAS: um raio pela porta passa, um
##      raio pela parede bate.
##   3. ENTRA-SE ANDANDO: com a tecla de andar, do adro até a nave, sem
##      escurecer nenhum; lá dentro o corpo pisa o chão, o HUD diz onde se está,
##      e a câmera fica lá dentro com ele — não sai pela porta para o adro.
##   4. A IGREJA TEM O QUE UMA IGREJA TEM: bancos com colisão, altar, velas e a
##      luz de dentro.
##   5. A LUZ NÃO VAZA: nenhuma luz do cômodo acende a camada do mundo — o
##      lampião da nave não clareia o adro através da parede.
##   6. O PEDRO ACHA A PORTA: do adro para dentro, o caminho passa pela soleira
##      de fora e depois pela de dentro.
##   7. CARREGAR LÁ DENTRO PÕE O CORPO NA NAVE, e não embaixo do assoalho.
##   8. O PEDRO ENTRA JUNTO: do adro, com o jogador na nave, ele acha a porta
##      e entra — sem ficar indo e vindo no patamar.

var falhas := 0


func _estilo_do_portao() -> String:
	return "tripo"


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("INTERIORES_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	root.get_node("/root/Estilo").modo = _estilo_do_portao()
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(8)
	var vale = current_scene
	var interiores = vale.get("interiores")
	var jogador = vale.get("player")
	_conferir(interiores != null and jogador != null, "o vale não montou as construções por dentro")
	if interiores == null or jogador == null:
		_fechar()
		return
	# O PEDRO SEGUE O JOGADOR DESDE O COMEÇO, num passo em que ele segue (a roça),
	# como seguia na partida antiga: no desembarque da partida nova ele fica na
	# ponta da prancha. Posto para seguir só na hora de entrar junto, no
	# procedural ele empacava diante da escadaria da igreja e o desvio o levava
	# pela fachada: não achava a porta em 14 s (05/10/2026).
	var guia = vale.get("pedro")
	if guia != null:
		guia.ir_ao_passo("roca")

	# --- 1. DENTRO DA IGREJA ---------------------------------------------------
	var sala: Node3D = interiores.sala_de("igreja")
	_conferir(sala != null, "a igreja não tem cômodo")
	if sala == null:
		_fechar()
		return
	var igreja: Vector3 = vale.world.ancoras["Igreja"]
	var frente: Vector3 = sala.global_basis.z.normalized()
	var meio_da_nave: Vector3 = sala.to_global(Vector3(0, 0, -sala.comprimento * 0.5))
	_conferir(Vector2(meio_da_nave.x - igreja.x, meio_da_nave.z - igreja.z).length() < 2.5,
		"o meio da nave está a %.1f do meio da igreja: o cômodo não está dentro dela"
			% Vector2(meio_da_nave.x - igreja.x, meio_da_nave.z - igreja.z).length())
	var frente_do_lote: Vector3 = vale.world.ancoras.get("IgrejaFrente", Vector3.BACK)
	_conferir(frente.dot(frente_do_lote.normalized()) > 0.95, "a porta do cômodo não está do lado da fachada da igreja")
	_conferir(sala.largura > 3.0 and sala.largura < 9.0 and sala.comprimento > 5.0 and sala.comprimento < 14.0,
		"o cômodo tem %.1f por %.1f: não é a medida da casca da igreja" % [sala.largura, sala.comprimento])
	print("  nave: %.1f x %.1f, pé-direito %.1f, soleira %.2f" % [sala.largura, sala.comprimento, sala.pe_direito, sala.altura_da_soleira])
	var caixa_inteira: Node = vale.world.get_node_or_null("IgrejaColisao")
	_conferir(caixa_inteira == null or caixa_inteira.is_queued_for_deletion(),
		"a caixa de colisão inteira da igreja continua lá: ninguém entra")

	# --- 2. PORTA ABERTA, PAREDES FECHADAS -------------------------------------
	var espaco: PhysicsDirectSpaceState3D = vale.world.get_world_3d().direct_space_state
	var fora: Vector3 = sala.soleira_de_fora() + Vector3.UP * 1.2
	var por_dentro: Vector3 = sala.soleira_de_dentro() + Vector3.UP * 1.2
	var pela_porta := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(fora, por_dentro, 1))
	_conferir(pela_porta.is_empty(), "o caminho pela porta bate em '%s'" % str(pela_porta.get("collider")))
	var lado: Vector3 = sala.global_basis.x.normalized()
	var de_lado: Vector3 = meio_da_nave + Vector3.UP * 1.2 + lado * (sala.largura * 0.5 + 3.0)
	var pela_parede := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(de_lado, meio_da_nave + Vector3.UP * 1.2, 1))
	_conferir(not pela_parede.is_empty(), "a parede da igreja não tem colisão: atravessa-se de lado")

	# --- 3. ENTRA-SE ANDANDO ---------------------------------------------------
	var rumo := atan2(frente.x, frente.z) - PI
	jogador.teleportar(vale.world.ground_position(sala.soleira_de_fora(), 0.05), rumo)
	await _frames(3)
	_conferir(interiores.dentro() == "", "de pé no adro, o jogo diz que estou dentro da igreja")
	Input.action_press("mv_forward")
	var entrou := await _ate(func() -> bool: return interiores.dentro() == "igreja", 8.0)
	await _segundos(1.2)
	Input.action_release("mv_forward")
	_conferir(entrou, "andando para a porta, não entrei na igreja: o corpo parou em %s" % str(jogador.global_position))
	await _quadros_de_fisica(30)
	_conferir(sala.contem(jogador.global_position), "andei e o corpo não está dentro da nave")
	_conferir(jogador.is_on_floor(), "dentro da igreja o corpo não está no chão")
	var no_chao: float = sala.to_local(jogador.global_position).y
	_conferir(absf(no_chao) < 0.6, "o corpo está %.2f acima do chão da nave" % no_chao)
	_conferir(jogador.dentro_de == "igreja", "o jogador não sabe que está na igreja (os passos)")
	var titulo: String = str(vale.hud.get("_region_label").text)
	_conferir(titulo.contains("IGREJA"), "dentro da igreja o HUD diz '%s'" % titulo)
	# A câmera, com o jogador logo depois da porta e de costas para ela: o braço
	# dela aponta para o vão, e sem a cortina ia parar no adro.
	jogador.teleportar(sala.to_global(Vector3(0, 0.05, -1.5)), rumo)
	await _quadros_de_fisica(20)
	var camera: Camera3D = jogador.get("camera")
	var olho: float = sala.to_local(camera.global_position).z
	_conferir(olho < 0.4,
		"com o jogador na nave, a câmera foi parar %.2f além da parede da frente: no vão ou no adro, só se vê o escuro da porta ou o avesso da parede" % olho)
	# E com ele lá fora, de costas para a porta, a câmera não entra pelo vão.
	jogador.teleportar(vale.world.ground_position(sala.soleira_de_fora(), 0.05), rumo + PI)
	await _quadros_de_fisica(20)
	var olho_de_fora: float = sala.to_local(camera.global_position).z
	var vao: float = (sala.get_node("PortaAberta") as Node3D).position.z
	_conferir(olho_de_fora > vao,
		"com o jogador no adro, a câmera entrou %.2f pelo vão da porta" % (vao - olho_de_fora))
	jogador.teleportar(sala.to_global(Vector3(0, 0.05, -1.5)), rumo)
	await _quadros_de_fisica(10)

	# --- 4. O QUE UMA IGREJA TEM -----------------------------------------------
	var bancos := sala.find_children("BancoColisao_*", "", true, false).size()
	_conferir(bancos >= 4, "a nave tem %d banco(s)" % bancos)
	_conferir(not sala.find_children("Altar_*", "", true, false).is_empty(), "a igreja não tem altar")
	var velas := sala.find_children("Vela_*", "OmniLight3D", true, false).size()
	_conferir(velas >= 2, "o altar tem %d vela(s) acesa(s)" % velas)
	# NINGUÉM SOBE NO ALTAR (#98): por cima dele há guarda sólida até acima da
	# cabeça — um raio de cima para baixo sobre a mesa bate bem acima dela —, e
	# o ponto da reza, diante do altar, continua livre.
	var estrado: float = float(sala.ALTURA_DO_PRESBITERIO)
	var sobre_o_altar_local := Vector3(0.0, estrado + 3.0, -float(sala.comprimento) + 0.85)
	var de_cima: Vector3 = sala.to_global(sobre_o_altar_local)
	var ate_a_mesa: Vector3 = sala.to_global(sobre_o_altar_local - Vector3.UP * 3.0)
	var sobre_o_altar := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(de_cima, ate_a_mesa, 1))
	var topo: float = float(sala.to_local(sobre_o_altar.get("position", ate_a_mesa)).y) - estrado
	_conferir(not sobre_o_altar.is_empty() and topo >= 2.0,
		"por cima do altar o primeiro sólido está a %.2f u do estrado: dá para subir nele" % topo)
	var reza: Vector3 = sala.ponto_do_altar()
	var na_reza := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(reza + Vector3.UP * 2.5, reza + Vector3.UP * 0.3, 1))
	_conferir(na_reza.is_empty(), "a guarda do altar cobre o ponto da reza (bateu em '%s')" % str(na_reza.get("collider")))
	_conferir(not sala.find_children("LuzDeDentro", "ReflectionProbe", true, false).is_empty(),
		"a igreja não tem a luz de dentro: as paredes sairiam claras como as de fora")

	# --- 5. A LUZ NÃO VAZA -----------------------------------------------------
	for luz in sala.find_children("*", "Light3D", true, false):
		_conferir(((luz as Light3D).light_cull_mask & 1) == 0,
			"a luz '%s' do cômodo acende a camada do mundo: vaza pela parede" % str(luz.name))

	# --- 6. O PEDRO ACHA A PORTA -----------------------------------------------
	var la_fora: Vector3 = sala.soleira_de_fora() + frente * 6.0
	var primeiro: Vector3 = interiores.passagem(la_fora, meio_da_nave)
	_conferir(primeiro.distance_to(sala.soleira_de_fora()) < 0.1,
		"do adro para a nave, o primeiro ponto não é a soleira de fora")
	var segundo: Vector3 = interiores.passagem(sala.soleira_de_fora(), meio_da_nave)
	_conferir(segundo.distance_to(sala.soleira_de_dentro()) < 0.1,
		"da soleira de fora, o passo seguinte não é entrar pela porta")
	_conferir(interiores.passagem(la_fora, la_fora + Vector3(3, 0, 0)).is_equal_approx(la_fora + Vector3(3, 0, 0)),
		"fora da igreja, sem porta no caminho, a passagem desvia")

	# --- 7. CARREGAR LÁ DENTRO -------------------------------------------------
	var na_nave: Vector3 = jogador.global_position
	var guardado: Dictionary = vale.estado_para_salvar()
	jogador.teleportar(la_fora, 0.0)
	await _frames(2)
	vale.restaurar_do_save(guardado)
	await _quadros_de_fisica(20)
	_conferir(sala.contem(jogador.global_position) and jogador.global_position.distance_to(na_nave) < 1.0,
		"carregar a partida salva na nave não pôs o corpo de volta na nave: está em %s" % str(jogador.global_position))

	# --- 8. O PEDRO ENTRA JUNTO ------------------------------------------------
	var pedro: Node3D = vale.get("pedro")
	_conferir(pedro != null, "o vale não tem o Pedro")
	if pedro != null:
		jogador.teleportar(meio_da_nave, rumo)
		pedro.global_position = vale.world.ground_position(sala.soleira_de_fora() + frente * 5.0 + lado * 1.5, 0.05)
		var pedro_entrou := await _ate(func() -> bool: return sala.contem(pedro.global_position), 14.0)
		_conferir(pedro_entrou, "com o jogador na nave, o Pedro não entrou: ficou em %s, no cômodo"
			% str(sala.to_local(pedro.global_position)))
	_fechar()


func _fechar() -> void:
	Input.action_release("mv_forward")
	print("")
	if falhas == 0:
		print("INTERIORES_OK (", _estilo_do_portao(), "): o cômodo mora dentro da igreja, de costas para a fachada e na medida da casca; a porta está aberta e as paredes fechadas; entra-se andando e lá dentro o corpo pisa o chão e o HUD diz onde está; a câmera fica lá dentro com ele; a nave tem bancos, altar, velas e a luz de dentro, que não vaza para o adro; o Pedro acha a porta e entra junto; e carregar lá dentro põe o corpo na nave")
	else:
		print("interiores (%s): %d falha(s)" % [_estilo_do_portao(), falhas])
	quit(1 if falhas > 0 else 0)


func _ate(condicao: Callable, segundos: float) -> bool:
	var ate := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < ate:
		if bool(condicao.call()):
			return true
		await process_frame
	return bool(condicao.call())


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
