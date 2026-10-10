extends "res://tests/suite/caso.gd"
## O mesmo painel muda de escala conforme a tela que ocupa, sem acumular sinais.
var falhas := 0
func _initialize() -> void:
	_run.call_deferred()
func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: ", texto)
func _run() -> void:
	await process_frame
	var tela: Node = root.get_node("Tela")
	tela.restaurar_componentes()
	var abertura: Node = load("res://scenes/prototipo_3d/abertura.tscn").instantiate()
	root.add_child(abertura)
	await process_frame
	await process_frame
	var painel: Control = abertura.panel
	var ligacoes: int = tela.componentes_mudaram.get_connections().size()
	tela.definir_componente("menu", 0)
	tela.definir_componente("historico", 5)
	tela.definir_componente("sobre", 1)
	tela.definir_componente("vagas", 0)
	tela.definir_componente("ajustes", 5)
	for tamanho in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = tamanho
		for modo in ["menu", "historico", "sobre", "vagas", "ajustes", "menu"]:
			match modo:
				"menu": abertura._home()
				"historico": abertura._render_history()
				"sobre": abertura._credits()
				"vagas": abertura._vagas()
				"ajustes": abertura._options()
			await process_frame
			await process_frame
			conferir(str(painel.get_meta("componente_interface")) == modo, "painel usa a preferência da tela atual")
			if "--sem-revincular" in OS.get_cmdline_user_args() and modo == "historico": painel.scale = Vector2.ONE * 0.65
			conferir(root.get_visible_rect().encloses(painel.get_global_rect()), "painel cabe na janela")
			if modo in ["menu", "vagas"]: conferir(is_equal_approx(painel.scale.x, 0.65), "menu e vagas usam escala pequena")
			if modo == "sobre": conferir(is_equal_approx(painel.scale.x, 0.8), "créditos têm escala independente")
			if modo == "historico": conferir(painel.scale.x > 0.9, "histórico não herda a escala do menu")
			if "--capturar" in OS.get_cmdline_user_args() and tamanho.x == 1280:
				await RenderingServer.frame_post_draw
				DirAccess.make_dir_recursive_absolute("res://scratch/interfaces-lobby")
				root.get_texture().get_image().save_png("res://scratch/interfaces-lobby/%s.png" % modo)
	conferir(tela.componentes_mudaram.get_connections().size() == ligacoes, "reabrir telas não acumula conexões de escala")
	tela.restaurar_componentes()
	print("INTERFACES_DO_LOBBY: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
