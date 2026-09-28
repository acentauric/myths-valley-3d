extends Node
## Fichas das árvores (data/arvores_3d.json): perto de uma árvore aparece a tecla E;
## E abre a ficha no painel da esquerda, E de novo passa a página e, na última, fecha.
## Na mata há milhares de árvores: o vale é dividido em quadras de QUADRA unidades e,
## em cada quadra, só uma árvore de cada espécie tem ficha — nunca várias dicas iguais.

const DicaTecla = preload("res://scripts/prototipo_3d/dica_tecla.gd")
const DADOS := "res://data/arvores_3d.json"
const QUADRA := 16.0
## Distância (no chão) para a dica aparecer e para a ficha fechar sozinha.
const ALCANCE := 3.6
const ALCANCE_FECHAR := 7.0
const ALTURA_DICA := 2.0

var _fichas: Dictionary = {}
## Árvores com ficha: {"especie", "pos"}, agrupadas por quadra para a busca.
var _pontos: Array[Dictionary] = []
var _por_quadra: Dictionary = {}
var _world: Node3D
var _jogador: Node3D
var _hud
var _dica: PanelContainer
var _perto := -1
var _aberta := -1
var _pagina := 0


func configurar(world: Node3D, jogador: Node3D, hud) -> void:
	_world = world
	_jogador = jogador
	_hud = hud
	var dados = JSON.parse_string(FileAccess.get_file_as_string(DADOS))
	if dados is Dictionary:
		_fichas = dados.get("arvores", {})
	var vistos := {}
	for arvore: Dictionary in world.arvores():
		var especie := String(arvore["especie"])
		if not _fichas.has(especie):
			continue
		var pos: Vector3 = arvore["pos"]
		var quadra := Vector2i(floori(pos.x / QUADRA), floori(pos.z / QUADRA))
		var chave := "%d,%d,%s" % [quadra.x, quadra.y, especie]
		if vistos.has(chave):
			continue
		vistos[chave] = true
		if not _por_quadra.has(quadra):
			_por_quadra[quadra] = []
		_por_quadra[quadra].append(_pontos.size())
		_pontos.append({"especie": especie, "pos": pos})
	_dica = DicaTecla.criar(hud.map_layer(), "E", "Sobre a árvore")


func _process(_delta: float) -> void:
	if _world == null:
		return
	var camera := get_viewport().get_camera_3d()
	var em_jogo: bool = camera != null and camera == _jogador.get("camera")
	# Outra ficha (lápide, casa) tomou o painel: esta já não está aberta.
	if _aberta >= 0 and _hud.get("painel_dono") != self:
		_aberta = -1
	_perto = _mais_proxima() if em_jogo else -1
	if _aberta >= 0 and _distancia(_aberta) > ALCANCE_FECHAR:
		_fechar()
	if _perto < 0 or _perto == _aberta:
		_dica.visible = false
		return
	var ficha: Dictionary = _fichas[_pontos[_perto]["especie"]]
	DicaTecla.mostrar_em(_dica, camera, _pontos[_perto]["pos"] + Vector3(0, ALTURA_DICA, 0), String(ficha.get("nome", "Árvore")))


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E):
		return
	if _aberta >= 0:
		var paginas: Array = _fichas[_pontos[_aberta]["especie"]].get("paginas", [])
		if _pagina < paginas.size() - 1:
			_mostrar(_aberta, _pagina + 1)
		else:
			_fechar()
		get_viewport().set_input_as_handled()
	elif _perto >= 0:
		_mostrar(_perto, 0)
		get_viewport().set_input_as_handled()


func ficha_aberta() -> int:
	return _aberta


func _mostrar(indice: int, pagina: int) -> void:
	var ficha: Dictionary = _fichas[_pontos[indice]["especie"]]
	var paginas: Array = ficha.get("paginas", [])
	_aberta = indice
	_pagina = clampi(pagina, 0, maxi(paginas.size() - 1, 0))
	var rodape := "\n\nE: próxima (%d/%d)" % [_pagina + 1, paginas.size()] if _pagina < paginas.size() - 1 else "\n\nE: fechar"
	Audio.efeito("ui_confirmar")
	_hud.show_house_info("%s · %s\n%s%s" % [ficha.get("nome", ""), ficha.get("cientifico", ""), paginas[_pagina] if not paginas.is_empty() else "", rodape], "ÁRVORE")
	_hud.set("painel_dono", self)


func _fechar() -> void:
	_aberta = -1
	_pagina = 0
	if _hud.get("painel_dono") == self:
		_hud.clear_house_info()


func _mais_proxima() -> int:
	var centro := Vector2i(floori(_jogador.global_position.x / QUADRA), floori(_jogador.global_position.z / QUADRA))
	var melhor := -1
	var menor := ALCANCE
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for indice: int in _por_quadra.get(centro + Vector2i(dx, dz), []):
				var distancia := _distancia(indice)
				if distancia < menor:
					menor = distancia
					melhor = indice
	return melhor


func _distancia(indice: int) -> float:
	var pos: Vector3 = _pontos[indice]["pos"]
	return Vector2(pos.x, pos.z).distance_to(Vector2(_jogador.global_position.x, _jogador.global_position.z))
