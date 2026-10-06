extends SceneTree
## O BICHO DE QUATRO PATAS ANDA COM AS QUATRO PERNAS E PARA DE PÉ (#91, #109).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/bicho_parado.gd
##
## "A animação dos bichos ainda estão bugadas, o bicho fica esticando e
## voltando em um movimento vertical. O caminhar também pouco realista, todos
## os bichos parece que mancam." O clipe de andar do GLB só mexia os ossos que o
## auto-rig do Tripo batizou, e ele batiza errado: perna sem nome ficava dura
## (o manco), pescoço chamado de perna subia e descia (o estica). Agora o
## clipe não toca, e as pernas são achadas pela PELE do GLB: o osso que move os
## vértices baixos da malha é pé, e a perna sobe dele até o tronco
## (`animador_bicho._achar_as_pernas`). Antes disso (#91), parado, o bicho
## congelava com a pata no ar; isto continua coberto: parado, cada perna volta
## ao repouso.
##
##   1. CADA ESPÉCIE DE QUATRO PATAS DO VALE anda com as pernas do código e o
##      clipe do GLB parado: uma perna em cada canto (trás/frente × lado), sem
##      duas no mesmo — quatro, ou três nos rigs em que o auto-rig do Tripo deu
##      uma cadeia só para as duas patas de uma ponta (`PERNA_DO_MEIO`: a de
##      trás do cão caramelo e do bode, a da frente do filhote), que então é a
##      perna do meio e balança as duas. Rabo não é perna (o do caititu pende
##      até perto do chão). Rig refeito que ganhe as quatro sai da lista.
##   2. ANDANDO, as quatro balançam com a mesma força — ninguém manca: o osso
##      do alto de cada perna sai do repouso tanto quanto o das outras.
##   3. PARADO, em dois segundos as quatro voltam ao repouso (pata no chão), e
##      o corpo nunca escala em Y: nada estica.
##   4. VOLTANDO A ANDAR, balançam de novo.

var falhas := 0

## Os rigs que vieram do Tripo com uma cadeia só para as duas patas de uma ponta
## (a sonda dos pesos da pele, 06/10): três pernas, uma delas do meio.
const PERNA_DO_MEIO := ["cachorro_caramelo", "filhote_caramelo", "bode"]


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("BICHO_PARADO_FALHOU: " + rotulo)
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
	root.get_node("/root/Dia").pausado = true

	# --- 1. CADA ESPÉCIE, QUATRO PERNAS PELA GEOMETRIA ---------------------------
	var por_especie: Dictionary = {}
	for candidato in get_nodes_in_group("bichos_de_casa"):
		var a = candidato.get("_animador")
		var chave := str(candidato.get("chave"))
		if a == null or por_especie.has(chave):
			continue
		if str((candidato.get("especie") as Dictionary).get("tipo", "")) != "quadrupede":
			continue
		por_especie[chave] = candidato
	_conferir(por_especie.size() >= 6, "o vale tem só %d espécie(s) de quatro patas: %s" % [por_especie.size(), str(por_especie.keys())])
	var bicho = null
	var animador = null
	for chave in por_especie:
		var candidato = por_especie[chave]
		var a = candidato.get("_animador")
		if candidato.find_child("Caixa", true, false) != null:
			continue  # o procedural não tem esqueleto: anda com o balanço
		_conferir(bool(a.tem_pernas()), "o %s não anda com as pernas do código" % chave)
		_conferir(not bool(a.tem_clipe()), "o clipe do GLB do %s está tocando" % chave)
		var pernas: Array = a.pernas()
		var cantos: Dictionary = {}
		var do_meio := 0
		var frente := false
		var tras := false
		for perna in pernas:
			var canto := str(perna["canto"])
			cantos[canto] = true
			do_meio += 1 if canto.ends_with("centro") else 0
			frente = frente or canto.begins_with("frente_")
			tras = tras or canto.begins_with("tras_")
			_conferir(int(perna["osso"]) != int(perna["joelho"]), "uma perna do %s não tem joelho" % chave)
			_conferir(float(perna["comprimento"]) > 0.05, "uma perna do %s mede %.2f u" % [chave, float(perna["comprimento"])])
		_conferir(cantos.size() == pernas.size() and frente and tras,
			"o %s tem %d perna(s) nos cantos %s: duas no mesmo canto, ou uma ponta sem perna" % [chave, pernas.size(), str(cantos.keys())])
		if chave in PERNA_DO_MEIO:
			_conferir(pernas.size() == 3 and do_meio == 1,
				"o %s (rig de cadeia só numa ponta) tem %d perna(s), %d do meio, e não três com uma do meio: %s" % [chave, pernas.size(), do_meio, str(cantos.keys())])
		else:
			_conferir(pernas.size() == 4 and do_meio == 0,
				"o %s tem %d perna(s) nos cantos %s, e não quatro, uma em cada canto" % [chave, pernas.size(), str(cantos.keys())])
		if bicho == null and pernas.size() == 4:
			bicho = candidato
			animador = a
	_conferir(bicho != null, "nenhum bicho de casa anda com as quatro pernas do código")
	if bicho == null:
		_fechar()
		return

	# Perto do bicho, para o animador não ficar parado por estar fora da vista.
	jogador.teleportar(mundo.ground_position(bicho.global_position + Vector3(3.0, 0.0, 3.0), 0.1), atan2(-1.0, -1.0))
	bicho.set_physics_process(false)
	var esqueleto: Skeleton3D = animador.get("_esqueleto")
	var pernas_do_bicho: Array = animador.pernas()
	var pose: Node3D = animador.get("pose")
	await _quadros(5)

	# --- 2. ANDANDO, AS QUATRO COM A MESMA FORÇA --------------------------------------
	animador.velocidade = 1.0
	var maior_por_perna: Array[float] = []
	for perna in pernas_do_bicho:
		maior_por_perna.append(0.0)
	var escalou := false
	for quadro in 90:
		await process_frame
		for i in pernas_do_bicho.size():
			var perna: Dictionary = pernas_do_bicho[i]
			var giro := _fora_do_repouso(esqueleto, perna)
			maior_por_perna[i] = maxf(maior_por_perna[i], giro)
		if absf(pose.scale.y - 1.0) > 0.001:
			escalou = true
	var menor := INF
	var maior := 0.0
	for g in maior_por_perna:
		menor = minf(menor, g)
		maior = maxf(maior, g)
	_conferir(menor > 0.08, "andando, uma perna do %s mal sai do repouso (%.3f rad): manca" % [str(bicho.get("chave")), menor])
	_conferir(maior > 0.0 and menor / maior > 0.6,
		"andando, as pernas do %s balançam desiguais (%.2f a %.2f rad): manca" % [str(bicho.get("chave")), menor, maior])
	_conferir(not escalou, "andando, o corpo do %s escalou em Y: estica" % str(bicho.get("chave")))

	# --- 3. PARADO, CADA PERNA VOLTA AO REPOUSO -----------------------------------------
	animador.velocidade = 0.0
	var parou := await _ate(func() -> bool:
		for perna in pernas_do_bicho:
			if _fora_do_repouso(esqueleto, perna) > 0.02:
				return false
		return true, 2.5)
	_conferir(parou, "parado, o %s ficou com a pata no ar" % str(bicho.get("chave")))
	for quadro in 30:
		await process_frame
		if absf(pose.scale.y - 1.0) > 0.001:
			escalou = true
	_conferir(not escalou and is_equal_approx(pose.scale.y, 1.0), "parado, o corpo do %s escala em Y (%.3f): estica e volta" % [str(bicho.get("chave")), pose.scale.y])

	# --- 4. VOLTANDO A ANDAR --------------------------------------------------------
	animador.velocidade = 1.0
	var voltou := await _ate(func() -> bool:
		for perna in pernas_do_bicho:
			if _fora_do_repouso(esqueleto, perna) > 0.05:
				return true
		return false, 1.5)
	_conferir(voltou, "voltando a andar, as pernas do %s não balançaram" % str(bicho.get("chave")))
	_fechar()


## Quanto o osso do alto da perna está fora do repouso (rad).
func _fora_do_repouso(esqueleto: Skeleton3D, perna: Dictionary) -> float:
	var agora: Quaternion = esqueleto.get_bone_pose_rotation(int(perna["osso"]))
	return agora.angle_to(perna["repouso"] as Quaternion)


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("BICHO_PARADO_OK: cada espécie de quatro patas anda com as pernas do código, achadas pela pele do GLB, uma em cada canto (três com a do meio nos rigs de cadeia só, e rabo fora); andando as pernas balançam com a mesma força; parado cada perna volta ao repouso e o corpo nunca escala em Y; e voltando a andar balançam de novo")
	else:
		print("bicho_parado: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicao.call():
			return true
		await process_frame
	return condicao.call()


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
