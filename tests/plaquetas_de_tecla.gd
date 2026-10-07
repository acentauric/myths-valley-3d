extends SceneTree
## #122: contraste próprio, sem cobrir ícone nem ampliar o clique.
var falhas := 0
func _initialize() -> void:
	_run.call_deferred()
func conferir(ok: bool, motivo: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: " + motivo)
func _run() -> void:
	await process_frame
	var hud = load("res://scripts/prototipo_3d/prototype_hud.gd").new()
	root.add_child(hud)
	hud.set_clock("07:51\nManhã")
	var fabrica = load("res://scripts/prototipo_3d/botao_canto.gd")
	for escala in [0.8, 1.0, 1.25]:
		for canto in get_nodes_in_group("botoes_canto"):
			fabrica._geometria(canto, escala)
		await process_frame
		for canto in get_nodes_in_group("botoes_canto"):
			var botao: Button = canto.get_meta("botao")
			var marca := botao.get_node_or_null("TeclaDeAtalho") as Label
			if marca == null:
				continue
			var icone: Control = canto.get_meta("icone")
			if "--falsificar" in OS.get_cmdline_user_args():
				marca.position = icone.position
			conferir(not marca.get_global_rect().intersects(icone.get_global_rect()), "plaqueta cobre o ícone")
			conferir(marca.mouse_filter == Control.MOUSE_FILTER_IGNORE, "plaqueta captura cliques")
			var fundo := marca.get_theme_stylebox("normal") as StyleBoxFlat
			conferir(fundo != null and fundo.bg_color.a == 1, "tecla depende do fundo do mundo")
			var tinta := marca.get_theme_color("font_color")
			var contraste := (fundo.bg_color.srgb_to_linear().get_luminance() + 0.05) / (tinta.srgb_to_linear().get_luminance() + 0.05)
			conferir(contraste >= 7, "tecla perdeu contraste")
			conferir(botao.size.x <= canto.size.x and botao.size.y <= canto.size.y, "atalho aumentou área de clique")
	for espaco in hud._barra._espacos:
		var marca: Label = espaco.get_node("TeclaDeAtalho")
		conferir(not marca.get_global_rect().intersects(espaco.get_node("Icone").get_global_rect()), "número cobre o item")
		conferir(marca.get_theme_stylebox("normal") is StyleBoxFlat, "número sem plaqueta comum")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tools/temp/plaquetas-tecla.png")
	hud.queue_free()
	await process_frame
	print("PLAQUETAS_TECLA: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
