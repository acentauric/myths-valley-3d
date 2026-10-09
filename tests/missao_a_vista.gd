extends SceneTree
## A MISSÃO À VISTA (08/10: "continuo sem missões depois da introdução à vila; eu preciso falar
## com o NPC para destravar, mas isso não é óbvio para o jogador. Precisa seguir boas práticas de
## jogos de RPG e colocar uma exclamação em cima da cabeça do NPC com quest disponível. Também
## deve ter uma tela resumo sobre a missão para o jogador aceitar ela ou não").
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/missao_a_vista.gd
##
##   1. O "!" SOBRE A CABEÇA: acabada a chegada, o Pedro tem a ponte por abrir no E dele — o
##      marcador dele diz "!" e está à vista. O Tonho, com o passo da rede esperando a entrega
##      (tudo na mochila), diz "?". Quem não tem fila por abrir nem passo que o procure, nada.
##   2. A TELA DE ACEITE: o E no Pedro não abre a ponte na hora — abre a tela, com o vale parado,
##      o nome da missão, quem pede e a recompensa somada; recusar fecha sem começar nada, e o
##      "!" fica; aceitar começa a fila, o "!" some e o HUD diz o primeiro passo.

const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("MISSAO_A_VISTA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(4)
	await _mundo_pronto()
	await _frames(6)
	var vale = current_scene
	if vale.get("cenas") != null:
		vale.cenas.desligadas = true
	var pedro = vale.pedro
	var tecla = vale.get("tecla_dos_moradores")
	var aceite = vale.get("aceite")
	var inv = root.get_node("/root/Inventario")
	_conferir(pedro != null and tecla != null and aceite != null, "o vale não tem o Pedro, a tecla dos moradores ou a tela de aceite")
	if pedro == null or tecla == null or aceite == null:
		_fechar()
		return

	# --- 1. O "!" SOBRE A CABEÇA ---------------------------------------------------------------
	var guia = pedro._cadeia
	guia.iniciado = true
	guia.missao = guia.passos.size()
	guia.despedida_feita = true
	_conferir(pedro.terminou_o_tutorial(), "não consegui dar a chegada por acabada")
	var ponte = vale._cadeias.get("pedro_ponte")
	_conferir(ponte != null and str(ponte.o_que_o_e_faz(pedro)) == "abrir", "acabada a chegada, a ponte não está por abrir no E do Pedro")
	var tonho = vale._achar_morador("tonho")
	var rede = vale._cadeias.get("tonho")
	if tonho != null and rede != null and rede.passos.size() >= 2:
		rede.iniciado = true
		rede.missao = 1
		rede.espera = 0.0
		inv.adicionar("corda", 5)
		inv.adicionar("tabua", 3)
	await _ate(func() -> bool: return str(pedro.marcador_de_missao()) == "!", 2.0)
	var marcador: Node3D = pedro.get("_marcador")
	_conferir(str(pedro.marcador_de_missao()) == "!", "o Pedro tem a ponte por abrir e o marcador dele diz '%s', e não '!'" % str(pedro.marcador_de_missao()))
	_conferir(marcador != null and marcador.visible and marcador is Label3D and (marcador as Label3D).text == "!",
		"o '!' do Pedro não está à vista sobre a cabeça dele")
	_conferir(marcador != null and marcador.position.y > float(pedro.altura), "o marcador não está acima da cabeça (y %.2f, altura %.2f)" % [marcador.position.y if marcador != null else 0.0, float(pedro.altura)])
	if tonho != null and rede != null:
		await _ate(func() -> bool: return str(tonho.marcador_de_missao()) == "?", 2.0)
		_conferir(str(tonho.marcador_de_missao()) == "?", "o Tonho espera a rede com tudo na mochila e o marcador dele diz '%s', e não '?'" % str(tonho.marcador_de_missao()))
	var sem_nada := 0
	for morador in vale.moradores:
		if str(morador.marcador_de_missao()) == "":
			sem_nada += 1
	_conferir(sem_nada >= 1, "nenhum morador está sem marcador: o '!' não distingue quem tem fila por abrir")
	print("  Pedro '%s', Tonho '%s', %d moradores sem marcador" % [str(pedro.marcador_de_missao()), str(tonho.marcador_de_missao()) if tonho != null else "-", sem_nada])

	# --- 2. A TELA DE ACEITE -------------------------------------------------------------------
	var respostas: Array = []
	aceite.respondeu.connect(func(sim: bool) -> void: respostas.append(sim))
	tecla.usar(pedro)
	await _frames(3)
	_conferir(bool(aceite.aberto), "o E no Pedro com a ponte por abrir não abriu a tela de aceite")
	_conferir(paused, "com a tela de aceite aberta o vale continua andando")
	_conferir(not ponte.iniciado, "a tela de aceite abriu e a fila começou antes da resposta")
	_conferir(str(aceite.titulo_a_vista()).to_lower().contains("ponte"), "a tela não diz o nome da missão: '%s'" % str(aceite.titulo_a_vista()))
	_conferir(str(aceite.quem_a_vista()).contains("Pedro"), "a tela não diz quem pede: '%s'" % str(aceite.quem_a_vista()))
	var recompensa: Dictionary = aceite.recompensa_a_vista()
	_conferir(int(recompensa.get("xp", 0)) >= 30 and recompensa.has("peixe_assado"), "a recompensa somada da ponte não apareceu: %s" % str(recompensa))
	for nome in ["Titulo", "QuemPede", "Recompensa", "Aceitar", "AgoraNao"]:
		_conferir(not aceite.find_children(nome, "", true, false).is_empty(), "a tela de aceite não tem '%s'" % nome)
	aceite.recusar()
	await _frames(3)
	_conferir(not bool(aceite.aberto) and not paused, "recusar não fechou a tela ou não soltou o vale")
	_conferir(not ponte.iniciado, "recusar começou a fila mesmo assim")
	_conferir(respostas == [false], "a resposta da recusa não saiu: %s" % str(respostas))
	await _ate(func() -> bool: return str(pedro.marcador_de_missao()) == "!", 2.0)
	_conferir(str(pedro.marcador_de_missao()) == "!", "recusada a missão, o '!' do Pedro sumiu")
	tecla.usar(pedro)
	await _frames(3)
	_conferir(bool(aceite.aberto), "o segundo E no Pedro não reabriu a tela de aceite")
	aceite.aceitar()
	await _frames(3)
	_conferir(not bool(aceite.aberto) and not paused, "aceitar não fechou a tela ou não soltou o vale")
	_conferir(ponte.iniciado, "aceitar não começou a fila da ponte")
	_conferir(respostas == [false, true], "as respostas não saíram na ordem: %s" % str(respostas))
	var primeiro := str(ponte.resumo_do_passo(ponte.passos[0]))
	var anunciou := await _ate(func() -> bool: return str(vale.hud.get("_objective")).contains(primeiro), 6.0)
	_conferir(anunciou, "aceita a missão, o HUD não diz o primeiro passo ('%s'; objetivo: '%s')" % [primeiro, str(vale.hud.get("_objective"))])
	# O "!" SÓ SOME QUANDO NÃO HÁ MAIS NADA POR ABRIR: aceita a ponte, ela deixa de estar por abrir no E
	# do Pedro — mas ele ainda tem as armas e o ofício, e o "!" fica enquanto houver fila por abrir.
	await _ate(func() -> bool: return false, 0.6)
	_conferir(str(ponte.o_que_o_e_faz(pedro)) != "abrir", "aceita a ponte, ela continua por abrir no E do Pedro")
	var outra_por_abrir := false
	for cadeia in get_nodes_in_group("cadeias_de_missoes"):
		if cadeia != ponte and cadeia.has_method("o_que_o_e_faz") and str(cadeia.o_que_o_e_faz(pedro)) == "abrir":
			outra_por_abrir = true
	_conferir((str(pedro.marcador_de_missao()) == "!") == outra_por_abrir,
		"aceita a ponte, o marcador do Pedro ('%s') não bate com o que ele ainda tem por abrir (%s)" % [str(pedro.marcador_de_missao()), str(outra_por_abrir)])
	print("  aceita a ponte: marcador do Pedro '%s', outra fila por abrir: %s" % [str(pedro.marcador_de_missao()), str(outra_por_abrir)])
	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("MISSAO_A_VISTA_OK: quem tem fila por abrir no E leva o '!' sobre a cabeça e quem o passo procura leva o '?'; o E na fila por abrir abre a tela de aceite com o vale parado, o nome, quem pede e a recompensa; recusar não começa nada e o '!' fica; aceitar começa a fila, o '!' some e o HUD diz o primeiro passo")
	else:
		print("missao_a_vista: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


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
