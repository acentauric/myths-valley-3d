extends RefCounted
## O SAVE ANTIGO DO DIA DE ROÇADO DO COSME (#160, #9).
##
## Até a Build 11 o dia de roçado do segundo tutorial tinha conta própria aqui: um contador de dias de
## prática por morador e um "ofício aprendido" que somava um quarto ao pagamento. Com a aba Trabalho
## (#9) o dia de roçado é a primeira designação do mesmo sistema de todos: o Cosme é posto na roça pelo
## `Terrenos`, rende pela conta do `Povoado` (perícia, amizade, obras do arraial, Palavra de patrão) e o
## talento Mestre de ofício conta dois dias por serviço lá mesmo. Esta classe não tem mais regra.
##
## Sobrou a ponte do save: a vaga antiga guardava os dias em `servico` (junto do ninho do curral), e
## quem carrega uma vaga assim não perde o que o Cosme já aprendeu: os dias viram dias de roçado na
## perícia do `Povoado`.


## Os dias de prática da vaga antiga viram dias de serviço de roçado. Não rebaixa quem já tem mais.
static func migrar(estado: Dictionary, povoado: Node) -> void:
	for morador in estado:
		var dias := int(estado[morador])
		if dias <= 0:
			continue
		var dele: Dictionary = povoado.pericia.get(str(morador), {})
		dele["roca"] = maxi(int(dele.get("roca", 0)), dias)
		povoado.pericia[str(morador)] = dele
