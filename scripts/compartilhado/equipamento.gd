extends Node
## O que o personagem veste.
##
## Cinco encaixes, e um item só entra no encaixe dele. Equipar TIRA da mochila
## e desequipar devolve — não existe item em dois lugares ao mesmo tempo, que é
## a fonte clássica de bug de inventário.
##
## O efeito de cada peça é um campo de `Progressao`, somado ao equipar e tirado
## ao desequipar, pelo mesmo caminho de `Efeitos` — só que sem prazo: enquanto
## estiver vestido, vale.

signal mudou

const ENCAIXES := ["cabeca", "corpo", "maos", "pes", "amuleto"]

const NOME_DO_ENCAIXE := {
	"cabeca": "Cabeça", "corpo": "Corpo", "maos": "Mãos",
	"pes": "Pés", "amuleto": "Amuleto",
}

## encaixe -> id do item, ou "" se vazio.
var vestido: Dictionary = {}


func _ready() -> void:
	for encaixe in ENCAIXES:
		vestido[encaixe] = ""


func no_encaixe(encaixe: String) -> String:
	return str(vestido.get(encaixe, ""))


func encaixe_de(id: String) -> String:
	return str(Catalogo.dados(id).get("encaixe", ""))


func e_equipamento(id: String) -> bool:
	return Catalogo.tipo(id) == "equipamento" and encaixe_de(id) != ""


## Veste o item que está no espaço dado da mochila. O que estava no encaixe
## volta para a mochila, no lugar que o novo deixou.
func equipar_do_espaco(indice: int) -> bool:
	if Inventario.vazio(indice):
		return false
	var id := str(Inventario.espacos[indice].get("id", ""))
	if not e_equipamento(id):
		return false

	var encaixe := encaixe_de(id)
	var antigo := no_encaixe(encaixe)

	Inventario.espacos[indice] = {}
	if antigo != "":
		_desaplicar(antigo)
		Inventario.espacos[indice] = {"id": antigo, "qtd": 1}
	vestido[encaixe] = id
	_aplicar(id)
	Inventario.mudou.emit()
	mudou.emit()
	return true


## Tira a peça do encaixe e devolve à mochila. Falha se não couber.
func desequipar(encaixe: String) -> bool:
	var id := no_encaixe(encaixe)
	if id == "":
		return false
	if not Inventario.adicionar(id, 1):
		return false
	_desaplicar(id)
	vestido[encaixe] = ""
	mudou.emit()
	return true


## Soma dos bônus vestidos num campo — para quem quiser exibir.
func bonus(campo: String) -> float:
	var total := 0.0
	for encaixe in vestido:
		var id := str(vestido[encaixe])
		if id != "":
			total += float(Catalogo.dados(id).get("efeito", {}).get(campo, 0.0))
	return total


## Só os campos que a `Progressao` tem. A DEFESA e o RESPIRO da luta não são
## dela: não mudam teto nenhum, e quem precisa deles lê na hora o que está
## vestido, por `bonus` (a criatura na mordida, a vida na pancada). Somá-los
## aqui pedia à Progressao um campo que ela não tem.
func _aplicar(id: String) -> void:
	for campo in Catalogo.dados(id).get("efeito", {}):
		if Progressao.get(campo) == null:
			continue
		Progressao.ajustar(campo, float(Progressao.get(campo)) + float(Catalogo.dados(id)["efeito"][campo]))


func _desaplicar(id: String) -> void:
	for campo in Catalogo.dados(id).get("efeito", {}):
		if Progressao.get(campo) == null:
			continue
		Progressao.ajustar(campo, float(Progressao.get(campo)) - float(Catalogo.dados(id)["efeito"][campo]))
