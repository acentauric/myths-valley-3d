extends Node3D
## A FAUNA D'ÁGUA DO VALE: põe os cardumes (cardume.gd) nos lugares e os comanda.
##
## Onde mora cada um:
##   - em cada canoa fundeada, tainhas rodando o casco e uma bola de sardinhas ao
##     lado; no dia do saveiro, outra bola junto dele;
##   - dois pares de xaréus patrulhando entre as canoas, que de tempos em tempos
##     atacam uma bola de sardinha (a água ferve e a bola perde uma ou duas);
##   - nas pedras do raso, sargentinhos e budiões (e um baiacu) em volta da rocha;
##   - nos poços do rio — junto das pontes e debaixo dos ingazeiros e mangues —
##     piabas, acarás e uma traíra parada na margem, vistos como sombra na água doce;
##   - no mar de fora, perto do tubarão, um cardume de cavalas e um de sororocas, que
##     são as presas dele (grupo `presas_do_tubarao`);
##   - bandos de raia-pintada a meia água e raias deitadas na areia do raso.
##
## A cada quadro de física junta os perigos (o jogador — de longe se nada, quase em
## cima se está no píer ou na canoa —, os moradores, os predadores e os xaréus) e
## distribui aos cardumes. Nível de detalhe pela distância à câmera: perto, todo
## quadro; a meia distância, a cada três; longe, parado e escondido.
##
## Nunca é filho do nó Canoas: tests/canoas.gd trata todo filho dele como canoa.

const Cardume = preload("res://scripts/prototipo_3d/cardume.gd")

## Alcance do susto (u): quem nada, quem está fora d'água, o predador e o xaréu.
const PERIGO_NADANDO := 3.0
const PERIGO_FORA := 1.2
const PERIGO_PREDADOR := 4.5
const PERIGO_XAREU := 2.5
## Nível de detalhe, em fração do alcance de visão do cardume: até aqui todo quadro;
## além, a cada três quadros; passando do alcance mais esta folga, dorme.
const PERTO := 0.65
const FOLGA_DE_SONO := 20.0
## A tainha que salta perto do jogador e o ataque do xaréu (intervalos em s).
const SALTO_TAINHA := Vector2(15.0, 40.0)
const ALCANCE_SALTO := 25.0
const ATAQUE_XAREU := Vector2(40.0, 90.0)
const ALCANCE_ATAQUE := 80.0
const DURACAO_ATAQUE := 15.0
## As raias e o mar de fora: lâminas (u) e quantos.
const LAMINA_PINTADAS := Vector2(0.65, 1.0)
const LAMINA_MANTEIGAS := Vector2(0.25, 0.6)
const LAMINA_MAR_DE_FORA := 1.2

## Os cardumes comandados (cardume.gd), inclusive o do píer.
var cardumes: Array = []
var _world: Node3D
var _player: Node3D
var _tubarao: Node3D
var _saveiro: Node
var _atraso: Dictionary = {}
var _quadro := 0
var _tempo := 0.0
var _proximo_salto := 0.0
var _proxima_olhada_saveiro := 0.0
## Os xaréus: {cardume, proximo, alvo, ate}.
var _xareus: Array[Dictionary] = []
var _bolas: Array = []
var _bola_do_saveiro = null
var _tripo := true
var _rng := RandomNumberGenerator.new()
var _perigos: Array = []


func _init(world: Node3D = null, player: Node3D = null, tubarao: Node3D = null, saveiro: Node = null) -> void:
	name = "FaunaVale"
	_world = world
	_player = player
	_tubarao = tubarao
	_saveiro = saveiro


func _ready() -> void:
	if _world == null:
		return
	if not bool(_world.get("construido")):
		await _world.pronto
	_montar()


func _montar() -> void:
	if not _world.has_method("water_level") or not is_finite(float(_world.water_level())):
		return
	_tripo = Estilo.tripo()
	_rng.seed = 1887
	_adotar_o_do_pier()
	_nas_canoas()
	_xareus_entre_as_canoas()
	_nas_pedras()
	_nos_rios()
	_no_mar_de_fora()
	_raias()
	_proximo_salto = _rng.randf_range(SALTO_TAINHA.x, SALTO_TAINHA.y)


func _novo(nome: String, especie: String, ancora: Vector3, opcoes: Dictionary):
	var cardume := Cardume.new()
	cardume.name = nome
	cardume.coordenado = true
	add_child(cardume)
	opcoes["tripo"] = _tripo
	opcoes["mundo"] = _world
	cardume.montar_especie(especie, ancora, opcoes)
	cardumes.append(cardume)
	_atraso[cardume] = 0.0
	return cardume


## O cardume antigo do píer (world_builder._build_cardume) passa ao comando daqui.
func _adotar_o_do_pier() -> void:
	for no in _world.find_children("Cardume*", "Node3D", false, false):
		if no.has_method("atualizar"):
			no.coordenado = true
			cardumes.append(no)
			_atraso[no] = 0.0


func _nivel() -> float:
	return float(_world.water_level())


func _lamina(ponto: Vector3) -> float:
	return float(_world.water_depth_at(ponto))


func _no_mar(ponto: Vector3) -> bool:
	return not _world.is_on_land(ponto)


# --- canoas e saveiro ----------------------------------------------------------

func _canoas() -> Array[Node3D]:
	var lista: Array[Node3D] = []
	var frota := _world.get_node_or_null("Canoas")
	if frota != null:
		for canoa in frota.get_children():
			if canoa is Node3D:
				lista.append(canoa)
	return lista


func _nas_canoas() -> void:
	var k := 0
	for canoa in _canoas():
		k += 1
		var p := canoa.global_position
		var ancora := Vector3(p.x, _nivel(), p.z)
		var r := RandomNumberGenerator.new()
		r.seed = Cardume.semente_do_lugar(ancora, "canoa")
		_novo("Cardume Tainhas %d" % k, "tainha", ancora, {"modo": "roda", "quantidade": r.randi_range(8, 10),
			"raio": r.randf_range(2.2, 3.2), "prof": Vector2(0.1, 0.3), "lamina_some": 0.15})
		var bola := _bola_ao_lado(canoa, 3.2)
		if bola.is_finite():
			_bolas.append(_novo("Cardume Sardinhas %d" % k, "sardinha", bola, {"modo": "bola", "quantidade": r.randi_range(16, 24),
				"raio": 0.85, "prof": Vector2(0.12, 0.3), "lamina_some": 0.2}))


## O ponto mais fundo a `distancia` do barco, entre oito direções.
func _bola_ao_lado(barco: Node3D, distancia: float) -> Vector3:
	var p := barco.global_position
	var melhor := Vector3.INF
	var maior := 0.32
	for k in 8:
		var ang := TAU * float(k) / 8.0
		var ponto := Vector3(p.x + cos(ang) * distancia, _nivel(), p.z + sin(ang) * distancia)
		var lamina := _lamina(ponto)
		if lamina > maior and _no_mar(ponto):
			maior = lamina
			melhor = ponto
	return melhor


## O saveiro só existe no dia dele: a bola nasce quando o barco aparece e dorme
## quando ele vai embora.
func _olhar_o_saveiro() -> void:
	if _saveiro == null or not is_instance_valid(_saveiro):
		return
	var barco = _saveiro.get("barco")
	if not barco is Node3D:
		return
	var atracado: bool = (barco as Node3D).is_visible_in_tree()
	if _bola_do_saveiro == null and atracado:
		var ponto := _bola_ao_lado(barco, 4.0)
		if ponto.is_finite():
			_bola_do_saveiro = _novo("Cardume Sardinhas do Saveiro", "sardinha", ponto, {"modo": "bola", "quantidade": 20,
				"raio": 0.9, "prof": Vector2(0.12, 0.3), "lamina_some": 0.2})
			_bolas.append(_bola_do_saveiro)
	if _bola_do_saveiro != null:
		_bola_do_saveiro.dormindo = not atracado
		if not atracado:
			_bola_do_saveiro.visible = false


## Dois pares de xaréus rodando entre as canoas, cada par num sentido.
func _xareus_entre_as_canoas() -> void:
	var canoas := _canoas()
	if canoas.size() < 2:
		return
	var meio := Vector3.ZERO
	for canoa in canoas:
		meio += canoa.global_position
	meio /= float(canoas.size())
	canoas.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return atan2(a.global_position.z - meio.z, a.global_position.x - meio.x) < atan2(b.global_position.z - meio.z, b.global_position.x - meio.x))
	# A rota passa entre uma canoa e a seguinte, no fundo que der.
	var rota := PackedVector3Array()
	for k in canoas.size():
		var a := canoas[k].global_position
		var b := canoas[(k + 1) % canoas.size()].global_position
		var entre := (a + b) * 0.5
		entre.y = _nivel()
		if _lamina(entre) >= 0.3 and _no_mar(entre):
			rota.append(entre)
		var junto := Vector3(a.x, _nivel(), a.z) + (meio - a).normalized() * 4.0
		junto.y = _nivel()
		if _lamina(junto) >= 0.3 and _no_mar(junto):
			rota.append(junto)
	if rota.size() < 3:
		return
	for par in 2:
		var minha := PackedVector3Array()
		for k in rota.size():
			# O segundo par corre a rota ao contrário, começando do outro lado.
			var indice := (k + rota.size() / 2) % rota.size() if par == 1 else k
			minha.append(rota[rota.size() - 1 - indice] if par == 1 else rota[indice])
		var xareu = _novo("Cardume Xareus %d" % (par + 1), "xareu", minha[0], {"modo": "cruzeiro", "quantidade": 2,
			"raio": 1.2, "prof": Vector2(0.15, 0.32), "rota": minha, "lamina_some": 0.2})
		_xareus.append({"cardume": xareu, "proximo": _rng.randf_range(20.0, 40.0) + 15.0 * par, "alvo": null, "ate": 0.0})


func _ataques_dos_xareus() -> void:
	for x in _xareus:
		var xareu = x["cardume"]
		if not is_instance_valid(xareu):
			continue
		var alvo = x["alvo"]
		if alvo == null:
			if _tempo < float(x["proximo"]):
				continue
			alvo = _bola_mais_perto(xareu.centro_atual())
			if alvo == null:
				x["proximo"] = _tempo + 10.0
				continue
			x["alvo"] = alvo
			x["ate"] = _tempo + DURACAO_ATAQUE
		var onde: Vector3 = alvo.centro_atual()
		xareu.cacar(onde)
		var xareu_em: Vector3 = xareu.centro_atual()
		var perto := Vector2(onde.x - xareu_em.x, onde.z - xareu_em.z).length() < 1.5
		if perto:
			alvo.ferver()
		if perto or _tempo > float(x["ate"]):
			xareu.cacar(Vector3.INF)
			x["alvo"] = null
			x["proximo"] = _tempo + _rng.randf_range(ATAQUE_XAREU.x, ATAQUE_XAREU.y)


func _bola_mais_perto(ponto: Vector3):
	var melhor = null
	var menor := ALCANCE_ATAQUE
	for bola in _bolas:
		if not is_instance_valid(bola) or bola.dormindo or not bola.visible:
			continue
		var bola_em: Vector3 = bola.centro_atual()
		var d := Vector2(bola_em.x - ponto.x, bola_em.z - ponto.z).length()
		if d < menor:
			menor = d
			melhor = bola
	return melhor


# --- pedras -------------------------------------------------------------------

## As pedras do raso: as lajes da maré e as pedras da praia montadas pelo mundo
## (pela composição, quando existe; senão pelos nós do catálogo); sem nenhuma, a
## batimetria em volta do marco "Pedras".
func _pedras() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	var avulsos = _world.get("avulsos_montados")
	if avulsos is Dictionary:
		for id in avulsos:
			var item = avulsos[id]
			if not item is Dictionary or not bool(item.get("visivel", true)):
				continue
			if String(item.get("chave", "")) in ["pedra_mare", "pedras_praia"] or String(id).begins_with("Pedra da"):
				var tamanho := float(item.get("tamanho", 1.0))
				var raio := (1.3 if String(item.get("chave", "")) == "pedra_mare" else 3.0) * tamanho
				lista.append({"pos": item["pos"], "raio": raio})
	if lista.is_empty():
		for padrao in ["*Pedra Mare*", "*Pedras Praia*"]:
			for no in _world.find_children(padrao, "Node3D", true, false):
				var caixa := _caixa_global(no)
				if caixa.size != Vector3.ZERO:
					lista.append({"pos": caixa.get_center(), "raio": maxf(caixa.size.x, caixa.size.z) * 0.4})
	if lista.is_empty():
		var ancoras = _world.get("ancoras")
		if ancoras is Dictionary and ancoras.has("Pedras"):
			var marco: Vector3 = ancoras["Pedras"]
			for k in 24:
				var ang := TAU * float(k) / 24.0
				for d in [12.0, 20.0, 30.0, 40.0]:
					var ponto := marco + Vector3(cos(ang), 0.0, sin(ang)) * float(d)
					var lamina := _lamina(ponto)
					if lamina >= 0.35 and lamina <= 0.9 and _no_mar(ponto):
						var longe := true
						for outra in lista:
							if (outra["pos"] as Vector3).distance_to(ponto) < 12.0:
								longe = false
						if longe and lista.size() < 2:
							lista.append({"pos": ponto, "raio": 0.8})
						break
	return lista


func _caixa_global(no: Node3D) -> AABB:
	var caixa := AABB()
	var tem := false
	for malha in no.find_children("*", "MeshInstance3D", true, false):
		var mi := malha as MeshInstance3D
		var parte := mi.global_transform * mi.get_aabb()
		caixa = caixa.merge(parte) if tem else parte
		tem = true
	return caixa


func _nas_pedras() -> void:
	var k := 0
	for pedra in _pedras():
		if k >= 4:
			break
		var centro: Vector3 = pedra["pos"]
		var raio_pedra: float = clampf(float(pedra["raio"]), 0.6, 3.0)
		# O lado de água da pedra: o ponto mais fundo de um anel de oito.
		var fundo := 0.0
		for a in 8:
			var ang := TAU * float(a) / 8.0
			var ponto := centro + Vector3(cos(ang), 0.0, sin(ang)) * (raio_pedra + 1.2)
			var lamina := _lamina(ponto)
			if lamina >= 0.35 and lamina <= 1.2 and _no_mar(ponto):
				fundo = maxf(fundo, lamina)
		if fundo <= 0.0:
			continue
		k += 1
		var ancora := Vector3(centro.x, _nivel(), centro.z)
		var base := {"modo": "pedra", "pedra": ancora, "raio_pedra": raio_pedra, "lamina_some": 0.0}
		var miudos := base.duplicate()
		miudos.merge({"quantidade": 8, "raio": 1.4, "prof": Vector2(0.08, 0.3)})
		_novo("Cardume Sargentinhos %d" % k, "sargentinho", ancora, miudos)
		var budioes := base.duplicate()
		budioes.merge({"quantidade": 2, "raio": 2.4, "prof": Vector2(0.15, 0.4)})
		_novo("Cardume Budioes %d" % k, "budiao", ancora, budioes)
		var baiacu := base.duplicate()
		baiacu.merge({"quantidade": 1, "raio": 1.2, "prof": Vector2(0.1, 0.3)})
		_novo("Cardume Baiacu %d" % k, "baiacu", ancora, baiacu)
		if k == 1 and fundo >= 0.6:
			var garoupa := base.duplicate()
			garoupa.merge({"quantidade": 1, "raio": 1.0, "prof": Vector2(0.3, 0.5)})
			_novo("Cardume Garoupa", "garoupa", ancora, garoupa)


# --- rios ---------------------------------------------------------------------

## Poços do rio: junto das pontes (um pouco correnteza acima, longe do tabuado) e
## debaixo de ingazeiros e mangues da beira.
func _nos_rios() -> void:
	var regiao = _world.get("_region")
	if regiao == null:
		return
	var rios = regiao.get("_rivers")
	if not rios is Array or (rios as Array).is_empty():
		return
	var candidatos: Array[Dictionary] = []
	var ancoras = _world.get("ancoras")
	if ancoras is Dictionary:
		for nome in ["Ponte", "Ponte do rio central"]:
			if ancoras.has(nome):
				candidatos.append({"ponto": ancoras[nome], "folga": 25.0, "afasta": 5.0})
	var por_rio: Dictionary = {}
	if _world.has_method("arvores"):
		for arvore: Dictionary in _world.arvores():
			if String(arvore.get("especie", "")) in ["ingazeiro", "mangue"]:
				candidatos.append({"ponto": arvore["pos"], "folga": 4.0, "afasta": 0.0})
	var pocos: Array[Vector3] = []
	var k := 0
	for candidato in candidatos:
		if pocos.size() >= 6:
			break
		var achado := _ponto_no_rio(rios, candidato["ponto"], float(candidato["folga"]))
		if achado.is_empty():
			continue
		var rio: Dictionary = achado["rio"]
		var nome_rio := String(rio.get("name", ""))
		if float(candidato["afasta"]) == 0.0 and int(por_rio.get(nome_rio, 0)) >= 2:
			continue
		var acima: Vector3 = achado["acima"]
		var poco := _poco_com_agua(achado["ponto"], acima, float(candidato["afasta"]))
		if not poco.is_finite():
			continue
		var longe := true
		for outro in pocos:
			if Vector2(outro.x - poco.x, outro.z - poco.z).length() < 20.0:
				longe = false
				break
		if not longe:
			continue
		pocos.append(poco)
		if float(candidato["afasta"]) == 0.0:
			por_rio[nome_rio] = int(por_rio.get(nome_rio, 0)) + 1
		k += 1
		var largura := float(rio.get("width", 2.0))
		var base := {"modo": "rio", "doce": true, "rio_dir": acima, "rio_largura": largura, "lamina_some": 0.05, "alcance": 50.0}
		var piabas := base.duplicate()
		piabas.merge({"quantidade": 8, "raio": 1.6, "prof": Vector2(0.03, 0.09)})
		_novo("Cardume Piabas %d" % k, "piaba", poco, piabas)
		var acaras := base.duplicate()
		acaras.merge({"quantidade": 3, "raio": 1.2, "prof": Vector2(0.06, 0.12)})
		_novo("Cardume Acaras %d" % k, "acara", poco, acaras)
		var traira := base.duplicate()
		traira.merge({"quantidade": 1, "raio": 0.5, "prof": Vector2(0.08, 0.12)})
		_novo("Cardume Traira %d" % k, "traira", poco, traira)


## O ponto da linha do rio mais perto de `ponto` (a até `folga` da margem), e o rumo
## correnteza acima: do ponto i para o i+1, porque o primeiro ponto é a foz.
func _ponto_no_rio(rios: Array, ponto: Vector3, folga: float) -> Dictionary:
	var aqui := Vector2(ponto.x, ponto.z)
	var melhor := {}
	var menor := INF
	for rio: Dictionary in rios:
		var pontos: PackedVector2Array = rio.get("points", PackedVector2Array())
		var largura := float(rio.get("width", 2.0))
		for i in range(pontos.size() - 1):
			var q := Geometry2D.get_closest_point_to_segment(aqui, pontos[i], pontos[i + 1])
			var d := q.distance_to(aqui)
			if d < menor and d <= largura * 0.5 + folga:
				var dir := (pontos[i + 1] - pontos[i]).normalized()
				menor = d
				melhor = {"rio": rio, "ponto": Vector3(q.x, 0.0, q.y), "acima": Vector3(dir.x, 0.0, dir.y)}
	return melhor


## Anda pela calha até achar água doce que cabe peixe (lâmina de 0,1 u ou mais).
func _poco_com_agua(ponto: Vector3, acima: Vector3, afasta: float) -> Vector3:
	var regiao = _world.get("_region")
	for passo in [afasta, afasta + 3.0, afasta - 3.0, afasta + 6.0, afasta - 6.0, afasta + 9.0]:
		var tentativa: Vector3 = ponto + acima * float(passo)
		var nivel := float(regiao.river_water_level_at(tentativa))
		if is_finite(nivel) and float(regiao.river_water_depth_at(tentativa)) >= 0.1:
			return Vector3(tentativa.x, nivel, tentativa.z)
	return Vector3.INF


# --- mar de fora e raias --------------------------------------------------------

## Um cardume de cavalas e um de sororocas rodando no fundo perto do tubarão.
func _no_mar_de_fora() -> void:
	if _tubarao == null or not bool(_tubarao.get("_ativo")):
		return
	var base: Vector3 = _tubarao.get("_centro")
	var feitos: Array[Vector3] = []
	for especie in ["cavala", "sororoca"]:
		var lugar := _roda_no_fundo(base, Vector2(15.0, 30.0), [16.0, 13.0, 10.0], LAMINA_MAR_DE_FORA, feitos, 14.0)
		if lugar.is_empty():
			continue
		var centro: Vector3 = lugar["centro"]
		feitos.append(centro)
		var quantos := _rng.randi_range(6, 8) if especie == "cavala" else 8
		_novo("Cardume %s do mar de fora" % especie.capitalize(), especie, centro, {"modo": "cruzeiro", "quantidade": quantos,
			"raio": float(lugar["raio"]), "prof": Vector2(0.35, 0.6), "presa": true, "lamina_some": 0.9, "alcance": 120.0})


## Um círculo de `raios[i]` todo com lâmina >= `lamina`, com centro a uma distância
## da faixa de `base`, longe dos já feitos. Devolve {centro, raio} ou {}.
func _roda_no_fundo(base: Vector3, distancia: Vector2, raios: Array, lamina: float, feitos: Array[Vector3], afastamento: float) -> Dictionary:
	for raio in raios:
		for k in 16:
			var ang := TAU * float(k) / 16.0 + 0.3
			var d := distancia.x
			while d <= distancia.y:
				var centro := base + Vector3(cos(ang), 0.0, sin(ang)) * d
				centro.y = _nivel()
				var livre := true
				for outro in feitos:
					if outro.distance_to(centro) < afastamento:
						livre = false
						break
				if livre and _circulo_fundo(centro, float(raio), lamina):
					return {"centro": centro, "raio": float(raio)}
				d += 5.0
	return {}


func _circulo_fundo(centro: Vector3, raio: float, lamina: float, tolera: int = 0) -> bool:
	var rasos := 0
	if _lamina(centro) < lamina:
		return false
	for k in 12:
		var ang := TAU * float(k) / 12.0
		var ponto := centro + Vector3(cos(ang), 0.0, sin(ang)) * raio
		if _lamina(ponto) < lamina or not _no_mar(ponto):
			rasos += 1
			if rasos > tolera:
				return false
	return true


## Os bandos de raia-pintada entre as canoas e o fundo, e as raias deitadas no raso.
func _raias() -> void:
	var ancoras = _world.get("ancoras")
	if not ancoras is Dictionary or not ancoras.has("PierPiso"):
		return
	var pier: Vector3 = ancoras["PierPiso"]
	var mar: Vector3 = ancoras.get("PierDirecao", Vector3.FORWARD)
	mar.y = 0.0
	mar = mar.normalized() if mar.length_squared() > 0.001 else Vector3.FORWARD
	var feitos: Array[Vector3] = []
	var bandos := 0
	for graus in [0.0, 30.0, -30.0, 55.0, -55.0, 80.0, -80.0]:
		if bandos >= 2:
			break
		var direcao := mar.rotated(Vector3.UP, deg_to_rad(graus))
		for d in range(25, 200, 5):
			var ponto := pier + direcao * float(d)
			ponto.y = _nivel()
			var lamina := _lamina(ponto)
			if lamina < LAMINA_PINTADAS.x or lamina > LAMINA_PINTADAS.y:
				continue
			var longe := true
			for outro in feitos:
				if outro.distance_to(ponto) < 25.0:
					longe = false
			if not longe:
				break
			var raio := 10.0
			while raio >= 6.0 and not _circulo_fundo(ponto, raio, 0.55, 2):
				raio -= 2.0
			if raio < 6.0:
				continue
			feitos.append(ponto)
			bandos += 1
			_novo("Cardume Raias Pintadas %d" % bandos, "raia_pintada", ponto, {"modo": "voo", "quantidade": _rng.randi_range(5, 7),
				"raio": raio, "prof": Vector2(0.3, 0.42), "lamina_some": 0.45})
			break
	# As raias de areia: num canto do raso, longe do caminho do píer.
	for graus in [40.0, -40.0, 70.0, -70.0]:
		var direcao := mar.rotated(Vector3.UP, deg_to_rad(graus))
		for d in range(12, 120, 4):
			var ponto := pier + direcao * float(d)
			ponto.y = _nivel()
			var lamina := _lamina(ponto)
			if lamina >= 0.3 and lamina <= 0.5 and _no_mar(ponto):
				_novo("Cardume Raias de Areia", "raia", ponto, {"modo": "fundo", "quantidade": _rng.randi_range(4, 6),
					"raio": 6.0, "prof": LAMINA_MANTEIGAS, "lamina_some": 0.2, "alcance": 120.0})
				return


# --- o comando de cada quadro ----------------------------------------------------

## Alcance do susto que `no` causa: quem nada espanta de longe; quem está fora
## d'água (no píer, na canoa, na beira), só quase em cima.
func raio_de_perigo(no: Node) -> float:
	if no != null and no.has_method("is_swimming") and no.is_swimming():
		return PERIGO_NADANDO
	return PERIGO_FORA


func _juntar_perigos() -> Array:
	var lista: Array = []
	if _player != null and is_instance_valid(_player):
		lista.append({"pos": _player.global_position, "raio": raio_de_perigo(_player), "no": _player})
	for no in get_tree().get_nodes_in_group("moradores"):
		if no is Node3D and (no as Node3D).is_visible_in_tree():
			lista.append({"pos": (no as Node3D).global_position, "raio": raio_de_perigo(no), "no": no})
	for no in get_tree().get_nodes_in_group("predadores"):
		if no is Node3D and (no as Node3D).visible:
			lista.append({"pos": (no as Node3D).global_position, "raio": PERIGO_PREDADOR, "no": no})
	for x in _xareus:
		var xareu = x["cardume"]
		if is_instance_valid(xareu) and xareu.visible:
			lista.append({"pos": xareu.centro_atual(), "raio": PERIGO_XAREU, "no": xareu, "so_para": ["sardinha", "tainha"]})
	return lista


func _olho() -> Vector3:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera != null:
		return camera.global_position
	if _player != null:
		return _player.global_position
	return Vector3.ZERO


func _physics_process(delta: float) -> void:
	if cardumes.is_empty():
		return
	_tempo += delta
	_quadro += 1
	if _tempo >= _proxima_olhada_saveiro:
		_proxima_olhada_saveiro = _tempo + 1.0
		_olhar_o_saveiro()
	_perigos = _juntar_perigos()
	_ataques_dos_xareus()
	var olho := _olho()
	for k in cardumes.size():
		var cardume = cardumes[k]
		if not is_instance_valid(cardume) or cardume.dormindo:
			continue
		var onde: Vector3 = cardume.centro_atual()
		var d := Vector2(onde.x - olho.x, onde.z - olho.z).length()
		var alcance := float(cardume.alcance_visivel)
		if d > alcance + FOLGA_DE_SONO:
			# Longe: parado e escondido (o MultiMesh nem chega à placa de vídeo).
			if cardume.visible:
				cardume.visible = false
			_atraso[cardume] = 0.0
			continue
		if not cardume.visible:
			cardume.visible = true
		_atraso[cardume] = float(_atraso.get(cardume, 0.0)) + delta
		var passo := 1 if d < alcance * PERTO else 3
		if (_quadro + k) % passo != 0:
			continue
		cardume.perigos = _perigos
		cardume.atualizar(float(_atraso[cardume]))
		_atraso[cardume] = 0.0
	_saltos()


## De 15 a 40 s, uma tainha perto do jogador salta.
func _saltos() -> void:
	if _tempo < _proximo_salto or _player == null:
		return
	_proximo_salto = _tempo + _rng.randf_range(SALTO_TAINHA.x, SALTO_TAINHA.y)
	var melhor = null
	var menor := ALCANCE_SALTO
	for cardume in cardumes:
		if not is_instance_valid(cardume) or cardume.especie != "tainha" or not cardume.visible:
			continue
		var d: float = cardume.centro_atual().distance_to(_player.global_position)
		if d < menor:
			menor = d
			melhor = cardume
	if melhor != null:
		melhor.saltar()
