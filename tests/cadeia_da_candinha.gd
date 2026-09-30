extends SceneTree
## JOGA A GARAPA DA PRAÇA — a cadeia que corta e entrega.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/cadeia_da_candinha.gd
##
## Veio do jogo 2D (`data/dialogos/arraial.json`, passo candinha_cana). A Dona
## Candinha mói cana no meio da praça e quer seis da do jogador, cortadas no
## roçado dele, para não comprar do engenho do outro lado da vila.
##
##
## O QUE ESTA CADEIA TEM DE NOVO: A ENTREGA COM CONTA
##
## As cadeias que já estavam aqui entregam UM: o pirão da Filó é um pirão. O 2D
## pede SEIS canas, e até agora a meta "levar" levava um item e consumia um só —
## chegar ao lado dela com uma cana fecharia a missão das seis.
##
## É um defeito que passa fácil, porque a missão FUNCIONA: o balão sai, o passo
## fecha, a fala dela aparece. O que não acontece é a conta. Por isso a pergunta
## do meio deste portão é feita com CINCO na mochila, que é o estado em que o
## jogador quase chegou — e é onde a implementação errada diz que chegou.
##
## Seis perguntas:
##
##   1. A CADEIA É DA DONA CANDINHA, tem dois passos e NÃO é de enredo: é
##      negócio de vizinha, e vai depois do enredo na lista do painel.
##   2. ELA DÁ A FOICE AO PEDIR A CANA. Pedir corte sem dar ferramenta é o
##      defeito que o playtest do 2D deixou escrito.
##   3. O VALE TEM CANA, E ELA SÓ CAI DE FOICE. Sem pé de cana posto, a missão é
##      impossível e ninguém percebe — a meta só diz "faltam 6".
##   4. CINCO NÃO BASTA. Ao lado dela com cinco canas, o passo não fecha.
##   5. SEIS FECHA, E AS SEIS SAEM DA MOCHILA — não uma. Quem recebe responde.
##   6. A CADEIA SOBREVIVE A RECARREGAR: depois da entrega não sobra nada no
##      mundo que prove que ela houve.

var falhas := 0
const SEGUNDOS_PARA_ANUNCIAR := 12.0
const SEGUNDOS_POR_PASSO := 15.0
## Quantas canas a missão pede. Lida do dado, e conferida contra isto: se o
## arquivo mudar o número, este portão não pode continuar medindo o antigo.
const CANAS_DA_MISSAO := 6


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("CANDINHA_FALHOU: " + rotulo)
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
	var inv := root.get_node("/root/Inventario")
	var energia := root.get_node("/root/Energia")
	var recursos := jogo.get_node_or_null("Recursos3D")
	var candinha: Node3D = null
	for morador in jogo.get("moradores"):
		if str((morador.dados as Dictionary).get("id", "")) == "candinha":
			candinha = morador
	_conferir(candinha != null, "o vale não tem a Dona Candinha")
	_conferir(recursos != null, "o vale não montou os alvos de trabalho")
	if candinha == null or jogador == null or recursos == null:
		_fechar()
		return

	# --- 1. A CADEIA É DELA, DE DOIS PASSOS, E NÃO É DE ENREDO ---------------
	var cadeia := candinha.get_node_or_null("CadeiaDeMissoes")
	_conferir(cadeia != null, "a Dona Candinha não tem fila de missões")
	if cadeia == null:
		_fechar()
		return
	_conferir(cadeia.total() == 2,
		"a cadeia da Candinha tem %d passo(s), e são dois: cortar e entregar" % cadeia.total())
	_conferir(not cadeia.principal,
		"a garapa da praça está marcada como enredo: negócio de vizinha vem depois do enredo na lista")

	# O NÚMERO É O DO DADO. Se alguém mudar as seis para três, as perguntas
	# abaixo passariam a medir outra missão calada.
	var pedido: Dictionary = (cadeia.passos[1] as Dictionary).get("meta", {})
	_conferir(int(pedido.get("quantos", 1)) == CANAS_DA_MISSAO,
		"a entrega pede %d cana(s) e este portão mede %d" % [int(pedido.get("quantos", 1)), CANAS_DA_MISSAO])

	# --- 3. O VALE TEM CANA, E SÓ CAI DE FOICE ------------------------------
	#
	# Antes de jogar: sem pé de cana posto a missão é impossível, e a meta diria
	# apenas "faltam 6" para sempre.
	var pes_de_cana: int = recursos.restantes("cana")
	_conferir(pes_de_cana > 0,
		"o vale não pôs um pé de cana: a missão das seis canas não tem onde ser cumprida")
	print("  pés de cana postos no vale: %d" % pes_de_cana)

	jogador.global_position = candinha.global_position + Vector3(1.2, 0.0, 1.0)
	await _frames(3)
	var abriu := await _ate(func() -> bool: return bool(cadeia.iniciado), SEGUNDOS_PARA_ANUNCIAR)
	_conferir(abriu, "cheguei ao lado da Dona Candinha e a conversa não abriu")
	if not abriu:
		_fechar()
		return
	var anunciou := await _ate(func() -> bool: return cadeia.espera <= 0.0, SEGUNDOS_PARA_ANUNCIAR)
	_conferir(anunciou, "o passo da cana não chegou a anunciar")
	await _frames(2)

	# --- 2. ELA DÁ A FOICE AO PEDIR A CANA ----------------------------------
	_conferir(recursos._tem_ferramenta("foice"),
		"a Dona Candinha pediu cana cortada e não deixou a foice à mão")

	# O CORTE É DE VERDADE: anda até um pé e bate até cair, como o jogador.
	var antes_de_cortar: int = inv.quantidade("cana")
	var onde: Vector3 = recursos.mais_perto_que_rende("cana", jogador.global_position)
	_conferir(onde != Vector3.ZERO, "não achei um pé de cana para cortar")
	if onde != Vector3.ZERO:
		jogador.global_position = onde
		await _frames(4)
		energia.encher()
		var bateu := false
		for golpe in 12:
			energia.encher()
			if recursos.bater():
				bateu = true
			if inv.quantidade("cana") > antes_de_cortar:
				break
			await _frames(2)
		_conferir(bateu, "bati no pé de cana com a foice à mão e o golpe não saiu")
		_conferir(inv.quantidade("cana") > antes_de_cortar,
			"cortei o pé de cana e nenhuma cana entrou na mochila")

	# --- 4. CINCO NÃO BASTA -------------------------------------------------
	#
	# PRIMEIRO O PASSO DE JUNTAR TEM DE FECHAR, e este portão já errou aqui: a
	# primeira versão mediu as cinco canas com o passo do corte ainda aberto, e
	# a cadeia não andou — mas não andou por causa do CORTE, não por causa da
	# entrega. A pergunta passava sem poder falhar. Quem mede a entrega tem de
	# estar no passo da entrega.
	while inv.quantidade("cana") < CANAS_DA_MISSAO:
		inv.adicionar("cana", 1)
	var fechou_o_corte := await _ate(func() -> bool: return cadeia.missao >= 1, SEGUNDOS_POR_PASSO)
	_conferir(fechou_o_corte,
		"juntei as %d canas e o passo do corte não fechou" % CANAS_DA_MISSAO)
	if not fechou_o_corte:
		_fechar()
		return
	print("  %-18s %s" % ["candinha_cana", "fechou"])
	var anunciou2 := await _ate(func() -> bool: return cadeia.espera <= 0.0, SEGUNDOS_PARA_ANUNCIAR)
	_conferir(anunciou2, "o passo da entrega não chegou a anunciar")

	# Agora sim: a mochila fica com exatamente cinco, que é o estado em que o
	# jogador quase chegou — e é o estado em que a entrega sem conta diz que
	# ele chegou.
	var na_entrega: int = cadeia.missao
	while inv.quantidade("cana") > CANAS_DA_MISSAO - 1:
		inv.consumir("cana", 1)
	_conferir(inv.quantidade("cana") == CANAS_DA_MISSAO - 1,
		"não consegui deixar a mochila com %d cana(s)" % (CANAS_DA_MISSAO - 1))

	jogador.global_position = candinha.global_position + Vector3(1.0, 0.0, 0.8)
	await _frames(3)
	await _ate(func() -> bool: return cadeia.missao > na_entrega, 5.0)
	_conferir(cadeia.missao == na_entrega,
		"cheguei com %d canas e a entrega de %d fechou: a conta da meta 'levar' não está sendo feita"
			% [CANAS_DA_MISSAO - 1, CANAS_DA_MISSAO])
	_conferir(inv.quantidade("cana") == CANAS_DA_MISSAO - 1,
		"a entrega que não aconteceu comeu cana da mochila: sobraram %d" % inv.quantidade("cana"))

	# --- 5. SEIS FECHA, E AS SEIS SAEM ------------------------------------
	var respostas: Array[String] = []
	if candinha.has_signal("narrou"):
		candinha.narrou.connect(func(texto: String) -> void: respostas.append(texto))
	inv.adicionar("cana", 1)
	var na_mochila_antes: int = inv.quantidade("cana")
	_conferir(na_mochila_antes == CANAS_DA_MISSAO,
		"queria %d canas na mochila e tenho %d" % [CANAS_DA_MISSAO, na_mochila_antes])
	await _frames(3)
	var entregou := await _ate(func() -> bool: return cadeia.missao > na_entrega, SEGUNDOS_POR_PASSO)
	_conferir(entregou, "cheguei com as seis canas e a entrega não fechou")
	print("  %-18s %s" % ["candinha_garapa", "fechou" if entregou else "PRESO"])
	if entregou:
		_conferir(inv.quantidade("cana") == na_mochila_antes - CANAS_DA_MISSAO,
			"a entrega tirou %d cana(s) da mochila, e devia tirar %d"
				% [na_mochila_antes - inv.quantidade("cana"), CANAS_DA_MISSAO])
	_conferir(candinha._balao_tempo > 0.0 or not respostas.is_empty(),
		"quem recebeu a cana não respondeu: a fala do fim ficou na boca de quem pediu")
	if not respostas.is_empty():
		_conferir(str(respostas[0]).contains("caldo") or str(respostas[0]).contains("garapa"),
			"a resposta da Candinha não é a do 2D: '%s'" % respostas[0])

	# --- 6. SOBREVIVE A RECARREGAR ------------------------------------------
	var guardado: Dictionary = jogo.estado_para_salvar()
	var guardadas: Dictionary = guardado.get("cadeias", {})
	_conferir(guardadas.has("candinha"), "o save não leva a fila da Dona Candinha")
	var dela: Dictionary = guardadas.get("candinha", {})
	_conferir((dela.get("levados", []) as Array).has("candinha_garapa"),
		"o save não lembra a entrega da cana: recarregar pediria as seis de novo")

	cadeia._levados.clear()
	cadeia.missao = 0
	jogo.restaurar_do_save(guardado)
	await _frames(2)
	_conferir(not cadeia.falta_a_meta(cadeia.passos[1]),
		"recarregar esqueceu a entrega das seis canas")

	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("CANDINHA_OK: a fila é da Dona Candinha, tem dois passos e não é de enredo, ela dá a foice ao pedir a cana, o vale tem pé de cana que cai de foice e rende cana na mochila, chegar com cinco NÃO fecha a entrega de seis nem come cana, com seis fecha tirando as seis e quem recebe responde, e recarregar não pede as canas de novo")
	else:
		print("candinha: %d falha(s)" % falhas)
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
