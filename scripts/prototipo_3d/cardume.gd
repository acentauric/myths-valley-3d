extends Node3D
## Cardume do vale: os peixes de um lugar, todos num MultiMesh só — as tainhas que
## rodam a canoa, a bola de sardinhas, os sargentinhos da pedra, as piabas do poço
## do rio, as cavalas do mar de fora, o bando de raias. O nado é desenhado no shader
## (assets/prototipo_3d/fauna/), e aqui fica só o rumo de cada peixe.
##
## O cardume antigo do píer ainda nasce por `montar` (world_builder._build_cardume)
## e é de tainhas. Os outros nascem por `montar_especie`, chamados pelo FaunaVale
## (fauna_vale.gd), que também junta os perigos e decide quem atualiza a cada quadro.
##
## Modos ("modo" nas opções):
##   roda     — em volta do centro, puxados de volta quando se afastam (as tainhas);
##   bola     — sardinhas apertadas e rápidas; diante de perigo a bola inteira foge
##              e se encolhe;
##   pedra    — cada peixe tem a vaga dele em volta da rocha e, com perigo, se
##              esconde atrás dela, do lado oposto, mais fundo;
##   rio      — de cara para a correnteza, com arrancadas; fogem rio abaixo e voltam;
##   cruzeiro — o centro anda por uma rota e os peixes seguem em formação;
##   voo      — raias numa fila escalonada, batendo as asas fora de compasso;
##   fundo    — raia deitada na areia, que dispara quando alguém chega perto.
##
## Profundidade pelo leito LOCAL: cada peixe consulta a lâmina onde está (mais
## amiúde quando corre) e nunca passa abaixo do leito; onde não cabe peixe (o raso
## da praia, a terra), ele some e volta para o centro. Quem está fora d'água só
## espanta a menos de 1,2 u; quem nada, e o predador, de longe.

const Mar = preload("res://scripts/prototipo_3d/mar.gd")
const Especies = preload("res://scripts/prototipo_3d/fauna/especies_do_mar.gd")
const NADO := preload("res://assets/prototipo_3d/fauna/nado.gdshader")
const RAIA_VOO := preload("res://assets/prototipo_3d/fauna/raia_voo.gdshader")
const SILHUETA := preload("res://assets/prototipo_3d/fauna/silhueta_rio.gdshader")

## O cardume antigo do píer: quantos, raio da roda e meia água (unidades).
const QUANTIDADE := 14
const RAIO := 4.5
const MEIA_AGUA := 0.45
## Força máxima do puxão de volta ao centro: longe demais não vira estilingue.
const VOLTA_MAXIMA := 1.2
## Perigo quase em cima: a direção de fuga fica travada por um tempo para não saltar.
const PERTO_DEMAIS := 0.5
const TRAVA_FUGA := 0.8
## Só atualiza o rumo acima desta velocidade (u/s), senão o peixe roda no lugar.
const RUMO_MINIMO := 0.1
## Alcance do susto: quem nada (e o predador) e quem está fora d'água (no píer, na
## canoa, na beira) — esse só espanta quase em cima.
const DISTANCIA_FUGA := 3.0
const DISTANCIA_FUGA_FORA := 1.2
## O peixe fica pelo menos isto acima do leito, e um dedo abaixo da superfície.
const FOLGA_LEITO := 0.05
const FOLGA_SUPERFICIE := 0.03
## A cada quanto (s) o peixe parado relê o leito; correndo, mais amiúde.
const CONSULTA_LEITO := 0.5
## Passo máximo de uma atualização (s): o cardume que dormiu longe não dá um salto.
const PASSO_MAXIMO := 0.1

var especie := "tainha"
var modo := "roda"
## Lista de perigos do quadro, posta pelo FaunaVale: {pos, raio, no, so_para?}.
var perigos: Array = []
## Com o FaunaVale no comando, o cardume não se atualiza sozinho.
var coordenado := false
## Escondido de propósito (a bola do saveiro com o barco fora): nem anda nem aparece.
var dormindo := false
var agua_doce := false
## Até onde o cardume se vê (visibility_range_end) e o FaunaVale o atualiza.
var alcance_visivel := 70.0
## Quantos peixes já foram comidos (pelo tubarão ou pelo xaréu).
var comidos := 0

var _mundo: Node
var _esp: Dictionary = {}
var _n := 0
## Âncora do cardume, no nível da água (a pesca lê `_centro`).
var _centro := Vector3.ZERO
## Centro que anda (bola, cruzeiro, voo) e a velocidade/rumo dele.
var _nucleo := Vector3.ZERO
var _nucleo_vel := Vector3.ZERO
var _nucleo_dir := Vector3.FORWARD
var _raio := RAIO
## Faixa de profundidade abaixo da superfície (no fundo: a lâmina das vagas).
var _prof := Vector2(0.1, MEIA_AGUA)
var _lamina_some := 0.3
var _sentido := 1.0
var _vel_cruzeiro := 0.9
var _vel_fuga := 2.2
var _rota := PackedVector3Array()
var _rota_i := 0
var _rio_dir := Vector3.FORWARD
var _rio_largura := 2.0
var _pedra := Vector3.ZERO
var _raio_pedra := 1.2
var _aperto := 1.0
var _alvo_caca := Vector3.INF
var _ameaca := Vector3.INF
var _proximo_salto := 0.0
var _tempo := 0.0
var _rng := RandomNumberGenerator.new()

## Um valor por peixe.
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _rumo := PackedFloat32Array()
var _inclina := PackedFloat32Array()
var _fase := PackedFloat32Array()
var _escala := PackedFloat32Array()
## A vaga do peixe no cardume: ângulo/raio na roda, na bola e na pedra; deslocamento
## no rio e na formação; o ponto na areia, na raia de fundo.
var _vaga := PackedVector3Array()
var _fundura := PackedFloat32Array()
var _fuga_dir := PackedVector3Array()
var _fuga_ate := PackedFloat32Array()
var _sup := PackedFloat32Array()
var _leito := PackedFloat32Array()
var _consulta := PackedFloat32Array()
var _vivo := PackedByteArray()
var _volta := PackedFloat32Array()
var _salto := PackedFloat32Array()
var _evento := PackedFloat32Array()
var _arranca := PackedFloat32Array()
var _susto := PackedFloat32Array()
var _escondido := PackedByteArray()

var _mm: MultiMeshInstance3D
## Peixe canônico (cabeça no -Z, centrado) → espaço da malha, e o inverso no shader.
var _canonica := Transform3D.IDENTITY
var _altura_meia := 0.05
var _escala_base := 1.0
var _duracao_salto := 0.7
var _buffer := PackedFloat32Array()

## Corpos já montados, por espécie, estilo e shader: o mesmo material para todos
## os cardumes da espécie.
static var _corpos: Dictionary = {}

## O RELÓGIO DO NADO, em segundos de JOGO, que os três shaders de peixe leem no lugar do
## TIME do motor: o TIME não pausa, e com o vale pausado os peixes e as raias
## seguiam batendo cauda e asa no lugar. Quem avança o relógio é o `_process` de
## qualquer cardume — o primeiro de cada quadro —, e nó processado pela árvore para de
## ser chamado quando ela pausa.
static var _relogio_do_nado := 0.0
static var _quadro_do_relogio := -1
## O que o relógio dá a volta em (s): o TIME do motor também dá, e a fase do rabear
## não se perde com a precisão do float.
const VOLTA_DO_RELOGIO := 3600.0


## O cardume antigo do píer: `ancora` no nível da água; `fundo` é a lâmina d'água ali.
func montar(ancora: Vector3, nivel: float, fundo: float, tripo: bool) -> void:
	montar_especie("tainha", Vector3(ancora.x, nivel, ancora.z), {"modo": "roda", "quantidade": QUANTIDADE,
		"raio": RAIO, "prof": Vector2(0.08, clampf(fundo * 0.7, 0.1, MEIA_AGUA)), "tripo": tripo})


## Cardume de `nome` (especies_do_mar.gd) em `ancora`, no nível da água. Opções:
## modo, quantidade, raio, prof (Vector2 abaixo da superfície), tripo, mundo, semente,
## lamina_some, doce, rio_dir, rio_largura, pedra, raio_pedra, rota, presa, alcance, pressa.
func montar_especie(nome: String, ancora: Vector3, opcoes: Dictionary = {}) -> void:
	especie = nome
	_esp = Especies.especie(nome)
	modo = String(opcoes.get("modo", "roda"))
	_mundo = opcoes.get("mundo", null)
	if _mundo == null and is_inside_tree():
		_mundo = get_tree().get_first_node_in_group("mundo")
	_centro = ancora
	_nucleo = ancora
	_raio = float(opcoes.get("raio", 4.0))
	_prof = opcoes.get("prof", Vector2(0.1, 0.4))
	agua_doce = bool(opcoes.get("doce", false))
	_lamina_some = float(opcoes.get("lamina_some", 0.05 if agua_doce else 0.3))
	_rio_dir = opcoes.get("rio_dir", Vector3.FORWARD)
	_rio_largura = float(opcoes.get("rio_largura", 2.0))
	_pedra = opcoes.get("pedra", ancora)
	_raio_pedra = float(opcoes.get("raio_pedra", 1.2))
	_rota = opcoes.get("rota", PackedVector3Array())
	_n = int(opcoes.get("quantidade", 10))
	var raia := String(_esp["forma"]) == "raia"
	alcance_visivel = float(opcoes.get("alcance", 160.0 if raia else 70.0))
	_vel_cruzeiro = float(_esp["velocidade"]) * float(opcoes.get("pressa", 1.0))
	_vel_fuga = float(_esp["fuga"])
	_rng.seed = int(opcoes.get("semente", semente_do_lugar(ancora, nome)))
	_sentido = 1.0 if _rng.randf() < 0.5 else -1.0
	if modo in ["cruzeiro", "voo"] and _rota.is_empty():
		# Sem rota dada, um círculo em volta do centro, no sentido do cardume.
		for k in 12:
			var ang := TAU * float(k) / 12.0 * _sentido
			_rota.append(ancora + Vector3(cos(ang), 0.0, sin(ang)) * _raio)
	if not _rota.is_empty():
		_nucleo = _rota[0]
		_rota_i = 1 % _rota.size()
	add_to_group("cardumes")
	if bool(opcoes.get("presa", false)):
		add_to_group("presas_do_tubarao")
	_montar_visual(bool(opcoes.get("tripo", Estilo.tripo())))
	for i in _n:
		_pos.append(Vector3.ZERO)
		_vel.append(Vector3.ZERO)
		_rumo.append(0.0)
		_inclina.append(0.0)
		_fase.append(_rng.randf())
		var variacao := float(_esp["variacao"])
		_escala.append(1.0 + _rng.randf_range(-variacao, variacao))
		_vaga.append(Vector3.ZERO)
		_fundura.append(_rng.randf())
		_fuga_dir.append(Vector3.ZERO)
		_fuga_ate.append(0.0)
		_sup.append(ancora.y)
		_leito.append(ancora.y - 1.0)
		_consulta.append(0.0)
		_vivo.append(1)
		_volta.append(0.0)
		_salto.append(0.0)
		_evento.append(_rng.randf_range(2.0, 9.0))
		_arranca.append(0.0)
		_susto.append(0.0)
		_escondido.append(0)
		_nascer(i)
	_proximo_salto = _rng.randf_range(6.0, 16.0)
	atualizar(0.0)


## A semente do cardume vem do lugar onde ele nasce: dois cardumes da mesma espécie
## não repetem o desenho, e o mesmo lugar dá o mesmo cardume a cada partida.
static func semente_do_lugar(ponto: Vector3, nome: String) -> int:
	return hash(Vector3i(roundi(ponto.x * 4.0), roundi(ponto.y * 4.0), roundi(ponto.z * 4.0))) ^ hash(nome)


## Âncora do cardume (onde a pesca lê o "no cardume").
func centro() -> Vector3:
	return _centro


## Onde o cardume está agora: o centro que anda, nos modos que andam.
func centro_atual() -> Vector3:
	return _nucleo if modo in ["bola", "cruzeiro", "voo"] else _centro


func quantidade() -> int:
	return _n


func vivo(i: int) -> bool:
	return i >= 0 and i < _n and _vivo[i] == 1 and _escondido[i] == 0


func posicao(i: int) -> Vector3:
	return _pos[i]


func leito(i: int) -> float:
	return _leito[i]


## Rumo de cada peixe (yaw, cabeça no -Z girada) e velocidade: para conferir que
## nada para a frente.
func rumo(i: int) -> float:
	return _rumo[i]


func velocidade(i: int) -> Vector3:
	return _vel[i]


func _process(delta: float) -> void:
	avancar_o_relogio(delta)


## Avança o relógio do nado e o põe em todo material de peixe, uma vez por quadro.
static func avancar_o_relogio(delta: float) -> void:
	var quadro := Engine.get_process_frames()
	if quadro == _quadro_do_relogio:
		return
	_quadro_do_relogio = quadro
	_relogio_do_nado = fposmod(_relogio_do_nado + delta, VOLTA_DO_RELOGIO)
	for corpo: Dictionary in _corpos.values():
		var material := corpo.get("material") as ShaderMaterial
		if material != null:
			material.set_shader_parameter("tempo", _relogio_do_nado)


func _physics_process(delta: float) -> void:
	if coordenado or _n == 0:
		return
	# Sozinho (o cardume do píer antes do FaunaVale): junta os perigos ele mesmo.
	perigos.clear()
	for no in get_tree().get_nodes_in_group("map_player"):
		if no is Node3D:
			var nadando: bool = no.has_method("is_swimming") and no.is_swimming()
			perigos.append({"pos": (no as Node3D).global_position, "raio": DISTANCIA_FUGA if nadando else DISTANCIA_FUGA_FORA, "no": no})
	for no in get_tree().get_nodes_in_group("moradores"):
		if no is Node3D:
			perigos.append({"pos": (no as Node3D).global_position, "raio": DISTANCIA_FUGA_FORA, "no": no})
	atualizar(delta)


# --- o nado -------------------------------------------------------------------

## Um passo do cardume inteiro. O FaunaVale chama com o tempo acumulado desde a
## última vez (o cardume de longe anda a cada três quadros).
func atualizar(delta: float) -> void:
	if _n == 0:
		return
	delta = minf(delta, PASSO_MAXIMO)
	_tempo += delta
	var superficie := _superficie_do_mar()
	# Baixa-mar: sem lâmina no centro, o cardume some no fundo até a água voltar.
	if _lamina_em(centro_atual()) < _lamina_some:
		if _mm != null:
			_mm.visible = false
		return
	if _mm != null:
		_mm.visible = true
	var proximos := _perigos_perto()
	_atualizar_nucleo(delta, proximos)
	if modo == "rio" and especie == "piaba" and _tempo >= _proximo_salto:
		_proximo_salto = _tempo + _rng.randf_range(8.0, 20.0)
		saltar()
	for i in _n:
		if _vivo[i] == 0:
			if _tempo < _volta[i]:
				continue
			_renascer(i)
		if _tempo >= _consulta[i]:
			_consultar(i, superficie)
			_consulta[i] = _tempo + CONSULTA_LEITO / maxf(1.0, _vel[i].length() * 1.5)
		_mover(i, delta, proximos)
	_escrever()


func _mover(i: int, delta: float, proximos: Array) -> void:
	var p := _pos[i]
	var antes_y := p.y
	# Perigo mais próximo dentro do alcance dele (o mais perto manda na direção).
	var mais_perto := INF
	var afasta := Vector3.ZERO
	for perigo: Dictionary in proximos:
		var pp: Vector3 = perigo["pos"]
		var longe := Vector3(p.x - pp.x, 0.0, p.z - pp.z)
		var d := longe.length()
		if d < float(perigo["raio"]) and d < mais_perto:
			mais_perto = d
			afasta = longe
	var fugindo := mais_perto < INF
	if fugindo:
		var direcao := _fuga_dir[i]
		if _tempo >= _fuga_ate[i] or modo != "rio":
			# Recalcula fora da trava; com o perigo quase em cima, guarda a direção
			# por um tempo em vez de inverter a cada quadro (o rumo saltava).
			if _tempo >= _fuga_ate[i] or direcao == Vector3.ZERO:
				if afasta.length_squared() > 0.000001:
					direcao = afasta / mais_perto
				elif direcao == Vector3.ZERO:
					direcao = Vector3(cos(_fase[i] * TAU), 0.0, sin(_fase[i] * TAU))
				_fuga_dir[i] = direcao
			if mais_perto < PERTO_DEMAIS:
				_fuga_ate[i] = maxf(_fuga_ate[i], _tempo + TRAVA_FUGA)
		if modo in ["rio", "fundo"]:
			# Rio e raia de fundo: a disparada dura um tempo mesmo sem o perigo.
			_fuga_ate[i] = maxf(_fuga_ate[i], _tempo + _rng.randf_range(1.4, 2.4))
	var em_fuga := fugindo or (modo in ["rio", "fundo"] and _tempo < _fuga_ate[i])
	_susto[i] = move_toward(_susto[i], 1.0 if em_fuga else 0.0, delta * 2.0)
	var desejada := _desejo(i, p, em_fuga)
	if _escondido[i] == 1:
		# Saiu da água que cabe peixe: volta para o centro do cardume.
		var volta := centro_atual() - p
		volta.y = 0.0
		if volta.length_squared() > 0.0001:
			desejada = volta.normalized() * _vel_cruzeiro * 1.5
	var agil := 6.0 if em_fuga else (3.0 if modo == "bola" else 1.5)
	var vel := _vel[i].lerp(desejada, 1.0 - exp(-agil * delta))
	vel.y = 0.0
	# Teto absoluto: fuga somada a qualquer outra força nunca passa disso.
	vel = vel.limit_length(_vel_fuga)
	_vel[i] = vel
	p += vel * delta
	if _salto[i] > 0.0:
		p.y = _altura_do_salto(i, delta)
		_escondido[i] = 0
	else:
		var piso := _leito[i] + FOLGA_LEITO + _altura_meia * _escala[i]
		var teto := _sup[i] - FOLGA_SUPERFICIE - _altura_meia * _escala[i]
		var alvo_y := _altura_alvo(i, piso, em_fuga)
		p.y = lerpf(p.y, alvo_y, 1.0 - exp(-3.0 * delta))
		if piso > teto:
			# Raso demais para este peixe: some (e no próximo passo volta ao centro).
			_escondido[i] = 1
			p.y = teto
		else:
			_escondido[i] = 0
			p.y = clampf(p.y, piso, teto)
	_pos[i] = p
	var horizontal := Vector2(_vel[i].x, _vel[i].z)
	var rumo_alvo := _rumo[i]
	if horizontal.length_squared() > RUMO_MINIMO * RUMO_MINIMO:
		rumo_alvo = atan2(-horizontal.x, -horizontal.y)
	if modo == "rio" and not em_fuga and _tempo >= _arranca[i]:
		# Parado no poço, de cara para a correnteza.
		rumo_alvo = atan2(-_rio_dir.x, -_rio_dir.z)
	# Rumo suavizado com lerp_angle: sem os saltos do atan2, o peixe não gira no lugar.
	# Na bola, que vira o tempo todo em volta do núcleo, a proa acompanha mais depressa.
	var giro_do_rumo := 8.0 if (em_fuga or modo == "bola") else 4.0
	_rumo[i] = lerp_angle(_rumo[i], rumo_alvo, 1.0 - exp(-giro_do_rumo * delta))
	if _salto[i] <= 0.0 and delta > 0.0:
		var sobe := (p.y - antes_y) / delta
		_inclina[i] = lerpf(_inclina[i], clampf(atan2(sobe, maxf(horizontal.length(), 0.2)), -0.5, 0.5), 1.0 - exp(-4.0 * delta))


## A velocidade que o peixe quer, no plano, conforme o modo do cardume.
func _desejo(i: int, p: Vector3, em_fuga: bool) -> Vector3:
	var f := _fase[i] * TAU
	var vc := _vel_cruzeiro
	match modo:
		"bola":
			if em_fuga and _fuga_dir[i] != Vector3.ZERO and _pos[i].distance_to(_nucleo) < _raio * 3.0:
				# Quem está quase em cima do perigo dispara sozinho; a bola foge junto.
				return _fuga_dir[i] * _vel_fuga + _nucleo_vel * 0.5
			var ang := _vaga[i].x + _tempo * (vc / maxf(_vaga[i].y, 0.25)) * _sentido
			var alvo := _nucleo + Vector3(cos(ang), 0.0, sin(ang)) * _vaga[i].y * _aperto
			var para := alvo - p
			para.y = 0.0
			return (para * 3.0 + _nucleo_vel).limit_length(_vel_fuga)
		"pedra":
			var ang := _vaga[i].x + sin(_tempo * 0.12 + f) * 0.6
			var r := _vaga[i].y + sin(_tempo * 0.3 + f) * 0.25
			var alvo := _pedra + Vector3(cos(ang), 0.0, sin(ang)) * r
			var limite := vc
			if _ameaca.is_finite():
				# Esconde-se atrás da rocha, do lado oposto ao perigo.
				var atras := Vector3(_pedra.x - _ameaca.x, 0.0, _pedra.z - _ameaca.z)
				if atras.length_squared() < 0.0001:
					atras = Vector3(cos(f), 0.0, sin(f))
				atras = atras.normalized()
				var lado := Vector3(-atras.z, 0.0, atras.x)
				var escondido := _pedra + atras * (_raio_pedra + 0.25 + (_vaga[i].y - _raio_pedra) * 0.3) + lado * sin(f * 3.0) * _raio_pedra * 0.5
				if _lamina_em(escondido) >= _prof.x + 0.08:
					alvo = escondido
					limite = _vel_fuga
				elif em_fuga:
					return _fuga_dir[i] * _vel_fuga
			var para := alvo - p
			para.y = 0.0
			return (para * 1.5 + Vector3(sin(_tempo * 0.8 + f), 0.0, cos(_tempo * 0.6 + f)) * vc * 0.3).limit_length(limite)
		"rio":
			var lado := Vector3(-_rio_dir.z, 0.0, _rio_dir.x)
			if em_fuga:
				# Rio abaixo, abrindo para o lado de onde não vem o perigo.
				var lateral := lado * signf(_fuga_dir[i].dot(lado) + 0.001)
				return (-_rio_dir * 0.8 + lateral * 0.45).normalized() * _vel_fuga
			if _tempo >= _evento[i]:
				# Arrancada curta correnteza acima, e depois a deriva de volta à vaga.
				_evento[i] = _tempo + _rng.randf_range(3.0, 9.0)
				_arranca[i] = _tempo + _rng.randf_range(0.25, 0.45)
			if _tempo < _arranca[i]:
				return _rio_dir * vc * 2.6
			var vaga := _centro + _rio_dir * _vaga[i].x + lado * _vaga[i].y
			var para := vaga - p
			para.y = 0.0
			return (para * 1.2 + lado * sin(_tempo * 0.9 + f) * vc * 0.15).limit_length(vc)
		"cruzeiro", "voo":
			if em_fuga and _fuga_dir[i] != Vector3.ZERO:
				return _fuga_dir[i] * _vel_fuga
			var frente := _nucleo_dir
			var lado := Vector3(-frente.z, 0.0, frente.x)
			var alvo := _nucleo + lado * _vaga[i].x - frente * _vaga[i].z
			var para := alvo - p
			para.y = 0.0
			return (para * 1.5 + _nucleo_vel).limit_length(_vel_fuga)
		"fundo":
			if em_fuga:
				return _fuga_dir[i] * _vel_fuga
			if _tempo >= _evento[i]:
				# De tempos em tempos, desliza para outro canto da areia.
				_evento[i] = _tempo + _rng.randf_range(20.0, 50.0)
				_vaga[i] = _vaga_na_areia()
			var alvo := _centro + _vaga[i]
			var para := alvo - p
			para.y = 0.0
			if para.length() < 0.15:
				return Vector3.ZERO
			return (para * 0.8).limit_length(vc * 0.6)
	# roda: em volta do centro, puxada de volta quando se afasta, com um vaivém próprio.
	if em_fuga and _fuga_dir[i] != Vector3.ZERO:
		return _fuga_dir[i] * _vel_fuga
	var rel := Vector3(p.x - _centro.x, 0.0, p.z - _centro.z)
	var dist := rel.length()
	var roda := Vector3(-rel.z, 0.0, rel.x).normalized() * vc * _sentido if dist > 0.01 else Vector3.ZERO
	var volta := Vector3.ZERO
	if dist > _raio:
		# Puxão limitado: antes crescia com a distância e lançava o peixe em disparada.
		volta = (-rel / dist) * minf((dist - _raio) * 0.6, VOLTA_MAXIMA)
	elif dist < _raio * 0.4 and dist > 0.01:
		volta = (rel / dist) * vc * 0.4
	var vaivem := Vector3(sin(_tempo * 0.7 + f), 0.0, cos(_tempo * 0.9 + f * 1.3)) * 0.35 * vc
	return roda + volta + vaivem


## A que altura o peixe quer nadar: na faixa do cardume, ondulando devagar; mais
## fundo escondido na pedra; a raia de fundo, rente à areia.
func _altura_alvo(i: int, piso: float, em_fuga: bool) -> float:
	if modo == "fundo":
		var andando := _vel[i].length() > 0.15
		return piso + (0.08 if andando or em_fuga else 0.0)
	var fracao := clampf(_fundura[i] + 0.15 * sin(_tempo * 0.4 + _fase[i] * TAU), 0.0, 1.0)
	if modo == "pedra" and _ameaca.is_finite():
		fracao = 1.0
	return _sup[i] - lerpf(_prof.x, _prof.y, fracao)


## O centro que anda: a bola foge inteira e se encolhe; o cruzeiro segue a rota (ou
## o alvo da caça, no xaréu); e todos guardam a ameaça mais próxima do cardume.
func _atualizar_nucleo(delta: float, proximos: Array) -> void:
	_ameaca = Vector3.INF
	var menor := INF
	var aqui := centro_atual()
	for perigo: Dictionary in proximos:
		var pp: Vector3 = perigo["pos"]
		var d := Vector2(pp.x - aqui.x, pp.z - aqui.z).length()
		var alcance: float = float(perigo["raio"]) + (_raio_pedra + 1.5 if modo == "pedra" else _raio * 0.6)
		if d < alcance and d < menor:
			menor = d
			_ameaca = pp
	match modo:
		"bola":
			var desejada := Vector3.ZERO
			if _ameaca.is_finite():
				var foge := Vector3(_nucleo.x - _ameaca.x, 0.0, _nucleo.z - _ameaca.z)
				desejada = (foge.normalized() if foge.length_squared() > 0.0001 else Vector3.RIGHT) * _vel_fuga * 0.6
				_aperto = move_toward(_aperto, 0.55, delta * 1.5)
			else:
				# Em casa: um giro lento em volta da âncora.
				var casa := _centro + Vector3(cos(_tempo * 0.15), 0.0, sin(_tempo * 0.15)) * 0.6
				desejada = ((casa - _nucleo) * 0.5).limit_length(_vel_cruzeiro * 0.5)
				_aperto = move_toward(_aperto, 1.0, delta * 0.3)
			desejada.y = 0.0
			_nucleo_vel = _nucleo_vel.lerp(desejada, 1.0 - exp(-3.0 * delta))
			var proximo := _nucleo + _nucleo_vel * delta
			# Não foge para o raso nem para longe demais da canoa dela.
			if _lamina_em(proximo) >= _prof.y + 0.08 and Vector2(proximo.x - _centro.x, proximo.z - _centro.z).length() < 7.0:
				_nucleo = proximo
			else:
				_nucleo_vel = Vector3.ZERO
		"cruzeiro", "voo":
			if _rota.is_empty():
				return
			var alvo := _rota[_rota_i]
			var rapidez := _vel_cruzeiro
			if _alvo_caca.is_finite():
				alvo = _alvo_caca
				rapidez = _vel_fuga
			elif _ameaca.is_finite():
				rapidez = _vel_cruzeiro * 1.6
			var para := Vector3(alvo.x - _nucleo.x, 0.0, alvo.z - _nucleo.z)
			if not _alvo_caca.is_finite() and para.length() < maxf(2.0, _raio * 0.3):
				_rota_i = (_rota_i + 1) % _rota.size()
			if para.length_squared() > 0.0001:
				var direcao := para.normalized()
				_nucleo_dir = _nucleo_dir.slerp(direcao, 1.0 - exp(-1.5 * delta)).normalized()
			_nucleo_vel = _nucleo_dir * rapidez
			_nucleo += _nucleo_vel * delta
			_nucleo.y = _centro.y


func _perigos_perto() -> Array:
	var lista: Array = []
	var aqui := centro_atual()
	var extensao := _raio + 4.0
	if modo in ["cruzeiro", "voo"]:
		extensao = _raio + 8.0
	for perigo in perigos:
		if not perigo is Dictionary:
			continue
		if perigo.get("no") == self:
			continue
		if perigo.has("so_para") and not (especie in perigo["so_para"]):
			continue
		var pp: Vector3 = perigo["pos"]
		if Vector2(pp.x - aqui.x, pp.z - aqui.z).length() < extensao + float(perigo["raio"]) + _raio:
			lista.append(perigo)
	return lista


# --- água, leito e superfície ------------------------------------------------------

func _superficie_do_mar() -> float:
	if _mundo != null and _mundo.has_method("water_level"):
		var nivel := float(_mundo.water_level())
		if is_finite(nivel):
			return nivel
	return _centro.y


## Lâmina d'água no ponto (unidades): a do rio na água doce; a do mar com a maré.
func _lamina_em(ponto: Vector3) -> float:
	if agua_doce:
		if _mundo != null and _mundo.has_method("water_depth_at"):
			return float(_mundo.water_depth_at(ponto))
		return 1.0
	var lamina := Mar.lamina_em(Vector2(ponto.x, ponto.z))
	if is_nan(lamina):
		return 0.0
	return maxf(lamina / Mare.METROS_POR_UNIDADE + Mare.nivel_offset(), 0.0)


## Lê a superfície e o leito onde o peixe está.
func _consultar(i: int, superficie: float) -> void:
	var p := _pos[i]
	if agua_doce and _mundo != null and _mundo.has_method("water_level_at"):
		var nivel := float(_mundo.water_level_at(p))
		var lamina := float(_mundo.water_depth_at(p))
		if not is_finite(nivel) or lamina <= 0.0:
			# Fora da calha: sem água para o peixe.
			_sup[i] = _sup[i] if is_finite(_sup[i]) else _centro.y
			_leito[i] = _sup[i]
			return
		_sup[i] = nivel
		_leito[i] = nivel - lamina
		return
	_sup[i] = superficie
	_leito[i] = superficie - _lamina_em(p)


# --- nascer, comer, saltar -------------------------------------------------------

func _nascer(i: int) -> void:
	var r := _rng
	var ang := r.randf() * TAU
	var p := _centro
	match modo:
		"bola":
			_vaga[i] = Vector3(ang, r.randf_range(0.25, 1.0) * _raio, 0.0)
			p = _nucleo + Vector3(cos(ang), 0.0, sin(ang)) * _vaga[i].y
		"pedra":
			# A vaga em volta da rocha, só onde cabe peixe.
			var melhor := ang
			var raio_vaga := _raio_pedra + r.randf_range(0.3, maxf(_raio, 0.4))
			for tentativa in 10:
				var a := r.randf() * TAU
				var ponto := _pedra + Vector3(cos(a), 0.0, sin(a)) * raio_vaga
				if _lamina_em(ponto) >= _prof.y + 0.1:
					melhor = a
					break
			_vaga[i] = Vector3(melhor, raio_vaga, 0.0)
			p = _pedra + Vector3(cos(melhor), 0.0, sin(melhor)) * raio_vaga
		"rio":
			var lado := Vector3(-_rio_dir.z, 0.0, _rio_dir.x)
			if _n == 1:
				# Sozinha (a traíra): parada na margem, quieta.
				_vaga[i] = Vector3(r.randf_range(-0.5, 0.5), _rio_largura * 0.3 * (1.0 if r.randf() < 0.5 else -1.0), 0.0)
			else:
				_vaga[i] = Vector3(r.randf_range(-_raio, _raio), r.randf_range(-0.3, 0.3) * _rio_largura, 0.0)
			p = _centro + _rio_dir * _vaga[i].x + lado * _vaga[i].y
		"cruzeiro":
			_vaga[i] = Vector3(r.randf_range(-1.0, 1.0) * _raio * 0.5, 0.0, r.randf_range(0.0, 1.0) * _raio)
			p = _nucleo - _nucleo_dir * _vaga[i].z + Vector3(-_nucleo_dir.z, 0.0, _nucleo_dir.x) * _vaga[i].x
		"voo":
			# Fila escalonada: um de cada lado, cada par um pouco mais atrás.
			var par := float((i + 1) >> 1)
			var lado_voo := 1.0 if i % 2 == 1 else -1.0
			_vaga[i] = Vector3(lado_voo * par * 1.5 * float(_esp["tamanho"]) * 0.8, 0.0, par * 1.7 * float(_esp["tamanho"]) * 0.8)
			p = _nucleo - _nucleo_dir * _vaga[i].z + Vector3(-_nucleo_dir.z, 0.0, _nucleo_dir.x) * _vaga[i].x
		"fundo":
			_vaga[i] = _vaga_na_areia()
			p = _centro + _vaga[i]
		_:
			var raio_roda := r.randf_range(0.5, _raio)
			p = _centro + Vector3(cos(ang), 0.0, sin(ang)) * raio_roda
			_vel[i] = Vector3(-sin(ang), 0.0, cos(ang)) * _vel_cruzeiro * _sentido
	p.y = _centro.y - lerpf(_prof.x, _prof.y, _fundura[i])
	_pos[i] = p
	if _vel[i].length_squared() > 0.0001:
		_rumo[i] = atan2(-_vel[i].x, -_vel[i].z)
	elif modo == "rio":
		_rumo[i] = atan2(-_rio_dir.x, -_rio_dir.z)
	else:
		_rumo[i] = r.randf() * TAU
	_consulta[i] = 0.0
	_consultar(i, _superficie_do_mar())


## Um canto da areia para a raia de fundo, na faixa de lâmina do cardume.
func _vaga_na_areia() -> Vector3:
	for tentativa in 12:
		var ang := _rng.randf() * TAU
		var ponto := Vector3(cos(ang), 0.0, sin(ang)) * _rng.randf_range(0.0, _raio)
		var lamina := _lamina_em(_centro + ponto)
		if lamina >= _prof.x and lamina <= _prof.y:
			return ponto
	return Vector3.ZERO


## O peixe comido volta pela borda do cardume, nadando para dentro.
func _renascer(i: int) -> void:
	_vivo[i] = 1
	_nascer(i)
	var de_fora := Vector3(cos(_fase[i] * TAU), 0.0, sin(_fase[i] * TAU)) * maxf(_raio, 1.5)
	if _lamina_em(_pos[i] + de_fora) >= _prof.y:
		_pos[i] += de_fora


## O peixe mais perto de `ponto` entre os vivos e à vista, ou -1.
func peixe_mais_perto(ponto: Vector3) -> int:
	var melhor := -1
	var menor := INF
	for i in _n:
		if not vivo(i):
			continue
		var d := _pos[i].distance_squared_to(ponto)
		if d < menor:
			menor = d
			melhor = i
	return melhor


## Um peixe comido: some com respingo e volta depois de `volta` segundos (ou entre
## 60 e 120 s).
func devorar(i: int, volta: float = -1.0) -> void:
	if i < 0 or i >= _n or _vivo[i] == 0:
		return
	_vivo[i] = 0
	comidos += 1
	_volta[i] = _tempo + (volta if volta > 0.0 else _rng.randf_range(60.0, 120.0))
	respingo(self, Vector3(_pos[i].x, _sup[i], _pos[i].z), float(_esp["tamanho"]) * 2.0)
	_escrever()


## O ataque do xaréu na bola: a água ferve, a bola se aperta e uma ou duas
## sardinhas somem (e voltam em um minuto).
func ferver() -> void:
	_aperto = 0.4
	var superficie := _superficie_do_mar()
	for k in 3:
		var ang := _rng.randf() * TAU
		respingo(self, Vector3(_nucleo.x + cos(ang) * 0.5, superficie, _nucleo.z + sin(ang) * 0.5), 0.6)
	for k in _rng.randi_range(1, 2):
		devorar(peixe_mais_perto(_nucleo + Vector3(_rng.randf_range(-0.5, 0.5), 0.0, _rng.randf_range(-0.5, 0.5))), 60.0)


## O cardume caçador (o xaréu) vai atrás deste ponto; INF devolve à rota.
func cacar(alvo: Vector3) -> void:
	_alvo_caca = alvo


## Um peixe salta fora d'água e cai de volta com respingo (a tainha perto do
## jogador, a piaba no poço). Devolve o índice, ou -1.
func saltar(i: int = -1) -> int:
	if i < 0:
		var candidatos: Array[int] = []
		for k in _n:
			if vivo(k) and _salto[k] <= 0.0:
				candidatos.append(k)
		if candidatos.is_empty():
			return -1
		i = candidatos[_rng.randi_range(0, candidatos.size() - 1)]
	_duracao_salto = 0.45 if float(_esp["tamanho"]) < 0.3 else 0.75
	_salto[i] = _duracao_salto
	var frente := Vector3(-sin(_rumo[i]), 0.0, -cos(_rumo[i]))
	_vel[i] = frente * _vel_cruzeiro * 1.8
	respingo(self, Vector3(_pos[i].x, _sup[i], _pos[i].z), float(_esp["tamanho"]))
	return i


func _altura_do_salto(i: int, delta: float) -> float:
	_salto[i] -= delta
	var u := clampf(1.0 - _salto[i] / _duracao_salto, 0.0, 1.0)
	var altura := maxf(float(_esp["tamanho"]) * 1.4, 0.18)
	# Bico para cima na subida e para baixo na queda.
	_inclina[i] = cos(u * PI) * 0.9
	if _salto[i] <= 0.0:
		_salto[i] = 0.0
		_inclina[i] = 0.0
		respingo(self, Vector3(_pos[i].x, _sup[i], _pos[i].z), float(_esp["tamanho"]))
		return _sup[i] - _prof.x
	return _sup[i] + sin(u * PI) * altura - _altura_meia * _escala[i]


# --- o corpo -------------------------------------------------------------------

func _montar_visual(tripo: bool) -> void:
	var corpo := _corpo(tripo)
	_canonica = corpo["canonica"]
	_altura_meia = float(corpo["altura"]) * 0.5 * float(corpo["escala"])
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = corpo["mesh"]
	multimesh.instance_count = _n
	_mm = MultiMeshInstance3D.new()
	_mm.name = "Peixes"
	_mm.multimesh = multimesh
	_mm.material_override = corpo["material"]
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mm.visibility_range_end = alcance_visivel
	_mm.visibility_range_end_margin = 4.0
	_mm.top_level = true
	add_child(_mm)
	# A origem do MultiMesh fica no cardume: o alcance de visão mede dali.
	_mm.global_transform = Transform3D(Basis.IDENTITY, _centro)
	_escala_base = float(corpo["escala"])


## Malha, material e o peixe canônico da espécie, guardados para os outros cardumes.
func _corpo(tripo: bool) -> Dictionary:
	var forma := String(_esp["forma"])
	var shader: Shader = RAIA_VOO if forma == "raia" else (SILHUETA if agua_doce else NADO)
	var chave_cache := "%s|%s|%s" % [especie, tripo, shader.resource_path]
	if _corpos.has(chave_cache):
		return _corpos[chave_cache]
	var tamanho := float(_esp["tamanho"])
	var corpo := {}
	if tripo:
		var chaves: Array = _esp["chaves"]
		for chave: String in chaves:
			if not CatalogoAssets.tem_tripo(chave):
				continue
			var malha := CatalogoAssets.malha(chave, 1.0)
			if malha.is_empty():
				continue
			var largura := float(CatalogoAssets.PECAS[chave].get("largura", tamanho))
			var altura := float(malha["altura"])
			# A base do catálogo põe o pé em y = 0; o peixe canônico fica centrado.
			var canonica: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, -altura * 0.5, 0.0)) * (malha["base"] as Transform3D)
			var tinta: Color = Color.WHITE if chave == chaves[0] else _esp["tinta"]
			corpo = {"mesh": malha["mesh"], "canonica": canonica, "altura": altura, "comprimento": largura,
				"escala": tamanho / maxf(largura, 0.01), "material": _material(shader, malha["mesh"], canonica, largura, tinta)}
			break
	if corpo.is_empty():
		corpo = _corpo_procedural(shader, forma)
	_corpos[chave_cache] = corpo
	return corpo


## O material do nado com as texturas do GLB (cor, normal e a MR do Tripo: rugosidade
## no G, metal no B).
func _material(shader: Shader, mesh: Mesh, canonica: Transform3D, comprimento: float, tinta: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	var original: BaseMaterial3D = null
	if mesh != null and mesh.get_surface_count() > 0:
		original = mesh.surface_get_material(0) as BaseMaterial3D
	if original != null:
		if original.albedo_texture != null:
			material.set_shader_parameter("textura_cor", original.albedo_texture)
			material.set_shader_parameter("tem_textura", true)
		if original.normal_enabled and original.normal_texture != null:
			material.set_shader_parameter("textura_normal", original.normal_texture)
			material.set_shader_parameter("tem_normal", true)
		var mr: Texture2D = original.roughness_texture if original.roughness_texture != null else original.metallic_texture
		if mr != null:
			material.set_shader_parameter("textura_mr", mr)
			material.set_shader_parameter("tem_mr", true)
		tinta = tinta * original.albedo_color
	material.set_shader_parameter("cor", tinta)
	_parametros_do_nado(material, canonica, comprimento)
	return material


func _parametros_do_nado(material: ShaderMaterial, canonica: Transform3D, comprimento: float) -> void:
	material.set_shader_parameter("canonica", Projection(canonica))
	material.set_shader_parameter("canonica_inv", Projection(canonica.affine_inverse()))
	material.set_shader_parameter("comprimento", comprimento)
	material.set_shader_parameter("amplitude", float(_esp["onda"]))
	material.set_shader_parameter("batida", float(_esp["batida"]))
	material.set_shader_parameter("tempo", _relogio_do_nado)
	if String(_esp["forma"]) == "raia":
		material.set_shader_parameter("envergadura", comprimento)
	if material.shader == SILHUETA:
		# Depois da água doce, que também é transparente.
		material.render_priority = 1


## Sem GLB (ou no estilo procedural): fuso achatado com a cauda em leque, ou o
## losango da raia, já no peixe canônico (cabeça no -Z) e com 1 u de comprimento.
func _corpo_procedural(shader: Shader, forma: String) -> Dictionary:
	var ferramenta := SurfaceTool.new()
	ferramenta.begin(Mesh.PRIMITIVE_TRIANGLES)
	var proporcao := float(_esp["corpo"])
	if forma == "raia":
		var disco := SphereMesh.new()
		disco.radius = 0.5
		disco.height = 1.0
		disco.radial_segments = 16
		disco.rings = 6
		ferramenta.append_from(disco, 0, Transform3D(Basis.from_scale(Vector3(1.0, proporcao, 0.62)), Vector3(0.0, 0.0, -0.1)))
		var cauda := BoxMesh.new()
		cauda.size = Vector3(0.03, 0.02, 0.5)
		ferramenta.append_from(cauda, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.42)))
	else:
		var fuso := SphereMesh.new()
		fuso.radius = 0.5
		fuso.height = 1.0
		fuso.radial_segments = 12
		fuso.rings = 6
		ferramenta.append_from(fuso, 0, Transform3D(Basis.from_scale(Vector3(proporcao * 0.45, proporcao, 0.8)), Vector3(0.0, 0.0, -0.08)))
		var rabo := PrismMesh.new()
		rabo.size = Vector3(proporcao * 0.9, 0.24, 0.02)
		# O leque da cauda, de pé, com a ponta presa no corpo.
		ferramenta.append_from(rabo, 0, Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 0.0, 0.4)))
	ferramenta.generate_normals()
	var malha := ferramenta.commit()
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("cor", _esp["cor"])
	_parametros_do_nado(material, Transform3D.IDENTITY, 1.0)
	if forma == "raia":
		material.set_shader_parameter("envergadura", 1.0)
	return {"mesh": malha, "canonica": Transform3D.IDENTITY, "altura": proporcao, "comprimento": 1.0,
		"escala": float(_esp["tamanho"]), "material": material}


## Passa posição, rumo e nado de cada peixe para o MultiMesh, de uma vez.
func _escrever() -> void:
	if _mm == null:
		return
	_buffer.resize(_n * 16)
	var origem := _centro
	for i in _n:
		var o := i * 16
		var t := Transform3D(Basis(), Vector3.ZERO)
		if _vivo[i] == 1 and _escondido[i] == 0:
			var giro := Basis.from_euler(Vector3(_inclina[i], _rumo[i], 0.0)).scaled(Vector3.ONE * _escala_base * _escala[i])
			t = Transform3D(giro, _pos[i] - origem) * _canonica
		else:
			t = Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), _pos[i] - origem)
		_buffer[o] = t.basis.x.x
		_buffer[o + 1] = t.basis.y.x
		_buffer[o + 2] = t.basis.z.x
		_buffer[o + 3] = t.origin.x
		_buffer[o + 4] = t.basis.x.y
		_buffer[o + 5] = t.basis.y.y
		_buffer[o + 6] = t.basis.z.y
		_buffer[o + 7] = t.origin.y
		_buffer[o + 8] = t.basis.x.z
		_buffer[o + 9] = t.basis.y.z
		_buffer[o + 10] = t.basis.z.z
		_buffer[o + 11] = t.origin.z
		# Nado: fase, ritmo (pela velocidade), susto e "fora d'água" (a silhueta do rio).
		var ritmo := clampf(_vel[i].length() / maxf(_vel_cruzeiro, 0.05), 0.0, 3.0)
		if modo != "fundo":
			ritmo = maxf(ritmo, 0.6)
		_buffer[o + 12] = _fase[i]
		_buffer[o + 13] = ritmo
		_buffer[o + 14] = _susto[i]
		_buffer[o + 15] = 1.0 if (_salto[i] > 0.0 and _pos[i].y > _sup[i]) else 0.0
	_mm.multimesh.buffer = _buffer


# --- respingo ------------------------------------------------------------------

static var _anel: GradientTexture2D


## Respingo na superfície: gotas que sobem e caem e um anel que abre e some. O
## peixe que salta, o comido, a água fervendo no ataque do xaréu.
static func respingo(pai: Node, onde: Vector3, tamanho: float = 0.5) -> void:
	if pai == null or not pai.is_inside_tree():
		return
	tamanho = clampf(tamanho, 0.15, 3.0)
	var gotas := GPUParticles3D.new()
	gotas.name = "Respingo"
	gotas.one_shot = true
	gotas.amount = 10
	gotas.lifetime = 0.7
	gotas.explosiveness = 0.9
	gotas.local_coords = false
	var processo := ParticleProcessMaterial.new()
	processo.direction = Vector3.UP
	processo.spread = 35.0
	processo.initial_velocity_min = 0.9 * sqrt(tamanho)
	processo.initial_velocity_max = 1.8 * sqrt(tamanho)
	processo.gravity = Vector3(0.0, -6.0, 0.0)
	processo.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	processo.emission_sphere_radius = 0.08 * tamanho
	processo.scale_min = 0.6
	processo.scale_max = 1.0
	gotas.process_material = processo
	var gota := SphereMesh.new()
	gota.radius = 0.025 * sqrt(tamanho)
	gota.height = gota.radius * 2.0
	gota.radial_segments = 6
	gota.rings = 3
	var branco := StandardMaterial3D.new()
	branco.albedo_color = Color(0.95, 0.98, 1.0, 0.85)
	branco.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	branco.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	branco.render_priority = 1
	gota.material = branco
	gotas.draw_pass_1 = gota
	pai.add_child(gotas)
	gotas.global_position = onde
	gotas.emitting = true
	var anel := MeshInstance3D.new()
	anel.name = "Anel"
	var placa := PlaneMesh.new()
	placa.size = Vector2.ONE
	anel.mesh = placa
	var espuma := StandardMaterial3D.new()
	espuma.albedo_texture = _textura_anel()
	espuma.albedo_color = Color(1.0, 1.0, 1.0, 0.7)
	espuma.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	espuma.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	espuma.render_priority = 1
	anel.material_override = espuma
	anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(anel)
	anel.global_position = onde + Vector3(0.0, 0.01, 0.0)
	anel.scale = Vector3.ONE * 0.2 * tamanho
	var abre := anel.create_tween()
	abre.set_parallel(true)
	abre.tween_property(anel, "scale", Vector3.ONE * 1.3 * tamanho, 0.9).set_ease(Tween.EASE_OUT)
	abre.tween_property(espuma, "albedo_color:a", 0.0, 0.9)
	abre.chain().tween_callback(anel.queue_free)
	gotas.finished.connect(gotas.queue_free)


static func _textura_anel() -> GradientTexture2D:
	if _anel != null:
		return _anel
	var degrade := Gradient.new()
	degrade.set_color(0, Color(1, 1, 1, 0))
	degrade.set_color(1, Color(1, 1, 1, 0))
	degrade.add_point(0.62, Color(1, 1, 1, 0))
	degrade.add_point(0.8, Color(1, 1, 1, 0.9))
	degrade.add_point(0.9, Color(1, 1, 1, 0.3))
	_anel = GradientTexture2D.new()
	_anel.gradient = degrade
	_anel.fill = GradientTexture2D.FILL_RADIAL
	_anel.fill_from = Vector2(0.5, 0.5)
	_anel.fill_to = Vector2(1.0, 0.5)
	_anel.width = 64
	_anel.height = 64
	return _anel
