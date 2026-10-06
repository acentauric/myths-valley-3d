extends SceneTree
## PLAQUINHAS DE NOME E BALÕES SÓ DE PERTO, E UM BALÃO POR VEZ (#90).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/placas_e_baloes.gd
##
## Na live os nomes de toda a praça apareciam de longe (22 u) e dois balões
## saíam ao mesmo tempo. A equipe: nome e balão só por proximidade, e uma regra
## de prioridade — quem fala com você > fala de missão > saudação de quem passa.
##
##   1. A PLAQUINHA some além de PLACA_LONGE, aparece inteira a PLACA_PERTO, e
##      esmaece entre as duas.
##   2. O BALÃO some além do alcance dele.
##   3. UM BALÃO POR VEZ: a saudação de quem passa cai quando outro morador fala
##      com você pelo E; e com alguém falando, quem passa não cumprimenta.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("PLACAS_E_BALOES_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	var vale = current_scene
	var jogador = vale.player
	var mundo = vale.world
	var placas = vale.get("placas")
	var tonho = vale._achar_morador("tonho")
	var candinha = vale._achar_morador("candinha")
	_conferir(placas != null and tonho != null and candinha != null, "o vale não tem as plaquinhas, o Tonho ou a Dona Candinha")
	if placas == null or tonho == null or candinha == null:
		_fechar()
		return
	root.get_node("/root/Dia").pausado = true
	var estilo = root.get_node("/root/Estilo")
	estilo.mostrar_nomes = true
	var placa: Control = (placas.get("_placas") as Dictionary).get(tonho)
	_conferir(placa != null, "o Tonho não tem plaquinha")
	if placa == null:
		_fechar()
		return

	# --- 1. A PLAQUINHA SÓ DE PERTO -----------------------------------------------
	var longe: float = float(placas.PLACA_LONGE)
	var perto: float = float(placas.PLACA_PERTO)
	for distancia: float in [longe + 2.0, perto - 1.0, (longe + perto) * 0.5]:
		_pôr_o_jogador_a(jogador, mundo, tonho, distancia)
		await _quadros(4)
		if distancia > longe:
			_conferir(not placa.visible, "a %.0f u a plaquinha do Tonho ainda aparece" % distancia)
		elif distancia < perto:
			_conferir(placa.visible and placa.modulate.a > 0.95, "a %.0f u a plaquinha do Tonho não aparece inteira (visível %s, alfa %.2f)" % [distancia, str(placa.visible), placa.modulate.a])
		else:
			_conferir(placa.visible and placa.modulate.a > 0.05 and placa.modulate.a < 0.95, "entre perto e longe a plaquinha não esmaece (visível %s, alfa %.2f)" % [str(placa.visible), placa.modulate.a])

	# --- 2. O BALÃO SÓ DE PERTO --------------------------------------------------------
	# O balão mede a distância da CÂMERA, que persegue o jogador aos poucos: a
	# espera é em segundo de relógio, até ela chegar.
	var alcance: float = float(tonho.balao.ALCANCE)
	tonho.mostrar_balao("Opa, tudo certo?", 30.0)
	_pôr_o_jogador_a(jogador, mundo, tonho, alcance + 6.0)
	await _esperar(1.2)
	_conferir(not tonho.balao.a_vista(), "a %.0f u o balão do Tonho ainda aparece (câmera a %.1f)" % [alcance + 6.0, _camera_ate(tonho)])
	_pôr_o_jogador_a(jogador, mundo, tonho, 4.0)
	await _esperar(1.2)
	_conferir(tonho.balao.a_vista(), "a 4 u o balão do Tonho não aparece (câmera a %.1f)" % _camera_ate(tonho))
	tonho.balao.esconder()

	# --- 3. UM BALÃO POR VEZ ------------------------------------------------------------
	# A Dona Candinha ao lado do Tonho, os dois perto do jogador.
	candinha.global_position = tonho.global_position + Vector3(2.0, 0.0, 0.0)
	candinha.velocity = Vector3.ZERO
	_pôr_o_jogador_a(jogador, mundo, tonho, 2.5)
	await _quadros(2)
	tonho.saudar()
	await _quadros(2)
	_conferir(tonho.balao.visible, "a saudação do Tonho não abriu balão")
	_conferir(not candinha.pode_falar(), "com o Tonho cumprimentando, a Dona Candinha ainda tem a palavra livre para cumprimentar")
	candinha.conversar()
	await _quadros(2)
	_conferir(candinha.balao.visible, "a conversa do E com a Dona Candinha não abriu balão")
	_conferir(not tonho.balao.visible, "a conversa do E não calou a saudação do Tonho: dois balões")

	# --- 4. O BALÃO POR CIMA DA PLAQUINHA (#103) ------------------------------------
	# "A camada do chat deve ser acima da camada do nome do NPC": a plaquinha de um
	# morador não pode cobrir o balão de outro — ela mora numa camada abaixo.
	var camada_da_placa: CanvasLayer = placa.get_canvas_layer_node()
	var camada_do_balao: CanvasLayer = tonho.balao.get_canvas_layer_node()
	_conferir(camada_da_placa != null and camada_do_balao != null and camada_da_placa.layer < camada_do_balao.layer,
		"a plaquinha (camada %s) não fica abaixo do balão (camada %s)" % [str(camada_da_placa.layer) if camada_da_placa != null else "?", str(camada_do_balao.layer) if camada_do_balao != null else "?"])
	_fechar()


## Quadros por `segundos` de relógio: a câmera suave anda com o tempo, não com o quadro.
func _esperar(segundos: float) -> void:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		await process_frame


func _camera_ate(morador) -> float:
	var camera := root.get_viewport().get_camera_3d()
	return camera.global_position.distance_to(morador.global_position) if camera != null else -1.0


func _pôr_o_jogador_a(jogador, mundo, morador, distancia: float) -> void:
	var de: Vector3 = morador.global_position
	var onde: Vector3 = mundo.ground_position(de + Vector3(0.0, 0.0, distancia), 0.1)
	jogador.teleportar(onde, atan2(de.x - onde.x, de.z - onde.z))


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("PLACAS_E_BALOES_OK: a plaquinha de nome some longe, aparece perto e esmaece entre; o balão só aparece ao alcance; a conversa do E cala a saudação de quem passa, e ninguém cumprimenta por cima de uma fala")
	else:
		print("placas_e_baloes: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
