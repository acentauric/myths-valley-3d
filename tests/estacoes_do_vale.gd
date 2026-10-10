extends "res://tests/suite/caso.gd"
## A virada real do calendário muda mata, luz e mistura sonora (#17).
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
	change_scene_to_file("res://scenes/prototipo_3d/vale.tscn")
	await process_frame
	var mundo := get_first_node_in_group("mundo")
	while mundo == null or not mundo.construido:
		await process_frame
		mundo = get_first_node_in_group("mundo")
	for _i in 10:
		await process_frame
	if DisplayServer.get_name() != "headless":
		while not get_nodes_in_group("carregando").is_empty():
			await process_frame
		var camera := Camera3D.new()
		current_scene.add_child(camera)
		var praca: Vector3 = mundo.ancoras.get("Praça", Vector3.ZERO)
		camera.global_position = mundo.ground_position(praca, 0.0) + Vector3(12, 6, 14)
		camera.look_at(mundo.ground_position(praca, 0.0) + Vector3.UP * 2.0)
		camera.make_current()
	var catalogo = load("res://scripts/prototipo_3d/catalogo_assets.gd")
	var tripo: BaseMaterial3D = catalogo.malha("mata_alta").mesh.surface_get_material(0)
	var textura := tripo.albedo_texture
	conferir(tripo.has_meta("cor_sem_estacao"), "matéria da mata Tripo registrada")
	var ambiente: Node
	for candidato in current_scene.find_children("*", "Node3D", true, false):
		if candidato.get_script() == load("res://scripts/prototipo_3d/ambiente_vale.gd"):
			ambiente = candidato
	conferir(ambiente != null, "ambiente real montado")
	if ambiente == null:
		quit(1)
		return
	ambiente.set_process(false)
	ambiente._mata_fator = 1.0
	var dia := root.get_node("Dia")
	dia.pausado = true
	dia.hora = 12.0
	var relogio := root.get_node("Relogio")
	var cores: Array[Color] = []
	var luzes: Array[Color] = []
	var aves: Array[float] = []
	relogio.estacao = 3
	for estacao in 4:
		relogio.dia = 28
		relogio._avancar_dia()
		conferir(relogio.estacao == estacao, "virada do calendário")
		cores.append(tripo.albedo_color)
		luzes.append(mundo._sun.light_color)
		aves.append(ambiente._aves.volume_db)
		conferir(tripo.albedo_texture == textura, "textura e identidade preservadas")
		# Repetir o sinal não multiplica a tinta de novo.
		relogio.estacao_mudou.emit(estacao)
		conferir(cores[-1].is_equal_approx(tripo.albedo_color), "cor não deriva em sinais repetidos")
		if DisplayServer.get_name() != "headless":
			for _quadro in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://scratch/estacoes")
			root.get_texture().get_image().save_png("res://scratch/estacoes/estacao-%d.png" % estacao)
	for i in range(1, 4):
		conferir(not cores[i].is_equal_approx(cores[i-1]), "mata muda entre estações")
		conferir(not luzes[i].is_equal_approx(luzes[i-1]), "luz muda entre estações")
		conferir(not is_equal_approx(aves[i], aves[i-1]), "aves variam entre estações")
	print("ESTACOES_DO_VALE: %d falha(s), aves %s" % [falhas, aves])
	quit(1 if falhas else 0)
