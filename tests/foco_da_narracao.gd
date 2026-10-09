extends SceneTree
var falhas := 0

func _initialize() -> void:
	_run.call_deferred()

func conferir(ok: bool, mensagem: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: ", mensagem)

func _run() -> void:
	await process_frame
	var hud = load("res://scripts/prototipo_3d/prototype_hud.gd").new()
	root.add_child(hud)
	await process_frame
	var dialogo := root.get_node("Dialogo")
	# A caixa de fala é desenhada na tela do vale, 1280×720 (`Prototype._na_tela_do_vale`):
	# não é mais o quadro do 2D ampliado duas vezes.
	dialogo.transform = Transform2D.IDENTITY
	hud.set_objective("Abra a casa")
	await create_timer(0.2).timeout
	var aviso: Control = hud._notice_panel
	hud.set_notice("Aviso antes da conversa")
	var cor := aviso.modulate
	dialogo.falar("Pedro", ["Vida", "Vigor"], [], [["vida"], ["vigor"]])
	await process_frame
	await process_frame
	if "--sem-reserva" in OS.get_cmdline_user_args():
		hud._barra.modulate = cor
	# O aviso mora no canto superior esquerdo (#102): a caixa da narração fica embaixo e não o cobre.
	conferir(aviso.modulate.a == 1.0, "o aviso do canto superior não cede à caixa da narração")
	conferir(hud._barra.modulate.a == 0.0, "a barra de mao sob a caixa cede")
	conferir(hud._heading.modulate.a == 1.0, "a missao fora da caixa permanece")
	# A narração manda (#106): QUALQUER painel do grupo obstaculos_do_hud que a cobre se apaga (o do
	# testador, por exemplo), e o que está longe dela fica.
	var caixa: Rect2 = dialogo.retangulo_da_caixa()
	conferir(caixa.has_area(), "a caixa da narração aberta devia ter retângulo")
	var sobre := Control.new()
	sobre.add_to_group("obstaculos_do_hud")
	root.add_child(sobre)
	sobre.position = caixa.position + Vector2(12, 12)
	sobre.size = Vector2(120, 40)
	var longe := Control.new()
	longe.add_to_group("obstaculos_do_hud")
	root.add_child(longe)
	longe.position = Vector2(2, 2)
	longe.size = Vector2(16, 16)
	await process_frame
	await process_frame
	conferir(sobre.modulate.a == 0.0, "o painel sobre a caixa da narração não se apagou")
	conferir(longe.modulate.a == 1.0, "o painel longe da caixa se apagou sem motivo")
	var foco: Control
	for filho in hud._root.get_children():
		if filho.get_script() == load("res://scripts/prototipo_3d/foco_da_narracao.gd"):
			foco = filho
	conferir(foco._destaques.size() == 1, "vida recebe um contorno")
	conferir(foco._destaques[0].has_point(load("res://scripts/prototipo_3d/foco_da_narracao.gd").retangulo(hud.barra_vida).get_center()), "o contorno segue a barra real")
	dialogo._indice = 1
	dialogo._mostrar_fala()
	await process_frame
	await process_frame
	conferir(dialogo.interfaces_em_foco() == ["vigor"], "o foco troca com a linha")
	hud.set_notice("")
	dialogo.calar()
	await process_frame
	await process_frame
	conferir(sobre.modulate.a == 1.0, "o painel sobre a caixa não voltou ao fechar a narração")
	sobre.queue_free()
	longe.queue_free()
	conferir(aviso.modulate == cor, "a cor original volta")
	conferir(not aviso.visible, "aviso expirado nao reaparece")
	conferir(hud._barra.modulate.a == 1.0, "a mao volta apos a fala")
	conferir(foco._destaques.is_empty(), "o destaque termina com a fala")
	var dados = JSON.parse_string(FileAccess.get_file_as_string("res://data/missoes_guia.json"))
	for linha: Dictionary in dados.corpo:
		conferir(not linha.get("interfaces", []).is_empty(), "cada linha do tutorial declara seu foco")
	hud.queue_free()
	await process_frame
	print("Foco da narracao: %d falhas" % falhas)
	quit(1 if falhas else 0)

