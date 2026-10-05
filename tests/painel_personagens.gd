extends SceneTree
## Painel MODELOS: as duas abas abrem em cartões e cada cartão abre a ficha no mesmo
## formato (prévia 3D e dados, todas as falas, sem filtro); EDITAR e GRAVAR ficam no
## cabeçalho; edita um morador (altura, posto, fala) e uma peça (medida), confere que os
## ajustes chegam aos dados do jogo, que fechar com ajuste pendente pede confirmação e
## restaura o padrão.


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
	var fechou := [false]
	painel.fechado.connect(func() -> void: fechou[0] = true)
	await _frames(3)
	# MORADORES abre em cartões, como ASSETS.
	var cartoes: GridContainer = painel._lista.get_node("GradeMoradores")
	# Com os moradores novos de 05/10 são mais de uma página de cartões: a primeira vem cheia, e o viajante fecha a lista.
	_assert(cartoes.columns == 4 and cartoes.get_child_count() == mini(painel._pessoas.size(), painel.CARTOES_POR_PAGINA), "moradores em cartões")
	_assert(str(cartoes.get_child(0).name) == "Morador_pedro" and str((painel._pessoas.back() as Dictionary).get("id", "")) == "viajante", "Pedro abre os cartões e o viajante fecha")
	var ids_na_lista: Array = []
	for pessoa: Dictionary in painel._pessoas:
		ids_na_lista.append(str(pessoa.get("id", "")))
	for novo in ["padre", "guarda", "lavadeira", "mestre_saveiro"]:
		_assert(novo in ids_na_lista, "o morador novo '%s' aparece no painel PERSONAGENS" % novo)
	_assert(painel._campo_filtro.visible and not painel._botao_editar.visible, "nos cartões há filtro e não há EDITAR")
	for botao in painel.find_children("*", "Button", true, false):
		_assert(not (botao.text in ["FECHAR", "GRAVAR NO PROJETO", "Voltar ao catálogo"]), "sem botões antigos no corpo: %s" % botao.text)
	for rotulo in painel.find_children("*", "Label", true, false):
		_assert(not rotulo.text.begins_with("Os ajustes valem") and not rotulo.text.begins_with("Selecione"), "sem avisos que a interface já comunica")
	await _capturar("cartoes")
	# A ficha do Pedro: prévia real, dados à direita e as três falas, sem navegar entre falas.
	painel._abrir("pedro")
	await _frames(3)
	_assert(painel._lista.get_meta("ficha") == "pedro", "cartão abre a ficha")
	_assert(painel._preview_modelo != null and not painel._preview_modelo.find_children("*", "MeshInstance3D", true, false).is_empty(), "prévia usa o modelo 3D real")
	_assert(painel._preview_viewport.own_world_3d, "prévia não mistura luzes e objetos com o vale")
	_assert(painel._voz.bus == &"Escuta", "a fala toca fora do mudo geral")
	var audio := root.get_node("/root/Audio")
	var som_antes: bool = audio.som_ativo
	audio.definir_som_ativo(false)
	_assert(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Geral")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Escuta")) and not AudioServer.is_bus_mute(0), "som desligado cala o Geral e deixa a fala pedida tocar")
	audio.definir_som_ativo(som_antes)
	_assert(not painel._campo_filtro.visible and painel._botao_editar.visible, "na ficha o filtro some e EDITAR aparece")
	var falas: Array = painel._lista.find_children("Fala*", "HBoxContainer", true, false)
	_assert(falas.size() == 3, "as três falas na ficha")
	for fala: HBoxContainer in falas:
		var texto := fala.get_child(1) as Label
		_assert(texto.max_lines_visible == 2 and texto.get_visible_line_count() <= 2, "fala em até duas linhas")
	_assert(painel._rodape.find_children("Navegacao", "", true, false).size() == 1 and painel._lista.find_children("Navegacao", "", true, false).is_empty(), "só a navegação entre fichas, no rodapé")
	_assert(painel._lista.find_child("FundoPrevia", true, false) != null and painel._preview_viewport.transparent_bg, "prévia sobre o fundo de azulejo")
	var fundo_pedro: Control = painel._lista.find_child("FundoPrevia", true, false)
	var tamanho_previa := fundo_pedro.size
	var linhas_pedro := (painel._lista.find_child("Linhas", true, false) as GridContainer).get_child_count()
	var posicao_falas: float = falas[0].global_position.y
	# O ▶ vira ❚❚ e o segundo clique para a fala.
	var tocar := falas[0].get_child(0) as Button
	if not tocar.disabled:
		tocar.pressed.emit()
		_assert(painel._fala_tocando == tocar and tocar.get_meta("icone").tipo == "pausar", "tocar mostra a pausa")
		tocar.pressed.emit()
		_assert(painel._fala_tocando == null and not painel._voz.playing and tocar.get_meta("icone").tipo == "tocar", "segundo clique para a fala")
	# Girar a prévia com o mouse.
	var giro_antes: float = painel._preview_pivo.rotation.y
	var arrasto := InputEventMouseMotion.new()
	arrasto.button_mask = MOUSE_BUTTON_MASK_LEFT
	arrasto.relative = Vector2(40, 0)
	painel._girar_previa(arrasto)
	_assert(not is_equal_approx(painel._preview_pivo.rotation.y, giro_antes), "arrastar gira o modelo")
	var roda := InputEventMouseButton.new()
	roda.button_index = MOUSE_BUTTON_WHEEL_UP
	roda.pressed = true
	var distancia_antes: float = painel._distancia
	painel._girar_previa(roda)
	_assert(painel._distancia < distancia_antes, "a roda aproxima")
	var mover := InputEventMouseMotion.new()
	mover.button_mask = MOUSE_BUTTON_MASK_RIGHT
	mover.relative = Vector2(30, 10)
	var alvo_antes: Vector3 = painel._alvo
	painel._girar_previa(mover)
	_assert(not painel._alvo.is_equal_approx(alvo_antes), "o botão direito move o enquadramento")
	var duplo := InputEventMouseButton.new()
	duplo.button_index = MOUSE_BUTTON_LEFT
	duplo.pressed = true
	duplo.double_click = true
	painel._girar_previa(duplo)
	_assert(is_equal_approx(painel._distancia, painel._distancia_inicial) and painel._alvo.is_equal_approx(painel._alvo_inicial) and is_zero_approx(painel._preview_pivo.rotation.y), "duplo clique centraliza")
	_assert(painel._rolagem.get_global_rect().encloses(painel._lista.get_global_rect()), "ficha cabe sem rolagem")
	await _capturar("morador")
	var direita := InputEventKey.new()
	direita.keycode = KEY_RIGHT
	direita.pressed = true
	painel._input(direita)
	await _frames(3)
	_assert(painel._lista.get_meta("ficha") == "benedito", "a seta → vai para o Benedito")
	_assert(painel._preview_modelo.name.begins_with("Benedito"), "prévia acompanha o morador")
	# A ficha não muda de forma entre moradores: mesma prévia, mesmas linhas e falas no lugar.
	await _frames(2)
	var fundo_benedito: Control = painel._lista.find_child("FundoPrevia", true, false)
	_assert(fundo_benedito.size.is_equal_approx(tamanho_previa), "a prévia tem o mesmo tamanho para todos")
	_assert((painel._lista.find_child("Linhas", true, false) as GridContainer).get_child_count() == linhas_pedro, "as mesmas linhas para todos")
	var falas_benedito: Array = painel._lista.find_children("Fala*", "HBoxContainer", true, false)
	_assert(falas_benedito.size() == 3 and is_equal_approx(falas_benedito[0].global_position.y, posicao_falas), "as falas ficam no mesmo lugar")
	# Edita o Benedito pelo EDITAR do cabeçalho.
	painel._botao_editar.pressed.emit()
	await _frames(2)
	_assert(painel.editando and painel._icone_editar.tipo == "concluir" and painel._botao_restaurar.visible, "EDITAR vira concluir e mostra RESTAURAR")
	var spins: Array = painel._lista.find_children("*", "SpinBox", true, false)
	var opcoes: Array = painel._lista.find_children("*", "OptionButton", true, false)
	print("PAINEL: %d campos numéricos, %d seletores de lugar" % [spins.size(), opcoes.size()])
	_assert(spins.size() >= 3 and opcoes.size() >= 5, "editor do morador com altura, volume e postos")
	(spins[0] as SpinBox).value = 1.9
	(opcoes[0] as OptionButton).select(1)
	(opcoes[0] as OptionButton).item_selected.emit(1)
	var campos: Array = painel._lista.find_children("*", "LineEdit", true, false)
	var campo_fala: LineEdit = campos[campos.size() - 1]
	campo_fala.text = "Fala de teste."
	campo_fala.text_changed.emit("Fala de teste.")
	var dados = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs_3d.json"))
	var ajustado: Dictionary = {}
	for m in AjustesConteudo.npcs(dados)["moradores"]:
		if m["id"] == "benedito":
			ajustado = m
	print("PAINEL: altura %s · manhã %s · falas %s" % [ajustado.get("altura"), ajustado["postos"]["manha"], ajustado["falas"].map(func(f): return f["texto"])])
	_assert(is_equal_approx(float(ajustado["altura"]), 1.9), "altura ajustada chega aos dados")
	_assert(String(ajustado["postos"]["manha"][0]) != "", "posto ajustado")
	_assert(ajustado["falas"].any(func(f): return f["texto"] == "Fala de teste."), "fala ajustada")
	if painel._botao_gravar != null:
		# O destaque é conferido a cada 0,25 s.
		await create_timer(0.5).timeout
		_assert(painel._icone_gravar.ativo, "GRAVAR fica dourado com ajuste pendente")
		painel.pedir_fechar()
		_assert(is_instance_valid(painel._confirmacao) and not fechou[0], "fechar com ajuste pendente pede confirmação")
		await _capturar("confirmacao")
		painel.pedir_fechar()
		_assert(not is_instance_valid(painel._confirmacao) and not fechou[0], "Esc de novo só cancela a confirmação")
	# ASSETS: os mesmos cartões e a ficha no mesmo formato.
	painel._trocar_aba(1)
	await _frames(3)
	var grade: GridContainer = painel._lista.get_node("GradeAssets")
	var primeiro_cartao := str(grade.get_child(0).name)
	_assert(grade.columns == 4 and grade.get_child_count() == 12, "assets em grade paginada")
	_assert(painel._lista.find_children("*", "SpinBox", true, false).is_empty(), "grade não abre editores")
	_assert(painel._rolagem.get_global_rect().encloses(painel._lista.get_global_rect()), "grade cabe sem rolagem")
	for chave: String in CatalogoAssets.PECAS:
		if str(CatalogoAssets.PECAS[chave].get("tripo", "")).begins_with("personagens/"):
			_assert(not painel._itens().any(func(item: Array) -> bool: return item[0] == chave), "morador fora de ASSETS: %s" % chave)
	await _capturar("assets")
	painel._rodape.find_children("Navegacao", "", true, false)[0].get_child(2).pressed.emit()
	await _frames(3)
	_assert(str(painel._lista.get_node("GradeAssets").get_child(0).name) != primeiro_cartao, "paginação muda os cartões")
	painel._abrir("mangueira")
	await _frames(3)
	_assert(not painel._lista.has_node("GradeAssets") and painel._preview_modelo != null, "cartão abre só o registro e o modelo")
	_assert(painel._lista.get_node("Ficha/Detalhes") != null and painel._lista.get_node("Ficha/FundoPrevia/Previa3D") != null, "ficha da peça no formato da do morador")
	_assert(not painel._campo_filtro.visible, "registro da peça sem filtro")
	await _capturar("registro")
	painel._botao_editar.pressed.emit()
	await _frames(3)
	var campos_peca: Array = painel._lista.find_children("*", "SpinBox", true, false)
	_assert(campos_peca.size() >= 2, "editor da peça selecionada")
	await _capturar("editor")
	var altura_antes := float(AjustesConteudo.peca("mangueira")["altura"])
	campos_peca[0].value = altura_antes + 1.5
	_assert(is_equal_approx(float(AjustesConteudo.peca("mangueira")["altura"]), altura_antes + 1.5), "campo da peça grava ajuste")
	painel._trocar_aba(1)
	await _frames(2)
	_assert(painel._lista.has_node("GradeAssets") and painel.selecionado.is_empty(), "clicar na aba volta aos cartões")
	# Restaurar volta ao padrão do projeto, e sem pendência o × fecha direto.
	var antes := float(CatalogoAssets.PECAS["mangueira"]["altura"])
	AjustesConteudo.restaurar_morador("benedito")
	AjustesConteudo.restaurar_peca("mangueira")
	_assert(not AjustesConteudo.morador_ajustado("benedito"), "morador restaurado")
	_assert(is_equal_approx(float(AjustesConteudo.peca("mangueira")["altura"]), antes), "peça restaurada")
	if not AjustesConteudo.tem_pendencias():
		painel.pedir_fechar()
		_assert(fechou[0], "sem pendência o × fecha")
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
