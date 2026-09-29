extends SceneTree
## Confere a COSTURA DOS LUGARES do lado 3D: nome de lugar vira posição no
## vale, e nome que o vale ainda não tem some em silêncio em vez de mentir.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/lugares.gd
##
## O par deste teste é o `testar_lugares` do jogo 2D, na raiz. Os dois cobram o
## mesmo contrato: `ponto(nome)` devolve o lugar, nome desconhecido devolve
## `NENHUM`, e nada estoura. A diferença é o tipo — `Vector2` lá, `Vector3`
## aqui —, e é justamente por ela que a campanha atravessa.
##
## Cinco perguntas:
##
##   1. O VALE SE REGISTRA. Sem isso todo nome devolve NENHUM e a campanha
##      inteira ficaria sem bússola, sem ninguém notar.
##   2. TODO NOME DO `DE_PARA` ACHA A ÂNCORA DELE. Renomear uma âncora no
##      `world_builder` sem mexer aqui é o erro fácil, e ele é calado.
##   3. TODO NOME RESOLVE PARA DENTRO DA REGIÃO. Âncora existir não basta: uma
##      que ficasse em `Vector3.ZERO` por engano põe o lugar no mar.
##   4. O QUE FALTA NO VALE É DECLARADO, e devolve NENHUM sem avisar. Nome que
##      a Fase 2.5 ainda vai trazer não é erro de quem escreveu a missão.
##   5. NOME DESCONHECIDO DE VERDADE DEVOLVE NENHUM, e não derruba nada.

var falhas := 0


func _initial_ok() -> void:
	pass


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("LUGARES_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK,
		"a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()

	var lugares := root.get_node("/root/Lugares")
	var mundo := get_first_node_in_group("mundo")

	# --- 1. O VALE SE REGISTRA ------------------------------------------------
	_conferir(mundo != null and mundo.construido, "o vale terminou de construir")
	_conferir(lugares.tem_mundo(),
		"o vale ficou pronto e não se registrou no Lugares: nenhum nome resolveria")

	if mundo == null or not lugares.tem_mundo():
		_fechar()
		return

	# --- 2. TODO NOME DO CONTRATO ACHA A ÂNCORA -------------------------------
	for nome in lugares.nomes():
		var ancora: String = lugares.DE_PARA[nome]
		_conferir(mundo.ancoras.has(ancora),
			"o Lugares promete '%s' pela âncora \"%s\", e o vale não tem essa âncora"
				% [nome, ancora])

	# --- 3. TODO NOME RESOLVE PARA DENTRO DA REGIÃO ---------------------------
	#
	# Os limites saem do próprio cenário, em metros, convertidos pela escala da
	# região — e com folga, porque o píer avança sobre a água e o mirante sobe
	# a encosta. A pergunta não é "está no lote certo", é "está no vale".
	var folga := 200.0
	for nome in lugares.nomes():
		var p: Vector3 = lugares.ponto(nome)
		_conferir(p != lugares.NENHUM, "o nome '%s' não resolveu" % nome)
		if p == lugares.NENHUM:
			continue
		_conferir(absf(p.x) < 2000.0 + folga and absf(p.z) < 2000.0 + folga,
			"o nome '%s' resolveu para %s, longe demais para estar na região" % [nome, str(p)])
		_conferir(p != Vector3.ZERO,
			"o nome '%s' resolveu para a origem: âncora esquecida em zero" % nome)

	# --- 4. O QUE FALTA É DECLARADO, E CALA -----------------------------------
	#
	# Cada nome de `FALTAM_NO_VALE` tem de ser conhecido pelo contrato (para
	# quem escreve missão não errar o dedo) e NÃO resolver (porque o lugar não
	# existe). Os dois ao mesmo tempo é o estado honesto de um vale a meio.
	_conferir(not lugares.FALTAM_NO_VALE.is_empty(),
		"a lista do que falta está vazia: ou a Fase 2.5 acabou e ninguém avisou, ou ela se perdeu")
	for nome in lugares.FALTAM_NO_VALE:
		_conferir(lugares.existe(nome),
			"'%s' está na lista do que falta e o contrato não o conhece" % nome)
		_conferir(not lugares.resolve(nome),
			"'%s' está na lista do que falta e resolveu: mova a linha para DE_PARA" % nome)
		_conferir(not lugares.DE_PARA.has(nome),
			"'%s' está nas duas listas ao mesmo tempo" % nome)
		_conferir(str(lugares.FALTAM_NO_VALE[nome]).length() > 8,
			"'%s' falta sem razão escrita: lista de exceção sem razão vira lista de tudo" % nome)

	# --- 5. NOME DESCONHECIDO -------------------------------------------------
	_conferir(not lugares.existe("lugar_que_nao_existe"), "nome inventado não é conhecido")
	_conferir(lugares.ponto("lugar_que_nao_existe") == lugares.NENHUM,
		"nome desconhecido devolveu posição")
	_conferir(lugares.ponto("") == lugares.NENHUM, "nome vazio devolveu posição")
	_conferir(lugares.pontos(["praca", "nao_existe", "pier"]).size() == 2,
		"nome podre no meio da lista não saiu dela")

	# E O DETALHE não derruba: "aldeao:zefa" ainda não resolve aqui, mas a
	# chave tem de ser lida sem estourar — é o formato que o 2D já escreve.
	_conferir(lugares.ponto("praca:seja_o_que_for") != lugares.NENHUM,
		"o detalhe depois dos dois pontos atrapalhou a chave")

	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("LUGARES_OK: %d nomes resolvem no vale, %d declarados como ainda ausentes, e nome errado devolve NENHUM"
			% [root.get_node("/root/Lugares").nomes().size(),
			   root.get_node("/root/Lugares").FALTAM_NO_VALE.size()])
	else:
		print("lugares: %d falha(s)" % falhas)
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
