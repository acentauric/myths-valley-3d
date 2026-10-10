extends "res://tests/unidade/base.gd"
## Parcial: testar_fracoes do 2D, SHA 62c0f14b (#18); producao pendente.
## Confere que os números do jogo guardam a FRAÇÃO, mesmo sem mostrá-la.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste regras_fracoes
##
## O defeito que este portão existe para pegar não dá erro, não dá aviso e não
## aparece em lugar nenhum da tela. Ele é uma torneira fechada com cara de
## aberta.
##
## Um morador que rende 0,4 de mandioca por dia entregava ZERO. Não pouco:
## zero, hoje, amanhã e daqui a cem dias, porque `int(round(0.4))` é zero. E no
## dia em que existir "+15% de experiência" — que é o bônus mais óbvio que
## falta na teia —, arar renderia 3 × 1,15 = 3,45, o inteiro faria disso 3, e o
## jogador teria gastado um ponto de talento num número que não muda.
##
## A regra, e ela é de projeto: **o que se ACUMULA é fração; o que se MOSTRA é
## inteiro.** Fôlego, experiência de ofício, experiência de fé e a produção do
## arraial acumulam em ponto flutuante. A tela trunca. O jogador nunca vê meia
## mandioca nem meio ponto de experiência, e nunca perde nenhum dos dois.
##
## Confere seis coisas:
##
##   1. Os acumuladores são float, e não int.
##   2. Ganho fracionário de XP não se perde: cem pingos de 0,3 viram 30.
##   3. O que a tela mostra continua inteiro.
##   4. A fé acumula igual, e o nível sai do acumulado com fração.
##   5. A produção do arraial fecha o saldo em trinta dias.
##   6. A fração sobrevive a salvar e carregar.


func test_fracoes_de_xp_fe_e_save() -> void:
	var talentos := root.get_node("/root/Talentos")
	var fe := root.get_node("/root/Fe")
	var energia := root.get_node("/root/Energia")
	var salvamento := root.get_node("/root/Salvamento")

	# --- 1. os acumuladores são float ----------------------------------------
	#
	# Perguntado ao VALOR e não ao código: `typeof` não tem como ser enganado
	# por uma declaração que diz float e uma atribuição que guarda int.
	talentos.xp = 0.0
	talentos.xp += 0.5
	conferir(typeof(talentos.xp) == TYPE_FLOAT,
		"Talentos.xp não é float: a fração morre na atribuição")
	conferir(is_equal_approx(talentos.xp, 0.5),
		"Talentos.xp engoliu meio ponto: guardou %s" % str(talentos.xp))
	conferir(typeof(energia.atual) == TYPE_FLOAT,
		"Energia.atual não é float: custo fracionário some")

	# --- 2. o pingo que não se perde -----------------------------------------
	#
	# Cem ganhos que, sozinhos, arredondariam para zero. É a conta do bônus de
	# percentagem: nenhum deles vale um ponto inteiro, e os cem valem trinta.
	talentos.nivel = 1
	talentos.xp = 0.0
	talentos.pontos = 0
	talentos.destravados = []
	var PINGOS := 100
	var por_pingo := 0.1        # 0,1 de "arar" = 0,3 de XP
	for i in PINGOS:
		talentos.ganhar("arar", por_pingo)
		if "--falsificar-fracao" in OS.get_cmdline_user_args():
			talentos.xp = floorf(talentos.xp)
	var esperado := float(talentos.XP_POR_ACAO["arar"]) * por_pingo * float(PINGOS)
	var somado: float = talentos.xp + _xp_gasto_em_niveis(talentos)
	conferir(is_equal_approx(somado, esperado),
		"Cem pingos de %.2f deviam somar %.1f e somaram %.4f" % [por_pingo, esperado, somado])

	# E ELE SOBE DE NÍVEL. Não basta acumular: o acumulado tem que virar nível
	# e ponto como qualquer outro XP, senão a fração fica presa num contador
	# que nunca é lido.
	talentos.nivel = 1
	talentos.xp = 0.0
	talentos.pontos = 0
	var voltas := 0
	while talentos.nivel == 1 and voltas < 10000:
		voltas += 1
		talentos.ganhar("arar", 0.1)
	conferir(talentos.nivel > 1,
		"Ganhando de décimo em décimo, o nível nunca subiu em %d voltas" % voltas)
	conferir(talentos.pontos > 0, "Subiu de nível e não creditou ponto")

	# --- 3. a tela continua inteira ------------------------------------------
	#
	# A fração é de dentro. O rodapé da teia escreve com `%d`, que trunca — e é
	# assim que o jogador nunca vê "137,4 / 260 para o nível 3".
	talentos.xp = 137.4
	var escrito := "%d / %d" % [talentos.xp, talentos.xp_do_nivel()]
	conferir(not escrito.contains("."),
		"O número da tela saiu com vírgula: '%s'" % escrito)
	conferir(escrito.begins_with("137"),
		"A tela devia truncar 137,4 em 137 e escreveu '%s'" % escrito)

	# --- 4. a fé acumula igual -----------------------------------------------
	fe.ativa = "catolica"
	fe._estados["catolica"] = {"total": 0.0, "teto": 1, "destravados": []}
	fe._espelhar()
	for i in 100:
		fe.ganhar("visita", 0.1)     # 0,8 por vez
	var total_da_fe: float = fe.total_exato("catolica")
	conferir(is_equal_approx(total_da_fe, float(fe.XP_POR_ATO["visita"]) * 0.1 * 100.0),
		"A fé perdeu fração: devia ter %.1f e tem %.4f"
			% [float(fe.XP_POR_ATO["visita"]) * 0.1 * 100.0, total_da_fe])
	conferir(fe.total("catolica") == floori(total_da_fe),
		"Fe.total devia ser o inteiro de %.2f e deu %d" % [total_da_fe, fe.total("catolica")])
	conferir(typeof(fe.xp) == TYPE_FLOAT, "Fe.xp não é float")

	# A producao fracionaria de trabalhadores aguarda Povoado/Terrenos no 3D.
	# Contratos pendentes enumerados em PORTOES_2D_3D.md; nao sao aprovados aqui.

	# --- 6. a fração atravessa o carregamento --------------------------------
	#
	# Duas camadas, e as duas podem comer a casa decimal sem avisar: o JSON, e
	# os faxineiros do `Salvamento` (`_limpar_*`), que existem justamente para
	# consertar valor fora de faixa e poderiam "consertar" 41,625 para 41.
	#
	# SEM ESCREVER ARQUIVO. Rodando fora do runner de perfil isolado, o
	# `user://` deste teste é o perfil DE VERDADE de quem está na máquina, e
	# portão que mexe na partida de alguém para provar um ponto é portão que um
	# dia apaga a partida de alguém. Aqui o save é montado à mão, passa pelo
	# JSON de ida e volta e entra pelo `carregar`, que é o caminho por onde os
	# bytes chegam de qualquer jeito.
	var como_no_disco := {
		"versao": salvamento.VERSAO,
		"Talentos": {"nivel": 1, "xp": 41.625, "pontos": 0, "destravados": []},
		# "estados" e não "_estados": é o nome com que o save grava o privado
		# da fé. Ver `Salvamento._guardar_especiais`.
		"Fe": {"ativa": "catolica",
			"estados": {"catolica": {"total": 12.5, "teto": 1, "destravados": []}}},
	}
	var texto := JSON.stringify(como_no_disco)
	var de_volta = JSON.parse_string(texto)
	conferir(de_volta != null, "O JSON do save não voltou: %s" % texto)
	if de_volta != null:
		conferir(is_equal_approx(float(de_volta["Talentos"]["xp"]), 41.625),
			"O JSON comeu a casa decimal do XP: voltou %s" % str(de_volta["Talentos"]["xp"]))

	talentos.xp = 0.0
	fe._estados["catolica"]["total"] = 0.0
	conferir(salvamento.carregar(de_volta), "O save de teste não foi aceito pelo carregar")
	conferir(is_equal_approx(talentos.xp, 41.625),
		"O XP voltou %s e devia voltar 41,625" % str(talentos.xp))
	conferir(is_equal_approx(fe.total_exato("catolica"), 12.5),
		"A fé voltou %s e devia voltar 12,5" % str(fe.total_exato("catolica")))


## Quanto XP já foi consumido pelos níveis vencidos. Sem isto a conta do
## acumulado não fecha: `ganhar` desconta do `xp` a cada nível que sobe.
func _xp_gasto_em_niveis(talentos) -> float:
	var gasto := 0.0
	for n in range(1, int(talentos.nivel)):
		gasto += float(int(roundf(talentos.BASE_DO_NIVEL * pow(talentos.CRESCIMENTO, n - 1))))
	return gasto
