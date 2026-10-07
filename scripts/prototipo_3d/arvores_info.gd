extends Node
## Fichas das árvores (data/arvores_3d.json): perto de uma árvore aparece a tecla E;
## E abre a ficha no painel da esquerda, E de novo passa a página e, na última, fecha.
## Na mata há milhares de árvores: o vale é dividido em quadras de QUADRA unidades e,
## em cada quadra, só uma árvore de cada espécie tem ficha — nunca várias dicas iguais.
##
## E O CORTE. Com o machado na mão, toda árvore do vale se corta — a plantada,
## a da mata, a da orla e a da beira do rio —, com a regra que nasceu no
## coqueiro: o jogador vai até o tronco, golpeia no tempo do braço, e cada
## golpe gasta vigor. O pé cortado vira toco e volta a crescer pelo
## CALENDÁRIO: toco, muda, árvore nova, quase feita, e só um ano depois do corte
## (`dias_do_ano`, os 112 do Relogio) está adulta e se corta de novo.
##
## A MADEIRA DIZ O QUE PEDE (`madeiras` no JSON): a madeira de lei pede o
## machado de nível 2, que só o talento dá — Braços de machado, no ofício, ou
## Ferro de Ogum, no candomblé —, e a de lei dura pede também o machado de aço
## na mão. Cada golpe cobra fôlego pela conta do Energia (bater × dureza) e
## ensina pela do Talentos (bater, ou bater_duro na madeira dura): é o mesmo
## trato do tronco caído e do jogo 2D. A gameleira e a bananeira não se cortam,
## cada uma com a sua razão escrita.

const DicaTecla = preload("res://scripts/prototipo_3d/dica_tecla.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const Almanaque = preload("res://scripts/prototipo_3d/almanaque.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const FocoDoE = preload("res://scripts/prototipo_3d/foco_do_e.gd")
const SuavizadorDeTela = preload("res://scripts/prototipo_3d/suavizador_de_tela.gd")

## O jogador conheceu uma espécie pela primeira vez, e ela entrou no almanaque.
## O vale mostra o aviso da primeira árvore (`aviso_da_primeira_vez.gd`).
signal conheceu(especie: String)
## A FICHA DA ÁRVORE DESCONTA NA CONTA DO FOCO (`foco_do_e.gd`): árvore está em
## toda parte, e só ganha de coisa posta de propósito — o cordel, o morador — se
## estiver bem mais perto. A ficha aberta e o golpe em curso levam o E sempre
## (VIES_DO_QUE_ESTA_ABERTO): o E deles é passar a página e parar.
const VIES_DA_FICHA := -1.0
const VIES_DO_QUE_ESTA_ABERTO := 100.0
const DADOS := "res://data/arvores_3d.json"
const QUADRA := 16.0
## Distância (no chão) para a dica aparecer e para a ficha fechar sozinha.
const ALCANCE := 3.6
const ALCANCE_FECHAR := 7.0
const ALTURA_DICA := 2.0
const DISTANCIA_PARA_GOLPEAR := 2.45
const DISTANCIA_DE_APROXIMACAO := 1.45
## O vigor de um golpe sai de Energia ("golpe"), ajustável em Ajustes → Esforço.
## OS ESTÁGIOS DE QUEM VOLTA A CRESCER, em fração do ano desde o corte: a
## partir de `de`, a árvore aparece com `escala` do tamanho dela. Antes do
## primeiro é toco; do ano inteiro em diante, adulta.
const ESTAGIOS := [
	{"nome": "toco", "de": 0.0, "escala": 0.0},
	{"nome": "muda", "de": 0.25, "escala": 0.2},
	{"nome": "nova", "de": 0.5, "escala": 0.45},
	{"nome": "crescida", "de": 0.75, "escala": 0.75},
]
## Madeira de espécie que o JSON não classifica.
const MADEIRA_PADRAO := "branca"
## A PIAÇAVA SE TIRA, NÃO SE DERRUBA: a fibra sai da bainha da folha, no fio da
## foice ou do facão, e a palmeira fica de pé e dá de novo na estação seguinte.
## É o que o mestre Quirino, do saveiro, mais leva (`saveiro_vale.gd`).
const PALMEIRA_DA_FIBRA := "piacava"
const FIBRA := "piacava"
const FEIXES_POR_PALMEIRA := 2
const GESTO_GOLPEAR := 6

var _fichas: Dictionary = {}
var _acoes: Dictionary = {}
var _madeiras: Dictionary = {}
var _especies: Dictionary = {}
var _nao_se_corta: Dictionary = {}
## Árvores com ficha: {"especie", "pos"}, agrupadas por quadra para a busca.
var _pontos: Array[Dictionary] = []
## TODA ÁRVORE DO VALE: {"especie", "pos", "raio", "golpes", "cortado",
## "dia_do_corte", "escala"}. Por quadra em `_cortaveis_por_quadra`.
var _cortaveis: Array[Dictionary] = []
var _cortaveis_por_quadra: Dictionary = {}
var _por_quadra: Dictionary = {}
var _world: Node3D
var _jogador: Node3D
var _hud
var _dica: PanelContainer
var _perto := -1
var _cortavel_perto := -1
## A piaçabeira ao alcance da foice ou do facão, e o dia (absoluto) em que cada
## uma deu fibra pela última vez, por índice em `_cortaveis`.
var _fibra_perto := -1
var _fibra_tirada: Dictionary = {}
var _cortavel_pendente := -1
var _em_golpe := -1
var _golpes_restantes_na_acao := 0
var _stamina := 100.0
var _destino_do_golpe := Vector3.INF
var _aproximando := false
var _animador: Node
var _balao_vida: PanelContainer
## O peso da vida da árvore na tela (`suavizador_de_tela.gd`): desliza até o ponto.
var _mola_da_vida := SuavizadorDeTela.new()
var _nome_no_balao: Label
var _vida_no_balao: ProgressBar
var _vida_texto_no_balao: Label
var _aberta := -1
var _pagina := 0


func configurar(world: Node3D, jogador: Node3D, hud, hud_layer: Control) -> void:
	_world = world
	_jogador = jogador
	_hud = hud
	var dados = JSON.parse_string(FileAccess.get_file_as_string(DADOS))
	if dados is Dictionary:
		_fichas = dados.get("arvores", {})
		_acoes = dados.get("acoes", {})
		_madeiras = dados.get("madeiras", {})
		_especies = dados.get("especies", {})
		_nao_se_corta = dados.get("nao_se_corta", {})
	var vistos := {}
	for arvore: Dictionary in world.arvores():
		var especie := String(arvore["especie"])
		var pos: Vector3 = arvore["pos"]
		var quadra := Vector2i(floori(pos.x / QUADRA), floori(pos.z / QUADRA))
		if especie != "":
			if not _cortaveis_por_quadra.has(quadra):
				_cortaveis_por_quadra[quadra] = []
			_cortaveis_por_quadra[quadra].append(_cortaveis.size())
			_cortaveis.append({"especie": especie, "pos": pos, "raio": float(arvore.get("raio", 0.24)), "golpes": 0, "cortado": false})
		if not _fichas.has(especie):
			continue
		var chave := "%d,%d,%s" % [quadra.x, quadra.y, especie]
		if vistos.has(chave):
			continue
		vistos[chave] = true
		if not _por_quadra.has(quadra):
			_por_quadra[quadra] = []
		_por_quadra[quadra].append(_pontos.size())
		_pontos.append({"especie": especie, "pos": pos})
	_dica = DicaTecla.criar(hud.map_layer(), Atalhos.letra("interagir"), "Sobre a árvore")
	_dica.set_meta("interacao_arvore", true)
	add_to_group(FocoDoE.GRUPO)
	add_to_group("arvores_do_vale")
	set_meta("recurso_arvore", true)
	_criar_balao_vida(hud.map_layer())
	_stamina = float(_jogador.call("vigor_atual"))
	_jogador.connect("vigor_mudou", Callable(self, "_ao_vigor_mudar"))
	if not Relogio.dia_comecou.is_connected(_ao_dia_comecar):
		Relogio.dia_comecou.connect(_ao_dia_comecar)
	_animador = _jogador.get("animator") as Node
	if _animador != null and _animador.has_signal("golpe_concluido"):
		_animador.connect("golpe_concluido", Callable(self, "_ao_golpe_concluido"))
	if _animador != null and _animador.has_signal("golpe_impacto"):
		_animador.connect("golpe_impacto", Callable(self, "_ao_impacto_do_golpe"))


func _process(_delta: float) -> void:
	if _world == null:
		return
	var camera := get_viewport().get_camera_3d()
	var em_jogo: bool = camera != null and camera == _jogador.get("camera")
	# Outra ficha (lápide, casa) tomou o painel: esta já não está aberta.
	if _aberta >= 0 and _hud.get("painel_dono") != self:
		_aberta = -1
	_perto = _mais_proxima() if em_jogo else -1
	_cortavel_perto = _mais_proxima_cortavel() if em_jogo and _machado_na_mao() and not _outro_dono_do_e() else -1
	_fibra_perto = _mais_proxima_piacabeira() if em_jogo and _fio_na_mao() != "" and not _outro_dono_do_e() else -1
	_atualizar_golpe_pendente()
	_atualizar_acao_de_golpe()
	_atualizar_balao_vida(camera if em_jogo else null)
	if _em_golpe >= 0:
		_dica.visible = false
		return
	if _aberta >= 0 and _distancia(_aberta) > ALCANCE_FECHAR:
		_fechar()
	# O E É DE OUTRO (`foco_do_e.gd`): a dica daqui se apaga.
	if not FocoDoE.e_dele(self):
		_dica.visible = false
		return
	if _corte_vale_a_tecla():
		var arvore: Dictionary = _cortaveis[_cortavel_perto]
		DicaTecla.mostrar_em(_dica, camera, (arvore["pos"] as Vector3) + Vector3(0, ALTURA_DICA, 0), _texto_do_corte(_cortavel_perto))
		return
	if _fibra_perto >= 0:
		var palmeira: Dictionary = _cortaveis[_fibra_perto]
		DicaTecla.mostrar_em(_dica, camera, (palmeira["pos"] as Vector3) + Vector3(0, ALTURA_DICA, 0), _texto_da_fibra(_fibra_perto))
		return
	if _perto < 0 or _perto == _aberta:
		_dica.visible = false
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
	# COM O CORPO PARADO, O E NÃO VALE PARA O MUNDO, como nos achados, na pesca
	# e na luta: no escuro da queda, o golpe no coqueiro da porta saía sem
	# ninguém de pé para dar.
	if not _jogador.is_physics_processing() or not FocoDoE.e_dele(self):
		return
	if _aberta >= 0:
		var paginas: Array = _fichas[_pontos[_aberta]["especie"]].get("paginas", [])
		if _pagina < paginas.size() - 1:
			_mostrar(_aberta, _pagina + 1)
		else:
			_fechar()
		get_viewport().set_input_as_handled()
	elif _em_golpe >= 0:
		_parar_golpe(true)
		get_viewport().set_input_as_handled()
	elif _fibra_perto >= 0 and _cortavel_perto < 0:
		_tirar_a_fibra(_fibra_perto)
		get_viewport().set_input_as_handled()
	elif _corte_vale_a_tecla() and not bool(_cortaveis[_cortavel_perto]["cortado"]):
		# Árvore cortada só mostra quando volta; o E dela segue adiante.
		var recusa := _recusa(_cortavel_perto)
		if recusa != "":
			_hud.set_notice(recusa)
		else:
			_iniciar_golpe(_cortavel_perto)
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
		conheceu.emit(String(_pontos[_perto]["especie"]))


## O QUE O E FARIA AQUI, para o foco (`foco_do_e.gd`), na ordem do
## `_unhandled_key_input`: a ficha aberta e o golpe em curso (que levam o E
## sempre), a fibra, o corte, e a ficha da espécie que o almanaque ainda não tem.
func alvo_do_e() -> Dictionary:
	if _jogador == null or not _jogador.is_physics_processing():
		return {}
	if _aberta >= 0:
		return {"ponto": _pontos[_aberta]["pos"], "vies": VIES_DO_QUE_ESTA_ABERTO}
	if _em_golpe >= 0 and _em_golpe < _cortaveis.size():
		return {"ponto": _cortaveis[_em_golpe]["pos"], "vies": VIES_DO_QUE_ESTA_ABERTO, "em_trabalho": true}
	if _fibra_perto >= 0 and _cortavel_perto < 0:
		return {"ponto": _cortaveis[_fibra_perto]["pos"]}
	if _corte_vale_a_tecla() and not bool(_cortaveis[_cortavel_perto]["cortado"]):
		return {"ponto": _cortaveis[_cortavel_perto]["pos"]}
	if _perto >= 0 and not Almanaque.conhece(String(_pontos[_perto]["especie"])):
		return {"ponto": _pontos[_perto]["pos"], "vies": VIES_DA_FICHA}
	return {}


## COM O MACHADO NA MÃO, A ÁRVORE AO ALCANCE É DO CORTE, e não da ficha — a
## não ser que a ficha esteja mais perto, que é a regra que o coqueiro já
## tinha. Sem machado na mão, árvore é ficha e nada mais.
func _corte_vale_a_tecla() -> bool:
	if _cortavel_perto < 0:
		return false
	return _perto < 0 or _distancia_da_cortavel(_cortavel_perto) <= _distancia(_perto)


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


# --- o corte -------------------------------------------------------------------

## A árvore ao alcance do machado — de pé ou crescendo, para a dica dizer
## quando ela volta —, ou -1. Pelas quadras: a mata tem milhares.
func _mais_proxima_cortavel() -> int:
	var centro := Vector2i(floori(_jogador.global_position.x / QUADRA), floori(_jogador.global_position.z / QUADRA))
	var melhor := -1
	var menor := ALCANCE
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for indice: int in _cortaveis_por_quadra.get(centro + Vector2i(dx, dz), []):
				var distancia := _distancia_da_cortavel(indice)
				if distancia < menor:
					menor = distancia
					melhor = indice
	return melhor


func _distancia_da_cortavel(indice: int) -> float:
	var pos: Vector3 = _cortaveis[indice]["pos"]
	return Vector2(pos.x, pos.z).distance_to(Vector2(_jogador.global_position.x, _jogador.global_position.z))


func _machado_na_mao() -> bool:
	return bool(_jogador.call("machado_na_mao"))


# --- a piaçava ---------------------------------------------------------------------

## A foice ou o facão na mão (o id do que está), ou "".
func _fio_na_mao() -> String:
	for familia in ["foice", "facao"]:
		var na_mao := Equipamento.da_familia_em_uso(familia)
		if na_mao != "":
			return na_mao
	return ""


## A piaçabeira de pé mais perto, ao alcance, ou -1.
func _mais_proxima_piacabeira() -> int:
	var centro := Vector2i(floori(_jogador.global_position.x / QUADRA), floori(_jogador.global_position.z / QUADRA))
	var melhor := -1
	var menor := ALCANCE
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for indice: int in _cortaveis_por_quadra.get(centro + Vector2i(dx, dz), []):
				var palmeira: Dictionary = _cortaveis[indice]
				if str(palmeira["especie"]) != PALMEIRA_DA_FIBRA or bool(palmeira["cortado"]):
					continue
				var distancia := _distancia_da_cortavel(indice)
				if distancia < menor:
					menor = distancia
					melhor = indice
	return melhor


## A palmeira tem fibra para dar? Uma vez por estação.
func fibra_pronta(indice: int) -> bool:
	if not _fibra_tirada.has(indice):
		return true
	return Relogio.dia_absoluto() - int(_fibra_tirada[indice]) >= Relogio.DIAS_POR_ESTACAO


## O que a dica diz da piaçabeira: tirar, ou — já tirada — que a fibra cresce de
## novo, sem dizer quando (como a árvore cortada).
func _texto_da_fibra(indice: int) -> String:
	var acoes: Dictionary = _acoes.get("arvore", {})
	if not fibra_pronta(indice):
		return str(IdiomaMenu.campo(acoes, "fibra_crescendo")) % _nome_da_especie(PALMEIRA_DA_FIBRA)
	if not Energia.aguenta("colher"):
		return str(IdiomaMenu.campo(acoes, "sem_folego"))
	return str(IdiomaMenu.campo(acoes, "tirar_fibra"))


## TIRA A FIBRA: o golpe da foice (o gesto de golpear), o fôlego e o que o
## trabalho ensina de colheita, e os feixes na mochila. A palmeira fica de pé.
func _tirar_a_fibra(indice: int) -> void:
	if not fibra_pronta(indice):
		_hud.set_notice(_texto_da_fibra(indice))
		return
	# Mochila cheia: nem fôlego nem golpe, e a palmeira guarda a fibra.
	if not _cabe(FIBRA):
		_hud.set_notice(str(IdiomaMenu.campo(_acoes.get("arvore", {}), "inventario_cheio")))
		return
	if not Energia.gastar("colher"):
		_hud.set_notice(str(IdiomaMenu.campo(_acoes.get("arvore", {}), "sem_folego")))
		return
	Talentos.ganhar("colher")
	var animador = _jogador.get("animator")
	if animador != null and animador.has_method("play_gesture"):
		animador.play_gesture(GESTO_GOLPEAR)
	Inventario.adicionar(FIBRA, FEIXES_POR_PALMEIRA)
	_fibra_tirada[indice] = Relogio.dia_absoluto()


## Cabe mais disso na mochila: a pilha que já tem, ou um espaço vazio.
func _cabe(id: String) -> bool:
	for espaco: Dictionary in Inventario.espacos:
		if espaco.is_empty() or (str(espaco.get("id", "")) == id and int(espaco["qtd"]) < Inventario.PILHA_MAXIMA):
			return true
	return false


## As piaçabeiras já tiradas, com o dia, para o save: [{pos, dia}].
func fibra_para_salvar() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for indice: int in _fibra_tirada:
		var pos: Vector3 = _cortaveis[indice]["pos"]
		lista.append({"pos": [pos.x, pos.y, pos.z], "dia": int(_fibra_tirada[indice])})
	return lista


func restaurar_fibra(lista: Array) -> void:
	_fibra_tirada.clear()
	for registro in lista:
		if not registro is Dictionary:
			continue
		var onde: Array = registro.get("pos", [])
		if onde.size() != 3:
			continue
		var indice := _indice_da_cortavel(Vector3(float(onde[0]), float(onde[1]), float(onde[2])))
		if indice >= 0:
			_fibra_tirada[indice] = int(registro.get("dia", Relogio.dia_absoluto()))


## O E É DE OUTRO AQUI: um alvo de trabalho, um achado, um marco, o campo da
## lavoura, ou o jogador dentro de um cômodo. Árvore está em toda parte, e por
## isso não disputa a tecla com o que foi posto de propósito — o tronco caído
## do roçado tem uma mangueira do lado, e quem foi buscar a lenha da missão
## não pode derrubar a mangueira por engano.
func _outro_dono_do_e() -> bool:
	var vale := get_parent()
	var recursos := vale.get_node_or_null("Recursos3D") if vale != null else null
	if recursos != null and str(recursos.get("_perto")) != "":
		return true
	var achados = vale.get("achados") if vale != null else null
	if achados != null and achados.has_method("mais_perto") and achados.mais_perto() != null:
		return true
	var marcos := get_tree().get_first_node_in_group("marcos_da_fe")
	if marcos != null and str(marcos.get("_perto")) != "":
		return true
	var lavoura := get_tree().get_first_node_in_group("lavoura")
	if lavoura != null and lavoura.no_campo(_jogador.global_position):
		return true
	var interiores := get_tree().get_first_node_in_group("interiores")
	return interiores != null and interiores.contem(_jogador.global_position) != ""


## A madeira desta espécie: o molde (`madeiras`) com o que a espécie muda nele
## (o coqueiro rende madeira de coqueiro, e não lenha).
func madeira_de(especie: String) -> Dictionary:
	var da_especie: Dictionary = _especies.get(especie, {})
	var classe := str(da_especie.get("madeira", MADEIRA_PADRAO))
	var molde: Dictionary = (_madeiras.get(classe, _madeiras.get(MADEIRA_PADRAO, {})) as Dictionary).duplicate()
	molde["classe"] = classe
	for campo in ["rende", "quantidade", "golpes"]:
		if da_especie.has(campo):
			molde[campo] = da_especie[campo]
	return molde


## Alternativa aos troncos caídos esgotados: só madeira acessível ao machado
## e ao talento atuais, sem apontar tocos, espécies protegidas ou outro produto.
func mais_perto_que_rende(item: String, de: Vector3) -> Vector3:
	var melhor := Vector3.INF
	var menor := INF
	for arvore: Dictionary in _cortaveis:
		var especie := str(arvore.get("especie", ""))
		if bool(arvore.get("cortado", false)) or _nao_se_corta.has(especie):
			continue
		var madeira := madeira_de(especie)
		if str(madeira.get("rende", "lenha")) != item or Progressao.nivel("machado") < int(madeira.get("nivel", 1)):
			continue
		if bool(madeira.get("aco", false)) and Catalogo.grau(Equipamento.da_familia_em_uso("machado")) < 2:
			continue
		var pos: Vector3 = arvore["pos"]
		var distancia := Vector2(de.x, de.z).distance_squared_to(Vector2(pos.x, pos.z))
		if distancia < menor:
			menor = distancia
			melhor = pos
	return melhor


func _golpes_da(indice: int) -> int:
	return maxi(int(madeira_de(String(_cortaveis[indice]["especie"])).get("golpes", 3)), 1)


## O QUE IMPEDE O CORTE, dito ao jogador, ou "" quando dá para golpear.
##
## A ordem é a do tronco caído e a do 2D: primeiro o que não se resolve
## (a árvore que não se corta), depois a ferramenta e o talento — que é o que
## o jogador precisa saber para ir atrás —, e só então o cansaço. E as duas
## recusas da madeira não se parecem: "pede machado de aço" manda à venda,
## "pede o talento" manda à teia. Foi a queixa do 2D: "precisa diferenciar uma
## árvore que precisa de machado melhor de uma que precisa destravar a
## habilidade".
func _recusa(indice: int) -> String:
	var especie := String(_cortaveis[indice]["especie"])
	if _nao_se_corta.has(especie):
		return str(IdiomaMenu.campo(_nao_se_corta[especie], "texto"))
	var madeira := madeira_de(especie)
	var nivel := int(madeira.get("nivel", 1))
	var falta_talento := Progressao.nivel("machado") < nivel
	var falta_aco := bool(madeira.get("aco", false)) and Catalogo.grau(Equipamento.da_familia_em_uso("machado")) < 2
	var nome_da_madeira := str(IdiomaMenu.campo(madeira, "nome"))
	var talentos := " / ".join(Talentos.que_abrem("machado", nivel))
	var acoes: Dictionary = _acoes.get("arvore", {})
	if falta_talento and falta_aco:
		return str(IdiomaMenu.campo(acoes, "precisa_os_dois")) % [nome_da_madeira, talentos]
	if falta_aco:
		return str(IdiomaMenu.campo(acoes, "precisa_aco")) % nome_da_madeira
	if falta_talento:
		return str(IdiomaMenu.campo(acoes, "precisa_talento")) % [nome_da_madeira, talentos]
	if _stamina < Energia.custo("golpe"):
		return str(IdiomaMenu.campo(acoes, "sem_stamina"))
	if not Energia.aguenta("bater", float(madeira.get("dureza", 1.0))):
		return str(IdiomaMenu.campo(acoes, "sem_folego"))
	return ""


## O QUE A DICA DIZ sobre a árvore ao alcance do machado: golpear, a recusa,
## ou — cortada — que ela está crescendo de novo. SEM DIZER QUANDO VOLTA: "não
## informe no texto o tempo que o pé de árvore estará em pé novamente". Quem
## quer saber, olha a árvore crescer.
func _texto_do_corte(indice: int) -> String:
	var arvore: Dictionary = _cortaveis[indice]
	var nome := _nome_da_especie(String(arvore["especie"]))
	var acoes: Dictionary = _acoes.get("arvore", {})
	if bool(arvore["cortado"]):
		return str(IdiomaMenu.campo(acoes, "crescendo")) % nome
	var recusa := _recusa(indice)
	if recusa != "":
		return recusa
	return str(IdiomaMenu.campo(acoes, "golpear", "%s")) % nome


func _nome_da_especie(especie: String) -> String:
	return str(IdiomaMenu.campo(_fichas.get(especie, {}), "nome", especie.capitalize()))


func _iniciar_golpe(indice: int) -> void:
	if _cortavel_pendente >= 0 or _em_golpe >= 0 or bool(_cortaveis[indice]["cortado"]):
		return
	_cortavel_pendente = indice
	var arvore: Dictionary = _cortaveis[indice]
	var tronco: Vector3 = arvore["pos"]
	if _distancia_da_cortavel(indice) <= DISTANCIA_PARA_GOLPEAR:
		_destino_do_golpe = tronco
		_aproximando = false
		return
	var afastamento := _jogador.global_position - tronco
	afastamento.y = 0.0
	if afastamento.length_squared() < 0.01:
		afastamento = Vector3.FORWARD
	afastamento = afastamento.normalized()
	for angulo in [0.0, PI * 0.5, -PI * 0.5, PI, PI * 0.25, -PI * 0.25, PI * 0.75, -PI * 0.75]:
		var destino := tronco + afastamento.rotated(Vector3.UP, angulo) * (DISTANCIA_DE_APROXIMACAO + float(arvore.get("raio", 0.24)))
		if bool(_jogador.call("caminhar_ate", destino)):
			_destino_do_golpe = destino
			_aproximando = true
			return
	_cortavel_pendente = -1
	_destino_do_golpe = Vector3.INF
	_aproximando = false
	_hud.set_notice(str(IdiomaMenu.campo(_acoes.get("arvore", {}), "sem_caminho", "")))


func _atualizar_golpe_pendente() -> void:
	if _cortavel_pendente < 0:
		return
	var distancia := _distancia_da_cortavel(_cortavel_pendente)
	# O golpe interrompe a caminhada; esperar a desaceleração pode cancelar a ação pendente.
	if distancia <= DISTANCIA_PARA_GOLPEAR:
		var indice := _cortavel_pendente
		var tronco: Vector3 = _cortaveis[indice]["pos"]
		var visual := _jogador.get("visual") as Node3D
		visual.rotation.y = atan2(tronco.x - _jogador.global_position.x, tronco.z - _jogador.global_position.z)
		var luta: Node = _jogador.get_parent().get_node_or_null("Luta")
		if luta != null and luta.has_method("animar_golpe"):
			# Quantos golpes cabem agora: no que falta para a árvore cair, no
			# vigor do braço e no fôlego do dia — o que acabar primeiro.
			var faltam := _golpes_da(indice) - int(_cortaveis[indice]["golpes"])
			var de_vigor := int(floorf((_stamina + 0.001) / maxf(Energia.custo("golpe"), 0.001)))
			var custo_do_folego := Energia.custo("bater", float(madeira_de(String(_cortaveis[indice]["especie"])).get("dureza", 1.0)))
			var de_folego := int(floorf((Energia.atual + 0.001) / custo_do_folego)) if custo_do_folego > 0.0 else faltam
			_golpes_restantes_na_acao = mini(mini(de_vigor, de_folego), faltam)
			if _golpes_restantes_na_acao <= 0:
				_cortavel_pendente = -1
				_destino_do_golpe = Vector3.INF
				_aproximando = false
				return
			_em_golpe = indice
			var espera_animacao := bool(luta.call("animar_golpe", _golpes_restantes_na_acao))
			_jogador.call("travar_acao_de_golpe", 5.0, espera_animacao)
			if not espera_animacao:
				_golpes_restantes_na_acao = 1
				_ao_golpe_concluido()
		_cortavel_pendente = -1
		_destino_do_golpe = Vector3.INF
		_aproximando = false
	elif distancia > ALCANCE or (_aproximando and not bool(_jogador.call("caminhando_para", _destino_do_golpe))):
		_cortavel_pendente = -1
		_destino_do_golpe = Vector3.INF
		_aproximando = false


## UM GOLPE QUE ACERTOU: o vigor do braço, o fôlego do dia (bater × dureza da
## madeira) e o que o trabalho ensina. No último, a árvore cai.
func _ao_golpe_concluido() -> void:
	if _em_golpe < 0:
		return
	var indice := _em_golpe
	var arvore: Dictionary = _cortaveis[indice]
	var madeira := madeira_de(String(arvore["especie"]))
	var dureza := float(madeira.get("dureza", 1.0))
	# DUAS CONTAS (#82): o braço paga o golpe inteiro no vigor, que volta sozinho;
	# a reserva do dia paga bater × dureza, que só a comida e a cama devolvem.
	if not bool(_jogador.call("gastar_vigor", Energia.custo("golpe"))):
		_parar_golpe(false)
		return
	_stamina = float(_jogador.call("vigor_atual"))
	if not Energia.gastar("bater", dureza):
		_hud.set_notice(str(IdiomaMenu.campo(_acoes.get("arvore", {}), "sem_folego")))
		_parar_golpe(false)
		return
	Talentos.ganhar("bater_duro" if dureza > 1.5 else "bater")
	arvore["golpes"] = int(arvore["golpes"]) + 1
	_golpes_restantes_na_acao -= 1
	if int(arvore["golpes"]) >= _golpes_da(indice):
		# ELA CAI PARA LONGE DE QUEM CORTOU, como manda o lenhador.
		var cair_para: Vector3 = (arvore["pos"] as Vector3) - _jogador.global_position
		cair_para.y = 0.0
		if bool(_world.call("cortar_arvore", arvore["pos"], true, cair_para)):
			arvore["cortado"] = true
			arvore["dia_do_corte"] = Relogio.dia_absoluto()
			arvore["escala"] = 0.0
			var rende := str(madeira.get("rende", "lenha"))
			var quantos := int(madeira.get("quantidade", 1))
			if rende == "lenha":
				quantos += maxi(0, int(Talentos.bonus("lenha_a_mais")))
			if rende != "" and quantos > 0 and not Inventario.adicionar(rende, quantos):
				_hud.set_notice(str(IdiomaMenu.campo(_acoes.get("arvore", {}), "inventario_cheio")))
			Audio.efeito("arvore_cai")
			_definir_ficha_cortada(arvore["pos"], true)
		else:
			arvore["golpes"] = _golpes_da(indice) - 1
	_cortaveis[indice] = arvore
	if _golpes_restantes_na_acao <= 0 or _stamina < Energia.custo("golpe") or bool(arvore["cortado"]):
		_parar_golpe(false)


func _ao_impacto_do_golpe() -> void:
	if _em_golpe >= 0:
		Audio.efeito("machado")


# --- o ano de crescer ---------------------------------------------------------

## Um ano do calendário do jogo: as quatro estações do Relogio.
func dias_do_ano() -> int:
	return Relogio.DIAS_POR_ESTACAO * 4


## O estágio de uma árvore cortada há `dias`: o de `ESTAGIOS`, ou "adulta".
func estagio(dias: int) -> Dictionary:
	var fracao := float(dias) / float(dias_do_ano())
	if fracao >= 1.0:
		return {"nome": "adulta", "de": 1.0, "escala": 1.0}
	var atual: Dictionary = ESTAGIOS[0]
	for candidato: Dictionary in ESTAGIOS:
		if fracao >= float(candidato["de"]):
			atual = candidato
	return atual


func _ao_dia_comecar(_dia: int, _estacao: int, _ano: int) -> void:
	atualizar_crescimento()


## CADA MANHÃ, AS CORTADAS CRESCEM: quem mudou de estágio muda de tamanho, e
## quem fez um ano volta adulta e se corta de novo.
func atualizar_crescimento() -> void:
	var hoje := Relogio.dia_absoluto()
	for indice in _cortaveis.size():
		var arvore: Dictionary = _cortaveis[indice]
		if not bool(arvore["cortado"]):
			continue
		_aplicar_estagio(indice, hoje - int(arvore.get("dia_do_corte", hoje)))


func _aplicar_estagio(indice: int, dias: int) -> void:
	var arvore: Dictionary = _cortaveis[indice]
	var agora := estagio(dias)
	var escala := float(agora["escala"])
	if escala >= 1.0:
		if bool(_world.call("restaurar_arvore", arvore["pos"])):
			arvore["cortado"] = false
			arvore["golpes"] = 0
			arvore.erase("dia_do_corte")
			arvore.erase("escala")
			_definir_ficha_cortada(arvore["pos"], false)
		_cortaveis[indice] = arvore
		return
	if is_equal_approx(float(arvore.get("escala", -1.0)), escala):
		return
	if bool(_world.call("crescer_arvore", arvore["pos"], escala)):
		arvore["escala"] = escala
	_cortaveis[indice] = arvore


## O estágio de cada árvore cortada, para o portão e para quem mais quiser ver.
func estagio_da(indice: int) -> String:
	var arvore: Dictionary = _cortaveis[indice]
	if not bool(arvore["cortado"]):
		return "adulta"
	return str(estagio(Relogio.dia_absoluto() - int(arvore.get("dia_do_corte", Relogio.dia_absoluto())))["nome"])


# --- a partida salva -------------------------------------------------------------

## O QUE O MACHADO MUDOU: cada árvore cortada, com o dia do calendário em que
## caiu. O resto do vale o gerador refaz igual.
func estado_para_salvar() -> Array[Dictionary]:
	var cortadas: Array[Dictionary] = []
	for arvore: Dictionary in _cortaveis:
		if not bool(arvore.get("cortado", false)):
			continue
		var pos: Vector3 = arvore["pos"]
		cortadas.append({"pos": [pos.x, pos.y, pos.z], "dia": int(arvore.get("dia_do_corte", Relogio.dia_absoluto()))})
	return cortadas


## Chamado depois de o `Relogio` voltar do save: o estágio de cada uma é o de
## hoje. Os saves do coqueiro de 24 horas (`regenera_em_horas`, sem `dia`) contam
## o corte de hoje — a regra agora é o ano.
func restaurar_do_save(cortadas: Array) -> void:
	var hoje := Relogio.dia_absoluto()
	for registro in cortadas:
		if not registro is Dictionary:
			continue
		var coordenadas: Array = registro.get("pos", [])
		if coordenadas.size() != 3:
			continue
		var pos := Vector3(float(coordenadas[0]), float(coordenadas[1]), float(coordenadas[2]))
		var dia := int(registro.get("dia", hoje))
		var dias := hoje - dia
		if estagio(dias)["nome"] == "adulta":
			continue
		var indice := _indice_da_cortavel(pos)
		if indice < 0 or bool(_cortaveis[indice]["cortado"]):
			continue
		var com_toco: bool = estagio(dias)["nome"] == "toco"
		if not bool(_world.call("cortar_arvore", pos, com_toco)):
			continue
		var arvore: Dictionary = _cortaveis[indice]
		arvore["golpes"] = _golpes_da(indice)
		arvore["cortado"] = true
		arvore["dia_do_corte"] = dia
		arvore["escala"] = 0.0
		_cortaveis[indice] = arvore
		_definir_ficha_cortada(pos, true)
		_aplicar_estagio(indice, dias)


func _indice_da_cortavel(pos: Vector3) -> int:
	var quadra := Vector2i(floori(pos.x / QUADRA), floori(pos.z / QUADRA))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for indice: int in _cortaveis_por_quadra.get(quadra + Vector2i(dx, dz), []):
				var candidata: Vector3 = _cortaveis[indice]["pos"]
				if Vector2(candidata.x, candidata.z).distance_squared_to(Vector2(pos.x, pos.z)) < 0.01:
					return indice
	return -1


func _definir_ficha_cortada(pos: Vector3, cortado: bool) -> void:
	for ficha: Dictionary in _pontos:
		var ficha_pos: Vector3 = ficha["pos"]
		if Vector2(ficha_pos.x, ficha_pos.z).distance_squared_to(Vector2(pos.x, pos.z)) < 0.01:
			ficha["cortado"] = cortado


## A barra de vigor é do HUD, que ouve o jogador (`configurar_corpo`); aqui só
## se guarda o número, para contar quantos golpes cabem no braço.
func _ao_vigor_mudar(valor: float) -> void:
	_stamina = valor


func _criar_balao_vida(camada: Control) -> void:
	_balao_vida = PanelContainer.new()
	_balao_vida.name = "VidaDaArvore"
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
	_vida_no_balao.max_value = 3
	_vida_no_balao.value = 3
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
	if _em_golpe < 0 or camera == null or bool(_hud.get("mapa_aberto")):
		_balao_vida.visible = false
		return
	var arvore: Dictionary = _cortaveis[_em_golpe]
	var pos: Vector3 = arvore["pos"]
	var topo := pos + Vector3(0, 2.45, 0)
	if camera.is_position_behind(topo):
		_balao_vida.visible = false
		return
	_nome_no_balao.text = _nome_da_especie(String(arvore["especie"]))
	var total := _golpes_da(_em_golpe)
	var restante := maxi(total - int(arvore["golpes"]), 0)
	_vida_no_balao.max_value = total
	_vida_no_balao.value = restante
	_vida_texto_no_balao.text = "%d/%d" % [restante, total]
	var acendeu_agora := not _balao_vida.visible
	_balao_vida.visible = true
	_balao_vida.reset_size()
	# COM PESO: o ponto projetado é o alvo de uma mola, e a vida desliza até ele.
	var ancora := camera.unproject_position(topo)
	if acendeu_agora:
		_mola_da_vida.reiniciar(ancora)
	var onde := _mola_da_vida.seguir(ancora, get_process_delta_time(), DicaTecla.TEMPO_DE_SEGUIR,
		SuavizadorDeTela.VELOCIDADE_MAXIMA, SuavizadorDeTela.ZONA_MORTA, DicaTecla.CORREIA)
	_balao_vida.position = (onde - Vector2(_balao_vida.size.x * 0.5, _balao_vida.size.y)).round()


func _atualizar_acao_de_golpe() -> void:
	if _em_golpe < 0:
		return
	var animando := _animador != null and _animador.has_method("chop_ativo") and bool(_animador.call("chop_ativo"))
	if not animando or not _machado_na_mao() or _distancia_da_cortavel(_em_golpe) > ALCANCE or bool(_hud.get("mapa_aberto")):
		_parar_golpe(true)


func _parar_golpe(interromper_animacao: bool) -> void:
	if interromper_animacao and _animador != null and _animador.has_method("stop_chop"):
		_animador.call("stop_chop")
	if interromper_animacao and _jogador.has_method("liberar_acao_de_golpe"):
		_jogador.call("liberar_acao_de_golpe")
	_em_golpe = -1
	_golpes_restantes_na_acao = 0
	_balao_vida.visible = false
