extends "res://tests/suite/caso.gd"
## Confere que A ÁRVORE BARRA O CORPO NO PEITO E DEIXA A COPA PASSAR (#150).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste arvores_barram_o_corpo
##
## `colisao_das_arvores` pergunta ONDE o cilindro está; este pergunta o que o
## jogador sente: com a cápsula do jogador (os mesmos 0,28 de raio), varrida de
## um lado ao outro do tronco ao nível do peito, ela PARA na borda do cilindro
## mais o corpo e n�o entra na madeira; varrida acima do cilindro, onde s� h�
## folhagem, ela PASSA. Uma espécie por vez, no vale montado, com o conjunto de
## cilindros acordado junto do jogador (a física dele fica parada: o que se
## mede � a geometria, n�o a caminhada). Pedra, casa ou outra �rvore que
## barrem um dos lados n�o contam como o cilindro medido; � preciso que ao
## menos um lado seja barrado por um cilindro de árvore.
##
## FALSIFICA��O: `-- --falsificar=copa` estica os cilindros at� acima da cabe�a
## (a copa passa a barrar) e `-- --falsificar=sem_corpo` tira os cilindros da
## camada de colis�o (o tronco passa a ser atravessado). Os dois t�m de
## reprovar.

const CORPO_RAIO := 0.28
## Quanto a parada pode fugir de (raio do cilindro + corpo).
const FOLGA := 0.12
## Onde a varredura começa, de cada lado do eixo, e o quanto ela anda.
const ARRANQUE := 1.2
## Acima disto o tronco é torto (o coqueiro da orla): mede-se só que o cilindro barra.
const INCLINACAO_MAXIMA_GRAUS := 10.0

var falhas := 0
var falsificar := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--falsificar="):
			falsificar = arg.substr("--falsificar=".length())
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("ARVORES_BARRAM_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK,
		"a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(8)

	var jogo := current_scene
	var world = jogo.get("world")
	var jogador = jogo.get("player")
	var regiao = world._region
	if regiao == null or (regiao._tree_trunks as Array).is_empty():
		_conferir(false, "o vale n�o tem tronco nenhum registrado")
		_fechar()
		return
	var altura_do_corpo: float = jogador.character_height

	# De cada espécie, o tronco mais em pé: o coqueiro da orla nasce torto (#orla,
	# `base_tronco`/`alto_tronco`), e o cilindro dele acompanha a inclinação.
	var por_especie: Dictionary = {}
	for t in regiao._tree_trunks:
		var especie := str(t.get("especie", "?"))
		if not por_especie.has(especie) or _inclinacao(t) < _inclinacao(por_especie[especie]):
			por_especie[especie] = t
	var nomes := por_especie.keys()
	nomes.sort()

	jogador.set_physics_process(false)
	var medidas := 0
	for especie in nomes:
		var tronco: Dictionary = por_especie[especie]
		var ponto: Vector2 = tronco["point"]
		var base_local := Vector3(ponto.x, float(tronco["ground"]), ponto.y)
		jogador.global_position = regiao.to_global(base_local) + Vector3(2.5, 0.5, 0.0)

		# Espera o conjunto acordar um cilindro neste tronco (ele se refaz a
		# cada 0,25 s), e ent�o o congela: a falsifica��o n�o pode ser desfeita.
		regiao.set_process(true)
		var slot_do_tronco = null
		for tentativa in range(240):
			await process_frame
			slot_do_tronco = _slot_perto(regiao, ponto)
			if slot_do_tronco != null and tentativa >= 20:
				break
		regiao.set_process(false)
		if slot_do_tronco == null:
			# O mangue e o bambu nascem em moita, e as vagas v�o aos mais
			# perto do jogador: a cobertura do conjunto é de colisao_das_arvores.
			print("  %-14s (sem vaga no conjunto: tronco em moita)" % especie)
			continue

		var corpo := slot_do_tronco.body as StaticBody3D
		var forma := slot_do_tronco.shape as CylinderShape3D
		var altura_real := forma.height
		var eixo_y := corpo.global_basis.y.normalized()
		var centro_antes := corpo.global_position

		if falsificar == "copa":
			for slot in regiao._tree_collision_pool:
				if slot.active:
					(slot.shape as CylinderShape3D).height = 9.0
					(slot.body as StaticBody3D).global_position += (slot.body as StaticBody3D).global_basis.y * 2.5
		elif falsificar == "sem_corpo":
			for slot in regiao._tree_collision_pool:
				if slot.active:
					(slot.body as StaticBody3D).collision_layer = 0
		await physics_frame
		await physics_frame
		await physics_frame

		var espaco: PhysicsDirectSpaceState3D = corpo.get_world_3d().direct_space_state

		# TRONCO TORTO: a cápsula em pé encosta no tronco inclinado com a cabeça
		# ou o pé antes de o peito chegar, e acima do cilindro ainda há tronco.
		# A distância no peito e a copa só se medem no tronco quase em pé; no
		# torto, cobra-se que um cilindro de árvore barre.
		var graus := rad_to_deg(eixo_y.angle_to(Vector3.UP))
		if graus > INCLINACAO_MAXIMA_GRAUS:
			# A varredura de lado começa dentro do tronco torto (ele passa por cima
			# do ponto de partida), e o cast_motion não conta o que já toca no
			# começo: aqui a pergunta é direta, a cápsula em pé no eixo toca o cilindro.
			var capsula := CapsuleShape3D.new()
			capsula.radius = CORPO_RAIO
			capsula.height = altura_do_corpo
			var consulta := PhysicsShapeQueryParameters3D.new()
			consulta.shape = capsula
			consulta.collision_mask = 1
			consulta.exclude = [(jogador as CollisionObject3D).get_rid()]
			consulta.transform = Transform3D(Basis.IDENTITY, centro_antes)
			var barrou := false
			for toque in espaco.intersect_shape(consulta, 16):
				if instance_from_id(int(toque.get("collider_id", 0))) == corpo:
					barrou = true
			_conferir(barrou, "em '%s' (tronco a %.0f°) o cilindro do tronco não barra a cápsula" % [especie, graus])
			medidas += 1
			print("  %-14s raio=%.2f altura=%.1f  tronco a %.0f°: %s" % [especie, forma.radius, altura_real, graus, "barra" if barrou else "NAO BARRA"])
			continue

		# --- PEITO: a cápsula varre os dois lados, atravessando o eixo --------
		var h_peito := altura_do_corpo * 0.5 + 0.15
		var no_eixo_peito := centro_antes + eixo_y * (h_peito - altura_real * 0.5)
		var barrada_por_cilindro := false
		var texto_peito := ""
		for lado in [1.0, -1.0]:
			var parada := _varrer(espaco, jogador, no_eixo_peito, altura_do_corpo, lado, ARRANQUE)
			if not parada.bloqueada:
				_conferir(false, "em '%s' a cápsula atravessa o tronco ao nível do peito (lado %+d)" % [especie, int(lado)])
				texto_peito += " ATRAVESSA"
				continue
			var slot_barrou = _melhor_slot(regiao, parada.donos, parada.posicao, h_peito)
			if slot_barrou == null:
				texto_peito += " (%s a %.2f)" % [str(parada.dono.get_path()) if parada.dono != null else "?", parada.distancia]
				continue
			barrada_por_cilindro = true
			# A parada, medida a partir do eixo DO CILINDRO que barrou.
			var dono := slot_barrou.body as StaticBody3D
			var raio_dono: float = (slot_barrou.shape as CylinderShape3D).radius
			var altura_dono: float = (slot_barrou.shape as CylinderShape3D).height
			var eixo_do_dono := dono.global_position + dono.global_basis.y * (h_peito - altura_dono * 0.5)
			var onde_parou: Vector3 = parada.posicao
			var dist := Vector2(onde_parou.x - eixo_do_dono.x, onde_parou.z - eixo_do_dono.z).length()
			var esperada := raio_dono + CORPO_RAIO
			texto_peito += " para a %.2f" % dist
			_conferir(dist >= esperada - FOLGA,
				"em '%s' a cápsula entra %.2f u na madeira (para a %.2f do eixo, o cilindro pede %.2f)"
				% [especie, esperada - dist, dist, esperada])
			_conferir(dist <= esperada + FOLGA,
				"em '%s' a c�psula para a %.2f do eixo e o cilindro pede %.2f: sobra v�o ou h� corpo fantasma"
				% [especie, dist, esperada])
		_conferir(barrada_por_cilindro,
			"em '%s' nenhum dos dois lados é barrado por um cilindro de árvore" % especie)

		# --- COPA: acima do cilindro, a cápsula passa ------------------------
		var h_copa := altura_real + 0.35 + altura_do_corpo * 0.5
		var no_eixo_copa := centro_antes + eixo_y * (h_copa - altura_real * 0.5)
		var alta := _varrer(espaco, jogador, no_eixo_copa, altura_do_corpo, 1.0, ARRANQUE)
		var copa_barrada: bool = alta.bloqueada and _melhor_slot(regiao, alta.donos, alta.posicao, h_copa) != null
		_conferir(not copa_barrada,
			"em '%s' um cilindro de árvore barra uma cápsula que passa acima de %.1f m: a copa bloqueia" % [especie, altura_real])
		medidas += 1
		print("  %-14s raio=%.2f altura=%.1f  peito:%s  copa: %s"
			% [especie, forma.radius, altura_real, texto_peito, "barra" if copa_barrada else "passa"])

	_conferir(medidas >= 8, "poucas esp�cies medidas (%d): o conjunto n�o acordou ao lado delas" % medidas)
	_fechar()


## O quanto o tronco se afasta da vertical, em graus (0 no tronco sem eixo próprio).
func _inclinacao(tronco: Dictionary) -> float:
	if not tronco.has("base_tronco") or not tronco.has("alto_tronco"):
		return 0.0
	var eixo: Vector3 = (tronco["alto_tronco"] as Vector3) - (tronco["base_tronco"] as Vector3)
	return rad_to_deg(eixo.angle_to(Vector3.UP)) if eixo.length_squared() > 0.0001 else 0.0


## A vaga do conjunto cujo cilindro est� no tronco `ponto` (referencial da regi�o).
func _slot_perto(regiao, ponto: Vector2):
	var melhor = null
	var menor := 0.6
	for slot in regiao._tree_collision_pool:
		if not slot.active:
			continue
		var corpo := slot.body as StaticBody3D
		var d := Vector2(corpo.position.x, corpo.position.z).distance_to(ponto)
		if d < menor:
			menor = d
			melhor = slot
	return melhor


## Entre os corpos que tocam a cápsula parada, o cilindro de árvore cuja borda
## mais combina com ela (numa moita, o que barrou pode ser um vizinho).
func _melhor_slot(regiao, donos: Array, onde: Vector3, altura: float):
	var melhor = null
	var menor := INF
	for slot in regiao._tree_collision_pool:
		if not slot.active or not donos.has(slot.body):
			continue
		var dono := slot.body as StaticBody3D
		var forma := slot.shape as CylinderShape3D
		var eixo := dono.global_position + dono.global_basis.y * (altura - forma.height * 0.5)
		var erro := absf(Vector2(onde.x - eixo.x, onde.z - eixo.z).length() - (forma.radius + CORPO_RAIO))
		if erro < menor:
			menor = erro
			melhor = slot
	return melhor


## Varre a cápsula do jogador, centrada em `centro`, de `arranque` de um lado do
## eixo até `arranque` do outro. Devolve se parou, onde, e quem a barrou.
func _varrer(espaco: PhysicsDirectSpaceState3D, jogador: Node, centro: Vector3, altura: float, lado: float, arranque: float) -> Dictionary:
	var capsula := CapsuleShape3D.new()
	capsula.radius = CORPO_RAIO
	capsula.height = altura
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = capsula
	consulta.collision_mask = 1
	consulta.exclude = [(jogador as CollisionObject3D).get_rid()]
	consulta.transform = Transform3D(Basis.IDENTITY, centro + Vector3(arranque * lado, 0.0, 0.0))
	consulta.motion = Vector3(-2.0 * arranque * lado, 0.0, 0.0)
	var seguro := float(espaco.cast_motion(consulta)[0])
	var parou := centro + Vector3((arranque - seguro * 2.0 * arranque) * lado, 0.0, 0.0)
	var resposta := {"bloqueada": seguro < 0.999, "distancia": arranque - seguro * 2.0 * arranque,
		"posicao": parou, "dono": null, "donos": []}
	if resposta.bloqueada:
		# Um passo adiante a cápsula já toca: o contato diz quem a barrou.
		consulta.motion = Vector3.ZERO
		consulta.transform = Transform3D(Basis.IDENTITY, parou + Vector3(-0.06 * lado, 0.0, 0.0))
		var toques := espaco.intersect_shape(consulta, 8)
		for toque in toques:
			var objeto := instance_from_id(int(toque.get("collider_id", 0)))
			resposta["donos"].append(objeto)
		if not toques.is_empty():
			resposta["dono"] = resposta["donos"][0]
	return resposta


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("ARVORES_BARRAM_OK: a cápsula do jogador para na borda do tronco, ao nível do peito, em toda espécie com cilindro ao lado, e passa por cima dele, onde só há copa")
	else:
		print("árvores que barram o corpo: %d falha(s)" % falhas)
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
