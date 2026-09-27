extends Control
## Ícones vetoriais dos botões de canto do HUD, no mesmo traço do som e do relógio:
## "casa" (HOME), "fechar" (×), "externo" (link que sai do jogo), "camera" (anel dourado quando travada), "velocidade" (setas conforme
## a Passagem do tempo, 0–3) e "estilo" (cubo para Tripo, chaves para Procedural).

var tipo := "casa"
var ativo := false
var nivel := 0

func configurar(novo_tipo: String):
	tipo = novo_tipo
	return self

func definir(novo_ativo: bool, novo_nivel: int = 0) -> void:
	ativo = novo_ativo
	nivel = novo_nivel
	queue_redraw()

func _draw() -> void:
	var tinta := Color(0.93, 0.96, 0.92)
	var ouro := Color("e2c47f")
	match tipo:
		"externo":
			# Link externo: caixa aberta no canto e seta saindo para fora.
			var ouro_link := ouro if not ativo else Color("f5e3b3")
			draw_polyline(PackedVector2Array([Vector2(11, 5), Vector2(5, 5), Vector2(5, 19), Vector2(19, 19), Vector2(19, 13)]), ouro_link, 1.8, true)
			draw_line(Vector2(11, 13), Vector2(20, 4), ouro_link, 1.8, true)
			draw_polyline(PackedVector2Array([Vector2(14, 4), Vector2(20, 4), Vector2(20, 10)]), ouro_link, 1.8, true)
		"fechar":
			draw_line(Vector2(6, 6), Vector2(18, 18), tinta, 2.0, true)
			draw_line(Vector2(18, 6), Vector2(6, 18), tinta, 2.0, true)
		"casa":
			draw_polyline(PackedVector2Array([Vector2(3, 12), Vector2(12, 4), Vector2(21, 12)]), tinta, 1.8, true)
			draw_polyline(PackedVector2Array([Vector2(6, 10), Vector2(6, 20), Vector2(18, 20), Vector2(18, 10)]), tinta, 1.8, true)
			draw_polyline(PackedVector2Array([Vector2(10, 20), Vector2(10, 15), Vector2(14, 15), Vector2(14, 20)]), tinta, 1.6, true)
		"camera":
			var cor := ouro if ativo else tinta
			draw_rect(Rect2(3, 8, 18, 12), cor, false, 1.8, true)
			draw_polyline(PackedVector2Array([Vector2(8, 8), Vector2(10, 5), Vector2(14, 5), Vector2(16, 8)]), cor, 1.6, true)
			draw_arc(Vector2(12, 14), 3.6, 0, TAU, 20, cor, 1.6, true)
		"velocidade":
			if nivel == 0:
				draw_line(Vector2(8, 6), Vector2(8, 18), tinta, 2.4, true)
				draw_line(Vector2(15, 6), Vector2(15, 18), tinta, 2.4, true)
			else:
				var largura := 5.0
				var inicio := 12.0 - largura * nivel * 0.5 - 1.0
				for indice in range(nivel):
					var x := inicio + indice * largura
					var cor := ouro if indice == nivel - 1 else tinta
					draw_polyline(PackedVector2Array([Vector2(x, 6), Vector2(x + 5, 12), Vector2(x, 18)]), cor, 2.0, true)
		"estilo":
			if ativo:
				# Tripo: cubo em perspectiva (modelos gerados).
				var topo := PackedVector2Array([Vector2(12, 3), Vector2(20, 7.5), Vector2(12, 12), Vector2(4, 7.5), Vector2(12, 3)])
				draw_polyline(topo, tinta, 1.6, true)
				draw_line(Vector2(4, 7.5), Vector2(4, 16.5), tinta, 1.6, true)
				draw_line(Vector2(20, 7.5), Vector2(20, 16.5), tinta, 1.6, true)
				draw_line(Vector2(12, 12), Vector2(12, 21), tinta, 1.6, true)
				draw_polyline(PackedVector2Array([Vector2(4, 16.5), Vector2(12, 21), Vector2(20, 16.5)]), tinta, 1.6, true)
			else:
				# Procedural: chaves de código.
				draw_polyline(PackedVector2Array([Vector2(9, 4), Vector2(6, 6), Vector2(6, 10), Vector2(3, 12), Vector2(6, 14), Vector2(6, 18), Vector2(9, 20)]), tinta, 1.8, true)
				draw_polyline(PackedVector2Array([Vector2(15, 4), Vector2(18, 6), Vector2(18, 10), Vector2(21, 12), Vector2(18, 14), Vector2(18, 18), Vector2(15, 20)]), tinta, 1.8, true)
