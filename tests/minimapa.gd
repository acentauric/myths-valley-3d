extends "res://tests/suite/caso.gd"
## Confere A BÚSSOLA DO CANTO: redonda, e apontando a missão em foco.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste minimapa
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
## DESDE QUE O MINIMAPA VIROU FOTO (desempenho de 05/10): ele não desenha mais o vale
## numa segunda câmera. A vista é uma textura recortada por shader, e o que segue o
## jogador é o centro dela. As perguntas 2 e 8 cobram isso.
##
## Oito perguntas:
##
##   1. A BÚSSOLA ESTÁ NO HUD, quadrada, e dentro da janela.
##   2. ELA É REDONDA: a vista (um retângulo com shader, sem SubViewport) tem
##      máscara, e o aro tem raio de meio lado.
##   3. SEM MISSÃO EM FOCO, não há losango de alvo.
##   4. COM MISSÃO EM FOCO, há losango, e ele cai do lado certo do jogador.
##   5. ALVO LONGE ENCOSTA NO ARO, e fica DENTRO do círculo — não na quina.
##   6. O LOSANGO SEGUE O FOCO: fixar a outra missão muda o lado para onde ele
##      aponta. É o que separa "aponta a missão" de "aponta quem falou".
##   7. MISSÃO CUMPRIDA LIMPA O ALVO: bússola que aponta o que já foi feito
##      manda o jogador andar à toa.
##   8. SEM SEGUNDO RENDER, E A FOTO SEGUE O JOGADOR: o minimapa não cria
##      SubViewport, e o centro da textura acompanha onde o jogador está.

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
	var vista: ColorRect = null
	for no in bussola.find_children("*", "ColorRect", true, false):
		vista = no as ColorRect
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

	# --- 8. SEM SEGUNDO RENDER, E A FOTO SEGUE O JOGADOR ---------------------
	#
	# O custo que a foto tirou foi o de um SubViewport no mesmo mundo, desenhando o
	# vale de novo todo quadro. Se alguém trouxer um de volta, este portão acusa.
	_conferir(bussola.find_children("*", "SubViewport", true, false).is_empty(),
		"o minimapa criou um SubViewport: o vale voltaria a ser desenhado duas vezes por quadro")
	_conferir(not bussola._sem_mapa,
		"o minimapa não achou a foto do mapa (rode tools/prototipo_3d/capturar_minimapa.gd)")
	if not bussola._sem_mapa:
		var antes: Vector2 = bussola._material.get_shader_parameter("centro_uv")
		var ponto: Vector3 = jogador.global_position
		_conferir(antes.is_equal_approx(bussola.centro_da_vista(ponto)),
			"o centro da textura está em %s e o jogador em %s deveria dar %s"
				% [str(antes), str(ponto), str(bussola.centro_da_vista(ponto))])
		# Um passo de 20 u a leste: o centro anda a leste na foto (u maior), e v não muda.
		jogador.global_position = ponto + Vector3(20.0, 0.0, 0.0)
		await _frames(4)
		var depois: Vector2 = bussola._material.get_shader_parameter("centro_uv")
		_conferir(bussola.visible, "o minimapa está escondido com a câmera do jogador ativa")
		_conferir(depois.x > antes.x + 0.001 and absf(depois.y - antes.y) < 0.001,
			"o jogador andou 20 u a leste e o centro foi de %s para %s" % [str(antes), str(depois)])
		jogador.global_position = ponto

	# --- 9. O MARCADOR DO JOGADOR SE LÊ DE RELANCE (#200) --------------------
	#
	# Era um triângulo de 9 de ponta, sem contorno, da cor da areia e do losango da
	# missão. Agora é uma seta maior (40 a 60% acima), com entalhe na base, contorno
	# escuro e halo, e o alvo tem forma e contorno próprios.
	for direcao in [Vector2(0, 1), Vector2(1, 0), Vector2(-0.6, 0.8)]:
		var seta: PackedVector2Array = bussola.pontos_do_jogador(Vector2.ZERO, direcao)
		_conferir(seta.size() == 4, "a seta do jogador tem %d pontos: sem o entalhe da base" % seta.size())
		if seta.size() == 4:
			_conferir(seta[0].length() >= 9.0 * 1.4 and seta[0].length() <= 9.0 * 1.6 + 2.0,
				"a ponta da seta mede %.1f: deveria ser 40 a 60%% maior que os 9 de antes" % seta[0].length())
			_conferir(seta[0].normalized().is_equal_approx(direcao.normalized()),
				"a ponta da seta não aponta para onde o jogador olha")
			# O entalhe fica atrás da ponta e na frente da linha das asas.
			var base: Vector2 = (seta[1] + seta[3]) * 0.5
			_conferir(seta[2].dot(direcao) > base.dot(direcao) and seta[2].dot(direcao) < 0.0,
				"a base da seta não tem entalhe (chevron)")
	_conferir(bussola.CONTORNO.v < 0.2 and bussola.CONTORNO.a >= 0.9 and bussola.LARGURA_CONTORNO >= 1.5 and bussola.LARGURA_CONTORNO <= 2.0,
		"o contorno da seta não é escuro e de 1,5 a 2 px")
	_conferir(bussola.HALO.a > 0.0 and bussola.RAIO_HALO >= bussola.PONTA_JOGADOR - 2.0,
		"a seta não tem halo por baixo")
	_conferir(bussola.JOGADOR.v > bussola.AMBAR.v and bussola.JOGADOR.s < bussola.AMBAR.s,
		"o jogador não é mais claro e menos saturado que o âmbar do alvo")

	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("MINIMAPA_OK: a seta do jogador é maior, com entalhe, contorno e halo; a bússola está no HUD, é quadrada e cabe na janela; a vista (textura com shader, sem SubViewport) tem máscara redonda e o aro fecha o círculo; sem missão em foco não aponta nada; com missão em foco o losango cai do lado certo; alvo longe encosta no aro e fica dentro do círculo em vez da quina; fixar outra missão vira o marcador; missão cumprida limpa o alvo; e o centro da foto acompanha o jogador sem segundo render")
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
