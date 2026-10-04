extends Node
## A cozinha: o fogo do fogão de barro transformando o que se colhe no que se come.
##
## É o outro lado da fome. `Energia` diz o quanto o corpo aguenta; a comida é
## como se devolve isso sem esperar a noite — e, diferente da cama, ela também
## deixa o dia seguinte mais barato ou mais caro, conforme o prato.
##
## Existe separado da `Oficina` de propósito, pelo mesmo motivo que o canteiro
## é separado dela: serrar tábua e torrar farinha são trabalhos diferentes,
## acontecem em lugares diferentes e evoluem por caminhos diferentes. A oficina
## fica no terreiro; a cozinha é o fogão de dentro de casa.
##
## Os pratos são do Recôncavo de 1887 e todos saem do que o jogador planta,
## pesca ou corta: mandioca, milho, cana e peixe. Nada de ingrediente que não
## exista no mundo.
##
## E NENHUM DELES NASCE NA CABEÇA DO JOGADOR. Cada prato tem a sua chave `abre`,
## que diz por onde ele se aprende — ver `Receitas`, que é quem guarda o que já
## foi aprendido e quem filtra `receitas()`. O fogão do primeiro dia está VAZIO,
## e é de propósito: a primeira coisa que entra nele é a farinha, quando o Pedro
## manda torrar farinha.

signal cozinhou(id: String, quantos: int)
## Alguém comeu alguma coisa. É o que a primeira refeição do tutorial espera:
## antes ela esperava o PRATO SUMIR da mochila, e quem cozinhava três pirões e
## comia um ficava com a missão aberta até engolir os outros dois.
signal comeu(id: String)

const RECEITAS := {
	## Duas mandiocas, que é exatamente o que um pé dá: a primeira farinha da
	## partida sai da primeira colheita, sem o jogador ter que plantar de novo.
	## A PRIMEIRA RECEITA DO JOGO, e a que o passo do fogão ensina.
	##
	## "Isso vai impactar a missão de aprender a cozinhar": é este o impacto. O
	## passo `cozinhar` manda torrar duas farinhas, e é ele que ensina a torrar
	## — por isso a porta abre quando o passo ABRE, e não quando fecha. Ver a
	## nota sobre isso em `Receitas`.
	"farinha": {
		"nome": "Torrar farinha",
		"resumo": "Mandioca ralada e prensada no forno de barro. É a base de tudo que se come aqui.",
		"custo": {"mandioca": 2, "lenha": 1},
		"rende": 2,
		"folego": 6.0,
		"abre": {"missao": "cozinhar"},
	},
	## O prato MAIS BARATO do fogão, e ele existe por causa do começo do jogo:
	## uma farinha e uma lenha, sem depender de peixe, de cana nem de milho. A
	## primeira colheita de mandioca já paga dois beijus, e com eles o jogador
	## tem o que comer no mesmo dia em que plantou.
	"beiju": {
		"nome": "Beiju na chapa",
		"resumo": "Massa de mandioca aberta na chapa quente e dobrada. Não sustenta o dia, mas tira do aperto.",
		"custo": {"farinha": 1, "lenha": 1},
		"rende": 2,
		"folego": 3.0,
		## COMIDA DE POBRE SE APRENDE COM QUEM COZINHA PARA OS OUTROS. A Dona
		## Filó cozinha o dia inteiro na porta do filho; basta ser conhecido de
		## vista para ela dizer como se abre a massa na chapa. O balcão também
		## vende, barato, porque beiju não é segredo de ninguém.
		"abre": {"morador": "filo", "grau": 1, "compra": 120},
	},
	"garapa": {
		"nome": "Garapa de cana",
		"resumo": "Caldo de cana moído na hora. Não sustenta, mas levanta na mesma hora.",
		"custo": {"cana": 2},
		"rende": 1,
		"folego": 2.0,
		## A CANA É DELA. A missão da Candinha é o jogador levar a cana que
		## plantou a quem sabe o que fazer com ela — e quem entrega seis canas na
		## mão da moageira aprende a moer. Ou só convive com ela, e ela conta.
		"abre": {"missao": "candinha_cana", "morador": "candinha", "grau": 1},
	},
	"peixe_assado": {
		"nome": "Peixe na brasa",
		"resumo": "Peixe aberto no sal e virado na brasa. Comida de quem chegou do mar com fome.",
		"custo": {"peixe": 1, "lenha": 1},
		"rende": 1,
		"folego": 4.0,
		## O PASSO DA PESCA, que é onde o jogador tira o primeiro peixe da água —
		## e o Tonho, que tira peixe todo dia.
		"abre": {"missao": "pesca", "morador": "tonho", "grau": 1},
	},
	## A CAÇA NA BRASA, irmã do peixe assado: mesmo gesto, mesma lenha, e
	## sustenta mais — carne de caça é o que se come depois de um dia de mata,
	## e o dia de mata custa fôlego e custa vida. Ver Criatura.ESPECIES.
	"carne_assada": {
		"nome": "Caça na brasa",
		"resumo": "Carne de caititu no sal grosso, virada na brasa. Come-se depois de um dia de mata.",
		"custo": {"carne_de_caca": 1, "lenha": 1},
		"rende": 1,
		"folego": 7.0,
		## DUAS PORTAS, e a segunda existe para tapar um beco. A lição do bote
		## ensina, mas o jogador pode derrubar um caititu com o facão antes de
		## ninguém lhe falar de caça — e aí ele tem carne na mochila e não sabe o
		## que fazer com ela, que é o pior jeito de descobrir um sistema novo. A
		## carne na mão ensina sozinha.
		"abre": {"missao": "armas_bote", "achado": "carne_de_caca"},
	},
	## O CHÁ DE FOLHA: a única coisa do fogão que fecha ferida.
	##
	## Até a luta ensinada, a vida só voltava dormindo — e uma briga de manhã
	## era o dia inteiro perdido, ou uma tarde andando machucado. As três
	## referências respondem de jeitos diferentes: no Stardew toda comida cura
	## também, perto de metade do que dá de energia; no Graveyard Keeper a
	## comida NÃO cura, só a poção, o mel e o sono — e os jogadores de lá
	## queimam a comida toda na masmorra achando que se curam, que é a
	## reclamação mais repetida do jogo.
	##
	## Ficou a regra do Graveyard Keeper e o remédio para a reclamação dele: a
	## comida continua sendo fôlego, e a vida tem UMA coisa que a devolve, dita
	## em letra na mochila ("+12 de vida"). É um chá porque é o que o arraial
	## faria: folha da serra fervida, o remédio de benzedeira que a Dona Zefa
	## ensinou a todo mundo. Duas ervas, uma lenha — a erva é da serra, oito
	## por dia, e disputa com o favor da Zefa e com a mesa do terreiro.
	"cha_de_folha": {
		"nome": "Ferver chá de folha",
		"resumo": "Erva da serra fervida no fogo baixo. Não enche a barriga: fecha a ferida.",
		"custo": {"erva_da_serra": 2, "lenha": 1},
		"rende": 1,
		"folego": 3.0,
		## "O REMÉDIO DE BENZEDEIRA QUE A DONA ZEFA ENSINOU A TODO MUNDO", diz o
		## texto acima — e agora ela ensina de fato. A missão das ervas é a
		## subida à serra que ela manda fazer; quem não passou por lá aprende
		## sendo gente boa com ela. Não se compra: é remédio, não mercadoria.
		"abre": {"missao": "zefa_ervas", "morador": "zefa", "grau": 2},
	},
	"pirao": {
		"nome": "Pirão de peixe",
		"resumo": "Caldo do peixe engrossado na farinha. Enche mais que os dois separados.",
		"custo": {"farinha": 2, "peixe": 1, "lenha": 1},
		"rende": 1,
		"folego": 8.0,
		## O SEGUNDO PASSO DO FOGÃO, que manda fazer um pirão — e a Dona Filó,
		## cujo pedido é justamente mandar um pirão ao filho no pontal.
		"abre": {"missao": "pirao", "morador": "filo", "grau": 2},
	},
	"mungunza": {
		"nome": "Mungunzá",
		"resumo": "Milho branco cozido devagar com a doçura da cana. Comida de festa e de dia duro.",
		"custo": {"milho": 3, "cana": 1, "lenha": 1},
		"rende": 1,
		"folego": 10.0,
		## COMIDA DE FESTA, e quem a ensina é um folheto de festa: "O Boi do
		## Recôncavo". É a porta do ACHADO no seu melhor uso — o jogador procura
		## cordel pelo troco, lê os versos por curiosidade, e sai de lá com um
		## prato. Ninguém lhe disse que aquele folheto valia isso.
		"abre": {"achado": "boi_do_reconcavo", "compra": 200},
	},
}


## O QUE O FOGÃO LISTA: só o que o jogador sabe fazer. Ver `Receitas`.
##
## O filtro mora aqui, e não na tela, porque a tela não é a única que pergunta —
## e porque uma segunda tela amanhã não pode ter que lembrar de filtrar. `dados`
## e `cozinhar` continuam respondendo sobre qualquer prato: quem já tem um pirão
## na mochila precisa saber o fôlego dele mesmo que a receita não esteja sabida.
func receitas() -> Array:
	var lista: Array = []
	for id in RECEITAS:
		if Receitas.sabe(str(id)):
			lista.append(id)
	return lista


func dados(id: String) -> Dictionary:
	return RECEITAS.get(id, {})


## "" quando dá para cozinhar; senão, o que falta.
func impedimento(id: String) -> String:
	var dado := dados(id)
	if dado.is_empty():
		return "Receita desconhecida."
	# NÃO SABER É UM IMPEDIMENTO como qualquer outro, e fica escrito aqui para
	# não depender da tela ter filtrado: `receitas()` já esconde o que não se
	# sabe, e esta linha é o que garante que esconder não seja a única trava.
	if not Receitas.sabe(id):
		return "Você ainda não sabe fazer isso."
	for item in dado.get("custo", {}):
		var pedido: int = int(dado["custo"][item])
		if Inventario.quantidade(item) < pedido:
			return "Falta %s: %d de %d." % [Catalogo.nome(item), Inventario.quantidade(item), pedido]
	if not Energia.aguenta("arar", _dureza(id)):
		return "Sem %s nem pra mexer a panela." % Energia.nome_recurso()
	return ""


func pode(id: String) -> bool:
	return impedimento(id) == ""


func cozinhar(id: String) -> bool:
	if not pode(id):
		return false
	var dado := dados(id)
	for item in dado.get("custo", {}):
		Inventario.consumir(item, int(dado["custo"][item]))
	Energia.gastar("arar", _dureza(id))
	var quantos: int = int(dado.get("rende", 1))
	Inventario.adicionar(id, quantos)
	Talentos.ganhar("plantar")
	cozinhou.emit(id, quantos)
	return true


func custo_em_texto(id: String) -> String:
	var partes: Array = []
	for item in dados(id).get("custo", {}):
		partes.append("%d %s" % [int(dados(id)["custo"][item]), Catalogo.nome(item).to_lower()])
	return ", ".join(partes)


## O fôlego da receita virado em "dureza" da ação de arar, que é a conta que
## `Energia` sabe fazer.
## "Mão de cozinheiro" corta pela metade o que a panela cansa.
func _dureza(id: String) -> float:
	var alivio := 1.0 + Talentos.bonus("folego_da_panela")
	return float(dados(id).get("folego", 4.0)) * maxf(0.2, alivio) / Energia.CUSTOS["arar"]


# --- comer --------------------------------------------------------------------
#
# Comer mora aqui, e não na tela da mochila, porque agora existem DOIS jeitos de
# comer: pela mochila (I, depois F) e com a comida na mão, apertando E no mundo.
# Duas telas chamando a mesma função é o que garante que as duas devolvam o
# mesmo fôlego e apliquem o mesmo efeito.

## Quanto de fôlego se perde por comer isto agora — o que passa do teto.
func desperdicio(id: String) -> float:
	var ganho := float(Catalogo.dados(id).get("folego", 0.0))
	return maxf(0.0, Energia.atual + ganho - Energia.maximo())


## O que comer isto agora jogaria fora, em palavras — "" quando não joga nada.
## Uma frase só, dita igual pela mochila e pelo E com a comida na mão.
##
## Duas perdas: o fôlego que passa do teto, e a vida que um remédio viria
## devolver a quem não tem ferida. O chá bebido de corpo inteiro é o chá
## perdido, e erva da serra custa uma subida.
func recado_de_desperdicio(id: String) -> String:
	var vida := float(Catalogo.dados(id).get("vida", 0.0))
	# Com peçonha no corpo, o chá nunca é desperdício: é para isso que ele
	# existe, esteja a vida onde estiver.
	if bool(Catalogo.dados(id).get("corta_peconha", false)) and Vida.envenenado_agora():
		return ""
	if vida > 0.0 and Vida.atual >= Vida.maximo():
		return "%s agora não fecha ferida nenhuma: a vida está cheia (%d de %d)." % [
			Catalogo.nome(id), int(Vida.atual), int(Vida.maximo())]
	var perde := desperdicio(id)
	if perde >= 1.0 and vida <= 0.0:
		return "%s agora passa do seu limite: %d de %s vão no lixo (você está em %d de %d)." % [
			Catalogo.nome(id), int(perde), Energia.nome_recurso(), int(Energia.atual), int(Energia.maximo())]
	return ""


func e_comida(id: String) -> bool:
	return id != "" and Catalogo.tipo(id) == "comida"


## SERVE um prato que não passou pela mochila — o prato do dia da casa de
## pasto. Repõe o fôlego dado e avisa que se comeu, pelo mesmo sinal de
## `comer`: para quem escuta (a primeira refeição do tutorial), comer fora é
## comer. Não aplica talento de panela nem efeito de campo: o prato não é seu.
func servir(id: String, folego: float) -> void:
	Energia.repor(folego)
	Audio.efeito("menu_confirma")
	comeu.emit(id)


## Come de fato. Quem chama já perguntou ao jogador se era isso mesmo.
func comer(id: String) -> bool:
	if not e_comida(id) or not Inventario.consumir(id, 1):
		return false
	var dados_do_item := Catalogo.dados(id)
	# "Tempero da casa" faz o PRATO alimentar mais; "Fogo manso" faz o efeito
	# durar mais um dia.
	#
	# Prato, e não fruta. O talento é `rendimento_da_panela`, e manga chupada na
	# beira do rio não passou por panela nenhuma — quem tempera melhor não faz
	# a fruta do pé render mais. A pergunta é feita à lista de receitas, e não a
	# uma marca no item: assim comida nova nasce com a regra certa sem ninguém
	# se lembrar de marcá-la.
	var da_panela := RECEITAS.has(id)
	Energia.repor(float(dados_do_item.get("folego", 20.0))
		* (1.0 + (Talentos.bonus("rendimento_da_panela") if da_panela else 0.0)))
	# O REMÉDIO: o que tem `vida` devolve vida, e o que corta peçonha, corta.
	# Ver o chá de folha, acima.
	Vida.curar(float(dados_do_item.get("vida", 0.0)))
	if bool(dados_do_item.get("corta_peconha", false)):
		Vida.curar_veneno()
	var campo := str(dados_do_item.get("efeito_campo", ""))
	if campo != "":
		Efeitos.conceder("comida", str(dados_do_item.get("nome", id)), campo,
			float(dados_do_item.get("efeito_valor", 0.0)),
			int(dados_do_item.get("efeito_dias", 1)) + int(Talentos.bonus("dias_de_comida")),
			"comida")
	Audio.efeito("menu_confirma")
	comeu.emit(id)
	return true
