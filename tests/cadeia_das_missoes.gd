extends SceneTree
## JOGA A CADEIA DE MISSÕES DO COMEÇO AO FIM, e confere que cada passo fecha.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/cadeia_das_missoes.gd
##
## Este portão existe porque a missão da picareta foi dada por consertada duas
## vezes e continuou quebrada. As duas vezes eu medi uma PARTE — que o alvo
## existe, que o golpe funciona, que o alvo está perto — e nenhuma das partes
## era o defeito.
##
## O defeito só aparece jogando: o passo com meta exigia estar perto do alvo
## para fechar, e o alvo é o lajedo, que SOME quando cai. O jogador quebrava a
## pedra, juntava as três, e o passo não fechava — porque o marcador tinha
## voltado para a âncora e ele teria de caminhar até uma casa.
##
## Então aqui não se mede parte nenhuma: teleporta o jogador de passo em passo
## e, nos que pedem trabalho, bate de verdade até render. Se a cadeia não
## chegar ao fim, o portão diz em qual passo ela parou e por quê.
##
##
## POR QUE A ESPERA É EM SEGUNDOS, E NÃO EM QUADROS
##
## A primeira versão esperava 240 QUADROS por passo e travava no roçado, com o
## jogador em cima do alvo e o raio folgado. O relatório dizia `dist=0.0
## raio=9.0` — chegou e não fechou.
##
## Não era o jogo. O Pedro só anuncia quando ninguém fala por perto, e quem
## segura a palavra é o `_falando` do `npc.gd`, que guarda PRAZO EM RELÓGIO DE
## PAREDE (`Time.get_ticks_msec`). Em headless os quadros voam: 240 deles
## passam numa fração de segundo real, e a saudação do aldeão do roçado ainda
## estava valendo. O teto era em quadros e o cadeado era em tempo.
##
## Medir espera de jogo em quadros só funciona enquanto quadro e segundo andam
## juntos — e em headless eles não andam.

var falhas := 0
## Teto REAL por passo. Passo que não fecha nisto está preso.
const SEGUNDOS_POR_PASSO := 15.0
## Teto real para o anúncio sair, que é onde a ferramenta é entregue.
const SEGUNDOS_PARA_ANUNCIAR := 12.0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("CADEIA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK,
		"a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(3)

	var jogo := current_scene
	var pedro = jogo.get("pedro")
	var recursos := jogo.get_node_or_null("Recursos3D")
	var jogador = jogo.get("player")
	var inv := root.get_node("/root/Inventario")
	var caderno := root.get_node("/root/CadernoDoVale")
	var energia := root.get_node("/root/Energia")
	_conferir(pedro != null and recursos != null and jogador != null,
		"não achei o Pedro, os recursos ou o jogador")
	if pedro == null or recursos == null or jogador == null:
		_fechar()
		return

	_conferir(pedro.recursos != null,
		"o Pedro não recebeu os recursos: o marcador vai apontar a âncora, e não o tronco")

	# Começa a condução sem esperar a saudação, que depende de proximidade.
	pedro.saudar()
	pedro._espera = 0.05
	await _frames(3)

	var total: int = pedro.MISSOES.size()
	_conferir(total >= 8, "a cadeia tem só %d passo(s)" % total)
	print("")

	var passo_anterior := -1
	var voltas := 0
	while pedro.missao < total and voltas < total + 4:
		voltas += 1
		var indice: int = pedro.missao
		if indice == passo_anterior:
			break
		passo_anterior = indice
		var passo: Dictionary = pedro.MISSOES[indice]
		var id := str(passo.get("id", "?"))
		var meta: Dictionary = passo.get("meta", {})

		# Deixa o passo anunciar: é no anúncio que a ferramenta é entregue. Só
		# sai quando ninguém fala por perto, e isso conta em segundo real.
		energia.encher()
		var anunciou := await _ate(func() -> bool: return pedro._espera <= 0.0,
			SEGUNDOS_PARA_ANUNCIAR)
		_conferir(anunciou,
			"o passo '%s' não chegou a anunciar em %s s: alguém nunca solta a palavra"
				% [id, str(SEGUNDOS_PARA_ANUNCIAR)])
		await _frames(2)

		# A ferramenta prometida tem de estar na mão ANTES de o trabalho ser
		# cobrado. É a regra 1 do tutorial do 2D.
		var entrega: Dictionary = passo.get("entrega", {})
		if not entrega.is_empty():
			var ferramenta := str(entrega.get("item", ""))
			# À MÃO, e não na mochila. O vale passou a cobrar a ferramenta
			# ENCAIXADA (`Recursos3D._tem_ferramenta`), e é o encaixe que a
			# entrega do passo preenche; perguntar pela mochila reprovaria
			# justamente a entrega que funciona. Pergunta-se à regra do jogo
			# para a medida não poder divergir dela.
			_conferir(recursos._tem_ferramenta(ferramenta),
				"o passo '%s' cobra trabalho e não deixou %s à mão" % [id, ferramenta])

		# O PASSO ESTÁ NO CADERNO DO VALE, que é o que o painel J mostra.
		#
		# Esta pergunta nasceu de "as missões estão bugadas e não aparecem no
		# menu de missão", e mudou de alvo depois: o caderno é do 3D agora
		# (`caderno_do_vale.gd`), e não o `Missoes` compartilhado com o 2D. O
		# pedido foi explícito — o vale tem de ter mecanismo próprio, sem
		# depender do checklist de lá.
		#
		# Medir a lista do caderno, e não o sinal do HUD, continua sendo o ponto:
		# o sinal funcionava; era o caderno que estava vazio.
		var no_caderno := "%s_%s" % ["pedro", id]
		_conferir(caderno.tem(no_caderno),
			"o passo '%s' anunciou e não entrou no caderno do vale: o painel J mostra a aba vazia" % id)
		if not meta.is_empty() and caderno.tem(no_caderno):
			var conta: Vector2i = caderno.andamento(no_caderno)
			_conferir(conta.y > 0,
				"o passo '%s' pede trabalho e entrou no caderno sem conta: o jogador não vê quanto falta" % id)
			_conferir(str(caderno.de(no_caderno).get("linha", "")) != "",
				"o passo '%s' pede trabalho e não escreveu a linha de andamento" % id)

		if meta.is_empty():
			# Passo de visita: chega e fecha.
			var alvo: Vector3 = pedro._posicao_da_missao(indice)
			jogador.spawn_position = alvo
			jogador.reset_position()
		else:
			# Passo de trabalho: bate no alvo até render o que falta.
			var item := str(meta.get("item", ""))
			var quantos := int(meta.get("quantos", 1))
			var marcado: Vector3 = pedro._posicao_da_missao(indice)
			_conferir(marcado != Vector3.ZERO,
				"o passo '%s' não marcou lugar nenhum" % id)
			var tentativas := 0
			while inv.quantidade(item) < quantos and tentativas < 40:
				tentativas += 1
				var onde: Vector3 = recursos.mais_perto_que_rende(item, jogador.global_position)
				if onde == Lugares.NENHUM:
					break
				jogador.spawn_position = onde
				jogador.reset_position()
				await _frames(2)
				energia.encher()
				if not recursos.bater():
					break
			_conferir(inv.quantidade(item) >= quantos,
				"o passo '%s' pede %d de %s e só consegui juntar %d batendo no vale"
					% [id, quantos, item, inv.quantidade(item)])

		# Espera o passo fechar — também em segundo real, pela mesma razão.
		var fechou := await _ate(func() -> bool: return pedro.missao != indice,
			SEGUNDOS_POR_PASSO)
		if not fechou:
			var onde_esta: Vector3 = pedro._posicao_da_missao(indice)
			_conferir(false,
				"o passo '%s' (%d de %d) não fechou em %s s. espera=%.2f dist=%.1f raio=%s meta=%s"
					% [id, indice + 1, total, str(SEGUNDOS_POR_PASSO), pedro._espera,
						jogador.global_position.distance_to(onde_esta),
						str(passo.get("raio", "?")), str(meta)])
		print("  %-14s %s" % [id, "fechou" if fechou else "PRESO"])
		if not fechou:
			break

	_conferir(pedro.missao >= total,
		"a cadeia parou no passo %d de %d" % [pedro.missao + 1, total])

	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("CADEIA_OK: os passos de visita fecham ao chegar, os de trabalho entregam a ferramenta e fecham ao cumprir a meta onde quer que o jogador esteja, e cada passo entra no caderno DO VALE com a conta e a linha de andamento dele")
	else:
		print("cadeia: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


## Roda quadros até `condicao` valer, com teto em SEGUNDO REAL.
##
## O teto é de relógio porque o que se espera aqui — fala acabar, passo virar —
## é medido em relógio pelo próprio jogo. Ver o cabeçalho.
func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicao.call():
			return true
		await process_frame
	return condicao.call()


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
