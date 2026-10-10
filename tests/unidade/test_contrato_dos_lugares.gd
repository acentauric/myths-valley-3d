extends "res://tests/unidade/base.gd"
## O contrato é uma lista independente das tabelas da implementação (#54).
## Remover um nome das duas tabelas precisa reprovar, mesmo que nenhum pedido
## atual use aquele alvo dinâmico. Os JSON locais também não podem inventar nomes.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste contrato_dos_lugares
const CONTRATO := ["praca", "igreja", "venda", "pier", "ponte_da_vila",
	"ponte_do_rio_grande", "expansao", "lapa", "cabra_do_alto", "lombada",
	"portao_da_fazenda", "patio_da_fazenda", "casarao", "poco", "mirante",
	"cemiterio", "cruzeiro", "capela_estrada", "terreiro", "gameleira",
	"rocado", "lavoura", "casa_de_taipa", "casa_da_estrada", "fogueira",
	"oficina", "canteiro", "pedras", "casa_do_pedro", "casa_da_zefa",
	"portao", "porta", "cama", "fogao", "bau", "bau_da_casa", "comida_da_casa",
	"pedro", "quadro", "machado", "itens", "pedra", "colheita",
	"erva_mais_perto", "mato_mais_perto", "aldeao", "marco", "bicho"]


func test_contrato_dos_lugares() -> void:
	await process_frame
	var lugares := root.get_node("Lugares")
	var resolve: Dictionary = lugares.DE_PARA.duplicate()
	var ausente: Dictionary = lugares.FALTAM_NO_VALE.duplicate()
	if "--sem-porta" in OS.get_cmdline_user_args():
		resolve.erase("porta")
		ausente.erase("porta")
	for nome in CONTRATO:
		conferir(resolve.has(nome) or ausente.has(nome), "nome do contrato sem resolução nem razão: " + nome)
	for nome in ausente:
		conferir(not resolve.has(nome), "nome declarado em duas tabelas: " + nome)
		conferir(str(ausente[nome]).length() > 20, "razão concreta para " + nome)
	var diretorio := DirAccess.open("res://data")
	for arquivo in diretorio.get_files():
		if not arquivo.begins_with("missoes") or not arquivo.ends_with(".json"):
			continue
		var dados = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + arquivo))
		if not dados is Dictionary:
			continue
		for passo in dados.get("passos", []):
			var lugar := str(passo.get("lugar", ""))
			if lugar != "":
				conferir(resolve.has(lugar) or ausente.has(lugar), "%s/%s usa lugar não declarado: %s" % [arquivo, passo.get("id", ""), lugar])
