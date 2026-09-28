extends GPUParticles3D
## Espuma em volta de quem anda ou nada no mar: placas de espuma deitadas na superfície
## que nascem em anel em volta das pernas (ou do corpo, nadando), se abrem e somem;
## mais densas correndo.
## Filho do CharacterBody3D; `mundo` responde water_level().

## Raio do anel (unidades) e altura acima da superfície onde a espuma nasce.
const RAIO := 0.32
const ACIMA_DA_AGUA := 0.02
## Lâmina mínima (unidades) para haver espuma; abaixo disso é só areia molhada.
const LAMINA_MINIMA := 0.04

var mundo: Node3D
var _dono: CharacterBody3D


func _ready() -> void:
	_dono = get_parent() as CharacterBody3D
	top_level = true
	amount = 56
	lifetime = 1.3
	emitting = false
	local_coords = false
	var processo := ParticleProcessMaterial.new()
	processo.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	processo.emission_ring_axis = Vector3.UP
	processo.emission_ring_radius = RAIO
	processo.emission_ring_inner_radius = RAIO * 0.6
	processo.emission_ring_height = 0.0
	# Para fora, rente à água: a espuma se espalha na superfície, sem subir.
	processo.direction = Vector3(1, 0, 0)
	processo.spread = 180.0
	processo.flatness = 1.0
	processo.initial_velocity_min = 0.15
	processo.initial_velocity_max = 0.5
	processo.gravity = Vector3.ZERO
	processo.damping_min = 0.3
	processo.damping_max = 0.6
	processo.angle_min = 0.0
	processo.angle_max = 360.0
	processo.scale_min = 0.7
	processo.scale_max = 1.3
	var cresce := Curve.new()
	cresce.add_point(Vector2(0.0, 0.45))
	cresce.add_point(Vector2(1.0, 1.4))
	var curva := CurveTexture.new()
	curva.curve = cresce
	processo.scale_curve = curva
	var some := Gradient.new()
	some.set_color(0, Color(1, 1, 1, 0.85))
	some.set_color(1, Color(1, 1, 1, 0.0))
	var rampa := GradientTexture1D.new()
	rampa.gradient = some
	processo.color_ramp = rampa
	process_material = processo
	var placa := PlaneMesh.new()
	placa.size = Vector2(0.3, 0.3)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _textura_redonda()
	material.roughness = 0.5
	# Desenhada depois da água (também transparente), por cima dela.
	material.render_priority = 1
	placa.material = material
	draw_pass_1 = placa


func _physics_process(_delta: float) -> void:
	if _dono == null or mundo == null or not mundo.has_method("water_level"):
		emitting = false
		return
	var nivel: float = mundo.water_level()
	var lamina := nivel - _dono.global_position.y
	var andando := Vector2(_dono.velocity.x, _dono.velocity.z).length() > 0.3
	emitting = is_finite(nivel) and lamina > LAMINA_MINIMA and andando
	if emitting:
		global_position = Vector3(_dono.global_position.x, nivel + ACIMA_DA_AGUA, _dono.global_position.z)
		amount_ratio = clampf(Vector2(_dono.velocity.x, _dono.velocity.z).length() / 4.0, 0.35, 1.0)


static func _textura_redonda() -> GradientTexture2D:
	var degrade := Gradient.new()
	degrade.set_color(0, Color(1, 1, 1, 1))
	degrade.set_color(1, Color(1, 1, 1, 0))
	var textura := GradientTexture2D.new()
	textura.gradient = degrade
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.0, 0.5)
	textura.width = 32
	textura.height = 32
	return textura
