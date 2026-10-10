extends "res://tests/suite/caso.gd"
## Confere que AS ÁRVORES DO VALE SE CORTAM, E VOLTAM EM UM ANO — e que a
## madeira e a pedra duras pedem o talento e a ferramenta de aço.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste corte_das_arvores
##
## "Pode tornar as árvores cortáveis, com respawn de 1 ano no calendário do
## jogo. Para isso ela tem que progredir até ficar 'adulta'. Também já vai
## poder vincular a progressão da árvore de habilidade para quebrar alguns
## tipos de árvores e a necessidade de ferramentas melhores para quebrar
## determinados itens como árvores e pedras." Nove perguntas:
##
##   1. TODA ÁRVORE SE CORTA: as plantadas e as da mata, da orla e da beira do
##      rio — cada tronco da região guarda a instância dele na MultiMesh.
##   2. A MADEIRA BRANCA CAI NO MACHADO DE FERRO, pela tecla de verdade, e cada
##      golpe cobra vigor, fôlego (bater × dureza) e ensina (XP). Cai em toco,
##      e rende lenha — e a copa TOMBA do toco para longe de quem cortou, deita
##      e afunda até sumir; a embaúba nova do cemitério também cai, do pé.
##   3. A MADEIRA DE LEI PEDE O TALENTO, e a recusa diz QUAIS — os nomes lidos
##      das teias, que existem de verdade. Com o talento, cai, e o golpe custa
##      o dobro e ensina como trabalho duro.
##   4. A MADEIRA DE LEI DURA PEDE O AÇO: o pau-brasil não cai no machado de
##      ferro nem com o talento; no de aço, cai.
##   5. A GAMELEIRA NÃO SE CORTA, e diz por quê.
##   6. O ANO DE CRESCER: toco, muda, nova, crescida — a malha da própria
##      árvore, crescendo do pé — e só com um ano do calendário ela está
##      adulta, inteira e com colisão, e se corta de novo. A dica não diz
##      quando ela volta.
##   7. A PARTIDA SALVA LEMBRA: cada cortada com o dia do corte, e a carga põe
##      cada uma no estágio de hoje (as de antes do toco, sem recortar toco).
##   8. A MATA TAMBÉM CRESCE: a instância da MultiMesh encolhe a nada, ganha
##      toco, cresce do pé e volta inteira.
##   9. A PEDRA DURA E O MATACÃO: o talento da picareta, e a picareta de aço.
##
##
## A ESPERA É EM SEGUNDOS DE JOGO, E NÃO DE PAREDE (`tests/fixtures/relogio_de_jogo.gd`).
##
## A copa que cai é um `Tween` de 1,5 s mais o tranco e a pausa, e o portão a
## conferia aos 1,70 s de relógio — folga de 12%. Com a física limitada a 3 passos
## por quadro (`project.godot`) o jogo anda mais devagar que a parede quando o
## quadro passa de 50 ms, e na bateria cheia passa: "a copa não deitou: tombou só
## 52 graus", num portão que passa sozinho. Agora os instantes da queda (0,75 s,
## 1,70 s e 6,50 s) são do JOGO, que é de onde o tween os conta. Com
## `MV_QUADRO_LENTO_MS=150` no ambiente o portão roda como na bateria no pior; com
## `MV_FALSIFICAR=parede` ele volta a esperar em parede, e então TEM de reprovar.

## Recebe o vale montado do zero: reprovava no vale deixado pelos casos anteriores (a suíte, #242).
const VALE_NOVO := true

const DIAS_DO_ANO := 112
const RelogioDeJogo = preload("res://tests/fixtures/relogio_de_jogo.gd")

var falhas := 0
var _xp_ganho := 0.0
## O relógio de jogo do portão (o `relogio` abaixo é o calendário do jogo).
var tempo: Node
## Os autoloads, pelo caminho: o portão compila antes de eles existirem.
var energia
var inventario
var progressao
var relogio
var venda


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("CORTE_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	tempo = RelogioDeJogo.new()
	root.add_child(tempo)
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	tempo.ficar_lento()
	var vale = current_scene
	var jogador = vale.player
	var mundo = vale.world
	var arvores = vale.get_node_or_null("ArvoresInfo")
	var recursos = vale.get_node_or_null("Recursos3D")
	_conferir(arvores != null and recursos != null, "o vale não tem ArvoresInfo ou Recursos3D")
	if arvores == null or recursos == null:
		_fechar()
		return
	root.get_node("/root/Dia").pausado = true
	energia = root.get_node("/root/Energia")
	inventario = root.get_node("/root/Inventario")
	progressao = root.get_node("/root/Progressao")
	relogio = root.get_node("/root/Relogio")
	venda = root.get_node("/root/Venda")
	root.get_node("/root/Talentos").ganhou_xp.connect(func(quanto: float) -> void: _xp_ganho += quanto)
	var regiao = mundo.get("_region")

	# --- 1. TODA ÁRVORE SE CORTA ----------------------------------------------
	var nomeadas := 0
	for arvore: Dictionary in mundo.get("_arvores_nomeadas"):
		if arvore.get("visual") != null:
			nomeadas += 1
	var troncos := 0
	var com_instancia := 0
	for tronco: Dictionary in regiao.get("_tree_trunks"):
		if str(tronco.get("especie", "")) == "":
			continue
		troncos += 1
		if tronco.get("visual") != null and int(tronco.get("instancia", -1)) >= 0 and tronco.has("transformacao"):
			com_instancia += 1
	_conferir(nomeadas > 20, "só %d árvores plantadas têm visual para cortar" % nomeadas)
	_conferir(troncos > 500, "a região só tem %d troncos: a mata não foi plantada" % troncos)
	_conferir(com_instancia == troncos, "%d de %d troncos da região sem instância registrada: esses não se cortam" % [troncos - com_instancia, troncos])
	_conferir(arvores._cortaveis.size() >= nomeadas + troncos, "o corte conhece %d árvores, e o vale tem %d" % [arvores._cortaveis.size(), nomeadas + troncos])
	print("  %d árvores plantadas e %d da região, todas com o que o corte precisa" % [nomeadas, com_instancia])

	# --- 2. A MADEIRA BRANCA CAI NO MACHADO DE FERRO -----------------------------
	var e_de_interagir := InputEventKey.new()
	e_de_interagir.physical_keycode = load("res://scripts/prototipo_3d/atalhos.gd").tecla("interagir")
	e_de_interagir.pressed = true
	_por_na_mao("machado")
	_conferir(jogador.machado_na_mao(), "o machado de ferro na mão não conta como machado")
	var branca: int = await _escolher(arvores, mundo, jogador, "mangueira", true)
	_conferir(branca >= 0, "não achei uma mangueira plantada, longe de outro dono do E, para cortar")
	if branca < 0:
		_fechar()
		return
	_conferir(arvores._recusa(branca) == "", "a mangueira, madeira branca, recusou o machado de ferro: '%s'" % arvores._recusa(branca))
	_conferir(arvores._texto_do_corte(branca).contains("Mangueira"), "a dica do corte não diz a árvore: '%s'" % arvores._texto_do_corte(branca))
	# A ÁRVORE GROSSA PEDE MAIS GOLPES E DÁ MAIS LENHA que a fina da mesma madeira (07/10: "tem
	# árvores maiores, que consomem muita stamina e vigor, mas dão o mesmo quantitativo").
	var fina := -1
	var grossa := -1
	for i in arvores._cortaveis.size():
		var arvore: Dictionary = arvores._cortaveis[i]
		if bool(arvore.get("cortado", false)) or str(arvores.madeira_de(str(arvore["especie"])).get("classe", "")) != "branca":
			continue
		if fina < 0 or float(arvore["raio"]) < float(arvores._cortaveis[fina]["raio"]):
			fina = i
		if grossa < 0 or float(arvore["raio"]) > float(arvores._cortaveis[grossa]["raio"]):
			grossa = i
	_conferir(fina >= 0 and grossa >= 0 and fina != grossa, "não achei duas árvores de madeira branca de tamanhos diferentes")
	if fina >= 0 and grossa >= 0:
		print("  madeira branca: a fina (raio %.2f) pede %d golpes e dá %d; a grossa (raio %.2f) pede %d e dá %d" % [
			float(arvores._cortaveis[fina]["raio"]), arvores.golpes_da(fina), arvores.rendimento_da(fina),
			float(arvores._cortaveis[grossa]["raio"]), arvores.golpes_da(grossa), arvores.rendimento_da(grossa)])
		_conferir(arvores.golpes_da(grossa) > arvores.golpes_da(fina) and arvores.rendimento_da(grossa) > arvores.rendimento_da(fina),
			"a árvore grossa não pede mais golpes nem dá mais lenha que a fina")
		_conferir(arvores.rendimento_da(fina) >= 1 and arvores.golpes_da(fina) >= 1, "a árvore fina não rende nem cai")
	energia.encher()
	var lenha_antes: int = inventario.quantidade("lenha")
	var folego_antes: float = energia.atual
	_xp_ganho = 0.0
	# A TECLA DE VERDADE dá o primeiro golpe: aproximação, braço, golpe. A
	# espera é em SEGUNDO REAL: o golpe sai no fim do clipe do braço, e sem
	# tela os quadros são curtos demais para contar por eles.
	arvores._unhandled_key_input(e_de_interagir)
	await tempo.ate(func() -> bool: return int(arvores._cortaveis[branca]["golpes"]) >= 1, 8.0)
	_conferir(int(arvores._cortaveis[branca]["golpes"]) >= 1, "o E perto da mangueira, com o machado na mão, não deu golpe nenhum")
	arvores._parar_golpe(true)
	var cortou_em := await _golpear_ate_cair(arvores, jogador, branca)
	_conferir(bool(arvores._cortaveis[branca]["cortado"]), "a mangueira não caiu nos golpes da madeira branca")
	# OS GOLPES E A LENHA SÃO DO TAMANHO DA ÁRVORE (07/10): a madeira branca pede 3 e dá 2 numa
	# árvore comum, vezes o tamanho desta (`tamanho_da`).
	var golpes_esperados: int = arvores.golpes_da(branca)
	var lenha_esperada: int = arvores.rendimento_da(branca)
	print("  a mangueira (raio %.2f, tamanho %.2f) pede %d golpes e dá %d de lenha" % [float(arvores._cortaveis[branca]["raio"]), arvores.tamanho_da(branca), golpes_esperados, lenha_esperada])
	_conferir(cortou_em == golpes_esperados, "a mangueira caiu com %d golpes, e o tamanho dela pede %d" % [cortou_em, golpes_esperados])
	_conferir(inventario.quantidade("lenha") == lenha_antes + lenha_esperada, "a mangueira caiu e rendeu %d de lenha, e devia render %d" % [inventario.quantidade("lenha") - lenha_antes, lenha_esperada])
	# O golpe cobra o vigor do braço ("golpe", com o "bater" dentro) e o corpo descansa
	# entre um e outro: o gasto fica entre o fôlego do dia e o golpe inteiro, os dois
	# lidos de Energia — mudar o balanço em Ajustes → Esforço não reprova o portão.
	_conferir(_gasto_coerente(energia, folego_antes - energia.atual, golpes_esperados, 1.0),
		"%d golpes de madeira branca custaram %.1f, fora de [%.1f, %.1f]" % [golpes_esperados, folego_antes - energia.atual, float(golpes_esperados) * energia.custo("bater", 1.0), float(golpes_esperados) * maxf(energia.custo("golpe"), energia.custo("bater", 1.0))])
	_conferir(is_equal_approx(_xp_ganho, 5.0 * golpes_esperados), "%d golpes de madeira branca ensinaram %.0f de XP, e são %d (bater)" % [golpes_esperados, _xp_ganho, 5 * golpes_esperados])
	var nomeada: Dictionary = _nomeada_em(mundo, arvores._cortaveis[branca]["pos"])
	_conferir(not nomeada.is_empty() and not (nomeada["visual"] as Node3D).visible, "a mangueira cortada continua de pé no mundo")
	_conferir(is_instance_valid(nomeada.get("toco")), "a mangueira cortada não deixou toco")
	_conferir(arvores.estagio_da(branca) == "toco", "a mangueira recém-cortada está no estágio '%s'" % arvores.estagio_da(branca))

	# --- 2b. ELA CAI -----------------------------------------------------------
	# "Produza a animação das árvores caindo ao cortá-las." A copa — a árvore de
	# cima do corte — tomba do toco PARA LONGE DE QUEM CORTOU, devagar no começo
	# e depressa no fim, deita e afunda até sumir sozinha.
	var caindo: Node3D = null
	for filho in mundo.get_children():
		if str(filho.name).begins_with("ArvoreCaindo") and filho.find_child("CopaCaindo", true, false) != null:
			caindo = filho
	_conferir(caindo != null, "a mangueira cortada não caiu: não há copa caindo no mundo")
	if caindo != null:
		var pe_da_mangueira: Vector3 = arvores._cortaveis[branca]["pos"]
		var de_quem_cortou: Vector3 = pe_da_mangueira - jogador.global_position
		de_quem_cortou.y = 0.0
		# OS INSTANTES SÃO DO JOGO: o tween da queda conta o delta de cada quadro, e o
		# relógio de parede só serve enquanto o quadro é curto.
		var desde_a_queda: float = tempo.agora()
		# NO MEIO DO TOMBO ela está a caminho: nem de pé, nem já deitada. Árvore
		# que some de pé e aparece deitada não caiu, foi trocada.
		while tempo.agora() - desde_a_queda < 0.75 and is_instance_valid(caindo):
			await process_frame
		if is_instance_valid(caindo):
			var no_meio := rad_to_deg((caindo.basis * Vector3.UP).angle_to(Vector3.UP))
			_conferir(no_meio > 3.0 and no_meio < 60.0, "no meio do tombo a copa está a %.0f graus: não está caindo, foi trocada" % no_meio)
		while tempo.agora() - desde_a_queda < 1.7 and is_instance_valid(caindo):
			await process_frame
		_conferir(is_instance_valid(caindo), "a copa sumiu antes de acabar de cair")
		if is_instance_valid(caindo):
			var topo: Vector3 = caindo.basis * Vector3.UP
			_conferir(rad_to_deg(topo.angle_to(Vector3.UP)) > 70.0, "a copa não deitou: tombou só %.0f graus" % rad_to_deg(topo.angle_to(Vector3.UP)))
			_conferir(Vector3(topo.x, 0.0, topo.z).dot(de_quem_cortou) > 0.0, "a copa caiu para o lado de quem cortou")
		while tempo.agora() - desde_a_queda < 6.5 and is_instance_valid(caindo):
			await process_frame
		_conferir(not is_instance_valid(caindo), "a copa caída não sumiu: continua deitada no chão")

	# --- 3. A MADEIRA DE LEI PEDE O TALENTO ---------------------------------------
	_conferir(progressao.nivel("machado") == 1, "a partida nova começou com o machado no nível %d" % progressao.nivel("machado"))
	var de_lei: int = await _escolher(arvores, mundo, jogador, "jaqueira", true)
	_conferir(de_lei >= 0, "não achei uma jaqueira plantada para cortar")
	if de_lei >= 0:
		var recusa: String = arvores._recusa(de_lei)
		_conferir(recusa.contains("Braços de machado") and recusa.contains("Ferro de Ogum"),
			"a recusa da madeira de lei não diz os talentos que a abrem: '%s'" % recusa)
		_conferir(not recusa.contains("machado de aço"), "a madeira de lei pede aço, e só pede o talento: '%s'" % recusa)
		arvores._unhandled_key_input(e_de_interagir)
		await _quadros(6)
		_conferir(int(arvores._cortaveis[de_lei]["golpes"]) == 0, "a jaqueira apanhou sem o talento")
		_conferir(arvores._cortavel_pendente < 0 and arvores._em_golpe < 0, "sem o talento, o E pôs o corpo a caminho da jaqueira")
		progressao.subir_ferramenta("machado", 2)
		_conferir(arvores._recusa(de_lei) == "", "com Braços de machado, a jaqueira ainda recusa: '%s'" % arvores._recusa(de_lei))
		energia.encher()
		folego_antes = energia.atual
		_xp_ganho = 0.0
		energia.encher()
		var golpes_de_lei := await _golpear_ate_cair(arvores, jogador, de_lei)
		_conferir(bool(arvores._cortaveis[de_lei]["cortado"]), "com o talento, a jaqueira não caiu")
		_conferir(golpes_de_lei == arvores.golpes_da(de_lei), "a jaqueira caiu com %d golpes, e o tamanho dela pede %d" % [golpes_de_lei, arvores.golpes_da(de_lei)])
		_conferir(_gasto_coerente(energia, folego_antes - energia.atual, 4, 2.0),
			"quatro golpes de madeira de lei custaram %.1f, fora de [%.1f, %.1f]" % [folego_antes - energia.atual, 4.0 * energia.custo("bater", 2.0), 4.0 * maxf(energia.custo("golpe"), energia.custo("bater", 2.0))])
		_conferir(is_equal_approx(_xp_ganho, 12.0 * golpes_de_lei), "%d golpes de madeira de lei ensinaram %.0f de XP, e são %d (bater_duro)" % [golpes_de_lei, _xp_ganho, 12 * golpes_de_lei])

	# --- 4. A MADEIRA DE LEI DURA PEDE O AÇO ----------------------------------
	var dura: int = await _escolher(arvores, mundo, jogador, "pau_brasil", true)
	_conferir(dura >= 0, "não achei o pau-brasil plantado")
	if dura >= 0:
		var sem_aco: String = arvores._recusa(dura)
		_conferir(sem_aco.contains("machado de aço") and not sem_aco.contains("Braços de machado"),
			"com o talento e o machado de ferro, o pau-brasil devia pedir só o aço: '%s'" % sem_aco)
		progressao.nivel_de_ferramenta["machado"] = 1
		var os_dois: String = arvores._recusa(dura)
		_conferir(os_dois.contains("machado de aço") and os_dois.contains("Braços de machado"),
			"sem talento e sem aço, o pau-brasil devia pedir os dois: '%s'" % os_dois)
		progressao.nivel_de_ferramenta["machado"] = 2
		_por_na_mao("machado_de_aco")
		energia.encher()
		_conferir(jogador.machado_na_mao(), "o machado de aço na mão não conta como machado")
		_conferir(arvores._recusa(dura) == "", "com o talento e o machado de aço, o pau-brasil recusa: '%s'" % arvores._recusa(dura))
		energia.encher()
		energia.encher()
		print("  antes do pau-brasil: fôlego %.1f de %.1f, golpe %.1f de vigor %.1f, bater×3 %.1f" % [energia.atual, energia.maximo(), energia.custo("golpe"), float(jogador.vigor_atual()), energia.custo("bater", 3.0)])
		var golpes_duros := await _golpear_ate_cair(arvores, jogador, dura, true)
		_conferir(bool(arvores._cortaveis[dura]["cortado"]) and golpes_duros == arvores.golpes_da(dura),
			"o pau-brasil, de machado de aço, caiu=%s em %d golpes (o tamanho dele pede %d)" % [str(arvores._cortaveis[dura]["cortado"]), golpes_duros, arvores.golpes_da(dura)])
		_por_na_mao("machado")

	# --- 5. A GAMELEIRA NÃO SE CORTA ------------------------------------------
	var gameleira := -1
	for i in arvores._cortaveis.size():
		if str(arvores._cortaveis[i]["especie"]) == "mata_larga":
			gameleira = i
			break
	if gameleira >= 0:
		_conferir(arvores._recusa(gameleira).contains("Iroko"), "a gameleira não diz por que não se corta: '%s'" % arvores._recusa(gameleira))
	var bananeira := -1
	for i in arvores._cortaveis.size():
		if str(arvores._cortaveis[i]["especie"]) == "bananeira":
			bananeira = i
			break
	_conferir(bananeira >= 0 and arvores._recusa(bananeira).contains("erva"), "a bananeira não diz que é erva e não dá lenha")

	# --- 6. O ANO DE CRESCER -----------------------------------------------------
	var visual: Node3D = nomeada["visual"]
	var inteira: Transform3D = nomeada["transformacao_original"]
	var pe: Vector3 = arvores._cortaveis[branca]["pos"]
	var desvio_inteira := _desvio_do_pe(visual, inteira, pe)
	var corte: int = int(arvores._cortaveis[branca]["dia_do_corte"])
	var esperado := {27: "toco", 28: "muda", 56: "nova", 84: "crescida", 111: "crescida"}
	var escalas := {"muda": 0.2, "nova": 0.45, "crescida": 0.75}
	for dia: int in [27, 28, 56, 84, 111]:
		await _ate_o_dia(corte + dia)
		var agora: String = arvores.estagio_da(branca)
		_conferir(agora == esperado[dia], "%d dias depois do corte a mangueira está '%s', e devia estar '%s'" % [dia, agora, esperado[dia]])
		if escalas.has(agora):
			var escala: float = escalas[agora]
			_conferir(visual.visible, "a mangueira %s não aparece" % agora)
			var proporcao: float = visual.transform.basis.get_scale().x / inteira.basis.get_scale().x
			_conferir(absf(proporcao - escala) < 0.01, "a mangueira %s está em %.2f do tamanho, e devia estar em %.2f" % [agora, proporcao, escala])
			# CRESCE DO PÉ: o desvio da árvore em relação ao pé — de lado e de
			# altura — encolhe junto com ela. Muda que encolhe em volta de outro
			# ponto flutua ou afunda, e sai de lado do toco.
			var desvio := _desvio_do_pe(visual, visual.transform, pe)
			_conferir(desvio.distance_to(desvio_inteira * escala) < 0.2,
				"a mangueira %s não cresce do pé: o centro e o fundo dela estão a %s do pé, e deviam estar a %s" % [agora, str(desvio), str(desvio_inteira * escala)])
			_conferir(not is_instance_valid(nomeada.get("toco")) or not (nomeada["toco"] as Node3D).is_inside_tree() or (nomeada["toco"] as Node3D).is_queued_for_deletion(),
				"a mangueira %s ainda tem o toco embaixo" % agora)
		if dia == 111:
			# A DICA NÃO DIZ QUANDO VOLTA: "não informe no texto o tempo que o pé de
			# árvore estará em pé novamente". Nem dias, nem número nenhum.
			var dica: String = arvores._texto_do_corte(branca)
			_conferir(RegEx.create_from_string("[0-9]").search(dica) == null, "a dica da árvore cortada diz quando ela volta: '%s'" % dica)
			_conferir(dica.contains("Mangueira"), "a dica da árvore cortada não diz que árvore é: '%s'" % dica)
			await _ir_para(arvores, jogador, branca)
			arvores._unhandled_key_input(e_de_interagir)
			await _quadros(3)
			_conferir(arvores._cortavel_pendente < 0 and arvores._em_golpe < 0, "a mangueira ainda crescendo aceitou o machado")
	await _ate_o_dia(corte + DIAS_DO_ANO)
	_conferir(arvores.estagio_da(branca) == "adulta", "um ano depois do corte a mangueira está '%s'" % arvores.estagio_da(branca))
	nomeada = _nomeada_em(mundo, pe)
	_conferir(visual.visible and visual.transform.is_equal_approx(inteira), "a mangueira adulta não voltou ao tamanho de antes do corte")
	await _quadros(2)
	_conferir(_colisao_ligada(nomeada), "a mangueira adulta voltou sem colisão")
	_conferir(not bool(arvores._cortaveis[branca]["cortado"]) and int(arvores._cortaveis[branca]["golpes"]) == 0, "a mangueira adulta não está pronta para o machado")
	_por_na_mao("machado")
	await _ir_para(arvores, jogador, branca)
	energia.encher()
	energia.encher()
	_conferir(await _golpear_ate_cair(arvores, jogador, branca, true) == arvores.golpes_da(branca) and bool(arvores._cortaveis[branca]["cortado"]), "a mangueira adulta não se cortou de novo")

	# --- 7. A PARTIDA SALVA LEMBRA ------------------------------------------------
	var salvo: Array = arvores.estado_para_salvar()
	var achou_no_save := false
	for registro: Dictionary in salvo:
		var onde: Array = registro.get("pos", [])
		if onde.size() == 3 and Vector2(float(onde[0]), float(onde[2])).distance_to(Vector2(pe.x, pe.z)) < 0.1:
			achou_no_save = int(registro.get("dia", -1)) == relogio.dia_absoluto()
	_conferir(achou_no_save, "o save não guarda a mangueira cortada com o dia do corte: %s" % str(salvo))
	var hoje: int = relogio.dia_absoluto()
	var nova: int = _de_pe_da_especie(arvores, mundo, "cajueiro", 0)
	var velha: int = _de_pe_da_especie(arvores, mundo, "cajueiro", 1)
	var do_coqueiro: int = _de_pe_da_especie(arvores, mundo, "coqueiro", 0)
	_conferir(nova >= 0 and velha >= 0 and do_coqueiro >= 0, "não achei dois cajueiros e um coqueiro plantados de pé para a carga")
	if nova >= 0 and velha >= 0 and do_coqueiro >= 0:
		arvores.restaurar_do_save([
			{"pos": _lista(arvores._cortaveis[nova]["pos"]), "dia": hoje - 60},
			{"pos": _lista(arvores._cortaveis[velha]["pos"]), "dia": hoje - 200},
			# O save do coqueiro de 24 horas, sem o dia: conta o corte de hoje.
			{"pos": _lista(arvores._cortaveis[do_coqueiro]["pos"]), "regenera_em_horas": 99.0},
		])
		_conferir(arvores.estagio_da(nova) == "nova", "o cajueiro cortado há 60 dias voltou da carga '%s'" % arvores.estagio_da(nova))
		var na_carga: Dictionary = _nomeada_em(mundo, arvores._cortaveis[nova]["pos"])
		_conferir(not is_instance_valid(na_carga.get("toco")), "a carga recortou toco para uma árvore que já passou dele")
		_conferir(arvores.estagio_da(velha) == "adulta", "o cajueiro cortado há 200 dias voltou da carga cortado")
		_conferir(arvores.estagio_da(do_coqueiro) == "toco", "o coqueiro do save antigo voltou '%s', e devia ser toco de hoje" % arvores.estagio_da(do_coqueiro))
		_conferir(is_instance_valid(_nomeada_em(mundo, arvores._cortaveis[do_coqueiro]["pos"]).get("toco")), "o coqueiro do save antigo voltou sem toco")

	# --- 8. A MATA TAMBÉM CRESCE --------------------------------------------------
	var da_mata := -1
	for i in regiao._tree_trunks.size():
		var tronco: Dictionary = regiao._tree_trunks[i]
		if str(tronco.get("especie", "")) == "embauba" and not bool(tronco.get("cortado", false)) and tronco.get("visual") != null:
			da_mata = i
			break
	_conferir(da_mata >= 0, "não achei uma embaúba da mata")
	if da_mata >= 0:
		var tronco: Dictionary = regiao._tree_trunks[da_mata]
		var ponto: Vector2 = tronco["point"]
		var onde := Vector3(ponto.x, float(tronco["ground"]), ponto.y)
		# O QUE A INSTÂNCIA MOSTRA, pelo tronco: sem tela, a MultiMesh não devolve
		# a transformação (o servidor de renderização dos portões não a guarda), e
		# o tronco guarda a que pôs nela (`_mostrar_instancia`).
		var inteira_da_mata: Transform3D = tronco["transformacao"]
		var antes := Time.get_ticks_msec()
		_conferir(mundo.cortar_arvore(onde), "a embaúba da mata não se cortou")
		print("  recortar o toco da embaúba levou %d ms" % (Time.get_ticks_msec() - antes))
		tronco = regiao._tree_trunks[da_mata]
		_conferir((tronco["transformacao"] as Transform3D).basis.get_scale().x < 0.001, "a embaúba cortada continua de pé na MultiMesh")
		_conferir(is_instance_valid(tronco.get("toco")), "a embaúba cortada não deixou toco")
		_conferir(mundo.crescer_arvore(onde, 0.45), "a embaúba não cresceu")
		var crescendo: Transform3D = regiao._tree_trunks[da_mata]["transformacao"]
		_conferir(absf(crescendo.basis.get_scale().x / inteira_da_mata.basis.get_scale().x - 0.45) < 0.01, "a embaúba nova não está em 0,45 do tamanho")
		var afundada: float = regiao.get_script().ARVORE_AFUNDADA
		var pe_da_mata: Vector3 = (tronco["visual"] as Node3D).global_transform.affine_inverse() * regiao.to_global(Vector3(ponto.x, float(tronco["ground"]) - afundada, ponto.y))
		_conferir((crescendo * inteira_da_mata.affine_inverse() * pe_da_mata).distance_to(pe_da_mata) < 0.01, "a embaúba não cresce do pé")
		await _quadros(2)
		_conferir(not is_instance_valid(regiao._tree_trunks[da_mata].get("toco")), "a embaúba nova ainda tem o toco")
		_conferir(mundo.restaurar_arvore(onde), "a embaúba não voltou adulta")
		_conferir((regiao._tree_trunks[da_mata]["transformacao"] as Transform3D).is_equal_approx(inteira_da_mata), "a embaúba adulta não é a de antes do corte")

	# --- 9. A PEDRA DURA E O MATACÃO --------------------------------------------
	var recusas: Array[String] = []
	recursos.recusado.connect(func(motivo: String) -> void: recusas.append(motivo))
	_por_na_mao("picareta")
	for id in ["pedra_dura_mirante_a", "pedra_dura_capela_a", "matacao_mirante", "matacao_capela"]:
		_conferir(recursos._alvos.has(id), "o alvo '%s' não foi posto no vale" % id)
	if recursos._alvos.has("pedra_dura_mirante_a") and recursos._alvos.has("matacao_mirante"):
		await _encostar(recursos, jogador, "pedra_dura_mirante_a")
		energia.encher()
		recusas.clear()
		_conferir(not recursos.bater(), "a pedra dura quebrou sem o talento da picareta")
		_conferir(recusas.size() == 1 and recusas[0].contains("Mão de pedra") and recusas[0].contains("Pedra de Xangô"),
			"a recusa da pedra dura não diz os talentos que a abrem: %s" % str(recusas))
		progressao.subir_ferramenta("picareta", 2)
		folego_antes = energia.atual
		_conferir(recursos.bater(), "com Mão de pedra, a pedra dura não apanhou")
		await _esperar_golpe(recursos)
		_conferir(is_equal_approx(folego_antes - energia.atual, energia.custo("bater", 2.0)), "o golpe na pedra dura não custou bater × 2")
		await _encostar(recursos, jogador, "matacao_mirante")
		recusas.clear()
		_conferir(not recursos.bater(), "o matacão quebrou com a picareta de ferro")
		_conferir(recusas.size() == 1 and recusas[0].contains("Picareta de aço"), "a recusa do matacão não pede a picareta de aço: %s" % str(recusas))
		_por_na_mao("picareta_de_aco")
		_conferir(recursos._perto == "matacao_mirante", "com a picareta de aço o matacão saiu do alcance")
		_conferir(recursos.bater(), "o matacão não apanhou da picareta de aço")
		await _esperar_golpe(recursos)
		_conferir(venda.mercadorias().has("machado_de_aco") and venda.mercadorias().has("picareta_de_aco"), "a venda não vende o aço")

	# --- 10. O TOCO É DE TRONCO, E NÃO DE COPA --------------------------------
	# "Quando cortei a pitangueira, ficou uma mesa no lugar dela." O corte nos
	# 0,85 de sempre passava pela copa dela, e a madeira exposta saía do
	# tamanho da copa: um tampo redondo de dois metros em cima do tronco fino.
	# Uma árvore de cada espécie plantada: o corte à mostra é de tronco, e o
	# toco não passa da altura de sempre.
	var vistas := {}
	for arvore: Dictionary in mundo.get("_arvores_nomeadas"):
		var especie := str(arvore["especie"])
		if vistas.has(especie) or bool(arvore.get("cortado", false)):
			continue
		vistas[especie] = true
		var pe_dela: Vector3 = arvore["pos"]
		if not mundo.cortar_arvore(pe_dela):
			continue
		var toco: Node3D = arvore.get("toco")
		var exposta: MeshInstance3D = toco.find_child("MadeiraExposta", true, false) if toco != null else null
		_conferir(exposta != null, "o toco da %s não tem o corte à mostra" % especie)
		if exposta != null:
			# A pitangueira tem tronco fino (o tampo dela tinha 1,0 de raio); a
			# gameleira da linha do terreiro tem tronco de quase dois metros.
			var raio_do_corte: float = (exposta.mesh as CylinderMesh).top_radius
			var no_maximo := 0.35 if especie == "pitangueira" else 1.0
			_conferir(raio_do_corte <= no_maximo, "o corte do toco da %s tem %.2f de raio: é tampo, e não tronco" % [especie, raio_do_corte])
			_conferir(exposta.position.y <= 0.9, "o toco da %s ficou com %.2f de altura" % [especie, exposta.position.y])
			print("  toco da %-12s corte de %.2f de raio a %.2f do chão" % [especie, raio_do_corte, exposta.position.y])
		mundo.restaurar_arvore(pe_dela)
	_conferir(vistas.has("pitangueira"), "não achei a pitangueira plantada para conferir o toco dela")

	# --- 11. A EMBAÚBA NOVA DO CEMITÉRIO TAMBÉM CAI -----------------------------
	# É alvo de trabalho (`Recursos3D`), e não árvore do vale: cai inteira, do
	# pé, quando o último golpe a derruba (`"cai": true` no JSON).
	if recursos._alvos.has("embauba_cemiterio_a"):
		_por_na_mao("machado")
		await _encostar(recursos, jogador, "embauba_cemiterio_a")
		var embauba: Node3D = recursos._alvos["embauba_cemiterio_a"]["no"]
		var golpes_dela := int(recursos._alvos["embauba_cemiterio_a"]["ficha"].get("golpes", 3))
		for i in golpes_dela:
			energia.encher()
			if recursos.bater():
				await _esperar_golpe(recursos)
		_conferir(is_instance_valid(embauba) and embauba.get_parent() != null and str(embauba.get_parent().name).begins_with("ArvoreCaindo"),
			"a embaúba nova do cemitério sumiu em vez de cair")
	_fechar()


## Põe o item na mão pela barra, como o jogador faz.
func _por_na_mao(id: String) -> void:
	if not inventario.tem(id):
		inventario.adicionar(id, 1)
	for i in inventario.ESPACOS_MAO:
		if str((inventario.espacos[i] as Dictionary).get("id", "")) == id:
			if inventario.selecionado != i:
				inventario.selecionar(i)
			return


## A árvore plantada desta espécie, de pé, a que o corte pode chegar: o jogador
## vai até ela e a tecla é do corte (nenhum outro dono do E por perto).
func _escolher(arvores, mundo, jogador, especie: String, plantada: bool) -> int:
	for i in arvores._cortaveis.size():
		var arvore: Dictionary = arvores._cortaveis[i]
		if str(arvore["especie"]) != especie or bool(arvore["cortado"]):
			continue
		if plantada and _nomeada_em(mundo, arvore["pos"]).is_empty():
			continue
		await _ir_para(arvores, jogador, i)
		if arvores._cortavel_perto == i and arvores._corte_vale_a_tecla():
			return i
	return -1


func _ir_para(arvores, jogador, indice: int) -> void:
	var pos: Vector3 = arvores._cortaveis[indice]["pos"]
	var mundo = current_scene.world
	for angulo in [0.0, PI * 0.5, PI, PI * 1.5]:
		var lado := Vector3(sin(angulo), 0.0, cos(angulo)) * (float(arvores._cortaveis[indice]["raio"]) + 1.2)
		jogador.teleportar(mundo.ground_position(pos + lado, 0.07), angulo + PI)
		await _quadros(4)
		if arvores._cortavel_perto == indice:
			return


## Golpe a golpe até cair, pelo mesmo `_ao_golpe_concluido` que a animação
## chama: o braço é do jogador, e a conta é o que se mede. Devolve com quantos
## golpes ela caiu, contando os que a tecla já tinha dado (0 se não caiu).
func _golpear_ate_cair(arvores, jogador, indice: int, encher_o_folego: bool = false) -> int:
	for i in 12:
		if bool(arvores._cortaveis[indice]["cortado"]):
			break
		if encher_o_folego:
			root.get_node("/root/Energia").encher()
		jogador.set("_vigor", 100.0)
		arvores._stamina = 100.0
		arvores._em_golpe = indice
		arvores._golpes_restantes_na_acao = 1
		arvores._ao_golpe_concluido()
		await process_frame
	arvores._parar_golpe(true)
	return int(arvores._cortaveis[indice]["golpes"]) if bool(arvores._cortaveis[indice]["cortado"]) else 0


## O golpe do `Recursos3D` até o fim: o impacto cai em 1,5 s de jogo; o resto é folga.
func _esperar_golpe(recursos) -> void:
	await tempo.ate(func() -> bool: return tempo.golpe_acabou(recursos), tempo.janela(6.0, 2.5))


func _encostar(recursos, jogador, id: String) -> void:
	jogador.global_position = recursos._alvos[id]["pos"]
	await _quadros(4)
	_conferir(recursos._perto == id, "de cima de '%s', o alvo perto é '%s'" % [id, recursos._perto])


## Vira os dias pelo calendário de verdade (`relogio.dormir`, que a cama chama).
func _ate_o_dia(dia: int) -> void:
	while relogio.dia_absoluto() < dia:
		relogio.dormir()
	await _quadros(2)


func _nomeada_em(mundo, pos: Vector3) -> Dictionary:
	for arvore: Dictionary in mundo.get("_arvores_nomeadas"):
		var pe: Vector3 = arvore["pos"]
		if Vector2(pe.x, pe.z).distance_to(Vector2(pos.x, pos.z)) < 0.1:
			return arvore
	return {}


func _de_pe_da_especie(arvores, mundo, especie: String, pular: int) -> int:
	var vistos := 0
	for i in arvores._cortaveis.size():
		var arvore: Dictionary = arvores._cortaveis[i]
		if str(arvore["especie"]) != especie or bool(arvore["cortado"]) or _nomeada_em(mundo, arvore["pos"]).is_empty():
			continue
		if vistos == pular:
			return i
		vistos += 1
	return -1


## Onde ficam o centro (de lado) e o fundo (de altura) das malhas da árvore em
## relação ao pé, com a árvore posta na transformação dada.
func _desvio_do_pe(visual: Node3D, transformacao: Transform3D, pe: Vector3) -> Vector3:
	var antes := visual.transform
	visual.transform = transformacao
	var caixa := AABB()
	var primeira := true
	var malhas: Array = visual.find_children("*", "MeshInstance3D", true, false)
	if visual is MeshInstance3D:
		malhas.append(visual)
	for malha: MeshInstance3D in malhas:
		var global := malha.global_transform * malha.get_aabb()
		caixa = global if primeira else caixa.merge(global)
		primeira = false
	visual.transform = antes
	var centro := caixa.get_center()
	return Vector3(centro.x - pe.x, caixa.position.y - pe.y, centro.z - pe.z)


func _colisao_ligada(arvore: Dictionary) -> bool:
	var corpo := arvore.get("colisao") as StaticBody3D
	if corpo == null:
		return true
	for filho in corpo.get_children():
		if filho is CollisionShape3D and (filho as CollisionShape3D).disabled:
			return false
	return true


func _lista(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("CORTE_OK: toda árvore do vale se corta e tomba para longe de quem cortou, a madeira branca no machado de ferro, a de lei com o talento e a de lei dura com o aço; a gameleira e a bananeira dizem por que não; a cortada cresce do pé em toco, muda, nova e crescida e só volta adulta com um ano do calendário; o save guarda o dia do corte; a mata cresce do pé; e a pedra dura pede o talento e o matacão, a picareta de aço")
	else:
		print("corte das árvores: %d falha(s)" % falhas)
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


## O gasto de `golpes` golpes numa madeira de `dureza`: ao menos o fôlego do dia
## (bater x dureza) e no máximo o golpe inteiro do braço, os dois de Energia.
func _gasto_coerente(energia, gasto: float, golpes: int, dureza: float) -> bool:
	var minimo: float = golpes * energia.custo("bater", dureza)
	var maximo: float = golpes * maxf(energia.custo("golpe"), energia.custo("bater", dureza))
	return gasto >= minimo - 0.01 and gasto <= maximo + 0.01
