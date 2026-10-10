extends "res://tests/suite/caso.gd"
## O ALTO DA TELA DIZ A TAREFA (#83), e não o texto da missão.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste tarefa_no_hud
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

	# --- 5. O AVISO MORA NO CANTO SUPERIOR ESQUERDO, ABAIXO DA MISSÃO (#102) ---------
	# A fala do Pedro no rodapé era uma faixa de largura inteira, atrás do minimapa; por
	# orientação do autor (07/10) ela passou para a coluna da missão: logo abaixo do quadro
	# da tarefa, quebrando a linha, sem cobrir o minimapa, a barra de mão, o relógio nem o
	# aviso de espera. Medido em três janelas, com a missão, o aviso e a espera ao mesmo tempo.
	var comprido := "Pedro: Agora come, e depois deita: o I abre a mochila, e o F come o que estiver marcado. A cama do seu tio é a de dentro, ao pé da parede. Amanhã cedo eu passo aqui — e o arraial inteiro já vai saber que tem gente na casa do finado."
	var minimapa_rodape := Control.new()
	minimapa_rodape.name = "MinimapaDoRodape"
	hud._root.add_child(minimapa_rodape)
	var barra_altura: float = float(load("res://scripts/prototipo_3d/barra_de_mao.gd").altura_ocupada())
	hud.set_objective("Siga o Pedro até a casa do finado (1/3)", "A chegada ao arraial")
	hud.set_mission_step(4, 16)
	hud.set_aviso_de_espera("Volte para perto do Pedro.")
	for tamanho_da_janela: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1000, 700)]:
		root.size = tamanho_da_janela
		var tela: Vector2 = Vector2(tamanho_da_janela)
		minimapa_rodape.position = Vector2(14.0, tela.y - 190.0)
		minimapa_rodape.size = Vector2(176.0, 176.0)
		hud.set_notice("")
		hud.set_notice(comprido)
		for _i in 4:
			await process_frame
		var aviso: Control = hud._notice_panel
		var caixa: Rect2 = aviso.get_global_rect()
		var rotulo := "janela %dx%d" % [tamanho_da_janela.x, tamanho_da_janela.y]
		_conferir(aviso.visible and aviso.size.x <= float(hud.LARGURA_DO_AVISO) + 1.0, "%s: o aviso mede %.0f de largura; o máximo é %.0f" % [rotulo, aviso.size.x, float(hud.LARGURA_DO_AVISO)])
		_conferir(hud._notice_label.get_line_count() > 1, "%s: a fala comprida do Pedro não quebrou a linha no aviso" % rotulo)
		_conferir(caixa.position.x < 60.0, "%s: o aviso não está no canto esquerdo (começa em x=%.0f)" % [rotulo, caixa.position.x])
		_conferir(caixa.position.y >= hud._heading.get_global_rect().end.y, "%s: o aviso não fica abaixo do quadro da missão (aviso em y=%.0f, missão termina em %.0f)" % [rotulo, caixa.position.y, hud._heading.get_global_rect().end.y])
		_conferir(not caixa.intersects(hud._heading.get_global_rect()), "%s: o aviso cobre a missão" % rotulo)
		_conferir(not caixa.intersects(hud._clock_panel.get_global_rect()), "%s: o aviso cobre o relógio" % rotulo)
		for barra_do_corpo: Control in [hud.barra_vida, hud.barra_folego, hud.barra_stamina]:
			_conferir(not caixa.intersects(barra_do_corpo.get_global_rect()), "%s: o aviso cobre uma barra do corpo" % rotulo)
		_conferir(hud._espera_panel.visible and not caixa.intersects(hud._espera_panel.get_global_rect()), "%s: o aviso e o aviso de espera se cobrem (ou a espera sumiu)" % rotulo)
		_conferir(not caixa.intersects(hud._barra.get_node("Fila").get_global_rect()), "%s: o aviso cobre a barra de mão" % rotulo)
		_conferir(not caixa.intersects(minimapa_rodape.get_global_rect()), "%s: o aviso cobre o minimapa (aviso termina em y=%.0f, minimapa começa em %.0f)" % [rotulo, caixa.end.y, minimapa_rodape.get_global_rect().position.y])
		_conferir(caixa.end.y <= tela.y - barra_altura, "%s: o aviso desce até %.0f e a barra de mão começa em %.0f" % [rotulo, caixa.end.y, tela.y - barra_altura])
		_conferir(root.get_visible_rect().encloses(caixa), "%s: o aviso sai da janela" % rotulo)
		# Missão trocada para uma tarefa longa: o aviso desce junto, sem cobrir o quadro novo.
		hud.set_objective("Siga a estrada para o norte até a ponte do rio grande, e volte ao Pedro para contar o que viu", "A ponte do rio grande")
		for _i in 3:
			await process_frame
		_conferir(not hud._notice_panel.get_global_rect().intersects(hud._heading.get_global_rect()), "%s: o quadro da missão cresceu e o aviso ficou por baixo dele" % rotulo)
		hud.set_objective("Siga o Pedro até a casa do finado (1/3)", "A chegada ao arraial")
	hud.set_aviso_de_espera("")
	hud.set_notice("")
	minimapa_rodape.queue_free()

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
		print("TAREFA_NO_HUD_OK: o alto da tela diz o nome da missão, a tarefa com a conta e o passo; sem páginas, setas nem X; acima do minimapa e cabendo no quadro; o aviso mora no canto superior esquerdo, abaixo da missão")
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
