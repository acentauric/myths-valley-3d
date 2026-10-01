extends SceneTree
## Confere as OBRAS no vale (#15): onde se toca obra, o plano antes do
## material, e o ganho da obra no corpo — uma vez só.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/obras.gd
##
## A regra é o `Obras` compartilhado, e o catálogo é o `obras.json` do 2D
## (conferido em `tests/dados_do_2d.gd`). Este portão pergunta o que é do vale:
##
##   1. NENHUMA OBRA SEM LUGAR NEM RAZÃO: toda construção que o catálogo cita
##      tem lugar no vale (`BancadasVale.OBRAS`) ou está declarada como
##      faltando, com a razão.
##   2. A ABA DE OBRAS APARECE NO LUGAR: na porta da Casa de taipa, a da casa;
##      no balcão da Venda do Bar, a do armazém junto com a venda; no mirante,
##      no poço e no píer, a de cada um. Longe de tudo, não aparece.
##   3. O PLANO ANTES DO MATERIAL: sem saber, a obra não entra na lista; o
##      plano de começo nasce sabido, e o do balcão se compra.
##   4. SEM MATERIAL NÃO SE FAZ, e dizendo o que falta.
##   5. A OBRA FEITA fica feita, consome o material e PAGA O GANHO NO CORPO UMA
##      VEZ SÓ. O `executar` do 2D não paga (só o `conceder` paga), e o vale
##      paga no painel; se o 2D consertar e os dois pagarem, isto reprova, e a
##      linha do vale sai (ver `painel_vale.pagar_o_que_a_obra_da`).

var falhas := 0
var obras
var receitas
var inventario
var progressao
var jogo


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("OBRAS_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	obras = root.get_node("/root/Obras")
	receitas = root.get_node("/root/Receitas")
	inventario = root.get_node("/root/Inventario")
	progressao = root.get_node("/root/Progressao")
	jogo = root.get_node("/root/Jogo")
	_conferir(not obras.catalogo().is_empty(), "o catálogo de obras está vazio: o obras.json não chegou ao vale")

	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(6)
	await _mundo_pronto()
	await _frames(10)
	var vale = current_scene
	var player = vale.player
	var world = vale.world
	var painel = vale.painel
	var Bancadas = load("res://scripts/prototipo_3d/bancadas_vale.gd")

	# --- 1. NENHUMA OBRA SEM LUGAR NEM RAZÃO -----------------------------------
	var familias_com_lugar := {}
	for qual in Bancadas.OBRAS:
		familias_com_lugar[obras._familia(str(qual))] = true
		var ancora := str(Bancadas.OBRAS[qual]["ancora"])
		_conferir(world.ancoras.has(ancora), "a obra '%s' aponta para a âncora '%s', que o vale não tem" % [qual, ancora])
	for qual in Bancadas.FALTAM:
		_conferir(str(Bancadas.FALTAM[qual]).length() > 20, "'%s' falta sem razão escrita" % qual)
	var alvos := {}
	for obra in obras.catalogo():
		for alvo in obras.dados(str(obra)).get("alvos", []):
			alvos[str(alvo)] = true
	for alvo in alvos:
		_conferir(familias_com_lugar.has(alvo) or Bancadas.FALTAM.has(alvo),
			"o catálogo tem obra para '%s', que não tem lugar no vale nem razão de faltar" % alvo)

	# --- 2. A ABA DE OBRAS APARECE NO LUGAR -----------------------------------
	for qual in Bancadas.OBRAS:
		var onde: Vector3 = world.ancoras[Bancadas.OBRAS[qual]["ancora"]]
		var ponto: Vector3 = onde + Vector3(Bancadas.raio(str(qual)) * 0.6, 0.0, 0.0)
		_conferir(Bancadas.obra_perto(world, ponto) == str(qual),
			"perto de '%s' a obra em foco é '%s'" % [qual, Bancadas.obra_perto(world, ponto)])
	_conferir(Bancadas.obra_perto(world, world.ancoras["Praça"] + Vector3(0, 0, 30)) == "",
		"longe de tudo ainda há obra em foco")

	var porta: Vector3 = vale.get_node("Queda").ponto_de_casa()
	player.global_position = porta
	await _frames(2)
	vale.abrir_o_painel()
	await _frames(2)
	_conferir(painel.obra_em_foco == "casa", "na porta da Casa de taipa a obra em foco é '%s'" % painel.obra_em_foco)
	_conferir(painel.abas_validas().has(painel.Aba.OBRAS), "na porta de casa a aba de obras não apareceu: %s" % str(painel.abas_validas()))

	# --- 3. O PLANO ANTES DO MATERIAL -----------------------------------------
	var disponiveis: Array = obras.disponiveis("casa")
	_conferir(disponiveis.has("casca_varanda"), "a varanda, que é plano de começo, não está na lista da casa: %s" % str(disponiveis))
	_conferir(not disponiveis.has("mobilia_rede"), "a rede entrou na lista sem o plano, que é do balcão")

	# --- 4. SEM MATERIAL NÃO SE FAZ -------------------------------------------
	_conferir(obras.impedimento("casa", "casca_varanda").begins_with("Falta"),
		"sem material, a varanda não diz o que falta: '%s'" % obras.impedimento("casa", "casca_varanda"))

	# --- 5. A OBRA FEITA, E O GANHO UMA VEZ SÓ ---------------------------------
	var custo: Dictionary = obras.custo("casca_varanda")
	for item in custo:
		inventario.adicionar(str(item), int(custo[item]))
	var teto_antes: float = progressao.energia_maxima
	var ganho := float(obras.ATRIBUTOS["casca_varanda"]["energia_maxima"])
	# Laço LIMITADO: se a aba não existe, girar para sempre trava o portão
	# em vez de reprová-lo.
	for _volta in painel.abas_validas().size():
		if painel.aba() == painel.Aba.OBRAS:
			break
		painel._proxima_aba(1)
	_conferir(painel.aba() == painel.Aba.OBRAS, "não cheguei à aba obras: %s" % str(painel.abas_validas()))
	painel.escolher(obras.disponiveis("casa").find("casca_varanda"))
	painel._confirmar()
	_conferir(obras.ja_feita("casa", "casca_varanda"), "o E na aba de obras não fez a varanda")
	for item in custo:
		_conferir(inventario.quantidade(str(item)) == 0, "a varanda não consumiu %s" % item)
	_conferir(is_equal_approx(progressao.energia_maxima, teto_antes + ganho),
		"a varanda deixou o fôlego máximo em %s, e era %s + %s: %s" % [str(progressao.energia_maxima), str(teto_antes), str(ganho),
			"o ganho não entrou" if progressao.energia_maxima < teto_antes + ganho else "o ganho entrou em dobro — o 2D consertou o executar? tire o painel_vale.pagar_o_que_a_obra_da"])
	_conferir(painel._aviso.begins_with("Obra pronta"), "a obra feita não disse que ficou pronta: '%s'" % painel._aviso)
	_conferir(not obras.disponiveis("casa").has("casca_varanda"), "a varanda feita continuou na lista")
	painel.fechar()

	# O plano do balcão: comprar a rede e ela aparece na casa.
	jogo.dinheiro = 1000
	_conferir(receitas.a_venda().has("mobilia_rede"), "o balcão não vende o plano da rede")
	_conferir(receitas.comprar("mobilia_rede"), "não consegui comprar o plano da rede")
	_conferir(obras.disponiveis("casa").has("mobilia_rede"), "com o plano comprado, a rede não entrou na lista da casa")

	# No balcão da Venda do Bar: a obra do armazém junto com a venda.
	var balcao: Vector3 = world.ancoras["Venda do Bar"] + world.ancoras.get("Venda do BarFrente", Vector3.BACK) * (Bancadas.raio("venda") - 1.0)
	player.global_position = world.ground_position(balcao, 0.07)
	await _frames(2)
	vale.abrir_o_painel()
	await _frames(2)
	_conferir(painel.obra_em_foco == "armazem" and painel.na_venda,
		"no balcão, obra em foco '%s' e venda %s: são as duas" % [painel.obra_em_foco, str(painel.na_venda)])
	_conferir(painel.abas_validas().has(painel.Aba.OBRAS) and painel.abas_validas().has(painel.Aba.VENDA),
		"no balcão as abas são %s, e são obras e venda" % str(painel.abas_validas()))
	painel.fechar()
	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("OBRAS_OK: toda construção do catálogo tem lugar ou razão; a aba de obras aparece na casa, no armazém, no mirante, no poço e no píer, e some longe; o plano vem antes do material, o de começo nasce sabido e o do balcão se compra; sem material a obra diz o que falta; a obra feita consome, some da lista, diz que ficou pronta e paga o ganho no corpo uma vez só")
	else:
		print("obras: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
