extends RefCounted
## OS CLIPES DO MIXAMO DE CADA PERSONAGEM (#190), lidos de `data/mixamo_uso.json`.
##
## O movimento vem do Mixamo, redirecionado para o esqueleto Tripo de cada morador
## por `tools/prototipo_3d/mixamo/redirecionar.gd`, que grava uma biblioteca de
## animações por modelo (`PASTA/<modelo>.res`). O `authored_animator` a pendura no
## tocador do modelo como a biblioteca "mixamo", e os clipes passam a se chamar
## pelo id ("capoeira", "fishing_idle") como os do Tripo ("idle", "walk").
##
## Cada clipe do JSON diz QUANDO toca no jogo — e clipe sem gatilho não entra:
##
##   `acao`       a ação da rotina (`npcs_3d.json`, agenda) que o toca no lugar do
##                clipe Tripo de sempre (o pescador pesca de vara, a beata reza de
##                joelhos);
##   `a_cada`     [mínimo, máximo] em segundos: o clipe se INTERCALA com o principal
##                da mesma ação, de tempos em tempos (lançar a linha);
##   `gatilho_id` um gatilho com código próprio (`treino` e `conducao`, o Pedro).
##
## Sem autoload (portão rodado com `--script` não enxerga autoload pelo nome): um
## portão o confere sem montar o vale.

const ARQUIVO := "res://data/mixamo_uso.json"
const PASTA := "res://assets/prototipo_3d/personagens/mixamo/"
## O nome da biblioteca no tocador do modelo, e o selo de origem na ficha.
const BIBLIOTECA := "mixamo"
const ORIGEM := "Mixamo"

static var _dados: Dictionary = {}


static func dados() -> Dictionary:
	if _dados.is_empty():
		var lido = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO)) if FileAccess.file_exists(ARQUIVO) else null
		_dados = lido if lido is Dictionary else {"personagens": []}
	return _dados


## A entrada do personagem de id `id` (o do `npcs_3d.json`), ou {}.
static func personagem(id: String) -> Dictionary:
	for pessoa: Dictionary in dados().get("personagens", []):
		if str(pessoa.get("id", "")) == id:
			return pessoa
	return {}


## Os clipes Mixamo do personagem (cada um um Dictionary do JSON).
static func clipes(id: String) -> Array:
	return personagem(id).get("clipes_mixamo", [])


## O clipe do personagem de id `clipe`, ou {}.
static func clipe(id: String, clipe_id: String) -> Dictionary:
	for c: Dictionary in clipes(id):
		if str(c.get("id", "")) == clipe_id:
			return c
	return {}


## A biblioteca redirecionada do modelo, ou null quando ele não tem nenhuma.
static func biblioteca(modelo: String) -> AnimationLibrary:
	var caminho := PASTA + modelo + ".res"
	if modelo.is_empty() or not ResourceLoader.exists(caminho):
		return null
	return load(caminho) as AnimationLibrary


## O CLIPE PRINCIPAL DA AÇÃO para o personagem: o Mixamo que a `acao` toca sem
## `a_cada`, ou "" (fica o clipe Tripo de sempre, `npc.ACOES`).
static func clipe_da_acao(id: String, acao: String) -> String:
	for c: Dictionary in clipes(id):
		if str(c.get("acao", "")) == acao and not c.has("a_cada"):
			return str(c.get("id", ""))
	return ""


## Os clipes que se intercalam com o principal da ação (os que têm `a_cada`).
static func variacoes_da_acao(id: String, acao: String) -> Array:
	var lista: Array = []
	for c: Dictionary in clipes(id):
		if str(c.get("acao", "")) == acao and c.has("a_cada"):
			lista.append(c)
	return lista


## Segundos até a próxima variação, sorteados entre o mínimo e o máximo do `a_cada`.
static func espera_da_variacao(c: Dictionary, sorteio: float) -> float:
	var faixa: Array = c.get("a_cada", [20.0, 40.0])
	var minimo := float(faixa[0]) if faixa.size() > 0 else 20.0
	var maximo := float(faixa[1]) if faixa.size() > 1 else minimo
	return lerpf(minimo, maximo, clampf(sorteio, 0.0, 1.0))


## O clipe toca em laço?
static func em_laco(id: String, clipe_id: String) -> bool:
	return bool(clipe(id, clipe_id).get("laco", false))


## O rótulo de um clipe Tripo pelo nome-base ("idle" → "Parado"), no idioma pedido
## por `campo` (o `IdiomaMenu.campo`); o próprio nome quando não há rótulo.
static func rotulo_tripo(nome: String, campo: Callable) -> String:
	var rotulos: Dictionary = dados().get("rotulos_tripo", {})
	if not rotulos.has(nome):
		return nome
	return str(campo.call(rotulos[nome], "rotulo"))
