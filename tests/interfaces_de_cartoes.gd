extends SceneTree
## Escala individual do aceite da missão e do aviso de primeira vez (#140): cada cartão tem o seu
## ajuste, cabe na janela em três resoluções e três idiomas, e mexer num não mexe no outro.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/interfaces_de_cartoes.gd
##
## `--sem-escala` tira a transformação do aceite em memória e reprova a asserção correspondente.
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
	var tamanhos: Dictionary = tela.tamanhos_componentes.duplicate()
	tela.restaurar_componentes()
	conferir("aceite" in tela.COMPONENTES and "aviso" in tela.COMPONENTES, "aceite e aviso têm ajuste próprio")
	var textos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/interface_tamanhos.json"))
	for chave: String in ["aceite", "aviso"]:
		conferir(textos.has(chave) and textos[chave].has("texto_en") and textos[chave].has("texto_es") and textos[chave].has("ajuda_en") and textos[chave].has("ajuda_es"), "texto e ajuda de %s em pt/en/es" % chave)
	var aceite: Node = load("res://scripts/prototipo_3d/aceite_de_missao.gd").new()
	root.add_child(aceite)
	aceite.configurar(null)
	aceite.visible = true
	var aviso: Node = load("res://scripts/prototipo_3d/aviso_da_primeira_vez.gd").new()
	root.add_child(aviso)
	aviso.mostrar("cordel")
	var caixa: Control = aceite._caixa
	var cartao: Control = aviso._cartao
	for j in 3: await process_frame
	conferir(str(caixa.get_meta("componente_interface", "")) == "aceite", "a caixa do aceite declara o componente")
	conferir(str(cartao.get_meta("componente_interface", "")) == "aviso", "o cartão do aviso declara o componente")
	tela.definir_componente("aceite", 0)
	for j in 3: await process_frame
	if "--sem-escala" in OS.get_cmdline_user_args(): caixa.scale = Vector2.ONE
	conferir(is_equal_approx(caixa.scale.x, 0.65), "o aceite encolhe a 65%")
	conferir(cartao.scale == Vector2.ONE, "mexer no aceite não mexe no aviso")
	tela.definir_componente("aviso", 5)
	for j in 3: await process_frame
	conferir(cartao.scale.x > 1.0, "o aviso cresce sem o aceite acompanhar")
	conferir(is_equal_approx(caixa.scale.x, 0.65), "mexer no aviso não mexe no aceite")
	tela.definir_componente("aceite", 5)
	for idioma in 3:
		load("res://scripts/prototipo_3d/idioma_menu.gd").definir(idioma)
		for resolucao: Vector2i in [Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(1920, 1080)]:
			root.size = resolucao
			for j in 3: await process_frame
			var util: Rect2 = root.get_visible_rect()
			conferir(util.encloses(caixa.get_global_rect()), "aceite cabe a 150%% em %s idioma %d" % [resolucao, idioma])
			conferir(util.encloses(cartao.get_global_rect()), "aviso cabe a 150%% em %s idioma %d" % [resolucao, idioma])
	load("res://scripts/prototipo_3d/idioma_menu.gd").definir(0)
	tela.restaurar_componentes()
	for j in 3: await process_frame
	conferir(caixa.scale == Vector2.ONE and cartao.scale == Vector2.ONE, "restaurar devolve os dois a 100%")
	aviso.fechar()
	aceite.queue_free()
	aviso.queue_free()
	await process_frame
	tela.tamanhos_componentes = tamanhos
	if existia:
		var gravado := FileAccess.open(arquivo, FileAccess.WRITE)
		gravado.store_buffer(original)
	else:
		DirAccess.remove_absolute(arquivo)
	print("INTERFACES_DE_CARTOES: falhas=", falhas)
	quit(0 if falhas == 0 else 1)
