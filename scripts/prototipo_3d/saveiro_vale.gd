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
	_atualizar_a_encomenda()


## CHEGA E PARTE pelo relógio: no dia dele, da hora de chegar à de partir.
## Calado (`avisar` falso) na montagem e na carga: quem abre a partida num dia
## sem saveiro não precisa saber que ele largou.
func _ver_se_chegou(avisar: bool) -> void:
	var agora := _no_dia_e_na_hora()
	if agora == _presente:
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


## Ele e o barco aparecem e somem juntos. Escondido, ele não anda, não fala e
## não recebe entrega (`CadeiaDeMissoes._tentar_encontro` não entrega a quem não
## está), e o barco sai da física.
func _mostrar(sim: bool) -> void:
	if comprador != null:
		comprador.visible = sim
		comprador.process_mode = Node.PROCESS_MODE_INHERIT if sim else Node.PROCESS_MODE_DISABLED
		if sim and comprador.has_method("ir_ao_posto_agora"):
			comprador.ir_ao_posto_agora()
	if barco != null:
		barco.visible = sim
		barco.process_mode = Node.PROCESS_MODE_INHERIT if sim else Node.PROCESS_MODE_DISABLED
		if sim and _mundo != null and _mundo.has_method("water_level") and is_finite(_mundo.water_level()):
			barco.global_position.y = _mundo.water_level()


## O SAVEIRO ATRACADO do lado do píer, alinhado com ele: o bote de toldo do
## catálogo (é o barco de carga que o vale já tem), ou, no procedural, o casco de
## tábuas das canoas. Com a colisão do próprio casco, como as canoas.
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
	# O comprimento do casco fica ao longo do píer (o X da canoa é o comprimento).
	barco.rotation.y = giro - PI * 0.5
	var casco: Node3D = null
	if Estilo.tripo() and CatalogoAssets.tem_tripo("bote"):
		casco = CatalogoAssets.instanciar("bote", barco, Vector3(0.0, -CALADO, 0.0), 1.0, PI * 0.5)
	if casco == null:
		casco = Canoas._casco_procedural()
		barco.add_child(casco)
	barco.add_child(Canoas._colisao_do_casco(casco, barco))
	barco.visible = false
	barco.process_mode = Node.PROCESS_MODE_DISABLED


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
	CadernoDoVale.concluir(_id_da_encomenda())


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
