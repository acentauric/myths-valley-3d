extends SceneTree
## AVALIA UM TRAJETO DO SOBREVOO CONTRA A GEOMETRIA REAL DO VALE, SEM MONTAR O VALE.
##
##   godot --headless --path . --script res://tools/prototipo_3d/sobrevoo/avaliar.gd -- \
##       --geometria=C:/.../geometria_tripo.json --trajeto=C:/.../candidatos/x.json \
##       [--saida=C:/.../x.avaliacao.json] [--limite_guinada=12] [--limite_lateral=1.0] \
##       [--referencia=C:/.../base.avaliacao.json] [--lerp_jogo=1.4]
##
## Simula o ciclo a 60 quadros por segundo com a MESMA interpolacao que o jogo vai usar
## (Catmull-Rom uniforme periodica, geometria.gd): a camera fica no olho interpolado e
## olha para o alvo interpolado. Velocidade, aceleracao e giro saem das derivadas
## exatas da cubica (em double), e nao de diferenca entre quadros: as amostras vem de
## Vector3 (float32), e a segunda diferenca a 60 fps amplificaria o ruido de 1e-5 u
## para ~0,2 m/s2, o tamanho do proprio limite.
##
## Restricoes duras (o veredito), com os numeros da linha de base ao lado para comparar:
##   H1 folga 3D do olho >= 5 m em todos os quadros;
##   H2 altura do olho sobre o chao local em [14, 18] m;
##   H3 suavidade: guinada <= LIMITE_GUINADA graus/s, aceleracao lateral do olho <=
##      LIMITE_LATERAL m/s2, velocidade vertical <= 1,5 m/s, aceleracao vertical <= 0,6 m/s2;
##   H4 enquadramento: alvo a 40-70 m na horizontal, inclinacao |dy|/horizontal <= 0,3,
##      olhar alinhado ao movimento (produto escalar >= 0,97), alvo >= 2 m acima do chao;
##   H5 continuidade C1 na volta do ciclo;
##   H6 fidelidade: olho a <= 20 m do pier em t = 0 e <= 35 m da praca em t = 36 s, e
##      desvio maximo da rota de hoje <= 60 m (distancia ao tracado, nao ao mesmo instante).
## Imprime "AVALIACAO_JSON: {...}" e grava o mesmo JSON em --saida.
##
## --lerp_jogo=1.4 acrescenta "camera_do_jogo_atual": o abertura.gd de HEAD nao poe a
## camera no olho, e sim a puxa para ele a cada quadro (lerp com blend = delta * 1.4,
## um atraso de ~0,7 s), o que corta caminho nas viradas e alisa o relevo. Serve para
## comparar com o que o jogador ve hoje; o formato novo nao tem esse atraso.

const Geometria = preload("res://tools/prototipo_3d/sobrevoo/geometria.gd")
const FPS := 60
const FOLGA_MIN_M := 5.0
const RAIO_BUSCA_M := 15.0
const ALTURA_MIN_M := 14.0
const ALTURA_MAX_M := 18.0
const VELOCIDADE_VERTICAL_MAX := 1.5
const ACELERACAO_VERTICAL_MAX := 0.6
const ALVO_MIN_M := 40.0
const ALVO_MAX_M := 70.0
const INCLINACAO_MAX := 0.3
const ALINHAMENTO_MIN := 0.97
const ALVO_SOBRE_CHAO_MIN_M := 2.0
const PIER_MAX_M := 20.0
const PRACA_MAX_M := 35.0
const DESVIO_MAX_M := 60.0
## Cone frontal: geometria a menos de CONE_ALCANCE_M dentro de CONE_SEMI_GRAUS do eixo
## olho -> alvo (semiabertura; 60 graus de abertura total).
const CONE_SEMI_GRAUS := 30.0
const CONE_ALCANCE_M := 10.0
const PIORES := 20
## Piores quadros separados por pelo menos isto (s): cada um e um episodio, nao o
## mesmo tronco contado vinte vezes.
const SEPARACAO_PIORES_S := 0.5

var _args := {}
var geo
var _s := 4.0
var _olho := PackedVector3Array()
var _alvo := PackedVector3Array()
var _segundos := 72.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for argumento in OS.get_cmdline_user_args():
		var texto := String(argumento)
		if texto.begins_with("--") and texto.contains("="):
			_args[texto.substr(2, texto.find("=") - 2)] = texto.substr(texto.find("=") + 1)
	var caminho_geo := String(_args.get("geometria", ""))
	var caminho_trajeto := String(_args.get("trajeto", ""))
	if caminho_geo.is_empty() or caminho_trajeto.is_empty():
		push_error("AVALIAR: use --geometria=<json> --trajeto=<json> [--saida=<json>]")
		quit(1)
		return
	var resultado := avaliar(caminho_geo, caminho_trajeto, float(_args.get("limite_guinada", "12")), float(_args.get("limite_lateral", "1.0")))
	if resultado.is_empty():
		quit(1)
		return
	if _args.has("referencia"):
		var referencia: Variant = JSON.parse_string(FileAccess.get_file_as_string(String(_args["referencia"])))
		if referencia is Dictionary:
			resultado["comparacao_com_referencia"] = comparar(resultado, referencia)
			resultado["comparacao_com_referencia"]["referencia"] = String(_args["referencia"])
	if _args.has("lerp_jogo"):
		resultado["camera_do_jogo_atual"] = simular_lerp(float(_args["lerp_jogo"]))
	if _args.has("saida"):
		Geometria.salvar_json(String(_args["saida"]), resultado)
	_imprimir_resumo(resultado)
	print("AVALIACAO_JSON: ", JSON.stringify(resultado))
	quit(0)


func avaliar(caminho_geo: String, caminho_trajeto: String, limite_guinada: float, limite_lateral: float) -> Dictionary:
	var inicio := Time.get_ticks_msec()
	geo = Geometria.carregar(caminho_geo)
	if geo == null:
		return {}
	var trajeto := Geometria.carregar_trajeto(caminho_trajeto)
	if trajeto.is_empty():
		return {}
	_s = geo.escala
	var avisos: Array = []
	if not is_equal_approx(float(trajeto.get("metros_por_unidade", _s)), _s):
		avisos.append("metros_por_unidade do trajeto (%s) difere da geometria (%s)" % [trajeto.get("metros_por_unidade"), _s])
	var olho: PackedVector3Array = trajeto["olho_v"]
	var alvo: PackedVector3Array = trajeto["alvo_v"]
	var n := olho.size()
	var segundos := float(trajeto.get("segundos", 72.0))
	_olho = olho
	_alvo = alvo
	_segundos = segundos
	var quadros := int(round(segundos * FPS))
	# Coordenadas em double, para as derivadas.
	var ox := PackedFloat64Array()
	var oy := PackedFloat64Array()
	var oz := PackedFloat64Array()
	var ax := PackedFloat64Array()
	var ay := PackedFloat64Array()
	var az := PackedFloat64Array()
	for p in trajeto["olho"]:
		ox.append(float(p[0]))
		oy.append(float(p[1]))
		oz.append(float(p[2]))
	for p in trajeto["alvo"]:
		ax.append(float(p[0]))
		ay.append(float(p[1]))
		az.append(float(p[2]))
	var por_segundo := float(n) / segundos
	# Rota de hoje (para o desvio), densa.
	var rota := PackedVector2Array()
	for i in range(2880):
		var p := Geometria.rota_base(geo.pier, geo.praca, _s, i / 2880.0)
		rota.append(Vector2(p.x, p.z))
	# Por quadro.
	var folgas := PackedFloat32Array()
	folgas.resize(quadros)
	var celulas: Array = []
	celulas.resize(quadros)
	var guinadas := PackedFloat64Array()
	guinadas.resize(quadros)
	var fora_da_grade := 0
	var minimo := {"folga": INF, "altura": INF, "velocidade": INF, "alvo_h": INF, "alinhamento": INF, "alvo_chao": INF}
	var maximo := {"altura": -INF, "velocidade": -INF, "alvo_h": -INF, "inclinacao": -INF, "guinada": -INF, "acel_guinada": -INF, "arfagem": -INF, "lateral": -INF, "vel_vertical": -INF, "acel_vertical": -INF, "desvio": -INF, "desvio_instante": -INF, "jerk": -INF, "acel_total": -INF}
	var quando := {}
	var abaixo_folga := 0
	var fora_altura := 0
	var soma_desvio := 0.0
	var soma_desvio_instante := 0.0
	var cone_violando := 0
	var cone_menor := INF
	var cone_piores: Array = []
	var indice_rota := 0
	for f in range(quadros):
		var t_s := float(f) / FPS
		var progresso := t_s / segundos
		var u := fposmod(progresso, 1.0) * n
		var i := floori(u)
		var t := u - i
		i = posmod(i, n)
		var e := _cr3(ox, oy, oz, i, t, n)
		var a := _cr3(ax, ay, az, i, t, n)
		# Em metros e segundos.
		var p_olho := Vector3(e[0], e[1], e[2])
		var p_alvo := Vector3(a[0], a[1], a[2])
		var k1 := por_segundo * _s
		var k2 := por_segundo * por_segundo * _s
		var k3 := por_segundo * por_segundo * por_segundo * _s
		var v := [e[3] * k1, e[4] * k1, e[5] * k1]
		var ac := [e[6] * k2, e[7] * k2, e[8] * k2]
		var jk := [e[9] * k3, e[10] * k3, e[11] * k3]
		var va := [a[3] * k1, a[4] * k1, a[5] * k1]
		var aa := [a[6] * k2, a[7] * k2, a[8] * k2]
		# H1: folga.
		if not geo.dentro(p_olho.x, p_olho.z) or not geo.dentro(p_olho.x - RAIO_BUSCA_M / _s, p_olho.z - RAIO_BUSCA_M / _s) or not geo.dentro(p_olho.x + RAIO_BUSCA_M / _s, p_olho.z + RAIO_BUSCA_M / _s):
			fora_da_grade += 1
		var folga: float = geo.folga(p_olho, RAIO_BUSCA_M)
		folgas[f] = folga
		celulas[f] = [geo.ultima_celula, geo.ultima_faixa]
		if folga < FOLGA_MIN_M:
			abaixo_folga += 1
		_min(minimo, quando, "folga", folga, t_s)
		# H2: altura sobre o chao local.
		var altura: float = (p_olho.y - geo.chao(p_olho.x, p_olho.z)) * _s
		_min(minimo, quando, "altura", altura, t_s)
		_max(maximo, quando, "altura", altura, t_s)
		if altura < ALTURA_MIN_M or altura > ALTURA_MAX_M:
			fora_altura += 1
		# Velocidade e aceleracoes do olho.
		var velocidade := sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2])
		_min(minimo, quando, "velocidade", velocidade, t_s)
		_max(maximo, quando, "velocidade", velocidade, t_s)
		var vh := sqrt(v[0] * v[0] + v[2] * v[2])
		var lateral := 0.0
		if vh > 1e-6:
			# Componente horizontal da aceleracao perpendicular a velocidade horizontal.
			lateral = absf(ac[0] * v[2] - ac[2] * v[0]) / vh
		_max(maximo, quando, "lateral", lateral, t_s)
		_max(maximo, quando, "vel_vertical", absf(v[1]), t_s)
		_max(maximo, quando, "acel_vertical", absf(ac[1]), t_s)
		_max(maximo, quando, "acel_total", sqrt(ac[0] * ac[0] + ac[1] * ac[1] + ac[2] * ac[2]), t_s)
		_max(maximo, quando, "jerk", sqrt(jk[0] * jk[0] + jk[1] * jk[1] + jk[2] * jk[2]), t_s)
		# Olhar: guinada e arfagem do eixo olho -> alvo, com derivadas exatas.
		var lx: float = (a[0] - e[0]) * _s
		var ly: float = (a[1] - e[1]) * _s
		var lz: float = (a[2] - e[2]) * _s
		var dlx: float = va[0] - v[0]
		var dly: float = va[1] - v[1]
		var dlz: float = va[2] - v[2]
		var ddlx: float = aa[0] - ac[0]
		var ddlz: float = aa[2] - ac[2]
		var h2: float = lx * lx + lz * lz
		var h := sqrt(h2)
		var guinada := 0.0
		var acel_guinada := 0.0
		var arfagem := 0.0
		if h2 > 1e-9:
			var cruz: float = dlx * lz - dlz * lx
			guinada = cruz / h2
			var dcruz: float = ddlx * lz - ddlz * lx
			acel_guinada = (dcruz * h2 - cruz * 2.0 * (lx * dlx + lz * dlz)) / (h2 * h2)
			var dh: float = (lx * dlx + lz * dlz) / h
			arfagem = (dly * h - ly * dh) / (h2 + ly * ly)
		guinadas[f] = absf(rad_to_deg(guinada))
		_max(maximo, quando, "guinada", absf(rad_to_deg(guinada)), t_s)
		_max(maximo, quando, "acel_guinada", absf(rad_to_deg(acel_guinada)), t_s)
		_max(maximo, quando, "arfagem", absf(rad_to_deg(arfagem)), t_s)
		# H4: enquadramento.
		_min(minimo, quando, "alvo_h", h, t_s)
		_max(maximo, quando, "alvo_h", h, t_s)
		if h > 1e-6:
			_max(maximo, quando, "inclinacao", absf(ly) / h, t_s)
			if vh > 1e-6:
				_min(minimo, quando, "alinhamento", (lx * v[0] + lz * v[2]) / (h * vh), t_s)
		_min(minimo, quando, "alvo_chao", (p_alvo.y - geo.chao(p_alvo.x, p_alvo.z)) * _s, t_s)
		# H6: desvio da rota de hoje (ao tracado e no mesmo instante).
		var xz := Vector2(p_olho.x, p_olho.z)
		var desvio := _distancia_ao_tracado(rota, xz) * _s
		var base_agora := Geometria.rota_base(geo.pier, geo.praca, _s, progresso)
		var desvio_instante := xz.distance_to(Vector2(base_agora.x, base_agora.z)) * _s
		soma_desvio += desvio
		soma_desvio_instante += desvio_instante
		_max(maximo, quando, "desvio", desvio, t_s)
		_max(maximo, quando, "desvio_instante", desvio_instante, t_s)
		# Cone frontal.
		var frente := Vector3(lx, ly, lz).normalized()
		var cone := _cone_frontal(p_olho, frente)
		if cone < CONE_ALCANCE_M:
			cone_violando += 1
			cone_piores.append([cone, t_s])
		cone_menor = minf(cone_menor, cone)
	# Piores pontos de folga, separados no tempo.
	var ordem: Array = range(quadros)
	ordem.sort_custom(func(x: int, y: int) -> bool: return folgas[x] < folgas[y])
	var piores: Array = []
	var separacao := int(SEPARACAO_PIORES_S * FPS)
	for f in ordem:
		if piores.size() >= PIORES or folgas[f] >= RAIO_BUSCA_M:
			break
		var perto := false
		for ja in piores:
			var df := absi(int(ja["quadro"]) - f)
			if mini(df, quadros - df) < separacao:
				perto = true
				break
		if perto:
			continue
		var progresso := float(f) / FPS / segundos
		var p := Geometria.catmull_rom(olho, progresso)
		var info: Array = celulas[f]
		var celula: Vector2i = info[0]
		var obstaculo: Variant = null
		if celula.x >= 0:
			var c: Vector2 = geo.centro_da_celula(celula.x, celula.y)
			obstaculo = {"centro_u": [snappedf(c.x, 0.001), snappedf(c.y, 0.001)], "faixa_m": "%d-%d" % [int(info[1]) * 2, int(info[1]) * 2 + 2], "topo_da_coluna_m": geo.topo_m(c.x, c.y)}
		piores.append({"quadro": f, "t_s": snappedf(float(f) / FPS, 0.001), "progresso": snappedf(progresso, 0.0001), "olho_u": [snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)], "folga_m": snappedf(folgas[f], 0.01), "altura_m": snappedf((p.y - geo.chao(p.x, p.z)) * _s, 0.01), "obstaculo": obstaculo})
	cone_piores.sort()
	var cone_lista: Array = []
	for item in cone_piores.slice(0, 10):
		cone_lista.append({"t_s": snappedf(float(item[1]), 0.001), "distancia_m": snappedf(float(item[0]), 0.01)})
	# p95 da guinada.
	var g_ordenada := guinadas.duplicate()
	g_ordenada.sort()
	var p95_guinada := g_ordenada[int(quadros * 0.95)]
	# Ancoras: t = 0 no pier; a praca e a menor distancia no ciclo (horizontal). O meio
	# do ciclo NAO precisa cair na praca: a volta contorna mais arvores e leva mais tempo
	# que a ida, e forcar 36 s + 36 s estoura a guinada ou a aceleracao lateral.
	var olho0 := Geometria.catmull_rom(olho, 0.0)
	var olho_meio := Geometria.catmull_rom(olho, 36.0 / segundos)
	var pier_t0 := Vector2(olho0.x - geo.pier.x, olho0.z - geo.pier.z).length() * _s
	var praca_meio := INF
	for i in range(olho.size()):
		praca_meio = minf(praca_meio, Vector2(olho[i].x - geo.praca.x, olho[i].z - geo.praca.z).length() * _s)
	var por_estilo := {}
	var ancoras_estilo: Dictionary = geo.cabecalho.get("ancoras_por_estilo", {})
	for estilo in ancoras_estilo:
		var anc: Dictionary = ancoras_estilo[estilo]
		var pe: Array = anc["pier"]
		var pr: Array = anc["praca"]
		por_estilo[estilo] = {"pier_t0_m": snappedf(Vector2(olho0.x - float(pe[0]), olho0.z - float(pe[2])).length() * _s, 0.01), "praca_t36_m": snappedf(Vector2(olho_meio.x - float(pr[0]), olho_meio.z - float(pr[2])).length() * _s, 0.01)}
	var traj_pier: Array = trajeto.get("pier", [0, 0, 0])
	var traj_praca: Array = trajeto.get("praca", [0, 0, 0])
	var ancoras_trajeto := {"pier_m": Vector3(float(traj_pier[0]), float(traj_pier[1]), float(traj_pier[2])).distance_to(geo.pier) * _s, "praca_m": Vector3(float(traj_praca[0]), float(traj_praca[1]), float(traj_praca[2])).distance_to(geo.praca) * _s}
	# Continuidade na volta (C0/C1), olho e alvo, em metros e m/s.
	var lados_o: Dictionary = Geometria.catmull_rom_lados(olho, 0)
	var lados_a: Dictionary = Geometria.catmull_rom_lados(alvo, 0)
	var c0_o: float = (lados_o.fim as Vector3).distance_to(lados_o.inicio) * _s
	var c1_o: float = (lados_o.d_fim as Vector3).distance_to(lados_o.d_inicio) * _s / segundos
	var c0_a: float = (lados_a.fim as Vector3).distance_to(lados_a.inicio) * _s
	var c1_a: float = (lados_a.d_fim as Vector3).distance_to(lados_a.d_inicio) * _s / segundos
	var desvio_medio := soma_desvio / quadros
	var restricoes := {
		"H1_folga": {"ok": minimo["folga"] >= FOLGA_MIN_M, "folga_min_m": minimo["folga"], "quadros_abaixo": abaixo_folga, "limite_m": FOLGA_MIN_M},
		"H2_altura": {"ok": minimo["altura"] >= ALTURA_MIN_M and maximo["altura"] <= ALTURA_MAX_M, "min_m": minimo["altura"], "max_m": maximo["altura"], "quadros_fora": fora_altura, "faixa_m": [ALTURA_MIN_M, ALTURA_MAX_M]},
		"H3_suavidade": {
			"ok": maximo["guinada"] <= limite_guinada and maximo["lateral"] <= limite_lateral and maximo["vel_vertical"] <= VELOCIDADE_VERTICAL_MAX and maximo["acel_vertical"] <= ACELERACAO_VERTICAL_MAX,
			"guinada_max_graus_s": maximo["guinada"], "limite_guinada_graus_s": limite_guinada, "guinada_ok": maximo["guinada"] <= limite_guinada,
			"lateral_max_m_s2": maximo["lateral"], "limite_lateral_m_s2": limite_lateral, "lateral_ok": maximo["lateral"] <= limite_lateral,
			"vel_vertical_max_m_s": maximo["vel_vertical"], "limite_vel_vertical_m_s": VELOCIDADE_VERTICAL_MAX, "vel_vertical_ok": maximo["vel_vertical"] <= VELOCIDADE_VERTICAL_MAX,
			"acel_vertical_max_m_s2": maximo["acel_vertical"], "limite_acel_vertical_m_s2": ACELERACAO_VERTICAL_MAX, "acel_vertical_ok": maximo["acel_vertical"] <= ACELERACAO_VERTICAL_MAX,
		},
		"H4_enquadramento": {
			"ok": minimo["alvo_h"] >= ALVO_MIN_M and maximo["alvo_h"] <= ALVO_MAX_M and maximo["inclinacao"] <= INCLINACAO_MAX and minimo["alinhamento"] >= ALINHAMENTO_MIN and minimo["alvo_chao"] >= ALVO_SOBRE_CHAO_MIN_M,
			"alvo_h_min_m": minimo["alvo_h"], "alvo_h_max_m": maximo["alvo_h"], "faixa_alvo_m": [ALVO_MIN_M, ALVO_MAX_M],
			"inclinacao_max": maximo["inclinacao"], "limite_inclinacao": INCLINACAO_MAX,
			"alinhamento_min": minimo["alinhamento"], "limite_alinhamento": ALINHAMENTO_MIN,
			"alvo_sobre_chao_min_m": minimo["alvo_chao"], "limite_alvo_sobre_chao_m": ALVO_SOBRE_CHAO_MIN_M,
		},
		"H5_continuidade": {"ok": c0_o < 0.001 and c1_o < 0.01 and c0_a < 0.001 and c1_a < 0.01, "olho_c0_m": c0_o, "olho_c1_m_s": c1_o, "alvo_c0_m": c0_a, "alvo_c1_m_s": c1_a},
		"H6_fidelidade": {"ok": pier_t0 <= PIER_MAX_M and praca_meio <= PRACA_MAX_M and maximo["desvio"] <= DESVIO_MAX_M, "pier_t0_m": pier_t0, "limite_pier_m": PIER_MAX_M, "praca_t36_m": praca_meio, "limite_praca_m": PRACA_MAX_M, "desvio_max_m": maximo["desvio"], "limite_desvio_m": DESVIO_MAX_M},
	}
	var aprovado := true
	for chave in restricoes:
		aprovado = aprovado and bool(restricoes[chave]["ok"])
	return {
		"versao": 1, "trajeto": caminho_trajeto, "geometria": caminho_geo, "estilo_geometria": geo.cabecalho.get("estilo", "?"),
		"quadros": quadros, "fps": FPS, "segundos": segundos, "amostras": n,
		"aprovado": aprovado, "restricoes": restricoes,
		"folga": {"min_m": minimo["folga"], "t_min_s": quando.get("min_folga", 0.0), "quadros_abaixo_5m": abaixo_folga, "raio_de_busca_m": RAIO_BUSCA_M, "quadros_perto_da_borda_da_grade": fora_da_grade, "piores": piores},
		"cone_frontal": {"semi_angulo_graus": CONE_SEMI_GRAUS, "alcance_m": CONE_ALCANCE_M, "eixo": "olho -> alvo", "quadros_violando": cone_violando, "menor_distancia_m": cone_menor, "piores": cone_lista},
		"altura_olho_m": {"min": minimo["altura"], "t_min_s": quando.get("min_altura", 0.0), "max": maximo["altura"], "t_max_s": quando.get("max_altura", 0.0), "quadros_fora_14_18": fora_altura},
		"guinada": {"max_graus_s": maximo["guinada"], "t_max_s": quando.get("max_guinada", 0.0), "p95_graus_s": p95_guinada, "aceleracao_max_graus_s2": maximo["acel_guinada"], "t_aceleracao_max_s": quando.get("max_acel_guinada", 0.0)},
		"arfagem": {"taxa_max_graus_s": maximo["arfagem"], "t_max_s": quando.get("max_arfagem", 0.0)},
		"olho": {"velocidade_min_m_s": minimo["velocidade"], "t_velocidade_min_s": quando.get("min_velocidade", 0.0), "velocidade_max_m_s": maximo["velocidade"], "t_velocidade_max_s": quando.get("max_velocidade", 0.0), "aceleracao_lateral_max_m_s2": maximo["lateral"], "t_lateral_max_s": quando.get("max_lateral", 0.0), "velocidade_vertical_max_m_s": maximo["vel_vertical"], "t_vel_vertical_max_s": quando.get("max_vel_vertical", 0.0), "aceleracao_vertical_max_m_s2": maximo["acel_vertical"], "t_acel_vertical_max_s": quando.get("max_acel_vertical", 0.0), "aceleracao_total_max_m_s2": maximo["acel_total"], "solavanco_max_m_s3": maximo["jerk"]},
		"alvo": {"distancia_horizontal_min_m": minimo["alvo_h"], "distancia_horizontal_max_m": maximo["alvo_h"], "inclinacao_max": maximo["inclinacao"], "alinhamento_min": minimo["alinhamento"], "t_alinhamento_min_s": quando.get("min_alinhamento", 0.0), "alvo_sobre_chao_min_m": minimo["alvo_chao"]},
		"rota_base": {"desvio_medio_m": desvio_medio, "desvio_max_m": maximo["desvio"], "t_desvio_max_s": quando.get("max_desvio", 0.0), "desvio_mesmo_instante_medio_m": soma_desvio_instante / quadros, "desvio_mesmo_instante_max_m": maximo["desvio_instante"]},
		"ancoras": {"pier_t0_m": pier_t0, "praca_t36_m": praca_meio, "por_estilo": por_estilo, "trajeto_vs_geometria": ancoras_trajeto},
		"continuidade": {"olho_c0_m": c0_o, "olho_c1_m_s": c1_o, "alvo_c0_m": c0_a, "alvo_c1_m_s": c1_a},
		"avisos": avisos, "tempo_s": (Time.get_ticks_msec() - inicio) / 1000.0,
	}


## A camera de hoje: a cada quadro (60 fps) ela anda blend = clamp(delta * taxa) do
## caminho ate o olho e o alvo da formula (abertura.gd de HEAD, _process). Roda dois
## ciclos e mede o segundo (o filtro esquece o comeco em ~1 s). Derivadas por diferenca
## central em double: aqui nao ha float32 no caminho, a curva sai da cubica em double.
func simular_lerp(taxa: float) -> Dictionary:
	var quadros := int(round(_segundos * FPS))
	var n := _olho.size()
	var dt := 1.0 / FPS
	var blend := clampf(dt * taxa, 0.0, 1.0)
	var e := _cr_d(_olho, 0.0)
	var a := _cr_d(_alvo, 0.0)
	var cam := PackedFloat64Array()
	cam.resize(quadros * 6)
	var atraso_max := 0.0
	var atraso_soma := 0.0
	for f in range(2 * quadros):
		var progresso := float(f + 1) / FPS / _segundos
		var eo := _cr_d(_olho, progresso)
		var ao := _cr_d(_alvo, progresso)
		for k in range(3):
			e[k] = lerpf(e[k], eo[k], blend)
			a[k] = lerpf(a[k], ao[k], blend)
		if f >= quadros:
			var g := f - quadros
			for k in range(3):
				cam[g * 6 + k] = e[k]
				cam[g * 6 + 3 + k] = a[k]
			var atraso := Vector2(e[0] - eo[0], e[2] - eo[2]).length() * _s
			atraso_max = maxf(atraso_max, atraso)
			atraso_soma += atraso
	var guinada_max := 0.0
	var guinadas := PackedFloat64Array()
	guinadas.resize(quadros)
	var lateral_max := 0.0
	var vv_max := 0.0
	var av_max := 0.0
	var folga_min := INF
	var abaixo := 0
	var altura_min := INF
	var altura_max := -INF
	for g in range(quadros):
		var gm := posmod(g - 1, quadros)
		var gp := (g + 1) % quadros
		var p := Vector3(cam[g * 6], cam[g * 6 + 1], cam[g * 6 + 2])
		var v := [(cam[gp * 6] - cam[gm * 6]) * 0.5 * FPS * _s, (cam[gp * 6 + 1] - cam[gm * 6 + 1]) * 0.5 * FPS * _s, (cam[gp * 6 + 2] - cam[gm * 6 + 2]) * 0.5 * FPS * _s]
		var ac := [(cam[gp * 6] - 2.0 * cam[g * 6] + cam[gm * 6]) * FPS * FPS * _s, (cam[gp * 6 + 1] - 2.0 * cam[g * 6 + 1] + cam[gm * 6 + 1]) * FPS * FPS * _s, (cam[gp * 6 + 2] - 2.0 * cam[g * 6 + 2] + cam[gm * 6 + 2]) * FPS * FPS * _s]
		var vh: float = sqrt(v[0] * v[0] + v[2] * v[2])
		if vh > 1e-6:
			lateral_max = maxf(lateral_max, absf(ac[0] * v[2] - ac[2] * v[0]) / vh)
		vv_max = maxf(vv_max, absf(v[1]))
		av_max = maxf(av_max, absf(ac[1]))
		var rumo_m := atan2(cam[gm * 6 + 3] - cam[gm * 6], cam[gm * 6 + 5] - cam[gm * 6 + 2])
		var rumo_p := atan2(cam[gp * 6 + 3] - cam[gp * 6], cam[gp * 6 + 5] - cam[gp * 6 + 2])
		var guinada := absf(rad_to_deg(wrapf(rumo_p - rumo_m, -PI, PI)) * 0.5 * FPS)
		guinadas[g] = guinada
		guinada_max = maxf(guinada_max, guinada)
		var folga: float = geo.folga(p, RAIO_BUSCA_M)
		folga_min = minf(folga_min, folga)
		if folga < FOLGA_MIN_M:
			abaixo += 1
		var altura: float = (p.y - geo.chao(p.x, p.z)) * _s
		altura_min = minf(altura_min, altura)
		altura_max = maxf(altura_max, altura)
	var ordenada := guinadas.duplicate()
	ordenada.sort()
	return {"taxa_lerp_por_s": taxa, "blend_por_quadro": blend, "atraso_horizontal_medio_m": atraso_soma / quadros, "atraso_horizontal_max_m": atraso_max,
		"guinada_max_graus_s": guinada_max, "guinada_p95_graus_s": ordenada[int(quadros * 0.95)], "aceleracao_lateral_max_m_s2": lateral_max,
		"velocidade_vertical_max_m_s": vv_max, "aceleracao_vertical_max_m_s2": av_max, "folga_min_m": folga_min, "quadros_abaixo_5m": abaixo,
		"altura_min_m": altura_min, "altura_max_m": altura_max}


func _cr_d(amostras: PackedVector3Array, progresso: float) -> PackedFloat64Array:
	var n := amostras.size()
	var u := fposmod(progresso, 1.0) * n
	var i := floori(u)
	var t := u - i
	i = posmod(i, n)
	var p0 := amostras[(i - 1 + n) % n]
	var p1 := amostras[i]
	var p2 := amostras[(i + 1) % n]
	var p3 := amostras[(i + 2) % n]
	var saida := PackedFloat64Array()
	saida.resize(3)
	for k in range(3):
		var a0: float = p0[k]
		var a1: float = p1[k]
		var a2: float = p2[k]
		var a3: float = p3[k]
		saida[k] = 0.5 * (2.0 * a1 + (-a0 + a2) * t + (2.0 * a0 - 5.0 * a1 + 4.0 * a2 - a3) * t * t + (-a0 + 3.0 * a1 - 3.0 * a2 + a3) * t * t * t)
	return saida


## Catmull-Rom periodica em double: [x, y, z, x', y', z', x'', y'', z'', x''', y''', z''']
## no segmento i, parametro t (derivadas em relacao ao parametro do segmento).
func _cr3(xs: PackedFloat64Array, ys: PackedFloat64Array, zs: PackedFloat64Array, i: int, t: float, n: int) -> PackedFloat64Array:
	var i0 := (i - 1 + n) % n
	var i2 := (i + 1) % n
	var i3 := (i + 2) % n
	var saida := PackedFloat64Array()
	saida.resize(12)
	var t2 := t * t
	var eixo := 0
	for arr in [xs, ys, zs]:
		var p0: float = arr[i0]
		var p1: float = arr[i]
		var p2: float = arr[i2]
		var p3: float = arr[i3]
		var b := -p0 + p2
		var c := 2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3
		var d := -p0 + 3.0 * p1 - 3.0 * p2 + p3
		saida[eixo] = 0.5 * (2.0 * p1 + b * t + c * t2 + d * t2 * t)
		saida[3 + eixo] = 0.5 * (b + 2.0 * c * t + 3.0 * d * t2)
		saida[6 + eixo] = 0.5 * (2.0 * c + 6.0 * d * t)
		saida[9 + eixo] = 3.0 * d
		eixo += 1
	return saida


func _min(minimo: Dictionary, quando: Dictionary, chave: String, valor: float, t: float) -> void:
	if valor < float(minimo[chave]):
		minimo[chave] = valor
		quando["min_" + chave] = t


func _max(maximo: Dictionary, quando: Dictionary, chave: String, valor: float, t: float) -> void:
	if valor > float(maximo[chave]):
		maximo[chave] = valor
		quando["max_" + chave] = t


## Distancia do ponto ao tracado fechado da rota (unidades): primeiro o vertice mais
## perto entre 1 de cada 16, depois os segmentos em volta dele.
func _distancia_ao_tracado(rota: PackedVector2Array, p: Vector2) -> float:
	var n := rota.size()
	var melhor := 0
	var menor := INF
	for k in range(0, n, 16):
		var d := p.distance_squared_to(rota[k])
		if d < menor:
			menor = d
			melhor = k
	var resposta := INF
	for k in range(melhor - 40, melhor + 40):
		var a := rota[posmod(k, n)]
		var b := rota[posmod(k + 1, n)]
		resposta = minf(resposta, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return resposta


## Menor distancia (m) a uma caixa celula x faixa ocupada que caia no cone frontal
## (semiabertura CONE_SEMI_GRAUS em volta de `frente`, ate CONE_ALCANCE_M). A caixa conta
## se o centro dela estiver no cone alargado pelo raio angular dela. INF se nada.
func _cone_frontal(p: Vector3, frente: Vector3) -> float:
	var alcance_u := CONE_ALCANCE_M / _s
	var c: float = geo.celula
	var ix0 := maxi(floori((p.x - alcance_u - geo.origem.x) / c), 0)
	var ix1 := mini(floori((p.x + alcance_u - geo.origem.x) / c), geo.nx - 1)
	var iz0 := maxi(floori((p.z - alcance_u - geo.origem.y) / c), 0)
	var iz1 := mini(floori((p.z + alcance_u - geo.origem.y) / c), geo.nz - 1)
	var cos_cone := cos(deg_to_rad(CONE_SEMI_GRAUS))
	var meia_diagonal := sqrt(2.0 * (c * _s * 0.5) * (c * _s * 0.5) + 1.0)
	var menor := INF
	for iz in range(iz0, iz1 + 1):
		var linha: int = iz * geo.nx
		var zc0: float = geo.origem.y + iz * c
		for ix in range(ix0, ix1 + 1):
			var m: int = geo.mascara[linha + ix]
			if m == 0:
				continue
			m = m & 0xFFFFFFFF
			var xc0: float = geo.origem.x + ix * c
			var g: float = geo.chao_celula[linha + ix]
			var dx := maxf(maxf(xc0 - p.x, p.x - xc0 - c), 0.0) * _s
			var dz := maxf(maxf(zc0 - p.z, p.z - zc0 - c), 0.0) * _s
			if dx * dx + dz * dz > CONE_ALCANCE_M * CONE_ALCANCE_M:
				continue
			var yrel := (p.y - g) * _s
			var k0 := maxi(floori((yrel - CONE_ALCANCE_M) * 0.5), 0)
			var k1 := mini(floori((yrel + CONE_ALCANCE_M) * 0.5), 31)
			for k in range(k0, k1 + 1):
				if (m >> k) & 1 == 0:
					continue
				var dy := maxf(maxf(2.0 * k - yrel, yrel - 2.0 * k - 2.0), 0.0)
				var dist := sqrt(dx * dx + dy * dy + dz * dz)
				if dist > CONE_ALCANCE_M or dist >= menor:
					continue
				var centro := Vector3((xc0 + c * 0.5 - p.x) * _s, 2.0 * k + 1.0 - yrel, (zc0 + c * 0.5 - p.z) * _s)
				var dc := centro.length()
				if dc < 1e-6:
					menor = 0.0
					continue
				var cosseno := centro.dot(frente) / dc
				var folga_angular := asin(minf(1.0, meia_diagonal / dc))
				if cosseno >= cos(minf(deg_to_rad(CONE_SEMI_GRAUS) + folga_angular, PI)):
					menor = dist
	return menor


## Numeros de suavidade e folga deste trajeto ao lado dos da referencia (a base).
func comparar(r: Dictionary, ref: Dictionary) -> Dictionary:
	var pares := {
		"guinada_max_graus_s": [r["guinada"]["max_graus_s"], ref["guinada"]["max_graus_s"]],
		"guinada_p95_graus_s": [r["guinada"]["p95_graus_s"], ref["guinada"]["p95_graus_s"]],
		"aceleracao_guinada_max_graus_s2": [r["guinada"]["aceleracao_max_graus_s2"], ref["guinada"]["aceleracao_max_graus_s2"]],
		"aceleracao_lateral_max_m_s2": [r["olho"]["aceleracao_lateral_max_m_s2"], ref["olho"]["aceleracao_lateral_max_m_s2"]],
		"velocidade_vertical_max_m_s": [r["olho"]["velocidade_vertical_max_m_s"], ref["olho"]["velocidade_vertical_max_m_s"]],
		"aceleracao_vertical_max_m_s2": [r["olho"]["aceleracao_vertical_max_m_s2"], ref["olho"]["aceleracao_vertical_max_m_s2"]],
		"solavanco_max_m_s3": [r["olho"]["solavanco_max_m_s3"], ref["olho"]["solavanco_max_m_s3"]],
		"velocidade_min_m_s": [r["olho"]["velocidade_min_m_s"], ref["olho"]["velocidade_min_m_s"]],
		"velocidade_max_m_s": [r["olho"]["velocidade_max_m_s"], ref["olho"]["velocidade_max_m_s"]],
		"folga_min_m": [r["folga"]["min_m"], ref["folga"]["min_m"]],
		"quadros_abaixo_5m": [r["folga"]["quadros_abaixo_5m"], ref["folga"]["quadros_abaixo_5m"]],
	}
	var saida := {}
	for chave in pares:
		var este := float(pares[chave][0])
		var base := float(pares[chave][1])
		saida[chave] = {"este": este, "referencia": base, "razao": este / base if absf(base) > 1e-9 else null}
	return saida


func _imprimir_resumo(r: Dictionary) -> void:
	print("AVALIACAO %s contra %s (%s)" % [String(r["trajeto"]).get_file(), String(r["geometria"]).get_file(), r["estilo_geometria"]])
	for chave in r["restricoes"]:
		print("  %s %s" % ["OK   " if r["restricoes"][chave]["ok"] else "FALHA", chave])
	print("  folga min %.2f m (t=%.2f s), %d quadros < 5 m; cone frontal: %d quadros" % [r["folga"]["min_m"], r["folga"]["t_min_s"], r["folga"]["quadros_abaixo_5m"], r["cone_frontal"]["quadros_violando"]])
	print("  guinada max %.2f graus/s (p95 %.2f), lateral max %.3f m/s2, vel %.2f-%.2f m/s, vertical %.3f m/s / %.3f m/s2" % [r["guinada"]["max_graus_s"], r["guinada"]["p95_graus_s"], r["olho"]["aceleracao_lateral_max_m_s2"], r["olho"]["velocidade_min_m_s"], r["olho"]["velocidade_max_m_s"], r["olho"]["velocidade_vertical_max_m_s"], r["olho"]["aceleracao_vertical_max_m_s2"]])
	print("  altura %.2f-%.2f m; alvo %.1f-%.1f m; desvio max %.1f m; pier t0 %.1f m; praca t36 %.1f m; %.1f s" % [r["altura_olho_m"]["min"], r["altura_olho_m"]["max"], r["alvo"]["distancia_horizontal_min_m"], r["alvo"]["distancia_horizontal_max_m"], r["rota_base"]["desvio_max_m"], r["ancoras"]["pier_t0_m"], r["ancoras"]["praca_t36_m"], r["tempo_s"]])
