extends Node
## O E NOS MORADORES: chegar perto de alguém e apertar E é conversar — e é assim
## que se cumpre o passo que manda falar com ele ou levar alguma coisa, e que se
## abre a fila de pedidos de quem tem o que pedir.
##
## "O ideal é o Pedro ensinar a apertar E para iniciar as interações com os NPCs,
## incluindo cumprir etapas de missões." No 2D é assim ("Converse com cada
## morador do arraial: chegue perto e aperte E"). No vale o encontro fechava
## sozinho ao chegar perto, e quem apertava o E — a tecla de tudo o mais — não
## via nada acontecer: "Quando fui falar com Dona Candinha para pegar a chave,
## não consegui interagir." O Pedro ensina no desembarque.
##
## Quem decide o que a conversa faz são as filas (`CadeiaDeMissoes.interagir`),
## perguntadas uma a uma; nenhuma usando, o morador conversa (`conversar`).
##
## Mesmo molde das bancadas (`tecla_das_bancadas.gd`): a dica da tecla em cima
## de quem está ao alcance, e o E no `_unhandled_key_input`. QUEM LEVA O E É O
## FOCO (`foco_do_e.gd`): o morador concorre com o cordel, a árvore e o resto
## pelo que está à frente do jogador e mais perto. Ele chegou a vir por último na
## árvore de nós para receber a tecla antes de todos — "conversar vem antes de
## cortar a árvore" —, e com alguém a dois passos o cordel aos pés não se pegava.

const DicaTecla = preload("res://scripts/prototipo_3d/dica_tecla.gd")
const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
const CadeiaDeMissoes = preload("res://scripts/prototipo_3d/cadeia_de_missoes.gd")
const FocoDoE = preload("res://scripts/prototipo_3d/foco_do_e.gd")

## De quão perto se conversa, no chão.
const ALCANCE := 2.8
## A dica fica acima da cabeça de quem está ao alcance.
const ACIMA_DA_CABECA := 0.45

var _jogador: Node3D
## Os moradores e o Pedro, perguntados ao vale a cada quadro (o mestre Quirino
## some e volta com o saveiro).
var _quem_mora: Callable
## Pode usar o E agora? (Ninguém lendo, nenhuma tela aberta: `Prototype`.)
var _livre: Callable
var _dica: PanelContainer
## Quem está ao alcance agora, ou null.
var _perto: Node3D = null


func configurar(jogador: Node3D, hud, quem_mora: Callable, livre: Callable) -> void:
	_jogador = jogador
	_quem_mora = quem_mora
	_livre = livre
	_dica = DicaTecla.criar(hud.map_layer(), Atalhos.letra("interagir"), "")
	add_to_group(FocoDoE.GRUPO)


## Quem leva o E da conversa agora, ou null: ao alcance E com o foco.
func perto() -> Node3D:
	return _perto


## O QUE O E FARIA AQUI, para o foco (`foco_do_e.gd`): conversar com quem está
## ao alcance.
func alvo_do_e() -> Dictionary:
	var quem := _ao_alcance()
	return {} if quem == null else {"ponto": quem.global_position}


## Quem está ao alcance da conversa, com o jogador em jogo e o E livre.
func _ao_alcance() -> Node3D:
	if _jogador == null:
		return null
	var camera := get_viewport().get_camera_3d()
	var em_jogo: bool = camera != null and camera == _jogador.get("camera")
	if em_jogo and _jogador.is_physics_processing() and not Dialogo.ocupado() \
			and (not _livre.is_valid() or bool(_livre.call())):
		return _mais_perto()
	return null


func _process(_delta: float) -> void:
	if _jogador == null or _dica == null:
		return
	_perto = _ao_alcance()
	if _perto != null and not FocoDoE.e_dele(self):
		_perto = null
	if _perto == null:
		_dica.visible = false
		return
	var camera := get_viewport().get_camera_3d()
	var altura := float(_perto.get("altura")) if _perto.get("altura") != null else 1.75
	DicaTecla.mostrar_em(_dica, camera, _perto.global_position + Vector3.UP * (altura + ACIMA_DA_CABECA), tr(_rotulo(_perto)))


func _mais_perto() -> Node3D:
	var melhor: Node3D = null
	var menor := ALCANCE
	if not _quem_mora.is_valid():
		return null
	for no in _quem_mora.call():
		var morador := no as Node3D
		if morador == null or not is_instance_valid(morador) or not morador.is_visible_in_tree() \
				or not morador.can_process():
			continue
		var falta := morador.global_position - _jogador.global_position
		if absf(falta.y) > 2.0:
			continue
		falta.y = 0.0
		if falta.length() <= menor:
			menor = falta.length()
			melhor = morador
	return melhor


## "Entregar" quando a conversa entrega o que um passo pede; "Falar", senão.
func _rotulo(morador: Node3D) -> String:
	for cadeia in get_tree().get_nodes_in_group(CadeiaDeMissoes.GRUPO):
		if cadeia.has_method("o_que_o_e_faz") and cadeia.o_que_o_e_faz(morador) == "entregar":
			return "Entregar"
	return "Falar"


func _unhandled_key_input(event: InputEvent) -> void:
	if _perto == null:
		return
	if not (event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == Atalhos.tecla("interagir")):
		return
	if Dialogo.ocupado() or not _jogador.is_physics_processing() or not FocoDoE.e_dele(self):
		return
	get_viewport().set_input_as_handled()
	usar(_perto)


## Conversa com `morador`: a primeira fila que usar a conversa a leva; nenhuma
## usando, ele conversa. Público para o portão chamar sem simular tecla.
##
## PRIMEIRO O QUE SE VEIO FAZER: a entrega ou a conversa que um passo manda ter
## com ele — o pirão da Dona Filó levado ao Tonho —, e só depois abrir a fila
## dele, que de outro modo tomaria a conversa.
func usar(morador: Node3D) -> void:
	if morador == null:
		return
	_dica.visible = false
	var cadeias := get_tree().get_nodes_in_group(CadeiaDeMissoes.GRUPO)
	for cadeia in cadeias:
		if not cadeia.has_method("o_que_o_e_faz"):
			continue
		var faz := str(cadeia.o_que_o_e_faz(morador))
		if (faz == "falar" or faz == "entregar") and cadeia.interagir(morador):
			return
	for cadeia in cadeias:
		if cadeia.has_method("interagir") and cadeia.interagir(morador):
			return
	if morador.has_method("conversar"):
		morador.conversar()
