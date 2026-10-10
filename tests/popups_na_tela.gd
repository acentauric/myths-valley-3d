extends "res://tests/suite/caso.gd"
## OS POPUPS DO MUNDO SÃO POUCOS E TÊM PESO (placas_nomes.gd, dica_tecla.gd, balao_fala.gd,
## seta_missao.gd, arvores_info.gd, suavizador_de_tela.gd, popups_do_mundo.gd).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste popups_na_tela
##     $env:MV_FALSIFICAR = "popups"    (o portão TEM de reprovar: o jogo de antes, sem mola, sem
##                                       teto de placas e sem permanência do balão)
##
## "Tem muitos popups de personagem, precisamos limitar essa quantidade para evitar poluir
## a tela, e a animação de movimentação tem que ser resistente, no sentido de não variar
## tanto e tão rápido com a movimentação do personagem na câmera: devem deslizar com
## maior peso na tela, em vez de ficar gritando tentando se ajustar." (Build 9B)
##
##   1. A MOLA, sem mundo: um degrau não é um pulo, nada passa do alvo, o tremor de um
##      pixel não move nada, a correia segura o popup perto do alvo numa virada rápida e
##      o corte de câmera vai direto.
##   2. O AFASTAMENTO E AS REGRAS, sem mundo: a dica sobe para cima do que cobriria (só o que
##      falta, sem salto, empilhando sobre duas); o dono do E e o alvo da missão levam placa
##      antes de qualquer distância (só o dono do E não cede a ninguém), o teto vale, quem já
##      tem a placa não a perde por um empate; o balão só troca de canto depois da permanência,
##      e o canto novo é um deslizar.
##   3. O TETO, com os moradores da roda à frente da câmera: nunca mais de três placas ligadas,
##      e três delas ligadas — o teto não é só "esconder tudo".
##   4. QUEM PASSA NA FRENTE: o alvo da missão, o mais longe de todos, leva a placa; e a perde
##      ao acabar a missão.
##   5. NINGUÉM COBRE NINGUÉM: a dica do E sobe acima da placa do dono dela, com a câmera perto
##      e longe (e a conta crua DE ANTES a cobriria); a placa de quem está atrás dele, na coluna
##      da dica, cede — e volta quando a dica some —; com o morador falando, a placa dele some,
##      o balão deixa a dica embaixo, nenhuma placa fica sob o balão, e são no máximo duas
##      placas e quatro popups de personagem.
##   5b. O "?"/"!" DE MISSÃO POR CIMA (#216): o marcador sobre a cabeça é do mundo 3D e o mundo desenha
##      antes de toda interface; a dica do E e o balão saem da frente dele (a dica sem a regra
##      o cobriria), com a câmera perto.
##   6. O PESO NA CÂMERA: numa varredura rápida a placa, a dica do E, o chevron da missão, a
##      vida da árvore e o balão andam menos depressa que o ponto a que estão presos e assentam
##      sem passar dele; o tremor de um pixel da câmera não move a dica; o chevron e a vida da
##      árvore acendem aos poucos e no lugar; o balão não troca de canto antes da permanência.
##   7. A FALA LONGA EM PÁGINAS: o balão mostra duas linhas por vez, no ritmo da fila, com o
##      texto inteiro no rótulo e a altura limitada.
##
## Espera em segundos de JOGO (tests/fixtures/relogio_de_jogo.gd): a bateria cheia roda muitos
## Godot de uma vez, e o quadro devagar não pode reprovar o portão. A velocidade se mede em
## janelas de 0,1 s de jogo, e não quadro a quadro: o quadro da máquina cheia mede o relógio.

## Recebe o vale montado do zero: reprovava no vale deixado pelos casos anteriores (a suíte, #242).
const VALE_NOVO := true

const SuavizadorDeTela = preload("res://scripts/prototipo_3d/suavizador_de_tela.gd")
const PopupsDoMundo = preload("res://scripts/prototipo_3d/popups_do_mundo.gd")
const RelogioDeJogo = preload("res://tests/fixtures/relogio_de_jogo.gd")

## Os lugares da roda (à frente, de lado), em metros a partir do jogador: 15 postos.
const RODA := [
	[5.0, -6.0], [5.0, -3.0], [5.0, 0.0], [5.0, 3.0], [5.0, 6.0],
	[7.5, -7.5], [7.5, -4.5], [7.5, -1.5], [7.5, 1.5], [7.5, 4.5], [7.5, 7.5],
	[10.0, -6.0], [10.0, -2.0], [10.0, 2.0], [10.0, 6.0],
]
const FALA_LONGA := "Ai, menino, o vale amanheceu cheio de novidade e eu nem tive tempo de contar tudo: a roça de Cosme deu milho, a Dona Filó fez pirão para meia aldeia, o Tonho puxou rede de manhã cedo e o coveiro anda de cara amarrada porque o capim não para de crescer entre as lápides do cemitério velho. Passa lá mais tarde, que a conversa é longa."
## A janela (s de jogo) em que se mede a velocidade dos popups.
const JANELA := 0.1
const FALA_CURTA := "Bom dia, meu filho. Chegue mais perto."

var falhas := 0
var falsificar := false
var relogio: Node
var vale
var jogador
var camera: Camera3D
var placas
var fila
## Os moradores da roda e o ponto onde cada um fica (reposto a cada quadro).
var roda: Array = []
var pontos: Array[Vector3] = []


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("POPUPS_NA_TELA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	falsificar = OS.get_environment("MV_FALSIFICAR") == "popups"
	if falsificar:
		print("  FALSIFICAÇÃO: sem mola, sem teto de placas e sem permanência do balão (MV_FALSIFICAR=popups)")
		SuavizadorDeTela.desligado = true
	_a_mola()
	_o_afastamento()

	relogio = RelogioDeJogo.new()
	root.add_child(relogio)
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	relogio.ficar_lento()
	vale = current_scene
	jogador = vale.player
	placas = vale.get("placas")
	fila = vale.get("fila_de_falas")
	var dia = root.get_node("/root/Dia")
	dia.pausado = true
	dia.definir_hora(18.0)
	_conferir(placas != null and fila != null and vale.get("tecla_dos_moradores") != null,
		"o vale não montou as placas (%s), a fila de falas (%s) ou o E dos moradores (%s)"
			% [str(placas), str(fila), str(vale.get("tecla_dos_moradores"))])
	if placas == null or fila == null or vale.get("tecla_dos_moradores") == null:
		_fechar()
		return
	camera = jogador.get("camera")
	# A apresentação do povoado esconde e desliga quem está longe do jogador até a visita
	# chegar perto: sem liberar o elenco só uns cinco moradores sobravam à vista para a roda.
	for i in 600:
		if vale.apresentacao_do_povoado != null:
			break
		await process_frame
	vale.apresentacao_do_povoado.liberar_todos()
	await _quadros(4)
	if falsificar:
		placas.maximo = 99
	# #218: com um balão no ar nenhuma placa fica na tela. As medidas do teto, da frente e do peso
	# precisam das placas acesas e não esperam a fala solta do vale passar: o silêncio com balão liga
	# só na seção 5, onde o morador fala, e tem o portão próprio em `placas_e_baloes`.
	placas.cala_com_balao = false
	_as_regras()

	# A cena: o jogador na praça, o Pedro fora do caminho (ele segue o jogador e falaria).
	var pedro = vale.get("pedro")
	if pedro != null:
		pedro.missao = pedro.MISSOES.size()
		pedro.set("_despedida_feita", true)
		pedro.visible = false
		# Escondido ele ainda falaria (o balão mora numa camada de interface, que o corpo escondido não esconde).
		pedro.process_mode = Node.PROCESS_MODE_DISABLED
	var praca: Vector3 = vale.world.ancoras.get("Praça", jogador.global_position)
	var aqui: Vector3 = vale.world.ground_position(praca + Vector3(3.0, 0.0, 3.0), 0.1)
	jogador.teleportar(aqui, 0.0)
	_montar_a_roda(aqui)
	_conferir(roda.size() >= 12, "só %d moradores no vale para montar a roda; o portão pede 12 ou mais" % roda.size())
	await _quadros(4)
	await relogio.ate(func() -> bool: return fila.livre(), 30.0)

	await _o_teto()
	await _quem_passa_na_frente()
	await _ninguem_cobre_ninguem(aqui)
	await _o_marcador_por_cima(aqui)
	await _o_peso_das_placas()
	await _o_peso_da_dica()
	await _o_peso_do_chevron()
	await _o_peso_da_vida_da_arvore()
	await _o_peso_do_balao()
	await _as_paginas()
	_fechar()


# --- 1. A MOLA, SEM MUNDO ----------------------------------------------------------------------

func _a_mola() -> void:
	var dt := 1.0 / 60.0
	# UM DEGRAU DE 50 PX não é um pulo: o primeiro quadro anda uma fração, nada passa do
	# alvo, nunca se anda para trás, e em 1,2 s o popup assentou (a zona morta deixa dois pixels).
	var mola = SuavizadorDeTela.new()
	mola.reiniciar(Vector2.ZERO)
	var x := 0.0
	var maior := 0.0
	var para_tras := 0.0
	var primeiro := 0.0
	for i in 72:
		var antes: float = mola.posicao.x
		x = mola.seguir(Vector2(50.0, 0.0), dt).x
		if i == 0:
			primeiro = x
		maior = maxf(maior, x)
		para_tras = maxf(para_tras, antes - x)
	_conferir(primeiro <= 12.5, "a mola pulou %.1f px no primeiro quadro de um degrau de 50: é um pulo, não peso" % primeiro)
	_conferir(maior <= 50.01, "a mola passou do alvo: foi a %.2f num degrau de 50" % maior)
	_conferir(para_tras <= 0.01, "a mola andou %.2f px para trás: balançou" % para_tras)
	_conferir(absf(x - 50.0) <= 3.0, "em 1,2 s a mola ainda está a %.1f px do alvo de um degrau de 50" % absf(x - 50.0))

	# O TREMOR DE 1,5 PX da câmera, com o popup assentado, não o move (zona morta de 2 px).
	var quieta = SuavizadorDeTela.new()
	quieta.reiniciar(Vector2(300.0, 300.0))
	var menor_x := 1e9
	var maior_x := -1e9
	for i in 120:
		var tremor := 1.5 if i % 2 == 0 else -1.5
		var p: Vector2 = quieta.seguir(Vector2(300.0 + tremor, 300.0 - tremor), dt)
		menor_x = minf(menor_x, p.x)
		maior_x = maxf(maior_x, p.x)
	_conferir(maior_x - menor_x < 0.5, "o tremor de 1,5 px da câmera moveu o popup %.2f px: a zona morta não segurou" % (maior_x - menor_x))

	# O CORTE DE CÂMERA (700 px de uma vez) vai direto: é outro lugar, não movimento.
	var corte = SuavizadorDeTela.new()
	corte.reiniciar(Vector2.ZERO)
	corte.seguir(Vector2(5.0, 0.0), dt)
	var depois: Vector2 = corte.seguir(Vector2(705.0, 0.0), dt)
	_conferir(depois.is_equal_approx(Vector2(705.0, 0.0)), "o corte de câmera de 700 px varreu a tela em vez de ir direto (parou em %s)" % str(depois))

	# A CORREIA: o alvo a 1500 px/s, que a mola não alcança, deixa o popup para trás, mas perto —
	# e sem pulo nenhum: cada quadro anda no máximo o que o alvo andou.
	var correia = SuavizadorDeTela.new()
	correia.reiniciar(Vector2.ZERO)
	var alvo := Vector2.ZERO
	var folga_maxima := 0.0
	var folga_no_fim := 0.0
	var passo_maior := 0.0
	for i in 90:
		alvo += Vector2(25.0, 0.0)
		var antes: Vector2 = correia.posicao
		var p: Vector2 = correia.seguir(alvo, dt)
		passo_maior = maxf(passo_maior, p.distance_to(antes))
		if i >= 30:
			folga_maxima = maxf(folga_maxima, alvo.distance_to(p))
		folga_no_fim = alvo.distance_to(p)
	_conferir(folga_maxima <= SuavizadorDeTela.CORREIA + 2.0, "a correia deixou o popup a %.0f px do alvo (a correia é de %.0f)" % [folga_maxima, SuavizadorDeTela.CORREIA])
	_conferir(folga_no_fim >= 50.0, "o popup acompanhou o alvo a 1500 px/s colado (a %.0f px): sem peso nenhum" % folga_no_fim)
	_conferir(passo_maior <= 26.0, "o popup deu um passo de %.0f px, mais que os 25 px do alvo: pulou" % passo_maior)


## O AFASTAMENTO (popups_do_mundo.gd), sem mundo: quem encosta sobe para cima do obstáculo — só o que falta, sem
## salto no começo do encontro —, e quem não encosta fica onde está.
func _o_afastamento() -> void:
	var placa := Rect2(100.0, 300.0, 100.0, 26.0)
	var obstaculos: Array[Rect2] = [placa]
	var dica := Rect2(110.0, 290.0, 120.0, 36.0)
	var sobe: Rect2 = PopupsDoMundo.afastar_de(dica, obstaculos, 3.0)
	_conferir(is_equal_approx(sobe.end.y, placa.position.y - 3.0) and sobe.position.x == dica.position.x,
		"a dica que cobria a placa não ficou 3 px acima dela (parou em y=%.1f..%.1f, a placa começa em %.1f)" % [sobe.position.y, sobe.end.y, placa.position.y])
	_conferir(PopupsDoMundo.afastar_de(Rect2(400.0, 290.0, 120.0, 36.0), obstaculos, 3.0) == Rect2(400.0, 290.0, 120.0, 36.0), "a dica ao lado da placa foi empurrada")
	_conferir(PopupsDoMundo.afastar_de(Rect2(110.0, 240.0, 120.0, 36.0), obstaculos, 3.0) == Rect2(110.0, 240.0, 120.0, 36.0), "a dica bem acima da placa foi empurrada")
	# Sem salto: cobrindo meio pixel (além da folga), o empurrão é de meio pixel, e não de uma placa inteira.
	var quase := Rect2(110.0, 300.0 - 3.0 - 36.0 + 0.5, 120.0, 36.0)
	var um_tico: Rect2 = PopupsDoMundo.afastar_de(quase, obstaculos, 3.0)
	_conferir(absf(um_tico.position.y - quase.position.y) <= 1.0, "a dica que mal encostou na folga da placa saltou %.1f px" % absf(um_tico.position.y - quase.position.y))
	# Debaixo do centro da placa: sobe também (descer botaria a dica sobre o que ela devia deixar embaixo).
	var por_baixo := Rect2(110.0, 315.0, 120.0, 36.0)
	var sobe_sempre: Rect2 = PopupsDoMundo.afastar_de(por_baixo, obstaculos, 3.0)
	_conferir(is_equal_approx(sobe_sempre.end.y, placa.position.y - 3.0), "a dica abaixo do centro da placa não subiu para cima dela (até y=%.1f)" % sobe_sempre.end.y)
	# Empilha sobre duas.
	var duas: Array[Rect2] = [placa, Rect2(100.0, 260.0, 100.0, 26.0)]
	var empilhada: Rect2 = PopupsDoMundo.afastar_de(dica, duas, 3.0)
	_conferir(empilhada.end.y <= 260.0 - 3.0 + 0.01, "a dica sobre duas placas empilhadas parou em y=%.1f, e a de cima começa em 260" % empilhada.end.y)

	# A dica do E também respeita o HUD (#184): desce para baixo da barra, encosta ao lado, ou se apaga.
	var tela := Vector2(1280.0, 720.0)
	var barra := Rect2(20.0, 40.0, 300.0, 24.0)
	var no_hud: Array[Rect2] = [barra]
	var por_cima := Rect2(100.0, 30.0, 120.0, 36.0)
	var desceu: Rect2 = PopupsDoMundo.livre_do_hud(por_cima, no_hud, 6.0, tela)
	_conferir(desceu.size != Vector2.ZERO and desceu.position.y >= barra.end.y + 6.0 - 0.01 and desceu.position.x == por_cima.position.x,
		"a dica sobre a barra de vigor não desceu para baixo dela (ficou em %s)" % str(desceu))
	var longe_da_barra := Rect2(600.0, 300.0, 120.0, 36.0)
	_conferir(PopupsDoMundo.livre_do_hud(longe_da_barra, no_hud, 6.0, tela) == longe_da_barra, "a dica longe do HUD foi mexida")
	var tapando: Array[Rect2] = [Rect2(0.0, 0.0, 1280.0, 720.0)]
	_conferir(PopupsDoMundo.livre_do_hud(longe_da_barra, tapando, 6.0, tela).size == Vector2.ZERO, "a dica sem lugar nenhum não pediu para se apagar")
	var lado: Array[Rect2] = [Rect2(100.0, 0.0, 130.0, 720.0)]
	var encostou: Rect2 = PopupsDoMundo.livre_do_hud(Rect2(110.0, 300.0, 120.0, 36.0), lado, 6.0, tela)
	_conferir(encostou.size != Vector2.ZERO and (encostou.end.x <= 100.0 - 6.0 + 0.01 or encostou.position.x >= 230.0 + 6.0 - 0.01),
		"a dica sobre um painel alto não encostou ao lado dele (ficou em %s)" % str(encostou))


# --- 2. AS REGRAS, SEM MUNDO -------------------------------------------------------------------

func _as_regras() -> void:
	# O DONO DO E E O ALVO DA MISSÃO vencem as distâncias, e o teto vale.
	var muitos: Array = []
	for i in 8:
		muitos.append(_candidato(2.0 + i, 110.0 * i))
	muitos.append(_candidato(15.0, 1000.0, {"dono_do_e": true}))
	muitos.append(_candidato(14.0, 1200.0, {"da_missao": true}))
	var escolhidos: Array = placas.escolher(muitos, 3)
	_conferir(escolhidos.size() == 3, "o teto de três deu %d placas" % escolhidos.size())
	_conferir(escolhidos.has(8) and escolhidos.has(9), "o dono do E ou o alvo da missão, longe, ficou sem placa: %s" % str(escolhidos))
	_conferir(escolhidos.has(0), "o morador mais perto ficou sem a terceira placa: %s" % str(escolhidos))
	_conferir(placas.escolher(muitos, 0).is_empty(), "com teto zero, alguém levou placa")
	# QUEM JÁ TEM A PLACA NÃO A PERDE POR UM EMPATE: três metros de bônus; mais que isso, perde.
	var duas: Array = [_candidato(5.0, 0.0), _candidato(6.5, 300.0, {"tinha": true})]
	_conferir(str(placas.escolher(duas, 1)) == "[1]", "quem já tinha a placa a perdeu para um empate de 1,5 m: troca de vaga a cada quadro")
	duas = [_candidato(5.0, 0.0), _candidato(9.0, 300.0, {"tinha": true})]
	_conferir(str(placas.escolher(duas, 1)) == "[0]", "quem já tinha a placa a manteve com 4 m a mais de distância")
	# A PLACA POR CIMA DE UMA MELHOR NÃO ENTRA, e o dono do E entra por cima de qualquer uma.
	var por_cima: Array = [_candidato(5.0, 100.0), _candidato(6.0, 110.0), _candidato(8.0, 400.0)]
	_conferir(str(placas.escolher(por_cima, 2)) == "[0, 2]", "a placa quase em cima de uma melhor entrou: %s" % str(placas.escolher(por_cima, 2)))
	por_cima = [_candidato(5.0, 100.0), _candidato(6.0, 110.0, {"dono_do_e": true})]
	_conferir(str(placas.escolher(por_cima, 2)) == "[1]", "o dono do E, sobreposto a uma placa comum, não ficou sozinho com a dele: %s" % str(placas.escolher(por_cima, 2)))
	por_cima = [_candidato(5.0, 100.0, {"da_missao": true}), _candidato(6.0, 110.0, {"dono_do_e": true})]
	_conferir(str(placas.escolher(por_cima, 2)) == "[1]", "o alvo da missão, por cima da placa do dono do E, não cedeu a ele: %s" % str(placas.escolher(por_cima, 2)))

	# A PERMANÊNCIA DO BALÃO: notas que trocam de favorito a cada quadro não trocam o canto mais
	# que uma vez por `permanencia`. (A conta é a do próprio balão: `decidir_canto`.)
	var balao_de_prova = load("res://scripts/prototipo_3d/balao_fala.gd").new()
	if falsificar:
		balao_de_prova.permanencia = 0.0
	var permanencia: float = balao_de_prova.permanencia
	var canto := 0
	var parado := 0.0
	var troca_em: Array[float] = []
	var agora := 0.0
	for i in 600:
		var notas: Array[float] = []
		notas.assign([100.0, 10.0, 200.0, 200.0, 200.0] if i % 2 == 0 else [10.0, 100.0, 200.0, 200.0, 200.0])
		var novo: int = balao_de_prova.decidir_canto(notas, canto, parado, permanencia)
		parado += 1.0 / 60.0
		agora += 1.0 / 60.0
		if novo != canto:
			canto = novo
			parado = 0.0
			troca_em.append(agora)
	var mais_curta := 1e9
	for i in range(1, troca_em.size()):
		mais_curta = minf(mais_curta, troca_em[i] - troca_em[i - 1])
	_conferir(troca_em.size() <= int(10.0 / maxf(permanencia, 0.05)) + 1,
		"o balão trocou de canto %d vezes em 10 s com a escolha mudando a cada quadro: não pára quieto" % troca_em.size())
	_conferir(mais_curta >= permanencia - 0.02, "o balão trocou de canto %.2f s depois da troca anterior, e a permanência é de %.2f s" % [mais_curta, permanencia])
	# O CANTO NOVO DESLIZA: a troca muda o alvo da caixa de uma vez (300 px), e ela vai até lá em
	# quadros — sem teleporte, com os números do próprio balão.
	var caixa_mola = SuavizadorDeTela.new()
	caixa_mola.reiniciar(Vector2(400.0, 500.0))
	var maior_passo := 0.0
	var onde_estava: Vector2 = caixa_mola.posicao
	for i in 90:
		var p: Vector2 = caixa_mola.seguir(Vector2(700.0, 500.0), 1.0 / 60.0, balao_de_prova.TEMPO_DE_SEGUIR,
			SuavizadorDeTela.VELOCIDADE_MAXIMA, balao_de_prova.ZONA_MORTA, balao_de_prova.CORREIA,
			balao_de_prova.SALTO, balao_de_prova.PUXAO)
		maior_passo = maxf(maior_passo, p.distance_to(onde_estava))
		onde_estava = p
	_conferir(maior_passo <= 40.0, "a troca de canto do balão (300 px) foi um teleporte de %.0f px num quadro, e não um deslizar" % maior_passo)
	_conferir(absf(onde_estava.x - 700.0) <= 4.0, "1,5 s depois da troca de canto o balão ainda estava a %.0f px do canto novo" % absf(onde_estava.x - 700.0))
	balao_de_prova.free()
	print("  regras: o balão de prova trocou %d vez(es) em 10 s (permanência %.2f s); o canto novo desliza a no máximo %.0f px por quadro" % [troca_em.size(), permanencia, maior_passo])


## Um candidato à placa, para as regras sem mundo: a `distancia`, a caixa a partir de `x`.
func _candidato(distancia: float, x: float, extra: Dictionary = {}) -> Dictionary:
	var candidato := {"distancia": distancia, "rumo": 0.0, "caixa": Rect2(x, 300.0, 100.0, 26.0),
		"dono_do_e": false, "da_missao": false, "tinha": false}
	candidato.merge(extra, true)
	return candidato


# --- 3. O TETO ----------------------------------------------------------------------------------

func _o_teto() -> void:
	var teto: int = placas.MAXIMO_DE_PLACAS
	var elegiveis := 0
	for morador in roda:
		if morador.nome_label.is_visible_in_tree():
			elegiveis += 1
	_conferir(elegiveis >= 8, "só %d dos moradores da roda estão no vale para a placa; o portão pede 8 ou mais" % elegiveis)
	await relogio.ate(func() -> bool: return _placas_ligadas() >= teto, 4.0)
	await _esperar(1.2)
	var maior := 0
	var quem_estava := _quem_tem_placa()
	var trocas_de_vaga := 0
	for i in 90:
		await _quadro()
		maior = maxi(maior, _placas_ligadas())
		var quem_esta := _quem_tem_placa()
		if quem_esta != quem_estava:
			trocas_de_vaga += 1
			quem_estava = quem_esta
	# Tudo parado (a roda, a câmera): as vagas não trocam de mão. Caixas a um pixel do limite de sobreposição
	# faziam a vaga piscar de um para outro, e a tela com ela.
	_conferir(trocas_de_vaga == 0, "com a roda e a câmera paradas, as placas trocaram de dono %d vez(es) em 90 quadros: a vaga pisca" % trocas_de_vaga)
	_conferir(maior <= teto, "%d placas ligadas ao mesmo tempo com %d moradores à vista: o teto é de %d" % [maior, elegiveis, teto])
	# Com um balão no ar são duas (o balão e o nome de quem fala já são dois popups de personagem).
	var com_balao := _baloes_no_ar()
	var esperadas := teto - (1 if com_balao > 0 else 0)
	# #124/#127: rótulo redundante e moradores atrás de cenário não ocupam vagas;
	# teto não obriga a mostrar nome oculto. A matriz sintética verifica os nomes úteis.
	_conferir((_placas_ligadas() > 0 and _placas_ligadas() <= esperadas) or _baloes_no_ar() != com_balao,
		"a roda ficou sem nomes úteis ou ultrapassou o teto após supressões contextuais")
	print("  teto: %d moradores à vista, no máximo %d placas ligadas (teto %d)" % [elegiveis, maior, teto])


# --- 4. QUEM PASSA NA FRENTE --------------------------------------------------------------------

func _quem_passa_na_frente() -> void:
	var seta = vale.get_node_or_null("SetaMissao")
	_conferir(seta != null and seta.has_method("alvo_atual"), "o vale não tem a seta da missão com `alvo_atual`")
	if seta == null or not seta.has_method("alvo_atual"):
		return
	var longe = roda[roda.size() - 1]
	for morador in roda:
		if morador.global_position.distance_to(jogador.global_position) > longe.global_position.distance_to(jogador.global_position):
			longe = morador
	var placa: Control = placas._placas[longe]
	_conferir(not placa.visible, "o morador mais longe da roda já tinha placa antes da missão apontá-lo")
	seta.definir_alvo(longe.global_position, "")
	var ligou: bool = await relogio.ate(func() -> bool: return placa.visible and placa.modulate.a > 0.9, 4.0)
	_conferir(ligou, "a missão aponta %s, o mais longe da roda, e ele não levou a placa" % longe.name)
	_conferir(_placas_ligadas() <= placas.MAXIMO_DE_PLACAS, "com a missão apontando alguém, há %d placas ligadas" % _placas_ligadas())
	seta.limpar()
	var apagou: bool = await relogio.ate(func() -> bool: return not placa.visible, 4.0)
	_conferir(apagou, "acabou a missão e %s, o mais longe da roda, continua com a placa" % longe.name)
	print("  missão: %s, a %.1f m, levou a placa e a perdeu ao acabar" % [longe.name, longe.global_position.distance_to(jogador.global_position)])


# --- 5. NINGUÉM COBRE NINGUÉM -------------------------------------------------------------------

func _ninguem_cobre_ninguem(aqui: Vector3) -> void:
	var teclas = vale.get("tecla_dos_moradores")
	# O morador a dois passos, de frente: quem vai levar o E.
	var dele: Node3D = roda[2]
	var posto_de_dele: Vector3 = pontos[2]
	var a_dois_passos: Vector3 = _a_dois_passos(aqui, dele)
	_fixar(dele, a_dois_passos)
	var dono: bool = await relogio.ate(func() -> bool: return teclas.perto() == dele and teclas._dica.visible, 6.0)
	_conferir(dono, "a dois passos do %s, de frente, a dica do E não acendeu sobre ele (perto: %s)" % [dele.name, str(teclas.perto())])
	if not dono:
		return
	# ALGUÉM ATRÁS DELE, na mesma linha da câmera, e a missão apontando para esse alguém: a placa dele cairia sob
	# a dica do E (e, depois, sob o balão). Ela cede, em vez de empurrar a dica para longe de quem a recebe.
	# #188: a placa do dono fica à vista sob a dica, e a dica sobe acima dela: o lugar "de antes" é o de
	# depois de a placa acender e de o empurrão dela assentar.
	var placa_do_dono: Control = placas._placas[dele]
	await relogio.ate(func() -> bool: return placa_do_dono.visible and float(placas._alfa.get(dele, 0.0)) >= 1.0, 4.0)
	await _esperar(1.0)
	var dica_antes: Rect2 = teclas._dica.get_global_rect()
	# A dica mora logo acima da placa do dono; a placa dele sobe quando uma cabeça entra sob ela (#184), e a
	# dica sobe junto. O que se mede é a folga entre as duas, e não a altura na tela.
	var folga_antes: float = placa_do_dono.get_global_rect().position.y - dica_antes.end.y
	var atras: Node3D = roda[3]
	var onde_estava_atras: Vector3 = pontos[3]
	# Esta pessoa só disputa identificação na tela. Na profundidade livre ela
	# pode ficar ao alcance: não deve disputar a conversa durante esta fixture.
	var processo_de_atras := atras.process_mode
	atras.process_mode = Node.PROCESS_MODE_DISABLED
	var seta = vale.get_node_or_null("SetaMissao")
	# A cabeça de quem está atrás aparece 8 px acima da placa do dono, sob a dica: o pé dele, pela câmera.
	var ancora_de_tras := Vector2(dica_antes.get_center().x, dica_antes.end.y - 4.0)
	# #127: o antigo ponto a 16 m ficava atrás de uma construção. Aqui se mede
	# disputa na tela: escolha uma profundidade livre na mesma região projetada.
	var montou_livre := false
	for profundidade in [16.0, 14.0, 12.0, 10.0, 8.0, 6.0]:
		var cabeca: Vector3 = camera.project_ray_origin(ancora_de_tras) + camera.project_ray_normal(ancora_de_tras) * profundidade
		var pe: Vector3 = cabeca - Vector3.UP * (float(atras.get("altura")) + 0.1)
		_fixar(atras, pe)
		await _quadros(2)
		placas._oclusao.erase(atras)
		if placas._visivel_para_camera(atras, camera):
			montou_livre = true
			break
	_conferir(montou_livre, "não encontrou posição visível para disputar nome e dica; cenário bloqueia a pessoa (#127)")
	if seta != null:
		seta.definir_alvo(atras.global_position, "")
	await _esperar(2.0)
	var placa_de_tras: Control = placas._placas[atras]
	var dica_agora: Rect2 = teclas._dica.get_global_rect()
	var tamanho_de_tras: Vector2 = placa_de_tras.get_combined_minimum_size()
	var topo_de_tras: Vector3 = atras.global_position + Vector3(0.0, float(atras.get("altura")) + 0.1, 0.0)
	var cairia := Rect2(camera.unproject_position(topo_de_tras) - Vector2(tamanho_de_tras.x * 0.5, tamanho_de_tras.y), tamanho_de_tras)
	_conferir(cairia.intersects(dica_antes), "o portão não montou a cena: a placa de quem está atrás (%s) não cairia sob a dica do E (%s)" % [str(cairia), str(dica_antes)])
	_conferir(not (placa_de_tras.visible and placa_de_tras.modulate.a > 0.25), "a placa de quem está atrás de quem recebe o E ficou na tela, por cima da dica dele")
	var folga_agora: float = placa_do_dono.get_global_rect().position.y - dica_agora.end.y
	_conferir(absf(folga_agora - folga_antes) <= 2.0, "a placa de quem está atrás empurrou a dica do E para longe da placa do dono dela (folga de %.0f px para %.0f px)" % [folga_antes, folga_agora])
	for outra in placas._placas.values():
		if outra.visible and outra.modulate.a > 0.25 and outra.get_global_rect().intersects(dica_agora):
			_conferir(false, "uma placa de nome ficou sob a dica do E de quem vai receber o E (placa %s, dica %s)" % [str(outra.get_global_rect()), str(dica_agora)])
	# O CONTROLE: sem a dica do E por cima (o dono se afasta), a placa de quem está atrás APARECE — ela só cedia à dica —,
	# e quando o dono volta e a dica acende, ela cede de novo e a dica volta ao lugar de antes.
	_fixar(dele, posto_de_dele)
	var apareceu: bool = await relogio.ate(func() -> bool: return placa_de_tras.visible and placa_de_tras.modulate.a > 0.9, 5.0)
	_conferir(apareceu and not teclas._dica.visible, "sem a dica do E, a placa de quem a missão aponta, atrás dele, não apareceu (visível %s, nome no vale %s, a dica ainda acesa %s, a %.1f m)"
		% [str(placa_de_tras.visible), str(atras.nome_label.is_visible_in_tree()), str(teclas._dica.visible), atras.global_position.distance_to(jogador.global_position)])
	_fixar(dele, a_dois_passos)
	var voltou: bool = await relogio.ate(func() -> bool: return teclas.perto() == dele and teclas._dica.visible, 6.0)
	_conferir(voltou, "o dono do E voltou e a dica dele não acendeu de novo")
	await _esperar(2.0)
	var dono_visivel: Control = placas._placas[dele]
	var estado_das_placas := " (dono: placa %s a%.2f em %s; atrás: placa %s a%.2f em %s; dica %s; ligadas %d; teto %d)" % [
		str(dono_visivel.visible), dono_visivel.modulate.a, str(dono_visivel.get_global_rect()), str(placa_de_tras.visible), placa_de_tras.modulate.a,
		str(placa_de_tras.get_global_rect()), str(teclas._dica.get_global_rect()), _placas_ligadas(), placas.maximo]
	_conferir(not (placa_de_tras.visible and placa_de_tras.modulate.a > 0.25), "com a dica de volta, a placa de quem está atrás, na coluna da dica, continuou na tela" + estado_das_placas)
	# #188: a dica diz só "Conversar", e quem é o morador a placa de nome diz — ela fica à vista, sob a dica.
	_conferir(dono_visivel.visible and dono_visivel.modulate.a > 0.25, "a dica do E diz só 'Conversar': a placa de nome do dono tem de ficar à vista (#188)" + estado_das_placas)
	_conferir(not dono_visivel.get_global_rect().intersects(teclas._dica.get_global_rect()), "a dica do E cobre a placa de nome do dono" + estado_das_placas)
	var folga_de_volta: float = dono_visivel.get_global_rect().position.y - teclas._dica.get_global_rect().end.y
	_conferir(absf(folga_de_volta - folga_antes) <= 3.0, "a dica do E não voltou ao lugar de antes, logo acima da placa do dono (folga de %.0f px, e era %.0f px)%s" % [folga_de_volta, folga_antes, estado_das_placas])
	var placa: Control = placas._placas[dele]
	var cobriria_longe := false
	for distancia in [5.0, 12.0]:
		jogador.set("_distance", distancia)
		jogador.call("_apply_camera")
		await _esperar(2.0)
		var da_placa: Rect2 = placa.get_global_rect()
		var da_dica: Rect2 = teclas._dica.get_global_rect()
		_conferir(placa.visible and teclas._dica.visible and not da_placa.intersects(da_dica),
			"com a câmera a %.0f m, a dica do E deve ficar acima da placa do dono, sem cobri-la (#188)" % distancia)
		# O que a dica faria SEM subir: a conta crua de antes (o ponto 0,45 m acima da cabeça).
		var ponto := dele.global_position + Vector3.UP * (float(dele.get("altura")) + 0.45)
		var crua := Rect2(camera.unproject_position(ponto) - Vector2(da_dica.size.x * 0.5, da_dica.size.y), da_dica.size)
		if crua.intersects(da_placa):
			cobriria_longe = true
	# Sem a regra de subir, a dica cairia sobre a placa do dono em algum dos dois alcances da câmera.
	_conferir(cobriria_longe, "o portão não montou a cena: a conta crua da dica nunca cobriria a placa do dono, perto nem longe")
	jogador.set("_distance", 8.0)
	jogador.call("_apply_camera")

	# O MESMO MORADOR FALANDO: a placa dele some, o balão sobe acima da dica, e ninguém cobre o balão.
	placas.cala_com_balao = not falsificar
	dele.mostrar_balao(FALA_CURTA, 12.0)
	var falou: bool = await relogio.ate(func() -> bool: return dele.balao.visible and dele.balao.retangulo().size != Vector2.ZERO, 3.0)
	_conferir(falou, "%s não abriu o balão" % dele.name)
	await _esperar(1.4)
	_conferir(not placa.visible, "o morador está falando e a placa de nome dele continua na tela (balão com o nome)")
	var do_balao: Rect2 = dele.balao.retangulo()
	var da_dica: Rect2 = teclas._dica.get_global_rect()
	_conferir(not teclas._dica.visible or teclas.perto() != dele,
		"a fala ativa ainda oferece E para iniciar outra conversa com o mesmo morador (#121)")
	var sob_o_balao := 0
	var ligadas := 0
	for outro in placas._placas.values():
		if outro.visible and outro.modulate.a > 0.25:
			ligadas += 1
			if outro.get_global_rect().intersects(do_balao):
				sob_o_balao += 1
	_conferir(sob_o_balao == 0, "%d placa(s) de nome sob o balão de quem fala" % sob_o_balao)
	_conferir(ligadas == 0 or falsificar, "com um balão no ar há %d placas de nome na tela; o balão tem prioridade e nenhuma fica (#218)" % ligadas)
	var no_total := ligadas + 1 + (1 if teclas._dica.visible else 0)
	_conferir(no_total <= 4 or falsificar, "%d popups de personagem ao mesmo tempo (%d placas, o balão e a dica): o teto é de quatro" % [no_total, ligadas])
	print("  cobrir: a dica sobe acima da placa em câmera perto e longe; falando, a placa some, são %d popups de personagem" % no_total)
	dele.mostrar_balao("", 0.0)
	placas.cala_com_balao = false
	await _esperar(0.6)
	_fixar(dele, posto_de_dele)
	_fixar(atras, onde_estava_atras)
	atras.process_mode = processo_de_atras
	if seta != null:
		seta.limpar()


## Onde o dono do E fica, a dois passos à frente do jogador: o primeiro ponto (de frente, ou um pouco
## de lado) de onde a câmera vê a cabeça dele. Bem em frente fica o poço da praça, entre a câmera e a
## cabeça, e a placa de quem a câmera não vê não acende (#184) — com a placa do dono à vista (#188),
## o portão precisa de um dono à vista.
func _a_dois_passos(aqui: Vector3, dele: Node3D) -> Vector3:
	var frente := Vector3(0.0, 0.0, 1.0)
	var direita := frente.cross(Vector3.UP)
	var excluir: Array[RID] = [jogador.get_rid()]
	for morador in placas._placas.keys():
		if is_instance_valid(morador) and morador is CollisionObject3D:
			excluir.append((morador as CollisionObject3D).get_rid())
	for lado in [0.0, 1.0, -1.0, 1.6, -1.6]:
		var onde: Vector3 = vale.world.ground_position(aqui + frente * 2.2 + direita * float(lado), 0.1)
		if placas._raio_livre(camera, onde + Vector3.UP * float(dele.get("altura")) * 0.9, excluir):
			return onde
	return vale.world.ground_position(aqui + frente * 2.2, 0.1)


## 5b. O "?" sobre a cabeça de quem recebe o E nunca fica sob a dica nem sob o balão (#216).
func _o_marcador_por_cima(aqui: Vector3) -> void:
	var teclas = vale.get("tecla_dos_moradores")
	var dele: Node3D = roda[2]
	var posto_de_dele: Vector3 = pontos[2]
	var a_dois_passos: Vector3 = _a_dois_passos(aqui, dele)
	_fixar(dele, a_dois_passos)
	var dono: bool = await relogio.ate(func() -> bool: return teclas.perto() == dele and teclas._dica.visible, 6.0)
	_conferir(dono, "marcador: a dois passos do %s a dica do E não acendeu" % dele.name)
	if not dono:
		return
	await _esperar(1.5)
	var sem_marcador: Rect2 = teclas._dica.get_global_rect()
	# Congela o "?" como se a missão mandasse falar com ele (a pergunta às filas é a cada 0,4 s).
	dele.set("_marcador_em", 1.0e9)
	dele.set("_marcador_texto", "?")
	dele._marcador.text = "?"
	dele._marcador.visible = true
	await _esperar(1.5)
	var marcador: Rect2 = dele.retangulo_do_marcador()
	_conferir(marcador.size != Vector2.ZERO, "marcador: o retângulo do \"?\" sobre %s está vazio com ele à vista" % dele.name)
	_conferir(marcador.size != Vector2.ZERO and marcador.intersects(sem_marcador),
		"marcador: o portão não montou a cena: a dica sem a regra (%s) nem cairia sobre o \"?\" (%s)" % [str(sem_marcador), str(marcador)])
	var dica: Rect2 = teclas._dica.get_global_rect()
	_conferir(not dica.intersects(marcador),
		"marcador: a dica do E (%s) ficou sobre o \"?\" de missão (%s)" % [str(dica), str(marcador)])
	# O balão do mesmo morador também sai da frente do marcador.
	dele.mostrar_balao(FALA_CURTA, 12.0)
	var falou: bool = await relogio.ate(func() -> bool: return dele.balao.visible and dele.balao.retangulo().size != Vector2.ZERO, 3.0)
	_conferir(falou, "marcador: %s não abriu o balão" % dele.name)
	await _esperar(1.4)
	if falou:
		var do_balao: Rect2 = dele.balao.retangulo()
		var marcador_agora: Rect2 = dele.retangulo_do_marcador()
		_conferir(marcador_agora.size != Vector2.ZERO and not do_balao.intersects(marcador_agora),
			"marcador: o balão (%s) ficou sobre o \"?\" de missão (%s)" % [str(do_balao), str(marcador_agora)])
	print("  marcador: a dica do E e o balão ficam fora do \"?\" de missão")
	dele.mostrar_balao("", 0.0)
	_calar_o_marcador(dele)
	await _esperar(0.6)
	_fixar(dele, posto_de_dele)


# --- 6. O PESO NA CÂMERA ------------------------------------------------------------------------

func _o_peso_das_placas() -> void:
	await relogio.ate(func() -> bool: return _placas_ligadas() >= placas.MAXIMO_DE_PLACAS, 4.0)
	await _esperar(1.2)
	var amostras: Array = await _varrer(16.0, 0.5, 1.6, func() -> Dictionary:
		var saida := {}
		for morador in placas._placas.keys():
			var placa: Control = placas._placas[morador]
			# Só a placa que já acendeu por inteiro (a vaga cheia: `_alfa` 1). O `modulate.a` leva também o esmaecer
			# da distância (de 6 a 10 m), e quando as vagas caem nos moradores de 7 a 9 m (os de perto atrás de uma
			# casa ou sob a coluna da dica) nenhuma placa passava de 0,99 e a varredura não media nada.
			if placa.visible and float(placas._alfa.get(morador, 0.0)) >= 1.0:
				# O alvo é o mesmo da placa: a altura real do modelo (o chapéu, o cabelo, #184) e o quanto
				# ela subiu para liberar um rosto.
				var topo: Vector3 = morador.global_position + Vector3(0, placas._altura_real(morador) + placas.ACIMA_DA_CABECA, 0)
				var sobe := Vector2(0.0, float(placas._subida.get(morador, 0.0)))
				saida[morador] = [placa.position, camera.unproject_position(topo) - sobe - Vector2(placa.size.x * 0.5, placa.size.y)]
		return saida)
	var pico := _picos(amostras)
	print("  placas: pico de %.0f px/s na tela contra %.0f px/s da cabeça (%d quadros)" % [pico[0], pico[1], amostras.size()])
	_conferir(pico[1] > 300.0, "a varredura da câmera só moveu as cabeças a %.0f px/s: não exercita o peso" % pico[1])
	_conferir(pico[0] <= pico[1] * 0.75, "as placas andaram a %.0f px/s, quase o %.0f px/s da cabeça: sem peso" % [pico[0], pico[1]])
	_assentou(amostras, 0.5, "a placa", 4.0)
	_conferir(_placas_ligadas() <= placas.MAXIMO_DE_PLACAS, "na varredura houve %d placas ligadas" % _placas_ligadas())


func _o_peso_da_dica() -> void:
	# Uma dica de prova, num ponto fixo do mundo, com as placas de lado para nenhuma subir a dica.
	placas.permitir(false)
	var DicaTecla = load("res://scripts/prototipo_3d/dica_tecla.gd")
	var dica = DicaTecla.criar(vale.hud.map_layer(), "E", "Prova")
	var frente := Vector3(0.0, 0.0, 1.0)
	var ponto: Vector3 = jogador.global_position + frente * 6.0 + Vector3.UP * 2.2
	DicaTecla.mostrar_em(dica, camera, ponto)
	await _esperar(0.5)
	var amostras: Array = await _varrer(16.0, 0.5, 1.6, func() -> Dictionary:
		DicaTecla.mostrar_em(dica, camera, ponto)
		# A dica nasce na escala do componente `interacao` (80%, #188): o ponto de chegada é o da caixa escalada.
		return {"dica": [dica.position, camera.unproject_position(ponto) - Vector2(dica.size.x * 0.5, dica.size.y) * dica.scale]})
	var pico := _picos(amostras)
	print("  dica do E: pico de %.0f px/s na tela contra %.0f px/s do ponto" % [pico[0], pico[1]])
	_conferir(pico[1] > 300.0, "a varredura da câmera só moveu o ponto da dica a %.0f px/s" % pico[1])
	var serie_dica := ""
	if pico[0] > pico[1] * 0.75:
		for amostra in amostras:
			var par: Array = amostra["dados"]["dica"]
			serie_dica += " %.3f:%.1f/%.1f" % [amostra["dt"], (par[0] as Vector2).x, (par[1] as Vector2).x]
	_conferir(pico[0] <= pico[1] * 0.75, "a dica andou a %.0f px/s, quase o %.0f px/s do ponto: sem peso (dt:real/cru)%s" % [pico[0], pico[1], serie_dica.left(1800)])
	_assentou(amostras, 0.5, "a dica do E", 4.0)
	# O TREMOR DE UM PIXEL da câmera, com a dica assentada, não a move.
	var menor := Vector2(1e9, 1e9)
	var maior := Vector2(-1e9, -1e9)
	var cru_menor := 1e9
	var cru_maior := -1e9
	var yaw0: float = jogador.get("_yaw")
	for i in 90:
		var tremor := 0.003 if i % 2 == 0 else -0.003
		jogador.set("_yaw", yaw0 + tremor)
		jogador.call("_apply_camera")
		DicaTecla.mostrar_em(dica, camera, ponto)
		await process_frame
		if i >= 30:
			menor = menor.min(dica.position)
			maior = maior.max(dica.position)
			var cru := camera.unproject_position(ponto).x
			cru_menor = minf(cru_menor, cru)
			cru_maior = maxf(cru_maior, cru)
	jogador.set("_yaw", yaw0)
	jogador.call("_apply_camera")
	var andou := maxf(maior.x - menor.x, maior.y - menor.y)
	print("  dica do E: tremor de %.1f px na cabeça moveu a dica %.1f px" % [cru_maior - cru_menor, andou])
	_conferir(cru_maior - cru_menor >= 1.2, "o tremor da câmera só mexeu o ponto %.2f px: não exercita a zona morta" % (cru_maior - cru_menor))
	_conferir(andou <= 1.01, "o tremor de um pixel da câmera moveu a dica %.1f px" % andou)
	dica.queue_free()
	placas.permitir(true)


func _o_peso_do_chevron() -> void:
	# O chevron da missão, com o alvo à vista e longe (flutua sobre ele): acende em vez de piscar,
	# e desliza com peso atrás do ponto na varredura da câmera.
	var seta = vale.get_node_or_null("SetaMissao")
	_conferir(seta != null and seta.get("_chevron") != null, "o vale não tem a seta da missão com o chevron")
	if seta == null or seta.get("_chevron") == null:
		return
	var frente := Vector3(0.0, 0.0, 1.0)
	var alvo: Vector3 = jogador.global_position + frente * 40.0 + Vector3.UP * 0.5
	var chevron: Control = seta.get("_chevron")
	seta.definir_alvo(alvo, "")
	# Um quadro: o `_process` da seta já correu uma vez (o sinal do quadro vem antes dos `_process`, e o desta
	# chamada ainda correu depois dela), e na máquina lenta dois quadros já a acendem de todo.
	await process_frame
	_conferir(chevron.visible and chevron.modulate.a < 0.99,
		"o chevron da missão acendeu de uma vez (visível %s, opacidade %.2f depois de um quadro): devia acender aos poucos" % [str(chevron.visible), chevron.modulate.a])
	await _esperar(0.8)
	_conferir(chevron.visible and chevron.modulate.a > 0.99, "o chevron da missão não acendeu de todo (visível %s, opacidade %.2f)" % [str(chevron.visible), chevron.modulate.a])
	var amostras: Array = await _varrer(16.0, 0.5, 1.6, func() -> Dictionary:
		var ponto: Vector3 = alvo + Vector3.UP * 1.2
		return {"chevron": [chevron.position + chevron.pivot_offset, camera.unproject_position(ponto) - Vector2(0.0, 46.0)]})
	var pico := _picos(amostras)
	print("  chevron: pico de %.0f px/s na tela contra %.0f px/s do ponto" % [pico[0], pico[1]])
	_conferir(pico[1] > 300.0, "a varredura da câmera só moveu o ponto do chevron a %.0f px/s" % pico[1])
	_conferir(pico[0] <= pico[1] * 0.75, "o chevron andou a %.0f px/s, quase o %.0f px/s do ponto: sem peso" % [pico[0], pico[1]])
	_assentou(amostras, 0.5, "o chevron", 4.0)
	seta.limpar()


func _o_peso_da_vida_da_arvore() -> void:
	# A vida da árvore que se corta (arvores_info.gd), na tela sobre o tronco: desliza com peso. O golpe de
	# verdade pede o machado e o braço; aqui se põe a árvore em golpe à mão e se chama a bolha a cada quadro.
	var arvores = vale.get_node_or_null("ArvoresInfo")
	_conferir(arvores != null and arvores.get("_balao_vida") != null, "o vale não tem as árvores com a bolha de vida")
	if arvores == null or arvores.get("_balao_vida") == null:
		return
	var cortaveis: Array = arvores.get("_cortaveis")
	var escolhida := -1
	var menor := 1e9
	var tela: Vector2 = root.get_visible_rect().size
	for i in cortaveis.size():
		if bool(cortaveis[i]["cortado"]):
			continue
		var topo: Vector3 = (cortaveis[i]["pos"] as Vector3) + Vector3(0.0, 2.45, 0.0)
		if camera.is_position_behind(topo):
			continue
		var longe: float = camera.global_position.distance_to(topo)
		if longe < 10.0 or longe > 40.0:
			continue
		var na_tela := camera.unproject_position(topo)
		var do_centro := absf(na_tela.x - tela.x * 0.5) + absf(na_tela.y - tela.y * 0.5)
		if do_centro < menor and absf(na_tela.x - tela.x * 0.5) < tela.x * 0.2 and absf(na_tela.y - tela.y * 0.5) < tela.y * 0.15:
			menor = do_centro
			escolhida = i
	_conferir(escolhida >= 0, "não há árvore cortável à frente da câmera, entre 10 e 40 m, para a bolha de vida")
	if escolhida < 0:
		return
	var bolha: Control = arvores.get("_balao_vida")
	var topo_da_arvore: Vector3 = (cortaveis[escolhida]["pos"] as Vector3) + Vector3(0.0, 2.45, 0.0)
	# O nó não pode zerar o golpe no quadro seguinte (ele o pára quando o braço não golpeia).
	arvores.set_process(false)
	arvores.set("_em_golpe", escolhida)
	arvores.call("_atualizar_balao_vida", camera)
	_conferir(bolha.visible, "a bolha de vida não acendeu com a árvore em golpe")
	# ACENDE NO LUGAR: no primeiro quadro está sobre o tronco, e não deslizando de onde ficou.
	var cru_agora := camera.unproject_position(topo_da_arvore) - Vector2(bolha.size.x * 0.5, bolha.size.y)
	_conferir(bolha.position.distance_to(cru_agora) <= 1.5, "a bolha de vida acendeu a %.0f px do tronco, em vez de no lugar" % bolha.position.distance_to(cru_agora))
	await _esperar(0.5)
	var amostras: Array = await _varrer(16.0, 0.5, 1.6, func() -> Dictionary:
		arvores.call("_atualizar_balao_vida", camera)
		return {"vida": [bolha.position, camera.unproject_position(topo_da_arvore) - Vector2(bolha.size.x * 0.5, bolha.size.y)]})
	var pico := _picos(amostras)
	print("  vida da árvore: pico de %.0f px/s na tela contra %.0f px/s do tronco" % [pico[0], pico[1]])
	_conferir(pico[1] > 300.0, "a varredura da câmera só moveu o tronco a %.0f px/s" % pico[1])
	_conferir(pico[0] <= pico[1] * 0.75, "a bolha de vida andou a %.0f px/s, quase o %.0f px/s do tronco: sem peso" % [pico[0], pico[1]])
	_assentou(amostras, 0.5, "a bolha de vida", 4.0)
	arvores.set("_em_golpe", -1)
	arvores.call("_atualizar_balao_vida", camera)
	arvores.set_process(true)


func _o_peso_do_balao() -> void:
	var quem: Node3D = roda[7]
	_fixar(quem, pontos[7])
	await _esperar(0.5)
	quem.mostrar_balao(FALA_LONGA, 40.0)
	var abriu: bool = await relogio.ate(func() -> bool: return quem.balao.visible and quem.balao.retangulo().size != Vector2.ZERO, 3.0)
	_conferir(abriu, "%s não abriu o balão" % quem.name)
	if not abriu:
		return
	await _esperar(1.5)
	var balao = quem.balao
	if falsificar:
		balao.permanencia = 0.0
	var antes := [int(balao.trocas)]
	var troca_em: Array[float] = []
	# A CÂMERA BALANÇA de um lado a outro, uma vez por segundo, cinco vezes: o balão não pula.
	var yaw0: float = jogador.get("_yaw")
	var t0: float = relogio.agora()
	var amostras: Array = []
	while relogio.agora() - t0 < 5.0:
		var t: float = relogio.agora() - t0
		jogador.set("_yaw", yaw0 + deg_to_rad(14.0) * sin(TAU * t / 1.0))
		jogador.call("_apply_camera")
		await _quadro()
		var agora: float = relogio.agora()
		var trocou: bool = int(balao.trocas) != int(antes[0])
		if trocou:
			troca_em.append(agora)
			antes[0] = int(balao.trocas)
		amostras.append({"t": agora - t0, "dados": {"balao": [balao._painel.position + Vector2(0.0, balao._painel.size.y), balao._cabeca_tela]}})
	jogador.set("_yaw", yaw0)
	jogador.call("_apply_camera")
	# A permanência: nenhuma troca a menos de `permanencia` da anterior (a primeira, a de
	# antes da varredura, conta como o instante em que ela começou).
	var mais_curta := 1e9
	for i in range(1, troca_em.size()):
		mais_curta = minf(mais_curta, troca_em[i] - troca_em[i - 1])
	_conferir(mais_curta >= balao.permanencia - 0.15, "o balão trocou de canto %.2f s depois da troca anterior, e a permanência é de %.2f s" % [mais_curta, balao.permanencia])
	# O peso: a caixa anda menos depressa que a cabeça, fora do meio segundo de cada troca de canto
	# (a troca muda o alvo da caixa de uma vez, e o deslizar até o canto novo não é o que se mede aqui).
	var sem_trocas: Array = []
	for amostra in amostras:
		var perto_de_troca := false
		for quando in troca_em:
			if absf(float(amostra["t"]) - (quando - t0)) < 0.5:
				perto_de_troca = true
		if not perto_de_troca:
			sem_trocas.append(amostra)
	var picos := _picos(sem_trocas)
	var caixa_pico: float = picos[0]
	var cabeca_pico: float = picos[1]
	print("  balão: pico de %.0f px/s na tela contra %.0f px/s da cabeça, %d troca(s) de canto em 5 s (permanência %.2f s)" % [caixa_pico, cabeca_pico, troca_em.size(), balao.permanencia])
	_conferir(cabeca_pico > 300.0, "o balanço da câmera só moveu a cabeça a %.0f px/s: não exercita o peso (%s: balão visível %s, painel %s, %d quadros)" % [cabeca_pico, quem.name, str(balao.visible), str(balao._painel.visible), amostras.size()])
	var serie_balao := ""
	if caixa_pico > cabeca_pico * 0.75:
		var maior_salto := 0.0
		var onde_foi := 0
		for i in range(1, sem_trocas.size()):
			var salto: float = (sem_trocas[i]["dados"]["balao"][0] as Vector2).distance_to(sem_trocas[i - 1]["dados"]["balao"][0])
			if salto > maior_salto:
				maior_salto = salto
				onde_foi = i
		for i in range(maxi(onde_foi - 6, 0), mini(onde_foi + 4, sem_trocas.size())):
			var par: Array = sem_trocas[i]["dados"]["balao"]
			serie_balao += " [t%.3f caixa%s cabeça%s]" % [sem_trocas[i]["t"], str(par[0]), str(par[1])]
	_conferir(caixa_pico <= cabeca_pico * 0.75, "o balão andou a %.0f px/s, quase o %.0f px/s da cabeça: sem peso%s" % [caixa_pico, cabeca_pico, serie_balao.left(1600)])
	# E assenta depois de parar.
	await _esperar(2.0)
	var p1: Vector2 = balao._painel.position
	await _quadro()
	await _quadro()
	var p2: Vector2 = balao._painel.position
	_conferir(p1.distance_to(p2) <= 1.01, "dois segundos depois da câmera parar o balão ainda anda (%.1f px por quadro)" % p1.distance_to(p2))
	quem.mostrar_balao("", 0.0)
	await _esperar(0.6)


# --- 7. A FALA LONGA EM PÁGINAS -----------------------------------------------------------------

func _as_paginas() -> void:
	var quem: Node3D = roda[8]
	_fixar(quem, pontos[8])
	await relogio.ate(func() -> bool: return fila.livre(), 30.0)
	quem.mostrar_balao(FALA_LONGA, 12.0)
	var abriu: bool = await relogio.ate(func() -> bool: return quem.balao.visible, 3.0)
	_conferir(abriu, "%s não abriu o balão da fala longa" % quem.name)
	if not abriu:
		return
	var balao = quem.balao
	var paginas: int = balao._paginas
	var linhas: int = balao._linhas
	_conferir(paginas >= 3, "a fala longa (%d linhas) virou %d página(s): devia passar de duas por vez" % [linhas, paginas])
	_conferir(str(balao._texto.text) == FALA_LONGA, "o rótulo do balão não guarda o texto inteiro da fala")
	var vistas: Array[int] = []
	var altura_maxima := 0.0
	var linhas_maximas := 0
	var descasou := 0
	var limite_s := Time.get_ticks_msec() + 40000
	while balao.visible and Time.get_ticks_msec() < limite_s:
		await _quadro()
		if not balao.visible:
			break
		var pagina: int = balao._pagina
		if vistas.is_empty() or vistas[vistas.size() - 1] != pagina:
			vistas.append(pagina)
		altura_maxima = maxf(altura_maxima, balao._painel.size.y)
		linhas_maximas = maxi(linhas_maximas, int(balao._texto.max_lines_visible))
		var no_ar: Dictionary = fila.atual()
		if not no_ar.is_empty() and no_ar.get("falante") == quem:
			var total := float(no_ar.get("no_ar", 0.0)) + maxf(float(no_ar.get("resta", 0.0)), 0.0)
			var esperada := mini(floori(float(no_ar.get("no_ar", 0.0)) / total * linhas / 2.0), paginas - 1) if total > 0.0 else 0
			if absi(esperada - pagina) > 1:
				descasou += 1
	var na_ordem := true
	for i in range(1, vistas.size()):
		if vistas[i] != vistas[i - 1] + 1:
			na_ordem = false
	_conferir(not vistas.is_empty() and vistas[0] == 0 and na_ordem, "as páginas passaram fora de ordem: %s" % str(vistas))
	_conferir(vistas.size() == paginas, "das %d páginas, só apareceram %d (%s) antes da fala acabar" % [paginas, vistas.size(), str(vistas)])
	_conferir(descasou == 0, "em %d quadro(s) a página estava a mais de uma do que o tempo da fila pedia" % descasou)
	var da_linha: float = balao._texto.get_line_height()
	_conferir(linhas_maximas <= 3 and linhas_maximas >= 2, "o balão mostrou até %d linhas de uma vez: são duas por página (três na última)" % linhas_maximas)
	_conferir(altura_maxima <= da_linha * 3.0 + 90.0, "o balão da fala longa chegou a %.0f px de altura (%d linhas de %.0f px): não está paginado" % [altura_maxima, linhas, da_linha])
	print("  páginas: %d linhas em %d páginas (%s), balão de até %.0f px de altura" % [linhas, paginas, str(vistas), altura_maxima])


# --- apoios ---------------------------------------------------------------------------------

## Gira a câmera `graus` graus e a traz de volta, em `duracao` s de jogo (um cosseno inteiro, sem
## degrau no começo nem no fim), e a deixa parada por `depois` s; a cada quadro guarda
## {"t", "dt", "dados": o que `amostrar` devolve}.
func _varrer(graus: float, duracao: float, depois: float, amostrar: Callable) -> Array:
	var amostras: Array = []
	var yaw0: float = jogador.get("_yaw")
	var t0: float = relogio.agora()
	var anterior := t0
	while relogio.agora() - t0 < duracao + depois:
		var f := clampf((relogio.agora() - t0) / duracao, 0.0, 1.0)
		jogador.set("_yaw", yaw0 + deg_to_rad(graus) * (1.0 - cos(TAU * f)) * 0.5)
		jogador.call("_apply_camera")
		await _quadro()
		var agora: float = relogio.agora()
		amostras.append({"t": agora - t0, "dt": agora - anterior, "dados": amostrar.call()})
		anterior = agora
	jogador.set("_yaw", yaw0)
	jogador.call("_apply_camera")
	return amostras


## O pico de velocidade (px/s) do que se vê [0] e do alvo cru [1], medido em JANELAS de `JANELA` s
## de jogo e não quadro a quadro: o quadro da máquina cheia (ou o de 100 por segundo) mede o
## arredondamento e o relógio, e não a mola. Cada amostra: {chave: [onde está, onde o alvo cru o poria]}.
## Janela com buraco (o popup apagou no meio) não conta.
func _picos(amostras: Array) -> Array:
	var series := {}
	for amostra in amostras:
		for chave in amostra["dados"].keys():
			if not series.has(chave):
				series[chave] = []
			var par: Array = amostra["dados"][chave]
			series[chave].append([float(amostra["t"]), par[0], par[1]])
	var visto := 0.0
	var cru := 0.0
	for chave in series.keys():
		var serie: Array = series[chave]
		for i in serie.size():
			var j := i - 1
			while j > 0 and float(serie[i][0]) - float(serie[j][0]) < JANELA:
				j -= 1
			if j < 0:
				continue
			var largura: float = float(serie[i][0]) - float(serie[j][0])
			if largura < JANELA or largura > JANELA * 2.0:
				continue
			visto = maxf(visto, (serie[i][1] as Vector2).distance_to(serie[j][1]) / largura)
			cru = maxf(cru, (serie[i][2] as Vector2).distance_to(serie[j][2]) / largura)
	return [visto, cru]


## Depois da varredura (`duracao` s) o popup assentou no alvo cru — a menos de `ate` px, com a
## zona morta e o arredondamento — e, no caminho, a distância a ele nunca voltou a crescer
## mais que o arredondamento (nada passou do ponto, nada balançou). Uma série por popup.
func _assentou(amostras: Array, duracao: float, quem: String, ate: float) -> void:
	var series := {}
	for amostra in amostras:
		# Só depois da câmera parar de vez: na máquina lenta o quadro de depois da varredura ainda é o da
		# câmera chegando (um quadro dura mais que 80 ms), e o alvo que ainda anda não é balanço da mola.
		if amostra["t"] < duracao + 0.3:
			continue
		for chave in amostra["dados"].keys():
			var a: Array = amostra["dados"][chave]
			if not series.has(chave):
				series[chave] = []
			series[chave].append((a[0] as Vector2).distance_to(a[1]))
	_conferir(not series.is_empty(), "%s: nenhum quadro de depois da varredura para medir o assento" % quem)
	for chave in series.keys():
		var distancias: Array = series[chave]
		if distancias.size() < 10:
			continue
		var fim_da_serie: float = distancias[distancias.size() - 1]
		var cresceu := 0.0
		for i in range(distancias.size() - 1):
			cresceu = maxf(cresceu, float(distancias[i + 1]) - float(distancias[i]))
		_conferir(fim_da_serie <= ate, "%s ainda estava a %.1f px do ponto no fim, 1,6 s depois da câmera parar" % [quem, fim_da_serie])
		var serie_do_assento := ""
		if cresceu > 2.0:
			for amostra in amostras:
				if amostra["t"] >= duracao and amostra["dados"].has(chave):
					var par: Array = amostra["dados"][chave]
					serie_do_assento += " [%.2f r%s c%s d%.1f]" % [amostra["t"], str(par[0]), str(par[1]), (par[0] as Vector2).distance_to(par[1])]
		_conferir(cresceu <= 2.0, "%s se afastou do ponto %.1f px num quadro depois de a câmera parar: balançou%s" % [quem, cresceu, serie_do_assento.left(1500)])


## Quantos balões de morador estão no ar.
func _baloes_no_ar() -> int:
	var no_ar := 0
	for morador in vale.moradores:
		if is_instance_valid(morador) and morador.balao != null and morador.balao.visible:
			no_ar += 1
	var pedro = vale.get("pedro")
	if pedro != null and pedro.balao != null and pedro.balao.visible:
		no_ar += 1
	return no_ar


## Os nomes de quem tem placa ligada agora, em ordem: para ver se a vaga troca de mão.
func _quem_tem_placa() -> String:
	var nomes: Array[String] = []
	for morador in placas._placas.keys():
		if (placas._placas[morador] as Control).visible:
			nomes.append(str(morador.name))
	nomes.sort()
	return ",".join(nomes)


func _placas_ligadas() -> int:
	var ligadas := 0
	for placa in placas._placas.values():
		if placa.visible:
			ligadas += 1
	return ligadas


## Pega os moradores da roda e os põe nos postos: o jogador em `aqui`, de frente para +Z.
func _montar_a_roda(aqui: Vector3) -> void:
	roda.clear()
	pontos.clear()
	var direita := Vector3(0.0, 0.0, 1.0).cross(Vector3.UP)
	var livres: Array = []
	for morador in vale.moradores:
		# Só quem está no vale e anda: o mestre Quirino, fora do dia do saveiro, está parado e escondido.
		if is_instance_valid(morador) and morador.can_process() and morador.is_visible_in_tree():
			livres.append(morador)
	for i in mini(RODA.size(), livres.size()):
		var onde: Vector3 = vale.world.ground_position(aqui + Vector3(0.0, 0.0, 1.0) * float(RODA[i][0]) + direita * float(RODA[i][1]), 0.1)
		var morador = livres[i]
		# Ninguém cumprimenta no meio da medida: o balão de quem passa muda o teto (duas placas) e some com a placa dele.
		morador.set("_ultima_saudacao_ms", Time.get_ticks_msec())
		morador.set("intervalo_saudacao_ms", 100000000)
		# Sem o "!"/"?" de missão (#216): metade da roda tem fila por abrir, e o marcador é obstáculo de
		# placa e dica; as medidas daqui são das regras entre placas, dica e balão. O marcador tem a
		# medida dele (5b), com o "?" posto à mão.
		_calar_o_marcador(morador)
		morador.ir_ate(onde, 1.0)
		morador.global_position = onde
		roda.append(morador)
		pontos.append(onde)
	# O vale tem mais moradores que postos na roda, e desde que os catorze mudos ganharam falas quem sobra solto
	# cumprimenta quem passa e anda para o posto do entardecer: o balão dele e a placa que ele leva consigo trocavam
	# a terceira placa de dono no meio da medida. Quem sobra vai para longe, calado e parado.
	for j in range(RODA.size(), livres.size()):
		var sobra = livres[j]
		sobra.set("_ultima_saudacao_ms", Time.get_ticks_msec())
		sobra.set("intervalo_saudacao_ms", 100000000)
		sobra.global_position = vale.world.ground_position(aqui + Vector3(0.0, 0.0, -80.0 - 4.0 * float(j)), 0.1)
		sobra.process_mode = Node.PROCESS_MODE_DISABLED


## O marcador de missão parado e apagado: a pergunta às filas (a cada 0,4 s) fica para depois do portão.
func _calar_o_marcador(morador: Node3D) -> void:
	morador.set("_marcador_em", 1.0e9)
	morador.set("_marcador_texto", "")


func _fixar(morador: Node3D, onde: Vector3) -> void:
	var indice := roda.find(morador)
	if indice >= 0:
		pontos[indice] = onde
	morador.ir_ate(onde, 1.0)
	morador.global_position = onde


## Onde pôr os pés de `quem` para a cabeça dele aparecer em `onde`, na tela: 16 m adiante pela câmera. Pelo relevo
## a conta não fecha (o raio da câmera passa a 40 m do jogador antes de tocar o chão de uma encosta que desce), e
## o que se mede aqui é a tela: ele fica no ar, quieto (`_quadro` zera a velocidade dele).
func _pe_pela_tela(quem: Node3D, onde: Vector2) -> Vector3:
	var cabeca := camera.project_ray_origin(onde) + camera.project_ray_normal(onde) * 16.0
	return cabeca - Vector3(0.0, float(quem.get("altura")) + 0.1, 0.0)


## Um quadro, com a roda no lugar: os moradores não derivam enquanto se mede.
func _quadro() -> void:
	for i in roda.size():
		if is_instance_valid(roda[i]):
			roda[i].global_position = pontos[i]
			roda[i].velocity = Vector3.ZERO
	await process_frame


## Espera `segundos` de jogo com a roda no lugar.
func _esperar(segundos: float) -> void:
	var ate: float = relogio.agora() + segundos
	var guarda := Time.get_ticks_msec() + int(maxf(segundos * 12.0, 60.0) * 1000.0)
	while relogio.agora() < ate and Time.get_ticks_msec() < guarda:
		await _quadro()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("POPUPS_NA_TELA_OK: a mola não pula, não passa do alvo, ignora o tremor e segura o popup perto numa virada rápida; o dono do E e o alvo da missão levam placa antes de qualquer distância; com quinze moradores à frente da câmera há no máximo três placas ligadas (duas com um balão no ar, quatro popups de personagem); a dica do E sobe acima da placa do dono dela, a placa de quem está atrás dele cede à coluna da dica, o balão deixa a dica embaixo e nenhuma placa fica sob o balão; numa varredura rápida a placa, a dica, o chevron da missão, a vida da árvore e o balão andam menos que o ponto a que estão presos e assentam sem balançar; o balão não troca de canto antes da permanência e o canto novo é um deslizar; e a fala longa passa em páginas de duas linhas, no ritmo da fila")
	else:
		print("popups_na_tela: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _quadros(n: int) -> void:
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
