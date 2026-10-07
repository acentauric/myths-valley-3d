extends SceneTree
## O catálogo também compila quando um portão o pré-carrega antes dos autoloads.
const CatalogoAssets = preload("res://scripts/prototipo_3d/catalogo_assets.gd")
const Estacoes = preload("res://scripts/prototipo_3d/estacoes_vale.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var falhas := 0
	Estacoes.aplicar(2)
	if "--estacao-inicial" in OS.get_cmdline_user_args():
		Estacoes._estacao_atual = 0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.6, 0.7)
	var base := material.albedo_color
	Estacoes.registrar(material)
	if not material.albedo_color.is_equal_approx(base * Estacoes.MATA[2]):
		falhas += 1
		print("FALHA: modelo carregado depois recebe a estacao vigente")
	Estacoes.registrar(material)
	Estacoes.aplicar(3)
	if not material.albedo_color.is_equal_approx(base * Estacoes.MATA[3]):
		falhas += 1
		print("FALHA: reaplicar nao acumula cor")
	Estacoes.aplicar(0)
	print("ESTACAO_CATALOGO: %d falhas" % falhas)
	quit(1 if falhas else 0)
