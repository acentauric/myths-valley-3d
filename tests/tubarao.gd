extends "res://tests/suite/caso.gd"
## O tubarão existe na água funda, persegue o jogador que nada lá, ataca (tela escura)
## e devolve o jogador à terra firme; o Pedro nunca é alvo.
##
## E É MAIS RÁPIDO QUE QUEM NADA ("o tubarão estava muito lento"): a patrulha passa do
## nado normal do jogador (1,5 u/s), a perseguição passa do nado de corrida dele (3,0)
## e quem foge a nado no fundo é ALCANÇADO. Escapar é voltar para o raso (a lâmina de
## perseguição). A cauda bate no ritmo da velocidade, sobre o repouso do osso, e o
## relógio dele é o do jogo: com o jogo pausado nada conta.
##
## E A MARÉ TIRA O TUBARÃO ("na maré baixa ele some"): o portão roda com o mar na preamar, e a maré vem
## ligada no jogo. No fim, com a maré ligada, ele está à mostra na preamar, SOME na baixa-mar (a lâmina no
## centro do pesqueiro cai uns 0,6 u, e a regra de antes só o tirava abaixo de 1,3 u: ele ficava), volta
## com a cheia, e o pesqueiro é o mesmo em qualquer maré (a escolha mede a água da preamar).
##
## E A PERSEGUIÇÃO TEM TRILHA (#261): enquanto ele persegue, a música de tensão entra por cima da do dia e cresce com a
## proximidade (o `perigo()` do tubarão é o que o `Audio` segue); quando ele alcança, ou o jogador foge para o
## raso, a tensão sai em 4 a 6 s e a trilha do dia, que só tinha abaixado, está no volume cheio e é a mesma de antes.


var relogio: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_assert(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "vale carrega")
	await _frames(6)
	await _mundo_pronto()
	var vale = current_scene
	# O cartão da água funda (#96) para o vale no primeiro nado: aqui o nado é a
	# prova, e o aviso conta como já dado.
	vale._avisou_agua_funda = true
	var world = vale.world
	var player: CharacterBody3D = vale.player
	var tubarao = vale.get_node_or_null("Tubarao")
	_assert(tubarao != null, "tubarão criado")
	var audio = root.get_node("/root/Audio")
	var fases_da_perseguicao: Array[bool] = []
	tubarao.perseguicao_mudou.connect(func(ativa: bool) -> void: fases_da_perseguicao.append(ativa))
	_assert(tubarao.get("_ativo") == true, "tubarão ativo (achou água funda)")
	_assert(tubarao.get("_modelo_tripo") != null, "modelo Tripo do tubarão em uso")
	_assert((tubarao.get("_ossos_cauda") as Array).size() == 2, "rig da cauda em uso")
	var esqueleto: Skeleton3D = tubarao.get("_esqueleto")
	var osso_cauda: int = (tubarao.get("_ossos_cauda") as Array)[0]
	var pose_inicial := esqueleto.get_bone_pose_rotation(osso_cauda)
	var repouso_da_cauda := esqueleto.get_bone_rest(osso_cauda).basis.orthonormalized().get_rotation_quaternion()
	var maior_giro := 0.0
	var maior_desvio := 0.0
	for frame in 24:
		await physics_frame
		maior_giro = maxf(maior_giro, pose_inicial.angle_to(esqueleto.get_bone_pose_rotation(osso_cauda)))
		maior_desvio = maxf(maior_desvio, repouso_da_cauda.angle_to(esqueleto.get_bone_pose_rotation(osso_cauda)))
	_assert(maior_giro > 0.01,
		"cauda do tubarão oscila durante a patrulha")
	# A cauda balança EM CIMA do repouso do osso (amplitude de 0,20 rad): a rotação absoluta
	# do tempo antigo a afastava uns 0,5 rad dele, a cada quadro.
	_assert(maior_desvio < 0.25,
		"a cauda do tubarão se afasta %.2f rad do repouso do osso (o balanço é de 0,20)" % maior_desvio)

	# Mais rápido que o jogador: nas constantes e no nado de verdade.
	var nado_normal: float = player.VELOCIDADE_NADO
	var nado_de_corrida: float = player.VELOCIDADE_NADO * 2.0
	_assert(float(tubarao.VELOCIDADE_PATRULHA) > nado_normal * 1.2,
		"a patrulha do tubarão (%.1f u/s) devia passar do nado normal do jogador (%.1f)" % [tubarao.VELOCIDADE_PATRULHA, nado_normal])
	_assert(float(tubarao.VELOCIDADE_PERSEGUICAO) > nado_de_corrida * 1.2,
		"a perseguição do tubarão (%.1f u/s) devia passar em 20 %% o nado de corrida do jogador (%.1f)" % [tubarao.VELOCIDADE_PERSEGUICAO, nado_de_corrida])
	_assert(float(tubarao.VELOCIDADE_CACA) >= float(tubarao.VELOCIDADE_PERSEGUICAO),
		"a arrancada da caça (%.1f u/s) devia ser a mais rápida" % tubarao.VELOCIDADE_CACA)

	# O relógio dele é o do jogo: pausado, não anda.
	var relogio_antes: float = tubarao.get("_tempo")
	paused = true
	await _frames(30)
	var relogio_na_pausa: float = tubarao.get("_tempo")
	paused = false
	_assert(is_equal_approx(relogio_antes, relogio_na_pausa),
		"o relógio do tubarão andou com o jogo pausado (%.2f para %.2f)" % [relogio_antes, relogio_na_pausa])
	print("TUBARAO: centro %s · lâmina no centro %.2f u · elipse %.1f × %.1f" % [tubarao.get("_centro"), world.water_depth_at(tubarao.get("_centro")), tubarao.get("_a"), tubarao.get("_b")])

	# Terra firme conhecida: o jogador parte da praça (vira a última terra firme).
	await _physics_frames(30)
	var terra: Vector3 = player.global_position
	# Joga o jogador nadando a 12 u do tubarão, em água funda.
	var t: Vector3 = tubarao.global_position
	var fora := Vector3(12.0, 0.0, 0.0)
	var ponto := t + fora
	for tentativa in 12:
		if world.water_depth_at(ponto) > 1.9:
			break
		fora = fora.rotated(Vector3.UP, PI / 6.0)
		ponto = t + fora
	player.global_position = Vector3(ponto.x, world.water_level() - 1.2, ponto.z)
	player.velocity = Vector3.ZERO
	await _physics_frames(20)
	_assert(player.is_swimming(), "jogador nadando na água funda")

	# --- FUGIR A NADO NÃO ADIANTA: o jogador sai nadando de corrida, para longe, pela água
	# funda, e o tubarão o alcança. (Com a perseguição de 2,3 u/s, a mesma de antes, ele
	# ficava para trás e nunca atacava.)
	var fuga := _rota_de_fuga(world, player.global_position, tubarao.global_position)
	print("TUBARAO: rota de fuga %s · %.0f u de água funda" % [str(fuga["rumo"]), fuga["alcance"]])
	_assert(float(fuga["alcance"]) >= 36.0, "não achei 36 u de água funda para o jogador fugir do tubarão (achei %.0f)" % fuga["alcance"])
	var rumo_da_fuga: Vector3 = fuga["rumo"]
	var distancia_inicial := _plano(tubarao.global_position - player.global_position).length()
	var ritmo_maximo := 0.0
	var alcancado := false
	var musica_do_dia: String = audio.musica_atual()
	var primeiro_perigo := -1.0
	var ultimo_perigo := 0.0
	var tensao_diferente_do_perigo := 0.0
	var tensao_tocou := false
	for frame in 1500:
		await physics_frame
		player.global_position += rumo_da_fuga * (nado_de_corrida / float(Engine.physics_ticks_per_second))
		player.velocity = Vector3.ZERO
		ritmo_maximo = maxf(ritmo_maximo, float(tubarao.get("_ritmo")))
		# A música de tensão segue o perigo do tubarão, quadro a quadro, e ele cresce com a proximidade.
		var perigo: float = tubarao.perigo()
		if perigo > 0.0:
			if primeiro_perigo < 0.0:
				primeiro_perigo = perigo
			ultimo_perigo = perigo
			tensao_diferente_do_perigo = maxf(tensao_diferente_do_perigo, absf(float(audio.tensao_atual()) - perigo))
			tensao_tocou = tensao_tocou or audio.tensao_tocando()
		if tubarao.get("_atacando") == true:
			alcancado = true
			print("TUBARAO: alcançou quem fugia a %.1f u/s depois de %.1f s (%.0f u de distância no começo)" % [nado_de_corrida, frame / 60.0, distancia_inicial])
			break
	_assert(alcancado, "o tubarão não alcançou quem fugia a nado de corrida (%.1f u/s) em 25 s" % nado_de_corrida)
	_assert(ritmo_maximo > 1.5, "a cauda não bateu mais depressa na perseguição (ritmo %.2f)" % ritmo_maximo)
	_assert(primeiro_perigo > 0.0, "o tubarão perseguiu e não fez perigo nenhum: a música de tensão não tem o que seguir")
	_assert(ultimo_perigo > primeiro_perigo + 0.05, "o perigo não cresceu com a proximidade (%.2f no começo, %.2f na mordida)" % [primeiro_perigo, ultimo_perigo])
	_assert(tensao_diferente_do_perigo < 0.001, "o Audio não segue o perigo do tubarão (diferença de %.3f)" % tensao_diferente_do_perigo)
	_assert(tensao_tocou, "a camada de tensão não tocou durante a perseguição")
	_assert(audio.musica_atual() == musica_do_dia, "a perseguição trocou a trilha do dia (%s para %s)" % [musica_do_dia.get_file(), audio.musica_atual().get_file()])
	await create_timer(2.5).timeout
	_assert(tubarao.get("_atacando") == false and not player.is_swimming(), "depois do ataque o jogador devia estar em terra firme")
	# Passou o perigo: a tensão sai em 4 a 6 s (já vão 2,5 s do ataque), e a trilha do dia volta inteira e a mesma.
	_assert(audio.tensao_atual() == 0.0, "mordido e devolvido à terra, o tubarão ainda faz perigo (%.2f)" % audio.tensao_atual())
	await create_timer(audio.SAIDA_DA_TENSAO).timeout
	_assert(not audio.tensao_tocando(), "a camada de tensão seguiu tocando %.1f s depois do perigo" % (audio.SAIDA_DA_TENSAO + 2.5))
	_assert(is_equal_approx(float(audio._abafo_da_tensao), 1.0), "a trilha do dia não voltou ao volume cheio (%.2f)" % float(audio._abafo_da_tensao))
	_assert(audio.musica_atual() == musica_do_dia, "a trilha do dia não é a mesma de antes da perseguição")
	_assert(fases_da_perseguicao.size() >= 2 and fases_da_perseguicao[0] == true and fases_da_perseguicao[fases_da_perseguicao.size() - 1] == false,
		"o sinal perseguicao_mudou não contou a perseguição (%s)" % str(fases_da_perseguicao))
	# Outra rodada: o susto passou, o cooldown do ataque é do jogo e o portão o zera.
	tubarao.set("_proximo_ataque", 0.0)
	player.global_position = Vector3(ponto.x, world.water_level() - 1.2, ponto.z)
	player.velocity = Vector3.ZERO
	await _physics_frames(20)
	_assert(player.is_swimming(), "jogador nadando na água funda (segunda rodada)")
	var d0 := Vector2(tubarao.global_position.x - player.global_position.x, tubarao.global_position.z - player.global_position.z).length()
	var atacou := false
	var mensagens: Array[String] = []
	var d_min := d0
	for frame in 1800:
		await physics_frame
		var d := Vector2(tubarao.global_position.x - player.global_position.x, tubarao.global_position.z - player.global_position.z).length()
		d_min = minf(d_min, d)
		if tubarao.get("_atacando") == true:
			atacou = true
			break
	print("TUBARAO: distância inicial %.1f · mínima %.1f · atacou %s" % [d0, d_min, atacou])
	_assert(atacou, "tubarão alcança e ataca quem nada no fundo")
	# Espera a sequência do susto terminar (~1,6 s) e confere o resgate.
	await create_timer(2.5).timeout
	var lamina_depois: float = world.water_depth_at(player.global_position)
	print("TUBARAO: depois do ataque em %s · lâmina %.2f · nadando %s" % [player.global_position, lamina_depois, player.is_swimming()])
	_assert(not player.is_swimming() and lamina_depois < 0.8, "jogador volta à terra firme")
	_assert(tubarao.get("_atacando") == false, "susto termina")

	# --- A MARÉ TIRA O TUBARÃO -------------------------------------------------------
	# `load()` depois de o vale subir: um `preload` aqui compila antes dos autoloads (AGENTS.md).
	relogio = load("res://tests/fixtures/relogio_de_jogo.gd").new()
	root.add_child(relogio)
	var mare := root.get_node("/root/Mare")
	var dia := root.get_node("/root/Dia")
	mare.modo = 1
	dia.pausado = true
	var preamar_h: float = float(mare.fase_da_preamar_h)
	dia.definir_hora(preamar_h)
	await relogio.esperar(2.0)
	_assert(tubarao.get("_submerso") == false and tubarao.visible,
		"na preamar o tubarão não está à mostra (lâmina no centro %.2f u)" % world.water_depth_at(tubarao.get("_centro")))
	var centro_da_cheia: Vector3 = tubarao.get("_centro")
	var lamina_da_cheia: float = world.water_depth_at(centro_da_cheia)
	dia.definir_hora(fposmod(preamar_h + 6.0, 24.0))
	await relogio.esperar(2.0)
	var lamina_da_baixa: float = world.water_depth_at(centro_da_cheia)
	print("TUBARAO: lâmina no centro do pesqueiro %.2f u na preamar, %.2f u na baixa-mar" % [lamina_da_cheia, lamina_da_baixa])
	_assert(lamina_da_cheia - lamina_da_baixa > 0.5, "a maré não baixou a água sobre o pesqueiro (%.2f → %.2f u)" % [lamina_da_cheia, lamina_da_baixa])
	_assert(tubarao.get("_submerso") == true and not tubarao.visible,
		"na baixa-mar (lâmina de %.2f u no centro) o tubarão continua à mostra: some com menos de %.2f u" % [lamina_da_baixa, tubarao.LAMINA_FUNDA + tubarao.FOLGA_DA_SAIDA])
	# O pesqueiro não depende da hora em que o vale se monta: escolhido na baixa-mar, cai no mesmo lugar.
	tubarao._procurar_pesqueiro()
	var centro_da_baixa: Vector3 = tubarao.get("_centro")
	_assert(Vector2(centro_da_baixa.x - centro_da_cheia.x, centro_da_baixa.z - centro_da_cheia.z).length() < 0.01,
		"o pesqueiro mudou de lugar com a maré: %s na preamar, %s na baixa-mar" % [str(centro_da_cheia), str(centro_da_baixa)])
	dia.definir_hora(preamar_h)
	await relogio.esperar(2.0)
	_assert(tubarao.get("_submerso") == false and tubarao.visible, "com a cheia de volta o tubarão não voltou")
	mare.modo = 0
	_calar_a_tensao(audio)
	print("TUBARAO_OK")
	quit()


func _assert(condition: bool, label: String) -> void:
	if not condition:
		push_error("TUBARAO_FALHOU: " + label)
		quit(1)
		assert(false, label)


## O caso devolve o que mexe: a camada da tensão é um nó filho do autoload `Audio`, e o anfitrião só devolve variáveis.
func _calar_a_tensao(audio) -> void:
	audio.tensao_do_tubarao(0.0)
	if audio._tensao_transicao != null and audio._tensao_transicao.is_valid():
		audio._tensao_transicao.kill()
	audio._tensao_envelope = 0.0
	audio._tensao.stop()


## A rota de fuga: o rumo (plano) que se afasta do tubarão e segue por água funda
## (lâmina de mais de 1,9 u) por mais tempo, e quanto ela dura.
func _rota_de_fuga(world, de: Vector3, do_tubarao: Vector3) -> Dictionary:
	var afastar := _plano(de - do_tubarao).normalized()
	var melhor := {"rumo": afastar, "alcance": 0.0}
	for g in 36:
		var rumo := Vector3.RIGHT.rotated(Vector3.UP, g * TAU / 36.0)
		if rumo.dot(afastar) < 0.3:
			continue
		var alcance := 0.0
		while alcance < 80.0 and world.water_depth_at(de + rumo * (alcance + 2.0)) > 1.9:
			alcance += 2.0
		if alcance > float(melhor["alcance"]):
			melhor = {"rumo": rumo, "alcance": alcance}
	return melhor


func _plano(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame


func _physics_frames(count: int) -> void:
	for frame in range(count):
		await physics_frame


## O vale se monta ao longo de vários quadros (world_builder): espera ficar pronto.
func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
