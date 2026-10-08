extends Node
## O SAVEIRO DO MESTRE QUIRINO: o comprador que encosta no píer uma vez por
## estação.
##
## "Introduza uma missão de venda de piaçava 1x por mês para um NPC novo que
## chega ao porto. Na missão algum NPC irá ensinar ao jogador que o comprador
## de mercadorias vem 1x por estação do calendário do jogo e compra o que foi
## produzido no mês, dando a possibilidade do jogador levar algumas mercadorias
## para vender por um bom preço."
##
## O MÊS DO VALE É A ESTAÇÃO: o calendário tem quatro estações de 28 dias. No
## dia do saveiro (`data/saveiro.json`, o 14), da manhã à tarde, o mestre
## Quirino está no píer com o saveiro atracado do lado; nos outros dias não há
## nem ele nem o barco. Com ele perto, o painel (J) ganha a aba do saveiro: ele
## compra o que se produziu no mês — piaçava, farinha, milho, peixe... —, mais
## caro que a venda, até o tanto que leva em cada viagem.
##
## QUEM ENSINA é o Seu Benedito (`data/missoes_saveiro.json`), que vende a
## colheita para o saveiro há quarenta e duas safras. Depois da cadeia dele, a
## ENCOMENDA volta toda estação: dez feixes de piaçava para o mestre, com um
## agrado para quem entrega tudo na mesma viagem — uma missão no caderno, aberta
## no começo de cada estação e riscada na entrega (ou encerrada, se o saveiro
## partiu sem ela).
##
## A CHEGADA É NELE. "O jogador tem que começar com o boneco posicionado em
## cima de um saveiro, no pier. [...] No fim do primeiro dia, o saveiro
## obviamente some do mapa." No primeiro dia do jogo o barco está atracado — foi
## nele que o jogador veio —, sem o mestre no píer e sem a aba de compra; a
## partida nova põe o jogador no convés (`ponto_do_conves`) e o Pedro na ponta
## da prancha (`lugar_do_pedro`), e quando o dia vira o saveiro larga.

const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const CatalogoAssets = preload("res://scripts/prototipo_3d/catalogo_assets.gd")
const Canoas = preload("res://scripts/prototipo_3d/canoas.gd")
const DADOS := "res://data/saveiro.json"
## De quão perto do mestre a aba do saveiro aparece no painel.
const PERTO := 4.5
## Onde o saveiro atraca, no referencial do píer (o Z mar adentro, como os
## postos do PierPiso): do lado do tabuado, perto da ponta. Medido com raios
## (03/10/2026): o tabuado vai de -5 a +2,5 ao longo do píer e de -1,5 a +2 de
## lado; daí para fora é água — o mestre fica nele, a 1,2.
const LUGAR_DO_BARCO := Vector3(-3.3, 0.0, 0.5)
const CALADO := 0.32
## O SAVEIRO DO TRIPO ASSENTA CARREGADO, mais fundo que o bote. Medido com raios
## (05/10/2026): com o calado do bote, o convés ficava 0,6 acima do tabuado e a
## borda 0,95, e descer do barco era pular de um muro; assim o convés fica um
## palmo acima, e a quilha some no fundo raso do píer.
const CALADO_DO_SAVEIRO := 0.6
## A BORDA DO SAVEIRO, em fração da altura do modelo (medida no GLB, 05/10/2026):
## o casco vai até 2,0 m dos 6,9 m, e dali para cima é mastro, retranca e vela.
## A colisão do casco fica abaixo dela (`Canoas._colisao_do_casco`).
const BORDA_DO_SAVEIRO := 0.30
## O mastro: no meio do casco, um palmo para a popa (fração da caixa, X e Z),
## do convés (17% da altura) ao topo (96%), com 12 cm de raio.
const MASTRO_NO_MODELO := Vector2(-0.017, 0.011)
const MASTRO_DE := 0.17
const MASTRO_ATE := 0.96
const RAIO_DO_MASTRO := 0.12
## O PRIMEIRO DIA DO JOGO (`Relogio.dia_absoluto`), o da chegada.
const DIA_DA_CHEGADA := 1
## ONDE O JOGADOR NASCE E DESCE: na proa, que a vela vai do mastro (no meio do
## casco) para a popa; a esta fração do comprimento, do meio rumo à proa.
const DESCIDA_NA_PROA := 0.16
## A PRANCHA: uma rampa invisível do convés, por cima da borda, até o tabuado —
## o estilo Tripo não leva peça procedural, e sem ela a borda era parede de um
## lado e degrau de meio corpo do outro, com o vão d'água no meio.
const LARGURA_DA_PRANCHA := 1.3
const ESPESSURA_DA_PRANCHA := 0.12
## Quanto a prancha corre por cima do tabuado, além da borda do casco.
const PRANCHA_ALEM_DA_BORDA := 1.4
## O Pedro espera um passo além da ponta da prancha, já no tabuado.
const PEDRO_ALEM_DA_PRANCHA := 1.1
## O CASCO ATRACADO É OBSTÁCULO NA MALHA DOS MORADORES: a pegada dele cresce desta
## folga (m) por todos os lados — a malha ainda come o raio do agente, 0,2, e o corpo
## do morador tem 0,28: quem o segura na quina é a colisão, e a colisão é o casco —,
## e a faixa de altura vai do fundo da quilha até esta sobra acima da borda.
const FOLGA_DO_CASCO_NA_MALHA := 0.4
const SOBRA_ACIMA_DA_BORDA := 3.0

signal chegou
signal partiu
signal vendeu(id: String, reis: int)

var dia := 14
var chega := 7.0
var parte := 17.0
var compra: Dictionary = {}
var encomenda: Dictionary = {}
var _textos: Dictionary = {}

var _mundo: Node3D
var _hud
## O mestre Quirino, morador do `npcs_3d.json` que só aparece no dia dele.
var comprador: Node3D
## O saveiro atracado, que só aparece com ele.
var barco: Node3D
## A cadeia que ensina (a do Seu Benedito): a encomenda só volta depois dela.
var cadeia: Node
## A prancha da chegada, filha do barco: some com ele, e só existe no dia dela.
var prancha: StaticBody3D

## A chegada, medida na montagem: o ponto do convés onde o jogador nasce, o
## rumo do píer visto dali, e o lugar do Pedro no tabuado. INF sem barco.
var _no_conves := Vector3.INF
var _rumo_do_pier := Vector3.ZERO
var _do_pedro := Vector3.INF
## A malha do casco no referencial do barco, de três em três vértices, para medir
## o convés sem a física — que só enxerga o casco depois do primeiro passo dela.
var _faces_do_casco := PackedVector3Array()
## O CASCO NA MALHA DOS MORADORES (`navegacao_vale.gd`): a pegada dele no referencial
## do barco (planta, em metros do mundo) e a faixa de altura do casco, medidas uma vez
## na montagem; mais o corpo do casco e a camada dele, para a malha só enxergar o
## barco enquanto ele está no píer. Ver `pegada_do_casco`.
var _pegada_do_casco := Rect2()
var _faixa_do_casco := Vector2.ZERO
var _corpo_do_casco: AnimatableBody3D
var _camada_do_casco := 1
var _camada_da_prancha := 1
## O que a malha já sabe do barco (1 atracado, 2 com prancha): só pede para assar de
## novo quando isto muda.
var _na_malha := -1

var _presente := false
## O dia (absoluto) da última visita, e o que ele já levou nela.
var _visita := -1
var _vendido: Dictionary = {}
## A estação (ano * 4 + estação) em que a encomenda foi entregue por último.
var _entregue_em := -1


func configurar(mundo: Node3D, quem_compra: Node3D, hud, cadeia_que_ensina: Node) -> void:
	_mundo = mundo
	comprador = quem_compra
	_hud = hud
	cadeia = cadeia_que_ensina
	add_to_group("saveiro")
	var lido = JSON.parse_string(FileAccess.get_file_as_string(DADOS))
	if lido is Dictionary:
		dia = int(lido.get("dia", dia))
		chega = float(lido.get("chega", chega))
		parte = float(lido.get("parte", parte))
		compra = lido.get("compra", {})
		encomenda = lido.get("encomenda", {})
		_textos = lido.get("textos", {})
	_montar_o_barco()
	_presente = not _no_dia_e_na_hora()
	_ver_se_chegou(false)
	if not Dia.hora_mudou.is_connected(_ao_mudar_a_hora):
		Dia.hora_mudou.connect(_ao_mudar_a_hora)
	if not Relogio.dia_comecou.is_connected(_ao_comecar_o_dia):
		Relogio.dia_comecou.connect(_ao_comecar_o_dia)
	if cadeia != null and cadeia.has_signal("missao_mudou"):
		cadeia.missao_mudou.connect(func(_t, _a, _i, _n) -> void: _atualizar_a_encomenda())
	_atualizar_a_encomenda()


func texto(chave: String) -> String:
	return str(IdiomaMenu.campo(_textos, chave, ""))


## O mestre está no píer agora?
func presente() -> bool:
	return _presente


## O jogador está perto dele, com ele presente? É o que abre a aba do painel.
func perto(ponto: Vector3) -> bool:
	if not _presente or comprador == null:
		return false
	var no_chao := comprador.global_position - ponto
	no_chao.y = 0.0
	return no_chao.length() <= PERTO


func _no_dia_e_na_hora() -> bool:
	return Relogio.dia == dia and Dia.hora >= chega and Dia.hora < parte


func _ao_mudar_a_hora(_hora: float) -> void:
	_ver_se_chegou(true)


func _ao_comecar_o_dia(_d: int, _e: int, _a: int) -> void:
	_ver_se_chegou(true)
	# O dia que vira é o fim da chegada: o saveiro larga, com ou sem o mestre.
	_ver_o_barco()
	_atualizar_a_encomenda()


## O DIA DA CHEGADA: o saveiro que trouxe o jogador está no píer.
func na_chegada() -> bool:
	return Relogio.dia_absoluto() == DIA_DA_CHEGADA


## CHEGA E PARTE pelo relógio: no dia dele, da hora de chegar à de partir.
## Calado (`avisar` falso) na montagem e na carga: quem abre a partida num dia
## sem saveiro não precisa saber que ele largou.
func _ver_se_chegou(avisar: bool) -> void:
	var agora := _no_dia_e_na_hora()
	if agora == _presente:
		# O mestre não mudou, mas o dia pode ter mudado (a chegada acabou).
		_ver_o_barco()
		return
	_presente = agora
	if agora:
		var hoje := Relogio.dia_absoluto()
		if hoje != _visita:
			_visita = hoje
			_vendido.clear()
	_mostrar(agora)
	if avisar and _hud != null and texto("chegou") != "":
		_hud.set_notice(texto("chegou") if agora else texto("partiu"))
	if agora:
		chegou.emit()
	else:
		partiu.emit()
	_atualizar_a_encomenda()


## O mestre aparece e some no dia dele. Escondido, ele não anda, não fala e não
## recebe entrega (`CadeiaDeMissoes._tentar_encontro` não entrega a quem não
## está).
func _mostrar(sim: bool) -> void:
	if comprador != null:
		# O orçamento de apresentação não pode convocar uma visita fora do dia.
		comprador.set_meta("presenca_do_calendario", sim)
		comprador.visible = sim
		comprador.process_mode = Node.PROCESS_MODE_INHERIT if sim else Node.PROCESS_MODE_DISABLED
		if sim and comprador.has_method("ir_ao_posto_agora"):
			comprador.ir_ao_posto_agora()
		var vale := get_parent()
		if vale != null and "apresentacao_do_povoado" in vale and vale.apresentacao_do_povoado != null:
			vale.apresentacao_do_povoado.atualizar()
	_ver_o_barco()


## O BARCO está atracado com o mestre no píer, e no dia da chegada sem ele.
## Fora disso, escondido e fora da física. A prancha só vale no dia da chegada:
## no dia do mestre, com a maré noutro ponto, a ponta dela não acharia o tabuado.
func _ver_o_barco() -> void:
	if barco == null:
		return
	var atracado := _presente or na_chegada()
	var atracando := atracado and not barco.visible
	barco.visible = atracado
	barco.process_mode = Node.PROCESS_MODE_INHERIT if atracado else Node.PROCESS_MODE_DISABLED
	# Assenta na água de agora AO ATRACAR, e só então: atracado, ele não sobe e
	# desce com a maré a cada hora, e a ponta da prancha não sai do tabuado.
	if atracando and _mundo != null and _mundo.has_method("water_level") and is_finite(_mundo.water_level()):
		barco.global_position.y = _mundo.water_level()
	if atracado and na_chegada():
		_montar_a_prancha()
	if prancha != null:
		prancha.process_mode = Node.PROCESS_MODE_INHERIT if na_chegada() else Node.PROCESS_MODE_DISABLED
	_dizer_a_malha(atracado)


## O BARCO NA MALHA DOS MORADORES. Corpo desligado (`process_mode`) sai da física, mas
## continua nó com camada na árvore, e a assada lê a árvore: o casco fora do píer virava
## obstáculo fantasma, e a prancha, rampa. Camada zero esconde um e outro da malha. E
## quando o barco atraca ou larga a malha se assa de novo, com a pegada do casco
## (`pegada_do_casco`) de obstáculo — o morador contorna o barco em vez de empurrá-lo.
func _dizer_a_malha(atracado: bool) -> void:
	var com_prancha := prancha != null and na_chegada()
	# Chamado a cada tique do relógio: só mexe quando o que a malha vê do barco muda.
	var estado := (1 if atracado else 0) + (2 if com_prancha else 0)
	if estado == _na_malha:
		return
	_na_malha = estado
	if _corpo_do_casco != null:
		_corpo_do_casco.collision_layer = _camada_do_casco if atracado else 0
	if prancha != null:
		prancha.collision_layer = _camada_da_prancha if com_prancha else 0
	var navegacao := get_tree().get_first_node_in_group("navegacao") if is_inside_tree() else null
	if navegacao != null:
		navegacao.reassar()


## A PEGADA DO CASCO ATRACADO para a malha dos moradores: o retângulo do casco no giro
## do barco, crescido de `FOLGA_DO_CASCO_NA_MALHA` (os quatro cantos, no mundo), e a
## faixa de altura (`elevacao` e `altura`, para o obstáculo projetado). Vazio com o
## barco fora do píer. Mede só o que tem colisão (abaixo do teto: vela e mastro não
## são parede).
func pegada_do_casco() -> Dictionary:
	if barco == null or not barco.visible or _pegada_do_casco.size == Vector2.ZERO:
		return {}
	var caixa := _pegada_do_casco.grow(FOLGA_DO_CASCO_NA_MALHA)
	var cantos := PackedVector3Array()
	for canto in [caixa.position, Vector2(caixa.end.x, caixa.position.y), caixa.end, Vector2(caixa.position.x, caixa.end.y)]:
		var no_mundo := barco.global_transform * Vector3(canto.x, 0.0, canto.y)
		cantos.append(Vector3(no_mundo.x, 0.0, no_mundo.z))
	var fundo := barco.global_position.y + _faixa_do_casco.x - 0.5
	return {"contorno": cantos, "elevacao": fundo,
		"altura": barco.global_position.y + _faixa_do_casco.y + SOBRA_ACIMA_DA_BORDA - fundo}


## O SAVEIRO ATRACADO do lado do píer, alinhado com ele: o saveiro do catálogo;
## sem ele, o bote de toldo (o barco de carga que o vale já tinha); no
## procedural, o casco de tábuas das canoas. Com a colisão do próprio casco, como
## as canoas.
func _montar_o_barco() -> void:
	if _mundo == null or not ("ancoras" in _mundo) or not _mundo.ancoras.has("PierPiso"):
		return
	var piso: Vector3 = _mundo.ancoras["PierPiso"]
	var rumo: Vector3 = _mundo.ancoras.get("PierDirecao", Vector3.FORWARD)
	var giro := atan2(rumo.x, rumo.z)
	barco = Node3D.new()
	barco.name = "SaveiroAtracado"
	_mundo.add_child(barco)
	barco.global_position = piso + LUGAR_DO_BARCO.rotated(Vector3.UP, giro)
	# O comprimento do casco fica ao longo do píer (o X da canoa é o comprimento),
	# e o píer fica do lado -Z do barco.
	barco.rotation.y = giro - PI * 0.5
	var casco: Node3D = null
	var e_o_saveiro := false
	if Estilo.tripo() and CatalogoAssets.tem_tripo("saveiro"):
		# O comprimento do saveiro é o X do modelo, com a proa no +X: ela aponta
		# mar adentro, e a vela fica do lado da terra.
		casco = CatalogoAssets.instanciar("saveiro", barco, Vector3(0.0, -CALADO_DO_SAVEIRO, 0.0), 1.0, 0.0)
		e_o_saveiro = casco != null
	elif Estilo.tripo() and CatalogoAssets.tem_tripo("bote"):
		casco = CatalogoAssets.instanciar("bote", barco, Vector3(0.0, -CALADO, 0.0), 1.0, PI * 0.5)
	if casco == null:
		casco = Canoas._casco_procedural()
		barco.add_child(casco)
	# O CORPO DO CASCO ACOMPANHA O BARCO NA HORA. O das canoas sincroniza com a
	# física (`sync_to_physics`), que é o certo para quem balança a cada quadro;
	# o barco atracado só desce à água ao atracar, e o corpo sincronizado
	# desfazia esse movimento: ficava 0,38 acima do desenho, e o jogador do
	# convés nascia dentro do casco.
	#
	# NO SAVEIRO DO TRIPO, O CASCO VAI SÓ ATÉ A BORDA, e o mastro é um cilindro:
	# com a malha inteira, a vela e a retranca eram parede no meio do convés.
	var limites: AABB = casco.get_meta("limites", AABB())
	var teto := -CALADO_DO_SAVEIRO + limites.size.y * BORDA_DO_SAVEIRO if e_o_saveiro else INF
	var corpo := Canoas._colisao_do_casco(casco, barco, teto)
	if e_o_saveiro:
		corpo.add_child(_mastro(limites))
	corpo.sync_to_physics = false
	barco.add_child(corpo)
	_corpo_do_casco = corpo
	_camada_do_casco = corpo.collision_layer
	_guardar_as_faces(casco, teto)
	barco.visible = false
	barco.process_mode = Node.PROCESS_MODE_DISABLED


## O MASTRO DO SAVEIRO, um cilindro do convés ao topo, no referencial do barco.
func _mastro(limites: AABB) -> CollisionShape3D:
	var forma := CylinderShape3D.new()
	forma.radius = RAIO_DO_MASTRO
	forma.height = limites.size.y * (MASTRO_ATE - MASTRO_DE)
	var colisao := CollisionShape3D.new()
	colisao.name = "Mastro"
	colisao.shape = forma
	colisao.position = Vector3(limites.size.x * MASTRO_NO_MODELO.x, -CALADO_DO_SAVEIRO + limites.size.y * (MASTRO_DE + MASTRO_ATE) * 0.5, limites.size.z * MASTRO_NO_MODELO.y)
	return colisao


# --- a chegada ---------------------------------------------------------------------

## Onde o jogador nasce na partida nova: no convés, na proa, um pouco para o
## lado do píer. INF se não há barco.
func ponto_do_conves() -> Vector3:
	return _no_conves


## Para onde o píer fica, visto do convés: é para lá que o jogador olha ao chegar.
func rumo_do_pier() -> Vector3:
	return _rumo_do_pier


## Onde o Pedro espera a chegada: no tabuado, um passo além da ponta da prancha.
func lugar_do_pedro() -> Vector3:
	return _do_pedro


func _guardar_as_faces(casco: Node3D, teto: float = INF) -> void:
	_faces_do_casco = PackedVector3Array()
	var malhas: Array = casco.find_children("*", "MeshInstance3D", true, false)
	if casco is MeshInstance3D:
		malhas.push_front(casco)
	var para_o_barco := barco.global_transform.affine_inverse()
	for no in malhas:
		var malha := no as MeshInstance3D
		if malha.mesh == null:
			continue
		var transformacao := para_o_barco * malha.global_transform
		for vertice in malha.mesh.get_faces():
			_faces_do_casco.append(transformacao * vertice)
	_medir_a_pegada(teto)


## A PEGADA E A FAIXA DE ALTURA DO CASCO que tem colisão: os triângulos inteiros abaixo
## do `teto`, a mesma regra de `Canoas._colisao_do_casco`. Uma vez só, na montagem.
func _medir_a_pegada(teto: float) -> void:
	var menor := Vector3.INF
	var maior := -Vector3.INF
	for i in range(0, _faces_do_casco.size() - 2, 3):
		var a := _faces_do_casco[i]
		var b := _faces_do_casco[i + 1]
		var c := _faces_do_casco[i + 2]
		if a.y > teto or b.y > teto or c.y > teto:
			continue
		menor = menor.min(a.min(b).min(c))
		maior = maior.max(a.max(b).max(c))
	if not menor.is_finite() or not maior.is_finite():
		_pegada_do_casco = Rect2()
		return
	_pegada_do_casco = Rect2(menor.x, menor.z, maior.x - menor.x, maior.z - menor.z)
	_faixa_do_casco = Vector2(menor.y, maior.y)


## AS ALTURAS DO CASCO na vertical de (x, z), no referencial do barco: a mais
## alta abaixo de `teto` — acima dele é mastro, verga e vela. -INF fora do casco.
func _altura_do_casco(x: float, z: float, teto: float) -> float:
	var melhor := -INF
	for i in range(0, _faces_do_casco.size() - 2, 3):
		var a := _faces_do_casco[i]
		var b := _faces_do_casco[i + 1]
		var c := _faces_do_casco[i + 2]
		if x < minf(a.x, minf(b.x, c.x)) or x > maxf(a.x, maxf(b.x, c.x)) \
				or z < minf(a.z, minf(b.z, c.z)) or z > maxf(a.z, maxf(b.z, c.z)):
			continue
		var d := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
		if absf(d) < 1e-9:
			continue
		var u := ((b.z - c.z) * (x - c.x) + (c.x - b.x) * (z - c.z)) / d
		var v := ((c.z - a.z) * (x - c.x) + (a.x - c.x) * (z - c.z)) / d
		if u < 0.0 or v < 0.0 or u + v > 1.0:
			continue
		var y := u * a.y + v * b.y + (1.0 - u - v) * c.y
		if y < teto and y > melhor:
			melhor = y
	return melhor


## O tabuado na vertical de um ponto do mundo, pela física (o píer está nela
## desde a montagem do vale); sem tabuado ali, a âncora do piso.
func _tabuado_em(ponto: Vector3) -> float:
	var piso: Vector3 = _mundo.ancoras["PierPiso"]
	var raio := PhysicsRayQueryParameters3D.create(Vector3(ponto.x, piso.y + 2.0, ponto.z), Vector3(ponto.x, piso.y - 2.0, ponto.z), 1)
	var achado := _mundo.get_world_3d().direct_space_state.intersect_ray(raio)
	if achado.is_empty() or (is_finite(_mundo.water_level()) and achado["position"].y < _mundo.water_level()):
		return piso.y
	return achado["position"].y


## A PRANCHA DA CHEGADA, e os pontos dela. Medida na malha do casco: da proa,
## no meio do comprimento que a vela não ocupa, o convés; rumo ao píer, a borda
## e o alto dela; além da borda, o tabuado. Duas tábuas invisíveis — do convés
## ao alto da borda, e de lá ao tabuado —, filhas do barco.
func _montar_a_prancha() -> void:
	if barco == null or _faces_do_casco.is_empty() or prancha != null:
		return
	var menor := Vector3.INF
	var maior := -Vector3.INF
	for vertice in _faces_do_casco:
		menor = menor.min(vertice)
		maior = maior.max(vertice)
	var comprimento := maior.x - menor.x
	var x := (menor.x + maior.x) * 0.5 + comprimento * DESCIDA_NA_PROA
	var teto := menor.y + comprimento * 0.2
	# A BORDA do lado do píer (o -Z do barco), de um em um palmo.
	var borda := 0.0
	var z := 0.0
	while z > menor.z - 0.1:
		if not is_finite(_altura_do_casco(x, z, teto)):
			break
		borda = z
		z -= 0.1
	if borda > -0.3:
		return
	var no_conves := Vector3(x, _altura_do_casco(x, borda * 0.35, teto), borda * 0.35)
	var de := Vector3(x, _altura_do_casco(x, borda * 0.55, teto), borda * 0.55)
	var alto := de.y
	var w := borda * 0.75
	while w >= borda:
		alto = maxf(alto, _altura_do_casco(x, w, teto))
		w -= 0.05
	if not is_finite(no_conves.y) or not is_finite(de.y):
		return
	var sobre_a_borda := Vector3(x, alto + 0.04, borda - 0.05)
	var para_o_mundo := barco.global_transform
	var ponta_no_mundo := para_o_mundo * Vector3(x, 0.0, borda - PRANCHA_ALEM_DA_BORDA)
	ponta_no_mundo.y = _tabuado_em(ponta_no_mundo)
	var ponta := para_o_mundo.affine_inverse() * ponta_no_mundo
	prancha = StaticBody3D.new()
	prancha.name = "PranchaDaChegada"
	_camada_da_prancha = prancha.collision_layer
	barco.add_child(prancha)
	prancha.add_child(_tabua(de, sobre_a_borda))
	prancha.add_child(_tabua(sobre_a_borda, ponta))
	_no_conves = para_o_mundo * no_conves + Vector3.UP * 0.05
	var rumo := para_o_mundo.basis * Vector3(0.0, 0.0, -1.0)
	rumo.y = 0.0
	_rumo_do_pier = rumo.normalized()
	_do_pedro = ponta_no_mundo + _rumo_do_pier * PEDRO_ALEM_DA_PRANCHA
	_do_pedro.y = _tabuado_em(_do_pedro) + 0.05


## Uma tábua invisível com o lado de cima na linha de `de` a `ate` (no
## referencial do barco).
func _tabua(de: Vector3, ate: Vector3) -> CollisionShape3D:
	var eixo := ate - de
	var forma := BoxShape3D.new()
	forma.size = Vector3(LARGURA_DA_PRANCHA, ESPESSURA_DA_PRANCHA, eixo.length())
	var colisao := CollisionShape3D.new()
	colisao.shape = forma
	var base := Basis.looking_at(eixo.normalized(), Vector3.UP)
	colisao.transform = Transform3D(base, (de + ate) * 0.5 - base.y * ESPESSURA_DA_PRANCHA * 0.5)
	return colisao


# --- a compra ---------------------------------------------------------------------

## O que ele compra, na ordem do JSON.
func o_que_compra() -> Array:
	return compra.keys()


func paga(id: String) -> int:
	return int((compra.get(id, {}) as Dictionary).get("paga", 0))


func leva(id: String) -> int:
	return int((compra.get(id, {}) as Dictionary).get("leva", 0))


## Quanto disso ele já levou nesta viagem.
func levou(id: String) -> int:
	return int(_vendido.get(id, 0))


## VENDE UM ao mestre. Devolve "" quando vendeu, ou o porquê não.
func vender(id: String) -> String:
	if not _presente or not compra.has(id):
		return texto("nao_tem")
	if not Inventario.tem(id):
		return texto("nao_tem")
	if levou(id) >= leva(id):
		return texto("ja_levou")
	Inventario.consumir(id, 1)
	Jogo.dinheiro += paga(id)
	_vendido[id] = levou(id) + 1
	vendeu.emit(id, paga(id))
	_ver_a_encomenda_entregue()
	_atualizar_a_encomenda()
	return ""


# --- a encomenda da estação -----------------------------------------------------------

func _estacao_de_agora() -> int:
	return Relogio.ano * 4 + Relogio.estacao


func _id_da_encomenda(estacao: int = -1) -> String:
	return "saveiro_encomenda_%d" % (_estacao_de_agora() if estacao < 0 else estacao)


func _pede() -> int:
	return int(encomenda.get("quantos", 10))


func _item_da_encomenda() -> String:
	return str(encomenda.get("item", "piacava"))


## A encomenda volta depois da cadeia que ensina.
func encomenda_aberta() -> bool:
	return cadeia != null and cadeia.has_method("acabou") and bool(cadeia.acabou())


## Entregou tudo nesta viagem: o agrado, e a encomenda riscada no caderno.
func _ver_a_encomenda_entregue() -> void:
	if not encomenda_aberta() or _entregue_em == _estacao_de_agora():
		return
	if levou(_item_da_encomenda()) < _pede():
		return
	_entregue_em = _estacao_de_agora()
	var agrado := int(encomenda.get("agrado_reis", 0))
	Jogo.dinheiro += agrado
	if _hud != null:
		_hud.set_notice(texto("agrado") % agrado)
	# A encomenda é missão inteira de um passo só: festeja (07/10).
	CadernoDoVale.concluir(_id_da_encomenda(), true)


## A ENCOMENDA NO CADERNO: aberta no começo de cada estação, com a conta da
## piaçava juntada; riscada na entrega; encerrada se o saveiro partiu sem ela.
func _atualizar_a_encomenda() -> void:
	if not encomenda_aberta():
		return
	var estacao := _estacao_de_agora()
	# A da estação passada que ficou aberta (o saveiro partiu sem ela, ou a
	# partida foi salva antes) sai do caderno.
	for anterior in range(estacao - 4, estacao):
		if CadernoDoVale.tem(_id_da_encomenda(anterior)):
			CadernoDoVale.encerrar(_id_da_encomenda(anterior))
	# A CADEIA ENTREGOU A PRIMEIRA: a piaçava da missão do Seu Benedito, levada
	# ao mestre, é a encomenda desta estação.
	if cadeia != null and cadeia.has_method("acabou") and _entregue_em < 0:
		_entregue_em = estacao
	var id := _id_da_encomenda()
	if _entregue_em == estacao:
		return
	var passou := Relogio.dia > dia or (Relogio.dia == dia and Dia.hora >= parte)
	if passou:
		if CadernoDoVale.tem(id):
			CadernoDoVale.encerrar(id)
		return
	if not CadernoDoVale.tem(id) and not CadernoDoVale.cumprida(id):
		CadernoDoVale.abrir_missao(id, texto("encomenda_titulo"), "quirino", false, texto("encomenda_texto"))
	var juntou := mini(Inventario.quantidade(_item_da_encomenda()) + levou(_item_da_encomenda()), _pede())
	CadernoDoVale.andar(id, juntou, _pede(), texto("encomenda_linha") % [_pede(), dia])
	if comprador != null:
		CadernoDoVale.apontar(id, comprador.global_position)


func _process(_delta: float) -> void:
	# A conta da piaçava juntada anda com a mochila; uma vez por segundo basta.
	if Engine.get_process_frames() % 60 == 0:
		_atualizar_a_encomenda()


# --- a partida salva -------------------------------------------------------------------

func estado_para_salvar() -> Dictionary:
	return {"visita": _visita, "vendido": _vendido.duplicate(), "entregue_em": _entregue_em}


func restaurar(estado: Dictionary) -> void:
	_visita = int(estado.get("visita", -1))
	_vendido = (estado.get("vendido", {}) as Dictionary).duplicate()
	_entregue_em = int(estado.get("entregue_em", -1))
	# A visita de hoje continua; a de outro dia não.
	if _visita != Relogio.dia_absoluto():
		_vendido.clear()
	_presente = not _no_dia_e_na_hora()
	_ver_se_chegou(false)
	_atualizar_a_encomenda()
