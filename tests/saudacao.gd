extends SceneTree
## A SAUDAÇÃO DE APROXIMAÇÃO: quem tem missão não cumprimenta, e o balão é curto.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/saudacao.gd
##
## "Quando encostar no NPC com missão, o NPC não [deve] falar a fala de
## aproximação. Isso tá deixando o jogador confuso. Os textos das falas de
## aproximação apresentados no balão também estão grandes. Podemos deixar a
## fala dele por extenso, mas enxugar o balão. Isso se aplica somente às falas
## por aproximação." (05/10/2026)
##
## Três perguntas:
##
##   1. O BALÃO DE TODA SAUDAÇÃO É CURTO, nos três idiomas: no máximo
##      `BALAO_CURTO` letras, nunca vazio, e é o começo da fala inteira.
##   2. QUEM TEM MISSÃO NÃO CUMPRIMENTA. Na chegada, o primeiro passo do Pedro
##      manda dar bom-dia ao Tonho: ao lado dele, com a palavra livre, sai a
##      resposta da missão e nenhuma saudação.
##   3. QUEM NÃO TEM MISSÃO CUMPRIMENTA, com a fala inteira no aviso (`saudou`)
##      e o balão enxuto.

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
		for fala in dados.get("falas", []):
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
	var livre := await _ate(func() -> bool: return tonho.pode_falar() and not tonho.fala_perto_de(tonho.global_position),
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
		var palavra := await _ate(func() -> bool: return sem_missao.pode_falar(), SEGUNDOS_DE_PALAVRA)
		_conferir(palavra, "a palavra não ficou livre perto de %s" % nome)
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
	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("SAUDACAO_OK: o balão de toda saudação é curto nos três idiomas e é o começo da fala; com o bom-dia da chegada em curso o Tonho responde a missão e não cumprimenta; e quem não tem missão cumprimenta com a fala inteira no aviso e o balão enxuto")
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
