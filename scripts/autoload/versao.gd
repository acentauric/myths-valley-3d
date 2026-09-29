extends Node
## A versão DESTE projeto, para quem precisar carimbar alguma coisa com ela.
##
## NÃO é o `Versao` do jogo 2D, e é de propósito. O `CHANGELOG_3D.md` diz, na
## primeira linha, que a identificação desta derivação é própria e não herda a
## numeração do 2D — "v0.1.0-dev · Build #6", enquanto o 2D vai em 0.2.0-dev e
## build 14. Importar o arquivo de lá carimbaria os saves do vale com a versão
## de outro jogo.
##
## Quem pede isto é o `Salvamento`, que veio do 2D compartilhado: ele grava
## `Versao.VERSAO_ATUAL` e `Versao.BUILD_NUMERO` no cabeçalho da partida, para
## que um save saiba de que build ele saiu. A interface é essa, e é só essa —
## por isso este arquivo é curto e não copia o resto do de lá.
##
## A FONTE É O MESMO JSON QUE A ABERTURA MOSTRA. `historico_3d.json` já é o
## lugar onde a versão e o build são declarados, e o rodapé do menu os lê de
## lá. Um segundo lugar dizendo a mesma coisa é um segundo lugar para
## divergir: ao registrar um marco novo, muda-se o JSON e pronto.

const ARQUIVO := "res://data/historico_3d.json"

## Valores de partida, usados se o arquivo sumir. Não são a verdade — a
## verdade está no JSON —, são o que impede um save sem carimbo.
var VERSAO_ATUAL: String = "0.0.0-dev"
var BUILD_NUMERO: int = 0


func _ready() -> void:
	var arquivo := FileAccess.open(ARQUIVO, FileAccess.READ)
	if arquivo == null:
		push_warning("Versao: não achei %s; o save vai sair sem carimbo." % ARQUIVO)
		return
	var dado = JSON.parse_string(arquivo.get_as_text())
	arquivo.close()
	if typeof(dado) != TYPE_DICTIONARY:
		push_warning("Versao: %s não é um objeto JSON." % ARQUIVO)
		return
	VERSAO_ATUAL = str(dado.get("versao_atual", VERSAO_ATUAL))
	BUILD_NUMERO = int(dado.get("build_numero", BUILD_NUMERO))


## Como a abertura escreve no rodapé.
func texto() -> String:
	return "v%s · Build #%d" % [VERSAO_ATUAL, BUILD_NUMERO]
