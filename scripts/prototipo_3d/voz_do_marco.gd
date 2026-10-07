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
##
## NA VEZ DELA (`fila_de_falas.gd`): a caixa abre quando a fala de quem estiver
## no balão acabar, e a vez só passa adiante quando a caixa fecha.

const FilaDeFalas = preload("res://scripts/prototipo_3d/fila_de_falas.gd")

var dados: Dictionary = {}


func narrar(_audio: String, texto: String, pedido: Dictionary = {}) -> void:
	if texto.strip_edges() == "":
		_avisar(pedido, "ao_terminar")
		return
	var fila := FilaDeFalas.da(self)
	if fila == null:
		_avisar(pedido, "ao_comecar")
		_dizer(texto, 0, null, pedido)
		return
	var fala := {
		"falante": self, "texto": texto,
		"classe": int(pedido.get("classe", FilaDeFalas.Classe.MISSAO)),
		"origem": str(pedido.get("origem", "")),
		"modal": true, "caixa": true,
	}
	for gancho in ["ao_comecar", "ao_terminar"]:
		if pedido.get(gancho) is Callable:
			fala[gancho] = pedido[gancho]
	fala["comecar"] = func(dada: Dictionary) -> void: _dizer(texto, int(dada.get("id", 0)), fila, {})
	fila.pedir(fala)


## Abre a caixa e, quando ela fecha, devolve a vez à fila.
func _dizer(texto: String, id: int, fila: Node, pedido: Dictionary) -> void:
	var dialogo := get_node_or_null("/root/Dialogo")
	if dialogo != null:
		await dialogo.falar("", [texto])
	if fila != null and is_instance_valid(fila):
		fila.soltar(id)
	_avisar(pedido, "ao_terminar")


func _avisar(pedido: Dictionary, gancho: String) -> void:
	var chamada = pedido.get(gancho)
	if chamada is Callable and (chamada as Callable).is_valid():
		(chamada as Callable).call()


## A voz espera a vez, como gente: com outra fala no ar ou esperando, não começa a sua.
func pode_falar() -> bool:
	var fila := FilaDeFalas.da(self)
	if fila != null:
		return fila.livre()
	var dialogo := get_node_or_null("/root/Dialogo")
	return dialogo == null or not bool(dialogo.call("ocupado"))


func fala_perto_de(_ponto: Vector3) -> bool:
	return false
