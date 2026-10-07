extends SceneTree
## FACHADAS DAS CASAS, de frente (+Z) e de lado (+X), em projeção ortogonal e com régua de 0,5 m:
## é como se leu a PORTA PINTADA de cada GLB para `data/interiores_casas.json` (`modelos`).
## A porta não existe na malha, só na textura, e nada no arquivo diz onde ela fica.
##
##     Godot_v4.7.2-stable_win64_console.exe --path . --script res://tools/prototipo_3d/fachadas_das_casas.gd -- \
##         casa_taipa,casa_pasto,venda folha1
##
## Precisa de janela (não use --headless: o desenho não sai). A folha vai para a pasta de dados do
## usuário (`user://<nome>.png`; o caminho real é impresso). Linhas vermelhas grossas de metro em metro,
## com o número; amarelas de meio em meio. De frente, +X está à direita de quem olha: é o `porta_x`
## do `modelos`, medido do meio do GLB para a direita, e a largura e a altura do vão.
## Para casca irregular (alcova no lugar da porta, alpendre fundo), confira também de planta: uma
## câmera ortogonal por cima, com o plano de corte (`near`) a 1,2 m, mostra as paredes de dentro.

const CW := 720
const CH := 440
var Catalogo


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	root.get_node("/root/Estilo").modo = "tripo"
	Catalogo = load("res://scripts/prototipo_3d/catalogo_assets.gd")
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
	luz.light_energy = 1.1
	root.add_child(luz)
	var amb := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.7, 0.85)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.85, 0.85)
	amb.environment = e
	root.add_child(amb)
	var sub := SubViewport.new()
	sub.size = Vector2i(CW, CH)
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sub)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.far = 200.0
	sub.add_child(cam)
	cam.current = true
	var chaves: PackedStringArray = (OS.get_cmdline_user_args()[0] as String).split(",")
	var nome_folha: String = OS.get_cmdline_user_args()[1]
	var folha := Image.create(CW * 2, CH * chaves.size(), false, Image.FORMAT_RGBA8)
	var r := 0
	for chave in chaves:
		var pose := Node3D.new()
		root.add_child(pose)
		var modelo = Catalogo.instanciar(chave, pose, Vector3.ZERO, 1.0, 0.0)
		if modelo == null:
			print("sem modelo: ", chave)
			r += 1
			continue
		var lim: AABB = modelo.get_meta("limites")
		print("%s: x %.2f  y %.2f  z %.2f" % [chave, lim.size.x, lim.size.y, lim.size.z])
		var regua := Node3D.new()
		pose.add_child(regua)
		for lado in 2:
			for filho in regua.get_children():
				filho.queue_free()
			var extensao: float = lim.size.x if lado == 0 else lim.size.z
			var tam := maxf(lim.size.y * 1.35, extensao * 1.35 * float(CH) / float(CW))
			cam.size = tam
			var meio_y := lim.size.y * 0.5
			if lado == 0:
				cam.position = Vector3(0.0, meio_y, 60.0)
				cam.look_at(Vector3(0.0, meio_y, 0.0), Vector3.UP)
			else:
				cam.position = Vector3(60.0, meio_y, 0.0)
				cam.look_at(Vector3(0.0, meio_y, 0.0), Vector3.UP)
			_regua(regua, lim, lado)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var img := sub.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			folha.blit_rect(img, Rect2i(0, 0, CW, CH), Vector2i(lado * CW, r * CH))
		pose.queue_free()
		await process_frame
		r += 1
	var arquivo := "user://%s.png" % nome_folha
	folha.save_png(arquivo)
	print("folha: ", ProjectSettings.globalize_path(arquivo))
	quit()


## Linhas de 0,5 em 0,5 m (a de metro inteiro mais grossa, com número), na horizontal
## ao longo da fachada (X, ou Z de lado) e na vertical (Y).
func _regua(raiz: Node3D, lim: AABB, lado: int) -> void:
	var tinta_fina := _tinta(Color(1, 1, 0, 0.55))
	var tinta_grossa := _tinta(Color(1, 0.1, 0.1, 0.9))
	var meia: float = (lim.size.x if lado == 0 else lim.size.z) * 0.5
	var k := -ceili(meia * 2.0)
	while k <= ceili(meia * 2.0):
		var pos: float = float(k) * 0.5
		var inteiro := k % 2 == 0
		var linha := MeshInstance3D.new()
		var caixa := BoxMesh.new()
		caixa.size = Vector3(0.02 if not inteiro else 0.045, lim.size.y + 1.0, 0.02) if lado == 0 else Vector3(0.02, lim.size.y + 1.0, 0.02 if not inteiro else 0.045)
		linha.mesh = caixa
		linha.material_override = tinta_grossa if inteiro else tinta_fina
		linha.position = Vector3(pos, lim.size.y * 0.5, 20.0) if lado == 0 else Vector3(20.0, lim.size.y * 0.5, pos)
		raiz.add_child(linha)
		if inteiro:
			var texto := Label3D.new()
			texto.text = "%d" % int(pos)
			texto.font_size = 96
			texto.pixel_size = 0.0035
			texto.modulate = Color(1, 0.1, 0.1)
			texto.outline_modulate = Color.WHITE
			texto.outline_size = 12
			texto.no_depth_test = true
			texto.position = Vector3(pos, -0.15, 20.0) if lado == 0 else Vector3(20.0, -0.15, pos)
			if lado == 1:
				texto.rotation.y = PI * 0.5
			raiz.add_child(texto)
		k += 1
	var j := 0
	while float(j) * 0.5 <= lim.size.y + 0.5:
		var y: float = float(j) * 0.5
		var inteiro := j % 2 == 0
		var linha := MeshInstance3D.new()
		var caixa := BoxMesh.new()
		caixa.size = Vector3(meia * 2.0 + 2.0, 0.02 if not inteiro else 0.045, 0.02) if lado == 0 else Vector3(0.02, 0.02 if not inteiro else 0.045, meia * 2.0 + 2.0)
		linha.mesh = caixa
		linha.material_override = tinta_grossa if inteiro else tinta_fina
		linha.position = Vector3(0.0, y, 20.0) if lado == 0 else Vector3(20.0, y, 0.0)
		raiz.add_child(linha)
		if inteiro:
			var texto := Label3D.new()
			texto.text = "%d" % int(y)
			texto.font_size = 96
			texto.pixel_size = 0.0035
			texto.modulate = Color(0.1, 0.2, 1)
			texto.outline_modulate = Color.WHITE
			texto.outline_size = 12
			texto.no_depth_test = true
			texto.position = Vector3(-meia - 0.55, y, 20.0) if lado == 0 else Vector3(20.0, y, -meia - 0.55)
			if lado == 1:
				texto.rotation.y = PI * 0.5
			raiz.add_child(texto)
		j += 1


func _tinta(cor: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = cor
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	return m
