extends SceneTree
## Confere que A BARRA DE MÃO APARECE — e não só que ela existe.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/barra_de_mao.gd
##
## Este teste nasceu de um defeito que passou por quinze testes verdes: a barra
## estava criada, ligada e correta em lógica, e NÃO DESENHAVA. A causa era
## layout — `PRESET_BOTTOM_WIDE` num nó recém-criado, cujos offsets saem de um
## tamanho que ainda é zero, e `position` escrito antes das âncoras, que as
## âncoras recalculam em seguida.
##
## A lição está no que ele mede. Os outros testes perguntam "a regra está
## certa?"; este pergunta "o jogador vê?". São perguntas diferentes, e a
## primeira passando não responde a segunda.
##
## Cinco perguntas:
##
##   1. A BARRA EXISTE na árvore do HUD.
##   2. ELA TEM TAMANHO. Control de altura zero é Control invisível, e foi
##      exatamente o defeito.
##   3. OS DEZ ESPAÇOS ESTÃO LÁ, um por espaço de mão do `Inventario`.
##   4. ELA ESTÁ NO RODAPÉ E NO MEIO, dentro da tela — não fora dela, que é o
##      outro jeito de um Control existir sem aparecer.
##   5. O QUE ENTRA NA MOCHILA APARECE NELA, e o que está na mão se destaca.

var falhas := 0
var Inv: Node = null


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("BARRA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK,
		"a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	# Dois quadros a mais: o layout dos Control só se acomoda depois de o
	# contêiner medir os filhos.
	await _frames(3)
	Inv = root.get_node("/root/Inventario")

	# --- 1. A BARRA EXISTE ----------------------------------------------------
	var barra: Control = null
	for no in current_scene.find_children("BarraDeMao", "", true, false):
		barra = no as Control
		break
	_conferir(barra != null, "não achei a BarraDeMao na árvore do HUD")
	if barra == null:
		_fechar()
		return

	# --- 2. ELA TEM TAMANHO ---------------------------------------------------
	var fila := barra.get_node_or_null("Fila") as Control
	_conferir(fila != null, "a barra não tem a Fila dos espaços")
	if fila == null:
		_fechar()
		return
	_conferir(fila.size.x > 100.0,
		"a fila tem %s de largura: estreita demais para dez espaços" % str(fila.size.x))
	_conferir(fila.size.y > 20.0,
		"a fila tem %s de altura: Control de altura zero não aparece" % str(fila.size.y))

	# --- 3. OS DEZ ESPAÇOS ----------------------------------------------------
	var paineis := 0
	for filho in fila.get_children():
		if filho is Panel:
			paineis += 1
	_conferir(paineis == Inv.ESPACOS_MAO,
		"a barra tem %d espaço(s) e a mão tem %d" % [paineis, Inv.ESPACOS_MAO])

	# --- 4. NO RODAPÉ E DENTRO DA TELA ---------------------------------------
	var tela: Vector2 = barra.get_viewport_rect().size
	var canto := fila.global_position
	_conferir(canto.x >= 0.0 and canto.x + fila.size.x <= tela.x + 1.0,
		"a fila está fora da tela na horizontal: x=%s largura=%s tela=%s"
			% [str(canto.x), str(fila.size.x), str(tela.x)])
	_conferir(canto.y > tela.y * 0.6 and canto.y + fila.size.y <= tela.y + 1.0,
		"a fila não está no rodapé: y=%s tela=%s" % [str(canto.y), str(tela.y)])

	# --- 5. O QUE ENTRA APARECE ----------------------------------------------
	Inv.adicionar("machado", 1)
	Inv.selecionar(0)
	await _frames(2)

	var primeiro := fila.get_child(0) as Panel
	var conteudo := primeiro.get_node_or_null("Conteudo") as Label
	var icone := primeiro.get_node_or_null("Icone") as TextureRect
	_conferir(conteudo != null and icone != null, "o espaço não tem rótulo nem ícone")
	if conteudo != null and icone != null:
		# Com ícone ou sem, alguma coisa tem de aparecer: a arte de 32px é do 2D
		# e ainda não veio para cá, e aí a inicial do item faz as vezes dela.
		_conferir(icone.texture != null or conteudo.text != "",
			"o machado entrou na mochila e o espaço ficou vazio na tela")

	var na_mao := barra.get_node_or_null("NaMao") as Label
	_conferir(na_mao != null, "não há rótulo do que está na mão")
	if na_mao != null:
		_conferir(na_mao.text.to_lower().contains("machado"),
			"a mão diz '%s' com o machado selecionado" % na_mao.text)

	# --- 6. O AVISO NÃO FICA ATRÁS DELA --------------------------------------
	#
	# A barra entra por último no HUD, então desenha por cima de tudo que não
	# seja tela cheia — inclusive do aviso de interação, que morava no mesmo
	# pedaço do rodapé. "O registro de iterações está ficando atrás da barra",
	# nas palavras de quem jogou.
	#
	# Mede RETÂNGULO CONTRA RETÂNGULO, e não a diferença de dois números: é o
	# que continua valendo se um dos dois mudar de tamanho.
	var aviso: Control = null
	for no in current_scene.find_children("Aviso", "", true, false):
		aviso = no as Control
		break
	_conferir(aviso != null, "não achei o painel do aviso, que se chama Aviso")
	if aviso != null:
		_conferir(not aviso.get_global_rect().intersects(fila.get_global_rect()),
			"o aviso de interação (%s) cruza a barra de mão (%s): um cobre o outro"
				% [str(aviso.get_global_rect()), str(fila.get_global_rect())])

	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("BARRA_OK: a barra existe, tem tamanho, está no rodapé dentro da tela, tem os dez espaços, e o que entra na mochila aparece nela")
	else:
		print("barra: %d falha(s)" % falhas)
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
