extends SceneTree
## O E REPETIDO NUM ALVO DE TRABALHO COBRA SÓ O GOLPE QUE ACONTECE (#112).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/golpe_repetido.gd
##
## "Eu aperto E várias vezes e consome a stamina várias vezes. Mas só acontece
## uma animação e o item não vai parar no inventário até que a animação termine"
## (autor, 06/10). A reserva era cobrada no aperto do E e o golpe acontecia no
## impacto do clipe — e quando o clipe não ia até o fim (o corpo ainda andando o
## corta), o impacto não vinha, o alvo só sofria o golpe por um temporizador de
## 1,5 s, a trava caía a 1,25 s e o E seguinte reiniciava o clipe no meio:
## cobranças sem golpe à vista. Agora a cobrança sai NO IMPACTO
## (`recursos_3d._ao_impacto_do_golpe`), a trava dura o clipe inteiro, e um
## clipe que morre solta a trava sem cobrar nem bater.
##
##   1. NO LAJEDO, com a picareta, o E a cada 0,15 s por 4 s: cada queda da
##      reserva acontece no mesmo quadro de um golpe no alvo, não há golpe sem
##      impacto da animação, e a conta fecha (golpes × custo = o que caiu).
##   2. O E durante o golpe não cobra: nem mais quedas que impactos, nem mais
##      que golpes.
##   3. NA ÁRVORE, com o machado, o E repetido não interrompe o corte: os
##      golpes avançam, e cada um custa o seu (bater × dureza da madeira).

## O E cai a cada tanto (ms), e por quanto tempo (ms) em cada prova.
const ENTRE_ES := 150
const DURACAO_DA_PROVA := 4000
## Na árvore, menos que três golpes (1,8 s cada): o terceiro a derrubaria, e a
## conta do que caiu é por golpe que a árvore sentiu.
const DURACAO_NA_ARVORE := 4000
## Cobrança e golpe no mesmo instante: até isto (ms) um do outro.
const MESMO_INSTANTE := 40

var falhas := 0
var _impactos := 0
var _tecla_e := 0
var _solta := false


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("GOLPE_REPETIDO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	var vale = current_scene
	var jogador = vale.player
	var mundo = vale.world
	var recursos = current_scene.get_node_or_null("Recursos3D")
	var Inv = root.get_node("/root/Inventario")
	var Energia = root.get_node("/root/Energia")
	var Atalhos = load("res://scripts/prototipo_3d/atalhos.gd")
	_tecla_e = Atalhos.tecla("interagir")
	root.get_node("/root/Dia").pausado = true
	_conferir(recursos != null, "o vale não tem os alvos de trabalho")
	if recursos == null:
		_fechar()
		return
	var animador = jogador.get("animator")
	_conferir(animador != null and animador.has_signal("golpe_impacto"), "o animador do jogador não avisa o impacto do golpe")
	if animador != null and animador.has_signal("golpe_impacto"):
		animador.connect("golpe_impacto", func() -> void: _impactos += 1)

	# --- 1 e 2. O LAJEDO, com a picareta ------------------------------------------
	var id := "pedra_rocado"
	_conferir(recursos._alvos.has(id), "o lajedo %s não está no vale" % id)
	if recursos._alvos.has(id):
		_por_na_mao(Inv, "picareta")
		var alvo: Dictionary = recursos._alvos[id]
		var ficha: Dictionary = alvo["ficha"]
		var dureza := float(ficha.get("dureza", 1.0))
		var custo: float = Energia.custo("bater", dureza)
		await _chegar_perto(jogador, mundo, alvo["pos"], 1.4 + float(alvo.get("meia_pegada", 0.0)))
		_conferir(recursos._perto == id, "perto do lajedo o alvo do E é '%s'" % recursos._perto)
		Energia.repor(1000.0)
		await process_frame
		_impactos = 0
		var antes: float = Energia.atual
		var golpes_antes := int(alvo["golpes_dados"])
		var quedas: Array[int] = []
		var golpes: Array[int] = []
		var ultima_energia := antes
		var ultimos_golpes := golpes_antes
		var caiu := false
		var inicio := Time.get_ticks_msec()
		var ultimo_e := -ENTRE_ES
		var es := 0
		while Time.get_ticks_msec() - inicio < DURACAO_DA_PROVA:
			await process_frame
			var t := Time.get_ticks_msec() - inicio
			_soltar_se_preciso()
			if t - ultimo_e >= ENTRE_ES:
				ultimo_e = t
				es += 1
				_apertar_e()
			if Energia.atual < ultima_energia - 0.01:
				quedas.append(t)
			ultima_energia = Energia.atual
			# A pedra que cai some de `_alvos` no último golpe: conta esse golpe uma vez.
			if recursos._alvos.has(id):
				var agora := int(recursos._alvos[id]["golpes_dados"])
				if agora != ultimos_golpes:
					golpes.append(t)
					ultimos_golpes = agora
			elif not caiu:
				caiu = true
				golpes.append(t)
		_soltar_se_preciso()
		var dados := golpes.size()
		print("  pedra: %d E, %d golpe(s) em %s ms (caiu: %s), %d cobrança(s) em %s ms, %d impacto(s), caiu %.1f de reserva (custo %.1f por golpe)" % [es, dados, str(golpes), str(caiu), quedas.size(), str(quedas), _impactos, antes - Energia.atual, custo])
		_conferir(dados >= 2, "o E a cada %d ms por %d ms rendeu só %d golpe(s)" % [ENTRE_ES, DURACAO_DA_PROVA, dados])
		_conferir(quedas.size() == dados, "%d cobrança(s) para %d golpe(s): cobrança sem golpe (ou golpe de graça)" % [quedas.size(), dados])
		for t_q in quedas:
			var junto := false
			for t_g in golpes:
				if absi(t_q - t_g) <= MESMO_INSTANTE:
					junto = true
			_conferir(junto, "a cobrança aos %d ms não tem golpe no mesmo instante (golpes em %s)" % [t_q, str(golpes)])
		_conferir(_impactos >= dados, "%d golpe(s) com %d impacto(s) de animação: golpe sem golpe à vista" % [dados, _impactos])
		_conferir(quedas.size() <= _impactos, "%d cobrança(s) para %d impacto(s): o E durante o golpe cobrou" % [quedas.size(), _impactos])
		_conferir(absf((antes - Energia.atual) - custo * float(dados)) < 0.05, "caíram %.1f de reserva para %d golpe(s) de %.1f" % [antes - Energia.atual, dados, custo])
		# O último E pode ter deixado um golpe a caminho: ele cai (e cobra) no
		# lajedo, não na árvore da parte seguinte.
		var limpo := Time.get_ticks_msec() + 4000
		while (recursos._golpe_pendente != "" or recursos._golpe_animando) and Time.get_ticks_msec() < limpo:
			await process_frame

	# --- 3. A ÁRVORE, com o machado ------------------------------------------------
	var arvores = current_scene.get_node_or_null("ArvoresInfo")
	_conferir(arvores != null, "o vale não tem as árvores")
	if arvores != null:
		_por_na_mao(Inv, "machado")
		var indice := -1
		var menor := INF
		for k in arvores._cortaveis.size():
			var a: Dictionary = arvores._cortaveis[k]
			if bool(a.get("cortado", false)) or str(arvores._recusa(k)) != "" or int(arvores._golpes_da(k)) < 3:
				continue
			var d: float = (a["pos"] as Vector3).distance_to(jogador.global_position)
			if d < menor:
				menor = d
				indice = k
		_conferir(indice >= 0, "não achei árvore que o machado corte sem recusa")
		if indice >= 0:
			var arvore: Dictionary = arvores._cortaveis[indice]
			var madeira: Dictionary = arvores.madeira_de(String(arvore["especie"]))
			var custo_da_madeira: float = Energia.custo("bater", float(madeira.get("dureza", 1.0)))
			await _chegar_perto(jogador, mundo, arvore["pos"], 1.0)
			Energia.repor(1000.0)
			jogador.set("_vigor", jogador.vigor_maximo())
			await process_frame
			var antes_a: float = Energia.atual
			var golpes_antes_a := int(arvore["golpes"])
			var inicio_a := Time.get_ticks_msec()
			var ultimo_e_a := -ENTRE_ES
			var es_a := 0
			while Time.get_ticks_msec() - inicio_a < DURACAO_NA_ARVORE:
				await process_frame
				var t := Time.get_ticks_msec() - inicio_a
				_soltar_se_preciso()
				if t - ultimo_e_a >= ENTRE_ES:
					ultimo_e_a = t
					es_a += 1
					_apertar_e()
			_soltar_se_preciso()
			var depois: Dictionary = arvores._cortaveis[indice]
			var dados_a := int(depois["golpes"]) - golpes_antes_a
			if bool(depois.get("cortado", false)):
				dados_a = int(arvores._golpes_da(indice)) - golpes_antes_a
			print("  árvore %s: %d E, %d golpe(s), caiu %.1f (custo %.1f por golpe), cortada=%s" % [str(arvore["especie"]), es_a, dados_a, antes_a - Energia.atual, custo_da_madeira, str(depois.get("cortado", false))])
			_conferir(dados_a >= 1, "o E repetido não deixou o corte da %s avançar: %d golpe(s) em %d ms" % [str(arvore["especie"]), dados_a, DURACAO_NA_ARVORE])
			_conferir(absf((antes_a - Energia.atual) - custo_da_madeira * float(dados_a)) < 0.05, "na %s caíram %.1f de reserva para %d golpe(s) de %.1f" % [str(arvore["especie"]), antes_a - Energia.atual, dados_a, custo_da_madeira])
	_fechar()


func _por_na_mao(Inv, item: String) -> void:
	if not Inv.tem(item):
		Inv.adicionar(item, 1)
	for i in Inv.ESPACOS_MAO:
		if str((Inv.espacos[i] as Dictionary).get("id", "")) == item:
			Inv.selecionar(i)


## Chega ao alvo e PARA: o corpo andando corta o gesto do golpe, e o que se
## pergunta aqui é o E repetido, não o passo.
func _chegar_perto(jogador, mundo, pos: Vector3, afastamento: float) -> void:
	var partida: Vector3 = mundo.ground_position(pos + Vector3(afastamento, 0.0, 0.0), 0.1)
	jogador.teleportar(partida, atan2(pos.x - partida.x, pos.z - partida.z))
	for i in 12:
		await physics_frame
	jogador.velocity = Vector3.ZERO
	await process_frame


func _apertar_e() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = _tecla_e
	ev.keycode = _tecla_e
	ev.pressed = true
	Input.parse_input_event(ev)
	_solta = true


func _soltar_se_preciso() -> void:
	if not _solta:
		return
	var ev := InputEventKey.new()
	ev.physical_keycode = _tecla_e
	ev.keycode = _tecla_e
	ev.pressed = false
	Input.parse_input_event(ev)
	_solta = false


func _fechar() -> void:
	_soltar_se_preciso()
	print("")
	if falhas == 0:
		print("GOLPE_REPETIDO_OK: o E repetido no lajedo cobra a reserva só no instante de cada golpe, nunca sem impacto da animação nem durante o golpe, e a conta fecha; na árvore o E repetido não interrompe o corte, e cada golpe custa o seu")
	else:
		print("golpe_repetido: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


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
