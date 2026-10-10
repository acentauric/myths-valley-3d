extends SceneTree
## REDIRECIONAR OS CLIPES DO MIXAMO PARA OS ESQUELETOS TRIPO (#190).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . \
##         --script res://tools/prototipo_3d/mixamo/redirecionar.gd -- --fbx=C:/VIRTUALENVS/myths-valley/mixamo_fbx [--so=pedro] [--medir] [--inventario]
##
## O QUE ENTRA: os FBX do Mixamo (sem pele, 30 quadros por segundo) numa pasta FORA
## do projeto (`--fbx`). Eles não vêm para o repositório: o repositório é público,
## e a licença do Mixamo deixa usar o movimento dentro do jogo, mas não
## redistribuir o arquivo solto. Quem fica no projeto é o resultado: a biblioteca
## de animações de cada morador, já no esqueleto dele
## (`assets/prototipo_3d/personagens/mixamo/<modelo>.res`), que só tem sentido
## tocada naquele corpo. O que cada morador recebe, e de qual FBX, está em
## `data/mixamo_uso.json`; o LEIAME da pasta de saída conta a licença.
##
## COMO REDIRECIONA. O FBX abre em tempo de execução (`FBXDocument`, sem importar
## nada no projeto) e o GLB do morador, pelo catálogo de recursos. Os dois
## esqueletos têm os nomes do Mixamo (`mixamorig_*`, o Tripo os herda), mas não a
## mesma pose de descanso nem os mesmos eixos locais: o Mixamo descansa em T, com
## os ossos alinhados a Y, e o Tripo, quase em T, com os eixos girados. Por isso o
## clipe não se copia osso a osso: ele se transfere NO MUNDO.
##
##   1. Para cada osso, a rotação de alinhamento `A`: a menor rotação que leva a
##      direção do osso no descanso do Tripo (do osso ao filho) à direção dele no
##      descanso do Mixamo. É o "fix silhouette" do redirecionamento do Godot
##      (`SkeletonProfileHumanoid`), feito aqui pelos próprios ossos.
##   2. Em cada quadro, a rotação que o Mixamo deu ao osso no mundo,
##      `D = global_animado * global_de_descanso⁻¹`, vai para o Tripo sobre o
##      osso alinhado: `global_tripo = D * A * descanso_tripo`. A direção de cada
##      osso fica idêntica à do Mixamo; o comprimento fica o do Tripo, e por isso
##      nada estica nem deforma (só há trilhas de rotação, e a posição do quadril).
##   3. O quadril anda o que andou no Mixamo, na escala da altura do quadril. E
##      os pés vão ao chão: a cada quadro o corpo sobe ou desce o que falta para o
##      pé mais baixo do Tripo estar na altura em que o do Mixamo está (pernas de
##      proporção diferente deixariam o pé flutuando ou enterrado).
##   4. No lugar: o clipe em laço não pode andar. O que o quadril se desloca de
##      ponta a ponta do laço é tirado em rampa, e o laço fecha onde começou. E
##      os pés ficam sob a origem do corpo: no laço, o meio dos pés na média do
##      ciclo (a ginga balança para os dois lados); no gesto de uma vez, no
##      primeiro quadro, de onde o parado vem — ou, com `termina_na_origem` no JSON (o
##      levantar do chão), no último, para o corpo terminar de pé onde o jogo o pôs.
##   5. Os pontos de parada do laço (`paradas`, no metadado do clipe): os quadros
##      em que a pose volta à do começo, onde o golpe acabou e o corpo pode voltar
##      ao parado (`authored_animator.parar_no_fim_do_golpe`).
##
## `--medir` só imprime, por clipe, a duração, a altura do quadril e o quanto ele
## e os pés andam — é a conferência da issue (pé plantado, no lugar). E
## `--inventario` imprime os clipes Tripo de cada modelo de morador, a lista que
## o `data/mixamo_uso.json` guarda para o site.
##
## Convenções do SceneTree --script: autoload só por `root.get_node`, e um teto
## de tempo que derruba o processo em vez de deixá-lo girando calado.

const USO := "res://data/mixamo_uso.json"
const PASTA_SAIDA := "res://assets/prototipo_3d/personagens/mixamo/"
const QUADROS_POR_SEGUNDO := 30.0
const TEMPO_LIMITE := 600.0
const PREFIXO := "mixamorig_"
## Os ossos que pisam: o mais baixo deles, em cada quadro, é a altura do pé.
const PES := ["LeftFoot", "LeftToeBase", "LeftToe_End", "RightFoot", "RightToeBase", "RightToe_End"]
## Entre vários filhos, o que dá a direção do osso (o quadril olha a coluna, o
## peito o pescoço, a mão o dedo médio).
const FILHO_PREFERIDO := ["Spine", "Neck", "HandMiddle1"]
## Os ossos que contam na pose para achar os pontos de parada de um laço.
const OSSOS_DA_POSE := ["Hips", "Spine", "Spine1", "LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg", "LeftArm", "RightArm", "LeftForeArm", "RightForeArm"]

var _fbx := ""
var _so := ""
var _medir := false
var _inventario := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(TEMPO_LIMITE).timeout.connect(func() -> void:
		push_error("REDIRECIONAR: passou de %d s sem terminar" % int(TEMPO_LIMITE))
		quit(2))
	for bruto in OS.get_cmdline_user_args():
		var arg := str(bruto)
		if arg.begins_with("--fbx="):
			_fbx = arg.trim_prefix("--fbx=").replace("\\", "/").rstrip("/")
		elif arg.begins_with("--so="):
			_so = arg.trim_prefix("--so=")
		elif arg == "--medir":
			_medir = true
		elif arg == "--inventario":
			_inventario = true
	var uso = JSON.parse_string(FileAccess.get_file_as_string(USO))
	if not (uso is Dictionary):
		push_error("REDIRECIONAR: %s não abre" % USO)
		quit(1)
		return
	if _inventario:
		_imprimir_inventario()
		quit(0)
		return
	if _fbx.is_empty() or not DirAccess.dir_exists_absolute(_fbx):
		push_error("REDIRECIONAR: passe a pasta dos FBX com --fbx=<pasta> (a pasta fica fora do projeto)")
		quit(1)
		return
	var falhas := 0
	for pessoa: Dictionary in (uso as Dictionary).get("personagens", []):
		var modelo := str(pessoa.get("modelo", pessoa.get("id", "")))
		var clipes: Array = pessoa.get("clipes_mixamo", [])
		if clipes.is_empty() or (not _so.is_empty() and _so != str(pessoa.get("id", "")) and _so != modelo):
			continue
		var biblioteca := AnimationLibrary.new()
		for clipe: Dictionary in clipes:
			var animacao := _redirecionar(modelo, _fbx.path_join(str(clipe.get("fbx", ""))), bool(clipe.get("laco", false)), bool(clipe.get("termina_na_origem", false)))
			if animacao == null:
				falhas += 1
				continue
			biblioteca.add_animation(StringName(str(clipe.get("id", ""))), animacao)
		if _medir:
			continue
		var saida := PASTA_SAIDA + modelo + ".res"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA_SAIDA))
		var erro := ResourceSaver.save(biblioteca, saida, ResourceSaver.FLAG_COMPRESS)
		if erro != OK:
			push_error("REDIRECIONAR: não gravou %s (%d)" % [saida, erro])
			falhas += 1
		else:
			print("REDIRECIONAR: %s com %s" % [saida, ", ".join(biblioteca.get_animation_list())])
	print("REDIRECIONAR_OK" if falhas == 0 else "REDIRECIONAR_FALHOU: %d" % falhas)
	quit(0 if falhas == 0 else 1)


## Os clipes Tripo (nome-base, como o `authored_animator` os chama) de cada modelo de morador.
func _imprimir_inventario() -> void:
	var catalogo = load("res://scripts/prototipo_3d/catalogo_assets.gd")
	var pecas: Dictionary = catalogo.PECAS
	for chave: String in pecas:
		var caminho := str((pecas[chave] as Dictionary).get("tripo", ""))
		if not caminho.begins_with("personagens/"):
			continue
		var cena := load("res://assets/prototipo_3d/" + caminho) as PackedScene
		if cena == null:
			continue
		var no := cena.instantiate()
		var nomes: Array[String] = []
		for tocador: AnimationPlayer in no.find_children("*", "AnimationPlayer", true, false):
			for real: StringName in tocador.get_animation_list():
				var base := _nome_base(String(real))
				if not base in nomes:
					nomes.append(base)
		no.free()
		nomes.sort()
		print("INVENTARIO %s %s" % [chave, JSON.stringify(nomes)])


static func _nome_base(nome: String) -> String:
	var regex := RegEx.create_from_string("^(.+)[._]\\d{3}$")
	var achado := regex.search(nome)
	return achado.get_string(1) if achado else nome


## O esqueleto e o tocador de uma cena montada.
func _esqueleto(no: Node) -> Skeleton3D:
	var achados := no.find_children("*", "Skeleton3D", true, false)
	return achados[0] as Skeleton3D if not achados.is_empty() else null


func _tocador(no: Node) -> AnimationPlayer:
	var achados := no.find_children("*", "AnimationPlayer", true, false)
	return achados[0] as AnimationPlayer if not achados.is_empty() else null


## O nome do osso sem o prefixo do Mixamo.
static func _canonico(nome: String) -> String:
	return nome.trim_prefix(PREFIXO)


## Índices por nome canônico.
static func _indices(esqueleto: Skeleton3D) -> Dictionary:
	var indices := {}
	for i in esqueleto.get_bone_count():
		indices[_canonico(esqueleto.get_bone_name(i))] = i
	return indices


## O filho que dá a direção do osso `i` (presente nos dois esqueletos), ou -1.
static func _filho_da_direcao(esqueleto: Skeleton3D, i: int, comuns: Dictionary) -> int:
	var filhos: Array[int] = []
	for filho in esqueleto.get_bone_children(i):
		if comuns.has(_canonico(esqueleto.get_bone_name(filho))):
			filhos.append(filho)
	if filhos.is_empty():
		return -1
	for preferido: String in FILHO_PREFERIDO:
		for filho in filhos:
			if _canonico(esqueleto.get_bone_name(filho)).ends_with(preferido):
				return filho
	return filhos[0]


## As trilhas do clipe de origem, por osso: {"pos": índice, "rot": índice}.
static func _trilhas(animacao: Animation) -> Dictionary:
	var trilhas := {}
	for t in animacao.get_track_count():
		var osso := _canonico(String(animacao.track_get_path(t).get_concatenated_subnames()))
		if osso.is_empty():
			continue
		var entrada: Dictionary = trilhas.get(osso, {})
		if animacao.track_get_type(t) == Animation.TYPE_POSITION_3D:
			entrada["pos"] = t
		elif animacao.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			entrada["rot"] = t
		trilhas[osso] = entrada
	return trilhas


## As transformações globais (no espaço do esqueleto) de todos os ossos, dadas as locais.
static func _globais(esqueleto: Skeleton3D, locais: Array[Transform3D]) -> Array[Transform3D]:
	var globais: Array[Transform3D] = []
	globais.resize(esqueleto.get_bone_count())
	var feitos := PackedByteArray()
	feitos.resize(esqueleto.get_bone_count())
	for i in esqueleto.get_bone_count():
		_global_de(esqueleto, i, locais, globais, feitos)
	return globais


static func _global_de(esqueleto: Skeleton3D, i: int, locais: Array[Transform3D], globais: Array[Transform3D], feitos: PackedByteArray) -> Transform3D:
	if feitos[i] == 1:
		return globais[i]
	var pai := esqueleto.get_bone_parent(i)
	var g := locais[i] if pai < 0 else _global_de(esqueleto, pai, locais, globais, feitos) * locais[i]
	globais[i] = g
	feitos[i] = 1
	return g


## A altura do pé mais baixo numa pose global.
static func _altura_do_pe(indices: Dictionary, globais: Array[Transform3D]) -> float:
	var baixo := INF
	for pe: String in PES:
		if indices.has(pe):
			baixo = minf(baixo, globais[indices[pe]].origin.y)
	return baixo


## O meio dos pés (tornozelos e peitos dos pés) numa pose global.
static func _meio_dos_pes(indices: Dictionary, globais: Array[Transform3D]) -> Vector3:
	var soma := Vector3.ZERO
	var n := 0
	for pe: String in ["LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase"]:
		if indices.has(pe):
			soma += globais[indices[pe]].origin
			n += 1
	return soma / maxi(n, 1)


## O clipe `caminho_fbx` no esqueleto do `modelo` do catálogo, ou null.
func _redirecionar(modelo: String, caminho_fbx: String, em_laco: bool, termina_na_origem: bool = false) -> Animation:
	if not FileAccess.file_exists(caminho_fbx):
		push_error("REDIRECIONAR: falta o FBX %s" % caminho_fbx)
		return null
	var documento := FBXDocument.new()
	var estado := FBXState.new()
	if documento.append_from_file(caminho_fbx, estado) != OK:
		push_error("REDIRECIONAR: o FBX %s não abriu" % caminho_fbx)
		return null
	var origem_cena := documento.generate_scene(estado)
	root.add_child(origem_cena)
	var cena_alvo := load("res://assets/prototipo_3d/personagens/%s_tripo.glb" % modelo) as PackedScene
	if cena_alvo == null:
		push_error("REDIRECIONAR: o modelo %s não tem GLB" % modelo)
		origem_cena.queue_free()
		return null
	var alvo_cena := cena_alvo.instantiate()
	root.add_child(alvo_cena)
	var resultado := _transferir(origem_cena, alvo_cena, caminho_fbx.get_file(), modelo, em_laco, termina_na_origem)
	origem_cena.queue_free()
	alvo_cena.queue_free()
	return resultado


func _transferir(origem_cena: Node, alvo_cena: Node, nome: String, modelo: String, em_laco: bool, termina_na_origem: bool = false) -> Animation:
	var fonte := _esqueleto(origem_cena)
	var alvo := _esqueleto(alvo_cena)
	var tocador_fonte := _tocador(origem_cena)
	var tocador_alvo := _tocador(alvo_cena)
	if fonte == null or alvo == null or tocador_fonte == null or tocador_fonte.get_animation_list().is_empty() or tocador_alvo == null:
		push_error("REDIRECIONAR: %s ou %s sem esqueleto ou sem clipe" % [nome, modelo])
		return null
	var clipe := tocador_fonte.get_animation(tocador_fonte.get_animation_list()[0])
	var trilhas := _trilhas(clipe)
	var indices_fonte := _indices(fonte)
	var indices_alvo := _indices(alvo)
	var comuns := {}
	for osso: String in indices_alvo:
		if indices_fonte.has(osso):
			comuns[osso] = true
	if not comuns.has("Hips"):
		push_error("REDIRECIONAR: %s e %s não têm o quadril em comum" % [nome, modelo])
		return null
	# Descanso dos dois lados.
	var descanso_fonte: Array[Transform3D] = []
	for i in fonte.get_bone_count():
		descanso_fonte.append(fonte.get_bone_rest(i))
	var global_descanso_fonte := _globais(fonte, descanso_fonte)
	var descanso_alvo: Array[Transform3D] = []
	for i in alvo.get_bone_count():
		descanso_alvo.append(alvo.get_bone_rest(i))
	var global_descanso_alvo := _globais(alvo, descanso_alvo)
	# 1. O alinhamento de cada osso do Tripo ao descanso do Mixamo (o pai antes do filho).
	var ordem := _ordem(alvo)
	var alinhamento: Array[Quaternion] = []
	alinhamento.resize(alvo.get_bone_count())
	for i in ordem:
		alinhamento[i] = _alinhamento(alvo, i, indices_fonte, comuns, global_descanso_alvo, global_descanso_fonte, alinhamento)
	var quadril_fonte: int = indices_fonte["Hips"]
	var quadril_alvo: int = indices_alvo["Hips"]
	var chao_fonte := _altura_do_pe(indices_fonte, global_descanso_fonte)
	var chao_alvo := _altura_do_pe(indices_alvo, global_descanso_alvo)
	var escala := (global_descanso_alvo[quadril_alvo].origin.y - chao_alvo) / maxf(global_descanso_fonte[quadril_fonte].origin.y - chao_fonte, 0.001)
	var quadros := maxi(2, int(round(clipe.length * QUADROS_POR_SEGUNDO)) + 1)
	var rotacoes: Array = []   # por quadro, Array[Quaternion] local do alvo
	var quadris: Array[Vector3] = []
	var apoios: Array[Vector3] = []   # por quadro, o meio dos pés do alvo
	var pose_fonte: Array = []   # por quadro, Dictionary osso -> Quaternion local (para as paradas)
	var deslize_fonte := 0.0
	var pe_anterior_fonte := {}
	for k in quadros:
		var tempo := minf(k / QUADROS_POR_SEGUNDO, clipe.length)
		var locais_fonte: Array[Transform3D] = []
		for i in fonte.get_bone_count():
			var local := descanso_fonte[i]
			var osso := _canonico(fonte.get_bone_name(i))
			var entrada: Dictionary = trilhas.get(osso, {})
			if entrada.has("rot"):
				local.basis = Basis(clipe.rotation_track_interpolate(int(entrada["rot"]), tempo))
			if entrada.has("pos"):
				local.origin = clipe.position_track_interpolate(int(entrada["pos"]), tempo)
			locais_fonte.append(local)
		var globais_fonte := _globais(fonte, locais_fonte)
		var pose := {}
		for osso: String in OSSOS_DA_POSE:
			if indices_fonte.has(osso):
				pose[osso] = locais_fonte[indices_fonte[osso]].basis.get_rotation_quaternion()
		pose["_quadril"] = globais_fonte[quadril_fonte].origin
		pose_fonte.append(pose)
		# O deslize do pé no próprio Mixamo, na escala do alvo: a régua do que o alvo pode deslizar.
		for lado: String in ["LeftToeBase", "RightToeBase"]:
			if not indices_fonte.has(lado):
				continue
			var ponto := globais_fonte[indices_fonte[lado]].origin
			var apoiado := ponto.y - chao_fonte < 0.012 / escala
			if apoiado and pe_anterior_fonte.has(lado):
				deslize_fonte = maxf(deslize_fonte, Vector2(ponto.x - (pe_anterior_fonte[lado] as Vector3).x, ponto.z - (pe_anterior_fonte[lado] as Vector3).z).length() * QUADROS_POR_SEGUNDO * escala)
			if apoiado:
				pe_anterior_fonte[lado] = ponto
			else:
				pe_anterior_fonte.erase(lado)
		# 2. A rotação no mundo, osso a osso, sobre o osso alinhado.
		var globais_alvo: Array[Quaternion] = []
		globais_alvo.resize(alvo.get_bone_count())
		var locais_alvo: Array[Quaternion] = []
		locais_alvo.resize(alvo.get_bone_count())
		for i in ordem:
			globais_alvo[i] = _rotacao_alvo(alvo, i, indices_fonte, comuns, globais_fonte, global_descanso_fonte, global_descanso_alvo, descanso_alvo, alinhamento, globais_alvo)
		for i in alvo.get_bone_count():
			var pai := alvo.get_bone_parent(i)
			locais_alvo[i] = globais_alvo[i] if pai < 0 else (globais_alvo[pai].inverse() * globais_alvo[i]).normalized()
		# 3. O quadril, na escala da altura dele, e os pés no chão.
		var desloca := (globais_fonte[quadril_fonte].origin - global_descanso_fonte[quadril_fonte].origin) * escala
		var quadril := descanso_alvo[quadril_alvo].origin + desloca
		var locais_completos: Array[Transform3D] = []
		for i in alvo.get_bone_count():
			locais_completos.append(Transform3D(Basis(locais_alvo[i]), quadril if i == quadril_alvo else descanso_alvo[i].origin))
		var globais_completos := _globais(alvo, locais_completos)
		var pe_alvo := _altura_do_pe(indices_alvo, globais_completos)
		# O pé nunca abaixo do chão (o Mixamo ajoelhado enterra a ponta do pé uns milímetros).
		var pe_desejado := maxf(chao_alvo + (_altura_do_pe(indices_fonte, globais_fonte) - chao_fonte) * escala, chao_alvo)
		quadril.y += pe_desejado - pe_alvo
		rotacoes.append(locais_alvo)
		quadris.append(quadril)
		apoios.append(_meio_dos_pes(indices_alvo, globais_completos))
	# 4. No lugar: o laço fecha onde começou...
	if em_laco and quadros > 1:
		var deriva := quadris[quadros - 1] - quadris[0]
		deriva.y = 0.0
		for k in quadros:
			var parte := deriva * (float(k) / (quadros - 1))
			quadris[k] -= parte
			apoios[k] -= parte
	# ... e os pés ficam sob a origem do corpo: no laço, o meio dos pés na média do
	# ciclo; no gesto de uma vez, no primeiro quadro (de onde o parado vem) ou, com
	# `termina_na_origem`, no último (o levantar do chão termina de pé onde o corpo está).
	var apoio := apoios[quadros - 1] if termina_na_origem and not em_laco else apoios[0]
	if em_laco:
		apoio = Vector3.ZERO
		for ponto in apoios:
			apoio += ponto
		apoio /= apoios.size()
	var acerto := apoio - _meio_dos_pes(indices_alvo, global_descanso_alvo)
	acerto.y = 0.0
	for k in quadros:
		quadris[k] -= acerto
	var animacao := Animation.new()
	animacao.length = (quadros - 1) / QUADROS_POR_SEGUNDO
	animacao.loop_mode = Animation.LOOP_LINEAR if em_laco else Animation.LOOP_NONE
	var raiz := tocador_alvo.get_node(tocador_alvo.root_node)
	var prefixo := String(raiz.get_path_to(alvo))
	var trilha_quadril := animacao.add_track(Animation.TYPE_POSITION_3D)
	animacao.track_set_path(trilha_quadril, NodePath("%s:%s" % [prefixo, alvo.get_bone_name(quadril_alvo)]))
	for k in quadros:
		animacao.position_track_insert_key(trilha_quadril, k / QUADROS_POR_SEGUNDO, quadris[k])
	for i in alvo.get_bone_count():
		var trilha := animacao.add_track(Animation.TYPE_ROTATION_3D)
		animacao.track_set_path(trilha, NodePath("%s:%s" % [prefixo, alvo.get_bone_name(i)]))
		var anterior := Quaternion.IDENTITY
		for k in quadros:
			var q: Quaternion = (rotacoes[k] as Array)[i]
			# Mesmo hemisfério do quadro anterior: a interpolação não dá a volta longa.
			if k > 0 and anterior.dot(q) < 0.0:
				q = -q
			anterior = q
			animacao.rotation_track_insert_key(trilha, k / QUADROS_POR_SEGUNDO, q)
	if em_laco:
		animacao.set_meta("paradas", _paradas(pose_fonte))
	animacao.set_meta("origem", "Mixamo")
	animacao.set_meta("fbx", nome)
	animacao.set_meta("deslize_no_mixamo", deslize_fonte)
	_relatar(nome, modelo, quadris, rotacoes, alvo, indices_alvo, descanso_alvo, chao_alvo, em_laco, animacao)
	return animacao


## Os ossos com o pai sempre antes do filho.
static func _ordem(esqueleto: Skeleton3D) -> Array[int]:
	var ordem: Array[int] = []
	var pendentes: Array[int] = []
	for i in esqueleto.get_bone_count():
		if esqueleto.get_bone_parent(i) < 0:
			pendentes.append(i)
	while not pendentes.is_empty():
		var i: int = pendentes.pop_front()
		ordem.append(i)
		for filho in esqueleto.get_bone_children(i):
			pendentes.append(filho)
	return ordem


## A rotação de alinhamento do osso `i` do alvo (ver o passo 1 no topo). O pai já
## está em `feitos`.
func _alinhamento(alvo: Skeleton3D, i: int, indices_fonte: Dictionary, comuns: Dictionary,
		global_alvo: Array[Transform3D], global_fonte: Array[Transform3D], feitos: Array[Quaternion]) -> Quaternion:
	var osso := _canonico(alvo.get_bone_name(i))
	if not comuns.has(osso):
		return Quaternion.IDENTITY
	var filho := _filho_da_direcao(alvo, i, comuns)
	if filho < 0:
		# Osso da ponta (o fim do dedo, o topo da cabeça): segue o pai.
		var pai := alvo.get_bone_parent(i)
		return feitos[pai] if pai >= 0 else Quaternion.IDENTITY
	var j: int = indices_fonte[osso]
	var jf: int = indices_fonte[_canonico(alvo.get_bone_name(filho))]
	var dir_alvo := global_alvo[filho].origin - global_alvo[i].origin
	var dir_fonte := global_fonte[jf].origin - global_fonte[j].origin
	if dir_alvo.length() < 0.00001 or dir_fonte.length() < 0.00001:
		return Quaternion.IDENTITY
	return Quaternion(dir_alvo.normalized(), dir_fonte.normalized())


## A rotação global do osso `i` do alvo neste quadro. A do pai já está em `globais`.
func _rotacao_alvo(alvo: Skeleton3D, i: int, indices_fonte: Dictionary, comuns: Dictionary,
		globais_fonte: Array[Transform3D], global_descanso_fonte: Array[Transform3D], global_descanso_alvo: Array[Transform3D],
		descanso_alvo: Array[Transform3D], alinhamento: Array[Quaternion], globais: Array[Quaternion]) -> Quaternion:
	var osso := _canonico(alvo.get_bone_name(i))
	if comuns.has(osso):
		var j: int = indices_fonte[osso]
		var animado := globais_fonte[j].basis.get_rotation_quaternion()
		var repouso := global_descanso_fonte[j].basis.get_rotation_quaternion()
		var d := (animado * repouso.inverse()).normalized()
		return (d * alinhamento[i] * global_descanso_alvo[i].basis.get_rotation_quaternion()).normalized()
	# Osso que o Mixamo não tem: segue o pai, no descanso.
	var pai := alvo.get_bone_parent(i)
	var do_pai := Quaternion.IDENTITY if pai < 0 else globais[pai]
	return (do_pai * descanso_alvo[i].basis.get_rotation_quaternion()).normalized()


## OS PONTOS DE PARADA DE UM LAÇO (s): os quadros em que a pose volta à do começo
## (mínimos locais da distância à pose do quadro 0), onde o golpe acabou e o corpo
## pode voltar ao parado sem cortar o movimento no meio. O fim do laço é sempre um.
func _paradas(poses: Array) -> PackedFloat32Array:
	var distancias := PackedFloat32Array()
	var primeira: Dictionary = poses[0]
	for pose: Dictionary in poses:
		var soma := 0.0
		for osso: String in OSSOS_DA_POSE:
			if pose.has(osso) and primeira.has(osso):
				soma += (pose[osso] as Quaternion).angle_to(primeira[osso] as Quaternion)
		soma += ((pose["_quadril"] as Vector3) - (primeira["_quadril"] as Vector3)).length() * 2.0
		distancias.append(soma)
	var maior := 0.0
	for d in distancias:
		maior = maxf(maior, d)
	var paradas := PackedFloat32Array()
	var minimo_entre := int(QUADROS_POR_SEGUNDO * 0.6)
	var ultima := 0
	for k in range(1, distancias.size() - 1):
		if k - ultima < minimo_entre or distancias.size() - 1 - k < minimo_entre:
			continue
		if distancias[k] <= distancias[k - 1] and distancias[k] <= distancias[k + 1] and distancias[k] < maior * 0.2:
			paradas.append(k / QUADROS_POR_SEGUNDO)
			ultima = k
	paradas.append((distancias.size() - 1) / QUADROS_POR_SEGUNDO)
	return paradas


## A conferência (`--medir`, e também a cada gravação): quanto o quadril sobe,
## desce e anda, e quanto o pé mais baixo se afasta do chão.
func _relatar(nome: String, modelo: String, quadris: Array[Vector3], rotacoes: Array, alvo: Skeleton3D,
		indices: Dictionary, descanso: Array[Transform3D], chao: float, em_laco: bool, animacao: Animation) -> void:
	var quadril_alvo: int = indices["Hips"]
	var altura_descanso := descanso[quadril_alvo].origin.y
	var menor_y := INF
	var maior_y := -INF
	var maior_xz := 0.0
	var pe_min := INF
	var pe_max := -INF
	# O pé que desliza: quanto o peito do pé anda no chão enquanto está apoiado.
	var deslize := 0.0
	var anteriores := {}
	for k in quadris.size():
		menor_y = minf(menor_y, quadris[k].y)
		maior_y = maxf(maior_y, quadris[k].y)
		maior_xz = maxf(maior_xz, Vector2(quadris[k].x - descanso[quadril_alvo].origin.x, quadris[k].z - descanso[quadril_alvo].origin.z).length())
		var locais: Array[Transform3D] = []
		for i in alvo.get_bone_count():
			locais.append(Transform3D(Basis((rotacoes[k] as Array)[i] as Quaternion), quadris[k] if i == quadril_alvo else descanso[i].origin))
		var globais := _globais(alvo, locais)
		var pe := _altura_do_pe(indices, globais) - chao
		pe_min = minf(pe_min, pe)
		pe_max = maxf(pe_max, pe)
		for lado: String in ["LeftToeBase", "RightToeBase"]:
			if not indices.has(lado):
				continue
			var ponto := globais[indices[lado]].origin
			var apoiado := ponto.y - chao < 0.012
			if apoiado and anteriores.has(lado):
				deslize = maxf(deslize, Vector2(ponto.x - (anteriores[lado] as Vector3).x, ponto.z - (anteriores[lado] as Vector3).z).length() * QUADROS_POR_SEGUNDO)
			if apoiado:
				anteriores[lado] = ponto
			else:
				anteriores.erase(lado)
	var ponta := Vector2(quadris[quadris.size() - 1].x - quadris[0].x, quadris[quadris.size() - 1].z - quadris[0].z).length()
	# Em unidades do modelo (o GLB tem 0,98 de altura); ×1,8 dá metros de um adulto.
	print("MEDIR %s em %s: %.2f s%s · quadril %.3f..%.3f (descanso %.3f) · afasta %.3f · ponta a ponta %.3f · pé %.3f..%.3f · pé apoiado desliza até %.3f/s (no Mixamo, %.3f/s) · paradas %s" % [
		nome, modelo, animacao.length, " em laço" if em_laco else "", menor_y, maior_y, altura_descanso, maior_xz, ponta,
		pe_min, pe_max, deslize, float(animacao.get_meta("deslize_no_mixamo", 0.0)), str(animacao.get_meta("paradas", PackedFloat32Array()))])
