extends Node
## #9: posse de lotes 3D. Compra não remove moradores nem concede obras/colheitas.
signal comprado(id: String)
signal mudou
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")
const ARQUIVO := "res://data/terras_3d.json"
var posses: Dictionary = {"rocado": true}

func dados(id: String) -> Dictionary:
	return Jogo.dados(ARQUIVO).get("lotes", {}).get(id, {})

func meu(id: String) -> bool:
	return id == "rocado" or bool(posses.get(id, false))

func nome(id: String) -> String:
	return str(IdiomaMenu.campo(dados(id), "nome", ""))

func texto(chave: String) -> String:
	return str(IdiomaMenu.campo(Jogo.dados(ARQUIVO), chave, ""))

func preco(id: String) -> int:
	var bruto := int(dados(id).get("preco", 0))
	var abate := clampf(Talentos.bonus("favor_mais_barato"), 0.0, 0.75)
	return maxi(1, roundi(bruto * (1.0 - abate))) if bruto > 0 else 0

func faz_divisa(id: String) -> bool:
	for vizinho in dados(id).get("vizinhos", []):
		if meu(str(vizinho)):
			return true
	return false

func vizinho_que_falta(id: String) -> String:
	if faz_divisa(id):
		return ""
	var lista: Array = dados(id).get("vizinhos", [])
	return str(lista[0]) if not lista.is_empty() else ""

func pode_comprar(id: String) -> bool:
	return not dados(id).is_empty() and not meu(id) and preco(id) > 0 \
		and faz_divisa(id) and Jogo.dinheiro >= preco(id)

func comprar(id: String) -> bool:
	if not pode_comprar(id):
		return false
	Jogo.dinheiro -= preco(id)
	posses[id] = true
	comprado.emit(id)
	mudou.emit()
	return true

func oferta(dono: String) -> String:
	if not Missoes.cumpridas.has("chapada_volta"):
		return ""
	for id in Jogo.dados(ARQUIVO).get("lotes", {}):
		if str(dados(id).get("dono", "")) == dono and not meu(id):
			return str(id)
	return ""

## Contorno orientado pela mesma frente da âncora, não por célula do 2D.
func poligono(id: String, world: Node3D) -> PackedVector3Array:
	var lote := dados(id)
	var ancoras: Dictionary = world.get("ancoras")
	var ancora := str(lote.get("ancora", ""))
	if not ancoras.has(ancora):
		return PackedVector3Array()
	var centro: Vector3 = ancoras[ancora]
	var frente: Vector3 = ancoras.get(ancora + "Frente", Vector3.BACK)
	frente.y = 0
	frente = frente.normalized()
	var lado := Vector3(frente.z, 0, -frente.x)
	var tamanho: Array = lote.get("tamanho", [0, 0])
	var pontos := PackedVector3Array()
	for canto in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		pontos.append(centro + lado * canto.x * float(tamanho[0]) * 0.5 + frente * canto.y * float(tamanho[1]) * 0.5)
	return pontos
