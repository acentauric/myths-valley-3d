extends Node
## Modo da janela do jogo: tela cheia ou janela.
##
## O jogo abre em tela cheia (`window/size/mode` no project.godot), sem piscar
## uma janela pequena antes. F11 alterna de qualquer tela — escolha de idioma,
## menu ou vale —, como no navegador; o botão do canto do menu faz o mesmo e
## ensina o atalho na dica. A escolha fica em `preferencias_visuais.cfg`, ao
## lado do idioma, e vale para as próximas aberturas.
##
## Em janela, o jogo ocupa FRACAO_JANELA da área útil do monitor, em 16:9: a
## resolução de desenho (1280×720) é só a referência do layout, e a janela não
## precisa ficar desse tamanho.
##
## O cursor do jogo também mora aqui. É cursor de hardware, que o sistema desenha
## mesmo quando a montagem do vale segura os quadros. O jogador escolhe o conjunto
## em AJUSTAR > Cenário; todos seguem a mesma regra: seta para apontar e mão com o
## indicador para clicar. O Clássico vem de `tools/prototipo_3d/cursor/gerar_cursor.py`;
## os demais, de `desenhos.js` pelo `gerar_cursores.js`, na mesma pasta.

signal modo_mudou(cheia: bool)

const ARQUIVO := "user://preferencias_visuais.cfg"
const FRACAO_JANELA := 0.8
## Conjuntos de cursor, na ordem do AJUSTAR: [seta, ponto quente, mão, ponto quente].
const CURSORES := [
	["res://assets/prototipo_3d/identidade/cursor_seta.png", Vector2(4, 3), "res://assets/prototipo_3d/identidade/cursor_mao.png", Vector2(16, 2)],
	["res://assets/prototipo_3d/identidade/cursores/ouro_seta.png", Vector2(4, 3), "res://assets/prototipo_3d/identidade/cursores/ouro_mao.png", Vector2(17, 2)],
	["res://assets/prototipo_3d/identidade/cursores/azulejo_seta.png", Vector2(4, 3), "res://assets/prototipo_3d/identidade/cursores/azulejo_mao.png", Vector2(17, 2)],
	["res://assets/prototipo_3d/identidade/cursores/talha_seta.png", Vector2(4, 3), "res://assets/prototipo_3d/identidade/cursores/talha_mao.png", Vector2(17, 2)],
	["res://assets/prototipo_3d/identidade/cursores/pergaminho_seta.png", Vector2(4, 3), "res://assets/prototipo_3d/identidade/cursores/pergaminho_mao.png", Vector2(17, 2)],
	["res://assets/prototipo_3d/identidade/cursores/lampiao_seta.png", Vector2(4, 3), "res://assets/prototipo_3d/identidade/cursores/lampiao_mao.png", Vector2(17, 2)],
]
const ROTULOS_CURSOR := ["Clássico", "Ouro polido", "Azulejo", "Talha com punho", "Pergaminho", "Luz do lampião"]
const PADRAO_CURSOR := 1

var cheia := true
var cursor := PADRAO_CURSOR


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cheia = preferida()
	_aplicar()
	cursor = cursor_preferido()
	_aplicar_cursor()


## A escolha salva vence; sem ela, tela cheia.
static func preferida() -> bool:
	var preferencias := ConfigFile.new()
	if preferencias.load(ARQUIVO) == OK:
		return bool(preferencias.get_value("tela", "cheia", true))
	return true


func alternar() -> void:
	definir(not cheia)


func definir(nova: bool) -> void:
	cheia = nova
	var preferencias := ConfigFile.new()
	preferencias.load(ARQUIVO)
	preferencias.set_value("tela", "cheia", nova)
	if preferencias.save(ARQUIVO) != OK:
		push_warning("Não foi possível salvar o modo da tela.")
	_aplicar()
	modo_mudou.emit(nova)


## Conjunto de cursor salvo; sem escolha, o padrão.
static func cursor_preferido() -> int:
	var preferencias := ConfigFile.new()
	if preferencias.load(ARQUIVO) == OK:
		return clampi(int(preferencias.get_value("interface", "cursor", PADRAO_CURSOR)), 0, CURSORES.size() - 1)
	return PADRAO_CURSOR


## Troca o cursor na hora e guarda a escolha para as próximas aberturas.
func definir_cursor(indice: int) -> void:
	cursor = clampi(indice, 0, CURSORES.size() - 1)
	var preferencias := ConfigFile.new()
	preferencias.load(ARQUIVO)
	preferencias.set_value("interface", "cursor", cursor)
	if preferencias.save(ARQUIVO) != OK:
		push_warning("Não foi possível salvar o cursor.")
	_aplicar_cursor()


func _aplicar_cursor() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var conjunto: Array = CURSORES[cursor]
	Input.set_custom_mouse_cursor(load(conjunto[0]), Input.CURSOR_ARROW, conjunto[1])
	Input.set_custom_mouse_cursor(load(conjunto[2]), Input.CURSOR_POINTING_HAND, conjunto[3])


## Dica dos botões: diz o que o clique faz e ensina o atalho.
func dica() -> String:
	return tr("Modo janela (F11)") if cheia else tr("Tela cheia (F11)")


# _input, e não _unhandled_input: F11 tem de valer mesmo com um botão em foco.
func _input(evento: InputEvent) -> void:
	var tecla := evento as InputEventKey
	if tecla != null and tecla.pressed and not tecla.echo and tecla.keycode == KEY_F11:
		alternar()
		get_viewport().set_input_as_handled()


func _aplicar() -> void:
	# Sem janela de verdade (testes headless) só a preferência importa.
	if DisplayServer.get_name() == "headless":
		return
	if cheia:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	# Ao sair da tela cheia o Windows devolve o estado de antes, que pode ser
	# maximizado; a janela tem de voltar ao tamanho dela.
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var tela := DisplayServer.window_get_current_screen()
	var area := DisplayServer.screen_get_usable_rect(tela)
	var largura := minf(area.size.x * FRACAO_JANELA, area.size.y * FRACAO_JANELA * 16.0 / 9.0)
	var tamanho := Vector2i(roundi(largura), roundi(largura * 9.0 / 16.0))
	DisplayServer.window_set_size(tamanho)
	DisplayServer.window_set_position(area.position + Vector2i(Vector2(area.size - tamanho) * 0.5))
