extends Control
## OS ÍCONES DA TELA DO ARRAIAL, desenhados em vetor como os do `hud_icon.gd`.
##
## "Na tela de relacionamento com as pessoas da aldeia está faltando os
## elementos gráficos (...) O texto é para apoio e não a única forma de consulta
## da informação. Precisamos ser visuais."
##
## Desenho e não fonte: o jogo não carrega fonte de emoji, e um "♥" de fonte
## sai com a cor e o peso que a fonte quiser. Aqui cada um tem o traço do resto
## da interface, e `aceso` decide entre cheio e só contorno — que é o que faz um
## coração dizer "já tem" ou "ainda falta" sem palavra nenhuma.
##
## Tipos: "coracao", "conversa", "presente", "cadeado", "estrela", "certo" e
## "nao" (o X do que o morador não aceita).

var tipo := "coracao"
var aceso := true
var cor := Color("e0c179")


func configurar(novo_tipo: String, lado: float, nova_cor: Color, ligado: bool = true):
	tipo = novo_tipo
	cor = nova_cor
	aceso = ligado
	custom_minimum_size = Vector2(lado, lado)
	size = Vector2(lado, lado)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()
	return self


func _draw() -> void:
	var lado := minf(size.x, size.y)
	var meio := size * 0.5
	var apagada := Color(cor.r, cor.g, cor.b, 0.35)
	var traco := maxf(1.5, lado * 0.08)
	match tipo:
		"coracao":
			var pontos := _coracao(meio, lado * 0.42)
			if aceso:
				draw_colored_polygon(pontos, cor)
			else:
				draw_colored_polygon(pontos, Color(cor.r, cor.g, cor.b, 0.12))
			var fechado := pontos.duplicate()
			fechado.append(pontos[0])
			draw_polyline(fechado, cor if aceso else apagada, traco * 0.7, true)
		"conversa":
			var caixa := Rect2(meio - Vector2(lado * 0.4, lado * 0.32), Vector2(lado * 0.8, lado * 0.52))
			var rabo := PackedVector2Array([
				Vector2(caixa.position.x + lado * 0.16, caixa.end.y - 1.0),
				Vector2(caixa.position.x + lado * 0.12, caixa.end.y + lado * 0.2),
				Vector2(caixa.position.x + lado * 0.34, caixa.end.y - 1.0)])
			if aceso:
				draw_rect(caixa, cor)
				draw_colored_polygon(rabo, cor)
				for i in 3:
					draw_circle(Vector2(caixa.position.x + caixa.size.x * (0.27 + 0.23 * i), caixa.get_center().y),
						lado * 0.05, Color(0.06, 0.09, 0.08))
			else:
				draw_rect(caixa, apagada, false, traco * 0.7)
				draw_polyline(rabo, apagada, traco * 0.7)
		"presente":
			var c := cor if aceso else apagada
			var corpo := Rect2(meio + Vector2(-lado * 0.36, -lado * 0.1), Vector2(lado * 0.72, lado * 0.46))
			var tampa := Rect2(meio + Vector2(-lado * 0.42, -lado * 0.26), Vector2(lado * 0.84, lado * 0.16))
			if aceso:
				draw_rect(corpo, c)
				draw_rect(tampa, c)
				draw_line(Vector2(meio.x, tampa.position.y), Vector2(meio.x, corpo.end.y), Color(0.06, 0.09, 0.08), traco)
			else:
				draw_rect(corpo, c, false, traco * 0.7)
				draw_rect(tampa, c, false, traco * 0.7)
				draw_line(Vector2(meio.x, tampa.position.y), Vector2(meio.x, corpo.end.y), c, traco * 0.7)
			# O laço.
			draw_arc(meio + Vector2(-lado * 0.1, -lado * 0.33), lado * 0.1, 0.0, TAU, 12, c, traco * 0.7)
			draw_arc(meio + Vector2(lado * 0.1, -lado * 0.33), lado * 0.1, 0.0, TAU, 12, c, traco * 0.7)
		"cadeado":
			var c := cor if aceso else apagada
			var corpo := Rect2(meio + Vector2(-lado * 0.3, -lado * 0.04), Vector2(lado * 0.6, lado * 0.42))
			draw_rect(corpo, c)
			draw_arc(meio + Vector2(0, -lado * 0.06), lado * 0.2, PI, TAU, 16, c, traco)
			draw_line(meio + Vector2(-lado * 0.2, -lado * 0.06), meio + Vector2(-lado * 0.2, -lado * 0.02), c, traco)
			draw_line(meio + Vector2(lado * 0.2, -lado * 0.06), meio + Vector2(lado * 0.2, -lado * 0.02), c, traco)
			draw_circle(meio + Vector2(0, lado * 0.14), lado * 0.06, Color(0.06, 0.09, 0.08))
		"estrela":
			var pontos := PackedVector2Array()
			for i in 10:
				var raio := lado * (0.44 if i % 2 == 0 else 0.19)
				var angulo := -PI * 0.5 + i * PI / 5.0
				pontos.append(meio + Vector2(cos(angulo), sin(angulo)) * raio)
			if aceso:
				draw_colored_polygon(pontos, cor)
			else:
				pontos.append(pontos[0])
				draw_polyline(pontos, apagada, traco * 0.7)
		"certo":
			draw_circle(meio, lado * 0.46, cor if aceso else apagada)
			draw_polyline(PackedVector2Array([meio + Vector2(-lado * 0.22, 0.0),
				meio + Vector2(-lado * 0.05, lado * 0.17), meio + Vector2(lado * 0.24, -lado * 0.17)]),
				Color(0.06, 0.09, 0.08), traco * 1.2)
		"nao":
			draw_circle(meio, lado * 0.46, cor if aceso else apagada)
			var d := lado * 0.17
			draw_line(meio + Vector2(-d, -d), meio + Vector2(d, d), Color(0.06, 0.09, 0.08), traco * 1.2)
			draw_line(meio + Vector2(d, -d), meio + Vector2(-d, d), Color(0.06, 0.09, 0.08), traco * 1.2)


## O contorno de um coração, de cima para baixo, centrado em `centro`.
func _coracao(centro: Vector2, raio: float) -> PackedVector2Array:
	var pontos := PackedVector2Array()
	for i in 32:
		var t := TAU * i / 32.0
		# A curva clássica do coração, achatada para caber no quadrado.
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pontos.append(centro + Vector2(x, y + 2.0) * raio / 17.0)
	return pontos
