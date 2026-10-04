extends CanvasLayer
## A CAIXA QUE PERGUNTA ANTES: título, texto e dois botões — o de desistir à
## esquerda e com o foco, porque é o que não custa nada; o de fazer em
## terracota. Esc ou clique fora desistem; Enter ou E respondem com o botão do
## foco; as setas (e A/D) trocam o foco.
##
## Havia duas cópias dela, com o mesmo desenho: a do menu do Esc (parar o
## relógio) e a do "Voltar ao menu?" do HUD. O relógio ganhou mais duas portas
## que perguntam — o "Parada" do AJUSTAR e a tecla de adiantar a hora —, e
## terceira e quarta cópias divergiriam das duas primeiras. Agora há uma.
##
## É uma camada própria, por cima de tudo o que pergunta (menu do Esc, AJUSTAR,
## HUD), e anda com o vale parado: quem pergunta costuma parar o vale antes.
##
##     const CaixaDePergunta = preload("res://scripts/prototipo_3d/caixa_de_pergunta.gd")
##     var caixa := CaixaDePergunta.new()
##     caixa.perguntar(self, {"titulo": ..., "texto": ...,
##         "nao": "DEIXAR CORRER", "sim": "PARAR O RELÓGIO"})
##     caixa.respondeu.connect(func(sim: bool) -> void: ...)

signal respondeu(sim: bool)

const TemaMenu = preload("res://scripts/prototipo_3d/tema_menu.gd")
const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")

## Acima do menu do Esc (27) e da tela da queda (30): a pergunta cobre quem a fez.
const CAMADA := 40

var _sim: Button
var _nao: Button
var _respondida := false


## Abre a caixa como filha de `pai` (qualquer nó: ela é camada própria e cobre
## a tela inteira). `dados`: titulo, texto, nao e sim (os rótulos dos botões).
func perguntar(pai: Node, dados: Dictionary) -> void:
	name = "Pergunta"
	_montar(dados)
	pai.add_child(self)
	_nao.grab_focus.call_deferred()


func _montar(dados: Dictionary) -> void:
	layer = CAMADA
	process_mode = Node.PROCESS_MODE_ALWAYS
	var tela := Control.new()
	tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tela.theme = TemaMenu.criar()
	add_child(tela)
	var sombra := ColorRect.new()
	sombra.color = Color(0, 0, 0, 0.55)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sombra.gui_input.connect(func(evento: InputEvent) -> void:
		if evento is InputEventMouseButton and evento.pressed:
			responder(false))
	tela.add_child(sombra)
	var painel := PanelContainer.new()
	painel.add_theme_stylebox_override("panel", TemaMenu.estilo_painel())
	painel.custom_minimum_size = Vector2(460, 0)
	painel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	painel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	painel.grow_vertical = Control.GROW_DIRECTION_BOTH
	tela.add_child(painel)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 14)
	painel.add_child(coluna)
	var titulo := Label.new()
	titulo.name = "Titulo"
	titulo.text = str(dados.get("titulo", ""))
	titulo.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600, 2))
	titulo.add_theme_font_size_override("font_size", 24)
	titulo.add_theme_color_override("font_color", Identidade.CREME)
	coluna.add_child(titulo)
	var texto := Label.new()
	texto.name = "Texto"
	texto.text = str(dados.get("texto", ""))
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.custom_minimum_size = Vector2(412, 0)
	texto.add_theme_font_size_override("font_size", 16)
	texto.add_theme_color_override("font_color", Color("c9b98f"))
	coluna.add_child(texto)
	var botoes := HBoxContainer.new()
	botoes.add_theme_constant_override("separation", 12)
	coluna.add_child(botoes)
	_nao = Button.new()
	_nao.name = "Nao"
	_nao.text = str(dados.get("nao", "CANCELAR"))
	_nao.custom_minimum_size.y = 44
	_nao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nao.pressed.connect(responder.bind(false))
	botoes.add_child(_nao)
	_sim = Button.new()
	_sim.name = "Sim"
	_sim.text = str(dados.get("sim", "CONFIRMAR"))
	_sim.custom_minimum_size.y = 44
	_sim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sim.theme_type_variation = &"BotaoNegativo"
	_sim.pressed.connect(responder.bind(true))
	botoes.add_child(_sim)
	for botao: Button in [_nao, _sim]:
		botao.mouse_entered.connect(func(): Audio.efeito("ui_hover"))


## Responde uma vez só, e a caixa sai.
func responder(sim: bool) -> void:
	if _respondida:
		return
	_respondida = true
	queue_free()
	respondeu.emit(sim)


## COM A CAIXA ABERTA, AS TECLAS SÃO DELA, inclusive o Esc — que o dono das
## telas também ouve e usaria para fechar a tela de baixo. Ela entra na árvore
## depois de quem perguntou, e por isso ouve antes.
func _input(event: InputEvent) -> void:
	if _respondida or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_ESCAPE:
			responder(false)
		KEY_LEFT, KEY_A:
			_nao.grab_focus()
		KEY_RIGHT, KEY_D:
			_sim.grab_focus()
		KEY_ENTER, KEY_KP_ENTER:
			responder(_sim.has_focus())
		_:
			if event.physical_keycode == Atalhos.tecla("interagir"):
				responder(_sim.has_focus())
			# As outras teclas não passam para a tela de baixo nem para o vale.
	get_viewport().set_input_as_handled()
