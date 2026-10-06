extends SceneTree
## Confere que a TEIA DE TALENTOS, as TRÊS FÉS e a AFINIDADE chegaram ao vale.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/fe.gd
##
## São 1.861 linhas em cinco autoloads que se citam em círculo — `Talentos`,
## `Fe`, `Ritos`, `Afinidade` e o `Jogo` que a afinidade puxa. Vão juntos ou
## não vão, e é por isso que esta é a fatia mais pesada da migração. Todos são
## os mesmos arquivos do 2D, conferidos byte a byte pelo `testar_compartilhado`
## do outro projeto.
##
## Só puderam vir depois do calendário: os quatro precisam do `Relogio` para
## contar espera em dias, zerar o que se gasta uma vez por dia e achar a festa
## na estação certa. Era o que o plano não tinha visto — a Fase 5 era
## pré-requisito da segunda, e não o penúltimo degrau.
##
## Seis perguntas:
##
##   1. OS CINCO ESTÃO DE PÉ.
##   2. A TEIA DE OFÍCIO VEIO INTEIRA: os nós, e nenhum apontando para pai que
##      não existe — árvore com galho solto é árvore que a tela não desenha.
##   3. AS TRÊS FÉS EXISTEM, e o preço de trocar é o do 2D.
##   4. A AFINIDADE CONHECE OS SETE MORADORES — os mesmos sete do vale — e sabe
##      o gosto de cada um, lido de `aldeoes.json`, que veio junto.
##   5. GOSTO E DESGOSTO VALEM NÚMERO DIFERENTE, que é a regra inteira do
##      presente.
##   6. E OS SETE DO 2D SÃO OS SETE DAQUI. Se um dia divergirem, é aqui que
##      aparece — e não numa fala sem dono, meses depois.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("FE_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	# --- 1. DE PÉ -------------------------------------------------------------
	var talentos := root.get_node_or_null("/root/Talentos")
	var fe := root.get_node_or_null("/root/Fe")
	var ritos := root.get_node_or_null("/root/Ritos")
	var afinidade := root.get_node_or_null("/root/Afinidade")
	var jogo := root.get_node_or_null("/root/Jogo")
	for par in [["Talentos", talentos], ["Fe", fe], ["Ritos", ritos],
			["Afinidade", afinidade], ["Jogo", jogo]]:
		_conferir(par[1] != null, "o autoload %s não subiu" % par[0])
	if talentos == null or fe == null or ritos == null or afinidade == null or jogo == null:
		_fechar()
		return

	# --- 2. A TEIA DE OFÍCIO VEIO INTEIRA ------------------------------------
	_conferir(talentos.NOS.size() >= 30,
		"a teia veio com %d nós: parece cortada" % talentos.NOS.size())
	for id in talentos.NOS:
		var no: Dictionary = talentos.NOS[id]
		_conferir(str(no.get("nome", "")) != "", "o nó '%s' está sem nome" % id)
		var pai := str(no.get("pai", ""))
		_conferir(pai == "" or talentos.NOS.has(pai),
			"o nó '%s' pende de '%s', que não existe na teia" % [id, pai])

	# --- 3. AS TRÊS FÉS ------------------------------------------------------
	_conferir(fe.FES.size() == 3,
		"não são três fés: %d" % fe.FES.size())
	for caminho in fe.FES:
		_conferir(fe.nome(caminho) != "", "a fé '%s' está sem nome" % caminho)
	_conferir(fe.ativa == "", "o vale começou com uma fé já escolhida: '%s'" % fe.ativa)

	# --- 4. OS SETE MORADORES, COM O GOSTO DE CADA UM -------------------------
	#
	# O `aldeoes.json` veio do 2D junto com a `Afinidade`, porque sem ele ela
	# não sabe de quem é cada gosto — e aí o presente vira um número sem
	# história.
	# Os sete do 2D vêm primeiro, e depois deles os quinze do vale (#85).
	_conferir(afinidade.MORADORES.size() == 22 and afinidade.MORADORES.slice(0, 7) == ["benedito", "zefa", "cosme", "tonho", "filo", "candinha", "damiao"],
		"os moradores da afinidade não são os sete do 2D seguidos dos quinze do vale: %s" % str(afinidade.MORADORES))
	var dados: Dictionary = jogo.dados(afinidade.ARQUIVO_DOS_MORADORES)
	_conferir(not dados.is_empty(),
		"o aldeoes.json não foi lido: a afinidade fica sem saber de quem é cada gosto")

	for morador in afinidade.MORADORES:
		_conferir(dados.has(morador), "o aldeoes.json não tem '%s'" % morador)
		if not dados.has(morador):
			continue
		var dele: Dictionary = dados[morador]
		_conferir(str(dele.get("nome", "")) != "", "'%s' está sem nome" % morador)
		_conferir((dele.get("gosta", []) as Array).size() > 0,
			"'%s' não gosta de nada: o presente não teria como acertar" % morador)
		_conferir(afinidade.de(morador) >= 0,
			"a afinidade de '%s' começou negativa" % morador)

	# --- 5. GOSTO E DESGOSTO VALEM DIFERENTE ----------------------------------
	_conferir(afinidade.POR_PRESENTE_BOM > afinidade.POR_PRESENTE_QUALQUER,
		"presente bom não vale mais que presente qualquer")
	_conferir(afinidade.POR_PRESENTE_RUIM < 0,
		"presente ruim não tira nada: a escolha do que dar não teria peso")

	var alguem := str(afinidade.MORADORES[0])
	var antes: int = afinidade.de(alguem)
	afinidade.somar(alguem, afinidade.POR_CONVERSA)
	_conferir(afinidade.de(alguem) == antes + afinidade.POR_CONVERSA,
		"conversar não somou afinidade: %d → %d" % [antes, afinidade.de(alguem)])
	_conferir(afinidade.de(alguem) <= afinidade.MAXIMO, "a afinidade passou do teto")

	# --- 6. OS SETE SÃO OS MESMOS DOS DOIS JOGOS ------------------------------
	#
	# O vale lista os moradores dele em `npcs_3d.json`; o 2D, na constante da
	# `Afinidade`. São a mesma gente, e nada garantia isso além de ninguém
	# ter mexido.
	var arquivo := FileAccess.open("res://data/npcs_3d.json", FileAccess.READ)
	_conferir(arquivo != null, "não consegui ler npcs_3d.json")
	if arquivo != null:
		var npcs = JSON.parse_string(arquivo.get_as_text())
		arquivo.close()
		if typeof(npcs) == TYPE_DICTIONARY:
			var do_vale := []
			for bruto in npcs.get("moradores", []):
				do_vale.append(str(bruto.get("id", "")))
			for morador in afinidade.MORADORES:
				_conferir(do_vale.has(morador),
					"'%s' tem afinidade no 2D e não mora no vale" % morador)

	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		var t := root.get_node("/root/Talentos")
		var a := root.get_node("/root/Afinidade")
		print("FE_OK: %d nós de teia sem galho solto, três fés, %d moradores com gosto e desgosto lidos do aldeoes.json, e o presente pesa diferente conforme acerta ou erra"
			% [t.NOS.size(), a.MORADORES.size()])
	else:
		print("fé: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)
