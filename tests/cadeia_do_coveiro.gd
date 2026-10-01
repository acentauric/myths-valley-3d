extends SceneTree
## JOGA A MISSÃO DO CEMITÉRIO DO COMEÇO AO FIM — a primeira do vale que não é do Pedro.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/cadeia_do_coveiro.gd
##
## O intendente nomeou o Damião zelador do cemitério e lhe deu um papel com o
## nome dele. Nada além disso — nem foice, nem tostão. A missão é ele pedindo
## ao jogador o que o cargo não veio com, e ela veio do `data/dialogos/
## arraial.json` do jogo 2D (passos coveiro_ver / coveiro_foice / coveiro_limpar).
##
##
## O QUE ESTE PORTÃO GUARDA, e que nenhum outro guarda
##
##   1. QUE HAJA UM SEGUNDO DONO DE MISSÃO. Até esta fatia, o Pedro era o único
##      morador do vale capaz de dar missão, porque a fila morava dentro do
##      `guia_pedro.gd`. A regra mudou de casa para o `cadeia_de_missoes.gd` e
##      o Damião é quem prova que ela mudou de verdade: se a cadeia dele não
##      abrir, a mudança foi de arquivo e não de estrutura.
##
##   2. QUE A CADEIA ABRA SOZINHA AO CHEGAR PERTO. O Pedro abre no `saudar()`;
##      o Damião abre por proximidade, porque no 2D quem manda subir ao
##      cemitério é a Dona Zefa, e ela ainda não tem fila no vale. Sem isso a
##      missão existiria e seria inalcançável, que é a pior forma de existir.
##
##   3. QUE O CAPIM SÓ CAIA DE FOICE, e que a foice venha ANTES de o corte ser
##      cobrado. É a razão de o passo do meio existir: se o mato saísse no
##      machado que o jogador já tem, o passo da foice viraria enfeite e ele
##      receberia a ferramenta depois de não precisar mais dela. É a mesma
##      pergunta que o `testar_coveiro.gd` do 2D faz, na forma que o vale tem.
##
##   4. QUE CORTAR CAPIM NÃO ENCHA A MOCHILA. O capim é o primeiro alvo do vale
##      que não rende nada: no 2D o mato some, que é o que limpar quer dizer.
##      Sem guarda, `Inventario.adicionar("")` empilharia um item de id vazio a
##      cada pé cortado — defeito calado, que só apareceria na tela da mochila.
##
## A espera é em SEGUNDO REAL, e não em quadro, pela razão escrita no
## `cadeia_das_missoes.gd`: o cadeado da fala do jogo é de relógio de parede, e
## em headless os quadros voam.

var falhas := 0
const SEGUNDOS_POR_PASSO := 15.0
const SEGUNDOS_PARA_ANUNCIAR := 12.0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("COVEIRO_FALHOU: " + rotulo)
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
	var recursos := jogo.get_node_or_null("Recursos3D")
	var inv := root.get_node("/root/Inventario")
	var energia := root.get_node("/root/Energia")
	_conferir(jogador != null and recursos != null, "não achei o jogador ou os recursos")
	if jogador == null or recursos == null:
		_fechar()
		return

	# --- 1. HÁ UM SEGUNDO DONO DE MISSÃO -------------------------------------
	var damiao: Node3D = null
	for morador in jogo.get("moradores"):
		if str((morador.dados as Dictionary).get("id", "")) == "damiao":
			damiao = morador
			break
	_conferir(damiao != null, "o vale não tem o Damião: sem zelador não há missão do cemitério")
	if damiao == null:
		_fechar()
		return

	var cadeia := damiao.get_node_or_null("CadeiaDeMissoes")
	_conferir(cadeia != null,
		"o Damião não tem fila de missões: a regra saiu do guia_pedro e não chegou em ninguém")
	if cadeia == null:
		_fechar()
		return
	_conferir(cadeia.total() == 3,
		"a cadeia do coveiro tem %d passo(s), e são três: ver, encabar e limpar" % cadeia.total())
	_conferir(cadeia.recursos != null,
		"a cadeia do coveiro não recebeu os alvos: o marcador vai apontar o cemitério, e não o capim")

	# --- 2. O CAPIM ESTÁ NO CEMITÉRIO, E SÓ SAI DE FOICE ---------------------
	var pes: int = recursos.derrubados("capim") + recursos._de_pe("capim")
	_conferir(pes >= 4, "o cemitério tem %d pé(s) de capim, e a missão pede quatro" % pes)

	var perto_do_capim: Vector3 = recursos.mais_perto_da_peca("capim", jogador.global_position)
	_conferir(perto_do_capim != Lugares.NENHUM, "não achei pé de capim nenhum no vale")
	if perto_do_capim != Lugares.NENHUM:
		jogador.spawn_position = perto_do_capim
		jogador.reset_position()
		await _frames(3)
		energia.encher()
		# Com o machado na mão e sem foice, o corte TEM DE SER RECUSADO. É o que
		# faz o passo do meio valer.
		inv.adicionar("machado", 1)
		var recusas: Array[String] = []
		var ouvir := func(motivo: String) -> void: recusas.append(motivo)
		recursos.recusado.connect(ouvir)
		var cortou: bool = recursos.bater()
		recursos.recusado.disconnect(ouvir)
		_conferir(not cortou, "o capim caiu sem foice: o passo de encabar a foice virou enfeite")
		_conferir(not recusas.is_empty() and recusas[0].to_lower().contains("foice"),
			"a recusa não disse que falta a foice: disse %s" % str(recusas))

	# --- 3. A CADEIA ABRE SOZINHA AO CHEGAR PERTO DO DAMIÃO ------------------
	jogador.spawn_position = damiao.global_position + Vector3(1.4, 0.0, 1.0)
	jogador.reset_position()
	await _frames(3)
	var abriu := await _ate(func() -> bool: return bool(cadeia.iniciado), SEGUNDOS_PARA_ANUNCIAR)
	_conferir(abriu,
		"cheguei ao lado do Damião e a missão não abriu: ela existe e é inalcançável")
	if not abriu:
		_fechar()
		return
	print("")

	# --- 4. OS TRÊS PASSOS FECHAM --------------------------------------------
	var total: int = cadeia.total()
	var anterior := -1
	var voltas := 0
	while cadeia.missao < total and voltas < total + 3:
		voltas += 1
		var indice: int = cadeia.missao
		if indice == anterior:
			break
		anterior = indice
		var passo: Dictionary = cadeia.passos[indice]
		var id := str(passo.get("id", "?"))
		var meta: Dictionary = passo.get("meta", {})

		energia.encher()
		var anunciou := await _ate(func() -> bool: return cadeia.espera <= 0.0,
			SEGUNDOS_PARA_ANUNCIAR)
		_conferir(anunciou, "o passo '%s' não chegou a anunciar" % id)
		await _frames(2)

		var entrega: Dictionary = passo.get("entrega", {})
		if not entrega.is_empty():
			var ferramenta := str(entrega.get("item", ""))
			# À MÃO, e não na mochila. O vale passou a cobrar a ferramenta
			# ENCAIXADA (`Recursos3D._tem_ferramenta`), e é o encaixe que a
			# entrega do passo preenche; perguntar pela mochila reprovaria
			# justamente a entrega que funciona. Pergunta-se à regra do jogo
			# para a medida não poder divergir dela.
			_conferir(recursos._tem_ferramenta(ferramenta),
				"o passo '%s' cobra trabalho e não deixou %s à mão" % [id, ferramenta])

		match str(meta.get("tipo", "")):
			"juntar":
				await _juntar(recursos, inv, energia, jogador,
					str(meta.get("item", "")), int(meta.get("quantos", 1)), id)
			"derrubar":
				await _derrubar(recursos, energia, jogador,
					str(meta.get("alvo", "")), int(meta.get("quantos", 1)), id)
			_:
				# Passo de visita: chegar ao cemitério, que é onde o jogador já está.
				jogador.spawn_position = cadeia.posicao_do_passo(indice)
				jogador.reset_position()

		var fechou := await _ate(func() -> bool: return cadeia.missao != indice,
			SEGUNDOS_POR_PASSO)
		if not fechou:
			_conferir(false,
				"o passo '%s' (%d de %d) não fechou em %s s. espera=%.2f meta=%s"
					% [id, indice + 1, total, str(SEGUNDOS_POR_PASSO), cadeia.espera, str(meta)])
		print("  %-16s %s" % [id, "fechou" if fechou else "PRESO"])
		if not fechou:
			break

	_conferir(cadeia.missao >= total,
		"a cadeia do coveiro parou no passo %d de %d" % [cadeia.missao + 1, total])

	# --- 5. CORTAR CAPIM NÃO ENCHEU A MOCHILA --------------------------------
	# NENHUM ESPAÇO COM ID VAZIO. Contado à mão, e não por `quantidade("")`: a
	# conta de "" agora é sempre zero por conserto — um espaço livre é `{}` e
	# casava com "" —, e a pergunta antiga passaria a não poder falhar.
	var sem_nome := 0
	for espaco in inv.espacos:
		var caixa: Dictionary = espaco
		if not caixa.is_empty() and str(caixa.get("id", "")) == "":
			sem_nome += 1
	_conferir(sem_nome == 0,
		"cortar capim pôs %d espaço(s) de id vazio na mochila" % sem_nome)
	_conferir(inv.quantidade("capim") == 0,
		"o capim virou item de mochila, e no 2D o mato cortado some")

	# --- 6. A MISSÃO SOBREVIVE A RECARREGAR ----------------------------------
	#
	# Sem isto a cadeia do Damião era missão que esquece a si mesma: o save do
	# vale guardava a fila do Pedro — o único que dava missão até aqui — e mais
	# nada. O jogador cortava os quatro pés, salvava, voltava, e o capim estava
	# de pé com o passo ainda aberto.
	#
	# A volta é conferida EM MEMÓRIA, sem tocar em arquivo: pede o estado ao
	# vale, embaralha o que está vivo, manda restaurar, e vê se voltou. Salvar
	# de verdade é do `tests/salvamento.gd`, que move os saves do jogador para
	# uma reserva antes de mexer neles; repetir aquela dança aqui seria arriscar
	# a partida de quem roda o portão.
	var guardado: Dictionary = jogo.estado_para_salvar()
	_conferir(guardado.has("cadeias") and (guardado["cadeias"] as Dictionary).has("damiao"),
		"o save do vale não leva a fila do Damião: a missão dele se esquece ao recarregar")
	_conferir(guardado.has("caidos") and (guardado["caidos"] as Array).size() >= 4,
		"o save não leva os alvos caídos: o capim cortado renasce e a meta desanda")

	var onde_estava: int = cadeia.missao
	cadeia.missao = 0
	cadeia.iniciado = false
	jogo.restaurar_do_save(guardado)
	await _frames(2)
	_conferir(cadeia.missao == onde_estava,
		"recarregar devolveu a fila do Damião no passo %d, e ela estava no %d"
			% [cadeia.missao, onde_estava])
	_conferir(cadeia.iniciado, "recarregar fechou a fila do Damião de novo")
	_conferir(recursos.derrubados("capim") >= 4,
		"recarregar fez o capim renascer: %d pé(s) contados, e eram quatro"
			% recursos.derrubados("capim"))
	_conferir(recursos.mais_perto_da_peca("capim", jogador.global_position) == Lugares.NENHUM,
		"recarregar pôs pé de capim de volta no cemitério")

	_fechar()


## Bate no que rende `item` até ter `quantos` na mochila.
func _juntar(recursos, inv, energia, jogador, item: String, quantos: int, id: String) -> void:
	var tentativas := 0
	while inv.quantidade(item) < quantos and tentativas < 40:
		tentativas += 1
		var onde: Vector3 = recursos.mais_perto_que_rende(item, jogador.global_position)
		if onde == Lugares.NENHUM:
			break
		jogador.spawn_position = onde
		jogador.reset_position()
		await _frames(2)
		energia.encher()
		if not recursos.bater():
			break
	_conferir(inv.quantidade(item) >= quantos,
		"o passo '%s' pede %d de %s e só juntei %d" % [id, quantos, item, inv.quantidade(item)])


## Derruba `quantos` alvos da peça `peca`.
func _derrubar(recursos, energia, jogador, peca: String, quantos: int, id: String) -> void:
	var tentativas := 0
	while recursos.derrubados(peca) < quantos and tentativas < 40:
		tentativas += 1
		var onde: Vector3 = recursos.mais_perto_da_peca(peca, jogador.global_position)
		if onde == Lugares.NENHUM:
			break
		jogador.spawn_position = onde
		jogador.reset_position()
		await _frames(2)
		energia.encher()
		if not recursos.bater():
			break
	_conferir(recursos.derrubados(peca) >= quantos,
		"o passo '%s' pede %d pé(s) de %s e só derrubei %d"
			% [id, quantos, peca, recursos.derrubados(peca)])


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("COVEIRO_OK: o Damião tem fila própria, ela abre ao chegar perto dele, o capim só cai de foice e a foice vem antes do corte, os três passos fecham, o mato cortado não vira item de mochila, e recarregar devolve a fila no passo certo com o capim ainda cortado")
	else:
		print("coveiro: %d falha(s)" % falhas)
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
