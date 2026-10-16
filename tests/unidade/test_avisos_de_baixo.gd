extends "res://tests/unidade/base.gd"
## OS AVISOS DE BAIXO: UMA LINHA É UMA LINHA, E TODOS TÊM O MESMO ESTILO (#249).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste avisos_de_baixo
##
## Visto na Build 11, ao parar de correr à noite perto da ponte: o aviso "Modo corrida desativado ao parar" saía numa
## caixa com uma linha em branco embaixo, em serifada, enquanto "Pedro voltou para te buscar: siga com ele." saía numa
## caixa de uma linha na sans do HUD. Duas causas, duas perguntas:
##
##   1. A ALTURA ACOMPANHA AS LINHAS. O aviso muda a largura do painel para caber o texto novo, mas o rótulo só recebe a
##      largura nova no quadro seguinte: medida com a largura velha, a frase mais longa ("desativado ao parar", depois
##      de "ativado") contava duas linhas, e a caixa guardava essa altura para sempre. Em toda ordem, a frase que cabe
##      numa linha tem uma caixa de UMA linha mais as margens — sem sobra.
##   2. O ESTILO É UM SÓ. O aviso do alto da pilha (o modo corrida, o que se recebeu) e o aviso de espera, o de "Pedro
##      voltou", usam a mesma fonte, o mesmo tamanho, as mesmas margens e a mesma caixa; os recados de baixo (a recusa e
##      o "✓ tarefa") também. O de "Pedro voltou" é a referência.
##
## A medida é do HUD sozinho, sem o vale. O quadro da tela inteira, com a barra de mão e o minimapa, é `avisos_em_linhas`.

const CURTA := "Modo corrida ativado"
const LONGA := "Modo corrida desativado ao parar"
const MUITO_LONGA := "Pedro: Chegamos. Daqui da cerca para dentro é seu. A chave tá com você: abre a porta e entra. Eu fico aqui fora, que dentro é seu."

var _janela_de_antes := Vector2i.ZERO


func before_each() -> void:
	super()
	_janela_de_antes = root.size


func after_each() -> void:
	root.size = _janela_de_antes


func _hud() -> Node:
	var hud: Node = load("res://scripts/prototipo_3d/prototype_hud.gd").new()
	pendurar(hud)
	return hud


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


## A altura que o texto de agora pede ao aviso: as linhas do rótulo (com o espaço entre elas) e as margens da caixa.
func _altura_pedida(hud: Node) -> float:
	var caixa: StyleBox = hud._notice_panel.get_theme_stylebox("panel")
	return float(hud._text_height(hud._notice_label)) + caixa.get_minimum_size().y


func test_uma_linha_e_uma_linha_em_qualquer_ordem() -> void:
	var ordens := [
		["curta e depois longa", [CURTA, LONGA]],
		["longa e depois curta", [LONGA, CURTA]],
		["curta, o aviso some, longa", [CURTA, "", LONGA]],
		["a fala comprida e depois a curta", [MUITO_LONGA, CURTA, LONGA]],
		["curta, comprida, curta", [CURTA, MUITO_LONGA, CURTA]],
	]
	for tamanho: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = tamanho
		var hud := _hud()
		await _quadros(2)
		for ordem: Array in ordens:
			hud.set_notice("")
			await _quadros(2)
			for texto: String in ordem[1]:
				hud.set_notice(texto)
				await _quadros(4)
				if texto == "":
					continue
				var rotulo := "%dx%d, %s, '%s'" % [tamanho.x, tamanho.y, ordem[0], texto.left(24)]
				var linhas: int = hud._notice_label.get_line_count()
				if texto != MUITO_LONGA:
					_conferir(linhas == 1, "%s: a frase que cabe numa linha contou %d" % [rotulo, linhas])
				else:
					_conferir(linhas >= 2, "%s: a fala comprida devia quebrar em linhas, e tem %d" % [rotulo, linhas])
				var pedida := _altura_pedida(hud)
				var altura: float = hud._notice_panel.size.y
				_conferir(absf(altura - pedida) <= 1.0,
					"%s: a caixa tem %.1f px de altura, e %d linha(s) pedem %.1f (%.1f px de sobra em branco)" % [rotulo, altura, linhas, pedida, altura - pedida])
				var caixa: Rect2 = hud._retangulo_em_tela(hud._notice_panel)
				_conferir(hud._root.get_global_rect().encloses(caixa), "%s: a caixa (%s) sai da tela" % [rotulo, str(caixa)])
		hud.queue_free()
		await process_frame


func test_o_aviso_curto_nao_herda_a_altura_do_longo() -> void:
	# O caso do autor, à letra: a caixa do "desativado ao parar" é de uma linha, mesmo vindo do "ativado".
	var hud := _hud()
	await _quadros(2)
	hud.set_notice(CURTA)
	await _quadros(4)
	var da_curta: float = hud._notice_panel.size.y
	hud.set_notice(LONGA)
	await _quadros(4)
	_conferir(absf(float(hud._notice_panel.size.y) - da_curta) <= 1.0,
		"a caixa de '%s' tem %.1f px, e a de '%s' tinha %.1f: as duas são de uma linha" % [LONGA, hud._notice_panel.size.y, CURTA, da_curta])
	# Dentro da caixa o texto está onde as margens o põem: a sobra de cima e a de baixo são as margens, e nada mais.
	var caixa_do_painel: StyleBox = hud._notice_panel.get_theme_stylebox("panel")
	var rotulo: Rect2 = hud._notice_label.get_global_rect()
	var caixa: Rect2 = hud._notice_panel.get_global_rect()
	_conferir(absf((rotulo.position.y - caixa.position.y) - caixa_do_painel.get_margin(SIDE_TOP)) <= 1.0,
		"o texto começa a %.1f px do alto da caixa, e a margem é %.1f" % [rotulo.position.y - caixa.position.y, caixa_do_painel.get_margin(SIDE_TOP)])
	_conferir(absf((caixa.end.y - rotulo.end.y) - caixa_do_painel.get_margin(SIDE_BOTTOM)) <= 1.0,
		"sobram %.1f px embaixo do texto, e a margem é %.1f: é a linha em branco" % [caixa.end.y - rotulo.end.y, caixa_do_painel.get_margin(SIDE_BOTTOM)])


## O nome da fonte de verdade: a variação (peso, reservas) não conta, a base dela sim.
func _fonte(fonte: Font) -> String:
	if fonte is FontVariation and (fonte as FontVariation).base_font != null:
		return _fonte((fonte as FontVariation).base_font)
	return "%s|%s" % [fonte.get_font_name(), fonte.resource_path]


## Tudo que dá a cara do aviso: a fonte, o tamanho, a cor, as margens, o canto, o fundo e o filete.
func _cara_do_aviso(rotulo: Label, painel: Control) -> Dictionary:
	var caixa := (painel.get_theme_stylebox("panel") if painel is PanelContainer else rotulo.get_theme_stylebox("normal")) as StyleBoxFlat
	return {
		"fonte": _fonte(rotulo.get_theme_font("font")),
		"tamanho": rotulo.get_theme_font_size("font_size"),
		"cor da letra": rotulo.get_theme_color("font_color"),
		"alinhamento": rotulo.horizontal_alignment,
		"margens": [caixa.content_margin_left, caixa.content_margin_right, caixa.content_margin_top, caixa.content_margin_bottom],
		"canto": caixa.corner_radius_top_left,
		"fundo": caixa.bg_color,
		"filete": caixa.border_color,
		"largura do filete": caixa.border_width_left,
	}


func test_todos_os_avisos_de_baixo_tem_a_mesma_cara() -> void:
	var hud := _hud()
	await _quadros(2)
	hud.set_aviso_de_espera("Pedro voltou para te buscar: siga com ele.")
	hud.set_notice(LONGA, 20.0)
	hud.avisar_embaixo("Precisa de Foice.")
	await _quadros(4)
	var referencia := _cara_do_aviso(hud._espera_label, hud._espera_panel)
	_conferir(hud._avisos_de_tarefa.size() == 1, "o recado 'Precisa de Foice.' não foi para a pilha de baixo (%d)" % hud._avisos_de_tarefa.size())
	if hud._avisos_de_tarefa.size() == 1:
		_conferir(hud._avisos_de_tarefa[0].is_inside_tree(), "o recado 'Precisa de Foice.' nunca entrou na árvore do HUD: ninguém o vê")
	var outros := {"o aviso do alto da pilha (o modo corrida)": _cara_do_aviso(hud._notice_label, hud._notice_panel)}
	if hud._avisos_de_tarefa.size() == 1:
		outros["o recado de baixo (a recusa)"] = _cara_do_aviso(hud._avisos_de_tarefa[0], hud._avisos_de_tarefa[0])
	for nome: String in outros:
		var cara: Dictionary = outros[nome]
		for chave: String in referencia:
			_conferir(cara[chave] == referencia[chave],
				"%s tem %s = %s, e o aviso de espera (a referência), %s" % [nome, chave, str(cara[chave]), str(referencia[chave])])
	# O "✓ tarefa" entra na mesma pilha, e também tem a mesma cara (num HUD novo: o recado de antes ainda ocupa a vez).
	var outro := _hud()
	await _quadros(2)
	outro.tarefa_concluida("Cortou o capim (2/4)")
	await _quadros(4)
	var da_tarefa: Label = outro._risco_da_tarefa
	_conferir(da_tarefa != null and da_tarefa.text.begins_with("✓"), "o '✓ tarefa' não apareceu na pilha de baixo")
	_conferir(str(outro.tarefa_concluida_a_vista()).begins_with("✓"), "o '✓ tarefa' não está à vista no HUD ('%s')" % str(outro.tarefa_concluida_a_vista()))
	if da_tarefa != null:
		var cara_da_tarefa := _cara_do_aviso(da_tarefa, da_tarefa)
		for chave: String in referencia:
			_conferir(cara_da_tarefa[chave] == referencia[chave],
				"o '✓ tarefa' tem %s = %s, e o aviso de espera (a referência), %s" % [chave, str(cara_da_tarefa[chave]), str(referencia[chave])])


func test_os_recados_de_baixo_aparecem_inteiros_e_em_pilha() -> void:
	# O "✓ tarefa" e a recusa eram criados, medidos e postos, mas nunca entravam no HUD (desde 10/10): ninguém os via.
	var hud := _hud()
	await _quadros(2)
	hud.set_notice(LONGA, 30.0)
	hud.avisar_embaixo("Precisa de Foice.")
	await get_tree().create_timer(0.5).timeout
	hud.tarefa_concluida("Cortou o capim com a foice (2/4)")
	await get_tree().create_timer(0.5).timeout
	var recados: Array = hud._avisos_de_tarefa
	_conferir(recados.size() == 2, "a pilha de baixo tem %d recado(s), e eram dois (a recusa e o ✓)" % recados.size())
	var janela: Rect2 = hud._root.get_global_rect()
	var aviso: Rect2 = hud._notice_panel.get_global_rect()
	var anterior := Rect2()
	for recado: Label in recados:
		var caixa := recado.get_global_rect()
		_conferir(recado.is_visible_in_tree() and recado.modulate.a > 0.9, "o recado '%s' não está à vista (na árvore: %s, alfa %.2f)" % [recado.text, str(recado.is_inside_tree()), recado.modulate.a])
		_conferir(janela.encloses(caixa), "o recado '%s' (%s) sai da tela (%s)" % [recado.text, str(caixa), str(janela)])
		_conferir(not caixa.intersects(aviso), "o recado '%s' cobre o aviso de baixo" % recado.text)
		_conferir(absf(caixa.get_center().x - janela.get_center().x) <= 2.0, "o recado '%s' não está no meio da tela" % recado.text)
		_conferir(absf(caixa.size.y - float(hud._text_height(recado)) - recado.get_theme_stylebox("normal").get_minimum_size().y) <= 1.0,
			"o recado '%s' tem %.1f px de altura, com uma linha de texto" % [recado.text, caixa.size.y])
		if anterior.has_area():
			_conferir(not caixa.intersects(anterior), "o recado '%s' cobre o de baixo" % recado.text)
			_conferir(caixa.end.y <= anterior.position.y + 0.5, "o recado '%s' devia estar acima do outro" % recado.text)
		anterior = caixa
	# E eles se apagam sozinhos, e a pilha esvazia.
	await get_tree().create_timer(3.8).timeout
	_conferir(hud._avisos_de_tarefa.is_empty(), "os recados não se apagaram (%d)" % hud._avisos_de_tarefa.size())
	_conferir(str(hud.tarefa_concluida_a_vista()) == "", "o '✓ tarefa' continua à vista depois do prazo")
