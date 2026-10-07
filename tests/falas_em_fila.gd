extends SceneTree
## AS FALAS ESPERAM UMAS AS OUTRAS (fila_de_falas.gd).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/falas_em_fila.gd
##     ... -- --falsificar-fila        (o portão TEM de reprovar: o vale sem a fila)
##
## "As falas estão sendo sobrepostas, as falas precisam esperar umas as outras
## terminarem, entende?" (playtest da Build 9B, 06/10/2026). Cinco perguntas:
##
##   1. QUATRO PEDIDOS NO MESMO QUADRO — a conversa do E em dois moradores, um
##      anúncio de missão e a narração do mundo: nunca dois balões, duas vozes ou
##      balão e narração ao mesmo tempo; todos saem, na ordem da importância (as
##      conversas, a missão, a narração), e a conversa do E espera a vez.
##   2. O CUMPRIMENTO DE QUEM PASSA CAI com a vez ocupada: o vizinho encostado no
##      jogador não fala no meio da fila, nem depois dela.
##   3. O TAGARELA NÃO SEGURA A VEZ: com alguém falando sem parar, a fala da missão
##      sai dentro do desempate — e sai CORTANDO o balão dele, não por cima.
##   4. A CAIXA DE FALA SUSPENDE O BALÃO: aberta a caixa, o balão de quem falava
##      some e a voz pausa; fechada, ele volta de onde parou.
##   5. O E EM QUEM ESTÁ FALANDO PASSA A FALA, e não a recomeça.
##   6. A FESTA DA MISSÃO CEDE A VEZ à narração do mundo e à conversa do E: ela se
##      recolhe enquanto elas duram, sem nada por cima dela, e volta depois.
##
## E no fim, o histórico da fila: nenhum trecho no ar se sobrepõe a outro.

const ESPERA_MAXIMA := 16.0
## Folga para o desempate na máquina cheia (quatro portões em paralelo).
const FOLGA := 4.0
## `FilaDeFalas.Classe.MISSAO`, pelo valor: o portão não pré-carrega scripts do vale.
const MISSAO := 1

var falhas := 0
var falsificar := false
var vale
var fila
var dialogo
var narracao
var conquista
## Quantos quadros tiveram duas coisas no ar, e qual foi a primeira.
var _atropelos := 0
var _primeiro_atropelo := ""


func _initialize() -> void:
	for argumento in OS.get_cmdline_user_args():
		if argumento == "--falsificar-fila":
			falsificar = true
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("FALAS_EM_FILA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	vale = current_scene
	dialogo = root.get_node("/root/Dialogo")
	var dia = root.get_node("/root/Dia")
	dia.pausado = true
	dia.definir_hora(9.0)
	fila = vale.get("fila_de_falas")
	narracao = vale.get("narracao")
	conquista = vale.get("conquista")
	var pedro = vale.get("pedro")
	var jogador = vale.player
	var filo = vale._achar_morador("filo")
	var candinha = vale._achar_morador("candinha")
	var benedito = vale._achar_morador("benedito")
	_conferir(fila != null, "o vale não tem a fila de falas (fila_de_falas.gd)")
	_conferir(pedro != null and filo != null and candinha != null and benedito != null and narracao != null,
		"faltam o Pedro, a Dona Filó, a Dona Candinha, o Seu Benedito ou a narração")
	if fila == null or pedro == null or filo == null or candinha == null or benedito == null or narracao == null:
		_fechar()
		return
	if falsificar:
		# O VALE SEM A FILA: cada boca fala na hora, como antes. As perguntas de baixo
		# têm de reprovar.
		fila.remove_from_group("fila_de_falas")
		print("  (falsificado: a fila saiu do vale)")

	# Acabada a chegada: a fila do Pedro não anuncia sozinha no meio das perguntas.
	pedro.missao = pedro.MISSOES.size()
	pedro.set("_despedida_feita", true)
	var praca: Vector3 = vale.world.ancoras.get("Praça", jogador.global_position)
	var aqui: Vector3 = vale.world.ground_position(praca + Vector3(3.0, 0.0, 3.0), 0.1)
	jogador.teleportar(aqui, 0.0)
	_segurar(filo, aqui + Vector3(1.2, 0.0, 0.0))
	_segurar(candinha, aqui + Vector3(-1.2, 0.0, 0.0))
	_segurar(benedito, aqui + Vector3(0.0, 0.0, 2.2))
	for morador in [filo, candinha, benedito]:
		morador.set("_ultima_saudacao_ms", Time.get_ticks_msec())
	await _passos_de_fisica(20)
	await _vez_livre(30.0)

	# --- 1. QUATRO PEDIDOS NO MESMO QUADRO -------------------------------------------
	var ordem: Array[String] = []
	var viu := {"filo": false, "candinha": false, "pedro": false, "narracao": false}
	var ditas_do_vizinho := [0]
	benedito.saudou.connect(func(_quem, _texto: String) -> void: ditas_do_vizinho[0] += 1)
	var missao := "Uma fala da missão, que espera a vez dela."
	filo.conversar()
	candinha.conversar()
	pedro.narrar("", missao, {"classe": MISSAO, "origem": "portao:missao"})
	narracao.narrar(["A primeira frase do mundo.", "A segunda frase do mundo."])
	narracao.narrar(["A narração que vem depois, e não some."])
	# O VIZINHO ENCOSTADO no jogador, com o encontro em aberto: com a vez ocupada, o
	# cumprimento dele cai.
	benedito.set("_ultima_saudacao_ms", -1)
	await _quadros(2)
	if not falsificar:
		_conferir(filo.balao.visible and not candinha.balao.visible,
			"a conversa do E na Dona Candinha abriu junto da Dona Filó: a segunda não esperou a vez")
	var limite := Time.get_ticks_msec() + 90000
	var segunda_narracao := false
	while Time.get_ticks_msec() < limite:
		_contar_o_que_esta_no_ar()
		if filo.balao.visible and not viu["filo"]:
			viu["filo"] = true
			ordem.append("filo")
		if candinha.balao.visible and not viu["candinha"]:
			viu["candinha"] = true
			ordem.append("candinha")
		if pedro.balao.visible and _texto(pedro) == missao and not viu["pedro"]:
			viu["pedro"] = true
			ordem.append("pedro")
		if narracao.tocando() and narracao.frase() != "" and not viu["narracao"]:
			viu["narracao"] = true
			ordem.append("narracao")
		if narracao.frase().contains("depois"):
			segunda_narracao = true
		if viu["narracao"] and segunda_narracao and not narracao.tocando() and fila.livre():
			break
		await process_frame
	_conferir(viu["filo"] and viu["candinha"] and viu["pedro"] and viu["narracao"],
		"nem todo pedido saiu em 90 s: %s" % str(viu))
	_conferir(segunda_narracao, "a segunda narração pedida durante a primeira sumiu, em vez de esperar")
	_conferir(ordem == ["filo", "candinha", "pedro", "narracao"],
		"a ordem das falas foi %s, e devia ser as conversas do E, depois a missão, depois a narração" % str(ordem))
	_conferir(ditas_do_vizinho[0] == 0, "o vizinho cumprimentou %d vez(es) no meio da fila: o cumprimento de quem passa não cai" % ditas_do_vizinho[0])

	# --- 3. O TAGARELA NÃO SEGURA A VEZ ------------------------------------------------
	await _vez_livre(30.0)
	filo.set("_proxima_fala", 0)
	filo.conversar()
	await _quadros(2)
	_conferir(filo.balao.visible, "a Dona Filó não começou a falar com a vez livre")
	var pedida := Time.get_ticks_msec()
	var urgente := "A fala que não pode esperar para sempre."
	pedro.narrar("", urgente, {"classe": MISSAO, "origem": "portao:urgente"})
	var saiu := false
	var cortou := false
	limite = Time.get_ticks_msec() + int((ESPERA_MAXIMA + FOLGA + 4.0) * 1000.0)
	while Time.get_ticks_msec() < limite:
		filo._tomar_palavra(30.0)
		_contar_o_que_esta_no_ar()
		if pedro.balao.visible and _texto(pedro) == urgente:
			saiu = true
			cortou = not filo.balao.visible
			break
		await process_frame
	var esperou := (Time.get_ticks_msec() - pedida) / 1000.0
	_conferir(saiu, "com a Dona Filó falando sem parar, a fala da missão não saiu em %.0f s: a vez não tem desempate" % (ESPERA_MAXIMA + FOLGA + 4.0))
	if saiu:
		_conferir(cortou, "a fala da missão saiu com o balão da tagarela ainda aberto: por cima, e não cortando")
		if not falsificar:
			_conferir(esperou >= ESPERA_MAXIMA - 1.0,
				"a fala da missão furou a vez em %.1f s: só o desempate (%.0f s) corta quem está falando" % [esperou, ESPERA_MAXIMA])
		_conferir(esperou <= ESPERA_MAXIMA + FOLGA, "o desempate levou %.1f s, e o prazo é %.0f s" % [esperou, ESPERA_MAXIMA])

	# --- 4. A CAIXA DE FALA SUSPENDE O BALÃO -------------------------------------------
	await _vez_livre(30.0)
	pedro.narrar("", "Uma fala que a caixa de fala interrompe e devolve inteira ao vale.", {"classe": MISSAO, "origem": "portao:caixa"})
	await _quadros(2)
	_conferir(pedro.balao.visible, "a fala do Pedro não saiu com a vez livre")
	await _ate(func() -> bool: return false, 1.0)
	var antes_da_caixa: float = float(pedro.get("_balao_tempo"))
	dialogo.falar("", ["A caixa de fala, por cima de tudo."])
	await _quadros(3)
	_conferir(dialogo.ativo, "a caixa de fala não abriu")
	_conferir(not pedro.balao.visible, "com a caixa de fala aberta, o balão do Pedro continuou na tela")
	await _ate(func() -> bool: return false, 1.5)
	var durante_a_caixa: float = float(pedro.get("_balao_tempo"))
	_conferir(absf(durante_a_caixa - antes_da_caixa) < 0.6,
		"a fala do Pedro correu o relógio dela por baixo da caixa (%.1f s antes, %.1f s depois)" % [antes_da_caixa, durante_a_caixa])
	while dialogo.ativo:
		dialogo._fechar()
		await process_frame
	var voltou := await _ate(func() -> bool: return pedro.balao.visible, 3.0)
	_conferir(voltou, "fechada a caixa, a fala do Pedro não voltou ao balão")

	# --- 5. O E EM QUEM ESTÁ FALANDO PASSA A FALA -------------------------------------------
	await _vez_livre(30.0)
	filo.conversar()
	await _quadros(2)
	var primeira := _texto(filo)
	_conferir(filo.balao.visible and primeira != "", "a Dona Filó não começou a conversar")
	filo.conversar()
	await _quadros(2)
	if not falsificar:
		_conferir(not filo.balao.visible, "o E na Dona Filó falando recomeçou a fala ('%s'), em vez de passá-la" % _texto(filo))

	# --- 6. A FESTA DA MISSÃO CEDE A VEZ -------------------------------------------------
	await _vez_livre(30.0)
	if conquista != null:
		var caderno = root.get_node("/root/CadernoDoVale")
		caderno.abrir_missao("portao_festa", "A festa que cede a vez", "portao", false, "Uma missão do portão.")
		# A festa só vem pedida (07/10: a missão inteira festeja, o passo do meio não); o portão a pede.
		caderno.concluir("portao_festa", true)
		var festejou := await _ate(func() -> bool: return conquista.ativa(), 6.0)
		_conferir(festejou, "a missão cumprida não festejou com a vez livre")
		if festejou:
			await _ate(func() -> bool: return false, 0.8)
			narracao.narrar(["A narração do mundo passa na frente da festa."])
			var narrou := await _ate(func() -> bool: return narracao.frase() != "", 5.0)
			_conferir(narrou, "com a festa na tela, a narração não entrou: esperou a festa acabar")
			_conferir(not conquista.ativa(), "a narração entrou com a festa ainda na tela, por baixo dela")
			var voltou_a_festa := await _ate(func() -> bool: return not narracao.tocando() and conquista.ativa(), 25.0)
			_conferir(voltou_a_festa, "acabada a narração, a festa da missão não voltou")
			if voltou_a_festa:
				_calar_os_vizinhos()
				filo.conversar()
				await _quadros(2)
				_conferir(filo.balao.visible and not conquista.ativa(),
					"com a festa na tela, a conversa do E na Dona Filó não entrou (balão %s, festa %s)" % [str(filo.balao.visible), str(conquista.ativa())])
			await _vez_livre(40.0)
			_conferir(not conquista.ativa() and not conquista.esperando(), "a festa que cedeu a vez não terminou depois")

	# --- O HISTÓRICO: nenhum trecho no ar se sobrepõe a outro --------------------------
	await _vez_livre(30.0)
	var trechos: Array = (fila.historico as Array).duplicate()
	trechos.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["inicio_ms"]) < int(b["inicio_ms"]))
	for i in range(1, trechos.size()):
		var antes: Dictionary = trechos[i - 1]
		var depois: Dictionary = trechos[i]
		if int(antes["fim_ms"]) < 0 or int(depois["inicio_ms"]) < int(antes["fim_ms"]):
			_conferir(false, "no histórico da fila, '%s' (%s) entrou com '%s' (%s) ainda no ar" % [
				str(depois["texto"]), str(depois["falante"]), str(antes["texto"]), str(antes["falante"])])
			break
	_conferir(_atropelos == 0, "%d quadro(s) com duas falas no ar ao mesmo tempo; o primeiro: %s" % [_atropelos, _primeiro_atropelo])
	_fechar()


## Prende o morador num ponto (o caminho dele volta ao posto sem isto).
func _segurar(morador, ponto: Vector3) -> void:
	morador.ir_ate(ponto, 1.0)
	morador.global_position = ponto + Vector3.UP * 0.1


func _texto(morador) -> String:
	var rotulo = morador.balao.get("_texto")
	return str(rotulo.text) if rotulo != null else ""


## UMA COISA NO AR DE CADA VEZ: balões, a narração, a festa e a caixa; e uma voz.
func _contar_o_que_esta_no_ar() -> void:
	var no_ar: Array[String] = []
	var vozes: Array[String] = []
	var todos: Array = vale.moradores.duplicate()
	if vale.pedro != null:
		todos.append(vale.pedro)
	for morador in todos:
		if not is_instance_valid(morador):
			continue
		if morador.balao != null and morador.balao.visible:
			no_ar.append(str(morador.name))
		if morador.voz != null and morador.voz.playing and not morador.voz.stream_paused:
			vozes.append(str(morador.name))
	if narracao != null and narracao.tocando() and narracao.get("_fundo").visible:
		no_ar.append("narração")
	if conquista != null and conquista.ativa():
		no_ar.append("festa")
	if dialogo.ativo:
		no_ar.append("caixa")
	if no_ar.size() > 1 or vozes.size() > 1:
		_atropelos += 1
		if _primeiro_atropelo == "":
			_primeiro_atropelo = "no ar %s, vozes %s" % [str(no_ar), str(vozes)]


## Espera a vez ficar livre — lendo depressa: a fala com tempo se passa, como o E
## de quem já leu; a festa e a narração, não.
func _vez_livre(segundos: float) -> void:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite and not fila.livre():
		_calar_os_vizinhos()
		if not falsificar:
			fila.pular()
		if dialogo.ativo:
			dialogo._fechar()
		await process_frame
	for i in 2:
		_calar_os_vizinhos()
		await process_frame
	_calar_os_vizinhos()


## Os moradores da praça dão o encontro por feito: o cumprimento de quem passa
## não entra entre uma pergunta e a seguinte.
func _calar_os_vizinhos() -> void:
	for morador in vale.moradores:
		if is_instance_valid(morador):
			morador.set("_ultima_saudacao_ms", Time.get_ticks_msec())


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("FALAS_EM_FILA_OK: quatro pedidos no mesmo quadro saem um de cada vez, na ordem (as conversas do E, a missão, a narração), sem dois balões nem duas vozes; a segunda narração espera a primeira; o cumprimento de quem passa cai com a vez ocupada; quem fala sem parar é cortado pelo desempate, e não atropelado; a caixa de fala suspende o balão e o devolve; o E em quem fala passa a fala; e o histórico da fila não tem trecho sobreposto")
	else:
		print("falas_em_fila: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _passos_de_fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


## Roda quadros até `condicao` valer, com teto em SEGUNDO REAL.
func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		_contar_o_que_esta_no_ar()
		if condicao.call():
			return true
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
