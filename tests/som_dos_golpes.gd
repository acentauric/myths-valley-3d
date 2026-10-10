extends "res://tests/suite/caso.gd"
## CADA GOLPE NUM ALVO DE TRABALHO TEM SOM (#89).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste som_dos_golpes
##
## `recursos_3d._aplicar_golpe` não tocava som nenhum: a galhada, o lajedo e a
## lapa eram mudos, e `picareta.mp3` existia sem ninguém o chamar. Na live faltou
## som ao partir lenha e pedra.
##
##   1. A GALHADA, partida na mão, soa madeira (o galho que quebra, ou o machado).
##   2. A LAPA, na picareta, soa picareta na pedra (a marretada, ou a picareta).
##   3. A EMBAÚBA cai com o som de árvore caindo no último golpe, depois do machado.
##
## Os nomes vêm da tabela única de `recursos_3d.gd` (SONS_DO_GOLPE, SONS_DO_ULTIMO): o
## primeiro arquivo que existe da lista de cada golpe é o que toca.

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
		# Da tabela única de `recursos_3d` (SONS_DO_GOLPE): galho partido na mão, ou o machado.
		_conferir(_ultimo_som(audio) in ["galho_quebra.mp3", "machado.mp3"], "o golpe na galhada tocou '%s', e é madeira (galho_quebra ou machado)" % _ultimo_som(audio))

	# --- 2. A LAPA --------------------------------------------------------------
	_conferir(alvos.has("lapa_da_lombada"), "a lapa da lombada não está nos alvos")
	if alvos.has("lapa_da_lombada"):
		recursos._aplicar_golpe("lapa_da_lombada")
		_conferir(_ultimo_som(audio) in ["marretada_pedra.mp3", "picareta.mp3"], "o golpe na lapa tocou '%s', e é a picareta na pedra" % _ultimo_som(audio))

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
		# A queda entra DEPOIS do golpe (`QUEDA_DEPOIS_DO_GOLPE_S`), e não por cima dele: o
		# `Audio.efeito` toca num tocador só, e o segundo som cortaria o primeiro.
		_conferir(_ultimo_som(audio) == "machado.mp3", "o último golpe na embaúba não tocou o machado antes da queda ('%s')" % _ultimo_som(audio))
		await _esperar(float(recursos.QUEDA_DEPOIS_DO_GOLPE_S) + 0.3)
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
		print("SOM_DOS_GOLPES_OK: a galhada soa madeira, a lapa soa picareta na pedra, e a embaúba cai com a árvore caindo depois do machado, da tabela única de sons do golpe")
	else:
		print("som_dos_golpes: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


## Quadros por `segundos` de relógio: o timer da queda anda com o tempo.
func _esperar(segundos: float) -> void:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		await process_frame


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
