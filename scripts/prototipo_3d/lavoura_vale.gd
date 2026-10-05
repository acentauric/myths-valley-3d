extends Node3D
## A LAVOURA DA CASA — a fazenda do jogador, na frente da casa herdada (#8).
##
## "Implemente também a casa do jogador, com sua fazenda." A regra é a do 2D
## (`plantacao.gd`, trazida inteira); o que este nó faz é o vale: uma grade de
## leitos no chão aberto do roçado, depois da cana e da lenha
## (`world_builder.LAVOURA_NA_CASA`), o desenho de cada leito e o gesto do E.
##
## O GESTO É O DO 2D (`Mundo._usar_no_rocado`): quem decide é o que está na mão.
##
##   enxada     ara o chão bruto
##   balde      molha o leito arado
##   semente    planta no leito arado e vazio, e gasta uma
##   mão livre  colhe o que está no ponto
##
## e cada gesto que não cabe DIZ por quê, como lá: "Chão bruto. A enxada abre o
## leito." O dia que vira (`Relogio.dia_comecou`, que a cama, a queda e o
## desmaio das duas disparam) faz crescer o que foi regado.
##
## O DESENHO DA PLANTA sai do catálogo, no estilo escolhido, com as peças que
## ele já tem: o capim é o broto, o canteiro de mandioca é a mandioca crescida,
## a cana é a cana, e as três fruteiras são as árvores da vila, pequenas. Não há
## peça nova nem desenho procedural novo; o chão arado é chão, como o terreno.

const Plantacao = preload("res://scripts/prototipo_3d/plantacao.gd")
const CatalogoAssets = preload("res://scripts/prototipo_3d/catalogo_assets.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const DicaTecla = preload("res://scripts/prototipo_3d/dica_tecla.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const FocoDoE = preload("res://scripts/prototipo_3d/foco_do_e.gd")
const TEXTOS := "res://data/lavoura.json"

## A grade: colunas de lado a lado (X da casa), linhas para a frente (Z).
const COLUNAS := 6
const LINHAS := 4
const ESPACO := 1.2
const LADO_DO_LEITO := 1.0
## De quão longe do campo a tecla ainda vale, e a altura dela.
const MARGEM := 0.7
const ALTURA_DA_DICA := 1.2
## Com que se rega: o balde d'água, como no 2D.
const DE_REGAR := ["balde"]

## O desenho de cada estágio: a peça do catálogo e o tamanho dela.
const ESTAGIOS := {
	"mandioca": [["capim", 0.3], ["capim", 0.6], ["mandioca_canteiro", 0.2], ["mandioca_canteiro", 0.3]],
	"milho": [["capim", 0.35], ["capim", 0.7], ["capim", 1.1], ["capim", 1.5]],
	"cana": [["cana", 0.25], ["cana", 0.5], ["cana", 0.75], ["cana", 1.0]],
	"bananeira": [["bananeira", 0.2], ["bananeira", 0.45], ["bananeira", 0.6]],
	"mangueira": [["mangueira", 0.08], ["mangueira", 0.16], ["mangueira", 0.28], ["mangueira", 0.32]],
	"cajueiro": [["cajueiro", 0.12], ["cajueiro", 0.3], ["cajueiro", 0.4]],
}

signal arou
signal plantou
signal regou
signal colheu

var plantacao
var _mundo
var _jogador: Node3D
var _hud
var _textos: Dictionary = {}
var _dica: PanelContainer
## O meio do campo e os eixos dele (a frente da casa).
var _meio := Vector3.ZERO
var _x := Vector3.RIGHT
var _z := Vector3.BACK
## célula -> {"chao": MeshInstance3D, "planta": Node3D, "desenho": String}
var _leitos_3d: Dictionary = {}
var _perto := Vector2i(-1, -1)
var _material_seco: StandardMaterial3D
var _material_molhado: StandardMaterial3D


func configurar(mundo, jogador: Node3D, hud) -> void:
	_mundo = mundo
	_jogador = jogador
	_hud = hud
	add_to_group("lavoura")
	var lido = JSON.parse_string(FileAccess.get_file_as_string(TEXTOS))
	_textos = lido if lido is Dictionary else {}
	_meio = mundo.ancoras.get("Lavoura", Vector3.INF)
	var frente: Vector3 = mundo.ancoras.get("LavouraFrente", Vector3.BACK)
	frente.y = 0.0
	_z = frente.normalized() if frente.length() > 0.01 else Vector3.BACK
	_x = Vector3.UP.cross(_z).normalized()
	plantacao = Plantacao.new(func(celula: Vector2i) -> bool: return na_grade(celula))
	plantacao.mudou.connect(_desenhar)
	if not Relogio.dia_comecou.is_connected(_ao_virar_o_dia):
		Relogio.dia_comecou.connect(_ao_virar_o_dia)
	_material_seco = _terra(Color("6e4f34"))
	_material_molhado = _terra(Color("3f2b1c"), 0.55)
	if _meio.is_finite():
		_montar_o_chao()
	if hud != null:
		_dica = DicaTecla.criar(hud.map_layer(), Atalhos.letra("interagir"), "")
		add_to_group(FocoDoE.GRUPO)


## O QUE O E FARIA AQUI, para o foco (`foco_do_e.gd`): o gesto no leito da vez.
func alvo_do_e() -> Dictionary:
	if _perto == Vector2i(-1, -1) or _jogador == null or not _jogador.is_physics_processing():
		return {}
	return {"ponto": posicao_da(_perto)}


func _ao_virar_o_dia(_dia: int, _estacao: int, _ano: int) -> void:
	plantacao.novo_dia()


# --- a grade ---------------------------------------------------------------------

func na_grade(celula: Vector2i) -> bool:
	return celula.x >= 0 and celula.x < COLUNAS and celula.y >= 0 and celula.y < LINHAS


## O meio do leito, no chão.
func posicao_da(celula: Vector2i) -> Vector3:
	var local := Vector2((float(celula.x) - (COLUNAS - 1) * 0.5) * ESPACO, (float(celula.y) - (LINHAS - 1) * 0.5) * ESPACO)
	var ponto := _meio + _x * local.x + _z * local.y
	return _mundo.ground_position(ponto, 0.0) if _mundo != null else ponto


## A célula sob este ponto, ou (-1, -1) fora da grade.
func celula_em(ponto: Vector3) -> Vector2i:
	if not _meio.is_finite():
		return Vector2i(-1, -1)
	var d := ponto - _meio
	var celula := Vector2i(roundi(d.dot(_x) / ESPACO + (COLUNAS - 1) * 0.5), roundi(d.dot(_z) / ESPACO + (LINHAS - 1) * 0.5))
	return celula if na_grade(celula) else Vector2i(-1, -1)


## O jogador está no campo (ou na beira dele)? É onde a tecla é da lavoura, e
## não dos alvos de trabalho em volta (`recursos_3d.gd`).
func no_campo(ponto: Vector3) -> bool:
	if not _meio.is_finite():
		return false
	var d := ponto - _meio
	return absf(d.dot(_x)) <= COLUNAS * ESPACO * 0.5 + MARGEM and absf(d.dot(_z)) <= LINHAS * ESPACO * 0.5 + MARGEM \
		and absf(d.y) < 3.0


# --- o chão e a planta -------------------------------------------------------------

## O CHÃO DE PLANTAR É TERRA DE VERDADE, e o campo tem um CERCADO RASTEIRO.
##
## "Melhore o asset da terra agricultável pelo Pedro e coloque um cercado bem
## rasteiro em volta dessa parte." Eram vinte e quatro caixas chatas de uma cor
## só, de cinco centímetros: de longe, ladrilho. Agora cada leito é um monte de
## terra solta de borda macia, com grão e torrão (`_grao`, `_torrao`); arado,
## ganha três camalhões e os sulcos entre eles (`_malha_do_leito`); molhado,
## escurece e brilha um pouco. E o campo ganha a cerca baixa de vara das roças do
## Recôncavo — a que segura galinha e cabrito, de canela de altura —, com a
## passagem do lado da casa (`_montar_o_cercado`).
func _montar_o_chao() -> void:
	for y in LINHAS:
		for x in COLUNAS:
			var celula := Vector2i(x, y)
			var chao := MeshInstance3D.new()
			chao.name = "Leito_%d_%d" % [x, y]
			chao.mesh = _malha_do_leito(false)
			chao.material_override = _terra_bruta()
			add_child(chao)
			chao.global_position = posicao_da(celula) + Vector3.UP * (ACIMA_DO_CHAO - 0.01)
			chao.global_basis = Basis.looking_at(-_z, Vector3.UP)
			_leitos_3d[celula] = {"chao": chao, "planta": null, "desenho": ""}
	_montar_a_terra_batida()
	_montar_o_cercado()


func _desenhar(celula: Vector2i) -> void:
	if not _leitos_3d.has(celula):
		return
	var leito: Dictionary = _leitos_3d[celula]
	var chao: MeshInstance3D = leito["chao"]
	if plantacao.arado(celula):
		chao.material_override = _material_molhado if plantacao.molhado(celula) else _material_seco
		chao.mesh = _malha_do_leito(true)
	else:
		chao.material_override = _terra_bruta()
		chao.mesh = _malha_do_leito(false)
	var cultura: String = plantacao.cultura_em(celula)
	var desenho := "" if cultura == "" else "%s:%d" % [cultura, plantacao.estagio(celula)]
	if desenho == str(leito["desenho"]):
		return
	if is_instance_valid(leito["planta"]):
		(leito["planta"] as Node).queue_free()
	leito["planta"] = null
	leito["desenho"] = desenho
	if cultura == "":
		return
	leito["planta"] = _planta(cultura, plantacao.estagio(celula), posicao_da(celula) + Vector3.UP * 0.05,
		float(hash("%d,%d" % [celula.x, celula.y]) % 628) / 100.0)


## A planta no estágio dela: a peça do catálogo, ou, no procedural, o broto de
## cone que o roçado já desenhava (`world_builder._build_farm`).
func _planta(cultura: String, qual: int, onde: Vector3, giro: float) -> Node3D:
	var estagios: Array = ESTAGIOS.get(cultura, [])
	if estagios.is_empty():
		return null
	var peca: Array = estagios[clampi(qual, 0, estagios.size() - 1)]
	if Estilo.tripo():
		var modelo := CatalogoAssets.instanciar(str(peca[0]), self, onde, float(peca[1]), giro)
		if modelo != null:
			modelo.name = "Planta_%s" % cultura
			return modelo
	var broto := MeshInstance3D.new()
	broto.name = "Planta_%s" % cultura
	var cone := CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = 0.12 + 0.06 * float(qual)
	cone.height = 0.3 + 0.35 * float(qual)
	cone.radial_segments = 5
	broto.mesh = cone
	var verde := StandardMaterial3D.new()
	verde.albedo_color = Color("8fa85e")
	broto.material_override = verde
	add_child(broto)
	broto.global_position = onde + Vector3.UP * cone.height * 0.5
	return broto


## A TERRA: a cor do estado (solta, arada, molhada) sobre o grão e o torrão, em
## projeção triplanar — os camalhões não esticam a textura. Molhada é menos
## áspera: a água brilha um pouco no sulco.
func _terra(cor: Color, aspereza: float = 0.95) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = cor
	material.albedo_texture = _grao()
	material.normal_enabled = true
	material.normal_texture = _torrao()
	material.normal_scale = 0.9
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * 1.4
	material.roughness = aspereza
	return material


var _material_bruto: StandardMaterial3D


## O chão bruto, ainda sem enxada: terra solta, mais clara e seca.
func _terra_bruta() -> StandardMaterial3D:
	if _material_bruto == null:
		_material_bruto = _terra(Color("8f7552"))
	return _material_bruto


## A TERRA BATIDA DO CAMPO, por baixo dos leitos e entre eles: sem ela, cada
## leito era um ladrilho solto na grama, e o campo não se lia como roça. Segue o
## chão ponto a ponto, um dedo acima dele, até a beira de dentro da cerca.
func _montar_a_terra_batida() -> void:
	var meia_x := COLUNAS * ESPACO * 0.5 + CERCA_FOLGA * 0.6
	var meia_z := LINHAS * ESPACO * 0.5 + CERCA_FOLGA * 0.6
	var partes_x := 28
	var partes_z := 20
	var superficie := SurfaceTool.new()
	superficie.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in partes_x + 1:
		for j in partes_z + 1:
			var no_campo_ := Vector2(lerpf(-meia_x, meia_x, float(i) / partes_x), lerpf(-meia_z, meia_z, float(j) / partes_z))
			superficie.set_uv(Vector2(float(i) / partes_x, float(j) / partes_z))
			# Três dedos acima da conta do chão: a malha da grama fica um tanto
			# acima dela, e a um dedo a terra batida sumia por baixo.
			superficie.add_vertex(_no_chao_do_campo(no_campo_) + Vector3.UP * ACIMA_DO_CHAO)
	for i in partes_x:
		for j in partes_z:
			var a := i * (partes_z + 1) + j
			var b := a + 1
			var c := a + partes_z + 1
			var d := c + 1
			for indice in [a, c, b, b, c, d]:
				superficie.add_index(indice)
	superficie.generate_normals()
	var terra := MeshInstance3D.new()
	terra.name = "TerraBatida"
	terra.mesh = superficie.commit()
	terra.material_override = _terra(Color("7d6447"))
	add_child(terra)
	terra.global_transform = Transform3D.IDENTITY


static var _grao_da_terra: NoiseTexture2D
static var _torrao_da_terra: NoiseTexture2D


## O grão da terra: manchas de célula, do castanho ao claro (o albedo multiplica).
static func _grao() -> Texture2D:
	if _grao_da_terra == null:
		var ruido := FastNoiseLite.new()
		ruido.noise_type = FastNoiseLite.TYPE_CELLULAR
		ruido.frequency = 0.09
		ruido.seed = 1887
		var degrade := Gradient.new()
		degrade.set_color(0, Color(0.6, 0.58, 0.55))
		degrade.set_color(1, Color(1.0, 1.0, 1.0))
		_grao_da_terra = NoiseTexture2D.new()
		_grao_da_terra.width = 256
		_grao_da_terra.height = 256
		_grao_da_terra.seamless = true
		_grao_da_terra.noise = ruido
		_grao_da_terra.color_ramp = degrade
	return _grao_da_terra


## O torrão: o relevo miúdo da terra revolvida, como mapa de normais.
static func _torrao() -> Texture2D:
	if _torrao_da_terra == null:
		var ruido := FastNoiseLite.new()
		ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		ruido.frequency = 0.06
		ruido.fractal_octaves = 4
		ruido.seed = 1888
		_torrao_da_terra = NoiseTexture2D.new()
		_torrao_da_terra.width = 256
		_torrao_da_terra.height = 256
		_torrao_da_terra.seamless = true
		_torrao_da_terra.as_normal_map = true
		_torrao_da_terra.bump_strength = 6.0
		_torrao_da_terra.noise = ruido
	return _torrao_da_terra


## AS DUAS MALHAS DE LEITO, feitas uma vez: o monte solto e o arado.
static var _malhas_do_leito: Dictionary = {}
## Quantos camalhões o leito arado tem, e quanto eles sobem.
const CAMALHOES := 3
const ALTURA_DO_CAMALHAO := 0.05
const ALTURA_DO_MONTE := 0.06
## A terra batida e o pé dos leitos ficam este tanto acima da conta do chão.
const ACIMA_DO_CHAO := 0.035


## O LEITO É UM MONTE DE TERRA DE BORDA MACIA: sobe da borda até um sexto do
## lado para dentro e fica abaulado em cima. Arado, o alto vira CAMALHOES
## camalhões com o sulco entre eles, no sentido da frente da casa. A grade é de
## vinte e quatro por vinte e quatro: macia o bastante para o sulco ser curva.
static func _malha_do_leito(arado: bool) -> ArrayMesh:
	if _malhas_do_leito.has(arado):
		return _malhas_do_leito[arado]
	var partes := 24
	var superficie := SurfaceTool.new()
	superficie.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in partes + 1:
		for j in partes + 1:
			var u := float(i) / partes
			var v := float(j) / partes
			var borda := minf(minf(u, 1.0 - u), minf(v, 1.0 - v))
			var ombro := smoothstep(0.0, 0.17, borda)
			var altura := ALTURA_DO_MONTE * ombro
			if arado:
				# O camalhão é largo e redondo em cima, e o sulco é estreito: o
				# cosseno amaciado (potência abaixo de um), e não em ponta.
				var camalhao := pow(0.5 + 0.5 * cos(TAU * float(CAMALHOES) * (u - 0.5 / float(CAMALHOES))), 0.7)
				altura = (0.03 + ALTURA_DO_CAMALHAO * camalhao) * ombro
			superficie.set_uv(Vector2(u, v))
			superficie.add_vertex(Vector3((u - 0.5) * LADO_DO_LEITO, altura, (v - 0.5) * LADO_DO_LEITO))
	for i in partes:
		for j in partes:
			var a := i * (partes + 1) + j
			var b := a + 1
			var c := a + partes + 1
			var d := c + 1
			for indice in [a, c, b, b, c, d]:
				superficie.add_index(indice)
	superficie.generate_normals()
	var malha := superficie.commit()
	_malhas_do_leito[arado] = malha
	return malha


# --- o cercado ---------------------------------------------------------------------

## O CERCADO RASTEIRO: estacas de vara a cada CERCA_VAO, de canela de altura, e
## duas varas deitadas amarradas nelas — a cerca de faxina da roça. A PASSAGEM
## fica no lado da casa. Tem corpo, e baixo: o jogador e o morador sobem nele
## como num degrau (`DEGRAU`, 0,4) e ninguém fica preso, mas quem vem da casa
## entra pela passagem.
const CERCA_ALTURA := 0.36
## Da beira dos leitos até a cerca, e entre uma estaca e outra.
const CERCA_FOLGA := 0.5
const CERCA_VAO := 0.55
const PASSAGEM := 1.5
const COR_DA_VARA := Color("8a6a46")

## Os lados do cercado já postos, em coordenadas do campo: [de, até] (x, z).
var lados_do_cercado: Array = []


func _montar_o_cercado() -> void:
	var meia_x := COLUNAS * ESPACO * 0.5 + CERCA_FOLGA
	var meia_z := LINHAS * ESPACO * 0.5 + CERCA_FOLGA
	# A casa fica para o -z do campo (ele está na frente dela): a passagem é ali.
	lados_do_cercado = [
		[Vector2(-meia_x, meia_z), Vector2(meia_x, meia_z)],
		[Vector2(meia_x, -meia_z), Vector2(meia_x, meia_z)],
		[Vector2(-meia_x, -meia_z), Vector2(-meia_x, meia_z)],
		[Vector2(-meia_x, -meia_z), Vector2(-PASSAGEM * 0.5, -meia_z)],
		[Vector2(PASSAGEM * 0.5, -meia_z), Vector2(meia_x, -meia_z)],
	]
	var cercado := Node3D.new()
	cercado.name = "Cercado"
	add_child(cercado)
	# As estacas e as varas são postas em coordenadas do mundo.
	cercado.global_transform = Transform3D.IDENTITY
	var vara := StandardMaterial3D.new()
	vara.albedo_color = COR_DA_VARA
	vara.roughness = 0.9
	var estacas: Array[Transform3D] = []
	var deitadas: Array[Transform3D] = []
	var corpo := StaticBody3D.new()
	corpo.name = "CercadoColisao"
	cercado.add_child(corpo)
	var sorte := RandomNumberGenerator.new()
	sorte.seed = 1887
	for lado in lados_do_cercado:
		var de: Vector2 = lado[0]
		var ate: Vector2 = lado[1]
		var vezes := maxi(1, ceili(de.distance_to(ate) / CERCA_VAO))
		var anterior := Vector3.INF
		for k in vezes + 1:
			var no_campo_ := de.lerp(ate, float(k) / float(vezes))
			var pe := _no_chao_do_campo(no_campo_)
			var alta := CERCA_ALTURA + sorte.randf_range(-0.04, 0.05)
			# A escala é do comprimento da própria vara (o eixo dela), e não do mundo.
			var torta := Basis(Vector3.RIGHT, sorte.randf_range(-0.06, 0.06)) * Basis(Vector3.FORWARD, sorte.randf_range(-0.06, 0.06))
			estacas.append(Transform3D(torta * Basis.from_scale(Vector3(1.0, alta, 1.0)), pe + Vector3.UP * alta * 0.5))
			if anterior.is_finite():
				for altura in [0.12, 0.27]:
					var a: Vector3 = anterior + Vector3.UP * altura
					var b: Vector3 = pe + Vector3.UP * altura
					var deitada := Basis(Quaternion(Vector3.UP, (b - a).normalized()))
					deitadas.append(Transform3D(deitada * Basis.from_scale(Vector3(1.0, a.distance_to(b), 1.0)), (a + b) * 0.5))
			anterior = pe
		# O CORPO DO LADO: uma tábua fina da altura da cerca, de ponta a ponta.
		var forma := CollisionShape3D.new()
		var caixa := BoxShape3D.new()
		var de3 := _no_chao_do_campo(de)
		var ate3 := _no_chao_do_campo(ate)
		caixa.size = Vector3(0.08, CERCA_ALTURA, de3.distance_to(ate3))
		forma.shape = caixa
		corpo.add_child(forma)
		var meio := (de3 + ate3) * 0.5 + Vector3.UP * CERCA_ALTURA * 0.5
		forma.global_transform = Transform3D(Basis.looking_at((ate3 - de3).normalized(), Vector3.UP), meio)
	cercado.add_child(_multimalha("Estacas", _cilindro(0.032, 1.0), vara, estacas))
	cercado.add_child(_multimalha("Varas", _cilindro(0.018, 1.0), vara, deitadas))


## Um ponto do campo (x pelo lado da casa, z pela frente dela), no chão.
func _no_chao_do_campo(ponto: Vector2) -> Vector3:
	var no_mundo := _meio + _x * ponto.x + _z * ponto.y
	return _mundo.ground_position(no_mundo, 0.0) if _mundo != null else no_mundo


static func _cilindro(raio: float, altura: float) -> CylinderMesh:
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = raio * 0.85
	cilindro.bottom_radius = raio
	cilindro.height = altura
	cilindro.radial_segments = 6
	cilindro.rings = 1
	return cilindro


func _multimalha(nome: String, malha: Mesh, material: Material, onde: Array[Transform3D]) -> MultiMeshInstance3D:
	var muitas := MultiMesh.new()
	muitas.transform_format = MultiMesh.TRANSFORM_3D
	muitas.mesh = malha
	muitas.instance_count = onde.size()
	for i in onde.size():
		muitas.set_instance_transform(i, onde[i])
	var instancia := MultiMeshInstance3D.new()
	instancia.name = nome
	instancia.multimesh = muitas
	instancia.material_override = material
	return instancia


# --- a tecla -------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _jogador == null or _dica == null:
		return
	var camera := get_viewport().get_camera_3d()
	var em_jogo: bool = camera != null and camera == _jogador.get("camera")
	_perto = Vector2i(-1, -1)
	if em_jogo and not Dialogo.ativo and no_campo(_jogador.global_position):
		_perto = leito_da_vez()
	if _perto == Vector2i(-1, -1) or not FocoDoE.e_dele(self):
		_dica.visible = false
		return
	DicaTecla.mostrar_em(_dica, camera, posicao_da(_perto) + Vector3.UP * ALTURA_DA_DICA, acao(_perto))


## O leito em que o gesto cai: o da frente do corpo, ou o de baixo dele.
func leito_da_vez() -> Vector2i:
	var visual: Node3D = _jogador.get("visual")
	var adiante := Vector3.ZERO
	if visual != null:
		adiante = visual.global_basis.z
		adiante.y = 0.0
		adiante = adiante.normalized() * 0.75 if adiante.length() > 0.01 else Vector3.ZERO
	var celula := celula_em(_jogador.global_position + adiante)
	if celula == Vector2i(-1, -1):
		celula = celula_em(_jogador.global_position)
	return celula


## O que a tecla diz no leito, pelo que está na mão.
func acao(celula: Vector2i) -> String:
	var mao := Inventario.na_mao()
	if mao == "enxada":
		return _texto("arar")
	if mao in DE_REGAR:
		return _texto("regar")
	if Catalogo.tipo(mao) == "semente":
		return _texto("plantar") % Catalogo.nome(mao)
	if plantacao.maduro(celula):
		return _texto("colher") % _nome_da_cultura(plantacao.cultura_em(celula))
	return _texto("olhar")


func _unhandled_key_input(event: InputEvent) -> void:
	if _perto == Vector2i(-1, -1):
		return
	if not (event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == Atalhos.tecla("interagir")):
		return
	if Dialogo.ocupado() or not _jogador.is_physics_processing() or not FocoDoE.e_dele(self):
		return
	get_viewport().set_input_as_handled()
	usar(_perto)


## O GESTO NO LEITO, pelo que está na mão — `Mundo._usar_no_rocado` do 2D.
func usar(celula: Vector2i) -> void:
	if not na_grade(celula):
		return
	var mao := Inventario.na_mao()
	if mao == "enxada" or mao in DE_REGAR or Catalogo.tipo(mao) == "ferramenta":
		if mao == "enxada" and not plantacao.arado(celula):
			if not Energia.gastar("arar"):
				_avisar("cansaco")
				return
			if plantacao.arar(celula):
				Audio.efeito("arar")
				Talentos.ganhar("arar")
				arou.emit()
		elif mao in DE_REGAR and plantacao.arado(celula) and not plantacao.molhado(celula):
			if not Energia.gastar("regar"):
				_avisar("cansaco")
				return
			if plantacao.regar(celula):
				Audio.efeito("regar")
				Talentos.ganhar("regar")
				regou.emit()
				# O INVERNO PARA A ROÇA, e o jogador precisa saber disso na hora
				# de regar, e não três dias depois.
				if plantacao.parada_por_estacao() and plantacao.plantado(celula):
					_avisar("inverno_regando")
		elif mao == "enxada":
			_avisar("ja_arado")
		elif mao in DE_REGAR and not plantacao.arado(celula):
			_avisar("molhar_chao_duro")
		elif mao in DE_REGAR:
			_avisar("ja_molhado")
		else:
			_avisar("nao_serve", Catalogo.nome(mao))
		return
	if Catalogo.tipo(mao) == "semente":
		var cultura := str(Catalogo.dados(mao).get("cultura", ""))
		if not plantacao.arado(celula):
			_avisar("semente_chao_duro")
			return
		if plantacao.plantado(celula):
			_avisar("ja_plantado")
			return
		if not Energia.gastar("plantar"):
			_avisar("cansaco")
			return
		if plantacao.plantar(celula, cultura):
			Inventario.consumir(mao, 1)
			Audio.efeito("plantar")
			Talentos.ganhar("plantar")
			plantou.emit()
		return
	# Mão livre (ou com o que não é ferramenta nem semente): colhe.
	if not plantacao.maduro(celula):
		if not plantacao.arado(celula):
			_avisar("chao_bruto")
		elif not plantacao.plantado(celula):
			_avisar("leito_vazio")
		elif plantacao.parada_por_estacao():
			_avisar("inverno")
		else:
			_avisar("nao_esta_no_ponto")
		return
	if not Energia.gastar("colher"):
		_avisar("cansaco")
		return
	var colhido: Dictionary = plantacao.colher(celula)
	if colhido.is_empty():
		return
	Inventario.adicionar(str(colhido["id"]), int(colhido["qtd"]))
	if int(colhido["sementes"]) > 0 and str(colhido.get("semente_id", "")) != "":
		Inventario.adicionar(str(colhido["semente_id"]), int(colhido["sementes"]))
	var qualidades: Array = _textos.get("qualidades", [])
	var qualidade := str(IdiomaMenu.campo(qualidades[int(colhido["qualidade"])], "texto")) \
		if int(colhido["qualidade"]) < qualidades.size() else str(colhido.get("qualidade_nome", ""))
	_avisar("colheita", qualidade, int(colhido["qtd"]), Catalogo.nome(str(colhido["id"])).to_lower())
	Audio.efeito("colher")
	Talentos.ganhar("colher")
	colheu.emit()


func _nome_da_cultura(cultura: String) -> String:
	var semente := Plantacao.semente_de(cultura)
	var colheita := str(Plantacao.CULTURAS.get(cultura, {}).get("colheita", cultura))
	return Catalogo.nome(colheita).to_lower() if colheita != "" else Catalogo.nome(semente)


func _texto(chave: String) -> String:
	return str(IdiomaMenu.campo(_textos.get("acoes", {}).get(chave, {}), "texto", chave))


## O recado do leito, nos três idiomas (`data/lavoura.json`), no canto do HUD.
func _avisar(chave: String, a = null, b = null, c = null) -> void:
	var texto := str(IdiomaMenu.campo(_textos.get("recados", {}).get(chave, {}), "texto", chave))
	var partes := [a, b, c].filter(func(p): return p != null)
	if not partes.is_empty():
		texto = texto % partes
	if _hud != null and _hud.has_method("set_notice"):
		_hud.set_notice(texto)


# --- o save ------------------------------------------------------------------------

func estado_para_salvar() -> Dictionary:
	return {"leitos": plantacao.leitos_para_salvar()}


func restaurar(estado: Dictionary) -> void:
	var leitos = estado.get("leitos", {})
	plantacao.restaurar_leitos(leitos if leitos is Dictionary else {})
	for celula in _leitos_3d:
		_desenhar(celula)
