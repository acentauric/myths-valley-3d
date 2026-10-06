extends CharacterBody3D
## UM BICHO DE CASA DE QUATRO PATAS: o cão, o gato, o porco (e a cabra, quando
## as casas novas a trouxerem). Quem o cria e lhe dá a rotina é o
## `bichos_de_casa.gd`, pelo `data/bichos_de_casa.json`.
##
## FORA DA CAMADA 1, como o caititu: camada nenhuma, máscara 1. Não barra o
## jogador, e a câmera não salta quando ele passa entre ela e o jogador — o
## mesmo defeito que o cruzeiro do adro teve. Anda com gravidade e colisão, e
## pelo caminho da malha de navegação quando o destino é longe (como o
## morador, `npc.gd`); não entra na água.
##
## AS ROTINAS, pela hora (`Dia.periodo()`):
##   - CÃO: de dia acompanha o dono a passo e meio (e deita na porta na sesta,
##     do meio-dia às duas); à noite deita na porta (troca para o GLB deitado
##     depois de três segundos parado) e vigia, levantando quando o jogador
##     passa perto. O filhote segue o cão grande em vez do dono.
##   - GATO: de manhã na soleira; à tarde vai ao píer com o Tonho, se for dele;
##     no resto, ronda o quintal. Foge do cão e de quem chega correndo.
##   - PORCO: no chiqueiro; à tarde fuça debaixo da mangueira ou da jaqueira
##     mais perto.
##   - SOLTO (cabra, bode, jumento): ronda o terreiro, devagar.

const Animador = preload("res://scripts/prototipo_3d/animador_bicho.gd")

## Distância a que o cão acompanha o dono, e a partir de quando corre atrás.
const JUNTO_DO_DONO := 1.5
const CORRE_ATRAS := 6.0
## A sesta do cão: nesta faixa de horas ele deita na porta mesmo de dia.
const SESTA := Vector2(12.0, 14.0)
## Parado na porta por isto (s), deita.
const DEITA_DEPOIS := 3.0
## O cão de vigia levanta quando o jogador passa a menos disto.
const VIGIA := 6.0
## O gato foge do cão e de quem chega correndo a menos disto.
const FOGE_DO_CAO := 3.0
const FOGE_DE_QUEM_CORRE := 4.0
const FOGE_ATE := 5.0
## Chegou ao ponto: a menos disto.
const CHEGOU := 0.35
## Destino mais longe que isto vai pelo caminho da malha.
const PELA_MALHA := 8.0
const REFAZER_CAMINHO := 3.0
## Querendo andar e andando menos que esta fração do passo por tanto tempo (s), o
## bicho está TRAVADO (banco, cerca, quina de casa): vai pela malha de navegação
## por alguns segundos, mesmo perto.
const TRAVADO_ABAIXO := 0.25
const TRAVADO_POR := 0.6
const DESVIA_POR := 5.0
## O porco procura fruta até esta distância do chiqueiro.
const FRUTA_ATE := 40.0
## Sem fruteira no raio, o porco só procura de novo depois disto (s): world.arvores()
## monta ~6.300 dicionários a cada chamada, e repetir isso por decisão custava 10–20 ms.
const REPROCURA_FRUTA := 30.0
const FRUTEIRAS := ["mangueira", "jaqueira", "mangueira_leve", "jaqueira_leve"]
## Lâmina (u) a partir da qual o bicho não pisa: o riacho, que o rio mais fundo
## não passa de 0,24, ele atravessa; o mar, não.
const AGUA_FUNDA := 0.3
## Até onde (u) da câmera o bicho anda com física (colide com banco e cerca); mais
## longe, ele anda sem (`_andar_livre`).
const FISICA_ATE := 26.0
## Longe da câmera (u), o bicho some e não anda: pula para onde estaria.
const ALCANCE := 80.0

var dados: Dictionary = {}
var especie: Dictionary = {}
var chave: String = ""
var rotina: String = ""
var casa: String = ""
var world
var jogador: Node3D
## O morador dono (cão, gato do Tonho), ou nulo.
var dono: Node3D
## Outro bicho que este segue (o filhote segue o cão).
var lider: Node3D
## Os cães da casa, de quem o gato foge.
var caes: Array = []
## Perto da câmera: anda de verdade; longe, só pula de posto em posto.
var perto := true
## Muito perto da câmera: anda com física. O gerente decide (histerese própria).
var fisica := true
## O que está fazendo agora, para o portão e para a depuração.
var fazendo := ""
var deitado := false

var _animador
var _pose: Node3D
var _de_pe: Node3D
var _deitado: Node3D
var _alvo := Vector3.INF
var _velocidade := 1.0
var _parado := 0.0
var _espera := 0.0
var _fugindo := 0.0
var _rumo_da_fuga := Vector3.ZERO
var _caminho := PackedVector3Array()
var _ponto_da_vez := 0
var _caminho_ate := Vector3.INF
var _refazer_em := 0.0
var _rng := RandomNumberGenerator.new()
var _fruta := Vector3.INF
var _fruta_procurada_em := -INF   ## quando procurou e não achou (s, relógio do jogo)
var _travado := 0.0
var _lugar := Vector3.INF
var _longe_em := 0.0
var _desvia_ate := -1.0


func configurar(d: Dictionary, sp: Dictionary, nome_da_casa: String, mundo, alvo_jogador: Node3D) -> void:
	dados = d
	especie = sp
	chave = str(d.get("especie", ""))
	rotina = str(d.get("rotina", ""))
	casa = nome_da_casa
	world = mundo
	jogador = alvo_jogador
	name = "Bicho" + chave.capitalize().replace(" ", "")


func _ready() -> void:
	add_to_group("bichos_de_casa")
	_rng.seed = hash(name + casa + str(get_index()))
	collision_layer = 0
	collision_mask = 1
	# SEM o ímã do chão e com poucos deslizes: o `move_and_slide` com snap custava
	# meio milésimo de segundo por bicho por quadro de física contra a malha do
	# terreno, dez vezes o resto. O chão se segura pela própria gravidade.
	floor_snap_length = 0.0
	max_slides = 2
	# Íngreme de propósito: a borda da rua do vale é um degrau de 63°, e o cão de
	# cápsula fina, que não sobe degrau, ficaria preso nela.
	floor_max_angle = deg_to_rad(70)
	var caixa := _caixa()
	var forma := CollisionShape3D.new()
	var cilindro := CapsuleShape3D.new()
	cilindro.radius = maxf(0.08, minf(caixa.x, caixa.z) * 0.45)
	cilindro.height = maxf(cilindro.radius * 2.0, caixa.y)
	forma.shape = cilindro
	forma.position.y = cilindro.height * 0.5
	add_child(forma)
	_pose = Node3D.new()
	_pose.name = "Pose"
	add_child(_pose)
	var cor := Color(str(especie.get("cor", "888888")))
	_de_pe = Animador.vestir(chave, _pose, caixa, cor, ALCANCE)
	_animador = Animador.new()
	_animador.name = "Animador"
	add_child(_animador)
	_animador.configurar(_pose, _de_pe, false, chave, float(especie.get("passo", 1.0)))
	_velocidade = float(especie.get("passo", 1.0))


func _caixa() -> Vector3:
	var c: Array = especie.get("caixa", [0.3, 0.5, 0.8])
	return Vector3(float(c[0]), float(c[1]), float(c[2]))


## Um ponto do referencial da casa (porta no +Z), no chão.
func na_casa(deslocamento: Array) -> Vector3:
	var local := Vector3(float(deslocamento[0]), float(deslocamento[1]), float(deslocamento[2]))
	var base: Vector3 = world.ancoras.get(casa, Vector3.ZERO)
	var frente: Vector3 = world.ancoras.get(casa + "Frente", Vector3.BACK)
	return world.ground_position(base + local.rotated(Vector3.UP, atan2(frente.x, frente.z)), 0.02)


## O lugar de casa deste bicho: a porta do cão, a soleira do gato, o chiqueiro.
func lugar_de_casa() -> Vector3:
	if _lugar.is_finite():
		return _lugar
	_lugar = world.ground_position(world.ancoras.get(casa, global_position), 0.02)
	for campo in ["porta", "soleira", "chiqueiro", "terreiro"]:
		if dados.has(campo):
			_lugar = na_casa(dados[campo])
			break
	return _lugar


# --- o quadro ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if world == null:
		return
	if not perto:
		# Longe da vista não se anda, e quase não se pensa: quatro vezes por
		# segundo ele decide e está onde estaria.
		_longe_em -= delta
		_parado += delta
		if _longe_em > 0.0:
			return
		_decidir(0.25)
		_longe_em = 0.25
		if _alvo.is_finite():
			global_position = _alvo
		velocity = Vector3.ZERO
		_animador.velocidade = 0.0
		return
	_decidir(delta)
	_andar(delta)


func _decidir(delta: float) -> void:
	_espera -= delta
	match rotina:
		"cao":
			_rotina_do_cao(delta)
		"gato":
			_rotina_do_gato(delta)
		"porco":
			_rotina_do_porco(delta)
		_:
			# SOLTO (a cabra, o bode, o jumento): ronda o terreiro, devagar.
			_rondar(lugar_de_casa(), float(dados.get("raio", 3.0)), 0.5)


func _rotina_do_cao(_delta: float) -> void:
	var periodo: String = Dia.periodo()
	var seguir: Node3D = lider if lider != null and is_instance_valid(lider) else dono
	if lider != null and is_instance_valid(lider):
		# O filhote: vai aonde o cão vai, colado nele.
		if lider.get("deitado"):
			_ir_deitar(lugar_de_casa())
		else:
			_acompanhar(lider, 1.0)
		return
	# De dia segue o dono; só na hora da sesta (do meio-dia às duas) e de noite deita.
	var sesta: bool = Dia.hora >= SESTA.x and Dia.hora < SESTA.y
	if periodo in ["manha", "tarde", "entardecer"] and not sesta and seguir != null and is_instance_valid(seguir):
		_acompanhar(seguir, JUNTO_DO_DONO)
		return
	var porta := lugar_de_casa()
	if periodo == "noite" and jogador != null \
			and _plano(jogador.global_position - global_position).length() < VIGIA \
			and _plano(porta - global_position).length() < 1.5:
		# DE VIGIA: levanta e encara quem passa.
		fazendo = "vigia"
		_levantar()
		_alvo = global_position
		_virar_para(jogador.global_position)
		return
	_ir_deitar(porta)


func _acompanhar(quem: Node3D, junto: float) -> void:
	_levantar()
	fazendo = "acompanha"
	var para := _plano(global_position - quem.global_position)
	var lado := para.normalized() if para.length() > 0.05 else Vector3.BACK
	var ponto: Vector3 = quem.global_position + lado * junto
	if _plano(ponto - global_position).length() < CHEGOU * 2.0 and _plano(quem.global_position - global_position).length() <= junto + 0.6:
		_alvo = global_position
		return
	_alvo = world.ground_position(ponto, 0.02)
	var longe := _plano(quem.global_position - global_position).length()
	_velocidade = float(especie.get("corrida", 3.0)) if longe > CORRE_ATRAS else float(especie.get("passo", 1.0)) * 1.15


## Vai para o ponto e, parado lá uns segundos, deita.
func _ir_deitar(ponto: Vector3) -> void:
	_velocidade = float(especie.get("passo", 1.0))
	if _plano(ponto - global_position).length() > 0.6:
		_levantar()
		fazendo = "vai_deitar"
		_alvo = ponto
		return
	_alvo = global_position
	fazendo = "deitado" if deitado else "na_porta"
	if _parado >= DEITA_DEPOIS:
		_deitar()


func _rotina_do_gato(_delta: float) -> void:
	# FOGE primeiro: do cão a menos de três passos, de quem chega correndo.
	if _fugindo > 0.0:
		_fugindo -= get_physics_process_delta_time()
		fazendo = "foge"
		_velocidade = float(especie.get("corrida", 4.0))
		_alvo = world.ground_position(global_position + _rumo_da_fuga * 2.0, 0.02)
		return
	var perigo := _perigo_para_o_gato()
	if perigo.is_finite():
		_rumo_da_fuga = _plano(global_position - perigo).normalized()
		if _rumo_da_fuga == Vector3.ZERO:
			_rumo_da_fuga = Vector3.RIGHT
		_fugindo = FOGE_ATE / float(especie.get("corrida", 4.0))
		return
	var periodo: String = Dia.periodo()
	var soleira := lugar_de_casa()
	if periodo == "manha":
		fazendo = "soleira"
		_velocidade = float(especie.get("passo", 0.8))
		_alvo = soleira if _plano(soleira - global_position).length() > 0.4 else global_position
		return
	if periodo == "tarde" and dono != null and is_instance_valid(dono) and str(dados.get("dono", "")) != "":
		fazendo = "com_o_dono"
		_acompanhar(dono, 1.2)
		_velocidade = minf(_velocidade, float(especie.get("passo", 0.8)) * 1.6)
		return
	_rondar(soleira + _plano(world.ancoras.get(casa, soleira) - soleira) * 1.6, 3.5, 0.75)


## O que o gato teme agora (cão perto, gente correndo), ou INF.
func _perigo_para_o_gato() -> Vector3:
	for cao in caes:
		if is_instance_valid(cao) and _plano(cao.global_position - global_position).length() < FOGE_DO_CAO:
			return cao.global_position
	if jogador != null and _plano(jogador.global_position - global_position).length() < FOGE_DE_QUEM_CORRE:
		var correndo: bool = jogador.has_method("is_running") and jogador.is_running() \
			and _plano(jogador.get("velocity") if jogador.get("velocity") != null else Vector3.ZERO).length() > 3.0
		if correndo:
			return jogador.global_position
	return Vector3.INF


func _rotina_do_porco(_delta: float) -> void:
	var chiqueiro := lugar_de_casa()
	if Dia.periodo() == "tarde":
		var agora := Time.get_ticks_msec() * 0.001
		if not _fruta.is_finite() and agora - _fruta_procurada_em >= REPROCURA_FRUTA:
			_fruta = _fruteira_perto(chiqueiro)
			if not _fruta.is_finite():
				_fruta_procurada_em = agora
		if _fruta.is_finite():
			# FUÇA debaixo da fruteira: anda devagar, para e mete o focinho.
			_rondar(_fruta, 3.0, 0.6, true)
			return
	_rondar(chiqueiro, float(dados.get("raio", 1.6)), 0.55, true)


func _fruteira_perto(de: Vector3) -> Vector3:
	var melhor := Vector3.INF
	var menor := FRUTA_ATE
	for arvore: Dictionary in world.arvores():
		if not str(arvore.get("especie", "")) in FRUTEIRAS:
			continue
		var d := _plano(arvore["pos"] - de).length()
		if d < menor:
			menor = d
			melhor = arvore["pos"]
	return melhor


## RONDA um raio em volta de um ponto: vai, para uns segundos, vai de novo.
## Quem fuça (porco) abaixa o focinho enquanto está parado.
func _rondar(centro: Vector3, raio: float, fracao_do_passo: float, fuca: bool = false) -> void:
	_levantar()
	_velocidade = float(especie.get("passo", 1.0)) * fracao_do_passo
	if not _alvo.is_finite() or _plano(_alvo - centro).length() > raio + 0.5:
		_alvo = _ponto_em_volta(centro, raio)
	if _plano(_alvo - global_position).length() <= CHEGOU:
		fazendo = "fuca" if fuca else "parado"
		if fuca and not _animador.bicando() and _rng.randf() < 0.02:
			_animador.bicar(deg_to_rad(18.0))
		if _espera <= 0.0:
			_espera = _rng.randf_range(2.5, 7.0)
			_alvo = _ponto_em_volta(centro, raio)
		return
	fazendo = "anda"


func _ponto_em_volta(centro: Vector3, raio: float) -> Vector3:
	for i in 12:
		var p := centro + Vector3(_rng.randf_range(-raio, raio), 0.0, _rng.randf_range(-raio, raio))
		if world.is_on_land(p) and world.is_walkable_point(p) and not _dentro_de_casa(p):
			return world.ground_position(p, 0.02)
	return world.ground_position(centro, 0.02)


func _dentro_de_casa(p: Vector3) -> bool:
	return Animador.dentro_de_casa(get_tree(), p, 0.3)


# --- o corpo -----------------------------------------------------------------

func _andar(delta: float) -> void:
	if not fisica:
		_andar_livre(delta)
		return
	var direcao := Vector3.ZERO
	if _alvo.is_finite():
		var falta := _plano(_alvo - global_position)
		if falta.length() > CHEGOU * 0.5:
			var rumo := _plano(_ponto_do_caminho(_alvo, delta) - global_position)
			direcao = rumo.normalized() if rumo.length() > 0.05 else falta.normalized()
	var alvo_v := direcao * _velocidade
	velocity.x = move_toward(velocity.x, alvo_v.x, 10.0 * delta)
	velocity.z = move_toward(velocity.z, alvo_v.z, 10.0 * delta)
	if is_on_floor():
		velocity.y = -0.1
	else:
		velocity.y -= 20.0 * delta
	var antes := global_position
	move_and_slide()
	if direcao != Vector3.ZERO:
		var deslocou := _plano(global_position - antes).length() / maxf(delta, 0.0001)
		_travado = _travado + delta if deslocou < _velocidade * TRAVADO_ABAIXO else 0.0
		if _travado >= TRAVADO_POR:
			_travado = 0.0
			_desvia_ate = Time.get_ticks_msec() / 1000.0 + DESVIA_POR
			_caminho_ate = Vector3.INF
	else:
		_travado = 0.0
	# Bicho de casa não entra na água: o passo que molharia a pata é desfeito.
	# Pela lâmina, e não pela terra do mapa — o píer não é terra, e o gato do
	# Tonho vai até ele.
	if _na_agua(global_position):
		global_position = antes
		velocity = Vector3.ZERO
		_alvo = _ponto_em_volta(lugar_de_casa(), 2.0)
	var andou := Vector2(velocity.x, velocity.z).length()
	_animador.velocidade = andou
	if andou > 0.08:
		_parado = 0.0
		var rumo_do_corpo := Vector3(velocity.x, 0.0, velocity.z)
		rotation.y = lerp_angle(rotation.y, atan2(rumo_do_corpo.x, rumo_do_corpo.z), minf(1.0, delta * 8.0))
	else:
		_parado += delta


## ANDA SEM FÍSICA, para o bicho que a câmera vê de longe: o `move_and_slide`
## contra a malha do terreno custa de 0,2 a 1,5 ms por bicho por quadro de
## física, e uma vila inteira de bichos estoura o quadro. Sem física ele segue o
## chão do vale (`ground_position`), não pisa em água funda nem entra em casa, e
## atravessa banco e cerca — o que ninguém vê a mais de `FISICA_ATE` u.
func _andar_livre(delta: float) -> void:
	var direcao := Vector3.ZERO
	if _alvo.is_finite():
		var falta := _plano(_alvo - global_position)
		if falta.length() > CHEGOU * 0.5:
			var rumo := _plano(_ponto_do_caminho(_alvo, delta) - global_position)
			direcao = rumo.normalized() if rumo.length() > 0.05 else falta.normalized()
	var alvo_v := direcao * _velocidade
	velocity.x = move_toward(velocity.x, alvo_v.x, 10.0 * delta)
	velocity.z = move_toward(velocity.z, alvo_v.z, 10.0 * delta)
	velocity.y = 0.0
	var passo := Vector3(velocity.x, 0.0, velocity.z) * delta
	if passo.length_squared() > 0.0:
		# O passo inteiro; se molhasse a pata ou entrasse na parede, só o eixo que
		# sobra (desliza ao longo dela); se nenhum serve, para e escolhe outro rumo.
		var livre := false
		for tentativa in [passo, Vector3(passo.x, 0.0, 0.0), Vector3(0.0, 0.0, passo.z)]:
			var novo: Vector3 = world.ground_position(global_position + tentativa, 0.02)
			if not _na_agua(novo) and not Animador.dentro_de_casa(get_tree(), novo, 0.1):
				global_position = novo
				livre = true
				break
		if not livre:
			velocity = Vector3.ZERO
			_alvo = _ponto_em_volta(lugar_de_casa(), 2.0)
	var andou := Vector2(velocity.x, velocity.z).length()
	_animador.velocidade = andou
	if andou > 0.08:
		_parado = 0.0
		rotation.y = lerp_angle(rotation.y, atan2(velocity.x, velocity.z), minf(1.0, delta * 8.0))
	else:
		_parado += delta


func _na_agua(p: Vector3) -> bool:
	return world.water_depth_at(p) > AGUA_FUNDA and p.y < world.water_level_at(p) + 0.05


func _ponto_do_caminho(destino: Vector3, delta: float) -> Vector3:
	var desviando := Time.get_ticks_msec() / 1000.0 < _desvia_ate
	if _plano(destino - global_position).length() < PELA_MALHA and not desviando:
		return destino
	var navegacao := get_tree().get_first_node_in_group("navegacao")
	if navegacao == null or not navegacao.esta_pronta():
		return destino
	_refazer_em -= delta
	if _caminho_ate.distance_to(destino) > 1.0 or _refazer_em <= 0.0:
		_caminho = navegacao.caminho(global_position, destino)
		_ponto_da_vez = 1 if _caminho.size() > 1 else 0
		_caminho_ate = destino
		_refazer_em = REFAZER_CAMINHO
	if _caminho.is_empty():
		return destino
	while _ponto_da_vez < _caminho.size() - 1 \
			and _plano(_caminho[_ponto_da_vez] - global_position).length() < 0.4:
		_ponto_da_vez += 1
	return _caminho[_ponto_da_vez]


func _virar_para(ponto: Vector3) -> void:
	var para := _plano(ponto - global_position)
	if para.length() > 0.05:
		rotation.y = atan2(para.x, para.z)


## DEITA: troca para o GLB deitado (o cão), ou abaixa a caixa no procedural.
func _deitar() -> void:
	if deitado:
		return
	var chave_deitado := str(especie.get("deitado", ""))
	if chave_deitado == "":
		return
	deitado = true
	if _deitado == null:
		var caixa := _caixa()
		_deitado = Animador.vestir(chave_deitado, _pose, Vector3(caixa.x * 1.4, caixa.y * 0.45, caixa.z * 1.05), Color(str(especie.get("cor", "888888"))), ALCANCE)
	_deitado.visible = true
	_de_pe.visible = false


func _levantar() -> void:
	if not deitado:
		return
	deitado = false
	_parado = 0.0
	if _deitado != null:
		_deitado.visible = false
	_de_pe.visible = true


## Para onde ele vai agora (INF parado à toa).
func alvo() -> Vector3:
	return _alvo


static func _plano(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
