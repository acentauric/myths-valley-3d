extends SceneTree
## JOGA O MIRANTE — as missões do arraial que o Pedro dá depois do tutorial.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/cadeia_do_mirante.gd
##
## Vieram do jogo 2D (`data/dialogos/arraial.json`: povo_conhecer,
## canteiro_material, canteiro_obra, mirante_ver, mirante_material,
## mirante_obra). "Continue importando as missões do 2D e adaptando para a
## realidade do 3D." Sete perguntas:
##
##   1. A CADEIA É DO PEDRO, é de enredo e tem os seis passos.
##   2. ELA NÃO ABRE ANTES DO TUTORIAL: no 2D estas missões vêm "depois que o
##      Pedro termina de ensinar a sobreviver" — e a ponte do rio grande é do
##      tutorial (data/missoes_ponte.json). Com o guia terminado, o E no Pedro
##      abre a ponte, e não o mirante; com a ponte de pé, abre o mirante.
##   3. O P FECHA O PRIMEIRO PASSO: a meta é o acontecimento "abriu_arraial",
##      que o vale avisa quando a tela do arraial abre.
##   4. O CANTEIRO VEM ANTES DO MIRANTE, como no 2D: oito tábuas e doze lenhas
##      fecham o material e ensinam a prancheta; o E na mesa do prumo abre a
##      aba de obras DELA; riscada a prancheta, o passo fecha e paga.
##   5. CHEGAR AO MIRANTE fecha o passo de ver.
##   6. O MATERIAL É A CONTA DE HOJE, E CADA ITEM CONTA: com a prancheta o
##      mirante pede menos que os vinte do catálogo, e uma tábua a menos que a
##      conta não basta. Juntar de uma coisa só deixaria passar quem trouxe
##      tábua de sobra e nenhuma corda.
##   7. A OBRA FECHA O ÚLTIMO, E PAGA (#48): os 1200 réis da vaquinha do arraial
##      e o pirão do Pedro, uma vez — e o HUD diz o que veio.

var falhas := 0
const SEGUNDOS := 15.0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("MIRANTE_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(3)
	var vale = current_scene
	var jogador = vale.get("player")
	var pedro = vale.get("pedro")
	var inv := root.get_node("/root/Inventario")
	var jogo := root.get_node("/root/Jogo")
	var obras := root.get_node("/root/Obras")
	var lugares := root.get_node("/root/Lugares")
	_conferir(pedro != null and jogador != null, "o vale não tem o Pedro")
	if pedro == null or jogador == null:
		_fechar()
		return

	# --- 1. A CADEIA DO PEDRO ---------------------------------------------------
	var cadeia = pedro.get_node_or_null("CadeiaDeMissoes_pedro_arraial")
	_conferir(cadeia != null, "o Pedro não tem a fila das missões do arraial")
	if cadeia == null:
		_fechar()
		return
	_conferir(cadeia.total() == 6, "a cadeia do mirante tem %d passo(s), e são seis" % cadeia.total())
	_conferir(cadeia.principal, "o mirante não está marcado como enredo")
	_conferir(cadeia.nome_da_missao != "", "a cadeia do mirante não tem nome de missão")

	# --- 2. NÃO ABRE ANTES DO TUTORIAL ------------------------------------------
	await _segundos(2.0)
	_conferir(not cadeia.iniciado, "a cadeia do mirante abriu com o tutorial do Pedro ainda em curso")
	pedro.missao = pedro.MISSOES.size()
	pedro.set("_despedida_feita", true)
	jogador.global_position = pedro.global_position + Vector3(1.2, 0.0, 1.0)
	await _segundos(1.0)
	_conferir(not cadeia.iniciado, "ao lado do Pedro, a cadeia do mirante abriu sozinha, sem o E")
	var ponte = vale._cadeias.get("pedro_ponte")
	_conferir(ponte != null, "o Pedro não tem a frente da ponte")
	vale.tecla_dos_moradores.usar(pedro)
	await _frames(3)
	_conferir(not cadeia.iniciado and ponte != null and ponte.iniciado,
		"acabado o tutorial, o primeiro E no Pedro abriu o mirante, e a ponte vem antes dele")
	# A PONTE DE PÉ (o portão `ponte` a joga inteira): o mirante passa a abrir.
	if ponte != null:
		ponte.missao = ponte.passos.size()
		ponte.despedida_feita = true
	await _frames(3)
	vale.tecla_dos_moradores.usar(pedro)
	var abriu := await _ate(func() -> bool: return bool(cadeia.iniciado), SEGUNDOS)
	_conferir(abriu, "com o tutorial terminado e o E no Pedro, a cadeia do mirante não abriu")
	if not abriu:
		_fechar()
		return
	var anunciou := await _ate(func() -> bool: return cadeia.espera <= 0.0, SEGUNDOS)
	_conferir(anunciou, "o primeiro passo do mirante não anunciou")

	# --- 3. O P FECHA O PRIMEIRO PASSO ------------------------------------------
	_conferir(cadeia.missao == 0, "a cadeia abriu no passo %d, e não no primeiro" % cadeia.missao)
	vale.telas.abrir("arraial")
	await _frames(3)
	vale.telas.fechar_tudo()
	var fechou_p := await _ate(func() -> bool: return cadeia.missao >= 1, SEGUNDOS)
	_conferir(fechou_p, "abri a tela do P e o passo 'quem é quem' não fechou")

	# --- 4. O CANTEIRO VEM ANTES DO MIRANTE ---------------------------------------
	await _ate(func() -> bool: return cadeia.espera <= 0.0, SEGUNDOS)
	_conferir(str(cadeia.passo_atual().get("id", "")) == "canteiro_material", "depois do P não veio o canteiro: '%s'" % str(cadeia.passo_atual().get("id", "")))
	_conferir(root.get_node("/root/Receitas").sabe("canteiro_prancheta"), "o material do canteiro não ensinou a prancheta")
	_ate_ter(inv, "tabua", 8)
	_ate_ter(inv, "lenha", 11)
	await _segundos(1.0)
	_conferir(cadeia.missao == 1, "com onze das doze lenhas, o material do canteiro fechou")
	_ate_ter(inv, "lenha", 12)
	_conferir(await _ate(func() -> bool: return cadeia.missao >= 2, SEGUNDOS), "com oito tábuas e doze lenhas, o material do canteiro não fechou")
	await _ate(func() -> bool: return cadeia.espera <= 0.0, SEGUNDOS)
	# O E NA MESA DO PRUMO: a aba de obras dela, com a prancheta na lista.
	var mesa: Vector3 = load("res://scripts/prototipo_3d/bancadas_vale.gd").ponto_da_provisoria(vale.world, "canteiro")
	_conferir(mesa.is_finite(), "o vale não tem a mesa do canteiro")
	jogador.teleportar(vale.world.ground_position(mesa + Vector3(0.0, 0.0, -1.3), 0.07), 0.0)
	await _frames(5)
	var tecla_b = vale.get("tecla_das_bancadas")
	_conferir(tecla_b != null and tecla_b.perto() == "canteiro", "ao lado da mesa do prumo, o E não é do canteiro")
	if tecla_b != null:
		tecla_b.usar("canteiro")
	await _frames(3)
	var painel = vale.get("painel")
	_conferir(painel != null and painel.aberto and str(painel.obra_em_foco) == "canteiro", "o E na mesa do prumo não abriu as obras do canteiro")
	_conferir(obras.disponiveis("canteiro").has("canteiro_prancheta"), "a prancheta não está na lista do canteiro: %s" % str(obras.disponiveis("canteiro")))
	if painel != null and painel.aberto:
		vale.telas.abrir("painel")
		await _frames(3)
	var beijus: int = inv.quantidade("beiju")
	_conferir(obras.executar("canteiro", "canteiro_prancheta"), "não consegui riscar a prancheta: %s" % str(obras.impedimento("canteiro", "canteiro_prancheta")))
	_conferir(await _ate(func() -> bool: return cadeia.missao >= 3, SEGUNDOS), "a prancheta riscada não fechou o passo do canteiro")
	_conferir(inv.quantidade("beiju") == beijus + 3, "o canteiro não pagou os três beijus")

	# --- 5. CHEGAR AO MIRANTE ---------------------------------------------------
	await _ate(func() -> bool: return cadeia.espera <= 0.0, SEGUNDOS)
	var mirante: Vector3 = lugares.ponto("mirante")
	_conferir(mirante.is_finite(), "o vale não tem o mirante")
	jogador.teleportar(vale.world.ground_position(mirante, 0.05), 0.0)
	var subiu := await _ate(func() -> bool: return cadeia.missao >= 4, SEGUNDOS)
	_conferir(subiu, "cheguei ao mirante e o passo de ver como ele está não fechou")

	# --- 6. O MATERIAL: A CONTA DE HOJE, E CADA ITEM CONTA -----------------------
	await _ate(func() -> bool: return cadeia.espera <= 0.0, SEGUNDOS)
	var conta: Dictionary = obras.custo("mirante_levantar")
	_conferir(int(conta.get("tabua", 0)) < 20, "com a prancheta riscada, o mirante ainda pede %d tábuas: o canteiro não abateu" % int(conta.get("tabua", 0)))
	var soma := 0
	for qual in conta:
		soma += int(conta[qual])
	_ate_ter(inv, "tabua", int(conta["tabua"]) - 1)
	_ate_ter(inv, "pedra", int(conta["pedra"]))
	_ate_ter(inv, "corda", int(conta["corda"]))
	await _segundos(1.0)
	_conferir(cadeia.missao == 4, "com uma tábua a menos que a conta, o passo do material fechou: a conta não é de cada item")
	var resumo: String = cadeia.resumo_do_passo(cadeia.passo_atual())
	_conferir(resumo.contains("%d/%d" % [soma - 1, soma]), "o resumo do material não traz a conta de hoje somada (%d/%d): '%s'" % [soma - 1, soma, resumo])
	_ate_ter(inv, "tabua", int(conta["tabua"]))
	var juntou := await _ate(func() -> bool: return cadeia.missao >= 5, SEGUNDOS)
	_conferir(juntou, "com todo o material na mochila, o passo do material não fechou")

	# --- 7. A OBRA FECHA E PAGA -------------------------------------------------
	await _ate(func() -> bool: return cadeia.espera <= 0.0, SEGUNDOS)
	var recados: Array[String] = []
	cadeia.pagou.connect(func(texto: String) -> void: recados.append(texto))
	var reis_antes: int = jogo.dinheiro
	var pirao_antes: int = inv.quantidade("pirao")
	_conferir(obras.executar("mirante", "mirante_levantar"), "não consegui levantar o mirante com o material na mochila")
	var levantou := await _ate(func() -> bool: return cadeia.missao >= 6, SEGUNDOS)
	_conferir(levantou, "o mirante ficou de pé e o último passo não fechou")
	_conferir(jogo.dinheiro == reis_antes + 1200,
		"a vaquinha do arraial pagou %d réis, e eram 1200" % (jogo.dinheiro - reis_antes))
	_conferir(inv.quantidade("pirao") == pirao_antes + 1, "o pirão do Pedro não veio")
	_conferir(recados.size() == 1 and recados[0].contains("1200"),
		"o HUD não disse o que se ganhou: %s" % str(recados))
	await _segundos(1.0)
	_conferir(jogo.dinheiro == reis_antes + 1200, "a recompensa foi paga mais de uma vez")

	# E O SAVE LEVA A FILA, com o nome dela.
	var guardadas: Dictionary = vale.estado_para_salvar().get("cadeias", {})
	_conferir(guardadas.has("pedro_arraial"), "o save não leva a fila do mirante")
	_fechar()


func _ate_ter(inv: Node, item: String, quantos: int) -> void:
	while inv.quantidade(item) < quantos:
		inv.adicionar(item, 1)
	while inv.quantidade(item) > quantos:
		inv.consumir(item, 1)


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("MIRANTE_OK: a fila do arraial é do Pedro, de enredo e de seis passos; não abre antes do tutorial nem antes da ponte; o P fecha o primeiro passo; o canteiro vem antes do mirante, e o E na mesa do prumo abre as obras dela; chegar ao mirante fecha o de ver; o material é a conta de hoje, abatida pela prancheta, e conta cada item e a obra fecha o último pagando os 1200 réis e o pirão uma vez só; e o save leva a fila")
	else:
		print("mirante: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _ate(condicao: Callable, segundos: float) -> bool:
	var ate := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < ate:
		if bool(condicao.call()):
			return true
		await process_frame
	return bool(condicao.call())


func _segundos(quanto: float) -> void:
	var ate := Time.get_ticks_msec() + int(quanto * 1000.0)
	while Time.get_ticks_msec() < ate:
		await process_frame


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
