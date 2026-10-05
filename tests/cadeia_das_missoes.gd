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
## A CHEGADA PEDE DE TUDO (docs/mundo/CHEGADA_E_MUTIROES.md)
##
## Deixou de ser "vá até" e "junte N": a descida do saveiro até o Pedro, a
## primeira corrida, o bom-dia ao Tonho, a pergunta à Dona Candinha, a casa
## aberta e as ferramentas do baú, a leira, a corda torcida na bancada, o
## mutirão do poço, a janta, a cama e o convite lido. Cada meta se cumpre aqui PELO CAMINHO DO JOGO: ao lado
## de quem se fala, a corrida pelo Shift, a porta da casa, o baú,
## `Oficina.fabricar`, `Obras.executar`, `Cozinha.cozinhar`, a
## lavoura pela ferramenta na mão, a cama pela `Queda`, o papel pela leitura da
## mochila. O que o portão não faz é chamar `registrar_evento`: o acontecimento
## tem de chegar à cadeia pelo fio que o vale ligou, ou o passo não fecha.
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
const SEGUNDOS_POR_PASSO := 30.0
## Teto real para o anúncio sair, que é onde a ferramenta é entregue.
const SEGUNDOS_PARA_ANUNCIAR := 12.0
## O teto do resumo de missão no HUD, com a conta "(2/4)" dentro.
const LETRAS_DO_RESUMO := 60


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
	var dialogo := root.get_node("/root/Dialogo")
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
			"o passo '%s' não chegou a anunciar em %s s: alguém nunca solta a palavra (%s)"
				% [id, str(SEGUNDOS_PARA_ANUNCIAR), _quem_fala(pedro, jogador)])
		await _frames(2)

		# A ferramenta prometida tem de estar na mão ANTES de o trabalho ser
		# cobrado. É a regra 1 do tutorial do 2D.
		var entregas: Array = passo.get("entrega", []) if passo.get("entrega") is Array else [passo.get("entrega", {})]
		var ferramentas := entregas.filter(func(e) -> bool:
			return e is Dictionary and Catalogo.tipo(str((e as Dictionary).get("item", ""))) == "ferramenta")
		if not ferramentas.is_empty():
			var ferramenta := str((ferramentas[0] as Dictionary).get("item", ""))
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
		# ENTROU, MESMO QUE JÁ TENHA FECHADO. Passo de visita anunciado com o
		# jogador já dentro do raio fecha no pulso seguinte da cadeia — é o caso
		# da enxada, no roçado, quando a pedra do passo de antes foi quebrada
		# ali perto. Se a pergunta viesse depois desse pulso, o passo estaria nas
		# cumpridas, que o J também mostra; perguntar só pelas ativas fazia o
		# portão depender de quantos quadros de física cabem em dois de desenho.
		_conferir(caderno.tem(no_caderno) or caderno.cumprida(no_caderno),
			"o passo '%s' anunciou e não entrou no caderno do vale: o painel J mostra a aba vazia" % id)
		if not meta.is_empty() and caderno.tem(no_caderno):
			var conta: Vector2i = caderno.andamento(no_caderno)
			_conferir(conta.y > 0,
				"o passo '%s' pede trabalho e entrou no caderno sem conta: o jogador não vê quanto falta" % id)
			_conferir(str(caderno.de(no_caderno).get("linha", "")) != "",
				"o passo '%s' pede trabalho e não escreveu a linha de andamento" % id)

		# O HUD MOSTRA O RESUMO, E O PAINEL A FALA INTEIRA.
		#
		# "A descrição da missão no HUD deve ser um resumo com atividades
		# diretas ao ponto. O texto completo deve ficar apenas no painel de
		# missão (J)." O HUD recebia a fala com o nome na frente.
		var objetivo := str(current_scene.hud.get("_objective"))
		var fala := str(passo.get("texto", ""))
		_conferir(objetivo.length() <= LETRAS_DO_RESUMO,
			"o objetivo do HUD no passo '%s' tem %d letras, e resumo é até %d: '%s'"
				% [id, objetivo.length(), LETRAS_DO_RESUMO, objetivo])
		_conferir(fala.length() <= LETRAS_DO_RESUMO or not objetivo.contains(fala),
			"o objetivo do HUD no passo '%s' é a fala inteira: '%s'" % [id, objetivo])
		if caderno.tem(no_caderno):
			_conferir(str(caderno.de(no_caderno).get("texto", "")).contains(fala),
				"a fala inteira do passo '%s' não está no caderno, que é o que o painel J mostra" % id)

		var marcado: Vector3 = pedro._posicao_da_missao(indice)
		_conferir(meta.is_empty() or marcado != Vector3.ZERO,
			"o passo '%s' não marcou lugar nenhum" % id)
		match str(meta.get("tipo", "")):
			"":
				# Passo de visita: chega e fecha.
				jogador.spawn_position = marcado
				jogador.reset_position()
			"falar", "levar":
				# Ao lado de quem se fala: o marcador segue a pessoa.
				var quem = jogo._achar_morador(str(meta.get("a_quem", "")))
				_conferir(quem != null, "o passo '%s' procura '%s', que não está no vale" % [id, str(meta.get("a_quem", ""))])
				if quem != null:
					_conferir(marcado.distance_to(quem.global_position) < 0.5,
						"o marcador do passo '%s' não está em %s" % [id, str(meta.get("a_quem", ""))])
					jogador.teleportar(quem.global_position + Vector3(1.0, 0.0, 0.6), 0.0)
			"juntar":
				for item in _carga(meta):
					await _juntar(str(item), int(_carga(meta)[item]), id, inv, recursos, jogador, energia)
			"obra":
				jogador.teleportar(marcado, 0.0)
				await _frames(3)
				energia.encher()
				var obras := root.get_node("/root/Obras")
				var construcao := str(meta.get("construcao", ""))
				var a_obra := str(meta.get("obra", ""))
				_conferir(obras.executar(construcao, a_obra),
					"o passo '%s' pede a obra '%s', e ela não saiu: %s" % [id, a_obra, obras.impedimento(construcao, a_obra)])
			"evento":
				for evento in _eventos(meta):
					await _acontecer(str(evento), id, jogo, jogador, inv, energia, dialogo)
			_:
				_conferir(false, "o passo '%s' tem meta '%s', que este portão não sabe jogar" % [id, str(meta.get("tipo", ""))])

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


## QUEM SEGURA A PALAVRA agora, a que distância do jogador e por quanto tempo
## ainda (`npc._falando`): é o que se precisa saber quando um passo não anuncia.
func _quem_fala(pedro, jogador) -> String:
	var agora := Time.get_ticks_msec()
	var partes: Array[String] = []
	for quem in pedro._falando:
		if is_instance_valid(quem) and int(pedro._falando[quem]) > agora:
			partes.append("%s a %.1f u, mais %.1f s" % [str(quem.name),
				(quem as Node3D).global_position.distance_to(jogador.global_position),
				(int(pedro._falando[quem]) - agora) / 1000.0])
	if not pedro.pode_falar():
		partes.append("o Pedro não pode falar")
	return ", ".join(partes) if not partes.is_empty() else "ninguém fala; a espera do passo é %.2f" % float(pedro._espera)


## Os acontecimentos da meta, como a cadeia os lê (`eventos`, ou o `evento` só).
## Lido aqui, e não pelo script da cadeia: `preload` dele num `--script` compila
## antes dos autoloads e fica quebrado no cache.
static func _eventos(meta: Dictionary) -> Array:
	var lista: Array = meta.get("eventos", [])
	return lista if not lista.is_empty() else [str(meta.get("evento", ""))]


static func _carga(meta: Dictionary) -> Dictionary:
	var varios: Dictionary = meta.get("itens", {})
	if not varios.is_empty():
		return varios
	return {str(meta.get("item", "")): int(meta.get("quantos", 1))}


## JUNTA O ITEM PELO CAMINHO DO JOGO: o que cai de alvo, batendo; o que sai da
## bancada (corda, tábua), juntando a lenha e fabricando, como o J faz; o que
## está no baú da casa (as ferramentas do finado), tirando de lá, como a tela
## do baú faz.
func _juntar(item: String, quantos: int, id: String, inv, recursos, jogador, energia) -> void:
	var oficina := root.get_node("/root/Oficina")
	var casa = current_scene.get("casa")
	if casa != null:
		for monte in casa.bau.duplicate():
			if inv.quantidade(item) >= quantos or str(monte.get("id", "")) != item:
				continue
			if inv.adicionar(item, int(monte.get("qtd", 1))):
				casa.bau.erase(monte)
	var tentativas := 0
	while inv.quantidade(item) < quantos and tentativas < 60:
		tentativas += 1
		var receita: Dictionary = oficina.dados(item)
		if not receita.is_empty():
			for material in receita.get("custo", {}):
				await _juntar(str(material), int(receita["custo"][material]), id, inv, recursos, jogador, energia)
			energia.encher()
			if not oficina.fabricar(item):
				break
			continue
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
		"o passo '%s' pede %d de %s e só consegui juntar %d no vale" % [id, quantos, item, inv.quantidade(item)])


## FAZ O ACONTECIMENTO ACONTECER pelo caminho do jogo, e não pelo
## `registrar_evento`: é o fio do vale que está sendo medido.
func _acontecer(evento: String, id: String, jogo, jogador, inv, energia, dialogo) -> void:
	energia.encher()
	if evento.begins_with("cozinhou:"):
		var cozinha := root.get_node("/root/Cozinha")
		var receita := evento.trim_prefix("cozinhou:")
		jogador.teleportar(root.get_node("/root/Lugares").ponto("fogueira") + Vector3(1.4, 0.0, 0.0), 0.0)
		_conferir(cozinha.cozinhar(receita),
			"o passo '%s' pede %s no fogo, e a cozinha recusou: %s" % [id, receita, cozinha.impedimento(receita)])
	elif evento == "dormiu":
		jogo.noite.dormir_na_cama()
	elif evento == "correu":
		# O Shift e a frente, de onde o desembarque deixou o jogador (ao lado do
		# Pedro, no píer) rumo à praça, pelo tabuado: o vale conta o trecho
		# corrido (`prototype._ver_se_correu`). Posto no ponto da praça e virado
		# para o +Z, o corpo não fechava o trecho em 6 s (05/10/2026); o tabuado
		# rumo à praça é o mesmo chão que o portão da chegada corre.
		# Um passo e meio à frente do Pedro, já no rumo, como no portão da
		# chegada: saindo colado nele, o trecho não fechava (05/10/2026).
		var guia = jogo.get("pedro")
		var de: Vector3 = guia.global_position if guia != null else jogador.global_position
		var praca: Vector3 = jogo.world.ancoras.get("Praça", de)
		var rumo: Vector3 = praca - de
		rumo.y = 0.0
		rumo = rumo.normalized() if rumo.length() > 0.1 else Vector3.FORWARD
		jogador.teleportar(de + rumo * 1.5 + Vector3.UP * 0.3, atan2(rumo.x, rumo.z))
		await _frames(2)
		jogador.set("_run_toggled", true)
		Input.action_press("mv_forward")
		await _ate(func() -> bool: return jogo.get("_correu_avisado") == true, 6.0)
		Input.action_release("mv_forward")
		# A corrida passa por gente no píer, e cada um cumprimenta quem passa: o
		# passo seguinte só se anuncia com a palavra livre, e o teto dele é de quem
		# chega calado. Espera-se as falas da corrida acabarem, como o jogador.
		if guia != null:
			await _ate(func() -> bool: return not guia.fala_perto_de(jogador.global_position), 20.0)
	elif evento.begins_with("entrou:"):
		# Entra pela porta: do lado de dentro da soleira, o vale vê quem entrou.
		var sala = jogo.interiores.sala_de(evento.trim_prefix("entrou:"))
		_conferir(sala != null, "o passo '%s' espera entrar em '%s', e o vale não tem esse cômodo" % [id, evento])
		if sala != null:
			jogador.teleportar(sala.soleira_de_dentro(), 0.0)
			await _frames(10)
	elif evento in ["arou", "plantou", "regou"]:
		var lavoura = jogo.lavoura
		var leito := Vector2i(0, 0)
		var na_mao := {"arou": "enxada", "plantou": "semente_mandioca", "regou": "balde"}
		_conferir(_por_na_mao(inv, str(na_mao[evento])),
			"o passo '%s' precisa de %s na mão, e não há na mochila" % [id, str(na_mao[evento])])
		jogador.teleportar(lavoura.posicao_da(leito) + Vector3(0.0, 0.0, -0.6), 0.0)
		await _frames(2)
		lavoura.usar(leito)
	elif evento.begins_with("leu:"):
		var papel := evento.trim_prefix("leu:")
		_conferir(inv.quantidade(papel) > 0, "o passo '%s' pede ler %s, e ninguém o deu" % [id, papel])
		jogo._ler_documento(papel)
		var ate := Time.get_ticks_msec() + 6000
		while not dialogo.ativo and Time.get_ticks_msec() < ate:
			await process_frame
		while dialogo.ativo and Time.get_ticks_msec() < ate:
			dialogo._fechar()
			await process_frame
	else:
		_conferir(false, "o passo '%s' espera '%s', e este portão não sabe fazer isso acontecer" % [id, evento])
	await _frames(2)


## Acende na barra o item, trazendo-o da reserva se for o caso.
static func _por_na_mao(inv, item: String) -> bool:
	for i in inv.ESPACOS:
		if str((inv.espacos[i] as Dictionary).get("id", "")) != item:
			continue
		if i >= inv.ESPACOS_MAO:
			inv.trocar(i, inv.ESPACOS_MAO - 1)
			i = inv.ESPACOS_MAO - 1
		inv.selecionar(i)
		return true
	return false


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("CADEIA_OK: a chegada joga do desembarque ao convite — descer do saveiro, correr, falar, perguntar, entrar na casa, pegar do baú, juntar, torcer corda, o mutirão do poço, a janta, a cama, a leira e o papel lido —, cada passo entrega a ferramenta antes de cobrar, fecha pelo fio do vale e entra no caderno DO VALE com a conta e a linha de andamento dele")
	else:
		print("cadeia: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


## Roda quadros até `condicao` valer, com teto em SEGUNDO REAL.
##
## O teto é de relógio porque o que se espera aqui — fala acabar, passo virar —
## é medido em relógio pelo próprio jogo. Ver o cabeçalho.
##
## A CAIXA DE FALA LONGA SE FECHA AQUI: a explicação do corpo (o Pedro, na porta
## da casa) segura o vale até o jogador ler, e o portão lê depressa.
func _ate(condicao: Callable, segundos: float) -> bool:
	var dialogo := root.get_node("/root/Dialogo")
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicao.call():
			return true
		if dialogo.ativo:
			dialogo._fechar()
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
