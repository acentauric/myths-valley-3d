extends SceneTree
## Confere A LOMBADA, A LAPA E A CABRA, a frente do ofício do 2D
## (docs/projeto/MISSOES_DO_2D.md, 1.5; data/missoes_lombada.json;
## scripts/prototipo_3d/lombada_vale.gd).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/lombada.gd
##
## Sete perguntas:
##
##   1. O LUGAR: a lapa e a cabra resolvem, a cabra lá em cima e a lapa no chão;
##      a lapa é alvo de trabalho; e nenhum tronco da mata atravessa a pedra.
##   2. A RAMPA FECHADA: com a lapa de pé, quem vem pelo leste bate nela, e o alto
##      não se sobe pelos lados.
##   3. A FRENTE ESPERA A LENHA DA PONTE: antes dela o E no Pedro não a abre; depois,
##      abre.
##   4. A LAPA: com a picareta na mão, oito golpes a racham, dão as oito pedras e
##      abrem o corredor; o passo fecha pela passagem e paga os dois beijus.
##   5. A CABRA: chegar lá em cima fecha o passo, e ela desce e vai embora — ANDANDO,
##      com o clipe de andar da cabra do rig no ritmo do chão (antes era uma malha parada
##      que escorregava rampa abaixo).
##   6. A VOLTA: o E no Pedro fecha a frente, com a Santa Casa na fala.
##   7. O SAVE: a partida que volta tem a lapa caída e a cabra em casa.

const RelogioDeJogo = preload("res://tests/fixtures/relogio_de_jogo.gd")

var falhas := 0
var vale
var tecla
var jogador
var pedro


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("LOMBADA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	vale = current_scene
	tecla = vale.get("tecla_dos_moradores")
	jogador = vale.player
	pedro = vale.get("pedro")
	var mundo = vale.world
	var lugares = root.get_node("/root/Lugares")
	var inv = root.get_node("/root/Inventario")
	var energia = root.get_node("/root/Energia")
	root.get_node("/root/Dia").pausado = true
	var frente = vale._cadeias.get("pedro_lombada")
	var ponte = vale._cadeias.get("pedro_ponte")
	var lombada = vale.get("lombada")
	var recursos = vale.get("_recursos")
	var Lombada = load("res://scripts/prototipo_3d/lombada_vale.gd")
	_conferir(frente != null and ponte != null and lombada != null and recursos != null and pedro != null,
		"o vale não tem a frente da lombada (%s), a ponte (%s), a lombada (%s) ou os alvos (%s)" % [str(frente), str(ponte), str(lombada), str(recursos)])
	if frente == null or ponte == null or lombada == null or recursos == null or pedro == null:
		_fechar()
		return

	# --- 1. O LUGAR ---------------------------------------------------------------
	var lapa: Vector3 = lugares.ponto("lapa")
	var alto: Vector3 = lugares.ponto("cabra_do_alto")
	var centro: Vector3 = lugares.ponto("lombada")
	_conferir(lapa.is_finite() and alto.is_finite() and centro.is_finite(), "a lapa (%s), a cabra (%s) ou a lombada (%s) não resolve" % [str(lapa), str(alto), str(centro)])
	if not lapa.is_finite() or not alto.is_finite() or not centro.is_finite():
		_fechar()
		return
	_conferir(alto.y - mundo.ground_height_at(lapa) > 2.0, "o alto da cabra está a %.1f acima do pé da lapa: não é alto" % (alto.y - mundo.ground_height_at(lapa)))
	_conferir(recursos._alvos.has("lapa_da_lombada"), "a lapa não é alvo de trabalho no vale")
	var regiao = mundo.get("_region")
	var atravessa := 0
	for tronco in regiao._tree_trunks:
		var ponto: Vector2 = tronco.get("point", Vector2.INF)
		var local := ponto - Vector2(centro.x, centro.z)
		if local.x > -Lombada.ALTO.x * 0.5 - 0.5 and local.x < Lombada.PE_DA_RAMPA + Lombada.ANTES_DA_LAPA + 2.0 and absf(local.y) < Lombada.ALTO.z * 0.5 + 0.5:
			atravessa += 1
	_conferir(atravessa == 0, "%d tronco(s) da mata atravessam a lombada" % atravessa)

	# --- 2. A RAMPA FECHADA ----------------------------------------------------------
	await physics_frame
	await physics_frame
	_conferir(lombada.trancada(), "com a lapa de pé, o corredor da rampa está aberto")
	var espaco: PhysicsDirectSpaceState3D = vale.get_world_3d().direct_space_state
	var de_fora: Vector3 = mundo.ground_position(lapa + Vector3(3.0, 0, 0)) + Vector3.UP * 0.9
	var para_dentro: Vector3 = mundo.ground_position(lapa - Vector3(2.5, 0, 0)) + Vector3.UP * 0.9
	var batida := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(de_fora, para_dentro))
	_conferir(not batida.is_empty(), "quem vem pelo leste passa pela lapa: o raio não bateu em nada")
	for lado in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(-1, 0, 0)]:
		var fora: Vector3 = mundo.ground_position(centro + lado * 7.0) + Vector3.UP * 1.0
		var bate := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(fora, Vector3(centro.x, fora.y, centro.z)))
		_conferir(not bate.is_empty(), "o alto não tem parede do lado %s" % str(lado))

	# --- 3. A FRENTE ESPERA A LENHA DA PONTE --------------------------------------------
	pedro.missao = pedro.MISSOES.size()
	# A despedida pertence à cadeia; set de uma propriedade antiga no NPC
	# falhava silenciosamente e deixava o tutorial incompleto no fixture.
	pedro._cadeia.despedida_feita = true
	ponte.iniciado = true
	ponte.missao = _indice(ponte, "ponte_lenha")
	ponte.espera = 0.0
	await _perto_do_pedro()
	tecla.usar(pedro)
	await _quadros(3)
	_conferir(not frente.iniciado, "a frente da lombada abriu antes da lenha da ponte")
	ponte.missao = _indice(ponte, "tabuas")
	await _perto_do_pedro()
	tecla.usar(pedro)
	_conferir(await _ate(func() -> bool: return frente.iniciado, 4.0), "com a lenha da ponte juntada, o E no Pedro não abriu a lombada")

	# --- 4. A LAPA -----------------------------------------------------------------------
	await _ate(func() -> bool: return frente.espera <= 0.0, 12.0)
	_conferir(str(frente.passo_atual().get("id", "")) == "picareta", "a frente não começou pela lapa")
	if not inv.tem("picareta"):
		inv.adicionar("picareta", 1)
	for i in inv.ESPACOS_MAO:
		if str((inv.espacos[i] as Dictionary).get("id", "")) == "picareta":
			inv.selecionar(i)
	_conferir(inv.na_mao() == "picareta", "não consegui pôr a picareta na mão")
	jogador.teleportar(mundo.ground_position(lapa + Vector3(1.9, 0, 0), 0.1), PI * 0.5)
	await physics_frame
	await physics_frame
	await _quadros(4)
	_conferir(recursos._perto == "lapa_da_lombada", "ao lado da lapa, o alvo perto é '%s'" % recursos._perto)
	var pedras: int = inv.quantidade("pedra")
	var beijus: int = inv.quantidade("beiju")
	var golpes := 0
	for i in 12:
		if not recursos._alvos.has("lapa_da_lombada"):
			break
		energia.encher()
		if recursos.bater():
			golpes += 1
		await _esperar_golpe(recursos)
	_conferir(golpes == 8 and not recursos._alvos.has("lapa_da_lombada"), "a lapa caiu em %d golpe(s), e são oito" % golpes)
	_conferir(inv.quantidade("pedra") == pedras + 8, "a lapa não deu as oito pedras: %d" % (inv.quantidade("pedra") - pedras))
	_conferir(await _ate(func() -> bool: return not lombada.trancada(), 2.0), "caída a lapa, o corredor da rampa continua fechado")
	_conferir(await _ate(func() -> bool: return frente.missao >= 1, 8.0), "a lapa caída não fechou o passo da passagem")
	_conferir(inv.quantidade("beiju") == beijus + 2, "a lapa não pagou os dois beijus")

	# --- 5. A CABRA ----------------------------------------------------------------------
	await _ate(func() -> bool: return frente.espera <= 0.0, 12.0)
	_conferir(str(frente.passo_atual().get("id", "")) == "cabra", "depois da lapa não veio a cabra")
	_conferir(lombada.cabra().is_finite() and lombada.cabra().y > alto.y - 0.6, "a cabra não está lá em cima: %s" % str(lombada.cabra()))
	var cabra_de_cena = lombada._cabra
	_conferir(cabra_de_cena != null and cabra_de_cena.has_method("animador") and cabra_de_cena.animador().tem_clipe(),
		"a cabra da lombada não tem o clipe de andar (é a malha parada do adereço, que escorrega?)")
	jogador.teleportar(alto + Vector3(0.6, 0.2, 0.4), 0.0)
	_conferir(await _ate(func() -> bool: return frente.missao >= 2, 8.0), "chegar perto da cabra lá em cima não fechou o passo")
	# A descida, em segundos de JOGO: enquanto o corpo sai do lugar o clipe toca, no ritmo do chão
	# (2,4 u/s); parada, não. Quem a leva é um Tween, e o animador só sabe de `andar` e `parar`.
	var relogio := RelogioDeJogo.new()
	root.add_child(relogio)
	var visto := {"andou_com_pernas": false, "ritmo": 0.0, "andou_sem_clipe": false, "seguidos": 0}
	var desceu: bool = await relogio.ate(func() -> bool: return _vigiar_a_descida(visto), 30.0)
	_conferir(desceu, "a cabra não desceu e foi embora")
	_conferir(visto["andou_com_pernas"], "a cabra desceu a rampa sem mexer as pernas (escorregando): %s" % str(visto))
	_conferir(not visto["andou_sem_clipe"], "houve quadro em que a cabra andava sem o clipe tocando: %s" % str(visto))
	_conferir(float(visto["ritmo"]) > 0.5, "o clipe da cabra na descida toca a %.2fx, devagar demais para 2,4 u/s" % float(visto["ritmo"]))

	# --- 6. A VOLTA -------------------------------------------------------------------------
	await _ate(func() -> bool: return frente.espera <= 0.0, 12.0)
	await _perto_do_pedro()
	tecla.usar(pedro)
	_conferir(await _ate(func() -> bool: return frente.acabou(), 8.0), "o E no Pedro não fechou a frente da lombada")
	_conferir(_no_balao(pedro).contains("Santa Casa"), "o Pedro não falou da Santa Casa: '%s'" % _no_balao(pedro))

	# --- 7. O SAVE ---------------------------------------------------------------------------
	var guardado: Dictionary = vale.estado_para_salvar()
	vale.restaurar_do_save(guardado)
	await _quadros(10)
	await _ate(func() -> bool: return false, 0.6)
	_conferir(not lombada.trancada(), "a partida que volta fechou o corredor de novo: a lapa reapareceu")
	_conferir(not lombada.cabra().is_finite(), "a partida que volta pôs a cabra lá em cima de novo")
	_fechar()


## Um quadro da descida: se a cabra está andando (o animador tem velocidade), o clipe toca? Devolve
## se ela já desceu.
func _vigiar_a_descida(visto: Dictionary) -> bool:
	var cabra = vale.get("lombada")._cabra if vale.get("lombada") != null else null
	if is_instance_valid(cabra) and cabra.has_method("andando") and cabra.andando():
		var an = cabra.animador()
		var tocando: bool = an.animacao != null and an.animacao.is_playing()
		if tocando and an.animacao.speed_scale > 0.3:
			visto["andou_com_pernas"] = true
			visto["seguidos"] = 0
			visto["ritmo"] = maxf(float(visto["ritmo"]), an.animacao.speed_scale)
		else:
			# O animador põe o clipe a tocar no quadro seguinte ao `andar`: um quadro sem ele é
			# o tempo do Tween chamar e do `_process` responder; quatro seguidos, não.
			visto["seguidos"] += 1
			if visto["seguidos"] > 3:
				visto["andou_sem_clipe"] = true
	return vale.get("lombada").a_cabra_ja_desceu()


func _indice(cadeia, id: String) -> int:
	for i in cadeia.passos.size():
		if str((cadeia.passos[i] as Dictionary).get("id", "")) == id:
			return i
	return -1


func _perto_do_pedro() -> void:
	jogador.teleportar(pedro.global_position + Vector3(1.0, 0.1, 0.6), 0.0)
	await _quadros(5)
	# Conversar agora respeita a voz ativa. Headless faz cinco quadros antes
	# de passar o prazo real da saudação; espere a boca liberar o E.
	_conferir(await _ate(func() -> bool: return not pedro.falando_agora(), 30.0),
		"Pedro terminou a fala antes da próxima interação")


func _no_balao(morador) -> String:
	var rotulo = morador.balao.get("_texto")
	return str(rotulo.text) if rotulo != null else ""


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("LOMBADA_OK: a lapa e a cabra resolvem, a lapa é alvo de trabalho e nenhum tronco atravessa a pedra; com a lapa de pé a rampa está fechada e o alto não se sobe pelos lados; a frente espera a lenha da ponte; oito golpes de picareta racham a lapa em oito pedras, abrem o corredor e fecham o passo; lá em cima a cabra desce e vai embora; a volta ao Pedro fala da Santa Casa; e a partida que volta tem a lapa caída e a cabra em casa")
	else:
		print("lombada: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


## O golpe do `Recursos3D` leva 1,5 s de JOGO, e o jogo anda mais devagar que a parede
## quando o quadro passa de 50 ms (`max_physics_steps_per_frame`, project.godot): a
## janela de 2,5 s de relógio reprovava na bateria cheia. A espera sai assim que o
## golpe acaba; o teto só pega o golpe que não acaba nunca.
func _esperar_golpe(recursos) -> void:
	var limite := Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < limite and (str(recursos.get("_golpe_pendente")) != "" or bool(recursos.get("_golpe_animando"))):
		await process_frame


## Roda quadros até `condicao` valer, com teto em SEGUNDO REAL.
func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
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
