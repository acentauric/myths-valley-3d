extends SceneTree
## Confere AS MISSÕES DA FÉ (#52): a fila da Dona Zefa e a missão própria de
## cada fé, do jogo 2D (arraial.json) trazidas para os marcos do vale.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/cadeia_da_fe.gd
##
##   1. A FILA DA FÉ ESPERA O MIRANTE, e abre quando ele fica de pé.
##   2. A DONA ZEFA FALA quando o jogador chega nela, e os marcos ainda não
##      aceitam ninguém.
##   3. OS TRÊS LUGARES: chegar perto de cada um risca a conta e o mundo conta o
##      que se vê dali; os três pagam as cocadas.
##   4. CONTAR À DONA ZEFA libera a escolha.
##   5. ESCOLHER NO MARCO fecha o passo, paga e rende XP de fé — e abre a missão
##      própria da fé escolhida.
##   6. A ROMARIA passa nos quatro marcos da igreja, o altar lá dentro também.
##   7. A MISSÃO DE UMA FÉ CONGELA quando o jogador muda para outra — nem a
##      oferenda pronta no pé do terreiro anda — e volta a correr se ele voltar.
##   8. AS OSTRAS SE CATAM À MÃO, nas pedras da maré, e pagam o monte.
##   9. O SAVE LEVA AS FILAS DA FÉ.

var falhas := 0
var dialogo
var vale
var marcos
var jogador
var inventario


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("CADEIA_DA_FE_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	dialogo = root.get_node("/root/Dialogo")
	inventario = root.get_node("/root/Inventario")
	var fe = root.get_node("/root/Fe")
	var energia = root.get_node("/root/Energia")
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(8)
	vale = current_scene
	marcos = vale.get("marcos")
	jogador = vale.player
	var cadeias: Dictionary = vale.get("_cadeias")
	var fila = cadeias.get("pedro_fe")
	var arraial = cadeias.get("pedro_arraial")
	_conferir(fila != null and arraial != null and marcos != null, "o vale não tem a fila da fé, a do arraial ou os marcos")
	if fila == null or arraial == null or marcos == null:
		_fechar()
		return
	var zefa: Node3D = null
	for morador in vale.moradores:
		if str(morador.dados.get("id", "")) == "zefa":
			zefa = morador

	# --- 1. ESPERA O MIRANTE ----------------------------------------------------
	await _segundos(2.0)
	_conferir(not fila.iniciado, "a fila da fé abriu antes do mirante consertado")
	arraial.iniciado = true
	arraial.missao = arraial.passos.size()
	vale.pedro.global_position = jogador.global_position + Vector3(1.5, 0, 0)
	var abriu := await _ate(func() -> bool: return fila.iniciado and fila.espera <= 0.0, 12.0)
	_conferir(abriu, "com o mirante de pé a fila da fé não abriu e anunciou")
	_conferir(root.get_node("/root/CadernoDoVale").tem("pedro_fe_zefa"), "o recado da Dona Zefa não entrou no diário")

	# --- 2. A DONA ZEFA ------------------------------------------------------------
	await _ir_a(zefa.global_position + Vector3(1.6, 0, 0))
	_conferir(await _ate(func() -> bool: return fila.missao == 1, 8.0), "chegar na Dona Zefa não fechou o recado (passo %d)" % fila.missao)
	_conferir(not bool(marcos.liberada.call()), "os marcos aceitam gente antes de a Dona Zefa mostrar as três")

	# --- 3. OS TRÊS LUGARES ------------------------------------------------------------
	var cocadas: int = inventario.quantidade("cocada")
	var vistas: Array = []
	fila.visitou.connect(func(lugar: String) -> void: vistas.append(lugar))
	var lidas: Array = []
	# A meta só conta depois de o passo ser anunciado.
	await _ate(func() -> bool: return fila.espera <= 0.0, 8.0, lidas)
	for marco in ["cruzeiro", "terreiro", "gameleira"]:
		await _ir_a(marcos.ponto(marco) + Vector3(1.5, 0, 0.5), lidas)
		await _segundos(0.6, lidas)
	_conferir(vistas.size() == 3, "a conta dos três lugares riscou %s" % str(vistas))
	_conferir(lidas.any(func(l): return str(l).contains("concha")), "chegar na gameleira não contou o que se vê dali")
	_conferir(await _ate(func() -> bool: return fila.missao == 2, 8.0, lidas), "os três lugares vistos não fecharam o passo (passo %d)" % fila.missao)
	_conferir(inventario.quantidade("cocada") == cocadas + 2, "os três lugares não pagaram as duas cocadas")

	# --- 4. CONTAR À DONA ZEFA ---------------------------------------------------------
	await _ate(func() -> bool: return fila.espera <= 0.0, 8.0, lidas)
	await _ir_a(zefa.global_position + Vector3(1.6, 0, 0), lidas)
	_conferir(await _ate(func() -> bool: return fila.missao == 3, 8.0, lidas), "contar à Dona Zefa não fechou o passo (passo %d)" % fila.missao)
	_conferir(bool(marcos.liberada.call()), "depois de a Dona Zefa contar como é, os marcos continuam travados")

	# --- 5. ESCOLHER NO MARCO ------------------------------------------------------------
	await _ate(func() -> bool: return fila.espera <= 0.0, 8.0, lidas)
	var beijus: int = inventario.quantidade("beiju")
	var garapas: int = inventario.quantidade("garapa")
	await _no_marco("cruzeiro", [true])
	_conferir(fe.ativa == "catolica", "aceitar no cruzeiro deixou a fé em '%s'" % fe.ativa)
	_conferir(await _ate(func() -> bool: return fila.missao == 4, 8.0, lidas), "entrar numa fé não fechou o passo de escolher (passo %d)" % fila.missao)
	_conferir(inventario.quantidade("beiju") == beijus + 2 and inventario.quantidade("garapa") == garapas + 2,
		"a escolha não pagou os beijus e as garapas")
	_conferir(fe.total_exato("catolica") > 0.0, "a missão de escolher não rendeu XP de fé")
	var romaria = cadeias.get("fe_catolica")
	_conferir(romaria != null and romaria.iniciado, "entrar na católica não abriu a romaria")

	# --- 6. A ROMARIA ------------------------------------------------------------------
	if romaria != null:
		await _ate(func() -> bool: return romaria.espera <= 0.0, 8.0, lidas)
	var sala = vale.interiores.sala_de("igreja")
	var dentro_da_nave: Vector3 = sala.to_global(Vector3(0, 0.05, -sala.comprimento + 3.4))
	for onde in [marcos.ponto("cruzeiro") + Vector3(1.5, 0, 0.5), dentro_da_nave,
			marcos.ponto("capela_estrada") + Vector3(1.0, 0, 0.5), marcos.ponto("cemiterio") + Vector3(1.0, 0, 0.5)]:
		await _ir_a(onde, lidas, onde != dentro_da_nave)
		await _segundos(0.5, lidas)
	if romaria != null:
		_conferir(await _ate(func() -> bool: return romaria.acabou(), 8.0, lidas), "a romaria não fechou nos quatro marcos (passo %d)" % romaria.missao)

	# --- a fila da Dona Zefa fecha ---------------------------------------------------
	await _ate(func() -> bool: return fila.espera <= 0.0, 8.0, lidas)
	await _ir_a(zefa.global_position + Vector3(1.6, 0, 0), lidas)
	_conferir(await _ate(func() -> bool: return fila.acabou(), 8.0, lidas), "o último passo da fila da fé não fechou com a Dona Zefa")

	# --- 7. CONGELA AO TROCAR ----------------------------------------------------------
	await _no_marco("terreiro", [true, false])
	_conferir(fe.ativa == "candomble", "trocar no terreiro deixou a fé em '%s'" % fe.ativa)
	var mesa = cadeias.get("fe_candomble")
	_conferir(mesa != null and mesa.iniciado, "entrar no candomblé não abriu a mesa da folha")
	await _segundos(2.0, lidas)
	await _no_marco("gameleira", [true, false])
	_conferir(fe.ativa == "caboclo", "trocar na gameleira deixou a fé em '%s'" % fe.ativa)
	inventario.adicionar("erva_da_serra", 3)
	inventario.adicionar("peixe", 2)
	inventario.adicionar("cana", 2)
	await _ir_a(marcos.ponto("terreiro") + Vector3(1.2, 0, 0.4), lidas)
	await _segundos(1.5, lidas)
	_conferir(mesa != null and not mesa.acabou() and inventario.quantidade("cana") >= 2,
		"com o caboclo ativo, a mesa do candomblé andou: a missão não congelou")
	var pirao: int = inventario.quantidade("pirao")
	await _no_marco("terreiro", [true, false])
	_conferir(fe.ativa == "candomble", "voltar ao terreiro deixou a fé em '%s'" % fe.ativa)
	await _ir_a(marcos.ponto("terreiro") + Vector3(1.2, 0, 0.4), lidas)
	if mesa != null:
		_conferir(await _ate(func() -> bool: return mesa.acabou(), 8.0, lidas), "de volta ao candomblé, a mesa da folha não foi entregue")
	_conferir(inventario.quantidade("pirao") == pirao + 2, "a mesa da folha não pagou os pirões")

	# --- 8. AS OSTRAS ---------------------------------------------------------------
	await _no_marco("gameleira", [true, false])
	var monte = cadeias.get("fe_caboclo")
	_conferir(fe.ativa == "caboclo" and monte != null, "não voltei ao caboclo para pagar o monte")
	var recursos = vale.get_node_or_null("Recursos3D")
	var ostras_antes: int = inventario.quantidade("ostra")
	for id in recursos._alvos.keys():
		if not str(id).begins_with("ostra_"):
			continue
		var alvo: Dictionary = recursos._alvos[id]
		var encostado: Vector3 = alvo["pos"] + Vector3(float(alvo.get("meia_pegada", 0.0)) + 0.28, 0.0, 0.0)
		await _ir_a(encostado, lidas)
		energia.encher()
		_conferir(recursos.bater(), "a ostra '%s' não se catou à mão" % str(id))
		await _frames(2)
	_conferir(inventario.quantidade("ostra") >= ostras_antes + 6, "as pedras da maré deram %d ostra(s)" % (inventario.quantidade("ostra") - ostras_antes))
	var assados: int = inventario.quantidade("peixe_assado")
	await _ir_a(marcos.ponto("gameleira") + Vector3(1.5, 0, 0.5), lidas)
	if monte != null:
		_conferir(await _ate(func() -> bool: return monte.acabou(), 8.0, lidas), "as ostras na gameleira não pagaram o monte")
	_conferir(inventario.quantidade("peixe_assado") == assados + 2, "pagar o monte não deu os peixes assados")

	# --- 9. O SAVE ---------------------------------------------------------------------
	var guardado: Dictionary = vale.estado_para_salvar()
	var filas: Dictionary = guardado.get("cadeias", {})
	for chave in ["pedro_fe", "fe_catolica", "fe_candomble", "fe_caboclo"]:
		_conferir(filas.has(chave), "o save não leva a fila '%s'" % chave)
	_fechar()


## Põe o jogador num ponto e deixa a física assentar, calando as falas que
## abrirem no caminho (as que se leem vão para `lidas`).
func _ir_a(onde: Vector3, lidas: Array = [], assentar: bool = true) -> void:
	var destino: Vector3 = vale.world.ground_position(onde, 0.05) if assentar else onde
	jogador.teleportar(destino, 0.0)
	await _segundos(0.4, lidas)


## Faz o marco responder, respondendo por ele (ver `fe_no_vale.gd`).
func _no_marco(marco: String, respostas: Array) -> void:
	var fila := respostas.duplicate()
	while dialogo.ativo:
		dialogo._fechar()
		await process_frame
	marcos.no_marco(marco)
	var ate := Time.get_ticks_msec() + 15000
	while marcos.ocupado() and Time.get_ticks_msec() < ate:
		if dialogo.ativo:
			if dialogo._modo == dialogo.Modo.PERGUNTA:
				dialogo._escolha = bool(fila.pop_front()) if not fila.is_empty() else false
				dialogo._escolheu = true
			dialogo._fechar()
		await process_frame
	_conferir(not marcos.ocupado(), "o marco '%s' não terminou de responder" % marco)
	await _frames(2)


func _calar(lidas: Array) -> void:
	if dialogo.ativo and not marcos.ocupado() and dialogo._modo != dialogo.Modo.PERGUNTA:
		lidas.append_array(dialogo._falas)
		dialogo._fechar()


func _ate(condicao: Callable, segundos: float, lidas: Array = []) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicao.call():
			return true
		_calar(lidas)
		await process_frame
	return condicao.call()


func _segundos(quanto: float, lidas: Array = []) -> void:
	var ate := Time.get_ticks_msec() + int(quanto * 1000.0)
	while Time.get_ticks_msec() < ate:
		_calar(lidas)
		await process_frame


func _fechar() -> void:
	while dialogo.ativo:
		dialogo._fechar()
	print("")
	if falhas == 0:
		print("CADEIA_DA_FE_OK: a fila da fé espera o mirante e abre com ele; a Dona Zefa fala quando se chega; os três lugares riscam a conta, contam o que se vê e pagam; contar a ela libera a escolha; escolher no marco fecha, paga, rende XP e abre a missão da fé; a romaria passa nos quatro marcos, o altar lá dentro; a missão de uma fé congela na troca e volta a correr na volta; as ostras se catam à mão e pagam o monte; e o save leva as filas")
	else:
		print("cadeia_da_fe: %d falha(s)" % falhas)
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
