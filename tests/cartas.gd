extends "res://tests/suite/caso.gd"
## Confere CARTAS E ACHADOS no vale (#12): cordéis no lugar deles, o sinal da
## Caipora na mata, a carta que espera o sinal, e o pacto firmado no lugar do
## mito ou no painel.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste cartas
##
## A regra é o `Cartas` e o `Colecao` compartilhados. Este portão pergunta o
## que é do vale:
##
##   1. NENHUM CORDEL ESQUECIDO: cada um dos dez tem lugar no vale ou está
##      declarado como faltando, com a razão. E quem tem lugar está no chão, em
##      terra (ou no piso do píer), perto da âncora do lugar dele.
##   2. PEGAR O CORDEL o guarda na coleção, paga o troco e o tira do chão — e
##      espalhar de novo (o que acontece ao carregar a partida) não o devolve.
##   3. A CARTA ESPERA O SINAL: antes de o jogador ver o sinal da Caipora, a
##      carta dela não está no chão. A mata do dendê é mata fechada, longe de
##      casa, da chegada e do caititu; a lagoa da Iara está declarada.
##   4. O PACTO NO LUGAR DO MITO, na conversa do 2D (#21): pegar a carta abre a
##      prosa dela na caixa de fala, depois o preço, depois a pergunta
##      "Firmar?". Sim firma — com o ganho do pacto no corpo —; Não deixa a
##      carta e diz que fica para outro dia. A carta de ritual não pergunta.
##   5. O PAINEL FIRMA E DESFAZ: a aba Cartas aparece com a primeira carta, e o
##      E nela firma e desfaz o pacto.

var falhas := 0
var colecao
var cartas
var jogo
var progressao


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("CARTAS_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	colecao = root.get_node("/root/Colecao")
	cartas = root.get_node("/root/Cartas")
	jogo = root.get_node("/root/Jogo")
	progressao = root.get_node("/root/Progressao")
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(6)
	await _mundo_pronto()
	await _frames(10)
	var vale = current_scene
	var player = vale.player
	var world = vale.world
	var achados = vale.get_node_or_null("Achados")
	_conferir(achados != null, "o vale não montou os achados")
	if achados == null:
		_fechar()
		return

	# --- 1. NENHUM CORDEL ESQUECIDO --------------------------------------------
	var todos: Array = colecao.ordem("cordeis")
	_conferir(todos.size() == 10, "a coleção tem %d cordéis, e o 2D tem dez" % todos.size())
	for id in todos:
		var tem_lugar: bool = achados.CORDEIS.has(id)
		var falta: bool = achados.CORDEIS_QUE_FALTAM.has(id)
		_conferir(tem_lugar != falta, "o cordel '%s' %s" % [id, "está nas duas listas" if tem_lugar else "não tem lugar nem razão de faltar"])
		if falta:
			_conferir(str(achados.CORDEIS_QUE_FALTAM[id]).length() > 20, "o cordel '%s' falta sem razão escrita" % id)
	for id in achados.CORDEIS:
		var achado = _no_chao(achados, "cordel", id)
		_conferir(achado != null, "o cordel '%s' não está no chão" % id)
		if achado == null:
			continue
		var ancora: Vector3 = world.ancoras[achados.CORDEIS[id]["ancora"]]
		var longe := _plano(achado["ponto"] - ancora)
		_conferir(longe < 14.0, "o cordel '%s' está a %.1f u do lugar dele" % [id, longe])
		if not bool(achados.CORDEIS[id].get("piso", false)):
			_conferir(world.is_on_land(achado["ponto"]), "o cordel '%s' caiu na água" % id)

	# --- 2. PEGAR O CORDEL -----------------------------------------------------
	var cordel = _no_chao(achados, "cordel", "peso_falso")
	if cordel != null:
		var reis: int = jogo.dinheiro
		_levar(player, world, cordel["ponto"])
		await _frames(2)
		_conferir(achados.interagir(), "perto do cordel, o E não pegou nada")
		_conferir(colecao.tem("cordeis", "peso_falso"), "o cordel pego não entrou na coleção")
		_conferir(jogo.dinheiro == reis + int(colecao.dados("cordeis", "peso_falso").get("valor", 0)), "o cordel não pagou o troco")
		_conferir(_no_chao(achados, "cordel", "peso_falso") == null, "o cordel pego continuou no chão")
		# O cordel achado abre no papel (#21); guardar devolve o vale. O PRIMEIRO
		# vem antes com o aviso do que é um cordel (`aviso_da_primeira_vez.gd`):
		# fechado o aviso, o papel abre.
		await _frames(2)
		var aviso = vale.get("aviso_da_primeira_vez")
		if aviso != null and aviso.aberto():
			aviso.fechar()
			await _frames(3)
		_conferir(root.get_node("/root/Folheto").aberto, "o cordel pego não abriu no papel")
		vale.telas.fechar_tudo()
		await _frames(2)
		achados.espalhar()
		_conferir(_no_chao(achados, "cordel", "peso_falso") == null, "espalhar de novo devolveu o cordel já achado")

	# --- 3. A CARTA ESPERA O SINAL ---------------------------------------------
	_conferir(achados.lugares.has("mata_do_dende"), "o vale não tem a mata da Caipora")
	_conferir(str(achados.LUGARES_QUE_FALTAM.get("lagoa", "")).length() > 20, "a lagoa da Iara não está declarada")
	var sinal = _no_chao(achados, "sinal", "a_mata_que_parou")
	_conferir(sinal != null, "o sinal da Caipora não está na mata")
	_conferir(_no_chao(achados, "carta", "caipora") == null, "a carta da Caipora já estava no chão antes do sinal")
	_conferir(_no_chao(achados, "carta", "iara") == null, "a carta da Iara está no chão sem lagoa")
	if sinal == null:
		_fechar()
		return
	var mata: Vector3 = achados.lugares["mata_do_dende"]
	_conferir(world.na_mata_fechada(mata), "o lugar da Caipora não é mata fechada")
	var luta = vale.get_node("Luta")
	if not luta.criaturas.is_empty():
		_conferir(_plano(mata - luta.criaturas[0]._ninho) >= achados.LONGE_DO_BICHO, "a Caipora mora em cima do ninho do caititu")
	_levar(player, world, sinal["ponto"])
	await _frames(2)
	_conferir(achados.interagir(), "perto do sinal, o E não fez nada")
	_conferir(colecao.tem("sinais", "a_mata_que_parou"), "o sinal visto não foi anotado")
	_conferir(_no_chao(achados, "carta", "caipora") != null, "depois do sinal, a carta da Caipora não apareceu")
	_conferir(_no_chao(achados, "carta", "olho_da_mata") != null, "depois do sinal, o olho da mata não apareceu")

	# --- 4. O PACTO NO LUGAR DO MITO -------------------------------------------
	var dialogo = root.get_node("/root/Dialogo")
	var ritual = _no_chao(achados, "carta", "olho_da_mata")
	_levar(player, world, ritual["ponto"])
	await _frames(2)
	achados.interagir()
	await _frames(2)
	_conferir(cartas.tem("olho_da_mata"), "o ritual pego não foi aprendido")
	_conferir(dialogo.ativo, "a prosa do ritual não abriu na caixa de fala")
	await _passar_as_falas(dialogo)
	_conferir(not dialogo.ativo, "a carta de ritual terminou numa pergunta: ritual não se firma")
	var carta = _no_chao(achados, "carta", "caipora")
	_levar(player, world, carta["ponto"])
	await _frames(2)
	var esforco: float = progressao.eficiencia
	achados.interagir()
	await _frames(2)
	_conferir(cartas.tem("caipora"), "a carta da Caipora pega não foi aprendida")
	_conferir(cartas.pacto == "", "pegar a carta já firmou o pacto, sem perguntar")
	_conferir(paused, "a conversa do pacto abriu com o vale andando atrás dela")
	await _passar_as_falas(dialogo)
	_conferir(dialogo.ativo and dialogo._modo == dialogo.Modo.PERGUNTA,
		"a conversa do pacto não chegou à pergunta 'Firmar?'")
	_conferir(str(dialogo._texto.text).contains(str(cartas.nome("caipora")).to_lower()),
		"a pergunta não diz qual pacto se firma: '%s'" % dialogo._texto.text)
	await _tecla(KEY_A)
	await _tecla(KEY_E)
	await _frames(3)
	_conferir(cartas.pacto == "caipora", "responder Sim não firmou o pacto")
	_conferir(not paused, "o vale ficou parado depois da conversa do pacto")
	_conferir(progressao.eficiencia < esforco, "o pacto firmado não mexeu no esforço (%s → %s)" % [str(esforco), str(progressao.eficiencia)])
	cartas.desfazer()
	# NÃO deixa a carta com o jogador, e diz que fica para outro dia.
	achados._oferecer_pacto("caipora")
	await _frames(2)
	await _passar_as_falas(dialogo)
	await _tecla(KEY_D)
	await _tecla(KEY_E)
	await _frames(2)
	_conferir(dialogo.ativo and dialogo._modo == dialogo.Modo.FALA,
		"dizer Não fechou a conversa sem dizer que fica para outro dia")
	await _passar_as_falas(dialogo)
	_conferir(cartas.pacto == "" and cartas.tem("caipora"), "recusar o pacto levou a carta junto")

	# --- 5. O PAINEL FIRMA E DESFAZ --------------------------------------------
	var painel = vale.painel
	vale.abrir_o_painel()
	await _frames(2)
	_conferir(painel.abas_validas().has(painel.Aba.CARTAS), "com carta na mão, a aba Cartas não apareceu")
	painel._proxima_aba(1)
	_conferir(painel.aba() == painel.Aba.CARTAS, "não cheguei à aba Cartas")
	var minhas: Array = cartas.minhas()
	painel.escolher(minhas.find("caipora"))
	painel._confirmar()
	_conferir(cartas.pacto == "caipora", "o E na aba Cartas não firmou o pacto")
	painel._confirmar()
	_conferir(cartas.pacto == "", "o E de novo na aba Cartas não desfez o pacto")
	painel.fechar()
	_fechar()


func _no_chao(achados, tipo: String, id: String):
	for achado in achados.no_chao:
		if achado["tipo"] == tipo and achado["id"] == id:
			return achado
	return null


func _levar(player, world, onde: Vector3) -> void:
	player.global_position = onde + Vector3(0.0, 0.1, 0.0)
	player.velocity = Vector3.ZERO


## Passa as falas da caixa com o E, como o jogador passa: espera a carência de
## cada linha. Para quando a caixa fecha ou chega a uma pergunta.
func _passar_as_falas(dialogo) -> void:
	for i in 40:
		await _frames(1)
		if not dialogo.ativo or dialogo._modo == dialogo.Modo.PERGUNTA:
			return
		var ate := Time.get_ticks_msec() + int((dialogo.CARENCIA_DE_ABERTURA + 0.05) * 1000.0)
		while Time.get_ticks_msec() < ate:
			await process_frame
		await _tecla(KEY_E)


## Aperta e solta uma tecla pelo `Input`, que é por onde a caixa de fala lê.
func _tecla(codigo: int) -> void:
	var aperta := InputEventKey.new()
	aperta.physical_keycode = codigo
	aperta.pressed = true
	Input.parse_input_event(aperta)
	await _frames(2)
	var solta := InputEventKey.new()
	solta.physical_keycode = codigo
	solta.pressed = false
	Input.parse_input_event(solta)
	await _frames(2)


func _plano(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("CARTAS_OK: os dez cordéis têm lugar ou razão, e os do vale estão no chão perto do lugar; pegar guarda, paga e não volta; a carta da Caipora espera o sinal na mata; a carta abre a conversa do pacto na caixa de fala, o Sim firma no lugar, o Não recusa sem perder a carta, e o painel firma e desfaz")
	else:
		print("cartas: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
