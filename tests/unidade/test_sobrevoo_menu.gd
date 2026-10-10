extends "res://tests/unidade/base.gd"
## Protege o trajeto real e a altura sobre o relevo: uma vista panoramica fixa
## pode parecer bonita e ainda apagar a vegetacao proxima com o LOD ativo.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste sobrevoo_menu

class CenarioTeste extends Node3D:
	var ancoras: Dictionary = {}
	var escala := 4.0

	func get_meters_per_unit() -> float:
		return escala

	func ground_height_at(at: Vector3) -> float:
		return 4.0 + at.x * 0.06 + at.z * 0.03


func test_sobrevoo_menu() -> void:
	var tamanho_original := root.size
	var abertura = load("res://scripts/prototipo_3d/abertura.gd").new()
	var mundo := CenarioTeste.new()
	mundo.name = "Cenario"
	abertura.add_child(mundo)
	# Marcos longe da origem detectam uma volta acidental aos pontos fixos antigos.
	var pier := Vector3(140, 8, 70)
	var praca := Vector3(80, 18, -30)
	mundo.ancoras = {"Pier": pier, "Praça": praca}
	_verificar(abertura._flyover_route(0.0).is_equal_approx(pier), "o trajeto nao parte do pier")
	_verificar(abertura._flyover_route(0.5).is_equal_approx(praca), "o trajeto nao chega a praca")
	for escala in [4.0, 2.0]:
		mundo.escala = escala
		for i in range(21):
			var progresso := float(i) / 20.0
			var eye: Vector3 = abertura._flyover_eye(progresso)
			var target: Vector3 = abertura._flyover_target(progresso)
			var altura: float = (eye.y - mundo.ground_height_at(eye)) * escala
			_verificar(altura >= 12.0 and altura <= 20.0, "o voo deixa a faixa baixa de 12 a 20 metros")
			var rota: Vector3 = abertura._flyover_route(progresso)
			var deslocamento: float = Vector2(eye.x - rota.x, eye.z - rota.z).length() * escala
			_verificar(deslocamento < 1.0, "a camera abandona o trajeto")
			_verificar(eye.distance_to(target) * escala < 70.0, "o alvo sai da faixa proxima do LOD")
			_verificar(target.y > mundo.ground_height_at(target), "o olhar entra no terreno")
			var movimento: Vector3 = abertura._flyover_route(progresso + 0.001) - abertura._flyover_route(progresso - 0.001)
			var olhar := target - eye
			movimento.y = 0.0
			var olhar_horizontal := Vector3(olhar.x, 0.0, olhar.z)
			_verificar(olhar_horizontal.normalized().dot(movimento.normalized()) > 0.98, "a camera nao olha para a frente do movimento")
			_verificar(absf(olhar.y) / olhar_horizontal.length() < 0.3, "a camera mira o chao em vez de casas e copas")
		_verificar(abertura._flyover_eye(0.0).is_equal_approx(abertura._flyover_eye(1.0)), "o ciclo salta ao recomecar")
		var ida: Vector3 = abertura._flyover_route(0.25)
		var volta: Vector3 = abertura._flyover_route(0.75)
		_verificar(ida.distance_to(volta) * escala > 60.0, "a volta repete o caminho de costas")
	mundo.ancoras = {"Pier": pier, "Praça": pier}
	_verificar(abertura._flyover_eye(0.5).is_finite(), "marcos coincidentes invalidam a camera")
	root.add_child(abertura.camera)
	abertura.camera.fov = 55.0
	for tamanho in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1024, 768)]:
		root.size = tamanho
		await process_frame
		for fase in [0.0, 0.25, 0.5, 0.75]:
			abertura.camera.position = abertura._flyover_eye(fase)
			abertura.camera_target = abertura._flyover_target(fase)
			abertura._frame_flyover()
			var projetado: Vector2 = abertura.camera.unproject_position(abertura.camera_target)
			var proporcao: float = projetado.x / root.get_visible_rect().size.x
			_verificar(proporcao > 0.70 and proporcao < 0.80, "o foco fica atras do painel em vez do terco direito")
	abertura.elapsed = 17.0
	abertura.camera.position = abertura._flyover_eye(0.25)
	abertura.camera_target = abertura._flyover_target(0.25)
	abertura._frame_flyover()
	var quadro: Transform3D = abertura.camera.transform
	var alvo: Vector3 = abertura.camera_target
	abertura._save_flyover_view()
	abertura.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	abertura.camera.position = Vector3(500, 3000, -200)
	abertura.camera_target = Vector3.ZERO
	abertura._restore_flyover_view()
	_verificar(abertura.camera.transform.is_equal_approx(quadro), "a volta do mapa nao restaura o quadro do voo")
	_verificar(abertura.camera_target.is_equal_approx(alvo), "a volta do mapa perde o alvo anterior")
	_verificar(abertura.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "a volta do mapa mantem a camera ortogonal")
	_verificar(is_equal_approx(abertura.elapsed, 17.0), "a volta do mapa reinicia o ciclo")
	abertura.camera.free()
	abertura.free()
	root.size = tamanho_original


func _verificar(ok: bool, motivo: String) -> void:
	assert_true(ok, motivo)
