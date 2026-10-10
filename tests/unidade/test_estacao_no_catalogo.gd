extends "res://tests/unidade/base.gd"
## O catálogo também compila quando um portão o pré-carrega antes dos autoloads.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste estacao_no_catalogo
const CatalogoAssets = preload("res://scripts/prototipo_3d/catalogo_assets.gd")
const Estacoes = preload("res://scripts/prototipo_3d/estacoes_vale.gd")

func test_estacao_no_catalogo() -> void:
	Estacoes.aplicar(2)
	if "--estacao-inicial" in OS.get_cmdline_user_args():
		Estacoes._estacao_atual = 0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.6, 0.7)
	var base := material.albedo_color
	Estacoes.registrar(material)
	conferir(material.albedo_color.is_equal_approx(base * Estacoes.MATA[2]),
		"modelo carregado depois recebe a estacao vigente")
	Estacoes.registrar(material)
	Estacoes.aplicar(3)
	conferir(material.albedo_color.is_equal_approx(base * Estacoes.MATA[3]),
		"reaplicar nao acumula cor")
	Estacoes.aplicar(0)
