class_name MoradorNPC
extends CharacterBody3D
## Morador do arraial no 3D: tem posto por período do dia (nome de âncora do cenário),
## caminha entre os postos, olha para quem chega perto e cumprimenta uma vez por
## visita — texto no balão e voz por proximidade (AudioStreamPlayer3D). O corpo é o
## humanoide procedural ou o modelo do Tripo, conforme o estilo escolhido em AJUSTAR.

const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const BalaoFala = preload("res://scripts/prototipo_3d/balao_fala.gd")
const EspumaAgua = preload("res://scripts/prototipo_3d/espuma_agua.gd")
const Vestimenta3D = preload("res://scripts/prototipo_3d/vestimenta_3d.gd")
const FilaDeFalas = preload("res://scripts/prototipo_3d/fila_de_falas.gd")
const FalasDosMoradores = preload("res://scripts/prototipo_3d/falas_dos_moradores.gd")

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
## O grupo das cadeias de missões (`CadeiaDeMissoes.GRUPO`), pelo nome: o
## preload daquele script aqui faria os dois se carregarem um ao outro.
const GRUPO_DAS_CADEIAS := &"cadeias_de_missoes"
const RAIO_BALAO := 6.0
const INTERVALO_SAUDACAO_MS := 45000
## Até onde a conversa segura o relógio (`_segurar_o_relogio`) e, sem a fila de
## falas no vale (um portão que monta um morador só), o raio da palavra antiga.
## No vale quem decide a vez é a fila (`fila_de_falas.gd`): uma fala de cada vez.
const RAIO_CONVERSA := 18.0
## Folga entre o fim de uma fala e o começo da seguinte, em segundos (a palavra
## antiga, sem fila; com ela, `FilaDeFalas.RESPIRO`).
const PAUSA_ENTRE_FALAS := 0.6
## O cinza das peças provisórias (a oficina, o caititu, os móveis de uso).
const CINZA_PROVISORIO := Color(0.52, 0.53, 0.52)

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

## A JORNADA DO MORADOR (`agenda` em npcs_3d.json). Quem tem agenda não segue os cinco
## postos do dia: cada entrada diz de que hora ("de"), onde ("lugar" e "desloc", o
## mesmo par âncora + deslocamento dos postos; "Casa" é a casa dele, "Casa/Varal" o
## varal dela) e o que faz ali ("acao", com "mao" e "cabeca" para o que leva).
## A entrada vale até a hora da seguinte, e depois da meia-noite vale a última do dia
## anterior. Ele SAI ANTES, para chegar na hora (`_entrada_agora`).
const PREFIXO_AGENDA := "agenda:"
## Mais longe que isto (u), a troca de posto é um caminho longo: fora da vista, o
## morador é posto no destino na hora marcada (`_encurtar_o_caminho`).
const CAMINHO_LONGO := 40.0
## O SALTO DO CAMINHO LONGO ESPERA (#84): o jogador longe (LONGE_PARA_SALTAR, u)
## e sem ver nem o morador nem o destino por FORA_DA_VISTA_POR segundos seguidos.
## O padre saltava da igreja ao cemitério porque bastava um quadro fora do
## enquadramento — virar a câmera não é sumir.
const FORA_DA_VISTA_POR := 4.0
const LONGE_PARA_SALTAR := 40.0
## Há quanto tempo (s) o jogador não vê o morador nem o destino do caminho longo.
var _fora_da_vista := 0.0
## A malha de navegação é de 5 a 10 % mais longa que a reta.
const FOLGA_DO_CAMINHO := 1.15
## Um salto de relógio maior que isto (horas) refaz o dia do morador (dormir, tecla T, save).
const SALTO_DE_HORA := 0.5
## Longe do jogador mais que isto (u), o morador anda sem corpo: sem física, sem esqueleto.
const LONGE := 90.0
## O que cada ação faz com o corpo: o clipe do GLB (vazio é ficar em pé). `SEM_LACO`
## roda uma vez e segura a pose (sentar); `SUBSTITUTO` é o clipe do mesmo gesto para
## quem não tem o primeiro.
const ACOES := {
	"varrer": "dig", "lavar": "dig", "mariscar": "dig", "capinar": "dig",
	"rachar": "chop", "carregar": "lift_heavy", "estender": "lift_heavy", "recolher": "lift_heavy",
	"balcao": "fold_arms", "vigiar": "fold_arms", "esperar": "fold_arms",
	"rezar": "bow", "benzer": "bow", "conversar": "look_around", "olhar": "look_around",
	"remendar": "sit", "renda": "sit", "descansar": "sit", "brincar": "look_around",
	"pescar": "", "vender": "", "recolhido": "",
}
const SEM_LACO := ["sit"]
const SUBSTITUTO := {"lift_heavy": "chop", "bow": "agree", "sit": "fold_arms"}
## O que se leva na mão (pela alça, como o balde do jogador, ou pelo cabo) e na
## cabeça: o tamanho em metros e como se pega. O que está em `Vestimenta3D.NA_MAO`
## (balde, enxada, vara) usa o encaixe de lá.
const NA_MAO_DO_MORADOR := {
	"vassoura_piacava": {"metros": 1.3, "agarra": 0.25},
	"candeeiro": {"metros": 0.34, "agarra": 0.0},
	"cesto": {"metros": 0.36, "agarra": 0.0},
}
const NA_CABECA_DO_MORADOR := {
	"trouxa_roupa": {"metros": 0.55, "acima": 0.1, "frente": 0.0},
	"tabuleiro": {"metros": 0.7, "acima": 0.12, "frente": 0.0},
	"cesto": {"metros": 0.45, "acima": 0.1, "frente": 0.0},
}

## Até quando (ms) cada morador que está falando segura a palavra. Com a fila no
## vale é só espelho de quem está no ar (o portão da chegada lê para dizer quem
## não soltou a palavra); sem ela, é a palavra antiga.
static var _falando: Dictionary = {}

## A FALA DESTE MORADOR NO AR AGORA (o pedido que a fila deu a vez), ou {}.
var _fala_no_ar: Dictionary = {}
var _fila_do_vale: Node = null

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
## A próxima das `saudacoes` (começa numa ao acaso, como as `falas`): -1 até a primeira.
var _proxima_saudacao := -1
## O humor (`falas_dos_moradores.gd`) da última saudação e da última conversa: quando muda, a
## rotação recomeça pelas falas do humor novo.
var _humor_da_saudacao := ""
var _humor_da_conversa := ""
## Os avisos de fila trancada que ele já deu, pelo nome da fila: quem não os repete (`_repete_o_aviso`)
## diz cada um uma vez só. Fica na memória da sessão, e não no save: carregar a partida o deixa dizer de novo.
var _avisos_dados := {}
var _destino_avulso := Vector3.INF
var _velocidade_avulsa := VELOCIDADE
var _nadando := false
## Nado e espuma não precisam de 60 Hz (a histerese do nado aguenta): cada morador os
## atualiza a cada `NADO_A_CADA` ticks, e a fase por instância espalha o custo entre eles.
const NADO_A_CADA := 4
const ESPUMA_A_CADA := 4
var _fase_de_custo := randi() % NADO_A_CADA
var _tique_nado := 0
var _preso := 0.0
var _desvio := Vector3.ZERO
var _desvio_tempo := 0.0
var _desvios := 0
var _parado := 0.0
var _lado_desvio := 0.0
var _ponto_bloqueio := Vector3.INF
## A caminho de um posto longe (a festa, a agenda): o caminho que pode se encurtar.
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
## CAMINHO VAZIO: a malha acabou de mudar (reassou) e ainda não respondeu, ou o corpo está
## num ponto que ela não cobre. Refaz em `REFAZER_SEM_CAMINHO`, e enquanto espera FICA
## PARADO (`_esperando_a_malha`): andar reto até o destino era andar para dentro da água, do
## casco do saveiro ou de uma parede por até `REFAZER_CAMINHO` segundos — o Pedro empacava
## com o jogador atrás dele. Passados `ESPERA_SEM_CAMINHO` segundos de respostas vazias a
## malha não tem mesmo o que dizer (mundo sem malha, destino em ilha) e ele volta ao reto.
const REFAZER_SEM_CAMINHO := 0.3
const ESPERA_SEM_CAMINHO := 2.5
var _sem_caminho_s := 0.0
var _esperando_a_malha := false
## DAR PASSAGEM: o passo para fora do caminho e quanto tempo se fica fora dele,
## o bastante para quem empurrou passar. Ver `dar_passagem`.
const PASSAGEM_PASSO := 1.4
const PASSAGEM_DURA := 2.5
var _passagem_ate := Vector3.INF
var _passagem_resta := 0.0
## A agenda (ordenada por hora), a entrada de agora, e o que ela pede.
var _agenda: Array = []
var _entrada := -1
var _alvos_da_agenda: Dictionary = {}
var _acao := ""
var _levados: Array[Node] = []
var _levados_andando: Array[Node] = []
var _recolhido := false
var _dormindo := false
var _hora_vista := -1.0
var _sem_antecipar := false
var _relogio_saltou := false
var _avisados: Dictionary = {}


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
	# Posto da hora, sem sair antes: quem é posto no lugar vem do relógio, e não do ponto de onde estava.
	_sem_antecipar = true
	_posto = _posto_de_agora()
	_sem_antecipar = false
	_alvo = _posicao_do_posto(_posto)
	_caminho_da_festa = false
	if _alvo != Vector3.ZERO:
		global_position = _alvo + Vector3(0, 0.05, 0)
		velocity = Vector3.ZERO
	_aplicar_entrada()


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
	_mover(direcao, _velocidade_de_passo() * 1.3, delta)
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
		# A espuma do morador atualiza a cada 4 ticks, com fase por instância (a do jogador, por tick).
		espuma.intervalo = ESPUMA_A_CADA
		espuma.fase = _fase_de_custo
		add_child(espuma)
	altura = float(d.get("altura", 1.7))
	name = "Morador" + String(d.get("id", "morador")).capitalize()
	_agenda = (d.get("agenda", []) as Array).duplicate()
	_agenda.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["de"]) < float(b["de"]))


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
	_hora_vista = Dia.hora
	_aplicar_entrada()


func _aplicar_volume() -> void:
	# Volume próprio do morador (painel PERSONAGENS) por cima do canal de vozes.
	voz.volume_db = Audio.volume_vozes_db() + float(dados.get("volume_voz_db", 0.0))


func _montar_modelo() -> void:
	var id := String(dados.get("id", "viajante"))
	# O corpo é o do "modelo" quando o morador o diz (duas lavadeiras podem usar o mesmo GLB).
	var corpo := String(dados.get("modelo", id))
	modelo = null
	animador = null
	if Estilo.tripo():
		var tamanho := 1.0
		var spec_modelo: Dictionary = AjustesConteudo.peca(corpo)
		if spec_modelo.has("altura"):
			tamanho = altura / float(spec_modelo["altura"])
		modelo = CatalogoAssets.instanciar(corpo, visual, Vector3.ZERO, tamanho, float(dados.get("yaw_modelo", 0.0)))
		if modelo != null and not modelo.find_children("*", "AnimationPlayer", true, false).is_empty():
			# GLB com rig e clipes do Tripo (idle/walk/run + gestos): usa o animador autoral.
			var autoral: Node = load("res://scripts/prototipo_3d/authored_animator.gd").new()
			add_child(autoral)
			autoral.configure(modelo)
			animador = autoral
		if modelo == null:
			# NO ESTILO TRIPO, QUEM AINDA NÃO TEM MODELO É CAIXA CINZA, e não o boneco
			# do procedural: peça procedural não entra no estilo Tripo. É o trato do
			# caititu e da oficina — a mecânica não espera o modelo, e o modelo entra
			# depois pelo catálogo sem tocar nela. Hoje é só o mestre Quirino. Sem
			# animador: toda chamada a ele pergunta antes se existe, e o balanço do
			# passo (`_atualizar_animacao`) anda sozinho.
			modelo = _corpo_provisorio()
	if modelo == null:
		var procedural := PersonagemProcedural.novo(corpo, altura)
		visual.add_child(procedural)
		modelo = procedural
		animador = procedural


## O CORPO PROVISÓRIO: caixa cinza na altura do morador, com a cabeça um pouco
## à frente (+Z, para onde o corpo olha) para ele ter rosto, como o caititu.
func _corpo_provisorio() -> Node3D:
	var corpo := Node3D.new()
	corpo.name = "CorpoProvisorio"
	var tinta := StandardMaterial3D.new()
	tinta.albedo_color = CINZA_PROVISORIO
	var tronco := MeshInstance3D.new()
	var malha := BoxMesh.new()
	malha.size = Vector3(0.46, altura * 0.82, 0.28)
	tronco.mesh = malha
	tronco.material_override = tinta
	tronco.position.y = malha.size.y * 0.5
	corpo.add_child(tronco)
	var cabeca := MeshInstance3D.new()
	var malha_cabeca := BoxMesh.new()
	malha_cabeca.size = Vector3(0.24, altura * 0.16, 0.24)
	cabeca.mesh = malha_cabeca
	cabeca.material_override = tinta
	cabeca.position = Vector3(0.0, malha.size.y + malha_cabeca.size.y * 0.5, 0.05)
	corpo.add_child(cabeca)
	visual.add_child(corpo)
	return corpo


func _physics_process(delta: float) -> void:
	if _andar_dando_passagem(delta):
		_atualizar_animacao(delta)
		_atualizar_interacao(delta)
		return
	_vigiar_o_relogio()
	var posto := _posto_de_agora()
	if posto != _posto or _relogio_saltou:
		_relogio_saltou = false
		var vinha_da_festa := _posto == POSTO_DA_FESTA
		_posto = posto
		_alvo = _posicao_do_posto(posto)
		# A festa se encurta sempre; o resto, quando o caminho é longo (`CAMINHO_LONGO`).
		_caminho_da_festa = posto == POSTO_DA_FESTA or vinha_da_festa or (_alvo != Vector3.ZERO \
			and Vector2(_alvo.x - global_position.x, _alvo.z - global_position.z).length() > CAMINHO_LONGO)
		_aplicar_entrada()
	if _caminho_da_festa:
		_encurtar_o_caminho(delta)
	if _recolhido:
		# Dentro de casa: sem corpo nenhum até a hora de sair.
		return
	if _andar_longe(delta):
		_atualizar_trabalho()
		return
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
		if not _esperando_a_malha:
			direcao = rumo.normalized() if rumo.length() > 0.05 else deslocamento / distancia
	_mover(direcao, _velocidade_avulsa if _destino_avulso.is_finite() else _velocidade_de_passo(), delta)
	if direcao == Vector3.ZERO and jogador != null and jogador.global_position.distance_to(global_position) < RAIO_BALAO \
			and not _trabalhando():
		_olhar_para(jogador.global_position, delta)
	_atualizar_animacao(delta)
	_atualizar_trabalho()
	_atualizar_interacao(delta)


## Movimento com gravidade e colisão; vira o corpo para a direção do passo.
func _mover(direcao: Vector3, velocidade: float, delta: float) -> void:
	direcao = _contornar_bloqueio(direcao, delta)
	_tique_nado += 1
	if (_tique_nado + _fase_de_custo) % NADO_A_CADA == 0:
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
	# Parado, no chão e sem nadar (velocidade zero, e já medida como zero): o
	# move_and_slide não tem o que resolver, e custava ~3 ms por tick na praça. Quem
	# é empurrado ganha velocidade e volta a passar por ele.
	if not _nadando and velocity.x == 0.0 and velocity.z == 0.0 and _velocidade_atual < 0.01 and is_on_floor():
		_velocidade_atual = 0.0
		return
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
	# Sem a fila no vale, o balão conta o próprio tempo; com ela, quem conta é a
	# fila, em relógio de parede (`_tique_da_fala`).
	if _balao_tempo > 0.0 and _fila() == null:
		_balao_tempo -= delta
		if _balao_tempo <= 0.0:
			_parar_a_fala(_fala_no_ar, false)
	if jogador == null:
		return
	var distancia := jogador.global_position.distance_to(global_position)
	# Quem se afastou no meio da fala saiu da conversa: o dia volta a correr.
	if _segura_o_relogio and distancia > RAIO_CONVERSA:
		_soltar_o_relogio()
	if distancia < RAIO_SAUDACAO and (_ultima_saudacao_ms < 0 or Time.get_ticks_msec() - _ultima_saudacao_ms > intervalo_saudacao_ms):
		if _eh_mudo():
			saudar()
		elif not pode_falar():
			# A VEZ ESTÁ COM ALGO QUE IMPORTA (a fala da missão, a resposta de
			# alguém, a festa): o cumprimento não espera na fila, cai — e o encontro
			# conta como feito, para não emendar no fim da fala que ele esperava.
			# Atrás de outro cumprimento, não: esse acaba logo, e aí ele sai.
			if not _so_cumprimento_no_ar():
				_ultima_saudacao_ms = Time.get_ticks_msec()
		elif tem_missao():
			# Quem tem missão com o jogador fala a missão, e não o cumprimento. A
			# saudação se dá por feita: sem isso, ela sairia no quadro seguinte ao
			# fim da fala da missão.
			_ultima_saudacao_ms = Time.get_ticks_msec()
		else:
			saudar()


## Só um cumprimento de outro morador no ar, e ninguém esperando a vez?
func _so_cumprimento_no_ar() -> bool:
	var fila := _fila()
	if fila == null:
		return true
	var no_ar: Dictionary = fila.atual()
	return fila.esperando() == 0 and not no_ar.is_empty() \
		and int(no_ar.get("classe", -1)) == FilaDeFalas.Classe.PASSAGEM


## O MORADOR TEM MISSÃO COM O JOGADOR AGORA? Pergunta a toda cadeia viva — a dele
## e a dos outros, que podem mandar o jogador até ele. Ver
## `CadeiaDeMissoes.envolve`.
func tem_missao() -> bool:
	if not is_inside_tree():
		return false
	for cadeia in get_tree().get_nodes_in_group(GRUPO_DAS_CADEIAS):
		if cadeia.has_method("envolve") and bool(cadeia.envolve(self)):
			return true
	return false


## A VEZ DE FALAR ESTÁ LIVRE? No vale, é a fila: ninguém no ar e ninguém
## esperando (`FilaDeFalas.livre`). Sem ela, ninguém por perto no meio de uma fala.
func pode_falar() -> bool:
	var fila := _fila()
	if fila != null:
		return fila.livre()
	var agora := Time.get_ticks_msec()
	for outro in _falando.keys():
		if not is_instance_valid(outro) or int(_falando[outro]) <= agora:
			_falando.erase(outro)
		elif outro != self and (outro as Node3D).global_position.distance_to(global_position) < RAIO_CONVERSA:
			return false
	return true


## Alguém (fora este) está falando ao alcance de `ponto`.
func fala_perto_de(ponto: Vector3) -> bool:
	var fila := _fila()
	if fila != null:
		return fila.alguem_alem_de(self, ponto, RAIO_CONVERSA)
	var agora := Time.get_ticks_msec()
	for outro in _falando.keys():
		if not is_instance_valid(outro) or int(_falando[outro]) <= agora:
			_falando.erase(outro)
		elif outro != self and (outro as Node3D).global_position.distance_to(ponto) < RAIO_CONVERSA:
			return true
	return false


## SEGURA A PALAVRA por `segundos` (mais a folga): a bronca do coveiro estica o
## balão dele pelo tempo da voz dela (`lapides.gd`). Na fila, estica a fala dele
## que está no ar.
func _tomar_palavra(segundos: float) -> void:
	_falando[self] = Time.get_ticks_msec() + int((segundos + PAUSA_ENTRE_FALAS) * 1000.0)
	var fila := _fila()
	if fila != null:
		fila.estender(self, segundos + PAUSA_ENTRE_FALAS)


func _exit_tree() -> void:
	var fila := _fila()
	if fila != null:
		fila.calar_falante(self)
	_falando.erase(self)
	_soltar_o_relogio()


## A fila de falas do vale, ou null (portão que monta um morador só).
func _fila() -> Node:
	if _fila_do_vale != null and is_instance_valid(_fila_do_vale) and _fila_do_vale.is_inside_tree() \
			and _fila_do_vale.is_in_group(FilaDeFalas.GRUPO):
		return _fila_do_vale
	_fila_do_vale = FilaDeFalas.da(self)
	return _fila_do_vale


## O RELÓGIO PARA NA CONVERSA (`Dia.segurar`): a fala da missão (`narrar`) e a
## conversa do E (`conversar`) seguram o dia enquanto o balão está no ar, com o
## jogador ao alcance dela. A SAUDAÇÃO DE QUEM PASSA NÃO SEGURA: atravessar a
## praça cheia pararia o dia a cada cumprimento, e cumprimento não é conversa.
var _segura_o_relogio := false


func _segurar_o_relogio() -> void:
	if jogador == null or jogador.global_position.distance_to(global_position) > RAIO_CONVERSA:
		return
	_segura_o_relogio = true
	# Com prazo: o do balão e um respiro (ver `Dia.segurar`).
	Dia.segurar(_motivo_do_relogio(), _balao_tempo + 1.0)


func _soltar_o_relogio() -> void:
	if not _segura_o_relogio:
		return
	_segura_o_relogio = false
	Dia.soltar(_motivo_do_relogio())


## "fala:" e quem: é o prefixo que a festa da missão cumprida espera passar.
func _motivo_do_relogio() -> String:
	return "fala:%d" % get_instance_id()


## Está no meio de uma conversa com o jogador (o balão que segura o relógio)?
func conversando() -> bool:
	return _segura_o_relogio


## Cumprimenta o jogador: balão com a fala e voz do ElevenLabs por proximidade. Quem
## tem "falas" (até três) alterna entre elas a cada encontro; sem elas, usa "fala".
##
## O CUMPRIMENTO ENTRA NA FILA DE FALAS como o de quem passa (`Classe.PASSAGEM`):
## quem o chama pela proximidade (`_atualizar_interacao`) já perguntou se a vez
## está livre. Chamado direto — o Pedro na chegada, um portão —, ele entra já:
## corta a fala com tempo que estiver no ar, e não fala por cima dela.
func saudar() -> void:
	if _eh_mudo():
		_acenar_mudo()
		return
	_ultima_saudacao_ms = Time.get_ticks_msec()
	var escolhida := _escolher_a_saudacao()
	var texto := str(escolhida.get("texto", ""))
	if texto.strip_edges() == "":
		return
	var fluxo = escolhida.get("voz")
	# O balão leva a fala enxuta; a voz e o aviso do HUD (`saudou`) levam a inteira.
	var curto := balao_curto(texto)
	_pedir_fala({
		"texto": curto, "inteira": texto, "voz": fluxo,
		"classe": _classe_da_saudacao(), "agora": true,
		"segundos": FilaDeFalas.duracao(curto, _tempo_da_voz(fluxo)),
		"aviso": true, "gesto": _gesto_de_saudacao(),
	})


## O cumprimento de quem passa — também o do Pedro na chegada, que é chamado
## direto (`agora`) e por isso não cai; e que a resposta do E de outro morador, ou
## a narração do mundo, pode cortar.
func _classe_da_saudacao() -> int:
	return FilaDeFalas.Classe.PASSAGEM


## RECOLHE O BALÃO E A VOZ NO MEIO DA FALA, e tira da fila o que ele ainda ia dizer
## (`_calar_a_boca`). O "um balão por vez" da #90 — quem fala com o jogador, pelo E
## ou pela missão, cala a saudação de quem passa — é a fila que garante
## (`FilaDeFalas._passa_na_frente`: a CONVERSA e a NARRAÇÃO cortam a PASSAGEM); isto
## é para quem precisa do morador calado já, como a pergunta do aceno (`interacao`).
func calar() -> void:
	_calar_a_boca()
	_balao_tempo = 0.0
	balao.esconder()
	nome_label.visible = true
	_falando.erase(self)
	if voz.playing:
		voz.stop()
	_soltar_o_relogio()


## A CONVERSA DO E (`tecla_dos_moradores.gd`): chegou perto e apertou E, sem
## missão nenhuma com este morador — ele diz a fala INTEIRA no balão, com a voz
## e o gesto da saudação, como no 2D ("Converse com cada morador do arraial:
## chegue perto e aperte E"). A de passagem, ao chegar perto, é a curta. No
## balão, e não na caixa de fala longa: a caixa é do que o jogador precisa ler
## antes de seguir (`dialogo_vale.gd`), e conversa de passagem não é isso.
##
## NA FILA DE FALAS: a resposta espera quem está falando terminar — só o
## cumprimento de quem passa cede a ela. O E em quem JÁ ESTÁ FALANDO passa a fala
## dele (quem leu não espera o relógio do balão); o segundo E em quem tem a
## resposta na fila a faz passar na frente.
func conversar() -> void:
	# QUEM NÃO FALA ACENA, como na saudação (`_eh_mudo`): sem balão vazio, sem o
	# aviso "Nome: " no HUD, e sem segurar o relógio por uma fala que não há.
	if _eh_mudo():
		_acenar_mudo()
		return
	var fila := _fila()
	if fila != null:
		if fila.falando(self) and int(fila.atual().get("classe", -1)) != FilaDeFalas.Classe.PASSAGEM:
			fila.pular()
			return
		if fila.pendente(self) and fila.apressar(self):
			return
	_ultima_saudacao_ms = Time.get_ticks_msec()
	# A FILA DELE ESTÁ TRANCADA: no lugar da conversa de passagem, ele diz o que fazer antes.
	var trancada := _fila_que_avisa()
	var escolhida: Dictionary
	if trancada != null:
		_avisos_dados[str(trancada.name)] = true
		escolhida = {"texto": str(trancada.dica_da_trancada()), "voz": null}
	else:
		escolhida = _escolher_a_fala()
	var texto := str(escolhida.get("texto", ""))
	if texto.strip_edges() == "":
		return
	var fluxo = escolhida.get("voz")
	_pedir_fala({
		"texto": texto, "inteira": texto, "voz": fluxo,
		"classe": FilaDeFalas.Classe.CONVERSA, "no_lugar": true,
		"segura": true, "aviso": true, "gesto": _gesto_de_saudacao(),
	})


## O QUE ESTE MORADOR DIZ QUANDO A FILA DELE AINDA ESPERA OUTRA COISA: "volte depois de ..."
## (`trancada` no arquivo da fila, nos três idiomas), e não a conversa de passagem.
##
## Quem só abre depois do tutorial, do machado da ponte ou da piaçava ouvia a mesma conversa
## de qualquer morador, e o jogador não sabia o que lhe faltava. Vale só quando o E não fez
## mais nada com ele — a fila aberta, o passo que o procura e a entrega vêm antes
## (`tecla_dos_moradores.usar`) — e só quando NENHUMA fila dele anda NEM PODE SER ABERTA pelo E
## dele agora: com uma aberta, a conversa de passagem não esconde o que fazer (o objetivo está no
## HUD); com uma por abrir, o E é dela, e não do aviso de outra que ainda espera. Com mais de uma
## trancada (o Pedro), a primeira na ordem dos nós. Sem aviso escrito, "" e a conversa de sempre.
func _dica_da_fila_trancada() -> String:
	var fila := _fila_que_avisa()
	return "" if fila == null else str(fila.dica_da_trancada())


## A FILA TRANCADA DE QUE ELE FALA AGORA, ou null: a primeira dele, na ordem dos nós, que está
## trancada, escreveu o aviso e ainda não foi avisada (quando ele não repete, `_repete_o_aviso`).
##
## É uma PERGUNTA, sem efeito: quem diz o aviso (`conversar`) é que o marca como dito.
##
## O PEDRO foi o caso que mostrou a segunda condição. Acabado o tutorial ele tem a ponte, as armas
## e o ofício por abrir no E dele, e as da chapada, do mirante, da fé e da lapa trancadas: o aviso da
## chapada ("volte depois de colher a primeira roça") tomava o E e escondia as falas de depois do
## tutorial (`falas_depois`), que o `tests/saudacao.gd` cobra. Fila por abrir quer o E dela.
func _fila_que_avisa() -> Node:
	if not is_inside_tree():
		return null
	var avisa: Node = null
	for cadeia in get_tree().get_nodes_in_group(GRUPO_DAS_CADEIAS):
		if not cadeia.has_method("dica_da_trancada") or cadeia.get("dono") != self:
			continue
		if bool(cadeia.em_andamento()) or str(cadeia.o_que_o_e_faz(self)) == "abrir":
			return null
		if avisa == null and str(cadeia.dica_da_trancada()) != "" \
				and (_repete_o_aviso() or not _avisos_dados.has(str(cadeia.name))):
			avisa = cadeia
	return avisa


## O aviso de fila trancada se repete a cada E? Sim, para quem não tem outra coisa a dizer em seguida
## (o Damião, o Tonho, a Dona Zefa: o jogador que volta sem o machado ouve de novo o que falta). Não,
## para quem tem as falas dele (`GuiaPedro`): cada aviso sai uma vez, e depois ele volta a elas.
func _repete_o_aviso() -> bool:
	return true


## A próxima das "falas" (até três, alternando a cada encontro), na língua do
## jogo, e a voz dela: {"texto": String, "voz": AudioStream ou null}. Sem
## "falas", a "fala". A VOZ NÃO É POSTA AQUI: a fala ainda vai pedir a vez, e
## trocar o `stream` de quem está falando cortaria a voz que está no ar.
func _escolher_a_fala() -> Dictionary:
	var texto := String(dados.get("fala", ""))
	var fluxo: AudioStream = voz.stream if voz != null else null
	var humor := _humor_da_fala()
	var falas: Array = FalasDosMoradores.lista(dados, "falas", humor)
	if humor != _humor_da_conversa:
		_humor_da_conversa = humor
		_proxima_fala = FalasDosMoradores.recomeco(dados, "falas", humor, _proxima_fala)
	if not falas.is_empty():
		var fala: Dictionary = falas[_proxima_fala % falas.size()]
		_proxima_fala += 1
		# Na língua do jogo, quando a fala a tem (texto_en, texto_es).
		texto = String(IdiomaMenu.campo(fala, "texto", ""))
		fluxo = _voz_do_arquivo(String(fala.get("audio", "")))
	return {"texto": texto, "voz": fluxo}


## O CUMPRIMENTO DE QUEM PASSA: o morador que tem `saudacoes` (os catorze que já foram
## mudos) o diz delas — frase curta, que cabe inteira no balão —, e guarda as `falas`
## para a conversa do E. Sem `saudacoes` (os sete antigos, o Pedro), o cumprimento sai
## da mesma lista da conversa, como sempre. De noite somam as `saudacoes_noite`
## (`falas_dos_moradores.gd`). Mesma devolução de `_escolher_a_fala`.
func _escolher_a_saudacao() -> Dictionary:
	var humor := _humor_da_fala()
	var saudacoes := FalasDosMoradores.lista(dados, "saudacoes", humor)
	if saudacoes.is_empty():
		return _escolher_a_fala()
	if _proxima_saudacao < 0:
		_proxima_saudacao = randi() % saudacoes.size()
	if humor != _humor_da_saudacao:
		_humor_da_saudacao = humor
		_proxima_saudacao = FalasDosMoradores.recomeco(dados, "saudacoes", humor, _proxima_saudacao)
	var saudacao: Dictionary = saudacoes[_proxima_saudacao % saudacoes.size()]
	_proxima_saudacao += 1
	return {
		"texto": String(IdiomaMenu.campo(saudacao, "texto", "")),
		"voz": _voz_do_arquivo(String(saudacao.get("audio", ""))),
	}


## O humor da hora para escolher a fala: "noite" à noite, "" no resto (`falas_dos_moradores.gd`).
func _humor_da_fala() -> String:
	return FalasDosMoradores.humor_do_periodo(Dia.periodo())


## A voz de assets/audio/vozes/<nome>.mp3, ou null.
static func _voz_do_arquivo(nome: String) -> AudioStream:
	var caminho := PASTA_VOZES + nome + ".mp3"
	return load(caminho) as AudioStream if nome != "" and ResourceLoader.exists(caminho) else null


static func _tempo_da_voz(fluxo) -> float:
	return (fluxo as AudioStream).get_length() if fluxo is AudioStream else 0.0


func _gesto_de_saudacao() -> int:
	if animador == null:
		return 0
	var chave := "gesto_tripo" if animador.has_method("is_using_authored_clips") else "gesto_saudacao"
	return int(dados.get(chave, 0))


## O BALÃO DA SAUDAÇÃO É CURTO; a fala continua inteira.
##
## "Os textos das falas de aproximação apresentados no balão também estão
## grandes. Podemos deixar a fala dele por extenso, mas enxugar o balão. Isso se
## aplica somente às falas por aproximação." Eram de 60 a 130 letras num balão
## que se lê de passagem. Fica a primeira frase — a de pelo menos
## FRASE_MINIMA letras, para "Opa!" não ficar sozinho —, e frase mais longa que
## BALAO_CURTO é cortada na última palavra que cabe, com reticências. Vale nos
## três idiomas, porque é feito sobre o texto já traduzido.
##
## Só a saudação passa por aqui: a fala de missão (`narrar`) é instrução e sai
## inteira no balão.
const BALAO_CURTO := 60
const FRASE_MINIMA := 12

static func balao_curto(texto: String) -> String:
	var limpo := texto.strip_edges()
	var frase := limpo
	for i in limpo.length():
		if i + 1 < FRASE_MINIMA or not ".!?…".contains(limpo[i]):
			continue
		if i + 1 == limpo.length() or limpo[i + 1] == " ":
			frase = limpo.substr(0, i + 1)
			break
	if frase.length() <= BALAO_CURTO:
		return frase
	var corte := frase.substr(0, BALAO_CURTO - 1)
	var espaco := corte.rfind(" ")
	if espaco > 0:
		corte = corte.substr(0, espaco)
	return corte.rstrip(" ,;:—-") + "…"


## MOSTRA ESTE TEXTO NO BALÃO, AGORA, por `segundos` (a bronca do coveiro,
## `lapides.gd`, que pergunta antes se a vez está livre). Entra já: corta a fala
## com tempo que estiver no ar, e não fala por cima dela. Texto vazio cala.
func mostrar_balao(texto: String, segundos: float) -> void:
	if texto == "":
		_calar_a_boca()
		return
	_pedir_fala({"texto": texto, "segundos": maxf(segundos, 0.1),
		"classe": FilaDeFalas.Classe.CONVERSA, "agora": true})


## NARRA UMA FALA: balão, voz do ElevenLabs quando o arquivo existe, pelo tempo
## da voz ou de ler o texto (`FilaDeFalas.duracao`), na vez dela.
##
## Nasceu dentro do `guia_pedro.gd`, porque o Pedro era o único morador que
## falava fora da saudação. Subiu para cá quando o Damião ganhou fila de
## missões: cadeia de missões pendurada num morador chama `narrar` nele, e
## morador sem `narrar` conduziria a missão em silêncio — o passo avançaria e o
## jogador não saberia por quê.
##
## `pedido` diz à fila de falas quem é esta fala (`classe`: o anúncio do passo é
## MISSAO, a resposta do E é CONVERSA; `origem`, para o passo que fecha calar o
## próprio anúncio; `no_lugar`, para quem fala trocar a fala pela resposta) e
## quem quer saber quando ela começa e acaba (`ao_comecar`, `ao_terminar`).
func narrar(nome_audio: String, texto: String, pedido: Dictionary = {}) -> void:
	if texto.strip_edges() == "":
		# Nada a dizer: quem esperava o fim (o arremate) fica sabendo já.
		if pedido.get("ao_terminar") is Callable and (pedido["ao_terminar"] as Callable).is_valid():
			(pedido["ao_terminar"] as Callable).call()
		return
	var fala := {
		"texto": texto, "inteira": texto, "voz": _voz_do_arquivo(nome_audio),
		"classe": int(pedido.get("classe", FilaDeFalas.Classe.MISSAO)),
		"origem": str(pedido.get("origem", "")),
		"no_lugar": bool(pedido.get("no_lugar", false)),
		# Autoral: 2 = concordar; procedural: 2 = apontar.
		"segura": true, "gesto": 2, "narrada": true,
	}
	for gancho in ["ao_comecar", "ao_terminar"]:
		if pedido.get(gancho) is Callable:
			fala[gancho] = pedido[gancho]
	_pedir_fala(fala)


## PEDE A VEZ À FILA DE FALAS (`fila_de_falas.gd`) e diz a ela como este morador
## fala: o balão, a voz, o relógio e o gesto começam em `_comecar_a_fala` e
## acabam em `_parar_a_fala`. Sem a fila (um portão que monta um morador só),
## fala na hora, como sempre falou.
func _pedir_fala(fala: Dictionary) -> void:
	fala["falante"] = self
	if not fala.has("segundos"):
		fala["segundos"] = FilaDeFalas.duracao(str(fala.get("texto", "")), _tempo_da_voz(fala.get("voz")))
	fala["comecar"] = _comecar_a_fala
	fala["parar"] = _parar_a_fala
	fala["suspender"] = _suspender_a_fala
	fala["tique"] = _tique_da_fala
	var fila := _fila()
	if fila != null:
		var id: int = fila.pedir(fala)
		if id > 0 and not fila.falando(self) and bool(fala.get("aviso", false)):
			# NA FILA, ESPERANDO A VEZ: o aceno diz ao jogador que o E chegou.
			_acenar()
		return
	if not _fala_no_ar.is_empty():
		_parar_a_fala(_fala_no_ar, true)
	_comecar_a_fala(fala)
	for gancho in ["ao_comecar", "ao_terminar"]:
		if fala.get(gancho) is Callable and (fala[gancho] as Callable).is_valid():
			(fala[gancho] as Callable).call()


## GANHOU A VEZ: balão, voz, relógio, gesto e o aviso do HUD (`saudou`), tudo
## agora — e não na hora do pedido, para o aviso dizer o que está no balão.
func _comecar_a_fala(fala: Dictionary) -> void:
	if not _fala_no_ar.is_empty() and _fala_no_ar.get("id") != fala.get("id"):
		_parar_a_fala(_fala_no_ar, true)
	_fala_no_ar = fala
	_balao_tempo = float(fala.get("segundos", FilaDeFalas.MINIMO))
	balao.mostrar(str(fala.get("texto", "")))
	# O balão já traz o nome; o rótulo 3D volta quando a fala termina.
	nome_label.visible = false
	var fluxo = fala.get("voz")
	if fluxo is AudioStream:
		voz.stop()
		voz.stream = fluxo
		voz.stream_paused = false
		voz.play()
	_falando[self] = Time.get_ticks_msec() + int((_balao_tempo + PAUSA_ENTRE_FALAS) * 1000.0)
	if bool(fala.get("segura", false)):
		_segurar_o_relogio()
	else:
		# A SAUDAÇÃO DE QUEM PASSA NÃO SEGURA o relógio (ver `_segurar_o_relogio`).
		_soltar_o_relogio()
	# QUEM TRABALHA CONTINUA TRABALHANDO ENQUANTO FALA: o gesto de saudação pisava no clipe do
	# ofício (a vassoura, a renda, a rede) e o corpo ficava parado até o próximo posto. Os
	# moradores novos, que agora falam, trabalham parados no posto (`_acenar_mudo` já fazia assim).
	if fala.has("gesto") and animador != null and animador.has_method("play_gesture") and not _trabalhando():
		animador.play_gesture(int(fala["gesto"]))
	if bool(fala.get("aviso", false)):
		saudou.emit(self, str(fala.get("inteira", fala.get("texto", ""))))


## PERDEU A VEZ: dita até o fim, cortada ou calada. O balão some, a voz cala.
func _parar_a_fala(fala: Dictionary, _cortada: bool) -> void:
	if _fala_no_ar.is_empty() or _fala_no_ar.get("id") != fala.get("id"):
		return
	_fala_no_ar = {}
	_balao_tempo = 0.0
	balao.esconder()
	nome_label.visible = true
	if fala.get("voz") is AudioStream:
		voz.stop()
		voz.stream_paused = false
	_falando.erase(self)
	_soltar_o_relogio()


## A CAIXA DE FALA OU UMA TELA COBRIU O VALE: a fala espera escondida, com a voz
## pausada, e volta de onde parou.
func _suspender_a_fala(fala: Dictionary, sim: bool) -> void:
	if _fala_no_ar.get("id") != fala.get("id"):
		return
	balao.visible = not sim and str(fala.get("texto", "")) != ""
	if fala.get("voz") is AudioStream:
		voz.stream_paused = sim
	if not sim and bool(fala.get("segura", false)):
		_segurar_o_relogio()


## O tempo que falta da fala no ar, a cada quadro (em relógio de parede).
func _tique_da_fala(resta: float) -> void:
	_balao_tempo = resta
	_falando[self] = Time.get_ticks_msec() + int((resta + PAUSA_ENTRE_FALAS) * 1000.0)


## Cala o que este morador estiver dizendo ou esperando dizer.
func _calar_a_boca() -> void:
	var fila := _fila()
	if fila != null:
		fila.calar_falante(self)
	if not _fala_no_ar.is_empty():
		_parar_a_fala(_fala_no_ar, true)


## Fala deste morador no ar agora?
func falando_agora() -> bool:
	return not _fala_no_ar.is_empty()


func _acenar() -> void:
	if animador != null and animador.has_method("play_gesture"):
		animador.play_gesture(_gesto_de_saudacao())


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
	if not _agenda.is_empty():
		return PREFIXO_AGENDA + str(_entrada_agora())
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
	# Só quem segue os cinco postos vem à roda: os moradores com agenda (os quinze de
	# 05/10, na teia desde a #85) têm fé, mas jornada própria — contá-los deixaria
	# vão na roda.
	var da_fe: Array = []
	for id in Afinidade.da_fe(festa):
		var outro: Node = _morador_do_vale(str(id))
		if outro != null and not (outro.get("dados") as Dictionary).has("agenda"):
			da_fe.append(str(id))
	var vez := maxi(da_fe.find(str(dados.get("id", ""))), 0)
	var direcao := base.rotated(Vector3.UP, TAU * (float(vez) + 0.5) / float(maxi(da_fe.size(), 1)))
	var lugar := centro + direcao * float(RODA_DA_FESTA.get(marco, 2.6))
	return _chao_de_verdade(terreno.ground_position(lugar, 0.0) if terreno != null else lugar)


## O morador `id` do vale (grupo "moradores"), ou nulo.
func _morador_do_vale(id: String) -> Node:
	if not is_inside_tree():
		return null
	for outro in get_tree().get_nodes_in_group("moradores"):
		var dele = outro.get("dados")
		if dele is Dictionary and str((dele as Dictionary).get("id", "")) == id:
			return outro
	return null


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
##
## E VIRAR A CÂMERA NÃO É SUMIR (#84). Bastava um quadro com o morador e o
## destino fora do enquadramento para ele ser posto no lugar: o padre saltava
## da igreja ao cemitério com o jogador a dois passos, de costas. O salto agora
## espera o jogador longe (LONGE_PARA_SALTAR) e sem ver nem o morador nem o
## destino por FORA_DA_VISTA_POR segundos seguidos; até lá, ele anda.
func _encurtar_o_caminho(delta: float) -> void:
	if _destino_avulso.is_finite():
		return
	if Vector2(_alvo.x - global_position.x, _alvo.z - global_position.z).length() < 1.0:
		_caminho_da_festa = false
		_fora_da_vista = 0.0
		return
	if _a_vista(global_position) or _a_vista(_alvo) \
			or (jogador != null and jogador.global_position.distance_to(global_position) < LONGE_PARA_SALTAR):
		_fora_da_vista = 0.0
		return
	_fora_da_vista += delta
	if _fora_da_vista < FORA_DA_VISTA_POR:
		return
	# Na agenda, o morador sai antes para chegar na hora: fora da vista ele anda
	# até a hora marcada e só então é posto no lugar, se ainda não chegou.
	if _entrada >= 0 and _posto.begins_with(PREFIXO_AGENDA) and _horas_ate(float(_agenda[_entrada]["de"])) > 0.1:
		return
	global_position = _alvo + Vector3(0, 0.05, 0)
	velocity = Vector3.ZERO
	_preso = 0.0
	_desvios = 0
	_desvio_tempo = 0.0
	_parado = 0.0
	_ponto_bloqueio = Vector3.INF
	_caminho_da_festa = false
	_fora_da_vista = 0.0


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
	_esperando_a_malha = false
	var navegacao := get_tree().get_first_node_in_group("navegacao")
	if navegacao == null or not navegacao.esta_pronta():
		return destino
	_refazer_em -= delta
	if _caminho_ate.distance_to(destino) > 0.3 or _refazer_em <= 0.0 or _preso > TEMPO_PRESO * 0.9:
		if _caminho_ate.distance_to(destino) > 0.3:
			_sem_caminho_s = 0.0
		_caminho = navegacao.caminho(global_position, destino)
		_ponto_da_vez = 1 if _caminho.size() > 1 else 0
		_caminho_ate = destino
		_refazer_em = REFAZER_CAMINHO if not _caminho.is_empty() else REFAZER_SEM_CAMINHO
		if not _caminho.is_empty():
			_sem_caminho_s = 0.0
	if _caminho.is_empty():
		_sem_caminho_s += delta
		_esperando_a_malha = _sem_caminho_s < ESPERA_SEM_CAMINHO
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
	if periodo.begins_with(PREFIXO_AGENDA):
		return _lugar_da_entrada(int(periodo.substr(PREFIXO_AGENDA.length())))
	var postos: Dictionary = dados.get("postos", {})
	if periodo == "" or not postos.has(periodo):
		return global_position
	var posto: Array = postos[periodo]
	return _ponto_da_ancora(String(posto[0]), posto[1] if posto.size() > 1 and posto[1] is Array else [])


## O ponto de uma âncora do cenário com o deslocamento no referencial dela. Âncora que
## não existe avisa uma vez (e vira a origem, que os chamadores tomam por "sem posto").
func _ponto_da_ancora(ancora_nome: String, offset: Array) -> Vector3:
	if ancora_nome == "Casa" or ancora_nome.begins_with("Casa/"):
		ancora_nome = String(dados.get("casa", "")) + ancora_nome.substr(4)
	if not ancoras.has(ancora_nome) and not _avisados.has(ancora_nome):
		_avisados[ancora_nome] = true
		push_warning("Morador %s: a âncora '%s' não existe no cenário." % [dados.get("id", "?"), ancora_nome])
	var base: Vector3 = ancoras.get(ancora_nome, Vector3.ZERO)
	if offset.size() >= 3:
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


# ---------------------------------------------------------------------------
# A JORNADA DO DIA: agenda, trabalho, o que se leva, recolher, economia longe
# ---------------------------------------------------------------------------

## Quem não fala: os moradores novos têm jornada e ofício, mas nenhuma fala. Cumprimentam
## com um aceno, parados, e só: sem balão, sem voz, sem aviso no HUD e sem tomar a
## palavra dos vizinhos (um aviso "Nome: " vazio e uma fala que cala o vale inteiro).
func _eh_mudo() -> bool:
	return bool(dados.get("mudo", false))


## Público para o E (`tecla_dos_moradores.gd`): quem não fala só leva o E quando não há
## ninguém que fale ao alcance — o saveirista no píer não toma a conversa do Pedro.
func eh_mudo() -> bool:
	return _eh_mudo()


func _acenar_mudo() -> void:
	if _trabalhando() or _recolhido:
		return
	_ultima_saudacao_ms = Time.get_ticks_msec()
	if animador != null and animador.has_method("play_gesture"):
		var chave := "gesto_tripo" if animador.has_method("is_using_authored_clips") else "gesto_saudacao"
		animador.play_gesture(int(dados.get(chave, 0)))


## A passada do morador: a de sempre, ou a dele (as crianças correm mais que os velhos).
func _velocidade_de_passo() -> float:
	return float(dados.get("velocidade", VELOCIDADE))


## Quantas horas do relógio faltam para `hora_marcada` (negativo: já passou). Vai de
## -12 a 12: a agenda dá a volta na meia-noite.
func _horas_ate(hora_marcada: float) -> float:
	return fposmod(hora_marcada - Dia.hora + 12.0, 24.0) - 12.0


## A ENTRADA DA AGENDA DE AGORA: a última que já começou (antes da primeira do dia,
## a última da véspera) — ou a seguinte, quando o caminho até ela leva tanto quanto
## falta para a hora dela. É assim que ele chega na hora, e não depois dela.
func _entrada_agora() -> int:
	var n := _agenda.size()
	var atual := n - 1
	for i in n:
		if float(_agenda[i]["de"]) <= Dia.hora:
			atual = i
	if n > 1 and not _sem_antecipar:
		var seguinte := (atual + 1) % n
		var falta := _horas_ate(float(_agenda[seguinte]["de"]))
		if falta > 0.0 and falta <= _horas_de_caminho(seguinte):
			atual = seguinte
	_entrada = atual
	return atual


## Quantas horas de relógio o morador leva para chegar à entrada `i` daqui. Com o relógio
## parado não se antecipa nada.
func _horas_de_caminho(i: int) -> float:
	var segundos_por_hora: float = Dia.VELOCIDADES[Dia.velocidade]
	if segundos_por_hora <= 0.0:
		return 0.0
	var alvo := _lugar_da_entrada(i)
	var distancia := Vector2(alvo.x - global_position.x, alvo.z - global_position.z).length()
	return distancia * FOLGA_DO_CAMINHO / maxf(_velocidade_de_passo(), 0.1) / segundos_por_hora


## Onde a entrada `i` da agenda põe o morador (a conta é feita uma vez).
func _lugar_da_entrada(i: int) -> Vector3:
	if i < 0 or i >= _agenda.size():
		return global_position
	if not _alvos_da_agenda.has(i):
		var entrada: Dictionary = _agenda[i]
		var desloc: Variant = entrada.get("desloc", [])
		_alvos_da_agenda[i] = _ponto_da_ancora(String(entrada.get("lugar", "")), desloc if desloc is Array else [])
	return _alvos_da_agenda[i]


## O RELÓGIO SALTOU (a cama, a tecla T, um save carregado): o morador refaz o dia. Fora
## da vista ele é posto onde estaria (o caminho longo); à vista, anda.
func _vigiar_o_relogio() -> void:
	var salto := absf(_horas_ate(_hora_vista))
	_hora_vista = Dia.hora
	if salto > SALTO_DE_HORA:
		_relogio_saltou = true


## A entrada que começa agora: o que ele leva, o que faz, e se sai de casa. Chamada
## quando o posto muda, e na hora em que o morador nasce.
func _aplicar_entrada() -> void:
	_largar_o_que_leva()
	_acao = ""
	if animador != null and animador.has_method("parar_trabalho"):
		animador.parar_trabalho()
	if _agenda.is_empty() or not _posto.begins_with(PREFIXO_AGENDA):
		_recolher(false)
		return
	var entrada: Dictionary = _agenda[int(_posto.substr(PREFIXO_AGENDA.length()))]
	_acao = String(entrada.get("acao", ""))
	if _acao != "recolhido":
		_recolher(false)
	for onde in ["mao", "cabeca"]:
		_levar_de(String(entrada.get(onde, "")), onde, _levados)
		_levar_de(String(entrada.get(onde + "_andando", "")), onde, _levados_andando)
	if _acao == "recolhido" and Vector2(_alvo.x - global_position.x, _alvo.z - global_position.z).length() < 0.8:
		_atualizar_trabalho()


func _levar_de(peca: String, onde: String, lista: Array[Node]) -> void:
	var raiz := _levar(peca, onde)
	if raiz != null:
		lista.append(raiz)


func _largar_o_que_leva() -> void:
	for no in _levados + _levados_andando:
		if is_instance_valid(no):
			no.queue_free()
	_levados.clear()
	_levados_andando.clear()


## O QUE ELE LEVA: a peça na mão (pela alça ou pelo cabo) ou na cabeça, presa ao osso
## do esqueleto — o trouxa na cabeça da lavadeira, o candeeiro do guarda. Só no
## estilo Tripo (as peças são GLB). Devolve o nó que apaga a peça, ou null.
func _levar(peca: String, onde: String) -> Node:
	if peca == "" or not Estilo.tripo() or modelo == null or not CatalogoAssets.tem_tripo(peca):
		return null
	var ancora: Node3D = null
	if onde == "cabeca":
		if not NA_CABECA_DO_MORADOR.has(peca):
			return null
		var ajuste: Dictionary = NA_CABECA_DO_MORADOR[peca]
		ancora = Vestimenta3D.ancora_da_cabeca(modelo, "ObjetoNaCabeca")
		if ancora == null:
			return null
		var escala := ancora.global_basis.get_scale().x
		var assento := Vector3(0.0, float(ajuste["acima"]), float(ajuste["frente"])) / maxf(escala, 0.0001)
		CatalogoAssets.instanciar(peca, ancora, assento, Vestimenta3D._tamanho_na_ancora(ancora, peca, float(ajuste["metros"])))
	else:
		if not Vestimenta3D.NA_MAO.has(peca) and not NA_MAO_DO_MORADOR.has(peca):
			return null
		ancora = Vestimenta3D.ancora_da_mao(modelo, altura, visual, "ObjetoNaMao")
		if ancora == null:
			return null
		if Vestimenta3D.NA_MAO.has(peca):
			Vestimenta3D.na_mao(ancora, visual, peca)
		else:
			var ajuste: Dictionary = NA_MAO_DO_MORADOR[peca]
			var pivo := Vestimenta3D._pendurado(ancora, visual, peca, {"tamanho": Vestimenta3D._tamanho_na_ancora(ancora, peca, float(ajuste["metros"]))})
			if pivo != null and pivo.get_child_count() > 0 and float(ajuste["agarra"]) > 0.0:
				# Pega mais embaixo do cabo: o topo na palma deixaria a vassoura arrastando no chão.
				var no := pivo.get_child(0) as Node3D
				no.position.y += (no.get_meta("limites", AABB()) as AABB).size.y * float(ajuste["agarra"])
	return ancora.get_parent() if ancora.get_parent() is BoneAttachment3D else ancora


func _trabalhando() -> bool:
	return animador != null and animador.has_method("trabalhando") and bool(animador.trabalhando())


## Um pulso por quadro: chegou ao posto? Então trabalha (o clipe da ação, em laço) ou, se
## é hora de se recolher, entra em casa. Saiu do posto, larga o trabalho. O que se leva
## só para andar ("mao_andando", "cabeca_andando") some quando ele chega.
func _atualizar_trabalho() -> void:
	if _agenda.is_empty():
		return
	var chegou := Vector2(_alvo.x - global_position.x, _alvo.z - global_position.z).length() < 0.8
	if chegou and _acao == "recolhido" and bool(dados.get("recolhe", false)):
		_recolher(true)
		return
	var parado := chegou and _velocidade_atual < 0.25
	if parado and ACOES.has(_acao) and not _trabalhando():
		_comecar_o_trabalho()
	elif not parado and _trabalhando():
		animador.parar_trabalho()
	for no in _levados_andando:
		if is_instance_valid(no):
			(no as Node3D).visible = not parado


func _comecar_o_trabalho() -> void:
	var clipe := String(ACOES.get(_acao, ""))
	if clipe == "" or animador == null or not animador.has_method("trabalhar"):
		return
	if not animador.trabalhar(clipe, not clipe in SEM_LACO):
		var outro := String(SUBSTITUTO.get(clipe, ""))
		if outro != "":
			animador.trabalhar(outro, not outro in SEM_LACO)


## RECOLHER-SE: na porta de casa o morador some (invisível e sem colisão) e só volta
## quando a agenda o chama. O corpo continua na cena, com o processamento mínimo, para
## acordar de manhã: desligar o processo dele (PROCESS_MODE_DISABLED) não o acordaria.
var _camadas_de_fora := Vector2i(-1, -1)

func _recolher(dentro: bool) -> void:
	if dentro == _recolhido:
		return
	_recolhido = dentro
	visible = not dentro
	if dentro:
		_camadas_de_fora = Vector2i(collision_layer, collision_mask)
		collision_layer = 0
		collision_mask = 0
		velocity = Vector3.ZERO
		# Quem entra em casa no meio da fala para de falar: a vez volta à fila.
		_calar_a_boca()
		balao.esconder()
	elif _camadas_de_fora.x >= 0:
		collision_layer = _camadas_de_fora.x
		collision_mask = _camadas_de_fora.y


func esta_recolhido() -> bool:
	return _recolhido


## A ECONOMIA LONGE: a mais de `LONGE` do jogador o morador anda o caminho sem física
## nem colisão (o chão é o do terreno) e com o esqueleto parado — ninguém o vê, e
## catorze corpos andando em silêncio custariam o quadro de quem está no píer.
## Devolve se ele andou assim neste quadro.
func _andar_longe(delta: float) -> bool:
	var longe: bool = jogador != null and terreno != null and not _destino_avulso.is_finite() and not _nadando \
		and jogador.global_position.distance_squared_to(global_position) > LONGE * LONGE
	if longe != _dormindo:
		_dormindo = longe
		if animador != null and animador.has_method("dormir"):
			animador.dormir(longe)
	if not longe:
		return false
	var falta := _alvo - global_position
	falta.y = 0.0
	if falta.length() < 0.6:
		velocity = Vector3.ZERO
		return true
	var rumo := _ponto_do_caminho(_alvo, delta) - global_position
	rumo.y = 0.0
	if _esperando_a_malha:
		# A malha ainda não respondeu: parado, e não reto por cima da água.
		_velocidade_atual = 0.0
		return true
	var direcao := rumo.normalized() if rumo.length() > 0.05 else falta.normalized()
	global_position += direcao * _velocidade_de_passo() * delta
	var chao: float = terreno.ground_height_at(global_position)
	if chao > terreno.water_level():
		# No píer o chão do terreno é o fundo do mar: ali o corpo fica na altura em que estava.
		global_position.y = chao + 0.05
	visual.rotation.y = atan2(direcao.x, direcao.z)
	_velocidade_atual = 0.0
	return true
