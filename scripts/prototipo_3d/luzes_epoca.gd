extends Node3D
## Luzes de 1887 no Recôncavo: lampião a óleo de poste (praça e adro), candeeiro de
## querosene nas portas, fogueira no terreiro e vela na janela. Não havia luz elétrica;
## a noite é escura de verdade e cada ponto de luz é um lugar de encontro.
## `aplicar_hora` acende ao entardecer e apaga ao amanhecer; o tremeluzir é por chama.

const COR_OLEO := Color("ffb45a")
const COR_QUEROSENE := Color("ffc978")
const COR_FOGO := Color("ff8a3c")
const COR_VELA := Color("ffcf8a")

var _chamas: Array[Dictionary] = []
var _acesas := false
var _intensidade := 0.0
var _tempo := 0.0


func lampiao(posicao: Vector3, modelo: Node3D) -> void:
	_chama(posicao + Vector3(0, 3.0, 0), COR_OLEO, 7.5, 2.4, 0.08, modelo, Vector3(0, 2.95, 0), 0.22)


func candeeiro(posicao: Vector3, modelo: Node3D) -> void:
	_chama(posicao, COR_QUEROSENE, 4.5, 1.4, 0.12, modelo, Vector3(0, 0.25, 0), 0.12)


func fogueira(posicao: Vector3, modelo: Node3D) -> void:
	_chama(posicao + Vector3(0, 0.55, 0), COR_FOGO, 9.0, 3.2, 0.35, modelo, Vector3(0, 0.3, 0), 0.0)
	_particulas_fogueira(posicao)


## A chama e as brasas são partículas luminosas; o modelo contém só madeira.
func _particulas_fogueira(posicao: Vector3) -> void:
	var particulas := GPUParticles3D.new()
	particulas.name = "ChamaDaFogueira"
	particulas.position = posicao + Vector3(0.0, 0.28, 0.0)
	particulas.amount = 72
	particulas.lifetime = 0.68
	particulas.preprocess = 0.68
	particulas.emitting = true
	particulas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var movimento := ParticleProcessMaterial.new()
	movimento.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	movimento.emission_sphere_radius = 0.16
	movimento.direction = Vector3.UP
	movimento.spread = 16.0
	movimento.gravity = Vector3(0.0, 0.45, 0.0)
	movimento.initial_velocity_min = 0.55
	movimento.initial_velocity_max = 1.15
	movimento.scale_min = 0.35
	movimento.scale_max = 1.0
	var cores := Gradient.new()
	cores.set_color(0, Color(1.0, 0.82, 0.25, 0.95))
	cores.add_point(0.5, Color(1.0, 0.42, 0.07, 0.8))
	cores.set_color(1, Color(1.0, 0.19, 0.04, 0.0))
	var rampa := GradientTexture1D.new()
	rampa.gradient = cores
	movimento.color_ramp = rampa
	particulas.process_material = movimento
	var chama := QuadMesh.new()
	chama.size = Vector2(0.16, 0.38)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = Color(1.0, 0.4, 0.08)
	material.emission_energy_multiplier = 1.2
	var borda := Gradient.new()
	borda.set_color(0, Color.WHITE)
	borda.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var textura := GradientTexture2D.new()
	textura.gradient = borda
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.55)
	textura.fill_to = Vector2(0.5, 0.0)
	material.albedo_texture = textura
	chama.material = material
	particulas.draw_pass_1 = chama
	add_child(particulas)
	var brasas := GPUParticles3D.new()
	brasas.name = "BrasasDaFogueira"
	brasas.position = posicao + Vector3(0.0, 0.32, 0.0)
	brasas.amount = 16
	brasas.lifetime = 1.2
	brasas.preprocess = 1.2
	brasas.emitting = true
	brasas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var movimento_brasas := ParticleProcessMaterial.new()
	movimento_brasas.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	movimento_brasas.emission_sphere_radius = 0.12
	movimento_brasas.direction = Vector3.UP
	movimento_brasas.spread = 32.0
	movimento_brasas.gravity = Vector3(0.0, -0.15, 0.0)
	movimento_brasas.initial_velocity_min = 0.8
	movimento_brasas.initial_velocity_max = 1.8
	var cores_brasas := Gradient.new()
	cores_brasas.set_color(0, Color(1.0, 0.75, 0.3, 0.9))
	cores_brasas.set_color(1, Color(1.0, 0.18, 0.03, 0.0))
	var rampa_brasas := GradientTexture1D.new()
	rampa_brasas.gradient = cores_brasas
	movimento_brasas.color_ramp = rampa_brasas
	brasas.process_material = movimento_brasas
	var ponto := QuadMesh.new()
	ponto.size = Vector2(0.045, 0.045)
	ponto.material = material
	brasas.draw_pass_1 = ponto
	add_child(brasas)


## Janela iluminada por dentro: um quadrado emissivo quente sem luz projetada.
func janela(posicao: Vector3) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.86, 1.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = COR_VELA
	material.emission_enabled = true
	material.emission = COR_VELA
	material.emission_energy_multiplier = 1.6
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var instance := MeshInstance3D.new()
	instance.mesh = quad
	instance.material_override = material
	instance.position = posicao
	add_child(instance)
	var luz := OmniLight3D.new()
	luz.light_color = COR_VELA
	luz.omni_range = 3.5
	luz.light_energy = 0.0
	luz.position = posicao + Vector3(0, 0, 0.3)
	add_child(luz)
	_chamas.append({"luz": luz, "energia": 0.9, "tremor": 0.05, "fase": randf() * TAU, "visual": instance})


func _chama(posicao: Vector3, cor: Color, alcance: float, energia: float, tremor: float, modelo: Node3D, deslocamento_no_modelo: Vector3, brasa_raio: float) -> void:
	var luz := OmniLight3D.new()
	luz.light_color = cor
	luz.omni_range = alcance
	luz.omni_attenuation = 1.4
	luz.light_energy = 0.0
	luz.shadow_enabled = false
	luz.position = posicao
	add_child(luz)
	var visual: MeshInstance3D = null
	if brasa_raio > 0.0:
		# Um pequeno globo emissivo faz a chama visível de longe, mesmo sem o modelo.
		var esfera := SphereMesh.new()
		esfera.radius = brasa_raio
		esfera.height = brasa_raio * 2.2
		esfera.radial_segments = 8
		esfera.rings = 4
		var material := StandardMaterial3D.new()
		material.albedo_color = cor
		material.emission_enabled = true
		material.emission = cor
		material.emission_energy_multiplier = 2.2
		visual = MeshInstance3D.new()
		visual.mesh = esfera
		visual.material_override = material
		visual.position = posicao
		add_child(visual)
	_chamas.append({"luz": luz, "energia": energia, "tremor": tremor, "fase": randf() * TAU, "visual": visual})


func aplicar_hora(_hora: float) -> void:
	# Acende quando a luz do dia cai abaixo de 45 % e apaga quando volta.
	var alvo := 1.0 - smoothstep(0.25, 0.6, Dia.luz_do_dia())
	_intensidade = alvo
	_acesas = alvo > 0.02
	_atualizar(0.0)


func _process(delta: float) -> void:
	_tempo += delta
	if _acesas:
		_atualizar(delta)


func _atualizar(_delta: float) -> void:
	for chama in _chamas:
		var luz: OmniLight3D = chama.luz
		var tremor: float = chama.tremor
		var fase: float = chama.fase
		var oscilacao := 1.0 + tremor * (sin(_tempo * 9.0 + fase) * 0.6 + sin(_tempo * 23.0 + fase * 1.7) * 0.4)
		luz.light_energy = float(chama.energia) * _intensidade * oscilacao
		luz.visible = _acesas
		var visual = chama.visual
		if visual != null:
			visual.visible = _acesas
			if visual.material_override is StandardMaterial3D:
				(visual.material_override as StandardMaterial3D).emission_energy_multiplier = 2.2 * _intensidade * oscilacao
