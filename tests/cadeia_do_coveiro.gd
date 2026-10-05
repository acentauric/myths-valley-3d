extends SceneTree
## JOGA A MISSÃO DO CEMITÉRIO DO COMEÇO AO FIM — a primeira do vale que não é do Pedro.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/cadeia_do_coveiro.gd
##
## O intendente nomeou o Damião zelador do cemitério e lhe deu um papel com o
## nome dele. Nada além disso — nem foice, nem tostão. A missão é ele pedindo
## ao jogador o que o cargo não veio com, e ela veio do `data/dialogos/
## arraial.json` do jogo 2D (passos coveiro_ver / coveiro_foice / coveiro_limpar).
## No vale ela cresceu, a pedido de quem jogou: mais capim, o mato que levanta
## laje, o conserto das lajes com tábua e pedra, e o cercado, que é obra.
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
##   5. QUE HAJA TRABALHO DE LIMPAR: oito pés de capim, e o mato — embaúba nova
##      e tronco caído — contado PELO GRUPO, porque o Damião pede o mato e não a
##      peça. Sem o grupo, a meta contava zero e o passo nunca fechava.
##
##   6. QUE A CAPELINHA DÊ AS COSTAS PARA O MAR, e que se reze DIANTE DA PORTA
##      DELA, de frente para a baía — e não no meio das covas. O lado do mar é
##      medido aqui de outro jeito que o do vale (varrendo a terra até a água),
##      para a pergunta não ser a resposta. Dali, o E é o da reza: nem lápide
##      nem alvo de trabalho ao alcance.
##
##   7. QUE AS LAJES TORTAS ENDIREITEM COM O CONSERTO, e só com ele — e que
##      voltar a uma partida de antes as entorte de novo.
##
##   8. QUE O CERCADO SEJA OBRA DE VERDADE: o plano se aprende com o passo, a
##      aba aparece no cemitério, de pé ele segura o corpo, deixa a entrada
##      livre onde a rua do cemitério chega, e a malha dos moradores se assa
##      de novo e passa por ela.
##
##   9. QUE A CONTA DO MATERIAL FECHE: a lenha e a pedra que o próprio
##      cemitério dá cobrem o conserto e o cercado, pelas receitas da oficina.
##      O vale tem pouca lenha fora dali, e missão que pede o que não existe é
##      missão que trava sem aviso.
##
##  10. QUE O MATO SEJA O TRONCO CAÍDO E A CAPELINHA SEJA POBRE: no lugar da lenha
##      empilhada, os três troncos caídos, que saem no machado e rendem lenha
##      (no estilo Tripo, o modelo do catálogo); e a capelinha de taipa do
##      catálogo no lugar da capela colonial reduzida.
##
## A espera é em SEGUNDO REAL, e não em quadro, pela razão escrita no
## `cadeia_das_missoes.gd`: o cadeado da fala do jogo é de relógio de parede, e
## em headless os quadros voam.

var falhas := 0
const SEGUNDOS_POR_PASSO := 15.0
const SEGUNDOS_PARA_ANUNCIAR := 12.0
## A malha nova dos moradores, depois do cercado: assar leva uns dois segundos.
const SEGUNDOS_PARA_A_MALHA := 25.0
const PASSOS := 6
const CAPINS := 8
const MATO := 7
const GRUPO_DO_MATO := "mato_do_cemiterio"


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
	var obras := root.get_node("/root/Obras")
	var mundo = jogo.get("world")
	var cemiterio = jogo.get("cemiterio")
	_conferir(jogador != null and recursos != null, "não achei o jogador ou os recursos")
	_conferir(cemiterio != null, "o vale não tem o cemiterio_vale: as lajes e o cercado não têm quem os mude")
	if jogador == null or recursos == null or cemiterio == null:
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
	_conferir(cadeia.total() == PASSOS,
		"a cadeia do coveiro tem %d passo(s), e são seis: ver, encabar, limpar, o mato, o conserto e o cercado" % cadeia.total())
	_conferir(cadeia.recursos != null,
		"a cadeia do coveiro não recebeu os alvos: o marcador vai apontar o cemitério, e não o capim")

	# --- 2. O CAPIM ESTÁ NO CEMITÉRIO, E SÓ SAI DE FOICE ---------------------
	var pes: int = recursos.derrubados("capim") + recursos._de_pe("capim")
	_conferir(pes >= CAPINS, "o cemitério tem %d pé(s) de capim, e a missão pede oito" % pes)
	# E O MATO, PELO GRUPO: embaúba e tronco caído são peças diferentes, e o pedido é um.
	var mato: int = recursos.derrubados(GRUPO_DO_MATO) + recursos._de_pe(GRUPO_DO_MATO)
	_conferir(mato >= MATO, "o grupo '%s' tem %d alvo(s), e o passo do mato pede sete" % [GRUPO_DO_MATO, mato])
	_conferir(recursos.mais_perto_da_peca(GRUPO_DO_MATO, jogador.global_position) != Lugares.NENHUM,
		"o marcador não acha o mato pelo grupo: o passo apontaria para o nada")
	# O TRONCO CAÍDO NO LUGAR DA LENHA EMPILHADA ("Substitua as madeiras empilhadas
	# na missão do cemitério por esse tronco caído"): o mato que não é embaúba é
	# tronco caído, que sai no machado e rende lenha — e, no estilo Tripo, é o
	# modelo dele, e não a pilha.
	var tripo: bool = root.get_node("/root/Estilo").tripo()
	var troncos := 0
	for id in recursos._alvos:
		var ficha: Dictionary = recursos._alvos[id]["ficha"]
		if str(ficha.get("grupo", "")) != GRUPO_DO_MATO or str(ficha.get("peca", "")) == "embauba":
			continue
		troncos += 1
		_conferir(str(ficha.get("peca", "")) == "tronco_caido" and str(ficha.get("ferramenta", "")) == "machado" and str(ficha.get("rende", "")) == "lenha",
			"o mato do cemitério ainda tem '%s' em %s, e não o tronco caído no machado" % [str(ficha.get("peca", "")), str(id)])
		var no = recursos._alvos[id]["no"]
		if tripo:
			_conferir(no != null and str(no.scene_file_path).ends_with("tronco_caido_tripo.glb"),
				"no estilo Tripo, %s não é o tronco caído do catálogo (%s)" % [str(id), str(no.scene_file_path) if no != null else "nada"])
	_conferir(troncos == 3, "o mato do cemitério tem %d tronco(s) caído(s), e são três" % troncos)

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

	# --- 3. A CAPELINHA DE COSTAS PARA O MAR, E A REZA DIANTE DELA -----------
	await _conferir_a_capelinha(jogo, mundo, jogador, recursos)

	# --- 4. A CONTA DO MATERIAL FECHA ----------------------------------------
	_conferir_a_conta(cadeia, obras)

	# --- 5. AS LAJES COMEÇAM TORTAS ------------------------------------------
	var tortas: Array = cemiterio.lajes_tortas()
	_conferir(tortas.size() == 3, "as lajes que a raiz levantou são três, e há %d torta(s)" % tortas.size())
	for indice in tortas:
		var tumulo: Node3D = mundo.tumulos[indice]
		_conferir(is_instance_valid(tumulo) and _inclinacao(tumulo) > 0.15,
			"a laje %d está na lista das tortas e o desenho dela está reto" % indice)

	# --- 6. A CADEIA ABRE NO E, AO LADO DO DAMIÃO -----------------------------
	jogador.spawn_position = damiao.global_position + Vector3(1.4, 0.0, 1.0)
	jogador.reset_position()
	await _frames(3)
	# A FILA ESPERA A CHEGADA DO PEDRO (docs/mundo/CHEGADA_E_MUTIROES.md, regra 7):
	# ao lado do morador, com a chegada em curso, ela não abre; acabada, abre.
	var guia = current_scene.get("pedro")
	await _ate(func() -> bool: return false, 1.5)
	_conferir(not cadeia.iniciado, "ao lado do Damião, a fila dele abriu sozinha, sem o E")
	await _falar_com(damiao)
	_conferir(not cadeia.iniciado, "a fila do Damião abriu com a chegada do Pedro em curso")
	if guia != null:
		guia.missao = guia.MISSOES.size()
		guia.set("_despedida_feita", true)
	await _falar_com(damiao)
	var abriu := await _ate(func() -> bool: return bool(cadeia.iniciado), SEGUNDOS_PARA_ANUNCIAR)
	_conferir(abriu,
		"cheguei ao lado do Damião e a missão não abriu: ela existe e é inalcançável")
	if not abriu:
		_fechar()
		return
	print("")

	# --- 7. OS SEIS PASSOS FECHAM --------------------------------------------
	var Bancadas = load("res://scripts/prototipo_3d/bancadas_vale.gd")
	var receitas := root.get_node("/root/Receitas")
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
			# A entrega vai para a barra; o jogador escolhe o número da ferramenta.
			for espaco in inv.ESPACOS_MAO:
				if str(inv.espacos[espaco].get("id", "")) == ferramenta:
					inv.selecionar(espaco)
					break
			_conferir(recursos._tem_ferramenta(ferramenta),
				"o passo '%s' cobra trabalho e não deixou %s à mão" % [id, ferramenta])

		match str(meta.get("tipo", "")):
			"juntar":
				await _juntar(recursos, inv, energia, jogador,
					str(meta.get("item", "")), int(meta.get("quantos", 1)), id)
			"derrubar":
				await _derrubar(recursos, energia, jogador,
					str(meta.get("alvo", "")), int(meta.get("quantos", 1)), id)
			"levar":
				# O CONSERTO: antes dele as lajes estão tortas; com a pedra e a
				# tábua na mochila, o E ao lado do Damião entrega.
				_conferir(cemiterio.lajes_tortas().size() == 3,
					"no passo do conserto as lajes já estavam retas: endireitaram antes da pedra e da tábua")
				var itens: Dictionary = meta.get("itens", {})
				for item in itens:
					inv.adicionar(str(item), int(itens[item]))
				jogador.spawn_position = damiao.global_position + Vector3(1.2, 0.0, 0.8)
				jogador.reset_position()
				await _frames(2)
				await _falar_com(damiao)
			"obra":
				# O CERCADO É OBRA DO J: o plano veio com o passo, a aba aparece
				# no cemitério, e sem o material ela diz o que falta.
				var construcao := str(meta.get("construcao", ""))
				var obra := str(meta.get("obra", ""))
				_conferir(receitas.sabe(obra), "o passo '%s' abriu e o plano '%s' não veio com ele" % [id, obra])
				_conferir(Bancadas.obra_perto(mundo, jogador.global_position) == construcao,
					"no cemitério a aba de obras é '%s', e devia ser '%s'" % [Bancadas.obra_perto(mundo, jogador.global_position), construcao])
				_conferir(obras.disponiveis(construcao).has(obra), "a obra '%s' não está na lista do cemitério: %s" % [obra, str(obras.disponiveis(construcao))])
				_conferir(obras.impedimento(construcao, obra).begins_with("Falta"),
					"sem material, o cercado não diz o que falta: '%s'" % obras.impedimento(construcao, obra))
				_conferir(not cemiterio.cercado_de_pe(), "o cercado subiu antes da obra")
				var custo: Dictionary = obras.custo(obra)
				for item in custo:
					inv.adicionar(str(item), int(custo[item]))
				_conferir(obras.executar(construcao, obra), "com o material na mochila, a obra '%s' não saiu: %s" % [obra, obras.impedimento(construcao, obra)])
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
		if id == "coveiro_reparo" and fechou:
			# O CONSERTO ENDIREITA AS LAJES — na hora, e não no anúncio seguinte.
			var retas := await _ate(func() -> bool: return cemiterio.lajes_tortas().is_empty(), 1.0)
			_conferir(retas, "o conserto fechou e as lajes continuam tortas")
			for torta in tortas:
				_conferir(_inclinacao(mundo.tumulos[torta]) < 0.01, "a laje %d continuou torta depois do conserto" % torta)
		print("  %-16s %s" % [id, "fechou" if fechou else "PRESO"])
		if not fechou:
			break

	_conferir(cadeia.missao >= total,
		"a cadeia do coveiro parou no passo %d de %d" % [cadeia.missao + 1, total])

	# --- 8. O CERCADO DE PÉ ---------------------------------------------------
	await _ate(func() -> bool: return cemiterio.cercado_de_pe(), 1.0)
	await _conferir_o_cercado(jogo, mundo, cemiterio)

	# --- 9. CORTAR CAPIM NÃO ENCHEU A MOCHILA --------------------------------
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

	# --- 10. A MISSÃO SOBREVIVE A RECARREGAR ---------------------------------
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
	_conferir(guardado.has("caidos") and (guardado["caidos"] as Array).size() >= CAPINS + MATO,
		"o save não leva os alvos caídos: o capim e o mato cortados renascem e a meta desanda")

	var onde_estava: int = cadeia.missao
	# UMA PARTIDA DE ANTES DO CONSERTO E DO CERCADO: as lajes voltam a entortar e
	# o cercado desce — o outeiro segue o jogo para os dois lados.
	cadeia.missao = 4
	var feitas_antes: Array = (obras.feitas.get("cemiterio", []) as Array).duplicate()
	obras.feitas["cemiterio"] = []
	cemiterio.acertar()
	_conferir(cemiterio.lajes_tortas().size() == 3, "de volta a antes do conserto, as lajes não entortaram de novo")
	_conferir(not cemiterio.cercado_de_pe() and cemiterio.lances().is_empty(),
		"de volta a antes da obra, o cercado continuou de pé")
	obras.feitas["cemiterio"] = feitas_antes
	cadeia.missao = 0
	cadeia.iniciado = false
	jogo.restaurar_do_save(guardado)
	await _frames(2)
	_conferir(cadeia.missao == onde_estava,
		"recarregar devolveu a fila do Damião no passo %d, e ela estava no %d"
			% [cadeia.missao, onde_estava])
	_conferir(cadeia.iniciado, "recarregar fechou a fila do Damião de novo")
	_conferir(recursos.derrubados("capim") >= CAPINS,
		"recarregar fez o capim renascer: %d pé(s) contados, e eram oito"
			% recursos.derrubados("capim"))
	_conferir(recursos.derrubados(GRUPO_DO_MATO) >= MATO,
		"recarregar fez o mato renascer: %d contado(s), e eram sete" % recursos.derrubados(GRUPO_DO_MATO))
	_conferir(recursos.mais_perto_da_peca("capim", jogador.global_position) == Lugares.NENHUM,
		"recarregar pôs pé de capim de volta no cemitério")
	_conferir(cemiterio.lajes_tortas().is_empty(), "recarregar a partida do fim entortou as lajes")
	_conferir(cemiterio.cercado_de_pe(), "recarregar a partida do fim derrubou o cercado")

	_fechar()


## A CAPELINHA: de costas para o mar, a reza diante da porta, e o E de lá é o dela.
func _conferir_a_capelinha(jogo, mundo, jogador, recursos) -> void:
	var ancoras: Dictionary = mundo.ancoras
	for nome in ["Capelinha", "CapelinhaFrente", "CapelinhaPorta"]:
		_conferir(ancoras.has(nome), "o vale não tem a âncora '%s': a capelinha do cemitério não foi posta" % nome)
	if not ancoras.has("CapelinhaFrente") or not ancoras.has("CapelinhaPorta"):
		return
	var centro: Vector3 = ancoras["Cemitério"]
	# O MAR, MEDIDO DE OUTRO JEITO: andando da cova para fora em 72 rumos até a
	# terra acabar. O vale usa a linha da costa; se os dois discordam, um mente.
	var mar := Vector3.ZERO
	var mais_perto := INF
	for k in 72:
		var rumo := Vector3(cos(TAU * k / 72.0), 0.0, sin(TAU * k / 72.0))
		for passo in range(2, 260, 2):
			if not mundo.is_on_land(centro + rumo * float(passo)):
				if float(passo) < mais_perto:
					mais_perto = float(passo)
					mar = rumo
				break
	_conferir(mar != Vector3.ZERO, "não achei o mar a partir do cemitério")
	# A CAPELINHA POBRE ("deve ser mais rudimentar, com um aspecto pobre"): no
	# estilo Tripo, é a de taipa do catálogo, e não a capela colonial reduzida.
	if root.get_node("/root/Estilo").tripo():
		var construida: Dictionary = mundo.construcoes.get("Capelinha", {})
		var modelo = construida.get("modelo", null)
		_conferir(modelo != null and str(modelo.scene_file_path).ends_with("capelinha_tripo.glb"),
			"a capelinha do cemitério não é a capelinha pobre do catálogo (%s)" % (str(modelo.scene_file_path) if modelo != null else "nada"))
	var frente: Vector3 = ancoras["CapelinhaFrente"]
	_conferir(frente.dot(mar) < -0.7,
		"a capelinha não dá as costas para o mar: a porta olha %s e o mar está em %s" % [str(frente), str(mar.snapped(Vector3.ONE * 0.01))])
	var porta: Vector3 = ancoras["CapelinhaPorta"]
	var marcos = jogo.get("marcos")
	var reza: Vector3 = marcos.ponto("cemiterio") if marcos != null else Vector3.INF
	_conferir(reza.is_finite(), "o cemitério não tem marco de reza")
	if not reza.is_finite():
		return
	var diante := (reza - porta).dot(frente)
	_conferir(diante > 1.0 and diante < 3.0 and Vector2(reza.x - porta.x, reza.z - porta.z).length() < 3.0,
		"a reza do cemitério não é diante da porta da capelinha: %.2f à frente dela" % diante)
	_conferir((porta - reza).dot(mar) > 0.0, "quem reza não está de frente para o mar, com a capelinha entre ele e a baía")
	_conferir(mundo.is_on_land(reza), "o lugar da reza não está em terra firme")
	# DALI, O E É O DA REZA: nenhuma lápide nem alvo de trabalho ao alcance.
	jogador.spawn_position = reza
	jogador.reset_position()
	await _frames(3)
	_conferir(recursos._mais_perto() == "", "no lugar da reza o E oferece o alvo '%s'" % recursos._mais_perto())
	var lapides = jogo.get("lapides")
	if lapides != null:
		_conferir(lapides._mais_proxima() < 0, "no lugar da reza o E oferece a lápide %d" % lapides._mais_proxima())
	_conferir(marcos._mais_perto(jogador.global_position) == "cemiterio",
		"no lugar da reza a tecla não é a do marco do cemitério: '%s'" % marcos._mais_perto(jogador.global_position))


## A CONTA DO MATERIAL, pelas receitas da oficina: o que o conserto e o cercado
## gastam cabe no que o cemitério dá.
func _conferir_a_conta(cadeia, obras) -> void:
	var oficina: Dictionary = load("res://scripts/compartilhado/oficina.gd").RECEITAS
	var lenha_da_tabua := int((oficina["tabua"]["custo"] as Dictionary).get("lenha", 0))
	var lenha_da_corda := int((oficina["corda"]["custo"] as Dictionary).get("lenha", 0))
	var pede_lenha := 0
	var pede_pedra := 0
	for passo in cadeia.passos:
		var meta: Dictionary = passo.get("meta", {})
		if str(meta.get("tipo", "")) == "levar":
			var itens: Dictionary = meta.get("itens", {})
			pede_lenha += int(itens.get("tabua", 0)) * lenha_da_tabua + int(itens.get("corda", 0)) * lenha_da_corda + int(itens.get("lenha", 0))
			pede_pedra += int(itens.get("pedra", 0))
		elif str(meta.get("tipo", "")) == "obra":
			var custo: Dictionary = obras.custo(str(meta.get("obra", "")))
			pede_lenha += int(custo.get("tabua", 0)) * lenha_da_tabua + int(custo.get("corda", 0)) * lenha_da_corda + int(custo.get("lenha", 0))
			pede_pedra += int(custo.get("pedra", 0))
	var dados = JSON.parse_string(FileAccess.get_file_as_string("res://data/recursos_3d.json"))
	var da_lenha := 0
	var da_pedra := 0
	for ficha in dados.get("recursos", []):
		if str(ficha.get("lugar", "")) != "cemiterio":
			continue
		match str(ficha.get("rende", "")):
			"lenha": da_lenha += int(ficha.get("quantidade", 0))
			"pedra": da_pedra += int(ficha.get("quantidade", 0))
	print("  conta: o cemitério dá %d de lenha e %d de pedra; o conserto e o cercado gastam %d e %d" % [da_lenha, da_pedra, pede_lenha, pede_pedra])
	_conferir(pede_lenha > 0 and da_lenha >= pede_lenha,
		"o conserto e o cercado gastam %d de lenha e o cemitério só dá %d" % [pede_lenha, da_lenha])
	_conferir(pede_pedra > 0 and da_pedra >= pede_pedra,
		"o conserto gasta %d pedra(s) e o cemitério só dá %d" % [pede_pedra, da_pedra])


## O CERCADO: fecha o quadrado em volta das covas, segura o corpo, deixa a
## entrada livre onde a rua chega, e a malha dos moradores passa por ela.
func _conferir_o_cercado(jogo, mundo, cemiterio) -> void:
	_conferir(cemiterio.cercado_de_pe(), "a obra foi feita e o cercado não subiu")
	var lances: Array = cemiterio.lances()
	_conferir(lances.size() >= 20, "o cercado tem %d lance(s): não fecha o cemitério" % lances.size())
	var entrada: Dictionary = cemiterio.entrada()
	_conferir(not entrada.is_empty(), "o cercado não tem entrada")
	if lances.is_empty() or entrada.is_empty():
		return
	var centro: Vector3 = mundo.ancoras["Cemitério"]
	var meio: float = cemiterio.MEIO_LADO
	# A ENTRADA É ONDE A RUA DO CEMITÉRIO CHEGA: o ponto da rua mais perto das covas
	# fica do lado de dentro, a menos de três passos da entrada.
	var c2 := Vector2(centro.x, centro.z)
	var ponta := Vector2.INF
	var menor := INF
	for rua in mundo._region._roads:
		var pontos: PackedVector2Array = rua.get("points", PackedVector2Array())
		for p in pontos:
			if p.distance_to(c2) < menor:
				menor = p.distance_to(c2)
				ponta = p
	var porteira: Vector3 = entrada["centro"]
	if ponta.is_finite() and menor < meio:
		_conferir(ponta.distance_to(Vector2(porteira.x, porteira.z)) < 5.0,
			"a entrada do cercado fica a %.1f da ponta da rua do cemitério" % ponta.distance_to(Vector2(porteira.x, porteira.z)))
	# SEGURA O CORPO no meio de um lance, e deixa passar na entrada.
	var espaco: PhysicsDirectSpaceState3D = current_scene.get_world_3d().direct_space_state
	await physics_frame
	await physics_frame
	var lance: Dictionary = lances[int(lances.size() / 3.0)]
	var no_lance: Vector3 = (lance["a"] as Vector3).lerp(lance["b"], 0.5)
	_conferir(_bate(espaco, no_lance + Vector3.UP * 0.6), "no meio de um lance do cercado o corpo passa: a cerca não tem colisão")
	_conferir(not _bate(espaco, porteira + Vector3.UP * 0.6), "na entrada do cercado o corpo bate em alguma coisa")
	# A MALHA DOS MORADORES SE ASSA DE NOVO, e o caminho de dentro para fora passa
	# pela entrada — e só por ela.
	var navegacao = jogo.get("navegacao")
	_conferir(navegacao != null, "o vale não tem a malha de navegação")
	if navegacao == null:
		return
	var nova := await _ate(func() -> bool: return int(navegacao.versao) >= 2 and navegacao.esta_pronta(), SEGUNDOS_PARA_A_MALHA)
	_conferir(nova, "o cercado subiu e a malha dos moradores não se assou de novo (versão %d)" % int(navegacao.versao))
	var dentro: Vector3 = mundo.ground_position(centro + Vector3(-4.0, 0.0, 6.0))
	var fora: Vector3 = mundo.ground_position(Vector3(porteira.x, 0.0, porteira.z) + (Vector3(porteira.x, 0.0, porteira.z) - Vector3(centro.x, 0.0, centro.z)).normalized() * 6.0)
	var caminho: PackedVector3Array = navegacao.caminho(dentro, fora)
	_conferir(caminho.size() >= 2 and caminho[-1].distance_to(fora) < 1.5,
		"não há caminho de dentro do cercado para fora (%d ponto[s])" % caminho.size())
	var cruzamentos := _cruzamentos(caminho, centro, meio)
	_conferir(not cruzamentos.is_empty(), "o caminho de dentro para fora não cruza a linha da cerca")
	var ao_longo: Vector3 = entrada["ao_longo"]
	for ponto in cruzamentos:
		var desvio := absf((ponto - porteira).dot(ao_longo))
		_conferir(desvio <= float(entrada["largura"]) * 0.5 + 0.2,
			"o caminho dos moradores atravessa a cerca a %.2f do meio da entrada, fora dela" % desvio)
	print("  cercado: %d lances, entrada em %s, caminho de %d pontos cruzando em %s" % [lances.size(),
		str((porteira - centro).snapped(Vector3.ONE * 0.1)), caminho.size(), str(cruzamentos.map(func(p): return (p - centro).snapped(Vector3.ONE * 0.1)))])


## Onde o caminho cruza a linha da cerca — o quadrado de meio-lado `meio` em
## volta de `centro`.
static func _cruzamentos(caminho: PackedVector3Array, centro: Vector3, meio: float) -> Array:
	var achados: Array = []
	for i in caminho.size() - 1:
		var a := caminho[i] - centro
		var b := caminho[i + 1] - centro
		for lado in [meio, -meio]:
			if (a.x - lado) * (b.x - lado) < 0.0:
				var t: float = (lado - a.x) / (b.x - a.x)
				var z: float = a.z + (b.z - a.z) * t
				if absf(z) <= meio:
					achados.append(centro + Vector3(lado, a.y + (b.y - a.y) * t, z))
			if (a.z - lado) * (b.z - lado) < 0.0:
				var t2: float = (lado - a.z) / (b.z - a.z)
				var x: float = a.x + (b.x - a.x) * t2
				if absf(x) <= meio:
					achados.append(centro + Vector3(x, a.y + (b.y - a.y) * t2, lado))
	return achados


## Uma esfera de corpo em `ponto` encosta em algum corpo sólido?
static func _bate(espaco: PhysicsDirectSpaceState3D, ponto: Vector3) -> bool:
	var pergunta := PhysicsShapeQueryParameters3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 0.25
	pergunta.shape = esfera
	pergunta.transform = Transform3D(Basis(), ponto)
	pergunta.collision_mask = 1
	return not espaco.intersect_shape(pergunta, 4).is_empty()


## O quanto o túmulo está fora do prumo (o eixo de cima dele contra o do mundo).
static func _inclinacao(tumulo: Node3D) -> float:
	if not is_instance_valid(tumulo):
		return 0.0
	return tumulo.global_basis.y.normalized().angle_to(Vector3.UP)


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
		await _ate(func() -> bool: return recursos._golpe_pendente.is_empty() and not recursos._golpe_animando, 2.0)
	_conferir(inv.quantidade(item) >= quantos,
		"o passo '%s' pede %d de %s e só juntei %d" % [id, quantos, item, inv.quantidade(item)])


## Derruba `quantos` alvos da peça (ou do grupo) `peca`.
func _derrubar(recursos, energia, jogador, peca: String, quantos: int, id: String) -> void:
	var tentativas := 0
	while recursos.derrubados(peca) < quantos and tentativas < 60:
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
		await _ate(func() -> bool: return recursos._golpe_pendente.is_empty() and not recursos._golpe_animando, 2.0)
	_conferir(recursos.derrubados(peca) >= quantos,
		"o passo '%s' pede %d de %s e só derrubei %d"
			% [id, quantos, peca, recursos.derrubados(peca)])


## O E AO LADO DE QUEM SE FALA, pelo caminho do jogo (`tecla_dos_moradores.gd`):
## conversar, abrir a fila do morador, cumprir o passo que manda a ele.
func _falar_com(morador) -> void:
	current_scene.get("tecla_dos_moradores").usar(morador)
	await process_frame


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("COVEIRO_OK: o Damião tem fila própria, ela abre no E, ao lado dele, o capim só cai de foice e a foice vem antes do corte, o mato conta pelo grupo e é tronco caído, a capelinha é a pobre, dá as costas para o mar e se reza diante dela, as lajes endireitam com o conserto, o cercado é obra com entrada onde a rua chega e a malha passa por ela, a conta do material fecha, os seis passos fecham, o mato cortado não vira item de mochila, e recarregar devolve a fila no passo certo com o capim cortado e o outeiro como estava")
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
