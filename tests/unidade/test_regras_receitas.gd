extends "res://tests/unidade/base.gd"
## Contratos de testar_receitas do 2D, SHA 62c0f14b (#18), com balcão 3D.
## Confere que RECEITA SE APRENDE — e que nenhuma fica fora de alcance.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste regras_receitas
##
## Do playtest: "considere que o NPC precisa encontrar, desbloquear, cumprir
## missões ou qualquer outra forma similar para desbloquear receitas e poder ver
## elas na lista de receitas no fogão. Isso vai impactar a missão de aprender a
## cozinhar. Faça isso também para receitas da Oficina de materiais e ferramentas
## e da Oficina de Construção."
##
## O sistema está em `Receitas`, e ele tem dois modos de falhar. Um é barato e
## visível: a bancada mostra o que não devia. O outro é caro e silencioso, e é
## este portão que existe por causa dele —
##
## RECEITA SEM PORTA NUNCA ABRE. Quem acrescentar um prato amanhã e esquecer a
## chave `abre` entrega uma receita que existe no catálogo, custa ingrediente,
## tem nome e resumo, e que NENHUM jogador vai ver. Não há erro, não há aviso: o
## prato simplesmente não está na lista, e ninguém sabe que devia estar. É o
## mesmo defeito que o `testar_obras` pegou nas obras que não mudavam nada.
##
## E O BECO PIOR, que é a razão de os passos serem simulados aqui: PASSO QUE
## MANDA FABRICAR O QUE O JOGADOR NÃO SABE. "Torre duas farinhas" com o fogão
## vazio é missão incumprível, e a tela não tem como dizer isso ao jogador —
## ele fica na frente do fogão lendo uma lista que não tem o que a missão pede.
## Cada passo desses está na tabela `O_QUE_O_PASSO_COBRA`, e o portão abre o
## passo e confere a bancada logo depois.

## OS PASSOS QUE MANDAM FABRICAR, e o que cada um cobra.
##
## Escrito à mão porque é conhecimento que só existe na cabeça de quem leu a
## frente: o passo `cozinhar` espera duas farinhas na mochila, e "espera duas
## farinhas" não é declarado em lugar nenhum que se possa varrer — é um
## `_esperar_quantidade("farinha", 2)` no meio do tutorial.
##
## Quem acrescentar um passo de fabricar e não puser aqui perde a cobertura, e
## isso é uma fraqueza conhecida deste portão. A alternativa seria varrer as
## chamadas de `_esperar_quantidade` e `_esperar_obra` no código, o que amarra o
## teste à forma das funções e quebra na primeira refatoração.
##
## `antes` são os passos que a série abre ANTES deste, e existe porque duas
## séries do arraial são filas de verdade: o canteiro manda juntar material e só
## depois tocar a obra, e é o primeiro passo que ensina o plano. Um portão que
## abrisse só o segundo estaria conferindo uma situação que o jogo não produz —
## mas a fila declarada aqui é o que garante que ela continue sendo fila.
const O_QUE_O_PASSO_COBRA := {
	"cozinhar": {"cobra": ["farinha"]},
	"pirao": {"cobra": ["pirao"]},
	"tabuas": {"cobra": ["tabua"]},
	"armas_facao": {"cobra": ["facao"]},
	"canteiro_material": {"cobra": ["canteiro_prancheta"]},
	"canteiro_obra": {"antes": ["canteiro_material"], "cobra": ["canteiro_prancheta"]},
	"mirante_material": {"cobra": ["mirante_levantar", "corda"]},
	"mirante_obra": {"antes": ["mirante_material"], "cobra": ["mirante_levantar"]},
	# No 3D, coveiro_cabo pede lenha e recebe a foice pronta, sem fabricar.
	"pescador_rede": {"cobra": ["tabua", "corda"]},
}

## Onde os passos do jogo estão escritos. As missões são abertas por código, mas
## o id de cada uma é a chave dela em `passos` — ver `Arraial._anunciar`.
const FALAS := [
	"res://data/dialogos/pedro.json",
	"res://data/dialogos/arraial.json",
	"res://data/dialogos/fazenda.json",
]


## Os ids dos passos, lidos dos arquivos de fala. Pelo `jogo` e não pelo nome do
## autoload: num script de `SceneTree` os autoloads não são identificadores, só
## nós de `/root`.
func passos_do_jogo() -> Array:
	var ids: Array = []
	for arquivo in DirAccess.get_files_at("res://data"):
		if not arquivo.begins_with("missoes_") or not arquivo.ends_with(".json"):
			continue
		for passo in jogo.dados("res://data/" + arquivo).get("passos", []):
			ids.append(str(passo.get("id", "")))
	return ids


var receitas: Node
var cozinha: Node
var oficina: Node
var obras: Node
var missoes: Node
var afinidade: Node
var colecao: Node
var inventario: Node
var jogo: Node
## O `Venda` das mercadorias, que não é o `Receitas.a_venda` dos planos.
var venda_de_itens: Node


## VOLTA O JOGO AO PRIMEIRO DIA, e a ordem importa: as receitas por último.
##
## `Receitas.limpar()` termina chamando `conferir()`, que varre o estado atual —
## missão cumprida, grau de afinidade, cordel achado, item na mochila — e reabre
## o que ele já permitia. Zerar as receitas ANTES de zerar o resto deixaria de
## pé o que o bloco anterior abriu, e o bloco seguinte passaria em falso sem
## testar a porta que diz estar testando.
func zerar() -> void:
	missoes.limpar()
	afinidade.pontos.clear()
	colecao.achados.clear()
	for id in ["carne_de_caca", "milho", "cana", "lenha"]:
		inventario.consumir(str(id), inventario.quantidade(str(id)))
	receitas.limpar()


func test_regras_receitas() -> void:
	receitas = root.get_node("/root/Receitas")
	cozinha = root.get_node("/root/Cozinha")
	oficina = root.get_node("/root/Oficina")
	obras = root.get_node("/root/Obras")
	missoes = root.get_node("/root/Missoes")
	afinidade = root.get_node("/root/Afinidade")
	colecao = root.get_node("/root/Colecao")
	inventario = root.get_node("/root/Inventario")
	jogo = root.get_node("/root/Jogo")
	venda_de_itens = root.get_node("/root/Venda")

	var catalogo: Dictionary = receitas.tudo().duplicate(true)
	if "--falsificar-porta" in OS.get_cmdline_user_args():
		catalogo[catalogo.keys()[0]]["abre"] = {}
	conferir(catalogo.size() >= 40,
		"Esperava as três bancadas somarem ao menos 40 receitas, achei %d" % catalogo.size())

	# --- 1. TODA RECEITA DECLARA POR ONDE SE APRENDE --------------------------
	#
	# É o bloco que impede a receita invisível. Sem `abre`, nada no jogo abre.
	var sem_porta: Array = []
	for id in catalogo:
		if (catalogo[id].get("abre", {}) as Dictionary).is_empty():
			sem_porta.append(str(id))
	sem_porta.sort()
	conferir(sem_porta.is_empty(),
		"Receitas sem a chave 'abre': %s. Receita sem porta nunca aparece para o jogador."
			% ", ".join(sem_porta))

	# --- 2. AS PORTAS APONTAM PARA COISA QUE EXISTE ---------------------------
	#
	# Porta escrita com o nome errado é o mesmo que porta nenhuma, e é pior de
	# achar: o código roda, o dicionário responde, e a chave simplesmente nunca
	# casa com o sinal que chega.
	var conhecidos := passos_do_jogo()
	conferir(conhecidos.size() >= 40,
		"Esperava achar ao menos 40 passos nos arquivos de fala, achei %d" % conhecidos.size())
	var itens_de_colecao: Array = []
	for qual in colecao.COLECOES:
		itens_de_colecao.append_array(colecao.catalogo(str(qual)).keys())

	for id in catalogo:
		var portas: Dictionary = catalogo[id].get("abre", {})
		for chave in portas:
			conferir(receitas.PORTAS.has(str(chave)),
				"A receita %s declara a porta '%s', que não existe. As portas são %s."
					% [id, chave, ", ".join(receitas.PORTAS)])
		if portas.has("missao"):
			var pedidos: Array = portas["missao"] if portas["missao"] is Array else [portas["missao"]]
			for pedido in pedidos:
				conferir(conhecidos.has(str(pedido)),
					"A receita %s abre pela missao '%s', e nao ha passo com esse id no jogo"
					% [id, pedido])
		if portas.has("morador"):
			conferir(afinidade.MORADORES.has(str(portas["morador"])),
				"A receita %s abre pelo morador '%s', que nao mora no arraial"
					% [id, portas["morador"]])
			var grau := int(portas.get("grau", 1))
			conferir(grau >= 1 and grau < afinidade.GRAUS.size(),
				"A receita %s pede grau %d com %s, e os graus vao de 1 a %d"
					% [id, grau, portas["morador"], afinidade.GRAUS.size() - 1])
		if portas.has("achado"):
			var chave_do_achado := str(portas["achado"])
			conferir(Catalogo.existe(chave_do_achado) or itens_de_colecao.has(chave_do_achado),
				"A receita %s abre pelo achado '%s', que nao e item nem peca de colecao"
					% [id, chave_do_achado])
		if portas.has("compra"):
			conferir(int(portas["compra"]) > 0,
				"A receita %s esta a venda por %d reis" % [id, int(portas["compra"])])
		# `grau` sem `morador` é porta pela metade: o número não abre nada.
		conferir(not portas.has("grau") or portas.has("morador"),
			"A receita %s declara grau sem morador" % id)

	# --- 3. O PASSO QUE MANDA FABRICAR ENSINA ANTES DE COBRAR -----------------
	#
	# O beco. Abre cada passo de verdade, pelo caminho de verdade
	# (`Missoes.adicionar`, que é o que solta o sinal), e confere a bancada.
	for passo in O_QUE_O_PASSO_COBRA:
		zerar()
		var dito: Dictionary = O_QUE_O_PASSO_COBRA[passo]
		conferir(conhecidos.has(str(passo)),
			"O portao vigia o passo '%s', que nao existe mais no jogo" % passo)
		for anterior in dito.get("antes", []):
			conferir(conhecidos.has(str(anterior)),
				"O portao diz que '%s' vem antes de '%s', e ele nao existe mais" % [anterior, passo])
			missoes.adicionar(str(anterior), "conferindo")
			missoes.concluir(str(anterior))
		missoes.adicionar(str(passo), "conferindo")
		for pedida in dito.get("cobra", []):
			conferir(receitas.sabe(str(pedida)),
				"O passo '%s' manda fabricar %s e o jogador nao sabe a receita: a bancada abre vazia e a missao nao fecha"
					% [passo, pedida])

	# --- 4. AS BANCADAS SÓ LISTAM O QUE SE SABE ------------------------------
	zerar()
	var so_de_comeco: Array = receitas.aprendidas.duplicate()
	conferir(not so_de_comeco.is_empty(),
		"Nenhuma receita nasce sabida: a oficina do primeiro dia abre vazia e o tutorial manda serrar tabua")
	conferir(cozinha.receitas().is_empty(),
		"O fogao do primeiro dia lista %s, e nenhum prato devia nascer sabido"
			% ", ".join(cozinha.receitas()))
	conferir(oficina.receitas().has("tabua") and oficina.receitas().has("corda"),
		"A oficina do primeiro dia nao lista tabua e corda, que o tutorial e tres series do arraial cobram")
	conferir(not oficina.receitas().has("facao"),
		"A oficina do primeiro dia ja lista o facao, que e licao do Pedro")
	# O ORATÓRIO, e não o sobrado. O sobrado seria a pergunta errada: ele exige a
	# varanda, então a cadeia do `exige` o esconde sozinha e a linha passaria
	# mesmo sem filtro de plano nenhum — foi o que a falsificação flagrou. O
	# oratório não exige obra alguma e só se aprende escolhendo uma fé, então o
	# único motivo para ele não estar na lista é o que esta linha diz que é.
	conferir(not obras.disponiveis("casa").has("mobilia_altar"),
		"A casa do primeiro dia ja oferece o oratorio, que se aprende escolhendo uma fe")
	conferir(obras.disponiveis("casa").has("casca_varanda"),
		"A casa do primeiro dia nao oferece a varanda, que e a obra de onde as outras partem")

	# E a bancada FECHADA de verdade, e não só escondida: quem chamar `cozinhar`
	# por fora da tela leva o mesmo não.
	inventario.adicionar("milho", 9)
	inventario.adicionar("cana", 9)
	inventario.adicionar("lenha", 9)
	conferir(cozinha.impedimento("mungunza") != "",
		"Com todos os ingredientes na mao, o mungunza que o jogador nao sabe passou pelo impedimento")
	conferir(not cozinha.cozinhar("mungunza"),
		"O fogao cozinhou um mungunza que o jogador nao sabe fazer")

	# --- 5. CADA PORTA ABRE ---------------------------------------------------
	#
	# Uma por uma, pelo sinal de verdade. Porta que não abre é receita presa, e é
	# o mesmo estrago da receita sem porta.
	zerar()
	missoes.adicionar("zefa_ervas", "conferindo")
	conferir(receitas.sabe("cha_de_folha"),
		"A porta da MISSAO nao abriu: zefa_ervas devia ensinar o cha de folha")

	zerar()
	afinidade.somar("candinha", afinidade.GRAUS[1]["de"])
	conferir(receitas.sabe("garapa"),
		"A porta do MORADOR nao abriu: a Dona Candinha em grau 1 devia ensinar a garapa")
	conferir(not receitas.sabe("mobilia_tapete"),
		"A porta do MORADOR abriu cedo: o tapete e grau 2 com a Candinha e ela esta em grau 1")
	afinidade.somar("candinha", afinidade.GRAUS[2]["de"])
	conferir(receitas.sabe("mobilia_tapete"),
		"A porta do MORADOR nao abriu no grau 2: a Candinha subiu e o tapete nao entrou")

	zerar()
	colecao.achar("cordeis", "boi_do_reconcavo")
	conferir(receitas.sabe("mungunza"),
		"A porta do ACHADO nao abriu: o cordel do boi devia ensinar o mungunza")

	zerar()
	conferir(not receitas.sabe("carne_assada"),
		"A carne assada ficou sabida depois de limpar")
	inventario.adicionar("carne_de_caca", 1)
	conferir(receitas.sabe("carne_assada"),
		"A porta do ACHADO por ITEM nao abriu: carne na mochila devia ensinar a assar")

	# --- 6. O BALCÃO ---------------------------------------------------------
	zerar()
	var a_venda: Array = receitas.a_venda()
	conferir(a_venda.size() >= 15,
		"Esperava ao menos 15 receitas a venda no balcao, achei %d" % a_venda.size())
	for id in a_venda:
		conferir(receitas.preco(str(id)) > 0, "A receita %s esta a venda de graca" % id)

	var escolhida := str(a_venda[0])
	var quanto: int = receitas.preco(escolhida)
	jogo.dinheiro = quanto - 1
	conferir(not receitas.comprar(escolhida),
		"O balcao vendeu %s por %d reis a quem tinha %d" % [escolhida, quanto, quanto - 1])
	jogo.dinheiro = quanto + 100
	conferir(receitas.comprar(escolhida),
		"O balcao recusou %s a quem tinha os %d reis" % [escolhida, quanto])
	conferir(jogo.dinheiro == 100,
		"A compra de %s devia cobrar %d reis e sobraram %d de %d"
			% [escolhida, quanto, jogo.dinheiro, quanto + 100])
	conferir(not receitas.a_venda().has(escolhida),
		"O balcao continua oferecendo %s depois de vender" % escolhida)
	conferir(not receitas.comprar(escolhida),
		"O balcao vendeu %s duas vezes" % escolhida)

	# --- 6b. O BALCÃO NA TELA, e a colisão de id que ele tem de aguentar -----
	#
	# `facao` é receita da oficina E mercadoria do balcão; `pirao` é prato do
	# fogão E item que se vende. Numa lista só, o id cru não diz qual das duas
	# coisas a linha é — e a linha do facão venderia a receita a quem quis
	# comprar a lâmina pronta. É o que o prefixo resolve, e é o que se confere
	# aqui: pelas funções da tela, e não remontando a regra.
	var painel = load("res://scripts/prototipo_3d/painel_vale.gd").new()
	var balcao: Array = painel.o_que_o_balcao_tem()
	for id in venda_de_itens.mercadorias():
		conferir(balcao.has(str(id)), "O balcao deixou de oferecer a mercadoria %s" % id)
		conferir(painel._receita_da_linha(str(id)) == "",
			"A tela leu a mercadoria %s como receita" % id)
	for id in receitas.a_venda():
		var linha: String = str(painel.PREFIXO_DA_RECEITA) + str(id)
		conferir(balcao.has(linha), "O balcao nao oferece a receita %s" % id)
		conferir(painel._receita_da_linha(linha) == str(id),
			"A tela nao devolveu %s da linha '%s'" % [id, linha])

	# E A COLISÃO, de frente: o facão é mercadoria e é receita, então o balcão tem
	# de ter DUAS linhas dele, lidas de maneiras diferentes. Sem o prefixo as
	# duas seriam a mesma string, e a segunda sumiria.
	conferir(venda_de_itens.mercadorias().has("facao") and receitas.a_venda().has("facao"),
		"O facao deixou de ser mercadoria e receita ao mesmo tempo: a colisao que o prefixo resolve nao existe mais, e este bloco perdeu o assunto")
	var linhas_do_facao := 0
	for linha in balcao:
		if str(linha).ends_with("facao"):
			linhas_do_facao += 1
	conferir(linhas_do_facao == 2,
		"O balcao tem %d linha(s) de facao, e devia ter duas: a lamina pronta e o plano" % linhas_do_facao)

	# --- 7. VALE A PRIMEIRA QUE ACONTECER ------------------------------------
	#
	# A regra do autor para as receitas de duas portas: "valendo a que o jogador
	# atingir primeiro". Ela sai da idempotência, e sem ela a segunda porta
	# cobraria de novo — o que no caso da compra é cobrar réis por receita
	# sabida.
	zerar()
	missoes.adicionar("candinha_cana", "conferindo")
	conferir(receitas.sabe("garapa"), "A garapa nao abriu pela missao da Candinha")
	conferir(not receitas.aprender("garapa", "morador"),
		"A garapa foi aprendida duas vezes: a segunda porta devia nao fazer nada")
	afinidade.somar("candinha", afinidade.MAXIMO)
	var quantas := 0
	for id in receitas.aprendidas:
		if str(id) == "garapa":
			quantas += 1
	conferir(quantas == 1, "A garapa esta %d vezes na lista de aprendidas" % quantas)

	# --- 8. O SAVE ANTIGO NÃO PERDE O FOGÃO ----------------------------------
	#
	# `conferir()` é o que faz este sistema poder entrar num jogo que já está
	# sendo jogado: sinal não se repete, e a partida de quem já cumpriu a missão
	# do fogão não vai receber o aviso de novo. Ver `Salvamento._limpar_receitas`.
	zerar()
	missoes.adicionar("zefa_ervas", "conferindo")
	missoes.concluir("zefa_ervas")
	afinidade.somar("filo", afinidade.GRAUS[2]["de"])
	colecao.achar("cordeis", "boi_do_reconcavo")
	# O save de antes desta rodada: a lista de receitas não existe.
	receitas.aprendidas.clear()
	conferir(not receitas.sabe("cha_de_folha"), "A lista de receitas nao ficou vazia")
	receitas.conferir()
	conferir(receitas.sabe("cha_de_folha"),
		"conferir() nao reabriu o cha de folha, cuja missao ja estava cumprida")
	conferir(receitas.sabe("pirao"),
		"conferir() nao reabriu o pirao, e a Dona Filo ja esta em grau 2")
	conferir(receitas.sabe("mungunza"),
		"conferir() nao reabriu o mungunza, e o cordel do boi ja estava achado")
	conferir(receitas.sabe("tabua"),
		"conferir() nao reabriu a tabua, que nasce sabida")

	# --- 9. NENHUMA RECEITA FORA DE ALCANCE ----------------------------------
	#
	# Porta declarada é porta que existe (bloco 2) — este confere que ela é
	# ALCANÇÁVEL. Morador que não tem missão nem gosto declarado não sobe de
	# grau, e uma receita presa atrás dele é receita perdida.
	var presas: Array = []
	for id in catalogo:
		var portas: Dictionary = catalogo[id].get("abre", {})
		if portas.has("comeco") or portas.has("compra") or portas.has("achado") \
				or portas.has("missao"):
			continue
		# Só resta a porta do morador: ele tem de ter como subir.
		var quem := str(portas.get("morador", ""))
		if quem == "" or (jogo.dados(afinidade.ARQUIVO_DOS_MORADORES).get(quem, {})
				as Dictionary).get("gosta", []).is_empty():
			presas.append(str(id))
	presas.sort()
	conferir(presas.is_empty(),
		"Receitas presas atras de morador que nao tem como subir de grau: %s" % ", ".join(presas))

	painel.free()
