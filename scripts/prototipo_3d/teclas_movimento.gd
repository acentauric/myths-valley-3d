extends RefCounted
## Teclas que movem o personagem (AJUSTAR → Geral): só WASD, só as setas ou os dois.
## A escolha fica salva e é aplicada no InputMap ao entrar no vale; o rodapé do HUD e
## os avisos usam `rotulo()` para mostrar as teclas que realmente funcionam.

const ARQUIVO := "user://controles.cfg"
const WASD := 0
const SETAS := 1
const AMBOS := 2
## Modo de fábrica (AJUSTAR → restaurar padrão).
const PADRAO := WASD
const ROTULOS := ["WASD", "Setas", "WASD e setas"]
const ACOES := {
	"mv_forward": [KEY_W, KEY_UP],
	"mv_back": [KEY_S, KEY_DOWN],
	"mv_left": [KEY_A, KEY_LEFT],
	"mv_right": [KEY_D, KEY_RIGHT],
}


static func modo() -> int:
	var preferencias := ConfigFile.new()
	if preferencias.load(ARQUIVO) != OK:
		return PADRAO
	return clampi(int(preferencias.get_value("movimento", "teclas", PADRAO)), WASD, AMBOS)


static func definir(novo: int) -> void:
	var preferencias := ConfigFile.new()
	preferencias.load(ARQUIVO)
	preferencias.set_value("movimento", "teclas", clampi(novo, WASD, AMBOS))
	if preferencias.save(ARQUIVO) != OK:
		push_warning("Não foi possível salvar as teclas de movimento.")
	aplicar()


## Refaz as quatro ações de movimento com as teclas do modo escolhido.
static func aplicar() -> void:
	var atual := modo()
	for acao: String in ACOES:
		if InputMap.has_action(acao):
			InputMap.action_erase_events(acao)
		else:
			InputMap.add_action(acao)
		var teclas: Array = ACOES[acao]
		if atual != SETAS:
			_adicionar(acao, teclas[0])
		if atual != WASD:
			_adicionar(acao, teclas[1])


## Texto curto das teclas ativas, para o rodapé do HUD ("WASD", "Setas", "WASD/setas").
static func rotulo() -> String:
	return ["WASD", "Setas", "WASD/setas"][modo()]


static func _adicionar(acao: String, tecla: int) -> void:
	var evento := InputEventKey.new()
	evento.physical_keycode = tecla
	InputMap.action_add_event(acao, evento)
