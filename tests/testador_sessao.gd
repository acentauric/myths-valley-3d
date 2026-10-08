extends SceneTree
## O botão TESTAR e o painel da sessão do testador (#183): o modal mostra o que a ponte
## achou, sem chave nenhuma; o painel diz quem decidiu, a ação em palavras, o motivo, a
## missão, quanto falta para zerar o jogo e o gasto.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/testador_sessao.gd
##
## A escada em si (sinais de trava, Jev, GPT, bloqueio, relatório) mora em
## tools/jev/test_escada.py, com respostas falsas e sem rede.

const TestadorApoios = preload("res://scripts/prototipo_3d/testador_apoios.gd")
const AcaoEmPalavras = preload("res://tools/jev/acao_em_palavras.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")

## Carregado em tempo de execução: o painel usa o autoload Audio, que um preload não enxerga.
var PainelSessao
var falhas := 0
var textos: Dictionary


func _initialize() -> void:
	PainelSessao = load("res://tools/jev/painel_sessao.gd")
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: ", rotulo)


func _t(chave: String) -> String:
	return IdiomaMenu.campo(textos, chave)


func _run() -> void:
	IdiomaMenu.definir(0)
	textos = JSON.parse_string(FileAccess.get_file_as_string("res://tools/jev/textos.json"))
	_ponte()
	_acoes_em_palavras()
	await _painel()
	await _modal()
	print("TESTADOR_SESSAO: %d falha(s)" % falhas)
	quit(1 if falhas else 0)


func _ponte() -> void:
	var vazio: Dictionary = TestadorApoios.interpretar("")
	_conferir(bool(vazio["erro"]) and bool(vazio["apoios"]["deterministic"]["disponivel"]), "sem resposta da ponte só o determinístico fica")
	_conferir(not bool(vazio["apoios"]["jev"]["disponivel"]) and not bool(vazio["apoios"]["gpt"]["disponivel"]), "sem resposta Jev e GPT ficam desligados")
	var texto := JSON.stringify({"apoios": {"deterministic": {"disponivel": true, "motivo": "ok"},
		"jev": {"disponivel": true, "motivo": "ok"}, "gpt": {"disponivel": false, "motivo": "sem_chave_openai"}},
		"orcamento": {"padrao": 0.1, "teto": 0.5}, "ultima_sessao": {"percentual": 43.5, "capitulo": "O mirante",
		"capitulo_feitos": 2, "capitulo_total": 6, "acoes": 412}})
	var lido: Dictionary = TestadorApoios.interpretar("aviso solto\n" + texto + "\n")
	_conferir(not bool(lido["erro"]) and bool(lido["apoios"]["jev"]["disponivel"]), "a ponte diz que o Jev está disponível")
	_conferir(str(lido["apoios"]["gpt"]["motivo"]) == "sem_chave_openai", "o motivo do GPT desligado vem da ponte")
	_conferir(TestadorApoios.resumo_da_ultima(lido["ultima_sessao"]).contains("O mirante 2/6"), "a última sessão diz o capítulo")
	_conferir(TestadorApoios.resumo_da_ultima(null) == "", "sem sessão anterior não há linha")
	for chave in TestadorApoios.MOTIVOS:
		_conferir(TranslationServer.translate(TestadorApoios.MOTIVOS[chave]) != "", "motivo %s tem texto" % chave)
	var local := TestadorApoios.argumentos(false, false, 0.1, 0, "godot.exe")
	_conferir(local.has("--robot") and not local.has("--apoio-jev") and not local.has("--budget"), "só o determinístico não leva orçamento")
	_conferir(local[local.find("--seconds") + 1] == "0", "duração zero é sem limite")
	var pago := TestadorApoios.argumentos(true, true, 9.0, 5, "godot.exe")
	_conferir(pago.has("--apoio-jev") and pago.has("--apoio-gpt"), "Jev e GPT marcados viram argumentos")
	_conferir(pago[pago.find("--budget") + 1] == "0.50", "o orçamento nunca passa do teto autorizado")
	_conferir(pago[pago.find("--seconds") + 1] == "300", "minutos viram segundos")
	var so_jev := TestadorApoios.argumentos(true, false, 0.0, 1, "godot.exe")
	_conferir(so_jev[so_jev.find("--budget") + 1] == "0.01", "orçamento mínimo de um centavo")


func _acoes_em_palavras() -> void:
	var estado := {"npcs": [{"node": "MoradorTonho", "name": "Tonho"}], "interaction_target": "Pedro"}
	var t := Callable(self, "_t")
	_conferir(AcaoEmPalavras.descrever("approach_MoradorTonho", estado, t) == "Aproximar de Tonho", "approach vira o nome do morador")
	_conferir(AcaoEmPalavras.descrever("walk_forward", estado, t) == "Andar para a frente", "walk vira a direção em palavras")
	_conferir(AcaoEmPalavras.descrever("run_left", estado, t) == "Correr para a esquerda", "run vira a direção em palavras")
	_conferir(AcaoEmPalavras.descrever("interact", estado, t) == "Interagir com Pedro", "E diz com quem")
	_conferir(AcaoEmPalavras.descrever("button_1", estado, t, {"button_1": "JOGAR"}) == "Clicar em JOGAR", "botão do menu diz o rótulo")
	_conferir(AcaoEmPalavras.descrever("approach_bed", estado, t) == "Ir até a cama", "a cama tem nome próprio")
	for nome in ["follow_pedro", "work_E", "objective", "wait", "dialogue_next", "close_screen", "inspect_journal", "hand_2", "gather_pedra", "explore_Arraial"]:
		var frase := AcaoEmPalavras.descrever(nome, estado, t)
		_conferir(frase != "" and frase != nome and not frase.contains("_"), "%s virou palavras (%s)" % [nome, frase])
	_conferir(AcaoEmPalavras.descrever("coisa_nova", estado, t).contains("coisa_nova"), "ação desconhecida ainda aparece")


func _painel() -> void:
	var painel: PanelContainer = PainelSessao.new()
	root.add_child(painel)
	painel.montar(Callable(self, "_t"))
	painel.mostrar({"titulo": _t("titulo_teste"), "nivel": "", "sub": "0 ações", "acao": _t("aguardando_robot"), "decisoes": []})
	await process_frame
	var inicial := painel.size
	painel.mostrar({
		"titulo": "Testando", "nivel": "jev", "modo": "plan", "plano": [2, 3],
		"sub": "110 ações · 12 min 03 s", "acao": "Aproximar de Tonho", "acao_tecnica": "approach_MoradorTonho",
		"motivo": "Plano do Jev (2/3): contornar o Pedro", "objetivo": {"titulo": "Falar com o Tonho", "feito": 1, "total": 3},
		"progresso": {"percentual": 43.5, "feitos": 24, "total": 56, "capitulo": "Chegada ao arraial", "capitulo_feitos": 13,
			"capitulo_total": 16, "proximo_objetivo": "Cumprimentar o Tonho",
			"marcos": [{"nome": "A", "total": 16, "atual": true, "acabou": false}, {"nome": "B", "total": 40, "atual": false, "acabou": false}]},
		"ritmo": {"acoes_restantes": 120, "segundos_restantes": 400},
		"sinais": ["recusa_repetida"], "decisoes": [
			{"nivel": "deterministic", "texto": "Andar para a frente"}, {"nivel": "deterministic", "texto": "Esperar"},
			{"nivel": "jev", "texto": "Interagir (E)"}, {"nivel": "jev", "texto": "Aproximar de Tonho"}, {"nivel": "gpt", "texto": "Esperar"}],
		"gasto": "Apoios: 1 · US$ 0.0012 de 0.10"})
	await process_frame
	await process_frame
	var textos_do_painel: Array[String] = []
	for no in painel.find_children("*", "Label", true, false):
		if (no as Label).visible:
			textos_do_painel.append((no as Label).text)
	var tudo := "\n".join(textos_do_painel)
	_conferir(tudo.contains("Jev · plano 2 de 3"), "o painel diz quem decidiu e em que plano")
	_conferir(tudo.contains("Aproximar de Tonho") and not tudo.contains("approach_MoradorTonho"), "a ação aparece em palavras, não pelo nome técnico")
	_conferir(tudo.contains("Plano do Jev (2/3): contornar o Pedro"), "o motivo aparece")
	_conferir(tudo.contains("Missão: Falar com o Tonho · 1/3"), "a missão e o contador aparecem")
	_conferir(tudo.contains("Capítulo: Chegada ao arraial · 13/16") and tudo.contains("43,5% da história"), "o capítulo e a porcentagem aparecem")
	_conferir(tudo.contains("Faltam ~120 ações · ~6 min 40 s"), "a estimativa até zerar aparece")
	_conferir(tudo.contains("Cumprimentar o Tonho"), "o próximo objetivo aparece em palavras")
	_conferir(tudo.contains("Travado: a mesma recusa se repete"), "o sinal de trava aparece")
	_conferir(tudo.contains("Apoios: 1 · US$ 0.0012 de 0.10"), "o gasto aparece")
	var marcadores := 0
	for no in painel.find_children("*", "Label", true, false):
		if (no as Label).text.begins_with("● ") and (no as Label).visible:
			marcadores += 1
	_conferir(marcadores == PainelSessao.MAX_DECISOES, "as últimas decisões aparecem em lista curta (%d)" % marcadores)
	# Sem `manual_botao`, o botão do F7 (#206) fica escondido: o único visível é o Parar.
	var botoes := painel.find_children("*", "Button", true, false).filter(func(b: Node) -> bool: return (b as Button).visible)
	_conferir(botoes.size() == 1 and (botoes[0] as Button).text == "Parar", "o Parar é um botão curto")
	_conferir((botoes[0] as Button).size.y <= 36.0 and (botoes[0] as Button).size.x <= 90.0, "o Parar é pequeno e discreto")
	var teclas: Array[String] = []
	for no in painel.find_children("*", "Label", true, false):
		if (no as Label).text == "F8":
			teclas.append("F8")
	_conferir(teclas.size() == 1, "a tecla F8 vem numa plaqueta ao lado do Parar")
	_conferir(is_equal_approx(painel.size.x, PainelSessao.LARGURA) and painel.size.y > inicial.y, "o painel cresce com o conteúdo")
	_conferir(painel.size.y <= 460.0, "o painel não passa de ~460 px (%.0f)" % painel.size.y)
	var moldura := painel.get_theme_stylebox("panel") as StyleBoxFlat
	_conferir(moldura != null and moldura.border_width_left == 1 and moldura.corner_detail == 1, "o painel usa a laca com borda e canto chanfrado do HUD")
	_conferir(moldura != null and moldura.bg_color.g > moldura.bg_color.r and moldura.border_color.r > moldura.border_color.b, "fundo verde-escuro e borda dourada")
	_conferir(painel.theme != null and painel.theme.has_stylebox("normal", "BotaoNegativo"), "o painel carrega o tema do menu")
	var titulo := painel.find_children("*", "Label", true, false)[0] as Label
	_conferir(titulo.uppercase and titulo.get_theme_font("font") != ThemeDB.fallback_font, "o título tem destaque na fonte do jogo")
	var parou := [false]
	painel.parar_pedido.connect(func() -> void: parou[0] = true)
	(botoes[0] as Button).pressed.emit()
	_conferir(parou[0], "o Parar avisa a sessão")
	# O F7 (#206) mora no painel novo: com `manual_botao`, o botão aparece e pede a troca de mãos.
	painel.mostrar({"titulo": "Testando", "nivel": "", "sub": "", "acao": "", "decisoes": [], "manual_botao": _t("assumir")})
	var manual := painel.find_child("Manual", true, false) as Button
	_conferir(manual != null and manual.visible and manual.text == _t("assumir"), "o botão de assumir o controle (F7) aparece no painel")
	var trocou := [false]
	painel.manual_pedido.connect(func() -> void: trocou[0] = true)
	if manual != null:
		manual.pressed.emit()
	_conferir(trocou[0], "o botão do F7 avisa a sessão")
	# Sem cobrir o HUD: barra de mão no meio de baixo, minimapa embaixo à esquerda, e no canto
	# da direita uma coluna de dicas que forçam o painel a subir ou mudar de lado.
	var janela := Vector2(1280, 720)
	var mao := Rect2(Vector2(345, 650), Vector2(590, 52))
	var minimapa := Rect2(Vector2(14, 560), Vector2(170, 146))
	var tamanho := painel.get_combined_minimum_size()
	var livre: int = PainelSessao.escolher(janela, tamanho, [mao, minimapa])
	var area: Rect2 = PainelSessao.candidatos(janela, tamanho)[livre]
	_conferir(not area.intersects(mao.grow(PainelSessao.FOLGA)) and not area.intersects(minimapa.grow(PainelSessao.FOLGA)), "o painel não cobre a barra de mão nem o minimapa")
	_conferir(Rect2(Vector2.ZERO, janela).encloses(area), "o painel cabe na janela")
	var coluna := Rect2(Vector2(janela.x - 120, 0), Vector2(120, janela.y))
	var com_coluna: int = PainelSessao.escolher(janela, tamanho, [mao, minimapa, coluna])
	var area_2: Rect2 = PainelSessao.candidatos(janela, tamanho)[com_coluna]
	_conferir(not area_2.intersects(coluna.grow(PainelSessao.FOLGA)) and not area_2.intersects(mao), "uma coluna de atalhos à direita empurra o painel para outro canto")
	_conferir(PainelSessao.escolher(janela, tamanho, [mao, minimapa], livre) == livre, "o painel não pula enquanto o canto continua livre")
	# O conteúdo diminui (espera: some motivo, trava e progresso): a altura acompanha o mínimo, sem faixa vazia.
	var alto := painel.size.y
	painel.mostrar({"titulo": "Testando", "nivel": "", "sub": "0 ações", "acao": _t("aguardando_robot"), "decisoes": []})
	await process_frame
	await process_frame
	_conferir(painel.size.y < alto and is_equal_approx(painel.size.y, painel.get_combined_minimum_size().y), "o painel encolhe quando o conteúdo diminui (%.0f -> %.0f)" % [alto, painel.size.y])
	painel.posicionar([mao, minimapa])
	_conferir(is_equal_approx(painel.size.y, painel.get_combined_minimum_size().y), "posicionar mantém a altura no mínimo do conteúdo")
	painel.queue_free()


func _modal() -> void:
	var abertura: Node = load("res://scenes/prototipo_3d/abertura.tscn").instantiate()
	root.add_child(abertura)
	await process_frame
	await process_frame
	var deteccao := {"apoios": {"deterministic": {"disponivel": true, "motivo": "ok"},
		"jev": {"disponivel": true, "motivo": "ok"}, "gpt": {"disponivel": false, "motivo": "sem_chave_openai"}},
		"orcamento": {"padrao": 0.1, "teto": 0.5}, "ultima_sessao": {"percentual": 43.5, "capitulo": "O mirante",
		"capitulo_feitos": 2, "capitulo_total": 6, "acoes": 412}, "erro": false}
	for tamanho in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = tamanho
		abertura._modal_testador(deteccao)
		await process_frame
		await process_frame
		var alternadores: Array[Button] = []
		for no in abertura.panel.find_children("*", "Button", true, false):
			if (no as Button).toggle_mode:
				alternadores.append(no)
		_conferir(alternadores.size() == 3, "o modal lista Determinístico, Jev e GPT (%d)" % alternadores.size())
		if alternadores.size() == 3:
			_conferir(alternadores[0].button_pressed and alternadores[0].disabled, "o determinístico é a base: ligado e fixo")
			_conferir(not alternadores[1].disabled and not alternadores[1].button_pressed, "o Jev disponível nasce desmarcado e pode ser marcado")
			_conferir(alternadores[2].disabled, "o GPT sem chave fica desativado")
		var rotulos: Array[String] = []
		for no in abertura.panel.find_children("*", "Label", true, false):
			rotulos.append((no as Label).text)
		var tudo := "\n".join(rotulos)
		_conferir(tudo.contains("Sem chave da OpenAI no .env"), "o GPT desativado diz por quê")
		_conferir(tudo.contains("43,5% · O mirante 2/6 · 412 ações"), "o modal reaberto mostra a última sessão")
		_conferir(abertura.panel.find_child("IniciarTeste", true, false) != null, "o modal tem o botão Iniciar")
		var campos: Array = abertura.panel.find_children("*", "SpinBox", true, false)
		_conferir(campos.size() == 2, "o modal tem orçamento e duração")
		if campos.size() == 2:
			_conferir(is_equal_approx((campos[0] as SpinBox).max_value, 0.5), "o orçamento tem o teto autorizado")
			_conferir(not (campos[0] as SpinBox).editable, "sem Jev nem GPT marcados o orçamento fica parado")
			alternadores[1].button_pressed = true
			_conferir((campos[0] as SpinBox).editable, "marcar o Jev libera o orçamento")
		_conferir(root.get_visible_rect().encloses(abertura.panel.get_global_rect()), "o modal cabe na janela %s" % tamanho)
		for no in abertura.panel.find_children("*", "Control", true, false):
			var texto := str(no.get("text")) if no.get("text") != null else ""
			_conferir(not texto.to_lower().contains("sk-") and not texto.contains("API_KEY"), "o modal nunca mostra chave")
	abertura.queue_free()
