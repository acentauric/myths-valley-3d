extends SceneTree
## A FOGUEIRA E A BANCADA DO ROÇADO: sólidas, e a bancada se usa com o E.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/rocado.gd
##
## Do playtest de 05/10/2026:
##
##   "Estou dentro da fogueira como mostra no print. Preciso que você coloque a
##    área de colisão."
##   "Não consegui progredir nas missões porque a bancada não tem asset e não
##    consegui interagir."
##
## Quatro perguntas, no estilo deste portão (`rocado_procedural.gd` faz o outro):
##
##   1. AS DUAS FOGUEIRAS SÃO SÓLIDAS: a do terreiro da casa e a do terreiro de
##      santo têm corpo no meio das toras.
##   2. A BANCADA DA OFICINA TEM PEÇA E CORPO: no Tripo é a peça do catálogo, e
##      não a caixa cinza; nos dois estilos, o corpo não passa por ela.
##   3. O E NA BANCADA ABRE A OFICINA, com a dica da tecla em cima dela, e o E na
##      fogueira abre o fogão.
##   4. LONGE DAS DUAS, o E não abre nada.

var falhas := 0


func _estilo_do_portao() -> String:
	return "tripo"


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("ROCADO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	root.get_node("/root/Estilo").modo = _estilo_do_portao()
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	var vale = current_scene
	var world = vale.world
	var jogador = vale.player
	var painel = vale.painel
	var tecla = vale.get("tecla_das_bancadas")
	_conferir(tecla != null, "o vale não montou o E das bancadas")
	if tecla == null:
		_fechar()
		return
	await physics_frame
	await physics_frame
	var espaco: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state

	# --- 1. AS DUAS FOGUEIRAS SÃO SÓLIDAS ------------------------------------
	var fogueiras: Array = [world.ancoras.get("Fogueira", Vector3.INF)]
	var do_terreiro = world.get("_fogo_do_terreiro")
	if is_instance_valid(do_terreiro):
		fogueiras.append((do_terreiro as Node3D).global_position)
	_conferir(fogueiras.size() == 2, "não achei as duas fogueiras (a da casa e a do terreiro de santo)")
	for onde: Vector3 in fogueiras:
		if not onde.is_finite():
			_conferir(false, "uma fogueira não tem lugar no vale")
			continue
		var corpos := _corpos_em(espaco, onde + Vector3.UP * 0.3, 0.25)
		_conferir(not corpos.is_empty(), "a fogueira em %s não tem corpo: o jogador entra no meio das toras" % str(onde.snapped(Vector3.ONE * 0.1)))

	# --- 2. A BANCADA DA OFICINA TEM PEÇA E CORPO ----------------------------
	var bancada: Node3D = vale.get_node_or_null("Bancada_oficina")
	_conferir(bancada != null, "a bancada da oficina não está no vale")
	if bancada == null:
		_fechar()
		return
	if _estilo_do_portao() == "tripo":
		_conferir(bancada.has_meta("limites"), "no estilo Tripo a bancada é a caixa cinza, e não a peça do catálogo")
	var no_meio: Vector3 = load("res://scripts/prototipo_3d/bancadas_vale.gd").ponto_da_provisoria(world, "oficina")
	_conferir(not _corpos_em(espaco, no_meio + Vector3.UP * 0.4, 0.2).is_empty(),
		"a bancada não tem corpo: o jogador passa por dentro dela")

	# --- 3. O E NA BANCADA ABRE A OFICINA, E NA FOGUEIRA O FOGÃO ------------
	await _ir(jogador, world, no_meio + Vector3(1.4, 0.0, 0.0))
	_conferir(tecla.perto() == "oficina", "ao lado da bancada, o E não é da oficina: '%s'" % tecla.perto())
	_conferir(tecla.get("_dica").visible, "ao lado da bancada, a dica da tecla não aparece")
	await _apertar_e()
	_conferir(painel.aberto, "o E na bancada não abriu o painel")
	if painel.aberto:
		_conferir(painel.aba() == painel.Aba.OFICINA, "o E na bancada abriu o painel na aba %d, e não na Oficina" % painel.aba())
		vale.telas.abrir("painel")
		await _quadros(3)
	var fogo: Vector3 = world.ancoras.get("Fogueira", Vector3.INF)
	await _ir(jogador, world, fogo + Vector3(1.5, 0.0, 0.0))
	_conferir(tecla.perto() == "cozinha", "ao lado da fogueira, o E não é do fogão: '%s'" % tecla.perto())
	await _apertar_e()
	_conferir(painel.aberto and painel.aba() == painel.Aba.COZINHA, "o E na fogueira não abriu o fogão")
	if painel.aberto:
		vale.telas.abrir("painel")
		await _quadros(3)

	# --- 4. LONGE DAS DUAS, O E NÃO ABRE NADA -------------------------------
	await _ir(jogador, world, no_meio + Vector3(9.0, 0.0, 9.0))
	_conferir(tecla.perto() == "", "longe das bancadas o E ainda diz '%s'" % tecla.perto())
	await _apertar_e()
	_conferir(not painel.aberto, "longe das bancadas o E abriu o painel")
	_fechar()


func _corpos_em(espaco: PhysicsDirectSpaceState3D, onde: Vector3, raio: float) -> Array:
	var consulta := PhysicsShapeQueryParameters3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = raio
	consulta.shape = esfera
	consulta.transform = Transform3D(Basis(), onde)
	var nomes: Array = []
	for achado in espaco.intersect_shape(consulta, 8):
		var quem: Object = achado["collider"]
		# O chão não conta: a pergunta é se há coisa EM CIMA dele.
		if quem is Node and not str((quem as Node).name).begins_with("Colisão da terra"):
			nomes.append(str((quem as Node).name))
	return nomes


## Põe o jogador no chão, ali, como os portões põem (`teleportar`).
func _ir(jogador, world, onde: Vector3) -> void:
	jogador.teleportar(world.ground_position(onde, 0.07), 0.0)
	await physics_frame
	await physics_frame
	await _quadros(3)


func _apertar_e() -> void:
	var atalhos = load("res://scripts/prototipo_3d/atalhos.gd")
	var tecla := InputEventKey.new()
	tecla.physical_keycode = atalhos.tecla("interagir")
	tecla.keycode = tecla.physical_keycode
	tecla.pressed = true
	root.push_input(tecla)
	var solta := tecla.duplicate() as InputEventKey
	solta.pressed = false
	root.push_input(solta)
	await _quadros(4)


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("ROCADO_OK (%s): as duas fogueiras e a bancada da oficina são sólidas, a bancada é peça e não caixa no Tripo, o E ao lado dela abre a Oficina com a dica em cima, o E na fogueira abre o fogão, e longe das duas o E não abre nada" % _estilo_do_portao())
	else:
		print("rocado (%s): %d falha(s)" % [_estilo_do_portao(), falhas])
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
