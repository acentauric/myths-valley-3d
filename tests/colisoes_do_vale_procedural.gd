extends "res://tests/colisoes_do_vale.gd"
## O mesmo portão de colisoes_do_vale.gd, no estilo procedural: as paredes das casas
## e da igreja barram a câmera, a cerca não, e a câmera não salta no cruzeiro.

func _estilo_do_portao() -> String:
	return "procedural"
