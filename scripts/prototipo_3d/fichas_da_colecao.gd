extends RefCounted
## A PÁGINA DE UMA PEÇA DE COLEÇÃO — cordel, sinal ou bicho.
##
## Este texto morava dentro do `colecao_vale.gd`, que é a tela da tecla própria
## da coleção. Quando os cordéis e os colecionáveis foram para dentro do
## almanaque — "leve os cordéis para dentro do almanaque também" —, as mesmas
## páginas passaram a ser pedidas de dois lugares.
##
## Copiar seria ter duas versões da mesma página, e elas divergem: uma ganha o
## conserto e a outra não. Então o texto saiu das duas telas e virou isto, que
## nenhuma das duas possui.
##
## O que cada página diz, e por quê, é do jogo 2D e não foi reescrito:
##
##   CORDEL   o que é, de quem é, onde estava e quanto vale. Mostra a primeira
##            estrofe de chamariz, como lá.
##   SINAL    NÃO TEM NOME até o encontro acontecer. Pôr o nome antes seria o
##            jogo respondendo o enigma na mesma tela em que o propõe.
##   BICHO    o que se aprendeu brigando, onde mora e quantos já caíram — a
##            parede da Guilda, com a meta e o prêmio dela.


## A página da peça, ou o convite quando a vaga ainda está vazia.
static func pagina(colecao: String, id: String) -> String:
	match Colecao.tipo(colecao):
		"sinal":
			return _de_sinal(colecao, id)
		"bicho":
			return _de_bicho(colecao, id)
		_:
			return _de_cordel(colecao, id)


## O nome que a lista mostra: o título quando achado, e a vaga em branco quando
## não. Coleção que só mostra o que se tem é inventário — é o buraco na estante
## que faz procurar (ver o 2D).
static func nome_na_lista(colecao: String, id: String) -> String:
	return str(Colecao.dados(colecao, id).get("titulo", id)) if Colecao.tem(colecao, id) else "— — —"


static func _de_cordel(colecao: String, id: String) -> String:
	if id == "" or not Colecao.tem(colecao, id):
		return "Esta vaga está vazia.\n\nHá folhetos embaixo de banco de capela, dentro de lata no píer, presos em pedra na beira do rio. Quem anda olhando acha."
	var dado := Colecao.dados(colecao, id)
	var texto := "%s\n%s\n\n" % [dado.get("titulo", id), dado.get("autor", "")]
	var versos: Array = dado.get("versos", [])
	if not versos.is_empty():
		texto += "   %s…\n\n" % Jogo.texto(str(versos[0]))
	texto += "Achado %s.\nVale %d réis." % [str(dado.get("onde", "por aí")), int(dado.get("valor", 0))]
	return texto


static func _de_bicho(colecao: String, id: String) -> String:
	if id == "" or not Colecao.tem(colecao, id):
		return "Esta vaga está vazia.\n\nBicho se conhece brigando com ele. Há mais na mata do que nesta página."
	var dado := Colecao.dados(colecao, id)
	var texto := "%s\n\n" % str(dado.get("titulo", id))
	for linha in (dado.get("ficha", []) as Array):
		texto += "%s\n" % Jogo.texto(str(linha))
	texto += "\nMora %s.\nJá caíram: %d.\n" % [str(dado.get("onde", "na mata")), Luta.abatidos(id)]
	var meta: Dictionary = dado.get("meta", {})
	if not meta.is_empty():
		if Missoes.cumprida(str(meta.get("missao", ""))):
			texto += "\n%s\n" % Jogo.texto(str(meta.get("premio", "")))
		else:
			texto += "\n%s (%d de %d)\n" % [Jogo.texto(str(meta.get("promessa", ""))),
				mini(Luta.abatidos(id), int(meta.get("conta", 1))), int(meta.get("conta", 1))]
	return texto


static func _de_sinal(colecao: String, id: String) -> String:
	if id == "" or not Colecao.tem(colecao, id):
		return "Esta vaga está vazia.\n\nSinal não se procura: se topa. Água parada, mata que cala de repente, bicho que some do caminho. Quando acontecer, olhe o chão antes de ir embora."
	var dado := Colecao.dados(colecao, id)
	var texto := "%s\n\n" % str(dado.get("titulo", id))
	for linha in (dado.get("sinal", []) as Array):
		texto += "%s\n" % Jogo.texto(str(linha))
	texto += "\nVisto %s, %s.\n" % [str(dado.get("onde", "por aí")), str(dado.get("quando", "num dia qualquer"))]
	if Colecao.nomeia(colecao, id):
		texto += "\n"
		for linha in (dado.get("revelado", []) as Array):
			texto += "%s\n" % Jogo.texto(str(linha))
	else:
		texto += "\nVocê não sabe de quem era. Ainda."
	return texto
