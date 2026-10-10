extends "res://tests/suite/caso.gd"
## Confere O LOBBY EM VÍDEO DO MENU, e o pedido que traz o vale 3D de volta.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste lobby_em_video
##
## "Vídeo do lobby em toda build e no editor (F5)": o menu abre com o sobrevoo pintado do LTX
## em laço, e o vale 3D de fundo — que levava ~27 s só para montar por trás do voo — nem nasce
## (`abertura.gd`, `_enter_tree`). Três perguntas, que os outros portões do menu não fazem
## (eles pedem o lobby 3D, porque medem o vale de fundo):
##
##   1. O MENU ABRE EM VÍDEO: sem pedido nenhum, o vídeo do sobrevoo toca em laço numa camada
##      atrás do retábulo, e o menu sabe que é assim (`lobby_em_video`).
##   2. SEM VALE POR TRÁS: o `Cenario` sai antes de entrar na árvore, o `_ready` da montagem
##      nunca roda (nenhum nó no grupo `mundo`), mas o acesso ao MAPA permanece; o clique
##      carrega o cenário sob demanda, sem custo na abertura inicial.
##   3. O PEDIDO TRAZ O VALE 3D DE VOLTA: com `lobby_3d_pedido` ligado (o que o sobrevoo, o
##      mapa e o fluxo do menu usam, porque o `--lobby-3d` só existe na linha de comando e o
##      runner não passa argumento a portão) o menu NÃO abre em vídeo e fica com o `Cenario`.
##
## FALSIFICAÇÃO: com `-- --falsificar` o gate liga o pedido antes da pergunta 1 — o menu abre
## com o vale 3D, e o gate TEM de reprovar na 1.

const ABERTURA := "res://scenes/prototipo_3d/abertura.tscn"
const SCRIPT_DA_ABERTURA := "res://scripts/prototipo_3d/abertura.gd"

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("LOBBY_EM_VIDEO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	# `load` e não `preload`: a abertura cita autoload, que só existe depois do `_initialize`.
	var script_da_abertura := load(SCRIPT_DA_ABERTURA) as GDScript
	_conferir(script_da_abertura != null, "o script da abertura carrega")
	if script_da_abertura == null:
		_fechar()
		return
	if "--falsificar" in OS.get_cmdline_user_args():
		script_da_abertura.set("lobby_3d_pedido", true)
		print("  falsificando: o pedido de lobby 3D está ligado desde o início")

	# --- 1. O MENU ABRE EM VÍDEO ------------------------------------------------------
	_conferir(change_scene_to_file(ABERTURA) == OK, "a abertura carrega")
	await _quadros(6)
	var menu := current_scene
	_conferir(menu != null and menu.name == "Abertura", "a cena aberta não é a abertura")
	if menu == null:
		_fechar()
		return
	var video_existe := ResourceLoader.exists(str(menu.get("VIDEO_LOBBY")))
	_conferir(video_existe, "o arquivo do vídeo do lobby não existe: %s" % str(menu.get("VIDEO_LOBBY")))
	_conferir(bool(menu.get("lobby_em_video")), "sem pedido nenhum, o menu não abriu em vídeo (lobby_em_video é falso)")
	var camada := menu.get_node_or_null("VideoDoLobby")
	_conferir(camada != null, "o menu não tem a camada do vídeo do lobby")
	if camada != null:
		var tocador := camada.get_node_or_null("Fundo/Video/Player") as VideoStreamPlayer
		_conferir(tocador != null and tocador.stream != null and tocador.loop, "o vídeo do lobby não toca em laço")
		_conferir((camada as CanvasLayer).layer < 0, "o vídeo do lobby não fica atrás do menu (camada %d)" % (camada as CanvasLayer).layer)

	# --- 2. SEM VALE POR TRÁS ---------------------------------------------------------
	_conferir(menu.get_node_or_null("Cenario") == null, "o vale 3D de fundo continua no menu em vídeo")
	_conferir(get_first_node_in_group("mundo") == null, "há um mundo montando por trás do menu em vídeo")
	if "--falsificar-mapa" in OS.get_cmdline_user_args():
		menu.map_icon = null
	_conferir(menu.get("map_icon") != null, "o lobby em vídeo perdeu o acesso explícito ao Mapa")
	if menu.map_icon != null:
		var botao_mapa := menu.map_icon.get_parent() as Button
		_conferir(botao_mapa != null and botao_mapa.is_visible_in_tree(), "o botão Mapa não está visível")
		var tamanho_anterior := root.size
		for tamanho in [Vector2i(1280, 720), Vector2i(800, 600), Vector2i(1920, 1080)]:
			root.size = tamanho
			await _quadros(2)
			var anteriores: Array[Rect2] = []
			for canto in get_nodes_in_group(menu.BotaoCanto.GRUPO):
				var retangulo: Rect2 = canto.get_global_rect()
				_conferir(root.get_visible_rect().encloses(retangulo), "atalho do lobby cortado em %s" % tamanho)
				for outro in anteriores:
					_conferir(not outro.intersects(retangulo), "atalhos sobrepostos em %s" % tamanho)
				anteriores.append(retangulo)
			_conferir(anteriores.size() == 6, "o lobby não oferece os seis acessos laterais previstos")
		root.size = tamanho_anterior
	if falhas > 0:
		# Com o menu já errado não há o que comparar: e instanciar o vale 3D de novo, com o
		# primeiro ainda montando, só enche a saída de erro de montagem interrompida.
		_fechar()
		return

	# O clique real solicita o cenário somente agora e abre o mapa após a carga.
	(menu.map_icon.get_parent() as Button).pressed.emit()
	var inicio := Time.get_ticks_msec()
	while Time.get_ticks_msec() - inicio < 120000:
		await process_frame
		if current_scene != menu and current_scene != null and current_scene.map_open:
			break
	_conferir(current_scene != menu and current_scene != null and current_scene.map_open,
		"pedir o mapa no vídeo não terminou com a interface do mapa aberta")
	if current_scene != null and current_scene.map_open:
		_conferir(current_scene.map_markers.size() >= 11, "o mapa solicitado não tem os pontos de interesse")
		_conferir(current_scene.get_node_or_null("VideoDoLobby") == null, "o vídeo cobre o mapa")
		current_scene._home()
		_conferir(not current_scene.map_open, "o mapa não retorna ao lobby")
	# --- 3. O PEDIDO TRAZ O VALE 3D DE VOLTA --------------------------------------------
	script_da_abertura.set("lobby_3d_pedido", true)
	_conferir(change_scene_to_file(ABERTURA) == OK, "a abertura não carrega pela segunda vez")
	await _quadros(6)
	var menu_3d := current_scene
	_conferir(menu_3d != null and not bool(menu_3d.get("lobby_em_video")), "com o pedido de lobby 3D o menu abriu em vídeo")
	_conferir(menu_3d != null and menu_3d.get_node_or_null("Cenario") != null, "com o pedido de lobby 3D o menu não tem o vale de fundo")
	script_da_abertura.set("lobby_3d_pedido", false)
	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("LOBBY_EM_VIDEO_OK: vídeo sem carga de cenário inicial; Mapa acessível e carregado sob demanda; retorno e lobby 3D preservados")
	else:
		print("lobby_em_video: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame
