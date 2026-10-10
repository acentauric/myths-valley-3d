extends "res://tests/suite/caso.gd"
## O botão de FPS não deve deixar uma dica gigante presa à coluna direita: abre um
## painel acima do minimapa, com todas as medições, e o recolhe junto com mapa e
## controles. Este portão também protege o encaixe quando a janela muda de tamanho.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, motivo: String) -> void:
	if not ok:
		print("FALHA: ", motivo)
		falhas += 1


func _run() -> void:
	var hud = load("res://scripts/prototipo_3d/prototype_hud.gd").new()
	root.add_child(hud)
	await process_frame
	var painel: Panel = hud._performance_panel
	var botao: Button = hud._performance_button
	_conferir(painel != null and botao != null, "faltam o painel ou o botão de FPS")
	if painel == null or botao == null:
		quit(1)
		return
	_conferir(not painel.visible, "o painel começa aberto")
	# O BOTÃO MOSTRA O NÚMERO. Ele levava o ícone de estilo, que no procedural
	# é um par de chaves, e quem jogou viu "{}" no lugar do FPS.
	hud._update_telemetry()
	var no_botao: Label = hud._fps_label
	_conferir(no_botao != null and no_botao.is_inside_tree(), "o botão de FPS não tem o número escrito")
	if no_botao != null:
		_conferir(no_botao.text.is_valid_int(), "o botão de FPS mostra '%s', e não um número" % no_botao.text)
	await _o_botao_fica_no_canto(hud, botao, no_botao)
	hud.set_model_status("Estilo Tripo: modelos do Tripo Studio (personagem GLB provisório)")
	hud.set_telemetry("Tripo · 1,78 m")
	botao.pressed.emit()
	await process_frame
	var texto: String = hud._performance_label.text
	_conferir(painel.visible, "o clique não abre o painel")
	for trecho in ["FPS", "Tripo · 1,78 m", "Estilo Tripo:", "tri", "draws", "MB VRAM"]:
		_conferir(texto.contains(trecho), "o painel perdeu %s" % trecho)
	_conferir(is_equal_approx(painel.position.x, 14.0), "o painel não alinha com o minimapa")
	_conferir(is_equal_approx(painel.position.y + painel.size.y, hud._root.size.y - hud.Minimapa.MARGEM - hud.Minimapa.ALTURA - 8.0),
		"o painel não está acima do minimapa")
	_conferir(hud._performance_label.get_line_count() * hud._performance_label.get_line_height() <= painel.size.y - 14.0,
		"o texto não cabe no painel compacto")
	root.size = Vector2i(1024, 576)
	await process_frame
	_conferir(is_equal_approx(painel.position.y + painel.size.y, hud._root.size.y - hud.Minimapa.MARGEM - hud.Minimapa.ALTURA - 8.0),
		"o painel não acompanha uma janela menor")
	hud.set_controls_open(true)
	_conferir(not painel.visible, "o painel cobre os controles")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://scratch/controles")
		root.get_texture().get_image().save_png("res://scratch/controles/modal.png")
	hud.set_controls_open(false)
	_conferir(painel.visible, "o painel não retorna depois dos controles")
	hud.set_map_open(true)
	_conferir(not painel.visible, "o painel cobre o mapa")
	hud.set_map_open(false)
	_conferir(painel.visible, "o painel não retorna depois do mapa")
	botao.pressed.emit()
	_conferir(not painel.visible, "o segundo clique não fecha o painel")
	print("HUD_DESEMPENHO_OK" if falhas == 0 else "hud_desempenho: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


## O BOTÃO FICA NA TELA, NO ALTO DO CANTO DIREITO, EM QUALQUER TAMANHO DO HUD.
##
## Ele é o único botão que sobrou no canto do vale, e nasce pelo `BotaoCanto`,
## que desde o "Tamanho do HUD" do AJUSTAR recebe a posição na coluna, e não os
## pixels do topo. Quando as duas mudanças se encontraram na mesma branch, o
## botão ainda passava 32.0: lido como posição, ia parar 1.600 px abaixo, fora
## da janela. Este portão passava, porque só perguntava se o botão existia.
##
## O perfil é o isolado do runner: trocar o tamanho grava a preferência, e ela
## volta ao que era no fim.
func _o_botao_fica_no_canto(hud: Node, botao: Button, numero: Label) -> void:
	var tela := root.get_node_or_null("/root/Tela")
	_conferir(tela != null, "não achei o autoload Tela, que guarda o tamanho do HUD")
	if tela == null:
		return
	var antes: int = tela.tamanho_hud
	for tamanho in tela.ESCALAS_HUD.size():
		tela.definir_tamanho_hud(tamanho)
		await process_frame
		await process_frame
		var nome := str(tela.ROTULOS_TAMANHO[tamanho])
		var janela: Rect2 = hud._root.get_global_rect()
		var quadro := botao.get_global_rect()
		_conferir(janela.encloses(quadro),
			"no HUD %s o botão de FPS fica fora da janela: %s numa tela de %s" % [nome, str(quadro), str(janela.size)])
		_conferir(quadro.position.y < janela.size.y * 0.25 and quadro.end.x > janela.size.x * 0.75,
			"no HUD %s o botão de FPS não está no alto do canto direito: %s" % [nome, str(quadro)])
		if numero == null:
			continue
		# O número usa o botão todo, e não o quadrado do ícone: "144" tem de caber.
		_conferir(numero.get_global_rect().is_equal_approx(quadro),
			"no HUD %s o número ocupa %s, e não o botão todo (%s)" % [nome, str(numero.get_global_rect()), str(quadro)])
		_conferir(numero.get_global_transform().get_scale().is_equal_approx(Vector2.ONE),
			"no HUD %s o número foi encolhido como se fosse ícone: escala %s" % [nome, str(numero.get_global_transform().get_scale())])
		var largura := numero.get_theme_font("font").get_string_size("144", HORIZONTAL_ALIGNMENT_LEFT, -1, numero.get_theme_font_size("font_size")).x
		_conferir(largura <= quadro.size.x,
			"no HUD %s '144' tem %.1f px e o botão, %.1f: o número corta" % [nome, largura, quadro.size.x])
	tela.definir_tamanho_hud(antes)
	await process_frame
