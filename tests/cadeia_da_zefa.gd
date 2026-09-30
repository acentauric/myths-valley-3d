extends SceneTree
## JOGA A CONVERSA DA DONA ZEFA — a cadeia que não pede nada do mundo.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/cadeia_da_zefa.gd
##
## Veio do jogo 2D (`data/dialogos/arraial.json`, passos zefa_cosme /
## zefa_conversa / zefa_despedida). A Dona Zefa manda o jogador falar com o
## neto; o Cosme conta que tem emprego em Salvador e pede segredo; ela já sabia
## desde que a carta chegou, porque quem lê carta naquela casa é ela.
##
##
## A META NOVA: FALAR COM ALGUÉM
##
## É a forma mais comum de missão do 2D — "Fale com o Tonho no pontal", "Volte à
## Dona Zefa" — e o vale não sabia fazer. As duas metas que existiam mediam o
## mundo: "juntar" conta item na mochila, "derrubar" conta pé cortado. Falar não
## deixa nada no mundo para contar depois; é ACONTECIMENTO, como a entrega.
##
## Por isso ela nasceu junto com a de entrega, no mesmo corpo: "levar" é "falar"
## com um item na mão. Escrevê-las separadas seria ter a mesma travessia duas
## vezes, e a segunda ficaria para trás no primeiro conserto da primeira.
##
## Cinco perguntas:
##
##   1. A CADEIA É DA DONA ZEFA e abre quando o jogador chega perto dela.
##   2. CHEGAR PERTO DELA NÃO FECHA O PASSO QUE PEDE O COSME. Sem isto, "fale
##      com o Cosme" fecharia sozinho ao lado de quem mandou — que é o defeito
##      que a meta existe para não ter.
##   3. CHEGAR PERTO DO COSME FECHA, E É ELE QUEM RESPONDE. A fala do fim é de
##      quem recebe, não de quem pediu: a Dona Zefa fica na casa de taipa, e
##      ouvir a resposta dela de longe seria ouvir um balão que não se vê.
##   4. FALAR UMA VEZ BASTA, e o passo não reabre.
##   5. A CONVERSA SOBREVIVE A RECARREGAR — mesma armadilha do pirão: depois do
##      encontro não sobra nada no mundo que prove que ele houve.

var falhas := 0
const SEGUNDOS_PARA_ANUNCIAR := 12.0
const SEGUNDOS_POR_PASSO := 15.0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("ZEFA_FALHOU: " + rotulo)
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
	var caderno := root.get_node("/root/CadernoDoVale")
	var zefa: Node3D = null
	var cosme: Node3D = null
	for morador in jogo.get("moradores"):
		match str((morador.dados as Dictionary).get("id", "")):
			"zefa":
				zefa = morador
			"cosme":
				cosme = morador
	_conferir(zefa != null, "o vale não tem a Dona Zefa")
	_conferir(cosme != null, "o vale não tem o Cosme: sem ele a conversa não acontece")
	if zefa == null or cosme == null or jogador == null:
		_fechar()
		return

	# --- 1. A CADEIA É DELA, E ABRE AO CHEGAR PERTO --------------------------
	var cadeia := zefa.get_node_or_null("CadeiaDeMissoes")
	_conferir(cadeia != null, "a Dona Zefa não tem fila de missões")
	if cadeia == null:
		_fechar()
		return
	_conferir(cadeia.total() == 3,
		"a cadeia da Zefa tem %d passo(s), e são três: o neto, a conversa e o saveiro" % cadeia.total())
	_conferir(cadeia.principal,
		"a conversa da Dona Zefa não está marcada como enredo: ela vem antes de um favor de vizinho na lista")

	jogador.global_position = zefa.global_position + Vector3(1.2, 0.0, 1.0)
	await _frames(3)
	var abriu := await _ate(func() -> bool: return bool(cadeia.iniciado), SEGUNDOS_PARA_ANUNCIAR)
	_conferir(abriu, "cheguei ao lado da Dona Zefa e a conversa não abriu")
	if not abriu:
		_fechar()
		return
	var anunciou := await _ate(func() -> bool: return cadeia.espera <= 0.0, SEGUNDOS_PARA_ANUNCIAR)
	_conferir(anunciou, "o primeiro passo não chegou a anunciar")
	await _frames(2)
	print("")

	# --- 2. AO LADO DE QUEM MANDOU, O PASSO NÃO FECHA ------------------------
	#
	# O jogador está encostado na Dona Zefa, e o passo pede o COSME. Se fechar
	# assim, "fale com fulano" vira "fique parado onde já está".
	_conferir(cadeia.missao == 0,
		"a cadeia pulou o passo do neto antes de o jogador falar com ele")
	var antes: int = cadeia.missao
	await _ate(func() -> bool: return cadeia.missao != antes, 4.0)
	_conferir(cadeia.missao == antes,
		"o passo que pede o Cosme fechou ao lado da Dona Zefa: a meta de falar virou enfeite")

	# --- 3. PERTO DO COSME FECHA, E É ELE QUEM RESPONDE ----------------------
	var respostas: Array[String] = []
	if cosme.has_signal("narrou"):
		cosme.narrou.connect(func(texto: String) -> void: respostas.append(texto))
	jogador.global_position = cosme.global_position + Vector3(1.0, 0.0, 0.8)
	await _frames(3)
	var fechou := await _ate(func() -> bool: return cadeia.missao > antes, SEGUNDOS_POR_PASSO)
	_conferir(fechou, "cheguei ao lado do Cosme e o passo não fechou")
	print("  %-16s %s" % ["zefa_cosme", "fechou" if fechou else "PRESO"])
	_conferir(cosme._balao_tempo > 0.0 or not respostas.is_empty(),
		"quem recebeu não respondeu: a fala do fim ficou na boca de quem pediu")
	if not respostas.is_empty():
		_conferir(str(respostas[0]).contains("Salvador"),
			"a resposta do Cosme não é a do 2D: '%s'" % respostas[0])

	# --- 4. FALAR UMA VEZ BASTA ----------------------------------------------
	_conferir(bool(cadeia._levados.get("zefa_cosme", false)),
		"a cadeia não lembra que a conversa com o Cosme aconteceu")
	_conferir(not cadeia.falta_a_meta(cadeia.passos[0]),
		"depois da conversa a meta do Cosme voltou a faltar: o passo pediria de novo")

	# O segundo passo manda voltar à Dona Zefa: perto do Cosme ele não fecha.
	var anunciou2 := await _ate(func() -> bool: return cadeia.espera <= 0.0, SEGUNDOS_PARA_ANUNCIAR)
	_conferir(anunciou2, "o passo da conversa não chegou a anunciar")
	var onde_esta: int = cadeia.missao
	await _ate(func() -> bool: return cadeia.missao != onde_esta, 4.0)
	_conferir(cadeia.missao == onde_esta,
		"o passo que manda voltar à Dona Zefa fechou com o jogador ao lado do Cosme")
	jogador.global_position = zefa.global_position + Vector3(1.0, 0.0, 0.8)
	await _frames(3)
	var voltou := await _ate(func() -> bool: return cadeia.missao > onde_esta, SEGUNDOS_POR_PASSO)
	_conferir(voltou, "voltei à Dona Zefa e o passo não fechou")
	print("  %-16s %s" % ["zefa_conversa", "fechou" if voltou else "PRESO"])

	# --- 5. A CONVERSA SOBREVIVE A RECARREGAR --------------------------------
	var guardado: Dictionary = jogo.estado_para_salvar()
	var guardadas: Dictionary = guardado.get("cadeias", {})
	_conferir(guardadas.has("zefa"), "o save não leva a fila da Dona Zefa")
	var dela: Dictionary = guardadas.get("zefa", {})
	_conferir((dela.get("levados", []) as Array).has("zefa_cosme"),
		"o save não lembra a conversa com o Cosme: recarregar mandaria falar com ele de novo")

	cadeia._levados.clear()
	cadeia.missao = 0
	jogo.restaurar_do_save(guardado)
	await _frames(2)
	_conferir(not cadeia.falta_a_meta(cadeia.passos[0]),
		"recarregar esqueceu a conversa com o Cosme")

	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("ZEFA_OK: a fila é da Dona Zefa e é de enredo, abre ao lado dela, o passo que pede o Cosme não fecha ao lado de quem mandou, fecha ao chegar nele e quem responde é ele, falar uma vez basta, voltar a ela fecha o segundo, e recarregar não manda conversar de novo")
	else:
		print("zefa: %d falha(s)" % falhas)
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
