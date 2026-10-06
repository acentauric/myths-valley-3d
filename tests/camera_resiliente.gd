extends SceneTree
## Confere A CÂMERA RESILIENTE: nunca dentro do personagem, nunca debaixo d'água.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/camera_resiliente.gd
##
## `camera_resiliente_procedural.gd` faz o outro estilo. Três queixas do dono,
## na noite do Build 9B: "já havíamos corrigido a questão da câmera não entrar
## dentro da água do mar, mas continuou"; "tente resolver as áreas de colisão ao
## entrar e sair da casa, principalmente porque está bugando a câmera, que nunca
## pode entrar dentro do personagem"; "a câmera deve ser resiliente nessas
## interações". Duas perguntas, medidas A CADA QUADRO e sem tolerância — os
## portões de antes olhavam 20 ou 30 quadros DEPOIS de a coisa acontecer, e por
## isso nunca viram o quadro em que ela acontecia:
##
##   1. A PORTA. Em todos os cômodos do vale (a igreja e as casas, e os que vierem:
##      a lista é a do `Interiores`), entrando e saindo, a pé, com a câmera atrás,
##      de lado, de frente e de viés: a câmera não chega a menos de `BRACO_MINIMO`
##      do pivô (nem a menos de `CORPO_MINIMO` do corpo), a cada quadro.
##   2. A ORLA E O NADO. Na beira d'água, andando no raso (0,5, 0,9 e 1,15 u de
##      água), nadando parado e nadando em movimento, com a câmera atrás, de
##      frente, alta e baixa, perto e longe, e girando para cima e para baixo:
##      a câmera fica `AGUA_MINIMA` acima da água DAQUI E AGORA — também na
##      baixa-mar — a cada quadro. A superfície que barra o braço (`mar.gd`) não
##      vale quando a esfera do braço já a cobre ao sair do pivô, e o pivô de quem
##      nada parado fica abaixo dela.
##
## O que o corte do `SpringArm3D` faz com o que já o cobre foi MEDIDO na sonda
## desta correção: ignora. Por isso as duas garantias da câmera (`braco_minimo` e
## `camera_acima_da_agua`, em `player_controller.gd`) são conta, e não física.
##
## FALSIFICAÇÃO: `-- --falsificar=braco` zera o braço mínimo (e desliga a subida),
## e a porta TEM de reprovar; `-- --falsificar=agua` zera a folga sobre a água, e a
## orla TEM de reprovar. A variável de ambiente `MV_FALSIFICAR` faz o mesmo.

const RelogioDeJogo = preload("res://tests/fixtures/relogio_de_jogo.gd")

## O menor braço que a câmera tem de manter (a garantia é 1,25; sobra o que o
## quadro lento e a mola comem).
const BRACO_MINIMO := 1.2
## A menor distância da câmera ao eixo do corpo (da cintura à cabeça), em metros.
const CORPO_MINIMO := 0.75
## A menor folga da câmera sobre a água (a garantia é 0,35).
const AGUA_MINIMA := 0.30
## Giros da câmera, em graus, em relação a "atrás do jogador": de costas, de
## lado, de frente e de viés. Os cômodos de câmera de passeio e a casa herdada
## levam todos; os outros, os dois que mais pesam.
const GIROS_TODOS := [0, 90, 180, -45]
const GIROS_CURTOS := [0, 90]
## Quanto a câmera pode ficar dentro de uma parede de câmera (s, de jogo): o vão
## baixo de uma porta não deixa outro lugar para uma câmera a 1,25 m do corpo — e o
## túnel da torre da igreja procedural, de meio metro de parede a parede, deixa menos
## ainda. Antes do braço mínimo ela ficava DENTRO DO CORPO; agora, no máximo uns
## quadros dentro da parede do túnel, vendo o jogador pelo avesso dela.
const DENTRO_MAXIMO_S := 0.5

var falhas := 0
var vale
var world
var jogador
var interiores
var relogio
var falsificar := ""
var espaco: PhysicsDirectSpaceState3D
var consulta_dentro := PhysicsPointQueryParameters3D.new()


## O estilo do vale em que o portão roda: `camera_resiliente_procedural.gd` o troca.
func _estilo_do_portao() -> String:
	return "tripo"


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("CAMERA_RESILIENTE_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	root.get_node("/root/Estilo").modo = _estilo_do_portao()
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(8)
	vale = current_scene
	world = vale.get("world")
	jogador = vale.get("player")
	interiores = vale.get("interiores")
	_conferir(world != null and jogador != null and interiores != null, "o vale não montou o mundo, o jogador ou os cômodos")
	if falhas > 0:
		_fechar()
		return
	relogio = RelogioDeJogo.new()
	root.add_child(relogio)
	relogio.ficar_lento()
	espaco = world.get_world_3d().direct_space_state
	consulta_dentro.collision_mask = 1 << 13
	_falsificar()
	print("física: ", ProjectSettings.get_setting("physics/3d/physics_engine", "DEFAULT"), " (DEFAULT é o do Godot, sem Jolt)")
	var pedro = vale.get("pedro")
	if pedro != null:
		pedro.ir_ao_passo("roca")
	# Morador e bicho não são parede: o gate mede a câmera contra a geometria, e quem fica
	# parado no vão (a Dona Zefa, em casa, no procedural) não pode decidir se o corpo passa.
	for no in vale.find_children("*", "CharacterBody3D", true, false):
		if no != jogador:
			jogador.add_collision_exception_with(no)
	vale._acertar_a_porta_da_casa()
	for qual in interiores.get("_construcoes"):
		var sala: Node3D = interiores.sala_de(qual)
		if sala != null and sala.has_method("trancar"):
			sala.trancar(false)

	print("")
	print("1. a porta (a cada quadro: braço >= %.2f m, corpo >= %.2f m)" % [BRACO_MINIMO, CORPO_MINIMO])
	for qual in interiores.get("_construcoes"):
		await _porta(qual)
	print("")
	print("2. a orla e o nado (a cada quadro: câmera >= %.2f m acima da água)" % AGUA_MINIMA)
	await _orla()
	_fechar()


func _falsificar() -> void:
	var pedido := OS.get_environment("MV_FALSIFICAR")
	for argumento in OS.get_cmdline_user_args():
		if str(argumento).begins_with("--falsificar="):
			pedido = str(argumento).trim_prefix("--falsificar=")
	falsificar = pedido
	if falsificar == "braco":
		jogador.braco_minimo = 0.0
		print("  FALSIFICAÇÃO: o braço mínimo é zero (e a câmera não sobe): a porta TEM de reprovar")
	elif falsificar == "agua":
		jogador.camera_acima_da_agua = -100.0
		print("  FALSIFICAÇÃO: a folga sobre a água é -100: a orla TEM de reprovar")


# --- 1. A PORTA -------------------------------------------------------------------

func _porta(qual: String) -> void:
	var sala: Node3D = interiores.sala_de(qual)
	if sala == null:
		return
	var giros: Array = GIROS_TODOS if (qual == "igreja" or qual == "casa") else GIROS_CURTOS
	for entrando in [true, false]:
		for graus in giros:
			await _cruzar(sala, qual, entrando, deg_to_rad(float(graus)), int(graus))


## Atravessa a porta de `sala` andando, com a câmera `giro` rad fora de "atrás do
## jogador", e mede a câmera a cada quadro.
func _cruzar(sala: Node3D, qual: String, entrando: bool, giro: float, graus: int) -> void:
	var frente: Vector3 = sala.global_basis.z.normalized()
	var sentido: Vector3 = -frente if entrando else frente
	var yaw_andar := atan2(-sentido.x, -sentido.z)
	var rumo := yaw_andar - PI
	# De fora, a 0,6 m da soleira de fora: mais longe, o procedural tem o cruzeiro a um
	# passo da fachada e o corpo nem sai do lugar.
	var z_soleira: float = sala.to_local(sala.soleira_de_fora()).z
	var inicio: Vector3 = world.ground_position(sala.soleira_de_fora() + frente * 0.6, 0.05) if entrando \
		else sala.to_global(Vector3(sala.porta_x, 0.05, -1.8))
	jogador.teleportar(inicio, rumo)
	jogador.set("_yaw", yaw_andar + giro)
	jogador.set("_distance", 8.0)
	await relogio.esperar(0.7)
	var camera: Camera3D = jogador.camera
	var m := {"braco": INF, "corpo": INF, "dentro": 0.0, "dentro_max": 0.0, "lado": 0.0, "lado_max": 0.0, "salto": 0.0}
	var anterior := -1.0
	var face_de_fora: float = sala.PAREDE + sala.fundo_da_porta
	var fim := false
	var chegou := -1.0
	var comeco: float = relogio.agora()
	var ultimo: float = comeco
	_andar(giro)
	while relogio.agora() - comeco < 7.0 and not fim:
		await process_frame
		var agora: float = relogio.agora()
		var dt: float = maxf(agora - ultimo, 0.001)
		ultimo = agora
		var d_pivo := camera.global_position.distance_to(jogador.camera_pivot.global_position)
		m["braco"] = minf(m["braco"], d_pivo)
		m["corpo"] = minf(m["corpo"], _distancia_ao_corpo(camera.global_position))
		if anterior >= 0.0:
			m["salto"] = maxf(m["salto"], absf(d_pivo - anterior))
		anterior = d_pivo
		consulta_dentro.position = camera.global_position
		if not espaco.intersect_point(consulta_dentro, 1).is_empty():
			m["dentro"] += dt
			m["dentro_max"] = maxf(m["dentro_max"], m["dentro"])
		else:
			m["dentro"] = 0.0
		# De que lado da porta a câmera está, contra o lado do jogador, com uma
		# folga de um metro para a travessia em si: o jogador lá dentro e a câmera
		# fora do cômodo, pelo vão; o jogador lá fora e a câmera dentro do cômodo.
		var corpo_z: float = sala.to_local(jogador.global_position).z
		var camera_local: Vector3 = sala.to_local(camera.global_position)
		var pelo_vao: bool = camera_local.z > face_de_fora and absf(camera_local.x - sala.porta_x) <= sala.largura_da_porta * 0.5 + 0.8
		var errado: bool = (corpo_z <= -1.0 and pelo_vao) or (corpo_z >= face_de_fora + 1.0 and sala.contem(camera.global_position))
		if errado and not sala.camera_de_cima:
			m["lado"] += dt
			m["lado_max"] = maxf(m["lado_max"], m["lado"])
		else:
			m["lado"] = 0.0
		var passou: bool = corpo_z <= -2.2 if entrando else corpo_z >= z_soleira - 0.3
		if passou and chegou < 0.0:
			chegou = agora
		if chegou >= 0.0 and agora - chegou > 1.2:
			fim = true
	_soltar()
	var rotulo := "%-10s %-6s giro %+4d°" % [qual, "entra" if entrando else "sai", graus]
	print("  %s: braço mín %.2f m · corpo mín %.2f m · dentro de parede até %.2f s · lado errado até %.2f s · maior salto de braço %.2f m" % [
		rotulo, m["braco"], m["corpo"], m["dentro_max"], m["lado_max"], m["salto"]])
	_conferir(chegou >= 0.0, "%s: o corpo não atravessou a porta (parou em %s)" % [rotulo, str(sala.to_local(jogador.global_position).snapped(Vector3.ONE * 0.01))])
	_conferir(m["braco"] >= BRACO_MINIMO, "%s: a câmera chegou a %.2f m do pivô (mínimo %.2f): dentro do personagem" % [rotulo, m["braco"], BRACO_MINIMO])
	_conferir(m["corpo"] >= CORPO_MINIMO, "%s: a câmera chegou a %.2f m do corpo (mínimo %.2f)" % [rotulo, m["corpo"], CORPO_MINIMO])
	_conferir(m["dentro_max"] <= DENTRO_MAXIMO_S, "%s: a câmera ficou %.2f s dentro de parede" % [rotulo, m["dentro_max"]])
	_conferir(m["lado_max"] <= DENTRO_MAXIMO_S, "%s: a câmera ficou %.2f s do lado errado da porta" % [rotulo, m["lado_max"]])
	# O estado de chegada: a casa vista de cima, por cima do teto; a igreja, por dentro.
	if giro == 0.0 and chegou >= 0.0:
		if entrando and sala.camera_de_cima:
			await relogio.ate(func() -> bool: return sala.to_local(camera.global_position).y > sala.pe_direito, 3.0)
			var no_teto: Vector3 = sala.to_local(camera.global_position)
			_conferir(no_teto.y > sala.pe_direito, "%s: dentro de casa a câmera está a %.2f do chão, abaixo do teto (%.2f)" % [rotulo, no_teto.y, sala.pe_direito])
		elif entrando:
			await relogio.ate(func() -> bool: return sala.to_local(camera.global_position).z < 0.4, 3.0)
			var na_nave: Vector3 = sala.to_local(camera.global_position)
			_conferir(na_nave.z < 0.4, "%s: com o jogador na nave a câmera ficou %.2f além da parede da frente" % [rotulo, na_nave.z])


## Anda, com a câmera `giro` fora de "atrás", em direção ao que o jogador encara:
## o direcional é lido no referencial da câmera, então o vetor gira ao contrário.
func _andar(giro: float) -> void:
	_soltar()
	Input.action_press("mv_forward", maxf(cos(giro), 0.0))
	Input.action_press("mv_back", maxf(-cos(giro), 0.0))
	Input.action_press("mv_right", maxf(sin(giro), 0.0))
	Input.action_press("mv_left", maxf(-sin(giro), 0.0))


func _soltar() -> void:
	for acao in ["mv_forward", "mv_back", "mv_left", "mv_right"]:
		Input.action_release(acao)


## A menor distância de `ponto` ao eixo do corpo, da cintura à cabeça.
func _distancia_ao_corpo(ponto: Vector3) -> float:
	var a: Vector3 = jogador.global_position + Vector3.UP * 0.3
	var b: Vector3 = jogador.global_position + Vector3.UP * 1.6
	var ab := b - a
	var t := clampf((ponto - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return ponto.distance_to(a + ab * t)


# --- 2. A ORLA E O NADO -------------------------------------------------------------

func _orla() -> void:
	var mare = root.get_node("/root/Mare")
	var dia = root.get_node("/root/Dia")
	dia.pausado = true
	mare.modo = 0
	var seguinte: Vector3 = world.ancoras["PierDirecao"]
	var lado := Vector3(-seguinte.z, 0.0, seguinte.x) * 6.0
	var inicio: Vector3 = world.ancoras["PierPiso"] - seguinte * 10.0 + lado
	var pontos := {}
	for passo in range(0, 260):
		var p: Vector3 = inicio + seguinte * float(passo)
		var fundo: float = world.water_depth_at(p)
		for alvo in [0.05, 0.5, 0.9, 1.15]:
			if fundo >= alvo and not pontos.has(alvo):
				pontos[alvo] = p
	# A água funda (2,2 u: nada, e na baixa-mar de 0,6 u ainda nada) fica longe: nesta
	# baía a planície rasa vai a 190 u do píer, na diagonal.
	# (Com chão: fora do quadro do mapa não há fundo do mar, e o corpo cairia.)
	for graus in [-60, -45, -30, 0, 30]:
		var d := seguinte.rotated(Vector3.UP, deg_to_rad(float(graus)))
		for passo in range(0, 700, 5):
			var p: Vector3 = inicio + d * float(passo)
			if world.water_depth_at(p) >= 2.2 and _tem_chao(p):
				pontos[2.5] = p
				break
		if pontos.has(2.5):
			break
	_conferir(pontos.has(2.5) and pontos.has(0.5), "não achei a orla e a água funda a partir do píer (achei %s)" % str(pontos.keys()))
	if not (pontos.has(2.5) and pontos.has(0.5)):
		return
	var yaw_para_o_mar := atan2(seguinte.x, seguinte.z)
	print("  água: raso 0,05 em %s, funda em %s" % [str(pontos[0.05]), str(pontos[2.5])])

	# Andando no raso: a câmera atrás do jogador, sobre o mar, e sobre a terra.
	for alvo in [0.05, 0.5, 0.9, 1.15]:
		if not pontos.has(alvo):
			continue
		var chao := _chao(pontos[alvo])
		jogador.teleportar(chao + Vector3.UP * 0.05, yaw_para_o_mar + PI)
		await relogio.esperar(0.8)
		await _varrer("raso %.2f u" % alvo, yaw_para_o_mar)
	# Nadando parado, e em movimento.
	var funda: Vector3 = pontos[2.5]
	var nivel: float = world.water_level()
	jogador.teleportar(Vector3(funda.x, nivel - 1.5, funda.z), yaw_para_o_mar + PI)
	await relogio.ate(func() -> bool: return jogador.is_swimming(), 4.0)
	_conferir(jogador.is_swimming(), "o jogador não nadou na água funda (%.2f u)" % world.water_depth_at(jogador.global_position))
	await relogio.esperar(1.0)
	await _varrer("nadando parado", yaw_para_o_mar)
	await _girar_para_cima_e_para_baixo("nadando parado, girando a câmera")
	jogador.set("_yaw", yaw_para_o_mar + PI)
	Input.action_press("mv_forward")
	await relogio.esperar(0.8)
	await _varrer("nadando em movimento", yaw_para_o_mar)
	Input.action_release("mv_forward")
	# Na baixa-mar: o nível desce 0,6 u e a câmera tem de acompanhar o de AGORA. (A conta é a
	# mesma nos dois estilos: o procedural, só de comparação, não repete a maré.)
	if _estilo_do_portao() != "tripo":
		mare.modo = 0
		dia.pausado = false
		return
	mare.modo = 1
	dia.definir_hora(6.0)
	await relogio.esperar(0.8)
	var nivel_baixo: float = world.water_level()
	print("  maré: o mar desceu de %.2f para %.2f" % [nivel, nivel_baixo])
	_conferir(nivel_baixo < nivel - 0.4, "a baixa-mar não baixou o mar (%.2f -> %.2f): o portão não prova a maré" % [nivel, nivel_baixo])
	var fundo_agora: Vector3 = funda
	jogador.teleportar(Vector3(fundo_agora.x, nivel_baixo - 1.5, fundo_agora.z), yaw_para_o_mar + PI)
	await relogio.ate(func() -> bool: return jogador.is_swimming(), 4.0)
	_conferir(jogador.is_swimming(), "na baixa-mar o jogador não nadou na água funda (%.2f u, em %s)" % [world.water_depth_at(jogador.global_position), str(jogador.global_position.snapped(Vector3.ONE * 0.1))])
	await relogio.esperar(1.0)
	await _varrer("nadando parado na baixa-mar", yaw_para_o_mar)
	mare.modo = 0
	dia.pausado = false


## Há chão (terra ou fundo do mar) sob `ponto`?
func _tem_chao(ponto: Vector3) -> bool:
	return not espaco.intersect_ray(PhysicsRayQueryParameters3D.create(ponto + Vector3.UP * 30.0, ponto - Vector3.UP * 30.0, 1)).is_empty()


## O chão firme (da terra ou do fundo do mar) sob `ponto`.
func _chao(ponto: Vector3) -> Vector3:
	var raio := PhysicsRayQueryParameters3D.create(ponto + Vector3.UP * 30.0, ponto - Vector3.UP * 30.0, 1)
	var bateu := espaco.intersect_ray(raio)
	return bateu["position"] if not bateu.is_empty() else world.ground_position(ponto)


## Varre a câmera em volta do jogador parado: inclinações, distâncias e giros, e
## confere a água a cada quadro.
func _varrer(rotulo: String, yaw_para_o_mar: float) -> void:
	var pior := {"folga": INF, "braco": INF}
	for giro in [0.0, PI]:
		for distancia in [3.1, 8.0]:
			for inclinacao in [-0.19, 0.0, 0.35]:
				jogador.set("_yaw", yaw_para_o_mar + giro)
				jogador.set("_distance", distancia)
				jogador.set("_pitch", inclinacao)
				for quadro in 10:
					await process_frame
					_medir_a_agua(pior)
	print("  %-34s folga mín sobre a água %+.2f m · braço mín %.2f m" % [rotulo, pior["folga"], pior["braco"]])
	_conferir(is_finite(pior["folga"]), "%s: a câmera nunca esteve sobre a água (jogador em %s): o portão não mediu nada" % [rotulo, str(jogador.global_position.snapped(Vector3.ONE * 0.1))])
	_conferir(pior["folga"] >= AGUA_MINIMA, "%s: a câmera chegou a %+.2f m da água (mínimo %.2f)" % [rotulo, pior["folga"], AGUA_MINIMA])
	_conferir(pior["braco"] >= BRACO_MINIMO, "%s: a câmera chegou a %.2f m do pivô (mínimo %.2f)" % [rotulo, pior["braco"], BRACO_MINIMO])


## O jogador nada parado e o mouse gira a câmera: sobe até o teto e desce até o
## chão, quadro a quadro.
func _girar_para_cima_e_para_baixo(rotulo: String) -> void:
	var pior := {"folga": INF, "braco": INF}
	jogador.set("_distance", 8.0)
	jogador.set("_pitch", -0.5)
	for quadro in 80:
		jogador._rotate_camera(Vector2(0.0, -9.0))
		await process_frame
		_medir_a_agua(pior)
	for quadro in 120:
		jogador._rotate_camera(Vector2(0.0, 9.0))
		await process_frame
		_medir_a_agua(pior)
	print("  %-34s folga mín sobre a água %+.2f m · braço mín %.2f m" % [rotulo, pior["folga"], pior["braco"]])
	_conferir(pior["folga"] >= AGUA_MINIMA, "%s: a câmera chegou a %+.2f m da água (mínimo %.2f)" % [rotulo, pior["folga"], AGUA_MINIMA])
	_conferir(pior["braco"] >= BRACO_MINIMO, "%s: a câmera chegou a %.2f m do pivô (mínimo %.2f)" % [rotulo, pior["braco"], BRACO_MINIMO])


## A folga da câmera sobre a água de onde ela está (só vale sobre água) e o braço.
func _medir_a_agua(pior: Dictionary) -> void:
	var camera: Camera3D = jogador.camera
	var onde: Vector3 = camera.global_position
	if world.water_depth_at(onde) > 0.0:
		pior["folga"] = minf(pior["folga"], onde.y - world.water_level_at(onde))
	pior["braco"] = minf(pior["braco"], onde.distance_to(jogador.camera_pivot.global_position))


# --- fim ----------------------------------------------------------------------------

func _fechar() -> void:
	_soltar()
	print("")
	if falhas == 0:
		print("CAMERA_RESILIENTE_OK (%s): em todos os cômodos, entrando e saindo e de qualquer lado, a câmera nunca chega a %.2f m do pivô nem a %.2f m do corpo; na orla, no raso, nadando parado e em movimento, girando e na baixa-mar, ela fica sempre %.2f m acima da água de agora" % [_estilo_do_portao(), BRACO_MINIMO, CORPO_MINIMO, AGUA_MINIMA])
	else:
		print("camera resiliente (%s): %d falha(s)" % [_estilo_do_portao(), falhas])
	quit(1 if falhas > 0 else 0)


func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame


func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
