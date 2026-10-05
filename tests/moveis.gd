extends SceneTree
## Confere que TODO MÓVEL DOS CÔMODOS É SÓLIDO NA MEDIDA DELE.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/moveis.gd
##
## "Revise a área de colisão de todos os móveis." Na casa herdada só a cama e o
## baú tinham corpo, com a medida escrita à mão; a mesa, o fogão, o barril, a
## cantareira não tinham nenhum, e o jogador passava por dentro deles. Na igreja,
## o banco tinha uma caixa de comprimento fixo.
##
## A pergunta é feita sem perguntar ao cômodo quais móveis ele tem: toda peça do
## catálogo posta dentro de cada cômodo (o nó com a marca `limites`), que está no
## chão e não é miudeza, leva raios deitados dos quatro lados, a um terço da
## altura dela, rumo ao meio — e cada raio tem de bater num corpo antes de
## entrar meio palmo na caixa desenhada dela.

var falhas := 0
## Miudeza (moringa, candeeiro) e o que mora em cima de outro móvel não contam.
const MENOR_PECA := 0.25
const NO_CHAO := 0.3


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("MOVEIS_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	var vale = current_scene
	var interiores = vale.get("interiores")
	_conferir(interiores != null, "o vale não tem cômodos")
	if interiores == null:
		_fechar()
		return
	await physics_frame
	await physics_frame

	# --- A CASA DO JOGADOR COMEÇA COM O BÁSICO, E AS OBRAS PÕEM O RESTO --------
	#
	# "Não precisa ter tudo no início, apenas o básico. Cada expansão e melhoria
	# deve dar XP ao jogador e melhorar atributos do personagem." (05/10/2026)
	var casa = interiores.sala_de("casa")
	_conferir(casa != null, "a casa do jogador não abriu por dentro")
	if casa != null:
		var no_comeco := _chaves(casa)
		for basico in ["cama", "bau", "pote"]:
			_conferir(no_comeco.has(basico), "a casa começa sem '%s', que é do básico: %s" % [basico, str(no_comeco.keys())])
		for de_obra in ["mesa", "banco_tosco", "oratorio", "jirau", "fogao_barro", "barril", "cantareira"]:
			_conferir(not no_comeco.has(de_obra), "a casa já começa com '%s', que é de obra: %s" % [de_obra, str(no_comeco.keys())])
		var obras := root.get_node("/root/Obras")
		var receitas := root.get_node("/root/Receitas")
		var inventario := root.get_node("/root/Inventario")
		var progressao := root.get_node("/root/Progressao")
		var talentos := root.get_node("/root/Talentos")
		# UMA OBRA FEITA PELO JOGADOR: a estante, com o material na mochila.
		if not receitas.sabe("mobilia_guardado"):
			receitas.aprender("mobilia_guardado")
		var custo: Dictionary = obras.custo("mobilia_guardado")
		for item in custo:
			inventario.adicionar(str(item), int(custo[item]))
		var ganhou := [0.0]
		talentos.ganhou_xp.connect(func(quanto: float) -> void: ganhou[0] += quanto)
		var teto_antes: float = progressao.energia_maxima
		var impedimento: String = obras.impedimento("casa", "mobilia_guardado")
		_conferir(impedimento == "", "a estante não pode ser feita com plano e material: '%s'" % impedimento)
		# Pelo mesmo caminho do E na aba de obras (`painel_vale._confirmar`): o
		# `executar` compartilhado dá o XP, e o painel paga o atributo.
		_conferir(obras.executar("casa", "mobilia_guardado"), "a estante não se fez")
		vale.painel.pagar_o_que_a_obra_da("mobilia_guardado")
		await _quadros(3)
		_conferir(ganhou[0] > 0.0, "a estante feita não deu XP")
		_conferir(progressao.energia_maxima > teto_antes, "a estante feita não melhorou o atributo (fôlego máximo %s)" % str(progressao.energia_maxima))
		_conferir(_chaves(casa).has("jirau"), "a estante feita não apareceu na casa: %s" % str(_chaves(casa).keys()))
		# As outras obras de mobília, dadas de presente, para conferir que cabem
		# sem fechar a porta e que são sólidas (o laço de baixo as mede).
		for obra in ["mobilia_mesa_grande", "mobilia_altar", "mobilia_cozinha"]:
			obras.conceder("casa", obra)
		await _quadros(3)
		await physics_frame
		await physics_frame
		var com_obras := _chaves(casa)
		for peca in ["mesa", "banco_tosco", "oratorio", "fogao_barro"]:
			_conferir(com_obras.has(peca), "com a obra feita, '%s' não apareceu na casa: %s" % [peca, str(com_obras.keys())])
		_conferir(com_obras.has("cama") and com_obras.has("bau"), "refazer os móveis perdeu a cama ou o baú: %s" % str(com_obras.keys()))

	# --- A PORTA DE TODA CASA FICA LIVRE ---------------------------------------
	#
	# "Os móveis ficaram na porta para entrar na casa." Nenhum móvel de chão toma
	# o vão da porta, da fachada até ENTRADA para dentro.
	for qual in interiores.CONSTRUCOES:
		var sala = interiores.sala_de(qual)
		if sala == null or not str(qual).begins_with("casa"):
			continue
		var vao := Rect2(sala.porta_x - sala.largura_da_porta * 0.5, -sala.ENTRADA, sala.largura_da_porta, sala.ENTRADA)
		for movel: Dictionary in sala._moveis:
			if not is_instance_valid(movel.get("peca")):
				continue
			var caixa: AABB = sala.caixa_no_comodo(movel["peca"])
			if caixa.position.y >= sala.NA_PAREDE:
				continue
			_conferir(not Rect2(caixa.position.x, caixa.position.z, caixa.size.x, caixa.size.z).intersects(vao),
				"em '%s', '%s' fica na frente da porta: x [%.2f, %.2f], z [%.2f, %.2f]" % [qual, str(movel.get("nome", "?")),
					caixa.position.x, caixa.end.x, caixa.position.z, caixa.end.z])

	var conferidos := 0
	for qual in interiores.CONSTRUCOES:
		var sala = interiores.sala_de(qual)
		if sala == null:
			continue
		var espaco: PhysicsDirectSpaceState3D = sala.get_world_3d().direct_space_state
		for no in sala.find_children("*", "Node3D", true, false):
			# A peça do catálogo leva a marca `limites` (CatalogoAssets.instanciar):
			# pelo nome não dá, que irmãos de mesmo nome viram "@Node3D@N".
			var peca := no as Node3D
			if peca == null or not peca.has_meta("limites"):
				continue
			var caixa: AABB = sala.caixa_no_comodo(peca)
			if maxf(caixa.size.x, caixa.size.z) < MENOR_PECA or caixa.position.y > NO_CHAO:
				continue
			conferidos += 1
			var altura := caixa.position.y + maxf(caixa.size.y / 3.0, 0.15)
			var meio := caixa.get_center()
			for lado: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
				var face := absf(caixa.size.dot(lado)) * 0.5
				var de := Vector3(meio.x, altura, meio.z) + lado * (face + 0.8)
				var ate := Vector3(meio.x, altura, meio.z)
				var pergunta := PhysicsRayQueryParameters3D.create(sala.to_global(de), sala.to_global(ate), 1)
				var toque := espaco.intersect_ray(pergunta)
				var entrou := INF
				if not toque.is_empty():
					entrou = face - (sala.to_local(toque["position"]) - ate).dot(lado)
				_conferir(entrou < 0.15, "em '%s', o raio pelo lado %s atravessa '%s' (entra %.2f na caixa desenhada)" % [qual, str(lado), peca.name, entrou])
			print("  %s: %s, caixa %s" % [qual, peca.name, str(caixa.size)])
	_conferir(conferidos >= 6, "só %d móveis no chão para conferir: os cômodos estão vazios?" % conferidos)
	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("MOVEIS_OK: a casa do jogador começa com o básico (cama, baú e água) e a obra feita põe o móvel, dá XP e melhora o atributo; nenhum móvel toma a porta das casas; e todo móvel no chão dos cômodos — cama, baú, mesa, banco, cantareira, fogão, barril, cesto, os bancos e a pia da igreja — é sólido dos quatro lados, na medida da caixa desenhada dele")
	else:
		print("moveis: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


## As peças do catálogo postas no cômodo, pela chave delas.
func _chaves(sala: Node) -> Dictionary:
	var chaves := {}
	for no in sala.find_children("*", "Node3D", true, false):
		if is_instance_valid(no) and not no.is_queued_for_deletion() and no.has_meta("chave"):
			chaves[str(no.get_meta("chave"))] = true
	return chaves


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
