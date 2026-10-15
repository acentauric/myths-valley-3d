extends SceneTree
## FOTOS DE LUGARES DO VALE, no vale montado de verdade, para conferir a olho o que os portões só medem
## (fachada, árvore, lagoa, ruína, luz da noite). Precisa de janela: com --headless o renderizador é o dummy
## e a foto sai preta.
##
##   Godot --path . --script res://tools/prototipo_3d/fotografar_lugar.gd -- --saida=<pasta> [--prefixo=lugar] \
##       [--hora=9] [--estacao=0..3] [--tamanho=1280x720] [--fov=60] \
##       --vistas="nome|Ancora|dx,dy,dz|tx,ty,tz[|fov[|frente[|hora]]]; outra|..."
##
## Cada vista é `nome|lugar|de|para`: o `lugar` é o nome de uma âncora do mundo (`Igreja`, `Casa_de_taipa`, com
## "_" no lugar de espaço) ou um nome do `Lugares` (`igreja`, `lagoa`); `de` é onde fica a câmera e `para` o ponto
## olhado, os dois em metros a partir do chão da âncora (x leste, y para cima, z sul). Com `frente` no fim,
## os deslocamentos andam no quadro da âncora (x à direita de quem olha de frente para ela, z para fora,
## na direção da `<Âncora>Frente`), que é o que se quer diante de uma fachada. Um `lugar` escrito `xyz` pega
## as coordenadas absolutas dos dois pontos.
##
## O HUD, o minimapa e o jogador ficam fora da foto. O relógio é parado na `--hora`, e a `hora` no fim de uma
## vista a troca só para ela (deixe o campo `frente` vazio para dar a hora sem ele: `a|Igreja|0,2,17|0,3,4||18.5`),
## o que põe o dia e a noite do mesmo lugar numa rodada só (cada rodada monta o vale: uns 40 s).
## Erro de shader não derruba o jogo: procure "SHADER ERROR" na saída depois.

var _args := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(900.0).timeout.connect(func() -> void:
		push_error("FOTOS_LUGAR: limite de 900 segundos excedido")
		quit(2))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			_args[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	var saida := String(_args.get("saida", OS.get_user_data_dir()))
	var prefixo := String(_args.get("prefixo", "lugar"))
	DirAccess.make_dir_recursive_absolute(saida)
	var medida := String(_args.get("tamanho", "1280x720")).split("x")
	DisplayServer.window_set_size(Vector2i(int(medida[0]), int(medida[1])))
	var jogo := (load("res://scenes/prototipo_3d/vale.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(jogo)
	current_scene = jogo
	var mundo: Node3D = jogo.get_node("Cenario")
	var limite := 0
	while not mundo.construido and limite < 40000:
		limite += 1
		await process_frame
	for i in 30:
		await process_frame
	var jogador := jogo.get_node_or_null("Jogador") as Node3D
	if jogador != null:
		jogador.set_physics_process(false)
		jogador.set_process(false)
		jogador.visible = false
	if _args.has("estacao"):
		var estacao := clampi(int(_args["estacao"]), 0, 3)
		root.get_node("Relogio").set("estacao", estacao)
		root.get_node("Relogio").emit_signal("estacao_mudou", estacao)
	var dia := root.get_node("Dia")
	dia.set("pausado", true)
	dia.call("definir_hora", float(_args.get("hora", "9")))
	for camada in jogo.find_children("*", "CanvasLayer", true, false):
		(camada as CanvasLayer).visible = false
	for viewport in jogo.find_children("*", "SubViewport", true, false):
		(viewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	var camera := Camera3D.new()
	camera.fov = float(_args.get("fov", "60"))
	camera.far = 2800.0
	jogo.add_child(camera)
	camera.current = true
	for vista in String(_args.get("vistas", "")).split(";", false):
		var campos := vista.strip_edges().split("|")
		if campos.size() < 4:
			push_warning("FOTOS_LUGAR: vista mal escrita: " + vista)
			continue
		var quadro := _quadro(mundo, campos)
		if quadro.is_empty():
			push_warning("FOTOS_LUGAR: lugar desconhecido: " + vista)
			continue
		camera.fov = float(campos[4]) if campos.size() > 4 and campos[4] != "" else float(_args.get("fov", "60"))
		dia.call("definir_hora", float(campos[6]) if campos.size() > 6 and campos[6] != "" else float(_args.get("hora", "9")))
		camera.global_position = quadro[0]
		camera.look_at(quadro[1])
		# O balanço de luz da noite e os shaders assentam em alguns quadros.
		for i in 24:
			await process_frame
		await RenderingServer.frame_post_draw
		var caminho := saida.path_join("%s_%s.png" % [prefixo, campos[0]])
		root.get_texture().get_image().save_png(caminho)
		print("FOTO_LUGAR ", caminho)
	quit()


## [posição da câmera, ponto olhado] no mundo, ou vazio se o lugar não existe.
func _quadro(mundo: Node3D, campos: PackedStringArray) -> Array:
	var de := _vetor(campos[2])
	var para := _vetor(campos[3])
	if campos[1] == "xyz":
		return [de, para]
	var nome := campos[1].replace("_", " ")
	var base: Vector3 = mundo.ancoras.get(nome, Vector3.INF)
	if not base.is_finite():
		base = root.get_node("Lugares").call("ponto", campos[1])
	if not base.is_finite():
		return []
	if campos.size() > 5 and campos[5] == "frente":
		var frente: Vector3 = mundo.ancoras.get(nome + "Frente", Vector3.ZERO)
		frente.y = 0.0
		if frente.length_squared() < 0.001:
			frente = Vector3.BACK
		frente = frente.normalized()
		var direita := Vector3(frente.z, 0.0, -frente.x)
		de = direita * de.x + Vector3.UP * de.y + frente * de.z
		para = direita * para.x + Vector3.UP * para.y + frente * para.z
	return [base + de, base + para]


func _vetor(texto: String) -> Vector3:
	var partes := texto.split(",")
	if partes.size() < 3:
		return Vector3.ZERO
	return Vector3(float(partes[0]), float(partes[1]), float(partes[2]))
