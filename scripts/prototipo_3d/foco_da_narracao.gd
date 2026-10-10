extends Control
## A caixa longa reserva seu espaço sem alterar o estado dos avisos do mundo.
##
## O QUE ELE GUARDA É SÓ A OPACIDADE (#222). Ele recolhe um componente tirando o alfa do `modulate`
## e o devolve quando a caixa sai da frente; guardar o `modulate` inteiro e devolvê-lo depois
## era devolver também a COR de quem o escureceu: a explicação das barras (`destacar_barra`)
## apaga o HUD em cinza, e a barra de mão, que a caixa de fala cobre, era recolhida apagada. O
## destaque terminava e devolvia o branco, mas este nó, um quadro depois, restaurava o cinza
## guardado, e a barra ficava escurecida, como desativada, até o fim da sessão. Agora cada um
## mexe no que é seu: o destaque na cor, este nó no alfa.
##
## A NARRAÇÃO TEM A PRIORIDADE MÁXIMA (#106, `PopupsDoMundo.PRIORIDADE_NARRACAO`): enquanto a caixa
## está aberta, tudo o que a cobre se apaga (o HUD nomeado em `componentes_da_narracao` e QUALQUER
## outro painel do grupo `obstaculos_do_hud`, como o do testador), e volta como estava ao fechar. O
## que a fala explica ganha um contorno dourado.
const PopupsDoMundo = preload("res://scripts/prototipo_3d/popups_do_mundo.gd")

var hud: CanvasLayer
var _recolhidos: Dictionary = {}
var _destaques: Array[Rect2] = []

static func retangulo(controle: Control) -> Rect2:
	return controle.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, controle.size)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100

func _process(_delta: float) -> void:
	if hud == null:
		return
	var dialogo := get_node("/root/Dialogo")
	var caixa: Rect2 = dialogo.retangulo_da_caixa()
	var focos: Array = dialogo.interfaces_em_foco()
	var componentes: Dictionary = hud.componentes_da_narracao()
	_somar_os_outros_paineis(componentes)
	_destaques.clear()
	for chave: String in componentes:
		var controles: Array = componentes[chave]
		var sobreposto := false
		for controle: Control in controles:
			if is_instance_valid(controle) and controle.is_visible_in_tree() and retangulo(controle).intersects(caixa):
				sobreposto = dialogo.ativo
		for controle: Control in controles:
			if not is_instance_valid(controle):
				continue
			var id := controle.get_instance_id()
			if sobreposto:
				if not _recolhidos.has(id):
					_recolhidos[id] = [weakref(controle), controle.modulate.a]
				var cor: Color = controle.modulate
				cor.a = 0.0
				controle.modulate = cor
			elif _recolhidos.has(id):
				_devolver_a_opacidade(controle, float(_recolhidos[id][1]))
				_recolhidos.erase(id)
			if dialogo.ativo and chave in focos and not sobreposto and controle.is_visible_in_tree():
				_destaques.append(retangulo(controle).grow(4.0))
	queue_redraw()

## Os painéis do grupo `obstaculos_do_hud` que o HUD não nomeou (o do testador, o que vier) cedem
## do mesmo jeito à caixa.
func _somar_os_outros_paineis(componentes: Dictionary) -> void:
	var nomeados: Dictionary = {}
	for controles: Array in componentes.values():
		for controle in controles:
			nomeados[controle] = true
	for no in get_tree().get_nodes_in_group(PopupsDoMundo.GRUPO_HUD):
		var controle := no as Control
		if controle != null and not nomeados.has(controle):
			componentes["outro_%d" % controle.get_instance_id()] = [controle]

func _draw() -> void:
	var inversa := get_global_transform_with_canvas().affine_inverse()
	for caixa in _destaques:
		draw_rect(inversa * caixa, Color("f4d47b"), false, 3.0)

func _exit_tree() -> void:
	for item: Array in _recolhidos.values():
		var controle := item[0].get_ref() as Control
		if is_instance_valid(controle):
			_devolver_a_opacidade(controle, float(item[1]))


## Devolve o alfa de antes e deixa a cor como está agora (de quem a mudou por último).
static func _devolver_a_opacidade(controle: Control, alfa: float) -> void:
	var cor: Color = controle.modulate
	cor.a = alfa
	controle.modulate = cor
