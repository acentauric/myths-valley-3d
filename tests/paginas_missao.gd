extends SceneTree
## A leitura das páginas do HUD não altera o passo real da missão.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, motivo: String) -> void:
	if not ok:
		print("FALHA: ", motivo)
		falhas += 1


func _run() -> void:
	var hud = load("res://scripts/prototipo_3d/prototype_hud.gd").new()
	root.add_child(hud)
	await process_frame
	var minimapa := Control.new()
	minimapa.name = "Minimapa"
	hud._root.add_child(minimapa)
	var paginas: Array[String] = ["Primeira", "Segunda", "Terceira"]
	hud.set_mission_pages(paginas)
	hud.set_objective("Segunda")
	hud.set_mission_step(2, 3)
	_conferir(hud._objective_label.text == "Segunda" and hud._mission_step.text == "2 de 3", "não abriu na página atual")
	_conferir(hud._mission_previous.visible and hud._mission_next.visible and not hud._mission_close.visible,
		"a página intermediária não mostra as duas setas ou já permite fechar")
	_conferir(hud._heading.z_index > minimapa.z_index and hud._mission_next.z_index > minimapa.z_index,
		"a mensagem ou suas setas ficam atrás do minimapa")
	hud._mission_previous.pressed.emit()
	_conferir(hud._objective_label.text == "Primeira" and hud._mission_previous.visible and hud._mission_previous.disabled, "a seta anterior não volta à primeira ou some no limite")
	var direita := InputEventKey.new()
	direita.keycode = KEY_RIGHT
	direita.pressed = true
	hud._unhandled_key_input(direita)
	_conferir(hud._objective_label.text == "Segunda", "a seta direita não avança uma página")
	var esquerda := InputEventKey.new()
	esquerda.keycode = KEY_LEFT
	esquerda.pressed = true
	hud._unhandled_key_input(esquerda)
	_conferir(hud._objective_label.text == "Primeira", "a seta esquerda não volta uma página")
	hud._mission_next.pressed.emit()
	hud._mission_next.pressed.emit()
	_conferir(hud._objective_label.text == "Terceira" and hud._mission_step.text == "3 de 3",
		"a seta seguinte não chega à última página")
	_conferir(not hud._mission_next.visible and hud._mission_close.visible, "o fechar não aparece só no fim")
	hud._mission_close.pressed.emit()
	_conferir(not hud._heading.visible and not hud._objective_label.visible, "o fechar não recolheu a mensagem")
	var novas_paginas: Array[String] = ["Nova primeira", "Nova segunda"]
	hud.set_mission_pages(novas_paginas)
	hud.set_objective("Nova primeira")
	hud.set_mission_step(1, 2)
	_conferir(hud._heading.visible and hud._objective_label.text == "Nova primeira", "uma nova missão não reabriu o painel")
	hud.set_objective("Concluída")
	hud.set_mission_step(2, 2, true)
	_conferir(not hud._mission_next.visible and not hud._mission_close.visible and hud._objective_label.text == "Concluída",
		"a conclusão ainda permite navegar nas páginas antigas")
	print("PAGINAS_MISSAO_OK" if falhas == 0 else "paginas_missao: %d falhas" % falhas)
	quit(1 if falhas > 0 else 0)
