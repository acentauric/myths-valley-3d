extends SceneTree
## Painel PERSONAGENS: abre, edita um morador (altura, posto, fala) e uma peça
## (medida), confere que os ajustes chegam aos dados do jogo e restaura o padrão.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	AjustesConteudo.restaurar_morador("benedito")
	AjustesConteudo.restaurar_peca("mangueira")
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var painel = load("res://scripts/prototipo_3d/painel_personagens.gd").new()
	host.add_child(painel)
	painel.abrir(load("res://scripts/prototipo_3d/tema_menu.gd").criar())
	painel._ancoras.assign(["Bar", "Casa de Carro Quebrado", "Igreja", "Pier", "Praça", "Roçado"])
	await _frames(3)
	_assert(painel._lista.get_meta("morador") == "pedro", "um morador por vez começa pelo Pedro")
	_assert(painel._preview_modelo != null and not painel._preview_modelo.find_children("*", "MeshInstance3D", true, false).is_empty(), "prévia usa o modelo 3D real")
	_assert(painel._preview_viewport.own_world_3d, "prévia não mistura luzes e objetos com o vale")
	_assert(painel._rolagem.get_global_rect().encloses(painel._lista.get_global_rect()), "ficha cabe sem rolagem")
	await _capturar("morador")
	for botao in painel.find_children("*", "Button", true, false):
		_assert(botao.text != "FECHAR", "sem botão FECHAR redundante")
	painel._navegar_morador(1)
	await _frames(3)
	_assert(painel._lista.get_meta("morador") == "benedito", "navegação mostra apenas Benedito")
	_assert(painel._preview_modelo.name.begins_with("Benedito"), "prévia acompanha o morador")
	# Edita o Benedito pelo botão EDITAR.
	painel._editando["m:benedito"] = true
	painel._reconstruir_lista()
	await _frames(2)
	var spins: Array = painel._lista.find_children("*", "SpinBox", true, false)
	var opcoes: Array = painel._lista.find_children("*", "OptionButton", true, false)
	print("PAINEL: %d campos numéricos, %d seletores de lugar" % [spins.size(), opcoes.size()])
	_assert(spins.size() >= 3 and opcoes.size() >= 5, "editor do morador com altura, volume e postos")
	(spins[0] as SpinBox).value = 1.9
	(opcoes[0] as OptionButton).select(1)
	(opcoes[0] as OptionButton).item_selected.emit(1)
	var falas: Array = painel._lista.find_children("*", "LineEdit", true, false)
	var campo_fala: LineEdit = falas[falas.size() - 1]
	campo_fala.text = "Fala de teste."
	campo_fala.text_changed.emit("Fala de teste.")
	var dados = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs_3d.json"))
	var ajustado: Dictionary = {}
	for m in AjustesConteudo.npcs(dados)["moradores"]:
		if m["id"] == "benedito":
			ajustado = m
	print("PAINEL: altura %s · manhã %s · falas %s" % [ajustado.get("altura"), ajustado["postos"]["manha"], ajustado["falas"].map(func(f): return f["texto"])])
	_assert(is_equal_approx(float(ajustado["altura"]), 1.9), "altura ajustada chega aos dados")
	_assert(String(ajustado["postos"]["manha"][0]) == painel._ancoras[1] or String(ajustado["postos"]["manha"][0]) != "", "posto ajustado")
	_assert(ajustado["falas"].any(func(f): return f["texto"] == "Fala de teste."), "fala ajustada")
	painel._trocar_aba(1)
	await _frames(3)
	var grade: GridContainer = painel._lista.get_node("GradeAssets")
	var primeiro_cartao := str(grade.get_child(0).name)
	_assert(grade.columns == 4 and grade.get_child_count() == 12, "assets em grade paginada")
	_assert(painel._lista.find_children("*", "SpinBox", true, false).is_empty(), "grade não abre todos os editores")
	_assert(painel._rolagem.get_global_rect().encloses(painel._lista.get_global_rect()), "grade cabe sem rolagem")
	await _capturar("assets")
	painel._asset_pagina = 1
	painel._reconstruir_lista()
	await _frames(3)
	_assert(str(painel._lista.get_node("GradeAssets").get_child(0).name) != primeiro_cartao, "paginação muda os cartões")
	painel._abrir_peca("mangueira")
	await _frames(3)
	_assert(not painel._lista.has_node("GradeAssets") and painel._preview_modelo != null, "selecionar peça abre só seu registro e modelo")
	await _capturar("registro")
	painel._editando["p:mangueira"] = true
	painel._reconstruir_lista()
	await _frames(3)
	var campos_peca: Array = painel._lista.find_children("*", "SpinBox", true, false)
	_assert(campos_peca.size() >= 2, "editor da peça selecionada")
	await _capturar("editor")
	var altura_antes := float(AjustesConteudo.peca("mangueira")["altura"])
	campos_peca[0].value = altura_antes + 1.5
	_assert(is_equal_approx(float(AjustesConteudo.peca("mangueira")["altura"]), altura_antes + 1.5), "campo da peça grava ajuste")
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--captura="):
			painel._trocar_aba(0)
			await _frames(3)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(argumento.trim_prefix("--captura="))
	# Peça: a medida da mangueira muda a especificação usada pelo catálogo.
	var antes := float(CatalogoAssets.PECAS["mangueira"]["altura"])
	AjustesConteudo.definir_peca("mangueira", "altura", antes + 1.5)
	_assert(is_equal_approx(float(AjustesConteudo.peca("mangueira")["altura"]), antes + 1.5), "medida da peça ajustada")
	# Restaurar volta ao padrão do projeto.
	AjustesConteudo.restaurar_morador("benedito")
	AjustesConteudo.restaurar_peca("mangueira")
	_assert(not AjustesConteudo.morador_ajustado("benedito"), "morador restaurado")
	_assert(is_equal_approx(float(AjustesConteudo.peca("mangueira")["altura"]), antes), "peça restaurada")
	print("PAINEL_PERSONAGENS_OK")
	quit()


func _capturar(nome: String) -> void:
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--capturas="):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(argumento.trim_prefix("--capturas=") + "-" + nome + ".png")


func _assert(condition: bool, label: String) -> void:
	if not condition:
		push_error("PAINEL_FALHOU: " + label)
		quit(1)
		assert(false, label)


func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame


## O vale se monta ao longo de vários quadros (world_builder): espera ficar pronto.
func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
