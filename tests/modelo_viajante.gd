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
