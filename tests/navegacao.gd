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

	# --- 2. HÁ CAMINHO, E ELE CHEGA ----------------------------------------------
	var pares := [["Casa da estrada", "Cruzeiro"], ["PierPiso", "Gameleira"], ["Casa de taipa", "Terreiro"],
		["Cemitério", "Igreja"], ["Lavoura", "Poço"], ["Casa de Carro Quebrado", "Bar"]]
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
	for nome in caminhos:
		var caminho: PackedVector3Array = caminhos[nome]
		for k in range(1, caminho.size()):
			var de: Vector3 = caminho[k - 1]
			var para: Vector3 = caminho[k]
			var passos := maxi(1, int(de.distance_to(para) / 0.5))
			for i in passos + 1:
				var ponto := de.lerp(para, float(i) / float(passos))
				_conferir(ponto.y > agua - 0.05, "o caminho %s desce ao fundo do mar em %s" % [nome, str(ponto)])
				for tronco in world._region._tree_trunks:
					var p: Vector2 = tronco.get("point", Vector2.INF)
					if p.distance_to(Vector2(ponto.x, ponto.z)) < float(tronco.get("radius", 0.3)) - 0.05:
						_conferir(false, "o caminho %s atravessa um tronco da mata em %s" % [nome, str(p)])
		var espaco: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
		for k in range(1, caminho.size()):
			var raio := PhysicsRayQueryParameters3D.create(caminho[k - 1] + Vector3.UP * 0.9, caminho[k] + Vector3.UP * 0.9, 1)
			var batida := espaco.intersect_ray(raio)
			if not batida.is_empty():
				var corpo = batida.get("collider")
				_conferir(false, "o caminho %s atravessa %s" % [nome, str(corpo.get_path()) if corpo is Node else str(corpo)])
				break

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
		print("NAVEGACAO_OK: a malha fica pronta depois de o vale montar; há caminho entre os postos e os marcos da festa e ele chega; não desce ao mar, não atravessa casa nem tronco; da praça ao altar passa-se pela porta; e o morador contorna a casa que em linha reta o prendia")
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
