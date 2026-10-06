extends SceneTree
## A FOGUEIRA DO TERREIRO (#86): o modelo certo, e a chama que apaga de dia.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/fogueira.gd
##
## "O asset da fogueira tá errado." Desde 04/10 (`8413ae7`) o catálogo apontava
## a pilha de lenha (`lenha_tripo.glb`) para a peça `fogueira`, e o jogador via
## uma pilha de lenha com chama em cima; e a chama de partículas ficava acesa o
## dia inteiro — na live, a fogueira acesa de manhã.
##
##   1. O CATÁLOGO: a peça `fogueira` é `fogueira_tripo.glb` (o anel de pedras e
##      as toras), sólida; a `lenha` continua a pilha.
##   2. A CHAMA SEGUE A NOITE: ao meio-dia a chama e as brasas não emitem e a luz
##      está apagada; às 22 h emitem, e a luz acende.
##   3. A CHAMA FICA EM CIMA DAS TORAS: nasce acima do chão da fogueira e abaixo
##      da altura de um corpo.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("FOGUEIRA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	# --- 1. O CATÁLOGO -----------------------------------------------------------
	var catalogo = load("res://scripts/prototipo_3d/catalogo_assets.gd")
	var fogueira: Dictionary = catalogo.PECAS.get("fogueira", {})
	_conferir(str(fogueira.get("tripo", "")) == "aderecos/fogueira_tripo.glb",
		"a peça `fogueira` aponta '%s', e é a fogueira de pedras e toras" % str(fogueira.get("tripo", "")))
	_conferir(bool(fogueira.get("caixa", false)), "a fogueira não é sólida")
	_conferir(str(catalogo.PECAS.get("lenha", {}).get("tripo", "")) == "aderecos/lenha_tripo.glb", "a pilha de lenha deixou de ser a `lenha`")
	_conferir(ResourceLoader.exists("res://assets/prototipo_3d/aderecos/fogueira_tripo.glb"), "o GLB da fogueira não está no projeto")

	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	var vale = current_scene
	var mundo = vale.world
	var luzes = mundo.get("_luzes")
	var dia = root.get_node("/root/Dia")
	_conferir(luzes != null, "o vale não tem as luzes de época")
	if luzes == null:
		_fechar()
		return
	var chama: GPUParticles3D = luzes.find_child("ChamaDaFogueira", true, false)
	var brasas: GPUParticles3D = luzes.find_child("BrasasDaFogueira", true, false)
	_conferir(chama != null and brasas != null, "a fogueira do terreiro não tem chama ou brasas")
	if chama == null or brasas == null:
		_fechar()
		return

	# --- 2. A CHAMA SEGUE A NOITE --------------------------------------------------
	dia.pausado = true
	dia.definir_hora(12.0)
	luzes.aplicar_hora(12.0)
	await _quadros(2)
	_conferir(not chama.emitting and not brasas.emitting, "ao meio-dia a fogueira continua acesa (chama %s, brasas %s)" % [str(chama.emitting), str(brasas.emitting)])
	_conferir(not bool(luzes.get("_acesas")), "ao meio-dia as luzes de época estão acesas")
	dia.definir_hora(22.0)
	luzes.aplicar_hora(22.0)
	await _quadros(2)
	_conferir(chama.emitting and brasas.emitting, "às 22 h a fogueira está apagada (chama %s, brasas %s)" % [str(chama.emitting), str(brasas.emitting)])
	_conferir(bool(luzes.get("_acesas")), "às 22 h as luzes de época estão apagadas")

	# --- 3. A CHAMA FICA EM CIMA DAS TORAS -----------------------------------------
	var pe: Vector3 = mundo.ancoras.get("Fogueira", Vector3.INF)
	_conferir(pe.is_finite(), "o vale não tem a âncora da fogueira")
	if pe.is_finite():
		var acima := chama.global_position.y - pe.y
		_conferir(acima > 0.15 and acima < 1.0, "a chama nasce a %.2f u do chão da fogueira" % acima)
		_conferir(Vector2(chama.global_position.x - pe.x, chama.global_position.z - pe.z).length() < 0.3, "a chama não está em cima da fogueira")
	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("FOGUEIRA_OK: a peça da fogueira é a de pedras e toras, sólida; a chama e as brasas apagam ao meio-dia e acendem às 22 h com as luzes de época; e a chama nasce em cima das toras")
	else:
		print("fogueira: %d falha(s)" % falhas)
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
