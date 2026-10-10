extends "res://tests/suite/caso.gd"
## Confere AS PEGADAS DO CURUPIRA E O MAPA DOIDO QUE ELAS PROVOCAM.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste rastro_do_curupira
##
## "adicione trilhas no mapa que serão do curupira, ao contrário... na verdade pegadas dele e faça o
## mapa ficar 'doido' quando você achar essas pegadas bem dentro da mata."
##
## O que existia era só a pegada do jogador (`pegadas.gd`) e o sinal de texto da Caipora. Nada de
## trilha, nada virado para trás, nada no mapa. Este portão mede o que ficou:
##
##   1. AS TRILHAS EXISTEM, FUNDO NA MATA: de 3 a 5 trilhas no vale; cada pegada que o arquivo marca
##      como funda é mata funda PELA CONTA DO JOGO (`mata_funda.gd`: longe de rua, vila, clareira,
##      costa e rio, com tronco em volta), e o fim de cada trilha também.
##   2. AS PEGADAS APONTAM PARA TRÁS: em cada trilha, os dedos de cada pegada apontam contra o
##      rumo em que o caminho anda (do pé i ao pé i+2: o zigue-zague dos dois pés não conta).
##   3. E O DESENHO OBEDECE: o quad que o jogador vê, com os dedos no -Z dele, também aponta contra
##      o caminho; o pé esquerdo é o espelho do direito.
##   4. PISAR NO RASTRO FUNDO ENLOUQUECE O MAPA — e só com o jogo livre e a chave Sustos ligada: com o
##      relógio segurado por uma fala, ou com os sustos desligados, nada acontece; livre e ligado, o
##      mapa enlouquece, o assobio toca no mundo, o sinal vai para o caderno. Pisar de novo não
##      recomeça (a loucura esfria).
##   5. A LOUCURA É DE VERDADE, nos três lugares: a bússola gira e escorrega (o centro da foto NÃO é
##      mais o jogador) e o losango da missão pula; o mapa grande gira, o "Você" vira "???" e os nomes
##      dos lugares trocam de dono; a seta da missão flutua longe do alvo e o chevron aponta errado.
##   6. E PASSA: a curva sobe de 0 a 1 e desce a 0 na duração, e depois TUDO volta EXATO — a foto no
##      jogador, "Você" de volta, o norte para cima, a seta sobre o alvo.
##
## FALSIFICAÇÃO: com `intensidade()` presa em zero (`loucura_do_mapa.gd`), a 5 e a 6 reprovam; com o
## `+ PI` tirado de `_transformacao` (`rastro_do_curupira.gd`), as pegadas viram para a frente e a 3
## reprova; com a chave Sustos ignorada pelo rastro, a 4 reprova.

const RelogioDeJogo = preload("res://tests/fixtures/relogio_de_jogo.gd")

var falhas := 0
var relogio: Node
var MataFunda
var SustosDaMata
## A chave Sustos de quem roda o portão à mão (o runner dá um perfil só do portão): devolvida no fim.
var _chave_de_antes: Variant = null


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("RASTRO_DO_CURUPIRA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(6)
	relogio = RelogioDeJogo.new()
	root.add_child(relogio)
	relogio.ficar_lento()
	MataFunda = load("res://scripts/prototipo_3d/mata_funda.gd")
	SustosDaMata = load("res://scripts/prototipo_3d/sustos_da_mata.gd")
	var preferencias := ConfigFile.new()
	if preferencias.load(SustosDaMata.PREFERENCIAS) == OK and preferencias.has_section_key("interface", "sustos"):
		_chave_de_antes = preferencias.get_value("interface", "sustos")

	var jogo := current_scene
	var world = jogo.get("world")
	var jogador = jogo.get("player")
	var rastro: Node = jogo.get_node_or_null("RastroDoCurupira")
	var loucura: Node = jogo.get_node_or_null("LoucuraDoMapa")
	_conferir(rastro != null and loucura != null, "o vale não montou o rastro do Curupira e a loucura do mapa (sustos_da_mata.gd)")
	if rastro == null or loucura == null or world == null or jogador == null:
		_fechar()
		return
	# O estado de partida do gate é limpo: chave na fábrica, sem relógio segurado.
	SustosDaMata.forcar_edicao = 0
	SustosDaMata.definir_ligado(true)

	# --- 1. AS TRILHAS EXISTEM, FUNDO NA MATA ----------------------------------
	var trilhas: Array = rastro.trilhas
	_conferir(trilhas.size() >= 3 and trilhas.size() <= 5, "o vale tem %d trilhas do Curupira: o pedido é de 3 a 5" % trilhas.size())
	var fundas_total := 0
	var fundas_boas := 0
	var motivos := {}
	for trilha: Dictionary in trilhas:
		var pegadas: Array = trilha["pegadas"]
		_conferir(pegadas.size() >= 40, "a trilha %s tem só %d pegadas desenhadas" % [trilha["id"], pegadas.size()])
		var fundas := 0
		for p: Dictionary in pegadas:
			if bool(p["funda"]):
				fundas += 1
				fundas_total += 1
				var por_que: String = MataFunda.porque_nao(world, p["pos"])
				if por_que == "":
					fundas_boas += 1
				else:
					motivos[por_que] = int(motivos.get(por_que, 0)) + 1
		_conferir(fundas >= 30, "a trilha %s tem só %d pegadas na mata funda" % [trilha["id"], fundas])
		var marco: Vector3 = trilha["marco"]
		marco.y = world.ground_height_at(marco)
		_conferir(MataFunda.e_funda(world, marco), "o fim da trilha %s não é mata funda (%s)" % [trilha["id"], MataFunda.porque_nao(world, marco)])
	_conferir(fundas_total > 0 and fundas_boas == fundas_total,
		"%d de %d pegadas 'fundas' não são mata funda pela conta do jogo: %s" % [fundas_total - fundas_boas, fundas_total, str(motivos)])
	print("  trilhas: %d, pegadas fundas: %d (todas mata funda pela conta do jogo)" % [trilhas.size(), fundas_total])

	# --- 2. OS DEDOS APONTAM PARA TRÁS -----------------------------------------
	var conferidas := 0
	for trilha: Dictionary in trilhas:
		var pegadas: Array = trilha["pegadas"]
		var para_a_frente := 0
		var primeira := -1
		for i in range(pegadas.size() - 2):
			var de: Vector3 = pegadas[i]["pos"]
			var para: Vector3 = pegadas[i + 2]["pos"]
			var ida := Vector2(para.x - de.x, para.z - de.z)
			if ida.length() > 4.5 or ida.length() < 0.5:
				continue
			var yaw: float = pegadas[i + 1]["yaw"]
			var dedos := Vector2(sin(yaw), cos(yaw))
			conferidas += 1
			if dedos.dot(ida.normalized()) >= -0.9:
				para_a_frente += 1
				primeira = i + 1 if primeira < 0 else primeira
		_conferir(para_a_frente == 0, "%d pegadas da trilha %s têm os dedos para a frente ou de lado (a primeira é a %d): precisam ser contra o rumo do caminho" % [para_a_frente, trilha["id"], primeira])
	_conferir(conferidas >= 100, "só conferi o rumo de %d pegadas" % conferidas)

	# --- 3. O DESENHO OBEDECE ---------------------------------------------------
	var desenhadas := 0
	for trilha: Dictionary in trilhas:
		var multi: MultiMesh = (trilha["visual"] as MultiMeshInstance3D).multimesh
		var pegadas: Array = trilha["pegadas"]
		_conferir(multi.instance_count == pegadas.size(), "a trilha %s desenha %d de %d pegadas" % [trilha["id"], multi.instance_count, pegadas.size()])
		# Sem tela o MultiMesh não devolve o que recebeu: o desenho é a `transformacao` que o nó guarda
		# no dado e entrega ao MultiMesh, uma só conta.
		var para_a_frente := 0
		var sem_espelho := 0
		for i in range(pegadas.size() - 2):
			var a: Transform3D = pegadas[i]["transformacao"]
			var b: Transform3D = pegadas[i + 1]["transformacao"]
			var c: Transform3D = pegadas[i + 2]["transformacao"]
			var ida := Vector2(c.origin.x - a.origin.x, c.origin.z - a.origin.z)
			if ida.length() > 4.5 or ida.length() < 0.5:
				continue
			var dedos3 := -b.basis.z
			var dedos := Vector2(dedos3.x, dedos3.z).normalized()
			desenhadas += 1
			if dedos.dot(ida.normalized()) >= -0.85:
				para_a_frente += 1
			# Pé esquerdo é o espelho do direito: o determinante da base vira negativo.
			if (b.basis.determinant() < 0.0) != bool(pegadas[i + 1]["esquerdo"]):
				sem_espelho += 1
		_conferir(para_a_frente == 0, "%d pegadas da trilha %s estão DESENHADAS com os dedos para a frente" % [para_a_frente, trilha["id"]])
		_conferir(sem_espelho == 0, "%d pés da trilha %s não estão espelhados como deviam" % [sem_espelho, trilha["id"]])
	_conferir(desenhadas >= 100, "só conferi o desenho de %d pegadas" % desenhadas)

	# --- 4. PISAR NO RASTRO FUNDO ENLOUQUECE O MAPA -----------------------------
	var colecao := root.get_node("/root/Colecao")
	var dia := root.get_node("/root/Dia")
	_conferir(not colecao.tem("sinais", "pegadas_ao_contrario"), "o sinal já estava no caderno antes de achar o rastro")
	var alvo_trilha: Dictionary = trilhas[0]
	var onde_pisar := Vector3.ZERO
	for p: Dictionary in alvo_trilha["pegadas"]:
		if bool(p["funda"]):
			onde_pisar = p["pos"]
			break
	var achou: Array = []
	rastro.achou.connect(func(id: String, _onde: Vector3) -> void: achou.append(id))
	jogador.teleportar(onde_pisar + Vector3(1.0, 0.1, 0.0), 0.0)
	# 4a. O relógio segurado por uma fala: não enlouquece.
	dia.segurar("teste_do_rastro")
	_conferir(not SustosDaMata.jogo_livre(jogo), "com uma fala segurando o relógio o jogo continua 'livre'")
	await relogio.esperar(1.6)
	_conferir(not loucura.ativa() and achou.is_empty(), "o mapa enlouqueceu com uma fala em curso")
	dia.soltar("teste_do_rastro")
	# 4b. Sustos desligados: não enlouquece.
	SustosDaMata.definir_ligado(false)
	await relogio.esperar(1.6)
	_conferir(not loucura.ativa() and achou.is_empty(), "o mapa enlouqueceu com os Sustos desligados em AJUSTAR")
	# 4c. Livre e ligado: enlouquece, assobia, anota o sinal.
	SustosDaMata.definir_ligado(true)
	var livre: bool = await relogio.ate(func() -> bool: return SustosDaMata.jogo_livre(jogo), 20.0)
	_conferir(livre, "o vale não ficou livre para um susto em 20 s de jogo (alguma tela ou fala ficou aberta?)")
	var enlouqueceu: bool = await relogio.ate(func() -> bool: return loucura.ativa(), 4.0)
	_conferir(enlouqueceu, "pisar a 1 u de uma pegada funda não enlouqueceu o mapa em 4 s de jogo")
	_conferir(achou.size() == 1 and String(achou[0]) == String(alvo_trilha["id"]), "o rastro devia ter avisado UMA vez, da trilha %s: %s" % [alvo_trilha["id"], str(achou)])
	_conferir(colecao.tem("sinais", "pegadas_ao_contrario"), "o sinal 'pegadas ao contrário' não foi para o caderno")
	var assobio := false
	for no in jogo.get_children():
		if no is AudioStreamPlayer3D and (no as AudioStreamPlayer3D).stream != null and (no as AudioStreamPlayer3D).stream.resource_path.ends_with("curupira_assobio.mp3"):
			assobio = true
	_conferir(assobio, "o assobio do Curupira não tocou no mundo (AudioStreamPlayer3D com curupira_assobio.mp3)")
	_conferir(not loucura.pode_iniciar(), "a loucura devia esfriar depois de começar (cooldown)")
	# 4d. Pisar de novo, no meio da loucura e depois dela, não recomeça: a mesma conta, o mesmo `achou`.
	_conferir(rastro.pisou(alvo_trilha, onde_pisar) == false, "pisar de novo recomeçou a loucura")
	_conferir(achou.size() == 1, "pisar de novo avisou outra vez")

	# --- 5. A LOUCURA É DE VERDADE ----------------------------------------------
	var bussola: Control = null
	for no in jogo.find_children("Minimapa", "", true, false):
		bussola = no as Control
	_conferir(bussola != null and not bussola._sem_mapa, "o vale não tem a bússola com a foto do mapa")
	var seta = jogo.get("_seta")
	_conferir(seta != null, "o vale não tem a seta da missão")
	if bussola == null or bussola._sem_mapa or seta == null:
		_fechar()
		return
	var aqui: Vector3 = jogador.global_position
	var meio: Vector2 = bussola._sobre.size * 0.5
	var escala: float = bussola._sobre.size.y / bussola.VISTA
	var alvo_do_mapa := aqui + Vector3(8.0, 0.0, 0.0)
	# A seta e o chevron: o alvo bem atrás da câmera, para o chevron prender na borda e apontar o rumo.
	var atras: Vector3 = aqui + (jogador.camera.global_basis.z * Vector3(1.0, 0.0, 1.0)).normalized() * 70.0
	seta.definir_alvo(atras, "")
	await relogio.esperar(0.3)
	print("  seta: alvo atual %s, posição %s" % [str(seta.alvo_atual()), str((seta as Node3D).global_position)])
	# Os valores "de sempre" (antes da loucura pegar de vez são os mesmos dela terminada): o portão os lê DEPOIS.
	var rotacao_max := 0.0
	var escorregou_max := 0.0
	var losango_max := 0.0
	var seta_longe_max := 0.0
	var chevron_amostras: Array[float] = []
	var centro_certo: Vector2 = bussola.centro_da_vista(aqui)
	# Espera a loucura subir ao máximo (2 s) e amostra 8 s, a cada quarto de segundo de jogo.
	var inicio: float = relogio.agora()
	await relogio.ate(func() -> bool: return loucura.intensidade() >= 0.999, 4.0)
	_conferir(loucura.intensidade() >= 0.999, "a loucura não chegou ao máximo em 4 s (intensidade %.2f)" % loucura.intensidade())
	var amostras := 0
	while relogio.agora() - inicio < 8.0:
		await relogio.esperar(0.25)
		amostras += 1
		rotacao_max = maxf(rotacao_max, absf(float(bussola._material.get_shader_parameter("rotacao"))))
		escorregou_max = maxf(escorregou_max, (bussola._material.get_shader_parameter("centro_uv") as Vector2).distance_to(centro_certo))
		var losango: Vector2 = bussola._no_quadro(alvo_do_mapa, meio, escala)
		losango_max = maxf(losango_max, losango.distance_to(meio + Vector2(8.0, 0.0) * escala))
		if seta.alvo_atual() != null:
			seta_longe_max = maxf(seta_longe_max, (seta as Node3D).global_position.distance_to(seta.alvo_atual()))
		chevron_amostras.append(seta._chevron.rotation)
	_conferir(rotacao_max > 0.3, "a bússola não girou com o mapa louco (giro máximo %.2f rad)" % rotacao_max)
	_conferir(escorregou_max > 0.01, "a foto da bússola continuou centrada no jogador (desvio máximo %.4f da foto)" % escorregou_max)
	_conferir(losango_max > 8.0, "o losango da missão não pulou da posição certa (máximo %.1f px)" % losango_max)
	_conferir(seta_longe_max > 2.0, "o cone da seta da missão continuou sobre o alvo (máximo %.2f u)" % seta_longe_max)
	print("  mapa doido: giro até %.2f rad, foto fora do jogador até %.3f, losango até %.0f px, cone até %.1f u" % [rotacao_max, escorregou_max, losango_max, seta_longe_max])
	# O MAPA GRANDE: gira, o "Você" vira "???" e os nomes trocam de dono.
	var mapa = jogo.get("mapa")
	mapa.abrir(world, jogador, jogo.get("hud_layer"))
	await relogio.esperar(0.4)
	var nomes_certos: Array[String] = []
	for entrada: Dictionary in mapa._marcadores:
		nomes_certos.append("● " + String(entrada["nome"]))
	_conferir(nomes_certos.size() >= 3, "o mapa grande tem só %d marcadores" % nomes_certos.size())
	var girou_mais := 0.0
	var trocou := false
	var perdido := false
	for i in range(24):
		await relogio.esperar(0.25)
		girou_mais = maxf(girou_mais, mapa._camera.global_basis.y.angle_to(Vector3(0.0, 0.0, -1.0)))
		perdido = perdido or String(mapa._voce.text) == "▼ ???"
		for k in range(mapa._marcadores.size()):
			if String((mapa._marcadores[k]["control"] as Button).text) != nomes_certos[k]:
				trocou = true
	_conferir(girou_mais > 0.3, "o mapa grande não girou (o 'cima' dele saiu só %.2f rad do norte)" % girou_mais)
	_conferir(perdido, "o 'Você' do mapa grande não virou '???'")
	_conferir(trocou, "os nomes dos lugares no mapa grande não trocaram de dono")

	# --- 6. E PASSA -------------------------------------------------------------
	# A duração e a curva, num nó à parte (o do vale esfriou): sobe, fica, desce, e zera EXATO.
	_conferir(loucura.DURACAO >= 60.0 and loucura.DURACAO <= 90.0, "a loucura dura %.0f s: o pedido é de uns 60 a 90" % loucura.DURACAO)
	var curva := Node.new()
	curva.set_script(load("res://scripts/prototipo_3d/loucura_do_mapa.gd"))
	root.add_child(curva)
	_conferir(curva.intensidade() == 0.0 and curva.rotacao_do_mapa() == 0.0 and curva.deriva_do_mapa() == Vector2.ZERO and curva.erro_da_seta() == 0.0,
		"a loucura que nem começou já mexe no mapa")
	_conferir(curva.iniciar(10.0), "a loucura não começou")
	await relogio.esperar(2.4)
	var no_alto: float = curva.intensidade()
	await relogio.esperar(5.0)
	var na_descida: float = curva.intensidade()
	await relogio.ate(func() -> bool: return not curva.ativa(), 6.0)
	_conferir(no_alto >= 0.999, "aos 2,4 s a loucura devia estar no máximo, e estava em %.2f" % no_alto)
	_conferir(na_descida > 0.0 and na_descida < 1.0, "aos 7,4 s de 10 a loucura devia estar descendo, e estava em %.2f" % na_descida)
	_conferir(not curva.ativa() and curva.intensidade() == 0.0, "a loucura não terminou na duração")
	_conferir(curva.rotacao_do_mapa() == 0.0 and curva.deriva_do_mapa() == Vector2.ZERO and curva.erro_da_seta() == 0.0 and curva.deriva_do_alvo() == Vector2.ZERO,
		"terminada, a loucura ainda mexe no mapa")
	curva.queue_free()
	# O do vale: termina, e a bússola, o mapa grande e a seta voltam EXATOS.
	loucura.terminar()
	await relogio.esperar(0.5)
	_conferir(not loucura.ativa(), "a loucura do vale não terminou")
	_conferir(String(mapa._voce.text) == "▼ Você", "o 'Você' do mapa grande não voltou: '%s'" % mapa._voce.text)
	for k in range(mapa._marcadores.size()):
		_conferir(String((mapa._marcadores[k]["control"] as Button).text) == nomes_certos[k] or k >= nomes_certos.size(), "o nome do lugar %d não voltou ao dono" % k)
	_conferir(mapa._camera.global_basis.y.angle_to(Vector3(0.0, 0.0, -1.0)) < 0.001, "o norte do mapa grande não voltou para cima")
	mapa.fechar()
	await relogio.esperar(0.6)
	_conferir(float(bussola._material.get_shader_parameter("rotacao")) == 0.0, "a bússola continua girada")
	_conferir((bussola._material.get_shader_parameter("centro_uv") as Vector2).is_equal_approx(bussola.centro_da_vista(jogador.global_position)),
		"a foto da bússola não voltou ao jogador")
	_conferir(bussola._no_quadro(alvo_do_mapa, meio, escala).is_equal_approx(meio + Vector2(8.0, 0.0) * escala), "o losango da bússola não voltou")
	_conferir(seta.alvo_atual() != null and (seta as Node3D).global_position.is_equal_approx(seta.alvo_atual()), "o cone da seta não voltou para cima do alvo (alvo %s, cone %s)" % [str(seta.alvo_atual()), str((seta as Node3D).global_position)])
	# O chevron assentado é o certo (o alvo não mexeu): durante a loucura ele já apontou outro lado.
	var chevron_certo: float = seta._chevron.rotation
	var chevron_max := 0.0
	for amostra in chevron_amostras:
		chevron_max = maxf(chevron_max, absf(angle_difference(amostra, chevron_certo)))
	_conferir(chevron_max > 0.5, "o chevron da seta apontou sempre para o alvo, mesmo com o mapa louco (desvio máximo %.2f rad)" % chevron_max)
	print("  chevron: até %.2f rad fora do certo durante a loucura" % chevron_max)
	seta.limpar()
	SustosDaMata.forcar_edicao = -1
	_fechar()


func _fechar() -> void:
	if SustosDaMata != null:
		SustosDaMata.forcar_edicao = -1
		if _chave_de_antes != null:
			SustosDaMata.definir_ligado(bool(_chave_de_antes))
		else:
			var preferencias := ConfigFile.new()
			if preferencias.load(SustosDaMata.PREFERENCIAS) == OK and preferencias.has_section_key("interface", "sustos"):
				preferencias.erase_section_key("interface", "sustos")
				preferencias.save(SustosDaMata.PREFERENCIAS)
	print("")
	if falhas == 0:
		print("RASTRO_DO_CURUPIRA_OK: trilhas de pegadas na mata funda (pela conta do jogo), com os dedos virados para trás no dado e no desenho; pisar no rastro enlouquece o mapa só com o jogo livre e os sustos ligados — a bússola, o mapa grande e a seta da missão —, e passa, voltando tudo exato")
	else:
		print("rastro_do_curupira: %d falha(s)" % falhas)
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
