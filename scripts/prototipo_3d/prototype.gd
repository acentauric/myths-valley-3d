extends Node3D
## Cena do vale: cenário, jogador, HUD, som do lugar, moradores e o Pedro guia.
## Estilo visual (Tripo/Procedural), hora do dia e velocidade do tempo vêm dos
## autoloads Estilo e Dia, ajustados no menu (AJUSTAR → Cenário e tempo).

const NPCS := "res://data/npcs_3d.json"
const PERIODOS := {"madrugada": "Madrugada", "manha": "Manhã", "tarde": "Tarde", "entardecer": "Entardecer", "noite": "Noite"}

@onready var player = $Jogador
@onready var hud = $HUD
@onready var world = $Cenario
var ambiente: AmbienteVale
var pedro: GuiaPedro
var moradores: Array[MoradorNPC] = []
var _visited: Dictionary = {}
var _step_time := 0.0


func _enter_tree() -> void:
	_bind("mv_forward", [KEY_W, KEY_UP])
	_bind("mv_back", [KEY_S, KEY_DOWN])
	_bind("mv_left", [KEY_A, KEY_LEFT])
	_bind("mv_right", [KEY_D, KEY_RIGHT])
	_bind("mv_run", [KEY_SHIFT])
	_bind("mv_release", [KEY_ESCAPE])
	_bind("mv_cursor", [KEY_TAB])
	_bind("mv_reset", [KEY_R])
	_bind("mv_inspect", [KEY_F])
	_bind("mv_time", [KEY_T])
	for index in range(8):
		_bind("mv_animation_%d" % (index + 1), [KEY_1 + index])


func _ready() -> void:
	Audio.parar_narracao()
	Audio.tocar_musica()
	var spawn: Vector3 = _ponto_de_chegada()
	player.spawn_position = spawn
	player.global_position = spawn
	player.configure_click_world(world)
	player.capture_changed.connect(hud.set_captured)
	player.camera_lock_changed.connect(hud.set_camera_locked)
	player.animation_requested.connect(_on_animation_requested)
	player.navigation_status.connect(hud.set_notice)
	hud.camera_lock_requested.connect(player.set_camera_locked)
	world.house_interacted.connect(func(properties: Dictionary): hud.show_house_info(world.format_house_properties(properties)))
	world.house_interaction_cleared.connect(hud.clear_house_info)
	hud.house_info_close_requested.connect(world.clear_house_interaction)
	hud.menu_requested.connect(_return_to_menu)
	player.set_camera_locked(false)
	hud.set_region_title(world.get_region_title())
	if Estilo.procedural():
		hud.set_model_status("Estilo procedural: personagem, casas e árvores por código")
		hud.set_telemetry("Procedural · 1,78 m")
	else:
		hud.set_model_status("Estilo Tripo: modelos do Tripo Studio (personagem GLB provisório)")
		hud.set_telemetry("Tripo · 1,78 m")
	hud.set_objective("Fale com Pedro: ele veio te esperar no píer.")
	hud.set_notice("Bom Jesus dos Pobres, 1887 · 1 unidade = %s m" % _formatar(world.get_meters_per_unit()))
	_montar_som()
	_montar_moradores(spawn)
	Dia.periodo_mudou.connect(_on_periodo_mudou)
	_atualizar_relogio()
	print("PROTOTYPE_READY: estilo=%s hora=%s moradores=%d user_dir=%s" % [Estilo.modo, Dia.texto_hora(), moradores.size(), OS.get_user_data_dir()])


## O jogador chega de barco: começa no píer, de frente para a praça.
func _ponto_de_chegada() -> Vector3:
	var spawn: Vector3 = world.get_spawn_position()
	if world.ancoras.has("Pier") and world.ancoras.has("Praça"):
		var pier: Vector3 = world.ancoras["Pier"]
		var praca: Vector3 = world.ancoras["Praça"]
		var direcao: Vector3 = (praca - pier).normalized()
		spawn = pier + direcao * 7.5 + Vector3(0, 0.07, 0)
	return spawn


func _montar_som() -> void:
	ambiente = AmbienteVale.new()
	ambiente.name = "Ambiente"
	add_child(ambiente)
	if world.ancoras.has("Pier"):
		ambiente.fonte(AmbienteVale.MAR, world.ancoras["Pier"], 60.0, 2.0)
	for chave in ["Rio", "Rio 2"]:
		if world.ancoras.has(chave):
			ambiente.fonte(AmbienteVale.RIACHO, world.ancoras[chave], 26.0, -2.0)
	if world.ancoras.has("Fogueira"):
		ambiente.fonte(AmbienteVale.FOGUEIRA, world.ancoras["Fogueira"] + Vector3(0, 0.5, 0), 16.0, 0.0, true)


func _montar_moradores(spawn: Vector3) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(NPCS))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Moradores 3D: arquivo inválido " + NPCS)
		return
	for entry in data.get("moradores", []):
		var morador := MoradorNPC.new()
		morador.configurar(entry, world.ancoras, player)
		add_child(morador)
		morador.saudou.connect(_on_saudacao)
		moradores.append(morador)
	var guia: Dictionary = data.get("guia", {})
	if not guia.is_empty():
		pedro = GuiaPedro.new()
		pedro.configurar(guia, world.ancoras, player)
		add_child(pedro)
		var lado: Vector3 = Vector3(-1.6, 0, 1.4)
		pedro.global_position = spawn + lado
		pedro.saudou.connect(_on_saudacao)
		pedro.missao_mudou.connect(_on_missao_mudou)
		pedro.narrou.connect(func(texto: String) -> void: hud.set_notice("Pedro: " + texto))


func _process(_delta: float) -> void:
	_step_time -= _delta
	if player.is_on_floor() and Vector2(player.velocity.x, player.velocity.z).length() > 0.3:
		if _step_time <= 0:
			var running := Input.is_action_pressed("mv_run")
			var terrain: String = world.surface_at(player.global_position)
			if terrain == "agua":
				terrain = "areia"
			Audio.passo(terrain, running)
			_step_time = 0.32 if running else 0.48
	else:
		_step_time = 0
	for landmark: Dictionary in world.landmarks:
		var landmark_id: String = landmark["id"]
		var landmark_name: String = landmark["name"]
		var destination: Vector3 = landmark["position"]
		if not _visited.has(landmark_id) and player.global_position.distance_to(destination) < 7.0:
			_visited[landmark_id] = true
			hud.set_notice("Você chegou: %s  ·  %d/%d pontos explorados" % [landmark_name, _visited.size(), world.landmarks.size()])
	_atualizar_relogio()


func _atualizar_relogio() -> void:
	var velocidade: String = Dia.ROTULOS_VELOCIDADE[Dia.velocidade]
	hud.set_clock("%s · %s · tempo %s · %s" % [Dia.texto_hora(), PERIODOS.get(Dia.periodo(), ""), velocidade.to_lower(), Estilo.rotulo()])


func _on_periodo_mudou(periodo: String) -> void:
	if not is_inside_tree():
		return
	match periodo:
		"entardecer":
			hud.set_notice("O sol vai baixando. Os lampiões da praça acendem logo mais.")
		"noite":
			hud.set_notice("Noite no arraial: só lampião, candeeiro e a fogueira do terreiro.")
		"manha":
			hud.set_notice("Amanheceu. A mata acorda com as aves do Recôncavo.")


func _on_saudacao(morador: MoradorNPC, texto: String) -> void:
	hud.set_notice("%s: %s" % [String(morador.dados.get("nome", "Morador")), texto])


func _on_missao_mudou(texto: String, _alvo: Vector3, indice: int, total: int) -> void:
	if indice >= total:
		hud.set_objective(texto)
	else:
		hud.set_objective("%s  (%d/%d)" % [texto, indice, total])


func _bind(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key: int in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_M:
			_return_to_menu()
		elif event.physical_keycode == KEY_T:
			Dia.avancar(1.0)
			hud.set_notice("Relógio adiantado: %s (%s)" % [Dia.texto_hora(), PERIODOS.get(Dia.periodo(), "")])


func _return_to_menu() -> void:
	player.set_captured(false)
	get_tree().change_scene_to_file("res://scenes/prototipo_3d/abertura.tscn")


func _on_animation_requested(label: String) -> void:
	hud.set_notice("Gesto: %s · mova o personagem para interromper" % label)


func _formatar(meters_per_unit: float) -> String:
	if is_equal_approx(meters_per_unit, roundf(meters_per_unit)):
		return str(int(roundf(meters_per_unit)))
	return String.num(meters_per_unit, 2)
