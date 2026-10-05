extends RefCounted
## COPAS DISTANTES: a mata que se vê depois de a árvore sumir.
##
## Cada bloco de 40 u de árvores some a LOD_MATA (280 u) e o chão é desenhado até
## 2.800 u: a serra ficava pelada. Aqui cada bloco que some ganha um IRMÃO, uma
## MultiMesh com uma COPA LOW-POLY (64 triângulos, achatada pela forma da
## espécie) por tronco, que entra exatamente onde a árvore sai — mesma distância
## e mesma margem, sem desvanecimento — e vai até FIM (1.200 u).
##
## POR QUE NÃO O MODELO DE LONGE DO TRIPO EM TODA ÁRVORE. Mais de 6 mil troncos
## ficam além de 280 u: um modelo de 1,1 a 2,1 mil triângulos em cada um daria de
## 7 a 12 milhões de triângulos por quadro, e o vale já anda perto de 20 FPS. A
## copa de 64 faces custa 0,4 M, e a 280 u uma árvore tem 8 a 20 pixels de
## altura: ninguém lê a folha. O que se lê é a MANCHA DE COR e o contorno. Por
## isso a cor da espécie (a da folhagem do GLB, puxada para o verde-copa do
## chão) e a silhueta.
##
## O ANEL DE LONGE DO TRIPO é só para quem NÃO é uma bola: a palmeira e a árvore
## de tronco fino (coqueiro, dendê, piaçava, mangue, castanhola, ingá), que
## sem o tronco viram um pires verde flutuando. São poucas (umas 500) e o modelo
## de longe delas (`*_longe_tripo.glb`) vai de LONGE_ATE_O_TRIPO adiante; depois
## disso a copa low-poly toma o lugar. As outras espécies (jatobá, jequitibá,
## cedro, angico, massaranduba, sapucaia, jenipapo, aroeira...) não têm versão
## de longe: ficam com a copa low-poly na cor da espécie.
##
## CASA COM O CHÃO E COM A NÉVOA. O terreno (`terreno.gdshader`) já pinta a copa no
## chão de 200 a 250 u, em #3E6B34 variando de #2E5229 a #4F7F45, e a névoa do céu
## tinge o que fica longe: a copa daqui usa a mesma família de verdes (a cor da
## espécie mistura-se à do chão em MISTURA_COM_O_CHAO) e é iluminada como
## qualquer malha, então a hora dourada a esquenta junto com o resto. A névoa é
## do ambiente: não há nada dela aqui.
##
## O bloco de copas guarda a forma de cada copa e `Copas.forma` a devolve: o
## corte, o crescimento e a restauração da árvore (`_mostrar_instancia` do
## renderizador) movem a copa junto com a instância da árvore.

## Até onde a copa se vê (u). O chão pintado cuida do resto.
const FIM := 1200.0
## O modelo de longe do Tripo vai do fim da camada de árvores até aqui; daí a
## copa low-poly (a 600 u uma palmeira de 9 m tem menos de 6 pixels de altura).
const LONGE_ATE_O_TRIPO := 600.0
## Espécies que ganham o modelo de longe do Tripo (`<espécie>_longe`) no anel
## perto, no estilo Tripo: as de tronco que a copa sozinha não sustenta.
const COM_MODELO_DE_LONGE := ["coqueiro", "dendezeiro", "piacava", "mangue", "castanhola", "ingazeiro"]
## Quanto da cor do chão entra na cor da espécie (0 = só a espécie).
const MISTURA_COM_O_CHAO := 0.45
const COR_DO_CHAO := Color("3e6b34")
## Variação de brilho de uma copa para outra (± fração).
const VARIACAO := 0.2
## Quanto a cor da copa escurece: o verde da folhagem do GLB é a cor SEM luz, e
## a copa low-poly é lisa e pega o sol inteiro no topo (mais clara do que a
## mata de verdade, que é feita de folhas e sombra entre elas).
const ESCURECE := 0.78
const NOME := "Copa distante"
const SHADER := preload("res://assets/prototipo_3d/materiais/copa_distante.gdshader")

## Cor média da folhagem de cada espécie, medida na textura do GLB (os pixels
## onde o verde manda); as que a medida não pega (flor, folha seca) vão à mão.
const CORES := {
	"mata_alta": Color("12341b"), "mata_larga": Color("314717"), "copa_larga": Color("16311c"),
	"jatoba": Color("16311c"), "sapucaia": Color("36451a"), "jequitiba": Color("162a1c"),
	"cedro": Color("2f5a2a"), "angico": Color("444b22"), "massaranduba": Color("0f2219"),
	"embauba": Color("7a852e"), "aroeira": Color("193112"), "jenipapeiro": Color("4b6611"),
	"piacava": Color("2d430f"), "clusia": Color("304319"), "pitangueira": Color("37540f"),
	"cajueiro": Color("395221"), "ingazeiro": Color("30581f"), "dendezeiro": Color("375513"),
	"jaqueira": Color("1b2e0e"), "mangueira": Color("1b2d0c"), "castanhola": Color("485b0b"),
	"ipe_amarelo": Color("6a7f2f"), "ipe_roxo": Color("3a6b2f"), "pau_brasil": Color("4d6814"),
	"coqueiro": Color("3d4e11"), "mangue": Color("142b13"), "bananeira": Color("416c18"),
	"gameleira": Color("3f4c18"),
}

## A silhueta por espécie, em fração da caixa da malha: [altura do centro,
## raio vertical, raio horizontal]. Palmeira é um penacho no alto; arbusto, uma
## bola baixa; o resto, a copa redonda de árvore.
const FORMA_DE_ARVORE := [0.56, 0.44, 0.42]
const FORMAS := {
	"coqueiro": [0.62, 0.38, 0.3], "dendezeiro": [0.62, 0.38, 0.32], "piacava": [0.6, 0.4, 0.36],
	"bananeira": [0.62, 0.38, 0.4], "mangue": [0.52, 0.48, 0.42], "clusia": [0.52, 0.48, 0.44],
	"pitangueira": [0.52, 0.48, 0.44], "aroeira": [0.54, 0.46, 0.44], "embauba": [0.6, 0.4, 0.4],
	"jatoba": [0.56, 0.44, 0.46], "copa_larga": [0.56, 0.44, 0.46], "jequitiba": [0.58, 0.42, 0.44],
	"mata_larga": [0.54, 0.46, 0.46], "mangueira": [0.54, 0.46, 0.46], "castanhola": [0.54, 0.46, 0.46],
	"cajueiro": [0.5, 0.5, 0.46], "ingazeiro": [0.54, 0.46, 0.45], "jenipapeiro": [0.56, 0.44, 0.44],
}

const _ANEIS := 5
const _FATIAS := 8

static var _malha: ArrayMesh = null
static var _material: ShaderMaterial = null


## A espécie que o nome do bloco diz ("Mata: jatoba 3,4" não: o nome SEM o
## sufixo de bloco, como o renderizador o passa), ou "" para o que não ganha copa
## (sub-bosque, decalque, teste). Os blocos da orla têm nome próprio.
static func especie_do_bloco(nome: String) -> String:
	if nome.begins_with("Mata: "):
		return nome.substr(6)
	if nome.begins_with("Restinga da orla: "):
		return nome.substr(18)
	match nome:
		"Coqueiros da orla":
			return "coqueiro"
		"Manguezal":
			return "mangue"
		"Ingazeiros do rio":
			return "ingazeiro"
	return ""


## Cor da copa da espécie: a da folhagem puxada para o verde do chão.
static func cor_da_especie(especie: String) -> Color:
	var base: Color = CORES.get(especie, COR_DO_CHAO)
	return base.lerp(COR_DO_CHAO, MISTURA_COM_O_CHAO)


## A forma da copa no espaço local da malha da árvore: elipsoide dentro da
## caixa dela. Multiplicada pela transformação da instância dá a copa no mundo.
## `jitter` (0 a 1) alarga um pouco uma copa mais que a outra.
static func forma(especie: String, caixa: AABB, jitter: float = 0.5) -> Transform3D:
	var f: Array = FORMAS.get(especie, FORMA_DE_ARVORE)
	var altura := maxf(caixa.size.y, 0.001)
	var largura := maxf(caixa.size.x, caixa.size.z)
	var centro := Vector3(caixa.position.x + caixa.size.x * 0.5, caixa.position.y + altura * float(f[0]), caixa.position.z + caixa.size.z * 0.5)
	var variacao := 0.9 + 0.2 * jitter
	var raio_h := largura * float(f[2])
	var raios := Vector3(raio_h * variacao, altura * float(f[1]), raio_h * (2.0 - variacao))
	return Transform3D(Basis.from_scale(raios), centro)


## O material único das copas (`copa_distante.gdshader`): cor vinda do vértice
## (escuro embaixo, claro em cima) e da instância, malhada como a copa que o chão
## pinta, sem brilho.
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
	return _material


## A copa unitária: esfera facetada (normais por face) de FATIAS x ANEIS, com
## 64 triângulos, cor de vértice do escuro (pé) ao claro (topo).
static func malha() -> ArrayMesh:
	if _malha != null:
		return _malha
	var pontos := PackedVector3Array()
	var normais := PackedVector3Array()
	var cores := PackedColorArray()
	var grade: Array = []
	for a in range(_ANEIS + 1):
		var fila: Array = []
		var polar := PI * float(a) / float(_ANEIS)
		for f in range(_FATIAS):
			var azimute := TAU * (float(f) + 0.5) / float(_FATIAS)
			fila.append(Vector3(sin(polar) * cos(azimute), cos(polar), sin(polar) * sin(azimute)))
		grade.append(fila)
	for a in range(_ANEIS):
		for f in range(_FATIAS):
			var f2 := (f + 1) % _FATIAS
			var p00: Vector3 = grade[a][f]
			var p01: Vector3 = grade[a][f2]
			var p10: Vector3 = grade[a + 1][f]
			var p11: Vector3 = grade[a + 1][f2]
			if a == 0:
				_triangulo(pontos, normais, cores, p00, p11, p10)
			elif a == _ANEIS - 1:
				_triangulo(pontos, normais, cores, p00, p01, p10)
			else:
				_triangulo(pontos, normais, cores, p00, p01, p10)
				_triangulo(pontos, normais, cores, p01, p11, p10)
	var matrizes: Array = []
	matrizes.resize(Mesh.ARRAY_MAX)
	matrizes[Mesh.ARRAY_VERTEX] = pontos
	matrizes[Mesh.ARRAY_NORMAL] = normais
	matrizes[Mesh.ARRAY_COLOR] = cores
	_malha = ArrayMesh.new()
	_malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, matrizes)
	_malha.surface_set_material(0, material())
	return _malha


static func _triangulo(pontos: PackedVector3Array, normais: PackedVector3Array, cores: PackedColorArray, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 1e-12:
		# Degenerado (o polo): não vira triângulo.
		return
	# A normal da face aponta para fora da esfera.
	if normal.dot(a + b + c) < 0.0:
		var t := b
		b = c
		c = t
		normal = -normal
	normal = normal.normalized()
	for p in [a, b, c]:
		pontos.append(p)
		normais.append(normal)
		# Escuro no pé (sombra da própria copa), claro no topo.
		var luz := remap(clampf((p as Vector3).y, -1.0, 1.0), -1.0, 1.0, 0.7, 1.12)
		cores.append(Color(luz, luz, luz, 1.0))


## Quantos triângulos tem uma copa (o portão confere o orçamento).
static func triangulos_por_copa() -> int:
	return malha().surface_get_array_len(0) / 3


## A cor da instância: a da espécie, escurecida (ver ESCURECE), em linear (o
## shader não converte).
static func cor_da_instancia(especie: String, brilho: float) -> Color:
	var c := cor_da_especie(especie) * (ESCURECE * brilho)
	return Color(clampf(c.r, 0.0, 1.0), clampf(c.g, 0.0, 1.0), clampf(c.b, 0.0, 1.0), 1.0).srgb_to_linear()


## A chave do catálogo da malha de longe da espécie, ou "" (no procedural, nas
## espécies sem versão de longe e nas que ficam com a copa). Só vale para a
## malha que o bloco plantou: `mesh` tem de ser a da espécie (ou a leve dela).
static func malha_de_longe(especie: String, mesh: Mesh) -> Dictionary:
	if not COM_MODELO_DE_LONGE.has(especie) or not CatalogoAssets.tem_tripo(especie + "_longe"):
		return {}
	# A transformação-base da malha plantada: a que o catálogo deu a ela.
	for chave in [especie + "_leve", especie]:
		var da_arvore: Dictionary = CatalogoAssets.malha(chave, 1.0)
		if not da_arvore.is_empty() and da_arvore.mesh == mesh:
			var longe: Dictionary = CatalogoAssets.malha(especie + "_longe", 1.0)
			if longe.is_empty():
				return {}
			# O pé e o giro da árvore (`pose`) ficam; só a base muda da malha de uma
			# para a de outra.
			return {"mesh": longe.mesh, "forma": (da_arvore.base as Transform3D).affine_inverse() * (longe.base as Transform3D)}
	return {}


## As camadas de longe de um bloco de árvores, na ordem em que entram. Cada uma:
## {"visual": MultiMeshInstance3D, "formas": Array[Transform3D]}, com a forma
## de cada instância no espaço da árvore (o corte, o crescimento e a
## restauração reaplicam: instância = transformação da árvore x forma).
##   - no Tripo, a espécie com modelo de longe ganha o dele de `distancia` a
##     LONGE_ATE_O_TRIPO, e a copa low-poly entra depois dele;
##   - as outras, a copa low-poly de `distancia` a FIM.
## `transforms` são as da árvore (a base da malha dentro) e `mesh` a malha dela.
static func montar(nome_do_bloco: String, especie: String, mesh: Mesh, transforms: Array[Transform3D], distancia: float, margem: float) -> Array[Dictionary]:
	var camadas: Array[Dictionary] = []
	var inicio_da_copa := distancia
	var longe := malha_de_longe(especie, mesh)
	if not longe.is_empty():
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = longe.mesh
		multimesh.instance_count = transforms.size()
		var formas: Array[Transform3D] = []
		for i in range(transforms.size()):
			formas.append(longe.forma)
			multimesh.set_instance_transform(i, transforms[i] * (longe.forma as Transform3D))
		var visual := _visual(NOME + ", modelo", nome_do_bloco, multimesh, distancia, LONGE_ATE_O_TRIPO, margem)
		camadas.append({"visual": visual, "formas": formas})
		inicio_da_copa = LONGE_ATE_O_TRIPO
	var caixa := mesh.get_aabb()
	var copas := MultiMesh.new()
	copas.transform_format = MultiMesh.TRANSFORM_3D
	copas.use_colors = true
	copas.mesh = malha()
	copas.instance_count = transforms.size()
	var formas_da_copa: Array[Transform3D] = []
	for i in range(transforms.size()):
		var t: Transform3D = transforms[i]
		# Número de 0 a 1 que só depende de onde a árvore está: a mesma copa em toda montagem.
		var sorte := _sorte(t.origin)
		var f := forma(especie, caixa, sorte)
		formas_da_copa.append(f)
		copas.set_instance_transform(i, t * f)
		copas.set_instance_color(i, cor_da_instancia(especie, 1.0 + VARIACAO * (sorte * 2.0 - 1.0)))
	camadas.append({"visual": _visual(NOME, nome_do_bloco, copas, inicio_da_copa, FIM, margem), "formas": formas_da_copa})
	return camadas


## O nó de uma camada: entra a `de` u e sai a `ate`, com a mesma margem dos
## dois lados e sem fade — a troca é seca e exata, como a da árvore.
static func _visual(prefixo: String, nome_do_bloco: String, multimesh: MultiMesh, de: float, ate: float, margem: float) -> MultiMeshInstance3D:
	var visual := MultiMeshInstance3D.new()
	visual.name = "%s: %s" % [prefixo, nome_do_bloco]
	visual.multimesh = multimesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.visibility_range_begin = de
	visual.visibility_range_begin_margin = margem
	visual.visibility_range_end = ate
	visual.visibility_range_end_margin = margem if ate < FIM else 0.0
	visual.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	return visual


static func _sorte(p: Vector3) -> float:
	var h := (int(floor(p.x * 7.3)) * 73856093) ^ (int(floor(p.z * 7.3)) * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65536.0
