extends RefCounted
## AS TECLAS DE QUEM ESCOLHE NUMA LISTA (#227): setas e W/S valem juntas, Enter vale como o E.
##
## O painel da tecla J (Oficina, Missões, Obras, Cozinha, Venda, Saveiro, Vagas, Jogo) escutava só as AÇÕES de
## movimento (`mv_forward` e as outras), e elas seguem a escolha de Ajustes → "Teclas de movimento": no padrão,
## WASD. As SETAS, o jeito natural de andar num menu, não faziam nada na Oficina — enquanto a Teia de talentos e o
## Almanaque já as aceitavam. Aqui está a regra de um lugar só, para a tela nova já nascer com ela:
##
##   ↑ ↓     escolhem na lista            (as ações do movimento, W/S no padrão, valem JUNTO delas)
##   ← →     trocam de coluna ou de aba   (A/D no padrão, onde isso já existe)
##   Enter   confirma como o E            (também o Enter do teclado numérico; o E segue remapeável no painel)
##   direcional e botão A do controle     o mesmo que as setas e o Enter
##
## As setas e o Enter são FIXOS (não passam pela tabela de atalhos de Ajustes, que não oferece nem W/A/S/D); as
## teclas de movimento remapeadas continuam valendo, e é por isso que o comando vem das duas fontes.

const CIMA := "cima"
const BAIXO := "baixo"
const ESQUERDA := "esquerda"
const DIREITA := "direita"
const CONFIRMAR := "confirmar"

## As ações de movimento, na ordem dos comandos (`teclas_movimento.gd`).
const ACOES_DO_MOVIMENTO := {
	"mv_forward": CIMA,
	"mv_back": BAIXO,
	"mv_left": ESQUERDA,
	"mv_right": DIREITA,
}


## Que comando de lista é este evento? "" se nenhum (ou se é a tecla segurada: repetir não pula linhas).
static func comando(evento: InputEvent) -> String:
	if evento is InputEventKey:
		var tecla := evento as InputEventKey
		if not tecla.pressed or tecla.echo:
			return ""
		match tecla.physical_keycode:
			KEY_UP:
				return CIMA
			KEY_DOWN:
				return BAIXO
			KEY_LEFT:
				return ESQUERDA
			KEY_RIGHT:
				return DIREITA
			KEY_ENTER, KEY_KP_ENTER:
				return CONFIRMAR
		for acao: String in ACOES_DO_MOVIMENTO:
			if InputMap.has_action(acao) and tecla.is_action_pressed(acao):
				return ACOES_DO_MOVIMENTO[acao]
	elif evento is InputEventJoypadButton:
		var botao := evento as InputEventJoypadButton
		if not botao.pressed:
			return ""
		match botao.button_index:
			JOY_BUTTON_DPAD_UP:
				return CIMA
			JOY_BUTTON_DPAD_DOWN:
				return BAIXO
			JOY_BUTTON_DPAD_LEFT:
				return ESQUERDA
			JOY_BUTTON_DPAD_RIGHT:
				return DIREITA
			JOY_BUTTON_A:
				return CONFIRMAR
	return ""
