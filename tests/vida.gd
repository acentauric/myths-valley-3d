extends "res://tests/suite/caso.gd"
## Confere que a VIDA do jogo 2D chegou ao vale inteira: no HUD, e com a queda
## que leva para casa (#10).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste vida
##
## O `Vida` não é código escrito para o 3D: é o arquivo do 2D, em
## `scripts/compartilhado/`, conferido byte a byte pelo `testar_compartilhado`
## do outro projeto, e a regra dele já tem portão lá (`testar_vida`). Este
## teste não repete aquele. Ele pergunta o que só o vale pode responder:
##
##   1. O AUTOLOAD SUBIU, com o teto do 2D, e é outra conta que o fôlego.
##   2. A BARRA ACOMPANHA O NÚMERO: pancada desce a barra do HUD, e a peçonha
##      troca a cor dela. HUD que mostra um número velho mente pior que HUD
##      nenhum.
##   3. CAIR LEVA PARA CASA — ao pé da cama, no quarto da Casa de taipa, ou
##      na porta dela sem o cômodo —, vira UM dia, acorda às 6h com a vida
##      cheia e o fôlego do desmaio.
##   4. O CALENDÁRIO FICA PRESO AO `Dia` depois da queda. O `Relogio.dormir()`
##      solta o `pausado` dele; se o `Dia` não o prender de novo, o calendário
##      anda sozinho, que é o defeito de `tests/calendario.gd`.
##   5. DUAS QUEDAS NA MESMA NOITE SÃO UMA NOITE: o aviso repetido enquanto a
##      tela ainda está escura não vira o dia duas vezes.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("VIDA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	# --- 1. O AUTOLOAD SUBIU ---------------------------------------------------
	var vida := root.get_node_or_null("/root/Vida")
	var energia := root.get_node_or_null("/root/Energia")
	var progressao := root.get_node_or_null("/root/Progressao")
	var relogio := root.get_node_or_null("/root/Relogio")
	var dia := root.get_node_or_null("/root/Dia")
	_conferir(vida != null, "o autoload Vida não subiu")
	_conferir(energia != null and progressao != null and relogio != null and dia != null,
		"falta autoload de que a queda depende (Energia, Progressao, Relogio, Dia)")
	if falhas > 0:
		_fechar()
		return
	_conferir(progressao.VIDA_MAXIMA_INICIAL == 30.0,
		"o teto de vida não é o do 2D: %s" % str(progressao.VIDA_MAXIMA_INICIAL))
	_conferir(vida.atual == vida.maximo(), "o vale não começa com a vida cheia: %s" % str(vida.atual))

	# --- o vale de pé ----------------------------------------------------------
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(6)
	await _mundo_pronto()
	await _frames(10)
	var vale = current_scene
	var hud = vale.hud
	var player = vale.player
	var world = vale.world
	var queda = vale.get_node_or_null("Queda")
	_conferir(queda != null, "o vale não montou o nó da queda")
	_conferir(hud.barra_vida != null and hud.barra_vida.visible, "o HUD não tem a barra de vida")
	if falhas > 0:
		_fechar()
		return

	# --- 2. A BARRA ACOMPANHA O NÚMERO -----------------------------------------
	var folego_antes: float = energia.atual
	vida.ferir(7.0)
	_conferir(is_equal_approx(hud.barra_vida.value, vida.atual),
		"depois da pancada a barra mostra %s e a vida é %s" % [str(hud.barra_vida.value), str(vida.atual)])
	_conferir(is_equal_approx(hud.barra_vida.max_value, vida.maximo()), "o teto da barra não é o da vida")
	_conferir(is_equal_approx(energia.atual, folego_antes), "a pancada descontou do fôlego")
	var cor_sa: Color = hud._vida_preenchimento.bg_color
	vida.envenenar(30.0, 0.01)
	_conferir(hud._vida_preenchimento.bg_color != cor_sa, "com peçonha, a barra não mudou de cor")
	vida.curar_veneno()
	_conferir(hud._vida_preenchimento.bg_color == cor_sa, "sem peçonha, a barra não voltou à cor da vida")

	# --- 3. CAIR LEVA PARA CASA ------------------------------------------------
	var casa: Vector3 = queda.ponto_de_casa()
	_conferir(casa.is_finite(), "o vale não tem a Casa de taipa: a queda não tem para onde levar")
	_conferir(casa.is_finite() and world.is_on_land(casa), "o lugar de acordar em casa não é terra firme: %s" % str(casa))
	var longe: Vector3 = player.global_position
	print("VIDA: jogador em %s, casa em %s (%.0f u)" % [str(longe), str(casa), longe.distance_to(casa)])
	dia.definir_hora(15.0)
	# COM O RELÓGIO PAUSADO pelo botão do HUD, que é quando a ordem da queda
	# importa: andando, o `Dia` prende o calendário de novo no quadro seguinte e
	# esconderia o defeito; parado, ninguém prende, e o calendário anda sozinho.
	dia.pausado = true
	var dia_antes: int = relogio.dia_absoluto()
	player.definir_vigor(5.0)
	# Cair no mar também precisa devolver a pose de terra antes de mostrar a fala.
	player.set("_nadando", true)
	if player.animator != null:
		player.animator.set_swimming(true)
	var acordou := [false]
	queda.acordou.connect(func(): acordou[0] = true)

	vida.ferir(9999.0)
	# --- 5. na mesma noite, o aviso de novo ---
	await _frames(3)
	vida.caiu.emit()
	# Teto pelo relógio de parede: escurecer, o cartão do amanhecer (#21) e
	# clarear são tempo de tela, e quadro sem janela passa mais rápido que isso.
	var ate := Time.get_ticks_msec() + 15000
	while not acordou[0] and Time.get_ticks_msec() < ate:
		await process_frame
	_conferir(acordou[0], "a queda não terminou: o jogador ficou no escuro")
	_conferir(player.global_position.distance_to(casa) < 1.5,
		"quem caiu acordou a %.1f u de casa" % player.global_position.distance_to(casa))
	_conferir(vida.atual == vida.maximo(), "acordou sem a vida cheia: %s" % str(vida.atual))
	_conferir(energia.atual >= 5.0 + progressao.recuperacao_ao_desmaiar,
		"o vigor não voltou como no desmaio do 2D: %s" % str(energia.atual))
	_conferir(not player.is_swimming() and player.visual.position.y == 0.0,
		"o jogador acordou ainda na pose de nado")
	_conferir(not paused, "o vale continuou pausado depois do respawn")
	_conferir(not root.get_node("/root/Dialogo").ativo and hud._house_info_panel.visible,
		"a explicação da queda não apareceu no painel com fechar")
	for placa in vale.placas._placas.values():
		_conferir((placa as Control).z_index < hud._house_info_panel.z_index,
			"a plaquinha de NPC pode cobrir a explicação da queda")
	var fechar: Array[Node] = hud._house_info_panel.find_children("*", "Button", true, false)
	_conferir(fechar.size() == 1, "o aviso da queda não tem botão de fechar")
	if fechar.size() == 1:
		(fechar[0] as Button).pressed.emit()
		_conferir(not hud._house_info_panel.visible, "o botão não fechou o aviso da queda")
	_conferir(relogio.dia_absoluto() == dia_antes + 1,
		"a queda virou %d dia(s), e é um" % (relogio.dia_absoluto() - dia_antes))
	# A hora é escrita com a tela preta e o relógio anda enquanto ela clareia
	# (1,2 s, alguns minutos de jogo) — como no 2D. Um quarto de hora de folga.
	var acordar := float(relogio.HORA_DE_ACORDAR)
	_conferir(dia.hora >= acordar and dia.hora < acordar + 0.25,
		"acordou às %s, e a hora de acordar é %d" % [dia.texto_hora(), relogio.HORA_DE_ACORDAR])

	# --- 4. O CALENDÁRIO FICA PRESO AO Dia -------------------------------------
	_conferir(relogio.pausado, "depois da queda o calendário ficou solto: ele anda sozinho, fora do Dia")
	var minutos_antes: float = relogio.minutos
	await _frames(30)
	_conferir(is_equal_approx(relogio.minutos, minutos_antes),
		"com o Dia pausado, o calendário andou sozinho depois da queda: %s → %s minutos" % [str(minutos_antes), str(relogio.minutos)])
	dia.pausado = false

	# O jogo continua: o corpo volta a andar.
	_conferir(player.is_physics_processing(), "depois de acordar, o jogador continuou travado")
	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("VIDA_OK: a barra do HUD acompanha a vida e a peçonha; cair leva para casa, ao pé da cama, vira um dia só, acorda às 6h inteiro e com o fôlego do desmaio, e o calendário continua preso ao Dia")
	else:
		print("vida: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame


## O vale se monta ao longo de vários quadros (world_builder): espera ficar pronto.
func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
