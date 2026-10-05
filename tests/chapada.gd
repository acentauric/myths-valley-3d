extends SceneTree
## Confere A CHAPADA DO SEU BENEDITO, a frente do 2D que mostra terra que poderia
## ser do jogador (docs/projeto/MISSOES_DO_2D.md, 1.4; data/missoes_chapada.json).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/chapada.gd
##
## Quatro perguntas:
##
##   1. O LUGAR: "expansao" resolve na terra alta para lá da Dona Zefa, em terra
##      firme, com o rio grande à vista ao norte — "tá vendo a água?".
##   2. ESPERA A PRIMEIRA COLHEITA: acabada a chegada (e a ponte, que vem antes no
##      E do Pedro), a chapada não abre sem a mandioca colhida; colhida, abre.
##   3. A CHEGADA É CENA: chegar fecha o passo, a luz dourada sobe na tela, e paga a
##      garapa e a cocada.
##   4. A VOLTA: o E no Pedro fecha a frente, com a fala da água no balão.

## Onde a chapada foi posta, revisada pelo autor (unidades do vale).
const ONDE := Vector2(-6.0, -268.0)

var falhas := 0
var vale
var tecla
var jogador
var pedro


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("CHAPADA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	vale = current_scene
	tecla = vale.get("tecla_dos_moradores")
	jogador = vale.player
	pedro = vale.get("pedro")
	var mundo = vale.world
	var lugares = root.get_node("/root/Lugares")
	var inv = root.get_node("/root/Inventario")
	root.get_node("/root/Dia").pausado = true
	var chapada = vale._cadeias.get("pedro_chapada")
	var ponte = vale._cadeias.get("pedro_ponte")
	var roca = vale._cadeias.get("cosme_roca")
	var luz = vale.get("luz_dourada")
	_conferir(chapada != null and ponte != null and roca != null and luz != null and pedro != null,
		"o vale não tem a chapada (%s), a ponte (%s), a roça (%s) ou a luz dourada (%s)" % [str(chapada), str(ponte), str(roca), str(luz)])
	if chapada == null or ponte == null or roca == null or luz == null or pedro == null:
		_fechar()
		return

	# --- 1. O LUGAR -------------------------------------------------------------
	var onde: Vector3 = lugares.ponto("expansao")
	_conferir(onde.is_finite(), "a chapada (\"expansao\") não resolve no vale")
	if not onde.is_finite():
		_fechar()
		return
	_conferir(Vector2(onde.x, onde.z).distance_to(ONDE) < 3.0, "a chapada está em %s, e foi posta em %s" % [str(Vector2(onde.x, onde.z)), str(ONDE)])
	_conferir(mundo.is_on_land(onde) and mundo.water_depth_at(onde) < 0.2, "a chapada não é terra firme")
	var agua := INF
	for passo in range(1, 40):
		var ali := onde + Vector3(0, 0, -float(passo))
		if mundo.water_depth_at(ali) > 0.05:
			agua = float(passo)
			break
	_conferir(agua < 30.0, "da chapada não se vê o rio grande ao norte: a água mais perto está a %s u" % str(agua))

	# --- 2. ESPERA A PRIMEIRA COLHEITA --------------------------------------------
	pedro.missao = pedro.MISSOES.size()
	pedro.set("_despedida_feita", true)
	ponte.iniciado = true
	ponte.missao = ponte.passos.size()
	ponte.despedida_feita = true
	await _perto_do_pedro()
	tecla.usar(pedro)
	await _quadros(3)
	_conferir(not chapada.iniciado, "a chapada abriu sem a primeira colheita")
	roca.iniciado = true
	roca.missao = _indice(roca, "colher") + 1
	await _perto_do_pedro()
	tecla.usar(pedro)
	_conferir(await _ate(func() -> bool: return chapada.iniciado, 4.0), "colhida a mandioca, o E no Pedro não abriu a chapada")

	# --- 3. A CHEGADA É CENA ------------------------------------------------------
	await _ate(func() -> bool: return chapada.espera <= 0.0, 12.0)
	_conferir(str(chapada.passo_atual().get("id", "")) == "chapada", "a frente não começou por ver a chapada")
	var garapas: int = inv.quantidade("garapa")
	var cocadas: int = inv.quantidade("cocada")
	jogador.teleportar(mundo.ground_position(onde, 0.1), 0.0)
	_conferir(await _ate(func() -> bool: return chapada.missao >= 1, 8.0), "chegar à chapada não fechou o passo")
	_conferir(await _ate(func() -> bool: return luz.tocando() and luz.forca() > 0.2, 3.0),
		"a chegada à chapada não acendeu a luz dourada (força %.2f)" % luz.forca())
	_conferir(inv.quantidade("garapa") == garapas + 1 and inv.quantidade("cocada") == cocadas + 1, "a chapada não pagou a garapa e a cocada")
	_conferir(await _ate(func() -> bool: return not luz.tocando(), 10.0), "a luz dourada não se apagou sozinha")

	# --- 4. A VOLTA ---------------------------------------------------------------
	await _ate(func() -> bool: return chapada.espera <= 0.0, 12.0)
	await _perto_do_pedro()
	tecla.usar(pedro)
	_conferir(await _ate(func() -> bool: return chapada.acabou(), 8.0), "o E no Pedro não fechou a frente da chapada")
	_conferir(_no_balao(pedro).contains("rio grande"), "o Pedro não falou da água: '%s'" % _no_balao(pedro))
	_fechar()


func _indice(cadeia, id: String) -> int:
	for i in cadeia.passos.size():
		if str((cadeia.passos[i] as Dictionary).get("id", "")) == id:
			return i
	return -1


func _perto_do_pedro() -> void:
	jogador.teleportar(pedro.global_position + Vector3(1.0, 0.1, 0.6), 0.0)
	await _quadros(5)


func _no_balao(morador) -> String:
	var rotulo = morador.balao.get("_texto")
	return str(rotulo.text) if rotulo != null else ""


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("CHAPADA_OK: a chapada fica na terra alta para lá da Dona Zefa, com o rio grande à vista; espera a primeira colheita e abre no E do Pedro; chegar fecha o passo com a luz dourada e paga a garapa e a cocada; e a volta ao Pedro fecha a frente com a fala da água")
	else:
		print("chapada: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


## Roda quadros até `condicao` valer, com teto em SEGUNDO REAL.
func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicao.call():
			return true
		await process_frame
	return condicao.call()


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
