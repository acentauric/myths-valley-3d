extends Node
## O ANIMADOR DOS BICHOS: o que o GLB traz e o que o Godot põe por cima.
##
## Os quadrúpedes do Tripo vêm com um clipe só, `preset:quadruped:walk`, andando
## no lugar (a raiz não sai do ponto). As aves vêm paradas, sem esqueleto. O
## resto é procedural, e mexe só no nó POSE — o que fica entre o corpo do bicho
## e o modelo —, para não brigar com quem é dono do corpo (a tontura e a queda
## o deitam de lado):
##
##   - ANDAR é o clipe, na velocidade do chão: a passada do clipe é medida pelos
##     pés uma vez por modelo, e a reprodução acompanha o deslocamento (até
##     `ACELERA_ATE` vezes) para a pata não escorregar.
##   - PARADO é o mesmo clipe congelado no quadro de PÉ (o que mais se parece com
##     o repouso do esqueleto), com a respiração por cima e, de tempos em tempos,
##     um olhar de lado — cada bicho no seu ritmo.
##   - CORRER é o clipe acelerado, o corpo inclinado e, na carreira, o galope: o
##     corpo sobe e desce no compasso do clipe.
##   - ESPREITAR é o corpo abaixado (`abaixar`), que a onça usa antes da carga; o
##     BOTE (`bote`) é o armar, o pulo e a mordida, em cima do mesmo nó.
##   - Ave não tem clipe: anda gingando e saltitando, BICA (inclina em volta do
##     pé), e no SUSTO pula estufada.
##
## Sem clipe (a caixa cinza do procedural, ou um GLB que ainda não chegou), o
## quadrúpede anda com o balanço do passo — a mesma leitura, sem perna.
##
## A RESPIRAÇÃO NÃO ENTRA NA ALTURA. A altura que o bicho persegue (`_altura`) é
## guardada à parte da escala que se mostra: antes, a escala do quadro anterior —
## já com o fôlego dentro — voltava a ser a base da seguinte, e o fôlego se
## multiplicava a si mesmo (de 3 % a 15 % de esticada, e a 144 quadros por segundo
## de 25 % a 43 %). O que se mostra é sempre `_altura * (1 + respiro)`, e nada do
## que se mostra é lido de volta.
##
## O CLIPE TORTO. Em dois modelos do Tripo (`CLIPE_TORTO`) o clipe de andar vem
## de um esqueleto-padrão que não casa com o do GLB: tocado, ele dobra a frente do
## corpo para cima (o cão caramelo chuta o ar, a onça vira girafa). O clipe é
## RECENTRADO uma vez: cada trilha de rotação passa a oscilar em volta da pose de
## repouso do osso, e não em volta da média que o clipe trouxe (`repouso × média⁻¹
## × q`), e o desvio é limitado a `TETO_DO_DESVIO`. Só a perna não basta: o osso do
## ombro, que carrega a perna da frente, fica fora da cadeia dela.
##
## PERNA PARADA. Em alguns modelos o clipe deixa uma perna dura (a traseira da
## onça-preta, uma do cão malhado). Essa perna copia o balanço da perna da diagonal
## oposta, em torno do eixo esquerda-direita do bicho.

## Até quanto o clipe acelera antes de a corrida virar só inclinação e galope, e
## de quanto ele desacelera no mínimo.
const ACELERA_ATE := 6.0
const ACELERA_DE := 0.3
## Abaixo disto (u/s) o bicho está parado.
const PARADO_ABAIXO := 0.08
## Respiração parado: amplitude da escala e o ritmo (rad/s).
const RESPIRA := 0.014
const RITMO_DA_RESPIRACAO := 2.3
## Inclinação máxima na corrida (rad), e a velocidade relativa em que começa.
const INCLINA_NA_CORRIDA := 0.09
const CORRIDA_A_PARTIR := 1.35
## O galope: a partir de quanto a mais de `CORRIDA_A_PARTIR` ele chega ao máximo,
## quanto o corpo sobe (u) e quanto cabeceia (rad).
const GALOPE_ATE := 3.0
const GALOPE_SOBE := 0.05
const GALOPE_CABECEIA := 0.035
## O bicar: ângulo (rad) e duração (s).
const BICA := deg_to_rad(35.0)
const DURA_O_BICAR := 0.42
## O olhar do bicho parado: de quanto em quanto tempo (s), até quanto vira (rad) e
## com que pressa (rad/s).
const OLHA_A_CADA := Vector2(3.5, 9.0)
const OLHA_ATE := 0.38
const OLHA_COM_PRESSA := 0.7

## Os modelos de quadrúpede cujo clipe de andar vem torto (ver o cabeçalho). Os
## outros (gatos, porco, cabra, bode, jumento, caititu, cão malhado, onça-preta)
## andam com o clipe como veio do GLB.
const CLIPE_TORTO := ["cachorro_caramelo", "onca_pintada"]
## O quanto uma trilha recentrada se afasta da média do clipe, no máximo (rad).
const TETO_DO_DESVIO := 0.35
## Pé é ponta de cadeia nos 30 % de baixo da altura do esqueleto, que não seja
## da cabeça nem da cauda.
const PE_ATE := 0.30
## Perna parada é a que anda menos que esta fração da perna do meio.
const PERNA_PARADA_ABAIXO := 0.3
## O pé conta para a passada se anda ao menos esta fração da maior pernada.
const PE_QUE_ANDA := 0.35

## O bote: até onde vai o armar e o pulo (fração do bote), quanto o corpo abaixa
## armando (fração da altura), o salto (u) e o cabeceio (rad) de cada fase.
const BOTE_ARMA_ATE := 0.3
const BOTE_PULA_ATE := 0.7
const BOTE_ABAIXA := 0.2
const BOTE_SALTO := 0.28
const BOTE_EMPINA := 0.28
const BOTE_MORDE := 0.30
const BOTE_ARMA_INCLINA := 0.10
## O meio comprimento do bicho que cabeceia (u): cabecear em torno do meio enfiaria no chão a ponta
## que desce, e a pose sobe o que a ponta desceria — a de baixo fica no chão, e a outra sobe o dobro.
const BOTE_ALAVANCA := 0.9

## As caixas das casas, em cache: bicho e ave perguntam "isto é dentro de uma
## casa?" a cada passo, e a conta por grupo (transformada inversa de cada casa)
## custava mais que o passo. A casa não anda; o cache refaz quando muda o número
## de casas.
static var _caixas_das_casas: Array[Dictionary] = []
static var _quantas_casas := -1

## O que se mede do clipe, por chave do catálogo: medir custa 48 poses do
## esqueleto, e todo galo do vale é o mesmo galo. `passada` (u/s com o clipe em
## 1×), `quadros_de_pe` (instantes do clipe em que o esqueleto mais se parece com o
## repouso) e `paradas` (pernas que o clipe não mexe).
static var _analises: Dictionary = {}

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
## A altura que o corpo persegue, sem o fôlego (ver o cabeçalho).
var _altura := 1.0
var _bicando := -1.0
var _angulo_do_bicar := BICA
var _susto := -1.0
var _tremor := 0.0
var _parado_no_quadro := false
var _quadros_de_pe: PackedFloat32Array = PackedFloat32Array()
var _posicao_anterior := -1.0
var _galope := 0.0
## O olhar de lado de quem está parado.
var _olhar_em := 0.0
var _olhar_para := 0.0
var _olhar := 0.0
## O bote: de 0 a 1 enquanto dura, -1 fora dele.
var _bote := -1.0
var _esqueleto: Skeleton3D
## As pernas paradas do clipe: cada uma, os pares de ossos {osso, parceiro, pai, repouso}.
var _paradas: Array[Dictionary] = []
var _eixo_lateral := Vector3.RIGHT


## `pose` é o nó que este animador mexe; `modelo`, o que está dentro dele (o GLB
## ou a caixa). `chave` é a do catálogo, para guardar o que se mediu do clipe.
func configurar(nova_pose: Node3D, novo_modelo: Node3D, eh_ave: bool, chave: String, passada_padrao: float) -> void:
	pose = nova_pose
	modelo = novo_modelo
	ave = eh_ave
	passada = passada_padrao
	_fase = randf() * TAU
	_olhar_em = randf_range(OLHA_A_CADA.x, OLHA_A_CADA.y)
	if modelo == null:
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
	var clipe := animacao.get_animation(_clipe)
	clipe.loop_mode = Animation.LOOP_LINEAR
	var esqueletos := modelo.find_children("*", "Skeleton3D", true, false)
	_esqueleto = esqueletos[0] as Skeleton3D if not esqueletos.is_empty() else null
	if chave in CLIPE_TORTO and _esqueleto != null:
		recentrar_o_clipe(clipe, _esqueleto)
	animacao.play(_clipe)
	# O que se mede vale por modelo E por tamanho: a cabra de cena é uma cabra solta 13 % maior.
	var escala := (pose.global_transform.affine_inverse() * modelo.global_transform).basis.get_scale().x
	var medida := "%s@%.2f" % [chave, escala]
	var analise: Dictionary = _analises.get(medida, {})
	if analise.is_empty():
		analise = _analisar_o_clipe()
		if not analise.is_empty():
			_analises[medida] = analise
	if float(analise.get("passada", 0.0)) > 0.05:
		passada = float(analise["passada"])
	_quadros_de_pe = analise.get("quadros_de_pe", PackedFloat32Array())
	_ligar_as_pernas_paradas(analise.get("paradas", []))
	# Cada bicho num ponto do passo: dois cães lado a lado não marcham juntos.
	animacao.seek(randf() * clipe.length, true)


func tem_clipe() -> bool:
	return animacao != null


## O clipe pode estar recentrado? (só o dos modelos de `CLIPE_TORTO`, e só depois de
## configurado um bicho com ele.)
func clipe_recentrado() -> bool:
	return animacao != null and animacao.get_animation(_clipe).has_meta("recentrado")


## Quantas pernas o clipe deixa duras e o código balança.
func pernas_paradas() -> int:
	return _paradas.size()


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


## O BOTE, de `fase` 0 (armou) a 1 (acabou); fora dele, `-1`. Quem manda no bote é
## a criatura (a mordida, o pulo, o relógio de física); aqui só se mostra: arma
## (abaixa e baixa o focinho), pula (sobe, empina e mergulha na mordida) e assenta.
## Tudo em posição e giro do nó POSE — a escala só abaixa, e abaixa de volta —, para
## que um bote interrompido (pancada, queda, pausa) não deixe o corpo esticado.
func bote(fase: float) -> void:
	_bote = fase


func em_bote() -> bool:
	return _bote >= 0.0


func _process(delta: float) -> void:
	if pose == null or not pose.is_visible_in_tree():
		# Bicho escondido (longe) não anima: sem pausar aqui o clipe de andar seguia
		# tocando, com o esqueleto, enquanto ninguém o via. Ao voltar, o `play` abaixo retoma.
		if animacao != null and animacao.is_playing():
			animacao.pause()
			_parado_no_quadro = true
		return
	_tempo += delta
	var relativa := velocidade / maxf(passada, 0.05)
	var andando := velocidade > PARADO_ABAIXO
	var y := 0.0
	var inclina := 0.0
	var ginga := 0.0
	_altura = lerpf(_altura, altura_alvo, minf(1.0, delta * 6.0))
	var escala_y := _altura
	if animacao != null:
		if andando:
			_posicao_anterior = -1.0
			if _parado_no_quadro or not animacao.is_playing():
				animacao.play(_clipe)
				_parado_no_quadro = false
			animacao.speed_scale = clampf(relativa, ACELERA_DE, ACELERA_ATE)
		elif not _parado_no_quadro:
			# Parou: termina o passo e congela no quadro de pé, em vez de no meio da
			# pernada (a pata não fica no ar), e sem pressa nem demora.
			animacao.speed_scale = clampf(animacao.speed_scale, 0.8, 2.0)
			var onde := _quadro_de_pe_cruzado()
			if onde >= 0.0:
				animacao.pause()
				animacao.seek(onde, true)
				_parado_no_quadro = true
		if not _paradas.is_empty():
			_mexer_as_pernas_paradas()
	elif andando:
		# O balanço do passo, sem perna: sobe e desce duas vezes por passada.
		_fase += delta * TAU * clampf(relativa, 0.5, 3.0) * (2.4 if ave else 1.6)
		y = absf(sin(_fase)) * (0.035 if ave else 0.03)
		ginga = sin(_fase) * (0.09 if ave else 0.03)
	if andando and relativa > CORRIDA_A_PARTIR:
		var corre := clampf((relativa - CORRIDA_A_PARTIR) / 0.8, 0.0, 1.0)
		inclina = INCLINA_NA_CORRIDA * corre
		if animacao != null:
			# O GALOPE: o corpo sobe e desce duas vezes por ciclo do clipe.
			var forca := clampf((relativa - CORRIDA_A_PARTIR) / GALOPE_ATE, 0.0, 1.0)
			_galope += delta * TAU * 2.0 * animacao.speed_scale / maxf(animacao.get_animation(_clipe).length, 0.1)
			y += absf(sin(_galope)) * GALOPE_SOBE * forca
			inclina += sin(_galope) * GALOPE_CABECEIA * forca
	var escala_xz := 1.0
	var olhando := not andando and not ave and _bicando < 0.0 and _susto < 0.0 and _bote < 0.0
	if olhando:
		_olhar_de_lado(delta)
	else:
		_olhar = move_toward(_olhar, 0.0, delta * 3.0)
	if not andando:
		# A respiração: o peito sobe e alarga, devagar — por cima da altura, e sem
		# voltar a ser a base dela.
		var respiro := sin(_tempo * RITMO_DA_RESPIRACAO + _fase) * RESPIRA
		escala_y *= 1.0 + respiro
		escala_xz = 1.0 + respiro * 0.5
	if _bote >= 0.0:
		var forma := _forma_do_bote(_bote)
		escala_y *= 1.0 - forma.x
		y += forma.y
		inclina += forma.z
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
	pose.rotation = Vector3(inclina, _olhar, ginga)
	pose.scale = Vector3(escala_xz, escala_y, escala_xz)


## O olhar de lado de quem está parado: de tempos em tempos vira um pouco para um
## lado e volta, e cada bicho olha no seu tempo. O giro de agora fica em `_olhar`.
func _olhar_de_lado(delta: float) -> void:
	_olhar_em -= delta
	if _olhar_em <= 0.0:
		_olhar_em = randf_range(OLHA_A_CADA.x, OLHA_A_CADA.y)
		_olhar_para = 0.0 if absf(_olhar_para) > 0.01 else randf_range(-OLHA_ATE, OLHA_ATE)
	_olhar = move_toward(_olhar, _olhar_para, delta * OLHA_COM_PRESSA)


## A forma do bote em `t` (0 a 1): x = quanto o corpo abaixa (fração da altura), y =
## quanto sobe (u), z = o cabeceio (rad, positivo é focinho para baixo).
static func _forma_do_bote(t: float) -> Vector3:
	var forma := Vector3.ZERO
	if t < BOTE_ARMA_ATE:
		var arma := smoothstep(0.0, BOTE_ARMA_ATE, t)
		forma = Vector3(BOTE_ABAIXA * arma, 0.0, BOTE_ARMA_INCLINA * arma)
	elif t < BOTE_PULA_ATE:
		var pula := (t - BOTE_ARMA_ATE) / (BOTE_PULA_ATE - BOTE_ARMA_ATE)
		var solta := 1.0 - smoothstep(0.0, 0.25, pula)
		forma = Vector3(BOTE_ABAIXA * solta, sin(pula * PI) * BOTE_SALTO, lerpf(-BOTE_EMPINA, BOTE_MORDE, smoothstep(0.0, 1.0, pula)))
	else:
		var assenta := smoothstep(BOTE_PULA_ATE, 1.0, t)
		forma = Vector3(0.0, 0.0, BOTE_MORDE * (1.0 - assenta))
	forma.y += BOTE_ALAVANCA * sin(absf(forma.z))
	return forma


# --- o clipe -------------------------------------------------------------------

## RECENTRA o clipe de andar em volta do repouso do esqueleto (ver o cabeçalho):
## cada trilha de rotação vira `repouso × média⁻¹ × q`, com o desvio da média limitado
## a `TETO_DO_DESVIO`. O clipe é um recurso dividido por todo bicho do modelo; ele
## leva a marca `recentrado` e só se recentra uma vez.
static func recentrar_o_clipe(clipe: Animation, esqueleto: Skeleton3D, teto: float = TETO_DO_DESVIO) -> void:
	if clipe.has_meta("recentrado"):
		return
	clipe.set_meta("recentrado", true)
	for t in clipe.get_track_count():
		if clipe.track_get_type(t) != Animation.TYPE_ROTATION_3D or clipe.track_is_compressed(t):
			continue
		var osso := esqueleto.find_bone(String(clipe.track_get_path(t).get_concatenated_subnames()))
		var chaves := clipe.track_get_key_count(t)
		if osso < 0 or chaves < 2:
			continue
		var primeira: Quaternion = clipe.track_get_key_value(t, 0)
		var soma := Vector4.ZERO
		for k in chaves:
			var q: Quaternion = clipe.track_get_key_value(t, k)
			if q.dot(primeira) < 0.0:
				q = Quaternion(-q.x, -q.y, -q.z, -q.w)
			soma += Vector4(q.x, q.y, q.z, q.w)
		var media := Quaternion(soma.x, soma.y, soma.z, soma.w).normalized()
		var maior := 0.0
		for k in chaves:
			maior = maxf(maior, media.angle_to(clipe.track_get_key_value(t, k)))
		var fator := 1.0 if maior <= teto else teto / maior
		var repouso := esqueleto.get_bone_rest(osso).basis.get_rotation_quaternion()
		for k in chaves:
			var desvio: Quaternion = media.inverse() * (clipe.track_get_key_value(t, k) as Quaternion)
			if fator < 1.0:
				desvio = Quaternion.IDENTITY.slerp(desvio, fator)
			clipe.track_set_key_value(t, k, repouso * desvio)


## Os PÉS do esqueleto: pontas de cadeia (osso sem filho) nos `PE_ATE` de baixo da
## altura, fora da cabeça e da cauda. `para_o_bicho` leva o esqueleto ao referencial
## do bicho, em que a frente é +Z.
static func achar_os_pes(esqueleto: Skeleton3D, para_o_bicho: Transform3D) -> Array[int]:
	var alturas := PackedFloat32Array()
	var baixo := INF
	var alto := -INF
	for i in esqueleto.get_bone_count():
		var y := (para_o_bicho * esqueleto.get_bone_global_rest(i).origin).y
		alturas.append(y)
		baixo = minf(baixo, y)
		alto = maxf(alto, y)
	var pes: Array[int] = []
	for i in esqueleto.get_bone_count():
		if esqueleto.get_bone_children(i).size() > 0 or alturas[i] > baixo + (alto - baixo) * PE_ATE:
			continue
		if _eh_da_cabeca_ou_da_cauda(esqueleto, i):
			continue
		pes.append(i)
	return pes


static func _eh_da_cabeca_ou_da_cauda(esqueleto: Skeleton3D, osso: int) -> bool:
	var a := osso
	while a >= 0:
		var nome := esqueleto.get_bone_name(a).to_lower()
		if "tail" in nome or "head" in nome:
			return true
		a = esqueleto.get_bone_parent(a)
	return false


## A PERNA de um pé: da ponta para cima, enquanto o pai só tem este pé embaixo (e
## nenhuma cabeça). O último osso é o topo da perna (a anca ou o ombro).
static func cadeia_da_perna(esqueleto: Skeleton3D, pe: int, pes: Array[int]) -> Array[int]:
	var cadeia: Array[int] = [pe]
	var atual := pe
	while true:
		var pai := esqueleto.get_bone_parent(atual)
		if pai < 0:
			break
		var pes_do_pai := 0
		for outro in pes:
			if _desce_ou_e(esqueleto, outro, pai):
				pes_do_pai += 1
		if pes_do_pai > 1:
			break
		var com_cabeca := false
		for i in esqueleto.get_bone_count():
			if "head" in esqueleto.get_bone_name(i).to_lower() and _desce_ou_e(esqueleto, i, pai):
				com_cabeca = true
				break
		if com_cabeca:
			break
		cadeia.append(pai)
		atual = pai
	return cadeia


static func _desce_ou_e(esqueleto: Skeleton3D, osso: int, ancestral: int) -> bool:
	var a := osso
	while a >= 0:
		if a == ancestral:
			return true
		a = esqueleto.get_bone_parent(a)
	return false


## UMA PASSADA pelo clipe, por modelo: a passada pelos pés (u/s do bicho com o clipe
## em 1×: quanto o pé de apoio anda para trás enquanto está no chão), os quadros em
## que o esqueleto mais se parece com o repouso (onde o bicho congela) e as pernas
## que o clipe não mexe.
func _analisar_o_clipe() -> Dictionary:
	if _esqueleto == null or not animacao.is_inside_tree():
		return {}
	var referencia := pose.global_transform.affine_inverse()
	var pes := achar_os_pes(_esqueleto, referencia * _esqueleto.global_transform)
	if pes.size() < 2:
		return {}
	var clipe := animacao.get_animation(_clipe)
	var amostras := 48
	var passo_tempo := clipe.length / amostras
	var caminhos: Array = []
	var repouso: Array[Vector3] = []
	for pe in pes:
		caminhos.append(PackedVector3Array())
		repouso.append(referencia * (_esqueleto.global_transform * _esqueleto.get_bone_global_rest(pe).origin))
	for k in amostras + 1:
		animacao.seek(k * passo_tempo, true)
		for j in pes.size():
			caminhos[j].append(referencia * (_esqueleto.global_transform * _esqueleto.get_bone_global_pose(pes[j]).origin))
	animacao.seek(0.0, true)
	# No referencial do bicho a frente é +Z: o pé de apoio anda em Z.
	var velocidades: Array[float] = []
	var viagens: Array[float] = []
	var apoios: Array[float] = []
	for j in pes.size():
		var caminho: PackedVector3Array = caminhos[j]
		var baixo := INF
		var alto := -INF
		var z_baixo := INF
		var z_alto := -INF
		for p in caminho:
			baixo = minf(baixo, p.y)
			alto = maxf(alto, p.y)
			z_baixo = minf(z_baixo, p.z)
			z_alto = maxf(z_alto, p.z)
		viagens.append(z_alto - z_baixo)
		var soma := 0.0
		var n := 0
		for k in range(1, caminho.size() - 1):
			if caminho[k].y < baixo + (alto - baixo) * 0.2:
				soma += absf(caminho[k + 1].z - caminho[k - 1].z) / (2.0 * passo_tempo)
				n += 1
		apoios.append(soma / n if n > 0 else 0.0)
	# A passada é a média do apoio dos pés que de fato andam (a pernada de pelo menos
	# `PE_QUE_ANDA` da maior): a perna dura do rig puxava a mediana para baixo.
	var maior_viagem := 0.0
	for v in viagens:
		maior_viagem = maxf(maior_viagem, v)
	for j in pes.size():
		if viagens[j] >= maior_viagem * PE_QUE_ANDA and apoios[j] > 0.005:
			velocidades.append(apoios[j])
	var analise := {"passada": 0.0, "quadros_de_pe": PackedFloat32Array(), "paradas": []}
	if not velocidades.is_empty():
		var media := 0.0
		for v in velocidades:
			media += v / float(velocidades.size())
		analise["passada"] = media
	# Os quadros de pé: mínimos locais da distância dos pés ao repouso, no meio de baixo.
	var distancias := PackedFloat32Array()
	for k in amostras:
		var d := 0.0
		for j in pes.size():
			d += (caminhos[j][k] as Vector3).distance_to(repouso[j])
		distancias.append(d)
	var menor := INF
	var maior := -INF
	for d in distancias:
		menor = minf(menor, d)
		maior = maxf(maior, d)
	var quadros := PackedFloat32Array()
	for k in amostras:
		var antes := distancias[(k + amostras - 1) % amostras]
		var depois := distancias[(k + 1) % amostras]
		if distancias[k] <= antes and distancias[k] < depois and distancias[k] <= menor + (maior - menor) * 0.5:
			quadros.append(k * passo_tempo)
	analise["quadros_de_pe"] = quadros
	analise["paradas"] = _achar_as_pernas_paradas(pes, viagens, repouso)
	return analise


## As pernas que o clipe não mexe: o pé anda menos que `PERNA_PARADA_ABAIXO` da perna do
## meio. Cada uma ganha como parceira a perna que anda em diagonal (frente×lado
## trocados), e guarda a cadeia de ossos dela e a da parceira, do topo para o pé.
func _achar_as_pernas_paradas(pes: Array[int], viagens: Array[float], repouso: Array[Vector3]) -> Array:
	var ordenadas := viagens.duplicate()
	ordenadas.sort()
	var meio: float = ordenadas[ordenadas.size() / 2]
	if meio < 0.02:
		return []
	var centro := Vector3.ZERO
	for p in repouso:
		centro += p / float(repouso.size())
	var paradas: Array = []
	for j in pes.size():
		if viagens[j] >= meio * PERNA_PARADA_ABAIXO:
			continue
		var parceiro := -1
		for outro in pes.size():
			if outro == j or viagens[outro] < meio * 0.6:
				continue
			var oposta: bool = signf(repouso[outro].x - centro.x) == -signf(repouso[j].x - centro.x) \
				and signf(repouso[outro].z - centro.z) == -signf(repouso[j].z - centro.z)
			if oposta and (parceiro < 0 or viagens[outro] > viagens[parceiro]):
				parceiro = outro
		if parceiro < 0:
			continue
		var cadeia := cadeia_da_perna(_esqueleto, pes[j], pes)
		var cadeia_parceira := cadeia_da_perna(_esqueleto, pes[parceiro], pes)
		cadeia.reverse()
		cadeia_parceira.reverse()
		paradas.append({"ossos": cadeia, "parceiros": cadeia_parceira})
	return paradas


func _ligar_as_pernas_paradas(paradas: Array) -> void:
	_paradas.clear()
	if _esqueleto == null or paradas.is_empty():
		return
	# O eixo esquerda-direita do bicho, no referencial do esqueleto.
	_eixo_lateral = (_esqueleto.global_basis.inverse() * (pose.global_basis * Vector3.RIGHT)).normalized()
	for perna: Dictionary in paradas:
		var ossos: Array = perna["ossos"]
		var parceiros: Array = perna["parceiros"]
		var pares: Array[Dictionary] = []
		for k in mini(ossos.size(), parceiros.size()):
			var osso: int = ossos[k]
			var parceiro: int = parceiros[k]
			pares.append({"osso": osso, "parceiro": parceiro, "pai": _esqueleto.get_bone_parent(osso),
				"osso_repouso": _esqueleto.get_bone_global_rest(osso).basis.orthonormalized().get_rotation_quaternion(),
				"parceiro_repouso": _esqueleto.get_bone_global_rest(parceiro).basis.orthonormalized().get_rotation_quaternion()})
		_paradas.append({"pares": pares})


## A perna parada copia o balanço da parceira, osso a osso, do topo para o pé: o giro de
## cada osso dela em torno do eixo esquerda-direita (a parte de giro, a "twist", do desvio
## em relação ao repouso) vai para o osso de mesma altura na perna parada, sobre o
## repouso dele. Roda depois do tocador (o animador é filho mais novo do corpo), por
## isso vale por cima do clipe.
func _mexer_as_pernas_paradas() -> void:
	for perna in _paradas:
		for par in perna["pares"]:
			var agora: Quaternion = _esqueleto.get_bone_global_pose(par["parceiro"]).basis.orthonormalized().get_rotation_quaternion()
			var desvio: Quaternion = agora * (par["parceiro_repouso"] as Quaternion).inverse()
			if desvio.w < 0.0:
				desvio = Quaternion(-desvio.x, -desvio.y, -desvio.z, -desvio.w)
			var giro := 2.0 * atan2(Vector3(desvio.x, desvio.y, desvio.z).dot(_eixo_lateral), desvio.w)
			var alvo := Quaternion(_eixo_lateral, giro) * (par["osso_repouso"] as Quaternion)
			var pai: int = par["pai"]
			if pai >= 0:
				alvo = _esqueleto.get_bone_global_pose(pai).basis.orthonormalized().get_rotation_quaternion().inverse() * alvo
			_esqueleto.set_bone_pose_rotation(par["osso"], alvo)


## O primeiro quadro de pé que o clipe cruzou desde o último quadro de processo, ou
## -1 se ainda não cruzou nenhum. Sem quadro de pé conhecido (ou com o tocador já
## parado), congela onde está.
func _quadro_de_pe_cruzado() -> float:
	var agora := animacao.current_animation_position
	if _quadros_de_pe.is_empty() or not animacao.is_playing():
		return agora
	var antes := _posicao_anterior
	_posicao_anterior = agora
	if antes < 0.0:
		return -1.0
	var comprimento := animacao.get_animation(_clipe).length
	var andou := fposmod(agora - antes, comprimento)
	for quadro in _quadros_de_pe:
		if fposmod(quadro - antes, comprimento) <= andou:
			return quadro
	return -1.0
