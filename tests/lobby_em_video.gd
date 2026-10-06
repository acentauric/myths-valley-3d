extends SceneTree
## Confere O LOBBY EM VÍDEO DO MENU, e o pedido que traz o vale 3D de volta.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/lobby_em_video.gd
##
## "Vídeo do lobby em toda build e no editor (F5)": o menu abre com o sobrevoo pintado do LTX
## em laço, e o vale 3D de fundo — que levava ~27 s só para montar por trás do voo — nem nasce
## (`abertura.gd`, `_enter_tree`). Três perguntas, que os outros portões do menu não fazem
## (eles pedem o lobby 3D, porque medem o vale de fundo):
##
##   1. O MENU ABRE EM VÍDEO: sem pedido nenhum, o vídeo do sobrevoo toca em laço numa camada
##      atrás do retábulo, e o menu sabe que é assim (`lobby_em_video`).
##   2. SEM VALE POR TRÁS: o `Cenario` sai antes de entrar na árvore, o `_ready` da montagem
##      nunca roda (nenhum nó no grupo `mundo`), e o botão do MAPA — que abre um mapa feito do
##      vale — não nasce.
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
	_conferir(menu.get("map_icon") == null, "o botão do MAPA nasceu num menu sem vale")
	if falhas > 0:
		# Com o menu já errado não há o que comparar: e instanciar o vale 3D de novo, com o
		# primeiro ainda montando, só enche a saída de erro de montagem interrompida.
		_fechar()
		return

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
		print("LOBBY_EM_VIDEO_OK: o menu abre com o sobrevoo em vídeo, em laço e atrás do retábulo, sem vale 3D por trás nem botão de MAPA; e o pedido de lobby 3D (o dos portões do sobrevoo e do fluxo) devolve o vale de fundo")
	else:
		print("lobby_em_video: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame
