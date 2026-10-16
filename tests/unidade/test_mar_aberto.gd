extends "res://tests/unidade/base.gd"
## A LINHA FATAL DO MAR ABERTO (#260): a conta que garante que o tubarão chega antes de a borda do mapa aparecer.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste mar_aberto
##
## A regra do autor: "toda vez que a borda aparecer no minimapa, o tubarão já tem que ter matado o jogador". A issue
## escrevia `VISTA = 55 m de raio` e a "borda − 80 m" como linha; a conta de verdade (minimapa.gd) é outra:
## `Minimapa.VISTA` (55 u) é o LADO do quadrado da vista, o círculo tem raio 27,5 u (110 m) e "borda − 80 m" (20 u) já
## estaria DENTRO dele. Estas perguntas fixam a geometria que o `mar_aberto.gd` usa, sem o vale:
##
##   1. A DISTÂNCIA À BORDA é a da mais perto das quatro, em x e z.
##   2. O RAIO DA VISTA É O DO MINIMAPA, lido dele, e a borda só aparece abaixo dele.
##   3. A LINHA FATAL CHEGA ANTES DA BORDA: a linha, descontado o que o jogador ainda anda (no pior ritmo que ele tem na
##      água, durante o prazo do bote e a tela escurecendo), fica além do raio da vista. E esse pior ritmo é o do
##      jogador de verdade, com os talentos e a fé no máximo.
##   4. AS ZONAS (aviso e fatal) e a folga de quem beira a linha.
##   5. O QUE É "MAR": dentro d'água o bastante e fora da terra.
##   6. O AVISO E O SUSTO DO MAR ABERTO TÊM TEXTO nos três idiomas, fora do código.
##
## FALSIFICAÇÃO (à mão): `LINHA_FATAL := 40.0` reprova a 3; `RITMO_MAXIMO := 2.0` reprova a 3; `LAMINA_DO_MAR := 0.0`
## reprova a 5; tirar `aviso_en` do fauna_do_mar.json reprova a 6.

const MarAberto = preload("res://scripts/prototipo_3d/mar_aberto.gd")
## O quadro de verdade do vale (903,6 x 508,3 u, 16:9): assets/prototipo_3d/identidade/minimapa/mapa_vale.json.
const QUADRO := Rect2(-433.516754150391, -341.868255615234, 903.5947265625, 508.272003173828)


# --- 1. A DISTÂNCIA À BORDA --------------------------------------------------------------------------

func test_a_distancia_e_a_da_borda_mais_perto() -> void:
	var centro := QUADRO.get_center()
	conferir(is_equal_approx(MarAberto.distancia_a_borda(Vector3(centro.x, 0.0, centro.y), QUADRO), QUADRO.size.y * 0.5),
		"no centro a borda mais perto é a de cima ou a de baixo (metade da altura)")
	conferir(is_equal_approx(MarAberto.distancia_a_borda(Vector3(QUADRO.end.x - 12.0, 0.0, centro.y), QUADRO), 12.0), "a 12 u da borda leste")
	conferir(is_equal_approx(MarAberto.distancia_a_borda(Vector3(centro.x, 0.0, QUADRO.end.y - 7.0), QUADRO), 7.0), "a 7 u da borda sul")
	conferir(is_equal_approx(MarAberto.distancia_a_borda(Vector3(QUADRO.position.x + 30.0, 0.0, centro.y), QUADRO), 30.0), "a 30 u da borda oeste")
	conferir(is_equal_approx(MarAberto.distancia_a_borda(Vector3(centro.x, 0.0, QUADRO.position.y + 3.0), QUADRO), 3.0), "a 3 u da borda norte")
	# No canto vale a menor das duas, e não a diagonal.
	conferir(is_equal_approx(MarAberto.distancia_a_borda(Vector3(QUADRO.end.x - 20.0, 0.0, QUADRO.end.y - 50.0), QUADRO), 20.0), "no canto sudeste vale a menor das duas")
	conferir(MarAberto.distancia_a_borda(Vector3(QUADRO.end.x + 9.0, 0.0, 0.0), QUADRO) == 0.0, "fora do quadro a distância é zero")
	# A altura não conta.
	conferir(is_equal_approx(MarAberto.distancia_a_borda(Vector3(QUADRO.end.x - 12.0, 40.0, centro.y), QUADRO), 12.0), "a altura não entra na distância")


func test_o_rumo_da_borda_aponta_para_a_mais_perto() -> void:
	var c := QUADRO.get_center()
	conferir(MarAberto.rumo_da_borda(Vector3(QUADRO.end.x - 10.0, 0.0, c.y), QUADRO) == Vector3.RIGHT, "perto da borda leste, o rumo é +x")
	conferir(MarAberto.rumo_da_borda(Vector3(c.x, 0.0, QUADRO.end.y - 10.0), QUADRO) == Vector3.BACK, "perto da borda sul, o rumo é +z")
	conferir(MarAberto.rumo_da_borda(Vector3(QUADRO.position.x + 10.0, 0.0, c.y), QUADRO) == Vector3.LEFT, "perto da borda oeste, o rumo é -x")
	conferir(MarAberto.rumo_da_borda(Vector3(c.x, 0.0, QUADRO.position.y + 10.0), QUADRO) == Vector3.FORWARD, "perto da borda norte, o rumo é -z")


# --- 2. O RAIO DA VISTA É O DO MINIMAPA ----------------------------------------------------------------

func test_o_raio_da_vista_e_o_do_minimapa() -> void:
	var minimapa = load("res://scripts/prototipo_3d/minimapa.gd")
	var lado: float = minimapa.VISTA
	conferir(is_equal_approx(MarAberto.borda_no_minimapa(), lado * 0.5),
		"o raio da vista (%.1f u) devia ser metade do lado do minimapa (%.1f u): VISTA é o lado do quadrado, e o círculo tem metade dele" % [MarAberto.borda_no_minimapa(), lado])
	conferir(is_equal_approx(MarAberto.borda_no_minimapa(), 27.5), "o raio da vista de hoje é 27,5 u (110 m): %.2f" % MarAberto.borda_no_minimapa())
	# A borda só aparece abaixo do raio, e o mapa doido a adianta pela deriva.
	conferir(not MarAberto.borda_a_vista(27.6), "a 27,6 u da borda a vista ainda é só mar")
	conferir(MarAberto.borda_a_vista(27.4), "a 27,4 u da borda a faixa escura já entra no círculo")
	conferir(MarAberto.borda_a_vista(60.0, 38.0) and not MarAberto.borda_a_vista(66.0, 38.0),
		"com o mapa doido (a foto escorrega 38 u) a borda aparece até 65,5 u")
	conferir(is_equal_approx(MarAberto.deriva_maxima_do_mapa(), 38.0), "a deriva máxima do mapa doido é 38 u (loucura_do_mapa.gd): %.1f" % MarAberto.deriva_maxima_do_mapa())


# --- 3. A LINHA FATAL CHEGA ANTES DA BORDA -----------------------------------------------------------------

func test_a_linha_fatal_chega_antes_da_borda() -> void:
	var raio: float = MarAberto.borda_no_minimapa()
	var folga: float = MarAberto.folga_da_perseguicao()
	conferir(is_equal_approx(folga, MarAberto.RITMO_MAXIMO * (MarAberto.PRAZO_DO_BOTE + MarAberto.DO_ATAQUE_AO_PRETO)), "a folga é o ritmo máximo vezes o prazo")
	conferir(MarAberto.LINHA_FATAL >= raio + folga,
		"a linha fatal (%.1f u) devia ficar além do raio da vista (%.1f) mais o que o jogador anda até o susto (%.1f)" % [MarAberto.LINHA_FATAL, raio, folga])
	# Quem corre sem parar no pior ritmo, desde a linha, não vê a borda antes de a tela escurecer.
	var onde_escurece: float = MarAberto.LINHA_FATAL - folga
	conferir(not MarAberto.borda_a_vista(onde_escurece), "no pior ritmo a borda já aparece (%.1f u) quando a tela escurece" % onde_escurece)
	# E o prazo do bote é curto: o susto não pode ser uma promessa de minutos.
	conferir(MarAberto.PRAZO_DO_BOTE <= 6.0, "o prazo do bote (%.1f s) devia ser de poucos segundos" % MarAberto.PRAZO_DO_BOTE)
	# O susto do tubarão leva pelo menos até a cortina (a tela preta) neste tempo, e a conta usa o dele.
	var tubarao = load("res://scripts/prototipo_3d/tubarao.gd")
	conferir(tubarao.ATE_O_PRETO <= MarAberto.DO_ATAQUE_AO_PRETO + 0.001,
		"o susto leva %.2f s até o preto, e a conta da linha fatal supõe %.2f" % [tubarao.ATE_O_PRETO, MarAberto.DO_ATAQUE_AO_PRETO])


func test_o_pior_ritmo_cobre_o_jogador_de_verdade() -> void:
	var jogador = load("res://scripts/prototipo_3d/player_controller.gd")
	var constantes: Dictionary = jogador.get_script_constant_map()
	var corpo = jogador.new()
	var corre: float = corpo.run_speed
	var altura: float = corpo.character_height
	corpo.free()
	# O máximo de passo que a árvore de talentos dá, e o da fé que mais dá (só se pratica uma).
	var talentos = root.get_node("/root/Talentos")
	var fe = root.get_node("/root/Fe")
	var de_talentos := 0.0
	for no in talentos.NOS:
		de_talentos += float(talentos.NOS[no].get("efeito", {}).get("passo", 0.0))
	var de_fe := 0.0
	for qual in fe.ARVORES:
		var soma := 0.0
		for no in fe.ARVORES[qual]:
			soma += float(fe.ARVORES[qual][no].get("efeito", {}).get("passo", 0.0))
		de_fe = maxf(de_fe, soma)
	var mais_passo: float = 1.0 + de_talentos + de_fe
	# Correr a vau, com a água já na lâmina do mar (0,4 u) freando o passo.
	var freio: float = lerpf(1.0, float(constantes["VELOCIDADE_NA_AGUA"]), clampf(MarAberto.LAMINA_DO_MAR / (altura * float(constantes["NADA_A_PARTIR"])), 0.0, 1.0))
	var a_vau: float = corre * freio * mais_passo
	var a_nado: float = float(constantes["VELOCIDADE_NADO"]) * 2.0 * mais_passo
	conferir(MarAberto.RITMO_MAXIMO >= a_vau, "o pior ritmo da conta (%.1f u/s) devia cobrir a corrida a vau (%.1f u/s, com +%.0f%% de passo)" % [MarAberto.RITMO_MAXIMO, a_vau, (mais_passo - 1.0) * 100.0])
	conferir(MarAberto.RITMO_MAXIMO >= a_nado, "o pior ritmo da conta (%.1f u/s) devia cobrir o nado de corrida (%.1f u/s)" % [MarAberto.RITMO_MAXIMO, a_nado])
	conferir(mais_passo < 1.6, "o passo máximo passou de 60%% (%.2f): rever RITMO_MAXIMO e a linha fatal" % mais_passo)


# --- 4. AS ZONAS ---------------------------------------------------------------------------------------------

func test_as_zonas_e_a_folga_de_quem_beira_a_linha() -> void:
	conferir(MarAberto.FAIXA_DE_AVISO > MarAberto.LINHA_FATAL + MarAberto.HISTERESE * 2.0, "a faixa de aviso devia passar da linha fatal com folga")
	conferir(MarAberto.FAIXA_DE_AVISO - MarAberto.LINHA_FATAL >= 30.0, "o aviso devia dar 30 u para entender e voltar (%.0f)" % (MarAberto.FAIXA_DE_AVISO - MarAberto.LINHA_FATAL))
	var longe := MarAberto.Zona.NENHUMA
	var aviso := MarAberto.Zona.AVISO
	var fatal := MarAberto.Zona.FATAL
	conferir(MarAberto.zona(300.0) == longe and MarAberto.zona(MarAberto.FAIXA_DE_AVISO + 0.5) == longe, "longe da borda não há zona")
	conferir(MarAberto.zona(MarAberto.FAIXA_DE_AVISO - 0.5) == aviso and MarAberto.zona(MarAberto.LINHA_FATAL + 0.5) == aviso, "entre a faixa e a linha é aviso")
	conferir(MarAberto.zona(MarAberto.LINHA_FATAL - 0.5) == fatal and MarAberto.zona(0.0) == fatal, "além da linha é fatal")
	# Quem já está na zona só sai dela com a folga: a barbatana não pisca a cada passo na linha.
	var h: float = MarAberto.HISTERESE
	conferir(MarAberto.zona(MarAberto.LINHA_FATAL + h - 0.5, fatal) == fatal, "quem estava na zona fatal e recuou meio passo continua nela")
	conferir(MarAberto.zona(MarAberto.LINHA_FATAL + h + 0.5, fatal) == aviso, "recuar além da folga leva ao aviso")
	conferir(MarAberto.zona(MarAberto.FAIXA_DE_AVISO + h - 0.5, aviso) == aviso, "quem estava no aviso e recuou meio passo continua nele")
	conferir(MarAberto.zona(MarAberto.FAIXA_DE_AVISO + h + 0.5, aviso) == longe, "recuar além da folga tira do aviso")
	conferir(MarAberto.zona(MarAberto.LINHA_FATAL + 0.5, longe) == aviso and MarAberto.zona(MarAberto.FAIXA_DE_AVISO - 0.5, longe) == aviso,
		"quem chega não ganha folga: entra no aviso na faixa")
	# A linha de prova (a falsificação do caso do vale zera a linha): sem ela não há zona fatal.
	conferir(MarAberto.zona(5.0, longe, 0.0) == aviso, "com a linha em zero ninguém morre: é o que a falsificação do caso usa")


# --- 5. O QUE É MAR ------------------------------------------------------------------------------------------

func test_o_mar_e_agua_acima_do_joelho_fora_da_terra() -> void:
	conferir(MarAberto.no_mar(MarAberto.LAMINA_DO_MAR, false), "a água no joelho já é mar")
	conferir(MarAberto.no_mar(2.0, false), "o fundo é mar")
	conferir(not MarAberto.no_mar(MarAberto.LAMINA_DO_MAR - 0.01, false), "a praia molhada não é mar")
	conferir(not MarAberto.no_mar(0.0, false), "a areia seca não é mar")
	conferir(not MarAberto.no_mar(2.0, true), "o rio e a ponte, dentro da terra, não são mar")
	conferir(MarAberto.LAMINA_DO_MAR >= 0.3 and MarAberto.LAMINA_DO_MAR <= 0.6, "a lâmina do mar devia ser a do joelho (%.2f)" % MarAberto.LAMINA_DO_MAR)


# --- 6. OS TEXTOS ----------------------------------------------------------------------------------------------

func test_o_aviso_e_o_susto_do_mar_aberto_tem_os_tres_idiomas() -> void:
	var lido = JSON.parse_string(FileAccess.get_file_as_string("res://data/fauna_do_mar.json"))
	conferir(lido is Dictionary and (lido as Dictionary).has("tubarao"), "falta o bloco do tubarão em fauna_do_mar.json")
	if not (lido is Dictionary):
		return
	var bloco: Dictionary = lido["tubarao"]
	var codigo := FileAccess.get_file_as_string("res://scripts/prototipo_3d/tubarao.gd")
	for chave in ["susto", "aviso", "susto_borda"]:
		var pt := str(bloco.get(chave, ""))
		conferir(pt != "", "falta o texto '%s' em português" % chave)
		conferir(pt.length() <= 90, "o texto '%s' (%d letras) devia caber no aviso do HUD" % [chave, pt.length()])
		conferir(not codigo.contains(pt) or pt == "", "o texto '%s' ainda está escrito no código" % chave)
		for sufixo in ["_en", "_es"]:
			var traduzido := str(bloco.get(chave + sufixo, ""))
			conferir(traduzido != "", "falta '%s%s'" % [chave, sufixo])
			conferir(traduzido != pt, "'%s%s' é cópia do português: tradução faltando disfarçada de tradução" % [chave, sufixo])
	# O aviso diz que a barbatana ronda (o que o jogador vê); o susto do mar aberto diz que o mar o devolveu.
	conferir(str(bloco.get("aviso", "")) != str(bloco.get("susto", "")), "o aviso e o susto de sempre são frases diferentes")
	conferir(str(bloco.get("susto_borda", "")) != str(bloco.get("susto", "")), "o susto do mar aberto e o de sempre são frases diferentes")
