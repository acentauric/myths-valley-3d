extends Node
## Estilo visual do protótipo 3D: "tripo" (modelos gerados no Tripo Studio, linha
## mestra) ou "procedural" (tudo construído por código, inclusive o personagem).
## A escolha fica em AJUSTAR e vale para o cenário inteiro; trocar reconstrói o vale.

signal estilo_alterado(novo: String)

const ARQUIVO := "user://preferencias_visuais.cfg"
const TRIPO := "tripo"
const PROCEDURAL := "procedural"

var modo: String = TRIPO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var preferencias := ConfigFile.new()
	if preferencias.load(ARQUIVO) == OK:
		var salvo := String(preferencias.get_value("estilo", "modo", TRIPO))
		modo = salvo if salvo in [TRIPO, PROCEDURAL] else TRIPO


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
	estilo_alterado.emit(modo)


func rotulo() -> String:
	return "Tripo" if tripo() else "Procedural"
