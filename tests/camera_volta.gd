extends SceneTree
## Confere que TODA TELA DEVOLVE A CÂMERA COMO A ACHOU.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/camera_volta.gd
##
## Este portão existe porque o mesmo defeito apareceu TRÊS VEZES, em três
## lugares diferentes, e cada vez eu consertei só aquele:
##
##   1. perder o foco da janela trocava o modo para sempre;
##   2. o Esc, que soltava o mouse em vez de abrir o menu;
##   3. o mapa, que soltava o cursor ao abrir e não devolvia ao fechar.
##
## Os três têm a mesma forma: uma tela precisa do cursor visível — menu que não
## se clica e mapa que não se navega não servem —, solta ele, e esquece de
## devolver o modo que o jogador escolheu. Consertar caso a caso é garantir a
## quarta vez.
##
## Então a pergunta aqui é sobre TODAS as telas de uma vez, e nos dois modos:
## abrir e fechar qualquer uma tem de terminar como começou. O que este portão
## cobra não é o conserto de hoje — é que o próximo lugar que soltar o cursor
## seja obrigado a devolvê-lo.

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

	# Cada tela é um par: como abrir e como fechar. Acrescentar tela nova aqui é
	# uma linha — e é o que faz este portão valer para o futuro, e não só para
	# os três defeitos que o criaram.
	var telas: Array = [
		{
			"nome": "mapa",
			"abrir": func(): jogo._toggle_map(),
			"fechar": func(): jogo._toggle_map(),
		},
		{
			"nome": "mochila",
			"abrir": func(): hud.barra_de_mao()._abrir_ou_fechar_a_mochila(),
			"fechar": func(): hud.barra_de_mao()._abrir_ou_fechar_a_mochila(),
		},
		{
			"nome": "almanaque",
			"abrir": func(): hud.almanaque().abrir(),
			"fechar": func(): hud.almanaque().fechar(),
		},
		{
			"nome": "menu (confirmação)",
			"abrir": func(): jogo._ask_return_to_menu(),
			"fechar": func(): jogo._on_menu_cancelled(),
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

			(tela["fechar"] as Callable).call()
			await _frames(3)
			var depois: bool = player.camera_travada()
			_conferir(depois == antes,
				"%s (modo '%s') devolveu a câmera em '%s'"
					% [tela["nome"], modo, "arrastar" if depois else "livre"])
			print("  %-20s modo '%s': %s" % [tela["nome"], modo,
				"ok" if depois == antes else "DEVOLVEU DIFERENTE"])

	# --- E PERDER O FOCO NÃO TROCA O MODO ------------------------------------
	#
	# O primeiro dos três defeitos. Soltar o cursor ao perder o foco é certo —
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
		print("CAMERA_OK: mapa, mochila, almanaque e menu abrem com o cursor livre e devolvem o modo que acharam, nos dois modos; e perder o foco não troca nada")
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
