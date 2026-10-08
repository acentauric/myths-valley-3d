extends CanvasLayer
## A TELA DE ACEITE DA MISSÃO (08/10: "deve ter uma tela resumo sobre a missão para o jogador
## aceitar ela ou não"). O E no morador que tem fila por abrir (`CadeiaDeMissoes.o_que_o_e_faz`
## == "abrir") não abre mais a fila na hora: abre ESTA tela — o nome da missão, quem pede, o
## que ele diz (a fala do primeiro passo), o primeiro passo, quantos passos, e a recompensa
## somada da fila — com Aceitar [E] e Agora não [Esc]. Quem aceita vê a fila começar como
## antes (`CadeiaDeMissoes.interagir`); quem recusa fica com o "!" sobre a cabeça do morador
## (`npc._marcador`), e nada muda.
##
## É tela do vale (`TelasDoVale`, "aceite"): abrir para o vale como o painel; o Esc fecha, e
## fechar é recusar. Nenhuma tecla a abre — é o E no morador que a pede
## (`tecla_dos_moradores.usar` → `propor`).

signal respondeu(aceitou: bool)

const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")

const CAMADA := 26
const TAMANHO := Vector2(640, 460)
const COR_TEXTO := Color("e8e4d7")
const COR_FUNDO := Color(0.055, 0.085, 0.075, 0.96)
const COR_BORDA := Color(0.84, 0.73, 0.47, 0.8)
const ICONE_DOS_REIS := "res://assets/sprites/icones/reis.png"
const ICONE_DO_XP := "res://assets/sprites/icones/xp.png"
## Quantas letras da fala do primeiro passo cabem na tela.
const LETRAS_DA_FALA := 280

var aberto := false
## ACEITE AUTOMÁTICO: a fila começa sem a tela. É para os portões que dirigem as filas na mão (o E
## no morador abre a fila e o portão segue; a tela pausaria o vale no meio da medida). O portão
## da própria tela (tests/missao_a_vista.gd) a deixa desligada.
var automatico := false
var _telas: Node
var _cadeia: Node
var _morador: Node3D
var _ao_aceitar: Callable
var _caixa: PanelContainer
var _coluna: VBoxContainer
var _titulo_a_vista := ""
var _quem_a_vista := ""
var _recompensa_a_vista: Dictionary = {}


func configurar(telas: Node) -> void:
	_telas = telas
	layer = CAMADA
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_montar()


## O E NO MORADOR PEDE A TELA para esta fila. `ao_aceitar` é o que abre a fila de fato.
func propor(cadeia: Node, morador: Node3D, ao_aceitar: Callable) -> void:
	if aberto or cadeia == null:
		return
	if automatico:
		if ao_aceitar.is_valid():
			ao_aceitar.call()
		return
	_cadeia = cadeia
	_morador = morador
	_ao_aceitar = ao_aceitar
	if _telas != null and _telas.has_method("abrir_por"):
		_telas.abrir_por("aceite", abrir)
	else:
		abrir()


func abrir() -> void:
	if aberto or _cadeia == null or not is_instance_valid(_cadeia):
		return
	aberto = true
	_preencher()
	visible = true


func aceitar() -> void:
	if not aberto:
		return
	var fazer := _ao_aceitar
	_fechar(true)
	if fazer.is_valid():
		fazer.call()


func recusar() -> void:
	if aberto:
		_fechar(false)


## O que o dono das telas chama ao fechar (o Esc, outra tela abrindo): fechar é recusar.
func fechar() -> void:
	recusar()


func titulo_a_vista() -> String:
	return _titulo_a_vista if aberto else ""


func quem_a_vista() -> String:
	return _quem_a_vista if aberto else ""


func recompensa_a_vista() -> Dictionary:
	return _recompensa_a_vista.duplicate() if aberto else {}


func _fechar(aceitou: bool) -> void:
	aberto = false
	visible = false
	_cadeia = null
	_morador = null
	_ao_aceitar = Callable()
	respondeu.emit(aceitou)
	# A tela fechou por conta própria: o dono das telas solta o vale (sem repetir quando foi ele
	# que mandou fechar — ele sabe, `fechou_por_conta`).
	if _telas != null and _telas.has_method("fechou_por_conta"):
		_telas.fechou_por_conta("aceite")


func _unhandled_input(evento: InputEvent) -> void:
	if not aberto:
		return
	if not (evento is InputEventKey and evento.pressed and not evento.echo):
		return
	var tecla: int = (evento as InputEventKey).physical_keycode
	if tecla == KEY_ESCAPE or tecla == KEY_Q:
		recusar()
	elif tecla == Atalhos.tecla("interagir") or tecla == KEY_ENTER or tecla == KEY_KP_ENTER or tecla == KEY_SPACE:
		aceitar()
	else:
		return
	get_viewport().set_input_as_handled()


# --- a montagem ------------------------------------------------------------------------------

func _montar() -> void:
	var veu := ColorRect.new()
	veu.name = "Veu"
	veu.color = Color(0.0, 0.0, 0.0, 0.45)
	veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veu)
	_caixa = PanelContainer.new()
	_caixa.name = "Caixa"
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_FUNDO
	estilo.border_color = COR_BORDA
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(10)
	estilo.set_content_margin_all(22)
	_caixa.add_theme_stylebox_override("panel", estilo)
	_caixa.set_anchors_preset(Control.PRESET_CENTER)
	_caixa.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caixa.grow_vertical = Control.GROW_DIRECTION_BOTH
	_caixa.custom_minimum_size = TAMANHO
	_caixa.offset_left = -TAMANHO.x * 0.5
	_caixa.offset_right = TAMANHO.x * 0.5
	_caixa.offset_top = -TAMANHO.y * 0.5
	_caixa.offset_bottom = TAMANHO.y * 0.5
	add_child(_caixa)
	Identidade.emoldurar(_caixa)
	_coluna = VBoxContainer.new()
	_coluna.name = "Coluna"
	_coluna.add_theme_constant_override("separation", 10)
	_caixa.add_child(_coluna)


func _preencher() -> void:
	for filho in _coluna.get_children():
		filho.queue_free()
	var passos: Array = _cadeia.get("passos") if _cadeia.get("passos") is Array else []
	var primeiro: Dictionary = passos[0] if not passos.is_empty() else {}
	var principal: bool = bool(_cadeia.get("principal"))
	_titulo_a_vista = str(_cadeia.get("nome_da_missao"))
	if _titulo_a_vista == "" and not primeiro.is_empty():
		_titulo_a_vista = str(IdiomaMenu.campo(primeiro, "titulo", ""))
	_quem_a_vista = _nome_do_dono()
	_recompensa_a_vista = _recompensa_somada(passos)

	_coluna.add_child(Identidade.rotulo(tr("Missão principal") if principal else tr("Favor de vizinho"), 12, Identidade.OURO))
	var titulo := _texto(_titulo_a_vista, 26, COR_TEXTO)
	titulo.name = "Titulo"
	titulo.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600, 1))
	_coluna.add_child(titulo)
	var quem := _texto(tr("Quem pede: %s") % _quem_a_vista, 16, Identidade.OURO)
	quem.name = "QuemPede"
	quem.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_ITALICO, 500))
	_coluna.add_child(quem)
	_coluna.add_child(Identidade.divisor())

	# O QUE ELE DIZ: a fala do primeiro passo, no idioma do jogo, cortada no que cabe.
	var fala := str(IdiomaMenu.campo(primeiro, "texto", "")).strip_edges()
	if fala.length() > LETRAS_DA_FALA:
		var corte := fala.rfind(" ", LETRAS_DA_FALA)
		fala = fala.left(corte if corte > LETRAS_DA_FALA / 2 else LETRAS_DA_FALA).strip_edges() + "…"
	if fala != "":
		var dito := _texto("“%s”" % fala, 17, COR_TEXTO)
		dito.name = "Fala"
		_coluna.add_child(dito)

	# O PRIMEIRO PASSO E O TAMANHO DA MISSÃO.
	if not primeiro.is_empty() and _cadeia.has_method("resumo_do_passo"):
		var passo := _texto(tr("Primeiro passo: %s") % str(_cadeia.resumo_do_passo(primeiro)), 15, COR_TEXTO)
		passo.name = "PrimeiroPasso"
		_coluna.add_child(passo)
	var quantos := _texto(tr("%d passos") % passos.size(), 13, Color(0.78, 0.75, 0.66))
	quantos.name = "Passos"
	_coluna.add_child(quantos)

	# A RECOMPENSA, em ícones, como no diário (`painel_vale.gd`).
	if not _recompensa_a_vista.is_empty():
		_coluna.add_child(Identidade.rotulo(tr("Recompensa"), 12, Identidade.OURO))
		var linha := HBoxContainer.new()
		linha.name = "Recompensa"
		linha.add_theme_constant_override("separation", 16)
		_coluna.add_child(linha)
		for chave in _recompensa_a_vista:
			var item := HBoxContainer.new()
			item.add_theme_constant_override("separation", 6)
			var icone := _icone(str(chave))
			if icone != null:
				var figura := TextureRect.new()
				figura.texture = icone
				figura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				figura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				figura.custom_minimum_size = Vector2(28, 28)
				figura.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if str(chave) in ["reis", "xp"] else CanvasItem.TEXTURE_FILTER_NEAREST
				item.add_child(figura)
			var conta := _texto(_nome_da_recompensa(str(chave), int(_recompensa_a_vista[chave])), 15, COR_TEXTO)
			conta.autowrap_mode = TextServer.AUTOWRAP_OFF
			conta.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			conta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			item.add_child(conta)
			linha.add_child(item)

	# OS BOTÕES.
	var respiro := Control.new()
	respiro.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_coluna.add_child(respiro)
	var botoes := HBoxContainer.new()
	botoes.name = "Botoes"
	botoes.add_theme_constant_override("separation", 14)
	botoes.alignment = BoxContainer.ALIGNMENT_END
	_coluna.add_child(botoes)
	var recusa := _botao("%s  [Esc]" % tr("Agora não"))
	recusa.name = "AgoraNao"
	recusa.pressed.connect(recusar)
	botoes.add_child(recusa)
	var aceite := _botao("%s  [%s]" % [tr("Aceitar"), Atalhos.letra("interagir")])
	aceite.name = "Aceitar"
	aceite.pressed.connect(aceitar)
	botoes.add_child(aceite)


func _nome_do_dono() -> String:
	var dono = _cadeia.get("dono")
	if dono != null and is_instance_valid(dono) and "dados" in dono:
		return str((dono.dados as Dictionary).get("nome", ""))
	if _morador != null and is_instance_valid(_morador) and "dados" in _morador:
		return str((_morador.dados as Dictionary).get("nome", ""))
	return ""


## A recompensa de toda a fila, somada por chave (réis, XP e itens).
static func _recompensa_somada(passos: Array) -> Dictionary:
	var soma := {}
	for passo in passos:
		if not (passo is Dictionary):
			continue
		var recompensa: Dictionary = (passo as Dictionary).get("recompensa", {})
		for chave in recompensa:
			soma[str(chave)] = int(soma.get(str(chave), 0)) + int(recompensa[chave])
	return soma


func _icone(chave: String) -> Texture2D:
	match chave:
		"reis":
			return load(ICONE_DOS_REIS) as Texture2D if ResourceLoader.exists(ICONE_DOS_REIS) else null
		"xp":
			return load(ICONE_DO_XP) as Texture2D if ResourceLoader.exists(ICONE_DO_XP) else null
		_:
			return Catalogo.icone(chave)


func _nome_da_recompensa(chave: String, quanto: int) -> String:
	match chave:
		"reis":
			return tr("%d réis") % quanto
		"xp":
			return "%d XP" % quanto
		_:
			return "×%d  %s" % [quanto, str(Catalogo.ITENS.get(chave, {}).get("nome", chave))]


func _texto(texto: String, tamanho: int, cor: Color) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	etiqueta.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TEXTO, 400))
	etiqueta.add_theme_font_size_override("font_size", tamanho)
	etiqueta.add_theme_color_override("font_color", cor)
	return etiqueta


func _botao(texto: String) -> Button:
	var botao := Button.new()
	botao.text = texto
	botao.focus_mode = Control.FOCUS_NONE
	botao.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	botao.custom_minimum_size = Vector2(190, 40)
	botao.add_theme_font_override("font", Identidade.fonte(Identidade.FONTE_TITULO, 600))
	botao.add_theme_font_size_override("font_size", 14)
	return botao
