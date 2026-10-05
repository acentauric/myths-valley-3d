extends Node3D
## A PONTE DO RIO GRANDE, QUE A FRENTE DA TRILHA LEVANTA (data/missoes_ponte.json).
##
## O rio grande é o rio do norte do mapa, raso de dar pé, e a ponte dele é a
## "Ponte" do KML, onde a Rua Principal o cruza (`world_builder._erguer_ponte`).
## No 2D ela caiu; no vale ela está de pé no modelo do Tripo, e não há arte de
## ponte caída. Então o estrago é o que não se vê de longe — a cheia de
## fevereiro comeu os esteios do meio —, e o que se vê é a CERCA nas duas
## cabeceiras, que o Pedro e o Seu Benedito pregaram. Gente atravessa no vau, ao
## lado (`Lugares` "vau"); pela ponte, ninguém.
##
## A obra `ponte_levantar` (obras.json, no J, ao pé da ponte) tira a cerca. Quem
## diz é o `Obras`, que vai no save: carregar uma partida de antes da obra põe a
## cerca de volta. É o trato do cercado do cemitério (`cemiterio_vale.gd`) ao
## contrário — lá a obra levanta a cerca, aqui a derruba —, com o lance de cerca
## feito do mesmo jeito: a cerca do catálogo esticada, com caixa de colisão, ou
## a procedural. Nada de arte nova.

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
	var largura_do_lance := _largura_da_cerca()
	for lado in [-1.0, 1.0]:
		var cabeceira: Vector3 = centro + ao_longo * ate_a_cabeceira * lado
		var a: Vector3 = cabeceira - atravessado * meia_largura
		var b: Vector3 = cabeceira + atravessado * meia_largura
		_cercas.append({"a": _mundo.ground_position(a), "b": _mundo.ground_position(b),
			"no": _lance(a, b, largura_do_lance)})
	_reassar()


func _descercar() -> void:
	var havia := not _cercas.is_empty()
	for cerca in _cercas:
		if is_instance_valid(cerca["no"]):
			(cerca["no"] as Node).queue_free()
	_cercas.clear()
	_cercada = false
	if havia:
		_reassar()


## O caminho dos moradores muda com a cerca: a malha se assa de novo.
func _reassar() -> void:
	var navegacao := get_tree().get_first_node_in_group("navegacao") if is_inside_tree() else null
	if navegacao != null:
		navegacao.reassar()


## Quanto mede um lance da cerca do catálogo.
func _largura_da_cerca() -> float:
	if not _mundo.estilo_tripo():
		return 1.0
	var prova := CatalogoAssets.instanciar("cerca", self, Vector3.ZERO, TAMANHO_DA_CERCA)
	if prova == null:
		return 1.0
	var largura: float = (prova.get_meta("limites") as AABB).size.x
	remove_child(prova)
	prova.free()
	return maxf(largura, 0.1)


## Um lance de `de` até `ate`: a cerca do catálogo esticada ao comprimento, com a
## caixa de colisão dele; ou a cerca procedural, que traz a dela.
func _lance(de: Vector3, ate: Vector3, largura_do_lance: float) -> Node3D:
	var rumo := Vector3(ate.x - de.x, 0.0, ate.z - de.z)
	var comprimento := rumo.length()
	var yaw := atan2(-rumo.z, rumo.x)
	var meio: Vector3 = _mundo.ground_position(de.lerp(ate, 0.5))
	var lance := Node3D.new()
	lance.name = "CercaDaPonte"
	add_child(lance)
	if _mundo.estilo_tripo():
		var cerca := CatalogoAssets.instanciar("cerca", lance, meio - Vector3(0, 0.06, 0), TAMANHO_DA_CERCA, yaw)
		if cerca != null:
			cerca.scale.x *= comprimento / largura_do_lance
			var corpo := StaticBody3D.new()
			corpo.name = "CercaColisao"
			var forma := CollisionShape3D.new()
			var caixa := BoxShape3D.new()
			caixa.size = Vector3(comprimento, ALTURA, GROSSURA)
			forma.shape = caixa
			corpo.add_child(forma)
			lance.add_child(corpo)
			corpo.global_position = meio + Vector3.UP * ALTURA * 0.5
			corpo.rotation.y = yaw
			return lance
	var mouroes := maxf(ceilf(comprimento / 1.65), 1.0)
	var cerca_proc := FloraReconcavo.cerca(comprimento, comprimento / mouroes - 0.0001)
	lance.add_child(cerca_proc)
	cerca_proc.global_position = _mundo.ground_position(de) - Vector3(0, 0.04, 0)
	cerca_proc.rotation.y = yaw
	return lance
