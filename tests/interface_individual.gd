extends SceneTree
## Independência, persistência, ancoragem e retângulos reais de componentes.
var falhas := 0

func _initialize() -> void:
	_run.call_deferred()

func conferir(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: ", mensagem)

func _run() -> void:
	await process_frame
	var tela := root.get_node("Tela")
	var caminho: String = ProjectSettings.globalize_path(tela.ARQUIVO)
	var existia := FileAccess.file_exists(caminho)
	var antes := FileAccess.get_file_as_bytes(caminho) if existia else PackedByteArray()
	var tamanhos: Dictionary = tela.tamanhos_componentes.duplicate()
	var base := Control.new()
	root.add_child(base)
	base.size = Vector2(1280, 720)
	var mapa := Panel.new()
	base.add_child(mapa)
	mapa.size = Vector2(176, 176)
	mapa.position = Vector2(14, 530)
	tela.vincular_componente(mapa, "minimapa", Vector2(0, 1))
	var barra := Button.new()
	base.add_child(barra)
	barra.size = Vector2(120, 40)
	barra.position = Vector2(500, 18)
	tela.vincular_componente(barra, "vida")
	tela.restaurar_componentes()
	await process_frame
	var rodape := mapa.get_global_rect().end.y
	tela.definir_componente("minimapa", 5)
	await process_frame
	if "--sem-escala" in OS.get_cmdline_user_args():
		mapa.scale = Vector2.ONE
	conferir(is_equal_approx(mapa.get_global_rect().size.x, 264.0), "o minimapa cresce inteiro")
	conferir(is_equal_approx(mapa.get_global_rect().end.y, rodape), "a borda inferior permanece ancorada")
	conferir(barra.scale == Vector2.ONE, "mudar mapa não altera a vida")
	tela.definir_componente("vida", 0)
	conferir(is_equal_approx(barra.get_global_rect().size.x, 78.0), "área clicável acompanha a vida")
	var preferencias := ConfigFile.new()
	preferencias.load(tela.ARQUIVO)
	conferir(preferencias.get_value("componentes", "minimapa") == 5, "a escolha persiste")
	tela.definir_componente("minimapa", tela.PADRAO_COMPONENTE)
	conferir(mapa.scale == Vector2.ONE and barra.scale.x < 1.0, "restaurar um preserva o outro")
	tela.restaurar_componentes()
	conferir(barra.scale == Vector2.ONE, "restaurar todos")
	# Padrão por componente (#176): a missão nasce em 80%, o resto em 100%.
	conferir(is_equal_approx(tela.escala_componente("missao"), 0.8), "a missão nasce em 80%")
	conferir(tela.padrao_componente("missao") == 1, "o ↺ de Missão volta para 80%")
	for chave: String in tela.COMPONENTES:
		if chave != "missao":
			conferir(tela.tamanho_componente(chave) == tela.PADRAO_COMPONENTE, "%s segue em 100%%" % chave)
	var hud = load("res://scripts/prototipo_3d/prototype_hud.gd").new()
	root.add_child(hud)
	await process_frame
	tela.definir_componente("missao", 5)
	tela.definir_componente("relogio", 0)
	tela.definir_componente("vida", 5)
	await process_frame
	conferir(not hud._heading.get_global_rect().intersects(hud._clock_panel.get_global_rect()), "missão e relógio não se cobrem")
	conferir(not hud._clock_panel.get_global_rect().intersects(hud.barra_vida.get_global_rect()), "relógio e vida não se cobrem")
	conferir(not hud.barra_vida.get_global_rect().intersects(hud.barra_folego.get_global_rect()), "vida maior não cobre fôlego")
	conferir(hud._heading.get_global_rect().size.x > 500, "a missão usa o retângulo transformado")
	var popups = load("res://scripts/prototipo_3d/popups_do_mundo.gd")
	conferir(popups.paineis_do_hud(root.get_visible_rect().size, hud).has(hud._heading.get_global_rect()), "a matriz reserva a missão ampliada")
	tela.definir_componente("mao", 5)
	tela.definir_componente("avisos", 5)
	hud.set_notice("Recebido: uma orientação comprida que precisa continuar legível sem ultrapassar as bordas da janela e sem ocupar o lugar da barra de mão.", 20)
	await process_frame
	await process_frame
	conferir(not hud._notice_panel.get_global_rect().intersects(hud.barra_de_mao().get_node("Fila").get_global_rect()), "aviso ampliado não cobre a barra maior")
	conferir(root.get_visible_rect().encloses(hud._notice_panel.get_global_rect()), "aviso ampliado cabe na janela")
	for idioma in 3:
		load("res://scripts/prototipo_3d/idioma_menu.gd").definir(idioma)
		for resolucao: Vector2i in [Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(1920, 1080)]:
			root.size = resolucao
			await process_frame
			await process_frame
			conferir(not hud._heading.get_global_rect().intersects(hud._clock_panel.get_global_rect()), "sem sobreposição após redimensionar em idioma " + str(idioma))
			conferir(root.get_visible_rect().encloses(hud._notice_panel.get_global_rect()), "aviso cabe após redimensionar")
	load("res://scripts/prototipo_3d/idioma_menu.gd").definir(0)
	hud.queue_free()
	base.queue_free()
	await process_frame
	tela.tamanhos_componentes = tamanhos
	if existia:
		var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
		arquivo.store_buffer(antes)
	else:
		DirAccess.remove_absolute(caminho)
	print("INTERFACE_INDIVIDUAL: falhas=", falhas)
	quit(0 if falhas == 0 else 1)
