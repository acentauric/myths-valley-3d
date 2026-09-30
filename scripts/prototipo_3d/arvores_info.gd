extends Node
## Fichas das árvores (data/arvores_3d.json): perto de uma árvore aparece a tecla E;
## E abre a ficha no painel da esquerda, E de novo passa a página e, na última, fecha.
## Na mata há milhares de árvores: o vale é dividido em quadras de QUADRA unidades e,
## em cada quadra, só uma árvore de cada espécie tem ficha — nunca várias dicas iguais.

const DicaTecla = preload("res://scripts/prototipo_3d/dica_tecla.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const Almanaque = preload("res://scripts/prototipo_3d/almanaque.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const DADOS := "res://data/arvores_3d.json"
const QUADRA := 16.0
## Distância (no chão) para a dica aparecer e para a ficha fechar sozinha.
const ALCANCE := 3.6
const ALCANCE_FECHAR := 7.0
const ALTURA_DICA := 2.0
const DISTANCIA_PARA_GOLPEAR := 2.45
const DISTANCIA_DE_APROXIMACAO := 1.45
const GOLPES_PARA_CORTAR := 3
const CUSTO_DO_GOLPE := 50.0

var _fichas: Dictionary = {}
var _acoes: Dictionary = {}
## Árvores com ficha: {"especie", "pos"}, agrupadas por quadra para a busca.
var _pontos: Array[Dictionary] = []
var _coqueiros: Array[Dictionary] = []
var _por_quadra: Dictionary = {}
var _world: Node3D
var _jogador: Node3D
var _hud
var _dica: PanelContainer
var _perto := -1
var _coqueiro_perto := -1
var _coqueiro_pendente := -1
var _coqueiro_em_golpe := -1
var _golpes_restantes_na_acao := 0
var _stamina := 100.0
var _destino_do_coqueiro := Vector3.INF
var _aproximando_do_coqueiro := false
var _animador: Node
var _balao_vida: PanelContainer
var _nome_no_balao: Label
var _vida_no_balao: ProgressBar
var _vida_texto_no_balao: Label
var _aberta := -1
var _pagina := 0


func configurar(world: Node3D, jogador: Node3D, hud) -> void:
	_world = world
	_jogador = jogador
	_hud = hud
	var dados = JSON.parse_string(FileAccess.get_file_as_string(DADOS))
	if dados is Dictionary:
		_fichas = dados.get("arvores", {})
		_acoes = dados.get("acoes", {})
	var vistos := {}
	for arvore: Dictionary in world.arvores():
		var especie := String(arvore["especie"])
		if especie == "coqueiro":
			_coqueiros.append({"pos": arvore["pos"], "raio": float(arvore.get("raio", 0.24)), "golpes": 0, "cortado": false})
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
	for coqueiro: Dictionary in _coqueiros:
		var ficha_proxima := -1
		var menor_distancia := INF
		var tronco: Vector3 = coqueiro["pos"]
		for indice in _pontos.size():
			if String(_pontos[indice]["especie"]) != "coqueiro":
				continue
			var pos_ficha: Vector3 = _pontos[indice]["pos"]
			var distancia := Vector2(tronco.x, tronco.z).distance_to(Vector2(pos_ficha.x, pos_ficha.z))
			if distancia < menor_distancia:
				menor_distancia = distancia
				ficha_proxima = indice
		coqueiro["ficha"] = ficha_proxima
	_dica = DicaTecla.criar(hud.map_layer(), Atalhos.letra("interagir"), "Sobre a árvore")
	_criar_balao_vida(hud.map_layer())
	_stamina = float(_jogador.call("vigor_atual"))
	_jogador.connect("vigor_mudou", Callable(self, "_ao_vigor_mudar"))
	if not Relogio.dia_comecou.is_connected(_ao_comecar_dia):
		Relogio.dia_comecou.connect(_ao_comecar_dia)
	_atualizar_stamina_hud()
	_animador = _jogador.get("animator") as Node
	if _animador != null and _animador.has_signal("golpe_concluido"):
		_animador.connect("golpe_concluido", Callable(self, "_ao_golpe_concluido"))


func _process(_delta: float) -> void:
	if _world == null:
		return
	var camera := get_viewport().get_camera_3d()
	var em_jogo: bool = camera != null and camera == _jogador.get("camera")
	# Outra ficha (lápide, casa) tomou o painel: esta já não está aberta.
	if _aberta >= 0 and _hud.get("painel_dono") != self:
		_aberta = -1
	_perto = _mais_proxima() if em_jogo else -1
	_coqueiro_perto = _mais_proximo_coqueiro() if em_jogo else -1
	_atualizar_golpe_pendente()
	_atualizar_acao_de_golpe()
	_atualizar_balao_vida(camera if em_jogo else null)
	if _coqueiro_em_golpe >= 0:
		_dica.visible = false
		return
	if _aberta >= 0 and _distancia(_aberta) > ALCANCE_FECHAR:
		_fechar()
	var coqueiro_visivel := _coqueiro_perto >= 0 and _distancia_do_coqueiro(_coqueiro_perto) <= ALCANCE
	var interagir_coqueiro := coqueiro_visivel and (_perto < 0 or _distancia_do_coqueiro(_coqueiro_perto) <= _distancia(_perto))
	if (_perto < 0 and not interagir_coqueiro) or (_perto == _aberta and not interagir_coqueiro):
		_dica.visible = false
		return
	if interagir_coqueiro:
		var pos: Vector3 = _coqueiros[_coqueiro_perto]["pos"]
		var nome := str(IdiomaMenu.campo(_fichas["coqueiro"], "nome", "Coqueiro"))
		if bool(_jogador.call("machado_na_mao")):
			nome = _acao_coqueiro()
		DicaTecla.mostrar_em(_dica, camera, pos + Vector3(0, ALTURA_DICA, 0), nome)
		return
	var arvore_info: Dictionary = _pontos[_perto]
	# A ficha aparece apenas até a espécie entrar no almanaque.
	if Almanaque.conhece(String(arvore_info["especie"])):
		_dica.visible = false
		return
	var ficha: Dictionary = _fichas[arvore_info["especie"]]
	DicaTecla.mostrar_em(_dica, camera, arvore_info["pos"] + Vector3(0, ALTURA_DICA, 0), String(ficha.get("nome", "Árvore")))


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == Atalhos.tecla("interagir")):
		return
	if _aberta >= 0:
		var paginas: Array = _fichas[_pontos[_aberta]["especie"]].get("paginas", [])
		if _pagina < paginas.size() - 1:
			_mostrar(_aberta, _pagina + 1)
		else:
			_fechar()
		get_viewport().set_input_as_handled()
	elif _coqueiro_em_golpe >= 0:
		_parar_golpe(true)
		get_viewport().set_input_as_handled()
	elif _coqueiro_perto >= 0 and _distancia_do_coqueiro(_coqueiro_perto) <= ALCANCE and (_perto < 0 or _distancia_do_coqueiro(_coqueiro_perto) <= _distancia(_perto)):
		if _coqueiros[_coqueiro_perto]["cortado"]:
			get_viewport().set_input_as_handled()
			return
		if bool(_jogador.call("machado_na_mao")):
			_iniciar_golpe_no_coqueiro(_coqueiro_perto)
		else:
			var ficha: int = int(_coqueiros[_coqueiro_perto].get("ficha", -1))
			if ficha < 0:
				return
			# Registrar pode retornar false quando a espécie já foi descoberta,
			# mas isso não deve impedir que o jogador abra a descrição novamente.
			Almanaque.registrar("coqueiro")
			_mostrar(ficha, 0)
		get_viewport().set_input_as_handled()
	elif _perto >= 0:
		# O ENCONTRO ACONTECE UMA VEZ SÓ.
		#
		# A ficha abre na PRIMEIRA vez que o jogador chega perto de cada
		# espécie, e a espécie entra no almanaque. Da segunda em diante o E não
		# é mais daqui: ele volta a ser o que deve ser — coletar e interagir —
		# e a tecla passa adiante sem ser consumida.
		#
		# Antes ele abria a ficha toda vez, e por isso fazia duas coisas
		# diferentes conforme onde o jogador estivesse. Ver `Almanaque`.
		if not Almanaque.registrar(String(_pontos[_perto]["especie"])):
			return
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


func fechar_painel() -> void:
	_fechar()


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
				if _pontos[indice].get("cortado", false):
					continue
				var distancia := _distancia(indice)
				if distancia < menor:
					menor = distancia
					melhor = indice
	return melhor


func _distancia(indice: int) -> float:
	var pos: Vector3 = _pontos[indice]["pos"]
	return Vector2(pos.x, pos.z).distance_to(Vector2(_jogador.global_position.x, _jogador.global_position.z))


func _mais_proximo_coqueiro() -> int:
	var melhor := -1
	var menor := ALCANCE
	for indice in _coqueiros.size():
		if _coqueiros[indice]["cortado"]:
			continue
		var distancia := _distancia_do_coqueiro(indice)
		if distancia < menor:
			menor = distancia
			melhor = indice
	return melhor


func _distancia_do_coqueiro(indice: int) -> float:
	var pos: Vector3 = _coqueiros[indice]["pos"]
	return Vector2(pos.x, pos.z).distance_to(Vector2(_jogador.global_position.x, _jogador.global_position.z))


func _acao_coqueiro() -> String:
	if _stamina < CUSTO_DO_GOLPE:
		return str(IdiomaMenu.campo(_acoes.get("coqueiro", {}), "sem_stamina"))
	return str(IdiomaMenu.campo(_acoes.get("coqueiro", {}), "golpear", "Golpear coqueiro"))


func _iniciar_golpe_no_coqueiro(indice: int) -> void:
	if _coqueiro_pendente >= 0 or _coqueiro_em_golpe >= 0 or _coqueiros[indice]["cortado"]:
		return
	if _stamina < CUSTO_DO_GOLPE:
		_hud.set_notice(_acao_coqueiro())
		return
	_coqueiro_pendente = indice
	var arvore: Dictionary = _coqueiros[indice]
	var tronco: Vector3 = arvore["pos"]
	if _distancia_do_coqueiro(indice) <= DISTANCIA_PARA_GOLPEAR:
		_destino_do_coqueiro = tronco
		_aproximando_do_coqueiro = false
		return
	var afastamento := _jogador.global_position - tronco
	afastamento.y = 0.0
	if afastamento.length_squared() < 0.01:
		afastamento = Vector3.FORWARD
	afastamento = afastamento.normalized()
	for angulo in [0.0, PI * 0.5, -PI * 0.5, PI, PI * 0.25, -PI * 0.25, PI * 0.75, -PI * 0.75]:
		var destino := tronco + afastamento.rotated(Vector3.UP, angulo) * (DISTANCIA_DE_APROXIMACAO + float(arvore.get("raio", 0.24)))
		if bool(_jogador.call("caminhar_ate", destino)):
			_destino_do_coqueiro = destino
			_aproximando_do_coqueiro = true
			return
	_coqueiro_pendente = -1
	_destino_do_coqueiro = Vector3.INF
	_aproximando_do_coqueiro = false
	_hud.set_notice(str(IdiomaMenu.campo(_acoes.get("coqueiro", {}), "sem_caminho", "")))


func _atualizar_golpe_pendente() -> void:
	if _coqueiro_pendente < 0:
		return
	var distancia := _distancia_do_coqueiro(_coqueiro_pendente)
	# O golpe interrompe a caminhada; esperar a desaceleração pode cancelar a ação pendente.
	if distancia <= DISTANCIA_PARA_GOLPEAR:
		var indice := _coqueiro_pendente
		var tronco: Vector3 = _coqueiros[_coqueiro_pendente]["pos"]
		var visual := _jogador.get("visual") as Node3D
		visual.rotation.y = atan2(tronco.x - _jogador.global_position.x, tronco.z - _jogador.global_position.z)
		var luta: Node = _jogador.get_parent().get_node_or_null("Luta")
		if luta != null and luta.has_method("animar_golpe"):
			var faltam := GOLPES_PARA_CORTAR - int(_coqueiros[indice]["golpes"])
			var disponiveis := int(floorf((_stamina + 0.001) / CUSTO_DO_GOLPE))
			_golpes_restantes_na_acao = mini(disponiveis, faltam)
			if _golpes_restantes_na_acao <= 0:
				_coqueiro_pendente = -1
				_destino_do_coqueiro = Vector3.INF
				_aproximando_do_coqueiro = false
				return
			_coqueiro_em_golpe = indice
			var espera_animacao := bool(luta.call("animar_golpe", _golpes_restantes_na_acao))
			_jogador.call("travar_acao_de_golpe", 5.0, espera_animacao)
			if not espera_animacao:
				_golpes_restantes_na_acao = 1
				_ao_golpe_concluido()
		_coqueiro_pendente = -1
		_destino_do_coqueiro = Vector3.INF
		_aproximando_do_coqueiro = false
	elif distancia > ALCANCE or (_aproximando_do_coqueiro and not bool(_jogador.call("caminhando_para", _destino_do_coqueiro))):
		_coqueiro_pendente = -1
		_destino_do_coqueiro = Vector3.INF
		_aproximando_do_coqueiro = false


func _ao_golpe_concluido() -> void:
	if _coqueiro_em_golpe < 0:
		return
	var indice := _coqueiro_em_golpe
	var coqueiro: Dictionary = _coqueiros[indice]
	if not bool(_jogador.call("gastar_vigor", CUSTO_DO_GOLPE)):
		_parar_golpe(false)
		return
	_stamina = float(_jogador.call("vigor_atual"))
	coqueiro["golpes"] = int(coqueiro["golpes"]) + 1
	_golpes_restantes_na_acao -= 1
	Audio.efeito("machado")
	if coqueiro["golpes"] >= GOLPES_PARA_CORTAR:
		if bool(_world.call("cortar_coqueiro", coqueiro["pos"])):
			coqueiro["cortado"] = true
			coqueiro["dia_corte"] = Relogio.dia_absoluto()
			if not Inventario.adicionar("madeira_de_coqueiro"):
				_hud.set_notice(str(IdiomaMenu.campo(_acoes.get("coqueiro", {}), "inventario_cheio")))
			Audio.efeito("arvore_cai")
			_definir_ficha_cortada(coqueiro["pos"], true)
		else:
			coqueiro["golpes"] = GOLPES_PARA_CORTAR - 1
	_coqueiros[indice] = coqueiro
	if _golpes_restantes_na_acao <= 0 or _stamina < CUSTO_DO_GOLPE or coqueiro["cortado"]:
		_parar_golpe(false)


func estado_para_salvar() -> Array[Dictionary]:
	var cortados: Array[Dictionary] = []
	for coqueiro: Dictionary in _coqueiros:
		if not bool(coqueiro.get("cortado", false)):
			continue
		var pos: Vector3 = coqueiro["pos"]
		cortados.append({"pos": [pos.x, pos.y, pos.z], "dia_corte": int(coqueiro.get("dia_corte", Relogio.dia_absoluto()))})
	return cortados


func restaurar_do_save(cortados: Array) -> void:
	for registro in cortados:
		if not registro is Dictionary:
			continue
		var coordenadas: Array = registro.get("pos", [])
		if coordenadas.size() != 3:
			continue
		var pos := Vector3(float(coordenadas[0]), float(coordenadas[1]), float(coordenadas[2]))
		var dia_corte := int(registro.get("dia_corte", Relogio.dia_absoluto()))
		# Um save antigo pode ter ficado aberto além da duração da árvore.
		if Relogio.dia_absoluto() > dia_corte:
			continue
		var indice := _indice_coqueiro(pos)
		if indice < 0 or not bool(_world.call("cortar_coqueiro", pos)):
			continue
		var coqueiro: Dictionary = _coqueiros[indice]
		coqueiro["golpes"] = GOLPES_PARA_CORTAR
		coqueiro["cortado"] = true
		coqueiro["dia_corte"] = dia_corte
		_coqueiros[indice] = coqueiro
		_definir_ficha_cortada(pos, true)


func _ao_comecar_dia(_dia: int, _estacao: int, _ano: int) -> void:
	var hoje := Relogio.dia_absoluto()
	for indice in _coqueiros.size():
		var coqueiro: Dictionary = _coqueiros[indice]
		if not bool(coqueiro.get("cortado", false)) or hoje <= int(coqueiro.get("dia_corte", hoje)):
			continue
		if not bool(_world.call("restaurar_coqueiro", coqueiro["pos"])):
			continue
		coqueiro["golpes"] = 0
		coqueiro["cortado"] = false
		coqueiro.erase("dia_corte")
		_coqueiros[indice] = coqueiro
		_definir_ficha_cortada(coqueiro["pos"], false)


func _indice_coqueiro(pos: Vector3) -> int:
	for indice in _coqueiros.size():
		var candidata: Vector3 = _coqueiros[indice]["pos"]
		if Vector2(candidata.x, candidata.z).distance_squared_to(Vector2(pos.x, pos.z)) < 0.01:
			return indice
	return -1


func _definir_ficha_cortada(pos: Vector3, cortado: bool) -> void:
	for ficha: Dictionary in _pontos:
		var ficha_pos: Vector3 = ficha["pos"]
		if ficha["especie"] == "coqueiro" and Vector2(ficha_pos.x, ficha_pos.z).distance_squared_to(Vector2(pos.x, pos.z)) < 0.01:
			ficha["cortado"] = cortado


func _ao_vigor_mudar(valor: float) -> void:
	_stamina = valor
	_atualizar_stamina_hud()


func _atualizar_stamina_hud() -> void:
	_hud.definir_stamina(_stamina, str(IdiomaMenu.campo(_acoes.get("coqueiro", {}), "stamina")))


func _criar_balao_vida(camada: Control) -> void:
	_balao_vida = PanelContainer.new()
	_balao_vida.name = "VidaDoCoqueiro"
	_balao_vida.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_balao_vida.visible = false
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.055, 0.085, 0.075, 0.88)
	estilo.border_color = Color("b49a60")
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(6)
	estilo.content_margin_left = 9
	estilo.content_margin_right = 9
	estilo.content_margin_top = 4
	estilo.content_margin_bottom = 5
	_balao_vida.add_theme_stylebox_override("panel", estilo)
	var conteudo := VBoxContainer.new()
	conteudo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	conteudo.add_theme_constant_override("separation", 3)
	_balao_vida.add_child(conteudo)
	_nome_no_balao = Label.new()
	_nome_no_balao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nome_no_balao.add_theme_font_size_override("font_size", 14)
	_nome_no_balao.add_theme_color_override("font_color", Color("e2c47f"))
	conteudo.add_child(_nome_no_balao)
	_vida_no_balao = ProgressBar.new()
	_vida_no_balao.custom_minimum_size = Vector2(132, 15)
	_vida_no_balao.max_value = GOLPES_PARA_CORTAR
	_vida_no_balao.value = GOLPES_PARA_CORTAR
	_vida_no_balao.show_percentage = false
	_vida_no_balao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color("343b2b")
	fundo.set_corner_radius_all(4)
	_vida_no_balao.add_theme_stylebox_override("background", fundo)
	var preenchimento := StyleBoxFlat.new()
	preenchimento.bg_color = Color("e0bf4e")
	preenchimento.set_corner_radius_all(4)
	_vida_no_balao.add_theme_stylebox_override("fill", preenchimento)
	conteudo.add_child(_vida_no_balao)
	_vida_texto_no_balao = Label.new()
	_vida_texto_no_balao.add_theme_font_size_override("font_size", 11)
	_vida_texto_no_balao.add_theme_color_override("font_color", Color.WHITE)
	_vida_texto_no_balao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vida_no_balao.add_child(_vida_texto_no_balao)
	_vida_texto_no_balao.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camada.add_child(_balao_vida)


func _atualizar_balao_vida(camera: Camera3D) -> void:
	if _coqueiro_em_golpe < 0 or camera == null or bool(_hud.get("mapa_aberto")):
		_balao_vida.visible = false
		return
	var coqueiro: Dictionary = _coqueiros[_coqueiro_em_golpe]
	var pos: Vector3 = coqueiro["pos"]
	var topo := pos + Vector3(0, 2.45, 0)
	if camera.is_position_behind(topo):
		_balao_vida.visible = false
		return
	_nome_no_balao.text = str(IdiomaMenu.campo(_fichas["coqueiro"], "nome"))
	var restante := maxi(GOLPES_PARA_CORTAR - int(coqueiro["golpes"]), 0)
	_vida_no_balao.value = restante
	_vida_texto_no_balao.text = "%d/%d" % [restante, GOLPES_PARA_CORTAR]
	_balao_vida.visible = true
	_balao_vida.reset_size()
	_balao_vida.position = camera.unproject_position(topo) - Vector2(_balao_vida.size.x * 0.5, _balao_vida.size.y)


func _atualizar_acao_de_golpe() -> void:
	if _coqueiro_em_golpe < 0:
		return
	var animando := _animador != null and _animador.has_method("chop_ativo") and bool(_animador.call("chop_ativo"))
	if not animando or not bool(_jogador.call("machado_na_mao")) or _distancia_do_coqueiro(_coqueiro_em_golpe) > ALCANCE or bool(_hud.get("mapa_aberto")):
		_parar_golpe(true)


func _parar_golpe(interromper_animacao: bool) -> void:
	if interromper_animacao and _animador != null and _animador.has_method("stop_chop"):
		_animador.call("stop_chop")
	if interromper_animacao and _jogador.has_method("liberar_acao_de_golpe"):
		_jogador.call("liberar_acao_de_golpe")
	_coqueiro_em_golpe = -1
	_golpes_restantes_na_acao = 0
	_balao_vida.visible = false
