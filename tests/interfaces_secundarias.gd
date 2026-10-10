extends "res://tests/suite/caso.gd"
## Escalas secundárias, retângulos e clique real com fonte global ampliada.
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
	var arquivo: String = ProjectSettings.globalize_path(tela.ARQUIVO)
	var existia := FileAccess.file_exists(arquivo)
	var original := FileAccess.get_file_as_bytes(arquivo) if existia else PackedByteArray()
	tela.restaurar_componentes()
	var controles: Node = load("res://scripts/prototipo_3d/tela_controles.gd").new()
	root.add_child(controles)
	controles.abrir()
	var painel_controles: Control = controles.get_node("Caixa")
	var apoios: Node = load("res://scripts/prototipo_3d/apoios_vale.gd").new()
	root.add_child(apoios)
	apoios.abrir()
	var painel_apoios: Control = apoios._raiz.find_children("*", "PanelContainer", true, false)[0]
	var base := Control.new()
	root.add_child(base)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var canto: GDScript = load("res://scripts/prototipo_3d/botao_canto.gd")
	var clique := [false]
	var botoes: Array[Button] = []
	for i in 10:
		var icone := Control.new()
		var partes: Array = canto.criar(base, i, icone)
		botoes.append(partes[0])
	botoes[9].pressed.connect(func() -> void: clique[0] = true)
	tela.definir_componente("controles", 0)
	tela.definir_componente("apoios", 5)
	tela.definir_componente("atalhos", 5)
	tela.definir_tamanho_hud(3)
	tela.definir_tamanho_texto(3)
	await process_frame
	await process_frame
	if "--sem-escala" in OS.get_cmdline_user_args(): painel_controles.scale = Vector2.ONE
	conferir(is_equal_approx(painel_controles.scale.x, 0.65), "controles encolhem independentemente")
	var sombra: Control = controles.get_node("SombraMoldura")
	conferir(sombra.get_global_rect().is_equal_approx(painel_controles.get_global_rect()), "moldura acompanha o retângulo transformado do painel")
	conferir(painel_apoios.scale.x > 1.0, "apoios aumentam sem acompanhar controles")
	for idioma in 3:
		load("res://scripts/prototipo_3d/idioma_menu.gd").definir(idioma)
		controles.fechar()
		controles.abrir()
		apoios.fechar_tela()
		apoios.abrir()
		for tamanho in [Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(1920, 1080)]:
			root.size = tamanho
			await process_frame
			await process_frame
			canto.reaplicar(arvore)
			var util: Rect2 = root.get_visible_rect()
			conferir(util.encloses(painel_controles.get_global_rect()), "controles cabem na janela")
			conferir(util.encloses(painel_apoios.get_global_rect()), "apoios cabem na janela")
			for botao in botoes:
				conferir(util.encloses(botao.get_parent().get_global_rect()), "dez atalhos cabem mesmo com dois ajustes máximos")
			if "--capturar" in OS.get_cmdline_user_args() and tamanho == Vector2i(1280, 720):
				DirAccess.make_dir_recursive_absolute("res://scratch/interfaces-secundarias")
				base.hide()
				apoios.visible = false
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://scratch/interfaces-secundarias/controles-%d.png" % idioma)
				controles.visible = false
				apoios.visible = true
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://scratch/interfaces-secundarias/apoios-%d.png" % idioma)
				controles.visible = true
				base.show()
	# Só a área de clique participa; painéis de fundo não interceptam a prova.
	controles.visible = false
	apoios.visible = false
	await process_frame
	for pressionado in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.button_index = MOUSE_BUTTON_LEFT
		evento.pressed = pressionado
		evento.position = botoes[9].get_global_rect().get_center()
		evento.global_position = evento.position
		root.push_input(evento, true)
		await process_frame
	conferir(clique[0], "clique alcança o último botão na geometria ampliada")
	tela.restaurar_componentes()
	tela.definir_tamanho_hud(1)
	tela.definir_tamanho_texto(1)
	load("res://scripts/prototipo_3d/idioma_menu.gd").definir(0)
	if existia:
		FileAccess.open(arquivo, FileAccess.WRITE).store_buffer(original)
	else:
		DirAccess.remove_absolute(arquivo)
	print("INTERFACES_SECUNDARIAS: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
