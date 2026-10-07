extends SceneTree
## Confere que O PEDRO NÃO ENTRA NO MAR para encurtar caminho.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/rota_por_terra.gd
##
## A queixa foi: "eu subo no píer e o Pedro fica tentando vir pelo mar". Ele
## andava em linha reta, o corpo sabia nadar, e a reta até o píer passa por
## cima d'água.
##
## O portão põe o jogador na ponta do píer e o Pedro em terra, do lado oposto,
## e mede DUAS coisas ao longo do caminho: que ele se aproxima, e que não passa
## a nadar. Uma sem a outra não diz nada — ficar parado na areia também não
## molha ninguém.
##
## Três perguntas:
##
##   1. O PÍER EXISTE e tem água em volta. Sem isso o teste mede um caminho
##      seco e passa por acidente.
##   2. O PEDRO SE APROXIMA. Preferir terra não pode virar preferir não ir.
##   3. ELE NÃO NADA NO CAMINHO. É a queixa, medida.
##
## E COM A MARÉ ("a maré vem ligada"): a primeira passada é a do mar na preamar, fixo, como o portão
## sempre mediu; depois vêm as outras duas, com a maré ligada — na PREAMAR (a água cobre mais) e na
## BAIXA-MAR (a água some em volta do píer, e a premissa 1 vira "ele não nada" e só). O portão media a
## premissa do mar fixo e reprovava com a maré ligada ("só 0 de 8 pontos com água" no meio da vazante); a
## malha dos moradores se assava com a água do instante, e na baixa-mar guardava a areia que a cheia cobre
## (navegacao_vale.gd, `_nivel_da_preamar`).

var falhas := 0
const QUADROS := 420


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("ROTA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK,
		"a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()

	var mundo := get_first_node_in_group("mundo")
	var jogador := get_first_node_in_group("map_player")
	var lugares := root.get_node("/root/Lugares")
	var pedro: Node3D = null
	for no in current_scene.find_children("*", "CharacterBody3D", true, false):
		if no.get_script() != null and str(no.get_script().resource_path).ends_with("guia_pedro.gd"):
			pedro = no
			break
	_conferir(mundo != null and jogador != null and pedro != null,
		"não achei o mundo, o jogador ou o Pedro")
	if mundo == null or jogador == null or pedro == null:
		_fechar()
		return
	var pier: Vector3 = lugares.ponto("pier")
	_conferir(pier != lugares.NENHUM, "o vale não tem píer")
	if pier == lugares.NENHUM:
		_fechar()
		return

	# A PASSADA DE SEMPRE: o mar na preamar, fixo.
	await _passada("mar fixo", true, mundo, jogador, pedro, pier)
	# COM A MARÉ LIGADA: na preamar e na baixa-mar.
	var mare := root.get_node("/root/Mare")
	var dia := root.get_node("/root/Dia")
	mare.modo = 1
	dia.pausado = true
	var preamar_h: float = float(mare.fase_da_preamar_h)
	dia.definir_hora(preamar_h)
	await _frames(6)
	_conferir(absf(float(mare.nivel_offset())) < 0.01, "o portão não achou a preamar (%.2f u)" % float(mare.nivel_offset()))
	await _passada("maré na preamar", true, mundo, jogador, pedro, pier)
	dia.definir_hora(fposmod(preamar_h + 6.0, 24.0))
	await _frames(6)
	_conferir(float(mare.nivel_offset()) < -0.5, "o portão não achou a baixa-mar (%.2f u)" % float(mare.nivel_offset()))
	await _passada("maré na baixa-mar", false, mundo, jogador, pedro, pier)
	mare.modo = 0
	_fechar()


## Uma medição completa: o Pedro, do lado de terra, e o jogador na ponta do píer. `exigir_agua`: a premissa 1 (água
## em volta do píer) vale — na baixa-mar a areia seca em volta e ela não pode ser cobrada.
func _passada(nome: String, exigir_agua: bool, mundo: Node, jogador: Node, pedro: Node3D, pier: Vector3) -> void:
	# --- 1. O PÍER TEM ÁGUA EM VOLTA -----------------------------------------
	var molhados := 0
	for i in 8:
		var angulo := TAU * float(i) / 8.0
		var ponto := pier + Vector3(cos(angulo), 0.0, sin(angulo)) * 6.0
		if float(mundo.water_depth_at(ponto)) > 0.4:
			molhados += 1
	if exigir_agua:
		_conferir(molhados >= 2,
			"[%s] só %d de 8 pontos em volta do píer têm água: o teste mediria caminho seco" % [nome, molhados])

	# --- 2 e 3. ELE SE APROXIMA SEM NADAR ------------------------------------
	#
	# O jogador vai para a ponta do píer, e o Pedro para o lado de terra — a
	# reta entre os dois é justamente a que passa pela água.
	jogador.global_position = pier
	await _frames(2)
	var em_terra := pier
	for i in 12:
		var tentativa := pier + Vector3(cos(TAU * float(i) / 12.0), 0.0, sin(TAU * float(i) / 12.0)) * 22.0
		if float(mundo.water_depth_at(tentativa)) < 0.2:
			em_terra = mundo.ground_position(tentativa)
			break
	_conferir(em_terra != pier, "[%s] não achei terra firme a 22 u do píer para pôr o Pedro" % nome)
	# Um passo em que ele SEGUE o jogador (a roça): no desembarque da partida nova
	# ele fica na ponta da prancha, e na condução vai na frente.
	pedro.ir_ao_passo("roca")
	pedro.global_position = em_terra
	await _frames(3)

	var distancia_inicial := _plano(pedro.global_position, jogador.global_position)
	var nadou := 0
	var fundura_maxima := 0.0
	for i in QUADROS:
		jogador.global_position = pier
		await physics_frame
		var fundura := float(mundo.water_depth_at(pedro.global_position))
		fundura_maxima = maxf(fundura_maxima, fundura)
		if pedro._nadando:
			nadou += 1

	var distancia_final := _plano(pedro.global_position, jogador.global_position)
	print("")
	print("  [%s] água em volta: %d de 8   distância %.1f → %.1f u   quadros nadando: %d   água mais funda: %.2f m"
		% [nome, molhados, distancia_inicial, distancia_final, nadou, fundura_maxima])

	_conferir(distancia_final < distancia_inicial - 2.0,
		"[%s] o Pedro não se aproximou: %.1f → %.1f. Preferir terra virou preferir não ir"
			% [nome, distancia_inicial, distancia_final])
	_conferir(nadou == 0,
		"[%s] o Pedro passou %d quadro(s) nadando para chegar ao píer: é a queixa" % [nome, nadou])


func _plano(a: Vector3, b: Vector3) -> float:
	var d := b - a
	d.y = 0.0
	return d.length()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("ROTA_OK: com o jogador na ponta do píer e o Pedro do outro lado da água, ele se aproxima por terra e não nada — com o mar fixo e com a maré ligada, na preamar e na baixa-mar")
	else:
		print("rota: %d falha(s)" % falhas)
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
