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
	# O runner usa um perfil isolado: também cobre arquivo sem a chave de idioma.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(idioma.ARQUIVO))
	_conferir(idioma.indice() == idioma.indice_do_sistema(OS.get_locale_language()), "primeira abertura usa idioma do SO")
	_conferir(not FileAccess.file_exists(idioma.ARQUIVO), "detecção não cria preferência")
	var preferencias := ConfigFile.new()
	preferencias.set_value("menu", "volume", 0.5)
	preferencias.save(idioma.ARQUIVO)
	for caso in [["pt_BR", 0], ["pt-PT", 0], ["en_US", 1], ["es_MX", 2], ["zh_Hans_CN", 3], ["zh-TW", 3], ["fr_FR", 1], ["", 1]]:
		_conferir(idioma.indice_preferido(caso[0]) == caso[1], "sugestão do sistema %s" % caso[0])
	preferencias.load(idioma.ARQUIVO)
	_conferir(not preferencias.has_section_key("menu", "idioma"), "sugestão não salva escolha")
	idioma.definir(2)
	_conferir(idioma.indice_preferido("zh_CN") == 2, "escolha salva vence o sistema")
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
	var painel: Control = tela.get_node("CentroIdioma/BlocoIdioma/OpcoesIdioma")
	var build: Label = tela.get_node("CentroIdioma/BlocoIdioma/IdentificacaoBuild")
	_conferir(build.text == root.get_node("Versao").texto(), "identificação usa a build do jogo")
	_conferir(build.get_global_rect().position.y >= painel.get_global_rect().end.y + 8 and absf(build.get_global_rect().get_center().x - painel.get_global_rect().get_center().x) < 1, "build centralizada abaixo do modal")
	var moldura := painel.get_theme_stylebox("panel") as StyleBoxTexture
	_conferir(moldura != null and moldura.texture.resource_path.ends_with("moldura_idioma.svg"), "moldura SVG da home")
	if moldura != null:
		_conferir(moldura.get_texture_margin(SIDE_LEFT) == 72 and moldura.get_texture_margin(SIDE_BOTTOM) == 72, "cantos preservados nas nove fatias")
	var centro_tela := tela.get_global_rect().get_center()
	var centro_painel := painel.get_global_rect().get_center()
	_conferir(absf(centro_painel.x - centro_tela.x) < 1.0 and centro_painel.y - centro_tela.y < 50.0 and centro_painel.y > centro_tela.y, "painel sobe e permanece abaixo da marca")
	var marca: Control = tela.get_node("Marca")
	_conferir(absf(marca.get_global_rect().get_center().x - centro_tela.x) < 1.0, "marca centralizada")
	_conferir(painel.get_global_rect().position.y - marca.get_global_rect().end.y >= 32.0, "espaço entre marca e painel")
	var capa: TextureRect = tela.get_node("Capa")
	var transformacao: Transform2D = capa.get_transform()
	await create_timer(1.0).timeout
	_conferir(capa.get_transform() == transformacao and capa.scale == Vector2.ONE, "fundo estático sem zoom")
	var botoes: Array[Button] = []
	_buscar_botoes(tela, botoes)
	_conferir(botoes.size() == 4, "quatro idiomas selecionáveis")
	_conferir(get_root().gui_get_focus_owner() == botoes[salvo], "foco lembra a escolha salva")
	_conferir(inicio._titulo.text == dados["titulo" + idioma.SUFIXOS[salvo]] and inicio._descricao.text == dados["descricao" + idioma.SUFIXOS[salvo]], "textos iniciais correspondem ao botão focado")
	for i in mini(4, botoes.size()):
		_conferir(botoes[i].text == dados.opcoes[i] and not botoes[i].disabled, "opção nativa %d" % i)
	var locale_salvo := TranslationServer.get_locale()
	for i in 4:
		botoes[i].mouse_entered.emit()
		_conferir(get_root().gui_get_focus_owner() == botoes[i], "destaque acompanha o idioma da prévia %d" % i)
		_conferir(inicio._titulo.text == dados["titulo" + idioma.SUFIXOS[i]], "título no hover %d" % i)
		_conferir(inicio._descricao.text == dados["descricao" + idioma.SUFIXOS[i]], "descrição no hover %d" % i)
		_conferir(inicio._aviso.text == dados["aviso" + idioma.SUFIXOS[i]], "aviso no hover %d" % i)
		_conferir(idioma.indice() == salvo and TranslationServer.get_locale() == locale_salvo and not inicio.carregando, "prévia não salva nem carrega %d" % i)
	for i in 4:
		get_root().gui_get_focus_owner().release_focus()
		botoes[i].grab_focus()
		_conferir(inicio._descricao.text == dados["descricao" + idioma.SUFIXOS[i]], "prévia pelo teclado %d" % i)
		_conferir(idioma.indice() == salvo, "foco não salva idioma %d" % i)
	botoes[salvo].grab_focus()
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
	_conferir(inicio.get_node("CanvasLayer/TelaCarregamento/Capa").scale == Vector2.ONE, "carregamento também usa fundo estático")
	var prazo := Time.get_ticks_msec() + 120000
	while current_scene == inicio and Time.get_ticks_msec() < prazo:
		await process_frame
	_conferir(current_scene != inicio, "transição para a abertura após escolha")
	var abertura := current_scene
	_conferir(abertura.lines == dados_travessia("travessia_es"), "intro segue o espanhol confirmado")
	var cenario := abertura.get_node("Cenario")
	# Capturas incluem o cenário pronto; o portão de interface dispensa montá-lo.
	if Array(OS.get_cmdline_user_args()).any(func(arg: String) -> bool: return arg.begins_with("--captura-menu=")):
		while not cenario.construido and Time.get_ticks_msec() < prazo:
			await process_frame
		await create_timer(1.5).timeout
	abertura._aplicar_entrada_final()
	var moldura_menu: NinePatchRect = abertura.moldura_nodes[1]
	for pagina in ["_home", "_vagas", "_options", "_credits"]:
		abertura.call(pagina)
		await process_frame
		_conferir(moldura_menu.texture.resource_path.ends_with("moldura_idioma.svg") and moldura_menu.visible, "moldura SVG visível em %s" % pagina)
		var retangulo := moldura_menu.get_global_rect()
		_conferir(retangulo.encloses(abertura.panel.get_global_rect()), "moldura acompanha o painel %s" % pagina)
		for argumento in OS.get_cmdline_user_args():
			if argumento.begins_with("--captura-menu="):
				await RenderingServer.frame_post_draw
				get_root().get_texture().get_image().save_png(argumento.trim_prefix("--captura-menu=").replace(".png", pagina + ".png"))
	# Na travessia, a legenda continua sem moldura; voltar restaura a talha.
	abertura._place_legenda()
	_conferir(not moldura_menu.visible, "travessia esconde moldura")
	abertura._home()
	_conferir(moldura_menu.visible, "voltar restaura moldura")
	var tema = load("res://scripts/prototipo_3d/tema_menu.gd")
	_conferir(tema.estilo_painel().texture.resource_path == moldura_menu.texture.resource_path, "modais auxiliares usam o mesmo SVG")
	if falhas == 0:
		print("SELECAO_IDIOMA_OK: espera sem cenário, quatro opções, persistência, foco e transição")
	quit(0 if falhas == 0 else 1)


func _buscar_botoes(no: Node, resultado: Array[Button]) -> void:
	if no is Button:
		resultado.append(no)
	for filho in no.get_children():
		_buscar_botoes(filho, resultado)


func dados_travessia(chave: String) -> Array:
	var dialogos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogos/pedro.json"))
	return dialogos[chave]
