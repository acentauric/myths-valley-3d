extends SceneTree
## AS ANIMAÇÕES DO MIXAMO NOS PERSONAGENS (#190).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/animacoes_mixamo.gd
##
## Os clipes do Mixamo entram redirecionados para o esqueleto Tripo de cada
## morador (`tools/prototipo_3d/mixamo/redirecionar.gd`), uma biblioteca por
## modelo em `assets/prototipo_3d/personagens/mixamo/`. Cinco perguntas:
##
##   1. O INVENTÁRIO É VERDADE: `data/mixamo_uso.json` traz o catálogo do Mixamo
##      (total e por tipo), todo personagem do vale, e os clipes Tripo de cada um
##      são os que o GLB dele tem de fato.
##   2. CADA CLIPE MIXAMO TEM GATILHO E ESTÁ NO JOGO: está na biblioteca do modelo
##      (e só ele), veio de um FBX baixado, tem rótulo e gatilho nos quatro
##      idiomas, e o gatilho existe — a ação da rotina do morador, ou um gatilho
##      com código (`treino` e `conducao`, do Pedro). A primeira rodada são 2
##      clipes em 3 personagens, o Pedro com a capoeira.
##   3. A POSE PASSA NA CONFERÊNCIA, quadro a quadro, no esqueleto do modelo: só
##      rotações (e a posição do quadril) — nada estica —, o pé nunca abaixo do
##      chão, um pé apoiado em quase todo quadro, o pé apoiado sem deslizar mais
##      que no próprio Mixamo, o laço fechando onde começou e os pés sob a origem
##      do corpo (no lugar).
##   4. O ANIMADOR TOCA COMO O JOGO PEDE: a capoeira só para no fim do golpe, o
##      apontar volta sozinho ao parado, e a linha lançada volta à pesca.
##   5. OS GATILHOS: o morador com o clipe da ação o toca no trabalho (o pescador
##      pesca de vara, a beata reza de joelhos) e a variação se intercala; e a
##      regra da capoeira do Pedro (longe, parado, sem condução, missão, conversa
##      nem cômodo, de dia e com espaço).

const USO := "res://data/mixamo_uso.json"
const PASTA := "res://assets/prototipo_3d/personagens/"
const GATILHOS_COM_CODIGO := ["treino", "conducao"]
const PES := ["LeftFoot", "LeftToeBase", "LeftToe_End", "RightFoot", "RightToeBase", "RightToe_End"]
const QUADROS := 30.0

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("ANIMACOES_MIXAMO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	var uso = JSON.parse_string(FileAccess.get_file_as_string(USO))
	_conferir(uso is Dictionary, "o mixamo_uso.json não abre")
	if not (uso is Dictionary):
		quit(1)
		return
	var npcs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs_3d.json"))
	var agendas := {}
	for ficha: Dictionary in [npcs["guia"]] + (npcs["moradores"] as Array):
		var acoes: Array = []
		for entrada: Dictionary in ficha.get("agenda", []):
			acoes.append(str(entrada.get("acao", "")))
		agendas[str(ficha["id"])] = acoes

	# --- 1. O INVENTÁRIO ---------------------------------------------------------------
	var catalogo: Dictionary = uso.get("catalogo", {})
	_conferir(int(catalogo.get("total_itens", 0)) > 2000, "o catálogo do Mixamo não tem o total levantado")
	_conferir(int(catalogo.get("movimentos", 0)) + int(catalogo.get("pacotes", 0)) == int(catalogo.get("total_itens", -1)),
		"movimentos + pacotes não dão o total do catálogo")
	var baixados := {}
	for b: Dictionary in uso.get("baixados", []):
		baixados[str(b.get("fbx", ""))] = b
	var ids: Array = []
	for pessoa: Dictionary in uso.get("personagens", []):
		ids.append(str(pessoa.get("id", "")))
	for id: String in agendas:
		_conferir(id in ids, "o personagem '%s' do vale não está no inventário" % id)
	_conferir("viajante" in ids, "o viajante não está no inventário")
	for pessoa: Dictionary in uso.get("personagens", []):
		var modelo := str(pessoa.get("modelo", ""))
		var cena := load(PASTA + modelo + "_tripo.glb") as PackedScene
		_conferir(cena != null, "o modelo '%s' não tem GLB" % modelo)
		if cena == null:
			continue
		var no := cena.instantiate()
		var no_glb: Array = []
		for tocador: AnimationPlayer in no.find_children("*", "AnimationPlayer", true, false):
			for real: StringName in tocador.get_animation_list():
				var base := _nome_base(String(real))
				if not base in no_glb:
					no_glb.append(base)
		no.free()
		no_glb.sort()
		var declarados: Array = (pessoa.get("clipes_tripo", []) as Array).duplicate()
		declarados.sort()
		_conferir(no_glb == declarados, "os clipes Tripo de '%s' no inventário (%s) não são os do GLB (%s)" % [modelo, declarados, no_glb])
		for nome in declarados:
			_conferir((uso.get("rotulos_tripo", {}) as Dictionary).has(str(nome)), "o clipe Tripo '%s' não tem rótulo" % nome)

	# --- 2. CADA CLIPE MIXAMO TEM GATILHO E ESTÁ NO JOGO ----------------------------------
	var com_dois := 0
	for pessoa: Dictionary in uso.get("personagens", []):
		var clipes: Array = pessoa.get("clipes_mixamo", [])
		var id := str(pessoa.get("id", ""))
		var modelo := str(pessoa.get("modelo", ""))
		var caminho := PASTA + "mixamo/" + modelo + ".res"
		if clipes.is_empty():
			_conferir(not ResourceLoader.exists(caminho), "'%s' tem biblioteca Mixamo e nenhum clipe declarado" % modelo)
			continue
		com_dois += 1 if clipes.size() >= 2 else 0
		var biblioteca: AnimationLibrary = load(caminho) as AnimationLibrary if ResourceLoader.exists(caminho) else null
		_conferir(biblioteca != null, "falta a biblioteca redirecionada %s" % caminho)
		if biblioteca == null:
			continue
		_conferir(biblioteca.get_animation_list().size() == clipes.size(), "a biblioteca de '%s' tem clipes que o inventário não declara" % modelo)
		for clipe: Dictionary in clipes:
			var nome := str(clipe.get("id", ""))
			_conferir(biblioteca.has_animation(nome), "o clipe '%s' de '%s' não está na biblioteca" % [nome, id])
			_conferir(baixados.has(str(clipe.get("fbx", ""))), "o clipe '%s' não veio de um FBX baixado" % nome)
			for chave in ["rotulo", "rotulo_en", "rotulo_es", "rotulo_zh", "gatilho", "gatilho_en", "gatilho_es", "gatilho_zh"]:
				_conferir(str(clipe.get(chave, "")) != "", "o clipe '%s' sem %s" % [nome, chave])
			var acao := str(clipe.get("acao", ""))
			var codigo := str(clipe.get("gatilho_id", ""))
			_conferir((acao != "" and acao in (agendas.get(id, []) as Array)) or codigo in GATILHOS_COM_CODIGO,
				"o clipe '%s' de '%s' não tem gatilho no jogo (ação '%s' fora da rotina, gatilho '%s')" % [nome, id, acao, codigo])
			if clipe.has("a_cada"):
				var faixa: Array = clipe["a_cada"]
				_conferir(faixa.size() == 2 and float(faixa[0]) > 0.0 and float(faixa[1]) >= float(faixa[0]), "o a_cada de '%s' não é [mínimo, máximo]" % nome)
			if biblioteca.has_animation(nome):
				var animacao := biblioteca.get_animation(nome)
				_conferir((animacao.loop_mode == Animation.LOOP_LINEAR) == bool(clipe.get("laco", false)), "o laço de '%s' não é o declarado" % nome)
				_conferir(str(animacao.get_meta("origem", "")) == "Mixamo", "o clipe '%s' não traz a origem" % nome)
				_conferir_pose(modelo, nome, animacao)
	_conferir(com_dois >= 3, "a primeira rodada são 2 clipes em 3 personagens; com 2 há %d" % com_dois)
	var pedro: Array = []
	for clipe: Dictionary in _clipes_de(uso, "pedro"):
		pedro.append(str(clipe.get("id", "")))
	_conferir("capoeira" in pedro and "pointing" in pedro, "o Pedro não tem a capoeira e o apontar (%s)" % pedro)
	var capoeira := _clipe_de(uso, "pedro", "capoeira")
	_conferir(str(capoeira.get("rotulo", "")) == "Capoeira", "a ficha do Pedro diz '%s', e não 'Capoeira'" % capoeira.get("rotulo", ""))

	# --- 4. O ANIMADOR --------------------------------------------------------------------
	await _conferir_animador()

	# --- 5. OS GATILHOS -------------------------------------------------------------------
	await _conferir_gatilhos()

	print("")
	if falhas == 0:
		print("ANIMACOES_MIXAMO_OK")
	else:
		print("animacoes_mixamo: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


static func _nome_base(nome: String) -> String:
	var achado := RegEx.create_from_string("^(.+)[._]\\d{3}$").search(nome)
	return achado.get_string(1) if achado else nome


func _clipes_de(uso: Dictionary, id: String) -> Array:
	for pessoa: Dictionary in uso.get("personagens", []):
		if str(pessoa.get("id", "")) == id:
			return pessoa.get("clipes_mixamo", [])
	return []


func _clipe_de(uso: Dictionary, id: String, clipe_id: String) -> Dictionary:
	for clipe: Dictionary in _clipes_de(uso, id):
		if str(clipe.get("id", "")) == clipe_id:
			return clipe
	return {}


## --- 3. A POSE, quadro a quadro, pela cinemática do esqueleto do modelo --------------
func _conferir_pose(modelo: String, nome: String, animacao: Animation) -> void:
	var cena := (load(PASTA + modelo + "_tripo.glb") as PackedScene).instantiate()
	root.add_child(cena)
	var esqueleto := cena.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var tocador := cena.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var raiz := tocador.get_node(tocador.root_node)
	var rotulo := "%s em %s" % [nome, modelo]
	# Trilhas: rotação de qualquer osso, posição só do quadril, e todas acham o osso.
	var rotacao := {}
	var quadril_trilha := -1
	var quadril := esqueleto.find_bone("mixamorig_Hips")
	for t in animacao.get_track_count():
		var caminho := animacao.track_get_path(t)
		var osso := esqueleto.find_bone(String(caminho.get_concatenated_subnames()))
		var alvo := raiz.get_node_or_null(NodePath(String(caminho).get_slice(":", 0)))
		_conferir(alvo == esqueleto and osso >= 0, "%s: a trilha %s não acha o osso no esqueleto" % [rotulo, caminho])
		match animacao.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				rotacao[osso] = t
			Animation.TYPE_POSITION_3D:
				_conferir(osso == quadril, "%s: trilha de posição fora do quadril (%s) — o osso estica" % [rotulo, caminho])
				quadril_trilha = t
			_:
				_conferir(false, "%s: trilha de tipo %d — só rotação e a posição do quadril" % [rotulo, animacao.track_get_type(t)])
	var pes: Array[int] = []
	for pe: String in PES:
		var i := esqueleto.find_bone("mixamorig_" + pe)
		if i >= 0:
			pes.append(i)
	var maos: Array[int] = [esqueleto.find_bone("mixamorig_LeftHand"), esqueleto.find_bone("mixamorig_RightHand")]
	var descanso := _pose(esqueleto, animacao, rotacao, -1, -1.0)
	var chao := INF
	for i in pes:
		chao = minf(chao, descanso[i].origin.y)
	var meio_descanso := _meio_dos_pes(esqueleto, descanso)
	var quadros := int(round(animacao.length * QUADROS)) + 1
	var apoiados := 0
	var enterrou := 0.0
	var deslize := 0.0
	var anteriores := {}
	var meios := Vector3.ZERO
	var primeiro_meio := Vector3.ZERO
	var quadril_inicio := Vector3.ZERO
	var quadril_fim := Vector3.ZERO
	var mao_baixa := INF
	for k in quadros:
		var tempo := minf(k / QUADROS, animacao.length)
		var pose := _pose(esqueleto, animacao, rotacao, quadril_trilha, tempo)
		var baixo := INF
		for i in pes:
			baixo = minf(baixo, pose[i].origin.y)
		enterrou = maxf(enterrou, chao - baixo)
		apoiados += 1 if baixo - chao < 0.015 else 0
		for i in maos:
			if i >= 0:
				mao_baixa = minf(mao_baixa, pose[i].origin.y - chao)
		for lado: String in ["LeftToeBase", "RightToeBase"]:
			var i := esqueleto.find_bone("mixamorig_" + lado)
			if i < 0:
				continue
			var ponto := pose[i].origin
			if ponto.y - chao < 0.012:
				if anteriores.has(lado):
					deslize = maxf(deslize, Vector2(ponto.x - (anteriores[lado] as Vector3).x, ponto.z - (anteriores[lado] as Vector3).z).length() * QUADROS)
				anteriores[lado] = ponto
			else:
				anteriores.erase(lado)
		var meio := _meio_dos_pes(esqueleto, pose)
		meios += meio
		if k == 0:
			primeiro_meio = meio
			quadril_inicio = pose[quadril].origin
		quadril_fim = pose[quadril].origin
	meios /= quadros
	_conferir(enterrou < 0.006, "%s: o pé entra %.3f no chão" % [rotulo, enterrou])
	_conferir(float(apoiados) / quadros >= 0.85, "%s: pé apoiado em só %d de %d quadros (flutua)" % [rotulo, apoiados, quadros])
	var regua := maxf(float(animacao.get_meta("deslize_no_mixamo", 0.0)) * 1.15, 0.12)
	_conferir(deslize <= regua, "%s: o pé apoiado desliza %.3f/s, mais que o Mixamo (%.3f/s)" % [rotulo, deslize, regua])
	_conferir(mao_baixa > 0.0, "%s: a mão atravessa o chão" % rotulo)
	var centro := meios if animacao.loop_mode == Animation.LOOP_LINEAR else primeiro_meio
	_conferir(Vector2(centro.x - meio_descanso.x, centro.z - meio_descanso.z).length() < 0.03,
		"%s: os pés saem de baixo do corpo (%.3f) — o clipe não está no lugar" % [rotulo, Vector2(centro.x - meio_descanso.x, centro.z - meio_descanso.z).length()])
	if animacao.loop_mode == Animation.LOOP_LINEAR:
		_conferir(Vector2(quadril_fim.x - quadril_inicio.x, quadril_fim.z - quadril_inicio.z).length() < 0.003,
			"%s: o laço anda (o quadril não fecha onde começou)" % rotulo)
	print("POSE %s: %d quadros, pé apoiado em %d, enterra %.3f, desliza %.3f/s (régua %.3f)" % [rotulo, quadros, apoiados, enterrou, deslize, regua])
	cena.queue_free()


## A pose global (espaço do esqueleto) no instante `tempo`; o descanso com tempo < 0.
func _pose(esqueleto: Skeleton3D, animacao: Animation, rotacao: Dictionary, quadril_trilha: int, tempo: float) -> Array[Transform3D]:
	var globais: Array[Transform3D] = []
	globais.resize(esqueleto.get_bone_count())
	var feitos := PackedByteArray()
	feitos.resize(esqueleto.get_bone_count())
	for i in esqueleto.get_bone_count():
		_global(esqueleto, animacao, rotacao, quadril_trilha, tempo, i, globais, feitos)
	return globais


func _global(esqueleto: Skeleton3D, animacao: Animation, rotacao: Dictionary, quadril_trilha: int, tempo: float,
		i: int, globais: Array[Transform3D], feitos: PackedByteArray) -> Transform3D:
	if feitos[i] == 1:
		return globais[i]
	var local := esqueleto.get_bone_rest(i)
	if tempo >= 0.0:
		if rotacao.has(i):
			local.basis = Basis(animacao.rotation_track_interpolate(int(rotacao[i]), tempo))
		if quadril_trilha >= 0 and esqueleto.get_bone_parent(i) < 0:
			local.origin = animacao.position_track_interpolate(quadril_trilha, tempo)
	var pai := esqueleto.get_bone_parent(i)
	var g := local if pai < 0 else _global(esqueleto, animacao, rotacao, quadril_trilha, tempo, pai, globais, feitos) * local
	globais[i] = g
	feitos[i] = 1
	return g


func _meio_dos_pes(esqueleto: Skeleton3D, pose: Array[Transform3D]) -> Vector3:
	var soma := Vector3.ZERO
	var n := 0
	for pe: String in ["LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase"]:
		var i := esqueleto.find_bone("mixamorig_" + pe)
		if i >= 0:
			soma += pose[i].origin
			n += 1
	return soma / maxi(n, 1)


## Um corpo de verdade (o GLB do modelo) com o animador do jogo e os clipes do Mixamo.
func _corpo(modelo: String) -> Array:
	var cena := (load(PASTA + modelo + "_tripo.glb") as PackedScene).instantiate()
	root.add_child(cena)
	var animador: Node = load("res://scripts/prototipo_3d/authored_animator.gd").new()
	root.add_child(animador)
	animador.configure(cena)
	animador.carregar_mixamo(modelo)
	# O teste conduz o relógio do clipe à mão: nada de quadro do motor no meio.
	animador.set_process(false)
	animador.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return [cena, animador]


func _avancar(animador: Node, segundos: float) -> void:
	var passo := 1.0 / QUADROS
	var feito := 0.0
	while feito < segundos:
		animador.animation_player.advance(passo)
		animador._process(passo)
		feito += passo


## --- 4. O ANIMADOR -----------------------------------------------------------------------
func _conferir_animador() -> void:
	var pedro := _corpo("pedro")
	var animador: Node = pedro[1]
	_conferir("capoeira" in animador.clipes_mixamo() and "pointing" in animador.clipes_mixamo(), "o animador do Pedro não pendurou a capoeira e o apontar")
	# A capoeira só para no fim do golpe.
	_conferir(animador.trabalhar("capoeira", true), "o Pedro não começa a capoeira")
	_avancar(animador, 1.0)
	_conferir(animador.trabalhando_em() == "capoeira", "a capoeira não segue em laço")
	animador.parar_no_fim_do_golpe()
	_conferir(animador.parando(), "parar no fim do golpe não ficou pedido")
	var duracao: float = animador.duracao_do_clipe("capoeira")
	_avancar(animador, 0.5)
	_conferir(animador.trabalhando_em() == "capoeira", "a capoeira cortou o golpe no meio")
	_avancar(animador, duracao)
	_conferir(animador.trabalhando_em() == "" and not animador.parando(), "a capoeira não parou no fim do golpe (%.2f s de clipe)" % duracao)
	_conferir(String(animador.animation_player.current_animation).begins_with("idle"), "depois da capoeira o Pedro não volta ao parado (%s)" % animador.animation_player.current_animation)
	# O apontar acaba sozinho, de volta ao parado.
	_conferir(animador.gesto("pointing"), "o Pedro não aponta")
	_conferir(animador.gesture_ativa(), "o apontar não ficou como gesto")
	_avancar(animador, animador.duracao_do_clipe("pointing") + 0.2)
	await process_frame
	_conferir(not animador.gesture_ativa() and String(animador.animation_player.current_animation).begins_with("idle"), "o apontar não voltou ao parado")
	(pedro[0] as Node).queue_free()
	(pedro[1] as Node).queue_free()
	# A linha lançada volta à pesca.
	var pescador := _corpo("pescador")
	animador = pescador[1]
	_conferir(animador.trabalhar("fishing_idle", true), "o pescador não pesca de vara")
	_conferir(animador.intercalar("fishing_cast"), "o pescador não lança a linha")
	_conferir(animador.intercalando(), "o lançar não ficou intercalado")
	_avancar(animador, animador.duracao_do_clipe("fishing_cast") + 0.2)
	await process_frame
	_conferir(not animador.intercalando() and animador.trabalhando_em() == "fishing_idle", "depois de lançar a linha ele não volta a pescar")
	_conferir(String(animador.animation_player.current_animation).contains("fishing_idle"), "depois de lançar toca %s, e não a pesca" % animador.animation_player.current_animation)
	(pescador[0] as Node).queue_free()
	(pescador[1] as Node).queue_free()
	await process_frame


## --- 5. OS GATILHOS ----------------------------------------------------------------------
func _conferir_gatilhos() -> void:
	var Npc = load("res://scripts/prototipo_3d/npc.gd")
	var npcs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs_3d.json"))
	var fichas := {}
	for ficha: Dictionary in npcs["moradores"]:
		fichas[str(ficha["id"])] = ficha
	for caso: Array in [["pescador", "pescar", "fishing_idle", "fishing_cast"], ["beata", "rezar", "praying", "kneeling_idle"]]:
		var corpo := _corpo(str(caso[0]))
		var animador: Node = corpo[1]
		var morador = Npc.new()
		morador.dados = fichas[str(caso[0])]
		morador.animador = animador
		morador._acao = str(caso[1])
		morador._comecar_o_trabalho()
		_conferir(animador.trabalhando_em() == str(caso[2]), "%s em '%s' toca '%s', e não o %s do Mixamo" % [caso[0], caso[1], animador.trabalhando_em(), caso[2]])
		# A variação: na hora marcada ela se intercala.
		morador._intercalar_variacao()
		_conferir(int(morador._variacao_em_ms) > Time.get_ticks_msec(), "%s: a variação não ficou marcada" % caso[0])
		morador._variacao_em_ms = Time.get_ticks_msec() - 1
		morador._intercalar_variacao()
		_conferir(animador.intercalando(), "%s: na hora marcada o %s não se intercala" % [caso[0], caso[3]])
		morador.free()
		(corpo[0] as Node).queue_free()
		(corpo[1] as Node).queue_free()
	# Quem não tem clipe Mixamo da ação segue no do Tripo.
	var sacristao := _corpo("sacristao")
	var outro = Npc.new()
	outro.dados = fichas["sacristao"]
	outro.animador = sacristao[1]
	outro._acao = "rezar"
	outro._comecar_o_trabalho()
	_conferir((sacristao[1] as Node).trabalhando_em() == "bow", "o sacristão perdeu a reverência do Tripo (%s)" % (sacristao[1] as Node).trabalhando_em())
	outro.free()
	(sacristao[0] as Node).queue_free()
	(sacristao[1] as Node).queue_free()
	# A regra da capoeira do Pedro.
	var Guia = load("res://scripts/prototipo_3d/guia_pedro.gd")
	_conferir(Guia.pode_treinar(20.0, 12.0, true, false, false, false, false, "manha", false), "longe, parado e livre, de manhã, o Pedro não treina")
	_conferir(not Guia.pode_treinar(10.0, 12.0, true, false, false, false, false, "manha", false), "com o jogador a 10 m o treino começa (devia ser além de 12)")
	_conferir(Guia.pode_treinar(10.0, 9.0, true, false, false, false, false, "tarde", false), "com o jogador a 10 m o treino em curso para (devia seguir até 9)")
	_conferir(not Guia.pode_treinar(8.0, 9.0, true, false, false, false, false, "tarde", false), "com o jogador a 8 m o treino segue")
	_conferir(not Guia.pode_treinar(20.0, 12.0, false, false, false, false, false, "manha", false), "andando, o Pedro treina")
	_conferir(not Guia.pode_treinar(20.0, 12.0, true, true, false, false, false, "manha", false), "conduzindo, o Pedro treina")
	_conferir(not Guia.pode_treinar(20.0, 12.0, true, false, true, false, false, "manha", false), "com missão em curso, o Pedro treina")
	_conferir(not Guia.pode_treinar(20.0, 12.0, true, false, false, true, false, "manha", false), "conversando, o Pedro treina")
	_conferir(not Guia.pode_treinar(20.0, 12.0, true, false, false, false, true, "manha", false), "dentro de cômodo, o Pedro treina")
	_conferir(not Guia.pode_treinar(20.0, 12.0, true, false, false, false, false, "noite", false), "de noite, o Pedro treina")
	_conferir(not Guia.pode_treinar(20.0, 12.0, true, false, false, false, false, "manha", true), "com gente perto, o Pedro treina")
	_conferir(float(Guia.TREINO_PARA) >= 8.0 and float(Guia.TREINO_PARA) <= 10.0, "o treino para a %.1f m; a issue pede de 8 a 10" % float(Guia.TREINO_PARA))
	await process_frame
