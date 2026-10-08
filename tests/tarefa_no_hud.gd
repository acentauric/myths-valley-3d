extends SceneTree
## O ALTO DA TELA DIZ A TAREFA (#83), e não o texto da missão.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/tarefa_no_hud.gd
##
## "As missões estão mostrando texto inteiro no HUD, enquanto na verdade deve
## mostrar apenas a task." Entre 04/10 e 06/10 o HUD recebia as páginas com a
## fala de todos os passos — inclusive os que ainda não tinham aberto —, e a
## fala cobria a tarefa; o X escondia o quadro inteiro.
##
##   1. O OBJETIVO É O RESUMO: o nome da missão em cima, a tarefa com a conta, e
##      o passo "n de N".
##   2. NÃO HÁ PÁGINAS: nem setas, nem "X para fechar", nem o atalho na tabela.
##   3. O QUADRO CABE E FICA ACIMA DO MINIMAPA, mesmo com uma tarefa longa.
##   4. SEM MISSÃO, só a frase, sem nome nem conta.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, motivo: String) -> void:
	if not ok:
		push_error("TAREFA_NO_HUD_FALHOU: " + motivo)
		print("FALHA: ", motivo)
		falhas += 1


func _run() -> void:
	var hud = load("res://scripts/prototipo_3d/prototype_hud.gd").new()
	root.add_child(hud)
	await process_frame
	var minimapa := Control.new()
	minimapa.name = "Minimapa"
	hud._root.add_child(minimapa)

	# --- 1. O OBJETIVO É O RESUMO ------------------------------------------------
	hud.set_objective("Tire pedra para calçar o poço (2/3)", "A chegada")
	hud.set_mission_step(5, 12)
	await process_frame
	_conferir(hud._objective_label.text == "Tire pedra para calçar o poço (2/3)", "o alto da tela não diz a tarefa: '%s'" % hud._objective_label.text)
	_conferir(hud._quest_label.visible and hud._quest_label.text.contains("A CHEGADA"), "o nome da missão não está em cima: '%s'" % hud._quest_label.text)
	_conferir(hud._mission_step.text == "5 de 12", "o passo não conta: '%s'" % hud._mission_step.text)
	_conferir(hud._heading.visible and hud._objective_label.visible and hud._region_label.visible, "o quadro da tarefa está escondido")

	# --- 2. NÃO HÁ PÁGINAS ---------------------------------------------------------
	_conferir(not hud.has_method("set_mission_pages") and not hud.has_method("_close_mission_pages"),
		"o HUD ainda tem o mecanismo das páginas")
	for nome in ["PaginaAnterior", "ProximaPagina", "FecharMissao"]:
		_conferir(hud._root.find_child(nome, true, false) == null, "o botão %s ainda existe" % nome)
	var atalhos := FileAccess.get_file_as_string("res://scripts/prototipo_3d/atalhos.gd")
	_conferir(not atalhos.contains("\"fechar_missao\""), "a tabela de atalhos ainda tem a tecla de fechar o quadro")
	var x := InputEventKey.new()
	x.keycode = KEY_X
	x.physical_keycode = KEY_X
	x.pressed = true
	Input.parse_input_event(x)
	await process_frame
	_conferir(hud._heading.visible and hud._objective_label.visible, "o X escondeu o quadro da tarefa")

	# --- 3. O QUADRO CABE E FICA ACIMA DO MINIMAPA -------------------------------------
	_conferir(hud._heading.z_index > minimapa.z_index and hud._objective_label.z_index > minimapa.z_index
		and hud._quest_label.z_index > minimapa.z_index, "a tarefa fica atrás do minimapa")
	hud.set_objective("Siga a estrada para o norte até a ponte do rio grande, e volte ao Pedro para contar o que viu", "A ponte do rio grande")
	await process_frame
	await process_frame
	_conferir(hud._objective_label.get_line_count() <= 3, "uma tarefa longa ocupou %d linhas" % hud._objective_label.get_line_count())
	_conferir(hud._heading.size.y <= 170.0, "o quadro cresceu demais com a tarefa longa: %.0f px" % hud._heading.size.y)
	_conferir(hud._heading.size.y >= hud._objective_label.position.y - hud._heading.position.y + hud._objective_label.size.y,
		"a tarefa sai do quadro por baixo")
	# Sem faixa vazia embaixo do objetivo (#176): no máximo 14 px de respiro (+1 de folga).
	_conferir(hud._heading.size.y - (hud._objective_label.position.y - hud._heading.position.y + hud._objective_label.size.y) <= 15.0,
		"sobra faixa vazia embaixo do objetivo: %.0f px" % (hud._heading.size.y - (hud._objective_label.position.y - hud._heading.position.y + hud._objective_label.size.y)))

	# --- 4. SEM MISSÃO ---------------------------------------------------------------
	hud.set_objective("Explore o vale")
	hud.set_mission_step(0, 0)
	await process_frame
	_conferir(hud._objective_label.text == "Explore o vale" and not hud._quest_label.visible and hud._mission_step.text == "",
		"sem missão o quadro ainda mostra nome ou conta: '%s' / '%s'" % [hud._quest_label.text, hud._mission_step.text])

	# --- 5. O AVISO FICA NO MEIO, ACIMA DA BARRA, E QUEBRA A LINHA (#102) -------------
	# A fala do Pedro no rodapé era uma faixa de largura inteira, atrás do minimapa.
	var comprido := "Pedro: Agora come, e depois deita: o I abre a mochila, e o F come o que estiver marcado. A cama do seu tio é a de dentro, ao pé da parede. Amanhã cedo eu passo aqui — e o arraial inteiro já vai saber que tem gente na casa do finado."
	hud.set_notice(comprido)
	await process_frame
	await process_frame
	var aviso: Control = hud._notice_panel
	var tela: Vector2 = hud.get_viewport().get_visible_rect().size
	var barra_altura: float = float(load("res://scripts/prototipo_3d/barra_de_mao.gd").altura_ocupada())
	_conferir(aviso.visible and aviso.size.x <= float(hud.LARGURA_DO_AVISO) + 1.0, "o aviso mede %.0f de largura; o máximo é %.0f" % [aviso.size.x, float(hud.LARGURA_DO_AVISO)])
	_conferir(hud._notice_label.get_line_count() > 1, "a fala comprida do Pedro não quebrou a linha no aviso")
	var centro_x: float = aviso.global_position.x + aviso.size.x * 0.5
	_conferir(absf(centro_x - tela.x * 0.5) < 2.0, "o aviso não está no meio da tela (centro em %.0f de %.0f)" % [centro_x, tela.x])
	var pe_do_aviso: float = aviso.global_position.y + aviso.size.y
	_conferir(pe_do_aviso <= tela.y - barra_altura + 0.5, "o aviso desce até %.0f e a barra de mão começa em %.0f" % [pe_do_aviso, tela.y - barra_altura])
	_conferir(aviso.global_position.x >= 300.0 or tela.x < 1000.0, "o aviso invade o minimapa (começa em %.0f)" % aviso.global_position.x)
	hud.set_notice("")

	# --- 6. OS MARCADORES DAS ETAPAS SÃO DESENHADOS PELO JOGO (#186) --------------------
	# "□" e "✓" caíam na fonte do sistema: pequenos, finos e fora da linha de base,
	# como glifo quebrado. Agora a etapa feita é "●", a por fazer é "○", e a fonte do
	# objetivo (e a do diário) as desenha sem recorrer ao sistema.
	var cadeia = load("res://scripts/prototipo_3d/cadeia_de_missoes.gd")
	var fonte_do_objetivo: Font = hud._objective_label.get_theme_font("font")
	# O diário usa a sans de leitura do HUD (#199, #202), com a Cormorant de reserva.
	var fonte_do_diario: Font = load("res://scripts/prototipo_3d/identidade.gd").fonte_do_hud()
	for marca in [cadeia.MARCA_FEITA, cadeia.MARCA_PENDENTE]:
		_conferir(fonte_do_objetivo.has_char(marca.unicode_at(0)), "a fonte do objetivo não desenha '%s'" % marca)
		_conferir(fonte_do_diario.has_char(marca.unicode_at(0)), "a fonte do diário não desenha '%s'" % marca)
	_conferir(cadeia.MARCA_FEITA != cadeia.MARCA_PENDENTE, "feita e por fazer têm o mesmo marcador")
	var fontes_antigas := ["res://scripts/prototipo_3d/cadeia_de_missoes.gd", "res://scripts/prototipo_3d/painel_vale.gd"]
	for caminho in fontes_antigas:
		var codigo := FileAccess.get_file_as_string(caminho)
		_conferir(not codigo.contains("else \"□\"") and not codigo.contains("\"✓  %s\""), "%s ainda monta marcador com □ ou ✓ da fonte do sistema" % caminho)
	for arquivo in _json_em("res://data"):
		var texto := FileAccess.get_file_as_string(arquivo)
		if texto.contains("\"etapas\""):
			_conferir(not texto.contains("□") and not texto.contains("✓"), "%s traz □ ou ✓ nas etapas" % arquivo)

	print("")
	if falhas == 0:
		print("TAREFA_NO_HUD_OK: o alto da tela diz o nome da missão, a tarefa com a conta e o passo; sem páginas, setas nem X; acima do minimapa e cabendo no quadro")
	else:
		print("tarefa_no_hud: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _json_em(pasta: String) -> Array[String]:
	var achados: Array[String] = []
	for nome in DirAccess.get_files_at(pasta):
		if nome.ends_with(".json"):
			achados.append(pasta + "/" + nome)
	for sub in DirAccess.get_directories_at(pasta):
		achados.append_array(_json_em(pasta + "/" + sub))
	return achados
