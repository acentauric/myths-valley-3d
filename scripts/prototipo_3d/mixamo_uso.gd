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
##                joelhos). Pode ser uma lista. Quem não tem agenda, só postos por
##                período do dia (a Dona Zefa, o Tonho, o Damião, o Quirino), usa
##                "posto:<período>" ("posto:manha", "posto:tarde", "posto:entardecer",
##                "posto:noite", "posto:madrugada") — o `npc.gd` dá a esses o período
##                como ação;
##   `a_cada`     [mínimo, máximo] em segundos: o clipe se INTERCALA com o principal
##                da mesma ação, de tempos em tempos (lançar a linha). Quem não tem
##                clipe principal na ação (o Tonho contando nos dedos) o faz do parado;
##   `gatilho_id` um gatilho com código próprio:
##                  `treino`, `conducao`   o Pedro (guia_pedro.gd);
##                  `saudacao`             no lugar do gesto de saudação do Tripo (npc.gd);
##                  `porta`                o morador abre a porta de casa ao se recolher (npc.gd);
##                  `passo`                o passo da ação (com `acao`): anda assim a caminho
##                                         dela (npc.gd, authored_animator.set_passo);
##                  `pulo`, `soco`, `acordar_cama`, `acordar_chao`, `cansado`
##                                         o viajante (player_controller, luta_vale, queda);
##   `pendente`   o motivo de o gatilho ainda não existir no jogo (`assento`: sentar
##                num banco que o vale não tem na rotina do morador; `porta_do_jogador`).
##                O clipe fica na biblioteca e na ficha, mas nenhum código o toca: o
##                portão confere que o motivo está escrito, e que ele sai desta
##                lista quando o gatilho passa a existir.
##
## Sem autoload (portão rodado com `--script` não enxerga autoload pelo nome): um
## portão o confere sem montar o vale.

const ARQUIVO := "res://data/mixamo_uso.json"
const PASTA := "res://assets/prototipo_3d/personagens/mixamo/"
## O nome da biblioteca no tocador do modelo, e o selo de origem na ficha.
const BIBLIOTECA := "mixamo"
const ORIGEM := "Mixamo"
## O prefixo da ação de quem só tem postos por período: "posto:manha".
const POSTO := "posto:"

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


## A ação `acao` está entre as do clipe (`acao` é um texto ou uma lista)?
static func _tem_acao(c: Dictionary, acao: String) -> bool:
	var das = c.get("acao", "")
	if das is Array:
		return acao in das
	return acao != "" and str(das) == acao


## O clipe espera um gatilho que ainda não existe no jogo?
static func pendente(c: Dictionary) -> bool:
	return c.has("pendente")


## O CLIPE PRINCIPAL DA AÇÃO para o personagem: o Mixamo que a `acao` toca sem
## `a_cada`, ou "" (fica o clipe Tripo de sempre, `npc.ACOES`). O passo da ação
## (`gatilho_id` "passo") tem `acao` e não é o trabalho dela.
static func clipe_da_acao(id: String, acao: String) -> String:
	for c: Dictionary in clipes(id):
		if _tem_acao(c, acao) and not c.has("a_cada") and not c.has("gatilho_id") and not pendente(c):
			return str(c.get("id", ""))
	return ""


## Os clipes que se intercalam com o principal da ação (os que têm `a_cada`).
static func variacoes_da_acao(id: String, acao: String) -> Array:
	var lista: Array = []
	for c: Dictionary in clipes(id):
		if _tem_acao(c, acao) and c.has("a_cada") and not c.has("gatilho_id") and not pendente(c):
			lista.append(c)
	return lista


## O PASSO DA AÇÃO: o clipe com que o personagem anda a caminho dela, ou "".
static func passo_da_acao(id: String, acao: String) -> String:
	for c: Dictionary in clipes(id):
		if str(c.get("gatilho_id", "")) == "passo" and _tem_acao(c, acao) and not pendente(c):
			return str(c.get("id", ""))
	return ""


## O clipe do gatilho com código `gatilho_id` ("saudacao", "porta", "pulo"...), ou "".
static func clipe_do_gatilho(id: String, gatilho_id: String) -> String:
	for c: Dictionary in clipes(id):
		if str(c.get("gatilho_id", "")) == gatilho_id and not pendente(c):
			return str(c.get("id", ""))
	return ""


## O personagem tem clipe que depende do período do posto ("posto:manha"...)? Só quem
## tem sai do atalho do `npc._atualizar_trabalho`, que ignora quem não tem agenda.
static func tem_acao_de_posto(id: String) -> bool:
	for c: Dictionary in clipes(id):
		var das = c.get("acao", "")
		for acao in (das if das is Array else [das]):
			if str(acao).begins_with(POSTO):
				return true
	return false


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
