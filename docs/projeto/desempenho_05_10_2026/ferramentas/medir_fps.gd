extends SceneTree
## PERFIL DE FPS DO VALE, COM ATRIBUICAO A/B.
##
## Sobe o vale como o jogo (change_scene), tira o censo da cena, mede o quadro em
## varias vistas (posicao x rumo da camera do jogador) e, na pior vista, liga e
## desliga uma coisa de cada vez para dizer QUANTO cada uma custa.
##
## O quadro e decomposto por carimbos de tempo:
##   fisica_scripts  = physics_frame ate o ultimo _physics_process (sonda de prioridade maxima)
##   fisica_servidor = fim dos scripts de fisica ate o proximo evento (passo do servidor + navegacao)
##   process_scripts = process_frame ate o ultimo _process (sonda)
##   cauda           = fim do _process ate o proximo quadro (desenho na CPU + espera da GPU/present)
## E o RenderingServer da o tempo de desenho CPU/GPU da tela e de cada SubViewport.
##
## Nao grava nada no projeto. Rodar com janela (GPU), perfil isolado:
##   godot --path <repo> --script <este arquivo> -- --saida=<json> [--fases=censo,vistas,ab,horas,passeio]
##       [--tela=cheia|janela] [--janela=1280x720] [--lugares=a,b,c] [--rumos=8] [--ab_em=pior|<lugar>:<rumo>]
##       [--teto=1500] [--lugar=praca]   (o --lugar e lido pelo jogo: pula a chegada de saveiro)

const CENA := "res://scenes/prototipo_3d/vale.tscn"
const LUGARES_PADRAO := ["pier", "praca", "igreja", "venda", "casa_de_taipa", "lavoura", "rocado", "fogueira",
	"mirante", "cemiterio", "ponte_da_vila", "terreiro", "gameleira", "expansao", "portao_da_fazenda", "casa_da_estrada"]

var _o := {"saida": "", "fases": "censo,vistas,abcpu,abgpu,horas,passeio", "tela": "cheia", "janela": "1280x720",
	"lugares": "", "rumos": "8", "ab_em": "pior", "ab_cpu_em": "praca:270", "ab_gpu_em": "igreja:90", "teto": "1500",
	"lugar": "praca", "medir_s": "1.5", "assentar_s": "0.5", "vista_s": "1.0", "hora": "9"}
var _r := {"avisos": [], "vistas": [], "ab": [], "horas": [], "passeio": {}}
var _jogo: Node
var _mundo: Node3D
var _jogador: Node3D
var _dia: Node
var _sonda: Node
var _gravando := false
# carimbos
var _t_evento := 0
var _t_process_ini := 0
var _t_fis_ini := 0
var _fase_do_quadro := ""
# acumuladores da janela de medicao
var _a := {}
var _quadros_ms: PackedFloat32Array = PackedFloat32Array()
var _subs: Array = []
var _ultimo_quadro_us := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			_o[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	create_timer(float(_o["teto"])).timeout.connect(func() -> void:
		push_error("MEDIR_FPS: teto excedido")
		_r["avisos"].append("teto excedido")
		_gravar()
		quit(2))
	await process_frame
	root.get_node("/root/Estilo").set("modo", "tripo")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	_dia = root.get_node("/root/Dia")
	# Janela.
	if String(_o["tela"]) == "cheia":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var wh := String(_o["janela"]).split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		DisplayServer.window_set_position(Vector2i(40, 40))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_instalar_sonda()
	process_frame.connect(_ao_process_frame)
	physics_frame.connect(_ao_physics_frame)

	# --- experimentos "e se": remendos SO NA MEMORIA deste processo (o arquivo do projeto nao muda) ---
	if String(_o.get("patch_costa", "0")) == "1":
		_r["patch_costa"] = _remendar_grade_da_costa()
		print("MEDIR_FPS: remendo da grade da costa (so em memoria): ", _r["patch_costa"])
	if _o.has("max_passos"):
		Engine.max_physics_steps_per_frame = int(_o["max_passos"])
		_r["max_passos_forcado"] = Engine.max_physics_steps_per_frame

	# --- montagem ---
	var t0 := Time.get_ticks_msec()
	var erro := change_scene_to_file(CENA)
	if erro != OK:
		_r["avisos"].append("change_scene falhou: %d" % erro)
		_gravar()
		quit(1)
		return
	for i in range(40000):
		var m := get_first_node_in_group("mundo")
		if m != null and bool(m.get("construido")):
			break
		await process_frame
	_mundo = get_first_node_in_group("mundo") as Node3D
	_jogo = current_scene
	_r["montagem_ms"] = Time.get_ticks_msec() - t0
	if _mundo == null or not bool(_mundo.get("construido")):
		_r["avisos"].append("o mundo nao ficou pronto")
		_gravar()
		quit(1)
		return
	# O _ready do prototype continua depois do pronto (interiores, moradores...).
	for i in range(3000):
		if _jogo.get("narracao") != null:
			break
		await process_frame
	_r["jogo_pronto_ms"] = Time.get_ticks_msec() - t0
	_jogador = get_first_node_in_group("map_player") as Node3D
	await _esperar(4.0)
	_r["estabilizado_ms"] = Time.get_ticks_msec() - t0
	_r["relogio"] = {"velocidade": _dia.get("velocidade"), "segundos_por_hora": (_dia.get("VELOCIDADES") as Array)[int(_dia.get("velocidade"))], "pausado_ao_chegar": _dia.get("pausado")}
	_dia.set("pausado", true)
	_dia.call("definir_hora", float(_o["hora"]))
	await _esperar(1.0)
	_gpu("vale pronto")
	print("MEDIR_FPS: vale pronto em %d ms (jogo %d ms)" % [_r["montagem_ms"], _r["jogo_pronto_ms"]])

	var fases := String(_o["fases"]).split(",", false)
	_achar_subviewports()
	if "fotos" in fases:
		if "censo" in fases:
			_r["censo"] = _censo()
		await _fase_fotos()
	_r["config"] = _config()
	if "censo" in fases:
		_r["censo"] = _censo()
		_gravar()
		print("MEDIR_FPS: censo pronto, %d nos" % int(_r["censo"]["nos"]))
	# Com --ab_antes=1 o A/B de GPU roda na cena original, ANTES do pacote persistente.
	if "abgpu" in fases and String(_o.get("ab_antes", "0")) == "1":
		await _fase_ab("gpu", String(_o["ab_gpu_em"]), true)
		_gravar()
		fases.remove_at(fases.find("abgpu"))
	if String(_o.get("aplicar", "")) != "":
		_r["aplicado"] = _aplicar_persistente(String(_o["aplicar"]).split(",", false))
		print("MEDIR_FPS: aplicado (so neste processo): ", _r["aplicado"])
		await _esperar(1.5)
		_r["config_com_pacote"] = _config()
	if "vistas" in fases:
		await _fase_vistas()
		_gravar()
	if "abcpu" in fases:
		await _fase_ab("cpu", String(_o["ab_cpu_em"]), false)
		_gravar()
	if "abgpu" in fases:
		await _fase_ab("gpu", String(_o["ab_gpu_em"]), true)
		_gravar()
	if "horas" in fases:
		await _fase_horas()
		_gravar()
	if "passeio" in fases:
		await _fase_passeio()
		_gravar()
	_r["fim_ok"] = true
	_gravar()
	print("MEDIR_FPS_FIM")
	for tocador in root.find_children("*", "AudioStreamPlayer", true, false):
		tocador.call("stop")
	await create_timer(0.2).timeout
	quit(0)


var _minimapa: Node
var _minimapa_hz := 0.0
var _minimapa_relogio := 0


## EXPERIMENTO "E SE": aplica ajustes candidatos SO NESTE PROCESSO, para medir o vale
## inteiro com eles (nada e gravado no projeto).
func _aplicar_persistente(itens: PackedStringArray) -> Array:
	var feitos: Array = []
	var sois: Array = _mundo.find_children("*", "DirectionalLight3D", true, false)
	var mmis: Array = root.find_children("*", "MultiMeshInstance3D", true, false)
	for item in itens:
		match item:
			"msaa0_fxaa":
				root.msaa_3d = Viewport.MSAA_DISABLED
				root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			"sombra60":
				for s in sois:
					(s as DirectionalLight3D).directional_shadow_max_distance = 60.0
			"sombra90":
				for s in sois:
					(s as DirectionalLight3D).directional_shadow_max_distance = 90.0
			"pssm2":
				for s in sois:
					(s as DirectionalLight3D).directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			"atlas2048":
				RenderingServer.directional_shadow_atlas_set_size(2048, true)
			"mata070", "mata050", "mata035":
				var fator := 0.7 if item == "mata070" else (0.5 if item == "mata050" else 0.35)
				for mmi in mmis:
					var v := mmi as MultiMeshInstance3D
					if v.visibility_range_end > 0.0 and v.visibility_range_begin <= 0.0:
						v.visibility_range_end *= fator
					elif v.visibility_range_begin > 0.0 and v.visibility_range_begin < 400.0:
						v.visibility_range_begin *= fator
				# O renderizador da regiao repoe a distancia ao trocar de camera: guarda a nova.
				var regiao: Variant = _mundo.get("_region")
				if regiao != null:
					for bloco in regiao.get("_blocos_vegetacao_lod"):
						bloco["distancia"] = float(bloco["distancia"]) * fator
			"minimapa_off":
				for sv in _subs:
					(sv as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
				_minimapa = _achar_por_script("minimapa.gd")
				if _minimapa != null:
					_minimapa.set_process(false)
			"minimapa_6hz":
				_minimapa = _achar_por_script("minimapa.gd")
				if _minimapa != null:
					_minimapa.set_process(false)
					_minimapa_hz = 6.0
			"luzes_interior_off":
				var interiores := _jogo.get_node_or_null("Interiores")
				if interiores != null:
					for luz in interiores.find_children("*", "OmniLight3D", true, false) + interiores.find_children("*", "SpotLight3D", true, false):
						(luz as Light3D).visible = false
			"cull_back":
				var vistos := {}
				for mmi in mmis:
					var mm := (mmi as MultiMeshInstance3D).multimesh
					if mm == null or mm.mesh == null:
						continue
					for sup in mm.mesh.get_surface_count():
						var mat: Material = mm.mesh.surface_get_material(sup)
						if mat is BaseMaterial3D and not vistos.has(mat.get_instance_id()):
							vistos[mat.get_instance_id()] = true
							if (mat as BaseMaterial3D).cull_mode == BaseMaterial3D.CULL_DISABLED:
								(mat as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_BACK
				for mi in root.find_children("*", "MeshInstance3D", true, false):
					var inst := mi as MeshInstance3D
					if inst.mesh == null:
						continue
					for sup in inst.mesh.get_surface_count():
						var mat2: Material = inst.get_active_material(sup)
						if mat2 is BaseMaterial3D and not vistos.has(mat2.get_instance_id()):
							vistos[mat2.get_instance_id()] = true
							if (mat2 as BaseMaterial3D).cull_mode == BaseMaterial3D.CULL_DISABLED:
								(mat2 as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_BACK
			"fsr077":
				root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
				root.scaling_3d_scale = 0.77
			"lod4":
				root.mesh_lod_threshold = 4.0
			"passos3":
				Engine.max_physics_steps_per_frame = 3
			"passos4":
				Engine.max_physics_steps_per_frame = 4
			_:
				feitos.append("DESCONHECIDO:" + item)
				continue
		feitos.append(item)
	return feitos


func _achar_por_script(arquivo: String) -> Node:
	var pilha: Array[Node] = [root]
	while not pilha.is_empty():
		var no: Node = pilha.pop_back()
		pilha.append_array(no.get_children())
		if _script_de(no).ends_with(arquivo):
			return no
	return null


## FOTOS: a mesma vista com e sem cada ajuste candidato, para conferir o visual.
## Os scripts ficam congelados durante as fotos de uma vista (a cena nao muda entre elas).
func _fase_fotos() -> void:
	var pasta := String(_o.get("fotos_em", ""))
	if pasta == "":
		return
	DirAccess.make_dir_recursive_absolute(pasta)
	var variantes := [["base", ""], ["cull_back", "faces de tras: cull BACK em tudo"], ["mata_x050", "mata: TODAS as distancias de corte x 0.50"],
		["mata_x035", "mata: TODAS as distancias de corte x 0.35"], ["sem_msaa_fxaa", "render: sem MSAA + FXAA"], ["sombra_60u", "sombra: distancia maxima 60 u"],
		["pacote_A", "PACOTE A"], ["pacote_B", "PACOTE B"], ["pacote_C", "PACOTE C"], ["pacote_D", "PACOTE D"]]
	_r["fotos"] = []
	for pedido in String(_o.get("fotos_vistas", "igreja:90,praca:0,mirante:270")).split(",", false):
		var vista := _vista_escolhida(pedido)
		_por_o_jogador(vista["ponto"], float(vista["rumo"]))
		_dia.set("pausado", true)
		_dia.call("definir_hora", float(_o["hora"]))
		await _esperar(2.5)
		var todas := _alternancias()
		var congelador := {}
		for alt in todas:
			if String(alt["nome"]).begins_with("CPU: TODOS"):
				congelador = alt
		var congelado: Variant = (congelador["aplicar"] as Callable).call() if not congelador.is_empty() else null
		for variante in variantes:
			var escolhida := {}
			if String(variante[1]) != "":
				for alt in todas:
					if String(alt["nome"]).begins_with(String(variante[1])):
						escolhida = alt
				if escolhida.is_empty():
					continue
			var antes: Variant = (escolhida["aplicar"] as Callable).call() if not escolhida.is_empty() else null
			await _esperar(1.6)
			var m := await _medir(0.8, 0.0)
			await RenderingServer.frame_post_draw
			var arquivo := pasta.path_join("%s_%03d_%s.jpg" % [vista["lugar"], roundi(rad_to_deg(float(vista["rumo"]))), variante[0]])
			root.get_texture().get_image().save_jpg(arquivo, 0.9)
			_r["fotos"].append({"arquivo": arquivo, "vista": pedido, "variante": variante[0], "fps": m["fps"], "gpu_ms": m["rs_gpu_ms"], "tri": m["primitivas"], "draws": m["draws"]})
			print("MEDIR_FPS foto %s (%.1f FPS, gpu %.1f ms)" % [arquivo.get_file(), m["fps"], m["rs_gpu_ms"]])
			if not escolhida.is_empty():
				(escolhida["desfazer"] as Callable).call(antes)
		if not congelador.is_empty():
			(congelador["desfazer"] as Callable).call(congelado)
	_gravar()


## Minimapa a N Hz (experimento): o SubViewport desenha uma vez a cada 1/N s.
func _tocar_minimapa(agora_us: int) -> void:
	if _minimapa_hz <= 0.0 or _minimapa == null or not is_instance_valid(_minimapa):
		return
	if agora_us - _minimapa_relogio < int(1000000.0 / _minimapa_hz):
		return
	_minimapa_relogio = agora_us
	_minimapa.call("_seguir")
	var vp := _minimapa.get("_viewport") as SubViewport
	if vp != null:
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## EXPERIMENTO: troca, so na memoria deste processo, o cache de margem unica de
## GeoRegionRenderer._distancia_costa por um cache POR margem. O resultado numerico e o
## mesmo; muda so quantas vezes a grade e refeita. Serve para medir o ganho da correcao.
func _remendar_grade_da_costa() -> String:
	var script := load("res://scripts/prototipo_3d/geo_region_renderer.gd") as GDScript
	if script == null:
		return "nao carregou o script"
	var fonte := script.source_code
	var inicio := fonte.find("func _distancia_costa(point: Vector2, margem: float) -> float:")
	var fim := fonte.find("\tvar lista: Variant = _grade_costa.get(", inicio)
	if inicio < 0 or fim < 0 or not fonte.contains("var _grade_costa_margem := -1.0"):
		return "nao achei a funcao (o codigo mudou)"
	var novo := "func _distancia_costa(point: Vector2, margem: float) -> float:\n" \
		+ "\tif _grade_costa_n != _coast.size():\n" \
		+ "\t\t_grades_costa_por_margem = {}\n" \
		+ "\t\t_grade_costa_n = _coast.size()\n" \
		+ "\tvar _g: Variant = _grades_costa_por_margem.get(margem)\n" \
		+ "\tif _g == null:\n" \
		+ "\t\t_g = {}\n" \
		+ "\t\tfor i in range(_coast.size() - 1):\n" \
		+ "\t\t\tvar caixa := Rect2(_coast[i], Vector2.ZERO).expand(_coast[i + 1]).grow(margem)\n" \
		+ "\t\t\tfor cx in range(floori(caixa.position.x / CELULA_COSTA), floori(caixa.end.x / CELULA_COSTA) + 1):\n" \
		+ "\t\t\t\tfor cy in range(floori(caixa.position.y / CELULA_COSTA), floori(caixa.end.y / CELULA_COSTA) + 1):\n" \
		+ "\t\t\t\t\tvar celula := Vector2i(cx, cy)\n" \
		+ "\t\t\t\t\tif not _g.has(celula):\n" \
		+ "\t\t\t\t\t\t_g[celula] = []\n" \
		+ "\t\t\t\t\t_g[celula].append(i)\n" \
		+ "\t\t_grades_costa_por_margem[margem] = _g\n" \
		+ "\t_grade_costa = _g\n"
	fonte = fonte.substr(0, inicio) + novo + fonte.substr(fim)
	fonte = fonte.replace("var _grade_costa_margem := -1.0", "var _grade_costa_margem := -1.0\nvar _grades_costa_por_margem := {}")
	script.source_code = fonte
	var erro := script.reload()
	return "ok" if erro == OK else "reload falhou: %d" % erro


# ----------------------------------------------------------------------------
# sonda e carimbos
# ----------------------------------------------------------------------------

func _instalar_sonda() -> void:
	var codigo := GDScript.new()
	codigo.source_code = "extends Node\nvar dono\nfunc _process(_d: float) -> void:\n\tdono._fim_process()\nfunc _physics_process(_d: float) -> void:\n\tdono._fim_fisica()\n"
	codigo.reload()
	_sonda = codigo.new()
	_sonda.set("dono", self)
	_sonda.name = "SondaDeTempo"
	_sonda.process_mode = Node.PROCESS_MODE_ALWAYS
	_sonda.process_priority = 2147483647
	_sonda.process_physics_priority = 2147483647
	root.add_child(_sonda)


func _fechar_trecho(agora: int) -> void:
	# O que vem depois do ultimo carimbo pertence a fase anterior.
	if _fase_do_quadro == "fis_fim":
		_a["fis_servidor_us"] = int(_a.get("fis_servidor_us", 0)) + (agora - _t_evento)
	elif _fase_do_quadro == "proc_fim":
		_a["cauda_us"] = int(_a.get("cauda_us", 0)) + (agora - _t_evento)


func _ao_physics_frame() -> void:
	var agora := Time.get_ticks_usec()
	if _gravando:
		_fechar_trecho(agora)
		_a["fis_passos"] = int(_a.get("fis_passos", 0)) + 1
	_t_fis_ini = agora
	_t_evento = agora
	_fase_do_quadro = "fis_ini"


func _fim_fisica() -> void:
	var agora := Time.get_ticks_usec()
	if _gravando:
		_a["fis_scripts_us"] = int(_a.get("fis_scripts_us", 0)) + (agora - _t_fis_ini)
	_t_evento = agora
	_fase_do_quadro = "fis_fim"


func _ao_process_frame() -> void:
	var agora := Time.get_ticks_usec()
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_tocar_minimapa(agora)
	if _gravando:
		_fechar_trecho(agora)
		if _ultimo_quadro_us > 0:
			_quadros_ms.append(float(agora - _ultimo_quadro_us) / 1000.0)
		var tela := root.get_viewport_rid()
		_a["rs_cpu_ms"] = float(_a.get("rs_cpu_ms", 0.0)) + RenderingServer.viewport_get_measured_render_time_cpu(tela)
		_a["rs_gpu_ms"] = float(_a.get("rs_gpu_ms", 0.0)) + RenderingServer.viewport_get_measured_render_time_gpu(tela)
		_a["rs_setup_ms"] = float(_a.get("rs_setup_ms", 0.0)) + RenderingServer.get_frame_setup_time_cpu()
		var sub_cpu := 0.0
		var sub_gpu := 0.0
		for sv in _subs:
			if is_instance_valid(sv):
				var rid: RID = (sv as SubViewport).get_viewport_rid()
				sub_cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
				sub_gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		_a["sub_cpu_ms"] = float(_a.get("sub_cpu_ms", 0.0)) + sub_cpu
		_a["sub_gpu_ms"] = float(_a.get("sub_gpu_ms", 0.0)) + sub_gpu
		_a["prim"] = float(_a.get("prim", 0.0)) + Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		_a["draws"] = float(_a.get("draws", 0.0)) + Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		_a["objs"] = float(_a.get("objs", 0.0)) + Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		_a["n"] = int(_a.get("n", 0)) + 1
	_ultimo_quadro_us = agora
	_t_process_ini = agora
	_t_evento = agora
	_fase_do_quadro = "proc_ini"


func _fim_process() -> void:
	var agora := Time.get_ticks_usec()
	if _gravando:
		_a["proc_scripts_us"] = int(_a.get("proc_scripts_us", 0)) + (agora - _t_process_ini)
	_t_evento = agora
	_fase_do_quadro = "proc_fim"


func _esperar(segundos: float) -> void:
	var fim := Time.get_ticks_usec() + int(segundos * 1000000.0)
	while Time.get_ticks_usec() < fim:
		await process_frame


## Mede por `segundos` (depois de `assentar`), e devolve as medias por quadro.
func _medir(segundos: float, assentar: float, guardar_serie := false) -> Dictionary:
	if assentar > 0.0:
		await _esperar(assentar)
	_a = {}
	_quadros_ms = PackedFloat32Array()
	_ultimo_quadro_us = 0
	await process_frame
	_gravando = true
	var inicio := Time.get_ticks_usec()
	var fim := inicio + int(segundos * 1000000.0)
	while Time.get_ticks_usec() < fim or _quadros_ms.size() < 8:
		await process_frame
	_gravando = false
	var n := maxi(int(_a.get("n", 0)), 1)
	var ordenado := _quadros_ms.duplicate()
	ordenado.sort()
	var soma := 0.0
	for v in ordenado:
		soma += v
	var media := soma / maxf(float(ordenado.size()), 1.0)
	var d := {
		"quadros": ordenado.size(),
		"quadro_ms": snappedf(media, 0.01),
		"fps": snappedf(1000.0 / maxf(media, 0.001), 0.1),
		"mediana_ms": snappedf(ordenado[ordenado.size() / 2], 0.01) if ordenado.size() > 0 else 0.0,
		"p95_ms": snappedf(ordenado[mini(ordenado.size() - 1, int(ordenado.size() * 0.95))], 0.01) if ordenado.size() > 0 else 0.0,
		"max_ms": snappedf(ordenado[ordenado.size() - 1], 0.01) if ordenado.size() > 0 else 0.0,
		"process_scripts_ms": snappedf(float(_a.get("proc_scripts_us", 0)) / 1000.0 / n, 0.001),
		"fisica_scripts_ms": snappedf(float(_a.get("fis_scripts_us", 0)) / 1000.0 / n, 0.001),
		"fisica_servidor_ms": snappedf(float(_a.get("fis_servidor_us", 0)) / 1000.0 / n, 0.001),
		"fisica_passos_por_quadro": snappedf(float(_a.get("fis_passos", 0)) / n, 0.01),
		"cauda_ms": snappedf(float(_a.get("cauda_us", 0)) / 1000.0 / n, 0.001),
		"rs_cpu_ms": snappedf(float(_a.get("rs_cpu_ms", 0.0)) / n, 0.001),
		"rs_gpu_ms": snappedf(float(_a.get("rs_gpu_ms", 0.0)) / n, 0.001),
		"rs_setup_ms": snappedf(float(_a.get("rs_setup_ms", 0.0)) / n, 0.001),
		"sub_cpu_ms": snappedf(float(_a.get("sub_cpu_ms", 0.0)) / n, 0.001),
		"sub_gpu_ms": snappedf(float(_a.get("sub_gpu_ms", 0.0)) / n, 0.001),
		"primitivas": int(float(_a.get("prim", 0.0)) / n),
		"draws": int(float(_a.get("draws", 0.0)) / n),
		"objetos": int(float(_a.get("objs", 0.0)) / n),
		"pausado": paused,
	}
	if guardar_serie:
		var serie: Array = []
		for v in _quadros_ms:
			serie.append(snappedf(v, 0.1))
		d["serie_ms"] = serie
	return d


func _gravar() -> void:
	var saida := String(_o["saida"])
	if saida.is_empty():
		return
	var arquivo := FileAccess.open(saida, FileAccess.WRITE)
	if arquivo == null:
		push_warning("MEDIR_FPS: nao gravei " + saida)
		return
	arquivo.store_string(JSON.stringify(_r, "\t") + "\n")
	arquivo.close()


# ----------------------------------------------------------------------------
# configuracao e censo
# ----------------------------------------------------------------------------

func _achar_subviewports() -> void:
	_subs = root.find_children("*", "SubViewport", true, false)
	for sv in _subs:
		RenderingServer.viewport_set_measure_render_time((sv as SubViewport).get_viewport_rid(), true)


func _ambiente() -> Environment:
	# O ambiente do MUNDO da tela (os estudios de retrato e o boneco tem mundos proprios).
	var do_mundo := root.find_world_3d().environment if root.find_world_3d() != null else null
	if do_mundo != null:
		return do_mundo
	if _mundo != null and _mundo.get("_environment") != null:
		return _mundo.get("_environment") as Environment
	for we in root.find_children("*", "WorldEnvironment", true, false):
		if (we as WorldEnvironment).environment != null:
			return (we as WorldEnvironment).environment
	var cam := root.get_camera_3d()
	if cam != null and cam.environment != null:
		return cam.environment
	return root.world_3d.environment if root.world_3d != null else null


func _config() -> Dictionary:
	var c := {}
	c["janela_px"] = [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]
	c["viewport_px"] = [root.size.x, root.size.y]
	c["modo_janela"] = DisplayServer.window_get_mode()
	c["vsync"] = DisplayServer.window_get_vsync_mode()
	c["max_fps"] = Engine.max_fps
	c["fisica_hz"] = Engine.physics_ticks_per_second
	c["max_passos_fisica_por_quadro"] = Engine.max_physics_steps_per_frame
	c["msaa_3d"] = root.msaa_3d
	c["screen_space_aa"] = root.screen_space_aa
	c["taa"] = root.use_taa
	c["debanding"] = root.use_debanding
	c["scaling_3d_mode"] = root.scaling_3d_mode
	c["scaling_3d_scale"] = root.scaling_3d_scale
	c["mesh_lod_threshold"] = root.mesh_lod_threshold
	c["occlusion_culling"] = root.use_occlusion_culling
	c["positional_shadow_atlas"] = root.positional_shadow_atlas_size
	for chave in ["rendering/lights_and_shadows/directional_shadow/size", "rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality",
			"rendering/lights_and_shadows/directional_shadow/16_bits", "rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality",
			"rendering/lights_and_shadows/positional_shadow/atlas_size", "rendering/driver/threads/thread_model",
			"rendering/textures/default_filters/anisotropic_filtering_level", "rendering/anti_aliasing/quality/msaa_3d",
			"rendering/scaling_3d/mode", "rendering/scaling_3d/scale", "rendering/mesh_lod/lod_change/threshold_pixels",
			"rendering/occlusion_culling/use_occlusion_culling", "rendering/environment/ssao/quality", "rendering/environment/glow/upscale_mode",
			"rendering/reflections/sky_reflections/roughness_layers", "rendering/reflections/sky_reflections/ggx_samples",
			"rendering/global_illumination/gi/use_half_resolution", "rendering/limits/cluster_builder/max_clustered_elements",
			"rendering/shading/overrides/force_vertex_shading", "rendering/rendering_device/pipeline_cache/enable",
			"physics/3d/physics_engine", "physics/common/physics_ticks_per_second", "physics/common/max_physics_steps_per_frame",
			"display/window/vsync/vsync_mode", "application/run/max_fps", "rendering/textures/vram_compression/import_s3tc_bptc"]:
		c[chave] = str(ProjectSettings.get_setting(chave)) if ProjectSettings.has_setting(chave) else "(ausente)"
	var amb := _ambiente()
	if amb != null:
		var a := {}
		for p in ["background_mode", "ambient_light_source", "ambient_light_energy", "reflected_light_source", "tonemap_mode",
				"ssao_enabled", "ssil_enabled", "sdfgi_enabled", "ssr_enabled", "glow_enabled", "fog_enabled", "fog_mode",
				"volumetric_fog_enabled", "adjustment_enabled", "fog_density", "fog_aerial_perspective", "fog_sky_affect"]:
			a[p] = str(amb.get(p))
		if amb.sky != null:
			a["sky_process_mode"] = amb.sky.process_mode
			a["sky_radiance_size"] = amb.sky.radiance_size
			var mat := amb.sky.sky_material
			a["sky_material"] = mat.get_class() if mat != null else "null"
			if mat is ShaderMaterial and (mat as ShaderMaterial).shader != null:
				a["sky_shader"] = (mat as ShaderMaterial).shader.resource_path
		c["ambiente"] = a
	var cam := root.get_camera_3d()
	if cam != null:
		c["camera"] = {"fov": cam.fov, "near": cam.near, "far": cam.far, "projecao": cam.projection}
	var subs: Array = []
	for sv in _subs:
		var v := sv as SubViewport
		var cams := v.find_children("*", "Camera3D", true, false)
		subs.append({"caminho": String(v.get_path()), "px": [v.size.x, v.size.y], "update_mode": v.render_target_update_mode,
			"own_world_3d": v.own_world_3d, "mesmo_mundo_da_tela": v.find_world_3d() == root.find_world_3d(),
			"cameras_3d": cams.size(), "msaa_3d": v.msaa_3d, "disable_3d": v.disable_3d, "transparente": v.transparent_bg,
			"visivel_pai": str((v.get_parent() as CanvasItem).is_visible_in_tree()) if v.get_parent() is CanvasItem else "?"})
	c["subviewports"] = subs
	return c


func _tri(malha: Mesh, cache: Dictionary) -> int:
	if malha == null:
		return 0
	var id := malha.get_instance_id()
	if cache.has(id):
		return int(cache[id])
	var total := 0
	if malha is ArrayMesh:
		var am := malha as ArrayMesh
		for s in am.get_surface_count():
			var indices := am.surface_get_array_index_len(s)
			total += floori((indices if indices > 0 else am.surface_get_array_len(s)) / 3.0)
	elif malha is PrimitiveMesh:
		var arr := (malha as PrimitiveMesh).get_mesh_arrays()
		if arr.size() > Mesh.ARRAY_INDEX and arr[Mesh.ARRAY_INDEX] != null:
			total = floori((arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3.0)
	else:
		total = floori(malha.get_faces().size() / 3.0)
	cache[id] = total
	return total


func _script_de(no: Node) -> String:
	var s: Script = no.get_script()
	if s == null:
		return ""
	return s.resource_path if not s.resource_path.is_empty() else "(script embutido)"


func _chave_glb(nome: String) -> String:
	var limpo := nome.trim_prefix("@")
	var fim := limpo.find("Tripo")
	return limpo.substr(0, fim).strip_edges() if fim > 0 else limpo


func _grupo_bloco(nome: String) -> String:
	var espaco := nome.rfind(" ")
	if espaco > 0 and nome.substr(espaco + 1).contains(","):
		return nome.substr(0, espaco)
	# nomes gerados "@MultiMeshInstance3D@123"
	if nome.begins_with("@"):
		return "(sem nome)"
	return nome


func _censo() -> Dictionary:
	var cache := {}
	var c := {"nos": 0, "por_classe": {}, "process_por_script": {}, "physics_por_script": {}, "interno_por_classe": {}}
	var malhas := {}      # id -> {tri, instancias, exemplo, sombra}
	var mm := {}          # grupo -> {blocos, instancias, tri_lod0, sombra, vis_end, lod_bias}
	var glb := {}         # chave -> {instancias, tri}
	var luzes: Array = []
	var esqueletos := 0
	var ossos := 0
	var anim_tocando := 0
	var anim_total := 0
	var sombra_mi := 0
	var mi_visiveis := 0
	var mi_com_vis_range := 0
	var mi_com_skin := 0
	var tri_mi := 0
	var tri_mi_skin := 0
	var formas := {}
	var faces_trimesh := 0
	var corpos := {}
	var areas_monitorando := 0
	var label3d := 0
	var audio_tocando := 0
	var controles := 0
	var controles_visiveis := 0
	var canvas_layers: Array = []
	var pilha: Array[Node] = [root]
	while not pilha.is_empty():
		var no: Node = pilha.pop_back()
		pilha.append_array(no.get_children())
		c["nos"] += 1
		var classe := no.get_class()
		c["por_classe"][classe] = int(c["por_classe"].get(classe, 0)) + 1
		var script := _script_de(no)
		if no != _sonda:
			if no.is_processing():
				var k := script if script != "" else "[" + classe + "]"
				c["process_por_script"][k] = int(c["process_por_script"].get(k, 0)) + 1
			if no.is_physics_processing():
				var k2 := script if script != "" else "[" + classe + "]"
				c["physics_por_script"][k2] = int(c["physics_por_script"].get(k2, 0)) + 1
			if no.is_processing_internal() or no.is_physics_processing_internal():
				c["interno_por_classe"][classe] = int(c["interno_por_classe"].get(classe, 0)) + 1
		if no is MeshInstance3D:
			var mi := no as MeshInstance3D
			var t := _tri(mi.mesh, cache)
			tri_mi += t
			if mi.is_visible_in_tree():
				mi_visiveis += 1
			if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				sombra_mi += 1
			if mi.visibility_range_end > 0.0:
				mi_com_vis_range += 1
			if mi.skin != null or not mi.skeleton.is_empty() and mi.get_node_or_null(mi.skeleton) is Skeleton3D:
				mi_com_skin += 1
				tri_mi_skin += t
			if mi.mesh != null:
				var id := mi.mesh.get_instance_id()
				if not malhas.has(id):
					malhas[id] = {"tri": t, "instancias": 0, "exemplo": String(mi.get_path()), "recurso": mi.mesh.resource_path}
				malhas[id]["instancias"] = int(malhas[id]["instancias"]) + 1
		elif no is MultiMeshInstance3D:
			var mmi := no as MultiMeshInstance3D
			if mmi.multimesh != null:
				var n := mmi.multimesh.instance_count if mmi.multimesh.visible_instance_count < 0 else mmi.multimesh.visible_instance_count
				var g := _grupo_bloco(String(no.name))
				if not mm.has(g):
					var niveis_mm := -1
					var malha_mm := mmi.multimesh.mesh
					if malha_mm is ArrayMesh and (malha_mm as ArrayMesh).get_surface_count() > 0:
						niveis_mm = (RenderingServer.mesh_get_surface(malha_mm.get_rid(), 0).get("lods", []) as Array).size()
					var mat_mm: Material = mmi.material_override
					if mat_mm == null and malha_mm != null and malha_mm.get_surface_count() > 0:
						mat_mm = malha_mm.surface_get_material(0)
					var transparencia := -1
					var cull := -1
					if mat_mm is BaseMaterial3D:
						transparencia = (mat_mm as BaseMaterial3D).transparency
						cull = (mat_mm as BaseMaterial3D).cull_mode
					mm[g] = {"blocos": 0, "instancias": 0, "tri_lod0": 0, "tri_por_instancia": 0, "sombra": 0, "vis_begin": mmi.visibility_range_begin,
						"vis_end": mmi.visibility_range_end, "lod_bias": mmi.lod_bias, "visiveis": 0, "niveis_lod": niveis_mm,
						"superficies": malha_mm.get_surface_count() if malha_mm != null else 0,
						"material": mat_mm.get_class() if mat_mm != null else "null", "transparencia": transparencia, "cull": cull}
				var t2 := _tri(mmi.multimesh.mesh, cache)
				mm[g]["blocos"] = int(mm[g]["blocos"]) + 1
				mm[g]["instancias"] = int(mm[g]["instancias"]) + n
				mm[g]["tri_lod0"] = int(mm[g]["tri_lod0"]) + n * t2
				mm[g]["tri_por_instancia"] = maxi(int(mm[g]["tri_por_instancia"]), t2)
				if mmi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					mm[g]["sombra"] = int(mm[g]["sombra"]) + 1
				if mmi.is_visible_in_tree():
					mm[g]["visiveis"] = int(mm[g]["visiveis"]) + 1
		elif no is Skeleton3D:
			esqueletos += 1
			ossos += (no as Skeleton3D).get_bone_count()
		elif no is AnimationPlayer:
			anim_total += 1
			if (no as AnimationPlayer).is_playing():
				anim_tocando += 1
		elif no is Light3D:
			var l := no as Light3D
			var info := {"classe": classe, "caminho": String(l.get_path()), "visivel": l.is_visible_in_tree(), "sombra": l.shadow_enabled, "energia": l.light_energy}
			if l is DirectionalLight3D:
				var dl := l as DirectionalLight3D
				info["modo_sombra"] = dl.directional_shadow_mode
				info["dist_max"] = dl.directional_shadow_max_distance
				info["blend_splits"] = dl.directional_shadow_blend_splits
			elif l is OmniLight3D:
				info["alcance"] = (l as OmniLight3D).omni_range
				info["fade"] = l.distance_fade_enabled
			elif l is SpotLight3D:
				info["alcance"] = (l as SpotLight3D).spot_range
				info["fade"] = l.distance_fade_enabled
			luzes.append(info)
		elif no is CollisionShape3D:
			var cs := no as CollisionShape3D
			if cs.shape != null:
				var f := cs.shape.get_class()
				formas[f] = int(formas.get(f, 0)) + 1
				if cs.shape is ConcavePolygonShape3D:
					faces_trimesh += floori((cs.shape as ConcavePolygonShape3D).get_faces().size() / 3.0)
		elif no is PhysicsBody3D:
			corpos[classe] = int(corpos.get(classe, 0)) + 1
		elif no is Area3D:
			if (no as Area3D).monitoring:
				areas_monitorando += 1
		elif no is Label3D:
			label3d += 1
		elif no is AudioStreamPlayer or no is AudioStreamPlayer3D:
			if bool(no.get("playing")):
				audio_tocando += 1
		elif no is Control:
			controles += 1
			if (no as Control).is_visible_in_tree():
				controles_visiveis += 1
		elif no is CanvasLayer:
			canvas_layers.append({"caminho": String(no.get_path()), "layer": (no as CanvasLayer).layer, "visivel": (no as CanvasLayer).visible, "script": script})
		if no is Node3D and no.has_meta("limites") and String(no.name).contains("Tripo"):
			var chave := _chave_glb(String(no.name))
			if not glb.has(chave):
				var soma := 0
				for filho in no.find_children("*", "MeshInstance3D", true, false):
					soma += _tri((filho as MeshInstance3D).mesh, cache)
				glb[chave] = {"instancias": 0, "tri": soma}
			glb[chave]["instancias"] = int(glb[chave]["instancias"]) + 1
	# maiores malhas (tri x instancias)
	var lista: Array = []
	for id in malhas:
		var m: Dictionary = malhas[id]
		m["tri_total"] = int(m["tri"]) * int(m["instancias"])
		lista.append(m)
	lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["tri_total"]) > int(b["tri_total"]))
	c["maiores_malhas"] = lista.slice(0, 40)
	c["malhas_distintas"] = malhas.size()
	c["multimesh_por_grupo"] = mm
	var glbs: Array = []
	for chave in glb:
		glbs.append({"chave": chave, "instancias": glb[chave]["instancias"], "tri": glb[chave]["tri"], "tri_total": int(glb[chave]["instancias"]) * int(glb[chave]["tri"])})
	glbs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["tri_total"]) > int(b["tri_total"]))
	c["glb_instanciados"] = glbs
	c["luzes"] = luzes
	c["esqueletos"] = esqueletos
	c["ossos"] = ossos
	c["animation_players"] = anim_total
	c["animation_players_tocando"] = anim_tocando
	c["mesh_instances_visiveis"] = mi_visiveis
	c["mesh_instances_com_sombra"] = sombra_mi
	c["mesh_instances_com_visibility_range"] = mi_com_vis_range
	c["mesh_instances_com_skin"] = mi_com_skin
	c["tri_em_mesh_instances"] = tri_mi
	c["tri_em_mesh_instances_com_skin"] = tri_mi_skin
	c["formas_de_colisao"] = formas
	c["faces_trimesh"] = faces_trimesh
	c["corpos"] = corpos
	c["areas_monitorando"] = areas_monitorando
	c["label3d"] = label3d
	c["audio_tocando"] = audio_tocando
	c["controles"] = controles
	c["controles_visiveis"] = controles_visiveis
	c["canvas_layers"] = canvas_layers
	c["monitores"] = _monitores()
	# LODs nas maiores malhas (o RenderingServer devolve a superficie com a lista de LODs).
	var lods: Array = []
	for m in lista.slice(0, 30):
		var exemplo := root.get_node_or_null(NodePath(String(m["exemplo"]))) as MeshInstance3D
		if exemplo == null or exemplo.mesh == null or not (exemplo.mesh is ArrayMesh):
			continue
		var niveis := 0
		var am := exemplo.mesh as ArrayMesh
		if am.get_surface_count() > 0:
			var sup := RenderingServer.mesh_get_surface(am.get_rid(), 0)
			niveis = (sup.get("lods", []) as Array).size()
		lods.append({"exemplo": m["exemplo"], "tri": m["tri"], "niveis_lod": niveis})
	c["lods_das_maiores"] = lods
	return c


func _monitores() -> Dictionary:
	var mega := 1048576.0
	return {
		"nos": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"objetos": Performance.get_monitor(Performance.OBJECT_COUNT),
		"recursos": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"nos_orfaos": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"memoria_estatica_mb": snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / mega, 0.1),
		"video_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / mega, 0.1),
		"texturas_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / mega, 0.1),
		"buffers_mb": snappedf(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / mega, 0.1),
		"fisica_corpos_ativos": Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		"fisica_pares": Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),
		"fisica_ilhas": Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT),
		"tempo_fisica_max_ms": snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.01),
		"tempo_process_max_ms": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01),
		"tempo_navegacao_ms": snappedf(Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0, 0.01),
	}


# ----------------------------------------------------------------------------
# vistas
# ----------------------------------------------------------------------------

func _por_o_jogador(ponto: Vector3, rumo: float) -> void:
	_jogador.global_position = _mundo.call("ground_position", ponto, 0.07)
	_jogador.set("velocity", Vector3.ZERO)
	_jogador.set("_yaw", rumo)
	_jogador.set("_pitch", -0.19)
	_jogador.call("_apply_camera")
	_jogador.call("_encaixar_a_camera")


func _lugares() -> Array:
	var lugares := root.get_node("/root/Lugares")
	var pedidos: Array = Array(String(_o["lugares"]).split(",", false)) if String(_o["lugares"]) != "" else LUGARES_PADRAO
	var saida: Array = []
	for nome in pedidos:
		var p: Vector3 = lugares.call("ponto", String(nome))
		if p.is_finite():
			saida.append({"nome": String(nome), "ponto": p})
		else:
			_r["avisos"].append("lugar nao resolve: " + String(nome))
	return saida


func _fase_vistas() -> void:
	var rumos := int(_o["rumos"])
	_gpu("inicio das vistas")
	for lugar in _lugares():
		# Como o jogador ve: relogio andando; cada lugar comeca na mesma hora.
		_dia.set("pausado", false)
		_dia.call("definir_hora", float(_o["hora"]))
		for i in rumos:
			var rumo := TAU * float(i) / float(rumos)
			_por_o_jogador(lugar["ponto"], rumo)
			# o primeiro segundo depois do teleporte: o pico de entrada (pop-in, pipelines)
			var m := await _medir(float(_o["vista_s"]), 0.45)
			m["lugar"] = lugar["nome"]
			m["rumo_graus"] = roundi(rad_to_deg(rumo))
			m["posicao"] = [snappedf(_jogador.global_position.x, 0.1), snappedf(_jogador.global_position.y, 0.1), snappedf(_jogador.global_position.z, 0.1)]
			_r["vistas"].append(m)
		var ultimas: Array = _r["vistas"].slice(-rumos)
		var pior: Dictionary = ultimas[0]
		for v in ultimas:
			if float(v["fps"]) < float(pior["fps"]):
				pior = v
		print("MEDIR_FPS vista %-18s pior %5.1f FPS (rumo %3d) gpu %.1f ms cpu-rs %.1f ms proc %.2f ms fis %.2f ms x%.1f draws %d tri %d" % [
			lugar["nome"], pior["fps"], pior["rumo_graus"], pior["rs_gpu_ms"], pior["rs_cpu_ms"], pior["process_scripts_ms"],
			pior["fisica_scripts_ms"], pior["fisica_passos_por_quadro"], pior["draws"], pior["primitivas"]])
	_r["monitores_depois_das_vistas"] = _monitores()
	_gpu("fim das vistas")
	_dia.set("pausado", true)


func _vista_escolhida(pedido: String = "") -> Dictionary:
	if pedido == "":
		pedido = String(_o["ab_em"])
	var lugares := root.get_node("/root/Lugares")
	if pedido != "pior" and pedido.contains(":"):
		var partes := pedido.split(":")
		var p: Vector3 = lugares.call("ponto", partes[0])
		if p.is_finite():
			return {"lugar": partes[0], "ponto": p, "rumo": deg_to_rad(float(partes[1]))}
	var pior := {}
	for v in _r["vistas"]:
		if pior.is_empty() or float(v["fps"]) < float(pior["fps"]):
			pior = v
	if pior.is_empty():
		var p2: Vector3 = lugares.call("ponto", "praca")
		return {"lugar": "praca", "ponto": p2, "rumo": 0.0}
	var p3: Vector3 = lugares.call("ponto", String(pior["lugar"]))
	return {"lugar": pior["lugar"], "ponto": p3, "rumo": deg_to_rad(float(pior["rumo_graus"]))}


# ----------------------------------------------------------------------------
# A/B
# ----------------------------------------------------------------------------

func _t_esconder(nome: String, nos: Array) -> Dictionary:
	return _t_prop(nome, nos, "visible", false)


func _t_prop(nome: String, objetos: Array, propriedade: String, valor: Variant) -> Dictionary:
	var aplicar := func() -> Variant:
		var antes: Array = []
		for obj in objetos:
			if is_instance_valid(obj):
				antes.append([obj, obj.get(propriedade)])
				obj.set(propriedade, valor)
		return antes
	var desfazer := func(antes: Variant) -> void:
		for par in antes:
			if is_instance_valid(par[0]):
				par[0].set(propriedade, par[1])
	return {"nome": nome, "n": objetos.size(), "aplicar": aplicar, "desfazer": desfazer}


## Multiplica uma propriedade numerica por `fator` (guardando o valor de cada objeto).
func _t_escala(nome: String, objetos: Array, propriedade: String, fator: float) -> Dictionary:
	var aplicar := func() -> Variant:
		var antes: Array = []
		for obj in objetos:
			if is_instance_valid(obj):
				antes.append([obj, obj.get(propriedade)])
				obj.set(propriedade, float(obj.get(propriedade)) * fator)
		return antes
	var desfazer := func(antes: Variant) -> void:
		for par in antes:
			if is_instance_valid(par[0]):
				par[0].set(propriedade, par[1])
	return {"nome": nome, "n": objetos.size(), "aplicar": aplicar, "desfazer": desfazer}


## Desliga so o _process/_physics_process do script (a animacao e a fisica do no seguem).
func _t_scripts(nome: String, nos: Array) -> Dictionary:
	var aplicar := func() -> Variant:
		var antes: Array = []
		for no in nos:
			if is_instance_valid(no):
				antes.append([no, no.is_processing(), no.is_physics_processing()])
				no.set_process(false)
				no.set_physics_process(false)
		return antes
	var desfazer := func(antes: Variant) -> void:
		for trio in antes:
			if is_instance_valid(trio[0]):
				trio[0].set_process(trio[1])
				trio[0].set_physics_process(trio[2])
	return {"nome": nome, "n": nos.size(), "aplicar": aplicar, "desfazer": desfazer}


func _t_chamar(nome: String, fazer: Callable, voltar: Callable) -> Dictionary:
	var aplicar := func() -> Variant:
		fazer.call()
		return null
	var desfazer := func(_antes: Variant) -> void:
		voltar.call()
	return {"nome": nome, "n": 1, "aplicar": aplicar, "desfazer": desfazer}


func _combinar(nome: String, partes: Array) -> Dictionary:
	var aplicar := func() -> Variant:
		var antes: Array = []
		for p in partes:
			antes.append((p["aplicar"] as Callable).call())
		return antes
	var desfazer := func(antes: Variant) -> void:
		for i in range(partes.size() - 1, -1, -1):
			(partes[i]["desfazer"] as Callable).call(antes[i])
	return {"nome": nome, "n": partes.size(), "aplicar": aplicar, "desfazer": desfazer}


## Foto da GPU pelo nvidia-smi (VRAM usada no sistema todo, uso, temperatura, potencia, clock).
func _gpu(rotulo: String) -> void:
	var saida: Array = []
	var codigo := OS.execute("nvidia-smi", ["--query-gpu=memory.used,memory.total,utilization.gpu,temperature.gpu,power.draw,clocks.gr", "--format=csv,noheader,nounits"], saida, true)
	if not _r.has("gpu"):
		_r["gpu"] = []
	_r["gpu"].append({"quando": rotulo, "ms": Time.get_ticks_msec(), "codigo": codigo, "linha": String(saida[0]).strip_edges() if saida.size() > 0 else "",
		"godot_video_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"godot_texturas_mb": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1),
		"godot_buffers_mb": snappedf(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0, 0.1)})


func _alternancias() -> Array:
	var t: Array = []
	var amb := _ambiente()
	var cam := root.get_camera_3d()
	var sois: Array = root.find_children("*", "DirectionalLight3D", true, false)
	var locais: Array = root.find_children("*", "OmniLight3D", true, false) + root.find_children("*", "SpotLight3D", true, false)
	var mmis: Array = root.find_children("*", "MultiMeshInstance3D", true, false)
	var mis: Array = root.find_children("*", "MeshInstance3D", true, false)
	var anims: Array = root.find_children("*", "AnimationPlayer", true, false)
	var camadas: Array = root.find_children("*", "CanvasLayer", true, false)

	# ---- configuracao de render ----
	t.append(_t_prop("render: MSAA 3D desligado (hoje 2x)", [root], "msaa_3d", Viewport.MSAA_DISABLED))
	t.append(_t_prop("render: escala 3D 0,77 bilinear", [root], "scaling_3d_scale", 0.77))
	t.append(_t_prop("render: escala 3D 0,67 bilinear", [root], "scaling_3d_scale", 0.67))
	t.append(_t_prop("render: escala 3D 0,50 bilinear", [root], "scaling_3d_scale", 0.5))
	t.append(_combinar("render: FSR1 0,77", [_t_prop("", [root], "scaling_3d_mode", Viewport.SCALING_3D_MODE_FSR), _t_prop("", [root], "scaling_3d_scale", 0.77)]))
	t.append(_combinar("render: FSR1 0,67", [_t_prop("", [root], "scaling_3d_mode", Viewport.SCALING_3D_MODE_FSR), _t_prop("", [root], "scaling_3d_scale", 0.67)]))
	t.append(_combinar("render: sem MSAA + FXAA", [_t_prop("", [root], "msaa_3d", Viewport.MSAA_DISABLED), _t_prop("", [root], "screen_space_aa", Viewport.SCREEN_SPACE_AA_FXAA)]))
	t.append(_t_prop("render: mesh_lod_threshold 4 px (hoje 1)", [root], "mesh_lod_threshold", 4.0))
	t.append(_t_prop("render: mesh_lod_threshold 8 px", [root], "mesh_lod_threshold", 8.0))
	t.append(_t_prop("render: mesh_lod_threshold 16 px", [root], "mesh_lod_threshold", 16.0))
	if cam != null:
		t.append(_t_prop("camera: far 600 (hoje %d)" % int(cam.far), [cam], "far", 600.0))
	# ---- vegetacao: distancias de corte e LOD ----
	var veg_perto: Array = []
	var veg_longe: Array = []
	var sub_bosque: Array = []
	for mmi_v in mmis:
		var v := mmi_v as MultiMeshInstance3D
		if v.visibility_range_end > 0.0 and v.visibility_range_begin <= 0.0:
			veg_perto.append(v)
			if String(v.name).begins_with("Sub-bosque"):
				sub_bosque.append(v)
		elif v.visibility_range_begin > 0.0 and v.visibility_range_begin < 400.0:
			veg_longe.append(v)
	for fator in [0.7, 0.5, 0.35]:
		t.append(_combinar("mata: TODAS as distancias de corte x %.2f (280->%d u, sub-bosque 85->%d u)" % [fator, int(280.0 * fator), int(85.0 * fator)],
			[_t_escala("", veg_perto, "visibility_range_end", fator), _t_escala("", veg_longe, "visibility_range_begin", fator)]))
	t.append(_t_escala("mata: so o sub-bosque a 50 u (hoje 85)", sub_bosque, "visibility_range_end", 50.0 / 85.0))
	t.append(_t_escala("mata: so o sub-bosque a 30 u", sub_bosque, "visibility_range_end", 30.0 / 85.0))
	t.append(_t_prop("mata: lod_bias 0,25 nos blocos (hoje 0,65)", veg_perto, "lod_bias", 0.25))
	# ---- sombras ----
	t.append(_t_prop("sombra: sol/lua sem sombra", sois, "shadow_enabled", false))
	t.append(_t_prop("sombra: distancia maxima 60 u", sois, "directional_shadow_max_distance", 60.0))
	t.append(_t_prop("sombra: distancia maxima 30 u", sois, "directional_shadow_max_distance", 30.0))
	t.append(_t_prop("sombra: 2 cascatas (PSSM2)", sois, "directional_shadow_mode", DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS))
	var atlas := int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size", 4096))
	var filtro := int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 2))
	t.append(_t_chamar("sombra: atlas direcional 2048 (hoje %d)" % atlas,
		func() -> void: RenderingServer.directional_shadow_atlas_set_size(2048, true),
		func() -> void: RenderingServer.directional_shadow_atlas_set_size(atlas, true)))
	t.append(_t_chamar("sombra: filtro duro (hoje qualidade %d)" % filtro,
		func() -> void: RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD),
		func() -> void: RenderingServer.directional_soft_shadow_filter_set_quality(filtro)))
	t.append(_t_prop("sombra: vegetacao (MultiMesh) sem projetar", mmis, "cast_shadow", GeometryInstance3D.SHADOW_CASTING_SETTING_OFF))
	# sombras por familia de malha individual
	var mis_interiores: Array = []
	var mis_vivos: Array = []
	var mis_pequenas: Array = []
	var cache_tri := {}
	for mi_s in mis:
		var inst_s := mi_s as MeshInstance3D
		var caminho_s := String(inst_s.get_path())
		if caminho_s.contains("/Interiores/"):
			mis_interiores.append(inst_s)
			continue
		var vivo := false
		var pai: Node = inst_s.get_parent()
		for nivel in 8:
			if pai == null:
				break
			var script_s := _script_de(pai)
			if script_s.ends_with("npc.gd") or script_s.ends_with("guia_pedro.gd") or script_s.ends_with("bicho_de_casa.gd") or script_s.ends_with("bando_de_chao.gd") or script_s.ends_with("criatura_vale.gd") or script_s.ends_with("player_controller.gd"):
				vivo = true
				break
			pai = pai.get_parent()
		if vivo:
			mis_vivos.append(inst_s)
		elif _tri(inst_s.mesh, cache_tri) <= 6000 and inst_s.get_aabb().get_longest_axis_size() * inst_s.global_transform.basis.get_scale().x < 2.5:
			mis_pequenas.append(inst_s)
	t.append(_t_prop("sombra: malhas dos INTERIORES sem projetar (%d)" % mis_interiores.size(), mis_interiores, "cast_shadow", GeometryInstance3D.SHADOW_CASTING_SETTING_OFF))
	t.append(_t_prop("sombra: moradores, bichos e aves sem projetar (%d)" % mis_vivos.size(), mis_vivos, "cast_shadow", GeometryInstance3D.SHADOW_CASTING_SETTING_OFF))
	t.append(_t_prop("sombra: pecas pequenas (< 2,5 u) sem projetar (%d)" % mis_pequenas.size(), mis_pequenas, "cast_shadow", GeometryInstance3D.SHADOW_CASTING_SETTING_OFF))
	t.append(_t_prop("sombra: malhas individuais sem projetar", mis, "cast_shadow", GeometryInstance3D.SHADOW_CASTING_SETTING_OFF))
	# ---- a casa herdada por dentro (#185): rodar com --ab_gpu_em=casa_de_taipa:135 --so=casa: ----
	var sala_casa: Node = null
	var interiores_no := _jogo.get_node_or_null("Interiores") if _jogo != null else null
	if interiores_no != null and interiores_no.has_method("sala_de"):
		sala_casa = interiores_no.call("sala_de", "casa")
	if sala_casa != null:
		var da_casca: Array = []
		for no in Array(sala_casa.get("_teto")) + Array(sala_casa.get("casca")):
			if is_instance_valid(no):
				if no is GeometryInstance3D:
					da_casca.append(no)
				da_casca.append_array((no as Node).find_children("*", "GeometryInstance3D", true, false))
		var luzes_casa: Array = sala_casa.find_children("*", "Light3D", true, false)
		var sondas_casa: Array = sala_casa.find_children("*", "ReflectionProbe", true, false)
		t.append(_t_prop("casa: casca e teto ESCONDIDOS (visible=false, em vez de so sombra)", da_casca, "visible", false))
		t.append(_t_prop("casa: casca e teto sem projetar sombra (%d malhas)" % da_casca.size(), da_casca, "cast_shadow", GeometryInstance3D.SHADOW_CASTING_SETTING_OFF))
		t.append(_t_prop("casa: luzes do comodo escondidas (%d)" % luzes_casa.size(), luzes_casa, "visible", false))
		t.append(_t_prop("casa: sonda de reflexo escondida", sondas_casa, "visible", false))
		t.append(_t_prop("casa: sombra do sol de volta a 70 u (antes do #185)", sois, "directional_shadow_max_distance", 70.0))
		t.append(_t_prop("casa: sombra do sol a 12 u", sois, "directional_shadow_max_distance", 12.0))
		t.append(_t_prop("casa: far da camera a 60 u", [cam], "far", 60.0))
		t.append(_t_prop("casa: sol sem sombra", sois, "shadow_enabled", false))
	# ---- faces de tras: todo GLB do Tripo vem doubleSided (cull desligado) ----
	var mats_veg := {}
	for mmi_c in mmis:
		var mm_c := (mmi_c as MultiMeshInstance3D).multimesh
		if mm_c == null or mm_c.mesh == null:
			continue
		for s_c in mm_c.mesh.get_surface_count():
			var mat_c: Material = mm_c.mesh.surface_get_material(s_c)
			if mat_c is BaseMaterial3D and (mat_c as BaseMaterial3D).cull_mode == BaseMaterial3D.CULL_DISABLED:
				mats_veg[mat_c.get_instance_id()] = mat_c
	var mats_ind := {}
	for mi_c in mis:
		var inst_c := mi_c as MeshInstance3D
		if inst_c.mesh == null:
			continue
		for s_c2 in inst_c.mesh.get_surface_count():
			var mat_c2: Material = inst_c.get_active_material(s_c2)
			if mat_c2 is BaseMaterial3D and (mat_c2 as BaseMaterial3D).cull_mode == BaseMaterial3D.CULL_DISABLED and not mats_veg.has(mat_c2.get_instance_id()):
				mats_ind[mat_c2.get_instance_id()] = mat_c2
	t.append(_t_prop("faces de tras: cull BACK nos %d materiais da vegetacao em MultiMesh" % mats_veg.size(), mats_veg.values(), "cull_mode", BaseMaterial3D.CULL_BACK))
	t.append(_t_prop("faces de tras: cull BACK nos %d materiais das malhas individuais" % mats_ind.size(), mats_ind.values(), "cull_mode", BaseMaterial3D.CULL_BACK))
	t.append(_combinar("faces de tras: cull BACK em tudo (vegetacao + individuais)", [_t_prop("", mats_veg.values(), "cull_mode", BaseMaterial3D.CULL_BACK), _t_prop("", mats_ind.values(), "cull_mode", BaseMaterial3D.CULL_BACK)]))
	t.append(_t_prop("luzes locais (omni/spot) escondidas", locais, "visible", false))
	t.append(_t_prop("luzes locais sem sombra", locais, "shadow_enabled", false))
	# ---- ambiente ----
	if amb != null:
		for efeito in ["ssao_enabled", "ssil_enabled", "sdfgi_enabled", "ssr_enabled", "glow_enabled", "fog_enabled", "volumetric_fog_enabled", "adjustment_enabled"]:
			if bool(amb.get(efeito)):
				t.append(_t_prop("ambiente: %s desligado" % efeito, [amb], efeito, false))
		t.append(_t_prop("ambiente: fundo cor solida (sem shader de ceu, sem radiancia)", [amb], "background_mode", Environment.BG_COLOR))
		t.append(_t_prop("ambiente: nevoa sem perspectiva aerea (nao le a radiancia)", [amb], "fog_aerial_perspective", 0.0))
		t.append(_t_prop("ambiente: reflexo desligado (reflected_light_source)", [amb], "reflected_light_source", Environment.REFLECTION_SOURCE_DISABLED))
		if amb.sky != null:
			t.append(_t_prop("ceu: process_mode INCREMENTAL (hoje %d = tempo real)" % amb.sky.process_mode, [amb.sky], "process_mode", Sky.PROCESS_MODE_INCREMENTAL))
			t.append(_t_prop("ceu: process_mode QUALITY (so refaz quando muda)", [amb.sky], "process_mode", Sky.PROCESS_MODE_QUALITY))
			t.append(_combinar("ceu: INCREMENTAL + radiancia 128", [_t_prop("", [amb.sky], "process_mode", Sky.PROCESS_MODE_INCREMENTAL), _t_prop("", [amb.sky], "radiance_size", Sky.RADIANCE_SIZE_128)]))
	# ---- relogio ----
	t.append(_t_prop("relogio do dia PARADO (a base e com ele andando, como no jogo)", [_dia], "pausado", true))
	# ---- cena por categoria ----
	t.append(_t_esconder("cena: toda a vegetacao em MultiMesh escondida", mmis))
	var individuais: Array = []
	var com_skin: Array = []
	for mi in mis:
		var m := mi as MeshInstance3D
		if m.skin != null:
			com_skin.append(m)
		individuais.append(m)
	t.append(_t_esconder("cena: todas as malhas individuais escondidas (sobra a vegetacao)", individuais))
	t.append(_t_esconder("cena: malhas com esqueleto (skin) escondidas", com_skin))
	t.append(_t_prop("animacao: AnimationPlayers parados", anims, "active", false))
	# pecas GLB do catalogo, por chave (as maiores em tri x instancias)
	var por_chave := {}
	var pilha: Array[Node] = [root]
	while not pilha.is_empty():
		var no: Node = pilha.pop_back()
		pilha.append_array(no.get_children())
		if no is Node3D and no.has_meta("limites") and String(no.name).contains("Tripo"):
			var chave := _chave_glb(String(no.name))
			if not por_chave.has(chave):
				por_chave[chave] = []
			por_chave[chave].append(no)
	var todas_as_pecas: Array = []
	for chave in por_chave:
		todas_as_pecas.append_array(por_chave[chave])
	t.append(_t_esconder("cena: todas as pecas GLB individuais do catalogo escondidas", todas_as_pecas))
	var malhas_das_pecas: Array = []
	for peca in todas_as_pecas:
		malhas_das_pecas.append_array((peca as Node).find_children("*", "MeshInstance3D", true, false))
	t.append(_t_prop("cena: pecas GLB com corte a 120 u (visibility_range_end)", malhas_das_pecas, "visibility_range_end", 120.0))
	t.append(_t_prop("cena: pecas GLB com corte a 60 u", malhas_das_pecas, "visibility_range_end", 60.0))
	if _r.has("censo"):
		var k := 0
		for item in _r["censo"]["glb_instanciados"]:
			if k >= 5:
				break
			var chave2 := String(item["chave"])
			if por_chave.has(chave2):
				t.append(_t_esconder("peca: %s (%d x %d tri) escondida" % [chave2, int(item["instancias"]), int(item["tri"])], por_chave[chave2]))
				k += 1
	# vegetacao por grupo de bloco
	var por_grupo := {}
	for mmi in mmis:
		var g := _grupo_bloco(String((mmi as Node).name))
		if not por_grupo.has(g):
			por_grupo[g] = []
		por_grupo[g].append(mmi)
	var grupos: Array = por_grupo.keys()
	if _r.has("censo"):
		var pesos: Dictionary = _r["censo"]["multimesh_por_grupo"]
		grupos.sort_custom(func(a: String, b: String) -> bool:
			return int((pesos.get(a, {}) as Dictionary).get("tri_lod0", 0)) > int((pesos.get(b, {}) as Dictionary).get("tri_lod0", 0)))
	var kg := 0
	for g in grupos:
		if kg >= 8:
			break
		t.append(_t_esconder("mata: grupo '%s' (%d blocos) escondido" % [g, (por_grupo[g] as Array).size()], por_grupo[g]))
		kg += 1
	# por shader (malhas individuais com ShaderMaterial)
	var por_shader := {}
	for mi in mis:
		var m2 := mi as MeshInstance3D
		var mat: Material = m2.material_override
		if mat == null and m2.mesh != null and m2.mesh.get_surface_count() > 0:
			mat = m2.get_active_material(0)
		if mat is ShaderMaterial and (mat as ShaderMaterial).shader != null:
			var caminho := (mat as ShaderMaterial).shader.resource_path
			if caminho.is_empty():
				caminho = "(shader embutido)"
			if not por_shader.has(caminho):
				por_shader[caminho] = []
			por_shader[caminho].append(m2)
	for caminho in por_shader:
		t.append(_t_esconder("shader: malhas com %s escondidas" % String(caminho).get_file(), por_shader[caminho]))
	# ---- interface ----
	t.append(_t_prop("HUD: todas as CanvasLayer escondidas", camadas, "visible", false))
	t.append(_t_prop("SubViewports: atualizacao desligada", _subs, "render_target_update_mode", SubViewport.UPDATE_DISABLED))
	t.append(_t_esconder("Label3D escondidos", root.find_children("*", "Label3D", true, false)))
	t.append(_t_esconder("particulas 3D escondidas", root.find_children("*", "GPUParticles3D", true, false) + root.find_children("*", "CPUParticles3D", true, false)))
	# ---- CPU: scripts por arquivo ----
	var por_script := {}
	var pilha2: Array[Node] = [root]
	while not pilha2.is_empty():
		var no2: Node = pilha2.pop_back()
		pilha2.append_array(no2.get_children())
		if no2 == _sonda:
			continue
		if no2.is_processing() or no2.is_physics_processing():
			var s := _script_de(no2)
			if s == "":
				continue
			if not por_script.has(s):
				por_script[s] = []
			por_script[s].append(no2)
	var todos_os_scripts: Array = []
	for s in por_script:
		todos_os_scripts.append_array(por_script[s])
	t.append(_t_scripts("CPU: TODOS os _process/_physics_process de script desligados", todos_os_scripts))
	var nomes: Array = por_script.keys()
	nomes.sort_custom(func(a: String, b: String) -> bool: return (por_script[a] as Array).size() > (por_script[b] as Array).size())
	var so_fisica: Array = []
	for s in nomes:
		var nos_do_script: Array = por_script[s]
		var com_fisica := false
		for no_s in nos_do_script:
			if (no_s as Node).is_physics_processing():
				com_fisica = true
				break
		if com_fisica:
			so_fisica.append_array(nos_do_script)
		# Um teste por script que roda na fisica, e pelos que rodam em muitos nos.
		if com_fisica or nos_do_script.size() >= 10:
			t.append(_t_scripts("script: %s (%d nos%s) desligado" % [String(s).get_file(), nos_do_script.size(), ", fisica" if com_fisica else ""], nos_do_script))
	t.append(_t_scripts("CPU: todos os scripts com _physics_process desligados", so_fisica))
	t.append(_t_chamar("fisica: servidor 3D inativo", func() -> void: PhysicsServer3D.set_active(false), func() -> void: PhysicsServer3D.set_active(true)))
	t.append(_t_prop("jogo inteiro com processamento desligado (so desenha)", [_jogo], "process_mode", Node.PROCESS_MODE_DISABLED))
	# ---- pacotes candidatos ----
	var pacote_a: Array = [
		_t_prop("", [root], "msaa_3d", Viewport.MSAA_DISABLED),
		_t_prop("", [root], "screen_space_aa", Viewport.SCREEN_SPACE_AA_FXAA),
		_t_prop("", sois, "directional_shadow_max_distance", 60.0),
		_t_chamar("", func() -> void: RenderingServer.directional_shadow_atlas_set_size(2048, true), func() -> void: RenderingServer.directional_shadow_atlas_set_size(atlas, true)),
	]
	t.append(_combinar("PACOTE A (so config): sem MSAA + FXAA + sombra 60 u + atlas 2048", pacote_a))
	var pacote_b: Array = pacote_a.duplicate()
	pacote_b.append(_t_prop("", _subs, "render_target_update_mode", SubViewport.UPDATE_DISABLED))
	pacote_b.append(_t_escala("", veg_perto, "visibility_range_end", 0.5))
	pacote_b.append(_t_escala("", veg_longe, "visibility_range_begin", 0.5))
	t.append(_combinar("PACOTE B: A + minimapa parado + distancias da mata x 0,5", pacote_b))
	var pacote_c: Array = pacote_b.duplicate()
	pacote_c.append(_t_prop("", malhas_das_pecas, "visibility_range_end", 120.0))
	pacote_c.append(_t_prop("", [root], "mesh_lod_threshold", 4.0))
	pacote_c.append(_t_prop("", [root], "scaling_3d_mode", Viewport.SCALING_3D_MODE_FSR))
	pacote_c.append(_t_prop("", [root], "scaling_3d_scale", 0.77))
	t.append(_combinar("PACOTE C: B + pecas com corte 120 u + LOD 4 px + FSR1 0,77", pacote_c))
	var pacote_d: Array = pacote_a.duplicate()
	pacote_d.append(_t_prop("", _subs, "render_target_update_mode", SubViewport.UPDATE_DISABLED))
	pacote_d.append(_t_escala("", veg_perto, "visibility_range_end", 0.35))
	pacote_d.append(_t_escala("", veg_longe, "visibility_range_begin", 0.35))
	pacote_d.append(_t_prop("", malhas_das_pecas, "visibility_range_end", 120.0))
	pacote_d.append(_t_prop("", [root], "mesh_lod_threshold", 8.0))
	pacote_d.append(_t_prop("", [root], "scaling_3d_mode", Viewport.SCALING_3D_MODE_FSR))
	pacote_d.append(_t_prop("", [root], "scaling_3d_scale", 0.67))
	t.append(_combinar("PACOTE D (agressivo): A + minimapa parado + mata x 0,35 + pecas 120 u + LOD 8 px + FSR1 0,67", pacote_d))
	# Por ultimo: o FSR2 troca o caminho de render (TAA proprio); se algo falhar, o resto ja foi medido.
	t.append(_combinar("render: FSR2 0,67 (com TAA proprio)", [_t_prop("", [root], "scaling_3d_mode", Viewport.SCALING_3D_MODE_FSR2), _t_prop("", [root], "scaling_3d_scale", 0.67)]))
	return t


## `grupo`: "cpu" (scripts, fisica, animacao) ou "gpu" (render e cena). Com `congelar`, os
## scripts ficam desligados durante toda a parte: o quadro passa a ser limitado so pelo
## desenho, a GPU fica a 100% e o custo de cada coisa aparece limpo.
func _fase_ab(grupo: String, pedido: String, congelar: bool) -> void:
	var vista := _vista_escolhida(pedido)
	_por_o_jogador(vista["ponto"], float(vista["rumo"]))
	_dia.set("pausado", false)
	_dia.call("definir_hora", float(_o["hora"]))
	await _esperar(2.0)
	var medir_s := float(_o["medir_s"])
	var assentar_s := float(_o["assentar_s"])
	var todas := _alternancias()
	var lista: Array = []
	for alt in todas:
		var nome := String(alt["nome"])
		var de_cpu := nome.begins_with("CPU:") or nome.begins_with("script:") or nome.begins_with("fisica:") or nome.begins_with("animacao:") or nome.begins_with("jogo inteiro") or nome.begins_with("relogio")
		if (grupo == "cpu") != de_cpu:
			continue
		# --so=trecho1|trecho2 limita aos testes cujo nome contem um dos trechos.
		if String(_o.get("so", "")) != "":
			var quer := false
			for trecho in String(_o["so"]).split("|", false):
				if nome.contains(trecho):
					quer = true
			if not quer:
				continue
		lista.append(alt)
	var chave := "ab_" + grupo
	_r[chave] = []
	_r[chave + "_vista"] = {"lugar": vista["lugar"], "rumo_graus": roundi(rad_to_deg(float(vista["rumo"]))), "alternancias": lista.size(), "scripts_congelados": congelar}
	print("MEDIR_FPS A/B %s em %s rumo %d: %d alternancias" % [grupo, vista["lugar"], roundi(rad_to_deg(float(vista["rumo"]))), lista.size()])
	# A base e a condicao do jogador: relogio andando. A hora volta ao ponto a cada par.
	var como_jogado := await _medir(medir_s, assentar_s)
	_r[chave + "_como_jogado"] = como_jogado
	var congelado: Variant = null
	var congelador := {}
	if congelar:
		for alt in todas:
			if String(alt["nome"]).begins_with("CPU: TODOS"):
				congelador = alt
		if not congelador.is_empty():
			congelado = (congelador["aplicar"] as Callable).call()
			await _esperar(1.0)
	var base := await _medir(medir_s, assentar_s)
	_r[chave + "_base_inicial"] = base
	_r["ab"] = _r[chave]
	_gpu("inicio do A/B " + grupo)
	var k := 0
	for alt in lista:
		k += 1
		if int(alt["n"]) == 0:
			continue
		# o jogador fica no lugar (algum script pode te-lo movido) e a hora volta
		_por_o_jogador(vista["ponto"], float(vista["rumo"]))
		_dia.set("pausado", false)
		_dia.call("definir_hora", float(_o["hora"]))
		var antes: Variant = (alt["aplicar"] as Callable).call()
		var com := await _medir(medir_s, assentar_s)
		(alt["desfazer"] as Callable).call(antes)
		var depois := await _medir(medir_s, assentar_s)
		var base_ms := (float(base["quadro_ms"]) + float(depois["quadro_ms"])) * 0.5
		var linha := {"nome": alt["nome"], "n": alt["n"], "base_ms": snappedf(base_ms, 0.01), "com_ms": com["quadro_ms"],
			"ganho_ms": snappedf(base_ms - float(com["quadro_ms"]), 0.01),
			"fps_base": snappedf(1000.0 / base_ms, 0.1), "fps_com": com["fps"], "com": com, "base_antes": base, "base_depois": depois}
		_r["ab"].append(linha)
		print("MEDIR_FPS AB %3d/%d %+7.2f ms  (%.1f -> %.1f FPS)  gpu %.1f->%.1f  proc %.2f->%.2f  fis %.2f->%.2f  %s" % [
			k, lista.size(), -float(linha["ganho_ms"]), linha["fps_base"], linha["fps_com"],
			(float(base["rs_gpu_ms"]) + float(depois["rs_gpu_ms"])) * 0.5, com["rs_gpu_ms"],
			(float(base["process_scripts_ms"]) + float(depois["process_scripts_ms"])) * 0.5, com["process_scripts_ms"],
			(float(base["fisica_scripts_ms"]) + float(depois["fisica_scripts_ms"])) * 0.5, com["fisica_scripts_ms"], alt["nome"]])
		base = depois
		_gravar()
	_r[chave + "_base_final"] = base
	_r.erase("ab")
	if congelar and not congelador.is_empty():
		(congelador["desfazer"] as Callable).call(congelado)
	_gpu("fim do A/B " + grupo)
	_dia.set("pausado", true)


# ----------------------------------------------------------------------------
# horas do dia e passeio
# ----------------------------------------------------------------------------

func _fase_horas() -> void:
	var vista := _vista_escolhida(String(_o["ab_gpu_em"]))
	_por_o_jogador(vista["ponto"], float(vista["rumo"]))
	for hora in [6.0, 9.0, 12.0, 15.0, 17.5, 19.0, 21.0, 0.0]:
		_dia.set("pausado", true)
		_dia.call("definir_hora", hora)
		await _esperar(1.2)
		_por_o_jogador(vista["ponto"], float(vista["rumo"]))
		var m := await _medir(1.5, 0.5)
		m["hora"] = hora
		var acesas := 0
		for l in root.find_children("*", "OmniLight3D", true, false) + root.find_children("*", "SpotLight3D", true, false):
			if (l as Light3D).is_visible_in_tree() and (l as Light3D).light_energy > 0.0:
				acesas += 1
		m["luzes_locais_acesas"] = acesas
		_r["horas"].append(m)
		print("MEDIR_FPS hora %4.1f: %.1f FPS gpu %.1f ms, %d luzes locais" % [hora, m["fps"], m["rs_gpu_ms"], acesas])
	_dia.call("definir_hora", float(_o["hora"]))
	# com o relogio correndo e V-Sync ligado: o que o jogador ve no HUD
	_dia.set("pausado", false)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	await _esperar(1.0)
	_por_o_jogador(vista["ponto"], float(vista["rumo"]))
	var com_vsync := await _medir(3.0, 0.5, true)
	com_vsync["nota"] = "V-Sync ligado, relogio andando: a condicao do jogador"
	_r["como_o_jogador_ve"] = com_vsync
	print("MEDIR_FPS com V-Sync: %.1f FPS (mediana %.1f ms, p95 %.1f ms)" % [com_vsync["fps"], com_vsync["mediana_ms"], com_vsync["p95_ms"]])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_dia.set("pausado", true)


func _fase_passeio() -> void:
	var pontos: Array = []
	var lugares := root.get_node("/root/Lugares")
	for nome in ["pier", "praca", "igreja", "venda", "casa_de_taipa", "lavoura", "rocado", "mirante"]:
		var p: Vector3 = lugares.call("ponto", nome)
		if p.is_finite():
			pontos.append({"nome": nome, "ponto": p})
	if pontos.size() < 2:
		return
	_dia.set("pausado", false)
	var velocidade := 9.0
	var serie: Array = []
	var marcos: Array = []
	_a = {}
	_quadros_ms = PackedFloat32Array()
	_ultimo_quadro_us = 0
	_por_o_jogador(pontos[0]["ponto"], 0.0)
	await _esperar(1.0)
	_gravando = true
	for i in range(pontos.size() - 1):
		var a: Vector3 = pontos[i]["ponto"]
		var b: Vector3 = pontos[i + 1]["ponto"]
		var plano := Vector3(b.x - a.x, 0.0, b.z - a.z)
		var distancia := plano.length()
		var rumo := atan2(-plano.x, -plano.z)
		marcos.append({"quadro": _quadros_ms.size(), "de": pontos[i]["nome"], "para": pontos[i + 1]["nome"], "distancia_u": snappedf(distancia, 0.1)})
		var andado := 0.0
		var t_ant := Time.get_ticks_usec()
		while andado < distancia:
			await process_frame
			var agora := Time.get_ticks_usec()
			andado += velocidade * float(agora - t_ant) / 1000000.0
			t_ant = agora
			var p := a.lerp(b, clampf(andado / maxf(distancia, 0.01), 0.0, 1.0))
			_jogador.global_position = _mundo.call("ground_position", p, 0.07)
			_jogador.set("velocity", Vector3.ZERO)
			_jogador.set("_yaw", rumo)
			_jogador.call("_apply_camera")
	_gravando = false
	for v in _quadros_ms:
		serie.append(snappedf(v, 0.1))
	var n := maxi(int(_a.get("n", 0)), 1)
	var ordenado := _quadros_ms.duplicate()
	ordenado.sort()
	var soma := 0.0
	var acima_33 := 0
	var acima_50 := 0
	var acima_100 := 0
	for v in ordenado:
		soma += v
		if v > 33.4:
			acima_33 += 1
		if v > 50.0:
			acima_50 += 1
		if v > 100.0:
			acima_100 += 1
	_r["passeio"] = {"quadros": ordenado.size(), "segundos": snappedf(soma / 1000.0, 0.1), "fps_medio": snappedf(float(ordenado.size()) / maxf(soma / 1000.0, 0.001), 0.1),
		"mediana_ms": ordenado[ordenado.size() / 2], "p95_ms": ordenado[int(ordenado.size() * 0.95)], "p99_ms": ordenado[int(ordenado.size() * 0.99)],
		"max_ms": ordenado[ordenado.size() - 1], "quadros_acima_de_33ms": acima_33, "quadros_acima_de_50ms": acima_50, "quadros_acima_de_100ms": acima_100,
		"process_scripts_ms": snappedf(float(_a.get("proc_scripts_us", 0)) / 1000.0 / n, 0.001),
		"fisica_scripts_ms": snappedf(float(_a.get("fis_scripts_us", 0)) / 1000.0 / n, 0.001),
		"fisica_passos_por_quadro": snappedf(float(_a.get("fis_passos", 0)) / n, 0.01),
		"rs_gpu_ms": snappedf(float(_a.get("rs_gpu_ms", 0.0)) / n, 0.001), "rs_cpu_ms": snappedf(float(_a.get("rs_cpu_ms", 0.0)) / n, 0.001),
		"marcos": marcos, "serie_ms": serie, "monitores": _monitores()}
	_dia.set("pausado", true)
	print("MEDIR_FPS passeio: %.1f FPS medio, p95 %.1f ms, max %.1f ms, %d quadros > 50 ms" % [_r["passeio"]["fps_medio"], _r["passeio"]["p95_ms"], _r["passeio"]["max_ms"], acima_50])
