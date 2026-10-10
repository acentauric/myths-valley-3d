extends "res://tests/suite/caso.gd"
## O PEDRO SEGUE ENQUANTO O JOGADOR O VÊ, E SÓ VOLTA QUANDO ELE SAI DA TELA (#238).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste conducao_pela_vista
##     .\tools\prototipo_3d\testar.ps1 -Teste conducao_pela_vista -Extra --falsificar
##
## Na condução o Pedro andava colado: o "Pedro voltou para te buscar" disparava a 5,5 u do jogador,
## e com o jogador um pouco lento (ou o testador hesitando) ele ia e voltava. A regra agora é a vista
## (`GuiaPedro.decidir_a_conducao`, `esta_na_tela_do_jogador`):
##
##   1. A DECISÃO, SEM MUNDO. Visível, ele segue, mesmo a 17 u e muito atrás na linha; fora da vista, longe
##      e atrás, ele ESPERA, e só depois de ESPERA_ANTES_DE_VOLTAR volta — e não volta se o jogador vem
##      na direção dele; barrado por cerca ou mourão, ele não volta (a falha é da rota); voltando, para
##      quando o jogador chega perto ou quando volta a vê-lo; perto do jogador, nunca espera.
##   2. A VISTA, NO VALE. Na praça, com o jogador a 10 u e a câmera virada para o Pedro, ele está na tela;
##      com a câmera virada para o outro lado, não; e a mais de LEGIVEL_ATE, mesmo de frente, não.
##
## `--falsificar` volta à regra de antes (a vista não conta) e a parte 1 reprova.

## Carregado na hora, e não por preload: o guia cita autoloads (o Inventario), e um preload o
## compilaria junto com este script, antes de o --script ter os autoloads.
var Guia = null

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()
	create_timer(300).timeout.connect(func() -> void:
		print("FALHA: a prova da vista excede o tempo")
		quit(2))


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("CONDUCAO_PELA_VISTA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	Guia = load("res://scripts/prototipo_3d/guia_pedro.gd")
	var regra: GDScript = Guia
	if "--falsificar" in OS.get_cmdline_user_args():
		regra = load("res://scripts/prototipo_3d/guia_pedro.gd")
		regra.source_code = regra.source_code.replace("if a_vista or barrado:", "if barrado:")
		_conferir(regra.reload() == OK, "o mutante da vista compila")
		_a_decisao(regra)
		print("CONDUCAO_PELA_VISTA (falsificado): %d falha(s)" % falhas)
		quit(1 if falhas > 0 else 0)
		return
	_a_decisao(regra)
	await _a_vista_no_vale()
	print("CONDUCAO_PELA_VISTA: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


# --- 1. A DECISÃO ---------------------------------------------------------------------------

func _a_decisao(regra: GDScript) -> void:
	var segue: int = regra.Conducao.SEGUE
	var espera: int = regra.Conducao.ESPERA
	var volta: int = regra.Conducao.VOLTA
	var espera_max: float = regra.ESPERA_ANTES_DE_VOLTAR
	var legivel: float = regra.LEGIVEL_ATE
	# (a_vista, atraso, do_jogador, voltando, esperou_s, vindo, barrado)
	_conferir(regra.decidir_a_conducao(true, legivel - 1.0, legivel - 1.0, false, 0.0, false, false) == segue,
		"à vista, a %.0f u do jogador, o Pedro não segue" % (legivel - 1.0))
	_conferir(regra.decidir_a_conducao(true, 40.0, legivel - 1.0, false, 99.0, false, false) == segue,
		"à vista, mesmo muito atrás na linha e esperando há muito, o Pedro não segue")
	_conferir(regra.decidir_a_conducao(false, 12.0, 12.0, false, 0.0, false, false) == espera,
		"fora da vista, longe e atrás, o Pedro não espera primeiro")
	_conferir(regra.decidir_a_conducao(false, 12.0, 12.0, false, espera_max - 0.5, false, false) == espera,
		"fora da vista, antes do tempo de espera, o Pedro já volta")
	_conferir(regra.decidir_a_conducao(false, 12.0, 12.0, false, espera_max, false, false) == volta,
		"fora da vista, passado o tempo de espera, o Pedro não volta")
	_conferir(regra.decidir_a_conducao(false, 12.0, 12.0, false, espera_max + 5.0, true, false) == espera,
		"com o jogador vindo na direção dele, o Pedro volta em vez de esperar")
	_conferir(regra.decidir_a_conducao(false, 12.0, 4.0, false, 99.0, false, false) == segue,
		"fora da vista mas com o jogador a 4 u, o Pedro não segue")
	_conferir(regra.decidir_a_conducao(false, 4.0, 12.0, false, 99.0, false, false) == segue,
		"fora da vista mas com o jogador à frente na linha, o Pedro não segue")
	_conferir(regra.decidir_a_conducao(false, 12.0, 12.0, false, 99.0, false, true) == segue,
		"barrado por cerca ou mourão, o Pedro volta à cidade em vez de tentar passar")
	_conferir(regra.decidir_a_conducao(false, 12.0, 12.0, true, 0.0, false, false) == volta,
		"voltando, fora da vista, o Pedro para de voltar")
	_conferir(regra.decidir_a_conducao(true, 12.0, 12.0, true, 0.0, false, false) == segue,
		"voltando, com o jogador vendo-o de novo, o Pedro não retoma a condução")
	_conferir(regra.decidir_a_conducao(false, 12.0, regra.VOLTA_A_ANDAR - 0.5, true, 0.0, false, false) == segue,
		"voltando e já perto do jogador, o Pedro não retoma a condução")


# --- 2. A VISTA, NO VALE --------------------------------------------------------------------

func _a_vista_no_vale() -> void:
	change_scene_to_file("res://scenes/prototipo_3d/vale.tscn")
	await process_frame
	while current_scene == null or current_scene.get("carga_ok") != true:
		await process_frame
	var vale: Node = current_scene
	root.get_node("Dia").pausado = true
	vale.apresentacao_do_povoado.set_process(false)
	var mundo = vale.world
	var pedro = vale.pedro
	var jogador = vale.player
	var praca: Vector3 = root.get_node("/root/Lugares").ponto("praca")
	_conferir(pedro != null and jogador != null and praca.is_finite(), "o vale tem o Pedro, o jogador e a praça")
	if pedro == null or jogador == null or not praca.is_finite():
		return
	pedro.set_physics_process(false)
	pedro.global_position = mundo.ground_position(praca, 0.1)
	var livre := false
	for graus in [0, 45, 90, 135, 180, 225, 270, 315]:
		if livre:
			break
		var dir := Vector3(sin(deg_to_rad(float(graus))), 0.0, cos(deg_to_rad(float(graus))))
		var perto: Vector3 = mundo.ground_position(pedro.global_position + dir * 10.0, 0.1)
		var para_ele := atan2(-dir.x, -dir.z)
		# A câmera olha para onde o corpo olha; confere pelo próprio resultado qual dos dois rumos põe o Pedro na tela.
		for olhar in [para_ele, para_ele + PI]:
			jogador.teleportar(perto, olhar)
			await _quadros(8)
			if not pedro.esta_na_tela_do_jogador():
				continue
			livre = true
			# Virada para o outro lado, a câmera não o tem na tela.
			jogador.teleportar(perto, olhar + PI)
			await _quadros(8)
			_conferir(not pedro.esta_na_tela_do_jogador(), "com a câmera virada para o lado contrário a %d graus, o Pedro continua na tela" % graus)
			# E a mais de LEGIVEL_ATE, mesmo de frente, é longe demais para ler.
			var longe: Vector3 = mundo.ground_position(pedro.global_position + dir * (Guia.LEGIVEL_ATE + 8.0), 0.1)
			jogador.teleportar(longe, olhar)
			await _quadros(8)
			_conferir(not pedro.esta_na_tela_do_jogador(), "a %.0f u, de frente, o Pedro ainda é dado por visível" % (Guia.LEGIVEL_ATE + 8.0))
			break
	_conferir(livre, "em nenhuma das oito direções da praça o Pedro aparece na tela a 10 u: ou a vista está errada, ou o gate não achou campo aberto")


func _quadros(n: int) -> void:
	for i in n:
		await process_frame
	await physics_frame
