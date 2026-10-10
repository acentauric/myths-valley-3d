extends "res://tests/suite/caso.gd"
var falhas := 0
func _initialize() -> void:
	_run.call_deferred()
	create_timer(180).timeout.connect(func(): quit(2))
func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: " + texto)
func quadros(n: int = 3) -> void:
	for _i in n:
		await process_frame
func tecla(codigo: int) -> void:
	for apertado in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = codigo
		e.pressed = apertado
		root.push_input(e, true)
		await quadros()
func mouse(botao: int, ponto: Vector2, apertado: bool = true) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = botao
	e.position = ponto
	e.global_position = ponto
	e.pressed = apertado
	root.push_input(e, true)
	await quadros()
func _run() -> void:
	await process_frame
	change_scene_to_file("res://scenes/prototipo_3d/vale.tscn")
	await process_frame
	var mundo := get_first_node_in_group("mundo")
	while mundo == null or not mundo.construido:
		await process_frame
		mundo = get_first_node_in_group("mundo")
	await quadros(10)
	var vale := current_scene
	await tecla(KEY_K)
	var teia = vale.teia
	conferir(teia.aberta, "K abre a teia")
	if "--sem-mouse" in OS.get_cmdline_user_args():
		teia.set_process_input(false)
	var maior := ""
	var largura := 0.0
	for raiz in teia._raizes():
		teia._escolher_raiz(str(raiz))
		if teia._tela_da_arvore.custom_minimum_size.x > largura:
			maior = str(raiz)
			largura = teia._tela_da_arvore.custom_minimum_size.x
	teia._escolher_raiz(maior)
	await quadros()
	var rolagem: ScrollContainer = teia._rolagem
	var ponto := rolagem.get_global_transform_with_canvas() * (rolagem.size * 0.5)
	for _i in 7:
		await mouse(MOUSE_BUTTON_WHEEL_UP, ponto)
	conferir(is_equal_approx(teia._zoom, 1.8), "roda amplia até limite")
	conferir(teia._tela_da_arvore.scale.is_equal_approx(Vector2.ONE * 1.8), "árvore e hit areas ampliam juntas")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://scratch/teia")
		root.get_texture().get_image().save_png("res://scratch/teia/zoom-ampliado.png")
	rolagem.scroll_horizontal = 0
	await mouse(MOUSE_BUTTON_MIDDLE, ponto)
	var movimento := InputEventMouseMotion.new()
	movimento.position = ponto - Vector2(80, 0)
	movimento.relative = Vector2(-80, 0)
	root.push_input(movimento, true)
	await quadros()
	conferir(rolagem.scroll_horizontal > 0, "arrastar percorre árvore larga")
	await mouse(MOUSE_BUTTON_MIDDLE, ponto, false)
	conferir(not teia._arrastando, "soltar encerra arrasto")
	for _i in 12:
		await mouse(MOUSE_BUTTON_WHEEL_DOWN, ponto)
	conferir(is_equal_approx(teia._zoom, 0.65), "roda reduz até limite")
	rolagem.scroll_horizontal = 0
	rolagem.scroll_vertical = 0
	await quadros()
	if not teia._caixinhas.is_empty():
		var id: String = teia._ordem[0]
		var botao: Button = teia._caixinhas[id]
		teia._no = ""
		var centro := botao.get_global_transform_with_canvas() * (botao.size * 0.5)
		await mouse(MOUSE_BUTTON_LEFT, centro)
		await mouse(MOUSE_BUTTON_LEFT, centro, false)
		conferir(teia._no == id, "clique continua selecionando o nó depois do zoom")
	await tecla(KEY_TAB)
	conferir(teia._modo == "fe", "Tab troca para fé")
	await tecla(KEY_TAB)
	conferir(teia._modo == "oficio", "Tab volta ao ofício")
	await tecla(KEY_K)
	await tecla(KEY_L)
	conferir(vale.hud.almanaque().aberto(), "L abre coleção no almanaque")
	await tecla(KEY_L)
	await tecla(KEY_P)
	conferir(vale.social.aberta, "P abre moradores e afinidade")
	await tecla(KEY_P)
	conferir(not paused, "fechar telas devolve controle ao vale")
	print("NAVEGACAO_DA_TEIA: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
