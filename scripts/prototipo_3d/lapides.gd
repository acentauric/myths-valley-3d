extends Node
## Interação por proximidade com as lápides do cemitério: perto de um túmulo aparece,
## sobre ele, a tecla E; apertar E abre à esquerda (no painel das casas) uma história
## curta de quem está ali. Afastar-se fecha o painel. Histórias: data/lapides_3d.json.
## Quem sobe numa laje ouve bronca do coveiro (Damião), no balão dele e no aviso.

const DicaTecla = preload("res://scripts/prototipo_3d/dica_tecla.gd")
const DADOS := "res://data/lapides_3d.json"
## Distância (no chão) para a tecla E aparecer e para o painel fechar sozinho.
const ALCANCE := 2.2
const ALCANCE_FECHAR := 4.0
const ALTURA_DICA := 1.5
## Broncas do coveiro, cada vez mais bravas, com a voz dele (ElevenLabs, a mesma do
## Damião). Na terceira ele derruba o jogador da laje.
const BRONCAS := [
	["Ô, moço! Desce daí, que aí embaixo tem gente descansando.", "res://assets/audio/vozes/damiao_bronca_1.mp3"],
	["Moço, eu já pedi! Em cima da cova, não! Respeite quem já foi!", "res://assets/audio/vozes/damiao_bronca_2.mp3"],
	["Chega! Falei duas vezes! Desce daí agora!", "res://assets/audio/vozes/damiao_bronca_3.mp3"],
]
## Folga depois de cada fala antes da próxima bronca, em segundos.
const FOLGA_BRONCA := 1.5
## Sem subir em túmulo por esse tempo, o coveiro esquece e volta à primeira bronca.
const PERDAO := 90.0
## Até onde o coveiro enxerga o cemitério (fora do posto dele, ninguém reclama).
const ALCANCE_COVEIRO := 30.0
## Empurrão da terceira bronca: velocidade horizontal (m/s) e tempo máximo que o coveiro
## leva andando até o túmulo antes de desistir.
const EMPURRAO := 4.5
const TEMPO_MAX_IDA := 15.0
## Meia distância entre colunas de túmulos (2,3 u no world_builder): o vão por onde o
## coveiro passa entre as fileiras.
const VAO_COLUNAS := 1.15

## Morador que reclama (Damião, o zelador do cemitério); definido depois dos moradores.
var coveiro: Node3D
var broncas_dadas := 0
var _espera_bronca := 0.0
var _sem_subir := 0.0
var _voz_bronca: AudioStreamPlayer3D
var _indo_empurrar := false
var _tempo_indo := 0.0
var _world: Node3D
var _jogador: Node3D
var _hud
var _historias: Array = []
var _perto := -1
var _aberta := -1
var _dica: PanelContainer


func configurar(world: Node3D, jogador: Node3D, hud) -> void:
	_world = world
	_jogador = jogador
	_hud = hud
	var dados = JSON.parse_string(FileAccess.get_file_as_string(DADOS))
	if dados is Dictionary:
		_historias = dados.get("lapides", [])
	_dica = DicaTecla.criar(hud.map_layer(), "E", "Ler lápide")


func _process(delta: float) -> void:
	if _world == null:
		return
	_espera_bronca = maxf(0.0, _espera_bronca - delta)
	var em_cima := _em_cima_de_tumulo() >= 0
	_sem_subir = 0.0 if em_cima else _sem_subir + delta
	if _sem_subir > PERDAO:
		broncas_dadas = 0
	if _indo_empurrar:
		_aproximar_para_empurrar(delta)
	elif em_cima and _espera_bronca <= 0.0 and _coveiro_por_perto():
		_dar_bronca()
	var camera := get_viewport().get_camera_3d()
	# Só na câmera do jogador (o mapa usa outra).
	var em_jogo: bool = camera != null and camera == _jogador.get("camera")
	_perto = _mais_proxima() if em_jogo else -1
	# Outra ficha (árvore, casa) tomou o painel: esta já não está aberta.
	if _aberta >= 0 and _hud.get("painel_dono") != self:
		_aberta = -1
	if _aberta >= 0 and _distancia(_aberta) > ALCANCE_FECHAR:
		_aberta = -1
		_hud.clear_house_info()
	if _perto < 0 or _perto == _aberta:
		_dica.visible = false
		return
	DicaTecla.mostrar_em(_dica, camera, _world.lapides[_perto] + Vector3(0, ALTURA_DICA, 0))


## E perto de um túmulo abre a lápide; com ela aberta, E fecha.
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E):
		return
	if _aberta >= 0:
		_aberta = -1
		_hud.clear_house_info()
		get_viewport().set_input_as_handled()
	elif _perto >= 0:
		ler(_perto)
		get_viewport().set_input_as_handled()


## Abre no painel da esquerda a lápide `indice`.
func ler(indice: int) -> void:
	if indice < 0 or indice >= _historias.size():
		return
	var lapide: Dictionary = _historias[indice]
	Audio.efeito("ui_confirmar")
	_hud.show_house_info("%s · %s\n%s" % [lapide.get("nome", ""), lapide.get("datas", ""), lapide.get("historia", "") + "\n\nE: fechar"], "LÁPIDE")
	_hud.set("painel_dono", self)
	_aberta = indice


func lapide_aberta() -> int:
	return _aberta


## Túmulo em cuja laje o jogador está apoiado (acima dela e dentro da pegada), ou -1.
func _em_cima_de_tumulo() -> int:
	if not (_jogador is CharacterBody3D and (_jogador as CharacterBody3D).is_on_floor()):
		return -1
	for indice in range(mini(_world.lapides.size(), _world.lapides_pegada.size())):
		var chao: Vector3 = _world.lapides[indice]
		var pegada: Vector3 = _world.lapides_pegada[indice]
		var p := _jogador.global_position
		if absf(p.x - chao.x) < pegada.x * 0.5 + 0.1 and absf(p.z - chao.z) < pegada.z * 0.5 + 0.1 and p.y > chao.y + pegada.y * 0.6:
			return indice
	return -1


func _coveiro_por_perto() -> bool:
	return is_instance_valid(coveiro) and coveiro.global_position.distance_to(_jogador.global_position) < ALCANCE_COVEIRO


## Próxima bronca da escada (1 → 2 → 3, e a 3 se repete): balão, aviso e voz. Na
## terceira, depois da fala, o coveiro derruba o jogador da laje.
func _dar_bronca() -> void:
	var nivel := mini(broncas_dadas, BRONCAS.size() - 1)
	broncas_dadas += 1
	var texto: String = BRONCAS[nivel][0]
	var nome := String(coveiro.get("dados").get("nome", "Coveiro"))
	coveiro.mostrar_balao(texto, 5.0)
	_hud.set_notice("%s: %s" % [nome, texto])
	var duracao := _falar(String(BRONCAS[nivel][1]))
	_espera_bronca = duracao + FOLGA_BRONCA
	if coveiro.get("animador") != null and coveiro.animador.has_method("play_gesture"):
		coveiro.animador.play_gesture(int(coveiro.dados.get("gesto_saudacao", 0)))
	if nivel == BRONCAS.size() - 1:
		# Terceira bronca: ele vem até o túmulo enquanto fala e só empurra ao chegar.
		_indo_empurrar = true
		_tempo_indo = 0.0


## Voz da bronca saindo do coveiro, no volume das falas dos personagens. Devolve a
## duração do áudio (ou uma estimativa se o arquivo faltar).
func _falar(caminho: String) -> float:
	var fluxo := load(caminho) as AudioStream if ResourceLoader.exists(caminho) else null
	if fluxo == null:
		return 3.0
	if not is_instance_valid(_voz_bronca):
		_voz_bronca = AudioStreamPlayer3D.new()
		_voz_bronca.name = "VozBronca"
		_voz_bronca.unit_size = 8.0
		_voz_bronca.max_distance = ALCANCE_COVEIRO + 10.0
		_voz_bronca.position = Vector3(0, 1.6, 0)
		coveiro.add_child(_voz_bronca)
	_voz_bronca.volume_db = Audio.volume_vozes_db()
	_voz_bronca.stream = fluxo
	_voz_bronca.play()
	return fluxo.get_length()


## Lado (eixo Z, ±1) para onde o jogador cai: o do corredor mais perto dele. As
## fileiras de túmulos têm 3 unidades entre si, então ele cai no corredor, não em
## outra laje.
func _lado_da_queda(chao: Vector3) -> float:
	var lado := signf(_jogador.global_position.z - chao.z)
	if lado == 0.0:
		lado = signf(_jogador.global_position.z - coveiro.global_position.z)
	return lado if lado != 0.0 else 1.0


## Terceira bronca em andamento: o coveiro anda até o lado oposto da queda, rente à
## laje, e empurra quando está ao alcance do braço. Se o jogador descer antes (ou ele
## não chegar em TEMPO_MAX_IDA), desiste e volta ao posto.
func _aproximar_para_empurrar(delta: float) -> void:
	_tempo_indo += delta
	var indice := _em_cima_de_tumulo()
	if indice < 0 and _jogador is CharacterBody3D and (_jogador as CharacterBody3D).is_on_floor():
		_parar_de_ir()
		return
	if indice < 0:
		return
	var chao: Vector3 = _world.lapides[indice]
	var pegada: Vector3 = _world.lapides_pegada[indice]
	var lado := _lado_da_queda(chao)
	var posto := Vector3(_jogador.global_position.x, chao.y, chao.z - lado * (pegada.z * 0.5 + 0.3))
	# Rota sem atravessar outras lajes: fora do corredor do túmulo, desce pelo vão entre
	# as colunas (meio caminho até a coluna vizinha) até a altura do corredor; dentro
	# dele, vai reto até o lado da laje.
	if absf(coveiro.global_position.z - posto.z) > 0.5:
		var vao := signf(coveiro.global_position.x - chao.x)
		var passagem := Vector3(chao.x + (vao if vao != 0.0 else 1.0) * VAO_COLUNAS, chao.y, posto.z)
		if absf(coveiro.global_position.x - passagem.x) > 0.3:
			passagem.z = coveiro.global_position.z
		coveiro.ir_ate(passagem)
	else:
		coveiro.ir_ate(posto)
	var alcance := Vector2(coveiro.global_position.x - posto.x, coveiro.global_position.z - posto.z).length()
	if alcance < 0.35:
		_parar_de_ir()
		if coveiro.get("animador") != null and coveiro.animador.has_method("play_gesture"):
			coveiro.animador.play_gesture(int(coveiro.dados.get("gesto_saudacao", 0)))
		if _jogador.has_method("empurrar"):
			_jogador.empurrar(Vector3(0, 0, lado * EMPURRAO))
			_hud.set_notice("%s te derrubou da laje." % String(coveiro.dados.get("nome", "O coveiro")))
	elif _tempo_indo > TEMPO_MAX_IDA:
		_parar_de_ir()


func _parar_de_ir() -> void:
	_indo_empurrar = false
	coveiro.liberar()


func _mais_proxima() -> int:
	var melhor := -1
	var menor := ALCANCE
	for indice in range(mini(_world.lapides.size(), _historias.size())):
		var distancia := _distancia(indice)
		if distancia < menor:
			menor = distancia
			melhor = indice
	return melhor


func _distancia(indice: int) -> float:
	var lapide: Vector3 = _world.lapides[indice]
	return Vector2(lapide.x, lapide.z).distance_to(Vector2(_jogador.global_position.x, _jogador.global_position.z))
