extends Node3D
## A VOZ DO MUNDO NUM MARCO DE FÉ (#52).
##
## A missão própria de cada fé — a romaria, a mesa da folha, pagar o monte — é
## dada pelo próprio marco, no dia em que o jogador entra na fé. No 2D: "o texto
## é a voz do MUNDO, sem nome: ninguém mora nos marcos. Quem entra numa fé
## aprende o que ela pede do mesmo jeito que aprendeu o que ela é."
##
## A cadeia de missões pede um dono que saiba `narrar`, e o dono de sempre é um
## morador. Este é o dono quando não há morador: fala na caixa de fala longa,
## sem nome, como o marco falou ao jogador quando ele chegou perto. `dados` traz
## só o nome do lugar, que o diário escreve como "quem deu".

var dados: Dictionary = {}


func narrar(_audio: String, texto: String) -> void:
	if texto.strip_edges() != "":
		Dialogo.falar("", [texto])


## A voz espera a vez, como gente: com outra fala aberta, não começa a sua.
func pode_falar() -> bool:
	return not Dialogo.ocupado()


func fala_perto_de(_ponto: Vector3) -> bool:
	return false
