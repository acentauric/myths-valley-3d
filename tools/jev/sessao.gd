extends SceneTree
## Opt-in playtest harness. Does not change the game's ordinary launch or tests.
## No secrets, teleports, mission mutation or injected inventory in this script.

const PainelSessao = preload("res://tools/jev/painel_sessao.gd")
const AcaoEmPalavras = preload("res://tools/jev/acao_em_palavras.gd")
const ModalBloqueio = preload("res://tools/jev/modal_bloqueio.gd")
## Pedido de 07/10: no teste a câmera abre um pouco mais afastada (o `mv_zoom_out`), para quem
## assiste ver o personagem, os moradores e o caminho. Cinco passos de 0,35 m sobre os 8 m
## de fábrica. Só vale na sessão do testador: a preferência do jogador não muda.
const PASSOS_DE_ZOOM := 5
const DISTANCIA_DA_CAMERA := 8.0

var ponte := ""
var token := ""
var pasta := ""
var duracao := 0
var orcamento := 0.10
var inicio_jogo := -1
var parar := false
var chamadas := 0
var custo := 0.0
var painel_observador: PainelSessao
## O que o painel mostra: a última decisão da ponte, as últimas quatro em palavras e se ainda
## se espera a próxima.
var aguardando := true
var decisao_atual: Dictionary = {}
var decisoes_recentes: Array = []
var rotulos_botoes: Dictionary = {}
var estado_recente: Dictionary = {}
var reposicionar_em := 0
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
## O CONTROLE MANUAL (#206): F7 tira o testador do volante sem encerrar a sessão. Nenhuma
## decisão é pedida nem ação executada enquanto `manual` vale; o teclado e o mouse são de
## quem assiste. F7 de novo devolve, e a ponte manda o robô recalcular do estado novo. F8
## continua encerrando a sessão em qualquer estado.
var manual := false
var manual_desde := 0
var manual_antes: Dictionary = {}
var manual_captura := ""
## A devolução ainda está a caminho da ponte: o laço espera, para o robô recalcular antes de decidir.
var manual_devolvendo := false
var faixa_manual: PanelContainer
var botao_manual: Button
## A câmera da sessão de teste (#201): desvia de poste, tronco, parede e árvore para o
## viajante não sumir da tela. Só existe aqui; a câmera do jogo comum não muda.
var camera_do_teste: Node
## As teclas que o testador pode estar segurando quando a mão passa para o humano.
const TECLAS_DO_TESTADOR := [KEY_W, KEY_A, KEY_S, KEY_D, KEY_E, KEY_F, KEY_V, KEY_SHIFT, KEY_SPACE]
## A casca de cada construção ao alcance, como o olho a vê, para saber quando o centro do viajante entra
## numa malha opaca (#205): nome do lote -> {"corpo", "desde"}; e quando o último achado dela foi.
const AuditoriaDeGeometria = preload("res://scripts/prototipo_3d/auditoria_de_geometria.gd")
var cascas_auditadas: Dictionary = {}
var dentro_de_geometria_visto: Dictionary = {}
## O BLOQUEIO (#183): a ponte manda `blocked` quando a escada não destrava; o modal pergunta e
## a escolha vai no estado do pedido seguinte (`blocked_choice`).
var modal_bloqueio: ModalBloqueio
var escolha_do_bloqueio := ""
## F6 (#234): o painel minimizado numa faixa; a escolha vale a sessão inteira.
var minimizado := false
var botao_f6: Button
## O idioma pedido pelo menu (#180), ou -1: conferido a cada volta e reaplicado se escapar.
var idioma_pedido := -1
## O arquivo de pronto do menu (#175) só nasce com o vale carregado.
var pronto_avisado := false
## As copas na frente do viajante (#201): esmaecidas só na sessão de teste.
var copas_do_teste: Node


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


## O índice (pt 0, en 1, es 2, zh 3) do idioma pedido à sessão; sem pedido vale o português.
var indice_do_idioma := 0


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
	idioma_pedido = _aplicar_idioma_da_sessao(OS.get_environment("MV_JEV_IDIOMA"))
	indice_do_idioma = maxi(idioma_pedido, 0)
	_montar_painel()
	root.window_input.connect(_ao_entrar_evento)
	change_scene_to_file("res://scenes/prototipo_3d/inicio.tscn")
	await process_frame
	while not parar:
		if Input.is_physical_key_pressed(KEY_F8):
			break
		if duracao > 0 and inicio_jogo >= 0 and _segundos() >= duracao:
			break
		if manual_devolvendo:
			await process_frame
			continue
		if manual:
			await _aguardar_manual()
			continue
		_garantir_idioma()
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
			camera_do_teste = load("res://tools/jev/camera_do_teste.gd").new()
			camera_do_teste.jogador = cena.get("player")
			camera_do_teste.encoberto_demais.connect(_ao_ficar_encoberto)
			root.add_child(camera_do_teste)
			copas_do_teste = load("res://tools/jev/copas_do_teste.gd").new()
			copas_do_teste.jogador = cena.get("player")
			root.add_child(copas_do_teste)
			if not OS.get_environment("MV_JEV_CENARIO").is_empty():
				await _aplicar_cenario(OS.get_environment("MV_JEV_CENARIO"))
			await _post("/ready", {})
			_capturar()
		if vale:
			_avisar_o_menu_que_o_vale_abriu()
		_vigiar_o_relogio()
		_afastar_camera()
		var estado := _estado()
		var opcoes: Dictionary = _acoes(estado)
		if opcoes.is_empty():
			await _esperar(0.5)
			continue
		var escolha_enviada := escolha_do_bloqueio
		if escolha_enviada != "":
			estado["blocked_choice"] = escolha_enviada
			escolha_do_bloqueio = ""
		aguardando = true
		estado_recente = estado
		var resposta: Dictionary = await _post("/decision", {"state": estado, "actions": opcoes})
		if parar:
			break
		if escolha_enviada == "stop":
			# Encerrar no modal do bloqueio: como o F8, com o bloqueio no relatório.
			ultima_acao = "blocked_step"
			parar = true
			break
		if not str(resposta.get("stop", "")).is_empty():
			ultima_acao = str(resposta.stop)
			parar = true
			break
		var bloqueio = resposta.get("blocked")
		if bloqueio is Dictionary and not (bloqueio as Dictionary).is_empty():
			chamadas = int(resposta.get("calls", chamadas))
			custo = float(resposta.get("estimated_usd", custo))
			await _tratar_bloqueio(bloqueio)
			continue
		if not resposta.has("choice"):
			ultima_acao = "bridge_error"
			parar = true
			break
		if manual:
			# A mão passou ao humano enquanto a ponte decidia: a escolha velha é descartada.
			continue
		chamadas = int(resposta.get("calls", 0))
		custo = float(resposta.get("estimated_usd", 0.0))
		ultima_acao = str(resposta.choice)
		_registrar_decisao(resposta, estado)
		_atualizar_painel()
		var antes: Dictionary = _estado()
		amostras_movimento.clear()
		amostrar_em = 0
		_amostrar_movimento()
		var resultado: String = await _executar(ultima_acao)
		if manual and not parar:
			resultado = "interrupted_manual_control"
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
	if manual:
		await _fechar_manual("session_end")
	_atualizar_painel()
	var motivo := "duration" if duracao > 0 and inicio_jogo >= 0 and _segundos() >= duracao else (ultima_acao if parar else "user_stop")
	await _post("/stop", {"reason": motivo})
	_capturar()
	quit()


## O CENÁRIO DE VERIFICAÇÃO (`jogar.py --cenario`): só para provar uma regra do testador sem
## jogar três horas de campanha. Arruma o estado pelas mesmas propriedades que os portões do
## jogo usam e deixa o resto para o robô: ele nunca teleporta nem mexe em missão ou item.
## `lenha` (#207): o tutorial feito, a ponte pedindo os 36 paus, a picareta na mão, o machado
## só na mochila e o viajante a uns passos do tronco que o marcador aponta.
func _aplicar_cenario(nome: String) -> void:
	if not nome in ["lenha", "noite", "varal", "f7"]:
		push_error("JEV: cenário desconhecido: " + nome)
		return
	var vale := current_scene
	var pedro = vale.get("pedro")
	var cadeia = vale.get("_cadeias").get("pedro_ponte")
	var inventario := root.get_node("Inventario")
	pedro._cadeia.iniciado = true
	pedro.missao = pedro.MISSOES.size()
	pedro._cadeia.despedida_feita = true
	cadeia.iniciado = true
	for i in cadeia.passos.size():
		if str((cadeia.passos[i] as Dictionary).get("id", "")) == "ponte_lenha":
			cadeia.missao = i
	# O passo se anuncia (objetivo, caderno e a entrega do machado, que depois vai só para a mochila).
	cadeia.retomar()
	for i in inventario.ESPACOS:
		inventario.espacos[i] = {}
	inventario.espacos[0] = {"id": "balde", "qtd": 1}
	inventario.espacos[1] = {"id": "picareta", "qtd": 1}
	inventario.espacos[inventario.ESPACOS_MAO + 2] = {"id": "machado", "qtd": 1}
	inventario.selecionar(1)
	inventario.mudou.emit()
	var jogador: Node3D = vale.get("player")
	var tronco: Vector3 = cadeia.posicao_do_passo(cadeia.missao)
	if nome == "varal":
		await _cenario_varal(vale, jogador)
		return
	if nome == "noite":
		# #192/#191: o tutorial feito, a hora das dez da noite, o fôlego curto e a porta de casa a uns
		# passos. O robô deve ir deitar, o relógio seguir andando e, de manhã, ele sair pela porta.
		var porta: Vector3 = root.get_node("Lugares").ponto("casa_de_taipa")
		root.get_node("Dia").definir_hora(22.0)
		root.get_node("Energia").definir(18.0)
		if porta.is_finite():
			var mundo_da_casa = vale.get("world")
			jogador.teleportar(mundo_da_casa.ground_position(porta + Vector3(0.0, 0.0, 9.0), 0.1), 0.0)
	elif tronco.is_finite():
		var mundo = vale.get("world")
		jogador.teleportar(mundo.ground_position(tronco + Vector3(6.0, 0.0, 0.0), 0.1), PI * 0.5)
	await _esperar(1.0)
	_registrar_cenario(nome, tronco)
	if nome == "f7":
		_apertar_f7_no_cenario()


## `varal` (#201): o viajante junto do poste do varal da Casa do arraial 5, com a câmera do
## jogador atrás do poste (o giro em que o raio da câmera ao peito bate no mourão). Depois de
## uns segundos a câmera da sessão tem de ter girado ou aproximado: o viajante à vista.
func _cenario_varal(vale: Node, jogador: CharacterBody3D) -> void:
	var CameraDoTeste = load("res://tools/jev/camera_do_teste.gd")
	var mundo = vale.get("world")
	var poste: Vector3 = mundo.ancoras.get("Casa do arraial 5/Varal", Vector3.INF)
	if not poste.is_finite():
		push_error("JEV: sem a âncora Casa do arraial 5/Varal")
		return
	var espaco: PhysicsDirectSpaceState3D = jogador.get_world_3d().direct_space_state
	var fora: Array[RID] = [jogador.get_rid()]
	var escolhido := false
	for graus in range(0, 360, 20):
		var lado := Vector3(sin(deg_to_rad(graus)), 0.0, cos(deg_to_rad(graus)))
		var chao: Vector3 = mundo.ground_position(poste + lado * 2.4, 0.1)
		jogador.teleportar(chao, 0.0)
		await physics_frame
		await physics_frame
		espaco = jogador.get_world_3d().direct_space_state
		var pivo := chao + Vector3(0.0, 1.18, 0.0)
		for giro in range(0, 360, 15):
			var yaw := deg_to_rad(giro)
			var camera: Vector3 = CameraDoTeste.posicao_da_camera(pivo, yaw, float(jogador.get("_pitch")), 8.0)
			if CameraDoTeste.encoberto_de(espaco, camera, chao + Vector3(0, 1.1, 0), chao + Vector3(0, 1.65, 0), fora):
				jogador.set("_yaw", yaw)
				escolhido = true
				break
		if escolhido:
			break
	print("JEV_CENARIO: varal poste=", poste, " encoberto_na_partida=", escolhido)
	await _esperar(4.0)
	var camera_viva: Camera3D = jogador.get_viewport().get_camera_3d()
	var peito: Vector3 = jogador.global_position + Vector3(0, 1.1, 0)
	var cabeca: Vector3 = jogador.global_position + Vector3(0, 1.65, 0)
	espaco = jogador.get_world_3d().direct_space_state
	var ainda: bool = CameraDoTeste.encoberto_de(espaco, camera_viva.global_position, peito, cabeca, fora)
	print("JEV_CENARIO: varal depois de 4 s encoberto=", ainda, " tempo_encoberto=", camera_do_teste.encoberto_s)


## `f7` (#206): a lenha, e um F7 de verdade, entrado pela janela como o teclado faria. Depois de
## 12 s o F7 assume o controle; 8 s com a mão do humano (o testador não pode agir nem decidir); outro
## F7 devolve, e o testador recalcula e volta a agir. O relatório conta o trecho (seção "Controle manual").
func _apertar_f7_no_cenario() -> void:
	await _esperar(12.0)
	var acoes_antes := chamadas
	_enviar_tecla_f7()
	await _esperar(0.5)
	var assumiu := manual
	var posicao_antes: Vector3 = (current_scene.get("player") as Node3D).global_position
	var inicio := Time.get_ticks_msec()
	while Time.get_ticks_msec() - inicio < 8000 and not parar:
		await process_frame
	var parado: bool = (current_scene.get("player") as Node3D).global_position.distance_to(posicao_antes) < 0.5 and chamadas == acoes_antes
	_enviar_tecla_f7()
	var devolveu := false
	var voltou := false
	var limite := Time.get_ticks_msec() + 25000
	while Time.get_ticks_msec() < limite and not parar and not voltou:
		await process_frame
		devolveu = devolveu or (not manual and not manual_devolvendo)
		voltou = devolveu and chamadas > acoes_antes
	print("JEV_CENARIO: f7 assumiu=", assumiu, " testador_parado_no_manual=", parado, " devolveu=", devolveu, " voltou_a_agir=", voltou)


func _enviar_tecla_f7() -> void:
	for apertada in [true, false]:
		var evento := InputEventKey.new()
		evento.keycode = KEY_F7
		evento.physical_keycode = KEY_F7
		evento.pressed = apertada
		Input.parse_input_event(evento)
		await process_frame


func _registrar_cenario(nome: String, tronco: Vector3) -> void:
	print("JEV_CENARIO: ", nome, " tronco=", tronco)


## O IDIOMA DO JOGADOR atravessa o perfil isolado (#180): `jogar.py --idioma` o manda por
## MV_JEV_IDIOMA e ele é gravado no `user://` novo da sessão, de onde o menu, a carga, o
## HUD, as falas e o painel do testador o leem. O save e o progresso do jogador não vêm.
## Devolve o índice aplicado, ou -1 sem idioma pedido (ou desconhecido): vale o padrão.
func _aplicar_idioma_da_sessao(codigo: String) -> int:
	if codigo.is_empty():
		return -1
	var indice: int = idioma.idioma_do_sistema(codigo)
	if indice < 0:
		push_warning("JEV: idioma desconhecido '%s'; vale o padrão do jogo." % codigo)
		return -1
	idioma.definir(indice)
	return indice


func _texto(chave: String) -> String:
	return idioma.campo(textos, chave)


func _robo() -> bool:
	return OS.get_environment("MV_JEV_ROBOT") == "1"


func _montar_painel() -> void:
	var camada := CanvasLayer.new()
	camada.name = "JevObservador"
	camada.layer = 110
	camada.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(camada)
	var painel := PainelSessao.new()
	painel_observador = painel
	painel.add_to_group("obstaculos_do_hud")
	camada.add_child(painel)
	painel.montar(_texto)
	painel.parar_pedido.connect(func() -> void:
		ultima_acao = "user_stop"
		parar = true)
	botao_manual = painel._manual
	painel.manual_pedido.connect(_alternar_manual)
	painel.minimizar_pedido.connect(_alternar_minimizado)
	# O botão próprio do F6, à direita do FPS (o primeiro da coluna de atalhos).
	botao_f6 = Button.new()
	botao_f6.name = "MinimizarF6"
	botao_f6.text = "F6"
	botao_f6.focus_mode = Control.FOCUS_NONE
	botao_f6.theme = painel.theme
	botao_f6.add_theme_font_size_override("font_size", 10)
	botao_f6.custom_minimum_size = Vector2(28.0, 24.0)
	botao_f6.visible = false
	botao_f6.pressed.connect(_alternar_minimizado)
	botao_f6.add_to_group("obstaculos_do_hud")
	camada.add_child(botao_f6)
	# O modal do bloqueio (#183), escondido até a ponte mandar `blocked`.
	modal_bloqueio = ModalBloqueio.new()
	camada.add_child(modal_bloqueio)
	modal_bloqueio.montar(_texto)
	# A faixa de cima só existe com o humano no controle, e fica à vista mesmo com telas abertas.
	faixa_manual = PanelContainer.new()
	faixa_manual.visible = false
	faixa_manual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.45, 0.07, 0.05, 0.92)
	fundo.border_color = Color(0.93, 0.74, 0.28)
	fundo.set_border_width_all(2)
	fundo.set_content_margin_all(8)
	faixa_manual.add_theme_stylebox_override("panel", fundo)
	var aviso := Label.new()
	aviso.name = "Aviso"
	aviso.add_theme_font_size_override("font_size", 18)
	aviso.add_theme_color_override("font_color", Color(1.0, 0.93, 0.7))
	aviso.text = _texto("manual_faixa")
	faixa_manual.add_child(aviso)
	camada.add_child(faixa_manual)
	faixa_manual.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 10)
	faixa_manual.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_atualizar_painel()


## O que a ponte decidiu, guardado para o painel: quem, por quê, a ação em palavras e as
## últimas quatro. O nome técnico fica na dica do painel e no relatório.
func _registrar_decisao(resposta: Dictionary, estado: Dictionary) -> void:
	aguardando = false
	var nivel := str(resposta.get("level", ""))
	var palavras := AcaoEmPalavras.descrever(ultima_acao, estado, _texto, rotulos_botoes)
	if ultima_acao == "follow_route":
		var nome_do_alvo := str((estado.get("route", {}) as Dictionary).get("target_name", ""))
		palavras = _texto("a_follow_route") % (nome_do_alvo if nome_do_alvo != "" else _texto("alvo_da_rota"))
	decisao_atual = {"nivel": nivel, "modo": str(resposta.get("mode", "normal")), "plano": resposta.get("plan"),
		"motivo": str(resposta.get("rationale", "")), "sinais": resposta.get("signals", []),
		"escalonamentos": int(resposta.get("escalations", 0)), "progresso": resposta.get("progress", {}),
		"acao_texto": palavras, "acao_tecnica": ultima_acao}
	decisoes_recentes.append({"nivel": nivel if nivel != "" else "jev", "texto": palavras})
	while decisoes_recentes.size() > PainelSessao.MAX_DECISOES:
		decisoes_recentes.pop_front()


func _objetivo_atual() -> Dictionary:
	var objetivo: Dictionary = estado_recente.get("objective", {})
	if objetivo.is_empty():
		return {}
	return {"titulo": str(objetivo.get("titulo", "")), "feito": int(objetivo.get("feito", 0)), "total": int(objetivo.get("total", 0))}


func _atualizar_painel() -> void:
	if painel_observador == null:
		return
	var robo := _robo()
	var d := decisao_atual
	var progresso: Dictionary = d.get("progresso", {})
	var titulo := _texto("titulo_teste") if robo else (_texto("sol") if OS.get_environment("MV_JEV_SOL") == "1" else (_texto("offline") if OS.get_environment("MV_JEV_OFFLINE") == "1" else _texto("titulo")))
	var com_apoio := not OS.get_environment("MV_JEV_APOIOS").is_empty()
	var gasto := _texto("sem_api")
	if com_apoio:
		gasto = _texto("ia") % [int(d.get("escalonamentos", 0)), custo, orcamento]
	elif not robo:
		gasto = ""
	var espera := aguardando or d.is_empty()
	var nivel_atual := str(d.get("nivel", "")) if robo else ""
	var faixa: Array = [_texto("testando")]
	if nivel_atual != "":
		faixa.append(_texto("nivel_" + nivel_atual))
	faixa.append(_texto("n_acoes") % chamadas)
	if int(progresso.get("total", 0)) > 0:
		faixa.append(PainelSessao.TestadorApoios.numero(float(progresso.get("percentual", 0.0)), 1) + "%")
	painel_observador.mostrar({
		"titulo": titulo,
		"nivel": nivel_atual,
		"modo": d.get("modo", "normal"), "plano": d.get("plano"),
		"sub": _texto("subtitulo") % [chamadas, PainelSessao.duracao(_segundos())] if robo else _texto("estado") % [titulo, chamadas, custo, orcamento],
		"acao": _texto("manual_acao") if manual else (_texto("aguardando_robot" if robo else "aguardando") if espera else str(d.get("acao_texto", ""))),
		"acao_tecnica": str(d.get("acao_tecnica", "")),
		"motivo": "" if espera else str(d.get("motivo", "")),
		"objetivo": _objetivo_atual(), "progresso": progresso, "ritmo": progresso.get("pace", {}),
		"sinais": d.get("sinais", []), "bloqueado": ultima_acao == "blocked_step",
		"decisoes": decisoes_recentes, "gasto": gasto,
		"minimizado": minimizado, "faixa": " · ".join(faixa),
		"minimizar_botao": _texto("cmd_maximizar" if minimizado else "cmd_minimizar"),
		# Maximizado, o rótulo inteiro; na faixa, o curto, para os três caberem lado a lado.
		"manual_botao": _texto(("cmd_devolver" if manual else "cmd_assumir") + ("_curto" if minimizado else ""))})
	if faixa_manual != null:
		faixa_manual.visible = manual
		faixa_manual.get_node("Aviso").text = _texto("manual_faixa")
	# Telas grandes, diálogos e cutscenes precisam de toda a área; F8 permanece ativo.
	if _no_vale() and bool(current_scene.get("carga_ok")):
		painel_observador.visible = current_scene.get("telas").aberta().is_empty() and not root.get_node("Dialogo").ativo \
			and not _em_cutscene()
	_posicionar_botao_f6()
	# Sem cobrir a barra de mão, o minimapa, a coluna de atalhos nem o resto do HUD: a cada meio
	# segundo, no lugar livre (o preferido é à esquerda da coluna, #234).
	if Time.get_ticks_msec() >= reposicionar_em:
		reposicionar_em = Time.get_ticks_msec() + 500
		painel_observador.posicionar(_obstaculos_do_hud(), _coluna_de_atalhos())


## F6: o painel vira a faixa de uma linha, ou volta inteiro.
func _alternar_minimizado() -> void:
	minimizado = not minimizado
	reposicionar_em = 0
	_atualizar_painel()


## A coluna de atalhos da direita (os `botoes_canto` do HUD), em coordenadas da tela, já com o
## botão do F6 ao lado do FPS. Vazio fora do vale.
func _coluna_de_atalhos() -> Rect2:
	var coluna := Rect2()
	if not _no_vale():
		return coluna
	for no in get_nodes_in_group("botoes_canto"):
		if not (no is Control) or not (no as Control).is_visible_in_tree():
			continue
		var rect := (no as Control).get_global_rect()
		coluna = rect if not coluna.has_area() else coluna.merge(rect)
	if coluna.has_area() and botao_f6 != null and botao_f6.visible:
		coluna = coluna.merge(botao_f6.get_global_rect())
	return coluna


## O botão do F6 mora à direita do botão de FPS, centrado nele; some com o painel.
func _posicionar_botao_f6() -> void:
	if botao_f6 == null:
		return
	var hud = current_scene.get("hud") if _no_vale() else null
	var fps = hud.get("_performance_button") if hud != null else null
	if not (fps is Control) or not is_instance_valid(fps) or not (fps as Control).is_visible_in_tree():
		botao_f6.visible = false
		return
	botao_f6.visible = painel_observador.visible
	var rect := (fps as Control).get_global_rect()
	var tamanho := botao_f6.get_combined_minimum_size()
	var janela := painel_observador.get_viewport_rect().size
	var x := minf(rect.end.x + 4.0, janela.x - tamanho.x - 2.0)
	botao_f6.position = Vector2(x, rect.position.y + (rect.size.y - tamanho.y) * 0.5).floor()
	botao_f6.size = tamanho
	botao_f6.tooltip_text = _texto("cmd_maximizar" if minimizado else "cmd_minimizar")


## Uma cutscene (as cenas dos dados ou as do revoar) está tocando? O painel e o modal saem.
func _em_cutscene() -> bool:
	if not _no_vale():
		return false
	for campo in ["cenas", "revoar"]:
		var sistema = current_scene.get(campo)
		if sistema is Object and is_instance_valid(sistema) and sistema.has_method("em_cena") and bool(sistema.em_cena()):
			return true
	return false


## Os retângulos do HUD que o painel não pode cobrir (o grupo `obstaculos_do_hud`).
func _obstaculos_do_hud() -> Array:
	var itens: Array = []
	for no in get_nodes_in_group("obstaculos_do_hud"):
		if no == painel_observador or not (no is Control) or not (no as Control).is_visible_in_tree():
			continue
		var controle := no as Control
		itens.append(controle.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, controle.size))
	# Na carga, o CARREGANDO com a rosa girando, a marca e o almanaque são obstáculos: as peças
	# soltas da tela (as camadas de capa e véus ocupam a janela inteira e não contam).
	var janela := painel_observador.get_viewport_rect().size
	for tela in get_nodes_in_group("telas_de_carregamento"):
		for filho in tela.get_children():
			if not (filho is Control) or not (filho as Control).visible:
				continue
			var rect := (filho as Control).get_global_rect()
			if rect.size.x * rect.size.y < janela.x * janela.y * 0.35:
				itens.append(rect)
	return itens


## A câmera do teste abre mais afastada. Só atua enquanto a distância está no padrão de 8 m
## (inclusive depois de um reinício da câmera) e fora do cômodo visto de cima.
func _afastar_camera() -> void:
	if not _no_vale() or not bool(current_scene.get("carga_ok")):
		return
	var jogador = current_scene.get("player")
	if jogador == null or bool(jogador.get("_de_cima")):
		return
	if absf(float(jogador.get("_distance")) - DISTANCIA_DA_CAMERA) > 0.01:
		return
	for _passo in PASSOS_DE_ZOOM:
		jogador._aproximar_a_camera(false)
	jogador._apply_camera()


## O testador deve largar o que faz: a sessão acabou ou a mão passou ao humano (#206).
func _cede() -> bool:
	return parar or manual


## F7, vindo da janela: vale na hora, mesmo no meio de uma decisão ou de um trajeto.
func _ao_entrar_evento(evento: InputEvent) -> void:
	var tecla := evento as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return
	if tecla.keycode == KEY_F6 or tecla.physical_keycode == KEY_F6:
		_alternar_minimizado()
	elif tecla.keycode == KEY_F7 or tecla.physical_keycode == KEY_F7:
		# Com o modal do bloqueio aberto, o F7 é a resposta "assumir o controle".
		if modal_bloqueio != null and modal_bloqueio.aberto():
			modal_bloqueio.escolher("takeover")
			return
		_alternar_manual()


func _alternar_manual() -> void:
	if parar or inicio_jogo < 0 or not _no_vale() or not bool(current_scene.get("carga_ok")):
		return
	if manual:
		_fechar_manual("f7")
	else:
		_abrir_manual()


## O que a ponte precisa saber do mundo nas pontas do controle manual: posição, missão, itens e mão.
func _resumo_manual() -> Dictionary:
	var jogador: Node3D = current_scene.get("player")
	var inventario := root.get_node("Inventario")
	var objetivo: Dictionary = _json_seguro(root.get_node("CadernoDoVale").atual())
	return {"position": _vetor(jogador.global_position), "seconds": _segundos(),
		"objective": {"id": objetivo.get("id", ""), "feito": objetivo.get("feito", 0), "total": objetivo.get("total", 0)},
		"inventory": {"slots": inventario.espacos.duplicate(true), "in_hand": inventario.na_mao()}}


func _abrir_manual() -> void:
	manual = true
	manual_desde = Time.get_ticks_msec()
	manual_antes = _resumo_manual()
	# A fila do testador morre aqui: o que ele segurava é solto e a caminhada guiada, cancelada.
	for tecla in TECLAS_DO_TESTADOR:
		_pressionar(tecla, false)
	current_scene.get("player")._cancel_walk()
	manual_captura = _capturar()
	_atualizar_painel()
	print("JEV: controle manual assumido (F7)")
	_post("/manual", {"phase": "start", "before": manual_antes, "capture": manual_captura, "last_action": ultima_acao})


## Devolve a mão ao testador (F7) ou fecha o trecho porque a sessão acaba. O robô recalcula do
## estado novo; o relógio é rearmado para o vigia não acusar o que o humano deixou parado.
func _fechar_manual(motivo: String) -> void:
	manual = false
	manual_devolvendo = true
	var duracao_s := snappedf((Time.get_ticks_msec() - manual_desde) / 1000.0, 0.1)
	var depois := _resumo_manual()
	var captura := _capturar()
	relogio_motivo = ""
	relogio_alertado = false
	relogio_hora_mudou_em = _agora()
	_atualizar_painel()
	print("JEV: controle manual devolvido (%s) apos %.1f s" % [motivo, duracao_s])
	await _post("/manual", {"phase": "end", "reason": motivo, "duration_s": duracao_s, "before": manual_antes,
		"after": depois, "capture": captura, "start_capture": manual_captura})
	manual_devolvendo = false


func _aguardar_manual() -> void:
	while manual and not parar:
		if Input.is_physical_key_pressed(KEY_F8):
			ultima_acao = "user_stop"
			parar = true
			break
		if duracao > 0 and inicio_jogo >= 0 and _segundos() >= duracao:
			break
		_atualizar_painel()
		if inicio_jogo >= 0 and _segundos() - ultima_captura >= 30:
			_capturar()
		await process_frame


func _segundos() -> int:
	return 0 if inicio_jogo < 0 else int((Time.get_ticks_msec() - inicio_jogo) / 1000)


func _no_vale() -> bool:
	return current_scene != null and current_scene.scene_file_path.ends_with("vale.tscn")


func _post(caminho: String, dados: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	# Com Jev/GPT marcados a ponte espera a resposta do serviço dentro do pedido.
	var espera_do_apoio := 120.0 if not OS.get_environment("MV_JEV_APOIOS").is_empty() else 15.0
	http.timeout = 190.0 if OS.get_environment("MV_JEV_SOL") == "1" else espera_do_apoio
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
	# A BARRA DE MÃO INTEIRA, vaga por vaga, com a família de cada item (#207): "o machado de
	# aço" é machado para o alvo que pede machado, e o robô não deve adivinhar isso pelo nome.
	var barra_de_mao: Array = []
	var catalogo_itens = load("res://scripts/compartilhado/catalogo.gd")
	for vaga in 10:
		var id_da_vaga := str(inventario.espacos[vaga].get("id", ""))
		barra_de_mao.append({"slot": vaga, "id": id_da_vaga,
			"family": str(catalogo_itens.familia(id_da_vaga)) if id_da_vaga != "" else ""})
	estado.inventory["hand_bar"] = barra_de_mao
	# O REQUISITO DE FERRAMENTA do alvo ao alcance e a ÚLTIMA RECUSA, como dado e não só como
	# a frase da tela ("Ponha na mão: Machado", "Precisa de Machado") — #207.
	var recursos_do_vale: Node = current_scene.get_node_or_null("Recursos3D")
	if recursos_do_vale != null and recursos_do_vale.has_method("requisito_de_ferramenta"):
		estado["tool_requirement"] = recursos_do_vale.requisito_de_ferramenta()
		var recusa: Dictionary = (recursos_do_vale.get("ultima_recusa") as Dictionary).duplicate()
		if not recusa.is_empty():
			recusa["ago_ms"] = Time.get_ticks_msec() - int(recusa.get("quando_ms", 0))
			recusa.erase("quando_ms")
		estado["last_refusal"] = recusa
	for espaco: Dictionary in inventario.espacos:
		var id := str(espaco.get("id", ""))
		if root.get_node("Cozinha").e_comida(id) and float(catalogo_itens.dados(id).get("folego", 0.0)) > 0.0:
			estado.inventory.food_items.append(id)
	var relogio := root.get_node("Relogio")
	var dia = _dia()
	estado["clock"] = {"day": relogio.dia, "season": relogio.estacao, "year": relogio.ano, "time": relogio.texto(), "paused": relogio.pausado,
		"player_paused": bool(dia.pausado), "speed": int(dia.velocidade), "held_by": dia.motivos_da_segurada()}
	estado["interior"] = current_scene.get("interiores").dentro()
	estado["route"] = _rota()
	estado["language"] = {"requested": str(idioma.LOCALES[idioma_pedido]) if idioma_pedido >= 0 else "",
		"applied": TranslationServer.get_locale()}
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
				# O E de longe anda até o alvo e gira antes de bater (#208): o testador espera por isso também.
				if fonte.has_method("em_andamento"):
					oferta["em_trabalho"] = bool(fonte.call("em_andamento"))
				else:
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
			"step": pedro.get("missao"), "text": pedro.texto_da_missao(), "position": _vetor(pedro.global_position),
			"tutorial_finished": bool(pedro.terminou_o_tutorial())}
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
	rotulos_botoes.clear()
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
			# A tela de idioma: o robô confirma o idioma da sessão (#180), nunca outro. Clicar
			# em "Português" ali regravava a preferência e a partida inteira abria em pt.
			var permitido: bool = str(botao.name) in ["Idioma%d" % indice_do_idioma, "Vaga1"]
			var texto_botao := str(botao.get("text"))
			permitido = permitido or texto_botao in ["JOGAR", "CONTINUAR", "PULAR"]
			if permitido:
				var id := "button_%d" % catalogo.size()
				catalogo[id] = botao
				rotulos_botoes[id] = texto_botao if texto_botao != "" else str(botao.name)
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
		if _guia_conduz(pedro):
			catalogo["follow_pedro"] = pedro
			opcoes["follow_pedro"] = "Keep following moving Pedro for up to 12 seconds, staying near so he does not stop. Continues even after catching up, until he reaches guide_destination. Essential when conducting=true and guide_destination_reached=false."
		else:
			# Acabado o tutorial ele não conduz mais (#191): é um morador no posto dele, e seguir
			# alguém parado não leva a lugar nenhum. Quem precisa dele o aborda, como aos outros.
			var id_do_guia := "approach_" + str(pedro.name)
			catalogo[id_do_guia] = pedro
			opcoes[id_do_guia] = "Approach Pedro, the guide, now at his post and no longer leading, %.1f units away" % jogador.global_position.distance_to(pedro.global_position)
	if str(estado.get("interaction_target", "")) != "":
		opcoes["interact"] = "Press E to interact with " + str(estado.interaction_target)
	var objetivo: Dictionary = root.get_node("CadernoDoVale").atual()
	var ponto = objetivo.get("alvo", Vector3.INF)
	if ponto is Vector3 and ponto.is_finite() and ponto != Vector3.ZERO:
		catalogo["objective"] = ponto
		opcoes["objective"] = "Walk toward current mission marker for up to 15 seconds"
		var rota: Dictionary = estado.get("route", {})
		if bool(rota.get("reachable", false)) and rota.get("next") != null:
			catalogo["follow_route"] = ponto
			opcoes["follow_route"] = "Follow the navigation-mesh route (state.route) to the current objective target, turning to face each waypoint and walking forward (no strafe), re-pathing every 0.5 s, for up to 15 seconds; %.1f units of path left" % float(rota.get("length", 0.0))
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
	var interior := str(estado.get("interior", ""))
	if interior != "" and interior != "casa":
		# A igreja, o casarão e as casas por dados saem pela mesma regra da casa herdada (#191).
		var sala_atual: Node3D = current_scene.get("interiores").sala_de(interior)
		if sala_atual != null:
			catalogo["exit_room"] = sala_atual
			opcoes["exit_room"] = "Walk to the inside threshold of this room (%s), then cross the exterior doorway using W" % interior
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
		# Não é passo lateral: o viajante vira o corpo para o rumo e anda para a frente
		# (giro suave, #209). O nome só diz para que lado da câmera ele vai.
		opcoes["run_" + rumo] = "Turn toward the " + rumo + " side of the camera and run that way for 4 seconds (the body faces where it goes; no sideways stepping); this direction is clear nearby"
		opcoes["walk_" + rumo] = "Turn toward the " + rumo + " side of the camera and walk that way for 2 seconds (the body faces where it goes; no sideways stepping); try another direction if the previous movement was blocked"
	opcoes["wait"] = "Wait 4 seconds for dialogue/narration or stamina recovery"
	_marcar_alvos_fora_do_comodo(estado, opcoes)
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
		"enter_home", "exit_home", "exit_room":
			var sala: Node3D = catalogo.get(escolha)
			if sala == null or sala.trancada():
				return "home_door_locked_or_unavailable"
			var saindo := escolha != "enter_home"
			var fora: Vector3 = sala.soleira_de_dentro() if saindo else sala.soleira_de_fora()
			var jogador: Node3D = current_scene.get("player")
			if Vector2(jogador.global_position.x - fora.x, jogador.global_position.z - fora.z).length() > 0.6:
				var chegada := await _caminhar(fora, false, true, saindo)
				if chegada != "arrived":
					return chegada
			return await _caminhar(sala.soleira_de_fora() if saindo else sala.soleira_de_dentro(), false, true, true)
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
		var direcoes := {"forward": Vector3.FORWARD, "backward": Vector3.BACK, "left": Vector3.LEFT, "right": Vector3.RIGHT}
		if not direcoes.has(rumo):
			return "action_unavailable"
		jogador._cancel_walk()
		if bool(jogador.get("_run_toggled")) != correr:
			await _tecla(KEY_SHIFT)
		# ANDAR RUMO A (#209): o testador não aperta A, D ou S. O lado da câmera vira um ponto no
		# chão, o corpo vira para ele e só o W é apertado, como em `follow_route`.
		var visada := Basis(Vector3.UP, float(jogador.get("_yaw"))) * (direcoes[rumo] as Vector3)
		jogada.virar_para(inicio + visada * 10.0)
		_pressionar(KEY_W, true)
		await _esperar(4.0 if correr else 2.0)
		_pressionar(KEY_W, false)
		await process_frame
		var andou := jogador.global_position.distance_to(inicio)
		if andou < 0.3:
			return "movement_blocked_no_displacement_try_other_direction"
		return "moved_%.1f_units" % andou
	if not catalogo.has(escolha) or not _no_vale():
		return "action_unavailable"
	visitas[escolha] = int(visitas.get(escolha, 0)) + 1
	if escolha == "follow_route":
		return await _seguir_rota()
	return await _caminhar(catalogo[escolha], escolha == "follow_pedro")


func _amostrar_movimento(forcar: bool = false) -> void:
	if not _no_vale() or inicio_jogo < 0 or not bool(current_scene.get("carga_ok")) or (not forcar and Time.get_ticks_msec() < amostrar_em):
		return
	var jogador: Node3D = current_scene.get("player")
	amostras_movimento.append({"seconds": (Time.get_ticks_msec() - inicio_jogo) / 1000.0, "position": _vetor(jogador.global_position)})
	amostrar_em = Time.get_ticks_msec() + 500
	_conferir_dentro_de_geometria(jogador)


## O CENTRO DO VIAJANTE DENTRO DE UMA MALHA OPACA (#205): perto de uma construção, a casca dela vai
## para uma camada de auditoria e o peito do viajante é conferido contra ela. Fora do cômodo e do
## corredor da porta (a porta atravessa a casca de propósito), é colisão que deixou entrar na parede,
## e o testador registra "player_inside_geometry".
func _conferir_dentro_de_geometria(jogador: Node3D) -> void:
	var mundo = current_scene.get("world")
	var interiores = current_scene.get("interiores")
	if mundo == null:
		return
	var construcoes = mundo.get("construcoes")
	if not (construcoes is Dictionary):
		return
	if interiores != null:
		if str(interiores.contem(jogador.global_position)) != "":
			return
		for qual in interiores.quais():
			var sala = interiores.sala_de(str(qual))
			if sala != null and sala.no_vao(jogador.global_position):
				return
	var espaco: PhysicsDirectSpaceState3D = mundo.get_world_3d().direct_space_state
	var peito := jogador.global_position + Vector3.UP * 0.9
	for nome in construcoes:
		var modelo = (construcoes[nome] as Dictionary).get("modelo")
		if not (modelo is Node3D) or not is_instance_valid(modelo):
			continue
		var longe := Vector2(jogador.global_position.x - (modelo as Node3D).global_position.x, jogador.global_position.z - (modelo as Node3D).global_position.z).length()
		var casca = cascas_auditadas.get(nome)
		if longe > 40.0:
			if casca != null:
				if is_instance_valid(casca.corpo):
					casca.corpo.queue_free()
				cascas_auditadas.erase(nome)
			continue
		if longe > 12.0:
			continue
		if casca == null:
			cascas_auditadas[nome] = {"corpo": AuditoriaDeGeometria.corpo_da_casca(mundo, modelo), "desde": Engine.get_physics_frames()}
			continue
		if Engine.get_physics_frames() - int(casca.desde) < 3:
			continue
		if AuditoriaDeGeometria.dentro_da_malha(espaco, peito) and _segundos() - float(dentro_de_geometria_visto.get(nome, -100.0)) > 10.0:
			achados.append({"type": "player_inside_geometry", "building": str(nome), "position": _vetor(jogador.global_position), "action": ultima_acao})
			if achados.size() > 6:
				achados.pop_front()
			dentro_de_geometria_visto[nome] = _segundos()


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
	while not _cede() and Time.get_ticks_msec() - comeco < (12000 if seguir else 15000):
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
	while not _cede() and not paused and not root.get_node("Dialogo").ativo and Time.get_ticks_msec() < limite:
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
				# Desentalar sem passo lateral (#209): vira o corpo 60 graus para o lado e segue com o W.
				var para: Vector3 = rumo - jogador.global_position
				para.y = 0.0
				if para.length() > 0.05:
					jogada.virar_para(jogador.global_position + para.rotated(Vector3.UP, -PI / 3.0))
				await _esperar(0.5)
			anterior = jogador.global_position
			verificar = Time.get_ticks_msec() + 500
		await physics_frame
	_pressionar(KEY_W, false)
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
	while Time.get_ticks_msec() < limite and not _cede() and not paused:
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
	while Time.get_ticks_msec() < fim and not _cede():
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
	# SÓ SE CAPTURA COM O VIAJANTE À VISTA (#201): encoberto, a câmera é reposicionada na hora
	# e o quadro sai depois de ela alcançar o ponto. O nome já vale, para os achados o citarem.
	if camera_do_teste != null and is_instance_valid(camera_do_teste) and camera_do_teste.liberar_ja():
		var nome := "quadro_%04d.jpg" % _segundos()
		ultima_captura = _segundos()
		_salvar_quadro_depois(nome)
		return nome
	return _salvar_quadro()


func _salvar_quadro() -> String:
	var imagem := root.get_texture().get_image()
	if imagem != null and not imagem.is_empty():
		# Evidência contínua em JPEG evita encher o disco numa campanha longa.
		var nome := "quadro_%04d.jpg" % _segundos()
		imagem.save_jpg(pasta.path_join(nome), 0.85)
		ultima_captura = _segundos()
		return nome
	return ""


## A câmera leva uns quadros para alcançar o ponto novo (o encaixe dela dura três ticks de física).
func _salvar_quadro_depois(nome: String) -> void:
	for _quadro in 6:
		await process_frame
	var imagem := root.get_texture().get_image()
	if imagem != null and not imagem.is_empty():
		imagem.save_jpg(pasta.path_join(nome), 0.85)


## O viajante ficou encoberto além do aceitável e a câmera não resolveu: vira achado do relatório.
func _ao_ficar_encoberto(segundos: float) -> void:
	var achado := {"type": "viajante_encoberto", "duration_s": snappedf(segundos, 0.1), "action": ultima_acao,
		"seconds": _segundos(), "position": _vetor(current_scene.get("player").global_position), "capture": _capturar()}
	achados.append(achado)
	if achados.size() > 6:
		achados.pop_front()
	print("JEV: viajante encoberto por %.1f s apos a acao %s" % [segundos, ultima_acao])
	_post("/achado", achado)


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


# --- o guia e os cômodos (#191) --------------------------------------------------

## O Pedro ainda conduz? Durante o tutorial, ou quando uma fila dele pede (a jornada da
## fazenda). Fora disso ele fica no posto, e não há o que seguir.
func _guia_conduz(pedro: Node3D) -> bool:
	if not pedro.has_method("terminou_o_tutorial"):
		return true
	return not pedro.terminou_o_tutorial() or pedro._outra_que_conduz() != null


## Dentro de um cômodo, quais destinos do catálogo ficam do lado de fora dele. O robô
## sai pela porta antes de qualquer um deles: andar em linha reta para o outro lado da
## parede é o que o prendia no canto da casa. A igreja e o casarão valem igual.
func _marcar_alvos_fora_do_comodo(estado: Dictionary, opcoes: Dictionary) -> void:
	var dentro := str(estado.get("interior", ""))
	if dentro.is_empty():
		return
	var sala: Node3D = current_scene.get("interiores").sala_de(dentro)
	if sala == null:
		return
	var fora: Array = []
	for id in opcoes:
		if str(id).begins_with("exit_") or str(id).begins_with("enter_") or not catalogo.has(id):
			continue
		var alvo = catalogo[id]
		var ponto := Vector3.INF
		if alvo is Vector3:
			ponto = alvo
		elif alvo is Node3D:
			ponto = (alvo as Node3D).global_position
		if ponto.is_finite() and not sala.contem(ponto, 0.5):
			fora.append(str(id))
	estado["room"] = {"name": dentro, "inside_threshold": _vetor(sala.soleira_de_dentro()),
		"outside_threshold": _vetor(sala.soleira_de_fora()), "outside_targets": fora}


# --- a rota pela malha (#240) ----------------------------------------------------

## O alvo do objetivo de agora (o mesmo do `objective`), ou INF.
func _alvo_do_objetivo() -> Vector3:
	var ponto = root.get_node("CadernoDoVale").atual().get("alvo", Vector3.INF)
	if ponto is Vector3 and (ponto as Vector3).is_finite() and ponto != Vector3.ZERO:
		return ponto
	return Vector3.INF


## O caminho pela malha de navegação do vale (a dos moradores: `navegacao_vale.gd`, que usa
## `NavigationServer3D.map_get_path`); sem ela pronta, a grade do clique do jogador.
func _caminho_da_rota(de: Vector3, para: Vector3) -> PackedVector3Array:
	var navegacao = current_scene.get("navegacao")
	var pontos := PackedVector3Array()
	if navegacao != null and is_instance_valid(navegacao) and navegacao.esta_pronta():
		pontos = navegacao.caminho(de, para)
	if pontos.size() < 2 and jogada != null:
		pontos = jogada.caminho_ate(para, de)
	return pontos


static func _no_plano(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## A rota do viajante ao alvo do objetivo, para a ponte: os pontos, o próximo, se chega e o tamanho.
func _rota() -> Dictionary:
	var objetivo: Dictionary = root.get_node("CadernoDoVale").atual()
	var rota := {"target": null, "target_name": str(objetivo.get("titulo", "")), "points": [], "next": null,
		"reachable": false, "length": 0.0}
	var alvo := _alvo_do_objetivo()
	if not alvo.is_finite():
		return rota
	rota["target"] = _vetor(alvo)
	var jogador: Node3D = current_scene.get("player")
	var de := jogador.global_position
	var pontos := _caminho_da_rota(de, alvo)
	if pontos.is_empty():
		return rota
	var lista: Array = []
	var comprimento := 0.0
	var anterior := de
	var proximo = null
	for p in pontos:
		comprimento += _no_plano(anterior, p)
		anterior = p
		if proximo == null and _no_plano(p, de) >= 0.7:
			proximo = _vetor(p)
		if lista.size() < 48:
			lista.append(_vetor(p))
	rota["points"] = lista
	rota["next"] = proximo if proximo != null else _vetor(pontos[pontos.size() - 1])
	rota["length"] = snappedf(comprimento, 0.1)
	rota["reachable"] = _no_plano(pontos[pontos.size() - 1], alvo) <= 2.5
	return rota


## SEGUIR A ROTA: de ponto em ponto da malha, virando o corpo para cada um e andando para a
## frente (W, sem passo lateral, #209), recalculando a cada meio segundo, por até 15 s.
func _seguir_rota() -> String:
	var jogador: Node3D = current_scene.get("player")
	jogador._cancel_walk()
	if bool(jogador.get("_run_toggled")):
		await _tecla(KEY_SHIFT)
	var comeco := Time.get_ticks_msec()
	var ver_pos: Vector3 = jogador.global_position
	var ver_tempo := comeco
	var recalcular := 0
	var pontos := PackedVector3Array()
	var alvo := _alvo_do_objetivo()
	while not _cede() and Time.get_ticks_msec() - comeco < 15000:
		if Input.is_physical_key_pressed(KEY_F8):
			ultima_acao = "user_stop"
			parar = true
			break
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
		if Time.get_ticks_msec() >= recalcular:
			recalcular = Time.get_ticks_msec() + 500
			alvo = _alvo_do_objetivo()
			if not alvo.is_finite():
				_pressionar(KEY_W, false)
				return "no_route_target"
			pontos = _caminho_da_rota(jogador.global_position, alvo)
			if pontos.is_empty():
				_pressionar(KEY_W, false)
				return "no_navigation_path_target_unreachable"
		if _no_plano(jogador.global_position, alvo) < 1.2:
			_pressionar(KEY_W, false)
			jogada.virar_para(alvo)
			return "arrived_at_route_target"
		while pontos.size() > 1 and _no_plano(pontos[0], jogador.global_position) < 0.7:
			pontos.remove_at(0)
		jogada.virar_para(pontos[0] if not pontos.is_empty() else alvo)
		_pressionar(KEY_W, true)
		if Time.get_ticks_msec() - ver_tempo > 2000:
			if jogador.global_position.distance_to(ver_pos) < 0.3:
				achados.append({"type": "possible_stuck", "position": _vetor(jogador.global_position), "action": "follow_route"})
				if achados.size() > 6:
					achados.pop_front()
				_pressionar(KEY_W, false)
				return "possible_stuck_requires_review"
			ver_pos = jogador.global_position
			ver_tempo = Time.get_ticks_msec()
		await physics_frame
	_pressionar(KEY_W, false)
	await physics_frame
	return "walking_chunk_complete"


# --- o bloqueio (#183) -------------------------------------------------------------

## A ponte desistiu do passo: o testador para de agir e pergunta a quem assiste. Fora de
## cutscene; com uma tocando, o modal espera (e a contagem também). A escolha segue no estado
## do próximo pedido; "takeover" entra no controle manual do F7.
func _tratar_bloqueio(bloqueio: Dictionary) -> void:
	ultima_acao = "blocked_step"
	for tecla in TECLAS_DO_TESTADOR:
		_pressionar(tecla, false)
	if _no_vale() and current_scene.get("player") != null:
		current_scene.get("player")._cancel_walk()
	print("JEV: bloqueio em %s (%s); perguntando" % [str(bloqueio.get("step", "")), str(bloqueio.get("reason", ""))])
	var escolha := [""]
	var ouvir := func(valor: String) -> void: escolha[0] = valor
	modal_bloqueio.escolhido.connect(ouvir)
	var aberto := false
	var anterior := Time.get_ticks_msec()
	while escolha[0] == "" and not parar:
		var agora := Time.get_ticks_msec()
		var delta := (agora - anterior) / 1000.0
		anterior = agora
		if Input.is_physical_key_pressed(KEY_F8):
			if aberto:
				modal_bloqueio.escolher("stop")
			else:
				escolha[0] = "stop"
			break
		if _em_cutscene():
			modal_bloqueio.esconder_por_um_instante(true)
		elif not aberto:
			modal_bloqueio.abrir(bloqueio)
			aberto = true
		else:
			modal_bloqueio.esconder_por_um_instante(false)
			modal_bloqueio.avancar(delta)
		_atualizar_painel()
		_vigiar_o_relogio()
		await process_frame
	if modal_bloqueio.aberto():
		modal_bloqueio.escolher("stop")
	modal_bloqueio.escolhido.disconnect(ouvir)
	var final: String = escolha[0] if escolha[0] != "" else "stop"
	escolha_do_bloqueio = final
	print("JEV: bloqueio respondido: ", final)
	if final == "takeover" and not manual:
		_abrir_manual()
	_atualizar_painel()


# --- o menu e o idioma (#175, #180) -----------------------------------------------

## O menu que lançou a sessão só se fecha quando o vale abriu de verdade: o arquivo de pronto
## (caminho em MV_JEV_PRONTO_VALE, posto pelo `abertura.gd`) nasce com a carga feita e a tela de
## carregamento fora, e não quando a janela da sessão aparece.
func _avisar_o_menu_que_o_vale_abriu() -> void:
	if pronto_avisado or not bool(current_scene.get("carga_ok")):
		return
	if not get_nodes_in_group("telas_de_carregamento").is_empty():
		return
	pronto_avisado = true
	var caminho := OS.get_environment("MV_JEV_PRONTO_VALE")
	print("JEV_PRONTO: vale carregado; idioma=", TranslationServer.get_locale())
	if caminho.is_empty():
		return
	var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
	if arquivo == null:
		push_warning("JEV: não foi possível gravar o aviso de pronto em " + caminho)
		return
	arquivo.store_string("ok")
	arquivo.close()


## O idioma da sessão vale ao vivo: se algo o trocou (ou a cena nova nasceu com outro locale),
## a escolha do menu é reaplicada.
func _garantir_idioma() -> void:
	if idioma_pedido < 0:
		return
	if int(idioma.indice()) != idioma_pedido:
		print("JEV: idioma da sessão reaplicado (%s)" % idioma.LOCALES[idioma_pedido])
		idioma.definir(idioma_pedido)
	elif TranslationServer.get_locale() != str(idioma.LOCALES[idioma_pedido]):
		idioma.aplicar_jogo()
