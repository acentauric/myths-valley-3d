extends Control
## O SELO DE FALA DO VIAJANTE (#225): quem fala é ele, e a tela diz.
##
## As falas do viajante (#187) tocam SEM balão, por decisão do autor. Sobrou o defeito: a voz soava e nada na
## tela dizia que era ele — o jogador podia achar que era um morador por perto. Aqui, enquanto a voz toca
## (`FalasDoViajante.comecou_a_falar` até `calou_a_voz`), aparece um ícone pequeno de ondas de som em ouro sobre a
## cabeça dele (o traço dos ícones do HUD, `hud_icon.gd`, tipo "fala"): as ondas acendem uma a uma e o ícone
## pulsa no ritmo de uma fala; entra e sai com fade.
##
##
## A LEGENDA, OPCIONAL
##
## Ajustes → Interface → "Legendas do viajante": Ligadas ou Desligadas, DESLIGADAS no padrão, para manter a decisão
## de "sem balão". Ligada, o texto da fala (no idioma do jogo) aparece numa caixa de laca com o filete de ouro,
## em letra de leitura, logo acima do ícone — uma legenda, sem nome, sem ponta e sem página.
##
##
## SEM COBRIR NINGUÉM (as regras dos popups, `popups_do_mundo.gd`)
##
## O selo mora ACIMA da cabeça dele (a caixa da cabeça é a mesma da placa de nome, `placas_nomes.gd`), nunca no
## rosto, e CEDE: some com fade se cairia sobre um balão de morador, a dica do E, um painel do HUD, o "!" ou o
## "?" de missão ou a cabeça de outro personagem; a legenda cede antes do ícone (se só ela cobriria algo, fica o
## ícone). Roda por último no quadro (`process_priority` 30), depois do balão, para ler o retângulo fresco de todos.
## Também some com qualquer tela aberta, caixa de fala, festa da missão ou cena (`permitir` e `coberto`), e só
## aparece com a câmera do jogo, de passeio, de cima ou dentro de casa. O tamanho acompanha o da "fala" em Ajustes
## → Tamanho de cada interface.

const SuavizadorDeTela = preload("res://scripts/prototipo_3d/suavizador_de_tela.gd")
const PopupsDoMundo = preload("res://scripts/prototipo_3d/popups_do_mundo.gd")
const PlacasNomes = preload("res://scripts/prototipo_3d/placas_nomes.gd")
const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")
const HudIcon = preload("res://scripts/prototipo_3d/hud_icon.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")

const PREFERENCIAS := "user://preferencias_visuais.cfg"
const SECAO := "jogo"
const CHAVE := "legendas_do_viajante"
## As escolhas de Ajustes, na ordem do seletor: o índice é o modo (0 = Ligadas, 1 = Desligadas).
const ROTULOS := ["Ligadas", "Desligadas"]
const PADRAO := 1

## O lado do ícone na tela (px, na escala 100%) e a folga entre ele e o alto da cabeça.
const LADO_DO_ICONE := 30.0
const FOLGA_DA_CABECA := 10.0
## O desenho do HudIcon cabe numa caixa de 24 px; o ícone cresce daí até o lado.
const CAIXA_DO_DESENHO := 24.0
## A legenda: a largura máxima, a folga sobre o ícone e a margem da borda da tela.
const LARGURA_DA_LEGENDA := 320.0
const FOLGA_DA_LEGENDA := 6.0
const MARGEM_DA_TELA := 12.0
const TAMANHO_DA_LEGENDA := 17
## Quanto sobra entre o selo e o que ele não pode cobrir (px).
const FOLGA_DOS_POPUPS := 6.0
## O fade de entrada e de saída (s).
const SEGUNDOS_DO_FADE := 0.25
## O ritmo da fala: pulsos por segundo do ícone e ondas acesas por segundo.
const PULSO_HZ := 2.4
const AMPLITUDE_DO_PULSO := 0.1
const ONDAS_POR_SEGUNDO := 3.0
## Se o aviso de que a voz acabou se perde, o selo some por conta própria depois da duração mais isto (s).
const SOBRA_DA_FALA := 1.5

## Devolve se o viajante está falando, para o portão e para quem quer saber.
var falando := false
## Para o portão: o fade completo do ícone e da legenda (0 a 1).
var alfa_do_icone := 0.0
var alfa_da_legenda := 0.0
## Quem diz se uma festa, a narração ou uma cena cobrem o vale (a mesma regra das dicas do E).
var coberto: Callable = Callable()

var _jogador: Node3D
var _placas: Node
var _icone: Control
var _painel: PanelContainer
var _texto: Label
var _mola := SuavizadorDeTela.new()
var _permitido := true
var _novo := true
var _relogio := 0.0
var _resta_s := 0.0
var _nivel := -1
## O último lugar desenhado: o selo que sai continua onde estava enquanto apaga.
var _caixa_do_icone := Rect2()
var _caixa_da_legenda := Rect2()
var _escala := 1.0

## Guardada da sessão: lê o arquivo na primeira vez e daí em diante vale `definir_legendas`.
static var _legendas_guardadas := -1


## --- o ajuste --------------------------------------------------------------------------------------

## O modo de agora: Ligadas (0) ou Desligadas (1).
static func modo_das_legendas() -> int:
	if _legendas_guardadas >= 0:
		return _legendas_guardadas
	var valor: int = PADRAO
	var preferencias := ConfigFile.new()
	if preferencias.load(PREFERENCIAS) == OK:
		valor = int(preferencias.get_value(SECAO, CHAVE, PADRAO))
	_legendas_guardadas = clampi(valor, 0, ROTULOS.size() - 1)
	return _legendas_guardadas


static func legendas_ligadas() -> bool:
	return modo_das_legendas() == 0


static func definir_legendas(valor: int) -> void:
	_legendas_guardadas = clampi(valor, 0, ROTULOS.size() - 1)
	var preferencias := ConfigFile.new()
	preferencias.load(PREFERENCIAS)
	preferencias.set_value(SECAO, CHAVE, _legendas_guardadas)
	if preferencias.save(PREFERENCIAS) != OK:
		push_warning("Não foi possível salvar a preferência das legendas do viajante.")


## Esquece o que a sessão guardou (o portão troca o modo sem passar pelo arquivo).
static func esquecer_as_legendas() -> void:
	_legendas_guardadas = -1


## --- a montagem --------------------------------------------------------------------------------------

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	# Por último no quadro, depois do balão (20): lê o retângulo fresco de todos.
	process_priority = 30
	_icone = HudIcon.new().configurar("fala")
	_icone.name = "Icone"
	_icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icone.custom_minimum_size = Vector2(CAIXA_DO_DESENHO, CAIXA_DO_DESENHO)
	_icone.size = Vector2(CAIXA_DO_DESENHO, CAIXA_DO_DESENHO)
	_icone.pivot_offset = Vector2(CAIXA_DO_DESENHO, CAIXA_DO_DESENHO) * 0.5
	_icone.visible = false
	add_child(_icone)
	_painel = PanelContainer.new()
	_painel.name = "Legenda"
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.visible = false
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(Identidade.LACA, 0.95)
	estilo.border_color = Color(Identidade.OURO, 0.8)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(8)
	estilo.content_margin_left = 14
	estilo.content_margin_right = 14
	estilo.content_margin_top = 7
	estilo.content_margin_bottom = 8
	estilo.shadow_color = Color(0, 0, 0, 0.35)
	estilo.shadow_size = 6
	estilo.shadow_offset = Vector2(0, 2)
	_painel.add_theme_stylebox_override("panel", estilo)
	add_child(_painel)
	_texto = Label.new()
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Identidade.papel_leitura(_texto, TAMANHO_DA_LEGENDA)
	_painel.add_child(_texto)


## Liga o selo ao jogador (a cabeça de onde ele sai), às placas (a altura e as cabeças dos outros) e ao
## viajante (quando a voz começa e acaba). Qualquer um pode faltar (um portão que monta uma peça só).
func configurar(jogador: Node3D, placas: Node, viajante: Node) -> void:
	_jogador = jogador
	_placas = placas
	if viajante != null:
		if viajante.has_signal("comecou_a_falar") and not viajante.is_connected("comecou_a_falar", _ao_comecar):
			viajante.connect("comecou_a_falar", _ao_comecar)
		if viajante.has_signal("calou_a_voz") and not viajante.is_connected("calou_a_voz", _ao_calar):
			viajante.connect("calou_a_voz", _ao_calar)


## Com uma tela, caixa de fala ou festa por cima do vale o selo se apaga na hora (como as placas).
func permitir(sim: bool) -> void:
	_permitido = sim
	if not sim:
		alfa_do_icone = 0.0
		alfa_da_legenda = 0.0
		_aplicar()


## --- o que a voz faz ---------------------------------------------------------------------------------

func _ao_comecar(texto: String, segundos: float) -> void:
	falando = true
	_resta_s = segundos + SOBRA_DA_FALA
	_relogio = 0.0
	_texto.text = texto
	var fonte := _texto.get_theme_font("font")
	var largura := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANHO_DA_LEGENDA).x + 2.0
	var largura_do_texto := minf(largura, LARGURA_DA_LEGENDA)
	_texto.custom_minimum_size = Vector2(largura_do_texto, 0.0)
	_texto.size = Vector2(largura_do_texto, 0.0)
	_painel.reset_size()
	# A palavra nova não desliza de onde a anterior ficou.
	_novo = alfa_do_icone <= 0.01
	_nivel = -1


func _ao_calar() -> void:
	falando = false


## --- o quadro ------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_relogio += delta
	if falando:
		_resta_s -= delta
		if _resta_s <= 0.0:
			falando = false
	var alvo_icone := 0.0
	var alvo_legenda := 0.0
	var camera := get_viewport().get_camera_3d()
	var em_jogo: bool = camera != null and _jogador != null and camera == _jogador.get("camera")
	var liberado: bool = _permitido and em_jogo and not (coberto.is_valid() and bool(coberto.call()))
	if liberado and (falando or alfa_do_icone > 0.0):
		var tela := get_viewport().get_visible_rect().size
		var caixas := _caixas(camera, tela, delta)
		if not caixas.is_empty():
			_caixa_do_icone = caixas["icone"]
			_caixa_da_legenda = caixas["legenda"]
			if falando:
				var obstaculos := _obstaculos(camera, tela)
				var livre := not _cobre(_caixa_do_icone, obstaculos)
				alvo_icone = 1.0 if livre else 0.0
				var quer_legenda: bool = legendas_ligadas() and _texto.text != "" and _caixa_da_legenda.size != Vector2.ZERO
				alvo_legenda = 1.0 if livre and quer_legenda and not _cobre(_caixa_da_legenda, obstaculos) else 0.0
		elif falando:
			_novo = true
	elif not liberado:
		_novo = true
	var passo := delta / SEGUNDOS_DO_FADE
	alfa_do_icone = move_toward(alfa_do_icone, alvo_icone, passo)
	alfa_da_legenda = move_toward(alfa_da_legenda, alvo_legenda, passo)
	_aplicar()


## As caixas do ícone e da legenda para este quadro, ou vazio se a cabeça não está na tela. O ícone é uma mola
## presa ao alto da cabeça; a legenda, logo acima dele.
func _caixas(camera: Camera3D, tela: Vector2, delta: float) -> Dictionary:
	_escala = Tela.escala_componente("fala")
	var altura := 1.75
	if _placas != null and _placas.has_method("altura_do"):
		altura = float(_placas.call("altura_do", _jogador))
	var cabeca := PlacasNomes.caixa_na_tela(camera, _jogador.global_position,
		altura * (1.0 - PlacasNomes.FRACAO_DA_CABECA), altura, PlacasNomes.MEIA_LARGURA_DA_CABECA)
	if cabeca.size == Vector2.ZERO:
		return {}
	var alvo := Vector2(cabeca.get_center().x, cabeca.position.y - FOLGA_DA_CABECA * _escala)
	if _novo or not _mola.iniciado():
		_mola.reiniciar(alvo)
		_novo = false
	var ponto := _mola.seguir(alvo, delta).round()
	var lado := LADO_DO_ICONE * _escala
	var icone := Rect2(ponto.x - lado * 0.5, ponto.y - lado, lado, lado)
	var legenda := Rect2()
	if legendas_ligadas() and _texto.text != "":
		var tamanho := _painel.get_combined_minimum_size() * _escala
		var x := clampf(ponto.x - tamanho.x * 0.5, MARGEM_DA_TELA, maxf(tela.x - tamanho.x - MARGEM_DA_TELA, MARGEM_DA_TELA))
		var y := icone.position.y - FOLGA_DA_LEGENDA * _escala - tamanho.y
		legenda = Rect2(x, y, tamanho.x, tamanho.y)
		# Sem lugar no alto da tela, a legenda não aparece (o ícone fica).
		if legenda.position.y < MARGEM_DA_TELA:
			legenda = Rect2()
	return {"icone": icone, "legenda": legenda}


## O que o selo não pode cobrir: os balões de fala, as dicas do E, os painéis do HUD, os "!" e "?" de missão e as
## cabeças dos outros personagens (a do próprio viajante fica de fora: é ele quem fala).
func _obstaculos(camera: Camera3D, tela: Vector2) -> Array[Rect2]:
	var lista: Array[Rect2] = []
	lista.append_array(PopupsDoMundo.retangulos_dos_baloes(self))
	lista.append_array(PopupsDoMundo.retangulos(self, PopupsDoMundo.GRUPO_DICAS))
	lista.append_array(PopupsDoMundo.paineis_do_hud(tela, self))
	lista.append_array(PopupsDoMundo.retangulos_dos_marcadores(self))
	if _placas != null and _placas.has_method("cabecas_a_vista"):
		lista.append_array(_placas.call("cabecas_a_vista", camera, _jogador))
	return lista


static func _cobre(caixa: Rect2, obstaculos: Array[Rect2]) -> bool:
	if caixa.size == Vector2.ZERO:
		return false
	var larga := caixa.grow(FOLGA_DOS_POPUPS)
	for obstaculo: Rect2 in obstaculos:
		if larga.intersects(obstaculo):
			return true
	return false


## Põe o ícone e a legenda onde estão as caixas, com o pulso e as ondas da fala e o fade.
func _aplicar() -> void:
	var ve_icone := alfa_do_icone > 0.01 and _permitido
	var ve_legenda := alfa_da_legenda > 0.01 and _permitido
	_icone.visible = ve_icone
	_painel.visible = ve_legenda
	visible = ve_icone or ve_legenda
	if not visible:
		return
	if ve_icone:
		var pulso := 1.0 + AMPLITUDE_DO_PULSO * sin(_relogio * TAU * PULSO_HZ) if falando else 1.0
		var lado := _caixa_do_icone.size.x
		_icone.scale = Vector2.ONE * (lado / CAIXA_DO_DESENHO) * pulso
		_icone.position = _caixa_do_icone.get_center() - _icone.pivot_offset
		_icone.modulate.a = alfa_do_icone
		# As ondas acendem uma a uma (1, 2, 3) no ritmo da fala.
		var nivel := 1 + int(_relogio * ONDAS_POR_SEGUNDO) % 3
		if nivel != _nivel:
			_nivel = nivel
			_icone.call("definir", false, nivel)
	if ve_legenda:
		_painel.scale = Vector2.ONE * _escala
		_painel.pivot_offset = Vector2.ZERO
		_painel.position = _caixa_da_legenda.position
		_painel.modulate.a = alfa_da_legenda


## O retângulo do ícone na tela, ou vazio sem ele (o portão e quem mais quiser saber onde o selo está).
func retangulo() -> Rect2:
	return _caixa_do_icone if _icone.visible else Rect2()


## O retângulo da legenda na tela, ou vazio sem ela.
func retangulo_da_legenda() -> Rect2:
	return _caixa_da_legenda if _painel.visible else Rect2()
