extends Node
## O E TEM UM DONO SÓ: o que está à frente do jogador, e mais perto.
##
## "Ao tentar interagir com o cordel e tem um NPC próximo, ele foca somente na
## seleção do NPC e não consigo clicar no cordel. Imagino que o mesmo acontece
## com outras coisas no jogo. Precisa revisar toda estrutura afim de propor uma
## solução e corrigir isso."
##
##
## COMO ERA
##
## Cada coisa que responde ao E — o morador, o cordel, a árvore, a lápide, o
## alvo de trabalho, a bancada, o marco da fé, o leito da lavoura, a cama e o
## baú, a água da pesca — media sozinha o que tinha ao alcance, acendia a
## própria dica e esperava a tecla no `_unhandled_key_input`. Recebia a tecla
## primeiro o último nó posto no vale, e a ordem da árvore de nós virou regra de
## jogo: o E dos moradores entrava por último de propósito ("com alguém ao
## alcance, conversar vem antes de cortar a árvore"), e com a Dona Candinha a
## dois passos o cordel aos pés nunca recebia o E. Os remendos foram caso a
## caso: a árvore perguntando a quatro vizinhos se a tecla era deles
## (`arvores_info._outro_dono_do_e`), o cordel da capela mudado de lugar porque o
## marco ao lado o engolia. E duas dicas acesas ao mesmo tempo diziam que as
## duas coisas aceitavam o E, quando só uma aceitava.
##
##
## COMO É
##
## Cada uma responde a UMA pergunta, `alvo_do_e()`: o que faria com o E agora, e
## onde — {"ponto": Vector3} ou {} quando nada. Este nó ouve todas (as do grupo
## GRUPO) e escolhe uma só: a de menor conta, que é a distância no chão MAIS o
## rumo — o que está na frente do corpo vence o que está de lado, e o de lado
## vence o de costas (PESO_DO_RUMO). A escolhida acende a dica e leva a tecla; as
## outras apagam a dica e deixam a tecla passar. Para pegar o cordel com a Dona
## Candinha do lado, basta virar para ele; para conversar com ela, virar para
## ela.
##
## O RUMO SOMA, E NÃO MULTIPLICA. A primeira conta multiplicava a distância pelo
## rumo, e de perto o rumo quase não pesava: com o Tonho a um passo, na frente, o
## cordel colado no pé, de lado, ainda ganhava — virar para quem se quer
## conversar não bastava. Somado em unidades, o rumo decide de perto, que é onde
## o jogador escolhe virando o corpo.
##
## O "vies" de uma resposta, opcional e em unidades, desconta da conta: o alvo de
## trabalho grande desconta a meia-pegada (encostado nele, a distância é a da
## face, e não a do centro); a árvore, que está em toda parte, entra com viés
## negativo e só ganha de coisa posta de propósito bem mais perto; o que está
## ABERTO — a ficha da árvore, a lápide lida, a vara na água — entra com viés
## grande, porque o E dele é para fechar ou recolher.
##
## A escolha se refaz uma vez por quadro, na primeira pergunta (`dono`), e vale
## para todos nele: a dica e a tecla nunca discordam.
##
## O QUE FICA DE FORA: a luta (com bicho perto o E é golpe, antes de tudo), o
## ferrar da pesca (o peixe mordendo não espera) e as telas (o E delas é delas).
## A barra de mão come o que está na mão só quando ninguém leva o E (`alguem`).

const GRUPO := "fontes_do_e"
## O quanto pesa o rumo, em unidades somadas à distância: PESO_DO_RUMO × (1 −
## cosseno) — nada na frente, 1,5 de lado, 3 de costas.
const PESO_DO_RUMO := 1.5
## Abaixo disto o alvo está colado no corpo, e o rumo não conta.
const COLADO := 0.3

var _jogador: Node3D
var _quadro := -1
var _dono: Object = null


func configurar(jogador: Node3D) -> void:
	_jogador = jogador
	add_to_group("foco_do_e")


## Quem leva o E neste quadro, ou null.
func dono() -> Object:
	var agora := Engine.get_process_frames()
	if agora != _quadro:
		_quadro = agora
		_dono = _escolher()
	return _dono


func _escolher() -> Object:
	if _jogador == null or not is_instance_valid(_jogador) or not is_inside_tree():
		return null
	var frente := _frente()
	var melhor: Object = null
	var menor := INF
	for fonte in get_tree().get_nodes_in_group(GRUPO):
		if not fonte.has_method("alvo_do_e"):
			continue
		var alvo: Dictionary = fonte.alvo_do_e()
		if alvo.is_empty():
			continue
		var conta := conta_do_alvo(alvo, _jogador.global_position, frente)
		if conta < menor:
			menor = conta
			melhor = fonte
	return melhor


## A CONTA DE UM ALVO: a distância no chão, mais o rumo, menos o viés.
static func conta_do_alvo(alvo: Dictionary, de: Vector3, frente: Vector3) -> float:
	var ponto: Vector3 = alvo.get("ponto", de)
	var falta := Vector2(ponto.x - de.x, ponto.z - de.z)
	var distancia := falta.length()
	var cosseno := 1.0
	var plano := Vector2(frente.x, frente.z)
	if distancia > COLADO and plano.length() > 0.01:
		cosseno = falta.normalized().dot(plano.normalized())
	return distancia + PESO_DO_RUMO * (1.0 - cosseno) - float(alvo.get("vies", 0.0))


## Para onde o corpo do jogador está virado (o `visual` gira; o corpo não).
func _frente() -> Vector3:
	var visual = _jogador.get("visual")
	if visual is Node3D:
		var giro: float = (visual as Node3D).rotation.y
		return Vector3(sin(giro), 0.0, cos(giro))
	return Vector3.ZERO


## ESTA FONTE LEVA O E AGORA? Sem foco no vale — um portão que monta uma peça só
## —, cada fonte leva o que é seu, como antes.
static func e_dele(fonte: Node) -> bool:
	if fonte == null or not fonte.is_inside_tree():
		return true
	var foco := fonte.get_tree().get_first_node_in_group("foco_do_e")
	return foco == null or foco.dono() == fonte


## ALGUÉM LEVA O E AGORA? A barra de mão só come o que está na mão quando não.
static func alguem(no: Node) -> bool:
	if no == null or not no.is_inside_tree():
		return false
	var foco := no.get_tree().get_first_node_in_group("foco_do_e")
	return foco != null and foco.dono() != null
