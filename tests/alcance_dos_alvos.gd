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
##
## E uma sexta, que nasceu da queixa de 06/10/2026 ("os dois troncos da casa de
## taipa não dá para chegar"): O CLIQUE CHEGA (seção 6). As cinco de cima olham
## o chão, o braço e as contas; nenhuma andava o caminho que o jogador escolhe
## com o mouse. Os dois troncos ficavam num canto de paredes, cerca e bananeiras
## atrás da casa, e a grade do clique tinha a casa inteira por chão livre: o
## caminho acabava DENTRO dela, junto da porta trancada, e o corpo parava na
## parede. Agora cada lado de cada alvo é provado pelo clique.

var falhas := 0
## Raio que o `Recursos3D` usa para aceitar o golpe. Se mudar lá, muda aqui.
const ALCANCE := 3.2
## E o do GOLPE (#208): da face do alvo ao corpo, no máximo isto, e o E de mais longe anda até lá.
const ALCANCE_DO_GOLPE := 1.2
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
## SEÇÃO 6, O CLIQUE. Todo alvo tem de ser alcançado pelo clique de ao menos um lado (exigir os quatro
## de todo alvo seria exigir alvo no meio do campo, como o `LIVRES_MINIMO` acima); os alvos que a
## queixa de 06/10/2026 nomeou exigem os quatro.
const QUATRO_LADOS := ["lenha_rocado_a", "lenha_rocado_b"]
## O QUE JÁ SE SABE E NÃO SE CORRIGE AQUI (dados de outro dono), com a razão: o portão imprime e não reprova, e
## reprova se o alvo passar a ser alcançado — a lista não apodrece.
const CLIQUE_NAO_CHEGA := {
	"ostra_pedras_a": "a ostra fica DENTRO da caixa de colisão das pedras da praia (8,9 x 6,3 u, `Pedras Praia`): nenhum ponto de pisar a 3 u é chão livre; só se alcança pela beira do raso, e a grade do clique (células de 2,5 u) não acha o caminho estreito da praia",
	"ostra_pedras_c": "a ostra fica na quina da caixa das pedras da praia, e a faixa de areia entre a caixa e o mar, onde se pisa, é estreita demais para a grade do clique (células de 2,5 u, folga de 0,55): o clique não acha caminho até lá, e as setas, sim",
}
## Quanto além do alcance o caminho do clique pode acabar: a grade tem células de 2,5 u e o caminho
## acaba no centro da última — o último passo é do teclado. Os troncos que a queixa nomeou exigem o
## caminho a menos de meia unidade do alcance (3,7); os outros alvos, o clique "perto" (6,0: duas
## células), porque há pedra em barranco e alvo no meio de lápides onde a grade acaba um pouco antes.
## A fresta da casa de taipa não era questão de metro: o caminho entrava na casa, e isso reprova em
## qualquer régua (o caminho tem de ser limpo).
const SOBRA_DO_CLIQUE := 6.0
const SOBRA_DOS_TRONCOS := 3.7
## De que distância o jogador parte para cada prova, quantas partidas se tentam, e de quanto em quanto
## se confere o caminho.
const PARTIDA := 16.0
const PARTIDAS := 6
const PASSO_DA_AMOSTRA := 0.5


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
		# O passo de vários itens da chegada (as ferramentas do finado) pega do baú
		# da casa: não há alvo a alcançar.
		if onde == lugares.NENHUM or item == "":
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
			# ONDE O CORPO PARA é a face de verdade da colisão (caixa girada, quina) mais o corpo, e
			# não a meia-pegada: o tronco girado a 90° tem a face a 0,25 do centro (#208).
			var encostado := _encostado(recursos, str(id), centro, lado)
			jogador.global_position = encostado
			var respondeu: String = recursos._mais_perto()
			_conferir(respondeu == str(id),
				"encostado no '%s' pelo lado %s o jogo oferece '%s': o alcance do E é %.2f da face — o corpo para na face antes de o E valer, ou outro alvo está mais perto"
					% [str(id), str(lado), respondeu if respondeu != "" else "nada", float(recursos.ALCANCE)])
			# O GOLPE É DE BRAÇO (#208): encostado, a face está ao alcance curto do golpe — e o ponto
			# de parar do E de longe (`ponto_de_golpe`) também, sem entrar na peça.
			var da_face: float = recursos.distancia_da_face(str(id), encostado)
			_conferir(da_face <= ALCANCE_DO_GOLPE,
				"encostado no '%s' pelo lado %s a face está a %.2f, além do alcance curto do golpe (%.2f)" % [str(id), str(lado), da_face, ALCANCE_DO_GOLPE])
			var parada: Vector3 = recursos.ponto_de_golpe(str(id), lado)
			var da_parada: float = recursos.distancia_da_face(str(id), parada) if parada.is_finite() else INF
			_conferir(parada.is_finite() and da_parada <= ALCANCE_DO_GOLPE and da_parada >= RAIO_DO_CORPO,
				"o ponto de parar do E de longe no '%s' pelo lado %s fica a %.2f da face: tem de ficar entre o corpo (%.2f) e o alcance do golpe (%.2f)" % [str(id), str(lado), da_parada, RAIO_DO_CORPO, ALCANCE_DO_GOLPE])
			var disputa := _disputa(recursos, str(id), encostado)
			if float(disputa[1]) < menor_folga:
				vizinho = str(disputa[0])
				menor_folga = float(disputa[1])
			_conferir(float(disputa[1]) >= FOLGA_MINIMA,
				"encostado no '%s' pelo lado %s o '%s' fica só %.2f além: um passo de lado e o E oferece o outro"
					% [str(id), str(lado), str(disputa[0]), float(disputa[1])])
		print("  braço    %-18s meia-pegada=%.2f  encostado pela face  4 lados  %s"
			% [str(id), meia,
				("vizinho '%s' %.2f além" % [vizinho, menor_folga]) if vizinho != "" else "sem vizinho ao alcance"])
	jogador.set_physics_process(corpo_solto)

	# --- 6. O CLIQUE CHEGA AO BRAÇO ------------------------------------------
	print("")
	jogador.set_physics_process(false)
	await _o_clique_chega(recursos, mundo, jogador)

	# --- 7. A CASA É BLOCO PARA QUEM PASSA POR FORA --------------------------
	print("")
	await _a_casa_e_bloco(mundo, jogador)
	jogador.set_physics_process(corpo_solto)

	_fechar()


## SEÇÃO 6. O jogador parte de um ponto livre a `PARTIDA` u do alvo e clica ao lado dele, de cada um
## dos quatro lados. Um lado "chega" quando algum ponto de pisar do braço (`_pontos_do_lado`) tem um
## caminho de clique que acaba ao alcance (`SOBRA_DO_CLIQUE`) e é LIMPO — nenhum ponto dele, de meio em
## meio metro, dentro de um corpo sólido ou de um cômodo de casa. É o caminho limpo que pega a fresta:
## um caminho que acaba "perto" mas por dentro da casa passava por perto e mesmo assim o corpo parava
## na parede. Tenta-se mais de uma partida (o cemitério tem cerca: de fora o clique acaba nela, e de
## dentro chega); vale a melhor.
func _o_clique_chega(recursos: Node, mundo: Node, jogador: Node) -> void:
	var provas: Dictionary = await _provar_o_clique(recursos._alvos.keys(), recursos, mundo, jogador)
	# A MARÉ: o portão roda com o mar na preamar, e a ostra das pedras da maré fica na beira — em volta dela é água
	# e a grade só anda em terra. O alvo que o clique não alcança na cheia tem a baixa-mar: o jogador espera a
	# água descer, e a grade se refaz com a beira seca (`configure`).
	var pendentes: Array = []
	for id in provas:
		if not bool(provas[id]["ok"]):
			pendentes.append(id)
	var na_baixa: Dictionary = {}
	if not pendentes.is_empty():
		var mare := root.get_node("/root/Mare")
		var dia := root.get_node("/root/Dia")
		mare.modo = 1
		dia.pausado = true
		dia.definir_hora(fposmod(float(mare.fase_da_preamar_h) + 6.0, 24.0))
		await _frames(6)
		jogador._navigator.configure(mundo)
		na_baixa = await _provar_o_clique(pendentes, recursos, mundo, jogador)
		mare.modo = 0
		dia.definir_hora(float(mare.fase_da_preamar_h))
		await _frames(6)
		jogador._navigator.configure(mundo)
	var provados := 0
	for id in provas:
		var cheia: Dictionary = provas[id]
		var baixa: Dictionary = na_baixa.get(id, {})
		var ok: bool = bool(cheia["ok"]) or bool(baixa.get("ok", false))
		var onde := "" if bool(cheia["ok"]) else " (só na baixa-mar)"
		if CLIQUE_NAO_CHEGA.has(str(id)):
			_conferir(not ok, "'%s' está em CLIQUE_NAO_CHEGA e o clique já o alcança: tire da lista" % str(id))
			print("  clique   %-18s CONHECIDO, o clique não chega: %s" % [str(id), str(CLIQUE_NAO_CHEGA[str(id)])])
			continue
		_conferir(ok,
			"'%s' (%s): o clique chega ao braço por %d dos %d lados exigidos na cheia e por %d na baixa-mar (melhor partida %s, de %d tentadas) — cheia: %s — baixa-mar: %s"
				% [str(id), str(cheia["centro"]), maxi(int(cheia["melhor"]), 0), int(cheia["exigidos"]), maxi(int(baixa.get("melhor", 0)), 0),
					str((cheia["partida"] as Vector3).snapped(Vector3.ONE * 0.1)), int(cheia["partidas"]),
					" | ".join(cheia["motivos"]) if not (cheia["motivos"] as PackedStringArray).is_empty() else "nenhuma partida livre a %.0f u" % PARTIDA,
					" | ".join(baixa["motivos"]) if baixa.has("motivos") and not (baixa["motivos"] as PackedStringArray).is_empty() else "-"])
		provados += 1
		print("  clique   %-18s %d/4 lados chegam ao braço%s%s" % [str(id), maxi(int(cheia["melhor"]), 0) if bool(cheia["ok"]) else maxi(int(baixa.get("melhor", 0)), 0), onde,
			"" if (cheia["motivos"] as PackedStringArray).is_empty() or not bool(cheia["ok"]) else "   [" + " | ".join(cheia["motivos"]) + "]"])
	_conferir(provados > 0, "o clique não provou alvo nenhum")


## A prova de cada alvo de `ids`: de quantos lados o clique o alcança, com a melhor partida, e se bastou.
## Devolve id → {"ok", "melhor", "exigidos", "centro", "partida", "partidas", "motivos"}.
func _provar_o_clique(ids: Array, recursos: Node, mundo: Node, jogador: Node) -> Dictionary:
	var regiao = mundo.get("_region")
	var interiores := get_first_node_in_group("interiores")
	var navegador = jogador._navigator
	var provas: Dictionary = {}
	for id in ids:
		var alvo: Dictionary = recursos._alvos[id]
		var centro: Vector3 = alvo["pos"]
		var meia: float = float(alvo.get("meia_pegada", 0.0))
		var exigidos := 4 if QUATRO_LADOS.has(str(id)) else 1
		var limite := SOBRA_DOS_TRONCOS if QUATRO_LADOS.has(str(id)) else SOBRA_DO_CLIQUE
		# A mata só tem corpo num raio de 28 u do jogador: ele vai para junto do alvo antes de se escolher a partida.
		await _levar_o_jogador(jogador, regiao, centro + Vector3(0.0, 0.5, 0.0))
		var partidas := _escolher_as_partidas(mundo, jogador, interiores, centro)
		var melhor := -1
		var da_melhor := Vector3.INF
		var motivos_da_melhor: PackedStringArray = []
		for partida in partidas:
			await _levar_o_jogador(jogador, regiao, partida + Vector3(0.0, 0.1, 0.0))
			var lados_ok := 0
			var motivos: PackedStringArray = []
			for lado: Vector3 in LADOS:
				var razao := _porque_o_lado_nao_chega(navegador, mundo, jogador, interiores, partida, centro, meia, lado, limite)
				if razao == "":
					lados_ok += 1
				else:
					motivos.append("%s: %s" % [str(lado), razao])
			if lados_ok > melhor:
				melhor = lados_ok
				da_melhor = partida
				motivos_da_melhor = motivos
			if melhor >= exigidos:
				break
		provas[id] = {"ok": melhor >= exigidos, "melhor": melhor, "exigidos": exigidos, "centro": centro,
			"partida": da_melhor, "partidas": partidas.size(), "motivos": motivos_da_melhor}
	return provas


## Põe o jogador em `onde` (sem física) e dá à mata o tempo de ganhar corpo em volta dele.
func _levar_o_jogador(jogador: Node, regiao: Node, onde: Vector3) -> void:
	jogador.global_position = onde
	jogador.velocity = Vector3.ZERO
	for i in 2:
		if regiao != null:
			regiao._refresh_tree_collisions()
		await physics_frame
		await physics_frame


## Até `PARTIDAS` pontos livres e andáveis a `PARTIDA` u do alvo, de direções diferentes (e, se a esse raio não
## houver nenhum, um pouco mais longe e um pouco mais perto).
func _escolher_as_partidas(mundo: Node, jogador: Node, interiores: Node, centro: Vector3) -> Array[Vector3]:
	var achadas: Array[Vector3] = []
	for raio in [PARTIDA, PARTIDA + 6.0, PARTIDA - 6.0]:
		for k in 8:
			var rumo := TAU * float(k) / 8.0
			var ponto: Vector3 = mundo.ground_position(centro + Vector3(cos(rumo), 0.0, sin(rumo)) * raio)
			if mundo.is_walkable_point(ponto) and _corpo_em(jogador, ponto) == "" \
					and (interiores == null or interiores.contem(ponto) == ""):
				achadas.append(ponto)
				if achadas.size() >= PARTIDAS:
					return achadas
		if not achadas.is_empty():
			break
	return achadas


## Os pontos de pisar de um lado do alvo, do mais perto (colado na face, onde o corpo para) ao mais longe do
## que o braço alcança, e de viés para cada lado: o capim ao lado da lápide tem corpo na face e chão livre
## dois passos adiante.
func _pontos_do_lado(mundo: Node, jogador: Node, centro: Vector3, meia: float, lado: Vector3) -> Array[Vector3]:
	var pontos: Array[Vector3] = []
	for raio in [meia + RAIO_DO_CORPO + 0.3, meia + 1.4, meia + 2.2, meia + 2.9]:
		for desvio in [0.0, 0.35, -0.35, 0.7, -0.7]:
			pontos.append(_superficie(mundo, jogador, centro + lado.rotated(Vector3.UP, desvio) * raio, centro.y))
	return pontos


## A SUPERFÍCIE em que o jogador pisa em (x, z): a de cima do que houver abaixo de `y_do_alvo` mais 1,5 (o topo
## da pedra onde a ostra está, o alto da lombada) e, sem nada, o chão do terreno. É a conta de `tests/fixtures/jogada.gd`.
func _superficie(mundo: Node, jogador: Node, ponto: Vector3, y_do_alvo: float) -> Vector3:
	var pergunta := PhysicsRayQueryParameters3D.create(Vector3(ponto.x, y_do_alvo + 1.5, ponto.z), Vector3(ponto.x, y_do_alvo - 3.0, ponto.z), 1, [(jogador as CollisionObject3D).get_rid()])
	var achou: Dictionary = current_scene.get_world_3d().direct_space_state.intersect_ray(pergunta)
	if not achou.is_empty() and achou["collider"] is not CharacterBody3D:
		return (achou["position"] as Vector3) + Vector3(0.0, 0.03, 0.0)
	return mundo.ground_position(ponto)


## Por que o clique não chega ao braço do alvo por este lado, ou "" se algum ponto de pisar dele chega. Quando
## nenhum chega, a razão é a do primeiro (o colado na face).
func _porque_o_lado_nao_chega(navegador, mundo: Node, jogador: Node, interiores: Node, partida: Vector3, centro: Vector3, meia: float, lado: Vector3, limite: float) -> String:
	var primeira := ""
	for ponto in _pontos_do_lado(mundo, jogador, centro, meia, lado):
		var razao := _porque_o_clique_nao_chega(navegador, mundo, jogador, interiores, partida, ponto, centro, meia, limite)
		if razao == "":
			return ""
		if primeira == "":
			primeira = razao
	return primeira


## Por que o clique de `partida` a `ponto` não chega ao braço do alvo, ou "" se chega.
func _porque_o_clique_nao_chega(navegador, mundo: Node, jogador: Node, interiores: Node, partida: Vector3, ponto: Vector3, centro: Vector3, meia: float, limite: float) -> String:
	if not mundo.is_walkable_point(ponto):
		return "o ponto de pisar %s não é andável" % str(ponto.snapped(Vector3.ONE * 0.1))
	var barra := _corpo_em(jogador, ponto)
	if barra != "":
		return "o ponto de pisar %s tem corpo (%s)" % [str(ponto.snapped(Vector3.ONE * 0.1)), barra]
	var caminho: PackedVector3Array = navegador.find_path(partida, ponto)
	if caminho.is_empty():
		return "o clique não acha caminho até %s" % str(ponto.snapped(Vector3.ONE * 0.1))
	var fim: Vector3 = caminho[caminho.size() - 1]
	var sobra := _plano(fim, centro) - meia
	if sobra > limite:
		return "o caminho acaba em %s, a %.1f do braço (cabe %.1f)" % [str(fim.snapped(Vector3.ONE * 0.1)), sobra, limite]
	return _porque_o_caminho_suja(caminho, partida, mundo, jogador, interiores)


## O caminho LIMPO: de meio em meio metro, nada sólido e nenhum cômodo. Devolve por que não é, ou "".
func _porque_o_caminho_suja(caminho: PackedVector3Array, partida: Vector3, mundo: Node, jogador: Node, interiores: Node) -> String:
	var anterior := partida
	for vertice in caminho:
		var trecho := _plano(anterior, vertice)
		var amostras := maxi(int(ceil(trecho / PASSO_DA_AMOSTRA)), 1)
		for k in range(1, amostras + 1):
			var amostra: Vector3 = mundo.ground_position(anterior.lerp(vertice, float(k) / float(amostras)))
			var comodo: String = interiores.contem(amostra) if interiores != null else ""
			if comodo != "":
				return "o caminho entra no cômodo '%s' em %s" % [comodo, str(amostra.snapped(Vector3.ONE * 0.1))]
			var corpo := _corpo_em(jogador, amostra)
			if corpo != "":
				return "o caminho atravessa %s em %s" % [corpo, str(amostra.snapped(Vector3.ONE * 0.1))]
		anterior = vertice
	return ""


## O nome ("pai/corpo") do primeiro sólido que o corpo do jogador encontraria em `ponto` — fora o chão, e fora
## o que anda sozinho (morador, bicho) —, ou "". A esfera é a do corpo (0,3), medida 0,7 acima do chão: o que o
## corpo sobe sem pular (a soleira, o degrau de 0,4) não é parede.
func _corpo_em(jogador: Node, ponto: Vector3) -> String:
	var esfera := SphereShape3D.new()
	esfera.radius = 0.3
	var pergunta := PhysicsShapeQueryParameters3D.new()
	pergunta.shape = esfera
	pergunta.transform = Transform3D(Basis.IDENTITY, ponto + Vector3(0.0, 0.7, 0.0))
	pergunta.collision_mask = 1
	pergunta.exclude = [(jogador as CollisionObject3D).get_rid()]
	var achados: Array[Dictionary] = current_scene.get_world_3d().direct_space_state.intersect_shape(pergunta, 6)
	for achado in achados:
		var corpo = achado.get("collider")
		if corpo is not Node or corpo is CharacterBody3D:
			continue
		var nome := String((corpo as Node).name)
		if nome.begins_with("Colisão ") or nome == "Chão do mar" or nome == "Borda do quadro":
			continue
		var pai := String((corpo as Node).get_parent().name) if (corpo as Node).get_parent() != null else ""
		return "%s/%s" % [pai, nome]
	return ""


## SEÇÃO 7. A causa da fresta da casa de taipa: a grade do clique tinha a casa inteira por chão livre (as paredes
## moram nos interiores, e o `AlvoCasa` é uma `Area3D`), e o caminho de um lado ao outro da casa ENTRAVA NELA. De
## cada lado de cada casa, a `LONGE` u da pegada, o clique vai ao lado oposto — de frente para os fundos, e de uma
## empena à outra —, e o caminho que achar não pode entrar em cômodo nem atravessar corpo. Par sem caminho (cerca,
## mata, água no meio) não conta: aqui se pergunta pelo caminho que EXISTE.
const LONGE_DA_CASA := 6.0
const CASAS_MINIMAS := 4


func _a_casa_e_bloco(mundo: Node, jogador: Node) -> void:
	var interiores := get_first_node_in_group("interiores")
	var navegador = jogador._navigator
	var provados := 0
	for casa in get_nodes_in_group("interactive_house"):
		if casa is not Node3D or not casa.has_meta("house_bounds"):
			continue
		var limites: Vector3 = casa.get_meta("house_bounds")
		var nome := str((casa.get_meta("house_properties", {}) as Dictionary).get("name", casa.name))
		for eixo in [Vector3.BACK, Vector3.RIGHT]:
			var meio := (limites.z if eixo == Vector3.BACK else limites.x) * 0.5 + LONGE_DA_CASA
			var a: Vector3 = mundo.ground_position((casa as Node3D).to_global(eixo * meio))
			var b: Vector3 = mundo.ground_position((casa as Node3D).to_global(-eixo * meio))
			var livres := true
			for ponto: Vector3 in [a, b]:
				if not mundo.is_walkable_point(ponto) or _corpo_em(jogador, ponto) != "":
					livres = false
				if interiores != null and interiores.contem(ponto) != "":
					livres = false
			if not livres:
				continue
			var caminho: PackedVector3Array = navegador.find_path(a, b)
			if caminho.is_empty():
				continue
			provados += 1
			var suja := _porque_o_caminho_suja(caminho, a, mundo, jogador, interiores)
			_conferir(suja == "", "de um lado ao outro da casa '%s' (%s a %s) o clique faz um caminho que não é limpo: %s"
				% [nome, str(a.snapped(Vector3.ONE * 0.1)), str(b.snapped(Vector3.ONE * 0.1)), suja])
			print("  casa     %-26s %s  %d pontos, %s" % [nome, "de frente para os fundos" if eixo == Vector3.BACK else "de empena a empena", caminho.size(), "limpo" if suja == "" else suja])
	_conferir(provados >= CASAS_MINIMAS, "só %d travessias de casa tinham caminho: a prova da casa-bloco não prova nada" % provados)


## O alvo que disputa o E com `id` com o jogador em `ponto`: o de menor sobra
## entre os outros ao alcance, e quanto ele fica além de `id`. Sem disputa,
## ["", INF].
func _disputa(recursos: Node, id: String, ponto: Vector3) -> Array:
	var sobra_dele: float = recursos.distancia_da_face(id, ponto)
	var quem := ""
	var folga := INF
	for outro in recursos._alvos:
		if str(outro) == id:
			continue
		var sobra: float = recursos.distancia_da_face(str(outro), ponto)
		if sobra < float(recursos.ALCANCE) and sobra - sobra_dele < folga:
			quem = str(outro)
			folga = sobra - sobra_dele
	return [quem, folga]


## Onde o corpo para ao encostar no alvo `id` pelo `lado`: o primeiro ponto, saindo do centro,
## cuja distância à face da colisão alcança o raio do corpo.
func _encostado(recursos: Node, id: String, centro: Vector3, lado: Vector3) -> Vector3:
	var t := 0.0
	while t < 30.0:
		var ponto := centro + lado * t
		if float(recursos.distancia_da_face(id, ponto)) >= RAIO_DO_CORPO:
			return ponto
		t += 0.02
	return centro + lado * RAIO_DO_CORPO


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
		print("ALCANCE_OK: todo alvo posto está em terra firme, com chão livre em volta, o braço alcança além da pegada dele dos quatro lados sem outro alvo disputando o E, o caminho do clique chega ao braço por caminho limpo (sem atravessar casa nem corpo) por ao menos um lado — pelos quatro, nos troncos do roçado —, a casa é bloco para quem passa por fora dela e toda missão que pede material tem alvo perto do lugar dela")
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
