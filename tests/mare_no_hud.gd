extends SceneTree
## O INDICADOR DA MARÉ AO LADO DO RELÓGIO: "maré enchendo" / "maré vazando", com a dica do que a água faz na
## praia, nos três idiomas e fora do código (`data/hud_3d.json`, "mare").
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/mare_no_hud.gd
##
## A maré vem ligada no jogo e o jogador, que a vê subir e descer na praia, não tinha como saber para que lado ela
## ia: "eu ainda não vi a maré". Três perguntas:
##
##   1. SEM MARÉ, NADA: com a maré desligada a dica do relógio é só a hora, como era.
##   2. COM MARÉ, ELA DIZ PARA QUE LADO VAI: duas horas depois da preamar a água VAZA, seis depois da baixa-mar
##      ela ENCHE — na dica do relógio e no balão do botão, e muda quando a maré vira.
##   3. NOS TRÊS IDIOMAS, E NÃO CÓPIA: pt, en e es dizem coisas diferentes, e todas vêm do JSON.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("MARE_NO_HUD_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(6)
	var vale := current_scene
	var hud = vale.get("hud")
	var mare := root.get_node("/root/Mare")
	var dia := root.get_node("/root/Dia")
	# `load()` depois de o vale subir: um `preload` aqui compila antes dos autoloads (AGENTS.md).
	var IdiomaMenu = load("res://scripts/prototipo_3d/idioma_menu.gd")
	_conferir(hud != null and hud.get("_clock_hint") != null, "o HUD não tem a dica do relógio")
	if hud == null or hud.get("_clock_hint") == null:
		_fechar()
		return
	var dados = JSON.parse_string(FileAccess.get_file_as_string("res://data/hud_3d.json"))
	var textos: Dictionary = (dados as Dictionary).get("mare", {}) if dados is Dictionary else {}
	_conferir(not textos.is_empty(), "falta o bloco \"mare\" em data/hud_3d.json")
	var codigo := FileAccess.get_file_as_string("res://scripts/prototipo_3d/prototype_hud.gd")
	dia.pausado = true

	# --- 1. SEM MARÉ, NADA ----------------------------------------------------------
	mare.modo = 0
	dia.definir_hora(9.0)
	await _frames(4)
	hud._update_clock_hint()
	var sem_mare: String = hud._clock_hint.text
	_conferir(not sem_mare.contains("maré") and not sem_mare.contains("tide") and not sem_mare.contains("marea"),
		"com a maré desligada o relógio fala dela: '%s'" % sem_mare)
	_conferir(String(hud._clock_button.tooltip_text) == "", "com a maré desligada o botão do relógio tem balão: '%s'" % hud._clock_button.tooltip_text)

	# --- 2 e 3. COM MARÉ, PARA QUE LADO VAI, NOS TRÊS IDIOMAS --------------------------
	mare.modo = 1
	var preamar_h: float = float(mare.fase_da_preamar_h)
	var casos := [
		["vazante", fposmod(preamar_h + 2.0, 24.0), false],
		["enchente", fposmod(preamar_h + 8.0, 24.0), true],
	]
	var ditos := {}
	for caso in casos:
		dia.definir_hora(float(caso[1]))
		await _frames(6)
		_conferir(bool(mare.enchente()) == bool(caso[2]), "às %.1f h a maré devia estar %s" % [float(caso[1]), caso[0]])
		for idioma in 3:
			IdiomaMenu.definir(idioma)
			hud._update_clock_hint()
			var curto := str(IdiomaMenu.campo_no_idioma(textos, caso[0], idioma))
			var dica := str(IdiomaMenu.campo_no_idioma(textos, "dica_" + str(caso[0]), idioma))
			_conferir(curto != "" and dica != "", "falta o texto da %s no idioma %d" % [caso[0], idioma])
			_conferir(String(hud._clock_hint.text).ends_with(curto), "[%s, idioma %d] a dica do relógio é '%s' e devia terminar em '%s'" % [caso[0], idioma, hud._clock_hint.text, curto])
			_conferir(String(hud._clock_button.tooltip_text) == dica, "[%s, idioma %d] o balão do botão é '%s' e devia ser '%s'" % [caso[0], idioma, hud._clock_button.tooltip_text, dica])
			ditos["%s/%d" % [caso[0], idioma]] = curto
			ditos["dica_%s/%d" % [caso[0], idioma]] = dica
	for caso in casos:
		for nome in [caso[0], "dica_" + str(caso[0])]:
			_conferir(ditos["%s/0" % nome] != ditos["%s/1" % nome] and ditos["%s/0" % nome] != ditos["%s/2" % nome] and ditos["%s/1" % nome] != ditos["%s/2" % nome],
				"o texto '%s' é igual em dois idiomas (tradução que é cópia)" % nome)
	# A maré virou, e a dica foi junto.
	IdiomaMenu.definir(0)
	hud._update_clock_hint()
	_conferir(String(hud._clock_hint.text).ends_with(str(textos.get("enchente", "?"))), "depois da virada a dica não diz que enche: '%s'" % hud._clock_hint.text)
	dia.definir_hora(fposmod(preamar_h + 2.0, 24.0))
	await _frames(6)
	hud._update_clock_hint()
	_conferir(String(hud._clock_hint.text).ends_with(str(textos.get("vazante", "?"))), "a dica não acompanhou a maré para a vazante: '%s'" % hud._clock_hint.text)
	# Fora do código: nenhuma das frases mora no script do HUD.
	for chave in ["enchente", "vazante"]:
		_conferir(not codigo.contains(str(textos.get(chave, "?"))), "'%s' ainda está escrito no script do HUD" % textos.get(chave, ""))
	print("MARE_NO_HUD: sem maré '%s'; vazante '%s'; enchente '%s'" % [sem_mare, ditos.get("vazante/0", ""), ditos.get("enchente/0", "")])
	mare.modo = 0
	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("MARE_NO_HUD_OK: sem maré o relógio só diz a hora; com ela diz se a água enche ou vaza, na dica e no balão, muda quando a maré vira, e vem do JSON nos três idiomas sem cópia")
	else:
		print("mare_no_hud: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _frames(count: int) -> void:
	for i in range(count):
		await process_frame


func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
