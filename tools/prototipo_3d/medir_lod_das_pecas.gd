extends SceneTree
## A/B DO ALCANCE DAS PEÇAS (`CatalogoAssets.dar_alcance`, `pecas_distantes.gd`) com o
## renderizador de verdade: triângulos e chamadas de desenho por quadro.
## Precisa de janela (o renderizador do --headless é o dummy e devolve zero):
##
##   godot --path . --script res://tools/prototipo_3d/medir_lod_das_pecas.gd -- --modo=vale
##   godot --path . --script res://tools/prototipo_3d/medir_lod_das_pecas.gd -- --modo=troca
##   godot --path . --script res://tools/prototipo_3d/medir_lod_das_pecas.gd -- --modo=estado
##
## --modo=vale   o vale montado, de vários pontos de vista: sem o alcance (o vale de
##               antes: `CatalogoAssets.modo_mapa(true)` tira o corte e esconde os
##               substitutos) e com ele (`--quadros=N`, `--abba` para medir também o
##               tempo, `--puro`, `--fotos=<pasta>`);
## --modo=troca  uma casa e um pote sozinhos, a câmera se afastando em linha reta:
##               os triângulos de cada distância mostram onde o modelo sai e o
##               substituto entra (a troca seca, a margem, o desvanecer), e que não há
##               buraco nem sobreposição;
## --modo=estado a peça que NASCE, ou é levada de um salto, com a câmera dentro da faixa
##               da margem: 0 triângulos é o buraco (ver `_estado`).

const PecasDistantes = preload("res://scripts/prototipo_3d/pecas_distantes.gd")

var _args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			_args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
		elif a.begins_with("--"):
			_args[a.substr(2)] = "1"
	_run.call_deferred()


func _run() -> void:
	create_timer(560.0).timeout.connect(func() -> void:
		push_error("MEDIR_LOD_PECAS: limite de 560 segundos excedido")
		quit(2))
	if DisplayServer.get_name() == "headless":
		push_error("MEDIR_LOD_PECAS: precisa de janela (sem --headless)")
		quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	match String(_args.get("modo", "vale")):
		"troca":
			await _troca()
		"estado":
			await _estado()
		_:
			await _vale()
	quit(0)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


## Média de triângulos e de chamadas de desenho em `n` quadros.
func _medir(n: int) -> Dictionary:
	await _quadros(12)
	var triangulos := 0.0
	var chamadas := 0.0
	var gpu := 0.0
	var cpu := 0.0
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var maior_quadro := 0.0
	var ultimo := Time.get_ticks_usec()
	for i in n:
		await process_frame
		var agora := Time.get_ticks_usec()
		maior_quadro = maxf(maior_quadro, float(agora - ultimo) / 1000.0)
		ultimo = agora
		triangulos += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		chamadas += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
	return {"tri": triangulos / n, "draws": chamadas / n, "gpu": gpu / n, "cpu": cpu / n, "maior_quadro_ms": maior_quadro}


# --- o vale -----------------------------------------------------------------------

func _vale() -> void:
	var jogo := (load("res://scenes/prototipo_3d/vale.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(jogo)
	current_scene = jogo
	var mundo: Node3D = jogo.get_node("Cenario")
	while not mundo.construido:
		await process_frame
	await _quadros(30)
	var jogador := jogo.get_node("Jogador") as Node3D
	jogador.set_physics_process(false)
	jogo.set_process(false)
	var dia := root.get_node("Dia")
	dia.set("pausado", true)
	dia.call("definir_hora", 10.0)
	for viewport in jogo.find_children("*", "SubViewport", true, false):
		var painel := viewport.get_parent().get_parent() as Control
		if painel != null:
			painel.set_process(false)
			painel.visible = false
		(viewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	var camera := Camera3D.new()
	camera.fov = 58.0
	camera.far = 2800.0
	jogo.add_child(camera)
	camera.current = true
	var pier: Vector3 = mundo.ancoras.get("Pier", Vector3.ZERO)
	var mirante: Vector3 = mundo.ancoras.get("Mirante", Vector3.ZERO)
	var casa_taipa: Vector3 = mundo.ancoras.get("Casa de taipa", Vector3.ZERO)
	var pontos := {
		"praca_de_pe": [Vector3(0, mundo.ground_height_at(Vector3.ZERO) + 2.2, 12.0), Vector3(-40, 2.0, -60)],
		"praca_para_o_mirante": [Vector3(0, mundo.ground_height_at(Vector3.ZERO) + 3.0, 0.0), mirante],
		"casa_de_taipa": [casa_taipa + Vector3(0, 3.0, 14.0), casa_taipa],
		"mirante_olhando_a_vila": [mirante + Vector3(0, 6.0, 0), Vector3.ZERO],
		"pier_olhando_a_vila": [pier + Vector3(0, 4.0, 0), Vector3.ZERO],
		"baia_a_300u": [pier + Vector3(300, 8.0, 40), Vector3.ZERO],
	}
	print("MEDIR_LOD_PECAS vale: pecas=", get_nodes_in_group(PecasDistantes.GRUPO).size())
	for rotulo: String in pontos:
		camera.position = pontos[rotulo][0]
		camera.look_at(pontos[rotulo][1])
		var sem: Array[Dictionary] = []
		var com: Array[Dictionary] = []
		# Triângulos e chamadas de desenho não dependem do relógio: poucos quadros bastam
		# (--quadros=N); ABBA só se pedido (--abba), para medir também o tempo.
		var ordem: Array = [false, true, true, false] if _args.has("abba") else [false, true]
		for ligado in ordem:
			CatalogoAssets.modo_mapa(self, not ligado)
			var r: Dictionary = await _medir(int(_args.get("quadros", "6")))
			(com if ligado else sem).append(r)
			# --fotos=<pasta>: a tela inteira de cada ponto de vista, sem e com o alcance.
			if _args.has("fotos"):
				root.get_texture().get_image().save_png("%s/vale_%s_%s.png" % [String(_args["fotos"]), rotulo, "com" if ligado else "sem"])
		# --puro: o vale de ANTES de verdade, sem o corte e também sem o modo de desvanecer
		# (o que a peça traz ao ganhar alcance), para medir o que só o modo custa.
		if _args.has("puro"):
			CatalogoAssets.modo_mapa(self, true)
			var modos := {}
			for modelo in get_nodes_in_group(PecasDistantes.GRUPO):
				for g in PecasDistantes.geometrias_do_modelo(modelo):
					modos[g] = g.visibility_range_fade_mode
					g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			var puro: Dictionary = await _medir(int(_args.get("quadros", "6")))
			for g in modos:
				g.visibility_range_fade_mode = modos[g]
			print("MEDIR_LOD_PECAS_PURO  %-26s tri=%8.0f draws=%5.0f gpu_ms=%5.2f cpu_ms=%5.2f" % [rotulo, puro["tri"], puro["draws"], puro["gpu"], puro["cpu"]])
		print("MEDIR_LOD_PECAS_RESUMO %-26s tri_sem=%8.0f tri_com=%8.0f (%.0f%%)  draws_sem=%5.0f draws_com=%5.0f  gpu_ms_sem=%5.2f gpu_ms_com=%5.2f  cpu_ms_sem=%5.2f cpu_ms_com=%5.2f" % [
			rotulo, _media(sem, "tri"), _media(com, "tri"), 100.0 * _media(com, "tri") / maxf(_media(sem, "tri"), 1.0), _media(sem, "draws"), _media(com, "draws"),
			_media(sem, "gpu"), _media(com, "gpu"), _media(sem, "cpu"), _media(com, "cpu")])
		# O ruído da máquina: cada tomada de GPU (ms), para ver se A e A (ou B e B) concordam.
		var tomadas_sem := ""
		for r in sem:
			tomadas_sem += " %.1f" % float(r["gpu"])
		var tomadas_com := ""
		for r in com:
			tomadas_com += " %.1f" % float(r["gpu"])
		print("MEDIR_LOD_PECAS_TOMADAS %-26s gpu_ms sem:%s | com:%s" % [rotulo, tomadas_sem, tomadas_com])
	CatalogoAssets.modo_mapa(self, false)


func _media(amostras: Array[Dictionary], campo: String) -> float:
	var soma := 0.0
	for a in amostras:
		soma += float(a[campo])
	return soma / float(amostras.size())


# --- a troca ----------------------------------------------------------------------

func _troca() -> void:
	var cena := Node3D.new()
	root.add_child(cena)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-50, 30, 0)
	cena.add_child(luz)
	var camera := Camera3D.new()
	camera.far = 2800.0
	camera.fov = 58.0
	cena.add_child(camera)
	camera.current = true
	for peca in [["casa_taipa", 6.5], ["pote", 0.9], ["mangueira", 8.0]]:
		var chave: String = peca[0]
		var modelo := CatalogoAssets.instanciar(chave, cena, Vector3.ZERO, 1.0, 0.0)
		var geometrias := PecasDistantes.geometrias_do_modelo(modelo)
		var fim: float = geometrias[0].visibility_range_end
		var margem: float = geometrias[0].visibility_range_end_margin
		var tem_longe := modelo.get_node_or_null(PecasDistantes.NOME) != null
		print("MEDIR_TROCA %s: fim=%.0f margem=%.0f substituto=%s fade=%d" % [chave, fim, margem, tem_longe, geometrias[0].visibility_range_fade_mode])
		# --foto=<pasta>: um recorte do meio da tela logo antes e logo depois da troca (a
		# 3 u dela), ampliado, para ver o tamanho do salto.
		if tem_longe and _args.has("foto"):
			for distancia in [40.0, 100.0, fim + margem - 3.0, fim + margem + 3.0, fim + margem + 60.0]:
				camera.position = Vector3(0, 3.0, distancia)
				camera.look_at(Vector3(0, 2.0, 0))
				await _quadros(8)
				var imagem := root.get_texture().get_image()
				# Metade da altura de tela é mais ou menos o que a peça ocupa a 40 u: o recorte
				# cresce com a distância.
				var meio := int(maxf(160.0 * distancia / (fim + margem), 90.0))
				var recorte := imagem.get_region(Rect2i(imagem.get_width() / 2 - meio / 2, imagem.get_height() / 2 - meio * 3 / 8, meio, meio * 3 / 4))
				recorte.resize(640, 480, Image.INTERPOLATE_NEAREST)
				recorte.save_png("%s/troca_%s_%03d.png" % [String(_args["foto"]), chave, int(distancia)])
		var linha := ""
		var passo := 2.0 if tem_longe else 1.0
		var d := maxf(fim - 40.0, 10.0)
		while d <= fim + 40.0:
			camera.position = Vector3(0, 3.0, d)
			camera.look_at(Vector3(0, 2.0, 0))
			var r: Dictionary = await _medir(4)
			linha += "%.0f:%.0f(%.0fms) " % [d, r["tri"], r["maior_quadro_ms"]]
			d += passo * 2.0
		print("MEDIR_TROCA_CURVA %s (distancia:triangulos) %s" % [chave, linha])
		modelo.queue_free()
		await _quadros(3)


# --- o estado da troca ---------------------------------------------------------------

## Como o renderizador decide o que se vê DENTRO da margem, e o que vê uma peça recém-criada
## ou levada de um salto para dentro dela (o jogo carrega, teletransporta, pega o save).
## Para cada configuração de troca entre o modelo (11343 triângulos) e o substituto (14), e
## para cada distância em que a câmera nasce, imprime os triângulos desenhados quando a câmera
## está a 150 u logo ao nascer e depois de ir a 135, 165 e voltar a 150: 11343 é o modelo, 14
## o substituto, 11357 os dois, 0 nenhum dos dois (o buraco).
func _estado() -> void:
	var cena := Node3D.new()
	root.add_child(cena)
	var camera := Camera3D.new()
	camera.far = 2800.0
	cena.add_child(camera)
	camera.current = true
	var configuracoes := {
		"A seca, margem 15 nos dois": [0, 15.0, 0, 15.0],
		"B seca, margem 0 nos dois": [0, 0.0, 0, 0.0],
		"C desvanece nos dois, margem 15": [1, 15.0, 1, 15.0],
		"D modelo desvanece 15, substituto seco sem margem": [1, 15.0, 0, 0.0],
	}
	for rotulo: String in configuracoes:
		var c: Array = configuracoes[rotulo]
		for d0 in [60.0, 150.0, 230.0]:
			var modelo := CatalogoAssets.instanciar("casa_taipa", cena, Vector3.ZERO, 1.0, 0.0)
			var longe := modelo.get_node(PecasDistantes.NOME) as MultiMeshInstance3D
			for g in PecasDistantes.geometrias_do_modelo(modelo):
				g.visibility_range_end = 143.0
				g.visibility_range_end_margin = float(c[1])
				g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF if int(c[0]) == 1 else GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			longe.visibility_range_begin = 143.0
			longe.visibility_range_begin_margin = float(c[3])
			longe.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF if int(c[2]) == 1 else GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			var linha := ""
			for d in [d0, 150.0, 135.0, 165.0, 150.0]:
				camera.position = Vector3(0, 3.0, d)
				camera.look_at(Vector3(0, 2.0, 0))
				var r: Dictionary = await _medir(3)
				linha += " %.0f:%.0f" % [d, r["tri"]]
			print("MEDIR_ESTADO %-50s nasce a %3.0f ->%s" % [rotulo, d0, linha])
			modelo.free()
			await _quadros(3)
