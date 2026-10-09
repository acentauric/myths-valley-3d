extends SceneTree
## O QUE O PASSO ENTREGA NÃO SE PERDE: nem no save, nem com a mochila cheia.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/entregas_da_cadeia.gd
##
## Duas travas que deixavam a missão sem saída (cadeia_de_missoes.gd):
##
##   1. SALVAR NO RESPIRO ENTRE DOIS PASSOS. A ferramenta vem no anúncio do passo
##      (a picareta do lajedo do poço), e o anúncio vem um respiro depois de o
##      passo anterior fechar. Salvo nesse respiro, carregar retomava o passo SEM
##      anunciar — e sem a picareta: o lajedo não quebrava, e a chegada parava.
##      Retomar entrega o que o passo deve; e só uma vez: recarregar de novo, com
##      a picareta vendida, não dá outra.
##   2. A MOCHILA CHEIA. A entrega e a recompensa sumiam em silêncio, e o HUD
##      ainda dizia "Recebido". Agora o HUD diz que falta espaço, o que não coube
##      fica guardado (e vai no save), e entra sozinho quando um espaço abre.

const PEDRA_CHEIA := {"id": "pedra", "qtd": 99}

var falhas := 0
var inv
var vale
var pedro


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("ENTREGAS_DA_CADEIA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	vale = current_scene
	# O ACEITE É AUTOMÁTICO AQUI (08/10): este portão abre filas pelo E e segue; a tela de aceite
	# pausaria o vale no meio da medida (a tela tem portão próprio, tests/missao_a_vista.gd).
	if vale.get("aceite") != null:
		vale.aceite.automatico = true
	inv = root.get_node("/root/Inventario")
	var dia = root.get_node("/root/Dia")
	dia.pausado = true
	dia.definir_hora(9.0)
	pedro = vale.get("pedro")
	_conferir(pedro != null, "o vale não tem o Pedro")
	if pedro == null:
		_fechar()
		return
	pedro.set("_iniciado", true)

	# --- 1. SALVO NO RESPIRO, A PICARETA VEM NA VOLTA ------------------------------
	_tirar_tudo("picareta")
	_conferir(pedro.ir_ao_passo("pedra_do_poco"), "a chegada não tem o passo da pedra do poço")
	# O passo de antes acabou de fechar: o anúncio deste ainda não veio.
	pedro._espera = 1.4
	pedro.lembrar([])
	var no_respiro: Dictionary = vale.estado_para_salvar()
	vale.restaurar_do_save(no_respiro)
	await _quadros(3)
	_conferir(pedro.passo_em_curso() == "pedra_do_poco", "recarregar não voltou ao passo da pedra do poço ('%s')" % pedro.passo_em_curso())
	_conferir(float(pedro._espera) <= 0.0, "recarregar refez a espera do anúncio (%.2f): a fala voltaria" % float(pedro._espera))
	_conferir(inv.quantidade("picareta") == 1,
		"salvo no respiro entre dois passos, recarregar devolveu %d picareta(s): sem ela o lajedo do poço não quebra" % inv.quantidade("picareta"))
	# UMA VEZ SÓ: vendida a picareta, recarregar de novo não dá outra.
	_tirar_tudo("picareta")
	vale.restaurar_do_save(vale.estado_para_salvar())
	await _quadros(3)
	_conferir(inv.quantidade("picareta") == 0,
		"recarregar de novo deu outra picareta (%d): a entrega do passo virou fonte de ferramenta" % inv.quantidade("picareta"))

	# --- 2. A MOCHILA CHEIA: A FERRAMENTA FICA DEVENDO, E O HUD DIZ -------------------
	var entregues: Array[String] = []
	var pagos: Array[String] = []
	pedro.entregou.connect(func(texto: String) -> void: entregues.append(texto))
	pedro.pagou.connect(func(texto: String) -> void: pagos.append(texto))
	var guardados := _encher_a_mochila()
	_conferir(not inv.adicionar("picareta", 1), "não consegui encher a mochila para a pergunta")
	_conferir(pedro.ir_ao_passo("pedra_do_poco"), "a chegada não tem o passo da pedra do poço")
	pedro.lembrar([])
	pedro._espera = 0.05
	await _ate(func() -> bool: return float(pedro._espera) <= 0.0, 6.0)
	await _quadros(3)
	_conferir(not inv.tem("picareta"), "com a mochila cheia, a picareta entrou mesmo assim (a mochila não estava cheia)")
	_conferir(_devendo("picareta"), "com a mochila cheia, a picareta do passo sumiu: nada ficou guardado para depois")
	var aviso := " ".join(entregues)
	_conferir(aviso.to_lower().contains("picareta") and not aviso.contains("Recebido"),
		"com a mochila cheia, o HUD não disse que falta espaço para a picareta: '%s'" % aviso)
	# O QUE FICOU DEVENDO VAI NO SAVE.
	vale.restaurar_do_save(vale.estado_para_salvar())
	await _quadros(3)
	_conferir(_devendo("picareta"), "salvo e recarregado, o vale esqueceu a picareta que ficou devendo")
	# ABRE UM ESPAÇO, E ELA VEM SOZINHA.
	inv.espacos[4] = {}
	inv.mudou.emit()
	var veio := await _ate(func() -> bool: return inv.tem("picareta"), 5.0)
	_conferir(veio, "aberto um espaço na mochila, a picareta guardada não entrou")
	_conferir(not _devendo("picareta"), "a picareta entrou e continuou na conta do que se deve: viria duas vezes")
	_conferir(" ".join(pagos).to_lower().contains("picareta"), "a picareta entrou sem o recado do HUD: '%s'" % " ".join(pagos))

	# --- 3. A MOCHILA CHEIA: A RECOMPENSA TAMBÉM ------------------------------------
	var tonho = vale._achar_morador("tonho")
	_conferir(tonho != null, "o vale não tem o Tonho")
	if tonho != null:
		_encher_a_mochila()
		_tirar_tudo("peixe")
		entregues.clear()
		pagos.clear()
		_conferir(pedro.ir_ao_passo("bom_dia"), "a chegada não tem o bom-dia ao Tonho")
		pedro.lembrar([])
		pedro._espera = 0.05
		await _ate(func() -> bool: return float(pedro._espera) <= 0.0, 6.0)
		var no_bom_dia: int = int(pedro.missao)
		vale.player.teleportar(tonho.global_position + Vector3(1.0, 0.1, 0.6), 0.0)
		await _quadros(3)
		vale.tecla_dos_moradores.usar(tonho)
		var fechou := await _ate(func() -> bool: return int(pedro.missao) > no_bom_dia, 8.0)
		_conferir(fechou, "o E no Tonho não fechou o bom-dia")
		await _quadros(3)
		_conferir(not inv.tem("peixe"), "com a mochila cheia, o peixe do Tonho entrou mesmo assim")
		_conferir(_devendo("peixe"), "com a mochila cheia, o peixe do Tonho sumiu: a recompensa se perdeu")
		_conferir(not " ".join(pagos).contains("peixe"),
			"com a mochila cheia, o HUD disse que o peixe foi recebido: '%s'" % " ".join(pagos))
		_conferir(" ".join(entregues).to_lower().contains("peixe"),
			"com a mochila cheia, o HUD não disse que o peixe ficou esperando espaço: '%s'" % " ".join(entregues))
		inv.espacos[6] = {}
		inv.mudou.emit()
		_conferir(await _ate(func() -> bool: return inv.tem("peixe"), 5.0), "aberto um espaço, o peixe do Tonho não entrou")
	for i in guardados.size():
		inv.espacos[i] = guardados[i]
	inv.mudou.emit()

	# --- 4. A CHAVE DA CASA SOBREVIVE AO SAVE, UMA SÓ (#217) -----------------------
	# Entre o passo da Dona Zefa e o da casa a chave mora na mochila. Salvar e carregar nesse trecho a devolve,
	# e uma só: o `_conferir_a_chave_da_casa` do vale só completa quem chegou sem ela.
	_tirar_tudo("chave_da_casa")
	_conferir(pedro.ir_ao_passo("casa"), "a chegada não tem o passo da casa")
	pedro.retomar()
	await _quadros(3)
	_conferir(inv.quantidade("chave_da_casa") == 1, "no passo da casa, a mochila tem %d chave(s)" % inv.quantidade("chave_da_casa"))
	vale.restaurar_do_save(vale.estado_para_salvar())
	await _quadros(3)
	_conferir(inv.quantidade("chave_da_casa") == 1,
		"salvo e recarregado entre o passo da Dona Zefa e o da casa, a mochila tem %d chave(s)" % inv.quantidade("chave_da_casa"))
	# Passada a casa, a chave que sobrou (passo pulado) é guardada no prego: a mochila não a carrega mais.
	_conferir(pedro.ir_ao_passo("pegar"), "a chegada não tem o passo das ferramentas do finado")
	pedro.retomar()
	await _quadros(3)
	_conferir(inv.quantidade("chave_da_casa") == 0, "passada a casa, a chave continua na mochila (%d)" % inv.quantidade("chave_da_casa"))
	_fechar()


## Enche os trinta espaços com pedra (pilhas cheias): nada novo cabe. Devolve o
## que havia, para pôr de volta no fim.
func _encher_a_mochila() -> Array:
	var antes: Array = inv.espacos.duplicate(true)
	for i in inv.ESPACOS:
		inv.espacos[i] = PEDRA_CHEIA.duplicate()
	inv.mudou.emit()
	return antes


func _tirar_tudo(item: String) -> void:
	for i in inv.ESPACOS:
		if str((inv.espacos[i] as Dictionary).get("id", "")) == item:
			inv.espacos[i] = {}
	inv.mudou.emit()


## O que o Pedro ficou devendo (a memória da chegada, que vai no save).
func _devendo(item: String) -> bool:
	for chave in pedro.lembrancas():
		if str(chave).begins_with("pendente:%s:" % item):
			return true
	return false


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("ENTREGAS_DA_CADEIA_OK: salvo no respiro entre dois passos, recarregar entrega a picareta do passo — uma vez só, e não de novo a cada recarga; com a mochila cheia a ferramenta e a recompensa não somem nem viram 'Recebido': o HUD diz que falta espaço, o que não coube vai no save e entra sozinho quando um espaço abre; a chave da casa do tio entra no passo da Dona Zefa, sobrevive ao save sem dobrar e sai da mochila ao passar da casa")
	else:
		print("entregas_da_cadeia: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


## Roda quadros até `condicao` valer, com teto em SEGUNDO REAL; a caixa de fala
## que abrir no caminho se fecha (o portão lê depressa).
func _ate(condicao: Callable, segundos: float) -> bool:
	var dialogo = root.get_node("/root/Dialogo")
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicao.call():
			return true
		if dialogo.ativo:
			dialogo._fechar()
		await process_frame
	return condicao.call()


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
