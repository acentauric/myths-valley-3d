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
		print("MOVEIS_OK: todo móvel no chão dos cômodos — cama, baú, mesa, banco, cantareira, fogão, barril, cesto, os bancos e a pia da igreja — é sólido dos quatro lados, na medida da caixa desenhada dele")
	else:
		print("moveis: %d falha(s)" % falhas)
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
