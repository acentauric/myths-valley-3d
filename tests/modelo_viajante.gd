extends SceneTree
## O GLB final precisa trazer o rig e todos os clipes usados pelo jogador.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var cena := load("res://assets/prototipo_3d/personagens/viajante_tripo.glb") as PackedScene
	_conferir(cena != null, "GLB do viajante importa")
	var modelo := cena.instantiate()
	root.add_child(modelo)
	var esqueletos := modelo.find_children("*", "Skeleton3D", true, false)
	_conferir(not esqueletos.is_empty(), "esqueleto Mixamo presente")
	var mao_direita := false
	for i in (esqueletos[0] as Skeleton3D).get_bone_count():
		if String((esqueletos[0] as Skeleton3D).get_bone_name(i)).to_lower().ends_with("righthand"):
			mao_direita = true
	_conferir(mao_direita, "osso da mão direita para o machado")
	var animador = load("res://scripts/prototipo_3d/authored_animator.gd").new()
	root.add_child(animador)
	_conferir(animador.configure(modelo), "AnimationPlayer do viajante")
	var clipes: Dictionary = animador.get("_clips")
	for nome in ["idle", "walk", "run", "swim", "run_upstairs", "chop", "jump_down", "greet_01", "wave_goodbye_02", "agree", "look_around", "afraid", "fold_arms"]:
		_conferir(clipes.has(nome), "clipe ausente: " + nome)
	var idle: Animation = animador.animation_player.get_animation(clipes["idle"])
	var idle_mantem_movimento_das_pernas := false
	var idle_mantem_balanco_do_tronco := false
	for faixa in idle.get_track_count():
		var osso := String(idle.track_get_path(faixa)).to_lower().get_slice(":", String(idle.track_get_path(faixa)).get_slice_count(":") - 1)
		if osso.contains("upleg") or osso.ends_with("leg") or osso.ends_with("foot"):
			idle_mantem_movimento_das_pernas = true
		if osso.ends_with("spine") or osso.ends_with("spine1") or osso.ends_with("spine2"):
			idle_mantem_balanco_do_tronco = true
	_conferir(idle_mantem_movimento_das_pernas, "o clipe idle deve manter a animação original das pernas")
	_conferir(idle_mantem_balanco_do_tronco, "o clipe idle deve manter o movimento lateral do tronco")
	var escada: Animation = animador.animation_player.get_animation(clipes["run_upstairs"])
	var quadris_nivelados := false
	for faixa in escada.get_track_count():
		if escada.track_get_type(faixa) != Animation.TYPE_POSITION_3D or not String(escada.track_get_path(faixa)).to_lower().contains("hips"):
			continue
		quadris_nivelados = true
		var pose_inicial: Vector3 = escada.track_get_key_value(faixa, 0)
		var altura := pose_inicial.y
		for chave in escada.track_get_key_count(faixa):
			var pose: Vector3 = escada.track_get_key_value(faixa, chave)
			_conferir(is_equal_approx(pose.y, altura),
				"o clipe de escada elevou os quadris no nado parado")
	_conferir(quadris_nivelados, "a trilha vertical dos quadris do clipe de escada não foi encontrada")
	animador.set_swimming(true)
	animador.update_motion(0.0, 0.0)
	_conferir(String(animador.get_current_animation()).begins_with("run_upstairs"), "nado parado usa escada")
	animador.update_motion(1.0, 0.0)
	_conferir(String(animador.get_current_animation()).begins_with("swim"), "nado em movimento usa swim")
	_conferir(animador.play_chop() == "Golpear", "golpe continua disponível")
	print("MODELO_VIAJANTE_OK")
	quit()


func _conferir(ok: bool, mensagem: String) -> void:
	if not ok:
		push_error("MODELO_VIAJANTE_FALHOU: " + mensagem)
		quit(1)
		assert(false, mensagem)
