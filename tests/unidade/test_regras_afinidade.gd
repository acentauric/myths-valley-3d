extends "res://tests/unidade/base.gd"
## Portado do 2D, SHA 62c0f14b, tools/gdscript/testar_afinidade.gd (#18).
## Confere a AFINIDADE com os moradores.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste regras_afinidade
##
## O que este teste pega são quatro coisas que não dão erro nenhum:
##
##   1. MORADOR SEM GOSTO. Quem não tiver `gosta` e `desgosta` no JSON aceita
##      tudo igual, e presentear vira apertar E com qualquer coisa. A escolha
##      morre e o sistema inteiro fica sem sal — sem uma linha de log.
##
##   2. GOSTO DE ITEM QUE NÃO EXISTE. Um erro de digitação em "farinha" e o
##      morador nunca gosta de nada: `juizo` devolve "qualquer" para sempre e
##      ninguém percebe, porque "qualquer" é uma resposta válida.
##
##   3. ITEM QUE NÃO SE DÁ. Gosto que aponte para ferramenta ou documento é
##      promessa que o jogo não deixa cumprir — o E nem oferece.
##
##   4. FALA QUE NÃO ABRE. Assunto com `quando: afinidade_4` num morador cujo
##      teto de pontos não chega ao grau 4 é fala escrita que ninguém lê.
##
## E faz a volta inteira: conversa, presenteia bem, presenteia mal, confere o
## teto diário, e confere que o grau sobe e que o sinal sai.

func test_regras_afinidade() -> void:
	var afinidade := root.get_node("/root/Afinidade")
	var relogio := root.get_node("/root/Relogio")
	var inventario := root.get_node("/root/Inventario")
	var jogo := root.get_node("/root/Jogo")

	var dados: Dictionary = jogo.dados(afinidade.ARQUIVO_DOS_MORADORES).duplicate(true)
	if "--falsificar-gosto" in OS.get_cmdline_user_args():
		dados[str(afinidade.MORADORES[0])]["gosta"] = ["item_inexistente_18", "item_inexistente_18"]
	conferir(not dados.is_empty(), "Não consegui ler o arquivo dos moradores")
	conferir(afinidade.MORADORES.size() >= 5,
		"O arraial tem %d moradores na lista de afinidade" % afinidade.MORADORES.size())

	# --- 1 a 3: o gosto de cada um -------------------------------------------
	var controlador = load("res://scripts/prototipo_3d/tecla_dos_moradores.gd").new()
	for id in afinidade.MORADORES:
		var dele: Dictionary = dados.get(str(id), {})
		conferir(not dele.is_empty(), "O morador '%s' não está no aldeoes.json" % id)
		var gosta: Array = dele.get("gosta", [])
		var desgosta: Array = dele.get("desgosta", [])
		conferir(gosta.size() >= 2,
			"'%s' gosta de %d coisa(s): com menos de duas, presentear vira sorte" % [id, gosta.size()])
		conferir(desgosta.size() >= 1,
			"'%s' não desgosta de nada: sem o que dá errado, a escolha do presente não é escolha" % id)

		for item in gosta + desgosta:
			conferir(Catalogo.existe(str(item)),
				"'%s' tem gosto por '%s', que não existe no catálogo — juizo devolve 'qualquer' para sempre"
					% [id, item])
			if not Catalogo.existe(str(item)):
				continue
			conferir(controlador._item_de_presente(str(item)),
				"'%s' gosta de '%s', que é %s e não se dá de presente: promessa que o E não cumpre"
					% [id, item, Catalogo.tipo(str(item))])
		for item in gosta:
			conferir(not desgosta.has(item), "'%s' gosta e desgosta de '%s' ao mesmo tempo" % [id, item])

		# As falas de reação. Sem elas o presente sai com a resposta genérica,
		# que funciona e é morna — e morno em cinco moradores é o arraial
		# inteiro sem voz.
		for chave in ["gostou", "nao_gostou", "agradeceu", "ja_ganhou"]:
			conferir(not (dele.get(str(chave), []) as Array).is_empty(),
				"'%s' está sem a fala '%s'" % [id, chave])

	controlador.free()

	# --- 4: fala de afinidade que dá para alcançar ----------------------------
	var teto_de_grau: int = afinidade.GRAUS.size() - 1
	for id in dados:
		if str(id) == "observacao":
			continue
		for assunto in (dados[id] as Dictionary).get("assuntos", []):
			var quando := str((assunto as Dictionary).get("quando", ""))
			if not quando.begins_with("afinidade_"):
				continue
			var pedido := int(quando.trim_prefix("afinidade_"))
			conferir(pedido >= 1 and pedido <= teto_de_grau,
				"'%s' tem assunto exigindo grau %d, e o maior grau que existe é %d: fala que ninguém lê"
					% [id, pedido, teto_de_grau])

	# --- a volta inteira ------------------------------------------------------
	var quem := str(afinidade.MORADORES[0])
	var dele: Dictionary = dados.get(quem, {})
	var bom := str((dele.get("gosta", []) as Array)[0])
	var ruim := str((dele.get("desgosta", []) as Array)[0])

	afinidade.pontos.clear()
	conferir(afinidade.de(quem) == 0, "Afinidade não começa em zero")
	conferir(afinidade.grau(quem) == 0, "Grau não começa em zero")

	# Conversa: uma vez por dia, e a segunda não vale.
	var subiu: int = afinidade.conversou(quem)
	conferir(subiu == afinidade.POR_CONVERSA,
		"Conversar deu %d de afinidade, esperava %d" % [subiu, afinidade.POR_CONVERSA])
	conferir(afinidade.conversou(quem) == 0,
		"Conversar duas vezes no mesmo dia contou duas vezes: a relação vira moagem")

	# Presente bom.
	inventario.adicionar(bom, 3)
	var antes: int = afinidade.de(quem)
	conferir(afinidade.juizo(quem, bom) == "bom", "'%s' devia ser do gosto de %s" % [bom, quem])
	conferir(afinidade.presentear(quem, bom) == afinidade.POR_PRESENTE_BOM,
		"O presente que ele gosta não deu %d" % afinidade.POR_PRESENTE_BOM)
	conferir(afinidade.de(quem) > antes, "Presentear não somou nada")
	conferir(inventario.quantidade(bom) == 2, "Presentear não consumiu o item da mochila")
	# E não dá para dar duas vezes no mesmo dia.
	conferir(afinidade.presentear(quem, bom) == 0, "Dois presentes no mesmo dia contaram os dois")
	conferir(inventario.quantidade(bom) == 2,
		"O segundo presente do dia foi recusado e MESMO ASSIM consumiu o item")

	# Presente ruim, no dia seguinte: TIRA ponto.
	relogio.dormir()
	inventario.adicionar(ruim, 1)
	var antes_do_ruim: int = afinidade.de(quem)
	conferir(afinidade.juizo(quem, ruim) == "ruim", "'%s' devia desagradar %s" % [ruim, quem])
	afinidade.presentear(quem, ruim)
	conferir(afinidade.de(quem) < antes_do_ruim,
		"Dar o que a pessoa não gosta não tirou ponto: sem isso o presente não é escolha")

	# Subir de grau solta o sinal, que é o que o jogador vê.
	var avisos: Array = []
	afinidade.subiu_de_grau.connect(func(m, g): avisos.append([m, g]))
	afinidade.somar(quem, 200)
	conferir(afinidade.de(quem) == afinidade.MAXIMO,
		"A afinidade passou do teto: %d" % afinidade.de(quem))
	conferir(afinidade.grau(quem) == teto_de_grau,
		"Com o teto de pontos o grau devia ser %d e é %d" % [teto_de_grau, afinidade.grau(quem)])
	conferir(not avisos.is_empty(), "Subir de grau não emitiu o sinal: o jogador não fica sabendo")
	conferir(afinidade.falta_para_o_proximo(quem) == -1,
		"No último grau ainda falta alguma coisa para o próximo")

	# O piso: não fica negativo.
	afinidade.somar(quem, -9999)
	conferir(afinidade.de(quem) == afinidade.MINIMO,
		"A afinidade furou o piso: %d" % afinidade.de(quem))

	# --- o save leva a afinidade junto ----------------------------------------
	afinidade.somar(quem, 42)
	var guardado: Dictionary = afinidade.estado()
	afinidade.pontos.clear()
	conferir(afinidade.de(quem) == 0, "Limpar não limpou")
	afinidade.restaurar(guardado)
	conferir(afinidade.de(quem) == 42,
		"A afinidade não voltou do estado guardado: %d" % afinidade.de(quem))

