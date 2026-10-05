extends Node3D
## OS BICHOS DE CASA DO VALE (#28): monta, casa por casa, os cães, os gatos, os
## porcos, as cabras, o jumento e os bandos de aves do quintal, e comanda o nível
## de detalhe deles. Quem manda em quem mora onde é o `data/bichos_de_casa.json`
## (sem texto para o jogador): casa nova de morador só acrescenta uma linha lá.
##
## UMA LINHA DO JSON É UM BICHO OU UM BANDO:
##   - "rotina": "cao" | "gato" | "porco" | "solto" → um corpo de quatro patas
##     (`bicho_de_casa.gd`), `quantos` vezes;
##   - "rotina": "bando" → um terreiro com aves de chão (`bando_de_chao.gd`).
## A casa é uma âncora do mundo (`ancoras`), e os pontos são deslocamentos no
## referencial dela (porta no +Z). Casa que o vale não tem (ou ainda não tem) é
## pulada em silêncio: o mesmo JSON serve a todo estado do vale.
##
## O DONO é um morador pelo id (`dono`, na casa ou no bicho): o cão o acompanha, o
## gato do Tonho vai com ele ao píer. Os moradores sobem junto com o vale, e o Pedro
## é o guia; por isso o dono é procurado de tempos em tempos até aparecer, e o bicho
## sem dono (ainda) fica de casa.
##
## NÍVEL DE DETALHE pela distância à câmera (`ALCANCE`): longe, o bicho some, não
## anda e fica onde estaria (ver `perto` nos dois scripts). Cada bicho tem a sua
## histerese para não piscar na fronteira.

const BichoDeCasa = preload("res://scripts/prototipo_3d/bicho_de_casa.gd")
const BandoDeChao = preload("res://scripts/prototipo_3d/bando_de_chao.gd")
const Animador = preload("res://scripts/prototipo_3d/animador_bicho.gd")

const ARQUIVO := "res://data/bichos_de_casa.json"
## Até onde (u) da câmera os bichos andam e se veem, e a folga da histerese.
const ALCANCE := 80.0
const HISTERESE := 8.0
## De quanto em quanto tempo (s) se confere a distância, e se procura o dono.
const CONFERIR_A_CADA := 0.5
const PROCURAR_O_DONO_A_CADA := 1.0
## Dois bichos da mesma linha nascem a esta distância um do outro (u).
const ESPACO_DA_NINHADA := 0.55

## Os corpos de quatro patas e os bandos, na ordem do JSON.
var bichos: Array = []
var bandos: Array = []
## Linhas do JSON que o vale não pôde atender (casa sem âncora), para o portão.
var casas_puladas: Array[String] = []
var dados: Dictionary = {}

var _world: Node3D
var _jogador: Node3D
var _conferir_em := 0.0
var _procurar_em := 0.0
var _sem_dono := true


func _init(world: Node3D = null, jogador: Node3D = null) -> void:
	name = "BichosDeCasa"
	_world = world
	_jogador = jogador


func _ready() -> void:
	if _world == null:
		return
	if not bool(_world.get("construido")):
		await _world.pronto
	_montar()


func _montar() -> void:
	Animador.esquecer_as_casas()
	dados = _ler()
	var especies: Dictionary = dados.get("especies", {})
	for casa: Dictionary in dados.get("casas", []):
		var nome := str(casa.get("casa", ""))
		if not _world.ancoras.has(nome):
			casas_puladas.append(nome)
			continue
		var caes_da_casa: Array = []
		var gatos_da_casa: Array = []
		for linha: Dictionary in casa.get("bichos", []):
			if str(linha.get("rotina", "")) == "bando":
				_novo_bando(linha, especies, nome)
				continue
			var sp: Dictionary = especies.get(str(linha.get("especie", "")), {})
			if sp.is_empty():
				push_warning("BichosDeCasa: espécie sem dados: %s" % str(linha.get("especie", "")))
				continue
			for i in int(linha.get("quantos", 1)):
				var bicho := _novo_bicho(linha, sp, nome, str(casa.get("dono", "")), i)
				if str(linha.get("rotina", "")) == "cao":
					caes_da_casa.append(bicho)
				elif str(linha.get("rotina", "")) == "gato":
					gatos_da_casa.append(bicho)
		_ligar_os_da_casa(caes_da_casa, gatos_da_casa)


func _ler() -> Dictionary:
	var arquivo := FileAccess.open(ARQUIVO, FileAccess.READ)
	if arquivo == null:
		push_warning("BichosDeCasa: não achei %s" % ARQUIVO)
		return {}
	var lido = JSON.parse_string(arquivo.get_as_text())
	return lido if lido is Dictionary else {}


func _novo_bicho(linha: Dictionary, sp: Dictionary, casa: String, dono_da_casa: String, indice: int) -> Node:
	var bicho := BichoDeCasa.new()
	var preparada := linha.duplicate()
	if not preparada.has("dono") and str(preparada.get("rotina", "")) == "cao" and dono_da_casa != "":
		preparada["dono"] = dono_da_casa
	bicho.configurar(preparada, sp, casa, _world, _jogador)
	add_child(bicho)
	var ponto: Vector3 = bicho.lugar_de_casa()
	var lado := Vector3(float(indice) * ESPACO_DA_NINHADA, 0.0, 0.0).rotated(Vector3.UP, float(get_child_count()) * 2.4)
	bicho.global_position = _world.ground_position(ponto + lado, 0.02)
	bichos.append(bicho)
	return bicho


func _novo_bando(linha: Dictionary, especies: Dictionary, casa: String) -> void:
	var bando := BandoDeChao.new()
	bando.configurar(linha, especies, casa, _world, _jogador)
	add_child(bando)
	bandos.append(bando)


## O filhote segue o cão grande da casa; o gato foge dos cães da casa.
func _ligar_os_da_casa(caes: Array, gatos: Array) -> void:
	for cao in caes:
		var segue := str(cao.dados.get("segue", ""))
		if segue == "":
			continue
		for outro in caes:
			if outro != cao and str(outro.dados.get("especie", "")) == segue:
				cao.lider = outro
				break
	for gato in gatos:
		gato.caes = caes.duplicate()


# --- o quadro ----------------------------------------------------------------

func _process(delta: float) -> void:
	if _world == null:
		return
	_conferir_em -= delta
	if _conferir_em <= 0.0:
		_conferir_em = CONFERIR_A_CADA
		_conferir_a_distancia()
	if _sem_dono:
		_procurar_em -= delta
		if _procurar_em <= 0.0:
			_procurar_em = PROCURAR_O_DONO_A_CADA
			_ligar_os_donos()


## De onde se mede: a câmera que está desenhando (o sobrevoo do menu também), ou
## o jogador quando não há câmera.
func _ponto_de_vista() -> Vector3:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera != null:
		return camera.global_position
	return _jogador.global_position if _jogador != null else Vector3.INF


func _conferir_a_distancia() -> void:
	var olho := _ponto_de_vista()
	if not olho.is_finite():
		return
	for bicho in bichos:
		if is_instance_valid(bicho):
			bicho.perto = _perto(bicho.global_position, olho, bicho.perto)
			bicho.visible = bicho.perto
			bicho.fisica = _perto(bicho.global_position, olho, bicho.fisica, BichoDeCasa.FISICA_ATE)
	for bando in bandos:
		if is_instance_valid(bando):
			bando.perto = _perto(bando.centro, olho, bando.perto)
			bando.visible = bando.perto


static func _perto(onde: Vector3, olho: Vector3, estava_perto: bool, alcance: float = ALCANCE) -> bool:
	var d := Vector2(onde.x - olho.x, onde.z - olho.z).length()
	return d < (alcance + HISTERESE if estava_perto else alcance - HISTERESE)


## Liga cada bicho ao morador dono dele, quando o morador já existe.
func _ligar_os_donos() -> void:
	var faltam := false
	for bicho in bichos:
		if not is_instance_valid(bicho):
			continue
		var id := str(bicho.dados.get("dono", ""))
		if id == "" or (bicho.dono != null and is_instance_valid(bicho.dono)):
			continue
		var morador := morador_de(id)
		if morador != null:
			bicho.dono = morador
		else:
			faltam = true
	_sem_dono = faltam


## O morador pelo id (o Pedro, o guia, também é um `MoradorNPC` do grupo).
func morador_de(id: String) -> Node3D:
	for no in get_tree().get_nodes_in_group("moradores"):
		var d = no.get("dados")
		if d is Dictionary and str(d.get("id", "")) == id:
			return no as Node3D
	return null


## Quantos bichos há por espécie (o portão e a depuração perguntam).
func contagem() -> Dictionary:
	var por_especie := {}
	for bicho in bichos:
		var chave := str(bicho.chave)
		por_especie[chave] = int(por_especie.get(chave, 0)) + 1
	for bando in bandos:
		for ave in bando.aves:
			var chave: String = ave["chave"]
			por_especie[chave] = int(por_especie.get(chave, 0)) + 1
	return por_especie
