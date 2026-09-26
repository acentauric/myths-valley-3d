class_name GuiaPedro
extends MoradorNPC
## Pedro, o pescador que conduz o tutorial: acompanha o jogador de perto e narra as
## missões de chegada (praça, capela, casa de pasto, roçado, píer antes de escurecer)
## com voz do ElevenLabs quando está por perto. Ao entardecer avisa que vai escurecer.

signal missao_mudou(texto: String, alvo: Vector3, indice: int, total: int)
signal narrou(texto: String)

const MISSOES := [
	{"id": "praca", "ancora": "Praça", "raio": 14.0, "audio": "pedro_praca", "texto": "Vem comigo. Que tal a gente ir até a praça? É ali que a vila começa."},
	{"id": "capela", "ancora": "Igreja", "raio": 12.0, "audio": "pedro_capela", "texto": "Agora a capela. Todo mundo do arraial passa por lá, cedo ou tarde."},
	{"id": "casa_pasto", "ancora": "Restaurante", "raio": 11.0, "audio": "pedro_casa_pasto", "texto": "Tá com fome? A casa de pasto é logo ali. Depois eu te mostro o roçado de mandioca."},
	{"id": "rocado", "ancora": "Roçado", "raio": 13.0, "audio": "", "texto": "Esse é o roçado. Mandioca: o pão desta terra."},
	{"id": "pier", "ancora": "Pier", "raio": 11.0, "audio": "pedro_pier", "texto": "Olha o sol. Bora pro píer antes de escurecer, que a maré conta história."},
]
const SEGUIR_MAX := 4.6
const CORRER_ALEM := 9.5
const ANDAR := 3.0
const CORRER := 5.7

var missao := -1
var _iniciado := false
var _espera := 0.0
var _anoiteceu_hoje := false


func _ready() -> void:
	super()
	intervalo_saudacao_ms = 1 << 30


func _physics_process(delta: float) -> void:
	if jogador == null:
		return
	var para_jogador := jogador.global_position - global_position
	para_jogador.y = 0.0
	var distancia := para_jogador.length()
	var direcao := Vector3.ZERO
	var velocidade := ANDAR
	if distancia > SEGUIR_MAX:
		direcao = para_jogador / distancia
		velocidade = CORRER if distancia > CORRER_ALEM else ANDAR
	_mover(direcao, velocidade, delta)
	if direcao == Vector3.ZERO:
		_olhar_para(jogador.global_position, delta)
	_atualizar_animacao(delta)
	_atualizar_interacao(delta)
	_atualizar_missao(delta)
	_verificar_anoitecer()


func saudar() -> void:
	super()
	if not _iniciado:
		_iniciado = true
		missao = 0
		_espera = 6.5


func _atualizar_missao(delta: float) -> void:
	if not _iniciado or missao < 0 or missao >= MISSOES.size():
		return
	if _espera > 0.0:
		_espera -= delta
		if _espera <= 0.0:
			_anunciar()
		return
	var alvo := _posicao_da_missao(missao)
	if jogador.global_position.distance_to(alvo) < float(MISSOES[missao]["raio"]):
		missao += 1
		if missao >= MISSOES.size():
			narrar("", "É isso: o arraial inteiro. Agora o resto é com você.")
			missao_mudou.emit("Você conheceu o arraial. Explore o vale como quiser — Pedro fica por perto.", Vector3.ZERO, MISSOES.size(), MISSOES.size())
		else:
			_espera = 1.4


func _anunciar() -> void:
	var m: Dictionary = MISSOES[missao]
	narrar(String(m["audio"]), String(m["texto"]))
	missao_mudou.emit("Pedro: " + String(m["texto"]), _posicao_da_missao(missao), missao + 1, MISSOES.size())


## Fala uma narração: balão e, quando existe, o áudio (por proximidade, como a saudação).
func narrar(nome_audio: String, texto: String) -> void:
	mostrar_balao(texto, 8.0)
	var caminho := PASTA_VOZES + nome_audio + ".mp3"
	if nome_audio != "" and ResourceLoader.exists(caminho):
		voz.stop()
		voz.stream = load(caminho)
		voz.play()
	if animador != null and animador.has_method("play_gesture"):
		animador.play_gesture(2)
	narrou.emit(texto)


func _verificar_anoitecer() -> void:
	var periodo := Dia.periodo()
	if periodo == "entardecer" and not _anoiteceu_hoje and _espera <= 0.0:
		_anoiteceu_hoje = true
		narrar("pedro_anoitecer", "Daqui a pouco escurece. Quando terminar, volte pra cama. Apagar no chão não descansa igual.")
	elif periodo == "manha":
		_anoiteceu_hoje = false


func _posicao_da_missao(indice: int) -> Vector3:
	return ancoras.get(String(MISSOES[indice]["ancora"]), Vector3.ZERO)


func texto_da_missao() -> String:
	if not _iniciado:
		return "Fale com Pedro: ele veio te esperar no píer."
	if missao >= MISSOES.size():
		return "Você conheceu o arraial. Explore o vale como quiser."
	return "Pedro: " + String(MISSOES[missao]["texto"])
