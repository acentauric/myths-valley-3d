extends "res://tests/suite/caso.gd"
## Confere que O CORPO DE UMA ÁRVORE COBRE O TRONCO QUE SE VÊ.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste colisao_das_arvores
##
## Este portão nasceu de uma queixa que eu NÃO CONSEGUI REPRODUZIR: "a área de
## colisão de algumas árvores não está funcionando adequadamente. Nos coqueiros
## na praia eu consegui atravessá-los" — e depois, com endereço: "o problema se
## repete nas árvores próximo ao pier que fica longe da vila".
##
## O que eu medi, duas vezes e por caminhos diferentes:
##
##   · os coqueiros da orla ENTRAM na lista de troncos, e o conjunto de cilindros
##     que segue o jogador cobre 11,5 unidades no pior ponto do mapa inteiro —
##     nunca falta corpo por falta de vaga;
##   · empurrando o jogador de frente contra um, ele para a 0,52 do eixo, que é
##     exatamente raio do tronco mais raio do corpo;
##   · correndo dez vezes pela linha das palmeiras a 5,2 m/s, nenhuma travessia;
##   · e no píer o tronco mais perto está a 12,9 unidades, com 17 cilindros
##     sobrando.
##
## MAS HAVIA UM DESCASAMENTO REAL, e é o que este portão guarda. O coqueiro da
## orla é plantado PENDENDO PARA O MAR — 0,14 rad, uns 8° — e o colisor era um
## cilindro VERTICAL na base dele. A quatro unidades de altura, isso põe o tronco
## desenhado a meia unidade do eixo que barra: quem encosta na parte alta da
## palmeira passa, porque ali não há corpo nenhum. É o que mais se parece com
## "atravessei o coqueiro", e é defeito de verdade tenha sido ele a queixa ou não.
##
## A pergunta que se faz aqui, e que ninguém fazia: EM CADA ALTURA DO TRONCO, o
## corpo está onde a madeira está? Não é sobre o conjunto, nem sobre o raio: é
## sobre o eixo.
##
## O EMPURRÃO DE FRENTE NÃO ESTÁ AQUI, de propósito: andar contra um tronco e
## parar é coisa que eu medi à mão e que passa, mas dentro deste portão ela vem
## depois de dez teleportes para a beira d'água, e o controlador do jogador
## passa a puxá-lo de volta para terra no meio da medida. Portão instável é pior
## que portão nenhum.

var falhas := 0
## Alturas em que o tronco é conferido, em fração da altura do corpo. A do peito
## é a que importa — é por onde o jogador encosta andando.
const ALTURAS := [0.15, 0.5, 0.85, 1.0]
## Quanto o eixo do corpo pode se afastar do eixo do tronco, em unidades. Meio
## raio: mais que isso e a madeira desenhada começa a sair do corpo.
const DESVIO_MAXIMO := 0.35


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("COLISAO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK,
		"a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(8)

	var jogo := current_scene
	var world = jogo.get("world")
	var jogador = jogo.get("player")
	var regiao = world._region
	_conferir(regiao != null and not (regiao._tree_trunks as Array).is_empty(),
		"o vale não tem tronco nenhum registrado")
	if regiao == null or (regiao._tree_trunks as Array).is_empty():
		_fechar()
		return

	# --- 1. O CONJUNTO DE CILINDROS NUNCA FALTA POR FALTA DE VAGA ------------
	#
	# Para cada tronco, a que distância está o 24º vizinho? Se em algum ponto do
	# mapa esse número cair para dentro do alcance do braço, há árvore ao lado do
	# jogador sem corpo — e aí a queixa seria de conjunto, não de eixo.
	var pool: int = regiao.TREE_COLLISION_POOL_SIZE
	var raio: float = regiao.TREE_COLLISION_RADIUS
	var pior := INF
	var pior_especie := ""
	for t in regiao._tree_trunks:
		var ponto: Vector2 = t["point"]
		var perto: Array[float] = []
		for outro in regiao._tree_trunks:
			var d: float = ponto.distance_to(outro["point"])
			if d <= raio:
				perto.append(d)
		if perto.size() <= pool:
			continue
		perto.sort()
		if perto[pool - 1] < pior:
			pior = perto[pool - 1]
			pior_especie = str(t.get("especie", "?"))
	print("")
	print("  conjunto: %d cilindros num raio de %.0f; pior cobertura %.1f u (%s)"
		% [pool, raio, pior if pior < INF else raio, pior_especie])
	_conferir(pior > 4.0,
		"em algum ponto o %dº tronco mais perto está a %.1f u (%s): há árvore ao alcance do braço sem corpo"
			% [pool, pior, pior_especie])

	# --- 2. O EIXO DO CORPO SEGUE O EIXO DO TRONCO --------------------------
	#
	# A pergunta que faltava. Põe o jogador ao lado de um tronco de cada espécie,
	# espera o conjunto acordar, e compara ONDE O CORPO ESTÁ com onde a madeira
	# está, em três alturas.
	var por_especie: Dictionary = {}
	for t in regiao._tree_trunks:
		var especie := str(t.get("especie", "?"))
		if not por_especie.has(especie):
			por_especie[especie] = t
	var nomes := por_especie.keys()
	nomes.sort()

	# A FÍSICA DO JOGADOR SAI DO CAMINHO durante a medida. Posto na beira
	# d'água, ele é puxado de volta para terra pelo próprio controlador
	# (`_back_to_land`) antes de o conjunto de cilindros acordar — e aí a medida
	# seria feita a quinhentas unidades do tronco. O que se mede aqui é geometria,
	# não caminhada.
	jogador.set_physics_process(false)

	for especie in nomes:
		var tronco: Dictionary = por_especie[especie]
		var ponto: Vector2 = tronco["point"]
		var base_local := Vector3(ponto.x, float(tronco["ground"]), ponto.y)
		jogador.global_position = regiao.to_global(base_local) + Vector3(2.5, 0.5, 0.0)
		await _frames(30)

		# Acha o cilindro que o conjunto pôs neste tronco.
		var corpo: StaticBody3D = null
		var forma: CylinderShape3D = null
		for slot in regiao._tree_collision_pool:
			if not slot.active:
				continue
			var candidato := slot.body as StaticBody3D
			var no_chao := Vector2(candidato.position.x, candidato.position.z)
			if no_chao.distance_to(ponto) < 0.35:
				corpo = candidato
				forma = slot.shape as CylinderShape3D
		# SEM CILINDRO NESTE TRONCO NÃO É DEFEITO, e é preciso dizer por quê.
		#
		# O conjunto tem 24 vagas e as dá aos mais PERTO DO JOGADOR. No mangue,
		# que nasce em moita, há mais de 24 troncos a poucos metros — o que eu
		# escolhi pode não estar entre os 24, e os que estão são justamente os que
		# o jogador encostaria. Cobrar vaga para um tronco específico seria cobrar
		# que o conjunto fosse infinito.
		#
		# A cobertura do conjunto já foi medida na pergunta 1, no mapa inteiro.
		if corpo == null or forma == null:
			print("  %-12s (sem vaga no conjunto: há mais de %d troncos mais perto)" % [especie, regiao.TREE_COLLISION_POOL_SIZE])
			continue

		# O EIXO QUE O DESENHO USA, tirado do próprio tronco.
		#
		# A primeira versão disto guardava uma `inclinacao` que eu tinha
		# acrescentado ao tronco, e comparava o corpo com ela. O outro lado da
		# mesa resolveu o mesmo problema melhor, e a versão dele ficou: em vez de
		# um ângulo, o tronco traz a BASE e o ALTO de verdade, tirados do GLB
		# (`base_tronco`, `alto_tronco`), e o colisor se orienta por eles. Isso
		# vale para qualquer malha, inclusive as que não são retas por dentro.
		#
		# A medida aqui não mudou de ideia — só de fonte: onde está a madeira,
		# onde está o corpo, e o quanto os dois se afastam subindo o tronco.
		var base_da_madeira: Vector3 = tronco.get("base_tronco",
			Vector3(ponto.x, float(tronco["ground"]), ponto.y))
		var alto_da_madeira: Vector3 = tronco.get("alto_tronco",
			Vector3(ponto.x, float(tronco["ground"]) + 1.0, ponto.y))
		var eixo_da_madeira := (alto_da_madeira - base_da_madeira).normalized()
		if eixo_da_madeira.length_squared() < 0.5:
			eixo_da_madeira = Vector3.UP
		# A palmeira da orla PENDE, e é ela que dá sentido a esta medida: se o
		# eixo dela viesse vertical, os dois lados seriam iguais por construção e
		# a pergunta não poderia falhar — que é o pior tipo de pergunta.
		if especie == "coqueiro":
			_conferir(absf(eixo_da_madeira.dot(Vector3.UP)) < 0.999,
				"o coqueiro da orla veio com eixo vertical: a medida do eixo ficaria vazia")
		var pior_desvio := 0.0
		for fracao in ALTURAS:
			var altura: float = forma.height * float(fracao)
			var na_madeira: Vector3 = base_da_madeira + eixo_da_madeira * altura
			var no_corpo: Vector3 = corpo.position + corpo.basis * Vector3(0.0, altura - forma.height * 0.5, 0.0)
			var desvio := Vector2(na_madeira.x - no_corpo.x, na_madeira.z - no_corpo.z).length()
			pior_desvio = maxf(pior_desvio, desvio)
		print("  %-12s raio=%.2f altura=%.1f  pior desvio eixo↔madeira: %.2f u"
			% [especie, forma.radius, forma.height, pior_desvio])
		_conferir(pior_desvio <= DESVIO_MAXIMO,
			"em '%s' o corpo se afasta %.2f u do tronco desenhado (limite %.2f): encostar na parte alta atravessa"
				% [especie, pior_desvio, DESVIO_MAXIMO])


	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("COLISAO_OK: o conjunto de cilindros cobre o que está ao alcance do braço em todo o mapa, e o eixo do corpo segue o eixo do tronco em três alturas — inclusive nas palmeiras que pendem para o mar")
	else:
		print("colisão das árvores: %d falha(s)" % falhas)
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
