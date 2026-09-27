extends RefCounted
## Mar da baía na preamar: superfície transparente (agua_mar.gdshader) sobre o fundo
## real da carta náutica (leito_mar.gdshader), com a elevação do bloco "bathymetry" do
## cenário (tools/mapas/gerar_batimetria.py). Fora do quadro do mapa, o mesmo fundo
## mostra o continente e a baía até o horizonte. Montado por geo_region_renderer.

const AGUA := preload("res://assets/prototipo_3d/mar/agua_mar.gdshader")
const LEITO := preload("res://assets/prototipo_3d/mar/leito_mar.gdshader")
## Vértices do fundo detalhado: um a cada N células da batimetria.
const CELULAS_POR_VERTICE := 2
## Fundo além da grade: plano grosso que repete a borda da batimetria até o horizonte.
const SUBDIVISOES_DISTANTE := 96
## Camada física só da câmera: a superfície da água barra o braço da câmera (ela não
## mergulha) e não é vista pelo jogador, pelos moradores nem pelos cliques.
const CAMADA_CAMERA_AGUA := 1 << 13
## Folga entre a água e o ponto mais baixo que a câmera alcança.
const FOLGA_CAMERA := 0.2

static var _ruidos: Dictionary = {}
## Batimetria da última montagem, para consultar a lâmina d'água num ponto.
static var _imagem: Image
static var _dados: Dictionary = {}
static var _grade := Rect2()
static var _metros_por_unidade := 4.0


## Monta água, fundo, colisão do fundo e paredes do quadro como filhos de `pai`.
## `nivel` é a altura da superfície, `extensao` o retângulo (unidades, XZ) que a água
## cobre e `quadro` o mundo jogável (o quadro Mapa).
static func montar(pai: Node3D, dados: Dictionary, nivel: float, metros_por_unidade: float, extensao: Rect2, quadro: Rect2) -> void:
	var imagem := elevacao(dados)
	if imagem == null:
		return
	var limites_m: Dictionary = dados["bounds_m"]
	var grade := Rect2(
		Vector2(float(limites_m["min_x"]), float(limites_m["min_z"])) / metros_por_unidade,
		Vector2(float(limites_m["max_x"]) - float(limites_m["min_x"]), float(limites_m["max_z"]) - float(limites_m["min_z"])) / metros_por_unidade)
	_imagem = imagem
	_dados = dados
	_grade = grade
	_metros_por_unidade = metros_por_unidade
	var leito := ShaderMaterial.new()
	leito.shader = LEITO
	leito.set_shader_parameter("elevacao", ImageTexture.create_from_image(imagem))
	leito.set_shader_parameter("ruido", _ruido("leito", 0.02))
	leito.set_shader_parameter("texel", Vector2.ONE / Vector2(imagem.get_size()))
	leito.set_shader_parameter("origem", grade.position)
	leito.set_shader_parameter("tamanho", grade.size)
	leito.set_shader_parameter("elevacao_min_m", float(dados["elevation_min_m"]))
	leito.set_shader_parameter("elevacao_max_m", float(dados["elevation_max_m"]))
	leito.set_shader_parameter("metros_por_unidade", metros_por_unidade)
	var colunas := int(imagem.get_width() / CELULAS_POR_VERTICE)
	var linhas := int(imagem.get_height() / CELULAS_POR_VERTICE)
	_plano(pai, "Fundo do mar", grade, nivel, colunas, linhas, leito)
	var distante := leito.duplicate() as ShaderMaterial
	distante.set_shader_parameter("recortar_grade", true)
	_plano(pai, "Fundo do mar distante", extensao, nivel, SUBDIVISOES_DISTANTE, SUBDIVISOES_DISTANTE, distante)

	var agua := ShaderMaterial.new()
	agua.shader = AGUA
	agua.set_shader_parameter("ondas_a", _ruido("ondas_a", 0.035, true))
	agua.set_shader_parameter("ondas_b", _ruido("ondas_b", 0.05, true))
	agua.set_shader_parameter("ruido", _ruido("espuma", 0.08))
	agua.set_shader_parameter("metros_por_unidade", metros_por_unidade)
	_plano(pai, "Mar", extensao, nivel, 0, 0, agua)

	_colisao_do_fundo(pai, imagem, dados, grade, quadro, nivel, metros_por_unidade)
	_paredes(pai, quadro)
	_superficie_da_camera(pai, nivel)


## Lâmina d'água (m) no ponto XZ em unidades, pela célula mais próxima; negativa em
## terra. NAN antes da montagem ou fora da grade.
static func lamina_em(ponto: Vector2) -> float:
	if _imagem == null or not _grade.has_point(ponto):
		return NAN
	var celula := Vector2i(((ponto - _grade.position) / _grade.size * Vector2(_imagem.get_size())).floor())
	var t := _imagem.get_pixelv(celula.clamp(Vector2i.ZERO, _imagem.get_size() - Vector2i.ONE)).r
	return -lerpf(float(_dados["elevation_min_m"]), float(_dados["elevation_max_m"]), t)


## Elevação acima da preamar, normalizada entre elevation_min_m e elevation_max_m
## (float16 cru, gerado por gerar_batimetria.py), como imagem de um canal.
static func elevacao(dados: Dictionary) -> Image:
	var bytes := FileAccess.get_file_as_bytes(String(dados["data"]))
	var tamanho: Array = dados["size"]
	if bytes.size() != int(tamanho[0]) * int(tamanho[1]) * 2:
		push_error("Batimetria com tamanho inesperado: " + String(dados["data"]))
		return null
	return Image.create_from_data(int(tamanho[0]), int(tamanho[1]), false, Image.FORMAT_RH, bytes)


## Chão do mar para o jogador entrar andando na água: um HeightMapShape3D com as
## células da batimetria que cobrem o quadro. Sob a terra do jogo o fundo fica logo
## abaixo da água, então o terreno continua sendo o chão ali.
static func _colisao_do_fundo(pai: Node3D, imagem: Image, dados: Dictionary, grade: Rect2, quadro: Rect2, nivel: float, metros_por_unidade: float) -> void:
	var celula := grade.size.x / float(imagem.get_width())
	var inicio := Vector2i(((quadro.position - grade.position) / celula).floor()) - Vector2i.ONE
	var fim := Vector2i(((quadro.end - grade.position) / celula).ceil()) + Vector2i.ONE
	inicio = inicio.clamp(Vector2i.ZERO, imagem.get_size() - Vector2i.ONE)
	fim = fim.clamp(Vector2i.ZERO, imagem.get_size() - Vector2i.ONE)
	var recorte := imagem.get_region(Rect2i(inicio, fim - inicio + Vector2i.ONE))
	var forma := HeightMapShape3D.new()
	# A forma usa 1 unidade entre amostras; a escala uniforme do nó leva à célula real,
	# e as alturas já vêm divididas por ela.
	forma.update_map_data_from_image(recorte,
		float(dados["elevation_min_m"]) / metros_por_unidade / celula,
		float(dados["elevation_max_m"]) / metros_por_unidade / celula)
	var corpo := StaticBody3D.new()
	corpo.name = "Chão do mar"
	var colisao := CollisionShape3D.new()
	colisao.shape = forma
	colisao.scale = Vector3.ONE * celula
	corpo.add_child(colisao)
	pai.add_child(corpo)
	# Amostra i fica no centro da célula i da grade; a forma é centrada no nó.
	var centro := grade.position + (Vector2(inicio) + Vector2(recorte.get_size() - Vector2i.ONE) * 0.5 + Vector2(0.5, 0.5)) * celula
	corpo.position = Vector3(centro.x, nivel, centro.y)


static func _superficie_da_camera(pai: Node3D, nivel: float) -> void:
	var corpo := StaticBody3D.new()
	corpo.name = "Superfície para a câmera"
	corpo.collision_layer = CAMADA_CAMERA_AGUA
	corpo.collision_mask = 0
	var colisao := CollisionShape3D.new()
	colisao.shape = WorldBoundaryShape3D.new()
	corpo.add_child(colisao)
	pai.add_child(corpo)
	corpo.position = Vector3(0.0, nivel + FOLGA_CAMERA, 0.0)


## Paredes invisíveis nas quatro bordas do quadro: o mundo jogável é o retângulo 16:9.
static func _paredes(pai: Node3D, quadro: Rect2) -> void:
	var corpo := StaticBody3D.new()
	corpo.name = "Borda do quadro"
	pai.add_child(corpo)
	for lado: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		var forma := WorldBoundaryShape3D.new()
		forma.plane = Plane(Vector3(-lado.x, 0.0, -lado.y), 0.0)
		var colisao := CollisionShape3D.new()
		colisao.shape = forma
		var ponto := quadro.get_center() + lado * quadro.size * 0.5
		colisao.position = Vector3(ponto.x, 0.0, ponto.y)
		corpo.add_child(colisao)


static func _plano(pai: Node3D, nome: String, area: Rect2, altura: float, colunas: int, linhas: int, material: Material) -> void:
	var malha := PlaneMesh.new()
	malha.size = area.size
	malha.subdivide_width = maxi(colunas - 1, 0)
	malha.subdivide_depth = maxi(linhas - 1, 0)
	malha.material = material
	var visual := MeshInstance3D.new()
	visual.name = nome
	visual.mesh = malha
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# O fundo sobe e desce no shader: a caixa de corte precisa abranger o relevo.
	visual.extra_cull_margin = 32.0
	pai.add_child(visual)
	var centro := area.get_center()
	visual.position = Vector3(centro.x, altura, centro.y)


## Ruído sem emenda, gerado uma vez por partida (NoiseTexture2D gera em thread).
static func _ruido(chave: String, frequencia: float, normal: bool = false) -> NoiseTexture2D:
	if _ruidos.has(chave):
		return _ruidos[chave]
	var ruido := FastNoiseLite.new()
	ruido.seed = hash(chave)
	ruido.frequency = frequencia
	ruido.fractal_octaves = 4
	var textura := NoiseTexture2D.new()
	textura.width = 512
	textura.height = 512
	textura.seamless = true
	textura.as_normal_map = normal
	textura.bump_strength = 4.0
	textura.noise = ruido
	_ruidos[chave] = textura
	return textura
