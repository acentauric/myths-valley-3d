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
##   4. A LENHA DA FOGUEIRA (07/10): o fogo dá para três pratos; o quarto não sai
##      sem lenha; uma lenha posta pelo E na fogueira (com ela na mão) devolve três,
##      até o teto; e o fogo vai no save.

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

	# --- 4. A LENHA DA FOGUEIRA (07/10) ----------------------------------------------
	var inv = root.get_node("/root/Inventario")
	var cozinha = root.get_node("/root/Cozinha")
	var receitas = root.get_node("/root/Receitas")
	var energia = root.get_node("/root/Energia")
	var tecla = vale.get("tecla_das_bancadas")
	_conferir(vale.fogueira_acesa() and int(vale.pratos_no_fogo()) == int(vale.PRATOS_POR_LENHA), "a fogueira não começa com fogo para três pratos (%d)" % int(vale.pratos_no_fogo()))
	receitas.aprender("peixe_assado")
	inv.adicionar("peixe", 6)
	inv.adicionar("lenha", 8)
	for i in int(vale.PRATOS_POR_LENHA):
		energia.encher()
		_conferir(cozinha.cozinhar("peixe_assado"), "o prato %d não saiu com fogo na fogueira" % (i + 1))
		await _quadros(1)
	_conferir(not vale.fogueira_acesa(), "três pratos não apagaram a fogueira (fogo %d)" % int(vale.pratos_no_fogo()))
	# O PAINEL NÃO COZINHA SEM FOGO: o E na linha do prato recusa e explica.
	var painel = vale.get("painel")
	if painel != null:
		vale.abrir_o_painel(painel.Aba.COZINHA)
		await _quadros(2)
		var peixes: int = inv.quantidade("peixe")
		painel._cursor = 0
		painel._confirmar()
		await _quadros(2)
		_conferir(inv.quantidade("peixe") == peixes, "o painel cozinhou com a fogueira apagada")
		_conferir(str(painel._dica.text).contains("lenha"), "com a fogueira apagada o painel não pediu lenha ('%s')" % str(painel._dica.text))
		painel.fechar()
		await _quadros(2)
	# A LENHA NA MÃO, O E NA FOGUEIRA: alimenta, e o fogão não abre.
	var jogador = vale.player
	for i in inv.ESPACOS_MAO:
		if str((inv.espacos[i] as Dictionary).get("id", "")) == "lenha":
			inv.selecionar(i)
	_conferir(inv.na_mao() == "lenha", "não consegui pôr a lenha na mão")
	var lenhas: int = inv.quantidade("lenha")
	jogador.teleportar(pe + Vector3(1.2, 0.1, 0.0), -PI * 0.5)
	await _quadros(3)
	_conferir(str(tecla._rotulo("cozinha")).to_lower().contains("lenha"), "com a lenha na mão a dica da fogueira não diz que põe lenha ('%s')" % str(tecla._rotulo("cozinha")))
	tecla.usar("cozinha")
	await _quadros(2)
	_conferir(int(vale.pratos_no_fogo()) == int(vale.PRATOS_POR_LENHA) and inv.quantidade("lenha") == lenhas - 1, "o E com a lenha na mão não alimentou a fogueira (fogo %d, lenha %d→%d)" % [int(vale.pratos_no_fogo()), lenhas, inv.quantidade("lenha")])
	_conferir(painel == null or not bool(painel.get("aberto")), "o E com a lenha na mão abriu o fogão em vez de pôr a lenha")
	tecla.usar("cozinha")
	tecla.usar("cozinha")
	await _quadros(2)
	_conferir(int(vale.pratos_no_fogo()) == int(vale.FOGO_MAXIMO), "três lenhas não encheram a fogueira até o teto (%d)" % int(vale.pratos_no_fogo()))
	var antes_do_teto: int = inv.quantidade("lenha")
	tecla.usar("cozinha")
	await _quadros(2)
	_conferir(inv.quantidade("lenha") == antes_do_teto, "a fogueira cheia engoliu mais lenha")
	inv.selecionar(inv.MAO_LIVRE)
	var estado: Dictionary = vale.estado_para_salvar()
	_conferir(int(estado.get("fogueira", -1)) == int(vale.FOGO_MAXIMO), "o save não leva o fogo da fogueira: %s" % str(estado.get("fogueira")))
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
