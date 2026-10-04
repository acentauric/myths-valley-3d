class_name AmbienteVale
extends Node3D
## Som do vale: a mata do Recôncavo de dia (aves, insetos) e de noite (grilos, sapos,
## corujas) em fusão pela luz do dia; e fontes por proximidade — o mar no
## píer, o riacho nos pontos do rio, a fogueira do terreiro quando está acesa.
## Os insetos e grilos da mata são estridentes: surgem só em episódios curtos,
## com longas pausas entre eles, em vez de um loop contínuo.
## Os loops de 24 s vieram do ElevenLabs Sound Effects (docs/sistemas/ESTRATEGIA_SONORA.md).

const PASTA := "res://assets/audio/ambiente/"
const MATA_DIA := PASTA + "mata_dia.mp3"
const MATA_NOITE := PASTA + "mata_noite.mp3"
const AVES := PASTA + "aves_reconcavo.ogg"
const MAR := PASTA + "mare_mansa.ogg"
const RIACHO := PASTA + "riacho.mp3"
const FOGUEIRA := PASTA + "fogueira.mp3"
const EFEITOS := "res://assets/audio/efeitos/"
## Cantos do bem-te-vi (de dia) e sussurros da mata fechada, tocados em pontos
## aleatórios ao redor do jogador para o vale parecer habitado.
const BEM_TE_VI := [EFEITOS + "bem_te_vi_1.mp3", EFEITOS + "bem_te_vi_2.mp3"]
const SUSSURROS := [PASTA + "mata_sussurro_1.mp3", PASTA + "mata_sussurro_2.mp3"]
## Pausas (segundos) entre um canto e outro e entre sussurros na mata.
const BEM_TE_VI_PAUSA := Vector2(18.0, 50.0)
const SUSSURRO_PAUSA := Vector2(12.0, 35.0)
## Checar o polígono da mata a cada quadro seria desperdício: meio segundo basta.
const MATA_CHECAGEM := 0.5
## Episódios da mata (segundos): pausa em silêncio, duração audível e rampa de volume.
const MATA_PAUSA := Vector2(60.0, 150.0)
const MATA_DURACAO := Vector2(6.0, 12.0)
const MATA_RAMPA := 2.5
const MATA_AJUSTE_DB := -12.0

var _dia: AudioStreamPlayer
var _noite: AudioStreamPlayer
var _aves: AudioStreamPlayer
var _fontes: Array[Dictionary] = []
var _mata_fator := 0.0
var _mata_alvo := 0.0
var _mata_espera := randf_range(20.0, 45.0)
var _bem_te_vi_espera := randf_range(BEM_TE_VI_PAUSA.x, BEM_TE_VI_PAUSA.y)
var _sussurro_espera := 0.0
var _mata_relogio := 0.0
var _na_mata := false
var _jogador: Node3D
var _mundo: Node


func _ready() -> void:
	_dia = _tocador(MATA_DIA)
	_noite = _tocador(MATA_NOITE)
	_aves = _tocador(AVES)
	Dia.hora_mudou.connect(_aplicar)
	if Audio.has_signal("volumes_alterados"):
		Audio.volumes_alterados.connect(_aplicar_volumes)
	_aplicar(Dia.hora)


func _aplicar_volumes() -> void:
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
	_processar_bem_te_vi(delta)
	_processar_mata_fechada(delta)


func _exit_tree() -> void:
	# Saindo do vale com o jogador dentro da mata, a trilha de tensão não pode ficar presa.
	if _na_mata:
		Audio.tocar_musica_mata(false)


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


## DENTRO DE UMA CONSTRUÇÃO o mato, a noite e as aves chegam abafados pela
## parede. As fontes de lugar (mar, fogueira) já somem sozinhas: o cômodo mora
## longe delas. 0 é ao ar livre, 1 é de porta fechada. Ver `interiores.gd`.
var abafado := 0.0:
	set(valor):
		abafado = clampf(valor, 0.0, 1.0)
		_aplicar(Dia.hora)
## Quanto do som de fora passa pela parede (12%, ou -18 dB).
const PASSA_PELA_PAREDE := 0.12


func _aplicar(_hora: float) -> void:
	if _dia == null:
		return
	var luz := Dia.luz_do_dia()
	var mata := Audio.volume_camada_db("mata")
	var parede := lerpf(1.0, PASSA_PELA_PAREDE, abafado)
	_dia.volume_db = _mistura(mata + MATA_AJUSTE_DB, luz * _mata_fator * parede)
	_noite.volume_db = _mistura(mata + 1.5 + MATA_AJUSTE_DB, (1.0 - luz) * _mata_fator * parede)
	# As aves cantam mais no alvorecer e no fim da tarde.
	var horizonte := 1.0 - smoothstep(0.75, 1.0, luz)
	_aves.volume_db = _mistura(Audio.volume_camada_db("aves") - 7.0, luz * (0.55 + 0.45 * horizonte) * parede)
	for fonte_info in _fontes:
		var tocador: AudioStreamPlayer3D = fonte_info["tocador"]
		var fator := (1.0 - luz) if bool(fonte_info["noturno"]) else 1.0
		tocador.volume_db = _mistura(Audio.volume_camada_db(String(fonte_info["camada"])) + float(fonte_info["ajuste"]), fator)


func _mistura(base_db: float, fator: float) -> float:
	if fator <= 0.01:
		return -80.0
	return maxf(-80.0, base_db + linear_to_db(fator))


## Bem-te-vi de manhã e à tarde: um canto curto vindo de um ponto aleatório ao
## redor do jogador, no volume da camada "aves".
func _processar_bem_te_vi(delta: float) -> void:
	# Bem-te-vi não canta dentro da igreja: o canto é posto ao redor do corpo,
	# e lá dentro ele sairia de dentro das paredes.
	if Dia.periodo() not in ["manha", "tarde"] or abafado > 0.5:
		return
	_bem_te_vi_espera -= delta
	if _bem_te_vi_espera > 0.0:
		return
	_bem_te_vi_espera = randf_range(BEM_TE_VI_PAUSA.x, BEM_TE_VI_PAUSA.y)
	var jogador := _jogador_atual()
	if jogador == null:
		return
	var caminho: String = BEM_TE_VI[randi() % BEM_TE_VI.size()]
	_tocar_pontual(caminho, _posicao_ao_redor(jogador.global_position, 15.0, 30.0), 45.0, "aves", -4.0)


## Mata fechada: ao entrar, a música cruza para a trilha de tensão e sussurros
## esparsos surgem perto do jogador; ao sair, tudo volta ao normal.
func _processar_mata_fechada(delta: float) -> void:
	_mata_relogio -= delta
	var jogador := _jogador_atual()
	if jogador == null:
		return
	if _mata_relogio <= 0.0:
		_mata_relogio = MATA_CHECAGEM
		var mundo := _mundo_atual()
		if mundo == null or not mundo.has_method("na_mata_fechada"):
			return
		var dentro: bool = mundo.na_mata_fechada(jogador.global_position)
		if dentro != _na_mata:
			_na_mata = dentro
			Audio.tocar_musica_mata(dentro)
			if dentro:
				# O primeiro sussurro vem logo, para marcar a mudança de clima.
				_sussurro_espera = randf_range(4.0, 10.0)
	if not _na_mata:
		return
	_sussurro_espera -= delta
	if _sussurro_espera > 0.0:
		return
	_sussurro_espera = randf_range(SUSSURRO_PAUSA.x, SUSSURRO_PAUSA.y)
	var caminho: String = SUSSURROS[randi() % SUSSURROS.size()]
	_tocar_pontual(caminho, _posicao_ao_redor(jogador.global_position, 6.0, 14.0), 30.0, "mata", 2.0)


## Som pontual 3D: tocador descartável na posição dada, com o volume da camada
## (o mesmo controle de AJUSTAR das fontes em loop) e removido ao terminar.
func _tocar_pontual(caminho: String, posicao: Vector3, alcance: float, camada: String, ajuste_db: float = 0.0) -> void:
	if not ResourceLoader.exists(caminho):
		return
	var fluxo := load(caminho) as AudioStream
	if fluxo == null:
		return
	var tocador := AudioStreamPlayer3D.new()
	tocador.stream = fluxo
	tocador.position = posicao
	tocador.max_distance = alcance
	tocador.unit_size = alcance * 0.18
	tocador.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	tocador.volume_db = _mistura(Audio.volume_camada_db(camada) + ajuste_db, 1.0)
	add_child(tocador)
	tocador.finished.connect(tocador.queue_free)
	tocador.play()


## Ponto aleatório num anel ao redor do centro, um pouco acima do chão (galhos).
func _posicao_ao_redor(centro: Vector3, minimo: float, maximo: float) -> Vector3:
	var angulo := randf() * TAU
	var raio := randf_range(minimo, maximo)
	return centro + Vector3(cos(angulo) * raio, randf_range(1.5, 4.0), sin(angulo) * raio)


func _jogador_atual() -> Node3D:
	if not is_instance_valid(_jogador):
		_jogador = get_tree().get_first_node_in_group("map_player") as Node3D
	return _jogador


func _mundo_atual() -> Node:
	if not is_instance_valid(_mundo):
		_mundo = get_tree().get_first_node_in_group("mundo")
	return _mundo
