extends Node
## O QUE SE ACHA NO VALE: os cordéis, os sinais e as cartas do lugar do mito
## (#12). É o que o `Mundo` do 2D espalha (`_espalhar_cordeis`,
## `_espalhar_sinais`, `_espalhar_cartas`), com a mesma ordem das coisas:
##
## - O CORDEL está num lugar do arraial — o balcão do armazém, o banco da
##   capela, a ponta do píer —, PENDURADO NUM BARBANTE como na feira, com a
##   capa para fora. Pegar paga o troco e o guarda na coleção (L). Coisa que
##   se guarda na memória não entra na mochila.
## - O SINAL está onde o mito anda, e a CARTA ESPERA O SINAL: ela não está no
##   chão desde o primeiro dia; aparece onde o sinal estava, depois que o
##   jogador o viu, porque é ali que a coisa está.
## - A CARTA DE PACTO se firma NO LUGAR DO MITO, na conversa do 2D
##   (`Mundo._oferecer_pacto`): a prosa da carta, o que o pacto dá e o que
##   cobra, e a pergunta "Firmar?" na caixa de Sim e Não (#21). Dizer que não
##   deixa a carta com o jogador, e o painel (J) ainda firma depois, como no 2D.
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
const CapaDeCordel = preload("res://scripts/prototipo_3d/capa_de_cordel.gd")
const FocoDoE = preload("res://scripts/prototipo_3d/foco_do_e.gd")
const TEXTOS := "res://data/achados.json"

## Quão perto, no chão, para a tecla aparecer e o E valer.
const ALCANCE := 1.8
const ALTURA_DICA := 0.9
## Quanto cada fala fica no aviso antes da próxima.
const POR_FALA := 3.6

## ONDE CADA CORDEL ESTÁ NO VALE: a âncora do lugar que o `onde` dele descreve,
## e onde em volta dela. `diante` anda pela frente da construção a partir da
## beira dela; `lado` anda de lado; `piso` usa a altura da âncora em vez do
## chão (o píer fica sobre a água, e o chão ali é o fundo do mar); `desvio`
## anda em x e z a partir da âncora que não tem frente.
const CORDEIS := {
	"peso_falso": {"ancora": "Venda do Bar", "diante": 1.2},          # no balcão do armazém
	"vendeu_a_chuva": {"ancora": "Bar", "diante": -2.0, "lado": 3.2},   # no bar da praia, numa mesa
	# Na capela, AO LADO DA PORTA, e não diante dela: diante dela é onde se reza
	# (`marcos_da_fe.gd`), e o marco recebe o E primeiro — o folheto que ficava
	# a três palmos do lugar da reza não se pegava.
	"cachorro_do_enterro": {"ancora": "Capela velha", "diante": 1.2, "lado": -1.0},
	"missa_dos_afogados": {"ancora": "Cemitério"},                       # no cemitério
	# No mirante, na serra — AO PÉ dele, e não no meio: o meio é a caixa de
	# colisão do mirante, e o folheto ficava lá dentro, onde ninguém chegava.
	"porfia_do_caboclo": {"ancora": "Mirante", "desvio": [3.2, 0.0]},
	# No tabuado do píer, quatro passos para dentro e um de lado — e NÃO no ponto
	# do píer, que é onde o Tonho fica de manhã e de tarde, com o mestre Quirino a
	# um passo e o Pedro a dois: o cordel pendia dentro do Tonho, o E empatava
	# entre os dois, e não havia para onde virar ("Ao tentar interagir com o
	# cordel e tem um NPC próximo [...] não consigo clicar no cordel").
	# `no_pier` é [de lado, ao longo], no rumo do píer, como os postos de lá.
	"moleque_do_pier": {"ancora": "PierPiso", "piso": true, "no_pier": [0.9, -4.0]},
}
const CORDEIS_QUE_FALTAM := {
	"moca_da_agua": "na beira da lagoa, que o vale ainda não tem (#23)",
	"cabra_da_fazenda": "no vau do rio grande, debaixo da ponte: o vau chegou com a ponte (data/missoes_ponte.json), e o chão da margem para o folheto ainda não foi medido (#23)",
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
var _avisou_perto: Dictionary = {}
var _fala := 0


func configurar(world, player, hud, luta, hud_layer: Control) -> void:
	_world = world
	_player = player
	_hud = hud
	_luta = luta
	var lido = JSON.parse_string(FileAccess.get_file_as_string(TEXTOS))
	_textos = lido if lido is Dictionary else {}
	_dica = DicaTecla.criar(hud_layer, Atalhos.letra("interagir"), _texto("dica_cordel"))
	_dica.visible = false
	add_to_group(FocoDoE.GRUPO)
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
		var no_pier: Array = onde.get("no_pier", [0.0, 0.0])
		var direcao: Vector3 = _world.ancoras.get("PierDirecao", Vector3.FORWARD)
		var ao_lado := Vector3(float(no_pier[0]), 0.0, float(no_pier[1])).rotated(Vector3.UP, atan2(direcao.x, direcao.z))
		return base + ao_lado + Vector3(0.0, 0.02, 0.0)
	if onde.has("desvio"):
		var desvio: Array = onde["desvio"]
		return _terra_perto(base + Vector3(float(desvio[0]), 0.0, float(desvio[1])))
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
	if _luta != null:
		# Pela espécie, e não pela vez na lista: a mata tem mais de um bicho.
		for c in _luta.criaturas:
			if c.especie == "caititu":
				bicho = c._ninho
				break
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
	if tipo == "cordel":
		_por_cordel(id, ponto)
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
	_balancar_os_folhetos()
	var camera := get_viewport().get_camera_3d()
	var perto = mais_perto()
	if not _em_jogo() or perto == null or not FocoDoE.e_dele(self):
		_dica.visible = false
		return
	var rotulo := ""
	match str(perto["tipo"]):
		"cordel": rotulo = _texto("dica_cordel")
		"sinal": rotulo = _texto("dica_sinal")
		"carta": rotulo = _texto("dica_carta")
	var altura := ALTURA_DICA_CORDEL if str(perto["tipo"]) == "cordel" else ALTURA_DICA
	DicaTecla.mostrar_em(_dica, camera, perto["ponto"] + Vector3(0.0, altura, 0.0), rotulo)
	if perto["tipo"] == "sinal" and not _avisou_perto.has(perto["id"]):
		_avisou_perto[perto["id"]] = true
		_avisar(_texto("tem_alguma_coisa"))


# --- o cordel no barbante -------------------------------------------------------

## O CORDEL PENDURADO NO BARBANTE, como na feira: o folheto a cavalo na corda,
## com a capa para fora — a xilogravura desenhada para ele, ou o bloco de sempre
## enquanto ela não vem (`CapaDeCordel`) — e o verso do papel do outro lado. O
## papel claro no chão era o que o jogador aprendia a catar; pendurado, o
## folheto se anuncia como na feira, e a capa diz qual é.
##
## OS MOURÕES E A CORDA SÃO PEÇA PROVISÓRIA, cinza como a bancada da oficina: o
## catálogo ainda não tem a corda de cordel, e a mecânica não espera o modelo.
## Sem colisão — é marca, não parede —, e o giro é o primeiro em que os dois
## mourões não entram em coisa sólida: no cemitério o folheto fica entre duas
## covas, e atravessado o mourão furava a laje.
const BARBANTE_VAO := 0.9
const BARBANTE_ALTURA := 1.15
## A capa do folheto, um tanto maior que os 11 por 16 cm de verdade: do tamanho
## real, de longe, era um ponto claro e não um folheto.
const FOLHETO := Vector2(0.26, 0.41)
## A letra do título impresso no alto da capa (ver `_capa_de_feira`).
const FONTE_DO_TITULO := "res://assets/fonts/Cinzel-Variavel.ttf"
## O quanto cada metade do folheto se abre da vertical, a cavalo na corda.
const ABERTURA := 0.16
const ALTURA_DICA_CORDEL := 1.62
const COR_MOURAO := Color(0.52, 0.53, 0.52)
const COR_CORDA := Color(0.72, 0.62, 0.44)


func _por_cordel(id: String, ponto: Vector3) -> void:
	var suporte := Node3D.new()
	suporte.name = "Achado_cordel_%s" % id
	add_child(suporte)
	suporte.global_position = ponto
	suporte.rotation.y = _giro_livre(ponto)
	var cinza := StandardMaterial3D.new()
	cinza.albedo_color = COR_MOURAO
	for lado in [-1.0, 1.0]:
		var mourao := MeshInstance3D.new()
		mourao.name = "Mourao_a" if lado < 0.0 else "Mourao_b"
		var caixa := BoxMesh.new()
		caixa.size = Vector3(0.05, BARBANTE_ALTURA + 0.08, 0.05)
		mourao.mesh = caixa
		mourao.material_override = cinza
		suporte.add_child(mourao)
		mourao.position = Vector3(lado * BARBANTE_VAO * 0.5, (BARBANTE_ALTURA + 0.08) * 0.5, 0.0)
	# A corda barriga um pouco no meio, onde o folheto pesa.
	var barriga := Vector3(0.0, BARBANTE_ALTURA - 0.05, 0.0)
	for lado in [-1.0, 1.0]:
		var corda := _corda(Vector3(lado * BARBANTE_VAO * 0.5, BARBANTE_ALTURA, 0.0), barriga)
		corda.name = "Barbante_a" if lado < 0.0 else "Barbante_b"
		suporte.add_child(corda)
	var folheto := _folheto_pendurado(id)
	suporte.add_child(folheto)
	folheto.position = barriga
	no_chao.append({"tipo": "cordel", "id": id, "lugar": "", "ponto": ponto, "no": suporte,
		"folheto": folheto, "fase": float(absi(hash(id)) % 628) / 100.0})


## Um pedaço de barbante de `de` até `ate`, no referencial do suporte.
func _corda(de: Vector3, ate: Vector3) -> MeshInstance3D:
	var fio := MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = 0.007
	cilindro.bottom_radius = 0.007
	cilindro.height = de.distance_to(ate)
	cilindro.radial_segments = 5
	cilindro.rings = 1
	fio.mesh = cilindro
	var tinta := StandardMaterial3D.new()
	tinta.albedo_color = COR_CORDA
	fio.material_override = tinta
	# O cilindro nasce de pé; deita na direção da corda.
	fio.basis = Basis(Quaternion(Vector3.UP, (ate - de).normalized()))
	fio.position = (de + ate) * 0.5
	return fio


## O folheto a cavalo no barbante, aberto num V estreito a partir da corda — COM
## A CAPA DOS DOIS LADOS.
##
## "Coloque as imagens que geramos dos cordeis na capa dele no mundo, acho que
## ficará mais bonito que essa folha em branco." A xilogravura já ia de um lado,
## e o outro era o verso em papel liso: o barbante gira para os mourões caberem
## (`_giro_livre`), e quem chegava pelo lado do verso via uma folha em branco. Na
## banca da feira os folhetos pendem costas com costas, cada um com a sua capa —
## é o que fica. E a capa é a de folheto de verdade: o TÍTULO impresso no alto,
## em letra de forma, e a gravura no quadro de baixo.
func _folheto_pendurado(id: String) -> Node3D:
	var folheto := Node3D.new()
	folheto.name = "Folheto"
	for lado in [1.0, -1.0]:
		var capa := _capa_de_feira(id)
		capa.name = "Capa" if lado > 0.0 else "CapaDeTras"
		# O alto da folha na corda, e ela pendendo aberta para o seu lado.
		var giro := Basis(Vector3.RIGHT, -ABERTURA)
		if lado < 0.0:
			giro = Basis(Vector3.UP, PI) * giro
		capa.basis = giro
		capa.position = giro * Vector3(0.0, -FOLHETO.y * 0.5, 0.0)
		folheto.add_child(capa)
	return folheto


## UMA CAPA DE FOLHETO, virada para o +Z dela: o papel, o título no alto e a
## gravura no quadro de baixo (a xilogravura desenhada, ou o bloco de sempre
## enquanto ela não vem — `CapaDeCordel`).
func _capa_de_feira(id: String) -> Node3D:
	var capa := Node3D.new()
	var papel := MeshInstance3D.new()
	papel.name = "Papel"
	var folha := QuadMesh.new()
	folha.size = FOLHETO
	papel.mesh = folha
	papel.material_override = _papel_de_folheto(null, CapaDeCordel.PAPEL, 0.12)
	capa.add_child(papel)
	# A GRAVURA, na proporção dela (2 por 3), com a margem do papel em volta e a
	# faixa do título em cima.
	var margem := FOLHETO.x * 0.08
	var altura := minf((FOLHETO.x - margem * 2.0) * 1.5, FOLHETO.y * 0.72)
	var largura := altura / 1.5
	var gravura := MeshInstance3D.new()
	gravura.name = "Gravura"
	var quadro := QuadMesh.new()
	quadro.size = Vector2(largura, altura)
	gravura.mesh = quadro
	# Um pouco de luz própria, como o papel no chão tinha: na sombra da venda o
	# folheto ainda se acha. Pouco — mais que isso desbota a xilogravura.
	gravura.material_override = _papel_de_folheto(CapaDeCordel.textura(id), Color.WHITE, 0.08)
	gravura.position = Vector3(0.0, -FOLHETO.y * 0.5 + margem + altura * 0.5, 0.002)
	capa.add_child(gravura)
	# O TÍTULO, em letra de forma preta, centrado na faixa de cima.
	var faixa := FOLHETO.y - altura - margem * 2.0
	var titulo := Label3D.new()
	titulo.name = "Titulo"
	titulo.text = str(Colecao.dados("cordeis", id).get("titulo", "")).to_upper()
	titulo.modulate = CapaDeCordel.TINTA
	# O contorno na mesma tinta engrossa a letra: a variável da Cinzel vem fina, e
	# título de folheto é letra de forma carregada.
	titulo.outline_size = 5
	titulo.outline_modulate = CapaDeCordel.TINTA
	titulo.font_size = 40 if titulo.text.length() <= 18 else 30
	titulo.pixel_size = 0.0005
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulo.width = (FOLHETO.x - margem * 2.0) / titulo.pixel_size
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titulo.double_sided = false
	titulo.shaded = true
	if ResourceLoader.exists(FONTE_DO_TITULO):
		titulo.font = load(FONTE_DO_TITULO)
	titulo.position = Vector3(0.0, FOLHETO.y * 0.5 - margem * 0.5 - faixa * 0.5, 0.003)
	capa.add_child(titulo)
	return capa


func _papel_de_folheto(textura: Texture2D, cor: Color, luz_propria: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.roughness = 1.0
	if textura != null:
		material.albedo_texture = textura
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		material.emission_texture = textura
	else:
		material.albedo_color = cor
	material.emission_enabled = true
	material.emission = cor
	material.emission_energy_multiplier = luz_propria
	return material


## O vento da feira: cada folheto balança no seu compasso.
func _balancar_os_folhetos() -> void:
	var agora := float(Time.get_ticks_msec()) / 1000.0
	for achado in no_chao:
		var folheto = achado.get("folheto")
		if folheto != null and is_instance_valid(folheto):
			(folheto as Node3D).rotation.x = sin(agora * 1.4 + float(achado.get("fase", 0.0))) * 0.07


## O GIRO EM QUE OS DOIS MOURÕES CABEM: prova quatro e fica com o primeiro em
## que nenhum dos dois encosta em coisa sólida.
func _giro_livre(ponto: Vector3) -> float:
	if not is_inside_tree():
		return 0.0
	var espaco := get_viewport().world_3d.direct_space_state
	for giro in [0.0, PI * 0.5, PI * 0.25, PI * 0.75]:
		var livre := true
		for lado in [-1.0, 1.0]:
			var pe: Vector3 = ponto + Vector3(lado * BARBANTE_VAO * 0.5, 0.0, 0.0).rotated(Vector3.UP, giro)
			if mourao_encosta(espaco, pe, ponto.y):
				livre = false
				break
		if livre:
			return giro
	return 0.0


## O mourão em pé em `pe` atravessa alguma coisa sólida? Mede do chão dele — ou
## do piso, no píer — até a corda. Sólido é o que não anda: o Tonho em pé na
## ponta do píer não é parede.
func mourao_encosta(espaco: PhysicsDirectSpaceState3D, pe: Vector3, piso: float) -> bool:
	var base := maxf(piso, float(_world.ground_height_at(pe)))
	var pergunta := PhysicsShapeQueryParameters3D.new()
	var forma := CapsuleShape3D.new()
	forma.radius = 0.05
	forma.height = BARBANTE_ALTURA - 0.25
	pergunta.shape = forma
	pergunta.transform = Transform3D(Basis(), Vector3(pe.x, base + 0.2 + forma.height * 0.5, pe.z))
	pergunta.collision_mask = 1
	for toque in espaco.intersect_shape(pergunta, 8):
		if toque.get("collider") is StaticBody3D:
			return true
	return false


func _em_jogo() -> bool:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	return camera != null and camera == _player.get("camera") and _player.is_physics_processing()


## O QUE O E FARIA AQUI, para o foco (`foco_do_e.gd`): pegar o achado ao alcance.
func alvo_do_e() -> Dictionary:
	if _player == null or not _em_jogo():
		return {}
	var perto = mais_perto()
	return {} if perto == null else {"ponto": perto["ponto"]}


## O achado ao alcance do jogador, ou null.
func mais_perto():
	var aqui: Vector3 = _player.global_position
	var melhor = null
	var melhor_d := ALCANCE
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
	if not FocoDoE.e_dele(self):
		return
	if interagir():
		get_viewport().set_input_as_handled()


## O E: pega o que está ao alcance. Devolve false quando não havia nada — e o
## E segue para lápide e árvore.
func interagir() -> bool:
	var perto = mais_perto()
	if perto == null:
		return false
	match str(perto["tipo"]):
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
	achou.emit("carta", id)
	# A PROSA DA CARTA NA CAIXA DE FALA, como no 2D (`Mundo._pegar_a_carta`):
	# é o encontro com o mito, e não aviso de passagem.
	_fala += 1
	await Dialogo.falar("", Jogo.falas(Cartas.dados(id).get("prosa", [])))
	if Cartas.natureza(id) == "pacto":
		await _oferecer_pacto(id)
	else:
		_avisar(_texto("aprendeu_ritual") % Cartas.nome(id))


## A CONVERSA DO PACTO, a do 2D (`Mundo._oferecer_pacto`): o preço ANTES do
## sim, e a pergunta separada, para o jogador saber o que firma.
func _oferecer_pacto(id: String) -> void:
	await Dialogo.falar("", _termos_do_pacto(id))
	var sim: bool = await Dialogo.perguntar("", _texto("firmar") % Cartas.nome(id).to_lower())
	if not sim:
		await Dialogo.falar("", [_texto("outro_dia")])
		return
	_firmar(id)


func _termos_do_pacto(id: String) -> Array:
	var dado := Cartas.dados(id)
	var conta: Array = []
	for item in dado.get("cobra", {}):
		conta.append("%d %s" % [int(dado["cobra"][item]), Catalogo.nome(str(item)).to_lower()])
	return [
		_texto("da") % str(dado.get("resumo", "")),
		_texto("cobra") % ", ".join(conta),
		_texto("um_de_cada_vez") if Cartas.pacto != "" else _texto("sem_pacto"),
	]


func _firmar(id: String) -> void:
	var recusa := Cartas.firmar(id)
	if recusa != "":
		_avisar(recusa)
		return
	Audio.efeito("menu_confirma")
	_avisar(_texto("firmado") % Cartas.nome(id))
	achou.emit("pacto", id)


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
