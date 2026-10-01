extends SceneTree
## JOGA O PIRÃO DA DONA FILÓ — a primeira missão do vale que se cumpre LEVANDO.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/cadeia_da_filo.gd
##
## Veio do jogo 2D (`data/dialogos/arraial.json`, passo filo_almoco). A Dona
## Filó faz pirão toda manhã e o Tonho sai antes; ela já não desce a ladeira do
## pontal, e pede que se leve. No vale ela fica na Casa da estrada e ele no
## píer — a mesma ladeira.
##
##
## POR QUE ESTA MISSÃO PEDIU UM TIPO DE META NOVO
##
## As duas que existiam são ESTADOS do mundo: "juntar" pergunta quantas pedras
## há na mochila, "derrubar" pergunta quantos pés caíram. Dá para perguntar as
## duas a qualquer momento e a resposta é a mesma.
##
## Entrega é um INSTANTE. O item muda de mão, e depois disso a mochila está
## vazia — que é indistinguível de "nunca pegou". Perguntar "o jogador tem o
## pirão?" depois de entregar responderia "não", e a missão pediria o pirão
## outra vez. Daí a meta "levar" e a memória do que já foi entregue.
##
## Este portão guarda seis coisas:
##
##   1. A CADEIA É DA DONA FILÓ, e abre quando o jogador chega perto dela.
##   2. ELA DÁ O PIRÃO AO ANUNCIAR, e não depois — regra 1 do tutorial do 2D.
##   3. CHEGAR PERTO DO TONHO SEM O PIRÃO NÃO FECHA NADA. Sem isto o passo
##      fecharia por proximidade e a entrega seria enfeite.
##   4. COM O PIRÃO NA MÃO, ENCOSTAR NELE ENTREGA: o item SAI da mochila e
##      QUEM RESPONDE É ELE, não ela. A Dona Filó está do outro lado do vale, e
##      balão que o jogador não vê é fala que não aconteceu.
##   5. ENTREGAR UMA VEZ BASTA. Depois da entrega a mochila está vazia, e a
##      missão não pode voltar a pedir.
##   6. O ARREMATE DESTA CADEIA NÃO É FALADO: quem fala no fim é o Tonho, pela
##      meta. O arremate é a nota que fica no objetivo.

var falhas := 0
const SEGUNDOS_PARA_ANUNCIAR := 12.0
const SEGUNDOS_POR_PASSO := 15.0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("PIRAO_FALHOU: " + rotulo)
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
	_conferir(jogador != null, "não achei o jogador")
	if jogador == null:
		_fechar()
		return

	var filo: Node3D = null
	var tonho: Node3D = null
	for morador in jogo.get("moradores"):
		match str((morador.dados as Dictionary).get("id", "")):
			"filo":
				filo = morador
			"tonho":
				tonho = morador
	_conferir(filo != null, "o vale não tem a Dona Filó")
	_conferir(tonho != null, "o vale não tem o Tonho: sem quem recebe não há entrega")
	if filo == null or tonho == null:
		_fechar()
		return

	# --- 1. A CADEIA É DELA, E ABRE AO CHEGAR PERTO --------------------------
	var cadeia := filo.get_node_or_null("CadeiaDeMissoes")
	_conferir(cadeia != null, "a Dona Filó não tem fila de missões")
	if cadeia == null:
		_fechar()
		return
	_conferir(cadeia.total() == 2,
		"a cadeia do pirão tem %d passo(s), e são dois: o pedido e a entrega" % cadeia.total())
	_conferir(cadeia.achar_morador.is_valid(),
		"a cadeia não sabe achar morador: a meta 'levar' nunca encontraria o Tonho")

	jogador.global_position = filo.global_position + Vector3(1.2, 0.0, 1.0)
	await _frames(3)
	var abriu := await _ate(func() -> bool: return bool(cadeia.iniciado), SEGUNDOS_PARA_ANUNCIAR)
	_conferir(abriu, "cheguei ao lado da Dona Filó e a missão não abriu")
	if not abriu:
		_fechar()
		return
	print("")

	# O primeiro passo é o pedido dela: anuncia e fecha ali mesmo.
	var fechou_pedido := await _ate(func() -> bool: return cadeia.missao >= 1, SEGUNDOS_POR_PASSO)
	_conferir(fechou_pedido, "o passo do pedido não fechou com o jogador ao lado dela")
	print("  %-14s %s" % ["filo_pedido", "fechou" if fechou_pedido else "PRESO"])

	# --- 2. ELA DÁ O PIRÃO AO ANUNCIAR ---------------------------------------
	var anunciou := await _ate(func() -> bool: return cadeia.espera <= 0.0, SEGUNDOS_PARA_ANUNCIAR)
	_conferir(anunciou, "o passo da entrega não chegou a anunciar")
	await _frames(2)
	_conferir(inv.tem("pirao"),
		"a Dona Filó pediu para levar o pirão e não deu o pirão: o jogador rodaria o vale procurando")

	# --- 3. PERTO DO TONHO SEM O PIRÃO NÃO FECHA -----------------------------
	#
	# Tira o pirão da mão e encosta nele: se o passo fechar assim, a entrega é
	# enfeite e a missão fecha por proximidade como qualquer visita.
	inv.consumir("pirao", 1)
	_conferir(not inv.tem("pirao"), "não consegui tirar o pirão da mochila para o teste")
	jogador.global_position = tonho.global_position + Vector3(1.0, 0.0, 0.8)
	var antes: int = cadeia.missao
	await _ate(func() -> bool: return cadeia.missao != antes, 3.0)
	_conferir(cadeia.missao == antes,
		"o passo da entrega fechou sem o pirão: a entrega virou enfeite")

	# --- 4 e 5. COM O PIRÃO, ENCOSTAR ENTREGA, E QUEM FALA É ELE -------------
	inv.adicionar("pirao", 1)
	var respostas: Array[String] = []
	if tonho.has_signal("narrou"):
		tonho.narrou.connect(func(texto: String) -> void: respostas.append(texto))
	jogador.global_position = tonho.global_position + Vector3(1.0, 0.0, 0.8)
	await _frames(3)
	var entregou := await _ate(func() -> bool: return not inv.tem("pirao"), SEGUNDOS_POR_PASSO)
	_conferir(entregou, "encostei no Tonho com o pirão na mão e ele não saiu da mochila")
	var fechou := await _ate(func() -> bool: return cadeia.acabou(), SEGUNDOS_POR_PASSO)
	_conferir(fechou, "o pirão foi entregue e o passo não fechou")
	print("  %-14s %s" % ["filo_pirao", "fechou" if fechou else "PRESO"])

	# A resposta é DELE. Sem acesso ao balão em headless, o que se mede é que o
	# Tonho tomou a palavra — é ele quem fala, e a fala é a do 2D.
	_conferir(tonho._balao_tempo > 0.0 or not respostas.is_empty(),
		"quem recebeu não respondeu: a fala do fim ficou na boca de quem pediu")
	if not respostas.is_empty():
		_conferir(str(respostas[0]).contains("Ela mandou"),
			"a resposta do Tonho não é a do 2D: '%s'" % respostas[0])

	# Entregar uma vez basta: a mochila está vazia e a missão não volta a pedir.
	_conferir(not inv.tem("pirao"), "o pirão voltou para a mochila depois da entrega")
	_conferir(cadeia.acabou(),
		"a cadeia reabriu o passo da entrega com a mochila vazia: pediria o pirão outra vez")

	# --- 6. O ARREMATE NÃO É FALADO ------------------------------------------
	_conferir(not bool(cadeia.arremate.get("narra", true)),
		"o arremate desta cadeia está marcado para ser falado, e a Dona Filó está longe do píer")
	_conferir(not str(cadeia.arremate.get("texto", "")).is_empty(),
		"a cadeia acabou sem nota de arremate: o objetivo do HUD fica em branco")

	# --- 7. A ENTREGA SOBREVIVE A RECARREGAR ---------------------------------
	#
	# Mesma armadilha da missão do cemitério, por outra porta. Entrega é
	# acontecimento: depois dela a mochila está vazia, e mochila vazia é
	# indistinguível de "nunca pegou". Sem a memória no save, recarregar
	# reabriria o passo pedindo um pirão que já foi entregue e não existe mais —
	# e o jogador não teria como cumprir.
	#
	# Conferido em memória, sem tocar em arquivo de partida (ver o portão do
	# coveiro).
	var guardado: Dictionary = jogo.estado_para_salvar()
	var guardadas: Dictionary = guardado.get("cadeias", {})
	_conferir(guardadas.has("filo"), "o save não leva a fila da Dona Filó")
	var dela: Dictionary = guardadas.get("filo", {})
	_conferir((dela.get("levados", []) as Array).has("filo_pirao"),
		"o save não lembra que o pirão foi entregue: recarregar pediria ele outra vez")

	cadeia._levados.clear()
	cadeia.missao = 1
	jogo.restaurar_do_save(guardado)
	await _frames(2)
	_conferir(cadeia.acabou(),
		"recarregar reabriu o passo da entrega: ficou no passo %d de %d" % [cadeia.missao, cadeia.total()])
	_conferir(not cadeia.falta_a_meta(cadeia.passos[1]),
		"recarregar esqueceu a entrega: a missão voltaria a pedir o pirão")

	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("PIRAO_OK: a fila é da Dona Filó e abre ao lado dela, ela dá o pirão ao anunciar, chegar perto do Tonho sem o pirão não fecha nada, com ele na mão a entrega acontece e quem responde é o Tonho, entregar uma vez basta, o arremate fica escrito em vez de falado longe, e recarregar não pede o pirão de novo")
	else:
		print("pirão: %d falha(s)" % falhas)
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
