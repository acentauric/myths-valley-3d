extends SceneTree
## Confere as ONÇAS do vale (#28): onde moram, o que enxergam, como caçam e o
## corpo que vestem.
##
##     Godot_v4.7.2-stable-win64_console.exe --headless --path . --script res://tests/onca.gd
##
## O que este portão pergunta, e a luta (`luta.gd`) não:
##
##   1. SÃO DUAS, a pintada e a preta, fora de `criaturas` (a mata repõe o caititu
##      por ela), e moram em chão que segura: longe das casas (120 u), da chegada
##      e do ninho do caititu — e a pintada não cai no vazio da praia.
##   2. O PENEDO COM LAPA está no ninho de cada uma, com colisão.
##   3. VÊ COM OS OLHOS: o jogador a 12 u de frente, em campo aberto; NÃO através
##      de uma parede, NÃO fora do cone (a 12 u), mas FAREJA pelas costas a 3 u;
##      de noite o alcance cai e a 12 u ela não vê.
##   4. CAÇA EM ESTADOS: ronda → espreita (abaixada) → carga → bote → recua, avisa
##      o HUD uma vez só, em pt/en/es, e a música da mata liga.
##   5. A COLEIRA: jogador longe demais, ou ela longe demais do ninho, e ela volta
##      ao ninho cega.
##   6. NÃO ENTRA NA ÁGUA.
##   7. A PRETA SÓ ANDA DO ENTARDECER À MADRUGADA, e de noite os olhos dela brilham.
##   8. O CORPO: no Tripo, o GLB da pelagem (sem caixa cinza); no procedural, a
##      caixa. O aviso e a pancada são `material_overlay`, a queda é `transparency`.
##   9. O PASSO DAS ONÇAS é o clipe do GLB: o da pintada (torto, a girafa) é
##      recentrado em volta do repouso, o da preta (saudável) fica como veio, e a
##      perna dura da preta ganha balanço. Nada de perna de código no lugar do clipe.
##  10. A ONÇA MATA EM DUAS MORDIDAS quem não corre, e perde quem corre: a mordida
##      tira mais da metade da vida cheia (com 30, com 60 de vigor e com o gibão),
##      quem fica parado ou anda é alcançado e cai na segunda mordida, quem corre
##      não leva nenhuma e ela desiste. Numa ARENA PLANA longe do vale, com a física
##      e a vida passadas à mão, em segundos de jogo e sem depender da máquina.
##
## FALSIFICAÇÃO: com `--falsificar-onca` a parede de teste perde a colisão, e o
## jogador de costas passa a ficar de frente — a pergunta da parede e a do cone
## têm de FALHAR (o portão tem de sair vermelho). Com `--falsificar-onca-mordida`
## o jogador parado leva a mordida em ginga (a onça a gasta no vazio): as perguntas
## da seção 10 sobre matar têm de FALHAR.

const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")

var Criatura
var falhas := 0
var falsificar := false
var falsificar_mordida := false
var vida
var relogio
var dia


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("ONCA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	falsificar = "--falsificar-onca" in OS.get_cmdline_user_args()
	falsificar_mordida = "--falsificar-onca-mordida" in OS.get_cmdline_user_args()
	vida = root.get_node("/root/Vida")
	relogio = root.get_node("/root/Relogio")
	dia = root.get_node("/root/Dia")
	root.get_node("/root/Estilo").modo = "tripo"
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(6)
	await _mundo_pronto()
	await _frames(10)
	dia.pausado = true
	dia.definir_hora(10.0)
	var vale = current_scene
	var player = vale.player
	var world = vale.world
	var luta = vale.get_node_or_null("Luta")
	_conferir(luta != null, "o vale não montou o nó da luta")
	if luta == null:
		_fechar()
		return
	Criatura = load("res://scripts/prototipo_3d/criatura_vale.gd")

	# --- 1. DUAS ONÇAS, EM CHÃO QUE SEGURA --------------------------------------
	_conferir(luta.oncas.size() == 2, "o vale devia ter duas onças, tem %d" % luta.oncas.size())
	var pintada = _onca(luta, "pintada")
	var preta = _onca(luta, "preta")
	_conferir(pintada != null and preta != null, "faltou a pintada ou a preta")
	if pintada == null or preta == null:
		_fechar()
		return
	for c in luta.criaturas:
		_conferir(c.especie != "onca", "a onça entrou em `criaturas`, que é a lista que a mata repõe")
	var lotes: Dictionary = world.get("_lotes")
	for onca in [pintada, preta]:
		var perto := INF
		var quem := ""
		for nome in lotes:
			var d: float = _plano(world.ancoras.get(nome, Vector3.INF) - onca._ninho).length()
			if d < perto:
				perto = d
				quem = nome
		print("ONCA: %s no ninho %s · %.0f u da %s · %.0f u da chegada" % [onca.pelagem, str(onca._ninho), perto, quem,
			_plano(player.spawn_position - onca._ninho).length()])
		_conferir(perto >= 120.0, "a onça %s mora a %.0f u de %s (mínimo 120)" % [onca.pelagem, perto, quem])
		_conferir(_plano(player.spawn_position - onca._ninho).length() >= 120.0, "a onça %s mora perto da chegada" % onca.pelagem)
		_conferir(world.is_on_land(onca._ninho), "a onça %s nasceu na água" % onca.pelagem)
		_conferir(_chao_firme(onca._ninho), "não há chão sólido sob o ninho da onça %s: ela cairia no vazio" % onca.pelagem)
		for c in luta.criaturas:
			_conferir(_plano(c._ninho - onca._ninho).length() >= luta.ONCA_LONGE_DO_CAITITU, "a onça %s mora colada no caititu" % onca.pelagem)
	# A pintada, que anda de dia, continua em pé depois de uns quadros de física.
	await _fisica(90)
	_conferir(pintada.global_position.y > pintada._ninho.y - 2.0, "a onça pintada caiu: y=%.1f, o ninho está em %.1f" % [pintada.global_position.y, pintada._ninho.y])

	# --- 2. O PENEDO COM LAPA --------------------------------------------------
	for onca in [pintada, preta]:
		var penedo: Node3D = world.get_node_or_null("Penedo da onça %s" % onca.pelagem)
		_conferir(penedo != null, "a onça %s não tem penedo" % onca.pelagem)
		if penedo != null:
			var d := _plano(penedo.global_position - onca._ninho).length()
			_conferir(d > 1.5 and d < 8.0, "o penedo da onça %s está a %.1f u do ninho" % [onca.pelagem, d])
			_conferir(not penedo.find_children("*", "CollisionShape3D", true, false).is_empty(), "o penedo da onça %s não tem colisão" % onca.pelagem)

	# --- 3. VÊ COM OS OLHOS ----------------------------------------------------
	# A onça de teste nasce em campo aberto (um lugar onde a linha de 12 u é livre
	# nas duas pontas), e some no fim.
	var teste = luta.nascer("onca", world.ground_position(Vector3(0, 0, 0), 0.05), "pintada")
	teste.set_physics_process(false)
	await _fisica(2)
	var campo := _campo_aberto(world, teste)
	_conferir(campo.has("onde"), "não achei campo aberto onde a onça veja o jogador a 12 u")
	if not campo.has("onde"):
		_fechar()
		return
	var onde: Vector3 = campo["onde"]
	var rumo: Vector3 = campo["rumo"]
	teste.global_position = onde
	teste._ninho = onde
	teste._destino = onde
	teste.rotation.y = atan2(rumo.x, rumo.z)
	player.global_position = world.ground_position(onde + rumo * 12.0, 0.1)
	await _fisica(2)
	_conferir(teste.enxerga(player.global_position), "a onça não vê o jogador a 12 u, de frente, em campo aberto")
	# Não vê através de uma parede.
	var parede := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(10.0, 5.0, 0.6)
	forma.shape = caixa
	parede.add_child(forma)
	parede.collision_layer = 0 if falsificar else 1
	vale.add_child(parede)
	parede.global_position = world.ground_position(onde + rumo * 6.0, 0.0) + Vector3(0.0, 2.0, 0.0)
	parede.rotation.y = atan2(rumo.x, rumo.z)
	await _fisica(3)
	_conferir(not teste.enxerga(player.global_position), "a onça vê o jogador através de uma parede")
	parede.queue_free()
	await _fisica(3)
	# Não vê fora do cone a 12 u (o faro do 2D, 4,3 u, não chega).
	var atras: Vector3 = rumo if falsificar else -rumo
	player.global_position = world.ground_position(onde + atras * 12.0, 0.1)
	await _fisica(2)
	_conferir(not teste.enxerga(player.global_position), "a onça vê o jogador a 12 u, pelas costas")
	# Fareja pelas costas a 3 u.
	player.global_position = world.ground_position(onde - rumo * 3.0, 0.1)
	await _fisica(2)
	_conferir(teste.enxerga(player.global_position), "a onça não farejou o jogador a 3 u, pelas costas")
	# Além do alcance de dia (16 u), de frente.
	player.global_position = world.ground_position(onde + rumo * 20.0, 0.1)
	await _fisica(2)
	_conferir(not teste.enxerga(player.global_position), "a onça vê o jogador a 20 u, além do alcance")
	# De noite o alcance cai (10 u): a 12 u, de frente, ela não vê.
	player.global_position = world.ground_position(onde + rumo * 12.0, 0.1)
	dia.definir_hora(22.0)
	await _fisica(2)
	_conferir(not teste.enxerga(player.global_position), "de noite a onça ainda vê o jogador a 12 u")
	dia.definir_hora(10.0)
	await _fisica(2)
	_conferir(teste.enxerga(player.global_position), "de dia a onça deixou de ver o jogador a 12 u")

	# --- 4. A CAÇA, EM ESTADOS --------------------------------------------------
	var avistou := [0]
	teste.avistou.connect(func(_c): avistou[0] += 1)
	teste.set_physics_process(true)
	luta.avisou_da_onca = false
	player.global_position = world.ground_position(onde + rumo * 9.0, 0.1)
	player.velocity = Vector3.ZERO
	vida.dormir()
	var estados: Dictionary = {}
	var abaixou := false
	var musica := false
	var t := 0.0
	while t < 14.0 and not (estados.has("recua") and estados.has("bote")):
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		estados[teste.estado_agora()] = true
		if teste.estado == "espreita" and teste._animador.altura_alvo < 1.0:
			abaixou = true
		if teste.cacando and root.get_node("/root/Audio").get("_mata_ativa") == true:
			musica = true
		if vida.atual < vida.maximo() - 1.0:
			vida.dormir()
	print("ONCA: estados vistos %s em %.1f s" % [str(estados.keys()), t])
	for estado in ["espreita", "carga", "bote", "recua"]:
		_conferir(estados.has(estado), "a caça da onça não passou por '%s'" % estado)
	_conferir(abaixou, "a onça não abaixou o corpo ao espreitar")
	_conferir(avistou[0] >= 1, "a onça viu o jogador e não emitiu o sinal")
	_conferir(luta.avisou_da_onca, "o HUD não avisou da primeira vez que a onça viu o jogador")
	_conferir(musica, "a música da mata não ligou com a onça caçando")
	var textos: Dictionary = _ler("res://data/luta.json").get("onca_viu", {})
	var pt := str(textos.get("texto", ""))
	var en := str(textos.get("texto_en", ""))
	var es := str(textos.get("texto_es", ""))
	_conferir(pt != "" and en != "" and es != "" and en != pt and es != pt and en != es, "o aviso da onça não está nos três idiomas")

	# --- 5. A COLEIRA -----------------------------------------------------------
	teste.estado = "carga"
	teste.cacando = true
	player.global_position = world.ground_position(onde + rumo * 12.0, 0.1)
	teste.global_position = world.ground_position(onde + rumo * 8.0, 0.05)
	await _fisica(3)
	player.global_position = world.ground_position(onde + rumo * 60.0, 0.1)
	await _fisica(8)
	_conferir(teste.estado == "volta" and not teste.cacando, "com o jogador a 60 u a onça não desistiu (estado %s)" % teste.estado)
	_conferir(teste.cega(), "a onça que desistiu não ficou cega")
	teste.estado = "carga"
	teste.cacando = true
	var coleira: float = Criatura.VISTA["onca"]["territorio"]
	teste.global_position = world.ground_position(onde + rumo * (coleira + 6.0), 0.05)
	player.global_position = world.ground_position(onde + rumo * (coleira + 10.0), 0.1)
	await _fisica(8)
	_conferir(teste.estado == "volta", "a onça a %.0f u do ninho (coleira de %.0f) não voltou: %s" % [coleira + 6.0, coleira, teste.estado])

	# --- 6. NÃO ENTRA NA ÁGUA ---------------------------------------------------
	var margem := _margem(world)
	_conferir(margem.has("terra"), "não achei uma margem para a onça de teste")
	if margem.has("terra"):
		teste.set_physics_process(false)
		teste.global_position = margem["terra"]
		var para: Vector3 = margem["mar"]
		for i in 40:
			teste.velocity = para * 6.0
			teste._mover(1.0 / Engine.physics_ticks_per_second)
			await physics_frame
		_conferir(world.is_on_land(teste.global_position), "a onça entrou na água: %s" % str(teste.global_position))

	# --- 8. O CORPO, E O QUE VAI POR CIMA ---------------------------------------
	_conferir(pintada.chave_do_modelo() == "onca_pintada" and preta.chave_do_modelo() == "onca_preta", "a pelagem não escolhe o GLB")
	for onca in [pintada, preta]:
		_conferir(onca.find_child("Caixa", true, false) == null, "a onça %s vestiu a caixa cinza no estilo Tripo" % onca.pelagem)
		_conferir(not onca._malhas.is_empty(), "a onça %s não tem malha" % onca.pelagem)
	teste.set_physics_process(true)
	teste._acender(true)
	_conferir(teste.tinta_por_cima() != null, "o aviso não pôs tinta por cima da malha")
	var tinta_do_aviso = teste.tinta_por_cima()
	teste._acender(false)
	teste.ferir(1.0)
	await _fisica(2)
	_conferir(teste.tinta_por_cima() != null and teste.tinta_por_cima() != tinta_do_aviso, "a pancada não pôs a tinta dela por cima")
	teste.ferir(1000.0)
	await create_timer(Criatura.TEMPO_DA_MORTE + 0.2).timeout
	var some := false
	if is_instance_valid(teste):
		for m in teste._malhas:
			some = some or (is_instance_valid(m) and m.transparency > 0.05)
	else:
		some = true
	_conferir(some, "a queda da onça não esmaeceu a malha (transparency)")
	await create_timer(0.8).timeout
	_conferir(not is_instance_valid(teste), "a onça caída não sumiu")
	luta.oncas.erase(teste)

	# --- 7. A PRETA SÓ ANDA DO ENTARDECER À MADRUGADA ---------------------------
	dia.definir_hora(12.0)
	await create_timer(0.6).timeout
	_conferir(not preta.ativa() and not preta.visible, "a onça-preta anda ao meio-dia")
	_conferir(pintada.ativa(), "a pintada parou de andar de dia")
	dia.definir_hora(22.0)
	await create_timer(0.6).timeout
	_conferir(preta.ativa() and preta.visible, "a onça-preta não anda de noite")
	await _fisica(30)
	_conferir(preta.olhos_acesos(), "os olhos da onça-preta não brilham de noite")
	dia.definir_hora(10.0)
	await create_timer(0.6).timeout
	_conferir(not preta.olhos_acesos() or not preta.ativa(), "os olhos da preta continuam acesos de dia")
	dia.definir_hora(10.0)

	# --- 9. O PASSO É O CLIPE DO GLB -----------------------------------------------------
	var Animador = load("res://scripts/prototipo_3d/animador_bicho.gd")
	for chave in ["onca_pintada", "cachorro_caramelo"]:
		_conferir(chave in Animador.CLIPE_TORTO, "%s saiu da lista de clipe torto" % chave)
	_conferir(not "onca_preta" in Animador.CLIPE_TORTO, "a onça preta, de clipe saudável, entrou na lista de clipe torto")
	for onca in [pintada, preta]:
		_conferir(onca._animador.tem_clipe(), "a onça %s não anda com o clipe do GLB" % onca.pelagem)
	_conferir(pintada._animador.clipe_recentrado(), "o clipe torto da onça pintada não foi recentrado")
	_conferir(not preta._animador.clipe_recentrado(), "o clipe saudável da onça preta foi recentrado")
	_conferir(preta._animador.pernas_paradas() >= 1, "a perna dura da onça preta não ganhou balanço (%d pernas paradas)" % preta._animador.pernas_paradas())

	# --- 8b. O PROCEDURAL: A CAIXA ----------------------------------------------
	root.get_node("/root/Estilo").modo = "procedural"
	var caixa_onca = luta.nascer("onca", world.ground_position(onde + Vector3(3.0, 0.0, 3.0), 0.05), "preta")
	await _frames(3)
	_conferir(caixa_onca.find_child("Caixa", true, false) != null, "no estilo procedural a onça não é a caixa")
	_conferir(not caixa_onca._malhas.is_empty(), "a caixa da onça não tem malha para o aviso")
	caixa_onca._acender(true)
	_conferir(caixa_onca.tinta_por_cima() != null, "no procedural o aviso não pôs tinta")
	root.get_node("/root/Estilo").modo = "tripo"
	luta.oncas.erase(caixa_onca)
	caixa_onca.queue_free()

	# --- 10. DUAS MORDIDAS MATAM QUEM NÃO CORRE, E QUEM CORRE ESCAPA --------------------
	await _duas_mordidas(vale, luta, player)

	_fechar()


## A mordida da onça e a fuga, numa arena plana no ALTO do vale (a 800 u de altura: sem casa,
## tronco, água nem colisão de ninguém — e DENTRO do quadro do mapa, porque as bordas dele
## empurram para dentro quem as toca: com a arena a 8 km de lado, a onça era cuspida para o
## meio do vale no primeiro passo) e com a física da onça e a vida do jogador passadas À MÃO,
## quadro a quadro de 1/60 s: o resultado é o do jogo em segundos de JOGO, e não
## depende de a máquina estar folgada. O jogador de mentira é um nó que o teste
## empurra; quem morde é a onça de verdade, e quem apanha é a `Vida` de verdade.
func _duas_mordidas(vale, luta, player) -> void:
	var queda = vale.get_node_or_null("Queda")
	if queda != null:
		var ao_cair := Callable(queda, "_ao_cair")
		if vida.caiu.is_connected(ao_cair):
			# O teste derruba o jogador de propósito: a noite não pode virar por causa disso.
			vida.caiu.disconnect(ao_cair)
	var progressao = root.get_node("/root/Progressao")
	var equipamento = root.get_node("/root/Equipamento")
	var vida_de_antes: float = progressao.vida_maxima
	var quedas := [0]
	vida.caiu.connect(func() -> void: quedas[0] += 1)
	var arena := Node3D.new()
	arena.name = "ArenaDaOnca"
	vale.add_child(arena)
	arena.global_position = Vector3(0.0, 800.0, 0.0)
	var chao := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(800.0, 2.0, 800.0)
	forma.shape = caixa
	chao.add_child(forma)
	chao.collision_layer = 1
	arena.add_child(chao)
	chao.position = Vector3(0.0, -1.0, 0.0)
	var jogador := Node3D.new()
	jogador.name = "JogadorDeMentira"
	arena.add_child(jogador)
	jogador.set_physics_process(true)
	await _fisica(3)
	var u: float = luta.u_por_px
	var dt := 1.0 / float(Engine.physics_ticks_per_second)

	# 10a. A mordida, golpe a golpe: com 30 de vida, com 60 (vigor) e com o gibão.
	var casos := [{"rotulo": "30 de vida", "vida": 30.0, "gibao": false},
		{"rotulo": "60 de vida (vigor)", "vida": 60.0, "gibao": false},
		{"rotulo": "30 de vida com o gibão", "vida": 30.0, "gibao": true}]
	for caso in casos:
		progressao.ajustar("vida_maxima", float(caso["vida"]))
		if caso["gibao"]:
			equipamento.vestido["corpo"] = "gibao_de_couro"
		_zerar_a_vida()
		quedas[0] = 0
		var onca = _onca_da_arena(arena, jogador, u)
		jogador.global_position = arena.global_position + Vector3(0.0, 0.0, 0.5)
		if falsificar_mordida:
			vida.livrar(600.0)
		onca._morder()
		var depois_da_primeira: float = vida.atual
		_conferir(depois_da_primeira > 0.0 and depois_da_primeira < vida.maximo(),
			"com %s a primeira mordida deixou %.1f de %.1f: devia ferir e não matar" % [caso["rotulo"], depois_da_primeira, vida.maximo()])
		var esperou := 0.0
		while vida.respirando() and esperou < 3.0:
			vida._physics_process(dt)
			esperou += dt
		onca._morder()
		_conferir(vida.atual <= 0.0 and quedas[0] == 1,
			"com %s duas mordidas não bastaram: sobraram %.1f de %.1f (quedas %d)" % [caso["rotulo"], vida.atual, vida.maximo(), quedas[0]])
		onca.queue_free()
		equipamento.vestido.erase("corpo")
	progressao.ajustar("vida_maxima", vida_de_antes)

	# 10b. A caçada inteira, na arena: o jogador a 10 u, de frente para ela.
	var parado := _cacada(arena, jogador, u, 0.0, 9.0, 10.0)
	var andando := _cacada(arena, jogador, u, player.walk_speed, 18.0, 10.0)
	var correndo := _cacada(arena, jogador, u, player.run_speed, 12.0, 10.0)
	print("ONCA: parado %s · andando %s · correndo %s" % [str(parado), str(andando), str(correndo)])
	_conferir(parado["mordidas"] == 2 and parado["caiu_em"] > 0.0 and parado["caiu_em"] <= 8.0,
		"quem fica parado devia cair na segunda mordida em até 8 s: %s" % str(parado))
	_conferir(andando["mordidas"] == 2 and andando["caiu_em"] > 0.0 and andando["caiu_em"] <= 16.0,
		"quem anda (%.1f u/s) devia ser alcançado e cair na segunda mordida em até 16 s: %s" % [player.walk_speed, str(andando)])
	_conferir(correndo["mordidas"] == 0 and correndo["caiu_em"] < 0.0 and not correndo["cacando"],
		"quem corre (%.1f u/s) devia escapar sem mordida, e ela desistir: %s" % [player.run_speed, str(correndo)])
	var passo := float(Criatura.ESPECIES["onca"]["passo"]) * u
	_conferir(passo >= player.walk_speed * 1.5 and passo <= player.run_speed * 0.9,
		"a onça (%.2f u/s) devia ser bem mais rápida que o passo (%.1f) e mais lenta que a carreira (%.1f)" % [passo, player.walk_speed, player.run_speed])

	arena.queue_free()
	vida._livre_por = 0.0
	_zerar_a_vida()


func _zerar_a_vida() -> void:
	vida._livre_por = 0.0
	vida.dormir()


func _onca_da_arena(arena: Node3D, jogador: Node3D, u: float):
	var bicho = Criatura.new()
	bicho.especie = "onca"
	bicho.pelagem = "pintada"
	arena.add_child(bicho)
	bicho.global_position = arena.global_position + Vector3(0.0, 0.05, 0.0)
	bicho.configurar(null, jogador, u)
	bicho.set_physics_process(false)
	return bicho


## Uma caçada: a onça na origem da arena, virada para +Z, e o jogador `distancia` u à frente,
## andando para longe dela a `velocidade` (0 = parado) por `segundos` de jogo. Devolve quantas
## mordidas entraram, em que segundo a vida zerou (-1 se não zerou) e como ela terminou.
func _cacada(arena: Node3D, jogador: Node3D, u: float, velocidade: float, segundos: float, distancia: float) -> Dictionary:
	_zerar_a_vida()
	var onca = _onca_da_arena(arena, jogador, u)
	jogador.global_position = arena.global_position + Vector3(0.0, 0.0, distancia)
	if falsificar_mordida and velocidade == 0.0:
		vida.livrar(600.0)
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var mordidas := [0]
	onca.mordeu.connect(func(_quanto: float) -> void: mordidas[0] += 1)
	var t := 0.0
	var caiu_em := -1.0
	while t < segundos:
		jogador.global_position.z += velocidade * dt
		vida._physics_process(dt)
		onca._physics_process(dt)
		t += dt
		if vida.atual <= 0.0:
			# Quem zerou a vida CAIU: no jogo a queda leva o jogador embora e a onça deixa de morder.
			caiu_em = t
			break
	var resultado := {"mordidas": mordidas[0], "caiu_em": snappedf(caiu_em, 0.01), "estado": onca.estado, "cacando": onca.cacando,
		"distancia": snappedf(_plano(jogador.global_position - onca.global_position).length(), 0.1)}
	onca.queue_free()
	_zerar_a_vida()
	return resultado


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("ONCA_OK: duas onças em chão firme a mais de 120 u das casas, com penedo; veem com cone, linha livre e alcance (e de noite menos), farejam pelas costas, caçam em estados com aviso nos três idiomas, a coleira as manda de volta, não entram na água, a preta só anda do entardecer à madrugada com os olhos acesos, o corpo é o GLB (ou a caixa) com aviso, pancada e queda por cima da malha e o passo é o clipe do GLB; e duas mordidas matam quem fica parado ou anda, enquanto quem corre escapa")
	else:
		print("onca: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _onca(luta, pelagem: String):
	for o in luta.oncas:
		if is_instance_valid(o) and o.pelagem == pelagem:
			return o
	return null


## Chão sólido sob o ponto: um raio na camada 1 acha a terra, perto da altura do ninho.
func _chao_firme(ninho: Vector3) -> bool:
	var espaco = current_scene.get_world_3d().direct_space_state
	var pergunta := PhysicsRayQueryParameters3D.create(ninho + Vector3.UP * 3.0, ninho + Vector3.DOWN * 4.0, 1)
	var achado: Dictionary = espaco.intersect_ray(pergunta)
	return not achado.is_empty() and absf((achado["position"] as Vector3).y - ninho.y) < 1.2


## Um ponto e um rumo em campo aberto: chão firme onde a onça de teste, virada
## para o rumo, ENXERGA um ponto a 12 u à frente (cone, alcance e linha livre
## de verdade, troncos e casas inclusos).
func _campo_aberto(world, teste) -> Dictionary:
	for cx in range(-60, 60, 8):
		for cz in range(-60, 60, 8):
			var p: Vector3 = world.ground_position(Vector3(cx, 0, cz), 0.0)
			if not world.is_on_land(p) or not _chao_firme(p):
				continue
			for giro in 8:
				var rumo := Vector3.FORWARD.rotated(Vector3.UP, giro * PI / 4.0)
				var fim: Vector3 = world.ground_position(p + rumo * 12.0, 0.1)
				if not world.is_on_land(fim) or absf(fim.y - p.y) > 1.5:
					continue
				teste.global_position = p
				teste.rotation.y = atan2(rumo.x, rumo.z)
				if teste.enxerga(fim) and teste.linha_livre(world.ground_position(p - rumo * 3.0, 0.1)):
					return {"onde": p, "rumo": rumo}
	return {}


## Uma margem: um ponto de terra e o rumo (plano) em que logo vem água.
func _margem(world) -> Dictionary:
	for giro in 16:
		var rumo := Vector3.RIGHT.rotated(Vector3.UP, giro * PI / 8.0)
		var base := Vector3(60, 0, 0)
		for passo in range(0, 400):
			var p := base + rumo * float(passo)
			var q := base + rumo * float(passo + 1)
			if world.is_on_land(p) and not world.is_on_land(q):
				return {"terra": world.ground_position(p, 0.05), "mar": rumo}
	return {}


func _ler(caminho: String) -> Dictionary:
	var arquivo := FileAccess.open(caminho, FileAccess.READ)
	if arquivo == null:
		return {}
	var lido = JSON.parse_string(arquivo.get_as_text())
	return lido if lido is Dictionary else {}


func _plano(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
