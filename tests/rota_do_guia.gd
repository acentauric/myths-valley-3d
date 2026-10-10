extends "res://tests/suite/caso.gd"

func _initialize() -> void:
	rodar.call_deferred()

func rodar() -> void:
	var leitura = load("res://tools/jev/rota_do_guia.gd")
	var origem := Vector3(112, 4, -252)
	var destino := Vector3(117, 5, -260)
	var entrada := Vector3(114.9, 5, -254.5)
	var caminho := PackedVector3Array([origem, entrada, destino])
	var falhas := 0
	if "--falsificar" in OS.get_cmdline_user_args():
		leitura.source_code = leitura.source_code.replace("return ponto", "return destino")
		if leitura.reload() != OK:
			push_error("O mutante precisa compilar")
			quit(1)
			return
	if leitura.rumo(origem, destino, caminho) != entrada:
		push_error("A aproximação precisa contornar a cabeceira antes de seguir Pedro")
		falhas += 1
	if leitura.rumo(origem, destino, PackedVector3Array()).is_finite():
		push_error("Sem caminho, oito metros não autorizam atravessar a água em linha reta")
		falhas += 1
	if leitura.rumo(destino + Vector3.RIGHT, destino, PackedVector3Array()) != destino:
		push_error("A aproximação final de um metro continua possível")
		falhas += 1
	if leitura.rumo(origem, destino, caminho, true) != destino:
		push_error("A projeção curta do píer não impede aproximar pelo piso físico contínuo")
		falhas += 1
	var mundo := Node3D.new()
	root.add_child(mundo)
	var piso := StaticBody3D.new()
	mundo.add_child(piso)
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(10, 0.2, 2)
	forma.shape = caixa
	piso.add_child(forma)
	piso.position = Vector3(5, -0.1, 0)
	await physics_frame
	await physics_frame
	var espaco := mundo.get_world_3d().direct_space_state
	if not leitura.reta_apoiada(espaco, Vector3(0.2, 0, 0), Vector3(9.8, 0, 0), []):
		push_error("A sola contínua aceita a aproximação pelo piso")
		falhas += 1
	forma.disabled = true
	await physics_frame
	await physics_frame
	if leitura.reta_apoiada(espaco, Vector3(0.2, 0, 0), Vector3(9.8, 0, 0), []):
		push_error("Sem apoio físico não pode aproximar sobre o vazio")
		falhas += 1
	print("ROTA_DO_GUIA: ", falhas, " falhas")
	quit(1 if falhas else 0)
