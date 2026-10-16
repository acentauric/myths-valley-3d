extends GutTest
## A BASE DOS TESTES DE UNIDADE: regra, dado, cálculo e tela sem o vale, no GUT.
##
##     .\tools\prototipo_3d\testar.ps1                      # todos, num Godot, em segundos
##     .\tools\prototipo_3d\testar.ps1 -Teste regras_missoes
##
## Cada teste começa com os autoloads (e as `static` do jogo) como num Godot
## recém-aberto: a foto é tirada antes do primeiro teste do processo e
## devolvida antes de cada um (tests/suite/estado.gd). Com o perfil descartável
## que o testar.ps1 dá, o user:// também volta ao que era.
##
## `root` é a raiz da árvore, como nos portões antigos: os autoloads se pegam
## por `root.get_node("/root/Nome")`. O que um teste pendura na raiz sai no fim
## dele (`add_child_autofree`, ou `pendurar`).

const Estado := preload("res://tests/suite/estado.gd")

static var _foto_inicial := {}

var root: Window:
	get: return get_tree().root
var process_frame: Signal:
	get: return get_tree().process_frame
var physics_frame: Signal:
	get: return get_tree().physics_frame


## O `conferir` dos portões antigos: o rótulo diz o defeito, e vira a mensagem da falha.
func conferir(ok: bool, rotulo: String) -> void:
	assert_true(ok, rotulo)


func _conferir(ok: bool, rotulo: String) -> void:
	assert_true(ok, rotulo)


func before_all() -> void:
	if _foto_inicial.is_empty():
		for caminho in Estado.scripts_com_estaticas():
			load(caminho)
		_foto_inicial = Estado.fotografar(get_tree().root, Estado.perfil_descartavel())


func before_each() -> void:
	Estado.restaurar(get_tree().root, _foto_inicial)


## Põe `no` na raiz e o tira no fim do teste.
func pendurar(no: Node) -> Node:
	root.add_child(no)
	autofree(no)
	return no


## OS TESTES QUE GRAVAM NO user:// (atalhos, idioma, preferências) SÓ RODAM NO PERFIL DESCARTÁVEL (#254).
##
## O `testar.ps1` dá a cada Godot um perfil novo, e o que o teste grava morre com ele. Rodado por fora do runner (o painel do
## GUT no editor, um Godot à mão), o `user://` é o de quem joga: o teste de atalhos punha o mapa no I e só devolvia o arquivo
## no fim, e um teste interrompido no meio deixava o `controles.cfg` trocado — a plaqueta do mapa passava a dizer "I". Aqui o
## teste se recusa (fica pendente, com a razão) em vez de gravar no perfil de verdade. `tests/unidade/test_perfil_descartavel.gd`
## confere que todo teste de unidade que mexe nos atalhos chama isto.
func exige_perfil_descartavel() -> bool:
	if Estado.perfil_descartavel():
		return true
	pending("só roda no perfil descartável do testar.ps1: o user:// de verdade (%s) tem as teclas e o idioma de quem joga" % OS.get_user_data_dir())
	return false
