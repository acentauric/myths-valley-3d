extends SceneTree
## Confere A TEIA SOCIAL do vale — a tela, não o sistema.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/teia_social.gd
##
## O SISTEMA JÁ TEM PORTÃO: o `tests/fe.gd` daqui confere os sete moradores com
## gosto e desgosto lidos do `aldeoes.json`, e o `testar_afinidade.gd` do 2D
## cobra os graus e as falas de reação. `Afinidade` é o mesmo arquivo nos dois
## jogos — repetir a pergunta é ter duas versões dela.
##
## O que este portão pergunta é o que é DA TELA:
##
##   1. ELA ESTÁ NO P, que é a tecla do arraial no 2D ("aperte P e veja quem é
##      quem no arraial", do tutorial de lá).
##   2. OS SETE MORADORES APARECEM, cada um com o nome e o grau escritos.
##   3. CADA UM TEM BARRA, e ela acompanha o número do `Afinidade`. A barra está
##      na linha porque a pergunta que se faz ao abrir é comparativa — de quem
##      eu estou mais perto? —, e isso se responde de relance.
##   4. O GOSTO SÓ APARECE DE "GENTE BOA" PARA CIMA, e esta é a pergunta que
##      importa. A regra é do 2D, com a razão escrita lá: o que alguém gosta de
##      ganhar se descobre convivendo, e mostrar tudo no primeiro dia
##      transformaria o arraial numa lista de compras. Abaixo do grau a tela diz
##      O QUE FAZER, e não o que está escondido.
##   5. O QUE HÁ PARA FAZER HOJE é dito como TAREFA e não como estado — também
##      do 2D: "ainda dá para conversar hoje" é convite para fechar a tela e ir
##      até lá.
##   6. A TELA CABE NA JANELA — a pergunta da barra de mão.
##
## OS PONTOS DE AFINIDADE SÃO DEVOLVIDOS no fim: este portão mexe neles para
## construir as duas situações, e afinidade é estado de partida.

var falhas := 0
var _guardados: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("SOCIAL_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK,
		"a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(3)

	var jogo := current_scene
	var afinidade := root.get_node("/root/Afinidade")
	var social = jogo.get("social")
	_conferir(social != null, "o vale não montou a teia social")
	if social == null:
		_fechar()
		return
	_guardados = (afinidade.pontos as Dictionary).duplicate(true)

	# --- 1. NA TECLA CERTA ----------------------------------------------------
	var Atalhos = load("res://scripts/prototipo_3d/atalhos.gd")
	_conferir(Atalhos.tecla("arraial") == KEY_P,
		"a teia social não está no P, que é a tecla do arraial no 2D")

	jogo.telas.abrir("arraial")
	await _frames(3)
	_conferir(social.aberta, "pedir a teia social não abriu nada")
	_conferir(paused, "a teia social abriu com o vale andando atrás dela")

	var coluna := _achar(social, "Moradores") as VBoxContainer
	var pagina := _achar(social, "Pagina") as VBoxContainer
	_conferir(coluna != null and pagina != null, "a teia social não tem a coluna e a página")
	if coluna == null or pagina == null:
		_fechar()
		return

	# --- 2. OS SETE MORADORES, COM NOME E GRAU -------------------------------
	var na_coluna := _texto_de(coluna)
	print("")
	for bruto in afinidade.MORADORES:
		var id := str(bruto)
		_conferir(na_coluna.contains(afinidade.nome_de(id)),
			"o morador '%s' não aparece na coluna: %s" % [afinidade.nome_de(id), na_coluna])
		_conferir(na_coluna.contains(afinidade.nome_do_grau(id)),
			"o grau de '%s' não está escrito na linha dele" % afinidade.nome_de(id))

	# --- 3. A BARRA ACOMPANHA O NÚMERO ---------------------------------------
	var primeiro := str(afinidade.MORADORES[0])
	afinidade.pontos[primeiro] = 45
	social._encher()
	await _frames(2)
	var barra: ProgressBar = null
	for filho in coluna.get_children():
		if filho is ProgressBar and str(filho.name) == "Barra_" + primeiro:
			barra = filho as ProgressBar
	_conferir(barra != null, "o morador '%s' não tem barra na linha; a coluna tem: %s"
		% [primeiro, str(coluna.get_children())])
	if barra != null:
		_conferir(is_equal_approx(barra.value, 45.0),
			"a barra de '%s' marca %.0f e a afinidade é 45" % [primeiro, barra.value])
		_conferir(is_equal_approx(barra.max_value, float(afinidade.MAXIMO)),
			"a barra de '%s' vai até %.0f e o teto é %d" % [primeiro, barra.max_value, afinidade.MAXIMO])

	# --- 4. O GOSTO SÓ DE "GENTE BOA" PARA CIMA ------------------------------
	#
	# É a pergunta que importa desta tela. Duas situações, o mesmo morador.
	var dele: Dictionary = root.get_node("/root/Jogo").dados(afinidade.ARQUIVO_DOS_MORADORES).get(primeiro, {})
	var gosta: Array = dele.get("gosta", [])
	_conferir(not gosta.is_empty(),
		"o morador '%s' não tem gosto no aldeoes.json: a pergunta não valeria nada" % primeiro)
	if not gosta.is_empty():
		# `Catalogo` é `class_name`, e não autoload: não há /root/Catalogo. Em
		# script de SceneTree o caminho seguro é carregar o arquivo e chamar o
		# estático — foi assim que este portão travou em vez de reprovar, pela
		# armadilha de sempre (erro aborta o `_run` antes do `quit`).
		var catalogo = load("res://scripts/compartilhado/catalogo.gd")
		var alguma := str(catalogo.nome(str(gosta[0]))).to_lower()

		# DESCONHECIDO: não mostra, e diz o que fazer.
		afinidade.pontos[primeiro] = 0
		social._quem = primeiro
		social._encher()
		await _frames(2)
		_conferir(afinidade.grau(primeiro) < social.GRAU_DO_GOSTO,
			"com zero ponto o morador já passou do grau do gosto: a situação não foi montada")
		var fechada := _texto_de(pagina).to_lower()
		_conferir(not fechada.contains(alguma),
			"com o morador desconhecido a tela já entregou o gosto dele ('%s'): o arraial virou lista de compras"
				% alguma)
		_conferir(fechada.contains("para saber do que ele gosta"),
			"a tela não diz o que fazer para descobrir o gosto: '%s'" % fechada)

		# GENTE BOA: mostra.
		afinidade.pontos[primeiro] = 35
		social._encher()
		await _frames(2)
		_conferir(afinidade.grau(primeiro) >= social.GRAU_DO_GOSTO,
			"com 35 pontos o morador ainda não chegou ao grau do gosto")
		var aberta_agora := _texto_de(pagina).to_lower()
		_conferir(aberta_agora.contains(alguma),
			"de 'Gente boa' para cima a tela não mostra o gosto ('%s'): '%s'" % [alguma, aberta_agora])
		print("  gosto: escondido de desconhecido, aberto de Gente boa para cima")

	# --- 5. O QUE FAZER HOJE, DITO COMO TAREFA -------------------------------
	var hoje := _texto_de(pagina).to_lower()
	_conferir(hoje.contains("conversar hoje") or hoje.contains("conversaram hoje"),
		"a página não diz se ainda dá para conversar hoje: '%s'" % hoje)
	_conferir(hoje.contains("dar alguma coisa hoje") or hoje.contains("ganhou alguma coisa hoje"),
		"a página não diz se ainda dá para dar alguma coisa hoje: '%s'" % hoje)

	# --- 6. CABE NA JANELA ---------------------------------------------------
	var caixa := _achar(social, "Caixa") as Control
	_conferir(caixa != null, "não achei a caixa da teia social")
	if caixa != null:
		var quadro := caixa.get_global_rect()
		var janela: Vector2 = caixa.get_viewport_rect().size
		_conferir(quadro.position.x >= -1.0 and quadro.position.y >= -1.0
				and quadro.end.x <= janela.x + 1.0 and quadro.end.y <= janela.y + 1.0,
			"a teia social está fora da janela: %s numa tela de %s" % [str(quadro), str(janela)])

	# O teclado anda pelos sete.
	var antes: String = social._quem
	social._andar(1)
	await _frames(2)
	_conferir(social._quem != antes, "a seta para baixo não andou pelos moradores")

	jogo.telas.fechar_tudo()
	await _frames(2)
	_conferir(not social.aberta, "fechar tudo deixou a teia social aberta")
	_conferir(not paused, "fechar a teia social deixou o vale parado")

	_fechar()


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


func _achar(raiz: Node, nome: String) -> Node:
	for no in raiz.find_children(nome, "", true, false):
		return no
	return null


## Devolve a afinidade como estava: este portão mexeu nela para montar as duas
## situações, e afinidade é estado de partida.
func _devolver() -> void:
	var afinidade := root.get_node_or_null("/root/Afinidade")
	if afinidade == null or _guardados.is_empty():
		return
	for quem in _guardados:
		afinidade.pontos[quem] = _guardados[quem]


func _fechar() -> void:
	_devolver()
	print("")
	if falhas == 0:
		print("SOCIAL_OK: a teia está no P, os sete moradores aparecem com nome, grau e barra que acompanha o número, o gosto fica escondido de quem é desconhecido e aparece de Gente boa para cima, o que há para fazer hoje é dito como tarefa, e a tela cabe na janela")
	else:
		print("teia social: %d falha(s)" % falhas)
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
