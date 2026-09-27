extends SceneTree
## Run: Godot --headless --path prototipo_3d --script res://tests/smoke_opening.gd
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(change_scene_to_file("res://scenes/prototipo_3d/abertura.tscn") == OK)
	await process_frame
	await process_frame
	var opening = current_scene
	await _capture("abertura")
	assert(opening.lines.size() == 9)
	assert(root.get_node_or_null("Audio") != null)
	var count := 0
	for folder in ["musica", "efeitos", "ambiente", "narracao"]:
		for file in DirAccess.get_files_at("res://assets/audio/" + folder):
			if file.get_extension() in ["mp3", "ogg", "wav"]:
				var stream = load("res://assets/audio/" + folder + "/" + file)
				assert(stream is AudioStream and stream.get_length() > 0)
				count += 1
	opening._options()
	await process_frame
	# Ajustes agora têm cabeçalho, abas e colunas: conta os controles dentro delas.
	assert(opening.content.find_children("*", "OptionButton", true, false).size() + opening.content.find_children("*", "HSlider", true, false).size() >= 9)
	await _capture("opcoes")
	opening._credits()
	await process_frame
	opening._home()
	opening._intro()
	assert(opening.line_index == 0)
	for i in range(8):
		opening._next_line()
	assert(opening.line_index == 8)
	opening._next_line()
	await _wait_game()
	assert(current_scene.name == "Vale3D")
	var player = current_scene.get_node("Jogador")
	for i in range(10):
		await physics_frame
	assert(player.is_on_floor())
	var event := InputEventKey.new()
	event.physical_keycode = KEY_M
	event.pressed = true
	current_scene._unhandled_key_input(event)
	await process_frame
	# M pede confirmação (vale pausado); confirmar carrega o menu.
	var hud = current_scene.get_node("HUD")
	assert(hud.menu_confirm_open() and paused)
	hud._close_menu_confirm(true)
	for i in range(600):
		if current_scene != null and current_scene.name == "Abertura":
			break
		await process_frame
	await process_frame
	assert(current_scene.name == "Abertura")
	current_scene._start_game()
	await _wait_game()
	assert(current_scene.name == "Vale3D")
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
	quit()

## A entrada no vale carrega em segundo plano (tela de carregamento).
func _wait_game() -> void:
	for i in range(600):
		if current_scene != null and current_scene.name == "Vale3D":
			break
		await process_frame
	await process_frame


func _capture(label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "user://teste_%s.png" % label
	root.get_texture().get_image().save_png(path)
	print("CAPTURE: ", ProjectSettings.globalize_path(path))
