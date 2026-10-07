extends "res://tools/jev/sessao.gd"
## #159: a espera real da ponte obedece F8 sem depender de API ou da cena.
func _initialize() -> void:
	_conferir.call_deferred()

func _atualizar_painel() -> void:
	pass

func _amostrar_movimento(_forcar: bool = false) -> void:
	pass

func _conferir() -> void:
	_pressionar(KEY_F8, true)
	await process_frame
	var inicio := Time.get_ticks_msec()
	await _esperar(4.0)
	_pressionar(KEY_F8, false)
	var ok := parar and ultima_acao == "user_stop" and Time.get_ticks_msec() - inicio < 1000
	if not ok:
		push_error("AUTOPLAYER_PARAR: F8 não interrompeu a espera com user_stop")
	print("AUTOPLAYER_PARAR: %d falha(s)" % (0 if ok else 1))
	quit(0 if ok else 1)
