extends "res://tests/suite/caso.gd"
## O E no baú real abre a pergunta; Não preserva o saldo e Sim paga (#68).
var falhas := 0
func _initialize() -> void:
	_run.call_deferred()
	create_timer(180).timeout.connect(func(): quit(2))
func conferir(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: ", mensagem)
func acao(nome: String) -> void:
	# A captura retorna em frame_post_draw; espere a entrada do quadro seguinte.
	await process_frame
	Input.action_press(nome)
	await create_timer(0.12).timeout
	Input.action_release(nome)
	await process_frame
func _run() -> void:
	await process_frame
	change_scene_to_file("res://scenes/prototipo_3d/vale.tscn")
	await process_frame
	while current_scene == null or current_scene.get("carga_ok") != true:
		await process_frame
	var vale := current_scene
	root.get_node("Dia").pausado = true
	vale.apresentacao_do_povoado.set_process(false)
	for pessoa in get_nodes_in_group("moradores"):
		pessoa._calar_a_boca()
		pessoa.set_physics_process(false)
		for filho in pessoa.get_children():
			if filho.get_script() == load("res://scripts/prototipo_3d/cadeia_de_missoes.gd"):
				filho.set_process(false)
				filho.set_physics_process(false)
	vale.pedro._cadeia.set_process(false)
	vale.pedro._cadeia.set_physics_process(false)
	var dialogo = root.get_node("Dialogo")
	dialogo.calar()
	await vale.interiores.garantir("venda")
	var sala: Node3D = vale.interiores.sala_de("venda")
	conferir(sala != null, "venda montada")
	var bau: Node3D = sala.peca_do_perfil("bau")
	conferir(bau != null, "baú real do perfil montado")
	if bau == null:
		quit(1)
		return
	var ponto: Vector3 = sala.to_global(sala.caixa_no_comodo(bau).get_center())
	vale.player.global_position = ponto + sala.global_basis * Vector3(-1.1, 0, 0)
	vale.player.global_position.y = sala.global_position.y + 0.07
	vale.player.camera.make_current()
	for _i in 8:
		await process_frame
	conferir(vale.interiores.dentro() == "venda", "jogador dentro da venda")
	var livro: Node = vale.fiado_tonho
	conferir(not livro.alvo_do_e().is_empty(), "livro ao alcance do E")
	var fio = load("res://scripts/prototipo_3d/foco_do_e.gd")
	vale.player.rotation.y = atan2(-(ponto.x - vale.player.global_position.x), -(ponto.z - vale.player.global_position.z))
	await process_frame
	conferir(fio.e_dele(livro), "E pertence ao baú do livro")
	root.get_node("Jogo").dinheiro = 800
	var tecla := InputEventKey.new()
	tecla.physical_keycode = load("res://scripts/prototipo_3d/atalhos.gd").tecla("interagir")
	tecla.pressed = true
	livro._unhandled_key_input(tecla)
	for _i in 10:
		await process_frame
	conferir(dialogo.ativo, "tecla abre pergunta real")
	conferir(livro.divida == 1900, "abrir não cobra")
	await acao("mover_direita")
	await acao("interagir")
	conferir(not dialogo.ativo and livro.divida == 1900 and root.get_node("Jogo").dinheiro == 800, "Não não cobra")
	await process_frame
	await process_frame
	livro.ler()
	for _i in 10:
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://scratch/fiado-tonho")
		root.get_texture().get_image().save_png("res://scratch/fiado-tonho/pergunta.png")
	await acao("mover_esquerda")
	await acao("interagir")
	conferir(not dialogo.ativo and livro.divida == 1400 and root.get_node("Jogo").dinheiro == 300, "Sim lança 500 reais")
	var salvo: Dictionary = vale.estado_para_salvar()
	conferir(salvo.fiado_tonho.divida == 1400 and salvo.fiado_tonho.lido, "save do vale contém saldo e leitura")
	print("LIVRO_ARMAZEM: %d falhas" % falhas)
	quit(0 if falhas == 0 else 1)
