extends SceneTree
## Confere A FESTA DE CADA FÉ (#52): no dia dela, da uma da tarde até a
## meia-noite, quem é da fé troca o posto de sempre pela roda no marco maior
## dela — "à tarde, quem é da fé vai para o marco maior dela", como no 2D.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/festa_da_fe.gd
##
##   1. FORA DA FESTA, À TARDE, todo morador está no posto de sempre.
##   2. NO DIA DA FESTA, DE MANHÃ, também: a festa é da tarde.
##   3. À VISTA DO JOGADOR, quem sai para a festa anda: não pula para o lugar.
##   4. LONGE DOS OLHOS DELE, os quatro católicos já estão na roda do cruzeiro —
##      cada um num lugar, em terra e em chão livre —, e o resto do arraial
##      segue no posto de sempre.
##   5. DE NOITE AINDA ESTÃO; NA MADRUGADA voltam para o posto de sempre.
##   6. COSME E DAMIÃO leva a Dona Zefa e o Cosme para os lados do fogo do
##      terreiro; o DOIS DE JULHO leva o Tonho para cima do monte da gameleira.

var falhas := 0
var vale
var world
var jogador
var relogio
var dia
var fe
var afinidade
var por_id := {}


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("FESTA_DA_FE_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	relogio = root.get_node("/root/Relogio")
	dia = root.get_node("/root/Dia")
	fe = root.get_node("/root/Fe")
	afinidade = root.get_node("/root/Afinidade")
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(8)
	vale = current_scene
	world = vale.world
	jogador = vale.player
	for morador in vale.moradores:
		por_id[str(morador.dados.get("id", ""))] = morador
	for id in afinidade.MORADORES:
		_conferir(por_id.has(id), "o morador '%s' não está no vale" % id)
	if falhas > 0:
		_fechar()
		return
	# Quem diz a hora é o portão, e não o tempo que passa enquanto ele roda.
	dia.pausado = true
	var catolicos: Array = afinidade.da_fe("catolica")
	_conferir(catolicos.size() == 4, "a festa do Bom Jesus devia juntar quatro católicos, e não %d" % catolicos.size())
	var terreiro: Vector3 = world.ancoras["Terreiro"]
	var gameleira: Vector3 = world.ancoras["Gameleira"]
	# Os dois mirantes do portão, longe de quem vai e de onde vai: ao pé do monte
	# da gameleira (para o cruzeiro e o terreiro) e no alto do cemitério, onde o
	# Damião passa a manhã (para a gameleira — o Tonho anda entre o píer e a casa
	# da estrada).
	var perto_da_gameleira: Vector3 = world.ground_position(gameleira + Vector3(0, 0, 6.5), 0.05)
	var no_cemiterio: Vector3 = por_id["damiao"]._posicao_do_posto("manha") + Vector3.UP * 0.05

	# --- 1. FORA DA FESTA --------------------------------------------------------
	_dia_sem_festa()
	_conferir(fe.festa_de_hoje() == "", "o dia escolhido para não ter festa tem a festa '%s'" % fe.festa_de_hoje())
	await _na_hora(15.0)
	for id in por_id:
		_no_posto_de_sempre(id, "tarde", "fora da festa, à tarde")

	# --- 2. NO DIA DA FESTA, DE MANHÃ ----------------------------------------------
	_no_dia_da_festa("catolica")
	await _na_hora(9.0)
	for id in por_id:
		_no_posto_de_sempre(id, "manha", "no dia do Bom Jesus, de manhã")

	# --- 3. À VISTA, ANDA ------------------------------------------------------------
	await _na_hora(12.5)
	var candinha = por_id["candinha"]
	# O jogador a quatro passos dela, num chão onde caiba, olhando para ela.
	var olho := Vector3.INF
	for i in 8:
		var tentativa: Vector3 = world.ground_position(candinha.global_position + Vector3(4.0, 0, 0).rotated(Vector3.UP, TAU * float(i) / 8.0), 0.0)
		if world.is_on_land(tentativa) and _chao_livre(tentativa, jogador):
			olho = tentativa
			break
	_conferir(olho.is_finite(), "(preparo) não há chão livre a quatro passos da Candinha")
	if olho.is_finite():
		jogador.teleportar(olho + Vector3.UP * 0.05, atan2(candinha.global_position.x - olho.x, candinha.global_position.z - olho.z))
	await _quadros(6)
	var camera: Camera3D = jogador.get_viewport().get_camera_3d()
	_conferir(camera != null and camera.is_position_in_frustum(candinha.global_position + Vector3.UP),
		"(preparo) a câmera não ficou olhando para a Candinha")
	# Vinte passos de física, contados, e não quadros de desenho: com a máquina
	# ocupada cabem mais passos num quadro, e a Candinha andaria mais. Em vinte
	# passos ela anda menos de meia unidade; a roda está a mais de quatro.
	var antes: Vector3 = candinha.global_position
	dia.definir_hora(15.0)
	await _passos(20)
	var depois: Vector3 = candinha.global_position
	var faltava := _no_chao(candinha._alvo).distance_to(_no_chao(antes))
	var falta := _no_chao(candinha._alvo).distance_to(_no_chao(depois))
	_conferir(candinha._posto == "festa", "à tarde do Bom Jesus a Candinha não saiu para a festa (posto '%s')" % candinha._posto)
	_conferir(faltava > 4.0, "(preparo) a Candinha já estava a %.1f do lugar dela na roda" % faltava)
	_conferir(antes.distance_to(depois) < 1.0, "à vista do jogador a Candinha pulou %.1f em vinte passos de física" % antes.distance_to(depois))
	_conferir(falta < faltava - 0.05, "à vista do jogador a Candinha não andou para a roda (faltava %.2f, falta %.2f)" % [faltava, falta])

	# --- 4. LONGE DOS OLHOS, JÁ ESTÃO LÁ ------------------------------------------
	jogador.teleportar(perto_da_gameleira, 0.0)
	await _quadros(8)
	_longe_de(catolicos, perto_da_gameleira)
	var cruzeiro: Vector3 = world.ancoras["Cruzeiro"]
	_na_roda(catolicos, cruzeiro, 2.2, 3.0, "do cruzeiro")
	for id in por_id:
		if not catolicos.has(id):
			_no_posto_de_sempre(id, "tarde", "na festa do Bom Jesus, quem não é católico")

	# --- 5. DE NOITE AINDA, NA MADRUGADA NÃO ----------------------------------------
	await _na_hora(21.0)
	for id in catolicos:
		_conferir(por_id[id]._posto == "festa", "às nove da noite do Bom Jesus, '%s' deixou a festa" % id)
	await _na_hora(2.0)
	for id in catolicos:
		_no_posto_de_sempre(id, "madrugada", "na madrugada depois do Bom Jesus")
		_conferir(_no_chao(por_id[id].global_position).distance_to(_no_chao(por_id[id]._alvo)) < 1.0,
			"longe dos olhos, '%s' não voltou da festa para o posto da madrugada" % id)

	# --- 6. AS OUTRAS DUAS FESTAS ----------------------------------------------------
	_no_dia_da_festa("candomble")
	await _na_hora(15.0)
	var do_candomble: Array = afinidade.da_fe("candomble")
	_conferir(do_candomble.has("zefa") and do_candomble.has("cosme"), "a Dona Zefa e o Cosme não são do candomblé: %s" % str(do_candomble))
	_longe_de(do_candomble, perto_da_gameleira)
	_na_roda(do_candomble, terreiro, 2.0, 4.0, "do terreiro")
	var fogo: Vector3 = terreiro + world.ancoras["TerreiroFrente"]
	for id in do_candomble:
		_conferir(_no_chao(por_id[id]._alvo).distance_to(_no_chao(fogo)) > 1.5, "'%s' está em cima do fogo do terreiro" % id)
	for id in por_id:
		if not do_candomble.has(id):
			_no_posto_de_sempre(id, "tarde", "em Cosme e Damião, quem não é do candomblé")
	await _na_hora(2.0)

	jogador.teleportar(no_cemiterio, 0.0)
	_no_dia_da_festa("caboclo")
	await _na_hora(15.0)
	var do_caboclo: Array = afinidade.da_fe("caboclo")
	_conferir(do_caboclo == ["tonho"], "a festa do Dois de Julho devia levar só o Tonho, e não %s" % str(do_caboclo))
	_longe_de(do_caboclo, no_cemiterio)
	_na_roda(do_caboclo, gameleira, 2.6, 3.8, "da gameleira")
	await _quadros(20)
	var tonho = por_id["tonho"]
	_conferir(tonho.global_position.y > gameleira.y - 0.7,
		"o Tonho não ficou em cima do monte da gameleira (pé a %.2f, topo a %.2f)" % [tonho.global_position.y, gameleira.y])
	for id in por_id:
		if not do_caboclo.has(id):
			_no_posto_de_sempre(id, "tarde", "no Dois de Julho, quem não é do caboclo")
	_fechar()


## O posto e o lugar de sempre para o período, sem festa nenhuma por cima.
func _no_posto_de_sempre(id: String, periodo: String, quando: String) -> void:
	var morador = por_id[id]
	var esperado: String = morador._posto_para(periodo)
	_conferir(morador._posto == esperado, "%s, '%s' está no posto '%s', e não no '%s'" % [quando, id, morador._posto, esperado])
	var lugar: Vector3 = morador._posicao_do_posto(esperado)
	_conferir(morador._alvo.distance_to(lugar) < 0.05, "%s, '%s' vai para %s, e não para o lugar de sempre %s" % [quando, id, str(morador._alvo), str(lugar)])


## Todos da fé na roda do marco: o posto, o lugar em volta dele, um lugar para
## cada um, em terra e em chão livre — e, longe dos olhos do jogador, já lá.
func _na_roda(ids: Array, marco: Vector3, de: float, ate: float, roda: String) -> void:
	var lugares: Array[Vector3] = []
	for id in ids:
		var morador = por_id[id]
		_conferir(morador._posto == "festa", "no dia da festa, à tarde, '%s' ficou no posto '%s'" % [id, morador._posto])
		var lugar: Vector3 = morador._alvo
		var raio := _no_chao(lugar).distance_to(_no_chao(marco))
		_conferir(raio > de and raio < ate, "o lugar de '%s' na roda %s está a %.2f do marco (devia estar entre %.1f e %.1f)" % [id, roda, raio, de, ate])
		_conferir(world.is_on_land(lugar), "o lugar de '%s' na roda %s não é terra firme" % [id, roda])
		_conferir(_chao_livre(lugar, morador), "o lugar de '%s' na roda %s esbarra em alguma coisa" % [id, roda])
		_conferir(_no_chao(morador.global_position).distance_to(_no_chao(lugar)) < 1.0,
			"longe dos olhos do jogador, '%s' não chegou à roda %s (está a %.1f)" % [id, roda, _no_chao(morador.global_position).distance_to(_no_chao(lugar))])
		for outro in lugares:
			_conferir(_no_chao(lugar).distance_to(_no_chao(outro)) > 1.2, "na roda %s, '%s' disputa o lugar com outro" % [roda, id])
		lugares.append(lugar)


## (Preparo) o jogador está mesmo longe de quem vai e da roda para onde vai.
func _longe_de(ids: Array, onde: Vector3) -> void:
	for id in ids:
		var morador = por_id[id]
		for ponto in [morador.global_position, morador._alvo]:
			if ponto.distance_to(onde) < morador.VISTA:
				_conferir(false, "(preparo) o jogador em %s não está longe de '%s' (%.0f)" % [str(onde), id, ponto.distance_to(onde)])


## Um corpo de gente cabe ali, sem bater em parede, pote, tronco ou fogo.
func _chao_livre(lugar: Vector3, morador: Node) -> bool:
	var forma := CapsuleShape3D.new()
	forma.radius = 0.3
	forma.height = 1.6
	var pergunta := PhysicsShapeQueryParameters3D.new()
	pergunta.shape = forma
	pergunta.transform = Transform3D(Basis(), lugar + Vector3.UP * 0.95)
	pergunta.collision_mask = morador.collision_mask
	var fora: Array[RID] = [jogador.get_rid()]
	for outro in vale.moradores:
		fora.append(outro.get_rid())
	if vale.get("pedro") != null:
		fora.append(vale.pedro.get_rid())
	pergunta.exclude = fora
	var tocou: Array = jogador.get_world_3d().direct_space_state.intersect_shape(pergunta, 4)
	for toque in tocou:
		var corpo = toque.get("collider")
		print("  em %s esbarra em %s" % [str(lugar), str(corpo.get_path()) if corpo is Node else str(corpo)])
	return tocou.is_empty()


func _no_chao(ponto: Vector3) -> Vector2:
	return Vector2(ponto.x, ponto.z)


func _dia_sem_festa() -> void:
	relogio.estacao = 2
	relogio.dia = 10


func _no_dia_da_festa(qual: String) -> void:
	relogio.estacao = int(fe.FESTAS[qual]["estacao"])
	relogio.dia = int(fe.FESTAS[qual]["dia"])
	_conferir(fe.festa_de_hoje() == qual, "o calendário não deu a festa '%s' (deu '%s')" % [qual, fe.festa_de_hoje()])


func _na_hora(hora: float, quadros: int = 8) -> void:
	dia.definir_hora(hora)
	await _quadros(maxi(quadros, 2))


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("FESTA_DA_FE_OK: fora da festa e de manhã cada um está no posto de sempre; à vista do jogador quem sai para a festa anda; longe dos olhos dele os quatro católicos já estão na roda do cruzeiro, um lugar para cada, em terra e em chão livre, e o resto no de sempre; de noite ainda estão, na madrugada voltam; Cosme e Damião leva a Dona Zefa e o Cosme para os lados do fogo do terreiro, e o Dois de Julho leva o Tonho para cima do monte da gameleira")
	else:
		print("festa_da_fe: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _passos(n: int) -> void:
	for i in n:
		await physics_frame


func _quadros(n: int) -> void:
	for i in n:
		await process_frame
		await physics_frame


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
