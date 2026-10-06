extends SceneTree
## CADA GOLPE NUM ALVO DE TRABALHO TEM SOM (#89).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/som_dos_golpes.gd
##
## `recursos_3d._aplicar_golpe` não tocava som nenhum: a galhada, o lajedo e a
## lapa eram mudos, e `picareta.mp3` existia sem ninguém o chamar. Na live faltou
## som ao partir lenha e pedra.
##
##   1. A GALHADA, partida na mão, soa como machado na madeira.
##   2. A LAPA, na picareta, soa picareta.
##   3. A EMBAÚBA cai com o som de árvore caindo no último golpe.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("SOM_DOS_GOLPES_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	var vale = current_scene
	var recursos = vale.get("_recursos")
	var audio = root.get_node("/root/Audio")
	_conferir(recursos != null, "o vale não tem os alvos de trabalho")
	if recursos == null:
		_fechar()
		return
	var alvos: Dictionary = recursos.get("_alvos")

	# --- 1. A GALHADA ------------------------------------------------------------
	_conferir(alvos.has("lenha_casa_taipa"), "a galhada do terreiro não está nos alvos")
	if alvos.has("lenha_casa_taipa"):
		recursos._aplicar_golpe("lenha_casa_taipa")
		_conferir(_ultimo_som(audio) == "machado.mp3", "o golpe na galhada tocou '%s', e é o machado" % _ultimo_som(audio))

	# --- 2. A LAPA --------------------------------------------------------------
	_conferir(alvos.has("lapa_da_lombada"), "a lapa da lombada não está nos alvos")
	if alvos.has("lapa_da_lombada"):
		recursos._aplicar_golpe("lapa_da_lombada")
		_conferir(_ultimo_som(audio) == "picareta.mp3", "o golpe na lapa tocou '%s', e é a picareta" % _ultimo_som(audio))

	# --- 3. A EMBAÚBA CAI -----------------------------------------------------------
	var embauba := ""
	for id in alvos:
		if str(id).begins_with("embauba_") and bool((alvos[id]["ficha"] as Dictionary).get("cai", false)):
			embauba = str(id)
			break
	_conferir(embauba != "", "não há embaúba que caia nos alvos")
	if embauba != "":
		var golpes := int((alvos[embauba]["ficha"] as Dictionary).get("golpes", 3))
		for i in golpes - 1:
			recursos._aplicar_golpe(embauba)
			_conferir(_ultimo_som(audio) == "machado.mp3", "o golpe %d na embaúba tocou '%s'" % [i + 1, _ultimo_som(audio)])
		recursos._aplicar_golpe(embauba)
		_conferir(_ultimo_som(audio) == "arvore_cai.mp3", "o último golpe na embaúba tocou '%s', e é a árvore caindo" % _ultimo_som(audio))
		_conferir(not alvos.has(embauba), "a embaúba caída continua nos alvos")
	_fechar()


## O arquivo do último efeito tocado pelo `Audio`.
func _ultimo_som(audio) -> String:
	var tocador: AudioStreamPlayer = audio.get("_efeitos")
	if tocador == null or tocador.stream == null:
		return ""
	return tocador.stream.resource_path.get_file()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("SOM_DOS_GOLPES_OK: a galhada soa machado, a lapa soa picareta, e a embaúba cai com a árvore caindo")
	else:
		print("som_dos_golpes: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
