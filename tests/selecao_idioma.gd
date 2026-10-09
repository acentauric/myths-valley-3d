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
		idioma.aplicar_jogo()
		_conferir(TranslationServer.get_locale() == idioma.LOCALES[i], "entrada no vale preserva locale %d" % i)
		_conferir(TranslationServer.translate("FECHAR") == (["FECHAR", "CLOSE", "CERRAR", "CLOSE"])[i], "controle do vale traduzido %d" % i)
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
	_buscar_botoes(tela.get_node("CentroIdioma"), botoes)
	_conferir(botoes.size() == 4, "quatro idiomas selecionáveis")
	var sair := tela.find_child("SairIdioma", true, false) as Button
	_conferir(sair != null and sair.get_global_rect().position.x > tela.get_global_rect().size.x * 0.9 and sair.get_global_rect().position.y < 80.0, "× de sair no canto superior direito")
	var placa_sair := sair.get_parent() as PanelContainer
	var fundo_sair := (placa_sair.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a * placa_sair.modulate.a
	_conferir(fundo_sair >= 0.4 and fundo_sair < 0.8, "× de sair visível em repouso, mas mais discreto que os botões (fundo efetivo %.2f)" % fundo_sair)
	sair.mouse_entered.emit()
	_conferir(placa_sair.modulate.a == 1.0 and (placa_sair.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a > 0.9, "× de sair acende com o mouse em cima")
	sair.mouse_exited.emit()
	_conferir(placa_sair.modulate.a < 1.0, "× de sair volta ao repouso quando o mouse sai")
	for sufixo in idioma.SUFIXOS:
		_conferir(not str(dados.get("sair" + sufixo, "")).is_empty(), "dica de sair no idioma '%s'" % sufixo)
	_conferir(get_root().gui_get_focus_owner() == botoes[salvo], "foco lembra a escolha salva")
	# Marcas em todos os botões; acesas só na última escolha e no idioma do sistema.
	var sistema: int = idioma.idioma_do_sistema(OS.get_locale_language())
	for i in botoes.size():
		var escolha := botoes[i].find_child("MarcaEscolha", true, false)
		var do_sistema := botoes[i].find_child("MarcaSistema", true, false)
		_conferir(escolha != null and do_sistema != null, "as duas marcas no botão %d" % i)
		_conferir(bool(escolha.get_meta("ativa")) == (i == salvo), "marcador aceso só no idioma %d salvo" % salvo)
		_conferir(bool(do_sistema.get_meta("ativa")) == (i == sistema), "monitor aceso só no idioma do sistema")
		_conferir(escolha.get_global_rect().get_center().y < do_sistema.get_global_rect().get_center().y and absf(escolha.get_parent().get_global_rect().get_center().y - botoes[i].get_global_rect().get_center().y) < 1.5, "marcas empilhadas e centradas no botão %d" % i)
	for chave in ["marca_escolha", "marca_sistema"]:
		for sufixo in idioma.SUFIXOS:
			_conferir(not str(dados.get(chave + sufixo, "")).is_empty(), "dica %s no idioma '%s'" % [chave, sufixo])
	_conferir(idioma.idioma_do_sistema("fr_FR") == -1 and idioma.idioma_do_sistema("pt_BR") == 0, "só idiomas do jogo marcam o sistema")
	_conferir(inicio._titulo.text == dados["titulo" + idioma.SUFIXOS[salvo]] and inicio._descricao.text == dados["descricao" + idioma.SUFIXOS[salvo]], "textos iniciais correspondem ao botão focado")
	for i in mini(4, botoes.size()):
		_conferir(botoes[i].text == dados.opcoes[i] and not botoes[i].disabled, "opção nativa %d" % i)
	var locale_salvo := TranslationServer.get_locale()
	var retangulo_painel := painel.get_global_rect()
	var retangulo_build := build.get_global_rect()
	var retangulos_botoes: Array[Rect2] = []
	for botao in botoes:
		retangulos_botoes.append(botao.get_global_rect())
	for i in 4:
		botoes[i].mouse_entered.emit()
		await process_frame
		await process_frame
		_conferir(painel.get_global_rect().is_equal_approx(retangulo_painel) and build.get_global_rect().is_equal_approx(retangulo_build), "modal e build não saltam no idioma %d" % i)
		for j in 4:
			_conferir(botoes[j].get_global_rect().is_equal_approx(retangulos_botoes[j]), "botão %d imóvel no idioma %d" % [j, i])
		botoes[i].mouse_exited.emit()
		await process_frame
		for j in 4:
			_conferir(botoes[j].button_pressed == (j == i), "pré-seleção persistente e única %d/%d" % [i, j])
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
		if pagina == "_vagas":
			_conferir(abertura.panel.get_global_rect().get_center().is_equal_approx(root.get_visible_rect().get_center()), "vagas centralizadas")
			var controles: Array[Button] = []
			_buscar_botoes(abertura.content, controles)
			_conferir(controles.any(func(b: Button) -> bool: return b.tooltip_text == TranslationServer.translate("Fechar") and b.get_child_count() > 0), "vagas têm ícone de fechar no cabeçalho")
			_conferir(not controles.any(func(b: Button) -> bool: return b.text == TranslationServer.translate("VOLTAR")), "vagas sem botão voltar redundante")
		if pagina == "_home":
			abertura.version_link.mouse_entered.emit()
			abertura.version_link.grab_focus()
			_conferir(abertura.version_link.get_child_count() == 0, "versão sem sublinhado no hover ou foco")
			_conferir(abertura.version_link.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "versão usa cursor de mão")
			abertura.version_link.pressed.emit()
			_conferir(abertura.modal_open, "versão continua abrindo histórico")
			_conferir(not abertura.bloco_almanaque.visible, "histórico oculta notas do fundo")
			abertura._home()
			_conferir(abertura.bloco_almanaque.visible, "home restaura notas do fundo")
		for argumento in OS.get_cmdline_user_args():
			if argumento.begins_with("--captura-menu="):
				await RenderingServer.frame_post_draw
				get_root().get_texture().get_image().save_png(argumento.trim_prefix("--captura-menu=").replace(".png", pagina + ".png"))
	for lingua in 4:
		idioma.definir(lingua)
		for pagina in abertura.history_entries.size():
			abertura.history_index = pagina
			abertura._render_history()
			await process_frame
			await process_frame
			_conferir(abertura.content.find_children("*", "ScrollContainer", true, false).is_empty(), "histórico sem scroll %d/%d" % [lingua, pagina])
			var lista: VBoxContainer = abertura.content.get_node("MudancasHistorico")
			for item: RichTextLabel in lista.get_children():
				_conferir(item.get_line_count() == 1 and item.get_content_width() <= item.size.x + 1 and item.get_content_height() <= item.size.y + 1, "item inteiro em uma linha %d/%d" % [lingua, pagina])
			_conferir(abertura.panel.get_global_rect().encloses(lista.get_global_rect()), "lista cabe no modal %d/%d" % [lingua, pagina])
			_conferir(not abertura.bloco_almanaque.visible, "notas ocultas no modal %d/%d" % [lingua, pagina])
	# Uma entrada futura com mais linhas que cabem numa página preserva todas em páginas extras (#212: 14 por página).
	var itens := range(23)
	var por_pagina: int = abertura.HISTORY_ROWS
	var paginas_esperadas := ceili(23.0 / por_pagina)
	var extras: Array = abertura._paginar_historico([{"mudancas": itens, "mudancas_en": itens, "mudancas_es": itens}])
	_conferir(extras.size() == paginas_esperadas and extras[paginas_esperadas - 1].mudancas == range(por_pagina * (paginas_esperadas - 1), 23), "paginação preserva itens excedentes")
	idioma.definir(2)
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
