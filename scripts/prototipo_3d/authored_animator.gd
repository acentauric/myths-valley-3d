extends Node
## Reproduz os clipes incorporados ao GLB do Tripo.

const MOTION_CLIPS := {
	"idle": "idle",
	"walk": "walk",
	"run": "run",
	"swim": "swim",
	"subir_escadas": "run_upstairs",
}

const GESTURES := [
	{"clip": "greet_01", "label": "Saudação"},
	{"clip": "wave_goodbye_02", "label": "Dar tchau"},
	{"clip": "agree", "label": "Concordar"},
	{"clip": "look_around", "label": "Olhar ao redor"},
	{"clip": "afraid", "label": "Com medo"},
	{"clip": "fold_arms", "label": "Cruzar os braços"},
	{"clip": "chop", "label": "Golpear"},
	{"clip": "swim", "label": "Nadar"},
	{"clip": "jump_down", "label": "Pular baixo"},
]

signal golpe_concluido
signal golpe_impacto
signal golpe_cancelado

var animation_player: AnimationPlayer
var _current_motion := ""
## Nome-base → nome real do clipe. O Tripo exporta clipes com sufixo ("walk.001") e o
## Godot os importa como "walk_001", "greet_01_002"; o sufixo de três dígitos some e o
## primeiro clipe de cada nome vence.
var _clips: Dictionary = {}
var _gesture_active := false
var _jump_active := false
var _chop_repetitions_left := 0
var _chop_impacto_emitido := false
var _chop_fase_impacto := IMPACTO_DO_GOLPE
## Na água funda o movimento vira nado (clipe "swim" em laço, se o modelo tiver).
var _swimming := false
## Velocidade de chão (unidades/s, escala 1) de cada clipe de passo, medida pelo pé de
## apoio (ver _medir_passada): a reprodução acompanha o deslocamento e o pé não desliza.
var _passada: Dictionary = {}
var _medido := false
## O TRABALHO EM CURSO (`trabalhar`): o nome do clipe que roda enquanto o corpo está
## parado (a cópia em laço da biblioteca "trabalho", quando o original não é laço).
var _trabalho := ""


func configure(model_root: Node, estabilizar_raiz: bool = false) -> bool:
	var players := model_root.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_warning("O modelo não contém AnimationPlayer; usando animação provisória.")
		return false
	animation_player = players[0] as AnimationPlayer
	animation_player.animation_finished.connect(_on_animation_finished)
	_clips.clear()
	for real: StringName in animation_player.get_animation_list():
		var base := _nome_base(String(real))
		if not _clips.has(base):
			_clips[base] = String(real)
	_congelar_altura_da_pose_de_escada()
	if estabilizar_raiz:
		_estabilizar_raiz_da_locomoção(model_root as Node3D)
	for clip: String in MOTION_CLIPS.values():
		if _clips.has(clip):
			animation_player.get_animation(_clips[clip]).loop_mode = Animation.LOOP_LINEAR
	_play_motion("idle", 1.0)
	return true


## A beata chega com Hips deslocado quase um metro no clipe de corrida.
## A física conduz o corpo: cópias locais preservam as passadas e removem
## esse deslocamento, limitando o balanço vertical a 2,5 cm no mundo.
func _estabilizar_raiz_da_locomoção(modelo: Node3D) -> void:
	if not _clips.has("idle"):
		return
	var parado := animation_player.get_animation(_clips["idle"])
	var biblioteca := AnimationLibrary.new()
	var limite := 0.025 / maxf(absf(modelo.scale.y), 0.001)
	for role in ["walk", "run"]:
		if not _clips.has(role):
			continue
		var copia := animation_player.get_animation(_clips[role]).duplicate() as Animation
		for track in copia.get_track_count():
			if copia.track_get_type(track) != Animation.TYPE_POSITION_3D or not String(copia.track_get_path(track)).to_lower().contains("hips"):
				continue
			var repouso := parado.find_track(copia.track_get_path(track), Animation.TYPE_POSITION_3D)
			if repouso < 0 or parado.track_get_key_count(repouso) == 0 or copia.track_get_key_count(track) == 0:
				continue
			var base: Vector3 = parado.track_get_key_value(repouso, 0)
			var media := 0.0
			for key in copia.track_get_key_count(track):
				media += (copia.track_get_key_value(track, key) as Vector3).y
			media /= copia.track_get_key_count(track)
			for key in copia.track_get_key_count(track):
				var original: Vector3 = copia.track_get_key_value(track, key)
				copia.track_set_key_value(track, key, Vector3(base.x, base.y + clampf(original.y - media, -limite, limite), base.z))
		biblioteca.add_animation(role, copia)
		_clips[role] = "locomocao/" + role
	animation_player.add_animation_library("locomocao", biblioteca)


## O clipe de escada tem movimento vertical no osso Hips, próprio de subir um degrau.
## No nado parado mantemos o balanço dos membros, mas nivelamos esse deslocamento para
## que a animação não tire o personagem da água ao longo do ciclo.
func _congelar_altura_da_pose_de_escada() -> void:
	var clip: String = _clips.get(MOTION_CLIPS["subir_escadas"], "")
	if clip.is_empty():
		return
	var animation := animation_player.get_animation(clip)
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_POSITION_3D:
			continue
		if not String(animation.track_get_path(track)).to_lower().contains("hips"):
			continue
		if animation.track_get_key_count(track) == 0:
			continue
		var altura_base: float = (animation.track_get_key_value(track, 0) as Vector3).y
		for key in animation.track_get_key_count(track):
			var posicao: Vector3 = animation.track_get_key_value(track, key)
			posicao.y = altura_base
			animation.track_set_key_value(track, key, posicao)


## O GOLPE DENTRO DO CLIPE (#112, a sonda da mão de 06/10): `chop_001` dura
## 6,63 s, mas o golpe é só a primeira metade — a mão sobe aos 21 %, bate aos
## 32 % e volta ao repouso aos 50 %; da metade ao fim o corpo fica parado. O
## impacto saía aos 50 % (depois de a mão já estar em repouso) e o corpo ficava
## travado os 6,63 s inteiros (3,5 s na velocidade do golpe): o golpe parecia
## lento e fora do tempo, e quem apertava E de novo era cobrado sem ver nada.
## Agora o impacto sai onde a mão bate, e o golpe termina onde ela volta.
const IMPACTO_DO_GOLPE := 0.325
const FIM_DO_GOLPE := 0.5


func _process(_delta: float) -> void:
	if not chop_ativo():
		return
	var clip := String(_clips.get("chop", ""))
	if clip.is_empty():
		return
	var duracao := animation_player.get_animation(clip).length
	if duracao <= 0.0:
		return
	var posicao := animation_player.current_animation_position
	if not _chop_impacto_emitido and posicao >= duracao * _chop_fase_impacto:
		_chop_impacto_emitido = true
		golpe_impacto.emit()
	# O fim nunca vem antes do impacto pedido (a enxada bate aos 45 %).
	if posicao >= duracao * maxf(FIM_DO_GOLPE, _chop_fase_impacto + 0.05):
		_concluir_o_golpe(clip)


## O golpe acabou (a mão voltou ao repouso): avisa, e repete do começo se ainda
## há repetições, senão volta ao idle.
func _concluir_o_golpe(clip: String) -> void:
	golpe_concluido.emit()
	if _chop_repetitions_left > 1:
		_chop_repetitions_left -= 1
		_chop_impacto_emitido = false
		animation_player.play(clip, 0.08)
		animation_player.seek(0.0, true)
		return
	_chop_repetitions_left = 0
	_gesture_active = false
	_play_motion("idle", 1.0)


func update_motion(speed: float, _delta: float) -> void:
	if animation_player == null:
		return
	if _trabalho != "":
		# Trabalhando, o corpo parado segue no clipe; ao se mover, o trabalho acaba.
		if speed < 0.2 and not _swimming:
			return
		parar_trabalho()
	if _jump_active:
		return
	if _gesture_active:
		if speed < 0.2 and not _swimming:
			return
		if _chop_repetitions_left > 0:
			stop_chop()
		_gesture_active = false

	if not _medido:
		_medido = true
		for role in ["walk", "run"]:
			_passada[role] = _medir_passada(role)
	if _swimming and _clips.has("swim"):
		if speed <= 0.2 and _clips.has(MOTION_CLIPS["subir_escadas"]):
			_play_motion("subir_escadas", 1.0)
		else:
			_play_motion("swim", clampf(0.45 + speed / 2.4, 0.45, 1.6))
	elif speed > _limite_da_corrida():
		_play_motion("run", _escala_da_passada("run", speed, 2.7))
	elif speed > 0.2:
		_play_motion("walk", _escala_da_passada("walk", speed, 0.9))
	else:
		_play_motion("idle", 1.0)


func play_gesture(index: int) -> String:
	if animation_player == null or index < 0 or index >= GESTURES.size():
		return ""
	var entry: Dictionary = GESTURES[index]
	var clip: String = _clips.get(entry["clip"], "")
	if clip.is_empty():
		return ""
	_gesture_active = true
	_chop_repetitions_left = 0
	_jump_active = index == 8
	_current_motion = ""
	animation_player.speed_scale = 4.8 if _jump_active else 1.0
	animation_player.play(clip, 0.18)
	var label: String = entry["label"]
	return label


## A velocidade do clipe de golpe, e quanto um golpe dura (s) do `play_chop` à
## mão de volta ao repouso (FIM_DO_GOLPE) — 0 sem clipe. Quem trava o corpo pelo
## golpe (`recursos_3d`) pergunta, em vez de chutar um teto (#112).
const VELOCIDADE_DO_GOLPE := 1.875


func duracao_do_golpe() -> float:
	if animation_player == null:
		return 0.0
	var clip: String = _clips.get("chop", "")
	if clip.is_empty():
		return 0.0
	return animation_player.get_animation(clip).length * FIM_DO_GOLPE / VELOCIDADE_DO_GOLPE


## `ritmo` e `fase_impacto` são do gesto que pede outro tempo — a enxada bate
## mais devagar e mais tarde (#145); o golpe de sempre usa os do clipe (#112).
func play_chop(repeticoes: int = 2, ritmo: float = VELOCIDADE_DO_GOLPE, fase_impacto: float = IMPACTO_DO_GOLPE) -> String:
	if animation_player == null:
		return ""
	var clip: String = _clips.get("chop", "")
	if clip.is_empty():
		return ""
	animation_player.get_animation(clip).loop_mode = Animation.LOOP_NONE
	_gesture_active = true
	_chop_repetitions_left = maxi(repeticoes, 1)
	_chop_impacto_emitido = false
	_chop_fase_impacto = clampf(fase_impacto, 0.1, 0.9)
	_jump_active = false
	_current_motion = ""
	animation_player.speed_scale = clampf(ritmo, 0.5, 3.0)
	animation_player.play(clip, 0.18)
	return "Golpear"


func gesture_ativa() -> bool:
	return _gesture_active


func chop_ativo() -> bool:
	return _gesture_active and _chop_repetitions_left > 0 and animation_player != null and animation_player.current_animation == StringName(_clips.get("chop", ""))


func fase_do_golpe() -> float:
	if not chop_ativo():
		return -1.0
	var duracao := animation_player.get_animation(animation_player.current_animation).length
	return animation_player.current_animation_position / maxf(duracao, 0.001)


func stop_chop() -> void:
	if _chop_repetitions_left <= 0:
		return
	_chop_repetitions_left = 0
	_gesture_active = false
	golpe_cancelado.emit()
	_play_motion("idle", 1.0)


## Tempo entre dois passos (ou braçadas) do clipe em curso, na velocidade atual; 0 parado.
func step_interval() -> float:
	if animation_player == null or _current_motion in ["", "idle"]:
		return 0.0
	var clip: String = _clips.get(MOTION_CLIPS.get(_current_motion, ""), "")
	if clip.is_empty():
		return 0.0
	return animation_player.get_animation(clip).length * 0.5 / maxf(animation_player.speed_scale, 0.1)


## Acima desta velocidade o passo vira corrida: o andar acelerado além de ESCALA_MAXIMA
## vezes a passada natural pareceria afobado.
const ESCALA_MAXIMA := 2.5


func _limite_da_corrida() -> float:
	var natural: float = _passada.get("walk", 0.0)
	return (natural if natural > 0.05 else 0.9) * ESCALA_MAXIMA


func _escala_da_passada(role: String, speed: float, velocidade_padrao: float) -> float:
	var natural: float = _passada.get(role, 0.0)
	if natural <= 0.05:
		natural = velocidade_padrao
	return clampf(speed / natural, 0.5, ESCALA_MAXIMA)


## Velocidade de chão do clipe: com a animação no lugar, o pé de apoio corre para trás
## na velocidade em que o corpo deveria andar. Amostra o ciclo, acha o eixo do passo
## (a maior variação horizontal dos pés), separa as amostras em que cada pé está no
## ponto mais baixo e tira a velocidade média dele nelas. 0 se não der para medir.
func _medir_passada(role: String) -> float:
	var clip: String = _clips.get(MOTION_CLIPS.get(role, ""), "")
	var esqueletos := animation_player.get_parent().find_children("*", "Skeleton3D", true, false) if animation_player.get_parent() else []
	if clip.is_empty() or esqueletos.is_empty() or not animation_player.is_inside_tree():
		return 0.0
	var esqueleto := esqueletos[0] as Skeleton3D
	var pes: Array[int] = []
	for i in esqueleto.get_bone_count():
		var nome := esqueleto.get_bone_name(i).to_lower()
		if nome.ends_with("foot") and not "toe" in nome:
			pes.append(i)
	if pes.size() < 2:
		return 0.0
	var animacao := animation_player.get_animation(clip)
	var amostras := 48
	var passo_tempo := animacao.length / amostras
	var caminhos: Array = []
	for pe in pes:
		caminhos.append(PackedVector3Array())
	var anterior := animation_player.current_animation
	var escala_antes := animation_player.speed_scale
	animation_player.play(clip)
	for k in amostras + 1:
		animation_player.seek(k * passo_tempo, true)
		for j in pes.size():
			var local := esqueleto.get_bone_global_pose(pes[j]).origin
			caminhos[j].append(esqueleto.global_transform.basis * local)
	# Eixo do passo: a direção horizontal em que os pés mais variam.
	var sxx := 0.0
	var szz := 0.0
	var sxz := 0.0
	for caminho: PackedVector3Array in caminhos:
		var media := Vector3.ZERO
		for p in caminho:
			media += p
		media /= caminho.size()
		for p in caminho:
			sxx += (p.x - media.x) * (p.x - media.x)
			szz += (p.z - media.z) * (p.z - media.z)
			sxz += (p.x - media.x) * (p.z - media.z)
	var angulo := 0.5 * atan2(2.0 * sxz, sxx - szz)
	var eixo := Vector3(cos(angulo), 0.0, sin(angulo))
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
			if caminho[k].y < baixo + (alto - baixo) * 0.15:
				soma += absf((caminho[k + 1] - caminho[k - 1]).dot(eixo)) / (2.0 * passo_tempo)
				n += 1
		if n > 0:
			velocidades.append(soma / n)
	animation_player.speed_scale = escala_antes
	if anterior != &"":
		animation_player.play(anterior)
	_current_motion = ""
	if velocidades.is_empty():
		return 0.0
	var total := 0.0
	for v in velocidades:
		total += v
	return total / velocidades.size()


## O CLIPE DE TRABALHO dos moradores (capinar, lavar, vigiar, rezar...): roda em
## laço enquanto o corpo está parado, e acaba sozinho quando ele anda. Com
## `em_laco` falso o clipe roda uma vez e segura a última pose (sentar). Devolve
## falso quando o modelo não tem o clipe, e o corpo segue em pé.
func trabalhar(clipe: String, em_laco: bool = true) -> bool:
	var real := String(_clips.get(clipe, ""))
	if animation_player == null or real.is_empty():
		return false
	parar_trabalho()
	real = _copia_de_trabalho(real, em_laco)
	_trabalho = real
	_gesture_active = false
	_jump_active = false
	_chop_repetitions_left = 0
	_current_motion = ""
	animation_player.speed_scale = 1.0
	animation_player.play(real, 0.3)
	return true


## O laço do trabalho vai numa CÓPIA do clipe, numa biblioteca só deste corpo. A
## Animation do GLB é um recurso compartilhado entre todas as instâncias do mesmo
## modelo — e o corpo do jogador usa o mesmo `chop`: mudar o loop_mode do original
## deixava o golpe do machado do jogador em laço, sem nunca terminar
## (tests/corte_das_arvores.gd).
func _copia_de_trabalho(real: String, em_laco: bool) -> String:
	var modo := Animation.LOOP_LINEAR if em_laco else Animation.LOOP_NONE
	var original := animation_player.get_animation(real)
	if original == null or original.loop_mode == modo:
		return real
	if not animation_player.has_animation_library("trabalho"):
		animation_player.add_animation_library("trabalho", AnimationLibrary.new())
	var biblioteca := animation_player.get_animation_library("trabalho")
	var chave := real.replace("/", "_") + ("_laco" if em_laco else "_uma")
	if not biblioteca.has_animation(chave):
		var copia := original.duplicate() as Animation
		copia.loop_mode = modo
		biblioteca.add_animation(chave, copia)
	return "trabalho/" + chave


## Larga o trabalho: o clipe volta a ser o que era e o corpo volta ao parado (o
## `update_motion` do quadro seguinte escolhe o passo, se ele anda).
func parar_trabalho() -> void:
	if _trabalho.is_empty():
		return
	_trabalho = ""
	_current_motion = ""


func trabalhando() -> bool:
	return not _trabalho.is_empty()


## DORMIR: o morador longe do jogador anda sem corpo (`npc.gd`, economia): o
## esqueleto não precisa tocar clipe que ninguém vê. Pausado, e não desligado: desligado
## ele volta à pose de fábrica (os braços abertos), e o vale se vê de longe.
## Ao acordar o `update_motion` do quadro seguinte retoma o clipe.
func dormir(dormindo: bool) -> void:
	if animation_player == null:
		return
	if dormindo:
		# Longe, o corpo guarda a última pose. Quem nasce longe do jogador ainda não
		# tocou clipe nenhum: guarda a pose do parado, e nunca a pose T do esqueleto,
		# que se vê do Mirante e do outro lado da praça.
		if String(animation_player.assigned_animation).is_empty():
			var parado := String(_clips.get(MOTION_CLIPS["idle"], ""))
			if not parado.is_empty():
				animation_player.play(parado)
		if not String(animation_player.assigned_animation).is_empty():
			# Aplica a pose do quadro atual antes de parar: quem pausa no mesmo quadro em
			# que o clipe começou (o `configure` toca o parado ao montar) ficava na pose T.
			animation_player.seek(animation_player.current_animation_position, true)
		animation_player.pause()
	elif not animation_player.is_playing() and not String(animation_player.assigned_animation).is_empty():
		# Acordando: o passo volta sozinho no update_motion, mas o clipe de trabalho
		# não (o corpo está parado no posto) — retoma o que estava tocando.
		animation_player.play()


## ACORDAR PARADO (#189): quem dorme tem o processo físico desligado, e o
## `update_motion` não roda para trocar o clipe: o corpo acordava na pose de
## antes (correndo, nadando, de machado na mão). Larga tudo — trabalho, gesto,
## golpe, pulo, nado — e põe o `papel` (o parado; um dia, "levantar da cama") no
## primeiro quadro, sem mistura com o clipe anterior. Devolve o clipe que tocou.
func acordar_parado(papel: String = "idle") -> String:
	if animation_player == null:
		return ""
	if _chop_repetitions_left > 0:
		golpe_cancelado.emit()
	_trabalho = ""
	_gesture_active = false
	_jump_active = false
	_chop_repetitions_left = 0
	_swimming = false
	var clip: String = _clips.get(MOTION_CLIPS.get(papel, papel), "")
	if clip.is_empty():
		clip = _clips.get(MOTION_CLIPS["idle"], "")
		papel = "idle"
	if clip.is_empty():
		return ""
	_current_motion = papel
	animation_player.speed_scale = 1.0
	animation_player.play(clip, 0.0)
	animation_player.seek(0.0, true)
	return clip


func set_swimming(swimming: bool) -> void:
	if _swimming == swimming:
		return
	_swimming = swimming
	_current_motion = ""


func can_swim() -> bool:
	return _clips.has("swim")


func finish_jump(speed: float) -> void:
	if not _jump_active:
		return
	_jump_active = false
	_gesture_active = false
	_current_motion = ""
	update_motion(speed, 0.0)


func get_animation_names() -> PackedStringArray:
	return animation_player.get_animation_list() if animation_player else PackedStringArray()


func get_current_animation() -> StringName:
	return animation_player.current_animation if animation_player else &""


func is_using_authored_clips() -> bool:
	return animation_player != null


func _play_motion(role: String, speed_scale: float) -> void:
	var clip: String = _clips.get(MOTION_CLIPS.get(role, ""), "")
	if clip.is_empty():
		return
	animation_player.speed_scale = speed_scale
	if _current_motion == role and animation_player.is_playing():
		return
	_current_motion = role
	animation_player.play(clip, 0.18)


func _on_animation_finished(animation_name: StringName) -> void:
	if not _gesture_active or _jump_active:
		return
	if _chop_repetitions_left > 0 and String(animation_name) == String(_clips.get("chop", "")):
		golpe_concluido.emit()
	if _chop_repetitions_left > 1 and String(animation_name) == String(_clips.get("chop", "")):
		_chop_repetitions_left -= 1
		_chop_impacto_emitido = false
		animation_player.play(String(animation_name), 0.08)
		return
	_chop_repetitions_left = 0
	_gesture_active = false
	_play_motion("idle", 1.0)


static func _nome_base(nome: String) -> String:
	var regex := RegEx.create_from_string("^(.+)[._]\\d{3}$")
	var achado := regex.search(nome)
	return achado.get_string(1) if achado else nome
