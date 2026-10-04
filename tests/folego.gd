extends SceneTree
## Confere Progressao e Energia, a regra do cansaço e a cobrança das ações.
## No 3D, Energia acompanha o vigor do personagem; a barra azul representa
## a respiração. A ligação vigor -> fôlego -> vida e sua apresentação são
## verificadas por reservas_do_corpo.gd.

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
	energia.atual = progressao.ENERGIA_MAXIMA_INICIAL * 0.1
	_conferir(energia.cansado(), "com 10% do fôlego, o corpo não se deu por cansado")
	_conferir(is_equal_approx(energia.passo(), energia.PESO_DO_CANSACO),
		"cansado, o passo é %s e devia ser %s" % [str(energia.passo()), str(energia.PESO_DO_CANSACO)])

	energia.encher()
	_conferir(energia.atual == energia.maximo(), "encher() não encheu")

	# --- 3. O CORPO SENTE -----------------------------------------------------
	var fonte := FileAccess.get_file_as_string("res://scripts/prototipo_3d/player_controller.gd")
	_conferir(fonte != "", "não consegui ler o player_controller")
	_conferir(fonte.contains("speed *= Energia.passo()"),
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
	var podem_gastar := ["/recursos_3d.gd", "/luta_vale.gd"]
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

	# Energia representa o vigor no 3D; o fôlego azul pertence ao jogador.
	var hud = load("res://scripts/prototipo_3d/prototype_hud.gd").new()
	root.add_child(hud)
	await process_frame
	_conferir(hud.barra_stamina != null and hud.barra_stamina.visible, "o HUD não tem a barra de vigor")
	energia.encher()
	_conferir(is_equal_approx(hud.barra_stamina.value, energia.atual), "a barra não mostra o vigor cheio")
	energia.atual = energia.maximo() * 0.5
	energia.mudou.emit()
	_conferir(is_equal_approx(hud.barra_stamina.value, energia.atual), "a barra não acompanha o gasto de vigor")
	energia.encher()
	hud.queue_free()

	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("FOLEGO_OK: Progressao e Energia subiram com os números do 2D, o cansaço encurta o passo para 62% e o corpo lê isso; trabalho e luta cobram Energia, só a queda desmaia, e o HUD mostra o vigor")
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
