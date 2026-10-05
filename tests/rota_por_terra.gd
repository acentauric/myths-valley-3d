extends SceneTree
## Confere que O PEDRO NÃO ENTRA NO MAR para encurtar caminho.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/rota_por_terra.gd
##
## A queixa foi: "eu subo no píer e o Pedro fica tentando vir pelo mar". Ele
## andava em linha reta, o corpo sabia nadar, e a reta até o píer passa por
## cima d'água.
##
## O portão põe o jogador na ponta do píer e o Pedro em terra, do lado oposto,
## e mede DUAS coisas ao longo do caminho: que ele se aproxima, e que não passa
## a nadar. Uma sem a outra não diz nada — ficar parado na areia também não
## molha ninguém.
##
## Três perguntas:
##
##   1. O PÍER EXISTE e tem água em volta. Sem isso o teste mede um caminho
##      seco e passa por acidente.
##   2. O PEDRO SE APROXIMA. Preferir terra não pode virar preferir não ir.
##   3. ELE NÃO NADA NO CAMINHO. É a queixa, medida.

var falhas := 0
const QUADROS := 420


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("ROTA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK,
		"a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()

	var mundo := get_first_node_in_group("mundo")
	var jogador := get_first_node_in_group("map_player")
	var lugares := root.get_node("/root/Lugares")
	var pedro: Node3D = null
	for no in current_scene.find_children("*", "CharacterBody3D", true, false):
		if no.get_script() != null and str(no.get_script().resource_path).ends_with("guia_pedro.gd"):
			pedro = no
			break
	_conferir(mundo != null and jogador != null and pedro != null,
		"não achei o mundo, o jogador ou o Pedro")
	if mundo == null or jogador == null or pedro == null:
		_fechar()
		return

	# --- 1. O PÍER TEM ÁGUA EM VOLTA -----------------------------------------
	var pier: Vector3 = lugares.ponto("pier")
	_conferir(pier != lugares.NENHUM, "o vale não tem píer")
	if pier == lugares.NENHUM:
		_fechar()
		return

	var molhados := 0
	for i in 8:
		var angulo := TAU * float(i) / 8.0
		var ponto := pier + Vector3(cos(angulo), 0.0, sin(angulo)) * 6.0
		if float(mundo.water_depth_at(ponto)) > 0.4:
			molhados += 1
	_conferir(molhados >= 2,
		"só %d de 8 pontos em volta do píer têm água: o teste mediria caminho seco" % molhados)

	# --- 2 e 3. ELE SE APROXIMA SEM NADAR ------------------------------------
	#
	# O jogador vai para a ponta do píer, e o Pedro para o lado de terra — a
	# reta entre os dois é justamente a que passa pela água.
	jogador.global_position = pier
	await _frames(2)
	var em_terra := pier
	for i in 12:
		var tentativa := pier + Vector3(cos(TAU * float(i) / 12.0), 0.0, sin(TAU * float(i) / 12.0)) * 22.0
		if float(mundo.water_depth_at(tentativa)) < 0.2:
			em_terra = mundo.ground_position(tentativa)
			break
	_conferir(em_terra != pier, "não achei terra firme a 22 u do píer para pôr o Pedro")
	# Um passo em que ele SEGUE o jogador (a roça): no desembarque da partida nova
	# ele fica na ponta da prancha, e na condução vai na frente.
	pedro.ir_ao_passo("roca")
	pedro.global_position = em_terra
	await _frames(3)

	var distancia_inicial := _plano(pedro.global_position, jogador.global_position)
	var nadou := 0
	var fundura_maxima := 0.0
	for i in QUADROS:
		jogador.global_position = pier
		await physics_frame
		var fundura := float(mundo.water_depth_at(pedro.global_position))
		fundura_maxima = maxf(fundura_maxima, fundura)
		if pedro._nadando:
			nadou += 1

	var distancia_final := _plano(pedro.global_position, jogador.global_position)
	print("")
	print("  distância %.1f → %.1f u   quadros nadando: %d   água mais funda: %.2f m"
		% [distancia_inicial, distancia_final, nadou, fundura_maxima])

	_conferir(distancia_final < distancia_inicial - 2.0,
		"o Pedro não se aproximou: %.1f → %.1f. Preferir terra virou preferir não ir"
			% [distancia_inicial, distancia_final])
	_conferir(nadou == 0,
		"o Pedro passou %d quadro(s) nadando para chegar ao píer: é a queixa" % nadou)

	_fechar()


func _plano(a: Vector3, b: Vector3) -> float:
	var d := b - a
	d.y = 0.0
	return d.length()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("ROTA_OK: com o jogador na ponta do píer e o Pedro do outro lado da água, ele se aproxima por terra e não nada")
	else:
		print("rota: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


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
