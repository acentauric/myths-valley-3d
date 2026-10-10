extends "res://tests/suite/caso.gd"
## #135/#144: chegada, histerese e alvo seguinte sem concluir o trabalho.
var falhas := 0
func _initialize() -> void:
	_run.call_deferred()
func conferir(ok: bool, motivo: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: " + motivo)
func _run() -> void:
	await process_frame
	var cena := Node3D.new()
	root.add_child(cena)
	var jogador := Node3D.new()
	cena.add_child(jogador)
	jogador.add_to_group("map_player")
	var camera := Camera3D.new()
	cena.add_child(camera)
	camera.position = Vector3(0, 8, 10)
	camera.look_at(Vector3.ZERO)
	var camada := Control.new()
	root.add_child(camada)
	var seta = load("res://scripts/prototipo_3d/seta_missao.gd").new()
	cena.add_child(seta)
	seta.configurar(camada)
	var alvo := Vector3(10, 0, 0)
	seta.definir_alvo(alvo, "")
	await process_frame
	conferir(seta._cone.visible and seta._anel.visible, "alvo distante perdeu orientação")
	jogador.position = alvo
	await process_frame
	conferir(not seta._cone.visible and not seta._anel.visible, "chegada mantém marcador sobre jogador")
	conferir(seta.alvo_atual() == alvo, "chegada apagou destino lógico da missão")
	jogador.position = alvo + Vector3(2.8, 0, 0)
	seta.definir_alvo(alvo, "mesmo destino, próximo trabalho")
	await process_frame
	conferir(not seta._cone.visible, "progresso parcial/borda revive marcador antigo")
	jogador.position = alvo + Vector3(3.3, 0, 0)
	await process_frame
	conferir(seta._cone.visible, "afastamento sem conclusão não recupera orientação")
	seta.definir_alvo(Vector3(20, 0, 0), "")
	await process_frame
	conferir(seta._cone.visible and seta.alvo_atual() == Vector3(20, 0, 0), "novo objetivo não orienta")
	conferir(not seta._cone.mesh.cap_top and seta._cone.mesh.top_radius < 0.3,
		"cone ainda projeta disco grande")
	seta.limpar()
	conferir(not seta.visible and seta.alvo_atual() == null, "conclusão não limpa marcador")
	cena.queue_free()
	camada.queue_free()
	await process_frame
	print("MARCADOR_NA_CHEGADA: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
