extends SceneTree
## Confere O FOLHETO NO VALE (#21): o cordel lido no papel.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/folheto.gd
##
## O `Folheto` é o do 2D, idêntico (`scripts/ui/folheto.gd`), como a mochila.
## A pergunta 4 é a do `tools/gdscript/testar_folheto.gd` de lá, que atravessa
## com ele (#18); as outras são do vale.
##
##   1. É O MESMO ARQUIVO DO 2D, byte a byte: mudou lá sem copiar, reprova aqui.
##   2. O PAPEL NA TELA: por cima do HUD, no tamanho do vale, inteiro na janela.
##   3. ACHAR ABRE O PAPEL e para o vale; o E o guarda e o vale volta a andar,
##      com o calendário preso. O Esc guarda também, e a tecla de outra tela
##      troca para ela — é o "[L] coleção" que o rodapé dele escreve.
##   4. CADA UM DOS DEZ CABE NO PAPEL: nenhum rótulo corta linha nem sai do
##      papel, e o título não encosta na assinatura.
##   5. O ALMANAQUE RELÊ: o cordel aberto, escolhido de novo, abre o papel, e
##      o rodapé diz isso; o papel guardado devolve o almanaque onde estava.

const CORDEL := "peso_falso"

var falhas := 0
var folheto
var colecao
var relogio
var dia
var vale


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("FOLHETO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	folheto = root.get_node_or_null("/root/Folheto")
	colecao = root.get_node("/root/Colecao")
	relogio = root.get_node("/root/Relogio")
	dia = root.get_node("/root/Dia")
	_conferir(folheto != null, "não há autoload Folheto no vale")
	if folheto == null:
		_fechar()
		return

	# --- 1. É O MESMO ARQUIVO DO 2D --------------------------------------------
	var raiz_do_2d := ProjectSettings.globalize_path("res://").path_join("..")
	var copia := FileAccess.get_file_as_bytes("res://scripts/ui/folheto.gd")
	var original := FileAccess.get_file_as_bytes(raiz_do_2d.path_join("scripts/ui/folheto.gd"))
	_conferir(not original.is_empty(), "não achei o folheto.gd do 2D para comparar")
	_conferir(copia == original,
		"o folheto.gd do vale não é o do 2D: a tela é compartilhada, e a mudança vai lá e se copia")

	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(6)
	await _mundo_pronto()
	await _frames(10)
	vale = current_scene
	dia.pausado = false

	# --- 2. O PAPEL NA TELA ----------------------------------------------------
	_conferir(folheto.layer > vale.hud.layer,
		"o folheto está na camada %d e o HUD na %d: o HUD desenha por cima do papel" % [folheto.layer, vale.hud.layer])
	var papel: Rect2 = folheto.get_script().get_script_constant_map()["PAPEL_EM"]
	var tela: Vector2 = vale.get_viewport().get_visible_rect().size
	var na_tela: Rect2 = folheto.transform * papel
	_conferir(Rect2(Vector2.ZERO, tela).encloses(na_tela),
		"o papel sai da janela: %s numa tela de %s" % [str(na_tela), str(tela)])
	_conferir(na_tela.size.x >= papel.size.x * 1.8,
		"o papel tem %.0f px de largura: abriu no tamanho do 2D (%.0f)" % [na_tela.size.x, papel.size.x])

	# --- 3. ACHAR ABRE O PAPEL -------------------------------------------------
	var achados = vale.get_node("Achados")
	var cordel = null
	for achado in achados.no_chao:
		if str(achado["tipo"]) == "cordel" and str(achado["id"]) == CORDEL:
			cordel = achado
	_conferir(cordel != null, "o cordel '%s' não está no chão para ser achado" % CORDEL)
	if cordel != null:
		vale.player.global_position = cordel["ponto"] + Vector3(0.6, 0.0, 0.0)
		await _frames(3)
		_conferir(achados.interagir(), "perto do cordel, o E não pegou nada")
		await _frames(3)
		_conferir(folheto.aberto, "o cordel achado não abriu no papel")
		_conferir(paused, "o papel abriu com o vale andando atrás dele")
		_conferir(dia.pausado, "o papel abriu com o relógio andando")
		await _tecla(KEY_E)
		await _frames(3)
		_conferir(not folheto.aberto, "o E não guardou o papel")
		_conferir(not paused, "o papel guardado deixou o vale parado")
		_conferir(not dia.pausado, "o papel guardado deixou o relógio parado")
		_conferir(relogio.pausado, "o papel guardado soltou o calendário: ele anda sozinho, fora do Dia")
	# O Esc guarda. E avisa UMA vez que a tela fechou: o papel avisa por conta
	# própria, e quando quem fecha é o dono das telas o aviso dele já saiu —
	# dois avisos devolveriam a câmera e o relógio duas vezes.
	var fechou_o_papel := [0]
	var contar := func(nome: String, aberta: bool) -> void:
		if nome == "folheto" and not aberta:
			fechou_o_papel[0] += 1
	vale.telas.tela_mudou.connect(contar)
	vale.ler_o_folheto(CORDEL)
	await _frames(4)
	_conferir(folheto.aberto, "o vale não abriu o papel pedido")
	await _tecla(KEY_ESCAPE)
	await _frames(3)
	vale.telas.tela_mudou.disconnect(contar)
	_conferir(fechou_o_papel[0] == 1, "guardar o papel pelo Esc avisou %d vez(es) que ele fechou, e é uma" % fechou_o_papel[0])
	_conferir(not folheto.aberto, "o Esc não guardou o papel")
	_conferir(vale.telas.aberta() == "", "o Esc do papel abriu '%s'" % vale.telas.aberta())
	_conferir(not paused, "o papel guardado pelo Esc deixou o vale parado")
	# A tecla de outra tela troca para ela.
	vale.ler_o_folheto(CORDEL)
	await _frames(4)
	await _tecla(load("res://scripts/prototipo_3d/atalhos.gd").tecla("almanaque"))
	await _frames(3)
	_conferir(not folheto.aberto, "a tecla do almanaque não guardou o papel")
	_conferir(vale.telas.aberta() == "almanaque", "a tecla do almanaque, com o papel aberto, abriu '%s'" % vale.telas.aberta())
	_conferir(paused, "trocar do papel para o almanaque soltou o vale")
	vale.telas.fechar_tudo()
	await _frames(3)
	_conferir(not paused, "fechado o almanaque, o vale ficou parado")

	# --- 4. CADA UM DOS DEZ CABE NO PAPEL ----------------------------------------
	var dentro := papel.grow(-10.0)
	for id in colecao.catalogo("cordeis"):
		folheto.abrir(str(id))
		await _frames(4)
		_conferir(folheto.aberto, "o folheto não abriu: %s" % id)
		for campo in ["_titulo", "_autor", "_preco", "_versos", "_nota", "_teclas"]:
			var etiqueta: Label = folheto.get(campo)
			_conferir(etiqueta.get_visible_line_count() >= etiqueta.get_line_count(),
				"%s: %s não cabe na caixa (mostra %d de %d linhas)" % [
					id, campo, etiqueta.get_visible_line_count(), etiqueta.get_line_count()])
			_conferir(dentro.encloses(etiqueta.get_global_rect()),
				"%s: %s saiu do papel (%s)" % [id, campo, etiqueta.get_global_rect()])
		_conferir(folheto._titulo.get_global_rect().end.y <= folheto._autor.get_global_rect().position.y,
			"%s: o título encostou na assinatura" % id)
		folheto.fechar()
		await _frames(2)

	# --- 5. O ALMANAQUE RELÊ ---------------------------------------------------
	colecao.achar("cordeis", CORDEL)
	var alm = vale.hud.almanaque()
	_conferir(alm != null, "o vale não tem almanaque")
	if alm != null:
		vale.telas.abrir("almanaque")
		await _frames(2)
		if alm._secao != "cordeis":
			alm._escolher_secao("cordeis")
		alm._escolher_item(CORDEL)
		await _frames(2)
		_conferir(not folheto.aberto, "escolher o cordel uma vez já abriu o papel: a primeira escolha é a ficha")
		_conferir(str(alm._rodape.text).contains(str(achados._texto("ler_no_papel"))),
			"o rodapé do almanaque não diz que o cordel aberto se lê no papel: '%s'" % alm._rodape.text)
		alm._escolher_item(CORDEL)
		await _frames(3)
		_conferir(folheto.aberto, "escolher de novo o cordel aberto não abriu o papel")
		_conferir(vale.telas.aberta() == "folheto", "com o papel aberto, a tela aberta é '%s'" % vale.telas.aberta())
		await _tecla(KEY_E)
		await _frames(4)
		_conferir(not folheto.aberto, "o E não guardou o papel aberto do almanaque")
		_conferir(vale.telas.aberta() == "almanaque", "guardado o papel, o almanaque não voltou (aberta: '%s')" % vale.telas.aberta())
		_conferir(alm._escolhido == CORDEL, "o almanaque voltou fora do cordel que estava aberto ('%s')" % alm._escolhido)
		_conferir(paused, "de volta ao almanaque, o vale andou")
		vale.telas.fechar_tudo()
		await _frames(3)

	_fechar()


func _tecla(codigo: int) -> void:
	for apertada in [true, false]:
		var evento := InputEventKey.new()
		evento.physical_keycode = codigo
		evento.keycode = codigo
		evento.pressed = apertada
		Input.parse_input_event(evento)
		await _frames(2)


func _fechar() -> void:
	if folheto != null and folheto.aberto:
		folheto.fechar()
	print("")
	if falhas == 0:
		print("FOLHETO_OK: o folheto é o do 2D byte a byte, fica por cima do HUD no tamanho do vale, o cordel achado abre no papel e para o vale, E e Esc guardam sem soltar o calendário, a tecla de outra tela troca para ela, os dez cordéis cabem no papel, e o almanaque relê o cordel aberto e volta onde estava")
	else:
		print("folheto: %d falha(s)" % falhas)
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
