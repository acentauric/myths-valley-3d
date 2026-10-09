extends SceneTree
## Confere O E NOS MORADORES e A CONQUISTA DA MISSÃO.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/interacao.gd
##     ... -- --falsificar-fila        (o portão TEM de reprovar: o vale sem a fila de falas)
##
## "Quando fui falar com Dona Candinha para pegar a chave, não consegui
## interagir. Eu tinha deletado o save e abri um novo em cima do mesmo slot. [...]
## O ideal é o Pedro ensinar a apertar E para iniciar as interações com os NPCs,
## incluindo cumprir etapas de missões. Sempre que concluir uma missão, deve
## aparecer uma animação na tela, sombreando toda a tela e dando um destaque para
## a animação." E, do playtest da Build 9B: "as falas estão sendo sobrepostas, as
## falas precisam esperar umas as outras terminarem" (fila_de_falas.gd). Sete
## perguntas, e em todas elas nunca dois balões no ar ao mesmo tempo:
##
##   1. A PARTIDA NOVA ZERA O CADERNO: missões da partida anterior (ativas,
##      cumpridas e a acompanhada) não passam para a nova no mesmo slot.
##   2. O E NUM MORADOR SEM MISSÃO É CONVERSA: ao lado dele, a dica do E está
##      nele, e o E o faz dizer a fala inteira, e não a curta da saudação — NA
##      VEZ DELE: com outro falando, o balão dele espera.
##   3. O PASSO SE CUMPRE NO E: ao lado do Pedro, no desembarque, nada fecha
##      sozinho; o E fecha, com a resposta dele.
##   4. A CONQUISTA: o passo cumprido escurece a tela e mostra "Missão
##      concluída" com o nome do passo — DEPOIS da resposta de quem fala, com o
##      relógio parado durante a fala e durante a festa, entrando devagar e
##      ficando pelo menos cinco segundos, com as plaquinhas de nome dos
##      moradores recolhidas enquanto dura.
##   5. A FILA DE UM MORADOR ABRE NO E: depois da chegada, ao lado do Tonho, a
##      fila dele não abre sozinha; o E a abre, e ele diz o pedido na vez dele.
##   6. A VEZ DE FALAR NÃO SE ATROPELA E TEM PRAZO: com alguém falando sem parar
##      ao lado do jogador, o passo seguinte se anuncia na hora (o caderno, o
##      objetivo), e a FALA dele espera — e sai no desempate da fila CORTANDO o
##      balão de quem não para, e nunca por cima dele. (Até 06/10/2026 este item
##      dizia o contrário: depois de seis segundos o passo falava por cima de quem
##      estivesse falando, `ESPERA_MAXIMA_PELA_VEZ`. Era o atropelo de propósito.)
##   7. O E EM QUEM NÃO FALA É ACENO: num morador novo, que não tem fala, o E não
##      abre balão vazio, não põe aviso no HUD e não segura o relógio.

## O desempate da fila de falas (`FilaDeFalas.ESPERA_MAXIMA`), e a folga da
## máquina cheia.
const ESPERA_MAXIMA := 16.0
const FOLGA := 4.0

const PovoadoLiberado = preload("res://tests/fixtures/povoado_liberado.gd")
const ConversaDoE = preload("res://tests/fixtures/conversa_do_e.gd")

var falhas := 0
var falsificar := false
var dialogo
var vale
## Quadros com dois balões no ar, e o primeiro deles.
var _atropelos := 0
var _primeiro_atropelo := ""


func _initialize() -> void:
	falsificar = OS.get_cmdline_user_args().has("--falsificar-fila")
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("INTERACAO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	# --- 1. A PARTIDA NOVA ZERA O CADERNO ---------------------------------------
	var caderno = root.get_node("/root/CadernoDoVale")
	var partida = root.get_node("/root/Partida")
	caderno.abrir_missao("pedro_chave", "Quem guardou a chave", "pedro", true, "A partida apagada.")
	caderno.abrir_missao("pedro_bom_dia", "Quem chega, cumprimenta", "pedro", true, "")
	# A festa só vem pedida (07/10: a missão inteira festeja, o passo do meio não); aqui o que
	# se mede é a HORA dela, então o portão a pede com os dados do passo.
	caderno.concluir("pedro_bom_dia", true)
	caderno.fixar("pedro_chave")
	partida.comecar(1, true)
	_conferir(caderno.ativas.is_empty() and caderno.cumpridas.is_empty() and caderno.foco == "",
		"a partida nova no mesmo slot ficou com o caderno da anterior: %d ativa(s), %d cumprida(s), foco '%s'" % [caderno.ativas.size(), caderno.cumpridas.size(), caderno.foco])

	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	dialogo = root.get_node("/root/Dialogo")
	vale = current_scene
	# O povoado se apresenta aos poucos na chegada (#155): este portão fala com moradores de longe.
	await PovoadoLiberado.todos(self, vale)
	# O ACEITE É AUTOMÁTICO AQUI (08/10): este portão abre filas pelo E e segue; a tela de aceite
	# pausaria o vale no meio da medida (a tela tem portão próprio, tests/missao_a_vista.gd).
	if vale.get("aceite") != null:
		vale.aceite.automatico = true
	var jogador = vale.player
	var pedro = vale.get("pedro")
	var tecla = vale.get("tecla_dos_moradores")
	var conquista = vale.get("conquista")
	var fila_de_falas = vale.get("fila_de_falas")
	_conferir(pedro != null and tecla != null and conquista != null, "o vale não tem o Pedro, o E dos moradores ou a tela da conquista")
	_conferir(fila_de_falas != null, "o vale não tem a fila de falas (fila_de_falas.gd)")
	if pedro == null or tecla == null or conquista == null or fila_de_falas == null:
		_fechar()
		return
	if falsificar:
		# O VALE SEM A FILA: cada boca fala na hora, como antes. Tem de reprovar.
		fila_de_falas.remove_from_group("fila_de_falas")
		print("  (falsificado: a fila de falas saiu do vale)")
	root.get_node("/root/Dia").pausado = true

	# --- 2. O E NUM MORADOR SEM MISSÃO É CONVERSA --------------------------------
	var filo = vale._achar_morador("filo")
	_conferir(filo != null, "o vale não tem a Dona Filó")
	if filo != null:
		_ao_lado_de(jogador, filo, Vector3(1.2, 0.1, 0.0))
		await _passos_de_fisica(10)
		_conferir(tecla.perto() == filo, "ao lado da Dona Filó, o E não está nela (está em %s)" % str(tecla.perto()))
		# NA VEZ DELA: com outro falando, o balão dela espera; com outro só
		# cumprimentando (o Pedro, que acabou de saudar no píer), o E corta o
		# cumprimento; sem ninguém, sai na hora. Nunca os dois balões juntos.
		var no_ar := _quem_fala(fila_de_falas)
		var era_cumprimento := int((fila_de_falas.atual() as Dictionary).get("classe", -1)) == 3
		var outro = (fila_de_falas.atual() as Dictionary).get("falante")
		_apertar_e(tecla)
		await _quadros(2)
		if no_ar != "" and no_ar != str(filo.name):
			if era_cumprimento:
				_conferir(filo.balao.visible and not (outro as Node).get("balao").visible,
					"o E na Dona Filó não cortou o cumprimento de %s (balão dela %s, dele %s)" % [no_ar, str(filo.balao.visible), str((outro as Node).get("balao").visible)])
			else:
				_conferir(not filo.balao.visible, "o E na Dona Filó abriu o balão dela por cima da fala de %s" % no_ar)
		var conversou := await _ate(func() -> bool: return filo._balao_tempo > 0.0 and _no_balao(filo) != "", 30.0)
		var dita := _no_balao(filo)
		_conferir(conversou, "o E na Dona Filó não a fez conversar, nem na vez dela")
		_conferir(dita.length() > 60, "a conversa do E é a fala curta da saudação, e não a inteira: '%s'" % dita)

	# --- 3. O PASSO SE CUMPRE NO E -----------------------------------------------
	_conferir(pedro.passo_em_curso() == "desembarque", "a chegada não começou pelo desembarque")
	await _ate(func() -> bool: return float(pedro.get("_espera")) <= 0.0, 15.0)
	_ao_lado_de(jogador, pedro, Vector3(1.0, 0.1, 0.6))
	await _passos_de_fisica(60)
	_conferir(pedro.passo_em_curso() == "desembarque", "ao lado do Pedro o desembarque fechou sozinho, sem o E")
	# FALA NO AR TIRA O E (#121, `tecla_dos_moradores._fala_ativa`): o anúncio do desembarque é do Pedro e dura a leitura
	# inteira, em relógio de parede; o jogador que chegou com ele falando espera acabar para apertar o E.
	await _ate(func() -> bool: return not pedro.falando_agora(), 30.0)
	_conferir(tecla.perto() == pedro, "ao lado do Pedro, o E não está nele")
	_apertar_e(tecla)
	caderno.festeja.emit({"id": "pedro_desembarque", "titulo": "As pernas de terra firme", "missao": "Chegada ao arraial", "quem": "Pedro"})
	# A resposta é dele, na vez dele: quem ainda falava (a Dona Filó) termina antes.
	var respondeu := await _ate(func() -> bool: return _no_balao(pedro).contains("Bom Jesus dos Pobres"), 30.0)
	_conferir(respondeu, "o E no Pedro não trouxe a resposta do desembarque: '%s'" % _no_balao(pedro))

	# --- 4. A CONQUISTA ------------------------------------------------------------
	# DEPOIS DA CONVERSA: o passo fechou no E, com a resposta do Pedro ainda no
	# balão, e a festa espera ele acabar ("o efeito também só deve aparecer depois
	# que terminar a interação com o NPC"). Enquanto ele fala, o relógio do vale
	# fica parado ("o relógio deve parar quando o jogador estiver em uma interação
	# de conversa com o NPC").
	var dia_do_vale = root.get_node("/root/Dia")
	_conferir(pedro.conversando() and dia_do_vale.segurado("fala:"),
		"com o Pedro respondendo no balão, o relógio do vale não parou")
	var por_cima := await _ate(func() -> bool: return conquista.ativa(), 2.0)
	_conferir(not por_cima and conquista.esperando(),
		"a conquista entrou por cima da resposta do Pedro, com ele ainda falando")
	var festejou := await _ate(func() -> bool: return conquista.ativa(), 15.0)
	_conferir(festejou, "acabada a resposta do Pedro, o desembarque cumprido não mostrou a tela da conquista")
	if festejou:
		var desde := Time.get_ticks_msec()
		_conferir(not pedro.conversando(), "a conquista entrou com o Pedro ainda no balão")
		_conferir(dia_do_vale.segurado("conquista"), "a festa da conquista não segurou o relógio do vale")
		# AS PLAQUINHAS DE NOME SE RECOLHEM: são do HUD, que desenha por cima da
		# festa, e o nome do Pedro — parado na frente do jogador — caía no emblema.
		_conferir(not vale.placas._permitido,
			"durante a festa da missão, as plaquinhas de nome dos moradores continuam acesas por cima dela")
		_conferir(str(conquista.mostrada.get("titulo", "")) == "As pernas de terra firme",
			"a conquista mostra '%s', e o passo cumprido é 'As pernas de terra firme'" % str(conquista.mostrada.get("titulo", "")))
		# O CARTÃO COMPACTO (#130): a conquista não escurece nem embranquece o vale —
		# ocupa um cartão — e dura o que dura (ENTRA + FICA + SAI), sem tomar o jogo.
		var sombra: ColorRect = conquista.get("_sombra")
		await _ate(func() -> bool: return false, 1.0)
		_conferir(sombra == null or sombra.color.a == 0.0,
			"a conquista escureceu o vale (sombra %.2f): o cartão compacto não escurece" % (sombra.color.a if sombra != null else -1.0))
		_conferir(str(conquista.get("_titulo").text) == "MISSÃO CONCLUÍDA", "o título da conquista é '%s'" % str(conquista.get("_titulo").text))
		_conferir(await _ate(func() -> bool: return not conquista.ativa(), 14.0), "a tela da conquista não sumiu sozinha")
		var durou := (Time.get_ticks_msec() - desde) / 1000.0
		var prevista: float = conquista.ENTRA + conquista.FICA + conquista.SAI
		_conferir(durou >= prevista * 0.8, "a conquista ficou %.1f s na tela, e o cartão dura %.1f s" % [durou, prevista])
		_conferir(not dia_do_vale.segurado("conquista"), "a festa acabou e o relógio continuou segurado por ela")
		_conferir(vale.placas._permitido, "a festa acabou e as plaquinhas de nome dos moradores não voltaram")

	# --- 5. A FILA DE UM MORADOR ABRE NO E -----------------------------------------
	pedro.missao = pedro.MISSOES.size()
	pedro.set("_despedida_feita", true)
	# A rede do Tonho é de madeira: a fila dele espera os machados do avô, na
	# ponte (`prototype._ja_recebeu_o_machado`). Aqui a ponte já passou deles.
	var da_ponte = vale._cadeias.get("pedro_ponte")
	if da_ponte != null:
		da_ponte.iniciado = true
		for i in da_ponte.passos.size():
			if str((da_ponte.passos[i] as Dictionary).get("id", "")) == "buscar_machado":
				da_ponte.missao = i + 1
	var tonho = vale._achar_morador("tonho")
	var fila = vale._cadeias.get("tonho")
	_conferir(fila != null, "o Tonho não tem fila de pedidos")
	if fila != null:
		_ao_lado_de(jogador, tonho, Vector3(1.0, 0.1, 0.6))
		await _ate(func() -> bool: return false, 2.0)
		_conferir(not fila.iniciado, "ao lado do Tonho, a fila dele abriu sozinha, sem o E")
		_conferir(tecla.perto() == tonho, "ao lado do Tonho, o E não está nele")
		_apertar_e(tecla)
		_conferir(fila.iniciado, "o E no Tonho, depois da chegada, não abriu a fila dele")
		var pediu := await _ate(func() -> bool: return tonho._balao_tempo > 0.0 and _no_balao(tonho) != "", 30.0)
		_conferir(pediu, "o E abriu a fila do Tonho, mas ele não disse o pedido, nem na vez dele")

	# --- 6. A VEZ DE FALAR NÃO SE ATROPELA E TEM PRAZO ---------------------------------
	# A fila do Tonho anuncia de novo o passo em que está; com o Pedro falando sem
	# parar ao lado do jogador, o anúncio acontece na hora — o caderno, o objetivo —
	# e a fala do Tonho espera a vez: sai no desempate, cortando o Pedro.
	if fila != null and fila.iniciado:
		await _vez_livre(fila_de_falas, 40.0)
		var antes: int = fila.missao
		pedro.global_position = jogador.global_position + Vector3(2.0, 0.1, 0.0)
		pedro.narrar("", "Uma fala do Pedro que não acaba nunca, de quem segura a palavra sem largar.",
			{"classe": 0})
		await _quadros(2)
		_conferir(pedro.balao.visible, "com a vez livre, o Pedro não começou a falar")
		var pedida := Time.get_ticks_msec()
		fila.espera = 0.05
		var limite := Time.get_ticks_msec() + int((ESPERA_MAXIMA + FOLGA + 4.0) * 1000.0)
		var anunciou := false
		var falou := false
		var atropelou := false
		while Time.get_ticks_msec() < limite:
			pedro._tomar_palavra(30.0)
			_contar_os_baloes()
			if float(fila.espera) <= 0.0:
				anunciou = true
			if tonho.balao.visible:
				falou = true
				atropelou = pedro.balao.visible
				break
			await process_frame
		var esperou := (Time.get_ticks_msec() - pedida) / 1000.0
		_conferir(anunciou and fila.missao == antes, "com alguém falando sem parar, o passo não se anunciou: o anúncio esperou a palavra")
		_conferir(falou, "com o Pedro falando sem parar, a fala do Tonho não saiu em %.0f s: a vez não tem prazo" % (ESPERA_MAXIMA + FOLGA + 4.0))
		if falou:
			_conferir(not atropelou, "a fala do Tonho saiu com o balão do Pedro ainda aberto: por cima, e não cortando")
			_conferir(esperou >= ESPERA_MAXIMA - 1.0,
				"a fala do Tonho furou a vez em %.1f s: só o desempate (%.0f s) corta quem está falando" % [esperou, ESPERA_MAXIMA])
		await _fechar_a_fala()

	# --- 7. O E EM QUEM NÃO FALA É ACENO ---------------------------------------------
	# Os moradores novos tinham jornada e ofício, e nenhuma fala (`npc._eh_mudo`). A
	# conversa do E neles abria um balão sem texto, punha "Nome: " no HUD e segurava
	# o relógio por dez segundos de uma fala que não havia. Desde 06/10/2026 os catorze
	# falam (a #85 e `falas_dos_moradores.gd`) e ninguém é mudo: o MECANISMO segue coberto
	# por um mudo sintético — um deles, de corpo presente, calado aqui (`dados["mudo"]`).
	# Um morador SEM FILA DE MISSÃO: no Benedito, na Zefa ou no Tonho o E abre a
	# fala da missão, que não é o aceno.
	var calado = null
	for id in ["guarda", "lavadeira", "rendeira", "pescador", "marisqueira", "sacristao", "beata", "quituteira", "carpinteiro"]:
		var morador = vale._achar_morador(id)
		if morador != null and morador.is_visible_in_tree() and not morador.esta_recolhido():
			calado = morador
			break
	if calado == null:
		for morador in vale.moradores:
			if morador.dados.has("agenda") and morador.is_visible_in_tree() and not morador.esta_recolhido():
				calado = morador
				break
	_conferir(calado != null, "o vale não tem morador de jornada, de corpo presente, para a pergunta do aceno")
	if calado != null:
		# Sem balão nem relógio de uma fala anterior: a pergunta é só sobre o aceno.
		calado.calar()
		calado.dados["mudo"] = true
		var avisos := [0]
		calado.saudou.connect(func(_quem, _texto: String) -> void: avisos[0] += 1)
		# Ao lado dele: a trava do relógio só pega com o jogador ao alcance da conversa.
		_ao_lado_de(jogador, calado, Vector3(1.0, 0.1, 0.6))
		await _passos_de_fisica(4)
		await ConversaDoE.usar(tecla, calado)
		await _quadros(2)
		_conferir(float(calado._balao_tempo) <= 0.0, "o E em quem não fala (%s) abriu um balão sem texto" % str(calado.dados.get("id", "")))
		_conferir(not calado.conversando(), "o E em quem não fala segurou o relógio do vale por uma fala que não há")
		_conferir(avisos[0] == 0, "o E em quem não fala pôs um aviso vazio no HUD")
		calado.dados.erase("mudo")
	_fechar()


## AO LADO DE QUEM SE FALA, VIRADO PARA ELE: o E vai para o que está na frente do
## corpo (`foco_do_e.gd`), e no píer o cordel pendurado fica a dois passos do
## Tonho. Quem quer conversar se vira para a pessoa.
func _ao_lado_de(jogador, morador, desvio: Vector3) -> void:
	var onde: Vector3 = morador.global_position + desvio
	var para_ele: Vector3 = morador.global_position - onde
	jogador.teleportar(onde, atan2(para_ele.x, para_ele.z))


## O que está no balão de quem fala.
func _no_balao(morador) -> String:
	var rotulo = morador.balao.get("_texto")
	return str(rotulo.text) if rotulo != null else ""


## O E, pelo caminho do jogo: a tecla de interagir, a quem conversa com os
## moradores.
func _apertar_e(tecla) -> void:
	var evento := InputEventKey.new()
	evento.keycode = KEY_E
	evento.physical_keycode = KEY_E
	evento.pressed = true
	tecla._unhandled_key_input(evento)


func _fechar_a_fala() -> void:
	var ate := Time.get_ticks_msec() + 4000
	while dialogo.ativo and Time.get_ticks_msec() < ate:
		dialogo._fechar()
		await process_frame
	await _quadros(3)


func _fechar() -> void:
	_conferir(_atropelos == 0, "%d quadro(s) com duas falas no ar ao mesmo tempo; o primeiro: %s" % [_atropelos, _primeiro_atropelo])
	print("")
	if falhas == 0:
		print("INTERACAO_OK: a partida nova zera o caderno da anterior; o E num morador sem missão o faz dizer a fala inteira, na vez dele; o passo que manda falar com alguém fecha no E, e não ao chegar perto; o relógio para enquanto ele responde; a conquista espera a resposta acabar, entra devagar, escurece a tela com o nome do passo, segura o relógio, fica mais de cinco segundos e some sozinha; a fila de um morador abre no E, e não sozinha; com alguém falando sem parar o passo se anuncia na hora e a fala dele sai no desempate, cortando quem não para, nunca por cima; nunca dois balões no ar; e o E em quem não fala é só o aceno, sem balão vazio nem relógio parado")
	else:
		print("interacao: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


## O nome de quem está no ar na fila de falas, ou "".
func _quem_fala(fila_de_falas) -> String:
	var no_ar: Dictionary = fila_de_falas.atual()
	var quem = no_ar.get("falante")
	return str(quem.name) if quem is Node and is_instance_valid(quem) else ""


## NUNCA DOIS BALÕES NO AR, nem balão com a festa da missão por cima.
func _contar_os_baloes() -> void:
	if vale == null:
		return
	var no_ar: Array[String] = []
	var todos: Array = vale.moradores.duplicate()
	if vale.pedro != null:
		todos.append(vale.pedro)
	for morador in todos:
		if is_instance_valid(morador) and morador.balao != null and morador.balao.visible:
			no_ar.append(str(morador.name))
	var conquista = vale.get("conquista")
	if conquista != null and conquista.ativa():
		no_ar.append("festa")
	if no_ar.size() > 1:
		_atropelos += 1
		if _primeiro_atropelo == "":
			_primeiro_atropelo = str(no_ar)


## Espera a vez de falar ficar livre, lendo depressa (o E de quem já leu).
func _vez_livre(fila_de_falas, segundos: float) -> void:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite and not fila_de_falas.livre():
		fila_de_falas.pular()
		if dialogo.ativo:
			dialogo._fechar()
		await process_frame
	await _quadros(2)


func _passos_de_fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


## Roda quadros até `condicao` valer, com teto em SEGUNDO REAL, contando os
## balões no ar a cada quadro.
func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		_contar_os_baloes()
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
