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
	# O jogador nasce sob a tela de carregamento: prender o cursor no _ready
	# sumia com o mouse durante a montagem do vale.
	var jogador := FileAccess.get_file_as_string("res://scripts/prototipo_3d/player_controller.gd")
	var pronto := jogador.get_slice("func _ready()", 1).get_slice("\nfunc ", 0)
	_conferir(pronto != "" and not pronto.contains("MOUSE_MODE_CAPTURED"), "o jogador não prende o cursor antes de o vale ficar pronto")
	if falhas == 0:
		print("TELA_OK: abre cheia, F11 alterna, escolha salva, dica traduzida, cursor escolhível e mouse livre no carregamento")
	quit(falhas)
