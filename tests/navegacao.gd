extends SceneTree
## Confere A MALHA DE NAVEGAÇÃO DOS MORADORES (navegacao_vale.gd).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/navegacao.gd
##
## Cinco perguntas:
##
##   1. A MALHA FICA PRONTA logo depois de o vale montar, e cobre os lugares
##      por onde os moradores andam.
##   2. HÁ CAMINHO entre os postos e os marcos da festa — da casa da estrada ao
##      cruzeiro, do píer à gameleira, da casa de taipa ao terreiro —, e ele
##      chega lá.
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

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("NAVEGACAO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(8)
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
	var caminhos := {}
	for par in pares:
		var de: Vector3 = world.ground_position(a[par[0]] + Vector3(0, 0, 0), 0.0) if par[0] != "PierPiso" else a[par[0]]
		var para: Vector3 = a[par[1]]
		var caminho: PackedVector3Array = navegacao.caminho(de, para)
		caminhos["%s → %s" % par] = caminho
		_conferir(caminho.size() >= 2, "não há caminho de %s a %s" % par)
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
					no_rio = true
					_conferir(false, "o caminho %s atravessa o rio a pé em (%.1f, %.1f), e não pela ponte" % [nome, ponto.x, ponto.z])
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
		_conferir(mais_perto < 1.5,
			"da Dona Candinha à Dona Zefa o caminho passa a %.1f da ponte do rio central: o Pedro não leva o jogador pela ponte" % mais_perto)

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
	_fechar()


func _plano(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _ate(condicao: Callable, segundos: float) -> bool:
	var ate := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < ate:
		if bool(condicao.call()):
			return true
		await process_frame
	return bool(condicao.call())


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("NAVEGACAO_OK: a malha fica pronta depois de o vale montar; há caminho entre os postos e os marcos da festa e ele chega; não desce ao mar, não atravessa casa, tronco nem rio a pé; da Dona Candinha à Dona Zefa passa pela ponte do rio central; da praça ao altar passa-se pela porta; e o morador contorna a casa que em linha reta o prendia")
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
