class_name SetaMissao
extends Node3D
## Marcador do alvo da missão atual, em duas partes: no MUNDO, um cone dourado
## invertido flutuando sobre o alvo e um anel raso pulsando no chão; na TELA, um
## chevron dourado preso à borda apontando o rumo quando o alvo sai do campo de
## visão da câmera. API: definir_alvo(pos, texto) e limpar().

const COR := Color("e2c47f")
## Altura (u) do cone acima do alvo e amplitude do sobe-e-desce.
const ALTURA_CONE := 3.0
const BOB := 0.3
## Margem (px) da borda da tela onde o chevron se prende.
const MARGEM_TELA := 28.0
## Alvo visível na tela e mais perto que isto (u): o chevron some (o cone basta).
const PERTO := 25.0
## Meio lado (px) do Control do chevron (pivô no centro para girar).
const MEIO_CHEVRON := 24.0

var _alvo := Vector3.ZERO
var _ativo := false
var _tempo := 0.0
var _cone: MeshInstance3D
var _anel: MeshInstance3D
var _chevron: ChevronMissao


func _ready() -> void:
	visible = false
	# Um só material para cone e anel: emissivo suave para ler de longe e à noite,
	# translúcido para não esconder o lugar que ele marca.
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(COR.r, COR.g, COR.b, 0.75)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = COR
	material.emission_energy_multiplier = 1.1
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cone_malha := CylinderMesh.new()
	# Raio em cima e zero embaixo: cone de ponta-cabeça, apontando o chão do alvo.
	cone_malha.top_radius = 0.55
	cone_malha.bottom_radius = 0.0
	cone_malha.height = 1.1
	cone_malha.material = material
	_cone = MeshInstance3D.new()
	_cone.name = "Cone"
	_cone.mesh = cone_malha
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cone.position = Vector3(0, ALTURA_CONE, 0)
	add_child(_cone)
	var anel_malha := TorusMesh.new()
	anel_malha.inner_radius = 1.15
	anel_malha.outer_radius = 1.45
	anel_malha.material = material
	_anel = MeshInstance3D.new()
	_anel.name = "Anel"
	_anel.mesh = anel_malha
	_anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Achatado e um tico acima do chão: um anel raso, não uma rosquinha.
	_anel.scale = Vector3(1, 0.18, 1)
	_anel.position = Vector3(0, 0.08, 0)
	add_child(_anel)


## O chevron vive no overlay do HUD (hud.map_layer()), atrás do que abrir depois.
func configurar(camada: Control) -> void:
	_chevron = ChevronMissao.new()
	_chevron.name = "ChevronMissao"
	camada.add_child(_chevron)


## Passa a marcar `pos` (o texto já aparece no objetivo do HUD; fica só de registro).
func definir_alvo(pos: Vector3, _texto: String) -> void:
	_alvo = pos
	global_position = pos
	_ativo = true
	visible = true


## Missão acabou (ou não há alvo): marcador e chevron somem.
func limpar() -> void:
	_ativo = false
	visible = false
	if is_instance_valid(_chevron):
		_chevron.visible = false


func _process(delta: float) -> void:
	if not _ativo:
		return
	_tempo += delta
	# Cone flutua e gira devagar; o anel pulsa no chão.
	_cone.position.y = ALTURA_CONE + sin(_tempo * 2.4) * BOB
	_cone.rotation.y += delta * 1.6
	var pulso := 0.85 + 0.25 * sin(_tempo * 3.2)
	_anel.scale = Vector3(pulso, 0.18, pulso)
	_atualizar_chevron()


## Fora do campo de visão, o chevron prende na borda apontando o rumo; na tela e
## longe, flutua sobre o ponto apontando para baixo; na tela e perto, some.
func _atualizar_chevron() -> void:
	if not is_instance_valid(_chevron):
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_chevron.visible = false
		return
	var ponto := _alvo + Vector3(0, 1.2, 0)
	var atras := camera.is_position_behind(ponto)
	var projecao := camera.unproject_position(ponto)
	var tamanho: Vector2 = _chevron.get_viewport_rect().size
	var area := Rect2(Vector2.ZERO, tamanho).grow(-MARGEM_TELA)
	var centro := tamanho * 0.5
	# Atrás da câmera o unproject espelha: inverte para apontar pelo lado certo.
	var rumo := projecao - centro
	if atras:
		rumo = -rumo
	if rumo.length_squared() < 1.0:
		rumo = Vector2(0, 1)
	var na_tela := not atras and area.has_point(projecao)
	var distancia := camera.global_position.distance_to(_alvo)
	if na_tela and distancia < PERTO:
		_chevron.visible = false
		return
	var pos: Vector2
	if na_tela:
		# Visível mas longe: paira sobre o ponto, apontando para baixo, para ele.
		pos = projecao - Vector2(0, 46)
		_chevron.rotation = PI * 0.5
	else:
		# Do centro rumo ao alvo até tocar a borda com a margem.
		var meia := centro - Vector2(MARGEM_TELA, MARGEM_TELA)
		var fator := minf(meia.x / maxf(absf(rumo.x), 0.001), meia.y / maxf(absf(rumo.y), 0.001))
		pos = centro + rumo * fator
		_chevron.rotation = rumo.angle()
	_chevron.visible = true
	_chevron.position = pos - _chevron.pivot_offset
	_chevron.pulso = 0.7 + 0.3 * (0.5 + 0.5 * sin(_tempo * 3.2))
	_chevron.queue_redraw()


## Chevron 2D desenhado à mão: seta apontando +X, girada pela rotação do Control.
## (Classe interna não enxerga as constantes do script: usa o nome global.)
class ChevronMissao extends Control:
	var pulso := 1.0

	func _init() -> void:
		var lado := SetaMissao.MEIO_CHEVRON * 2.0
		custom_minimum_size = Vector2(lado, lado)
		size = custom_minimum_size
		pivot_offset = Vector2(SetaMissao.MEIO_CHEVRON, SetaMissao.MEIO_CHEVRON)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func _draw() -> void:
		# O chevron é desenhado como duas asas triangulares (cada triângulo é um
		# polígono trivialmente válido; o contorno único se autocruzava e a
		# triangulação do canvas rejeitava).
		var metades := [
			PackedVector2Array([Vector2(14, 0), Vector2(-10, -14), Vector2(-2, 0)]),
			PackedVector2Array([Vector2(14, 0), Vector2(-2, 0), Vector2(-10, 14)]),
		]
		var centro := Vector2(SetaMissao.MEIO_CHEVRON, SetaMissao.MEIO_CHEVRON)
		var cor: Color = SetaMissao.COR
		for metade: PackedVector2Array in metades:
			var forma := PackedVector2Array()
			var sombra := PackedVector2Array()
			for p in metade:
				forma.append(centro + p)
				sombra.append(centro + p + Vector2(1, 2))
			# Sombra leve para o chevron ler sobre céu claro.
			draw_colored_polygon(sombra, Color(0, 0, 0, 0.35 * pulso))
			draw_colored_polygon(forma, Color(cor.r, cor.g, cor.b, pulso))
