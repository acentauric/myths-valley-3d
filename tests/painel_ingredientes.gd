extends SceneTree
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: " + texto)
func rodar() -> void:
	await process_frame
	root.size = Vector2i(1440, 900)
	var inventario := root.get_node("Inventario")
	var receitas := root.get_node("Receitas")
	var energia := root.get_node("Energia")
	for i in inventario.espacos.size(): inventario.espacos[i] = {}
	inventario.adicionar("lenha", 2)
	inventario.adicionar("pedra", 1)
	energia.atual = 100
	receitas.aprender("tabua", "teste")
	receitas.aprender("corda", "teste")
	receitas.aprender("facao", "teste")
	var painel = load("res://scripts/prototipo_3d/painel_vale.gd").new()
	root.add_child(painel)
	painel.obra_em_foco = "oficina"
	painel.abrir(painel.Aba.OFICINA)
	for j in 5: await process_frame
	var lista: Array = painel._lista_atual()
	for i in lista.size():
		var botao: Button = painel._escolhiveis[i]
		conferir(botao.icon != null, "receita possui ícone: " + str(lista[i]))
		var faixa := botao.get_node_or_null("Ingredientes")
		if "--sem-ingredientes" in OS.get_cmdline_user_args() and faixa != null:
			botao.remove_child(faixa)
			faixa.free()
			faixa = null
		conferir(faixa != null, "custo na própria linha: " + str(lista[i]))
		if faixa == null: continue
		conferir(botao.get_global_rect().encloses(faixa.get_global_rect()), "custo cabe na linha")
		conferir(faixa.mouse_filter == Control.MOUSE_FILTER_IGNORE, "ingredientes deixam clicar na receita")
		var lenha: Control = faixa.get_node("lenha")
		var pedido := int(lenha.get_meta("pedido"))
		conferir(bool(lenha.get_meta("suficiente")) == (pedido <= 2), "custo acende por ingrediente, não por receita")
	# O ícone da aba é o do item, ou o distintivo próprio dela (Obras, Saveiro: #108).
	for aba: Button in painel._abas_coluna.get_children():
		conferir(aba.icon != null or not aba.find_children("Icone_*", "TextureRect", false, false).is_empty(), "abas têm ícones")
	var indice: int = lista.find("tabua")
	painel.escolher(indice)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for j in 5: await process_frame
	var clique := InputEventMouseButton.new()
	clique.button_index = MOUSE_BUTTON_LEFT
	clique.position = painel._escolhiveis[indice].get_node("Ingredientes").get_global_rect().get_center() if not "--sem-ingredientes" in OS.get_cmdline_user_args() else painel._escolhiveis[indice].get_global_rect().get_center()
	clique.pressed = true
	clique.global_position = clique.position
	root.push_input(clique, true)
	await process_frame
	clique = clique.duplicate()
	clique.pressed = false
	root.push_input(clique, true)
	for j in 3: await process_frame
	conferir(inventario.quantidade("tabua") == 1, "clicar no custo confirma a receita selecionada")
	if inventario.quantidade("tabua") != 1: print("retorno=", painel._aviso, " dica=", painel._dica.text, " cursor=", painel._cursor, " pos=", clique.position)
	conferir(inventario.quantidade("lenha") == 0, "consumo é o custo da regra")
	var cartas := root.get_node("Cartas")
	for id: String in cartas.tudo(): cartas.aprender(id)
	for id: String in receitas.tudo(): receitas.aprender(id, "teste")
	painel.na_cozinha = true
	painel.na_venda = true
	for aba: int in [painel.Aba.OFICINA, painel.Aba.COZINHA, painel.Aba.CARTAS, painel.Aba.OBRAS, painel.Aba.VENDA, painel.Aba.AJUSTES, painel.Aba.VAGAS]:
		painel._aba = aba
		painel._cursor = 0
		painel._redesenhar()
		for j in 5: await process_frame
		for botao: Control in painel._escolhiveis:
			if not botao is Button: continue # Campos numéricos do Jogo.
			conferir(botao.icon != null, "ícone em todas as abas suportadas")
			var faixa := botao.get_node_or_null("Ingredientes")
			if faixa != null: conferir(botao.get_global_rect().encloses(faixa.get_global_rect()), "custos e tecla cabem em cada aba")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://scratch/painel-ingredientes")
			root.get_texture().get_image().save_png("res://scratch/painel-ingredientes/aba-%d.png" % aba)
	painel.fechar()
	painel.queue_free()
	for j in 3: await process_frame
	print("PAINEL_INGREDIENTES: %d falhas" % falhas)
	quit(0 if falhas == 0 else 1)
