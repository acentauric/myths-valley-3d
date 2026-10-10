extends "res://tests/suite/caso.gd"
## Salvar no editor precisa mudar o mundo, não apenas a aparência da prévia.

const Composicao = preload("res://scripts/prototipo_3d/composicao_vale.gd")
var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var pacote := load(Composicao.CENA) as PackedScene
	_verificar(pacote != null, "composição carrega")
	if pacote == null:
		quit(1)
		return
	var cena := pacote.instantiate()
	var dados := Composicao.extrair(cena)
	# As quinze de antes e as oito dos moradores novos (tools/mapas/aplicar_casas_moradores.py).
	_verificar(dados.size() == 23, "as vinte e três construções atuais têm identidade única")
	_verificar(cena.get_node_or_null("BaseGeografica") == null, "base pesada não é instanciada fora do editor")
	var ruas := (load("res://scenes/prototipo_3d/ruas_referencia.tscn") as PackedScene).instantiate()
	_verificar(ruas.find_children("Rua*", "MeshInstance3D", true, false).size() == 8, "as oito ruas estão visíveis na referência")
	ruas.free()
	var casa := cena.get_node("Casas/Casa de taipa") as Node3D
	# Filhos autorais (Terreiro, peças) são da cena; a prévia (Visual, alicerce) é
	# interna e só nasce no editor.
	_verificar(_internos(casa) == 0 and casa.get_node_or_null("Visual") == null, "ler autoria não instancia GLBs no runtime")
	casa._mostrar_visual()
	_verificar(casa.get_node_or_null("Visual") != null, "prévia usa modelo do catálogo")
	casa.position += Vector3(0.7, 0.4, 0.8)
	casa.rotation.y += 0.2
	var esperado := casa.position
	var giro := casa.rotation.y
	# AVULSOS: o poço movido no editor e um banco acrescentado (Ctrl+D) chegam ao jogo.
	var avulsos := cena.get_node_or_null("Avulsos") as Node3D
	if avulsos == null:
		avulsos = Node3D.new()
		avulsos.name = "Avulsos"
		cena.add_child(avulsos)
		avulsos.owner = cena
	for velho in avulsos.find_children("Poço", "", true, false) + avulsos.find_children("Banco extra", "", true, false) + avulsos.find_children("Manguezal", "", false, false) + avulsos.find_children("Pontes", "", false, false):
		velho.get_parent().remove_child(velho)
		velho.free()
	# Vegetação e ponte autorais: um manguezal de UM mangue e a ponte central movida.
	var mangue_esperado := Vector2(120.0, -250.0)
	var ponte_esperada := Vector3(9.5, 3.9, -26.0)
	for par in [["Manguezal", "Mangue único", "arvore", "mangue", Vector3(mangue_esperado.x, 0.0, mangue_esperado.y), true], ["Pontes", "Ponte do rio central", "construcao", "ponte", ponte_esperada, false]]:
		var subgrupo := Node3D.new()
		subgrupo.name = par[0]
		avulsos.add_child(subgrupo)
		subgrupo.owner = cena
		var peca := Node3D.new()
		peca.set_script(load("res://scripts/prototipo_3d/peca_composicao.gd"))
		peca.name = par[1]
		peca.set("id", par[1])
		peca.set("tipo", par[2])
		peca.set("chave", par[3])
		peca.set("no_chao", par[5])
		peca.position = par[4]
		subgrupo.add_child(peca)
		peca.owner = cena
	var poco_esperado := Vector3(6.5, 0.0, 8.0)
	for par in [["Poço", "poco", poco_esperado], ["Banco extra", "banco", Vector3(-6.0, 0.0, 6.0)]]:
		var peca := Node3D.new()
		peca.set_script(load("res://scripts/prototipo_3d/peca_composicao.gd"))
		peca.name = par[0]
		peca.set("id", par[0])
		peca.set("tipo", "adereco")
		peca.set("chave", par[1])
		peca.position = par[2]
		avulsos.add_child(peca)
		peca.owner = cena
	var salvo := PackedScene.new()
	_verificar(salvo.pack(cena) == OK, "edição pode ser empacotada")
	var caminho := "user://composicao_teste.tscn"
	_verificar(ResourceSaver.save(salvo, caminho) == OK, "edição fica salva")
	var reaberta := salvo.instantiate()
	var casa_reaberta := reaberta.get_node("Casas/Casa de taipa")
	_verificar(_internos(casa_reaberta) == 0 and casa_reaberta.get_node_or_null("Visual") == null, "prévia não é incorporada ao salvar a autoria")
	reaberta.free()
	cena.free()
	var relido := Composicao.ler(caminho)
	_verificar(relido["Casa de taipa"]["pos"].distance_to(esperado) < 0.0001, "posição sobrevive ao salvamento e reabertura")
	_verificar(absf(float(relido["Casa de taipa"]["yaw"]) - giro) < 0.0001, "giro sobrevive ao salvamento e reabertura")
	root.get_node("Estilo").modo = "tripo"
	var mundo := (load("res://scripts/prototipo_3d/world_builder.gd") as Script).new() as Node3D
	mundo.caminho_composicao = caminho
	if "--falsificar-composicao" in OS.get_cmdline_user_args():
		mundo.ignorar_composicao = true
	root.add_child(mundo)
	if not mundo.construido:
		await mundo.pronto
	for nome in relido:
		_verificar(mundo.construcoes_editaveis.has(nome), "construção aparece uma vez: " + nome)
		if not mundo.construcoes_editaveis.has(nome):
			continue
		var resultado: Dictionary = mundo.construcoes_editaveis[nome]
		_verificar(resultado["pos"].distance_to(relido[nome]["pos"]) < 0.002, "jogo usa a posição salva: " + nome)
		_verificar(absf(angle_difference(float(resultado["yaw"]), float(relido[nome]["yaw"]))) < 0.0001, "jogo usa o giro salvo: " + nome)
	_verificar(mundo.ancoras["Casa de taipa"].distance_to(esperado) < 0.002, "âncora de moradores e missões acompanha a casa")
	var poco_no_chao: Vector3 = mundo.ground_position(poco_esperado)
	_verificar(Vector2(mundo.ancoras["Poço"].x, mundo.ancoras["Poço"].z).distance_to(Vector2(poco_no_chao.x, poco_no_chao.z)) < 0.002, "o poço autoral move a âncora do poço")
	_verificar(mundo.avulsos_montados.has("Banco extra") and bool(mundo.avulsos_montados["Banco extra"]["visivel"]), "avulso acrescentado no editor entra no jogo")
	_verificar(mundo.ancoras["Ponte do rio central"].distance_to(ponte_esperada) < 0.002, "a ponte autoral fica onde o autor a pôs")
	var mangues: Array = []
	for tronco in mundo._region._tree_trunks:
		if String(tronco.get("especie", "")) == "mangue":
			mangues.append(tronco["point"])
	if CatalogoAssets.tem_tripo("mangue"):
		_verificar(mangues.size() == 1 and (mangues[0] as Vector2).distance_to(mangue_esperado) < 0.002, "o manguezal autoral troca o sorteado (%d mangues)" % mangues.size())
	var alvos := 0
	for alvo in mundo._house_targets:
		var propriedades: Dictionary = alvo.get_meta("house_properties")
		if propriedades["name"] == "Casa de taipa":
			alvos += 1
			_verificar(alvo.position.distance_to(esperado) < 0.002, "interação acompanha a posição salva")
			_verificar(absf(angle_difference(alvo.rotation.y, giro)) < 0.0001, "interação acompanha o giro salvo")
	_verificar(alvos == 1, "não duplica o alvo da casa")
	var visual: Node3D = mundo.construcoes_editaveis["Casa de taipa"]["visual"]
	_verificar(absf(angle_difference(visual.rotation.y, giro)) < 0.0001, "modelo acompanha o giro salvo")
	# A colisão vem do catálogo e tem o giro da composição, no lugar da casa. O
	# centro dela é o da PEGADA do que o modelo ocupa na altura do corpo
	# (`CatalogoAssets.pegada`), e não o da caixa envolvente: o beiral que sobra
	# de um lado desloca a caixa de parede, por isso a folga de 0,6 m.
	var corpos := 0
	for filho in mundo.get_children():
		if filho is StaticBody3D and String(filho.name).begins_with("Casa TaipaColisao") and Vector2(filho.position.x, filho.position.z).distance_to(Vector2(esperado.x, esperado.z)) < 0.6:
			corpos += 1
			_verificar(absf(angle_difference(filho.rotation.y, giro)) < 0.0001, "colisão acompanha o giro salvo")
	_verificar(corpos == 1, "colisão da casa acompanha o deslocamento, sem duplicação")
	_verificar(Composicao.ler()["Casa de taipa"]["pos"].distance_to(dados["Casa de taipa"]["pos"]) < 0.0001, "teste não altera a composição do projeto")
	# O estilo legado continua funcional e aplica o giro relativo à forma original.
	root.get_node("Estilo").modo = "procedural"
	var legado := (load("res://tests/fixtures/construtor_sem_montagem.gd") as Script).new() as Node3D
	root.add_child(legado)
	legado._region = mundo._region
	legado._casas_autorais = relido
	legado._lotes = {"Casa de taipa": {"pos": esperado, "yaw": giro}}
	legado._construcao("casa_taipa", esperado, giro, func(at: Vector3): legado._house(at, Color.WHITE, Color.RED), 1.0, "Casa de taipa")
	var alvo_legado: Area3D = legado._house_targets[0]
	_verificar(Vector2(alvo_legado.position.x, alvo_legado.position.z).distance_to(Vector2(esperado.x, esperado.z)) < 0.002, "procedural acompanha deslocamento horizontal")
	_verificar(absf(angle_difference(alvo_legado.rotation.y, 0.2)) < 0.0001, "procedural aplica giro relativo à orientação inicial")
	var grupo_legado := legado.get_node_or_null("ConstrucaoAutoralProcedural") as Node3D
	_verificar(grupo_legado != null and grupo_legado.find_children("*", "StaticBody3D", true, false).size() > 0, "modelo e colisões procedurais giram juntos")
	# Reimportar uma geografia com menos ruas não elimina lotes promovidos à autoria.
	var ruas_originais: Array[Dictionary] = mundo._region._roads
	mundo._region._roads = [] as Array[Dictionary]
	legado.ancoras = mundo.ancoras.duplicate()
	legado._lotes.clear()
	legado._loteamento()
	_verificar(legado._lotes.size() == relido.size(), "geografia sem ruas não apaga construções autorais")
	mundo._region._roads = ruas_originais
	legado._region = null
	legado.queue_free()
	mundo.queue_free()
	await process_frame
	print("COMPOSICAO_VALE_OK: posição, giro, salvamento, colisão, interação e âncoras" if falhas == 0 else "composicao_vale: Falhas: %d" % falhas)
	quit(1 if falhas else 0)


func _verificar(ok: bool, descricao: String) -> void:
	if not ok:
		falhas += 1
		push_error("FALHOU: " + descricao)


func _internos(no: Node) -> int:
	return no.get_child_count(true) - no.get_child_count(false)
