extends Node3D
## O espólio fica no mundo e no save até o E recolhê-lo (#67).
## Reaproveita as gravuras dos itens, sem criar outro modelo ou corpo sólido.
const FocoDoE = preload("res://scripts/prototipo_3d/foco_do_e.gd")
const DicaTecla = preload("res://scripts/prototipo_3d/dica_tecla.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const ALCANCE := 1.8
var caidos: Array[Dictionary] = []
var _player: Node3D
var _world: Node3D
var _hud
var _dica: PanelContainer
var _textos: Dictionary

func configurar(world: Node3D, player: Node3D, hud, camada: Control) -> void:
	_world = world
	_player = player
	_hud = hud
	_textos = JSON.parse_string(FileAccess.get_file_as_string("res://data/coleta_no_chao.json"))
	_dica = DicaTecla.criar(camada, Atalhos.letra("interagir"), _texto("pegar"))
	add_to_group(FocoDoE.GRUPO)

func _texto(chave: String) -> String:
	return str(IdiomaMenu.campo(_textos.get(chave, {}), "texto", chave))

func deixar(item: String, quantidade: int, ponto: Vector3) -> bool:
	if not Catalogo.existe(item) or quantidade <= 0 or not ponto.is_finite():
		return false
	var gravura := Sprite3D.new()
	gravura.texture = Catalogo.icone(item)
	gravura.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	gravura.pixel_size = 0.013
	gravura.no_depth_test = false
	gravura.name = "ItemCaido"
	add_child(gravura)
	gravura.global_position = _world.ground_position(ponto, 0.32)
	caidos.append({"item": item, "quantidade": quantidade, "ponto": gravura.global_position, "gravura": gravura})
	return true

func _perto() -> int:
	if _player == null or not _player.is_physics_processing():
		return -1
	var melhor := -1
	var distancia := ALCANCE
	for i in caidos.size():
		var ponto: Vector3 = caidos[i].ponto
		var d := _player.global_position.distance_to(ponto)
		if d < distancia:
			distancia = d
			melhor = i
	return melhor

func alvo_do_e() -> Dictionary:
	var i := _perto()
	return {"ponto": caidos[i].ponto, "vies": 1.0} if i >= 0 else {}

func recolher() -> bool:
	var i := _perto()
	if i < 0:
		return false
	var item: Dictionary = caidos[i]
	if not Inventario.adicionar(item.item, item.quantidade):
		_hud.set_notice(_texto("cheia"))
		return false
	caidos.remove_at(i)
	item.gravura.queue_free()
	Audio.efeito("pegar")
	_hud.set_notice(_texto("recebeu") % [item.quantidade, Catalogo.nome(item.item)])
	return true

func _process(_delta: float) -> void:
	if _dica == null:
		return
	var i := _perto()
	_dica.visible = i >= 0 and FocoDoE.e_dele(self)
	if _dica.visible:
		DicaTecla.mostrar_em(_dica, get_viewport().get_camera_3d(), caidos[i].ponto + Vector3.UP * 0.5,
			_texto("pegar") + " · " + Catalogo.nome(caidos[i].item))

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == Atalhos.tecla("interagir"):
		if _perto() >= 0 and FocoDoE.e_dele(self):
			recolher()
			get_viewport().set_input_as_handled()

func estado_para_salvar() -> Array:
	var resultado: Array = []
	for item in caidos:
		var p: Vector3 = item.ponto
		resultado.append({"item": item.item, "quantidade": item.quantidade, "ponto": [p.x, p.y, p.z]})
	return resultado

func restaurar(lista: Array) -> void:
	for item in caidos:
		item.gravura.queue_free()
	caidos.clear()
	for entrada in lista:
		if not entrada is Dictionary:
			continue
		var p = entrada.get("ponto", [])
		if p is Array and p.size() == 3 and p[0] is float and p[1] is float and p[2] is float:
			deixar(str(entrada.get("item", "")), int(entrada.get("quantidade", 0)), Vector3(p[0], p[1], p[2]))
