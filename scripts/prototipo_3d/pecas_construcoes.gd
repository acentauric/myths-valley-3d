class_name PecasConstrucoes
extends RefCounted
## Objetos que acompanham cada construção (árvores do quintal, adereços, itens e luzes).
## Fonte única dos valores padrão: o jogo usa quando a casa ainda não tem peças autorais,
## e o editor usa para criar os nós editáveis na composicao_vale.tscn.
## desloc/giro são relativos à casa (frente = +Z local).

const TIPOS := ["arvore", "adereco", "item", "candeeiro", "lampiao", "luz_janela"]

## Modelo usado para cada tipo de luz (o tipo define a luz; a chave, o objeto).
const CHAVE_LUZ := {"candeeiro": "candeeiro", "lampiao": "lampiao_poste"}

const POR_CASA := {
	"Casa de taipa": [
		{"id": "Bananeira 1", "tipo": "arvore", "chave": "bananeira", "desloc": Vector3(-3.2, 0, -4.6), "giro": -4.16, "tamanho": 0.9},
		{"id": "Bananeira 2", "tipo": "arvore", "chave": "bananeira", "desloc": Vector3(-1.6, 0, -5.9), "giro": -2.08, "tamanho": 0.9},
		{"id": "Bananeira 3", "tipo": "arvore", "chave": "bananeira", "desloc": Vector3(0.4, 0, -4.9), "giro": 0.52, "tamanho": 0.9},
		{"id": "Bananeira 4", "tipo": "arvore", "chave": "bananeira", "desloc": Vector3(-4.6, 0, -3.0), "giro": -5.98, "tamanho": 0.9},
		{"id": "Varal", "tipo": "adereco", "chave": "varal", "desloc": Vector3(-4.9, 0, 1.4), "giro": 0.35},
		{"id": "Lenha", "tipo": "adereco", "chave": "lenha", "desloc": Vector3(3.6, 0, -0.4)},
		{"id": "Pote", "tipo": "adereco", "chave": "pote", "desloc": Vector3(2.4, 0, 2.9)},
		{"id": "Machado", "tipo": "item", "chave": "machado", "desloc": Vector3(3.9, 0.55, 0.6), "giro": 0.9, "no_chao": false},
		{"id": "Cesto", "tipo": "item", "chave": "cesto", "desloc": Vector3(1.6, 0, 3.4), "giro": 0.2},
		{"id": "Moringa", "tipo": "item", "chave": "moringa", "desloc": Vector3(-1.0, 0, 3.1)},
		{"id": "Candeeiro", "tipo": "candeeiro", "chave": "candeeiro", "desloc": Vector3(0.92, 2.45, 2.35), "no_chao": false},
		{"id": "Luz da janela", "tipo": "luz_janela", "chave": "", "desloc": Vector3(-1.35, 1.9, 2.2), "no_chao": false},
	],
	"Venda do Bar": [
		{"id": "Dendezeiro 1", "tipo": "arvore", "chave": "dendezeiro", "desloc": Vector3(-14.0, 0, 2.5), "giro": 5.5, "tamanho": 0.95},
		{"id": "Dendezeiro 2", "tipo": "arvore", "chave": "dendezeiro", "desloc": Vector3(-17.5, 0, -1.0), "giro": 2.0, "tamanho": 0.95},
		{"id": "Farinha", "tipo": "item", "chave": "farinha", "desloc": Vector3(-2.0, 0, 3.5)},
		{"id": "Candeeiro", "tipo": "candeeiro", "chave": "candeeiro", "desloc": Vector3(0.0, 2.5, 3.15), "no_chao": false},
	],
	"Restaurante": [
		{"id": "Cacho de banana", "tipo": "item", "chave": "cacho_banana", "desloc": Vector3(-2.0, 0, 3.6)},
		{"id": "Candeeiro", "tipo": "candeeiro", "chave": "candeeiro", "desloc": Vector3(0.0, 2.5, 3.15), "no_chao": false},
	],
	"Igreja": [
		{"id": "Ipê roxo", "tipo": "arvore", "chave": "ipe_roxo", "desloc": Vector3(-8.5, 0, 9.0)},
		{"id": "Ipê amarelo", "tipo": "arvore", "chave": "ipe_amarelo", "desloc": Vector3(8.5, 0, 9.5), "giro": 1.1},
		{"id": "Cruzeiro", "tipo": "adereco", "chave": "cruzeiro", "desloc": Vector3(0, 0, 9.0)},
		{"id": "Lampião", "tipo": "lampiao", "chave": "lampiao_poste", "desloc": Vector3(-6.0, 0, 8.0)},
		{"id": "Luz da janela", "tipo": "luz_janela", "chave": "", "desloc": Vector3(0, 3.6, 4.6), "no_chao": false},
	],
}

## Quintal de toda casa ("Casa ..."): pitangueira atrás, como nos quintais baianos.
const QUINTAL := [
	{"id": "Pitangueira", "tipo": "arvore", "chave": "pitangueira", "desloc": Vector3(3.5, 0, -6.5)},
]


static func padrao_da_casa(nome: String) -> Array:
	var lista: Array = []
	for entrada in POR_CASA.get(nome, []):
		lista.append(normalizar(entrada))
	if nome.begins_with("Casa"):
		for entrada in QUINTAL:
			var item := normalizar(entrada)
			# Giro estável por casa, como antes (variação entre quintais).
			item["giro"] = float(nome.length())
			lista.append(item)
	return lista


static func normalizar(entrada: Dictionary) -> Dictionary:
	return {
		"id": String(entrada.get("id", "")), "tipo": String(entrada.get("tipo", "adereco")),
		"chave": String(entrada.get("chave", "")), "desloc": entrada.get("desloc", Vector3.ZERO),
		"giro": float(entrada.get("giro", 0.0)), "tamanho": float(entrada.get("tamanho", 1.0)),
		"no_chao": bool(entrada.get("no_chao", true)), "visivel": true,
	}
