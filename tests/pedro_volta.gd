extends SceneTree
## O PEDRO VEM JUNTO QUANDO O JOGADOR APAGA (#92).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/pedro_volta.gd
##
## Na live o jogador apagou nadando e acordou em casa; o Pedro ficou no mar.
## Enquanto o tutorial dura, quem apaga acorda com o Pedro esperando na porta,
## do lado de fora, e a condução recomeça dali (`queda._levar_para_casa`,
## `guia_pedro.vir_para_a_porta`).
##
##   1. ANTES, o Pedro está longe da casa (na prancha do saveiro).
##   2. CAÍDO, o jogador acorda em casa e o Pedro está na porta, em terra, sem nadar.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("PEDRO_VOLTA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	var vale = current_scene
	var jogador = vale.player
	var mundo = vale.world
	var pedro = vale.get("pedro")
	var noite = vale.get("noite")
	var vida = root.get_node("/root/Vida")
	_conferir(pedro != null and noite != null, "o vale não tem o Pedro ou a noite")
	if pedro == null or noite == null:
		_fechar()
		return
	_conferir(not bool(pedro.terminou_o_tutorial()), "a partida nova já começou sem tutorial")
	var casa: Vector3 = noite.ponto_de_casa()
	var porta: Vector3 = noite.diante_da_porta(2.0)
	_conferir(casa.is_finite() and porta.is_finite(), "a casa (%s) ou a porta (%s) não resolve" % [str(casa), str(porta)])

	# --- 1. ANTES ---------------------------------------------------------------
	var longe: float = pedro.global_position.distance_to(porta)
	_conferir(longe > 20.0, "o Pedro já começa a %.0f u da porta: a prova não vale" % longe)

	# --- 2. CAÍDO ----------------------------------------------------------------
	var acordou := [false]
	noite.acordou.connect(func(): acordou[0] = true)
	vida.ferir(vida.maximo())
	_conferir(await _ate(func() -> bool: return acordou[0], 30.0), "caído, o jogador não acordou em 30 s")
	await _quadros(3)
	_conferir(jogador.global_position.distance_to(casa) < 2.0, "o jogador não acordou em casa (está a %.1f u)" % jogador.global_position.distance_to(casa))
	var ate_a_porta: float = pedro.global_position.distance_to(porta)
	_conferir(ate_a_porta < 3.0, "o Pedro não veio para a porta: está a %.1f u dela" % ate_a_porta)
	await _quadros(10)
	var lamina: float = mundo.water_depth_at(pedro.global_position)
	# Uma poça de palmo na porta não é água de nado (o `water_depth_at` devolve
	# centímetros em terra junto da casa); o que importa é não estar nadando.
	_conferir(not bool(pedro.get("_nadando")) and lamina < 0.3,
		"o Pedro continua na água (nadando %s, lâmina %.2f, em %s, água %.2f)" % [str(pedro.get("_nadando")), lamina, str(pedro.global_position), mundo.water_level_at(pedro.global_position)])
	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("PEDRO_VOLTA_OK: quem apaga no tutorial acorda em casa com o Pedro esperando na porta, em terra")
	else:
		print("pedro_volta: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicao.call():
			return true
		await process_frame
	return condicao.call()


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
