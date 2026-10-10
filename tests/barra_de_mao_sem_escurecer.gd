extends "res://tests/suite/caso.gd"
## #222: a barra de mão não fica escurecida, como desativada, depois de a explicação das barras
## e a caixa de fala passarem por cima dela. Duas mãos mexiam no mesmo `modulate`: o destaque
## (`destacar_barra`) apaga o HUD em cinza, e o foco da narração (`foco_da_narracao.gd`) recolhe o
## componente que a caixa cobre tirando o alfa, guardando o `modulate` INTEIRO e devolvendo-o
## depois, cinza e tudo, um quadro depois de o destaque ter devolvido o branco.
##
## O portão passa pelas horas do dia (manhã, tarde, entardecer, noite) em cada caso: a luz do
## mundo não toca a camada do HUD, e a cor da barra tem de ser a mesma em todas.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, motivo: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: ", motivo)


func _run() -> void:
	await process_frame
	var hud = load("res://scripts/prototipo_3d/prototype_hud.gd").new()
	root.add_child(hud)
	await process_frame
	var dialogo := root.get_node("Dialogo")
	var dia := root.get_node("Dia")
	dialogo.transform = Transform2D.IDENTITY
	var barra: Control = hud._barra
	var hora_de_antes: float = dia.hora

	for hora in [9.0, 15.0, 17.8, 21.5]:
		dia.definir_hora(hora)
		await process_frame
		# A explicação do corpo: o Pedro fala cobrindo a barra de mão e acende a barra da vez.
		dialogo.falar("Pedro", ["Vida", "Vigor"], [], [["vida"], ["vigor"]])
		await process_frame
		hud.destacar_barra("Vida")
		await process_frame
		await process_frame
		_conferir(barra.modulate.a == 0.0, "às %.1f h, a barra sob a caixa de fala deveria ceder, e está com alfa %.2f" % [hora, barra.modulate.a])
		hud.destacar_barra("Folego")
		await process_frame
		_conferir(barra.modulate.a == 0.0, "às %.1f h, trocar a barra acesa fez a barra de mão reaparecer por baixo da caixa" % hora)
		hud.apagar_destaque()
		dialogo.calar()
		await process_frame
		await process_frame
		await process_frame
		_conferir(barra.modulate == Color.WHITE,
			"às %.1f h, depois da explicação a barra de mão ficou escurecida: %s" % [hora, str(barra.modulate)])
		for nome in ["Vida", "Folego", "Stamina"]:
			var outra = hud._root.get_node_or_null(nome)
			if outra is CanvasItem:
				_conferir((outra as CanvasItem).modulate == Color.WHITE, "às %.1f h, a barra %s ficou escurecida" % [hora, nome])

		# O destaque sem caixa nenhuma por cima: apaga a barra de mão e devolve o branco, com o alfa que tinha.
		hud.destacar_barra("Vida")
		_conferir(barra.modulate.r < 0.5 and barra.modulate.a == 1.0, "às %.1f h, o destaque não apagou a barra de mão na cor" % hora)
		hud.apagar_destaque()
		_conferir(barra.modulate == Color.WHITE, "às %.1f h, apagado o destaque, a barra de mão não voltou ao branco" % hora)

	dia.definir_hora(hora_de_antes)
	hud.queue_free()
	await process_frame
	print("Barra de mão sem escurecer: %d falhas" % falhas)
	quit(1 if falhas else 0)
