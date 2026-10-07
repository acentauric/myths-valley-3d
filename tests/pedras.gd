extends SceneTree
## PEDRA QUE SE QUEBRA É PEQUENA; PEDRA GRANDE É CENÁRIO.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/pedras.gd
##
## Do playtest da Build 9B: "algumas pedras que são quebráveis estão grandes
## demais, precisam ficar pequenas; precisamos de pedras quebráveis pequenas e
## grandes não quebráveis."
##
## O defeito, em números: o lajedo do poço e o do roçado eram a peça `pedras` em
## tamanho 2,2 — 6,6 de largura por 4,1 de altura, mais alto que o jogador e do
## tamanho de uma casa —, a pedra dura tinha 3,9 × 2,4 e o matacão 5,4 × 3,4. Todos
## quebravam na picareta e SUMIAM depois do último golpe. Além de feio, o pé do
## lajedo (a meia-pegada de 3,3) roubava o E de quem estava junto do poço.
##
## A REGRA: pedra que rende pedra e se quebra cabe na mão — até 1,25 de largura e
## 0,8 de altura, que vai da canela à coxa do jogador (1,75). As soltas postas medem
## de 0,6 a 0,75. As grandes ficam no
## mundo como CENÁRIO: com o corpo do tamanho do desenho, e sem E, sem golpe e sem
## voto no foco do E. A única exceção é a lapa da lombada, que é a pedra da missão:
## atravessada no pé da rampa, trava a subida até rachar.
##
## Sete perguntas:
##
##   1. TODA PEDRA QUE SE QUEBRA É PEQUENA, medida no modelo posto no vale, e a
##      exceção é uma só, com a razão escrita na ficha.
##   2. TODA PEDRA GRANDE É CENÁRIO: está no mundo, com corpo, e não é alvo.
##   3. DO LADO DE UMA PEDRA GRANDE O E NÃO BATE: nem dica, nem golpe, nem voto.
##   4. A PEDRA SOLTA NÃO BRIGA PELO E: a meia-pegada dela é pequena, e nenhuma
##      nasce dentro (ou encostada) numa pedra grande, onde ninguém a alcançaria.
##   5. AS PEDRAS DA MISSÃO SE COLHEM DE VERDADE: com a picareta na mão, golpe a
##      golpe, as do poço e as do roçado caem, dão a pedra que a missão pede — e a
##      pedra grande continua lá —, e a mais perto do lugar da missão está perto.
##   6. A CONTA DA PEDRA NÃO ENCOLHEU: cada sítio rende, em pedra solta, o que o
##      lajedo rendia — o poço o que o conserto pede (3), o roçado o da carroça
##      (3), o mirante e a capela o que o talento e o aço abrem (16 cada).
##   7. A REGRA É DO MOTOR, e não só dos dados: o `Recursos3D` mede o desenho e
##      rebaixa a cenário, com aviso, a ficha grande que rende pedra sem razão.
##
## FALSIFICAÇÃO. Em `data/recursos_3d.json`, volte `pedra_poco` ao tamanho 2,2: o
## motor a rebaixa a cenário (pergunta 7), e o poço fica sem pedra (5 e 6). Tire a
## pedra grande do poço (`lajedo_poco`): a pergunta 2 reprova.
##
## A espera do golpe é em segundo DE JOGO (`tests/fixtures/relogio_de_jogo.gd`).

const RelogioDeJogo = preload("res://tests/fixtures/relogio_de_jogo.gd")

## "Pequena" é isto. O motor tem o mesmo limite, e o portão confere que ele não
## foi frouxado além do que se pediu.
const LARGURA_MAXIMA := 1.25
const ALTURA_MAXIMA := 0.8
## A pedra grande é grande de verdade: acima disto numa das medidas.
const GRANDE_DE_LARGURA := 2.0
## Raio do corpo do jogador, medido no `vale.tscn`.
const RAIO_DO_CORPO := 0.28
## A razão da exceção tem de ser prosa, e não um "x".
const RAZAO_MINIMA := 20
## A ÚNICA pedra que se quebra sendo grande.
const EXCECOES := ["lapa_da_lombada"]
## Quanto cada sítio rendia de pedra antes (e quanto a missão ou o talento pedem).
const RENDIMENTO_MINIMO := {"poco": 3, "rocado": 3, "mirante": 16, "capela_estrada": 16, "cemiterio": 6, "lapa": 8}
## Do lugar da missão à pedra solta mais perto: perto o bastante para o marcador não
## mandar o jogador atravessar o vale.
const DISTANCIA_MAXIMA_DA_MISSAO := {"poco": 12.0, "rocado": 20.0}

var falhas := 0
var relogio: Node


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("PEDRAS_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	relogio = RelogioDeJogo.new()
	root.add_child(relogio)
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(6)
	relogio.ficar_lento()

	var vale := current_scene
	var jogador = vale.get("player")
	var recursos := vale.get_node_or_null("Recursos3D")
	var inv := root.get_node("/root/Inventario")
	var energia := root.get_node("/root/Energia")
	var lugares := root.get_node("/root/Lugares")
	_conferir(recursos != null and jogador != null, "o vale não montou o jogador ou os alvos de trabalho")
	if recursos == null or jogador == null:
		_fechar()
		return
	var dado = JSON.parse_string(FileAccess.get_file_as_string("res://data/recursos_3d.json"))
	_conferir(dado is Dictionary, "data/recursos_3d.json não é um objeto JSON")
	if not (dado is Dictionary):
		_fechar()
		return

	# --- 7. A REGRA É DO MOTOR (primeiro: as outras perguntas contam com ela) --------
	_conferir(recursos.PEDRA_MAX_LARGURA <= LARGURA_MAXIMA and recursos.PEDRA_MAX_ALTURA <= ALTURA_MAXIMA,
		"o motor aceita pedra quebrável de %.2f × %.2f, e o pedido foi até %.2f × %.2f" % [recursos.PEDRA_MAX_LARGURA, recursos.PEDRA_MAX_ALTURA, LARGURA_MAXIMA, ALTURA_MAXIMA])
	_conferir(recursos.pedra_pequena(AABB(Vector3.ZERO, Vector3(1.05, 0.65, 0.95))), "o motor acha grande a pedra solta de 1,05 × 0,65")
	_conferir(not recursos.pedra_pequena(AABB(Vector3.ZERO, Vector3(6.6, 4.1, 6.0))), "o motor acha pequeno o lajedo de 6,6 × 4,1")
	_conferir(not recursos.pedra_pequena(AABB(Vector3.ZERO, Vector3(1.0, 1.4, 1.0))), "o motor acha pequena uma pedra de 1,4 de altura")
	_conferir(recursos.rebaixados.is_empty(),
		"o motor rebaixou a cenário (grande demais para quebrar): %s" % str(recursos.rebaixados))

	# --- 1. TODA PEDRA QUE SE QUEBRA É PEQUENA, E A EXCEÇÃO É UMA SÓ ------------------
	var das_pedras: Array = []
	var excecoes: Array = []
	var maior := Vector2.ZERO
	for ficha: Dictionary in dado.get("recursos", []):
		if str(ficha.get("rende", "")) != "pedra":
			continue
		var id := str(ficha.get("id", ""))
		das_pedras.append(ficha)
		if not recursos._alvos.has(id):
			_conferir(false, "'%s' rende pedra e não virou alvo: o lugar '%s' não resolve, ou o motor a rebaixou" % [id, str(ficha.get("lugar", ""))])
			continue
		var limites: AABB = (recursos._alvos[id]["no"] as Node3D).get_meta("limites")
		var largura := maxf(limites.size.x, limites.size.z)
		if str(ficha.get("grande_de_proposito", "")) != "":
			excecoes.append(id)
			_conferir(str(ficha["grande_de_proposito"]).length() >= RAZAO_MINIMA,
				"a exceção '%s' não tem razão escrita (%d letras, e a prosa pede %d)" % [id, str(ficha["grande_de_proposito"]).length(), RAZAO_MINIMA])
			continue
		maior = Vector2(maxf(maior.x, largura), maxf(maior.y, limites.size.y))
		_conferir(largura <= LARGURA_MAXIMA and limites.size.y <= ALTURA_MAXIMA,
			"'%s' rende pedra e mede %.2f de largura por %.2f de altura: grande demais para quebrar (cabe até %.2f × %.2f)" % [id, largura, limites.size.y, LARGURA_MAXIMA, ALTURA_MAXIMA])
	_conferir(das_pedras.size() >= 20, "só %d ficha(s) rendem pedra: a regra mediria quase nada" % das_pedras.size())
	_conferir(excecoes == EXCECOES, "as pedras grandes que se quebram são %s, e só %s tem razão para isso" % [str(excecoes), str(EXCECOES)])
	print("  %d pedras que se quebram, a maior (fora a exceção) com %.2f de largura e %.2f de altura" % [das_pedras.size() - excecoes.size(), maior.x, maior.y])

	# --- 2. TODA PEDRA GRANDE É CENÁRIO ------------------------------------------------
	var fixas: Dictionary = recursos._fixas
	_conferir(fixas.size() >= 8, "só %d pedra(s) grande(s) de cenário: as oito que eram quebráveis não ficaram" % fixas.size())
	for id in fixas:
		var fixa: Dictionary = fixas[id]
		var no: Node3D = fixa["no"]
		_conferir(is_instance_valid(no) and no.is_inside_tree(), "a pedra grande '%s' não está no mundo" % id)
		if not is_instance_valid(no):
			continue
		var limites: AABB = no.get_meta("limites")
		_conferir(maxf(limites.size.x, limites.size.z) >= GRANDE_DE_LARGURA,
			"'%s' é cenário e mede só %.2f de largura: pedra pequena devia ser solta, e quebrar" % [id, maxf(limites.size.x, limites.size.z)])
		_conferir(not recursos._alvos.has(id), "a pedra grande '%s' é alvo de trabalho: se quebra" % id)
		var com_caixa := false
		for corpo in fixa["corpos"]:
			for forma in (corpo as Node).get_children():
				if forma is CollisionShape3D and (forma as CollisionShape3D).shape is BoxShape3D:
					var caixa := ((forma as CollisionShape3D).shape as BoxShape3D).size
					# O corpo é do tamanho do desenho: nem fantasma, nem parede de mais.
					com_caixa = com_caixa or (caixa.x >= limites.size.x * 0.7 and caixa.z >= limites.size.z * 0.7 and caixa.x <= limites.size.x * 1.1)
		_conferir(com_caixa, "a pedra grande '%s' não tem corpo do tamanho do desenho: o jogador atravessa" % id)
		# Nenhum alvo é este nó.
		for outro in recursos._alvos:
			_conferir(recursos._alvos[outro]["no"] != no, "'%s' e '%s' são o mesmo modelo" % [id, outro])

	# --- 3. DO LADO DE UMA PEDRA GRANDE O E NÃO BATE -----------------------------------
	_por_na_mao(inv, "picareta")
	energia.encher()
	var recusas: Array[String] = []
	recursos.recusado.connect(func(motivo: String) -> void: recusas.append(motivo))
	var provadas := 0
	var corpo_solto: bool = jogador.is_physics_processing()
	jogador.set_physics_process(false)
	for id in fixas:
		var fixa: Dictionary = fixas[id]
		var no: Node3D = fixa["no"]
		if not is_instance_valid(no):
			continue
		var limites: AABB = no.get_meta("limites")
		var centro := _centro_dos_corpos(fixa)
		# Das quatro faces, a que fica mais longe de qualquer alvo: ali, só a pedra
		# grande está ao alcance, e ela é que não pode responder.
		var melhor := Vector3.INF
		var folga := -INF
		for lado: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
			var meia: float = (limites.size.x if absf(lado.x) > 0.5 else limites.size.z) * 0.5
			var ponto: Vector3 = centro + lado * (meia + RAIO_DO_CORPO + 0.2)
			var mais_perto := INF
			for alvo in recursos._alvos:
				var d: Vector3 = recursos._alvos[alvo]["pos"] - ponto
				d.y = 0.0
				mais_perto = minf(mais_perto, d.length() - float(recursos._alvos[alvo].get("meia_pegada", 0.0)))
			if mais_perto > folga:
				folga = mais_perto
				melhor = ponto
		if folga <= float(recursos.ALCANCE) + 0.1:
			continue
		provadas += 1
		jogador.global_position = melhor
		await _frames(3)
		recusas.clear()
		_conferir(recursos._mais_perto() == "", "encostado na pedra grande '%s' o jogo oferece '%s'" % [id, recursos._mais_perto()])
		_conferir(not recursos.bater(), "o golpe saiu na pedra grande '%s'" % id)
		_conferir(recursos.alvo_do_e().is_empty(), "a pedra grande '%s' vota no foco do E" % id)
		_conferir(recursos._golpe_pendente.is_empty(), "a pedra grande '%s' deixou um golpe pendente" % id)
	jogador.set_physics_process(corpo_solto)
	_conferir(provadas >= 4, "só provei o E em %d pedra(s) grande(s) de %d: as outras têm alvo ao alcance de todas as faces" % [provadas, fixas.size()])

	# --- 4. A PEDRA SOLTA NÃO BRIGA PELO E, NEM NASCE DENTRO DA GRANDE ------------------
	for ficha: Dictionary in das_pedras:
		var id := str(ficha.get("id", ""))
		if not recursos._alvos.has(id) or EXCECOES.has(id):
			continue
		var alvo: Dictionary = recursos._alvos[id]
		_conferir(float(alvo["meia_pegada"]) <= 0.9, "'%s' tem meia-pegada de %.2f: empurra o E dos vizinhos" % [id, float(alvo["meia_pegada"])])
		var onde: Vector3 = alvo["pos"]
		for grande in fixas:
			for corpo in fixas[grande]["corpos"]:
				for forma in (corpo as Node).get_children():
					if not (forma is CollisionShape3D and (forma as CollisionShape3D).shape is BoxShape3D):
						continue
					var caixa := ((forma as CollisionShape3D).shape as BoxShape3D).size
					var local: Vector3 = (corpo as Node3D).global_transform.affine_inverse() * onde
					var dentro := absf(local.x) < caixa.x * 0.5 + float(alvo["meia_pegada"]) + 0.3 and absf(local.z) < caixa.z * 0.5 + float(alvo["meia_pegada"]) + 0.3
					_conferir(not dentro, "'%s' nasceu dentro (ou encostada) na pedra grande '%s': ninguém a alcança" % [id, str(grande)])

	# --- 5. AS PEDRAS DA MISSÃO SE COLHEM DE VERDADE -------------------------------------
	for sitio in ["poco", "rocado"]:
		var aqui: Array = []
		for ficha: Dictionary in das_pedras:
			if str(ficha.get("lugar", "")) == sitio:
				aqui.append(ficha)
		var ponto_do_lugar: Vector3 = lugares.ponto(sitio)
		_conferir(ponto_do_lugar != lugares.NENHUM and not aqui.is_empty(), "o sítio '%s' não tem pedra solta" % sitio)
		if aqui.is_empty() or ponto_do_lugar == lugares.NENHUM:
			continue
		# O marcador da missão aponta a pedra mais perto: ela tem de estar perto do lugar.
		var marcada: Vector3 = recursos.mais_perto_que_rende("pedra", ponto_do_lugar)
		var distancia := Vector2(marcada.x - ponto_do_lugar.x, marcada.z - ponto_do_lugar.z).length()
		_conferir(distancia <= float(DISTANCIA_MAXIMA_DA_MISSAO[sitio]),
			"a pedra mais perto do lugar '%s' fica a %.1f u dele, e passa de %.0f" % [sitio, distancia, float(DISTANCIA_MAXIMA_DA_MISSAO[sitio])])
		var antes: int = inv.quantidade("pedra")
		var esperadas := 0
		for ficha: Dictionary in aqui:
			esperadas += int(ficha.get("quantidade", 0))
			var id := str(ficha.get("id", ""))
			if not recursos._alvos.has(id):
				continue
			var onde: Vector3 = recursos._alvos[id]["pos"]
			_por_na_mao(inv, "picareta")
			var tentativas := 0
			while recursos._alvos.has(id) and tentativas < 14:
				tentativas += 1
				jogador.global_position = onde + (ponto_do_lugar - onde).normalized() * (float(recursos._alvos[id]["meia_pegada"]) + 0.5)
				await _frames(2)
				energia.encher()
				if recursos.bater():
					await relogio.ate(func() -> bool: return relogio.golpe_acabou(recursos), 6.0)
				else:
					await _frames(2)
			_conferir(not recursos._alvos.has(id), "'%s' não quebrou com a picareta em %d tentativas" % [id, tentativas])
		var ganhou: int = inv.quantidade("pedra") - antes
		_conferir(ganhou >= RENDIMENTO_MINIMO[sitio] and ganhou >= esperadas,
			"as pedras do sítio '%s' deram %d, e a missão pede %d (a ficha promete %d)" % [sitio, ganhou, int(RENDIMENTO_MINIMO[sitio]), esperadas])
		print("  %-8s %d pedra(s) soltas deram %d de pedra, a mais perto do lugar a %.1f u" % [sitio, aqui.size(), ganhou, distancia])
	# A pedra grande do poço e a do roçado continuam lá depois de colhidas as soltas.
	for id in ["lajedo_poco", "lajedo_rocado"]:
		_conferir(fixas.has(id) and is_instance_valid(fixas[id]["no"]), "colhidas as pedras soltas, a pedra grande '%s' sumiu" % id)

	# --- 6. A CONTA DA PEDRA NÃO ENCOLHEU ------------------------------------------------
	var soma := {}
	var com_aco := {}
	var com_talento := {}
	for ficha: Dictionary in das_pedras:
		var lugar := str(ficha.get("lugar", ""))
		soma[lugar] = int(soma.get(lugar, 0)) + int(ficha.get("quantidade", 0))
		if int(ficha.get("grau", 1)) >= 2:
			com_aco[lugar] = int(com_aco.get(lugar, 0)) + int(ficha.get("quantidade", 0))
		elif int(ficha.get("nivel", 1)) >= 2:
			com_talento[lugar] = int(com_talento.get(lugar, 0)) + int(ficha.get("quantidade", 0))
	for lugar in RENDIMENTO_MINIMO:
		_conferir(int(soma.get(lugar, 0)) >= int(RENDIMENTO_MINIMO[lugar]),
			"o sítio '%s' rende %d de pedra, e rendia %d: a conta encolheu" % [lugar, int(soma.get(lugar, 0)), int(RENDIMENTO_MINIMO[lugar])])
	for lugar in ["mirante", "capela_estrada"]:
		_conferir(int(com_aco.get(lugar, 0)) >= 8, "o aço abre %d de pedra em '%s', e abria 8" % [int(com_aco.get(lugar, 0)), lugar])
		_conferir(int(com_talento.get(lugar, 0)) >= 8, "o talento abre %d de pedra em '%s', e abria 8" % [int(com_talento.get(lugar, 0)), lugar])

	_fechar()


## Põe o item na mão pela barra, como o jogador faz.
func _por_na_mao(inv, id: String) -> void:
	if not inv.tem(id):
		inv.adicionar(id, 1)
	for i in inv.ESPACOS_MAO:
		if str((inv.espacos[i] as Dictionary).get("id", "")) == id:
			if inv.selecionado != i:
				inv.selecionar(i)
			return


## O meio do corpo da pedra grande (a caixa de colisão), que é onde o jogador esbarra.
func _centro_dos_corpos(fixa: Dictionary) -> Vector3:
	for corpo in fixa["corpos"]:
		if is_instance_valid(corpo):
			var p: Vector3 = (corpo as Node3D).global_position
			return Vector3(p.x, (fixa["no"] as Node3D).global_position.y, p.z)
	return (fixa["no"] as Node3D).global_position


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("PEDRAS_OK: toda pedra que se quebra cabe na mão (até 1,25 × 0,8) e a lapa da missão é a única grande com razão escrita; as grandes ficam no mundo como cenário, com corpo do tamanho do desenho e sem E, golpe nem voto no foco; a pedra solta não briga pelo E nem nasce dentro da grande; as do poço e as do roçado quebram na picareta, dão a pedra da missão e ficam perto do lugar dela; cada sítio rende o que o lajedo rendia; e o motor rebaixa a cenário a ficha grande que rende pedra")
	else:
		print("pedras: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _frames(n: int) -> void:
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
