extends SceneTree
## Run: Godot --headless --path . --script res://tests/smoke_opening.gd

var falhas := 0

func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		falhas += 1
		push_error("SMOKE_OPENING_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/abertura.tscn") == OK, "Condição do teste: change_scene_to_file(\"res://scenes/prototipo_3d/abertura.tscn\") == OK")
	if falhas > 0:
		quit(1)
		return
	await process_frame
	await process_frame
	await _mundo_pronto()
	var opening = current_scene
	await _capture("abertura")
	_conferir(opening.lines.size() == 9, "Condição do teste: opening.lines.size() == 9")
	_conferir(root.get_node_or_null("Audio") != null, "Condição do teste: root.get_node_or_null(\"Audio\") != null")
	var count := 0
	for folder in ["musica", "efeitos", "ambiente", "narracao"]:
		for file in DirAccess.get_files_at("res://assets/audio/" + folder):
			if file.get_extension() in ["mp3", "ogg", "wav"]:
				var stream = load("res://assets/audio/" + folder + "/" + file)
				_conferir(stream is AudioStream and stream.get_length() > 0, "Condição do teste: stream is AudioStream and stream.get_length() > 0")
				count += 1
	opening._options()
	await process_frame
	# Ajustes agora têm cabeçalho, abas e colunas: conta os controles dentro delas.
	_conferir(opening.content.find_children("*", "OptionButton", true, false).size() + opening.content.find_children("*", "HSlider", true, false).size() >= 9, "Condição do teste: opening.content.find_children(\"*\", \"OptionButton\", true, false).size() + opening.content.find_children(\"*\", \"HSlider\", true, false).size() >= 9")
	await _capture("opcoes")
	opening._credits()
	await process_frame
	opening._home()
	opening._intro()
	_conferir(opening.line_index == 0, "Condição do teste: opening.line_index == 0")
	for i in range(8):
		opening._next_line()
	_conferir(opening.line_index == 8, "Condição do teste: opening.line_index == 8")
	opening._next_line()
	await _wait_game()
	_conferir(current_scene != null and current_scene.name == "Vale3D", "o vale abriu depois da apresentação")
	if current_scene == null or current_scene.name != "Vale3D":
		quit(1)
		return
	var player = current_scene.get_node("Jogador")
	for i in range(10):
		await physics_frame
	_conferir(player.is_on_floor(), "Condição do teste: player.is_on_floor()")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_M
	event.pressed = true
	current_scene._unhandled_key_input(event)
	await process_frame
	# M abre e fecha o MAPA do jogo (o HOME saiu do M).
	_conferir(current_scene.mapa != null and current_scene.mapa.aberto, "Condição do teste: current_scene.mapa != null and current_scene.mapa.aberto")
	var fecha := InputEventKey.new()
	fecha.physical_keycode = KEY_M
	fecha.pressed = true
	current_scene._unhandled_key_input(fecha)
	await process_frame
	_conferir(not current_scene.mapa.aberto, "Condição do teste: not current_scene.mapa.aberto")
	# HOME pela confirmação do HUD; confirmar carrega o menu.
	var hud = current_scene.get_node("HUD")
	current_scene._ask_return_to_menu()
	await process_frame
	_conferir(hud.menu_confirm_open() and paused, "Condição do teste: hud.menu_confirm_open() and paused")
	hud._close_menu_confirm(true)
	# O vale do level design (05/10) lê mais modelos em segundo plano: com a bateria cheia passa de 30 s.
	var limite_da_cena := Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < limite_da_cena:
		if current_scene != null and current_scene.name == "Abertura":
			break
		await process_frame
	await process_frame
	await _mundo_pronto()
	_conferir(current_scene != null and current_scene.name == "Abertura", "a abertura voltou depois do menu")
	if current_scene == null or current_scene.name != "Abertura":
		quit(1)
		return
	current_scene._start_game()
	await _wait_game()
	_conferir(current_scene.name == "Vale3D", "Condição do teste: current_scene.name == \"Vale3D\"")
	print("SMOKE_OK: %d audios; menu, opcoes, creditos, 9 falas, jogo, retorno e pulo" % count)
	current_scene.queue_free()
	await process_frame
	await process_frame
	# Allow music/ambience fades and the audio mixer to finish before shutdown.
	await create_timer(1.0).timeout
	for child in root.get_node("Audio").get_children():
		if child is AudioStreamPlayer:
			child.stop()
	await create_timer(0.2).timeout
	quit(1 if falhas > 0 else 0)

## A entrada no vale carrega em segundo plano (tela de carregamento).
func _wait_game() -> void:
	# O vale do level design (05/10) lê mais modelos em segundo plano: com a bateria cheia passa de 30 s.
	var limite_do_jogo := Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < limite_do_jogo:
		if current_scene != null and current_scene.name == "Vale3D":
			break
		await process_frame
	await process_frame
	await _mundo_pronto()


func _capture(label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "user://teste_%s.png" % label
	root.get_texture().get_image().save_png(path)
	print("CAPTURE: ", ProjectSettings.globalize_path(path))


## O vale se monta ao longo de vários quadros (world_builder): espera ficar pronto.
func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
