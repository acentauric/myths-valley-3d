extends SceneTree
## Confere que o SISTEMA DE MISSÕES do jogo 2D roda no vale, apontando para
## lugares daqui.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/missoes.gd
##
## É a chave de abóbada da migração. `Missoes` dependia de `Inventario` e de
## `Fe`, e as duas atravessaram nas fatias anteriores; o que sobrava era a
## tecla Tab, que saiu para o `Controles` do 2D como a tecla da mão saíra
## antes. São 611 linhas que agora rodam nos dois jogos.
##
## O que ele traz que o vale não tinha: várias frentes abertas ao mesmo tempo,
## checklist com item e quantidade, separação entre ENREDO e DIA A DIA, foco
## que não troca sozinho, e bússola para vários alvos.
##
## Seis perguntas:
##
##   1. OS DOIS ESTÃO DE PÉ — `Missoes` e a `Jornada`, que conta o estado dos
##      capítulos 6 e 7.
##   2. ABRIR, APONTAR E FECHAR funciona, e o alvo vira posição DO VALE.
##   3. APONTAR POR NOME É O CAMINHO, e é a costura inteira de ponta a ponta:
##      "praca" tem de virar um `Vector3` daqui, não um `Vector2` de lá.
##   4. NOME QUE O VALE NÃO TEM não estoura: os treze declarados em
##      `FALTAM_NO_VALE` são a metade da campanha do 2D, e a missão tem de
##      abrir mesmo sem bússola até a Fase 2.5 chegar.
##   5. A CHECKLIST CONTA ITEM da mochila compartilhada.
##   6. O FOCO GIRA PELA REGRA, e não pela tecla — que ficou no 2D.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("MISSOES_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK,
		"a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()

	# --- 1. DE PÉ -------------------------------------------------------------
	var missoes := root.get_node_or_null("/root/Missoes")
	var jornada := root.get_node_or_null("/root/Jornada")
	var lugares := root.get_node_or_null("/root/Lugares")
	var inv := root.get_node_or_null("/root/Inventario")
	_conferir(missoes != null, "o autoload Missoes não subiu")
	_conferir(jornada != null, "o autoload Jornada não subiu")
	if missoes == null or jornada == null or lugares == null or inv == null:
		_fechar()
		return

	_conferir(missoes.ativas.is_empty(), "o vale começou com missão aberta")

	# --- 2 e 3. ABRIR, APONTAR POR NOME, FECHAR -------------------------------
	missoes.adicionar("teste_praca", "Ir até a praça", false, [], "", false, "teste")
	_conferir(missoes.tem("teste_praca"), "a missão não abriu")
	_conferir(missoes.ativas.size() == 1, "abriu %d missões" % missoes.ativas.size())

	missoes.apontar("teste_praca", "praca")
	var i: int = missoes.indice("teste_praca")
	var alvo = missoes.ativas[i].get("alvo", null)
	_conferir(alvo is Vector3,
		"apontar por nome deu %s: no vale o alvo tem de ser Vector3" % str(alvo))
	if alvo is Vector3:
		_conferir(alvo == lugares.ponto("praca"),
			"o alvo (%s) não é a praça do vale (%s)" % [str(alvo), str(lugares.ponto("praca"))])

	# VÁRIOS DE UMA VEZ, que é a missão dos três marcos de fé no 2D.
	missoes.apontar_varios("teste_praca", ["praca", "pier", "igreja"])
	_conferir((missoes.ativas[i].get("alvos", []) as Array).size() == 3,
		"apontar três nomes deixou %d alvo(s)" % (missoes.ativas[i].get("alvos", []) as Array).size())

	missoes.concluir("teste_praca")
	_conferir(not missoes.tem("teste_praca"), "a missão não fechou")
	_conferir(missoes.cumpridas.has("teste_praca"), "a missão fechou e não entrou nas cumpridas")

	# --- 4. NOME QUE O VALE AINDA NÃO TEM -------------------------------------
	#
	# Metade da campanha do 2D aponta para o vau, a chapada, a lagoa e a
	# fazenda, que só chegam na Fase 2.5. Até lá a missão abre sem bússola — e
	# ABRIR É O QUE IMPORTA: missão que não abre trava a campanha; missão sem
	# seta só obriga a procurar.
	missoes.adicionar("teste_vau", "Ver a ponte caída", false, [], "", true, "teste")
	missoes.apontar("teste_vau", "vau")
	var j: int = missoes.indice("teste_vau")
	_conferir(j >= 0, "a missão que aponta para lugar ausente não abriu")
	if j >= 0:
		var sem_alvo = missoes.ativas[j].get("alvo", null)
		_conferir(sem_alvo == null or sem_alvo == lugares.NENHUM,
			"o vau não existe no vale e mesmo assim virou alvo: %s" % str(sem_alvo))

	# --- 5. A CHECKLIST CONTA ITEM --------------------------------------------
	inv.adicionar("tabua", 3)
	missoes.adicionar("teste_ponte", "Levantar a ponte", false,
		[{"id": "tabuas", "texto": "Tábuas", "item": "tabua", "alvo": 5}], "", true, "teste")
	var k: int = missoes.indice("teste_ponte")
	_conferir(k >= 0, "a missão com checklist não abriu")
	if k >= 0:
		var andamento = missoes.andamento("teste_ponte")
		_conferir(andamento != null, "a missão com checklist não tem andamento")
		# A CONTA VÊ A MOCHILA COMPARTILHADA. Três tábuas guardadas de cinco
		# pedidas, e a checklist tem de saber disso sem ninguém avisar — é o
		# `Inventario` do 2D falando com o `Missoes` do 2D, dentro do vale.
		var itens: Array = missoes.ativas[k].get("lista", [])
		_conferir(itens.size() == 1, "a checklist ficou com %d item(ns)" % itens.size())
		if itens.size() == 1:
			var texto := str(missoes.texto_do_item(itens[0]))
			_conferir(texto.contains("3") and texto.contains("5"),
				"a checklist não viu as três tábuas de cinco: '%s'" % texto)

	# --- 6. O FOCO GIRA PELA REGRA --------------------------------------------
	#
	# A tecla Tab ficou no `Controles` do 2D; aqui se chama o método, que é o
	# que atravessou. Com duas frentes abertas, girar tem de trocar.
	_conferir(missoes.ativas.size() >= 2,
		"preciso de duas frentes abertas para medir o foco, e há %d" % missoes.ativas.size())
	if missoes.ativas.size() >= 2:
		var foco_antes: int = missoes.em_foco
		missoes.girar_o_foco()
		_conferir(missoes.em_foco != foco_antes,
			"girar o foco não trocou: continuou em %d" % missoes.em_foco)

	# Limpa o que este teste abriu, para não deixar missão de conferência viva.
	missoes.concluir("teste_vau")
	missoes.concluir("teste_ponte")

	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("MISSOES_OK: a missão abre, aponta por NOME para um lugar do vale, aceita vários alvos, sobrevive a lugar que ainda não existe, conta item da mochila e gira o foco pela regra")
	else:
		print("missões: %d falha(s)" % falhas)
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
