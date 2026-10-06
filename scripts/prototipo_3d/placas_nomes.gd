extends Node
## Plaquinhas com o nome de cada morador, na identidade do HUD (painel escuro, borda e
## nome dourados), presas acima da cabeça. Somem enquanto o morador fala (o balão já
## traz o nome), longe demais ou atrás da câmera, com o morador fora do vale (o mestre
## Quirino fora do dia do saveiro: o rótulo dele continua `visible`, quem some é ele) e
## quando AJUSTAR → Cenário → Nomes dos personagens está em Ocultar.

const DISTANCIA_MAXIMA := 22.0
const ACIMA_DA_CABECA := 0.1
const FUNDO := Color(0.055, 0.085, 0.075, 0.88)
const OURO := Color("b49a60")
const NOME := Color("e2c47f")

var _jogador: Node3D
var _placas: Dictionary = {}
## Falso enquanto alguma tela está aberta. Ver `permitir`.
var _permitido := true


func configurar(jogador: Node3D, camada: Control) -> void:
	_jogador = jogador
	for morador in get_tree().get_nodes_in_group("moradores"):
		_placas[morador] = _criar(camada, String(morador.dados.get("nome", "Morador")))
		# O rótulo 3D antigo fica só como sinal de "sem balão"; quem aparece é a placa.
		if morador.get("nome_label") != null:
			morador.nome_label.modulate.a = 0.0
			morador.nome_label.outline_modulate.a = 0.0
			# Sem camada nenhuma a câmera não o enfileira (com alfa zero ele ainda entrava
			# na passada transparente); `visible` fica como está, que é o sinal de "sem balão".
			morador.nome_label.layers = 0


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var em_jogo: bool = camera != null and _jogador != null and camera == _jogador.get("camera")
	for morador: Node3D in _placas.keys():
		var placa: PanelContainer = _placas[morador]
		if not is_instance_valid(morador):
			placa.queue_free()
			_placas.erase(morador)
			continue
		var topo := morador.global_position + Vector3(0, float(morador.get("altura")) + ACIMA_DA_CABECA, 0)
		var mostrar: bool = _permitido and em_jogo and Estilo.mostrar_nomes and morador.nome_label.is_visible_in_tree() \
			and morador.global_position.distance_to(_jogador.global_position) < DISTANCIA_MAXIMA \
			and not camera.is_position_behind(topo)
		placa.visible = mostrar
		if mostrar:
			placa.reset_size()
			placa.position = camera.unproject_position(topo) - Vector2(placa.size.x * 0.5, placa.size.y)


func _criar(camada: Control, nome: String) -> PanelContainer:
	var placa := PanelContainer.new()
	placa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Nome flutuante pertence ao mundo; qualquer painel do HUD deve cobri-lo.
	placa.z_index = -1
	placa.visible = false
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = FUNDO
	estilo.border_color = OURO
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(6)
	estilo.content_margin_left = 9
	estilo.content_margin_right = 9
	estilo.content_margin_top = 3
	estilo.content_margin_bottom = 3
	placa.add_theme_stylebox_override("panel", estilo)
	var rotulo := Label.new()
	rotulo.text = nome
	rotulo.add_theme_font_size_override("font_size", 14)
	rotulo.add_theme_color_override("font_color", NOME)
	placa.add_child(rotulo)
	camada.add_child(placa)
	return placa


## PLAQUINHA DE NOME É COISA DO MUNDO, e some com qualquer tela aberta.
##
## "Quando abro os MENUs, o nome do Pedro tá sobrescrevendo os MENUs."
##
## A razão é ordem de irmãos. As plaquinhas moram no mesmo Control do HUD que o
## almanaque e a barra de mão, e entram DEPOIS deles — filho mais novo desenha
## por cima. Dava para consertar mexendo na ordem, ou pondo o almanaque numa
## camada própria, e as duas coisas consertariam este caso e deixariam o
## seguinte de pé: qualquer tela nova que nasça dentro do HUD volta a ser
## coberta.
##
## O conserto de fundo é de SENTIDO, não de camada: nome flutuando acima da
## cabeça de um morador é anotação sobre o vale, e com uma tela aberta não há
## vale à vista. Então elas somem — de todas as telas, de uma vez.
##
## Some NA HORA, e não no próximo `_process`: as telas pausam a árvore, e nó
## pausável não recebe mais `_process`. Esperar o quadro seguinte seria esperar
## para sempre.
func permitir(mostrar: bool) -> void:
	_permitido = mostrar
	if not mostrar:
		for morador in _placas.keys():
			var placa: PanelContainer = _placas[morador]
			if is_instance_valid(placa):
				placa.visible = false
