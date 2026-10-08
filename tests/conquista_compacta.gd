extends SceneTree
## #130: conclusão pelo caderno real, sem clarão aditivo sobre todo o vale.
var falhas := 0
func _initialize() -> void:
	_run.call_deferred()
func conferir(ok: bool, motivo: String) -> void:
	if not ok:
		falhas += 1
		push_error("CONQUISTA_COMPACTA_FALHOU: " + motivo)
func _run() -> void:
	await process_frame
	var festa = load("res://scripts/prototipo_3d/conquista_da_missao.gd").new()
	root.add_child(festa)
	var caderno = root.get_node("CadernoDoVale")
	caderno.abrir_missao("teste_conquista", "Uma leira pronta", "pedro")
	# A festa só vem pedida (07/10: a missão inteira festeja, o passo do meio não).
	caderno.concluir("teste_conquista", true)
	await create_timer(0.9).timeout
	if "--falsificar-clarao" in OS.get_cmdline_user_args():
		festa._clarao.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	conferir(festa.ativa(), "conclusão real não abriu aviso")
	conferir(festa.mostrada.get("id") == "teste_conquista", "perdeu identidade do passo")
	conferir(festa._raiz.get_global_rect().get_area() <= 420.0 * 150.0, "conquista ocupa a tela inteira")
	conferir(festa._sombra.color.a == 0.0 and festa._veu.color.a == 0.0, "conquista escurece ou embranquece o vale")
	conferir(festa._clarao.material == null or festa._clarao.material.blend_mode != CanvasItemMaterial.BLEND_MODE_ADD, "luz aditiva estoura a exposição")
	conferir(festa.ENTRA + festa.FICA + festa.SAI <= 3.5, "aviso interfere por tempo excessivo")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var imagem := root.get_texture().get_image()
		imagem.save_png("res://tools/temp/conquista-compacta.png")
	await create_timer(7.0).timeout
	conferir(not festa.ativa(), "aviso não terminou")
	festa.queue_free()
	await process_frame
	print("CONQUISTA_COMPACTA: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
