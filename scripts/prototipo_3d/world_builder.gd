extends Node3D
## O vale de Bom Jesus dos Pobres: terreno geográfico (KML) + peças perto dos pontos de
## interesse. Toda peça é um GLB do catálogo (CatalogoAssets); se um GLB faltar, o
## mundo avisa com `push_error` e não constrói nada no lugar.
## O catálogo de regiões separa a escala horizontal (`scale_m_per_unit`) da
## exageração artística do relevo (`vertical_exaggeration`).

const PATH := Color("c5ad7a")
const WOOD := Color("735139")
const LEAVES := Color("487557")
const GeoRegionRenderer = preload("res://scripts/prototipo_3d/geo_region_renderer.gd")
const LuzesEpoca = preload("res://scripts/prototipo_3d/luzes_epoca.gd")
const Canoas = preload("res://scripts/prototipo_3d/canoas.gd")
const Cardume = preload("res://scripts/prototipo_3d/cardume.gd")
const Mar = preload("res://scripts/prototipo_3d/mar.gd")
const Camadas = preload("res://scripts/prototipo_3d/camadas.gd")
const CoqueiroCortado = preload("res://scripts/prototipo_3d/coqueiro_cortado.gd")
const MAP_CATALOG := "res://data/mapas/regioes.json"
const ComposicaoVale = preload("res://scripts/prototipo_3d/composicao_vale.gd")
const LombadaVale = preload("res://scripts/prototipo_3d/lombada_vale.gd")
const FazendaVale = preload("res://scripts/prototipo_3d/fazenda_vale.gd")
const RevoarVale = preload("res://scripts/prototipo_3d/revoar_vale.gd")
const CemiterioLayout = preload("res://scripts/prototipo_3d/cemiterio_layout.gd")
const TERREIRO_CASA := preload("res://scenes/prototipo_3d/terreiro_casa.tscn")
## Camada reservada para raycasts de interação com casas (bit 13 no inspetor).
const HOUSE_INTERACTION_LAYER := 1 << 12
const SITE_SEARCH_STEP := 1.5
const SITE_SEARCH_DIRECTIONS := 24
## Loteamento das casas ao longo das ruas: frente (a porta, +Z do modelo) para a rua,
## centro afastado do eixo o bastante para não invadir a rua, terreno quase plano.
const RECUO_DA_RUA := 1.6
const DESNIVEL_MAXIMO_CASA := 0.35
## Enterra discretamente as casas pequenas e seus alicerces no terreno inclinado.
const AFUNDAMENTO_CASAS_PEQUENAS := 0.18
const PASSO_NA_RUA := 2.5
const ALCANCE_NA_RUA := 60.0

signal house_interacted(properties: Dictionary)
signal house_interaction_cleared

var _materials: Dictionary = {}
var landmarks: Array[Dictionary] = []
var areas: Array[Dictionary] = []
## Chão de cada túmulo do cemitério, na ordem de data/lapides_3d.json.
var lapides: Array[Vector3] = []
## Tamanho da laje de cada túmulo (x, altura, z), para a colisão e para saber quem subiu.
var lapides_pegada: Array[Vector3] = []
## O desenho de cada túmulo, na mesma ordem: as lajes que a raiz levantou se
## entortam e se endireitam com a missão do Damião (`cemiterio_vale.gd`).
var tumulos: Array[Node3D] = []
var region_title := "Vale"
var _region = null
var _meters_per_unit := 1.0
var _vertical_exaggeration := 1.0
var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _environment: Environment
## Céu, névoa, sol e lua (ceu_vale.gd).
const CeuVale = preload("res://scripts/prototipo_3d/ceu_vale.gd")
var _ceu: CeuVale
var _luzes: Node3D
## Pontos de interesse e âncoras que os NPCs e as luzes usam (nome → posição no chão).
var ancoras: Dictionary = {}
var _house_targets: Array[Area3D] = []
var _hovered_house: Area3D
var _selected_house: Area3D
var _house_sites: Array[Dictionary] = []
## OS MARCOS DE FÉ QUE O MAPA NÃO TEM (#52), em metros no referencial do mapa,
## como as árvores de `_build_trees`. O lugar é o que o jogo 2D descreve:
##   terreiro   "sobe a estrada do mirante e, antes da curva, tem uma vereda de
##              pé saindo pro poente. Ela entra na mata e some" — uns setenta
##              metros a poente da rua, antes da curva grande dela.
##   gameleira  "na ponta do poente da praia, onde a estrada rareia" — no mato
##              da beira, perto das pedras.
const TERREIRO_M := Vector3(-262, 0, -238)
## Nome legível das espécies para os ids dos avulsos ("Mangueira 2").
const NOMES_DAS_ESPECIES := {
	"mangueira": "Mangueira", "cajueiro": "Cajueiro", "ipe_amarelo": "Ipê amarelo", "ipe_roxo": "Ipê roxo",
	"jaqueira": "Jaqueira", "embauba": "Embaúba", "dendezeiro": "Dendezeiro", "coqueiro": "Coqueiro",
}
const GAMELEIRA_M := Vector3(-300, 0, 560)
## O VÃO NORTE DO SOBREVOO DO MENU, em metros no mesmo referencial: onde o voo
## gravado (`data/sobrevoo_menu.json`), aos 7 s, cruza a fileira do manguezal da
## foz na ida do píer para a praça. A fileira não planta tronco a menos de 10 m
## dele (`GeoRegionRenderer.vaos_do_sobrevoo`). Replanejou o voo por outro vão?
## Mude este ponto junto, ou tire-o se o voo não cruzar mais a fileira.
const VAO_NORTE_DO_SOBREVOO_M := Vector3(294, 0, -50)
var _fogo_do_terreiro: Node3D

## AS CLAREIRAS DOS LUGARES NOVOS DAS FRENTES DO 2D, em unidades: a lombada da lapa
## (o alto e o corredor da rampa), a chapada do Seu Benedito (o alto e a beira de
## frente para o rio) e a fazenda do convite. Os três caíam no meio da mata — onze a catorze troncos a
## menos de 12 u —, e tronco atravessando pedra é o que se vê primeiro.
func _clareiras_das_frentes() -> Array[Vector2]:
	var lombada := Vector2(LombadaVale.CENTRO_M.x, LombadaVale.CENTRO_M.z) / _meters_per_unit
	var chapada := Vector2(CHAPADA_DO_BENEDITO_M.x, CHAPADA_DO_BENEDITO_M.z) / _meters_per_unit
	var lista: Array[Vector2] = [lombada + Vector2(2.0, 0.0), lombada + Vector2(LombadaVale.PE_DA_RAMPA, 0.0),
		chapada, chapada + Vector2(1.0, -11.0)]
	# E A FAZENDA: o portão e a guarita, o pátio e o casarão (`FazendaVale.CLAREIRAS_M`).
	for ponto: Vector2 in FazendaVale.CLAREIRAS_M:
		lista.append(ponto / _meters_per_unit)
	# E AS RUÍNAS DO PALACETE, a torre e a estátua do capítulo 7 (`RevoarVale.CLAREIRAS_M`, #31).
	for ponto: Vector2 in RevoarVale.CLAREIRAS_M:
		lista.append(ponto / _meters_per_unit)
	return lista


## Lote (posição e giro) de cada construção nomeada, decidido por _loteamento().
var _lotes: Dictionary = {}
## O MODELO E A COLISÃO INTEIRA de cada construção com nome:
## nome -> {"modelo": Node3D, "colisao": StaticBody3D}. O cômodo de dentro
## (`interiores.gd`) os acha por aqui, e não pelo nome do nó: há várias casas
## de taipa no vale, e o Godot renomeia as repetidas.
var construcoes: Dictionary = {}
## AS PONTES, pela âncora: {"centro", "ao_longo" (de cabeceira a cabeceira),
## "comprimento", "largura"}. Quem cerca a do rio grande até a obra a lê daqui
## (`ponte_vale.gd`).
var pontes: Dictionary = {}
## A importação inicial pode ignorar a cena, mas uma partida sempre lê a autoria.
var ignorar_composicao := false
var caminho_composicao := ComposicaoVale.CENA
var _casas_autorais: Dictionary = {}
## Objetos avulsos (fora das casas) da composição: id -> dados autorais.
var _avulsos_autorais: Dictionary = {}
## O editor já criou o grupo Avulsos: o que não está lá foi apagado pelo autor.
var _avulsos_criados := false
var _avulsos_usados: Dictionary = {}
var _avulsos_grupos: Array = []
## Onde cada avulso ficou de fato (semente do editor, portões e depuração).
var avulsos_montados: Dictionary = {}
## Modelos que o editor mostra como referência, sem editar (as pontes).
var referencias_montadas: Array = []
## Usado só pela semente: monta os avulsos nas posições do código.
var ignorar_avulsos := false
## Registros do resultado real, usados somente pela ferramenta de primeira extração.
var construcoes_editaveis: Dictionary = {}
## Montagem aos poucos: o vale é erguido ao longo de vários quadros, com o progresso
## (0 a 1) e a etapa avisados à tela de carregamento (tela_carregamento.gd), e
## `pronto` no fim. Quem depende do mundo espera `construido`/`pronto`.
signal progresso(fracao: float, etapa: String)
signal pronto
var construido := false
## Árvores plantadas uma a uma (_arvore): espécie, posição e raio do tronco.
var _arvores_nomeadas: Array[Dictionary] = []
var _terreiro: Material
var _manual_tree_sites: Array[Dictionary] = []


func get_meters_per_unit() -> float:
	return _meters_per_unit


## Converte um deslocamento medido em metros reais para unidades da cena.
func _u(meters: Vector3) -> Vector3:
	return meters / _meters_per_unit


func ground_height_at(position: Vector3) -> float:
	return _region.ground_height_at(position) if _region else 0.0


func ground_position(position: Vector3, offset_y: float = 0.0) -> Vector3:
	return _region.ground_position(position, offset_y) if _region else position + Vector3(0, offset_y, 0)


func _footprint_range(position: Vector3, radius: float) -> Vector2:
	var center_height := ground_height_at(position)
	var lowest := center_height
	var highest := center_height
	for index in range(16):
		var angle := TAU * float(index) / 16.0
		var edge := position + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		var height := ground_height_at(edge)
		lowest = minf(lowest, height)
		highest = maxf(highest, height)
	return Vector2(lowest, highest)


func _footprint_height(position: Vector3, radius: float) -> float:
	return _footprint_range(position, radius).y


## Mede o terreno sob toda a base retangular da casa, já com o giro do modelo.
## O círculo do lote serve para achar espaço livre, mas alcança pontos fora da
## construção e pode deixar a casa suspensa quando o terreno sobe ali.
func _house_ground_range(position: Vector3, footprint: Vector2, yaw: float) -> Vector2:
	var lowest := INF
	var highest := -INF
	for ix in range(5):
		for iz in range(5):
			var local := Vector2((float(ix) / 4.0 - 0.5) * footprint.x, (float(iz) / 4.0 - 0.5) * footprint.y).rotated(-yaw)
			var sample := ground_height_at(Vector3(position.x + local.x, 0.0, position.z + local.y))
			lowest = minf(lowest, sample)
			highest = maxf(highest, sample)
	return Vector2(lowest, highest)


## Apoia a casa no ponto mais alto sob sua base e estende o alicerce até o
## ponto mais baixo. A pequena sobreposição esconde a junta entre modelo e base.
func _support_house(position: Vector3, footprint: Vector2, yaw: float, chave: String = "", altura_autoral_padrao: Variant = null, deslocamento_y: float = 0.0, ajustes: Dictionary = {}) -> Vector3:
	# Padrão null em vez de NaN: NaN como padrão quebra o JSON do LSP do editor.
	var altura_autoral: float = NAN if altura_autoral_padrao == null else float(altura_autoral_padrao)
	var church := chave == "igreja"
	var base_margin := AlicerceConstrucao.margem(church, ajustes)
	var heights := _house_ground_range(position, footprint + Vector2.ONE * base_margin, yaw)
	var bury := AFUNDAMENTO_CASAS_PEQUENAS if chave in ["casa_taipa", "casa_carro_quebrado"] else 0.0
	var placed := Vector3(position.x, heights.y + 0.02 - bury, position.z)
	if is_finite(altura_autoral):
		placed.y = altura_autoral
	placed.y += deslocamento_y
	# Alicerce, borda e escadaria vêm da fonte compartilhada com a prévia do editor.
	for caixa in AlicerceConstrucao.caixas(ground_height_at, placed, footprint, yaw, church, ajustes):
		var material: Material = _terreiro_material() if caixa["tipo"] == "alicerce" and not church else null
		_box(caixa["size"], caixa["center"], caixa["cor"], true, material, yaw)
	return placed


func _remember_house_position(name: String, position: Vector3, yaw: float) -> void:
	if name.is_empty():
		return
	ancoras[name] = position
	ancoras[name + "Frente"] = Vector3(sin(yaw), 0.0, cos(yaw))
	if name == "Venda do Bar":
		ancoras["Bar"] = position
		ancoras["BarFrente"] = ancoras[name + "Frente"]
	if _lotes.has(name):
		var lot: Dictionary = _lotes[name]
		lot["pos"] = position
		_lotes[name] = lot


func get_spawn_position() -> Vector3:
	return _region.get_spawn_position() if _region else Vector3(0, 0.05, 0)


func get_map_bounds() -> Rect2:
	return _region.get_map_bounds() if _region else Rect2(-1200, -1300, 1800, 1950)


func get_map_frame() -> Rect2:
	return _region.get_map_frame() if _region else get_map_bounds()


func has_map_frame() -> bool:
	return _region != null and _region.has_map_frame()


func surface_at(world_position: Vector3) -> String:
	return _region.surface_at(world_position) if _region else "grama"


func is_walkable_point(world_position: Vector3) -> bool:
	return _region != null and _region.is_walkable_point(world_position)


## O CACHE de `arvores()`: eram 3 mil dicionários novos a cada chamada, e os bandos
## de chão e o porco chamam várias vezes. A lista se refaz sozinha quando o número
## de árvores muda (a mata, a orla e o paisagismo plantam aos poucos) e é
## invalidada a cada corte, crescimento e restauração, que mexem na árvore.
var _cache_das_arvores: Array[Dictionary] = []
var _cache_das_arvores_valido := false
var _cache_das_arvores_nomeadas := -1
var _cache_das_arvores_troncos := -1


## Terra firme do mapa (fora do mar, passarelas e píer).
## Todas as árvores do vale (plantadas e da mata/orla): espécie, posição no chão e raio
## aproximado do tronco. É a lista do cache: quem chama só LÊ a lista e os itens
## dela, não os altera.
func arvores() -> Array[Dictionary]:
	var troncos: int = _region._tree_trunks.size() if _region else 0
	if _cache_das_arvores_valido and _cache_das_arvores_nomeadas == _arvores_nomeadas.size() and _cache_das_arvores_troncos == troncos:
		return _cache_das_arvores
	var lista: Array[Dictionary] = _arvores_nomeadas.duplicate()
	if _region:
		for tronco: Dictionary in _region._tree_trunks:
			var ponto: Vector2 = tronco["point"]
			lista.append({"especie": String(tronco.get("especie", "")), "pos": Vector3(ponto.x, float(tronco["ground"]), ponto.y), "raio": float(tronco["radius"])})
	_cache_das_arvores = lista
	_cache_das_arvores_nomeadas = _arvores_nomeadas.size()
	_cache_das_arvores_troncos = troncos
	_cache_das_arvores_valido = true
	return _cache_das_arvores


## CORTA A ÁRVORE que tem o pé neste ponto — qualquer espécie, plantada à mão
## (`_arvore`) ou da mata, da orla e da beira do rio (`_region`). O visual
## some, a colisão sai, e no lugar fica o toco: a malha da própria árvore
## recortada na altura do golpe (`CoqueiroCortado`, que nasceu para o coqueiro
## e recorta qualquer malha). Devolve false se não há árvore de pé ali.
##
## `deixar_toco` falso é para a carga da partida, quando a árvore já passou do
## toco: recortar a malha só para jogá-la fora no mesmo quadro é o passo caro.
## `cair_para` é o lado para onde ela tomba (`CoqueiroCortado.derrubar`), longe
## de quem cortou; vazio, ela some sem cair, como na carga.
func cortar_arvore(posicao: Vector3, deixar_toco: bool = true, cair_para: Vector3 = Vector3.ZERO) -> bool:
	_cache_das_arvores_valido = false
	var indice := _indice_da_nomeada(posicao, false)
	if indice < 0:
		return _region.cortar_arvore(posicao, deixar_toco, cair_para) if _region != null else false
	var arvore: Dictionary = _arvores_nomeadas[indice]
	var original := arvore.get("visual") as Node3D
	if original == null:
		return false
	var pe: Vector3 = arvore["pos"]
	if deixar_toco:
		var partes: Array[Dictionary] = []
		if original is MeshInstance3D:
			partes.append(_parte_da_arvore(original as MeshInstance3D))
		for filho in original.find_children("*", "MeshInstance3D", true, false):
			partes.append(_parte_da_arvore(filho as MeshInstance3D))
		var toco: Node3D = CoqueiroCortado.criar(partes, pe, float(arvore["raio"]))
		if toco == null:
			return false
		add_child(toco)
		toco.global_position = pe
		arvore["toco"] = toco
		if cair_para != Vector3.ZERO:
			_derrubar_a_copa(partes, toco, pe, cair_para)
	original.visible = false
	_colisao_da_nomeada(arvore, false)
	arvore["transformacao_original"] = original.transform
	arvore["cortado"] = true
	_arvores_nomeadas[indice] = arvore
	return true


## A ÁRVORE CORTADA CRESCE DE NOVO. `escala` é o tamanho de agora, de 0 (só o
## toco) até perto de 1; adulta, quem chama passa a `restaurar_arvore`.
##
## A muda e a árvore nova são a malha da PRÓPRIA árvore, menor, crescendo a
## partir do pé: nenhuma peça nova, e nenhuma de outro estilo — a regra dos
## dois estilos vale também para o que cresce. Sem colisão até ficar adulta:
## muda não barra ninguém, e a colisão da adulta não cabe na nova.
func crescer_arvore(posicao: Vector3, escala: float) -> bool:
	_cache_das_arvores_valido = false
	var indice := _indice_da_nomeada(posicao, true)
	if indice < 0:
		return _region.crescer_arvore(posicao, escala) if _region != null else false
	var arvore: Dictionary = _arvores_nomeadas[indice]
	var original := arvore.get("visual") as Node3D
	if original == null:
		return false
	if escala <= 0.0:
		original.visible = false
		return is_instance_valid(arvore.get("toco"))
	var toco = arvore.get("toco")
	if is_instance_valid(toco):
		(toco as Node3D).queue_free()
	arvore.erase("toco")
	# CRESCE DO PÉ: a árvore inteira encolhe em volta do ponto de plantio. Nas
	# peças de hoje a origem do nó já cai ali — `CatalogoAssets.instanciar`
	# assenta o fundo da caixa no pé (medido em 03/10/2026, a seis centímetros,
	# que são o afundamento) —, mas a conta não depende disso: peça girada ou de
	# origem fora do fundo cresceria longe do toco.
	var pe: Vector3 = original.get_parent().to_local(arvore["pos"])
	var inteira: Transform3D = arvore.get("transformacao_original", original.transform)
	original.transform = Transform3D(Basis().scaled(Vector3.ONE * escala), pe * (1.0 - escala)) * inteira
	original.visible = true
	arvore["escala"] = escala
	_arvores_nomeadas[indice] = arvore
	return true


## A ÁRVORE VOLTA A SER ADULTA: o tamanho de antes do corte, a colisão de volta
## e o toco (se ainda houver) fora.
func restaurar_arvore(posicao: Vector3) -> bool:
	_cache_das_arvores_valido = false
	var indice := _indice_da_nomeada(posicao, true)
	if indice < 0:
		return _region.restaurar_arvore(posicao) if _region != null else false
	var arvore: Dictionary = _arvores_nomeadas[indice]
	var original := arvore.get("visual") as Node3D
	if original == null:
		return false
	original.transform = arvore.get("transformacao_original", original.transform)
	original.visible = true
	var toco = arvore.get("toco")
	if is_instance_valid(toco):
		(toco as Node3D).queue_free()
	_colisao_da_nomeada(arvore, true)
	arvore["cortado"] = false
	arvore.erase("toco")
	arvore.erase("escala")
	arvore.erase("transformacao_original")
	_arvores_nomeadas[indice] = arvore
	return true


## A COPA CAI do toco para `cair_para`: a árvore de cima do corte, girando em
## volta do eixo do tronco na altura dele (ver `CoqueiroCortado.copa`).
func _derrubar_a_copa(partes: Array[Dictionary], toco: Node3D, pe: Vector3, cair_para: Vector3) -> void:
	var eixo: Vector2 = toco.get_meta("eixo", Vector2.ZERO)
	var pivo := pe + Vector3(eixo.x, float(toco.get_meta("altura", CoqueiroCortado.ALTURA_DO_TOCO)), eixo.y)
	var copa := CoqueiroCortado.copa(partes, pivo)
	if copa != null:
		CoqueiroCortado.derrubar(copa, self, pivo, cair_para)


## A árvore plantada à mão com o pé neste ponto, cortada ou de pé, ou -1.
func _indice_da_nomeada(posicao: Vector3, cortada: bool) -> int:
	var ponto := Vector2(posicao.x, posicao.z)
	for indice in range(_arvores_nomeadas.size()):
		var arvore: Dictionary = _arvores_nomeadas[indice]
		if bool(arvore.get("cortado", false)) != cortada:
			continue
		var pe: Vector3 = arvore["pos"]
		if Vector2(pe.x, pe.z).distance_squared_to(ponto) <= 0.01:
			return indice
	return -1


func _colisao_da_nomeada(arvore: Dictionary, ligada: bool) -> void:
	var corpo := arvore.get("colisao") as StaticBody3D
	if corpo == null:
		return
	for filho in corpo.get_children():
		if filho is CollisionShape3D:
			(filho as CollisionShape3D).set_deferred("disabled", not ligada)


func _parte_da_arvore(instancia: MeshInstance3D) -> Dictionary:
	var materiais: Array[Material] = []
	if instancia.mesh != null:
		for superficie in range(instancia.mesh.get_surface_count()):
			materiais.append(instancia.get_active_material(superficie))
	return {"mesh": instancia.mesh, "transform": instancia.global_transform, "materiais": materiais}


## Nível atual da superfície do mar: a preamar da região mais o deslocamento da maré.
func water_level() -> float:
	if _region == null:
		return -INF
	var preamar: float = _region.water_level()
	return (preamar + Mare.nivel_offset()) if is_finite(preamar) else -INF


## O rio acompanha o relevo e tem nível local; o mar continua seguindo a maré.
func water_level_at(world_position: Vector3) -> float:
	if _region != null:
		var river_level: float = _region.river_water_level_at(world_position)
		if is_finite(river_level):
			return river_level
	return water_level()


## Lâmina d'água (unidades) sobre o leito do rio ou do mar no ponto.
## O rio segue o relevo; o mar acompanha a maré.
func water_depth_at(world_position: Vector3) -> float:
	if _region != null:
		var river_depth: float = _region.river_water_depth_at(world_position)
		if river_depth > 0.0:
			return river_depth
	if not is_finite(water_level()):
		return 0.0
	var lamina := Mar.lamina_em(Vector2(world_position.x, world_position.z))
	if is_nan(lamina):
		return 0.0
	return maxf(lamina / _meters_per_unit + Mare.nivel_offset(), 0.0)


## Fundo do mar que a baixa-mar deixou de fora: tinha água na preamar, agora não tem.
func fundo_exposto(world_position: Vector3) -> bool:
	if _region == null or not is_finite(_region.water_level()):
		return false
	var lamina := Mar.lamina_em(Vector2(world_position.x, world_position.z))
	if is_nan(lamina) or lamina <= 0.0:
		return false
	return lamina / _meters_per_unit + Mare.nivel_offset() <= 0.0


func is_on_land(world_position: Vector3) -> bool:
	return _region != null and _region._is_on_land(world_position)


## Mata fechada: dentro do polígono da mata (o do KML quando existe, senão o
## cênico) e a mais de 25 unidades da Praça, para o clima de tensão não pegar
## a beirada da vila.
func na_mata_fechada(world_position: Vector3) -> bool:
	if _region == null:
		return false
	var poligono: PackedVector2Array = _region._kml_forest if _region._kml_forest.size() >= 3 else _region._forest
	if poligono.size() < 3:
		return false
	var ponto := Vector2(world_position.x, world_position.z)
	if not Geometry2D.is_point_in_polygon(ponto, poligono):
		return false
	var praca: Vector3 = ancoras.get("Praça", _region.get_feature_center("Praça", "poi"))
	return Vector2(praca.x, praca.z).distance_to(ponto) > 25.0


## Rotação (yaw) que alinha o eixo X local — o comprimento da ponte no modelo —
## com a rua mais próxima do ponto, para a ponte seguir a rua sobre o rio.
func _road_yaw_at(point: Vector3) -> float:
	if _region == null:
		return 0.0
	var target := Vector2(point.x, point.z)
	var best := INF
	var direction := Vector2.RIGHT
	for road in _region.get("_roads"):
		var points: PackedVector2Array = road.points
		for i in range(points.size() - 1):
			var segment := points[i + 1] - points[i]
			if segment.length_squared() < 0.000001:
				continue
			var closest := Geometry2D.get_closest_point_to_segment(target, points[i], points[i + 1])
			var distance := closest.distance_squared_to(target)
			if distance < best:
				best = distance
				direction = segment.normalized()
	# Girar yaw leva o X local para (cos yaw, -sen yaw) no plano XZ.
	return atan2(-direction.y, direction.x)


## A travessia do rio central não tinha marcador no KML. Usa as linhas já
## suavizadas que desenham a Rua Principal e a água para achar o encontro real.
func _central_road_river_crossing() -> Vector3:
	var found := false
	var best := INF
	var point := Vector2.ZERO
	for road in _region._roads:
		if String(road.name) != "Rua Principal":
			continue
		var road_points: PackedVector2Array = road.points
		for river in _region._rivers:
			if _region._is_northern_river(river):
				continue
			var river_points: PackedVector2Array = river.points
			for i in range(road_points.size() - 1):
				for j in range(river_points.size() - 1):
					var crossing: Variant = Geometry2D.segment_intersects_segment(
						road_points[i], road_points[i + 1], river_points[j], river_points[j + 1])
					if not (crossing is Vector2):
						continue
					var candidate: Vector2 = crossing
					var distance := candidate.length_squared()
					if not found or distance < best:
						point = candidate
						best = distance
						found = true
	return Vector3(point.x, 0.0, point.y) if found else Vector3.INF


## O raycast deve usar HOUSE_INTERACTION_LAYER e collide_with_areas = true.
func get_house_properties(collider: Object) -> Dictionary:
	var house := _house_from_collider(collider)
	if house == null:
		return {}
	return (house.get_meta("house_properties") as Dictionary).duplicate(true)


func format_house_properties(properties: Dictionary) -> String:
	var point: Vector3 = properties["position"]
	return "%s\nObjeto: %s\nPosição: X %s · Y %s · Z %s\nEstilo: %s" % [properties["name"], properties["object_key"], str(snappedf(point.x, 0.01)), str(snappedf(point.y, 0.01)), str(snappedf(point.z, 0.01)), properties["style"]]


## Mostra apenas o nome e a dica de interação enquanto o cursor está sobre a casa.
func set_hovered_house(collider: Object) -> void:
	var house := _house_from_collider(collider)
	if house == _hovered_house:
		return
	var previous := _hovered_house
	_hovered_house = house
	if is_instance_valid(previous):
		_update_house_label(previous)
	if house != null:
		_update_house_label(house)


## Clique esquerdo: mantém o balão de propriedades aberto para a casa escolhida.
func interact_with_house(collider: Object) -> void:
	var house := _house_from_collider(collider)
	if house == null:
		return
	var previous := _selected_house
	_selected_house = house
	if is_instance_valid(previous):
		_update_house_label(previous)
	_update_house_label(house)
	house_interacted.emit(get_house_properties(house))


func clear_house_interaction() -> void:
	var previous_hover := _hovered_house
	var previous_selected := _selected_house
	_hovered_house = null
	_selected_house = null
	if is_instance_valid(previous_hover):
		_update_house_label(previous_hover)
	if is_instance_valid(previous_selected) and previous_selected != previous_hover:
		_update_house_label(previous_selected)
	if is_instance_valid(previous_selected):
		house_interaction_cleared.emit()


## Um ponto livre junto à construção; Vector3.INF indica alvo sem acesso por terra.
func get_house_destination(collider: Object, from_position: Vector3 = Vector3.ZERO) -> Vector3:
	var house := _house_from_collider(collider)
	if house == null or not is_walkable_point(house.global_position):
		return Vector3.INF
	var bounds: Vector3 = house.get_meta("house_bounds")
	var margin := 1.2
	var candidates: Array[Vector3] = [
		Vector3(0, 0, bounds.z * 0.5 + margin),
		Vector3(0, 0, -bounds.z * 0.5 - margin),
		Vector3(bounds.x * 0.5 + margin, 0, 0),
		Vector3(-bounds.x * 0.5 - margin, 0, 0),
	]
	var result := Vector3.INF
	var best_distance := INF
	for offset in candidates:
		var candidate := house.to_global(offset)
		candidate.y = ground_height_at(candidate) + 0.08
		if not is_walkable_point(candidate):
			continue
		var distance := candidate.distance_squared_to(from_position)
		if distance < best_distance:
			best_distance = distance
			result = candidate
	return result


func get_feature_center(feature_name: String, kind: String = "") -> Vector3:
	return _region.get_feature_center(feature_name, kind) if _region else Vector3.ZERO


func get_region_title() -> String:
	return region_title


func _enter_tree() -> void:
	add_to_group("mundo")


func _ready() -> void:
	# A cena persistida deixa o relevo visível no editor. Em execução ela sai antes
	# da montagem para a região real continuar sendo a única fonte de colisão e arte.
	var terreno_editor := get_node_or_null("TerrenoEditor")
	if terreno_editor != null:
		terreno_editor.queue_free()
	_montar()


func _montar() -> void:
	# Escondido enquanto monta: os quadros cedidos à tela de carregamento não gastam
	# tempo desenhando o vale pela metade atrás dela.
	visible = false
	if not ignorar_composicao:
		_casas_autorais = ComposicaoVale.ler(caminho_composicao)
		if not ignorar_avulsos:
			var avulsos: Dictionary = ComposicaoVale.ler_avulsos(caminho_composicao)
			_avulsos_autorais = avulsos.get("itens", {})
			_avulsos_criados = bool(avulsos.get("criados", false))
			_avulsos_grupos = avulsos.get("grupos", [])
	_build_lighting()
	var region_data := _active_region_data()
	if region_data.is_empty():
		_concluir()
		return
	region_title = String(region_data.get("title", region_data.get("id", "Vale")))
	_meters_per_unit = maxf(float(region_data.get("scale_m_per_unit", 1.0)), 0.01)
	_vertical_exaggeration = maxf(float(region_data.get("vertical_exaggeration", 1.0)), 0.01)
	_region = GeoRegionRenderer.new()
	_region.name = String(region_data.get("id", "Regiao"))
	add_child(_region)
	_region.set_meters_per_unit(_meters_per_unit)
	_region.set_vertical_exaggeration(_vertical_exaggeration)
	_region.vegetacao_autoral = _vegetacao_autoral()
	# A região vale 0 a 75% do progresso; a vila, o resto.
	_region.etapa.connect(func(fracao: float, texto: String) -> void: progresso.emit(fracao * 0.75, texto))
	# Os marcos de fé que o mapa não tem pedem clareira antes de a mata nascer.
	_region.clareiras.assign([Vector2(TERREIRO_M.x, TERREIRO_M.z) / _meters_per_unit,
		Vector2(GAMELEIRA_M.x, GAMELEIRA_M.z) / _meters_per_unit] + _clareiras_das_frentes())
	# E o voo do menu pede o vão dele livre na fileira da orla.
	_region.vaos_do_sobrevoo.assign([Vector2(VAO_NORTE_DO_SOBREVOO_M.x, VAO_NORTE_DO_SOBREVOO_M.z) / _meters_per_unit])
	await _region.build_region(String(region_data["geometry"]), String(region_data["scenario"]))
	# O sol segue a latitude do lugar (a origem do KML).
	if _region._projection.has("origin_lat"):
		Dia.definir_latitude(float(_region._projection["origin_lat"]))
		_aplicar_hora(Dia.hora)
	landmarks = _region.landmarks
	areas = _region.areas
	for landmark in landmarks:
		var nome := String(landmark["name"])
		var contador := 2
		while ancoras.has(nome):
			nome = "%s %d" % [String(landmark["name"]), contador]
			contador += 1
		ancoras[nome] = landmark["position"]
	if region_data["id"] == "bom_jesus_dos_pobres":
		await _construir_vila()
	var faltando := CatalogoAssets.relatorio_faltando()
	if not faltando.is_empty():
		print("CATALOGO: ", faltando)
	_concluir()


func _concluir() -> void:
	visible = true
	construido = true
	# O VALE SE APRESENTA AO `Lugares` AQUI, e não no `_ready`: as âncoras são
	# postas ao longo da construção inteira, e quem se registrasse no começo
	# responderia com meio dicionário. Nome resolvendo para o lugar errado é
	# pior que nome não resolvendo — este some a seta, aquele manda o jogador
	# para o outro lado da vila. Ver docs/projeto/MIGRACAO_2D_3D.md, Fase 1.
	Lugares.registrar(self)
	tree_exiting.connect(func() -> void: Lugares.esquecer(self))
	progresso.emit(1.0, "Pronto")
	pronto.emit()


## Cede um quadro à tela de carregamento se o quadro atual já passou do orçamento.
const ORCAMENTO_QUADRO_US := 80000
var _inicio_do_quadro_us := 0


func _pausar() -> void:
	if not is_inside_tree() or Time.get_ticks_usec() - _inicio_do_quadro_us < ORCAMENTO_QUADRO_US:
		return
	await get_tree().process_frame
	_inicio_do_quadro_us = Time.get_ticks_usec()


## Etapa da vila: avisa o progresso e cede um quadro à tela de carregamento.
func _etapa(fracao: float, texto: String) -> void:
	progresso.emit(fracao, texto)
	if is_inside_tree():
		await get_tree().process_frame


func _active_region_data() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAP_CATALOG))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Catálogo de regiões inválido: " + MAP_CATALOG)
		return {}
	for entry_value in data.get("regions", []):
		var entry: Dictionary = entry_value
		if entry.get("id", "") == data.get("active_region", ""):
			var scale := float(entry.get("scale_m_per_unit", 1.0))
			if scale <= 0.0:
				push_error("A escala da região (scale_m_per_unit) precisa ser positiva.")
				return {}
			var vertical_exaggeration := float(entry.get("vertical_exaggeration", 1.0))
			if vertical_exaggeration <= 0.0:
				push_error("A exageração vertical da região (vertical_exaggeration) precisa ser positiva.")
				return {}
			return entry
	push_error("A região ativa não foi encontrada no catálogo.")
	return {}


# ---------------------------------------------------------------------------
# Luz: sol, lua, céu e ambiente seguem o relógio do autoload Dia.
# ---------------------------------------------------------------------------

func _build_lighting() -> void:
	# O céu é do CeuVale: shader próprio, névoa com perspectiva aérea, sol e lua.
	_ceu = CeuVale.new()
	_ceu.montar(self)
	_sun = _ceu.sol
	_moon = _ceu.lua
	_environment = _ceu.ambiente
	_aplicar_hora(Dia.hora)
	Dia.hora_mudou.connect(_aplicar_hora)
	Relogio.estacao_mudou.connect(_aplicar_estacao)
	_aplicar_estacao(Relogio.estacao)


## Dentro de um cômodo de câmera de cima (a casa) a sombra do sol cobre só o que a câmera vê (#185).
func sombra_de_dentro(dentro: bool) -> void:
	if _ceu != null:
		_ceu.sombra_de_dentro(dentro)


func _aplicar_estacao(estacao: int) -> void:
	preload("res://scripts/prototipo_3d/estacoes_vale.gd").aplicar(estacao)
	_aplicar_hora(Dia.hora)


## O céu acompanha a hora (curvas de cor e de névoa em ceu_vale.gd), e as luzes de 1887 também.
func _aplicar_hora(hora: float) -> void:
	_ceu.aplicar(hora)
	if _luzes != null:
		_luzes.aplicar_hora(hora)


# ---------------------------------------------------------------------------
# A vila: cada função decide o estilo pelo catálogo.
# ---------------------------------------------------------------------------

func _construir_vila() -> void:
	var praca := Vector3.ZERO
	var taipa := _u(Vector3(-52, 0, -27))
	ancoras["Casa de taipa"] = taipa
	ancoras["Casa de Carro Quebrado"] = _u(Vector3(40, 0, -35))
	ancoras["Casa da estrada"] = _region.position_beside_road(_region.wgs84_to_world(-12.812855555555556, -38.780297222222224), "Rua Principal", 10.0)
	await _etapa(0.76, "Medindo os lotes")
	_loteamento()
	await _etapa(0.8, "Erguendo as casas")
	# Casas da praça
	_construcao("casa_taipa", taipa, 0.0, 1.0, "Casa de taipa")
	_construcao("casa_carro_quebrado", ancoras["Casa de Carro Quebrado"], 0.0, 1.0, "Casa de Carro Quebrado")
	# Referência: 12°48'46.28"S 38°46'49.07"W; afastar a casa do eixo da Rua Principal.
	var casa_estrada_referencia: Vector3 = _region.wgs84_to_world(-12.812855555555556, -38.780297222222224)
	ancoras["Casa da estrada"] = _region.position_beside_road(casa_estrada_referencia, "Rua Principal", 10.0)
	_construcao("casa_taipa", ancoras["Casa da estrada"], 0.0, 1.0, "Casa da estrada")
	# As demais casas do arraial, nos lotes reservados pelo loteamento.
	# Toda moradia da composição sobe aqui — as "Casa do arraial" e as casas dos
	# moradores novos (a do guarda, a da lavadeira...) —, menos as que já subiram
	# acima e as que sobem com os marcos. Casa nova cujo GLB ainda não chegou sobe
	# com a casca da casa de taipa.
	for nome_lote in _lotes:
		var chave_lote := String(_lotes[nome_lote]["chave"])
		if not _is_house_key(chave_lote) or String(nome_lote) in ["Casa de taipa", "Casa de Carro Quebrado", "Casa da estrada", "Venda do Bar", "Restaurante"]:
			continue
		if not CatalogoAssets.tem_tripo(chave_lote):
			chave_lote = "casa_taipa"
		_construcao(chave_lote, _lotes[nome_lote]["pos"], 0.0, 1.0, String(nome_lote))
		await _pausar()
	_escolher_as_casas_dos_moradores()
	await _etapa(0.84, "Cercando o roçado")
	_build_farm()
	await _etapa(0.86, "Plantando as árvores da vila")
	await _build_trees()
	await _build_details()
	await _etapa(0.89, "Erguendo a capela, a venda e o píer")
	_build_landmark_details()
	await _etapa(0.93, "Espalhando os objetos")
	_build_pecas()
	_build_marcos_de_fe()
	await _etapa(0.94, "Assentando as pedras")
	_build_pedras()
	_build_clareiras_da_mata()
	await _etapa(0.95, "Fundeando as canoas")
	_build_canoas()
	await _etapa(0.97, "Acendendo os lampiões")
	_build_luzes_epoca()
	await _etapa(0.975, "Plantando as árvores da vila")
	_build_paisagismo()
	_build_bases_das_arvores()


## O PAISAGISMO DO VALE: os bananais, pomares, roças e a mata ciliar do arraial,
## plantados pelas zonas de `scenes/prototipo_3d/paisagismo_vale.tscn` e pelas
## receitas de `data/paisagismo/receitas.json` (`paisagismo_vale.gd`). Vem depois
## de tudo o que tem lugar fixo — casas, nomeadas, âncoras, luzes — porque planta
## só no que sobrou, e antes dos pés das árvores, que o chão pinta. Só no estilo
## Tripo (as espécies são os GLBs dele).
const PaisagismoVale := preload("res://scripts/prototipo_3d/paisagismo_vale.gd")
## O que o paisagismo plantou (ver `PaisagismoVale.gerar`), para os portões.
var paisagismo_plantas: Array[Dictionary] = []
var paisagismo_aderecos: Array[Dictionary] = []


func _build_paisagismo() -> void:
	if _region == null:
		return
	var receitas := PaisagismoVale.ler_receitas()
	var plano := PaisagismoVale.planejar(self, PaisagismoVale.ler(), receitas)
	paisagismo_plantas.assign(plano["plantas"])
	paisagismo_aderecos.assign(plano["aderecos"])
	PaisagismoVale.plantar(_region, paisagismo_plantas, receitas)
	PaisagismoVale.plantar_aderecos(self, paisagismo_aderecos, receitas)


## AS CASAS DO PEDRO E DA DONA ZEFA, entre as casas de taipa do arraial: a do
## Pedro é a mais perto do píer — ele mora "na praia, perto do píer" —, e a da
## Zefa, a mais perto da casa herdada, que fica sendo a vizinha dela e do neto.
## Escolhidas aqui, e não por nome de lote, para continuar certo quando o
## loteamento mudar. As duas abrem por dentro (`Interiores`, cada uma com o
## perfil de quem mora), e o morador dorme nela. Ficam também como âncoras
## ("Casa do Pedro", "Casa da Zefa"), que é o que o `Lugares` e os postos leem.
var casas_dos_moradores: Dictionary = {}


func _escolher_as_casas_dos_moradores() -> void:
	var livres: Array[String] = []
	for nome_lote in _lotes:
		if String(nome_lote).begins_with("Casa do arraial") and str(_lotes[nome_lote].get("chave", "")) == "casa_taipa" and ancoras.has(nome_lote):
			livres.append(String(nome_lote))
	# O píer ainda não está posto quando as casas sobem: vale o ponto dele no
	# mapa da região, que existe desde o começo.
	var onde_fica := {"pier": _region.get_feature_center("Pier", "poi"), "Casa de taipa": ancoras.get("Casa de taipa", Vector3.INF)}
	for pedido in [["pedro", "pier", "Casa do Pedro"], ["zefa", "Casa de taipa", "Casa da Zefa"]]:
		var perto_de: Vector3 = onde_fica.get(str(pedido[1]), Vector3.INF)
		if not perto_de.is_finite():
			continue
		var melhor := ""
		var menor := INF
		for lote in livres:
			var distancia: float = (ancoras[lote] as Vector3).distance_to(perto_de)
			if distancia < menor:
				menor = distancia
				melhor = lote
		if melhor == "":
			continue
		livres.erase(melhor)
		casas_dos_moradores[str(pedido[0])] = melhor
		ancoras[str(pedido[2])] = ancoras[melhor]
		ancoras[str(pedido[2]) + "Frente"] = ancoras.get(melhor + "Frente", Vector3.BACK)


## Construção: GLB do Tripo com colisão em caixa. Sem o GLB não se constrói nada.
func _construcao(chave: String, origin: Vector3, yaw: float, size: float = 1.0, nome: String = "") -> Node3D:
	if chave == "igreja" and nome.is_empty():
		nome = "Igreja"
	var autoria: Dictionary = _casas_autorais.get(nome, {})
	var is_house := _is_house_key(chave)
	var placed_origin := origin
	if is_house:
		var footprint_radius := _raio_do_lote(chave, size)
		if _lotes.has(nome):
			placed_origin = _lotes[nome]["pos"]
			yaw = _lotes[nome]["yaw"]
		else:
			placed_origin = _reserve_house_site(origin, footprint_radius, nome)
		if not placed_origin.is_finite():
			return null
	else:
		placed_origin = ground_position(origin, maxf(origin.y - ground_height_at(origin), 0.0))
	if not autoria.is_empty():
		placed_origin = autoria["pos"]
		yaw = autoria["yaw"]
	var node := CatalogoAssets.instanciar(chave, self, placed_origin, size, yaw)
	if node != null:
		var limites: AABB = node.get_meta("limites")
		if is_house or chave == "igreja":
			var original_y := placed_origin.y
			placed_origin = _support_house(placed_origin, Vector2(limites.size.x, limites.size.z), yaw, chave, placed_origin.y if not autoria.is_empty() else NAN, 0.0, autoria.get("alicerce", {}))
			node.position.y += placed_origin.y - original_y
			if is_house:
				_remember_house_position(nome, placed_origin, yaw)
			else:
				_remember_house_position("Igreja", placed_origin, yaw)
		var corpo := CatalogoAssets.colisao(chave, node, self, placed_origin, size, yaw)
		var quem := nome if nome != "" else ("Igreja" if chave == "igreja" else "")
		if quem != "":
			construcoes[quem] = {"modelo": node, "colisao": corpo, "chave": chave}
		var piso := float(CatalogoAssets.PECAS[chave].get("piso", 0.0))
		var piso_size := Vector3(limites.size.x + 1.6, 0.16, limites.size.z + 1.6)
		var piso_position := placed_origin + Vector3(0, piso + 0.08, 0)
		if chave == "pier":
			# O modelo Tripo tem o próprio tabuado e recebe colisão pela malha.
			var pier_deck_top := piso_position.y + piso_size.y * 0.5
			ancoras["PierPiso"] = Vector3(placed_origin.x, pier_deck_top, placed_origin.z)
		elif not chave.begins_with("ponte") and autoria.has("terreiro"):
			# Terreiro autoral (Decal editado em composicao_vale.tscn), relativo à casa assentada.
			var dados: Dictionary = autoria["terreiro"]
			if bool(dados.get("visible", true)):
				var decal := TERREIRO_CASA.instantiate() as Decal
				decal.name = "Terreiro " + nome
				decal.size = dados["size"]
				decal.modulate = dados["modulate"]
				add_child(decal)
				decal.global_transform = Transform3D(Basis(Vector3.UP, yaw), placed_origin) * (dados["transform"] as Transform3D)
		elif not chave.begins_with("ponte"):
			# Terreiro de chão batido drapeado no próprio terreno (acompanha o declive):
			# uma caixa plana ficava flutuando do lado baixo do lote.
			var meio := Vector2(piso_size.x, piso_size.z) * 0.5
			var cantos := PackedVector2Array()
			for canto in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var local: Vector2 = (canto * meio).rotated(-yaw)
				cantos.append(Vector2(placed_origin.x, placed_origin.z) + local)
			_region._add_polygon("Terreiro", cantos, 0.03, Color("958d79"), false, _terreiro_material())
		if is_house:
			_register_house(nome if not nome.is_empty() else chave.capitalize(), chave, placed_origin, yaw, limites.size, "Tripo")
		if _lotes.has(nome):
			construcoes_editaveis[nome] = {"chave": chave, "pos": placed_origin, "yaw": yaw, "visual": node}
		return node
	push_error("Construção sem GLB no catálogo: %s" % chave)
	return null


func _is_house_key(chave: String) -> bool:
	return chave.begins_with("casa_") or chave == "venda"


func _raio_do_lote(chave: String, size: float = 1.0) -> float:
	var spec: Dictionary = CatalogoAssets.PECAS.get(chave, {})
	return maxf(5.5, float(spec.get("largura", 6.5)) * size * 0.75 + 1.0)


## Ponto em volta de uma construção com o deslocamento no referencial dela (porta no +Z):
## gira junto quando a casa se alinha à rua.
## Objetos de uma construção no mundo: os nós autorais da composição, ou a tabela
## PecasConstrucoes enquanto a casa ainda não tem peças criadas no editor.
func _pecas_da_casa(nome: String) -> Array:
	if not ancoras.has(nome):
		return []
	var base: Vector3 = ancoras[nome]
	var frente: Vector3 = ancoras.get(nome + "Frente", Vector3.BACK)
	var giro_casa := atan2(frente.x, frente.z)
	var casa := Transform3D(Basis(Vector3.UP, giro_casa), base)
	var autoria: Dictionary = _casas_autorais.get(nome, {})
	var resultado: Array = []
	if bool(autoria.get("pecas_autorais", false)):
		for dados in autoria.get("pecas", []):
			var item: Dictionary = (dados as Dictionary).duplicate()
			var local: Transform3D = item["transform"]
			item["pos"] = (casa * local).origin
			item["yaw"] = giro_casa + local.basis.get_euler().y
			item["exato"] = true
			resultado.append(item)
		return resultado
	var quintal := CatalogoAssets.tem_tripo("pitangueira") and _lotes.has(nome)
	for item in PecasConstrucoes.padrao_da_casa(nome):
		if item["chave"] == "pitangueira" and not quintal:
			continue
		item["pos"] = casa * (item["desloc"] as Vector3)
		item["yaw"] = giro_casa + float(item["giro"])
		item["exato"] = false
		resultado.append(item)
	return resultado


func _nomes_com_pecas() -> Array:
	var nomes: Array = []
	for nome in _casas_autorais.keys() + PecasConstrucoes.POR_CASA.keys() + _lotes.keys():
		if not nomes.has(nome):
			nomes.append(nome)
	return nomes


func _montar_arvores_das_casas() -> void:
	for nome in _nomes_com_pecas():
		for item in _pecas_da_casa(String(nome)):
			if item["tipo"] != "arvore" or not bool(item.get("visivel", true)):
				continue
			var pos: Vector3 = item["pos"]
			if bool(item.get("no_chao", true)):
				pos = ground_position(pos)
			_arvore(String(item["chave"]), pos, float(item.get("tamanho", 1.0)), float(item["yaw"]), bool(item["exato"]))
			await _pausar()


## Adereços, itens e luzes das construções (as árvores vão em _montar_arvores_das_casas).
func _montar_pecas(tipos: Array) -> void:
	for nome in _nomes_com_pecas():
		for item in _pecas_da_casa(String(nome)):
			if not tipos.has(item["tipo"]) or not bool(item.get("visivel", true)):
				continue
			var chave_item := String(item["chave"])
			var pos: Vector3 = item["pos"]
			var yaw := float(item["yaw"])
			var tamanho := float(item.get("tamanho", 1.0))
			if bool(item.get("no_chao", true)):
				pos = ground_position(pos)
			match String(item["tipo"]):
				"adereco":
					_adereco(chave_item, pos, yaw, tamanho)
					if chave_item == "cruzeiro" and not ancoras.has("Cruzeiro"):
						ancoras["Cruzeiro"] = pos
					elif chave_item.begins_with("varal") and not ancoras.has(String(nome) + "/Varal"):
						# O varal da casa é posto da agenda ("Casa/Varal", `npc.gd`):
						# a frente dele é o +Z do modelo, a corda corre no X.
						ancoras[String(nome) + "/Varal"] = pos
						ancoras[String(nome) + "/VaralFrente"] = Vector3(sin(yaw), 0.0, cos(yaw))
					elif chave_item in ["canoa_em_obra", "lavadouro_pedra"] and not ancoras.has(String(nome) + "/" + chave_item):
						# A canoa do carpinteiro e o lavadouro da lavadeira, no quintal: o
						# posto de trabalho de quem mora ali ("Casa/canoa_em_obra").
						ancoras[String(nome) + "/" + chave_item] = pos
						ancoras[String(nome) + "/" + chave_item + "Frente"] = Vector3(sin(yaw), 0.0, cos(yaw))
				"item":
					pos.y = maxf(pos.y, ground_height_at(pos))
					CatalogoAssets.instanciar(chave_item, self, pos, tamanho, yaw)
				"candeeiro":
					var luz := pos + Vector3(0.0, 0.1, 0.05).rotated(Vector3.UP, yaw)
					_luzes.candeeiro(luz, _adereco(chave_item if not chave_item.is_empty() else "candeeiro", pos, yaw, tamanho))
				"lampiao":
					_luzes.lampiao(pos, _adereco(chave_item if not chave_item.is_empty() else "lampiao_poste", pos, yaw, tamanho))
				"luz_janela":
					_luzes.janela(pos)


## OBJETO AVULSO (fora das casas): a posição autoral do grupo Avulsos da composição,
## ou a do código enquanto o editor ainda não criou os avulsos. Depois de criados,
## o que o autor apagou some do jogo (visivel = false), menos o que a jogabilidade
## exige (o píer), que volta ao lugar do mapa.
func _avulso(id: String, tipo: String, chave: String, pos: Vector3, yaw: float = 0.0, tamanho: float = 1.0, no_chao: bool = true, grupo: String = "") -> Dictionary:
	var item := {"id": id, "tipo": tipo, "chave": chave, "pos": pos, "yaw": yaw, "tamanho": tamanho, "no_chao": no_chao, "grupo": grupo, "visivel": true, "exato": false}
	if _avulsos_autorais.has(id):
		var autoria: Dictionary = _avulsos_autorais[id]
		var transformacao: Transform3D = autoria["transform"]
		item["pos"] = transformacao.origin
		item["yaw"] = transformacao.basis.get_euler().y
		if not String(autoria.get("chave", "")).is_empty():
			item["chave"] = String(autoria["chave"])
		item["tamanho"] = float(autoria.get("tamanho", tamanho))
		item["no_chao"] = bool(autoria.get("no_chao", no_chao))
		item["visivel"] = bool(autoria.get("visivel", true))
		item["exato"] = true
		if bool(item["no_chao"]):
			item["pos"] = ground_position(item["pos"])
	elif _avulsos_criados and _avulsos_grupos.has(grupo):
		# Só some o que falta num grupo que existe na composição. Grupo que o editor
		# ainda não criou (ou que o autor apagou inteiro) segue o código.
		item["visivel"] = false
	_avulsos_usados[id] = true
	avulsos_montados[id] = item
	return item


## Coqueiros da orla e manguezal da composição: a região planta estes no lugar dos
## sorteados, por grupo (só o grupo que existe na composição vira autoral).
const GRUPOS_DE_VEGETACAO := ["Coqueiros da orla", "Manguezal"]

func _vegetacao_autoral() -> Dictionary:
	var resultado := {}
	for grupo in _avulsos_grupos:
		if grupo in GRUPOS_DE_VEGETACAO:
			resultado[grupo] = []
	for id in _avulsos_autorais:
		var autoria: Dictionary = _avulsos_autorais[id]
		var grupo := String(autoria.get("grupo", ""))
		if not resultado.has(grupo):
			continue
		_avulsos_usados[id] = true
		if not bool(autoria.get("visivel", true)):
			continue
		var t: Transform3D = autoria["transform"]
		resultado[grupo].append({"point": Vector2(t.origin.x, t.origin.z), "giro": t.basis.get_euler().y, "escala": float(autoria.get("tamanho", 1.0))})
	return resultado


func _adereco_avulso(item: Dictionary) -> Node3D:
	if not bool(item["visivel"]):
		return null
	return _adereco(String(item["chave"]), item["pos"], float(item["yaw"]), float(item["tamanho"]))


func _arvore_avulsa(item: Dictionary) -> void:
	if not bool(item["visivel"]):
		return
	var antes := _arvores_nomeadas.size()
	_arvore(String(item["chave"]), item["pos"], float(item["tamanho"]), float(item["yaw"]), bool(item["exato"]))
	if _arvores_nomeadas.size() > antes:
		item["pos"] = _arvores_nomeadas[-1]["origem"]


func _item_avulso(item: Dictionary) -> void:
	if not bool(item["visivel"]):
		return
	var onde: Vector3 = item["pos"]
	onde.y = maxf(onde.y, ground_height_at(onde))
	CatalogoAssets.instanciar(String(item["chave"]), self, onde, float(item["tamanho"]), float(item["yaw"]))


## Avulsos que o autor acrescentou no editor (Ctrl+D) e que o código não conhece.
func _montar_avulsos_extras(tipos: Array) -> void:
	for id in _avulsos_autorais:
		if _avulsos_usados.has(id) or not tipos.has(String(_avulsos_autorais[id].get("tipo", ""))):
			continue
		var autoria: Dictionary = _avulsos_autorais[id]
		var item := _avulso(String(id), String(autoria["tipo"]), String(autoria.get("chave", "")), (autoria["transform"] as Transform3D).origin)
		match String(item["tipo"]):
			"arvore":
				_arvore_avulsa(item)
			"adereco":
				_adereco_avulso(item)
			"item":
				_item_avulso(item)
			"construcao":
				if bool(item["visivel"]):
					var no := CatalogoAssets.instanciar(String(item["chave"]), self, item["pos"], float(item["tamanho"]), float(item["yaw"]))
					if no != null:
						CatalogoAssets.colisao(String(item["chave"]), no, self, item["pos"], float(item["tamanho"]), float(item["yaw"]))
			"lampiao", "candeeiro", "fogueira", "luz_janela":
				_luz_avulsa(item)


func _luz_avulsa(item: Dictionary, luz_padrao: Vector3 = Vector3.INF) -> void:
	if not bool(item["visivel"]):
		return
	var pos: Vector3 = item["pos"]
	var chave := String(item["chave"])
	match String(item["tipo"]):
		"lampiao":
			_luzes.lampiao(pos, _adereco(chave if not chave.is_empty() else "lampiao_poste", pos, float(item["yaw"]), float(item["tamanho"])))
		"candeeiro":
			var luz := luz_padrao if luz_padrao.is_finite() and not bool(item["exato"]) else pos + Vector3.UP * 0.1
			_luzes.candeeiro(luz, _adereco(chave if not chave.is_empty() else "candeeiro", pos, float(item["yaw"]), float(item["tamanho"])))
		"fogueira":
			_luzes.fogueira(pos, _adereco(chave if not chave.is_empty() else "fogueira", pos, float(item["yaw"]), float(item["tamanho"])))
		"luz_janela":
			_luzes.janela(pos)


func _na_casa(ancora: String, deslocamento: Vector3) -> Vector3:
	var base: Vector3 = ancoras.get(ancora, Vector3.ZERO)
	var frente: Vector3 = ancoras.get(ancora + "Frente", Vector3.BACK)
	return base + deslocamento.rotated(Vector3.UP, atan2(frente.x, frente.z))


## Decide o lote de cada construção antes de erguer a vila, para árvores, adereços,
## luzes e postos dos moradores já usarem a posição e a frente finais.
func _loteamento() -> void:
	# A casa herdada fica junto do roçado (a carta falava em casa de taipa e roçado).
	var pedidos := [
		["Casa de taipa", "casa_taipa", _region.get_feature_center("Fazenda", "area")],
		["Casa de Carro Quebrado", "casa_carro_quebrado", ancoras["Casa de Carro Quebrado"]],
		["Casa da estrada", "casa_taipa", ancoras["Casa da estrada"]],
		["Venda do Bar", "venda", _region.get_feature_center("Bar", "poi") + Vector3(8, 0, 3)],
		["Restaurante", "casa_pasto", _region.get_feature_center("Restaurante", "poi") + Vector3(7, 0, 4)],
		["Igreja", "igreja", _region.get_feature_center("Igreja", "poi")],
		["Capela velha", "capela", _region.get_feature_center("Rua do mirante", "road")],
	]
	pedidos.append_array(_pedidos_casas_do_arraial())
	# Uma atualização geográfica não pode apagar casas já promovidas à autoria.
	var nomes_pedidos := {}
	for pedido in pedidos:
		nomes_pedidos[pedido[0]] = true
	for nome in _casas_autorais:
		if not nomes_pedidos.has(nome):
			var autoria: Dictionary = _casas_autorais[nome]
			pedidos.append([nome, autoria["chave"], autoria["pos"]])
	for pedido in pedidos:
		var nome: String = pedido[0]
		var templo: bool = pedido[1] in ["capela", "igreja"]
		var raio := 7.5 if templo else _raio_do_lote(pedido[1])
		var lote := {}
		if _casas_autorais.has(nome):
			var autoria: Dictionary = _casas_autorais[nome]
			lote = {"pos": autoria["pos"], "yaw": autoria["yaw"]}
			_house_sites.append({"position": lote["pos"], "radius": raio})
		elif nome == "Igreja":
			# A igreja fica exatamente no marco do KML (o lugar dela na vila real),
			# só girando a frente para a rua; os templos têm base própria de pedra.
			lote = _lote_fixo_virado_para_rua(pedido[2], raio)
		elif nome == "Capela velha":
			# No alto da rua do mirante o morro é inclinado: aceita desnível maior (a
			# base de pedra do modelo cobre); sem lote livre, crava ao lado da rua.
			lote = _lote_na_rua(pedido[2], raio, 1.6)
			if lote.is_empty():
				lote = _lote_capela_velha(raio)
		else:
			lote = _lote_na_rua(pedido[2], raio, 0.7 if templo else DESNIVEL_MAXIMO_CASA)
		if lote.is_empty():
			var sitio := _reserve_house_site(pedido[2], raio, nome)
			if not sitio.is_finite():
				continue
			lote = {"pos": sitio, "yaw": 0.0}
		# O modelo da casa autoral é o da composição (a casa paroquial no lugar da
		# Casa do arraial 7); a do pedido vale para quem ainda não foi editado.
		lote["chave"] = String(_casas_autorais[nome]["chave"]) if _casas_autorais.has(nome) and String(_casas_autorais[nome].get("chave", "")) != "" else pedido[1]
		lote["inicial"] = lote["pos"]
		_lotes[nome] = lote
		ancoras[nome] = lote["pos"]
		var yaw: float = lote["yaw"]
		ancoras[nome + "Frente"] = Vector3(sin(yaw), 0.0, cos(yaw))
	if ancoras.has("Venda do Bar"):
		ancoras["Bar"] = ancoras["Venda do Bar"]
		ancoras["BarFrente"] = ancoras["Venda do BarFrente"]


## Lote cravado em `ponto` (sem deslizar), com a frente girada para a rua mais próxima.
func _lote_fixo_virado_para_rua(ponto: Vector3, raio: float) -> Dictionary:
	var centro := Vector2(ponto.x, ponto.z)
	var mais_perto := centro + Vector2.RIGHT
	var menor := INF
	for road in _region._roads:
		var pontos: PackedVector2Array = road.points
		for i in pontos.size() - 1:
			var q := Geometry2D.get_closest_point_to_segment(centro, pontos[i], pontos[i + 1])
			if q.distance_to(centro) < menor:
				menor = q.distance_to(centro)
				mais_perto = q
	var pos := ponto
	pos.y = _footprint_height(pos, raio) + 0.02
	_house_sites.append({"position": pos, "radius": raio})
	var para_rua := Vector3(mais_perto.x - centro.x, 0.0, mais_perto.y - centro.y)
	var yaw := atan2(para_rua.x, para_rua.z) if para_rua.length_squared() > 0.01 else 0.0
	return {"pos": pos, "yaw": yaw}


## Ponto fixo a 45% da rua do mirante, afastado do eixo, frente para a rua.
func _lote_capela_velha(raio: float) -> Dictionary:
	for road in _region._roads:
		if String(road.name) != "Rua do mirante":
			continue
		var pontos: PackedVector2Array = road.points
		var comprimento := 0.0
		for i in pontos.size() - 1:
			comprimento += pontos[i].distance_to(pontos[i + 1])
		var alvo := _na_linha(pontos, comprimento * 0.45)
		var tangente: Vector2 = alvo[1]
		var normal := Vector2(tangente.y, -tangente.x)
		var centro: Vector2 = alvo[0] + normal * (float(road.width) * 0.5 + raio + RECUO_DA_RUA)
		return _lote_fixo_virado_para_rua(Vector3(centro.x, 0.0, centro.y), raio)
	return {}


## Mais casas do arraial ao longo das ruas maiores: lotes espalhados, dois por rua,
## para a vila não se resumir a meia dúzia de marcos.
func _pedidos_casas_do_arraial() -> Array:
	var pedidos: Array = []
	var indice := 0
	for road in _region._roads:
		if String(road.name) == "Rua do mirante" or pedidos.size() >= 8:
			continue
		var pontos: PackedVector2Array = road.points
		var comprimento := 0.0
		for i in pontos.size() - 1:
			comprimento += pontos[i].distance_to(pontos[i + 1])
		if comprimento < 45.0:
			continue
		for fracao in [0.32, 0.64]:
			var alvo := _na_linha(pontos, comprimento * fracao)
			indice += 1
			var chave := "casa_taipa" if indice % 2 == 0 else "casa_carro_quebrado"
			pedidos.append(["Casa do arraial %d" % indice, chave, Vector3(alvo[0].x, 0.0, alvo[0].y)])
	return pedidos


## Lote ao lado da rua mais próxima de `preferido`, do mesmo lado dela: desliza ao longo
## da rua, a partir do ponto mais próximo, até achar terreno livre e quase plano. A
## frente (+Z) fica voltada para a rua. Vazio se não houver rua perto ou lote livre.
func _lote_na_rua(preferido: Vector3, raio: float, desnivel_maximo: float = DESNIVEL_MAXIMO_CASA) -> Dictionary:
	var ponto := Vector2(preferido.x, preferido.z)
	var melhor_rua: Dictionary = {}
	var menor := INF
	var s0 := 0.0
	for road in _region._roads:
		var pts: PackedVector2Array = road.points
		var percorrido := 0.0
		for i in pts.size() - 1:
			var q := Geometry2D.get_closest_point_to_segment(ponto, pts[i], pts[i + 1])
			var d := q.distance_to(ponto)
			if d < menor:
				menor = d
				melhor_rua = road
				s0 = percorrido + pts[i].distance_to(q)
			percorrido += pts[i].distance_to(pts[i + 1])
	if melhor_rua.is_empty() or menor > 80.0:
		return {}
	var pontos: PackedVector2Array = melhor_rua.points
	var afastamento: float = float(melhor_rua.width) * 0.5 + raio + RECUO_DA_RUA
	var base := _na_linha(pontos, s0)
	var lado := signf((ponto - base[0]).cross(base[1])) if menor > 0.01 else 1.0
	if lado == 0.0:
		lado = 1.0
	for k in range(int(ALCANCE_NA_RUA / PASSO_NA_RUA) + 1):
		for sinal in ([1.0] if k == 0 else [1.0, -1.0]):
			var alvo := _na_linha(pontos, s0 + sinal * k * PASSO_NA_RUA)
			var tangente: Vector2 = alvo[1]
			var normal := Vector2(tangente.y, -tangente.x) * lado
			var centro2: Vector2 = alvo[0] + normal * afastamento
			var centro := Vector3(centro2.x, 0.0, centro2.y)
			if _site_is_clear(centro, raio, true, desnivel_maximo):
				centro.y = _footprint_height(centro, raio) + 0.02
				_house_sites.append({"position": centro, "radius": raio})
				var para_rua := -Vector3(normal.x, 0.0, normal.y)
				return {"pos": centro, "yaw": atan2(para_rua.x, para_rua.z)}
	return {}


## Ponto e tangente da linha a `s` unidades do começo (preso às pontas).
func _na_linha(pontos: PackedVector2Array, s: float) -> Array:
	var restante := maxf(s, 0.0)
	for i in pontos.size() - 1:
		var trecho := pontos[i].distance_to(pontos[i + 1])
		var tangente := (pontos[i + 1] - pontos[i]).normalized()
		if restante <= trecho or i == pontos.size() - 2:
			return [pontos[i] + tangente * minf(restante, trecho), tangente]
		restante -= trecho
	return [pontos[0], Vector2.RIGHT]


## Chão batido varrido para terreiros e alicerces das casas: a mesma terra (textura,
## ladrilho e tinta) que o shader do terreno pinta na praça, nas ruas e nas trilhas,
## para o terreiro emendar no chão em volta sem trocar de cor.
func _terreiro_material() -> Material:
	if _terreiro == null:
		var terra: Array = _region.CAMADAS_DO_CHAO["terra"]
		_terreiro = _region._textured_material(terra[0], Color(0.98, 0.94, 0.88), float(terra[1]))
	return _terreiro


func _reserve_house_site(preferred: Vector3, radius: float, name: String) -> Vector3:
	var placed := _find_clear_site(preferred, radius, 40)
	if not placed.is_finite():
		push_error("Não há terreno livre para a casa: " + name)
		return Vector3.INF
	placed.y = _footprint_height(placed, radius) + 0.02
	_house_sites.append({"position": placed, "radius": radius})
	return placed


func _find_clear_site(preferred: Vector3, radius: float, rings: int, check_manual_trees: bool = true) -> Vector3:
	if _site_is_clear(preferred, radius, check_manual_trees):
		return preferred
	for ring in range(1, rings + 1):
		var distance := float(ring) * SITE_SEARCH_STEP
		for direction in range(SITE_SEARCH_DIRECTIONS):
			var angle := TAU * float(direction) / float(SITE_SEARCH_DIRECTIONS)
			var candidate := preferred + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
			if _site_is_clear(candidate, radius, check_manual_trees):
				return candidate
	return Vector3.INF


func _site_is_clear(position: Vector3, radius: float, check_manual_trees: bool = true, max_relief: float = 0.8) -> bool:
	if not _region.is_build_site_clear(position, radius):
		return false
	if check_manual_trees:
		var footprint_heights := _footprint_range(position, radius)
		if footprint_heights.y - footprint_heights.x > max_relief:
			return false
	var center := Vector2(position.x, position.z)
	for site in _house_sites:
		var other: Vector3 = site["position"]
		var separation: float = radius + float(site["radius"]) + 1.0
		if center.distance_squared_to(Vector2(other.x, other.z)) < separation * separation:
			return false
	if check_manual_trees:
		for site in _manual_tree_sites:
			var other: Vector3 = site["position"]
			var separation: float = radius + float(site["radius"]) + 1.0
			if center.distance_squared_to(Vector2(other.x, other.z)) < separation * separation:
				return false
	return true


func _register_house(nome: String, chave: String, origin: Vector3, yaw: float, bounds: Vector3, style: String) -> void:
	var house := Area3D.new()
	house.name = "AlvoCasa%s" % (_house_targets.size() + 1)
	house.position = origin
	house.rotation.y = yaw
	house.collision_layer = HOUSE_INTERACTION_LAYER
	house.collision_mask = 0
	house.monitoring = false
	house.add_to_group("interactive_house")
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(bounds.x, 3.0), maxf(bounds.y, 3.0), maxf(bounds.z, 3.0))
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = shape.size.y * 0.5
	house.add_child(collision)
	var properties := {"name": nome, "object_key": chave, "position": origin, "style": style}
	house.set_meta("house_properties", properties)
	house.set_meta("house_bounds", shape.size)
	var label := Label3D.new()
	label.name = "PropriedadesCasa"
	label.font_size = 30
	label.outline_size = 8
	label.pixel_size = 0.0034
	label.width = 720.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("f2dc9a")
	label.position.y = maxf(shape.size.y + 1.0, 6.0)
	house.add_child(label)
	house.set_meta("house_label", label)
	add_child(house)
	_house_targets.append(house)
	_update_house_label(house)


func _house_from_collider(collider: Object) -> Area3D:
	if collider == null or not is_instance_valid(collider):
		return null
	var node := collider as Node
	while node != null:
		if node is Area3D and _house_targets.has(node):
			return node as Area3D
		node = node.get_parent()
	return null


func _update_house_label(house: Area3D) -> void:
	var label: Label3D = house.get_meta("house_label")
	var properties: Dictionary = house.get_meta("house_properties")
	if house == _selected_house:
		label.text = format_house_properties(properties)
		label.visible = true
	elif house == _hovered_house:
		label.text = "%s\nClique para ver propriedades" % properties["name"]
		label.visible = true
	else:
		label.visible = false


## Adereço: GLB do Tripo com a colisão do catálogo. Sem o GLB, nada nasce.
func _adereco(chave: String, origin: Vector3, yaw: float = 0.0, size: float = 1.0) -> Node3D:
	origin.y = maxf(origin.y, ground_height_at(origin))
	var node := CatalogoAssets.instanciar(chave, self, origin, size, yaw)
	if node == null:
		push_error("Adereço sem GLB no catálogo: %s" % chave)
		return null
	CatalogoAssets.colisao(chave, node, self, origin, size, yaw)
	return node


## O lance das cercas soltas do quintal do roçado, como o do cercado do cemitério.
const LANCE_DO_QUINTAL := 2.0


## UMA CERCA SOLTA DO QUINTAL (#93): dois lances ao longo do X, centrados em
## `centro`, cada um de ponta a ponta no chão (`CatalogoAssets.lance_de_cerca`).
func _cerca_do_quintal(centro: Vector3, largura_do_lance: float) -> void:
	for k in 2:
		var de := ground_position(centro + Vector3((float(k) - 1.0) * LANCE_DO_QUINTAL, 0.0, 0.0))
		var ate := ground_position(centro + Vector3(float(k) * LANCE_DO_QUINTAL, 0.0, 0.0))
		CatalogoAssets.lance_de_cerca(self, de, ate, 1.0, largura_do_lance, 1.2, 0.3, "CercaDoQuintal", "CercaColisao")


## Caixa sólida na laje do túmulo: não se atravessa andando, mas dá para subir pulando.
func _colisao_tumulo(chao: Vector3, pegada: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "TumuloColisao"
	var shape := BoxShape3D.new()
	shape.size = pegada
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	body.position = chao + Vector3(0, pegada.y * 0.5, 0)
	add_child(body)


## AS DOZE COVAS DO CEMITÉRIO (data/lapides_3d.json, na ordem dela), no desenho de
## `CemiterioLayout`: fileiras leste-oeste, cabeceira a oeste, o corredor do meio na
## altura da porta da capelinha. Cada laje é assentada no TERRENO: a base sai do
## canto mais baixo da pegada dela (os quatro cantos e o centro, pela mesma fórmula
## do chão), um pouco afundada, e não da altura do centro, que deixava a ponta no ar.
## Sem inclinar a laje: o conserto do Damião é que a inclina (`cemiterio_vale.gd`),
## e a laje assentada tem de voltar reta.
##
## `lapides[i]` é o centro da laje no pé dela; `lapides_pegada[i]` a caixa dela nos
## eixos do MUNDO (a que o corpo sólido e `lapides.gd` leem); `tumulos[i]` o nó, com
## a marca `eixo_curto` (em volta de qual eixo da laje se levanta uma ponta).
func _assentar_as_covas(cemetery: Vector3) -> void:
	for index in range(CemiterioLayout.quantas()):
		var lugar := CemiterioLayout.lugar(index)
		var desvio: Vector2 = lugar["desvio"]
		var giro := CemiterioLayout.giro_de_base(true) + float(lugar["giro"])
		var tamanho := float(lugar["tamanho"])
		var centro := ground_position(cemetery + Vector3(desvio.x, 0.0, desvio.y))
		var tumulo := _adereco("tumulo", centro, giro, tamanho)
		if tumulo == null:
			push_warning("Não há túmulo para a cova %d." % index)
			continue
		# A laje no espaço dela (antes do giro): o modelo traz a caixa.
		var limites: AABB = tumulo.get_meta("limites")
		var meio := Vector2(limites.size.x, limites.size.z) * 0.5
		var altura_da_laje := limites.size.y * 0.62
		# Os cantos da pegada no mundo, e a altura do terreno sob cada um.
		var menor := INF
		var maior := -INF
		for ponto: Vector2 in [Vector2.ZERO, Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var canto: Vector2 = (ponto * meio).rotated(-giro)
			var chao := ground_height_at(Vector3(centro.x + canto.x, 0.0, centro.z + canto.y))
			menor = minf(menor, chao)
			maior = maxf(maior, chao)
		var base := lerpf(menor, maior, CemiterioLayout.BASE_ENTRE_OS_CANTOS) - CemiterioLayout.AFUNDADA
		tumulo.position.y += base - centro.y
		centro.y = base
		# A caixa nos eixos do mundo: a da laje girada.
		var vira := Vector2(absf(cos(giro)), absf(sin(giro)))
		var pegada := Vector3(meio.x * 2.0 * vira.x + meio.y * 2.0 * vira.y, altura_da_laje, meio.x * 2.0 * vira.y + meio.y * 2.0 * vira.x)
		tumulo.set_meta("eixo_curto", CemiterioLayout.eixo_curto(tumulo.has_meta("limites")))
		lapides.append(centro)
		tumulos.append(tumulo)
		_colisao_tumulo(centro, pegada)
		lapides_pegada.append(pegada)


## A CAPELINHA DO CEMITÉRIO, onde o católico reza (`marcos_da_fe.gd`): na beira
## do outeiro do lado do mar, DE COSTAS PARA ELE — quem reza fica de frente para
## a porta e, por cima do telhado, vê a baía. Rezava-se no meio das covas, entre
## duas lajes.
##
## O lado do mar é o do ponto da costa mais perto (`lado_do_mar`), acertado ao
## eixo das covas, para a capelinha ficar no alinhamento delas e do cercado, que
## passa pelo meio dela (`cemiterio_vale.gd`): a porta dentro, os fundos fora.
## É a capela do catálogo, pequena, no alicerce das casas — o outeiro cai para o
## mar, e sem ele os fundos ficavam no ar.
const CAPELINHA_TAMANHO := 0.5
## Do centro do cemitério ao meio da capelinha, para o lado do mar, e o quanto
## ela sai da linha do meio ao longo da beira (para longe da entrada do cercado).
const CAPELINHA_PARA_O_MAR := 9.95
const CAPELINHA_DE_LADO := -0.6


func _capelinha_do_cemiterio(cemetery: Vector3) -> void:
	var mar := lado_do_mar(cemetery)
	var frente := -mar
	var ao_longo := Vector3(-mar.z, 0.0, mar.x)
	var centro := cemetery + mar * CAPELINHA_PARA_O_MAR + ao_longo * CAPELINHA_DE_LADO
	centro.y = ground_height_at(centro)
	var yaw := atan2(frente.x, frente.z)
	var porta := Vector3.INF
	# A CAPELINHA POBRE do cemitério, de taipa e cal rachada ("deve ser mais
	# rudimentar, com um aspecto pobre"), ou, sem ela no catálogo, a capela
	# colonial reduzida que estava ali.
	var chave := "capelinha" if CatalogoAssets.tem_tripo("capelinha") else "capela"
	var tamanho := 1.0 if chave == "capelinha" else CAPELINHA_TAMANHO
	var capela := CatalogoAssets.instanciar(chave, self, centro, tamanho, yaw)
	if capela != null:
		var limites: AABB = capela.get_meta("limites")
		var assentada := _support_house(centro, Vector2(limites.size.x, limites.size.z), yaw)
		capela.position.y += assentada.y - centro.y
		var corpo := CatalogoAssets.colisao(chave, capela, self, assentada, tamanho, yaw)
		construcoes["Capelinha"] = {"modelo": capela, "colisao": corpo}
		centro = assentada
		porta = assentada + frente * (limites.size.z * 0.5)
		# Lote tomado: o que se planta depois não nasce dentro dela.
		_house_sites.append({"position": assentada, "radius": maxf(limites.size.x, limites.size.z) * 0.5})
	if not porta.is_finite():
		push_error("Capelinha do cemitério sem GLB no catálogo.")
		porta = centro + frente * (float(CatalogoAssets.PECAS["capela"]["largura"]) * CAPELINHA_TAMANHO * 0.5)
	ancoras["Capelinha"] = centro
	ancoras["CapelinhaFrente"] = frente
	ancoras["CapelinhaPorta"] = ground_position(porta)


## O LADO DO MAR visto de `ponto`: para o ponto da linha da costa mais perto,
## acertado ao eixo (±X ou ±Z) mais próximo. Sem costa, +X, que é o lado da baía
## neste mapa.
func lado_do_mar(ponto: Vector3) -> Vector3:
	var costa: PackedVector2Array = _region._coast if _region != null else PackedVector2Array()
	var de := Vector2(ponto.x, ponto.z)
	var mais_perto := Vector2.INF
	var menor := INF
	for i in costa.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(de, costa[i], costa[i + 1])
		if q.distance_to(de) < menor:
			menor = q.distance_to(de)
			mais_perto = q
	if not mais_perto.is_finite():
		return Vector3.RIGHT
	var rumo := mais_perto - de
	if absf(rumo.x) >= absf(rumo.y):
		return Vector3(signf(rumo.x), 0.0, 0.0)
	return Vector3(0.0, 0.0, signf(rumo.y))


## Árvore com nome: GLB do Tripo (colisão no tronco). Sem o GLB, a árvore não nasce.
func _arvore(especie: String, origin: Vector3, size: float = 1.0, yaw: float = 0.0, exato: bool = false) -> void:
	var tree_radius := maxf(2.0, size * 2.4)
	# Posição autoral (composição) é respeitada; as demais procuram chão livre.
	var placed_origin := origin if exato else _find_clear_site(origin, tree_radius, 24, false)
	if not placed_origin.is_finite():
		push_warning("Não há terreno livre para a árvore: " + especie)
		return
	placed_origin = ground_position(placed_origin)
	_manual_tree_sites.append({"position": placed_origin, "radius": tree_radius})
	var registro := _arvores_nomeadas.size()
	_arvores_nomeadas.append({"especie": especie, "pos": placed_origin, "raio": size * 0.5, "origem": placed_origin})
	var node := CatalogoAssets.instanciar(especie, self, placed_origin - Vector3(0.0, _region.ARVORE_AFUNDADA, 0.0), size, yaw)
	if node != null:
		# O pé do tronco, e não o ponto de plantio, apoia a árvore na encosta (#141).
		var apoio := _apoio_pelo_pe(especie, node, size, placed_origin.y)
		if apoio != 0.0:
			node.position.y += apoio
			placed_origin.y += apoio
			_arvores_nomeadas[registro]["pos"] = placed_origin
		CatalogoAssets.colisao(especie, node, self, placed_origin, size, yaw)
		_arvores_nomeadas[registro]["visual"] = node
		var corpo := get_child(get_child_count() - 1) as StaticBody3D
		_arvores_nomeadas[registro]["colisao"] = corpo
		if especie == "cajueiro" and corpo != null:
			var cilindro := (corpo.get_child(0) as CollisionShape3D).shape as CylinderShape3D
			_arvores_nomeadas[registro]["pos"] = Vector3(corpo.position.x, placed_origin.y, corpo.position.z)
			_arvores_nomeadas[registro]["raio"] = cilindro.radius
		if especie == "coqueiro":
			_alinhar_colisao_coqueiro(node, corpo)
		return
	push_error("Árvore sem GLB no catálogo: %s" % especie)
	_arvores_nomeadas.remove_at(registro)


## O APOIO PELO PÉ DO TRONCO da árvore nomeada (#141): quanto ela sobe (+) ou desce (−) para o pé do
## tronco, medido no modelo (`CatalogoAssets.tronco`), e não o ponto de plantio, ficar no chão. O
## coqueiro, inclinado, mede o pé pela própria regra (`_alinhar_colisao_coqueiro`) e fica de fora.
func _apoio_pelo_pe(especie: String, node: Node3D, size: float, ground: float) -> float:
	if especie == "coqueiro" or _region == null:
		return 0.0
	var medido := CatalogoAssets.tronco(especie, size)
	if medido.is_empty():
		return 0.0
	var pe: Vector3 = node.transform * (medido["centro"] as Vector3)
	return clampf(ground_height_at(pe) - ground, -_region.APOIO_PELO_PE_MAXIMO, _region.APOIO_PELO_PE_MAXIMO)


func _alinhar_colisao_coqueiro(visual: Node3D, corpo: StaticBody3D) -> void:
	if corpo == null:
		return
	var malhas: Array[MeshInstance3D] = []
	if visual is MeshInstance3D:
		malhas.append(visual as MeshInstance3D)
	for filho in visual.find_children("*", "MeshInstance3D", true, false):
		malhas.append(filho as MeshInstance3D)
	for malha in malhas:
		var referencias: Dictionary = CoqueiroCortado.referencias_tronco(malha.mesh)
		if referencias.is_empty():
			continue
		var base: Vector3 = malha.global_transform * (referencias["base"] as Vector3)
		var alto: Vector3 = malha.global_transform * (referencias["alto"] as Vector3)
		var eixo := (alto - base).normalized()
		if eixo.length_squared() < 0.5:
			eixo = Vector3.UP
		var colisao := corpo.get_child(0) as CollisionShape3D
		if colisao == null or not (colisao.shape is CylinderShape3D):
			return
		var cilindro := colisao.shape as CylinderShape3D
		var escala := malha.global_transform.basis.get_scale()
		cilindro.radius = maxf(cilindro.radius, float(referencias["raio_base"]) * maxf(escala.x, escala.z) * 0.9)
		corpo.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, eixo)), base + eixo * cilindro.height * 0.5)
		return


## A LAVOURA DA CASA (#8), na frente dela, depois da cana e da lenha: o chão
## aberto do roçado, onde a fazenda do jogador planta. No referencial da casa
## (`_na_casa`), para girar com ela. LONGE DOS PÉS DE CANA: no campo a tecla é
## da lavoura, e pé de cana dentro dele ou na beira ficaria sem tecla — dois
## ficavam, a onze e meio da casa.
const LAVOURA_NA_CASA := Vector3(4.0, 0.0, 14.0)
## O canteiro velho de mandioca, a leste da lavoura. Morava no meio do roçado
## — que a casa passou a ocupar —, e com a casa aberta por dentro ele aparecia
## no meio da sala.
const CANTEIRO_NA_CASA := Vector3(10.5, 0.0, 12.0)
## A mesa do canteiro de obras, a do prumo, a partir do meio do roçado: junto
## da bancada da oficina (-3, -9), atrás dela e da casa.
const CANTEIRO_DE_OBRAS := Vector3(-3.0, 0.0, -12.0)
## A chapada do Seu Benedito, em metros a partir da praça (x 24 m a oeste dela,
## 1.072 m ao norte).
const CHAPADA_DO_BENEDITO_M := Vector3(-24.0, 0.0, -1072.0)


func _build_farm() -> void:
	var origin: Vector3 = _region.get_feature_center("Fazenda", "area")
	ancoras["Roçado"] = origin
	# A casa passou a ocupar o centro do roçado. A oficina precisa de ponto
	# próprio na beira, senão a distância empatada sempre escolhe a casa.
	#
	# E LONGE DE TRONCO: em (-8, -4) ela ficava a 2,8 m do tronco caído da
	# chegada (`lenha_rocado_b`), e o E ao lado da bancada batia nele — "não
	# consegui interagir" com a bancada. Aqui, atrás da casa, o tronco, o
	# lajedo e a árvore mais perto ficam a mais de 5 m nos dois estilos, e o E
	# perto dela é só da oficina (`tecla_das_bancadas.gd`).
	ancoras["Oficina"] = ground_position(origin + Vector3(-3.0, 0.0, -9.0))
	# A MESA DO CANTEIRO DE OBRAS, a do prumo, junto da do serrote ("a do lado,
	# com a planta em cima, é outra coisa — é onde se decide obra", no 2D). Ao
	# fundo, e não do lado: quem encosta na bancada pelo leste é dela, e o tronco
	# e o lajedo mais perto ficam a dez passos daqui.
	ancoras["Canteiro de obras"] = ground_position(origin + CANTEIRO_DE_OBRAS)
	# A CHAPADA DO SEU BENEDITO (`Lugares` "expansao", data/missoes_chapada.json):
	# a terra alta para lá da Dona Zefa, de frente para o rio grande, "passando
	# pela terra da Dona Zefa" como no 2D. Posta no vale de hoje, sem mexer no KML
	# (revisada pelo autor): o chão sobe devagar para o poente, de 5 na casa a 7
	# ali, e o rio passa 17 u ao norte — "tá vendo a água?".
	ancoras["Chapada"] = ground_position(_u(CHAPADA_DO_BENEDITO_M))
	# A LOMBADA, A LAPA E A CABRA (`Lugares` "lapa" e "cabra_do_alto",
	# data/missoes_lombada.json): o alto de pedra que o vale não tinha perto das
	# terras, levantado por `lombada_vale.gd` — lugar revisado pelo autor. A âncora
	# da lombada fica no chão mais alto debaixo dela, que é onde o alto se apoia; a
	# da cabra, em cima; a da lapa, no pé da rampa, onde a pedra a tranca.
	var lombada := _u(LombadaVale.CENTRO_M)
	lombada.y = _footprint_height(lombada, LombadaVale.ALTO.x * 0.5)
	ancoras["Lombada"] = lombada
	ancoras["Cabra do alto"] = lombada + Vector3(0.0, LombadaVale.ALTO.y, 0.0)
	ancoras["Lapa"] = ground_position(lombada + Vector3(LombadaVale.PE_DA_RAMPA + LombadaVale.ANTES_DA_LAPA, 0.0, 0.0))
	# A FAZENDA DO CONVITE (`Lugares` "portao_da_fazenda" e "patio_da_fazenda",
	# `fazenda_vale.gd`): do outro lado do rio grande, na ponta da Rua Principal,
	# logo depois da ponte — revisada pelo autor. O pátio é o pé da escadaria do
	# casarão, que é onde o 2D fecha o passo.
	ancoras["Portão da fazenda"] = ground_position(_u(FazendaVale.PORTAO_M))
	ancoras["Pátio da fazenda"] = ground_position(_u(FazendaVale.PATIO_M))
	ancoras["Casarão"] = ground_position(_u(FazendaVale.CASARAO_M))
	ancoras["Lavoura"] = ground_position(_na_casa("Casa de taipa", LAVOURA_NA_CASA))
	ancoras["LavouraFrente"] = ancoras.get("Casa de taipaFrente", Vector3.BACK)
	var canteiro := ground_position(_na_casa("Casa de taipa", CANTEIRO_NA_CASA))
	if _adereco("mandioca_canteiro", canteiro, 0.2) == null:
		for row in range(3):
			_box(Vector3(5.6, 0.1, 0.88), ground_position(canteiro + Vector3(0, 0, row * 1.35), 0.055), Color("826346"))
			for column in range(7):
				var crop := CylinderMesh.new()
				crop.top_radius = 0.02
				crop.bottom_radius = 0.24
				crop.height = 0.54 + row * 0.09
				crop.radial_segments = 5
				_mesh(crop, ground_position(canteiro + Vector3(-2.3 + column * 0.75, 0, row * 1.35), 0.35), Color("8fa85e"))
	# AS DUAS CERCAS DO QUINTAL, em lances deitados na encosta como toda cerca do
	# vale (#93), e do tamanho das outras: por `_adereco("cerca", …, 2.0)` a cerca
	# saía com 2,3 m de altura.
	var largura_do_lance := CatalogoAssets.largura_da_cerca(self, 1.0, LANCE_DO_QUINTAL)
	for recuo: float in [6.0, -3.0]:
		_cerca_do_quintal(ground_position(origin + Vector3(-4.0, 0.0, recuo)), largura_do_lance)
	_box(Vector3(0.85, 1.0, 0.85), ground_position(origin + Vector3(5.2, 0, 2), 0.5), WOOD, true)
	_box(Vector3(0.95, 0.11, 0.95), ground_position(origin + Vector3(5.2, 0, 2), 1.0), Color("b1966c"))


func _build_trees() -> void:
	# Posições anotadas em metros reais ao redor da Praça (a cena converte para unidades).
	# Espécies de docs/mundo/AMBIENTACAO.md §4.
	_arvore_avulsa(_avulso("Pau-brasil", "arvore", "pau_brasil", _u(Vector3(-82, 0, 5)), 0.0, 1.0, true, "Árvores"))
	await _pausar()
	var plan: Array = [
		["mangueira", Vector3(-75, 0, -70), 1.0, 0.4],
		["cajueiro", Vector3(-78, 0, -35), 1.0, 1.9],
		["ipe_amarelo", Vector3(-85, 0, 47), 1.0, 0.0],
		["jaqueira", Vector3(-44, 0, 93), 1.0, 2.6],
		["mangueira", Vector3(55, 0, 99), 1.1, 3.1],
		["ipe_roxo", Vector3(72, 0, 77), 0.95, 1.2],
		["cajueiro", Vector3(85, 0, 30), 1.05, 4.0],
		["jaqueira", Vector3(85, 0, -60), 0.9, 0.7],
		["embauba", Vector3(44, 0, -86), 1.0, 0.0],
		["dendezeiro", Vector3(-46, 0, -95), 1.0, 2.2],
		["mangueira", Vector3(-34, 0, 38), 0.9, 5.2],
		["mangueira", Vector3(22, 0, -44), 0.85, 1.6],
	]
	var contagem := {}
	for entry in plan:
		var especie := String(entry[0])
		contagem[especie] = int(contagem.get(especie, 0)) + 1
		var id := "%s %d" % [String(NOMES_DAS_ESPECIES.get(especie, especie.capitalize())), contagem[especie]]
		_arvore_avulsa(_avulso(id, "arvore", especie, _u(entry[1]), float(entry[3]), float(entry[2]), true, "Árvores"))
		await _pausar()
	var taipa: Vector3 = ancoras.get("Casa de taipa", _u(Vector3(-52, 0, -27)))
	# Árvores dos quintais (bananeiras, dendezeiros, pitangueiras, ipês da igreja):
	# vêm da composição autoral ou da tabela PecasConstrucoes.
	await _montar_arvores_das_casas()
	var farm: Vector3 = _region.get_feature_center("Fazenda", "area")
	_arvore_avulsa(_avulso("Mangueira da fazenda", "arvore", "mangueira", farm + Vector3(-9.5, 0, -6.5), 0.9, 1.15, true, "Fazenda"))
	await _pausar()
	_arvore_avulsa(_avulso("Cajueiro da fazenda 1", "arvore", "cajueiro", farm + Vector3(9.0, 0, -8.0), 2.4, 1.0, true, "Fazenda"))
	await _pausar()
	_arvore_avulsa(_avulso("Cajueiro da fazenda 2", "arvore", "cajueiro", farm + Vector3(11.0, 0, 8.5), 0.3, 0.9, true, "Fazenda"))
	await _pausar()
	var pier: Vector3 = _region.get_feature_center("Pier", "poi")
	var toward_praca: Vector3 = (_region.get_feature_center("Praça", "poi") - pier).normalized()
	var coqueiro := 0
	for step in [Vector3(14.0, 0, 5.0), Vector3(20.0, 0, -4.0)]:
		coqueiro += 1
		_arvore_avulsa(_avulso("Coqueiro do píer %d" % coqueiro, "arvore", "coqueiro", pier + toward_praca * step.x + Vector3(0, 0, step.z), step.z, 1.0, true, "Píer"))
		await _pausar()
	_montar_avulsos_extras(["arvore"])


func _build_details() -> void:
	# Canteiros de flores na BORDA da praça (o miolo do largo fica aberto, como no
	# lugar real): um anel de moitas, pulando as bocas de rua.
	for i in range(16):
		var angulo := TAU * float(i) / 16.0
		var ponto := Vector3(cos(angulo) * 16.5, 0, sin(angulo) * 12.5)
		if _region.surface_at(ponto) == "terra":
			continue
		await _pausar()
		if _adereco("moita", ponto, float(i) * 0.7, 0.55 + float(i % 3) * 0.12) != null:
			continue
		for j in range(3):
			var flower := Vector3(ponto.x + j * 0.21, 0, ponto.z + (j % 2) * 0.25)
			_box(Vector3(0.05, 0.28, 0.05), ground_position(flower, 0.14), LEAVES)
			_box(Vector3(0.16, 0.10, 0.16), ground_position(flower, 0.30), Color("e4c782") if i % 2 == 0 else Color("ce9d99"))


## A mesma peça e a mesma colisão atendem às duas travessias do vale.
func _erguer_ponte(point: Vector3, anchor: String) -> void:
	var bridge := point
	bridge.y = _footprint_height(bridge, 5.5) + 0.1
	ancoras[anchor] = bridge
	var bridge_yaw := _road_yaw_at(bridge)
	# A PONTE GRANDE NA VILA (07/10): a travessia do rio central volta ao modelo de
	# 26/09, maior; o rio grande fica com a ponte de pé e a caída da obra (#94).
	var peca := "ponte_grande" if anchor == "Ponte do rio central" and CatalogoAssets.tem_tripo("ponte_grande") else "ponte"
	# A PONTE AUTORAL (Avulsos/Pontes): como o píer, nunca some; apagada, volta ao
	# cruzamento da rua com o rio.
	var autoral := _avulso(anchor, "construcao", peca, bridge, bridge_yaw, 1.0, false, "Pontes")
	if bool(autoral["exato"]):
		bridge = autoral["pos"]
		bridge_yaw = float(autoral["yaw"])
		ancoras[anchor] = bridge
	var modelo := _construcao(peca, bridge, bridge_yaw)
	# AS MEDIDAS DA PONTE COMO ELA FICOU: as do modelo do Tripo, comprido no eixo
	# maior (11 por 6 só enquanto o GLB não vem). Girar o yaw leva o X local para
	# (cos, -sen) e o Z local para (sen, cos).
	var ao_longo := Vector3(cos(bridge_yaw), 0.0, -sin(bridge_yaw))
	var comprimento := 11.0
	var largura := 6.0
	if modelo != null and modelo.has_meta("limites"):
		var limites: AABB = modelo.get_meta("limites")
		comprimento = maxf(limites.size.x, limites.size.z)
		largura = minf(limites.size.x, limites.size.z)
		if limites.size.z > limites.size.x:
			ao_longo = Vector3(sin(bridge_yaw), 0.0, cos(bridge_yaw))
	pontes[anchor] = {"centro": bridge, "ao_longo": ao_longo, "comprimento": comprimento, "largura": largura}
	# O CORRIMÃO DA PONTE GRANDE, MEDIDO NO GLB (09/10): o tabuleiro dela vai até uns 2,0 u do eixo e os
	# corrimãos e os mourões da cabeceira ficam de 1,4 a 2,3 u. Sem o modelo de pé/caído da pequena
	# (`modelos`), a malha dos moradores não tinha como saber onde ele fica: ela tira as faces do
	# corrimão e deixava o mourão da entrada como chão (`NavegacaoVale._obstaculos_das_pontes`).
	if peca == "ponte_grande":
		pontes[anchor]["corrimao"] = Vector2(0.31, 0.52) * largura
	# A PONTE CAÍDA (#94), no mesmo vão: o modelo de pé fica escondido e sem
	# tabuleiro até a obra `ponte_levantar`, e a caída aparece no lugar — quem
	# troca é o `ponte_vale.gd`, pela obra.
	if modelo != null and peca == "ponte":
		var caida := CatalogoAssets.instanciar("ponte_caida", self, bridge, 1.0, bridge_yaw)
		if caida != null:
			caida.name = "PonteCaidaTripo"
			caida.visible = false
			pontes[anchor]["modelos"] = {"de_pe": modelo, "caida": caida}

	# As pontes seguem o cruzamento da rua com o rio; o editor só as mostra.
	if modelo != null:
		referencias_montadas.append({"chave": peca, "nome": anchor, "transform": modelo.transform})

## O RIO GRANDE NÃO TEM VAU (#81). Havia um, a oito unidades da ponte pela linha
## do rio, "onde se atravessa a pé, com água na canela, enquanto a ponte está
## cercada". Com o jogador nadando, era a trava da jornada aberta: a fazenda do
## convite fica do outro lado. Agora o rio é fundo e a margem norte é barranco
## (`GeoRegionRenderer`, RIO GRANDE): fora da ponte ninguém passa, como no 2D.


func _build_landmark_details() -> void:
	var church: Vector3 = ancoras["Igreja"]
	var church_yaw: float = _lotes.get("Igreja", {}).get("yaw", 0.0)
	_construcao("igreja", church, church_yaw)
	# A capela antiga do vale segue de pé, bem afastada, no alto da rua do mirante.
	if _lotes.has("Capela velha"):
		var velha: Vector3 = _lotes["Capela velha"]["pos"]
		_construcao("capela", velha, float(_lotes["Capela velha"]["yaw"]), 1.0, "Capela velha")
	_construcao("venda", ancoras["Venda do Bar"], 0.0, 1.0, "Venda do Bar")
	_construcao("casa_pasto", ancoras["Restaurante"], 0.0, 1.0, "Restaurante")
	var pier: Vector3 = _region.get_feature_center("Pier", "poi")
	var pier_origin := pier
	var pier_yaw := 0.0
	var pier_direction := Vector3.FORWARD
	var acesso_pier: PackedVector2Array = _region.shore_access_route("Pier")
	if acesso_pier.size() >= 2:
		# Alinha o modelo ao acesso e leva a maior parte dele para dentro d'água.
		var eixo := (acesso_pier[acesso_pier.size() - 1] - acesso_pier[0]).normalized()
		var centro := (acesso_pier[0] + acesso_pier[acesso_pier.size() - 1]) * 0.5 + eixo * 5.0
		pier_origin = Vector3(centro.x, pier.y, centro.y)
		pier_direction = Vector3(eixo.x, 0.0, eixo.y)
		pier_yaw = atan2(eixo.x, eixo.y)
	else:
		pier_direction = (pier - _region.get_feature_center("Praça", "poi")).normalized()
		pier_origin = pier + pier_direction * 9.0
		pier_yaw = atan2(pier_direction.x, pier_direction.z)
	pier_yaw += PI
	# O PÍER AUTORAL: posição e giro do grupo Avulsos; as âncoras (piso, direção,
	# lado) saem dele, então pote, peixe, vara e candeeiro padrão o acompanham.
	var pier_autoral := _avulso("Píer", "construcao", "pier", pier_origin, pier_yaw, 1.0, false, "Píer")
	if bool(pier_autoral["exato"]):
		pier_origin = pier_autoral["pos"]
		pier_yaw = float(pier_autoral["yaw"])
		pier_direction = Vector3(-sin(pier_yaw), 0.0, -cos(pier_yaw))
	ancoras["Pier"] = pier_origin
	var pier_base := ground_position(pier_origin, maxf(pier_origin.y - ground_height_at(pier_origin), 0.0))
	var pier_floor_top := pier_base.y + float(CatalogoAssets.PECAS["pier"].get("piso", 0.0)) + 0.16
	ancoras["PierPiso"] = Vector3(pier_base.x, pier_floor_top, pier_base.z)
	ancoras["PierDirecao"] = pier_direction
	ancoras["PierLado"] = Vector3(cos(pier_yaw), 0.0, -sin(pier_yaw))
	# A PISTA DA CORRIDA E A AREIA (playtest de 07/10). O passo "correr" da chegada
	# apontava o píer, e o marcador caía em cima do Tonho — "isso tá confuso para o
	# jogador": a seta agora aponta um ponto em terra, estrada adentro, a uns doze
	# passos da cabeça do píer ("corra até ali"). E na chegada o Tonho espera na
	# AREIA, ao lado do píer, para o tabuado não ficar cheio (ele volta à rotina
	# dele depois): o primeiro ponto em terra firme, de um lado ou do outro.
	var para_a_terra := -pier_direction
	var cabeca: Vector3 = pier_origin + para_a_terra * 8.5
	ancoras["Corrida"] = _ponto_em_terra([cabeca + para_a_terra * 12.0, cabeca + para_a_terra * 8.0, cabeca + para_a_terra * 5.0], cabeca)
	var lado: Vector3 = ancoras["PierLado"]
	ancoras["Areia"] = _ponto_em_terra([cabeca + para_a_terra * 3.0 + lado * 4.5, cabeca + para_a_terra * 3.0 - lado * 4.5,
		cabeca + para_a_terra * 5.0 + lado * 3.0, cabeca + para_a_terra * 5.0 - lado * 3.0], ancoras["Corrida"])
	_construcao("pier", pier_origin, pier_yaw)
	_erguer_ponte(_region.get_feature_center("Ponte", "poi"), "Ponte")
	var central_bridge := _central_road_river_crossing()
	if central_bridge.is_finite():
		_erguer_ponte(central_bridge, "Ponte do rio central")
	else:
		push_warning("Não foi encontrado o cruzamento da Rua Principal com o rio central.")
	var lookout: Vector3 = _region.get_feature_center("Mirante", "poi")
	lookout.y = _footprint_height(lookout, 4.3) + 0.02
	ancoras["Mirante"] = lookout
	_construcao("mirante", lookout, 0.0)
	var cemetery: Vector3 = _region.get_feature_center("Cemitério", "poi")
	ancoras["Cemitério"] = cemetery
	_assentar_as_covas(cemetery)
	_capelinha_do_cemiterio(cemetery)
	var pedras := _avulso("Pedras", "adereco", "pedras", _region.get_feature_center("Pedras", "poi"), 0.4, 1.4, false, "Marcos")
	var stones: Vector3 = pedras["pos"]
	ancoras["Pedras"] = stones
	_adereco_avulso(pedras)


## Pé de cada árvore (plantadas, mata e coqueiros): decalque de terra escura, folhas
## caídas e raízes (base_arvore_v1.png) deitado no chão, maior quanto mais grosso o
## tronco, em blocos de MultiMesh como a mata. Sem ele o tronco parece pousado na grama.
const BASE_ARVORE := preload("res://assets/prototipo_3d/materiais/base_arvore_v1.png")
const BASE_ARVORE_AREIA := preload("res://assets/prototipo_3d/materiais/base_arvore_areia_v1.png")


func _build_bases_das_arvores() -> void:
	# O chão pinta a copa de cada árvore (folhiço embaixo, verde-mata ao longe) e as
	# trilhas de pé da porta de cada casa até a rua: o mapa de solo da região
	# (docs/mundo/SOLO_E_FRANJAS.md). Aqui, porque é quando as árvores e as casas
	# já existem todas.
	var todas := arvores()
	var portas: Array[Vector2] = []
	for nome_lote in _lotes:
		if not ancoras.has(nome_lote) or not ancoras.has(String(nome_lote) + "Frente"):
			continue
		var centro: Vector3 = ancoras[nome_lote]
		var frente: Vector3 = ancoras[String(nome_lote) + "Frente"]
		var porta := centro + frente * _raio_do_lote(String(_lotes[nome_lote].get("chave", ""))) * 0.55
		portas.append(Vector2(porta.x, porta.z))
	_region.pintar_vida(todas, portas)
	# Um decalque por tipo de chão: terra e folhas na grama, areia revolvida na praia
	# (a base escura sobre a areia clara destoava). Só nas árvores nomeadas e nas da
	# areia: o pé das ~6 mil da mata já é o folhiço do chão, e os decalques, sem LOD,
	# viravam pontos escuros cintilando no morro ao longe.
	var por_chao := {"grama": [BASE_ARVORE, [] as Array[Transform3D]], "areia": [BASE_ARVORE_AREIA, [] as Array[Transform3D]]}
	var rng := RandomNumberGenerator.new()
	rng.seed = 1887
	for indice in todas.size():
		var arvore: Dictionary = todas[indice]
		var tamanho := clampf(float(arvore["raio"]) * 9.0, 1.8, 5.0)
		var pos: Vector3 = arvore["pos"]
		var chao := "areia" if _region.surface_at(pos) == "areia" else "grama"
		var giro_sorteado := rng.randf() * TAU
		if indice >= _arvores_nomeadas.size() and chao != "areia":
			continue
		var giro := Basis(Vector3.UP, giro_sorteado).scaled(Vector3(tamanho, 1.0, tamanho))
		(por_chao[chao][1] as Array[Transform3D]).append(Transform3D(giro, pos + Vector3(0.0, 0.035, 0.0)))
	for chao in por_chao:
		var transforms: Array[Transform3D] = por_chao[chao][1]
		if transforms.is_empty():
			continue
		var placa := PlaneMesh.new()
		placa.size = Vector2.ONE
		var material := StandardMaterial3D.new()
		material.albedo_texture = por_chao[chao][0]
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.35
		material.roughness = 1.0
		placa.material = material
		_region._multimesh_em_blocos("Pé das árvores (%s)" % chao, placa, transforms)


## As pedras do lugar: o afloramento claro em camadas no marco "Pedras" da costa e as
## lajes escuras de recife no raso em frente, que a maré baixa expõe. Só no estilo
## Tripo (GLBs pedras_praia/pedra_mare); sem eles, nada muda.
func _build_pedras() -> void:
	var marco: Vector3 = _region.get_feature_center("Pedras", "poi")
	if marco == Vector3.ZERO:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1108
	if CatalogoAssets.tem_tripo("pedras_praia"):
		# O marco do KML fica no mato; as pedras reais estão na areia, junto da água:
		# desce até o ponto da costa mais próximo e recua um pouco para a areia.
		var costa: PackedVector2Array = _region._coast
		var m2 := Vector2(marco.x, marco.z)
		var na_costa := m2
		var menor := INF
		for i in costa.size() - 1:
			var q := Geometry2D.get_closest_point_to_segment(m2, costa[i], costa[i + 1])
			if q.distance_to(m2) < menor:
				menor = q.distance_to(m2)
				na_costa = q
		var para_terra := (m2 - na_costa).normalized() if menor > 0.01 else Vector2.ZERO
		var na_areia := na_costa + para_terra * 3.0
		marco = Vector3(na_areia.x, 0.0, na_areia.y)
		# Pedras editáveis (Avulsos/Pedras): o sorteio continua igual, para as demais
		# não mudarem de lugar; a posição autoral, quando existe, prevalece.
		var grande := _avulso("Pedra da praia", "adereco", "pedras_praia", ground_position(marco), rng.randf_range(0.0, TAU), 1.0, true, "Pedras")
		if bool(grande["visivel"]):
			var pedra := CatalogoAssets.instanciar("pedras_praia", self, grande["pos"], float(grande["tamanho"]), float(grande["yaw"]))
			if pedra != null:
				CatalogoAssets.colisao("pedras_praia", pedra, self, grande["pos"], float(grande["tamanho"]), float(grande["yaw"]))
		# Pedras menores espalhadas ao longo da praia, dos dois lados da maior.
		var ao_longo := Vector2(-para_terra.y, para_terra.x)
		for k in 2:
			var passo := ao_longo * (rng.randf_range(5.0, 9.0) * (1.0 if k == 0 else -1.0)) + para_terra * rng.randf_range(-1.0, 2.0)
			var vizinho := ground_position(marco + Vector3(passo.x, 0, passo.y))
			var tamanho := rng.randf_range(0.45, 0.65)
			var menor_pedra := _avulso("Pedra da praia %d" % (k + 2), "item", "pedras_praia", vizinho, rng.randf_range(0.0, TAU), tamanho, true, "Pedras")
			_item_avulso(menor_pedra)
	if not CatalogoAssets.tem_tripo("pedra_mare"):
		return
	# Lajes no raso: procura pontos com pouca lâmina d'água mar adentro do marco.
	var para_o_mar := (marco - ground_position(Vector3.ZERO)).normalized()
	var postas := 0
	for tentativa in 60:
		if postas >= 4:
			break
		var ponto := marco + para_o_mar * rng.randf_range(6.0, 30.0) + Vector3(rng.randf_range(-14.0, 14.0), 0, rng.randf_range(-14.0, 14.0))
		var lamina := water_depth_at(ponto)
		if lamina < 0.06 or lamina > 0.5 or _region._is_on_land(ponto):
			continue
		var pos := Vector3(ponto.x, water_level() - lamina - 0.05, ponto.z)
		postas += 1
		var laje := _avulso("Pedra da maré %d" % postas, "item", "pedra_mare", pos, rng.randf_range(0.0, TAU), rng.randf_range(0.7, 1.2), false, "Pedras")
		if bool(laje["visivel"]):
			CatalogoAssets.instanciar("pedra_mare", self, laje["pos"], float(laje["tamanho"]), float(laje["yaw"]))


## AS CLAREIRAS-DESTAQUE DA MATA: a metade das árvores que saiu da mata deu lugar
## a clareiras isoladas (`GeoRegionRenderer.clareiras_da_mata`, planejadas em
## data/mapas/clareiras_da_mata.json), e cada uma é um destaque: UMA árvore de
## espécie diferente no centro, no modelo cheio do catálogo (cortável, com a
## colisão do tronco), ou, em duas delas, uma casa de taipa isolada com o
## terreiro, e pedras em volta, com colisão. A trilha de terra até a rua e o chão
## de cada uma já foram pintados no mapa de solo pela região. As peças são os
## GLBs do Tripo.
const CASA_DA_CLAREIRA_TERREIRO := 1.6


func _build_clareiras_da_mata() -> void:
	if _region == null:
		return
	for clareira: Dictionary in _region.clareiras_da_mata:
		var centro: Vector2 = clareira["centro"]
		var casa := String(clareira.get("casa", ""))
		if casa != "" and CatalogoAssets.tem_tripo(casa):
			_casa_isolada_da_clareira(casa, centro, float(clareira["giro"]))
		elif String(clareira["especie"]) != "" and CatalogoAssets.tem_tripo(String(clareira["especie"])):
			# Posição exata: o JSON já escolheu o chão (e a mata não plantou nada ali).
			_arvore(String(clareira["especie"]), Vector3(centro.x, 0.0, centro.y), float(clareira["escala"]), float(clareira["giro"]), true)
		for pedra: Dictionary in clareira["pedras"]:
			var chave := String(pedra["tipo"])
			if not CatalogoAssets.tem_tripo(chave):
				continue
			var chao := ground_position(Vector3(centro.x + float(pedra["dx"]), 0.0, centro.y + float(pedra["dz"])))
			var tamanho := float(pedra["escala"])
			var modelo := CatalogoAssets.instanciar(chave, self, chao, tamanho, float(pedra["giro"]))
			if modelo != null:
				CatalogoAssets.colisao(chave, modelo, self, chao, tamanho, float(pedra["giro"]))


## A casa de taipa do meio de uma clareira, de porta para a trilha: como a
## capelinha do cemitério, assentada no alicerce e com o terreiro de chão batido
## drapeado no terreno. Sem ficha de morador, mas com cômodo de dentro como toda casa:
## entra em `construcoes` e `ancoras` como "Casa da clareira N" (`Interiores`).
var _casas_da_clareira := 0


func _casa_isolada_da_clareira(chave: String, centro: Vector2, yaw: float) -> void:
	var chao := ground_position(Vector3(centro.x, 0.0, centro.y))
	var modelo := CatalogoAssets.instanciar(chave, self, chao, 1.0, yaw)
	if modelo == null:
		return
	var limites: AABB = modelo.get_meta("limites")
	var assentada := _support_house(chao, Vector2(limites.size.x, limites.size.z), yaw, chave)
	modelo.position.y += assentada.y - chao.y
	var corpo := CatalogoAssets.colisao(chave, modelo, self, assentada, 1.0, yaw)
	_casas_da_clareira += 1
	var nome_da_casa := "Casa da clareira %d" % _casas_da_clareira
	ancoras[nome_da_casa] = assentada
	ancoras[nome_da_casa + "Frente"] = Vector3(sin(yaw), 0.0, cos(yaw))
	construcoes[nome_da_casa] = {"modelo": modelo, "colisao": corpo, "chave": chave}
	# O terreiro: a pegada da casa mais uma beirada, no giro dela.
	var meio := Vector2(limites.size.x, limites.size.z) * 0.5 + Vector2.ONE * CASA_DA_CLAREIRA_TERREIRO
	var cantos := PackedVector2Array()
	for canto in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		cantos.append(centro + (canto * meio).rotated(-yaw))
	_region._add_polygon("Terreiro da clareira", cantos, 0.03, Color("958d79"), false, _terreiro_material())
	# Lote tomado: o que se planta depois não nasce dentro dela.
	_house_sites.append({"position": assentada, "radius": maxf(limites.size.x, limites.size.z) * 0.5 + 2.0})


## Canoas fundeadas no raso diante da vila (canoas.gd), só com o mar de fundo real.
func _build_canoas() -> void:
	if not is_finite(water_level()) or not ancoras.has("PierPiso"):
		return
	var canoas := Canoas.new()
	canoas.name = "Canoas"
	add_child(canoas)
	canoas.montar(_region._coast, ancoras["PierPiso"], ancoras["PierDirecao"], water_level())
	_build_cardume()


## Cardume ao lado do píer (cardume.gd), onde a água tem de 1 a 3 m.
func _build_cardume() -> void:
	var pier: Vector3 = ancoras["PierPiso"]
	var mar_adentro: Vector3 = ancoras["PierDirecao"]
	var lado := Vector3(-mar_adentro.z, 0.0, mar_adentro.x)
	for afastamento in [5.0, -5.0, 8.0, -8.0]:
		for adiante in [4.0, 8.0, 12.0]:
			var centro: Vector3 = pier + lado * afastamento + mar_adentro * adiante
			var fundo := water_depth_at(centro)
			if fundo >= 0.25 and fundo <= 0.75:
				var cardume := Cardume.new()
				cardume.name = "Cardume"
				add_child(cardume)
				cardume.montar(Vector3(centro.x, water_level(), centro.z), water_level(), fundo)
				return


func _build_pecas() -> void:
	# Peças soltas do 2D (gerador_mundo.gd ADORNOS): poço e bancos na praça, cruzeiro na
	# igreja, varal, lenha e pote na casa de taipa, carroça na fazenda.
	var poco := _avulso("Poço", "adereco", "poco", ground_position(Vector3(4.2, 0, 5.4)), 0.6, 1.0, true, "Praça")
	ancoras["Poço"] = poco["pos"]
	_adereco_avulso(poco)
	_adereco_avulso(_avulso("Banco 1", "adereco", "banco", _u(Vector3(-4.6, 0, -0.1)), 0.0, 1.0, true, "Praça"))
	_adereco_avulso(_avulso("Banco 2", "adereco", "banco", Vector3(3.2, 0, -7.0), PI, 1.0, true, "Praça"))
	var taipa: Vector3 = ancoras.get("Casa de taipa", _u(Vector3(-52, 0, -27)))
	# Adereços e itens das construções (varal, lenha, pote, cruzeiro, machado...).
	# O CRUZEIRO é marco de fé (#52), e marco tem âncora: _montar_pecas a registra
	# onde o cruzeiro autoral ficar; sem cruzeiro na composição, fica o ponto padrão.
	_montar_pecas(["adereco", "item"])
	if not ancoras.has("Cruzeiro"):
		ancoras["Cruzeiro"] = ground_position(_na_casa("Igreja", Vector3(0, 0, 9.0)))
	var farm: Vector3 = _region.get_feature_center("Fazenda", "area")
	_adereco_avulso(_avulso("Carroça", "adereco", "carroca", ground_position(farm + Vector3(8.5, 0, -5.5)), -0.6, 1.0, true, "Fazenda"))
	_adereco_avulso(_avulso("Pote do píer", "adereco", "pote", _posicao_no_pier(-1.8, -3.0), 0.0, 1.0, false, "Píer"))
	# Itens de mão espalhados como cenário.
	_item_avulso(_avulso("Enxada", "item", "enxada", farm + Vector3(5.6, 0.0, 1.2), 1.2, 1.0, true, "Fazenda"))
	_item_avulso(_avulso("Balde", "item", "balde", ancoras["Poço"] + Vector3(1.3, 0, 0.4), 0.0, 1.0, true, "Praça"))
	_item_avulso(_avulso("Peixe", "item", "peixe", _posicao_no_pier(1.2, 2.0), 1.0, 1.0, false, "Píer"))
	_montar_avulsos_extras(["adereco", "item", "construcao"])


## O primeiro dos `candidatos` que é terra firme, no chão; sem nenhum, `senao` no chão.
func _ponto_em_terra(candidatos: Array, senao: Vector3) -> Vector3:
	for ponto: Vector3 in candidatos:
		if is_on_land(ponto):
			return ground_position(ponto, 0.0)
	return ground_position(senao, 0.0)


func _posicao_no_pier(lateral: float, longitudinal: float) -> Vector3:
	var piso: Vector3 = ancoras.get("PierPiso", ancoras.get("Pier", Vector3.ZERO))
	var direcao: Vector3 = ancoras.get("PierDirecao", Vector3.FORWARD)
	var lado: Vector3 = ancoras.get("PierLado", Vector3(direcao.z, 0.0, -direcao.x))
	return piso + lado * lateral + direcao * longitudinal


## Luzes de 1887: lampiões a óleo nas esquinas da Praça, candeeiros nas portas, fogueira
## no terreiro e velas nas janelas. Acendem ao entardecer e apagam ao amanhecer.
func _build_luzes_epoca() -> void:
	_luzes = LuzesEpoca.new()
	_luzes.name = "LuzesDeEpoca"
	add_child(_luzes)
	var praca := ground_position(Vector3.ZERO)
	var taipa: Vector3 = ancoras.get("Casa de taipa", _u(Vector3(-52, 0, -27)))
	var farm: Vector3 = _region.get_feature_center("Fazenda", "area")
	var lampiao := 0
	for corner in [Vector3(-9.0, 0, 8.5), Vector3(7.5, 0, -12.0), Vector3(8.0, 0, 9.5)]:
		lampiao += 1
		_luz_avulsa(_avulso("Lampião da praça %d" % lampiao, "lampiao", "lampiao_poste", ground_position(praca + corner), 0.0, 1.0, true, "Praça"))
	# Lampião da igreja, candeeiros das portas e velas nas janelas das construções.
	_montar_pecas(["candeeiro", "lampiao", "luz_janela"])
	var luz_no_pier := _posicao_no_pier(0.0, 2.0)
	luz_no_pier.y += 1.6
	var modelo_luz_no_pier := _posicao_no_pier(0.3, 2.0) + Vector3.UP * 1.5
	_luz_avulsa(_avulso("Candeeiro do píer", "candeeiro", "candeeiro", modelo_luz_no_pier, 0.0, 1.0, false, "Píer"), luz_no_pier)
	# O lajedo de trabalho ocupa (8, 3) e seu modelo se estende além da colisão.
	# A fogueira fica no terreiro, com folga visível entre as toras e o rochedo.
	var fogueira := _avulso("Fogueira da fazenda", "fogueira", "fogueira", ground_position(farm + Vector3(19.0, 0, 4.0)), 0.0, 1.0, true, "Fazenda")
	ancoras["Fogueira"] = fogueira["pos"]
	_luz_avulsa(fogueira)
	_montar_avulsos_extras(["lampiao", "candeeiro", "fogueira", "luz_janela"])
	# O fogo do terreiro de santo, aceso à noite como o da fazenda.
	if is_instance_valid(_fogo_do_terreiro):
		_luzes.fogueira(_fogo_do_terreiro.global_position, _fogo_do_terreiro)
	_luzes.aplicar_hora(Dia.hora)


func _node_bounds(node: Node3D) -> AABB:
	var combined := AABB()
	var has_bounds := false
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var relative_transform := node.global_transform.affine_inverse() * mesh_instance.global_transform
		var bounds := relative_transform * mesh_instance.get_aabb()
		combined = combined.merge(bounds) if has_bounds else bounds
		has_bounds = true
	assert(has_bounds, "A casa importada precisa conter uma malha 3D")
	return combined


## `barra_camera`: o corpo barra também o braço da câmera (`camadas.gd`).
func _box(size: Vector3, position: Vector3, color: Color, solid: bool = false, material_override: Material = null, yaw: float = 0.0, barra_camera: bool = false) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var instance := _mesh(box, position, color, material_override)
	instance.rotation.y = yaw
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		_body(shape, position, "", yaw, barra_camera)
	return instance


func _mesh(mesh: Mesh, position: Vector3, color: Color, material_override: Material = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	if material_override != null:
		instance.material_override = material_override
	else:
		if not _materials.has(color):
			var material := StandardMaterial3D.new()
			material.albedo_color = color
			material.roughness = 0.9
			_materials[color] = material
		instance.material_override = _materials[color] as StandardMaterial3D
	add_child(instance)
	return instance


func _body(shape: Shape3D, position: Vector3, body_name: String = "", yaw: float = 0.0, barra_camera: bool = false) -> void:
	var body := StaticBody3D.new()
	if barra_camera:
		body.collision_layer = Camadas.MUNDO_E_CAMERA
	if not body_name.is_empty():
		body.name = body_name
	body.position = position
	body.rotation.y = yaw
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


# --- os marcos de fé (#52) -------------------------------------------------------

## O TERREIRO E A GAMELEIRA, os dois marcos de fé que o vale não tinha (o
## cruzeiro, a igreja, a capela velha e o cemitério já estavam). Feitos SÓ com o
## que o catálogo tem — a casa de taipa, o pote, a fogueira, a moita e a árvore
## da mata larga, que o almanaque chama de gameleira —; os dois mastros com
## pano branco do terreiro e as fitas no tronco da gameleira, que o 2D descreve,
## chegaram do Tripo no lote de 03/10/2026.
## Por código só o chão: o terreiro de chão batido e o monte de concha, que são
## relevo, como o terreno.
func _build_marcos_de_fe() -> void:
	_build_terreiro()
	_build_gameleira()


## "Taipa caiada, porta fechada, e potes de barro alinhados na parede." A casa
## de frente para a rua, que fica a leste; o terreiro de chão batido na frente
## dela, com o fogo; e uma linha de árvores entre o terreiro e a rua — "a casa
## está atrás da linha de árvores".
func _build_terreiro() -> void:
	var centro := ground_position(_u(TERREIRO_M))
	ancoras["Terreiro"] = centro
	var frente := Vector3.RIGHT
	var lado := Vector3.BACK
	var giro := atan2(frente.x, frente.z)
	ancoras["TerreiroFrente"] = frente
	# O chão batido, drapeado no terreno como o terreiro das casas.
	var cantos := PackedVector2Array()
	for canto in [Vector2(-5.5, -5.0), Vector2(5.5, -5.0), Vector2(5.5, 4.5), Vector2(-5.5, 4.5)]:
		var ponto: Vector3 = centro + lado * canto.x + frente * canto.y
		cantos.append(Vector2(ponto.x, ponto.z))
	_region._add_polygon("Terreiro de santo", cantos, 0.03, Color("958d79"), false, _terreiro_material())
	# A casa, menor que a de morar, atrás do terreiro.
	var casa := ground_position(centro - frente * 3.6)
	var modelo := CatalogoAssets.instanciar("casa_taipa", self, casa, 0.72, giro)
	if modelo != null:
		CatalogoAssets.colisao("casa_taipa", modelo, self, casa, 0.72, giro)
	else:
		push_error("Casa do terreiro de santo sem o GLB casa_taipa no catálogo.")
	# Os potes de barro alinhados na parede da frente.
	for i in 4:
		var na_parede: Vector3 = casa + frente * 2.4 + lado * (-1.8 + float(i) * 1.2)
		_adereco("pote", ground_position(na_parede), giro + float(i), 0.62)
	# O fogo, no meio do terreiro.
	_fogo_do_terreiro = _adereco("fogueira", ground_position(centro + frente * 1.0), giro)
	# OS DOIS MASTROS COM PANO BRANCO, um de cada lado da entrada do terreiro,
	# do lado da rua — de onde se chega.
	for sinal in [-1.0, 1.0]:
		var pe_do_mastro := ground_position(centro + frente * 3.9 + lado * sinal * 3.8)
		var mastro := CatalogoAssets.instanciar("mastro_pano", self, pe_do_mastro, 1.0, giro)
		if mastro != null:
			CatalogoAssets.colisao("mastro_pano", mastro, self, pe_do_mastro, 1.0, giro)
	# A linha de árvores entre o terreiro e a rua, com moita nos vãos: de quem
	# passa na rua, a casa fica atrás dela.
	var especies := ["mata_alta", "jaqueira", "mata_larga", "embauba", "mata_alta"]
	for i in especies.size():
		var onde: Vector3 = centro + frente * 8.5 + lado * (-8.0 + float(i) * 4.0)
		_arvore(str(especies[i]), onde, 0.9 + 0.08 * float(i % 3), float(i) * 1.7)
	for i in 4:
		var no_vao: Vector3 = centro + frente * (9.5 + 0.6 * float(i % 2)) + lado * (-6.0 + float(i) * 4.0)
		_adereco("moita", ground_position(no_vao), float(i) * 2.1, 1.35)


## "A árvore é maior do que qualquer coisa que o arraial construiu. As raízes
## descem por cima de um monte baixo e branco": o sambaqui, monte de concha, e a
## gameleira em cima dele, com potes de barro entre as raízes.
## A árvore não entra na lista das árvores nomeadas: não é lenha nem ficha de
## almanaque — "a gameleira é morada de Iroko, e não se corta".
## O SAMBAQUI: o meio-eixo do domo (raio e altura) e quanto dele fica enterrado.
## Enterrado assim, a borda sobe a uns 40 graus — rampa que se anda (o chão do
## corpo vai até 46), e não degrau.
const RAIO_DO_SAMBAQUI := 5.0
const ALTURA_DO_SAMBAQUI := 1.5
const ENTERRADO := 0.5
## Onde o pano das fitas é amarrado, do PÉ da árvore para cima: no tronco liso, acima das
## sapopemas e abaixo dos galhos. Na gameleira de 11 m (#228) o tronco é limpo, com uns 1,2 de raio,
## entre 2,05 e 2,55 m (medido no GLB em 09/10/2026); abaixo, até 1,7 m, as sapopemas ainda abrem a
## 2,5 de raio: foi medir nelas, com a faixa larga de antes (±1,2), que deixava o pano boiando longe
## do tronco. O raio se mede nessa faixa (ALTURA_DAS_FITAS ± MEIA_FAIXA_DAS_FITAS), e o alto do pano
## fica no alto dela.
const ALTURA_DAS_FITAS := 2.3
const MEIA_FAIXA_DAS_FITAS := 0.25
## A escala do modelo da gameleira: 1,0 sobre os 11 m do catálogo, a mesma altura da mata alta.
## Era 1,3 sobre 14 m (18,2 m): esmagava o vale.
const GAMELEIRA_TAMANHO := 1.0


## O RAIO DO TRONCO a `altura` acima de `centro`: os vértices numa faixa estreita (MEIA_FAIXA_DAS_FITAS
## para cada lado), sem os galhos nem as sapopemas (longe do eixo, ou noutra altura), e o raio é o
## quase-máximo (90%) das distâncias ao eixo, para um vértice solto não inchar o pano.
func _raio_do_tronco(modelo: Node3D, centro: Vector3, altura: float) -> float:
	var distancias: Array[float] = []
	for no in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := no as MeshInstance3D
		if mi.mesh == null:
			continue
		for superficie in mi.mesh.get_surface_count():
			var vertices: PackedVector3Array = mi.mesh.surface_get_arrays(superficie)[Mesh.ARRAY_VERTEX]
			for v in vertices:
				var global: Vector3 = mi.global_transform * v
				if absf(global.y - centro.y - altura) > MEIA_FAIXA_DAS_FITAS:
					continue
				var d := Vector2(global.x - centro.x, global.z - centro.z).length()
				if d < 2.0:
					distancias.append(d)
	if distancias.is_empty():
		return 0.0
	distancias.sort()
	return distancias[int(floor(float(distancias.size() - 1) * 0.9))]


## O PÉ DO TRONCO de um modelo: o meio dos vértices mais baixos, no mundo. As
## raízes se abrem para todo lado, e o meio delas é o tronco.
func _pe_do_tronco(modelo: Node3D) -> Vector3:
	var pontos: Array[Vector3] = []
	var mais_baixo := INF
	for no in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := no as MeshInstance3D
		if mi.mesh == null:
			continue
		for superficie in mi.mesh.get_surface_count():
			var vertices: PackedVector3Array = mi.mesh.surface_get_arrays(superficie)[Mesh.ARRAY_VERTEX]
			for v in vertices:
				var global: Vector3 = mi.global_transform * v
				pontos.append(global)
				mais_baixo = minf(mais_baixo, global.y)
	if pontos.is_empty():
		return Vector3.INF
	var soma := Vector3.ZERO
	var quantos := 0
	for p in pontos:
		if p.y < mais_baixo + 1.2:
			soma += p
			quantos += 1
	return soma / float(quantos) if quantos > 0 else Vector3.INF


## CONCHA, E NÃO REBOCO: um salpicado de dois tons, que de perto se lê como
## milhões de conchas e de longe como um monte claro.
func _material_de_concha() -> StandardMaterial3D:
	var ruido := FastNoiseLite.new()
	ruido.noise_type = FastNoiseLite.TYPE_CELLULAR
	ruido.frequency = 0.03
	ruido.seed = 1887
	var cores := Gradient.new()
	cores.set_color(0, Color("6f6757"))
	cores.set_color(1, Color("cdc6b2"))
	var textura := NoiseTexture2D.new()
	textura.noise = ruido
	textura.seamless = true
	textura.color_ramp = cores
	var material := StandardMaterial3D.new()
	material.albedo_texture = textura
	material.uv1_scale = Vector3(2.0, 2.0, 2.0)
	material.roughness = 0.95
	return material


func _build_gameleira() -> void:
	var chao := ground_position(_u(GAMELEIRA_M))
	ancoras["Gameleira"] = chao
	# O SAMBAQUI: um domo baixo e largo, quase todo enterrado, para a borda ser
	# rampa e não degrau (um corpo sobe por ela andando).
	var domo := SphereMesh.new()
	domo.radius = RAIO_DO_SAMBAQUI
	domo.height = ALTURA_DO_SAMBAQUI * 2.0
	domo.radial_segments = 28
	domo.rings = 10
	var monte := MeshInstance3D.new()
	monte.name = "Sambaqui"
	monte.mesh = domo
	monte.material_override = _material_de_concha()
	monte.position = chao - Vector3.UP * ENTERRADO
	add_child(monte)
	var corpo := StaticBody3D.new()
	corpo.name = "SambaquiColisao"
	var forma := CollisionShape3D.new()
	# CONVEXA, e não malha: o domo é convexo, e a forma convexa empurra para
	# fora quem nasce dentro dela (um save no alto do monte, assentado no
	# terreno por baixo dele); a malha deixava o corpo enterrado no sambaqui.
	forma.shape = domo.create_convex_shape()
	corpo.add_child(forma)
	corpo.position = monte.position
	add_child(corpo)
	var topo := chao + Vector3.UP * (ALTURA_DO_SAMBAQUI - ENTERRADO)
	ancoras["Gameleira"] = topo
	# MAIOR QUE A MATA EM VOLTA: a gameleira é "maior do que qualquer coisa que
	# o arraial construiu". Tem modelo próprio (`gameleira`, 11 m, com as
	# sapopemas): é a única, e a mata em volta é de jatobá e jequitibá.
	var tamanho := GAMELEIRA_TAMANHO
	# O PÉ DA ÁRVORE É O CHÃO, e não o alto do monte (#228). As sapopemas se abrem a uns 5 m do
	# tronco, quase o raio do monte, e o monte cai de 1 m no centro a zero na borda: com o pé no
	# alto dele, as pontas das raízes ficavam 1 m acima da areia, pousadas numa bandeja com sombra
	# por baixo. Com o pé no chão (o platô em volta é plano), as raízes nascem da areia, e o monte
	# de concha cobre o miolo delas — "as raízes descem por cima de um monte baixo e branco".
	var pe_da_arvore := Vector3(topo.x, chao.y - _region.ARVORE_AFUNDADA, topo.z)
	var arvore := CatalogoAssets.instanciar("gameleira", self, pe_da_arvore, tamanho, 0.7)
	if arvore != null:
		# O TRONCO NO MEIO DO MONTE: o pivô do modelo não é o pé do tronco, e
		# a árvore nascia ao lado do sambaqui em vez de em cima dele.
		var pe := _pe_do_tronco(arvore)
		if pe.is_finite():
			arvore.global_position += Vector3(topo.x - pe.x, 0.0, topo.z - pe.z)
		CatalogoAssets.colisao("gameleira", arvore, self, pe_da_arvore, tamanho, 0.7)
		# AS FITAS NO TRONCO: o pano branco amarrado em volta dele, com as
		# fitas coloridas pendendo — "a gameleira é morada de Iroko". Acima
		# das sapopemas, no trecho limpo do tronco (ALTURA_DAS_FITAS), e na
		# medida do tronco ali, um tanto folgada.
		var raio := _raio_do_tronco(arvore, pe_da_arvore, ALTURA_DAS_FITAS)
		if raio > 0.1:
			var roda := (raio + 0.15) * 2.0
			var fitas := CatalogoAssets.instanciar("fitas_gameleira", self, pe_da_arvore, roda / float(CatalogoAssets.PECAS["fitas_gameleira"]["largura"]), 0.0)
			if fitas != null:
				# O pano é o alto da peça; as fitas pendem dele.
				var alto: float = (fitas.get_meta("limites") as AABB).size.y
				fitas.global_position.y += ALTURA_DAS_FITAS + MEIA_FAIXA_DAS_FITAS - alto
	else:
		push_error("Gameleira sem GLB no catálogo.")
	# Os potes de barro entre as raízes, em cima do monte: o pote do catálogo.
	var raio_do_tronco := float(CatalogoAssets.PECAS["gameleira"].get("tronco", 1.2)) * tamanho
	for i in 4:
		var angulo := TAU * float(i) / 4.0 + 0.9
		var raio := raio_do_tronco + 1.3
		var onde: Vector3 = topo + Vector3(cos(angulo), 0.0, sin(angulo)) * raio
		# Em cima do monte, que ali já desceu um tanto.
		var no_monte := ALTURA_DO_SAMBAQUI * sqrt(maxf(0.0, 1.0 - pow(raio / RAIO_DO_SAMBAQUI, 2.0))) - ENTERRADO
		_adereco("pote", Vector3(onde.x, chao.y + no_monte, onde.z), angulo, 0.5)
