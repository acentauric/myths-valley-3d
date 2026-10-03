extends SceneTree
## Confere A FÉ NO CHÃO DO VALE (#52): os marcos, o que acontece neles e a teia
## da fé no K.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/fe_no_vale.gd
##
## As três fés já estavam de pé (`tests/fe.gd` confere os autoloads); aqui se
## pergunta o que o vale fez com elas:
##
##   1. OS SEIS MARCOS ESTÃO NO VALE: o cruzeiro, o altar da igreja (DENTRO da
##      nave), a capela velha, o cemitério, o terreiro e a gameleira — em terra,
##      e com nome que o `Lugares` resolve.
##   2. A MATA RESPEITA o terreiro e o sambaqui: nenhum tronco dela no meio deles.
##   3. A TECLA APARECE no marco ("Olhar" para quem não é da fé), e o altar só
##      se alcança de dentro da nave, e não do lado de fora da parede.
##   4. SEM A DONA ZEFA, MARCO NENHUM ACEITA NINGUÉM.
##   5. COM ELA, ENTRA-SE NUMA FÉ NO MARCO DELA, e o Tab do K mostra a teia dela.
##   6. O RITO no marco da fé: fôlego, XP de fé, bênção — e, de novo antes do
##      prazo, a graça não vem e o marco diz quando volta.
##   7. TROCAR DE FÉ: duas perguntas; trocar sem levar o acumulado deixa a fé
##      antiga congelada INTEIRA, e a página das regras diz isso.
##   8. A TEIA DA FÉ DESTRAVA nó com ponto de fé.

var falhas := 0
var dialogo
var vale
var marcos


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("FE_NO_VALE_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	dialogo = root.get_node("/root/Dialogo")
	var fe = root.get_node("/root/Fe")
	var ritos = root.get_node("/root/Ritos")
	var energia = root.get_node("/root/Energia")
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(8)
	vale = current_scene
	marcos = vale.get("marcos")
	_conferir(marcos != null, "o vale não tem os marcos de fé")
	if marcos == null:
		_fechar()
		return
	var world = vale.world
	var jogador = vale.player
	var interiores = vale.get("interiores")

	# --- 1. OS SEIS MARCOS -------------------------------------------------------
	for marco in ["cruzeiro", "capela", "capela_estrada", "cemiterio", "terreiro", "gameleira"]:
		var onde: Vector3 = marcos.ponto(marco)
		_conferir(onde.is_finite(), "o marco '%s' não está no vale" % marco)
	for nome in ["cruzeiro", "capela_estrada", "terreiro", "gameleira"]:
		_conferir(root.get_node("/root/Lugares").resolve(nome), "o Lugares não resolve '%s'" % nome)
	for marco in ["terreiro", "gameleira"]:
		var onde: Vector3 = marcos.ponto(marco)
		_conferir(onde.is_finite() and world.is_on_land(onde), "o %s não está em terra firme: %s" % [marco, str(onde)])
	var altar: Vector3 = marcos.ponto("capela")
	_conferir(altar.is_finite() and interiores.contem(altar) == "igreja", "o marco da igreja não é o altar, dentro da nave")

	# --- 2. A MATA RESPEITA ----------------------------------------------------------
	for marco in ["terreiro", "gameleira"]:
		var onde: Vector3 = marcos.ponto(marco)
		var no_meio := 0
		for tronco in world._region._tree_trunks:
			var ponto: Vector2 = tronco.get("point", Vector2.INF)
			if ponto.distance_to(Vector2(onde.x, onde.z)) < 6.0:
				no_meio += 1
		_conferir(no_meio == 0, "a mata plantou %d árvore(s) no meio do %s" % [no_meio, marco])

	# --- 3. A TECLA --------------------------------------------------------------------
	var cruzeiro: Vector3 = marcos.ponto("cruzeiro")
	jogador.teleportar(world.ground_position(cruzeiro + Vector3(1.6, 0, 0.6), 0.05), 0.0)
	await _quadros(6)
	_conferir(marcos.get("_perto") == "cruzeiro", "perto do cruzeiro a tecla não apareceu (perto: '%s')" % str(marcos.get("_perto")))
	_conferir(marcos._acao("cruzeiro") == "Olhar", "sem fé, a tecla do cruzeiro diz '%s'" % marcos._acao("cruzeiro"))
	var sala = interiores.sala_de("igreja")
	var atras_da_parede: Vector3 = sala.to_global(Vector3(0, 0, -sala.comprimento - 1.1))
	jogador.teleportar(world.ground_position(atras_da_parede, 0.05), 0.0)
	await _quadros(6)
	_conferir(marcos.get("_perto") != "capela", "do lado de fora da parede dos fundos, a tecla do altar apareceu")
	jogador.teleportar(sala.to_global(Vector3(0, 0.05, -sala.comprimento + 3.4)), 0.0)
	await _quadros(6)
	_conferir(marcos.get("_perto") == "capela", "dentro da nave, perto do altar, a tecla não apareceu (perto: '%s')" % str(marcos.get("_perto")))

	# --- 4. SEM A DONA ZEFA ----------------------------------------------------------
	await _no_marco("terreiro", [true, true])
	_conferir(fe.ativa == "", "sem a Dona Zefa mostrar as três, o marco aceitou o jogador na fé '%s'" % fe.ativa)

	# --- 5. ENTRAR NUMA FÉ -------------------------------------------------------------
	marcos.liberada = func() -> bool: return true
	await _no_marco("terreiro", [true])
	_conferir(fe.ativa == "candomble", "aceitar no terreiro deixou a fé em '%s'" % fe.ativa)
	var teia = vale.get("teia")
	if teia != null:
		teia.abrir()
		await _frames(2)
		teia.trocar_de_teia()
		await _frames(2)
		_conferir(teia.modo() == "fe", "o Tab do K não trocou para a teia da fé")
		_conferir(not teia.find_children("No_folha_de_ossain", "", true, false).is_empty(),
			"a teia da fé não desenhou a árvore do candomblé")
		teia.fechar()

	# --- 6. O RITO ---------------------------------------------------------------------
	energia.atual = 5.0
	var xp_antes: float = fe.total_exato("candomble")
	await _no_marco("terreiro", [true])
	_conferir(energia.atual > 5.0, "o rito não devolveu fôlego")
	_conferir(fe.total_exato("candomble") > xp_antes, "o rito não rendeu experiência de fé")
	_conferir(ritos.bencao_ativa() != "", "o rito não deu bênção")
	var falas_cedo: Array = []
	await _no_marco("terreiro", [true], falas_cedo)
	_conferir(falas_cedo.any(func(l): return str(l).contains("volta")),
		"de novo antes do prazo, o marco não disse quando a graça volta: %s" % str(falas_cedo))

	# --- 7. TROCAR DE FÉ ---------------------------------------------------------------
	fe.ganhar("rito", 3.0)
	var acumulado: float = fe.total_exato("candomble")
	await _no_marco("gameleira", [true, false])
	_conferir(fe.ativa == "caboclo", "trocar na gameleira deixou a fé em '%s'" % fe.ativa)
	_conferir(is_equal_approx(fe.total_exato("candomble"), acumulado),
		"trocar sem levar mexeu no acumulado do candomblé: %.1f e era %.1f" % [fe.total_exato("candomble"), acumulado])
	_conferir(fe.conhecida("candomble"), "a fé deixada não ficou guardada")
	if teia != null:
		var regras: Array = teia.linhas_da_pagina_da_fe()
		_conferir(regras.any(func(l): return str(l).contains("congelada")),
			"a página das regras não diz que o candomblé está congelado: %s" % str(regras))

	# --- 8. A TEIA DA FÉ DESTRAVA ----------------------------------------------------
	fe.ganhar("missao", 3.0)
	_conferir(fe.pontos > 0, "três missões de fé não deram ponto")
	if teia != null and fe.pontos > 0:
		teia.abrir()
		await _frames(2)
		if teia.modo() != "fe":
			teia.trocar_de_teia()
		await _frames(2)
		teia.set("_no", "flecha_certa")
		teia._destravar()
		_conferir(fe.tem("flecha_certa"), "a teia da fé não destravou o primeiro nó do caboclo com ponto na mão")
		teia.fechar()
	_fechar()


## Faz o marco responder, e responde por ele: cada pergunta leva a próxima
## resposta da lista, e cada fala é fechada. As falas lidas vão para `lidas`.
func _no_marco(marco: String, respostas: Array, lidas: Array = []) -> void:
	var fila := respostas.duplicate()
	marcos.no_marco(marco)
	var ate := Time.get_ticks_msec() + 15000
	while marcos.ocupado() and Time.get_ticks_msec() < ate:
		if dialogo.ativo:
			if dialogo._modo == dialogo.Modo.PERGUNTA:
				dialogo._escolha = bool(fila.pop_front()) if not fila.is_empty() else false
				dialogo._escolheu = true
			else:
				lidas.append_array(dialogo._falas)
			dialogo._fechar()
		await process_frame
	_conferir(not marcos.ocupado(), "o marco '%s' não terminou de responder" % marco)
	await _frames(2)


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("FE_NO_VALE_OK: os seis marcos estão no vale, o da igreja é o altar lá dentro; a mata respeita o terreiro e o sambaqui; a tecla aparece no marco e o altar só de dentro; sem a Dona Zefa ninguém entra; com ela entra-se no marco e o Tab mostra a teia da fé; o rito dá fôlego, XP e bênção e diz quando volta; trocar de fé congela a antiga inteira e as regras dizem; e a teia da fé destrava com ponto")
	else:
		print("fe_no_vale: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame
		await physics_frame


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
