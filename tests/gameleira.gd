extends SceneTree
## A GAMELEIRA DO SAMBAQUI ASSENTA NO CHÃO (#87).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/gameleira.gd
##
## O monte e a árvore eram assentados por uma amostra do terreno, no centro
## (`world_builder._build_gameleira`); com o chão novo de 05/10 a encosta ali
## ficou inclinada e a árvore apareceu desnivelada em relação ao mundo. Agora o
## terreno em volta é um platô (`GeoRegionRenderer`, PLATÔ DA GAMELEIRA).
##
##   1. O CHÃO EM VOLTA É PLANO: num anel de raio 5,5 em volta do marco, o chão
##      varia menos de 0,2 u do centro.
##   2. O MONTE NÃO FLUTUA: a borda do domo (raio 5, enterrado meia unidade)
##      fica abaixo do chão em todo o anel.
##   3. O MARCO É O TRONCO: `Lugares.ponto("gameleira")` é a âncora do tronco.

const RAIO_DO_ANEL := 5.5
const TOLERANCIA := 0.2

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("GAMELEIRA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	var vale = current_scene
	var mundo = vale.world
	var lugares = root.get_node("/root/Lugares")
	var topo: Vector3 = mundo.ancoras.get("Gameleira", Vector3.INF)
	_conferir(topo.is_finite(), "o vale não tem a gameleira")
	if not topo.is_finite():
		_fechar()
		return
	var centro: float = mundo.ground_height_at(topo)

	# --- 1. O CHÃO EM VOLTA É PLANO ------------------------------------------------
	var desnivel := 0.0
	var mais_baixo := INF
	for i in 24:
		var angulo := TAU * float(i) / 24.0
		var ali := topo + Vector3(cos(angulo), 0.0, sin(angulo)) * RAIO_DO_ANEL
		var chao: float = mundo.ground_height_at(ali)
		desnivel = maxf(desnivel, absf(chao - centro))
		# --- 2. O MONTE NÃO FLUTUA: a borda do domo, a 5 u.
		var borda := topo + Vector3(cos(angulo), 0.0, sin(angulo)) * float(mundo.RAIO_DO_SAMBAQUI)
		mais_baixo = minf(mais_baixo, float(mundo.ground_height_at(borda)) - (centro - float(mundo.ENTERRADO)))
	_conferir(desnivel <= TOLERANCIA, "em volta da gameleira o chão varia %.2f u do centro (tolerância %.1f)" % [desnivel, TOLERANCIA])
	_conferir(mais_baixo >= -0.05, "a borda do sambaqui flutua %.2f u acima do chão" % -mais_baixo)

	# --- 3. O MARCO É O TRONCO -------------------------------------------------------
	var marco: Vector3 = lugares.ponto("gameleira")
	_conferir(marco.is_finite() and marco.distance_to(topo) < 0.01, "o marco da gameleira (%s) não é a âncora do tronco (%s)" % [str(marco), str(topo)])
	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("GAMELEIRA_OK: o chão em volta do sambaqui é plano, a borda do monte não flutua, e o marco do caboclo é o tronco")
	else:
		print("gameleira: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
