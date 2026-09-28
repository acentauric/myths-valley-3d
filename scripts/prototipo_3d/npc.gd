class_name MoradorNPC
extends CharacterBody3D
## Morador do arraial no 3D: tem posto por período do dia (nome de âncora do cenário),
## caminha entre os postos, olha para quem chega perto e cumprimenta uma vez por
## visita — texto no balão e voz por proximidade (AudioStreamPlayer3D). O corpo é o
## humanoide procedural ou o modelo do Tripo, conforme o estilo escolhido em AJUSTAR.

const BalaoFala = preload("res://scripts/prototipo_3d/balao_fala.gd")
const EspumaAgua = preload("res://scripts/prototipo_3d/espuma_agua.gd")

signal saudou(morador: MoradorNPC, texto: String)

const PASTA_VOZES := "res://assets/audio/vozes/"
const VELOCIDADE := 1.35
const RAIO_SAUDACAO := 3.4
const RAIO_BALAO := 6.0
const INTERVALO_SAUDACAO_MS := 45000
## Duas falas não se atropelam: quem está a menos disto de alguém que ainda fala espera
## a vez (a fila é quem chegou primeiro a pedir a palavra).
const RAIO_CONVERSA := 14.0
## Folga entre o fim de uma fala e o começo da seguinte, em segundos.
const PAUSA_ENTRE_FALAS := 0.6

## Água: como o jogador (player_controller.gd), nada onde o fundo passa do peito.
const NADA_A_PARTIR := 0.72
const ANDA_ATE := 0.66
const SUBMERSO_NADANDO := 0.68
const VELOCIDADE_NADO := 1.4
## O clipe "swim" deita o corpo na altura dos pés: nadando, o modelo sobe esta fração.
const MODELO_ACIMA_NADANDO := 0.44
## Bloqueio: andando sem sair do lugar por TEMPO_PRESO, contorna o obstáculo seguindo
## a parede, sempre para o mesmo lado, por TEMPO_DESVIO × tentativas; depois de
## DESVIOS_MAXIMOS sem se afastar LIVRE_APOS do ponto onde travou, desiste um pouco.
const TEMPO_PRESO := 0.6
const TEMPO_DESVIO := 1.2
const DESVIOS_MAXIMOS := 4
const LIVRE_APOS := 4.0
const PAUSA_DESISTIU := 4.0

## Até quando (ms) cada morador que está falando segura a palavra.
static var _falando: Dictionary = {}

var dados: Dictionary = {}
var ancoras: Dictionary = {}
var jogador: Node3D
var terreno: Node3D
var visual: Node3D
var modelo: Node3D
var animador: Node = null
var nome_label: Label3D
## Balão de fala em tela (balao_fala.gd), numa camada de interface própria.
var balao: Control
var voz: AudioStreamPlayer3D
var altura := 1.7
var intervalo_saudacao_ms := INTERVALO_SAUDACAO_MS
var _alvo := Vector3.ZERO
var _posto := ""
var _ultima_saudacao_ms := -1
var _balao_tempo := 0.0
var _bob := 0.0
var _velocidade_atual := 0.0
var _proxima_fala := 0
var _destino_avulso := Vector3.INF
var _velocidade_avulsa := VELOCIDADE
var _nadando := false
var _preso := 0.0
var _desvio := Vector3.ZERO
var _desvio_tempo := 0.0
var _desvios := 0
var _parado := 0.0
var _lado_desvio := 0.0
var _ponto_bloqueio := Vector3.INF


## Anda até `ponto` (em vez do posto do período), na `velocidade` dada, até liberar().
func ir_ate(ponto: Vector3, velocidade: float = 2.6) -> void:
	_destino_avulso = ponto
	_velocidade_avulsa = velocidade


## Volta ao posto do período.
func liberar() -> void:
	_destino_avulso = Vector3.INF


func configurar(d: Dictionary, anc: Dictionary, alvo_jogador: Node3D, mundo: Node3D = null) -> void:
	dados = d
	ancoras = anc
	jogador = alvo_jogador
	terreno = mundo
	if mundo != null:
		var espuma := EspumaAgua.new()
		espuma.name = "Espuma"
		espuma.mundo = mundo
		add_child(espuma)
	altura = float(d.get("altura", 1.7))
	name = "Morador" + String(d.get("id", "morador")).capitalize()


func _ready() -> void:
	add_to_group("moradores")
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(46)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.26
	capsule.height = altura
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = altura * 0.5
	add_child(collision)
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	_montar_modelo()
	nome_label = Label3D.new()
	nome_label.text = String(dados.get("nome", "Morador"))
	nome_label.font_size = 40
	nome_label.outline_size = 10
	nome_label.pixel_size = 0.0034
	nome_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nome_label.modulate = Color("e8e4d7")
	nome_label.position = Vector3(0, altura + 0.32, 0)
	add_child(nome_label)
	var camada_balao := CanvasLayer.new()
	camada_balao.layer = 10
	add_child(camada_balao)
	balao = BalaoFala.new()
	camada_balao.add_child(balao)
	balao.configurar(self, altura + 0.45, String(dados.get("nome", "Morador")))
	voz = AudioStreamPlayer3D.new()
	voz.name = "Voz"
	voz.max_distance = 30.0
	voz.unit_size = 7.0
	voz.max_db = 6.0
	voz.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	voz.position = Vector3(0, altura * 0.85, 0)
	add_child(voz)
	var saudacao := String(dados.get("saudacao", ""))
	if saudacao != "" and ResourceLoader.exists(PASTA_VOZES + saudacao + ".mp3"):
		voz.stream = load(PASTA_VOZES + saudacao + ".mp3")
	# Começa numa fala qualquer das (até) três, para dois encontros não abrirem igual.
	_proxima_fala = randi() % maxi(1, (dados.get("falas", []) as Array).size())
	_aplicar_volume()
	if Audio.has_signal("volumes_alterados"):
		Audio.volumes_alterados.connect(_aplicar_volume)
	_posto = _posto_para(Dia.periodo())
	_alvo = _posicao_do_posto(_posto)
	if _alvo != Vector3.ZERO:
		global_position = _alvo + Vector3(0, 0.05, 0)


func _aplicar_volume() -> void:
	voz.volume_db = Audio.volume_vozes_db()


func _montar_modelo() -> void:
	var id := String(dados.get("id", "viajante"))
	modelo = null
	animador = null
	if Estilo.tripo():
		var tamanho := 1.0
		if CatalogoAssets.PECAS.has(id) and CatalogoAssets.PECAS[id].has("altura"):
			tamanho = altura / float(CatalogoAssets.PECAS[id]["altura"])
		modelo = CatalogoAssets.instanciar(id, visual, Vector3.ZERO, tamanho, float(dados.get("yaw_modelo", 0.0)))
		if modelo != null and not modelo.find_children("*", "AnimationPlayer", true, false).is_empty():
			# GLB com rig e clipes do Tripo (idle/walk/run + gestos): usa o animador autoral.
			var autoral: Node = load("res://scripts/prototipo_3d/authored_animator.gd").new()
			add_child(autoral)
			autoral.configure(modelo)
			animador = autoral
	if modelo == null:
		var procedural := PersonagemProcedural.novo(id, altura)
		visual.add_child(procedural)
		modelo = procedural
		animador = procedural


func _physics_process(delta: float) -> void:
	var posto := _posto_para(Dia.periodo())
	if posto != _posto:
		_posto = posto
		_alvo = _posicao_do_posto(posto)
	# Destino avulso (ir_ate) vale mais que o posto até ser liberado.
	var destino := _destino_avulso if _destino_avulso.is_finite() else _alvo
	var deslocamento := destino - global_position
	deslocamento.y = 0.0
	var distancia := deslocamento.length()
	var direcao := Vector3.ZERO
	if distancia > (0.2 if _destino_avulso.is_finite() else 0.6):
		direcao = deslocamento / distancia
	_mover(direcao, _velocidade_avulsa if _destino_avulso.is_finite() else VELOCIDADE, delta)
	if direcao == Vector3.ZERO and jogador != null and jogador.global_position.distance_to(global_position) < RAIO_BALAO:
		_olhar_para(jogador.global_position, delta)
	_atualizar_animacao(delta)
	_atualizar_interacao(delta)


## Movimento com gravidade e colisão; vira o corpo para a direção do passo.
func _mover(direcao: Vector3, velocidade: float, delta: float) -> void:
	direcao = _contornar_bloqueio(direcao, delta)
	_atualizar_nado()
	if _nadando:
		velocidade = minf(velocidade, VELOCIDADE_NADO)
	velocity.x = move_toward(velocity.x, direcao.x * velocidade, 12.0 * delta)
	velocity.z = move_toward(velocity.z, direcao.z * velocidade, 12.0 * delta)
	if _nadando:
		var altura_nado: float = terreno.water_level() - altura * SUBMERSO_NADANDO
		velocity.y = clampf((altura_nado - global_position.y) * 5.0, -3.0, 3.0)
		if is_on_floor():
			velocity.y = maxf(velocity.y, 0.0)
	elif not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = -0.1
	move_and_slide()
	_subir_degrau(direcao)
	_medir_bloqueio(direcao, velocidade, delta)
	if direcao.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direcao.x, direcao.z), 1.0 - exp(-9.0 * delta))
	_velocidade_atual = Vector2(velocity.x, velocity.z).length()
	if global_position.y < -6.0:
		global_position = _alvo + Vector3(0, 0.5, 0)
		velocity = Vector3.ZERO


## Bordas baixas (terreiro das casas, meio-fio, praia saindo da água) viram parede para o
## CharacterBody3D: se o que barra o passo cabe em DEGRAU, sobe nele.
const DEGRAU := 0.4


func _subir_degrau(direcao: Vector3) -> void:
	if _nadando or not is_on_wall() or direcao.length_squared() < 0.01 or get_wall_normal().y > 0.3:
		return
	var passo := Vector3(direcao.x, 0.0, direcao.z).normalized() * 0.2
	var em_cima := global_transform.translated(Vector3.UP * DEGRAU)
	if test_move(global_transform, Vector3.UP * DEGRAU) or test_move(em_cima, passo):
		return
	global_position += Vector3.UP * DEGRAU + passo


func _atualizar_nado() -> void:
	if terreno == null or not terreno.has_method("water_depth_at"):
		return
	var nadar: bool = terreno.water_depth_at(global_position) > altura * (ANDA_ATE if _nadando else NADA_A_PARTIR)
	if nadar == _nadando:
		return
	_nadando = nadar
	if animador != null and animador.has_method("set_swimming"):
		animador.set_swimming(_nadando)
	# Sem clipe de nado, o modelo segue de pé, com a água no peito.
	var deita: bool = _nadando and animador != null and animador.has_method("can_swim") and animador.can_swim()
	create_tween().tween_property(visual, "position:y", altura * MODELO_ACIMA_NADANDO if deita else 0.0, 0.35)


## Direção de fato seguida neste quadro: a pedida, o desvio em curso, ou nenhuma
## enquanto o morador está parado depois de desistir.
func _contornar_bloqueio(direcao: Vector3, delta: float) -> Vector3:
	if _parado > 0.0:
		_parado -= delta
		return Vector3.ZERO
	if direcao.length_squared() < 0.01:
		_preso = 0.0
		_desvios = 0
		return direcao
	if _desvio_tempo > 0.0:
		_desvio_tempo -= delta
		return _desvio
	return direcao


## Andando sem sair do lugar (parede, casa, cerca, borda): contorna seguindo a parede;
## depois de várias tentativas sem sair dali, desiste por um tempo e olha em volta.
func _medir_bloqueio(direcao: Vector3, velocidade: float, delta: float) -> void:
	if direcao.length_squared() < 0.01:
		return
	var andou := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if andou > velocidade * 0.3:
		_preso = maxf(_preso - delta, 0.0)
		if _ponto_bloqueio.is_finite() and _desvio_tempo <= 0.0 and global_position.distance_to(_ponto_bloqueio) > LIVRE_APOS:
			_desvios = 0
			_lado_desvio = 0.0
			_ponto_bloqueio = Vector3.INF
		return
	_preso += delta
	if _preso < TEMPO_PRESO:
		return
	_preso = 0.0
	if not _ponto_bloqueio.is_finite():
		_ponto_bloqueio = global_position
	_desvios += 1
	if _desvios > DESVIOS_MAXIMOS:
		_desvios = 0
		_desvio_tempo = 0.0
		_lado_desvio = 0.0
		_ponto_bloqueio = Vector3.INF
		_parado = PAUSA_DESISTIU
		if animador != null and animador.has_method("play_gesture"):
			animador.play_gesture(3)
		return
	var normal := get_wall_normal() if is_on_wall() else -direcao
	normal.y = 0.0
	normal = normal.normalized() if normal.length_squared() > 0.0001 else -direcao
	var tangente := normal.cross(Vector3.UP).normalized()
	if _lado_desvio == 0.0:
		# Primeiro bloqueio: o lado que mais se aproxima do rumo e está livre.
		_lado_desvio = 1.0 if tangente.dot(direcao) >= 0.0 else -1.0
		if test_move(global_transform, tangente * _lado_desvio * 0.6):
			_lado_desvio = -_lado_desvio
	_desvio = (tangente * _lado_desvio + normal * 0.25).normalized()
	_desvio_tempo = TEMPO_DESVIO * _desvios


func _olhar_para(ponto: Vector3, delta: float) -> void:
	var direcao := ponto - global_position
	direcao.y = 0.0
	if direcao.length_squared() < 0.04:
		return
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direcao.x, direcao.z), 1.0 - exp(-6.0 * delta))


func _atualizar_animacao(delta: float) -> void:
	if animador != null and animador.has_method("update_motion"):
		animador.update_motion(_velocidade_atual, delta)
	elif modelo != null:
		# Modelo sem esqueleto: um balanço leve sugere o passo.
		_bob += delta * _velocidade_atual * 6.0
		modelo.position.y = absf(sin(_bob)) * 0.05 * clampf(_velocidade_atual, 0.0, 1.0)
		modelo.rotation.z = sin(_bob) * 0.04 * clampf(_velocidade_atual, 0.0, 1.0)


func _atualizar_interacao(delta: float) -> void:
	if _balao_tempo > 0.0:
		_balao_tempo -= delta
		if _balao_tempo <= 0.0:
			balao.esconder()
			nome_label.visible = true
	if jogador == null:
		return
	var distancia := jogador.global_position.distance_to(global_position)
	if distancia < RAIO_SAUDACAO and (_ultima_saudacao_ms < 0 or Time.get_ticks_msec() - _ultima_saudacao_ms > intervalo_saudacao_ms) and pode_falar():
		saudar()


## Ninguém por perto está no meio de uma fala (Pedro incluído).
func pode_falar() -> bool:
	var agora := Time.get_ticks_msec()
	for outro in _falando.keys():
		if not is_instance_valid(outro) or int(_falando[outro]) <= agora:
			_falando.erase(outro)
		elif outro != self and (outro as Node3D).global_position.distance_to(global_position) < RAIO_CONVERSA:
			return false
	return true


## Marca que este morador segura a palavra por `segundos` (mais a folga).
func _tomar_palavra(segundos: float) -> void:
	_falando[self] = Time.get_ticks_msec() + int((segundos + PAUSA_ENTRE_FALAS) * 1000.0)


func _exit_tree() -> void:
	_falando.erase(self)


## Cumprimenta o jogador: balão com a fala e voz do ElevenLabs por proximidade. Quem
## tem "falas" (até três) alterna entre elas a cada encontro; sem elas, usa "fala".
func saudar() -> void:
	_ultima_saudacao_ms = Time.get_ticks_msec()
	var texto := String(dados.get("fala", ""))
	var falas: Array = dados.get("falas", [])
	if not falas.is_empty():
		var fala: Dictionary = falas[_proxima_fala % falas.size()]
		_proxima_fala += 1
		texto = String(fala.get("texto", ""))
		var caminho := PASTA_VOZES + String(fala.get("audio", "")) + ".mp3"
		voz.stream = load(caminho) if ResourceLoader.exists(caminho) else null
	mostrar_balao(texto, maxf(5.0, voz.stream.get_length() + 1.5) if voz.stream != null else 7.0)
	_tomar_palavra(voz.stream.get_length() if voz.stream != null else 4.0)
	if voz.stream != null:
		voz.stop()
		voz.play()
	if animador != null and animador.has_method("play_gesture"):
		var chave := "gesto_tripo" if animador.has_method("is_using_authored_clips") else "gesto_saudacao"
		animador.play_gesture(int(dados.get(chave, 0)))
	saudou.emit(self, texto)


func mostrar_balao(texto: String, segundos: float) -> void:
	_balao_tempo = segundos
	balao.mostrar(texto)
	# O balão já traz o nome; o rótulo 3D volta quando a fala termina.
	nome_label.visible = texto == ""


## Nome do posto para o período: "manha", "tarde", "entardecer", "noite" ou "madrugada".
func _posto_para(periodo: String) -> String:
	var postos: Dictionary = dados.get("postos", {})
	if postos.has(periodo):
		return periodo
	for alternativa in ["tarde", "manha", "noite", "entardecer", "madrugada"]:
		if postos.has(alternativa):
			return alternativa
	return ""


func _posicao_do_posto(periodo: String) -> Vector3:
	var postos: Dictionary = dados.get("postos", {})
	if periodo == "" or not postos.has(periodo):
		return global_position
	var posto: Array = postos[periodo]
	var ancora_nome := String(posto[0])
	var base: Vector3 = ancoras.get(ancora_nome, Vector3.ZERO)
	if posto.size() > 1 and posto[1] is Array and (posto[1] as Array).size() >= 3:
		var offset: Array = posto[1]
		var deslocamento := Vector3(float(offset[0]), float(offset[1]), float(offset[2]))
		if ancora_nome == "PierPiso":
			var direcao: Vector3 = ancoras.get("PierDirecao", Vector3.FORWARD)
			var yaw := atan2(direcao.x, direcao.z)
			deslocamento = deslocamento.rotated(Vector3.UP, yaw)
		elif ancoras.has(ancora_nome + "Frente"):
			# Deslocamentos das casas estão no referencial delas (porta no +Z).
			var frente: Vector3 = ancoras[ancora_nome + "Frente"]
			deslocamento = deslocamento.rotated(Vector3.UP, atan2(frente.x, frente.z))
		base += deslocamento
		if ancora_nome == "PierPiso":
			return base
		if terreno != null:
			base = terreno.ground_position(base, float(offset[1]))
	return base
