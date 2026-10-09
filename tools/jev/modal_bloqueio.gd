extends PanelContainer
## O MODAL DO BLOQUEIO (#183): quando a escada (determinístico → Jev → GPT) não destrava um
## passo, a ponte responde com `blocked` e a sessão NÃO encerra: pergunta a quem assiste.
##
##   "O testador travou em <passo> (<motivo>). Deseja assumir o controle?"
##   [F7] Assumir o controle · Tentar outra rota · Encerrar (F8)
##
## Sem resposta em `ESPERA_S` (sessão sem ninguém olhando), vale "timeout" e a ponte segue
## por outra rota. Só desenho e contagem: `sessao.gd` abre, ouve `escolhido` e manda a escolha
## à ponte no estado do pedido seguinte (`blocked_choice`).

const PainelSessao = preload("res://tools/jev/painel_sessao.gd")
const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")
const TemaMenu = preload("res://scripts/prototipo_3d/tema_menu.gd")

signal escolhido(escolha: String)

const ESPERA_S := 20.0
const LARGURA := 460.0

var _t: Callable
var _pergunta: Label
var _tentativas: Label
var _contagem: Label
var _restante := 0.0
var _aberto := false


func montar(t: Callable) -> void:
	_t = t
	name = "ModalDoBloqueio"
	theme = TemaMenu.criar()
	add_theme_stylebox_override("panel", PainelSessao._estilo_do_painel())
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	custom_minimum_size = Vector2(LARGURA, 0.0)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 8)
	add_child(caixa)
	var titulo := Label.new()
	titulo.name = "Titulo"
	titulo.uppercase = true
	titulo.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600, 3))
	titulo.add_theme_font_size_override("font_size", 16)
	titulo.add_theme_color_override("font_color", Identidade.OURO)
	caixa.add_child(titulo)
	caixa.add_child(Identidade.divisor())
	_pergunta = _texto(caixa, 18, Identidade.CREME, Identidade.fonte(Identidade.FONTE_TEXTO, 700))
	_tentativas = _texto(caixa, 14, PainelSessao.NOTA)
	_contagem = _texto(caixa, 14, PainelSessao.NOTA, Identidade.fonte(Identidade.FONTE_ITALICO, 500))
	var botoes := HBoxContainer.new()
	botoes.add_theme_constant_override("separation", 6)
	caixa.add_child(botoes)
	for par in [["Assumir", "F7", &"", "takeover"], ["OutraRota", "", &"", "alternate"], ["Encerrar", "F8", &"BotaoNegativo", "stop"]]:
		var botao := Button.new()
		botao.name = str(par[0])
		botao.focus_mode = Control.FOCUS_NONE
		botao.custom_minimum_size = Vector2(0.0, 34.0)
		botao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if par[2] != &"":
			botao.theme_type_variation = par[2]
		var linha := HBoxContainer.new()
		linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
		linha.alignment = BoxContainer.ALIGNMENT_CENTER
		linha.add_theme_constant_override("separation", 6)
		botao.add_child(linha)
		linha.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if str(par[1]) != "":
			var plaqueta := PainelSessao._plaqueta_da_tecla(str(par[1]))
			plaqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
			linha.add_child(plaqueta)
		var rotulo := Label.new()
		rotulo.name = "Rotulo"
		rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rotulo.size_flags_vertical = Control.SIZE_EXPAND_FILL
		rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rotulo.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600))
		rotulo.add_theme_font_size_override("font_size", 12)
		rotulo.add_theme_color_override("font_color", Identidade.CREME)
		linha.add_child(rotulo)
		var escolha := str(par[3])
		botao.pressed.connect(func() -> void: escolher(escolha))
		botoes.add_child(botao)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)


func _texto(pai: Control, tamanho: int, cor: Color, fonte: Font = null) -> Label:
	var r := Label.new()
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size.x = LARGURA - 28.0
	r.add_theme_font_size_override("font_size", tamanho)
	r.add_theme_color_override("font_color", cor)
	if fonte != null:
		r.add_theme_font_override("font", fonte)
	pai.add_child(r)
	return r


func aberto() -> bool:
	return _aberto


## Abre com o que a ponte mandou: {"step", "reason", "tries"}.
func abrir(bloqueio: Dictionary) -> void:
	var passo := str(bloqueio.get("step", ""))
	var motivo := str(bloqueio.get("reason", ""))
	(find_child("Titulo", true, false) as Label).text = _t.call("bloqueio_titulo")
	_pergunta.text = str(_t.call("bloqueio_pergunta")) % [passo if passo != "" else _t.call("passo_desconhecido"),
		motivo if motivo != "" else _t.call("motivo_desconhecido")]
	var tentativas := int(bloqueio.get("tries", 0))
	_tentativas.text = str(_t.call("bloqueio_tentativas")) % tentativas
	_tentativas.visible = tentativas > 0
	for par in [["Assumir", "cmd_assumir"], ["OutraRota", "bloqueio_outra"], ["Encerrar", "bloqueio_encerrar"]]:
		(find_child(str(par[0]), true, false).find_child("Rotulo", true, false) as Label).text = _t.call(str(par[1]))
	_restante = ESPERA_S
	_aberto = true
	visible = true
	_atualizar_contagem()
	reset_size()
	# Centrado na janela, por cima do jogo.
	var janela := get_viewport_rect().size
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = ((janela - get_combined_minimum_size()) * 0.5).floor()


## Esconde sem escolher (a cena tomou a tela): a contagem para e retoma ao reabrir.
func esconder_por_um_instante(escondido: bool) -> void:
	if _aberto:
		visible = not escondido


func escolher(escolha: String) -> void:
	if not _aberto:
		return
	_aberto = false
	visible = false
	escolhido.emit(escolha)


## A contagem anda só com o modal à vista.
func avancar(delta: float) -> void:
	if not _aberto or not visible:
		return
	_restante -= delta
	_atualizar_contagem()
	if _restante <= 0.0:
		escolher("timeout")


func _atualizar_contagem() -> void:
	_contagem.text = str(_t.call("bloqueio_contagem")) % maxi(0, ceili(_restante))
