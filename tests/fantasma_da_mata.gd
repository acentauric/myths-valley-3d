extends SceneTree
## Confere O VULTO DA MATA: o susto que fecha o jogo de mentira.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/fantasma_da_mata.gd
##
## "adicione um fantasma na floresta que aparece aleatoriamente e fecha o jogo ao correr em direção ao
## personagem... vai parecer um bug mas não é (se o personagem não tirar a câmera da direção, ele some,
## mas se ficar de costas na mata para ele, ele te pega)."
##
## O PERIGO DESTE PORTÃO é o `quit()`: um portão que fecha o jogo sai com código 0 e PASSA — o runner
## julga por código de saída e por `FALHA:`. Por isso o vulto tem `salvar` e `sair` como gravadores
## nos portões, o `quit()` de verdade recusa em tela nenhuma, e este portão avisa `FALHA:` se o jogo
## fechar antes do fim dele (`tree_exiting`).
##
## Oito perguntas:
##
##   1. SÓ NO FUNDO DA MATA: o vulto só aparece onde `mata_funda.gd` diz que é fundo — nunca na vila,
##      na praça, perto de rua, de clareira ou de casa — e a 20 a 35 u do jogador, por trás da
##      câmera, FORA da vista e com a linha livre (virar a câmera serve).
##   2. AS GUARDAS, uma a uma, cada uma com a prova de que sem ela o vulto apareceria: sustos
##      desligados, edição Tripothon, sem tela, sessão curta, tutorial, fala ou tela aberta, casa,
##      nado, caçada de onça, fora da mata, já apareceu, esfriando (guardado em disco).
##   3. O SORTEIO: parado ou teleportado não conta tempo na mata; andando, sorteia — e chega.
##   4. OLHAR GANHA: com a câmera nele, ele some em menos de 1,6 s, não chega mais perto e NADA é salvo
##      nem fechado. Tronco no meio não deixa olhar.
##   5. DE COSTAS, ELE PEGA: o `pegou` sai UMA vez, `salvar` e depois `sair`, nessa ordem, com o jogo
##      congelado e mudo entre os dois.
##   6. DESLIGAR NO MEIO ABORTA: com o vulto no ar, desligar os Sustos o desfaz sem pegar ninguém.
##   7. NUNCA DUAS VEZES: nem na mesma sessão, nem em outro vale, nem logo depois (esfriando).
##   8. O SOM E O CORPO: o sussurro toca no mundo ao aparecer, o avanço ao disparar; e há corpo (túnica,
##      braços, olhos).
##
## FALSIFICAÇÃO: com `OLHAR_PARA_SUMIR` enorme (`fantasma_da_mata.gd`), a 4 reprova; com o `salvar` tirado
## de `_pegar`, a 5 reprova; com a guarda de `sem_tela` tirada de `_fechar_de_verdade`, o jogo fecha e o
## portão grita FALHA.

const RelogioDeJogo = preload("res://tests/fixtures/relogio_de_jogo.gd")

var falhas := 0
var relogio: Node
var MataFunda
var SustosDaMata
var Fantasma
var _concluido := false
## O perfil de quem roda o portão à mão: o valor da chave Sustos e o `user://sustos.cfg` de antes, devolvidos no fim.
## (O runner dá a cada portão um perfil só dele; a mão não, e apagar `preferencias_visuais.cfg` seria apagar o de verdade.)
var _chave_de_antes: Variant = null
var _esfriar_existia := false
var _esfriar_de_antes := ""


func _initialize() -> void:
	root.tree_exiting.connect(_ao_fechar)
	_run.call_deferred()


func _ao_fechar() -> void:
	if not _concluido:
		print("FALHA: o jogo FECHOU no meio do portão (um quit() de verdade, num portão: falso verde)")


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("FANTASMA_DA_MATA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(6)
	relogio = RelogioDeJogo.new()
	root.add_child(relogio)
	relogio.ficar_lento()
	MataFunda = load("res://scripts/prototipo_3d/mata_funda.gd")
	SustosDaMata = load("res://scripts/prototipo_3d/sustos_da_mata.gd")
	Fantasma = load("res://scripts/prototipo_3d/fantasma_da_mata.gd")
	_guardar_o_perfil()

	var jogo := current_scene
	var world = jogo.get("world")
	var jogador = jogo.get("player")
	var vulto: Node3D = jogo.get_node_or_null("FantasmaDaMata")
	_conferir(vulto != null, "o vale não montou o vulto da mata (sustos_da_mata.gd)")
	if vulto == null or world == null or jogador == null:
		_fechar()
		return
	var dia := root.get_node("/root/Dia")
	# O estado de partida do gate: chave na fábrica, ligada, o vulto "à solta" mas sem fechar nada.
	SustosDaMata.forcar_edicao = 0
	SustosDaMata.definir_ligado(true)
	Fantasma.forcar_para_o_portao = true
	var eventos: Array[String] = []
	var momentos: Array[int] = []
	vulto.salvar = func() -> bool:
		eventos.append("salvar")
		momentos.append(Time.get_ticks_msec())
		return true
	vulto.sair = func() -> void:
		eventos.append("sair")
		momentos.append(Time.get_ticks_msec())
	var sumidos: Array[String] = []
	vulto.sumiu.connect(func(porque: String) -> void: sumidos.append(porque))
	var pegou: Array[int] = []
	vulto.pegou.connect(func() -> void: pegou.append(1))
	var apareceu: Array[Vector3] = []
	vulto.apareceu.connect(func(onde: Vector3) -> void: apareceu.append(onde))
	_reiniciar(vulto)
	# O tutorial do Pedro, no vale de verdade, ainda está em curso: o vulto não nasce (a guarda do
	# fiado do vale montado). O resto do portão o dá por acabado.
	vulto.sessao_s = 1000.0
	var tutorial_do_vale: Callable = vulto._tutorial_acabou
	_conferir(not bool(tutorial_do_vale.call()), "o tutorial do Pedro já estava acabado num vale novo")
	var tutorial_acabado := func() -> bool: return true
	vulto._tutorial_acabou = tutorial_acabado

	# --- 1. SÓ NO FUNDO DA MATA --------------------------------------------------
	var fundo := _achar_o_fundo(world)
	_conferir(fundo != Vector3.INF, "não achei um ponto de mata funda com mata funda em volta")
	if fundo == Vector3.INF:
		_fechar()
		return
	var praca: Vector3 = world.ancoras.get("Praça", Vector3.ZERO)
	_conferir(not MataFunda.e_funda(world, praca), "a praça é mata funda")
	var regiao = world.get("_region")
	_conferir(not MataFunda.e_funda(world, _no_chao(world, Vector3(regiao.clareiras_da_mata[0]["centro"].x, 0.0, regiao.clareiras_da_mata[0]["centro"].y))), "uma clareira é mata funda")
	var na_rua: Vector2 = (regiao._roads[0]["points"] as PackedVector2Array)[3]
	_conferir(not MataFunda.e_funda(world, _no_chao(world, Vector3(na_rua.x, 0.0, na_rua.y))), "o meio de uma rua é mata funda")
	var casas := 0
	for nome: Variant in world.ancoras:
		var onde: Variant = world.ancoras[nome]
		if onde is Vector3 and not String(nome).ends_with("Frente"):
			casas += 1
			if MataFunda.e_funda(world, _no_chao(world, onde)):
				_conferir(false, "a âncora '%s' (casa ou lugar) é mata funda" % nome)
	_conferir(casas >= 5, "só %d âncoras para conferir" % casas)
	# O mundo todo: nenhum ponto "fundo" perto da vila (30 u do contorno) nem da rua (24 u) — varredura.
	var perto_demais := _varrer_o_fundo(world)
	_conferir(perto_demais == "", "ponto 'fundo' perto demais do que não é mata: " + perto_demais)

	jogador.teleportar(fundo, 0.0)
	await relogio.esperar(0.6)
	vulto.sessao_s = 1000.0
	var livre_logo: bool = await relogio.ate(func() -> bool: return SustosDaMata.jogo_livre(jogo), 25.0)
	_conferir(livre_logo, "o vale não ficou livre em 25 s de jogo: o controle das guardas não vale (alguma tela ou fala ficou aberta)")
	var camera: Camera3D = jogador.camera
	var distancias: Array[float] = []
	var dentro := 0
	for n in range(10):
		_reiniciar(vulto)
		if not vulto.aparecer():
			continue
		dentro += 1
		var lugar: Vector3 = vulto.global_position
		var plano := Vector2(lugar.x - jogador.global_position.x, lugar.z - jogador.global_position.z)
		distancias.append(plano.length())
		_conferir(plano.length() >= 19.9 and plano.length() <= 35.1, "o vulto apareceu a %.1f u: o pedido é de 20 a 35" % plano.length())
		_conferir(MataFunda.e_funda(world, lugar), "o vulto apareceu fora da mata funda (%s)" % MataFunda.porque_nao(world, lugar))
		var frente := -camera.global_basis.z
		frente.y = 0.0
		frente = frente.normalized()
		var graus := rad_to_deg(frente.angle_to(Vector3(plano.x, 0.0, plano.y).normalized()))
		_conferir(graus >= 99.0, "o vulto apareceu a %.0f graus da frente da câmera: devia ser por trás (100 a 180)" % graus)
		_conferir(not camera.is_position_in_frustum(lugar + Vector3(0.0, 1.0, 0.0)), "o vulto apareceu NA vista do jogador")
		_conferir(MataFunda.linha_livre(vulto, world, jogador.global_position + Vector3(0.0, 1.7, 0.0), lugar + Vector3(0.0, 1.2, 0.0), [jogador.get_rid()]),
			"o vulto apareceu atrás de um tronco: virar a câmera não adiantaria")
		_conferir(vulto.estado == Fantasma.Estado.APARECENDO, "o vulto não começou aparecendo")
	_conferir(dentro >= 8, "o vulto só achou lugar %d de 10 vezes" % dentro)
	print("  aparições de teste: %d, distância de %.1f a %.1f u" % [dentro, distancias.min() if not distancias.is_empty() else 0.0, distancias.max() if not distancias.is_empty() else 0.0])

	# --- 2. AS GUARDAS -----------------------------------------------------------
	_reiniciar(vulto)
	jogador.teleportar(fundo, 0.0)
	await relogio.ate(func() -> bool: return SustosDaMata.jogo_livre(jogo), 20.0)
	vulto.sessao_s = 1000.0
	_conferir(String(vulto.porque_nao()) == "", "(controle) com tudo liberto o vulto devia poder aparecer, e a guarda disse '%s'" % vulto.porque_nao())
	# Cada guarda: fecha, diz o motivo certo, e ABRE de novo ao soltar (a prova de que era ela).
	SustosDaMata.definir_ligado(false)
	_conferir(vulto.porque_nao() == "desligado", "com os Sustos desligados a guarda disse '%s'" % vulto.porque_nao())
	SustosDaMata.definir_ligado(true)
	_conferir(vulto.porque_nao() == "", "religar os Sustos não abriu a guarda: '%s'" % vulto.porque_nao())
	# A edição Tripothon nasce DESLIGADA: sem escolha do jogador, a chave é falsa; com a escolha, a escolha vale.
	_limpar_a_chave()
	SustosDaMata.forcar_edicao = 1
	_conferir(not SustosDaMata.ligado() and not SustosDaMata.padrao_de_fabrica(), "na edição Tripothon os Sustos nasceram ligados")
	_conferir(vulto.porque_nao() == "desligado", "na edição Tripothon o vulto não ficou calado ('%s')" % vulto.porque_nao())
	SustosDaMata.definir_ligado(true)
	_conferir(vulto.porque_nao() == "", "na edição Tripothon, ligar em AJUSTAR não valeu ('%s')" % vulto.porque_nao())
	_limpar_a_chave()
	SustosDaMata.forcar_edicao = 0
	_conferir(SustosDaMata.ligado() and SustosDaMata.padrao_de_fabrica(), "fora do Tripothon os Sustos nasceram desligados")
	Fantasma.forcar_para_o_portao = false
	if DisplayServer.get_name() == "headless":
		_conferir(vulto.porque_nao() == "sem_tela", "sem tela (o portão) a guarda disse '%s'" % vulto.porque_nao())
	Fantasma.forcar_para_o_portao = true
	vulto.sessao_s = 10.0
	_conferir(vulto.porque_nao() == "sessao_curta", "com 10 s de sessão a guarda disse '%s'" % vulto.porque_nao())
	vulto.sessao_s = 1000.0
	vulto._tutorial_acabou = tutorial_do_vale
	_conferir(vulto.porque_nao() == "tutorial", "com o tutorial em curso a guarda disse '%s'" % vulto.porque_nao())
	vulto._tutorial_acabou = tutorial_acabado
	dia.segurar("teste_do_vulto")
	_conferir(vulto.porque_nao() == "tela_aberta", "com uma fala segurando o relógio a guarda disse '%s'" % vulto.porque_nao())
	dia.soltar("teste_do_vulto")
	paused = true
	_conferir(vulto.porque_nao() == "tela_aberta", "com o jogo pausado a guarda disse '%s'" % vulto.porque_nao())
	paused = false
	jogador.dentro_de = "casa"
	_conferir(vulto.porque_nao() == "interior", "dentro de casa a guarda disse '%s'" % vulto.porque_nao())
	jogador.dentro_de = ""
	jogador._nadando = true
	_conferir(vulto.porque_nao() == "nadando", "nadando a guarda disse '%s'" % vulto.porque_nao())
	jogador._nadando = false
	var luta: Node = jogo.get_node_or_null("Luta")
	var script_da_onca := GDScript.new()
	script_da_onca.source_code = "extends Node\nvar cacando := true\n"
	script_da_onca.reload()
	var onca_falsa := Node.new()
	onca_falsa.set_script(script_da_onca)
	root.add_child(onca_falsa)
	luta.oncas.append(onca_falsa)
	_conferir(vulto.porque_nao() == "cacada", "com uma onça caçando a guarda disse '%s'" % vulto.porque_nao())
	luta.oncas.erase(onca_falsa)
	onca_falsa.queue_free()
	# Na praça os moradores falam e seguram o relógio: a guarda da mata é a que se mede aqui.
	var livre_antes: Callable = vulto._livre
	vulto._livre = func() -> bool: return true
	var da_vila: Vector3 = world.ground_position(Vector3(praca.x, 0.0, praca.z))
	jogador.teleportar(da_vila, 0.0)
	_conferir(vulto.porque_nao() == "fora_da_mata", "na praça a guarda disse '%s'" % vulto.porque_nao())
	vulto._livre = livre_antes
	jogador.teleportar(fundo, 0.0)
	await relogio.esperar(0.5)
	Fantasma.aparicoes_nesta_sessao = 1
	_conferir(vulto.porque_nao() == "ja_apareceu", "depois de uma aparição a guarda disse '%s'" % vulto.porque_nao())
	Fantasma.aparicoes_nesta_sessao = 0
	vulto._ultima_aparicao = Time.get_unix_time_from_system()
	_conferir(vulto.porque_nao() == "esfriando", "logo depois da última a guarda disse '%s'" % vulto.porque_nao())
	vulto._ultima_aparicao = 0.0
	_conferir(String(vulto.porque_nao()) == "", "soltas todas as guardas, a guarda ainda diz '%s'" % vulto.porque_nao())

	# --- 3. O SORTEIO ------------------------------------------------------------
	_reiniciar(vulto)
	jogador.velocity = Vector3.ZERO
	vulto._checar = 0.0
	vulto._vigiar(0.0)
	_conferir(vulto.fundo_s == 0.0, "parado, o jogador acumulou %.1f s de andança na mata" % vulto.fundo_s)
	jogador.velocity = Vector3(3.0, 0.0, 0.0)
	vulto._checar = 0.0
	vulto._vigiar(0.0)
	_conferir(vulto.fundo_s > 0.0, "andando na mata funda, a andança não contou")
	vulto.sessao_s = 10.0
	var antes: float = vulto.fundo_s
	vulto._checar = 0.0
	vulto._vigiar(0.0)
	_conferir(vulto.fundo_s == antes, "nos primeiros minutos da sessão a andança contou")
	vulto.sessao_s = 1000.0
	seed(1887)
	var rodadas := 0
	vulto.fundo_s = 1000.0
	while vulto.estado == Fantasma.Estado.DORMINDO and rodadas < 500:
		rodadas += 1
		vulto._sortear = 100.0
		vulto._checar = 0.0
		jogador.velocity = Vector3(3.0, 0.0, 0.0)
		vulto._vigiar(0.0)
	_conferir(vulto.estado != Fantasma.Estado.DORMINDO, "em %d sorteios o vulto nunca apareceu" % rodadas)
	_conferir(rodadas > 1, "o vulto apareceu no primeiro sorteio: não há acaso")
	print("  o sorteio acertou na rodada %d" % rodadas)
	jogador.velocity = Vector3.ZERO

	# --- 4. OLHAR GANHA ----------------------------------------------------------
	_reiniciar(vulto)
	sumidos.clear()
	eventos.clear()
	pegou.clear()
	jogador.teleportar(fundo, 0.0)
	await relogio.esperar(0.5)
	_conferir(vulto.aparecer(16.0), "o vulto não apareceu para o teste de olhar")
	var longe_antes := _plano(vulto.global_position - jogador.global_position).length()
	var olhar_desde: float = relogio.agora()
	var ate_sumir: float = 0.0
	var maior_distancia := longe_antes
	while relogio.agora() - olhar_desde < 4.0 and sumidos.is_empty():
		var para: Vector3 = vulto.global_position - jogador.global_position
		jogador.teleportar(jogador.global_position, atan2(para.x, para.z))
		await process_frame
		maior_distancia = maxf(maior_distancia, _plano(vulto.global_position - jogador.global_position).length())
		if sumidos.is_empty():
			ate_sumir = relogio.agora() - olhar_desde
	_conferir(sumidos.size() == 1 and sumidos[0] == "olhado", "olhado, o vulto devia sumir 'olhado' e foi: %s" % str(sumidos))
	_conferir(ate_sumir <= 1.6, "o vulto levou %.2f s para sumir olhado: o pedido é de uns 0,4 s" % ate_sumir)
	_conferir(maior_distancia <= longe_antes + 0.05, "o vulto chegou mais perto... ou mais longe (%.2f para %.2f) enquanto era olhado" % [longe_antes, maior_distancia])
	_conferir(pegou.is_empty() and eventos.is_empty(), "olhar o vulto salvou ou fechou o jogo: %s" % str(eventos))
	await relogio.ate(func() -> bool: return vulto.estado == Fantasma.Estado.DORMINDO, 3.0)
	_conferir(vulto.estado == Fantasma.Estado.DORMINDO and not vulto.visible, "o vulto não se desfez de vez depois de olhado")
	print("  olhado: sumiu em %.2f s, a %.1f u" % [ate_sumir, longe_antes])
	# Tronco no meio não deixa olhar: a linha entre dois pontos, com e sem um tronco entre eles.
	var tronco := _tronco_isolado(world)
	_conferir(tronco != Vector3.INF, "não achei um tronco isolado para o teste da linha livre")
	if tronco != Vector3.INF:
		var chao: float = world.ground_height_at(tronco)
		var de := Vector3(tronco.x - 4.0, chao + 1.5, tronco.z)
		var ate := Vector3(tronco.x + 4.0, chao + 1.5, tronco.z)
		_conferir(not MataFunda.linha_livre(vulto, world, de, ate), "a linha de um lado a outro de um tronco passou 'livre'")
		_conferir(MataFunda.linha_livre(vulto, world, de + Vector3(0.0, 0.0, 2.5), ate + Vector3(0.0, 0.0, 2.5)), "a linha ao lado do tronco passou 'tapada' (o controle da outra)")

	# --- 7. (parte) NUNCA DUAS VEZES, na mesma sessão ----------------------------
	_conferir(Fantasma.aparicoes_nesta_sessao >= 1, "a aparição não ficou contada na sessão")
	vulto.sessao_s = 1000.0
	_conferir(vulto.porque_nao() == "ja_apareceu", "depois de aparecer uma vez, a guarda disse '%s'" % vulto.porque_nao())
	_conferir(not vulto.aparecer(16.0), "o vulto apareceu duas vezes na mesma sessão")
	# E o guardado em disco: outro vale (nó novo) lê a hora da última e fica esfriando.
	var guardado := ConfigFile.new()
	_conferir(guardado.load("user://sustos.cfg") == OK and float(guardado.get_value("fantasma", "ultima", 0.0)) > 1.0e9, "a hora da aparição não foi guardada em user://sustos.cfg")
	var outro := Node3D.new()
	outro.set_script(Fantasma)
	jogo.add_child(outro)
	outro.configurar(world, jogador, vulto._livre, vulto._tutorial_acabou, luta)
	outro.sessao_s = 1000.0
	Fantasma.aparicoes_nesta_sessao = 0
	_conferir(outro.porque_nao() == "esfriando", "um vale novo logo depois da queda não esfriou: '%s'" % outro.porque_nao())
	outro.queue_free()

	# --- 6. DESLIGAR NO MEIO ABORTA ----------------------------------------------
	_reiniciar(vulto)
	sumidos.clear()
	eventos.clear()
	jogador.teleportar(fundo, 0.0)
	await relogio.esperar(0.5)
	_conferir(vulto.aparecer(30.0), "o vulto não apareceu para o teste de desligar")
	SustosDaMata.definir_ligado(false)
	await relogio.ate(func() -> bool: return not sumidos.is_empty(), 3.0)
	_conferir(sumidos.size() == 1 and sumidos[0] == "abortado", "desligar os Sustos com o vulto no ar devia desfazê-lo ('abortado') e foi: %s" % str(sumidos))
	_conferir(eventos.is_empty(), "desligar os Sustos salvou ou fechou: %s" % str(eventos))
	SustosDaMata.definir_ligado(true)

	# --- 8. O SOM E O CORPO ------------------------------------------------------
	_reiniciar(vulto)
	jogador.teleportar(fundo, 0.0)
	await relogio.esperar(0.5)
	_conferir(vulto.aparecer(16.0), "o vulto não apareceu para o teste do som")
	_conferir(_tocando(jogo, "fantasma_sussurro.mp3"), "o sussurro não tocou no mundo ao aparecer")
	_conferir(vulto.get_node_or_null("Corpo/Tunica") != null and (vulto.get_node("Corpo/Tunica") as MeshInstance3D).mesh.get_surface_count() == 1,
		"o vulto não tem túnica")
	var bracos := 0
	var olhos := 0
	for filho in vulto.get_node("Corpo").get_children():
		if (filho as MeshInstance3D).mesh is CapsuleMesh:
			bracos += 1
		elif (filho as MeshInstance3D).mesh is SphereMesh:
			olhos += 1
	_conferir(bracos == 2 and olhos == 2, "o vulto tem %d braços e %d olhos (o certo é 2 e 2)" % [bracos, olhos])
	_conferir(vulto._material != null and vulto._material.shader != null and String(vulto._material.shader.code).contains("dissolver"), "o vulto não tem o shader de névoa")

	# --- 5. DE COSTAS, ELE PEGA (a câmera NÃO se mexe: ele nasceu atrás dela) ----
	var avanco := false
	var t_aparecer: float = relogio.agora()
	var pegou_em := -1.0
	while relogio.agora() - t_aparecer < 14.0 and eventos.size() < 2:
		await process_frame
		avanco = avanco or _tocando(vulto, "fantasma_avanco.mp3")
		if pegou_em < 0.0 and not pegou.is_empty():
			pegou_em = relogio.agora()
	_conferir(pegou.size() == 1, "o vulto devia pegar UMA vez e pegou %d (sumiu: %s, estado %d, a %.1f u)" % [pegou.size(), str(sumidos), vulto.estado, _plano(vulto.global_position - jogador.global_position).length()])
	_conferir(eventos.size() == 2 and eventos[0] == "salvar" and eventos[1] == "sair", "de costas, o fim devia ser salvar e depois sair, e foi: %s" % str(eventos))
	_conferir(momentos.size() == 2 and momentos[1] - momentos[0] >= 250, "o jogo devia ficar congelado uns 0,35 s entre salvar e sair, e ficou %d ms" % (momentos[1] - momentos[0] if momentos.size() == 2 else -1))
	_conferir(avanco, "o som do avanço não tocou quando ele disparou")
	_conferir(paused, "na hora de fechar o jogo devia estar congelado")
	var master := AudioServer.get_bus_index(&"Master")
	_conferir(AudioServer.is_bus_mute(master), "na hora de fechar o som devia estar cortado")
	var camada_preta := false
	for no in root.get_children():
		if no is CanvasLayer and (no as CanvasLayer).layer == 200:
			camada_preta = true
	_conferir(camada_preta, "o preto do último quadro não foi posto na tela")
	print("  de costas: pegou em %.1f s de jogo; eventos %s" % [pegou_em - t_aparecer, str(eventos)])
	# Desfaz o congelamento da queda de mentira para fechar o portão em paz.
	paused = false
	AudioServer.set_bus_mute(master, false)
	for no in root.get_children():
		if no is CanvasLayer and (no as CanvasLayer).layer == 200:
			no.queue_free()
	await _frames(2)
	_conferir(Fantasma.aparicoes_nesta_sessao >= 1 and vulto.porque_nao() == "ja_apareceu", "depois de pegar, a guarda disse '%s'" % vulto.porque_nao())

	# --- A GUARDA DO PORTÃO: o `quit()` de verdade recusa onde não há tela -------
	Fantasma.forcar_para_o_portao = false
	vulto._fechar_de_verdade()
	await _frames(2)
	Fantasma.forcar_para_o_portao = true
	# Se a guarda não existisse, o jogo teria fechado aqui, e o `tree_exiting` do portão gritaria FALHA.

	SustosDaMata.forcar_edicao = -1
	Fantasma.forcar_para_o_portao = false
	Fantasma.aparicoes_nesta_sessao = 0
	_fechar()


func _fechar() -> void:
	_concluido = true
	_devolver_o_perfil()
	print("")
	if falhas == 0:
		print("FANTASMA_DA_MATA_OK: o vulto só aparece no fundo da mata, por trás da câmera e fora da vista; cada guarda o segura (sustos desligados, edição Tripothon, sem tela, sessão curta, tutorial, fala, casa, nado, onça, fora da mata, já apareceu, esfriando em disco); o sorteio só conta andança; olhado, ele some e nada fecha; de costas, ele pega, salva e fecha nessa ordem, congelado e mudo; desligar no meio o aborta; nunca duas vezes")
	else:
		print("fantasma_da_mata: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _guardar_o_perfil() -> void:
	var preferencias := ConfigFile.new()
	if preferencias.load(SustosDaMata.PREFERENCIAS) == OK and preferencias.has_section_key("interface", "sustos"):
		_chave_de_antes = preferencias.get_value("interface", "sustos")
	_esfriar_existia = FileAccess.file_exists(Fantasma.ARQUIVO_DO_ESFRIAR)
	if _esfriar_existia:
		_esfriar_de_antes = FileAccess.get_file_as_string(Fantasma.ARQUIVO_DO_ESFRIAR)


## Tira só a chave Sustos das preferências (a fábrica volta a valer), sem apagar o resto do arquivo.
func _limpar_a_chave() -> void:
	var preferencias := ConfigFile.new()
	if preferencias.load(SustosDaMata.PREFERENCIAS) == OK and preferencias.has_section_key("interface", "sustos"):
		preferencias.erase_section_key("interface", "sustos")
		preferencias.save(SustosDaMata.PREFERENCIAS)


func _devolver_o_perfil() -> void:
	if SustosDaMata == null:
		return
	_limpar_a_chave()
	if _chave_de_antes != null:
		SustosDaMata.definir_ligado(bool(_chave_de_antes))
	if _esfriar_existia:
		var arquivo := FileAccess.open(Fantasma.ARQUIVO_DO_ESFRIAR, FileAccess.WRITE)
		if arquivo != null:
			arquivo.store_string(_esfriar_de_antes)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Fantasma.ARQUIVO_DO_ESFRIAR))
	Fantasma.forcar_para_o_portao = false
	Fantasma.aparicoes_nesta_sessao = 0
	SustosDaMata.forcar_edicao = -1


func _reiniciar(vulto: Node3D) -> void:
	vulto.estado = Fantasma.Estado.DORMINDO
	vulto.visible = false
	vulto.olhado_s = 0.0
	vulto.vida_s = 0.0
	vulto.fundo_s = 0.0
	vulto._sortear = 0.0
	vulto._ultima_aparicao = 0.0
	vulto.dissolver = 1.0
	Fantasma.aparicoes_nesta_sessao = 0


func _plano(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _no_chao(world, p: Vector3) -> Vector3:
	return Vector3(p.x, world.ground_height_at(p), p.z)


func _tocando(no: Node, arquivo: String) -> bool:
	for filho in no.get_children():
		if filho is AudioStreamPlayer3D and (filho as AudioStreamPlayer3D).stream != null and (filho as AudioStreamPlayer3D).stream.resource_path.ends_with(arquivo):
			return true
	return false


## O primeiro ponto de mata funda com, a 27 u dele, mata funda em pelo menos 20 de 24 direções.
func _achar_o_fundo(world) -> Vector3:
	var quadro: Rect2 = world.get_map_frame()
	var x := quadro.position.x
	while x <= quadro.end.x:
		var z := quadro.position.y
		while z <= quadro.end.y:
			var p := _no_chao(world, Vector3(x, 0.0, z))
			if MataFunda.e_funda(world, p):
				var vizinhas := 0
				for k in range(24):
					var a := TAU * float(k) / 24.0
					if MataFunda.e_funda(world, _no_chao(world, p + Vector3(cos(a), 0.0, sin(a)) * 27.0)):
						vizinhas += 1
				if vizinhas >= 20:
					return p
			z += 16.0
		x += 16.0
	return Vector3.INF


## Na terra toda, de 18 em 18 u: todo ponto "fundo" está a 24 u de rua e a 30 u da vila.
func _varrer_o_fundo(world) -> String:
	var regiao = world.get("_region")
	var quadro: Rect2 = world.get_map_frame()
	var x := quadro.position.x
	var fundos := 0
	while x <= quadro.end.x:
		var z := quadro.position.y
		while z <= quadro.end.y:
			var p := _no_chao(world, Vector3(x, 0.0, z))
			if MataFunda.e_funda(world, p):
				fundos += 1
				var plano := Vector2(p.x, p.z)
				if MataFunda._distancia_as_ruas(regiao, plano, 24.0) < 23.9:
					return "(%.0f, %.0f) a %.1f u de rua" % [x, z, MataFunda._distancia_as_ruas(regiao, plano, 24.0)]
				if regiao._village.size() >= 3 and (Geometry2D.is_point_in_polygon(plano, regiao._village) or MataFunda._distancia_ao_contorno(plano, regiao._village) < 29.9):
					return "(%.0f, %.0f) dentro ou a menos de 30 u da vila" % [x, z]
			z += 18.0
		x += 18.0
	return "" if fundos > 50 else "só %d pontos de mata funda na varredura" % fundos


## Um tronco sem outro a 8 u, no fundo da mata: o teste da linha livre não pode ter outro no caminho.
func _tronco_isolado(world) -> Vector3:
	var regiao = world.get("_region")
	for tronco: Dictionary in regiao._tree_trunks:
		if bool(tronco.get("cortado", false)) or float(tronco["radius"]) < 0.3:
			continue
		var ponto: Vector2 = tronco["point"]
		var p := Vector3(ponto.x, world.ground_height_at(Vector3(ponto.x, 0.0, ponto.y)), ponto.y)
		if MataFunda.troncos_em_volta(world, p, 8.0) == 1:
			return p
	return Vector3.INF


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
