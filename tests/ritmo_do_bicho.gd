extends SceneTree
## O passo normal não vira galope só porque o clipe tem passada curta.
## Deslizar por um único eixo deve animar só o deslocamento que ocorreu.

var Animador

class ChaoDeTeste extends Node3D:
	func ground_height_at(_p: Vector3) -> float:
		return 0.0
	func ground_position(p: Vector3, _folga: float) -> Vector3:
		return p
	func water_depth_at(p: Vector3) -> float:
		return 1.0 if p.x > 0.015 else 0.0
	func water_level_at(_p: Vector3) -> float:
		return 0.0

var falhas := 0
func _initialize() -> void:
	_run.call_deferred()

func _confere(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas += 1
		push_error("RITMO_DO_BICHO_FALHOU: " + mensagem)

func _run() -> void:
	Animador = load("res://scripts/prototipo_3d/animador_bicho.gd")
	var palco := Node3D.new()
	root.add_child(palco)
	var pose := Node3D.new()
	palco.add_child(pose)
	var modelo := Node3D.new()
	pose.add_child(modelo)
	var tocador := AnimationPlayer.new()
	modelo.add_child(tocador)
	var biblioteca := AnimationLibrary.new()
	var clipe := Animation.new()
	clipe.length = 1.0
	biblioteca.add_animation("walk", clipe)
	tocador.add_animation_library("", biblioteca)
	var an = Animador.new()
	palco.add_child(an)
	an.set_process(false)
	an.configurar(pose, modelo, false, "teste", 0.75)
	# O gato malhado atual mede ~0,22 u/s: o clipe precisa acelerar mesmo ao andar.
	an.passada = 0.22
	if "--falsificar-passo" in OS.get_cmdline_user_args():
		an.velocidade_do_passo = an.passada
	an.velocidade = 0.75
	var salto := 0.0
	for quadro in 120:
		an._process(1.0 / 60.0)
		salto = maxf(salto, pose.position.y)
	_confere(salto < 0.001, "o passeio ganhou salto artificial de %.3f u" % salto)
	_confere(tocador.speed_scale > 3.0, "o clipe não acompanha a passada curta")
	an.velocidade = 2.1
	salto = 0.0
	for quadro in 120:
		an._process(1.0 / 60.0)
		salto = maxf(salto, pose.position.y)
	_confere(salto > 0.02, "a corrida perdeu o balanço do corpo")
	var chao := ChaoDeTeste.new()
	palco.add_child(chao)
	var bicho = load("res://tests/fixtures/bicho_sem_rotina.gd").new()
	palco.add_child(bicho)
	bicho.world = chao
	bicho._animador = an
	bicho._alvo = Vector3(2.0, 0.0, 2.0)
	bicho._velocidade = 1.0
	var antes: Vector3 = bicho.global_position
	bicho._andar_livre(0.1)
	var deslocamento: Vector3 = bicho.global_position - antes
	var real := Vector2(deslocamento.x, deslocamento.z).length() / 0.1
	if "--falsificar-movimento" in OS.get_cmdline_user_args():
		an.velocidade = Vector2(bicho.velocity.x, bicho.velocity.z).length()
	_confere(real > 0.5 and real < 0.8, "a margem não fez deslizar por só um eixo")
	_confere(absf(an.velocidade - real) < 0.001,
		"passada animada %.3f u/s, deslocamento real %.3f u/s" % [an.velocidade, real])
	# Mesma pergunta com move_and_slide de produção e uma parede física.
	var piso := StaticBody3D.new()
	palco.add_child(piso)
	var piso_col := CollisionShape3D.new()
	var piso_forma := BoxShape3D.new()
	piso_forma.size = Vector3(10.0, 0.2, 10.0)
	piso_col.shape = piso_forma
	piso.add_child(piso_col)
	piso.position.y = -0.1
	var parede := StaticBody3D.new()
	palco.add_child(parede)
	var parede_col := CollisionShape3D.new()
	var parede_forma := BoxShape3D.new()
	parede_forma.size = Vector3(3.0, 2.0, 0.1)
	parede_col.shape = parede_forma
	parede.add_child(parede_col)
	parede.position = Vector3(-1.0, 1.0, 0.0)
	var corpo_col := CollisionShape3D.new()
	var corpo_forma := CapsuleShape3D.new()
	corpo_forma.radius = 0.12
	corpo_forma.height = 0.5
	corpo_col.shape = corpo_forma
	bicho.add_child(corpo_col)
	bicho.global_position = Vector3(-1.0, 0.3, -1.0)
	bicho.velocity = Vector3.ZERO
	bicho._alvo = Vector3(-1.0, 0.3, 1.0)
	var erro := 0.0
	for quadro in 75:
		await physics_frame
		antes = bicho.global_position
		bicho._andar(1.0 / 60.0)
		deslocamento = bicho.global_position - antes
		real = Vector2(deslocamento.x, deslocamento.z).length() * 60.0
		erro = maxf(erro, absf(an.velocidade - real))
	_confere(erro < 0.001, "a colisão física não anima o deslocamento real: erro %.3f" % erro)
	_confere(bicho.global_position.z < -0.1 and bicho.global_position.z > -0.4,
		"a fixture não encostou na parede física")
	_confere(an.velocidade < 0.08, "o bicho marcha parado contra a parede")
	var bando = load("res://tests/fixtures/bando_sem_rotina.gd").new()
	palco.add_child(bando)
	bando.world = chao
	var ave := Node3D.new()
	palco.add_child(ave)
	var dados_ave := {"no": ave, "alvo": Vector3(0.0, 0.0, 0.2),
		"animador": an, "no_poleiro": false, "velocidade": 1.0}
	bando._andar(dados_ave, 1.0)
	real = ave.global_position.length()
	if "--falsificar-movimento" in OS.get_cmdline_user_args():
		an.velocidade = 1.0
	_confere(absf(an.velocidade - real) < 0.001 and is_equal_approx(real, 0.2),
		"a ave anima a velocidade pedida em vez do último passo: %.3f / %.3f" % [an.velocidade, real])
	print("RITMO_DO_BICHO: %d falha(s)" % falhas)
	palco.queue_free()
	quit(1 if falhas > 0 else 0)
