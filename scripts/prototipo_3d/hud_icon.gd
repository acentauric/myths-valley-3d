extends Control
## Ícones vetoriais dos botões de canto do HUD, no mesmo traço do som e do relógio:
## "casa" (HOME), "ajustes" (engrenagem), "restaurar" (seta circular), "mapa", "ajuda" (?), "tela_cheia" (cantos para fora em janela, para dentro em tela cheia), "fechar" (×), "salvar" (disquete), "editar" (lápis), "tocar" (play), "pausar", "concluir" (✓), "externo" (link que sai do jogo), "camera" (anel dourado quando travada), "velocidade" (setas conforme
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
		"restaurar":
			# Seta circular (desfazer/voltar ao padrão); apagada quando já está no padrão.
			var cor_restaurar := tinta if ativo else Color(tinta, 0.35)
			draw_arc(Vector2(12, 12.5), 6.5, deg_to_rad(-200.0), deg_to_rad(90.0), 24, cor_restaurar, 1.8, true)
			var ponta := Vector2(12, 12.5) + Vector2.from_angle(deg_to_rad(-200.0)) * 6.5
			draw_polyline(PackedVector2Array([ponta + Vector2(-1.5, -4.5), ponta, ponta + Vector2(4.5, -1.0)]), cor_restaurar, 1.8, true)
		"ajustes":
			# Engrenagem: aro, oito dentes e furo; dourada com os ajustes abertos.
			var cor_ajustes := ouro if ativo else tinta
			var centro := Vector2(12, 12)
			draw_arc(centro, 5.6, 0, TAU, 28, cor_ajustes, 1.8, true)
			draw_arc(centro, 2.2, 0, TAU, 16, cor_ajustes, 1.6, true)
			for dente in range(8):
				var direcao := Vector2.from_angle(dente * TAU / 8.0)
				draw_line(centro + direcao * 6.2, centro + direcao * 9.2, cor_ajustes, 2.6, true)
		"mapa":
			# Mapa dobrado em três faixas; dourado com o mapa aberto.
			var cor_mapa := ouro if ativo else tinta
			draw_polyline(PackedVector2Array([Vector2(3, 6), Vector2(9, 4), Vector2(15, 6), Vector2(21, 4), Vector2(21, 18), Vector2(15, 20), Vector2(9, 18), Vector2(3, 20), Vector2(3, 6)]), cor_mapa, 1.7, true)
			draw_line(Vector2(9, 4), Vector2(9, 18), cor_mapa, 1.4, true)
			draw_line(Vector2(15, 6), Vector2(15, 20), cor_mapa, 1.4, true)
		"ajuda":
			# Interrogação: gancho, haste e ponto; dourada com o painel de ajuda aberto.
			var cor_ajuda := ouro if ativo else tinta
			draw_arc(Vector2(12, 9), 4.5, PI, TAU + PI * 0.25, 16, cor_ajuda, 2.0, true)
			draw_polyline(PackedVector2Array([Vector2(15.2, 12.2), Vector2(12, 14.5), Vector2(12, 16)]), cor_ajuda, 2.0, true)
			draw_circle(Vector2(12, 19.6), 1.3, cor_ajuda)
		"tela_cheia":
			# Quatro cantos: para fora em janela (expandir); para dentro e dourados em
			# tela cheia (voltar à janela).
			var cor_tela := ouro if ativo else tinta
			for canto in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var ponta: Vector2 = Vector2(12, 12) + canto * (4.0 if ativo else 8.0)
				var dentro := 1.0 if ativo else -1.0
				draw_polyline(PackedVector2Array([ponta + Vector2(canto.x * dentro * 4.5, 0), ponta, ponta + Vector2(0, canto.y * dentro * 4.5)]), cor_tela, 1.8, true)
		"missoes":
			var cor_missoes := ouro if ativo else tinta
			draw_rect(Rect2(5, 4, 15, 17), cor_missoes, false, 1.7, true)
			draw_line(Vector2(8, 9), Vector2(17, 9), cor_missoes, 1.5, true)
			draw_line(Vector2(8, 13), Vector2(17, 13), cor_missoes, 1.5, true)
			draw_polyline(PackedVector2Array([Vector2(8, 17), Vector2(10, 19), Vector2(14, 15)]), cor_missoes, 1.6, true)
		"salvar":
			# Disquete; dourado quando há ajustes ainda não gravados.
			var cor_salvar := ouro if ativo else tinta
			draw_polyline(PackedVector2Array([Vector2(4, 4), Vector2(16, 4), Vector2(20, 8), Vector2(20, 20), Vector2(4, 20), Vector2(4, 4)]), cor_salvar, 1.7, true)
			draw_rect(Rect2(8, 4, 7, 5), cor_salvar, false, 1.5, true)
			draw_rect(Rect2(7.5, 13, 9, 7), cor_salvar, false, 1.5, true)
		"editar":
			# Lápis; dourado com a edição aberta.
			var cor_editar := ouro if ativo else tinta
			draw_polyline(PackedVector2Array([Vector2(15, 5), Vector2(19, 9), Vector2(9, 19), Vector2(5, 19), Vector2(5, 15), Vector2(15, 5)]), cor_editar, 1.7, true)
			draw_line(Vector2(12.5, 7.5), Vector2(16.5, 11.5), cor_editar, 1.5, true)
		"concluir":
			# ✓: fecha a edição.
			draw_polyline(PackedVector2Array([Vector2(5, 12.5), Vector2(10, 17.5), Vector2(19, 7)]), ouro, 2.0, true)
		"pausar":
			draw_rect(Rect2(7, 5.5, 3.5, 13), ouro if ativo else tinta, true)
			draw_rect(Rect2(13.5, 5.5, 3.5, 13), ouro if ativo else tinta, true)
		"tocar":
			# Play: o triângulo fica no centro óptico do quadro de 24.
			draw_colored_polygon(PackedVector2Array([Vector2(8.5, 5.5), Vector2(18.5, 12), Vector2(8.5, 18.5)]), ouro if ativo else tinta)
		"fechar":
			draw_line(Vector2(6, 6), Vector2(18, 18), tinta, 2.0, true)
			draw_line(Vector2(18, 6), Vector2(6, 18), tinta, 2.0, true)
		"casa":
			# Dourada quando já se está na Home (como o relógio andando).
			var cor_casa := ouro if ativo else tinta
			draw_polyline(PackedVector2Array([Vector2(3, 12), Vector2(12, 4), Vector2(21, 12)]), cor_casa, 1.8, true)
			draw_polyline(PackedVector2Array([Vector2(6, 10), Vector2(6, 20), Vector2(18, 20), Vector2(18, 10)]), cor_casa, 1.8, true)
			draw_polyline(PackedVector2Array([Vector2(10, 20), Vector2(10, 15), Vector2(14, 15), Vector2(14, 20)]), cor_casa, 1.6, true)
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
