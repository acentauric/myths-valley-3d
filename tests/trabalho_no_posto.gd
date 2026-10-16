extends "res://tests/suite/caso.gd"
## Confere O TRABALHO NAS TERRAS NO MUNDO (#9): o morador que o jogador pôs para trabalhar numa terra sua
## vai ao posto do ofício dele na hora de trabalho, faz o gesto e, fora dela, volta à rotina que tinha.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste trabalho_no_posto
##     ... -- --falsificar-trabalho     (rodado direto: o portão TEM de reprovar, o morador fica no posto o dia todo)
##
## FALSIFICADO À MÃO em 15/10/2026 (o testar.ps1 não repassa argumento): com `em_horario_de_trabalho` sempre
## verdadeiro, o portão reprova nas 18,5 h, às 21 h e às 3 h, nos três moradores.
##
## Cinco perguntas:
##
##   1. O POSTO EXISTE E SE ALCANÇA: todo ofício que o morador pode fazer tem posto no lote dele, a âncora
##      existe no cenário e a malha de navegação leva até 1,5 u do posto.
##   2. A HORA DE TRABALHO MANDA: de manhã e de tarde o morador está no posto do ofício ("trabalho:<ofício>",
##      a ação é o gesto do ofício); ao entardecer, de noite e de madrugada ele está onde a rotina dele manda.
##   3. SEM OFÍCIO, SEM POSTO: "nada" deixa o morador na rotina de sempre, a qualquer hora.
##   4. O COSME: antes de comprar a terra da Dona Zefa ele só vai ao roçado do jogador (o dia de roçado do
##      segundo tutorial), e a lenha é recusada; comprada a terra, vai à lenha, na casa da Zefa.
##   5. O CORPO TRABALHA: parado no posto, o morador faz o gesto do ofício, quando o modelo dele tem o clipe.

var falhas := 0
var falsificar := false


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("TRABALHO_NO_POSTO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	falsificar = "--falsificar-trabalho" in OS.get_cmdline_user_args()
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	var vale = current_scene
	while vale.apresentacao_do_povoado == null:
		await process_frame
	vale.apresentacao_do_povoado.liberar_todos()
	var mundo = vale.world
	var jogador = vale.player
	var dia = root.get_node("/root/Dia")
	var terras = root.get_node("/root/Terras")
	var terrenos = root.get_node("/root/Terrenos")
	var jogo = root.get_node("/root/Jogo")
	dia.pausado = true
	var por_id := {}
	for morador in vale.moradores:
		por_id[str(morador.dados.get("id", ""))] = morador
	for id in ["cosme", "zefa", "benedito"]:
		_conferir(por_id.has(id), "o morador '%s' não está no vale" % id)
	if not (por_id.has("cosme") and por_id.has("zefa") and por_id.has("benedito")):
		_fechar()
		return
	var navegacao = vale.get("navegacao")
	var pronta: bool = navegacao != null and await _ate(func() -> bool: return navegacao.esta_pronta(), 60.0)
	_conferir(pronta, "a malha de navegação não ficou pronta em 60 s")
	# Jogador longe de todos: o morador é posto no lugar na hora.
	jogador.global_position = mundo.ground_position(Vector3(-60.0, 0.0, 150.0), 1.0)
	var praca: Vector3 = mundo.ground_position(mundo.ancoras["Praça"], 0.0)

	terras.posses = {"rocado": true}
	terrenos.trabalho.clear()
	jogo.dinheiro = 99999

	# --- 4a. O COSME ANTES DA TERRA DA ZEFA --------------------------------------------
	_conferir(not terrenos.mandar_trabalhar("cosme", "lenha"), "o Cosme foi à lenha sem a terra da Zefa")
	_conferir(terrenos.mandar_trabalhar("cosme", "roca"), "o Cosme não foi ao roçado do jogador")
	dia.definir_hora(10.0)
	por_id["cosme"].ir_ao_posto_agora()
	_conferir(por_id["cosme"]._posto == "trabalho:roca", "às 10 h o Cosme devia estar no posto da roça e está em '%s'" % por_id["cosme"]._posto)

	# --- 1 a 3. OS POSTOS, A HORA E O "NADA" -------------------------------------------
	terras.comprar("terreno_zefa")
	terras.comprar("terreno_benedito")
	var postos := 0
	var horas := 0
	for id in ["cosme", "zefa", "benedito"]:
		var m = por_id[id]
		for oficio in terrenos.trabalhos_de(id):
			if str(oficio) == "nada":
				continue
			terrenos.trabalho.clear()
			_conferir(terrenos.mandar_trabalhar(id, str(oficio)), "'%s' não pôde ser posto em '%s'" % [id, oficio])
			var posto: Array = terrenos.posto_de_trabalho(id)
			_conferir(not posto.is_empty() and mundo.ancoras.has(str(posto[0])), "'%s' em '%s': a âncora do posto não existe no cenário" % [id, oficio])
			if posto.is_empty():
				continue
			dia.definir_hora(10.0)
			m.ir_ao_posto_agora()
			_conferir(m._posto == "trabalho:" + str(oficio), "às 10 h '%s' devia estar no posto de '%s' e está em '%s'" % [id, oficio, m._posto])
			_conferir(m._acao == terrenos.acao_do_oficio(str(oficio)), "'%s' em '%s' faz '%s', e devia fazer '%s'" % [id, oficio, m._acao, terrenos.acao_do_oficio(str(oficio))])
			var alvo: Vector3 = m._alvo
			var ponto: Vector3 = m._ponto_da_ancora(str(posto[0]), posto[1])
			_conferir(Vector2(alvo.x - ponto.x, alvo.z - ponto.z).length() < 0.5, "'%s' em '%s' foi para %s, e o posto é %s" % [id, oficio, str(alvo), str(ponto)])
			if pronta:
				var caminho: PackedVector3Array = navegacao.caminho(praca, ponto)
				var chega := caminho.size() > 0 and Vector2(caminho[caminho.size() - 1].x - ponto.x, caminho[caminho.size() - 1].z - ponto.z).length() <= 1.5
				_conferir(chega, "a malha não leva até 1,5 u do posto de '%s' em '%s' (%s)" % [id, oficio, str(ponto)])
			postos += 1
			for hora in [6.5, 10.0, 15.0, 18.5, 21.0, 3.0]:
				dia.definir_hora(hora)
				m.ir_ao_posto_agora()
				var de_trabalho: bool = dia.periodo() in ["manha", "tarde"]
				var no_posto: bool = m._posto.begins_with("trabalho:") or falsificar
				_conferir(no_posto == de_trabalho, "às %.1f h (%s) '%s' %s" % [hora, dia.periodo(), id, "devia estar no posto do ofício" if de_trabalho else "devia ter voltado à rotina"])
				horas += 1
		# Sem ofício, a rotina de sempre.
		terrenos.trabalho.clear()
		terrenos.mandar_trabalhar(id, "nada")
		dia.definir_hora(10.0)
		m.ir_ao_posto_agora()
		_conferir(not m._posto.begins_with("trabalho:"), "'%s' sem ofício foi para um posto de trabalho" % id)
		_conferir(m._posto == m._posto_para("manha"), "'%s' sem ofício não está na rotina das 10 h: '%s'" % [id, m._posto])
	_conferir(not terrenos.mandar_trabalhar("zefa", "lenha"), "a Dona Zefa foi cortar lenha")

	# --- 4b. COMPRADA A TERRA, O COSME VAI À LENHA NA CASA DA ZEFA ---------------------
	terrenos.trabalho.clear()
	terrenos.mandar_trabalhar("cosme", "lenha")
	dia.definir_hora(10.0)
	por_id["cosme"].ir_ao_posto_agora()
	_conferir(str(terrenos.posto_de_trabalho("cosme")[0]) == "Casa da Zefa", "o posto da lenha do Cosme devia ser na casa da Zefa")
	_conferir(por_id["cosme"]._posto == "trabalho:lenha", "o Cosme devia estar na lenha e está em '%s'" % por_id["cosme"]._posto)

	# --- 5. O CORPO TRABALHA -------------------------------------------------------------
	var cosme = por_id["cosme"]
	terrenos.trabalho.clear()
	terrenos.mandar_trabalhar("cosme", "roca")
	dia.definir_hora(10.0)
	cosme.ir_ao_posto_agora()
	jogador.global_position = mundo.ground_position(cosme.global_position + Vector3(6.0, 0.0, 0.0), 0.5)
	await _passos(40)
	var animador = cosme.animador
	_conferir(animador != null and animador.has_method("trabalhando"), "o Cosme não tem animador de trabalho")
	# O Cosme, a Dona Zefa e o Seu Benedito só têm no GLB os clipes de falar e andar (nem cavar nem cortar,
	# e nenhum Mixamo: data/mixamo_uso.json). Com o clipe do gesto, o corpo trabalha; sem ele, fica em pé no
	# posto e a lacuna é a do clipe, anotada no handoff, e não a do posto.
	var clipe := str(cosme.ACOES.get(cosme._acao, ""))
	var tem_clipe: bool = animador != null and animador.has_method("tem_clipe") and bool(animador.tem_clipe(clipe))
	if tem_clipe:
		_conferir(animador.trabalhando(), "o Cosme parado no posto da roça devia estar tocando o clipe '%s'" % clipe)
	else:
		print("trabalho no posto: o Cosme não tem o clipe '%s' (fica em pé no posto)" % clipe)
	_conferir(cosme._acao == "capinar" and cosme._posto == "trabalho:roca", "o Cosme na roça devia capinar no posto")

	terrenos.trabalho.clear()
	print("trabalho no posto: %d postos conferidos, %d conferências de hora" % [postos, horas])
	_fechar()


func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if bool(condicao.call()):
			return true
		await process_frame
	return bool(condicao.call())


func _passos(n: int) -> void:
	for i in n:
		await physics_frame


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame


func _fechar() -> void:
	print("")
	print("TRABALHO_NO_POSTO: %d falhas" % falhas)
	quit(1 if falhas else 0)
