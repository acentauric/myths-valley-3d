extends Node3D
## Tubarão da parte funda: só a barbatana corta a superfície, com o corpo como sombra
## alongada logo abaixo e um rastro leve de espuma. Patrulha em elipses largas na água
## funda mais próxima do píer e persegue apenas o JOGADOR nadando no fundo — moradores
## e Pedro nunca são alvo. Ao alcançar, efeito de tela num CanvasLayer próprio e o
## jogador volta à terra firme (player._back_to_land()). Na maré baixa ele some.
##
## Também come: a cada 45 a 90 s, longe do jogador, arranca atrás do cardume mais
## perto do grupo `presas_do_tubarao` (as cavalas e sororocas do mar de fora,
## fauna_vale.gd) e, chegando junto, um peixe some com respingo — o cardume o repõe
## depois. O jogador nadando no fundo continua sendo a primeira presa. Está no grupo
## `predadores`, de quem os cardumes fogem. No estilo Tripo o corpo é o GLB
## "tubarao" (cabeça-chata, nadando com o clipe do rig); no procedural, os prismas.

## Lâminas d'água (unidades): onde ele vive, onde ainda persegue e onde não entra.
const LAMINA_FUNDA := 1.8
const LAMINA_PERSEGUE := 1.6
const LAMINA_MINIMA := 1.0
## A MARÉ TIRA O TUBARÃO: o pesqueiro é escolhido pela água da PREAMAR (`_lamina_na_cheia`, a mesma em qualquer
## hora de partida), e a lâmina no centro dele acompanha o mar. Com a regra de antes (sumir só abaixo de
## LAMINA_FUNDA - 0,5, 1,3 u) ele ficava na baixa-mar: o centro do pesqueiro mede 2,15 u na preamar e 1,55 na
## baixa-mar (medido em 06/10/2026), e 1,55 passa de 1,3. Agora ele some quando a lâmina no centro cai abaixo de
## LAMINA_FUNDA mais a folga de `FOLGA_DA_SAIDA` (1,95 u) e só volta quando ela passa de LAMINA_FUNDA mais
## `FOLGA_DA_VOLTA` (2,1 u, a mesma folga com que o pesqueiro é escolhido).
const FOLGA_DA_SAIDA := 0.15
const FOLGA_DA_VOLTA := 0.3
## Velocidades (u/s): o nado do jogador é ~1,5 (correndo 3,0), e o tubarão passa dos
## dois — quem nada no fundo não foge dele. Escapar é voltar para o RASO: ele não
## persegue quem está em lâmina de `LAMINA_PERSEGUE` ou menos, nem entra onde
## a lâmina é menor que `LAMINA_MINIMA`. A patrulha (2,0) já é mais rápida que o
## nado normal do jogador (1,5).
const VELOCIDADE_PATRULHA := 2.0
const VELOCIDADE_PERSEGUICAO := 4.4
const RAIO_PERCEPCAO := 55.0
const RAIO_ATAQUE := 0.9
const COOLDOWN_ATAQUE := 25.0
## Semi-eixos da elipse de patrulha (encolhem até a elipse caber na água funda).
const ELIPSE_A := 14.0
const ELIPSE_B := 8.0
const SOM_ATAQUE := "res://assets/audio/efeitos/tubarao_ataque.mp3"
## O aviso do susto, nos três idiomas.
const TEXTOS := "res://data/fauna_do_mar.json"
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const Cardume = preload("res://scripts/prototipo_3d/cardume.gd")
## A caça aos cardumes: de quanto em quanto tempo (s), até onde ele procura, a
## arrancada (u/s) e quanto dura no máximo, e a distância do bote no peixe.
const INTERVALO_CACA := Vector2(45.0, 90.0)
const ALCANCE_CACA := 40.0
const VELOCIDADE_CACA := 5.0
const DURACAO_CACA := 10.0
const RAIO_BOTE_PEIXE := 1.0
## O corpo do Tripo: a ponta da barbatana fica este tanto acima da água.
const BARBATANA_FORA := 0.12

var _world	# world_builder.gd (water_level, water_depth_at, ancoras)
var _player	# player_controller.gd (is_swimming, _back_to_land)
var _aviso := Callable()
var _centro := Vector3.ZERO
var _eixo_a := Vector3.RIGHT
var _eixo_b := Vector3.BACK
var _a := ELIPSE_A
var _b := ELIPSE_B
var _angulo := 0.0
var _rumo := 0.0
var _ativo := false
var _atacando := false
var _submerso := false
var _proximo_ataque := 0.0
var _checagem_mare := 0.0
var _espuma: GPUParticles3D
var _modelo_tripo: Node3D
var _esqueleto: Skeleton3D
var _ossos_cauda: Array[int] = []
var _eixos_cauda: Array[Vector3] = []
var _tempo_cauda := 0.0
## O relógio do tubarão, em segundos de JOGO (a soma do delta de física): a caça, o
## cooldown do ataque e o prazo da presa paravam de contar com o jogo pausado? Não —
## contavam em relógio de parede, e andavam com a pausa. Agora param.
var _tempo := 0.0
## O quanto a cauda bate mais depressa que na patrulha: acompanha a velocidade.
var _ritmo := 1.0
var _repousos_cauda: Array[Quaternion] = []
var _tela: CanvasLayer
var _proxima_caca := 0.0
var _caca_ate := 0.0
var _presa = null
var _nado: AnimationPlayer
var _rng := RandomNumberGenerator.new()
var _flash: ColorRect
var _vinheta: TextureRect
var _preto: ColorRect


## `aviso` recebe o texto do susto para o HUD (hud.set_notice).
func configurar(world, player, aviso: Callable) -> void:
	_world = world
	_player = player
	_aviso = aviso
	if _world == null or not _world.has_method("water_level") or not is_finite(float(_world.water_level())):
		visible = false
		return
	if not _procurar_pesqueiro():
		# Sem água funda no mapa: fica quieto e invisível, sem processar nada.
		visible = false
		return
	_montar_visual()
	_montar_espuma()
	_montar_tela()
	global_position = _ponto_elipse(_angulo)
	_rumo = rotation.y
	_ativo = true
	add_to_group("predadores")
	_rng.seed = 2611
	_proxima_caca = _tempo + _rng.randf_range(INTERVALO_CACA.x, INTERVALO_CACA.y)


func _physics_process(delta: float) -> void:
	_tempo += delta
	if not _ativo or _atacando:
		return
	_animar_cauda(delta)
	var agora := _tempo
	_checagem_mare -= delta
	if _checagem_mare <= 0.0:
		_checagem_mare = 0.7
		# Maré baixa: sem lâmina funda no pesqueiro, ele afunda e some até a água voltar.
		var fundo := _lamina(_centro)
		if _submerso and fundo >= LAMINA_FUNDA + FOLGA_DA_VOLTA:
			_submerso = false
			visible = true
		elif not _submerso and fundo < LAMINA_FUNDA + FOLGA_DA_SAIDA:
			_submerso = true
			visible = false
	if _submerso:
		if _espuma:
			_espuma.emitting = false
		return
	# A barbatana acompanha a superfície (a maré pode mexer no nível).
	global_position.y = _nivel()
	var pos := global_position
	var alvo := _alvo_perseguicao(agora)
	var perseguindo := alvo.is_finite()
	var destino := alvo
	var velocidade := VELOCIDADE_PERSEGUICAO
	if not perseguindo:
		# Patrulha: avança o ângulo da elipse mantendo a velocidade linear quase constante.
		var raio_local := sqrt(pow(_a * sin(_angulo), 2.0) + pow(_b * cos(_angulo), 2.0))
		_angulo = fposmod(_angulo + VELOCIDADE_PATRULHA * delta / maxf(raio_local, 1.0), TAU)
		destino = _ponto_elipse(_angulo)
		velocidade = VELOCIDADE_PATRULHA
	var cacando := false
	if perseguindo:
		_largar_presa(agora)
	else:
		var bote := _alvo_da_caca(agora)
		if bote.is_finite():
			cacando = true
			destino = bote
			velocidade = VELOCIDADE_CACA
	var dif := Vector3(destino.x - pos.x, 0.0, destino.z - pos.z)
	var dist := dif.length()
	if perseguindo and dist < RAIO_ATAQUE:
		_atacar()
		return
	if cacando and dist < RAIO_BOTE_PEIXE:
		_comer(agora)
	if dist > 0.005:
		var direcao := dif / dist
		var proxima := pos + direcao * minf(velocidade * delta, dist)
		proxima.y = _nivel()
		# Nunca entra no raso: quem volta para a areia escapa dele.
		if _lamina(proxima) >= LAMINA_MINIMA:
			global_position = proxima
			_rumo = lerp_angle(_rumo, atan2(-direcao.x, -direcao.z), 1.0 - exp(-4.0 * delta))
			rotation.y = _rumo
	if _espuma:
		_espuma.emitting = true
		_espuma.amount_ratio = 1.0 if perseguindo or cacando else 0.5
	_ritmo = clampf(velocidade / VELOCIDADE_PATRULHA, 1.0, 3.0)
	if _nado != null:
		_nado.speed_scale = velocidade / VELOCIDADE_PATRULHA


## Posição do jogador se ele é caçável agora; Vector3.INF caso contrário.
## Só o JOGADOR nadando em água funda, perto e fora do cooldown — nunca moradores.
func _alvo_perseguicao(agora: float) -> Vector3:
	if _player == null or agora < _proximo_ataque:
		return Vector3.INF
	if not _player.has_method("is_swimming") or not _player.is_swimming():
		return Vector3.INF
	var ppos: Vector3 = _player.global_position
	if _lamina(ppos) <= LAMINA_PERSEGUE:
		return Vector3.INF
	if Vector2(ppos.x - global_position.x, ppos.z - global_position.z).length() > RAIO_PERCEPCAO:
		return Vector3.INF
	return ppos


## A caça aos cardumes, quando não está atrás do jogador: na hora, escolhe o
## cardume-presa mais perto; caçando, devolve o peixe mais perto dele (ou INF).
func _alvo_da_caca(agora: float) -> Vector3:
	if _presa == null:
		if agora < _proxima_caca:
			return Vector3.INF
		_presa = _cardume_mais_perto()
		if _presa == null:
			_proxima_caca = agora + _rng.randf_range(INTERVALO_CACA.x, INTERVALO_CACA.y) * 0.5
			return Vector3.INF
		_caca_ate = agora + DURACAO_CACA
	if not is_instance_valid(_presa) or agora > _caca_ate:
		_largar_presa(agora)
		return Vector3.INF
	var i: int = _presa.peixe_mais_perto(global_position)
	if i < 0:
		_largar_presa(agora)
		return Vector3.INF
	return _presa.posicao(i)


func _cardume_mais_perto():
	var melhor = null
	var menor := ALCANCE_CACA
	for cardume in get_tree().get_nodes_in_group("presas_do_tubarao"):
		if not cardume is Node3D or not cardume.has_method("peixe_mais_perto") or bool(cardume.get("dormindo")):
			continue
		var onde: Vector3 = cardume.centro_atual()
		var d := Vector2(onde.x - global_position.x, onde.z - global_position.z).length()
		if d < menor:
			menor = d
			melhor = cardume
	return melhor


## O bote no cardume: o peixe mais perto some com respingo, e a caça acaba.
func _comer(agora: float) -> void:
	if _presa != null and is_instance_valid(_presa):
		var i: int = _presa.peixe_mais_perto(global_position)
		if i >= 0:
			_presa.devorar(i)
		Cardume.respingo(get_parent(), Vector3(global_position.x, _nivel(), global_position.z), 1.6)
	_largar_presa(agora)


func _largar_presa(agora: float) -> void:
	if _presa == null:
		return
	_presa = null
	_proxima_caca = agora + _rng.randf_range(INTERVALO_CACA.x, INTERVALO_CACA.y)


## Para o portão: a próxima caça é agora.
func forcar_caca() -> void:
	_presa = null
	_proxima_caca = 0.0


func _atacar() -> void:
	_atacando = true
	if _espuma:
		_espuma.emitting = false
	if Audio.has_method("efeito") and ResourceLoader.exists(SOM_ATAQUE):
		Audio.efeito("tubarao_ataque")
	_tela.visible = true
	_flash.modulate.a = 1.0
	_vinheta.modulate.a = 0.0
	_vinheta.pivot_offset = _vinheta.size * 0.5
	_vinheta.scale = Vector2(2.2, 2.2)
	_preto.modulate.a = 0.0
	# Flash branco → vinheta vermelha fechando → preto → reset → abre do preto.
	var sequencia := create_tween()
	sequencia.tween_property(_flash, "modulate:a", 0.0, 0.1)
	sequencia.tween_property(_vinheta, "modulate:a", 1.0, 0.5)
	sequencia.parallel().tween_property(_vinheta, "scale", Vector2.ONE, 0.5)
	sequencia.tween_property(_preto, "modulate:a", 1.0, 0.4)
	sequencia.tween_callback(_resgatar)
	sequencia.tween_property(_preto, "modulate:a", 0.0, 0.6)
	sequencia.parallel().tween_property(_vinheta, "modulate:a", 0.0, 0.3)
	sequencia.tween_callback(_encerrar_ataque)


## Com a tela preta: o jogador volta à última terra firme e o tubarão recua.
func _resgatar() -> void:
	if _player != null and _player.has_method("_back_to_land"):
		_player._back_to_land()
	if _aviso.is_valid():
		_aviso.call(_texto_do_susto())
	# Recomeça a patrulha do lado oposto da elipse, longe do jogador.
	if _player != null:
		var rel: Vector3 = _player.global_position - _centro
		_angulo = fposmod(atan2(rel.dot(_eixo_b), rel.dot(_eixo_a)) + PI, TAU)
	global_position = _ponto_elipse(_angulo)


## O aviso do susto, no idioma do jogador (data/fauna_do_mar.json).
func _texto_do_susto() -> String:
	var arquivo := FileAccess.open(TEXTOS, FileAccess.READ)
	if arquivo == null:
		return ""
	var dados = JSON.parse_string(arquivo.get_as_text())
	if not dados is Dictionary:
		return ""
	return str(IdiomaMenu.campo(dados.get("tubarao", {}), "susto", ""))


func _encerrar_ataque() -> void:
	_tela.visible = false
	_atacando = false
	_proximo_ataque = _tempo + COOLDOWN_ATAQUE


## Primeiro ponto bem fundo varrendo do píer mar adentro, abrindo em leque. A planície
## rasa da baía passa de 150 unidades (600 m) na frente da vila: a busca vai até
## ALCANCE_BUSCA, senão ele nunca encontrava água funda e ficava desligado.
const ALCANCE_BUSCA := 360
func _procurar_pesqueiro() -> bool:
	var ancoras_var = _world.get("ancoras")
	var ancoras: Dictionary = ancoras_var if ancoras_var is Dictionary else {}
	var pier: Vector3 = ancoras.get("Pier", ancoras.get("PierPiso", Vector3.ZERO))
	var mar: Vector3 = ancoras.get("PierDirecao", Vector3.FORWARD)
	mar.y = 0.0
	if mar.length_squared() < 0.001:
		mar = Vector3.FORWARD
	mar = mar.normalized()
	for raio in range(6, ALCANCE_BUSCA, 4):
		for graus in [0.0, 20.0, -20.0, 40.0, -40.0, 60.0, -60.0]:
			var direcao := mar.rotated(Vector3.UP, deg_to_rad(graus))
			var ponto := pier + direcao * float(raio)
			if _lamina_na_cheia(ponto) >= LAMINA_FUNDA + 0.3:
				_centro = ponto + direcao * 4.0
				_centro.y = _nivel()
				_eixo_a = direcao
				_eixo_b = Vector3(-direcao.z, 0.0, direcao.x)
				_ajustar_elipse()
				return true
	return false


## Encolhe a elipse até toda ela ficar em água funda o bastante para nadar.
func _ajustar_elipse() -> void:
	for _tentativa in 8:
		var cabe := true
		for k in 12:
			if _lamina_na_cheia(_ponto_elipse(TAU * float(k) / 12.0)) < LAMINA_PERSEGUE - 0.2:
				cabe = false
				break
		if cabe:
			return
		_a = maxf(_a * 0.75, 3.0)
		_b = maxf(_b * 0.75, 2.0)


func _ponto_elipse(ang: float) -> Vector3:
	var ponto := _centro + _eixo_a * (cos(ang) * _a) + _eixo_b * (sin(ang) * _b)
	ponto.y = _nivel()
	return ponto


func _nivel() -> float:
	return float(_world.water_level())


func _lamina(ponto: Vector3) -> float:
	return float(_world.water_depth_at(ponto))


## A lâmina no ponto NA PREAMAR (o deslocamento da maré, que vai de 0 a -0,6 u, sai da conta): onde o pesqueiro
## fica não pode depender da hora em que o vale se montou.
func _lamina_na_cheia(ponto: Vector3) -> float:
	return _lamina(ponto) - float(Mare.nivel_offset())


## Estilo Tripo: o GLB inteiro debaixo d'água, só a barbatana de fora, nadando com
## o clipe do rig. Procedural (ou sem o GLB): os prismas e a sombra.
func _montar_visual() -> void:
	if Estilo.tripo() and CatalogoAssets.tem_tripo("tubarao"):
		var cena := CatalogoAssets.cena("tubarao")
		if cena != null:
			_modelo_tripo = cena.instantiate() as Node3D
			_modelo_tripo.name = "CorpoTripo"
			add_child(_modelo_tripo)
			var limites := CatalogoAssets.limites(_modelo_tripo)
			var comprimento := maxf(limites.size.x, limites.size.z)
			var escala := 2.6 / maxf(comprimento, 0.001)
			_modelo_tripo.scale *= escala
			_modelo_tripo.rotation.y = PI * 0.5
			_modelo_tripo.position = -(limites.get_center() * escala).rotated(Vector3.UP, PI * 0.5) + Vector3(0.0, -0.25, 0.0)
			var esqueletos := _modelo_tripo.find_children("*", "Skeleton3D", true, false)
			if not esqueletos.is_empty():
				_esqueleto = esqueletos[0] as Skeleton3D
				for nome_osso in ["Tail_0", "Tail_1"]:
					for i in _esqueleto.get_bone_count():
						if String(_esqueleto.get_bone_name(i)).ends_with(nome_osso):
							_ossos_cauda.append(i)
							_repousos_cauda.append(_esqueleto.get_bone_rest(i).basis.orthonormalized().get_rotation_quaternion())
							_eixos_cauda.append((_esqueleto.get_bone_global_rest(i).basis.inverse() * Vector3.UP).normalized())
							break
			var animacoes := _modelo_tripo.find_children("*", "AnimationPlayer", true, false)
			if not animacoes.is_empty():
				var player := animacoes[0] as AnimationPlayer
				_nado = player
				for nome in player.get_animation_list():
					if "swim" in String(nome).to_lower() or "nadar" in String(nome).to_lower():
						player.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
						player.play(nome)
						break
			for malha in _modelo_tripo.find_children("*", "GeometryInstance3D", true, false):
				(malha as GeometryInstance3D).visibility_range_end = 160.0
				(malha as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			return
	_montar_prismas()


## Barbatana rente à superfície, corpo achatado como sombra e uma caudal discreta.
func _montar_prismas() -> void:
	var pele := StandardMaterial3D.new()
	pele.albedo_color = Color("39444e")
	pele.roughness = 0.55
	pele.metallic = 0.1
	var barbatana := MeshInstance3D.new()
	barbatana.name = "Barbatana"
	var prisma := PrismMesh.new()
	# Triângulo no plano da proa (rotação de 90°), fino e recuado como barbatana real.
	prisma.size = Vector3(0.55, 0.5, 0.07)
	prisma.left_to_right = 0.15
	barbatana.mesh = prisma
	barbatana.material_override = pele
	barbatana.rotation.y = PI * 0.5
	barbatana.position = Vector3(0.0, 0.14, 0.1)
	add_child(barbatana)
	var caudal := MeshInstance3D.new()
	caudal.name = "Caudal"
	var prisma_caudal := PrismMesh.new()
	prisma_caudal.size = Vector3(0.3, 0.28, 0.05)
	prisma_caudal.left_to_right = 0.2
	caudal.mesh = prisma_caudal
	caudal.material_override = pele
	caudal.rotation.y = PI * 0.5
	caudal.position = Vector3(0.0, 0.0, 1.2)
	add_child(caudal)
	var corpo := MeshInstance3D.new()
	corpo.name = "CorpoSombra"
	var esfera := SphereMesh.new()
	esfera.radius = 1.0
	esfera.height = 2.0
	corpo.mesh = esfera
	var sombra := StandardMaterial3D.new()
	sombra.albedo_color = Color(0.03, 0.05, 0.07, 0.5)
	sombra.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sombra.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sombra.roughness = 1.0
	# Desenhado depois da água (também transparente), por cima dela.
	sombra.render_priority = 1
	corpo.material_override = sombra
	# Elipsoide achatado: longo na proa, raso na vertical — a "sombra" sob a barbatana.
	corpo.scale = Vector3(0.35, 0.12, 1.3)
	corpo.position = Vector3(0.0, -0.3, 0.3)
	add_child(corpo)


func _animar_cauda(delta: float) -> void:
	if _esqueleto == null or _ossos_cauda.is_empty():
		return
	# A cauda bate no ritmo da velocidade (patrulha, perseguição, arrancada) e balança
	# EM CIMA do repouso do osso — o osso da cauda nasce torto uns 31 graus, e pôr a
	# rotação absoluta o endireitava a cada quadro.
	_tempo_cauda += delta * _ritmo
	for j in _ossos_cauda.size():
		var fase := _tempo_cauda * 4.2 - float(j) * 0.65
		var amplitude := 0.20 if j == 0 else 0.38
		_esqueleto.set_bone_pose_rotation(_ossos_cauda[j], _repousos_cauda[j] * Quaternion(_eixos_cauda[j], sin(fase) * amplitude))


## Rastro leve de espuma atrás da barbatana, rente à superfície.
func _montar_espuma() -> void:
	_espuma = GPUParticles3D.new()
	_espuma.name = "Rastro"
	_espuma.amount = 20
	_espuma.lifetime = 1.1
	_espuma.emitting = false
	_espuma.local_coords = false
	var processo := ParticleProcessMaterial.new()
	processo.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	processo.emission_sphere_radius = 0.12
	# Para trás e rente à água: a espuma fica na esteira, sem subir.
	processo.direction = Vector3(0, 0, 1)
	processo.spread = 25.0
	processo.flatness = 1.0
	processo.gravity = Vector3.ZERO
	processo.initial_velocity_min = 0.1
	processo.initial_velocity_max = 0.3
	processo.damping_min = 0.2
	processo.damping_max = 0.5
	processo.scale_min = 0.6
	processo.scale_max = 1.2
	var some := Gradient.new()
	some.set_color(0, Color(1, 1, 1, 0.7))
	some.set_color(1, Color(1, 1, 1, 0.0))
	var rampa := GradientTexture1D.new()
	rampa.gradient = some
	processo.color_ramp = rampa
	_espuma.process_material = processo
	var placa := PlaneMesh.new()
	placa.size = Vector2(0.22, 0.22)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _textura_redonda()
	material.roughness = 0.5
	material.render_priority = 1
	placa.material = material
	_espuma.draw_pass_1 = placa
	_espuma.position = Vector3(0.0, 0.03, 0.35)
	add_child(_espuma)


## CanvasLayer próprio do susto: flash branco, vinheta vermelha e cortina preta.
func _montar_tela() -> void:
	_tela = CanvasLayer.new()
	_tela.name = "TelaTubarao"
	_tela.layer = 96
	_tela.visible = false
	add_child(_tela)
	_vinheta = TextureRect.new()
	_vinheta.name = "Vinheta"
	var degrade := Gradient.new()
	degrade.set_color(0, Color(0.45, 0.0, 0.0, 0.0))
	degrade.set_color(1, Color(0.3, 0.0, 0.0, 0.9))
	degrade.add_point(0.55, Color(0.45, 0.0, 0.0, 0.0))
	var textura := GradientTexture2D.new()
	textura.gradient = degrade
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.0, 0.5)
	textura.width = 256
	textura.height = 256
	_vinheta.texture = textura
	_vinheta.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vinheta.stretch_mode = TextureRect.STRETCH_SCALE
	_vinheta.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vinheta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vinheta.modulate.a = 0.0
	# O fechamento da vinheta é a escala caindo até 1 com o pivô no centro da tela.
	_vinheta.resized.connect(func() -> void: _vinheta.pivot_offset = _vinheta.size * 0.5)
	_tela.add_child(_vinheta)
	_flash = ColorRect.new()
	_flash.name = "Flash"
	_flash.color = Color(1, 1, 1, 1)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	_tela.add_child(_flash)
	_preto = ColorRect.new()
	_preto.name = "Cortina"
	_preto.color = Color(0, 0, 0, 1)
	_preto.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preto.modulate.a = 0.0
	_tela.add_child(_preto)


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
