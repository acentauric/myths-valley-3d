extends Control
## Ícone vetorial de relógio: os ponteiros mostram a hora do vale (autoload Dia).
## Com o dia correndo, o mostrador ganha um anel dourado; pausado, fica claro.

var running := false

func _ready() -> void:
	Dia.hora_mudou.connect(func(_hora: float) -> void: queue_redraw())

func set_running(value: bool) -> void:
	running = value
	queue_redraw()

func _draw() -> void:
	var ink := Color(0.93, 0.96, 0.92)
	var center := size * 0.5
	var raio := minf(size.x, size.y) * 0.5 - 1.0
	draw_arc(center, raio, 0, TAU, 40, Color("e2c47f") if running else ink, 2.0, true)
	# Marcas de 12, 3, 6 e 9 para o mostrador ler como relógio em qualquer hora.
	for quarto in range(4):
		var direcao := Vector2(sin(quarto * PI * 0.5), -cos(quarto * PI * 0.5))
		draw_line(center + direcao * (raio - 3.2), center + direcao * (raio - 1.2), ink, 1.5, true)
	var hora := Dia.hora
	var minutos := (hora - floorf(hora)) * TAU
	var horas := fmod(hora, 12.0) / 12.0 * TAU
	draw_line(center, center + Vector2(sin(horas), -cos(horas)) * raio * 0.5, ink, 2.2, true)
	draw_line(center, center + Vector2(sin(minutos), -cos(minutos)) * raio * 0.75, ink, 1.6, true)
	draw_circle(center, 1.6, ink)
