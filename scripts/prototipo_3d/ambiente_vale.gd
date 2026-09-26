class_name AmbienteVale
extends Node3D
## Som do vale: a mata do Recôncavo de dia (aves, insetos) e de noite (grilos, sapos,
## corujas) em fusão pela luz do dia; e fontes por proximidade — o mar no
## píer, o riacho nos pontos do rio, a fogueira do terreiro quando está acesa.
## Os insetos e grilos da mata são estridentes: surgem só em episódios curtos,
## com longas pausas entre eles, em vez de um loop contínuo.
## Os loops de 24 s vieram do ElevenLabs Sound Effects (docs/ESTRATEGIA_SONORA.md).

const PASTA := "res://assets/audio/ambiente/"
const MATA_DIA := PASTA + "mata_dia.mp3"
const MATA_NOITE := PASTA + "mata_noite.mp3"
const AVES := PASTA + "aves_reconcavo.ogg"
const MAR := PASTA + "mare_mansa.ogg"
const RIACHO := PASTA + "riacho.mp3"
const FOGUEIRA := PASTA + "fogueira.mp3"
## Episódios da mata (segundos): pausa em silêncio, duração audível e rampa de volume.
const MATA_PAUSA := Vector2(60.0, 150.0)
const MATA_DURACAO := Vector2(6.0, 12.0)
const MATA_RAMPA := 2.5
const MATA_AJUSTE_DB := -5.0

var _dia: AudioStreamPlayer
var _noite: AudioStreamPlayer
var _aves: AudioStreamPlayer
var _fontes: Array[Dictionary] = []
var _mata_fator := 0.0
var _mata_alvo := 0.0
var _mata_espera := randf_range(20.0, 45.0)


func _ready() -> void:
	_dia = _tocador(MATA_DIA)
	_noite = _tocador(MATA_NOITE)
	_aves = _tocador(AVES)
	Dia.hora_mudou.connect(_aplicar)
	if Audio.has_signal("volumes_alterados"):
		Audio.volumes_alterados.connect(func() -> void: _aplicar(Dia.hora))
	_aplicar(Dia.hora)


func _process(delta: float) -> void:
	_mata_espera -= delta
	if _mata_espera <= 0.0:
		_mata_alvo = 1.0 - _mata_alvo
		var faixa := MATA_DURACAO if _mata_alvo > 0.0 else MATA_PAUSA
		_mata_espera = randf_range(faixa.x, faixa.y)
	if not is_equal_approx(_mata_fator, _mata_alvo):
		_mata_fator = move_toward(_mata_fator, _mata_alvo, delta / MATA_RAMPA)
		_aplicar(Dia.hora)


## Fonte posicional em loop na `camada` indicada (Audio.CAMADAS_AMBIENTE), que define o
## controle de volume dela. `noturno` faz a fonte acompanhar a noite (fogueira acesa).
func fonte(camada: String, caminho: String, posicao: Vector3, alcance: float, ajuste_db: float = 0.0, noturno: bool = false) -> AudioStreamPlayer3D:
	var fluxo := Audio.carregar_loop(caminho)
	if fluxo == null:
		return null
	var tocador := AudioStreamPlayer3D.new()
	tocador.stream = fluxo
	tocador.position = posicao
	tocador.max_distance = alcance
	tocador.unit_size = alcance * 0.18
	tocador.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	tocador.volume_db = -80.0
	add_child(tocador)
	tocador.play(randf() * 20.0)
	_fontes.append({"tocador": tocador, "camada": camada, "ajuste": ajuste_db, "noturno": noturno})
	_aplicar(Dia.hora)
	return tocador


func _tocador(caminho: String) -> AudioStreamPlayer:
	var tocador := AudioStreamPlayer.new()
	tocador.volume_db = -80.0
	add_child(tocador)
	var fluxo := Audio.carregar_loop(caminho)
	if fluxo != null:
		tocador.stream = fluxo
		tocador.play(randf() * 20.0)
	return tocador


func _aplicar(_hora: float) -> void:
	var luz := Dia.luz_do_dia()
	var mata := Audio.volume_camada_db("mata")
	_dia.volume_db = _mistura(mata + MATA_AJUSTE_DB, luz * _mata_fator)
	_noite.volume_db = _mistura(mata + 1.5 + MATA_AJUSTE_DB, (1.0 - luz) * _mata_fator)
	# As aves cantam mais no alvorecer e no fim da tarde.
	var horizonte := 1.0 - smoothstep(0.75, 1.0, luz)
	_aves.volume_db = _mistura(Audio.volume_camada_db("aves") - 7.0, luz * (0.55 + 0.45 * horizonte))
	for fonte_info in _fontes:
		var tocador: AudioStreamPlayer3D = fonte_info["tocador"]
		var fator := (1.0 - luz) if bool(fonte_info["noturno"]) else 1.0
		tocador.volume_db = _mistura(Audio.volume_camada_db(String(fonte_info["camada"])) + float(fonte_info["ajuste"]), fator)


func _mistura(base_db: float, fator: float) -> float:
	if fator <= 0.01:
		return -80.0
	return maxf(-80.0, base_db + linear_to_db(fator))
