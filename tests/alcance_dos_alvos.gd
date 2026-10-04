extends SceneTree
## Confere que TODO ALVO DE TRABALHO É ALCANÇÁVEL — e diz onde cada um caiu.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/alcance_dos_alvos.gd
##
## Nasceu da queixa "na missão da pedreira, não consegui interagir com o
## objeto". O `tests/ferramentas.gd` já provava que o golpe funciona — mas ele
## TELEPORTA o jogador para cima do alvo. Provar que a mecânica funciona não
## prova que o jogador chega até ela, e era essa a pergunta que faltava.
##
## É o mesmo que o `testar_assentamento` do jogo 2D faz com as peças do mundo:
## toda peça posta tem de ter chão de verdade e caminho a pé.
##
## Quatro perguntas por alvo:
##
##   1. ELE FOI POSTO. Lugar que o `Lugares` não resolve não recebe alvo, e o
##      silêncio disso é o que faz uma missão apontar para o nada.
##   2. ESTÁ EM TERRA FIRME, e não no mar nem afundado no chão.
##   3. HÁ CHÃO LIVRE EM VOLTA. Alvo encravado entre construções é alvo que se
##      vê e não se alcança — a queixa, em uma frase.
##   4. A MISSÃO QUE O PEDE APONTA PARA PERTO DELE. Uma missão de picareta
##      mandando o jogador a duzentas unidades do único lajedo é a mesma
##      queixa por outro caminho.

var falhas := 0
## Raio que o `Recursos3D` usa para aceitar o golpe. Se mudar lá, muda aqui.
const ALCANCE := 3.2
## Quantos pontos em volta do alvo precisam estar livres para dizer que se
## chega a pé. Oito direções; exigir todas seria exigir alvo no meio do campo.
const LIVRES_MINIMO := 3
## Raio do corpo do jogador, medido no `vale.tscn`. É o quanto a colisão o
## mantém afastado da face de qualquer coisa.
const RAIO_DO_CORPO := 0.28
## Encostado num alvo, quanto o segundo mais perto tem de estar além dele. O
## corpo solto escorrega até 0,41 na encosta do mirante (medido em 03/10/2026);
## com menos folga que isso, um passo de lado troca o alvo que o E oferece.
const FOLGA_MINIMA := 0.5
## Os quatro lados de onde se chega a um alvo.
const LADOS := [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("ALCANCE_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK,
		"a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(3)

	var recursos := current_scene.get_node_or_null("Recursos3D")
	var jogador = current_scene.get("player")
	var mundo := get_first_node_in_group("mundo")
	var lugares := root.get_node("/root/Lugares")
	_conferir(recursos != null and mundo != null, "não achei os recursos ou o mundo")
	if recursos == null or mundo == null:
		_fechar()
		return

	# --- 1. TODOS FORAM POSTOS ------------------------------------------------
	var arquivo := FileAccess.open("res://data/recursos_3d.json", FileAccess.READ)
	var dado = JSON.parse_string(arquivo.get_as_text())
	arquivo.close()
	var pedidos: Array = dado.get("recursos", [])
	_conferir(not pedidos.is_empty(), "o JSON de recursos está vazio")

	var postos := 0
	print("")
	for ficha: Dictionary in pedidos:
		var id := str(ficha.get("id", ""))
		var lugar := str(ficha.get("lugar", ""))
		if not recursos._alvos.has(id):
			# Não é falha automática: lugar que o vale ainda não tem é
			# declarado no `Lugares`. Mas é falha se o lugar RESOLVE e o alvo
			# não foi posto, porque aí alguma coisa deu errado ao erguer.
			_conferir(not lugares.resolve(lugar),
				"'%s' aponta para '%s', que existe, e mesmo assim não foi posto" % [id, lugar])
			print("  ausente  %-18s (lugar '%s' não existe no vale)" % [id, lugar])
			continue
		postos += 1

		var alvo: Dictionary = recursos._alvos[id]
		var pos: Vector3 = alvo["pos"]

		# --- 2. EM TERRA FIRME -----------------------------------------------
		var chao := float(mundo.ground_height_at(pos))
		_conferir(absf(pos.y - chao) < 1.5,
			"'%s' está a %.1f do chão (y=%.1f, chão=%.1f)" % [id, pos.y - chao, pos.y, chao])
		var superficie := str(mundo.surface_at(pos))
		_conferir(superficie != "mar" and superficie != "agua",
			"'%s' caiu na água ('%s')" % [id, superficie])

		# --- 3. CHÃO LIVRE EM VOLTA ------------------------------------------
		var livres := _livres_em_volta(pos)
		_conferir(livres >= LIVRES_MINIMO,
			"'%s' tem só %d de 8 direções livres a %.1f u: encravado, o jogador vê e não alcança"
				% [id, livres, ALCANCE])

		print("  posto    %-18s %-14s chão=%.1f  livres=%d/8  superfície=%s"
			% [id, lugar, chao, livres, superficie])

	_conferir(postos > 0, "nenhum alvo foi posto no vale")

	# --- 4. A MISSÃO APONTA PARA PERTO DO ALVO -------------------------------
	#
	# Era a causa da queixa da pedreira: a missão da picareta mandava o jogador
	# ao poço e o lajedo mais perto estava a 225 unidades — mais de novecentos
	# metros de caminhada sem nada no meio.
	print("")
	var missoes := FileAccess.open("res://data/missoes_guia.json", FileAccess.READ)
	var dado_missoes = JSON.parse_string(missoes.get_as_text())
	missoes.close()
	for passo: Dictionary in dado_missoes.get("passos", []):
		var meta: Dictionary = passo.get("meta", {})
		if meta.is_empty() or str(meta.get("tipo", "")) != "juntar":
			continue
		var item := str(meta.get("item", ""))
		var onde: Vector3 = lugares.ponto(str(passo.get("lugar", "")))
		if onde == lugares.NENHUM:
			continue
		# O QUE SAI DA BANCADA não cai de alvo nenhum: a corda da chegada se torce na
		# oficina (docs/mundo/CHEGADA_E_MUTIROES.md). Para ele, o alvo é a bancada, e
		# o passo tem de apontar para perto dela.
		if not (root.get_node("/root/Oficina").dados(item) as Dictionary).is_empty():
			var bancada: Vector3 = lugares.ponto("oficina")
			var ate_a_bancada := INF if bancada == lugares.NENHUM else _plano(onde, bancada)
			print("  missão   %-18s pede %-8s bancada a %.1f u" % [str(passo.get("id", "?")), item, ate_a_bancada])
			_conferir(ate_a_bancada < 40.0,
				"o passo '%s' pede %s, que sai da bancada, e a bancada está a %.1f u do lugar dele"
					% [str(passo.get("id", "?")), item, ate_a_bancada])
			continue
		var menor := INF
		for id in recursos._alvos:
			if str(recursos._alvos[id]["ficha"].get("rende", "")) != item:
				continue
			menor = minf(menor, _plano(onde, recursos._alvos[id]["pos"]))
		if menor == INF:
			_conferir(false, "o passo '%s' pede %s e não há alvo nenhum que renda isso"
				% [str(passo.get("id", "?")), item])
			continue
		print("  missão   %-18s pede %-8s alvo mais perto a %.1f u" % [str(passo.get("id", "?")), item, menor])
		_conferir(menor < 40.0,
			"o passo '%s' pede %s e o alvo mais perto está a %.1f u do lugar dele: caminhada sem motivo"
				% [str(passo.get("id", "?")), item, menor])

	# --- 5. ENCOSTADO NA PEÇA, O ALVO RESPONDE -------------------------------
	#
	# ESTA PERGUNTA FALTAVA, e a falta dela deixou a missão da picareta quebrada
	# por três rodadas com este portão verde.
	#
	# As quatro de cima olham o CHÃO em volta do alvo: se é terra, se está
	# livre, se a missão aponta para perto. Todas passavam. Nenhuma perguntava
	# o que o jogador faz de fato — encostar na coisa e apertar E.
	#
	# O lajedo é a peça `pedras` em tamanho 2,2: a caixa de colisão tem 3,30 do
	# centro até a face. O alcance era 3,20, medido do CENTRO. O corpo para na
	# face, a 3,30, e o golpe pedia 3,20: dez centímetros de folga NEGATIVA.
	# Chão livre não adianta quando o que barra é o próprio alvo.
	#
	# Aqui o jogador é posto onde a colisão o deixaria — encostado na face, mais
	# o corpo dele —, DOS QUATRO LADOS, e se pergunta ao `Recursos3D` qual alvo
	# está ao alcance. Se não for este, por ali ele é inalcançável, seja qual
	# for a aritmética por dentro.
	#
	# SEM FÍSICA, de propósito (#37). A pergunta é de conta — onde o corpo para
	# e o que o alcance aceita dali —, e o corpo solto andava: escorregava na
	# encosta do mirante, e quanto escorregava dependia de quantos passos de
	# física cabiam nos dois quadros de espera. Na bateria cheia, com a máquina
	# ocupada, cabiam outros: o portão reprovava ("o jogo oferece
	# 'erva_mirante_d'") e passava sozinho. O que o corpo anda entra na conta
	# como FOLGA_MINIMA, e não como sorte.
	print("")
	var corpo_solto: bool = jogador.is_physics_processing()
	jogador.set_physics_process(false)
	for id in recursos._alvos.keys():
		var alvo: Dictionary = recursos._alvos[id]
		var meia: float = float(alvo.get("meia_pegada", 0.0))
		var centro: Vector3 = alvo["pos"]
		var vizinho := ""
		var menor_folga := INF
		for lado: Vector3 in LADOS:
			var encostado := centro + lado * (meia + RAIO_DO_CORPO)
			jogador.global_position = encostado
			var respondeu: String = recursos._mais_perto()
			_conferir(respondeu == str(id),
				"encostado no '%s' pelo lado %s o jogo oferece '%s': a peça tem %.2f de pegada e o alcance é %.2f — o corpo para na face antes de o golpe valer, ou outro alvo está mais perto"
					% [str(id), str(lado), respondeu if respondeu != "" else "nada", meia, float(recursos.ALCANCE)])
			var disputa := _disputa(recursos, str(id), encostado)
			if float(disputa[1]) < menor_folga:
				vizinho = str(disputa[0])
				menor_folga = float(disputa[1])
			_conferir(float(disputa[1]) >= FOLGA_MINIMA,
				"encostado no '%s' pelo lado %s o '%s' fica só %.2f além: um passo de lado e o E oferece o outro"
					% [str(id), str(lado), str(disputa[0]), float(disputa[1])])
		print("  braço    %-18s meia-pegada=%.2f  encostado a %.2f  4 lados  %s"
			% [str(id), meia, meia + RAIO_DO_CORPO,
				("vizinho '%s' %.2f além" % [vizinho, menor_folga]) if vizinho != "" else "sem vizinho ao alcance"])
	jogador.set_physics_process(corpo_solto)

	_fechar()


## O alvo que disputa o E com `id` com o jogador em `ponto`: o de menor sobra
## entre os outros ao alcance, e quanto ele fica além de `id`. Sem disputa,
## ["", INF].
func _disputa(recursos: Node, id: String, ponto: Vector3) -> Array:
	var sobra_dele := _plano(ponto, recursos._alvos[id]["pos"]) - float(recursos._alvos[id].get("meia_pegada", 0.0))
	var quem := ""
	var folga := INF
	for outro in recursos._alvos:
		if str(outro) == id:
			continue
		var sobra := _plano(ponto, recursos._alvos[outro]["pos"]) - float(recursos._alvos[outro].get("meia_pegada", 0.0))
		if sobra < float(recursos.ALCANCE) and sobra - sobra_dele < folga:
			quem = str(outro)
			folga = sobra - sobra_dele
	return [quem, folga]


## Quantas das oito direções em volta têm chão livre ao alcance do golpe.
##
## Mede com um raio para baixo a partir da altura do peito: encontrar chão
## quer dizer que ali se pode pisar, e não encontrar quer dizer buraco, água ou
## o telhado de alguma coisa.
func _livres_em_volta(pos: Vector3) -> int:
	var espaco: PhysicsDirectSpaceState3D = current_scene.get_world_3d().direct_space_state
	var livres := 0
	for i in 8:
		var angulo := TAU * float(i) / 8.0
		var ponto := pos + Vector3(cos(angulo), 0.0, sin(angulo)) * ALCANCE
		var de := ponto + Vector3(0.0, 2.0, 0.0)
		var ate := ponto - Vector3(0.0, 3.0, 0.0)
		var pergunta := PhysicsRayQueryParameters3D.create(de, ate)
		var achou: Dictionary = espaco.intersect_ray(pergunta)
		if not achou.is_empty():
			livres += 1
	return livres


func _plano(a: Vector3, b: Vector3) -> float:
	var d := b - a
	d.y = 0.0
	return d.length()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("ALCANCE_OK: todo alvo posto está em terra firme, com chão livre em volta, o braço alcança além da pegada dele dos quatro lados sem outro alvo disputando o E, e toda missão que pede material tem alvo perto do lugar dela")
	else:
		print("alcance: %d falha(s)" % falhas)
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
