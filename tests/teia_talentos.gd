extends SceneTree
## Confere A TEIA DE TALENTOS do vale — a tela, não o sistema.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/teia_talentos.gd
##
## O SISTEMA JÁ TEM PORTÃO, e é do 2D: o `testar_talentos.gd` de lá cobra os 37
## nós, os campos de efeito e que nenhum espere mecânica que não existe; o
## `testar_teia.gd` cobra a conta da viagem e que a tela concorde com o
## `Talentos`. Nada disso se repete aqui — `Talentos` é o mesmo arquivo nos dois
## jogos, e repetir a pergunta é ter duas versões dela.
##
## O que este portão pergunta é o que é DAQUI: a tela do vale.
##
##   1. A TELA EXISTE E ESTÁ NA TECLA. O K é a tecla da teia no 2D, e ficou
##      livre quando o almanaque assumiu o L.
##   2. TODA RAIZ APARECE, e cada uma traz a conta do que já foi destravado.
##   3. TODO NÓ DA RAIZ ABERTA APARECE. Nó que existe no `Talentos` e não
##      aparece na tela é ponto que o jogador não tem como gastar.
##   4. A ÁRVORE É ÁRVORE: quem exige alguém fica À DIREITA de quem ele exige, e
##      há um fio ligando os dois. Era a razão de não ser uma lista — lista não
##      mostra dependência, e dependência é o que a teia serve para mostrar.
##   5. NENHUM NÓ CAI EM CIMA DE OUTRO. É a mesma pergunta que o `testar_teia`
##      do 2D faz da tela de lá, e ela pega o dia em que uma raiz ganhar nó
##      demais numa coluna.
##   6. O E GASTA O PONTO, e quem recusa é o `Talentos`. Com ponto, destrava;
##      sem ponto, não destrava e a ficha DIZ por quê.
##   7. A TELA CABE NA JANELA — a pergunta da barra de mão.

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("TEIA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK,
		"a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(3)

	var jogo := current_scene
	var talentos := root.get_node("/root/Talentos")
	var teia = jogo.get("teia")
	_conferir(teia != null, "o vale não montou a teia de talentos")
	if teia == null:
		_fechar()
		return

	# --- 1. NA TECLA CERTA ----------------------------------------------------
	var Atalhos = load("res://scripts/prototipo_3d/atalhos.gd")
	_conferir(Atalhos.tecla("talentos") == KEY_K,
		"a teia de talentos não está no K, que é a tecla dela no 2D")

	jogo.telas.abrir("talentos")
	await _frames(3)
	_conferir(teia.aberta, "pedir a teia não abriu nada")
	_conferir(paused, "a teia abriu com o vale andando atrás dela")

	var raizes_coluna := _achar(teia, "Raizes") as VBoxContainer
	var arvore := _achar(teia, "Arvore") as Control
	var ficha := _achar(teia, "Ficha") as VBoxContainer
	_conferir(raizes_coluna != null and arvore != null and ficha != null,
		"a teia não tem a coluna das raízes, a árvore e a ficha")
	if raizes_coluna == null or arvore == null or ficha == null:
		_fechar()
		return

	# --- 2. TODA RAIZ APARECE, COM A CONTA ------------------------------------
	var na_tela: Array[String] = []
	for filho in raizes_coluna.get_children():
		if filho is Button:
			na_tela.append((filho as Button).text)
	var tudo := " | ".join(na_tela)
	print("")
	print("  raízes: ", tudo)
	for bruta in talentos.raizes():
		_conferir(tudo.contains(str(bruta)),
			"a raiz '%s' do Talentos não aparece na tela: %s" % [str(bruta), tudo])
	_conferir(tudo.contains(" de "),
		"as raízes não trazem a conta do que já foi destravado: %s" % tudo)

	# --- 3, 4 e 5. A ÁRVORE DE CADA RAIZ -------------------------------------
	for bruta in talentos.raizes():
		var raiz := str(bruta)
		teia._escolher_raiz(raiz)
		await _frames(3)
		_conferir(teia._raiz == raiz, "não consegui abrir a raiz '%s'" % raiz)

		var caixas: Dictionary = {}
		for filho in arvore.get_children():
			if filho is Button and str(filho.name).begins_with("No_"):
				caixas[str(filho.name).substr(3)] = filho as Button

		# 3. TODO NÓ APARECE.
		var nos: Array = talentos.nos_da_raiz(raiz)
		for no in nos:
			_conferir(caixas.has(str(no)),
				"o nó '%s' da raiz '%s' existe no Talentos e não aparece na tela: ponto que não se gasta"
					% [str(no), raiz])

		# 3b. E TODO NÓ TRAZ O DESENHO DO 2D, com o nome fora de cima dele.
		#
		# A decisão #71 mantém os 39 ícones PixelLab na teia do 3D; não são
		# substitutos provisórios. Eles moram em `assets/sprites/talentos`, copiados
		# para o projeto do vale porque `res://` aqui é a pasta do protótipo e
		# não enxerga a do 2D. Um ícone que não foi copiado some calado: o nó
		# continua lá, só fica uma caixa de texto sem desenho.
		for no in nos:
			if not caixas.has(str(no)):
				continue
			var caixa: Button = caixas[str(no)]
			var desenho: TextureRect = null
			for neto in caixa.get_children():
				if neto is TextureRect:
					desenho = neto as TextureRect
			_conferir(desenho != null and desenho.texture != null,
				"o nó '%s' está sem o ícone do 2D: falta copiar assets/sprites/talentos/%s.png"
					% [str(no), str(no)])
			if desenho == null:
				continue
			var estilo := caixa.get_theme_stylebox("normal")
			var comeca_o_texto: float = estilo.content_margin_left if estilo != null else 0.0
			_conferir(comeca_o_texto >= desenho.position.x + desenho.size.x,
				"no nó '%s' o nome começa em %.0f e o ícone vai até %.0f: texto por cima do desenho"
					% [str(no), comeca_o_texto, desenho.position.x + desenho.size.x])

		# 4. QUEM EXIGE FICA À DIREITA, E HÁ FIO.
		var fios := 0
		for filho in arvore.get_children():
			if filho is Line2D:
				fios += 1
		var exigencias := 0
		for no in nos:
			for exigido in (talentos.dados(str(no)).get("exige", []) as Array):
				if not nos.has(str(exigido)):
					continue
				exigencias += 1
				if not (caixas.has(str(no)) and caixas.has(str(exigido))):
					continue
				var x_dele: float = (caixas[str(no)] as Control).position.x
				var x_do_outro: float = (caixas[str(exigido)] as Control).position.x
				_conferir(x_dele > x_do_outro,
					"'%s' exige '%s' e está em x=%.0f, à esquerda ou junto de x=%.0f: a árvore não lê"
						% [str(no), str(exigido), x_dele, x_do_outro])
		_conferir(fios >= exigencias,
			"a raiz '%s' tem %d exigência(s) e só %d fio(s) desenhado(s)" % [raiz, exigencias, fios])

		# 5. NENHUM NÓ EM CIMA DE OUTRO.
		var ids := caixas.keys()
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				var a := (caixas[ids[i]] as Control)
				var b := (caixas[ids[j]] as Control)
				var ra := Rect2(a.position, a.custom_minimum_size)
				var rb := Rect2(b.position, b.custom_minimum_size)
				_conferir(not ra.intersects(rb),
					"na raiz '%s' os nós '%s' e '%s' se sobrepõem: %s e %s"
						% [raiz, str(ids[i]), str(ids[j]), str(ra), str(rb)])
		print("  %-10s %d nó(s), %d exigência(s), %d fio(s)" % [raiz, nos.size(), exigencias, fios])

	# --- 6. O E GASTA O PONTO, E O TALENTOS RECUSA ---------------------------
	#
	# Primeiro SEM ponto: não destrava, e a ficha diz por quê. Depois com ponto:
	# destrava. Quem decide é o `Talentos`; a tela só pergunta e mostra.
	var raiz_um := str(talentos.raizes()[0])
	teia._escolher_raiz(raiz_um)
	await _frames(2)
	var livre := ""
	for no in talentos.nos_da_raiz(raiz_um):
		if not talentos.tem(str(no)) and (talentos.dados(str(no)).get("exige", []) as Array).is_empty():
			livre = str(no)
			break
	_conferir(livre != "", "a raiz '%s' não tem nó de entrada para testar" % raiz_um)
	if livre != "":
		teia._no = livre
		talentos.pontos = 0
		teia._encher()
		await _frames(2)
		teia._destravar()
		await _frames(2)
		_conferir(not talentos.tem(livre), "destravou '%s' sem ponto nenhum" % livre)
		var recado := _texto_de(ficha)
		_conferir(recado.to_lower().contains("ponto"),
			"sem ponto, a ficha não explica o que falta: '%s'" % recado)

		talentos.pontos = 3
		teia._no = livre
		teia._encher()
		await _frames(2)
		teia._destravar()
		await _frames(2)
		_conferir(talentos.tem(livre),
			"com três pontos na mão, o E não destravou '%s'" % livre)
		_conferir(_texto_de(ficha).to_lower().contains("você tem"),
			"depois de destravar, a ficha não diz que o talento é seu: '%s'" % _texto_de(ficha))

	# --- 7. CABE NA JANELA ---------------------------------------------------
	var caixa := _achar(teia, "Caixa") as Control
	_conferir(caixa != null, "não achei a caixa da teia")
	if caixa != null:
		var quadro := caixa.get_global_rect()
		var janela: Vector2 = caixa.get_viewport_rect().size
		_conferir(quadro.position.x >= -1.0 and quadro.position.y >= -1.0
				and quadro.end.x <= janela.x + 1.0 and quadro.end.y <= janela.y + 1.0,
			"a teia está fora da janela: %s numa tela de %s" % [str(quadro), str(janela)])

	jogo.telas.fechar_tudo()
	await _frames(2)
	_conferir(not teia.aberta, "fechar tudo deixou a teia aberta")
	_conferir(not paused, "fechar a teia deixou o vale parado")

	_fechar()


func _texto_de(no: Node) -> String:
	var partes: Array[String] = []
	for filho in no.get_children():
		if filho is Label:
			partes.append((filho as Label).text)
		elif filho is Button:
			partes.append((filho as Button).text)
		if filho.get_child_count() > 0:
			partes.append(_texto_de(filho))
	return " ".join(partes)


func _achar(raiz: Node, nome: String) -> Node:
	for no in raiz.find_children(nome, "", true, false):
		return no
	return null


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("TEIA_OK: a teia está no K, toda raiz aparece com a conta, todo nó da raiz aberta aparece, quem exige fica à direita de quem ele exige com fio ligando, nenhum nó cai em cima de outro, o E gasta o ponto e sem ponto a ficha diz o que falta, e a tela cabe na janela")
	else:
		print("teia: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame


func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
