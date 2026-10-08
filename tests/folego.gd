extends SceneTree
## Confere que o FÔLEGO do jogo 2D chegou ao vale, e que ele pesa no corpo.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/folego.gd
##
## `Progressao` e `Energia` não são código escrito para o 3D: são os mesmos
## arquivos do jogo 2D, em `scripts/compartilhado/`, conferidos byte a byte
## pelo `testar_compartilhado` do outro projeto. Eles atravessaram porque não
## sabem o que é um tile — e este teste existe para que continuem assim.
##
## Quatro perguntas:
##
##   1. OS DOIS SUBIRAM, e com os números do 2D. Autoload que falha ao carregar
##      não derruba o jogo no Godot: ele some, e quem o chama é que estoura,
##      três telas adiante.
##   2. A REGRA DO CANSAÇO É A DO 2D: abaixo de um quinto do fôlego o passo cai
##      para 62%, e não para outro número inventado aqui.
##   3. O CORPO SENTE. O `player_controller` multiplica a velocidade pelo
##      `Energia.passo()` — lido do fonte, porque medir velocidade de um corpo
##      que anda por física dá um teste que falha por pouco em máquina lenta.
##   4. LUTA E TRABALHO GASTAM FÔLEGO, e a queda desmaia. O vale tem
##      enxada, machado, picareta e lavoura; seus portões cobram esses usos.
##      A luta chegou com a #14 — golpe e ginga cobram "bater", e
##      o `tests/luta.gd` confere quanto. A QUEDA (`queda.gd`, #10) chama
##      `Energia.desmaiar()` como o `_apagar` do 2D, que devolve fôlego. Quem
##      mais passar a gastar ou a desmaiar reprova aqui, e o recado é o mesmo
##      de antes: escreva o portão do que passou a gastar, e ponha o arquivo na
##      lista. A CAMA (#50) entrou assim: ela vira a noite pelo mesmo
##      `queda.gd`, e devolve o fôlego do sono (`Energia.dormir()`) — o portão
##      dela é o `tests/casa.gd`.
##      E A LAVOURA (#8): arar, plantar, regar e colher cobram como no roçado do
##      2D, e o portão dela é o `tests/lavoura.gd`. E O CORTE DAS ÁRVORES: cada
##      golpe cobra bater × dureza da madeira, e o portão dele é o
##      `tests/corte_das_arvores.gd`.
##   5. O HUD MOSTRA (#3). A barra de fôlego acompanha o número, e abaixo do
##      limiar muda de cor e diz "cansado" — o corpo já sentia, e quem joga
##      não sabia por quê.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("FOLEGO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	# --- 1. OS DOIS SUBIRAM ---------------------------------------------------
	var progressao := root.get_node_or_null("/root/Progressao")
	var energia := root.get_node_or_null("/root/Energia")
	_conferir(progressao != null, "o autoload Progressao não subiu")
	_conferir(energia != null, "o autoload Energia não subiu")
	if progressao == null or energia == null:
		_fechar()
		return

	_conferir(progressao.ENERGIA_MAXIMA_INICIAL == 100.0,
		"o teto de fôlego não é o do 2D: %s" % str(progressao.ENERGIA_MAXIMA_INICIAL))
	_conferir(progressao.RECUPERACAO_INICIAL == 40.0,
		"o que o sono devolve não é o do 2D: %s" % str(progressao.RECUPERACAO_INICIAL))
	_conferir(energia.atual == progressao.ENERGIA_MAXIMA_INICIAL,
		"o vale não começa com o fôlego cheio: %s" % str(energia.atual))

	# --- 2. A REGRA DO CANSAÇO É A DO 2D --------------------------------------
	_conferir(energia.LIMIAR_DE_CANSACO == 0.2,
		"o limiar do cansaço mudou: %s" % str(energia.LIMIAR_DE_CANSACO))
	_conferir(energia.PESO_DO_CANSACO == 0.62,
		"o peso do cansaço mudou: %s" % str(energia.PESO_DO_CANSACO))

	_conferir(not energia.cansado(), "de fôlego cheio, o corpo já estava cansado")
	_conferir(energia.passo() == 1.0, "de fôlego cheio, o passo não é inteiro")

	# Um décimo do teto: abaixo do limiar, e o passo tem de encurtar.
	energia.definir(progressao.ENERGIA_MAXIMA_INICIAL * 0.1)
	_conferir(energia.cansado(), "com 10% do fôlego, o corpo não se deu por cansado")
	_conferir(is_equal_approx(energia.passo(), energia.PESO_DO_CANSACO),
		"cansado, o passo é %s e devia ser %s" % [str(energia.passo()), str(energia.PESO_DO_CANSACO)])

	energia.encher()
	_conferir(energia.atual == energia.maximo(), "encher() não encheu")

	# --- 3. O CORPO SENTE -----------------------------------------------------
	var fonte := FileAccess.get_file_as_string("res://scripts/prototipo_3d/player_controller.gd")
	_conferir(fonte != "", "não consegui ler o player_controller")
	# O passo do Energia chega ao corpo por `multiplicador_do_passo` (que também soma o talento
	# e a fé ativa, 0611ca8): o controle multiplica a velocidade por ele, e ele pelo cansaço.
	_conferir(fonte.contains("speed *= multiplicador_do_passo()") and fonte.contains("* Energia.passo()"),
		"o controle do jogador não multiplica a velocidade pelo passo do Energia: o cansaço não chega ao corpo")

	# --- 4. QUEM PODE GASTAR FÔLEGO, E SÓ ELES -------------------------------
	#
	# As duas metades desta pergunta nasceram separadas e se encontraram nesta
	# junção. Uma vinha das FERRAMENTAS: bater num tronco custa, e é o que faz
	# a ferramenta valer. A outra vinha da LUTA: o golpe e a ginga do 2D cobram
	# "bater". As duas estão certas, e o que muda é que a lista de quem pode
	# gastar tem dois nomes em vez de um.
	#
	# Cada lado, sozinho, reprovava o outro — e reprovava com razão, porque
	# cada um tinha sido escrito quando só existia o seu. O que a pergunta
	# guarda continua igual: chamada a `Energia.gastar` fora desta lista é
	# ação nova sem portão. Quem acrescentar uma terceira escreve o portão
	# dela e põe o arquivo aqui.
	#
	# `Energia.desmaiar` é da queda, e de mais ninguém: é a mesma noite no
	# chão do desmaio do 2D.
	#
	# Chamada é linha de CÓDIGO: comentário que cita a função (e o `queda.gd`
	# cita) não pode contar como chamada, nem para acusar nem para absolver.
	# A cama (`queda.gd`, #50) devolve o fôlego do sono; o portão dela é o
	# `tests/casa.gd`, que confere quanto. A lavoura (`lavoura_vale.gd`, #8)
	# cobra arar, plantar, regar e colher como o roçado do 2D; o portão dela é o
	# `tests/lavoura.gd`. E O CORTE DAS ÁRVORES (`arvores_info.gd`): o golpe na
	# árvore cobra bater × dureza da madeira, como o tronco caído; o portão dele
	# é o `tests/corte_das_arvores.gd`, que confere quanto.
	var podem_gastar := ["/recursos_3d.gd", "/luta_vale.gd", "/queda.gd", "/lavoura_vale.gd", "/arvores_info.gd"]
	var gasta_sem_portao: Array[String] = []
	var desmaia_fora_da_queda := false
	var desmaia := RegEx.create_from_string("(?m)^[ \\t]+[^#\\n]*Energia\\.desmaiar\\(")
	var gasta := RegEx.create_from_string("(?m)^[ \\t]+[^#\\n]*Energia\\.(gastar|dormir)\\(")
	for arquivo in _scripts_do_prototipo():
		var texto := FileAccess.get_file_as_string(arquivo)
		if gasta.search(texto) != null:
			var permitido := false
			for fim in podem_gastar:
				if arquivo.ends_with(fim):
					permitido = true
			if not permitido:
				gasta_sem_portao.append(arquivo.get_file())
		if desmaia.search(texto) != null and not arquivo.ends_with("/queda.gd"):
			desmaia_fora_da_queda = true
	for arquivo in gasta_sem_portao:
		_conferir(false,
			"'%s' passou a gastar fôlego e não tem portão: escreva o dele, como o ferramentas.gd e o luta.gd fizeram"
				% arquivo)

	# E o outro lado da mesma pergunta: os dois que PODEM gastar têm de
	# continuar gastando. Trabalho de graça e luta de graça são defeitos tão
	# grandes quanto gasto sem portão, e calados.
	var recursos := FileAccess.get_file_as_string("res://scripts/prototipo_3d/recursos_3d.gd")
	_conferir(gasta.search(recursos) != null,
		"o trabalho parou de gastar fôlego: bater tem de custar, e é o que faz a ferramenta valer")
	var luta := FileAccess.get_file_as_string("res://scripts/prototipo_3d/luta_vale.gd")
	_conferir(gasta.search(luta) != null,
		"a luta não gasta fôlego: o golpe e a ginga do 2D cobram 'bater'")
	_conferir(not desmaia_fora_da_queda,
		"Energia.desmaiar() fora do queda.gd: o vale ganhou outra noite no chão, e ela precisa do portão dela")
	var queda := FileAccess.get_file_as_string("res://scripts/prototipo_3d/queda.gd")
	_conferir(desmaia.search(queda) != null,
		"a queda não chama Energia.desmaiar(): cair deixou de ser a mesma noite do desmaio do 2D")

	# --- 5. O HUD MOSTRA (#3, #82) ---------------------------------------------
	# A barra do meio é a reserva do dia: acompanha o `Energia` com ou sem jogador,
	# só com o número, e no limiar diz "cansado" e muda de cor.
	var hud = load("res://scripts/prototipo_3d/prototype_hud.gd").new()
	root.add_child(hud)
	await process_frame
	_conferir(hud.barra_folego != null and hud.barra_folego.visible, "o HUD não tem a barra da reserva")
	energia.encher()
	_conferir(is_equal_approx(hud.barra_folego.value, energia.atual), "a barra não mostra a reserva cheia")
	_conferir(hud._folego_texto.text == str(roundi(energia.atual)),
		"em terra a barra da reserva não mostra só o número: '%s'" % hud._folego_texto.text)
	energia.definir(energia.maximo() * 0.5)
	_conferir(is_equal_approx(hud.barra_folego.value, energia.atual), "a barra não acompanha o gasto da reserva")
	energia.definir(energia.maximo() * 0.1)
	_conferir(hud._folego_texto.text.contains("cansado") and hud._folego_preenchimento.bg_color == hud.COR_RESERVA_BAIXA,
		"no limiar a barra da reserva não diz 'cansado' nem muda de cor: '%s'" % hud._folego_texto.text)
	energia.encher()
	hud.queue_free()

	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("FOLEGO_OK: Progressao e Energia subiram com os números do 2D, o cansaço encurta o passo para 62% e o corpo lê isso; quem gasta fôlego é o trabalho, a lavoura e a luta, a cama devolve o do sono, e só a queda desmaia; o HUD mostra o fôlego e o cansaço")
	else:
		print("folego: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


## Todo `.gd` do protótipo, menos os compartilhados (que são do 2D) e os
## próprios testes.
func _scripts_do_prototipo() -> Array:
	var achados := []
	var pastas := ["res://scripts/prototipo_3d", "res://scripts/autoload"]
	for pasta in pastas:
		var dir := DirAccess.open(pasta)
		if dir == null:
			continue
		for nome in dir.get_files():
			if nome.ends_with(".gd"):
				achados.append(pasta + "/" + nome)
	return achados
