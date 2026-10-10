extends SceneTree
## PLANO DO BIOMA DA ORLA: coqueiral contínuo e manguezal no leito dos rios.
## Regras em docs/mundo/BIOMA_DA_ORLA.md. Monta o vale com a composição atual e
## grava res://tools/mapas/bioma_orla_plano.json; quem aplica na cena é
## tools/mapas/aplicar_bioma_orla.py (só acrescenta blocos, sem regravar a cena).
##
##     Godot --headless --path . --script res://tools/mapas/bioma_orla.gd

const PLANO := "res://tools/mapas/bioma_orla_plano.json"
## Onde o editor guarda o que o código sorteia; vale para o grupo que a cena ainda não tem.
const SEMENTE := "res://data/composicao/avulsos_padrao.json"
## Folga em volta da ponte, além do comprimento e da largura dela.
const FOLGA_DA_PONTE := 4.0
## Coqueiral baiano: fileira quase contínua na orla.
const PASSO_COQUEIRO := Vector2(4.5, 7.0)
## Primeira fileira na areia; a segunda, mais para dentro, em metade dos pontos.
const RECUO_COQUEIRO := Vector2(2.0, 6.0)
const RECUO_SEGUNDA_FILEIRA := Vector2(7.0, 12.0)
const CHANCE_SEGUNDA_FILEIRA := 0.5
const ESPACO_COQUEIRO := 4.0
const PERTO_DO_MANGUE := 12.0
const CHANCE_PERTO_DO_MANGUE := 0.2
const CHANCE_DE_BOSQUE := 0.4
const FOLGA_DA_CASA := 9.0
## Manguezal: nas duas margens, colado à água, por todo o leito.
const PASSO_MANGUE := Vector2(3.5, 6.0)
const RECUO_MANGUE := Vector2(0.8, 2.5)
const ESPACO_MANGUE := 3.0


## Quantos pontos cada motivo recusou (reservas do paisagismo por tipo, ponte, zona,
## clareira), para ver o que o level design tirou da orla.
var recusas := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var mundo := (load("res://scripts/prototipo_3d/world_builder.gd") as Script).new() as Node3D
	root.add_child(mundo)
	if not mundo.construido:
		await mundo.pronto
	var r = mundo._region
	var rng := RandomNumberGenerator.new()
	rng.seed = 18870514
	var agua: float = mundo.water_level()
	var casas: Array[Vector2] = []
	for nome in mundo.construcoes_editaveis:
		var p: Vector3 = mundo.construcoes_editaveis[nome]["pos"]
		casas.append(Vector2(p.x, p.z))
	var coqueiros: Array[Vector2] = []
	var mangues: Array[Vector2] = []
	var existentes := {}
	var avulsos: Dictionary = load("res://scripts/prototipo_3d/composicao_vale.gd").ler_avulsos()
	var grupos_da_cena: Array = avulsos.get("grupos", [])
	for id in avulsos["itens"]:
		var it: Dictionary = avulsos["itens"][id]
		var o: Vector3 = (it["transform"] as Transform3D).origin
		if it["grupo"] == "Coqueiros da orla":
			coqueiros.append(Vector2(o.x, o.z))
			existentes[id] = o.z
		elif it["grupo"] == "Manguezal":
			mangues.append(Vector2(o.x, o.z))
	# Grupo que a cena ainda não tem: vale o que o código sorteou (a semente), que
	# aplicar_bioma_orla.py materializa na cena antes de acrescentar o plano.
	var da_semente := {}
	if FileAccess.file_exists(SEMENTE):
		var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(SEMENTE))
		if typeof(dados) == TYPE_DICTIONARY:
			for it in (dados as Dictionary).get("avulsos", []):
				var grupo := String(it.get("grupo", ""))
				if grupo in ["Coqueiros da orla", "Manguezal"] and not grupos_da_cena.has(grupo):
					var pos: Array = it["pos"]
					da_semente[String(it["id"])] = grupo
					if grupo == "Coqueiros da orla":
						coqueiros.append(Vector2(float(pos[0]), float(pos[2])))
						existentes[String(it["id"])] = float(pos[2])
					else:
						mangues.append(Vector2(float(pos[0]), float(pos[2])))
	# O que o level design já ocupa e a orla não pode pisar: reservas do paisagismo
	# (casas, lotes, nomeadas, âncoras, portas, veredas), pontes e as zonas dele.
	var paisagismo := load("res://scripts/prototipo_3d/paisagismo_vale.gd")
	var reservas: Dictionary = paisagismo.reservas_do_mundo(mundo, paisagismo.ler_receitas()).duplicate()
	for chave in ["terra", "rua", "costa", "rio", "voo"]:
		reservas.erase(chave)
	var ocupado := {"reservas": reservas, "regras": paisagismo.ler_receitas().get("reservas", {}), "pontes": mundo.pontes, "zonas": []}
	for zona in paisagismo.ler():
		ocupado["zonas"].append(zona["poligono"])
	# Divisa norte/sul: a foz do rio central (o eixo z cresce para o sul).
	var divisa_z := 0.0
	for rio in r._rivers:
		if not r._is_northern_river(rio):
			divisa_z = (rio.points[0] as Vector2).y

	var novos_mangues: Array = []
	for rio in r._rivers:
		var pontos: PackedVector2Array = rio.points
		var largura := float(rio.width)
		var percorrido := 0.0
		var proximo := 0.0
		for i in pontos.size() - 1:
			var a := pontos[i]
			var b := pontos[i + 1]
			var trecho := a.distance_to(b)
			if trecho < 0.01:
				continue
			var direcao := (b - a) / trecho
			var normal := Vector2(-direcao.y, direcao.x)
			while proximo <= percorrido + trecho:
				var base := a + direcao * (proximo - percorrido)
				for lado in [-1.0, 1.0]:
					var ponto: Vector2 = base + normal * float(lado) * (largura * 0.5 + rng.randf_range(RECUO_MANGUE.x, RECUO_MANGUE.y))
					if not _livre(ponto, r, casas, agua, 0.0, 0.0, ocupado) or _perto_de_rua(ponto, r, 2.0) or r._no_vao_do_sobrevoo(ponto) or _perto(ponto, mangues) < ESPACO_MANGUE:
						continue
					mangues.append(ponto)
					novos_mangues.append({"ponto": ponto, "giro": rng.randf() * TAU, "escala": snappedf(rng.randf_range(0.8, 1.2), 0.01), "chao": r.ground_height_at(Vector3(ponto.x, 0, ponto.y))})
				proximo += rng.randf_range(PASSO_MANGUE.x, PASSO_MANGUE.y)
			percorrido += trecho

	var novos_coqueiros: Array = []
	var costa: PackedVector2Array = r._coast
	var andado := 0.0
	var proximo_coqueiro := 0.0
	for i in costa.size() - 1:
		var a := costa[i]
		var b := costa[i + 1]
		var trecho := a.distance_to(b)
		if trecho < 0.01:
			continue
		var direcao := (b - a) / trecho
		while proximo_coqueiro <= andado + trecho:
			var base := a + direcao * (proximo_coqueiro - andado)
			proximo_coqueiro += rng.randf_range(PASSO_COQUEIRO.x, PASSO_COQUEIRO.y)
			var normal := Vector2(-direcao.y, direcao.x)
			if not Geometry2D.is_point_in_polygon(base + normal * 4.0, r._land):
				normal = -normal
			var mar := -normal
			var recuos := [rng.randf_range(RECUO_COQUEIRO.x, RECUO_COQUEIRO.y)]
			if rng.randf() < CHANCE_SEGUNDA_FILEIRA:
				recuos.append(rng.randf_range(RECUO_SEGUNDA_FILEIRA.x, RECUO_SEGUNDA_FILEIRA.y))
			var ponto := Vector2.INF
			for recuo in recuos:
				var candidato := base + normal * float(recuo) + direcao * rng.randf_range(-1.5, 1.5)
				if _perto(candidato, mangues) < PERTO_DO_MANGUE and rng.randf() > CHANCE_PERTO_DO_MANGUE:
					continue
				if not _livre(candidato, r, casas, agua, 3.0, 6.0, ocupado) or _perto(candidato, coqueiros) < ESPACO_COQUEIRO:
					continue
				coqueiros.append(candidato)
				novos_coqueiros.append(_coqueiro(candidato, mar, rng, false, r))
				ponto = candidato
			if not ponto.is_finite():
				continue
			if rng.randf() < CHANCE_DE_BOSQUE:
				for _c in rng.randi_range(1, 2):
					var angulo := rng.randf() * TAU
					var perto := ponto + Vector2(cos(angulo), sin(angulo)) * rng.randf_range(3.0, 5.0)
					if _livre(perto, r, casas, agua, 3.0, 6.0, ocupado) and _perto(perto, coqueiros) >= ESPACO_COQUEIRO and _perto(perto, mangues) >= PERTO_DO_MANGUE * 0.5:
						coqueiros.append(perto)
						novos_coqueiros.append(_coqueiro(perto, mar, rng, rng.randf() < 0.45, r))
		andado += trecho
	for c in novos_coqueiros:
		c["lado"] = "Norte" if (c["ponto"] as Vector2).y < divisa_z else "Sul"
	var reagrupar := {}
	for id in existentes:
		reagrupar[id] = "Norte" if float(existentes[id]) < divisa_z else "Sul"

	var saida := {"divisa_z": divisa_z, "da_semente": da_semente, "reagrupar": reagrupar, "coqueiros": [], "mangues": []}
	for c in novos_coqueiros:
		saida["coqueiros"].append({"x": snappedf(c["ponto"].x, 0.001), "y": snappedf(c["chao"], 0.001), "z": snappedf(c["ponto"].y, 0.001), "giro": snappedf(c["giro"], 0.0001), "escala": c["escala"], "lado": c["lado"]})
	for m in novos_mangues:
		saida["mangues"].append({"x": snappedf(m["ponto"].x, 0.001), "y": snappedf(m["chao"], 0.001), "z": snappedf(m["ponto"].y, 0.001), "giro": snappedf(m["giro"], 0.0001), "escala": m["escala"]})
	var arquivo := FileAccess.open(PLANO, FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(saida, "\t") + "\n")
	arquivo.close()
	# Cobertura: trechos da orla com mais de 15 u sem coqueiro, fora do manguezal.
	var vazio := 0.0
	var vazios: Array = []
	var inicio_vazio := Vector2.INF
	for i in costa.size() - 1:
		var passos := maxi(1, int(costa[i].distance_to(costa[i + 1]) / 3.0))
		for k in passos:
			var q := costa[i].lerp(costa[i + 1], float(k) / float(passos))
			var coberto := _perto(q, coqueiros) < 12.0 or _perto(q, mangues) < PERTO_DO_MANGUE
			if coberto:
				if vazio > 15.0:
					vazios.append("%.0f u perto de %s" % [vazio, str(inicio_vazio.snapped(Vector2.ONE))])
				vazio = 0.0
			else:
				if vazio == 0.0:
					inicio_vazio = q
				vazio += costa[i].distance_to(costa[i + 1]) / float(passos)
	print("BIOMA_VAZIOS: ", vazios)
	print("BIOMA_RECUSAS: ", recusas)
	print("BIOMA_PLANO: +%d coqueiros (total %d), +%d mangues (total %d), %d coqueiros reagrupados; divisa z=%.1f" % [novos_coqueiros.size(), coqueiros.size(), novos_mangues.size(), mangues.size(), reagrupar.size(), divisa_z])
	mundo.queue_free()
	await process_frame
	quit()


## Terra firme, fora de rua/rio (rota > 0), de ponto de interesse e de casa.
## Coqueiro pode na orla da vila: em vila baiana o coqueiral chega à praia.
func _livre(ponto: Vector2, r, casas: Array[Vector2], agua: float, rota: float, interesse: float, ocupado: Dictionary) -> bool:
	if not Geometry2D.is_point_in_polygon(ponto, r._land):
		return false
	if _ocupado(ponto, r, ocupado, rota > 0.0):
		return false
	if rota > 0.0 and r._near_route(ponto, rota):
		return false
	if interesse > 0.0 and r._near_interest(ponto, interesse):
		return false
	if r.ground_height_at(Vector3(ponto.x, 0, ponto.y)) < agua + 0.05:
		return false
	return _perto(ponto, casas) >= FOLGA_DA_CASA


## O que o level design já ocupa: casas e afins (reservas do paisagismo), pontes, as
## zonas de plantio (dendezal, mata ciliar, cajual...) e, nos coqueiros, as clareiras.
func _ocupado(ponto: Vector2, r, ocupado: Dictionary, coqueiro: bool) -> bool:
	var regras: Dictionary = ocupado["regras"]
	var paisagismo := load("res://scripts/prototipo_3d/paisagismo_vale.gd")
	var motivo: String = paisagismo.bloqueado(ocupado["reservas"], regras, ponto, 0.0)
	if motivo != "":
		recusas[motivo] = int(recusas.get(motivo, 0)) + 1
		return true
	for nome in ocupado["pontes"]:
		var ponte: Dictionary = ocupado["pontes"][nome]
		var centro: Vector3 = ponte["centro"]
		var ao_longo: Vector3 = ponte["ao_longo"]
		var d := ponto - Vector2(centro.x, centro.z)
		var no_eixo := d.dot(Vector2(ao_longo.x, ao_longo.z))
		var de_lado := absf(d.dot(Vector2(-ao_longo.z, ao_longo.x)))
		if absf(no_eixo) < float(ponte["comprimento"]) * 0.5 + FOLGA_DA_PONTE and de_lado < float(ponte["largura"]) * 0.5 + FOLGA_DA_PONTE:
			recusas["ponte"] = int(recusas.get("ponte", 0)) + 1
			return true
	for zona: PackedVector2Array in ocupado["zonas"]:
		if Geometry2D.is_point_in_polygon(ponto, zona):
			recusas["zona"] = int(recusas.get("zona", 0)) + 1
			return true
	if coqueiro and r._em_clareira(ponto):
		recusas["clareira"] = int(recusas.get("clareira", 0)) + 1
		return true
	return false


## Só ruas (sem rios): o mangue nasce colado à margem do rio.
func _perto_de_rua(ponto: Vector2, r, folga: float) -> bool:
	for rua in r._roads:
		if r._distance_to_line(ponto, rua.points) < folga + float(rua.width) * 0.5:
			return true
	return false


func _perto(ponto: Vector2, outros: Array[Vector2]) -> float:
	var menor := INF
	for o in outros:
		menor = minf(menor, o.distance_to(ponto))
	return menor


## Pende para o mar (-X local é o lado do topo) com ±25°; muda é menor.
func _coqueiro(ponto: Vector2, mar: Vector2, rng: RandomNumberGenerator, muda: bool, r) -> Dictionary:
	return {"ponto": ponto, "giro": atan2(mar.y, -mar.x) + rng.randf_range(-0.44, 0.44), "escala": snappedf(rng.randf_range(0.55, 0.72) if muda else rng.randf_range(0.78, 1.18), 0.01), "chao": r.ground_height_at(Vector3(ponto.x, 0, ponto.y))}
