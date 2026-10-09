extends Node
## Estilo visual do protótipo 3D: "tripo" (modelos gerados no Tripo Studio, linha
## mestra) ou "procedural" (tudo construído por código, inclusive o personagem).
## A escolha fica em AJUSTAR e vale para o cenário inteiro; trocar reconstrói o vale.

## Plaquinhas com o nome dos personagens (AJUSTAR → Cenário).
signal nomes_alterados(mostrar: bool)

const ARQUIVO := "user://preferencias_visuais.cfg"
const TRIPO := "tripo"
const PROCEDURAL := "procedural"

var modo: String = TRIPO
var mostrar_nomes := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var preferencias := ConfigFile.new()
	if preferencias.load(ARQUIVO) == OK:
		var salvo := String(preferencias.get_value("estilo", "modo", TRIPO))
		modo = salvo if salvo in [TRIPO, PROCEDURAL] else TRIPO
		mostrar_nomes = bool(preferencias.get_value("interface", "nomes", true))
	get_tree().node_added.connect(_cursor_de_clique)


## Todo botão, seletor e volume do jogo mostra a mãozinha ao passar o mouse, sem cada
## tela precisar lembrar disso. Quem já escolheu outro cursor (ex.: relógio bloqueado)
## mantém o seu.
func _cursor_de_clique(no: Node) -> void:
	if (no is BaseButton or no is Slider) and (no as Control).mouse_default_cursor_shape == Control.CURSOR_ARROW:
		(no as Control).mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func tripo() -> bool:
	return modo == TRIPO


func procedural() -> bool:
	return modo == PROCEDURAL


func definir(novo: String) -> void:
	if novo not in [TRIPO, PROCEDURAL] or novo == modo:
		return
	modo = novo
	var preferencias := ConfigFile.new()
	preferencias.load(ARQUIVO)
	preferencias.set_value("estilo", "modo", modo)
	if preferencias.save(ARQUIVO) != OK:
		push_warning("Não foi possível salvar o estilo visual.")


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
