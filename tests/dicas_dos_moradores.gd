extends SceneTree
## OS MORADORES AJUDAM QUEM ESTÁ PERDIDO (#204): um morador que entende do assunto vem até o jogador, dá uma dica
## curta e volta à rotina.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/dicas_dos_moradores.gd
##
## Depois do tutorial o jogo deixava o jogador sozinho: a missão da lenha ficou em 2/36 por centenas de ações e
## ninguém disse nada. Sete perguntas:
##
##   1. OS DADOS: cada situação tem dicas em pt/en/es, com o `quem` existindo no npcs_3d.json e com voz, o áudio
##      `dica_<situacao>_<quem>` e a marcação de voz; toda situação tem a dica do Pedro (é quem vem quando ninguém está
##      perto). Os mp3 existem, ou o `voz_pendente` declara a dívida (e some quando eles chegam).
##   2. CADA SITUAÇÃO ESTÁ LIGADA: o nome aparece no dicas_dos_moradores.gd, e o que o código devolve existe no arquivo.
##   3. O AJUSTE: "Dicas dos moradores" (Ligadas, Poucas, Desligadas) está em Ajustes, com ajuda e tradução, e o modo
##      vai e volta do arquivo de preferências.
##   4. O PASSO DIZ A SITUAÇÃO: lenha, tábua e corda na bancada, pedra, lavoura, obra, ponte e pesca; o passo sem ensino
##      próprio cai na geral.
##   5. OS SINAIS: a mesma recusa repetida (duas vezes, três nas Poucas) pede a dica da ferramenta; o jogador sem
##      avanço pelo tempo do sinal pede a do passo; a conta não corre com o tutorial por acabar nem com a tela parada.
##   6. O MORADOR VEM, FALA E VOLTA: anda até o jogador, espera a palavra livre (não fura quem fala), diz a dica com
##      balão, e solta o morador para a rotina; o mesmo assunto não volta antes do cooldown, e outro assunto também não
##      emenda; Desligadas ninguém vem.
##   7. SEM MORADOR PERTO, VEM O PEDRO: com o do assunto impedido de vir, a dica é a do Pedro.

const PASTA_VOZES := "res://assets/audio/vozes/"
const SEGUNDOS_DE_CHEGADA := 40.0
const SEGUNDOS_DE_PALAVRA := 25.0
## A classe MISSAO da fila de falas (`FilaDeFalas.Classe`).
const MISSAO := 1

var falhas := 0
var DicasDosMoradores
var _modo_de_antes := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("DICAS_DOS_MORADORES_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	# load() dentro do _run e não preload: o script usa os autoloads, que só existem depois do _initialize.
	DicasDosMoradores = load("res://scripts/prototipo_3d/dicas_dos_moradores.gd")
	var arquivo = JSON.parse_string(FileAccess.get_file_as_string("res://data/dicas_dos_moradores.json"))
	var npcs = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs_3d.json"))
	_conferir(arquivo is Dictionary and npcs is Dictionary, "o dicas_dos_moradores.json ou o npcs_3d.json não abre")
	if not (arquivo is Dictionary and npcs is Dictionary):
		_fechar()
		return
	var situacoes: Dictionary = (arquivo as Dictionary).get("situacoes", {})
	var com_voz := {"pedro": true}
	for morador: Dictionary in (npcs as Dictionary).get("moradores", []):
		if morador.has("voz"):
			com_voz[str(morador.get("id", ""))] = true

	# --- 1. OS DADOS ---------------------------------------------------------------------------------
	_conferir(situacoes.size() >= 14, "só %d situação(ões) de dica" % situacoes.size())
	var faltam := 0
	var audios := 0
	for nome: String in situacoes.keys():
		var entrada: Dictionary = situacoes[nome]
		_conferir(str(entrada.get("assunto", "")) != "", "%s: sem assunto (o cooldown é por assunto)" % nome)
		var dicas: Array = entrada.get("dicas", [])
		_conferir(not dicas.is_empty(), "%s: sem dica nenhuma" % nome)
		var tem_pedro := false
		for dica: Dictionary in dicas:
			var quem := str(dica.get("quem", ""))
			tem_pedro = tem_pedro or quem == "pedro"
			_conferir(com_voz.has(quem), "%s: o morador '%s' não existe no npcs_3d.json ou não tem voz" % [nome, quem])
			for chave in ["texto", "texto_en", "texto_es", "tts", "audio"]:
				_conferir(str(dica.get(chave, "")) != "", "%s/%s sem o campo %s" % [nome, quem, chave])
			_conferir(str(dica.get("audio", "")) == "dica_%s_%s" % [nome, quem], "%s/%s: o áudio devia se chamar dica_%s_%s" % [nome, quem, nome, quem])
			_conferir(str(dica.get("tts", "")).contains("["), "%s/%s: o tts sem marcação de interpretação do v3" % [nome, quem])
			_conferir(str(dica.get("texto_en", "")) != str(dica.get("texto", "")), "%s/%s: o inglês é cópia do português" % [nome, quem])
			_conferir(str(dica.get("texto", "")).length() <= 120, "%s/%s: dica comprida demais para um balão curto" % [nome, quem])
			audios += 1
			var caminho := PASTA_VOZES + str(dica.get("audio", "")) + ".mp3"
			if not FileAccess.file_exists(caminho) or not FileAccess.file_exists(caminho + ".import"):
				faltam += 1
		_conferir(tem_pedro, "%s: sem a dica do Pedro, que é quem vem quando ninguém está perto" % nome)
	if str((arquivo as Dictionary).get("voz_pendente", "")) != "":
		_conferir(faltam > 0, "o voz_pendente sobrou: os %d áudios das dicas já existem, tire a marca do arquivo" % audios)
	else:
		_conferir(faltam == 0, "faltam %d áudio(s) das dicas e o arquivo não declara voz_pendente" % faltam)

	# --- 2. CADA SITUAÇÃO ESTÁ LIGADA ----------------------------------------------------------------
	var codigo := FileAccess.get_file_as_string("res://scripts/prototipo_3d/dicas_dos_moradores.gd")
	for nome: String in situacoes.keys():
		_conferir(codigo.contains("\"%s\"" % nome), "a situação '%s' não é devolvida em lugar nenhum do dicas_dos_moradores.gd" % nome)
	for nome in ["ponha_machado", "picareta_na_madeira", "ponha_picareta", "ponha_outra", "sem_machado", "sem_ferramenta",
			"lenha", "bancada", "pedra", "lavoura", "obra", "ponte", "pesca", "cansado", "noite", "lado_errado", "geral"]:
		_conferir(situacoes.has(nome), "o código devolve '%s' e o arquivo não tem essa situação" % nome)

	# --- 3. O AJUSTE -----------------------------------------------------------------------------------
	var painel := FileAccess.get_file_as_string("res://scripts/prototipo_3d/painel_ajustes.gd")
	_conferir(painel.contains("\"Dicas dos moradores\"") and painel.contains("DicasDosMoradores.ROTULOS"), "Ajustes não tem o campo 'Dicas dos moradores'")
	_conferir(DicasDosMoradores.ROTULOS == ["Ligadas", "Poucas", "Desligadas"], "as escolhas do ajuste não são Ligadas, Poucas e Desligadas, nessa ordem")
	var ajuda := FileAccess.get_file_as_string("res://scripts/prototipo_3d/ajuda_menu.gd")
	var idioma := FileAccess.get_file_as_string("res://scripts/prototipo_3d/idioma_menu.gd")
	_conferir(ajuda.contains("\"Dicas dos moradores\": ["), "o ajuste não tem o texto de ajuda")
	for rotulo in ["Dicas dos moradores", "Ligadas", "Poucas", "Desligadas"]:
		_conferir(idioma.count("\"%s\":" % rotulo) >= 2, "'%s' não está traduzido para o inglês e o espanhol" % rotulo)
	_modo_de_antes = DicasDosMoradores.modo()
	DicasDosMoradores.definir_modo(1)
	DicasDosMoradores.esquecer_o_modo()
	_conferir(DicasDosMoradores.modo() == 1, "o modo Poucas não voltou do arquivo de preferências")
	DicasDosMoradores.definir_modo(0)

	# --- 4 a 7. NO VALE ---------------------------------------------------------------------------------
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(3)
	var jogo := current_scene
	var jogador = jogo.get("player")
	var pedro = jogo.get("pedro")
	var d = jogo.get("dicas_dos_moradores")
	var fila = jogo.get("fila_de_falas")
	_conferir(jogador != null and pedro != null and d != null and fila != null, "não achei o jogador, o Pedro, as dicas ou a fila de falas no vale")
	if jogador == null or pedro == null or d == null or fila == null:
		DicasDosMoradores.definir_modo(_modo_de_antes)
		_fechar()
		return

	# 4. O passo diz a situação.
	var esperado := {
		"res://data/missoes_ponte.json": {"ponte_lenha": "lenha", "tabuas": "bancada", "ponte": "ponte", "ponte_contar": "geral"},
		"res://data/missoes_guia.json": {"pedra_do_poco": "pedra", "roca": "lavoura", "mutirao_poco": "obra", "lenha": "lenha"},
		"res://data/missoes_oficio.json": {"pesca": "pesca"},
	}
	for caminho: String in esperado.keys():
		var missao = JSON.parse_string(FileAccess.get_file_as_string(caminho))
		for passo: Dictionary in (missao as Dictionary).get("passos", []):
			var id := str(passo.get("id", ""))
			if esperado[caminho].has(id):
				_conferir(d.situacao_do_passo(passo) == esperado[caminho][id],
					"o passo %s devia pedir a dica '%s', e pediu '%s'" % [id, esperado[caminho][id], d.situacao_do_passo(passo)])

	# 5. Os sinais. A mesma recusa duas vezes pede a dica da ferramenta; três nas Poucas.
	d._recusas.clear()
	d.anotar_recusa("ponha_machado")
	_conferir(d._situacao_das_recusas() == "", "uma recusa só não devia pedir dica")
	d.anotar_recusa("sem_ferramenta")
	_conferir(d._situacao_das_recusas() == "", "duas recusas de ferramentas diferentes não são a mesma recusa")
	d.anotar_recusa("ponha_machado")
	_conferir(d._situacao_das_recusas() == "ponha_machado", "a mesma recusa duas vezes devia pedir a dica de pôr o machado na mão")
	d._recusas.clear()
	DicasDosMoradores.definir_modo(1)
	d.anotar_recusa("ponha_machado")
	d.anotar_recusa("ponha_machado")
	_conferir(d._situacao_das_recusas() == "", "nas Poucas duas recusas ainda não pedem dica")
	d.anotar_recusa("ponha_machado")
	_conferir(d._situacao_das_recusas() == "ponha_machado", "nas Poucas a terceira recusa devia pedir a dica")
	_conferir(float(d.medidas()["limite_sem_avanco_s"]) > DicasDosMoradores.SEM_AVANCO_S[0], "nas Poucas o tempo sem avanço devia ser maior")
	d._recusas.clear()
	DicasDosMoradores.definir_modo(0)
	# O tempo sem avanço: a missão 2/36 da lenha (a da ponte) parada pede a dica do passo.
	var passo_da_lenha := {}
	for passo: Dictionary in (JSON.parse_string(FileAccess.get_file_as_string("res://data/missoes_ponte.json")) as Dictionary).get("passos", []):
		if str(passo.get("id", "")) == "ponte_lenha":
			passo_da_lenha = passo
	d._passo_acompanhado = func() -> Dictionary: return passo_da_lenha
	d._sem_avanco_s = 1.0
	_conferir(d._situacao_do_momento() == "", "um segundo sem avanço não é estar perdido")
	d._sem_avanco_s = float(DicasDosMoradores.SEM_AVANCO_S[0]) + 1.0
	var situacao_do_estado: String = d.situacao_de_estado()
	var esperada: String = situacao_do_estado if situacao_do_estado != "" else "lenha"
	_conferir(d._situacao_do_momento() == esperada, "parado no 2/36 da lenha devia pedir '%s', e pediu '%s'" % [esperada, d._situacao_do_momento()])
	# A dica de estado em cooldown não esconde a do passo: cansado ou à noite, a lenha ainda recebe ajuda.
	if situacao_do_estado != "":
		var entrada_do_estado: Dictionary = (d._dados.get("situacoes", {}) as Dictionary).get(situacao_do_estado, {})
		var assunto_do_estado := str(entrada_do_estado.get("assunto", situacao_do_estado))
		var guardado_do_assunto = d._assunto_em.get(assunto_do_estado)
		d._assunto_em[assunto_do_estado] = Time.get_ticks_msec()
		_conferir(d._situacao_do_momento() == "lenha", "com a dica de estado em cooldown, o 2/36 da lenha devia cair para '%s'" % "lenha")
		if guardado_do_assunto == null:
			d._assunto_em.erase(assunto_do_estado)
		else:
			d._assunto_em[assunto_do_estado] = guardado_do_assunto
	# O lado errado: afastando-se seis amostras seguidas, já longe do alvo.
	d._sem_avanco_s = 0.0
	d._fora_de_rumo = true
	_conferir(d._situacao_do_momento() == "lado_errado", "o jogador indo para o lado oposto devia pedir a dica do rumo")
	d._fora_de_rumo = false
	# O tutorial por acabar segura a conta: a medida não corre.
	d._sem_avanco_s = 0.0
	_conferir(not d._jogo_livre(), "com o tutorial por acabar o jogo devia contar como não livre")

	# Acaba o tutorial do Pedro, como o portão das falas dele faz.
	pedro.missao = pedro.MISSOES.size()
	pedro.set("_despedida_feita", true)
	_conferir(pedro.terminou_o_tutorial(), "não consegui dar a chegada do Pedro por acabada")
	await _frames(2)
	d._espera_s = 0.0
	d._ultima_dica_ms = -1000000
	d._assunto_em.clear()

	# 6. O morador vem, fala e volta. Quem vem: o carpinteiro se pode e está perto, senão o Pedro.
	var escolha: Dictionary = d.escolher("ponha_machado")
	_conferir(not escolha.is_empty(), "ninguém pode vir ajudar com a madeira (nem o Pedro)")
	if escolha.is_empty():
		DicasDosMoradores.definir_modo(_modo_de_antes)
		_fechar()
		return
	var morador: Node3D = escolha["morador"]
	var quem := str((escolha["dica"] as Dictionary).get("quem", ""))
	_conferir(quem in ["carpinteiro", "pedro"], "a dica da madeira veio de '%s', que não entende do assunto" % quem)
	# Põe o morador perto, para o portão não depender de um passeio pelo vale.
	morador.global_position = jogador.global_position + Vector3(7.0, 0.0, 0.0)
	await _palavra_livre(fila, SEGUNDOS_DE_PALAVRA)
	# A fila ocupada por outra fala: ele chega e ESPERA, não fura.
	fila.pedir({"falante": jogo, "texto": "Outra fala qualquer, comprida o bastante.", "classe": MISSAO, "segundos": 12.0})
	_conferir(d.pedir_ajuda("ponha_machado"), "pedir ajuda com a vez da fila ocupada devia ao menos pôr o morador a caminho")
	_conferir(d.ajudando(), "o morador não saiu andando")
	_conferir(morador._destino_avulso.is_finite(), "o morador não recebeu o destino até o jogador")
	var chegou := await _ate(func() -> bool:
		return Vector2(morador.global_position.x - jogador.global_position.x, morador.global_position.z - jogador.global_position.z).length() <= d.CHEGOU_A,
		SEGUNDOS_DE_CHEGADA)
	_conferir(chegou, "o morador não chegou perto do jogador em %d s" % int(SEGUNDOS_DE_CHEGADA))
	await _ate(func() -> bool: return false, 1.5)
	_conferir(d.dicas_dadas == 0, "o morador falou por cima da fala que estava no ar")
	fila.calar_falante(jogo)
	await _palavra_livre(fila, SEGUNDOS_DE_PALAVRA)
	var falou := await _ate(func() -> bool: return d.dicas_dadas == 1, SEGUNDOS_DE_PALAVRA)
	_conferir(falou, "o morador não deu a dica com a palavra livre")
	_conferir(d.ultima_situacao == "ponha_machado", "a dica dada foi a de '%s'" % d.ultima_situacao)
	var com_balao := await _ate(func() -> bool: return morador.balao != null and morador.balao.visible, 4.0)
	_conferir(com_balao or not d.ajudando(), "a dica não abriu o balão do morador")
	var terminou := await _ate(func() -> bool: return not d.ajudando(), 30.0)
	_conferir(terminou, "a dica não terminou")
	_conferir(not morador._destino_avulso.is_finite(), "o morador não voltou à rotina depois da dica")
	# O cooldown: o mesmo assunto não volta, e outro assunto também não emenda.
	_conferir(not d.pedir_ajuda("lenha"), "o mesmo assunto (madeira) voltou antes do cooldown")
	_conferir(not d.pedir_ajuda("pedra"), "duas dicas emendaram, sem a pausa entre elas")

	# 7. Sem o do assunto, vem o Pedro: a dica da pedra, com o carpinteiro impedido.
	d._ultima_dica_ms = -1000000
	d._assunto_em.clear()
	var carpinteiro: Node3D = null
	for m in jogo.get("moradores") as Array:
		if str((m.dados as Dictionary).get("id", "")) == "carpinteiro":
			carpinteiro = m
	if carpinteiro != null and pedro.pode_vir_ajudar():
		var estava = carpinteiro.get("_recolhido")
		carpinteiro.set("_recolhido", true)
		var sem_ele: Dictionary = d.escolher("pedra")
		_conferir(not sem_ele.is_empty() and str((sem_ele["dica"] as Dictionary).get("quem", "")) == "pedro",
			"sem o carpinteiro por perto a dica da pedra devia ser a do Pedro")
		carpinteiro.set("_recolhido", estava)

	# Desligadas: ninguém vem, e quem estava vindo volta.
	DicasDosMoradores.definir_modo(2)
	d._sem_avanco_s = 1000.0
	await _frames(40)
	_conferir(not d.ajudando(), "com as dicas Desligadas alguém veio ajudar")
	DicasDosMoradores.definir_modo(_modo_de_antes)
	_fechar()


func _palavra_livre(fila: Node, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if fila.livre():
			return true
		fila.pular()
		await process_frame
	return fila.livre()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("DICAS_DOS_MORADORES_OK: as dicas têm pt, en e es, o morador e o áudio nomeados, cada situação está ligada no código, o ajuste Ligadas, Poucas e Desligadas existe, o passo diz a situação, a recusa repetida e o tempo sem avanço pedem a dica, o morador vem, espera a palavra livre, fala com balão e volta à rotina, o cooldown vale, e sem o do assunto vem o Pedro")
	else:
		print("dicas_dos_moradores: %d falha(s)" % falhas)
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
