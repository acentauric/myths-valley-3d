extends Control
## O POPOVER DOS MENUS (#232): uma caixa compacta com seta, no lugar do tooltip em linha.
##
## O botão TESTAR do lobby mostrava o tooltip padrão numa linha única de meia tela, por cima da arte, e os outros
## cinco botões da coluna não diziam o que faziam. O popover é o tooltip da identidade do menu: LACA escura, filete
## de ouro, canto chanfrado (`corner_detail` 1), letra de leitura (`Identidade.papel_leitura`) e uma SETA apontando
## para o botão. É um componente, para qualquer menu usar:
##
##     PopoverMenu.ligar(botao, "texto em português (a chave da tradução)", camada)
##
## `camada` é o nó (o CanvasLayer ou o Control raiz do menu) em que o popover mora, por cima de tudo; ele se libera
## sozinho quando o botão sai da árvore (o `_clear()` do lobby esvazia a coluna a cada tela).
##
##
## QUANDO APARECE
##
##   - com o MOUSE em cima do botão, depois de `ATRASO_S` (para quem só passa por cima não ver piscar), com fade;
##   - com o FOCO do teclado ou do controle, depois do mesmo atraso — mas só quando a última entrada foi de teclado
##     ou controle. O lobby põe o foco em JOGAR sozinho e o mouse puxa o foco para o botão (`puxa_foco`): sem essa
##     regra o popover ficaria preso no botão de que o mouse já saiu;
##   - some com fade ao sair (o mouse sai, o foco passa para outro botão) e na hora se o botão some.
##
##
## ONDE FICA
##
## Do lado pedido (`Lado.DIREITA` para a coluna da esquerda do lobby), alinhado ao CENTRO do botão, com a seta
## no meio da aresta voltada para ele. Se não cabe na tela naquele lado, passa para o oposto; no eixo de
## cruzamento a caixa é empurrada para dentro da tela e a seta continua apontando para o centro do botão. A
## largura máxima é `LARGURA_MAX` (~340 px em 1080p): o texto quebra em duas a quatro linhas.
##
## O texto é a CHAVE em português (como todos os rótulos do menu) e é traduzida na hora de aparecer
## (`tr`), então a troca de idioma vale sem reconstruir nada. `definir_texto` troca o texto de um popover que já existe.

const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")

enum Lado { DIREITA, ESQUERDA, ABAIXO, ACIMA }

const CAMINHO := "res://scripts/prototipo_3d/popover_menu.gd"
## Largura máxima da caixa (px na referência do menu) e o tamanho da letra.
const LARGURA_MAX := 340.0
const TAMANHO_DA_LETRA := 17
## Espera antes de aparecer e duração do fade (s).
const ATRASO_S := 0.4
const FADE_S := 0.15
## A seta: quanto sai da caixa e a meia-largura da base; a folga entre a ponta e o botão.
const SETA := 10.0
const SETA_META_BASE := 7.0
const FOLGA_DO_BOTAO := 4.0
## Margem da borda da tela, e o canto da caixa que a seta não pode invadir.
const MARGEM_DA_TELA := 8.0
const CANTO := 10.0
const FUNDO := Color(0.055, 0.09, 0.075, 0.97)
const FILETE := Color(0.788, 0.647, 0.353, 0.8)

## A última entrada foi de teclado ou de controle? (Dividido por todos os popovers.)
static var _entrada_de_teclado := false

var lado: int = Lado.DIREITA
## Para o portão: o fade completo (0 a 1) e o lado em que a caixa ficou.
var alfa := 0.0
var lado_atual: int = Lado.DIREITA

var _botao: Control
var _chave := ""
var _painel: PanelContainer
var _texto: Label
var _seta: Control
var _pairando := false
var _com_foco := false
var _espera_s := 0.0
## A ponta da seta e os dois cantos da base, no espaço do popover (a seta é desenhada por `_desenhar_seta`).
var _ponta := Vector2.ZERO
var _base_a := Vector2.ZERO
var _base_b := Vector2.ZERO
var _para_dentro := Vector2.ZERO


## Liga um popover ao `botao` e o devolve. Mora em `camada`; some e se libera com o botão.
static func ligar(botao: Control, chave: String, camada: Node, no_lado: int = Lado.DIREITA) -> Control:
	var popover: Control = (load(CAMINHO) as GDScript).new()
	popover.set("lado", no_lado)
	camada.add_child(popover)
	popover.call("_prender", botao, chave)
	return popover


func _init() -> void:
	name = "Popover"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_painel = PanelContainer.new()
	_painel.name = "Caixa"
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = FUNDO
	estilo.border_color = FILETE
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(8)
	estilo.corner_detail = 1
	estilo.shadow_color = Color(0, 0, 0, 0.4)
	estilo.shadow_size = 6
	estilo.shadow_offset = Vector2(0, 2)
	estilo.content_margin_left = 14
	estilo.content_margin_right = 14
	estilo.content_margin_top = 9
	estilo.content_margin_bottom = 10
	_painel.add_theme_stylebox_override("panel", estilo)
	add_child(_painel)
	_texto = Label.new()
	_texto.name = "Texto"
	_texto.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Identidade.papel_leitura(_texto, TAMANHO_DA_LETRA)
	_painel.add_child(_texto)
	# A seta vem DEPOIS da caixa: desenha por cima e apaga o trecho do filete onde ela nasce.
	_seta = Control.new()
	_seta.name = "Seta"
	_seta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seta.draw.connect(_desenhar_seta)
	add_child(_seta)


func _prender(botao: Control, chave: String) -> void:
	_botao = botao
	_chave = chave
	botao.mouse_entered.connect(func() -> void: _pairando = true)
	botao.mouse_exited.connect(func() -> void: _pairando = false)
	botao.focus_entered.connect(func() -> void: _com_foco = true)
	botao.focus_exited.connect(func() -> void: _com_foco = false)
	# O botão sai (o `_clear()` do lobby): o popover vai junto, sem ficar órfão na tela.
	botao.tree_exiting.connect(queue_free)
	_com_foco = botao.has_focus()


## Troca o texto (a chave em português) de um popover que já existe.
func definir_texto(chave: String) -> void:
	_chave = chave


func texto_atual() -> String:
	return _texto.text


## O popover está sendo visto (com fade, ao menos um pouco)?
func a_vista() -> bool:
	return visible and alfa > 0.01


## O retângulo da caixa na tela, ou vazio sem ele (a seta não conta).
func retangulo() -> Rect2:
	if not a_vista():
		return Rect2()
	return Rect2(_painel.global_position, _painel.size)


func _input(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion or evento is InputEventMouseButton:
		_entrada_de_teclado = false
	elif evento is InputEventKey or evento is InputEventJoypadButton:
		if evento.is_pressed():
			_entrada_de_teclado = true
	elif evento is InputEventJoypadMotion and absf((evento as InputEventJoypadMotion).axis_value) > 0.5:
		_entrada_de_teclado = true


func _process(delta: float) -> void:
	if _botao == null or not is_instance_valid(_botao):
		return
	var quer := (_pairando or (_com_foco and _entrada_de_teclado)) and _botao.is_visible_in_tree() and _chave != ""
	_espera_s = _espera_s + delta if quer else 0.0
	var alvo := 1.0 if quer and _espera_s >= ATRASO_S else 0.0
	alfa = move_toward(alfa, alvo, delta / FADE_S)
	visible = alfa > 0.01
	if not visible:
		return
	modulate.a = alfa
	_atualizar_o_texto()
	_posicionar()


## O texto na língua de agora, quebrado na largura máxima (a caixa é justa ao texto quando ele é curto).
func _atualizar_o_texto() -> void:
	var traduzido := tr(_chave)
	if _texto.text == traduzido and _texto.custom_minimum_size.x > 0.0:
		return
	_texto.text = traduzido
	var fonte := _texto.get_theme_font("font")
	var largura := fonte.get_string_size(traduzido, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANHO_DA_LETRA).x + 2.0
	var largura_do_texto := minf(largura, LARGURA_MAX)
	_texto.custom_minimum_size = Vector2(largura_do_texto, 0.0)
	_texto.size = Vector2(largura_do_texto, 0.0)
	_painel.reset_size()


## Põe a caixa ao lado do botão, a seta apontando para o centro dele.
func _posicionar() -> void:
	var tela := get_viewport_rect().size
	var botao := _botao.get_global_rect()
	var caixa := _painel.get_combined_minimum_size()
	var util := Rect2(Vector2.ZERO, tela).grow(-MARGEM_DA_TELA)
	var escolhido := lado
	if not util.encloses(_retangulo_do_lado(lado, botao, caixa, tela)) 			and util.encloses(_retangulo_do_lado(_oposto(lado), botao, caixa, tela)):
		escolhido = _oposto(lado)
	# Nenhum lado cabe inteiro: fica o pedido, com o eixo de cruzamento empurrado para dentro.
	var total := _retangulo_do_lado(escolhido, botao, caixa, tela)
	lado_atual = escolhido
	position = total.position
	size = total.size
	_painel.position = _deslocamento_da_caixa(escolhido)
	_painel.size = caixa
	_seta.position = Vector2.ZERO
	_seta.size = total.size
	_desenhar_o_apontador(escolhido, botao, total, caixa)


## O retângulo do popover inteiro (caixa mais a seta) do `no_lado` do botão, com o eixo de cruzamento já
## empurrado para dentro da tela.
func _retangulo_do_lado(no_lado: int, botao: Rect2, caixa: Vector2, tela: Vector2) -> Rect2:
	var horizontal := no_lado == Lado.DIREITA or no_lado == Lado.ESQUERDA
	var total := caixa + (Vector2(SETA, 0.0) if horizontal else Vector2(0.0, SETA))
	var origem := Vector2.ZERO
	match no_lado:
		Lado.DIREITA:
			origem = Vector2(botao.end.x + FOLGA_DO_BOTAO, botao.get_center().y - total.y * 0.5)
		Lado.ESQUERDA:
			origem = Vector2(botao.position.x - FOLGA_DO_BOTAO - total.x, botao.get_center().y - total.y * 0.5)
		Lado.ABAIXO:
			origem = Vector2(botao.get_center().x - total.x * 0.5, botao.end.y + FOLGA_DO_BOTAO)
		Lado.ACIMA:
			origem = Vector2(botao.get_center().x - total.x * 0.5, botao.position.y - FOLGA_DO_BOTAO - total.y)
	if horizontal:
		origem.y = clampf(origem.y, MARGEM_DA_TELA, maxf(tela.y - total.y - MARGEM_DA_TELA, MARGEM_DA_TELA))
	else:
		origem.x = clampf(origem.x, MARGEM_DA_TELA, maxf(tela.x - total.x - MARGEM_DA_TELA, MARGEM_DA_TELA))
	return Rect2(origem, total)


func _oposto(no_lado: int) -> int:
	match no_lado:
		Lado.DIREITA:
			return Lado.ESQUERDA
		Lado.ESQUERDA:
			return Lado.DIREITA
		Lado.ABAIXO:
			return Lado.ACIMA
	return Lado.ABAIXO


## Onde a caixa fica dentro do popover: do lado oposto ao botão, deixando o espaço da seta.
func _deslocamento_da_caixa(no_lado: int) -> Vector2:
	match no_lado:
		Lado.DIREITA:
			return Vector2(SETA, 0.0)
		Lado.ABAIXO:
			return Vector2(0.0, SETA)
	return Vector2.ZERO


## Calcula a ponta e a base da seta, no espaço do popover, para o centro do botão.
func _desenhar_o_apontador(no_lado: int, botao: Rect2, total: Rect2, caixa: Vector2) -> void:
	var deslocamento := _deslocamento_da_caixa(no_lado)
	var horizontal := no_lado == Lado.DIREITA or no_lado == Lado.ESQUERDA
	# `fora` aponta da caixa para o botão; `ao_longo`, pela aresta.
	var fora := Vector2.ZERO
	match no_lado:
		Lado.DIREITA:
			fora = Vector2.LEFT
		Lado.ESQUERDA:
			fora = Vector2.RIGHT
		Lado.ABAIXO:
			fora = Vector2.UP
		Lado.ACIMA:
			fora = Vector2.DOWN
	var ao_longo := Vector2.DOWN if horizontal else Vector2.RIGHT
	var centro_no_popover := botao.get_center() - total.position
	var t: float = centro_no_popover.y if horizontal else centro_no_popover.x
	var comprimento: float = caixa.y if horizontal else caixa.x
	var inicio: float = deslocamento.y if horizontal else deslocamento.x
	t = clampf(t, inicio + CANTO + SETA_META_BASE, inicio + comprimento - CANTO - SETA_META_BASE)
	var aresta: Vector2
	match no_lado:
		Lado.DIREITA:
			aresta = Vector2(SETA, t)
		Lado.ESQUERDA:
			aresta = Vector2(caixa.x, t)
		Lado.ABAIXO:
			aresta = Vector2(t, SETA)
		_:
			aresta = Vector2(t, caixa.y)
	_ponta = aresta + fora * SETA
	_base_a = aresta - ao_longo * SETA_META_BASE
	_base_b = aresta + ao_longo * SETA_META_BASE
	_para_dentro = -fora
	_seta.queue_redraw()


func _desenhar_seta() -> void:
	# O miolo entra 1,5 px na caixa para apagar o trecho do filete onde a seta nasce.
	var a_dentro := _base_a + _para_dentro * 1.5
	var b_dentro := _base_b + _para_dentro * 1.5
	_seta.draw_colored_polygon(PackedVector2Array([_ponta, _base_a, a_dentro, b_dentro, _base_b]), FUNDO)
	_seta.draw_line(_base_a, _ponta, FILETE, 1.2, true)
	_seta.draw_line(_ponta, _base_b, FILETE, 1.2, true)
