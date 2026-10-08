extends SceneTree
## Confere O MENU DO ESC — que recebeu a coluna de ícones do canto esquerdo.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/menu_pausa.gd
##
## "Os ícones na esquerda do HUD podem ser todos dentro do menu ESC." Eram nove
## botões redondos empilhados na borda, por cima do vale, o tempo todo, e sem
## rótulo: o do som era um desenho diferente ligado e desligado, e só passando o
## mouse se descobria qual era qual.
##
## Seis perguntas:
##
##   1. O ESC ABRE O MENU com o vale sem nada aberto. Antes ele abria a caixa de
##      "voltar ao menu?", que virou uma linha daqui.
##   2. AS LINHAS QUE ERAM ÍCONE ESTÃO TODAS LÁ. Não é por contagem: cada uma é
##      procurada pelo nome, porque perder uma função no meio da mudança de casa
##      é o jeito silencioso de esta fatia dar errado.
##   3. A LINHA DIZ O ESTADO, e não só o nome. É a razão de a coluna ter saído:
##      "Som: ligado" responde o que o botão faz E em que pé está.
##   4. APERTAR UMA LINHA MUDA O ESTADO E O RÓTULO JUNTO. Menu que faz e não se
##      redesenha é menu mentindo sobre o que ele mesmo acabou de fazer.
##   5. OS ATALHOS DA COLUNA DIREITA TÊM DICAS — o HEAD voltou a oferecê-los,
##      e cada um deve explicar sua ação ao passar o mouse.
##   6. O MENU CABE NA JANELA, que é a pergunta da barra de mão.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("MENU_PAUSA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK,
		"a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(3)

	var jogo := current_scene
	var menu = jogo.get("menu_pausa")
	_conferir(menu != null, "o vale não montou o menu do Esc")
	if menu == null:
		_fechar()
		return

	# --- 1. O ESC ABRE O MENU ------------------------------------------------
	_conferir(not menu.aberto, "o menu do Esc já abriu sozinho")
	jogo.telas.abrir("menu_pausa")
	await _frames(3)
	_conferir(menu.aberto, "pedir o menu do Esc não abriu nada")
	_conferir(paused, "o menu do Esc abriu com o vale andando atrás dele")

	var lista := _achar(menu, "Linhas") as VBoxContainer
	_conferir(lista != null, "o menu não tem a lista de linhas")
	if lista == null:
		_fechar()
		return

	# --- 2 e 3. AS NOVE FUNÇÕES, COM O ESTADO ESCRITO ------------------------
	var textos: Array[String] = []
	for filho in lista.get_children():
		if filho is Button:
			textos.append((filho as Button).text)
	var tudo := " | ".join(textos)
	print("")
	for linha in textos:
		print("  ", linha)
	print("")

	# Cada ícone da coluna antiga, pelo que ele fazia.
	var esperados := {
		"voltar ao vale": "o botão de voltar ao jogo",
		"mapa": "o ícone do mapa",
		"ajustes": "o ícone de ajustes",
		"controles": "o ícone de ajuda (controles)",
		"som:": "o ícone do som, com o estado",
		"relógio:": "o ícone do relógio, com o estado",
		"velocidade do tempo:": "o ícone da velocidade do tempo, com o estado",
		"câmera do mouse:": "o ícone da câmera, com o estado",
		"voltar ao menu inicial": "o ícone HOME",
		"sair do jogo": "a saída do jogo",
	}
	for chave in esperados:
		_conferir(tudo.to_lower().contains(str(chave)),
			"o menu do Esc não tem %s (procurei por '%s')" % [str(esperados[chave]), str(chave)])

	# --- 4. APERTAR MUDA O ESTADO E O RÓTULO JUNTO ---------------------------
	#
	# O som é o caso mais limpo: alterna, e o rótulo tem de acompanhar no mesmo
	# quadro. Se o texto não mudar, o menu está mentindo sobre o que fez.
	var audio := root.get_node("/root/Audio")
	var antes: bool = audio.som_ativo
	var i_som := _linha_com(lista, "Som:")
	_conferir(i_som >= 0, "não achei a linha do som")
	if i_som >= 0:
		var texto_antes: String = (lista.get_child(i_som) as Button).text
		menu._cursor = i_som
		menu._fazer()
		await _frames(2)
		_conferir(audio.som_ativo != antes, "apertar a linha do som não trocou o som")
		var depois_lista := _achar(menu, "Linhas") as VBoxContainer
		var texto_depois: String = (depois_lista.get_child(i_som) as Button).text
		_conferir(texto_depois != texto_antes,
			"o som trocou e o rótulo ficou igual ('%s'): o menu mente sobre o que fez" % texto_depois)
		# Devolve como estava, que é educação de portão.
		menu._cursor = i_som
		menu._fazer()
		await _frames(2)
		_conferir(audio.som_ativo == antes, "não consegui devolver o som ao estado de antes")

	# --- 4b. CADA LINHA TEM ÍCONE ---------------------------------------------
	#
	# "Não precisa descartar os ícones que você tinha colocado, eles são
	# ilustrativos e facilitam a identificação das coisas."
	#
	# O que estava errado na coluna do canto não era o desenho: era o desenho
	# SOZINHO, sem rótulo e sem estado. Juntos, cada um faz o que sabe — o ícone
	# acha a linha de relance, o texto diz o que ela faz e em que pé está.
	var sem_icone: Array[String] = []
	for filho in lista.get_children():
		if not (filho is Button):
			continue
		var tem := false
		for neto in filho.get_children():
			if neto is Control:
				tem = true
		if not tem:
			sem_icone.append((filho as Button).text)
	_conferir(sem_icone.is_empty(),
		"linha(s) do menu sem ícone: %s" % str(sem_icone))

	# --- 4b. O ÍCONE NÃO FICA POR CIMA DO TEXTO -------------------------------
	#
	# "Os ícones do MENU ESC estão por cima do texto." O ícone mora DENTRO do
	# botão, e quem decide onde o texto começa é a margem esquerda do estilo da
	# linha: ela valia 14 em todas, e o ícone ocupa de 14 a 40 — o nome da opção
	# nascia debaixo do desenho.
	#
	# A medida é a distância entre o fim do ícone e o começo do texto, lida do
	# ESTILO que o botão está usando, e não da constante: é o estilo que a tela
	# obedece, e foi uma constante que não chegava nele que causou o defeito.
	var encostados: Array[String] = []
	for filho in lista.get_children():
		if not (filho is Button):
			continue
		var botao := filho as Button
		var fim_do_icone := 0.0
		for neto in botao.get_children():
			if neto is Control:
				fim_do_icone = maxf(fim_do_icone,
					(neto as Control).position.x + (neto as Control).size.x)
		if fim_do_icone <= 0.0:
			continue
		var estilo := botao.get_theme_stylebox("normal")
		var comeca_o_texto: float = estilo.content_margin_left if estilo != null else 0.0
		if comeca_o_texto < fim_do_icone:
			encostados.append("%s (ícone até %.0f, texto em %.0f)"
				% [botao.text, fim_do_icone, comeca_o_texto])
	_conferir(encostados.is_empty(),
		"linha(s) com o texto debaixo do ícone: %s" % str(encostados))

	# --- 4c. SALVAR DEVOLVE RECADO, COMO NO 2D --------------------------------
	#
	# Salvar dá certo e a tela fica igual. Ação sem retorno é a que se aperta
	# três vezes — é o que o painel do J já faz, vindo do 2D. O recado sai no
	# rodapé, no lugar da linha das teclas.
	var i_salvar := _linha_com(lista, "Salvar")
	_conferir(i_salvar >= 0, "o menu do Esc não tem a linha de salvar")
	if i_salvar >= 0:
		menu._cursor = i_salvar
		menu._fazer()
		await _frames(2)
		var recado: String = (_achar(menu, "Rodape") as Label).text
		_conferir(not recado.to_lower().contains("andar"),
			"salvar não devolveu recado: o rodapé continuou com as teclas ('%s')" % recado)
		_conferir(recado.to_lower().contains("vaga") or recado.to_lower().contains("salvar"),
			"o recado de salvar não fala de vaga nem de salvar: '%s'" % recado)

	# --- 4d. AS DUAS SAÍDAS FICAM EMBAIXO, EM DESTAQUE ------------------------
	#
	# "O botão de voltar ao MENU INICIAL e SAIR DO JOGO também pode voltar a ser
	# como era, tendo um destaque no MENU ESC." Sair do vale não é do mesmo tipo
	# que trocar o volume: elas são as duas últimas, separadas por um filete, e
	# de outra cor.
	var botoes: Array[Button] = []
	for filho in lista.get_children():
		if filho is Button:
			botoes.append(filho as Button)
	_conferir(botoes.size() >= 2, "o menu tem menos de duas linhas")
	if botoes.size() >= 2:
		_conferir(botoes[botoes.size() - 2].text.contains("menu inicial"),
			"a penúltima linha não é 'Voltar ao menu inicial': '%s'" % botoes[botoes.size() - 2].text)
		_conferir(botoes[botoes.size() - 1].text.contains("Sair"),
			"a última linha não é 'Sair do jogo': '%s'" % botoes[botoes.size() - 1].text)
		var cor_saida: Color = botoes[botoes.size() - 1].get_theme_color("font_color")
		var cor_comum: Color = botoes[0].get_theme_color("font_color")
		_conferir(cor_saida != cor_comum,
			"as linhas de saída estão da mesma cor das outras: sem destaque nenhum")
	var filetes := 0
	for filho in lista.get_children():
		if not (filho is Button) and not (filho is Label):
			filetes += 1
	_conferir(filetes > 0,
		"não há separação entre as linhas de ajuste e as de saída: elas viram a mesma lista")

	# --- 5. OS ATALHOS DO HUD TÊM DICAS --------------------------------------
	# O commit 8413ae7 reintroduziu a coluna direita, incluindo missões.
	# O menu continua completo; a coluna tem de explicar cada atalho ao mouse.
	var hud = jogo.get("hud")
	_conferir(hud != null, "não achei o HUD")
	if hud != null:
		var atalhos = load("res://scripts/prototipo_3d/atalhos.gd")
		# O relógio saiu da coluna (#177): o controle do tempo é o relógio central.
		var teclas_da_coluna := {3: "mapa", 5: "camera", 9: "painel"}
		_conferir(hud._corner_nodes.size() == 20, "faltam atalhos ou dicas na coluna do HUD")
		for i in range(0, hud._corner_nodes.size() - 1, 2):
			var canto: Control = hud._corner_nodes[i]
			var dica: Control = hud._corner_nodes[i + 1]
			var botoes_canto: Array[Node] = canto.find_children("*", "Button", true, false)
			var rotulos: Array[Node] = dica.find_children("*", "Label", true, false)
			var marcas: Array[Node] = canto.find_children("TeclaDeAtalho", "Label", true, false)
			var acao: String = str(teclas_da_coluna.get(i >> 1, ""))
			if acao.is_empty():
				_conferir(marcas.is_empty(), "botão sem tecla mostra atalho inexistente")
			else:
				_conferir(marcas.size() == 1, "botão de %s não mostra a tecla" % acao)
				if marcas.size() == 1:
					_conferir((marcas[0] as Label).text == atalhos.letra(acao),
						"tecla de %s não corresponde ao atalho configurado" % acao)
					_conferir((marcas[0] as Label).mouse_filter == Control.MOUSE_FILTER_IGNORE,
						"a dica de %s captura o clique do botão" % acao)
			_conferir(botoes_canto.size() == 1 and rotulos.size() == 1, "atalho perdeu botão ou rótulo")
			if botoes_canto.size() == 1 and rotulos.size() == 1:
				_conferir(not (rotulos[0] as Label).text.is_empty(), "atalho ficou sem descrição")
				botoes_canto[0].mouse_entered.emit()
				_conferir(dica.visible, "o mouse não revela a descrição do atalho")
				botoes_canto[0].mouse_exited.emit()
				_conferir(not dica.visible, "a descrição fica presa ao retirar o mouse")

	# --- 6. CABE NA JANELA ---------------------------------------------------
	var caixa := _achar(menu, "Caixa") as Control
	_conferir(caixa != null, "não achei a caixa do menu")
	if caixa != null:
		var quadro := caixa.get_global_rect()
		var janela: Vector2 = caixa.get_viewport_rect().size
		_conferir(quadro.size.x > 300.0 and quadro.size.y > 300.0,
			"a caixa do menu tem %s: pequena demais para dez linhas" % str(quadro.size))
		_conferir(quadro.position.x >= -1.0 and quadro.position.y >= -1.0
				and quadro.end.x <= janela.x + 1.0 and quadro.end.y <= janela.y + 1.0,
			"o menu está fora da janela: %s numa tela de %s" % [str(quadro), str(janela)])

	# --- 7. O RELÓGIO DIZ A ESCOLHA DO JOGADOR, E PARAR AVISA ---------------
	#
	# "O relógio parado no MENU não tá funcionando para voltar a fazer o tempo
	# correr. Por padrão o relógio deve estar funcionando e se o jogador tentar
	# desabilitar o relógio, deve informar que isso fará ele perder as
	# conquistas dali para frente."
	var dia := root.get_node("/root/Dia")
	var i_relogio := _linha_com(lista, "Relógio:")
	_conferir(i_relogio >= 0, "não achei a linha do relógio")
	if i_relogio >= 0:
		_conferir(not dia.relogio_alterado, "a partida já começou com o relógio marcado como parado")
		var texto_relogio: String = (_lista_de(menu).get_child(i_relogio) as Button).text
		_conferir(texto_relogio.contains("andando"),
			"com o menu aberto e o relógio do jogador andando, a linha diz '%s'" % texto_relogio)
		# Apertar abre a CAIXA DE CONFIRMAÇÃO, que fala das conquistas.
		menu._cursor = i_relogio
		menu._fazer()
		await _frames(2)
		_conferir(menu.perguntando(), "parar o relógio não pediu confirmação")
		var pergunta := _achar(menu, "Pergunta")
		var texto_da_pergunta: String = (_achar(pergunta, "Texto") as Label).text if pergunta != null else ""
		_conferir(texto_da_pergunta.contains("conquistas"),
			"a confirmação de parar o relógio não fala das conquistas: '%s'" % texto_da_pergunta)
		_conferir(not dia.relogio_alterado, "o relógio parou antes de o jogador confirmar")
		# O Esc desiste — da pergunta, e não do menu.
		var esc_da_pergunta := InputEventKey.new()
		esc_da_pergunta.physical_keycode = KEY_ESCAPE
		esc_da_pergunta.pressed = true
		Input.parse_input_event(esc_da_pergunta)
		await _frames(3)
		_conferir(not menu.perguntando() and menu.aberto, "o Esc na confirmação não voltou ao menu")
		_conferir(not dia.relogio_alterado and (_lista_de(menu).get_child(i_relogio) as Button).text.contains("andando"),
			"desistir da confirmação parou o relógio mesmo assim")
		# Confirmar: para, e marca a partida.
		menu._cursor = i_relogio
		menu._fazer()
		await _frames(2)
		menu._responder(true)
		await _frames(2)
		_conferir(dia.relogio_alterado, "parar o relógio não marcou a partida (relogio_alterado)")
		# "...desde que tenha o aviso, a confirmação e a alteração no backlog do
		# save": a parada entra no registro do relógio.
		_conferir(not dia.registro_do_relogio.is_empty()
				and str(dia.registro_do_relogio[-1].get("o_que", "")) == "parou",
			"parar o relógio não entrou no registro dele: %s" % str(dia.registro_do_relogio))
		texto_relogio = (_lista_de(menu).get_child(i_relogio) as Button).text
		_conferir(texto_relogio.contains("parado"), "o relógio parou e a linha diz '%s'" % texto_relogio)
		# Fechar devolve o vale andando e o relógio parado, como o jogador pediu.
		jogo.telas.fechar_tudo()
		await _frames(2)
		_conferir(not paused, "fechar o menu deixou o vale parado")
		_conferir(dia.pausado, "o jogador parou o relógio e ele voltou andando ao fechar o menu")
		# E religar funciona, sem pedir nada.
		jogo.telas.abrir("menu_pausa")
		await _frames(2)
		menu._cursor = i_relogio
		menu._fazer()
		await _frames(2)
		jogo.telas.fechar_tudo()
		await _frames(2)
		_conferir(not dia.pausado, "religar o relógio pelo menu não fez o tempo voltar a correr")
		_conferir(dia.relogio_alterado, "religar o relógio apagou a marca: 'dali para frente' não volta")
		_conferir(str(dia.registro_do_relogio[-1].get("o_que", "")) == "voltou",
			"religar o relógio não entrou no registro dele: %s" % str(dia.registro_do_relogio))
		_conferir(jogo.estado_para_salvar().get("relogio_alterado", false) == true,
			"a marca do relógio não vai para o save")
		_conferir((jogo.estado_para_salvar().get("registro_do_relogio", []) as Array).size() == dia.registro_do_relogio.size(),
			"o registro do relógio não vai para o save")
		dia.relogio_alterado = false

		# A TRANCA DO AJUSTAR: bloqueado, a linha não para o tempo e diz por quê.
		# Mexe-se no campo, e não no `definir_pausa_no_jogo`, para o portão não
		# gravar a preferência do jogador.
		dia.pausa_no_jogo = false
		var registro_antes: int = dia.registro_do_relogio.size()
		jogo.telas.abrir("menu_pausa")
		await _frames(2)
		var com_tranca: String = (_lista_de(menu).get_child(i_relogio) as Button).text
		_conferir(com_tranca.contains("bloqueada"), "com a pausa bloqueada, a linha do relógio diz '%s'" % com_tranca)
		menu._cursor = i_relogio
		menu._fazer()
		await _frames(2)
		_conferir(not menu.perguntando(), "com a pausa bloqueada, a linha ainda pergunta se pode parar")
		_conferir(str(menu.get("_aviso")).contains("bloqueado"),
			"com a pausa bloqueada, a linha não diz por que não parou: '%s'" % str(menu.get("_aviso")))
		jogo.telas.fechar_tudo()
		await _frames(2)
		_conferir(not dia.pausado and not dia.relogio_alterado and dia.registro_do_relogio.size() == registro_antes,
			"com a pausa bloqueada, a linha do relógio parou o tempo mesmo assim")
		dia.pausa_no_jogo = true

	# --- 8. LINHA QUE FECHA O MENU DEVOLVE O VALE ----------------------------
	#
	# "Quando abri MENU > Controles, ele travou o jogo." As linhas que fecham o
	# menu o fechavam por dentro, sem avisar o dono das telas, e a árvore ficava
	# pausada. Os Ajustes pioravam: guardavam o relógio parado pelo menu como
	# se fosse a escolha do jogador.
	jogo.telas.abrir("menu_pausa")
	await _frames(2)
	var i_voltar := _linha_com(_lista_de(menu), "Voltar ao vale")
	if i_voltar >= 0:
		menu._cursor = i_voltar
		menu._fazer()
		await _frames(2)
		_conferir(not menu.aberto, "'Voltar ao vale' não fechou o menu")
		_conferir(not paused, "'Voltar ao vale' fechou o menu e deixou o vale parado")
	jogo.telas.abrir("menu_pausa")
	await _frames(2)
	var i_ajustes := _linha_com(_lista_de(menu), "Ajustes")
	if i_ajustes >= 0:
		menu._cursor = i_ajustes
		menu._fazer()
		await _frames(2)
		_conferir(paused, "os Ajustes abriram com o vale andando atrás")
		jogo.hud.close_settings()
		await _frames(2)
		_conferir(not paused, "fechar os Ajustes abertos pelo menu deixou o vale parado")
		_conferir(not dia.pausado, "fechar os Ajustes abertos pelo menu deixou o relógio parado")

	# --- 9. CONTROLES É TELA, E O ESC VOLTA AO MENU --------------------------
	jogo.telas.abrir("menu_pausa")
	await _frames(2)
	var i_controles := _linha_com(_lista_de(menu), "Controles")
	_conferir(i_controles >= 0, "não achei a linha dos controles")
	if i_controles >= 0:
		menu._cursor = i_controles
		menu._fazer()
		await _frames(2)
		var controles = jogo.get("tela_controles")
		_conferir(controles != null and controles.aberta, "'Controles' não abriu a tela de controles")
		_conferir(jogo.telas.aberta() == "controles", "a tela de controles não é do dono das telas")
		_conferir(paused, "a tela de controles abriu com o vale andando atrás")
		if controles != null and controles.aberta:
			_conferir(controles._teclas.size() == load("res://scripts/prototipo_3d/atalhos.gd").DEFINICOES.size(),
				"a tela de controles não lista todos os atalhos")
			var esc := InputEventKey.new()
			esc.physical_keycode = KEY_ESCAPE
			esc.pressed = true
			# Esperando a tecla nova, o Esc só desiste dela — e a tela fica.
			# (Sem trocar letra de verdade: o portão roda nas preferências do
			# jogador, e elas não são dele.)
			controles._esperar(controles._acoes[0])
			Input.parse_input_event(esc)
			await _frames(3)
			_conferir(controles.aberta and controles._esperando == "",
				"o Esc esperando a tecla não desistiu dela, ou fechou a tela de controles")
			Input.parse_input_event(esc)
			await _frames(3)
			_conferir(not controles.aberta and menu.aberto, "o Esc nos controles não voltou ao menu do Esc")
			_conferir(paused, "voltar dos controles ao menu soltou o vale")

	jogo.telas.fechar_tudo()
	await _frames(2)
	_conferir(not menu.aberto, "fechar tudo deixou o menu do Esc aberto")
	_conferir(not paused, "fechar o menu do Esc deixou o vale parado")

	# O ? abre a tela modal de Controles pelo gestor do vale.
	hud.controls_requested.emit()
	await _frames(2)
	_conferir(hud.controls_open() and jogo.telas.aberta() == "controles" and jogo.tela_controles.aberta and paused,
		"o ? não abriu Controles como modal pausado")
	var caixa_controles := _achar(jogo.tela_controles, "Caixa") as Control
	_conferir(caixa_controles != null, "o modal de Controles não tem caixa")
	if caixa_controles != null:
		var quadro_controles := caixa_controles.get_global_rect()
		var janela_controles := caixa_controles.get_viewport_rect().size
		_conferir(absf(quadro_controles.get_center().x - janela_controles.x * 0.5) < 2.0
			and absf(quadro_controles.get_center().y - janela_controles.y * 0.5) < 2.0,
			"Controles ainda aparece na lateral, fora do centro")
	jogo.tela_controles.voltar_pedido.emit()
	await _frames(2)
	_conferir(not jogo.tela_controles.aberta and menu.aberto and paused,
		"Voltar nos Controles não retornou ao menu do Esc")
	jogo.telas.fechar_tudo()
	await _frames(2)
	_conferir(not hud.controls_open() and not paused,
		"fechar Controles deixou o jogo travado")

	jogo.telas.abrir("menu_pausa")
	await _frames(2)
	var controles_no_menu := _linha_com(_achar(menu, "Linhas") as VBoxContainer, "Controles")
	_conferir(controles_no_menu >= 0, "o menu perdeu a linha de Controles")
	if controles_no_menu >= 0:
		menu._cursor = controles_no_menu
		menu._fazer()
		await _frames(2)
		_conferir(hud.controls_open() and not menu.aberto and paused,
			"a linha Controles do menu não abre o modal")
		jogo.telas.fechar_tudo()
		await _frames(2)
		_conferir(not paused, "fechar Controles pelo gestor não retomou o jogo")

	# A velocidade Parada vem das preferências; o relógio precisa retomá-la mesmo
	# quando a opção de pausar pelo botão estiver bloqueada.
	var dia_retomada = root.get_node("/root/Dia")
	dia_retomada.definir_pausa_no_jogo(false)
	dia_retomada.definir_velocidade(0)
	dia_retomada.pausado = false
	hud._update_clock_hint()
	_conferir(hud._clock_hint.contains("Retomar"),
		"o relógio parado não indica que o botão pode retomar o tempo")
	hud._clock_button.pressed.emit()
	_conferir(dia_retomada.velocidade == 2 and not dia_retomada.pausado,
		"clicar no relógio não retomou a velocidade normal")
	var hora_antes: float = dia_retomada.hora
	await _frames(5)
	_conferir(dia_retomada.hora > hora_antes, "o horário não avançou depois de clicar no relógio")
	_conferir(not dia_retomada.pausado and not paused,
		"o clique no relógio deixou a partida pausada")

	_fechar()


## A lista é refeita a cada redesenho; pega a de agora.
func _lista_de(menu: Node) -> VBoxContainer:
	return _achar(menu, "Linhas") as VBoxContainer


func _linha_com(lista: VBoxContainer, pedaco: String) -> int:
	for i in lista.get_child_count():
		var filho := lista.get_child(i)
		if filho is Button and (filho as Button).text.contains(pedaco):
			return i
	return -1


func _achar(raiz: Node, nome: String) -> Node:
	for no in raiz.find_children(nome, "", true, false):
		return no
	return null


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("MENU_PAUSA_OK: o Esc abre o menu com o vale parado; as linhas que eram a coluna de ícones estão lá com ícone E estado escrito, apertar uma troca as duas coisas junto, salvar devolve recado como no 2D, as duas saídas ficam embaixo em destaque, os atalhos do canto têm dicas, e o menu cabe na janela")
	else:
		print("menu do Esc: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame


func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
