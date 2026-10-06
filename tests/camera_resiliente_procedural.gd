extends "res://tests/camera_resiliente.gd"
## O mesmo portão de camera_resiliente.gd, no estilo procedural: a câmera nunca
## entra no personagem nas portas das construções nem debaixo d'água na orla.

func _estilo_do_portao() -> String:
	return "procedural"
