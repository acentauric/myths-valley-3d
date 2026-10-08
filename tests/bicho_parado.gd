extends SceneTree
## O BICHO DE QUATRO PATAS PARA NA POSE DE APOIO (#91).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/bicho_parado.gd
##
## "Agora não sei por que os bichos quadrúpedes ficaram assim" — parados, eles
## congelavam no quadro em que o passo os pegou, com a pata no ar
## (`animador_bicho`: "congelado no quadro em que parou"). Agora o clipe segue
## até a pose de apoio — um quadro de pé medido nas patas do clipe, ou, sem
## medida, o começo ou o meio da passada — e só então para.
##
##   1. ANDANDO, o clipe de andar toca.
##   2. PARADO, o clipe para numa pose de apoio, e não no meio do passo.
##   3. VOLTANDO A ANDAR, o clipe retoma.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("BICHO_PARADO_FALHOU: " + rotulo)
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
	root.get_node("/root/Dia").pausado = true
	# A apresentação do povoado esconde e desliga os bichos longe do jogador (o animador
	# vai junto, em PROCESS_MODE_DISABLED) até a visita chegar perto: sem liberar o elenco o
	# bicho sorteado podia estar oculto, com o clipe pausado, e o parado nunca se media.
	for i in 600:
		if vale.apresentacao_do_povoado != null:
			break
		await process_frame
	vale.apresentacao_do_povoado.liberar_todos()
	await _quadros(2)
	var bicho = null
	var animador = null
	for candidato in get_nodes_in_group("bichos_de_casa"):
		var a = candidato.get("_animador")
		if a == null or not bool(a.tem_clipe()) or str(candidato.get("chave")) in a.CLIPE_TORTO:
			continue
		bicho = candidato
		animador = a
		break
	_conferir(bicho != null, "nenhum bicho de casa anda com o clipe do GLB")
	if bicho == null:
		_fechar()
		return
	# Perto do bicho, para o clipe não ficar pausado por estar fora da vista.
	jogador.teleportar(mundo.ground_position(bicho.global_position + Vector3(3.0, 0.0, 3.0), 0.1), atan2(-1.0, -1.0))
	bicho.set_physics_process(false)
	var ap: AnimationPlayer = animador.get("animacao")
	var clipe: String = animador.get("_clipe")
	var comprimento: float = ap.get_animation(clipe).length
	var meia_passada := comprimento * 0.5
	await _quadros(5)

	# --- 1. ANDANDO -------------------------------------------------------------
	animador.velocidade = 1.0
	await _quadros(5)
	_conferir(ap.is_playing(), "andando, o clipe do %s não toca" % str(bicho.get("chave")))

	# --- 2. PARADO NA POSE DE APOIO -----------------------------------------------
	animador.velocidade = 0.0
	var parou := await _ate(func() -> bool: return not ap.is_playing(), 4.0)
	_conferir(parou, "parado, o clipe do %s não parou em 4 s" % str(bicho.get("chave")))
	# A POSE DE APOIO é um quadro de pé MEDIDO no clipe (`animador_bicho._quadros_de_pe`,
	# da análise das patas); sem medida, o começo ou o meio da passada.
	var posicao: float = ap.current_animation_position
	var de_pe: PackedFloat32Array = animador.get("_quadros_de_pe")
	if de_pe.is_empty():
		de_pe = PackedFloat32Array([0.0, meia_passada])
	var ate_o_apoio := INF
	for quadro in de_pe:
		var d := fposmod(posicao - quadro, comprimento)
		ate_o_apoio = minf(ate_o_apoio, minf(d, comprimento - d))
	_conferir(ate_o_apoio < 0.07,
		"o %s parou com a pata no ar: posição %.2f de uma passada de %.2f (quadros de pé %s)" % [str(bicho.get("chave")), posicao, comprimento, str(de_pe)])

	# --- 3. VOLTANDO A ANDAR --------------------------------------------------------
	animador.velocidade = 1.0
	await _quadros(5)
	_conferir(ap.is_playing(), "voltando a andar, o clipe do %s não retomou" % str(bicho.get("chave")))
	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("BICHO_PARADO_OK: andando o clipe toca, parado ele para numa pose de apoio, e voltando a andar retoma")
	else:
		print("bicho_parado: %d falha(s)" % falhas)
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
