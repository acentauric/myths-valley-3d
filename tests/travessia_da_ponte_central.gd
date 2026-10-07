extends "res://tests/caminho_pela_porta.gd"
## Rotas que raspavam o corrimão, mais as duas cabeceiras reais da ponte.

func _initialize() -> void:
	if "--sem-corrimaos" in OS.get_cmdline_user_args():
		var script: GDScript = load("res://scripts/prototipo_3d/navegacao_vale.gd")
		script.source_code = script.source_code.replace("\t_obstaculos_das_pontes(fonte)", "\tpass")
		_conferir(script.reload() == OK, "mutante dos corrimãos compila")
	super._initialize()

func _caminhos() -> void:
	for par in [["Gameleira", "Cemitério"], ["Bar", "Casa de Carro Quebrado"]]:
		var pontos: PackedVector3Array = navegacao.caminho(world.ancoras[par[0]], world.ancoras[par[1]])
		_conferir(pontos.size() >= 2, "rota existe: " + str(par))
		await _andar(str(par), _sem_as_pontas(pontos, PONTA_DO_CAMINHO))

func _pontes() -> void:
	# A segunda laje tinha nome automático e desaparecia do inventário por nome.
	var lajes: Array[Node] = world.find_children("*LajeDaCamera*", "StaticBody3D", true, false)
	_conferir(lajes.size() >= 3, "píer e ambas as pontes mantêm nomes identificáveis")
	var ponte: Dictionary = world.pontes["Ponte do rio central"]
	var centro: Vector3 = ponte.centro
	var eixo: Vector3 = ponte.ao_longo
	var a := _chao(centro - eixo * 5.8) + Vector3.UP * 0.3
	var b := _chao(centro + eixo * 5.8) + Vector3.UP * 0.3
	await _andar("ponte central, ida pelo eixo", PackedVector3Array([a, b]))
	await _andar("ponte central, volta pelo eixo", PackedVector3Array([b, a]))
