extends SceneTree
## Confere o GIRO DO VIAJANTE (#209): ele nunca anda de lado deslizando. O corpo
## gira para o rumo com velocidade angular limitada (sem salto de um quadro) e o
## passo só pega velocidade conforme o corpo se alinha com o rumo.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/giro_do_viajante.gd
##
##   1. A MATEMÁTICA DO GIRO (`passo_de_giro`): nunca passa do teto angular por
##      quadro, não ultrapassa o rumo, pega o caminho curto pela volta e chega
##      ao rumo em menos de um segundo, mesmo na meia-volta.
##   2. O ALINHAMENTO (`alinhamento_do_passo`): 1 com o corpo no rumo, 0 de costas,
##      quase 0 de lado, e só diminui conforme o desvio cresce.
##   3. O VIAJANTE NO VALE: andando para a frente e trocando a tecla para o lado,
##      nenhum quadro gira além do teto, e andando de novo o corpo termina virado
##      para a direção em que a velocidade aponta.

var falhas := 0
var vale
var jogador


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("GIRO_DO_VIAJANTE_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(6)
	await _mundo_pronto()
	await _frames(10)
	vale = current_scene
	jogador = vale.get("player")
	if jogador == null:
		_conferir(false, "o vale não tem jogador")
		_fechar()
		return
	var roteiro = jogador.get_script()
	var dt := 1.0 / 60.0
	var teto: float = float(jogador.VELOCIDADE_DE_GIRO) * dt

	# --- 1. A MATEMÁTICA DO GIRO ---------------------------------------------
	var passo: float = roteiro.passo_de_giro(0.0, PI, dt)
	_conferir(absf(passo) > 0.0 and absf(passo) <= teto + 0.000001, "a meia-volta passou do teto no primeiro quadro (%.3f rad)" % passo)
	_conferir(absf(float(roteiro.passo_de_giro(0.0, 0.01, dt))) <= 0.01, "o giro ultrapassou um rumo quase alinhado")
	_conferir(float(roteiro.passo_de_giro(3.0, -3.0, dt)) > 0.0, "o giro não tomou o caminho curto pela volta")
	_conferir(float(roteiro.passo_de_giro(-3.0, 3.0, dt)) < 0.0, "o giro não tomou o caminho curto pela volta (outro lado)")
	var atual := 0.0
	var maior := 0.0
	var quadros_ate_chegar := -1
	for i in 120:
		var d: float = roteiro.passo_de_giro(atual, PI, dt)
		maior = maxf(maior, absf(d))
		atual += d
		if quadros_ate_chegar < 0 and absf(angle_difference(atual, PI)) < deg_to_rad(2.0):
			quadros_ate_chegar = i + 1
	_conferir(maior <= teto + 0.000001, "algum quadro da meia-volta passou do teto (%.3f rad)" % maior)
	_conferir(quadros_ate_chegar > 0 and quadros_ate_chegar <= 60, "a meia-volta não fechou em um segundo (%d quadros)" % quadros_ate_chegar)
	_conferir(quadros_ate_chegar > 6, "a meia-volta fechou em %d quadros: é um salto, não um giro" % quadros_ate_chegar)

	# --- 2. O ALINHAMENTO -----------------------------------------------------
	_conferir(is_equal_approx(float(roteiro.alinhamento_do_passo(1.0, 1.0)), 1.0), "alinhado não anda inteiro")
	_conferir(is_equal_approx(float(roteiro.alinhamento_do_passo(0.0, deg_to_rad(20.0))), 1.0), "20° de desvio já tirou velocidade")
	_conferir(float(roteiro.alinhamento_do_passo(0.0, deg_to_rad(90.0))) < 0.2, "de lado (90°) ainda anda quase inteiro")
	_conferir(is_zero_approx(float(roteiro.alinhamento_do_passo(0.0, PI))), "de costas ainda anda")
	var anterior := 2.0
	var cai := true
	for graus in range(0, 181, 5):
		var f: float = roteiro.alinhamento_do_passo(0.0, deg_to_rad(float(graus)))
		if f > anterior + 0.000001:
			cai = false
		anterior = f
	_conferir(cai, "o alinhamento não diminui sempre que o desvio cresce")

	# --- 3. O VIAJANTE NO VALE ------------------------------------------------
	Input.action_press("mv_forward")
	await _frames(60)
	Input.action_release("mv_forward")
	Input.action_press("mv_right")
	var visual: Node3D = jogador.visual
	var antes := visual.rotation.y
	var maior_no_vale := 0.0
	for i in 90:
		await physics_frame
		maior_no_vale = maxf(maior_no_vale, absf(angle_difference(antes, visual.rotation.y)))
		antes = visual.rotation.y
	var teto_no_vale: float = float(jogador.VELOCIDADE_DE_GIRO) / float(Engine.physics_ticks_per_second)
	_conferir(maior_no_vale <= teto_no_vale * 1.05 + 0.000001,
		"um quadro do viajante girou %.1f° (teto %.1f°)" % [rad_to_deg(maior_no_vale), rad_to_deg(teto_no_vale)])
	var v := Vector2(jogador.velocity.x, jogador.velocity.z)
	_conferir(v.length() > 0.5, "o viajante não andou para o lado (velocidade %.2f)" % v.length())
	if v.length() > 0.5:
		var rumo := atan2(v.x, v.y)
		var desvio := absf(angle_difference(visual.rotation.y, rumo))
		_conferir(desvio < deg_to_rad(15.0), "andando, o corpo está %.0f° fora do rumo da velocidade" % rad_to_deg(desvio))
	Input.action_release("mv_right")
	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("GIRO_DO_VIAJANTE_OK: o corpo gira para o rumo sem passar do teto angular por quadro, a meia-volta fecha em menos de um segundo, o passo espera o alinhamento (de lado e de costas não anda) e, no vale, andando para o lado o viajante termina virado para onde vai")
	else:
		print("giro_do_viajante: %d falha(s)" % falhas)
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
