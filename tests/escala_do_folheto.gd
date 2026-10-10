extends "res://tests/suite/caso.gd"
var falhas := 0
func _initialize() -> void:
	_run.call_deferred()
func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: ", texto)
func _run() -> void:
	await process_frame
	# O vale registra estas ações de compatibilidade para as telas compartilhadas.
	var ponte: Node = load("res://scripts/prototipo_3d/prototype.gd").new()
	ponte._bind("interagir", [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER], true)
	ponte._bind("cancelar", [KEY_ESCAPE], true)
	ponte.free()
	var tela: Node = root.get_node("Tela")
	var folheto: Node = root.get_node("Folheto")
	folheto.abrir("peso_falso")
	var tabua: Control = folheto._tabua
	for tamanho in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = tamanho
		for indice in [0, 2, 5]:
			tela.definir_componente("folheto", indice)
			await process_frame
			await process_frame
			if "--sem-texto" in OS.get_cmdline_user_args(): folheto._versos.scale = Vector2.ONE * 0.5
			var limites: Rect2 = tabua.get_global_transform_with_canvas() * (tabua.get_meta("limites_interface") as Rect2)
			conferir(root.get_visible_rect().encloses(limites), "papel e sombra cabem na janela")
			for campo in ["_titulo", "_capa", "_autor", "_versos", "_nota", "_preco", "_teclas"]:
				var item: Control = folheto.get(campo)
				conferir(item.get_parent() == tabua, "conteúdo acompanha o papel")
				conferir(item.get_global_transform().get_scale().is_equal_approx(tabua.scale), "texto e capa usam a mesma escala")
			if indice == 0: conferir(is_equal_approx(tabua.scale.x, 0.65), "folheto encolhe")
			if indice == 5: conferir(tabua.scale.x > 1.0, "papel amplia até o limite da área lógica da janela")
			if "--capturar" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
				DirAccess.make_dir_recursive_absolute("res://scratch/escala-folheto")
				root.get_texture().get_image().save_png("res://scratch/escala-folheto/%d-%d.png" % [tamanho.x, indice])
	var evento := InputEventKey.new()
	evento.keycode = KEY_ESCAPE
	evento.physical_keycode = KEY_ESCAPE
	evento.pressed = true
	Input.parse_input_event(evento)
	await process_frame
	conferir(not folheto.aberto, "Esc fecha mesmo após trocar a escala")
	tela.definir_componente("folheto", 2)
	print("ESCALA_DO_FOLHETO: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
