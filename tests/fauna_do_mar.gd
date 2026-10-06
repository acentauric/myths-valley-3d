extends SceneTree
## Confere A FAUNA D'ÁGUA DO VALE (fauna_vale.gd, cardume.gd, tubarao.gd).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/fauna_do_mar.gd
##
## "Mais cardumes em cada barco; peixes nas pedras e no rio, com inteligência
## algorítmica parecida; espécies diferentes; peixes maiores (cavala, sororoca) que
## são comidos pelo tubarão; raias em cardume." Perguntas:
##
##   1. TODA CANOA TEM CARDUME a até 4 u, e nenhum cardume é filho do nó Canoas
##      (tests/canoas.gd trata todo filho dele como canoa).
##   2. OS PEIXES DO RIO ESTÃO EM ÁGUA DOCE: dentro da calha, com lâmina.
##   3. NENHUM PEIXE FICA ABAIXO DO LEITO, nem acima da superfície (fora do salto),
##      depois de nadar dois segundos — o leito de cada um, não o do centro.
##   4. O CARDUME FOGE DE QUEM NADA, e quem está fora d'água só espanta quase em cima.
##   5. NADA PARA A FRENTE: a cabeça (o rumo) aponta para onde o peixe vai.
##   6. O TUBARÃO, FORÇADO, COME UM PEIXE do cardume-presa; ele é predador, e o
##      corpo é o GLB no estilo Tripo (os prismas no procedural).
##   7. O AVISO DO SUSTO ESTÁ NOS TRÊS IDIOMAS, fora do código.
##   8. ESPÉCIES DIFERENTES nos lugares diferentes, e as raias em bando.

var falhas := 0


func _estilo_do_portao() -> String:
	return "tripo"


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("FAUNA_DO_MAR_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	root.get_node("/root/Estilo").modo = _estilo_do_portao()
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(10)
	root.get_node("/root/Dia").pausado = true
	var vale = current_scene
	var mundo = vale.world
	var fauna = vale.get_node_or_null("FaunaVale")
	_conferir(fauna != null, "o vale não criou o FaunaVale")
	if fauna == null:
		_fechar()
		return
	var todos: Array = get_nodes_in_group("cardumes")
	print("FAUNA: %d cardumes, %d comandados" % [todos.size(), fauna.cardumes.size()])
	var por_especie: Dictionary = {}
	var peixes := 0
	for c in todos:
		por_especie[c.especie] = int(por_especie.get(c.especie, 0)) + c.quantidade()
		peixes += c.quantidade()
	print("FAUNA: %d peixes · %s" % [peixes, por_especie])

	# --- 1. canoas ------------------------------------------------------------
	var frota: Node = mundo.get_node_or_null("Canoas")
	_conferir(frota != null and frota.get_child_count() > 0, "o vale não fundeou canoa nenhuma")
	if frota != null:
		for canoa: Node3D in frota.get_children():
			_conferir(not canoa.has_method("atualizar"), "um cardume virou filho do nó Canoas: '%s'" % canoa.name)
			var perto := false
			for c in todos:
				var onde: Vector3 = c.centro()
				if c.especie == "tainha" and Vector2(onde.x - canoa.global_position.x, onde.z - canoa.global_position.z).length() <= 4.0:
					perto = true
			_conferir(perto, "a canoa '%s' não tem cardume a até 4 u" % canoa.name)

	# --- 2. rio ---------------------------------------------------------------
	var regiao = mundo.get("_region")
	var do_rio := 0
	for c in todos:
		if not c.agua_doce:
			continue
		for i in c.quantidade():
			if not c.vivo(i):
				continue
			do_rio += 1
			var p: Vector3 = c.posicao(i)
			var nivel: float = regiao.river_water_level_at(p)
			_conferir(is_finite(nivel) and mundo.water_depth_at(p) > 0.0, "o peixe %s %d do rio está fora da calha em %s" % [c.especie, i, p])
	_conferir(do_rio > 0, "nenhum peixe nos poços do rio")

	# --- 3. leito -------------------------------------------------------------
	# Todos nadam dois segundos (sem depender da distância da câmera).
	for passo in 60:
		for c in todos:
			c.atualizar(1.0 / 30.0)
	var conferidos := 0
	var pior := INF
	for c in todos:
		for i in c.quantidade():
			if not c.vivo(i):
				continue
			var p: Vector3 = c.posicao(i)
			var lamina: float = mundo.water_depth_at(p)
			var superficie: float = regiao.river_water_level_at(p) if c.agua_doce else mundo.water_level()
			if c.agua_doce and not is_finite(superficie):
				continue
			var leito := superficie - lamina
			conferidos += 1
			pior = minf(pior, p.y - leito)
			_conferir(p.y >= leito - 0.02, "o %s %d está abaixo do leito: y %.3f, leito %.3f" % [c.especie, i, p.y, leito])
			if c._salto[i] <= 0.0:
				_conferir(p.y <= superficie + 0.01, "o %s %d está fora d'água sem saltar: y %.3f, superfície %.3f" % [c.especie, i, p.y, superficie])
	print("FAUNA: %d peixes conferidos contra o leito; a menor folga foi %.3f u" % [conferidos, pior])
	_conferir(conferidos > 100, "conferi só %d peixes contra o leito" % conferidos)

	# --- 4. fuga --------------------------------------------------------------
	_conferir(is_equal_approx(fauna.raio_de_perigo(vale.player), 1.2), "quem está fora d'água espanta de %.1f u, não de 1,2" % fauna.raio_de_perigo(vale.player))
	var nadador := Node.new()
	var roteiro := GDScript.new()
	roteiro.source_code = "extends Node\nfunc is_swimming() -> bool:\n\treturn true\n"
	roteiro.reload()
	nadador.set_script(roteiro)
	_conferir(fauna.raio_de_perigo(nadador) >= 3.0, "quem nada só espanta de %.1f u" % fauna.raio_de_perigo(nadador))
	nadador.free()
	var tainhas = null
	for c in fauna.cardumes:
		if c.especie == "tainha" and c.modo == "roda" and String(c.name).begins_with("Cardume Tainhas"):
			tainhas = c
			break
	_conferir(tainhas != null, "nenhum cardume de tainhas nas canoas")
	if tainhas != null:
		fauna.cardumes.erase(tainhas)
		var meio: Vector3 = tainhas.centro()
		var antes := _distancia_media(tainhas, meio)
		# Fora d'água no meio do cardume (o pescador na canoa): quem está longe não foge.
		tainhas.perigos = [{"pos": meio, "raio": 1.2, "no": null}]
		for passo in 45:
			tainhas.atualizar(1.0 / 30.0)
		var assustados := 0
		for i in tainhas.quantidade():
			if tainhas.vivo(i) and tainhas._susto[i] > 0.5 and Vector2(tainhas.posicao(i).x - meio.x, tainhas.posicao(i).z - meio.z).length() > 2.0:
				assustados += 1
		_conferir(assustados == 0, "%d tainhas a mais de 2 u fugiram de quem está fora d'água" % assustados)
		# Agora alguém nadando no meio do cardume: todos se afastam.
		antes = _distancia_media(tainhas, meio)
		tainhas.perigos = [{"pos": meio, "raio": 3.0, "no": null}]
		for passo in 45:
			tainhas.atualizar(1.0 / 30.0)
		var depois := _distancia_media(tainhas, meio)
		print("FAUNA: tainhas a %.2f u de quem nada; depois de 1,5 s, a %.2f u" % [antes, depois])
		_conferir(depois > antes + 0.6 and depois > 2.4, "o cardume não fugiu de quem nada (%.2f → %.2f u)" % [antes, depois])
		tainhas.perigos = []
		fauna.cardumes.append(tainhas)

	# --- 5. nada para a frente -----------------------------------------------
	var andando := 0
	var de_frente := 0
	var contra := {}
	for c in todos:
		if c.modo == "rio":
			continue
		for i in c.quantidade():
			var v: Vector3 = c.velocidade(i)
			if not c.vivo(i) or Vector2(v.x, v.z).length() < 0.3:
				continue
			andando += 1
			var frente := Vector3(-sin(c.rumo(i)), 0.0, -cos(c.rumo(i)))
			var ok_frente: bool = frente.dot(Vector3(v.x, 0.0, v.z).normalized()) > 0.7
			if ok_frente:
				de_frente += 1
			else:
				contra[c.modo] = int(contra.get(c.modo, 0)) + 1
	print("FAUNA: %d de %d peixes nadando com a cabeça para onde vão (fora, por modo: %s)" % [de_frente, andando, contra])
	_conferir(andando > 50 and de_frente >= andando * 0.85, "só %d de %d peixes nadam de frente" % [de_frente, andando])

	# --- 6. tubarão -----------------------------------------------------------
	var tubarao = vale.get_node_or_null("Tubarao")
	_conferir(tubarao != null and tubarao.get("_ativo") == true, "o tubarão não está ativo")
	if tubarao != null and tubarao.get("_ativo") == true:
		_conferir(tubarao.is_in_group("predadores"), "o tubarão não está no grupo predadores")
		var tripo: bool = _estilo_do_portao() == "tripo" and CatalogoAssets.tem_tripo("tubarao")
		_conferir((tubarao.get_node_or_null("CorpoTripo") != null) == tripo, "o corpo do tubarão não é o do estilo (%s)" % _estilo_do_portao())
		_conferir((tubarao.get_node_or_null("Barbatana") != null) == (not tripo), "os prismas do tubarão no estilo errado")
		var presas: Array = get_nodes_in_group("presas_do_tubarao")
		_conferir(presas.size() >= 2, "o mar de fora tem %d cardumes-presa (quero cavalas e sororocas)" % presas.size())
		if not presas.is_empty():
			var presa = presas[0]
			# Junto da presa, em água em que ele nada, e com a caça forçada.
			var onde: Vector3 = presa.centro_atual()
			var largada := Vector3.INF
			for k in 16:
				var tentativa := onde + Vector3(cos(TAU * k / 16.0), 0.0, sin(TAU * k / 16.0)) * 6.0
				if mundo.water_depth_at(tentativa) >= 1.2:
					largada = tentativa
					break
			_conferir(largada.is_finite(), "sem água funda perto da presa")
			if largada.is_finite():
				tubarao.global_position = Vector3(largada.x, mundo.water_level(), largada.z)
				tubarao.forcar_caca()
				var antes_comidos: int = presa.comidos
				var comeu := false
				for quadro in 900:
					await physics_frame
					if presa.comidos > antes_comidos:
						comeu = true
						break
				print("FAUNA: o tubarão %s um peixe de '%s'" % ["comeu" if comeu else "NÃO comeu", presa.name])
				_conferir(comeu, "o tubarão forçado não comeu peixe nenhum em 15 s")
				_conferir(not tubarao.get("_atacando"), "o tubarão atacou o jogador, que está em terra")

	# --- 7. texto -------------------------------------------------------------
	var arquivo := FileAccess.open("res://data/fauna_do_mar.json", FileAccess.READ)
	_conferir(arquivo != null, "falta data/fauna_do_mar.json")
	if arquivo != null:
		var dados = JSON.parse_string(arquivo.get_as_text())
		var susto: Dictionary = dados.get("tubarao", {}) if dados is Dictionary else {}
		var pt := String(susto.get("susto", ""))
		for sufixo in ["_en", "_es"]:
			var outro := String(susto.get("susto" + sufixo, ""))
			_conferir(not outro.is_empty() and outro != pt, "o aviso do tubarão não tem tradução '%s'" % sufixo)
		_conferir(not pt.is_empty(), "o aviso do tubarão está vazio")
		var codigo := FileAccess.get_file_as_string("res://scripts/prototipo_3d/tubarao.gd")
		_conferir(not codigo.contains(pt), "o aviso do tubarão ainda está escrito no código")
		if tubarao != null:
			_conferir(String(tubarao._texto_do_susto()) != "", "o tubarão não leu o aviso do JSON")

	# --- 8. espécies e raias ----------------------------------------------------
	for especie in ["tainha", "sardinha", "xareu", "cavala", "sororoca", "piaba", "traira", "raia_pintada"]:
		_conferir(por_especie.has(especie), "não há %s no vale" % especie)
	var bandos := 0
	for c in todos:
		if c.especie == "raia_pintada" and c.modo == "voo" and c.quantidade() >= 5:
			bandos += 1
	_conferir(bandos >= 1, "nenhum bando de raia-pintada")
	for c in todos:
		var corpo = c.get_node_or_null("Peixes")
		_conferir(corpo is MultiMeshInstance3D and corpo.material_override is ShaderMaterial, "o cardume '%s' não é um MultiMesh com o nado" % c.name)
		if corpo is MultiMeshInstance3D:
			_conferir(corpo.visibility_range_end > 0.0 and corpo.visibility_range_end <= 160.0, "o cardume '%s' se vê de longe demais" % c.name)

	# --- 9. A MARÉ -------------------------------------------------------------------
	await _mare(vale, mundo, fauna, todos)
	_fechar()


## 9. COM A MARÉ LIGADA. Tudo acima mede o mar na preamar, fixo. A maré vem ligada no jogo, e este é o que vale com
## ela: na PREAMAR e na BAIXA-MAR, depois de os cardumes nadarem três segundos, todo peixe À MOSTRA (o cardume
## visível, o peixe nem escondido nem saltando) está dentro d'água — do leito de agora à superfície de agora, nunca
## acima da lâmina que baixou nem abaixo do fundo que subiu (o bando de raias de voo salta por projeto e fica fora
## da conta, como o salto de qualquer peixe); na baixa-mar os cardumes da água
## rasa SOMEM (o centro do bando sem lâmina), e voltam na cheia. Um portão que só media a preamar deixava o peixe do
## mar de fora sem prova nenhuma de que acompanhava a maré.
func _mare(vale: Node, mundo: Node, fauna: Node, todos: Array) -> void:
	var mare := root.get_node("/root/Mare")
	var dia := root.get_node("/root/Dia")
	mare.modo = 1
	dia.pausado = true
	var preamar_h: float = float(mare.fase_da_preamar_h)
	var sumidos_na_cheia := 0
	var sumidos_na_baixa := 0
	for fase in [["preamar", preamar_h], ["baixa-mar", fposmod(preamar_h + 6.0, 24.0)]]:
		dia.definir_hora(float(fase[1]))
		await _quadros(6)
		var nivel: float = float(mare.nivel_offset())
		_conferir((absf(nivel) < 0.01) if str(fase[0]) == "preamar" else (nivel < -0.5), "[%s] o portão não achou a maré (%.2f u)" % [fase[0], nivel])
		for passo in 90:
			for c in todos:
				c.atualizar(1.0 / 30.0)
		var conferidos := 0
		var raias := 0
		var sumidos := 0
		var pior_acima := -INF
		var pior_abaixo := INF
		var superficie: float = mundo.water_level()
		for c in todos:
			if c.agua_doce:
				continue
			var mm = c.get("_mm")
			if mm != null and not mm.visible:
				sumidos += 1
				continue
			for i in c.quantidade():
				if not c.vivo(i) or c._salto[i] > 0.0:
					continue
				var p: Vector3 = c.posicao(i)
				var leito := superficie - float(mundo.water_depth_at(p))
				conferidos += 1
				if c.especie == "raia_pintada":
					raias += 1
				pior_acima = maxf(pior_acima, p.y - superficie)
				pior_abaixo = minf(pior_abaixo, p.y - leito)
				_conferir(p.y <= superficie + 0.01, "[%s] o %s %d está acima da água (y %.3f, superfície %.3f)" % [fase[0], c.especie, i, p.y, superficie])
				_conferir(p.y >= leito - 0.02, "[%s] o %s %d está abaixo do leito (y %.3f, leito %.3f)" % [fase[0], c.especie, i, p.y, leito])
		print("FAUNA: [%s] mar a %.2f u da preamar: %d peixes à mostra (%d raias) na água, %d cardume(s) sumidos; mais alto %.3f acima da superfície, mais fundo %.3f acima do leito" % [fase[0], float(mare.nivel_offset()), conferidos, raias, sumidos, pior_acima, pior_abaixo])
		# Na baixa-mar quase todo cardume some (a baía rasa fica sem lâmina): o que resta é pouco, mas não é nada.
		_conferir(conferidos > (50 if str(fase[0]) == "preamar" else 5), "[%s] conferi só %d peixes à mostra" % [fase[0], conferidos])
		if str(fase[0]) == "preamar":
			sumidos_na_cheia = sumidos
		else:
			sumidos_na_baixa = sumidos
	_conferir(sumidos_na_baixa > sumidos_na_cheia, "na baixa-mar não sumiu cardume nenhum da água rasa (%d sumidos na cheia, %d na baixa-mar)" % [sumidos_na_cheia, sumidos_na_baixa])
	mare.modo = 0


func _distancia_media(c, ponto: Vector3) -> float:
	var soma := 0.0
	var n := 0
	for i in c.quantidade():
		if c.vivo(i):
			soma += Vector2(c.posicao(i).x - ponto.x, c.posicao(i).z - ponto.z).length()
			n += 1
	return soma / maxf(float(n), 1.0)


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("FAUNA_DO_MAR_OK (%s): toda canoa tem cardume e nenhum é filho dela; os peixes do rio estão na água doce; nenhum peixe passa do leito nem sai da água sem saltar; o cardume foge de quem nada e não de quem está fora d'água; nadam de cabeça para a frente; o tubarão é predador, tem o corpo do estilo e, forçado, come um peixe; o aviso do susto está nos três idiomas fora do código; há espécies diferentes e raias em bando; e, com a maré ligada, na preamar e na baixa-mar todo peixe à mostra está dentro d'água e os cardumes da água rasa somem na baixa-mar" % _estilo_do_portao())
	else:
		print("fauna_do_mar (%s): %d falha(s)" % [_estilo_do_portao(), falhas])
	quit(1 if falhas > 0 else 0)


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
