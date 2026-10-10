extends "res://tests/suite/caso.gd"
## O GOLPE É DE BRAÇO: SÓ SAI ENCOSTADO E DE FRENTE PARA O ALVO (#208).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste golpe_de_braco
##
## O viajante dava machadadas no ar: o alcance do golpe era 3,2 m somados à meia-pegada
## da peça, e o E valia de muito longe, com o corpo parado olhando para outro lado.
## Agora o E se oferece de longe mas o golpe só sai a `ALCANCE_DO_GOLPE` da face do alvo:
## de mais longe o viajante anda até o ponto de golpe, gira para o alvo e só então bate.
##
##   1. O E DE LONGE: de costas e a ~3 m da face de uma pedra que se cata à mão, o E não
##      bate no ar — anda até lá, vira de frente e bate com o corpo no alcance curto.
##   2. A ESCALA: a pilha de lenha chega à cintura e o tronco caído tem uns 50 cm de
##      diâmetro, medidos contra o viajante (1,75).
##   3. O IMPACTO FORA DO ALCANCE não conta: levado para longe no meio do clipe, o golpe
##      não cobra nem derruba.

const ALVO := "pedra_cemiterio_a"
## Do viajante à face, na partida: longe do braço e perto o bastante para o E se oferecer.
const PARTIDA := 2.6
const CINTURA := 1.05
const DIAMETRO_DO_TRONCO := 0.6

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("GOLPE_DE_BRACO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(4)
	await _mundo_pronto()
	await _frames(6)
	var vale := current_scene
	var recursos := vale.get_node_or_null("Recursos3D")
	var jogador = vale.get("player")
	var mundo := get_first_node_in_group("mundo")
	var inv := root.get_node("/root/Inventario")
	var energia := root.get_node("/root/Energia")
	_conferir(recursos != null and jogador != null and mundo != null, "faltou o Recursos3D, o jogador ou o mundo")
	if recursos == null or jogador == null or mundo == null:
		_fechar()
		return

	# --- 2. A ESCALA ----------------------------------------------------------
	for id in recursos._alvos:
		var alvo: Dictionary = recursos._alvos[id]
		var peca := str(alvo["ficha"].get("peca", ""))
		if peca != "lenha" and peca != "tronco_caido":
			continue
		var limites: AABB = (alvo["no"] as Node3D).get_meta("limites", AABB())
		if peca == "lenha":
			_conferir(limites.size.y <= CINTURA, "a pilha '%s' tem %.2f de altura: passa da cintura (%.2f)" % [id, limites.size.y, CINTURA])
		else:
			_conferir(limites.size.y <= DIAMETRO_DO_TRONCO, "o tronco '%s' tem %.2f de diâmetro: passa de %.2f" % [id, limites.size.y, DIAMETRO_DO_TRONCO])
		print("  escala   %-22s %s  %.2f x %.2f x %.2f" % [id, peca, limites.size.x, limites.size.y, limites.size.z])

	# --- 1. O E DE LONGE ------------------------------------------------------
	_conferir(recursos._alvos.has(ALVO), "a pedra '%s' não está no vale" % ALVO)
	if recursos._alvos.has(ALVO):
		inv.selecionar(-1)
		await _prova_do_e_de_longe(recursos, jogador, mundo, inv, energia)

		# --- 3. O IMPACTO LONGE DO BRAÇO NÃO CONTA ------------------------------
		await _prova_do_impacto_longe(recursos, jogador, mundo, inv, energia)
	_fechar()


## Põe o viajante de costas para o alvo, a `PARTIDA` da face, pelo primeiro lado em que o E
## oferece o alvo. Devolve false se nenhum lado serviu.
func _partir(recursos: Node, jogador: Node, mundo: Node) -> bool:
	var pos: Vector3 = recursos._alvos[ALVO]["pos"]
	for lado: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var ponto: Vector3 = pos + lado * (PARTIDA + 0.6)
		var partida: Vector3 = mundo.ground_position(ponto, 0.1)
		jogador.teleportar(partida, atan2(lado.x, lado.z))
		for i in 10:
			await physics_frame
		jogador.velocity = Vector3.ZERO
		await process_frame
		await process_frame
		if recursos._perto == ALVO and float(recursos.distancia_da_face(ALVO, jogador.global_position)) > float(recursos.ALCANCE_DO_GOLPE):
			return true
	return false


func _prova_do_e_de_longe(recursos: Node, jogador: Node, mundo: Node, inv: Node, energia: Node) -> void:
	var partiu: bool = await _partir(recursos, jogador, mundo)
	_conferir(partiu, "nenhum lado a ~%.1f m da pedra '%s' a oferece ao E fora do alcance do golpe" % [PARTIDA, ALVO])
	if not partiu:
		return
	energia.repor(1000.0)
	var pedras_antes: int = inv.quantidade("pedra")
	var longe: float = recursos.distancia_da_face(ALVO, jogador.global_position)
	_conferir(recursos.bater(true), "o E de longe não foi aceito")
	await process_frame
	_conferir(inv.quantidade("pedra") == pedras_antes and recursos._alvos.has(ALVO),
		"o E a %.2f m da face bateu no ar na hora: o golpe devia esperar o viajante chegar" % longe)
	_conferir(recursos._aproximando_de == ALVO, "o E de longe não pôs o viajante a andar até o alvo")
	var da_face := INF
	var tempo := 0.0
	while tempo < 12.0 and recursos._alvos.has(ALVO):
		da_face = recursos.distancia_da_face(ALVO, jogador.global_position)
		await physics_frame
		tempo += 1.0 / float(Engine.physics_ticks_per_second)
	_conferir(not recursos._alvos.has(ALVO) and inv.quantidade("pedra") > pedras_antes,
		"o viajante não chegou nem bateu na pedra em %.0f s (face a %.2f m)" % [tempo, da_face])
	_conferir(da_face <= float(recursos.ALCANCE_DO_GOLPE) + float(recursos.FOLGA_DO_PARAR),
		"o golpe saiu com o corpo a %.2f m da face (alcance do golpe %.2f)" % [da_face, float(recursos.ALCANCE_DO_GOLPE)])
	print("  golpe    E a %.2f m da face: andou, virou e bateu a %.2f m" % [longe, da_face])


## A prova chama o `_ao_impacto_do_golpe` direto: com o golpe pendente e o corpo a 8 m do
## alvo, nada é cobrado nem derrubado.
func _prova_do_impacto_longe(recursos: Node, jogador: Node, mundo: Node, inv: Node, energia: Node) -> void:
	var outro := ""
	for id in recursos._alvos:
		if str(recursos._alvos[id]["ficha"].get("ferramenta", "")) == "" and str(recursos._alvos[id]["ficha"].get("rende", "")) == "pedra":
			outro = str(id)
			break
	_conferir(outro != "", "não sobrou pedra de catar à mão para a prova do impacto")
	if outro == "":
		return
	var pos: Vector3 = recursos._alvos[outro]["pos"]
	jogador.teleportar(mundo.ground_position(pos + Vector3(8.0, 0.0, 0.0), 0.1), 0.0)
	for i in 6:
		await physics_frame
	energia.repor(1000.0)
	var reserva: float = energia.atual
	var pedras: int = inv.quantidade("pedra")
	var golpes: int = int(recursos._alvos[outro]["golpes_dados"])
	recursos._golpe_pendente = outro
	recursos._ao_impacto_do_golpe()
	_conferir(is_equal_approx(float(energia.atual), reserva) and inv.quantidade("pedra") == pedras
			and int(recursos._alvos[outro]["golpes_dados"]) == golpes,
		"um impacto a 8 m do alvo '%s' cobrou ou derrubou" % outro)


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("GOLPE_DE_BRACO_OK: a pilha de lenha e o tronco caído estão em escala com o viajante, o E de longe anda até o alvo, vira de frente e só então bate com o corpo no alcance curto, e o impacto longe do braço não cobra nem derruba")
	else:
		print("golpe_de_braco: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame


func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
