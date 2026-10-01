extends SceneTree
## Os colecionáveis, cartas e obras precisam existir num clone independente.
## Uma categoria vazia faria desaparecer conteúdo do vale sem erro de compilação.

const CATEGORIAS := {
    "data/colecionaveis/cordeis.json": "cordeis",
    "data/colecionaveis/sinais.json": "sinais",
    "data/colecionaveis/bichos.json": "bichos",
    "data/cartas/cartas.json": "cartas",
    "data/construcoes/obras.json": "obras",
}

func _initialize() -> void:
    var falhas := 0
    for caminho in CATEGORIAS:
        var dados = JSON.parse_string(FileAccess.get_file_as_string("res://" + caminho))
        if not dados is Dictionary or not dados.get(CATEGORIAS[caminho]) is Dictionary:
            push_error("DADOS_FALHOU: categoria ausente em " + caminho)
            falhas += 1
            continue
        var entradas: Dictionary = dados[CATEGORIAS[caminho]]
        if entradas.is_empty():
            push_error("DADOS_FALHOU: categoria vazia em " + caminho)
            falhas += 1
        for id in entradas:
            if str(id).is_empty() or not entradas[id] is Dictionary or entradas[id].is_empty():
                push_error("DADOS_FALHOU: entrada sem identidade ou conteúdo em " + caminho)
                falhas += 1
    if falhas == 0:
        print("DADOS_OK: colecionáveis, cartas e obras completos dentro do próprio projeto")
    quit(1 if falhas > 0 else 0)
