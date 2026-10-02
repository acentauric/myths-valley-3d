extends "res://tools/prototipo_3d/sobrevoo/extrair_geometria.gd"
## O SOBREVOO DO MENU NAO ATRAVESSA NADA, no estilo Tripo.
##
## O menu voa um trajeto planejado offline (data/sobrevoo_menu.json, feito por
## tools/prototipo_3d/sobrevoo/planejar.py) que contorna arvores e casas pelos lados,
## a ~16 m do chao. Quem planta uma arvore ou muda uma casa de lugar perto do voo pode
## pôr um obstaculo no caminho sem perceber: a elipse antiga atravessava copas e
## telhados em 30% do ciclo e ninguem tinha medido. Este portao monta o vale de hoje,
## rasteriza os TRIANGULOS reais em volta do voo (o extrator; AABB e grossa demais: a
## do coqueiro tem 49 m de largura) e confere o trajeto gravado quadro a quadro:
## folga >= 5 m e olho a 14-18 m do chao. sobrevoo_livre_procedural.gd faz o outro estilo.

func _estilo_do_portao() -> String:
	return "tripo"


func _run() -> void:
	await _executar({"estilo": _estilo_do_portao(), "conferir": "res://data/sobrevoo_menu.json", "teto": "400"})
