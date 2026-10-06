extends SceneTree
## Perfil isolado pelo runner. O jogo abre em tela cheia, F11 alterna e a
## escolha fica salva para a próxima abertura.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: ", rotulo)


func _run() -> void:
	var tela: Node = root.get_node("/root/Tela")
	_conferir(int(ProjectSettings.get_setting("display/window/size/mode")) == DisplayServer.WINDOW_MODE_FULLSCREEN, "project.godot abre em tela cheia")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tela.ARQUIVO))
	_conferir(tela.preferida(), "sem escolha salva, tela cheia")
	var preferencias := ConfigFile.new()
	preferencias.set_value("menu", "idioma", 2)
	preferencias.save(tela.ARQUIVO)
	_conferir(tela.preferida(), "arquivo só com idioma continua em tela cheia")
	tela.cheia = true
	var avisos: Array[bool] = []
	tela.modo_mudou.connect(func(cheia: bool) -> void: avisos.append(cheia))
	var f11 := InputEventKey.new()
	f11.keycode = KEY_F11
	f11.pressed = true
	root.push_input(f11)
	_conferir(not tela.cheia and avisos == [false], "F11 vai para janela")
	_conferir(not tela.preferida(), "janela fica salva")
	preferencias.load(tela.ARQUIVO)
	_conferir(int(preferencias.get_value("menu", "idioma", -1)) == 2, "salvar a tela preserva o idioma")
	var eco := f11.duplicate() as InputEventKey
	eco.echo = true
	root.push_input(eco)
	_conferir(not tela.cheia, "F11 segurado não pisca a tela")
	tela.alternar()
	_conferir(tela.cheia and tela.preferida() and avisos == [false, true], "botão volta para tela cheia")
	var idioma = load("res://scripts/prototipo_3d/idioma_menu.gd")
	for frase in ["Tela cheia (F11)", "Modo janela (F11)"]:
		_conferir(idioma.EN.has(frase) and idioma.ES.has(frase), "dica traduzida: %s" % frase)
	# Cursor de hardware: cada conjunto (seta e mão) chega sem compressão de VRAM.
	for conjunto: Array in tela.CURSORES:
		for i in [0, 2]:
			var caminho := str(conjunto[i])
			var importacao := ConfigFile.new()
			_conferir(importacao.load(caminho + ".import") == OK and int(importacao.get_value("params", "compress/mode", -1)) == 0, "cursor sem compressão: %s" % caminho)
			var textura := load(caminho) as Texture2D
			_conferir(textura != null and textura.get_width() <= 64 and Rect2(Vector2.ZERO, textura.get_size()).has_point(conjunto[i + 1]), "cursor carrega com ponto quente dentro: %s" % caminho)
	_conferir(tela.ROTULOS_CURSOR.size() == tela.CURSORES.size(), "um rótulo por conjunto de cursor")
	for rotulo in tela.ROTULOS_CURSOR + ["Cursor do mouse", "Interface"]:
		_conferir(idioma.EN.has(rotulo) and idioma.ES.has(rotulo), "cursor traduzido: %s" % rotulo)
	_conferir(load("res://scripts/prototipo_3d/ajuda_menu.gd").tem("Cursor do mouse"), "o cursor tem ajuda no ?")
	tela.definir_cursor(3)
	preferencias.load(tela.ARQUIVO)
	_conferir(tela.cursor == 3 and tela.cursor_preferido() == 3, "escolha do cursor fica salva")
	_conferir(int(preferencias.get_value("menu", "idioma", -1)) == 2 and tela.preferida(), "salvar o cursor preserva idioma e tela")
	tela.definir_cursor(99)
	_conferir(tela.cursor == tela.CURSORES.size() - 1, "índice fora da lista não quebra")
	# Tamanho do texto e do HUD: salvos, e o texto escala a partir do tamanho original.
	for rotulo in tela.ROTULOS_TAMANHO + ["Tamanho do texto", "Tamanho do HUD"]:
		_conferir(idioma.EN.has(rotulo) and idioma.ES.has(rotulo), "tamanho traduzido: %s" % rotulo)
	var ajuda = load("res://scripts/prototipo_3d/ajuda_menu.gd")
	_conferir(ajuda.tem("Tamanho do texto") and ajuda.tem("Tamanho do HUD"), "tamanhos têm ajuda no ?")
	# O monitor (#95): um item por tela, a escolha fica salva e preserva o resto do
	# arquivo, índice fora da lista não quebra, rótulo e ajuda traduzidos.
	var telas := maxi(1, DisplayServer.get_screen_count())
	var monitores: Array = tela.monitores()
	_conferir(monitores.size() == telas, "a lista de monitores tem %d item(ns) para %d tela(s)" % [monitores.size(), telas])
	_conferir(monitores.size() > 0 and str(monitores[0]).begins_with("Monitor 1"), "o primeiro item da lista não é o Monitor 1: %s" % str(monitores))
	tela.definir_monitor(0)
	preferencias.load(tela.ARQUIVO)
	_conferir(tela.monitor == 0 and int(preferencias.get_value("tela", "monitor", -1)) == 0 and tela.monitor_preferido() == 0, "a escolha do monitor não ficou salva")
	_conferir(int(preferencias.get_value("menu", "idioma", -1)) == 2 and tela.preferida() and tela.cursor_preferido() == tela.cursor, "salvar o monitor preserva idioma, tela e cursor")
	tela.definir_monitor(99)
	_conferir(tela.monitor == telas - 1 and tela.monitor_preferido() == tela.monitor, "monitor fora da lista não quebra")
	_conferir(idioma.EN.has("Monitor") and idioma.ES.has("Monitor"), "monitor traduzido")
	_conferir(ajuda.tem("Monitor"), "o monitor tem ajuda no ?")
	var fixo := Label.new()
	fixo.add_theme_font_size_override("font_size", 20)
	var do_tema := Label.new()
	root.add_child(fixo)
	root.add_child(do_tema)
	var base_tema := do_tema.get_theme_font_size("font_size")
	tela.definir_tamanho_texto(3)
	_conferir(fixo.get_theme_font_size("font_size") == 26 and do_tema.get_theme_font_size("font_size") == roundi(base_tema * 1.3), "Muito grande escala os textos na tela")
	var novo := Label.new()
	novo.add_theme_font_size_override("font_size", 10)
	root.add_child(novo)
	await process_frame
	_conferir(novo.get_theme_font_size("font_size") == 13, "texto que entra depois já chega escalado")
	tela.definir_tamanho_texto(1)
	_conferir(fixo.get_theme_font_size("font_size") == 20 and not do_tema.has_theme_font_size_override("font_size"), "Médio devolve o tamanho original")
	tela.definir_tamanho_hud(2)
	_conferir(tela.escala_hud == 1.3 and tela._tamanho_salvo("tamanho_hud") == 2 and tela._tamanho_salvo("tamanho_texto") == 1, "tamanhos ficam salvos")
	tela.definir_tamanho_hud(1)
	for no in [fixo, do_tema, novo]:
		no.queue_free()
	# O jogador nasce sob a tela de carregamento: prender o cursor no _ready
	# sumia com o mouse durante a montagem do vale.
	var jogador := FileAccess.get_file_as_string("res://scripts/prototipo_3d/player_controller.gd")
	var pronto := jogador.get_slice("func _ready()", 1).get_slice("\nfunc ", 0)
	_conferir(pronto != "" and not pronto.contains("MOUSE_MODE_CAPTURED"), "o jogador não prende o cursor antes de o vale ficar pronto")
	if falhas == 0:
		print("TELA_OK: abre cheia, F11 alterna, escolha salva, dica traduzida, cursor e tamanhos escolhíveis e mouse livre no carregamento")
	quit(falhas)
