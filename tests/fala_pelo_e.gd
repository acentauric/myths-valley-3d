extends "res://tests/suite/caso.gd"
## O E CONTROLA A CONVERSA (#220): a fala da missão e a conversa que o jogador abriu não somem sozinhas
## com ele perto; o E passa a página, e na última a fecha.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste fala_pelo_e
##     ... -- --falsificar-espera        (o portão TEM de reprovar: a fala passa pelo tempo, sem esperar o E)
##
## Playtest: o Pedro falava andando e o balão sumia quando o tempo acabava; em fala longa, com várias
## páginas, o jogador perdia parte do texto. Seis perguntas:
##
##   1. COM O JOGADOR PERTO, o tempo da fala PARA: passados mais segundos que ela dura, o balão segue lá, e o
##      "E ×" do cabeçalho, a dica "Fechar" e o foco do E (com viés que vence qualquer outro alvo) dizem que a
##      fala espera.
##   2. O E PASSA A PÁGINA, uma por uma e sem pular nenhuma, e NA ÚLTIMA FECHA: a fala não está mais na fila
##      e o balão some; antes da última, o "E »" e a dica "Continuar" dizem que há mais. O Esc a fecha de
##      qualquer página.
##   3. A FALA CURTA (uma página só) fecha no primeiro E.
##   4. AFASTANDO-SE, a fala acaba pelo tempo: a condução do Pedro não trava por causa de quem foi embora.
##   5. O CUMPRIMENTO DE QUEM PASSA, e a fala que pede `"por_e": false` (a cena, o aviso solto), passam sozinhos.
##   6. O TEMPO DO PORTÃO: sem janela (--headless) a fala não espera o E, para os outros portões seguirem; este
##      liga a espera à mão (`FilaDeFalas.ligar_a_espera_pelo_e`).

## Recebe o vale montado do zero: reprovava no vale deixado pelos casos anteriores (a suíte, #242).
const VALE_NOVO := true

const MISSAO := 1
const FALA_CURTA := "Bom dia, moço."
const FALA_LONGA := "Escuta com atenção, moço, que o que eu vou te dizer não se diz duas vezes. O saveiro sai de manhã cedo, quando a maré enche, e quem perde a hora espera a outra lua. A ponte do rio grande está caída desde a cheia, e sem lenha, pedra e corda ninguém atravessa. Fale com a Dona Candinha, pegue a chave da casa do seu tio e depois me procure no píer, que eu te conto o resto da história toda."

var falhas := 0
var falsificar := false


func _initialize() -> void:
	for argumento in OS.get_cmdline_user_args():
		if argumento == "--falsificar-espera":
			falsificar = true
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("FALA_PELO_E_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	var vale = current_scene
	var jogador = vale.player
	var mundo = vale.world
	var tonho = vale._achar_morador("tonho")
	var tecla = vale.get("tecla_dos_moradores")
	var foco = vale.get("foco_do_e")
	var fila = vale.get("fila_de_falas")
	_conferir(tonho != null and tecla != null and foco != null and fila != null, "o vale não tem o Tonho, a tecla do E, o foco ou a fila de falas")
	if tonho == null or tecla == null or foco == null or fila == null:
		_fechar()
		return
	root.get_node("/root/Dia").pausado = true
	var Fila = load("res://scripts/prototipo_3d/fila_de_falas.gd")
	if not falsificar:
		Fila.ligar_a_espera_pelo_e(true)
	var seta = vale.get_node_or_null("SetaMissao")
	if seta != null and seta.has_method("limpar"):
		seta.limpar()
	await _ate(func() -> bool: return fila.livre(), 40.0)
	_pôr_o_jogador_a(jogador, mundo, tonho, 3.0)
	await _esperar(1.4)
	# Chegar a 3 u dele faz o Tonho cumprimentar quem passa: a fala de prova espera o cumprimento acabar.
	await _ate(func() -> bool: return fila.livre(), 15.0)

	# --- 1 e 3. A FALA CURTA: o tempo para, e um E fecha -------------------------------------
	tonho.narrar("", FALA_CURTA, {"classe": MISSAO})
	var abriu: bool = await _ate(func() -> bool: return fila.falando(tonho) and tonho.balao.visible, 8.0)
	_conferir(abriu, "a fala da missão do Tonho não abriu o balão")
	if not abriu:
		_fechar()
		return
	await _esperar(1.0)
	_conferir(tonho.balao.a_vista(), "o balão do Tonho não está à vista a 3 u (câmera a %.1f)" % _camera_ate(tonho))
	_conferir(tonho.espera_o_e(), "com o jogador a 3 u a fala da missão não espera o E")
	var resta_antes := float(fila.atual().get("resta", 0.0))
	await _esperar(4.0)
	_conferir(fila.falando(tonho) and tonho.balao.visible, "a fala curta (2,5 s) acabou sozinha com o jogador perto: ele não leu")
	_conferir(absf(float(fila.atual().get("resta", 0.0)) - resta_antes) < 0.2, "o tempo da fala seguiu correndo com o jogador perto (resta %.2f → %.2f)" % [resta_antes, float(fila.atual().get("resta", 0.0))])
	_conferir(tonho.balao._indicador_e.visible and str(tonho.balao._indicador_e.text).contains("×"), "o balão da fala curta não mostra o \"E ×\" do fim")
	_conferir(tecla.perto() == tonho, "a tecla do E não vê o Tonho como quem leva o E com a fala aberta")
	_conferir(float(tecla.alvo_do_e().get("vies", 0.0)) >= 1000.0, "o E da fala aberta não vence os outros alvos (viés %s)" % str(tecla.alvo_do_e().get("vies", 0.0)))
	_conferir(foco.dono() == tecla, "o foco do E não está com a conversa aberta")
	_conferir(tecla._rotulo(tonho) == "Fechar", "a dica da fala curta devia dizer Fechar, e diz %s" % tecla._rotulo(tonho))
	tecla.usar(tonho)
	await _quadros(3)
	_conferir(not fila.falando(tonho) and not tonho.balao.visible, "o E na fala curta não a fechou")
	_conferir(not tonho.espera_o_e(), "fechada a fala, o Tonho ainda diz que espera o E")

	# --- 2. O E PASSA CADA PÁGINA E FECHA NA ÚLTIMA ------------------------------------------
	await _ate(func() -> bool: return fila.livre(), 10.0)
	tonho.narrar("", FALA_LONGA, {"classe": MISSAO})
	var abriu_longa: bool = await _ate(func() -> bool: return fila.falando(tonho) and tonho.balao.visible, 8.0)
	_conferir(abriu_longa, "a fala longa do Tonho não abriu o balão")
	if abriu_longa:
		await _esperar(0.8)
		var balao = tonho.balao
		var paginas: int = balao.paginas()
		_conferir(paginas >= 3, "a fala longa virou %d página(s): devia passar de duas" % paginas)
		_conferir(balao.pagina() == 0 and tonho.fala_tem_mais(), "a fala longa não abriu na primeira página, com mais por vir")
		_conferir(str(balao._indicador_e.text).contains("»"), "o balão da fala longa não mostra o \"E »\" de que há mais")
		_conferir(tecla._rotulo(tonho) == "Continuar", "a dica da fala com mais páginas devia dizer Continuar, e diz %s" % tecla._rotulo(tonho))
		var resta := float(fila.atual().get("resta", 0.0))
		await _esperar(2.0)
		_conferir(absf(float(fila.atual().get("resta", 0.0)) - resta) < 0.2 and balao.pagina() == 0, "a fala longa seguiu pelo tempo com o jogador perto, sem o E")
		var vistas: Array[int] = [0]
		for toque in paginas - 1:
			tecla.usar(tonho)
			await _quadros(3)
			_conferir(fila.falando(tonho), "o E da página %d fechou a fala antes da última" % toque)
			vistas.append(balao.pagina())
		var em_ordem := true
		for i in vistas.size():
			em_ordem = em_ordem and vistas[i] == i
		_conferir(em_ordem and vistas.size() == paginas, "o E não passou as páginas uma a uma, sem pular: %s" % str(vistas))
		_conferir(not tonho.fala_tem_mais() and str(balao._indicador_e.text).contains("×"), "na última página o balão devia mostrar o \"E ×\" do fim")
		_conferir(tecla._rotulo(tonho) == "Fechar", "na última página a dica devia dizer Fechar")
		tecla.usar(tonho)
		await _quadros(3)
		_conferir(not fila.falando(tonho) and not balao.visible, "o E na última página não fechou a fala")

	# O ESC FECHA A CONVERSA de qualquer página (e, sem conversa aberta, não faz nada: o menu é dele).
	await _ate(func() -> bool: return fila.livre(), 10.0)
	_conferir(not tecla.fechar_a_fala(), "o Esc fechou uma conversa que não existe")
	tonho.narrar("", FALA_LONGA, {"classe": MISSAO})
	await _ate(func() -> bool: return fila.falando(tonho) and tonho.balao.visible, 8.0)
	await _esperar(0.8)
	_conferir(tonho.espera_o_e() and tonho.balao.pagina() == 0, "a fala longa do Esc não abriu esperando o E, na primeira página")
	_conferir(tecla.fechar_a_fala(), "o Esc não fechou a conversa aberta")
	await _quadros(3)
	_conferir(not fila.falando(tonho) and not tonho.balao.visible, "depois do Esc a fala do Tonho segue no ar")

	# --- 4. AFASTANDO-SE, A FALA ACABA PELO TEMPO -------------------------------------------
	await _ate(func() -> bool: return fila.livre(), 10.0)
	_pôr_o_jogador_a(jogador, mundo, tonho, 14.0)
	await _esperar(1.0)
	tonho.narrar("", FALA_CURTA, {"classe": MISSAO})
	await _ate(func() -> bool: return fila.falando(tonho), 8.0)
	_conferir(not tonho.espera_o_e(), "com o jogador a 14 u a fala do Tonho espera o E")
	var acabou: bool = await _ate(func() -> bool: return not fila.falando(tonho), 8.0)
	_conferir(acabou, "com o jogador longe a fala curta não acabou sozinha em 8 s: a condução trava")

	# --- 5. O QUE PASSA SOZINHO --------------------------------------------------------------
	await _ate(func() -> bool: return fila.livre(), 10.0)
	_pôr_o_jogador_a(jogador, mundo, tonho, 3.0)
	await _esperar(1.4)
	# Chegar a 3 u dele faz o Tonho cumprimentar quem passa: a fala de prova espera o cumprimento acabar.
	await _ate(func() -> bool: return fila.livre(), 15.0)
	tonho.narrar("", FALA_CURTA, {"classe": MISSAO, "por_e": false})
	var solta: bool = await _ate(func() -> bool: return fila.falando(tonho), 8.0)
	_conferir(solta and not tonho.espera_o_e(), "a fala com \"por_e\": false esperou o E (a cena e o aviso solto passam sozinhos)")
	await _ate(func() -> bool: return not fila.falando(tonho), 8.0)
	await _ate(func() -> bool: return fila.livre(), 10.0)
	tonho.saudar()
	var cumprimentou: bool = await _ate(func() -> bool: return fila.falando(tonho), 8.0)
	_conferir(cumprimentou and not tonho.espera_o_e(), "o cumprimento de quem passa esperou o E")
	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("FALA_PELO_E_OK: com o jogador perto a fala da missão e a conversa esperam o E, que passa as páginas uma a uma e na última fecha; longe, ou no cumprimento e na cena, a fala passa pelo tempo")
	else:
		print("fala_pelo_e: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicao.call():
			return true
		await process_frame
	return condicao.call()


## Quadros por `segundos` de relógio: a câmera suave anda com o tempo, não com o quadro.
func _esperar(segundos: float) -> void:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		await process_frame


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _camera_ate(morador) -> float:
	var camera := root.get_viewport().get_camera_3d()
	return camera.global_position.distance_to(morador.global_position) if camera != null else -1.0


func _pôr_o_jogador_a(jogador, mundo, morador, distancia: float) -> void:
	var de: Vector3 = morador.global_position
	var onde: Vector3 = mundo.ground_position(de + Vector3(0.0, 0.0, distancia), 0.1)
	jogador.teleportar(onde, atan2(de.x - onde.x, de.z - onde.z))


func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
