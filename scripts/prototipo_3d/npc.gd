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
## O DIA DA FESTA DA FÉ (#52): da uma da tarde até a meia-noite, quem é da fé
## da festa troca o posto de sempre pela roda no marco maior dela — a hora é a
## do 2D (`Mundo.HORA_DA_TARDE`).
const HORA_DA_FESTA := 13.0
const POSTO_DA_FESTA := "festa"
## O raio da roda em volta de cada marco: fora da caixa do cruzeiro, em volta do
## fogo do terreiro, em cima do monte da gameleira.
const RODA_DA_FESTA := {"cruzeiro": 2.6, "terreiro": 2.5, "gameleira": 3.2}
## Até onde o jogador vê quem anda: mais longe que isto, ou fora da câmera, o
## caminho da festa se encurta (ver `_encurtar_o_caminho`).
const VISTA := 70.0
const VELOCIDADE := 1.35
const RAIO_SAUDACAO := 3.4
const RAIO_BALAO := 6.0
const INTERVALO_SAUDACAO_MS := 45000
## Duas falas não se atropelam: quem está a menos disto de alguém que ainda fala espera
## a vez (a fila é quem chegou primeiro a pedir a palavra). Perto do alcance audível
## da voz (max_distance = 30) para ninguém ouvir duas vozes ao mesmo tempo.
const RAIO_CONVERSA := 18.0
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
## A caminho da festa, ou voltando dela: o caminho que pode se encurtar.
var _caminho_da_festa := false
## O CAMINHO PELA MALHA (`navegacao_vale.gd`): os pontos até o destino, o da
## vez, para onde ele foi feito e quando refazer. Sem malha, anda-se reto.
var _caminho: PackedVector3Array = PackedVector3Array()
var _ponto_da_vez := 0
var _caminho_ate := Vector3.INF
var _refazer_em := 0.0
## De quanto em quanto tempo o caminho se refaz (o jogador, outro morador e a
## porta aberta mudam o que está no meio), e de que distância o ponto da vez
## conta como alcançado: perto, para o corpo não cortar a quina rumo ao ponto
## seguinte e raspar nela.
const REFAZER_CAMINHO := 4.0
const PONTO_ALCANCADO := 0.35
## DAR PASSAGEM: o passo para fora do caminho e quanto tempo se fica fora dele,
## o bastante para quem empurrou passar. Ver `dar_passagem`.
const PASSAGEM_PASSO := 1.4
const PASSAGEM_DURA := 2.5
var _passagem_ate := Vector3.INF
var _passagem_resta := 0.0


## Anda até `ponto` (em vez do posto do período), na `velocidade` dada, até liberar().
func ir_ate(ponto: Vector3, velocidade: float = 2.6) -> void:
	_destino_avulso = ponto
	_velocidade_avulsa = velocidade


## Volta ao posto do período.
func liberar() -> void:
	_destino_avulso = Vector3.INF


## Já no posto do período, sem andar até ele: a carga de uma partida põe cada
## um onde ele estaria.
func ir_ao_posto_agora() -> void:
	_posto = _posto_de_agora()
	_alvo = _posicao_do_posto(_posto)
	if _alvo != Vector3.ZERO:
		global_position = _alvo + Vector3(0, 0.05, 0)
		velocity = Vector3.ZERO


## DAR PASSAGEM. Morador parado no caminho é parede que fala: o Pedro entrou
## atrás do jogador na casa herdada, parou no vão da porta, e "não consigo mais
## sair de casa". Quem anda contra um morador — o jogador, pelo
## `player_controller._empurrar_quem_barra` — faz ele sair do caminho: DE LADO,
## se há lado; ADIANTE, na direção do empurrão, se o lado é parede — no vão da
## porta, adiante é para fora dela. Fica fora do caminho `PASSAGEM_DURA`
## segundos, e então volta ao que fazia.
func dar_passagem(empurrao: Vector3) -> void:
	if _passagem_resta > 0.0:
		return
	var rumo := Vector3(empurrao.x, 0.0, empurrao.z)
	if rumo.length() < 0.01:
		return
	rumo = rumo.normalized()
	var lado := rumo.cross(Vector3.UP).normalized()
	# Do chão um palmo acima, para o roçar do pé no chão não contar como parede.
	var de := global_transform.translated(Vector3.UP * 0.12)
	for saida in [lado, -lado, rumo, (rumo + lado).normalized(), (rumo - lado).normalized()]:
		var passo: Vector3 = saida * PASSAGEM_PASSO
		if not test_move(de, passo):
			_passagem_ate = global_position + passo
			_passagem_resta = PASSAGEM_DURA
			return


func dando_passagem() -> bool:
	return _passagem_resta > 0.0


## Um pulso de quem está dando passagem: anda até o lugar de fora do caminho e
## espera lá o resto do tempo. Devolve se ainda está dando passagem.
func _andar_dando_passagem(delta: float) -> bool:
	if _passagem_resta <= 0.0:
		return false
	_passagem_resta -= delta
	var falta := _passagem_ate - global_position
	falta.y = 0.0
	var direcao := falta.normalized() if falta.length() > 0.12 else Vector3.ZERO
	_mover(direcao, VELOCIDADE * 1.3, delta)
	return true


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
	_posto = _posto_de_agora()
	_alvo = _posicao_do_posto(_posto)
	if _alvo != Vector3.ZERO:
		global_position = _alvo + Vector3(0, 0.05, 0)


func _aplicar_volume() -> void:
	# Volume próprio do morador (painel PERSONAGENS) por cima do canal de vozes.
	voz.volume_db = Audio.volume_vozes_db() + float(dados.get("volume_voz_db", 0.0))


func _montar_modelo() -> void:
	var id := String(dados.get("id", "viajante"))
	modelo = null
	animador = null
	if Estilo.tripo():
		var tamanho := 1.0
		var spec_modelo: Dictionary = AjustesConteudo.peca(id)
		if spec_modelo.has("altura"):
			tamanho = altura / float(spec_modelo["altura"])
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
	if _andar_dando_passagem(delta):
		_atualizar_animacao(delta)
		_atualizar_interacao(delta)
		return
	var posto := _posto_de_agora()
	if posto != _posto:
		_caminho_da_festa = posto == POSTO_DA_FESTA or _posto == POSTO_DA_FESTA
		_posto = posto
		_alvo = _posicao_do_posto(posto)
	if _caminho_da_festa:
		_encurtar_o_caminho()
	# Destino avulso (ir_ate) vale mais que o posto até ser liberado.
	var destino := _destino_avulso if _destino_avulso.is_finite() else _alvo
	var deslocamento := destino - global_position
	deslocamento.y = 0.0
	var distancia := deslocamento.length()
	var direcao := Vector3.ZERO
	if distancia > (0.2 if _destino_avulso.is_finite() else 0.6):
		# Pela malha, quando há: o rumo é o ponto da vez do caminho, e não o
		# destino em linha reta.
		var rumo := _ponto_do_caminho(destino, delta) - global_position
		rumo.y = 0.0
		direcao = rumo.normalized() if rumo.length() > 0.05 else deslocamento / distancia
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
	# O que o corpo andou de fato (depois das colisões), não o que ele pediu: barrado pelo
	# jogador, pelo píer ou por uma parede, o clipe é de parado, não de andar no lugar.
	_velocidade_atual = Vector2(get_real_velocity().x, get_real_velocity().z).length()
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
	return _por_terra(direcao)


## GENTE DO ARRAIAL NÃO ENTRA NO MAR PARA ENCURTAR CAMINHO.
##
## Era a queixa do Pedro "tentando vir pelo mar": ele andava em LINHA RETA até
## o jogador, e com o jogador no píer a reta passa por cima d'água. O corpo
## sabia nadar, então ele nadava — e ficava batendo na estrutura do píer, que
## é o que se via de fora.
##
## O conserto foi preferência local. Antes de andar, o NPC olha para onde o
## passo vai cair; se cai em água funda, ele tenta ângulos cada vez mais
## abertos até achar chão. Na beira do píer isso o faz seguir a costa até a
## cabeceira, que é o que uma pessoa faria.
##
## O que ela NÃO resolvia — enseada em forma de U podia fazê-lo hesitar na
## boca dela, porque decisão local não vê o mapa inteiro — a malha de
## navegação resolve (`navegacao_vale.gd`): com ela pronta, o rumo é o ponto
## da vez do caminho, que fica em terra. Este olhar continua por baixo, para
## os primeiros segundos, antes de a malha ficar pronta, e para o corpo
## empurrado para fora do caminho.
##
## Quem já está na água não é desviado: NADANDO, o caminho mais curto para
## terra é em frente, e empurrá-lo para os lados o faria circular no mar.
func _por_terra(direcao: Vector3) -> Vector3:
	if _nadando or terreno == null or not terreno.has_method("water_depth_at"):
		return direcao
	if not _fundo(global_position + direcao * PASSO_A_FRENTE):
		return direcao
	# Tenta abrir o ângulo para os dois lados, alternando, até achar chão.
	for grau in [35, -35, 70, -70, 105, -105, 140, -140]:
		var tentativa := direcao.rotated(Vector3.UP, deg_to_rad(float(grau)))
		if not _fundo(global_position + tentativa * PASSO_A_FRENTE):
			return tentativa
	# Cercado de água por todos os lados: segue em frente e nada, que é o que
	# sobra — e é o caso de quem está numa ponta de areia.
	return direcao


## O passo cairia em água funda demais para andar?
func _fundo(ponto: Vector3) -> bool:
	return terreno.water_depth_at(ponto) > altura * NADA_A_PARTIR


## O quanto à frente o NPC olha antes de pisar. Um corpo e meio: perto o
## bastante para a decisão ser sobre o próximo passo, longe o bastante para
## ele não meter o pé na água antes de perceber.
const PASSO_A_FRENTE := 1.6


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


## Alguém (fora este) ainda fala ao alcance de `ponto`: o Pedro usa com a posição do
## jogador para não narrar por cima de uma fala que o jogador está ouvindo.
func fala_perto_de(ponto: Vector3) -> bool:
	var agora := Time.get_ticks_msec()
	for outro in _falando.keys():
		if not is_instance_valid(outro) or int(_falando[outro]) <= agora:
			_falando.erase(outro)
		elif outro != self and (outro as Node3D).global_position.distance_to(ponto) < RAIO_CONVERSA:
			return true
	return false


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


## NARRA UMA FALA: balão, voz do ElevenLabs quando o arquivo existe, e a palavra
## tomada pelo tempo que ela durar.
##
## Nasceu dentro do `guia_pedro.gd`, porque o Pedro era o único morador que
## falava fora da saudação. Subiu para cá quando o Damião ganhou fila de
## missões: cadeia de missões pendurada num morador chama `narrar` nele, e
## morador sem `narrar` conduziria a missão em silêncio — o passo avançaria e o
## jogador não saberia por quê.
##
## A duração vem do próprio áudio quando há áudio, e são quatro segundos quando
## não há. É ela que o `_tomar_palavra` usa para ninguém falar por cima.
func narrar(nome_audio: String, texto: String) -> void:
	mostrar_balao(texto, 8.0)
	var caminho := PASTA_VOZES + nome_audio + ".mp3"
	var duracao := 4.0
	if nome_audio != "" and ResourceLoader.exists(caminho):
		voz.stop()
		voz.stream = load(caminho)
		voz.play()
		duracao = voz.stream.get_length()
	_tomar_palavra(duracao)
	if animador != null and animador.has_method("play_gesture"):
		# Autoral: 2 = concordar; procedural: 2 = apontar.
		animador.play_gesture(2)


## O POSTO DE AGORA, com a festa por cima. No dia da festa da fé do morador
## (`Fe.FESTAS`), da tarde até a meia-noite ele vai para o marco maior dela —
## "à tarde, quem é da fé vai para o marco maior dela" (`Mundo._posto_de` do
## 2D). É o CALENDÁRIO que manda, e não a fé do jogador: a festa acontece no
## arraial quer o jogador seja dela ou não, e quem é dela o encontra lá.
func _posto_de_agora() -> String:
	var festa := Fe.festa_de_hoje()
	if festa != "" and Dia.hora >= HORA_DA_FESTA \
			and Afinidade.fe_de(str(dados.get("id", ""))) == festa \
			and Lugares.resolve(Fe.marco_maior(festa)):
		return POSTO_DA_FESTA
	return _posto_para(Dia.periodo())


## O LUGAR DO MORADOR NA RODA da festa: a roda em volta do marco, repartida por
## igual entre os da fé (`Afinidade.da_fe`), para dois não disputarem o mesmo
## chão. No terreiro a roda é em volta do fogo, metro e meio à frente do meio do
## chão batido, e a gente fica dos lados dele — atrás estão os potes e a parede.
func _lugar_na_festa() -> Vector3:
	var festa := Fe.festa_de_hoje()
	var marco := Fe.marco_maior(festa)
	var centro: Vector3 = Lugares.ponto(marco)
	if not centro.is_finite():
		return global_position
	var frente: Vector3 = ancoras.get(str(Lugares.DE_PARA.get(marco, "")) + "Frente", Vector3.ZERO)
	var base := Vector3.BACK
	if frente.length() > 0.01:
		base = frente.normalized()
		centro += base * 1.5
	var da_fe: Array = Afinidade.da_fe(festa)
	var vez := maxi(da_fe.find(str(dados.get("id", ""))), 0)
	var direcao := base.rotated(Vector3.UP, TAU * (float(vez) + 0.5) / float(maxi(da_fe.size(), 1)))
	var lugar := centro + direcao * float(RODA_DA_FESTA.get(marco, 2.6))
	return _chao_de_verdade(terreno.ground_position(lugar, 0.0) if terreno != null else lugar)


## O CHÃO DE VERDADE no lugar da roda, e não só o do terreno: o monte de concha
## da gameleira é corpo, e não relevo, e quem fosse posto na altura do terreno
## nasceria dentro dele.
func _chao_de_verdade(ponto: Vector3) -> Vector3:
	if not is_inside_tree():
		return ponto
	var pergunta := PhysicsRayQueryParameters3D.create(ponto + Vector3.UP * 3.0, ponto + Vector3.DOWN)
	pergunta.exclude = [get_rid()]
	var achou: Dictionary = get_world_3d().direct_space_state.intersect_ray(pergunta)
	return achou.get("position", ponto)


## O CAMINHO DA FESTA É LONGO. O terreiro e a gameleira ficam longe da vila:
## pela malha de navegação (`navegacao_vale.gd`) o Tonho chega à gameleira
## andando, mas leva a tarde quase inteira desde o píer. Então, LONGE DOS OLHOS
## DO JOGADOR, ele chega pelo caminho de sempre — é posto no lugar dele, como na
## carga do jogo. Visto, anda o que se vê; e não aparece do nada no lugar para
## onde o jogador está olhando. A volta, à meia-noite, é igual.
func _encurtar_o_caminho() -> void:
	if _destino_avulso.is_finite():
		return
	if Vector2(_alvo.x - global_position.x, _alvo.z - global_position.z).length() < 1.0:
		_caminho_da_festa = false
		return
	if _a_vista(global_position) or _a_vista(_alvo):
		return
	global_position = _alvo + Vector3(0, 0.05, 0)
	velocity = Vector3.ZERO
	_preso = 0.0
	_desvios = 0
	_desvio_tempo = 0.0
	_parado = 0.0
	_ponto_bloqueio = Vector3.INF
	_caminho_da_festa = false


## O jogador vê este ponto? Perto dele e na frente da câmera.
func _a_vista(ponto: Vector3) -> bool:
	if jogador == null or jogador.global_position.distance_to(ponto) > VISTA:
		return false
	var camera := get_viewport().get_camera_3d()
	return camera == null or camera.is_position_in_frustum(ponto + Vector3.UP * altura * 0.5)


## O PONTO DA VEZ no caminho pela malha até `destino`: refeito quando o destino
## muda, a cada `REFAZER_CAMINHO` segundos, e quando o corpo empaca. Sem malha
## — ela assa enquanto o vale começa —, ou sem caminho, é o próprio destino.
func _ponto_do_caminho(destino: Vector3, delta: float) -> Vector3:
	var navegacao := get_tree().get_first_node_in_group("navegacao")
	if navegacao == null or not navegacao.esta_pronta():
		return destino
	_refazer_em -= delta
	if _caminho_ate.distance_to(destino) > 0.3 or _refazer_em <= 0.0 or _preso > TEMPO_PRESO * 0.9:
		_caminho = navegacao.caminho(global_position, destino)
		_ponto_da_vez = 1 if _caminho.size() > 1 else 0
		_caminho_ate = destino
		_refazer_em = REFAZER_CAMINHO
	if _caminho.is_empty():
		return destino
	while _ponto_da_vez < _caminho.size() - 1 \
			and Vector2(_caminho[_ponto_da_vez].x - global_position.x, _caminho[_ponto_da_vez].z - global_position.z).length() < PONTO_ALCANCADO:
		_ponto_da_vez += 1
	return destino if _ponto_da_vez >= _caminho.size() - 1 else _caminho[_ponto_da_vez]


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
	if periodo == POSTO_DA_FESTA:
		return _lugar_na_festa()
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
