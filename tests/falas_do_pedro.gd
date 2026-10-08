extends SceneTree
## AS FALAS SITUACIONAIS DO PEDRO (#179): comentários curtos, cada um ligado a um gatilho do que acontece com
## o jogador enquanto ele conduz a chegada.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/falas_do_pedro.gd
##
## O Pedro tinha 21 falas com voz e ficava calado quando o jogador sumia, parava, caía na água ou ia para o lado
## errado. Cinco perguntas:
##
##   1. SÃO DEZ, uma por gatilho, nos quatro idiomas, com o nome do áudio `pedro_situacao_<gatilho>` (o arquivo
##      e o import são conferidos em `vozes_dos_moradores.gd`) e a marcação de interpretação para a voz.
##   2. CADA GATILHO ESTÁ LIGADO: o nome de cada `gatilho` do arquivo aparece num `_pedir_situacao` do
##      `guia_pedro.gd` (um gatilho sem ligação é uma fala que nunca toca), e todo `_pedir_situacao` do script
##      tem uma fala no arquivo.
##   3. O NADO PEDE A FALA, e ela sai com a palavra livre: o sinal `nado_mudou` do jogador chega ao Pedro.
##   4. NÃO SAI EM SEQUÊNCIA nem repete: duas falas situacionais respeitam a pausa; a de uma vez só não volta, e
##      a de `intervalo` não volta antes dele.
##   5. SÓ NA CHEGADA, e só com o jogador conduzido: acabado o tutorial o Pedro cala; conversar com o alvo do
##      passo não é "falar com outro morador".

const SEGUNDOS_PARA_ANUNCIAR := 12.0
const SEGUNDOS_DE_PALAVRA := 25.0
const GATILHOS := 10

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("FALAS_DO_PEDRO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	var arquivo = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs_3d.json"))
	_conferir(arquivo is Dictionary, "o npcs_3d.json não abre")
	var lista: Array = (arquivo["guia"] as Dictionary).get("situacoes", []) if arquivo is Dictionary else []

	# --- 1. AS DEZ FALAS ---------------------------------------------------------------------
	_conferir(lista.size() == GATILHOS, "o Pedro tem %d fala(s) situacional(is), e são %d" % [lista.size(), GATILHOS])
	var gatilhos := {}
	for i in lista.size():
		var fala: Dictionary = lista[i]
		var g := str(fala.get("gatilho", ""))
		_conferir(g != "" and not gatilhos.has(g), "situacoes[%d] sem gatilho ou com o gatilho '%s' repetido" % [i, g])
		gatilhos[g] = true
		for chave in ["texto", "texto_en", "texto_es", "texto_zh", "tts", "audio"]:
			_conferir(str(fala.get(chave, "")) != "", "situacoes[%d] (%s) sem o campo %s" % [i, g, chave])
		_conferir(str(fala.get("audio", "")) == "pedro_situacao_" + g, "situacoes[%d]: o áudio devia se chamar pedro_situacao_%s" % [i, g])
		_conferir(str(fala.get("tts", "")).contains("["), "situacoes[%d] (%s): o tts sem marcação de interpretação do v3" % [i, g])
		_conferir(float(fala.get("intervalo", 0.0)) >= 0.0, "situacoes[%d] (%s): intervalo negativo" % [i, g])

	# --- 2. CADA GATILHO ESTÁ LIGADO -------------------------------------------------------------
	var codigo := FileAccess.get_file_as_string("res://scripts/prototipo_3d/guia_pedro.gd")
	for g: String in gatilhos.keys():
		_conferir(codigo.contains("_pedir_situacao(\"%s\"" % g), "o gatilho '%s' não é pedido em lugar nenhum do guia_pedro.gd" % g)
	var pedidos := 0
	var cursor := 0
	while true:
		var achou := codigo.find("_pedir_situacao(\"", cursor)
		if achou < 0:
			break
		var fim := codigo.find("\"", achou + 17)
		var nome := codigo.substr(achou + 17, fim - achou - 17)
		_conferir(gatilhos.has(nome), "o guia_pedro.gd pede '%s', e o npcs_3d.json não tem essa fala" % nome)
		pedidos += 1
		cursor = fim
	_conferir(pedidos >= GATILHOS, "só %d pedido(s) no guia_pedro.gd, e são %d gatilhos" % [pedidos, GATILHOS])

	# --- 3, 4 e 5. NO VALE ------------------------------------------------------------------------
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(3)
	var jogo := current_scene
	var jogador = jogo.get("player")
	var pedro = jogo.get("pedro")
	var tonho: Node3D = null
	for morador in jogo.get("moradores") as Array:
		if str((morador.dados as Dictionary).get("id", "")) == "tonho":
			tonho = morador
	_conferir(jogador != null and pedro != null and tonho != null, "não achei o jogador, o Pedro ou o Tonho")
	if jogador == null or pedro == null or tonho == null:
		_fechar()
		return
	pedro.saudar()
	_conferir(pedro._na_chegada(), "o Pedro devia estar na chegada depois de saudar")
	# Espera o anúncio do primeiro passo passar, que tem a vez antes de qualquer comentário.
	await _ate(func() -> bool: return float(pedro._cadeia.espera) <= 0.0, SEGUNDOS_PARA_ANUNCIAR)
	await _palavra_livre(func() -> bool: return pedro.pode_falar(), SEGUNDOS_DE_PALAVRA)

	# 3. O nado do jogador pede a fala dele, e ela sai.
	pedro._situacao_ultima_ms = -1000000
	# O cartão da água funda (aviso da primeira vez) para o vale; este portão é do Pedro, não dele.
	jogo.set("_avisou_agua_funda", true)
	jogador.nado_mudou.emit(true)
	_conferir(pedro._situacao_pedidas.has("nadou"), "o nado do jogador não pediu a fala do Pedro")
	await _palavra_livre(func() -> bool: return pedro.pode_falar(), SEGUNDOS_DE_PALAVRA)
	var disse := await _ate(func() -> bool: return pedro._situacao_dita_em.has("nadou"), 8.0)
	_conferir(disse, "o Pedro não disse a fala do nado com a palavra livre")
	_conferir(not pedro._situacao_pedidas.has("nadou"), "a fala do nado foi dita e o pedido ficou")

	# 4. Em sequência não sai: o pedido espera a pausa. De uma vez só não volta.
	var antes: int = pedro._situacao_ultima_ms
	pedro._pedir_situacao("passagem", 6.0)
	_conferir(pedro._situacao_pedidas.has("passagem"), "o pedido da passagem não entrou")
	await _ate(func() -> bool: return false, 1.5)
	_conferir(not pedro._situacao_dita_em.has("passagem") and pedro._situacao_ultima_ms == antes,
		"duas falas situacionais saíram coladas (a pausa de %d s não valeu)" % int(pedro.SITUACAO_PAUSA))
	pedro._situacao_pedidas.clear()
	# Uma vez por partida: sem `intervalo`, depois de dita não é pedida de novo.
	pedro._cadeia._levados["disse:primeiro_peixe"] = true
	pedro._pedir_situacao("primeiro_peixe", 60.0)
	_conferir(not pedro._situacao_pedidas.has("primeiro_peixe"), "a fala de uma vez só foi pedida de novo")
	# Com `intervalo`: acabou de dizer, não volta já.
	pedro._situacao_dita_em["nadou"] = Time.get_ticks_msec()
	pedro._pedir_situacao("nadou", 6.0)
	_conferir(not pedro._situacao_pedidas.has("nadou"), "a fala do nado voltou antes do intervalo dela")
	pedro._situacao_dita_em["nadou"] = Time.get_ticks_msec() - 400000
	pedro._pedir_situacao("nadou", 6.0)
	_conferir(pedro._situacao_pedidas.has("nadou"), "passado o intervalo, a fala do nado não pôde ser pedida")
	pedro._situacao_pedidas.clear()

	# 5a. Falar com outro morador, no meio da condução, é um gatilho; falar com o alvo do passo, não.
	pedro._quadro_da_conducao = Engine.get_physics_frames()
	_conferir(pedro.ir_ao_passo("bom_dia"), "a chegada não tem o bom-dia ao Tonho")
	var cosme: Node3D = null
	for morador in jogo.get("moradores") as Array:
		if str((morador.dados as Dictionary).get("id", "")) in ["cosme", "zefa", "candinha"]:
			cosme = morador
			break
	_conferir(cosme != null, "não achei um morador que não seja o Tonho")
	pedro._quadro_da_conducao = Engine.get_physics_frames()
	pedro.o_jogador_falou_com(tonho)
	_conferir(not pedro._situacao_pedidas.has("outro_morador"), "falar com o alvo do passo (o Tonho) contou como falar com outro morador")
	if cosme != null:
		pedro._quadro_da_conducao = Engine.get_physics_frames()
		pedro.o_jogador_falou_com(cosme)
		_conferir(pedro._situacao_pedidas.has("outro_morador"), "falar com outro morador no meio da condução não pediu a fala do Pedro")
	pedro._situacao_pedidas.clear()

	# 5b. Acabada a chegada, o Pedro cala.
	pedro.missao = pedro.MISSOES.size()
	pedro.set("_despedida_feita", true)
	_conferir(pedro.terminou_o_tutorial(), "não consegui dar a chegada do Pedro por acabada")
	pedro._situacao_dita_em.clear()
	pedro._pedir_situacao("nadou", 6.0)
	_conferir(not pedro._situacao_pedidas.has("nadou"), "acabado o tutorial o Pedro ainda comenta o nado")
	_fechar()


func _palavra_livre(condicao: Callable, segundos: float) -> bool:
	var fila = current_scene.get("fila_de_falas")
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicao.call():
			return true
		if fila != null:
			fila.pular()
		await process_frame
	return condicao.call()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("FALAS_DO_PEDRO_OK: as dez falas situacionais do Pedro têm os quatro idiomas e a voz nomeada, cada gatilho está ligado no código, o nado pede a fala e ela sai com a palavra livre, duas não saem coladas, a de uma vez só e a de intervalo não repetem, e acabado o tutorial ele cala")
	else:
		print("falas_do_pedro: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicao.call():
			return true
		await process_frame
	return condicao.call()


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
