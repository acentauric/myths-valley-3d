extends SceneTree
## Prova gráfica dos shaders reais; executar com janela, não --headless.
##   ... -- --sem-franja   a franja da praia desligada: a prova TEM de reprovar.
##   ... -- --sem-desfaz   a laje da foz sem o desfazer ao largo (#138): TEM de reprovar.
##   ... -- --hash-antigo  o hash de seno de antes, longe da origem: TEM de reprovar (#197).
var falhas := 0
func _initialize() -> void: _run.call_deferred()
func conferir(ok: bool, texto: String) -> void:
	if not ok: falhas += 1; print("FALHA: ", texto)
func _run() -> void:
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("FRANJA_DA_AREIA: requer renderização gráfica")
		quit(2)
		return
	var vista := SubViewport.new()
	vista.size = Vector2i(256, 256)
	vista.own_world_3d = true
	vista.transparent_bg = true
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vista)
	var plano := MeshInstance3D.new()
	var malha := PlaneMesh.new()
	malha.size = Vector2(16, 16)
	plano.mesh = malha
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/prototipo_3d/mar/areia_praia.gdshader")
	material.set_shader_parameter("textura_areia", load("res://assets/prototipo_3d/materiais/areia_praia_v1.png"))
	if "--sem-franja" in OS.get_cmdline_user_args(): material.set_shader_parameter("franja_mar", 0.001)
	plano.material_override = material
	vista.add_child(plano)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 16
	vista.add_child(camera)
	camera.position = Vector3(0, 20, 0)
	camera.look_at(Vector3.ZERO, Vector3.BACK)
	camera.current = true
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var foto := vista.get_texture().get_image()
	# UV.x cresce para a esquerda nesta orientação de PlaneMesh. A faixa central opaca
	# e pixels recortados em posições diferentes comprovam a franja real.
	var vazios := 0
	var cheios := 0
	var cortes := {}
	for y in range(16, 240):
		var primeiro := -1
		for x in range(0, 32):
			if foto.get_pixel(x, y).a < 0.5:
				vazios += 1
				primeiro = x
			else: cheios += 1
		cortes[primeiro] = true
	conferir(foto.get_pixel(128, 128).a > 0.9, "centro da areia permanece opaco")
	conferir(vazios > 500 and cheios > 500, "franja mistura areia e fundo")
	conferir(cortes.size() > 3, "recorte acompanha o ruído sem régua reta")
	vista.queue_free()
	await process_frame
	await _laje_da_foz()
	await _hash_longe_da_origem()
	print("FRANJA_DA_AREIA: %d falha(s), %d vazios, %d cheios, %d cortes" % [falhas, vazios, cheios, cortes.size()])
	quit(1 if falhas else 0)



## A laje de areia da foz (leito_rio.gdshader com costa_desfaz) passa da costa para o mar e
## tem de se desfazer em manchas até sumir, sem acabar numa régua reta (#138). A costa fica
## no meio do plano; o fim da laje, a 8 u dela, tem de estar vazio, e o miolo da terra, cheio.
func _laje_da_foz() -> void:
	var vista := SubViewport.new()
	vista.size = Vector2i(256, 256)
	vista.own_world_3d = true
	vista.transparent_bg = true
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vista)
	var plano := MeshInstance3D.new()
	var malha := PlaneMesh.new()
	malha.size = Vector2(16, 16)
	plano.mesh = malha
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/prototipo_3d/mar/leito_rio.gdshader")
	material.set_shader_parameter("areia", load("res://assets/prototipo_3d/materiais/areia_praia_v1.png"))
	material.set_shader_parameter("costa_ponto", Vector2(0.0, -2.0))
	material.set_shader_parameter("costa_direcao", Vector2(0.0, 1.0))
	material.set_shader_parameter("costa_desfaz", 0.0 if "--sem-desfaz" in OS.get_cmdline_user_args() else 8.0)
	plano.material_override = material
	vista.add_child(plano)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 16
	vista.add_child(camera)
	camera.position = Vector3(0, 20, 0)
	camera.look_at(Vector3.ZERO, Vector3.BACK)
	camera.current = true
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var foto := vista.get_texture().get_image()
	# +z do mundo é o alto da foto: a costa está a 2 u abaixo do centro e o mar fica para
	# cima. O miolo da terra (embaixo) é cheio; no alto, a ~7 u da costa, não sobra areia.
	var terra := 0
	var mar := 0
	var cortes := {}
	for y in range(8, 248):
		var cheios_na_linha := 0
		for x in range(112, 144):
			var cheio := foto.get_pixel(x, y).a > 0.5
			if y > 200 and cheio:
				terra += 1
			if y < 40 and cheio:
				mar += 1
			if cheio:
				cheios_na_linha += 1
		if y >= 40 and y <= 130:
			cortes[cheios_na_linha] = true
	conferir(terra > 32 * 40 * 0.9, "a laje em terra fica cheia (%d de %d)" % [terra, 32 * 47])
	conferir(mar == 0, "a laje some ao largo, no mar (%d pixels sobram)" % mar)
	conferir(cortes.size() > 3, "a laje se desfaz em manchas, não numa linha (%d larguras)" % cortes.size())
	vista.queue_free()
	await process_frame


## O HASH DO RUÍDO é a base da borda esfarelada da areia e do chão. O de seno (`sin * 43758`)
## amplifica o erro da GPU: o canto de uma célula, lido da célula vizinha, dava outro valor e,
## longe da origem do vale, cada célula do ruído virava um retângulo de borda reta (#197).
## Aqui o mesmo canto é pedido de dois jeitos, `hash(floor(p) + 1)` e `hash(floor(p + 1))`, em
## coordenadas de 300 u: a diferença TEM de ser desprezível (menos de 0,05) em quase todo pixel (0,5% de folga para o arredondamento do `floor`).
func _hash_longe_da_origem() -> void:
	var antigo := "--hash-antigo" in OS.get_cmdline_user_args()
	var inc := FileAccess.get_file_as_string("res://assets/prototipo_3d/materiais/solo.gdshaderinc")
	var corpo_novo := inc.substr(inc.find("float hash21"), inc.find("// Ruído de valor") - inc.find("float hash21"))
	var corpo_antigo := "float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
"
	var codigo := "shader_type canvas_item;
" + (corpo_antigo if antigo else corpo_novo) + """
void fragment() {
	// Coordenadas do vale (até ~400 u) em passos de 0,37 u: cada pixel é um ponto diferente.
	vec2 p = vec2(300.0, -250.0) + UV * 60.0;
	vec2 c = floor(p);
	float a = hash21(c + vec2(1.0, 0.0));
	float b = hash21(floor(p + vec2(1.0, 0.0)));
	float d = hash21(c + vec2(0.0, 1.0));
	float e = hash21(floor(p + vec2(0.0, 1.0)));
	COLOR = vec4(abs(a - b) > 0.05 || abs(d - e) > 0.05 ? 1.0 : 0.0, 0.0, 0.0, 1.0);
}
"""
	var shader := Shader.new()
	shader.code = codigo
	var vista := SubViewport.new()
	vista.size = Vector2i(256, 256)
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vista)
	var retangulo := ColorRect.new()
	retangulo.size = Vector2(256, 256)
	var material := ShaderMaterial.new()
	material.shader = shader
	retangulo.material = material
	vista.add_child(retangulo)
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	var foto := vista.get_texture().get_image()
	var diferentes := 0
	for y in 256:
		for x in 256:
			if foto.get_pixel(x, y).r > 0.5:
				diferentes += 1
	conferir(diferentes <= 330, "o hash dá o mesmo valor ao mesmo canto de célula longe da origem (%d de 65536 pixels diferem; o aceitável é até 330, o hash de seno dava ~50 mil)" % diferentes)
	print("HASH_LONGE: %d pixels diferem" % diferentes)
	vista.queue_free()
	await process_frame
