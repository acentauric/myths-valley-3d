extends SceneTree
## Painel PERSONAGENS: abre, edita um morador (altura, posto, fala) e uma peça
## (medida), confere que os ajustes chegam aos dados do jogo e restaura o padrão.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	AjustesConteudo.restaurar_morador("benedito")
	AjustesConteudo.restaurar_peca("mangueira")
	_assert(change_scene_to_file("res://scenes/prototipo_3d/abertura.tscn") == OK, "abertura carrega")
	await _frames(4)
	await _mundo_pronto()
	var abertura = current_scene
	abertura._abrir_personagens()
	await _frames(3)
	var painel = abertura.painel_personagens
	_assert(painel != null, "painel aberto")
	_assert(painel._ancoras.size() > 5, "âncoras do vale disponíveis para os postos")
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
