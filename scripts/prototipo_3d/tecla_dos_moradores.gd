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
## O que as filas de missão dizem que o E faz com um morador, pelo valor (menor
## vale mais): é a primeira pergunta de quem leva a conversa (`escolher_entre`).
const ACAO_PEDIDA := 0
const ACAO_QUE_ABRE := 1
const ACAO_NENHUMA := 2

var _jogador: Node3D
## Os moradores e o Pedro, perguntados ao vale a cada quadro (o mestre Quirino
## some e volta com o saveiro).
var _quem_mora: Callable
## Pode usar o E agora? (Ninguém lendo, nenhuma tela aberta: `Prototype`.)
var _livre: Callable
## A tela de aceite da missão (aceite_de_missao.gd), posta pelo vale; sem ela a fila abre na hora.
var aceite: Node
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
	if quem == null:
		return {}
	# QUEM O PASSO MANDA PROCURAR LEVA O E COM FOLGA, como o sítio de obra que a missão pede: o jogador
	# parado de frente para ele, a dois passos, perdia a tecla para o toco de lenha ao lado do Damião e
	# para o canteiro do roçado ao lado do Cosme ("não consegui interagir"). O viés é a DISTÂNCIA até ele,
	# e a conta dele fica só com o rumo — a mesma regra de `TeclaDasBancadas.vies_da_obra_pedida`. Assim a
	# pessoa vence o toco e o canteiro que estão ao lado dela, a não ser que o jogador esteja virado para
	# eles e de costas para ela; e, de frente para o sítio de obra que a missão pede, com o Pedro ao lado e
	# o passo dele aberto, o sítio vence (um viés fixo de 2,5 u, que foi o primeiro conserto, deixava o
	# Pedro ganhar do mirante: `tests/obras_com_e.gd` reprovou).
	var longe :=Vector2(quem.global_position.x - _jogador.global_position.x, quem.global_position.z - _jogador.global_position.z).length()
	return {"ponto": quem.global_position, "vies": longe if _acao_das_filas(quem) == ACAO_PEDIDA else 0.0}


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
	DicaTecla.mostrar_em(_dica, camera, _perto.global_position + Vector3.UP * (altura + ACIMA_DA_CABECA), _dica_de(_perto))


## QUEM LEVA A CONVERSA ENTRE OS QUE ESTÃO AO ALCANCE: primeiro o que as filas de
## missão dizem que o E faz com cada um, e SÓ DEPOIS a distância (`escolher_entre`).
##
## Era o mais perto, e o mais perto não é quem a missão manda procurar. No píer o
## Pedro e o Tonho ficam a dois passos um do outro de propósito, e o Pedro segue o
## jogador: com ele a um passo, o passo "fale com o Tonho" abria a conversa do
## Pedro, que só repetia o passo — e quem apertava o E de novo apertava de novo no
## Pedro. O mesmo valia para o Cosme ao lado da Dona Zefa e para o Seu Benedito.
func _mais_perto() -> Node3D:
	if not _quem_mora.is_valid():
		return null
	var candidatos: Array = []
	for no in _quem_mora.call():
		var morador := no as Node3D
		if morador == null or not is_instance_valid(morador) or not morador.is_visible_in_tree() \
				or not morador.can_process():
			continue
		var falta := morador.global_position - _jogador.global_position
		if absf(falta.y) > 2.0:
			continue
		falta.y = 0.0
		if falta.length() > ALCANCE:
			continue
		candidatos.append({
			"no": morador,
			"acao": _acao_das_filas(morador),
			"mudo": morador.has_method("eh_mudo") and bool(morador.call("eh_mudo")),
			"distancia": falta.length(),
		})
	var escolhido := escolher_entre(candidatos)
	return null if escolhido < 0 else candidatos[escolhido]["no"] as Node3D


## O QUE O E FARIA COM ESTE MORADOR segundo as filas, pelo valor: `ACAO_PEDIDA`
## quando o passo de agora manda entregar-lhe algo ou falar com ele, `ACAO_QUE_ABRE`
## quando o E abre uma fila dele, e `ACAO_NENHUMA` quando é só conversa.
func _acao_das_filas(morador: Node3D) -> int:
	var acao := ACAO_NENHUMA
	for cadeia in get_tree().get_nodes_in_group(CadeiaDeMissoes.GRUPO):
		if not cadeia.has_method("o_que_o_e_faz"):
			continue
		match str(cadeia.o_que_o_e_faz(morador)):
			"entregar", "falar":
				return ACAO_PEDIDA
			"abrir":
				acao = ACAO_QUE_ABRE
	return acao


## A REGRA DA ESCOLHA, sem mundo: cada candidato é {"acao", "mudo", "distancia"},
## e o índice do que leva o E sai de três perguntas, nesta ordem —
##
##   1. o que as filas dizem (pedido pelo passo > abre uma fila > nada);
##   2. quem fala antes de quem só acena: o saveirista parado no píer, que é mudo,
##      não toma o E de quem tem fala — a não ser que o passo mande procurar
##      justamente ele, e então a pergunta 1 já decidiu;
##   3. o mais perto.
##
## -1 sem candidato. Pública para o portão conferir a ordem sem montar o vale.
func escolher_entre(candidatos: Array) -> int:
	var melhor := -1
	for i in candidatos.size():
		if melhor < 0 or _vem_antes(candidatos[i], candidatos[melhor]):
			melhor = i
	return melhor


static func _vem_antes(a: Dictionary, b: Dictionary) -> bool:
	if int(a["acao"]) != int(b["acao"]):
		return int(a["acao"]) < int(b["acao"])
	if bool(a["mudo"]) != bool(b["mudo"]):
		return not bool(a["mudo"])
	return float(a["distancia"]) < float(b["distancia"])


## "Entregar a %s" quando a conversa entrega o que um passo pede; "Falar com %s",
## senão — o molde, que é o que se traduz; o nome entra em `_dica_de`.
func _rotulo(morador: Node3D) -> String:
	var entrega := false
	for cadeia in get_tree().get_nodes_in_group(CadeiaDeMissoes.GRUPO):
		if cadeia.has_method("o_que_o_e_faz") and cadeia.o_que_o_e_faz(morador) == "entregar":
			entrega = true
			break
	if _nome_de(morador) == "":
		return "Entregar" if entrega else "Falar"
	return "Entregar a %s" if entrega else "Falar com %s"


## A DICA DIZ O ALVO (#97): "Falar com Tonho", "Entregar a Candinha". O foco do E
## escolhe um morador só, e a dica dizia "Falar" sem dizer a quem — com um
## morador ao lado do cordel, na live, o jogador não sabia para quem o E ia.
func _dica_de(morador: Node3D) -> String:
	var molde := tr(_rotulo(morador))
	return molde % _nome_de(morador) if molde.contains("%s") else molde


func _nome_de(morador: Node3D) -> String:
	var dados = morador.get("dados")
	return str((dados as Dictionary).get("nome", "")) if dados is Dictionary else ""


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
	# A MISSÃO SE ACEITA (08/10: "deve ter uma tela resumo sobre a missão para o jogador
	# aceitar ela ou não"): a fila que o E abriria neste morador passa pela tela de aceite
	# (`AceiteDeMissao`). Quem aceita vê a fila começar como antes; quem recusa fica com o "!"
	# sobre a cabeça dele, e nada começa.
	for cadeia in cadeias:
		if cadeia.has_method("o_que_o_e_faz") and str(cadeia.o_que_o_e_faz(morador)) == "abrir":
			if aceite != null and aceite.has_method("propor"):
				aceite.propor(cadeia, morador, func() -> void: cadeia.interagir(morador))
				return
			break
	for cadeia in cadeias:
		if cadeia.has_method("interagir") and cadeia.interagir(morador):
			return
	if morador.has_method("conversar"):
		morador.conversar()
