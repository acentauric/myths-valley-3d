extends SceneTree
## FOTOGRAFA O MAPA DO MINIMAPA: uma imagem do vale visto de cima, que o minimapa
## do canto passa a mostrar no lugar de desenhar o mundo 3D de novo a cada quadro
## (docs/projeto/DESEMPENHO_05_10_2026.md, F5/HUD-01/REN-01).
##
## Precisa de janela: com --headless o renderizador é o dummy e a foto sai preta.
##
##     Godot_v4.7.2-stable_win64.exe --path . --script res://tools/prototipo_3d/capturar_minimapa.gd
##     (opções depois de "--":  --lado=3072  --hora=9  --saida=<pasta>)
##
## Rode de novo SEMPRE QUE O MAPA MUDAR (árvores, ruas, costa, casas): a imagem é
## uma foto, não acompanha o vale sozinha. Grava, na pasta da saída (padrão
## assets/prototipo_3d/identidade/minimapa/):
##
##   - mapa_vale.png   a foto, RGB, sem névoa, sem gente e sem bicho;
##   - mapa_vale.json  o retângulo do mundo que a foto cobre (origem_x, origem_z,
##                     largura, altura, em unidades) e o tamanho dela em pixels. O
##                     minimapa só usa isso: ponto do mundo -> ponto da imagem;
##   - mapa_vale.png.import  (se faltar) com a textura SEM compressão e SEM mipmaps,
##                     a regra do projeto para HUD; compressão em bloco borra as ruas
##                     finas, e mipmap apaga o que a escala do minimapa já reduz.
##
## Mesma orientação do minimapa antigo: câmera ortográfica olhando para baixo com
## rotation_degrees = (-90, 0, 0), então o TOPO da imagem é o -Z do mundo e a
## DIREITA é o +X. O retângulo é o do mapa grande (get_map_frame()).
##
## A foto é feita num SubViewport do tamanho pedido, e não na janela: a janela
## não passa da tela, e 3072 px pedem mais que isso.
##
## A MATA INTEIRA NA FOTO. O corte de LOD da vegetação é por distância da câmera, e
## a 3.000 u de altura tudo estaria "longe". O corte é do `geo_region_renderer`, que
## olha a câmera da JANELA: se ela é ortográfica, ele entra em "modo mapa" (alcance
## ilimitado, árvores de verdade no lugar das cópias de longe). Por isso uma câmera
## ortográfica vira a atual da janela durante a foto, e a do SubViewport só tira o retrato.

const ALTURA := 3000.0
const PASTA := "res://assets/prototipo_3d/identidade/minimapa"
## Grupos de corpos vivos e de coisas que andam: ficam fora da foto.
const GRUPOS_VIVOS := ["moradores", "map_player", "bichos_de_casa", "bandos_de_chao",
	"cardumes", "predadores", "saveiro"]
## Nós do jogo que desenham marcas passageiras sobre o chão.
const NOS_PASSAGEIROS := ["Tubarao", "SetaMissao", "PlacasNomes", "Pegadas", "Saveiro"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(420.0).timeout.connect(func() -> void:
		push_error("CAPTURA_MINIMAPA: limite de 420 segundos excedido")
		quit(2))
	if DisplayServer.get_name() == "headless":
		push_error("CAPTURA_MINIMAPA: precisa de janela (sem --headless)")
		quit(1)
		return
	var args := _argumentos()
	var lado := int(args.get("lado", "3072"))
	var saida := String(args.get("saida", PASTA))
	if saida.begins_with("res://"):
		saida = ProjectSettings.globalize_path(saida)
	DirAccess.make_dir_recursive_absolute(saida)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var game := (load("res://scenes/prototipo_3d/vale.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(game)
	current_scene = game
	var world: Node3D = game.get_node("Cenario")
	while not world.construido:
		await process_frame
	for i in range(20):
		await process_frame
	game.set_process(false)
	var dia := root.get_node("Dia")
	dia.set("pausado", true)
	dia.call("definir_hora", float(args.get("hora", "9")))
	# Só o terreno e o que é fixo: HUD, balões e telas, gente, bicho e marcas ficam de fora.
	for camada in game.find_children("*", "CanvasLayer", true, false):
		(camada as CanvasLayer).visible = false
	for viewport in game.find_children("*", "SubViewport", true, false):
		(viewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	var escondidos := 0
	for grupo: String in GRUPOS_VIVOS:
		for no in get_nodes_in_group(grupo):
			if no is Node3D:
				(no as Node3D).visible = false
				escondidos += 1
	var jogador := game.get_node_or_null("Jogador") as Node3D
	if jogador != null:
		jogador.set_physics_process(false)
		jogador.set_process(false)
		jogador.visible = false
	for nome: String in NOS_PASSAGEIROS:
		var no := game.find_child(nome, true, false) as Node3D
		if no != null:
			no.visible = false
	var pedro = game.get("pedro")
	if pedro is Node3D:
		(pedro as Node3D).visible = false
	print("CAPTURA_MINIMAPA: %d corpos vivos escondidos" % escondidos)

	var retangulo: Rect2 = world.get_map_frame()
	var largura_px := lado
	var altura_px := lado
	if retangulo.size.x >= retangulo.size.y:
		altura_px = roundi(float(lado) * retangulo.size.y / retangulo.size.x)
	else:
		largura_px = roundi(float(lado) * retangulo.size.x / retangulo.size.y)
	var centro := world.to_global(Vector3(retangulo.get_center().x, 0.0, retangulo.get_center().y))
	print("CAPTURA_MINIMAPA: retângulo %s (%s) -> %dx%d px, %.2f px/u"
		% [str(retangulo), "moldura do mapa" if world.has_map_frame() else "limites", largura_px, altura_px,
			float(largura_px) / retangulo.size.x])

	# Sem névoa, como o minimapa e o mapa grande já faziam: de 3.000 u ela apagaria tudo.
	var ambiente: Environment = root.world_3d.environment
	var sem_nevoa: Environment = null
	if ambiente != null:
		sem_nevoa = ambiente.duplicate() as Environment
		sem_nevoa.fog_enabled = false

	# A câmera da janela: só existe para o `geo_region_renderer` entrar em modo mapa.
	var camera_da_janela := Camera3D.new()
	camera_da_janela.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera_da_janela.size = retangulo.size.y
	camera_da_janela.far = ALTURA + 1000.0
	camera_da_janela.rotation_degrees = Vector3(-90, 0, 0)
	game.add_child(camera_da_janela)
	camera_da_janela.global_position = centro + Vector3(0, ALTURA, 0)
	camera_da_janela.environment = sem_nevoa
	camera_da_janela.current = true

	var viewport := SubViewport.new()
	viewport.size = Vector2i(largura_px, altura_px)
	viewport.own_world_3d = false
	viewport.audio_listener_enable_3d = false
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	game.add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# KEEP_HEIGHT: a altura da imagem cobre a altura do retângulo.
	camera.size = retangulo.size.y
	camera.far = ALTURA + 1000.0
	camera.rotation_degrees = Vector3(-90, 0, 0)
	camera.environment = sem_nevoa
	viewport.add_child(camera)
	camera.global_position = centro + Vector3(0, ALTURA, 0)
	camera.current = true

	# Quadros para o modo mapa trocar as árvores, a água ler a profundidade e o
	# Sol assentar na hora parada.
	for i in range(45):
		await process_frame
	await RenderingServer.frame_post_draw
	var imagem := viewport.get_texture().get_image()
	if imagem == null or imagem.is_empty():
		push_error("CAPTURA_MINIMAPA: o viewport não devolveu imagem")
		quit(1)
		return
	imagem.convert(Image.FORMAT_RGB8)
	var png := saida.path_join("mapa_vale.png")
	if imagem.save_png(png) != OK:
		push_error("CAPTURA_MINIMAPA: não consegui gravar " + png)
		quit(1)
		return
	var descricao := {
		"origem_x": retangulo.position.x,
		"origem_z": retangulo.position.y,
		"largura": retangulo.size.x,
		"altura": retangulo.size.y,
		"largura_px": largura_px,
		"altura_px": altura_px,
		"hora": float(args.get("hora", "9")),
	}
	var arquivo := FileAccess.open(saida.path_join("mapa_vale.json"), FileAccess.WRITE)
	arquivo.store_string(JSON.stringify(descricao, "\t") + "\n")
	arquivo.close()
	_garantir_importacao(saida.path_join("mapa_vale.png"), PASTA.path_join("mapa_vale.png"))
	print("CAPTURA_MINIMAPA_OK ", png)
	quit()


## Se o PNG ainda não tem .import, grava um com textura sem compressão e sem
## mipmaps (o padrão do editor seria comprimir em bloco e gerar mipmaps). Se já
## tem, deixa como está: foi o editor que o escreveu, e a foto nova só o reimporta.
func _garantir_importacao(caminho_disco: String, caminho_res: String) -> void:
	var destino := caminho_disco + ".import"
	if FileAccess.file_exists(destino):
		return
	var uid := ResourceUID.id_to_text(ResourceUID.create_id())
	var importado := "res://.godot/imported/mapa_vale.png-%s.ctex" % caminho_res.md5_text()
	var texto := """[remap]

importer="texture"
type="CompressedTexture2D"
uid="%s"
path="%s"
metadata={
"vram_texture": false
}

[deps]

source_file="%s"
dest_files=["%s"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
""" % [uid, importado, caminho_res, importado]
	var arquivo := FileAccess.open(destino, FileAccess.WRITE)
	arquivo.store_string(texto)
	arquivo.close()
	print("CAPTURA_MINIMAPA: .import gravado (lossless, sem mipmaps); o editor reimporta ao focar")


func _argumentos() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			args[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	return args
