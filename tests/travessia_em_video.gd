extends SceneTree
## A travessia em vídeo (#129): cada fala toca o seu clipe LTX atrás da legenda, a última
## espera o saveiro chegar à igreja, e voltar ao menu (ou entrar no jogo) fecha o vídeo.
## Run: Godot --headless --path . --script res://tests/travessia_em_video.gd

var falhas := 0


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		falhas += 1
		push_error("TRAVESSIA_EM_VIDEO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)


func _initialize() -> void:
	_run.call_deferred()


func _players(opening) -> Array:
	if opening._camada_travessia == null:
		return []
	return opening._camada_travessia.find_children("*", "VideoStreamPlayer", true, false)


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/abertura.tscn") == OK, "abertura carregou")
	await process_frame
	await process_frame
	var opening = current_scene
	for i in range(9):
		var caminho: String = opening._video_do_trecho(i)
		_conferir(ResourceLoader.exists(caminho), "clipe do trecho %d existe (%s)" % [i + 1, caminho])
	opening._intro()
	await process_frame
	var players := _players(opening)
	_conferir(players.size() == 1 and (players[0] as VideoStreamPlayer).is_playing(), "o primeiro clipe toca")
	for i in range(8):
		opening._next_line()
	await create_timer(1.2).timeout
	players = _players(opening)
	# A fusão terminou: só o clipe da última fala fica.
	_conferir(players.size() == 1, "o clipe anterior sai depois da fusão (%d)" % players.size())
	_conferir(opening.line_index == 8, "na última fala")
	_conferir(opening.line_total >= 9.5, "a última fala espera o saveiro chegar (%.1f s)" % opening.line_total)
	opening._home()
	await process_frame
	_conferir(opening._camada_travessia == null, "voltar ao menu fecha o vídeo")
	if opening._video_lobby != null:
		_conferir(opening._video_lobby.paused == not opening.flyover_active, "o lobby volta a andar")
	print("TRAVESSIA_EM_VIDEO_OK" if falhas == 0 else "TRAVESSIA_EM_VIDEO: %d falhas" % falhas)
	quit(1 if falhas > 0 else 0)
