extends SceneTree
## A condução do convite precisa de malha até o portão, pátio e casarão.
## A área antiga acabava em z=-232: o caminho projetava o Pedro para trás
## e terminava 57 m antes do portão. A campanha não escreve estado por aqui.

var falhas := 0

func _initialize() -> void:
	rodar.call_deferred()

func conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		push_error("ROTA_FAZENDA_FALHOU: " + texto)

func rodar() -> void:
	if "--falsificar-juntas" in OS.get_cmdline_user_args():
		# Recurso em memória só deste processo: a quina importada volta a ser
		# o único apoio. Nenhum arquivo ou save da campanha é modificado.
		var catalogo: GDScript = load("res://scripts/prototipo_3d/catalogo_assets.gd")
		catalogo.source_code = catalogo.source_code.replace("\t\t\t_apoiar_tabuleiro(node, parent, origin, bounds, yaw)", "\t\t\tpass")
		conferir(catalogo.reload() == OK, "o mutante de juntas precisa compilar")
	# Pré-condição da jornada nesta fixture isolada; não toca o perfil da campanha.
	root.get_node("Obras").feitas = {"ponte": ["ponte_levantar"]}
	change_scene_to_file("res://scenes/prototipo_3d/vale.tscn")
	for i in range(5000):
		await process_frame
		if current_scene != null and current_scene.get("navegacao") != null and current_scene.navegacao.esta_pronta():
			break
	var vale = current_scene
	var nav = vale.navegacao
	conferir(nav.esta_pronta(), "a malha precisa ficar pronta")
	if "--falsificar-limites" in OS.get_cmdline_user_args():
		# Só a fixture reassada, com os limites antigos; a campanha fica intacta.
		var versao: int = nav.versao
		nav._malha.filter_baking_aabb = AABB(Vector3(-95, -3.12, -232.2496), Vector3(229.2514, 80, 392.2496))
		nav.reassar()
		for i in range(5000):
			await process_frame
			if nav.versao > versao:
				break
		await physics_frame
		await physics_frame
	var anterior := Vector3(115.5, 4.1, -251.0)
	for nome in ["Portão da fazenda", "Pátio da fazenda", "Casarão"]:
		var destino: Vector3 = vale.world.ancoras[nome]
		conferir(nav._malha.filter_baking_aabb.has_point(destino), "a área assada precisa conter " + nome)
		# Casarão é o centro sólido da construção; a missão chega ao pátio.
		if nome == "Casarão":
			continue
		var caminho: PackedVector3Array = nav.caminho(anterior, destino)
		conferir(not caminho.is_empty(), "precisa de caminho até " + nome)
		if not caminho.is_empty():
			print("ROTA_FAZENDA_PONTO: ", nome, " destino=", destino, " início=", caminho[0], " fim=", caminho[-1], " distância=", caminho[-1].distance_to(destino))
			conferir(caminho[-1].distance_to(destino) < 1.5, "o caminho termina junto de " + nome)
			conferir(caminho[0].distance_to(anterior) < 2.0, "a projeção não manda o guia de volta para longe")
		anterior = destino
	if "--falsificar-limites" not in OS.get_cmdline_user_args():
		var pedro = vale.pedro
		pedro.set_physics_process(false)
		vale.player.set_physics_process(false)
		vale.player.global_position = Vector3(80, 10, -180)
		var centro: Vector3 = vale.world.pontes["Ponte"].centro
		pedro.global_position = centro + Vector3.UP * 0.4
		pedro._nadando = false
		pedro._atualizar_nado()
		conferir(not pedro._nadando, "o piso da ponte não ativa nado pela profundidade do leito")
		print("ROTA_LAMINA: ",vale.world.water_level_at(centro), " corpo=",pedro.global_position)
		var lamina: float = vale.world.water_level_at(centro)
		pedro.global_position.y = lamina - pedro.altura * 0.9
		pedro.velocity = Vector3.ZERO
		pedro._atualizar_nado()
		conferir(pedro._nadando, "o corpo submerso entra em nado no rio elevado")
		pedro._mover(Vector3.ZERO, 0.0, 1.0 / 60.0)
		conferir(pedro.velocity.y > 0, "o nado procura a lâmina local, sem descer ao nível do mar")
		pedro.global_position = Vector3(109.0, 3.2, -234.8) if "--aproximacao-campanha" in OS.get_cmdline_user_args() else Vector3(115.5, 4.1, -251.0)
		pedro._atualizar_nado()
		pedro.velocity = Vector3.ZERO
		var destino: Vector3 = vale.world.ancoras["Portão da fazenda"]
		for i in range(2400):
			await physics_frame
			var ponto: Vector3 = pedro._ponto_do_caminho(destino, 1.0 / 60.0)
			var rumo := Vector3(ponto.x - pedro.global_position.x, 0, ponto.z - pedro.global_position.z).normalized()
			pedro._mover(rumo, pedro.ANDAR, 1.0 / 60.0)
			if i % 240 == 0:
				print("ROTA_FAZENDA_FISICA: ", pedro.global_position, " ponto=", ponto, " fundo=", pedro._fundo(pedro.global_position + rumo * pedro.PASSO_A_FRENTE))
				for k in pedro.get_slide_collision_count():
					var colisao: KinematicCollision3D = pedro.get_slide_collision(k)
					print("ROTA_FAZENDA_COLISAO: ", colisao.get_collider().get_path(), " normal=", colisao.get_normal())
			if Vector2(pedro.global_position.x - destino.x, pedro.global_position.z - destino.z).length() < pedro.CONDUZ_ATE:
				break
		conferir(Vector2(pedro.global_position.x - destino.x, pedro.global_position.z - destino.z).length() < pedro.CONDUZ_ATE,
			"Pedro precisa percorrer fisicamente a aproximação e o tabuleiro até o portão")
	print("ROTA_FAZENDA: ", falhas, " falhas")
	quit(1 if falhas > 0 else 0)
