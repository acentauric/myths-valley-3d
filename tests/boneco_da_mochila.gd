extends SceneTree
## Confere O BONECO DA MOCHILA.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/boneco_da_mochila.gd
##
## "No inventário, ao lado dos itens equipados, coloque o 3D do boneco com os
## itens equipados, igual nos jogos de RPG. Assim ele pode ver as alterações
## conforme vai equipando." Nove perguntas:
##
##   1. ELE ESTÁ AO LADO DOS ENCAIXES: aberta a mochila, o boneco está à direita
##      da coluna dos encaixes, na altura dela, e a mochila inteira cabe na tela.
##   2. É O CORPO DO JOGADOR: a mesma cena, o mesmo transform, parado no idle.
##   3. SÓ DESENHA COM A MOCHILA ABERTA: fechada, o palco não renderiza.
##   4. O QUE SE VESTE APARECE NOS DOIS: o chapéu no encaixe da cabeça aparece no
##      boneco e no jogador; tirado, some dos dois.
##   5. A MÃO TAMBÉM: o machado e o facão escolhidos na barra de mão (arma vai
##      nos números; o encaixe das Mãos é das luvas) aparecem na mão do boneco
##      e do jogador, um de cada vez.
##   6. O MOUSE GIRA O BONECO: arrastar por cima dele gira; arrastar fora, não.
##   7. SOLTAR A PEÇA NO BONECO VESTE: arrastada da mochila e solta em cima
##      dele, o chapéu vai para o encaixe da cabeça.
##   8. COM O BAÚ, O BONECO SAI: a mochila do baú é tela de transferir, e com o
##      boneco ela passava da altura da tela; sem ele, cabe, e o palco não
##      renderiza.
##   9. AS LUVAS NAS DUAS MÃOS: as luvas de couro vão para o encaixe das Mãos
##      ("não é para armas, mas sim para luvas") e aparecem nas duas mãos do
##      boneco e do jogador; os dedos encolhem dentro delas, que são rígidas,
##      e o machado na mão não muda de tamanho por isso; tiradas, saem dos dois
##      e os dedos voltam.

var falhas := 0
var inventario
var equipamento
var mochila


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("BONECO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	inventario = root.get_node("/root/Inventario")
	equipamento = root.get_node("/root/Equipamento")
	mochila = root.get_node("/root/Mochila")
	var vale = current_scene
	var jogador = vale.player
	var boneco = vale.get("boneco_da_mochila")
	_conferir(boneco != null and is_instance_valid(boneco), "o vale não montou o boneco da mochila")
	if boneco == null:
		_fechar()
		return

	# --- 1. AO LADO DOS ENCAIXES ---------------------------------------------------
	_abrir(vale)
	await _segundos(0.6)
	var encaixes: Control = mochila.get("_encaixes_coluna")
	var dele: Rect2 = boneco.get_global_rect()
	var deles: Rect2 = encaixes.get_global_rect()
	_conferir(boneco.is_visible_in_tree(), "aberta a mochila, o boneco não está à vista")
	_conferir(dele.position.x >= deles.end.x and dele.position.x - deles.end.x < 60.0,
		"o boneco não está logo à direita dos encaixes (boneco em %s, encaixes em %s)" % [str(dele), str(deles)])
	_conferir(dele.position.y < deles.end.y and dele.end.y > deles.position.y, "o boneco não está na altura dos encaixes")
	_conferir(dele.size.x >= 80.0 and dele.size.y >= 120.0, "o boneco é pequeno demais: %s" % str(dele.size))
	var painel: Control = mochila.get_child(1)
	var na_tela: Rect2 = mochila.transform * painel.get_global_rect()
	var tela := root.get_visible_rect()
	_conferir(tela.encloses(na_tela), "com o boneco, a mochila não cabe na tela: %s em %s" % [str(na_tela), str(tela)])

	# --- 2. É O CORPO DO JOGADOR ----------------------------------------------------
	var do_jogador: Node3D = jogador.model
	_conferir(boneco.modelo != null and boneco.modelo.scene_file_path == do_jogador.scene_file_path,
		"o boneco não é a cena do jogador (%s, e não %s)" % [str(boneco.modelo.scene_file_path) if boneco.modelo != null else "nada", do_jogador.scene_file_path])
	if boneco.modelo != null:
		_conferir(boneco.modelo.transform.is_equal_approx(do_jogador.transform), "o boneco não tem a escala e o giro do corpo do jogador")
		var tocadores: Array = boneco.modelo.find_children("*", "AnimationPlayer", true, false)
		_conferir(not tocadores.is_empty() and str((tocadores[0] as AnimationPlayer).current_animation).contains("idle"),
			"o boneco não está parado no idle (%s)" % (str((tocadores[0] as AnimationPlayer).current_animation) if not tocadores.is_empty() else "sem clipes"))

	# --- 3. SÓ DESENHA COM A MOCHILA ABERTA ------------------------------------------
	_conferir(boneco.palco.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "com a mochila aberta, o palco do boneco não renderiza")
	_fechar_a_mochila(vale)
	await _segundos(0.3)
	_conferir(boneco.palco.render_target_update_mode == SubViewport.UPDATE_DISABLED, "com a mochila fechada, o palco do boneco continua renderizando")

	# --- 4. O QUE SE VESTE APARECE NOS DOIS ------------------------------------------
	inventario.adicionar("chapeu", 1)
	equipamento.equipar_do_espaco(_espaco_de("chapeu"))
	_abrir(vale)
	await _segundos(0.5)
	_conferir(boneco.pecas_vestidas().has("chapeu"), "com o chapéu na cabeça, o boneco não está de chapéu (%s)" % str(boneco.pecas_vestidas()))
	_fechar_a_mochila(vale)
	await _segundos(0.4)
	_conferir(_pecas(do_jogador).has("chapeu"), "com o chapéu na cabeça, o jogador no vale não está de chapéu")
	_abrir(vale)
	equipamento.desequipar("cabeca")
	await _segundos(0.5)
	_conferir(not boneco.pecas_vestidas().has("chapeu"), "tirado o chapéu, o boneco continua de chapéu")
	_fechar_a_mochila(vale)
	await _segundos(0.4)
	_conferir(not _pecas(do_jogador).has("chapeu"), "tirado o chapéu, o jogador continua de chapéu")

	# --- 5. A MÃO TAMBÉM -------------------------------------------------------------
	if _espaco_de("machado") < 0:
		inventario.adicionar("machado", 1)
	inventario.selecionar(_espaco_de("machado"))
	_abrir(vale)
	await _segundos(0.5)
	_conferir(boneco.pecas_vestidas().has("machado"), "com o machado na mão, o boneco não está com ele (%s)" % str(boneco.pecas_vestidas()))
	inventario.adicionar("facao", 1)
	inventario.selecionar(_espaco_de("facao"))
	await _segundos(0.5)
	var na_mao: Array = boneco.pecas_vestidas()
	_conferir(na_mao.has("facao") and not na_mao.has("machado"), "com o facão escolhido na barra, o boneco mostra %s" % str(na_mao))
	_fechar_a_mochila(vale)
	await _segundos(0.4)
	var do_corpo := _pecas(do_jogador)
	_conferir(do_corpo.has("facao") and not do_corpo.has("machado"), "com o facão escolhido na barra, o jogador mostra %s" % str(do_corpo))
	inventario.selecionar(-1)
	await _segundos(0.4)
	_conferir(not _pecas(do_jogador).has("facao"), "tirado o facão, o jogador continua com ele na mão")

	# --- 6. O MOUSE GIRA O BONECO ------------------------------------------------------
	_abrir(vale)
	await _segundos(0.3)
	var vidro: Control = mochila.get("_vidro")
	var antes: float = boneco.giro
	_arrastar(vidro, boneco.get_global_rect().get_center(), Vector2(60, 0))
	_conferir(absf(boneco.giro - antes) > 0.3, "arrastar por cima do boneco não o girou (%.2f → %.2f)" % [antes, boneco.giro])
	antes = boneco.giro
	_arrastar(vidro, encaixes.get_global_rect().position - Vector2(30, 0), Vector2(60, 0))
	_conferir(is_equal_approx(boneco.giro, antes), "arrastar fora do boneco o girou")

	# --- 7. SOLTAR A PEÇA NO BONECO VESTE ---------------------------------------------
	var onde_esta := _espaco_de("chapeu")
	_conferir(onde_esta >= 0, "o chapéu não voltou para a mochila")
	if onde_esta >= 0:
		var molduras: Array = mochila.get("_molduras")
		var de: Vector2 = (molduras[onde_esta] as Control).get_global_rect().get_center()
		_clicar(vidro, de, true)
		_mover(vidro, boneco.get_global_rect().get_center() - de)
		_clicar(vidro, boneco.get_global_rect().get_center(), false)
		await _segundos(0.4)
		_conferir(equipamento.no_encaixe("cabeca") == "chapeu", "soltar o chapéu em cima do boneco não o vestiu (cabeça: '%s')" % equipamento.no_encaixe("cabeca"))
		_conferir(boneco.pecas_vestidas().has("chapeu"), "vestido pelo boneco, o chapéu não aparece nele")
	_fechar_a_mochila(vale)

	# --- 8. COM O BAÚ, O BONECO SAI ----------------------------------------------------
	var guardado: Array = [{"id": "lenha", "qtd": 3}]
	vale.telas.abrir_por("mochila", func() -> void: mochila.abrir_bau(guardado, 20, "Baú"))
	await _segundos(0.4)
	_conferir(mochila.aberta and not boneco.is_visible_in_tree(), "com o baú aberto, o boneco continua na mochila")
	_conferir(boneco.palco.render_target_update_mode == SubViewport.UPDATE_DISABLED, "com o baú aberto, o palco do boneco renderiza")
	var com_bau: Rect2 = mochila.transform * painel.get_global_rect()
	_conferir(tela.encloses(com_bau), "com o baú aberto, a mochila não cabe na tela: %s" % str(com_bau))
	_fechar_a_mochila(vale)

	# --- 9. AS LUVAS NAS DUAS MÃOS -----------------------------------------------------
	# O tamanho dos dedos é lido no meio da atualização do esqueleto: fora dela o
	# Godot já devolveu a pose de antes dos modificadores.
	var esqueletos: Array = do_jogador.find_children("*", "Skeleton3D", true, false)
	_conferir(not esqueletos.is_empty(), "o corpo do jogador não tem esqueleto")
	if not esqueletos.is_empty():
		var esqueleto: Skeleton3D = esqueletos[0]
		var dedo := esqueleto.find_bone("mixamorig_RightHandIndex1")
		_conferir(dedo >= 0, "o esqueleto do jogador não tem o osso do indicador direito")
		var dedo_no_quadro := [1.0]
		esqueleto.skeleton_updated.connect(func() -> void: dedo_no_quadro[0] = esqueleto.get_bone_pose_scale(maxi(dedo, 0)).x)
		inventario.selecionar(_espaco_de("machado"))
		await _segundos(0.4)
		var machado_antes := _escala_do_machado(do_jogador)
		_conferir(machado_antes > 0.0, "com o machado escolhido na barra, o jogador não está com ele na mão")
		inventario.adicionar("luvas_de_couro", 1)
		equipamento.equipar_do_espaco(_espaco_de("luvas_de_couro"))
		_conferir(equipamento.no_encaixe("maos") == "luvas_de_couro", "as luvas de couro não foram para o encaixe das Mãos (%s)" % equipamento.no_encaixe("maos"))
		_abrir(vale)
		await _segundos(0.5)
		_conferir(boneco.pecas_vestidas().count("luvas_de_couro") == 2, "com as luvas nas Mãos, o boneco não está de luvas nas duas mãos (%s)" % str(boneco.pecas_vestidas()))
		_fechar_a_mochila(vale)
		await _segundos(0.4)
		_conferir(_pecas(do_jogador).count("luvas_de_couro") == 2, "com as luvas nas Mãos, o jogador no vale não está de luvas nas duas mãos (%s)" % str(_pecas(do_jogador)))
		_conferir(float(dedo_no_quadro[0]) < 0.5, "de luvas, os dedos do jogador não encolhem dentro delas, e furam o couro (escala %.2f)" % float(dedo_no_quadro[0]))
		var machado_com := _escala_do_machado(do_jogador)
		_conferir(absf(machado_com - machado_antes) <= 0.001 * maxf(machado_antes, 0.001), "de luvas, o machado na mão mudou de tamanho (%.3f → %.3f)" % [machado_antes, machado_com])
		equipamento.desequipar("maos")
		await _segundos(0.5)
		_conferir(_pecas(do_jogador).count("luvas_de_couro") == 0, "tiradas as luvas, o jogador continua de luvas")
		_conferir(float(dedo_no_quadro[0]) > 0.99, "tiradas as luvas, os dedos do jogador continuam encolhidos (escala %.2f)" % float(dedo_no_quadro[0]))
		_abrir(vale)
		await _segundos(0.5)
		_conferir(boneco.pecas_vestidas().count("luvas_de_couro") == 0, "tiradas as luvas, o boneco continua de luvas")
		_fechar_a_mochila(vale)
		inventario.selecionar(-1)
	_fechar()


## O tamanho do machado na mão de um corpo (a escala dele no mundo), ou 0 sem ele.
func _escala_do_machado(modelo: Node3D) -> float:
	for no in modelo.find_children("*", "Node3D", true, false):
		if str(no.get_meta("peca", "")) == "machado" and not no.is_queued_for_deletion():
			return (no as Node3D).global_basis.get_scale().x
	return 0.0


func _abrir(vale) -> void:
	vale.telas.abrir_por("mochila", func() -> void: mochila.abrir())


func _fechar_a_mochila(vale) -> void:
	vale.telas.fechar_tudo()
	if mochila.aberta:
		mochila.fechar()


func _arrastar(vidro: Control, de: Vector2, quanto: Vector2) -> void:
	_clicar(vidro, de, true)
	_mover(vidro, quanto)
	_clicar(vidro, de + quanto, false)


func _clicar(vidro: Control, onde: Vector2, apertado: bool) -> void:
	var botao := InputEventMouseButton.new()
	botao.button_index = MOUSE_BUTTON_LEFT
	botao.pressed = apertado
	botao.position = onde
	vidro.gui_input.emit(botao)


func _mover(vidro: Control, quanto: Vector2) -> void:
	var movimento := InputEventMouseMotion.new()
	movimento.relative = quanto
	movimento.button_mask = MOUSE_BUTTON_MASK_LEFT
	vidro.gui_input.emit(movimento)


## As peças que um corpo mostra: o "peca" dos nós presos a ele.
func _pecas(modelo: Node3D) -> Array:
	var lista: Array = []
	for no in modelo.find_children("*", "Node3D", true, false):
		if no.has_meta("peca") and not no.is_queued_for_deletion():
			lista.append(str(no.get_meta("peca")))
	return lista


func _espaco_de(id: String) -> int:
	for i in inventario.espacos.size():
		if str((inventario.espacos[i] as Dictionary).get("id", "")) == id:
			return i
	return -1


func _segundos(s: float) -> void:
	var ate := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < ate:
		await process_frame


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("BONECO_OK: aberta a mochila, o boneco está ao lado dos encaixes e ela cabe na tela; é o corpo do jogador, parado no idle; só desenha com a mochila aberta; o chapéu, o machado e o facão da barra aparecem nele e no jogador, e somem dos dois; o mouse o gira por cima e não fora; o chapéu solto em cima dele vai para a cabeça; com o baú aberto ele sai; e as luvas das Mãos vestem as duas mãos dele e do jogador, com os dedos dentro e o machado do mesmo tamanho, e saem dos dois")
	else:
		print("boneco: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
