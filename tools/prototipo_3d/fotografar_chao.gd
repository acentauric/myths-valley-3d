extends SceneTree
## FOTOS DO CHÃO: as mesmas vistas fixas antes e depois de mexer no terreno, nas
## ruas e nas franjas (docs/mundo/SOLO_E_FRANJAS.md). Precisa de janela: com
## --headless o renderizador é o dummy, nenhum shader compila e a foto sai preta.
##   Godot --path . --script res://tools/prototipo_3d/fotografar_chao.gd -- --saida=<pasta> [--prefixo=antes] [--hora=9] [--estilo=tripo] [--so=praca,foz]
## Erro de shader não derruba o jogo: procure "SHADER ERROR" na saída depois.

const VISTAS := ["praca", "rua_principal", "rio_norte", "foz", "praia_pier", "mirante_vila", "vila_mirante", "lavoura"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(420.0).timeout.connect(func() -> void:
		push_error("FOTOS_CHAO: limite de 420 segundos excedido")
		quit(2))
	var args := _argumentos()
	var saida := String(args.get("saida", OS.get_user_data_dir()))
	var prefixo := String(args.get("prefixo", "chao"))
	var so: PackedStringArray = String(args.get("so", ",".join(VISTAS))).split(",", false)
	DirAccess.make_dir_recursive_absolute(saida)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.get_node("Estilo").set("modo", String(args.get("estilo", "tripo")))
	var game := (load("res://scenes/prototipo_3d/vale.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	var world: Node3D = game.get_node("Cenario")
	while not world.construido:
		await process_frame
	for i in range(20):
		await process_frame
	var player := game.get_node_or_null("Jogador") as Node3D
	if player != null:
		player.set_physics_process(false)
		player.set_process(false)
	game.set_process(false)
	var dia := root.get_node("Dia")
	dia.set("pausado", true)
	dia.call("definir_hora", float(args.get("hora", "9")))
	# Só o mundo na foto: HUD, minimapa, balões e telas ficam de fora.
	for camada in game.find_children("*", "CanvasLayer", true, false):
		(camada as CanvasLayer).visible = false
	for viewport in game.find_children("*", "SubViewport", true, false):
		(viewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	var region := world.get("_region") as Node3D
	var camera := Camera3D.new()
	camera.fov = 58.0
	camera.far = 2800.0
	game.add_child(camera)
	camera.current = true
	for vista in VISTAS:
		if not so.has(vista):
			continue
		if vista == "lavoura":
			_arar_um_pedaco(game)
		var quadro: Array = _quadro(vista, region, world)
		if quadro.is_empty():
			push_warning("FOTOS_CHAO: vista sem lugar no mapa: " + vista)
			continue
		camera.global_position = quadro[0]
		camera.look_at(quadro[1])
		for i in range(30):
			await process_frame
		await RenderingServer.frame_post_draw
		var caminho := saida.path_join("%s_%s.png" % [prefixo, vista])
		root.get_texture().get_image().save_png(caminho)
		print("FOTO_CHAO ", caminho)
	quit()


## [posição da câmera, ponto olhado] de cada vista, tirados do próprio mapa: se o
## KML mudar, a vista acompanha o lugar.
func _quadro(vista: String, region: Node3D, world: Node3D) -> Array:
	match vista:
		"praca":
			var praca: Vector3 = region.get_feature_center("Praça", "area")
			return [_no_chao(region, praca + Vector3(-16.0, 0.0, 15.0), 6.0), praca]
		"rua_principal":
			var rua := _linha(region.get("_roads"), "Rua Principal")
			if rua.size() < 4:
				return []
			var i := rua.size() / 2
			var a := rua[i]
			var b := rua[mini(i + 3, rua.size() - 1)]
			var lado := (b - a).normalized().orthogonal() * 3.0
			return [_no_chao(region, Vector3(a.x + lado.x, 0.0, a.y + lado.y), 2.6), _no_chao(region, Vector3(b.x, 0.0, b.y), 0.0)]
		"rio_norte":
			for rio: Dictionary in region.get("_rivers"):
				if region.call("_is_northern_river", rio):
					var pontos: PackedVector2Array = rio.points
					var i := pontos.size() / 3
					var tangente := (pontos[i + 1] - pontos[i]).normalized()
					var olho := pontos[i] + tangente.orthogonal() * 16.0 - tangente * 10.0
					return [_no_chao(region, Vector3(olho.x, 0.0, olho.y), 6.0), _no_chao(region, Vector3(pontos[i + 2].x, 0.0, pontos[i + 2].y), 0.0)]
		"foz":
			for rio: Dictionary in region.get("_rivers"):
				if region.call("_is_northern_river", rio):
					continue
				var pontos: PackedVector2Array = rio.points
				for do_fim in [false, true]:
					if not region.call("_tem_foz_no_extremo", pontos, do_fim):
						continue
					var ponta: Vector2 = pontos[-1] if do_fim else pontos[0]
					var antes: Vector2 = pontos[-6] if do_fim else pontos[5]
					var olho := antes + (antes - ponta).normalized() * 6.0 + (ponta - antes).normalized().orthogonal() * 10.0
					return [_no_chao(region, Vector3(olho.x, 0.0, olho.y), 7.0), Vector3(ponta.x, 0.0, ponta.y)]
		"praia_pier":
			var pier: Vector3 = region.get_feature_center("Pier", "poi")
			var costa: Vector2 = region.call("_nearest_land_edge", Vector2(pier.x, pier.z))
			var dentro := (costa - Vector2(pier.x, pier.z)).normalized()
			var olho := costa + dentro * 9.0 + dentro.orthogonal() * 14.0
			return [_no_chao(region, Vector3(olho.x, 0.0, olho.y), 3.0), Vector3(costa.x - dentro.orthogonal().x * 10.0, 0.0, costa.y - dentro.orthogonal().y * 10.0)]
		"mirante_vila":
			var mirante: Vector3 = region.get_feature_center("Mirante", "poi")
			var praca: Vector3 = region.get_feature_center("Praça", "area")
			var rumo := Vector3(praca.x - mirante.x, 0.0, praca.z - mirante.z).normalized()
			# Do alto da copa do morro: no chão do Mirante a mata tapa a vista.
			return [_no_chao(region, mirante + rumo * 10.0, 16.0), praca]
		"vila_mirante":
			var mirante: Vector3 = region.get_feature_center("Mirante", "poi")
			var praca: Vector3 = region.get_feature_center("Praça", "area")
			# Alto sobre a vila: o morro inteiro aparece, e com ele a mata que some ao longe.
			return [_no_chao(region, praca + Vector3(-6.0, 0.0, 4.0), 28.0), mirante]
		"lavoura":
			var meio: Vector3 = world.ancoras.get("Lavoura", Vector3.INF)
			if not meio.is_finite():
				return []
			var frente: Vector3 = world.ancoras.get("LavouraFrente", Vector3.BACK)
			return [_no_chao(region, meio + frente * 6.0, 3.2), _no_chao(region, meio, 0.0)]
	return []


## Ara metade dos leitos e rega alguns, para a foto mostrar bruto, arado e molhado.
func _arar_um_pedaco(game: Node) -> void:
	var lavoura = game.get("lavoura")
	if lavoura == null:
		return
	var n := 0
	for y in lavoura.LINHAS:
		for x in lavoura.COLUNAS:
			if x >= 3:
				continue
			lavoura.plantacao.arar(Vector2i(x, y))
			if y < 2 and x == 1:
				lavoura.plantacao.regar(Vector2i(x, y))
			n += 1


func _no_chao(region: Node3D, ponto: Vector3, acima: float) -> Vector3:
	return Vector3(ponto.x, float(region.ground_height_at(ponto)) + acima, ponto.z)


func _linha(rotas: Array, nome: String) -> PackedVector2Array:
	for rota: Dictionary in rotas:
		if String(rota.get("name", "")) == nome:
			return rota.points
	return PackedVector2Array()


func _argumentos() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			args[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	return args
