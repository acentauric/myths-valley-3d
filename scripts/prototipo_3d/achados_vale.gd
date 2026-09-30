extends Node
## O QUE SE ACHA NO VALE: os cordéis, os sinais e as cartas do lugar do mito
## (#12). É o que o `Mundo` do 2D espalha (`_espalhar_cordeis`,
## `_espalhar_sinais`, `_espalhar_cartas`), com a mesma ordem das coisas:
##
## - O CORDEL está num lugar do arraial — o balcão do armazém, o banco da
##   capela, a ponta do píer. Pegar paga o troco e o guarda na coleção (L).
##   Coisa que se guarda na memória não entra na mochila.
## - O SINAL está onde o mito anda, e a CARTA ESPERA O SINAL: ela não está no
##   chão desde o primeiro dia; aparece onde o sinal estava, depois que o
##   jogador o viu, porque é ali que a coisa está.
## - A CARTA DE PACTO se firma NO LUGAR DO MITO. No 2D, pegá-la abre a
##   pergunta "Firmar?", que é a caixa de Sim e Não da #21. Até ela chegar, o
##   vale diz o que o pacto dá e o que cobra, e o SEGUNDO E, ali mesmo, firma;
##   andar para longe é dizer que não — e a carta fica, e o painel (J) ainda
##   firma depois, como no 2D.
##
## O QUE O VALE AINDA NÃO TEM está declarado, com a razão: quatro cordéis e o
## lugar da Iara esperam a lagoa, o vau, a ruína e o engenho. As cartas que
## vêm dos moradores (a reza da Zefa, o braço do Cosme...) chegam pela
## amizade, que é o `Povoado` (#13).
##
## Entra na árvore ANTES da luta: com bicho perto, o E é da luta primeiro.

const DicaTecla = preload("res://scripts/prototipo_3d/dica_tecla.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const TEXTOS := "res://data/achados.json"

## Quão perto, no chão, para a tecla aparecer e o E valer.
const ALCANCE := 1.8
## Longe assim do lugar do pacto, a oferta vira "fica para outro dia".
const DESISTE := 6.0
const ALTURA_DICA := 0.9
## Quanto cada fala fica no aviso antes da próxima.
const POR_FALA := 3.6

## ONDE CADA CORDEL ESTÁ NO VALE: a âncora do lugar que o `onde` dele descreve,
## e onde em volta dela. `diante` anda pela frente da construção a partir da
## beira dela; `lado` anda de lado; `piso` usa a altura da âncora em vez do
## chão (o píer fica sobre a água, e o chão ali é o fundo do mar).
const CORDEIS := {
	"peso_falso": {"ancora": "Venda do Bar", "diante": 1.2},          # no balcão do armazém
	"vendeu_a_chuva": {"ancora": "Bar", "diante": -2.0, "lado": 3.2},   # no bar da praia, numa mesa
	"cachorro_do_enterro": {"ancora": "Capela velha", "diante": 1.2},   # na capela
	"missa_dos_afogados": {"ancora": "Cemitério"},                       # no cemitério
	"porfia_do_caboclo": {"ancora": "Mirante"},                          # no mirante, na serra
	"moleque_do_pier": {"ancora": "PierPiso", "piso": true},            # na ponta do píer
}
const CORDEIS_QUE_FALTAM := {
	"moca_da_agua": "na beira da lagoa, que o vale ainda não tem (#23)",
	"cabra_da_fazenda": "no vau do rio grande, debaixo da ponte caída, que o vale ainda não tem (#23)",
	"santo_do_pau_oco": "na ruína do palacete, que é a segunda região (#25)",
	"boi_do_reconcavo": "no engenho, construção do roçado que ainda não existe (#27)",
}

## O sinal de cada lugar de mito — os do 2D (`Mundo.SINAL_DE_CADA_LUGAR`).
const SINAL_DE_CADA_LUGAR := {
	"mata_do_dende": "a_mata_que_parou",
	"lagoa": "o_que_olhou_de_volta",
}
const LUGARES_QUE_FALTAM := {
	"lagoa": "a lagoa da Iara é da #23: o sinal dela, a carta dela e a moça da água esperam por ela",
}
## A mata do dendê no vale: mata fechada, longe da porta de casa, da chegada e
## do ninho do caititu — o encontro com a Caipora não é briga.
const LONGE_DE_CASA := 45.0
const LONGE_DO_BICHO := 25.0
const BUSCA_RAIO := 320.0
const BUSCA_PASSO := 8.0

signal achou(tipo: String, id: String)

var _world
var _player
var _hud
var _luta
var _textos: Dictionary = {}
var _dica: PanelContainer
## Cada achado no chão: {tipo, id, lugar, ponto, no}.
var no_chao: Array = []
## Onde fica cada lugar de mito no vale, resolvido uma vez.
var lugares: Dictionary = {}
## O pacto oferecido e ainda não respondido: {id, ponto}, ou vazio.
var oferta: Dictionary = {}
var _avisou_perto: Dictionary = {}
var _fala := 0


func configurar(world, player, hud, luta) -> void:
	_world = world
	_player = player
	_hud = hud
	_luta = luta
	var lido = JSON.parse_string(FileAccess.get_file_as_string(TEXTOS))
	_textos = lido if lido is Dictionary else {}
	_dica = DicaTecla.criar(hud.map_layer(), Atalhos.letra("interagir"), _texto("dica_cordel"))
	_dica.visible = false
	var mata := _ponto_da_mata()
	if mata.is_finite():
		lugares["mata_do_dende"] = mata
	else:
		push_warning("Achados: não achei mata fechada para a Caipora")


func _texto(chave: String) -> String:
	return str(IdiomaMenu.campo(_textos.get(chave, {}), "texto", chave))


## Põe no chão o que ainda não foi achado. Chamado depois de a partida salva
## voltar (ver prototype.gd): o que o save diz que já se achou não reaparece.
## Pode ser chamado de novo — refaz tudo do zero.
func espalhar() -> void:
	for achado in no_chao:
		if is_instance_valid(achado["no"]):
			achado["no"].queue_free()
	no_chao.clear()
	for id in CORDEIS:
		if Colecao.tem("cordeis", str(id)) or Colecao.dados("cordeis", str(id)).is_empty():
			continue
		var ponto := ponto_do_cordel(str(id))
		if ponto.is_finite():
			_por("cordel", str(id), "", ponto)
	for lugar in SINAL_DE_CADA_LUGAR:
		var sinal := str(SINAL_DE_CADA_LUGAR[lugar])
		if not lugares.has(lugar) or Colecao.tem("sinais", sinal):
			continue
		_por("sinal", sinal, str(lugar), _ao_lado(lugares[lugar], 0))
	_espalhar_cartas()


## As cartas com lugar, cada uma ESPERANDO o sinal do lugar dela.
func _espalhar_cartas() -> void:
	var n := 1
	for id in Cartas.tudo():
		var lugar := str(Cartas.dados(str(id)).get("onde", ""))
		if lugar == "" or Cartas.tem(str(id)) or not lugares.has(lugar):
			continue
		if SINAL_DE_CADA_LUGAR.has(lugar) and not Colecao.tem("sinais", str(SINAL_DE_CADA_LUGAR[lugar])):
			continue
		if _no_chao_tem("carta", str(id)):
			continue
		_por("carta", str(id), lugar, _ao_lado(lugares[lugar], n))
		n += 1


func _no_chao_tem(tipo: String, id: String) -> bool:
	for achado in no_chao:
		if achado["tipo"] == tipo and achado["id"] == id:
			return true
	return false


# --- onde as coisas ficam -----------------------------------------------------

func ponto_do_cordel(id: String) -> Vector3:
	var onde: Dictionary = CORDEIS.get(id, {})
	var ancora := str(onde.get("ancora", ""))
	var base: Vector3 = _world.ancoras.get(ancora, Vector3.INF)
	if not base.is_finite():
		return Vector3.INF
	if bool(onde.get("piso", false)):
		return base + Vector3(0.0, 0.02, 0.0)
	var frente: Vector3 = _world.ancoras.get(ancora + "Frente", Vector3.ZERO)
	frente.y = 0.0
	var ponto := base
	if frente.length_squared() > 0.001 and (onde.has("diante") or onde.has("lado")):
		frente = frente.normalized()
		var lado := Vector3(frente.z, 0.0, -frente.x)
		var beira := _meia_largura(ancora)
		var diante := float(onde.get("diante", 0.0))
		ponto = base + frente * (beira + diante if diante >= 0.0 else diante) + lado * (beira + float(onde.get("lado", 0.0)) if onde.has("lado") else 0.0)
	return _terra_perto(ponto)


## A peça do catálogo de cada âncora com construção, para a largura dela.
const PECA_DA_ANCORA := {"Venda do Bar": "venda", "Bar": "venda", "Capela velha": "capela"}

func _meia_largura(ancora: String) -> float:
	var peca := str(PECA_DA_ANCORA.get(ancora, ""))
	return float(CatalogoAssets.PECAS.get(peca, {}).get("largura", 6.0)) * 0.5


## O ponto em terra mais perto do pedido, no chão.
func _terra_perto(ponto: Vector3) -> Vector3:
	if _world.is_on_land(ponto):
		return _world.ground_position(ponto, 0.02)
	for raio in [1.0, 2.0, 3.0, 4.5, 6.0]:
		for i in 12:
			var p: Vector3 = ponto + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 12.0) * raio
			if _world.is_on_land(p):
				return _world.ground_position(p, 0.02)
	return Vector3.INF


## Achados do mesmo lugar lado a lado, e não empilhados.
func _ao_lado(centro: Vector3, n: int) -> Vector3:
	if n == 0:
		return _terra_perto(centro)
	return _terra_perto(centro + Vector3.RIGHT.rotated(Vector3.UP, TAU * n / 5.0) * 1.6)


func _ponto_da_mata() -> Vector3:
	var praca: Vector3 = _world.ancoras.get("Praça", Vector3.ZERO)
	var casa: Vector3 = _world.ancoras.get("Casa de taipa", Vector3.INF)
	var chegada: Vector3 = _player.spawn_position
	var bicho := Vector3.INF
	if _luta != null and not _luta.criaturas.is_empty():
		bicho = _luta.criaturas[0]._ninho
	var melhor := Vector3.INF
	var melhor_d := INF
	var passos := int(BUSCA_RAIO / BUSCA_PASSO)
	for i in range(-passos, passos + 1):
		for j in range(-passos, passos + 1):
			var p := praca + Vector3(i * BUSCA_PASSO, 0.0, j * BUSCA_PASSO)
			var d := Vector2(p.x - praca.x, p.z - praca.z).length()
			if d >= melhor_d or not _world.na_mata_fechada(p) or not _world.is_on_land(p):
				continue
			if casa.is_finite() and Vector2(p.x - casa.x, p.z - casa.z).length() < LONGE_DE_CASA:
				continue
			if Vector2(p.x - chegada.x, p.z - chegada.z).length() < LONGE_DE_CASA:
				continue
			if bicho.is_finite() and Vector2(p.x - bicho.x, p.z - bicho.z).length() < LONGE_DO_BICHO:
				continue
			melhor = p
			melhor_d = d
	return _world.ground_position(melhor, 0.02) if melhor.is_finite() else Vector3.INF


# --- no chão ------------------------------------------------------------------

## O papel no chão: claro e pequeno, que é o que o jogador aprende a catar. O
## sinal é o mesmo papel em verde de água parada, e a carta em azul — as cores
## que o 2D dá às três (ver `Mundo._espalhar_sinais`).
const COR := {
	"cordel": Color(0.95, 0.9, 0.76),
	"sinal": Color(0.62, 0.92, 0.84),
	"carta": Color(0.72, 0.86, 1.0),
}

func _por(tipo: String, id: String, lugar: String, ponto: Vector3) -> void:
	if not ponto.is_finite():
		return
	var marca := MeshInstance3D.new()
	marca.name = "Achado_%s_%s" % [tipo, id]
	var folha := BoxMesh.new()
	folha.size = Vector3(0.34, 0.03, 0.26) if tipo != "carta" else Vector3(0.22, 0.03, 0.32)
	marca.mesh = folha
	var tinta := StandardMaterial3D.new()
	tinta.albedo_color = COR.get(tipo, Color.WHITE)
	tinta.emission_enabled = true
	tinta.emission = COR.get(tipo, Color.WHITE)
	tinta.emission_energy_multiplier = 0.55
	marca.material_override = tinta
	add_child(marca)
	marca.global_position = ponto + Vector3(0.0, 0.03, 0.0)
	marca.rotation.y = randf() * TAU
	no_chao.append({"tipo": tipo, "id": id, "lugar": lugar, "ponto": ponto, "no": marca})


func _process(_delta: float) -> void:
	if _player == null or _dica == null:
		return
	var camera := get_viewport().get_camera_3d()
	var em_jogo: bool = camera != null and camera == _player.get("camera") and _player.is_physics_processing()
	_conferir_a_oferta()
	var perto = mais_perto()
	if not em_jogo or perto == null:
		_dica.visible = false
		return
	var rotulo := ""
	match str(perto["tipo"]):
		"cordel": rotulo = _texto("dica_cordel")
		"sinal": rotulo = _texto("dica_sinal")
		"carta": rotulo = _texto("dica_carta")
		"pacto": rotulo = _texto("dica_pacto")
	DicaTecla.mostrar_em(_dica, camera, perto["ponto"] + Vector3(0.0, ALTURA_DICA, 0.0), rotulo)
	if perto["tipo"] == "sinal" and not _avisou_perto.has(perto["id"]):
		_avisou_perto[perto["id"]] = true
		_avisar(_texto("tem_alguma_coisa"))


## O achado (ou o pacto oferecido) ao alcance do jogador, ou null.
func mais_perto():
	var aqui: Vector3 = _player.global_position
	var melhor = null
	var melhor_d := ALCANCE
	if not oferta.is_empty():
		var d := _plano(oferta["ponto"] - aqui)
		if d <= melhor_d:
			melhor = {"tipo": "pacto", "id": oferta["id"], "ponto": oferta["ponto"]}
			melhor_d = d
	for achado in no_chao:
		var d := _plano(achado["ponto"] - aqui)
		if d <= melhor_d:
			melhor = achado
			melhor_d = d
	return melhor


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode != Atalhos.tecla("interagir") or not _player.is_physics_processing():
		return
	if interagir():
		get_viewport().set_input_as_handled()


## O E: pega o que está ao alcance, ou firma o pacto oferecido. Devolve false
## quando não havia nada — e o E segue para lápide e árvore.
func interagir() -> bool:
	var perto = mais_perto()
	if perto == null:
		return false
	match str(perto["tipo"]):
		"pacto":
			_firmar(str(perto["id"]))
		"cordel":
			_pegar_cordel(perto)
		"sinal":
			_pegar_sinal(perto)
		"carta":
			_pegar_carta(perto)
	return true


func _tirar(achado: Dictionary) -> void:
	no_chao.erase(achado)
	if is_instance_valid(achado["no"]):
		achado["no"].queue_free()


func _pegar_cordel(achado: Dictionary) -> void:
	var id := str(achado["id"])
	if not Colecao.achar("cordeis", id):
		return
	_tirar(achado)
	Audio.efeito("pegar")
	var dado := Colecao.dados("cordeis", id)
	_avisar(_texto("cordel") % [str(dado.get("titulo", id)), int(dado.get("valor", 0))])
	achou.emit("cordel", id)


func _pegar_sinal(achado: Dictionary) -> void:
	var id := str(achado["id"])
	if not Colecao.achar("sinais", id):
		return
	_tirar(achado)
	Audio.efeito("pegar")
	var falas: Array = Jogo.falas(Colecao.dados("sinais", id).get("sinal", []))
	falas.append(_texto("anotado"))
	_contar(falas)
	achou.emit("sinal", id)
	# E AGORA A CARTA ESTÁ ALI, onde o sinal estava.
	_espalhar_cartas()


func _pegar_carta(achado: Dictionary) -> void:
	var id := str(achado["id"])
	if not Cartas.aprender(id):
		return
	_tirar(achado)
	Audio.efeito("pegar")
	var falas: Array = Jogo.falas(Cartas.dados(id).get("prosa", []))
	if Cartas.natureza(id) == "pacto":
		falas.append_array(_termos_do_pacto(id))
		oferta = {"id": id, "ponto": achado["ponto"]}
	else:
		falas.append(_texto("aprendeu_ritual") % Cartas.nome(id))
	_contar(falas)
	achou.emit("carta", id)


## O preço ANTES do sim, como a conversa do pacto do 2D.
func _termos_do_pacto(id: String) -> Array:
	var dado := Cartas.dados(id)
	var conta: Array = []
	for item in dado.get("cobra", {}):
		conta.append("%d %s" % [int(dado["cobra"][item]), Catalogo.nome(str(item)).to_lower()])
	return [
		_texto("da") % str(dado.get("resumo", "")),
		_texto("cobra") % ", ".join(conta),
		_texto("um_de_cada_vez") if Cartas.pacto != "" else _texto("sem_pacto"),
		_texto("firmar_aqui") % Cartas.nome(id).to_lower(),
	]


func _firmar(id: String) -> void:
	oferta = {}
	var recusa := Cartas.firmar(id)
	if recusa != "":
		_avisar(recusa)
		return
	Audio.efeito("menu_confirma")
	_avisar(_texto("firmado") % Cartas.nome(id))
	achou.emit("pacto", id)


## Quem se afasta do lugar do pacto respondeu que não.
func _conferir_a_oferta() -> void:
	if oferta.is_empty():
		return
	if _plano(oferta["ponto"] - _player.global_position) > DESISTE:
		oferta = {}
		_avisar(_texto("outro_dia"))


# --- o que se lê --------------------------------------------------------------

func _avisar(texto: String) -> void:
	_fala += 1
	if _hud != null:
		_hud.set_notice(texto)


## Várias falas no aviso, uma depois da outra. Uma sequência nova cala a antiga.
func _contar(falas: Array) -> void:
	_fala += 1
	var esta := _fala
	for fala in falas:
		if esta != _fala or not is_inside_tree():
			return
		if _hud != null:
			_hud.set_notice(str(fala))
		await get_tree().create_timer(POR_FALA).timeout


static func _plano(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()
