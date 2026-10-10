extends "res://tests/unidade/base.gd"
## Os colecionáveis, cartas e obras precisam existir num clone independente.
## Uma categoria vazia faria desaparecer conteúdo do vale sem erro de compilação.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste dados

const CATEGORIAS := {
	"data/colecionaveis/cordeis.json": "cordeis",
	"data/colecionaveis/sinais.json": "sinais",
	"data/colecionaveis/bichos.json": "bichos",
	"data/cartas/cartas.json": "cartas",
	"data/construcoes/obras.json": "obras",
}

func test_dados() -> void:
	for caminho in CATEGORIAS:
		var dados = JSON.parse_string(FileAccess.get_file_as_string("res://" + caminho))
		var presente: bool = dados is Dictionary and dados.get(CATEGORIAS[caminho]) is Dictionary
		conferir(presente, "categoria ausente em " + caminho)
		if not presente:
			continue
		var entradas: Dictionary = dados[CATEGORIAS[caminho]]
		conferir(not entradas.is_empty(), "categoria vazia em " + caminho)
		for id in entradas:
			conferir(not (str(id).is_empty() or not entradas[id] is Dictionary or entradas[id].is_empty()),
				"entrada sem identidade ou conteúdo em " + caminho)
