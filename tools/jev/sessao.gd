extends SceneTree
## Opt-in playtest harness. Does not change the game's ordinary launch or tests.
## No secrets, teleports, mission mutation or injected inventory in this script.

var ponte := ""
var token := ""
var pasta := ""
var duracao := 0
var orcamento := 0.10
var inicio_jogo := -1
var parar := false
var chamadas := 0
var custo := 0.0
var rotulo: Label
var acao_rotulo: Label
var painel_observador: PanelContainer
var textos: Dictionary
var idioma
var historico: Array = []
var visitas: Dictionary = {}
var catalogo: Dictionary = {}
var ultima_captura := -1
var ultima_acao := ""
var achados: Array = []
var jogada
var amostras_movimento: Array = []
var amostrar_em := 0
var fontes_de_material: Dictionary = {}
## O VIGIA DO RELÓGIO (#192): o testador nunca pausa nem acelera o relógio, e se o
## dia parar sem tela, fala ou motivo à vista o relatório registra o que houve.
const RELOGIO_PARADO_APOS_MS := {"pausado": 2000, "velocidade_zero": 2000, "segurado": 45000, "hora_parada": 0}
const RELOGIO_SEM_ANDAR_MS := 20000
## Os controles do jogador que mexem no tempo; o robô não os clica nem os confirma.
const NOMES_DO_RELOGIO := ["clock", "relogio", "relógio", "velocidade", "speed"]
## Do menu de pausa, o robô só confirma a linha de Salvar jogo.
const ICONES_LIVRES_NO_MENU := ["restaurar"]
var relogio_motivo := ""
var relogio_motivo_desde := 0
var relogio_alertado := false
var relogio_hora_vista := -1.0
var relogio_hora_mudou_em := 0


func _ponto_de_material(item: String) -> Vector3:
	var jogador: Node3D = current_scene.get("player")
	var de := jogador.global_position
	var anterior: Dictionary = fontes_de_material.get(item, {})
	if not anterior.is_empty() and is_instance_valid(anterior.fonte):
		var ainda: Vector3 = _material_acessivel(anterior.fonte, item, anterior.ponto)
		if ainda.is_finite() and ainda.distance_to(anterior.ponto) < 0.05:
			return anterior.ponto
		de = anterior.ponto
	for fonte in [current_scene.get_node_or_null("Recursos3D"), get_first_node_in_group("arvores_do_vale")]:
		if fonte == null:
			continue
		var ponto: Vector3 = _material_acessivel(fonte, item, de)
		if ponto.is_finite():
			fontes_de_material[item] = {"fonte": fonte, "ponto": ponto}
			return ponto
	fontes_de_material.erase(item)
	return Vector3.INF


func _material_acessivel(fonte: Node, item: String, de: Vector3) -> Vector3:
	if fonte.has_method("mais_perto_que_cede"):
		return fonte.mais_perto_que_cede(item, de)
	return fonte.mais_perto_que_rende(item, de)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	ponte = OS.get_environment("MV_JEV_URL")
	token = OS.get_environment("MV_JEV_TOKEN")
	pasta = OS.get_environment("MV_JEV_OUTPUT")
	duracao = int(OS.get_environment("MV_JEV_SECONDS"))
	orcamento = float(OS.get_environment("MV_JEV_BUDGET"))
	if not ponte.begins_with("http://127.0.0.1:") or token.is_empty() or pasta.is_empty():
		push_error("JEV: launch using JOGAR_JEV.cmd")
		quit(1)
		return
	textos = JSON.parse_string(FileAccess.get_file_as_string("res://tools/jev/textos.json"))
	idioma = load("res://scripts/prototipo_3d/idioma_menu.gd")
	_montar_painel()
	change_scene_to_file("res://scenes/prototipo_3d/inicio.tscn")
	await process_frame
	while not parar:
		if Input.is_physical_key_pressed(KEY_F8):
			break
		if duracao > 0 and inicio_jogo >= 0 and _segundos() >= duracao:
			break
		var cena := current_scene
		if cena == null:
			await _esperar(0.5)
			continue
		var vale := _no_vale()
		if cena.has_method("_start_game") and bool(cena.get("starting")):
			await _esperar(0.5)
			continue
		if vale and not bool(cena.get("carga_ok")):
			await _esperar(0.5)
			continue
		if vale and inicio_jogo < 0:
			inicio_jogo = Time.get_ticks_msec()
			# Reuse the game's approach geometry; walking below never calls its teleport helper.
			jogada = load("res://tests/fixtures/jogada.gd").new(self, cena, null, func(_t): pass, func(_t): pass)
			jogada.teleporte = false
			await _post("/ready", {})
			_capturar()
		_vigiar_o_relogio()
		var estado := _estado()
		var opcoes: Dictionary = _acoes(estado)
		if opcoes.is_empty():
			await _esperar(0.5)
			continue
		acao_rotulo.text = _texto("aguardando_robot" if OS.get_environment("MV_JEV_ROBOT") == "1" else "aguardando")
		var resposta: Dictionary = await _post("/decision", {"state": estado, "actions": opcoes})
		if parar:
			break
		if not str(resposta.get("stop", "")).is_empty():
			ultima_acao = str(resposta.stop)
			parar = true
			break
		if not resposta.has("choice"):
			ultima_acao = "bridge_error"
			parar = true
			break
		chamadas = int(resposta.get("calls", 0))
		custo = float(resposta.get("estimated_usd", 0.0))
		ultima_acao = str(resposta.choice)
		acao_rotulo.text = _texto("acao_robot") % ultima_acao if OS.get_environment("MV_JEV_ROBOT") == "1" else _texto("acao") % [ultima_acao, float(resposta.confidence) * 100.0]
		_atualizar_painel()
		var antes: Dictionary = _estado()
		amostras_movimento.clear()
		amostrar_em = 0
		_amostrar_movimento()
		var resultado: String = await _executar(ultima_acao)
		var depois: Dictionary = _estado()
		_amostrar_movimento(true)
		var evento := {"action": ultima_acao, "result": resultado, "before": antes, "after": depois, "movement_samples": amostras_movimento.duplicate(true)}
		var retorno: Dictionary = await _post("/event", evento)
		if not str(retorno.get("stop", "")).is_empty():
			ultima_acao = str(retorno.stop)
			parar = true
		historico.append({"action": ultima_acao, "result": resultado, "seconds": _segundos(),
			"from": antes.get("position", []), "to": depois.get("position", []),
			"objective_after": depois.get("objective", {}).get("id", "")})
		if historico.size() > 24:
			historico.pop_front()
		await _esperar(0.15 if OS.get_environment("MV_JEV_ROBOT") == "1" else 2.0)
	var motivo := "duration" if duracao > 0 and inicio_jogo >= 0 and _segundos() >= duracao else (ultima_acao if parar else "user_stop")
	await _post("/stop", {"reason": motivo})
	_capturar()
	quit()


func _texto(chave: String) -> String:
	return idioma.campo(textos, chave)


func _montar_painel() -> void:
	var camada := CanvasLayer.new()
	camada.name = "JevObservador"
	camada.layer = 110
	camada.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(camada)
	var painel := PanelContainer.new()
	painel_observador = painel
	painel.add_to_group("obstaculos_do_hud")
	camada.add_child(painel)
	painel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	painel.offset_left = -294
	painel.offset_right = -14
	painel.offset_top = -128
	painel.offset_bottom = -14
	var margens := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margens.add_theme_constant_override("margin_" + lado, 8)
	painel.add_child(margens)
	var caixa := VBoxContainer.new()
	margens.add_child(caixa)
	rotulo = Label.new()
	rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rotulo.add_theme_font_size_override("font_size", 12)
	caixa.add_child(rotulo)
	acao_rotulo = Label.new()
	acao_rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	acao_rotulo.add_theme_font_size_override("font_size", 12)
	acao_rotulo.text = _texto("aguardando_robot" if OS.get_environment("MV_JEV_ROBOT") == "1" else "aguardando")
	caixa.add_child(acao_rotulo)
	var botao := Button.new()
	botao.text = _texto("parar")
	botao.pressed.connect(func(): ultima_acao = "user_stop"; parar = true)
	caixa.add_child(botao)
	_atualizar_painel()


func _atualizar_painel() -> void:
	var titulo := _texto("sol") if OS.get_environment("MV_JEV_SOL") == "1" else (_texto("offline") if OS.get_environment("MV_JEV_OFFLINE") == "1" else _texto("titulo"))
	if OS.get_environment("MV_JEV_ROBOT") == "1":
		titulo = _texto("robot")
	rotulo.text = _texto("estado_robot") % chamadas if OS.get_environment("MV_JEV_ROBOT") == "1" else _texto("estado") % [titulo, chamadas, custo, orcamento]
	# Telas grandes e diálogos precisam de toda a área; F8 permanece ativo.
	if _no_vale() and bool(current_scene.get("carga_ok")):
		painel_observador.visible = current_scene.get("telas").aberta().is_empty() and not root.get_node("Dialogo").ativo


func _segundos() -> int:
	return 0 if inicio_jogo < 0 else int((Time.get_ticks_msec() - inicio_jogo) / 1000)


func _no_vale() -> bool:
	return current_scene != null and current_scene.scene_file_path.ends_with("vale.tscn")


func _post(caminho: String, dados: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	http.timeout = 190.0 if OS.get_environment("MV_JEV_SOL") == "1" else 15.0
	root.add_child(http)
	var erro := http.request(ponte + caminho, ["Content-Type: application/json", "Authorization: Bearer " + token], HTTPClient.METHOD_POST, JSON.stringify(dados))
	if erro != OK:
		http.queue_free()
		return {}
	var resposta: Array = await http.request_completed
	http.queue_free()
	if int(resposta[0]) != HTTPRequest.RESULT_SUCCESS or int(resposta[1]) != 200:
		return {}
	var valor = JSON.parse_string((resposta[3] as PackedByteArray).get_string_from_utf8())
	return valor if valor is Dictionary else {}


func _estado() -> Dictionary:
	var estado := {"scene": current_scene.scene_file_path if current_scene != null else "loading",
		"seconds": _segundos(), "recent_actions": historico.duplicate(true), "visits": visitas.duplicate(),
		"observations": _textos_visiveis(), "possible_issues": achados.duplicate()}
	if not _no_vale() or not bool(current_scene.get("carga_ok")):
		return estado
	var jogador: Node3D = current_scene.get("player")
	estado["position"] = _vetor(jogador.global_position)
	estado["energy"] = root.get_node("Energia").atual
	estado["life"] = root.get_node("Vida").atual
	estado["vigor"] = jogador.get("_vigor")
	estado["swimming"] = jogador.get("_nadando")
	estado["walking"] = Vector2(jogador.velocity.x, jogador.velocity.z).length() > 0.1
	estado["movement_control"] = "WASD keyboard; navigation is used only to read route waypoints, never to issue click walking"
	estado["directions"] = _direcoes(jogador)
	estado["screen"] = current_scene.get("telas").aberta()
	var pausa = current_scene.get("menu_pausa")
	if pausa != null and pausa.aberto:
		var salvar_indice := -1
		for indice in pausa._itens.size():
			if str(pausa._itens[indice].get("icone", "")) == "restaurar":
				salvar_indice = indice
		estado["pause_menu"] = {"cursor": pausa._cursor, "save_index": salvar_indice, "notice": pausa._aviso,
			"cursor_icon": _icone_da_linha_do_menu(pausa)}
	if bool(current_scene.get("mapa").get("aberto")):
		estado["screen"] = "world_map"
	if current_scene.get("aviso_da_primeira_vez").aberto():
		estado["screen"] = "first_time_notice"
	var dialogo := root.get_node("Dialogo")
	estado["dialogue"] = {"active": dialogo.ativo, "speaker": dialogo.quem_fala, "mode": dialogo.get("_modo"),
		"text": str(dialogo.get("_texto").text) if dialogo.ativo else ""}
	var objetivo: Dictionary = root.get_node("CadernoDoVale").atual()
	estado["objective"] = _json_seguro(objetivo)
	estado["journal"] = _json_seguro(root.get_node("CadernoDoVale").estado())
	var inventario := root.get_node("Inventario")
	estado["inventory"] = {"slots": inventario.espacos.duplicate(true), "selected": inventario.selecionado, "in_hand": inventario.na_mao()}
	estado.inventory["food_items"] = []
	var catalogo_itens = load("res://scripts/compartilhado/catalogo.gd")
	for espaco: Dictionary in inventario.espacos:
		var id := str(espaco.get("id", ""))
		if root.get_node("Cozinha").e_comida(id) and float(catalogo_itens.dados(id).get("folego", 0.0)) > 0.0:
			estado.inventory.food_items.append(id)
	var relogio := root.get_node("Relogio")
	var dia = _dia()
	estado["clock"] = {"day": relogio.dia, "season": relogio.estacao, "year": relogio.ano, "time": relogio.texto(), "paused": relogio.pausado,
		"player_paused": bool(dia.pausado), "speed": int(dia.velocidade), "held_by": dia.motivos_da_segurada()}
	estado["interior"] = current_scene.get("interiores").dentro()
	estado["world_map"] = _json_seguro(current_scene.get("world").ancoras)
	estado["map_orientation_keys"] = "Keys ending Frente/Direcao/Lado are orientations, not travel destinations. Other entries are world positions."
	estado["crafting"] = {}
	for bancada in ["Cozinha", "Oficina"]:
		var sistema := root.get_node(bancada)
		var receitas := []
		for id in sistema.receitas():
			receitas.append({"id": id, "requirements": _json_seguro(sistema.dados(id)), "impediment": sistema.impedimento(id)})
		estado.crafting[bancada] = receitas
	estado["learned_recipes"] = root.get_node("Receitas").aprendidas.duplicate()
	estado["built_works"] = _json_seguro(root.get_node("Obras").feitas)
	estado["money"] = root.get_node("Jogo").dinheiro
	estado["interaction_candidates"] = []
	estado["resource_work"] = {}
	var recursos_observados := current_scene.get_node_or_null("Recursos3D")
	if recursos_observados != null:
		var alvos: Dictionary = recursos_observados.get("_alvos")
		for id in alvos:
			var golpes := int(alvos[id].get("golpes_dados", 0))
			if golpes > 0:
				estado.resource_work[str(id)] = golpes
	estado["resource_targets"] = {}
	for item in ["lenha", "pedra"]:
		var ponto_material := _ponto_de_material(item)
		if ponto_material.is_finite():
			estado.resource_targets[item] = _vetor(ponto_material)
	for fonte in get_nodes_in_group("fontes_do_e"):
		var oferta: Dictionary = fonte.alvo_do_e()
		if not oferta.is_empty():
			if fonte == recursos_observados:
				oferta["em_trabalho"] = bool(fonte.get("_golpe_animando")) or str(fonte.get("_golpe_pendente")) != ""
			estado.interaction_candidates.append({"source": str(fonte.name), "kind": "tree" if fonte.has_meta("recurso_arvore") else "", "target": _json_seguro(oferta), "path": str(fonte.get_path())})
	estado["mission_chains"] = []
	estado["work_costs"] = {}
	for cadeia in get_nodes_in_group("cadeias_de_missoes"):
		var obra_exigida := str(cadeia.passo_atual().get("meta", {}).get("da_obra", ""))
		if obra_exigida != "":
			estado.work_costs[obra_exigida] = _json_seguro(root.get_node("Obras").custo(obra_exigida))
		estado.mission_chains.append({"key": cadeia.chave, "name": cadeia.nome_da_missao, "main": cadeia.principal,
			"locked": cadeia.esta_trancada(),
			"started": cadeia.iniciado, "completed": cadeia.acabou(), "step": cadeia.missao, "total": cadeia.total(),
			"current_step": _json_seguro(cadeia.passo_atual()), "events_and_deliveries": _json_seguro(cadeia.get("_levados")),
			"locked_advice": cadeia.trancada_texto})
	var fazenda: Node = current_scene.get("fazenda")
	var cadeia_fazenda: Node = fazenda.get("_cadeia") if fazenda != null else null
	estado["farm"] = {"awaiting_morning": fazenda != null and fazenda.pronta() and not fazenda.dia_marcado(),
		"day_marked": fazenda != null and fazenda.dia_marcado()}
	estado["implemented_story_completed"] = cadeia_fazenda != null and cadeia_fazenda.acabou()
	estado["npcs"] = []
	for npc in current_scene.get("moradores"):
		if is_instance_valid(npc):
			estado.npcs.append({"speaking": npc.has_method("falando_agora") and npc.falando_agora(), "node": str(npc.name), "id": npc.dados.get("id", ""), "name": npc.dados.get("nome", ""),
				"position": _vetor(npc.global_position), "distance": snappedf(jogador.global_position.distance_to(npc.global_position), 0.1)})
	var mochila := root.get_node("Mochila")
	estado["home_interaction"] = current_scene.get("casa").perto()
	var sala_casa: Node3D = current_scene.get("casa").quarto()
	if sala_casa != null:
		estado["home_entry"] = {"outside": _vetor(sala_casa.soleira_de_fora()),
			"inside": _vetor(sala_casa.soleira_de_dentro()), "locked": sala_casa.trancada()}
	if mochila.aberta:
		estado["inventory_screen"] = {"cursor": mochila.get("_cursor"), "held_slot": mochila.get("_pego"), "chest": _json_seguro(mochila.get("_bau")), "chest_cursor_base": mochila._primeiro_do_bau(), "confirmation": mochila.get("_confirmar")}
	var painel: Node = current_scene.get("painel")
	if painel.aberto:
		estado["panel"] = {"tab": painel.aba(), "allowed_tabs": painel.abas_validas(), "cursor": painel.get("_cursor"),
			"entries": _json_seguro(painel._lista_atual()), "construction": painel.obra_em_foco,
			"rows": _json_seguro(painel.get("_linhas")), "advice": painel.get("_dica").text}
	var pedro: Node3D = current_scene.get("pedro")
	if is_instance_valid(pedro):
		estado["pedro"] = {"speaking": pedro.has_method("falando_agora") and pedro.falando_agora(), "distance": snappedf(jogador.global_position.distance_to(pedro.global_position), 0.1),
			"step": pedro.get("missao"), "text": pedro.texto_da_missao(), "position": _vetor(pedro.global_position)}
		var cadeia: Node = pedro.get("_cadeia")
		var outra: Node = pedro._outra_que_conduz()
		if outra != null:
			cadeia = outra
		var destino: Vector3 = pedro._destino_da_conducao(cadeia)
		var distancia := Vector2(destino.x - pedro.global_position.x, destino.z - pedro.global_position.z).length()
		estado.pedro.merge({"conducting": bool(cadeia.passo_atual().get("conduz", false)),
			"waiting_for_player": bool(pedro.get("_esperando_quem_ficou")), "guide_destination": _vetor(destino),
			"guide_destination_reached": distancia <= 2.9, "distance_to_guide_destination": snappedf(distancia, 0.1)})
	var dono: Object = current_scene.get("foco_do_e").dono()
	estado["interaction_target"] = str(dono.name) if dono is Node else ""
	if dono != null and dono.has_method("perto"):
		var perto = dono.perto()
		if perto is Node3D:
			estado["interaction_target"] = str(perto.dados.get("nome", perto.name))
	return estado


func _json_seguro(valor):
	if valor is Vector3:
		return _vetor(valor)
	if valor is Dictionary:
		var saida := {}
		for chave in valor:
			if str(chave).ends_with("_en") or str(chave).ends_with("_es") or str(chave) in ["audio", "resposta"]:
				continue
			saida[str(chave)] = _json_seguro(valor[chave])
		return saida
	if valor is Array:
		var saida := []
		for item in valor:
			saida.append(_json_seguro(item))
		return saida
	if valor is Object:
		return str(valor.name) if valor is Node else null
	return valor


func _direcoes(jogador: Node3D) -> Dictionary:
	var direcoes := {"forward": Vector3.FORWARD, "backward": Vector3.BACK, "left": Vector3.LEFT, "right": Vector3.RIGHT}
	var resultado: Dictionary = {}
	var de: Vector3 = jogador.global_position + Vector3(0, 0.7, 0)
	var camera := Basis(Vector3.UP, float(jogador.get("_yaw")))
	for nome in direcoes:
		var rumo: Vector3 = camera * (direcoes[nome] as Vector3)
		var raio := PhysicsRayQueryParameters3D.create(de, de + rumo * 1.5, 1, [jogador.get_rid()])
		var colisao: Dictionary = jogador.get_world_3d().direct_space_state.intersect_ray(raio)
		var corrida: Vector3 = jogador.global_position + rumo * float(jogador.run_speed) * 4.0
		var passo: Vector3 = jogador.global_position + rumo * float(jogador.walk_speed) * 2.0
		var mundo: Node3D = current_scene.get("world")
		resultado[nome] = {"blocked": not colisao.is_empty(), "body": str(colisao.collider.name) if not colisao.is_empty() and colisao.collider is Node else "",
			"world_direction": _vetor(rumo), "run_endpoint": _vetor(corrida), "run_endpoint_walkable": mundo.is_walkable_point(corrida),
			"walk_endpoint": _vetor(passo), "walk_endpoint_walkable": mundo.is_walkable_point(passo)}
	return resultado


func _vetor(p: Vector3) -> Array:
	return [snappedf(p.x, 0.1), snappedf(p.y, 0.1), snappedf(p.z, 0.1)]


func _textos_visiveis() -> Array:
	var linhas: Array = []
	if current_scene == null:
		return linhas
	for classe in ["Label", "RichTextLabel"]:
		for no in root.find_children("*", classe, true, false):
			if no.is_visible_in_tree() and not no.text.is_empty() and not str(no.get_path()).contains("JevObservador"):
				linhas.append({"path": str(no.get_path()), "text": str(no.text)})
	return linhas


func _acoes(estado: Dictionary) -> Dictionary:
	catalogo.clear()
	var opcoes: Dictionary = {}
	if not _no_vale():
		var nome_pendente := current_scene.find_child("NomeJogador", true, false) as LineEdit
		if nome_pendente != null and nome_pendente.is_visible_in_tree():
			catalogo["name_player"] = nome_pendente
			return {"name_player": "Type a deterministic test name into the visible player name field and press Enter"}
		# Safe menu allowlist: never expose quit, delete, update or settings.
		for botao in current_scene.find_children("*", "BaseButton", true, false):
			if not botao.is_visible_in_tree() or botao.disabled or _e_controle_do_relogio(botao):
				continue
			var permitido: bool = str(botao.name) in ["Idioma0", "Vaga1"]
			var texto_botao := str(botao.get("text"))
			permitido = permitido or texto_botao in ["JOGAR", "CONTINUAR", "PULAR"]
			if permitido:
				var id := "button_%d" % catalogo.size()
				catalogo[id] = botao
				opcoes[id] = "Click " + (texto_botao if texto_botao != "" else str(botao.name))
		if opcoes.is_empty():
			opcoes["wait"] = "Wait for loading or narration"
		return opcoes
	if root.get_node("Dialogo").ativo:
		if int(root.get_node("Dialogo").get("_modo")) == 1:
			opcoes["answer_yes"] = "Choose yes for the visible question and confirm"
			opcoes["answer_no"] = "Choose no for the visible question and confirm"
		else:
			opcoes["dialogue_next"] = "Read the visible dialogue, then press E to advance"
		return opcoes
	if estado.get("screen", "") == "world_map":
		return {"close_screen": "Press Escape to close the world map and release movement controls"}
	if str(estado.get("screen", "")) != "" or paused:
		var da_tela := {"close_screen": "Press Escape to close the screen or dismiss the visible tutorial notice",
			"confirm_screen": "Press E to confirm the visible selection or pick/move the selected inventory item",
			"screen_tab": "Press Tab to inspect the next tab", "screen_up": "Press W to select the previous row",
			"screen_down": "Press S to select the next row", "screen_left": "Press A to move left/decrease quantity",
			"screen_right": "Press D to move right/increase quantity", "screen_use": "Press F to use/equip/eat the selected inventory item"}
		# No menu de pausa o E só vale na linha de Salvar: as do relógio e da
		# velocidade (e as de sair) não são do testador (#192).
		if not _menu_de_pausa_permite_confirmar():
			da_tela.erase("confirm_screen")
		return da_tela
	var jogador: Node3D = current_scene.get("player")
	if not jogador.is_physics_processing():
		return {"wait": "Wait for the current narration/animation to release the controls"}
	opcoes["inspect_pause"] = "Press Escape to open the normal pause menu, including Save game"
	var pedro: Node3D = current_scene.get("pedro")
	if is_instance_valid(pedro):
		catalogo["follow_pedro"] = pedro
		opcoes["follow_pedro"] = "Keep following moving Pedro for up to 12 seconds, staying near so he does not stop. Continues even after catching up, until he reaches guide_destination. Essential when conducting=true and guide_destination_reached=false."
	if str(estado.get("interaction_target", "")) != "":
		opcoes["interact"] = "Press E to interact with " + str(estado.interaction_target)
	var objetivo: Dictionary = root.get_node("CadernoDoVale").atual()
	var ponto = objetivo.get("alvo", Vector3.INF)
	if ponto is Vector3 and ponto.is_finite() and ponto != Vector3.ZERO:
		catalogo["objective"] = ponto
		opcoes["objective"] = "Walk toward current mission marker for up to 15 seconds"
	for item in estado.get("resource_targets", {}):
		var posicao: Array = estado.resource_targets[item]
		catalogo["gather_" + str(item)] = Vector3(posicao[0], posicao[1], posicao[2])
		opcoes["gather_" + str(item)] = "Walk toward an eligible source of %s; harvest separately using normal E" % str(item)
	var moradores: Array = current_scene.get("moradores")
	for npc in moradores:
		if not is_instance_valid(npc) or npc == pedro:
			continue
		var id := "approach_" + str(npc.name)
		catalogo[id] = npc
		opcoes[id] = "Approach %s, %.1f units away; previous visits: %d" % [str(npc.dados.get("nome", npc.name)), jogador.global_position.distance_to(npc.global_position), int(visitas.get(id, 0))]
	for oferta in estado.get("interaction_candidates", []):
		var p = oferta.target.get("ponto", [])
		if p is Array and p.size() == 3:
			var id := "face_" + str(oferta.source)
			catalogo[id] = Vector3(float(p[0]), float(p[1]), float(p[2]))
			opcoes[id] = "Turn to face the nearby E interaction source %s, then check interaction_target and use E" % str(oferta.source)
	var sala: Node3D = current_scene.get("casa").quarto()
	if sala != null:
		if not sala.trancada() and str(estado.get("interior", "")) != "casa":
			catalogo["enter_home"] = sala
			opcoes["enter_home"] = "Walk to the actual exterior doorway, then cross its inside threshold using W; door is unlocked"
		elif str(estado.get("interior", "")) == "casa":
			catalogo["exit_home"] = sala
			opcoes["exit_home"] = "Walk to the inside threshold, then cross the exterior doorway using W"
		for mobilia in ["bed", "chest"]:
			var id: String = "approach_" + str(mobilia)
			catalogo[id] = sala.ponto_da_cama() if mobilia == "bed" else sala.ponto_do_bau()
			opcoes[id] = "Walk to the %s inside your house, then use E. Enter the house first." % mobilia
	var mundo: Node3D = current_scene.get("world")
	for nome in mundo.ancoras:
		if str(nome).ends_with("Frente") or str(nome).ends_with("Direcao") or str(nome).ends_with("Lado"):
			continue
		if not mundo.ancoras.has(nome):
			continue
		var alvo: Vector3 = mundo.ancoras[nome]
		var id := "explore_" + str(nome)
		catalogo[id] = alvo
		opcoes[id] = "Walk toward %s (%.1f units away); previous attempts: %d" % [str(nome), jogador.global_position.distance_to(alvo), int(visitas.get(id, 0))]
	opcoes["inspect_journal"] = "Press J to inspect missions and available tasks"
	opcoes["inspect_inventory"] = "Press I to inspect inventory"
	opcoes["inspect_map"] = "Press M to inspect map"
	opcoes["inspect_talents"] = "Press K to inspect talent tree"
	opcoes["inspect_social"] = "Press P to inspect villagers"
	opcoes["inspect_almanac"] = "Press L to inspect almanac"
	opcoes["observe"] = "Press F to observe the object in front"
	opcoes["dodge"] = "Hold V briefly to dodge/ginga"
	var inventario := root.get_node("Inventario")
	for i in 10:
		if not inventario.espacos[i].is_empty():
			opcoes["hand_%d" % i] = "Press %s to toggle hand slot: %s; current hand: %s" % [str((i + 1) % 10), str(inventario.espacos[i]), inventario.na_mao()]
	opcoes["work_E"] = "Hold E for 3 seconds to work/harvest/use the selected tool on the nearby target. Do not use to talk to the wrong NPC."
	opcoes["jump"] = "Jump once using Space to test the movement control"
	var direcoes: Dictionary = estado.get("directions", {})
	for rumo in ["forward", "backward", "left", "right"]:
		if bool((direcoes.get(rumo, {}) as Dictionary).get("blocked", false)):
			continue
		opcoes["run_" + rumo] = "Run " + rumo + " relative to the camera for 4 seconds using Shift and movement keys; this direction is clear nearby"
		opcoes["walk_" + rumo] = "Walk " + rumo + " relative to the camera for 2 seconds; try another direction if the previous movement was blocked"
	opcoes["wait"] = "Wait 4 seconds for dialogue/narration or stamina recovery"
	return opcoes


func _executar(escolha: String) -> String:
	if escolha.begins_with("button_"):
		var botao: BaseButton = catalogo.get(escolha)
		if not is_instance_valid(botao) or not botao.is_visible_in_tree():
			return "button_no_longer_visible"
		if _e_controle_do_relogio(botao):
			return "clock_control_not_allowed"
		botao.pressed.emit()
		await _esperar(1.0)
		return "button_clicked"
	if _acao_do_relogio(escolha):
		return "clock_control_not_allowed"
	match escolha:
		"name_player":
			var campo: LineEdit = catalogo.get(escolha)
			if not is_instance_valid(campo) or not campo.is_visible_in_tree():
				return "name_field_no_longer_visible"
			campo.grab_focus()
			if campo.text.is_empty():
				for letra in "Viajante de teste":
					var evento := InputEventKey.new()
					evento.unicode = letra.unicode_at(0)
					evento.pressed = true
					Input.parse_input_event(evento)
					await process_frame
			await _tecla(KEY_ENTER)
			return "test_name_typed_and_submitted"
		"enter_home", "exit_home":
			var sala: Node3D = catalogo.get(escolha)
			if sala == null or sala.trancada():
				return "home_door_locked_or_unavailable"
			var fora: Vector3 = sala.soleira_de_dentro() if escolha == "exit_home" else sala.soleira_de_fora()
			var jogador: Node3D = current_scene.get("player")
			if Vector2(jogador.global_position.x - fora.x, jogador.global_position.z - fora.z).length() > 0.6:
				var chegada := await _caminhar(fora, false, true, escolha == "exit_home")
				if chegada != "arrived":
					return chegada
			return await _caminhar(sala.soleira_de_fora() if escolha == "exit_home" else sala.soleira_de_dentro(), false, true, true)
		"dialogue_next", "interact", "confirm_screen":
			if escolha == "confirm_screen" and not _menu_de_pausa_permite_confirmar():
				return "clock_or_other_menu_line_not_allowed"
			await _tecla(KEY_E)
			return "E_pressed"
		"answer_yes", "answer_no":
			await _tecla(KEY_A if escolha == "answer_yes" else KEY_D)
			await _tecla(KEY_E)
			return "question_answered"
		"close_screen", "inspect_pause":
			await _tecla(KEY_ESCAPE)
			return "Escape_pressed"
		"screen_tab":
			await _tecla(KEY_TAB)
			return "Tab_pressed"
		"screen_up", "screen_down", "screen_left", "screen_right", "screen_use":
			var teclas := {"screen_up": KEY_W, "screen_down": KEY_S, "screen_left": KEY_A, "screen_right": KEY_D, "screen_use": KEY_F}
			await _tecla(int(teclas[escolha]))
			return "screen_key_pressed"
		"inspect_journal":
			await _tecla(KEY_J)
			return "J_pressed"
		"inspect_inventory":
			await _tecla(KEY_I)
			return "I_pressed"
		"inspect_map", "inspect_talents", "inspect_social", "inspect_almanac", "observe":
			var teclas := {"inspect_map": KEY_M, "inspect_talents": KEY_K, "inspect_social": KEY_P, "inspect_almanac": KEY_L, "observe": KEY_F}
			await _tecla(int(teclas[escolha]))
			return "inspection_key_pressed"
		"work_E", "dodge":
			var tecla := KEY_E if escolha == "work_E" else KEY_V
			_pressionar(tecla, true)
			await _esperar(3.0)
			_pressionar(tecla, false)
			return "work_or_dodge_key_held"
		"jump":
			await _tecla(KEY_SPACE)
			return "Space_pressed"
		"wait":
			await _esperar(4.0)
			return "waited"
	if escolha.begins_with("hand_"):
		var indice := int(escolha.trim_prefix("hand_"))
		await _tecla(KEY_0 if indice == 9 else KEY_1 + indice)
		return "hand_slot_toggled"
	if escolha.begins_with("face_") and catalogo.has(escolha):
		jogada.virar_para(catalogo[escolha])
		await _esperar(0.3)
		return "turned_toward_interaction_source"
	if escolha.begins_with("run_") or escolha.begins_with("walk_"):
		var jogador: Node3D = current_scene.get("player")
		var inicio: Vector3 = jogador.global_position
		var correr := escolha.begins_with("run_")
		var rumo := escolha.trim_prefix("run_").trim_prefix("walk_")
		var teclas := {"forward": KEY_W, "backward": KEY_S, "left": KEY_A, "right": KEY_D}
		if not teclas.has(rumo):
			return "action_unavailable"
		jogador._cancel_walk()
		if bool(jogador.get("_run_toggled")) != correr:
			await _tecla(KEY_SHIFT)
		_pressionar(int(teclas[rumo]), true)
		await _esperar(4.0 if correr else 2.0)
		_pressionar(int(teclas[rumo]), false)
		await process_frame
		var andou := jogador.global_position.distance_to(inicio)
		if andou < 0.3:
			return "movement_blocked_no_displacement_try_other_direction"
		return "moved_%.1f_units" % andou
	if not catalogo.has(escolha) or not _no_vale():
		return "action_unavailable"
	visitas[escolha] = int(visitas.get(escolha, 0)) + 1
	return await _caminhar(catalogo[escolha], escolha == "follow_pedro")


func _amostrar_movimento(forcar: bool = false) -> void:
	if not _no_vale() or inicio_jogo < 0 or not bool(current_scene.get("carga_ok")) or (not forcar and Time.get_ticks_msec() < amostrar_em):
		return
	var jogador: Node3D = current_scene.get("player")
	amostras_movimento.append({"seconds": (Time.get_ticks_msec() - inicio_jogo) / 1000.0, "position": _vetor(jogador.global_position)})
	amostrar_em = Time.get_ticks_msec() + 500


func _caminhar(alvo, seguir: bool, exato: bool = false, passagem_da_porta: bool = false) -> String:
	var jogador: Node3D = current_scene.get("player")
	jogador._cancel_walk()
	if bool(jogador.get("_run_toggled")):
		await _tecla(KEY_SHIFT)
	var comeco := Time.get_ticks_msec()
	var ver_pos: Vector3 = jogador.global_position
	var ver_tempo := comeco
	var recalcular := 0
	var destino := Vector3.INF
	var trajeto := PackedVector3Array()
	while not parar and Time.get_ticks_msec() - comeco < (12000 if seguir else 15000):
		if Input.is_physical_key_pressed(KEY_F8):
			ultima_acao = "user_stop"
			parar = true
			_pressionar(KEY_W, false)
			return "user_stop"
		_atualizar_painel()
		_vigiar_o_relogio()
		_amostrar_movimento()
		if _segundos() - ultima_captura >= 30:
			_capturar()
		if duracao > 0 and inicio_jogo >= 0 and _segundos() >= duracao:
			_pressionar(KEY_W, false)
			return "session_end"
		if root.get_node("Dialogo").ativo or paused:
			_pressionar(KEY_W, false)
			return "interrupted_by_dialogue_or_screen"
		var ponto: Vector3 = alvo.global_position if alvo is Node3D else alvo
		# The navigation mesh may stop >4 units away; Pedro resumes below 4.
		# Use actual keyboard movement for the last stretch, as the native mission gate does.
		if seguir and jogador.global_position.distance_to(ponto) > 2.6 and jogador.global_position.distance_to(ponto) < 14.0:
			jogador._cancel_walk()
			if not await _aproximar_guia(alvo):
				return "guide_keyboard_approach_blocked_choose_other_direction"
			destino = Vector3.INF
			trajeto = PackedVector3Array()
			recalcular = 0
			continue
		if Time.get_ticks_msec() >= recalcular:
			if Vector2(jogador.global_position.x - ponto.x, jogador.global_position.z - ponto.z).length() < (0.35 if exato else (2.6 if seguir else (1.2 if alvo is Node3D else 1.0))):
				_pressionar(KEY_W, false)
				jogador._cancel_walk()
				if seguir and not _guia_chegou(alvo):
					# Catching up is not the end of following: let him lead and track him again.
					destino = Vector3.INF
					recalcular = 0
					await _esperar(0.2)
					continue
				return await _conferir_chegada(alvo, ponto, seguir)
			var novo: Vector3 = ponto if exato else jogada.chegada(ponto, 2.0 if seguir else 0.8, jogador.global_position)
			if not novo.is_finite():
				_pressionar(KEY_W, false)
				return "no_walkable_approach"
			if not destino.is_finite() or novo.distance_to(destino) > 1.5:
				trajeto = PackedVector3Array() if passagem_da_porta else jogada.caminho_ate(novo)
				if trajeto.is_empty() and jogador.global_position.distance_to(ponto) > 14.0:
					_pressionar(KEY_W, false)
					return "no_navigation_path"
				destino = novo
			recalcular = Time.get_ticks_msec() + 2000
		# Read the route, but execute it through keyboard input and ordinary physics.
		var rumo: Vector3 = ponto
		if not exato or jogador.global_position.distance_to(ponto) > 2.0:
			while not trajeto.is_empty() and Vector2(trajeto[0].x - jogador.global_position.x, trajeto[0].z - jogador.global_position.z).length() < 0.7:
				trajeto.remove_at(0)
			if not trajeto.is_empty():
				rumo = trajeto[0]
		jogada.virar_para(rumo)
		_pressionar(KEY_W, true)
		if Time.get_ticks_msec() - ver_tempo > 2000:
			if jogador.global_position.distance_to(ver_pos) < 0.3:
				var achado := {"type": "possible_stuck", "position": _vetor(jogador.global_position), "action": ultima_acao}
				achados.append(achado)
				if achados.size() > 6:
					achados.pop_front()
				jogador._cancel_walk()
				_pressionar(KEY_W, false)
				return "possible_stuck_requires_review"
			ver_pos = jogador.global_position
			ver_tempo = Time.get_ticks_msec()
		await physics_frame
	_pressionar(KEY_W, false)
	await physics_frame
	return "walking_chunk_complete"


func _aproximar_guia(pedro: Node3D) -> bool:
	var jogador: Node3D = current_scene.get("player")
	var inicio: Vector3 = jogador.global_position
	var limite := Time.get_ticks_msec() + 2000
	var verificar := Time.get_ticks_msec() + 500
	var anterior: Vector3 = inicio
	var recalcular := 0
	var caminho := PackedVector3Array()
	var leitura = load("res://tools/jev/rota_do_guia.gd")
	var reta_apoiada := false
	_pressionar(KEY_W, true)
	while not parar and not paused and not root.get_node("Dialogo").ativo and Time.get_ticks_msec() < limite:
		if Input.is_physical_key_pressed(KEY_F8):
			ultima_acao = "user_stop"
			parar = true
			break
		if duracao > 0 and inicio_jogo >= 0 and _segundos() >= duracao:
			break
		if jogador.global_position.distance_to(pedro.global_position) <= 2.4:
			break
		_amostrar_movimento()
		if Time.get_ticks_msec() >= recalcular:
			caminho = jogada.caminho_ate(pedro.global_position)
			reta_apoiada = leitura.reta_apoiada(jogador.get_world_3d().direct_space_state,
				jogador.global_position, pedro.global_position, [jogador.get_rid(), pedro.get_rid()])
			recalcular = Time.get_ticks_msec() + 500
		while caminho.size() > 1 and Vector2(caminho[0].x - jogador.global_position.x, caminho[0].z - jogador.global_position.z).length() < 0.35:
			caminho.remove_at(0)
		var rumo: Vector3 = leitura.rumo(jogador.global_position, pedro.global_position, caminho, reta_apoiada)
		if not rumo.is_finite():
			_pressionar(KEY_W, false)
			return false
		jogada.virar_para(rumo)
		if Time.get_ticks_msec() >= verificar:
			if jogador.global_position.distance_to(anterior) < 0.2:
				_pressionar(KEY_D, true)
				await _esperar(0.5)
				_pressionar(KEY_D, false)
			anterior = jogador.global_position
			verificar = Time.get_ticks_msec() + 500
		await physics_frame
	_pressionar(KEY_W, false)
	_pressionar(KEY_D, false)
	await physics_frame
	return jogador.global_position.distance_to(inicio) >= 0.2 or jogador.global_position.distance_to(pedro.global_position) <= 2.6


func _guia_chegou(pedro: Node3D) -> bool:
	var cadeia: Node = pedro.get("_cadeia")
	var outra: Node = pedro._outra_que_conduz()
	if outra != null:
		cadeia = outra
	if not bool(cadeia.passo_atual().get("conduz", false)):
		return true
	var destino: Vector3 = pedro._destino_da_conducao(cadeia)
	return Vector2(destino.x - pedro.global_position.x, destino.z - pedro.global_position.z).length() <= 2.9


func _conferir_chegada(alvo, ponto: Vector3, _seguir: bool) -> String:
	jogada.virar_para(ponto)
	await process_frame
	if not alvo is Node3D:
		return "arrived"
	var dono: Object = current_scene.get("foco_do_e").dono()
	if dono != null and dono.has_method("perto") and dono.perto() == alvo:
		return "arrived_with_correct_E_target"
	# The navigator's arrival radius can stop short of the intended NPC.
	# Finish with ordinary W input, without teleporting or forcing interaction.
	var limite := Time.get_ticks_msec() + 2500
	_pressionar(KEY_W, true)
	while Time.get_ticks_msec() < limite and not parar and not paused:
		if root.get_node("Dialogo").ativo:
			break
		if Input.is_physical_key_pressed(KEY_F8):
			ultima_acao = "user_stop"
			parar = true
			break
		jogada.virar_para(ponto)
		var foco: Object = current_scene.get("foco_do_e").dono()
		if foco != null and foco.has_method("perto") and foco.perto() == alvo:
			break
		await physics_frame
	_pressionar(KEY_W, false)
	await process_frame
	dono = current_scene.get("foco_do_e").dono()
	return "arrived_with_correct_E_target" if dono != null and dono.has_method("perto") and dono.perto() == alvo else "approach_failed_E_targets_other_character"


func _tecla(codigo: int) -> void:
	_pressionar(codigo, true)
	await process_frame
	await process_frame
	_pressionar(codigo, false)
	await process_frame


func _pressionar(codigo: int, pressionado: bool) -> void:
	if Input.is_physical_key_pressed(codigo) == pressionado:
		return
	var evento := InputEventKey.new()
	evento.keycode = codigo
	evento.physical_keycode = codigo
	evento.pressed = pressionado
	Input.parse_input_event(evento)


func _esperar(segundos: float) -> void:
	var fim := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < fim and not parar:
		if Input.is_physical_key_pressed(KEY_F8):
			ultima_acao = "user_stop"
			parar = true
		_atualizar_painel()
		_vigiar_o_relogio()
		_amostrar_movimento()
		if duracao > 0 and inicio_jogo >= 0 and _segundos() >= duracao:
			return
		if inicio_jogo >= 0 and _segundos() - ultima_captura >= 30:
			_capturar()
		await process_frame


func _capturar() -> String:
	if DisplayServer.get_name() == "headless":
		return ""
	var imagem := root.get_texture().get_image()
	if imagem != null and not imagem.is_empty():
		# Evidência contínua em JPEG evita encher o disco numa campanha longa.
		var nome := "quadro_%04d.jpg" % _segundos()
		imagem.save_jpg(pasta.path_join(nome), 0.85)
		ultima_captura = _segundos()
		return nome
	return ""


# --- o relógio é do jogador (#192) ----------------------------------------------

func _dia():
	return root.get_node("Dia")


## O relógio do jogo em milissegundos; o teste troca por um relógio dele.
func _agora() -> int:
	return Time.get_ticks_msec()


## A ação aperta um controle de tempo do jogador (pausa, velocidade, hora)? Nenhuma
## entra no catálogo; esta checagem é a segunda tranca, na hora de executar.
func _acao_do_relogio(escolha: String) -> bool:
	return escolha == "inspect_time" or escolha.begins_with("clock_") or escolha.begins_with("speed_") or escolha.begins_with("time_")


## O botão é um controle do relógio do jogador? Pelo nome dele ou de quem o carrega
## (`_clock_button`, a placa central do relógio, a velocidade): o testador não clica.
func _e_controle_do_relogio(no: Node) -> bool:
	var cena := current_scene
	var hud = cena.get("hud") if cena != null else null
	if hud != null:
		for campo in ["_clock_button", "_clock_panel", "_clock_hint"]:
			var controle = hud.get(campo)
			if controle is Node and is_instance_valid(controle) and (no == controle or controle.is_ancestor_of(no)):
				return true
	var atual := no
	while atual != null and atual != cena and atual != root:
		var nome := str(atual.name).to_lower()
		for marca in NOMES_DO_RELOGIO:
			if nome.contains(marca):
				return true
		atual = atual.get_parent()
	return false


## O ícone da linha onde está o cursor do menu de pausa ("restaurar" é o Salvar jogo).
func _icone_da_linha_do_menu(pausa) -> String:
	var cursor := int(pausa._cursor)
	if cursor < 0 or cursor >= pausa._itens.size():
		return ""
	return str(pausa._itens[cursor].get("icone", ""))


## Com o menu de pausa aberto, o E só pode confirmar a linha de Salvar jogo. As do
## relógio, da velocidade e de sair ficam com o jogador.
func _menu_de_pausa_permite_confirmar() -> bool:
	var pausa = current_scene.get("menu_pausa") if current_scene != null else null
	if pausa == null or not bool(pausa.aberto):
		return true
	return _icone_da_linha_do_menu(pausa) in ICONES_LIVRES_NO_MENU


## Tela, fala, mapa ou pergunta: o relógio parar ali é de propósito.
func _ha_modal() -> bool:
	if paused or root.get_node("Dialogo").ativo:
		return true
	var cena := current_scene
	if not str(cena.get("telas").aberta()).is_empty() or bool(cena.get("mapa").get("aberto")):
		return true
	return cena.get("aviso_da_primeira_vez").aberto() or cena.get("_pergunta_do_relogio") != null


## Por que o dia está parado agora, ou "" se anda (ou se parou de propósito).
func _motivo_do_relogio_parado() -> String:
	var agora := _agora()
	var dia = _dia()
	var hora := float(dia.hora)
	if absf(hora - relogio_hora_vista) > 0.0001:
		relogio_hora_vista = hora
		relogio_hora_mudou_em = agora
	if _ha_modal() or bool(dia.congelado_na_carga):
		relogio_hora_mudou_em = agora
		return ""
	if bool(dia.pausado):
		return "pausado"
	if int(dia.velocidade) == 0:
		return "velocidade_zero"
	if dia.segurado():
		relogio_hora_mudou_em = agora
		return "segurado"
	return "hora_parada" if agora - relogio_hora_mudou_em >= RELOGIO_SEM_ANDAR_MS else ""


## Chamado a cada volta dos laços do testador. Registra UMA vez por parada, e rearma
## quando o relógio volta a andar.
func _vigiar_o_relogio() -> void:
	if inicio_jogo < 0 or not _no_vale() or not bool(current_scene.get("carga_ok")):
		return
	var motivo := _motivo_do_relogio_parado()
	if motivo.is_empty():
		relogio_motivo = ""
		relogio_alertado = false
		return
	var agora := _agora()
	if motivo != relogio_motivo:
		relogio_motivo = motivo
		relogio_motivo_desde = agora
		relogio_alertado = false
	if relogio_alertado or agora - relogio_motivo_desde < int(RELOGIO_PARADO_APOS_MS[motivo]):
		return
	relogio_alertado = true
	_registrar_relogio_parado(motivo)


func _registrar_relogio_parado(motivo: String) -> void:
	var dia = _dia()
	var achado := {"type": "relogio_parado", "reason": motivo, "action": ultima_acao, "seconds": _segundos(),
		"time": str(root.get_node("Relogio").texto()), "player_paused": bool(dia.pausado), "speed": int(dia.velocidade),
		"held_by": dia.motivos_da_segurada(), "position": _vetor(current_scene.get("player").global_position),
		"capture": _capturar()}
	achados.append(achado)
	if achados.size() > 6:
		achados.pop_front()
	print("JEV: relogio parado (%s) apos a acao %s" % [motivo, ultima_acao])
	_post("/achado", achado)
