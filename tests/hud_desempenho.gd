extends SceneTree
## O botão de FPS não deve deixar uma dica gigante presa à coluna direita: abre um
## painel acima do minimapa, com todas as medições, e o recolhe junto com mapa e
## controles. Este portão também protege o encaixe quando a janela muda de tamanho.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, motivo: String) -> void:
	if not ok:
		print("FALHA: ", motivo)
		falhas += 1


func _run() -> void:
	var hud = load("res://scripts/prototipo_3d/prototype_hud.gd").new()
	root.add_child(hud)
	await process_frame
	var painel: Panel = hud._performance_panel
	var botao: Button = hud._performance_button
	_conferir(painel != null and botao != null, "faltam o painel ou o botão de FPS")
	if painel == null or botao == null:
		quit(1)
		return
	_conferir(not painel.visible, "o painel começa aberto")
	hud.set_model_status("Estilo Tripo: modelos do Tripo Studio (personagem GLB provisório)")
	hud.set_telemetry("Tripo · 1,78 m")
	botao.pressed.emit()
	await process_frame
	var texto: String = hud._performance_label.text
	_conferir(painel.visible, "o clique não abre o painel")
	for trecho in ["FPS", "Tripo · 1,78 m", "Estilo Tripo:", "tri", "draws", "MB VRAM"]:
		_conferir(texto.contains(trecho), "o painel perdeu %s" % trecho)
	_conferir(is_equal_approx(painel.position.x, 14.0), "o painel não alinha com o minimapa")
	_conferir(is_equal_approx(painel.position.y + painel.size.y, hud._root.size.y - hud.Minimapa.MARGEM - hud.Minimapa.ALTURA - 8.0),
		"o painel não está acima do minimapa")
	_conferir(hud._performance_label.get_line_count() * hud._performance_label.get_line_height() <= painel.size.y - 14.0,
		"o texto não cabe no painel compacto")
	root.size = Vector2i(1024, 576)
	await process_frame
	_conferir(is_equal_approx(painel.position.y + painel.size.y, hud._root.size.y - hud.Minimapa.MARGEM - hud.Minimapa.ALTURA - 8.0),
		"o painel não acompanha uma janela menor")
	hud.set_controls_open(true)
	_conferir(not painel.visible, "o painel cobre os controles")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://scratch/controles")
		root.get_texture().get_image().save_png("res://scratch/controles/modal.png")
	hud.set_controls_open(false)
	_conferir(painel.visible, "o painel não retorna depois dos controles")
	hud.set_map_open(true)
	_conferir(not painel.visible, "o painel cobre o mapa")
	hud.set_map_open(false)
	_conferir(painel.visible, "o painel não retorna depois do mapa")
	botao.pressed.emit()
	_conferir(not painel.visible, "o segundo clique não fecha o painel")
	print("HUD_DESEMPENHO_OK" if falhas == 0 else "hud_desempenho: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)
