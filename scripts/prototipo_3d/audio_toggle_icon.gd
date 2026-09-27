extends Control
## Ícone vetorial desenhado em tempo real para o controle geral de som.

var active := true

func set_active(value: bool) -> void:
	active = value
	queue_redraw()

## Ligado fica dourado (padrão de "ativo" dos botões do canto); mudo fica claro com ×.
func _draw() -> void:
	var ink := Color("e2c47f") if active else Color(0.93, 0.96, 0.92)
	var speaker := PackedVector2Array([
		Vector2(2, 9), Vector2(6, 9), Vector2(12, 5),
		Vector2(12, 19), Vector2(6, 15), Vector2(2, 15), Vector2(2, 9)
	])
	draw_polyline(speaker, ink, 1.8, true)
	if active:
		draw_arc(Vector2(11, 12), 4, -PI / 3, PI / 3, 12, ink, 1.8, true)
		draw_arc(Vector2(11, 12), 8, -PI / 3, PI / 3, 18, ink, 1.8, true)
	else:
		draw_line(Vector2(16, 9), Vector2(22, 15), ink, 1.8, true)
		draw_line(Vector2(22, 9), Vector2(16, 15), ink, 1.8, true)
