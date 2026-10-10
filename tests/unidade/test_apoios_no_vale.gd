extends "res://tests/unidade/base.gd"
## Apoios do vale: cartas de apoio e talentos ativos na mesma lista.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste apoios_no_vale


func test_apoios_no_vale() -> void:
	await process_frame
	var cartas = root.get_node("Cartas")
	var talentos = root.get_node("Talentos")
	var energia = root.get_node("Energia")
	var relogio = root.get_node("Relogio")
	var apoio := ""
	for id in cartas.tudo():
		if cartas.natureza(str(id)) == "apoio":
			apoio = str(id)
			break
	conferir(apoio != "", "existe carta real de apoio")
	cartas.sabidas.clear()
	cartas._usadas.clear()
	cartas.aprender(apoio)
	talentos.destravados = ["segundo_folego"]
	talentos._usados_hoje.clear()
	energia.atual = 20.0
	var menu = load("res://scripts/prototipo_3d/apoios_vale.gd").new()
	pendurar(menu)
	menu.abrir()
	conferir(menu.aberta and menu._entradas.size() == 2, "lista carta e talento reais")
	conferir(cartas.apoio_pronto(apoio) and talentos.ativo_pronto("segundo_folego"), "abrir não consome")
	menu.confirmar(0)
	conferir(not menu.aberta and not cartas.apoio_pronto(apoio), "confirma carta e fecha")
	menu.abrir()
	conferir(menu._botoes[0].disabled, "carta usada não é oferecida de novo")
	menu.confirmar(1)
	conferir(is_equal_approx(energia.atual, 50.0), "talento recupera trinta de fôlego")
	menu.abrir()
	if "--permitir-reuso" in OS.get_cmdline_user_args():
		talentos._usados_hoje.clear()
	menu.confirmar(1)
	conferir(is_equal_approx(energia.atual, 50.0), "não repete habilidade no mesmo dia")
	menu.fechar_tela()
	# Sinal do relógio é o caminho normal de renovação diária.
	relogio.dia_comecou.emit(2, 0, 1)
	relogio.dia += 1
	menu.abrir()
	conferir(not menu._botoes[0].disabled and not menu._botoes[1].disabled, "dia novo renova ambos")
	menu.fechar_tela()
