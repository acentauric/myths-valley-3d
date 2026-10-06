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
##
## O CORPO DO TRIPO (#28). No estilo Tripo o bicho veste o GLB do catálogo
## (`MODELOS`; a onça escolhe pela `pelagem`), e a caixa cinza fica para o
## procedural e para o GLB que ainda não chegou. Por isso o aviso e a pancada
## são `material_overlay`, e a queda é `transparency` — os três valem em
## qualquer malha, sem saber de que material ela é feita. O passo é o clipe do
## GLB com o resto por cima (`animador_bicho.gd`).
##
## A ONÇA VÊ, e não só fareja (`VISTA`, números só do 3D, em unidades do vale):
## um cone à frente, mais curto de noite, com a linha livre de casa, pedra e
## tronco; o faro do 2D continua valendo pelas costas. Quem é visto passa por
## RONDA → ESPREITA (o corpo abaixa e ela vem devagar) → CARGA → BOTE → RECUA,
## e de novo carga enquanto o vir. A COLEIRA é o território: longe demais do
## ninho, ou o jogador longe demais dela, e ela VOLTA, cega por uns segundos —
## quem foge da mata se livra dela de verdade.

const Animador = preload("res://scripts/prototipo_3d/animador_bicho.gd")

signal mordeu(quanto: float)
signal morreu(criatura)
## Viu o jogador e começou a caçar (só quem tem `VISTA`).
signal avistou(criatura)

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

## O modelo de cada espécie no catálogo (estilo Tripo). A onça tem dois, pela
## pelagem; sem pelagem, a pintada.
const MODELOS := {
	"caititu": "caititu",
	"jararaca": "jararaca",
	"onca": {"pintada": "onca_pintada", "preta": "onca_preta"},
}

## A VISTA, só do 3D e já em unidades (não é número do 2D, que só farejava):
## até onde enxerga de dia e de noite, a abertura do cone em graus, a coleira
## (`desiste`, do jogador; `territorio`, do ninho), quanto tempo espreita antes
## da carga e o raio da ronda.
const VISTA := {
	"onca": {"alcance": 16.0, "alcance_noite": 10.0, "cone": 140.0, "desiste": 26.0,
		"territorio": 34.0, "espreita": 2.0, "ronda": 9.0},
}
## De quanto em quanto tempo ela olha (s): o raio de física não é de graça.
const OLHAR_A_CADA := 0.25
## Altura dos olhos e do peito de quem é visto, para a linha.
const ALTURA_DOS_OLHOS := 0.6
const ALTURA_DO_ALVO := 0.9
## Sem ver o jogador por isto (s), volta à ronda.
const PERDE_DE_VISTA := 3.0
## Quanto tempo fica cega depois que a coleira a manda de volta (s).
const CEGA_NA_VOLTA := 6.0
## Espreitando: o corpo abaixa até esta fração e o passo cai para esta outra.
const ESPREITA_ABAIXA := 0.85
const ESPREITA_PASSO := 0.45
## Depois do bote ela se afasta um pouco antes da próxima carga (s, fração do passo).
const RECUO := 1.1
const RECUO_PASSO := 0.6
## Até onde (u) é "chegou ao ninho" na volta.
const CHEGOU_AO_NINHO := 2.0
const COR_DOS_OLHOS := Color(1.0, 0.86, 0.32)

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
## "pintada" ou "preta", para a onça; vazio para os outros.
var pelagem: String = ""
## ronda, espreita, carga, recua ou volta (só quem tem `VISTA`); ver `estado_agora`.
var estado: String = "ronda"
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
## Soneca de quem está longe do jogador (ver `_physics_process`).
const DISTANCIA_DE_SONECA := 120.0
const DECIDE_LONGE := 0.25
var _soneca := 0.0
var _aceso: bool = false
var _rng := RandomNumberGenerator.new()

var _corpo: Node3D
var _modelo: Node3D
var _animador
var _malhas: Array[GeometryInstance3D] = []
var _tinta_do_aviso: StandardMaterial3D
var _tinta_da_pancada: StandardMaterial3D
var _marca: MeshInstance3D
var _olhos: Array[MeshInstance3D] = []
var _proxima_olhada: float = 0.0
var _sem_ver: float = 0.0
var _cega_ate: float = -1.0
var _espreita_resta: float = 0.0
var _recua_resta: float = 0.0
var _ativa := true


func dados() -> Dictionary:
	return ESPECIES.get(especie, {})


func nome() -> String:
	return str(dados().get("nome", especie))


## A chave do catálogo do corpo desta criatura.
func chave_do_modelo() -> String:
	var modelo = MODELOS.get(especie, especie)
	if modelo is Dictionary:
		return str(modelo.get(pelagem, modelo.values()[0]))
	return str(modelo)


func tem_vista() -> bool:
	return VISTA.has(especie)


func vista() -> Dictionary:
	return VISTA.get(especie, {})


## O que ela está fazendo agora: o estado, ou "bote" no meio dele.
func estado_agora() -> String:
	return "bote" if no_bote() else estado


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

	_corpo = Node3D.new()
	_corpo.name = "Corpo"
	add_child(_corpo)
	# A POSE fica entre o corpo e o modelo: o animador mexe nela (respirar,
	# abaixar, inclinar), e o bote e a queda continuam mexendo no corpo.
	var pose := Node3D.new()
	pose.name = "Pose"
	_corpo.add_child(pose)
	# A caixa tem cabeça na frente: sem ela não teria frente, e o bote precisa
	# de uma — é para ela que o jogador olha.
	var chave := chave_do_modelo()
	_modelo = Animador.vestir(chave, pose, tamanho, COR_DO_CORPO)
	_animador = Animador.new()
	_animador.name = "Animador"
	add_child(_animador)
	_animador.configurar(pose, _modelo, false, chave, _u("passo"))
	_malhas = Animador.malhas(_modelo)
	# O AVISO e a PANCADA por cima de qualquer malha, sem luz: o âmbar lê igual
	# de dia e de noite, e na onça-preta também.
	_tinta_do_aviso = _tinta_por_cima(COR_DO_AVISO, 0.5)
	_tinta_da_pancada = _tinta_por_cima(COR_DA_PANCADA, 0.6)
	if pelagem == "preta":
		_montar_os_olhos(tamanho)

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


func _tinta_por_cima(cor: Color, alfa: float) -> StandardMaterial3D:
	var tinta := StandardMaterial3D.new()
	tinta.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tinta.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tinta.albedo_color = Color(cor, alfa)
	return tinta


## OS OLHOS DA ONÇA-PRETA, que brilham de noite. Sem eles ela é invisível no
## escuro, e o bote de quem não se vê não tem aviso — é injusto. No GLB eles
## seguem o osso da cabeça (o último `Head`); na caixa, a frente da cabeça.
func _montar_os_olhos(tamanho: Vector3) -> void:
	var tinta := StandardMaterial3D.new()
	tinta.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tinta.albedo_color = COR_DOS_OLHOS
	tinta.emission_enabled = true
	tinta.emission = COR_DOS_OLHOS
	tinta.emission_energy_multiplier = 3.0
	var bola := SphereMesh.new()
	bola.radius = 0.028
	bola.height = 0.05
	bola.radial_segments = 8
	bola.rings = 4
	var centro := Vector3(0.0, tamanho.y * 0.66, tamanho.z * 0.5 + tamanho.z * 0.2)
	var lado := 0.055
	var esqueleto: Skeleton3D = null
	var cabeca := -1
	var esqueletos := _modelo.find_children("*", "Skeleton3D", true, false)
	if not esqueletos.is_empty():
		esqueleto = esqueletos[0] as Skeleton3D
		var maior := -1
		for i in esqueleto.get_bone_count():
			var nome_do_osso := esqueleto.get_bone_name(i)
			if "Head_" in nome_do_osso:
				var numero := nome_do_osso.get_slice("Head_", 1).to_int()
				if numero > maior:
					maior = numero
					cabeca = i
	var pai: Node3D = _corpo
	var osso := Transform3D.IDENTITY
	if cabeca >= 0:
		var preso := BoneAttachment3D.new()
		preso.name = "Olhos"
		esqueleto.add_child(preso)
		preso.bone_idx = cabeca
		pai = preso
		# O osso no referencial do bicho; os olhos vão um pouco acima e à frente
		# dele, e voltam para o referencial do osso para segui-lo no passo.
		osso = esqueleto.global_transform * esqueleto.get_bone_global_pose(cabeca)
		var comprimento := tamanho.z * 1.4
		centro = global_transform.affine_inverse() * osso.origin + Vector3(0.0, comprimento * 0.02, comprimento * 0.02)
		lado = comprimento * 0.024
	for x in [-lado, lado]:
		var olho := MeshInstance3D.new()
		olho.name = "Olho"
		olho.mesh = bola
		olho.material_override = tinta
		olho.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pai.add_child(olho)
		var no_bicho: Vector3 = centro + Vector3(x, 0.0, 0.0)
		if cabeca >= 0:
			# Do referencial do bicho para o do osso, sem a escala dele.
			var local := osso.affine_inverse() * (global_transform * no_bicho)
			olho.transform = Transform3D(Basis(), local)
			olho.scale = Vector3.ONE / maxf(osso.basis.get_scale().x, 0.001)
		else:
			olho.position = no_bicho
		olho.visible = false
		_olhos.append(olho)


func olhos_acesos() -> bool:
	return not _olhos.is_empty() and _olhos[0].visible


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
	estado = "ronda"


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
	var distancia := _plano(_alvo.global_position - global_position).length()
	# Longe demais do jogador (ninguém vê), sem caçar, sem bote, sem empurrão: não anda
	# nem pasta. Só decide a cada 0,25 s se algo mudou, e não chama `_mover` (física
	# de corpo que custava até 1,5 ms por tick).
	if not cacando and _no_bote < 0.0 and _empurrao.length() <= 0.5 * u_por_px \
			and distancia > DISTANCIA_DE_SONECA:
		_soneca += delta
		_animador.velocidade = 0.0
		if _soneca < DECIDE_LONGE:
			return
		_olhar_ou_farejar(_soneca, distancia)
		_soneca = 0.0
		return
	_soneca = 0.0
	if _empurrao.length() > 0.5 * u_por_px:
		velocity.x = _empurrao.x
		velocity.z = _empurrao.z
		_mover(delta)
		_empurrao = _empurrao.move_toward(Vector3.ZERO, _freio * delta)
	# O FARO CORRE EM TODO QUADRO, antes do tonto e do bote (ver o 2D). Quem
	# tem vista olha, e o faro entra no olhar (`enxerga`).
	_olhar_ou_farejar(delta, distancia)
	if tonto():
		_parar(delta)
		_corpo.rotation.z = sin(_relogio * 18.0) * 0.14
		return
	_corpo.rotation.z = 0.0
	if _no_bote >= 0.0:
		_seguir_o_bote(delta)
		return
	if tem_vista():
		_cacar_com_os_olhos(delta, distancia)
	elif cacando:
		_cacar(delta, distancia)
	else:
		_pastar(delta)


func _olhar_ou_farejar(delta: float, distancia: float) -> void:
	if tem_vista():
		_olhar(delta)
	else:
		_farejar(distancia)


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


func _cacar(delta: float, distancia: float, fracao_do_passo: float = 1.0) -> void:
	var rumo := _plano(_alvo.global_position - global_position).normalized()
	if distancia <= _u("mordida"):
		_parar(delta)
		_virar(rumo)
		if _desde_a_mordida >= float(dados().get("entre_mordidas", 1.0)):
			_comecar_o_bote()
		return
	velocity.x = rumo.x * _u("passo") * fracao_do_passo
	velocity.z = rumo.z * _u("passo") * fracao_do_passo
	_mover(delta)
	_virar(rumo)


# --- a vista (onça) ------------------------------------------------------------

## ENXERGA o ponto? Dentro do alcance (mais curto de noite) e do cone da
## frente, ou a menos do faro do 2D por qualquer lado — e, nos dois casos, com
## a linha livre. Cega na volta da coleira.
func enxerga(ponto: Vector3) -> bool:
	if _relogio < _cega_ate:
		return false
	var v := vista()
	var para := _plano(ponto - global_position)
	var d := para.length()
	if d > _u("fareja"):
		var alcance := float(v.get("alcance_noite", 10.0)) if Dia.eh_noite() else float(v.get("alcance", 16.0))
		if d > alcance:
			return false
		var frente := _plano(global_basis.z).normalized()
		if d > 0.01 and frente.dot(para / d) < cos(deg_to_rad(float(v.get("cone", 140.0)) * 0.5)):
			return false
	return linha_livre(ponto)


## A LINHA LIVRE dos olhos ao peito: um raio na camada 1 (casa, pedra, chão, e
## os troncos que têm colisão perto do jogador) e, só lendo, a grade de troncos
## da região — longe do jogador a mata tem só um punhado de colisões de tronco.
func linha_livre(ponto: Vector3) -> bool:
	var de := global_position + Vector3.UP * ALTURA_DOS_OLHOS
	var ate := ponto + Vector3.UP * ALTURA_DO_ALVO
	if is_inside_tree():
		var pergunta := PhysicsRayQueryParameters3D.create(de, ate, 1)
		var fora: Array[RID] = [get_rid()]
		if _alvo is CollisionObject3D:
			fora.append((_alvo as CollisionObject3D).get_rid())
		pergunta.exclude = fora
		if not get_world_3d().direct_space_state.intersect_ray(pergunta).is_empty():
			return false
	return not _tronco_no_caminho(de, ate)


func _tronco_no_caminho(de: Vector3, ate: Vector3) -> bool:
	var regiao = _world.get("_region") if _world != null else null
	if regiao == null:
		return false
	regiao._garantir_grade_troncos()
	var a := Vector2(de.x, de.z)
	var b := Vector2(ate.x, ate.z)
	var celula: float = regiao.CELULA_TRONCOS
	var grade: Dictionary = regiao._grade_troncos
	for cx in range(floori((minf(a.x, b.x) - 1.0) / celula), floori((maxf(a.x, b.x) + 1.0) / celula) + 1):
		for cy in range(floori((minf(a.y, b.y) - 1.0) / celula), floori((maxf(a.y, b.y) + 1.0) / celula) + 1):
			for i: int in grade.get(Vector2i(cx, cy), []):
				var tronco: Dictionary = regiao._tree_trunks[i]
				if bool(tronco.get("cortado", false)):
					continue
				var pe: Vector2 = tronco["point"]
				# O pé de quem olha e o de quem é olhado não tapam a vista.
				if pe.distance_to(a) < 0.5 or pe.distance_to(b) < 0.5:
					continue
				if Geometry2D.get_closest_point_to_segment(pe, a, b).distance_to(pe) < float(tronco["radius"]):
					return true
	return false


func _olhar(delta: float) -> void:
	if _alvo_travado():
		if cacando:
			_perder_de_vista()
		return
	_proxima_olhada -= delta
	if _proxima_olhada > 0.0:
		return
	_proxima_olhada = OLHAR_A_CADA
	_atualizar_os_olhos()
	if estado == "volta":
		return
	if enxerga(_alvo.global_position):
		_sem_ver = 0.0
		if estado == "ronda":
			estado = "espreita"
			_espreita_resta = float(vista().get("espreita", 2.0))
			cacando = true
			avistou.emit(self)
	elif cacando:
		_sem_ver += OLHAR_A_CADA


func _atualizar_os_olhos() -> void:
	var acesos := Dia.eh_noite() and _morrendo < 0.0
	for olho in _olhos:
		olho.visible = acesos


func _perder_de_vista() -> void:
	cacando = false
	estado = "ronda"
	_sem_ver = 0.0
	_animador.abaixar(1.0)


## A COLEIRA: volta ao ninho, cega por `CEGA_NA_VOLTA` segundos.
func voltar_ao_ninho() -> void:
	cacando = false
	estado = "volta"
	_sem_ver = 0.0
	_cega_ate = _relogio + CEGA_NA_VOLTA
	_animador.abaixar(1.0)


func cega() -> bool:
	return _relogio < _cega_ate


func _cacar_com_os_olhos(delta: float, distancia: float) -> void:
	var v := vista()
	if estado in ["espreita", "carga", "recua"]:
		if _plano(global_position - _ninho).length() > float(v.get("territorio", 34.0)) \
				or distancia > float(v.get("desiste", 26.0)):
			voltar_ao_ninho()
		elif _sem_ver >= PERDE_DE_VISTA:
			_perder_de_vista()
	match estado:
		"espreita":
			# ABAIXADA, devagar: o tempo de o jogador perceber e decidir.
			_animador.abaixar(ESPREITA_ABAIXA)
			_espreita_resta -= delta
			if _espreita_resta <= 0.0:
				estado = "carga"
			_cacar(delta, distancia, ESPREITA_PASSO)
		"carga":
			_animador.abaixar(1.0)
			_cacar(delta, distancia)
		"recua":
			# Depois do bote ela se afasta um passo, de frente para quem caça.
			_recua_resta -= delta
			var de_costas := _plano(global_position - _alvo.global_position).normalized()
			velocity.x = de_costas.x * _u("passo") * RECUO_PASSO
			velocity.z = de_costas.z * _u("passo") * RECUO_PASSO
			_mover(delta)
			_virar(-de_costas)
			if _recua_resta <= 0.0:
				estado = "carga"
		"volta":
			var para := _plano(_ninho - global_position)
			if para.length() <= CHEGOU_AO_NINHO:
				estado = "ronda"
				_parar(delta)
				return
			velocity.x = para.normalized().x * _u("passo")
			velocity.z = para.normalized().z * _u("passo")
			var antes := global_position
			_mover(delta)
			_virar(para)
			# Presa (casa, barranco, beira d'água): volta pelo caminho que não há.
			if global_position.distance_to(antes) < 0.002:
				global_position = _ninho
		_:
			_pastar(delta, float(v.get("ronda", 9.0)))


func _pastar(delta: float, raio: float = -1.0) -> void:
	if _plano(_destino - global_position).length() <= _u_de(CHEGOU):
		if _relogio >= _parado_ate:
			_parado_ate = _relogio + _rng.randf_range(PARADA_MINIMA, PARADA_MAXIMA)
			_destino = _ponto_perto_do_ninho(raio)
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
		_destino = _ponto_perto_do_ninho(raio)
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
		if tem_vista() and cacando:
			estado = "recua"
			_recua_resta = RECUO


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
	_animador.velocidade = Vector2(velocity.x, velocity.z).length()


func _parar(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_animador.velocidade = 0.0
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
	_pintar_por_cima()


## O que vai por cima da malha agora: a pancada pisca por cima de tudo; o
## aviso fica enquanto o bote está armado.
func _pintar_por_cima() -> void:
	var tinta: Material = null
	if _piscar > 0.0:
		tinta = _tinta_da_pancada
	elif _aceso:
		tinta = _tinta_do_aviso
	for malha in _malhas:
		if is_instance_valid(malha):
			malha.material_overlay = tinta


## A tinta que está por cima do corpo agora (nula, a do aviso ou a da pancada).
func tinta_por_cima() -> Material:
	return _malhas[0].material_overlay if not _malhas.is_empty() else null


func _piscar_o_corpo(delta: float) -> void:
	if _piscar <= 0.0:
		return
	_piscar -= delta
	_pintar_por_cima()


func _cair(delta: float) -> void:
	_morrendo += delta
	_corpo.rotation.z = lerpf(0.0, PI * 0.5, minf(1.0, _morrendo / TEMPO_DA_MORTE))
	if _morrendo > TEMPO_DA_MORTE:
		# A transparência da instância, e não do material: vale para qualquer GLB.
		var alfa := maxf(0.0, 1.0 - (_morrendo - TEMPO_DA_MORTE) / TEMPO_DO_SUMICO)
		for malha in _malhas:
			if is_instance_valid(malha):
				malha.transparency = 1.0 - alfa
		for olho in _olhos:
			olho.visible = false
	if _morrendo >= TEMPO_DA_MORTE + TEMPO_DO_SUMICO:
		queue_free()


## Liga e desliga a criatura sem tirá-la do vale (a onça-preta só anda do
## entardecer à madrugada): some, para de pensar e volta ao ninho.
func ativar(ligada: bool) -> void:
	if ligada == _ativa:
		return
	_ativa = ligada
	visible = ligada
	set_physics_process(ligada)
	_parar_o_bote()
	cacando = false
	estado = "ronda"
	velocity = Vector3.ZERO
	if ligada:
		global_position = _ninho
		_destino = _ninho


## Anda agora? Pela chave própria, e não pela física: o portão desliga a
## física do bicho para pô-lo à mão, e ele continua no vale.
func ativa() -> bool:
	return _ativa


func _ponto_perto_do_ninho(raio: float = -1.0) -> Vector3:
	if raio <= 0.0:
		raio = _u_de(RAIO_DO_NINHO)
	for i in 10:
		var ponto := _ninho + Vector3(_rng.randf_range(-raio, raio), 0.0, _rng.randf_range(-raio, raio))
		if _world == null or _world.is_on_land(ponto):
			return ponto
	return global_position


func _u_de(pixels: float) -> float:
	return pixels * u_por_px


static func _plano(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
