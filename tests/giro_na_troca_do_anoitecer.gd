extends "res://tests/suite/caso.gd"
## MEDIÇÃO (#258, #247): os moradores na troca de agenda do entardecer.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste giro_na_troca_do_anoitecer
##
## Versão de MEDIÇÃO: imprime o que cada morador fez de 16:50 a 19:40 (a hora em que quase todos
## trocam de agenda e vão para casa), sem cobrar nada ainda.

const TETO_S := 400

var falhas := 0
var amostras: Dictionary = {}
var nomes: Dictionary = {}
var corpos: Array = []
var dt := 1.0 / 60.0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("GIRO_NA_TROCA_DO_ANOITECER_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(6)
	await _mundo_pronto()
	await _frames(10)
	var vale = current_scene
	while vale.apresentacao_do_povoado == null:
		await process_frame
	vale.apresentacao_do_povoado.liberar_todos()
	var mundo = vale.world
	var jogador = vale.player
	var dia = root.get_node("/root/Dia")
	var navegacao = vale.get("navegacao")
	var pronta: bool = navegacao != null and await _ate(func() -> bool: return navegacao.esta_pronta(), 60.0)
	_conferir(pronta, "a malha de navegação não ficou pronta em 60 s")

	corpos = []
	for m in vale.moradores:
		corpos.append(m)
	corpos.append(vale.pedro)
	# O jogador fica na praça: todos a menos de 90 u (andam de verdade, com física).
	var praca: Vector3 = mundo.ground_position(mundo.ancoras["Praça"], 0.05)
	jogador.teleportar(praca + Vector3(0.0, 0.0, -9.0), 0.0)
	dia.pausado = false
	dia.definir_hora(16.8)
	for m in corpos:
		if m == vale.pedro:
			continue
		m.ir_ao_posto_agora()
	await _passos(30)
	for m in corpos:
		var id := str(m.dados.get("id", "pedro"))
		nomes[id] = m
		amostras[id] = []

	var limite_hora := 19.7
	var quadros := 0
	while dia.hora < limite_hora or dia.hora > 20.0:
		await physics_frame
		quadros += 1
		for m in corpos:
			_amostrar(m, quadros)
		if quadros > 60 * 200:
			break
	print("medido: %d quadros de física, até %.2f h" % [quadros, dia.hora])
	_relatar()
	_fechar()


func _amostrar(m, quadro: int) -> void:
	var id := str(m.dados.get("id", "pedro"))
	var anim_nome := ""
	if m.animador != null and m.animador.get("animation_player") != null:
		anim_nome = str(m.animador.animation_player.current_animation)
	(amostras[id] as Array).append({
		"t": quadro * dt, "x": m.global_position.x, "z": m.global_position.z,
		"yaw": m.visual.rotation.y, "v": m._velocidade_atual,
		"posto": m._posto, "acao": m._acao, "rec": m._recolhido, "dorm": m._dormindo,
		"falta": Vector2(m._alvo.x - m.global_position.x, m._alvo.z - m.global_position.z).length(),
		"desvio": m._desvio_tempo, "parado": m._parado, "pass": m._passagem_resta, "anim": anim_nome,
		"hora": root.get_node("/root/Dia").hora,
	})


## Para cada janela de 3 s: o giro acumulado (soma dos |Δyaw|) e o quanto o corpo se deslocou.
func _relatar() -> void:
	print("")
	print("=== PIÕES (giro > 360° em 3 s com deslocamento < 1,5 m) ===")
	var total_piao := 0
	for id in amostras:
		var a: Array = amostras[id]
		var janela := 180
		var pior := {"giro": 0.0, "desloc": 0.0, "t": 0.0}
		var piao_frames := 0
		for i in range(0, a.size() - janela, 6):
			var giro := 0.0
			var minx := 1.0e9
			var maxx := -1.0e9
			var minz := 1.0e9
			var maxz := -1.0e9
			for k in range(i + 1, i + janela):
				if a[k]["rec"] or a[k - 1]["rec"]:
					giro = 0.0
					break
				giro += absf(angle_difference(a[k - 1]["yaw"], a[k]["yaw"]))
				minx = minf(minx, a[k]["x"]); maxx = maxf(maxx, a[k]["x"])
				minz = minf(minz, a[k]["z"]); maxz = maxf(maxz, a[k]["z"])
			var desloc := Vector2(maxx - minx, maxz - minz).length() if giro > 0.0 else 0.0
			if rad_to_deg(giro) > 360.0 and desloc < 1.5:
				piao_frames += 1
				if giro > pior["giro"]:
					pior = {"giro": giro, "desloc": desloc, "t": a[i]["t"], "i": i}
		if piao_frames > 0:
			total_piao += 1
			var s: Dictionary = a[int(pior["i"])]
			print("  PIÃO %-14s %d janelas; pior: giro %.0f° desloc %.2f u em t=%.1fs hora=%.2f posto=%s acao=%s falta=%.2f v=%.2f desvio=%.1f parado=%.1f anim=%s" % [
				id, piao_frames, rad_to_deg(float(pior["giro"])), float(pior["desloc"]), float(pior["t"]), float(s["hora"]), s["posto"], s["acao"], float(s["falta"]), float(s["v"]), float(s["desvio"]), float(s["parado"]), s["anim"]])
	print("  moradores com pião: %d" % total_piao)

	print("")
	print("=== INVERSÕES DE RUMO e TROCAS andar/parado (por morador) ===")
	for id in amostras:
		var a: Array = amostras[id]
		var inversoes := 0
		var trocas := 0
		var andou := 0.0
		var anda_antes: bool = a[0]["v"] > 0.2
		var rumo_antes := Vector2.ZERO
		var ref_i := 0
		# Rumo medido a cada 0,5 s de deslocamento líquido.
		for i in range(30, a.size(), 30):
			var d := Vector2(a[i]["x"] - a[ref_i]["x"], a[i]["z"] - a[ref_i]["z"])
			andou += d.length()
			if d.length() > 0.25:
				if rumo_antes != Vector2.ZERO and rad_to_deg(rumo_antes.angle_to(d)) > 120.0 or rad_to_deg(rumo_antes.angle_to(d)) < -120.0 and rumo_antes != Vector2.ZERO:
					inversoes += 1
				rumo_antes = d
			ref_i = i
		for k in range(1, a.size()):
			var anda: bool = a[k]["v"] > 0.2
			if anda != anda_antes:
				trocas += 1
				anda_antes = anda
		var segundos: float = a[a.size() - 1]["t"] - a[0]["t"]
		print("  %-14s andou %6.1f u  inversões>120° %2d  trocas andar/parado %3d (%.2f/s)" % [id, andou, inversoes, trocas, float(trocas) / segundos])

	print("")
	print("=== O GUARDA, de 30 em 30 s ===")
	var g: Array = amostras["guarda"]
	for i in range(0, g.size(), 180):
		var s: Dictionary = g[i]
		print("  t=%5.1f hora=%.2f pos=(%.2f, %.2f) posto=%s falta=%.2f v=%.2f desvio=%.1f parado=%.1f anim=%s" % [
			float(s["t"]), float(s["hora"]), float(s["x"]), float(s["z"]), s["posto"], float(s["falta"]), float(s["v"]), float(s["desvio"]), float(s["parado"]), s["anim"]])


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("GIRO_NA_TROCA_DO_ANOITECER_OK: medição")
	else:
		print("giro_na_troca_do_anoitecer: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if bool(condicao.call()):
			return true
		await process_frame
	return bool(condicao.call())


func _passos(n: int) -> void:
	for i in n:
		await physics_frame


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
