extends "res://tests/suite/caso.gd"
## A CONDUÇÃO DO PEDRO, DA CANDINHA À DONA ZEFA E DEPOIS (#237).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste conducao_candinha_zefa
##
## No passo 5/16 ("Siga o Pedro até a Dona Zefa e busque a chave") o Pedro entrava no corredor entre
## as cercas das roças, não passava, e o "Pedro voltou para te buscar" o levava de volta à cidade.
## As cercas ganharam corpo em 07 e 08/10, e o caminho pela estrada ligava os vértices da rua em reta,
## sem saber delas. Cada trecho da rua agora segue a malha (`NavegacaoVale._elo_da_rua`), e a rua que a
## malha não liga cai no caminho da malha inteiro.
##
##   1. OS VÃOS. Em nenhum ponto de nenhuma rua do vale (a cada 1,5 u da linha) há corpo de cerca de
##      roça no meio do caminho: onde a rua cruza uma cerca, a cerca abre.
##   2. A ROTA. Da praça à porta da Zefa, o caminho pela estrada chega, não passa por dentro de cerca
##      (nenhum ponto dele toca o corpo de uma) e não é um desvio: no máximo DESVIO_MAXIMO vezes a reta
##      mais a sobra.
##   3. A CONDUÇÃO, COM A FÍSICA E O CÓDIGO DE VERDADE. Cada passo com `conduz` da chegada, na ordem, com o
##      jogador colado atrás do Pedro: ele chega ao destino dentro do tempo-limite (a distância pela rota
##      a passo de ANDAR, e mais a folga), sem nenhum "voltou para te buscar" (o jogador nunca ficou para
##      trás, e então nenhuma volta é culpa da rota dele).

## Recebe o vale montado do zero: reprovava no vale deixado pelos casos anteriores (a suíte, #242).
const VALE_NOVO := true

const DESVIO_MAXIMO := 1.8
const SOBRA_DA_ROTA := 25.0
const PASSO_DA_RUA := 1.5
const ATRAS_DO_PEDRO := 2.5
const FOLGA_DO_TEMPO := 40.0
const ANDAR := 2.1

var falhas := 0
var voltas := 0


func _initialize() -> void:
	_run.call_deferred()
	create_timer(900).timeout.connect(func() -> void:
		print("FALHA: a condução excede o tempo de prova")
		quit(2))


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("CONDUCAO_CANDINHA_ZEFA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
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
	var jogador = vale.player
	var lugares = root.get_node("/root/Lugares")
	_conferir(pedro != null and jogador != null, "o vale tem o Pedro e o jogador")
	if pedro == null or jogador == null:
		quit(1)
		return
	var espaco: PhysicsDirectSpaceState3D = mundo.get_world_3d().direct_space_state

	_os_vaos(mundo, espaco)
	var praca: Vector3 = lugares.ponto("praca")
	var zefa: Vector3 = lugares.ponto("casa_da_zefa")
	_a_rota(navegacao, espaco, praca, zefa)

	# Só o Pedro e o jogador se mexem; os outros moradores não barram nem comentam.
	for pessoa in get_nodes_in_group("moradores"):
		if pessoa != pedro:
			pessoa.set_physics_process(false)
			pessoa.set_process(false)
			pessoa.collision_layer = 0
	pedro.esperando_quem_ficou.connect(func(esperando: bool) -> void:
		if esperando:
			voltas += 1)
	await _a_conducao(vale, mundo, pedro, jogador)
	print("CONDUCAO_CANDINHA_ZEFA: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


# --- 1. OS VÃOS -----------------------------------------------------------------------------

func _os_vaos(mundo, espaco: PhysicsDirectSpaceState3D) -> void:
	var regiao = mundo.get("_region")
	_conferir(regiao != null and "_roads" in regiao, "a região tem as ruas")
	if regiao == null or not ("_roads" in regiao):
		return
	var esfera := SphereShape3D.new()
	esfera.radius = 0.3
	var amostras := 0
	var barradas: Array[String] = []
	for rua in regiao._roads:
		var pontos: PackedVector2Array = (rua as Dictionary)["points"]
		for i in range(pontos.size() - 1):
			var a := pontos[i]
			var b := pontos[i + 1]
			var passos := maxi(1, ceili(a.distance_to(b) / PASSO_DA_RUA))
			for k in passos:
				var p := a.lerp(b, float(k) / float(passos))
				var chao: float = mundo.ground_height_at(Vector3(p.x, 0.0, p.y))
				var pergunta := PhysicsShapeQueryParameters3D.new()
				pergunta.shape = esfera
				pergunta.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, chao + 0.95, p.y))
				pergunta.collision_mask = 1
				amostras += 1
				for achado in espaco.intersect_shape(pergunta, 4):
					var corpo = achado.get("collider")
					if corpo is Node and (corpo as Node).is_in_group("cercas_do_paisagismo"):
						barradas.append("%s em (%.1f, %.1f)" % [str(rua.get("name", "rua")), p.x, p.y])
						break
	print("  vãos: %d pontos de rua, %d com cerca no meio" % [amostras, barradas.size()])
	_conferir(barradas.is_empty(), "%d ponto(s) de rua com corpo de cerca no meio, sem vão (ex.: %s)" % [barradas.size(), "; ".join(PackedStringArray(barradas.slice(0, 4)))])


# --- 2. A ROTA ------------------------------------------------------------------------------

func _a_rota(navegacao: Node, espaco: PhysicsDirectSpaceState3D, de: Vector3, para: Vector3) -> void:
	_conferir(de.is_finite() and para.is_finite(), "a praça e a casa da Zefa resolvem")
	if not de.is_finite() or not para.is_finite():
		return
	var caminho: PackedVector3Array = navegacao.caminho_pela_estrada(de, para)
	_conferir(caminho.size() >= 2, "há caminho pela estrada da praça à Zefa")
	if caminho.size() < 2:
		return
	var fim := caminho[caminho.size() - 1]
	_conferir(Vector2(fim.x - para.x, fim.z - para.z).length() < 3.5, "o caminho da praça chega à Zefa")
	var comprimento := _comprimento(caminho)
	var reta := Vector2(para.x - de.x, para.z - de.z).length()
	print("  rota praça → Zefa: %.1f u (reta %.1f)" % [comprimento, reta])
	_conferir(comprimento <= reta * DESVIO_MAXIMO + SOBRA_DA_ROTA, "o caminho da praça à Zefa é um desvio: %.1f u para %.1f de reta" % [comprimento, reta])
	var esfera := SphereShape3D.new()
	esfera.radius = 0.3
	var dentro := 0
	for i in range(caminho.size() - 1):
		var a := caminho[i]
		var b := caminho[i + 1]
		var passos := maxi(1, ceili(Vector2(b.x - a.x, b.z - a.z).length() / 0.75))
		for k in passos + 1:
			var pergunta := PhysicsShapeQueryParameters3D.new()
			pergunta.shape = esfera
			pergunta.transform = Transform3D(Basis.IDENTITY, a.lerp(b, float(k) / float(passos)) + Vector3.UP * 0.95)
			pergunta.collision_mask = 1
			for achado in espaco.intersect_shape(pergunta, 4):
				var corpo = achado.get("collider")
				if corpo is Node and (corpo as Node).is_in_group("cercas_do_paisagismo"):
					dentro += 1
					break
	_conferir(dentro == 0, "o caminho da praça à Zefa toca cerca em %d ponto(s)" % dentro)


# --- 3. A CONDUÇÃO --------------------------------------------------------------------------

func _a_conducao(vale: Node, mundo, pedro, jogador) -> void:
	var passos: Array = []
	for passo in pedro.MISSOES:
		if bool((passo as Dictionary).get("conduz", false)):
			passos.append(str((passo as Dictionary).get("id", "")))
	_conferir(passos.has("chave_zefa"), "o passo da Zefa é conduzido")
	pedro._iniciado = true
	var tempo_total := 0.0
	for id in passos:
		if not pedro.ir_ao_passo(id):
			_conferir(false, "o passo %s existe" % id)
			continue
		pedro.retomar()
		var destino: Vector3 = pedro._destino_da_conducao()
		if not destino.is_finite():
			_conferir(false, "o passo %s tem destino" % id)
			continue
		var falta := Vector2(destino.x - pedro.global_position.x, destino.z - pedro.global_position.z).length()
		if falta <= 8.0:
			print("  passo %s: o Pedro já está a %.1f u do destino" % [id, falta])
			continue
		var rota: PackedVector3Array = vale.navegacao.caminho_pela_estrada(pedro.global_position, destino)
		var limite_s := _comprimento(rota) / ANDAR + FOLGA_DO_TEMPO if rota.size() >= 2 else falta * 3.0 / ANDAR + FOLGA_DO_TEMPO
		var voltas_antes := voltas
		var inicio := Time.get_ticks_msec()
		var chegou: bool = await _conduzir_ate_chegar(mundo, pedro, jogador, destino, limite_s)
		var gasto := float(Time.get_ticks_msec() - inicio) / 1000.0
		tempo_total += gasto
		print("  passo %s: %s em %.0f s de jogo (limite %.0f, rota %.0f u)" % [id, "chegou" if chegou else "NÃO chegou", gasto, limite_s, _comprimento(rota)])
		_conferir(chegou, "passo %s: o Pedro não chegou a %s em %.0f s (parou em %s)" % [id, str(destino), limite_s, str(pedro.global_position)])
		_conferir(voltas == voltas_antes, "passo %s: o Pedro voltou para buscar o jogador, que ia colado atrás dele" % id)
	print("  condução inteira: %.0f s de jogo" % tempo_total)


## Deixa o Pedro conduzir pelo código de verdade (`_physics_process`), com o jogador sempre ATRAS_DO_PEDRO
## atrás dele pela trilha que ele deixou; devolve se ele chegou ao destino dentro de `limite_s` de jogo.
func _conduzir_ate_chegar(mundo, pedro, jogador, destino: Vector3, limite_s: float) -> bool:
	var trilha := PackedVector3Array([pedro.global_position])
	var quadros := int(limite_s * 60.0) + 120
	for i in quadros:
		await physics_frame
		if pedro.global_position.distance_to(trilha[trilha.size() - 1]) > 0.25:
			trilha.append(pedro.global_position)
		jogador.global_position = _atras(trilha, pedro.global_position, destino, mundo)
		jogador.velocity = Vector3.ZERO
		if pedro._chegou_ao_destino():
			return true
	return false


## O ponto da trilha mais recente que fica a ATRAS_DO_PEDRO ou mais dele; sem trilha ainda, atrás dele no rumo
## contrário ao destino.
func _atras(trilha: PackedVector3Array, onde: Vector3, destino: Vector3, mundo) -> Vector3:
	for i in range(trilha.size() - 1, -1, -1):
		if Vector2(trilha[i].x - onde.x, trilha[i].z - onde.z).length() >= ATRAS_DO_PEDRO:
			return trilha[i] + Vector3(0.0, 0.1, 0.0)
	var rumo := Vector3(onde.x - destino.x, 0.0, onde.z - destino.z).normalized()
	return mundo.ground_position(onde + rumo * ATRAS_DO_PEDRO, 0.1)


func _comprimento(pontos: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, pontos.size()):
		total += Vector2(pontos[i].x - pontos[i - 1].x, pontos[i].z - pontos[i - 1].z).length()
	return total
