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
			"abrir": func(): hud.barra_de_mao()._abrir_ou_fechar_a_mochila(),
			"fechar": func(): hud.barra_de_mao()._abrir_ou_fechar_a_mochila(),
			"pausa": true,
		},
		{
			"nome": "almanaque",
			"abrir": func(): hud.almanaque().abrir(),
			"fechar": func(): hud.almanaque().fechar(),
			"pausa": true,
		},
		{
			"nome": "painel (J)",
			"abrir": func(): jogo.abrir_o_painel(),
			"fechar": func(): jogo.painel.fechar(),
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
		print("CAMERA_OK: mapa, mochila, almanaque, painel e menu abrem com o cursor livre, param o vale atrás delas (menos o mapa, que é vista ao vivo) e devolvem o modo que acharam, nos dois modos; e perder o foco não troca nada")
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
