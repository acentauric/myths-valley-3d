extends SceneTree
## NA CENA SÓ FICAM O BALÃO E AS TARJAS, A CÂMERA DESLIZA E O E PULA (#215).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/cena_so_com_balao.gd
##     ... -- --falsificar-interface        (o portão TEM de reprovar: a cena sem recolher a interface)
##
## Playtest de 09/10: na chegada ao píer o painel de missão aparecia cortado pela tarja, o painel TESTANDO e a
## seta ficavam por cima da cena, e a câmera passava colada no viajante, com movimentos bruscos. Cinco perguntas:
##
##   1. O TEMPO DO PLANO e a curva são puros: a distância e o giro esticam o tempo até a velocidade média e o
##      giro caberem nos limites (com teto), e a aceleração parte e chega parada.
##   2. COM A CENA TOCANDO, a interface do vale se recolhe — o HUD (missão, relógio, barras, atalhos, minimapa,
##      barra de mão), a seta, as plaquinhas — e volta inteira no fim. Ficam as tarjas.
##   3. A CÂMERA DESLIZA: nasce onde a câmera do jogador estava, nunca chega a menos de DISTANCIA_DO_VIAJANTE do
##      corpo dele, e nenhum quadro dá salto de posição ou de giro.
##   4. O E PULA a cena (e o Esc, sem abrir o menu): os comandos que faltam correm sem espera, o Pedro chega ao
##      Tonho, a fila é solta e o passo seguinte é anunciado.
##   5. O E NÃO PULA NA HORA: antes de ESPERA_PARA_PULAR a cena segue.

const TETO_DA_CENA_S := 30.0

var falhas := 0
var falsificar := false


func _initialize() -> void:
	for argumento in OS.get_cmdline_user_args():
		if argumento == "--falsificar-interface":
			falsificar = true
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("CENA_SO_COM_BALAO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	var Cena = load("res://scripts/prototipo_3d/cena_vale.gd")

	# --- 1. O TEMPO DO PLANO E A CURVA ---------------------------------------------------------
	var curto: float = Cena.tempo_do_plano(1.2, Vector3.ZERO, Vector3(0, 0, 1), Vector3.FORWARD, Vector3.FORWARD)
	_conferir(is_equal_approx(curto, 1.2), "um plano curto e reto devia durar o pedido (1,2 s), e durou %.2f" % curto)
	var longo: float = Cena.tempo_do_plano(1.0, Vector3.ZERO, Vector3(0, 0, 12), Vector3.FORWARD, Vector3.FORWARD)
	_conferir(longo >= 12.0 / Cena.VELOCIDADE_DA_CAMERA - 0.01, "12 m em 1 s passam da velocidade da câmera: durou %.2f s" % longo)
	var giro: float = Cena.tempo_do_plano(0.5, Vector3.ZERO, Vector3(0, 0, 0.5), Vector3.FORWARD, Vector3.BACK)
	_conferir(giro >= PI / Cena.GIRO_DA_CAMERA - 0.01, "meia-volta em 0,5 s passa do giro da câmera: durou %.2f s" % giro)
	var absurdo: float = Cena.tempo_do_plano(1.0, Vector3.ZERO, Vector3(0, 0, 400), Vector3.FORWARD, Vector3.BACK)
	_conferir(absurdo <= Cena.TETO_DO_PLANO + 0.01, "o plano absurdo passou do teto (%.2f s)" % absurdo)
	_conferir(is_equal_approx(Cena._suave(0.0), 0.0) and is_equal_approx(Cena._suave(1.0), 1.0), "a curva não vai de 0 a 1")
	_conferir(Cena._suave(0.05) < 0.01 and Cena._suave(0.95) > 0.99, "a curva não parte nem chega parada (%.4f, %.4f)" % [Cena._suave(0.05), Cena._suave(0.95)])
	var anterior := -1.0
	var cresce := true
	for i in 101:
		var v: float = Cena._suave(i / 100.0)
		cresce = cresce and v >= anterior
		anterior = v
	_conferir(cresce, "a curva do plano não é crescente")

	# --- 2 e 3. A CENA TOCANDO ------------------------------------------------------------------
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(4)
	await _mundo_pronto()
	await _frames(6)
	var vale = current_scene
	var cenas = vale.get("cenas")
	var jogador = vale.player
	var pedro = vale.pedro
	var guia = pedro._cadeia
	var seta = vale.get("_seta")
	var placas = vale.get("placas")
	var hud_layer: Control = vale.hud_layer
	_conferir(cenas != null and jogador != null and pedro != null and hud_layer != null, "o vale não tem as cenas, o jogador, o Pedro ou a interface")
	if cenas == null or jogador == null or pedro == null or hud_layer == null:
		_fechar()
		return
	root.get_node("/root/Dia").pausado = true
	if falsificar:
		# A falsificação: a cena não avisa o vale, e a interface fica onde estava.
		for sinal in ["comecou", "acabou"]:
			for ligacao in cenas.get_signal_connection_list(sinal):
				cenas.disconnect(sinal, ligacao["callable"])
	var camera_do_jogador: Camera3D = jogador.get("camera")
	_conferir(hud_layer.visible, "antes da cena a interface já estava recolhida")
	var quadros: Array = []
	cenas.tocar("vista_da_praca", guia)
	var comecou := await _ate(func() -> bool: return bool(cenas.em_cena()) and cenas.camera_da_cena() != null, 3.0)
	_conferir(comecou, "a cena da vista da praça não começou")
	if comecou:
		var camera_no_inicio: Vector3 = cenas.camera_da_cena().global_position
		_conferir(camera_no_inicio.distance_to(camera_do_jogador.global_position) < 0.6, "a câmera da cena nasceu a %.2f m da câmera do jogador: foi um corte" % camera_no_inicio.distance_to(camera_do_jogador.global_position))
		var limite := Time.get_ticks_msec() + int(TETO_DA_CENA_S * 1000.0)
		var ultimo_ms := Time.get_ticks_msec()
		var ultimo_pos := camera_no_inicio
		var ultima_frente: Vector3 = -cenas.camera_da_cena().global_basis.z
		var maior_velocidade := 0.0
		var maior_giro := 0.0
		var mais_perto := INF
		var interface_recolhida := true
		var seta_recolhida := true
		var placas_recolhidas := true
		while bool(cenas.em_cena()) and Time.get_ticks_msec() < limite:
			await process_frame
			var camera: Camera3D = cenas.camera_da_cena()
			if camera == null:
				continue
			interface_recolhida = interface_recolhida and not hud_layer.visible
			seta_recolhida = seta_recolhida and (seta == null or bool(seta.oculta()))
			placas_recolhidas = placas_recolhidas and (placas == null or not bool(placas.get("_permitido")))
			var perto := Vector2(camera.global_position.x - jogador.global_position.x, camera.global_position.z - jogador.global_position.z).length()
			if camera.global_position.y < jogador.global_position.y + 2.5:
				mais_perto = minf(mais_perto, perto)
			var agora := Time.get_ticks_msec()
			# Janelas de 0,3 s: sem tela os quadros saem desiguais (um de 140 ms, outro de 10), e numa janela de 0,1 s
			# o deslize de dois quadros caía inteiro numa só, dobrando a velocidade medida.
			if agora - ultimo_ms >= 300:
				var dt := float(agora - ultimo_ms) / 1000.0
				var frente: Vector3 = -camera.global_basis.z
				maior_velocidade = maxf(maior_velocidade, camera.global_position.distance_to(ultimo_pos) / dt)
				maior_giro = maxf(maior_giro, ultima_frente.angle_to(frente) / dt)
				ultimo_ms = agora
				ultimo_pos = camera.global_position
				ultima_frente = frente
			quadros.append(perto)
		_conferir(quadros.size() > 5, "a cena da vista da praça acabou sem quadros para medir")
		_conferir(interface_recolhida, "durante a cena a interface do vale continuou à vista")
		_conferir(seta_recolhida, "durante a cena a seta da missão continuou à vista")
		_conferir(placas_recolhidas, "durante a cena as plaquinhas de nome continuaram permitidas")
		_conferir(mais_perto >= Cena.DISTANCIA_DO_VIAJANTE - 0.1, "a câmera da cena chegou a %.2f m do viajante (o mínimo é %.1f)" % [mais_perto, Cena.DISTANCIA_DO_VIAJANTE])
		_conferir(maior_velocidade <= Cena.VELOCIDADE_DA_CAMERA * 3.0, "a câmera da cena chegou a %.1f m/s (a média é no máximo %.1f)" % [maior_velocidade, Cena.VELOCIDADE_DA_CAMERA])
		_conferir(maior_giro <= 4.0, "a câmera da cena girou a %.1f rad/s: foi um corte" % maior_giro)
		print("  vista da praça: câmera a no mínimo %.1f m do viajante, no máximo %.1f m/s e %.1f rad/s" % [mais_perto, maior_velocidade, maior_giro])
	await _ate(func() -> bool: return not bool(cenas.em_cena()), 3.0)
	await _frames(3)
	_conferir(hud_layer.visible, "acabada a cena a interface do vale não voltou")
	_conferir(seta == null or not bool(seta.oculta()), "acabada a cena a seta continua escondida")
	_conferir(placas == null or bool(placas.get("_permitido")), "acabada a cena as plaquinhas não voltaram")

	# --- 5. O E NÃO PULA NA HORA, 4. O E PULA ------------------------------------------------------
	var i_correr := -1
	for i in guia.passos.size():
		if str((guia.passos[i] as Dictionary).get("id", "")) == "correr":
			i_correr = i
	var tonho = vale._achar_morador("tonho")
	_conferir(i_correr >= 0 and tonho != null, "a chegada não tem o passo 'correr' ou o Tonho não está no vale")
	if i_correr < 0 or tonho == null:
		_fechar()
		return
	guia.iniciado = true
	guia.missao = i_correr
	guia.espera = 0.0
	var d_antes: float = _plano(pedro.global_position, tonho.global_position)
	guia.avancar()
	await _frames(3)
	_conferir(bool(cenas.em_cena()) and str(cenas.nome_da_cena()) == "apresentacao_do_tonho", "a apresentação do Tonho não tocou")
	_conferir(not cenas.pular(), "o E pulou a cena no primeiro instante, antes de ESPERA_PARA_PULAR")
	_conferir(bool(cenas.em_cena()) and not bool(cenas.pulando()), "a cena parou de tocar com o E do primeiro instante")
	await _ate(func() -> bool: return false, Cena.ESPERA_PARA_PULAR + 0.4)
	var tecla := InputEventKey.new()
	tecla.physical_keycode = KEY_E
	tecla.pressed = true
	Input.parse_input_event(tecla)
	await _frames(2)
	_conferir(bool(cenas.pulando()) or not bool(cenas.em_cena()), "o E, depois de ESPERA_PARA_PULAR, não pulou a cena")
	# Pulada, a cena acaba já, menos a volta da câmera ao jogador, que sempre desliza (até TETO_DO_PLANO).
	var pulou := await _ate(func() -> bool: return not bool(cenas.em_cena()), Cena.TETO_DO_PLANO + 3.0)
	_conferir(pulou, "a cena pulada não acabou em %.0f s" % (Cena.TETO_DO_PLANO + 3.0))
	var d_depois: float = _plano(pedro.global_position, tonho.global_position)
	_conferir(d_depois < d_antes - 1.0 or d_depois < 3.5, "pulada a cena, o Pedro não chegou ao Tonho (%.1f → %.1f)" % [d_antes, d_depois])
	_conferir(jogador.is_physics_processing(), "pulada a cena o jogador não voltou a andar")
	_conferir(root.get_camera_3d() == camera_do_jogador, "pulada a cena a câmera não voltou para a do jogador")
	_conferir(float(guia.espera) < 100.0, "pulada a cena a fila continua segura (espera %.1f)" % float(guia.espera))
	var resumo_seguinte := str(guia.resumo_do_passo(guia.passos[i_correr + 1]))
	# O anúncio abre o passo seguinte no caderno. O HUD segue a missão ACOMPANHADA, e aqui o foco ficou no
	# desembarque, que o portão pulou ao pôr a fila direto no `correr`: pergunta-se ao caderno, e não ao HUD.
	var caderno := root.get_node("/root/CadernoDoVale")
	var no_caderno: String = guia._id_no_caderno(guia.passos[i_correr + 1])
	var anunciou := await _ate(func() -> bool: return caderno.tem(no_caderno) and str(caderno.de(no_caderno).get("resumo", "")).contains(resumo_seguinte), 6.0)
	_conferir(anunciou, "pulada a cena, o passo seguinte ('%s') não foi anunciado" % resumo_seguinte)
	_conferir(hud_layer.visible, "pulada a cena a interface do vale não voltou")

	# O Esc também pula, e não abre o menu da pausa.
	cenas.tocar("a_casa_do_tio", guia)
	await _ate(func() -> bool: return bool(cenas.em_cena()), 3.0)
	await _ate(func() -> bool: return false, Cena.ESPERA_PARA_PULAR + 0.4)
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await _frames(2)
	_conferir(bool(cenas.pulando()) or not bool(cenas.em_cena()), "o Esc, na cena, não a pulou")
	_conferir(str(vale.telas.aberta()) == "", "o Esc que pulou a cena abriu a tela '%s'" % str(vale.telas.aberta()))
	await _ate(func() -> bool: return not bool(cenas.em_cena()), Cena.TETO_DO_PLANO + 3.0)
	_conferir(not bool(cenas.em_cena()) and jogador.is_physics_processing(), "pulada pelo Esc, a cena não devolveu o jogador")
	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("CENA_SO_COM_BALAO_OK: o tempo do plano respeita a velocidade e o giro, a curva parte e chega parada; na cena a interface, a seta e as plaquinhas se recolhem e voltam; a câmera nasce da do jogador, nunca chega perto do viajante e desliza sem salto; o E e o Esc pulam a cena depois do primeiro instante e a missão segue certa")
	else:
		print("cena_so_com_balao: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


static func _plano(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicao.call():
			return true
		await process_frame
	return condicao.call()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
