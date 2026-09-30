extends RefCounted
## Atalhos de tecla remapeáveis (AJUSTAR → Geral → Atalhos): cada ação usa uma letra
## A–Z, salva em user://controles.cfg (seção "atalhos", o mesmo arquivo das teclas de
## movimento). `aplicar()` re-registra as ações do InputMap; se a letra escolhida já
## pertence a outra ação, `definir()` troca as duas entre si (swap), então nunca há
## duas ações na mesma letra. "interagir", "gingar", "painel" e "colecao" não têm ação no InputMap:
## lápides, árvores, a luta e o vale comparam o evento com `tecla(...)`.

const ARQUIVO := "user://controles.cfg"
## Rótulo (para o AJUSTAR) e letra de fábrica de cada ação.
const DEFINICOES := {
	"interagir": {"rotulo": "Ler / interagir", "padrao": KEY_E},
	"observar": {"rotulo": "Observar", "padrao": KEY_F},
	"hora": {"rotulo": "Avançar a hora", "padrao": KEY_T},
	"reiniciar": {"rotulo": "Reiniciar", "padrao": KEY_R},
	"mapa": {"rotulo": "Mapa", "padrao": KEY_M},
	"camera": {"rotulo": "Alternar a câmera", "padrao": KEY_C},
	# A ginga da capoeira (#14), para quem aprendeu com o Cosme; V como no 2D.
	"gingar": {"rotulo": "Gingar (esquiva)", "padrao": KEY_V},
	# O painel de missões, cartas, venda e jogo (#19); J como no 2D.
	"painel": {"rotulo": "Painel", "padrao": KEY_J},
	# O ALMANAQUE NO L, que é a tecla da coleção no jogo 2D.
	#
	# Ele nasceu no L emprestado, foi para o K quando a coleção chegou, e volta
	# ao L agora que ELE É A COLEÇÃO: plantas, cordéis, sinais e bichos no mesmo
	# caderno. Duas telas com a mesma função em teclas vizinhas era o jogador
	# tendo de decorar qual guardava o quê.
	#
	# E o K, que sobrou, é a tecla da TEIA DE TALENTOS no 2D — que é exatamente
	# o que o autor pediu para ele: "precisamos do botão disponível para acessar
	# a árvore de habilidades".
	"almanaque": {"rotulo": "Almanaque", "padrao": KEY_L},
	"talentos": {"rotulo": "Árvore de habilidades", "padrao": KEY_K},
	# A teia social do arraial: quem mora aqui e o quanto cada um gosta de você.
	# P como no 2D, que o tutorial de lá ensina com estas palavras: "aperte P e
	# veja quem é quem no arraial".
	"arraial": {"rotulo": "O arraial", "padrao": KEY_P},
}
## Ação do InputMap que `aplicar()` re-registra para cada atalho.
const ACOES_INPUT := {
	"observar": "mv_inspect",
	"hora": "mv_time",
	"reiniciar": "mv_reset",
	"mapa": "mv_mapa",
	"camera": "mv_cursor",
	"almanaque": "mv_almanaque",
}

## Cache das teclas lidas do arquivo (evita reler o disco a cada evento de tecla).
static var _cache: Dictionary = {}


## Keycode (KEY_A–KEY_Z) da ação; qualquer valor estranho no arquivo volta ao padrão.
static func tecla(acao: String) -> int:
	if _cache.has(acao):
		return int(_cache[acao])
	# NOME QUE A TABELA NÃO CONHECE devolve 0, e não derruba.
	#
	# `DEFINICOES[acao]` cru estourava com nome desconhecido, e isso amarrava a
	# tabela a quem a consulta: retirar um atalho — como o da coleção, que virou
	# uma seção do almanaque — quebraria toda tela que ainda perguntasse por
	# ele. Zero não é tecla nenhuma: evento de teclado nunca traz 0, então a
	# comparação simplesmente nunca casa.
	if not DEFINICOES.has(acao):
		return 0
	var padrao := int(DEFINICOES[acao]["padrao"])
	var valor := padrao
	var preferencias := ConfigFile.new()
	if preferencias.load(ARQUIVO) == OK:
		var guardada := int(preferencias.get_value("atalhos", acao, padrao))
		if guardada >= KEY_A and guardada <= KEY_Z:
			valor = guardada
	_cache[acao] = valor
	return valor


## Letra da ação para a interface ("E", "F"…).
static func letra(acao: String) -> String:
	return OS.get_keycode_string(tecla(acao))


## Rótulo do AJUSTAR com a letra de fábrica entre parênteses: "Ler / interagir (E)".
static func rotulo(acao: String) -> String:
	return "%s (%s)" % [TranslationServer.translate(String(DEFINICOES[acao]["rotulo"])), OS.get_keycode_string(int(DEFINICOES[acao]["padrao"]))]


## Grava a letra da ação; se outra ação já usava a letra, herda a antiga desta (swap).
static func definir(acao: String, keycode: int) -> void:
	keycode = clampi(keycode, KEY_A, KEY_Z)
	var anterior := tecla(acao)
	var preferencias := ConfigFile.new()
	preferencias.load(ARQUIVO)
	for outra: String in DEFINICOES:
		if outra != acao and tecla(outra) == keycode:
			preferencias.set_value("atalhos", outra, anterior)
	preferencias.set_value("atalhos", acao, keycode)
	if preferencias.save(ARQUIVO) != OK:
		push_warning("Não foi possível salvar os atalhos de teclado.")
	_cache.clear()


## Refaz as ações do InputMap com as letras atuais (mv_cursor mantém o Tab fixo).
static func aplicar() -> void:
	for acao: String in ACOES_INPUT:
		var teclas: Array = [tecla(acao)]
		if acao == "camera":
			teclas.push_front(KEY_TAB)
		_registrar(String(ACOES_INPUT[acao]), teclas)


static func _registrar(nome_acao: String, teclas: Array) -> void:
	if InputMap.has_action(nome_acao):
		InputMap.action_erase_events(nome_acao)
	else:
		InputMap.add_action(nome_acao)
	for codigo: int in teclas:
		var evento := InputEventKey.new()
		evento.physical_keycode = codigo
		InputMap.action_add_event(nome_acao, evento)
