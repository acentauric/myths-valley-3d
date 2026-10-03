extends "res://tests/casa.gd"
## O mesmo portão de casa.gd, no estilo procedural: o jogador escolhe o estilo
## em AJUSTAR, e a casa herdada abre por dentro nos dois.

func _estilo_do_portao() -> String:
	return "procedural"
