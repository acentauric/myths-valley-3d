extends "res://tests/suite/caso.gd"
## #196: o chevron da missão ORBITA o jogador em vez de grudar na borda da tela.
##
## Fora da visão ele fica numa elipse ao redor do personagem na tela (raio de 18 a 25% da
## altura), apontando o rumo do alvo; se o ponto da órbita cair sobre um painel do HUD
## (grupo `obstaculos_do_hud`), desliza pela elipse ou diminui o raio até sair. O portão
## monta uma cena mínima (jogador, câmera, seta e um painel falso do HUD) e conduz o
## `_atualizar_chevron` quadro a quadro, sem esperar tempo real.
var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func conferir(ok: bool, motivo: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: " + motivo)


func _run() -> void:
	await process_frame
	var Seta = load("res://scripts/prototipo_3d/seta_missao.gd")
	var tela: Vector2 = root.get_visible_rect().size

	# --- 1. A CONTA, SEM CENA: a órbita, o deslize e o raio --------------------------
	var centro := tela * 0.5
	var area := Rect2(Vector2.ZERO, tela).grow(-Seta.MARGEM_TELA)
	var raio := Vector2(tela.y * 0.2 * Seta.ACHATAMENTO, tela.y * 0.2)
	var livres: Array[Rect2] = []
	var nominal: Vector2 = Seta.lugar_livre(centro, Vector2(1, 0), raio, livres, area)
	conferir(nominal.is_equal_approx(centro + Vector2(raio.x, 0)), "sem painel o chevron fica na elipse, rumo ao alvo: %s" % str(nominal))
	var coberto: Array[Rect2] = [Rect2(nominal - Vector2(60, 60), Vector2(120, 120))]
	var desviado: Vector2 = Seta.lugar_livre(centro, Vector2(1, 0), raio, coberto, area)
	conferir(not Seta._cobre(desviado, coberto), "o chevron ficou sobre o painel do HUD: %s" % str(desviado))
	conferir(desviado.distance_to(centro) <= raio.x + 1.0, "o chevron fugiu do painel para longe do jogador: %s" % str(desviado))
	conferir(desviado != nominal, "o painel não tirou o chevron do lugar")
	# Com a tela inteira coberta não há lugar livre: devolve INF (o chevron se apaga, não vai sobre o painel).
	var tudo: Array[Rect2] = [Rect2(Vector2.ZERO, tela)]
	conferir(not Seta.lugar_livre(centro, Vector2(1, 0), raio, tudo, area).is_finite(), "sem lugar livre o chevron devia pedir para apagar")
	# O retângulo de um painel ampliado pelo componente de Ajustes (pivô + scale) vale o tamanho ampliado.
	var PopupsDoMundo = load("res://scripts/prototipo_3d/popups_do_mundo.gd")
	var ampliado := Control.new()
	root.add_child(ampliado)
	ampliado.position = Vector2(100, 100)
	ampliado.size = Vector2(200, 100)
	ampliado.pivot_offset = Vector2.ZERO
	ampliado.scale = Vector2(1.5, 1.5)
	var medido: Rect2 = PopupsDoMundo.retangulo_na_tela(ampliado)
	conferir(medido.is_equal_approx(Rect2(100, 100, 300, 150)), "o painel ampliado devia medir 300x150, mediu %s" % str(medido))
	ampliado.add_to_group("obstaculos_do_hud")
	var vistos: Array[Rect2] = PopupsDoMundo.retangulos(root, "obstaculos_do_hud")
	conferir(vistos.has(medido), "os painéis do HUD não trazem o retângulo ampliado")
	ampliado.queue_free()
	# O raio proporcional à janela e ao tamanho do HUD.
	var seta_solta = Seta.new()
	root.add_child(seta_solta)
	for janela in [Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440)]:
		var r: Vector2 = seta_solta._raio_da_orbita(janela)
		conferir(r.y >= janela.y * Seta.FRACAO_MINIMA - 0.01 and r.y <= janela.y * Seta.FRACAO_MAXIMA + 0.01, "raio de %.0f px fora de 18 a 25%% da altura de %s" % [r.y, str(janela)])
		conferir(is_equal_approx(r.x, r.y * Seta.ACHATAMENTO), "a órbita não é uma elipse achatada")
	var r_pequeno: Vector2 = seta_solta._raio_da_orbita(Vector2(1280, 720))
	var r_grande: Vector2 = seta_solta._raio_da_orbita(Vector2(2560, 1440))
	conferir(r_grande.y > r_pequeno.y * 1.9, "o raio não cresce com a janela (%.0f e %.0f)" % [r_pequeno.y, r_grande.y])
	seta_solta.queue_free()

	# --- 2. A CENA: alvo fora da vista, com e sem painel no caminho -------------------
	var cena := Node3D.new()
	root.add_child(cena)
	var jogador := Node3D.new()
	cena.add_child(jogador)
	jogador.add_to_group("map_player")
	var camera := Camera3D.new()
	cena.add_child(camera)
	camera.position = Vector3(0, 8, 10)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var camada := Control.new()
	root.add_child(camada)
	var seta = Seta.new()
	cena.add_child(seta)
	seta.configurar(camada)
	seta.definir_alvo(Vector3(60, 0, 0), "")
	await process_frame
	for i in 80:
		seta._atualizar_chevron(0.1)
	var chevron: Control = seta._chevron
	conferir(chevron.visible and chevron.modulate.a > 0.99, "o chevron de um alvo fora da vista não acendeu")
	var peito: Vector2 = camera.unproject_position(jogador.global_position + Vector3.UP)
	var raios: Vector2 = seta._raio_da_orbita(tela)
	var onde: Vector2 = chevron.position + chevron.pivot_offset
	var fora_da_borda := Rect2(Vector2.ZERO, tela).grow(-Seta.MARGEM_TELA).has_point(onde)
	conferir(fora_da_borda, "o chevron saiu da área útil da tela: %s" % str(onde))
	var na_elipse := Vector2((onde.x - peito.x) / raios.x, (onde.y - peito.y) / raios.y).length()
	conferir(na_elipse > 0.35 and na_elipse < 1.05, "o chevron não orbita o jogador: %.2f da elipse, em %s (jogador em %s)" % [na_elipse, str(onde), str(peito)])
	conferir(onde.x > peito.x, "o alvo está à direita e o chevron ficou do outro lado do jogador")
	conferir(cos(chevron.rotation) > 0.8, "o chevron não aponta para o alvo à direita: giro de %.2f rad" % chevron.rotation)
	conferir(onde.distance_to(Vector2(tela.x, tela.y * 0.5)) > Seta.MARGEM_TELA * 2.0, "o chevron ainda gruda na borda direita da tela")

	# Um painel do HUD exatamente onde o chevron está: ele sai de baixo.
	var painel := Control.new()
	painel.add_to_group("obstaculos_do_hud")
	root.add_child(painel)
	painel.position = onde - Vector2(90, 90)
	painel.size = Vector2(180, 180)
	for i in 80:
		seta._atualizar_chevron(0.1)
	var depois: Vector2 = chevron.position + chevron.pivot_offset
	conferir(not painel.get_global_rect().intersects(Rect2(depois - Vector2(14, 14), Vector2(28, 28))), "o chevron ficou sobre o painel do HUD: %s em %s" % [str(depois), str(painel.get_global_rect())])
	conferir(depois.distance_to(peito) <= raios.x + 2.0, "o chevron fugiu do painel para longe do jogador: %s" % str(depois))
	conferir(chevron.visible and chevron.modulate.a > 0.99, "o chevron sumiu em vez de desviar do painel")

	# A NARRAÇÃO MANDA (#106): a caixa longa do Dialogo é painel de que o chevron também foge.
	painel.queue_free()
	var dialogo := root.get_node_or_null("Dialogo")
	if dialogo != null:
		dialogo.transform = Transform2D.IDENTITY
		dialogo.falar("Pedro", ["Uma fala longa de narração para a caixa abrir."])
		await process_frame
		await process_frame
		var caixa: Rect2 = dialogo.retangulo_da_caixa()
		conferir(caixa.has_area(), "a caixa da narração aberta devia ter retângulo")
		# A caixa vai exatamente para onde o chevron estava.
		var meio: Vector2 = chevron.position + chevron.pivot_offset
		dialogo._painel.global_position += meio - caixa.get_center()
		caixa = dialogo.retangulo_da_caixa()
		conferir(caixa.has_point(meio), "o portão não conseguiu pôr a caixa sob o chevron (caixa %s, chevron %s)" % [str(caixa), str(meio)])
		for i in 80:
			seta._atualizar_chevron(0.1)
		var sob_a_caixa: Vector2 = chevron.position + chevron.pivot_offset
		conferir(not caixa.intersects(Rect2(sob_a_caixa - Vector2(14, 14), Vector2(28, 28))), "o chevron ficou sobre a caixa da narração: %s em %s" % [str(sob_a_caixa), str(caixa)])
		conferir(chevron.visible and chevron.modulate.a > 0.99, "o chevron sumiu em vez de desviar da caixa da narração")
		dialogo.calar()
		await process_frame
		await process_frame

	# O alvo volta à vista e perto: o chevron apaga (o cone sobre o alvo basta).
	seta.definir_alvo(Vector3(2, 0, 0), "")
	for i in 40:
		seta._atualizar_chevron(0.1)
	conferir(not chevron.visible, "com o alvo à vista e perto o chevron devia apagar")

	cena.queue_free()
	camada.queue_free()
	await process_frame
	print("SETA_EM_ORBITA: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
