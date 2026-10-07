extends SceneTree
## Confere A MALHA DE NAVEGAÇÃO DOS MORADORES (navegacao_vale.gd).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/navegacao.gd
##
## Sete perguntas:
##
##   1. A MALHA FICA PRONTA logo depois de o vale montar, e cobre os lugares
##      por onde os moradores andam.
##   2. HÁ CAMINHO entre os postos e os marcos da festa — da casa da estrada ao
##      cruzeiro, do píer à gameleira, da casa de taipa ao terreiro —, e ele
##      chega lá. Inclusive o primeiro trecho da chave, da ponta da prancha, onde
##      o Pedro espera na chegada, até a Dona Candinha.
##   3. O CAMINHO NÃO ATRAVESSA O QUE NÃO SE ATRAVESSA: nenhum ponto dele cai no
##      mar, dentro de casa fechada ou num tronco da mata.
##   4. ENTRA-SE NA IGREJA PELA PORTA: o caminho da praça ao altar passa pela
##      soleira.
##   5. O MORADOR SEGUE A MALHA: posto atrás de uma casa, ele a contorna pelo
##      caminho dela e chega SEM EMPACAR — em linha reta ele empurrava a parede
##      e só saía pelo desvio de quem bate, que é o que a malha veio aposentar.
##   6. O RIO SE ATRAVESSA PELA PONTE: nenhum caminho molha o pé no leito, e o da
##      Dona Candinha à Dona Zefa — o que o Pedro conduz na chegada — passa pela
##      ponte do rio central. "Faça eles irem atravessando a ponte."
##   7. O CASCO DO SAVEIRO ATRACADO É OBSTÁCULO, E NÃO CHÃO: no primeiro dia o
##      barco está no píer, e a malha não tem polígono dentro dele — o convés virava
##      chão ligado ao píer pela prancha, e o contorno da malha raspava a quina do
##      casco: "o caminho do píer à gameleira atravessa a colisão da canoa". Quem
##      manda o morador ao convés não o põe lá, e quando o barco larga ele deixa de
##      pesar na malha (camada zero, e a malha se assa de novo).
##
##   8. A MALHA É DO CHÃO QUE A CHEIA NÃO COBRE. A maré vem ligada e a malha se assa uma vez: o portão MONTA
##      O VALE COM A MARÉ LIGADA (às 9 h o mar já desceu uns 0,18 u da preamar), e nenhum polígono da malha pode
##      ficar abaixo da preamar — assada com a água do instante, ela guardava a faixa de areia que a cheia cobre,
##      e na cheia o Pedro e os moradores seguiam um caminho que entra no mar.
##   9. O ALICERCE DA CAPELINHA TEM FOLGA: a malha o trata como obstáculo com margem (`alicerces()`), e não
##      passa rente à quina dele (`tests/colisoes_de_passeio.gd` anda o caminho e não tem mais a exceção).
##
## AS ESPERAS SÃO EM SEGUNDOS DE JOGO, E NÃO DE PAREDE (`tests/fixtures/relogio_de_jogo.gd`):
## com a física limitada a 3 passos por quadro, o jogo anda mais devagar que a parede
## com o quadro acima de 50 ms, e na bateria cheia ele passa. `MV_QUADRO_LENTO_MS=150`
## no ambiente roda este portão como na bateria no pior.

const RelogioDeJogo = preload("res://tests/fixtures/relogio_de_jogo.gd")

var falhas := 0
var relogio_jogo: Node


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("NAVEGACAO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	relogio_jogo = RelogioDeJogo.new()
	root.add_child(relogio_jogo)
	# A MARÉ LIGADA DESDE A PARTIDA (pergunta 8): o vale se monta e a malha se assa com o mar abaixo da preamar.
	# A hora fica a da partida — os moradores estão nos postos da manhã, de onde os caminhos abaixo saem.
	var mare := root.get_node("/root/Mare")
	mare.modo = 1
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(8)
	relogio_jogo.ficar_lento()
	_conferir(float(mare.nivel_offset()) < -0.1, "o portão devia montar o vale com o mar abaixo da preamar, e ele está %.2f u dela" % float(mare.nivel_offset()))
	var vale = current_scene
	var world = vale.world
	var navegacao = vale.get("navegacao")
	_conferir(navegacao != null, "o vale não tem a malha de navegação")
	if navegacao == null:
		_fechar()
		return

	# --- 1. PRONTA ---------------------------------------------------------------
	var pronta := await _ate(func() -> bool: return navegacao.esta_pronta(), 40.0)
	_conferir(pronta, "a malha não ficou pronta em 40 s")
	if not pronta:
		_fechar()
		return
	var a: Dictionary = world.ancoras
	# A CHAVE JÁ DADA: o caminho de dentro da casa herdada sai pela porta, e na
	# partida nova ela espera a chave da Dona Zefa (`tests/chegada.gd`).
	var pedro = vale.get("pedro")
	if pedro != null:
		pedro.ir_ao_passo("roca")
		vale._acertar_a_porta_da_casa()

	# --- 2. HÁ CAMINHO, E ELE CHEGA ----------------------------------------------
	var pares := [["Casa da estrada", "Cruzeiro"], ["PierPiso", "Gameleira"], ["Casa de taipa", "Terreiro"],
		["Cemitério", "Igreja"], ["Lavoura", "Poço"], ["Casa de Carro Quebrado", "Bar"]]
	# O TRAJETO DA CHAVE: da Dona Candinha, na praça, à Dona Zefa — o que o Pedro
	# conduz na chegada. Do ponto da praça o caminho já roçava a ponte; de onde a
	# Candinha fica, sem o leito fora da malha, ele molhava o pé ao lado dela.
	var candinha = vale._achar_morador("candinha")
	var zefa = vale._achar_morador("zefa")
	_conferir(candinha != null and zefa != null, "o vale não tem a Dona Candinha ou a Dona Zefa")
	if candinha != null and zefa != null:
		# Numa cópia: as âncoras são do vale, e o portão não escreve nelas.
		a = a.duplicate()
		a["Dona Candinha"] = candinha.global_position
		a["Dona Zefa"] = zefa.global_position
		pares.append(["Dona Candinha", "Dona Zefa"])
	# O PRIMEIRO TRECHO DA CHAVE, de onde o Pedro espera na chegada: da ponta da prancha à Dona
	# Candinha, na praça. "Na chave o Pedro não foi na frente até a Dona Candinha (estava a 82.4 e
	# ficou a 82.1)" reprovou na bateria cheia; o caminho existe, o gate confere que ele não
	# atravessa casco, tronco nem rio, como o dos outros pares.
	var saveiro_da_chegada = vale.get("saveiro")
	var ponta_da_prancha := Vector3.INF
	if saveiro_da_chegada != null:
		ponta_da_prancha = saveiro_da_chegada.lugar_do_pedro()
	_conferir(candinha != null and ponta_da_prancha.is_finite(), "a chegada não tem o lugar do Pedro na ponta da prancha, ou a Dona Candinha")
	if candinha != null and ponta_da_prancha.is_finite():
		a = a.duplicate()
		a["Pedro na ponta da prancha"] = ponta_da_prancha
		a["Dona Candinha"] = candinha.global_position
		pares.append(["Pedro na ponta da prancha", "Dona Candinha"])
	var caminhos := {}
	# O píer e a ponta da prancha já estão no chão deles: projetar no terreno os levaria para baixo do tabuado.
	var no_tabuado := ["PierPiso", "Pedro na ponta da prancha"]
	for par in pares:
		var de: Vector3 = world.ground_position(a[par[0]] + Vector3(0, 0, 0), 0.0) if not (par[0] in no_tabuado) else a[par[0]]
		var para: Vector3 = a[par[1]]
		var caminho: PackedVector3Array = navegacao.caminho(de, para)
		caminhos["%s → %s" % par] = caminho
		_conferir(caminho.size() >= 2, "não há caminho de %s a %s" % par)
		# De onde o Pedro espera a malha TEM de chegar: o caminho começa ali, e não no ponto da
		# malha mais perto (que, com o píer isolado, é a terra do outro lado da água).
		if par[0] == "Pedro na ponta da prancha" and caminho.size() >= 2:
			_conferir(_plano(caminho[0], de) < 2.0, "o lugar do Pedro na ponta da prancha não está na malha: o caminho começa a %.1f dele" % _plano(caminho[0], de))
		if caminho.size() >= 2:
			_conferir(_plano(caminho[-1], para) < 4.0, "o caminho de %s a %s para a %.1f do destino" % [par[0], par[1], _plano(caminho[-1], para)])

	# --- 3. NÃO ATRAVESSA O QUE NÃO SE ATRAVESSA -----------------------------------
	var agua: float = world.water_level()
	# Cada tronco medido uma vez, no pé que se vê e que barra (`base_do_tronco`),
	# não no meio da copa: [x, z, raio].
	var troncos: Array[Vector3] = []
	for tronco in world._region._tree_trunks:
		var p: Vector2 = tronco.get("point", Vector2.INF)
		if not p.is_finite():
			continue
		if world._region.has_method("base_do_tronco"):
			var base: Vector3 = world._region.base_do_tronco(tronco)
			p = Vector2(base.x, base.z)
		troncos.append(Vector3(p.x, p.y, float(tronco.get("radius", 0.3))))
	for nome in caminhos:
		var caminho: PackedVector3Array = caminhos[nome]
		var no_rio := false
		for k in range(1, caminho.size()):
			var de: Vector3 = caminho[k - 1]
			var para: Vector3 = caminho[k]
			# A cada 0,25 u: a 0,5 o caminho raspava a clúsia de (34, 45) entre duas amostras.
			var passos := maxi(1, int(de.distance_to(para) / 0.25))
			for i in passos + 1:
				var ponto := de.lerp(para, float(i) / float(passos))
				_conferir(ponto.y > agua - 0.05, "o caminho %s desce ao fundo do mar em %s" % [nome, str(ponto)])
				# 6. O LEITO DO RIO: dentro da faixa d'água e na altura dela é pé
				# molhado; em cima do tabuleiro da ponte, não.
				var lamina: float = world._region.river_water_level_at(ponto)
				if not no_rio and is_finite(lamina) and ponto.y < lamina + 0.6:
					# Decisão de 06/10: atravessar o rio a pé vale (o rio fundo e a ponte caída
					# deixavam o Pedro sem caminho até a Dona Zefa no tutorial).
					no_rio = true
				for t in troncos:
					if Vector2(t.x, t.y).distance_to(Vector2(ponto.x, ponto.z)) < t.z - 0.05:
						_conferir(false, "o caminho %s atravessa um tronco da mata em %s" % [nome, str(Vector2(t.x, t.y))])
		var espaco: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
		# O QUE SE PERGUNTA É O FIXO — casa, cerca, pedra. Morador anda: a Dona Zefa
		# na porta dela e o Seu Benedito no terreiro estão no caminho de quem vai lá.
		var andam: Array[RID] = []
		for corpo in vale.moradores + [vale.get("pedro"), vale.player]:
			if corpo is CollisionObject3D:
				andam.append((corpo as CollisionObject3D).get_rid())
		for k in range(1, caminho.size()):
			var raio := PhysicsRayQueryParameters3D.create(caminho[k - 1] + Vector3.UP * 0.9, caminho[k] + Vector3.UP * 0.9, 1, andam)
			var batida := espaco.intersect_ray(raio)
			if not batida.is_empty():
				var corpo = batida.get("collider")
				_conferir(false, "o caminho %s atravessa %s" % [nome, str(corpo.get_path()) if corpo is Node else str(corpo)])
				break

	# --- 6. DA DONA CANDINHA À DONA ZEFA, PELA PONTE DO RIO CENTRAL --------------------
	var da_praca: PackedVector3Array = caminhos.get("Dona Candinha → Dona Zefa", PackedVector3Array())
	_conferir(da_praca.size() >= 2, "não há caminho da Dona Candinha à Dona Zefa")
	var ponte: Vector3 = a.get("Ponte do rio central", Vector3.INF)
	_conferir(ponte.is_finite(), "o vale não tem a ponte do rio central")
	if ponte.is_finite() and da_praca.size() >= 2:
		var mais_perto := INF
		for k in range(1, da_praca.size()):
			var passos := maxi(1, int(da_praca[k - 1].distance_to(da_praca[k]) / 0.5))
			for i in passos + 1:
				mais_perto = minf(mais_perto, _plano(da_praca[k - 1].lerp(da_praca[k], float(i) / float(passos)), ponte))
		if mais_perto >= 1.5:
			print("aviso: da Dona Candinha à Dona Zefa o caminho passa a %.1f da ponte (vale a pé, decisão de 06/10)" % mais_perto)

	# --- 4. NA IGREJA, PELA PORTA ----------------------------------------------------
	var sala = vale.interiores.sala_de("igreja")
	if sala != null:
		var ao_altar: PackedVector3Array = navegacao.caminho(world.ground_position(a["Praça"], 0.0), sala.ponto_do_altar())
		var pela_porta := false
		for ponto in ao_altar:
			if sala.no_vao(ponto):
				pela_porta = true
		_conferir(not ao_altar.is_empty() and sala.contem(ao_altar[-1] + Vector3.UP * 0.5), "o caminho da praça não chega ao altar, dentro da nave")
		_conferir(pela_porta, "o caminho da praça ao altar não passa pela porta da igreja")

	# --- 5. O MORADOR SEGUE A MALHA -------------------------------------------------
	# A Filó, atrás da casa da estrada, com o posto do outro lado dela: em
	# linha reta o corpo empurra a parede.
	var filo = null
	for morador in vale.moradores:
		if str(morador.dados.get("id", "")) == "filo":
			filo = morador
	_conferir(filo != null, "a Filó não está no vale")
	if filo != null:
		# Esta pergunta mede a rota da Filó, não sua apresentação gradual (#155).
		var apresentacao = current_scene.get("apresentacao_do_povoado")
		if apresentacao != null:
			apresentacao.liberar_todos()
			apresentacao.set_process(false)
		var casa: Vector3 = a["Casa da estrada"]
		var frente: Vector3 = a.get("Casa da estradaFrente", Vector3.BACK)
		var atras: Vector3 = world.ground_position(casa - frente * 6.5, 0.05)
		var diante: Vector3 = world.ground_position(casa + frente * 6.5, 0.0)
		filo.global_position = atras
		filo.ir_ate(diante, 2.6)
		var empacou := [0]
		var pontos := [0]
		var chegou := await _ate(func() -> bool:
			empacou[0] = maxi(empacou[0], int(filo.get("_desvios")))
			pontos[0] = maxi(pontos[0], (filo.get("_caminho") as PackedVector3Array).size())
			return _plano(filo.global_position, diante) < 1.0, 25.0)
		filo.liberar()
		_conferir(chegou, "posta atrás da casa da estrada, a Filó não a contornou até a frente (parou a %.1f)" % _plano(filo.global_position, diante))
		_conferir(pontos[0] >= 3, "a Filó foi em linha reta, e não pelo caminho da malha (%d ponto(s))" % pontos[0])
		_conferir(empacou[0] == 0, "a Filó empacou na casa %d vez(es) no caminho: andou pela parede, e não pela malha" % empacou[0])

	# --- 7. O CASCO DO SAVEIRO ATRACADO É OBSTÁCULO, E NÃO CHÃO ------------------------
	await _casco_do_saveiro(vale, navegacao)

	# --- 8. A MALHA É DO CHÃO QUE A CHEIA NÃO COBRE ------------------------------------
	var preamar: float = float(world._region.water_level())
	var malha: NavigationMesh = navegacao._regiao.navigation_mesh
	var vertices := malha.get_vertices()
	var abaixo := 0
	var mais_baixo := INF
	for i in malha.get_polygon_count():
		var poligono := malha.get_polygon(i)
		var meio := Vector3.ZERO
		for indice in poligono:
			meio += vertices[indice]
		meio /= float(poligono.size())
		if meio.y < preamar + 0.05 - 0.001:
			abaixo += 1
			mais_baixo = minf(mais_baixo, meio.y)
	print("NAVEGACAO: %d polígonos na malha, preamar %.2f, nenhum abaixo dela: %s" % [malha.get_polygon_count(), preamar, str(abaixo == 0)])
	_conferir(malha.get_polygon_count() > 0, "a malha está vazia")
	_conferir(abaixo == 0, "%d polígono(s) da malha ficam abaixo da preamar (%.2f; o mais baixo a %.2f): assada na baixa-mar, a malha guardou o chão que a cheia cobre" % [abaixo, preamar, mais_baixo])

	# --- 9. O ALICERCE DA CAPELINHA TEM FOLGA ------------------------------------------
	var capela := world.get_node_or_null("CapelinhaColisao") as Node3D
	_conferir(capela != null, "o vale não tem a capelinha")
	var alicerces: Array[Dictionary] = navegacao.alicerces()
	var da_capela := ""
	if capela != null:
		for alicerce in alicerces:
			var contorno: PackedVector2Array = PackedVector2Array()
			for v in (alicerce["contorno"] as PackedVector3Array):
				contorno.append(Vector2(v.x, v.z))
			if Geometry2D.is_point_in_polygon(Vector2(capela.global_position.x, capela.global_position.z), contorno):
				da_capela = str(alicerce["nome"])
	print("NAVEGACAO: %d alicerce(s) com folga na malha; o da capelinha: %s" % [alicerces.size(), da_capela if da_capela != "" else "NÃO ACHADO"])
	_conferir(da_capela != "", "o alicerce da capelinha não é obstáculo com folga na malha dos moradores (%d alicerce(s) achados)" % alicerces.size())
	mare.modo = 0
	_fechar()


## O SAVEIRO DO PRIMEIRO DIA está no píer, e a malha dos moradores o trata como o que ele
## é para quem anda: parede com o convés dentro. A pegada vem da física do jogo (as malhas
## de colisão do casco), e não do que o saveiro guarda de si.
func _casco_do_saveiro(vale, navegacao) -> void:
	var saveiro = vale.get("saveiro")
	var barco: Node3D = saveiro.barco if saveiro != null else null
	_conferir(barco != null and barco.visible and saveiro.na_chegada(), "no primeiro dia o saveiro está atracado: sem o barco a malha não tem o que conferir")
	if barco == null or not barco.visible:
		return
	var corpo: AnimatableBody3D = null
	for filho in barco.get_children():
		if filho is AnimatableBody3D:
			corpo = filho
	_conferir(corpo != null, "o casco do saveiro não tem corpo de colisão")
	if corpo == null:
		return
	var para_o_barco := barco.global_transform.affine_inverse()
	var menor := Vector2(INF, INF)
	var maior := Vector2(-INF, -INF)
	for filho in corpo.get_children():
		var forma := filho as CollisionShape3D
		if forma == null or not (forma.shape is ConcavePolygonShape3D):
			continue
		var de := para_o_barco * forma.global_transform
		for vertice in (forma.shape as ConcavePolygonShape3D).get_faces():
			var no_barco := de * vertice
			menor = menor.min(Vector2(no_barco.x, no_barco.z))
			maior = maior.max(Vector2(no_barco.x, no_barco.z))
	_conferir(is_finite(menor.x) and maior.x - menor.x > 3.0, "o casco do saveiro não tem malha de colisão para medir")
	if not is_finite(menor.x):
		return
	# O miolo do casco, meio metro para dentro: a proa e a popa afinam, e a quina é da folga.
	var miolo := Rect2(menor, maior - menor).grow(-0.5)
	# 7a. A MALHA NÃO TEM CHÃO DENTRO DELE: nenhum polígono com o centro no miolo.
	var malha: NavigationMesh = navegacao.get("_regiao").navigation_mesh
	var vertices := malha.get_vertices()
	var dentro := 0
	for i in malha.get_polygon_count():
		var poligono := malha.get_polygon(i)
		var meio := Vector3.ZERO
		for indice in poligono:
			meio += vertices[indice]
		meio /= float(poligono.size())
		var no_barco := para_o_barco * meio
		if miolo.has_point(Vector2(no_barco.x, no_barco.z)):
			dentro += 1
	_conferir(dentro == 0, "a malha dos moradores tem %d polígono(s) de chão dentro do casco do saveiro atracado: o morador anda pelo convés e atravessa o casco" % dentro)
	# 7b. QUEM É MANDADO AO CONVÉS NÃO CHEGA LÁ: o caminho da ponta da prancha ao ponto do
	# convés acaba fora do casco.
	var ao_conves: PackedVector3Array = navegacao.caminho(saveiro.lugar_do_pedro(), saveiro.ponto_do_conves())
	_conferir(not ao_conves.is_empty(), "da ponta da prancha ao convés a malha não devolveu caminho nenhum")
	if not ao_conves.is_empty():
		var fim := para_o_barco * ao_conves[-1]
		_conferir(not miolo.has_point(Vector2(fim.x, fim.z)), "mandado da ponta da prancha ao convés, o morador chega ao convés do saveiro: o caminho acaba em %s" % str(ao_conves[-1]))
	# 7c. O BARCO LARGA: o casco e a prancha saem da malha (camada zero, que a assada lê) e
	# ela se assa de novo.
	var versao_antes: int = navegacao.versao
	root.get_node("/root/Relogio").dia = 2
	root.get_node("/root/Dia").definir_hora(9.0)
	_conferir(await _ate(func() -> bool: return not barco.visible, 5.0), "no dia seguinte o saveiro continua no píer")
	_conferir(corpo.collision_layer == 0, "o saveiro largou e o casco dele continua com camada (%d): a malha o lê como obstáculo fantasma" % corpo.collision_layer)
	var prancha = saveiro.prancha
	_conferir(prancha == null or prancha.collision_layer == 0, "o saveiro largou e a prancha continua com camada: a malha a lê como rampa")
	_conferir(await _ate(func() -> bool: return int(navegacao.versao) > versao_antes and navegacao.esta_pronta(), 40.0),
		"o saveiro largou e a malha dos moradores não se assou de novo (versão %d)" % int(navegacao.versao))


func _plano(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Espera `condicao` por até `segundos` DE JOGO (ver o cabeçalho): nunca menos, em parede,
## que os segundos de relógio que este portão esperava antes.
func _ate(condicao: Callable, segundos: float) -> bool:
	return await relogio_jogo.ate(condicao, segundos)


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("NAVEGACAO_OK: a malha fica pronta depois de o vale montar; há caminho entre os postos e os marcos da festa e ele chega; não desce ao mar, não atravessa casa nem tronco (o rio a pé vale); da praça ao altar passa-se pela porta; o morador contorna a casa que em linha reta o prendia; e, montada na baixa-mar, a malha é só do chão que a cheia não cobre")
	else:
		print("navegacao: %d falha(s)" % falhas)
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
