extends "res://tests/suite/caso.gd"
## Confere o GIRO DOS MORADORES (#209): como o viajante, o morador nunca anda de
## lado deslizando. O corpo gira para o rumo com a velocidade angular limitada
## do viajante (sem salto de um quadro) e o passo espera o corpo virar.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste giro_dos_moradores
##
## Um morador do vale, com a rotina parada, recebe o rumo quadro a quadro pelo
## mesmo `_mover` que o dia dele usa:
##   1. rumo a 90° do corpo: nenhum quadro gira além do teto; quando a velocidade
##      passa de 0,5 m/s o corpo não está a mais de 60° do rumo (nada de patinar de
##      lado); ao fim ele anda para o rumo e o corpo olha para onde anda;
##   2. meia-volta (180°): idem, sem nunca andar de costas;
##   3. olhando alguém (`_olhar_para`): o mesmo teto por quadro.
##
## FALSIFICAÇÃO: `-- --falsificar=salto` crava o corpo no rumo de uma vez (a
## virada seca de antes) e `-- --falsificar=deslize` o deixa de lado, sem virar, para o
## rumo enquanto ele anda (o patinar de lado). Os dois têm de reprovar.

var falhas := 0
var falsificar := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--falsificar="):
			falsificar = arg.substr("--falsificar=".length())
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("GIRO_DOS_MORADORES_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(6)
	await _mundo_pronto()
	await _frames(10)
	var vale := current_scene
	var jogador = vale.get("player")
	var alvo = null
	for m in get_nodes_in_group("moradores"):
		var morador = m
		if morador.get("visual") != null and morador.get("terreno") != null:
			alvo = morador
			break
	if alvo == null or jogador == null:
		_conferir(false, "o vale não tem morador com corpo e terreno")
		_fechar()
		return

	var teto: float = float(alvo.get_script().GiroDoViajante.VELOCIDADE_DE_GIRO) / float(Engine.physics_ticks_per_second)
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	# A rotina dele fica parada: quem manda o rumo, quadro a quadro, é este portão.
	alvo.set_physics_process(false)
	# Chão aberto: um ponto perto do posto dele sem nada a 4 m em volta, achado em anéis.
	var origem: Vector3 = alvo.global_position
	var achou := false
	for raio in [0.0, 3.0, 6.0, 9.0, 12.0, 16.0]:
		for graus in range(0, 360, 30):
			var ponto: Vector3 = origem + Vector3(raio, 0.0, 0.0).rotated(Vector3.UP, deg_to_rad(float(graus)))
			ponto.y = float(alvo.terreno.ground_height_at(ponto)) + 0.15
			alvo.global_position = ponto
			alvo.velocity = Vector3.ZERO
			for i in 6:
				await physics_frame
				alvo._mover(Vector3.ZERO, 1.5, dt)
			var livre: bool = alvo.is_on_floor() and float(alvo.terreno.water_depth_at(ponto)) <= 0.15
			for lado_teste in [-1.0, 1.0]:
				if alvo.test_move(alvo.global_transform.translated(Vector3.UP * 0.15), Vector3(3.5 * lado_teste, 0.0, 0.0)):
					livre = false
			if livre:
				achou = true
				break
		if achou:
			break
	_conferir(achou, "não há chão aberto (4 m livres em volta) perto do posto dele")
	alvo.velocity = Vector3.ZERO

	# --- 1. RUMO A 90° ---------------------------------------------------------
	var r1 := await _andar(alvo, Vector3.RIGHT, 0.0, teto, dt)
	_relatar("a 90°", r1, teto)
	# --- 2. MEIA-VOLTA ---------------------------------------------------------
	var r2 := await _andar(alvo, Vector3.LEFT, atan2(1.0, 0.0), teto, dt)
	_relatar("meia-volta", r2, teto)
	# --- 3. OLHAR PARA ALGUÉM -------------------------------------------------
	alvo.visual.rotation.y = 0.0
	var antes: float = alvo.visual.rotation.y
	var maior_olhar := 0.0
	for i in 40:
		alvo._olhar_para(alvo.global_position + Vector3(0.0, 0.0, -5.0), dt)
		await physics_frame
		maior_olhar = maxf(maior_olhar, absf(angle_difference(antes, alvo.visual.rotation.y)))
		antes = alvo.visual.rotation.y
	_conferir(maior_olhar <= teto * 1.05 + 0.000001,
		"olhando para trás, um quadro girou %.1f° (teto %.1f°)" % [rad_to_deg(maior_olhar), rad_to_deg(teto)])
	_conferir(absf(angle_difference(alvo.visual.rotation.y, PI)) < deg_to_rad(20.0),
		"ao fim do olhar o corpo ficou a %.0f° do ponto" % rad_to_deg(absf(angle_difference(alvo.visual.rotation.y, PI))))
	print("  olhar para trás: maior quadro %.1f° (teto %.1f°)" % [rad_to_deg(maior_olhar), rad_to_deg(teto)])
	_fechar()


## Põe o corpo em `giro_inicial` e manda andar rumo a `rumo` por 90 quadros.
func _andar(morador, rumo: Vector3, giro_inicial: float, teto: float, dt: float) -> Dictionary:
	morador.visual.rotation.y = giro_inicial
	morador.velocity = Vector3.ZERO
	var antes: float = morador.visual.rotation.y
	var maior_giro := 0.0
	var maior_patinada := 0.0
	var andou_para_tras := false
	var saiu: Vector3 = morador.global_position
	var alvo_rumo := atan2(rumo.x, rumo.z)
	for i in 90:
		morador._mover(rumo, 1.5, dt)
		if falsificar == "salto":
			morador.visual.rotation.y = alvo_rumo
		elif falsificar == "deslize":
			morador.visual.rotation.y = giro_inicial
		await physics_frame
		var corpo: float = morador.visual.rotation.y
		maior_giro = maxf(maior_giro, absf(angle_difference(antes, corpo)))
		antes = corpo
		var v: Vector2 = Vector2(morador.get_real_velocity().x, morador.get_real_velocity().z)
		if v.length() > 0.5:
			var fora := absf(angle_difference(corpo, atan2(v.x, v.y)))
			maior_patinada = maxf(maior_patinada, fora)
	var ate: Vector3 = morador.global_position - saiu
	var andou := Vector2(ate.x, ate.z)
	var fim := absf(angle_difference(morador.visual.rotation.y, alvo_rumo))
	return {"giro": maior_giro, "patinada": maior_patinada, "andou": andou.length(),
		"na_direcao": andou.normalized().dot(Vector2(rumo.x, rumo.z)) if andou.length() > 0.05 else 0.0,
		"fim": fim}


func _relatar(nome: String, r: Dictionary, teto: float) -> void:
	_conferir(float(r.giro) <= teto * 1.05 + 0.000001,
		"%s: um quadro girou %.1f° (teto %.1f°)" % [nome, rad_to_deg(float(r.giro)), rad_to_deg(teto)])
	_conferir(float(r.patinada) <= deg_to_rad(60.0),
		"%s: andou a %.0f° de onde o corpo olha (patinou de lado)" % [nome, rad_to_deg(float(r.patinada))])
	_conferir(float(r.andou) > 1.0 and float(r.na_direcao) > 0.8,
		"%s: não andou para o rumo (andou %.2f u, alinhamento %.2f)" % [nome, float(r.andou), float(r.na_direcao)])
	_conferir(float(r.fim) < deg_to_rad(15.0),
		"%s: ao fim o corpo está a %.0f° do rumo" % [nome, rad_to_deg(float(r.fim))])
	print("  %-11s maior quadro %.1f° (teto %.1f°), pior desvio andando %.0f°, andou %.2f u, corpo a %.0f° do rumo"
		% [nome, rad_to_deg(float(r.giro)), rad_to_deg(teto), rad_to_deg(float(r.patinada)), float(r.andou), rad_to_deg(float(r.fim))])


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("GIRO_DOS_MORADORES_OK: o morador gira para o rumo sem passar do teto angular do viajante por quadro, o passo espera o corpo virar (de lado e na meia-volta não patina) e, parado, o olhar tem o mesmo teto")
	else:
		print("giro_dos_moradores: %d falha(s)" % falhas)
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
