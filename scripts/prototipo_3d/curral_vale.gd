extends Node3D
## O CURRAL DO QUINTAL — o galinheiro da casa de taipa e os ovos (data/missoes_quintal.json,
## passos `curral_aprender` e `curral`; docs/projeto/MISSOES_DO_2D.md, 2; #160).
##
## No 2D o talento Curral (raiz Pastoreio) levantava o galinheiro no terreno do jogador e
## soltava as galinhas (`mundo.gd` de lá); no vale o talento existia e não fazia nada
## (`talentos.gd`: "não destravava nada"). Agora faz: no dia em que o nó sai da teia este nó
## põe o galinheiro do Tripo (ou uma caixa de tábuas, enquanto o modelo não chega) num canto do quintal da
## casa de taipa, com um bando de três galinhas (`bando_de_chao.gd`, o das outras casas), e
## as galinhas BOTAM TODO DIA: a cada manhã (`Relogio.dia_comecou`) o ninho ganha um ovo por
## galinha, até o teto, e o E no galinheiro recolhe o que há. "Ele deu, acabou; volte amanhã."
##
## O LUGAR é escolhido uma vez, entre uns poucos cantos da casa (`CANDIDATOS`, no referencial
## dela): o primeiro em terra firme sem corpo nenhum de pé — a lavoura, a oficina, o varal e os
## troncos da chegada moram por ali. Vai em `ancoras["Galinheiro"]` SEMPRE, levantado ou não,
## porque o `Lugares` promete o nome ("galinheiro") e o passo do curral aponta para lá.
##
## O TALENTO É LIDO PELO CAMPO, e não pelo nome do nó: o galinheiro sobe quando
## `Talentos.bonus("pastoreio")` passa de zero, que é o que o nó Curral concede (e o que a
## auditoria de talentos cobra, `tools/prototipo_3d/auditar_talentos.gd`). O TRATO DO CURRAL
## (`pressa_do_curral`, "bicho seu rende um dia antes") adianta a postura: as galinhas botam o
## ovo de amanhã ao cair da tarde de hoje (`HORA_DA_POSTURA_ADIANTADA`), e o ritmo de um ovo por
## galinha por dia não muda — o ninho só enche meio dia antes.
##
## O que vai no save: os ovos no ninho e o dia da última postura (`estado_para_salvar`), e os
## dias de serviço dos moradores (`servico_do_morador.gd`, o dia de roçado do Cosme), que viajam
## aqui por não terem casa própria no vale. O galinheiro em si não vai: ele é o talento, e o
## talento vai.
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const DicaTecla = preload("res://scripts/prototipo_3d/dica_tecla.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const FocoDoE = preload("res://scripts/prototipo_3d/foco_do_e.gd")
const CatalogoAssets = preload("res://scripts/prototipo_3d/catalogo_assets.gd")
const BandoDeChao = preload("res://scripts/prototipo_3d/bando_de_chao.gd")
const TEXTOS := "res://data/quintal.json"
const BICHOS := "res://data/bichos_de_casa.json"
const CASA := "Casa de taipa"
const ServicoDoMorador = preload("res://scripts/prototipo_3d/servico_do_morador.gd")
## A hora a partir da qual o Trato do curral já bota o ovo do dia seguinte.
const HORA_DA_POSTURA_ADIANTADA := 17
const CADEIA := "pedro_quintal"
const EVENTO := "destravou:curral"
## Os cantos do quintal, no referencial da casa (x para a direita de quem olha a frente
## dela, z para a frente). A lavoura fica a 14 para a frente; a oficina, atrás.
const CANDIDATOS := [Vector3(-6.5, 0.0, 0.5), Vector3(6.5, 0.0, 0.5), Vector3(-6.5, 0.0, -4.5),
	Vector3(6.5, 0.0, -4.5), Vector3(0.0, 0.0, -7.5)]
## O vão que o galinheiro e as galinhas precisam, livre de corpo de pé (u), e a altura em
## que a caixa da pergunta começa (acima do chão, para o terreno não contar).
const VAO := Vector3(3.6, 1.2, 3.6)
const ACIMA_DO_CHAO := 0.5
const GALINHAS := 3
## Quantos ovos o ninho segura: dois dias de postura.
const TETO_DE_OVOS := GALINHAS * 2
const RAIO_DO_E := 2.6
const ALTURA_DA_DICA := 1.3
const CONFERIR_A_CADA := 0.5

## Os ovos no ninho e o dia absoluto da última postura (-1 antes do galinheiro). Vão no save.
var ovos := 0
var dia_da_postura := -1

var _mundo
var _vale
var _jogador: Node3D
var _hud
var _lugar := Vector3.INF
var _local := Vector3.ZERO
var _giro := 0.0
var _galinheiro: Node3D = null
var _bando: Node = null
var _dica: PanelContainer = null
var _textos: Dictionary = {}
var _conferir_em := 0.0


func configurar(mundo, vale, jogador: Node3D, hud) -> void:
	_mundo = mundo
	_vale = vale
	_jogador = jogador
	_hud = hud
	var lido = JSON.parse_string(FileAccess.get_file_as_string(TEXTOS))
	_textos = lido if lido is Dictionary else {}
	add_to_group("curral")
	ServicoDoMorador.limpar()
	_escolher_o_lugar()
	if hud != null and hud.has_method("map_layer"):
		_dica = DicaTecla.criar(hud.map_layer(), Atalhos.letra("interagir"), "")
		add_to_group(FocoDoE.GRUPO)
	if not Talentos.mudou.is_connected(_ao_mudar_os_talentos):
		Talentos.mudou.connect(_ao_mudar_os_talentos)
	if not Relogio.dia_comecou.is_connected(_ao_comecar_o_dia):
		Relogio.dia_comecou.connect(_ao_comecar_o_dia)
	acertar()


func _exit_tree() -> void:
	if Talentos.mudou.is_connected(_ao_mudar_os_talentos):
		Talentos.mudou.disconnect(_ao_mudar_os_talentos)
	if Relogio.dia_comecou.is_connected(_ao_comecar_o_dia):
		Relogio.dia_comecou.disconnect(_ao_comecar_o_dia)


## O talento Curral, pelo campo que ele concede.
func tem_pastoreio() -> bool:
	return Talentos.bonus("pastoreio") > 0.0


func levantado() -> bool:
	return _galinheiro != null


func lugar() -> Vector3:
	return _lugar


func galinhas() -> int:
	return _bando.aves.size() if _bando != null else 0


# --- o talento ---------------------------------------------------------------------

func _ao_mudar_os_talentos() -> void:
	acertar(true)


## O GALINHEIRO VAI PARA ONDE O TALENTO DIZ: levantado com o nó Curral, uma vez. E o passo do
## talento no segundo tutorial fecha também para quem já o tinha ("pula se já tinha o
## talento", no 2D): a fila ganha o acontecimento aqui, sem esperar outra teia.
func acertar(avisar: bool = false) -> void:
	if not tem_pastoreio() or not _lugar.is_finite():
		return
	if _galinheiro == null:
		_levantar()
		if dia_da_postura < 0:
			# A primeira postura é do dia em que o galinheiro sobe: "vai lá ver o que elas deixaram".
			dia_da_postura = Relogio.dia_absoluto()
			ovos = GALINHAS
		if avisar:
			_avisar("levantou")
	var cadeias = _vale.get("_cadeias") if _vale != null else null
	var fila = (cadeias as Dictionary).get(CADEIA) if cadeias is Dictionary else null
	if fila != null and fila.iniciado and not fila.aconteceu(EVENTO):
		fila.registrar_evento(EVENTO)


# --- a postura -----------------------------------------------------------------------

func _ao_comecar_o_dia(_dia: int, _estacao: int, _ano: int) -> void:
	_postura()


## As galinhas botam uma vez por dia: um ovo por galinha, até o teto do ninho. Conta pelo
## dia absoluto, e não pelo sinal só: a partida que volta de um save de ontem bota hoje.
func _postura() -> void:
	if _galinheiro == null or dia_da_postura < 0:
		return
	var hoje := dia_da_postura_vigente(Relogio.dia_absoluto(), Relogio.hora(),
			Talentos.bonus("pressa_do_curral") > 0.0)
	if hoje > dia_da_postura:
		ovos = mini(TETO_DE_OVOS, ovos + GALINHAS)
		dia_da_postura = hoje


## O DIA DE POSTURA QUE JÁ VALE: o de hoje, ou o de amanhã quando o Trato do curral adianta a
## postura e a tarde já caiu. Pura, para o portão conferir sem relógio.
static func dia_da_postura_vigente(hoje: int, hora: int, pressa: bool) -> int:
	return hoje + 1 if pressa and hora >= HORA_DA_POSTURA_ADIANTADA else hoje


## O E NO GALINHEIRO: recolhe o que está no ninho, um a um (a mochila cheia fica com o resto).
func recolher() -> int:
	if _galinheiro == null:
		return 0
	if ovos <= 0:
		_avisar("vazio")
		return 0
	var quantos := 0
	while ovos > 0 and Inventario.adicionar("ovo", 1):
		ovos -= 1
		quantos += 1
	if quantos == 0:
		_avisar("mochila_cheia")
		return 0
	Audio.efeito("pegar")
	_avisar("recolheu", quantos)
	return quantos


# --- a tecla -------------------------------------------------------------------------

## O QUE O E FARIA AQUI, para o foco (`foco_do_e.gd`): recolher os ovos do ninho.
func alvo_do_e() -> Dictionary:
	if _galinheiro == null or _jogador == null or not _jogador.is_physics_processing():
		return {}
	var para := _jogador.global_position - _lugar
	para.y = 0.0
	if para.length() > RAIO_DO_E:
		return {}
	return {"ponto": _lugar + Vector3.UP * 0.6}


func _process(delta: float) -> void:
	_conferir_em -= delta
	if _conferir_em <= 0.0:
		_conferir_em = CONFERIR_A_CADA
		acertar()
		_postura()
	if _dica == null:
		return
	var camera := get_viewport().get_camera_3d()
	if alvo_do_e().is_empty() or camera == null or Dialogo.ocupado() or not FocoDoE.e_dele(self):
		_dica.visible = false
		return
	var acao := (_texto("acoes", "recolher") % ovos) if ovos > 0 else _texto("acoes", "olhar")
	DicaTecla.mostrar_em(_dica, camera, _lugar + Vector3.UP * ALTURA_DA_DICA, acao)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == Atalhos.tecla("interagir")):
		return
	if alvo_do_e().is_empty() or Dialogo.ocupado() or not FocoDoE.e_dele(self):
		return
	get_viewport().set_input_as_handled()
	recolher()


# --- o lugar -------------------------------------------------------------------------

## O canto do quintal: o primeiro candidato em terra firme com o vão livre; sem nenhum
## livre, o primeiro em terra. A âncora "Galinheiro" fica posta de qualquer jeito.
func _escolher_o_lugar() -> void:
	if _mundo == null or not _mundo.ancoras.has(CASA):
		return
	var frente: Vector3 = _mundo.ancoras.get(CASA + "Frente", Vector3.BACK)
	_giro = atan2(frente.x, frente.z)
	var primeiro := Vector3.INF
	var local_do_primeiro := Vector3.ZERO
	for local: Vector3 in CANDIDATOS:
		var ponto: Vector3 = _mundo.ground_position(_na_casa(local), 0.0)
		if not _mundo.is_on_land(ponto):
			continue
		if not primeiro.is_finite():
			primeiro = ponto
			local_do_primeiro = local
		if _vao_livre(ponto):
			_lugar = ponto
			_local = local
			break
	if not _lugar.is_finite():
		_lugar = primeiro if primeiro.is_finite() else _mundo.ground_position(_na_casa(CANDIDATOS[0]), 0.0)
		_local = local_do_primeiro if primeiro.is_finite() else CANDIDATOS[0]
	_mundo.ancoras["Galinheiro"] = _lugar
	_mundo.ancoras["GalinheiroFrente"] = frente


func _na_casa(local: Vector3) -> Vector3:
	return (_mundo.ancoras[CASA] as Vector3) + local.rotated(Vector3.UP, _giro)


## Nada de pé no vão: uma caixa acima do chão (do joelho à cabeça), que não toca o terreno.
func _vao_livre(ponto: Vector3) -> bool:
	if not is_inside_tree():
		return true
	var espaco := get_world_3d().direct_space_state
	if espaco == null:
		return true
	var forma := BoxShape3D.new()
	forma.size = VAO
	var pedido := PhysicsShapeQueryParameters3D.new()
	pedido.shape = forma
	pedido.transform = Transform3D(Basis.IDENTITY, ponto + Vector3.UP * (ACIMA_DO_CHAO + VAO.y * 0.5))
	pedido.collision_mask = 0xFFFFFFFF
	pedido.collide_with_areas = false
	if _jogador is CollisionObject3D:
		pedido.exclude = [(_jogador as CollisionObject3D).get_rid()]
	return espaco.intersect_shape(pedido, 4).is_empty()


# --- o galinheiro e as galinhas ------------------------------------------------------------

func _levantar() -> void:
	var modelo: Node3D = null
	if CatalogoAssets.tem_tripo("galinheiro"):
		modelo = CatalogoAssets.instanciar("galinheiro", self, _lugar, 1.0, _giro)
		if modelo != null:
			CatalogoAssets.colisao("galinheiro", modelo, self, _lugar, 1.0, _giro)
	if modelo == null:
		modelo = _caixa_de_tabuas()
	modelo.name = "Galinheiro"
	_galinheiro = modelo
	_soltar_as_galinhas()


## O galinheiro provisório, sem modelo no catálogo: uma caixa de tábuas com corpo.
func _caixa_de_tabuas() -> Node3D:
	var tinta := StandardMaterial3D.new()
	tinta.albedo_color = Color(0.45, 0.33, 0.22)
	tinta.roughness = 1.0
	var caixa := MeshInstance3D.new()
	var malha := BoxMesh.new()
	malha.size = Vector3(2.0, 1.1, 1.3)
	caixa.mesh = malha
	caixa.material_override = tinta
	add_child(caixa)
	caixa.global_position = _lugar + Vector3.UP * 0.55
	caixa.rotation.y = _giro
	var corpo := StaticBody3D.new()
	corpo.name = "GalinheiroCorpo"
	var forma := CollisionShape3D.new()
	var bloco := BoxShape3D.new()
	bloco.size = malha.size
	forma.shape = bloco
	corpo.add_child(forma)
	add_child(corpo)
	corpo.global_position = caixa.global_position
	corpo.rotation.y = _giro
	return caixa


## O bando das três, no terreiro em frente ao galinheiro (`bando_de_chao.gd`, como nas outras
## casas: ciscam de dia e sobem no galho mais perto de noite, se houver).
func _soltar_as_galinhas() -> void:
	var lido = JSON.parse_string(FileAccess.get_file_as_string(BICHOS))
	var especies: Dictionary = (lido as Dictionary).get("especies", {}) if lido is Dictionary else {}
	if especies.is_empty() or _jogador == null or _mundo == null:
		return
	var terreiro := _local + Vector3(0.0, 0.0, 1.8)
	var linha := {"rotina": "bando", "terreiro": [terreiro.x, 0.0, terreiro.z], "raio": 2.4,
		"aves": [{"especie": "galinha", "quantos": GALINHAS}]}
	_bando = BandoDeChao.new()
	_bando.configurar(linha, especies, CASA, _mundo, _jogador)
	add_child(_bando)


# --- os textos e o save -------------------------------------------------------------------

func _texto(bloco: String, chave: String) -> String:
	return str(IdiomaMenu.campo((_textos.get(bloco, {}) as Dictionary).get(chave, {}), "texto", chave))


func _avisar(chave: String, quanto: int = 0) -> void:
	var texto := _texto("recados", chave)
	if texto.contains("%d"):
		texto = texto % quanto
	if _hud != null and _hud.has_method("set_notice"):
		_hud.set_notice(texto)


func estado_para_salvar() -> Dictionary:
	return {"ovos": ovos, "dia_da_postura": dia_da_postura, "servico": ServicoDoMorador.estado_para_salvar()}


func restaurar(estado: Dictionary) -> void:
	ovos = int(estado.get("ovos", ovos))
	dia_da_postura = int(estado.get("dia_da_postura", dia_da_postura))
	var servico = estado.get("servico", {})
	ServicoDoMorador.restaurar(servico if servico is Dictionary else {})
	acertar()
	_postura()
