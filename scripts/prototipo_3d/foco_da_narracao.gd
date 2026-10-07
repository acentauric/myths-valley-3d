extends Control
## A caixa longa reserva seu espaço sem alterar o estado dos avisos do mundo.
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
	var caixa := retangulo(dialogo._painel) if dialogo.ativo else Rect2()
	var focos: Array = dialogo.interfaces_em_foco()
	var componentes: Dictionary = hud.componentes_da_narracao()
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
					_recolhidos[id] = [weakref(controle), controle.modulate]
				var cor: Color = controle.modulate
				cor.a = 0.0
				controle.modulate = cor
			elif _recolhidos.has(id):
				controle.modulate = _recolhidos[id][1]
				_recolhidos.erase(id)
			if dialogo.ativo and chave in focos and not sobreposto and controle.is_visible_in_tree():
				_destaques.append(retangulo(controle).grow(4.0))
	queue_redraw()

func _draw() -> void:
	var inversa := get_global_transform_with_canvas().affine_inverse()
	for caixa in _destaques:
		draw_rect(inversa * caixa, Color("f4d47b"), false, 3.0)

func _exit_tree() -> void:
	for item: Array in _recolhidos.values():
		var controle := item[0].get_ref() as Control
		if is_instance_valid(controle):
			controle.modulate = item[1]
