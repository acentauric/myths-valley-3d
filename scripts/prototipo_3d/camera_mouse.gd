extends RefCounted
## Três modos (AJUSTAR → Geral): livre, arrastar e automático. C cicla.
##
## Os dois modos originais usam `_camera_locked`. A câmera automática
## compartilha o cursor visível; C (remapeável) percorre os três modos.
## A preferência sobrevive ao fechamento do jogo.
##
##   LIVRE     o mouse gira a câmera direto, sem apertar nada, e o cursor fica
##             preso na tela. É o de The Witcher 3, Palworld, Cyberpunk — o
##             padrão do gênero, e por isso o de fábrica aqui.
##   ARRASTAR  o cursor fica visível e a câmera só gira com o botão esquerdo
##             segurado. Serve a quem joga com o mouse também para clicar no
##             mundo, e a quem tem tontura com câmera presa.
##   AUTOMÁTICA acompanha a direção percorrida e sonda desvios laterais quando
##             o enquadramento está bloqueado. Cursor visível, clique preservado.
##
## Por que isto virou ajuste agora: o Esc SOLTAVA o mouse, e quem o apertava
## procurando o menu caía no modo de arrastar sem saber por quê nem como
## voltar. O Esc virou menu (ver `Prototype._unhandled_key_input`), e o modo
## de câmera virou escolha em vez de acidente.

const ARQUIVO := "user://controles.cfg"

const LIVRE := 0
const ARRASTAR := 1
const AUTOMATICA := 2

## De fábrica: livre, que é o do gênero.
const PADRAO := LIVRE
static func rotulos() -> Array:
	var idioma = load("res://scripts/prototipo_3d/idioma_menu.gd")
	var textos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/camera_modos.json"))
	var resultado: Array = []
	for campo in ["livre", "arrastar", "automatica"]:
		resultado.append(idioma.campo(textos, campo))
	return resultado


static func rotulo() -> String:
	return str(rotulos()[modo()])


static func modo() -> int:
	var preferencias := ConfigFile.new()
	if preferencias.load(ARQUIVO) != OK:
		return PADRAO
	return clampi(int(preferencias.get_value("camera", "mouse", PADRAO)), LIVRE, AUTOMATICA)


## Verdadeiro quando o jogo deve abrir com o cursor visível — que é o mesmo que
## o `player_controller` chama de câmera "travada".
static func travada() -> bool:
	return modo() != LIVRE


static func definir(novo: int) -> void:
	var preferencias := ConfigFile.new()
	preferencias.load(ARQUIVO)
	preferencias.set_value("camera", "mouse", clampi(novo, LIVRE, AUTOMATICA))
	if preferencias.save(ARQUIVO) != OK:
		push_warning("Não foi possível salvar o modo de câmera do mouse.")
