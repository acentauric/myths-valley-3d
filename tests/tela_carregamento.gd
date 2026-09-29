extends SceneTree
## Tela de carregamento: a capa segue a hora (dia ou noite) para qualquer hora, ao entrar
## no jogo e ao voltar ao menu; na entrada o relógio espera a montagem do vale, e o
## jogador chega exatamente na hora inicial que escolheu a capa.
## Run: Godot --headless --path prototipo_3d --script res://tests/tela_carregamento.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var dia := root.get_node("Dia")
	# Carregada aqui, não com preload: o autoload Dia só vira identificador depois do início.
	var tela_script: GDScript = load("res://scripts/prototipo_3d/tela_carregamento.gd")
	var tema: Theme = load("res://scripts/prototipo_3d/tema_menu.gd").criar()

	# 1. Regra da capa em horas avulsas (nascer 5,95 h; noite a partir de 18,3 h).
	var casos := {6.5: false, 10.0: false, 17.5: false, 18.2: false, 18.4: true, 21.0: true, 0.0: true, 4.5: true, 6.0: false, 30.0: false}
	var camada := CanvasLayer.new()
	root.add_child(camada)
	for hora in casos:
		var tela := _montar(tela_script, camada, tema, hora)
		var capa: TextureRect = tela.get_node("Capa")
		_assert(tela.get_meta("noite") == casos[hora], "capa certa às %.1f h" % hora)
		_assert(capa.texture.resource_path.ends_with("capa_noite.webp" if casos[hora] else "capa_dia.webp"), "arquivo da capa às %.1f h" % hora)
		tela.free()
	# Sem hora explícita vale o relógio.
	dia.definir_hora(22.0)
	var tela_noite := _montar(tela_script, camada, tema, -1.0)
	_assert(tela_noite.get_meta("noite") == true, "sem hora: relógio às 22 h dá a capa da noite")
	tela_noite.free()
	dia.definir_hora(12.0)
	var tela_dia := _montar(tela_script, camada, tema, -1.0)
	_assert(tela_dia.get_meta("noite") == false, "sem hora: relógio ao meio-dia dá a capa de dia")
	tela_dia.free()
	camada.free()

	# 2. Congelado na carga o relógio não anda; solto, volta a andar.
	var velocidade_antes: int = dia.velocidade
	var hora_inicial_antes: float = dia.hora_inicial
	dia.velocidade = 3
	dia.pausado = false
	dia.congelado_na_carga = true
	dia.definir_hora(9.0)
	await create_timer(0.4).timeout
	_assert(is_equal_approx(dia.hora, 9.0), "relógio parado durante a carga")
	dia.congelado_na_carga = false
	await create_timer(0.4).timeout
	_assert(dia.hora > 9.0, "relógio volta a andar depois da carga")

	# 3. Entrar às 17h30 na velocidade Rápida: capa de dia e chegada às 17h30 (a montagem
	# leva segundos; com o relógio correndo, o vale abriria já de noite).
	_assert(change_scene_to_file("res://scenes/prototipo_3d/abertura.tscn") == OK, "menu carrega")
	await process_frame
	await process_frame
	await _mundo_pronto()
	dia.hora_inicial = 17.5
	current_scene._start_game()
	await process_frame
	var tela_entrada := root.find_child("TelaCarregamento", true, false)
	_assert(tela_entrada != null and tela_entrada.get_meta("noite") == false, "entrada às 17h30 com a capa de dia")
	await _esperar_cena("Vale3D")
	_assert(absf(dia.hora - 17.5) < 0.1, "chegou às 17h30 (chegou às %.2f h)" % dia.hora)
	_assert(not dia.congelado_na_carga, "relógio solto depois da montagem")
	# A tela da entrada some no fade; só então a da saída pode ser procurada.
	await create_timer(1.0).timeout
	_assert(root.find_child("TelaCarregamento", true, false) == null, "tela da entrada sumiu")

	# 4. Voltar ao menu às 21 h mostra a capa da noite.
	dia.definir_hora(21.0)
	current_scene._return_to_menu()
	await process_frame
	var tela_saida := root.find_child("TelaCarregamento", true, false)
	_assert(tela_saida != null and tela_saida.get_meta("noite") == true, "saída às 21 h com a capa da noite")
	await _esperar_cena("Abertura")

	dia.hora_inicial = hora_inicial_antes
	dia.velocidade = velocidade_antes
	print("TELA_CARREGAMENTO_OK: %d horas avulsas, relógio na carga, entrada às 17h30 e saída às 21 h" % casos.size())
	await create_timer(0.6).timeout
	for child in root.get_node("Audio").get_children():
		if child is AudioStreamPlayer:
			child.stop()
	await create_timer(0.2).timeout
	quit()


func _montar(tela_script: GDScript, pai: Node, tema: Theme, hora: float) -> Control:
	var barra: ProgressBar = tela_script.mostrar(pai, tema, "teste", hora)
	return barra.get_meta("tela")


func _esperar_cena(nome: String) -> void:
	for i in range(3000):
		if current_scene != null and current_scene.name == nome:
			break
		await process_frame
	await process_frame
	await _mundo_pronto()
	_assert(current_scene != null and current_scene.name == nome, "cena %s aberta" % nome)


func _assert(condition: bool, label: String) -> void:
	if not condition:
		push_error("TELA_CARREGAMENTO_FALHOU: " + label)
		quit(1)
		assert(false, label)


## O vale se monta ao longo de vários quadros (world_builder): espera ficar pronto.
func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
