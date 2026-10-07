extends RefCounted
## PEÇAS DISTANTES: o que o vale desenha no lugar de uma casa ou de uma árvore
## nomeada depois de ela passar do alcance (`CatalogoAssets.dar_alcance`).
##
## A MATA JÁ FAZ ISSO (`copas_distantes.gd`) e deu certo: o bloco de árvores some a
## 170 u e uma copa de 64 triângulos entra exatamente onde ele sai. As casas e as
## árvores plantadas uma a uma não tinham nada disso: 28 construções de 10 mil
## triângulos e 50 árvores de 10 a 20 mil eram desenhadas inteiras do mirante ao
## fim da baía, a 400 u, onde uma casa tem 15 pixels de largura. Aqui elas ganham
## o mesmo irmão:
##
##   - CASA: uma caixa de parede e um telhado de duas águas (14 triângulos), nas
##     proporções e nas cores MEDIDAS no GLB (`CASAS`, tirado por
##     tools/prototipo_3d/medir_cores_das_casas.py: a média da textura nas faces
##     de parede e nas de telhado, o beiral e a pegada do corpo). Não é arte nova
##     nem enfeite: é o mesmo recurso técnico da copa, a mancha de cor e o contorno
##     que se leem a 150 u, e é o que a regra dos dois estilos permite (a copa também
##     é procedural dentro do Tripo);
##   - ÁRVORE NOMEADA: a copa low-poly da mata (`CopasDistantes`), na cor da espécie.
##
## O SUBSTITUTO É FILHO DO MODELO (e não irmão dele): move-se com ele quando o
## prédio é assentado (`_construcao` sobe o nó depois de instanciar), some com ele
## quando a árvore é cortada e encolhe e cresce com ele (`crescer_arvore`). E é um
## MultiMeshInstance3D, e não um MeshInstance3D, de propósito: tudo o que mede ou
## varre a casca atrás de malha (`CatalogoAssets.limites`, `Interiores._malhas_da_casca`,
## o toco do corte, a extração do sobrevoo) procura MeshInstance3D, e uma caixa
## dentro da casca falsearia os raios que medem o cômodo.
##
## A TROCA: o modelo DESVANECE (`FADE_SELF`) da distância do corte até ela mais a margem
## (15 u), e o substituto aparece, seco e sem margem, no começo dessa faixa, por baixo
## do modelo que ainda se vê e que o encobre: nenhum dos dois some antes de o outro estar
## lá, e não há pulo. E vai até FIM, o mesmo das copas da mata. Sem sombra: o sol só
## sombreia até 70 u (`ceu_vale.gd`).
##
## POR QUE NÃO A TROCA SECA COM MARGEM DOS DOIS LADOS, COMO A DA MATA. Com `FADE_DISABLED`
## e margem o renderizador faz histerese: cada um muda de estado só ao passar de
## `corte - margem` ou de `corte + margem`, e uma peça que nasce (o vale que monta, o jogo
## que carrega) com a câmera DENTRO dessa faixa não tem estado nenhum: nem o modelo nem o
## substituto aparecem, até a câmera sair da faixa. Medido com a GPU
## (tools/prototipo_3d/medir_lod_das_pecas.gd --modo=estado): a casa que nasce a 150 u do
## corte de 143 u desenha 0 triângulos, e só volta aos 165 u. Sem margem (seca) ou com
## desvanecer não há estado: o que se vê depende só da distância de agora.
##
## MODO MAPA: câmera ortográfica (o mapa grande, o do menu, a foto do minimapa) a
## 3.000 u deixaria tudo "longe". `modo_mapa` tira o corte dos modelos e esconde os
## substitutos, como o renderizador faz com a mata (`_atualizar_lod_da_camera`).

const Copas := preload("res://scripts/prototipo_3d/copas_distantes.gd")

## Grupo dos modelos que ganharam alcance (o modo mapa percorre só ele).
const GRUPO := "lod_das_pecas"
## O nome do substituto, filho do modelo.
const NOME := "PecaDistante"
## Até onde o substituto se vê (u): o mesmo das copas da mata.
const FIM := Copas.FIM

## Cor e proporção de cada construção, medidas no GLB (sRGB): a parede e a telha
## (média da textura nas faces de uma e de outra), o `beiral` (altura em que o telhado
## começa, em fração da altura total) e o `corpo_x`/`corpo_z` (onde ficam as paredes,
## em fração da caixa do modelo; o telhado cobre a caixa inteira).
## Para refazer: python tools/prototipo_3d/medir_cores_das_casas.py
const CASAS := {
	"cadeia": {"parede": Color("#cbaa82"), "telha": Color("#8f4a22"), "beiral": 0.67, "corpo_x": [0.09, 0.91], "corpo_z": [0.12, 0.90]},
	"capela": {"parede": Color("#bcae9a"), "telha": Color("#9e4f2d"), "beiral": 0.51, "corpo_x": [0.08, 0.95], "corpo_z": [0.07, 0.86]},
	"capelinha": {"parede": Color("#c99e70"), "telha": Color("#894d29"), "beiral": 0.46, "corpo_x": [0.01, 0.99], "corpo_z": [0.06, 0.95]},
	"casa_carro_quebrado": {"parede": Color("#c3ac95"), "telha": Color("#a26035"), "beiral": 0.63, "corpo_x": [0.08, 0.92], "corpo_z": [0.06, 0.93]},
	"casa_farinha": {"parede": Color("#a8784c"), "telha": Color("#984928"), "beiral": 0.52, "corpo_x": [0.05, 0.95], "corpo_z": [0.08, 0.94]},
	"casa_meia_agua": {"parede": Color("#a1866b"), "telha": Color("#94441d"), "beiral": 0.70, "corpo_x": [0.11, 0.90], "corpo_z": [0.08, 0.91]},
	"casa_palha": {"parede": Color("#ac6a38"), "telha": Color("#a96833"), "beiral": 0.56, "corpo_x": [0.14, 0.87], "corpo_z": [0.21, 0.83]},
	"casa_paroquial": {"parede": Color("#d9cab8"), "telha": Color("#853d16"), "beiral": 0.69, "corpo_x": [0.05, 0.96], "corpo_z": [0.04, 0.96]},
	"casa_pasto": {"parede": Color("#b9a18b"), "telha": Color("#b46e3f"), "beiral": 0.50, "corpo_x": [0.06, 0.96], "corpo_z": [0.00, 0.94]},
	"casa_pescador": {"parede": Color("#9f6832"), "telha": Color("#85532d"), "beiral": 0.49, "corpo_x": [0.03, 0.98], "corpo_z": [0.08, 0.91]},
	"casa_taipa": {"parede": Color("#a58d78"), "telha": Color("#7d5139"), "beiral": 0.62, "corpo_x": [0.10, 0.91], "corpo_z": [0.02, 0.92]},
	"casa_taipa_azul": {"parede": Color("#ba967c"), "telha": Color("#c24c2f"), "beiral": 0.58, "corpo_x": [0.05, 0.97], "corpo_z": [0.10, 0.90]},
	"casa_taipa_ocre": {"parede": Color("#cc8a2f"), "telha": Color("#a6421e"), "beiral": 0.65, "corpo_x": [0.06, 0.94], "corpo_z": [0.09, 0.91]},
	"casa_taipa_rosa": {"parede": Color("#c97358"), "telha": Color("#a9451f"), "beiral": 0.68, "corpo_x": [0.07, 0.93], "corpo_z": [0.04, 0.94]},
	"casa_taipa_verde": {"parede": Color("#9ab13c"), "telha": Color("#94221f"), "beiral": 0.79, "corpo_x": [0.10, 0.90], "corpo_z": [0.06, 0.88]},
	"casa_varanda": {"parede": Color("#c3a894"), "telha": Color("#964f2f"), "beiral": 0.72, "corpo_x": [0.05, 0.95], "corpo_z": [0.17, 0.95]},
	"casarao_fazenda": {"parede": Color("#988560"), "telha": Color("#994029"), "beiral": 0.50, "corpo_x": [0.04, 0.97], "corpo_z": [0.03, 0.93]},
	"igreja": {"parede": Color("#bba68f"), "telha": Color("#a95d3a"), "beiral": 0.44, "corpo_x": [0.03, 0.98], "corpo_z": [0.02, 0.92]},
	"sobrado": {"parede": Color("#ceb496"), "telha": Color("#a5572c"), "beiral": 0.56, "corpo_x": [0.06, 0.91], "corpo_z": [0.07, 0.95]},
	"venda": {"parede": Color("#a08570"), "telha": Color("#9e4426"), "beiral": 0.53, "corpo_x": [0.03, 0.98], "corpo_z": [0.07, 0.97]},
}
## O telhado encolhe um pouco da caixa (o beiral do GLB afina nas pontas) e a parede, um
## pouco para dentro da medida: a caixa fica POR DENTRO da casa, e na faixa em que o modelo
## desvanece por cima dela as faces dos dois não brigam (z-fighting).
const ENCOLHE_O_TELHADO := 0.03
const ENCOLHE_O_CORPO := 0.015
## A gable (empena) é da cor da parede, um tom abaixo (fica na sombra do beiral).
const ESCURECE_A_EMPENA := 0.9

static var _malhas: Dictionary = {}
static var _material_de_casa: StandardMaterial3D = null


## A construção tem substituto de longe?
static func tem_casa(chave: String) -> bool:
	return CASAS.has(chave)


## O substituto de uma CONSTRUÇÃO: a caixa de parede e telhado de duas águas, no
## espaço local do modelo (`caixa` é a dele, antes da escala), entrando a `de` u.
static func casa(chave: String, caixa: AABB, de: float) -> MultiMeshInstance3D:
	if not CASAS.has(chave) or caixa.size.x <= 0.0 or caixa.size.z <= 0.0:
		return null
	return _no(malha_da_casa(chave, caixa), Transform3D.IDENTITY, null, de)


## O substituto de uma ÁRVORE NOMEADA: a copa low-poly da mata na cor da espécie.
static func copa(chave: String, caixa: AABB, de: float) -> MultiMeshInstance3D:
	if caixa.size.y <= 0.0:
		return null
	return _no(Copas.malha(), forma_da_copa(chave, caixa), Copas.cor_da_instancia(chave, 1.0), de)


## A copa dentro da caixa do modelo: a elipsoide da espécie (`CopasDistantes.FORMAS`)
## com os raios nos DOIS eixos da caixa, e não no maior dos dois como na mata (a
## bananeira e o ipê são chatos: uma copa redonda saía da árvore em Z).
static func forma_da_copa(chave: String, caixa: AABB) -> Transform3D:
	var f: Array = Copas.FORMAS.get(chave, Copas.FORMA_DE_ARVORE)
	var altura := maxf(caixa.size.y, 0.001)
	var centro := Vector3(caixa.position.x + caixa.size.x * 0.5, caixa.position.y + altura * float(f[0]), caixa.position.z + caixa.size.z * 0.5)
	return Transform3D(Basis.from_scale(Vector3(caixa.size.x * float(f[2]), altura * float(f[1]), caixa.size.z * float(f[2]))), centro)


## A malha da casa (uma por tipo de construção, compartilhada por todas as casas
## do tipo): 4 paredes, 2 águas e 2 empenas, 14 triângulos, cor de vértice.
static func malha_da_casa(chave: String, caixa: AABB) -> ArrayMesh:
	var registro := "%s@%s" % [chave, str(caixa)]
	if _malhas.has(registro):
		return _malhas[registro]
	var dados: Dictionary = CASAS[chave]
	var parede: Color = dados["parede"]
	var telha: Color = dados["telha"]
	var empena := Color(parede.r * ESCURECE_A_EMPENA, parede.g * ESCURECE_A_EMPENA, parede.b * ESCURECE_A_EMPENA)
	var cx: Array = dados["corpo_x"]
	var cz: Array = dados["corpo_z"]
	var x0 := caixa.position.x + caixa.size.x * (float(cx[0]) + ENCOLHE_O_CORPO)
	var x1 := caixa.position.x + caixa.size.x * (float(cx[1]) - ENCOLHE_O_CORPO)
	var z0 := caixa.position.z + caixa.size.z * (float(cz[0]) + ENCOLHE_O_CORPO)
	var z1 := caixa.position.z + caixa.size.z * (float(cz[1]) - ENCOLHE_O_CORPO)
	var pe := caixa.position.y
	var beiral := pe + caixa.size.y * float(dados["beiral"])
	var cume := caixa.end.y
	var tx0 := caixa.position.x + caixa.size.x * ENCOLHE_O_TELHADO
	var tx1 := caixa.end.x - caixa.size.x * ENCOLHE_O_TELHADO
	var tz0 := caixa.position.z + caixa.size.z * ENCOLHE_O_TELHADO
	var tz1 := caixa.end.z - caixa.size.z * ENCOLHE_O_TELHADO
	var pontos := PackedVector3Array()
	var normais := PackedVector3Array()
	var cores := PackedColorArray()
	# As quatro paredes, de fora para fora.
	_quadro(pontos, normais, cores, [Vector3(x1, pe, z0), Vector3(x1, pe, z1), Vector3(x1, beiral, z1), Vector3(x1, beiral, z0)], Vector3.RIGHT, parede)
	_quadro(pontos, normais, cores, [Vector3(x0, pe, z1), Vector3(x0, pe, z0), Vector3(x0, beiral, z0), Vector3(x0, beiral, z1)], Vector3.LEFT, parede)
	_quadro(pontos, normais, cores, [Vector3(x1, pe, z1), Vector3(x0, pe, z1), Vector3(x0, beiral, z1), Vector3(x1, beiral, z1)], Vector3.BACK, parede)
	_quadro(pontos, normais, cores, [Vector3(x0, pe, z0), Vector3(x1, pe, z0), Vector3(x1, beiral, z0), Vector3(x0, beiral, z0)], Vector3.FORWARD, parede)
	# O telhado: a cumeeira corre pelo lado mais comprido da caixa.
	if caixa.size.x >= caixa.size.z:
		var zm := (tz0 + tz1) * 0.5
		var normal_z1 := Vector3(0.0, tz1 - zm, cume - beiral).normalized()
		var normal_z0 := Vector3(0.0, tz1 - zm, -(cume - beiral)).normalized()
		_quadro(pontos, normais, cores, [Vector3(tx0, beiral, tz1), Vector3(tx1, beiral, tz1), Vector3(tx1, cume, zm), Vector3(tx0, cume, zm)], normal_z1, telha)
		_quadro(pontos, normais, cores, [Vector3(tx1, beiral, tz0), Vector3(tx0, beiral, tz0), Vector3(tx0, cume, zm), Vector3(tx1, cume, zm)], normal_z0, telha)
		_triangulo(pontos, normais, cores, Vector3(tx1, beiral, tz1), Vector3(tx1, beiral, tz0), Vector3(tx1, cume, zm), Vector3.RIGHT, empena)
		_triangulo(pontos, normais, cores, Vector3(tx0, beiral, tz0), Vector3(tx0, beiral, tz1), Vector3(tx0, cume, zm), Vector3.LEFT, empena)
	else:
		var xm := (tx0 + tx1) * 0.5
		var normal_x1 := Vector3(cume - beiral, tx1 - xm, 0.0).normalized()
		var normal_x0 := Vector3(-(cume - beiral), tx1 - xm, 0.0).normalized()
		_quadro(pontos, normais, cores, [Vector3(tx1, beiral, tz0), Vector3(tx1, beiral, tz1), Vector3(xm, cume, tz1), Vector3(xm, cume, tz0)], normal_x1, telha)
		_quadro(pontos, normais, cores, [Vector3(tx0, beiral, tz1), Vector3(tx0, beiral, tz0), Vector3(xm, cume, tz0), Vector3(xm, cume, tz1)], normal_x0, telha)
		_triangulo(pontos, normais, cores, Vector3(tx1, beiral, tz1), Vector3(tx0, beiral, tz1), Vector3(xm, cume, tz1), Vector3.BACK, empena)
		_triangulo(pontos, normais, cores, Vector3(tx0, beiral, tz0), Vector3(tx1, beiral, tz0), Vector3(xm, cume, tz0), Vector3.FORWARD, empena)
	var matrizes: Array = []
	matrizes.resize(Mesh.ARRAY_MAX)
	matrizes[Mesh.ARRAY_VERTEX] = pontos
	matrizes[Mesh.ARRAY_NORMAL] = normais
	matrizes[Mesh.ARRAY_COLOR] = cores
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, matrizes)
	malha.surface_set_material(0, material_de_casa())
	_malhas[registro] = malha
	return malha


## Quantos triângulos tem a malha de uma casa (o portão confere o orçamento).
static func triangulos_da_casa(chave: String, caixa: AABB) -> int:
	return malha_da_casa(chave, caixa).surface_get_array_len(0) / 3


## O material único das casas: cor de vértice (sRGB, como a tabela), sem brilho, de
## dois lados (a caixa tem 14 triângulos: o dobro de fragmentos não pesa, e a
## ordem das pontas deixa de importar).
static func material_de_casa() -> StandardMaterial3D:
	if _material_de_casa == null:
		_material_de_casa = StandardMaterial3D.new()
		_material_de_casa.vertex_color_use_as_albedo = true
		_material_de_casa.vertex_color_is_srgb = true
		_material_de_casa.roughness = 1.0
		_material_de_casa.metallic_specular = 0.0
		_material_de_casa.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _material_de_casa


## O nó do substituto: uma MultiMesh de uma instância, entrando a `de` u e saindo a
## FIM, seco e sem margem (sem histerese: ver o alto do arquivo).
static func _no(malha: Mesh, forma: Transform3D, cor: Variant, de: float) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = cor != null
	multimesh.mesh = malha
	multimesh.instance_count = 1
	multimesh.set_instance_transform(0, forma)
	if cor != null:
		multimesh.set_instance_color(0, cor as Color)
	var visual := MultiMeshInstance3D.new()
	visual.name = NOME
	visual.multimesh = multimesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.visibility_range_begin = de
	visual.visibility_range_begin_margin = 0.0
	visual.visibility_range_end = FIM
	visual.visibility_range_end_margin = 0.0
	visual.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	return visual


## Tira o corte dos modelos e esconde os substitutos (`mapa`), ou põe tudo como
## estava. Vale para todo modelo que ganhou alcance e está na árvore.
static func modo_mapa(arvore: SceneTree, mapa: bool) -> void:
	if arvore == null:
		return
	for modelo in arvore.get_nodes_in_group(GRUPO):
		for geometria in geometrias_do_modelo(modelo):
			geometria.visibility_range_end = 0.0 if mapa else float(geometria.get_meta("lod_fim", 0.0))
		var longe := modelo.get_node_or_null(NOME) as Node3D
		if longe != null:
			longe.visible = not mapa


## As geometrias do modelo que o corte vale para: as malhas do GLB, e não o
## substituto, que tem o corte dele.
static func geometrias_do_modelo(modelo: Node) -> Array[GeometryInstance3D]:
	var lista: Array[GeometryInstance3D] = []
	if modelo is GeometryInstance3D:
		lista.append(modelo as GeometryInstance3D)
	for filho in modelo.find_children("*", "GeometryInstance3D", true, false):
		if filho.name != NOME:
			lista.append(filho as GeometryInstance3D)
	return lista


## Quadrilátero de `normal` para fora, em dois triângulos de normal chata.
static func _quadro(pontos: PackedVector3Array, normais: PackedVector3Array, cores: PackedColorArray, v: Array, normal: Vector3, cor: Color) -> void:
	_triangulo(pontos, normais, cores, v[0], v[1], v[2], normal, cor)
	_triangulo(pontos, normais, cores, v[0], v[2], v[3], normal, cor)


## Um triângulo com a face para `normal`. O Godot tem como frente a ordem horária
## vista de fora (o produto vetorial aponta para dentro); se a ordem dada sai ao
## contrário, troca duas pontas.
static func _triangulo(pontos: PackedVector3Array, normais: PackedVector3Array, cores: PackedColorArray, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, cor: Color) -> void:
	if (b - a).cross(c - a).dot(normal) > 0.0:
		var t := b
		b = c
		c = t
	for p in [a, b, c]:
		pontos.append(p)
		normais.append(normal)
		cores.append(cor)
