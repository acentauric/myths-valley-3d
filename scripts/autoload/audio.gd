extends Node
## Mixagem e preferências locais independentes de partidas e salvamentos.
## Fontes, prompts e direção: docs/ESTRATEGIA_SONORA.md.

const ARQUIVO_PREFERENCIAS := "user://audio.cfg"
const PASTA_EFEITOS := "res://assets/audio/efeitos/"
const MUSICA_MENU_1 := "res://assets/audio/musica/tema_introducao.wav"
const MUSICA_MENU_2 := "res://assets/audio/musica/tema_menu.mp3"
const MUSICA_MENU_3 := "res://assets/audio/musica/tema_menu_2.mp3"
const MUSICA_MENU_4 := "res://assets/audio/musica/tema_reconcavo.ogg"
const MUSICA_MENU := MUSICA_MENU_4
const MUSICA_ROCADO := "res://assets/audio/musica/tema_rocado.mp3"
const NARRACAO_ABERTURA := "res://assets/audio/narracao/boas_vindas.mp3"
const AMBIENTE_MAR := "res://assets/audio/ambiente/mare_mansa.ogg"
const AMBIENTE_AVES := "res://assets/audio/ambiente/aves_reconcavo.ogg"
const VOLUME_MUSICA := -10.0
const VOLUME_NARRACAO := -3.0
const VOLUME_EFEITO := -6.0
const VOLUME_PASSO := -16.0
const VOLUME_AMBIENTE := -5.0
## Falas dos personagens e narração: base acima dos efeitos para a voz se destacar.
const VOLUME_VOZ := 2.0
const VARIACAO_DO_PASSO := 0.12
## Camadas do ambiente com volume próprio, aplicado sobre o volume geral de Ambiente.
const CAMADAS_AMBIENTE := ["aves", "mar", "riacho", "fogueira", "mata"]
const ROTULOS_CAMADAS := {"aves": "Aves", "mar": "Mar", "riacho": "Riacho", "fogueira": "Fogueira", "mata": "Insetos e grilos"}

## Emitido quando um volume muda: os tocadores 3D do vale (NPCs, ambiente) reaplicam o seu.
signal volumes_alterados

var som_ativo: bool = true
var musica_menu_opcao: int = 4
var efeitos_menu_opcao: int = 2
var ambiente_menu_opcao: int = 3
var volume_musica: float = 0.8
var volume_efeitos: float = 0.8
var volume_ambiente: float = 0.45
var volume_vozes: float = 1.0
var volume_narracao: float = 1.0
var volume_camadas: Dictionary = {"aves": 1.0, "mar": 1.0, "riacho": 1.0, "fogueira": 1.0, "mata": 1.0}
var _musica: AudioStreamPlayer
var _narracao: AudioStreamPlayer
var _efeitos: AudioStreamPlayer
var _passos: AudioStreamPlayer
var _interface: AudioStreamPlayer
var _mar: AudioStreamPlayer
var _aves: AudioStreamPlayer
var _timer_previa: Timer
var _cache: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _transicao_musica: Tween
var _transicoes_ambiente: Dictionary = {}
var _caminho_musica: String = ""
var _ambiente_menu_ativo: bool = false
var _opcao_previa: int = -1
var _ultimo_movimento_ms: int = -1000
var _ganho_musica: float = 1.0:
	set(valor):
		_ganho_musica = valor
		if is_instance_valid(_musica):
			_musica.volume_db = _volume_db(VOLUME_MUSICA, volume_musica * _ganho_musica)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_carregar_preferencias()
	_musica = _criar_tocador("Musica", VOLUME_MUSICA)
	_narracao = _criar_tocador("Narracao", VOLUME_NARRACAO)
	_efeitos = _criar_tocador("Efeitos", VOLUME_EFEITO)
	_passos = _criar_tocador("Passos", VOLUME_PASSO)
	_interface = _criar_tocador("Interface", VOLUME_EFEITO)
	_mar = _criar_tocador("Mare", VOLUME_AMBIENTE)
	_aves = _criar_tocador("Aves", VOLUME_AMBIENTE)
	_timer_previa = Timer.new()
	_timer_previa.one_shot = true
	_timer_previa.wait_time = 6.0
	_timer_previa.timeout.connect(_encerrar_previa_ambiente)
	add_child(_timer_previa)
	_rng.randomize()
	_aplicar_volumes()
	_aplicar_mute()


func alternar_som() -> bool:
	definir_som_ativo(not som_ativo)
	return som_ativo


func definir_som_ativo(ativo: bool) -> void:
	som_ativo = ativo
	_aplicar_mute()
	_salvar_preferencias()


func obter_caminho_musica_menu() -> String:
	var caminhos := [MUSICA_MENU_1, MUSICA_MENU_2, MUSICA_MENU_3, MUSICA_MENU_4]
	var caminho: String = caminhos[clampi(musica_menu_opcao, 1, 4) - 1]
	return caminho if ResourceLoader.exists(caminho) else MUSICA_MENU_1


func definir_musica_menu(opcao: int) -> void:
	musica_menu_opcao = clampi(opcao, 1, 4)
	_salvar_preferencias()
	tocar_musica(obter_caminho_musica_menu())


func definir_efeitos_menu(opcao: int) -> void:
	efeitos_menu_opcao = clampi(opcao, 1, 2)
	_salvar_preferencias()


func definir_ambiente_menu(opcao: int) -> void:
	ambiente_menu_opcao = clampi(opcao, 0, 3)
	_timer_previa.stop()
	_opcao_previa = -1
	_aplicar_ambiente(ambiente_menu_opcao if _ambiente_menu_ativo else 0)
	_salvar_preferencias()


func definir_volume_musica(valor: float) -> void:
	volume_musica = _normalizar_volume(valor)
	_aplicar_volumes()
	_salvar_preferencias()


func definir_volume_efeitos(valor: float) -> void:
	volume_efeitos = _normalizar_volume(valor)
	_aplicar_volumes()
	_salvar_preferencias()


func definir_volume_ambiente(valor: float) -> void:
	volume_ambiente = _normalizar_volume(valor)
	_aplicar_volumes()
	_salvar_preferencias()


func definir_volume_vozes(valor: float) -> void:
	volume_vozes = _normalizar_volume(valor)
	_aplicar_volumes()
	_salvar_preferencias()


func definir_volume_narracao(valor: float) -> void:
	volume_narracao = _normalizar_volume(valor)
	_aplicar_volumes()
	_salvar_preferencias()


func definir_volume_camada(camada: String, valor: float) -> void:
	if not volume_camadas.has(camada):
		return
	volume_camadas[camada] = _normalizar_volume(valor)
	_aplicar_volumes()
	_salvar_preferencias()


func tocar_musica(caminho: String = MUSICA_ROCADO, forcar_troca: bool = false) -> void:
	var fluxo := _carregar(caminho)
	if fluxo == null:
		return
	if caminho == MUSICA_ROCADO:
		parar_ambiente_menu()
	# Reentrar no menu ou mudar opções visuais não reinicia a composição.
	if not forcar_troca and caminho == _caminho_musica and (_musica.playing or (_transicao_musica and _transicao_musica.is_running())):
		return
	_configurar_loop(fluxo)
	if _transicao_musica and _transicao_musica.is_valid():
		_transicao_musica.kill()
	_caminho_musica = caminho
	_transicao_musica = create_tween()
	if _musica.playing:
		_transicao_musica.tween_property(self, "_ganho_musica", 0.0, 0.22)
	else:
		_ganho_musica = 0.0
	_transicao_musica.tween_callback(func() -> void:
		_musica.stream = fluxo
		_musica.play()
	)
	_transicao_musica.tween_property(self, "_ganho_musica", 1.0, 0.65)


func parar_musica() -> void:
	if _transicao_musica and _transicao_musica.is_valid():
		_transicao_musica.kill()
	_musica.stop()
	_caminho_musica = ""


func iniciar_ambiente_menu() -> void:
	_ambiente_menu_ativo = true
	_timer_previa.stop()
	_opcao_previa = -1
	_aplicar_ambiente(ambiente_menu_opcao)


func parar_ambiente_menu() -> void:
	_ambiente_menu_ativo = false
	_timer_previa.stop()
	_opcao_previa = -1
	_aplicar_ambiente(0)


## Prévia de seis segundos: respeita mute e volume, preserva a preferência.
func testar_ambiente_menu(opcao: int = -1) -> void:
	_opcao_previa = ambiente_menu_opcao if opcao < 0 else clampi(opcao, 0, 3)
	_aplicar_ambiente(_opcao_previa)
	_timer_previa.start()


func testar_efeito_menu(nome: String = "menu_confirma") -> void:
	# O clique explícito de prévia deve ser audível mesmo após focar o botão.
	if nome in ["menu_mover", "ui_hover"]:
		_ultimo_movimento_ms = -1000
	efeito(nome)


## Narração não bloqueia a abertura nem a entrada no mundo.
func narrar_abertura() -> void:
	var fluxo := _carregar(NARRACAO_ABERTURA)
	if fluxo != null:
		_narracao.stream = fluxo
		_narracao.play()


func parar_narracao() -> void:
	_narracao.stop()


func efeito(nome: String) -> void:
	var aliases := {"ui_confirmar": "menu_confirma", "ui_hover": "menu_mover", "ui_voltar": "menu_voltar"}
	var nome_base: String = aliases.get(nome, nome)
	var menu := nome_base in ["menu_mover", "menu_confirma", "menu_voltar"]
	if nome_base == "menu_mover":
		var agora := Time.get_ticks_msec()
		if agora - _ultimo_movimento_ms < 65:
			return
		_ultimo_movimento_ms = agora
	var arquivo := nome_base
	if menu and efeitos_menu_opcao == 2:
		arquivo += "_madeira"
	if not ResourceLoader.exists(PASTA_EFEITOS + arquivo + ".mp3"):
		arquivo = "menu_mover" if nome_base == "menu_voltar" else nome_base
	var fluxo := _carregar(PASTA_EFEITOS + arquivo + ".mp3")
	if fluxo == null:
		return
	var tocador := _interface if menu else _efeitos
	tocador.stream = fluxo
	tocador.pitch_scale = 1.0
	tocador.play()


func passo(terreno: String, correndo: bool = false) -> void:
	var nome := "corrida" if correndo else "passo_" + terreno
	var fluxo := _carregar(PASTA_EFEITOS + nome + ".mp3")
	if fluxo == null and correndo:
		fluxo = _carregar(PASTA_EFEITOS + "passo_" + terreno + ".mp3")
	if fluxo == null:
		return
	_passos.stream = fluxo
	_passos.pitch_scale = 1.0 + _rng.randf_range(-VARIACAO_DO_PASSO, VARIACAO_DO_PASSO)
	_passos.play()


func _encerrar_previa_ambiente() -> void:
	_opcao_previa = -1
	_aplicar_ambiente(ambiente_menu_opcao if _ambiente_menu_ativo else 0)


func _aplicar_ambiente(opcao: int) -> void:
	_sincronizar_camada(_mar, AMBIENTE_MAR, opcao in [1, 3], 0.0, "mar")
	_sincronizar_camada(_aves, AMBIENTE_AVES, opcao in [2, 3], -3.0, "aves")


func _sincronizar_camada(tocador: AudioStreamPlayer, caminho: String, ativo: bool, ajuste_db: float, camada: String) -> void:
	var id := tocador.get_instance_id()
	if _transicoes_ambiente.has(id):
		var anterior: Tween = _transicoes_ambiente[id]
		if anterior.is_valid():
			anterior.kill()
	if ativo:
		var fluxo := _carregar(caminho)
		if fluxo == null:
			return
		_configurar_loop(fluxo)
		if not tocador.playing or tocador.stream != fluxo:
			tocador.stream = fluxo
			tocador.volume_db = -80.0
			tocador.play()
	elif not tocador.playing:
		return
	var transicao := create_tween()
	_transicoes_ambiente[id] = transicao
	var alvo := volume_camada_db(camada) + ajuste_db if ativo else -80.0
	transicao.tween_property(tocador, "volume_db", alvo, 0.6)
	if not ativo:
		transicao.tween_callback(tocador.stop)


## Volume-base (em dB) das fontes posicionais que seguem os controles de AJUSTAR.
func volume_ambiente_db() -> float:
	return _volume_db(VOLUME_AMBIENTE, volume_ambiente)


## Volume-base (em dB) de uma camada do ambiente: geral de Ambiente × volume da camada.
func volume_camada_db(camada: String) -> float:
	return _volume_db(VOLUME_AMBIENTE, volume_ambiente * float(volume_camadas.get(camada, 1.0)))


func volume_efeitos_db() -> float:
	return _volume_db(VOLUME_EFEITO, volume_efeitos)


func volume_vozes_db() -> float:
	return _volume_db(VOLUME_VOZ, volume_vozes)


## Carrega um áudio já configurado para repetir (loops de ambiente do vale).
func carregar_loop(caminho: String) -> AudioStream:
	var fluxo := _carregar(caminho)
	if fluxo != null:
		_configurar_loop(fluxo)
	return fluxo


func _aplicar_volumes() -> void:
	_ganho_musica = _ganho_musica
	_efeitos.volume_db = _volume_db(VOLUME_EFEITO, volume_efeitos)
	_interface.volume_db = _volume_db(VOLUME_EFEITO, volume_efeitos)
	_passos.volume_db = _volume_db(VOLUME_PASSO, volume_efeitos)
	_narracao.volume_db = _volume_db(VOLUME_NARRACAO, volume_narracao)
	if _opcao_previa >= 0:
		_aplicar_ambiente(_opcao_previa)
	elif _ambiente_menu_ativo:
		_aplicar_ambiente(ambiente_menu_opcao)
	volumes_alterados.emit()


func _aplicar_mute() -> void:
	var indice := AudioServer.get_bus_index("Master")
	if indice >= 0:
		AudioServer.set_bus_mute(indice, not som_ativo)


func _carregar_preferencias() -> void:
	if not ResourceLoader.exists(MUSICA_MENU_4):
		musica_menu_opcao = 1
	var configuracao := ConfigFile.new()
	if configuracao.load(ARQUIVO_PREFERENCIAS) != OK:
		return
	som_ativo = bool(configuracao.get_value("audio", "som_ativo", true))
	musica_menu_opcao = clampi(int(configuracao.get_value("audio", "musica_menu", musica_menu_opcao)), 1, 4)
	efeitos_menu_opcao = clampi(int(configuracao.get_value("audio", "efeitos_menu", 2)), 1, 2)
	ambiente_menu_opcao = clampi(int(configuracao.get_value("audio", "ambiente_menu", 3)), 0, 3)
	volume_musica = _normalizar_volume(float(configuracao.get_value("audio", "volume_musica", 0.8)))
	volume_efeitos = _normalizar_volume(float(configuracao.get_value("audio", "volume_efeitos", 0.8)))
	volume_ambiente = _normalizar_volume(float(configuracao.get_value("audio", "volume_ambiente", 0.45)))
	volume_vozes = _normalizar_volume(float(configuracao.get_value("audio", "volume_vozes", 1.0)))
	volume_narracao = _normalizar_volume(float(configuracao.get_value("audio", "volume_narracao", 1.0)))
	for camada in CAMADAS_AMBIENTE:
		volume_camadas[camada] = _normalizar_volume(float(configuracao.get_value("audio", "volume_" + camada, 1.0)))


func _salvar_preferencias() -> void:
	var configuracao := ConfigFile.new()
	configuracao.set_value("audio", "som_ativo", som_ativo)
	configuracao.set_value("audio", "musica_menu", musica_menu_opcao)
	configuracao.set_value("audio", "efeitos_menu", efeitos_menu_opcao)
	configuracao.set_value("audio", "ambiente_menu", ambiente_menu_opcao)
	configuracao.set_value("audio", "volume_musica", volume_musica)
	configuracao.set_value("audio", "volume_efeitos", volume_efeitos)
	configuracao.set_value("audio", "volume_ambiente", volume_ambiente)
	configuracao.set_value("audio", "volume_vozes", volume_vozes)
	configuracao.set_value("audio", "volume_narracao", volume_narracao)
	for camada in CAMADAS_AMBIENTE:
		configuracao.set_value("audio", "volume_" + camada, volume_camadas[camada])
	if configuracao.save(ARQUIVO_PREFERENCIAS) != OK:
		push_warning("Não foi possível salvar as preferências de áudio.")


func _normalizar_volume(valor: float) -> float:
	return clampf(valor, 0.0, 1.0) if is_finite(valor) else 0.0


func _volume_db(base: float, valor: float) -> float:
	return maxf(-80.0, base + linear_to_db(valor)) if valor > 0.0 else -80.0


func _criar_tocador(nome: String, volume: float) -> AudioStreamPlayer:
	var tocador := AudioStreamPlayer.new()
	tocador.name = nome
	tocador.volume_db = volume
	add_child(tocador)
	return tocador


func _configurar_loop(fluxo: AudioStream) -> void:
	if fluxo is AudioStreamMP3 or fluxo is AudioStreamOggVorbis:
		fluxo.loop = true
	elif fluxo is AudioStreamWAV:
		fluxo.loop_mode = AudioStreamWAV.LOOP_FORWARD
		if fluxo.loop_end <= 0:
			fluxo.loop_begin = 0
			fluxo.loop_end = int(fluxo.get_length() * fluxo.mix_rate)


func _carregar(caminho: String) -> AudioStream:
	if _cache.has(caminho):
		return _cache[caminho]
	if not ResourceLoader.exists(caminho):
		push_warning("Áudio ausente: %s" % caminho)
		_cache[caminho] = null
		return null
	var fluxo := load(caminho) as AudioStream
	_cache[caminho] = fluxo
	return fluxo
