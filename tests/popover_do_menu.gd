extends "res://tests/suite/caso.gd"
## O POPOVER DOS BOTÕES DA ESQUERDA DO LOBBY (#232): uma caixa compacta com seta no lugar do tooltip em linha.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste popover_do_menu
##
## Seis perguntas:
##
##   1. O COMPONENTE, SOZINHO: com o mouse em cima do botão o popover aparece depois do atraso, com fade, À DIREITA do
##      botão, alinhado ao centro dele, com largura máxima, dentro da tela; sai com fade quando o mouse sai.
##   2. O FOCO: o foco do teclado também o abre — mas só se a última entrada foi de teclado (o foco que o lobby põe em
##      JOGAR sozinho, ou que o mouse puxa para o botão, não deixa o popover preso); e a seta aponta para o botão.
##   3. NÃO SAI DA TELA: um botão encostado na borda direita vira o popover para a esquerda; o texto longo quebra em
##      várias linhas, e não numa linha de meia tela; o popover se libera com o botão.
##   4. NO LOBBY: JOGAR, EXPLORAR, TESTAR, MODELOS, SOBRE e SAIR têm popover e nenhum tooltip padrão; cada popover fica
##      ao lado da coluna, sem cobrir os outros cinco botões; o texto da versão no rodapé não ganha nada.
##   5. OS TEXTOS estão em pt, en, es e zh, e nenhum é cópia do português.
##   6. O HUD DA DIREITA continua com a dica de sempre (o `botao_canto.gd` não foi tocado).

const ATRASO_FADE_S := 2.5

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: ", rotulo)


func _run() -> void:
	# load() dentro do _run e não preload: o menu usa autoloads, que só existem depois do _initialize.
	var Popover: GDScript = load("res://scripts/prototipo_3d/popover_menu.gd")
	var Abertura: GDScript = load("res://scripts/prototipo_3d/abertura.gd")
	var IdiomaMenu: GDScript = load("res://scripts/prototipo_3d/idioma_menu.gd")
	IdiomaMenu.definir(0)

	# --- 1 a 3. O COMPONENTE, SOZINHO ----------------------------------------------------------------------
	var camada := CanvasLayer.new()
	root.add_child(camada)
	var tela := root.get_visible_rect().size
	var botao := Button.new()
	botao.text = "JOGAR"
	botao.position = Vector2(36, 200)
	botao.size = Vector2(300, 44)
	camada.add_child(botao)
	var longo := "O testador automático joga numa janela separada, e esta fecha quando ela abrir. F7 assume o controle; F8 encerra e volta ao menu."
	var popover: Control = Popover.ligar(botao, longo, camada)
	await process_frame
	await process_frame
	_conferir(not popover.visible and popover.alfa == 0.0, "o popover apareceu sem ninguém pedir")
	botao.mouse_entered.emit()
	await process_frame
	await process_frame
	_conferir(popover.alfa < 1.0, "o popover apareceu de uma vez, sem atraso nem fade")
	var apareceu := await _ate(func() -> bool: return popover.alfa >= 0.99, ATRASO_FADE_S)
	_conferir(apareceu, "com o mouse em cima o popover não apareceu")
	await process_frame
	await process_frame
	var caixa: Rect2 = popover.retangulo()
	var rect_botao := botao.get_global_rect()
	_conferir(caixa.size != Vector2.ZERO, "o popover visível não tem retângulo")
	_conferir(popover.lado_atual == Popover.Lado.DIREITA, "o popover devia ficar à direita do botão")
	_conferir(caixa.position.x >= rect_botao.end.x, "a caixa não está à direita do botão (cobre ele): %s / %s" % [caixa, rect_botao])
	_conferir(absf(caixa.get_center().y - rect_botao.get_center().y) <= 2.0, "a caixa não está alinhada ao centro do botão: %s / %s" % [caixa, rect_botao])
	_conferir(caixa.size.x <= Popover.LARGURA_MAX + 30.0, "a caixa passa da largura máxima: %.0f px" % caixa.size.x)
	_conferir(popover._texto.get_line_count() >= 2, "o texto longo não quebrou em várias linhas (%d)" % popover._texto.get_line_count())
	_conferir(Rect2(Vector2.ZERO, tela).encloses(caixa), "a caixa saiu da tela: %s" % caixa)
	_conferir(popover.texto_atual() == longo, "o popover não traz o texto pedido")
	# A seta: a ponta fica junto do botão (à esquerda da caixa) e a base na aresta da caixa.
	var ponta: Vector2 = popover.position + popover._ponta
	_conferir(ponta.x < caixa.position.x and ponta.x >= rect_botao.end.x - 1.0, "a ponta da seta não aponta para o botão: %s" % ponta)
	_conferir(absf(ponta.y - rect_botao.get_center().y) <= 2.0, "a seta não aponta para o centro do botão: %s" % ponta)
	# Sai do botão: some com fade.
	botao.mouse_exited.emit()
	var sumiu := await _ate(func() -> bool: return popover.alfa <= 0.01 and not popover.visible, ATRASO_FADE_S)
	_conferir(sumiu, "o popover não sumiu quando o mouse saiu")

	# O foco sem teclado (o foco que o lobby põe sozinho) não abre; com teclado, abre.
	var movimento := InputEventMouseMotion.new()
	popover._input(movimento)
	botao.focus_entered.emit()
	await _ate(func() -> bool: return false, 0.8)
	_conferir(popover.alfa <= 0.01, "o foco sem teclado deixou o popover preso na tela")
	var tecla := InputEventKey.new()
	tecla.keycode = KEY_DOWN
	tecla.pressed = true
	popover._input(tecla)
	var por_teclado := await _ate(func() -> bool: return popover.alfa >= 0.99, ATRASO_FADE_S)
	_conferir(por_teclado, "o foco do teclado não abriu o popover")
	botao.focus_exited.emit()
	var saiu_foco := await _ate(func() -> bool: return popover.alfa <= 0.01, ATRASO_FADE_S)
	_conferir(saiu_foco, "o popover não saiu quando o foco passou para outro botão")
	popover._input(movimento)

	# Encostado na borda direita da tela: vira para a esquerda, sem sair dela.
	botao.position = Vector2(tela.x - 340.0, 200)
	botao.mouse_entered.emit()
	await _ate(func() -> bool: return popover.alfa >= 0.99, ATRASO_FADE_S)
	await process_frame
	caixa = popover.retangulo()
	_conferir(popover.lado_atual == Popover.Lado.ESQUERDA, "no canto direito da tela o popover devia virar para a esquerda")
	_conferir(caixa.end.x <= botao.get_global_rect().position.x and Rect2(Vector2.ZERO, tela).encloses(caixa), "o popover do canto direito saiu da tela ou cobre o botão: %s" % caixa)
	botao.mouse_exited.emit()
	# Libera junto com o botão.
	var id := popover.get_instance_id()
	botao.free()
	await process_frame
	await process_frame
	_conferir(instance_from_id(id) == null, "o popover ficou na tela depois que o botão se foi")
	camada.free()

	# --- 5. OS TEXTOS ---------------------------------------------------------------------------------------
	var dicas: Dictionary = Abertura.DICAS_DAS_PLACAS
	_conferir(dicas.size() == 7, "são seis botões (e o aviso do Testar indisponível): %d textos" % dicas.size())
	var ingles: Dictionary = IdiomaMenu.EN
	var espanhol: Dictionary = IdiomaMenu.ES
	var selecao: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/selecao_idioma.json"))
	var chines: Dictionary = selecao.get("menu_zh", {})
	for chave: String in dicas:
		var texto: String = dicas[chave]
		_conferir(texto != "" and ingles.has(texto) and espanhol.has(texto) and chines.has(texto), "o texto do popover de %s falta em algum idioma (pt/en/es/zh)" % chave)
		_conferir(ingles.get(texto, "") != texto and espanhol.get(texto, "") != texto, "o texto do popover de %s é cópia do português" % chave)
		_conferir(texto.length() <= 140, "o texto do popover de %s não é curto (%d letras)" % [chave, texto.length()])
	var testar: String = dicas["TESTAR"]
	_conferir(testar.contains("F7") and testar.contains("F8"), "o popover do Testar devia dizer que F7 assume o controle e F8 encerra")

	# --- 4 e 6. NO LOBBY -----------------------------------------------------------------------------------
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/abertura.tscn") == OK, "a abertura carrega")
	await process_frame
	await process_frame
	await process_frame
	var abertura := current_scene
	_conferir(abertura != null and abertura.get("content") != null, "a abertura não montou o menu")
	if abertura == null or abertura.get("content") == null:
		_fechar()
		return
	abertura.call("_aplicar_entrada_final")
	abertura.call("_home")
	await process_frame
	await process_frame
	var placas: Array[Button] = []
	for filho in abertura.content.get_children():
		if filho is Button and (filho as Button).theme_type_variation in [&"BotaoCronica", &"BotaoCronicaNegativo"]:
			placas.append(filho)
	_conferir(placas.size() == 6, "a coluna da esquerda devia ter seis botões e tem %d" % placas.size())
	var camada_do_menu: Node = abertura.panel.get_parent()
	var popovers: Array = camada_do_menu.get_children().filter(func(no: Node) -> bool: return no.get_script() == Popover)
	_conferir(popovers.size() == 6, "devia haver um popover por botão da esquerda (6) e há %d" % popovers.size())
	for placa in placas:
		_conferir(placa.tooltip_text == "", "o botão %s ainda tem o tooltip em linha" % placa.text)
	_conferir(abertura.version_link != null and abertura.version_link.tooltip_text == "", "o texto da versão no rodapé ganhou tooltip")
	for i in placas.size():
		var placa: Button = placas[i]
		var alvo: Control = popovers[i]
		placa.mouse_entered.emit()
		var abriu := await _ate(func() -> bool: return alvo.alfa >= 0.99, ATRASO_FADE_S)
		await process_frame
		await process_frame
		_conferir(abriu, "o popover de %s não abriu com o mouse" % placa.text)
		var c: Rect2 = alvo.retangulo()
		_conferir(c.size != Vector2.ZERO and c.position.x >= placa.get_global_rect().end.x, "o popover de %s não fica ao lado direito da coluna: %s" % [placa.text, c])
		_conferir(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(c), "o popover de %s saiu da tela: %s" % [placa.text, c])
		_conferir(c.size.x <= Popover.LARGURA_MAX + 30.0 and c.size.y <= 130.0, "o popover de %s não é compacto: %s" % [placa.text, c.size])
		for outra in placas:
			_conferir(not c.intersects(outra.get_global_rect()), "o popover de %s cobre o botão %s" % [placa.text, outra.text])
		placa.mouse_exited.emit()
		await _ate(func() -> bool: return alvo.alfa <= 0.01, ATRASO_FADE_S)
	# O texto aparece traduzido em cada idioma (o popover traduz na hora).
	var jogar: Button = placas[0]
	var primeiro: Control = popovers[0]
	for idioma in [1, 2, 3]:
		IdiomaMenu.definir(idioma)
		jogar.mouse_entered.emit()
		await _ate(func() -> bool: return primeiro.alfa >= 0.99, ATRASO_FADE_S)
		_conferir(primeiro.texto_atual() != Abertura.DICAS_DAS_PLACAS["JOGAR"] and primeiro.texto_atual() != "", "o popover de JOGAR não foi traduzido (idioma %d): '%s'" % [idioma, primeiro.texto_atual()])
		jogar.mouse_exited.emit()
		await _ate(func() -> bool: return primeiro.alfa <= 0.01, ATRASO_FADE_S)
	IdiomaMenu.definir(0)
	# O HUD da direita mantém a dica de sempre (botao_canto.gd): HOME acende a sua com o mouse e a apaga ao sair.
	_conferir(get_nodes_in_group("botoes_canto").size() >= 5, "o HUD da direita perdeu botões do canto")
	var rotulo_home: Label = null
	for rotulo: Label in camada_do_menu.find_children("*", "Label", true, false):
		if rotulo.text == "Home":
			rotulo_home = rotulo
	_conferir(rotulo_home != null, "o botão HOME perdeu a dica")
	if rotulo_home != null:
		abertura.home_corner.mouse_entered.emit()
		_conferir(rotulo_home.get_parent().visible, "a dica do HOME não acende com o mouse")
		abertura.home_corner.mouse_exited.emit()
		_conferir(not rotulo_home.get_parent().visible, "a dica do HOME não apaga ao sair")
	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("POPOVER_DO_MENU_OK: o popover aparece com atraso e fade ao lado direito do botão, alinhado ao centro, com seta, compacto e dentro da tela; abre com o mouse e com o teclado (e não prende o foco do mouse), vira para a esquerda na borda, libera com o botão; os seis botões do lobby têm popover em pt, en, es e zh, sem tooltip em linha e sem cobrir uns aos outros; a versão do rodapé fica sem nada")
	else:
		print("popover_do_menu: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicao.call():
			return true
		await process_frame
	return condicao.call()
