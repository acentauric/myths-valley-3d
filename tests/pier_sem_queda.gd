extends "res://tests/suite/caso.gd"
## O PEDRO NÃO CAI NA ÁGUA DO PÍER QUANDO ABRE PASSAGEM PARA O JOGADOR (#236).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste pier_sem_queda
##     .\tools\prototipo_3d\testar.ps1 -Teste pier_sem_queda -Extra --falsificar
##
## Ao entrar no píer o jogador vem pelo tabuado estreito, o Pedro "abre passagem" (`dar_passagem`) e escolhe
## um lado que é mar: `test_move` só diz que nada barra o passo, e a água não barra. Agora cada saída
## precisa de chão firme (`chao_firme_em`), e sem saída ele fica onde está e o jogador o atravessa raspando.
##
##   1. DAR PASSAGEM NO TABUADO. Dez vezes, em pontos do tabuado do píer, com o empurrão ao longo dele
##      (o jogador vindo de frente) e de través (o pior caso), o Pedro dá passagem e três segundos depois
##      está no píer, a pé, na altura do tabuado.
##   2. A CHÃO FIRME, SÓ. Os pontos de "dar passagem" que ele escolhe (`_passagem_ate`) têm chão firme.
##   3. SE CAIR, VOLTA. Posto na água ao lado do píer logo depois de pisar o tabuado, com o jogador de costas
##      para ele, o Pedro volta ao chão firme e não fica nadando.
##
## `--falsificar` volta à escolha de antes (só `test_move`) e a parte 2 reprova.

const REPETICOES := 10
const PASSOS_DE_ESPERA := 240
const ABAIXO_DO_TABUADO := 0.6

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()
	create_timer(300).timeout.connect(func() -> void:
		print("FALHA: a prova do píer excede o tempo")
		quit(2))


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("PIER_SEM_QUEDA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	if "--falsificar" in OS.get_cmdline_user_args():
		var npc: GDScript = load("res://scripts/prototipo_3d/npc.gd")
		npc.source_code = npc.source_code.replace("if not test_move(de, passo) and chao_firme_em(global_position + passo):", "if not test_move(de, passo):")
		_conferir(npc.reload() == OK, "o mutante da passagem compila")
	root.get_node("Estilo").modo = "tripo"
	change_scene_to_file("res://scenes/prototipo_3d/vale.tscn")
	await process_frame
	while current_scene == null or current_scene.get("carga_ok") != true:
		await process_frame
	var vale: Node = current_scene
	root.get_node("Dia").pausado = true
	vale.apresentacao_do_povoado.set_process(false)
	var mundo = vale.world
	var pedro = vale.pedro
	var jogador = vale.player
	var piso: Vector3 = mundo.ancoras.get("PierPiso", Vector3.INF)
	var eixo: Vector3 = mundo.ancoras.get("PierDirecao", Vector3.INF)
	var lado: Vector3 = mundo.ancoras.get("PierLado", Vector3.INF)
	_conferir(pedro != null and jogador != null and piso.is_finite() and eixo.is_finite() and lado.is_finite(), "o vale tem o Pedro, o jogador e o píer")
	if falhas > 0:
		quit(1)
		return
	for pessoa in get_nodes_in_group("moradores"):
		if pessoa != pedro:
			pessoa.set_physics_process(false)
			pessoa.set_process(false)
			pessoa.collision_layer = 0
	jogador.set_physics_process(false)
	eixo.y = 0.0
	lado.y = 0.0
	eixo = eixo.normalized()
	lado = lado.normalized()
	var espaco: PhysicsDirectSpaceState3D = mundo.get_world_3d().direct_space_state

	# --- 1 e 2. DAR PASSAGEM NO TABUADO -------------------------------------------------------
	var provados := 0
	var escolhas_sem_chao := 0
	for k in REPETICOES:
		var ponto: Vector3 = piso + eixo * (-4.5 + float(k))
		var pergunta := PhysicsRayQueryParameters3D.create(ponto + Vector3.UP * 1.5, ponto + Vector3.DOWN * 1.5, 1)
		var chao := espaco.intersect_ray(pergunta)
		if chao.is_empty():
			print("  ponto %d do tabuado sem chão (%s): fora da prova" % [k, str(ponto)])
			continue
		provados += 1
		var em_pe: Vector3 = chao.position
		pedro.global_position = em_pe + Vector3(0.0, 0.1, 0.0)
		pedro.velocity = Vector3.ZERO
		pedro.set("_passagem_resta", 0.0)
		pedro.set("_nadando", false)
		jogador.teleportar(em_pe - eixo * 1.5 + Vector3(0.0, 0.1, 0.0), 0.0)
		await _passos(30)
		var empurrao := eixo if k % 2 == 0 else lado * (1.0 if k % 4 == 1 else -1.0)
		pedro.dar_passagem(empurrao)
		var destino: Vector3 = pedro.get("_passagem_ate")
		if pedro.dando_passagem() and destino.is_finite() and destino.distance_to(pedro.global_position) > 0.2:
			if not pedro.chao_firme_em(destino):
				escolhas_sem_chao += 1
				print("  ponto %d: a saída escolhida %s não tem chão firme" % [k, str(destino)])
		await _passos(PASSOS_DE_ESPERA)
		var no_agua: bool = bool(pedro.get("_nadando"))
		_conferir(not no_agua, "ponto %d (empurrão %s): o Pedro caiu na água ao dar passagem" % [k, "ao longo" if k % 2 == 0 else "de través"])
		_conferir(pedro.global_position.y > em_pe.y - ABAIXO_DO_TABUADO, "ponto %d: o Pedro está %.2f abaixo do tabuado" % [k, em_pe.y - pedro.global_position.y])
	_conferir(provados >= REPETICOES / 2, "só %d dos %d pontos do tabuado têm chão: a prova não vale" % [provados, REPETICOES])
	_conferir(escolhas_sem_chao == 0, "%d saída(s) de dar passagem sem chão firme" % escolhas_sem_chao)

	# --- 3. SE CAIR, VOLTA --------------------------------------------------------------------
	var fundo: Vector3 = piso + lado * 3.5
	var lamina: float = mundo.water_level_at(fundo)
	var profundidade: float = mundo.water_depth_at(fundo)
	if not is_finite(lamina) or profundidade < pedro.altura * 0.9:
		print("  a 3,5 u do tabuado a água tem %.2f: a parte da volta não vale aqui" % profundidade)
	else:
		pedro.global_position = piso + Vector3(0.0, 0.1, 0.0)
		pedro.velocity = Vector3.ZERO
		await _passos(90)
		jogador.teleportar(piso - eixo * 3.0 + Vector3(0.0, 0.1, 0.0), atan2(-eixo.x, -eixo.z))
		pedro.global_position = Vector3(fundo.x, lamina - pedro.altura * 0.68, fundo.z)
		pedro.velocity = Vector3.ZERO
		var voltou := false
		for i in 600:
			await physics_frame
			if not bool(pedro.get("_nadando")) and pedro.global_position.y > lamina - 0.3:
				voltou = true
				break
		_conferir(voltou, "caído a 3,5 u do píer, o Pedro continuou nadando 10 s")
	print("PIER_SEM_QUEDA: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _passos(n: int) -> void:
	for i in n:
		await physics_frame
