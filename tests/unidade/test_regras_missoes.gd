extends "res://tests/unidade/base.gd"
## Foco/heranca puros do 2D, SHA 62c0f14b (#18).
## Tutorial, portas e orientacoes ficam nos gates das cadeias 3D.
## Confere A MISSÃO EM FOCO e O RITMO COM QUE AS MISSÕES ABREM.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste regras_missoes
##
## Duas queixas do jogador, e as duas são sobre a mesma coisa: o jogo decidindo
## por ele o que ele deve estar olhando.
##
##   "Quando o jogador termina um conjunto de tasks de uma missão, mas a missão
##    ainda não acabou, ela tá sendo trocada na missão fixada e não deveria."
##
## `em_foco` é um ÍNDICE, e índice não sobrevive a mexer na lista. `adicionar`
## já sabia disso e empurrava o foco ao inserir na frente dele; `concluir`
## nunca soube: removia do meio, tudo escorregava um lugar para trás, e o
## índice continuava apontando para o mesmo NÚMERO — que agora era outra
## missão. Fechar um passo do tutorial trocava a missão que o jogador tinha
## fixado.
##
##   "Está começando muitas missões de uma vez só e o jogador pode ficar
##    ansioso para ir até a próxima etapa."
##
## Quatro frentes abriam juntas depois da primeira noite. A da chapada — ver a
## terra do Seu Benedito — foi para depois da primeira colheita.
##
## O PORTÃO DO FOCO É POR ID, e não por índice, porque comparar índices seria
## repetir aqui a conta que está sendo testada: se ela estiver errada nos dois
## lugares, os dois erros se cancelam e o teste aprova. O que interessa é se a
## missão que o jogador escolheu continua sendo a que a HUD mostra.

func test_regras_missoes() -> void:
	var missoes := root.get_node("/root/Missoes")

	# --- 1. FECHAR UMA MISSÃO ANTES DA FIXADA -------------------------------
	#
	# É o caso da queixa: o tutorial fecha um passo (que é o de índice 0) e o
	# jogador tinha fixado uma frente do arraial.
	_montar(missoes, ["passo_do_tutorial", "favor_da_zefa", "divida_do_tonho"])
	missoes.fixar("favor_da_zefa")
	conferir(_fixada(missoes) == "favor_da_zefa", "Não consegui fixar para começar")

	missoes.concluir("passo_do_tutorial")
	if "--falsificar-foco" in OS.get_cmdline_user_args():
		missoes.fixar("divida_do_tonho")
	conferir(_fixada(missoes) == "favor_da_zefa",
		"Fechar uma missão antes da fixada trocou o foco para '%s'" % _fixada(missoes))

	# --- 2. FECHAR UMA MISSÃO DEPOIS DA FIXADA ------------------------------
	#
	# COM QUATRO MISSÕES, e não com as duas que sobraram acima. Com duas, a
	# fixada é a primeira e o índice 0 é a resposta certa por acaso: um
	# deslocamento errado é clampado de volta para 0 e o portão não vê nada.
	# Foi assim que ele passou na falsificação que existia para pegá-lo.
	#
	# Com a fixada no meio da lista, qualquer deslocamento aparece.
	_montar(missoes, ["antes", "meio", "fixada", "depois"])
	missoes.fixar("fixada")
	missoes.concluir("depois")
	conferir(_fixada(missoes) == "fixada",
		"Fechar uma missão depois da fixada trocou o foco para '%s'" % _fixada(missoes))

	# --- 3. FECHAR A PRÓPRIA FIXADA: a próxima herda ------------------------
	#
	# É a outra metade, e consertar só a primeira não bastava. Cada passo do
	# tutorial é uma missão própria: fecha uma, abre a seguinte. Com o foco no
	# passo que fechou, ele caía numa frente lateral qualquer — e um quadro
	# depois o passo novo entrava na frente dela e empurrava o foco mais um.
	_montar(missoes, ["passo_um", "lateral"])
	missoes.fixar("passo_um")
	missoes.concluir("passo_um")
	missoes.adicionar("passo_dois", "O passo seguinte", false, [], "", true)
	conferir(_fixada(missoes) == "passo_dois",
		"O passo seguinte do tutorial não herdou o foco do que fechou: ficou em '%s'"
			% _fixada(missoes))

	# --- 4. ABRIR NA FRENTE DA FIXADA não mexe nela -------------------------
	#
	# Regressão: isto já era certo, e é o tipo de coisa que um conserto na
	# função vizinha desfaz sem querer.
	_montar(missoes, ["lateral_a", "lateral_b"])
	missoes.fixar("lateral_b")
	missoes.adicionar("enredo", "Missão de enredo", false, [], "", true)
	conferir(_fixada(missoes) == "lateral_b",
		"Abrir uma missão de enredo trocou o foco para '%s'" % _fixada(missoes))

	# --- 5. FIXAR À MÃO cancela a herança -----------------------------------
	#
	# Sem isto, a herança fica pendurada: o jogador fecha a missão em foco,
	# escolhe outra à mão, e a PRÓXIMA missão que abrir — daqui a uma hora de
	# jogo — rouba o foco dele sem que nada tenha acontecido.
	_montar(missoes, ["fechada", "escolhida"])
	missoes.fixar("fechada")
	missoes.concluir("fechada")
	missoes.fixar("escolhida")
	missoes.adicionar("bem_depois", "Uma missão qualquer, mais tarde")
	conferir(_fixada(missoes) == "escolhida",
		"Depois de fixar à mão, a missão seguinte roubou o foco: '%s'" % _fixada(missoes))

	# --- 6. RISCAR A CHECKLIST NÃO MEXE NO FOCO -----------------------------
	#
	# A queixa fala em "terminar um conjunto de tasks": marcar item não pode
	# mexer em foco nenhum, nem na missão marcada nem em outra.
	_montar(missoes, ["com_lista", "fixada_de_lado"])
	missoes.pendurar_lista("com_lista", [
		{"id": "a", "texto": "primeiro"}, {"id": "b", "texto": "segundo"}])
	missoes.fixar("fixada_de_lado")
	missoes.marcar("com_lista", "a")
	missoes.marcar("com_lista", "b")
	conferir(_fixada(missoes) == "fixada_de_lado",
		"Riscar a checklist de outra missão trocou o foco para '%s'" % _fixada(missoes))
	conferir(missoes.completa("com_lista"),
		"Marquei os dois itens e a missão não se deu por completa")

	# --- 8. O FOCO NÃO TROCA DE LINHA --------------------------------------
	#
	# "Quando completo uma task de uma linha de missão, está trocando a missão
	# fixada." Entre fechar um passo e abrir o seguinte há uma fala inteira, e
	# nesse tempo o foco caía no vizinho de índice — e qualquer frente que
	# abrisse missão no intervalo o roubava para sempre.
	#
	# Quatro coisas, em ordem: vago é VAGO (a HUD não mostra o vizinho); outra
	# linha não rouba; a mesma linha herda; e linha que não continua devolve o
	# foco à mais importante depois da espera.
	missoes.adicionar("l1_a", "A", false, [], "", false, "l1")
	missoes.adicionar("horta", "Horta", false, [], "", false, "")
	missoes.fixar("l1_a")
	missoes.concluir("l1_a")
	conferir(missoes.atual().is_empty(),
		"Fechou o passo em foco e a HUD já mostra outra missão: é a troca que o jogador viu")
	missoes.adicionar("l2_x", "X", false, [], "", false, "l2")
	conferir(missoes.atual().is_empty(),
		"Uma missão de OUTRA linha roubou o foco vago")
	missoes.adicionar("l1_b", "B", false, [], "", false, "l1")
	conferir(str(missoes.atual().get("id", "")) == "l1_b",
		"O passo seguinte da mesma linha não herdou o foco: o olho do jogador perde a série")

	# E A LINHA QUE ACABA. Sem isto o foco ficaria vago para sempre depois do
	# último passo de uma série.
	missoes.fixar("l1_b")
	missoes.concluir("l1_b")
	conferir(missoes.atual().is_empty(), "O foco não ficou vago ao fechar o último passo")
	# MEIO MINUTO É O TETO, escrito aqui e não lido da constante. A primeira
	# versão recuava `_orfao_desde` em `ESPERA_DA_LINHA`: provava só que a
	# espera é igual a si mesma, e uma espera de um ano passava. A
	# falsificação pegou.
	conferir(missoes.ESPERA_DA_LINHA <= 30000,
		"A espera pela linha é de %d ms: a HUD fica em branco por mais de meio minuto"
			% missoes.ESPERA_DA_LINHA)
	missoes._orfao_desde = Time.get_ticks_msec() - 30001
	conferir(not missoes.atual().is_empty(),
		"Passado meio minuto, o foco continua vago: a HUD fica em branco para sempre")
	missoes.limpar()


## Monta uma lista de missões do zero, na ordem dada.
func _montar(missoes, ids: Array) -> void:
	missoes.limpar()
	for id in ids:
		missoes.adicionar(str(id), "Missão %s" % id)


## QUAL MISSÃO A HUD ESTÁ MOSTRANDO, pelo id.
##
## Por id e não por índice de propósito: comparar índices seria refazer aqui a
## conta que está em teste, e dois erros iguais se cancelam.
func _fixada(missoes) -> String:
	var atual: Dictionary = missoes.atual()
	return str(atual.get("id", ""))
