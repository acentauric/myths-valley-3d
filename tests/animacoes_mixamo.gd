extends "res://tests/suite/caso.gd"
## AS ANIMAÇÕES DO MIXAMO NOS PERSONAGENS (#190).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste animacoes_mixamo
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
##      idiomas, e o gatilho existe — a ação da rotina do morador (ou o período do
##      posto de quem não tem agenda: "posto:manha"), ou um gatilho com código
##      (`GATILHOS_COM_CODIGO`). O que ainda não tem gatilho no jogo (`pendente`:
##      sentar sem banco, a porta do viajante) fica declarado, com o motivo, e
##      nenhum código o toca. Os 41 clipes aprovados da rodada 2 estão todos
##      e nenhum dos 8 reprovados entrou.
##   3. A POSE PASSA NA CONFERÊNCIA, quadro a quadro, no esqueleto do modelo: só
##      rotações (e a posição do quadril) — nada estica —, o pé nunca abaixo do
##      chão, um pé apoiado em quase todo quadro, o pé apoiado sem deslizar mais
##      que no próprio Mixamo, o laço fechando onde começou e os pés sob a origem
##      do corpo (no lugar).
##   4. O ANIMADOR TOCA COMO O JOGO PEDE: a capoeira só para no fim do golpe, o
##      apontar volta sozinho ao parado, e a linha lançada volta à pesca.
##   5. OS GATILHOS: o morador com o clipe da ação o toca no trabalho (o pescador
##      pesca de vara, a beata reza de joelhos, a Dona Zefa ceifa de manhã) e a
##      variação se intercala (ou sai do parado, no Tonho); o passo da ação, a
##      saudação e a porta de casa; e a regra da capoeira do Pedro (longe,
##      parado, sem condução, missão, conversa nem cômodo, de dia e com espaço).
##   6. O VIAJANTE: o pulo, o soco, o acordar (cama e chão) e o ofegar tocam no
##      animador do jogador, e a pose de acordar de cada motivo é um clipe dele.

const USO := "res://data/mixamo_uso.json"
const PASTA := "res://assets/prototipo_3d/personagens/"
## Os gatilhos com código no jogo (ver o cabeçalho do `mixamo_uso.gd`).
const GATILHOS_COM_CODIGO := ["treino", "conducao", "saudacao", "porta", "passo", "pulo", "soco", "acordar_cama", "acordar_chao", "cansado"]
## Os que esperam algo que o vale ainda não tem: o clipe fica registrado, com o motivo em `pendente`.
const GATILHOS_PENDENTES := ["assento", "porta_do_jogador"]
## A LISTA DA RODADA 2 (a prévia que o Ramon aprovou e reprovou).
const APROVADOS := [
	"beata/kneeling_idle", "beata/praying", "benedito/sitting_idle", "candinha/sitting_idle", "candinha/waving", "damiao/digging",
	"damiao/sitting_talking", "guarda/salute", "guarda/strut_walking", "lavadeira/wiping_sweat", "marisqueira/digging",
	"marisqueira/picking_up", "marisqueira/wiping_sweat", "menina/girl_bench_swing", "menina/happy_walk", "menina/jump",
	"menino/happy_walk", "menino/jump", "mercador/counting", "mercador/sitting_yell", "mestre_saveiro/pulling_rope",
	"mestre_saveiro/strut_walking", "padre/waving", "pedro/capoeira", "pedro/pointing", "pescador/fishing_cast",
	"pescador/fishing_idle", "quirino/pulling_rope", "quituteira/sitting_yell", "quituteira/waving", "rendeira/sitting_idle",
	"sacristao/harvesting", "sacristao/opening_door", "tonho/counting", "viajante/getting_up", "viajante/jump",
	"viajante/opening_door", "viajante/punching", "viajante/stretching_yawn", "viajante/tired_breathing_idle", "zefa/harvesting",
]
const REPROVADOS := [
	"benedito/old_man_idle", "benedito/old_man_walk", "filo/sitting_talking", "quirino/salute", "rendeira/sitting_talking",
	"tonho/writing", "viajante/running_tired", "viajante/waking_up_sitting",
]
const PES := ["LeftFoot", "LeftToeBase", "LeftToe_End", "RightFoot", "RightToeBase", "RightToe_End"]
const QUADROS := 30.0
## OS CLIPES EM QUE O CORPO SAI DO CHÃO OU SE DEITA, e por isso não cumprem a régua do passo: o pulo
## voa uns quadros (`apoio_minimo`) e a criança é mais leve que o viajante no agachar (`folga_do_deslize`);
## a menina no banco balança as pernas sem tocar o chão; quem se levanta de costas apoia a mão no chão
## (`mao_abaixo_do_chao`, quanto ela pode descer abaixo do pé em pé).
const EXCECOES_DE_POSE := {
	"jump": {"apoio_minimo": 0.8, "folga_do_deslize": 1.3},
	"girl_bench_swing": {"apoio_minimo": 0.0},
	"getting_up": {"apoio_minimo": 0.65, "mao_abaixo_do_chao": -0.02},
}

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
		var acoes: Array = ["festa"]
		for entrada: Dictionary in ficha.get("agenda", []):
			acoes.append(str(entrada.get("acao", "")))
		# Quem não tem agenda tem postos por período: a ação é "posto:<período>" (`npc._acao_do_posto`).
		if (ficha.get("agenda", []) as Array).is_empty():
			for periodo: String in ficha.get("postos", {}):
				acoes.append("posto:" + periodo)
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
	var no_jogo: Array = []
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
			no_jogo.append("%s/%s" % [id, nome])
			var acoes: Array = clipe.get("acao", []) if clipe.get("acao", "") is Array else ([str(clipe["acao"])] if str(clipe.get("acao", "")) != "" else [])
			var codigo := str(clipe.get("gatilho_id", ""))
			if clipe.has("pendente"):
				_conferir(str(clipe["pendente"]).length() > 20 and codigo in GATILHOS_PENDENTES and acoes.is_empty(),
					"o clipe '%s' de '%s' é pendente sem o motivo escrito, ou com um gatilho que já existe (%s)" % [nome, id, codigo])
			else:
				_conferir(not codigo in GATILHOS_PENDENTES, "o clipe '%s' de '%s' usa o gatilho pendente '%s' sem declarar o motivo" % [nome, id, codigo])
				_conferir(not acoes.is_empty() or codigo in GATILHOS_COM_CODIGO, "o clipe '%s' de '%s' não tem gatilho no jogo (gatilho '%s')" % [nome, id, codigo])
				_conferir(codigo == "" or codigo in GATILHOS_COM_CODIGO, "o gatilho '%s' do clipe '%s' de '%s' não existe no código" % [codigo, nome, id])
			for acao in acoes:
				_conferir(str(acao) in (agendas.get(id, []) as Array), "o clipe '%s' de '%s' espera a ação '%s', que a rotina dele não tem" % [nome, id, acao])
			if codigo == "passo":
				_conferir(not acoes.is_empty() and bool(clipe.get("laco", false)), "o passo '%s' de '%s' precisa de ação e de laço" % [nome, id])
			if clipe.has("a_cada"):
				_conferir(not acoes.is_empty() and codigo == "", "a variação '%s' de '%s' precisa de uma ação, sem outro gatilho" % [nome, id])
			if clipe.has("a_cada"):
				var faixa: Array = clipe["a_cada"]
				_conferir(faixa.size() == 2 and float(faixa[0]) > 0.0 and float(faixa[1]) >= float(faixa[0]), "o a_cada de '%s' não é [mínimo, máximo]" % nome)
			if biblioteca.has_animation(nome):
				var animacao := biblioteca.get_animation(nome)
				_conferir((animacao.loop_mode == Animation.LOOP_LINEAR) == bool(clipe.get("laco", false)), "o laço de '%s' não é o declarado" % nome)
				_conferir(str(animacao.get_meta("origem", "")) == "Mixamo", "o clipe '%s' não traz a origem" % nome)
				_conferir_pose(modelo, nome, animacao, bool(clipe.get("termina_na_origem", false)))
	_conferir(com_dois >= 3, "a primeira rodada são 2 clipes em 3 personagens; com 2 há %d" % com_dois)
	for chave: String in APROVADOS:
		_conferir(chave in no_jogo, "o clipe aprovado '%s' não está no inventário" % chave)
	for chave: String in REPROVADOS:
		_conferir(not chave in no_jogo, "o clipe reprovado '%s' entrou no inventário" % chave)
	_conferir(no_jogo.size() == APROVADOS.size(), "há %d clipes Mixamo no inventário, e os aprovados são %d" % [no_jogo.size(), APROVADOS.size()])
	var pedro: Array = []
	for clipe: Dictionary in _clipes_de(uso, "pedro"):
		pedro.append(str(clipe.get("id", "")))
	_conferir("capoeira" in pedro and "pointing" in pedro, "o Pedro não tem a capoeira e o apontar (%s)" % [pedro])
	var capoeira := _clipe_de(uso, "pedro", "capoeira")
	_conferir(str(capoeira.get("rotulo", "")) == "Capoeira", "a ficha do Pedro diz '%s', e não 'Capoeira'" % capoeira.get("rotulo", ""))

	# --- 4. O ANIMADOR --------------------------------------------------------------------
	await _conferir_animador()

	# --- 5. OS GATILHOS -------------------------------------------------------------------
	await _conferir_gatilhos()

	# --- 6. A RODADA 2: os moradores e o viajante -------------------------------------------
	await _conferir_moradores_da_rodada_2()
	await _conferir_viajante()

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
func _conferir_pose(modelo: String, nome: String, animacao: Animation, termina_na_origem: bool = false) -> void:
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
	var ultimo_meio := Vector3.ZERO
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
		ultimo_meio = meio
		if k == 0:
			primeiro_meio = meio
			quadril_inicio = pose[quadril].origin
		quadril_fim = pose[quadril].origin
	meios /= quadros
	_conferir(enterrou < 0.006, "%s: o pé entra %.3f no chão" % [rotulo, enterrou])
	var excecao: Dictionary = EXCECOES_DE_POSE.get(nome, {})
	_conferir(float(apoiados) / quadros >= float(excecao.get("apoio_minimo", 0.85)), "%s: pé apoiado em só %d de %d quadros (flutua)" % [rotulo, apoiados, quadros])
	var regua := maxf(float(animacao.get_meta("deslize_no_mixamo", 0.0)) * float(excecao.get("folga_do_deslize", 1.15)), 0.12)
	_conferir(deslize <= regua, "%s: o pé apoiado desliza %.3f/s, mais que o Mixamo (%.3f/s)" % [rotulo, deslize, regua])
	_conferir(mao_baixa > float(excecao.get("mao_abaixo_do_chao", 0.0)), "%s: a mão atravessa o chão (%.3f)" % [rotulo, mao_baixa])
	var centro := meios if animacao.loop_mode == Animation.LOOP_LINEAR else (ultimo_meio if termina_na_origem else primeiro_meio)
	_conferir(Vector2(centro.x - meio_descanso.x, centro.z - meio_descanso.z).length() < 0.03,
		"%s: os pés saem de baixo do corpo (%.3f) — o clipe não está no lugar" % [rotulo, Vector2(centro.x - meio_descanso.x, centro.z - meio_descanso.z).length()])
	if animacao.loop_mode == Animation.LOOP_LINEAR:
		_conferir(Vector2(quadril_fim.x - quadril_inicio.x, quadril_fim.z - quadril_inicio.z).length() < 0.003,
			"%s: o laço anda (o quadril não fecha onde começou)" % rotulo)
	print("POSE %s: %d quadros, pé apoiado em %d, enterra %.3f, desliza %.3f/s (régua %.3f), mão a %.3f do chão" % [rotulo, quadros, apoiados, enterrou, deslize, regua, mao_baixa])
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


## Um morador (só os dados, o animador e o estado de ação) sobre um corpo de verdade.
func _morador(id: String, fichas: Dictionary, corpo: Array):
	var Npc = load("res://scripts/prototipo_3d/npc.gd")
	var morador = Npc.new()
	morador.dados = fichas[id]
	morador.animador = corpo[1]
	return morador


func _soltar(corpo: Array, morador = null) -> void:
	if morador != null:
		morador.free()
	(corpo[0] as Node).queue_free()
	(corpo[1] as Node).queue_free()


## --- 6a. OS MORADORES: a ação do posto, o parado, o passo, a saudação e a porta -----------
func _conferir_moradores_da_rodada_2() -> void:
	var npcs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs_3d.json"))
	var fichas := {}
	for ficha: Dictionary in npcs["moradores"]:
		fichas[str(ficha["id"])] = ficha
	var MixamoUso = load("res://scripts/prototipo_3d/mixamo_uso.gd")

	# Quem só tem postos por período ganha o período como ação, e o JSON diz o que ele faz nele.
	var corpo := _corpo("zefa")
	var zefa = _morador("zefa", fichas, corpo)
	zefa._posto = "manha"
	_conferir(zefa._acao_do_posto() == "posto:manha", "a ação do posto da Dona Zefa de manhã é '%s'" % zefa._acao_do_posto())
	_conferir(zefa._vive_de_postos_com_clipe(), "a Dona Zefa tem clipe de posto e o animador do morador não o sabe")
	zefa._acao = zefa._acao_do_posto()
	zefa._comecar_o_trabalho()
	_conferir((corpo[1] as Node).trabalhando_em() == "harvesting", "de manhã no posto a Dona Zefa toca '%s', e não a foice" % (corpo[1] as Node).trabalhando_em())
	zefa._posto = "noite"
	_conferir(MixamoUso.clipe_da_acao("zefa", zefa._acao_do_posto()) == "", "à noite a Dona Zefa ainda ceifa")
	zefa._posto = "festa"
	_conferir(zefa._acao_do_posto() == "festa", "no dia da festa a ação do posto é '%s'" % zefa._acao_do_posto())
	_soltar(corpo, zefa)
	var cosme = _morador("cosme", fichas, [null, null])
	_conferir(not cosme._vive_de_postos_com_clipe(), "o Cosme, sem clipe de posto, passaria a ser olhado pelo trabalho do posto")
	cosme.free()

	# Quem não trabalha no posto faz a variação do parado, de tempos em tempos (o Tonho conta nos dedos).
	corpo = _corpo("tonho")
	var tonho = _morador("tonho", fichas, corpo)
	tonho._posto = "tarde"
	tonho._acao = tonho._acao_do_posto()
	tonho._gesto_do_parado()
	_conferir(int(tonho._variacao_em_ms) > Time.get_ticks_msec(), "o Tonho não marcou a hora de contar nos dedos")
	_conferir(not (corpo[1] as Node).gesture_ativa(), "o Tonho contou nos dedos antes da hora")
	tonho._variacao_em_ms = Time.get_ticks_msec() - 1
	tonho._gesto_do_parado()
	_conferir((corpo[1] as Node).gesture_ativa() and String((corpo[1] as Node).animation_player.current_animation).contains("counting"), "na hora marcada o Tonho não conta nos dedos")
	_avancar(corpo[1], (corpo[1] as Node).duracao_do_clipe("counting") + 0.2)
	await process_frame
	_conferir(not (corpo[1] as Node).gesture_ativa() and String((corpo[1] as Node).animation_player.current_animation).begins_with("idle"), "depois de contar o Tonho não voltou ao parado")
	tonho._posto = "noite"
	tonho._acao = tonho._acao_do_posto()
	tonho._variacao_em_ms = Time.get_ticks_msec() - 1
	tonho._gesto_do_parado()
	_conferir(not (corpo[1] as Node).gesture_ativa(), "o Tonho conta nos dedos à noite")
	_soltar(corpo, tonho)

	# A ação da rotina: o sacristão capina com a foice; o mercador conta o troco intercalado no balcão.
	corpo = _corpo("sacristao")
	var sacristao = _morador("sacristao", fichas, corpo)
	sacristao._acao = "capinar"
	sacristao._comecar_o_trabalho()
	_conferir((corpo[1] as Node).trabalhando_em() == "harvesting", "capinando o sacristão toca '%s', e não a foice" % (corpo[1] as Node).trabalhando_em())
	# A porta de casa: só quem veio andando, e o corpo some quando o clipe acaba.
	sacristao._acao = "recolhido"
	_conferir(not sacristao._abrindo_a_porta(), "o sacristão abre a porta sem ter vindo andando")
	sacristao._veio_andando = true
	_conferir(sacristao._abrindo_a_porta() and (corpo[1] as Node).gesture_ativa(), "o sacristão não abre a porta ao chegar em casa")
	_conferir(sacristao._abrindo_a_porta(), "o sacristão sumiu antes de acabar de abrir a porta")
	sacristao._porta_ate_ms = Time.get_ticks_msec() - 1
	_conferir(not sacristao._abrindo_a_porta(), "o sacristão não entra depois de abrir a porta")
	_soltar(corpo, sacristao)
	corpo = _corpo("mercador")
	var mercador = _morador("mercador", fichas, corpo)
	mercador._acao = "balcao"
	mercador._comecar_o_trabalho()
	_conferir((corpo[1] as Node).trabalhando_em() == "fold_arms", "no balcão o mercador perdeu os braços cruzados (%s)" % (corpo[1] as Node).trabalhando_em())
	mercador._intercalar_variacao()
	mercador._variacao_em_ms = Time.get_ticks_msec() - 1
	mercador._intercalar_variacao()
	_conferir((corpo[1] as Node).intercalando(), "no balcão o mercador não conta o troco nos dedos")
	_soltar(corpo, mercador)
	# A marisqueira: a pá é o trabalho, e o pegar do chão e o enxugar o suor se intercalam.
	corpo = _corpo("marisqueira")
	var marisqueira = _morador("marisqueira", fichas, corpo)
	marisqueira._acao = "mariscar"
	marisqueira._comecar_o_trabalho()
	_conferir((corpo[1] as Node).trabalhando_em() == "digging", "mariscando ela toca '%s', e não a pá" % (corpo[1] as Node).trabalhando_em())
	_conferir(MixamoUso.variacoes_da_acao("marisqueira", "mariscar").size() == 2, "mariscando ela tem %d variações, e são duas" % MixamoUso.variacoes_da_acao("marisqueira", "mariscar").size())
	_soltar(corpo, marisqueira)

	# O passo da ação: a caminho da brincadeira, da ronda e da festa o corpo anda com o clipe do Mixamo.
	for caso: Array in [["menino", "brincar", "happy_walk"], ["menina", "brincar", "happy_walk"], ["guarda", "vigiar", "strut_walking"], ["mestre_saveiro", "festa", "strut_walking"]]:
		corpo = _corpo(str(caso[0]))
		var morador = _morador(str(caso[0]), fichas, corpo)
		morador._acao = str(caso[1])
		morador._aplicar_o_passo()
		_conferir((corpo[1] as Node).passo_atual() == str(caso[2]), "%s a caminho de '%s' anda com '%s', e não com %s" % [caso[0], caso[1], (corpo[1] as Node).passo_atual(), caso[2]])
		# Mede as passadas (a primeira chamada) e anda um pouco mais depressa que a do passo, sem chegar à corrida.
		(corpo[1] as Node).update_motion(0.4, 0.016)
		var rapido: float = float((corpo[1] as Node)._passada.get("passo", 0.5)) * 1.1
		(corpo[1] as Node).update_motion(rapido, 0.016)
		_conferir(String((corpo[1] as Node).animation_player.current_animation) == "mixamo/" + str(caso[2]), "%s andando toca '%s'" % [caso[0], (corpo[1] as Node).animation_player.current_animation])
		_conferir((corpo[1] as Node).step_interval() > 0.0, "%s: o passo do Mixamo não dá o intervalo entre passos" % caso[0])
		morador._acao = "olhar"
		morador._aplicar_o_passo()
		_conferir((corpo[1] as Node).passo_atual() == "", "%s a caminho de 'olhar' ainda anda com o passo da brincadeira" % caso[0])
		(corpo[1] as Node).update_motion(float((corpo[1] as Node)._passada.get("walk", 0.5)) * 1.1, 0.016)
		_conferir(String((corpo[1] as Node).animation_player.current_animation).begins_with("walk"), "%s no passo de sempre toca '%s'" % [caso[0], (corpo[1] as Node).animation_player.current_animation])
		_soltar(corpo, morador)
		await process_frame

	# A brincadeira: o pulo se intercala com o olhar ao redor.
	corpo = _corpo("menina")
	var menina = _morador("menina", fichas, corpo)
	menina._acao = "brincar"
	menina._comecar_o_trabalho()
	menina._intercalar_variacao()
	menina._variacao_em_ms = Time.get_ticks_msec() - 1
	menina._intercalar_variacao()
	_conferir((corpo[1] as Node).intercalando() and String((corpo[1] as Node).animation_player.current_animation).contains("jump"), "brincando a menina não pula")
	_soltar(corpo, menina)

	# A saudação: o aceno (que dura meio segundo) recomeça até uns dois segundos; a continência é uma só.
	for caso: Array in [["candinha", "waving"], ["padre", "waving"], ["quituteira", "waving"], ["guarda", "salute"]]:
		corpo = _corpo(str(caso[0]))
		var morador = _morador(str(caso[0]), fichas, corpo)
		var animador: Node = corpo[1]
		_conferir(morador._fazer_a_saudacao(int(fichas[str(caso[0])].get("gesto_tripo", 0))), "%s não saudou" % caso[0])
		_conferir(animador.gesture_ativa() and String(animador.animation_player.current_animation).contains(str(caso[1])), "%s saúda com '%s', e não com %s" % [caso[0], animador.animation_player.current_animation, caso[1]])
		var duracao: float = animador.duracao_do_clipe(str(caso[1]))
		var voltas := maxi(1, roundi(2.0 / duracao))
		_avancar(animador, duracao * (voltas - 0.5))
		_conferir(animador.gesture_ativa(), "%s: a saudação acabou antes das %d voltas" % [caso[0], voltas])
		_avancar(animador, duracao * 1.5 + 0.3)
		await process_frame
		_conferir(not animador.gesture_ativa() and String(animador.animation_player.current_animation).begins_with("idle"), "%s: depois da saudação não voltou ao parado" % caso[0])
		_soltar(corpo, morador)
		await process_frame
	# Quem trabalha não larga o ofício para saudar: o aceno se intercala.
	corpo = _corpo("padre")
	var padre = _morador("padre", fichas, corpo)
	padre._acao = "conversar"
	padre._comecar_o_trabalho()
	_conferir(padre._fazer_a_saudacao(0, true) and (corpo[1] as Node).intercalando() and (corpo[1] as Node).trabalhando_em() == "look_around",
		"o padre trabalhando não intercala o aceno no ofício")
	_avancar(corpo[1], (corpo[1] as Node).duracao_do_clipe("waving") * 4.0 + 0.3)
	await process_frame
	_conferir(not (corpo[1] as Node).intercalando() and (corpo[1] as Node).trabalhando_em() == "look_around", "depois do aceno o padre não volta ao ofício")
	_soltar(corpo, padre)
	# Sem clipe do Mixamo a saudação segue no Tripo (e quem trabalha não faz nada, como sempre).
	corpo = _corpo("pescador")
	var pescador = _morador("pescador", fichas, corpo)
	_conferir(pescador._fazer_a_saudacao(0) and (corpo[1] as Node).gesture_ativa(), "o pescador perdeu o gesto de saudação do Tripo")
	_conferir(not pescador._fazer_a_saudacao(0, true), "o pescador trabalhando saudou sem clipe do Mixamo")
	_soltar(corpo, pescador)
	await process_frame


## --- 6b. O VIAJANTE: o pulo, o soco, o ofego e o acordar ---------------------------------------
func _conferir_viajante() -> void:
	var corpo := _corpo("viajante")
	var animador: Node = corpo[1]
	var ap: AnimationPlayer = animador.animation_player
	for clipe in ["jump", "punching", "opening_door", "stretching_yawn", "getting_up", "tired_breathing_idle"]:
		_conferir(clipe in animador.clipes_mixamo(), "o animador do viajante não pendurou '%s'" % clipe)
	# O pulo: o clipe entra no fundo do agachamento e roda mais depressa, e segura a pose até o pouso.
	var rotulo: String = animador.play_gesture(8)
	_conferir(rotulo != "" and String(ap.current_animation) == "mixamo/jump", "o pulo do viajante toca '%s'" % ap.current_animation)
	_conferir(animador._jump_active and is_equal_approx(ap.speed_scale, animador.PULO_RITMO), "o pulo não roda no ritmo do ar")
	_conferir(ap.current_animation_position >= animador.PULO_INICIO - 0.01, "o pulo não entra no fundo do agachamento (%.2f s)" % ap.current_animation_position)
	_avancar(animador, 3.0)
	await process_frame
	_conferir(animador._jump_active and String(ap.assigned_animation) == "mixamo/jump", "o pulo não segura a pose até o pouso")
	animador.finish_jump(0.0)
	await process_frame
	_conferir(not animador._jump_active and String(ap.current_animation).begins_with("idle"), "depois do pouso o viajante não volta ao parado (%s)" % ap.current_animation)
	# O soco: a mão chega ao alvo no tempo do golpe (`Luta.GOLPES` impacto) e o corpo volta ao parado.
	_conferir(animador.soco() and String(ap.current_animation) == "mixamo/punching", "o viajante não soca")
	_conferir(is_equal_approx(ap.current_animation_position, animador.SOCO_INICIO), "o soco não entra na guarda (%.2f s)" % ap.current_animation_position)
	_avancar(animador, animador.duracao_do_clipe("punching") - animador.SOCO_INICIO + 0.2)
	await process_frame
	_conferir(not animador.gesture_ativa() and String(ap.current_animation).begins_with("idle"), "depois do soco o viajante não volta ao parado")
	# O ofego: parado e sem vigor, respira ofegante; andando, o passo de sempre.
	animador.set_cansado(true)
	animador.update_motion(0.0, 0.016)
	_conferir(String(ap.current_animation) == "mixamo/tired_breathing_idle", "sem vigor, parado, o viajante toca '%s'" % ap.current_animation)
	animador.update_motion(1.0, 0.016)
	_conferir(String(ap.current_animation).begins_with("walk"), "sem vigor, andando, o viajante toca '%s'" % ap.current_animation)
	animador.set_cansado(false)
	animador.update_motion(0.0, 0.016)
	_conferir(String(ap.current_animation).begins_with("idle"), "com o vigor de volta o viajante segue ofegante")
	# Acordar: cada motivo tem o clipe dele, que acaba no parado.
	var POSES: Dictionary = load("res://scripts/prototipo_3d/queda.gd").POSE_DE_ACORDAR
	_conferir(POSES.get("cama", "") == "stretching_yawn" and POSES.get("desmaio", "") == "getting_up" and POSES.get("queda", "") == "getting_up",
		"a pose de acordar é %s" % [POSES])
	for motivo: String in POSES:
		var papel := str(POSES[motivo])
		var clipe: String = animador.acordar_parado(papel)
		_conferir(clipe == "mixamo/" + papel and animador.gesture_ativa(), "[%s] acordar toca '%s', e deveria ser o clipe '%s'" % [motivo, clipe, papel])
		_conferir(is_zero_approx(ap.current_animation_position), "[%s] o clipe de acordar não começa do zero" % motivo)
		animador.update_motion(0.0, 0.016)
		_conferir(String(ap.current_animation) == clipe, "[%s] o primeiro update_motion cortou o clipe de acordar" % motivo)
		_avancar(animador, animador.duracao_do_clipe(papel) + 0.3)
		await process_frame
		_conferir(not animador.gesture_ativa() and String(ap.current_animation).begins_with("idle"), "[%s] depois de acordar o viajante não volta ao parado (%s)" % [motivo, ap.current_animation])
	# O corpo sem a biblioteca do Mixamo cai no parado.
	var outro := _corpo("cosme")
	_conferir(String((outro[1] as Node).acordar_parado("getting_up")).begins_with("idle"), "sem a biblioteca do Mixamo o acordar não cai no parado")
	_soltar(outro)
	# O vigor zerado: entra ao zerar e só sai ao recuperar a fração do teto.
	var Jogador = load("res://scripts/prototipo_3d/player_controller.gd")
	var jogador = Jogador.new()
	_conferir(not jogador._vigor_zerado(), "o viajante com o vigor cheio está ofegante")
	jogador.definir_vigor(0.0)
	_conferir(jogador._vigor_zerado(), "o viajante com o vigor zerado não está ofegante")
	jogador.definir_vigor(jogador.vigor_maximo() * jogador.VIGOR_RECUPERADO_DO_OFEGO * 0.5)
	_conferir(jogador._vigor_zerado(), "o viajante parou de ofegar antes de recuperar o fôlego")
	jogador.definir_vigor(jogador.vigor_maximo() * jogador.VIGOR_RECUPERADO_DO_OFEGO + 1.0)
	_conferir(not jogador._vigor_zerado(), "o viajante segue ofegante com o fôlego de volta")
	jogador.free()
	# A luta de mão vazia: o soco; com arma, o golpe de sempre.
	var gd := GDScript.new()
	gd.source_code = "extends Node\nvar animator\nvar visual\n"
	gd.reload()
	var falso = gd.new()
	falso.animator = animador
	var luta = load("res://scripts/prototipo_3d/luta_vale.gd").new()
	luta._player = falso
	_conferir(luta._animar_o_golpe(2, true) and String(ap.current_animation) == "mixamo/punching", "o golpe de mão vazia não é o soco (%s)" % ap.current_animation)
	_avancar(animador, 2.0)
	await process_frame
	_conferir(luta._animar_o_golpe(2, false) and animador.chop_ativo(), "o golpe de arma não é o Golpear")
	luta.free()
	falso.free()
	_soltar(corpo)
	await process_frame
