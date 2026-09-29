extends Node
## Efeitos temporários: bênção de cruzeiro, comida, e o que vier.
##
## Um efeito mexe num campo de `Progressao` por um tanto de DIAS e some sozinho
## quando o prazo vence. Quem concede não precisa saber desfazer — some por
## conta, na virada do dia, e o campo volta ao que era.
##
## Existe separado de Progressao porque são coisas de natureza diferente:
## Progressao é o que o personagem VIROU e não volta atrás; efeito é o que ele
## está sentindo hoje. Misturar os dois faria o talento e o prato de comida
## disputarem o mesmo número sem ninguém saber quem somou o quê.

signal ganhou(id: String)
signal perdeu(id: String)
signal mudou

## Quantos efeitos o corpo carrega ao mesmo tempo.
##
## Existe teto porque sem ele o jogo vira acúmulo: reza, come, bebe, faz
## oferenda e sai com seis bônus somados que nenhum deles foi desenhado para
## conviver. Três obriga a escolher — e escolher é o que torna cada um deles
## uma decisão em vez de um item a mais.
##
## Estourando o teto, sai o que vence primeiro: o mais antigo é o que já deu o
## que tinha para dar.
const LIMITE := 3

## O que cada natureza de efeito é, para o inventário dizer de onde veio. São
## coisas diferentes no mundo, ainda que a conta seja a mesma.
const NATUREZAS := {
	"bencao": "Bênção",
	"comida": "Comida",
	"pocao": "Poção",
	"pacto": "Pacto",
	"oferenda": "Oferenda",
	"reza": "Reza",
}

## id -> {"nome", "campo", "valor", "ate_o_dia", "natureza"}
var ativos: Dictionary = {}


func _ready() -> void:
	Relogio.dia_comecou.connect(_ao_comecar_dia)


func cabem() -> int:
	return LIMITE


func quantos() -> int:
	return ativos.size()


## Concede (ou renova) um efeito. `dias` conta a partir de hoje.
func conceder(id: String, nome: String, campo: String, valor: float, dias: int,
		natureza: String = "bencao") -> void:
	retirar(id)
	_abrir_vaga()
	ativos[id] = {
		"nome": nome, "campo": campo, "valor": valor, "natureza": natureza,
		"ate_o_dia": Relogio.dia_absoluto() + maxi(1, dias),
	}
	_somar(campo, valor)
	ganhou.emit(id)
	mudou.emit()


## Tira o mais velho, se o corpo já estiver cheio.
func _abrir_vaga() -> void:
	while ativos.size() >= LIMITE:
		var mais_velho := ""
		var vence_antes := INF
		for id in ativos:
			var quando := float(ativos[id]["ate_o_dia"])
			if quando < vence_antes:
				vence_antes = quando
				mais_velho = str(id)
		if mais_velho == "":
			return
		retirar(mais_velho)


func retirar(id: String) -> void:
	if not ativos.has(id):
		return
	var efeito: Dictionary = ativos[id]
	_somar(str(efeito["campo"]), -float(efeito["valor"]))
	ativos.erase(id)
	perdeu.emit(id)
	mudou.emit()


func tem(id: String) -> bool:
	return ativos.has(id)


func nome(id: String) -> String:
	return str(ativos.get(id, {}).get("nome", ""))


func dias_restantes(id: String) -> int:
	if not ativos.has(id):
		return 0
	return maxi(0, int(ativos[id]["ate_o_dia"]) - Relogio.dia_absoluto())


## Lista dos efeitos em curso, para o HUD e o inventário mostrarem. Vem com a
## natureza e com o quanto cada um mexe, que é o que o jogador quer conferir.
func em_curso() -> Array:
	var lista: Array = []
	for id in ativos:
		lista.append({
			"id": id,
			"nome": ativos[id]["nome"],
			"dias": dias_restantes(str(id)),
			"campo": str(ativos[id]["campo"]),
			"valor": float(ativos[id]["valor"]),
			"natureza": str(NATUREZAS.get(ativos[id].get("natureza", "bencao"), "Efeito")),
		})
	lista.sort_custom(func(a, b): return int(a["dias"]) < int(b["dias"]))
	return lista


## Vence de madrugada, junto com o dia.
func _ao_comecar_dia(_dia: int, _estacao: int, _ano: int) -> void:
	for id in ativos.keys():
		if Relogio.dia_absoluto() >= int(ativos[id]["ate_o_dia"]):
			retirar(str(id))


func _somar(campo: String, valor: float) -> void:
	if campo == "":
		return
	Progressao.ajustar(campo, float(Progressao.get(campo)) + valor)
