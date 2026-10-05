extends SceneTree
## Confere O FOCO DO E (scripts/prototipo_3d/foco_do_e.gd): de tudo o que responde
## ao E, um só leva a tecla — o da frente do jogador, e mais perto.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/foco_do_e.gd
##
## "Ao tentar interagir com o cordel e tem um NPC próximo, ele foca somente na
## seleção do NPC e não consigo clicar no cordel. Imagino que o mesmo acontece
## com outras coisas no jogo." Cinco perguntas, com a tecla de verdade (pela
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
	for apertado in [true, false]:
		var evento := InputEventKey.new()
		evento.keycode = KEY_E
		evento.physical_keycode = KEY_E
		evento.pressed = apertado
		root.push_input(evento)


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("FOCO_DO_E_OK: toda fonte do E responde ao foco; a conta favorece a frente e o que está aberto; com o Tonho do lado, virado para o cordel, só a dica do cordel acende e o E o pega; virado para o Tonho, o E e a dica são dele; e com dono no foco a barra de mão não come")
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
