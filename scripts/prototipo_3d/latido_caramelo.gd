extends Node3D
## Saudação por aproximação; não é loop ambiente nem disputa a vez da fala.
const AUDIO := "res://assets/audio/animais/caramelo_latido.wav"
const INTERVALO := 12.0
const APROXIMACAO := 6.0
const SAIDA := 8.0
static var ultimo_global := -100.0
var _tocador: AudioStreamPlayer3D
var _dentro := false
var _pendente := false
var _proximo := 0.0
var _conferir := 0.0
var _serie := 0

func _ready() -> void:
	name = "LatidoCaramelo"
	process_mode = Node.PROCESS_MODE_ALWAYS
	position.y = 0.45
	_tocador = AudioStreamPlayer3D.new()
	_tocador.stream = AudioStreamWAV.load_from_file(AUDIO)
	_tocador.bus = Audio.GERAL
	_tocador.unit_size = 3.0
	_tocador.max_distance = 22.0
	_tocador.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(_tocador)
	Audio.volumes_alterados.connect(_volume)
	_volume()

func _volume() -> void:
	_tocador.volume_db = maxf(-80, Audio.volume_efeitos_db() - 8)
	if Audio.canal_mudo("efeitos"):
		_tocador.stop()

func _fala_ocupa() -> bool:
	if get_tree().paused or not get_tree().get_nodes_in_group("telas_de_carregamento").is_empty():
		return true
	var dialogo := get_node_or_null("/root/Dialogo")
	if dialogo != null and bool(dialogo.get("ativo")):
		return true
	for fila in get_tree().get_nodes_in_group("fila_de_falas"):
		if not fila.livre():
			return true
	return Audio._narracao != null and Audio._narracao.playing

func _process(delta: float) -> void:
	_conferir -= delta
	if _conferir > 0:
		return
	_conferir = 0.25
	var cao := get_parent()
	if not is_instance_valid(cao.get("jogador")):
		return
	var distancia: float = global_position.distance_to(cao.jogador.global_position)
	_observar(distancia, bool(cao.get("perto")), bool(cao.get("deitado")), _fala_ocupa(), Time.get_ticks_msec() / 1000.0)

## Separada da física para verificar intervalos com relógio determinístico.
func _observar(distancia: float, ativo: bool, dormindo: bool, fala: bool, agora: float) -> bool:
	if fala or not ativo:
		_tocador.stop()
	if distancia >= SAIDA:
		_dentro = false
		_pendente = false
	elif distancia <= APROXIMACAO and not _dentro:
		_dentro = true
		_pendente = true
	if not _pendente or fala or not ativo or dormindo or Audio.canal_mudo("efeitos") or Audio.volume_efeitos <= 0:
		return false
	if agora < _proximo or agora - ultimo_global < 3.0:
		return false
	_pendente = false
	_serie += 1
	_proximo = agora + INTERVALO + (_serie % 3) * 2.0
	ultimo_global = agora
	_tocador.pitch_scale = [1.0, 0.96, 1.04][_serie % 3]
	_tocador.play()
	return true
