extends SceneTree
## Confere A LAVOURA DA CASA (#8): a fazenda do jogador, na frente da casa
## herdada, com a regra do roçado do 2D.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/lavoura.gd
##
## Oito perguntas:
##
##   1. A LAVOURA ESTÁ NA FRENTE DA CASA, em terra, plana e livre: nenhum leito
##      embaixo de árvore, pedra, cerca ou parede, nenhum dentro da casa — e
##      nenhum alvo de trabalho dentro dela ou na beira, que no campo a tecla é
##      da lavoura e ele ficaria sem tecla.
##   2. O GESTO É O DA MÃO: de mão livre o chão bruto não se ara; a enxada ara
##      e gasta fôlego; a semente planta e gasta uma; o balde molha.
##   3. O DIA QUE VIRA FAZ CRESCER O REGADO, e só ele: o leito seco não anda, e
##      todo leito amanhece seco.
##   4. MADURO SE COLHE: o milho regado todo dia chega ao ponto, e colher dá o
##      milho com a qualidade do cuidado, mais a semente de volta.
##   5. A CANA REBROTA: colhida, volta ao toco e passa a carência sem carregar.
##   6. O INVERNO PARA A ROÇA: regada, a planta não anda.
##   7. NO CAMPO A TECLA É DA LAVOURA: os alvos de trabalho em volta calam.
##   8. O SAVE GUARDA A LAVOURA inteira, e ela volta desenhada.
##   9. A TERRA É DE VERDADE E O CAMPO É CERCADO: grão e torrão no leito, os
##      camalhões no arado, a terra batida por baixo, e a cerca rasteira em volta
##      de todos os leitos, abaixo do degrau, com a passagem do lado da casa.

var falhas := 0
var vale
var lavoura
var inventario
var relogio
var energia


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("LAVOURA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	inventario = root.get_node("/root/Inventario")
	relogio = root.get_node("/root/Relogio")
	energia = root.get_node("/root/Energia")
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(8)
	vale = current_scene
	lavoura = vale.get("lavoura")
	var jogador = vale.get("player")
	var world = vale.world
	_conferir(lavoura != null, "o vale não tem a lavoura")
	if lavoura == null:
		_fechar()
		return
	relogio.estacao = 0
	var plantacao = lavoura.plantacao

	# --- 1. NA FRENTE DA CASA, EM TERRA, PLANA E LIVRE ---------------------------
	var casa: Vector3 = world.ancoras["Casa de taipa"]
	var frente: Vector3 = world.ancoras.get("Casa de taipaFrente", Vector3.BACK)
	var espaco: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var alturas: Array[float] = []
	for y in lavoura.LINHAS:
		for x in lavoura.COLUNAS:
			var celula := Vector2i(x, y)
			var onde: Vector3 = lavoura.posicao_da(celula)
			alturas.append(onde.y)
			_conferir(world.is_on_land(onde), "o leito %s não está em terra firme" % str(celula))
			_conferir((onde - casa).dot(frente) > 5.0, "o leito %s não está na frente da casa" % str(celula))
			_conferir(vale.interiores.contem(onde + Vector3.UP) == "", "o leito %s está dentro de uma construção" % str(celula))
			var corpo := CapsuleShape3D.new()
			corpo.radius = 0.3
			corpo.height = 1.6
			var pergunta := PhysicsShapeQueryParameters3D.new()
			pergunta.shape = corpo
			pergunta.transform = Transform3D(Basis(), onde + Vector3.UP * 0.95)
			pergunta.collision_mask = 1
			var fora: Array[RID] = [jogador.get_rid()]
			for morador in vale.moradores:
				fora.append(morador.get_rid())
			if vale.get("pedro") != null:
				fora.append(vale.pedro.get_rid())
			pergunta.exclude = fora
			var toques: Array = espaco.intersect_shape(pergunta, 2)
			_conferir(toques.is_empty(), "o leito %s esbarra em %s" % [str(celula),
				str(toques[0].get("collider").get_path()) if not toques.is_empty() and toques[0].get("collider") is Node else "?"])
			for tronco in world._region._tree_trunks:
				var p: Vector2 = tronco.get("point", Vector2.INF)
				_conferir(p.distance_to(Vector2(onde.x, onde.z)) > 0.9, "há um tronco no leito %s" % str(celula))
	alturas.sort()
	_conferir(alturas[-1] - alturas[0] < 0.8, "a lavoura não é plana: %.2f de desnível" % (alturas[-1] - alturas[0]))
	var alvos = vale.get_node_or_null("Recursos3D")
	if alvos != null:
		for id in alvos._alvos:
			var alvo: Dictionary = alvos._alvos[id]
			var centro: Vector3 = alvo["pos"]
			var encosta := float(alvo.get("meia_pegada", 0.0)) + 0.28
			for lado in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
				if lavoura.no_campo(centro + lado * encosta):
					_conferir(false, "o alvo '%s' fica dentro da lavoura ou na beira: no campo a tecla é dela, e ele fica sem tecla" % id)
					break

	# --- 2. O GESTO É O DA MÃO ----------------------------------------------------
	var a := Vector2i(1, 1)
	var b := Vector2i(2, 1)
	inventario.selecionar(inventario.MAO_LIVRE)
	lavoura.usar(a)
	_conferir(not plantacao.arado(a), "de mão livre, o chão bruto foi arado")
	_na_mao("enxada")
	energia.atual = 50.0
	lavoura.usar(a)
	_conferir(plantacao.arado(a), "com a enxada na mão, o leito não foi arado")
	_conferir(energia.atual < 50.0, "arar não gastou fôlego")
	lavoura.usar(b)
	_na_mao("semente_milho", 3)
	var sementes: int = inventario.quantidade("semente_milho")
	lavoura.usar(a)
	_conferir(plantacao.cultura_em(a) == "milho", "a semente na mão não plantou milho")
	_conferir(inventario.quantidade("semente_milho") == sementes - 1, "plantar não gastou uma semente")
	lavoura.usar(b)
	_na_mao("balde")
	lavoura.usar(a)
	_conferir(plantacao.molhado(a), "o balde na mão não molhou o leito")
	await _frames(2)
	_conferir(_desenho(a) == "milho:0", "o leito plantado não desenhou a planta (%s)" % _desenho(a))

	# --- 3. O DIA QUE VIRA ------------------------------------------------------------
	relogio.dormir()
	await _frames(2)
	_conferir(plantacao.estagio(a) == 1, "regado, o milho não cresceu no dia novo (estágio %d)" % plantacao.estagio(a))
	_conferir(plantacao.estagio(b) == 0, "seco, o milho cresceu assim mesmo")
	_conferir(not plantacao.molhado(a), "o leito amanheceu molhado")
	_conferir(_desenho(a) == "milho:1", "o milho cresceu e o desenho não (%s)" % _desenho(a))

	# --- 4. MADURO SE COLHE -------------------------------------------------------------
	while not plantacao.maduro(a):
		plantacao.regar(a)
		relogio.dormir()
		await _frames(1)
	inventario.selecionar(inventario.MAO_LIVRE)
	var milhos: int = inventario.quantidade("milho")
	sementes = inventario.quantidade("semente_milho")
	energia.atual = 50.0
	lavoura.usar(a)
	_conferir(inventario.quantidade("milho") > milhos + 2, "colher o milho de primeira deu %d" % (inventario.quantidade("milho") - milhos))
	_conferir(inventario.quantidade("semente_milho") == sementes + 1, "colher o milho não devolveu a semente")
	_conferir(plantacao.arado(a) and plantacao.cultura_em(a) == "", "colhido, o leito não ficou arado e vazio")

	# --- 5. A CANA REBROTA -------------------------------------------------------------
	_na_mao("rebolo_cana", 2)
	lavoura.usar(a)
	_conferir(plantacao.cultura_em(a) == "cana", "o rebolo não plantou cana")
	while not plantacao.maduro(a):
		plantacao.regar(a)
		relogio.dormir()
		await _frames(1)
	inventario.selecionar(inventario.MAO_LIVRE)
	lavoura.usar(a)
	_conferir(plantacao.cultura_em(a) == "cana" and plantacao.estagio(a) == 1, "colhida, a cana não voltou ao toco")
	plantacao.regar(a)
	relogio.dormir()
	await _frames(1)
	_conferir(plantacao.estagio(a) == 1, "na carência, a cana carregou de novo no dia seguinte")

	# --- 6. O INVERNO ------------------------------------------------------------------
	relogio.estacao = 3
	var antes: int = plantacao.estagio(b)
	plantacao.regar(b)
	relogio.dormir()
	await _frames(1)
	relogio.estacao = 0
	_conferir(plantacao.estagio(b) == antes, "no inverno a planta regada andou")

	# --- 7. NO CAMPO A TECLA É DA LAVOURA ------------------------------------------
	var recursos = vale.get_node_or_null("Recursos3D")
	_conferir(recursos != null, "o vale não tem os alvos de trabalho")
	if recursos != null:
		var beira: Vector3 = lavoura.posicao_da(Vector2i(2, 0))
		var alem: Vector3 = beira - frente * 2.6
		recursos._alvos["teste_na_beira"] = {"pos": alem, "meia_pegada": 0.2, "ficha": {}}
		jogador.global_position = beira + Vector3.UP * 0.05
		var no_campo: String = recursos._mais_perto()
		jogador.global_position = alem + frente * 0.6 + Vector3.UP * 0.05
		var fora_do_campo: String = recursos._mais_perto()
		recursos._alvos.erase("teste_na_beira")
		_conferir(fora_do_campo == "teste_na_beira", "(preparo) fora da lavoura, junto do alvo de teste, o alcance ofereceu '%s'" % fora_do_campo)
		_conferir(no_campo == "", "dentro da lavoura o E ainda oferece o alvo de trabalho de fora: '%s'" % no_campo)

	# --- 8. O SAVE -----------------------------------------------------------------------
	var guardado: Dictionary = lavoura.estado_para_salvar()
	plantacao.restaurar_leitos({})
	await _frames(2)
	_conferir(_desenho(a) == "", "esvaziada, a lavoura ainda desenha planta")
	lavoura.restaurar(guardado)
	await _frames(2)
	_conferir(plantacao.cultura_em(a) == "cana" and plantacao.arado(b), "a lavoura não voltou do save como estava")
	_conferir(_desenho(a) == "cana:%d" % plantacao.estagio(a), "a lavoura voltou do save sem a planta desenhada (%s)" % _desenho(a))
	var do_vale: Dictionary = vale.estado_para_salvar()
	_conferir(do_vale.has("lavoura"), "o save do vale não leva a lavoura")

	# --- 9. TERRA DE VERDADE E O CERCADO RASTEIRO -------------------------------------
	# "Melhore o asset da terra agricultável pelo Pedro e coloque um cercado bem
	# rasteiro em volta dessa parte."
	var bruto := Vector2i(5, 3)
	plantacao.restaurar_leitos({})
	lavoura._desenhar(bruto)
	var leito: MeshInstance3D = lavoura.get("_leitos_3d")[bruto]["chao"]
	var terra := leito.material_override as StandardMaterial3D
	_conferir(terra != null and terra.albedo_texture != null and terra.normal_texture != null,
		"o leito ainda é de cor lisa: a terra não tem grão nem torrão")
	var malha_bruta: Mesh = leito.mesh
	plantacao.arar(bruto)
	lavoura._desenhar(bruto)
	_conferir(leito.mesh != malha_bruta and leito.mesh.get_aabb().size.y > malha_bruta.get_aabb().size.y,
		"arado, o leito não ganhou os camalhões: a malha é a mesma do chão bruto")
	_conferir(lavoura.get_node_or_null("TerraBatida") != null,
		"o campo não tem a terra batida por baixo dos leitos: cada leito é um ladrilho solto na grama")
	var cercado = lavoura.get_node_or_null("Cercado")
	_conferir(cercado != null, "o campo da lavoura não tem cercado")
	if cercado != null:
		var estacas: MultiMeshInstance3D = cercado.get_node_or_null("Estacas") as MultiMeshInstance3D
		_conferir(estacas != null and estacas.multimesh.instance_count >= 30,
			"o cercado tem %d estaca(s): não cerca o campo" % (estacas.multimesh.instance_count if estacas != null else 0))
		# RASTEIRO: abaixo do degrau que o corpo sobe sozinho (`player_controller.DEGRAU`,
		# 0,4) — encostar nele não empaca ninguém.
		var mais_alta := 0.0
		var corpo: Node = cercado.get_node_or_null("CercadoColisao")
		if corpo != null:
			for forma in corpo.get_children():
				if forma is CollisionShape3D and (forma as CollisionShape3D).shape is BoxShape3D:
					mais_alta = maxf(mais_alta, ((forma as CollisionShape3D).shape as BoxShape3D).size.y)
		_conferir(mais_alta > 0.0 and mais_alta < 0.4, "a cerca tem %.2f de altura: não é rasteira, ou não tem corpo" % mais_alta)
		# CERCA O CAMPO: todo leito fica dentro dela.
		var lados: Array = lavoura.lados_do_cercado
		var meia_x := absf((lados[1][0] as Vector2).x)
		var meia_z := absf((lados[0][0] as Vector2).y)
		var x_da_casa: Vector3 = lavoura.get("_x")
		var z_da_casa: Vector3 = lavoura.get("_z")
		var meio: Vector3 = vale.world.ancoras["Lavoura"]
		var fora := 0
		for y in lavoura.LINHAS:
			for x in lavoura.COLUNAS:
				var d: Vector3 = lavoura.posicao_da(Vector2i(x, y)) - meio
				if absf(d.dot(x_da_casa)) + lavoura.LADO_DO_LEITO * 0.5 > meia_x or absf(d.dot(z_da_casa)) + lavoura.LADO_DO_LEITO * 0.5 > meia_z:
					fora += 1
		_conferir(fora == 0, "%d leito(s) ficam fora do cercado" % fora)
		# A PASSAGEM É DO LADO DA CASA, e é larga de passar: o vão entre os dois
		# pedaços do lado da frente, medido onde eles estão, e não onde deviam estar.
		var antes_do_vao: Vector2 = lados[3][1]
		var depois_do_vao: Vector2 = lados[4][0]
		var vao: float = antes_do_vao.distance_to(depois_do_vao)
		_conferir(vao >= 1.0, "a passagem do cercado tem %.2f de largura: não se passa" % vao)
		var no_campo: Vector2 = (antes_do_vao + depois_do_vao) * 0.5
		var da_casa: Vector3 = vale.world.ancoras["Casa de taipa"]
		var da_passagem: Vector3 = lavoura._no_chao_do_campo(no_campo)
		var do_outro_lado: Vector3 = lavoura._no_chao_do_campo(-no_campo)
		_conferir(da_passagem.distance_to(da_casa) < do_outro_lado.distance_to(da_casa),
			"a passagem do cercado não fica do lado da casa: quem sai de casa dá a volta no campo")
	_fechar()


## Põe o item na mão: na mochila, se não estiver, e na barra, se estiver lá dentro.
func _na_mao(id: String, quantos: int = 1) -> void:
	if not inventario.tem(id):
		inventario.adicionar(id, quantos)
	var onde := -1
	for i in inventario.ESPACOS:
		if str((inventario.espacos[i] as Dictionary).get("id", "")) == id:
			onde = i
			break
	if onde >= inventario.ESPACOS_MAO:
		inventario.trocar(onde, inventario.ESPACOS_MAO - 1)
		onde = inventario.ESPACOS_MAO - 1
	inventario.selecionar(onde)


func _desenho(celula: Vector2i) -> String:
	return str(lavoura.get("_leitos_3d").get(celula, {}).get("desenho", "?"))


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("LAVOURA_OK: a lavoura fica na frente da casa, em terra plana e livre; o gesto é o da mão — mão livre não ara, a enxada ara e cansa, a semente planta e gasta, o balde molha; o dia que vira faz crescer só o regado e seca tudo; o milho de primeira se colhe com a semente de volta; a cana rebrota e espera a carência; o inverno para a roça; no campo a tecla é da lavoura; o save a guarda inteira; e a terra tem grão, torrão e camalhão, com a terra batida por baixo e o cercado rasteiro em volta, aberto do lado da casa")
	else:
		print("lavoura: %d falha(s)" % falhas)
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
