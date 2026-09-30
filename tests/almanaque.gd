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
##   3. A CADEIA MOSTRA GRUPO, E NÃO DEZOITO NOMES. Grupo sem espécie conhecida
##      não aparece — cabeçalho de gaveta vazia é a caça ao item que a silhueta
##      seria.
##   4. A CONTA DE CADA GRUPO ESTÁ NA LINHA ("2 de 6"): é o que responde "falta
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

	# --- 2. SEM NADA CONHECIDO ------------------------------------------------
	Alm._conhecidas.clear()
	tela._grupo = ""
	tela._especie = ""
	tela.abrir()
	await _frames(3)
	_conferir(_texto_de(pagina).to_lower().contains("aperte e"),
		"com o almanaque vazio a página não diz como encher: diz '%s'" % _texto_de(pagina))
	_conferir(cadeia.get_child_count() == 0,
		"com o almanaque vazio a cadeia tem %d linha(s)" % cadeia.get_child_count())
	tela.fechar()
	await _frames(2)

	# --- 3 e 4. A CADEIA MOSTRA GRUPO, COM A CONTA ---------------------------
	#
	# Duas frutíferas e uma da mata: três grupos existem no dado, e só dois
	# podem aparecer.
	Alm._conhecidas.clear()
	for especie in ["mangueira", "jaqueira", "pau_brasil"]:
		_conferir(Alm._fichas.has(especie), "o dado não tem a espécie '%s'" % especie)
		Alm._conhecidas.append(especie)
	tela._grupo = ""
	tela._especie = ""
	tela.abrir()
	await _frames(3)

	var linhas := _textos_de(cadeia)
	_conferir(linhas.size() == 2,
		"a cadeia mostra %d linha(s) e devia mostrar dois grupos: %s" % [linhas.size(), str(linhas)])
	var tudo := " | ".join(linhas)
	_conferir(tudo.contains("Frutíferas"), "o grupo das frutíferas não está na cadeia: %s" % tudo)
	_conferir(tudo.contains("Mata"), "o grupo da mata não está na cadeia: %s" % tudo)
	_conferir(not tudo.contains("Beira"),
		"um grupo SEM espécie conhecida apareceu na cadeia: %s" % tudo)
	_conferir(not tudo.contains("Mangueira"),
		"a cadeia despejou a espécie com o grupo fechado: %s" % tudo)
	_conferir(tudo.contains("2 de 6"),
		"a conta das frutíferas não está na linha (esperava '2 de 6'): %s" % tudo)

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
	_conferir(caminho.text.contains("3 de %d" % Alm.total()),
		"o caminho não traz a conta geral: '%s'" % caminho.text)

	# --- 6. A PÁGINA DA ESPÉCIE ----------------------------------------------
	tela._escolher_especie("mangueira")
	await _frames(3)
	var texto := _texto_de(pagina)
	_conferir(texto.contains("Mangueira"), "a página não traz o nome da espécie: '%s'" % texto)
	_conferir(texto.contains("Mangifera indica"),
		"a página não traz o nome científico: '%s'" % texto)
	_conferir(texto.contains("Índia"),
		"a página não traz o texto da ficha, só o cabeçalho: '%s'" % texto)
	_conferir(caminho.text.contains("Mangueira"),
		"o caminho não desceu até a espécie: '%s'" % caminho.text)

	# --- 7. O TECLADO, E A TELA DENTRO DA JANELA -----------------------------
	var onde: int = tela._cursor
	tela._andar(1)
	_conferir(tela._cursor != onde, "a seta para baixo não andou na cadeia")
	tela._voltar()
	await _frames(2)
	_conferir(tela._especie == "" and tela._grupo == "frutiferas",
		"voltar da ficha devia parar no grupo, e parou em grupo='%s' especie='%s'"
			% [tela._grupo, tela._especie])
	tela._voltar()
	await _frames(2)
	_conferir(tela._grupo == "", "voltar do grupo devia chegar à raiz, e ficou em '%s'" % tela._grupo)

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

	# --- 8. REABRIR VOLTA ONDE O JOGADOR PAROU -------------------------------
	tela._escolher_especie("jaqueira")
	await _frames(2)
	tela.fechar()
	await _frames(2)
	tela.abrir()
	await _frames(3)
	_conferir(tela._especie == "jaqueira",
		"reabrir o almanaque perdeu a ficha aberta: ficou em '%s'" % tela._especie)
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
		print("ALMANAQUE_OK: o índice mostra grupo com a conta e não dezoito nomes, grupo vazio não aparece, abrir um grupo abre as espécies dele no lugar, o caminho escreve onde se está, a página traz a ficha inteira, o teclado anda e volta, o painel cabe na janela, e reabrir devolve a ficha aberta")
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
