extends SceneTree
## Confere que TODA TELA DEVOLVE A CÂMERA COMO A ACHOU, e para o vale atrás dela.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/camera_volta.gd
##
## Este portão existe porque o mesmo defeito apareceu QUATRO VEZES, em quatro
## lugares diferentes, e cada vez foi consertado só aquele:
##
##   1. perder o foco da janela trocava o modo para sempre;
##   2. o Esc, que soltava o mouse em vez de abrir o menu;
##   3. o mapa, que soltava o cursor ao abrir e não devolvia ao fechar;
##   4. o painel do J, que chegou depois e repetiu o número 3 inteiro.
##
## Os quatro têm a mesma forma: uma tela precisa do cursor visível — menu que
## não se clica e mapa que não se navega não servem —, solta ele, e esquece de
## devolver o modo que o jogador escolheu. Consertar caso a caso é garantir a
## quinta vez, e a quarta aconteceu DEPOIS de este portão existir, num arquivo
## que ele ainda não conhecia. Daí a lista de telas: acrescentar uma é três
## linhas, e quem não a acrescentar vai descobrir pelo jogador.
##
## A segunda pergunta é a da PAUSA, e vem de um pedido: "quando se abre
## qualquer menu, o jogo atrás deve ser pausado". Cada tela diz aqui se pausa,
## e o mapa é a exceção declarada — nele o jogador para e o mundo continua, de
## propósito, porque é vista do vale ao vivo e não menu.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("CAMERA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK,
		"a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(3)

	var jogo := current_scene
	var player = jogo.get("player")
	var hud = jogo.get("hud")
	_conferir(player != null and hud != null, "não achei o jogador ou o HUD")
	if player == null or hud == null:
		_fechar()
		return

	# Cada tela diz como se abre, como se fecha, e se ela PARA O VALE atrás
	# dela. Acrescentar tela nova aqui são três linhas — e é o que faz este
	# portão valer para o futuro, e não só para os defeitos que o criaram.
	var telas: Array = [
		{
			"nome": "mapa",
			"abrir": func(): jogo._toggle_map(),
			"fechar": func(): jogo._toggle_map(),
			# A EXCEÇÃO DECLARADA: o mapa é vista do vale ao vivo, não menu. O
			# jogador para, o mundo continua — moradores andando, relógio
			# correndo. Está escrito no `_toggle_map`, e é de propósito.
			"pausa": false,
		},
		{
			"nome": "mochila",
			"abrir": func(): jogo.telas.abrir("mochila"),
			"fechar": func(): jogo.telas.fechar_tudo(),
			"pausa": true,
		},
		{
			"nome": "almanaque",
			"abrir": func(): jogo.telas.abrir("almanaque"),
			"fechar": func(): jogo.telas.fechar_tudo(),
			"pausa": true,
		},
		{
			"nome": "painel (J)",
			"abrir": func(): jogo.telas.abrir("painel"),
			"fechar": func(): jogo.telas.fechar_tudo(),
			"pausa": true,
		},
		{
			"nome": "menu (confirmação)",
			"abrir": func(): jogo._ask_return_to_menu(),
			# FECHA PELO HUD, e não chamando o `_on_menu_cancelled` direto.
			#
			# Chamar o tratador à mão devolvia a câmera e DEIXAVA A CAIXA
			# ABERTA — e aí a segunda volta deste laço pedia o menu, o
			# `_ask_return_to_menu` recusava por já haver caixa, e nada
			# pausava. O portão só percebeu quando passou a perguntar da
			# pausa; pela câmera sozinha ele passava verde com a tela
			# presa. Fechar como o jogador fecha é o que mede o jogo.
			"fechar": func(): hud._close_menu_confirm(false),
			"pausa": true,
		},
	]

	# NOS DOIS MODOS. O defeito aparecia para quem jogava no modo livre, mas a
	# promessa é simétrica: quem escolheu arrastar também não pode voltar
	# diferente.
	print("")
	for travada_no_inicio in [false, true]:
		var modo := "arrastar" if travada_no_inicio else "livre"
		for tela: Dictionary in telas:
			player.set_camera_locked(travada_no_inicio)
			await _frames(2)
			var antes: bool = player.camera_travada()
			_conferir(antes == travada_no_inicio,
				"não consegui pôr a câmera em '%s' antes de abrir %s" % [modo, tela["nome"]])

			(tela["abrir"] as Callable).call()
			await _frames(3)
			# COM A TELA ABERTA O CURSOR TEM DE ESTAR VISÍVEL. É a outra metade:
			# devolver o modo não pode ser conseguido não soltando o cursor.
			_conferir(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
				"%s abriu com o cursor preso (modo '%s'): não se clica nela" % [tela["nome"], modo])

			# E O VALE PARA ATRÁS DELA, quando a tela promete parar. Era a
			# outra metade do pedido, e a que passou despercebida: o almanaque
			# abria com o mundo andando por baixo, e ninguém mediu isso porque
			# este portão só perguntava da câmera.
			_conferir(paused == bool(tela["pausa"]),
				"%s (modo '%s') abriu com o vale %s, e devia abrir %s"
					% [tela["nome"], modo,
						"andando" if not paused else "parado",
						"parado" if tela["pausa"] else "andando"])

			(tela["fechar"] as Callable).call()
			await _frames(3)
			_conferir(not paused,
				"%s (modo '%s') fechou e deixou o vale parado" % [tela["nome"], modo])
			var depois: bool = player.camera_travada()
			_conferir(depois == antes,
				"%s (modo '%s') devolveu a câmera em '%s'"
					% [tela["nome"], modo, "arrastar" if depois else "livre"])
			print("  %-20s modo '%s': %s" % [tela["nome"], modo,
				"ok" if depois == antes else "DEVOLVEU DIFERENTE"])

	# --- UMA TELA DE CADA VEZ, E A CÂMERA INTEIRA DEPOIS DE TROCAR -----------
	#
	# "Quando tava no Menu de missão, apertei o Menu do Almanaque e ele abriu
	# ATRÁS do da missão" — e, logo depois, "quando sai do almanaque, a tela
	# tava destravada". As duas queixas são a mesma coisa.
	#
	# Enquanto cada tela cuidava da própria tecla, abrir a segunda não fechava a
	# primeira, e as duas escreviam na MESMA gaveta do modo de câmera: a
	# primeira guardava "travada", a segunda guardava o que achava — já solta —,
	# e fechar devolvia solta. Não adiantava consertar a devolução: o defeito
	# era o empilhamento.
	#
	# Aqui se abre uma, se abre OUTRA por cima, e se cobra que a primeira tenha
	# fechado e que a câmera volte como estava no começo de tudo.
	print("")
	var com_tecla := ["mochila", "almanaque", "painel"]
	for modo_travado in [false, true]:
		for primeira in com_tecla:
			for segunda in com_tecla:
				if primeira == segunda:
					continue
				jogo.telas.fechar_tudo()
				player.set_camera_locked(modo_travado)
				await _frames(2)
				jogo.telas.abrir(primeira)
				await _frames(2)
				if jogo.telas.aberta() != primeira:
					continue          # tela que se recusa a abrir agora (mapa aberto etc.)
				jogo.telas.abrir(segunda)
				await _frames(2)
				var agora: String = jogo.telas.aberta()
				_conferir(agora == segunda,
					"com '%s' aberta, pedir '%s' deixou '%s' na tela"
						% [primeira, segunda, agora if agora != "" else "nada"])
				jogo.telas.fechar_tudo()
				await _frames(2)
				_conferir(jogo.telas.aberta() == "",
					"fechar tudo deixou '%s' aberta" % jogo.telas.aberta())
				_conferir(player.camera_travada() == modo_travado,
					"abrir '%s', trocar para '%s' e fechar devolveu a câmera em '%s'"
						% [primeira, segunda, "arrastar" if player.camera_travada() else "livre"])
				_conferir(not paused, "depois de fechar tudo o vale continuou parado")

	# --- A PLAQUINHA DE NOME NÃO FICA POR CIMA DA TELA -----------------------
	#
	# "Quando abro os MENUs, o nome do Pedro tá sobrescrevendo os MENUs."
	#
	# As plaquinhas moram no mesmo Control do HUD que o almanaque e a barra de
	# mão, e entram DEPOIS deles — filho mais novo desenha por cima.
	#
	# MEDE O AVISO, E NÃO O PIXEL, e isso é escolha com razão. A primeira versão
	# contava plaquinhas visíveis com a tela aberta e PASSAVA COM O CONSERTO
	# ARRANCADO: em headless nenhuma fica visível, porque o morador que fala
	# esconde o próprio rótulo (`npc.gd.mostrar_balao`) e os que não falam andam
	# de volta ao posto no meio da conta. Tentei construir a cena — morador
	# calado, posto na frente da câmera, rótulo aceso — e não se sustenta com o
	# vale andando.
	#
	# Verificação que não pode falhar é pior que verificação nenhuma. O que pode
	# quebrar, e o que quebrou, é o AVISO: o dono das telas chamar
	# `placas.permitir(false)` ao abrir e `true` ao fechar. É isso que se mede —
	# e arrancar a ligação reprova aqui.
	print("")
	jogo.telas.fechar_tudo()
	await _frames(2)
	_conferir(jogo.placas != null, "o vale não montou as plaquinhas de nome")
	if jogo.placas != null:
		_conferir(jogo.placas._permitido,
			"com o vale livre as plaquinhas já estavam proibidas")
		for qual in ["mochila", "almanaque", "painel", "menu_pausa"]:
			jogo.telas.abrir(qual)
			await _frames(3)
			if jogo.telas.aberta() != qual:
				continue
			_conferir(not jogo.placas._permitido,
				"'%s' abriu e as plaquinhas de nome continuaram permitidas: elas desenham por cima" % qual)
			jogo.telas.fechar_tudo()
			await _frames(3)
			_conferir(jogo.placas._permitido,
				"depois de fechar '%s' as plaquinhas não voltaram a ser permitidas" % qual)
		print("  plaquinhas: proibidas nas cinco telas e liberadas ao fechar")

	# --- E PERDER O FOCO NÃO TROCA O MODO ------------------------------------
	#
	# O primeiro dos quatro defeitos. Soltar o cursor ao perder o foco é certo —
	# mouse preso numa janela que não está na frente é mouse preso num jogo que
	# o jogador não está vendo — mas o MODO tem de sobreviver.
	for travada_no_inicio in [false, true]:
		player.set_camera_locked(travada_no_inicio)
		await _frames(2)
		player.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		await _frames(2)
		player.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		await _frames(2)
		_conferir(player.camera_travada() == travada_no_inicio,
			"perder e recuperar o foco trocou o modo (era '%s')"
				% ["arrastar" if travada_no_inicio else "livre"])

	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("CAMERA_OK: as cinco telas abrem com o cursor livre, param o vale atrás delas (menos o mapa, que é vista ao vivo) e devolvem o modo que acharam nos dois modos; abrir uma fecha a outra, e trocar de tela não perde a câmera; e perder o foco não troca nada")
	else:
		print("câmera: %d falha(s)" % falhas)
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
