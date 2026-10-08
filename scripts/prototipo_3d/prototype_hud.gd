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
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")


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
const PopupsDoMundo = preload("res://scripts/prototipo_3d/popups_do_mundo.gd")
var _espera_texto_desejado := ""

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
signal quests_requested
## Engrenagem do canto: pede os ajustes; `settings_closed` quando o modal fecha.
signal settings_requested
signal settings_closed
## Estilo visual trocado nos ajustes: o vale precisa ser reconstruído.
signal style_changed
signal camera_lock_requested(locked: bool)
signal house_info_close_requested
signal controls_requested
signal controls_closed

const INK := Color("e8e4d7")
const MUTED := Color("aebaae")
const GOLD := Color("d6ba78")
## Largura do painel do canto superior esquerdo (título, região e objetivo).
const HEADING_WIDTH := 360.0

var _model_status := "Preparando personagem…"
var _telemetry := ""
var _notice := ""
var _notice_revision := 0
var _notice_expiry: Tween
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
var _notice_panel: PanelContainer
var _objective_label: Label
var _heading: Panel
var _control_mode_label: Label
var _controls_overlay: Control
var _controls_panel: PanelContainer
var _controls_screen_open := false
var _help_icon	# hud_icon.gd
var _camera_lock_button: Button
var _clock_hint: Label
var _clock_button: Button
var _clock_icon
var _house_info_panel: Panel
var _house_info_label: Label
var _house_info_heading: Label
var _clock_label: Label
## A largura máxima do aviso do rodapé (#102): cabe entre o minimapa e os botões.
const LARGURA_DO_AVISO := 640.0
var _clock_panel: Panel
var _clock_estado: Label
## A altura do painel do relógio, e quanto cresce com a linha do estado.
const ALTURA_DO_RELOGIO := 72
const ALTURA_DO_ESTADO := 14
var _icones_medidores: Dictionary = {}
var _menu_confirm = null	# caixa_de_pergunta.gd
var _map_icon	# hud_icon.gd
var _settings_icon	# hud_icon.gd
var _settings: Control
var _ajustes	# painel_ajustes.gd
## Painéis escondidos enquanto o mapa está aberto (a coluna do canto continua).
var _hidden_for_map: Array[Control] = []
var _corner_nodes: Array[Node] = []
var _shortcut_badges: Dictionary = {}
var mapa_aberto := false


func _ready() -> void:
	layer = 20
	process_priority = 30 # Depois de posicionar falas e dicas.
	set_process_unhandled_key_input(true)
	_root = get_node_or_null("PrototypeHUD") as Control
	if _root == null:
		_root = Control.new()
		_root.name = "PrototypeHUD"
		add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# O BLOCO DA MISSÃO, e não o letreiro do jogo.
	#
	# Aqui ficava "MYTHS' VALLEY" em 28 px, ocupando o terço de cima de um
	# painel de 360×132 — o nome do jogo escrito na tela de quem já está
	# jogando. Saiu, e o que sobrou é o que o jogador precisa ler: onde ele
	# está, o que ele tem de fazer, e quanto falta.
	#
	# A missão ganhou o espaço e o corpo, com a linha do passo à direita do
	# rótulo, na borda do painel (o objetivo depois voltou a 15 px, #176). O painel encolheu junto — cabeçalho menor é
	# mais vale à vista.
	_heading = _panel(Color(0.055, 0.085, 0.075, 0.82))
	_heading.add_to_group(PopupsDoMundo.GRUPO_HUD)
	_place(_heading, Vector2(18, 18), Vector2(HEADING_WIDTH, 96))
	_region_label = _label("REGIÃO INICIAL", 12, GOLD)
	_place(_region_label, Vector2(33, 26), Vector2(HEADING_WIDTH - 130, 20))
	_mission_step = _label("", 12, GOLD)
	_mission_step.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# O contador encosta na mesma margem (15 px) que o rótulo da região tem à esquerda.
	_place(_mission_step, Vector2(18 + HEADING_WIDTH - 15 - 92, 26), Vector2(92, 20))
	_quest_label = _label("", 13, GOLD)
	_quest_label.name = "MissaoAcompanhada"
	_quest_label.clip_text = true
	_quest_label.visible = false
	_place(_quest_label, Vector2(33, 50), Vector2(HEADING_WIDTH - 30, 20))
	# O objetivo era bem maior que o título dourado: 15 px, não 17 (#176). Com o
	# painel em 80% por padrão, o texto na tela sai perto dos 12 px do título.
	_objective_label = _label(_objective, 15, INK)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# As etapas da missão (#186) levam "●"/"○", que a fonte padrão não desenha.
	_objective_label.add_theme_font_override("font", Identidade.fonte_do_hud())
	_place(_objective_label, Vector2(33, 52), Vector2(HEADING_WIDTH - 30, 42))
	# A bússola/minimapa é acrescentada depois do HUD e, por isso, fica por cima
	# dos controles no mesmo CanvasLayer. A tarefa precisa continuar legível ali.
	for control: Control in [_heading, _region_label, _mission_step, _objective_label, _quest_label]:
		control.z_index = 100

	# A COLUNA DE ÍCONES DO CANTO SAIU.
	#
	# Eram nove botões redondos empilhados na borda esquerda, por cima do vale,
	# o tempo todo: HOME, ajustes, som, relógio, mapa, câmera, velocidade,
	# estilo e controles. "Os ícones na esquerda do HUD podem ser todos dentro do
	# menu ESC" — e estão, em linhas com o estado escrito (`menu_pausa.gd`).
	#
	# `_create_corner_buttons` continua aqui, sem ser chamada, porque ela é a
	# receita dos ícones e do que cada um fazia — inclusive o das missões, que
	# abre a mesma aba do diário que o J abre. O FPS fica sozinho no canto, com
	# o número escrito nele.
	_create_performance_panel()
	_create_corner_buttons()
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

	# A mesma apresentação modal das telas do vale: fundo escurecido, caixa ao
	# centro e conteúdo rolável para janelas menores.
	_controls_overlay = Control.new()
	_controls_overlay.name = "ModalControles"
	_controls_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_controls_overlay.z_index = 100
	_controls_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_controls_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_controls_overlay)
	_controls_overlay.visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.03, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_controls_overlay.add_child(shade)
	_controls_panel = PanelContainer.new()
	_controls_panel.name = "CaixaControles"
	var controls_style := StyleBoxFlat.new()
	controls_style.bg_color = Color(0.055, 0.085, 0.075, 0.97)
	controls_style.border_color = GOLD
	controls_style.set_border_width_all(1)
	controls_style.set_corner_radius_all(10)
	controls_style.set_content_margin_all(18)
	_controls_panel.add_theme_stylebox_override("panel", controls_style)
	_controls_overlay.add_child(_controls_panel)
	var controls_column := VBoxContainer.new()
	controls_column.add_theme_constant_override("separation", 12)
	_controls_panel.add_child(controls_column)
	var controls_top := HBoxContainer.new()
	controls_column.add_child(controls_top)
	var controls_heading := _label("CONTROLES", 19, GOLD)
	controls_heading.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 500, 2))
	controls_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_top.add_child(controls_heading)
	var close_controls := Button.new()
	close_controls.name = "FecharControles"
	close_controls.text = "×"
	close_controls.tooltip_text = "Fechar controles"
	close_controls.custom_minimum_size = Vector2(32, 28)
	close_controls.focus_mode = Control.FOCUS_NONE
	controls_top.add_child(close_controls)
	close_controls.pressed.connect(func(): set_controls_open(false))
	var controls_scroll := ScrollContainer.new()
	controls_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	controls_column.add_child(controls_scroll)
	_control_mode_label = _label("", 17, INK)
	_control_mode_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_control_mode_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_scroll.add_child(_control_mode_label)
	_layout_controls_modal()
	get_viewport().size_changed.connect(_layout_controls_modal)

	# O AVISO (#102): a fala do Pedro, o que se recebeu, o que se entregou. Era
	# uma faixa de largura inteira no rodapé, atrás do minimapa e por cima do
	# "mão livre" da barra. Agora é uma caixa no meio, acima da barra de mão, de
	# até LARGURA_DO_AVISO, que quebra a linha e cresce para cima — na identidade
	# do vale, como a caixa de fala: a laca, o filete de ouro, a Cormorant.
	var estilo_do_aviso := StyleBoxFlat.new()
	estilo_do_aviso.bg_color = Color(Identidade.LACA, 0.94)
	estilo_do_aviso.border_color = Color(Identidade.OURO, 0.75)
	estilo_do_aviso.set_border_width_all(1)
	estilo_do_aviso.set_corner_radius_all(6)
	estilo_do_aviso.content_margin_left = 14.0
	estilo_do_aviso.content_margin_right = 14.0
	estilo_do_aviso.content_margin_top = 6.0
	estilo_do_aviso.content_margin_bottom = 6.0
	estilo_do_aviso.shadow_color = Color(0, 0, 0, 0.35)
	estilo_do_aviso.shadow_size = 5
	_notice_panel = PanelContainer.new()
	_notice_panel.name = "Aviso"
	_notice_panel.add_to_group(PopupsDoMundo.GRUPO_HUD)
	_notice_panel.set_meta("popup_prioridade", PopupsDoMundo.PRIORIDADE_AVISO)
	_notice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_panel.add_theme_stylebox_override("panel", estilo_do_aviso)
	_root.add_child(_notice_panel)
	# ACIMA DA BARRA DE MÃO, e a medida vem dela (`BarraDeMao.altura_ocupada`);
	# ancorada no rodapé e crescendo para cima conforme o texto.
	var acima := BarraDeMao.altura_ocupada()
	_notice_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_notice_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_notice_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_notice_panel.offset_left = -LARGURA_DO_AVISO * 0.5
	_notice_panel.offset_right = LARGURA_DO_AVISO * 0.5
	_notice_panel.offset_top = -acima - 8.0 - 30.0
	_notice_panel.offset_bottom = -acima - 8.0
	_notice_panel.visible = not _notice.is_empty()
	_notice_label = _label(_notice, 16, Identidade.TEXTO)
	_notice_label.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 600))
	_notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notice_panel.add_child(_notice_label)

	# Relógio do vale: só a hora e o período do dia.
	_clock_panel = _panel(Color(0.055, 0.085, 0.075, 0.82))
	_clock_panel.name = "RelogioCompacto"
	_root.add_child(_clock_panel)
	_clock_panel.add_to_group("obstaculos_do_hud")
	_clock_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_clock_panel.offset_left = -70
	_clock_panel.offset_right = 70
	_clock_panel.offset_top = 18
	_clock_panel.offset_bottom = ALTURA_DO_RELOGIO
	_clock_label = _label("", 12, GOLD)
	_clock_panel.add_child(_clock_label)
	_clock_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_clock_label.offset_left = 26
	var mostrador := ClockIcon.new()
	_clock_panel.add_child(mostrador)
	mostrador.position = Vector2(7, 14)
	mostrador.size = Vector2(20, 20)
	mostrador.set_running(true)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# O ESTADO DO RELÓGIO (#100): "parado" pela pausa do jogador, ou quem o
	# segura — fala, tela, conquista, narração —, para o dia parado ter motivo
	# na tela. Vazio com o dia andando.
	_clock_estado = _label("", 10, Color(0.85, 0.7, 0.36, 0.95))
	_clock_estado.name = "EstadoDoRelogio"
	_clock_panel.add_child(_clock_estado)
	_clock_estado.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_clock_estado.offset_top = -16
	_clock_estado.offset_bottom = -3
	_clock_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_estado.visible = false

	_criar_barra_de_vida()
	_criar_barra_de_folego()
	_criar_barra_de_stamina()
	for dado in [[barra_vida, "vida"], [barra_folego, "reserva"], [barra_stamina, "vigor"]]:
		var icone = HudIcon.new().configurar(dado[1])
		dado[0].add_child(icone)
		icone.position = Vector2(2, 0)
		icone.scale = Vector2.ONE * 0.75
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icones_medidores[dado[1]] = icone
	_layout_medidores()
	get_viewport().size_changed.connect(_layout_medidores)

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

	# Como o painel de Missões, o almanaque tem camada própria acima do HUD.
	# O minimapa e as plaquinhas entram depois na raiz, mas ficam sob a cortina.
	var almanaque_layer := CanvasLayer.new()
	almanaque_layer.name = "CamadaAlmanaque"
	almanaque_layer.layer = 25
	add_child(almanaque_layer)
	var almanaque := Almanaque.new()
	almanaque.name = "Almanaque"
	almanaque_layer.add_child(almanaque)
	_almanaque = almanaque

	_agrupar_componente([_heading, _region_label, _mission_step, _quest_label, _objective_label], "missao", Vector2(18, 18))
	_agrupar_componente([_notice_panel], "avisos", Vector2(_root.size.x * 0.5, _root.size.y - BarraDeMao.altura_ocupada()))
	var foco = load("res://scripts/prototipo_3d/foco_da_narracao.gd").new()
	foco.hud = self
	_root.add_child(foco)
	Tela.componentes_mudaram.connect(_layout_medidores)
	Tela.componentes_mudaram.connect(_layout_notice)
	get_viewport().size_changed.connect(_layout_notice)
	Tela.vincular_componente(_clock_panel, "relogio")
	for dado in [[barra_vida, "vida"], [barra_folego, "folego"], [barra_stamina, "vigor"]]:
		Tela.vincular_componente(dado[0], dado[1])
	_update_control_mode()
	_update_telemetry()


## A VIDA, logo abaixo do relógio, com as cores do 2D (`scripts/ui/hud.gd`):
## vermelha sempre, porque é sangue e não fôlego; verde-musgo enquanto a
## peçonha corre, que é o aviso de que ela está descendo sozinha.
##
## É widget ACRESCENTADO, como a migração manda: o HUD continua sendo este, e
## não o do 2D. O número vem do `Vida` compartilhado — por `get_node_or_null`,
## porque quem monta o HUD sozinho, sem o projeto inteiro, não pode estourar
## aqui. A barra verde do corte das árvores fica embaixo, na mesma medida.
const COR_VIDA := Color(0.78, 0.28, 0.26)
const COR_VIDA_ENVENENADA := Color(0.45, 0.62, 0.22)
var barra_vida: ProgressBar
var _vida_texto: Label
var _vida_preenchimento: StyleBoxFlat
var barra_stamina: ProgressBar
var _stamina_texto: Label
var _stamina_preenchimento: StyleBoxFlat
var _textos_medidores: Dictionary = {}
## O indicador da maré ao lado do relógio (`hud_3d.json`, "mare"): diz se a água enche ou vaza, nos três idiomas.
var _textos_mare: Dictionary = {}


func _criar_barra_de_vida() -> void:
	var dados = JSON.parse_string(FileAccess.get_file_as_string("res://data/hud_3d.json"))
	if dados is Dictionary:
		_textos_medidores = dados.get("medidores", {})
		_textos_mare = dados.get("mare", {})
	barra_vida = ProgressBar.new()
	barra_vida.name = "Vida"
	barra_vida.step = 0.01
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
	barra_vida.add_to_group("obstaculos_do_hud")
	barra_vida.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	barra_vida.offset_left = -110
	barra_vida.offset_right = 110
	barra_vida.offset_top = 78
	barra_vida.offset_bottom = 98
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
	_vida_texto.text = _texto_medidor("vida", barra_vida)
	_vida_preenchimento.bg_color = COR_VIDA_ENVENENADA if vida.envenenado_agora() else COR_VIDA


## OS TRÊS MEDIDORES DO CORPO (#82), abaixo da vida e na mesma medida.
##
## A BARRA DO MEIO é a RESERVA DO DIA — o `Energia` compartilhado, o fôlego do
## 2D: enxada, machado, picareta, lavoura e luta gastam dela, e só comida, cama
## e desmaio devolvem. Mostra SÓ O NÚMERO, como o Pedro ensina ("a do meio, só
## com o número"); abaixo do limiar do `Energia` fica vermelha e diz "cansado" —
## o passo encurta e a corrida não responde (ver `Energia.cansou`), e sem o
## aviso quem joga pensa que o jogo travou.
##
## NA ÁGUA a mesma barra vira o FÔLEGO DO NADO, azul ("a azul, a do meio, é o
## fôlego: o ar de quem nada"): o ar do corpo, que o jogador guarda
## (`folego_atual`). O nado gasta o vigor primeiro e depois o fôlego, e sem
## fôlego a água tira da vida ("afogamento"). Ao sair da água a barra volta à
## reserva (`nado_mudou`).
##
## A BARRA DE BAIXO é o VIGOR, o fôlego curto do corpo (`vigor_atual`): corrida,
## pulo e golpe gastam, e ele volta sozinho. Baixo, fica âmbar — a palavra
## "cansado" é da reserva.
##
## Entre 04/10 e 06/10 a reserva e o vigor foram UMA conta (`Energia.registrar_vigor`,
## `8413ae7`): o vigor voltava sozinho e a comida perdeu o sentido. Decisão do
## autor em 06/10: a reserva volta a ser a que sempre foi.
const COR_RESERVA := Color("c9a24a")
const COR_RESERVA_BAIXA := Color(0.9, 0.42, 0.34)
const COR_FOLEGO := Color("398fd2")
const COR_VIGOR := Color("56ad67")
const COR_MEDIDOR_BAIXO := Color("bd803e")
var barra_folego: ProgressBar
var _folego_texto: Label
var _folego_preenchimento: StyleBoxFlat
## O jogador: de quem vêm o vigor, o fôlego do nado e o aviso de que entrou na água.
var _jogador_corpo: Node
## Nadando, a barra do meio é o fôlego do nado; em terra, a reserva do dia.
var _nadando := false


func _criar_barra_de_folego() -> void:
	barra_folego = ProgressBar.new()
	barra_folego.name = "Folego"
	barra_folego.step = 0.01
	barra_folego.show_percentage = false
	# Transparente ao mouse, como a da vida.
	barra_folego.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra_folego.add_theme_stylebox_override("background", barra_vida.get_theme_stylebox("background"))
	_folego_preenchimento = StyleBoxFlat.new()
	_folego_preenchimento.bg_color = COR_FOLEGO
	_folego_preenchimento.set_corner_radius_all(6)
	barra_folego.add_theme_stylebox_override("fill", _folego_preenchimento)
	_root.add_child(barra_folego)
	barra_folego.add_to_group("obstaculos_do_hud")
	barra_folego.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	barra_folego.offset_left = -110
	barra_folego.offset_right = 110
	barra_folego.offset_top = 102
	barra_folego.offset_bottom = 122
	_folego_texto = _label("", 11, INK)
	barra_folego.add_child(_folego_texto)
	_folego_texto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_folego_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_folego_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	barra_folego.visible = true
	# Em terra a barra é a reserva: ouve o `Energia` desde o nascimento, com ou
	# sem jogador (o portão do fôlego instancia o HUD sozinho).
	var energia := get_node_or_null("/root/Energia")
	if energia != null:
		energia.mudou.connect(_atualizar_folego)
	_atualizar_folego()


## O HUD ouve o jogador: o vigor, o fôlego do nado, e a entrada e a saída da água.
func configurar_corpo(jogador: Node) -> void:
	if is_instance_valid(_jogador_corpo):
		_desligar(_jogador_corpo, "vigor_mudou", _atualizar_vigor)
		_desligar(_jogador_corpo, "folego_mudou", _atualizar_folego)
		_desligar(_jogador_corpo, "nado_mudou", _ao_mudar_o_nado)
	_jogador_corpo = jogador
	jogador.connect("vigor_mudou", _atualizar_vigor)
	jogador.connect("folego_mudou", _atualizar_folego)
	jogador.connect("nado_mudou", _ao_mudar_o_nado)
	_nadando = jogador.has_method("is_swimming") and bool(jogador.call("is_swimming"))
	_atualizar_folego()
	_atualizar_vigor()


func _desligar(de: Node, sinal: String, para: Callable) -> void:
	if de.is_connected(sinal, para):
		de.disconnect(sinal, para)


## Entrou na água, ou saiu dela: a barra do meio troca de conta.
func _ao_mudar_o_nado(nadando: bool) -> void:
	_nadando = nadando
	_atualizar_folego()


func _atualizar_folego(_valor: float = 0.0) -> void:
	if barra_folego == null:
		return
	if _nadando and is_instance_valid(_jogador_corpo):
		barra_folego.max_value = float(_jogador_corpo.call("folego_maximo"))
		barra_folego.value = float(_jogador_corpo.call("folego_atual"))
		_folego_texto.text = _texto_medidor("folego", barra_folego)
		var baixo := barra_folego.value <= barra_folego.max_value * 0.2
		_folego_preenchimento.bg_color = COR_MEDIDOR_BAIXO if baixo else COR_FOLEGO
		if baixo:
			_folego_texto.text += " · " + str(IdiomaMenu.campo(_textos_medidores, "afogamento"))
		return
	var energia := get_node_or_null("/root/Energia")
	if energia == null:
		return
	barra_folego.max_value = energia.maximo()
	barra_folego.value = energia.atual
	barra_folego.tooltip_text = str(IdiomaMenu.campo(_textos_medidores, "reserva"))
	var cansado: bool = energia.cansado()
	_folego_texto.text = str(roundi(energia.atual))
	if cansado:
		_folego_texto.text += " · " + str(IdiomaMenu.campo(_textos_medidores, "cansado"))
	_folego_preenchimento.bg_color = COR_RESERVA_BAIXA if cansado else COR_RESERVA


func _criar_barra_de_stamina() -> void:
	barra_stamina = ProgressBar.new()
	barra_stamina.name = "Stamina"
	barra_stamina.step = 0.01
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
	_stamina_preenchimento = StyleBoxFlat.new()
	_stamina_preenchimento.bg_color = COR_VIGOR
	_stamina_preenchimento.set_corner_radius_all(6)
	barra_stamina.add_theme_stylebox_override("fill", _stamina_preenchimento)
	_root.add_child(barra_stamina)
	barra_stamina.add_to_group("obstaculos_do_hud")
	barra_stamina.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	barra_stamina.offset_left = -110
	barra_stamina.offset_right = 110
	barra_stamina.offset_top = 126
	barra_stamina.offset_bottom = 146
	_stamina_texto = _label("", 11, INK)
	barra_stamina.add_child(_stamina_texto)
	_stamina_texto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stamina_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamina_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_atualizar_vigor()


func _agrupar_componente(controles: Array, chave: String, pivo: Vector2) -> void:
	var grupo := Control.new()
	grupo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(grupo)
	grupo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for controle: Control in controles:
		controle.reparent(grupo, false)
	var aplicar := func() -> void:
		grupo.pivot_offset = Vector2(_root.size.x * 0.5, _root.size.y - BarraDeMao.altura_ocupada()) if chave == "avisos" else pivo
		grupo.scale = Vector2.ONE * Tela.escala_componente(chave)
	Tela.componentes_mudaram.connect(aplicar)
	grupo.resized.connect(aplicar)
	aplicar.call()


func _layout_medidores() -> void:
	if not is_instance_valid(_clock_panel) or not is_instance_valid(barra_stamina):
		return
	var largura := _root.size.x
	# Missao termina em 378; atalhos comecam a 78 da borda direita.
	var esquerda := 18.0 + HEADING_WIDTH * Tela.escala_componente("missao") + 12.0
	var relogio := 100.0 * Tela.escala_componente("relogio")
	var barras := 160.0 * maxf(Tela.escala_componente("vida"), maxf(Tela.escala_componente("folego"), Tela.escala_componente("vigor")))
	var inicio := maxf(esquerda, (largura - relogio - barras - 8.0) * 0.5)
	var topo := 18.0
	if inicio + relogio + barras + 8.0 > largura - 90.0:
		inicio = 18.0
		topo = 18.0 + _heading.size.y * Tela.escala_componente("missao") + 12.0
	_clock_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_clock_panel.position = Vector2(inicio, topo)
	# Cresce ALTURA_DO_ESTADO quando a linha do estado ("parado") aparece.
	_clock_panel.size = Vector2(100, 52 + (ALTURA_DO_ESTADO if is_instance_valid(_clock_estado) and _clock_estado.visible else 0))
	var indice := 0
	var altura := topo
	for barra: ProgressBar in [barra_vida, barra_folego, barra_stamina]:
		barra.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		barra.position = Vector2(inicio + relogio + 8.0, altura)
		barra.size = Vector2(160, 18)
		altura += 18.0 * Tela.escala_componente(["vida", "folego", "vigor"][indice]) + 2.0
		indice += 1
	for texto: Label in [_vida_texto, _folego_texto, _stamina_texto]:
		texto.offset_left = 22
		texto.add_theme_font_size_override("font_size", 10)


func _texto_medidor(chave: String, barra: ProgressBar) -> String:
	barra.tooltip_text = str(IdiomaMenu.campo(_textos_medidores, chave))
	return "%d/%d" % [roundi(barra.value), roundi(barra.max_value)]


## O vigor vem do jogador; sem jogador (o HUD sozinho num portão), a barra fica cheia.
func _atualizar_vigor(_valor: float = 0.0) -> void:
	if barra_stamina == null:
		return
	if is_instance_valid(_jogador_corpo):
		barra_stamina.max_value = float(_jogador_corpo.call("vigor_maximo"))
		barra_stamina.value = float(_jogador_corpo.call("vigor_atual"))
	_stamina_texto.text = _texto_medidor("vigor", barra_stamina)
	var baixo := barra_stamina.value <= barra_stamina.max_value * 0.2
	_stamina_preenchimento.bg_color = COR_MEDIDOR_BAIXO if baixo else COR_VIGOR


func _process(delta: float) -> void:
	_sincronizar_prioridade_dos_avisos()
	_refresh_time += delta
	if _refresh_time >= 0.35:
		_refresh_time = 0.0
		_update_telemetry()
		_update_clock_state()


## O ESTADO DO RELÓGIO ao lado da hora (#100): a pausa do jogador, ou o motivo
## que o segura; nada com o dia andando. Quem para a árvore (as telas) chama
## `atualizar_estado_do_relogio` na hora, porque este `_process` para junto.
func atualizar_estado_do_relogio() -> void:
	_update_clock_state()


func _update_clock_state() -> void:
	if not is_instance_valid(_clock_estado):
		return
	# SÓ A PAUSA DO JOGADOR TEM RÓTULO (07/10). Os motivos que seguram o relógio —
	# a fala, a tela, a festa, a narração — estão na tela por si: escrever "fala"
	# ao lado da hora era ruído, e a barra da vida cobria a palavra. Quem quiser o
	# motivo ainda o tem em `Dia.motivos_da_segurada` e em `texto_do_motivo`.
	var estado := ""
	if Dia.pausado or Dia.velocidade == 0:
		estado = tr("parado")
	if estado != _clock_estado.text or _clock_estado.visible != (estado != ""):
		_clock_estado.text = estado
		_clock_estado.visible = estado != ""
		_layout_medidores()
		_update_clock_hint()


## O motivo de `Dia.segurar` em palavra do jogador: "fala:tonho" é fala.
func texto_do_motivo(motivo: String) -> String:
	if motivo.begins_with("fala"):
		return tr("fala")
	if motivo.begins_with("tela"):
		return tr("tela")
	if motivo.begins_with("conquista"):
		return tr("conquista")
	if motivo.begins_with("narracao"):
		return tr("narração")
	return motivo


func set_model_status(value: String) -> void:
	_model_status = value
	_update_telemetry()


## Avisos cedem apenas onde uma fala ou interação precisa do mesmo espaço.
## A intenção vem do texto atual; fechar uma fala nunca revive aviso expirado.
func _sincronizar_prioridade_dos_avisos() -> void:
	var permitido := not mapa_aberto and not controls_open()
	var superiores := PopupsDoMundo.retangulos_dos_baloes(self)
	superiores.append_array(PopupsDoMundo.retangulos(self, PopupsDoMundo.GRUPO_DICAS))
	var essenciais := PopupsDoMundo.retangulos(self, PopupsDoMundo.GRUPO_HUD, null, PopupsDoMundo.PRIORIDADE_HUD)
	if is_instance_valid(_espera_panel):
		_espera_panel.position.y = 154.0
		# O aviso segue abaixo dos componentes maiores, antes de disputar com
		# as falas do mundo. Sua função permanece legível com uma missão ampliada.
		for caixa in essenciais:
			if caixa.intersects(_espera_panel.get_global_rect()):
				_espera_panel.position.y = caixa.end.y + 12.0
	superiores.append_array(essenciais)
	if is_instance_valid(_notice_panel):
		var livre := true
		for caixa in superiores:
			if caixa.intersects(_notice_panel.get_global_rect()):
				livre = false
		_notice_panel.visible = permitido and not _notice.is_empty() and livre
		_notice_label.visible = _notice_panel.visible
	if is_instance_valid(_espera_panel):
		var livre := true
		for caixa in superiores:
			if caixa.intersects(_espera_panel.get_global_rect()):
				livre = false
		_espera_panel.visible = permitido and not _espera_texto_desejado.is_empty() and livre


func set_region_title(value: String) -> void:
	if is_instance_valid(_region_label):
		_region_label.text = value.to_upper()


func set_telemetry(value: String) -> void:
	_telemetry = value
	_update_telemetry()


## Avisos de recebimento e resultado têm prazo próprio. Repetir o mesmo aviso
## enquanto ele está no ar não reinicia o prazo; o prazo antigo nunca limpa outro.
func _layout_notice() -> void:
	if is_instance_valid(_notice_label):
		_notice_label.text = _notice
		_notice_panel.visible = not _notice.is_empty()
		# A caixa se mede pelo texto: curta para um aviso curto, até a largura
		# máxima (LARGURA_DO_AVISO, ou o que a janela e a escala dos avisos deixam)
		# para a fala do Pedro, que então quebra a linha e cresce para cima — o
		# rótulo mora dentro da caixa, e ela acompanha a altura dele.
		var font := _notice_label.get_theme_font("font")
		var largura := minf(LARGURA_DO_AVISO, maxf(160.0, _root.get_viewport_rect().size.x * 0.68 / Tela.escala_componente("avisos")))
		var half := minf(font.get_string_size(_notice, HORIZONTAL_ALIGNMENT_LEFT, -1, _notice_label.get_theme_font_size("font_size")).x * 0.5 + 30.0, largura * 0.5)
		var acima := BarraDeMao.altura_ocupada()
		_notice_panel.offset_left = -half
		_notice_panel.offset_right = half
		_notice_panel.offset_top = -acima - 8.0 - 30.0
		_notice_panel.offset_bottom = -acima - 8.0


func set_notice(value: String, segundos: float = -1.0) -> void:
	if value == _notice:
		return
	_notice_revision += 1
	if _notice_expiry != null and _notice_expiry.is_valid():
		_notice_expiry.kill()
	_notice = value
	_layout_notice()
	if not value.is_empty() and is_inside_tree():
		var prazo := segundos if segundos >= 0.0 else maxf(4.0, float(value.length()) / 15.0 + 1.0)
		var revisao := _notice_revision
		# Vinculado ao HUD: pausa junto do vale e é descartado ao sair da cena.
		_notice_expiry = create_tween()
		_notice_expiry.tween_interval(maxf(prazo, 0.1))
		_notice_expiry.tween_callback(func() -> void:
			if _notice_revision == revisao:
				set_notice(""))


## O AVISO DE QUEM FICOU PARA TRÁS na condução: "o Pedro está esperando você".
## "Quando a missão tiver que seguir um NPC, como o Pedro no inicio, e o
## jogador se afastar ao ponto do NPC parar, deve aparecer um aviso em tela
## informando para se reaproximar do NPC." Fica no alto, abaixo do relógio,
## enquanto o guia espera (`guia_pedro.esperando_quem_ficou`), e some quando o
## jogador volta. É painel próprio, e não o aviso do rodapé: o rodapé troca a
## cada coisa que acontece — o que se ganhou, o que se recusou —, e este tem de
## durar o tempo que a espera durar. Texto vazio esconde.
var _espera_panel: PanelContainer
var _espera_label: Label
var _espera_tween: Tween


func set_aviso_de_espera(texto: String) -> void:
	_espera_texto_desejado = texto
	if _espera_panel == null:
		_criar_aviso_de_espera()
	if _espera_tween != null:
		_espera_tween.kill()
	_espera_tween = _espera_panel.create_tween()
	if texto.is_empty():
		_espera_tween.tween_property(_espera_panel, "modulate:a", 0.0, 0.35)
		_espera_tween.tween_callback(func() -> void: _espera_panel.visible = false)
		return
	_espera_label.text = texto
	_espera_panel.visible = true
	_espera_tween.tween_property(_espera_panel, "modulate:a", 1.0, 0.35)


## O texto do aviso de espera na tela agora, ou "" (para o portão).
func aviso_de_espera() -> String:
	return _espera_label.text if _espera_panel != null and _espera_panel.visible else ""


func _criar_aviso_de_espera() -> void:
	_espera_panel = PanelContainer.new()
	_espera_panel.name = "AvisoDeEspera"
	_espera_panel.set_meta("popup_prioridade", PopupsDoMundo.PRIORIDADE_AVISO)
	_espera_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.055, 0.085, 0.075, 0.9)
	estilo.set_corner_radius_all(10)
	estilo.set_border_width_all(1)
	estilo.border_color = Color(GOLD, 0.7)
	estilo.content_margin_left = 20.0
	estilo.content_margin_right = 20.0
	estilo.content_margin_top = 8.0
	estilo.content_margin_bottom = 9.0
	_espera_panel.add_theme_stylebox_override("panel", estilo)
	_espera_label = _label("", 15, INK)
	_espera_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_espera_panel.add_child(_espera_label)
	_root.add_child(_espera_panel)
	Tela.vincular_componente(_espera_panel, "avisos", Vector2(0.5, 0))
	_espera_panel.add_to_group("obstaculos_do_hud")
	# No meio, abaixo do relógio (18 a 72) e das três barras do corpo embaixo
	# dele (a do vigor vai até 146), com um respiro, e crescendo para os dois
	# lados com o texto.
	_espera_panel.anchor_left = 0.5
	_espera_panel.anchor_right = 0.5
	_espera_panel.offset_top = 154.0
	_espera_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_espera_panel.modulate.a = 0.0
	_espera_panel.visible = false


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
	_heading.visible = true
	_objective_label.visible = true
	if is_instance_valid(_quest_label):
		_quest_label.text = ("◆  " + missao.to_upper()) if missao != "" else ""
		_quest_label.visible = missao != ""
	if is_instance_valid(_objective_label):
		_objective_label.text = value
		_fit_heading()


## O ALTO DA TELA DIZ A TAREFA (#83), e só ela: o nome da missão, o resumo do
## passo com a conta e "n de N" (`set_objective`, `set_mission_step`). Entre
## 04/10 e 06/10 ele recebia as PÁGINAS com a fala inteira de todos os passos —
## inclusive os que ainda não tinham aberto —, com setas e um X para fechar; a
## fala cobria a tarefa, e o X escondia o quadro inteiro. A fala fica no balão e
## no painel J, que é onde se lê.


## O DESTAQUE DE UMA BARRA (#106): quando o Pedro explica o corpo, a tela
## escurece — um véu entre o mundo e a caixa de fala, na camada CAMADA_DO_VEU —
## e o HUD apaga tudo menos a barra da vez ("Vida", "Folego", "Stamina"; vazio
## apaga tudo, que é o respiro). `apagar_destaque` devolve tudo.
const CAMADA_DO_VEU := 5
const APAGADO := Color(0.3, 0.3, 0.3, 1.0)
var _veu_do_destaque: CanvasLayer
var _destacada := ""
var _destacando := false


func destacar_barra(nome: String) -> void:
	if _veu_do_destaque == null:
		_veu_do_destaque = CanvasLayer.new()
		_veu_do_destaque.name = "VeuDoDestaque"
		_veu_do_destaque.layer = CAMADA_DO_VEU
		var escuro := ColorRect.new()
		escuro.name = "Escuro"
		escuro.color = Color(0.0, 0.0, 0.0, 0.68)
		escuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
		escuro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_veu_do_destaque.add_child(escuro)
		add_child(_veu_do_destaque)
	_veu_do_destaque.visible = true
	_destacando = true
	_destacada = nome
	for filho in _root.get_children():
		if filho is CanvasItem:
			(filho as CanvasItem).modulate = Color.WHITE if String(filho.name) == nome else APAGADO


func apagar_destaque() -> void:
	if not _destacando:
		return
	_destacando = false
	_destacada = ""
	if _veu_do_destaque != null:
		_veu_do_destaque.visible = false
	for filho in _root.get_children():
		if filho is CanvasItem:
			(filho as CanvasItem).modulate = Color.WHITE


## A barra acesa agora ("" com tudo apagado, ou sem destaque).
func barra_destacada() -> String:
	return _destacada


func destacando() -> bool:
	return _destacando


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
			var preferencia = load("res://scripts/prototipo_3d/camera_mouse.gd")
			var textos: Dictionary = Jogo.dados("res://data/camera_modos.json")
			_camera_hint.text = IdiomaMenu.campo(textos, "indicar") % [preferencia.rotulo(), Atalhos.letra("camera")]
	_update_control_mode()


## Texto do painel de controles, um comando por linha; a linha da câmera muda com o modo.
func _update_control_mode() -> void:
	if not is_instance_valid(_control_mode_label):
		return
	var preferencia = load("res://scripts/prototipo_3d/camera_mouse.gd")
	var mode: String = preferencia.rotulo()
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
		"Rodinha: zoom  ·  1 a 0: item da mão  ·  %s: avança a hora" % Atalhos.letra("hora"),
		"%s: reinicia  ·  %s: mapa · minimapa em AJUSTAR" % [Atalhos.letra("reiniciar"), Atalhos.letra("mapa")],
	])


func _layout_controls_modal() -> void:
	if not is_instance_valid(_controls_panel):
		return
	var screen := get_viewport().get_visible_rect().size
	var dimensions := Vector2(minf(900.0, screen.x - 48.0), minf(520.0, screen.y - 48.0))
	_controls_panel.position = (screen - dimensions) * 0.5
	_controls_panel.size = dimensions


## Altura do texto de um rótulo com quebra de linha, contando o espaço entre linhas.
func _text_height(label: Label) -> float:
	var lines := maxi(1, label.get_line_count())
	return lines * label.get_line_height() + (lines - 1) * label.get_theme_constant("line_spacing")


func controls_open() -> bool:
	return _controls_screen_open or (is_instance_valid(_controls_overlay) and _controls_overlay.visible)


func set_controls_screen_open(open: bool) -> void:
	_controls_screen_open = open
	_sync_performance_panel()


## Modal de controles; o dono das telas do vale cuida da pausa e do Esc.
func set_controls_open(open: bool) -> void:
	if controls_open() == open:
		return
	_controls_overlay.visible = open
	if is_instance_valid(_help_icon):
		_help_icon.definir(open)
	_sync_performance_panel()
	if open:
		_update_control_mode()
	else:
		controls_closed.emit()


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
	# A coluna é criada junto do HUD; as guardas também cobrem sua desmontagem.
	if is_instance_valid(_speed_icon):
		_speed_icon.definir(false, Dia.velocidade)
	if is_instance_valid(_speed_hint):
		_speed_hint.text = "Tempo: %s · clique para mudar" % String(Dia.ROTULOS_VELOCIDADE[Dia.velocidade])
	_update_clock_hint()


func _update_clock_hint() -> void:
	if not is_instance_valid(_clock_hint):
		return
	var andando: bool = not Dia.pausado and Dia.velocidade > 0 and not Dia.segurado()
	if is_instance_valid(_clock_icon):
		_clock_icon.set_running(andando)
	if is_instance_valid(_clock_button):
		_clock_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not andando or Dia.pausa_no_jogo else Control.CURSOR_ARROW
	var texto := Dia.texto_hora()
	if not andando:
		texto = "%s · Retomar" % texto
	elif Dia.pausa_no_jogo:
		texto = "%s · Pausar" % texto
	# A MARÉ, ao lado da hora: com ela ligada, a dica diz se a água sobe ou desce (e o que isso faz na praia).
	var mare := _texto_da_mare("")
	if mare != "":
		texto += " · " + mare
	_clock_hint.text = texto
	if is_instance_valid(_clock_button):
		_clock_button.tooltip_text = _texto_da_mare("dica_")


## A frase curta da maré, enchente ou vazante (ou a dica longa, com `prefixo` "dica_"), no idioma do jogador; "" com a maré desligada.
func _texto_da_mare(prefixo: String) -> String:
	if Mare.modo == 0 or _textos_mare.is_empty():
		return ""
	return str(IdiomaMenu.campo(_textos_mare, prefixo + ("enchente" if Mare.enchente() else "vazante")))


## O painel do canto esquerdo cresce só o necessário para o objetivo caber.
func _fit_heading() -> void:
	if not is_instance_valid(_heading):
		return
	var lines := maxi(1, _objective_label.get_line_count())
	# 52 é o y ABSOLUTO onde o texto começa (ver `_montar`; o painel fica em y=18,
	# então são 34 px abaixo do topo dele); com o nome da missão em cima, ele
	# desce 22. 14 de respiro embaixo: o painel abraça o texto.
	var topo := 52.0 + (22.0 if _missao != "" else 0.0)
	_objective_label.position.y = _heading.position.y + topo - 18.0
	var altura_texto := lines * _objective_label.get_line_height()
	_objective_label.size.y = altura_texto
	var altura := topo - 18.0 + altura_texto + 14.0
	_heading.size.y = altura
	if is_instance_valid(_house_info_panel):
		_house_info_panel.position.y = 18.0 + altura * Tela.escala_componente("missao") + 12.0
	_layout_medidores()


## Coluna de botões redondos: HOME, som e relógio na mesma posição do menu, depois
## câmera, velocidade do tempo e dados de desempenho.
func _create_corner_buttons() -> void:
	var first_child := _root.get_child_count()
	var top := 0
	var home: Array = BotaoCanto.criar(_root, top, HudIcon.new().configurar("casa"))
	(home[1] as Label).text = "HOME · voltar ao menu"
	_corner_setup(home[0], func() -> void: menu_prompt_requested.emit())

	top += 1
	_settings_icon = HudIcon.new().configurar("ajustes")
	var settings: Array = BotaoCanto.criar(_root, top, _settings_icon)
	(settings[1] as Label).text = "Ajustes"
	_corner_setup(settings[0], func() -> void: settings_requested.emit())

	top += 1
	var audio_icon := AudioToggleIcon.new()
	audio_icon.set_active(Audio.som_ativo)
	var audio: Array = BotaoCanto.criar(_root, top, audio_icon)
	var audio_hint: Label = audio[1]
	audio_hint.text = "Desativar" if Audio.som_ativo else "Ativar"
	_corner_setup(audio[0], func() -> void:
		Audio.definir_som_ativo(not Audio.som_ativo)
		audio_icon.set_active(Audio.som_ativo)
		audio_hint.text = "Desativar" if Audio.som_ativo else "Ativar")

	top += 1
	var clock_icon := ClockIcon.new()
	clock_icon.set_running(not Dia.pausado)
	var clock: Array = BotaoCanto.criar(_root, top, clock_icon, 28.0)
	_clock_icon = clock_icon
	_clock_button = clock[0]
	_clock_hint = clock[1]
	_corner_setup(clock[0], func() -> void:
		if Dia.velocidade == 0:
			Dia.definir_velocidade(2)
			Dia.pausado = false
		elif Dia.pausado:
			Dia.pausado = false
		elif Dia.pausa_no_jogo:
			Dia.pausado = true
		else:
			Audio.efeito("ui_trava")
			return
		Audio.efeito("ui_confirmar")
		_update_telemetry(), false)
	_update_clock_hint()
	Dia.hora_mudou.connect(_update_clock_hint.unbind(1))
	Mare.mare_mudou.connect(_update_clock_hint.unbind(1))

	top += 1
	_map_icon = HudIcon.new().configurar("mapa")
	var map: Array = BotaoCanto.criar(_root, top, _map_icon)
	(map[1] as Label).text = "Mapa do Vale"
	_shortcut_badges["mapa"] = BotaoCanto.marcar_atalho(map[0], Atalhos.letra("mapa"))
	_corner_setup(map[0], func() -> void: map_requested.emit())

	# TELA CHEIA na mesma vaga do menu (logo abaixo do mapa), com o mesmo código.
	top += 1
	var tela: Array = BotaoCanto.criar_tela_cheia(_root, top)
	(tela[0] as Button).focus_mode = Control.FOCUS_NONE

	top += 1
	_camera_icon = HudIcon.new().configurar("camera")
	var camera: Array = BotaoCanto.criar(_root, top, _camera_icon)
	_camera_lock_button = camera[0]
	_camera_hint = camera[1]
	_shortcut_badges["camera"] = BotaoCanto.marcar_atalho(_camera_lock_button, Atalhos.letra("camera"))
	_camera_lock_button.toggle_mode = true
	_camera_lock_button.focus_mode = Control.FOCUS_NONE
	_camera_lock_button.toggled.connect(func(locked: bool):
		Audio.efeito("ui_confirmar")
		camera_lock_requested.emit(locked))

	top += 1
	_speed_icon = HudIcon.new().configurar("velocidade")
	var speed: Array = BotaoCanto.criar(_root, top, _speed_icon)
	_speed_hint = speed[1]
	_corner_setup(speed[0], func() -> void:
		Dia.definir_velocidade(Dia.proxima_velocidade())
		_update_telemetry())

	top += 1
	var style_icon = HudIcon.new().configurar("estilo")
	style_icon.definir(Estilo.tripo())
	var style: Array = BotaoCanto.criar(_root, top, style_icon)
	(style[1] as Label).text = "FPS"
	_performance_button = style[0]
	_corner_setup(_performance_button, func() -> void:
		_performance_open = not _performance_open
		_sync_performance_panel())

	top += 1
	_help_icon = HudIcon.new().configurar("ajuda")
	var help: Array = BotaoCanto.criar(_root, top, _help_icon)
	(help[1] as Label).text = "Controles"
	_corner_setup(help[0], func() -> void: controls_requested.emit())

	top += 1
	var quest_icon: Control = HudIcon.new().configurar("missoes")
	var quests: Array = BotaoCanto.criar(_root, top, quest_icon)
	var quest_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/hud_3d.json"))
	var quest_texts: Dictionary = quest_data if quest_data is Dictionary else {}
	(quests[1] as Label).text = str(IdiomaMenu.campo(quest_texts.get("botao_missoes", {}), "rotulo", "Missões e objetivos"))
	_shortcut_badges["painel"] = BotaoCanto.marcar_atalho(quests[0], Atalhos.letra("painel"))
	_corner_setup(quests[0], func() -> void: quests_requested.emit())
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
	# O CANTO RECEBE A POSIÇÃO NA COLUNA (0 é o alto), e não os pixels do topo.
	#
	# Desde o "Tamanho do HUD" do AJUSTAR, o `BotaoCanto` mede a placa pela
	# escala escolhida e a refaz na hora (`BotaoCanto.reaplicar`). Aqui ainda se
	# passava 32.0, o topo em pixels de antes: lido como posição, o botão ia
	# parar 1.600 px abaixo, fora da tela — e sem erro nenhum.
	#
	# E O NÚMERO NÃO É ÍCONE. O canto encolhe o ícone para um quadrado de 16 no
	# meio da placa, e refaz essa conta a cada troca de tamanho; o número usa o
	# botão todo, para "144" caber sem cortar. Por isso o ícone do canto é um
	# nó vazio, e o número é filho do botão, ancorado nele inteiro: acompanha a
	# placa em qualquer tamanho do HUD.
	var dados: Array = BotaoCanto.criar(_root, 0, Control.new())
	(dados[1] as Label).text = "FPS"
	_performance_button = dados[0]
	_performance_button.add_child(_fps_label)
	_fps_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
			if child is Control and child.name == "VidaDaArvore":
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
func set_mission_step(indice: int, total: int, finished := false) -> void:
	if not is_instance_valid(_mission_step):
		return
	_mission_step.text = "" if total <= 0 or indice <= 0 or indice > total else "%d de %d" % [indice, total]


func componentes_da_narracao() -> Dictionary:
	var partes := {
		"missao": [_heading, _region_label, _mission_step, _quest_label, _objective_label],
		"relogio": [_clock_panel], "vida": [barra_vida],
		"folego": [barra_folego], "vigor": [barra_stamina],
		"mao": [_barra], "avisos": [_notice_panel],
		"espera": [_espera_panel],
		"casa": [_house_info_panel], "desempenho": [_performance_panel],
	}
	for filho in _root.get_children():
		if filho is Control and filho.get_script() == Minimapa:
			partes["minimapa"] = [filho]
	for i in _corner_nodes.size():
		if _corner_nodes[i] is Control:
			partes["atalho_%d" % i] = [_corner_nodes[i]]
	return partes
