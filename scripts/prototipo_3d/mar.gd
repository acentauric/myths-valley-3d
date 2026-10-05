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
## A camada de tudo o que tem corpo (`camadas.gd`, `MUNDO`).
const CAMADA_MUNDO := 1
## Folga entre a água e o ponto mais baixo que a câmera alcança.
const FOLGA_CAMERA := 0.2

static var _ruidos: Dictionary = {}
## Batimetria da última montagem, para consultar a lâmina d'água num ponto.
static var _imagem: Image
static var _dados: Dictionary = {}
static var _grade := Rect2()
static var _metros_por_unidade := 4.0
## Exagero do relevo que a terra além do quadro recebe (o da região, pai.get_vertical_exaggeration).
static var _exageracao := 1.0
static var _nivel := 0.0


## Monta água, fundo, colisão do fundo e paredes do quadro como filhos de `pai`.
## `nivel` é a altura da superfície, `extensao` o retângulo (unidades, XZ) que a água
## cobre e `quadro` o mundo jogável (o quadro Mapa).
static func montar(pai: Node3D, dados: Dictionary, nivel: float, metros_por_unidade: float, extensao: Rect2, quadro: Rect2, rios: Array[Dictionary] = [], terra: PackedVector2Array = PackedVector2Array()) -> void:
	var imagem := elevacao(dados)
	if imagem == null:
		return
	var limites_m: Dictionary = dados["bounds_m"]
	var grade := Rect2(
		Vector2(float(limites_m["min_x"]), float(limites_m["min_z"])) / metros_por_unidade,
		Vector2(float(limites_m["max_x"]) - float(limites_m["min_x"]), float(limites_m["max_z"]) - float(limites_m["min_z"])) / metros_por_unidade)
	_abrir_calha_na_batimetria(pai, imagem, dados, grade, nivel, metros_por_unidade, rios, terra)
	_imagem = imagem
	_dados = dados
	_grade = grade
	_metros_por_unidade = metros_por_unidade
	_nivel = nivel
	# A terra de fora sobe com o exagero do relevo do jogo: sem ele, degrau na borda.
	_exageracao = float(pai.call("get_vertical_exaggeration")) if pai.has_method("get_vertical_exaggeration") else 1.0
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
	leito.set_shader_parameter("exageracao_vertical", _exageracao)
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
	var mar := _plano(pai, "Mar", extensao, nivel, 0, 0, agua)
	# A superfície sobe e desce com a maré; os materiais recebem os uniforms dela.
	_acompanha_mare(mar, nivel)
	Mare.registrar_material(leito)
	Mare.registrar_material(distante)
	Mare.registrar_material(agua)

	_colisao_do_fundo(pai, imagem, dados, grade, quadro, nivel, metros_por_unidade)
	_paredes(pai, quadro)
	_superficie_da_camera(pai, nivel)


## O mapa de colisão do mar continua sob a terra. Sem esse corte, o jogador
## pisa nele antes de alcançar o novo leito do rio. O mesmo corte na imagem
## mantém o fundo visível abaixo da calha, inclusive na saída para o mar.
static func _abrir_calha_na_batimetria(pai: Node3D, imagem: Image, dados: Dictionary, grade: Rect2, nivel: float, metros_por_unidade: float, rios: Array[Dictionary], terra: PackedVector2Array) -> void:
	if rios.is_empty():
		return
	var image_size := imagem.get_size()
	var cell := grade.size / Vector2(image_size)
	var elevation_min := float(dados["elevation_min_m"])
	var elevation_range := float(dados["elevation_max_m"]) - elevation_min
	for rio in rios:
		var points: PackedVector2Array = rio.points
		if points.size() < 2:
			continue
		var reach := float(rio.width) * 0.5 + maxf(cell.x, cell.y) * 1.5
		var bounds: Rect2 = (rio.bounds as Rect2).grow(reach)
		var from_cell := Vector2i(((bounds.position - grade.position) / cell).floor()).clamp(Vector2i.ZERO, image_size - Vector2i.ONE)
		var to_cell := Vector2i(((bounds.end - grade.position) / cell).ceil()).clamp(Vector2i.ZERO, image_size - Vector2i.ONE)
		for z in range(from_cell.y, to_cell.y + 1):
			for x in range(from_cell.x, to_cell.x + 1):
				var point := grade.position + (Vector2(x, z) + Vector2(0.5, 0.5)) * cell
				if _distance_to_river(point, points) > reach:
					continue
				var in_land := terra.size() >= 3 and Geometry2D.is_point_in_polygon(point, terra)
				var position := Vector3(point.x, 0.0, point.y)
				var floor_height: float = float(pai.call("ground_height_at", position)) - 0.12 if in_land else nivel - 0.32
				var target := clampf(((floor_height - nivel) * metros_por_unidade - elevation_min) / elevation_range, 0.0, 1.0)
				var current := imagem.get_pixel(x, z).r
				if target < current:
					imagem.set_pixel(x, z, Color(target, 0.0, 0.0))


static func _distance_to_river(point: Vector2, path: PackedVector2Array) -> float:
	var closest := INF
	for i in range(path.size() - 1):
		var segment := path[i + 1] - path[i]
		var fraction := clampf((point - path[i]).dot(segment) / maxf(segment.length_squared(), 0.0001), 0.0, 1.0)
		closest = minf(closest, point.distance_to(path[i] + segment * fraction))
	return closest


## Lâmina d'água (m) no ponto XZ em unidades, pela célula mais próxima; negativa em
## terra. NAN antes da montagem ou fora da grade.
static func lamina_em(ponto: Vector2) -> float:
	if _imagem == null or not _grade.has_point(ponto):
		return NAN
	var celula := Vector2i(((ponto - _grade.position) / _grade.size * Vector2(_imagem.get_size())).floor())
	var t := _imagem.get_pixelv(celula.clamp(Vector2i.ZERO, _imagem.get_size() - Vector2i.ONE)).r
	return -lerpf(float(_dados["elevation_min_m"]), float(_dados["elevation_max_m"]), t)


## Altura (u) do fundo desenhado num ponto XZ, como leito_mar.gdshader a calcula:
## textura bilinear e o exagero do relevo só na terra. NAN antes da montagem ou fora da grade.
static func altura_do_fundo(ponto: Vector2) -> float:
	if _imagem == null or not _grade.has_point(ponto):
		return NAN
	var tamanho := Vector2(_imagem.get_size())
	var p := (ponto - _grade.position) / _grade.size * tamanho - Vector2(0.5, 0.5)
	var a := Vector2i(p.floor())
	var f := p - Vector2(a)
	var limite := _imagem.get_size() - Vector2i.ONE
	var t00 := _imagem.get_pixelv(a.clamp(Vector2i.ZERO, limite)).r
	var t10 := _imagem.get_pixelv((a + Vector2i(1, 0)).clamp(Vector2i.ZERO, limite)).r
	var t01 := _imagem.get_pixelv((a + Vector2i(0, 1)).clamp(Vector2i.ZERO, limite)).r
	var t11 := _imagem.get_pixelv((a + Vector2i(1, 1)).clamp(Vector2i.ZERO, limite)).r
	var t := lerpf(lerpf(t00, t10, f.x), lerpf(t01, t11, f.x), f.y)
	var lamina := -lerpf(float(_dados["elevation_min_m"]), float(_dados["elevation_max_m"]), t)
	if lamina < 0.0:
		lamina *= _exageracao
	return _nivel - lamina / _metros_por_unidade


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
	# Chão para o corpo e para a câmera (`camadas.gd`).
	corpo.collision_layer = CAMADA_MUNDO | CAMADA_CAMERA_AGUA
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
	# A barreira da câmera acompanha o nível da maré, senão o braço mergulharia
	# na baixa-mar (ou bateria no ar na volta da enchente).
	_acompanha_mare(corpo, nivel + FOLGA_CAMERA)


## Nó cuja altura segue a maré: o autoload Mare o move a cada quadro (base + offset).
static func _acompanha_mare(no: Node3D, base_y: float) -> void:
	no.set_meta("mare_base_y", base_y)
	no.add_to_group("mare_superficie")


## Paredes invisíveis nas quatro bordas do quadro: o mundo jogável é o retângulo 16:9.
static func _paredes(pai: Node3D, quadro: Rect2) -> void:
	var corpo := StaticBody3D.new()
	corpo.name = "Borda do quadro"
	# A câmera também não sai do quadro (`camadas.gd`).
	corpo.collision_layer = CAMADA_MUNDO | CAMADA_CAMERA_AGUA
	pai.add_child(corpo)
	for lado: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		var forma := WorldBoundaryShape3D.new()
		forma.plane = Plane(Vector3(-lado.x, 0.0, -lado.y), 0.0)
		var colisao := CollisionShape3D.new()
		colisao.shape = forma
		var ponto := quadro.get_center() + lado * quadro.size * 0.5
		colisao.position = Vector3(ponto.x, 0.0, ponto.y)
		corpo.add_child(colisao)


static func _plano(pai: Node3D, nome: String, area: Rect2, altura: float, colunas: int, linhas: int, material: Material) -> MeshInstance3D:
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
	return visual


## Ruído compartilhado para outros materiais de água (o rio usa as mesmas ondas).
static func textura_ruido(chave: String, frequencia: float, normal: bool = false) -> NoiseTexture2D:
	return _ruido(chave, frequencia, normal)


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
