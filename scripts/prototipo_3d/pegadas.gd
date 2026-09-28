extends Node3D
## Pegadas do jogador: um decalque fino no chão a cada passo, alternando o pé.
## A marca muda com o terreno (areia nítida, lama funda, terra leve, grama amassada;
## água, madeira e poça não marcam) e some sozinha — só o último terço da vida
## esmaece. Pool fixo em round-robin: a marca mais antiga cede o lugar.

## Quantas marcas vivas ao mesmo tempo.
const POOL := 64
## Meio passo lateral (unidades) entre o pé esquerdo e o direito.
const AFASTAMENTO_PES := 0.09
## Sola no chão (unidades; 1 u = 4 m → ~14 × 34 cm).
const TAMANHO := Vector2(0.034, 0.085)
## Um dedo acima do chão para o decalque não brigar com a textura do terreno.
const ACIMA_DO_CHAO := 0.005
## Tremor lateral (unidades) para os passos não caírem em fila perfeita.
const TREMOR := 0.02

## Cor, força e duração (s) da marca por terreno; terreno fora daqui não marca.
const TERRENOS := {
	"areia": {"cor": Color(0.33, 0.25, 0.16), "alfa": 0.55, "dura": 25.0},
	"lama": {"cor": Color(0.20, 0.14, 0.09), "alfa": 0.72, "dura": 35.0},
	"terra": {"cor": Color(0.30, 0.22, 0.14), "alfa": 0.30, "dura": 12.0},
	"grama": {"cor": Color(0.10, 0.15, 0.08), "alfa": 0.26, "dura": 7.0},
}

var _itens: Array[Dictionary] = []
var _proximo := 0
var _pe_esquerdo := false


func _ready() -> void:
	# Uma malha e uma textura para todo mundo; cada marca só tem o próprio material
	# (o esmaecer é no albedo, que funciona em qualquer renderizador).
	var textura := _desenhar_pegada()
	var malha := QuadMesh.new()
	malha.size = TAMANHO
	malha.orientation = PlaneMesh.FACE_Y
	for indice in POOL:
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# O pé esquerdo é o espelho (scale.x negativo), então nada de cull.
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_texture = textura
		# Acima do chão na fila de desenho, para o decalque não sumir no terreno.
		material.render_priority = 2
		var marca := MeshInstance3D.new()
		marca.name = "Pegada%d" % indice
		marca.mesh = malha
		marca.material_override = material
		marca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marca.visible = false
		add_child(marca)
		_itens.append({"no": marca, "vida": 0.0, "dura": 1.0, "cor": Color.WHITE})


func _process(delta: float) -> void:
	for item in _itens:
		var vida := float(item["vida"])
		if vida <= 0.0:
			continue
		vida -= delta
		item["vida"] = vida
		var marca: MeshInstance3D = item["no"]
		if vida <= 0.0:
			marca.visible = false
			continue
		# Firme até o último terço; daí em diante esmaece linear até sumir.
		var terco := float(item["dura"]) / 3.0
		var cor: Color = item["cor"]
		cor.a *= clampf(vida / terco, 0.0, 1.0)
		(marca.material_override as StandardMaterial3D).albedo_color = cor


## Marca um passo: posição dos pés, rumo do corpo (yaw do visual) e o chão que o
## player_controller informou. Terrenos que não marcam saem calados.
func marcar(pos: Vector3, yaw: float, terreno: String, correndo: bool) -> void:
	if not TERRENOS.has(terreno) or _itens.is_empty():
		return
	var regra: Dictionary = TERRENOS[terreno]
	_pe_esquerdo = not _pe_esquerdo
	var item: Dictionary = _itens[_proximo]
	_proximo = (_proximo + 1) % POOL
	var marca: MeshInstance3D = item["no"]
	# Cada pé cai de um lado do rumo, com um tremor para não virar carimbo em fila.
	var lado := Vector3(cos(yaw), 0.0, -sin(yaw)) * (AFASTAMENTO_PES if _pe_esquerdo else -AFASTAMENTO_PES)
	var tremor := Vector3(randf_range(-TREMOR, TREMOR), 0.0, randf_range(-TREMOR, TREMOR))
	marca.global_position = Vector3(pos.x, pos.y + ACIMA_DO_CHAO, pos.z) + lado + tremor
	# O corpo anda para o +Z local (yaw = atan2(x, z) no player_controller) e o topo
	# da textura (dedos) fica no -Z do QuadMesh: meio giro alinha os dedos ao rumo.
	marca.rotation = Vector3(0.0, yaw + PI, 0.0)
	# Correndo o passo pisa mais: marca 15% maior e mais forte.
	var fator := 1.15 if correndo else 1.0
	marca.scale = Vector3(-fator if _pe_esquerdo else fator, 1.0, fator)
	var cor: Color = regra["cor"]
	cor.a = minf(float(regra["alfa"]) * (1.25 if correndo else 1.0), 0.9)
	item["cor"] = cor
	item["dura"] = float(regra["dura"])
	item["vida"] = float(regra["dura"])
	(marca.material_override as StandardMaterial3D).albedo_color = cor
	marca.visible = true


## Desenha a pegada uma única vez: sola, arco, calcanhar e cinco dedos, em branco
## com alfa suave — a cor vem do material, por terreno. Dedos no topo da imagem
## (v = 0, o -Z local do QuadMesh FACE_Y); o marcar() dá o meio giro para o rumo.
func _desenhar_pegada() -> ImageTexture:
	var imagem := Image.create_empty(32, 48, false, Image.FORMAT_RGBA8)
	for py in 48:
		for px in 32:
			var alfa := 0.0
			# Sola da frente, arco (mais estreito, puxado para dentro) e calcanhar.
			alfa = maxf(alfa, _alfa_elipse(px, py, 16.0, 19.0, 9.0, 9.5))
			alfa = maxf(alfa, _alfa_elipse(px, py, 14.5, 29.0, 6.0, 7.5))
			alfa = maxf(alfa, _alfa_elipse(px, py, 15.0, 39.0, 7.0, 7.0))
			# Dedão do lado de dentro e os outros quatro descendo em arco.
			alfa = maxf(alfa, _alfa_elipse(px, py, 7.5, 8.0, 3.2, 3.6))
			alfa = maxf(alfa, _alfa_elipse(px, py, 13.0, 5.5, 2.4, 2.6))
			alfa = maxf(alfa, _alfa_elipse(px, py, 18.0, 4.8, 2.2, 2.4))
			alfa = maxf(alfa, _alfa_elipse(px, py, 22.5, 5.5, 2.0, 2.2))
			alfa = maxf(alfa, _alfa_elipse(px, py, 26.0, 7.5, 1.8, 2.0))
			# RGB branco até onde o alfa é zero: o filtro linear não escurece a borda.
			imagem.set_pixel(px, py, Color(1.0, 1.0, 1.0, alfa))
	# Mipmaps para a marca não cintilar quando vista de longe.
	imagem.generate_mipmaps()
	return ImageTexture.create_from_image(imagem)


## Alfa suave de uma elipse: cheio no miolo, caindo até zero na borda.
func _alfa_elipse(px: int, py: int, cx: float, cy: float, rx: float, ry: float) -> float:
	var dx := (float(px) - cx) / rx
	var dy := (float(py) - cy) / ry
	return clampf((1.0 - sqrt(dx * dx + dy * dy)) * 2.2, 0.0, 1.0)
