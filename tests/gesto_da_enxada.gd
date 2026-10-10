extends "res://tests/suite/caso.gd"
## A terra muda no contato da enxada, não no começo do E (#145).
var falhas := 0
const TROCA_DE_POSE_S := 0.1
var efeitos := 0

func _initialize() -> void:
	_run.call_deferred()
	create_timer(40).timeout.connect(func(): quit(2))

func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: " + texto)

func terminar(animador: Node) -> void:
	while animador.chop_ativo():
		await process_frame
		if not animador.chop_ativo():
			break
	animador.update_motion(0, 0.016)
	await create_timer(0.3).timeout

func _run() -> void:
	await process_frame
	var T = load("res://tests/itens_na_mao.gd")
	var jogador: Node3D = await T.montar_jogador(self)
	var peca: Node3D = await T.por_na_mao(self, jogador, "enxada")
	var lav = load("res://scripts/prototipo_3d/lavoura_vale.gd").new()
	lav._jogador = jogador
	lav._textos = JSON.parse_string(FileAccess.get_file_as_string(lav.TEXTOS))
	lav.plantacao = load("res://scripts/prototipo_3d/plantacao.gd").new(func(_p): return true)
	root.add_child(lav)
	lav.arou.connect(func(): efeitos += 1)
	var energia := root.get_node("Energia")
	energia.definir(100)
	var animador: Node = jogador.get("animator")
	var player: AnimationPlayer = animador.get("animation_player")
	# A 60 quadros por segundo, como no jogo: o headless solto passa de 500 e amostra
	# poses da mistura que ninguém vê; o primeiro quadro lento de um Godot recém-aberto
	# as escondia, e o portão dependia de ser o primeiro a rodar.
	Engine.max_fps = 60
	var cell := Vector2i(2, 1)
	jogador.global_position = lav.posicao_da(cell) - Vector3.BACK * 0.8
	var antes: float = energia.atual
	conferir(lav._gesto_no_leito(cell), "E inicia o trabalho animado")
	conferir(not lav.plantacao.arado(cell) and energia.atual == antes, "início não ara nem cobra")
	conferir(player.speed_scale <= 1.15, "golpe pode ser acompanhado")
	var clipe := player.get_animation(player.current_animation)
	var medidas := 0
	var maior_intrusao := 0.0
	var menor_altura := INF
	var contato := false
	while animador.chop_ativo():
		await process_frame
		if not animador.chop_ativo():
			break
		var fase := player.current_animation_position / clipe.length
		if fase < 0.40:
			conferir(not lav.plantacao.arado(cell), "preparação não produz efeito")
		if fase > 0.2 and fase < 0.3:
			conferir(lav._gesto_no_leito(cell), "E repetido mantém o trabalho")
		var m: Dictionary = T.medir(jogador, peca)
		# Os primeiros 0,1 s do clipe são a troca de pose: a ferramenta segue a mão
		# com um quadro de atraso, e por um ou dois quadros o cabo mede dentro do
		# corpo. O portão antigo os pulava por acaso (o primeiro quadro de um Godot
		# recém-aberto é lento); agora pula de propósito, e mede o golpe.
		if player.current_animation_position < TROCA_DE_POSE_S:
			medidas += 1
			continue
		if m.corpo > maior_intrusao:
			maior_intrusao = m.corpo
			if maior_intrusao > 10:
				print("ENXADA_INTRUSAO: fase %.3f, %.1f%%" % [fase, maior_intrusao])
		menor_altura = minf(menor_altura, m.baixo.y)
		conferir(m.palma <= 0.045, "pegada continua na palma durante o ciclo")
		if fase >= 0.45 and not contato:
			contato = true
			print("ENXADA_CONTATO: fase %.3f, %s" % [fase, T.descrever(m)])
			conferir(lav.plantacao.arado(cell), "impacto ara o leito")
			conferir(m.baixo.y <= 0.16 and m.baixo.y >= -0.12, "lâmina toca o chão no impacto")
		medidas += 1
	conferir(contato and medidas > 15, "ciclo real foi acompanhado")
	conferir(maior_intrusao < 10.0 and menor_altura > -0.12, "cabo não atravessa corpo nem enterra na preparação e retorno")
	conferir(efeitos == 1 and is_equal_approx(energia.atual, antes - energia.custo("arar")), "um golpe cobra e avança uma vez")
	print("ENXADA_MEDIDA: %d quadros, intrusão máxima %.1f%%, mínimo %.3fm" % [medidas, maior_intrusao, menor_altura])
	await terminar(animador)
	# Segundo leito: cancelar antes do contato não deixa um golpe pendente.
	cell = Vector2i(3, 1)
	jogador.global_position = lav.posicao_da(cell) - Vector3.BACK * 0.8
	antes = energia.atual
	conferir(lav._gesto_no_leito(cell), "segundo trabalho inicia")
	await create_timer(0.1).timeout
	animador.stop_chop()
	await terminar(animador)
	animador.play_chop(1) # Outro trabalho não aplica a antiga leira.
	await terminar(animador)
	conferir(not lav.plantacao.arado(cell) and energia.atual == antes, "cancelamento preserva leito e energia")
	conferir(lav._gesto_no_leito(cell), "pode tentar novamente depois de cancelar")
	await terminar(animador)
	conferir(lav.plantacao.arado(cell) and efeitos == 2, "novo golpe conclui normalmente")
	conferir(not lav._gesto_no_leito(cell), "leito arado não reproduz golpe inútil")
	energia.definir(0)
	conferir(not lav._gesto_no_leito(Vector2i(4, 1)), "sem energia não simula trabalho")
	lav.free()
	Engine.max_fps = 0
	print("GESTO_DA_ENXADA: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
