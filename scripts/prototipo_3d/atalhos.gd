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
	# A coleção de cordéis, sinais e bichos (#20); L como no 2D.
	"colecao": {"rotulo": "Coleção", "padrao": KEY_L},
	# O ALMANAQUE DAS PLANTAS, que estava no L À REVELIA DESTA TABELA.
	#
	# Ele foi escrito antes de a coleção chegar, e tomou o L emprestado
	# justamente porque o L é a coleção do 2D. Quando a coleção de verdade
	# desembarcou no vale, as duas telas ficaram na mesma letra — e a tabela,
	# que existe para que isso não aconteça, não tinha como saber: o almanaque
	# amarrava o `mv_almanaque` ao `KEY_L` na mão, sem passar por aqui.
	#
	# Passa a passar. O K é o vizinho livre do L, e o `definir()` troca as
	# duas quando alguém quiser outra coisa.
	#
	# O LUGAR CERTO DELE, a prazo, é ser a QUARTA COLEÇÃO — cordéis, sinais,
	# bichos e plantas, numa tela só. É o que o cabeçalho do `almanaque.gd` já
	# previa ("quando as plantas quiserem almanaque, a lista muda de casa").
	# Fazer isso agora seria mexer na tela que acabou de chegar, no meio de uma
	# junção; fica anotado no plano.
	"almanaque": {"rotulo": "Almanaque das plantas", "padrao": KEY_K},
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
