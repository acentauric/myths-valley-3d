extends SceneTree
## Perfil isolado pelo runner. O início não pode carregar a abertura sem escolha.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: ", rotulo)


func _run() -> void:
	var idioma = load("res://scripts/prototipo_3d/idioma_menu.gd")
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/selecao_idioma.json"))
	for i in 4:
		idioma.definir(i)
		_conferir(idioma.indice() == i, "persiste idioma %d" % i)
		_conferir(TranslationServer.get_locale() == idioma.LOCALES[i], "aplica locale %d" % i)
		_conferir(not str(idioma.campo(dados, "descricao")).is_empty(), "descrição do idioma %d" % i)
	_conferir(idioma.campo({"texto": "PT", "texto_en": "EN"}, "texto") == "EN", "chinês usa fallback inglês")
	_conferir(TranslationServer.translate("Carregando o vale…") == dados.menu_zh["Carregando o vale…"], "carregamento em chinês")
	var ajuda = load("res://scripts/prototipo_3d/ajuda_menu.gd")
	_conferir(ajuda.texto("Idioma", 3) == ajuda.texto("Idioma", 1), "ajuda em chinês usa inglês")
	var atualizacao := root.get_node("Atualizacao")
	var manifesto_antes: Dictionary = atualizacao.manifesto
	atualizacao.manifesto = {"pagina": {"pt": "https://mythsvalley.app.br/jogar", "en": "https://mythsvalley.app.br/en/play", "es": "https://mythsvalley.app.br/es/jugar"}}
	_conferir(atualizacao.pagina_de_download().ends_with("/en/play"), "download em chinês usa inglês")
	atualizacao.manifesto = manifesto_antes
	var salvo := 3
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--idioma-captura="):
			salvo = clampi(int(argumento.trim_prefix("--idioma-captura=")), 0, 3)
			idioma.definir(salvo)
	change_scene_to_file("res://scenes/prototipo_3d/inicio.tscn")
	await scene_changed
	await process_frame
	var inicio := current_scene
	await create_timer(0.5).timeout
	_conferir(current_scene == inicio and not inicio.carregando, "aguarda escolha mesmo com idioma salvo")
	_conferir(not ResourceLoader.has_cached(inicio.ABERTURA), "abertura não está carregada antes da escolha")
	var tela: Control = inicio.get_node("CanvasLayer/SelecaoIdioma")
	_conferir(tela.get_node("Capa").texture.resource_path.ends_with("capa_dia.webp"), "mesma capa da abertura")
	var botoes: Array[Button] = []
	_buscar_botoes(tela, botoes)
	_conferir(botoes.size() == 4, "quatro idiomas selecionáveis")
	_conferir(get_root().gui_get_focus_owner() == botoes[salvo], "foco lembra a escolha salva")
	for i in mini(4, botoes.size()):
		_conferir(botoes[i].text == dados.opcoes[i] and not botoes[i].disabled, "opção nativa %d" % i)
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--captura="):
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png(argumento.trim_prefix("--captura="))
	# Enter no botão focado: também é possível começar só com o teclado.
	botoes[2].grab_focus()
	var tecla := InputEventKey.new()
	tecla.keycode = KEY_ENTER
	tecla.pressed = true
	Input.parse_input_event(tecla)
	var soltar := InputEventKey.new()
	soltar.keycode = KEY_ENTER
	Input.parse_input_event(soltar)
	await process_frame
	# A primeira escolha vence mesmo com clique duplicado.
	inicio._escolher(1)
	_conferir(inicio.carregando and idioma.indice() == 2, "escolha única aplica e salva espanhol")
	_conferir(inicio.has_node("CanvasLayer/TelaCarregamento"), "mostra carregamento após escolher")
	var prazo := Time.get_ticks_msec() + 120000
	while current_scene == inicio and Time.get_ticks_msec() < prazo:
		await process_frame
	_conferir(current_scene != inicio, "transição para a abertura após escolha")
	if falhas == 0:
		print("SELECAO_IDIOMA_OK: espera sem cenário, quatro opções, persistência, foco e transição")
	quit(0 if falhas == 0 else 1)


func _buscar_botoes(no: Node, resultado: Array[Button]) -> void:
	if no is Button:
		resultado.append(no)
	for filho in no.get_children():
		_buscar_botoes(filho, resultado)
