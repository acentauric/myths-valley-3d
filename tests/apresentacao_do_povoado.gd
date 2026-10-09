extends SceneTree
## Presença gradual, processamento suspenso e disponibilidade das missões (#155).
var falhas := 0
func _initialize() -> void:
	_run.call_deferred()
	create_timer(180).timeout.connect(func(): quit(2))
func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: " + texto)
func _run() -> void:
	await process_frame
	root.get_node("Estilo").modo = "tripo"
	change_scene_to_file("res://scenes/prototipo_3d/vale.tscn")
	await process_frame
	while current_scene == null or current_scene.get("carga_ok") != true:
		await process_frame
	var vale := current_scene
	var diretor: Node = vale.apresentacao_do_povoado
	diretor.set_process(false)
	root.get_node("Dia").definir_hora(7.9)
	root.get_node("Dia").pausado = true
	vale.player.global_position = vale._achar_morador("candinha").global_position + Vector3(0, 0, 3)
	vale.player.set_physics_process(false)
	vale.pedro.missao = 4
	# Recomeça a apresentação na praça, sem contar os figurantes vistos no píer.
	diretor._vistos.clear()
	diretor.segundos = 0
	diretor.atualizar()
	var visitante: Node3D = vale.saveiro.comprador
	if "--visita-forcada" in OS.get_cmdline_user_args():
		visitante.set_meta("presenca_do_calendario", true)
		diretor.atualizar()
	conferir(not visitante.visible, "apresentação respeita ausência do mestre fora do dia")
	var sem := "--sem-orcamento" in OS.get_cmdline_user_args()
	if sem:
		diretor.liberar_todos()
	for _i in 4:
		await process_frame
	var inicial: Dictionary = diretor.contagem()
	print("POPULACAO_INICIAL: " + JSON.stringify(inicial))
	conferir(int(inicial.moradores.ativos) <= 6, "chegada: quatro essenciais e até dois outros moradores")
	# A introdução (#155, reaberta): no passo 4 nenhum bicho entra perto de quem chega, e só um aparece.
	conferir(int(inicial.bichos_de_casa.ativos) <= 1, "chegada: no máximo um quadrúpede, longe do caminho")
	_longe_de_quem_chega(vale, "bichos_de_casa", "quadrúpede")
	_longe_de_quem_chega(vale, "bandos_de_chao", "bando")
	conferir(int(inicial.bandos_de_chao.ativos) <= 1, "chegada: até um bando")
	# O bando de aves é medido pelo terreiro, e não pelo nó parado na origem (#193).
	for bando in get_nodes_in_group("bandos_de_chao"):
		conferir(diretor.onde_esta(bando).is_equal_approx(bando.centro), "o bando da %s é medido pelo centro do terreiro" % bando.casa)
		conferir(not diretor.onde_esta(bando).is_equal_approx(bando.global_position), "o bando da %s não é medido pelo nó parado na origem" % bando.casa)
		conferir(diretor.alcance_do_ator(bando) >= float(bando.raio) + 6.0, "o bando da %s sai de cena só depois de o terreiro inteiro passar do fade" % bando.casa)
	for id in ["pedro", "tonho", "candinha", "zefa"]:
		var ator: Node = vale.pedro if id == "pedro" else vale._achar_morador(id)
		conferir(ator.is_physics_processing(), "essencial disponível: " + id)
	for ator in get_nodes_in_group("moradores"):
		if not ator.get_meta("presenca_liberada", true):
			conferir(not ator.visible and not ator.is_physics_processing(), "oculto sem movimento")
			conferir(ator.visual.process_mode == Node.PROCESS_MODE_DISABLED, "rig oculto sem atualização")
			conferir(ator.collision_layer == 0, "corpo oculto não bloqueia")
			for filho in ator.get_children():
				if filho.get_script() == load("res://scripts/prototipo_3d/cadeia_de_missoes.gd"):
					conferir(filho.process_mode != Node.PROCESS_MODE_DISABLED, "missão continua disponível")
	if "--medir" in OS.get_cmdline_user_args():
		print("CONDICOES_POPULACAO: processador=%s video=%s viewport=%s render=%s" % [OS.get_processor_name(), RenderingServer.get_video_adapter_name(), root.size, ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus")])
		var camera := Camera3D.new()
		vale.add_child(camera)
		camera.global_position = vale.player.global_position + Vector3(0, 5, 10)
		camera.look_at(vale.player.global_position + Vector3.UP)
		camera.make_current()
		await create_timer(5).timeout
		var amostras: Array[float] = []
		var ate := Time.get_ticks_msec() + 15000
		var anterior := Time.get_ticks_usec()
		while Time.get_ticks_msec() < ate:
			await process_frame
			var agora := Time.get_ticks_usec()
			amostras.append(float(agora - anterior) / 1000.0)
			anterior = agora
		amostras.sort()
		var media := 0.0
		for ms in amostras:
			media += ms
		media /= amostras.size()
		print("MEDIDA_POPULACAO: sem_orcamento=%s quadros=%d fps=%.2f mediana_ms=%.2f p95_ms=%.2f" % [sem, amostras.size(), 1000.0 / media, amostras[amostras.size()/2], amostras[int(amostras.size()*0.95)]])
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://scratch/populacao")
		root.get_texture().get_image().save_png("res://scratch/populacao/%s.png" % ("antes" if sem else "depois"))
		quit(0)
		return
	# Durante a introdução o tempo não amplia os bichos nem os bandos (#155, reaberta em 09/10)...
	diretor.segundos = 90
	diretor.atualizar()
	var depois: Dictionary = diretor.contagem()
	conferir(int(depois.bichos_de_casa.ativos) <= 1, "durante a introdução o tempo não amplia os quadrúpedes (%d em cena)" % int(depois.bichos_de_casa.ativos))
	conferir(int(depois.bandos_de_chao.ativos) <= 1, "durante a introdução o tempo não amplia os bandos (%d em cena)" % int(depois.bandos_de_chao.ativos))
	_longe_de_quem_chega(vale, "bichos_de_casa", "quadrúpede")
	_longe_de_quem_chega(vale, "bandos_de_chao", "bando")
	conferir(diretor.em_introducao(), "com o Pedro no passo 5 ainda é a introdução")
	# ...e terminada a entrada na casa do tio eles entram AOS POUCOS, e não de uma vez.
	vale.pedro.missao = 6
	diretor.atualizar()
	conferir(not diretor.em_introducao(), "depois da entrada na casa a introdução acabou")
	var ao_acabar: Dictionary = diretor.contagem()
	conferir(int(ao_acabar.bichos_de_casa.ativos) <= 2, "ao acabar a introdução entram só dois quadrúpedes (%d em cena)" % int(ao_acabar.bichos_de_casa.ativos))
	conferir(int(ao_acabar.bichos_de_casa.ativos) > int(depois.bichos_de_casa.ativos), "ao acabar a introdução os quadrúpedes começam a entrar")
	diretor.segundos += 60
	diretor.atualizar()
	var depois_de_um_minuto: Dictionary = diretor.contagem()
	conferir(int(depois_de_um_minuto.bichos_de_casa.ativos) > int(ao_acabar.bichos_de_casa.ativos), "o tempo depois da introdução amplia os quadrúpedes")
	conferir(int(depois_de_um_minuto.bandos_de_chao.ativos) >= int(ao_acabar.bandos_de_chao.ativos), "o tempo depois da introdução não tira bando de cena")
	var entrada := false
	for ator in get_nodes_in_group("bichos_de_casa"):
		if ator.get_meta("presenca_liberada", true):
			for malha in ator.find_children("*", "GeometryInstance3D", true, false):
				entrada = entrada or malha.transparency > 0.0
	conferir(entrada, "entrada gradual com transparência, sem aparição instantânea")
	await create_timer(1).timeout
	for ator in get_nodes_in_group("bichos_de_casa"):
		if ator.get_meta("presenca_liberada", true):
			for malha in ator.find_children("*", "GeometryInstance3D", true, false):
				conferir(is_zero_approx(malha.transparency), "entrada termina opaca")
	var salvo: Dictionary = vale.estado_para_salvar()
	conferir(is_equal_approx(float(salvo.segundos_apresentacao), diretor.segundos), "tempo da apresentação entra no save")
	var candinha: Node = vale._achar_morador("candinha")
	var camada_original: int = candinha.collision_layer
	candinha._recolher(true)
	diretor._definir(candinha, false, false)
	diretor._definir(candinha, true, false)
	conferir(candinha.collision_layer == 0 and not candinha.visible, "retomar não expõe quem está recolhido em casa")
	candinha._recolher(false)
	conferir(candinha.collision_layer == camada_original, "morador sai de casa com a colisão original")
	vale.pedro.missao = 6
	diretor.atualizar()
	conferir(int(diretor.contagem().moradores.ativos) > int(inicial.moradores.ativos), "progresso também apresenta o povoado")
	diretor.liberar_todos()
	vale.player.global_position += Vector3(500, 0, 500)
	if "--reabrir-orcamento" in OS.get_cmdline_user_args():
		diretor._todos_liberados = false
	diretor.atualizar()
	var cosme: Node = vale._achar_morador("cosme")
	conferir(cosme.get_meta("presenca_liberada", false), "liberar todos permanece válido ao recalcular visita")
	conferir(not visitante.visible, "liberar todos mantém calendário da visita")
	print("APRESENTACAO: %d falhas" % falhas)
	quit(0 if falhas == 0 else 1)


## Na introdução, nenhum ator do grupo em cena (visível e com movimento) está a menos de 40 u do jogador.
func _longe_de_quem_chega(vale: Node, grupo: String, nome: String) -> void:
	var minimo: float = vale.apresentacao_do_povoado.INTRODUCAO_LONGE
	for ator in get_nodes_in_group(grupo):
		if not (ator.is_physics_processing() or ator.is_processing()):
			continue
		var onde: Vector3 = vale.apresentacao_do_povoado.onde_esta(ator)
		conferir(onde.distance_to(vale.player.global_position) >= minimo,
			"na introdução um %s em cena está a %.1f u de quem chega (o mínimo é %.0f)" % [nome, onde.distance_to(vale.player.global_position), minimo])
