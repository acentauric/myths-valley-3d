extends Node
## Preferências de interface do vale: as plaquinhas com o nome dos personagens e a
## mãozinha do cursor sobre todo botão.
##
## O nome é histórico: este autoload escolhia o estilo visual do vale, Tripo ou
## procedural. O procedural saiu do jogo (#58, 10/10/2026); o vale é sempre Tripo, e
## a chave `[estilo] modo` que um save antigo tenha em preferencias_visuais.cfg
## ficou órfã, sem ninguém que a leia.

## Plaquinhas com o nome dos personagens (AJUSTAR → Cenário).
signal nomes_alterados(mostrar: bool)

const ARQUIVO := "user://preferencias_visuais.cfg"

var mostrar_nomes := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var preferencias := ConfigFile.new()
	if preferencias.load(ARQUIVO) == OK:
		mostrar_nomes = bool(preferencias.get_value("interface", "nomes", true))
	get_tree().node_added.connect(_cursor_de_clique)


## Todo botão, seletor e volume do jogo mostra a mãozinha ao passar o mouse, sem cada
## tela precisar lembrar disso. Quem já escolheu outro cursor (ex.: relógio bloqueado)
## mantém o seu.
func _cursor_de_clique(no: Node) -> void:
	if (no is BaseButton or no is Slider) and (no as Control).mouse_default_cursor_shape == Control.CURSOR_ARROW:
		(no as Control).mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func definir_nomes(mostrar: bool) -> void:
	if mostrar == mostrar_nomes:
		return
	mostrar_nomes = mostrar
	var preferencias := ConfigFile.new()
	preferencias.load(ARQUIVO)
	preferencias.set_value("interface", "nomes", mostrar)
	if preferencias.save(ARQUIVO) != OK:
		push_warning("Não foi possível salvar a preferência dos nomes.")
	nomes_alterados.emit(mostrar)
