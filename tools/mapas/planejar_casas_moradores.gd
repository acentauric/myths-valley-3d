extends SceneTree
## PLANEJA O QUINTAL DE CADA CASA no vale montado (estilo Tripo) e escreve
## tools/mapas/casas_moradores_plano.json, que o aplicar_casas_moradores.py
## põe na composição. Não grava a cena.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/mapas/planejar_casas_moradores.gd
##
## "Um varal novo para cada casa, posicionado inteligentemente." A regra:
##   - no quintal do lado ou de trás, paralelo à parede, de 2 a 2,5 u dela (a
##     caixa do modelo inclui o beiral, uns 0,35 além da parede);
##   - a 2,5 u ou mais do eixo da porta (porta no +Z da casa);
##   - a 2 u ou mais de peças, troncos e outras casas, fora da rua e em terra;
##   - desnível menor que 0,4 ao longo da corda;
##   - o mais dentro do Terreiro que der.
## O tipo alterna entre varal, varal_bambu e varal_estacas, na ordem da cena.
## Também a pitangueira das casas novas, e o galinheiro, o chiqueiro e o cocho
## das casas que têm galinha ou porco (QUINTAL, mais o que o
## data/bichos_de_casa.json pede).

const SAIDA := "res://tools/mapas/casas_moradores_plano.json"
const VARAIS := ["varal", "varal_bambu", "varal_estacas"]
## O comprimento da corda de cada um (a largura no catálogo).
const CORDA := {"varal": 3.8, "varal_bambu": 3.8, "varal_estacas": 4.2}
## Sem varal: a herdada já tem o dela, e a casa de farinha é de trabalho.
const SEM_VARAL := ["Casa de taipa", "Casa de farinha"]
## As casas novas, com a largura do modelo que vai chegar: enquanto o GLB não
## chega elas sobem com a casca da casa de taipa, e o quintal tem de caber
## também na casa de verdade.
const LARGURA_NOVA := {"Casa do guarda": 6.5, "Casa do pescador": 5.8, "Casa da marisqueira": 5.2,
	"Casa da lavadeira": 6.5, "Casa da rendeira": 6.5, "Casa da quituteira": 7.0,
	"Casa do carpinteiro": 6.5, "Casa do arraial 7": 7.5}
const CASAS_NOVAS := ["Casa do guarda", "Casa do pescador", "Casa da marisqueira", "Casa da lavadeira",
	"Casa da rendeira", "Casa da quituteira", "Casa do carpinteiro"]
## Quem tem galinha e porco no quintal (o Seu Benedito tem os dois), e o posto de
## trabalho que fica no quintal de quem mora ali: a canoa do carpinteiro e o
## lavadouro da lavadeira (`world_builder` os faz âncoras "Casa/<chave>").
const QUINTAL := {"Casa de Carro Quebrado": ["galinheiro", "chiqueiro"],
	"Casa do carpinteiro": ["canoa_em_obra"], "Casa da lavadeira": ["lavadouro_pedra"]}
## O raio de chão que cada abrigo ou posto de trabalho ocupa (u).
const RAIO_DO_ABRIGO := {"galinheiro": 1.1, "chiqueiro": 1.7, "canoa_em_obra": 2.6, "lavadouro_pedra": 1.0}
const BEIRAL := 0.35

var mundo
var obstaculos: Array = []
var ruas: Array = []
## Por que os candidatos caíram (impresso quando a casa fica sem lugar).
var motivos: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.get_node("Estilo").modo = "tripo"
	mundo = (load("res://scripts/prototipo_3d/world_builder.gd") as Script).new()
	root.add_child(mundo)
	if not mundo.construido:
		await mundo.pronto
	for i in 4:
		await process_frame
	_juntar_obstaculos()
	for road in mundo._region._roads:
		ruas.append({"pontos": road.points, "meia": float(road.width) * 0.5})
	var quintal: Dictionary = QUINTAL.duplicate(true)
	_ler_bichos(quintal)
	var plano := {}
	var vez := 0
	var nomes: Array = []
	for nome in mundo._casas_autorais:
		nomes.append(String(nome))
	for nome: String in nomes:
		var chave := String(mundo._casas_autorais[nome].get("chave", ""))
		if not mundo._is_house_key(chave) or not mundo.ancoras.has(nome):
			continue
		var casa := _casa(nome)
		var pecas: Array = []
		if nome not in SEM_VARAL:
			var tipo: String = VARAIS[vez % VARAIS.size()]
			motivos.clear()
			vez += 1
			var varal := _varal(casa, tipo)
			if varal.is_empty():
				print("SEM_LUGAR: varal de ", nome, " ", motivos)
			else:
				pecas.append(varal)
				_ocupar(casa, varal, 1.0)
		for bicho in quintal.get(nome, []):
			for peca in _abrigo(casa, String(bicho)):
				pecas.append(peca)
				_ocupar(casa, peca, 0.9)
		if nome in CASAS_NOVAS:
			var pe := _pitangueira(casa)
			if not pe.is_empty():
				pecas.append(pe)
				_ocupar(casa, pe, 0.6)
		if not pecas.is_empty():
			plano[nome] = pecas
			print("PLANO: ", nome, " → ", ", ".join(pecas.map(func(p: Dictionary) -> String: return "%s %s (%.1f, %.1f)" % [p["id"], p["chave"], p["x"], p["z"]])))
	var arquivo := FileAccess.open(SAIDA, FileAccess.WRITE)
	arquivo.store_string(JSON.stringify({"observacao": "Escrito por tools/mapas/planejar_casas_moradores.gd; aplicado por aplicar_casas_moradores.py. Coordenadas no referencial da casa (porta no +Z).", "casas": plano}, "\t") + "\n")
	arquivo.close()
	print("PLANO_ESCRITO: %d casas" % plano.size())
	quit(0)


## As casas que ganham galinheiro e chiqueiro pelo que o pacote dos bichos pôs
## em cada uma: galinha (e galo, pinto, d'angola) pede galinheiro; porco e
## leitão, chiqueiro com cocho.
func _ler_bichos(quintal: Dictionary) -> void:
	if not FileAccess.file_exists("res://data/bichos_de_casa.json"):
		return
	var dados = JSON.parse_string(FileAccess.get_file_as_string("res://data/bichos_de_casa.json"))
	if not dados is Dictionary:
		return
	for item in (dados as Dictionary).get("casas", []):
		if not item is Dictionary:
			continue
		var casa := _da_composicao(String(item.get("casa", "")))
		if casa == "":
			continue
		var especies: Array = []
		for bicho in item.get("bichos", []):
			especies.append(String(bicho.get("especie", "")))
			for ave in bicho.get("aves", []):
				especies.append(String(ave.get("especie", "")))
		var tem: Array = quintal.get(casa, [])
		for especie in especies:
			var abrigo := ""
			if especie in ["galinha", "galo", "pintinho", "galinha_dangola", "peru"]:
				abrigo = "galinheiro"
			elif especie in ["porco", "leitao"]:
				abrigo = "chiqueiro"
			if abrigo != "" and not tem.has(abrigo):
				tem.append(abrigo)
		if not tem.is_empty():
			quintal[casa] = tem


## O nome da casa na composição para o nome que o JSON dos bichos usa: o mesmo, ou o
## da casa que está no mesmo lugar ("Casa da Zefa" é a "Casa do arraial 6").
func _da_composicao(nome: String) -> String:
	if mundo._casas_autorais.has(nome):
		return nome
	if not mundo.ancoras.has(nome):
		return ""
	for outro in mundo._casas_autorais:
		if mundo.ancoras.has(outro) and (mundo.ancoras[outro] as Vector3).distance_to(mundo.ancoras[nome]) < 0.5:
			return String(outro)
	return ""


## A casa no plano: origem, giro, meia caixa (com o beiral) e meio Terreiro.
func _casa(nome: String) -> Dictionary:
	var base: Vector3 = mundo.ancoras[nome]
	var frente: Vector3 = mundo.ancoras.get(nome + "Frente", Vector3.BACK)
	var giro := atan2(frente.x, frente.z)
	var meia := Vector2(3.25, 2.8)
	if mundo.construcoes.has(nome) and mundo.construcoes[nome].get("modelo") != null:
		var limites: AABB = (mundo.construcoes[nome]["modelo"] as Node3D).get_meta("limites", AABB())
		meia = Vector2(limites.size.x, limites.size.z) * 0.5
	if LARGURA_NOVA.has(nome):
		var largura: float = LARGURA_NOVA[nome]
		meia = Vector2(maxf(meia.x, largura * 0.5), maxf(meia.y, largura * 0.43))
	var terreiro := meia + Vector2(1.6, 1.6)
	var autoria: Dictionary = mundo._casas_autorais[nome]
	if autoria.has("terreiro"):
		var tamanho: Vector3 = autoria["terreiro"]["size"]
		terreiro = Vector2(tamanho.x, tamanho.z) * 0.5
	return {"nome": nome, "base": base, "giro": giro, "meia": meia, "terreiro": terreiro, "ocupado": []}


func _mundo(casa: Dictionary, local: Vector2) -> Vector3:
	var p: Vector3 = Vector3(local.x, 0.0, local.y).rotated(Vector3.UP, casa["giro"]) + casa["base"]
	return Vector3(p.x, mundo.ground_height_at(p), p.z)


## O VARAL: os candidatos dos dois lados e de trás, o melhor que passa na regra.
func _varal(casa: Dictionary, tipo: String) -> Dictionary:
	var meia: Vector2 = casa["meia"]
	var corda: float = CORDA[tipo]
	var melhor := {}
	var menor := INF
	for folga_parede in [2.0, 2.25, 2.5, 1.75, 2.75]:
		var e: float = folga_parede - BEIRAL
		var candidatos: Array = []
		for desliza in [0.0, -0.4, -0.8, 0.4, -1.2, 0.8]:
			# Lados: a corda corre no Z da casa; +Z do varal virado para a casa.
			candidatos.append([Vector2(meia.x + e, desliza), -PI / 2.0, 0.0])
			candidatos.append([Vector2(-meia.x - e, desliza), PI / 2.0, 0.0])
			# Fundos: a corda corre no X; um pouco mais caro, o quintal de trás
			# não se vê da rua.
			candidatos.append([Vector2(desliza * 1.5, -meia.y - e), 0.0, 0.15])
		for candidato in candidatos:
			var centro: Vector2 = candidato[0]
			var giro_local: float = candidato[1]
			var eixo := Vector2(cos(giro_local), -sin(giro_local))
			var pontos: Array[Vector2] = []
			for k in 7:
				pontos.append(centro + eixo * corda * (float(k) / 6.0 - 0.5))
			var nota: float = _nota_varal(casa, pontos)
			if not is_finite(nota):
				continue
			nota += float(candidato[2]) + absf(folga_parede - 2.25) * 0.4
			if nota < menor:
				menor = nota
				var chao: Vector3 = _mundo(casa, centro)
				melhor = {"id": "Varal", "tipo": "adereco", "chave": tipo, "x": snappedf(centro.x, 0.01),
					"y": snappedf(chao.y - (casa["base"] as Vector3).y, 0.01), "z": snappedf(centro.y, 0.01),
					"giro": snappedf(giro_local, 0.0001), "pontos": pontos}
		if not melhor.is_empty():
			break
	melhor.erase("pontos")
	return melhor


## Nota de um varal (menor é melhor); INF quando quebra a regra.
func _nota_varal(casa: Dictionary, pontos: Array[Vector2]) -> float:
	var alturas: Array[float] = []
	var fora_do_terreiro := 0.0
	var terreiro: Vector2 = casa["terreiro"]
	for local in pontos:
		# Longe do eixo da porta (a faixa à frente da casa).
		if local.y > 0.0 and absf(local.x) < 2.5:
			return _caiu("porta")
		var p: Vector3 = _mundo(casa, local)
		# Chão acima da lâmina (a profundidade da maré não vale no vale sem relógio).
		if not mundo.is_on_land(p) or p.y < float(mundo.water_level()) + 0.3:
			return _caiu("agua")
		if not _livre(p, 2.0, casa):
			return _caiu("ocupado")
		if _na_rua(p, 1.2):
			return _caiu("rua")
		alturas.append(p.y)
		fora_do_terreiro += maxf(absf(local.x) - terreiro.x, 0.0) + maxf(absf(local.y) - terreiro.y, 0.0)
	if alturas.max() - alturas.min() >= 0.4:
		return _caiu("desnivel")
	return fora_do_terreiro * 0.35 + (alturas.max() - alturas.min())


func _caiu(motivo: String) -> float:
	motivos[motivo] = int(motivos.get(motivo, 0)) + 1
	return INF


## GALINHEIRO e CHIQUEIRO (com o cocho ao lado): nos fundos, o chiqueiro o mais
## longe da praça que der.
func _abrigo(casa: Dictionary, abrigo: String) -> Array:
	var meia: Vector2 = casa["meia"]
	var raio: float = RAIO_DO_ABRIGO.get(abrigo, 1.7)
	var melhor: Array = []
	var menor := INF
	for e in [1.6, 2.2, 2.8, 3.4, 4.2]:
		for desliza in [-1.5, 1.5, 0.0, -2.5, 2.5]:
			for lado in ["fundos", "dir", "esq"]:
				var centro := Vector2(desliza, -meia.y - e - raio)
				var giro_local := 0.0
				if lado == "dir":
					centro = Vector2(meia.x + e + raio, -meia.y * 0.5 + desliza * 0.3)
					giro_local = -PI / 2.0
				elif lado == "esq":
					centro = Vector2(-meia.x - e - raio, -meia.y * 0.5 + desliza * 0.3)
					giro_local = PI / 2.0
				var p: Vector3 = _mundo(casa, centro)
				if not mundo.is_on_land(p) or not _livre(p, raio + 1.0, casa) or _na_rua(p, raio + 1.0):
					continue
				var alturas: Array[float] = []
				for canto in [Vector2(-raio, -raio), Vector2(raio, -raio), Vector2(raio, raio), Vector2(-raio, raio)]:
					alturas.append(_mundo(casa, centro + canto).y)
				if alturas.max() - alturas.min() > 0.6:
					continue
				var cocho := {}
				if abrigo == "chiqueiro":
					var eixo := Vector2(cos(giro_local), -sin(giro_local))
					var ponto_cocho := centro + eixo * (raio + 1.1)
					var pc: Vector3 = _mundo(casa, ponto_cocho)
					if not mundo.is_on_land(pc) or not _livre(pc, 1.4, casa) or _na_rua(pc, 1.0):
						continue
					cocho = {"id": "Cocho", "tipo": "adereco", "chave": "cocho", "x": snappedf(ponto_cocho.x, 0.01),
						"y": snappedf(pc.y - (casa["base"] as Vector3).y, 0.01), "z": snappedf(ponto_cocho.y, 0.01),
						"giro": snappedf(giro_local + PI / 2.0, 0.0001)}
				var nota: float = e * 0.3 + (alturas.max() - alturas.min())
				if abrigo == "chiqueiro":
					# Longe da praça (e da rua da frente).
					nota -= Vector2(p.x, p.z).length() * 0.01
				if nota < menor:
					menor = nota
					melhor = [{"id": abrigo.capitalize(), "tipo": "adereco", "chave": abrigo, "x": snappedf(centro.x, 0.01),
						"y": snappedf(p.y - (casa["base"] as Vector3).y, 0.01), "z": snappedf(centro.y, 0.01),
						"giro": snappedf(giro_local, 0.0001)}]
					if not cocho.is_empty():
						melhor.append(cocho)
	if melhor.is_empty():
		print("SEM_LUGAR: ", abrigo, " de ", casa["nome"])
	return melhor


## A PITANGUEIRA das casas novas: num canto dos fundos, cada casa num.
func _pitangueira(casa: Dictionary) -> Dictionary:
	var meia: Vector2 = casa["meia"]
	var semente := absi(hash(casa["nome"]))
	var cantos := [Vector2(1, -1), Vector2(-1, -1), Vector2(1, 0.2), Vector2(-1, 0.2)]
	for i in cantos.size():
		var canto: Vector2 = cantos[(i + semente) % cantos.size()]
		for e in [2.6, 3.2, 3.8]:
			var centro := Vector2(canto.x * (meia.x + e * 0.6), canto.y * (meia.y + e) if canto.y < 0.0 else canto.y)
			var p: Vector3 = _mundo(casa, centro)
			if mundo.is_on_land(p) and _livre(p, 2.4, casa) and not _na_rua(p, 2.0):
				return {"id": "Pitangueira", "tipo": "arvore", "chave": "pitangueira", "x": snappedf(centro.x, 0.01),
					"y": snappedf(p.y - (casa["base"] as Vector3).y, 0.01), "z": snappedf(centro.y, 0.01),
					"giro": snappedf(float(semente % 628) / 100.0, 0.0001)}
	print("SEM_LUGAR: pitangueira de ", casa["nome"])
	return {}


## O ponto está a `folga` de troncos, peças e casas (a própria casa conta pela
## caixa dela, com o beiral)?
func _livre(p: Vector3, folga: float, casa: Dictionary) -> bool:
	var plano := Vector2(p.x, p.z)
	for obstaculo in obstaculos:
		if obstaculo["tipo"] == "circulo":
			if plano.distance_to(obstaculo["centro"]) < folga + float(obstaculo["raio"]):
				_caiu("tronco/peca " + str(obstaculo["nome"]))
				return false
		else:
			var local: Vector2 = (plano - (obstaculo["centro"] as Vector2)).rotated(float(obstaculo["giro"]))
			var meia: Vector2 = obstaculo["meia"]
			var fora := Vector2(maxf(absf(local.x) - meia.x, 0.0), maxf(absf(local.y) - meia.y, 0.0))
			var minimo := 1.2 if obstaculo["nome"] == casa["nome"] else folga
			if fora.length() < minimo:
				_caiu("casa " + str(obstaculo["nome"]))
				return false
	for ocupado in casa["ocupado"]:
		if plano.distance_to(ocupado["centro"]) < float(ocupado["raio"]) + 0.6:
			return false
	return true


func _na_rua(p: Vector3, folga: float) -> bool:
	var plano := Vector2(p.x, p.z)
	for rua in ruas:
		var pontos: PackedVector2Array = rua["pontos"]
		for i in pontos.size() - 1:
			if plano.distance_to(Geometry2D.get_closest_point_to_segment(plano, pontos[i], pontos[i + 1])) < float(rua["meia"]) + folga:
				return true
	return false


## O que o plano já pôs nesta casa conta para a peça seguinte.
func _ocupar(casa: Dictionary, peca: Dictionary, raio: float) -> void:
	var p: Vector3 = _mundo(casa, Vector2(float(peca["x"]), float(peca["z"])))
	if String(peca["chave"]).begins_with("varal"):
		var eixo := Vector2(cos(float(peca["giro"])), -sin(float(peca["giro"])))
		for k in 5:
			var ponto := Vector2(float(peca["x"]), float(peca["z"])) + eixo * 4.0 * (float(k) / 4.0 - 0.5)
			var q: Vector3 = _mundo(casa, ponto)
			casa["ocupado"].append({"centro": Vector2(q.x, q.z), "raio": raio})
		return
	casa["ocupado"].append({"centro": Vector2(p.x, p.z), "raio": raio + (1.0 if peca["chave"] == "chiqueiro" else 0.0)})


## Troncos (toda colisão cilíndrica do vale), peças das casas e as caixas das
## construções. As luzes de parede não contam.
func _juntar_obstaculos() -> void:
	for forma in mundo.find_children("*", "CollisionShape3D", true, false):
		var cs := forma as CollisionShape3D
		if cs.shape is CylinderShape3D and not cs.disabled:
			var g := cs.global_position
			obstaculos.append({"tipo": "circulo", "centro": Vector2(g.x, g.z), "raio": (cs.shape as CylinderShape3D).radius, "nome": ""})
	for arvore in mundo._arvores_nomeadas:
		var pos: Vector3 = arvore["pos"]
		obstaculos.append({"tipo": "circulo", "centro": Vector2(pos.x, pos.z), "raio": maxf(float(arvore.get("raio", 0.3)), 0.3), "nome": ""})
	for nome in mundo._nomes_com_pecas():
		for item in mundo._pecas_da_casa(String(nome)):
			if String(item.get("tipo", "")) in ["candeeiro", "luz_janela", "lampiao"]:
				continue
			if String(item.get("chave", "")).begins_with("varal") and nome != "Casa de taipa":
				# O varal antigo do plano é o que se está replanejando.
				continue
			if String(item.get("chave", "")) in ["galinheiro", "chiqueiro", "cocho", "canoa_em_obra", "lavadouro_pedra"] or (String(item.get("chave", "")) == "pitangueira" and String(nome) in CASAS_NOVAS):
				continue
			var pos: Vector3 = item["pos"]
			obstaculos.append({"tipo": "circulo", "centro": Vector2(pos.x, pos.z), "raio": 0.6 if item["tipo"] == "arvore" else 0.5, "nome": String(nome)})
	for nome in mundo.construcoes:
		var dados: Dictionary = mundo.construcoes[nome]
		var modelo: Node3D = dados.get("modelo")
		if modelo == null:
			continue
		var limites: AABB = modelo.get_meta("limites", AABB())
		var meia := Vector2(limites.size.x, limites.size.z) * 0.5
		if LARGURA_NOVA.has(nome):
			var largura: float = LARGURA_NOVA[nome]
			meia = Vector2(maxf(meia.x, largura * 0.5), maxf(meia.y, largura * 0.43))
		var frente: Vector3 = mundo.ancoras.get(String(nome) + "Frente", Vector3.BACK)
		var centro: Vector3 = mundo.ancoras.get(String(nome), modelo.global_position)
		obstaculos.append({"tipo": "caixa", "centro": Vector2(centro.x, centro.z), "giro": atan2(frente.x, frente.z), "meia": meia, "nome": String(nome)})
