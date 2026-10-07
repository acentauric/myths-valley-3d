extends SceneTree
## JOGA A HISTÓRIA INTEIRA DO TONHO — a rede, a conta e a terra.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/cadeia_do_tonho.gd
##
## Veio do jogo 2D (`data/dialogos/arraial.json`, passos pescador_ver /
## pescador_rede / tonho_divida / tonho_terra). Ele mostra a água, pede corda e
## tábua para refazer a rede que perdeu no rio, conta que deve mil e novecentos
## no armazém, e na volta entrega a terra do outro lado da estrada.
##
## A ORDEM É O SENTIDO, e é a de lá: a rede é o que paga o armazém, e a dívida
## paga é o que solta a terra ("eu só não queria entregar terra devendo"). Esta
## cadeia começou só com a dívida e a terra — o fim sem o começo.
##
##
## AS DUAS COISAS NOVAS
##
## 1. O PASSO QUE MANDA A UM LUGAR. As cadeias conversadas (zefa, filo,
##    candinha) vão de uma pessoa a outra. Esta manda ao armazém, e é a primeira
##    a depender de o nome do lugar resolver no vale. Importa porque o `correr`
##    faz uma gentileza perigosa: passo cujo `lugar` não resolve é PULADO em
##    silêncio, para que o vale a meio não trave numa das treze âncoras que a
##    Fase 2.5 ainda vai trazer. A gentileza é certa, e a consequência é que um
##    erro de digitação não quebra nada — só apaga o meio da missão, e ninguém
##    fica sabendo. Aconteceu ao escrever esta cadeia: o passo da rede apontava
##    "oficina", que está na lista do que falta, e teria sumido calado.
##
## 2. A ENTREGA DE DUAS COISAS. Ele pede cinco cordas E três tábuas na mesma
##    frase. A meta "levar" levava um item só; com a conta de um lado e não do
##    outro, chegar com as cordas e sem as tábuas fecharia a missão.
##
## Sete perguntas:
##
##   1. A CADEIA É DO TONHO, é de enredo e tem os cinco passos.
##   2. TODO PASSO APONTA LUGAR QUE O VALE RESOLVE — nenhum é pulado em silêncio.
##   3. O PRIMEIRO FECHA NO PÍER, que é onde ele está: é a leitura da maré.
##   4. A REDE NÃO SE FECHA COM MEIA CARGA. Com as cinco cordas e só duas
##      tábuas, ao lado dele, o passo não fecha e nada sai da mochila.
##   5. COM AS DUAS COISAS FECHA, E AS DUAS SAEM na conta certa.
##   6. O DO ARMAZÉM NÃO FECHA NO PÍER, e a viagem é de verdade; voltar ao
##      Tonho fecha o último, e é ele quem entrega a terra.
##   7. A CADEIA ENTRA NO CADERNO DO VALE e sobrevive a recarregar.

var falhas := 0
const SEGUNDOS_PARA_ANUNCIAR := 12.0
const SEGUNDOS_POR_PASSO := 15.0
## O píer e o armazém têm de estar a mais que isto um do outro, em unidades.
const TRAVESSIA_MINIMA := 15.0
## O que a rede cobra, conferido contra o dado: se o arquivo mudar os números,
## este portão não pode continuar medindo os antigos.
const REDE_COBRA := {"corda": 5, "tabua": 3}


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
	var inv := root.get_node("/root/Inventario")
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

	# --- 1. A CADEIA É DELE, DE ENREDO, E TEM CINCO PASSOS -------------------
	var cadeia := tonho.get_node_or_null("CadeiaDeMissoes")
	_conferir(cadeia != null, "o Tonho não tem fila de missões")
	if cadeia == null:
		_fechar()
		return
	_conferir(cadeia.total() == 5,
		"a cadeia do Tonho tem %d passo(s), e são cinco: a maré, a rede, a dívida, o livro e a terra"
			% cadeia.total())
	_conferir(cadeia.principal,
		"a história do Tonho não está marcada como enredo: ela vem depois de um favor de vizinho na lista")
	if cadeia.total() != 5:
		_fechar()
		return

	# --- 2. TODO PASSO APONTA LUGAR QUE O VALE RESOLVE -----------------------
	#
	# Perguntado ao Lugares antes de jogar: passo cujo lugar não resolve some
	# calado, e as perguntas abaixo passariam a medir uma cadeia mais curta sem
	# ninguém notar.
	for i in cadeia.passos.size():
		var onde := str((cadeia.passos[i] as Dictionary).get("lugar", ""))
		_conferir(lugares.resolve(onde),
			"o passo %d aponta '%s', que o vale não resolve: ele seria pulado em silêncio"
				% [i + 1, onde])

	# A REDE COBRA O QUE ESTE PORTÃO MEDE.
	var pedido: Dictionary = (cadeia.passos[1] as Dictionary).get("meta", {})
	var cobrada: Dictionary = pedido.get("itens", {})
	_conferir(cobrada.size() == REDE_COBRA.size(),
		"a rede cobra %d tipo(s) de material e este portão mede %d"
			% [cobrada.size(), REDE_COBRA.size()])
	for qual in REDE_COBRA:
		_conferir(int(cobrada.get(qual, 0)) == int(REDE_COBRA[qual]),
			"a rede cobra %s de %s e este portão mede %s"
				% [str(cobrada.get(qual, 0)), qual, str(REDE_COBRA[qual])])

	var ponto_do_armazem: Vector3 = lugares.ponto(
		str((cadeia.passos[3] as Dictionary).get("lugar", "")))

	jogador.global_position = tonho.global_position + Vector3(1.2, 0.0, 1.0)
	await _frames(3)
	# A FILA ESPERA A CHEGADA DO PEDRO (docs/mundo/CHEGADA_E_MUTIROES.md, regra 7):
	# ao lado do morador, com a chegada em curso, ela não abre; acabada, abre.
	var guia = current_scene.get("pedro")
	await _ate(func() -> bool: return false, 1.5)
	_conferir(not cadeia.iniciado, "ao lado do Tonho, a fila dele abriu sozinha, sem o E")
	await _falar_com(tonho)
	_conferir(not cadeia.iniciado, "a fila do Tonho abriu com a chegada do Pedro em curso")
	if guia != null:
		guia.missao = guia.MISSOES.size()
		guia.set("_despedida_feita", true)
		# O TONHO VOLTA AO PÍER (07/10): na chegada ele espera na areia ao lado do píer, e só
		# volta à rotina sem ninguém olhando. Acabado o tutorial, aqui ele já está no posto —
		# que é onde lê a maré —, e o jogador ao lado dele.
		current_scene.set("_tonho_na_areia", false)
		tonho.liberar()
		tonho.ir_ao_posto_agora()
		jogador.global_position = tonho.global_position + Vector3(1.2, 0.0, 1.0)
		await _frames(3)
	# A REDE É DE MADEIRA, e a fila espera os machados do avô do Pedro, na ponte
	# (`prototype._ja_recebeu_o_machado`): com a chegada feita e sem eles, o E
	# ainda não abre; com a ponte passada deles, abre.
	await _falar_com(tonho)
	await _frames(3)
	_conferir(not cadeia.iniciado, "a fila do Tonho abriu antes dos machados do avô: a rede pede madeira, e ainda não há machado")
	var da_ponte = current_scene._cadeias.get("pedro_ponte")
	if da_ponte != null:
		da_ponte.iniciado = true
		for i in da_ponte.passos.size():
			if str((da_ponte.passos[i] as Dictionary).get("id", "")) == "buscar_machado":
				da_ponte.missao = i + 1
	await _falar_com(tonho)
	var abriu := await _ate(func() -> bool: return bool(cadeia.iniciado), SEGUNDOS_PARA_ANUNCIAR)
	_conferir(abriu, "com o E no Tonho, a conversa não abriu")
	if not abriu:
		_fechar()
		return

	# --- 3. O PRIMEIRO FECHA NO PÍER ----------------------------------------
	var leu_a_mare := await _ate(func() -> bool: return cadeia.missao >= 1, SEGUNDOS_POR_PASSO)
	_conferir(leu_a_mare, "o passo da maré não fechou ao lado do Tonho, e é lá que ele a lê")
	print("  %-16s %s" % ["pescador_ver", "fechou" if leu_a_mare else "PRESO"])
	if not leu_a_mare:
		_fechar()
		return
	var anunciou := await _ate(func() -> bool: return cadeia.espera <= 0.0, SEGUNDOS_PARA_ANUNCIAR)
	_conferir(anunciou, "o passo da rede não chegou a anunciar")

	# ENQUANTO ABERTO, O PASSO ESTÁ NAS ATIVAS do caderno: é o que o jogador lê
	# no menu de missão enquanto atravessa o vale. Perguntado pelo nome que a
	# PRÓPRIA cadeia dá ao passo — a regra de como o dono e o passo viram um id é
	# dela, e copiá-la para cá envelheceria calada.
	var id_da_rede: String = cadeia._id_no_caderno(cadeia.passos[1])
	_conferir(caderno.tem(id_da_rede),
		"o passo da rede não está nas missões abertas do caderno ('%s')" % id_da_rede)

	# --- 4. A REDE NÃO SE FECHA COM MEIA CARGA ------------------------------
	#
	# Cinco cordas e só DUAS tábuas: é o estado de quem torceu tudo e serrou
	# quase. É onde a entrega sem conta de cada item diz que se chegou.
	var na_rede: int = cadeia.missao
	for qual in REDE_COBRA:
		while inv.quantidade(str(qual)) > 0:
			inv.consumir(str(qual), 1)
	for i in int(REDE_COBRA["corda"]):
		inv.adicionar("corda", 1)
	for i in int(REDE_COBRA["tabua"]) - 1:
		inv.adicionar("tabua", 1)
	_conferir(inv.quantidade("corda") == int(REDE_COBRA["corda"])
			and inv.quantidade("tabua") == int(REDE_COBRA["tabua"]) - 1,
		"não consegui deixar a mochila com as cordas e uma tábua de menos")

	jogador.global_position = tonho.global_position + Vector3(1.0, 0.0, 0.8)
	await _frames(3)
	await _falar_com(tonho)
	await _ate(func() -> bool: return cadeia.missao > na_rede, 5.0)
	_conferir(cadeia.missao == na_rede,
		"cheguei com uma tábua de menos e a rede fechou: a conta da entrega não é feita item por item")
	_conferir(inv.quantidade("corda") == int(REDE_COBRA["corda"]),
		"a entrega que não aconteceu comeu corda: sobraram %d" % inv.quantidade("corda"))

	# --- 5. COM AS DUAS COISAS FECHA, E AS DUAS SAEM ------------------------
	var respostas: Array[String] = []
	if tonho.has_signal("narrou"):
		tonho.narrou.connect(func(texto: String) -> void: respostas.append(texto))
	inv.adicionar("tabua", 1)
	var corda_antes: int = inv.quantidade("corda")
	var tabua_antes: int = inv.quantidade("tabua")
	await _frames(3)
	await _falar_com(tonho)
	var fez_a_rede := await _ate(func() -> bool: return cadeia.missao > na_rede, SEGUNDOS_POR_PASSO)
	_conferir(fez_a_rede, "cheguei com as cinco cordas e as três tábuas e a rede não fechou")
	print("  %-16s %s" % ["pescador_rede", "fechou" if fez_a_rede else "PRESO"])
	if fez_a_rede:
		_conferir(inv.quantidade("corda") == corda_antes - int(REDE_COBRA["corda"]),
			"a entrega tirou %d corda(s), e devia tirar %d"
				% [corda_antes - inv.quantidade("corda"), int(REDE_COBRA["corda"])])
		_conferir(inv.quantidade("tabua") == tabua_antes - int(REDE_COBRA["tabua"]),
			"a entrega tirou %d tábua(s), e devia tirar %d"
				% [tabua_antes - inv.quantidade("tabua"), int(REDE_COBRA["tabua"])])
	if not respostas.is_empty():
		var tudo := " ".join(respostas)
		_conferir(tudo.contains("rede") or tudo.contains("malha"),
			"a resposta da rede não é a do 2D: '%s'" % respostas[0])

	# --- 6. A DÍVIDA, A TRAVESSIA E A TERRA ---------------------------------
	var fechou_divida := await _ate(func() -> bool: return cadeia.missao >= 3, SEGUNDOS_POR_PASSO)
	_conferir(fechou_divida, "o passo da dívida não fechou ao lado do Tonho")
	print("  %-16s %s" % ["tonho_divida", "fechou" if fechou_divida else "PRESO"])
	var anunciou2 := await _ate(func() -> bool: return cadeia.espera <= 0.0, SEGUNDOS_PARA_ANUNCIAR)
	_conferir(anunciou2, "o passo do livro não chegou a anunciar")

	var no_pier: int = cadeia.missao
	await _ate(func() -> bool: return cadeia.missao != no_pier, 4.0)
	_conferir(cadeia.missao == no_pier,
		"o passo que manda ao armazém fechou com o jogador parado no píer")

	var travessia: float = jogador.global_position.distance_to(ponto_do_armazem)
	_conferir(travessia > TRAVESSIA_MINIMA,
		"o armazém está a %.1f u do píer: não é travessia, é um passo ao lado" % travessia)
	jogador.global_position = ponto_do_armazem
	await _frames(3)
	var chegou := await _ate(func() -> bool: return cadeia.missao > no_pier, SEGUNDOS_POR_PASSO)
	_conferir(chegou, "cheguei ao armazém e o passo não fechou")
	print("  %-16s %s  (travessia de %.1f u)"
		% ["tonho_livro", "fechou" if chegou else "PRESO", travessia])

	var anunciou3 := await _ate(func() -> bool: return cadeia.espera <= 0.0, SEGUNDOS_PARA_ANUNCIAR)
	_conferir(anunciou3, "o passo da terra não chegou a anunciar")
	var no_armazem: int = cadeia.missao
	await _ate(func() -> bool: return cadeia.missao != no_armazem, 4.0)
	_conferir(cadeia.missao == no_armazem,
		"o passo que manda voltar ao Tonho fechou com o jogador no armazém")

	respostas.clear()
	jogador.global_position = tonho.global_position + Vector3(1.0, 0.0, 0.8)
	await _frames(3)
	await _falar_com(tonho)
	var voltou := await _ate(func() -> bool: return cadeia.missao > no_armazem, SEGUNDOS_POR_PASSO)
	_conferir(voltou, "voltei ao Tonho e o passo da terra não fechou")
	print("  %-16s %s" % ["tonho_terra", "fechou" if voltou else "PRESO"])
	var no_balao := str(tonho.balao.get("_texto").text)
	_conferir(tonho._balao_tempo > 0.0 and (no_balao.contains("chão") or no_balao.contains("terra")),
		"quem entrega a terra não falou: a fala do fim ficou na boca de quem mandou embora ('%s')" % no_balao)
	if not respostas.is_empty():
		var tudo2 := " ".join(respostas)
		_conferir(tudo2.contains("chão") or tudo2.contains("terra"),
			"a resposta da terra não é a do 2D: '%s'" % respostas[0])
	_conferir(cadeia.acabou(), "a cadeia do Tonho não acabou depois dos cinco passos")

	# --- 7. O CADERNO E O RECARREGAR ----------------------------------------
	#
	# Passo cumprido SAI das ativas e entra nas cumpridas, que é o que fecha a
	# missão no menu em vez de deixá-la aberta para sempre.
	for i in cadeia.passos.size():
		var qual_id: String = cadeia._id_no_caderno(cadeia.passos[i])
		_conferir(caderno.cumpridas.has(qual_id),
			"o passo %d não consta como cumprido no caderno ('%s')" % [i + 1, qual_id])

	var guardado: Dictionary = jogo.estado_para_salvar()
	var guardadas: Dictionary = guardado.get("cadeias", {})
	_conferir(guardadas.has("tonho"), "o save não leva a fila do Tonho")
	var dele: Dictionary = guardadas.get("tonho", {})
	var levados: Array = dele.get("levados", [])
	_conferir(levados.has("pescador_rede"),
		"o save não lembra a entrega da rede: recarregar pediria corda e tábua de novo")
	_conferir(levados.has("tonho_terra"),
		"o save não lembra a entrega da terra: recarregar mandaria voltar ao píer de novo")

	cadeia._levados.clear()
	cadeia.missao = 0
	jogo.restaurar_do_save(guardado)
	await _frames(2)
	_conferir(not cadeia.falta_a_meta(cadeia.passos[1]),
		"recarregar esqueceu a entrega da rede")
	_conferir(not cadeia.falta_a_meta(cadeia.passos[4]),
		"recarregar esqueceu a entrega da terra")

	_fechar()


## O E AO LADO DE QUEM SE FALA, pelo caminho do jogo (`tecla_dos_moradores.gd`):
## conversar, abrir a fila do morador, cumprir o passo que manda a ele.
func _falar_com(morador) -> void:
	current_scene.get("tecla_dos_moradores").usar(morador)
	await process_frame


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("TONHO_OK: a fila é do Tonho, é de enredo e tem os cinco passos da história dele; todo passo aponta lugar que o vale resolve; a maré fecha no píer; a rede NÃO fecha com uma tábua de menos nem come material, e com as cinco cordas e as três tábuas fecha tirando as duas contas certas; a dívida fecha no píer, o armazém não fecha antes da travessia, voltar ao Tonho fecha a terra e é ele quem a entrega; e os cinco passos constam como cumpridos no caderno, com o save lembrando as duas entregas")
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
