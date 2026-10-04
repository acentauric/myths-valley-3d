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
## O cursor do jogo também mora aqui: seta e mão em ouro com contorno de laca
## (`tools/prototipo_3d/cursor/gerar_cursor.py`). É cursor de hardware, que o
## sistema desenha mesmo quando a montagem do vale segura os quadros.

signal modo_mudou(cheia: bool)

const ARQUIVO := "user://preferencias_visuais.cfg"
const FRACAO_JANELA := 0.8
const CURSORES := [
	[Input.CURSOR_ARROW, "res://assets/prototipo_3d/identidade/cursor_seta.png", Vector2(4, 3)],
	[Input.CURSOR_POINTING_HAND, "res://assets/prototipo_3d/identidade/cursor_mao.png", Vector2(16, 2)],
]

var cheia := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cheia = preferida()
	_aplicar()
	if DisplayServer.get_name() != "headless":
		for cursor in CURSORES:
			Input.set_custom_mouse_cursor(load(cursor[1]), cursor[0], cursor[2])


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
