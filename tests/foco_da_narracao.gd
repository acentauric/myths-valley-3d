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
		aviso.modulate = cor
	conferir(aviso.modulate.a == 0.0, "o aviso sob a caixa cede")
	conferir(hud._barra.modulate.a == 0.0, "a barra de mao sob a caixa cede")
	conferir(hud._heading.modulate.a == 1.0, "a missao fora da caixa permanece")
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

