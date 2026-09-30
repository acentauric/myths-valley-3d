extends SceneTree
## JOGA A CONTA E A TERRA DO TONHO — a cadeia que atravessa o arraial.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/cadeia_do_tonho.gd
##
## Veio do jogo 2D (`data/dialogos/arraial.json`, passos tonho_divida /
## tonho_terra). O Tonho conta que deve mil e novecentos no armazém, manda ver o
## livro de fiado, e na volta entrega a terra do outro lado da estrada.
##
##
## O QUE ESTA CADEIA TEM DE NOVO: O PASSO QUE MANDA A UM LUGAR
##
## As duas cadeias conversadas que já estavam aqui (zefa, filo) vão de uma
## PESSOA a outra. Esta manda a um LUGAR — o armazém — e é a primeira a depender
## de o nome do lugar resolver no vale.
##
## Isso importa porque o `correr` da CadeiaDeMissoes faz uma gentileza perigosa:
## passo cujo `lugar` não resolve é PULADO em silêncio, para que o vale a meio
## não trave numa das treze âncoras que a Fase 2.5 ainda vai trazer. A gentileza
## é certa, e a consequência é que um erro de digitação em "venda" não quebra
## nada — só apaga o meio da missão, e ninguém fica sabendo.
##
## Seis perguntas:
##
##   1. A CADEIA É DO TONHO, é de enredo e tem os três passos.
##   2. O PRIMEIRO FECHA NO PÍER, que é onde ele está: é a fala da dívida.
##   3. O DO ARMAZÉM NÃO FECHA NO PÍER. Sem isto a missão vira "fique parado",
##      e é assim que um passo pulado se disfarça de passo cumprido.
##   4. A VIAGEM É DE VERDADE: o armazém fica longe do píer o bastante para ser
##      uma travessia, e chegar lá fecha o passo.
##   5. VOLTAR AO TONHO FECHA O ÚLTIMO, E É ELE QUEM ENTREGA A TERRA — a fala do
##      fim é de quem recebe o jogador, não de quem o mandou embora.
##   6. A CADEIA SOBREVIVE A RECARREGAR: depois da conversa não sobra nada no
##      mundo que prove que ela houve.

var falhas := 0
const SEGUNDOS_PARA_ANUNCIAR := 12.0
const SEGUNDOS_POR_PASSO := 15.0
## O píer e o armazém têm de estar a mais que isto um do outro, em unidades.
const TRAVESSIA_MINIMA := 15.0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("TONHO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK,
		"a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(3)

	var jogo := current_scene
	var jogador = jogo.get("player")
	var lugares := root.get_node("/root/Lugares")
	var caderno := root.get_node("/root/CadernoDoVale")
	var tonho: Node3D = null
	for morador in jogo.get("moradores"):
		if str((morador.dados as Dictionary).get("id", "")) == "tonho":
			tonho = morador
	_conferir(tonho != null, "o vale não tem o Tonho")
	if tonho == null or jogador == null:
		_fechar()
		return

	# --- 1. A CADEIA É DELE, DE ENREDO, E TEM TRÊS PASSOS --------------------
	var cadeia := tonho.get_node_or_null("CadeiaDeMissoes")
	_conferir(cadeia != null, "o Tonho não tem fila de missões")
	if cadeia == null:
		_fechar()
		return
	_conferir(cadeia.total() == 3,
		"a cadeia do Tonho tem %d passo(s), e são três: a dívida, o livro e a terra" % cadeia.total())
	_conferir(cadeia.principal,
		"a conta do Tonho não está marcada como enredo: ela vem depois de um favor de vizinho na lista")

	# O LUGAR DO PASSO DO MEIO RESOLVE. Perguntado ao Lugares antes de jogar: se
	# não resolvesse, o passo sumiria calado e as perguntas abaixo passariam a
	# medir uma cadeia de dois passos sem ninguém notar.
	var onde_o_armazem := str((cadeia.passos[1] as Dictionary).get("lugar", ""))
	_conferir(lugares.resolve(onde_o_armazem),
		"o passo do meio aponta '%s', que o vale não resolve: ele seria pulado em silêncio"
			% onde_o_armazem)
	if not lugares.resolve(onde_o_armazem):
		_fechar()
		return
	var ponto_do_armazem: Vector3 = lugares.ponto(onde_o_armazem)

	jogador.global_position = tonho.global_position + Vector3(1.2, 0.0, 1.0)
	await _frames(3)
	var abriu := await _ate(func() -> bool: return bool(cadeia.iniciado), SEGUNDOS_PARA_ANUNCIAR)
	_conferir(abriu, "cheguei ao lado do Tonho e a conversa não abriu")
	if not abriu:
		_fechar()
		return

	# --- 2. O PRIMEIRO FECHA NO PÍER ----------------------------------------
	var fechou_divida := await _ate(func() -> bool: return cadeia.missao >= 1, SEGUNDOS_POR_PASSO)
	_conferir(fechou_divida,
		"o passo da dívida não fechou ao lado do Tonho, e é lá que ele fala dela")
	print("  %-16s %s" % ["tonho_divida", "fechou" if fechou_divida else "PRESO"])
	if not fechou_divida:
		_fechar()
		return
	var anunciou := await _ate(func() -> bool: return cadeia.espera <= 0.0, SEGUNDOS_PARA_ANUNCIAR)
	_conferir(anunciou, "o passo do livro não chegou a anunciar")

	# ENQUANTO ABERTO, O PASSO ESTÁ NAS ATIVAS do caderno: é o que o jogador lê
	# no menu de missão enquanto atravessa o vale. Perguntado pelo nome que a
	# PRÓPRIA cadeia dá ao passo — a regra de como o dono e o passo viram um id
	# é dela, e copiá-la para cá envelheceria calada.
	var id_do_livro: String = cadeia._id_no_caderno(cadeia.passos[1])
	_conferir(caderno.tem(id_do_livro),
		"o passo do armazém não está nas missões abertas do caderno ('%s')" % id_do_livro)

	# --- 3. O DO ARMAZÉM NÃO FECHA NO PÍER ----------------------------------
	_conferir(cadeia.missao == 1,
		"a cadeia pulou o passo do armazém: está no passo %d" % (cadeia.missao + 1))
	var onde_esta: int = cadeia.missao
	await _ate(func() -> bool: return cadeia.missao != onde_esta, 4.0)
	_conferir(cadeia.missao == onde_esta,
		"o passo que manda ao armazém fechou com o jogador parado no píer")

	# --- 4. A VIAGEM É DE VERDADE, E CHEGAR FECHA ---------------------------
	var travessia: float = jogador.global_position.distance_to(ponto_do_armazem)
	_conferir(travessia > TRAVESSIA_MINIMA,
		"o armazém está a %.1f u do píer: não é travessia, é um passo ao lado" % travessia)
	jogador.global_position = ponto_do_armazem
	await _frames(3)
	var chegou := await _ate(func() -> bool: return cadeia.missao > onde_esta, SEGUNDOS_POR_PASSO)
	_conferir(chegou, "cheguei ao armazém e o passo não fechou")
	print("  %-16s %s  (travessia de %.1f u)" % ["tonho_livro", "fechou" if chegou else "PRESO", travessia])

	# --- 5. VOLTAR AO TONHO FECHA, E É ELE QUEM ENTREGA A TERRA -------------
	var respostas: Array[String] = []
	if tonho.has_signal("narrou"):
		tonho.narrou.connect(func(texto: String) -> void: respostas.append(texto))
	var anunciou2 := await _ate(func() -> bool: return cadeia.espera <= 0.0, SEGUNDOS_PARA_ANUNCIAR)
	_conferir(anunciou2, "o passo da terra não chegou a anunciar")
	var no_armazem: int = cadeia.missao
	await _ate(func() -> bool: return cadeia.missao != no_armazem, 4.0)
	_conferir(cadeia.missao == no_armazem,
		"o passo que manda voltar ao Tonho fechou com o jogador no armazém")

	jogador.global_position = tonho.global_position + Vector3(1.0, 0.0, 0.8)
	await _frames(3)
	var voltou := await _ate(func() -> bool: return cadeia.missao > no_armazem, SEGUNDOS_POR_PASSO)
	_conferir(voltou, "voltei ao Tonho e o passo da terra não fechou")
	print("  %-16s %s" % ["tonho_terra", "fechou" if voltou else "PRESO"])
	_conferir(tonho._balao_tempo > 0.0 or not respostas.is_empty(),
		"quem entrega a terra não falou: a fala do fim ficou na boca de quem mandou embora")
	if not respostas.is_empty():
		var tudo := " ".join(respostas)
		_conferir(tudo.contains("chão") or tudo.contains("terra"),
			"a resposta do Tonho não é a do 2D: '%s'" % respostas[0])
	_conferir(bool(cadeia._levados.get("tonho_terra", false)),
		"a cadeia não lembra que a entrega da terra aconteceu")
	_conferir(cadeia.acabou(),
		"a cadeia do Tonho não acabou depois dos três passos")

	# E NO FIM ELE SAIU DAS ATIVAS PARA AS CUMPRIDAS, que é o que fecha a
	# missão no menu em vez de deixá-la aberta para sempre.
	var id_da_divida: String = cadeia._id_no_caderno(cadeia.passos[0])
	var id_da_terra: String = cadeia._id_no_caderno(cadeia.passos[2])
	_conferir(caderno.cumpridas.has(id_da_divida),
		"o passo da dívida não consta como cumprido no caderno ('%s')" % id_da_divida)
	_conferir(caderno.cumpridas.has(id_da_terra),
		"o passo da terra não consta como cumprido no caderno ('%s')" % id_da_terra)

	# --- 6. SOBREVIVE A RECARREGAR ------------------------------------------
	var guardado: Dictionary = jogo.estado_para_salvar()
	var guardadas: Dictionary = guardado.get("cadeias", {})
	_conferir(guardadas.has("tonho"), "o save não leva a fila do Tonho")
	var dele: Dictionary = guardadas.get("tonho", {})
	_conferir((dele.get("levados", []) as Array).has("tonho_terra"),
		"o save não lembra a entrega da terra: recarregar mandaria voltar ao píer de novo")

	cadeia._levados.clear()
	cadeia.missao = 0
	jogo.restaurar_do_save(guardado)
	await _frames(2)
	_conferir(not cadeia.falta_a_meta(cadeia.passos[2]),
		"recarregar esqueceu a entrega da terra")

	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("TONHO_OK: a fila é do Tonho e é de enredo, o passo da dívida fecha no píer, o do armazém aponta um lugar que o vale resolve e não fecha antes da travessia, chegar lá fecha, voltar ao Tonho fecha o último e é ele quem entrega a terra, o caderno do vale leva a cadeia, e recarregar não manda voltar de novo")
	else:
		print("tonho: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicao.call():
			return true
		await process_frame
	return condicao.call()


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
