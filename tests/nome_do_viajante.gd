extends SceneTree
var falhas := 0

func _initialize() -> void:
	_run.call_deferred()

func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: " + texto)

func quadros(n := 4) -> void:
	for i in n: await process_frame

func _run() -> void:
	var jogo := root.get_node("Jogo")
	var partida := root.get_node("Partida")
	var salvamento := root.get_node("Salvamento")
	var idioma = load("res://scripts/prototipo_3d/idioma_menu.gd")
	change_scene_to_file("res://scenes/prototipo_3d/abertura.tscn")
	await quadros(8)
	var menu = current_scene
	var textos: Dictionary = jogo.dados("res://data/nome_jogador.json")
	for lingua in [0, 1, 2]:
		idioma.definir(lingua)
		menu._ao_tocar_a_vaga(1, false)
		await quadros()
		var campo := menu.content.get_node_or_null("NomeJogador") as LineEdit
		conferir(campo != null, "vaga nova não pede o nome")
		if campo == null: continue
		conferir(campo.placeholder_text == str(idioma.campo(textos, "campo")), "campo não acompanha o idioma")
		# #214: a ajuda é texto de leitura no tamanho do corpo, cabe em duas linhas e o modal abraça o conteúdo.
		var ajuda := menu.content.get_node_or_null("AjudaNome") as Label
		var erro := menu.content.get_node_or_null("ErroNome") as Label
		conferir(ajuda != null and erro != null, "o modal do nome perdeu a ajuda ou o aviso de erro (idioma %d)" % lingua)
		if ajuda != null and erro != null:
			var tam_ajuda := ajuda.get_theme_font_size("font_size")
			var tam_erro := erro.get_theme_font_size("font_size")
			conferir(tam_ajuda >= 17, "a ajuda do nome está pequena (%d px) perto do título e do campo (idioma %d)" % [tam_ajuda, lingua])
			conferir(tam_erro < tam_ajuda and tam_erro >= 15, "o aviso de erro (%d px) não acompanha a ajuda (%d px) (idioma %d)" % [tam_erro, tam_ajuda, lingua])
			conferir(ajuda.get_line_count() <= 2, "a ajuda do nome quebrou em %d linhas (idioma %d)" % [ajuda.get_line_count(), lingua])
			var sobra: float = menu.panel.size.y - menu.panel.get_combined_minimum_size().y
			conferir(sobra <= 2.0, "sobram %.0f px vazios no modal do nome (idioma %d)" % [sobra, lingua])
		var slot_antes: int = salvamento.slot_atual
		var nome_antes: String = jogo.nome_jogador
		campo.text = "   "
		campo.text_submitted.emit(campo.text)
		await quadros()
		conferir(salvamento.slot_atual == slot_antes and jogo.nome_jogador == nome_antes, "nome vazio iniciou partida")
		menu._vagas()
		await quadros()
		conferir(jogo.nome_jogador == nome_antes, "cancelar mudou o jogador")
	idioma.definir(0)
	menu._ao_tocar_a_vaga(1, false)
	await quadros()
	var campo := menu.content.get_node_or_null("NomeJogador") as LineEdit
	if campo != null:
		campo.text = "  José da Silva  "
		campo.text_submitted.emit(campo.text)
		await quadros()
		conferir(jogo.nome_jogador == "José da Silva" and salvamento.slot_atual == 1, "confirmação não aplica nome limpo à vaga")
		conferir(partida.salvar(), "a partida nomeada não grava")
		conferir(str(salvamento.ler(1).get("Jogo", {}).get("nome_jogador", "")) == "José da Silva", "o save perdeu o nome")
		jogo.nome_jogador = "Outro"
		salvamento.carregar(salvamento.ler(1))
		conferir(jogo.nome_jogador == "José da Silva", "retomar perdeu o nome")
		menu.lines = ["Bem-vindo, {jogador}."]
		menu.line_index = -1
		menu._next_line()
		conferir(menu.caption.text == "Bem-vindo, José da Silva.", "a travessia deixa o marcador literal")
		root.get_node("Audio").parar_narracao()
		var dialogo := root.get_node("Dialogo")
		dialogo.falar("Pedro", ["Chegue, {jogador}."])
		await quadros()
		conferir(dialogo._falas == ["Chegue, José da Silva."], "a caixa não substitui o nome")
		dialogo.calar()
		if "--capturar" in OS.get_cmdline_user_args():
			menu._pedir_nome(2)
			await quadros()
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://scratch/nome-do-viajante")
			root.get_texture().get_image().save_png("res://scratch/nome-do-viajante/nome.png")
	print("NOME_DO_VIAJANTE: %d falha(s)" % falhas)
	quit(1 if falhas else 0)
