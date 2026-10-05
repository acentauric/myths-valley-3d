extends SceneTree
## Confere que NINGUÉM PRENDE O JOGADOR NUMA PORTA — e que o Pedro para de
## seguir depois do tutorial.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/passagem.gd
##
## "Ao entrar na casa para dormir, o Pedro me seguiu e bloqueou a porta. Não
## consigo mais sair de casa." Três perguntas:
##
##   1. O PEDRO NÃO ENTRA NA CASA. Com o jogador lá dentro, durante o tutorial,
##      ele espera do lado de fora, fora do vão da porta — e, se já estava
##      dentro, sai.
##   2. QUEM BARRA DÁ PASSAGEM. Um morador parado no vão da porta, e o jogador
##      lá dentro andando para fora (a tecla de andar, de verdade): o morador
##      sai do caminho e o jogador sai de casa.
##   3. DEPOIS DO TUTORIAL, O PEDRO PARA DE SEGUIR: com as nove missões e a
##      despedida, ele vai para o posto dele e não vem atrás do jogador.
##
## As esperas são em SEGUNDO REAL e contam passos de física: andar é física, e
## com a máquina ocupada cabem menos passos por segundo.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("PASSAGEM_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	var vale = current_scene
	var jogador = vale.player
	var pedro = vale.get("pedro")
	var interiores = vale.get("interiores")
	_conferir(pedro != null and interiores != null, "o vale não tem o Pedro ou os cômodos")
	if pedro == null or interiores == null:
		_fechar()
		return
	var sala = interiores.sala_de("casa")
	_conferir(sala != null, "a casa herdada não tem cômodo")
	if sala == null:
		_fechar()
		return
	root.get_node("/root/Dia").pausado = true
	_conferir(not pedro.terminou_o_tutorial(), "a partida nova começa com o tutorial já terminado")

	# --- 1. O PEDRO NÃO ENTRA NA CASA ------------------------------------------
	# Depois da casa aberta (a roça): o Pedro, que até ali conduziu, de volta a
	# seguir o jogador — e esperando do lado de fora quando ele entra em casa.
	_conferir(pedro.ir_ao_passo("roca"), "a chegada não tem o passo da roça")
	vale._acertar_a_porta_da_casa()
	jogador.teleportar(sala.lugar_de_acordar(), 0.0)
	pedro.global_position = sala.soleira_de_fora() + (sala.soleira_de_fora() - sala.soleira_de_dentro()).normalized() * 2.5
	await _passos(240)
	_conferir(interiores.contem(pedro.global_position) == "", "com o jogador em casa, o Pedro entrou atrás dele")
	_conferir(not sala.no_vao(pedro.global_position), "com o jogador em casa, o Pedro parou no vão da porta")
	# E se ele já estava dentro, sai.
	pedro.global_position = sala.to_global(Vector3(sala.largura * 0.2, 0.05, -sala.comprimento * 0.55))
	await _passos(480)
	_conferir(interiores.contem(pedro.global_position) == "", "o Pedro que estava dentro de casa não saiu")
	_conferir(not sala.no_vao(pedro.global_position), "o Pedro saiu de casa e ficou no vão da porta")
	print("  pedro esperando a %.2f do lugar de esperar, do lado de fora" % (pedro.global_position - sala.lugar_de_esperar_fora()).length())

	# --- 2. QUEM BARRA DÁ PASSAGEM ---------------------------------------------
	# Um morador de pé no vão, querendo ficar ali, e o jogador lá dentro andando
	# para fora.
	var barra = null
	for morador in vale.moradores:
		if str(morador.dados.get("id", "")) == "filo":
			barra = morador
	_conferir(barra != null, "não achei a Dona Filó para barrar a porta")
	if barra != null:
		var no_vao: Vector3 = sala.to_global(Vector3(sala.porta_x, 0.05, -0.1))
		barra.global_position = no_vao
		barra.ir_ate(no_vao, 0.5)
		var de_dentro: Vector3 = sala.to_global(Vector3(sala.porta_x, 0.05, -1.6))
		var rumo: Vector3 = sala.soleira_de_fora() - de_dentro
		jogador.teleportar(de_dentro, atan2(-rumo.x, -rumo.z) - PI)
		await _passos(4)
		Input.action_press("mv_forward")
		var saiu := false
		for i in 600:
			await physics_frame
			if interiores.contem(jogador.global_position) == "":
				saiu = true
				break
		Input.action_release("mv_forward")
		_conferir(saiu, "a Dona Filó parada no vão da porta prendeu o jogador dentro de casa")
		_conferir(not saiu or not sala.no_vao(barra.global_position) or barra.dando_passagem(),
			"o jogador saiu, mas a Dona Filó não deu passagem")
		barra.liberar()

	# --- 3. DEPOIS DO TUTORIAL, O PEDRO PARA DE SEGUIR -----------------------------
	pedro.missao = pedro.MISSOES.size()
	pedro.set("_despedida_feita", true)
	_conferir(pedro.terminou_o_tutorial(), "com as nove missões e a despedida, o tutorial não terminou")
	var praca: Vector3 = vale.world.ancoras["Praça"]
	jogador.teleportar(vale.world.ground_position(praca + Vector3(6, 0, 6), 0.07), 0.0)
	pedro.global_position = vale.world.ground_position(praca + Vector3(4, 0, 4), 0.05)
	var posto: Vector3 = pedro._posicao_do_posto(pedro._posto_de_agora())
	var antes: float = Vector2(pedro.global_position.x - posto.x, pedro.global_position.z - posto.z).length()
	await _passos(360)
	var depois: float = Vector2(pedro.global_position.x - posto.x, pedro.global_position.z - posto.z).length()
	_conferir(depois < antes - 2.0, "depois do tutorial o Pedro não foi para o posto dele (de %.1f para %.1f)" % [antes, depois])
	var do_jogador: float = pedro.global_position.distance_to(jogador.global_position)
	_conferir(do_jogador > 4.0, "depois do tutorial o Pedro continua colado no jogador (%.1f)" % do_jogador)
	print("  pedro a caminho do posto: de %.1f para %.1f; longe do jogador %.1f" % [antes, depois, do_jogador])
	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("PASSAGEM_OK: com o jogador em casa o Pedro espera fora e fora do vão, e sai se estava dentro; quem barra a porta dá passagem e o jogador sai andando; e depois do tutorial o Pedro vai para o posto dele e para de seguir")
	else:
		print("passagem: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _passos(n: int) -> void:
	for i in n:
		await physics_frame


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
