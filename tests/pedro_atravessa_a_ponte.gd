extends SceneTree
## O PEDRO ATRAVESSA A PONTE NOS DOIS SENTIDOS (#219).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/pedro_atravessa_a_ponte.gd
##     ... --script res://tests/pedro_atravessa_a_ponte.gd -- --falsificar
##
## No passo 6/16 ("Abra a casa do seu tio e entre") o Pedro ficou parado na cabeceira da ponte,
## encostado no pilar, e a chegada travou: o caminho da rua chegava à ponte em reta de vértice a
## vértice e entrava de viés pelo mourão. A regra nova (`NavegacaoVale.alinhar_pela_ponte`) faz todo
## caminho que cruza a ponte entrar pelo eixo dela.
##
##   1. A REGRA, SEM MUNDO. Uma ponte de mentira e um caminho em diagonal: o resultado passa pelo eixo
##      (nunca a mais de CORREDOR dele, na ponte e nas cabeceiras); o caminho que só passa ao lado, e o
##      que parte do meio da ponte, voltam iguais; nos dois sentidos.
##   2. O CAMINHO DO VALE. Em cada ponte pervia, o caminho pela estrada de uma ponta à outra, nos dois
##      sentidos, fica no corredor, e nenhum ponto dele cai dentro de um corpo.
##   3. O CORPO. Com a física de verdade, o Pedro anda esse caminho de uma ponta à outra da ponte, ida e
##      volta, dentro do tempo-limite; e um morador comum (a Candinha), pelo caminho da malha, também.
##
## `--falsificar` desliga a regra em memória: a parte 1 reprova (o caminho em diagonal volta intacto).

const CORREDOR := 1.0
const MARGEM_DAS_CABECEIRAS := 0.5
const ALEM_DA_CABECEIRA := 9.0
const LIMITE_DE_QUADROS := 3600
const PASSO := 1.0 / 60.0

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()
	create_timer(420).timeout.connect(func() -> void:
		print("FALHA: a travessia excedeu o tempo de prova")
		quit(2))


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("PEDRO_ATRAVESSA_A_PONTE_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	var navegacao_script: GDScript = load("res://scripts/prototipo_3d/navegacao_vale.gd")
	if "--falsificar" in OS.get_cmdline_user_args():
		navegacao_script.source_code = navegacao_script.source_code.replace(
			"if primeiro < 0 or absf(u_entra)", "if true or absf(u_entra)")
		_conferir(navegacao_script.reload() == OK, "o mutante da regra compila")
		_regra_sem_mundo(navegacao_script)
		print("PEDRO_ATRAVESSA_A_PONTE (falsificado): %d falha(s)" % falhas)
		quit(1 if falhas > 0 else 0)
		return
	_regra_sem_mundo(navegacao_script)
	if falhas > 0:
		print("PEDRO_ATRAVESSA_A_PONTE: %d falha(s)" % falhas)
		quit(1)
		return
	await _no_vale()
	print("PEDRO_ATRAVESSA_A_PONTE: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


# --- 1. A REGRA, SEM MUNDO -------------------------------------------------------------------

func _regra_sem_mundo(regra: GDScript) -> void:
	var centro := Vector3(10.0, 0.0, -4.0)
	var eixo := Vector3(0.8, 0.0, 0.6)
	var lado := Vector3(-eixo.z, 0.0, eixo.x)
	var comprimento := 9.0
	var largura := 4.5
	var no_lugar := func(xz: Vector2) -> Vector3: return Vector3(xz.x, 0.0, xz.y)
	# Um caminho em diagonal, que chega de viés a uma cabeceira e sai de viés pela outra.
	var diagonal := PackedVector3Array([
		centro - eixo * 22.0 + lado * 12.0,
		centro + eixo * 22.0 - lado * 12.0])
	_conferir(_desvio_no_corredor(diagonal, centro, eixo, comprimento) > CORREDOR * 2.0,
		"o caminho de prova precisa atravessar a ponte de viés (o defeito)")
	var alinhado: PackedVector3Array = regra.alinhar_pela_ponte(diagonal, centro, eixo, comprimento, largura, no_lugar)
	var desvio := _desvio_no_corredor(alinhado, centro, eixo, comprimento)
	_conferir(desvio <= CORREDOR, "o caminho alinhado fica a %.2f do eixo na ponte e nas cabeceiras (limite %.1f)" % [desvio, CORREDOR])
	_conferir(alinhado[0].is_equal_approx(diagonal[0]) and alinhado[alinhado.size() - 1].is_equal_approx(diagonal[1]),
		"o caminho alinhado parte e chega onde o original partia e chegava")
	# O sentido contrário.
	var volta := PackedVector3Array([diagonal[1], diagonal[0]])
	var alinhado_volta: PackedVector3Array = regra.alinhar_pela_ponte(volta, centro, eixo, comprimento, largura, no_lugar)
	_conferir(_desvio_no_corredor(alinhado_volta, centro, eixo, comprimento) <= CORREDOR, "a volta também entra pelo eixo")
	# Passar ao lado, ou partir do meio da ponte, não é atravessá-la: volta intacto.
	var ao_lado := PackedVector3Array([centro - eixo * 20.0 + lado * 14.0, centro + eixo * 20.0 + lado * 14.0])
	_conferir(regra.alinhar_pela_ponte(ao_lado, centro, eixo, comprimento, largura, no_lugar) == ao_lado,
		"o caminho que só passa ao lado da ponte não muda")
	var do_meio := PackedVector3Array([centro + lado * 0.5, centro + eixo * 25.0 + lado * 6.0])
	_conferir(regra.alinhar_pela_ponte(do_meio, centro, eixo, comprimento, largura, no_lugar) == do_meio,
		"o caminho que parte do meio da ponte não muda")


## O quanto, no máximo, o caminho se afasta do eixo da ponte enquanto está na ponte ou nas cabeceiras.
func _desvio_no_corredor(pontos: PackedVector3Array, centro: Vector3, eixo: Vector3, comprimento: float) -> float:
	var e := Vector2(eixo.x, eixo.z).normalized()
	var l := Vector2(-e.y, e.x)
	var c := Vector2(centro.x, centro.z)
	var pior := 0.0
	for i in range(pontos.size() - 1):
		var a := Vector2(pontos[i].x, pontos[i].z)
		var b := Vector2(pontos[i + 1].x, pontos[i + 1].z)
		var passos := maxi(1, ceili(a.distance_to(b) / 0.25))
		for k in passos + 1:
			var rel := a.lerp(b, float(k) / float(passos)) - c
			if absf(rel.dot(e)) <= comprimento * 0.5 + MARGEM_DAS_CABECEIRAS:
				pior = maxf(pior, absf(rel.dot(l)))
	return pior


# --- 2 e 3. O VALE ---------------------------------------------------------------------------

func _no_vale() -> void:
	root.get_node("Estilo").modo = "tripo"
	change_scene_to_file("res://scenes/prototipo_3d/vale.tscn")
	await process_frame
	while current_scene == null or current_scene.get("carga_ok") != true:
		await process_frame
	var vale: Node = current_scene
	var navegacao: Node = get_first_node_in_group("navegacao")
	while not navegacao.esta_pronta():
		await physics_frame
	root.get_node("Dia").pausado = true
	vale.apresentacao_do_povoado.set_process(false)
	var mundo = vale.world
	var pedro = vale.pedro
	var candinha: CharacterBody3D = vale._achar_morador("candinha")
	_conferir(pedro != null and candinha != null, "o vale tem o Pedro e a Candinha")
	if pedro == null or candinha == null:
		return
	# Ninguém mais se mexe nem barra: só quem anda na prova.
	for pessoa in get_nodes_in_group("moradores"):
		pessoa.set_physics_process(false)
		pessoa.set_process(false)
		pessoa.collision_layer = 0
	pedro.set_physics_process(false)
	pedro.collision_layer = 0
	vale.player.set_physics_process(false)
	vale.player.collision_layer = 0
	var espaco: PhysicsDirectSpaceState3D = mundo.get_world_3d().direct_space_state
	var pontes: Dictionary = mundo.pontes
	_conferir(pontes.has("Ponte do rio central"), "o vale tem a ponte do rio central")
	var provadas := 0
	for nome in pontes:
		var ponte: Dictionary = pontes[nome]
		if not bool(navegacao._ponte_pervia(str(nome))):
			print("  %s: interditada, fora da prova" % nome)
			continue
		var centro: Vector3 = ponte.centro
		var eixo: Vector3 = ponte.ao_longo
		var comprimento := float(ponte.comprimento)
		var ate := comprimento * 0.5 + ALEM_DA_CABECEIRA
		var a: Vector3 = mundo.ground_position(centro - eixo * ate)
		var b: Vector3 = mundo.ground_position(centro + eixo * ate)
		if not mundo.is_on_land(a) or not mundo.is_on_land(b):
			print("  %s: uma das pontas cai na água, fora da prova (%s, %s)" % [nome, str(a), str(b)])
			continue
		provadas += 1
		for sentido in [[a, b, "ida"], [b, a, "volta"]]:
			var de: Vector3 = sentido[0]
			var para: Vector3 = sentido[1]
			var rotulo := "%s, %s" % [nome, sentido[2]]
			# 2. O caminho: fica no corredor e não entra em corpo.
			var caminho: PackedVector3Array = navegacao.caminho_pela_estrada(de, para)
			_conferir(caminho.size() >= 2, "%s: há caminho pela estrada" % rotulo)
			if caminho.size() < 2:
				continue
			var fim := caminho[caminho.size() - 1]
			_conferir(Vector2(fim.x - para.x, fim.z - para.z).length() < 3.5, "%s: o caminho chega à outra ponta" % rotulo)
			var desvio := _desvio_no_corredor(caminho, centro, eixo, comprimento)
			_conferir(desvio <= CORREDOR, "%s: o caminho se afasta %.2f do eixo da ponte (limite %.1f)" % [rotulo, desvio, CORREDOR])
			_conferir(not _ha_corpo_no_caminho(espaco, caminho, centro, eixo, comprimento), "%s: um ponto do caminho cai dentro de um corpo" % rotulo)
			# 3. O Pedro anda o caminho.
			var chegou: bool = await _andar(pedro, de, para, true)
			_conferir(chegou, "%s: o Pedro não chegou à outra ponta (parou em %s)" % [rotulo, str(pedro.global_position)])
			_conferir(not bool(pedro.get("_nadando")), "%s: o Pedro acabou nadando" % rotulo)
			# E o morador comum, pelo caminho da malha.
			var candinha_chegou: bool = await _andar(candinha, de, para, false)
			_conferir(candinha_chegou, "%s: a Candinha não chegou à outra ponta (parou em %s)" % [rotulo, str(candinha.global_position)])
	_conferir(provadas >= 1, "nenhuma ponte pervia foi provada")


## Algum ponto do caminho, na zona da ponte, cai dentro de um corpo sólido (fora o chão)?
func _ha_corpo_no_caminho(espaco: PhysicsDirectSpaceState3D, caminho: PackedVector3Array, centro: Vector3, eixo: Vector3, comprimento: float) -> bool:
	var e := Vector2(eixo.x, eixo.z).normalized()
	var esfera := SphereShape3D.new()
	esfera.radius = 0.3
	for p in caminho:
		var rel := Vector2(p.x - centro.x, p.z - centro.z)
		if absf(rel.dot(e)) > comprimento * 0.5 + 4.0:
			continue
		var pergunta := PhysicsShapeQueryParameters3D.new()
		pergunta.shape = esfera
		pergunta.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 0.95)
		pergunta.collision_mask = 1
		if not espaco.intersect_shape(pergunta, 1).is_empty():
			return true
	return false


## Põe `quem` em `de` e o faz andar até `para`, quadro a quadro, como o morador anda de verdade.
func _andar(quem: CharacterBody3D, de: Vector3, para: Vector3, pela_estrada: bool) -> bool:
	quem.collision_layer = 1
	quem.global_position = de + Vector3(0.0, 0.1, 0.0)
	quem.velocity = Vector3.ZERO
	quem.set("_prefere_a_estrada", pela_estrada)
	quem.set("_caminho_ate", Vector3.INF)
	quem.set("_preso", 0.0)
	quem.set("_parado", 0.0)
	await physics_frame
	var chegou := false
	for i in LIMITE_DE_QUADROS:
		await physics_frame
		var ponto: Vector3 = quem._ponto_do_caminho(para, PASSO)
		var rumo := Vector3(ponto.x - quem.global_position.x, 0.0, ponto.z - quem.global_position.z)
		quem._mover(rumo.normalized() if rumo.length() > 0.05 else Vector3.ZERO, 3.0, PASSO)
		if Vector2(quem.global_position.x - para.x, quem.global_position.z - para.z).length() < 1.5:
			chegou = true
			break
	quem.collision_layer = 0
	return chegou
