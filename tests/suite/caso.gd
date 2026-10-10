extends RefCounted
## UM CASO DA SUÍTE DO VALE: o portão que antes abria um Godot só para ele.
##
## O portão antigo era um `extends SceneTree` rodado com `--script`: montava o
## vale do zero, conferia o que tinha de conferir e saía com `quit(falhas)`.
## Cada um custava a montagem inteira do vale, e eram 160. Agora todos rodam em
## sequência dentro de UM Godot (`tests/suite/rodar.gd`), que monta o vale uma
## vez e o empresta a cada caso.
##
## Para o portão não precisar ser reescrito, esta base imita o pedaço da
## `SceneTree` que os portões usam: `root`, `current_scene`, `process_frame`,
## `physics_frame`, `paused`, `create_timer`, os grupos, `change_scene_to_file`
## e `quit`. Converter um portão é trocar `extends SceneTree` por
## `extends "res://tests/suite/caso.gd"` e passar `arvore` (a árvore de verdade)
## onde ele passava `self` a quem espera uma `SceneTree`.
##
## O QUE MUDA PARA O CASO:
##   - `change_scene_to_file(vale)` não remonta o vale se ele já está montado no
##     mesmo estilo: devolve OK, e o caso segue com o vale emprestado. A segunda
##     chamada no mesmo caso remonta de verdade (é o portão que testa recarga).
##   - `quit(codigo)` não fecha o Godot: avisa o anfitrião que o caso acabou.
##   - O caso que precisa de um Godot novo (saves e autoloads zerados, o vale
##     recém-montado) declara `const ISOLADO := true` e roda num processo só dele.
##   - O caso que depende de um vale que ninguém tocou (a cadeia do Pedro do
##     começo) declara `const VALE_NOVO := true`: o anfitrião remonta antes dele.
##   - Teto de tempo próprio: `const TETO_S := 600`.
##   - Simulação longa (andar, nadar, passar a noite): `const ACELERAR := 4` roda o
##     tempo do jogo 4 vezes mais rápido durante o caso (`Engine.time_scale`).
##   - Depois do fim, do teto ou de um erro de script, o caso fica CONGELADO:
##     `process_frame`, `physics_frame` e `create_timer` passam a não disparar
##     nunca, e a corrotina que sobrou para ali em vez de mexer no caso seguinte.

signal caso_terminou(codigo: int)
signal _caso_nunca

## A árvore de verdade. Passe esta a quem espera uma `SceneTree` (fixtures, `Jogada`).
var arvore: SceneTree
var _caso_anfitriao: Object
var _caso_trocas := 0
var _caso_fim := false
var _caso_congelado := false
var _caso_codigo := 0
var _caso_timers: Array[SceneTreeTimer] = []

var root: Window:
	get: return arvore.root
var current_scene: Node:
	get: return arvore.current_scene
	set(valor): arvore.current_scene = valor
var process_frame: Signal:
	get: return _caso_nunca if _caso_congelado else arvore.process_frame
var physics_frame: Signal:
	get: return _caso_nunca if _caso_congelado else arvore.physics_frame
var scene_changed: Signal:
	get: return _caso_nunca if _caso_congelado else arvore.scene_changed
var paused: bool:
	get: return arvore.paused
	set(valor): arvore.paused = valor


func _initialize() -> void:
	pass


func get_root() -> Window:
	return arvore.root


func get_first_node_in_group(grupo: StringName) -> Node:
	return arvore.get_first_node_in_group(grupo)


func get_nodes_in_group(grupo: StringName) -> Array[Node]:
	return arvore.get_nodes_in_group(grupo)


func create_timer(segundos: float, sempre: bool = true, na_fisica: bool = false, ignorar_escala: bool = false) -> SceneTreeTimer:
	if _caso_congelado:
		return arvore.create_timer(1.0e9)
	var timer := arvore.create_timer(segundos, sempre, na_fisica, ignorar_escala)
	_caso_timers.append(timer)
	return timer


func create_tween() -> Tween:
	return arvore.create_tween()


func change_scene_to_file(caminho: String) -> Error:
	if _caso_congelado:
		return ERR_UNAVAILABLE
	_caso_trocas += 1
	return _caso_anfitriao.trocar_cena(caminho, _caso_trocas == 1)


func change_scene_to_packed(cena: PackedScene) -> Error:
	if _caso_congelado:
		return ERR_UNAVAILABLE
	_caso_trocas += 1
	return _caso_anfitriao.trocar_cena_empacotada(cena)


## Chamado pelo anfitrião no fim do caso: nada do que ele armou dispara depois.
## O timer de teto de um caso (`create_timer(300).timeout.connect(...)`) disparava
## dentro de outro, cinco minutos depois, e reprovava quem não tinha nada com isso.
func congelar() -> void:
	_caso_congelado = true
	for timer in _caso_timers:
		for ligacao in timer.timeout.get_connections():
			timer.timeout.disconnect(ligacao["callable"])
	_caso_timers.clear()


func quit(codigo: int = 0) -> void:
	if _caso_fim:
		return
	_caso_fim = true
	_caso_codigo = codigo
	caso_terminou.emit(codigo)
