extends SceneTree
## Confere O FOCO DO E (scripts/prototipo_3d/foco_do_e.gd): de tudo o que responde
## ao E, um só leva a tecla — o da frente do jogador, e mais perto.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/foco_do_e.gd
##
## "Ao tentar interagir com o cordel e tem um NPC próximo, ele foca somente na
## seleção do NPC e não consigo clicar no cordel. Imagino que o mesmo acontece
## com outras coisas no jogo." Sete perguntas, com a tecla de verdade (pela
## janela, `push_input`), e não chamando a fonte pela mão:
##
##   1. O CORDEL COM GENTE DO LADO: o cordel da ponta do píer, o Tonho a dois
##      passos de lado; virado para o cordel, o foco é do cordel, só a dica dele
##      acende, e o E o pega — o Tonho não abre a boca.
##   2. VIRANDO-SE, O E MUDA DE DONO: com o cordel às costas e o Tonho na frente,
##      o foco é do Tonho, e só a dica dele acende.
##   3. TODA FONTE RESPONDE À PERGUNTA: o morador, o achado, a árvore, a lápide,
##      o alvo de trabalho, a bancada, o marco, a lavoura, a casa, a pesca e a
##      luta estão no grupo do foco e dizem o que fariam (`alvo_do_e`).
##   4. A CONTA PESA O RUMO: na mesma distância, o da frente vence o de lado, e o
##      de lado vence o de costas; o viés do que está aberto vence tudo.
##   5. A BARRA DE MÃO COME SÓ SEM DONO: com o foco em alguém, o E não come o que
##      está na mão.
##   6. O MORADOR QUE O PASSO PEDE VENCE O MAIS PERTO: o passo manda falar com o
##      Tonho, o Pedro está colado no jogador (e o Tonho a dois passos): o E da
##      conversa é do Tonho, e é nele que o passo fecha. Sem passo pedindo ninguém,
##      volta a valer o mais perto. A regra da ordem (o que a fila diz, quem fala
##      antes de quem só acena, o mais perto) se confere sem mundo.
##   7. A DICA NÃO FICA ONDE O E NÃO VALE: com a dica do Tonho acesa, o J abre a tela
##      e o vale para — as fontes param com ele, e a dica ficava congelada por cima
##      do que abriu —; nenhuma dica fica acesa com a tela aberta, e a do Tonho volta
##      ao fechar. O mesmo quando algo cobre o vale sem parar a árvore (a festa da
##      missão, a voz do mundo: `coberto`).

const FocoDoE = preload("res://scripts/prototipo_3d/foco_do_e.gd")
const CORDEL := "moleque_do_pier"

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("FOCO_DO_E_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	var vale = current_scene
	var jogador = vale.player
	var foco = vale.get("foco_do_e")
	var achados = vale.get("achados")
	var moradores = vale.get("tecla_dos_moradores")
	var colecao = root.get_node("/root/Colecao")
	root.get_node("/root/Dia").pausado = true
	_conferir(foco != null and achados != null and moradores != null,
		"o vale não tem o foco do E (%s), os achados (%s) ou o E dos moradores (%s)" % [str(foco), str(achados), str(moradores)])
	if foco == null or achados == null or moradores == null:
		_fechar()
		return

	# --- 3. TODA FONTE RESPONDE À PERGUNTA ----------------------------------------------
	var fontes := get_nodes_in_group(FocoDoE.GRUPO)
	var nomes: Array[String] = []
	for fonte in fontes:
		nomes.append(str(fonte.name))
		_conferir(fonte.has_method("alvo_do_e"), "%s está no grupo do foco e não responde o que faria com o E" % fonte.name)
	for esperada in ["TeclaDosMoradores", "Achados", "Recursos3D", "TeclaDasBancadas", "Luta"]:
		_conferir(nomes.any(func(n: String) -> bool: return n.begins_with(esperada)),
			"%s não está no grupo do foco: o E dele ainda se decide pela ordem dos nós (grupo: %s)" % [esperada, ", ".join(nomes)])
	_conferir(fontes.size() >= 10, "só %d fonte(s) do E respondem ao foco; são onze as que aceitam o E no vale" % fontes.size())

	# --- 4. A CONTA PESA O RUMO ---------------------------------------------------------
	var de := Vector3.ZERO
	var frente := Vector3(0, 0, 1)
	var na_frente: float = FocoDoE.conta_do_alvo({"ponto": Vector3(0, 0, 2)}, de, frente)
	var de_lado: float = FocoDoE.conta_do_alvo({"ponto": Vector3(2, 0, 0)}, de, frente)
	var de_costas: float = FocoDoE.conta_do_alvo({"ponto": Vector3(0, 0, -2)}, de, frente)
	var aberto: float = FocoDoE.conta_do_alvo({"ponto": Vector3(0, 0, -2), "vies": 100.0}, de, frente)
	_conferir(na_frente < de_lado and de_lado < de_costas,
		"na mesma distância, a conta não favorece a frente: frente %.2f, lado %.2f, costas %.2f" % [na_frente, de_lado, de_costas])
	_conferir(aberto < na_frente, "o viés do que está aberto não vence o da frente")
	# DE PERTO, VIRAR O CORPO ESCOLHE: o morador um passo à frente ganha do cordel
	# colado no pé, de lado. Com o rumo multiplicando a distância, o colado ganhava.
	var um_passo_a_frente: float = FocoDoE.conta_do_alvo({"ponto": Vector3(0, 0, 1.2)}, de, frente)
	var colado_de_lado: float = FocoDoE.conta_do_alvo({"ponto": Vector3(0.4, 0, 0)}, de, frente)
	_conferir(um_passo_a_frente < colado_de_lado,
		"de perto, o que está colado de lado ganha do que está um passo à frente: virar o corpo não escolhe (frente %.2f, lado %.2f)" % [um_passo_a_frente, colado_de_lado])

	# --- 1. O CORDEL COM GENTE DO LADO --------------------------------------------------
	var tonho = vale._achar_morador("tonho")
	var cordel: Vector3 = achados.ponto_do_cordel(CORDEL)
	var no_chao := false
	for achado in achados.no_chao:
		if str(achado.get("id", "")) == CORDEL:
			no_chao = true
	_conferir(tonho != null and cordel.is_finite() and no_chao, "não há o Tonho (%s) ou o cordel da ponta do píer no chão" % str(tonho))
	if tonho == null or not cordel.is_finite() or not no_chao:
		_fechar()
		return
	# O jogador a um passo do cordel, olhando para ele; o Tonho a dois passos, de lado.
	var ao_longo: Vector3 = vale.world.ancoras.get("PierDirecao", Vector3.FORWARD)
	ao_longo.y = 0.0
	ao_longo = ao_longo.normalized() if ao_longo.length() > 0.01 else Vector3.FORWARD
	var de_lado_no_pier := Vector3(-ao_longo.z, 0.0, ao_longo.x)
	var onde_fico: Vector3 = cordel - ao_longo * 1.0
	var onde_o_tonho: Vector3 = onde_fico + de_lado_no_pier * 2.0
	tonho.ir_ate(onde_o_tonho, 1.0)
	tonho.global_position = onde_o_tonho + Vector3.UP * 0.1
	jogador.teleportar(onde_fico + Vector3.UP * 0.3, atan2(ao_longo.x, ao_longo.z))
	await _passos_de_fisica(20)
	tonho.global_position = onde_o_tonho + Vector3.UP * 0.1
	await _quadros(3)
	_conferir(moradores._ao_alcance() == tonho,
		"o Tonho não está ao alcance da conversa (%s): o caso do cordel com gente do lado não se montou" % str(moradores._ao_alcance()))
	_conferir(foco.dono() == achados, "virado para o cordel, com o Tonho de lado, o E é de '%s', e não do cordel" % _nome(foco.dono()))
	_conferir(_dica_acesa(achados) and not _dica_acesa(moradores),
		"virado para o cordel, as dicas acesas não são só a dele (cordel: %s, Tonho: %s)" % [str(_dica_acesa(achados)), str(_dica_acesa(moradores))])
	_conferir(_dicas_acesas() <= 1, "%d dicas do E acesas ao mesmo tempo: só uma aceita a tecla" % _dicas_acesas())
	var falava: bool = tonho._balao_tempo > 0.0
	_apertar_e()
	await _quadros(3)
	_conferir(colecao.tem("cordeis", CORDEL), "virado para o cordel, o E não o pegou: o Tonho do lado ainda leva a tecla")
	_conferir(falava or tonho._balao_tempo <= 0.0, "o E que pegou o cordel fez o Tonho conversar também")

	# --- 2. VIRANDO-SE, O E MUDA DE DONO ------------------------------------------------
	# O cordel pego abre o papel dele por cima do vale (`ler_o_folheto`), e o vale
	# para atrás: guarda-se o papel, como o jogador, e o vale volta a andar.
	await _guardar_o_que_abriu(vale)
	jogador.teleportar(onde_fico + Vector3.UP * 0.3, atan2(de_lado_no_pier.x, de_lado_no_pier.z))
	tonho.global_position = onde_o_tonho + Vector3.UP * 0.1
	await _passos_de_fisica(10)
	tonho.global_position = onde_o_tonho + Vector3.UP * 0.1
	await _quadros(3)
	_conferir(foco.dono() == moradores, "virado para o Tonho, o E é de '%s', e não dele" % _nome(foco.dono()))
	_conferir(_dica_acesa(moradores) and _dicas_acesas() == 1,
		"virado para o Tonho, a dica dele não é a única acesa (%d acesas)" % _dicas_acesas())
	# A DICA DIZ O ALVO (#97): com o Tonho no foco, o rótulo aceso tem o nome dele,
	# e os moldes têm tradução.
	var acao: String = (moradores._dica.find_child("Acao", true, false) as Label).text
	var nome_do_tonho := str((tonho.dados as Dictionary).get("nome", "Tonho"))
	_conferir(acao.contains(nome_do_tonho) and (acao.begins_with("Falar") or acao.begins_with("Entregar")),
		"virado para o Tonho, a dica do E não diz com quem se fala: '%s'" % acao)
	var idioma = load("res://scripts/prototipo_3d/idioma_menu.gd")
	for molde in ["Falar com %s", "Entregar a %s"]:
		_conferir(idioma.EN.has(molde) and idioma.ES.has(molde), "a dica do E sem tradução: %s" % molde)

	# --- 5. A BARRA DE MÃO COME SÓ SEM DONO --------------------------------------------
	var inv = root.get_node("/root/Inventario")
	inv.adicionar("beiju", 1)
	for i in inv.ESPACOS_MAO:
		if str((inv.espacos[i] as Dictionary).get("id", "")) == "beiju":
			inv.selecionar(i)
	var beijus: int = inv.quantidade("beiju")
	tonho._balao_tempo = 0.0
	_apertar_e()
	await _quadros(3)
	_conferir(inv.quantidade("beiju") == beijus, "com o foco no Tonho, o E comeu o beiju da mão")

	# --- 6. O MORADOR QUE O PASSO PEDE VENCE O MAIS PERTO ------------------------------
	# No píer o Pedro e o Tonho ficam a dois passos um do outro, e o Pedro segue o
	# jogador. O passo do bom-dia manda falar com o Tonho; o Pedro está colado, atrás
	# do jogador, e o Tonho a dois passos, na frente.
	var pedro = vale.pedro
	_conferir(pedro != null, "o vale não tem o Pedro")
	if pedro == null:
		tonho.liberar()
		_fechar()
		return
	pedro.ir_ao_passo("bom_dia")
	pedro.set("_iniciado", true)
	pedro.set("_espera", 0.0)
	var atras_do_jogador: Vector3 = onde_fico - de_lado_no_pier * 0.8 + Vector3.UP * 0.1
	for vez in 2:
		jogador.teleportar(onde_fico + Vector3.UP * 0.3, atan2(de_lado_no_pier.x, de_lado_no_pier.z))
		pedro.global_position = atras_do_jogador
		tonho.global_position = onde_o_tonho + Vector3.UP * 0.1
		await _passos_de_fisica(8)
	pedro.global_position = atras_do_jogador
	tonho.global_position = onde_o_tonho + Vector3.UP * 0.1
	await _quadros(3)
	var ate_o_pedro := Vector2(pedro.global_position.x - jogador.global_position.x, pedro.global_position.z - jogador.global_position.z).length()
	var ate_o_tonho := Vector2(tonho.global_position.x - jogador.global_position.x, tonho.global_position.z - jogador.global_position.z).length()
	_conferir(ate_o_pedro < ate_o_tonho and ate_o_tonho < moradores.ALCANCE,
		"o caso não se montou: o Pedro está a %.2f, o Tonho a %.2f (alcance %.2f)" % [ate_o_pedro, ate_o_tonho, moradores.ALCANCE])
	_conferir(pedro._cadeia.o_que_o_e_faz(tonho) == "falar" and pedro._cadeia.o_que_o_e_faz(pedro) == "",
		"o passo do bom-dia não pede o Tonho: pede '%s' e ao Pedro '%s'" % [pedro._cadeia.o_que_o_e_faz(tonho), pedro._cadeia.o_que_o_e_faz(pedro)])
	_conferir(moradores.perto() == tonho,
		"o passo manda falar com o Tonho, e o E ficou com '%s', que está mais perto" % _nome(moradores.perto()))
	_conferir(foco.dono() == moradores and _dica_acesa(moradores) and _dicas_acesas() == 1,
		"o foco não deixou só a dica da conversa acesa (dono: %s, %d dicas)" % [_nome(foco.dono()), _dicas_acesas()])
	_apertar_e()
	await _quadros(3)
	_conferir(bool(pedro._cadeia._levados.get("bom_dia", false)),
		"o E não cumpriu o passo do bom-dia: a conversa foi para quem está mais perto, e não para o Tonho")
	# SEM PASSO PEDINDO NINGUÉM, o mais perto: o passo seguinte é correr.
	pedro.ir_ao_passo("correr")
	pedro.global_position = atras_do_jogador
	tonho.global_position = onde_o_tonho + Vector3.UP * 0.1
	jogador.teleportar(onde_fico + Vector3.UP * 0.3, atan2(de_lado_no_pier.x, de_lado_no_pier.z))
	await _passos_de_fisica(8)
	pedro.global_position = atras_do_jogador
	tonho.global_position = onde_o_tonho + Vector3.UP * 0.1
	await _quadros(3)
	_conferir(moradores.perto() == pedro,
		"sem passo pedindo ninguém, o E devia ficar com o mais perto (o Pedro), e ficou com '%s'" % _nome(moradores.perto()))
	# A REGRA, sem mundo: a ordem é o que a fila diz, depois quem fala, depois a distância.
	var pedido_mudo := {"acao": 0, "mudo": true, "distancia": 2.6}
	var abre_fila := {"acao": 1, "mudo": false, "distancia": 2.0}
	var conversa_perto := {"acao": 2, "mudo": false, "distancia": 0.5}
	var aceno_colado := {"acao": 2, "mudo": true, "distancia": 0.3}
	_conferir(moradores.escolher_entre([conversa_perto, pedido_mudo]) == 1,
		"o que o passo pede (mesmo quem não fala) perdeu para quem está mais perto")
	_conferir(moradores.escolher_entre([conversa_perto, abre_fila]) == 1, "quem abre uma fila perdeu para a conversa mais perto")
	_conferir(moradores.escolher_entre([abre_fila, pedido_mudo]) == 1, "quem abre uma fila ganhou do que o passo pede")
	_conferir(moradores.escolher_entre([aceno_colado, conversa_perto]) == 1, "quem só acena ganhou de quem fala, só por estar mais perto")
	_conferir(moradores.escolher_entre([conversa_perto, {"acao": 2, "mudo": false, "distancia": 0.4}]) == 1, "entre iguais, o mais perto não ganhou")
	_conferir(moradores.escolher_entre([]) == -1, "sem ninguém ao alcance a escolha não é -1")

	# --- 7. A DICA NÃO FICA ONDE O E NÃO VALE ---------------------------------------------
	pedro.global_position = atras_do_jogador
	tonho.global_position = onde_o_tonho + Vector3.UP * 0.1
	jogador.teleportar(onde_fico + Vector3.UP * 0.3, atan2(de_lado_no_pier.x, de_lado_no_pier.z))
	await _passos_de_fisica(8)
	pedro.global_position = atras_do_jogador
	tonho.global_position = onde_o_tonho + Vector3.UP * 0.1
	await _quadros(3)
	_conferir(_dica_acesa(moradores) and _dicas_acesas() == 1, "a dica da conversa não acendeu para a prova (%d acesas)" % _dicas_acesas())
	_apertar_tecla(KEY_J)
	await _quadros(4)
	_conferir(paused, "o J não abriu a tela e parou o vale")
	_conferir(_dicas_acesas() == 0,
		"com a tela aberta há %d dica(s) do E acesa(s), congeladas por cima dela (a árvore parada não roda as fontes)" % _dicas_acesas())
	await _guardar_o_que_abriu(vale)
	pedro.global_position = atras_do_jogador
	tonho.global_position = onde_o_tonho + Vector3.UP * 0.1
	await _quadros(4)
	_conferir(not paused and _dica_acesa(moradores), "fechada a tela, a dica da conversa não voltou (pausado: %s)" % str(paused))
	# O QUE COBRE O VALE SEM PARAR A ÁRVORE (a festa da missão, a voz do mundo) o vale diz em `coberto`.
	var o_que_o_vale_diz: Callable = foco.coberto
	foco.coberto = func() -> bool: return true
	await _quadros(3)
	_conferir(_dicas_acesas() == 0, "coberto o vale pela festa, ainda há %d dica(s) do E acesa(s)" % _dicas_acesas())
	foco.coberto = o_que_o_vale_diz
	await _quadros(3)
	_conferir(_dica_acesa(moradores), "acabada a festa, a dica da conversa não voltou")
	tonho.liberar()
	_fechar()


## Fecha o que o cordel abriu — o papel, e o aviso da primeira vez, se houver —,
## até o vale andar de novo.
func _guardar_o_que_abriu(vale) -> void:
	var ate := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < ate:
		var telas = vale.get("telas")
		if telas != null and telas.aberta() != "":
			telas.fechar_tudo()
		var aviso = vale.get("aviso_da_primeira_vez")
		if aviso != null and aviso.has_method("aberto") and aviso.aberto():
			aviso.fechar()
		if not paused and (telas == null or telas.aberta() == ""):
			break
		await process_frame
	await _quadros(4)


func _nome(no) -> String:
	return str(no.name) if no is Node else "ninguém"


## A dica do E desta fonte está acesa?
func _dica_acesa(fonte) -> bool:
	var dica = fonte.get("_dica")
	return dica is Control and (dica as Control).visible


## Quantas dicas do E estão acesas entre as fontes do foco.
func _dicas_acesas() -> int:
	var acesas := 0
	for fonte in get_nodes_in_group(FocoDoE.GRUPO):
		if _dica_acesa(fonte):
			acesas += 1
	return acesas


## O E pela janela, como o teclado: quem o recebe é decidido pelo jogo. O perfil
## do portão é novo, e o interagir está no E de fábrica.
func _apertar_e() -> void:
	_apertar_tecla(KEY_E)


func _apertar_tecla(tecla: int) -> void:
	for apertado in [true, false]:
		var evento := InputEventKey.new()
		evento.keycode = tecla
		evento.physical_keycode = tecla
		evento.pressed = apertado
		root.push_input(evento)


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("FOCO_DO_E_OK: toda fonte do E responde ao foco; a conta favorece a frente e o que está aberto; com o Tonho do lado, virado para o cordel, só a dica do cordel acende e o E o pega; virado para o Tonho, o E e a dica são dele; com dono no foco a barra de mão não come; o morador que o passo pede vence o mais perto (o Tonho, com o Pedro colado), e sem passo pedindo vale o mais perto; e com a tela aberta ou a festa por cima nenhuma dica fica acesa")
	else:
		print("foco_do_e: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _passos_de_fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
