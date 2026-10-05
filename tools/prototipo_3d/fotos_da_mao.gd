extends SceneTree
## A FOLHA DE FOTOS DOS ITENS NA MÃO: para acertar a pegada, o acerto e a pose
## de cada peça olhando, e não só pelos números.
##
##     Godot_v4.7.2-stable_win64_console.exe --path . --script res://tools/prototipo_3d/fotos_da_mao.gd -- --saida=<pasta> [--itens=foice,balde] [--estados=parado,golpe@0.45] [--janela=1.0]
##
## Com `--janela=<metros>` as câmeras miram a PALMA em cada estado, com essa
## altura de quadro (1,0 mostra a mão e o cabo, de frente, de lado, de 3/4 e de
## cima), e a folha sai como `zoom_<item>.png`: é o jeito de ver se o cabo passa
## pelo punho, que a folha do corpo inteiro (3,2 m de quadro) não mostra.
##
## Roda COM JANELA (sem --headless: o headless não desenha). Monta o corpo do
## jogador sozinho, como o portão `tests/itens_na_mao.gd` — chão, luz e uma
## régua de 1 m listrada de 10 em 10 cm ao lado —, põe cada item na mão pelo
## caminho do jogo e o fotografa em cada estado de três lados, com câmeras
## ortográficas (de frente, do lado direito e de 3/4 por cima). Salva uma folha
## por item, `<saida>/mao_<item>.png` (uma linha por estado), e imprime as
## medidas do portão: palma, comprimento, corpo, o ponto mais baixo e, no quadro
## do GLB, a palma e o ponto da peça mais perto dela — a pegada nova anda de um
## para o outro.
##
## GLB NOVO (a enxada, o balde, a vara refeitos no Tripo): meça com
## `tools/tripo/medir_glb.py`, ponha a medida no catálogo, rode esta folha e
## acerte a linha da peça em `Vestimenta3D.NA_MAO` até a foto e o portão
## concordarem.

const ITENS := ["machado", "facao", "picareta", "foice", "enxada", "vara_de_pescar", "balde"]
const ESTADOS := ["parado", "andando", "golpe@0.30", "golpe@0.45", "uso"]
const VISTA := Vector2i(320, 400)
## [nome, de onde a câmera olha (no quadro do corpo: x à esquerda, z à frente)]
const VISTAS := [["frente", Vector3(0.0, 0.0, 1.0)], ["lado", Vector3(-1.0, 0.0, 0.0)], ["3/4", Vector3(-0.7, 0.45, 0.75)]]
## Na folha da palma (`--janela`) a vista é quadrada e ganha a de cima.
const VISTA_DA_PALMA := Vector2i(360, 360)
const VISTA_DE_CIMA := ["cima", Vector3(0.0, 1.0, 0.05)]

var T
var V
var janela := 0.0
var tamanho_da_vista := VISTA
var vistas: Array = VISTAS


func _initialize() -> void:
	_run.call_deferred()


func _arg(nome: String, padrao: String) -> String:
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--" + nome + "="):
			return argumento.trim_prefix("--" + nome + "=")
	return padrao


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("fotos_da_mao: rode com janela (sem --headless); o headless não desenha.")
		quit(1)
		return
	var saida := _arg("saida", "user://fotos_da_mao")
	DirAccess.make_dir_recursive_absolute(saida)
	janela = float(_arg("janela", "0"))
	if janela > 0.0:
		tamanho_da_vista = VISTA_DA_PALMA
		vistas = VISTAS + [VISTA_DE_CIMA]
	root.get_node("/root/Estilo").modo = "tripo"
	T = load("res://tests/itens_na_mao.gd")
	V = load("res://scripts/prototipo_3d/vestimenta_3d.gd")
	var jogador: Node3D = await T.montar_jogador(self)
	var corpo := (jogador.get("visual") as Node3D).global_transform
	_montar_o_palco(jogador.get_parent(), corpo)
	var cameras := _montar_as_cameras(corpo)
	var itens: Array = Array(_arg("itens", ",".join(ITENS)).split(",", false))
	var estados: Array = Array(_arg("estados", ",".join(ESTADOS)).split(",", false))
	for id in itens:
		var no: Node3D = await T.por_na_mao(self, jogador, id)
		if no == null:
			print("%s: nada na mão" % id)
			continue
		var peca := str(no.get_meta("peca"))
		var deste: Array = estados.filter(func(e) -> bool: return e != "uso" or V.NA_MAO.get(peca, {}).has("uso"))
		var folha := Image.create(tamanho_da_vista.x * vistas.size(), tamanho_da_vista.y * deste.size(), false, Image.FORMAT_RGBA8)
		for linha in deste.size():
			var estado := str(deste[linha])
			await T.ir_ao_estado(self, jogador, estado)
			var m: Dictionary = T.medir(jogador, no)
			print("%s %s: %s | palma_na_peca=%s perto_na_peca=%s" % [id, estado, T.descrever(m), _v(m["palma_na_peca"]), _v(m["perto_na_peca"])])
			for coluna in cameras.size():
				(cameras[coluna]["rotulo"] as Label).text = "%s  %s  %s" % [peca, estado, vistas[coluna][0]]
			if janela > 0.0:
				_mirar_a_palma(cameras, corpo, corpo * (m["palma_no_corpo"] as Vector3))
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			for coluna in cameras.size():
				var foto := (cameras[coluna]["vista"] as SubViewport).get_texture().get_image()
				foto.convert(Image.FORMAT_RGBA8)
				folha.blit_rect(foto, Rect2i(Vector2i.ZERO, tamanho_da_vista), Vector2i(coluna * tamanho_da_vista.x, linha * tamanho_da_vista.y))
			await T.sair_do_estado(self, jogador)
		var arquivo := saida.path_join(("zoom_%s.png" if janela > 0.0 else "mao_%s.png") % id)
		folha.save_png(arquivo)
		print("FOLHA: ", ProjectSettings.globalize_path(arquivo))
	quit(0)


func _v(p: Vector3) -> String:
	return "(%.3f, %.3f, %.3f)" % [p.x, p.y, p.z]


## O chão, a luz, o céu e a régua de 1 m (listras de 10 cm) ao lado do corpo.
func _montar_o_palco(palco: Node3D, corpo: Transform3D) -> void:
	var chao := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(8.0, 8.0)
	chao.mesh = plano
	var terra := StandardMaterial3D.new()
	terra.albedo_color = Color("6f7a5a")
	chao.material_override = terra
	palco.add_child(chao)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sol.shadow_enabled = true
	palco.add_child(sol)
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("c9d3d8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.75)
	ambiente.environment = env
	palco.add_child(ambiente)
	for i in 10:
		var listra := MeshInstance3D.new()
		var caixa := BoxMesh.new()
		caixa.size = Vector3(0.03, 0.1, 0.03)
		listra.mesh = caixa
		var tinta := StandardMaterial3D.new()
		tinta.albedo_color = Color.BLACK if i % 2 == 0 else Color.WHITE
		tinta.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		listra.material_override = tinta
		listra.position = corpo * Vector3(0.7, 0.05 + 0.1 * i, -0.3)
		palco.add_child(listra)


## Uma SubViewport por vista, no mesmo mundo do corpo, com câmera ortográfica
## e o rótulo da foto por cima. O corpo fica de frente para +Z.
func _montar_as_cameras(corpo: Transform3D) -> Array:
	var lista := []
	for vista in vistas:
		var sub := SubViewport.new()
		sub.size = tamanho_da_vista
		sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(sub)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = janela if janela > 0.0 else 3.2
		var alvo := corpo * Vector3(0.1, 1.05, 0.55)
		var dir: Vector3 = (corpo.basis * (vista[1] as Vector3)).normalized()
		sub.add_child(camera)
		camera.look_at_from_position(alvo + dir * 6.0, alvo, Vector3.UP)
		camera.current = true
		var rotulo := Label.new()
		rotulo.position = Vector2(6, 4)
		rotulo.add_theme_color_override("font_color", Color.BLACK)
		sub.add_child(rotulo)
		lista.append({"vista": sub, "rotulo": rotulo, "camera": camera})
	return lista


## Aponta as câmeras para a palma (em coordenadas do mundo), cada uma do seu lado.
## A de cima olha para baixo com a frente do corpo para o alto da imagem.
func _mirar_a_palma(cameras: Array, corpo: Transform3D, alvo: Vector3) -> void:
	for coluna in cameras.size():
		var dir: Vector3 = (corpo.basis * (vistas[coluna][1] as Vector3)).normalized()
		var cima := Vector3.UP if absf(dir.y) < 0.9 else corpo.basis * Vector3(0.0, 0.0, -1.0)
		(cameras[coluna]["camera"] as Camera3D).look_at_from_position(alvo + dir * 6.0, alvo, cima)
