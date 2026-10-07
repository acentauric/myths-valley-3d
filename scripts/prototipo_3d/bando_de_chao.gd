extends Node3D
## UM BANDO DE AVES DE CHÃO num quintal: galinhas com o galo e os pintinhos,
## galinhas-d'angola, patos, o pavão com as pavoas no adro. Quem o cria é o
## `bichos_de_casa.gd`, por uma linha de `data/bichos_de_casa.json`.
##
## AVE NÃO TEM FÍSICA. Anda entre pontos já sorteados no terreiro — chão de
## andar, em terra, fora da caixa das casas (`AlvoCasa`), longe da água e dos
## troncos —, com a altura do chão do vale. Não barra ninguém e não faz a
## câmera saltar, e trinta aves não custam trinta corpos.
##
## O DIA DO BANDO:
##   - de dia CISCAM: o líder (o galo, a primeira d'angola, o pavão) anda de
##     ponto em ponto, e as outras vão para perto dele; parada, a ave bica. O
##     pintinho segue uma galinha, colado nela.
##   - quem chega perto demais, ou correndo, ESPANTA o bando: pulo estufado e
##     carreira para longe.
##   - ao entardecer SOBEM NO POLEIRO (a pitangueira do quintal, o ipê do adro),
##     com um voo curto do pé da árvore até o galho, e DESCEM ÀS CINCO. Sem
##     árvore, dormem juntas no chão.
##   - o PAVÃO ABRE O LEQUE quando o jogador para perto dele, ou de tempos em
##     tempos: troca para o GLB de cauda aberta (`leque` da espécie) e treme a
##     cauda um segundo.

const Animador = preload("res://scripts/prototipo_3d/animador_bicho.gd")

## Longe da câmera (u), as aves somem e o bando para de pensar.
const ALCANCE := 80.0
## Quantos pontos de terreiro se sorteiam.
const PONTOS := 28
## A que hora descem do poleiro.
const DESCE_AS := 5.0
## Espanta quem chega a menos disto, ou correndo a menos do outro.
const ESPANTA := 1.6
const ESPANTA_CORRENDO := 3.4
## O pavão abre o leque com o jogador parado a menos disto, ou a cada tanto.
const LEQUE_PERTO := 5.0
const LEQUE_PARADO := 1.0
const LEQUE_DURA := 7.0
const LEQUE_TREME := 1.0
const LEQUE_A_CADA := Vector2(120.0, 240.0)
## Alturas e raios do poleiro (u), por árvore: [altura mínima, máxima, raio mínimo, máximo].
const POLEIROS := {
	"pitangueira": [1.5, 2.1, 0.45, 0.85],
	"ipe": [2.6, 3.4, 0.8, 1.6],
	"arvore": [1.8, 2.6, 0.6, 1.2],
}
## Árvore que não serve de poleiro: palmeira e bananeira não têm galho.
const SEM_GALHO := ["coqueiro", "dendezeiro", "bananeira", "piacava", "mangue"]
const DURA_O_VOO := 0.8
const CHEGOU := 0.12

var dados: Dictionary = {}
var especies: Dictionary = {}
var casa: String = ""
var world
var jogador: Node3D
var perto := true
## As aves: {no, pose, animador, chave, papel, segue, alvo, espera, velocidade,
## poleiro, no_poleiro, voo, de, ate}.
var aves: Array[Dictionary] = []
var centro := Vector3.ZERO
var raio := 3.0
var pontos := PackedVector3Array()
## O pé da árvore do poleiro (INF sem árvore).
var arvore := Vector3.INF

var _rng := RandomNumberGenerator.new()
var _leque_ate := -1.0
var _proximo_leque := 0.0
var _jogador_parado := 0.0
var _tempo := 0.0
var _espantou := -10.0
var _longe_em := 0.0


func configurar(d: Dictionary, sp: Dictionary, nome_da_casa: String, mundo, alvo_jogador: Node3D) -> void:
	dados = d
	especies = sp
	casa = nome_da_casa
	world = mundo
	jogador = alvo_jogador
	name = "Bando" + casa.capitalize().replace(" ", "")


func _ready() -> void:
	add_to_group("bandos_de_chao")
	_rng.seed = hash(casa + str(dados.get("terreiro", [])))
	raio = float(dados.get("raio", 3.0))
	_achar_o_terreiro()
	_achar_o_poleiro()
	_proximo_leque = _rng.randf_range(LEQUE_A_CADA.x, LEQUE_A_CADA.y)
	for entrada: Dictionary in dados.get("aves", []):
		for i in int(entrada.get("quantos", 1)):
			_nova_ave(entrada)
	# Quem segue (o pintinho), segue uma das que ele pede, sorteada.
	for ave in aves:
		var quem := str(ave["entrada"].get("segue", ""))
		if quem == "":
			continue
		var maes: Array[int] = []
		for j in aves.size():
			if aves[j]["chave"] == quem:
				maes.append(j)
		if not maes.is_empty():
			ave["segue"] = maes[_rng.randi() % maes.size()]
	# No lugar de agora: de noite, já no galho.
	for ave in aves:
		if _hora_do_poleiro() and ave["poleiro"].is_finite():
			ave["no"].global_position = ave["poleiro"]
			ave["no_poleiro"] = true
			ave["animador"].abaixar(0.86)


# --- o lugar -----------------------------------------------------------------

func _na_casa(deslocamento: Vector3) -> Vector3:
	var base: Vector3 = world.ancoras.get(casa, Vector3.ZERO)
	var frente: Vector3 = world.ancoras.get(casa + "Frente", Vector3.BACK)
	return base + deslocamento.rotated(Vector3.UP, atan2(frente.x, frente.z))


## O TERREIRO: o ponto do JSON, e, se ele não der chão (água, casa, tronco), o
## mesmo ponto girado em volta da casa — um quarto de volta de cada vez.
func _achar_o_terreiro() -> void:
	var t: Array = dados.get("terreiro", [0, 0, -5])
	var local := Vector3(float(t[0]), float(t[1]), float(t[2]))
	for giro in 4:
		centro = world.ground_position(_na_casa(local.rotated(Vector3.UP, giro * PI * 0.5)), 0.0)
		pontos = _sortear_pontos()
		if pontos.size() >= 6:
			return


func _sortear_pontos() -> PackedVector3Array:
	var achados := PackedVector3Array()
	var troncos: Array[Dictionary] = []
	for a: Dictionary in world.arvores():
		if _plano(a["pos"] - centro).length() < raio + 3.0:
			troncos.append(a)
	for i in PONTOS * 3:
		if achados.size() >= PONTOS:
			break
		var p := centro + Vector3(_rng.randf_range(-raio, raio), 0.0, _rng.randf_range(-raio, raio))
		if _plano(p - centro).length() > raio or not ponto_de_ave(p, troncos):
			continue
		achados.append(world.ground_position(p, 0.0))
	return achados


## Chão de ave: em terra de andar, seco, fora das casas e dos troncos.
func ponto_de_ave(p: Vector3, troncos: Array[Dictionary] = []) -> bool:
	if not world.is_on_land(p) or not world.is_walkable_point(p) or na_agua(p):
		return false
	if dentro_de_casa(p):
		return false
	for a in troncos:
		if _plano(a["pos"] - p).length() < float(a.get("raio", 0.3)) + 0.45:
			return false
	return true


## Molhado: lâmina de mais de um palmo e o chão abaixo da água. A lâmina sozinha
## engana — na vila ela vale o desvio da maré, mesmo em terra seca.
func na_agua(p: Vector3) -> bool:
	var chao: Vector3 = world.ground_position(p, 0.0)
	return world.water_depth_at(chao) > 0.12 and chao.y < world.water_level_at(chao) + 0.05


func dentro_de_casa(p: Vector3, folga: float = 0.4) -> bool:
	return Animador.dentro_de_casa(get_tree(), p, folga)


## O POLEIRO: a árvore pedida mais perto do terreiro.
func _achar_o_poleiro() -> void:
	var tipo := str(dados.get("poleiro", ""))
	if tipo == "":
		return
	var menor := 14.0 if tipo == "pitangueira" else 20.0
	for a: Dictionary in world.arvores():
		var sp := str(a.get("especie", ""))
		var serve := false
		match tipo:
			"pitangueira":
				serve = sp.begins_with("pitangueira")
			"ipe":
				serve = sp.begins_with("ipe")
			_:
				serve = sp != "" and not sp.get_slice("_", 0) in SEM_GALHO
		if not serve:
			continue
		var d := _plano(a["pos"] - centro).length()
		if d < menor:
			menor = d
			arvore = a["pos"]


func _poleiro_da_ave(i: int, n: int) -> Vector3:
	if not arvore.is_finite():
		return Vector3.INF
	var faixa: Array = POLEIROS.get(str(dados.get("poleiro", "")), POLEIROS["arvore"])
	var giro := TAU * (float(i) + _rng.randf_range(-0.2, 0.2)) / maxf(1.0, float(n))
	var r := _rng.randf_range(float(faixa[2]), float(faixa[3]))
	var y := _rng.randf_range(float(faixa[0]), float(faixa[1]))
	var onde := arvore
	# O galho não entra na parede: a árvore pode estar colada na casa, e então a
	# ave gira em volta do tronco até achar um lado livre.
	for tentativa in 10:
		onde = arvore + Vector3(cos(giro) * r, y, sin(giro) * r)
		if not dentro_de_casa(onde, 0.25):
			break
		giro += 0.7
	return onde


## Hora de estar no poleiro: do entardecer às cinco da manhã.
func _hora_do_poleiro() -> bool:
	var periodo: String = Dia.periodo()
	return periodo in ["entardecer", "noite"] or (periodo == "madrugada" and Dia.hora < DESCE_AS) \
		or (Dia.hora >= 18.0)


# --- as aves -----------------------------------------------------------------

func _nova_ave(entrada: Dictionary) -> void:
	var chave := str(entrada.get("especie", "galinha"))
	var sp: Dictionary = especies.get(chave, {})
	var no := Node3D.new()
	no.name = chave.capitalize().replace(" ", "") + str(aves.size())
	add_child(no)
	var pose := Node3D.new()
	pose.name = "Pose"
	no.add_child(pose)
	var c: Array = sp.get("caixa", [0.2, 0.4, 0.4])
	var tamanho := _rng.randf_range(0.92, 1.08)
	var modelo := Animador.vestir(chave, pose, Vector3(float(c[0]), float(c[1]), float(c[2])),
		Color(str(sp.get("cor", "999999"))), ALCANCE, tamanho)
	var animador = Animador.new()
	animador.name = "Animador"
	no.add_child(animador)
	animador.configurar(pose, modelo, true, chave, float(sp.get("passo", 0.6)))
	var inicio: Vector3 = pontos[_rng.randi() % pontos.size()] if not pontos.is_empty() else centro
	no.global_position = inicio
	no.rotation.y = _rng.randf() * TAU
	var papel := "lider" if bool(entrada.get("lider", false)) else "bando"
	var ave := {"no": no, "pose": pose, "modelo": modelo, "animador": animador, "chave": chave,
		"especie": sp, "entrada": entrada, "papel": papel, "segue": -1, "alvo": inicio,
		"espera": _rng.randf_range(0.5, 4.0), "velocidade": float(sp.get("passo", 0.6)),
		"poleiro": Vector3.INF, "no_poleiro": false, "voo": -1.0, "de": inicio, "ate": inicio,
		"leque": null}
	aves.append(ave)
	var total := 0
	for e: Dictionary in dados.get("aves", []):
		total += int(e.get("quantos", 1))
	ave["poleiro"] = _poleiro_da_ave(aves.size() - 1, total)


func lider() -> Dictionary:
	for ave in aves:
		if ave["papel"] == "lider":
			return ave
	return aves[0] if not aves.is_empty() else {}


func _process(delta: float) -> void:
	if world == null or aves.is_empty():
		return
	_tempo += delta
	var empoleirar := _hora_do_poleiro()
	if not perto:
		# Longe da vista: está onde estaria, e não se anima. Quatro conferências
		# por segundo bastam: ninguém vê a ave subir no galho daqui.
		_longe_em -= delta
		if _longe_em > 0.0:
			return
		_longe_em = 0.25
		for ave in aves:
			if empoleirar and ave["poleiro"].is_finite():
				ave["no"].global_position = ave["poleiro"]
				ave["no_poleiro"] = true
			elif ave["no_poleiro"]:
				ave["no"].global_position = ave["alvo"]
				ave["no_poleiro"] = false
			ave["voo"] = -1.0
		return
	_conferir_o_leque(delta)
	var espanto := _espanto()
	for i in aves.size():
		var ave: Dictionary = aves[i]
		if ave["voo"] >= 0.0:
			_voar(ave, delta)
			continue
		if empoleirar:
			_ir_dormir(ave, i)
		elif ave["no_poleiro"]:
			# Cinco da manhã: desce do galho para o pé da árvore.
			_comecar_o_voo(ave, _chao_perto(arvore, 1.2), false)
			continue
		else:
			_ciscar(ave, i, delta, espanto)
		_andar(ave, delta)


func _ir_dormir(ave: Dictionary, i: int) -> void:
	ave["animador"].abaixar(0.86)
	if ave["no_poleiro"]:
		ave["alvo"] = ave["no"].global_position
		return
	if not ave["poleiro"].is_finite():
		# Sem árvore: dormem juntas no chão, no meio do terreiro.
		ave["velocidade"] = float(ave["especie"].get("passo", 0.6))
		if not ave.has("cama"):
			ave["cama"] = world.ground_position(centro + Vector3(cos(i * 2.4) * 0.35 * sqrt(i), 0.0, sin(i * 2.4) * 0.35 * sqrt(i)), 0.0)
		ave["alvo"] = ave["cama"]
		return
	var pe: Vector3 = Vector3(ave["poleiro"].x, arvore.y, ave["poleiro"].z)
	var chao := _chao_perto(pe, 0.0)
	ave["velocidade"] = float(ave["especie"].get("passo", 0.6)) * 1.3
	ave["alvo"] = chao
	if _plano(chao - ave["no"].global_position).length() <= CHEGOU * 3.0:
		_comecar_o_voo(ave, ave["poleiro"], true)


func _chao_perto(p: Vector3, espalha: float) -> Vector3:
	# Quem desce do galho não pousa na parede: o pé da árvore pode estar colado na casa.
	var q := p
	for i in 8:
		q = p + Vector3(_rng.randf_range(-espalha, espalha), 0.0, _rng.randf_range(-espalha, espalha))
		if espalha <= 0.0 or not dentro_de_casa(q, 0.3):
			break
	return world.ground_position(q, 0.0)


func _comecar_o_voo(ave: Dictionary, ate: Vector3, subindo: bool) -> void:
	ave["voo"] = 0.0
	ave["de"] = ave["no"].global_position
	ave["ate"] = ate
	ave["subindo"] = subindo
	ave["animador"].velocidade = 0.0
	ave["animador"].assustar()


func _voar(ave: Dictionary, delta: float) -> void:
	ave["voo"] += delta / DURA_O_VOO
	var t: float = minf(1.0, ave["voo"])
	var de: Vector3 = ave["de"]
	var ate: Vector3 = ave["ate"]
	var no: Node3D = ave["no"]
	no.global_position = de.lerp(ate, t) + Vector3.UP * sin(t * PI) * 0.6
	var rumo := _plano(ate - de)
	if rumo.length() > 0.05:
		no.rotation.y = atan2(rumo.x, rumo.z)
	if t >= 1.0:
		ave["voo"] = -1.0
		ave["no_poleiro"] = bool(ave.get("subindo", false))
		ave["alvo"] = ate
		if not ave["no_poleiro"]:
			ave["animador"].abaixar(1.0)
			ave["espera"] = _rng.randf_range(0.5, 2.0)


## Quem espanta o bando agora: o ponto do jogador, ou INF.
func _espanto() -> Vector3:
	if jogador == null:
		return Vector3.INF
	var v = jogador.get("velocity")
	var rapido: bool = v is Vector3 and _plano(v).length() > 3.0
	var d := _plano(jogador.global_position - centro).length()
	if d > raio + ESPANTA_CORRENDO + 1.0:
		return Vector3.INF
	for ave in aves:
		var da_ave := _plano(jogador.global_position - ave["no"].global_position).length()
		if da_ave < ESPANTA or (rapido and da_ave < ESPANTA_CORRENDO):
			return jogador.global_position
	return Vector3.INF


func _ciscar(ave: Dictionary, i: int, delta: float, espanto: Vector3) -> void:
	var no: Node3D = ave["no"]
	var animador = ave["animador"]
	animador.abaixar(1.0)
	var sp: Dictionary = ave["especie"]
	if ave.get("leque") != null and _leque_ate > _tempo:
		# De leque aberto, o pavão fica parado, de frente para quem o olha.
		ave["alvo"] = no.global_position
		if jogador != null:
			_virar(no, jogador.global_position)
		return
	if espanto.is_finite() and _plano(espanto - no.global_position).length() < ESPANTA_CORRENDO + 0.5:
		# ESPANTOU: pulo estufado e carreira para o lado oposto.
		if _tempo - float(ave.get("espantou", -10.0)) > 1.2:
			ave["espantou"] = _tempo
			animador.assustar()
			var fuga := _plano(no.global_position - espanto).normalized()
			if fuga == Vector3.ZERO:
				fuga = Vector3.RIGHT.rotated(Vector3.UP, i)
			ave["alvo"] = _ponto_mais_perto(no.global_position + fuga * 2.4)
			ave["velocidade"] = float(sp.get("corrida", 2.0))
		return
	ave["espera"] = float(ave["espera"]) - delta
	var chegou := _plano(ave["alvo"] - no.global_position).length() <= CHEGOU
	if not chegou:
		return
	# Parada: bica o chão de vez em quando.
	if not animador.bicando() and _rng.randf() < delta * 0.8:
		animador.bicar()
	if float(ave["espera"]) > 0.0:
		return
	ave["espera"] = _rng.randf_range(1.5, 5.0)
	ave["velocidade"] = float(sp.get("passo", 0.6))
	if int(ave["segue"]) >= 0:
		# O pintinho vai para perto da mãe, colado nela.
		var mae: Node3D = aves[int(ave["segue"])]["no"]
		ave["alvo"] = _ponto_mais_perto(mae.global_position + Vector3(_rng.randf_range(-0.5, 0.5), 0.0, _rng.randf_range(-0.5, 0.5)))
		ave["espera"] = _rng.randf_range(0.3, 1.2)
		ave["velocidade"] = float(sp.get("corrida", 1.2))
	elif ave["papel"] == "lider" or lider().is_empty():
		ave["alvo"] = pontos[_rng.randi() % pontos.size()] if not pontos.is_empty() else centro
	else:
		var galo: Node3D = lider()["no"]
		ave["alvo"] = _ponto_mais_perto(galo.global_position + Vector3(_rng.randf_range(-2.2, 2.2), 0.0, _rng.randf_range(-2.2, 2.2)))


## O ponto do terreiro mais perto de `p` (ave não sai do terreiro).
func _ponto_mais_perto(p: Vector3) -> Vector3:
	var melhor := centro
	var menor := INF
	for q in pontos:
		var d := _plano(q - p).length()
		if d < menor:
			menor = d
			melhor = q
	if menor < 0.6 or pontos.is_empty():
		return melhor
	# Entre o ponto pedido e o mais perto, se o caminho for chão de ave.
	var meio := melhor.lerp(p, 0.5)
	return world.ground_position(meio, 0.0) if ponto_de_ave(meio) else melhor


func _andar(ave: Dictionary, delta: float) -> void:
	var no: Node3D = ave["no"]
	var falta := _plano(ave["alvo"] - no.global_position)
	var animador = ave["animador"]
	if falta.length() <= CHEGOU or ave["no_poleiro"]:
		animador.velocidade = 0.0
		return
	var passo := minf(falta.length(), float(ave["velocidade"]) * delta)
	var novo: Vector3 = no.global_position + falta.normalized() * passo
	if dentro_de_casa(novo, 0.1):
		# Bateu na parede: volta para um ponto do terreiro.
		ave["alvo"] = pontos[_rng.randi() % pontos.size()] if not pontos.is_empty() else centro
		animador.velocidade = 0.0
		return
	novo.y = world.ground_height_at(novo)
	no.global_position = novo
	no.rotation.y = lerp_angle(no.rotation.y, atan2(falta.x, falta.z), minf(1.0, delta * 10.0))
	# O último passo pode ser menor que a velocidade pedida: o ritmo acompanha
	# o trajeto realmente percorrido, sem acelerar a chegada ao ponto de ciscar.
	animador.velocidade = passo / maxf(delta, 0.0001)


func _virar(no: Node3D, ponto: Vector3) -> void:
	var para := _plano(ponto - no.global_position)
	if para.length() > 0.05:
		no.rotation.y = lerp_angle(no.rotation.y, atan2(para.x, para.z), 0.1)


# --- o leque -----------------------------------------------------------------

func _conferir_o_leque(delta: float) -> void:
	var pavao := _o_pavao()
	if pavao.is_empty():
		return
	if _leque_ate > 0.0 and _tempo >= _leque_ate:
		fechar_leque()
	if jogador == null or _hora_do_poleiro():
		return
	var v = jogador.get("velocity")
	var parado: bool = not (v is Vector3) or _plano(v).length() < 0.2
	var d := _plano(jogador.global_position - pavao["no"].global_position).length()
	_jogador_parado = _jogador_parado + delta if parado and d < LEQUE_PERTO else 0.0
	if not leque_aberto() and (_jogador_parado >= LEQUE_PARADO or _tempo >= _proximo_leque):
		abrir_leque()


func _o_pavao() -> Dictionary:
	for ave in aves:
		if bool(ave["entrada"].get("leque", false)):
			return ave
	return {}


func leque_aberto() -> bool:
	return _leque_ate > _tempo


## ABRE O LEQUE: o GLB de cauda aberta no lugar do de cauda fechada, e a cauda
## tremendo o primeiro segundo. Sem o GLB do leque (ainda não chegou), só treme.
func abrir_leque() -> void:
	var pavao := _o_pavao()
	if pavao.is_empty() or pavao["no_poleiro"] or pavao["voo"] >= 0.0:
		return
	_leque_ate = _tempo + LEQUE_DURA
	_proximo_leque = _tempo + _rng.randf_range(LEQUE_A_CADA.x, LEQUE_A_CADA.y)
	_jogador_parado = -LEQUE_DURA * 2.0
	pavao["leque"] = true
	pavao["alvo"] = pavao["no"].global_position
	pavao["animador"].tremer(LEQUE_TREME)
	var chave_leque := str(pavao["especie"].get("leque", ""))
	var procedural: bool = Estilo.procedural()
	if chave_leque != "" and (procedural or CatalogoAssets.tem_tripo(chave_leque)):
		if not pavao.has("modelo_leque"):
			var c: Array = pavao["especie"].get("caixa", [0.3, 1.1, 1.5])
			# Na caixa do procedural, o leque é a cauda em pé atrás do corpo.
			var leque := Animador.vestir(chave_leque, pavao["pose"],
				Vector3(float(c[2]) * 1.1, float(c[1]) * 1.3, float(c[0])), Color(str(pavao["especie"].get("cor", "2a5a8a"))), ALCANCE)
			if procedural:
				leque.position.z = -float(c[2]) * 0.35
				pavao["modelo"].visible = true
			pavao["modelo_leque"] = leque
		pavao["modelo_leque"].visible = true
		if not procedural:
			pavao["modelo"].visible = false


func fechar_leque() -> void:
	_leque_ate = -1.0
	var pavao := _o_pavao()
	if pavao.is_empty():
		return
	pavao["leque"] = null
	if pavao.has("modelo_leque"):
		pavao["modelo_leque"].visible = false
	pavao["modelo"].visible = true


static func _plano(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
