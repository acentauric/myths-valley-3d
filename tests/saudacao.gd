extends "res://tests/suite/caso.gd"
## A SAUDAÇÃO DE APROXIMAÇÃO: quem tem missão não cumprimenta, e o balão é curto.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste saudacao
##
## "Quando encostar no NPC com missão, o NPC não [deve] falar a fala de
## aproximação. Isso tá deixando o jogador confuso. Os textos das falas de
## aproximação apresentados no balão também estão grandes. Podemos deixar a
## fala dele por extenso, mas enxugar o balão. Isso se aplica somente às falas
## por aproximação." (05/10/2026)
##
## Quatro perguntas:
##
##   1. O BALÃO DE TODA SAUDAÇÃO É CURTO, nos três idiomas: no máximo
##      `BALAO_CURTO` letras, nunca vazio, e é o começo da fala inteira — também
##      nas falas do Pedro de depois do tutorial (`falas_depois`).
##   2. QUEM TEM MISSÃO NÃO CUMPRIMENTA. Na chegada, o primeiro passo do Pedro
##      manda dar bom-dia ao Tonho: ao lado dele, com a palavra livre, sai a
##      resposta da missão e nenhuma saudação.
##   3. QUEM NÃO TEM MISSÃO CUMPRIMENTA, com a fala inteira no aviso (`saudou`)
##      e o balão enxuto.
##   4. O PEDRO DE DEPOIS DO TUTORIAL NÃO SE APRESENTA DE NOVO: "Opa! É você o
##      moço da capital?" era a fala dele para sempre. Acabada a chegada, o E nele
##      diz as falas de quem já conhece o jogador, nenhuma do primeiro encontro,
##      e não sempre a mesma.
##
## A palavra livre se espera pela fila de falas (`fila_de_falas.gd`), lendo
## depressa: a fala no ar se passa, como o E de quem já leu.

var falhas := 0
const SEGUNDOS_PARA_ANUNCIAR := 12.0
const SEGUNDOS_DE_PALAVRA := 25.0
const SEGUNDOS_PARA_SAUDAR := 4.0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("SAUDACAO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(3)

	var jogo := current_scene
	# O ACEITE É AUTOMÁTICO AQUI (08/10): este portão abre filas pelo E e segue; a tela de aceite
	# pausaria o vale no meio da medida (a tela tem portão próprio, tests/missao_a_vista.gd).
	if jogo.get("aceite") != null:
		jogo.aceite.automatico = true
	var jogador = jogo.get("player")
	var pedro = jogo.get("pedro")
	var moradores: Array = jogo.get("moradores")
	var tonho: Node3D = null
	for morador in moradores:
		if str((morador.dados as Dictionary).get("id", "")) == "tonho":
			tonho = morador
	_conferir(jogador != null and pedro != null and tonho != null, "não achei o jogador, o Pedro ou o Tonho")
	if jogador == null or pedro == null or tonho == null:
		_fechar()
		return

	# --- 1. O BALÃO DE TODA SAUDAÇÃO É CURTO ---------------------------------
	var limite: int = tonho.BALAO_CURTO
	var encurtadas := 0
	for morador in moradores + [pedro]:
		var dados: Dictionary = morador.dados
		var textos: Array = []
		if str(dados.get("fala", "")) != "":
			textos.append(str(dados["fala"]))
		for fala in (dados.get("falas", []) as Array) + (dados.get("falas_depois", []) as Array):
			for chave in ["texto", "texto_en", "texto_es"]:
				if str((fala as Dictionary).get(chave, "")) != "":
					textos.append(str(fala[chave]))
		for texto: String in textos:
			var curto: String = morador.balao_curto(texto)
			_conferir(curto != "" and curto.length() <= limite,
				"o balão de %s tem %d letras: '%s'" % [dados.get("id", "?"), curto.length(), curto])
			_conferir(texto.strip_edges().begins_with(curto.trim_suffix("…")),
				"o balão de %s não é o começo da fala: '%s'" % [dados.get("id", "?"), curto])
			if curto.length() < texto.strip_edges().length():
				encurtadas += 1
	_conferir(encurtadas > 0, "nenhuma saudação foi encurtada: a regra do balão não está valendo")

	# --- 2. QUEM TEM MISSÃO NÃO CUMPRIMENTA ----------------------------------
	# O bom-dia ao Tonho é o terceiro passo da chegada, depois do desembarque e
	# da primeira corrida: o portão vai direto a ele.
	pedro.saudar()
	_conferir(pedro.ir_ao_passo("bom_dia"), "a chegada não tem o bom-dia ao Tonho")
	var no_bom_dia: int = int(pedro.missao)
	pedro._espera = 0.05
	var anunciou := await _ate(func() -> bool: return int(pedro.missao) == no_bom_dia and float(pedro._espera) <= 0.0,
		SEGUNDOS_PARA_ANUNCIAR)
	_conferir(anunciou, "o bom-dia ao Tonho não chegou a anunciar")
	_conferir(tonho.tem_missao(),
		"o passo da chegada manda falar com o Tonho, e ele se diz sem missão")
	# A palavra livre, para a saudação PODER sair: é ela que o defeito usava.
	var livre := await _palavra_livre(func() -> bool: return tonho.pode_falar() and not tonho.fala_perto_de(tonho.global_position),
		SEGUNDOS_DE_PALAVRA)
	_conferir(livre, "a palavra não ficou livre perto do Tonho")
	var do_tonho: Array[String] = []
	tonho.saudou.connect(func(_quem, texto: String) -> void: do_tonho.append(texto))
	tonho.set("_ultima_saudacao_ms", -1)
	jogador.teleportar(tonho.global_position + Vector3(1.0, 0.0, 0.8), 0.0)
	# Chegar perto não fecha o bom-dia: o E é que cumprimenta.
	await _ate(func() -> bool: return false, 1.0)
	jogo.get("tecla_dos_moradores").usar(tonho)
	var fechou := await _ate(func() -> bool: return int(pedro.missao) > no_bom_dia, SEGUNDOS_PARA_SAUDAR + 4.0)
	_conferir(fechou, "com o E no Tonho o bom-dia não fechou")
	await _ate(func() -> bool: return false, 1.5)
	_conferir(do_tonho.is_empty(),
		"o Tonho tinha missão e cumprimentou mesmo assim: '%s'" % (" | ".join(do_tonho)))

	# --- 3. QUEM NÃO TEM MISSÃO CUMPRIMENTA, COM O BALÃO CURTO --------------
	var sem_missao: Node3D = null
	var fala_longa := ""
	for morador in moradores:
		if morador == tonho or morador.tem_missao():
			continue
		var falas: Array = (morador.dados as Dictionary).get("falas", [])
		if falas.is_empty():
			continue
		var primeira := str((falas[0] as Dictionary).get("texto", ""))
		if primeira.length() > limite:
			sem_missao = morador
			fala_longa = primeira
			break
	_conferir(sem_missao != null, "não achei morador sem missão com fala mais longa que o balão")
	if sem_missao != null:
		var ditas: Array[String] = []
		sem_missao.saudou.connect(func(_quem, texto: String) -> void: ditas.append(texto))
		sem_missao.set("_ultima_saudacao_ms", -1)
		sem_missao.set("_proxima_fala", 0)
		var nome := str(sem_missao.dados.get("id", "?"))
		var palavra := await _palavra_livre(func() -> bool: return sem_missao.pode_falar(), SEGUNDOS_DE_PALAVRA)
		_conferir(palavra, "a palavra não ficou livre perto de %s" % nome)
		# O TELEPORTE TIRA O JOGADOR DO SAVEIRO, e o viajante diria "Então é aqui…" (agora com voz, uns
		# segundos): a fala dele toma a vez, e o cumprimento que encontra a vez ocupada cai e se dá por feito.
		# Aqui só interessa o cumprimento: a chegada do viajante conta como já dita.
		var viajante = jogo.get("viajante")
		if viajante != null:
			viajante._ditas["desceu_do_saveiro"] = true
		jogador.teleportar(sem_missao.global_position + Vector3(1.0, 0.0, 0.8), 0.0)
		var saudou := await _ate(func() -> bool: return not ditas.is_empty(), SEGUNDOS_PARA_SAUDAR)
		_conferir(saudou, "%s não tem missão e não cumprimentou" % nome)
		if saudou:
			_conferir(ditas[0] == fala_longa,
				"o aviso de %s não levou a fala inteira: '%s'" % [nome, ditas[0]])
			var no_balao: String = sem_missao.balao._texto.text
			_conferir(no_balao == sem_missao.balao_curto(fala_longa) and no_balao.length() < fala_longa.length(),
				"o balão de %s não ficou curto: '%s'" % [nome, no_balao])
			print("  %-9s balão '%s' (fala de %d letras)" % [nome, no_balao, fala_longa.length()])

	# --- 4. O PEDRO DE DEPOIS DO TUTORIAL NÃO SE APRESENTA DE NOVO --------------
	var depois: Array = (pedro.dados as Dictionary).get("falas_depois", [])
	_conferir(depois.size() >= 5 and depois.size() <= 8,
		"o Pedro tem %d fala(s) de depois do tutorial, e são de cinco a oito" % depois.size())
	var de_depois: Array[String] = []
	for fala in depois:
		var pt := str((fala as Dictionary).get("texto", ""))
		de_depois.append(pt)
		for chave in ["texto_en", "texto_es"]:
			var traduzida := str((fala as Dictionary).get(chave, ""))
			_conferir(traduzida != "" and traduzida != pt,
				"a fala de depois do tutorial '%s…' não tem '%s' de verdade" % [pt.left(30), chave])
			de_depois.append(traduzida)
	var do_encontro: Array[String] = []
	for fala in (pedro.dados as Dictionary).get("falas", []):
		for chave in ["texto", "texto_en", "texto_es"]:
			if str((fala as Dictionary).get(chave, "")) != "":
				do_encontro.append(str(fala[chave]))
	# ENTRE O ÚLTIMO PASSO E A DESPEDIDA ele também não se apresenta de novo (07/10: o "chegou,
	# homem! O mestre do saveiro jurou que trazia você hoje" tocava sem nexo nessa janela).
	pedro.set("_iniciado", true)
	pedro.missao = pedro.MISSOES.size()
	pedro.set("_despedida_feita", false)
	_conferir(not pedro.terminou_o_tutorial(), "a janela entre o último passo e a despedida não se montou")
	for vez in 3:
		var dita_antes: String = str(pedro._escolher_a_fala().get("texto", ""))
		_conferir(not do_encontro.has(dita_antes) and de_depois.has(dita_antes),
			"antes da despedida o Pedro ainda se apresentava de novo: '%s'" % dita_antes)
	pedro.missao = pedro.MISSOES.size()
	pedro.set("_despedida_feita", true)
	_conferir(pedro.terminou_o_tutorial(), "não consegui dar a chegada do Pedro por acabada")
	var do_pedro: Array[String] = []
	pedro.saudou.connect(func(_quem, texto: String) -> void: do_pedro.append(texto))
	for vez in 4:
		await _palavra_livre(func() -> bool: return pedro.pode_falar(), SEGUNDOS_DE_PALAVRA)
		# A conversa dele: as filas do Pedro abrem no E antes dela, e aqui só ela
		# interessa (`GuiaPedro.conversar`).
		pedro.conversar()
		await _ate(func() -> bool: return do_pedro.size() > vez, 6.0)
	_conferir(do_pedro.size() >= 4, "depois do tutorial, conversar com o Pedro não o fez falar (%d de 4)" % do_pedro.size())
	var diferentes := {}
	for dita in do_pedro:
		diferentes[dita] = true
		_conferir(not do_encontro.has(dita), "depois do tutorial o Pedro se apresentou de novo: '%s'" % dita)
		_conferir(de_depois.has(dita), "depois do tutorial o Pedro disse '%s', que não é das falas de depois dele" % dita)
	_conferir(diferentes.size() >= 2, "depois do tutorial o Pedro repete sempre a mesma fala: '%s'" % (do_pedro[0] if not do_pedro.is_empty() else ""))
	_fechar()


## ESPERA A PALAVRA LIVRE pela fila de falas, lendo depressa: a fala com tempo
## que estiver no ar se passa (`FilaDeFalas.pular`), como o E de quem já leu.
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
		print("SAUDACAO_OK: o balão de toda saudação é curto nos três idiomas e é o começo da fala; com o bom-dia da chegada em curso o Tonho responde a missão e não cumprimenta; quem não tem missão cumprimenta com a fala inteira no aviso e o balão enxuto; e o Pedro de depois do tutorial conversa com as falas de quem já conhece o jogador, nos três idiomas, sem se apresentar de novo")
	else:
		print("saudacao: %d falha(s)" % falhas)
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
