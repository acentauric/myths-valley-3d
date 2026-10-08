extends SceneTree
## A TAREFA CONCLUÍDA SE VÊ E SE OUVE (07/10: "precisamos evidenciar melhor que o jogador
## concluiu uma tarefa da missão... talvez um efeito brilhante no balão de missão").
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/tarefa_concluida.gd
##
## A festa de tela inteira é só do fim da missão (tests/falas_em_fila.gd, conquista_da_missao).
## Cada passo do MEIO fechado ganha o pulso do quadro da missão, o risco "✓ tarefa" e o sinete.
##
##   1. UM PASSO DO MEIO FECHOU: o quadro da missão pulsa (a cor dele sai do branco), o
##      risco "✓" com o resumo do passo cumprido aparece embaixo do quadro, e o sinete
##      `tarefa_concluida` é pedido ao Audio — e o arquivo dele existe.
##   2. O RISCO SE APAGA SOZINHO em poucos segundos, sem parar o jogo.
##   3. O ÚLTIMO PASSO NÃO RISCA: é a festa da missão inteira; nem pulso, nem sinete de tarefa.
##   4. O HUD NÃO PISCA "FALE COM PEDRO" entre um passo e o seguinte: fechado um passo do meio,
##      o objetivo não vira a frase de quem está sem missão.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("TAREFA_CONCLUIDA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(4)
	await _mundo_pronto()
	await _frames(4)
	var vale = current_scene
	var hud = vale.hud
	var audio = root.get_node("/root/Audio")
	_conferir(ResourceLoader.exists("res://assets/audio/efeitos/tarefa_concluida.mp3"), "o sinete tarefa_concluida.mp3 não está na pasta dos efeitos")
	_conferir(str(audio.arquivo_do_efeito("tarefa_concluida")) != "", "o Audio não resolve o efeito tarefa_concluida")

	# --- 1. UM PASSO DO MEIO FECHOU (a fila do Tonho, de cinco passos) ----------------------
	var cadeia = vale._cadeias.get("tonho")
	_conferir(cadeia != null and cadeia.passos.size() >= 3, "não achei a fila do Tonho com três passos ou mais")
	if cadeia == null:
		_fechar()
		return
	# A chegada feita na mão, para a fila poder andar.
	var guia = vale.pedro._cadeia
	guia.iniciado = true
	guia.missao = guia.passos.size()
	guia.espera = 0.0
	guia.despedida_feita = true
	# O PASSO DA REDE (o segundo: levar corda e tábua), e não o primeiro, que é uma visita
	# ao píer — onde a partida nova nasce, e a fila o fecharia sozinha no quadro seguinte.
	cadeia.iniciado = true
	cadeia.missao = 1
	cadeia.espera = 0.0
	# O PASSO ANUNCIADO entra no caderno e vai para o alto da tela: é dele que o HUD não
	# pode cair para a frase de quem está sem missão quando ele fechar.
	cadeia.anunciar()
	await _frames(3)
	var resumo_do_primeiro := str(cadeia.resumo_do_passo(cadeia.passos[1]))
	var objetivo_antes := str(hud.get("_objective"))
	_conferir(resumo_do_primeiro != "" and objetivo_antes.contains(resumo_do_primeiro),
		"anunciado o passo da rede do Tonho, o HUD não mostra a tarefa dele ('%s' não tem '%s')" % [objetivo_antes, resumo_do_primeiro])
	audio.ultimo_efeito = ""
	cadeia.avancar()
	await _frames(3)
	_conferir(cadeia.missao == 2, "a fila do Tonho não avançou do passo da rede (missao %d)" % cadeia.missao)
	var risco := str(hud.tarefa_concluida_a_vista())
	_conferir(risco.begins_with("✓"), "fechado o primeiro passo, o risco da tarefa não apareceu ('%s')" % risco)
	_conferir(resumo_do_primeiro != "" and risco.contains(resumo_do_primeiro), "o risco não diz a tarefa cumprida ('%s' não tem '%s')" % [risco, resumo_do_primeiro])
	var heading: Control = hud.get("_heading")
	_conferir(heading != null and not heading.modulate.is_equal_approx(Color(1, 1, 1, 1)), "o quadro da missão não pulsou (modulate %s)" % str(heading.modulate if heading != null else null))
	_conferir(str(audio.ultimo_efeito) == "tarefa_concluida", "o sinete da tarefa não foi pedido (último efeito: '%s')" % str(audio.ultimo_efeito))
	# 4. O objetivo não virou a frase de quem está sem missão.
	var objetivo_depois := str(hud.get("_objective"))
	_conferir(not objetivo_depois.contains("veio te esperar"), "entre um passo e o seguinte o HUD piscou a frase de quem está sem missão ('%s')" % objetivo_depois)
	print("  objetivo antes: '%s' · depois: '%s'" % [objetivo_antes, objetivo_depois])

	# --- 2. O RISCO SE APAGA SOZINHO --------------------------------------------------------
	var apagou := await _ate(func() -> bool: return str(hud.tarefa_concluida_a_vista()) == "", 6.0)
	_conferir(apagou, "o risco da tarefa não se apagou sozinho")
	_conferir(not paused, "o risco da tarefa parou o jogo")

	# --- 3. O ÚLTIMO PASSO NÃO RISCA ------------------------------------------------------
	var favor = vale._cadeias.get("rendeira_favor")
	_conferir(favor != null and favor.passos.size() == 1, "não achei a fila de um passo da rendeira")
	if favor != null:
		favor.iniciado = true
		favor.missao = 0
		favor.espera = 0.0
		audio.ultimo_efeito = ""
		favor.avancar()
		await _frames(3)
		_conferir(bool(favor.acabou()), "a fila de um passo não acabou ao avançar")
		_conferir(str(hud.tarefa_concluida_a_vista()) == "", "o último passo riscou a tarefa ('%s'): o fim da missão é a festa, não o risco" % str(hud.tarefa_concluida_a_vista()))
		_conferir(str(audio.ultimo_efeito) != "tarefa_concluida", "o último passo pediu o sinete da tarefa")
	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("TAREFA_CONCLUIDA_OK: um passo do meio fechado pulsa o quadro da missão, desce o risco '✓ tarefa' e pede o sinete, que existe; o risco se apaga sozinho sem parar o jogo; o último passo não risca (é a festa); e o HUD não pisca a frase de quem está sem missão entre um passo e o seguinte")
	else:
		print("tarefa_concluida: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicao.call():
			return true
		await process_frame
	return condicao.call()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
