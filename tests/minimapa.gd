extends SceneTree
## Confere A BÚSSOLA DO CANTO: redonda, e apontando a missão em foco.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/minimapa.gd
##
## "No minimapa deve indicar o local da missão, como acontece na maioria dos
## jogos de RPG. Você pode aplicar uma máscara no HUD do minimapa para ficar
## redondo como se fosse uma bússola."
##
## O minimapa existia desde o começo e NUNCA TEVE PORTÃO — é a razão de o
## defeito ter durado. O losango do alvo era desenhado, mas seguia o último
## passo ANUNCIADO: com várias cadeias abertas ele apontava para quem tinha
## acabado de falar, e não para o que o jogador escolheu fazer no painel. Nada
## media isso, e ninguém reparou.
##
## O QUE A MÁSCARA MUDA NAS CONTAS. Vista redonda apaga as quinas, e o marcador
## de alvo longe era preso no retângulo: num canto, ele cai justamente no pedaço
## que o shader apaga — o jogador perderia a seta exatamente quando mais precisa
## dela, longe do alvo. Por isso o limite virou redondo, e é a pergunta 5.
##
## Sete perguntas:
##
##   1. A BÚSSOLA ESTÁ NO HUD, quadrada, e dentro da janela.
##   2. ELA É REDONDA: a vista tem máscara, e o aro tem raio de meio lado.
##   3. SEM MISSÃO EM FOCO, não há losango de alvo.
##   4. COM MISSÃO EM FOCO, há losango, e ele cai do lado certo do jogador.
##   5. ALVO LONGE ENCOSTA NO ARO, e fica DENTRO do círculo — não na quina.
##   6. O LOSANGO SEGUE O FOCO: fixar a outra missão muda o lado para onde ele
##      aponta. É o que separa "aponta a missão" de "aponta quem falou".
##   7. MISSÃO CUMPRIDA LIMPA O ALVO: bússola que aponta o que já foi feito
##      manda o jogador andar à toa.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("MINIMAPA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK,
		"a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(6)

	var jogo := current_scene
	var jogador = jogo.get("player")
	var caderno := root.get_node("/root/CadernoDoVale")
	var bussola: Control = null
	for no in jogo.find_children("Minimapa", "", true, false):
		bussola = no as Control
	_conferir(bussola != null, "o HUD não tem o minimapa")
	if bussola == null or jogador == null:
		_fechar()
		return

	# --- 1. NO HUD, QUADRADA, DENTRO DA JANELA -------------------------------
	await _frames(3)
	var quadro := bussola.get_global_rect()
	var janela: Vector2 = bussola.get_viewport_rect().size
	_conferir(is_equal_approx(quadro.size.x, quadro.size.y),
		"a bússola é %s: círculo em moldura retangular corta mais de um lado que do outro"
			% str(quadro.size))
	_conferir(quadro.position.x >= -1.0 and quadro.position.y >= -1.0
			and quadro.end.x <= janela.x + 1.0 and quadro.end.y <= janela.y + 1.0,
		"a bússola saiu da janela: %s numa tela de %s" % [str(quadro), str(janela)])
	print("  bússola: %s numa tela de %s" % [str(quadro.size), str(janela)])

	# --- 2. ELA É REDONDA ---------------------------------------------------
	#
	# Duas metades, e as duas têm de estar: a MÁSCARA apaga o mundo fora do
	# círculo, e o ARO é a moldura. Só a moldura redonda com a vista quadrada
	# deixaria o mapa vazando por baixo do aro.
	var vista: SubViewportContainer = null
	for no in bussola.find_children("*", "SubViewportContainer", true, false):
		vista = no as SubViewportContainer
	_conferir(vista != null, "a bússola não tem a vista do mundo")
	if vista != null:
		_conferir(vista.material is ShaderMaterial,
			"a vista da bússola não tem máscara: ela continua quadrada por dentro")
	var moldura: Panel = null
	for no in bussola.find_children("*", "Panel", true, false):
		moldura = no as Panel
	if moldura != null:
		var estilo := moldura.get_theme_stylebox("panel")
		if estilo is StyleBoxFlat:
			var raio: int = (estilo as StyleBoxFlat).corner_radius_top_left
			_conferir(float(raio) >= bussola.LADO * 0.5 - 1.0,
				"o aro tem raio %d para um lado de %.0f: não fecha o círculo"
					% [raio, bussola.LADO])

	# O centro da vista, para medir de onde o marcador sai.
	var meio: Vector2 = bussola._sobre.size * 0.5

	# --- 3. SEM MISSÃO EM FOCO, SEM LOSANGO ---------------------------------
	caderno.limpar()
	await _frames(3)
	_conferir(not bussola._tem_alvo,
		"sem missão em foco a bússola continua apontando alguma coisa")

	# --- 4. COM MISSÃO EM FOCO, O LOSANGO CAI DO LADO CERTO -----------------
	#
	# O alvo é posto A LESTE do jogador (x maior), e perto o bastante para não
	# bater no aro: o marcador tem de sair à direita do centro.
	var aqui: Vector3 = jogador.global_position
	caderno.abrir_missao("perto_do_minimapa", "Um passo de teste", "pedro", true)
	caderno.apontar("perto_do_minimapa", aqui + Vector3(8.0, 0.0, 0.0))
	caderno.fixar("perto_do_minimapa")
	await _frames(4)
	_conferir(bussola._tem_alvo, "com missão em foco e lugar a bússola não aponta nada")
	var escala: float = bussola._sobre.size.y / bussola.VISTA
	var leste: Vector2 = bussola._no_quadro(aqui + Vector3(8.0, 0.0, 0.0), meio, escala)
	_conferir(leste.x > meio.x + 1.0,
		"o alvo está a leste e o losango saiu em %s, com o centro em %s" % [str(leste), str(meio)])

	# --- 5. ALVO LONGE ENCOSTA NO ARO, DENTRO DO CÍRCULO --------------------
	var longe: Vector2 = bussola._no_quadro(aqui + Vector3(4000.0, 0.0, 4000.0), meio, escala)
	var raio_da_vista: float = minf(bussola._sobre.size.x, bussola._sobre.size.y) * 0.5
	var distancia: float = (longe - meio).length()
	_conferir(distancia <= raio_da_vista - 1.0,
		"o alvo longe foi para %.1f do centro, e o aro está a %.1f: cairia na quina que a máscara apaga"
			% [distancia, raio_da_vista])
	_conferir(distancia > raio_da_vista * 0.5,
		"o alvo longe ficou a %.1f do centro: ele tem de ENCOSTAR no aro para dar a direção"
			% distancia)
	print("  alvo longe: a %.1f do centro, aro em %.1f" % [distancia, raio_da_vista])

	# --- 6. O LOSANGO SEGUE O FOCO ------------------------------------------
	#
	# Duas missões abertas, a segunda a OESTE. Fixar a segunda tem de virar o
	# marcador para o outro lado; se ele seguisse quem falou por último, ficaria
	# onde estava.
	caderno.abrir_missao("outra_do_minimapa", "Outro passo", "damiao", false)
	caderno.apontar("outra_do_minimapa", aqui + Vector3(-8.0, 0.0, 0.0))
	caderno.fixar("outra_do_minimapa")
	await _frames(4)
	_conferir(bussola._tem_alvo, "com a outra missão em foco a bússola parou de apontar")
	var oeste: Vector2 = bussola._no_quadro(bussola._alvo, meio, escala)
	_conferir(oeste.x < meio.x - 1.0,
		"fixei a missão a oeste e o losango continuou em %s, com o centro em %s"
			% [str(oeste), str(meio)])

	# --- 7. MISSÃO CUMPRIDA LIMPA O ALVO ------------------------------------
	caderno.concluir("outra_do_minimapa")
	caderno.concluir("perto_do_minimapa")
	await _frames(4)
	_conferir(not bussola._tem_alvo,
		"cumpri as duas missões e a bússola continuou apontando o lugar de uma delas")

	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("MINIMAPA_OK: a bússola está no HUD, é quadrada e cabe na janela; a vista tem máscara redonda e o aro fecha o círculo; sem missão em foco não aponta nada; com missão em foco o losango cai do lado certo; alvo longe encosta no aro e fica dentro do círculo em vez da quina; fixar outra missão vira o marcador; e missão cumprida limpa o alvo")
	else:
		print("minimapa: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


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
