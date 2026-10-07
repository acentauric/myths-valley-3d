extends "res://tests/colisoes_de_passeio.gd"
## A cápsula atravessa a porta da igreja na rota da malha, nos dois sentidos.
func _initialize() -> void:
	if "--sem-alinhamento" in OS.get_cmdline_user_args():
		var script: GDScript = load("res://scripts/prototipo_3d/navegacao_vale.gd")
		script.source_code = script.source_code.replace("if saida == entrada:", "if true:")
		_conferir(script.reload() == OK, "mutante compila")
	super._initialize()

func _mundo_pronto() -> void:
	await super._mundo_pronto()
	for i in 3600:
		var nav: Node = get_first_node_in_group("navegacao")
		if nav != null and nav.esta_pronta(): return
		await physics_frame

func _caminhos() -> void:
	var sala: Node3D = vale.interiores.sala_de("igreja")
	var a: Vector3 = world.ancoras["Praça"]
	var b: Vector3 = world.ancoras["Igreja"]
	var entrada: PackedVector3Array = navegacao.caminho(a, b)
	_conferir(entrada.has(sala.soleira_de_dentro()), "entrada mantém o alinhamento interno do vão")
	await _andar("Praça → Igreja", _sem_as_pontas(entrada, PONTA_DO_CAMINHO))
	var saida: PackedVector3Array = navegacao.caminho(b, a)
	_conferir(saida.has(sala.soleira_de_fora()), "saída mantém a soleira externa")
	await _andar("Igreja → Praça", _sem_as_pontas(saida, PONTA_DO_CAMINHO))
	sala.trancar(true)
	var fechada: PackedVector3Array = navegacao.caminho(a, b)
	_conferir(not fechada.has(sala.soleira_de_dentro()), "porta trancada não recebe travessia forçada")
	sala.trancar(false)

func _portas() -> void: pass
func _buracos() -> void: pass
func _pontes() -> void: pass
