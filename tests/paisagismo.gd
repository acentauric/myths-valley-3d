extends "res://tests/suite/caso.gd"
## Confere O PAISAGISMO DO VALE (paisagismo_vale.gd, paisagismo_vale.tscn,
## data/paisagismo/receitas.json).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste paisagismo
##
## "Faça o paisagismo do jogo INTEIRO: preencha áreas vazias e mortas; crie
## agrupamentos coerentes de uma espécie só; evite misturar espécies, porque a
## repetição é melhor." Monta o vale de verdade (estilo Tripo) e pergunta:
##
##   1. AS RESERVAS NÃO FORAM VIOLADAS: nenhum pé na rua, na casa, na faixa da
##      porta até a rua, na vereda, na âncora, no cemitério, na faixa da orla
##      (18 u da costa), no leito dos rios; e no corredor do sobrevoo do menu só
##      pé de até 2,4 u. Medido em cima dos dados do mundo, não pela função do
##      plantio.
##   2. AS ZONAS SÃO DE UMA ESPÉCIE SÓ: em média, pelo menos 75% dos oito
##      vizinhos de um pé são da espécie dele (a mata sorteada dava 19%).
##   3. O ARRAIAL ESTÁ VIVO: no máximo 35% das células livres da vila ficam a
##      mais de 9 u de uma árvore ou planta (eram 78%).
##   4. É DETERMINÍSTICO E LOCAL: montar de novo dá a mesma lista, e uma casa
##      posta de repente só tira os pés que ela cobre — nenhum outro se mexe.
##   5. CABE NO ORÇAMENTO: pés e triângulos por quadro.
##   6. AS RECEITAS CONFEREM COM O CATÁLOGO: toda espécie tem GLB, medida e (as
##      de tronco) ficha; nenhum mangue, coqueiro nem licuri (o semiárido).
##   7. O TRONCO É TRONCO: cada árvore de pomar entra no conjunto de troncos
##      (colisão, corte, navegação) com a instância dela na MultiMesh.
##   8. HÁ PIAÇAVA PERTO DO PÍER para a missão do saveiro (saveiro_piacava).
##
## `--falsificar=reservas|sorteio|semente|voo|vazio` estraga de propósito o que o
## modo nomeia, e o portão TEM de reprovar.

const PaisagismoVale := preload("res://scripts/prototipo_3d/paisagismo_vale.gd")
const PUREZA_MINIMA := 0.75
const VAZIAS_MAXIMAS := 0.35
const ALCANCE_DA_ARVORE := 9.0
const PES_MAXIMOS := 14000
const TRIANGULOS_MAXIMOS := 45000000.0
const PROIBIDAS := ["coqueiro", "coqueiro_leve", "coqueiro_longe", "mangue", "mangue_leve", "mangue_longe", "licurizeiro"]

var falhas := 0
var modo := ""


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("PAISAGISMO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--falsificar="):
			modo = argumento.trim_prefix("--falsificar=")
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await process_frame
	await process_frame
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	var jogo := current_scene
	var wb = jogo.get("world")
	_conferir(wb != null and wb._region != null, "o vale monta o mundo")
	if wb == null or wb._region == null:
		_fechar()
		return
	var regiao: Node3D = wb._region
	var receitas: Dictionary = PaisagismoVale.ler_receitas()
	var zonas := PaisagismoVale.ler()
	var plantas: Array[Dictionary] = wb.paisagismo_plantas
	var plano: Dictionary = PaisagismoVale.planejar(wb, zonas, receitas)
	var reservas: Dictionary = plano["reservas"]
	var aderecos: Array[Dictionary] = wb.paisagismo_aderecos
	print("zonas: %d, pés: %d" % [zonas.size(), plantas.size()])
	_conferir(zonas.size() >= 14, "a cena do paisagismo tem só %d zonas" % zonas.size())
	_conferir(plantas.size() >= 1500, "o paisagismo plantou só %d pés" % plantas.size())
	plantas = _falsificar(plantas, zonas, receitas, reservas)

	# --- 6. AS RECEITAS CONFEREM COM O CATÁLOGO ------------------------------------
	var info: Dictionary = receitas.get("info_das_especies", {})
	var fichas: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/arvores_3d.json"))
	for chave in _chaves_das_receitas(receitas):
		_conferir(info.has(chave), "a espécie %s das receitas não tem medida em info_das_especies" % chave)
		_conferir(CatalogoAssets.tem_tripo(chave), "a espécie %s das receitas não tem GLB no catálogo" % chave)
		_conferir(not PROIBIDAS.has(chave), "a espécie %s é da orla ou do semiárido e não entra no paisagismo" % chave)
		if info.has(chave) and bool((info[chave] as Dictionary).get("tronco", false)):
			var ficha := String((info[chave] as Dictionary).get("ficha", ""))
			_conferir(ficha != "", "a espécie %s tem tronco mas não tem ficha" % chave)
			_conferir((fichas.arvores as Dictionary).has(ficha) and ((fichas.especies as Dictionary).has(ficha) or (fichas.nao_se_corta as Dictionary).has(ficha)), "a ficha %s (de %s) não está em data/arvores_3d.json, nas fichas e na madeira (ou em nao_se_corta)" % [ficha, chave])
			if ficha in ["goiabeira", "mamoeiro", "bambu"] and (fichas.arvores as Dictionary).has(ficha):
				var texto: Dictionary = fichas.arvores[ficha]
				for campo in ["nome_en", "nome_es", "paginas", "paginas_en", "paginas_es"]:
					_conferir(texto.has(campo) and str(texto[campo]) != "", "a ficha %s não tem %s (os três idiomas)" % [ficha, campo])
	for zona in zonas:
		_conferir((receitas.receitas as Dictionary).has(zona.receita), "a zona %s pede a receita %s, que não existe" % [zona.nome, zona.receita])
	var por_zona := {}
	for planta in plantas:
		por_zona[planta.zona] = int(por_zona.get(planta.zona, 0)) + 1
	for zona in zonas:
		if bool(zona.ativa):
			_conferir(int(por_zona.get(zona.nome, 0)) > 0, "a zona %s não plantou nada" % zona.nome)

	# --- 1. RESERVAS -----------------------------------------------------------------
	var violacoes := _violacoes(wb, regiao, plantas, receitas, reservas)
	print("violações das reservas: %s" % str(violacoes))
	_conferir(violacoes.is_empty(), "reservas violadas: %s" % str(violacoes))

	# --- 2. PUREZA --------------------------------------------------------------------
	var pureza := _pureza(plantas, zonas, receitas)
	print("pureza das zonas: %.3f" % pureza.total)
	for nome in pureza.por_zona:
		print("  %s: %.2f" % [nome, pureza.por_zona[nome]])
	_conferir(pureza.total >= PUREZA_MINIMA, "as zonas estão misturadas: pureza %.3f, abaixo de %.2f" % [pureza.total, PUREZA_MINIMA])

	# --- 3. O ARRAIAL ESTÁ VIVO ----------------------------------------------------------
	var vazio := _vazio_do_arraial(wb, regiao, plantas, reservas)
	print("células vazias do arraial: %.1f%% de %d" % [vazio.fracao * 100.0, vazio.celulas])
	_conferir(vazio.fracao <= VAZIAS_MAXIMAS, "o arraial tem %.0f%% de células vazias, acima de %.0f%%" % [vazio.fracao * 100.0, VAZIAS_MAXIMAS * 100.0])

	# --- 4. DETERMINÍSTICO E LOCAL ---------------------------------------------------------
	var de_novo := plano["plantas"] as Array
	_conferir(_igual(PaisagismoVale.gerar(zonas, receitas, reservas), plantas), "montar de novo deu outra lista")
	if modo == "semente":
		# Semente pelo relógio: cada montagem planta um vale.
		var com_relogio: Array = zonas.duplicate(true)
		for zona in com_relogio:
			zona["semente"] = int(zona["semente"]) + Time.get_ticks_usec()
		de_novo = PaisagismoVale.gerar(com_relogio, receitas, reservas)
	_conferir(_igual(de_novo, plantas), "montar de novo deu outra lista: %d pés e %d pés" % [de_novo.size(), plantas.size()])
	if not plantas.is_empty():
		var meio: Dictionary = plantas[plantas.size() / 2]
		var centro: Vector2 = meio["ponto"]
		var com_casa := reservas.duplicate()
		var circulos: Array = (reservas["circulos"] as Array).duplicate()
		var tipos := (reservas["tipos"] as PackedStringArray).duplicate()
		var grade: Dictionary = {}
		for chave_da_celula in (reservas["grade"] as Dictionary):
			grade[chave_da_celula] = (reservas["grade"][chave_da_celula] as Array).duplicate()
		var raio_da_casa := 8.0
		circulos.append(Vector4(centro.x, centro.y, raio_da_casa, 1.0))
		tipos.append("casa")
		var indice := circulos.size() - 1
		for cy in range(floori((centro.y - raio_da_casa - 4.0) / PaisagismoVale.CELULA), floori((centro.y + raio_da_casa + 4.0) / PaisagismoVale.CELULA) + 1):
			for cx in range(floori((centro.x - raio_da_casa - 4.0) / PaisagismoVale.CELULA), floori((centro.x + raio_da_casa + 4.0) / PaisagismoVale.CELULA) + 1):
				var celula := Vector2i(cx, cy)
				if not grade.has(celula):
					grade[celula] = []
				grade[celula].append(indice)
		com_casa["circulos"] = circulos
		com_casa["tipos"] = tipos
		com_casa["grade"] = grade
		var depois := PaisagismoVale.gerar(zonas, receitas, com_casa)
		var por_chave := {}
		for planta in plantas:
			por_chave[_chave(planta)] = planta
		var removidos := 0
		var longe := 0
		var novos := 0
		var depois_chaves := {}
		for planta in depois:
			depois_chaves[_chave(planta)] = planta
			if not por_chave.has(_chave(planta)) or not _igual([planta], [por_chave[_chave(planta)]]):
				novos += 1
		for planta in plantas:
			if not depois_chaves.has(_chave(planta)):
				removidos += 1
				if (planta["ponto"] as Vector2).distance_to(centro) > raio_da_casa + PaisagismoVale.COPA_MAXIMA:
					longe += 1
		print("casa posta de repente: %d pés saíram, %d longe dela, %d diferentes" % [removidos, longe, novos])
		_conferir(removidos > 0, "uma casa posta no meio do pomar não tirou pé nenhum")
		_conferir(longe == 0, "%d pé(s) longe da casa nova saíram do lugar" % longe)
		_conferir(novos == 0, "%d pé(s) mudaram com uma casa nova (a lista toda deslocou)" % novos)

	# --- 5. ORÇAMENTO ---------------------------------------------------------------------
	var triangulos := 0.0
	var malhas := {}
	var ficha_por_chave := {}
	for planta in plantas:
		var chave: String = planta.chave
		if not malhas.has(chave):
			var modelo: Dictionary = CatalogoAssets.malha(chave, 1.0)
			var soma := 0
			if not modelo.is_empty():
				var malha: Mesh = modelo.mesh
				for s in malha.get_surface_count():
					var arrays := malha.surface_get_arrays(s)
					soma += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if arrays[Mesh.ARRAY_INDEX] != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			malhas[chave] = soma
		triangulos += float(malhas[chave])
		ficha_por_chave[chave] = int(ficha_por_chave.get(chave, 0)) + 1
	print("espécies: %s" % str(ficha_por_chave))
	var por_zona_e_chave := {}
	for planta in plantas:
		if not bool(planta["forro"]):
			var da_zona: Dictionary = por_zona_e_chave.get(planta.zona, {})
			da_zona[planta.chave] = int(da_zona.get(planta.chave, 0)) + 1
			por_zona_e_chave[planta.zona] = da_zona
	for nome in por_zona_e_chave:
		print("  zona %s: %s" % [nome, str(por_zona_e_chave[nome])])
	print("orçamento: %d pés, %.1f milhões de triângulos se todos aparecessem de uma vez" % [plantas.size(), triangulos / 1000000.0])
	_conferir(plantas.size() <= PES_MAXIMOS, "o paisagismo plantou %d pés, acima de %d" % [plantas.size(), PES_MAXIMOS])
	_conferir(triangulos <= TRIANGULOS_MAXIMOS, "os pés somam %.1f milhões de triângulos, acima do orçamento" % [triangulos / 1000000.0])

	# --- 7. O TRONCO É TRONCO ----------------------------------------------------------------
	var troncos := 0
	var sem_instancia := 0
	for tronco: Dictionary in regiao._tree_trunks:
		if not tronco.has("paisagismo"):
			continue
		troncos += 1
		if tronco.get("visual") == null or int(tronco.get("instancia", -1)) < 0 or not tronco.has("transformacao"):
			sem_instancia += 1
	print("troncos do paisagismo: %d" % troncos)
	_conferir(troncos >= 300, "só %d pés do paisagismo entraram no conjunto de troncos" % troncos)
	_conferir(sem_instancia == 0, "%d tronco(s) do paisagismo sem instância na MultiMesh (não se cortam)" % sem_instancia)

	# --- 9. OS ADEREÇOS DE ROÇA E DE QUINTAL ------------------------------------------------------
	var por_chave_do_adereco := {}
	for item in aderecos:
		por_chave_do_adereco[item.chave] = int(por_chave_do_adereco.get(item.chave, 0)) + 1
	print("adereços: %s" % str(por_chave_do_adereco))
	for chave in ["cerca_varas", "estaleiro_fumo", "carro_de_boi", "monjolo", "barraca_feira"]:
		_conferir(int(por_chave_do_adereco.get(chave, 0)) >= (30 if chave == "cerca_varas" else 1), "faltam adereços: %s" % chave)
	_conferir(int(por_chave_do_adereco.get("porteira", 0)) == 0, "uma porteira decorativa volta a bloquear a entrada (#152)")
	_conferir(_igual_aderecos(plano["aderecos"], aderecos), "os adereços de uma remontagem não são os que o vale plantou")
	var itens_de_corpo := 0
	for item in aderecos:
		var p: Vector2 = item["ponto"]
		if regiao._distancia_da_rua(p) < float(item.get("rua_minima", receitas.reservas.rua)) or _perto_de_casa(wb, p, 0.0) or not Geometry2D.is_point_in_polygon(p, regiao._land):
			_conferir(false, "o adereço %s em %s cai na rua, na casa ou fora da terra" % [item.chave, str(p)])
		if bool(item["corpo"]):
			itens_de_corpo += 1
	var com_colisao := 0
	for no in wb.get_children():
		if no.has_meta("paisagismo") and no is Node3D:
			com_colisao += 1
	_conferir(com_colisao >= itens_de_corpo, "só %d dos %d adereços com corpo estão no mundo" % [com_colisao, itens_de_corpo])

	# --- 8. PIAÇAVA PERTO DO PÍER ---------------------------------------------------------------
	var piacavas: Dictionary = receitas.get("piacavas_do_pier", {})
	var pier: Vector3 = wb.ancoras[String(piacavas.get("ancora", "PierPiso"))]
	var perto := 0
	for tronco: Dictionary in regiao._tree_trunks:
		if String(tronco.get("especie", "")) == "piacava" and (tronco["point"] as Vector2).distance_to(Vector2(pier.x, pier.z)) <= float(piacavas.get("raio", 80.0)):
			perto += 1
	print("piaçabeiras a %.0f u do píer (todas as do vale): %d" % [float(piacavas.get("raio", 80.0)), perto])
	_conferir(perto >= int(piacavas.get("minimo", 8)), "só %d piaçava(s) perto do píer, e a missão do saveiro pede %d" % [perto, int(piacavas.get("minimo", 8))])
	_fechar()


func _chave(planta: Dictionary) -> String:
	var ponto: Vector2 = planta["ponto"]
	return "%s|%d|%d|%s" % [planta["zona"], roundi(ponto.x * 1000.0), roundi(ponto.y * 1000.0), planta["forro"]]


func _igual(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		var x: Dictionary = a[i]
		var y: Dictionary = b[i]
		if x["chave"] != y["chave"] or not (x["ponto"] as Vector2).is_equal_approx(y["ponto"]) or not is_equal_approx(float(x["escala"]), float(y["escala"])) or not is_equal_approx(float(x["giro"]), float(y["giro"])):
			return false
	return true


func _igual_aderecos(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i]["chave"] != b[i]["chave"] or not (a[i]["ponto"] as Vector2).is_equal_approx(b[i]["ponto"]) or not is_equal_approx(float(a[i]["giro"]), float(b[i]["giro"])):
			return false
	return true


func _chaves_das_receitas(receitas: Dictionary) -> Array[String]:
	var chaves: Array[String] = []
	for nome in receitas.receitas:
		var receita: Dictionary = receitas.receitas[nome]
		var listas: Array = [receita.get("especies", {}), receita.get("forro", {})]
		for faixa: Dictionary in receita.get("faixas", []):
			listas.append(faixa.get("especies", {}))
		for lista: Dictionary in listas:
			for chave in lista:
				if not chaves.has(String(chave)):
					chaves.append(String(chave))
		var baixa := String(receita.get("baixa_no_voo", ""))
		if baixa != "" and not chaves.has(baixa):
			chaves.append(baixa)
	return chaves


# --- Falsificações --------------------------------------------------------------------

func _falsificar(plantas: Array[Dictionary], zonas: Array, receitas: Dictionary, reservas: Dictionary) -> Array[Dictionary]:
	var saida: Array[Dictionary] = plantas
	if modo == "reservas":
		# As reservas desligadas: o plantio cobre a rua, a casa, a orla.
		saida = PaisagismoVale.gerar(zonas, receitas, {})
	elif modo == "sorteio":
		# Espécie sorteada pé a pé, como na mata antiga.
		var sorte := RandomNumberGenerator.new()
		sorte.seed = 7
		var todas: Array = ["bananeira_leve", "mangueira_leve", "pitangueira_leve", "goiabeira", "cajueiro_leve", "jaqueira_leve"]
		saida = []
		for planta in plantas:
			var copia := planta.duplicate()
			if not bool(copia["forro"]):
				copia["chave"] = todas[sorte.randi_range(0, todas.size() - 1)]
			saida.append(copia)
	elif modo == "voo":
		# Espécie alta no corredor do sobrevoo.
		saida = []
		var voo: Dictionary = reservas.get("voo", {})
		var trocadas := 0
		for planta in plantas:
			var copia := planta.duplicate()
			if not voo.is_empty() and PaisagismoVale.no_corredor_do_voo(voo, planta["ponto"], 0.0, receitas.reservas):
				copia["chave"] = "mangueira_leve"
				copia["escala"] = 1.0
				trocadas += 1
			saida.append(copia)
		if trocadas == 0:
			# O corredor ficou sem pé: planta uma mangueira nele, de propósito.
			var primeiro: Vector2 = (voo.pontos as PackedVector2Array)[3]
			saida.append({"chave": "mangueira_leve", "ponto": primeiro, "escala": 1.0, "giro": 0.0, "zona": "falsa", "lod": 230.0, "forro": false})
	elif modo == "vazio":
		# O arraial sem paisagismo.
		saida = []
	return saida


# --- As medidas ------------------------------------------------------------------------

## O que viola as reservas, medido em cima dos dados do mundo.
func _violacoes(wb: Node, regiao: Node3D, plantas: Array, receitas: Dictionary, reservas: Dictionary) -> Dictionary:
	var regras: Dictionary = receitas.reservas
	var info: Dictionary = receitas.info_das_especies
	var violacoes := {}
	var voo: Dictionary = reservas.get("voo", {})
	var ancoras: Array[Vector3] = []
	var cemiterio := Vector3.INF
	for nome: String in wb.ancoras:
		if nome.ends_with("Frente") or nome.ends_with("Direcao") or nome.ends_with("Lado") or not wb.ancoras[nome] is Vector3:
			continue
		if nome == "Cemitério":
			cemiterio = wb.ancoras[nome]
		else:
			ancoras.append(wb.ancoras[nome])
	var beira_das_zonas := {}
	for nome in receitas.receitas:
		for faixa: Dictionary in (receitas.receitas[nome] as Dictionary).get("faixas", []):
			if bool(faixa.get("beira", false)):
				for chave in faixa.especies:
					beira_das_zonas[chave] = true
	for planta in plantas:
		var p: Vector2 = planta["ponto"]
		var chave: String = planta["chave"]
		var altura := float((info.get(chave, {}) as Dictionary).get("altura", 1.0)) * float(planta["escala"])
		var motivo := ""
		if regiao._distancia_da_rua(p) < float(regras.rua):
			motivo = "rua"
		elif _perto_de_casa(wb, p, float(regras.casa)):
			motivo = "casa"
		elif cemiterio.is_finite() and p.distance_to(Vector2(cemiterio.x, cemiterio.z)) < float(regras.cemiterio):
			motivo = "cemiterio"
		elif regiao._distancia_costa(p, 26.0) < float(regras.costa) and (regiao._costa_limites as Rect2).grow(26.0).has_point(p):
			motivo = "costa"
		elif not Geometry2D.is_point_in_polygon(p, regiao._land):
			motivo = "fora da terra"
		else:
			for ancora in ancoras:
				if p.distance_to(Vector2(ancora.x, ancora.z)) < float(regras.ancora):
					motivo = "ancora"
					break
			if motivo == "":
				var folga_do_leito := float(regras.leito_beira) if beira_das_zonas.has(chave) else float(regras.leito)
				for rio in regiao._rivers:
					if (rio.bounds as Rect2).grow(folga_do_leito + 2.0).has_point(p) and regiao._distance_to_line(p, rio.points) - float(rio.width) * 0.5 < folga_do_leito:
						motivo = "leito"
						break
			if motivo == "":
				for segmento: Dictionary in reservas.get("segmentos", []):
					if p.distance_to(Geometry2D.get_closest_point_to_segment(p, segmento.a, segmento.b)) < float(segmento.folga):
						motivo = String(segmento.tipo)
						break
			if motivo == "" and not voo.is_empty() and PaisagismoVale.no_corredor_do_voo(voo, p, 0.0, regras) and altura > float(regras.altura_no_voo) + 0.02:
				motivo = "voo (%s com %.1f u)" % [chave, altura]
		if motivo != "":
			violacoes[motivo] = int(violacoes.get(motivo, 0)) + 1
	return violacoes


func _perto_de_casa(wb: Node, p: Vector2, folga: float) -> bool:
	for sitio: Dictionary in wb._house_sites:
		var pos: Vector3 = sitio["position"]
		if p.distance_to(Vector2(pos.x, pos.z)) < float(sitio["radius"]) + folga:
			return true
	return false


## A pureza: a fração dos 8 vizinhos mais perto que são da espécie do pé, de pés
## de zonas de espécie única por agrupamento (a mata ciliar é em faixas de
## estratos, e fica de fora). O forro não conta.
func _pureza(plantas: Array, zonas: Array, receitas: Dictionary) -> Dictionary:
	var faixas := {}
	for zona in zonas:
		if String((receitas.receitas[zona.receita] as Dictionary).get("padrao", "")) == "faixa":
			faixas[zona.nome] = true
	var por_zona := {}
	var soma_total := 0.0
	var medidas_total := 0
	var nomes := {}
	for planta in plantas:
		if not bool(planta["forro"]) and not faixas.has(planta["zona"]):
			nomes[planta["zona"]] = true
	for nome in nomes:
		var da_zona: Array = []
		for planta in plantas:
			if planta["zona"] == nome and not bool(planta["forro"]):
				da_zona.append(planta)
		var grade := {}
		for i in da_zona.size():
			var p: Vector2 = da_zona[i]["ponto"]
			var celula := Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
			if not grade.has(celula):
				grade[celula] = []
			grade[celula].append(i)
		var soma := 0.0
		var medidas := 0
		for i in da_zona.size():
			var p: Vector2 = da_zona[i]["ponto"]
			var celula := Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
			var vizinhos: Array = []
			for dz in range(-2, 3):
				for dx in range(-2, 3):
					for j in grade.get(celula + Vector2i(dx, dz), []):
						if j != i:
							vizinhos.append([p.distance_squared_to(da_zona[j]["ponto"]), j])
			if vizinhos.size() < 8:
				continue
			vizinhos.sort_custom(func(a, b): return a[0] < b[0])
			var iguais := 0
			for k in 8:
				if da_zona[vizinhos[k][1]]["chave"] == da_zona[i]["chave"]:
					iguais += 1
			soma += float(iguais) / 8.0
			medidas += 1
		if medidas > 0:
			por_zona[nome] = soma / float(medidas)
			soma_total += soma
			medidas_total += medidas
	return {"total": soma_total / float(maxi(medidas_total, 1)), "por_zona": por_zona}


## As células livres do arraial (dentro da vila, fora de rua, rio, casa, costa e
## praça; e fora do corredor do sobrevoo e do cemitério, que ficam sem árvore
## de propósito) que não têm árvore ou planta a ALCANCE_DA_ARVORE.
func _vazio_do_arraial(wb: Node, regiao: Node3D, plantas: Array, reservas: Dictionary) -> Dictionary:
	var arvores := PackedVector2Array()
	for tronco: Dictionary in regiao._tree_trunks:
		if not tronco.has("paisagismo"):
			arvores.append(tronco["point"])
	for nomeada: Dictionary in wb._arvores_nomeadas:
		arvores.append(Vector2(nomeada["pos"].x, nomeada["pos"].z))
	for planta in plantas:
		if not bool(planta["forro"]):
			arvores.append(planta["ponto"])
	var grade := {}
	for i in arvores.size():
		var celula := Vector2i(floori(arvores[i].x / ALCANCE_DA_ARVORE), floori(arvores[i].y / ALCANCE_DA_ARVORE))
		if not grade.has(celula):
			grade[celula] = []
		grade[celula].append(i)
	var vila: PackedVector2Array = regiao._village
	var caixa := Rect2(vila[0], Vector2.ZERO)
	for ponto in vila:
		caixa = caixa.expand(ponto)
	var voo: Dictionary = reservas.get("voo", {})
	var regras := {"voo": 9.0}
	var cemiterio := Vector3.INF
	if wb.ancoras.has("Cemitério"):
		cemiterio = wb.ancoras["Cemitério"]
	var celulas := 0
	var vazias := 0
	var passo := 6.0
	var z := caixa.position.y
	while z < caixa.end.y:
		var x := caixa.position.x
		while x < caixa.end.x:
			var p := Vector2(x, z)
			x += passo
			if not Geometry2D.is_point_in_polygon(p, vila) or not Geometry2D.is_point_in_polygon(p, regiao._land):
				continue
			if regiao._distancia_da_rua(p) < 1.0 or _perto_de_casa(wb, p, 0.0) or regiao._inside_open_area(p):
				continue
			if (regiao._costa_limites as Rect2).grow(26.0).has_point(p) and regiao._distancia_costa(p, 26.0) < 18.0:
				continue
			var no_rio := false
			for rio in regiao._rivers:
				if (rio.bounds as Rect2).grow(4.0).has_point(p) and regiao._distance_to_line(p, rio.points) - float(rio.width) * 0.5 < 2.0:
					no_rio = true
					break
			if no_rio:
				continue
			if not voo.is_empty() and PaisagismoVale.no_corredor_do_voo(voo, p, 0.0, regras):
				continue
			if cemiterio.is_finite() and p.distance_to(Vector2(cemiterio.x, cemiterio.z)) < 16.0:
				continue
			celulas += 1
			var tem := false
			var celula := Vector2i(floori(p.x / ALCANCE_DA_ARVORE), floori(p.y / ALCANCE_DA_ARVORE))
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					for i in grade.get(celula + Vector2i(dx, dz), []):
						if p.distance_squared_to(arvores[i]) <= ALCANCE_DA_ARVORE * ALCANCE_DA_ARVORE:
							tem = true
			if not tem:
				vazias += 1
		z += passo
	return {"fracao": float(vazias) / float(maxi(celulas, 1)), "celulas": celulas}


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("PAISAGISMO_OK: as zonas plantam agrupamentos de uma espécie só, longe das ruas, das casas, da orla, dos rios e do corredor do sobrevoo, de forma determinística e local, e o arraial deixou de ser vazio")
	else:
		print("paisagismo: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)
