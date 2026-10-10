extends "res://tests/suite/caso.gd"
## Uma entrada de roça não é uma porteira decorativa imóvel no caminho.
const Paisagismo := preload("res://scripts/prototipo_3d/paisagismo_vale.gd")
var falhas := 0

func _initialize() -> void:
	_run.call_deferred()

func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: " + texto)

func _run() -> void:
	var receitas := Paisagismo.ler_receitas()
	receitas.aderecos.barraca_feira = {}
	var zona := {"nome": "Roça de prova", "receita": "roca_mandioca", "poligono": PackedVector2Array([
		Vector2(0, 0), Vector2(12, 0), Vector2(12, 12), Vector2(0, 12)])}
	var reservas := {"rua": func(p: Vector2) -> float: return p.y + 5.0}
	var itens := Paisagismo.aderecos(null, [zona], receitas, reservas)
	var cercas := 0
	var portoes := 0
	var entradas := 0
	for item in itens:
		if item.chave == "porteira": portoes += 1
		if item.chave == "cerca_varas": cercas += 1
		if item.chave == "entrada": entradas += 1
	var da_cerca: Dictionary = receitas.aderecos.cerca
	var lances := Paisagismo._lances_do_cercado(zona.poligono, float(da_cerca.passo),
		float(da_cerca.get("simplificar", 1.6)), float(da_cerca.get("para_fora", 0.9)))
	conferir(portoes == 0, "a entrada recebe um portão imóvel")
	conferir(entradas == 1, "a roça tem %d entrada(s), e não uma" % entradas)
	conferir(cercas == lances.size() - 1, "a entrada remove mais que seu lance: %d cercas de %d lances" % [cercas, lances.size()])
	change_scene_to_file("res://scenes/prototipo_3d/vale.tscn")
	for i in 8000:
		await process_frame
		if current_scene != null and bool(current_scene.get("carga_ok")): break
	var mundo = current_scene.world
	if "--falsificar" in OS.get_cmdline_user_args():
		load("res://scripts/prototipo_3d/catalogo_assets.gd").instanciar("porteira", mundo, mundo.ancoras["Cemitério"])
	for no in mundo.get_children():
		conferir(str(no.get_meta("peca", "")) != "porteira", "a porteira decorativa continua no vale")
	var no_vale := 0
	for item in mundo.paisagismo_aderecos:
		conferir(item.chave != "porteira", "o plano mantém uma porteira isolada")
		if item.chave == "cerca_varas": no_vale += 1
	conferir(no_vale >= 30, "a retirada eliminou as cercas das roças")
	if "--capturar" in OS.get_cmdline_user_args():
		var camera := Camera3D.new()
		current_scene.add_child(camera)
		var cem: Vector3 = mundo.ancoras["Cemitério"]
		camera.global_position = cem + Vector3(12, 8, 12)
		camera.look_at(cem)
		camera.current = true
		await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://scratch/entrada-da-roca")
		root.get_texture().get_image().save_png("res://scratch/entrada-da-roca/cemiterio.png")
	print("ENTRADA_DA_ROCA: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
