extends "res://tests/suite/caso.gd"
## AS CERCAS ACOMPANHAM O CHÃO (#93).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste cercas_na_encosta
##
## Cada lance de cerca era assentado por uma amostra do terreno no centro dele,
## e na encosta uma ponta flutuava e a outra se enterrava — "cercas desniveladas
## por todo o vale" (autor, 06/10). Agora todo lance vai de ponta a ponta no
## chão, deitado na encosta (`CatalogoAssets.lance_de_cerca`,
## `PaisagismoVale.plantar_cercas`), e a caixa de colisão vai junto.
##
## A medida é sempre a mesma: as duas pontas de baixo do lance — da caixa de
## colisão, ou da malha plantada — ficam a menos de FOLGA do chão ali.
##
##   1. O CERCADO DO CEMITÉRIO: a obra feita levanta os lances (`Obras.conceder`
##      → `cemiterio_vale.acertar`); cada um com as pontas no chão.
##   2. AS CERCAS DA PONTE DO RIO GRANDE, nas duas cabeceiras: idem.
##   3. AS CERCAS DO QUINTAL DO ROÇADO: idem.
##   4. AS CERCAS DE VARAS DAS ROÇAS, em MultiMesh: a região guarda as
##      transformações que plantou (o renderizador vazio não as devolve); são
##      tantas quantos os adereços `cerca_varas` do plano, pelo menos trinta,
##      e cada malha tem as pontas de baixo no chão.
##   5. HÁ ENCOSTA: ao menos um lance do vale tem desnível entre as pontas
##      maior que a FOLGA — senão o portão não prova nada.

const CatalogoAssets := preload("res://scripts/prototipo_3d/catalogo_assets.gd")

const FOLGA := 0.1
const MINIMO_DE_CERCAS_DE_VARAS := 30

var falhas := 0
## O maior desnível entre pontas visto em todo o vale (ponto 5).
var _maior_desnivel := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("CERCAS_NA_ENCOSTA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	var vale = current_scene
	var mundo = vale.world
	var obras = root.get_node("/root/Obras")

	# --- 1. O CERCADO DO CEMITÉRIO -------------------------------------------------
	var cemiterio := get_first_node_in_group("cemiterio")
	_conferir(cemiterio != null, "o vale não tem o cemiterio_vale")
	if cemiterio != null:
		obras.conceder("cemiterio", "cemiterio_cercado")
		await _quadros(2)
		_conferir(cemiterio.cercado_de_pe(), "a obra do cercado foi dada e o cercado não subiu")
		var lances := _lances_chamados(cemiterio, "Lance")
		_conferir(lances.size() >= 20, "o cercado do cemitério tem %d lance(s)" % lances.size())
		_medir_os_lances("cemitério", lances, mundo)

	# --- 2. AS CERCAS DA PONTE -----------------------------------------------------
	var ponte := get_first_node_in_group("ponte_do_rio")
	_conferir(ponte != null, "o vale não tem a ponte_vale")
	if ponte != null:
		_conferir(ponte.interditada(), "a ponte do rio grande começa sem cerca")
		var cercas := _lances_chamados(ponte, "CercaDaPonte")
		_conferir(cercas.size() == 2, "a ponte tem %d cerca(s), e são duas cabeceiras" % cercas.size())
		_medir_os_lances("ponte", cercas, mundo)

	# --- 3. AS CERCAS DO QUINTAL ---------------------------------------------------
	var quintal := _lances_chamados(mundo, "CercaDoQuintal")
	_conferir(quintal.size() >= 2, "o quintal do roçado tem %d lance(s) de cerca, e são ao menos dois" % quintal.size())
	_medir_os_lances("quintal", quintal, mundo)

	# --- 4. AS CERCAS DE VARAS DAS ROÇAS ---------------------------------------------
	var regiao: Node3D = mundo._region
	var plantadas: Array = regiao.get_meta("cercas_cerca_varas", [])
	var no_plano := 0
	var lances_do_plano: Array[Dictionary] = []
	for item: Dictionary in mundo.paisagismo_aderecos:
		if String(item["chave"]) == "cerca_varas":
			no_plano += 1
			lances_do_plano.append(item)
	_conferir(no_plano >= MINIMO_DE_CERCAS_DE_VARAS, "o plano tem %d cerca(s) de varas, e são ao menos %d" % [no_plano, MINIMO_DE_CERCAS_DE_VARAS])
	_conferir(plantadas.size() == no_plano, "a região guarda %d cerca(s) de varas plantadas e o plano tem %d" % [plantadas.size(), no_plano])
	var modelo: Dictionary = CatalogoAssets.malha("cerca_varas", 1.0)
	_conferir(not modelo.is_empty(), "o catálogo não tem a malha da cerca de varas")
	if not modelo.is_empty() and not plantadas.is_empty():
		var base: Transform3D = modelo.base
		# A caixa da malha já no quadro do catálogo: centrada em X e Z, pé em y = 0,
		# comprida no X — as pontas são o meio das faces de baixo em cada extremo.
		var caixa: AABB = base * (modelo.mesh as Mesh).get_aabb()
		var pontas_locais := [
			Vector3(caixa.position.x, caixa.position.y, caixa.get_center().z),
			Vector3(caixa.end.x, caixa.position.y, caixa.get_center().z)]
		var pior := 0.0
		var tortas := 0
		for indice in plantadas.size():
			var plantada: Transform3D = plantadas[indice]
			var lance: Transform3D = plantada * base.affine_inverse()
			if indice == 0 and "--lance-curto" in OS.get_cmdline_user_args():
				lance.basis.x *= 0.5
			var folgas: Array[float] = []
			var pes: Array[Vector3] = []
			for ponta: Vector3 in pontas_locais:
				var pe: Vector3 = lance * ponta
				pes.append(pe)
				folgas.append(pe.y - float(mundo.ground_height_at(pe)))
			if indice < lances_do_plano.size():
				var item: Dictionary = lances_do_plano[indice]
				_conferir(item.has("de") and item.has("ate"), "o plano conserva as extremidades da cerca")
				if item.has("de") and item.has("ate"):
					_conferir(Vector2(pes[0].x, pes[0].z).distance_to(item.de) < FOLGA and
						Vector2(pes[1].x, pes[1].z).distance_to(item.ate) < FOLGA,
						"a malha %d une as extremidades reais do terreno" % indice)
			_anotar_o_desnivel(pes[0], pes[1], mundo)
			var folga := maxf(absf(folgas[0]), absf(folgas[1]))
			pior = maxf(pior, folga)
			if folga > FOLGA:
				tortas += 1
		print("  cercas de varas: %d; a pior ponta fica a %.2f u do chão" % [plantadas.size(), pior])
		_conferir(tortas == 0, "%d cerca(s) de varas com ponta a mais de %.2f u do chão (a pior: %.2f)" % [tortas, FOLGA, pior])

	# --- 5. HÁ ENCOSTA -------------------------------------------------------------------
	print("  o maior desnível entre pontas de um lance: %.2f u" % _maior_desnivel)
	_conferir(_maior_desnivel > FOLGA, "nenhum lance do vale está em encosta (desnível máximo %.2f): o portão não prova nada" % _maior_desnivel)

	# --- 6. AS CERCAS DE VARAS TÊM CORPO (#104) --------------------------------------------
	# Nasceram sem colisão; agora cada lance tem a caixa dele, assentada no lance,
	# na camada das cercas, que o jogador vê, e na camada do mundo, que a malha dos
	# moradores lê (#125) — e fora da camada da câmera.
	var corpos: Node = regiao.get_node_or_null("CorposDasCercas_cerca_varas")
	var quantos_corpos := corpos.get_child_count() if corpos != null else 0
	_conferir(corpos != null and quantos_corpos == plantadas.size(), "as cercas de varas têm %d corpo(s) para %d lance(s)" % [quantos_corpos, plantadas.size()])
	if corpos != null and quantos_corpos > 0 and not plantadas.is_empty() and not modelo.is_empty():
		var corpo: StaticBody3D = corpos.get_child(0)
		var forma := corpo.get_child(0) as CollisionShape3D
		var caixa_do_corpo := forma.shape as BoxShape3D
		var pe: Vector3 = corpo.global_transform * Vector3(0.0, -caixa_do_corpo.size.y * 0.5, 0.0)
		var primeiro: Transform3D = (plantadas[0] as Transform3D) * (modelo.base as Transform3D).affine_inverse()
		_conferir(pe.distance_to(primeiro.origin) < 0.05, "o corpo da primeira cerca de varas não assenta no lance (%.2f u)" % pe.distance_to(primeiro.origin))
		_conferir((corpo.collision_layer & (1 << 3)) != 0 and (corpo.collision_layer & 1) != 0 and (corpo.collision_layer & (1 << 13)) == 0,
			"o corpo da cerca de varas não está nas camadas das cercas e do mundo, fora da câmera (camada %d): o jogador ou os moradores a atravessariam, ou ela barraria a câmera" % corpo.collision_layer)
		_conferir((vale.player.collision_mask & (1 << 3)) != 0, "o corpo do jogador não vê a camada das cercas")
	_fechar()


## Os lances de cerca chamados `nome` debaixo de `pai`: pelo grupo
## "lances_de_cerca" e pela meta "lance" que `CatalogoAssets.lance_de_cerca`
## põe — o nome do nó não serve, porque irmãos de mesmo nome o Godot renomeia
## ("@Node3D@2038").
func _lances_chamados(pai: Node, nome: String) -> Array[Node3D]:
	var lista: Array[Node3D] = []
	for no in get_nodes_in_group("lances_de_cerca"):
		if String((no as Node).get_meta("lance", "")) == nome and pai.is_ancestor_of(no as Node):
			lista.append(no as Node3D)
	return lista


## As duas pontas de baixo da caixa de colisão de cada lance, contra o chão.
func _medir_os_lances(rotulo: String, lances: Array[Node3D], mundo) -> void:
	var pior := 0.0
	var tortos := 0
	var sem_caixa := 0
	for lance in lances:
		var forma: CollisionShape3D = null
		for candidata in lance.find_children("*", "CollisionShape3D", true, false):
			if (candidata as CollisionShape3D).shape is BoxShape3D:
				forma = candidata as CollisionShape3D
				break
		if forma == null:
			sem_caixa += 1
			continue
		var caixa := forma.shape as BoxShape3D
		var folgas: Array[float] = []
		var pes: Array[Vector3] = []
		for sinal: float in [-1.0, 1.0]:
			var pe: Vector3 = forma.global_transform * Vector3(sinal * caixa.size.x * 0.5, -caixa.size.y * 0.5, 0.0)
			pes.append(pe)
			folgas.append(pe.y - float(mundo.ground_height_at(pe)))
		_anotar_o_desnivel(pes[0], pes[1], mundo)
		var folga := maxf(absf(folgas[0]), absf(folgas[1]))
		pior = maxf(pior, folga)
		if folga > FOLGA:
			tortos += 1
	print("  %s: %d lance(s); a pior ponta fica a %.2f u do chão" % [rotulo, lances.size(), pior])
	_conferir(sem_caixa == 0, "%s: %d lance(s) sem caixa de colisão" % [rotulo, sem_caixa])
	_conferir(tortos == 0, "%s: %d lance(s) com ponta a mais de %.2f u do chão (a pior: %.2f)" % [rotulo, tortos, FOLGA, pior])


## O desnível do CHÃO entre as duas pontas (ponto 5): é do terreno, não do lance.
func _anotar_o_desnivel(a: Vector3, b: Vector3, mundo) -> void:
	_maior_desnivel = maxf(_maior_desnivel, absf(float(mundo.ground_height_at(a)) - float(mundo.ground_height_at(b))))


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("CERCAS_NA_ENCOSTA_OK: todo lance de cerca do vale — cemitério, ponte, quintal e roças — tem as duas pontas no chão, com a colisão junto, e há encosta para provar")
	else:
		print("cercas_na_encosta: %d falha(s)" % falhas)
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
