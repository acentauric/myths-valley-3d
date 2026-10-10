extends "res://tests/unidade/base.gd"
## O nado parado usa o novo clipe; em movimento e nos modelos antigos usa swim.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste nado_parado_animacao

const Animador = preload("res://scripts/prototipo_3d/authored_animator.gd")


func test_nado_parado_animacao() -> void:
	var modelo := Node3D.new()
	pendurar(modelo)
	var player := AnimationPlayer.new()
	modelo.add_child(player)
	var biblioteca := AnimationLibrary.new()
	for nome in ["idle", "walk", "run", "swim", "run_upstairs"]:
		var animacao := Animation.new()
		animacao.length = 1.0
		biblioteca.add_animation(nome, animacao)
	player.add_animation_library("", biblioteca)
	var animador = Animador.new()
	pendurar(animador)
	_conferir(animador.configure(modelo), "o modelo não configurou o animador")
	animador.set_swimming(true)
	animador.update_motion(0.0, 0.0)
	_conferir(animador.get_current_animation() == &"run_upstairs",
		"o nado parado não selecionou subir_escadas")
	animador.update_motion(1.0, 0.0)
	_conferir(animador.get_current_animation() == &"swim",
		"o nado em movimento não selecionou swim")
	var modelo_antigo := Node3D.new()
	pendurar(modelo_antigo)
	var player_antigo := AnimationPlayer.new()
	modelo_antigo.add_child(player_antigo)
	var biblioteca_antiga := AnimationLibrary.new()
	for nome in ["idle", "walk", "run", "swim"]:
		var animacao := Animation.new()
		animacao.length = 1.0
		biblioteca_antiga.add_animation(nome, animacao)
	player_antigo.add_animation_library("", biblioteca_antiga)
	var animador_antigo = Animador.new()
	pendurar(animador_antigo)
	_conferir(animador_antigo.configure(modelo_antigo), "o modelo antigo não configurou o animador")
	animador_antigo.set_swimming(true)
	animador_antigo.update_motion(0.0, 0.0)
	_conferir(animador_antigo.get_current_animation() == &"swim",
		"o modelo antigo sem subir_escadas perdeu o nado parado")
