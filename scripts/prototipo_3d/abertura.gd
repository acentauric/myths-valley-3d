extends Node3D
## Interface 3D; contrato de áudio e narrativa idênticos aos da versão 2D.
const AudioToggleIcon = preload("res://scripts/prototipo_3d/audio_toggle_icon.gd")
const ClockIcon = preload("res://scripts/prototipo_3d/clock_icon.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
## O arquivo que o `jogar.py` cria quando a janela do jogo da sessão sobe (a primeira chamada
## da ponte). Só então o menu se fecha: se o testador falhar, o jogador não fica sem janela.
const TESTADOR_PRONTO := "user://testador_pronto.txt"
## O que a ponte grava quando a janela da sessão sobe: só diz que ela abriu, não fecha o menu.
## Quem fecha o menu é o TESTADOR_PRONTO, que a sessão grava com o vale carregado (#175).
const TESTADOR_JANELA := "user://testador_janela.txt"
const BotaoCanto = preload("res://scripts/prototipo_3d/botao_canto.gd")
const HudIcon = preload("res://scripts/prototipo_3d/hud_icon.gd")
const TemaMenu = preload("res://scripts/prototipo_3d/tema_menu.gd")
const PainelAjustes = preload("res://scripts/prototipo_3d/painel_ajustes.gd")
const PainelPersonagens = preload("res://scripts/prototipo_3d/painel_personagens.gd")
const TelaCarregamento = preload("res://scripts/prototipo_3d/tela_carregamento.gd")
const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")
const TestadorApoios = preload("res://scripts/prototipo_3d/testador_apoios.gd")
## O LOBBY EM VÍDEO: o sobrevoo pintado do LTX em laço, no lugar do
## vale 3D de fundo. O menu deixava a primeira carga em ~27 s só para montar o vale inteiro
## por trás do voo, e depois o desenhava a cada quadro. Vale em toda build e no editor
## (F5); `-- --lobby-3d` volta ao vale 3D de fundo, e sem o arquivo do vídeo também.
## Nas telas de carregamento não há vídeo: a montagem segura a thread principal e ele engasgava.
const VIDEO_LOBBY := TelaCarregamento.VIDEO_SOBREVOO
var lobby_em_video := false
var _video_lobby: VideoStreamPlayer
## O PORTÃO QUE MEDE O VALE 3D DE FUNDO (o sobrevoo conferido contra as árvores e as
## casas, o MAPA, a vegetação do HOME) pede o lobby 3D por aqui, ANTES de instanciar a
## cena: o `--lobby-3d` só existe na linha de comando, e o runner não passa argumento a
## portão. Sem isto o menu libera o vale na entrada, e quem espera o `mundo` fica
## girando até o teto. É de processo (`static`): fica ligada até o portão acabar.
## É o mesmo `-- --lobby-3d` para quem carrega a abertura por script: o extrator do
## sobrevoo (`tools/prototipo_3d/sobrevoo/extrair_geometria.gd`, e os portões
## `sobrevoo_livre*` que o estendem), o `mapa_fluxo` e o `lobby_em_video`.
static var lobby_3d_pedido := false
static var mapa_apos_carga := false
var _mapa_solicitado := false
const VISUAL_PREFERENCES := "user://preferencias_visuais.cfg"
const FLYOVER_SECONDS := 72.0
## Metros reais: a escala do mapa muda as unidades, mas nao a proximidade do voo.
const ALTURA_SOBREVOO := 16.0
const OLHAR_ADIANTE := 56.0
const LATERAL_SOBREVOO := 40.0
const ENQUADRAMENTO_SOBREVOO := 0.75
## Trajeto planejado offline (tools/prototipo_3d/sobrevoo/planejar.py) que contorna
## árvores e casas PELOS LADOS, sempre a ~16 m do chão: a elipse abaixo atravessava
## copas e telhados em 30% do ciclo. Os portões tests/sobrevoo_livre*.gd conferem o
## trajeto contra o vale de hoje; sem ele (âncoras mudaram), volta a elipse.
const TRAJETO_SOBREVOO := "res://data/sobrevoo_menu.json"
## Âncora gravada no trajeto x âncora do vale montado (u): passou disso, é outro vale.
const TOLERANCIA_ANCORA_U := 0.05
## Ao trocar de modo (travessia → voo, parado ↔ voo), a câmera chega ao trajeto em
## curva suave neste tempo. Em regime ela fica EXATAMENTE no trajeto: o atraso do
## lerp antigo (7 m em média) cortava as curvas por dentro, em cima das árvores.
const CHEGADA_SEGUNDOS := 2.0
const HISTORY_SIZE := Vector2(640, 600)
const TESTADOR_SIZE := Vector2(640, 700)
## O modal do nome (#214): largo para a ajuda caber em duas linhas nos três idiomas, e a ajuda no
## tamanho do corpo dos outros modais; o aviso de erro, um pouco menor.
const NOME_LARGURA := 600.0
const NOME_TAMANHO_AJUDA := 18
const NOME_TAMANHO_ERRO := 16
const HISTORY_ROWS := 10
## Lista do histórico: fonte base (desce até o mínimo se a linha não couber) e respiro.
const HISTORY_FONTE := 15
const HISTORY_FONTE_MIN := 13
## Setas de página, compactas e juntas do "N / M".
const HISTORY_SETA := Vector2(44, 32)
const GAME_SCENE := "res://scenes/prototipo_3d/vale.tscn"
## Equipe exibida em SOBRE.
const CREDITS_HIGHLIGHTS := [
	"histórias brasileiras", "Brazilian", "historias brasileñas",
	"primeira visita", "first visit", "primera visita",
	"Batalha de Mitos",
]
const COLLABORATORS := ["Ramon Santos", "Renato Leal", "Matheus Ché"]
## Fonte do menu (AJUSTAR → Cenário): padrão do Godot ou as duas fontes do 2D.
const MENU_FONTS := PainelAjustes.FONTES_MENU
## Trocar o estilo visual reconstrói a cena do menu; ao voltar, reabre a página de ajustes.
static var _reabrir_ajustes := false
var camera := Camera3D.new()
var camera_target := Vector3(0, 1.5, 0)
var map_target := Vector3.ZERO
var _camera_antes_do_mapa := Transform3D.IDENTITY
var _alvo_antes_do_mapa := Vector3.ZERO
var map_full_size := 0.0
var map_marker_root: Control
var map_markers: Array[Dictionary] = []
var panel: PanelContainer
var content: VBoxContainer
## Onde _label/_button/_slider/_choice inserem controles; volta a `content` a cada _clear().
var ui_parent: Container
var version_link: Button
## A oferta de atualização, embaixo da versão (some quando o jogo está em dia).
var linha_atualizacao: Button
var caption: Label
var estado_testador: Label
## O PID do python que sobe o testador, enquanto o menu espera a janela da sessão (#175).
var _testador_pid := 0
## Quanto falta do trecho da travessia na tela (1 → 0), para o jogador saber quando passa.
var line_bar: ProgressBar
var line_total := 1.0
var chapter: Label
var lines: Array = []
var dialog_data: Dictionary = {}
var history_entries: Array = []
var version_text := ""
var history_index := 0
var history_open := false
## Setas de página do histórico, para as teclas ← → animarem o botão correspondente.
var history_buttons: Array[Button] = []
var map_open := false
## Histórico, AJUSTAR ou SOBRE abertos no centro da tela (clique fora fecha).
var modal_open := false
var home_corner: Button
var home_icon	# hud_icon.gd
var map_icon	# hud_icon.gd
var ajustes_icon	# hud_icon.gd
var ajustes	# painel_ajustes.gd
var options_open := false
## Painel PERSONAGENS aberto sobre a camada do menu (liberado em _clear).
var painel_personagens: Control
## Botões HOME e "?" que o MAPA acrescenta à coluna do canto (removidos ao sair).
var map_corner_nodes: Array[Control] = []
## Deslize/zoom gradual até um ponto de interesse (lista do painel ou marcador).
var map_tween: Tween
var map_help_button: Button
var map_help_tip: Control
var line_index := -1
var elapsed := 0.0
var line_time := 0.0
## Respiro depois de cada trecho da narração antes da legenda seguinte.
const PAUSA_ENTRE_TRECHOS := 0.8
var starting := false
var flyover_active := true
var menu_font_option := 0
var clock_running := true
var clock_hint: Label
## Decoração da identidade sobre o vale (véus, partículas, almanaque, faixas de cinema
## e o fio de ouro) e a moldura de talha do retábulo. Ver _montar_decoracao().
var decoracao: Control
var veu_vertical: TextureRect
var veu_esquerdo: TextureRect
var bloco_almanaque: VBoxContainer
var rotulo_almanaque: Label
var nota_almanaque: Label
var veu_modal: ColorRect
var faixa_cima: ColorRect
var faixa_baixo: ColorRect
var fio_base: ProgressBar
var moldura_nodes: Array[Control] = []
var _indice_nota := 0
var _era_noite := false
var _tween_entrada: Tween
var _tween_veu_modal: Tween
var _tween_nota: Tween
## Amostras do trajeto planejado (uma a cada 0,1 s do ciclo); vazias = elipse antiga.
var _trajeto_olho := PackedVector3Array()
var _trajeto_alvo := PackedVector3Array()
## Chegada suave ao trajeto depois de uma troca de modo (0 → 1).
var _chegada := 1.0
var _chegada_olho := Vector3.ZERO
var _chegada_alvo := Vector3.ZERO
var _modo_camera := ""
## Falso enquanto a tela de carregamento cobre o menu: o foco que o _home() põe no
## JOGAR não toca o "tique" de passar por cima debaixo dela.
var _som_liberado := false

func _enter_tree() -> void:
	_mapa_solicitado = mapa_apos_carga
	mapa_apos_carga = false
	lobby_em_video = not lobby_3d_pedido and not ("--lobby-3d" in OS.get_cmdline_user_args()) \
		and not _mapa_solicitado \
		and ResourceLoader.exists(VIDEO_LOBBY)
	if lobby_em_video:
		# O vale sai antes de entrar na árvore: o _ready do world_builder, que é a montagem
		# inteira, nunca roda. Nada mais aqui toca o $Cenario com o lobby em vídeo.
		var cenario := get_node_or_null("Cenario")
		if cenario != null:
			remove_child(cenario)
			cenario.free()


func _ready() -> void:
	IdiomaMenu.aplicar_menu()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# O menu sempre abre no começo do dia; o dia corre na velocidade de Passagem do tempo.
	Dia.pausado = false
	Dia.congelado_na_carga = false
	Dia.definir_hora(Dia.INICIO_DO_DIA)
	add_child(camera)
	camera.current = true
	camera.fov = 55
	camera.far = 7000.0
	camera.position = Vector3(105, 70, 115)
	camera.look_at(camera_target)
	_load_visual_preference()
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogos/pedro.json"))
	if data is Dictionary:
		dialog_data = data
		lines = IdiomaMenu.campo(dialog_data, "travessia", [])
	var history_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/historico_3d.json"))
	if history_data is Dictionary:
		history_entries = _paginar_historico(history_data.get("entradas", []))
		version_text = "v%s · Build #%d%s" % [str(history_data.get("versao_atual", "0.1.0-dev")), int(history_data.get("build_numero", 1)), "B" if OS.has_feature("tripothon") else ""]
	var layer := CanvasLayer.new()
	add_child(layer)
	ajustes = PainelAjustes.new()
	ajustes.fechar_pedido.connect(_home)
	ajustes.estilo_mudou.connect(func() -> void:
		# Trocar o estilo reconstrói a cena do menu; ao voltar, reabre em Cenário.
		_reabrir_ajustes = true
		get_tree().reload_current_scene())
	ajustes.fonte_menu_mudou.connect(func(option: int) -> void:
		menu_font_option = option
		panel.theme = _menu_theme()
		ajustes.tema = panel.theme)
	ajustes.cenario_menu_mudou.connect(func(sobrevoo: bool) -> void:
		flyover_active = sobrevoo
		_aplicar_video_do_lobby())
	_montar_decoracao(layer)
	panel = PanelContainer.new()
	panel.position = Vector2(36, 32)
	panel.custom_minimum_size = Vector2(440, 640)
	# O fundo e a borda vêm da moldura de talha; o stylebox só guarda as margens.
	panel.add_theme_stylebox_override("panel", _estilo_vazio())
	panel.theme = _menu_theme()
	layer.add_child(panel)
	moldura_nodes = Identidade.emoldurar(panel)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	_create_home_button(layer)
	_create_ajustes_button(layer)
	_create_quick_mute(layer)
	_create_clock(layer)
	_create_map_button(layer)
	_create_tela_button(layer)
	if lobby_em_video:
		_montar_video_do_lobby()
	# O som do menu só começa quando o menu aparece: tocava debaixo da tela de
	# carregamento, desde os 25% da barra, e era a tela que parecia ter som.
	if lobby_em_video or $Cenario.construido:
		_iniciar_som_do_menu()
	else:
		$Cenario.pronto.connect(_iniciar_som_do_menu, CONNECT_ONE_SHOT)
	_era_noite = Dia.eh_noite()
	# Método (não lambda): o Godot desconecta sozinho quando o menu é liberado.
	Dia.hora_mudou.connect(_ao_mudar_hora)
	Atualizacao.mudou.connect(_atualizar_oferta)
	_ao_mudar_hora(Dia.hora)
	_home()
	if _reabrir_ajustes:
		_reabrir_ajustes = false
		_options(2)
	# A entrada anima véus, retábulo e placas quando o vale termina de montar (a tela
	# de carregamento some logo depois). Na recarga da troca de estilo, sem animação.
	if lobby_em_video:
		# Sem vale para esperar: o retábulo entra já, enquanto a tela de carregamento some.
		if not options_open:
			_preparar_entrada()
			_entrada.call_deferred()
	else:
		if $Cenario.construido:
			_start_flyover()
		else:
			$Cenario.pronto.connect(_start_flyover, CONNECT_ONE_SHOT)
		if not $Cenario.construido and not options_open:
			_preparar_entrada()
			$Cenario.pronto.connect(_entrada, CONNECT_ONE_SHOT)
	print("OPENING_READY: audio compartilhado e abertura 3D · estilo=%s" % Estilo.modo)
	if _mapa_solicitado:
		_abrir_mapa_apos_carga.call_deferred()


func _abrir_mapa_apos_carga() -> void:
	while not $Cenario.construido:
		await get_tree().process_frame
	_open_map()

func _process(delta: float) -> void:
	_vigiar_testador()
	if lobby_em_video:
		# Sem câmera para mover: só as falas da travessia andam, com o tempo delas.
		if line_index >= 0:
			line_time -= delta
			if line_bar:
				line_bar.value = clampf(line_time / line_total, 0.0, 1.0)
			if line_time <= 0:
				_next_line()
		return
	if not $Cenario.construido:
		return
	if map_open:
		camera.position = map_target + Vector3(0, 3000, 0)
		camera_target = map_target
		camera.look_at(map_target, Vector3(0, 0, -1))
		_position_map_markers()
		return
	elapsed += delta
	var target := _flyover_target(0.0)
	var eye := _flyover_eye(0.0)
	var modo := "travessia" if line_index >= 0 else ("voo" if flyover_active else "parado")
	if modo != _modo_camera and _modo_camera != "":
		_chegada = 0.0
		_chegada_olho = camera.position
		_chegada_alvo = camera_target
	_modo_camera = modo
	if line_index >= 0:
		var phase := mini(line_index / 3, 2)
		eye = [Vector3(-110, 65, 55), Vector3(-76, 35, 43), Vector3(75, 48, 75)][phase]
		target = [Vector3(-30, 0, 0), Vector3(-20, 1, -20), Vector3(10, 1, 10)][phase]
		line_time -= delta
		if line_bar:
			line_bar.value = clampf(line_time / line_total, 0.0, 1.0)
		if line_time <= 0:
			_next_line()
		camera.position = eye + Vector3(sin(elapsed * 0.08) * 1.2, 0, cos(elapsed * 0.08))
		camera_target = target
	else:
		if flyover_active:
			var progress := fposmod(elapsed / FLYOVER_SECONDS, 1.0)
			eye = _flyover_eye(progress)
			target = _flyover_target(progress)
		_chegada = minf(1.0, _chegada + delta / CHEGADA_SEGUNDOS)
		var peso := smoothstep(0.0, 1.0, _chegada)
		camera.position = _chegada_olho.lerp(eye, peso)
		camera_target = _chegada_alvo.lerp(target, peso)
	camera.look_at(camera_target)
	if line_index < 0:
		_frame_flyover()

## A volta curva permite seguir olhando na direcao do movimento, sem dar marcha
## a re com o olhar preso na praca. O outro lado da curva revela as casas na volta.
func _flyover_route(progress: float) -> Vector3:
	var pier: Vector3 = $Cenario.ancoras.get("Pier", Vector3.ZERO)
	var praca: Vector3 = $Cenario.ancoras.get("Praça", pier)
	var direction := praca - pier
	direction.y = 0.0
	var lateral := direction.normalized().cross(Vector3.UP) if direction.length_squared() > 0.001 else Vector3.RIGHT
	var angle := progress * TAU
	var route := (pier + praca) * 0.5 - (praca - pier) * cos(angle) * 0.5
	return route + lateral * sin(angle) * LATERAL_SOBREVOO / $Cenario.get_meters_per_unit()


func _flyover_direction(progress: float) -> Vector3:
	var direction := _flyover_route(progress + 0.001) - _flyover_route(progress - 0.001)
	direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.000001 else Vector3.FORWARD


func _flyover_eye(progress: float) -> Vector3:
	if not _trajeto_olho.is_empty():
		return _catmull_rom(_trajeto_olho, progress)
	var eye := _flyover_route(progress)
	# A altura segue o terreno; o enquadramento fica na altura das copas e telhados.
	eye.y = $Cenario.ground_height_at(eye) + ALTURA_SOBREVOO / $Cenario.get_meters_per_unit()
	return eye


func _flyover_target(progress: float) -> Vector3:
	if not _trajeto_alvo.is_empty():
		return _catmull_rom(_trajeto_alvo, progress)
	var scale_m: float = $Cenario.get_meters_per_unit()
	var eye := _flyover_eye(progress)
	var target := eye + _flyover_direction(progress) * OLHAR_ADIANTE / scale_m
	# Uma inclinacao leve mostra fachadas e arvores, em vez de mirar o chao da praca.
	target.y = maxf(eye.y - 5.0 / scale_m, $Cenario.ground_height_at(target) + 4.0 / scale_m)
	return target


## O sobrevoo em vídeo numa camada atrás do retábulo, cobrindo a tela (ver VIDEO_LOBBY).
func _montar_video_do_lobby() -> void:
	var camada := CanvasLayer.new()
	camada.name = "VideoDoLobby"
	camada.layer = -1
	add_child(camada)
	var fundo := Control.new()
	fundo.name = "Fundo"
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(fundo)
	TelaCarregamento.video_em_laco(fundo, VIDEO_LOBBY)
	_video_lobby = fundo.get_node_or_null("Video/Player") as VideoStreamPlayer
	_aplicar_video_do_lobby()


## "Sobrevoo" desligado em AJUSTAR → Cenário: o vídeo para no quadro, como a câmera parava.
func _aplicar_video_do_lobby() -> void:
	if _video_lobby != null:
		_video_lobby.paused = not flyover_active


func _start_flyover() -> void:
	_carregar_trajeto()
	elapsed = 0.0
	_chegada = 1.0
	camera.position = _flyover_eye(0.0)
	camera_target = _flyover_target(0.0)
	_frame_flyover()


## O "tique" de madeira quando o foco chega a um botão; calado sob a tela de carregamento.
func _tique_de_foco() -> void:
	if _som_liberado:
		Audio.efeito("ui_hover")


func _iniciar_som_do_menu() -> void:
	_som_liberado = true
	# Com a travessia já em curso, a música dela continua.
	if line_index < 0:
		Audio.tocar_musica(Audio.obter_caminho_musica_menu())
	Audio.iniciar_ambiente_menu()
	Atualizacao.verificar()


## Lê o trajeto planejado e confere se ele é deste vale (escala e âncoras de algum dos
## dois estilos). Se não for, deixa as amostras vazias e o voo cai na elipse antiga.
func _carregar_trajeto() -> void:
	_trajeto_olho = PackedVector3Array()
	_trajeto_alvo = PackedVector3Array()
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(TRAJETO_SOBREVOO))
	if not dados is Dictionary or int(dados.get("versao", 0)) != 1:
		push_warning("Sobrevoo: %s ilegível; o voo volta à elipse antiga." % TRAJETO_SOBREVOO)
		return
	if not is_equal_approx(float(dados.get("metros_por_unidade", 0.0)), $Cenario.get_meters_per_unit()) or not _ancoras_do_trajeto_conferem(dados):
		push_warning("Sobrevoo: o trajeto gravado é de outro vale (escala ou âncoras mudaram). Replaneje com tools/prototipo_3d/sobrevoo/planejar.py; até lá, o voo volta à elipse antiga.")
		return
	var olho := PackedVector3Array()
	var alvo := PackedVector3Array()
	for p in dados.get("olho", []):
		olho.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
	for p in dados.get("alvo", []):
		alvo.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
	if olho.size() < 4 or olho.size() != alvo.size() or olho.size() != int(dados.get("amostras", 0)):
		push_warning("Sobrevoo: amostras inconsistentes em %s; o voo volta à elipse antiga." % TRAJETO_SOBREVOO)
		return
	_trajeto_olho = olho
	_trajeto_alvo = alvo


func _ancoras_do_trajeto_conferem(dados: Dictionary) -> bool:
	var pier: Vector3 = $Cenario.ancoras.get("Pier", Vector3.INF)
	var praca: Vector3 = $Cenario.ancoras.get("Praça", Vector3.INF)
	var por_estilo: Dictionary = dados.get("ancoras_por_estilo", {})
	for estilo in por_estilo:
		var anc: Dictionary = por_estilo[estilo]
		var p: Array = anc.get("pier", [])
		var q: Array = anc.get("praca", [])
		if p.size() == 3 and q.size() == 3 \
				and pier.distance_to(Vector3(float(p[0]), float(p[1]), float(p[2]))) <= TOLERANCIA_ANCORA_U \
				and praca.distance_to(Vector3(float(q[0]), float(q[1]), float(q[2]))) <= TOLERANCIA_ANCORA_U:
			return true
	return false


## Catmull-Rom uniforme periódica: a amostra i vale no progresso i/N e a N-ésima volta à
## 0, então o ciclo fecha sem emenda. É a mesma conta do planejador e do avaliador
## (tools/prototipo_3d/sobrevoo/geometria.gd).
func _catmull_rom(amostras: PackedVector3Array, progress: float) -> Vector3:
	var n := amostras.size()
	var u := fposmod(progress, 1.0) * n
	var i := floori(u)
	var t := u - i
	i = posmod(i, n)
	return amostras[i].cubic_interpolate(amostras[(i + 1) % n], amostras[(i - 1 + n) % n], amostras[(i + 2) % n], t)


## O retabulo cobre a esquerda. Corrige o eixo optico para que o olhar adiante
## apareca no terco direito, ajustando o angulo a largura real da janela.
func _frame_flyover() -> void:
	camera.look_at(camera_target)
	var tela := camera.get_viewport().get_visible_rect().size
	var aspecto := tela.x / maxf(tela.y, 1.0)
	var meia_largura := tan(deg_to_rad(camera.fov) * 0.5)
	if camera.keep_aspect == Camera3D.KEEP_HEIGHT:
		meia_largura *= aspecto
	var angulo := atan((ENQUADRAMENTO_SOBREVOO * 2.0 - 1.0) * meia_largura)
	camera.rotate_object_local(Vector3.UP, angulo)


func _load_visual_preference() -> void:
	var preferences := ConfigFile.new()
	if preferences.load(VISUAL_PREFERENCES) == OK:
		flyover_active = bool(preferences.get_value("menu", "sobrevoo", true))
		menu_font_option = PainelAjustes.ler_fonte_menu(preferences)


## O fundo do painel é a moldura de talha; o stylebox só guarda as margens de sempre.
func _estilo_vazio() -> StyleBoxEmpty:
	var vazio := StyleBoxEmpty.new()
	vazio.content_margin_left = 28
	vazio.content_margin_right = 28
	vazio.content_margin_top = 22
	vazio.content_margin_bottom = 22
	return vazio


## A camada de "luz de pintura" da identidade, entre o vale 3D e o retábulo: véus que
## seguem a luz do dia, vinheta, o almanaque
## no canto de baixo, o fio de ouro na base, as faixas de cinema da travessia e o véu
## dos modais. Tudo com o mouse desligado: decoração nunca pega clique.
func _montar_decoracao(layer: CanvasLayer) -> void:
	decoracao = Control.new()
	decoracao.name = "Decoracao"
	decoracao.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	decoracao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(decoracao)
	veu_vertical = Identidade.veu(Color(0.04, 0.035, 0.023), {0.0: 0.5, 0.12: 0.2, 0.24: 0.0, 0.72: 0.0, 0.88: 0.4, 1.0: 0.62})
	veu_vertical.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	decoracao.add_child(veu_vertical)
	veu_esquerdo = Identidade.veu(Color(0.04, 0.031, 0.023), {0.0: 0.55, 0.68: 0.3, 1.0: 0.0}, true)
	veu_esquerdo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veu_esquerdo.anchor_right = 0.594
	decoracao.add_child(veu_esquerdo)
	var vinheta := Identidade.vinheta(Vector2(0.62, 0.5), 0.36)
	vinheta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	decoracao.add_child(vinheta)
	# Sombra difusa atrás do almanaque: o texto fica legível sobre o mar claro.
	# Sem borrão escuro atrás: com frase curta ele aparecia como mancha à esquerda do
	# rótulo. A leitura sobre o cenário vem da sombra no próprio texto.
	bloco_almanaque = VBoxContainer.new()
	bloco_almanaque.alignment = BoxContainer.ALIGNMENT_END
	bloco_almanaque.add_theme_constant_override("separation", 9)
	bloco_almanaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloco_almanaque.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	bloco_almanaque.offset_left = -480.0
	bloco_almanaque.offset_right = -56.0
	bloco_almanaque.offset_top = -148.0
	bloco_almanaque.offset_bottom = -44.0
	decoracao.add_child(bloco_almanaque)
	var linha_rotulo := HBoxContainer.new()
	linha_rotulo.alignment = BoxContainer.ALIGNMENT_END
	linha_rotulo.add_theme_constant_override("separation", 10)
	linha_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bloco_almanaque.add_child(linha_rotulo)
	linha_rotulo.add_child(Identidade.losango())
	rotulo_almanaque = Identidade.rotulo("Do almanaque")
	rotulo_almanaque.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	Identidade.sombra_texto(rotulo_almanaque)
	linha_rotulo.add_child(rotulo_almanaque)
	nota_almanaque = Label.new()
	nota_almanaque.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	nota_almanaque.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota_almanaque.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	nota_almanaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nota_almanaque.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_ITALICO, 500))
	nota_almanaque.add_theme_font_size_override("font_size", 21)
	nota_almanaque.add_theme_color_override("font_color", Identidade.TEXTO)
	nota_almanaque.add_theme_constant_override("line_spacing", 0)
	Identidade.sombra_texto(nota_almanaque)
	bloco_almanaque.add_child(nota_almanaque)
	_indice_nota = Time.get_ticks_msec() % Identidade.NOTAS_DIA.size()
	_atualizar_almanaque(true)
	var relogio_nota := Timer.new()
	relogio_nota.wait_time = 10.0
	relogio_nota.autostart = true
	relogio_nota.timeout.connect(_proxima_nota)
	decoracao.add_child(relogio_nota)
	# Faixas de cinema da travessia e o fio de ouro da base (o mesmo da carga).
	faixa_cima = ColorRect.new()
	faixa_cima.color = Color(0.02, 0.016, 0.012)
	faixa_cima.set_anchors_preset(Control.PRESET_TOP_WIDE)
	faixa_cima.offset_bottom = 30.0
	faixa_cima.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faixa_cima.visible = false
	decoracao.add_child(faixa_cima)
	faixa_baixo = ColorRect.new()
	faixa_baixo.color = Color(0.02, 0.016, 0.012)
	faixa_baixo.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	faixa_baixo.offset_top = -30.0
	faixa_baixo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faixa_baixo.visible = false
	decoracao.add_child(faixa_baixo)
	fio_base = Identidade.fio(decoracao)
	fio_base.value = 1.0
	fio_base.modulate.a = 0.45
	veu_modal = ColorRect.new()
	veu_modal.color = Color(0.02, 0.016, 0.012)
	veu_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veu_modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veu_modal.modulate.a = 0.0
	decoracao.add_child(veu_modal)


## A cada hora do vale: os véus pesam conforme a luz (mais fortes contra o céu claro do
## meio-dia) e a virada dia/noite troca o caderno do almanaque — pela
## mesma regra (eh_noite) que escolhe a capa da tela de carregamento.
func _ao_mudar_hora(_hora: float) -> void:
	var luz := Dia.luz_do_dia()
	veu_vertical.modulate.a = lerpf(0.55, 1.0, luz)
	veu_esquerdo.modulate.a = lerpf(0.55, 1.0, luz)
	if Dia.eh_noite() != _era_noite:
		_era_noite = Dia.eh_noite()
		_atualizar_almanaque()


func _notas_atuais() -> Array:
	return Identidade.NOTAS_NOITE if _era_noite else Identidade.NOTAS_DIA


## Troca o caderno (Do almanaque ↔ Dizem no vale) e mostra a nota da vez. Os textos
## ficam em português nas listas e são traduzidos na hora, para acompanhar o idioma.
func _atualizar_almanaque(imediato := false) -> void:
	rotulo_almanaque.text = tr("Dizem no vale") if _era_noite else tr("Do almanaque")
	var notas := _notas_atuais()
	_indice_nota = _indice_nota % notas.size()
	if imediato:
		nota_almanaque.text = tr(notas[_indice_nota])
		return
	_trocar_nota(tr(notas[_indice_nota]))


func _proxima_nota() -> void:
	var notas := _notas_atuais()
	_indice_nota = (_indice_nota + 1) % notas.size()
	_trocar_nota(tr(notas[_indice_nota]))


func _trocar_nota(texto: String) -> void:
	if _tween_nota:
		_tween_nota.kill()
	_tween_nota = nota_almanaque.create_tween()
	_tween_nota.tween_property(nota_almanaque, "modulate:a", 0.0, 0.35)
	_tween_nota.tween_callback(func() -> void: nota_almanaque.text = texto)
	_tween_nota.tween_property(nota_almanaque, "modulate:a", 1.0, 0.6)


## Modo da decoração: "home" (tudo aceso), "modal" (véu escuro sobre o vale), "mapa"
## (decoração desligada) e "travessia" (faixas de cinema, sem almanaque nem véu lateral;
## o fio de ouro vira o tempo da fala).
func _decoracao_modo(modo: String) -> void:
	if decoracao == null:
		return
	var travessia := modo == "travessia"
	decoracao.visible = modo != "mapa"
	veu_esquerdo.visible = not travessia
	bloco_almanaque.visible = modo == "home"
	faixa_cima.visible = travessia
	faixa_baixo.visible = travessia
	fio_base.modulate.a = 1.0 if travessia else 0.45
	if not travessia:
		fio_base.value = 1.0
	var alvo := 0.42 if modo == "modal" else 0.0
	if _tween_veu_modal:
		_tween_veu_modal.kill()
	_tween_veu_modal = veu_modal.create_tween()
	_tween_veu_modal.tween_property(veu_modal, "modulate:a", alvo, 0.2)


func _preparar_entrada() -> void:
	decoracao.modulate.a = 0.0
	panel.modulate.a = 0.0
	for peca in moldura_nodes:
		peca.modulate.a = 0.0


## Véus e retábulo surgem, e as placas entram em escada. Roda uma vez, disparada por
## Cenario.pronto; se o jogador já navegou (teclado sob a carga), só assenta os finais.
func _entrada() -> void:
	if options_open or modal_open or map_open or line_index >= 0 or _tween_entrada != null:
		_aplicar_entrada_final()
		return
	_tween_entrada = create_tween().set_parallel()
	_tween_entrada.tween_property(decoracao, "modulate:a", 1.0, 0.8)
	_tween_entrada.tween_property(panel, "modulate:a", 1.0, 0.45).set_delay(0.1)
	for peca in moldura_nodes:
		_tween_entrada.tween_property(peca, "modulate:a", 1.0, 0.45).set_delay(0.1)
	var atraso := 0.35
	for filho in content.get_children():
		if filho is Control:
			filho.modulate.a = 0.0
			_tween_entrada.tween_property(filho, "modulate:a", 1.0, 0.25).set_delay(atraso)
			atraso += 0.06
	_tween_entrada.set_parallel(false)
	_tween_entrada.tween_callback(func() -> void: _tween_entrada = null)


func _aplicar_entrada_final() -> void:
	decoracao.modulate.a = 1.0
	panel.modulate.a = 1.0
	for peca in moldura_nodes:
		peca.modulate.a = 1.0


func _notification(what: int) -> void:
	# Troca de idioma com o menu aberto: almanaque e dica do relógio se refazem.
	if what == NOTIFICATION_TRANSLATION_CHANGED and nota_almanaque != null:
		_atualizar_almanaque(true)
		if clock_hint != null:
			_refresh_clock_hint()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if ajustes.ajuda_aberta() and event.keycode == KEY_ESCAPE:
			_close_help()
		elif line_index >= 0:
			if event.keycode == KEY_ESCAPE:
				_start_game()
			elif event.keycode in [KEY_ENTER, KEY_SPACE, KEY_E]:
				_next_line()
		elif history_open and event.keycode in [KEY_LEFT, KEY_RIGHT]:
			_press_history_arrow(1 if event.keycode == KEY_RIGHT else 0)
		elif event.keycode == KEY_ESCAPE:
			_voltar_home()


func _unhandled_input(event: InputEvent) -> void:
	# Clique fora de um modal (fora do painel e dos botões do canto) fecha e volta ao menu.
	if modal_open and not ajustes.ajuda_aberta() and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Audio.efeito("ui_voltar")
		_voltar_home()
		return
	if not map_open:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_stop_map_tween()
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(30.0, camera.size * 0.78)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(map_full_size, camera.size * 1.28)
		_limit_map_target()
	if event is InputEventMouseMotion and (event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT)):
		_stop_map_tween()
		var meters_per_pixel := camera.size / maxf(1.0, get_viewport().get_visible_rect().size.y)
		map_target.x -= event.relative.x * meters_per_pixel
		map_target.z -= event.relative.y * meters_per_pixel
		_limit_map_target()


func _limit_map_target() -> void:
	map_target = _clamped_map_target(map_target, camera.size)


## Centro da vista mais próximo de `target` que não mostra nada fora do quadro do mapa
## com a câmera de tamanho `view_size`.
func _clamped_map_target(target: Vector3, view_size: float) -> Vector3:
	var frame: Rect2 = $Cenario.get_map_frame()
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var half_width := view_size * aspect * 0.5
	var half_height := view_size * 0.5
	var min_x := frame.position.x + half_width
	var max_x := frame.end.x - half_width
	var min_z := frame.position.y + half_height
	var max_z := frame.end.y - half_height
	target.x = clampf(target.x, min_x, max_x) if min_x <= max_x else frame.get_center().x
	target.z = clampf(target.z, min_z, max_z) if min_z <= max_z else frame.get_center().y
	return target

func _clear() -> void:
	var saindo_do_mapa := map_open
	_close_help()
	if _tween_entrada:
		_tween_entrada.kill()
		_tween_entrada = null
		_aplicar_entrada_final()
	_decoracao_modo("home")
	history_open = false
	map_open = false
	modal_open = false
	_set_home_corner(false)
	if map_icon:
		map_icon.definir(false)
	options_open = false
	if ajustes_icon:
		ajustes_icon.definir(false)
	camera.environment = null
	if map_marker_root:
		map_marker_root.queue_free()
		map_marker_root = null
	for node in map_corner_nodes:
		node.queue_free()
	map_corner_nodes.clear()
	_stop_map_tween()
	if saindo_do_mapa:
		_restore_flyover_view()
	# O painel PERSONAGENS vive na camada (não em content): liberado aqui.
	if is_instance_valid(painel_personagens):
		painel_personagens.queue_free()
	painel_personagens = null
	panel.visible = true
	map_markers.clear()
	_place_panel(false)
	ui_parent = content
	content.add_theme_constant_override("separation", 12)
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func _place_panel(centered: bool) -> void:
	panel.set_meta("sem_moldura", false)
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.custom_minimum_size = Vector2(440, 640)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER if centered else Control.PRESET_TOP_LEFT)
	panel.offset_left = -220 if centered else 36
	panel.offset_right = 220 if centered else 476
	panel.offset_top = -320 if centered else 32
	panel.offset_bottom = 320 if centered else 672
	Tela.vincular_componente(panel, "menu", Vector2(0.5, 0.5) if centered else Vector2.ZERO)

## Modal centrado de tamanho fixo (histórico, ajustes): não muda entre páginas. Com `abraca`, a
## altura de `modal_size` é só o mínimo: o modal tem a altura do que há dentro e cresce para os dois
## lados a partir do centro, sem faixa vazia embaixo (#214).
func _place_modal(modal_size: Vector2, componente := "menu", abraca := false) -> void:
	_place_panel(true)
	_decoracao_modo("modal")
	modal_open = true
	if abraca:
		panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = modal_size
	panel.offset_left = -modal_size.x * 0.5
	panel.offset_right = modal_size.x * 0.5
	panel.offset_top = -modal_size.y * 0.5
	panel.offset_bottom = modal_size.y * 0.5
	Tela.vincular_componente(panel, componente, Vector2(0.5, 0.5))

func _menu_theme() -> Theme:
	return TemaMenu.criar(MENU_FONTS[menu_font_option])


## Botões redondos do canto superior direito (som, relógio): ver botao_canto.gd.
## Devolve [botão, rótulo da dica].
func _corner_button(layer: CanvasLayer, posicao: int, icon: Control, lado_icone := 24.0) -> Array:
	var parts := BotaoCanto.criar(layer, posicao, icon, lado_icone)
	(parts[0] as Button).toggle_mode = true
	return parts


## HOME no alto da coluna do canto (mesma posição no jogo): de qualquer tela do menu
## (modal, mapa, travessia) volta direto ao menu inicial, sem carregamento.
func _create_home_button(layer: CanvasLayer) -> void:
	home_icon = HudIcon.new().configurar("casa")
	var parts := BotaoCanto.criar(layer, 0, home_icon)
	home_corner = parts[0]
	(parts[1] as Label).text = "Home"
	home_corner.pressed.connect(func() -> void:
		if starting:
			return
		Audio.efeito("ui_confirmar")
		_voltar_home())


## AJUSTAR na coluna do canto, logo abaixo de HOME (mesma posição no jogo): abre os
## ajustes; aberto, fica dourado e fecha de volta para a Home.
func _create_ajustes_button(layer: CanvasLayer) -> void:
	ajustes_icon = HudIcon.new().configurar("ajustes")
	var parts := BotaoCanto.criar(layer, 1, ajustes_icon)
	(parts[1] as Label).text = tr("Ajustes")
	(parts[0] as Button).pressed.connect(func() -> void:
		if starting:
			return
		Audio.efeito("ui_confirmar")
		if options_open:
			_home()
		else:
			_options())


## MAPA na coluna do canto, abaixo do relógio (mesma posição no jogo): abre o mapa do
## vale; com o mapa aberto fica dourado e fecha de volta para a Home.
func _create_map_button(layer: CanvasLayer) -> void:
	map_icon = HudIcon.new().configurar("mapa")
	var parts := BotaoCanto.criar(layer, 4, map_icon)
	(parts[1] as Label).text = tr("Mapa")
	(parts[0] as Button).pressed.connect(func() -> void:
		if starting:
			return
		Audio.efeito("ui_confirmar")
		if map_open:
			_home()
		else:
			_open_map())


## TELA CHEIA na coluna do canto, abaixo do mapa: alterna tela cheia e janela, como o
## F11 (o autoload `Tela`), e a dica ensina o atalho. Dourado em tela cheia.
func _create_tela_button(layer: CanvasLayer) -> void:
	BotaoCanto.criar_tela_cheia(layer, 5, func() -> bool: return not starting)


## Na Home a casa fica dourada e não responde (já se está lá); em qualquer outra tela
## (modal, mapa, travessia) volta a ser clicável.
func _set_home_corner(at_home: bool) -> void:
	if home_corner == null:
		return
	home_icon.definir(at_home)
	home_corner.disabled = at_home
	home_corner.mouse_default_cursor_shape = Control.CURSOR_ARROW if at_home else Control.CURSOR_POINTING_HAND


func _create_quick_mute(layer: CanvasLayer) -> void:
	var audio_icon := AudioToggleIcon.new()
	audio_icon.set_active(Audio.som_ativo)
	var parts := _corner_button(layer, 2, audio_icon)
	var quick_mute: Button = parts[0]
	var hint_label: Label = parts[1]
	quick_mute.button_pressed = Audio.som_ativo
	hint_label.text = "Desativar" if Audio.som_ativo else "Ativar"
	quick_mute.toggled.connect(func(active: bool):
		Audio.definir_som_ativo(active)
		Audio.efeito("ui_confirmar")
		audio_icon.set_active(active)
		hint_label.text = "Desativar" if active else "Ativar")


## Relógio do menu: os ponteiros acompanham a hora do vale, que corre desde o começo
## do dia na velocidade de Passagem do tempo; o botão pausa e retoma o dia.
func _create_clock(layer: CanvasLayer) -> void:
	var clock_icon := ClockIcon.new()
	clock_icon.set_running(clock_running)
	var parts := _corner_button(layer, 3, clock_icon, 28.0)
	var clock_button: Button = parts[0]
	var hint_label: Label = parts[1]
	clock_button.button_pressed = clock_running
	clock_hint = hint_label
	_refresh_clock_hint()
	# Método (não lambda): o Godot desconecta sozinho quando a cena do menu é liberada.
	Dia.hora_mudou.connect(_refresh_clock_hint)
	clock_button.toggled.connect(func(active: bool) -> void:
		Audio.efeito("ui_confirmar")
		clock_running = active
		Dia.pausado = not active
		clock_icon.set_running(active)
		_refresh_clock_hint())


func _refresh_clock_hint(_hora: float = 0.0) -> void:
	clock_hint.text = "%s · %s" % [Dia.texto_hora(), tr("Pausar") if clock_running else tr("Retomar")]

func _create_version_link() -> void:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)
	var filete := Identidade.filete_centrado()
	filete.custom_minimum_size = Vector2(264, 1)
	filete.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(filete)
	version_link = Button.new()
	version_link.text = version_text
	version_link.tooltip_text = "Ver o histórico"
	version_link.flat = true
	version_link.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	version_link.add_theme_font_override("font", Identidade.fonte_numeros(600))
	version_link.add_theme_font_size_override("font_size", 18)
	version_link.add_theme_color_override("font_color", Color("c9b98f"))
	version_link.add_theme_color_override("font_hover_color", Identidade.CREME)
	version_link.add_theme_color_override("font_focus_color", Identidade.CREME)
	version_link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	version_link.custom_minimum_size.y = 26
	content.add_child(version_link)
	version_link.pressed.connect(_open_history)
	linha_atualizacao = Button.new()
	linha_atualizacao.flat = true
	linha_atualizacao.add_theme_font_override("font", Identidade.fonte_numeros(600))
	linha_atualizacao.add_theme_font_size_override("font_size", 15)
	linha_atualizacao.add_theme_color_override("font_color", Identidade.OURO)
	linha_atualizacao.add_theme_color_override("font_hover_color", Identidade.CREME)
	linha_atualizacao.add_theme_color_override("font_focus_color", Identidade.CREME)
	linha_atualizacao.add_theme_color_override("font_disabled_color", Color("c9b98f"))
	linha_atualizacao.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	linha_atualizacao.custom_minimum_size.y = 24
	linha_atualizacao.mouse_entered.connect(func():
		if not linha_atualizacao.disabled:
			Audio.efeito("ui_hover"))
	linha_atualizacao.pressed.connect(_acionar_atualizacao)
	content.add_child(linha_atualizacao)
	_atualizar_oferta()


## A linha embaixo da versão diz em que pé está a atualização. Só aparece quando há
## uma build nova no site; durante o download e a instalação, não aceita clique.
func _atualizar_oferta() -> void:
	if linha_atualizacao == null or not is_instance_valid(linha_atualizacao):
		return
	# Build do evento (Tripothon): fixa, sem consulta nem oferta; a linha fica à vista,
	# apagada e sem clique, dizendo por que não atualiza.
	if Atualizacao.edicao_estatica():
		linha_atualizacao.visible = true
		linha_atualizacao.text = tr("Edição Tripothon · atualização desativada")
		linha_atualizacao.tooltip_text = ""
		linha_atualizacao.disabled = true
		linha_atualizacao.mouse_default_cursor_shape = Control.CURSOR_ARROW
		return
	var E := Atualizacao.Estado
	var estado: int = Atualizacao.estado
	var build := Atualizacao.build_nova()
	var texto := ""
	if estado == E.DISPONIVEL:
		texto = (tr("Nova versão: Build %d · Atualizar") if Atualizacao.instala_sozinho() else tr("Nova versão: Build %d · Baixar no site")) % build
	elif estado == E.BAIXANDO:
		texto = tr("Baixando a Build %d… %d%%") % [build, int(Atualizacao.progresso * 100.0)]
	elif estado == E.CONFERINDO:
		texto = tr("Conferindo o arquivo…")
	elif estado == E.INSTALANDO:
		texto = tr("Instalando a Build %d…") % build
	elif estado == E.PRONTA:
		texto = tr("Build %d instalada · Reiniciar o jogo") % build
	elif estado == E.FALHOU:
		# Falha que tentar de novo não resolve (build grande demais, sem espaço, #231): o clique abre o site.
		texto = tr("Não deu para atualizar sozinho · Baixar no site") if Atualizacao.so_pelo_site else tr("A atualização falhou · Tentar de novo")
	linha_atualizacao.visible = not texto.is_empty()
	linha_atualizacao.text = texto
	linha_atualizacao.tooltip_text = Atualizacao.erro if estado == E.FALHOU else ""
	linha_atualizacao.disabled = estado in [E.BAIXANDO, E.CONFERINDO, E.INSTALANDO]
	# Sem clique, sem mãozinha: a seta diz que ali não há o que apertar.
	linha_atualizacao.mouse_default_cursor_shape = Control.CURSOR_ARROW if linha_atualizacao.disabled else Control.CURSOR_POINTING_HAND


func _acionar_atualizacao() -> void:
	Audio.efeito("ui_confirmar")
	if Atualizacao.estado == Atualizacao.Estado.PRONTA:
		Atualizacao.reiniciar()
	else:
		Atualizacao.atualizar()

func _label(text: String, size: int = 18) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 375 if ui_parent == content else 0
	label.add_theme_font_size_override("font_size", size)
	ui_parent.add_child(label)
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.mouse_entered.connect(func(): Audio.efeito("ui_hover"))
	button.focus_entered.connect(_tique_de_foco)
	button.pressed.connect(func():
		Audio.efeito("ui_confirmar")
		callback.call())
	ui_parent.add_child(button)
	return button

func _home() -> void:
	# Saindo da travessia, a voz some suave e a trilha do menu volta.
	if line_index >= 0:
		Audio.encerrar_travessia(true)
	else:
		Audio.parar_narracao()
	line_index = -1
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 55
	_clear()
	_marca()
	_placa("JOGAR", _vagas).grab_focus()
	_placa("EXPLORAR", _explorar)
	var teste := _placa("TESTAR", _teste_automatico)
	teste.tooltip_text = tr("O testador joga uma partida separada, e esta janela se fecha quando ela abrir. F8 encerra a sessão e volta ao menu.")
	if not TestadorApoios.ponte_instalada():
		teste.disabled = true
		teste.tooltip_text = tr("Disponível no projeto de desenvolvimento com Python instalado.")
	_placa("MODELOS", _abrir_personagens)
	_placa("SOBRE", _credits)
	_placa("SAIR", _confirm_exit, true)
	estado_testador = _label("", 13)
	estado_testador.hide()
	if not history_entries.is_empty():
		_create_version_link()
	_set_home_corner(true)


## O alto do retábulo: o logotipo em talha com um halo que respira, a linha do lugar e
## do ano entre filetes, o lema e o divisor de azulejo.
func _marca() -> void:
	var logo := TextureRect.new()
	logo.texture = load(Identidade.LOGO) as Texture2D
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(340, 98)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(logo)
	var halo := TextureRect.new()
	halo.texture = Identidade.brilho(Color(Identidade.OURO, 1.0), 128)
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.material = Identidade.aditivo()
	halo.show_behind_parent = true
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.set_anchors_preset(Control.PRESET_FULL_RECT)
	halo.offset_left = -30.0
	halo.offset_right = 30.0
	halo.offset_top = -22.0
	halo.offset_bottom = 22.0
	halo.modulate.a = 0.14
	logo.add_child(halo)
	var respira := halo.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	respira.tween_property(halo, "modulate:a", 0.2, 2.5)
	respira.tween_property(halo, "modulate:a", 0.1, 2.5)
	var lugar := HBoxContainer.new()
	lugar.add_theme_constant_override("separation", 10)
	lugar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(lugar)
	lugar.add_child(Identidade.filete(false))
	var nome := Identidade.rotulo("Bom Jesus dos Pobres · 1887", 14, Identidade.CREME)
	nome.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	lugar.add_child(nome)
	lugar.add_child(Identidade.filete(true))
	var lema := Label.new()
	lema.text = "Um vale cheio de histórias."
	lema.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lema.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lema.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_ITALICO, 500))
	lema.add_theme_font_size_override("font_size", 24)
	lema.add_theme_color_override("font_color", Color(Identidade.TEXTO, 0.9))
	content.add_child(lema)
	content.add_child(Identidade.divisor())


## Placa de ação do retábulo: Cinzel sobre laca chanfrada, com as rosas dos ventos
## girando no item em foco. Com `puxa_foco`, o mouse em cima já traz o foco — hover e
## foco viram um estado só, com um único marcador na tela (só na home; na confirmação
## de sair, passar o mouse por SAIR não pode roubar o Enter de CANCELAR).
func _placa(texto: String, acao: Callable, negativa := false, puxa_foco := true) -> Button:
	var placa := Button.new()
	placa.text = texto
	placa.theme_type_variation = &"BotaoCronicaNegativo" if negativa else &"BotaoCronica"
	placa.custom_minimum_size.y = TemaMenu.ALTURA_BOTAO
	content.add_child(placa)
	for lado in [false, true]:
		var suporte := Control.new()
		suporte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if lado:
			suporte.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			suporte.offset_left = -42.0
			suporte.offset_right = -16.0
		else:
			suporte.offset_left = 16.0
			suporte.offset_right = 42.0
		suporte.offset_top = 10.0
		suporte.offset_bottom = 36.0
		suporte.visible = false
		placa.add_child(suporte)
		var rosa := TextureRect.new()
		rosa.texture = load(Identidade.ROSA) as Texture2D
		rosa.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		rosa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rosa.size = Vector2(26, 26)
		rosa.pivot_offset = Vector2(13, 13)
		rosa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		suporte.add_child(rosa)
		var giro := rosa.create_tween().set_loops()
		giro.tween_property(rosa, "rotation", TAU * (-1.0 if lado else 1.0), 26.0).from(0.0)
		placa.focus_entered.connect(func() -> void: suporte.visible = true)
		placa.focus_exited.connect(func() -> void: suporte.visible = false)
	placa.focus_entered.connect(_tique_de_foco)
	if puxa_foco:
		placa.mouse_entered.connect(placa.grab_focus)
	else:
		placa.mouse_entered.connect(func() -> void: Audio.efeito("ui_hover"))
	placa.pressed.connect(func() -> void:
		Audio.efeito("ui_confirmar")
		acao.call())
	return placa

## O mapa usa a mesma camera a 3000 unidades. Guarda o quadro do voo para
## voltar direto a ele, sem interpolar a descida dessa altura ate a vila.
func _save_flyover_view() -> void:
	_camera_antes_do_mapa = camera.transform
	_alvo_antes_do_mapa = camera_target


func _restore_flyover_view() -> void:
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.transform = _camera_antes_do_mapa
	camera_target = _alvo_antes_do_mapa


func _open_map() -> void:
	if lobby_em_video:
		if starting:
			return
		starting = true
		mapa_apos_carga = true
		TelaCarregamento.trocar_cena(get_tree(), scene_file_path, _show_loading())
		return
	if not map_open:
		_save_flyover_view()
	_clear()
	_decoracao_modo("mapa")
	map_open = true
	panel.custom_minimum_size = Vector2(440, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 36
	panel.offset_right = 476
	panel.offset_top = 32
	panel.offset_bottom = 32
	_modal_header("Mapa do Vale", func() -> void: _mostrar_info_mapa(false),
		"%s · %s" % [$Cenario.get_region_title(), tr("1 unidade = %s m") % _formatar_escala($Cenario.get_meters_per_unit())])
	_label("N ↑ · roda: zoom · arrastar: mover", 14)
	var points_title := _label("Pontos de interesse", 16)
	points_title.add_theme_color_override("font_color", Color("e2c47f"))
	# Clicar num ponto desliza e aproxima o mapa até ele.
	var points := GridContainer.new()
	points.columns = 2
	points.add_theme_constant_override("h_separation", 8)
	points.add_theme_constant_override("v_separation", 6)
	content.add_child(points)
	for point: Array in _map_points():
		var button := Button.new()
		button.text = "● " + String(point[0])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 32)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		button.focus_mode = Control.FOCUS_NONE
		var destination: Vector3 = point[1]
		button.pressed.connect(func() -> void:
			Audio.efeito("ui_confirmar")
			_focus_map_marker(destination, true))
		points.add_child(button)
	# O mapa abre com o painel de informações à vista. O × do painel o esconde e deixa
	# um "?" no canto esquerdo, onde ele estava, que o traz de volta.
	map_icon.definir(true)
	var layer := panel.get_parent()
	var help_icon: Control = HudIcon.new().configurar("ajuda")
	var help_parts := BotaoCanto.criar(layer, 0, help_icon)
	map_help_button = help_parts[0]
	var help_hint: Label = help_parts[1]
	help_hint.text = tr("Mostrar informações")
	var help_corner := map_help_button.get_parent() as Control
	var help_tip := help_hint.get_parent() as Control
	# Do canto direito (coluna) para o esquerdo, fora da coluna que a escala refaz.
	help_corner.remove_from_group(BotaoCanto.GRUPO)
	var lado := help_corner.offset_right - help_corner.offset_left
	help_corner.anchor_left = 0.0
	help_corner.anchor_right = 0.0
	help_corner.offset_left = BotaoCanto.MARGEM
	help_corner.offset_right = BotaoCanto.MARGEM + lado
	help_tip.anchor_left = 0.0
	help_tip.anchor_right = 0.0
	help_tip.grow_horizontal = Control.GROW_DIRECTION_END
	help_tip.offset_left = BotaoCanto.MARGEM + lado + 10.0
	help_tip.offset_right = help_tip.offset_left
	map_help_button.pressed.connect(func() -> void:
		Audio.efeito("ui_confirmar")
		_mostrar_info_mapa(true))
	map_help_tip = help_tip
	map_corner_nodes.append(help_corner)
	map_corner_nodes.append(help_tip)
	_mostrar_info_mapa(true)
	var frame: Rect2 = $Cenario.get_map_frame()
	var center := frame.get_center()
	map_target = Vector3(center.x, 0, center.y)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# A câmera fica a 3000 unidades do chão. O nevoeiro do cenário apaga
	# quase toda a imagem nessa distância; só esta vista precisa vê-lo sem névoa.
	var scene_environment: Environment = get_world_3d().environment
	if scene_environment != null:
		camera.environment = scene_environment.duplicate() as Environment
		camera.environment.fog_enabled = false
	var aspect := get_viewport().get_visible_rect().size.aspect()
	# Usa o maior recorte 16:9 dentro do quadro do KML; a roda não afasta além dele.
	var size_by_width := frame.size.x / maxf(aspect, 0.5)
	if $Cenario.has_map_frame():
		map_full_size = minf(frame.size.y, size_by_width)
	else:
		map_full_size = maxf(frame.size.y, size_by_width)
	map_full_size = maxf(30.0, map_full_size)
	camera.size = map_full_size
	camera.position = map_target + Vector3(0, 3000, 0)
	camera_target = map_target
	camera.look_at(map_target, Vector3(0, 0, -1))
	_create_map_markers()


## Painel "Mapa do Vale" à vista, ou escondido com o "?" no lugar dele.
func _mostrar_info_mapa(visivel: bool) -> void:
	panel.visible = visivel
	if is_instance_valid(map_help_button):
		map_help_button.get_parent().visible = not visivel
	# A dica do "?" não pode ficar presa na tela quando ele some.
	if visivel and is_instance_valid(map_help_tip):
		map_help_tip.visible = false


func _create_map_markers() -> void:
	map_marker_root = Control.new()
	map_marker_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_marker_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.get_parent().add_child(map_marker_root)
	panel.get_parent().move_child(map_marker_root, 0)
	for point: Array in _map_points():
		_add_map_marker(point[0], point[1])
	_position_map_markers()


## Pontos de interesse e áreas do mapa como [nome traduzido, posição]; nomes repetidos
## ganham número (Rio 1, Rio 2).
func _map_points() -> Array:
	var points: Array = []
	var name_totals: Dictionary = {}
	var name_seen: Dictionary = {}
	for landmark: Dictionary in $Cenario.landmarks:
		var name: String = landmark["name"]
		name_totals[name] = int(name_totals.get(name, 0)) + 1
	for landmark: Dictionary in $Cenario.landmarks:
		var base_name: String = landmark["name"]
		var marker_name := tr(base_name)
		if int(name_totals[base_name]) > 1:
			name_seen[base_name] = int(name_seen.get(base_name, 0)) + 1
			marker_name = "%s %d" % [marker_name, name_seen[base_name]]
		points.append([marker_name, landmark["position"]])
	for area: Dictionary in $Cenario.areas:
		if area["name"] != "Praça":
			points.append([tr(area["name"]), area["position"]])
	return points


func _add_map_marker(label: String, position: Vector3) -> void:
	var marker := Button.new()
	marker.text = "● " + label
	marker.tooltip_text = tr("Centralizar em %s") % label
	marker.custom_minimum_size = Vector2(0, 26)
	marker.add_theme_font_size_override("font_size", 13)
	marker.pressed.connect(_focus_map_marker.bind(position, true))
	map_marker_root.add_child(marker)
	map_markers.append({"control": marker, "position": position})


## Centraliza e aproxima um ponto. Com `animate`, desliza e aproxima aos poucos.
func _focus_map_marker(position: Vector3, animate := false) -> void:
	var view_size := minf(camera.size, 420.0 / $Cenario.get_meters_per_unit())
	var target := _clamped_map_target(position, view_size)
	_stop_map_tween()
	if not animate:
		camera.size = view_size
		map_target = target
		return
	map_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	map_tween.tween_property(self, "map_target", target, 0.9)
	map_tween.tween_property(camera, "size", view_size, 0.9)


func _stop_map_tween() -> void:
	if map_tween and map_tween.is_valid():
		map_tween.kill()
	map_tween = null


func _position_map_markers() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	for entry: Dictionary in map_markers:
		var marker: Button = entry["control"]
		var projected := camera.unproject_position(entry["position"])
		var marker_size := marker.get_combined_minimum_size()
		marker.position = (projected + Vector2(5, -13)).clamp(Vector2.ZERO, (viewport_size - marker_size).max(Vector2.ZERO))
		marker.visible = projected.x > 0 and projected.y > 0 and projected.x < viewport_size.x and projected.y < viewport_size.y

func _open_history() -> void:
	if history_entries.is_empty():
		return
	history_index = 0
	_render_history()


## Entradas longas viram páginas extras, mantendo cada alteração inteira.
func _paginar_historico(entradas: Array) -> Array:
	var paginas: Array = []
	for entrada: Dictionary in entradas:
		var quantidade := 0
		for chave in ["mudancas", "mudancas_en", "mudancas_es", "mudancas_zh"]:
			quantidade = maxi(quantidade, entrada.get(chave, []).size())
		for inicio in range(0, maxi(1, quantidade), HISTORY_ROWS):
			var pagina := entrada.duplicate(true)
			for chave in ["mudancas", "mudancas_en", "mudancas_es", "mudancas_zh"]:
				if pagina.has(chave):
					pagina[chave] = entrada[chave].slice(inicio, inicio + HISTORY_ROWS)
			paginas.append(pagina)
	return paginas

## Tecla ← / →: o botão da seta aparece pressionado por um instante (como no clique)
## e só então a página muda.
func _press_history_arrow(index: int) -> void:
	if index >= history_buttons.size():
		return
	var button := history_buttons[index]
	if not is_instance_valid(button) or button.has_meta("pressionando"):
		return
	if button.disabled:
		# Já na primeira/última página: som de trava, sem mudar de página.
		Audio.efeito("ui_trava")
		return
	button.set_meta("pressionando", true)
	button.add_theme_stylebox_override("normal", button.get_theme_stylebox("pressed"))
	button.add_theme_stylebox_override("hover", button.get_theme_stylebox("pressed"))
	button.add_theme_color_override("font_color", button.get_theme_color("font_pressed_color"))
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(button) and history_open:
		_change_history(1 if index == 1 else -1)


## Troca de página (clique na seta ou tecla ← →), sempre com o mesmo som.
func _change_history(step: int) -> void:
	Audio.efeito("ui_hover")
	history_index = clampi(history_index + step, 0, history_entries.size() - 1)
	_render_history()

func _render_history() -> void:
	_clear()
	# Resumos em uma linha, até dez por página, sem área de rolagem.
	_place_modal(HISTORY_SIZE, "historico")
	history_open = true
	var entry: Dictionary = history_entries[history_index]
	# Sem foco em botão: as teclas ← → ficam livres para trocar de página.
	_modal_header("Histórico", _home, "O que mudou no vale a cada versão.")
	_label("%s · %s" % [entry.get("data", ""), IdiomaMenu.campo(entry, "estado")], 14)
	_label(str(IdiomaMenu.campo(entry, "titulo")), 20)
	var changes := VBoxContainer.new()
	changes.name = "MudancasHistorico"
	changes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	changes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	changes.add_theme_constant_override("separation", 4)
	content.add_child(changes)
	# Os termos entre *asteriscos* no historico_3d.json aparecem em dourado.
	for change in IdiomaMenu.campo(entry, "mudancas", []):
		var change_label := RichTextLabel.new()
		change_label.bbcode_enabled = true
		change_label.custom_minimum_size.y = 24
		change_label.scroll_active = false
		change_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		change_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var fonte := change_label.get_theme_font("normal_font")
		var tamanho := HISTORY_FONTE
		var texto_simples := "• " + str(change).replace("*", "")
		while tamanho > HISTORY_FONTE_MIN and fonte.get_string_size(texto_simples, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x > HISTORY_SIZE.x - 56:
			tamanho -= 1
		change_label.add_theme_font_size_override("normal_font_size", tamanho)
		change_label.add_theme_color_override("default_color", Color.WHITE)
		var parts := ("• " + str(change)).replace("[", "[lb]").split("*")
		for i in range(1, parts.size(), 2):
			parts[i] = "[color=#e2c47f]%s[/color]" % parts[i]
		change_label.text = "".join(parts)
		changes.add_child(change_label)
	# Setas pequenas, centradas junto do "N / M"; o chevron é desenhado (as setas ‹ › da
	# fonte ficavam fora do centro do botão).
	var navigation := HBoxContainer.new()
	navigation.alignment = BoxContainer.ALIGNMENT_CENTER
	navigation.add_theme_constant_override("separation", 14)
	content.add_child(navigation)
	var previous := _seta_historico(-1, "Página anterior", history_index == 0)
	navigation.add_child(previous)
	history_buttons = [previous]
	var position := Label.new()
	position.text = "%d / %d" % [history_index + 1, history_entries.size()]
	position.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	position.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	position.custom_minimum_size.x = 64
	position.add_theme_font_size_override("font_size", 16)
	navigation.add_child(position)
	var next := _seta_historico(1, "Próxima página", history_index == history_entries.size() - 1)
	navigation.add_child(next)
	history_buttons.append(next)
	# Clique numa seta desativada (primeira/última página) toca o som de trava.
	for arrow in history_buttons:
		arrow.gui_input.connect(func(event: InputEvent) -> void:
			if arrow.disabled and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				Audio.efeito("ui_trava"))

func _seta_historico(passo: int, dica: String, desativada: bool) -> Button:
	var botao := Button.new()
	botao.tooltip_text = dica
	botao.custom_minimum_size = HISTORY_SETA
	botao.disabled = desativada
	botao.pressed.connect(func(): _change_history(passo))
	var chevron := Control.new()
	chevron.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chevron.draw.connect(func() -> void:
		var centro := chevron.size * 0.5
		var cor := Color(1, 1, 1, 0.3) if botao.disabled else Color(Identidade.CREME, 0.92)
		var ponta := Vector2(4.0 * passo, 0)
		chevron.draw_polyline(PackedVector2Array([centro - ponta + Vector2(0, -6), centro + ponta, centro - ponta + Vector2(0, 6)]), cor, 1.8, true))
	botao.add_child(chevron)
	return botao


func _confirm_exit() -> void:
	_clear()
	Tela.vincular_componente(panel, "pergunta", Vector2.ZERO)
	_marca()
	var pergunta := Label.new()
	pergunta.text = "Sair do jogo?"
	pergunta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pergunta.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600, 3))
	pergunta.add_theme_font_size_override("font_size", 26)
	pergunta.add_theme_color_override("font_color", Identidade.CREME)
	content.add_child(pergunta)
	var frase := Label.new()
	frase.text = "Deseja encerrar Myths’ Valley?"
	frase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	frase.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_ITALICO, 500))
	frase.add_theme_font_size_override("font_size", 22)
	frase.add_theme_color_override("font_color", Identidade.TEXTO)
	content.add_child(frase)
	var folga := Control.new()
	folga.custom_minimum_size.y = 12
	content.add_child(folga)
	_placa("CANCELAR", _home, false, false).grab_focus()
	_placa("SAIR", func() -> void: get_tree().quit(), true, false)

## AJUSTAR (painel_ajustes.gd) no modal central. `tab`: o índice de PainelAjustes.ABAS (Geral, Sons, Cenário, Interface, Atalhos, Esforço).
func _options(tab: int = 0) -> void:
	_clear()
	_place_modal(PainelAjustes.TAMANHO, "ajustes")
	options_open = true
	ajustes_icon.definir(true)
	ajustes.tema = panel.theme
	ajustes.construir(content, panel.get_parent(), tab)


## Esc, clique fora e HOME: com PERSONAGENS aberto, o painel decide (pode pedir para
## confirmar ajustes não gravados) e emite `fechado` quando pode voltar à Home.
func _voltar_home() -> void:
	if is_instance_valid(painel_personagens):
		painel_personagens.pedir_fechar()
		return
	_home()


## PERSONAGENS: painel próprio (painel_personagens.gd) sobre a camada do menu, no
## padrão dos modais: Esc, × ou clique fora voltam à Home (_clear o libera).
func _abrir_personagens() -> void:
	_clear()
	_decoracao_modo("modal")
	modal_open = true
	panel.visible = false
	var painel := PainelPersonagens.new()
	painel.fechado.connect(_home)
	panel.get_parent().add_child(painel)
	painel.abrir(panel.theme)
	painel_personagens = painel


## Cabeçalho padrão dos modais (painel_ajustes.gd): título, subtítulo, × e divisor.
## AS TRÊS VAGAS (#7), por baixo da abertura. O `menu_inicial` do 2D não
## entra; entra a pergunta dele — "qual vaga?" — com a cara deste menu. Vaga
## vazia começa ali, com a travessia; vaga ocupada continua de onde parou, sem
## ela.
##
## CADA VAGA É UM CARTÃO: "No MENU de save, ao invés de abrir um combo embaixo
## para deletar o save, coloque o ícone dentro do próprio balão do save. Na
## esquerda pode colocar o ícone de editar o nome do save e deletar o save."
## E depois: "me confundi. O correto é no lado direito." Clicar no cartão
## continua a partida (ou começa, na vaga vazia). Dentro dele, à direita do
## texto, o lápis edita o nome da vaga (`Partida.renomear`) e a lixeira a apaga
## — no SEGUNDO clique, com o cartão dizendo o que se perde: vaga ocupada nunca
## é apagada num toque (ver `scripts/ui/slots_tela.gd` no 2D). Depois deles, a
## seta circular abre os PONTOS DE RESTAURAÇÃO da vaga
## (`pontos_de_restauracao.gd`) quando ela tem algum — inclusive vazia, depois
## de apagada, que é como apagar se desfaz.
const PontosDeRestauracao = preload("res://scripts/prototipo_3d/pontos_de_restauracao.gd")
var _confirmando_vaga := 0
## O ponto de restauração que pede o segundo clique, pelo caminho, ou "".
var _confirmando_ponto := ""

func _vagas() -> void:
	_clear()
	_place_modal(HISTORY_SIZE, "vagas")
	_confirmando_vaga = 0
	_modal_header("Vagas", _home, "Três partidas, cada uma inteira. Escolha onde jogar.")
	var primeiro: Button = null
	for slot in range(1, Salvamento.QUANTOS_SLOTS + 1):
		var cartao := _cartao_da_vaga(slot)
		if primeiro == null:
			primeiro = cartao
	primeiro.grab_focus()


## O nome que o cartão mostra: o que o jogador deu à vaga, ou o de quem joga.
func _nome_da_vaga(slot: int, resumo: Dictionary) -> String:
	var dado := Partida.nome_da_vaga(slot)
	return dado if dado != "" else str(resumo.get("nome", ""))


## O CARTÃO DE UMA VAGA: o botão inteiro continua (ou começa); dentro dele, o
## texto e, à direita, o lápis e a lixeira da vaga ocupada e a seta dos pontos.
func _cartao_da_vaga(slot: int) -> Button:
	var resumo := Salvamento.resumo(slot)
	var ocupada := bool(resumo.get("existe", false))
	var nome := _nome_da_vaga(slot, resumo)
	var cartao := _button("", func(): _ao_tocar_a_vaga(slot, ocupada))
	cartao.name = "Vaga%d" % slot
	cartao.custom_minimum_size.y = 52
	var linha := HBoxContainer.new()
	linha.name = "Linha"
	linha.set_anchors_preset(Control.PRESET_FULL_RECT)
	linha.offset_left = 6.0
	linha.offset_right = -6.0
	linha.add_theme_constant_override("separation", 2)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartao.add_child(linha)
	# DUAS LINHAS: o nome em cima, na letra dos botões, e a vaga e o dia embaixo,
	# miúdos — numa linha só, ao lado dos ícones, o texto não cabia no cartão.
	var textos := VBoxContainer.new()
	textos.name = "Textos"
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.alignment = BoxContainer.ALIGNMENT_CENTER
	textos.add_theme_constant_override("separation", -3)
	textos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(textos)
	var texto := _linha_do_cartao(cartao, "Texto", cartao.get_theme_font_size("font_size"), 1.0)
	var detalhe := _linha_do_cartao(cartao, "Detalhe", 12, 0.62)
	textos.add_child(texto)
	textos.add_child(detalhe)
	if ocupada:
		texto.text = nome
		detalhe.text = tr("VAGA %d · DIA %d") % [slot, int(resumo.get("dia", 1))]
	else:
		texto.text = tr("VAGA %d · VAZIA") % slot
		detalhe.text = tr("COMEÇAR AQUI")
	if ocupada:
		linha.add_child(_icone_da_vaga("Editar%d" % slot, "editar", "Editar o nome da vaga", func(): _editar_o_nome(slot)))
		linha.add_child(_icone_da_vaga("Apagar%d" % slot, "apagar", "Apagar a partida", func(): _apagar_a_vaga(slot, nome)))
	if not PontosDeRestauracao.listar(slot).is_empty():
		linha.add_child(_icone_da_vaga("Pontos%d" % slot, "restaurar", "Pontos de restauração", func(): _pontos_da_vaga(slot), true))
	return cartao


## Uma linha de texto do cartão, na letra do botão.
func _linha_do_cartao(cartao: Button, nome: String, tamanho: int, opaco: float) -> Label:
	var texto := Label.new()
	texto.name = nome
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.clip_text = true
	texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texto.add_theme_font_override("font", cartao.get_theme_font("font"))
	texto.add_theme_font_size_override("font_size", tamanho)
	texto.add_theme_color_override("font_color", Color(cartao.get_theme_color("font_color"), opaco))
	return texto


## Um ícone dentro do cartão: botão próprio, que fica com o clique dele (o
## cartão não continua a partida por baixo).
func _icone_da_vaga(nome: String, icone: String, dica: String, acao: Callable, aceso := false) -> Button:
	var botao := Button.new()
	botao.name = nome
	botao.custom_minimum_size = Vector2(36, 36)
	botao.theme_type_variation = &"BotaoIcone"
	botao.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	botao.tooltip_text = tr(dica)
	botao.mouse_filter = Control.MOUSE_FILTER_STOP
	var glifo = HudIcon.new().configurar(icone)
	glifo.name = "Glifo"
	glifo.position = Vector2(6, 6)
	glifo.size = Vector2(24, 24)
	glifo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glifo.definir(aceso)
	botao.add_child(glifo)
	botao.mouse_entered.connect(func(): Audio.efeito("ui_hover"))
	botao.focus_entered.connect(_tique_de_foco)
	botao.pressed.connect(func():
		Audio.efeito("ui_confirmar")
		acao.call())
	return botao


## Tocar no cartão continua a partida (ou começa a nova); com a lixeira pedindo
## a confirmação, desiste de apagar.
func _ao_tocar_a_vaga(slot: int, ocupada: bool) -> void:
	if _confirmando_vaga == slot:
		_vagas()
		(content.get_node("Vaga%d" % slot) as Button).grab_focus()
		return
	_abrir_vaga(slot, not ocupada)


## A LIXEIRA: o primeiro clique pinta o cartão e diz o que se perde; o segundo
## apaga. Apagar guarda antes o ponto de restauração da vaga (`Partida`).
func _apagar_a_vaga(slot: int, nome: String) -> void:
	if _confirmando_vaga != slot:
		_vagas()
		_confirmando_vaga = slot
		var cartao := content.get_node("Vaga%d" % slot) as Button
		cartao.theme_type_variation = &"BotaoNegativo"
		var texto := cartao.get_node("Linha/Textos/Texto") as Label
		texto.text = tr("APAGAR A PARTIDA DE %s?") % nome
		# Letra menor, e o lápis sai enquanto a lixeira pergunta: a pergunta leva
		# o nome inteiro, e tem de caber no cartão.
		texto.add_theme_font_size_override("font_size", 14)
		cartao.get_node("Linha/Editar%d" % slot).visible = false
		texto.add_theme_color_override("font_color", cartao.get_theme_color("font_color"))
		var detalhe := cartao.get_node("Linha/Textos/Detalhe") as Label
		detalhe.text = tr("CLIQUE NA LIXEIRA DE NOVO")
		detalhe.add_theme_color_override("font_color", Color(cartao.get_theme_color("font_color"), 0.75))
		var lixeira := cartao.get_node("Linha/Apagar%d" % slot) as Button
		lixeira.get_node("Glifo").definir(true)
		lixeira.grab_focus()
		return
	Partida.apagar_vaga(slot)
	_vagas()
	(content.get_node("Vaga%d" % slot) as Button).grab_focus()


## O LÁPIS: o texto do cartão vira um campo com o nome da vaga. Enter (ou sair
## do campo) grava; Esc desiste. Nome vazio volta ao de quem joga.
func _editar_o_nome(slot: int) -> void:
	var cartao := content.get_node("Vaga%d" % slot) as Button
	var texto := cartao.get_node("Linha/Textos") as Control
	var campo := LineEdit.new()
	campo.name = "Nome"
	campo.text = _nome_da_vaga(slot, Salvamento.resumo(slot))
	campo.placeholder_text = tr("Nome da vaga")
	campo.max_length = Partida.NOME_MAXIMO
	campo.alignment = HORIZONTAL_ALIGNMENT_CENTER
	campo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texto.get_parent().add_child(campo)
	texto.get_parent().move_child(campo, texto.get_index())
	texto.visible = false
	var feito := [false]
	var gravar := func(novo: String) -> void:
		if feito[0]:
			return
		feito[0] = true
		Partida.renomear(slot, novo)
		_vagas()
		(content.get_node("Vaga%d" % slot) as Button).grab_focus()
	campo.text_submitted.connect(gravar)
	campo.focus_exited.connect(func() -> void: gravar.call(campo.text))
	campo.gui_input.connect(func(evento: InputEvent) -> void:
		if evento.is_action_pressed("ui_cancel"):
			feito[0] = true
			campo.accept_event()
			_vagas()
			(content.get_node("Vaga%d" % slot) as Button).grab_focus())
	campo.grab_focus()
	campo.select_all()


## OS PONTOS DE RESTAURAÇÃO DE UMA VAGA: do mais novo ao mais velho, cada um com
## o dia do jogo, quando foi guardado e por quê. Restaurar pede o segundo
## clique, e o que a vaga tinha vira um ponto também.
func _pontos_da_vaga(slot: int) -> void:
	_clear()
	_confirmando_ponto = ""
	var resumo := Salvamento.resumo(slot)
	_label("Pontos de restauração", 30)
	if bool(resumo.get("existe", false)):
		_label(tr("Vaga %d · %s · dia %d") % [slot, _nome_da_vaga(slot, resumo), int(resumo.get("dia", 1))], 18)
	else:
		_label(tr("Vaga %d · vazia") % slot, 18)
	_label("O jogo guarda um ponto por dia de jogo — os sete mais novos — e um antes de apagar ou de restaurar a partida. Restaurar volta a vaga para o ponto escolhido, e o que ela tinha fica guardado como ponto também.", 15)
	var primeiro: Button = null
	var ordem := 0
	for ponto in PontosDeRestauracao.listar(slot):
		var este := []
		var botao := _button(_texto_do_ponto(ponto), func(): _restaurar_o_ponto(slot, ponto, este[0]))
		# Letra menor: a data e o porquê numa linha só, sem alargar o painel.
		botao.add_theme_font_size_override("font_size", 14)
		este.append(botao)
		botao.name = "Ponto%d" % ordem
		ordem += 1
		if primeiro == null:
			primeiro = botao
	var voltar := _button("VOLTAR", func():
		_vagas()
		(content.get_node("Vaga%d" % slot) as Button).grab_focus())
	(primeiro if primeiro != null else voltar).grab_focus()


func _texto_do_ponto(ponto: Dictionary) -> String:
	var por_que := {
		PontosDeRestauracao.DIA: tr("COMEÇO DO DIA"),
		PontosDeRestauracao.ANTES_DE_APAGAR: tr("ANTES DE APAGAR"),
		PontosDeRestauracao.ANTES_DE_RESTAURAR: tr("ANTES DE RESTAURAR"),
	}
	# O relógio de parede de quem joga, e não o UTC do arquivo.
	var fuso := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var data := Time.get_datetime_dict_from_unix_time(int(ponto["quando"]) / 1000 + fuso)
	var quando := "%02d/%02d %02d:%02d" % [int(data["day"]), int(data["month"]), int(data["hour"]), int(data["minute"])]
	return tr("DIA %d · %s · %s") % [int(ponto["dia"]), quando, str(por_que.get(str(ponto["tipo"]), str(ponto["tipo"])))]


func _restaurar_o_ponto(slot: int, ponto: Dictionary, botao: Button) -> void:
	var caminho := str(ponto["caminho"])
	if _confirmando_ponto != caminho:
		_confirmando_ponto = caminho
		botao.text = tr("RESTAURAR O DIA %d · CLIQUE DE NOVO") % int(ponto["dia"])
		botao.theme_type_variation = &"BotaoNegativo"
		return
	if PontosDeRestauracao.restaurar(slot, caminho):
		Audio.efeito("ui_confirmar")
	_vagas()
	(content.get_node("Vaga%d" % slot) as Button).grab_focus()


## Vaga nova: a partida começa do zero ali, pela travessia. Vaga ocupada: o
## vale abre e carrega o que ela guarda (ver `prototype._retomar_a_partida`).
func _abrir_vaga(slot: int, nova: bool, nome: String = "") -> void:
	if nova and nome.strip_edges() == "":
		_pedir_nome(slot)
		return
	Partida.comecar(slot, nova)
	if nova:
		Jogo.nome_jogador = nome.strip_edges().left(Partida.NOME_MAXIMO)
		_intro()
	else:
		_start_game()


## O nome de quem joga é distinto do nome editável da vaga. Cancelar não
## começa nem limpa a partida; só a confirmação restaura o estado de fábrica.
func _pedir_nome(slot: int) -> void:
	_clear()
	# Mais largo e sem altura fixa (#214): a ajuda em leitura de corpo cabe em duas linhas nos três
	# idiomas, e o modal abraça o conteúdo.
	_place_modal(Vector2(NOME_LARGURA, 0), "vagas", true)
	var dados: Dictionary = Jogo.dados("res://data/nome_jogador.json")
	_modal_header(str(IdiomaMenu.campo(dados, "titulo")), _vagas)
	# A ajuda é texto para ler (papel de leitura da #199): a sans do HUD, em creme, no tamanho do corpo
	# dos outros modais e proporcional ao título e ao campo; o aviso de erro vai um pouco menor.
	var ajuda := Identidade.papel_leitura(_label(str(IdiomaMenu.campo(dados, "ajuda"))), NOME_TAMANHO_AJUDA)
	ajuda.name = "AjudaNome"
	var campo := LineEdit.new()
	campo.name = "NomeJogador"
	campo.placeholder_text = str(IdiomaMenu.campo(dados, "campo"))
	campo.max_length = Partida.NOME_MAXIMO
	campo.custom_minimum_size.y = 44
	content.add_child(campo)
	var erro := Identidade.papel_leitura(_label(str(IdiomaMenu.campo(dados, "erro"))), NOME_TAMANHO_ERRO, Identidade.TERRACOTA)
	erro.name = "ErroNome"
	erro.hide()
	var feito := [false]
	var confirmar := func() -> void:
		if feito[0]: return
		var nome := campo.text.strip_edges()
		if nome == "":
			erro.show()
			campo.grab_focus()
			return
		feito[0] = true
		_abrir_vaga(slot, true, nome)
	var botao := _button("COMEÇAR AQUI", confirmar)
	botao.name = "ComecarPartida"
	campo.text_submitted.connect(func(_texto: String) -> void: confirmar.call())
	campo.gui_input.connect(func(evento: InputEvent) -> void:
		if evento.is_action_pressed("ui_cancel"):
			campo.accept_event()
			_vagas())
	campo.grab_focus()


## EXPLORAR é o passeio livre: sem vaga, não grava nada e não apaga nada.
func _explorar() -> void:
	Partida.comecar(0)
	_start_game()


## TESTAR abre o modal do testador: quem joga (o determinístico sempre; Jev e GPT quando a
## ponte acha a chave e o serviço), o orçamento e a duração. Nada começa antes do INICIAR.
## A ponte abre a própria janela com um perfil isolado, sem usar as vagas pessoais; o
## lançador automático escolhe JOGAR, não este botão, evitando recursão.
##
## SÓ FICA UMA JANELA DO JOGO (#175). O menu não se fecha ao disparar o python — ele só sabe que
## o processo começou, não que a janela do testador abriu —: espera o arquivo `TESTADOR_PRONTO`,
## que a ponte cria na primeira chamada do jogo da sessão, e então se fecha (`_vigiar_testador`).
## Se o python morrer antes disso o menu continua aberto e diz o que houve. Ao fim da sessão
## (F8, tempo ou erro) o `jogar.py --voltar-ao-menu` reabre o menu, para o jogador não ficar sem janela.
func _teste_automatico() -> void:
	_modal_testador(TestadorApoios.detectar())


## O desenho do modal, separado da detecção para o portão poder dar uma detecção pronta.
func _modal_testador(deteccao: Dictionary) -> void:
	_clear()
	_place_modal(TESTADOR_SIZE)
	var voltar := _modal_header("Testar o jogo", _home, "Escolha quem joga e quanto pode gastar.")
	var apoios: Dictionary = deteccao["apoios"]
	_apoio_linha("Determinístico", "Base, sempre ligado: o robô local escolhe pelas regras do jogo, sem custo.", apoios["deterministic"], true)
	# AS OPÇÕES DO ÚLTIMO TESTE (#235): Jev, GPT, orçamento e duração voltam como ficaram. Um apoio
	# indisponível aparece desligado, e a preferência fica guardada para quando ele voltar.
	var guardadas := TestadorApoios.preferencias()
	var jev := _apoio_linha("Jev (TypeSafe)", "Segundo nível: decide a continuidade quando o determinístico trava.", apoios["jev"], false, bool(guardadas["jev"]))
	var gpt := _apoio_linha("GPT (OpenAI)", "Terceiro nível: entra quando o Jev também não destrava.", apoios["gpt"], false, bool(guardadas["gpt"]))
	var teto: float = float(deteccao["orcamento"]["teto"])
	var orcamento_inicial := float(guardadas["orcamento"]) if guardadas["orcamento"] != null else float(deteccao["orcamento"]["padrao"])
	var orcamento := _campo_numerico("Orçamento (US$)", 0.01, teto, 0.01, clampf(orcamento_inicial, 0.01, teto),
		tr("Só vale com Jev ou GPT marcados. Teto autorizado: US$ %.2f.") % teto)
	var duracao := _campo_numerico("Duração (minutos)", 0.0, 600.0, 1.0, float(guardadas["duracao_min"]), tr("Zero deixa a sessão sem limite de tempo."))
	var jev_disponivel := bool(apoios["jev"]["disponivel"])
	var gpt_disponivel := bool(apoios["gpt"]["disponivel"])
	# Indisponível, o botão não diz nada da vontade de quem joga: guarda-se o que já estava.
	var guardar := func(continuar: bool) -> void:
		TestadorApoios.guardar_preferencias(jev.button_pressed if jev_disponivel else bool(guardadas["jev"]),
			gpt.button_pressed if gpt_disponivel else bool(guardadas["gpt"]), orcamento.value, int(duracao.value), continuar)
	var pago := func() -> void:
		var algum := jev.button_pressed or gpt.button_pressed
		orcamento.editable = algum
		orcamento.modulate.a = 1.0 if algum else 0.5
	jev.toggled.connect(func(_ligado: bool) -> void: pago.call())
	gpt.toggled.connect(func(_ligado: bool) -> void: pago.call())
	pago.call()
	jev.toggled.connect(func(_ligado: bool) -> void: guardar.call(bool(guardadas["continuar"])))
	gpt.toggled.connect(func(_ligado: bool) -> void: guardar.call(bool(guardadas["continuar"])))
	var ultima := TestadorApoios.resumo_da_ultima(deteccao["ultima_sessao"])
	# CONTINUAR OU NOVA (#235): com uma sessão anterior, a escolha entre retomar de onde ela
	# parou e começar do zero. Sem anterior, é sempre nova.
	var continuar: Button = null
	if ultima != "":
		var titulo := _label(tr("Última sessão"), 15)
		titulo.add_theme_color_override("font_color", Color("e2c47f"))
		var nota := _label(ultima, 16)
		nota.add_theme_color_override("font_color", Color("c9b98f"))
		content.add_child(TestadorApoios.barra(float(deteccao["ultima_sessao"].get("percentual", 0.0))))
		var grupo := ButtonGroup.new()
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation", 10)
		content.add_child(linha)
		continuar = _opcao_da_sessao(linha, grupo, "ContinuarSessao", "Continuar a última sessão", bool(guardadas["continuar"]))
		_opcao_da_sessao(linha, grupo, "NovaSessao", "Nova sessão", not bool(guardadas["continuar"]))
	if bool(deteccao["erro"]):
		var aviso := _label(tr("Sem Python por perto: só o determinístico está disponível."), 15)
		aviso.add_theme_color_override("font_color", Color("c9b98f"))
	var iniciar := _button("INICIAR", func() -> void:
		var retomar := continuar != null and continuar.button_pressed
		guardar.call(retomar if continuar != null else bool(guardadas["continuar"]))
		_iniciar_teste(jev.button_pressed, gpt.button_pressed, orcamento.value, int(duracao.value), retomar))
	iniciar.name = "IniciarTeste"
	voltar.grab_focus()


## Uma linha de apoio: botão de alternar e, embaixo, o papel dele ou, desligado, o motivo.
## Devolve o botão. Indisponível fica desativado e explicado; o determinístico, ligado e fixo.
func _apoio_linha(titulo: String, papel: String, apoio: Dictionary, fixo: bool, preferido := false) -> Button:
	var botao := Button.new()
	botao.toggle_mode = true
	botao.custom_minimum_size.y = 44
	botao.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var disponivel := bool(apoio["disponivel"])
	botao.disabled = fixo or not disponivel
	botao.button_pressed = fixo or (preferido and disponivel)
	botao.mouse_entered.connect(func() -> void: Audio.efeito("ui_hover"))
	var atualizar := func() -> void:
		var estado := tr("SEMPRE LIGADO") if fixo else (tr("LIGADO") if botao.button_pressed else (tr("DESLIGADO") if disponivel else tr("INDISPONÍVEL")))
		botao.text = "%s  ·  %s" % [tr(titulo), estado]
	botao.toggled.connect(func(_ligado: bool) -> void:
		Audio.efeito("ui_confirmar")
		atualizar.call())
	atualizar.call()
	content.add_child(botao)
	var texto := tr(papel) if (disponivel or fixo) else TestadorApoios.motivo(str(apoio["motivo"]))
	var nota := _label(texto, 15)
	nota.add_theme_color_override("font_color", Color("c9b98f") if (disponivel or fixo) else Color("e39475"))
	return botao


## Uma das duas escolhas da sessão (continuar ou nova): botão de alternar no mesmo grupo.
func _opcao_da_sessao(linha: HBoxContainer, grupo: ButtonGroup, nome: String, texto: String, ligado: bool) -> Button:
	var botao := Button.new()
	botao.name = nome
	botao.toggle_mode = true
	botao.button_group = grupo
	botao.button_pressed = ligado
	botao.text = tr(texto)
	botao.custom_minimum_size.y = 40
	botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	botao.mouse_entered.connect(func() -> void: Audio.efeito("ui_hover"))
	botao.toggled.connect(func(_ligado: bool) -> void: Audio.efeito("ui_confirmar"))
	linha.add_child(botao)
	return botao


func _campo_numerico(rotulo: String, minimo: float, maximo: float, passo: float, valor: float, ajuda: String) -> SpinBox:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 12)
	content.add_child(linha)
	var nome := Label.new()
	nome.text = tr(rotulo)
	nome.add_theme_font_size_override("font_size", 17)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(nome)
	var campo := SpinBox.new()
	campo.min_value = minimo
	campo.max_value = maximo
	campo.step = passo
	campo.value = valor
	campo.custom_minimum_size = Vector2(150, 36)
	campo.tooltip_text = ajuda
	linha.add_child(campo)
	return campo


## Dispara a ponte com o que o modal marcou e volta ao menu, que mostra o estado da partida.
func _iniciar_teste(jev: bool, gpt: bool, orcamento: float, minutos: int, continuar := false) -> void:
	if _testador_pid > 0:
		return
	var pronto := ProjectSettings.globalize_path(TESTADOR_PRONTO)
	var janela := ProjectSettings.globalize_path(TESTADOR_JANELA)
	DirAccess.remove_absolute(pronto)
	DirAccess.remove_absolute(janela)
	var argumentos := TestadorApoios.argumentos(jev, gpt, orcamento, minutos, OS.get_executable_path(), continuar)
	# O perfil do testador é isolado e só o idioma atravessa (#180): pt, en, es ou zh.
	var idioma_atual: String = IdiomaMenu.LOCALES[IdiomaMenu.indice()].get_slice("_", 0)
	# O MENU SÓ FECHA COM O VALE CARREGADO (#175): a ponte grava o `--pronto` quando a janela da
	# sessão sobe, cedo demais; o arquivo que fecha o menu vai pelo ambiente (o python o repassa
	# ao jogo) e a sessão o grava com a carga feita (`sessao.gd`, `_avisar_o_menu_que_o_vale_abriu`).
	OS.set_environment("MV_JEV_PRONTO_VALE", pronto)
	argumentos.append_array(PackedStringArray(["--idioma", idioma_atual, "--pronto", janela, "--voltar-ao-menu"]))
	var pid := OS.create_process("python", argumentos)
	_home()
	if pid <= 0:
		estado_testador.text = tr("Não foi possível iniciar o testador. Confira a instalação do Python.")
	else:
		_testador_pid = pid
		estado_testador.text = tr("Abrindo o teste automático. Esta janela se fecha quando a sessão começar; F8 encerra a sessão e volta ao menu.")
	estado_testador.show()


## O menu fecha quando a janela do testador subiu; se o python saiu antes, avisa e segue aberto.
func _vigiar_testador() -> void:
	if _testador_pid <= 0:
		return
	if FileAccess.file_exists(TESTADOR_PRONTO):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TESTADOR_PRONTO))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TESTADOR_JANELA))
		_testador_pid = 0
		get_tree().quit()
	elif not OS.is_process_running(_testador_pid):
		_testador_pid = 0
		estado_testador.text = tr("O teste automático não abriu a janela da sessão. Esta janela continua aberta; confira a instalação do Python.")


func _modal_header(title: String, action: Callable, subtitle: String = "", icon: String = "fechar") -> Button:
	return PainelAjustes.cabecalho(ui_parent, title, action, subtitle, icon)


func _close_help() -> void:
	ajustes.fechar_ajuda()


func _credits() -> void:
	_clear()
	_place_modal(HISTORY_SIZE, "sobre")
	var home := _modal_header("Por trás do vale", _home, "Quem faz o vale e de onde ele vem.")
	_highlighted("O vale nasceu do encontro entre paisagens, memórias e histórias brasileiras. Entre casas, caminhos e mata, cada lugar convida a uma descoberta.")
	_highlighted("Música, narração e efeitos acompanham a travessia e dão voz aos lugares e personagens. Esta é uma primeira visita a esse mundo. Obrigado por caminhar conosco enquanto a jornada cresce.")
	_highlighted("Myths’ Valley é uma criação da equipe da Alpha Centauri, um spin-off do projeto Batalha de Mitos. Você pode saber mais acessando:")
	_link_externo("batalhademitos.com.br", "https://www.batalhademitos.com.br")
	_link_externo("mythsvalley.app.br", Atualizacao.ORIGEM)
	var team_gap := Control.new()
	team_gap.custom_minimum_size.y = 6
	content.add_child(team_gap)
	var team_title := _label("Colaboradores", 15)
	team_title.add_theme_color_override("font_color", Color("e2c47f"))
	_label(" · ".join(COLLABORATORS), 16)
	home.grab_focus()


## Endereço com o ícone de link externo antes: avisa que o clique abre o navegador.
func _link_externo(texto: String, url: String) -> void:
	var abrir := func() -> void: OS.shell_open(url)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 8)
	content.add_child(linha)
	var externo := Button.new()
	externo.flat = true
	externo.focus_mode = Control.FOCUS_NONE
	externo.custom_minimum_size = Vector2(26, 26)
	externo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	externo.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var icone = HudIcon.new().configurar("externo")
	icone.position = Vector2(3, 3)
	icone.size = Vector2(24, 24)
	icone.scale = Vector2.ONE * (20.0 / 24.0)
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	externo.add_child(icone)
	externo.pressed.connect(abrir)
	linha.add_child(externo)
	var site := LinkButton.new()
	site.text = texto
	site.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	site.add_theme_font_size_override("font_size", 17)
	site.add_theme_color_override("font_color", Color("e2c47f"))
	site.add_theme_color_override("font_hover_color", Color("f5e3b3"))
	site.pressed.connect(abrir)
	linha.add_child(site)
	for hoverable: Control in [externo, site]:
		hoverable.mouse_entered.connect(func() -> void: icone.definir(true))
		hoverable.mouse_exited.connect(func() -> void: icone.definir(false))

## Parágrafo com os termos de CREDITS_HIGHLIGHTS em dourado, para a leitura correr
## pelos pontos principais. O texto é traduzido antes; os termos cobrem os três idiomas.
func _highlighted(text: String) -> void:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich.custom_minimum_size.x = 375
	rich.add_theme_font_size_override("normal_font_size", 17)
	rich.add_theme_color_override("default_color", Color.WHITE)
	var translated := tr(text).replace("[", "[lb]")
	for term: String in CREDITS_HIGHLIGHTS:
		translated = translated.replace(term, "[color=#e2c47f]%s[/color]" % term)
	rich.text = translated
	content.add_child(rich)


## A travessia vira cinema: faixas pretas, capítulo entre losangos, legenda centrada na
## base sobre o vale e o fio de ouro medindo cada fala (o mesmo fio da carga).
func _intro() -> void:
	_clear()
	_place_legenda()
	_decoracao_modo("travessia")
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 12)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(linha)
	linha.add_child(Identidade.filete(false))
	linha.add_child(Identidade.losango())
	chapter = Identidade.rotulo("A travessia", 14, Identidade.OURO)
	linha.add_child(chapter)
	linha.add_child(Identidade.losango())
	linha.add_child(Identidade.filete(true))
	caption = Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.custom_minimum_size.y = 108
	caption.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_ITALICO, 500))
	caption.add_theme_font_size_override("font_size", 28)
	caption.add_theme_color_override("font_color", Identidade.TEXTO)
	caption.add_theme_constant_override("line_spacing", -2)
	Identidade.sombra_texto(caption)
	content.add_child(caption)
	var acoes := HBoxContainer.new()
	acoes.alignment = BoxContainer.ALIGNMENT_END
	acoes.add_theme_constant_override("separation", 24)
	content.add_child(acoes)
	for par in [["CONTINUAR", _next_line], ["PULAR", _start_game]]:
		var botao := Button.new()
		botao.text = par[0]
		botao.theme_type_variation = &"BotaoLegenda"
		# Sem foco, como sempre: Enter, Espaço e E avançam; Esc pula (_unhandled_key_input).
		botao.focus_mode = Control.FOCUS_NONE
		botao.mouse_entered.connect(func() -> void: Audio.efeito("ui_hover"))
		botao.pressed.connect(func() -> void:
			Audio.efeito("ui_confirmar")
			(par[1] as Callable).call())
		acoes.add_child(botao)
	line_bar = fio_base
	line_bar.value = 1.0
	Audio.iniciar_travessia()
	lines = IdiomaMenu.campo(dialog_data, "travessia", [])
	line_index = -1
	_next_line()


## Painel sem moldura, centrado na base da tela, para a legenda da travessia.
func _place_legenda() -> void:
	panel.set_meta("sem_moldura", true)
	panel.custom_minimum_size = Vector2(900, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -450.0
	panel.offset_right = 450.0
	panel.offset_top = -218.0
	panel.offset_bottom = -30.0
	Tela.vincular_componente(panel, "travessia", Vector2(0.5, 1.0))

func _next_line() -> void:
	line_index += 1
	if line_index >= lines.size():
		_start_game()
		return
	caption.text = Jogo.texto(str(lines[line_index]))
	chapter.text = ["A partida", "A travessia", "A chegada"][mini(line_index / 3, 2)]
	# Cada legenda tem o seu trecho de narração (o mesmo em todos os idiomas: a voz é
	# em português). A legenda dura o trecho e um respiro; sem o áudio, o tempo de leitura.
	var restante := Audio.tocar_trecho_travessia(line_index)
	line_time = restante + PAUSA_ENTRE_TRECHOS if restante > 0.0 else maxf(6.0, caption.text.length() * 0.065)
	line_total = line_time
	line_bar.value = 1.0

func _start_game() -> void:
	if starting:
		return
	starting = true
	set_process(false)
	# PULAR no meio de uma fala: ela some suave em vez de cortar.
	Audio.encerrar_travessia(false)
	# A tela de carregamento e a partida seguem o idioma escolhido no menu.
	var loading := _show_loading()
	Dia.pausado = false
	Dia.definir_hora(Dia.hora_inicial)
	# prototype.gd solta o relógio quando o vale fica pronto.
	Dia.congelado_na_carga = true
	IdiomaMenu.aplicar_jogo()
	TelaCarregamento.trocar_cena(get_tree(), GAME_SCENE, loading)


## Tela de carregamento sobre o menu (tela_carregamento.gd). Devolve a barra. A capa (dia
## ou noite) segue a hora em que o jogo vai começar, não a do cenário do menu.
func _show_loading() -> ProgressBar:
	_close_help()
	return TelaCarregamento.mostrar(panel.get_parent(), panel.theme, tr("Carregando o vale…"), Dia.hora_inicial)


func _formatar_escala(meters_per_unit: float) -> String:
	if is_equal_approx(meters_per_unit, roundf(meters_per_unit)):
		return str(int(roundf(meters_per_unit)))
	return String.num(meters_per_unit, 2)
