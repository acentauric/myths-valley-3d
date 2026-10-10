extends "res://tests/suite/caso.gd"
## Travessia: uma narração por legenda, nos tempos do Whisper, e a música própria.
## Toda legenda (nos três idiomas) tem o seu trecho; os trechos seguem a ordem da tomada;
## trocar de trecho com outro ainda soando espera o fade antes de começar.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: ", rotulo)


func _run() -> void:
	var audio := root.get_node("/root/Audio")
	var dialogos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogos/pedro.json"))
	var registro: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/travessia_narracao.json"))
	var legendas: Array = dialogos["travessia"]
	for chave in ["travessia_en", "travessia_es"]:
		_conferir((dialogos[chave] as Array).size() == legendas.size(), "%s tem uma legenda por trecho" % chave)
	_conferir((registro["trechos"] as Array).size() == legendas.size(), "um trecho registrado por legenda")
	var anterior := -1.0
	for i in legendas.size():
		var caminho: String = audio.trecho_travessia(i)
		_conferir(ResourceLoader.exists(caminho), "trecho %d existe" % (i + 1))
		var trecho: Dictionary = registro["trechos"][i]
		_conferir(float(trecho["inicio"]) >= anterior and float(trecho["duracao"]) > 0.5, "trecho %d em ordem e com fala" % (i + 1))
		anterior = float(trecho["fim"])
	_conferir(ResourceLoader.exists(audio.MUSICA_TRAVESSIA), "música da travessia")
	# Primeiro trecho: entra direto. Segundo, com o primeiro soando: espera o fade.
	var primeiro: float = audio.tocar_trecho_travessia(0)
	await process_frame
	await process_frame
	_conferir(primeiro > 1.0, "o primeiro trecho devolve a duração")
	var segundo: float = audio.tocar_trecho_travessia(1)
	var esperado: float = audio.FADE_TRECHO + audio.ESPERA_TRECHO
	_conferir(not audio._narracao.playing or segundo > esperado, "trocar de trecho espera o fade do anterior")
	audio.encerrar_travessia(false)
	if falhas == 0:
		print("TRAVESSIA_OK: %d trechos, um por legenda, música própria e troca suave" % legendas.size())
	quit(falhas)
