extends SceneTree
## Confere OS AVISOS DA PRIMEIRA VEZ (scripts/prototipo_3d/aviso_da_primeira_vez.gd,
## data/avisos.json).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/avisos_da_primeira_vez.gd
##
## "Ao pegar o primeiro cordel no jogo, deve aparecer um pop-up informando que
## eles ficam localizados no almanaque. O mesmo vale para a primeira interação
## com árvore. No caso dos cordéis, nesse pop-up deve contextualizar o que é um
## cordel." Quatro perguntas:
##
##   1. O PRIMEIRO CORDEL AVISA: pegar o primeiro abre o aviso, que diz o que é
##      um cordel e que ele fica no almanaque, na letra do almanaque; o vale e o
##      relógio param enquanto ele está aberto; ele mora acima do HUD e recolhe
##      as plaquinhas de nome dos moradores; o E o fecha, e o papel do cordel
##      abre depois dele.
##   2. O SEGUNDO NÃO: o segundo cordel abre o papel direto.
##   3. A PRIMEIRA ÁRVORE AVISA: o E na primeira espécie abre a ficha e o aviso
##      do almanaque.
##   4. A SEGUNDA NÃO: outra espécie abre só a ficha.
##   5. O PRIMEIRO MERGULHO AVISA (#96): o corpo entrando no nado abre o cartão
##      da água funda — parar é boiar, e o fôlego volta —, com o vale parado.
##   6. O SEGUNDO NÃO, E O SAVE LEMBRA: sair e voltar ao nado não repete o
##      cartão, e `estado_para_salvar` guarda a marca.

const CORDEIS := ["peso_falso", "vendeu_a_chuva"]

var falhas := 0
var vale


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("AVISOS_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	vale = current_scene
	var dia = root.get_node("/root/Dia")
	var colecao = root.get_node("/root/Colecao")
	var aviso = vale.get("aviso_da_primeira_vez")
	var achados = vale.get("achados")
	var arvores = vale.get("_arvores_info")
	_conferir(aviso != null and achados != null and arvores != null,
		"o vale não tem o aviso (%s), os achados (%s) ou as árvores (%s)" % [str(aviso), str(achados), str(arvores)])
	if aviso == null or achados == null or arvores == null:
		_fechar()
		return
	_conferir(colecao.quantos("cordeis") == 0, "a partida nova já começou com %d cordel(is)" % colecao.quantos("cordeis"))

	# --- 1. O PRIMEIRO CORDEL AVISA --------------------------------------------------------
	await _pegar(achados, CORDEIS[0])
	_conferir(await _ate(func() -> bool: return aviso.aberto(), 2.0), "o primeiro cordel pego não abriu o aviso")
	if aviso.aberto():
		var dito: String = aviso.texto()
		_conferir(aviso.qual == "cordel", "o aviso do primeiro cordel é o de '%s'" % aviso.qual)
		_conferir(dito.contains("Nordeste") and dito.contains("xilogravura") and dito.contains("verso"),
			"o aviso do cordel não conta o que é um cordel para quem não é do Nordeste: '%s'" % dito)
		_conferir(dito.contains("Almanaque (L)"), "o aviso do cordel não diz que ele fica no almanaque, na tecla dele: '%s'" % dito)
		# O papel no jogo (#88): colecionável, com outros pelo vale e a conta no almanaque.
		_conferir(dito.contains("colecion") and dito.contains("faltam"), "o aviso do cordel não diz que ele é um colecionável nem que o almanaque conta os que faltam: '%s'" % dito)
		_conferir(paused and dia.pausado, "com o aviso aberto, o vale (%s) ou o relógio (%s) seguiu andando" % [str(paused), str(dia.pausado)])
		# NADA DO HUD POR CIMA DO CARTÃO: ele mora acima do HUD, como a caixa de
		# fala e o folheto, e as plaquinhas de nome dos moradores se recolhem.
		_conferir(aviso.layer > vale.hud.layer,
			"o aviso está na camada %d e o HUD na %d: o HUD desenha por cima do cartão" % [aviso.layer, vale.hud.layer])
		_conferir(not vale.placas._permitido,
			"com o aviso aberto, as plaquinhas de nome dos moradores continuam acesas por cima do cartão")
		# O E logo de cara é engolido: é o mesmo que pegou o cordel.
		_apertar_e()
		await _quadros(2)
		_conferir(aviso.aberto(), "o E de logo depois de pegar o cordel fechou o aviso sem ele ser lido")
		await _ate(func() -> bool: return false, 0.8)
		_apertar_e()
		_conferir(await _ate(func() -> bool: return not aviso.aberto(), 2.0), "o E não fechou o aviso do cordel")
		_conferir(await _ate(func() -> bool: return vale.telas.aberta() == "folheto", 3.0),
			"fechado o aviso, o papel do primeiro cordel não abriu (tela aberta: '%s')" % vale.telas.aberta())
		# O PAPEL SEGURA O VALE como qualquer tela: a volta do aviso não o solta por
		# baixo do papel, e guardado o papel o relógio volta a andar.
		await _quadros(4)
		_conferir(paused and vale.telas.aberta() == "folheto",
			"com o papel do primeiro cordel aberto, o vale anda atrás dele: a volta do aviso o soltou")
		_conferir(not vale.placas._permitido,
			"fechado o aviso, as plaquinhas de nome voltaram por cima do papel do cordel")
		vale.telas.fechar_tudo()
		await _ate(func() -> bool: return not paused, 3.0)
		_conferir(not paused and not dia.pausado,
			"guardado o papel do primeiro cordel, o vale (%s) ou o relógio (%s) ficou parado" % [str(paused), str(dia.pausado)])
		_conferir(vale.placas._permitido, "guardado o papel, as plaquinhas de nome dos moradores não voltaram")
	await _guardar_tudo()

	# --- 2. O SEGUNDO NÃO -------------------------------------------------------------------
	await _pegar(achados, CORDEIS[1])
	_conferir(await _ate(func() -> bool: return vale.telas.aberta() == "folheto", 3.0),
		"o segundo cordel não abriu o papel (tela aberta: '%s')" % vale.telas.aberta())
	_conferir(not aviso.aberto(), "o segundo cordel abriu o aviso de novo")
	await _guardar_tudo()

	# --- 3. A PRIMEIRA ÁRVORE AVISA -----------------------------------------------------------
	var especies_vistas: Array[String] = []
	for vez in 2:
		var arvore := _arvore_sozinha(arvores, especies_vistas)
		_conferir(arvore >= 0, "não achei árvore de espécie nova longe do resto do vale (%dª)" % (vez + 1))
		if arvore < 0:
			break
		var especie := str(arvores._pontos[arvore]["especie"])
		especies_vistas.append(especie)
		var pos: Vector3 = arvores._pontos[arvore]["pos"]
		var de: Vector3 = pos + Vector3(1.4, 0.0, 0.0)
		vale.player.teleportar(vale.world.ground_position(de, 0.3), atan2(pos.x - de.x, pos.z - de.z))
		var foco = vale.get("foco_do_e")
		var na_vez := await _ate(func() -> bool: return arvores._perto == arvore and foco.dono() == arvores, 3.0)
		_conferir(na_vez, "ao lado da árvore (%s), o E não é dela (perto %d, dono %s)" % [especie, arvores._perto, str(foco.dono())])
		if not na_vez:
			continue
		var evento := InputEventKey.new()
		evento.keycode = KEY_E
		evento.physical_keycode = KEY_E
		evento.pressed = true
		arvores._unhandled_key_input(evento)
		_conferir(arvores.ficha_aberta() == arvore, "o E na árvore (%s) não abriu a ficha" % especie)
		if vez == 0:
			_conferir(await _ate(func() -> bool: return aviso.aberto(), 2.0), "a primeira árvore conhecida não abriu o aviso do almanaque")
			_conferir(aviso.qual == "arvore" and aviso.texto().contains("Almanaque (L)"),
				"o aviso da primeira árvore não diz que ela fica no almanaque: '%s'" % aviso.texto())
		else:
			# --- 4. A SEGUNDA NÃO ----------------------------------------------------------
			await _quadros(6)
			_conferir(not aviso.aberto(), "a segunda espécie conhecida abriu o aviso de novo")
		await _guardar_tudo()

	# --- 5. O PRIMEIRO MERGULHO AVISA (#96) -----------------------------------------------
	var jogador = vale.player
	jogador._definir_nado(true)
	_conferir(await _ate(func() -> bool: return aviso.aberto(), 2.0), "o primeiro nado em água funda não abriu o aviso")
	if aviso.aberto():
		var dito_na_agua: String = aviso.texto()
		_conferir(aviso.qual == "agua_funda", "o aviso do primeiro nado é o de '%s'" % aviso.qual)
		_conferir(dito_na_agua.contains("boiar") and dito_na_agua.contains("fôlego"),
			"o aviso da água funda não diz que parar é boiar e que o fôlego volta: '%s'" % dito_na_agua)
		_conferir(paused and dia.pausado, "com o aviso da água funda aberto, o vale (%s) ou o relógio (%s) seguiu andando" % [str(paused), str(dia.pausado)])
	await _guardar_tudo()
	# --- 6. O SEGUNDO NÃO, E O SAVE LEMBRA ---------------------------------------------------
	jogador._definir_nado(false)
	await _quadros(2)
	jogador._definir_nado(true)
	await _quadros(6)
	_conferir(not aviso.aberto(), "o segundo nado abriu o aviso de novo")
	_conferir(bool(vale.estado_para_salvar().get("avisou_agua_funda", false)), "o save não guarda que o aviso da água funda já foi dado")
	jogador._definir_nado(false)
	await _guardar_tudo()
	_fechar()


## Pega o cordel `id` pelo caminho do jogo (o E dos achados), de perto.
func _pegar(achados, id: String) -> void:
	var ponto: Vector3 = achados.ponto_do_cordel(id)
	vale.player.teleportar(ponto + Vector3(0.0, 0.3, 0.0), 0.0)
	await _passos_de_fisica(4)
	for achado in achados.no_chao:
		if str(achado.get("id", "")) == id:
			achados._pegar_cordel(achado)
			return
	_conferir(false, "o cordel '%s' não está no chão do vale" % id)


## A árvore mais perto da praça de espécie ainda não vista, com nada mais que
## responda ao E a seis unidades dela: é o caminho do jogador que vai à mata.
func _arvore_sozinha(arvores, fora: Array[String]) -> int:
	var praca: Vector3 = vale.world.ancoras.get("Praça", Vector3.ZERO)
	var almanaque = load("res://scripts/prototipo_3d/almanaque.gd")
	var melhor := -1
	var menor := INF
	for i in arvores._pontos.size():
		var especie := str(arvores._pontos[i]["especie"])
		if fora.has(especie) or almanaque.conhece(especie) or bool(arvores._pontos[i].get("cortado", false)):
			continue
		var pos: Vector3 = arvores._pontos[i]["pos"]
		var d := Vector2(pos.x - praca.x, pos.z - praca.z).length()
		if d < 25.0 or d >= menor or _tem_algo_perto(pos):
			continue
		menor = d
		melhor = i
	return melhor


func _tem_algo_perto(pos: Vector3) -> bool:
	for morador in vale.moradores + [vale.get("pedro")]:
		if morador != null and Vector2(morador.global_position.x - pos.x, morador.global_position.z - pos.z).length() < 8.0:
			return true
	var recursos = vale.get_node_or_null("Recursos3D")
	if recursos != null:
		for id in recursos._alvos:
			var alvo: Vector3 = recursos._alvos[id]["pos"]
			if Vector2(alvo.x - pos.x, alvo.z - pos.z).length() < 6.0:
				return true
	return false


## Fecha o aviso, o papel e a ficha, até o vale andar de novo.
func _guardar_tudo() -> void:
	var ate := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < ate:
		var aviso = vale.get("aviso_da_primeira_vez")
		if aviso != null and aviso.aberto():
			aviso.fechar()
		if vale.telas.aberta() != "":
			vale.telas.fechar_tudo()
		if not paused and vale.telas.aberta() == "" and not aviso.aberto():
			break
		await process_frame
	var arvores = vale.get("_arvores_info")
	if arvores != null and arvores.ficha_aberta() >= 0:
		arvores.fechar_painel()
	await _quadros(4)


func _apertar_e() -> void:
	for apertado in [true, false]:
		var evento := InputEventKey.new()
		evento.keycode = KEY_E
		evento.physical_keycode = KEY_E
		evento.pressed = apertado
		root.push_input(evento)


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("AVISOS_OK: o primeiro cordel abre o aviso que conta o que é um cordel e que ele fica no almanaque, com o vale e o relógio parados, e o papel depois dele; o segundo vai direto ao papel; a primeira árvore conhecida abre o aviso do almanaque junto da ficha, e a segunda só a ficha")
	else:
		print("avisos_da_primeira_vez: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _passos_de_fisica(n: int) -> void:
	for i in n:
		await physics_frame


## Roda quadros até `condicao` valer, com teto em SEGUNDO REAL.
func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicao.call():
			return true
		await process_frame
	return condicao.call()


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
