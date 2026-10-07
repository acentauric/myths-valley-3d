extends RefCounted
## AS MÃOS DO JOGADOR NOS PORTÕES DE MISSÃO: andar, apertar a tecla, esperar em segundos de JOGO.
##
## Não é portão: o runner só roda `tests/*.gd`, e esta pasta fica fora disso.
##
## POR QUE EXISTE. Todo portão de missão até 06/10/2026 teleportava o jogador, chamava
## `Obras.executar`, `recursos.bater` e `tecla.usar` pela mão, punha `missao = N` e injetava
## o material. Nenhum provava que o jogador CONSEGUE chegar e que a tecla DELE faz a coisa:
## "não consegui interagir com o poço" passou por todos eles. Estas mãos fazem o que o
## jogador faz — caminham pela navegação do próprio controle (`caminhar_ate`, o mesmo
## caminho do clique), apertam a tecla pela janela (`push_input`) e perguntam ao FOCO DO E
## quem leva a tecla antes de apertá-la.
##
## O ÚNICO ATALHO É A DISTÂNCIA: o vale tem centenas de metros, e andá-lo inteiro, passo a
## passo, levaria horas de jogo. `ir_ate` teleporta para `DISTANCIA_DO_TELEPORTE` unidades
## antes do fim do caminho e anda o resto de verdade.
##
## Autoload, aqui, só por `arvore.root.get_node("/root/Nome")`: um portão `--script` não
## enxerga autoload pelo nome, e nem o que ele pré-carrega.

const DISTANCIA_DO_TELEPORTE := 15.0
## Segundos de jogo para o corpo andar o último trecho (15 u a ~4 u/s, com folga).
const TETO_DA_CAMINHADA_S := 60.0

var arvore: SceneTree
var vale: Node
var jogador: Node
## O `RelogioDeJogo` (tests/fixtures/relogio_de_jogo.gd): as esperas são em segundos de jogo.
var relogio: Node
## `func(texto: String)`: marca falha no portão que usa as mãos.
var reprovar: Callable
## `func(texto: String)`: uma linha de andamento.
var contar: Callable
var atalhos: Array[String] = []
## Em `calado`, `ir_ate` não reprova: guarda o motivo em `ultimo_motivo` e devolve false (quem chama decide).
var calado := false
## O clique corre (`_walk_run`), em vez de andar: o jogador que persegue quem anda (`e_no_morador`).
var correr_ao_andar := false
var ultimo_motivo := ""
## Teleportar para `DISTANCIA_DO_TELEPORTE` antes do fim do caminho? O tutorial anda tudo, porque o
## Pedro conduz o jogador e fica para trás se ele some de vista.
var teleporte := true


func _init(a: SceneTree, v: Node, r: Node, reprovar_: Callable, contar_: Callable) -> void:
	arvore = a
	vale = v
	jogador = v.get("player")
	relogio = r
	reprovar = reprovar_
	contar = contar_


func auto(nome: String) -> Node:
	return arvore.root.get_node("/root/" + nome)


## Um atalho que o portão tomou (algo que o jogador faria de outro jeito): fica anotado para o
## resumo final dizer o que NÃO foi jogado de verdade.
func atalho(o_que: String) -> void:
	if not atalhos.has(o_que):
		atalhos.append(o_que)
	contar.call("    ATALHO: " + o_que)


# --- esperar --------------------------------------------------------------------------------

func quadros(quantos: int) -> void:
	for i in range(quantos):
		await arvore.process_frame


## Espera `condicao` por até `segundos` DE JOGO. A caixa de fala longa que abrir no caminho é
## "lida" (fechada) — ler não é o que se mede aqui.
func esperar(condicao: Callable, segundos: float) -> bool:
	var dialogo := auto("Dialogo")
	var limite: float = relogio.agora() + segundos
	var guarda := Time.get_ticks_msec() + int(maxf(segundos * relogio.GUARDA, relogio.GUARDA_MINIMA_S) * 1000.0)
	while relogio.agora() < limite and Time.get_ticks_msec() < guarda:
		if condicao.call():
			return true
		if dialogo.ativo:
			dialogo._fechar()
		await arvore.process_frame
	return condicao.call()


func passar(segundos: float) -> void:
	await esperar(func() -> bool: return false, segundos)


# --- a tecla --------------------------------------------------------------------------------

## A tecla pela janela, como o teclado. `segurar_s` segura apertada (o golpe forte, a rasteira): aí vai pelo
## `Input.parse_input_event`, que também marca a tecla como APERTADA para quem a pergunta por
## `Input.is_physical_key_pressed` (a luta pergunta, para saber se o E ainda está embaixo do dedo); o toque
## vai pela janela (`push_input`), como o foco do E o conferiu.
func apertar(tecla: int, segurar_s: float = 0.0) -> void:
	# O VALE SEGURA AS TECLAS enquanto uma fala está aberta ou acabou de fechar (`Dialogo.ocupado`, com os
	# quadros de carência): quem aperta nesse intervalo não é ouvido. O jogador lê a fala, espera ela sumir e
	# aperta (o `esperar` fecha a caixa que estiver aberta: ler não é o que se mede aqui).
	await esperar(func() -> bool: return not auto("Dialogo").ocupado(), 8.0)
	var evento := InputEventKey.new()
	evento.keycode = tecla
	evento.physical_keycode = tecla
	evento.pressed = true
	var solto := InputEventKey.new()
	solto.keycode = tecla
	solto.physical_keycode = tecla
	solto.pressed = false
	if segurar_s > 0.0:
		Input.parse_input_event(evento)
		await passar(segurar_s)
		Input.parse_input_event(solto)
		await arvore.process_frame
		return
	arvore.root.push_input(evento)
	await arvore.process_frame
	arvore.root.push_input(solto)
	await arvore.process_frame


## A TECLA DE UMA TELA (J, K, P, I): o jogador a aperta e confere se a tela abriu; se não abriu (a fala que
## fechava ainda segurava a tecla, a mão errou a hora), aperta de novo — até `tentativas` vezes. Devolve se abriu.
func abrir_tela(tecla: int, aberta: Callable, tentativas: int = 3) -> bool:
	for vez in range(tentativas):
		await apertar(tecla)
		if await esperar(aberta, 2.5):
			return true
	return false


func foco() -> Node:
	return vale.get("foco_do_e")


## Quem leva o E agora, pelo foco do vale.
func dono_do_e() -> Object:
	var f := foco()
	return f.dono() if f != null else null


## Quem concorre ao E agora e com que conta (distância + rumo - viés): é o que se lê quando o E é de outro.
func explicar_o_foco() -> String:
	var f := foco()
	if f == null:
		return "sem foco do E"
	var frente: Vector3 = f._frente()
	var partes: Array[String] = []
	for fonte in arvore.get_nodes_in_group("fontes_do_e"):
		if not fonte.has_method("alvo_do_e"):
			continue
		var alvo: Dictionary = fonte.alvo_do_e()
		if alvo.is_empty():
			continue
		var conta: float = f.conta_do_alvo(alvo, jogador.global_position, frente)
		partes.append("%s a %.2f u (viés %.1f, conta %.2f)" % [nome_de(fonte), _de_longe(alvo.get("ponto", jogador.global_position)), float(alvo.get("vies", 0.0)), conta])
	return "; ".join(partes) if not partes.is_empty() else "ninguém concorre"


func nome_de(no: Object) -> String:
	if no == null:
		return "ninguém"
	if no is Node:
		var dados = (no as Node).get("dados")
		if dados is Dictionary and (dados as Dictionary).has("id"):
			return "%s (%s)" % [(no as Node).name, str((dados as Dictionary)["id"])]
		return str((no as Node).name)
	return str(no)


# --- o corpo --------------------------------------------------------------------------------

## O PONTO ANDÁVEL em que o jogador pode parar para tocar `alvo`: primeiro no anel de `ideal`
## unidades em volta dele — começando pelo lado de `preferir`, de onde o jogador vem —, depois
## nos anéis vizinhos, até `maximo`. Sem corpo no meio (esfera de 0,3 u). `Vector3.INF` se não há.
func chegada(alvo: Vector3, ideal: float, preferir: Vector3 = Vector3.INF, maximo: float = 8.0) -> Vector3:
	var todas := chegadas(alvo, ideal, preferir, maximo, 1)
	return Vector3.INF if todas.is_empty() else todas[0]


## TODOS os pontos de parar (até `quantos`), na ordem em que `chegada` os acha: o jogador tenta o seguinte
## quando o caminho até o primeiro não existe (o outro lado da cerca, o barranco).
func chegadas(alvo: Vector3, ideal: float, preferir: Vector3 = Vector3.INF, maximo: float = 8.0, quantos: int = 12) -> Array[Vector3]:
	var mundo = vale.get("world")
	var achados: Array[Vector3] = []
	var rumo0 := 0.0
	if preferir.is_finite():
		rumo0 = atan2(preferir.x - alvo.x, preferir.z - alvo.z)
	var aneis: Array[float] = [ideal]
	for passo in [0.6, -0.6, 1.2, -1.2, 2.4, 4.0, 6.0]:
		var r: float = ideal + float(passo)
		if r >= 0.0 and r <= maximo and not aneis.has(r):
			aneis.append(r)
	for r in aneis:
		var amostras := 1 if r < 0.05 else 16
		for k in amostras:
			# 0, +22,5, -22,5, +45...: o lado de onde se vem primeiro.
			var salto := 0.0
			if k > 0:
				salto = ceil(float(k) / 2.0) * (TAU / 16.0) * (1.0 if k % 2 == 1 else -1.0)
			var rumo := rumo0 + salto
			var ponto: Vector3 = alvo + Vector3(sin(rumo) * r, 0.0, cos(rumo) * r)
			ponto = superficie(ponto, alvo.y)
			if mundo.is_walkable_point(ponto) and sem_corpo(ponto):
				achados.append(ponto)
				if achados.size() >= quantos:
					return achados
	return achados


## A SUPERFÍCIE em que o jogador pisa em (x, z): a de cima do que houver abaixo de `y_do_alvo + 1,5`
## (o alto da lombada, a tábua do píer), e o chão do terreno quando não há nada.
func superficie(ponto: Vector3, y_do_alvo: float) -> Vector3:
	var mundo = vale.get("world")
	var de := Vector3(ponto.x, y_do_alvo + 1.5, ponto.z)
	var ate := Vector3(ponto.x, y_do_alvo - 3.0, ponto.z)
	var pergunta := PhysicsRayQueryParameters3D.create(de, ate, 1, [jogador.get_rid()])
	var achou: Dictionary = (jogador as Node3D).get_world_3d().direct_space_state.intersect_ray(pergunta)
	if not achou.is_empty() and not (achou["collider"] is Node and (achou["collider"] as Node).is_in_group("moradores")):
		return (achou["position"] as Vector3) + Vector3(0.0, 0.03, 0.0)
	return mundo.ground_position(ponto)


## Nenhum corpo sólido (parede, tronco, casa) onde o jogador ficaria.
func sem_corpo(ponto: Vector3) -> bool:
	var esfera := SphereShape3D.new()
	esfera.radius = 0.3
	var pergunta := PhysicsShapeQueryParameters3D.new()
	pergunta.shape = esfera
	pergunta.transform = Transform3D(Basis.IDENTITY, ponto + Vector3(0.0, 0.7, 0.0))
	pergunta.collision_mask = 1
	pergunta.exclude = [jogador.get_rid()]
	var achados: Array[Dictionary] = (jogador as Node3D).get_world_3d().direct_space_state.intersect_shape(pergunta, 4)
	for achado in achados:
		var corpo = achado.get("collider")
		if corpo is Node and (corpo as Node).is_in_group("moradores"):
			continue
		return false
	return true


## O caminho do jogador até `ponto`, pela navegação do próprio controle.
func caminho_ate(ponto: Vector3, de: Vector3 = Vector3.INF) -> PackedVector3Array:
	var origem: Vector3 = de if de.is_finite() else jogador.global_position
	return jogador._navigator.find_path(origem, ponto)


static func comprimento(caminho: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, caminho.size()):
		total += Vector2(caminho[i].x - caminho[i - 1].x, caminho[i].z - caminho[i - 1].z).length()
	return total


## O ponto do caminho a `resta` unidades do fim, e o rumo do corpo ali.
static func ponto_a(caminho: PackedVector3Array, resta: float) -> Dictionary:
	var falta := resta
	for i in range(caminho.size() - 1, 0, -1):
		var trecho := Vector2(caminho[i].x - caminho[i - 1].x, caminho[i].z - caminho[i - 1].z).length()
		if trecho >= falta and trecho > 0.001:
			var t := 1.0 - falta / trecho
			var ponto: Vector3 = caminho[i - 1].lerp(caminho[i], t)
			var rumo: Vector3 = caminho[i] - caminho[i - 1]
			return {"ponto": ponto, "giro": atan2(rumo.x, rumo.z)}
		falta -= trecho
	var primeiro: Vector3 = caminho[0]
	var seguinte: Vector3 = caminho[mini(1, caminho.size() - 1)]
	return {"ponto": primeiro, "giro": atan2(seguinte.x - primeiro.x, seguinte.z - primeiro.z)}


## ANDA ATÉ PERTO DE `destino`: teleporta só para `DISTANCIA_DO_TELEPORTE` antes do fim do
## caminho e anda o resto pelo controle, como o clique — e o último trecho, que a grade do clique
## (células de 2,5 u) não alcança, com a tecla de ir em frente, virado para o destino, como o jogador
## faz. `ideal` é a que distância do destino se para (1,9 u diante de uma pessoa; 0 num lugar);
## `maximo`, quão longe do destino ainda se aceita parar. `olhar` vira o corpo para o destino na
## chegada. Devolve se chegou, e diz por quê quando não.
func ir_ate(destino: Vector3, ideal: float = 1.9, olhar: bool = true, teto_s: float = TETO_DA_CAMINHADA_S, maximo: float = 8.0) -> bool:
	# Perto o bastante: diante de uma pessoa, o alcance da conversa; num lugar, o `maximo` pedido.
	var basta := ideal + 0.5 if ideal > 0.0 else maxf(maximo, 1.0) + 0.8
	if _de_longe(destino) <= basta:
		if olhar:
			virar_para(destino)
		await quadros(2)
		return true
	# O ponto de parar, com caminho do clique inteiro até ele: o do anel de `ideal` e, quando o caminho some ou
	# só chega perto (malha parcial: o barranco, a água), os anéis de fora.
	var ponto := Vector3.INF
	var caminho := PackedVector3Array()
	var parcial := ""
	var melhor_parcial := {}
	var vistos := 0
	for extra in [0.0, 2.0, 4.0]:
		if not caminho.is_empty():
			break
		for candidato in chegadas(destino, ideal + float(extra), jogador.global_position, maximo + float(extra), 10):
			vistos += 1
			var tentativa := caminho_ate(candidato)
			if tentativa.is_empty():
				continue
			var fim: Vector3 = tentativa[tentativa.size() - 1]
			var falta_ate_o_ponto := Vector2(fim.x - candidato.x, fim.z - candidato.z).length()
			if falta_ate_o_ponto > 3.5:
				parcial = "o caminho do clique de %s até %s termina em %s, a %.1f u do ponto (%d pontos de parar tentados)" % [str(jogador.global_position), str(candidato), str(fim), falta_ate_o_ponto, vistos]
				# O melhor caminho parcial: o que acaba mais perto do alvo (o resto, o corpo anda).
				var falta_ate_o_alvo := Vector2(fim.x - destino.x, fim.z - destino.z).length()
				if melhor_parcial.is_empty() or falta_ate_o_alvo < float(melhor_parcial["falta"]):
					melhor_parcial = {"ponto": candidato, "caminho": tentativa, "falta": falta_ate_o_alvo}
				continue
			ponto = candidato
			caminho = tentativa
			break
	if caminho.is_empty() and not melhor_parcial.is_empty() and float(melhor_parcial["falta"]) <= 9.0:
		# Sem caminho inteiro (a malha tem células de 2,5 u e o alvo fica colado numa quina): vai até onde a
		# malha chega, e o corpo anda o resto — o clique perto e as setas, como o jogador.
		ponto = melhor_parcial["ponto"]
		caminho = melhor_parcial["caminho"]
	if caminho.is_empty() and _de_longe(destino) <= 25.0:
		# Nem caminho parcial (o ponto de saída é uma célula presa): as setas direto, de perto.
		contar.call("    ... sem caminho do clique de %s até %s: as setas direto" % [str(jogador.global_position), str(destino)])
		await guiar_ate(destino, maxf(basta - 0.5, 0.6), 20.0)
		if _de_longe(destino) <= basta + 0.3:
			if olhar:
				virar_para(destino)
			await quadros(2)
			return true
	if caminho.is_empty():
		_nao_deu(parcial if parcial != "" else "o controle não acha caminho do jogador (%s) até %s" % [str(jogador.global_position), str(destino)])
		return false
	var total := comprimento(caminho)
	if teleporte and total > DISTANCIA_DO_TELEPORTE + 1.0:
		var onde := ponto_a(caminho, DISTANCIA_DO_TELEPORTE)
		# O ponto é interpolado em linha reta entre dois pontos do caminho (a grade do clique tem células de 2,5 u),
		# e num morro a reta passa ABAIXO do chão: o jogador nascia enterrado na terra, não andava, e a fase empacava
		# (a da Zefa, em 06/10/2026, a 0,9 u sob o chão, no desvio em volta da casa). O ponto sobe para a superfície.
		var do_teleporte: Vector3 = onde["ponto"]
		do_teleporte.y = maxf(do_teleporte.y, superficie(do_teleporte, do_teleporte.y).y)
		jogador.teleportar(do_teleporte, float(onde["giro"]))
		await quadros(3)
		total = DISTANCIA_DO_TELEPORTE
	# O teto cresce com o que falta andar (o tutorial anda o vale inteiro, de ponta a ponta): nunca menos
	# de 1,5 u por segundo de jogo, que é o que o quadro lento da bateria cheia ainda entrega.
	teto_s = maxf(teto_s, total / 1.5 + 20.0)
	# A caminhada do clique para quando o corpo empaca ("Caminho bloqueado. Escolha outro destino."): quem
	# joga dá um passo de lado e clica de novo, do ponto em que ficou.
	for tentativa in range(8):
		if not jogador.caminhar_ate(ponto):
			if _de_longe(destino) <= basta + 0.3:
				break
			await desempacar(destino, "sem caminho do ponto em que está")
			continue
		# CORRENDO (o duplo clique): quem vai atrás de quem anda, como o Pedro que leva o jogador à fazenda, alcança.
		if correr_ao_andar:
			jogador.set("_walk_run", true)
		await esperar(func() -> bool:
			return not (jogador._walk_destination as Vector3).is_finite(), teto_s)
		if (jogador._walk_destination as Vector3).is_finite():
			_nao_deu("o jogador não chegou a %s em %.0f s de jogo (parou em %s, a %.1f u do destino %s)" % [
				str(ponto), teto_s, str(jogador.global_position), _de_longe(destino), str(destino)])
			return false
		# A grade do clique tem células de 2,5 u: a caminhada acaba na célula, perto do ponto, e o último
		# trecho é do `guiar_ate`. Só empacou DE VERDADE quem parou longe disso.
		if _de_longe(destino) <= maxf(basta + 3.0, 5.5):
			break
		await desempacar(destino, "a caminhada parou antes do fim")
	if _de_longe(destino) > basta:
		await guiar_ate(destino, maxf(basta - 0.5, 0.6), 14.0)
	if _de_longe(destino) > basta + 0.3 and _de_longe(destino) <= 8.0 and not _e_alvo_de_trabalho(destino):
		# PRESO EM UM CANTO A POUCOS METROS DO ALVO (a malha do clique deixa o corpo numa fresta entre as paredes
		# da casa, e as setas não tiram dali): último recurso, o jogador é posto no ponto de pisar ao lado do alvo.
		# NÃO PARA ALVO DE TRABALHO (tronco, pedra, capim, ostra): esses o jogador alcança de verdade — os dois
		# troncos do roçado ficavam num canto de paredes atrás da casa de taipa, o atalho os escondia, e agora
		# eles estão em chão aberto e `tests/alcance_dos_alvos.gd` cobra o clique de todos. Alvo que não se
		# alcança sem atalho volta como "não deu", e o jogador escolhe outro.
		var livres := chegadas(destino, ideal, jogador.global_position, maxf(maximo, ideal + 3.0), 1)
		if not livres.is_empty():
			atalho("preso num canto a menos de 8 u do alvo (a malha do clique acaba numa fresta entre paredes): posto no ponto de pisar ao lado dele")
			contar.call("    ... preso em %s a %.1f u de %s: posto em %s" % [str(jogador.global_position), _de_longe(destino), str(destino), str(livres[0])])
			jogador.teleportar(livres[0], atan2(destino.x - livres[0].x, destino.z - livres[0].z))
			await quadros(3)
	if _de_longe(destino) > basta + 0.3:
		_nao_deu("a caminhada parou a %.1f u de %s (o jogador está em %s; ficar a até %.1f). Em volta dele: %s" % [
			_de_longe(destino), str(destino), str(jogador.global_position), basta, corpos_em_volta(1.6)])
		return false
	if olhar:
		virar_para(destino)
	await quadros(2)
	return true


## `ponto` é o de um alvo de trabalho do vale (`Recursos3D`)? O alvo de trabalho não tem o atalho do canto.
func _e_alvo_de_trabalho(ponto: Vector3) -> bool:
	var recursos = vale.get_node_or_null("Recursos3D")
	if recursos == null:
		return false
	for id in recursos._alvos:
		var onde: Vector3 = recursos._alvos[id]["pos"]
		if Vector2(onde.x - ponto.x, onde.z - ponto.z).length() < 0.05:
			return true
	return false


## Empacou: dá um passo de lado (alternando a mão) e um à frente, virado para `alvo`, e diz em quê bateu.
func desempacar(alvo: Vector3, porque: String) -> void:
	var quem: PackedStringArray = []
	for i in range(jogador.get_slide_collision_count()):
		var corpo = jogador.get_slide_collision(i).get_collider()
		quem.append(str((corpo as Node).name) if corpo is Node else str(corpo))
	contar.call("    ... empacou (%s) em %s, a %.1f u de %s; bateu em: %s; em volta: %s" % [porque, str(jogador.global_position), _de_longe(alvo), str(alvo), ", ".join(quem), corpos_em_volta(1.6)])
	_mao_do_passo = -_mao_do_passo
	var mao := "mv_left" if _mao_do_passo > 0.0 else "mv_right"
	Input.action_press(mao)
	var ate: float = relogio.agora() + 0.9
	while relogio.agora() < ate:
		virar_para(alvo)
		await arvore.process_frame
	Input.action_release(mao)
	Input.action_press("mv_forward")
	ate = relogio.agora() + 0.9
	while relogio.agora() < ate:
		virar_para(alvo)
		await arvore.process_frame
	Input.action_release("mv_forward")
	await arvore.process_frame


var _mao_do_passo := 1.0


func _nao_deu(motivo: String) -> void:
	ultimo_motivo = motivo
	if not calado:
		reprovar.call(motivo)


## Os corpos (parede, tronco, gente) a até `raio` do jogador, com o ponto de cada um: o que está barrando.
func corpos_em_volta(raio: float) -> String:
	var esfera := SphereShape3D.new()
	esfera.radius = raio
	var pergunta := PhysicsShapeQueryParameters3D.new()
	pergunta.shape = esfera
	pergunta.transform = Transform3D(Basis.IDENTITY, jogador.global_position + Vector3(0.0, 0.8, 0.0))
	pergunta.collision_mask = 0xFFFFF
	pergunta.exclude = [jogador.get_rid()]
	var achados: Array[Dictionary] = (jogador as Node3D).get_world_3d().direct_space_state.intersect_shape(pergunta, 12)
	var nomes: PackedStringArray = []
	for achado in achados:
		var corpo = achado.get("collider")
		if corpo is Node3D:
			nomes.append("%s@(%.1f,%.1f,%.1f)" % [(corpo as Node).name, (corpo as Node3D).global_position.x, (corpo as Node3D).global_position.y, (corpo as Node3D).global_position.z])
	return ", ".join(nomes) if not nomes.is_empty() else "nada"


## A distância no chão do jogador até `ponto`.
func _de_longe(ponto: Vector3) -> float:
	return Vector2(jogador.global_position.x - ponto.x, jogador.global_position.z - ponto.z).length()


## O ÚLTIMO TRECHO COM AS SETAS: vira para `alvo` e segura ir em frente até chegar a `parar_a`. Empacado
## (sem avançar 0,2 u em meio segundo de jogo) — o moleque do píer, um toco, o Pedro —, dá um passo de
## lado, alternando a mão, e volta a ir em frente. Para em `teto_s`.
func guiar_ate(alvo: Vector3, parar_a: float, teto_s: float) -> void:
	var limite: float = relogio.agora() + teto_s
	var ultimo: Vector3 = jogador.global_position
	var ultimo_em: float = relogio.agora()
	var lado := 1.0
	while relogio.agora() < limite and _de_longe(alvo) > parar_a:
		virar_para(alvo)
		Input.action_press("mv_forward")
		await arvore.process_frame
		if relogio.agora() - ultimo_em >= 0.5:
			var andou: float = (jogador.global_position - ultimo).length()
			ultimo = jogador.global_position
			ultimo_em = relogio.agora()
			if andou < 0.2:
				var mao := "mv_left" if lado > 0.0 else "mv_right"
				lado = -lado
				Input.action_press(mao)
				var ate: float = relogio.agora() + 0.8
				while relogio.agora() < ate:
					virar_para(alvo)
					await arvore.process_frame
				Input.action_release(mao)
				ultimo = jogador.global_position
				ultimo_em = relogio.agora()
	Input.action_release("mv_forward")
	await arvore.process_frame


## Vira o corpo para `alvo`: é o que o jogador faz ao chegar de frente, ou com a câmera.
func virar_para(alvo: Vector3) -> void:
	var d: Vector3 = alvo - jogador.global_position
	d.y = 0.0
	if d.length() < 0.05:
		return
	var giro := atan2(d.x, d.z)
	jogador.visual.rotation.y = giro
	jogador.set("_yaw", giro + PI)


## Põe `id` na mão (a barra de mão do jogador: o número que a seleciona).
func por_na_mao(id: String) -> bool:
	var inv := auto("Inventario")
	for i in inv.ESPACOS:
		if str((inv.espacos[i] as Dictionary).get("id", "")) != id:
			continue
		if i >= inv.ESPACOS_MAO:
			inv.trocar(i, inv.ESPACOS_MAO - 1)
			i = inv.ESPACOS_MAO - 1
		inv.selecionar(i)
		return true
	return false


## O E num morador: anda até ele, confere que o FOCO deu a tecla à conversa dele (e não ao pedido
## de outro), aperta o E pela janela. Devolve se o E chegou nele.
##
## Morador anda (o Tonho sai do píer para o convés, para a beira, e volta): o jogador o ALCANÇA, como quem
## corre atrás de alguém — até 6 voltas, cada uma até onde ele está agora — e, quando ele está onde a malha
## do clique não chega (a água, o convés), ESPERA que volte, como quem espera na beira do píer.
func e_no_morador(morador: Node3D, porque: String) -> bool:
	var tecla: Node = vale.get("tecla_dos_moradores")
	var antes: Vector3 = morador.global_position
	var depois_da_caminhada := 0.0
	var motivo := ""
	for volta in range(10):
		var onde: Vector3 = morador.global_position
		if _de_longe(onde) > 5.0 and not alcancavel(onde):
			motivo = "ele estava em %s (%s), onde o caminho do clique não chega" % [str(onde), situacao_do(morador)]
			await passar(3.0)
			continue
		calado = true
		correr_ao_andar = volta >= 1
		var chegou := await ir_ate(morador.global_position, 1.9)
		correr_ao_andar = false
		calado = false
		if not chegou:
			motivo = ultimo_motivo
			await passar(2.0)
			continue
		depois_da_caminhada = _de_longe(morador.global_position)
		await quadros(3)
		# DOIS AO ALCANCE (o Pedro e o Tonho no píer): o E vai ao mais perto, entre os que valem o mesmo. Quem joga
		# chega mais perto de quem quer, e vira para ele.
		for chega_mais in range(2):
			if tecla.perto() == morador or _de_longe(morador.global_position) > tecla.ALCANCE:
				break
			await guiar_ate(morador.global_position, 0.9 - 0.2 * float(chega_mais), 4.0)
			virar_para(morador.global_position)
			await quadros(3)
		if tecla.perto() == morador or _de_longe(morador.global_position) <= tecla.ALCANCE - 0.4:
			motivo = ""
			break
		motivo = "ao chegar, ele já estava a %.1f u" % _de_longe(morador.global_position)
	if motivo != "":
		reprovar.call("%s: não consegui chegar em %s: %s" % [porque, nome_de(morador), motivo])
		return false
	var dono := dono_do_e()
	var perto = tecla.perto()
	if dono != tecla or perto != morador:
		reprovar.call("%s: ao lado de %s (a %.2f u; logo depois de chegar a %.2f u) o E é de %s e a conversa seria de %s. Concorrem: %s. Ele estava em %s, está em %s; o jogador está em %s" % [
			porque, nome_de(morador), _de_longe(morador.global_position), depois_da_caminhada, nome_de(dono), nome_de(perto), explicar_o_foco(),
			str(antes), str(morador.global_position), str(jogador.global_position)])
		return false
	await apertar(KEY_E)
	return true


## O que o morador está fazendo, para o diagnóstico: o alvo da agenda dele, a ação, se dá passagem.
func situacao_do(morador: Node) -> String:
	return "alvo %s, ação '%s', dando passagem=%s" % [str(morador.get("_alvo")), str(morador.get("_acao")), str(morador.call("dando_passagem")) if morador.has_method("dando_passagem") else "?"]


## O corpo chega perto de `ponto` pelo caminho do clique? Algum ponto de parar em volta dele tem caminho que
## acaba a até 6 u dele (o resto são as setas). Não: o alvo está onde a malha não vai — a água, o convés.
func alcancavel(ponto: Vector3) -> bool:
	for candidato in chegadas(ponto, 1.9, jogador.global_position, 8.0, 8):
		var caminho := caminho_ate(candidato)
		if caminho.is_empty():
			continue
		var fim: Vector3 = caminho[caminho.size() - 1]
		if Vector2(fim.x - ponto.x, fim.z - ponto.z).length() <= 6.0:
			return true
	return false
