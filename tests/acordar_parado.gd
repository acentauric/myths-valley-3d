extends SceneTree
## Confere ACORDAR PARADO (#189): quem dorme correndo, andando, nadando ou de
## machado no golpe acorda em pé, quieto e no clipe do parado, em frente à cama,
## desde o primeiro quadro depois do escuro, pelas três portas da noite.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/acordar_parado.gd
##
##   1. O ANIMADOR larga o que fazia: depois de `acordar_parado`, o clipe é o
##      parado (sem mistura), na posição 0, sem gesto, golpe, pulo, trabalho ou nado.
##   2. A NOITE (cama, desmaio e queda), com o corpo correndo, golpeando ou
##      nadando antes de deitar: com o cartão ainda no escuro, o jogador já está
##      no parado, no ponto de acordar, sem velocidade nem corrida ligada.
##   3. O GANCHO: a pose de acordar é escolhida por motivo (`POSE_DE_ACORDAR`),
##      e um papel que o animador não conhece cai no parado.

var falhas := 0
var vale
var jogador
var queda
var dia
var amanhecer


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("ACORDAR_PARADO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	dia = root.get_node("/root/Dia")
	amanhecer = root.get_node("/root/Amanhecer")
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(6)
	await _mundo_pronto()
	await _frames(10)
	vale = current_scene
	jogador = vale.get("player")
	queda = vale.get_node("Queda")
	var animador = jogador.animator
	_conferir(animador != null and animador.has_method("acordar_parado"), "o animador do jogador não sabe acordar parado")
	if animador == null or not animador.has_method("acordar_parado"):
		_fechar()
		return
	var parado := String(animador._clips.get("idle", ""))
	_conferir(parado != "", "o modelo do jogador não tem o clipe idle")

	# --- 1. O ANIMADOR LARGA O QUE FAZIA --------------------------------------
	# Sem esperar quadro: o processo físico do jogador, rodando, chamaria update_motion(0) e
	# traria o parado de volta antes da conferência.
	animador.update_motion(6.0, 0.016)
	_conferir(String(animador.get_current_animation()) != parado, "montagem: correndo, o clipe já era o parado")
	animador.play_chop(2)
	await _frames(2)
	_conferir(animador.gesture_ativa(), "montagem: o golpe não começou")
	animador.set_swimming(true)
	var clip := String(animador.acordar_parado())
	_conferir(clip == parado, "acordar_parado tocou '%s', e o parado é '%s'" % [clip, parado])
	_conferir(String(animador.get_current_animation()) == parado, "o clipe em curso não é o parado")
	_conferir(is_zero_approx(animador.animation_player.current_animation_position), "o parado não começou do zero")
	_conferir(not animador.gesture_ativa() and not animador.chop_ativo() and not animador.trabalhando(),
		"o animador ainda tem gesto, golpe ou trabalho")
	_conferir(not animador._swimming and not animador._jump_active, "o animador ainda nada ou pula")
	await _frames(2)
	animador.update_motion(0.0, 0.016)
	_conferir(String(animador.get_current_animation()) == parado, "o primeiro update_motion parado trocou o clipe")

	# --- 3. O GANCHO ------------------------------------------------------------
	for motivo in ["cama", "desmaio", "queda"]:
		_conferir(queda.POSE_DE_ACORDAR.has(motivo), "a pose de acordar não prevê o motivo '%s'" % motivo)
	_conferir(String(animador.acordar_parado("papel_que_nao_existe")) == parado, "um papel desconhecido não caiu no parado")

	# --- 2. AS TRÊS PORTAS DA NOITE -------------------------------------------
	dia.pausado = true
	for motivo in ["cama", "desmaio", "queda"]:
		await _noite_com_o_corpo_ocupado(motivo)
	_fechar()


func _noite_com_o_corpo_ocupado(motivo: String) -> void:
	# Correndo: o Shift ligado, velocidade e o clipe de corrida. No golpe: a
	# ferramenta em uso. E o nado, para a ordem de limpar não importar.
	jogador._run_toggled = true
	jogador._ran_since_toggle = true
	jogador.velocity = Vector3(4.0, 0.0, 0.0)
	jogador.animator.update_motion(6.0, 0.016)
	if motivo == "desmaio":
		jogador.animator.play_chop(3)
		jogador.travar_acao_de_golpe(2.0, true)
	await _frames(3)
	var acordou := [false]
	queda.acordou.connect(func(): acordou[0] = true, CONNECT_ONE_SHOT)
	match motivo:
		"cama":
			queda.dormir_na_cama()
		"desmaio":
			queda._ao_passar_das_duas()
		_:
			queda._ao_cair()
	await _esperar_ate(func() -> bool: return amanhecer.aberto, 10.0)
	_conferir(amanhecer.aberto, "[%s] o cartão do amanhecer não abriu" % motivo)
	# NO ESCURO, antes de clarear: o corpo já está parado.
	var parado := String(jogador.animator._clips.get("idle", ""))
	_conferir(String(jogador.get_current_animation()) == parado,
		"[%s] no escuro o clipe é '%s', e deveria ser o parado" % [motivo, jogador.get_current_animation()])
	_conferir(jogador.velocity.length() < 0.01, "[%s] acordou com velocidade %s" % [motivo, jogador.velocity])
	_conferir(not jogador._run_toggled and not jogador.is_running(), "[%s] a corrida sobreviveu à noite" % motivo)
	_conferir(not jogador.animator.gesture_ativa() and not jogador.is_swimming(), "[%s] o golpe ou o nado sobreviveu à noite" % motivo)
	_conferir(jogador._acao_golpe_restante <= 0.0, "[%s] a trava de golpe sobreviveu à noite" % motivo)
	var destino: Vector3 = queda.ponto_de_casa()
	if destino.is_finite():
		_conferir(jogador.global_position.distance_to(destino) < 0.5,
			"[%s] acordou a %.2f m do ponto de acordar" % [motivo, jogador.global_position.distance_to(destino)])
	await _esperar_ate(func() -> bool: return acordou[0], 15.0)
	_conferir(acordou[0], "[%s] a noite não terminou" % motivo)
	await _frames(6)
	_conferir(String(jogador.get_current_animation()) == parado,
		"[%s] depois de clarear o clipe é '%s'" % [motivo, jogador.get_current_animation()])
	if motivo == "queda":
		# A explicação da queda abre no painel do HUD; fecha para não atrapalhar a próxima.
		if vale.hud._house_info_panel.visible:
			vale.hud._house_info_panel.visible = false
	elif motivo == "desmaio":
		root.get_node("/root/Dialogo").calar()
	await _frames(4)


func _esperar_ate(pronto: Callable, segundos: float) -> void:
	var ate := Time.get_ticks_msec() + int(segundos * 1000.0)
	while not bool(pronto.call()) and Time.get_ticks_msec() < ate:
		await process_frame


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("ACORDAR_PARADO_OK: o animador larga gesto, golpe, nado e trabalho e toca o parado do zero, e a noite (cama, desmaio e queda) acorda o viajante em pé, quieto, sem corrida nem golpe, no clipe do parado já no escuro")
	else:
		print("acordar_parado: %d falha(s)" % falhas)
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
