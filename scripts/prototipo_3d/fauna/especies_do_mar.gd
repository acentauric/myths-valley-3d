extends RefCounted
## Os números dos bichos d'água do vale, por espécie: só medidas, velocidades e cor,
## nenhum texto que o jogador leia (o nome do peixe pescado mora no catálogo de itens).
## Quem lê é o `Cardume` (cardume.gd); quem decide onde cada cardume mora é o
## `FaunaVale` (fauna_vale.gd).
##
## "chaves": as peças do `CatalogoAssets`, na ordem de preferência. Se a primeira
##     ainda não tem GLB, vale a seguinte, tingida por "tinta" (a cavala usa o corpo
##     da sororoca até a dela chegar). Sem nenhuma, ou no estilo procedural, o corpo
##     é montado aqui mesmo com "cor" e "corpo".
## "tamanho": comprimento do peixe (envergadura da raia), em unidades — 1 u ≈ 1 m.
##     Igual à "largura" do catálogo da chave principal; com a chave de reserva, o
##     cardume reescala para este tamanho.
## "velocidade"/"fuga": nado de cruzeiro e disparada (u/s).
## "onda": amplitude do rabear (fração do comprimento); "batida": ritmo (rad/s).
## "corpo": altura do corpo sobre o comprimento, no corpo procedural.
## "variacao": quanto o tamanho varia de um peixe para outro (fração).

const ESPECIES := {
	# Mar raso: a bola das canoas e as tainhas que rodam o casco.
	"sardinha": {"chaves": ["sardinha", "peixe"], "tamanho": 0.2, "velocidade": 1.3, "fuga": 3.4,
		"onda": 0.09, "batida": 17.0, "forma": "peixe", "cor": Color("b9c8d0"), "tinta": Color("dfe8ee"), "corpo": 0.22, "variacao": 0.12},
	"tainha": {"chaves": ["tainha", "peixe"], "tamanho": 0.5, "velocidade": 0.9, "fuga": 2.6,
		"onda": 0.08, "batida": 10.0, "forma": "peixe", "cor": Color("9fb2b8"), "tinta": Color.WHITE, "corpo": 0.24, "variacao": 0.15},
	# O xaréu caça em dupla a bola de sardinha.
	"xareu": {"chaves": ["xareu", "robalo"], "tamanho": 0.7, "velocidade": 1.4, "fuga": 3.6,
		"onda": 0.07, "batida": 9.0, "forma": "peixe", "cor": Color("8b9ca3"), "tinta": Color("c9d3d6"), "corpo": 0.36, "variacao": 0.1},
	# Mar de fora: as presas do tubarão.
	"cavala": {"chaves": ["cavala", "sororoca"], "tamanho": 1.0, "velocidade": 1.5, "fuga": 3.8,
		"onda": 0.06, "batida": 8.0, "forma": "peixe", "cor": Color("5f7c8c"), "tinta": Color("9fb4c4"), "corpo": 0.2, "variacao": 0.1},
	"sororoca": {"chaves": ["sororoca", "cavala"], "tamanho": 0.75, "velocidade": 1.4, "fuga": 3.6,
		"onda": 0.07, "batida": 9.0, "forma": "peixe", "cor": Color("7d93a0"), "tinta": Color("d8dccf"), "corpo": 0.2, "variacao": 0.1},
	# Pedras: o miúdo listrado em volta da rocha e os maiores que pastam nela.
	"sargentinho": {"chaves": ["sargentinho", "budiao"], "tamanho": 0.2, "velocidade": 0.6, "fuga": 2.4,
		"onda": 0.1, "batida": 13.0, "forma": "peixe", "cor": Color("d8c552"), "tinta": Color("f2e27a"), "corpo": 0.4, "variacao": 0.12},
	"budiao": {"chaves": ["budiao"], "tamanho": 0.45, "velocidade": 0.5, "fuga": 2.2,
		"onda": 0.08, "batida": 8.0, "forma": "peixe", "cor": Color("4f9a7c"), "tinta": Color.WHITE, "corpo": 0.38, "variacao": 0.12},
	"baiacu": {"chaves": ["baiacu"], "tamanho": 0.25, "velocidade": 0.3, "fuga": 1.4,
		"onda": 0.06, "batida": 7.0, "forma": "peixe", "cor": Color("a39a6a"), "tinta": Color.WHITE, "corpo": 0.5, "variacao": 0.1},
	"garoupa": {"chaves": ["garoupa"], "tamanho": 0.9, "velocidade": 0.3, "fuga": 1.8,
		"onda": 0.05, "batida": 5.0, "forma": "peixe", "cor": Color("6b5a44"), "tinta": Color.WHITE, "corpo": 0.36, "variacao": 0.08},
	# Água doce: o miúdo do poço, o acará e a traíra parada na margem.
	"piaba": {"chaves": ["piaba", "sardinha"], "tamanho": 0.14, "velocidade": 0.5, "fuga": 2.6,
		"onda": 0.1, "batida": 16.0, "forma": "peixe", "cor": Color("c8c2a0"), "tinta": Color("e6dcb4"), "corpo": 0.24, "variacao": 0.15},
	"acara": {"chaves": ["acara", "budiao"], "tamanho": 0.22, "velocidade": 0.35, "fuga": 1.8,
		"onda": 0.08, "batida": 10.0, "forma": "peixe", "cor": Color("7c8a5a"), "tinta": Color("b9b48a"), "corpo": 0.45, "variacao": 0.12},
	"traira": {"chaves": ["traira", "robalo"], "tamanho": 0.45, "velocidade": 0.25, "fuga": 2.8,
		"onda": 0.06, "batida": 6.0, "forma": "peixe", "cor": Color("4a4a32"), "tinta": Color("8a8058"), "corpo": 0.24, "variacao": 0.05},
	# Raias: a pintada voa em bando a meia água; a manteiga deita na areia do raso.
	"raia_pintada": {"chaves": ["raia_pintada"], "tamanho": 1.7, "velocidade": 0.8, "fuga": 2.6,
		"onda": 0.12, "batida": 2.6, "forma": "raia", "cor": Color("2f3540"), "tinta": Color.WHITE, "corpo": 0.08, "variacao": 0.1},
	"raia": {"chaves": ["raia", "raia_pintada"], "tamanho": 1.1, "velocidade": 0.5, "fuga": 2.4,
		"onda": 0.1, "batida": 2.2, "forma": "raia", "cor": Color("8a7656"), "tinta": Color("c8a878"), "corpo": 0.08, "variacao": 0.12},
}


static func especie(nome: String) -> Dictionary:
	return ESPECIES.get(nome, ESPECIES["tainha"])
