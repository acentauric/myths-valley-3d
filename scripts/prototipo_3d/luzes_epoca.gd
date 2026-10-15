extends Node3D
## Luzes de 1887 no Recôncavo: lampião a óleo de poste (praça e adro), candeeiro de
## querosene nas portas, fogueira no terreiro e vela na janela. Não havia luz elétrica;
## a noite é escura de verdade e cada ponto de luz é um lugar de encontro.
## `aplicar_hora` acende ao entardecer e apaga ao amanhecer; o tremeluzir é por chama.

const COR_OLEO := Color("ffb45a")
const COR_QUEROSENE := Color("ffc978")
const COR_FOGO := Color("ff8a3c")
const COR_VELA := Color("ffcf8a")
const FasesDaLua = preload("res://scripts/prototipo_3d/fases_da_lua.gd")

var _chamas: Array[Dictionary] = []
## A chama e as brasas da fogueira: partículas que seguem a noite como a luz (#86).
var _particulas: Array[GPUParticles3D] = []
var _acesas := false
## As luzes locais ganham força quando a lua é nova (#229, fases_da_lua.gd), e o viajante ganha um
## brilho de lampião em volta de si nas noites escuras. Na lua cheia os dois são neutros.
var _fator_lunar := 1.0
var _energia_do_viajante := 0.0
var _viajante: OmniLight3D
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
	_particulas.append(particulas)
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
	_particulas.append(brasas)


## O VIDRO ACESO de uma janela da fachada (#257): uma textura de vidro quente com moldura e travessas,
## e não uma cor chapada. Era um quadrado de uma cor só, emissivo a 2,2 (o tonemap o levava ao
## branco): na igreja, onde não há janela naquele ponto, aparecia como uma ficha branca sobre a porta.
## Tamanho do quad (m) e da textura (px, na mesma proporção).
const VIDRO_M := Vector2(0.86, 1.0)
const VIDRO_PX := Vector2i(48, 56)
const COR_VIDRO_CENTRO := Color("ffd98f")
const COR_VIDRO_BORDA := Color("c9772e")
const COR_MOLDURA := Color("3b2412")
## Emissão do vidro à noite, antes de multiplicar pela intensidade e pelo tremor da chama: baixa o bastante
## para o tonemap não queimar o vidro em branco, e alta o bastante para ele ser a luz da casa.
const EMISSAO_DO_VIDRO := 1.25
const EMISSAO_DO_GLOBO := 2.2
## O grupo de todo vidro aceso do mundo.
const GRUPO_DO_VIDRO := "vidro_aceso"

static var _vidro: ImageTexture


## A textura do vidro aceso: o meio mais claro (a vela dentro do cômodo), as bordas mais quentes, a
## moldura de madeira em volta e uma travessa em cruz. Gerada uma vez e dividida por todas as janelas.
static func textura_do_vidro() -> ImageTexture:
	if _vidro != null:
		return _vidro
	var imagem := Image.create(VIDRO_PX.x, VIDRO_PX.y, false, Image.FORMAT_RGB8)
	for y in VIDRO_PX.y:
		for x in VIDRO_PX.x:
			var u := (float(x) + 0.5) / float(VIDRO_PX.x)
			var v := (float(y) + 0.5) / float(VIDRO_PX.y)
			var distancia := clampf(Vector2(u - 0.5, v - 0.5).length() * 1.9, 0.0, 1.0)
			var cor := COR_VIDRO_CENTRO.lerp(COR_VIDRO_BORDA, distancia * distancia)
			var moldura := u < 0.08 or u > 0.92 or v < 0.07 or v > 0.93
			var travessa := absf(u - 0.5) < 0.035 or absf(v - 0.42) < 0.03
			imagem.set_pixel(x, y, COR_MOLDURA if moldura or travessa else cor)
	imagem.generate_mipmaps()
	_vidro = ImageTexture.create_from_image(imagem)
	return _vidro


## Janela iluminada por dentro: o vidro aceso rente à fachada e um facho quente na parede.
## `yaw` é o giro da fachada: a frente da casa é o +Z do modelo (`giro = atan2(frente.x, frente.z)`).
## Sem ele o vidro ficava sempre voltado para o sul do mundo, e só parecia certo na casa que olha
## para o sul; na igreja, que olha para o oeste, o quad ficava de través, espetado para fora da parede.
func janela(posicao: Vector3, yaw: float = 0.0) -> void:
	var quad := QuadMesh.new()
	quad.size = VIDRO_M
	var material := StandardMaterial3D.new()
	var vidro := textura_do_vidro()
	material.albedo_texture = vidro
	material.emission_enabled = true
	material.emission_texture = vidro
	material.emission_energy_multiplier = EMISSAO_DO_VIDRO
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var instance := MeshInstance3D.new()
	instance.name = "Vidro aceso"
	# O grupo é como os testes (e quem mais precisar) acham os vidros: o Godot renomeia o segundo nó de mesmo
	# nome para "@MeshInstance3D@N", e o nome deixa de servir.
	instance.add_to_group(GRUPO_DO_VIDRO)
	instance.mesh = quad
	instance.material_override = material
	instance.position = posicao
	instance.rotation.y = yaw
	add_child(instance)
	var luz := OmniLight3D.new()
	luz.light_color = COR_VELA
	luz.omni_range = 3.5
	luz.light_energy = 0.0
	luz.position = posicao + Vector3(0, 0, 0.3).rotated(Vector3.UP, yaw)
	add_child(luz)
	_chamas.append({"luz": luz, "energia": 0.9, "tremor": 0.05, "fase": randf() * TAU, "visual": instance, "emissao": EMISSAO_DO_VIDRO})


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
		material.emission_energy_multiplier = EMISSAO_DO_GLOBO
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
	var fase := FasesDaLua.fase_do_dia(Relogio.dia_absoluto())
	var suaves := FasesDaLua.suaves()
	_fator_lunar = FasesDaLua.fator_das_luzes_locais(fase, suaves)
	_energia_do_viajante = FasesDaLua.brilho_do_viajante(fase, suaves) * alvo
	# A chama da fogueira apaga de dia com a luz (#86): só a luz seguia a noite,
	# e de manhã a fogueira do terreiro continuava ardendo.
	for particulas in _particulas:
		particulas.emitting = _acesas
	_atualizar(0.0)


func _process(delta: float) -> void:
	_tempo += delta
	if _acesas:
		_atualizar(delta)
	_seguir_o_viajante()


## O brilho do viajante (#229): nas noites sem lua uma luz quente de uns seis metros anda com ele,
## para a mata fechada não virar breu em volta de quem joga. Na lua cheia, ou de dia, fica apagada
## (e nem é criada). O PROPÓSITO É O CHÃO EM VOLTA, e não o corpo: a luz ficava a 1,4 m, dentro
## do peito, e acendia por dentro as bordas da roupa e do cabelo (10/10/2026). Agora ela fica
## acima da cabeça (ALTURA_DO_BRILHO) e o alcance cresce na conta certa para o círculo de luz no
## chão continuar do mesmo tamanho de antes; o viajante recebe luz de cima, como de um céu claro.
const ALTURA_DO_BRILHO := 3.2
const ALTURA_ANTIGA_DO_BRILHO := 1.4


func _seguir_o_viajante() -> void:
	if _energia_do_viajante <= 0.01:
		if _viajante != null:
			_viajante.visible = false
		return
	if not is_inside_tree():
		return
	var jogador := get_tree().get_first_node_in_group("map_player") as Node3D
	if jogador == null:
		return
	if _viajante == null:
		_viajante = OmniLight3D.new()
		_viajante.name = "BrilhoDoViajante"
		_viajante.light_color = COR_OLEO
		var no_chao := sqrt(FasesDaLua.ALCANCE_DO_VIAJANTE ** 2 - ALTURA_ANTIGA_DO_BRILHO ** 2)
		_viajante.omni_range = sqrt(no_chao ** 2 + ALTURA_DO_BRILHO ** 2)
		_viajante.omni_attenuation = 1.4
		_viajante.shadow_enabled = false
		add_child(_viajante)
	_viajante.visible = true
	_viajante.light_energy = _energia_do_viajante
	_viajante.global_position = jogador.global_position + Vector3(0.0, ALTURA_DO_BRILHO, 0.0)


func _atualizar(_delta: float) -> void:
	for chama in _chamas:
		var luz: OmniLight3D = chama.luz
		var tremor: float = chama.tremor
		var fase: float = chama.fase
		var oscilacao := 1.0 + tremor * (sin(_tempo * 9.0 + fase) * 0.6 + sin(_tempo * 23.0 + fase * 1.7) * 0.4)
		luz.light_energy = float(chama.energia) * _intensidade * oscilacao * _fator_lunar
		luz.visible = _acesas
		var visual = chama.visual
		if visual != null:
			visual.visible = _acesas
			if visual.material_override is StandardMaterial3D:
				(visual.material_override as StandardMaterial3D).emission_energy_multiplier = float(chama.get("emissao", EMISSAO_DO_GLOBO)) * _intensidade * oscilacao
