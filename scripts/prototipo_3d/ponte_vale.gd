extends Node3D
## A PONTE DO RIO GRANDE, QUE A FRENTE DA TRILHA LEVANTA (data/missoes_ponte.json).
##
## O rio grande é o rio do norte do mapa, fundo e com barranco na margem norte
## (#81, `GeoRegionRenderer` RIO GRANDE), e a ponte dele é a "Ponte" do KML,
## onde a Rua Principal o cruza (`world_builder._erguer_ponte`). No 2D ela caiu,
## e desde o #94 (06/10) cai aqui também: até a obra o vão mostra o modelo
## caído do Tripo — o vão do meio no chão, as tábuas quebradas — e o modelo de
## pé fica escondido, com o tabuleiro desligado (`_mostrar_caida`). A CERCA
## nas duas cabeceiras, que o Pedro e o Seu Benedito pregaram, continua: é ela
## que diz "não passe" a quem vem pela estrada. Fora da ponte ninguém passa: a
## água dá nado e a margem de lá não tem por onde subir; pela ponte, ninguém
## até a obra.
##
## A obra `ponte_levantar` (obras.json, no J, ao pé da ponte) tira a cerca. Quem
## diz é o `Obras`, que vai no save: carregar uma partida de antes da obra põe a
## cerca de volta. É o trato do cercado do cemitério (`cemiterio_vale.gd`) ao
## contrário — lá a obra levanta a cerca, aqui a derruba e põe a ponte de pé —,
## com o lance de cerca feito do mesmo jeito: a cerca do catálogo esticada, com
## caixa de colisão, ou a procedural.

const CONSTRUCAO := "ponte"
const OBRA := "ponte_levantar"
## A ponte que a obra conserta, pelo nome da âncora (`world_builder.pontes`).
const ANCORA := "Ponte"
## Quanto a cerca passa da largura da ponte, de cada lado, e a que distância da
## cabeceira ela fica, já no chão da estrada.
const SOBRA_DOS_LADOS := 0.6
const FORA_DA_CABECEIRA := 0.4
## O tamanho da cerca do catálogo, a grossura e a altura da colisão de um lance.
const TAMANHO_DA_CERCA := 1.0
const GROSSURA := 0.3
const ALTURA := 1.2
## De quanto em quanto tempo se confere a obra (a partida que volta do save).
const CONFERIR_A_CADA := 0.25

var _mundo
## {"centro", "ao_longo", "comprimento", "largura"}, ou vazio sem a ponte.
var _ponte: Dictionary = {}
var _cercada := false
## Cada cerca de pé: {"a", "b"} no chão, e o nó dela.
var _cercas: Array[Dictionary] = []
var _conferir_em := 0.0


func configurar(mundo) -> void:
	_mundo = mundo
	add_to_group("ponte_do_rio")
	var pontes = mundo.get("pontes")
	if pontes is Dictionary:
		_ponte = (pontes as Dictionary).get(ANCORA, {})
	# A obra feita tira a cerca NA HORA; a conferência de quarto em quarto de
	# segundo cobre o resto (a partida que volta).
	if not Obras.concluida.is_connected(_ao_concluir):
		Obras.concluida.connect(_ao_concluir)
	acertar()


func _exit_tree() -> void:
	if Obras.concluida.is_connected(_ao_concluir):
		Obras.concluida.disconnect(_ao_concluir)


func _ao_concluir(construcao: String, _obra: String) -> void:
	if construcao == CONSTRUCAO:
		acertar()


func _process(delta: float) -> void:
	_conferir_em -= delta
	if _conferir_em > 0.0:
		return
	_conferir_em = CONFERIR_A_CADA
	acertar()


## A PONTE COMO O JOGO DIZ QUE ELA ESTÁ: cercada até a obra. Para os dois lados
## — carregar uma partida de antes da obra põe a cerca de volta.
func acertar() -> void:
	if _ponte.is_empty():
		return
	var cercar := not Obras.ja_feita(CONSTRUCAO, OBRA)
	if cercar == _cercada:
		return
	if cercar:
		_cercar()
	else:
		_descercar()


## A ponte está fechada?
func interditada() -> bool:
	return _cercada


## As cercas de pé, cada uma {"a": Vector3, "b": Vector3} no chão.
func cercas() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for cerca in _cercas:
		lista.append({"a": cerca["a"], "b": cerca["b"]})
	return lista


## A ponte de que se fala: {"centro", "ao_longo", "comprimento", "largura"}.
func ponte() -> Dictionary:
	return _ponte.duplicate()


# --- a cerca -------------------------------------------------------------------

## UMA CERCA EM CADA CABECEIRA, atravessada na estrada, da largura da ponte e mais
## um pouco: quem vem pela estrada dá com ela, e quem quer passar desce ao vau.
func _cercar() -> void:
	_descercar()
	_cercada = true
	var centro: Vector3 = _ponte["centro"]
	var ao_longo: Vector3 = _ponte["ao_longo"]
	var atravessado := Vector3(-ao_longo.z, 0.0, ao_longo.x)
	var ate_a_cabeceira := float(_ponte["comprimento"]) * 0.5 + FORA_DA_CABECEIRA
	var meia_largura := float(_ponte["largura"]) * 0.5 + SOBRA_DOS_LADOS
	var tripo: bool = _mundo.estilo_tripo()
	var largura_do_lance: float = CatalogoAssets.largura_da_cerca(self, TAMANHO_DA_CERCA, 1.0) if tripo else 1.0
	for lado in [-1.0, 1.0]:
		# De ponta a ponta no chão, deitada na encosta da cabeceira (#93;
		# `CatalogoAssets.lance_de_cerca`).
		var cabeceira: Vector3 = centro + ao_longo * ate_a_cabeceira * lado
		var a: Vector3 = _mundo.ground_position(cabeceira - atravessado * meia_largura)
		var b: Vector3 = _mundo.ground_position(cabeceira + atravessado * meia_largura)
		_cercas.append({"a": a, "b": b,
			"no": CatalogoAssets.lance_de_cerca(self, a, b, tripo, TAMANHO_DA_CERCA, largura_do_lance, ALTURA, GROSSURA, "CercaDaPonte", "CercaColisao")})
	_mostrar_caida(true)
	_reassar()


func _descercar() -> void:
	var havia := not _cercas.is_empty()
	for cerca in _cercas:
		if is_instance_valid(cerca["no"]):
			(cerca["no"] as Node).queue_free()
	_cercas.clear()
	_cercada = false
	_mostrar_caida(false)
	if havia:
		_reassar()


## A PONTE CAÍDA OU DE PÉ (#94): até a obra, o que se vê no vão é o modelo caído
## do Tripo, e o de pé fica escondido com o tabuleiro desligado — ninguém anda
## por ele, nem morador pela malha; feita a obra, a de pé volta inteira. Sem os
## dois modelos (o estilo procedural), a ponte é a de sempre, só cercada.
func _mostrar_caida(caida: bool) -> void:
	var modelos: Dictionary = _ponte.get("modelos", {})
	if modelos.is_empty():
		return
	var de_pe: Node3D = modelos.get("de_pe")
	var a_caida: Node3D = modelos.get("caida")
	if is_instance_valid(de_pe):
		de_pe.visible = not caida
		for forma in de_pe.find_children("*", "CollisionShape3D", true, false):
			(forma as CollisionShape3D).disabled = caida
	if is_instance_valid(a_caida):
		a_caida.visible = caida


## A ponte está caída (até a obra) ou de pé?
func caida() -> bool:
	return _cercada and not (_ponte.get("modelos", {}) as Dictionary).is_empty()


## O caminho dos moradores muda com a cerca: a malha se assa de novo.
func _reassar() -> void:
	var navegacao := get_tree().get_first_node_in_group("navegacao") if is_inside_tree() else null
	if navegacao != null:
		navegacao.reassar()


