extends CanvasLayer
## Interface leve para o primeiro teste do personagem em 3D. No canto direito, a mesma
## coluna de botões redondos do menu (som e relógio na mesma posição), seguida de HOME,
## câmera, velocidade do tempo e estilo visual. O botão de dados abre as medições acima
## do minimapa; no alto, ao centro, ficam só a hora e o período do dia.

const BotaoCanto = preload("res://scripts/prototipo_3d/botao_canto.gd")
const AudioToggleIcon = preload("res://scripts/prototipo_3d/audio_toggle_icon.gd")
const ClockIcon = preload("res://scripts/prototipo_3d/clock_icon.gd")
const HudIcon = preload("res://scripts/prototipo_3d/hud_icon.gd")
const TemaMenu = preload("res://scripts/prototipo_3d/tema_menu.gd")
const TelaCarregamento = preload("res://scripts/prototipo_3d/tela_carregamento.gd")
const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")
const PainelAjustes = preload("res://scripts/prototipo_3d/painel_ajustes.gd")
const CaixaDePergunta = preload("res://scripts/prototipo_3d/caixa_de_pergunta.gd")
const Minimapa = preload("res://scripts/prototipo_3d/minimapa.gd")


## Camada dos modais do jogo (ajustes): roda com o vale pausado e trata Esc.
class Sobreposicao:
	extends Control
	var ao_esc: Callable

	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _unhandled_key_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			ao_esc.call()
			get_viewport().set_input_as_handled()
const TeclasMovimento = preload("res://scripts/prototipo_3d/teclas_movimento.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const BarraDeMao = preload("res://scripts/prototipo_3d/barra_de_mao.gd")
const Almanaque = preload("res://scripts/prototipo_3d/almanaque.gd")

## A barra de mão, para quem precisar escutar a mochila abrindo.
var _barra: Control
var _almanaque: Control

signal reset_requested
signal quit_requested
## HOME (botão ou M): pede a confirmação. Confirmada, `menu_requested`; cancelada,
## `menu_cancelled`.
signal menu_prompt_requested
signal menu_requested
signal menu_cancelled
## Botão de mapa do canto: abre ou fecha o mapa do vale.
signal map_requested
## Engrenagem do canto: pede os ajustes; `settings_closed` quando o modal fecha.
signal settings_requested
signal settings_closed
## Estilo visual trocado nos ajustes: o vale precisa ser reconstruído.
signal style_changed
signal camera_lock_requested(locked: bool)
signal house_info_close_requested

const INK := Color("e8e4d7")
const MUTED := Color("aebaae")
const GOLD := Color("d6ba78")
## Largura do painel do canto superior esquerdo (título, região e objetivo).
const HEADING_WIDTH := 360.0

var _model_status := "Preparando personagem…"
var _telemetry := ""
var _notice := ""
var _objective := "Explore o vale e observe o personagem de todos os ângulos."
var _captured := false
var _camera_locked := false
var _refresh_time := 0.0
var _root: Control
var _region_label: Label
## "3 de 9" da missão em curso, à direita do nome da região.
var _mission_step: Label
## O nome da missão acompanhada, em cima do objetivo (ver `set_objective`).
var _quest_label: Label
var _missao := ""
var _performance_panel: Panel
var _performance_label: Label
var _performance_button: Button
var _performance_open := false
## O número de FPS escrito no próprio botão (ver `_create_performance_button`).
var _fps_label: Label
var _speed_hint: Label
var _speed_icon	# hud_icon.gd
var _camera_icon	# hud_icon.gd
var _camera_hint: Label
var _notice_label: Label
var _notice_panel: Panel
var _objective_label: Label
var _heading: Panel
var _control_mode_label: Label
var _controls_panel: Panel
var _help_icon	# hud_icon.gd
var _camera_lock_button: Button
var _clock_hint: Label
var _house_info_panel: Panel
var _house_info_label: Label
var _house_info_heading: Label
var _clock_label: Label
var _menu_confirm = null	# caixa_de_pergunta.gd
var _map_icon	# hud_icon.gd
var _settings_icon	# hud_icon.gd
var _settings: Control
var _ajustes	# painel_ajustes.gd
## Painéis escondidos enquanto o mapa está aberto (a coluna do canto continua).
var _hidden_for_map: Array[Control] = []
var _corner_nodes: Array[Node] = []
var mapa_aberto := false


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.name = "PrototypeHUD"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# O BLOCO DA MISSÃO, e não o letreiro do jogo.
	#
	# Aqui ficava "MYTHS' VALLEY" em 28 px, ocupando o terço de cima de um
	# painel de 360×132 — o nome do jogo escrito na tela de quem já está
	# jogando. Saiu, e o que sobrou é o que o jogador precisa ler: onde ele
	# está, o que ele tem de fazer, e quanto falta.
	#
	# A missão ganhou o espaço e o corpo: 17 px em vez de 15, com a linha do
	# passo à direita do rótulo. O painel encolheu junto — cabeçalho menor é
	# mais vale à vista.
	_heading = _panel(Color(0.055, 0.085, 0.075, 0.82))
	_place(_heading, Vector2(18, 18), Vector2(HEADING_WIDTH, 96))
	_region_label = _label("REGIÃO INICIAL", 12, GOLD)
	_place(_region_label, Vector2(33, 26), Vector2(HEADING_WIDTH - 130, 20))
	_mission_step = _label("", 12, GOLD)
	_mission_step.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(_mission_step, Vector2(HEADING_WIDTH - 108, 26), Vector2(92, 20))
	_quest_label = _label("", 13, GOLD)
	_quest_label.name = "MissaoAcompanhada"
	_quest_label.clip_text = true
	_quest_label.visible = false
	_place(_quest_label, Vector2(33, 50), Vector2(HEADING_WIDTH - 50, 20))
	_objective_label = _label(_objective, 17, INK)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_objective_label, Vector2(33, 52), Vector2(HEADING_WIDTH - 50, 42))

	# A COLUNA DE ÍCONES DO CANTO SAIU.
	#
	# Eram nove botões redondos empilhados na borda esquerda, por cima do vale,
	# o tempo todo: HOME, ajustes, som, relógio, mapa, câmera, velocidade,
	# estilo e controles. "Os ícones na esquerda do HUD podem ser todos dentro do
	# menu ESC" — e estão, em linhas com o estado escrito (`menu_pausa.gd`).
	#
	# `_create_corner_buttons` continua aqui, sem ser chamada, porque ela é a
	# receita dos ícones e do que cada um fazia: apagar agora seria perder o
	# registro de nove comportamentos no mesmo commit em que eles mudam de casa.
	# Sai no commit seguinte, com o `set_map_open` que fala dela.
	_create_performance_panel()
	_create_performance_button()

	_house_info_panel = _panel(Color(0.055, 0.085, 0.075, 0.92))
	_root.add_child(_house_info_panel)
	# Abaixo do bloco do canto superior esquerdo; _fit_heading acompanha a altura dele.
	_house_info_panel.position = Vector2(18, 162)
	_house_info_panel.size = Vector2(HEADING_WIDTH, 155)
	_house_info_panel.visible = false
	_house_info_heading = _label("INFORMAÇÕES DA CASA", 13, GOLD)
	_house_info_panel.add_child(_house_info_heading)
	_house_info_heading.position = Vector2(16, 10)
	_house_info_heading.size = Vector2(270, 24)
	_house_info_label = _label("", 15, INK)
	_house_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_house_info_panel.add_child(_house_info_label)
	_house_info_label.position = Vector2(16, 39)
	_house_info_label.size = Vector2(HEADING_WIDTH - 32, 108)
	var close_house_info := Button.new()
	close_house_info.text = "×"
	close_house_info.tooltip_text = "Fechar informações"
	close_house_info.position = Vector2(HEADING_WIDTH - 41, 7)
	close_house_info.size = Vector2(32, 28)
	close_house_info.mouse_filter = Control.MOUSE_FILTER_STOP
	_house_info_panel.add_child(close_house_info)
	close_house_info.pressed.connect(func(): house_info_close_requested.emit())

	# Controles: painel à esquerda, embaixo, como o das casas; começa oculto e abre
	# pelo "?" da coluna do canto.
	_controls_panel = _panel(Color(0.055, 0.085, 0.075, 0.92))
	_root.add_child(_controls_panel)
	_controls_panel.visible = false
	var controls_heading := _label("CONTROLES", 13, GOLD)
	_controls_panel.add_child(controls_heading)
	controls_heading.position = Vector2(16, 10)
	controls_heading.size = Vector2(270, 24)
	_control_mode_label = _label("", 14, INK)
	_control_mode_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_controls_panel.add_child(_control_mode_label)
	_control_mode_label.position = Vector2(16, 38)
	_control_mode_label.size = Vector2(HEADING_WIDTH - 32, 0)
	var close_controls := Button.new()
	close_controls.text = "×"
	close_controls.tooltip_text = "Fechar controles"
	close_controls.position = Vector2(HEADING_WIDTH - 41, 7)
	close_controls.size = Vector2(32, 28)
	close_controls.focus_mode = Control.FOCUS_NONE
	_controls_panel.add_child(close_controls)
	close_controls.pressed.connect(func(): set_controls_open(false))

	_notice_panel = _panel(Color(0.055, 0.085, 0.075, 0.82))
	_notice_panel.name = "Aviso"
	_root.add_child(_notice_panel)
	_notice_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_notice_panel.offset_left = -285
	_notice_panel.offset_right = 285
	# ACIMA DA BARRA DE MÃO, e a medida vem dela. O aviso ficava a 31–64 px do
	# rodapé, que é exatamente onde a barra desenha — e a barra entra depois no
	# HUD, então o cobria. Ver `BarraDeMao.altura_ocupada`.
	var acima := BarraDeMao.altura_ocupada()
	_notice_panel.offset_top = -acima - 33.0
	_notice_panel.offset_bottom = -acima
	_notice_panel.visible = not _notice.is_empty()
	_notice_label = _label(_notice, 14, GOLD)
	_root.add_child(_notice_label)
	_notice_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_notice_label.offset_left = 30
	_notice_label.offset_right = -30
	# Junto com o painel dele, acima da barra.
	_notice_label.offset_top = -acima - 29.0
	_notice_label.offset_bottom = -acima - 4.0
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Relógio do vale: só a hora e o período do dia.
	var clock_panel := _panel(Color(0.055, 0.085, 0.075, 0.82))
	_root.add_child(clock_panel)
	clock_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	clock_panel.offset_left = -70
	clock_panel.offset_right = 70
	clock_panel.offset_top = 18
	clock_panel.offset_bottom = 72
	_clock_label = _label("", 15, GOLD)
	clock_panel.add_child(_clock_label)
	_clock_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_criar_barra_de_vida()
	_criar_barra_de_folego()
	_criar_barra_de_stamina()

	# A BARRA DE MÃO ENTRA POR ÚLTIMO, e é o conserto de "não dá pra ver".
	#
	# A primeira versão a punha logo depois da raiz, de propósito, para ficar
	# POR BAIXO dos painéis — raciocínio que soa certo e está errado: o painel
	# do jogador ocupa o rodapé, e a barra desapareceu atrás dele.
	#
	# Barra de mão não é informação de fundo: é o que o jogador olha para saber
	# o que está segurando, e tem de estar na frente de tudo que não seja uma
	# tela cheia aberta. Filho mais novo desenha por cima — então ela é o
	# último a entrar, e a barra de vida, que é widget do alto, entra antes.
	var barra := BarraDeMao.new()
	barra.name = "BarraDeMao"
	_root.add_child(barra)
	_barra = barra

	# O ALMANAQUE por cima de tudo: é tela cheia, e tela cheia cobre.
	var almanaque := Almanaque.new()
	almanaque.name = "Almanaque"
	_root.add_child(almanaque)
	_almanaque = almanaque

	_update_control_mode()
	_update_telemetry()


## A VIDA, logo abaixo do relógio, com as cores do 2D (`scripts/ui/hud.gd`):
## vermelha sempre, porque é sangue e não fôlego; verde-musgo enquanto a
## peçonha corre, que é o aviso de que ela está descendo sozinha.
##
## É widget ACRESCENTADO, como a migração manda: o HUD continua sendo este, e
## não o do 2D. O número vem do `Vida` compartilhado — por `get_node_or_null`,
## porque quem monta o HUD sozinho, sem o projeto inteiro, não pode estourar
## aqui. A barra verde do corte dos coqueiros fica embaixo, na mesma medida.
const COR_VIDA := Color(0.78, 0.28, 0.26)
const COR_VIDA_ENVENENADA := Color(0.45, 0.62, 0.22)
var barra_vida: ProgressBar
var _vida_texto: Label
var _vida_preenchimento: StyleBoxFlat
var barra_stamina: ProgressBar
var _stamina_texto: Label
var _stamina_rotulo := ""


func _criar_barra_de_vida() -> void:
	barra_vida = ProgressBar.new()
	barra_vida.name = "Vida"
	barra_vida.show_percentage = false
	# Transparente ao mouse, como os rótulos do HUD: o clique no chão atrás dela
	# é caminhada (clique direito) e não pode morrer numa barra de 16 px.
	barra_vida.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.055, 0.085, 0.075, 0.82)
	fundo.set_corner_radius_all(6)
	fundo.set_border_width_all(1)
	fundo.border_color = Color(0.58, 0.64, 0.48, 0.2)
	barra_vida.add_theme_stylebox_override("background", fundo)
	_vida_preenchimento = StyleBoxFlat.new()
	_vida_preenchimento.bg_color = COR_VIDA
	_vida_preenchimento.set_corner_radius_all(6)
	barra_vida.add_theme_stylebox_override("fill", _vida_preenchimento)
	_root.add_child(barra_vida)
	barra_vida.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	barra_vida.offset_left = -70
	barra_vida.offset_right = 70
	barra_vida.offset_top = 78
	barra_vida.offset_bottom = 94
	_vida_texto = _label("", 11, INK)
	barra_vida.add_child(_vida_texto)
	_vida_texto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vida_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vida_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var vida := get_node_or_null("/root/Vida")
	if vida == null:
		barra_vida.visible = false
		return
	vida.mudou.connect(_atualizar_vida)
	_atualizar_vida()


func _atualizar_vida() -> void:
	var vida := get_node_or_null("/root/Vida")
	if vida == null or barra_vida == null:
		return
	barra_vida.max_value = vida.maximo()
	barra_vida.value = vida.atual
	_vida_texto.text = "%d" % roundi(vida.atual)
	_vida_preenchimento.bg_color = COR_VIDA_ENVENENADA if vida.envenenado_agora() else COR_VIDA


## O FÔLEGO (#3), logo abaixo da vida e na mesma medida, com as cores do 2D
## (`scripts/ui/hud.gd`): verde enquanto há fôlego, vermelho quando o corpo
## está no fim. O número vem do `Energia` compartilhado, e o limiar é o dele
## (`Energia.cansado()`), não um número daqui.
##
## Cansado, o texto diz "cansado" além de mudar a cor. O cansaço já pesa no
## corpo — o passo cai para 62% e a corrida não responde —, e sem aviso quem
## joga pensa que o jogo travou (ver `Energia.cansou`).
const COR_FOLEGO := Color(0.55, 0.78, 0.45)
const COR_FOLEGO_BAIXO := Color(0.9, 0.42, 0.34)
var barra_folego: ProgressBar
var _folego_texto: Label
var _folego_preenchimento: StyleBoxFlat


func _criar_barra_de_folego() -> void:
	barra_folego = ProgressBar.new()
	barra_folego.name = "Folego"
	barra_folego.show_percentage = false
	# Transparente ao mouse, como a da vida.
	barra_folego.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra_folego.add_theme_stylebox_override("background", barra_vida.get_theme_stylebox("background"))
	_folego_preenchimento = StyleBoxFlat.new()
	_folego_preenchimento.bg_color = COR_FOLEGO
	_folego_preenchimento.set_corner_radius_all(6)
	barra_folego.add_theme_stylebox_override("fill", _folego_preenchimento)
	_root.add_child(barra_folego)
	barra_folego.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	barra_folego.offset_left = -70
	barra_folego.offset_right = 70
	barra_folego.offset_top = 98
	barra_folego.offset_bottom = 114
	_folego_texto = _label("", 11, INK)
	barra_folego.add_child(_folego_texto)
	_folego_texto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_folego_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_folego_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var energia := get_node_or_null("/root/Energia")
	if energia == null:
		barra_folego.visible = false
		return
	energia.mudou.connect(_atualizar_folego)
	_atualizar_folego()


func _atualizar_folego() -> void:
	var energia := get_node_or_null("/root/Energia")
	if energia == null or barra_folego == null:
		return
	barra_folego.max_value = energia.maximo()
	barra_folego.value = energia.atual
	var cansado: bool = energia.cansado()
	_folego_texto.text = ("%d · cansado" if cansado else "%d") % roundi(energia.atual)
	_folego_preenchimento.bg_color = COR_FOLEGO_BAIXO if cansado else COR_FOLEGO


func _criar_barra_de_stamina() -> void:
	barra_stamina = ProgressBar.new()
	barra_stamina.name = "Stamina"
	barra_stamina.max_value = 100.0
	barra_stamina.value = 100.0
	barra_stamina.show_percentage = false
	barra_stamina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.055, 0.085, 0.075, 0.82)
	fundo.set_corner_radius_all(6)
	fundo.set_border_width_all(1)
	fundo.border_color = Color(0.58, 0.64, 0.48, 0.2)
	barra_stamina.add_theme_stylebox_override("background", fundo)
	var preenchimento := StyleBoxFlat.new()
	preenchimento.bg_color = Color("56ad67")
	preenchimento.set_corner_radius_all(6)
	barra_stamina.add_theme_stylebox_override("fill", preenchimento)
	_root.add_child(barra_stamina)
	barra_stamina.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	barra_stamina.offset_left = -70
	barra_stamina.offset_right = 70
	barra_stamina.offset_top = 118
	barra_stamina.offset_bottom = 134
	_stamina_texto = _label("100%", 11, INK)
	barra_stamina.add_child(_stamina_texto)
	_stamina_texto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stamina_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamina_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func definir_stamina(valor: float, rotulo: String) -> void:
	if barra_stamina == null:
		return
	_stamina_rotulo = rotulo
	barra_stamina.value = clampf(valor, 0.0, 100.0)
	_stamina_texto.text = "%s %d%%" % [_stamina_rotulo, roundi(barra_stamina.value)]


func _process(delta: float) -> void:
	_refresh_time += delta
	if _refresh_time >= 0.35:
		_refresh_time = 0.0
		_update_telemetry()


func set_model_status(value: String) -> void:
	_model_status = value
	_update_telemetry()


func set_region_title(value: String) -> void:
	if is_instance_valid(_region_label):
		_region_label.text = value.to_upper()


func set_telemetry(value: String) -> void:
	_telemetry = value
	_update_telemetry()


func set_notice(value: String) -> void:
	_notice = value
	if is_instance_valid(_notice_label):
		_notice_label.text = value
		_notice_panel.visible = not value.is_empty()
		var font := _notice_label.get_theme_font("font")
		var half := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x * 0.5 + 24.0
		_notice_panel.offset_left = -half
		_notice_panel.offset_right = half


## Painel de informações à esquerda, abaixo do título: casas e lápides do cemitério.
## A altura acompanha o texto.
## Quem abriu o painel (lápides, árvores); a casa clicada abre sem dono. Cada módulo
## confere o dono para saber se a ficha dele ainda está aberta.
var painel_dono: Object = null


func show_house_info(value: String, heading: String = "INFORMAÇÕES DA CASA") -> void:
	painel_dono = null
	_house_info_heading.text = heading
	_house_info_label.text = value
	var text_height := _text_height(_house_info_label)
	_house_info_label.size.y = text_height
	_house_info_panel.size.y = maxf(155.0, 39.0 + text_height + 28.0)
	_house_info_panel.visible = true


func clear_house_info() -> void:
	painel_dono = null
	_house_info_panel.visible = false


## O OBJETIVO, e em cima dele o NOME DA MISSÃO acompanhada, como no canto do
## Witcher: "◆ O CEMITÉRIO ESQUECIDO" e embaixo "Corte o capim com a foice
## (2/4)". Sem missão (o convite do começo, o fim de uma cadeia), só a frase.
func set_objective(value: String, missao: String = "") -> void:
	_objective = value
	_missao = missao
	if is_instance_valid(_quest_label):
		_quest_label.text = ("◆  " + missao.to_upper()) if missao != "" else ""
		_quest_label.visible = missao != ""
	if is_instance_valid(_objective_label):
		_objective_label.text = value
		_fit_heading()


func set_clock(value: String) -> void:
	if is_instance_valid(_clock_label):
		_clock_label.text = value


func set_captured(value: bool) -> void:
	_captured = value
	_update_control_mode()


func set_camera_locked(value: bool) -> void:
	_camera_locked = value
	if is_instance_valid(_camera_lock_button):
		_camera_lock_button.set_pressed_no_signal(value)
		if is_instance_valid(_camera_icon):
			_camera_icon.definir(value)
		if is_instance_valid(_camera_hint):
			_camera_hint.text = ("Câmera travada · %s ou Tab destrava" % Atalhos.letra("camera")) if value else ("Câmera livre · %s ou Esc trava" % Atalhos.letra("camera"))
	_update_control_mode()


## Texto do painel de controles, um comando por linha; a linha da câmera muda com o modo.
func _update_control_mode() -> void:
	if not is_instance_valid(_control_mode_label):
		return
	var mode := "Câmera solta: mova o mouse para olhar" if _captured else "Câmera travada: arraste o cenário"
	_control_mode_label.text = "\n".join([
		"%s: mover" % TeclasMovimento.rotulo(),
		"Shift: corrida (parar desliga)",
		"Espaço: pular  ·  1 a 0: item na mão  ·  Alt+1 a 8: gestos",
		"%s: mochila  ·  %s: árvore de habilidades  ·  %s: o arraial" % [Atalhos.letra("mochila"), Atalhos.letra("talentos"), Atalhos.letra("arraial")],
		"Botão direito: andar até o ponto (duplo: correr)",
		"Botão esquerdo na casa: dados",
		"%s: ler / interagir  ·  %s: observar" % [Atalhos.letra("interagir"), Atalhos.letra("observar")],
		"%s perto do bicho: golpe (segurar: forte)  ·  %s: ginga" % [Atalhos.letra("interagir"), Atalhos.letra("gingar")],
		"%s: painel (missões, cartas, venda, jogo)  ·  %s: almanaque (plantas, cordéis, sinais, bichos)" % [Atalhos.letra("painel"), Atalhos.letra("almanaque")],
		mode,
		"Tab ou %s: alterna a câmera  ·  Esc: menu" % Atalhos.letra("camera"),
		"Rodinha: item da mão  ·  Ctrl+rodinha ou +/-: zoom  ·  %s: avança a hora" % Atalhos.letra("hora"),
		"%s: reinicia  ·  %s: mapa · minimapa em AJUSTAR" % [Atalhos.letra("reiniciar"), Atalhos.letra("mapa")],
	])
	var text_height := _text_height(_control_mode_label)
	_control_mode_label.size.y = text_height
	var height := 38.0 + text_height + 16.0
	var screen := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1280, 720)
	_controls_panel.size = Vector2(HEADING_WIDTH, height)
	_controls_panel.position = Vector2(18, screen.y - height - 18.0)


## Altura do texto de um rótulo com quebra de linha, contando o espaço entre linhas.
func _text_height(label: Label) -> float:
	var lines := maxi(1, label.get_line_count())
	return lines * label.get_line_height() + (lines - 1) * label.get_theme_constant("line_spacing")


func controls_open() -> bool:
	return is_instance_valid(_controls_panel) and _controls_panel.visible


## "?" do canto: mostra ou esconde o painel de controles (o "?" fica dourado aberto).
func set_controls_open(open: bool) -> void:
	_controls_panel.visible = open
	if is_instance_valid(_help_icon):
		_help_icon.definir(open)
	_sync_performance_panel()
	if open:
		_update_control_mode()


func _update_telemetry() -> void:
	if is_instance_valid(_fps_label):
		_fps_label.text = str(int(Engine.get_frames_per_second()))
	if not is_instance_valid(_performance_label):
		return
	var triangles := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var vram := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	var suffix := "  ·  " + _telemetry if not _telemetry.is_empty() else ""
	_performance_label.text = "%d FPS%s\n%s\n%s tri · %d draws · %d MB VRAM" % [Engine.get_frames_per_second(), suffix, _model_status, _compact(triangles), int(draws), int(vram)]
	# OS ÍCONES DO CANTO PODEM NÃO EXISTIR.
	#
	# A coluna deles saiu para dentro do menu do Esc, e `_create_corner_buttons`
	# deixou de ser chamada — então `_speed_icon` e companhia ficam nulos. As
	# medições continuam sendo feitas (o `_performance_label` acima é a dica de
	# desempenho, que tem dono próprio); o que se guarda aqui é só não falar com
	# quem não nasceu.
	if is_instance_valid(_speed_icon):
		_speed_icon.definir(false, Dia.velocidade)
	if is_instance_valid(_speed_hint):
		_speed_hint.text = "Tempo: %s · clique para mudar" % String(Dia.ROTULOS_VELOCIDADE[Dia.velocidade])
	_update_clock_hint()


func _update_clock_hint() -> void:
	if not is_instance_valid(_clock_hint):
		return
	_clock_hint.text = Dia.texto_hora()


## O painel do canto esquerdo cresce só o necessário para o objetivo caber.
func _fit_heading() -> void:
	if not is_instance_valid(_heading):
		return
	var lines := maxi(1, _objective_label.get_line_count())
	# 52 é onde a missão começa (ver `_montar`); com o nome da missão em cima,
	# ela desce 22. 18 de respiro embaixo.
	var topo := 52.0 + (22.0 if _missao != "" else 0.0)
	_objective_label.position.y = _heading.position.y + topo - 18.0
	var altura := topo + lines * _objective_label.get_line_height() + 18.0
	_objective_label.size.y = lines * _objective_label.get_line_height()
	_heading.size.y = altura
	if is_instance_valid(_house_info_panel):
		_house_info_panel.position.y = 18.0 + altura + 12.0


## Coluna de botões redondos: HOME, som e relógio na mesma posição do menu, depois
## câmera, velocidade do tempo e dados de desempenho.
func _create_corner_buttons() -> void:
	var first_child := _root.get_child_count()
	var top := 32.0
	var home: Array = BotaoCanto.criar(_root, top, HudIcon.new().configurar("casa"))
	(home[1] as Label).text = "HOME · voltar ao menu"
	_corner_setup(home[0], func() -> void: menu_prompt_requested.emit())

	top += BotaoCanto.ESPACO
	_settings_icon = HudIcon.new().configurar("ajustes")
	var settings: Array = BotaoCanto.criar(_root, top, _settings_icon)
	(settings[1] as Label).text = "Ajustes"
	_corner_setup(settings[0], func() -> void: settings_requested.emit())

	top += BotaoCanto.ESPACO
	var audio_icon := AudioToggleIcon.new()
	audio_icon.set_active(Audio.som_ativo)
	var audio: Array = BotaoCanto.criar(_root, top, audio_icon)
	var audio_hint: Label = audio[1]
	audio_hint.text = "Desativar" if Audio.som_ativo else "Ativar"
	_corner_setup(audio[0], func() -> void:
		Audio.definir_som_ativo(not Audio.som_ativo)
		audio_icon.set_active(Audio.som_ativo)
		audio_hint.text = "Desativar" if Audio.som_ativo else "Ativar")

	top += BotaoCanto.ESPACO
	var clock_icon := ClockIcon.new()
	clock_icon.set_running(not Dia.pausado)
	var clock: Array = BotaoCanto.criar(_root, top, clock_icon)
	clock_icon.position = Vector2(6, 6)
	clock_icon.size = Vector2(28, 28)
	_clock_hint = clock[1]
	# Só mostra a hora: parar o relógio desliga as conquistas da partida, e a
	# única porta para isso é a linha "Relógio" do menu do Esc, que avisa antes.
	_corner_setup(clock[0], func() -> void: Audio.efeito("ui_trava"), false)
	(clock[0] as Button).mouse_default_cursor_shape = Control.CURSOR_ARROW
	Dia.hora_mudou.connect(_update_clock_hint.unbind(1))

	top += BotaoCanto.ESPACO
	_map_icon = HudIcon.new().configurar("mapa")
	var map: Array = BotaoCanto.criar(_root, top, _map_icon)
	(map[1] as Label).text = "Mapa do Vale"
	_corner_setup(map[0], func() -> void: map_requested.emit())


	top += BotaoCanto.ESPACO
	_camera_icon = HudIcon.new().configurar("camera")
	var camera: Array = BotaoCanto.criar(_root, top, _camera_icon)
	_camera_lock_button = camera[0]
	_camera_hint = camera[1]
	_camera_lock_button.toggle_mode = true
	_camera_lock_button.focus_mode = Control.FOCUS_NONE
	_camera_lock_button.toggled.connect(func(locked: bool):
		Audio.efeito("ui_confirmar")
		camera_lock_requested.emit(locked))

	top += BotaoCanto.ESPACO
	_speed_icon = HudIcon.new().configurar("velocidade")
	var speed: Array = BotaoCanto.criar(_root, top, _speed_icon)
	_speed_hint = speed[1]
	_corner_setup(speed[0], func() -> void:
		Dia.definir_velocidade(Dia.proxima_velocidade())
		_update_telemetry())

	top += BotaoCanto.ESPACO
	var style_icon = HudIcon.new().configurar("estilo")
	style_icon.definir(Estilo.tripo())
	var style: Array = BotaoCanto.criar(_root, top, style_icon)
	(style[1] as Label).text = "FPS"
	_performance_button = style[0]
	_corner_setup(_performance_button, func() -> void:
		_performance_open = not _performance_open
		_sync_performance_panel())

	top += BotaoCanto.ESPACO
	_help_icon = HudIcon.new().configurar("ajuda")
	var help: Array = BotaoCanto.criar(_root, top, _help_icon)
	(help[1] as Label).text = "Controles"
	_corner_setup(help[0], func() -> void: set_controls_open(not controls_open()))
	set_camera_locked(_camera_locked)
	for index in range(first_child, _root.get_child_count()):
		_corner_nodes.append(_root.get_child(index))


## A largura menor troca a dica horizontal por um painel de leitura persistente.
## A posição acompanha a moldura do minimapa, sem depender da resolução da janela.
##
## O BOTÃO MOSTRA O FPS, e não um ícone. Ele levava o ícone de "estilo", que no
## estilo procedural é um par de chaves — e quem jogou viu "{}" no lugar do
## indicador: "o indicador de FPS não tá mostrando o FPS, está travado com {}".
## Agora o número vive no botão, refeito com o resto das medições
## (`_update_telemetry`); o clique continua abrindo o painel com o detalhe.
func _create_performance_button() -> void:
	_fps_label = Label.new()
	_fps_label.name = "FPS"
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fps_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fps_label.add_theme_font_override("font", Identidade.fonte_numeros(600))
	_fps_label.add_theme_font_size_override("font_size", 15)
	_fps_label.add_theme_color_override("font_color", Identidade.CREME)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_label.text = "--"
	var dados: Array = BotaoCanto.criar(_root, 32.0, _fps_label)
	# O canto põe ícone num quadrado de 24 no meio; o número usa o botão todo,
	# para "144" caber sem cortar.
	_fps_label.position = Vector2.ZERO
	_fps_label.size = Vector2(40, 40)
	(dados[1] as Label).text = "FPS"
	_performance_button = dados[0]
	_corner_setup(_performance_button, func() -> void:
		_performance_open = not _performance_open
		_sync_performance_panel())


func _create_performance_panel() -> void:
	_performance_panel = _panel(Color(0.055, 0.085, 0.075, 0.92))
	_performance_panel.name = "DadosDeDesempenho"
	_root.add_child(_performance_panel)
	_performance_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_performance_panel.offset_left = Minimapa.MARGEM
	_performance_panel.offset_right = Minimapa.MARGEM + 290.0
	_performance_panel.offset_bottom = -Minimapa.MARGEM - Minimapa.ALTURA - 8.0
	_performance_panel.offset_top = _performance_panel.offset_bottom - 108.0
	_performance_panel.visible = false
	_performance_label = _label("", 13, INK)
	_performance_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_performance_panel.add_child(_performance_label)
	_performance_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_performance_label.offset_left = 10.0
	_performance_label.offset_right = -10.0
	_performance_label.offset_top = 7.0
	_performance_label.offset_bottom = -7.0


func _sync_performance_panel() -> void:
	if is_instance_valid(_performance_panel):
		_performance_panel.visible = _performance_open and not controls_open() and not mapa_aberto


## Com o mapa aberto somem título, relógio, avisos e controles, e voltam como
## estavam. Antes ficava também a coluna de ícones do canto, com o do mapa em
## dourado — ela saiu para dentro do menu do Esc, e o mapa hoje se fecha pelo
## Esc ou pela mesma linha do menu que o abriu.
func set_map_open(open: bool) -> void:
	mapa_aberto = open
	if is_instance_valid(_map_icon):
		_map_icon.definir(open)
	if open:
		_hidden_for_map.clear()
		for child in _root.get_children():
			if child is Control and child.name == "VidaDoCoqueiro":
				child.visible = false
				continue
			if child is Control and child.visible and child != _menu_confirm and not _corner_nodes.has(child):
				_hidden_for_map.append(child)
				child.visible = false
	else:
		for child in _hidden_for_map:
			if is_instance_valid(child):
				child.visible = true
		_hidden_for_map.clear()
	_sync_performance_panel()


## Nó de UI em que o mapa põe os marcadores (atrás da coluna do canto).
func map_layer() -> Control:
	return _root


func settings_open() -> bool:
	return is_instance_valid(_settings)


## Ajustes dentro do jogo (painel_ajustes.gd sem as opções só do menu), num modal
## centrado sobre o vale pausado. Esc fecha a ajuda aberta ou o modal; clique fora fecha.
func open_settings() -> void:
	if settings_open():
		return
	var tema := TemaMenu.criar()
	var overlay := Sobreposicao.new()
	overlay.theme = tema
	_settings = overlay
	_root.add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close_settings())
	overlay.add_child(shade)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", TemaMenu.estilo_painel())
	box.custom_minimum_size = PainelAjustes.TAMANHO
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	overlay.add_child(box)
	var content := VBoxContainer.new()
	box.add_child(content)
	_ajustes = PainelAjustes.new(true)
	_ajustes.tema = tema
	_ajustes.fechar_pedido.connect(close_settings)
	_ajustes.estilo_mudou.connect(func() -> void: style_changed.emit())
	overlay.ao_esc = func() -> void:
		if _ajustes.ajuda_aberta():
			_ajustes.fechar_ajuda()
		else:
			close_settings()
	_ajustes.construir(content, overlay, 0)
	if is_instance_valid(_settings_icon):
		_settings_icon.definir(true)


func close_settings() -> void:
	if not settings_open():
		return
	_ajustes.fechar_ajuda()
	_settings.queue_free()
	_settings = null
	if is_instance_valid(_settings_icon):
		_settings_icon.definir(false)
	settings_closed.emit()


func menu_confirm_open() -> bool:
	return is_instance_valid(_menu_confirm)


## Confirmação de saída para o menu, na caixa de pergunta do vale
## (`caixa_de_pergunta.gd`), a mesma do relógio. Roda com o jogo pausado; Esc ou
## clique fora cancelam.
func open_menu_confirm() -> void:
	if menu_confirm_open():
		return
	_menu_confirm = CaixaDePergunta.new()
	_menu_confirm.perguntar(self, {
		"titulo": "Voltar ao menu?",
		"texto": "O passeio termina aqui. Ao entrar de novo, o dia recomeça.",
		"nao": "CONTINUAR",
		"sim": "IR AO MENU",
	})
	_menu_confirm.respondeu.connect(_close_menu_confirm)


func _close_menu_confirm(leave: bool) -> void:
	if not menu_confirm_open():
		return
	Audio.efeito("ui_confirmar" if leave else "ui_voltar")
	_menu_confirm.queue_free()
	_menu_confirm = null
	if leave:
		menu_requested.emit()
	else:
		menu_cancelled.emit()


## Tela de carregamento da volta ao menu, por cima de todo o HUD.
func show_loading() -> ProgressBar:
	return TelaCarregamento.mostrar(_root, TemaMenu.criar(), "Voltando ao menu…")


## Botões do HUD não roubam o foco do teclado (WASD, Espaço, Tab seguem com o jogador).
## Tocam o mesmo clique dos botões do menu (o relógio bloqueado troca pelo som de trava).
func _corner_setup(button: Button, action: Callable, click := true) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void:
		if click:
			Audio.efeito("ui_confirmar")
		action.call())


func _compact(value: float) -> String:
	if value >= 1000000.0:
		return "%.2f M" % (value / 1000000.0)
	if value >= 1000.0:
		return "%d mil" % int(value / 1000.0)
	return str(int(value))


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _place(control: Control, at: Vector2, dimensions: Vector2) -> void:
	_root.add_child(control)
	control.position = at
	control.size = dimensions


func _panel(color: Color) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	style.border_color = Color(0.58, 0.64, 0.48, 0.2)
	panel.add_theme_stylebox_override("panel", style)
	return panel


## A barra de mão do rodapé. O `Prototype` a usa para saber quando a mochila
## abre e fechar o vale por trás dela.
func barra_de_mao() -> Control:
	return _barra


## O almanaque das plantas. O `Prototype` o usa para pausar o vale quando ele
## abre, como faz com a mochila.
func almanaque() -> Control:
	return _almanaque


## QUANTO FALTA DA MISSÃO, ao lado do nome da região.
##
## Vinha colado no texto do objetivo — "Corte o capim  (3/9)" —, e a conta
## reaparecia no meio da frase a cada reanúncio. Separada, ela é um número que
## se olha de relance sem reler a missão. Com a cadeia terminada (indice >=
## total) some, em vez de mostrar "9/9" para sempre.
func set_mission_step(indice: int, total: int) -> void:
	if not is_instance_valid(_mission_step):
		return
	_mission_step.text = "" if total <= 0 or indice <= 0 or indice > total else "%d de %d" % [indice, total]
