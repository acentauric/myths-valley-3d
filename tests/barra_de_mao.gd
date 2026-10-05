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
##   5. O QUE ENTRA NA MOCHILA APARECE NELA, e o que está na mão se destaca —
##      inclusive o machado, que o número põe na mão.

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
	#
	Inv.adicionar("picareta", 1)
	var espaco := -1
	for i in Inv.ESPACOS_MAO:
		if str((Inv.espacos[i] as Dictionary).get("id", "")) == "picareta":
			espaco = i
			break
	_conferir(espaco >= 0, "a picareta não entrou em espaço nenhum da mão")
	Inv.selecionar(maxi(espaco, 0))
	await _frames(2)

	# O MACHADO SOBE PARA A MÃO PELO NÚMERO, como a picareta.
	#
	# "O machado no inventário não tá subindo para a mão (1,2,3,4,5,6,7,8,9,0),
	# os outros itens estão normal." Ele tinha ido morar só na reserva, usado
	# pelo encaixe "Mãos" da mochila, e o número dele não existia. O vale dá um
	# machado de saída; ele tem de estar num dos dez, e a TECLA — não a chamada
	# direta — tem de pô-lo na mão e no braço do personagem.
	if not Inv.tem("machado"):
		Inv.adicionar("machado", 1)
	var espaco_do_machado := -1
	for i in Inv.ESPACOS_MAO:
		if str((Inv.espacos[i] as Dictionary).get("id", "")) == "machado":
			espaco_do_machado = i
	_conferir(espaco_do_machado >= 0,
		"o machado não está em nenhum dos dez espaços da mão: o número dele não alcança")
	if espaco_do_machado >= 0:
		Inv.selecionar(Inv.MAO_LIVRE)
		await _tecla(KEY_0 if espaco_do_machado == 9 else KEY_1 + espaco_do_machado)
		_conferir(Inv.na_mao() == "machado",
			"apertei o número do machado (%s) e a mão ficou com '%s'"
				% [Inv.rotulo_do_espaco(espaco_do_machado), Inv.na_mao()])
		var jogador_5 = current_scene.get("player")
		if jogador_5 != null:
			_conferir(bool(jogador_5.machado_na_mao()),
				"o machado está na barra e na mão, e o personagem não o segura")
		Inv.selecionar(maxi(espaco, 0))
		await _frames(2)

	var primeiro := fila.get_child(maxi(espaco, 0)) as Panel
	var conteudo := primeiro.get_node_or_null("Conteudo") as Label
	var icone := primeiro.get_node_or_null("Icone") as TextureRect
	_conferir(conteudo != null and icone != null, "o espaço não tem rótulo nem ícone")
	if conteudo != null and icone != null:
		# Com ícone ou sem, alguma coisa tem de aparecer: a arte de 32px é do 2D
		# e ainda não veio para cá, e aí a inicial do item faz as vezes dela.
		_conferir(icone.texture != null or conteudo.text != "",
			"a picareta entrou na mochila e o espaço ficou vazio na tela")
	Inv.adicionar("cana", 2)
	var espaco_da_cana := -1
	for i in Inv.ESPACOS_MAO:
		if str((Inv.espacos[i] as Dictionary).get("id", "")) == "cana":
			espaco_da_cana = i
			break
	if espaco_da_cana >= 0:
		var slot_cana := fila.get_child(espaco_da_cana) as Panel
		var quantidade_cana := slot_cana.get_node("Conteudo") as Label
		var icone_cana := slot_cana.get_node("Icone") as TextureRect
		_conferir(quantidade_cana.text == "2" and quantidade_cana.z_index > icone_cana.z_index
			and quantidade_cana.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT
			and quantidade_cana.vertical_alignment == VERTICAL_ALIGNMENT_TOP,
			"a quantidade da cana não aparece sobre o ícone, no canto superior")
	else:
		_conferir(false, "a cana não entrou na barra para testar o contador")

	var na_mao := barra.get_node_or_null("NaMao") as Label
	_conferir(na_mao != null, "não há rótulo do que está na mão")
	if na_mao != null:
		_conferir(na_mao.text.to_lower().contains("picareta"),
			"a mão diz '%s' com a picareta selecionada" % na_mao.text)

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

	# --- 7. O QUE ESTÁ NA MÃO SE COME, pela tecla e pelo clique ---------------
	#
	# "Apertando E ou clicando com o mouse em itens consumíveis na mão ativa do
	# jogador, deve ser consumido. Só consegui consumir clicando dentro do
	# inventário."
	#
	# A regra de comer é do `Cozinha.comer`, compartilhado com o 2D. O que se
	# mede aqui é a MÃO chegar até ela.
	var energia := root.get_node("/root/Energia")
	var cozinha := root.get_node("/root/Cozinha")
	Inv.adicionar("pirao", 2)
	var espaco_do_pirao := -1
	for i in Inv.ESPACOS_MAO:
		if str((Inv.espacos[i] as Dictionary).get("id", "")) == "pirao":
			espaco_do_pirao = i
	_conferir(espaco_do_pirao >= 0, "o pirão não entrou num espaço de mão")
	if espaco_do_pirao >= 0:
		Inv.selecionar(espaco_do_pirao)
		await _frames(2)
		_conferir(Inv.na_mao() == "pirao", "não consegui pôr o pirão na mão")
		# Abre espaço no fôlego para o pirão ter o que repor: cheio, comer não
		# mudaria número nenhum e a pergunta não valeria nada.
		energia.repor(-30.0)
		var antes_folego: float = energia.atual
		var antes_conta: int = Inv.quantidade("pirao")
		_conferir(barra._comer_da_mao(), "a mão recusou comer o pirão, que é comida")
		await _frames(2)
		_conferir(Inv.quantidade("pirao") == antes_conta - 1,
			"comer não gastou o pirão: tinha %d, ficou %d" % [antes_conta, Inv.quantidade("pirao")])
		_conferir(energia.atual > antes_folego,
			"comer o pirão não repôs fôlego: era %.0f e ficou %.0f" % [antes_folego, energia.atual])

		# FERRAMENTA NÃO SE COME. É a outra metade: a mão não pode engolir a
		# ferramenta porque o jogador apertou E perto de nada.
		#
		Inv.adicionar("picareta", 1)
		var achou_picareta := false
		for i in Inv.ESPACOS_MAO:
			if str((Inv.espacos[i] as Dictionary).get("id", "")) == "picareta":
				Inv.selecionar(i)
				achou_picareta = true
				break
		_conferir(achou_picareta, "a picareta não entrou num espaço da mão")
		await _frames(2)
		_conferir(Inv.na_mao() == "picareta",
			"a mão está com '%s' e não com a picareta: a pergunta abaixo mediria outro item" % Inv.na_mao())
		_conferir(not barra._comer_da_mao(), "a mão comeu a picareta")
		_conferir(Inv.tem("picareta"), "a picareta desapareceu da mochila")

	# --- 8. O E DA MÃO É O ÚLTIMO DA FILA ------------------------------------
	#
	# Perto de um tronco o E golpeia; perto de uma árvore lê a ficha. Comer é o
	# que sobra, e sobra por ORDEM DE ÁRVORE: a barra mora dentro do HUD, que
	# entra no vale antes dos nós do mundo, e o Godot entrega o evento de baixo
	# para cima. Ordem de árvore é coisa que muda quando alguém acrescenta um nó,
	# então aqui se mede a precedência de verdade.
	var recursos := current_scene.get_node_or_null("Recursos3D")
	var jogador = current_scene.get("player")
	if recursos != null and jogador != null and not recursos._alvos.is_empty():
		Inv.adicionar("pirao", 3)
		Inv.adicionar("machado", 1)
		var onde: Vector3 = recursos.mais_perto_que_rende("lenha", jogador.global_position)
		if onde != Vector3.ZERO:
			jogador.global_position = onde
			await _frames(4)
			for i in Inv.ESPACOS_MAO:
				if str((Inv.espacos[i] as Dictionary).get("id", "")) == "pirao":
					Inv.selecionar(i)
			await _frames(2)
			var pirao_antes: int = Inv.quantidade("pirao")
			_tecla_de_interagir()
			await _frames(3)
			_conferir(Inv.quantidade("pirao") == pirao_antes,
				"com um tronco ao alcance, o E comeu o pirão em vez de golpear: a fila do E inverteu")

	# --- 9. COM O CORPO PARADO, O E NÃO VALE PARA O MUNDO NEM PARA A MÃO -----
	#
	# No escuro da queda o jogador já está na porta de casa, de corpo parado, e
	# o E batia no tronco ao lado dela: achados, pesca e luta perguntavam pelo
	# corpo; recursos, árvores e lápides não. E o E que ninguém pegava caía na
	# mão, que comia — desacordado não come.
	if recursos != null and jogador != null:
		var onde9: Vector3 = recursos.mais_perto_que_rende("lenha", jogador.global_position)
		if onde9 != Vector3.ZERO:
			jogador.global_position = onde9
			await _frames(4)
			var alvo9: String = recursos._perto
			_conferir(alvo9 != "", "não achei um tronco ao alcance para a pergunta do corpo parado")
			if alvo9 != "":
				_por_o_pirao_na_mao()
				energia.repor(-30.0)
				var golpes9 := int(recursos._alvos[alvo9]["golpes_dados"])
				var pirao9: int = Inv.quantidade("pirao")
				# "BATER FOI TENTADO" é golpe dado OU recusa dita ("Precisa de
				# machado", "Sem fôlego"): a ferramenta certa não é o que se
				# pergunta aqui, e sem ela o golpe não sairia nem sem a guarda.
				var recusas := [0]
				var contar_recusa := func(_texto: String) -> void: recusas[0] += 1
				recursos.recusado.connect(contar_recusa)
				jogador.set_physics_process(false)
				_tecla_de_interagir()
				await _frames(3)
				recursos.recusado.disconnect(contar_recusa)
				_conferir(recursos._alvos.has(alvo9) and int(recursos._alvos[alvo9]["golpes_dados"]) == golpes9 and recusas[0] == 0,
					"com o corpo parado (o escuro da queda), o E tentou bater no tronco")
				_conferir(Inv.quantidade("pirao") == pirao9, "com o corpo parado, o E comeu o pirão da mão")
				jogador.set_physics_process(true)
				await _frames(2)
	# AS ÁRVORES E AS LÁPIDES, pelo mesmo E e com o corpo parado. Chamadas
	# direto, com o alvo posto à mão: o `_process` delas recalcula o que está
	# perto a cada quadro, e o que se pergunta aqui é só a guarda do corpo.
	var e_de_interagir := InputEventKey.new()
	e_de_interagir.physical_keycode = load("res://scripts/prototipo_3d/atalhos.gd").tecla("interagir")
	e_de_interagir.pressed = true
	var arvores = current_scene.get_node_or_null("ArvoresInfo")
	var AlmanaqueScript = load("res://scripts/prototipo_3d/almanaque.gd")
	if arvores != null and jogador != null:
		var nova := -1
		for k in arvores._pontos.size():
			if not AlmanaqueScript.conhece(String(arvores._pontos[k]["especie"])):
				nova = k
				break
		if nova >= 0:
			jogador.set_physics_process(false)
			arvores._aberta = -1
			arvores._em_golpe = -1
			arvores._cortavel_perto = -1
			arvores._perto = nova
			arvores._unhandled_key_input(e_de_interagir)
			_conferir(arvores._aberta == -1, "com o corpo parado, o E abriu a ficha da árvore")
			jogador.set_physics_process(true)
	var lapides = current_scene.get_node_or_null("Lapides")
	var hud = current_scene.get("hud")
	if lapides != null and jogador != null and hud != null and not lapides._historias.is_empty():
		jogador.set_physics_process(false)
		lapides._aberta = -1
		lapides._perto = 0
		hud.set("painel_dono", null)
		lapides._unhandled_key_input(e_de_interagir)
		_conferir(lapides.lapide_aberta() == -1, "com o corpo parado, o E leu a lápide")
		jogador.set_physics_process(true)
		await _frames(2)

	# --- 10. COM TELA ABERTA, AS TECLAS DA MÃO SÃO DELA ----------------------
	#
	# A barra ouve com o vale parado, e ouve ANTES das telas que escutam no
	# `_unhandled_input` (no Godot 4 o `_unhandled_key_input` vem antes): o
	# número trocava a mão por baixo de qualquer uma das cinco, e com o arraial
	# aberto o E comia (nas outras, um controle delas pega o E antes). As cinco
	# ficam na pergunta, porque o que pega o E antes é coisa de cada tela e
	# muda. O número vem antes do E, porque o E pode fechar a tela.
	var telas = current_scene.get("telas")
	if telas != null:
		_por_o_pirao_na_mao()
		var mao: int = Inv.selecionado
		var outro_numero: int = KEY_1 + ((mao + 1) % 9)
		for nome in ["painel", "almanaque", "arraial", "talentos", "menu_pausa"]:
			telas.abrir(nome)
			await _frames(3)
			_conferir(telas.aberta() == nome, "não consegui abrir '%s' para a pergunta das teclas da mão" % nome)
			if telas.aberta() != nome:
				continue
			await _tecla(outro_numero)
			_conferir(Inv.selecionado == mao, "com '%s' aberto, o número trocou a mão" % nome)
			# O pirão volta à mão, para a pergunta do E não depender da de cima.
			_por_o_pirao_na_mao()
			energia.repor(-30.0)
			var pirao10: int = Inv.quantidade("pirao")
			_tecla_de_interagir()
			await _frames(3)
			_conferir(Inv.quantidade("pirao") == pirao10, "com '%s' aberto, o E comeu o pirão da mão" % nome)
			telas.fechar_tudo()
			await _frames(3)

	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("BARRA_OK: a barra existe, tem tamanho, está no rodapé dentro da tela, tem os dez espaços, o que entra na mochila aparece nela, o que está na mão se come pela tecla e não se come quando é ferramenta, com um tronco ao alcance o E golpeia em vez de comer, com o corpo parado o E não bate nem come, e com tela aberta as teclas da mão são dela")
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


func _por_o_pirao_na_mao() -> void:
	if Inv.quantidade("pirao") < 2:
		Inv.adicionar("pirao", 2)
	for i in Inv.ESPACOS_MAO:
		if str((Inv.espacos[i] as Dictionary).get("id", "")) == "pirao":
			Inv.selecionar(i)
			return


func _tecla(codigo: int) -> void:
	for apertada in [true, false]:
		var evento := InputEventKey.new()
		evento.physical_keycode = codigo
		evento.keycode = codigo
		evento.pressed = apertada
		Input.parse_input_event(evento)
		await _frames(2)


## Manda a tecla de interagir pelo caminho do jogo, para a fila do E valer.
func _tecla_de_interagir() -> void:
	var Atalhos = load("res://scripts/prototipo_3d/atalhos.gd")
	var evento := InputEventKey.new()
	evento.physical_keycode = Atalhos.tecla("interagir")
	evento.pressed = true
	Input.parse_input_event(evento)
