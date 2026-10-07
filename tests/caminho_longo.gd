extends SceneTree
## O MORADOR NÃO SALTA NO CAMINHO LONGO QUANDO A CÂMERA VIRA (#84).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/caminho_longo.gd
##
## "O padre teleportou em vários momentos que caminhava, eu vi a primeira vez
## saindo da igreja para o cemitério." A troca de posto a mais de CAMINHO_LONGO
## é caminho longo, e `_encurtar_o_caminho` punha o morador no destino assim
## que ele e o destino saíam do enquadramento por um quadro — bastava virar as
## costas. Agora o salto espera o jogador longe (LONGE_PARA_SALTAR) e sem ver
## nem o morador nem o destino por FORA_DA_VISTA_POR segundos seguidos.
##
##   1. DE COSTAS NÃO É LONGE: com o jogador a vinte unidades, olhando para o
##      outro lado, o morador num caminho longo anda — nenhum passo maior que
##      o que as pernas dão, e ele avança.
##   2. LONGE E FORA DA VISTA POR UM TEMPO, o atalho continua valendo: longe do
##      jogador e fora da câmera, antes de FORA_DA_VISTA_POR ele ainda anda, e
##      depois é posto no destino — a economia da festa.
##   3. NUNCA PARA UM PONTO À VISTA: com o destino na frente da câmera, mesmo
##      longe do morador, ele não aparece do nada.

## Um passo maior que isto (u) num tique de física é salto, não passo.
const SALTO := 0.3
var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("CAMINHO_LONGO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	var vale = current_scene
	var jogador = vale.player
	var mundo = vale.world
	var lugares = root.get_node("/root/Lugares")
	root.get_node("/root/Dia").pausado = true
	var tonho = vale._achar_morador("tonho")
	var gameleira: Vector3 = mundo.ancoras.get("Gameleira", Vector3.INF)
	_conferir(tonho != null and gameleira.is_finite(), "o vale não tem o Tonho ou a gameleira")
	if tonho == null or not gameleira.is_finite():
		_fechar()
		return
	var partida: Vector3 = tonho.global_position
	_conferir(partida.distance_to(gameleira) > float(tonho.CAMINHO_LONGO) + 10.0,
		"do posto do Tonho à gameleira são %.0f u: curto demais para a prova" % partida.distance_to(gameleira))

	# --- 1. DE COSTAS NÃO É LONGE ----------------------------------------------------
	_mandar_a_festa(tonho, gameleira)
	var perto: Vector3 = mundo.ground_position(partida + Vector3(20.0, 0.0, 0.0), 0.1)
	jogador.teleportar(perto, atan2(1.0, 0.0))
	await _passos_de_fisica(5)
	_conferir(not tonho._a_vista(tonho.global_position) and not tonho._a_vista(gameleira),
		"de costas, a câmera ainda vê o Tonho ou a gameleira: a prova não vale")
	var medida := await _andar(tonho, 360)
	_conferir(medida["maior"] <= SALTO, "com o jogador a vinte unidades, de costas, o Tonho saltou %.2f u num tique" % medida["maior"])
	_conferir(medida["andou"] >= 2.0, "o Tonho não andou (%.2f u) no caminho longo" % medida["andou"])
	_conferir(tonho._caminho_da_festa, "o caminho longo acabou antes da hora")

	# --- 2. LONGE E FORA DA VISTA POR UM TEMPO ---------------------------------------
	var chapada: Vector3 = lugares.ponto("expansao")
	_conferir(chapada.is_finite(), "a chapada não resolve")
	tonho.global_position = partida
	tonho.velocity = Vector3.ZERO
	_mandar_a_festa(tonho, gameleira)
	jogador.teleportar(mundo.ground_position(chapada, 0.1), PI)
	await _passos_de_fisica(5)
	var longe: float = jogador.global_position.distance_to(tonho.global_position)
	_conferir(longe >= float(tonho.LONGE_PARA_SALTAR) and not tonho._a_vista(tonho.global_position) and not tonho._a_vista(gameleira),
		"na chapada o jogador ainda está a %.0f u do Tonho, ou vê o Tonho ou a gameleira: a prova não vale" % longe)
	medida = await _andar(tonho, 60)
	_conferir(medida["maior"] <= SALTO, "longe e fora da vista, o Tonho saltou %.2f u antes de FORA_DA_VISTA_POR" % medida["maior"])
	medida = await _andar(tonho, int(float(tonho.FORA_DA_VISTA_POR) * 60.0) + 60)
	_conferir(tonho.global_position.distance_to(gameleira) < 2.0 and not tonho._caminho_da_festa,
		"longe e fora da vista por %.0f s, o Tonho não foi posto na gameleira (está a %.0f u)" % [float(tonho.FORA_DA_VISTA_POR), tonho.global_position.distance_to(gameleira)])

	# --- 3. NUNCA PARA UM PONTO À VISTA -----------------------------------------------
	tonho.global_position = partida
	tonho.velocity = Vector3.ZERO
	_mandar_a_festa(tonho, gameleira)
	# A 25 u ao sul a maré e o platô novo deixaram o ponto n'água (o jogador nadando, a câmera alta olhando o chão):
	# escolhe o primeiro ponto seco a 25 u em volta da gameleira.
	var de_frente: Vector3 = mundo.ground_position(gameleira + Vector3(0.0, 0.0, 25.0), 0.1)
	for graus in [0.0, 45.0, -45.0, 90.0, -90.0, 135.0, -135.0, 180.0]:
		var candidato: Vector3 = mundo.ground_position(gameleira + Vector3(0.0, 0.0, 25.0).rotated(Vector3.UP, deg_to_rad(graus)), 0.1)
		if candidato.y > gameleira.y - 1.5:
			de_frente = candidato
			break
	jogador.teleportar(de_frente, atan2(gameleira.x - de_frente.x, gameleira.z - de_frente.z))
	# A câmera assenta com mola depois do teleporte (06/10): 5 passos não bastam para ela olhar a gameleira.
	await _passos_de_fisica(45)
	_conferir(tonho._a_vista(gameleira), "de frente para a gameleira a câmera não a vê: a prova não vale")
	_conferir(jogador.global_position.distance_to(tonho.global_position) >= float(tonho.LONGE_PARA_SALTAR),
		"de frente para a gameleira o jogador está perto do Tonho: a prova não vale")
	medida = await _andar(tonho, int(float(tonho.FORA_DA_VISTA_POR) * 60.0) + 120)
	_conferir(medida["maior"] <= SALTO, "com a gameleira à vista, o Tonho apareceu nela: saltou %.2f u" % medida["maior"])
	_conferir(tonho.global_position.distance_to(gameleira) > 5.0, "com a gameleira à vista, o Tonho apareceu nela")
	_fechar()


## Manda o morador à gameleira pelo caminho longo da festa, sem destino avulso.
func _mandar_a_festa(morador, alvo: Vector3) -> void:
	morador.set("_destino_avulso", Vector3.INF)
	morador.set("_alvo", alvo)
	morador.set("_caminho_da_festa", true)
	morador.set("_fora_da_vista", 0.0)


## Roda `tiques` de física medindo o maior passo do morador num tique e o quanto andou.
func _andar(morador, tiques: int) -> Dictionary:
	var maior := 0.0
	var andou := 0.0
	var antes: Vector3 = morador.global_position
	for i in tiques:
		await physics_frame
		var agora: Vector3 = morador.global_position
		var passo := Vector2(agora.x - antes.x, agora.z - antes.z).length()
		maior = maxf(maior, passo)
		andou += passo
		antes = agora
	return {"maior": maior, "andou": andou}


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("CAMINHO_LONGO_OK: de costas e a vinte unidades o morador anda o caminho longo sem saltar; longe e fora da vista ele ainda anda antes de FORA_DA_VISTA_POR e depois é posto no destino; e nunca aparece num ponto à vista")
	else:
		print("caminho_longo: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _passos_de_fisica(n: int) -> void:
	for i in n:
		await physics_frame


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
