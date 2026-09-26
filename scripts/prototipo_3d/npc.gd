class_name MoradorNPC
extends CharacterBody3D
## Morador do arraial no 3D: tem posto por período do dia (nome de âncora do cenário),
## caminha entre os postos, olha para quem chega perto e cumprimenta uma vez por
## visita — texto no balão e voz por proximidade (AudioStreamPlayer3D). O corpo é o
## humanoide procedural ou o modelo do Tripo, conforme o estilo escolhido em AJUSTAR.

signal saudou(morador: MoradorNPC, texto: String)

const PASTA_VOZES := "res://assets/audio/vozes/"
const VELOCIDADE := 1.35
const RAIO_SAUDACAO := 3.4
const RAIO_BALAO := 6.0
const INTERVALO_SAUDACAO_MS := 45000

var dados: Dictionary = {}
var ancoras: Dictionary = {}
var jogador: Node3D
var visual: Node3D
var modelo: Node3D
var animador: Node = null
var nome_label: Label3D
var balao: Label3D
var voz: AudioStreamPlayer3D
var altura := 1.7
var intervalo_saudacao_ms := INTERVALO_SAUDACAO_MS
var _alvo := Vector3.ZERO
var _posto := ""
var _ultima_saudacao_ms := -1
var _balao_tempo := 0.0
var _bob := 0.0
var _velocidade_atual := 0.0


func configurar(d: Dictionary, anc: Dictionary, alvo_jogador: Node3D) -> void:
	dados = d
	ancoras = anc
	jogador = alvo_jogador
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
	balao = Label3D.new()
	balao.font_size = 30
	balao.outline_size = 8
	balao.pixel_size = 0.0034
	balao.width = 640.0
	balao.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	balao.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	balao.modulate = Color("f2dc9a")
	balao.position = Vector3(0, altura + 0.72, 0)
	balao.visible = false
	add_child(balao)
	voz = AudioStreamPlayer3D.new()
	voz.name = "Voz"
	voz.max_distance = 22.0
	voz.unit_size = 3.0
	voz.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	voz.position = Vector3(0, altura * 0.85, 0)
	add_child(voz)
	var saudacao := String(dados.get("saudacao", ""))
	if saudacao != "" and ResourceLoader.exists(PASTA_VOZES + saudacao + ".mp3"):
		voz.stream = load(PASTA_VOZES + saudacao + ".mp3")
	_aplicar_volume()
	if Audio.has_signal("volumes_alterados"):
		Audio.volumes_alterados.connect(_aplicar_volume)
	_posto = _posto_para(Dia.periodo())
	_alvo = _posicao_do_posto(_posto)
	if _alvo != Vector3.ZERO:
		global_position = _alvo + Vector3(0, 0.05, 0)


func _aplicar_volume() -> void:
	voz.volume_db = Audio.volume_efeitos_db() + 4.0


func _montar_modelo() -> void:
	var id := String(dados.get("id", "viajante"))
	modelo = null
	animador = null
	if Estilo.tripo():
		var tamanho := 1.0
		if CatalogoAssets.PECAS.has(id) and CatalogoAssets.PECAS[id].has("altura"):
			tamanho = altura / float(CatalogoAssets.PECAS[id]["altura"])
		modelo = CatalogoAssets.instanciar(id, visual, Vector3.ZERO, tamanho, float(dados.get("yaw_modelo", 0.0)))
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
	var deslocamento := _alvo - global_position
	deslocamento.y = 0.0
	var distancia := deslocamento.length()
	var direcao := Vector3.ZERO
	if distancia > 0.6:
		direcao = deslocamento / distancia
	_mover(direcao, VELOCIDADE, delta)
	if direcao == Vector3.ZERO and jogador != null and jogador.global_position.distance_to(global_position) < RAIO_BALAO:
		_olhar_para(jogador.global_position, delta)
	_atualizar_animacao(delta)
	_atualizar_interacao(delta)


## Movimento com gravidade e colisão; vira o corpo para a direção do passo.
func _mover(direcao: Vector3, velocidade: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, direcao.x * velocidade, 12.0 * delta)
	velocity.z = move_toward(velocity.z, direcao.z * velocidade, 12.0 * delta)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = -0.1
	move_and_slide()
	if direcao.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direcao.x, direcao.z), 1.0 - exp(-9.0 * delta))
	_velocidade_atual = Vector2(velocity.x, velocity.z).length()
	if global_position.y < -6.0:
		global_position = _alvo + Vector3(0, 0.5, 0)
		velocity = Vector3.ZERO


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
		balao.visible = _balao_tempo > 0.0
	if jogador == null:
		return
	var distancia := jogador.global_position.distance_to(global_position)
	if distancia < RAIO_SAUDACAO and (_ultima_saudacao_ms < 0 or Time.get_ticks_msec() - _ultima_saudacao_ms > intervalo_saudacao_ms):
		saudar()


## Cumprimenta o jogador: balão com a fala e voz do ElevenLabs por proximidade.
func saudar() -> void:
	_ultima_saudacao_ms = Time.get_ticks_msec()
	var texto := String(dados.get("fala", ""))
	mostrar_balao(texto, 7.0)
	if voz.stream != null:
		voz.stop()
		voz.play()
	if animador != null and animador.has_method("play_gesture"):
		animador.play_gesture(int(dados.get("gesto_saudacao", 0)))
	saudou.emit(self, texto)


func mostrar_balao(texto: String, segundos: float) -> void:
	balao.text = texto
	_balao_tempo = segundos
	balao.visible = texto != ""


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
	var base: Vector3 = ancoras.get(String(posto[0]), Vector3.ZERO)
	if posto.size() > 1 and posto[1] is Array and (posto[1] as Array).size() >= 3:
		var offset: Array = posto[1]
		base += Vector3(float(offset[0]), float(offset[1]), float(offset[2]))
	return base
