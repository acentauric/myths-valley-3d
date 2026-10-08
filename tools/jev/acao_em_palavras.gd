extends RefCounted
## O nome técnico de uma ação do testador (`approach_MoradorTonho`, `walk_forward`,
## `button_1`) dito em palavras de jogador: "Aproximar de Tonho", "Andar para a frente",
## "Clicar em JOGAR". O nome técnico fica no relatório e na dica do painel.
##
## `t` é um Callable(chave: String) -> String que devolve o modelo de frase no idioma da
## sessão (`textos.json`, chaves `a_*`); `estado` é o último estado observado, usado para
## achar o nome do morador; `botoes` guarda o rótulo de cada botão do menu (`button_1`).


static func descrever(acao: String, estado: Dictionary, t: Callable, botoes: Dictionary = {}) -> String:
	if acao.is_empty():
		return ""
	var exatas := {
		"follow_pedro": "a_follow", "interact": "a_interact", "work_E": "a_work", "objective": "a_objective",
		"wait": "a_wait", "dialogue_next": "a_dialogue", "answer_yes": "a_yes", "answer_no": "a_no",
		"close_screen": "a_close", "confirm_screen": "a_confirm", "screen_tab": "a_tab", "screen_use": "a_use",
		"screen_up": "a_nav", "screen_down": "a_nav", "screen_left": "a_nav", "screen_right": "a_nav",
		"inspect_pause": "a_pause", "inspect_journal": "a_journal", "inspect_inventory": "a_inventory",
		"inspect_map": "a_map", "inspect_talents": "a_talents", "inspect_social": "a_social",
		"inspect_almanac": "a_almanac", "inspect_time": "a_time", "observe": "a_observe", "dodge": "a_dodge",
		"jump": "a_jump", "enter_home": "a_enter_home", "exit_home": "a_exit_home", "name_player": "a_name",
		"user_stop": "a_stop", "bridge_error": "a_error",
	}
	if exatas.has(acao):
		var modelo: String = t.call(exatas[acao])
		if acao == "interact" and str(estado.get("interaction_target", "")) != "":
			return t.call("a_interact_com") % str(estado["interaction_target"])
		return modelo
	if acao.begins_with("approach_"):
		var no := acao.trim_prefix("approach_")
		if no == "bed":
			return t.call("a_approach_bed")
		if no == "chest":
			return t.call("a_approach_chest")
		return t.call("a_approach") % _nome_do_morador(no, estado)
	if acao.begins_with("walk_") or acao.begins_with("run_"):
		var correr := acao.begins_with("run_")
		var rumo := acao.substr(acao.find("_") + 1)
		return t.call("a_run" if correr else "a_walk") % t.call("rumo_" + rumo)
	if acao.begins_with("gather_"):
		return t.call("a_gather") % _nome_do_item(acao.trim_prefix("gather_"))
	if acao.begins_with("explore_"):
		return t.call("a_explore") % acao.trim_prefix("explore_")
	if acao.begins_with("face_"):
		return t.call("a_face") % acao.trim_prefix("face_")
	if acao.begins_with("hand_"):
		return t.call("a_hand") % ((int(acao.trim_prefix("hand_")) + 1) % 10)
	if acao.begins_with("button_"):
		return t.call("a_button") % str(botoes.get(acao, acao.trim_prefix("button_")))
	return t.call("a_other") % acao


static func _nome_do_morador(no: String, estado: Dictionary) -> String:
	for npc in estado.get("npcs", []):
		if str(npc.get("node", "")) == no and str(npc.get("name", "")) != "":
			return str(npc["name"])
	return no.trim_prefix("Morador")


static func _nome_do_item(id: String) -> String:
	var catalogo = load("res://scripts/compartilhado/catalogo.gd")
	var dados: Dictionary = catalogo.dados(id) if catalogo != null else {}
	var idioma = load("res://scripts/prototipo_3d/idioma_menu.gd")
	var nome := str(idioma.campo(dados, "nome", id))
	return nome if nome != "" else id
