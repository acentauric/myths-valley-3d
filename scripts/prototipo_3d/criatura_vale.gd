extends CharacterBody3D
## CRIATURA da mata, no vale: o bicho do jogo 2D (`scripts/npcs/criatura.gd`)
## em CAIXA CINZA, que é o que a #14 pede — a luta não espera o modelo, e o
## modelo, quando vier (#28), entra no lugar do corpo sem tocar no resto.
##
## A REGRA É A DO 2D, número por número: fareja num raio e desiste num maior
## (quem foi farejado só se livra indo embora de verdade), ARMA O BOTE antes de
## morder, a mordida confere de novo a distância na hora de fechar, a ginga
## conta antes da distância e o respiro depois dela, a pancada empurra e pisca,
## a rasteira tonteia, e cair é cair de lado e sumir devagar.
##
## O QUE MUDA É A ESCALA. `ESPECIES` guarda os números do 2D como estão, em
## pixels, e `u_por_px` os traz para o vale. O fator sai do PASSO do jogador
## (62 px/s lá, `walk_speed` aqui), e não da altura: é a velocidade que decide
## quem alcança quem, e com ele a onça continua entre o passo e a carreira do
## jogador — "quem vai andando é alcançado, quem corre escapa".
##
## O BOTE LEGÍVEL EM TERCEIRA PESSOA. No 2D o bicho acende e o jogador o vê de
## cima; aqui a câmera fica atrás do ombro e o bicho pode estar de lado. Então
## o aviso é três coisas juntas, do quadro em que o bote arma até a boca
## fechar: o corpo ACENDE em âmbar, ABAIXA (a cabeça que baixa do 2D), e uma
## MARCA NO CHÃO mostra até onde a mordida alcança. A marca é o que funciona
## de costas para a câmera.
##
## O JOGADOR ATRAVESSA A CRIATURA, como no 2D: quem morde é a distância, não a
## colisão. Sem a exceção de colisão, a cápsula do jogador pararia o caititu
## antes do alcance da boca e ele nunca morderia.

signal mordeu(quanto: float)
signal morreu(criatura)

## Os números do 2D, verbatim (`Criatura.ESPECIES`). Distâncias e passo em
## pixels; tempos em segundos. `corpo` e `desenho_y` do 2D ficaram de fora: são
## da folha de sprite, e aqui o corpo é `CORPO`.
const ESPECIES := {
	"caititu": {"nome": "Caititu", "vida": 12.0, "dano": 4.0, "passo": 46.0,
		"fareja": 96.0, "desiste": 176.0, "mordida": 14.0, "entre_mordidas": 0.6,
		"cai": "carne_de_caca", "quantos_caem": 1, "volta": 3, "folego": 4.0,
		"bote": 0.75, "bote_acerta": 0.55, "salto": 6.0},
	"onca": {"nome": "Onça", "vida": 36.0, "dano": 8.0, "passo": 72.0,
		"fareja": 128.0, "desiste": 224.0, "mordida": 18.0, "entre_mordidas": 0.9,
		"cai": "couro_de_onca", "quantos_caem": 1, "volta": 5, "folego": 12.0,
		"bote": 0.7, "bote_acerta": 0.6, "salto": 18.0},
	"jararaca": {"nome": "Jararaca", "vida": 8.0, "dano": 2.0, "passo": 30.0,
		"fareja": 56.0, "desiste": 112.0, "mordida": 12.0, "entre_mordidas": 1.0,
		"cai": "banha_de_jararaca", "quantos_caem": 1, "volta": 4,
		"bote": 0.55, "bote_acerta": 0.6, "salto": 10.0,
		"peconha": {"dura": 12.0, "por_segundo": 0.5}},
}

## A caixa de cada espécie, em unidades: largura, altura, comprimento (o
## comprimento aponta para a frente, +Z). Proporção de bicho, não de sprite.
const CORPO := {
	"caititu": Vector3(0.45, 0.45, 0.9),
	"onca": Vector3(0.55, 0.7, 1.5),
	"jararaca": Vector3(0.16, 0.12, 1.1),
}

## O passo do jogador no 2D, em pixels por segundo (`Jogador`). É a régua da
## escala: `u_por_px = walk_speed / PASSO_DO_JOGADOR_2D`.
const PASSO_DO_JOGADOR_2D := 62.0

const FREIO_DO_EMPURRAO := 0.16
const TEMPO_DO_PISCAR := 0.14
const TEMPO_DA_MORTE := 0.7
const TEMPO_DO_SUMICO := 0.35
## Em pixels do 2D, como lá; `_u()` converte.
const CHEGOU := 4.0
const RAIO_DO_NINHO := 64.0
const PARADA_MINIMA := 3.0
const PARADA_MAXIMA := 12.0
## O corpo abaixa até esta fração da altura enquanto arma o bote.
const ABAIXA := 0.72

const COR_DO_CORPO := Color(0.52, 0.53, 0.52)
const COR_DO_AVISO := Color(1.0, 0.62, 0.18)
const COR_DA_PANCADA := Color(0.95, 0.32, 0.28)

var especie: String = "caititu"
var vida: float = 1.0
## Está atrás do jogador agora? Ver a nota dos dois raios, no 2D.
var cacando: bool = false
## Unidades do vale por pixel do 2D. Quem cria o bicho passa o do jogador.
var u_por_px: float = 2.1 / PASSO_DO_JOGADOR_2D

var _world
var _alvo: Node3D
var _ninho: Vector3 = Vector3.ZERO
var _destino: Vector3 = Vector3.ZERO
var _parado_ate: float = 0.0
var _relogio: float = 0.0
## Tempo de FÍSICA desde a última mordida (ver a nota do 2D sobre carga).
var _desde_a_mordida: float = 100.0
var _no_bote: float = -1.0
var _bote_mordeu: bool = false
var _rumo_do_bote: Vector3 = Vector3.FORWARD
var _tonto_ate: float = 0.0
var _empurrao: Vector3 = Vector3.ZERO
var _freio: float = 0.0
var _piscar: float = 0.0
var _morrendo: float = -1.0
var _aceso: bool = false
var _rng := RandomNumberGenerator.new()

var _corpo: Node3D
var _material: StandardMaterial3D
var _marca: MeshInstance3D


func dados() -> Dictionary:
	return ESPECIES.get(especie, {})


func nome() -> String:
	return str(dados().get("nome", especie))


## Um número de distância ou passo da espécie, já no vale.
func _u(chave: String) -> float:
	return float(dados().get(chave, 0.0)) * u_por_px


## Alcance da mordida no instante de fechar, como no 2D: a boca alcança um
## terço além da mordida parada, mais o salto do bote.
func alcance_da_mordida() -> float:
	return _u("mordida") * 1.35 + _u("salto")


func configurar(world, alvo: Node3D, fator_de_escala: float) -> void:
	_world = world
	_alvo = alvo
	u_por_px = fator_de_escala
	_ninho = global_position
	_destino = global_position
	if alvo is PhysicsBody3D:
		add_collision_exception_with(alvo)


func _ready() -> void:
	_rng.randomize()
	vida = float(dados().get("vida", 1.0))
	# Camada nenhuma, máscara 1: não barra ninguém (o jogador o atravessa, e a
	# câmera não bate nele), e não atravessa casa nem barranco.
	collision_layer = 0
	collision_mask = 1
	_montar()


func _montar() -> void:
	var tamanho: Vector3 = CORPO.get(especie, Vector3(0.45, 0.45, 0.9))
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = tamanho
	forma.shape = caixa
	forma.position.y = tamanho.y * 0.5
	add_child(forma)

	_material = StandardMaterial3D.new()
	_material.albedo_color = COR_DO_CORPO
	_material.emission_enabled = true
	_material.emission = COR_DO_AVISO
	_material.emission_energy_multiplier = 0.0
	_corpo = Node3D.new()
	_corpo.name = "Corpo"
	add_child(_corpo)
	var tronco := MeshInstance3D.new()
	var malha := BoxMesh.new()
	malha.size = tamanho
	tronco.mesh = malha
	tronco.material_override = _material
	tronco.position.y = tamanho.y * 0.5
	_corpo.add_child(tronco)
	# A CABEÇA, uma caixa menor na frente: sem ela a caixa não tem frente, e o
	# bote precisa de uma — é para ela que o jogador olha.
	var cabeca := MeshInstance3D.new()
	var malha_cabeca := BoxMesh.new()
	malha_cabeca.size = Vector3(tamanho.x * 0.7, tamanho.y * 0.6, tamanho.z * 0.28)
	cabeca.mesh = malha_cabeca
	cabeca.material_override = _material
	cabeca.position = Vector3(0.0, tamanho.y * 0.62, tamanho.z * 0.5 + malha_cabeca.size.z * 0.4)
	_corpo.add_child(cabeca)

	# A MARCA NO CHÃO: do focinho até onde a mordida alcança, na largura do
	# corpo. Sem sombra e sem luz, para ler igual de dia e de noite.
	_marca = MeshInstance3D.new()
	_marca.name = "MarcaDoBote"
	var faixa := BoxMesh.new()
	var comprimento := alcance_da_mordida() + tamanho.z * 0.5
	faixa.size = Vector3(maxf(tamanho.x, 0.35), 0.02, comprimento)
	_marca.mesh = faixa
	var tinta := StandardMaterial3D.new()
	tinta.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tinta.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tinta.albedo_color = Color(COR_DO_AVISO, 0.55)
	tinta.cull_mode = BaseMaterial3D.CULL_DISABLED
	_marca.material_override = tinta
	_marca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marca.position = Vector3(0.0, 0.04, comprimento * 0.5)
	_marca.visible = false
	add_child(_marca)


# --- a pancada que o bicho leva ----------------------------------------------

## Leva pancada. `empurrao` já em unidades. Devolve true se caiu.
func ferir(quanto: float, empurrao: Vector3 = Vector3.ZERO, tonteia: float = 0.0) -> bool:
	if quanto <= 0.0 or vida <= 0.0:
		return false
	vida = maxf(0.0, vida - quanto)
	_piscar = TEMPO_DO_PISCAR
	empurrao.y = 0.0
	if empurrao.length() > 0.0:
		# Recuo que freia até parar em FREIO segundos: a velocidade de saída é
		# o dobro da média, para a distância andada dar o que foi pedido.
		_empurrao = empurrao.normalized() * (2.0 * empurrao.length() / FREIO_DO_EMPURRAO)
		_freio = _empurrao.length() / FREIO_DO_EMPURRAO
	if vida > 0.0:
		if tonteia > 0.0:
			_tonto_ate = _relogio + tonteia
			_parar_o_bote()
		return false
	_morrer()
	return true


func _morrer() -> void:
	_parar_o_bote()
	morreu.emit(self)
	_morrendo = 0.0
	cacando = false
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func tonto() -> bool:
	return _relogio < _tonto_ate


func no_bote() -> bool:
	return _no_bote >= 0.0


func avisando() -> bool:
	return _aceso


func morto() -> bool:
	return vida <= 0.0


# --- o quadro ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_relogio += delta
	_piscar_o_corpo(delta)
	if _morrendo >= 0.0:
		_cair(delta)
		return
	if _alvo == null or vida <= 0.0:
		return
	_desde_a_mordida += delta
	if _empurrao.length() > 0.5 * u_por_px:
		velocity.x = _empurrao.x
		velocity.z = _empurrao.z
		_mover(delta)
		_empurrao = _empurrao.move_toward(Vector3.ZERO, _freio * delta)
	# O FARO CORRE EM TODO QUADRO, antes do tonto e do bote (ver o 2D).
	var distancia := _plano(_alvo.global_position - global_position).length()
	_farejar(distancia)
	if tonto():
		_parar(delta)
		_corpo.rotation.z = sin(_relogio * 18.0) * 0.14
		return
	_corpo.rotation.z = 0.0
	if _no_bote >= 0.0:
		_seguir_o_bote(delta)
		return
	if cacando:
		_cacar(delta, distancia)
	else:
		_pastar(delta)


## Jogador que o mundo travou não se fareja: caça de cutscene é injustiça. No
## vale, travado é o corpo sem física — a queda e o mapa aberto param o
## jogador assim, e param o faro junto.
func _alvo_travado() -> bool:
	return not _alvo.is_physics_processing() or not _alvo.is_visible_in_tree()


func _farejar(distancia: float) -> void:
	if _alvo_travado():
		cacando = false
		return
	if cacando:
		if distancia > _u("desiste"):
			cacando = false
	elif distancia <= _u("fareja"):
		cacando = true


func _cacar(delta: float, distancia: float) -> void:
	var rumo := _plano(_alvo.global_position - global_position).normalized()
	if distancia <= _u("mordida"):
		_parar(delta)
		_virar(rumo)
		if _desde_a_mordida >= float(dados().get("entre_mordidas", 1.0)):
			_comecar_o_bote()
		return
	velocity.x = rumo.x * _u("passo")
	velocity.z = rumo.z * _u("passo")
	_mover(delta)
	_virar(rumo)


func _pastar(delta: float) -> void:
	if _plano(_destino - global_position).length() <= _u_de(CHEGOU):
		if _relogio >= _parado_ate:
			_parado_ate = _relogio + _rng.randf_range(PARADA_MINIMA, PARADA_MAXIMA)
			_destino = _ponto_perto_do_ninho()
		_parar(delta)
		return
	if _relogio < _parado_ate:
		_parar(delta)
		return
	var rumo := _plano(_destino - global_position).normalized()
	velocity.x = rumo.x * _u("passo") * 0.5
	velocity.z = rumo.z * _u("passo") * 0.5
	var antes := global_position
	_mover(delta)
	_virar(rumo)
	if global_position.distance_to(antes) < 0.2 * u_por_px:
		_destino = _ponto_perto_do_ninho()
		_parado_ate = _relogio + 1.0


func _comecar_o_bote() -> void:
	_no_bote = 0.0
	_bote_mordeu = false
	_rumo_do_bote = _plano(_alvo.global_position - global_position).normalized()
	if _rumo_do_bote == Vector3.ZERO:
		_rumo_do_bote = global_basis.z
	_virar(_rumo_do_bote)
	# Aceso JÁ no quadro em que arma: o aviso é a janela da ginga.
	_acender(true)


func _seguir_o_bote(delta: float) -> void:
	_no_bote += delta
	var dura := float(dados().get("bote", 0.5))
	var acerta := float(dados().get("bote_acerta", 0.55))
	var t := _no_bote / dura
	if t >= 0.3 and t <= 0.7:
		velocity.x = _rumo_do_bote.x * _u("salto") / (dura * 0.4)
		velocity.z = _rumo_do_bote.z * _u("salto") / (dura * 0.4)
		_mover(delta)
	else:
		_parar(delta)
	# Aceso e abaixado até a boca fechar; dali em diante, apagado e de pé.
	_acender(t < acerta)
	var altura := lerpf(1.0, ABAIXA, clampf(t / 0.3, 0.0, 1.0)) if t < acerta else 1.0
	_corpo.scale.y = altura
	if not _bote_mordeu and t >= acerta:
		_bote_mordeu = true
		_morder()
	if t >= 1.0:
		_no_bote = -1.0
		_desde_a_mordida = 0.0


func _parar_o_bote() -> void:
	_no_bote = -1.0
	_acender(false)
	if _corpo != null:
		_corpo.scale.y = 1.0


func _morder() -> void:
	if _alvo_travado():
		return
	# A GINGA CONTA ANTES DA DISTÂNCIA (ver o 2D): a esquiva bem feita conta
	# como esquiva mesmo quando o corpo já saiu do alcance.
	if Vida.livre():
		Luta.esquivou.emit(especie)
		return
	if _plano(_alvo.global_position - global_position).length() > alcance_da_mordida():
		return
	# No respiro a boca fecha no vazio, e não é esquiva.
	if Vida.respirando():
		return
	var dano := maxf(1.0, float(dados().get("dano", 0.0)) - Equipamento.bonus("defesa"))
	Vida.ferir(dano)
	mordeu.emit(dano)
	var peconha: Dictionary = dados().get("peconha", {})
	if not peconha.is_empty():
		Vida.envenenar(float(peconha.get("dura", 0.0)), float(peconha.get("por_segundo", 0.0)))


# --- corpo -------------------------------------------------------------------

func _mover(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = -0.1
	var antes := global_position
	move_and_slide()
	# Bicho da mata não entra no mar atrás de ninguém: o passo que cairia na
	# água é desfeito.
	if _world != null and not _world.is_on_land(global_position):
		global_position = antes
		velocity = Vector3.ZERO


func _parar(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= 20.0 * delta
		move_and_slide()


func _virar(rumo: Vector3) -> void:
	if rumo.length_squared() > 0.0001:
		rotation.y = atan2(rumo.x, rumo.z)


func _acender(aceso: bool) -> void:
	_aceso = aceso
	if _marca != null:
		_marca.visible = aceso
	if _material != null:
		_material.emission_energy_multiplier = 1.6 if aceso else 0.0


func _piscar_o_corpo(delta: float) -> void:
	if _piscar <= 0.0:
		return
	_piscar -= delta
	var cor := COR_DA_PANCADA if _piscar > 0.0 else COR_DO_CORPO
	_material.albedo_color = Color(cor, _material.albedo_color.a)


func _cair(delta: float) -> void:
	_morrendo += delta
	_corpo.rotation.z = lerpf(0.0, PI * 0.5, minf(1.0, _morrendo / TEMPO_DA_MORTE))
	if _morrendo > TEMPO_DA_MORTE:
		var alfa := maxf(0.0, 1.0 - (_morrendo - TEMPO_DA_MORTE) / TEMPO_DO_SUMICO)
		_material.albedo_color = Color(_material.albedo_color, alfa)
	if _morrendo >= TEMPO_DA_MORTE + TEMPO_DO_SUMICO:
		queue_free()


func _ponto_perto_do_ninho() -> Vector3:
	var raio := _u_de(RAIO_DO_NINHO)
	for i in 10:
		var ponto := _ninho + Vector3(_rng.randf_range(-raio, raio), 0.0, _rng.randf_range(-raio, raio))
		if _world == null or _world.is_on_land(ponto):
			return ponto
	return global_position


func _u_de(pixels: float) -> float:
	return pixels * u_por_px


static func _plano(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
