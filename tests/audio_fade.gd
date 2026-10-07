extends SceneTree

var falhas := 0

func _initialize() -> void:
	_run.call_deferred()

func _conferir(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: ", mensagem)

func _run() -> void:
	var audio := root.get_node("Audio")
	if "--sem-fade" in OS.get_cmdline_user_args():
		# Mutante isolado: as mesmas transições passam a terminar em 10 ms.
		var fonte := FileAccess.get_file_as_string("res://scripts/autoload/audio.gd")
		fonte = fonte.replace("const FADE_MUSICA := 2.5", "const FADE_MUSICA := 0.01")
		fonte = fonte.replace("const FADE_SAIDA := 1.25", "const FADE_SAIDA := 0.01")
		var arquivo := FileAccess.open("user://audio_sem_fade.gd", FileAccess.WRITE)
		arquivo.store_string(fonte)
		arquivo.close()
		audio = load("user://audio_sem_fade.gd").new()
		root.add_child(audio)
	var volume_original: float = audio.volume_musica
	var mudo_original: bool = audio.canal_mudo("musica")
	audio.definir_mudo("musica", false)
	audio.definir_volume_musica(0.25)
	# Loops distintos e determinísticos, sem depender da duração das composições.
	var a := AudioStreamWAV.new()
	var b := AudioStreamWAV.new()
	var dados := PackedByteArray()
	dados.resize(32000)
	for fluxo in [a, b]:
		fluxo.format = AudioStreamWAV.FORMAT_16_BITS
		fluxo.mix_rate = 8000
		fluxo.data = dados
		fluxo.loop_end = 16000
	audio._cache[audio.MUSICA_MENU_1] = a
	audio._cache[audio.MUSICA_MENU_2] = b
	audio.tocar_musica(audio.MUSICA_MENU_1)
	_conferir(audio._ganho_musica == 0, "primeira trilha inicia silenciosa")
	await create_timer(1.5).timeout
	_conferir(audio._musica.stream == a and audio._musica.playing and audio._ganho_musica > 0.99, "primeira trilha entra em fade")
	audio.tocar_musica(audio.MUSICA_MENU_2)
	_conferir(audio._musica.stream == a and audio._ganho_musica > 0.99, "troca não corta trilha nem ganho")
	await create_timer(0.4).timeout
	_conferir(audio._musica.stream == a and audio._ganho_musica > 0 and audio._ganho_musica < 0.9, "trilha antiga diminui gradualmente")
	var ganho_antes_do_mudo: float = audio._ganho_musica
	audio.definir_mudo("musica", true)
	_conferir(audio._musica.volume_db <= -80, "mudo prevalece durante fade")
	_conferir(is_equal_approx(audio._ganho_musica, ganho_antes_do_mudo), "mudo não reinicia transição")
	audio.definir_mudo("musica", false)
	_conferir(is_equal_approx(audio._musica.volume_db, audio._volume_db(audio.VOLUME_MUSICA, 0.25 * audio._ganho_musica * audio._abafo_musica)), "volume escolhido acompanha ganho do fade")
	await create_timer(1.0).timeout
	_conferir(audio._musica.stream == b and audio._ganho_musica > 0 and audio._ganho_musica < 0.5, "nova trilha entra baixa")
	await create_timer(1.4).timeout
	_conferir(audio._musica.stream == b and audio._ganho_musica > 0.99, "troca completa restaura ganho")
	audio.parar_musica()
	_conferir(audio._musica.playing and audio._ganho_musica > 0.99, "parar não corta imediatamente")
	await create_timer(0.4).timeout
	_conferir(audio._musica.playing and audio._ganho_musica > 0 and audio._ganho_musica < 0.9, "parada reduz ganho em fade")
	# Recomeçar durante a saída cancela o callback que pararia a trilha nova.
	var ganho: float = audio._ganho_musica
	audio.tocar_musica(audio.MUSICA_MENU_1)
	_conferir(is_equal_approx(audio._ganho_musica, ganho), "troca rápida preserva ganho atual")
	await create_timer(2.8).timeout
	_conferir(audio._musica.stream == a and audio._musica.playing and audio._ganho_musica > 0.99, "último pedido vence sem parada atrasada")
	audio.parar_musica()
	await create_timer(1.5).timeout
	_conferir(not audio._musica.playing and audio._ganho_musica < 0.01, "parada termina silenciosa")
	audio.definir_volume_musica(volume_original)
	audio.definir_mudo("musica", mudo_original)
	if falhas == 0:
		print("AUDIO_FADE_OK")
	quit(0 if falhas == 0 else 1)
