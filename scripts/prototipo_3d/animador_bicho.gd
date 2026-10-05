extends Node
## O ANIMADOR DOS BICHOS: o que o GLB traz e o que o Godot põe por cima.
##
## Os quadrúpedes do Tripo vêm com um clipe só, `preset:quadruped:walk`, andando
## no lugar (a raiz não sai do ponto). As aves vêm paradas, sem esqueleto. O
## resto é procedural, e mexe só no nó POSE — o que fica entre o corpo do bicho
## e o modelo —, para não brigar com quem é dono do corpo (o bote da onça
## abaixa o corpo; a tontura e a queda o deitam de lado):
##
##   - ANDAR é o clipe, na velocidade do chão: a passada do clipe é medida pelos
##     pés uma vez por modelo (como no `authored_animator`, mas os pés aqui são
##     as pontas dos ossos `Limb`, e não `*foot`), e a reprodução acompanha o
##     deslocamento para a pata não escorregar.
##   - PARADO é o mesmo clipe congelado num quadro, com a respiração por cima.
##   - CORRER é o clipe acelerado até 2,2× e o corpo inclinado para a frente.
##   - ESPREITAR é o corpo abaixado (`abaixar`), que a onça usa antes da carga.
##   - Ave não tem clipe: anda gingando e saltitando, BICA (inclina em volta do
##     pé), e no SUSTO pula estufada.
##
## Sem clipe (a caixa cinza do procedural, ou um GLB que ainda não chegou), o
## quadrúpede anda com o balanço do passo — a mesma leitura, sem perna.
##
## O CLIPE TORTO. Em três modelos do Tripo (`CLIPE_QUEBRADO`) o clipe de andar
## não casa com o esqueleto do GLB: tocado, ele dobra a frente do corpo para
## cima (o cão caramelo chuta o ar, a onça vira girafa). Nesses o clipe nem
## toca; as PERNAS são do código: o osso de cima de cada perna balança em volta
## do eixo esquerda-direita do bicho (diagonais juntas, como no trote) e o osso
## de baixo dobra quando a perna vai à frente. O eixo é o do bicho, e não o do
## osso: serve a qualquer esqueleto do Tripo, e a mesma conta vale para todos.

## Até quanto o clipe acelera antes de a corrida virar só inclinação.
const ACELERA_ATE := 2.2
## Abaixo disto (u/s) o bicho está parado.
const PARADO_ABAIXO := 0.08
## Respiração parado: amplitude da escala e o ritmo (rad/s).
const RESPIRA := 0.014
const RITMO_DA_RESPIRACAO := 2.3
## Inclinação máxima na corrida (rad), e a velocidade relativa em que começa.
const INCLINA_NA_CORRIDA := 0.09
const CORRIDA_A_PARTIR := 1.35
## O bicar: ângulo (rad) e duração (s).
const BICA := deg_to_rad(35.0)
const DURA_O_BICAR := 0.42

## Os modelos de quadrúpede cujo clipe de andar vem torto (ver o cabeçalho): a
## perna deles é do código. Os outros (gatos, porco, cabra, bode, jumento,
## caititu, cão malhado) andam com o clipe do GLB.
const CLIPE_QUEBRADO := ["cachorro_caramelo", "onca_pintada", "onca_preta"]
## O balanço da perna (rad): base, o que cresce com a velocidade relativa e o teto;
## quanto o osso de baixo dobra na perna que vai à frente; e a frequência (Hz)
## no passo da espécie.
const PERNA_BALANCO := Vector3(0.30, 0.14, 0.52)
const PERNA_DOBRA := 0.65
const PERNA_HZ := 1.7
const PERNA_VOLTA := 8.0

## As caixas das casas, em cache: bicho e ave perguntam "isto é dentro de uma
## casa?" a cada passo, e a conta por grupo (transformada inversa de cada casa)
## custava mais que o passo. A casa não anda; o cache refaz quando muda o número
## de casas.
static var _caixas_das_casas: Array[Dictionary] = []
static var _quantas_casas := -1

## Passada medida (u/s com o clipe em 1×), por chave do catálogo: medir custa
## 48 poses do esqueleto, e todo galo do vale é o mesmo galo.
static var _passadas: Dictionary = {}

var pose: Node3D
var modelo: Node3D
var ave := false
var animacao: AnimationPlayer
## Passada de referência sem clipe, ou quando a medida falha (u/s a 1×).
var passada := 1.0
## Velocidade de agora, posta por quem anda.
var velocidade := 0.0
## Para onde a altura do corpo vai (1 de pé; 0,85 espreitando).
var altura_alvo := 1.0

var _clipe := ""
var _tempo := 0.0
var _fase := 0.0
var _bicando := -1.0
var _angulo_do_bicar := BICA
var _susto := -1.0
var _tremor := 0.0
var _parado_no_quadro := false
## As pernas do bicho de clipe torto: {osso, joelho, fase, repouso, repouso_joelho, pai}.
var _pernas: Array[Dictionary] = []
var _esqueleto: Skeleton3D
var _forca_da_perna := 0.0
var _giro_da_perna := 0.0


## `pose` é o nó que este animador mexe; `modelo`, o que está dentro dele (o GLB
## ou a caixa). `chave` é a do catálogo, para guardar a passada medida.
func configurar(nova_pose: Node3D, novo_modelo: Node3D, eh_ave: bool, chave: String, passada_padrao: float) -> void:
	pose = nova_pose
	modelo = novo_modelo
	ave = eh_ave
	passada = passada_padrao
	_fase = randf() * TAU
	if modelo == null:
		return
	if chave in CLIPE_QUEBRADO and not ave:
		_achar_as_pernas()
		return
	var tocadores := modelo.find_children("*", "AnimationPlayer", true, false)
	if tocadores.is_empty():
		return
	animacao = tocadores[0] as AnimationPlayer
	for nome: StringName in animacao.get_animation_list():
		if "walk" in String(nome).to_lower() or "march" in String(nome).to_lower():
			_clipe = String(nome)
			break
	if _clipe.is_empty():
		animacao = null
		return
	animacao.get_animation(_clipe).loop_mode = Animation.LOOP_LINEAR
	animacao.play(_clipe)
	# Cada bicho num ponto do passo: dois cães lado a lado não marcham juntos.
	animacao.seek(randf() * animacao.get_animation(_clipe).length, true)
	if _passadas.has(chave):
		passada = float(_passadas[chave])
	else:
		var medida := _medir_passada()
		if medida > 0.05:
			passada = medida
		_passadas[chave] = passada


func tem_clipe() -> bool:
	return animacao != null


## `p` está dentro da caixa de alguma casa (`AlvoCasa`, `house_bounds`), com
## `folga` de cada lado?
static func dentro_de_casa(arvore: SceneTree, p: Vector3, folga: float = 0.0) -> bool:
	var quantas := arvore.get_node_count_in_group("interactive_house")
	if quantas != _quantas_casas:
		_quantas_casas = quantas
		_caixas_das_casas.clear()
		for alvo in arvore.get_nodes_in_group("interactive_house"):
			_caixas_das_casas.append({"inversa": (alvo as Node3D).global_transform.affine_inverse(),
				"caixa": alvo.get_meta("house_bounds", Vector3.ZERO)})
	for c in _caixas_das_casas:
		var caixa: Vector3 = c["caixa"]
		var local: Vector3 = (c["inversa"] as Transform3D) * p
		if absf(local.x) < caixa.x * 0.5 + folga and absf(local.z) < caixa.z * 0.5 + folga:
			return true
	return false


## Esquece as casas em cache (o vale refez as casas).
static func esquecer_as_casas() -> void:
	_quantas_casas = -1
	_caixas_das_casas.clear()


## Anda com as pernas do código (o clipe do modelo vem torto)?
func tem_pernas() -> bool:
	return not _pernas.is_empty()


## AS PERNAS DO ESQUELETO: a raiz de cada cadeia `Limb` (cujo pai não é `Limb`)
## é o osso de cima; o filho `Limb` dele, o de baixo. A fase vem da posição de
## repouso no referencial do bicho: pernas na mesma diagonal (frente×lado igual)
## andam juntas.
func _achar_as_pernas() -> void:
	var esqueletos := modelo.find_children("*", "Skeleton3D", true, false)
	if esqueletos.is_empty():
		return
	_esqueleto = esqueletos[0] as Skeleton3D
	var para_o_bicho := pose.global_transform.affine_inverse() * _esqueleto.global_transform
	for i in _esqueleto.get_bone_count():
		if not "limb" in _esqueleto.get_bone_name(i).to_lower():
			continue
		var pai := _esqueleto.get_bone_parent(i)
		if pai >= 0 and "limb" in _esqueleto.get_bone_name(pai).to_lower():
			continue
		var joelho := -1
		for filho in _esqueleto.get_bone_children(i):
			if "limb" in _esqueleto.get_bone_name(filho).to_lower():
				joelho = filho
				break
		var onde: Vector3 = para_o_bicho * _esqueleto.get_bone_global_rest(i).origin
		var diagonal := signf(onde.x) * signf(onde.z)
		_pernas.append({"osso": i, "joelho": joelho, "fase": 0.0 if diagonal >= 0.0 else PI,
			"repouso": _esqueleto.get_bone_rest(i).basis.orthonormalized().get_rotation_quaternion(),
			"repouso_joelho": _esqueleto.get_bone_rest(joelho).basis.orthonormalized().get_rotation_quaternion() if joelho >= 0 else Quaternion.IDENTITY,
			"pai": _esqueleto.get_bone_global_rest(pai).basis.orthonormalized().get_rotation_quaternion() if pai >= 0 else Quaternion.IDENTITY,
			"pai_do_joelho": _esqueleto.get_bone_global_rest(i).basis.orthonormalized().get_rotation_quaternion()})


## O balanço de uma perna: gira o osso em volta do eixo esquerda-direita do bicho
## (passado ao referencial do esqueleto), por cima do repouso.
func _balancar_as_pernas(delta: float, andando: bool, relativa: float) -> void:
	if _esqueleto == null or not is_instance_valid(_esqueleto):
		return
	var alvo := 0.0
	if andando:
		alvo = clampf(PERNA_BALANCO.x + PERNA_BALANCO.y * relativa, 0.0, PERNA_BALANCO.z)
	_forca_da_perna = move_toward(_forca_da_perna, alvo, delta * PERNA_VOLTA)
	if _forca_da_perna <= 0.001 and not andando:
		if _giro_da_perna != 0.0:
			for perna in _pernas:
				_esqueleto.set_bone_pose_rotation(perna["osso"], perna["repouso"])
				if perna["joelho"] >= 0:
					_esqueleto.set_bone_pose_rotation(perna["joelho"], perna["repouso_joelho"])
			_giro_da_perna = 0.0
		return
	_giro_da_perna += delta * TAU * PERNA_HZ * clampf(relativa, 0.45, 2.4)
	var eixo: Vector3 = (_esqueleto.global_basis.inverse() * (pose.global_basis * Vector3.RIGHT)).normalized()
	for perna in _pernas:
		var fase: float = _giro_da_perna + float(perna["fase"])
		var pai: Quaternion = perna["pai"]
		var giro := Quaternion(eixo, _forca_da_perna * sin(fase))
		_esqueleto.set_bone_pose_rotation(perna["osso"], pai.inverse() * giro * pai * (perna["repouso"] as Quaternion))
		if perna["joelho"] >= 0:
			# A perna que vai à frente (cos < 0) dobra o osso de baixo para trás.
			var dobra := PERNA_DOBRA * maxf(0.0, -cos(fase)) * (_forca_da_perna / PERNA_BALANCO.z)
			var no_osso: Quaternion = perna["pai_do_joelho"]
			_esqueleto.set_bone_pose_rotation(perna["joelho"],
				no_osso.inverse() * Quaternion(eixo, dobra) * no_osso * (perna["repouso_joelho"] as Quaternion))


## O CORPO DE UM BICHO, nos dois estilos e sem misturar: no Tripo, o GLB do
## catálogo; sem ele (o procedural, ou um GLB que ainda não chegou), a caixa na
## medida `caixa` (largura, altura, comprimento) com a cabeça à frente, +Z.
## Toda malha some a `alcance` u da câmera (`visibility_range_end`): bicho de
## quintal não se vê do outro lado da vila.
static func vestir(chave: String, onde: Node3D, caixa: Vector3, cor: Color, alcance: float = 0.0, tamanho: float = 1.0) -> Node3D:
	var vestido: Node3D = null
	if Estilo.tripo() and CatalogoAssets.tem_tripo(chave):
		vestido = CatalogoAssets.instanciar(chave, onde, Vector3.ZERO, tamanho)
	if vestido == null:
		vestido = caixa_de_bicho(caixa * tamanho, cor)
		onde.add_child(vestido)
	if alcance > 0.0:
		for malha in malhas(vestido):
			malha.visibility_range_end = alcance
			malha.visibility_range_end_margin = 4.0
			malha.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return vestido


## A caixa cinza dos bichos (a do caititu): tronco e cabeça, sem sombra de luxo.
static func caixa_de_bicho(tamanho: Vector3, cor: Color) -> Node3D:
	var corpo := Node3D.new()
	corpo.name = "Caixa"
	var tinta := StandardMaterial3D.new()
	tinta.albedo_color = cor
	var tronco := MeshInstance3D.new()
	var malha := BoxMesh.new()
	malha.size = tamanho
	tronco.mesh = malha
	tronco.material_override = tinta
	tronco.position.y = tamanho.y * 0.5
	corpo.add_child(tronco)
	var cabeca := MeshInstance3D.new()
	var malha_cabeca := BoxMesh.new()
	malha_cabeca.size = Vector3(tamanho.x * 0.7, tamanho.y * 0.6, tamanho.z * 0.28)
	cabeca.mesh = malha_cabeca
	cabeca.material_override = tinta
	cabeca.position = Vector3(0.0, tamanho.y * 0.62, tamanho.z * 0.5 + malha_cabeca.size.z * 0.4)
	corpo.add_child(cabeca)
	return corpo


static func malhas(no: Node) -> Array[GeometryInstance3D]:
	var lista: Array[GeometryInstance3D] = []
	if no is GeometryInstance3D:
		lista.append(no)
	for filho in no.find_children("*", "GeometryInstance3D", true, false):
		lista.append(filho as GeometryInstance3D)
	return lista


## Ave bica o chão (ou o que estiver na frente do bico); o porco fuça, com um
## ângulo menor.
func bicar(angulo: float = BICA) -> void:
	if _bicando < 0.0 and _susto < 0.0:
		_bicando = 0.0
		_angulo_do_bicar = angulo


func bicando() -> bool:
	return _bicando >= 0.0


## Pulo estufado: o susto de quem foi espantado.
func assustar() -> void:
	_susto = 0.0
	_bicando = -1.0


## Treme o corpo por `segundos` (o pavão abrindo o leque).
func tremer(segundos: float) -> void:
	_tremor = segundos


func abaixar(fracao: float) -> void:
	altura_alvo = fracao


func _process(delta: float) -> void:
	if pose == null or not pose.is_visible_in_tree():
		return
	_tempo += delta
	var relativa := velocidade / maxf(passada, 0.05)
	var andando := velocidade > PARADO_ABAIXO
	var y := 0.0
	var inclina := 0.0
	var ginga := 0.0
	var escala_y := lerpf(pose.scale.y, altura_alvo, minf(1.0, delta * 6.0))
	if animacao != null:
		if andando:
			if _parado_no_quadro or not animacao.is_playing():
				animacao.play(_clipe)
				_parado_no_quadro = false
			animacao.speed_scale = clampf(relativa, 0.45, ACELERA_ATE)
		elif not _parado_no_quadro:
			# Congelado no quadro em que parou: a pata não volta ao ponto zero.
			animacao.pause()
			_parado_no_quadro = true
	elif not _pernas.is_empty():
		# O clipe torto não toca: as pernas são do código, e o corpo sobe e desce
		# duas vezes por passada, de leve.
		_balancar_as_pernas(delta, andando, relativa)
		if andando:
			y = absf(sin(_giro_da_perna)) * 0.018
	elif andando:
		# O balanço do passo, sem perna: sobe e desce duas vezes por passada.
		_fase += delta * TAU * clampf(relativa, 0.5, 3.0) * (2.4 if ave else 1.6)
		y = absf(sin(_fase)) * (0.035 if ave else 0.03)
		ginga = sin(_fase) * (0.09 if ave else 0.03)
	if andando and relativa > CORRIDA_A_PARTIR:
		inclina = INCLINA_NA_CORRIDA * clampf((relativa - CORRIDA_A_PARTIR) / 0.8, 0.0, 1.0)
	var escala_xz := 1.0
	if not andando:
		# A respiração: o peito sobe e alarga, devagar.
		var respiro := sin(_tempo * RITMO_DA_RESPIRACAO + _fase) * RESPIRA
		escala_y *= 1.0 + respiro
		escala_xz = 1.0 + respiro * 0.5
	if _bicando >= 0.0:
		_bicando += delta
		var t := _bicando / DURA_O_BICAR
		inclina += _angulo_do_bicar * sin(clampf(t, 0.0, 1.0) * PI)
		if t >= 1.0:
			_bicando = -1.0
	if _susto >= 0.0:
		_susto += delta
		var s := clampf(_susto / 0.35, 0.0, 1.0)
		y += sin(s * PI) * 0.22
		escala_xz *= 1.0 + sin(s * PI) * 0.18
		if s >= 1.0:
			_susto = -1.0
	if _tremor > 0.0:
		_tremor -= delta
		ginga += sin(_tempo * 55.0) * 0.035
	pose.position.y = y
	pose.rotation = Vector3(inclina, 0.0, ginga)
	pose.scale = Vector3(escala_xz, escala_y, escala_xz)


## A PASSADA DO CLIPE pelos pés: quanto o pé de apoio anda para trás, por
## segundo, enquanto está no chão. Pés são as pontas das cadeias `Limb`.
func _medir_passada() -> float:
	var esqueletos := modelo.find_children("*", "Skeleton3D", true, false)
	if esqueletos.is_empty() or not animacao.is_inside_tree():
		return 0.0
	var esqueleto := esqueletos[0] as Skeleton3D
	var pes: Array[int] = []
	for i in esqueleto.get_bone_count():
		if not "limb" in esqueleto.get_bone_name(i).to_lower():
			continue
		var ponta := true
		for filho in esqueleto.get_bone_children(i):
			if "limb" in esqueleto.get_bone_name(filho).to_lower():
				ponta = false
		if ponta:
			pes.append(i)
	if pes.size() < 2:
		return 0.0
	var clipe := animacao.get_animation(_clipe)
	var amostras := 48
	var passo_tempo := clipe.length / amostras
	var referencia := pose.global_transform.affine_inverse()
	var caminhos: Array = []
	for pe in pes:
		caminhos.append(PackedVector3Array())
	for k in amostras + 1:
		animacao.seek(k * passo_tempo, true)
		for j in pes.size():
			var global := esqueleto.global_transform * esqueleto.get_bone_global_pose(pes[j]).origin
			caminhos[j].append(referencia * global)
	animacao.seek(0.0, true)
	# No referencial do bicho a frente é +Z: o pé de apoio anda em Z.
	var velocidades: Array[float] = []
	for caminho: PackedVector3Array in caminhos:
		var baixo := INF
		var alto := -INF
		for p in caminho:
			baixo = minf(baixo, p.y)
			alto = maxf(alto, p.y)
		var soma := 0.0
		var n := 0
		for k in range(1, caminho.size() - 1):
			if caminho[k].y < baixo + (alto - baixo) * 0.2:
				soma += absf(caminho[k + 1].z - caminho[k - 1].z) / (2.0 * passo_tempo)
				n += 1
		if n > 0:
			velocidades.append(soma / n)
	if velocidades.is_empty():
		return 0.0
	velocidades.sort()
	return velocidades[int(velocidades.size() * 0.5)]
