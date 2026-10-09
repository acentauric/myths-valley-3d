extends SceneTree
## O HISTÓRICO: LINHAS LONGAS, A ENTRADA DE 08/10 E UM GRUPO POR DIA (#212).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/historico_em_linhas_longas.gd
##
## O Histórico do menu ("O que mudou no vale a cada versão") tinha linhas de uma frase curta (~260 px num modal de
## 584 px úteis, mais da metade vazia à direita), as páginas chegavam a 26 para 17 dias, e três dias (03/10, 26/09 e
## 25/09) apareciam em duas entradas. Seis perguntas, só sobre o arquivo e a conta de páginas:
##
##   1. O MAIS RECENTE é 08/10/2026, com título e estado nos três idiomas.
##   2. UM GRUPO POR DIA: nenhuma data repete.
##   3. OS TRÊS IDIOMAS TÊM AS MESMAS LINHAS: a mesma quantidade em pt, en e es, nenhuma vazia.
##   4. O DOURADO SÓ NO TERMO CENTRAL: no máximo um destaque por linha.
##   5. CADA LINHA CABE EM UMA SÓ, na largura útil do modal, na fonte e no tamanho do menu, nos três idiomas (medido
##      com a fonte de verdade); e a linha média usa mais da metade da largura (era 45% do modal antigo).
##   6. UMA PÁGINA POR DIA sempre que as linhas cabem nela: a paginação do menu dá uma página para cada dia de até
##      `HISTORY_ROWS` linhas, o total cai bem abaixo das 26 de antes, e um dia maior que a página não perde linha.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("HISTORICO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	# load() dentro do _run e não preload: a abertura cita autoloads, que só existem depois do _initialize.
	var Abertura: GDScript = load("res://scripts/prototipo_3d/abertura.gd")
	var Identidade: GDScript = load("res://scripts/prototipo_3d/identidade.gd")
	var arquivo = JSON.parse_string(FileAccess.get_file_as_string("res://data/historico_3d.json"))
	_conferir(arquivo is Dictionary, "o historico_3d.json não abre")
	if not (arquivo is Dictionary):
		_fechar()
		return
	var entradas: Array = (arquivo as Dictionary).get("entradas", [])
	_conferir(entradas.size() >= 10, "o histórico tem só %d dias" % entradas.size())

	# --- 1. O MAIS RECENTE ---------------------------------------------------------------------------
	var primeira: Dictionary = entradas[0]
	_conferir(str(primeira.get("data", "")) == "08/10/2026", "a entrada mais recente devia ser a de 08/10/2026 (é '%s')" % str(primeira.get("data", "")))
	for chave in ["titulo", "titulo_en", "titulo_es", "estado", "estado_en", "estado_es"]:
		_conferir(str(primeira.get(chave, "")) != "", "a entrada de 08/10 está sem %s" % chave)

	# --- 2 a 4. UM GRUPO POR DIA, OS TRÊS IDIOMAS, O DOURADO ------------------------------------------
	var datas := {}
	var linhas_no_total := 0
	for i in entradas.size():
		var e: Dictionary = entradas[i]
		var data := str(e.get("data", ""))
		_conferir(not datas.has(data), "o dia %s aparece em mais de uma entrada" % data)
		datas[data] = true
		for chave in ["titulo", "titulo_en", "titulo_es", "estado", "estado_en", "estado_es"]:
			_conferir(str(e.get(chave, "")) != "", "%s: falta %s" % [data, chave])
		var pt: Array = e.get("mudancas", [])
		var en: Array = e.get("mudancas_en", [])
		var es: Array = e.get("mudancas_es", [])
		_conferir(pt.size() > 0 and pt.size() == en.size() and pt.size() == es.size(), "%s: pt, en e es têm %d, %d e %d linhas" % [data, pt.size(), en.size(), es.size()])
		linhas_no_total += pt.size()
		for lingua in [pt, en, es]:
			for linha in lingua:
				var texto := str(linha)
				_conferir(texto.strip_edges() != "", "%s: linha vazia" % data)
				var asteriscos := texto.count("*")
				_conferir(asteriscos == 0 or asteriscos == 2, "%s: mais de um destaque dourado (ou asterisco solto) em '%s'" % [data, texto])

	# --- 5. CADA LINHA CABE EM UMA SÓ, E USA A LARGURA -----------------------------------------------------
	var fonte: Font = Identidade.fonte(Identidade.FONTE_TEXTO, 600)
	var util: float = Abertura.HISTORICO_SIZE.x - 56.0
	var tamanho: int = Abertura.HISTORY_FONTE
	var soma := 0.0
	var quantas := 0
	for e: Dictionary in entradas:
		for chave in ["mudancas", "mudancas_en", "mudancas_es"]:
			for linha in e.get(chave, []):
				var largura := fonte.get_string_size("• " + str(linha).replace("*", ""), HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x
				soma += largura
				quantas += 1
				_conferir(largura <= util, "%s: a linha passa da largura útil do modal (%.0f de %.0f px): '%s'" % [str(e.get("data", "")), largura, util, str(linha)])
	_conferir(quantas > 0 and soma / quantas >= util * 0.5, "a linha média usa só %.0f%% da largura útil do modal" % (100.0 * soma / maxf(quantas, 1) / util))

	# --- 6. UMA PÁGINA POR DIA ------------------------------------------------------------------------------
	var paginas: Array = Abertura._paginar_historico(entradas)
	var esperadas := 0
	for e: Dictionary in entradas:
		var linhas: int = (e.get("mudancas", []) as Array).size()
		var por_dia := int(ceil(float(linhas) / float(Abertura.HISTORY_ROWS)))
		esperadas += por_dia
		if linhas <= Abertura.HISTORY_ROWS:
			var do_dia := 0
			for pagina: Dictionary in paginas:
				if str(pagina.get("data", "")) == str(e.get("data", "")):
					do_dia += 1
			_conferir(do_dia == 1, "%s: cabe numa página (%d linhas) e ocupa %d" % [str(e.get("data", "")), linhas, do_dia])
	_conferir(paginas.size() == esperadas, "a paginação dá %d páginas e a conta é %d" % [paginas.size(), esperadas])
	_conferir(paginas.size() <= entradas.size() + 3, "as páginas (%d) passam muito dos dias (%d)" % [paginas.size(), entradas.size()])
	_conferir(paginas.size() < 26, "o histórico ainda tem %d páginas (eram 26)" % paginas.size())
	var linhas_nas_paginas := 0
	for pagina: Dictionary in paginas:
		linhas_nas_paginas += (pagina.get("mudancas", []) as Array).size()
	_conferir(linhas_nas_paginas == linhas_no_total, "a paginação perdeu linhas (%d de %d)" % [linhas_nas_paginas, linhas_no_total])
	# Um dia maior que a página não perde linha (falsificação da conta): 30 linhas viram três páginas inteiras.
	var itens := range(Abertura.HISTORY_ROWS * 2 + 2)
	var extras: Array = Abertura._paginar_historico([{"data": "x", "mudancas": itens, "mudancas_en": itens, "mudancas_es": itens}])
	_conferir(extras.size() == 3 and (extras[2].mudancas as Array).size() == 2, "um dia maior que a página perdeu linhas na paginação")
	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("HISTORICO_OK: 08/10 é a entrada mais recente, cada dia aparece uma vez, pt/en/es têm as mesmas linhas com um destaque dourado no máximo, cada linha cabe inteira na largura do modal e a média passa da metade dela, e a paginação dá uma página por dia (e não perde linha quando um dia passa da página)")
	else:
		print("historico_em_linhas_longas: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)
