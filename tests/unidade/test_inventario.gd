extends "res://tests/unidade/base.gd"
## Confere que o INVENTÁRIO do jogo 2D chegou ao vale inteiro, e que o catálogo
## de itens veio junto.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste inventario
##
## `Inventario`, `Equipamento` e `Catalogo` são os mesmos arquivos do 2D, em
## `scripts/compartilhado/`, conferidos byte a byte pelo `testar_compartilhado`
## do outro projeto. Eles só puderam atravessar depois que a TECLA saiu do
## `Inventario`: doze linhas de `_unhandled_input` — que dependem das ações
## `espaco_N` e do `Telas`, nenhum dos dois existe aqui — prendiam 174 linhas
## de regra ao 2D. A tecla ficou lá, no `Controles`; a regra veio.
##
## Cinco perguntas:
##
##   1. OS TRÊS ESTÃO DE PÉ, e com os números do 2D: 30 espaços, 10 de mão.
##   2. A REGRA DE GUARDAR FUNCIONA: entra, empilha, conta e sai.
##   3. A MÃO LIVRE EXISTE, que é o estado de colher.
##   4. O CATÁLOGO VEIO INTEIRO, com os itens que a campanha cita pelo nome.
##   5. ÍCONE AUSENTE NÃO DERRUBA NADA. O catálogo integrado tem sprites;
##      pedir uma arte inexistente ainda deve devolver `null` sem quebrar
##      a mochila. A inicial do item continua disponível como fallback.


func test_inventario() -> void:
	# --- 1. OS TRÊS DE PÉ -----------------------------------------------------
	var inv := root.get_node_or_null("/root/Inventario")
	var equip := root.get_node_or_null("/root/Equipamento")
	_conferir(inv != null, "o autoload Inventario não subiu")
	_conferir(equip != null, "o autoload Equipamento não subiu")
	if inv == null or equip == null:
		return

	_conferir(inv.ESPACOS_MAO == 10, "a barra de mão não tem 10 espaços: %d" % inv.ESPACOS_MAO)
	_conferir(inv.ESPACOS == 30, "a mochila não tem 30 espaços: %d" % inv.ESPACOS)
	_conferir(inv.espacos.size() == inv.ESPACOS,
		"os espaços não foram criados: %d" % inv.espacos.size())

	# --- 2. A REGRA DE GUARDAR ------------------------------------------------
	#
	# O item escolhido é a mandioca, que é o pão desta terra e o primeiro que o
	# tutorial do 2D põe na mão de alguém.
	_conferir(inv.quantidade("mandioca") == 0, "o vale começou com mandioca na mochila")
	_conferir(inv.adicionar("mandioca", 3), "não consegui guardar mandioca")
	_conferir(inv.quantidade("mandioca") == 3,
		"guardei 3 mandiocas e a conta deu %d" % inv.quantidade("mandioca"))
	_conferir(inv.tem("mandioca"), "tem() não achou o que adicionar() guardou")

	_conferir(inv.adicionar("mandioca", 2), "não consegui empilhar mais mandioca")
	_conferir(inv.quantidade("mandioca") == 5,
		"empilhar não somou: %d" % inv.quantidade("mandioca"))
	_conferir(inv.ocupados() == 1, "cinco mandiocas ocuparam %d espaços" % inv.ocupados())

	_conferir(inv.consumir("mandioca", 2), "não consegui consumir mandioca")
	_conferir(inv.quantidade("mandioca") == 3,
		"consumir 2 de 5 deixou %d" % inv.quantidade("mandioca"))
	_conferir(not inv.consumir("mandioca", 99),
		"consumir mais do que há devia recusar, e não recusou")
	_conferir(inv.quantidade("mandioca") == 3,
		"a recusa de consumir levou item junto: %d" % inv.quantidade("mandioca"))

	# --- 3. A MÃO LIVRE -------------------------------------------------------
	inv.selecionar(0)
	_conferir(inv.selecionado == 0, "selecionar(0) não pegou o primeiro espaço")
	_conferir(inv.na_mao() == "mandioca",
		"o primeiro espaço tem mandioca e a mão diz '%s'" % inv.na_mao())
	inv.alternar(0)
	_conferir(inv.selecionado == inv.MAO_LIVRE,
		"apertar de novo o espaço que já estava na mão não soltou o item")
	_conferir(inv.na_mao() == "", "de mão livre, a mão ainda segura '%s'" % inv.na_mao())

	# --- 4. O CATÁLOGO VEIO INTEIRO -------------------------------------------
	#
	# Os nomes vêm da campanha, e não de uma lista inventada aqui: são o que o
	# tutorial entrega e o que a ponte pede.
	for id in ["mandioca", "machado", "enxada", "balde", "picareta", "tabua", "corda", "peixe"]:
		_conferir(Catalogo.ITENS.has(id), "o catálogo não tem '%s'" % id)
		if Catalogo.ITENS.has(id):
			_conferir(str(Catalogo.ITENS[id].get("nome", "")) != "",
				"'%s' está no catálogo sem nome" % id)

	_conferir(Catalogo.ITENS.size() > 30,
		"o catálogo veio com %d itens: parece cortado" % Catalogo.ITENS.size())

	# --- 5. ÍCONE AUSENTE NÃO DERRUBA ----------------------------------------
	#
	# Aqui não há `assets/sprites/itens/`: aquela pasta é do 2D. A pergunta não
	# é se o ícone aparece, é se pedir um ícone que não existe quebra alguma
	# coisa — porque o dia em que a mochila chegar, ela vai pedir os trinta.
	var icone = Catalogo.icone("mandioca")
	_conferir(icone == null or icone is Texture2D,
		"icone() devolveu algo que não é textura nem nada")
