## Diretor de tomadas para teaser: monta o vale, tira a HUD, assume a câmera e
## grava cada tomada de um plano JSON em PNG, quadro a quadro.
##
## Rode com passo fixo, para o tempo do jogo andar 1/30 s por quadro mesmo que o
## quadro leve segundos para sair (Vulkan por software, por exemplo):
##
##   godot --path . --fixed-fps 30 --resolution 1280x720 res://tools/teaser/diretor.tscn \
##       -- --lugar=praca --sem-sustos --plano=/abs/plano.json --saida=/abs/quadros [--so=a,b] [--previa]
##
## `--previa` grava só o primeiro e o último quadro de cada tomada, para conferir
## enquadramento depressa. Posições do plano são em unidades do mundo (1 u = 4 m),
## relativas a um lugar de `Lugares` (`base`) posto no chão.
extends Node

const VALE := "res://scenes/prototipo_3d/vale.tscn"
const SOBREVOO := "res://data/sobrevoo_menu.json"
const AQUECIMENTO := 12

var _vale: Node3D
var _mundo: Node3D
var _camera: Camera3D
var _args := {}
var _sobrevoo := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var partes := arg.substr(2).split("=", true, 1)
			_args[partes[0]] = partes[1]
		elif arg.begins_with("--"):
			_args[arg.substr(2)] = true
	var plano: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_args["plano"]))
	var so: Array = str(_args.get("so", "")).split(",", false)
	_sobrevoo = JSON.parse_string(FileAccess.get_file_as_string(SOBREVOO))

	_vale = (load(VALE) as PackedScene).instantiate() as Node3D
	add_child(_vale)
	_mundo = _vale.get_node("Cenario")
	while not _mundo.construido or not _vale.get("carga_ok"):
		await get_tree().process_frame
	for i in 30:
		await get_tree().process_frame
	Dia.pausado = true
	_vale.cenas.desligadas = true
	if _vale.apresentacao_do_povoado != null:
		_vale.apresentacao_do_povoado.liberar_todos()
	_camera = Camera3D.new()
	_camera.fov = 52.0
	_camera.near = 0.08
	_camera.far = 2800.0
	_vale.add_child(_camera)
	_camera.make_current()
	for nome in Lugares.nomes():
		print("LUGAR %s %s" % [nome, Lugares.ponto(nome)])

	for tomada: Dictionary in plano["tomadas"]:
		if so.size() > 0 and not so.has(tomada["nome"]):
			continue
		await _gravar(tomada)
	print("DIRETOR_FIM")
	get_tree().quit()


func _gravar(t: Dictionary) -> void:
	var quadros := int(t.get("quadros", 90))
	Dia.definir_hora(float(t.get("hora", 9.0)))
	var horas_por_quadro := float(t.get("avancar_horas", 0.0)) / float(quadros)
	_preparar_jogador(t)
	_aplicar_camera(t, 0.0)
	for i in AQUECIMENTO:
		_aplicar_camera(t, 0.0)
		await RenderingServer.frame_pre_draw
		_esconder_hud()
		await RenderingServer.frame_post_draw
	await _acao(t)
	var pasta := "%s/%s" % [_args["saida"], t["nome"]]
	DirAccess.make_dir_recursive_absolute(pasta)
	print("TOMADA %s %d quadros" % [t["nome"], quadros])
	for i in quadros:
		var p := float(i) / float(max(quadros - 1, 1))
		_aplicar_camera(t, p)
		if horas_por_quadro != 0.0:
			Dia.definir_hora(fposmod(Dia.hora + horas_por_quadro, 24.0))
		# Os moradores religam o marcador no próprio _process: esconder depois
		# dele, já com o quadro a caminho do desenho.
		await RenderingServer.frame_pre_draw
		_esconder_hud()
		await RenderingServer.frame_post_draw
		if not _args.has("previa") or i == 0 or i == quadros - 1:
			get_viewport().get_texture().get_image().save_png("%s/%04d.png" % [pasta, i])
	_desfazer_acao(t)


func _base(t: Dictionary) -> Vector3:
	if t.has("base"):
		return _mundo.ground_position(Lugares.ponto(t["base"]), 0.0)
	return Vector3.ZERO


func _v(a) -> Vector3:
	return Vector3(a[0], a[1], a[2])


func _preparar_jogador(t: Dictionary) -> void:
	var jogador: Node3D = _vale.player
	var pedro: Node3D = _vale.pedro
	if pedro != null:
		pedro.set("_ultima_saudacao_ms", Time.get_ticks_msec())
	var j: Dictionary = t.get("jogador", {})
	jogador.visible = not j.is_empty()
	if not j.is_empty():
		var pos: Vector3 = _mundo.ground_position(_base(t) + _v(j["pos"]), 0.07)
		jogador.teleportar(pos, deg_to_rad(float(j.get("rumo", 0.0))))
		if j.has("mao"):
			Inventario.adicionar(j["mao"], 1)
			for slot in 10:
				if str(Inventario.espacos[slot].get("id", "")) == j["mao"]:
					Inventario.selecionar(slot)
					break
		else:
			Inventario.selecionar(-1)
	# Quem não deve aparecer: pelo id, ou todo morador a menos de `esconder_raio` do jogador.
	var raio := float(t.get("esconder_raio", 0.0))
	for m in _vale.moradores:
		var id := str(m.dados.get("id", ""))
		var perto: bool = raio > 0.0 and m.global_position.distance_to(jogador.global_position) < raio
		m.visible = not (t.get("esconder", []).has(id) or perto)
		if perto:
			print("ESCONDIDO %s" % id)
	var p: Dictionary = t.get("pedro", {})
	if pedro != null:
		pedro.visible = not p.is_empty() or t.get("pedro_visivel", false)
		if not p.is_empty():
			pedro.global_position = _mundo.ground_position(_base(t) + _v(p["pos"]), 0.0)
			pedro.rotation.y = deg_to_rad(float(p.get("rumo", 0.0)))


func _acao(t: Dictionary) -> void:
	match str(t.get("acao", "")):
		"pesca":
			print("PESCA lance=%s" % str(_vale.pesca.lancar()))
		"enxada":
			var cel: Vector2i = _vale.lavoura.leito_da_vez()
			_vale.lavoura._gesto_no_leito(cel)
		"folheto":
			_vale.ler_o_folheto(str(t.get("folheto", "moleque_do_pier")))
			for i in 20:
				await get_tree().process_frame
		"acenar", "apontar":
			var quem := str(t.get("morador", "pedro"))
			var m = _vale.pedro if quem == "pedro" else _vale._achar_morador(quem)
			if m != null:
				m.gesto(str(t["acao"]))
	return


func _desfazer_acao(t: Dictionary) -> void:
	if str(t.get("acao", "")) == "folheto":
		_vale.telas.fechar_tudo()
		get_tree().paused = false


func _esconder_hud() -> void:
	for camada in _vale.find_children("*", "CanvasLayer", true, false):
		if not (camada as CanvasLayer).name.begins_with("Folheto"):
			(camada as CanvasLayer).visible = false
	if _vale.get("_seta") != null:
		_vale._seta.ocultar(true)
	for m in _vale.moradores + [_vale.pedro]:
		if m == null:
			continue
		var marcador = m.get_node_or_null("MarcadorDeMissao")
		if marcador != null:
			marcador.visible = false
		for marca in m.find_children("*", "Label3D", true, false) + m.find_children("*", "Sprite3D", true, false):
			(marca as Node3D).visible = false


func _suave(p: float) -> float:
	return p * p * (3.0 - 2.0 * p)


func _aplicar_camera(t: Dictionary, p: float) -> void:
	var c: Dictionary = t["camera"]
	if c.has("fov"):
		_camera.fov = float(c["fov"])
	var s := _suave(p) if c.get("suave", true) else p
	match str(c.get("tipo", "linha")):
		"sobrevoo":
			var q := lerpf(float(c["de"]), float(c["ate"]), p)
			var olho := _catmull(_sobrevoo["olho"], q) + _v(c.get("subir", [0, 0, 0]))
			_camera.global_position = olho
			_camera.look_at(_catmull(_sobrevoo["alvo"], q), Vector3.UP)
		"orbita":
			var centro := _base(t) + _v(c["centro"])
			var ang := deg_to_rad(lerpf(float(c["ang_de"]), float(c["ang_ate"]), s))
			var raio := lerpf(float(c["raio"]), float(c.get("raio_ate", c["raio"])), s)
			var alt := lerpf(float(c["altura"]), float(c.get("altura_ate", c["altura"])), s)
			_camera.global_position = centro + Vector3(sin(ang) * raio, alt, cos(ang) * raio)
			_camera.look_at(centro, Vector3.UP)
		_:
			var b := _base(t)
			_camera.global_position = b + _v(c["olho_de"]).lerp(_v(c.get("olho_ate", c["olho_de"])), s)
			_camera.look_at(b + _v(c["alvo_de"]).lerp(_v(c.get("alvo_ate", c["alvo_de"])), s), Vector3.UP)


func _catmull(amostras: Array, progresso: float) -> Vector3:
	var n := amostras.size()
	var f := fposmod(progresso, 1.0) * n
	var i := int(floor(f))
	var u := f - i
	var a := _v(amostras[posmod(i - 1, n)])
	var b := _v(amostras[i % n])
	var c := _v(amostras[(i + 1) % n])
	var d := _v(amostras[(i + 2) % n])
	return b.cubic_interpolate(c, a, d, u)
