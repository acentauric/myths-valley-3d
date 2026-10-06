extends SceneTree
## Confere que TODA CASA DO VALE ABRE POR DENTRO E TEM MÓVEIS, a começar pelo casarão
## da fazenda.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/casas_por_dentro.gd
##
## "Precisamos melhorar a casa grande no norte do mapa, com acesso interno como as demais
## casas pequenas têm; todas as casas devem ter acesso interno e móveis." Só quatro das
## vinte e oito construções abriam (a igreja, a casa herdada, a do Pedro, a da Zefa); as
## outras, até as capelas e a casa de farinha, moram em `data/interiores_casas.json` e se montam de perto (`interiores.gd`).
## Oito perguntas:
##
##   1. TODO LOTE DE MORADIA TEM CÔMODO, e o nome dele existe nos três idiomas. A lista não
##      é escrita aqui: sai do que o vale construiu (`world.construcoes`): casa nova que
##      ninguém ensinou ao `Interiores` reprova.
##   2. OS CÔMODOS SÃO PREGUIÇOSOS: ao subir o vale o casarão e as casas longe do jogador não
##      estão montados; chegando perto o cômodo se monta SOZINHO; longe, some do desenho.
##   3. CADA CÔMODO TEM PISO, FORRO, PORTA ABERTA E PAREDE FECHADA, o tamanho de gente e a
##      luz de dentro, que não vaza.
##   4. CADA CÔMODO TEM MÓVEIS, todos sólidos (a colisão sai da malha deles), e nenhum de chão
##      toma o vão da porta.
##   5. ENTRA-SE ANDANDO: do chão de fora, com a tecla de andar, até dentro — sem escurecer, o
##      corpo no chão do cômodo, o HUD dizendo onde se está —, e se sai andando de volta; a
##      câmera nunca vai para dentro do corpo no caminho.
##   6. O CASARÃO TEM A ESCADARIA: de lá do pé da escada de pedra até o salão, andando.
##   7. A CASA DE FARINHA, que é galpão aberto, se anda por dentro, e a parede do fundo segura.
##   8. O SAVE DENTRO DE CASA AINDA NÃO MONTADA: o jogador que chega de uma vez ao meio dela fica lá dentro.
##
## FALSIFICAÇÃO: `-- --falsificar=sem_moveis` esvazia a mobília dos perfis (a pergunta 4 tem de
## reprovar); `=eager` monta tudo no começo (a 2); `=porta_fechada` põe um corpo no vão de
## cada porta (a 5); `=sem_freio` não segura o jogador que chega de uma vez a uma casa por montar (a 8).
## A variável `MV_FALSIFICAR` faz o mesmo.

## O relógio de JOGO dos portões (`tests/fixtures/relogio_de_jogo.gd`).
const RelogioDeJogo = preload("res://tests/fixtures/relogio_de_jogo.gd")

## O mínimo de móveis com colisão, por cômodo, e no casarão.
const MOVEIS_NA_CASA := 3
const MOVEIS_NO_CASARAO := 12
## Quanto o corpo tem de passar da porta, para dentro, andando em linha reta (m): o caminho está livre.
const FUNDO_DA_ENTRADA := 0.9
## A câmera nunca chega mais perto do corpo que isto (m) no caminho.
const CAMERA_MAIS_PERTO := 0.3
## A altura da cabeça de quem anda (m): peça de parede abaixo disso, no caminho, é obstáculo.
const CABECA := 1.7

var falhas := 0
var relogio_de_jogo
var falsificar := ""
var vale
var interiores
var jogador
var mundo
## A menor distância entre a câmera e o corpo durante a caminhada.
var _menor_camera := INF


func _estilo_do_portao() -> String:
	return "tripo"


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("CASAS_POR_DENTRO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _pedido_de_falsificacao() -> String:
	var pedido := OS.get_environment("MV_FALSIFICAR")
	for argumento in OS.get_cmdline_user_args():
		if str(argumento).begins_with("--falsificar="):
			pedido = str(argumento).trim_prefix("--falsificar=")
	return pedido


func _run() -> void:
	falsificar = _pedido_de_falsificacao()
	root.get_node("/root/Estilo").modo = _estilo_do_portao()
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(8)
	await _carga_pronta()
	relogio_de_jogo = RelogioDeJogo.new()
	root.add_child(relogio_de_jogo)
	relogio_de_jogo.ficar_lento()
	vale = current_scene
	interiores = vale.get("interiores")
	jogador = vale.get("player")
	mundo = vale.get("world")
	_conferir(interiores != null and jogador != null and mundo != null, "o vale não montou as construções por dentro")
	if interiores == null or jogador == null or mundo == null:
		_fechar()
		return
	if falsificar != "":
		print("  FALSIFICAÇÃO: %s" % falsificar)
	# Quem mora no vale tira o corpo do caminho: o morador parado na porta de casa (o posto
	# dele) fecharia o vão, e o portão mede a casa, e não o arraial.
	for morador in vale.moradores:
		(morador as CollisionObject3D).collision_layer = 0
	var guia = vale.get("pedro")
	if guia != null:
		(guia as CollisionObject3D).collision_layer = 0
		# A CHAVE JÁ DADA: na partida nova a casa herdada espera a chave da Dona Zefa
		# (`tests/chegada.gd`), e o Pedro mudando de passo a tranca de novo; aqui se mede a
		# casa aberta, como o jogador a acha depois (como `tests/casa.gd` faz).
		guia.ir_ao_passo("roca")
		vale._acertar_a_porta_da_casa()
	root.get_node("/root/Dia").pausado = true

	# --- 1. TODO LOTE DE MORADIA TEM CÔMODO ---------------------------------------------
	var qual_do_lote := {}
	for qual in interiores.todas():
		qual_do_lote[str(interiores._ancora_de(str(qual), interiores._tabela[qual]))] = str(qual)
	var lotes_de_casa := 0
	for nome in mundo.construcoes:
		lotes_de_casa += 1
		_conferir(qual_do_lote.has(str(nome)), "o lote '%s' não tem cômodo: ninguém ensinou o Interiores a abri-lo" % str(nome))
	_conferir(lotes_de_casa >= 20, "só %d lotes de casa no vale: o mundo não subiu inteiro?" % lotes_de_casa)
	for qual in interiores.todas():
		var dado: Dictionary = interiores._tabela[qual]
		if not dado.has("nome_en"):
			continue
		_conferir(str(dado.get("nome", "")) != "" and str(dado.get("nome_es", "")) != "", "'%s' não tem o nome nos três idiomas" % qual)
		_conferir(str(dado.get("nome_en", "")) != str(dado.get("nome", "")) and str(dado.get("nome_es", "")) != str(dado.get("nome", "")),
			"'%s' tem o nome em inglês ou espanhol igual ao do português: é cópia, e não tradução" % qual)

	# --- 2. OS CÔMODOS SÃO PREGUIÇOSOS --------------------------------------------------
	if falsificar == "eager":
		await interiores.garantir_todas()
	var montadas: int = interiores.quais().size()
	_conferir(montadas < interiores.todas().size(),
		"ao subir o vale já há %d de %d cômodos montados: o que está longe não precisa estar" % [montadas, interiores.todas().size()])
	_conferir(interiores.sala_de("casarao") == null, "o casarão, a trezentas unidades do jogador, já está montado")
	if falsificar == "sem_freio":
		interiores.segura_o_jogador = false
	if falsificar != "eager":
		await _chegar_de_uma_vez_dentro()
		await _chegar_e_ver_montar()
		await _ir_embora_e_ver_sumir()

	# --- 3 a 6. CADA CÔMODO ---------------------------------------------------------------
	if falsificar == "sem_moveis":
		for perfil in (interiores._dados.get("perfis", {}) as Dictionary).values():
			(perfil as Dictionary)["moveis"] = []
	await interiores.garantir_todas()
	var camera: Camera3D = jogador.get("camera")
	var vistos: Array = interiores.quais()
	vistos.sort()
	for qual in vistos:
		await _conferir_a_casa(str(qual), camera)
	await _conferir_o_galpao()
	_fechar()


## Pergunta 8, o save: o jogador que chega DE UMA VEZ ao meio de uma casa que ainda não se montou
## (a partida salva lá dentro, um pulo no mapa) fica parado até o cômodo estar de pé, e acaba
## dentro dele, no piso — e não expulso pela caixa inteira que ainda cobria a casa.
func _chegar_de_uma_vez_dentro() -> void:
	var lote := "Casa da lavadeira"
	var qual := ""
	for q in interiores.todas():
		if interiores._ancora_de(str(q), interiores._tabela[q]) == lote:
			qual = str(q)
	if qual == "" or not mundo.ancoras.has(lote) or interiores.sala_de(qual) != null:
		_conferir(false, "a casa da lavadeira não serve para ver o cômodo se montar em volta do jogador")
		return
	var meio: Vector3 = mundo.ancoras[lote]
	jogador.teleportar(Vector3(meio.x, meio.y + 0.9, meio.z), 0.0)
	var montou: bool = await _ate(func() -> bool: return interiores.sala_de(qual) != null, 6.0)
	await _quadros_de_fisica(25)
	_conferir(montou, "o jogador chegou de uma vez ao meio da casa da lavadeira e o cômodo não se montou")
	var sala = interiores.sala_de(qual)
	if sala != null:
		_conferir(sala.contem(jogador.global_position),
			"o jogador que chegou de uma vez ao meio da casa foi parar fora do cômodo: %s" % str(sala.to_local(jogador.global_position)))
		_conferir(jogador.is_on_floor() and absf(sala.to_local(jogador.global_position).y) < 0.6,
			"o jogador não está no piso da casa da lavadeira: %s" % str(sala.to_local(jogador.global_position)))
		_conferir(jogador.is_physics_processing(), "o jogador ficou parado depois de o cômodo se montar")


## Pergunta 2, a ida: o jogador chega à casa do guarda e o cômodo se monta sem ninguém pedir.
func _chegar_e_ver_montar() -> void:
	var lote := "Casa do guarda"
	var qual := ""
	for q in interiores.todas():
		if interiores._ancora_de(str(q), interiores._tabela[q]) == lote:
			qual = str(q)
	if qual == "" or not mundo.ancoras.has(lote):
		_conferir(false, "não achei a casa do guarda para ver o cômodo se montar")
		return
	if interiores.sala_de(qual) != null:
		_conferir(false, "a casa do guarda já estava montada antes de o jogador chegar")
		return
	var frente: Vector3 = mundo.ancoras.get(lote + "Frente", Vector3.BACK)
	var perto: Vector3 = mundo.ground_position(mundo.ancoras[lote] + frente * 14.0, 0.05)
	jogador.teleportar(perto, 0.0)
	var montou: bool = await _ate(func() -> bool: return interiores.sala_de(qual) != null, 6.0)
	_conferir(montou, "o jogador chegou a 14 unidades da casa do guarda e o cômodo não se montou sozinho")


## Pergunta 2, a volta: longe, o cômodo montado some do desenho, e volta quando ele volta.
func _ir_embora_e_ver_sumir() -> void:
	var sala = interiores.sala_de("guarda")
	if sala == null:
		return
	var longe: Vector3 = mundo.ground_position(mundo.ancoras["Pier"], 0.05)
	jogador.teleportar(longe, 0.0)
	var sumiu: bool = await _ate(func() -> bool: return not sala.visible, 4.0)
	_conferir(sumiu, "o jogador foi para o píer, a mais de 100 unidades da casa do guarda, e o cômodo dela continua desenhado")
	var frente: Vector3 = mundo.ancoras.get("Casa do guardaFrente", Vector3.BACK)
	jogador.teleportar(mundo.ground_position(mundo.ancoras["Casa do guarda"] + frente * 14.0, 0.05), 0.0)
	var voltou: bool = await _ate(func() -> bool: return sala.visible, 4.0)
	_conferir(voltou, "o jogador voltou à casa do guarda e o cômodo dela não reapareceu")


func _conferir_a_casa(qual: String, camera: Camera3D) -> void:
	var sala: Node3D = interiores.sala_de(qual)
	_conferir(sala != null, "'%s' não tem cômodo montado" % qual)
	if sala == null:
		return
	var nome: String = interiores.nome_de(qual)
	_conferir(nome != "", "'%s' não tem nome para o HUD" % qual)
	var espaco: PhysicsDirectSpaceState3D = mundo.get_world_3d().direct_space_state
	# A casa herdada abre trancada até a chave da Dona Zefa, na chegada
	# (`prototype._acertar_a_porta_da_casa`): aqui a chave já foi dada.
	if sala.has_method("trancar"):
		sala.trancar(false)

	# --- 3. PISO, FORRO, PORTA ABERTA, PAREDE FECHADA, TAMANHO DE GENTE, LUZ QUE NÃO VAZA ---
	_conferir(not sala.find_children("Chao_*", "Node3D", false, false).is_empty(), "%s: sem piso" % qual)
	_conferir(not sala.find_children("Forro_*", "Node3D", false, false).is_empty(), "%s: sem forro" % qual)
	_conferir(sala.largura >= 2.8 and sala.comprimento >= 2.6 and sala.pe_direito >= 2.2,
		"%s: o cômodo tem %.1f por %.1f, pé-direito %.1f: não cabe uma pessoa e uma cama" % [qual, sala.largura, sala.comprimento, sala.pe_direito])
	var fora: Vector3 = sala.soleira_de_fora() + Vector3.UP * 1.2
	var por_dentro: Vector3 = sala.soleira_de_dentro() + Vector3.UP * 1.2
	var pela_porta := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(fora, por_dentro, 1))
	_conferir(pela_porta.is_empty(), "%s: o caminho pela porta bate em '%s'" % [qual, str(pela_porta.get("collider"))])
	var meio: Vector3 = sala.to_global(Vector3(0, 1.2, -sala.comprimento * 0.5))
	var de_lado: Vector3 = meio + sala.global_basis.x.normalized() * (sala.largura * 0.5 + 3.0)
	_conferir(not espaco.intersect_ray(PhysicsRayQueryParameters3D.create(de_lado, meio, 1)).is_empty(),
		"%s: a parede não tem colisão: atravessa-se de lado" % qual)
	for luz in sala.find_children("*", "Light3D", true, false):
		_conferir(((luz as Light3D).light_cull_mask & 1) == 0, "%s: a luz '%s' acende a camada do mundo e vaza pela parede" % [qual, str(luz.name)])

	# --- 4. MÓVEIS: quantos, sólidos, e longe do vão da porta ----------------------------
	var moveis: Array = sala.moveis()
	var minimo := MOVEIS_NO_CASARAO if qual == "casarao" else MOVEIS_NA_CASA
	_conferir(moveis.size() >= minimo, "%s: só %d móvel(is) com colisão (mínimo %d)" % [qual, moveis.size(), minimo])
	var vao := Rect2(sala.porta_x - sala.largura_da_porta * 0.5 - 0.1, -1.2, sala.largura_da_porta + 0.2, 1.2)
	var fundo_do_corredor := minf(2.75, sala.comprimento)
	var corredor := Rect2(sala.porta_x - sala.largura_da_porta * 0.5, -fundo_do_corredor, sala.largura_da_porta, fundo_do_corredor)
	for movel: Dictionary in moveis:
		# Só as casas têm vão de entrada (`_reservado`); a nave da igreja tem corredor entre bancos.
		if not is_instance_valid(movel.get("peca")) or not ("_reservado" in sala):
			continue
		var caixa: AABB = sala.caixa_no_comodo(movel["peca"])
		var pegada := Rect2(caixa.position.x, caixa.position.z, caixa.size.x, caixa.size.z)
		if caixa.position.y >= 0.9:
			# A peça de parede à altura da cabeça (a prateleira, o oratório) também fecha o caminho de
			# quem entra: o corredor do corpo vai da fachada ao fundo da faixa livre, na largura do vão.
			if caixa.position.y < CABECA:
				_conferir(not pegada.intersects(corredor), "%s: '%s' pendurado na parede, à altura da cabeça, fica no corredor da porta: x [%.2f, %.2f], z [%.2f, %.2f]" % [qual,
					str(movel.get("nome", "?")), caixa.position.x, caixa.end.x, caixa.position.z, caixa.end.z])
			continue
		_conferir(not pegada.intersects(vao),
			"%s: '%s' fica no vão da porta: x [%.2f, %.2f], z [%.2f, %.2f]" % [qual, str(movel.get("nome", "?")),
				caixa.position.x, caixa.end.x, caixa.position.z, caixa.end.z])
	print("  %-15s %.1f x %.1f, pé-direito %.1f, parede %.2f, porta %.2f em x=%.2f, %d móveis" % [qual, sala.largura, sala.comprimento,
		sala.pe_direito, sala.parede, sala.largura_da_porta, sala.porta_x, moveis.size()])

	# --- 5 e 6. ENTRA-SE ANDANDO, E SE SAI ANDANDO ---------------------------------------
	var tampa: StaticBody3D = null
	if falsificar == "porta_fechada":
		tampa = StaticBody3D.new()
		tampa.collision_layer = 1
		var forma := CollisionShape3D.new()
		var caixa := BoxShape3D.new()
		caixa.size = Vector3(sala.largura_da_porta + 0.2, 2.5, 0.3)
		forma.shape = caixa
		tampa.add_child(forma)
		root.add_child(tampa)
		tampa.global_transform = Transform3D(sala.global_basis, sala.to_global(Vector3(sala.porta_x, 1.25, sala.parede + sala.fundo_da_porta + 0.4)))
	var frente: Vector3 = sala.global_basis.z.normalized()
	var rumo := atan2(frente.x, frente.z) - PI
	jogador.teleportar(mundo.ground_position(sala.soleira_de_fora(), 0.05), rumo)
	await _quadros_de_fisica(4)
	_conferir(interiores.dentro() == "", "%s: de pé do lado de fora, o jogo diz que estou dentro de %s" % [qual, interiores.dentro()])
	_menor_camera = INF
	physics_frame.connect(_amostrar_a_camera.bind(camera))
	Input.action_press("mv_forward")
	var entrou: bool = await _ate(func() -> bool: return interiores.dentro() == qual, 9.0)
	await _segundos(0.45)
	if entrou:
		# Segue andando até passar de `FUNDO_DA_ENTRADA` da porta (no máximo 3 s de jogo). Medir só pelo tempo
		# de caminhada reprovava por um palmo (0,88 de 0,9), conforme a cadência dos quadros; móvel no caminho,
		# esse sim, segura o corpo aquém, e o tempo acaba.
		await _ate(func() -> bool: return sala.to_local(jogador.global_position).z < -FUNDO_DA_ENTRADA, 3.0)
	Input.action_release("mv_forward")
	await _quadros_de_fisica(10)
	_conferir(entrou, "%s: andando para a porta, não entrei: o corpo parou em %s" % [qual, str(sala.to_local(jogador.global_position))])
	if entrou:
		var onde: Vector3 = sala.to_local(jogador.global_position)
		_conferir(sala.contem(jogador.global_position), "%s: andei e o corpo não está dentro do cômodo (%s)" % [qual, str(onde)])
		_conferir(jogador.is_on_floor(), "%s: dentro, o corpo não está no chão" % qual)
		_conferir(absf(onde.y) < 0.6, "%s: o corpo está %.2f acima do piso" % [qual, onde.y])
		_conferir(onde.z < -FUNDO_DA_ENTRADA, "%s: entrei, mas parei a %.2f da porta: um móvel fecha o caminho?" % [qual, -onde.z])
		_conferir(jogador.dentro_de == qual, "%s: o jogador não sabe em que casa está" % qual)
		var titulo: String = str(vale.hud.get("_region_label").text)
		_conferir(titulo.to_upper().contains(nome.to_upper()), "%s: dentro, o HUD diz '%s' em vez de '%s'" % [qual, titulo, nome])
		# E de volta: de dentro, de frente para a porta, andando para fora.
		jogador.teleportar(sala.to_global(Vector3(sala.porta_x, 0.05, -1.4)), rumo + PI)
		await _quadros_de_fisica(4)
		Input.action_press("mv_forward")
		var saiu: bool = await _ate(func() -> bool: return interiores.dentro() == "", 9.0)
		await _segundos(0.15)
		Input.action_release("mv_forward")
		_conferir(saiu, "%s: andando para fora, não saí: o corpo parou em %s" % [qual, str(sala.to_local(jogador.global_position))])
	physics_frame.disconnect(_amostrar_a_camera.bind(camera))
	_conferir(_menor_camera >= CAMERA_MAIS_PERTO, "%s: a câmera chegou a %.2f do corpo no caminho (mínimo %.2f): entrou nele" % [qual, _menor_camera, CAMERA_MAIS_PERTO])
	if tampa != null:
		tampa.queue_free()


## Pergunta 7, a casa de farinha: o galpão aberto na frente. Pelo lado esquerdo do forno se entra
## andando — a caixa inteira que fechava o desenho saiu —, e a parede do fundo segura.
func _conferir_o_galpao() -> void:
	var lote := "Casa de farinha"
	_conferir(interiores._galpoes.has("farinha"), "a casa de farinha não ganhou as caixas do galpão")
	if not interiores._galpoes.has("farinha") or not mundo.ancoras.has(lote):
		return
	var base: Vector3 = mundo.ancoras[lote]
	var frente: Vector3 = mundo.ancoras.get(lote + "Frente", Vector3.BACK)
	frente.y = 0.0
	frente = frente.normalized()
	var direita := Vector3.UP.cross(frente).normalized()
	var rumo := atan2(frente.x, frente.z) - PI
	jogador.teleportar(mundo.ground_position(base + frente * 5.6 - direita * 1.8, 0.05), rumo)
	await _quadros_de_fisica(4)
	Input.action_press("mv_forward")
	await _segundos(2.4)
	Input.action_release("mv_forward")
	await _quadros_de_fisica(10)
	var fundo: float = (jogador.global_position - base).dot(frente)
	_conferir(fundo < 2.4, "andando pela frente da casa de farinha, o corpo parou a %.1f do meio do galpão: a frente está fechada" % fundo)
	_conferir(jogador.is_on_floor(), "dentro do galpão da farinha, o corpo não está no chão")
	Input.action_press("mv_forward")
	await _segundos(3.0)
	Input.action_release("mv_forward")
	await _quadros_de_fisica(6)
	fundo = (jogador.global_position - base).dot(frente)
	_conferir(fundo > -2.05, "o corpo atravessou a parede do fundo da casa de farinha: está a %.2f do meio" % fundo)
	_conferir(fundo < 0.0, "andando por dentro do galpão da farinha, o corpo não chegou ao fundo dele (%.2f)" % fundo)


func _amostrar_a_camera(camera: Camera3D) -> void:
	_menor_camera = minf(_menor_camera, camera.global_position.distance_to(jogador.global_position + Vector3.UP * 0.9))


func _fechar() -> void:
	Input.action_release("mv_forward")
	print("")
	if falhas == 0:
		print("CASAS_POR_DENTRO_OK (", _estilo_do_portao(), "): toda casa do vale tem cômodo com o nome nos três idiomas; eles se montam de perto, sozinhos, e somem do desenho longe; cada um tem piso, forro, porta aberta, parede fechada, móveis sólidos fora do vão da porta e a luz de dentro, que não vaza; entra-se andando e sai-se andando de cada um, o corpo no piso, o HUD dizendo onde se está e a câmera longe do corpo; e o casarão da fazenda se alcança pela escadaria de pedra")
	else:
		print("casas_por_dentro (%s): %d falha(s)" % [_estilo_do_portao(), falhas])
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


## Espera a carga inteira do vale (os cômodos de tabela fixa, a fazenda, os moradores).
func _carga_pronta() -> void:
	for i in range(3000):
		if current_scene != null and current_scene.get("carga_ok") == true:
			break
		await process_frame
	await process_frame


func _mundo_pronto() -> void:
	for i in range(3000):
		var no_mundo := get_first_node_in_group("mundo")
		if no_mundo != null and no_mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
