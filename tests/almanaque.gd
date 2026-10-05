extends SceneTree
## Confere que O ALMANAQUE SE LÊ — a cadeia de índices, e não só as regras dela.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/almanaque.gd
##
## Este portão existe pela lição da barra de mão: quinze testes verdes com a
## barra invisível, porque todos perguntavam "a regra está certa?" e nenhum
## perguntava "o jogador vê?". O almanaque acabou de trocar de forma — era uma
## coluna corrida com as dezoito fichas emendadas, virou índice e página, no
## desenho do diário do Witcher 3 — e tela nova é exatamente onde aquele
## defeito mora.
##
## Sete perguntas, e nenhuma é sobre o dado:
##
##   1. AS QUATRO PEÇAS ESTÃO NA ÁRVORE: o caminho, a cadeia, a página e o
##      rodapé das teclas.
##   2. SEM NADA CONHECIDO ELA NÃO QUEBRA, e diz o que fazer.
##   3. A RAIZ MOSTRA AS QUATRO SEÇÕES, e as plantas descem por grupo. Grupo sem espécie conhecida
##      não aparece — cabeçalho de gaveta vazia é a caça ao item que a silhueta
##      seria.
##   4. A CONTA DE CADA GRUPO ESTÁ NA LINHA ("2 de N", com N lido do dado): é o que responde "falta
##      muito?" sem dizer o que falta.
##   5. ABRIR UM GRUPO ABRE AS ESPÉCIES DELE NO LUGAR, e o caminho escreve onde
##      se está.
##   6. A PÁGINA DA ESPÉCIE TEM O TEXTO DA FICHA, e não só o nome.
##   7. O TECLADO ANDA, ABRE E VOLTA — e a tela cabe dentro da janela, que é a
##      pergunta da barra de mão.
##
##
## O ARQUIVO DO JOGADOR NÃO É TOCADO.
##
## O almanaque guarda as espécies conhecidas em `user://almanaque.cfg`, ao lado
## das preferências. Um portão que chamasse `registrar()` escreveria no arquivo
## de verdade e daria ao jogador plantas que ele não viu. Então aqui o arquivo é
## movido para uma reserva no começo e devolvido no fim — e, se uma rodada
## anterior morreu no meio, a primeira coisa que ele faz é devolver a reserva
## que ficou. É a mesma dança do `tests/salvamento.gd`.

const RESERVA := "user://reserva_do_teste_do_almanaque"

var falhas := 0
var Alm


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("ALMANAQUE_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_guardar_o_arquivo_do_jogador()

	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK,
		"a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(3)

	var jogo := current_scene
	var hud = jogo.get("hud")
	_conferir(hud != null and hud.has_method("almanaque"), "o HUD não expõe o almanaque")
	if hud == null or not hud.has_method("almanaque"):
		_fechar()
		return
	var tela: Control = hud.almanaque()
	_conferir(tela != null, "o HUD não montou o almanaque")
	if tela != null:
		var camada := tela.get_parent() as CanvasLayer
		_conferir(camada != null and camada.layer > hud.layer,
			"o almanaque não tem camada modal acima do HUD e do minimapa")
	if tela == null:
		_fechar()
		return
	Alm = tela.get_script()

	# --- 1. AS QUATRO PEÇAS --------------------------------------------------
	var caminho := _achar(tela, "Caminho") as Label
	var cadeia := _achar(tela, "Cadeia") as VBoxContainer
	var pagina := _achar(tela, "Pagina") as VBoxContainer
	var rodape := _achar(tela, "Rodape") as Label
	_conferir(caminho != null, "não achei o Caminho (o fio de volta) na árvore")
	_conferir(cadeia != null, "não achei a Cadeia (a coluna do índice)")
	_conferir(pagina != null, "não achei a Pagina (a ficha da direita)")
	_conferir(rodape != null, "não achei o Rodape (as teclas)")
	if caminho == null or cadeia == null or pagina == null or rodape == null:
		_fechar()
		return

	# --- 2. AS QUATRO SEÇÕES ESTÃO NA CADEIA ---------------------------------
	#
	# "No próprio almanaque, já considere os cordéis e outros colecionáveis." A
	# raiz da cadeia passou a ser a SEÇÃO — plantas, cordéis, sinais, bichos —, e
	# é ela que faz o caderno ser um só em vez de duas telas em teclas vizinhas.
	Alm._conhecidas.clear()
	tela._secao = ""
	tela._grupo = ""
	tela._escolhido = ""
	tela.abrir()
	await _frames(3)
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://scratch/almanaque")
		root.get_texture().get_image().save_png("res://scratch/almanaque/modal.png")
	var raiz := _textos_de(cadeia)
	_conferir(raiz.size() == 5,
		"a raiz da cadeia mostra %d linha(s) e as seções são cinco: %s" % [raiz.size(), str(raiz)])
	var tudo_raiz := " | ".join(raiz)
	for esperado in ["Plantas", "Cordéis", "Sinais", "Bichos", "Receitas"]:
		_conferir(tudo_raiz.contains(esperado),
			"a seção '%s' não está na raiz da cadeia: %s" % [esperado, tudo_raiz])

	# --- 3. SEM NADA CONHECIDO A TELA NÃO QUEBRA ------------------------------
	tela._escolher_secao(Alm.PLANTAS)
	await _frames(3)
	_conferir(_texto_de(pagina).to_lower().contains("aperte e"),
		"com o almanaque vazio a página das plantas não diz como encher: diz '%s'" % _texto_de(pagina))

	# --- 4. OS GRUPOS DE PLANTA, COM A CONTA ---------------------------------
	#
	# Duas frutíferas e uma da mata: três grupos existem no dado, e só dois
	# podem aparecer. Grupo sem espécie conhecida não aparece — cabeçalho de
	# gaveta vazia é a caça ao item que a silhueta seria.
	Alm._conhecidas.clear()
	for especie in ["mangueira", "jaqueira", "pau_brasil"]:
		_conferir(Alm._fichas.has(especie), "o dado não tem a espécie '%s'" % especie)
		Alm._conhecidas.append(especie)
	tela._secao = Alm.PLANTAS
	tela._grupo = ""
	tela._escolhido = ""
	tela._encher()
	await _frames(2)

	var linhas := " | ".join(_textos_de(cadeia))
	_conferir(linhas.contains("Frutíferas"), "o grupo das frutíferas não está na cadeia: %s" % linhas)
	_conferir(linhas.contains("Mata"), "o grupo da mata não está na cadeia: %s" % linhas)
	_conferir(not linhas.contains("Beira"),
		"um grupo SEM espécie conhecida apareceu na cadeia: %s" % linhas)
	_conferir(not linhas.contains("Mangueira"),
		"a cadeia despejou a espécie com o grupo fechado: %s" % linhas)
	# O total vem do dado: cada fruteira nova que ganha ficha (goiabeira, mamoeiro...) entra na conta.
	var total_de_frutiferas := 0
	for ficha in Alm._fichas.values():
		if String((ficha as Dictionary).get("grupo", "")) == "frutiferas":
			total_de_frutiferas += 1
	_conferir(linhas.contains("2 de %d" % total_de_frutiferas),
		"a conta das frutíferas não está na linha (esperava '2 de %d'): %s" % [total_de_frutiferas, linhas])

	# --- 5. ABRIR O GRUPO ABRE AS ESPÉCIES DELE ------------------------------
	tela._escolher_grupo("frutiferas")
	await _frames(3)
	var abertas := " | ".join(_textos_de(cadeia))
	_conferir(abertas.contains("Mangueira") and abertas.contains("Jaqueira"),
		"abrir as frutíferas não mostrou as espécies dela: %s" % abertas)
	_conferir(not abertas.contains("Pau-brasil"),
		"abrir um grupo mostrou espécie de outro: %s" % abertas)
	_conferir(caminho.text.contains("Almanaque") and caminho.text.contains("Frutíferas"),
		"o caminho não diz onde se está: '%s'" % caminho.text)

	# --- 6. A PÁGINA DA PLANTA -----------------------------------------------
	tela._escolher_item("mangueira")
	await _frames(3)
	var texto := _texto_de(pagina)
	_conferir(texto.contains("Mangueira"), "a página não traz o nome da espécie: '%s'" % texto)
	_conferir(texto.contains("Mangifera indica"),
		"a página não traz o nome científico: '%s'" % texto)
	_conferir(texto.contains("Índia"),
		"a página não traz o texto da ficha, só o cabeçalho: '%s'" % texto)
	_conferir(caminho.text.contains("Mangueira"),
		"o caminho não desceu até a espécie: '%s'" % caminho.text)

	# --- 7. OS CORDÉIS ESTÃO DENTRO, COM VAGA EM BRANCO E COM FICHA ----------
	#
	# "Leve os cordéis para dentro do almanaque também."
	#
	# Aqui a regra é a OPOSTA da das plantas, e as duas estão certas: planta não
	# conhecida não aparece, porque o almanaque é sobre o que se viu; peça de
	# coleção aparece como "— — —", porque é o buraco na estante que faz
	# procurar. É assim no 2D, e é o que separa coleção de inventário.
	var colecao := root.get_node("/root/Colecao")
	var ids: Array = colecao.ordem("cordeis")
	_conferir(not ids.is_empty(), "o vale não tem cordel nenhum no catálogo")
	if ids.is_empty():
		_fechar()
		return

	tela._escolher_secao("cordeis")
	await _frames(3)
	var na_estante := _textos_de(cadeia)
	var so_cordeis := 0
	for linha in na_estante:
		if linha.contains("— — —"):
			so_cordeis += 1
	_conferir(so_cordeis > 0,
		"a seção dos cordéis não mostra vaga em branco: %s" % str(na_estante))
	_conferir(caminho.text.contains("Cordéis"),
		"o caminho não desceu até os cordéis: '%s'" % caminho.text)
	_conferir(caminho.text.contains("de %d" % colecao.total("cordeis")),
		"o caminho não traz a conta dos cordéis: '%s'" % caminho.text)

	# Acha um cordel e confere que a página dele é a do 2D, com título e preço.
	var primeiro := str(ids[0])
	colecao.achar("cordeis", primeiro)
	await _frames(2)
	tela._escolher_item(primeiro)
	await _frames(3)
	var folha := _texto_de(pagina)
	var dados_do_cordel: Dictionary = colecao.dados("cordeis", primeiro)
	_conferir(folha.contains(str(dados_do_cordel.get("titulo", ""))),
		"a página do cordel achado não traz o título dele: '%s'" % folha)
	_conferir(folha.contains("réis"),
		"a página do cordel não traz o quanto ele vale, como no 2D: '%s'" % folha)

	# --- 8. E OS SINAIS E OS BICHOS TAMBÉM ------------------------------------
	for secao in ["sinais", "bichos"]:
		tela._escolher_secao(secao)
		await _frames(3)
		_conferir(not _textos_de(cadeia).is_empty(),
			"a seção '%s' abriu vazia: o Colecao tem %d peça(s)"
				% [secao, colecao.total(secao)])
		_conferir(caminho.text.to_lower().contains(secao.substr(0, 5)),
			"o caminho não desceu até '%s': '%s'" % [secao, caminho.text])

	# --- 8b. AS RECEITAS DE COZINHA ESTÃO DENTRO --------------------------------
	#
	# "Aproveite para inserir no Almanaque as Receitas de Cozinhar."
	#
	# A regra de quem sabe o quê é do `Receitas` compartilhado com o 2D, e as
	# receitas em si são do `Cozinha`. O que se mede aqui é a seção: a lista
	# mostra as vagas, a receita sabida abre a ficha com o que leva e o que
	# rende, e a NÃO sabida diz COMO SE APRENDE — que é a informação útil de uma
	# vaga em branco, e não o segredo dela.
	var receitas := root.get_node("/root/Receitas")
	var cozinha := root.get_node("/root/Cozinha")
	var ids_receita: Array = cozinha.RECEITAS.keys()
	_conferir(not ids_receita.is_empty(), "o vale não tem receita nenhuma de panela")
	if not ids_receita.is_empty():
		ids_receita.sort()
		tela._escolher_secao("receitas")
		await _frames(3)
		var na_lista := _textos_de(cadeia)
		_conferir(na_lista.size() >= ids_receita.size(),
			"a seção das receitas mostra %d linha(s) e há %d receitas de panela"
				% [na_lista.size(), ids_receita.size()])

		# Uma que NÃO se sabe: a ficha ensina o caminho, e não a receita.
		var nao_sabida := ""
		for bruto in ids_receita:
			if not receitas.sabe(str(bruto)):
				nao_sabida = str(bruto)
				break
		if nao_sabida != "":
			tela._escolher_item(nao_sabida)
			await _frames(3)
			var fechada := _texto_de(pagina).to_lower()
			_conferir(fechada.contains("ainda não sabe"),
				"a receita não sabida não diz que não se sabe: '%s'" % fechada)
			var resumo := str(cozinha.RECEITAS[nao_sabida].get("resumo", "")).to_lower()
			if resumo.length() > 12:
				_conferir(not fechada.contains(resumo.substr(0, 20)),
					"a receita não sabida já entregou o que ela faz: o almanaque virou livro de receitas")

		# Uma que se sabe: a ficha traz o que leva e o que rende.
		var sabida := ""
		for bruto in ids_receita:
			if receitas.sabe(str(bruto)):
				sabida = str(bruto)
				break
		if sabida == "":
			receitas.aprender(str(ids_receita[0]), "portao")
			await _frames(2)
			sabida = str(ids_receita[0])
		tela._encher()
		tela._escolher_item(sabida)
		await _frames(3)
		var aberta_r := _texto_de(pagina).to_lower()
		_conferir(aberta_r.contains("leva:") or aberta_r.contains("rende"),
			"a receita sabida não diz o que leva nem o que rende: '%s'" % aberta_r)
		_conferir(caminho.text.contains("Receitas"),
			"o caminho não desceu até as receitas: '%s'" % caminho.text)

	# --- 9. O TECLADO, E A TELA DENTRO DA JANELA -----------------------------
	tela._escolher_secao(Alm.PLANTAS)
	tela._escolher_grupo("frutiferas")
	tela._escolher_item("mangueira")
	await _frames(2)
	var onde: int = tela._cursor
	tela._andar(1)
	_conferir(tela._cursor != onde, "a seta para baixo não andou na cadeia")
	tela._voltar()
	await _frames(2)
	_conferir(tela._escolhido == "" and tela._grupo == "frutiferas",
		"voltar da ficha devia parar no grupo, e parou em grupo='%s' peça='%s'"
			% [tela._grupo, tela._escolhido])
	tela._voltar()
	await _frames(2)
	_conferir(tela._grupo == "", "voltar do grupo devia chegar à seção, e ficou em '%s'" % tela._grupo)
	tela._voltar()
	await _frames(2)
	_conferir(tela._secao == "", "voltar da seção devia chegar à raiz, e ficou em '%s'" % tela._secao)

	_conferir(rodape.text.to_lower().contains("fechar"),
		"o rodapé não diz como fechar: '%s'" % rodape.text)

	# A PERGUNTA DA BARRA DE MÃO: o jogador vê? Painel fora da janela é painel
	# que existe e não aparece, e foi assim que a barra passou por quinze testes.
	var retabulo := _achar(tela, "Retabulo") as Control
	_conferir(retabulo != null, "não achei o painel do almanaque")
	if retabulo != null:
		var janela: Vector2 = tela.get_viewport_rect().size
		var caixa := retabulo.get_global_rect()
		_conferir(caixa.size.x > 300.0 and caixa.size.y > 200.0,
			"o painel tem %s: pequeno demais para índice e página" % str(caixa.size))
		_conferir(caixa.position.x >= -1.0 and caixa.position.y >= -1.0
				and caixa.end.x <= janela.x + 1.0 and caixa.end.y <= janela.y + 1.0,
			"o painel está fora da janela: %s numa tela de %s" % [str(caixa), str(janela)])

	# --- 10. REABRIR VOLTA ONDE O JOGADOR PAROU ------------------------------
	tela._escolher_secao(Alm.PLANTAS)
	tela._escolher_item("jaqueira")
	await _frames(2)
	tela.fechar()
	await _frames(2)
	tela.abrir()
	await _frames(3)
	_conferir(tela._escolhido == "jaqueira",
		"reabrir o almanaque perdeu a página aberta: ficou em '%s'" % tela._escolhido)
	tela.fechar()

	_fechar()


## Todo o texto de um ramo, junto — é o que o jogador leria na tela.
func _texto_de(no: Node) -> String:
	var partes: Array[String] = []
	for filho in no.get_children():
		if filho is Label:
			partes.append((filho as Label).text)
		elif filho is Button:
			partes.append((filho as Button).text)
		if filho.get_child_count() > 0:
			partes.append(_texto_de(filho))
	return " ".join(partes)


## Uma linha por filho direto, para contar linhas da cadeia.
func _textos_de(no: Node) -> Array[String]:
	var lista: Array[String] = []
	for filho in no.get_children():
		if filho is Button:
			lista.append((filho as Button).text.strip_edges())
		elif filho is Label:
			lista.append((filho as Label).text.strip_edges())
	return lista


func _achar(raiz: Node, nome: String) -> Node:
	for no in raiz.find_children(nome, "", true, false):
		return no
	return null


## O `almanaque.cfg` de verdade sai da frente e volta no fim. Reserva que ficou
## de uma rodada morta é devolvida antes de qualquer coisa.
func _guardar_o_arquivo_do_jogador() -> void:
	_devolver_o_arquivo_do_jogador()
	if FileAccess.file_exists("user://almanaque.cfg"):
		var erro := DirAccess.rename_absolute(
			ProjectSettings.globalize_path("user://almanaque.cfg"),
			ProjectSettings.globalize_path(RESERVA))
		if erro != OK:
			push_warning("Almanaque (portão): não consegui pôr o arquivo do jogador a salvo.")


func _devolver_o_arquivo_do_jogador() -> void:
	if not FileAccess.file_exists(RESERVA):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://almanaque.cfg"))
	DirAccess.rename_absolute(
		ProjectSettings.globalize_path(RESERVA),
		ProjectSettings.globalize_path("user://almanaque.cfg"))


func _fechar() -> void:
	_devolver_o_arquivo_do_jogador()
	print("")
	if falhas == 0:
		print("ALMANAQUE_OK: a raiz tem as cinco seções; as plantas descem por grupo com a conta e sem grupo vazio; cordéis, sinais e bichos estão dentro com a vaga em branco e a ficha do 2D; as receitas de panela mostram o que levam quando sabidas e COMO SE APRENDEM quando não; o caminho escreve onde se está, o teclado anda e volta elo por elo, o painel cabe na janela, e reabrir devolve a página aberta")
	else:
		print("almanaque: %d falha(s)" % falhas)
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
