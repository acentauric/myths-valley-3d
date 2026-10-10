extends "res://tests/suite/caso.gd"
## Confere A CASA HERDADA POR DENTRO e a CAMA QUE VIRA O DIA (#50, #26).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste casa
##
## `casa_procedural.gd` faz o outro estilo. Dez perguntas:
##
##   1. O CÔMODO ESTÁ DENTRO DA CASA: no meio dela, de costas para a fachada, na
##      medida da casca, com a porta onde a casca tem a dela pintada; e a caixa
##      inteira da casa saiu.
##   2. A PORTA ESTÁ ABERTA E AS PAREDES FECHADAS.
##   3. ENTRA-SE ANDANDO, o HUD diz "Sua casa" e a câmera sobe: lá dentro ela olha
##      de cima, com o teto e a casca só na sombra; saindo, volta como era.
##   4. NADA DE FORA ESTÁ NA SALA: nem árvore, nem o canteiro de mandioca que
##      morava no meio do roçado.
##   5. A CAMA E O BAÚ ESTÃO LÁ, a lamparina acende, e a tecla aparece perto de
##      cada um — e não do lado de fora.
##   6. DORMIR: o "não" não faz nada; o "sim" vira UM dia, acorda às 6h ao pé da
##      cama, descansado, e salva na virada.
##   7. O BAÚ DA CASA abre a mochila com ele do lado, com os dois beijus da
##      partida nova, e volta do save como estava.
##   8. A LENHA DE FORA NÃO RESPONDE DE DENTRO: a parede separa o alcance.
##   9. PASSOU DAS DUAS SEM DEITAR, o cansaço vence: um dia, ao pé da cama, com
##      o fôlego do desmaio e as falas do 2D.
##  10. CHEGAR ÀS TRÊS NÃO É PASSAR DAS DUAS: pôr a hora lá de uma vez (carregar
##      uma partida) não desmaia ninguém.

## O relógio de JOGO dos portões (`tests/fixtures/relogio_de_jogo.gd`): a bateria cheia
## roda sete Godots na mesma máquina, o quadro passa de 100 ms, e o jogo (que corta o
## delta e anda 3 a 5 passos de física por quadro) anda mais devagar que a parede. As
## esperas que contam o relógio de parede reprovavam "andando para a porta, não entrei
## em casa" e "a câmera de cima está a 1.34 do chão" na base de 05/10 — era o jogo
## ainda no meio do caminho e do tween de 0,3 s da câmera.
const RelogioDeJogo = preload("res://tests/fixtures/relogio_de_jogo.gd")

var falhas := 0
var relogio_de_jogo
var vale
var jogador
var interiores
var casa
var noite
var dialogo
var dia
var relogio
var energia
var progressao


func _estilo_do_portao() -> String:
	return "tripo"


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("CASA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	dialogo = root.get_node("/root/Dialogo")
	dia = root.get_node("/root/Dia")
	relogio = root.get_node("/root/Relogio")
	energia = root.get_node("/root/Energia")
	progressao = root.get_node("/root/Progressao")
	var partida = root.get_node("/root/Partida")
	var salvamento = root.get_node("/root/Salvamento")
	# Uma vaga de verdade, limpa: dormir salva na virada, e sem vaga não há onde.
	partida.comecar(1, true)
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(8)
	relogio_de_jogo = RelogioDeJogo.new()
	root.add_child(relogio_de_jogo)
	relogio_de_jogo.ficar_lento()
	vale = current_scene
	# O ACEITE É AUTOMÁTICO AQUI (08/10): este portão abre filas pelo E e segue; a tela de aceite
	# pausaria o vale no meio da medida (a tela tem portão próprio, tests/missao_a_vista.gd).
	if vale.get("aceite") != null:
		vale.aceite.automatico = true
	jogador = vale.get("player")
	interiores = vale.get("interiores")
	casa = vale.get("casa")
	noite = vale.get("noite")
	_conferir(interiores != null and casa != null and noite != null, "o vale não montou a casa, o cômodo ou a noite")
	if falhas > 0:
		_fechar()
		return
	var world = vale.world
	# A CHAVE JÁ DADA: na partida nova a casa espera a chave da Dona Zefa
	# (`tests/chegada.gd`); aqui se mede a casa aberta, como o jogador a acha.
	var pedro = vale.get("pedro")
	if pedro != null:
		pedro.ir_ao_passo("roca")
		vale._acertar_a_porta_da_casa()

	# --- 1. DENTRO DA CASA -----------------------------------------------------
	var sala: Node3D = interiores.sala_de("casa")
	var cadeia: Node = vale.pedro._cadeia
	var entrada: Vector3 = cadeia.posicao_do_passo(5)
	if "--alvo-na-parede" in OS.get_cmdline_user_args():
		entrada = world.ancoras["Casa de taipa"]
	_conferir(entrada.distance_to(sala.soleira_de_fora()) < 0.05, "marcador da entrada aponta a soleira real")
	var passo_anterior: int = cadeia.missao
	cadeia.missao = 5
	var espera_pedro: Vector3 = vale.pedro._destino_da_conducao(cadeia)
	cadeia.missao = passo_anterior
	_conferir(Vector2(espera_pedro.x - entrada.x, espera_pedro.z - entrada.z).length() > 0.6, "Pedro espera ao lado sem bloquear a porta")
	_conferir(sala != null, "a casa herdada não tem cômodo")
	if sala == null:
		_fechar()
		return
	# #136: verifica as paredes realmente montadas, não só a fábrica de material.
	if _estilo_do_portao() == "tripo":
		var paredes_texturizadas := 0
		var paredes = sala.find_children("Parede_*", "Node3D", true, false)
		paredes.append_array(sala.find_children("Fundos_*", "Node3D", true, false))
		paredes.append_array(sala.find_children("Fachada_*", "Node3D", true, false))
		for parede in paredes:
			for malha in parede.find_children("*", "MeshInstance3D", true, false):
				var material = malha.material_override
				if "--falsificar-cal" in OS.get_cmdline_user_args() and material is StandardMaterial3D:
					material.albedo_texture = null
				_conferir(material is StandardMaterial3D and material.albedo_texture != null,
					"parede interna continua sem textura de cal")
				if material is StandardMaterial3D:
					_conferir(material.uv1_world_triplanar and material.uv1_triplanar,
						"textura de parede depende dos UVs esticados da caixa")
					paredes_texturizadas += 1
		_conferir(paredes_texturizadas >= 3, "faltam paredes internas texturizadas")
	var centro: Vector3 = world.ancoras["Casa de taipa"]
	var frente: Vector3 = sala.global_basis.z.normalized()
	var meio: Vector3 = sala.to_global(Vector3(0, 0, -sala.comprimento * 0.5))
	_conferir(Vector2(meio.x - centro.x, meio.z - centro.z).length() < 1.5,
		"o meio do cômodo está a %.1f do meio da casa" % Vector2(meio.x - centro.x, meio.z - centro.z).length())
	_conferir(frente.dot(world.ancoras.get("Casa de taipaFrente", Vector3.BACK).normalized()) > 0.95,
		"a porta do cômodo não está do lado da fachada da casa")
	_conferir(sala.largura > 2.8 and sala.largura < 6.0 and sala.comprimento > 2.6 and sala.comprimento < 5.4,
		"o cômodo tem %.1f por %.1f: não é a medida da casca da casa" % [sala.largura, sala.comprimento])
	_conferir(absf(sala.porta_x - 0.92) < 0.05, "a porta do cômodo está em %.2f, e a pintada da casca em 0,92" % sala.porta_x)
	print("  casa: %.1f x %.1f, pé-direito %.1f, porta em %.2f" % [sala.largura, sala.comprimento, sala.pe_direito, sala.porta_x])
	var lote: Dictionary = world.construcoes.get("Casa de taipa", {})
	var caixa_inteira = lote.get("colisao")
	_conferir(not is_instance_valid(caixa_inteira) or caixa_inteira.is_queued_for_deletion(),
		"a caixa de colisão inteira da casa continua lá: ninguém entra")

	# --- 2. PORTA ABERTA, PAREDES FECHADAS -------------------------------------
	var espaco: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var fora: Vector3 = sala.soleira_de_fora() + Vector3.UP * 1.1
	var por_dentro: Vector3 = sala.soleira_de_dentro() + Vector3.UP * 1.1
	var pela_porta := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(fora, por_dentro, 1))
	_conferir(pela_porta.is_empty(), "o caminho pela porta bate em '%s'" % str(pela_porta.get("collider")))
	var lado: Vector3 = sala.global_basis.x.normalized()
	var de_lado: Vector3 = meio + Vector3.UP * 1.2 - lado * (sala.largura * 0.5 + 3.0)
	var pela_parede := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(de_lado, meio + Vector3.UP * 1.2, 1))
	_conferir(not pela_parede.is_empty(), "a parede da casa não tem colisão: atravessa-se de lado")

	# --- 3. ENTRA-SE ANDANDO, E A CÂMERA SOBE ------------------------------------
	var rumo := atan2(frente.x, frente.z) - PI
	jogador.teleportar(world.ground_position(sala.soleira_de_fora(), 0.05), rumo)
	await _frames(3)
	_conferir(interiores.dentro() == "", "de pé na porta, do lado de fora, o jogo diz que estou dentro")
	_conferir(not jogador.esta_de_cima(), "do lado de fora a câmera já estava de cima")
	Input.action_press("mv_forward")
	var entrou := await _ate(func() -> bool: return interiores.dentro() == "casa", 8.0)
	await _segundos(0.6)
	Input.action_release("mv_forward")
	_conferir(entrou, "andando para a porta, não entrei em casa: o corpo parou em %s" % str(jogador.global_position))
	await _quadros_de_fisica(30)
	_conferir(sala.contem(jogador.global_position), "andei e o corpo não está dentro da casa")
	_conferir(jogador.is_on_floor(), "dentro de casa o corpo não está no chão")
	_conferir(absf(sala.to_local(jogador.global_position).y) < 0.6, "o corpo está fora do chão da casa")
	var titulo: String = str(vale.hud.get("_region_label").text)
	_conferir(titulo == str(interiores.nome_de("casa")).to_upper(), "dentro de casa o HUD diz '%s'" % titulo)
	_conferir(jogador.esta_de_cima(), "dentro de casa a câmera não subiu")
	var camera: Camera3D = jogador.get("camera")
	# A câmera de cima sobe em trânsito (0,3 s de jogo) e fica por cima do teto, que
	# some para ela: espera-se o trânsito, em segundos de JOGO.
	await _ate(func() -> bool: return sala.to_local(camera.global_position).y > sala.pe_direito, 3.0)
	_conferir(sala.to_local(camera.global_position).y > sala.pe_direito,
		"a câmera de cima está a %.2f do chão, abaixo do teto (%.2f)" % [sala.to_local(camera.global_position).y, sala.pe_direito])
	_conferir(_so_sombra(sala.get("_teto")) and _so_sombra(sala.get("casca")),
		"com o jogador dentro, o teto ou a casca continuam aparecendo para a câmera")
	# A sombra do sol encurta com a câmera de cima (#185) e volta ao sair.
	var sol: DirectionalLight3D = world.get("_ceu").sol
	_conferir(is_equal_approx(sol.directional_shadow_max_distance, 24.0),
		"dentro da casa a sombra do sol vai a %.1f u, e não a 24" % sol.directional_shadow_max_distance)
	jogador.teleportar(world.ground_position(sala.soleira_de_fora() + frente * 1.5, 0.05), rumo + PI)
	await _quadros_de_fisica(10)
	_conferir(interiores.dentro() == "" and not jogador.esta_de_cima(), "saindo de casa, a câmera não voltou a ser a de passeio")
	_conferir(not _so_sombra(sala.get("casca")), "saindo de casa, a casca continuou sumida")
	_conferir(is_equal_approx(sol.directional_shadow_max_distance, 70.0),
		"saindo de casa a sombra do sol ficou em %.1f u, e não nas 70 de sempre" % sol.directional_shadow_max_distance)

	# --- 4. NADA DE FORA NA SALA -------------------------------------------------
	var intrusos := []
	var da_casca: Array = []
	for no in sala.get("casca"):
		if is_instance_valid(no):
			da_casca.append(no)
			da_casca.append_array((no as Node).find_children("*", "MeshInstance3D", true, false))
	for mi in world.find_children("*", "MeshInstance3D", true, false):
		var malha := mi as MeshInstance3D
		if malha.mesh == null or da_casca.has(malha) or not malha.is_visible_in_tree():
			continue
		var caixa: AABB = malha.global_transform * malha.get_aabb()
		# O chão do lote e a base da casa são rasos; o que tem altura é coisa.
		if caixa.size.y < 0.7:
			continue
		var centro_da_caixa := caixa.get_center()
		if sala.contem(Vector3(centro_da_caixa.x, sala.global_position.y + 1.0, centro_da_caixa.z)):
			intrusos.append("%s (%.1f de altura)" % [malha.get_path(), caixa.size.y])
	_conferir(intrusos.is_empty(), "há coisa de fora dentro da sala: %s" % str(intrusos))
	for tronco in world._region._tree_trunks:
		var ponto: Vector2 = tronco.get("point", Vector2.INF)
		_conferir(not sala.contem(Vector3(ponto.x, sala.global_position.y + 1.0, ponto.y)),
			"há um tronco da mata dentro da sala, em %s" % str(ponto))

	# --- 5. A CAMA, O BAÚ E A TECLA ------------------------------------------------
	_conferir(not sala.find_children("CamaColisao_*", "", true, false).is_empty(), "a casa não tem cama")
	_conferir(not sala.find_children("BauColisao_*", "", true, false).is_empty(), "a casa não tem baú")
	_conferir(not sala.find_children("Lamparina_*", "OmniLight3D", true, false).is_empty(), "a casa não tem a lamparina acesa")
	jogador.teleportar(sala.lugar_de_acordar(), sala.giro_de_acordar())
	await _quadros_de_fisica(6)
	await _frames(2)
	_conferir(casa.perto() == "cama", "ao pé da cama a tecla diz '%s'" % casa.perto())
	var diante_do_bau: Vector3 = sala.ponto_do_bau() + frente * 0.9
	jogador.teleportar(Vector3(diante_do_bau.x, sala.lugar_de_acordar().y, diante_do_bau.z), rumo)
	await _quadros_de_fisica(6)
	await _frames(2)
	_conferir(casa.perto() == "bau", "diante do baú a tecla diz '%s'" % casa.perto())
	var atras_da_parede: Vector3 = sala.to_global(Vector3(-sala.largura * 0.5 + 1.0, 0.0, -sala.comprimento - 1.4))
	jogador.teleportar(world.ground_position(atras_da_parede, 0.05), rumo)
	await _quadros_de_fisica(6)
	await _frames(2)
	_conferir(casa.perto() == "", "do lado de fora da parede do fundo, a tecla da cama apareceu")

	# --- 6. DORMIR ---------------------------------------------------------------
	jogador.teleportar(sala.lugar_de_acordar(), sala.giro_de_acordar())
	await _quadros_de_fisica(6)
	dia.pausado = true
	dia.definir_hora(22.0)
	var dia_antes: int = relogio.dia_absoluto()
	await _usar_a_cama([false])
	_conferir(relogio.dia_absoluto() == dia_antes and absf(dia.hora - 22.0) < 0.1,
		"dizendo que não, a cama virou o dia ou mexeu na hora (%s)" % dia.texto_hora())
	energia.definir(5.0)
	var motivo := [""]
	noite.deitou.connect(func(qual: String): motivo[0] = qual)
	var acordou := [false]
	# A RESERVA SE LÊ NA HORA DE ACORDAR, e não quadros depois. No corpo de três
	# barras o vigor volta sozinho com o jogador parado (vinte por segundo), e o
	# `acordou` sai logo depois de a física dele ser religada: bastava um tique
	# entre o sinal e a conferência para o sono devolver 45,33 em vez de 45.
	var reserva_ao_acordar := [0.0]
	noite.acordou.connect(func():
		acordou[0] = true
		reserva_ao_acordar[0] = energia.atual)
	await _usar_a_cama([true])
	_conferir(await _ate(func() -> bool: return acordou[0], 20.0), "dormindo, o jogador ficou no escuro")
	_conferir(motivo[0] == "cama", "a noite virou pela porta '%s', e não pela da cama" % motivo[0])
	_conferir(relogio.dia_absoluto() == dia_antes + 1, "a cama virou %d dia(s), e é um" % (relogio.dia_absoluto() - dia_antes))
	var acordar := float(relogio.HORA_DE_ACORDAR)
	_conferir(dia.hora >= acordar and dia.hora < acordar + 0.25, "acordou às %s" % dia.texto_hora())
	_conferir(jogador.global_position.distance_to(sala.lugar_de_acordar()) < 0.8,
		"acordou a %.1f u do pé da cama" % jogador.global_position.distance_to(sala.lugar_de_acordar()))
	_conferir(is_equal_approx(reserva_ao_acordar[0], minf(energia.maximo(), 5.0 + progressao.recuperacao_ao_dormir)),
		"na cama o fôlego voltou como desmaio, e não como sono: %s" % str(reserva_ao_acordar[0]))
	var guardado: Dictionary = salvamento.ler(1)
	_conferir(not guardado.is_empty() and int(guardado.get("Relogio", {}).get("dia", -1)) == relogio.dia,
		"a virada não salvou a partida do dia novo")
	_conferir(jogador.is_physics_processing(), "depois de acordar, o jogador continuou travado")

	# --- 7. O BAÚ DA CASA --------------------------------------------------------
	var mochila = root.get_node("/root/Mochila")
	var beijus := 0
	for monte in casa.bau:
		if str(monte.get("id", "")) == "beiju":
			beijus += int(monte.get("qtd", 0))
	_conferir(beijus == 2, "a partida nova achou %d beiju(s) no baú, e são dois" % beijus)
	# Na câmera livre o cursor está preso: é dele que o baú tem de soltar.
	jogador.set_captured(true)
	casa.usar("bau")
	await _frames(3)
	_conferir(mochila.aberta and mochila.get("_bau") == casa.bau, "o E no baú não abriu a mochila com ele do lado")
	# O BAÚ É TELA COMO A MOCHILA: "no manuseio do baú deve poder usar o
	# ponteiro do mouse igual na mochila". Aberto direto, o cursor ficava preso
	# na câmera livre e o vale seguia andando atrás da tela.
	var telas = current_scene.get_node_or_null("TelasDoVale")
	_conferir(telas != null and telas.aberta() == "mochila", "o baú abriu sem passar pelo dono das telas")
	_conferir(paused, "com o baú aberto o vale continua andando")
	_conferir(Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, "com o baú aberto o cursor do mouse continua preso na câmera")
	# Fecha como o Esc fecha: pelo dono das telas, que devolve o vale.
	if telas != null:
		telas.fechar_tudo()
	else:
		mochila.fechar()
	await _frames(2)
	_conferir(not mochila.aberta and not paused, "fechar o baú não devolveu o vale")
	var no_save: Dictionary = guardado.get("Mundo", {}).get("casa", {})
	_conferir(not no_save.is_empty(), "o save não guarda o baú da casa")
	casa.bau.clear()
	casa.restaurar(no_save)
	_conferir(casa.bau == no_save.get("bau", []), "o baú não voltou do save como estava")
	var tem := {}
	for monte in casa.bau:
		tem[str(monte.get("id", ""))] = true
	_conferir(tem.has("balde") and tem.has("semente_mandioca"), "o baú da partida nova não tem o balde e a maniva do finado")

	# --- 8. A PAREDE SEPARA O ALCANCE ----------------------------------------------
	# Um alvo de teste dois palmos do lado de fora da parede da direita, e o
	# jogador do lado de dentro, junto dela: sem a parede separar, o alcance
	# passava por ela. (A lenha de verdade fica longe demais para isto.) O alvo
	# entra e sai na mesma chamada, sem quadro no meio: o `_process` dos alvos
	# lê dele mais do que a posição.
	var recursos = vale.get_node_or_null("Recursos3D")
	_conferir(recursos != null, "o vale não tem os alvos de trabalho")
	if recursos != null:
		var meio_z: float = -sala.comprimento * 0.5
		var junto: Vector3 = sala.to_global(Vector3(sala.largura * 0.5 - 0.4, 0.05, meio_z))
		jogador.teleportar(junto, rumo)
		await _quadros_de_fisica(4)
		_conferir(sala.contem(jogador.global_position), "(preparo) o jogador não ficou dentro de casa, junto da parede")
		var alvo_de_fora: Vector3 = sala.to_global(Vector3(sala.largura * 0.5 + sala.PAREDE + 0.5, 0.05, meio_z))
		recursos._alvos["teste_do_lado_de_fora"] = {"pos": alvo_de_fora, "meia_pegada": 0.2, "ficha": {}}
		var de_dentro: String = recursos._mais_perto()
		jogador.global_position = sala.to_global(Vector3(sala.largura * 0.5 + sala.PAREDE + 1.0, 0.05, meio_z))
		var de_fora: String = recursos._mais_perto()
		recursos._alvos.erase("teste_do_lado_de_fora")
		jogador.teleportar(junto, rumo)
		_conferir(de_fora == "teste_do_lado_de_fora", "(preparo) do lado de fora, junto do alvo de teste, o alcance ofereceu '%s'" % de_fora)
		_conferir(de_dentro != "teste_do_lado_de_fora", "de dentro de casa, junto da parede, o E oferece o que está do lado de fora dela")

	# --- 9. PASSOU DAS DUAS ---------------------------------------------------------
	var praca: Vector3 = world.ancoras["Praça"]
	jogador.teleportar(world.ground_position(praca + Vector3(3, 0, 3), 0.05), 0.0)
	await _quadros_de_fisica(6)
	dia.definir_hora(1.9)
	dia_antes = relogio.dia_absoluto()
	energia.definir(5.0)
	motivo[0] = ""
	acordou[0] = false
	var lidas: Array = []
	dia.avancar(0.2)
	_conferir(motivo[0] == "desmaio", "às duas da manhã, na praça, a noite virou pela porta '%s'" % motivo[0])
	_conferir(await _ate(func() -> bool: return acordou[0], 20.0), "desmaiado, o jogador ficou no escuro")
	await _ate(func() -> bool: return dialogo.ativo, 3.0)
	if dialogo.ativo:
		lidas.append_array(dialogo._falas)
		dialogo._fechar()
	_conferir(relogio.dia_absoluto() == dia_antes + 1, "o desmaio virou %d dia(s), e é um" % (relogio.dia_absoluto() - dia_antes))
	_conferir(dia.hora >= acordar and dia.hora < acordar + 0.25, "depois do desmaio acordou às %s" % dia.texto_hora())
	_conferir(jogador.global_position.distance_to(sala.lugar_de_acordar()) < 0.8,
		"quem desmaiou na praça acordou a %.1f u do pé da cama" % jogador.global_position.distance_to(sala.lugar_de_acordar()))
	_conferir(is_equal_approx(reserva_ao_acordar[0], minf(energia.maximo(), 5.0 + progressao.recuperacao_ao_desmaiar)),
		"o fôlego não voltou como no desmaio: %s" % str(reserva_ao_acordar[0]))
	_conferir(" ".join(lidas).contains(_primeira_fala_do_desmaio()), "ao acordar do desmaio, as falas do 2D não vieram: %s" % str(lidas))

	# --- 10. CHEGAR ÀS TRÊS ------------------------------------------------------------
	motivo[0] = ""
	dia.definir_hora(3.0)
	await _quadros_de_fisica(10)
	_conferir(motivo[0] == "", "pôr a hora às três de uma vez desmaiou o jogador")
	dia.pausado = false
	_fechar()


## A cama, respondendo à pergunta dela com `respostas`.
func _usar_a_cama(respostas: Array) -> void:
	var fila := respostas.duplicate()
	casa.usar("cama")
	var ate: float = relogio_de_jogo.agora() + 6.0
	while not dialogo.ativo and relogio_de_jogo.agora() < ate:
		await process_frame
	while dialogo.ativo and relogio_de_jogo.agora() < ate:
		if dialogo._modo == dialogo.Modo.PERGUNTA:
			dialogo._escolha = bool(fila.pop_front()) if not fila.is_empty() else false
			dialogo._escolheu = true
		dialogo._fechar()
		await process_frame
	await _frames(2)


func _primeira_fala_do_desmaio() -> String:
	var dado = JSON.parse_string(FileAccess.get_file_as_string("res://data/casa.json"))
	var falas: Array = dado.get("desmaio", []) if dado is Dictionary else []
	var idioma = load("res://scripts/prototipo_3d/idioma_menu.gd")
	return str(idioma.campo(falas[0], "texto")) if not falas.is_empty() else "?"


## Tudo isso só faz sombra (a câmera não vê)?
func _so_sombra(nos: Array) -> bool:
	var algum := false
	for no in nos:
		if not is_instance_valid(no):
			continue
		var geometrias: Array = [no] if no is GeometryInstance3D else []
		geometrias.append_array((no as Node).find_children("*", "GeometryInstance3D", true, false))
		for geometria in geometrias:
			algum = true
			if (geometria as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
				return false
	return algum


func _fechar() -> void:
	Input.action_release("mv_forward")
	print("")
	if falhas == 0:
		print("CASA_OK (", _estilo_do_portao(), "): o cômodo mora dentro da casa herdada, na medida da casca e com a porta onde a pintada está; a porta está aberta e as paredes fechadas; entra-se andando, o HUD diz Sua casa e a câmera sobe com o teto só na sombra; nada de fora está na sala; a cama, o baú e a lamparina estão lá, com a tecla só de dentro; o não da cama não faz nada e o sim vira um dia, acorda às 6h ao pé da cama descansado e salva; o baú abre com os beijus e volta do save; a lenha de fora não responde de dentro; passar das duas desmaia, com as falas do 2D; e chegar às três de uma vez não")
	else:
		print("casa (%s): %d falha(s)" % [_estilo_do_portao(), falhas])
	quit(1 if falhas > 0 else 0)


## Espera `condicao` por até `segundos` de JOGO (e não de parede).
func _ate(condicao: Callable, segundos: float) -> bool:
	return await relogio_de_jogo.ate(condicao, segundos)


func _segundos(quanto: float) -> void:
	await relogio_de_jogo.esperar(quanto)


func _quadros_de_fisica(quantos: int) -> void:
	for i in quantos:
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
