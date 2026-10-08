extends RefCounted
## O POVOADO INTEIRO EM CENA, para o portão que fala com morador de longe.
##
## Não é portão: o runner só roda `tests/*.gd`, e esta pasta fica fora disso.
##
## POR QUE EXISTE. Na chegada o vale se apresenta em pequenos grupos
## (`apresentacao_do_povoado.gd`, #155): fora do Pedro, do Tonho, da Dona Candinha, da Dona Zefa, de
## quem tem fila andando e dos mais próximos do jogador, o morador fica escondido, sem processo e
## sem colisão (e calado) até o jogador chegar a 65 m, e o orçamento só cresce com o tempo de jogo.
## Um portão que põe o jogador ao lado do Padre, do Cosme ou da Dona Filó de uma partida recém-aberta
## encontra ninguém: `visible` falso, `can_process` falso, e o E "não alcança" quem não está lá. Os
## portões das cadeias, das frentes e das falas vinham de antes dessa apresentação e reprovaram todos
## com o mesmo sintoma (morador fora do posto da hora; o E ao lado dele não aponta para nada).
##
## O QUE FAZ: espera o diretor da apresentação existir e o manda soltar todos
## (`liberar_todos`, o mesmo que `rotina_dos_moradores` e `missoes_elos` já chamam). A apresentação em
## grupos tem o portão dela (`apresentacao_do_povoado`), que NÃO usa isto.
##
##     const PovoadoLiberado = preload("res://tests/fixtures/povoado_liberado.gd")
##     ...
##     await PovoadoLiberado.todos(self, vale)


## Solta todos os moradores, bichos de casa e bandos do vale. `arvore` é o próprio portão (SceneTree).
static func todos(arvore: SceneTree, vale: Node) -> void:
	for i in 600:
		if vale.get("apresentacao_do_povoado") != null:
			break
		await arvore.process_frame
	var diretor = vale.get("apresentacao_do_povoado")
	if diretor != null:
		diretor.liberar_todos()
