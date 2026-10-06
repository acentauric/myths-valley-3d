extends Node
## O ANIMADOR DOS BICHOS: o que o GLB traz e o que o Godot põe por cima.
##
## OS QUADRÚPEDES DO TRIPO ANDAM COM AS PERNAS DO CÓDIGO (#109). O GLB traz um
## clipe só, `preset:quadruped:walk`, retargetado pelo auto-rig do Studio — e
## o auto-rig erra o nome dos ossos em quase todo modelo (a sonda de 06/10):
## cadeias `Limb` que param no meio da perna (o pé fica num osso sem nome, que
## o clipe não move), pernas inteiras sem nome, e no pior caso um pescoço
## batizado de perna (a onça pintada "virava girafa", o cão caramelo "chutava o
## ar"). O clipe só mexe o que tem nome: toda perna de nome errado ficava dura,
## e "todos os bichos mancavam". Três modelos já estavam numa lista de clipe
## torto e andavam com as pernas do código — achadas pelo NOME `Limb`, que
## errava do mesmo jeito (no caramelo, uma perna de verdade e três ossos de
## orelha e rabo balançando: "o bicho fica esticando e voltando").
##
## Agora o clipe não toca em quadrúpede nenhum, e as pernas são achadas pela
## PELE, sem ler nome: o osso que move os vértices baixos da malha é um pé, e a
## perna sobe dele até o tronco (`_achar_as_pernas`). Só o esqueleto não
## bastava, e a sonda dos pesos de 06/10 mostrou por quê: em metade dos rigs há
## perna que é um toco de um osso (a de trás direita do gato malhado), ou uma
## cadeia só, no meio, que move as duas patas de trás (cão caramelo, bode) ou as
## duas da frente (filhote) — essa balança as duas juntas, no tempo dela, que
## manca menos que pata dura. O passo é o
## andar de quatro tempos (trás-esquerda, frente-esquerda, trás-direita,
## frente-direita), a cadência sai do comprimento da perna e da velocidade de
## cada espécie (`bichos_de_casa.json`, `criaturas_3d.json`), e o corpo
## balança pouco. A mesma conta vale para qualquer esqueleto do Tripo; o bicho
## de caixa (o procedural) anda com o balanço do passo, sem perna.
##
## NADA ESTICA: a respiração alarga o peito (escala só em X e Z), a cabeça
## acena e o rabo balança por osso, e ABAIXAR (`abaixar`: a espreita da onça,
## a ave no poleiro) é o corpo descer com os joelhos dobrados — não a escala
## vertical de antes, que era o "esticando e voltando em um movimento vertical"
## do teste ao vivo.
##
## O resto é como era: mexe só no nó POSE — o que fica entre o corpo do bicho
## e o modelo —, para não brigar com quem é dono do corpo (o bote da onça
## abaixa o corpo; a tontura e a queda o deitam de lado):
##   - CORRER inclina o corpo para a frente.
##   - Ave não tem esqueleto: anda gingando e saltitando, BICA (inclina em
##     volta do pé), e no SUSTO pula estufada (escala em X e Z).

## Abaixo disto (u/s) o bicho está parado.
const PARADO_ABAIXO := 0.08
## Respiração parado: quanto o peito alarga (escala em X e Z) e o ritmo (rad/s).
const RESPIRA := 0.012
const RITMO_DA_RESPIRACAO := 2.3
## Inclinação máxima na corrida (rad), e a velocidade relativa em que começa.
const INCLINA_NA_CORRIDA := 0.09
const CORRIDA_A_PARTIR := 1.35
## O bicar: ângulo (rad) e duração (s).
const BICA := deg_to_rad(35.0)
const DURA_O_BICAR := 0.42

## AS PERNAS, pelo que a pele move. Vértice baixo é o que fica até `PE_ATE` da
## altura da malha; um osso é pé quando pelo menos `PE_DO_OSSO` do peso dele
## está nesses vértices (o Root segura o corpo e um pouco de pata: não é pé), e
## a perna tem de carregar pelo menos `PE_MINIMO` do peso baixo (senão é dedo,
## ou a ponta do rabo). A perna sobe do pé até o tronco — onde o esqueleto se
## ramifica alto, ou acima de `TRONCO_ACIMA` da altura, nunca pelo nome do
## osso —, cai pelo menos `PERNA_MINIMA` da altura e cai em pé:
## `PERNA_INCLINA` é o máximo de deslocamento horizontal por queda (o rabo
## que arrasta no chão cai deitado, e não é perna). `LADO_A_PARTIR` é a fração
## da largura do corpo de que uma perna se afasta do meio para ter lado.
const PE_ATE := 0.25
const PE_DO_OSSO := 0.4
const PE_MINIMO := 0.04
const PERNA_MINIMA := 0.15
const TRONCO_ACIMA := 0.8
const PERNA_INCLINA := 0.7
const LADO_A_PARTIR := 0.1
## O balanço da perna (rad): base, o que cresce com a velocidade relativa e o
## teto; quanto o joelho dobra na perna que vai à frente; quanto a perna demora
## a tomar força e a voltar ao repouso (rad/s).
const PERNA_BALANCO := Vector3(0.22, 0.12, 0.46)
const PERNA_DOBRA := 0.6
const PERNA_VOLTA := 8.0
## A passada, em comprimentos de perna por ciclo, e a cadência (Hz) mínima e
## máxima: um cão de perna de 40 cm a 1,25 u/s dá dois passos por segundo; o
## jumento, menos de um.
const PASSADA_EM_PERNAS := 1.5
const CADENCIA := Vector2(0.7, 3.0)
## OS QUATRO TEMPOS DO ANDAR, pela posição da perna (trás/frente × lado): a de
## trás pousa, depois a da frente do mesmo lado, e o outro lado repete. O
## número é a fase (do ciclo) em que o osso do alto está mais para trás, que é
## quando o pé pousa. A perna do meio (uma cadeia para as duas patas de uma
## ponta) pousa no tempo de uma das duas.
const TEMPO_DA_PERNA := {"tras_esquerda": 0.75, "frente_esquerda": 0.5, "tras_direita": 0.25, "frente_direita": 0.0,
	"tras_centro": 0.75, "frente_centro": 0.5}
## Quanto o corpo sobe no passo (fração do comprimento da perna) e rola (rad);
## quanto os joelhos dobram ao abaixar (rad por unidade de abaixamento); a
## cabeça parada acenando e o rabo balançando (rad).
const SOBE_NO_PASSO := 0.02
const ROLA_NO_PASSO := 0.02
const DOBRA_AO_ABAIXAR := 2.4
const ACENO_DA_CABECA := 0.035
const BALANCO_DO_RABO := 0.14

## As caixas das casas, em cache: bicho e ave perguntam "isto é dentro de uma
## casa?" a cada passo, e a conta por grupo (transformada inversa de cada casa)
## custava mais que o passo. A casa não anda; o cache refaz quando muda o número
## de casas.
static var _caixas_das_casas: Array[Dictionary] = []
static var _quantas_casas := -1

var pose: Node3D
var modelo: Node3D
var ave := false
## O tocador do GLB, parado: fica para quem pergunta (`tem_clipe`).
var animacao: AnimationPlayer
## O passo da espécie (u/s): a velocidade relativa é a de agora sobre ele.
var passada := 1.0
## Velocidade de agora, posta por quem anda.
var velocidade := 0.0
## Para onde a altura do corpo vai (1 de pé; 0,85 espreitando).
var altura_alvo := 1.0
var _tempo := 0.0
var _fase := 0.0
var _bicando := -1.0
var _angulo_do_bicar := BICA
var _susto := -1.0
var _tremor := 0.0
## As pernas: {osso (o alto), joelho (-1 num toco de um osso), fase, repouso,
## repouso_joelho, pai, pai_do_joelho, comprimento, canto}.
var _pernas: Array[Dictionary] = []
var _esqueleto: Skeleton3D
var _forca_da_perna := 0.0
var _giro_da_perna := 0.0
var _comprimento_da_perna := 0.0
## A altura do modelo (u), para abaixar e para o balanço.
var _altura := 0.5
## A altura de agora, a caminho de `altura_alvo`.
var _abaixado := 1.0
## A cabeça e o rabo, se o esqueleto os nomeia: {osso, repouso, pai}.
var _cabeca: Dictionary = {}
var _rabo: Dictionary = {}


## `pose` é o nó que este animador mexe; `modelo`, o que está dentro dele (o GLB
## ou a caixa). `passada_padrao` é o passo da espécie (u/s).
func configurar(nova_pose: Node3D, novo_modelo: Node3D, eh_ave: bool, chave: String, passada_padrao: float) -> void:
	pose = nova_pose
	modelo = novo_modelo
	ave = eh_ave
	passada = passada_padrao
	_fase = randf() * TAU
	# Cada bicho num ponto do passo: dois cães lado a lado não marcham juntos.
	_giro_da_perna = randf() * TAU
	_pernas.clear()
	_cabeca = {}
	_rabo = {}
	_esqueleto = null
	if modelo == null:
		return
	_altura = _medir_altura()
	if ave:
		return
	# O clipe do GLB não toca (ver o cabeçalho): o tocador fica parado.
	var tocadores := modelo.find_children("*", "AnimationPlayer", true, false)
	if not tocadores.is_empty():
		animacao = tocadores[0] as AnimationPlayer
		animacao.stop()
	_achar_as_pernas(chave)


## O clipe do GLB toca? Nunca mais em quadrúpede (#109): fica para quem
## pergunta, e para o portão cobrar que continue assim.
func tem_clipe() -> bool:
	return animacao != null and animacao.is_playing()


## Anda com as pernas do código?
func tem_pernas() -> bool:
	return not _pernas.is_empty()


## As pernas achadas, para quem confere: uma cópia.
func pernas() -> Array[Dictionary]:
	return _pernas.duplicate()


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


## A altura do modelo no referencial da pose (u).
func _medir_altura() -> float:
	var para_a_pose := pose.global_transform.affine_inverse()
	var caixa := AABB()
	var primeira := true
	for malha in malhas(modelo):
		var c: AABB = para_a_pose * (malha.global_transform * malha.get_aabb())
		caixa = c if primeira else caixa.merge(c)
		primeira = false
	return maxf(caixa.size.y, 0.05) if not primeira else 0.5


## A PELE SONDADA, por chave do catálogo (todo cão caramelo é o mesmo GLB): o
## que cada osso move dos vértices baixos da malha, e a caixa da malha.
static var _peles: Dictionary = {}


## O QUE A PELE MOVE: para cada osso, quanto peso ele tem nos vértices baixos da
## malha (até `PE_ATE` da altura) e onde eles ficam (o centroide, no referencial
## do bicho), e a caixa da malha inteira. Os ossos saem do `Skin` de cada malha.
## Um osso é PÉ quando pelo menos `PE_DO_OSSO` do peso dele está embaixo. Vazio
## quando o modelo não tem pele.
func _sondar_a_pele(chave: String) -> Dictionary:
	if _peles.has(chave):
		return _peles[chave]
	var pele: Dictionary = {}
	var para_a_pose := pose.global_transform.affine_inverse()
	var com_pele: Array[MeshInstance3D] = []
	var caixa := AABB()
	for no in modelo.find_children("*", "MeshInstance3D", true, false):
		var malha := no as MeshInstance3D
		if malha.mesh == null or malha.skin == null:
			continue
		var c: AABB = (para_a_pose * malha.global_transform) * malha.mesh.get_aabb()
		caixa = c if com_pele.is_empty() else caixa.merge(c)
		com_pele.append(malha)
	if com_pele.is_empty():
		_peles[chave] = pele
		return pele
	var corte := caixa.position.y + PE_ATE * caixa.size.y
	var total: Dictionary = {}
	var baixo: Dictionary = {}
	var em_x: Dictionary = {}
	var em_z: Dictionary = {}
	var peso_baixo := 0.0
	for malha in com_pele:
		var ossos_do_skin: PackedInt32Array = PackedInt32Array()
		for b in malha.skin.get_bind_count():
			var osso: int = malha.skin.get_bind_bone(b)
			if osso < 0:
				osso = _esqueleto.find_bone(malha.skin.get_bind_name(b))
			ossos_do_skin.append(osso)
		var para: Transform3D = para_a_pose * malha.global_transform
		for s in malha.mesh.get_surface_count():
			var arranjos := malha.mesh.surface_get_arrays(s)
			var vertices: PackedVector3Array = arranjos[Mesh.ARRAY_VERTEX]
			var ossos = arranjos[Mesh.ARRAY_BONES]
			var pesos = arranjos[Mesh.ARRAY_WEIGHTS]
			if vertices.is_empty() or ossos == null or pesos == null:
				continue
			var por_vertice := int(ossos.size() / vertices.size())
			for i in vertices.size():
				var q: Vector3 = para * vertices[i]
				var embaixo := q.y <= corte
				for k in por_vertice:
					var w: float = pesos[i * por_vertice + k]
					if w <= 0.001:
						continue
					var indice: int = ossos[i * por_vertice + k]
					var osso: int = ossos_do_skin[indice] if indice < ossos_do_skin.size() else -1
					total[osso] = float(total.get(osso, 0.0)) + w
					if embaixo:
						baixo[osso] = float(baixo.get(osso, 0.0)) + w
						em_x[osso] = float(em_x.get(osso, 0.0)) + w * q.x
						em_z[osso] = float(em_z.get(osso, 0.0)) + w * q.z
						peso_baixo += w
	var pes: Dictionary = {}
	for osso in baixo:
		if int(osso) < 0 or float(baixo[osso]) < PE_DO_OSSO * float(total[osso]):
			continue
		pes[osso] = {"peso": float(baixo[osso]), "x": float(em_x[osso]) / float(baixo[osso]), "z": float(em_z[osso]) / float(baixo[osso])}
	pele = {"pes": pes, "peso_baixo": peso_baixo, "caixa": caixa}
	_peles[chave] = pele
	return pele


## AS PERNAS, PELO QUE A PELE MOVE (ver o cabeçalho). De cada pé
## (`_sondar_a_pele`) a cadeia sobe de pai em pai até o tronco: uma ramificação
## alta, o limite `TRONCO_ACIMA` da altura, ou um pai mais baixo (virou outro
## membro). Pés que chegam ao mesmo osso do alto são a mesma perna (os dedos, a
## canela), e o pé dela é o centroide do que esses ossos movem embaixo. Vale a
## perna que carrega pelo menos `PE_MINIMO` do peso baixo, cai pelo menos
## `PERNA_MINIMA` da altura e cai em pé (`PERNA_INCLINA`). O osso do alto
## balança; o logo abaixo dele é o joelho (um toco de um osso não tem). Trás e
## frente é o pé contra a média dos pés; o lado, contra a média dos pés da mesma
## ponta — a cadeia sozinha na ponta é do meio, e move as duas patas; com as
## duas patas na ponta, o que sobra no meio é rabo, e sai.
func _achar_as_pernas(chave: String) -> void:
	var esqueletos := modelo.find_children("*", "Skeleton3D", true, false)
	if esqueletos.is_empty():
		return
	_esqueleto = esqueletos[0] as Skeleton3D
	var pele := _sondar_a_pele(chave)
	if pele.is_empty():
		return
	var caixa: AABB = pele["caixa"]
	var altura := maxf(caixa.size.y, 0.001)
	var chao := caixa.position.y
	var n := _esqueleto.get_bone_count()
	var para_o_bicho := pose.global_transform.affine_inverse() * _esqueleto.global_transform
	var onde: PackedVector3Array = PackedVector3Array()
	for i in n:
		onde.append(para_o_bicho * _esqueleto.get_bone_global_rest(i).origin)
	var pes: Dictionary = pele["pes"]
	var por_alto: Dictionary = {}
	for pe in pes:
		var cadeia: Array[int] = [int(pe)]
		var b := _esqueleto.get_bone_parent(int(pe))
		while b >= 0:
			if onde[b].y > chao + TRONCO_ACIMA * altura:
				break
			if _esqueleto.get_bone_children(b).size() >= 2 and onde[b].y > chao + PERNA_MINIMA * altura:
				break
			if onde[b].y < onde[cadeia.back()].y - 0.02 * altura:
				break
			cadeia.append(b)
			b = _esqueleto.get_bone_parent(b)
		var alto: int = cadeia.back()
		var dado: Dictionary = pes[pe]
		if not por_alto.has(alto):
			por_alto[alto] = {"peso": 0.0, "x": 0.0, "z": 0.0, "cadeia": cadeia}
		var grupo: Dictionary = por_alto[alto]
		grupo["peso"] = float(grupo["peso"]) + float(dado["peso"])
		grupo["x"] = float(grupo["x"]) + float(dado["x"]) * float(dado["peso"])
		grupo["z"] = float(grupo["z"]) + float(dado["z"]) * float(dado["peso"])
		if cadeia.size() > (grupo["cadeia"] as Array).size():
			grupo["cadeia"] = cadeia
	var candidatas: Array[Dictionary] = []
	for alto in por_alto:
		var grupo: Dictionary = por_alto[alto]
		var peso: float = grupo["peso"]
		if peso < PE_MINIMO * float(pele["peso_baixo"]):
			continue
		var pe := Vector3(float(grupo["x"]) / peso, chao, float(grupo["z"]) / peso)
		var queda: float = onde[int(alto)].y - chao
		if queda < PERNA_MINIMA * altura:
			continue
		if Vector2(pe.x - onde[int(alto)].x, pe.z - onde[int(alto)].z).length() > PERNA_INCLINA * queda:
			continue
		candidatas.append({"alto": int(alto), "cadeia": grupo["cadeia"], "pe": pe, "queda": queda})
	if candidatas.size() < 2:
		return
	var meio_z := 0.0
	for c in candidatas:
		meio_z += (c["pe"] as Vector3).z
	meio_z /= float(candidatas.size())
	var soma_x: Dictionary = {"frente_": 0.0, "tras_": 0.0}
	var quantas: Dictionary = {"frente_": 0, "tras_": 0}
	for c in candidatas:
		var pe: Vector3 = c["pe"]
		var ponta := "frente_" if pe.z >= meio_z else "tras_"
		c["ponta"] = ponta
		soma_x[ponta] = float(soma_x[ponta]) + pe.x
		quantas[ponta] = int(quantas[ponta]) + 1
	for c in candidatas:
		var pe: Vector3 = c["pe"]
		var ponta: String = c["ponta"]
		var desvio: float = pe.x - float(soma_x[ponta]) / float(quantas[ponta])
		var lado := "centro"
		if desvio > LADO_A_PARTIR * caixa.size.x:
			lado = "esquerda"
		elif desvio < -LADO_A_PARTIR * caixa.size.x:
			lado = "direita"
		c["canto"] = ponta + lado
	# A ponta que já tem as duas patas, uma de cada lado, não tem perna do meio:
	# o que sobra no meio é rabo que pende até perto do chão (o do caititu).
	var com_lado: Dictionary = {"frente_": 0, "tras_": 0}
	for c in candidatas:
		if not str(c["canto"]).ends_with("centro"):
			com_lado[c["ponta"]] = int(com_lado[c["ponta"]]) + 1
	var soma := 0.0
	for c in candidatas:
		var canto: String = c["canto"]
		if canto.ends_with("centro") and int(com_lado[c["ponta"]]) >= 2:
			continue
		var alto: int = c["alto"]
		var cadeia: Array = c["cadeia"]
		var joelho: int = cadeia[cadeia.size() - 2] if cadeia.size() >= 2 else -1
		var queda: float = c["queda"]
		soma += queda
		_pernas.append({"osso": alto, "joelho": joelho, "fase": float(TEMPO_DA_PERNA[canto]) * TAU, "canto": canto,
			"comprimento": queda,
			"repouso": _repouso(alto),
			"repouso_joelho": _repouso(joelho) if joelho >= 0 else Quaternion.IDENTITY,
			"pai": _repouso_global(_esqueleto.get_bone_parent(alto)),
			"pai_do_joelho": _repouso_global(alto)})
	if _pernas.is_empty():
		return
	_comprimento_da_perna = soma / float(_pernas.size())
	# A cabeça e o rabo, pelo nome, só para o aceno e o balanço: o primeiro osso
	# de cada cadeia (o da base).
	for i in n:
		var nome := _esqueleto.get_bone_name(i).to_lower()
		if _cabeca.is_empty() and ("head" in nome or "neck" in nome):
			_cabeca = {"osso": i, "repouso": _repouso(i), "pai": _repouso_global(_esqueleto.get_bone_parent(i))}
		elif _rabo.is_empty() and "tail" in nome:
			_rabo = {"osso": i, "repouso": _repouso(i), "pai": _repouso_global(_esqueleto.get_bone_parent(i))}


func _repouso(osso: int) -> Quaternion:
	return _esqueleto.get_bone_rest(osso).basis.orthonormalized().get_rotation_quaternion()


func _repouso_global(osso: int) -> Quaternion:
	if osso < 0:
		return Quaternion.IDENTITY
	return _esqueleto.get_bone_global_rest(osso).basis.orthonormalized().get_rotation_quaternion()


## Gira um osso por cima do repouso, com `giro` no referencial do esqueleto:
## passado ao referencial do pai do osso, que é onde a pose local vive.
func _girar_osso(osso: int, giro: Quaternion, repouso: Quaternion, pai: Quaternion) -> void:
	_esqueleto.set_bone_pose_rotation(osso, pai.inverse() * giro * pai * repouso)


## Um eixo do bicho (frente, direita, cima) no referencial do esqueleto.
func _eixo(do_bicho: Vector3) -> Vector3:
	return (_esqueleto.global_basis.inverse() * (pose.global_basis * do_bicho)).normalized()


## O BALANÇO DAS PERNAS: o osso do alto gira em volta do eixo esquerda-direita
## do bicho, cada perna no seu tempo; o joelho dobra na perna que vai à frente
## (`cos` negativo: o osso do alto indo de trás para a frente) e, abaixado,
## todos dobram. A força sobe ao andar e desce ao parar, e parado de vez cada
## osso volta ao repouso — a pata no chão (#91).
func _balancar_as_pernas(delta: float, andando: bool, relativa: float) -> void:
	if _esqueleto == null or not is_instance_valid(_esqueleto):
		return
	var alvo := 0.0
	if andando:
		alvo = clampf(PERNA_BALANCO.x + PERNA_BALANCO.y * relativa, 0.0, PERNA_BALANCO.z)
	_forca_da_perna = move_toward(_forca_da_perna, alvo, delta * PERNA_VOLTA)
	var agachado := (1.0 - _abaixado) * DOBRA_AO_ABAIXAR
	if _forca_da_perna <= 0.001 and not andando and agachado <= 0.001:
		if _giro_da_perna != 0.0:
			for perna in _pernas:
				_esqueleto.set_bone_pose_rotation(int(perna["osso"]), perna["repouso"])
				if int(perna["joelho"]) >= 0:
					_esqueleto.set_bone_pose_rotation(int(perna["joelho"]), perna["repouso_joelho"])
			_giro_da_perna = 0.0
		return
	if andando or _forca_da_perna > 0.001:
		var cadencia := clampf(velocidade / maxf(PASSADA_EM_PERNAS * _comprimento_da_perna, 0.05), CADENCIA.x, CADENCIA.y)
		_giro_da_perna += delta * TAU * cadencia
	var eixo := _eixo(Vector3.RIGHT)
	for perna in _pernas:
		var fase: float = _giro_da_perna + float(perna["fase"])
		_girar_osso(int(perna["osso"]), Quaternion(eixo, _forca_da_perna * sin(fase)), perna["repouso"], perna["pai"])
		if int(perna["joelho"]) < 0:
			continue
		var dobra := PERNA_DOBRA * maxf(0.0, -cos(fase)) * (_forca_da_perna / PERNA_BALANCO.z) + agachado
		_girar_osso(int(perna["joelho"]), Quaternion(eixo, dobra), perna["repouso_joelho"], perna["pai_do_joelho"])


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


## Abaixa o corpo até `fracao` da altura (1 de pé): o corpo desce e, com
## pernas, os joelhos dobram. Nada escala em Y.
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
	_abaixado = lerpf(_abaixado, altura_alvo, minf(1.0, delta * 6.0))
	if not _pernas.is_empty():
		# As pernas do código, e o corpo sobe e rola duas vezes por passada, de leve.
		_balancar_as_pernas(delta, andando, relativa)
		if _forca_da_perna > 0.001:
			var quanto := _forca_da_perna / PERNA_BALANCO.z
			y = absf(sin(_giro_da_perna)) * SOBE_NO_PASSO * _comprimento_da_perna * quanto
			ginga = sin(_giro_da_perna) * ROLA_NO_PASSO * quanto
	elif andando:
		# O balanço do passo, sem perna: sobe e desce duas vezes por passada.
		_fase += delta * TAU * clampf(relativa, 0.5, 3.0) * (2.4 if ave else 1.6)
		y = absf(sin(_fase)) * (0.035 if ave else 0.03)
		ginga = sin(_fase) * (0.09 if ave else 0.03)
	if andando and relativa > CORRIDA_A_PARTIR:
		inclina = INCLINA_NA_CORRIDA * clampf((relativa - CORRIDA_A_PARTIR) / 0.8, 0.0, 1.0)
	var escala_xz := 1.0
	if not andando:
		# A respiração: o peito alarga, devagar. Só em X e Z: nada estica.
		escala_xz = 1.0 + sin(_tempo * RITMO_DA_RESPIRACAO + _fase) * RESPIRA
	_acenar(andando)
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
	# Abaixado, o corpo desce (a metade do que perde de altura: o resto é joelho).
	y -= (1.0 - _abaixado) * _altura * 0.5
	pose.position.y = y
	pose.rotation = Vector3(inclina, 0.0, ginga)
	pose.scale = Vector3(escala_xz, 1.0, escala_xz)


## A cabeça acena e o rabo balança, por osso, parado ou andando (andando, o
## rabo mais).
func _acenar(andando: bool) -> void:
	if _esqueleto == null or not is_instance_valid(_esqueleto):
		return
	if not _cabeca.is_empty():
		var aceno := sin(_tempo * 1.3 + _fase) * ACENO_DA_CABECA
		_girar_osso(int(_cabeca["osso"]), Quaternion(_eixo(Vector3.RIGHT), aceno), _cabeca["repouso"], _cabeca["pai"])
	if not _rabo.is_empty():
		var balanco := sin(_tempo * (3.1 if andando else 1.7) + _fase) * BALANCO_DO_RABO * (1.4 if andando else 1.0)
		_girar_osso(int(_rabo["osso"]), Quaternion(_eixo(Vector3.UP), balanco), _rabo["repouso"], _rabo["pai"])
