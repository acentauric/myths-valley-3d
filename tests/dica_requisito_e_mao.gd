extends SceneTree
## #134/#120: layout real em três idiomas/resoluções e seleção sem rótulo persistente.
var Dica = preload("res://scripts/prototipo_3d/dica_tecla.gd")
var caminho_barra := "res://scripts/prototipo_3d/barra_de_mao.gd"
var falhas := 0
func _initialize() -> void:
	if "--antes" in OS.get_cmdline_user_args():
		Dica = load("res://tools/temp/dica-mao-antes/dica_tecla.gd")
		caminho_barra = "res://tools/temp/dica-mao-antes/barra_de_mao.gd"
	_run.call_deferred()
func conferir(ok: bool, motivo: String) -> void:
	if not ok:
		falhas += 1
		push_error("DICA_REQUISITO_MAO_FALHOU: " + motivo)
func quadros() -> void:
	for _i in 4:
		await process_frame
func _run() -> void:
	var camada := Control.new()
	root.add_child(camada)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position.z = 8
	var exemplos := ["Tronco caído · precisa de Machado", "Fallen log · needs an Axe", "Tronco caído · requiere Hacha"]
	for largura in [640, 1280, 1920]:
		root.size = Vector2i(largura, largura * 9 / 16)
		for exemplo in exemplos:
			var dica: PanelContainer = Dica.criar(camada, "E", exemplo)
			Dica.mostrar_em(dica, camera, Vector3.ZERO, exemplo)
			await quadros()
			var texto := dica.find_child("Acao", true, false) as Label
			var requisito := dica.find_child("Requisito", true, false) as Label
			var tecla := dica.find_child("Tecla", true, false) as Control
			var letra := dica.find_child("Letra", true, false) as Label
			# #188: o alvo é título (ouro, Cinzel); o requisito, leitura (creme, sans do HUD, menor).
			conferir(requisito != null and requisito.visible and requisito.text != "" and texto.text.find(char(10)) < 0, "alvo e requisito em rótulos separados: " + exemplo)
			conferir(dica.size.x < largura * 0.65 and dica.size.y > 40, "altura e largura adaptam às linhas")
			conferir(texto.size.x <= 282 and texto.size.y >= texto.get_minimum_size().y, "texto cabe sem corte")
			conferir(requisito.size.x <= 282 and requisito.size.y >= requisito.get_minimum_size().y, "requisito cabe sem corte")
			conferir(texto.get_theme_color("font_color").is_equal_approx(Dica.COR_DO_ALVO), "alvo em ouro")
			conferir(requisito.get_theme_color("font_color").is_equal_approx(Dica.COR_DO_REQUISITO), "requisito em creme")
			conferir(requisito.get_theme_font("font") != texto.get_theme_font("font"), "alvo e requisito em fontes diferentes")
			conferir(requisito.get_theme_font_size("font_size") < texto.get_theme_font_size("font_size"), "requisito menor que o alvo")
			# A plaqueta do E tem a altura das duas linhas, é quadrada e a letra cresce com ela.
			var altura_das_linhas: float = texto.size.y + requisito.size.y
			conferir(absf(tecla.size.y - altura_das_linhas) <= 3.0, "plaqueta com a altura das duas linhas (%.1f x %.1f)" % [tecla.size.y, altura_das_linhas])
			conferir(absf(tecla.size.x - tecla.size.y) <= 2.0, "plaqueta quadrada (%.1f x %.1f)" % [tecla.size.x, tecla.size.y])
			conferir(letra.get_theme_font_size("font_size") > 14, "letra da plaqueta grande")
			var longa: String = exemplo + " e os materiais necessários para preparar este terreno com segurança"
			Dica.mostrar_em(dica, camera, Vector3.ZERO, longa)
			await quadros()
			conferir(requisito.get_line_count() > 1 and dica.size.x < largura * 0.65, "requisito longo quebra por largura")
			Dica.mostrar_em(dica, camera, Vector3.ZERO, "Olhar")
			await quadros()
			conferir(not requisito.visible and texto.get_line_count() == 1 and dica.size.y < 40, "interação simples volta ao tamanho compacto")
			conferir(absf(tecla.size.y - texto.size.y) <= 3.0 and absf(tecla.size.x - tecla.size.y) <= 2.0, "plaqueta da altura da linha única e quadrada (%.1f x %.1f)" % [tecla.size.x, tecla.size.y])
			dica.queue_free()
			await process_frame
	var inv = root.get_node("Inventario")
	inv.espacos.fill({})
	inv.espacos[0] = {"id": "enxada", "qtd": 1}
	inv.selecionar(0)
	var barra = load(caminho_barra).new()
	camada.add_child(barra)
	await quadros()
	conferir(not barra.get_node("NaMao").visible, "nome da enxada não fica persistente")
	conferir(inv.na_mao() == "enxada", "ocultar texto preserva item selecionado")
	var slot: Panel = barra.get_node("Fila").get_child(0)
	conferir(slot.tooltip_text != "", "hover identifica o item")
	conferir(slot.get_theme_stylebox("panel").border_width_left == 2, "seleção mantém destaque no slot")
	inv.selecionar(inv.MAO_LIVRE)
	await quadros()
	conferir(not barra.get_node("NaMao").visible and inv.na_mao() == "", "mão livre não exibe rótulo nem muda inventário")
	inv.espacos[0] = {}
	inv.mudou.emit()
	await quadros()
	conferir(slot.tooltip_text == "", "slot esvaziado não mantém tooltip antigo")
	camada.queue_free()
	camera.queue_free()
	await quadros()
	print("DICA_REQUISITO_MAO: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
