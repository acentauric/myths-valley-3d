extends SceneTree
## CORREDOR LIVRE EM VOLTA DA ROTA DE HOJE: ONDE ELA BATE E PARA QUE LADO HA AR.
##
##   godot --headless --path . --script res://tools/prototipo_3d/sobrevoo/corredor.gd -- \
##       --geometria=C:/.../geometria_tripo.json --saida=C:/.../corredor.json \
##       [--altura_m=16] [--folga_m=5] [--alcance_m=80] [--passo_m=0.5] [--amostras=720] \
##       [--alturas_extra=14,18]
##
## Para cada amostra da rota de hoje (a mesma formula do abertura.gd de HEAD), anda pela
## normal horizontal do trajeto de -alcance a +alcance (negativo = esquerda de quem voa,
## positivo = direita) com o olho a `altura_m` do chao local, e marca onde a folga 3D ate
## a geometria e >= `folga_m`. O autor pediu desvio SUAVE para os LADOS, sem subir: este
## mapa responde se isso basta em todo o ciclo, e quanto de lado cada trecho pede.
##
## Viabilidade: um caminho so de lado existe se, estacao a estacao ao longo da rota, ha
## um deslocamento livre que muda no maximo tan(theta) x passo (theta = quanto a
## trajetoria se inclina em planta em relacao a rota de hoje). Primeiro a alcancabilidade
## a partir de TODO ponto livre do pier (uma volta aberta), depois o ponto fixo dela na
## volta (a volta fecha), e entao o caminho de menor desvio. Mede theta = 10, 15, 25 graus
## e a menor inclinacao que deixa passar, para cada altura.

const Geometria = preload("res://tools/prototipo_3d/sobrevoo/geometria.gd")

var _args := {}
var geo
var _s := 4.0
## Objetos perto da rota (do cabecalho da geometria), para dizer QUEM fecha cada trecho.
var _objetos: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var inicio := Time.get_ticks_msec()
	for argumento in OS.get_cmdline_user_args():
		var texto := String(argumento)
		if texto.begins_with("--") and texto.contains("="):
			_args[texto.substr(2, texto.find("=") - 2)] = texto.substr(texto.find("=") + 1)
	geo = Geometria.carregar(String(_args.get("geometria", "")))
	if geo == null:
		push_error("CORREDOR: use --geometria=<json> --saida=<json>")
		quit(1)
		return
	_s = geo.escala
	var altura := float(_args.get("altura_m", "16"))
	var folga := float(_args.get("folga_m", "5"))
	var alcance := float(_args.get("alcance_m", "80"))
	var passo := float(_args.get("passo_m", "0.5"))
	var amostras := int(_args.get("amostras", "720"))
	_carregar_objetos(String(_args.get("geometria", "")))
	var resultado := _analisar(altura, folga, alcance, passo, amostras, true)
	var extras := {}
	for texto in String(_args.get("alturas_extra", "14,18")).split(",", false):
		var h := float(texto)
		var r := _analisar(h, folga, alcance, passo, amostras, false)
		extras["%.0f" % h] = r["resumo"]
	resultado["outras_alturas"] = extras
	resultado["tempo_s"] = (Time.get_ticks_msec() - inicio) / 1000.0
	if _args.has("saida"):
		Geometria.salvar_json(String(_args["saida"]), resultado)
	print("CORREDOR_JSON: ", JSON.stringify({"resumo": resultado["resumo"], "outras_alturas": extras, "tempo_s": resultado["tempo_s"]}))
	quit(0)


func _carregar_objetos(caminho_geo: String) -> void:
	var pasta := caminho_geo.get_base_dir()
	var estilo: String = String(geo.cabecalho.get("estilo", ""))
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(pasta.path_join("geometria_%s.json" % estilo)))
	if not dados is Dictionary:
		return
	for o in (dados as Dictionary).get("objetos_perto_da_rota", []):
		var item: Dictionary = o
		item["estilo"] = estilo
		_objetos.append(item)


## Os objetos mais altos a ate `raio_m` do trecho da rota entre as amostras.
func _quem_fecha(lista: Array, amostras: int, raio_m: float) -> Array:
	var achados: Array = []
	for o in _objetos:
		if float(o.get("topo_marcado_m", 0.0)) < 12.0:
			continue
		var c: Array = o["centro_u"]
		var centro := Vector2(float(c[0]), float(c[1]))
		var perto := INF
		for i in lista:
			var r := Geometria.rota_base(geo.pier, geo.praca, _s, float(i) / amostras)
			perto = minf(perto, centro.distance_to(Vector2(r.x, r.z)) * _s)
		if perto <= raio_m:
			achados.append({"estilo": o["estilo"], "rotulo": String(o["rotulo"]).get_slice(" | ", 1) + " (" + String(o["rotulo"]).get_slice(" | ", 0).get_file() + ")", "topo_m": o["topo_marcado_m"], "centro_a_rota_m": snappedf(perto, 0.1)})
	achados.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["centro_a_rota_m"]) < float(b["centro_a_rota_m"]))
	return achados.slice(0, 6)


func _analisar(altura: float, folga: float, alcance: float, passo: float, amostras: int, detalhar: bool) -> Dictionary:
	var colunas := int(round(2.0 * alcance / passo)) + 1
	var centro := colunas / 2
	var livre := PackedByteArray()
	livre.resize(amostras * colunas)
	var detalhe: Array = []
	var ds := PackedFloat32Array()
	ds.resize(amostras)
	var segundos := Geometria.FLYOVER_SECONDS
	for i in range(amostras):
		var progresso := float(i) / amostras
		var r := Geometria.rota_base(geo.pier, geo.praca, _s, progresso)
		var proxima := Geometria.rota_base(geo.pier, geo.praca, _s, float(i + 1) / amostras)
		ds[i] = Vector2(proxima.x - r.x, proxima.z - r.z).length() * _s
		var frente := Geometria.direcao_base(geo.pier, geo.praca, _s, progresso)
		var direita := frente.cross(Vector3.UP).normalized()
		for c in range(colunas):
			var o := (c - centro) * passo
			var q := r + direita * o / _s
			q.y = geo.chao(q.x, q.z) + altura / _s
			livre[i * colunas + c] = 1 if geo.folga(q, folga) >= folga else 0
		if detalhar:
			var olho := Vector3(r.x, geo.chao(r.x, r.z) + altura / _s, r.z)
			var folga_base: float = geo.folga(olho, 15.0)
			var intervalos: Array = []
			var a := -1
			for c in range(colunas + 1):
				var l := c < colunas and livre[i * colunas + c] == 1
				if l and a < 0:
					a = c
				elif not l and a >= 0:
					intervalos.append([(a - centro) * passo, (c - 1 - centro) * passo])
					a = -1
			detalhe.append({
				"i": i, "t_s": snappedf(progresso * segundos, 0.01), "progresso": snappedf(progresso, 0.0001),
				"rota_u": [snappedf(r.x, 0.001), snappedf(r.z, 0.001)], "direita_u": [snappedf(direita.x, 0.0001), snappedf(direita.z, 0.0001)],
				"livre_na_base": livre[i * colunas + centro] == 1, "folga_base_m": snappedf(folga_base, 0.01),
				"livre_esq_m": _primeiro_livre(livre, i, colunas, centro, -1, passo),
				"livre_dir_m": _primeiro_livre(livre, i, colunas, centro, 1, passo),
				"intervalos_livres_m": intervalos,
			})
	# Trechos em que a base bate (amostras seguidas, com a volta do ciclo).
	var bate := PackedByteArray()
	bate.resize(amostras)
	var batidas := 0
	for i in range(amostras):
		bate[i] = 1 if livre[i * colunas + centro] == 0 else 0
		batidas += bate[i]
	var aglomerados: Array = []
	if batidas > 0 and batidas < amostras:
		var comeco := 0
		while bate[comeco] == 1:
			comeco += 1
		var i := 0
		while i < amostras:
			var k := (comeco + i) % amostras
			if bate[k] == 0:
				i += 1
				continue
			var lista: Array = []
			while i < amostras and bate[(comeco + i) % amostras] == 1:
				lista.append((comeco + i) % amostras)
				i += 1
			aglomerados.append(_resumir_aglomerado(lista, livre, colunas, centro, passo, ds, amostras, segundos))
	elif batidas == amostras:
		var todas: Array = range(amostras)
		aglomerados.append(_resumir_aglomerado(todas, livre, colunas, centro, passo, ds, amostras, segundos))
	# Viabilidade so de lado, por inclinacao lateral maxima.
	var viabilidade := {}
	for graus in [10.0, 15.0, 25.0]:
		viabilidade["%d_graus" % int(graus)] = _caminho_lateral(livre, colunas, centro, passo, ds, amostras, tan(deg_to_rad(graus)))
	var inclinacao_minima: Variant = null
	for graus in [10.0, 15.0, 20.0, 25.0, 30.0, 35.0, 40.0, 45.0, 50.0, 60.0, 70.0]:
		var tentativa := _caminho_lateral(livre, colunas, centro, passo, ds, amostras, tan(deg_to_rad(graus)), false)
		if bool(tentativa["viavel"]):
			inclinacao_minima = graus
			break
	var sem_saida := 0
	for i in range(amostras):
		var alguma := false
		for c in range(colunas):
			if livre[i * colunas + c] == 1:
				alguma = true
				break
		if not alguma:
			sem_saida += 1
	var resumo := {
		"altura_m": altura, "folga_m": folga, "alcance_m": alcance, "passo_m": passo, "amostras": amostras,
		"amostras_em_que_a_base_bate": batidas, "fracao_que_bate": snappedf(float(batidas) / amostras, 0.0001),
		"amostras_sem_nenhum_ponto_livre_em_mais_ou_menos_alcance": sem_saida,
		"aglomerados": aglomerados.size(),
		"aglomerados_densos": aglomerados.filter(func(a: Dictionary) -> bool: return bool(a["denso"])).size(),
		"so_de_lado_viavel": {"10_graus": viabilidade["10_graus"]["viavel"], "15_graus": viabilidade["15_graus"]["viavel"], "25_graus": viabilidade["25_graus"]["viavel"]},
		"menor_inclinacao_lateral_viavel_graus": inclinacao_minima,
		"onde_trava_a_15_graus_t_s": viabilidade["15_graus"].get("t_s"),
		"onde_trava_a_25_graus_t_s": viabilidade["25_graus"].get("t_s"),
		"desvio_max_do_caminho_lateral_m": {"10_graus": viabilidade["10_graus"].get("desvio_max_m"), "15_graus": viabilidade["15_graus"].get("desvio_max_m"), "25_graus": viabilidade["25_graus"].get("desvio_max_m")},
	}
	var saida := {"versao": 1, "geometria": geo.cabecalho.get("estilo", "?"), "pier_u": [geo.pier.x, geo.pier.y, geo.pier.z], "praca_u": [geo.praca.x, geo.praca.y, geo.praca.z], "resumo": resumo, "aglomerados": aglomerados, "viabilidade": viabilidade, "convencao": "deslocamento negativo = esquerda de quem voa (UP x frente), positivo = direita (frente x UP)"}
	if detalhar:
		saida["amostras_detalhe"] = detalhe
	return saida


func _primeiro_livre(livre: PackedByteArray, i: int, colunas: int, centro: int, lado: int, passo: float) -> Variant:
	var c := centro
	while c >= 0 and c < colunas:
		if livre[i * colunas + c] == 1:
			return absf((c - centro) * passo)
		c += lado
	return null


func _resumir_aglomerado(lista: Array, livre: PackedByteArray, colunas: int, centro: int, passo: float, ds: PackedFloat32Array, amostras: int, segundos: float) -> Dictionary:
	var comprimento := 0.0
	var pior_esq := 0.0
	var pior_dir := 0.0
	var esq_sempre := true
	var dir_sempre := true
	# Canal comum: deslocamentos livres em TODAS as amostras do trecho.
	var comum := PackedByteArray()
	comum.resize(colunas)
	comum.fill(1)
	for i in lista:
		comprimento += ds[i]
		var e: Variant = _primeiro_livre(livre, i, colunas, centro, -1, passo)
		var d: Variant = _primeiro_livre(livre, i, colunas, centro, 1, passo)
		if e == null:
			esq_sempre = false
		else:
			pior_esq = maxf(pior_esq, float(e))
		if d == null:
			dir_sempre = false
		else:
			pior_dir = maxf(pior_dir, float(d))
		for c in range(colunas):
			if livre[i * colunas + c] == 0:
				comum[c] = 0
	var canal_esq: Variant = null
	var canal_dir: Variant = null
	for c in range(centro, -1, -1):
		if comum[c] == 1:
			canal_esq = (centro - c) * passo
			break
	for c in range(centro, colunas):
		if comum[c] == 1:
			canal_dir = (c - centro) * passo
			break
	var minimo_lado := minf(pior_esq if esq_sempre else INF, pior_dir if dir_sempre else INF)
	return {
		"objetos_que_fecham": _quem_fecha(lista, amostras, 30.0),
		"amostra_inicio": lista[0], "amostra_fim": lista[lista.size() - 1], "amostras": lista.size(),
		"t_inicio_s": snappedf(float(lista[0]) / amostras * segundos, 0.01), "t_fim_s": snappedf(float(lista[lista.size() - 1] + 1) / amostras * segundos, 0.01),
		"comprimento_m": snappedf(comprimento, 0.1),
		"desvio_esq_necessario_m": pior_esq if esq_sempre else null,
		"desvio_dir_necessario_m": pior_dir if dir_sempre else null,
		"canal_comum_esq_m": canal_esq, "canal_comum_dir_m": canal_dir,
		"denso": minimo_lado > 20.0,
	}


## Estacoes de mesmo passo ao longo da rota (passo de estacao = passo lateral /
## tan(theta), entao cada estacao muda no maximo UMA coluna): a rota de hoje anda devagar
## nas viradas e depressa no meio, e com amostras de mesmo progresso o limite viraria
## zero coluna nas viradas. 1) Alcancabilidade a partir de TODO ponto livre do pier,
## uma volta (se esvazia, trava ali). 2) Ponto fixo na volta: as colunas do pier que
## continuam alcancaveis depois de voltas seguidas (se esvazia, abre mas nao fecha).
## 3) Caminho fechado de menor soma de |deslocamento|, partindo da coluna do ponto fixo
## mais perto do centro (algumas tentativas).
func _caminho_lateral(livre: PackedByteArray, colunas: int, centro: int, passo: float, ds: PackedFloat32Array, amostras: int, inclinacao: float, com_caminho: bool = true) -> Dictionary:
	var acumulado := PackedFloat32Array()
	acumulado.resize(amostras + 1)
	for i in range(amostras):
		acumulado[i + 1] = acumulado[i] + ds[i]
	var total := acumulado[amostras]
	var passo_estacao := passo / maxf(inclinacao, 1e-6)
	var estacoes := maxi(int(ceil(total / passo_estacao)), 3)
	var amostra_da_estacao := PackedInt32Array()
	amostra_da_estacao.resize(estacoes)
	var k := 0
	for j in range(estacoes):
		var alvo := j * total / estacoes
		while k < amostras and acumulado[k + 1] < alvo:
			k += 1
		amostra_da_estacao[j] = k if alvo - acumulado[k] <= acumulado[mini(k + 1, amostras)] - alvo else (k + 1) % amostras
	# 1 e 2: alcancabilidade em voltas seguidas, a partir de todo ponto livre do pier.
	var alcance := PackedByteArray()
	alcance.resize(colunas)
	var linha0 := amostra_da_estacao[0]
	for c in range(colunas):
		alcance[c] = livre[linha0 * colunas + c]
	var volta := 0
	while volta < 6:
		volta += 1
		var antes := alcance.duplicate()
		for j in range(1, estacoes + 1):
			var linha := amostra_da_estacao[j % estacoes]
			var novo := PackedByteArray()
			novo.resize(colunas)
			var algum := false
			for c in range(colunas):
				if livre[linha * colunas + c] == 0:
					continue
				if alcance[c] == 1 or (c > 0 and alcance[c - 1] == 1) or (c + 1 < colunas and alcance[c + 1] == 1):
					novo[c] = 1
					algum = true
			alcance = novo
			if not algum:
				if volta == 1:
					return {"viavel": false, "trava_na_amostra": linha, "t_s": snappedf(float(linha) / amostras * Geometria.FLYOVER_SECONDS, 0.01), "estacao": j}
				return {"viavel": false, "motivo": "abre uma volta mas nao fecha"}
		if alcance == antes:
			break
	if not com_caminho:
		return {"viavel": true, "inclinacao": inclinacao}
	var fixos: Array = []
	for c in range(colunas):
		if alcance[c] == 1:
			fixos.append(c)
	fixos.sort_custom(func(a: int, b: int) -> bool: return absi(a - centro) < absi(b - centro))
	for inicio in fixos.slice(0, 6):
		var r := _menor_desvio(livre, colunas, centro, passo, acumulado, amostras, estacoes, amostra_da_estacao, inicio)
		if bool(r["viavel"]):
			r["inclinacao"] = inclinacao
			r["passo_da_estacao_m"] = passo_estacao
			r["estacoes"] = estacoes
			return r
	return {"viavel": true, "inclinacao": inclinacao, "motivo": "ponto fixo existe, mas o caminho de menor desvio nao fechou em 1 volta"}


func _menor_desvio(livre: PackedByteArray, colunas: int, centro: int, passo: float, acumulado: PackedFloat32Array, amostras: int, estacoes: int, amostra_da_estacao: PackedInt32Array, inicio: int) -> Dictionary:
	var custo := PackedFloat32Array()
	custo.resize(colunas)
	custo.fill(INF)
	custo[inicio] = absf((inicio - centro) * passo)
	var de_onde := PackedInt32Array()
	de_onde.resize((estacoes + 1) * colunas)
	de_onde.fill(-1)
	for j in range(1, estacoes + 1):
		var linha := amostra_da_estacao[j % estacoes]
		var novo := PackedFloat32Array()
		novo.resize(colunas)
		novo.fill(INF)
		var algum := false
		for c in range(colunas):
			if livre[linha * colunas + c] == 0:
				continue
			if j == estacoes and c != inicio:
				continue
			var melhor := INF
			var origem := -1
			for d in range(maxi(c - 1, 0), mini(c + 1, colunas - 1) + 1):
				if custo[d] < melhor:
					melhor = custo[d]
					origem = d
			if origem < 0:
				continue
			novo[c] = melhor + (absf((c - centro) * passo) if j < estacoes else 0.0)
			de_onde[j * colunas + c] = origem
			algum = true
		custo = novo
		if not algum:
			return {"viavel": false}
	var por_estacao := PackedFloat32Array()
	por_estacao.resize(estacoes)
	var c := inicio
	for j in range(estacoes, 0, -1):
		var anterior := de_onde[j * colunas + c]
		por_estacao[j - 1] = (anterior - centro) * passo
		c = anterior
	var total := acumulado[amostras]
	var por_amostra := PackedFloat32Array()
	por_amostra.resize(amostras)
	var maior := 0.0
	var soma := 0.0
	for i in range(amostras):
		var posicao := acumulado[i] / total * estacoes
		var j0 := floori(posicao) % estacoes
		var j1 := (j0 + 1) % estacoes
		por_amostra[i] = lerpf(por_estacao[j0], por_estacao[j1], posicao - floorf(posicao))
		maior = maxf(maior, absf(por_amostra[i]))
		soma += absf(por_amostra[i])
	return {"viavel": true, "coluna_inicial_m": (inicio - centro) * passo, "desvio_max_m": maior, "desvio_medio_m": soma / amostras, "deslocamento_por_amostra_m": Array(por_amostra).map(func(x: float) -> float: return snappedf(x, 0.01))}
