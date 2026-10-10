extends Node3D
## O CAPÍTULO 7, O REVOAR DAS ASAS NEGRAS (data/missoes_revoar.json; docs/enredo/capitulo-07.md;
## docs/projeto/MISSOES_DO_2D.md, 4; o plano do 2D, Fase 6, fatias 7.1 a 7.5; #31).
##
## A fila segue a da fazenda (`fazenda_vale.gd`): começa quando a porta estreita se fecha
## atrás do Pedro, sem E. O quarto sem janelas e os corredores são contados pela voz do
## mundo, com o escuro, como o salão redondo do fim do capítulo 6; o que é LUGAR de verdade
## são as ruínas do palacete, a torre da capela e a estátua da coruja — atrás do monte a
## oeste da fazenda, no fim da terra (`RUINAS_M`, `TORRE_M`, `ESTATUA_M`, em metros a partir
## da praça como as da fazenda). Este nó as levanta sempre: muros sem telhado, colunas
## caídas, a torre com a rampa de pedra por fora e os destroços no alto.
##
##   7.1 O QUARTO: a voz conta a cama e a velha; a velha oferece TROCAS, perguntas de sim ou
##       não (`Dialogo.perguntar`): aceitar tira fôlego (`FOLEGO_POR_TROCA` do máximo) e dá
##       o que ela oferece; recusar é o caminho. Quem aceita as três vai ao chão (sem
##       desmaio: a jornada acontece uma vez). Depois as miragens voltam-se para o Pedro,
##       que estende a mão — e é o jogador quem o puxa (o E nele, passo `revoar_mao`).
##   7.2 A FUGA E O ABRIGO: corredores, entardecer, a moça na escadaria, o estrondo, a
##       coruja; o arraial corre para as ruínas (`ir_ate`), o Pedro conduz (`conduz`), e no
##       abrigo a anciã conta a história do senhor da fazenda.
##   7.3 ESCUDO E LANÇA: no alto da torre, o E nos destroços dá os dois (`_pegar_as_armas`);
##       com a lança na mão e o escudo nas Mãos, o E bate uma no outro e chama a fera
##       (`chamou_a_fera`).
##   7.4 O EMBATE é luta de verdade (decisão do autor: "o embate com a Matinta é combate de
##       verdade"): a fera é criatura (`data/criaturas_3d.json`, "matinta", nascida pelo
##       `luta_vale.nascer`), a lança é arma, o escudo segura a mordida. O espírito do
##       senhor anda ao lado do jogador, a luz azul da lança e do escudo cresce com a fera
##       perto, e com a fera abaixo de `SINAL_EM` da vida o senhor AVANÇA — o sinal: ela fica
##       tonta `SINAL_DURA` segundos. Derrubada, a voz conta a chama azul e a estátua fica
##       nas ruínas para sempre.
##   7.5 A LIBERTAÇÃO: o E na estátua traz o pedido da anciã e a escolha: deixar o escudo
##       (vira pedra ao lado da coruja) ou levar (a conta da Matinta vai junto). O amanhecer
##       fecha o capítulo; o arraial volta para casa no dia seguinte (`fazenda_vale`).
##
## O que vai no save é da fila, como acontecimentos dela: as trocas, as armas, o chamado, o
## escudo que ficou ou foi levado. A estátua e a fera viva se refazem daí (`acertar`).
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const CatalogoAssets = preload("res://scripts/prototipo_3d/catalogo_assets.gd")
const DicaTecla = preload("res://scripts/prototipo_3d/dica_tecla.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const FocoDoE = preload("res://scripts/prototipo_3d/foco_do_e.gd")
const ARQUIVO := "res://data/missoes_revoar.json"
const CADEIA := "pedro_revoar"
const ESPECIE := "matinta"
## Em metros a partir da praça: o meio das ruínas (o abrigo), o meio da torre e a estátua.
const RUINAS_M := Vector3(264.0, 0.0, -1312.0)
const TORRE_M := Vector3(232.0, 0.0, -1344.0)
const ESTATUA_M := Vector3(280.0, 0.0, -1288.0)
## As clareiras das ruínas na mata cênica (`world_builder._clareiras_das_frentes`).
const CLAREIRAS_M := [Vector2(264, -1312), Vector2(232, -1344), Vector2(280, -1288), Vector2(240, -1312),
	Vector2(288, -1320), Vector2(256, -1340), Vector2(216, -1328), Vector2(264, -1280), Vector2(232, -1372)]
## A torre: o lado, a altura do piso de cima e o parapeito; a rampa de pedra que sobe por
## fora, pela frente (sul), e o quanto ela avança no chão.
const LADO_DA_TORRE := 3.2
const ALTURA_DA_TORRE := 3.6
const PARAPEITO := 0.9
const RAMPA := Vector3(1.8, 0.3, 7.6)
const PE_DA_RAMPA := 7.2
## De quão perto o E vale nos destroços e na estátua, e a altura da dica.
const RAIO_DO_E := 2.4
const ALTURA_DA_DICA := 1.4
## A fera nasce a esta distância do meio das ruínas, do lado oposto à torre; o senhor anda
## ao lado do jogador, a este deslocamento (x para a esquerda, z para trás), a este passo.
const FERA_LONGE := 9.0
const AO_LADO := Vector3(-1.4, 0.0, 0.5)
const PASSO_DO_ESPIRITO := 3.4
## O sinal: com a fera abaixo desta fração da vida, o senhor avança, para a dois passos
## dela, e ela fica tonta este tanto.
const SINAL_EM := 0.35
const SINAL_DURA := 2.8
const DIANTE_DA_FERA := 1.8
## A luz azul da lança e do escudo perto da fera: de onde começa a crescer, e a força cheia.
const LUZ_ALCANCE := 16.0
const LUZ_FORCA := 2.4
const COR_DA_SAFIRA := Color(0.3, 0.5, 1.0)
const COR_DA_PEDRA := Color(0.5, 0.49, 0.46)
const COR_DO_MUSGO := Color(0.42, 0.45, 0.36)
## Quanto do fôlego máximo cada troca aceita leva; as três levam ao chão.
const FOLEGO_POR_TROCA := 0.4
const CONFERIR_A_CADA := 0.5
## Os passos em que o Pedro espera nas ruínas (depois do que ele conduz).
const PASSOS_NAS_RUINAS := ["revoar_armas", "revoar_chamado", "revoar_embate", "revoar_libertacao"]

var _mundo
var _vale
var _cadeia
var _ruinas := Vector3.INF
var _torre := Vector3.INF
var _torre_centro := Vector3.INF
var _topo := Vector3.INF
var _estatua := Vector3.INF
var _fera = null
var _espirito: Node3D = null
var _luz: OmniLight3D = null
var _estatua_no: Node3D = null
var _dica: PanelContainer = null
var _em_cena := false
var _espera_antes := 0.0
var _sinal := -1.0
var _sinal_dado := false
var _relogio := 0.0
var _conferir_em := 0.0


func configurar(mundo, vale) -> void:
	_mundo = mundo
	_vale = vale
	_cadeia = (vale._cadeias as Dictionary).get(CADEIA)
	add_to_group("revoar")
	_torre_centro = mundo.ground_position(mundo._u(TORRE_M), 0.0)
	_ruinas = mundo.ground_position(mundo._u(RUINAS_M), 0.0)
	_estatua = mundo.ground_position(mundo._u(ESTATUA_M), 0.0)
	_torre = mundo.ground_position(_torre_centro + Vector3(0.0, 0.0, LADO_DA_TORRE * 0.5 + PE_DA_RAMPA), 0.0)
	_topo = _torre_centro + Vector3.UP * ALTURA_DA_TORRE
	# AS ÂNCORAS FICAM POSTAS SEMPRE: o `Lugares` promete os três nomes.
	mundo.ancoras["Ruínas do palacete"] = _ruinas
	mundo.ancoras["Torre da capela"] = _torre
	mundo.ancoras["Estátua da coruja"] = _estatua
	_levantar()
	var hud = vale.get("hud")
	if hud != null and hud.has_method("map_layer"):
		_dica = DicaTecla.criar(hud.map_layer(), Atalhos.letra("interagir"), "")
		add_to_group(FocoDoE.GRUPO)
	acertar()


func ruinas() -> Vector3:
	return _ruinas


func topo_da_torre() -> Vector3:
	return _topo


func estatua() -> Vector3:
	return _estatua


func em_cena() -> bool:
	return _em_cena


func fera():
	return _fera if _fera != null and is_instance_valid(_fera) else null


func espirito() -> Node3D:
	return _espirito


func estatua_posta() -> bool:
	return _estatua_no != null


# --- a fila ------------------------------------------------------------------------------

func _passo() -> String:
	if _cadeia == null or not _cadeia.iniciado or _cadeia.acabou():
		return ""
	return str(_cadeia.passo_atual().get("id", ""))


## O CAPÍTULO COMO A FILA DIZ QUE ELE ESTÁ: começa com a porta estreita fechada; a fera de pé
## no embate (a partida que volta do save); a estátua depois dele; o Pedro nas ruínas, e livre
## no fim.
func acertar() -> void:
	if _cadeia == null:
		return
	if not _cadeia.iniciado:
		var fazenda = (_vale._cadeias as Dictionary).get("pedro_fazenda")
		if fazenda != null and fazenda.acabou() and fazenda.aconteceu("porta_estreita"):
			_cadeia.comecar(1.5)
		return
	var passo := _passo()
	if passo == "revoar_embate" and not _em_cena and fera() == null and _cadeia.aconteceu("chamou_a_fera"):
		_nascer_a_fera()
		_montar_o_espirito()
	if (passo == "revoar_libertacao" or _cadeia.acabou()) and _estatua_no == null:
		_montar_a_estatua(_cadeia.aconteceu("escudo_ficou"))
	_segurar_o_pedro(passo)


func _segurar_o_pedro(passo: String) -> void:
	var pedro: Node3D = _vale.get("pedro")
	if pedro == null:
		return
	if PASSOS_NAS_RUINAS.has(passo):
		var destino = pedro.get("_destino_avulso")
		if not (destino is Vector3) or not (destino as Vector3).is_finite():
			pedro.ir_ate(_mundo.ground_position(_ruinas + Vector3(1.6, 0.0, 2.2), 0.05))
	elif _cadeia.acabou() and not _cadeia.aconteceu("pedro_livre"):
		_cadeia.registrar_evento("pedro_livre")
		pedro.liberar()


func _segurar() -> void:
	_em_cena = true
	_espera_antes = _cadeia.espera
	_cadeia.espera = 1000.0


func _soltar() -> void:
	_cadeia.espera = minf(_espera_antes, 0.8) if _espera_antes > 0.0 else 0.8
	_em_cena = false


# --- as cenas ------------------------------------------------------------------------------

## 7.1 O QUARTO (a `cena` do passo do quarto): a voz conta a cama e a velha; as trocas; as
## miragens para o Pedro. O passo seguinte é a mão dele, no E.
func o_quarto() -> void:
	if _em_cena or _cadeia == null:
		return
	_segurar()
	_cadeia.registrar_evento("quarto")
	await _narrar(_falas("quarto"))
	var aceitas := 0
	var recusou := false
	var i := 0
	for troca in (Jogo.dados(ARQUIVO).get("trocas", []) as Array):
		i += 1
		await Dialogo.falar(_nome("velha"), [str(IdiomaMenu.campo(troca, "oferta", ""))])
		var aceitou: bool = await Dialogo.perguntar(_nome("velha"), str(IdiomaMenu.campo(troca, "pergunta", "")))
		if aceitou:
			aceitas += 1
			_cadeia.registrar_evento("troca:%d" % i)
			Energia.definir(Energia.atual - Energia.maximo() * FOLEGO_POR_TROCA)
			var reis := int(troca.get("reis", 0))
			if reis > 0:
				Jogo.dinheiro += reis
			_avisar("troca", reis)
			await _narrar(_falas("chao") if aceitas >= 3 else _falas("aceite"))
		else:
			_cadeia.registrar_evento("recusa:%d" % i)
			if not recusou:
				recusou = true
				await _narrar(_falas("recusa"))
	await _narrar(_falas("miragens"))
	_soltar()


## 7.2 A FUGA (a `cena` do passo da mão): a fumaça e a coruja entalhada, os corredores, o
## entardecer, a moça na escadaria, o estrondo e o revoar. O arraial corre para as ruínas.
func a_fuga() -> void:
	if _em_cena or _cadeia == null:
		return
	_segurar()
	_cadeia.registrar_evento("fuga")
	await _narrar(_falas("fuga"))
	await Dialogo.falar(_nome("moca"), _falas("perdao"))
	await _narrar(_falas("revoar"))
	_arraial_para_as_ruinas()
	_soltar()


## 7.2 O ABRIGO (a `cena` do passo do abrigo): a noite nas ruínas e o relato das escravas.
func o_relato() -> void:
	if _em_cena or _cadeia == null:
		return
	_segurar()
	_cadeia.registrar_evento("relato")
	await _narrar(_falas("noite"))
	await Dialogo.falar(_nome("ancia"), _falas("relato"))
	await _narrar(_falas("senhor"))
	await Dialogo.falar(_nome_do_pedro(), _falas("pedro_torre"))
	_soltar()


## 7.3 → 7.4 A FERA VEM (a `cena` do passo do chamado): o grito ao longe, as asas, a luz azul;
## a fera nasce nas ruínas e o senhor aparece ao lado do jogador.
func a_fera_vem() -> void:
	if _em_cena or _cadeia == null:
		return
	_segurar()
	await _narrar(_falas("chamado"))
	_nascer_a_fera()
	_montar_o_espirito()
	await Dialogo.falar(_nome_do_pedro(), _falas("pedro_embate"))
	_soltar()


## 7.4 A PEDRA (a `cena` do passo do embate): as duas lanças, a chama azul, os dois de pedra.
func a_pedra() -> void:
	if _em_cena or _cadeia == null:
		return
	_segurar()
	_apagar_a_luz()
	_despedir_o_espirito()
	await _narrar(_falas("pedra"))
	_montar_a_estatua(false)
	_soltar()


## 7.5 O AMANHECER (a `cena` do passo da libertação): o canto, os feridos, o sol, a despedida.
func o_amanhecer() -> void:
	if _em_cena or _cadeia == null:
		return
	_segurar()
	await _narrar(_falas("amanhecer_levado" if _cadeia.aconteceu("escudo_levado") else "amanhecer"))
	_soltar()


# --- a tecla -------------------------------------------------------------------------------

## O QUE O E FARIA AQUI, para o foco (`foco_do_e.gd`): pegar as armas ou bater a lança no
## escudo, no alto da torre; ouvir a anciã, na estátua.
func alvo_do_e() -> Dictionary:
	var jogador: Node3D = _vale.player if _vale != null else null
	if jogador == null or not jogador.is_physics_processing() or _em_cena:
		return {}
	match _passo():
		"revoar_armas", "revoar_chamado":
			if _perto(jogador, _topo, RAIO_DO_E, 2.5):
				return {"ponto": _topo + Vector3.UP * 0.4, "vies": 0.5}
		"revoar_libertacao":
			if _perto(jogador, _estatua, RAIO_DO_E + 0.8, 2.5):
				return {"ponto": _estatua + Vector3.UP * 0.8, "vies": 0.5}
	return {}


func _perto(jogador: Node3D, ponto: Vector3, raio: float, altura: float) -> bool:
	var para := jogador.global_position - ponto
	var dy := absf(para.y)
	para.y = 0.0
	return para.length() <= raio and dy <= altura


## O E, pelo passo: pegar as armas, bater a lança no escudo, ouvir a anciã.
func usar_o_e() -> void:
	match _passo():
		"revoar_armas":
			_pegar_as_armas()
		"revoar_chamado":
			_bater_a_lanca()
		"revoar_libertacao":
			_libertar()


func _dica_do_passo() -> String:
	match _passo():
		"revoar_armas":
			return _texto("dicas", "pegar")
		"revoar_chamado":
			return _texto("dicas", "bater")
		"revoar_libertacao":
			return _texto("dicas", "falar")
	return ""


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == Atalhos.tecla("interagir")):
		return
	if alvo_do_e().is_empty() or Dialogo.ocupado() or not FocoDoE.e_dele(self):
		return
	get_viewport().set_input_as_handled()
	usar_o_e()


## 7.3: entre os destroços, a lança e o escudo. Uma vez; o passo fecha pelo `juntar`.
func _pegar_as_armas() -> void:
	if _cadeia.aconteceu("armas"):
		return
	var entrou := true
	for item in ["lanca_de_safira", "escudo_de_safira"]:
		if not Inventario.tem(item) and not Equipamento.em_uso(item):
			entrou = Inventario.adicionar(item, 1) and entrou
	if not entrou:
		return
	_cadeia.registrar_evento("armas")
	Audio.efeito("pegar")
	_avisar("achou")


## 7.3: a lança batida no escudo chama a fera — com a lança na mão e o escudo vestido.
func _bater_a_lanca() -> void:
	if Inventario.na_mao() != "lanca_de_safira":
		_avisar("sem_lanca")
		return
	if not Equipamento.em_uso("escudo_de_safira"):
		_avisar("sem_escudo")
		return
	if _cadeia.aconteceu("chamou_a_fera"):
		return
	Audio.efeito("machado")
	_cadeia.registrar_evento("chamou_a_fera")


## 7.5: o pedido da anciã e a escolha do capítulo.
func _libertar() -> void:
	if _em_cena or _cadeia.aconteceu("libertou"):
		return
	_em_cena = true
	await Dialogo.falar(_nome("ancia"), _falas("pedido"))
	var pergunta := str(IdiomaMenu.campo(Jogo.dados(ARQUIVO).get("pergunta_escudo", {}), "texto", ""))
	var deixa: bool = await Dialogo.perguntar(_nome("ancia"), pergunta)
	if deixa:
		if Equipamento.em_uso("escudo_de_safira"):
			Equipamento.desequipar("maos")
		Inventario.consumir("escudo_de_safira", Inventario.quantidade("escudo_de_safira"))
		_cadeia.registrar_evento("escudo_ficou")
		_por_o_escudo_na_estatua()
		_avisar("escudo_ficou")
	else:
		_cadeia.registrar_evento("escudo_levado")
	_cadeia.registrar_evento("libertou")
	_em_cena = false


# --- o quadro -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_relogio += delta
	_conferir_em -= delta
	if _conferir_em <= 0.0:
		_conferir_em = CONFERIR_A_CADA
		acertar()
	_mover_o_espirito(delta)
	_acender_a_luz()
	_mostrar_a_dica()


func _mostrar_a_dica() -> void:
	if _dica == null:
		return
	var camera := get_viewport().get_camera_3d()
	var alvo := alvo_do_e()
	if alvo.is_empty() or camera == null or Dialogo.ocupado() or not FocoDoE.e_dele(self):
		_dica.visible = false
		return
	DicaTecla.mostrar_em(_dica, camera, (alvo["ponto"] as Vector3) + Vector3.UP * (ALTURA_DA_DICA - 0.4), _dica_do_passo())


# --- a fera, o senhor e a luz ------------------------------------------------------------------

## A fera nasce nas ruínas, do lado oposto à torre, já caçando.
func _nascer_a_fera() -> void:
	var luta = _vale.get_node_or_null("Luta")
	if luta == null or fera() != null:
		return
	var rumo := _ruinas - _torre_centro
	rumo.y = 0.0
	rumo = rumo.normalized() if rumo.length() > 0.01 else Vector3.BACK
	var onde: Vector3 = _mundo.ground_position(_ruinas + rumo * FERA_LONGE, 0.05)
	_fera = luta.nascer(ESPECIE, onde)
	if _fera != null:
		_fera.cacando = true
	_sinal = -1.0
	_sinal_dado = false


## O espírito do senhor da fazenda: um vulto azul, translúcido, armado como o jogador.
func _montar_o_espirito() -> void:
	if _espirito != null:
		return
	var jogador: Node3D = _vale.player
	if jogador == null:
		return
	_espirito = Node3D.new()
	_espirito.name = "EspiritoDoSenhor"
	add_child(_espirito)
	var tinta := StandardMaterial3D.new()
	tinta.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tinta.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tinta.albedo_color = Color(0.5, 0.65, 1.0, 0.45)
	tinta.emission_enabled = true
	tinta.emission = COR_DA_SAFIRA
	tinta.emission_energy_multiplier = 1.2
	tinta.cull_mode = BaseMaterial3D.CULL_DISABLED
	var corpo := MeshInstance3D.new()
	var capsula := CapsuleMesh.new()
	capsula.radius = 0.3
	capsula.height = 1.5
	corpo.mesh = capsula
	corpo.material_override = tinta
	corpo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	corpo.position = Vector3(0.0, 1.05, 0.0)
	_espirito.add_child(corpo)
	var cabeca := MeshInstance3D.new()
	var bola := SphereMesh.new()
	bola.radius = 0.17
	bola.height = 0.34
	cabeca.mesh = bola
	cabeca.material_override = tinta
	cabeca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cabeca.position = Vector3(0.0, 1.95, 0.0)
	_espirito.add_child(cabeca)
	var lanca := MeshInstance3D.new()
	var haste := CylinderMesh.new()
	haste.top_radius = 0.03
	haste.bottom_radius = 0.03
	haste.height = 2.0
	lanca.mesh = haste
	lanca.material_override = tinta
	lanca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lanca.position = Vector3(0.35, 1.1, 0.1)
	lanca.rotation = Vector3(0.1, 0.0, 0.05)
	_espirito.add_child(lanca)
	var escudo := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 0.42
	disco.bottom_radius = 0.42
	disco.height = 0.06
	escudo.mesh = disco
	escudo.material_override = tinta
	escudo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	escudo.position = Vector3(-0.42, 1.0, 0.2)
	escudo.rotation = Vector3(PI * 0.5, 0.0, 0.3)
	_espirito.add_child(escudo)
	_espirito.global_position = _mundo.ground_position(jogador.global_position + _ao_lado_do(jogador), 0.0)


func _despedir_o_espirito() -> void:
	if _espirito != null:
		_espirito.queue_free()
		_espirito = null
	_sinal = -1.0


func _ao_lado_do(jogador: Node3D) -> Vector3:
	var visual: Node3D = jogador.get("visual")
	var giro: float = visual.rotation.y if visual != null else 0.0
	return AO_LADO.rotated(Vector3.UP, giro)


## O senhor anda ao lado do jogador; no sinal, avança até dois passos da fera e ela fica
## tonta. Depois volta ao lado.
func _mover_o_espirito(delta: float) -> void:
	if _espirito == null:
		return
	var jogador: Node3D = _vale.player
	if jogador == null:
		return
	var bicho = fera()
	var alvo: Vector3 = jogador.global_position + _ao_lado_do(jogador)
	if bicho != null and not bicho.morto():
		var fracao: float = float(bicho.vida) / maxf(1.0, float(bicho.dados().get("vida", 1.0)))
		if not _sinal_dado and fracao <= SINAL_EM:
			_sinal_dado = true
			_sinal = _relogio
			if bicho.has_method("tontear"):
				bicho.tontear(SINAL_DURA)
			_avisar("sinal")
		if _sinal >= 0.0 and _relogio - _sinal <= SINAL_DURA:
			var para_o_jogador: Vector3 = jogador.global_position - bicho.global_position
			para_o_jogador.y = 0.0
			alvo = bicho.global_position + (para_o_jogador.normalized() if para_o_jogador.length() > 0.01 else Vector3.BACK) * DIANTE_DA_FERA
		elif _sinal >= 0.0:
			_sinal = -1.0
	var destino: Vector3 = _mundo.ground_position(alvo, 0.0)
	_espirito.global_position = _espirito.global_position.move_toward(destino, PASSO_DO_ESPIRITO * delta)
	var olhar: Vector3 = (bicho.global_position if bicho != null and not bicho.morto() else jogador.global_position) - _espirito.global_position
	olhar.y = 0.0
	if olhar.length() > 0.05:
		_espirito.rotation.y = atan2(olhar.x, olhar.z)


## A luz azul no jogador: com a lança na mão ou o escudo no braço, cresce com a fera perto.
func _acender_a_luz() -> void:
	var jogador: Node3D = _vale.player
	var bicho = fera()
	if jogador == null or bicho == null or bicho.morto():
		if _luz != null:
			_luz.light_energy = 0.0
		return
	if not (Inventario.na_mao() == "lanca_de_safira" or Equipamento.em_uso("escudo_de_safira")):
		if _luz != null:
			_luz.light_energy = 0.0
		return
	if _luz == null:
		_luz = OmniLight3D.new()
		_luz.name = "LuzDaSafira"
		_luz.light_color = COR_DA_SAFIRA
		_luz.omni_range = 7.0
		_luz.shadow_enabled = false
		_luz.position = Vector3(0.0, 1.2, 0.0)
		jogador.add_child(_luz)
	var para: Vector3 = bicho.global_position - jogador.global_position
	para.y = 0.0
	var perto := clampf(1.0 - para.length() / LUZ_ALCANCE, 0.0, 1.0)
	var pulso := 1.0 + (0.35 * sin(_relogio * 9.0) if _sinal >= 0.0 else 0.0)
	_luz.light_energy = perto * LUZ_FORCA * pulso


func _apagar_a_luz() -> void:
	if _luz != null:
		_luz.queue_free()
		_luz = null


# --- o arraial e o Pedro --------------------------------------------------------------------------

func _moradores() -> Array:
	var lista: Array = []
	for morador in _vale.moradores:
		if is_instance_valid(morador) and morador.is_visible_in_tree() and morador.has_method("ir_ate"):
			lista.append(morador)
	return lista


## Todo mundo corre para as ruínas: cada um num ponto da roda em volta do abrigo. Voltam
## para casa no dia seguinte, como a fazenda manda (`fazenda_vale._ao_comecar_o_dia`).
func _arraial_para_as_ruinas() -> void:
	var todos := _moradores()
	var n := maxi(todos.size(), 1)
	for i in todos.size():
		var angulo := TAU * float(i) / float(n)
		var raio := 3.2 + 1.4 * float(i % 2)
		var lugar: Vector3 = _mundo.ground_position(_ruinas + Vector3(cos(angulo) * raio, 0.0, sin(angulo) * raio), 0.05)
		todos[i].ir_ate(lugar)


func _nome_do_pedro() -> String:
	var pedro = _vale.get("pedro")
	return str(pedro.dados.get("nome", "Pedro")) if pedro != null else "Pedro"


# --- as ruínas, a torre e a estátua ----------------------------------------------------------------

func _pedra() -> StandardMaterial3D:
	var tinta := StandardMaterial3D.new()
	tinta.albedo_color = COR_DA_PEDRA
	tinta.roughness = 1.0
	return tinta


func _musgo() -> StandardMaterial3D:
	var tinta := StandardMaterial3D.new()
	tinta.albedo_color = COR_DO_MUSGO
	tinta.roughness = 1.0
	return tinta


## As ruínas do palacete: muros sem telhado, colunas caídas, uma de pé, a torre da capela
## com a rampa e os destroços. Levantadas sempre — são lugar do vale, não só do capítulo.
func _levantar() -> void:
	var pedra := _pedra()
	var musgo := _musgo()
	for muro in [[Vector3(6.0, 2.2, 0.6), Vector3(-4.0, 0.0, -3.0), 0.0], [Vector3(0.6, 1.6, 5.0), Vector3(4.5, 0.0, -1.0), 0.0],
			[Vector3(5.0, 1.2, 0.6), Vector3(1.0, 0.0, 4.0), 0.15], [Vector3(0.6, 2.6, 3.0), Vector3(-5.5, 0.0, 2.0), -0.1],
			[Vector3(3.0, 0.9, 0.6), Vector3(6.0, 0.0, 3.0), 0.5], [Vector3(2.2, 0.5, 1.4), Vector3(-2.6, 0.0, -0.4), 0.8]]:
		_bloco(muro[0], _chao(_ruinas + muro[1]), float(muro[2]), pedra if int(float(muro[2]) * 10.0) % 2 == 0 else musgo, "Muro")
	_coluna(_chao(_ruinas + Vector3(2.0, 0.0, -4.2)), 0.3, 3.2, 0.2, pedra)
	_coluna(_chao(_ruinas + Vector3(-2.2, 0.0, 3.2)), 0.3, 2.6, -0.9, pedra)
	_bloco(Vector3(0.7, 2.4, 0.7), _chao(_ruinas + Vector3(-1.0, 0.0, -1.5)), 0.3, pedra, "ColunaDePe")
	# A TORRE DA CAPELA: o corpo, o piso de cima com o parapeito em três lados (o sul fica
	# aberto para a rampa), os destroços no alto e a rampa de pedra que sobe pela frente.
	var base: Vector3 = _torre_centro
	_bloco(Vector3(LADO_DA_TORRE, ALTURA_DA_TORRE, LADO_DA_TORRE), base, 0.0, pedra, "Torre")
	var meio := LADO_DA_TORRE * 0.5 - 0.125
	_bloco(Vector3(0.25, PARAPEITO, LADO_DA_TORRE), _topo + Vector3(-meio, 0.0, 0.0), 0.0, pedra, "Parapeito")
	_bloco(Vector3(0.25, PARAPEITO, LADO_DA_TORRE), _topo + Vector3(meio, 0.0, 0.0), 0.0, pedra, "Parapeito")
	_bloco(Vector3(LADO_DA_TORRE, PARAPEITO, 0.25), _topo + Vector3(0.0, 0.0, -meio), 0.0, pedra, "Parapeito")
	_bloco(Vector3(0.7, 0.35, 0.5), _topo + Vector3(0.7, 0.0, -0.6), 0.3, musgo, "Destroco")
	_bloco(Vector3(0.5, 0.3, 0.9), _topo + Vector3(-0.8, 0.0, 0.3), -0.4, pedra, "Destroco")
	_bloco(Vector3(0.4, 0.5, 0.4), _topo + Vector3(0.2, 0.0, 0.9), 0.1, pedra, "Destroco")
	_rampa(base, pedra)


## O chão sob um ponto, para assentar o que fica nele.
func _chao(ponto: Vector3) -> Vector3:
	return _mundo.ground_position(ponto, 0.0)


## Um bloco de pedra com corpo: `base` é o meio da face de baixo.
func _bloco(tamanho: Vector3, base: Vector3, giro: float, tinta: Material, nome: String) -> StaticBody3D:
	var malha := MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = tamanho
	malha.mesh = caixa
	malha.material_override = tinta
	malha.name = nome
	add_child(malha)
	malha.global_position = base + Vector3.UP * tamanho.y * 0.5
	malha.rotation.y = giro
	var corpo := StaticBody3D.new()
	corpo.name = nome + "Corpo"
	var forma := CollisionShape3D.new()
	var bloco := BoxShape3D.new()
	bloco.size = tamanho
	forma.shape = bloco
	corpo.add_child(forma)
	add_child(corpo)
	corpo.global_position = malha.global_position
	corpo.rotation.y = giro
	return corpo


## Uma coluna tombada, com corpo.
func _coluna(base: Vector3, raio: float, comprimento: float, giro: float, tinta: Material) -> void:
	var malha := MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = raio
	cilindro.bottom_radius = raio
	cilindro.height = comprimento
	malha.mesh = cilindro
	malha.material_override = tinta
	malha.name = "ColunaCaida"
	add_child(malha)
	malha.global_position = base + Vector3.UP * raio
	malha.rotation = Vector3(PI * 0.5, giro, 0.0)
	var corpo := StaticBody3D.new()
	corpo.name = "ColunaCaidaCorpo"
	var forma := CollisionShape3D.new()
	var tubo := CylinderShape3D.new()
	tubo.radius = raio
	tubo.height = comprimento
	forma.shape = tubo
	corpo.add_child(forma)
	add_child(corpo)
	corpo.global_position = malha.global_position
	corpo.rotation = malha.rotation


## A rampa de pedra: sobe pela frente (sul) da torre até o piso de cima, inclinada como uma
## ladeira de pedra (uns 28 graus), com o corpo dela.
func _rampa(base: Vector3, tinta: Material) -> void:
	var inclinacao := atan2(ALTURA_DA_TORRE, sqrt(RAMPA.z * RAMPA.z - ALTURA_DA_TORRE * ALTURA_DA_TORRE))
	var avanco := RAMPA.z * cos(inclinacao)
	var centro := base + Vector3(0.0, ALTURA_DA_TORRE * 0.5 - RAMPA.y * 0.5, LADO_DA_TORRE * 0.5 + avanco * 0.5)
	var malha := MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = RAMPA
	malha.mesh = caixa
	malha.material_override = tinta
	malha.name = "Rampa"
	add_child(malha)
	malha.global_position = centro
	malha.rotation.x = inclinacao
	var corpo := StaticBody3D.new()
	corpo.name = "RampaCorpo"
	var forma := CollisionShape3D.new()
	var bloco := BoxShape3D.new()
	bloco.size = RAMPA
	forma.shape = bloco
	corpo.add_child(forma)
	add_child(corpo)
	corpo.global_position = centro
	corpo.rotation.x = inclinacao


## A ESTÁTUA: a coruja de pedra caída sobre o senhor, a lança dele, e o escudo — se ficou.
func _montar_a_estatua(com_escudo: bool) -> void:
	if _estatua_no != null:
		return
	var pedra := _pedra()
	_estatua_no = Node3D.new()
	_estatua_no.name = "EstatuaDaCoruja"
	add_child(_estatua_no)
	_estatua_no.global_position = _estatua
	var senhor := MeshInstance3D.new()
	var capsula := CapsuleMesh.new()
	capsula.radius = 0.32
	capsula.height = 1.9
	senhor.mesh = capsula
	senhor.material_override = pedra
	senhor.name = "Senhor"
	_estatua_no.add_child(senhor)
	senhor.position = Vector3(0.0, 0.32, 0.0)
	senhor.rotation.x = PI * 0.5
	var coruja: Node3D = null
	if CatalogoAssets.tem_tripo("urubu"):
		coruja = CatalogoAssets.instanciar("urubu", _estatua_no, _estatua + Vector3.UP * 0.55, 2.4, 0.6)
	if coruja == null:
		coruja = MeshInstance3D.new()
		var caixa := BoxMesh.new()
		caixa.size = Vector3(1.1, 1.0, 2.0)
		(coruja as MeshInstance3D).mesh = caixa
		_estatua_no.add_child(coruja)
		coruja.position = Vector3(0.0, 1.05, 0.0)
	coruja.name = "Coruja"
	for malha in coruja.find_children("*", "GeometryInstance3D", true, false) + ([coruja] if coruja is GeometryInstance3D else []):
		(malha as GeometryInstance3D).material_override = pedra
	var lanca := MeshInstance3D.new()
	var haste := CylinderMesh.new()
	haste.top_radius = 0.04
	haste.bottom_radius = 0.04
	haste.height = 2.2
	lanca.mesh = haste
	lanca.material_override = pedra
	lanca.name = "Lanca"
	_estatua_no.add_child(lanca)
	lanca.position = Vector3(0.3, 1.3, -0.4)
	lanca.rotation = Vector3(0.4, 0.3, 0.6)
	var corpo := StaticBody3D.new()
	corpo.name = "EstatuaCorpo"
	var forma := CollisionShape3D.new()
	var bloco := BoxShape3D.new()
	bloco.size = Vector3(2.4, 1.3, 2.6)
	forma.shape = bloco
	corpo.add_child(forma)
	_estatua_no.add_child(corpo)
	corpo.position = Vector3(0.0, 0.65, 0.0)
	if com_escudo:
		_por_o_escudo_na_estatua()


func _por_o_escudo_na_estatua() -> void:
	if _estatua_no == null or _estatua_no.get_node_or_null("Escudo") != null:
		return
	var escudo := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 0.5
	disco.bottom_radius = 0.5
	disco.height = 0.08
	escudo.mesh = disco
	escudo.material_override = _pedra()
	escudo.name = "Escudo"
	_estatua_no.add_child(escudo)
	escudo.position = Vector3(1.4, 0.5, 0.5)
	escudo.rotation = Vector3(1.2, 0.4, 0.0)


# --- a voz, as falas, os textos ---------------------------------------------------------------------

## A voz do mundo conta, com o jogador parado, e devolve o corpo ao fim.
func _narrar(frases: Array) -> void:
	var narracao = _vale.get("narracao")
	if narracao == null or frases.is_empty():
		return
	var jogador: Node3D = _vale.player
	if jogador != null:
		jogador.set_physics_process(false)
	narracao.narrar(frases)
	await narracao.terminou
	if jogador != null:
		jogador.set_physics_process(true)


## As falas de uma lista do arquivo, na língua do jogo.
func _falas(chave: String) -> Array:
	var linhas: Array = []
	for fala in (Jogo.dados(ARQUIVO).get(chave, []) as Array):
		linhas.append(str(IdiomaMenu.campo(fala, "texto", "")))
	return linhas


## O nome de quem fala, na língua do jogo ("velha", "moca", "ancia").
func _nome(chave: String) -> String:
	return str(IdiomaMenu.campo(Jogo.dados(ARQUIVO).get(chave, {}), "nome", chave))


func _texto(bloco: String, chave: String) -> String:
	return str(IdiomaMenu.campo((Jogo.dados(ARQUIVO).get(bloco, {}) as Dictionary).get(chave, {}), "texto", chave))


func _avisar(chave: String, quanto: int = 0) -> void:
	var texto := _texto("recados", chave)
	if texto.contains("%d"):
		texto = texto % quanto
	var hud = _vale.get("hud")
	if hud != null and hud.has_method("set_notice"):
		hud.set_notice(texto)
