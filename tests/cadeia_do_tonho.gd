extends SceneTree
## JOGA A HISTÓRIA INTEIRA DO TONHO — a rede, a conta e o primeiro peixe.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/cadeia_do_tonho.gd
##
## Veio do jogo 2D (`data/dialogos/arraial.json`, passos pescador_ver /
## pescador_rede / tonho_divida / tonho_terra). Ele mostra a água, pede corda e
## tábua para refazer a rede que perdeu no rio, conta que deve mil e novecentos
## no armazém; o jogador paga a conta ao Seu Nicolau, e na volta o Tonho lhe dá o
## primeiro peixe da rede nova.
##
## A ORDEM É O SENTIDO, e é a de lá: a rede é o que paga o armazém. No 2D a dívida
## paga soltava a terra do outro lado da estrada; o vale não tem terras nem o livro
## de fiado, e até 08/10 a dívida zerava sem ninguém pagar (o passo do armazém era
## só a ida). Desde a correção das falas (docs/falas), o livro se paga de verdade —
## 1.900 réis da bolsa, levados ao Seu Nicolau (`CadeiaDeMissoes.REIS`) — e o fim
## é o primeiro lanço da rede, "que é de quem fez a rede".
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
##   6. A CONTA SE PAGA AO SEU NICOLAU, que está longe do píer: com um réis de
##      menos ele não risca nada e a bolsa fica como estava; com a conta inteira
##      ele risca, e a bolsa perde exatamente a conta. Voltar ao Tonho fecha o
##      último, é ele quem responde, e o robalo — o primeiro peixe — chega.
##   7. A CADEIA ENTRA NO CADERNO DO VALE e sobrevive a recarregar.

var falhas := 0
const SEGUNDOS_PARA_ANUNCIAR := 12.0
const SEGUNDOS_POR_PASSO := 15.0
## O Tonho e o Seu Nicolau têm de estar a mais que isto um do outro, em unidades.
const TRAVESSIA_MINIMA := 15.0
## A conta do Tonho no livro do Seu Nicolau, em réis, conferida contra o dado.
const CONTA_DO_TONHO := 1900
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
	# O ACEITE É AUTOMÁTICO AQUI (08/10): este portão abre filas pelo E e segue; a tela de aceite
	# pausaria o vale no meio da medida (a tela tem portão próprio, tests/missao_a_vista.gd).
	if jogo.get("aceite") != null:
		jogo.aceite.automatico = true
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

	# O LIVRO COBRA A CONTA QUE ESTE PORTÃO MEDE: levar réis ao Seu Nicolau.
	var livro: Dictionary = (cadeia.passos[3] as Dictionary).get("meta", {})
	_conferir(str(livro.get("tipo", "")) == "levar" and str(livro.get("item", "")) == "reis"
			and str(livro.get("a_quem", "")) == "mercador",
		"o passo do livro não é levar réis ao Seu Nicolau: %s" % str(livro))
	_conferir(int(livro.get("quantos", 0)) == CONTA_DO_TONHO,
		"a conta do Tonho no dado é de %d réis, e este portão mede %d"
			% [int(livro.get("quantos", 0)), CONTA_DO_TONHO])
	var nicolau: Node3D = null
	for morador in jogo.get("moradores"):
		if str((morador.dados as Dictionary).get("id", "")) == "mercador":
			nicolau = morador
	_conferir(nicolau != null, "o vale não tem o Seu Nicolau, a quem o Tonho deve")
	if nicolau == null:
		_fechar()
		return

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

	# --- 6. A DÍVIDA, A CONTA PAGA E O PRIMEIRO PEIXE ----------------------
	var fechou_divida := await _ate(func() -> bool: return cadeia.missao >= 3, SEGUNDOS_POR_PASSO)
	_conferir(fechou_divida, "o passo da dívida não fechou ao lado do Tonho")
	print("  %-16s %s" % ["tonho_divida", "fechou" if fechou_divida else "PRESO"])
	var anunciou2 := await _ate(func() -> bool: return cadeia.espera <= 0.0, SEGUNDOS_PARA_ANUNCIAR)
	_conferir(anunciou2, "o passo do livro não chegou a anunciar")

	# A CONTA NÃO SE PAGA NO PÍER: o passo é levar os réis a quem os cobra.
	var bolsa := root.get_node("/root/Jogo")
	bolsa.dinheiro = CONTA_DO_TONHO + 100
	var no_pier: int = cadeia.missao
	await _ate(func() -> bool: return cadeia.missao != no_pier, 4.0)
	_conferir(cadeia.missao == no_pier,
		"o passo que manda pagar ao Seu Nicolau fechou com o jogador parado no píer")
	var travessia: float = tonho.global_position.distance_to(nicolau.global_position)
	_conferir(travessia > TRAVESSIA_MINIMA,
		"o Seu Nicolau está a %.1f u do Tonho: não é travessia, é um passo ao lado" % travessia)

	# UM RÉIS DE MENOS NÃO PAGA, e nada sai da bolsa.
	var do_nicolau: Array[String] = []
	if nicolau.has_signal("narrou"):
		nicolau.narrou.connect(func(texto: String) -> void: do_nicolau.append(texto))
	bolsa.dinheiro = CONTA_DO_TONHO - 1
	jogador.global_position = nicolau.global_position + Vector3(1.0, 0.0, 0.8)
	await _frames(3)
	await _falar_com(nicolau)
	await _ate(func() -> bool: return cadeia.missao != no_pier, 4.0)
	_conferir(cadeia.missao == no_pier,
		"com um réis de menos, o Seu Nicolau riscou a conta do Tonho")
	_conferir(int(bolsa.dinheiro) == CONTA_DO_TONHO - 1,
		"a entrega que não aconteceu mexeu na bolsa: eram %d réis e ficaram %d" % [CONTA_DO_TONHO - 1, int(bolsa.dinheiro)])

	# COM A CONTA INTEIRA, ele risca, e a bolsa perde exatamente a conta.
	bolsa.dinheiro = CONTA_DO_TONHO + 100
	await _frames(2)
	await _falar_com(nicolau)
	var pagou := await _ate(func() -> bool: return cadeia.missao > no_pier, SEGUNDOS_POR_PASSO)
	_conferir(pagou, "com %d réis na bolsa, ao lado do Seu Nicolau, a conta do Tonho não foi paga" % (CONTA_DO_TONHO + 100))
	print("  %-16s %s  (travessia de %.1f u)" % ["tonho_livro", "pago" if pagou else "PRESO", travessia])
	if pagou:
		_conferir(int(bolsa.dinheiro) == 100,
			"pagar a conta deixou %d réis na bolsa, e devia deixar 100" % int(bolsa.dinheiro))
		# A RESPOSTA ESPERA A VEZ na fila de falas (quem já falava termina antes).
		var falou := await _ate(func() -> bool: return _balao_diz(nicolau, ["Mil e novecentos"]), SEGUNDOS_POR_PASSO)
		_conferir(falou, "quem recebe a conta não falou: a resposta ficou na boca de quem mandou pagar ('%s')"
			% str(nicolau.balao.get("_texto").text))
		if not do_nicolau.is_empty():
			_conferir(" ".join(do_nicolau).contains("Risco o nome"),
				"a resposta do Seu Nicolau não risca o nome: '%s'" % do_nicolau[0])

	var anunciou3 := await _ate(func() -> bool: return cadeia.espera <= 0.0, SEGUNDOS_PARA_ANUNCIAR)
	_conferir(anunciou3, "o passo do primeiro peixe não chegou a anunciar")
	var na_venda: int = cadeia.missao
	await _ate(func() -> bool: return cadeia.missao != na_venda, 4.0)
	_conferir(cadeia.missao == na_venda,
		"o passo que manda voltar ao Tonho fechou com o jogador ao lado do Seu Nicolau")

	respostas.clear()
	var robalos_antes: int = inv.quantidade("robalo")
	jogador.global_position = tonho.global_position + Vector3(1.0, 0.0, 0.8)
	await _frames(3)
	await _falar_com(tonho)
	var voltou := await _ate(func() -> bool: return cadeia.missao > na_venda, SEGUNDOS_POR_PASSO)
	_conferir(voltou, "voltei ao Tonho e o passo do primeiro peixe não fechou")
	print("  %-16s %s" % ["tonho_terra", "fechou" if voltou else "PRESO"])
	# A RESPOSTA ESPERA A VEZ na fila de falas (o anúncio de antes, a saudação de quem está no píer).
	var disse_o_fim := await _ate(func() -> bool: return _balao_diz(tonho, ["rede nova", "primeiro peixe"]), SEGUNDOS_POR_PASSO)
	var no_balao := str(tonho.balao.get("_texto").text)
	_conferir(disse_o_fim,
		"quem dá o primeiro peixe não falou: a fala do fim ficou na boca de quem mandou embora ('%s')" % no_balao)
	_conferir(not no_balao.contains("terra") and not no_balao.contains("chão"),
		"o fim do Tonho ainda dá terra, que o vale não tem: '%s'" % no_balao)
	if not respostas.is_empty():
		_conferir(" ".join(respostas).contains("primeiro peixe"),
			"a resposta do fim não dá o primeiro peixe da rede: '%s'" % respostas[0])
	_conferir(inv.quantidade("robalo") >= robalos_antes + 1,
		"o primeiro peixe da rede (o robalo) não chegou à mochila: %d -> %d" % [robalos_antes, inv.quantidade("robalo")])
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
	_conferir(levados.has("tonho_livro"),
		"o save não lembra a conta paga: recarregar cobraria os %d réis de novo" % CONTA_DO_TONHO)
	_conferir(levados.has("tonho_terra"),
		"o save não lembra o primeiro peixe: recarregar mandaria voltar ao píer de novo")

	cadeia._levados.clear()
	cadeia.missao = 0
	jogo.restaurar_do_save(guardado)
	await _frames(2)
	_conferir(not cadeia.falta_a_meta(cadeia.passos[1]),
		"recarregar esqueceu a entrega da rede")
	_conferir(not cadeia.falta_a_meta(cadeia.passos[3]),
		"recarregar esqueceu a conta paga")
	_conferir(not cadeia.falta_a_meta(cadeia.passos[4]),
		"recarregar esqueceu o primeiro peixe")

	_fechar()


## O E AO LADO DE QUEM SE FALA, pelo caminho do jogo (`tecla_dos_moradores.gd`):
## conversar, abrir a fila do morador, cumprir o passo que manda a ele.
func _falar_com(morador) -> void:
	current_scene.get("tecla_dos_moradores").usar(morador)
	await process_frame


## O balão do morador está aberto e diz um destes trechos?
func _balao_diz(morador, trechos: Array) -> bool:
	if morador._balao_tempo <= 0.0:
		return false
	var dito := str(morador.balao.get("_texto").text)
	for trecho in trechos:
		if dito.contains(str(trecho)):
			return true
	return false


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("TONHO_OK: a fila é do Tonho, é de enredo e tem os cinco passos da história dele; todo passo aponta lugar que o vale resolve; a maré fecha no píer; a rede NÃO fecha com uma tábua de menos nem come material, e com as cinco cordas e as três tábuas fecha tirando as duas contas certas; a dívida fecha no píer; a conta não se paga no píer, com um réis de menos o Seu Nicolau não risca nem mexe na bolsa, e com a conta inteira risca e tira da bolsa exatamente os 1.900 réis; voltar ao Tonho fecha o último, é ele quem responde e o robalo do primeiro lanço chega; e os cinco passos constam como cumpridos no caderno, com o save lembrando as três entregas")
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
