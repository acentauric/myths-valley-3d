extends RefCounted
## COMO O MOUSE GIRA A CÂMERA (AJUSTAR → Geral): livre ou arrastando.
##
## Os dois modos já existiam no `player_controller` — é o `_camera_locked` —, e
## a tecla da câmera (Tab, ou a letra escolhida em Atalhos) sempre alternou
## entre eles. O que faltava era ESCOLHER COM QUAL O JOGO ABRE, e que essa
## escolha sobrevivesse a fechar o jogo.
##
##   LIVRE     o mouse gira a câmera direto, sem apertar nada, e o cursor fica
##             preso na tela. É o de The Witcher 3, Palworld, Cyberpunk — o
##             padrão do gênero, e por isso o de fábrica aqui.
##   ARRASTAR  o cursor fica visível e a câmera só gira com o botão esquerdo
##             segurado. Serve a quem joga com o mouse também para clicar no
##             mundo, e a quem tem tontura com câmera presa.
##
## Por que isto virou ajuste agora: o Esc SOLTAVA o mouse, e quem o apertava
## procurando o menu caía no modo de arrastar sem saber por quê nem como
## voltar. O Esc virou menu (ver `Prototype._unhandled_key_input`), e o modo
## de câmera virou escolha em vez de acidente.

const ARQUIVO := "user://controles.cfg"

const LIVRE := 0
const ARRASTAR := 1

## De fábrica: livre, que é o do gênero.
const PADRAO := LIVRE
const ROTULOS := ["Livre (o mouse gira)", "Arrastar (segure o botão)"]


static func modo() -> int:
	var preferencias := ConfigFile.new()
	if preferencias.load(ARQUIVO) != OK:
		return PADRAO
	return clampi(int(preferencias.get_value("camera", "mouse", PADRAO)), LIVRE, ARRASTAR)


## Verdadeiro quando o jogo deve abrir com o cursor visível — que é o mesmo que
## o `player_controller` chama de câmera "travada".
static func travada() -> bool:
	return modo() == ARRASTAR


static func definir(novo: int) -> void:
	var preferencias := ConfigFile.new()
	preferencias.load(ARQUIVO)
	preferencias.set_value("camera", "mouse", clampi(novo, LIVRE, ARRASTAR))
	if preferencias.save(ARQUIVO) != OK:
		push_warning("Não foi possível salvar o modo de câmera do mouse.")
