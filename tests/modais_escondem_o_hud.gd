extends "res://tests/suite/caso.gd"
## Confere QUE TODO MODAL ESCONDE O HUD DO VALE e que os papéis da tipografia
## existem e valem (#199).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste modais_escondem_o_hud
##
## A queixa: com o Arraial (P) aberto, missão, relógio, atalhos, minimapa e barra de
## mão apareciam atrás do modal, só escurecidos. A #143 tinha resolvido isso só
## para a Mochila e o Baú. Quatro perguntas:
##
##   1. CADA TELA REGISTRADA recolhe a interface do vale ao abrir e a devolve ao
##      fechar — painel (J), Arraial (P), Teia (K), Coleção (L), menu do Esc e
##      Controles — por UM mecanismo (`Prototype._acertar_as_placas`), e os Ajustes,
##      que não são tela, também.
##   2. O TEMA TEM OS PAPÉIS: TituloModal, RotuloSecao, TextoLeitura e Enfase.
##   3. TEXTO PARA LER NÃO É CORMORANT: o corpo da página da fé está na sans do HUD,
##      o nome de cada fé está em destaque (Cinzel, ouro) e o rodapé de teclas tem
##      plaquetas.
##   4. O CINZA APAGADO LÊ-SE: o texto secundário sobre a laca passa de 4,5:1.

const TemaMenu = preload("res://scripts/prototipo_3d/tema_menu.gd")
const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("MODAIS_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(6)
	await _mundo_pronto()
	await _frames(10)
	var vale = current_scene
	if vale == null or vale.get("telas") == null or vale.get("hud_layer") == null:
		_conferir(false, "o vale não ficou de pé com o dono das telas")
		_fechar()
		return

	# --- 1. CADA MODAL RECOLHE O HUD E O DEVOLVE --------------------------------
	_conferir(vale.hud_layer.is_visible_in_tree(), "o HUD já começa escondido, antes de qualquer modal")
	for nome in ["painel", "arraial", "talentos", "almanaque", "menu_pausa", "controles"]:
		vale.telas.fechar_tudo()
		await _frames(2)
		vale.telas.abrir(nome)
		await _frames(3)
		_conferir(vale.telas.aberta() == nome, "a tela '%s' não abriu" % nome)
		_conferir(not vale.hud_layer.is_visible_in_tree(), "com '%s' aberto, a interface do vale continua à mostra" % nome)
		vale.telas.fechar_tudo()
		await _frames(3)
		_conferir(vale.hud_layer.is_visible_in_tree(), "fechar '%s' não devolveu a interface do vale" % nome)
	# Os Ajustes não são tela do dono delas: têm o próprio caminho.
	vale.telas.fechar_tudo()
	await _frames(2)
	vale._open_settings()
	await _frames(3)
	_conferir(vale.hud.settings_open(), "os Ajustes não abriram")
	_conferir(not vale.hud_layer.is_visible_in_tree(), "com os Ajustes abertos, a interface do vale continua à mostra")
	vale.hud.close_settings()
	await _frames(3)
	_conferir(vale.hud_layer.is_visible_in_tree(), "fechar os Ajustes não devolveu a interface do vale")

	# --- 2. O TEMA TEM OS PAPÉIS --------------------------------------------------
	var tema := TemaMenu.criar()
	for papel in ["TituloModal", "RotuloSecao", "TextoLeitura", "Enfase"]:
		_conferir(tema.get_type_variation_base(papel) == &"Label", "o tema não tem o papel '%s' como variação de Label" % papel)
	_conferir(tema.get_font("font", "TextoLeitura") is FontVariation
		and (tema.get_font("font", "TextoLeitura") as FontVariation).base_font == ThemeDB.fallback_font,
		"o papel TextoLeitura não usa a sans do HUD")

	# --- 3. A PÁGINA DA FÉ É PARA LER -------------------------------------------
	var teia = vale.teia
	if teia == null:
		_conferir(false, "o vale não tem a teia de talentos")
		_fechar()
		return
	vale.telas.abrir("talentos")
	await _frames(3)
	if teia.modo() != "fe":
		teia.trocar_de_teia()
	await _frames(3)
	var fe = root.get_node("/root/Fe")
	if fe.ativa == "":
		var pagina := _achar(teia, "PaginaDaFe")
		_conferir(pagina != null, "sem fé, a página da fé não existe")
		if pagina != null:
			var nomes := _todos(pagina, "NomeDaFe")
			_conferir(nomes.size() == fe.ids().size(), "a página não destaca o nome de cada fé: %d de %d" % [nomes.size(), fe.ids().size()])
			for nome in nomes:
				var rotulo := nome as Label
				var cinzel: Font = (rotulo.get_theme_font("font") as FontVariation).base_font
				_conferir(cinzel == load(Identidade.FONTE_TITULO), "o nome da fé não está na Cinzel")
				_conferir(rotulo.get_theme_color("font_color").is_equal_approx(Identidade.OURO), "o nome da fé não está em ouro")
			var corpos := _rotulos_sem_nome(pagina)
			_conferir(not corpos.is_empty(), "a página da fé não tem texto")
			for corpo in corpos:
				var fonte := (corpo as Label).get_theme_font("font") as FontVariation
				_conferir(fonte != null and fonte.base_font == ThemeDB.fallback_font,
					"o texto da página da fé não está na sans de leitura: '%s'" % (corpo as Label).text.left(40))
				_conferir((corpo as Label).custom_minimum_size.x <= 600.0, "o texto da página da fé tem linha longa demais")
	var rodape := _achar(teia, "Rodape")
	_conferir(rodape != null and rodape.find_child("Plaqueta", true, false) != null,
		"o rodapé de teclas da Teia não tem plaquetas")
	_conferir(rodape != null and rodape.find_child("Tecla", true, false) != null
		and (rodape.find_child("Tecla", true, false) as Label).text != "",
		"as plaquetas do rodapé estão vazias")
	vale.telas.fechar_tudo()

	# --- 4. O CINZA APAGADO LÊ-SE ------------------------------------------------
	var laca := Color(0.055, 0.082, 0.070)
	_conferir(_contraste(Identidade.COR_LEITURA_APAGADA, laca) >= 4.5,
		"o creme apagado tem contraste %.2f, abaixo de 4,5" % _contraste(Identidade.COR_LEITURA_APAGADA, laca))
	_conferir(_contraste(Identidade.COR_LEITURA, laca) >= 7.0, "o creme de leitura tem contraste baixo")
	_conferir(Identidade.pares_do_rodape("↑↓ ou W/S: andar    ·    P ou Esc: fechar").size() == 2, "o rodapé de teclas não se parte em dois")
	_conferir(Identidade.pares_do_rodape("[E] acompanhar · [Esc] fechar")[0][0] == "E", "o rodapé [E] não vira plaqueta")

	# --- 5. O CHINÊS TEM FONTE DE RESERVA DECLARADA --------------------------------
	# Nem a sans do HUD nem a Cinzel nem a Cormorant têm ideogramas: com o jogo em chinês a reserva é
	# uma SystemFont com as famílias nomeadas, em último lugar, para o latim sair sempre da fonte do jogo.
	# Fora do chinês a lista é vazia: fonte de reserva muda a altura de linha, e o layout latino não
	# pode mexer (a barra de mão, `plaquetas_de_tecla`).
	var PainelAjustes: GDScript = load("res://scripts/prototipo_3d/painel_ajustes.gd")
	var IdiomaMenu: GDScript = load("res://scripts/prototipo_3d/idioma_menu.gd")
	IdiomaMenu.definir(0)
	_conferir(Identidade.reservas_cjk().is_empty() and Identidade.fonte_do_hud().fallbacks.size() == 1
		and (Identidade.fonte(Identidade.FONTE_TEXTO, 500) as FontVariation).fallbacks.is_empty(),
		"fora do chinês as fontes ganham reserva CJK: a altura de linha do texto latino muda")
	IdiomaMenu.definir(3)
	var reserva := Identidade.fonte_cjk()
	_conferir(reserva is SystemFont and reserva.font_names.has("Microsoft YaHei") and reserva.font_names.has("Noto Sans CJK SC"),
		"a reserva do chinês não nomeia as famílias CJK")
	_conferir(Identidade.fonte_cjk() == reserva and Identidade.reservas_cjk().size() == 1 and Identidade.reservas_cjk()[0] == reserva, "a reserva do chinês não é uma instância só")
	var leitura := Identidade.fonte_do_hud()
	_conferir(leitura.fallbacks.size() == 2 and leitura.fallbacks[1] == reserva and leitura.base_font == ThemeDB.fallback_font,
		"a sans de leitura não termina na reserva do chinês, depois da Cormorant")
	for fonte_do_papel in [Identidade.fonte(Identidade.FONTE_TITULO, 600, 1), Identidade.fonte(Identidade.FONTE_TEXTO, 500), Identidade.fonte(Identidade.FONTE_ITALICO, 500)]:
		_conferir((fonte_do_papel as FontVariation).fallbacks.has(reserva), "uma fonte de papel (título, rótulo ou ênfase) não tem a reserva do chinês")
	var rotulo_zh := Identidade.papel_leitura(Label.new())
	var tema_zh := TemaMenu.criar()
	_conferir((tema_zh.get_font("font", "TextoLeitura") as FontVariation).fallbacks.has(reserva), "o papel TextoLeitura do tema não leva a reserva do chinês")
	if OS.has_feature("windows"):
		var ideogramas := "神话谷：欢迎来到阿拉亚尔"
		_conferir(leitura.get_string_size(ideogramas, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x > 17.0 * 4.0,
			"a fonte de leitura não desenha ideogramas: a reserva não achou família CJK nesta máquina")
		_conferir(Identidade.fonte(Identidade.FONTE_TITULO, 600, 1).get_string_size(ideogramas, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x > 17.0 * 4.0,
			"a Cinzel dos títulos não cai na reserva para os ideogramas")
	rotulo_zh.free()
	IdiomaMenu.definir(0)

	# --- 5b. A ESCALA DE TEXTO DOS AJUSTES VALE PARA OS QUATRO PAPÉIS ---------------
	var tela_autoload: Node = root.get_node("/root/Tela")
	var papeis: Array[Label] = [Identidade.papel_titulo(Label.new()), Identidade.papel_rotulo(Label.new()),
		Identidade.papel_leitura(Label.new()), Identidade.papel_enfase(Label.new())]
	var tamanhos: Array[int] = []
	for papel in papeis:
		papel.text = "Papel"
		root.add_child(papel)
		tamanhos.append(papel.get_theme_font_size("font_size"))
	var antes_do_tamanho: int = tela_autoload.tamanho_texto
	tela_autoload.definir_tamanho_texto(3)
	for i in papeis.size():
		_conferir(papeis[i].get_theme_font_size("font_size") == roundi(tamanhos[i] * float(tela_autoload.ESCALAS_TEXTO[3])),
			"o 'Tamanho do texto' dos Ajustes não escalou o papel %d: %d, esperado %d" % [i, papeis[i].get_theme_font_size("font_size"), roundi(tamanhos[i] * float(tela_autoload.ESCALAS_TEXTO[3]))])
	tela_autoload.definir_tamanho_texto(antes_do_tamanho)
	for papel in papeis:
		papel.free()

	# --- 6. OS RÓTULOS DE SEÇÃO DOS AJUSTES CABEM --------------------------------
	# Cinzel menor em ouro, com espaço entre as letras: em nenhum idioma, nem em nenhuma aba, o rótulo
	# de seção quebra em duas linhas ou sai da coluna.
	var secoes := 0
	for idioma in [0, 1, 2, 3]:
		IdiomaMenu.definir(idioma)
		for aba in PainelAjustes.ABAS.size():
			var tela_de_prova := Control.new()
			tela_de_prova.theme = TemaMenu.criar()
			tela_de_prova.size = PainelAjustes.TAMANHO
			root.add_child(tela_de_prova)
			var conteudo := VBoxContainer.new()
			conteudo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tela_de_prova.add_child(conteudo)
			var painel = PainelAjustes.new(true)
			painel.construir(conteudo, tela_de_prova, aba)
			await _frames(3)
			for rotulo: Node in conteudo.find_children("*", "Label", true, false):
				var secao := rotulo as Label
				var fonte_da_secao := secao.get_theme_font("font") as FontVariation
				if fonte_da_secao == null or fonte_da_secao.base_font != load(Identidade.FONTE_TITULO) 						or not secao.get_theme_color("font_color").is_equal_approx(Color("e2c47f")) or secao.text.strip_edges() == "":
					continue
				secoes += 1
				_conferir(secao.get_line_count() == 1, "o rótulo de seção '%s' (idioma %d, aba %d) quebra em %d linhas" % [secao.text, idioma, aba, secao.get_line_count()])
				var largura := fonte_da_secao.get_string_size(secao.text, HORIZONTAL_ALIGNMENT_LEFT, -1, secao.get_theme_font_size("font_size")).x
				_conferir(largura <= secao.size.x + 1.0, "o rótulo de seção '%s' (idioma %d, aba %d) tem %.0f px numa coluna de %.0f" % [secao.text, idioma, aba, largura, secao.size.x])
			tela_de_prova.queue_free()
	IdiomaMenu.definir(0)
	_conferir(secoes >= 30, "só %d rótulos de seção medidos nos Ajustes; o portão espera 30 ou mais" % secoes)
	_fechar()


func _luminancia(cor: Color) -> float:
	var canais: Array[float] = []
	for valor in [cor.r, cor.g, cor.b]:
		canais.append(valor / 12.92 if valor <= 0.03928 else pow((valor + 0.055) / 1.055, 2.4))
	return 0.2126 * canais[0] + 0.7152 * canais[1] + 0.0722 * canais[2]


func _contraste(a: Color, b: Color) -> float:
	var clara := maxf(_luminancia(a), _luminancia(b))
	var escura := minf(_luminancia(a), _luminancia(b))
	return (clara + 0.05) / (escura + 0.05)


func _achar(no: Node, nome: String) -> Node:
	return no.find_child(nome, true, false)


func _todos(no: Node, nome: String) -> Array:
	var saida: Array = []
	if no.name == nome:
		saida.append(no)
	for filho in no.get_children():
		saida.append_array(_todos(filho, nome))
	return saida


## Os rótulos da página que não são nome de fé.
func _rotulos_sem_nome(no: Node) -> Array:
	var saida: Array = []
	if no is Label and no.name != "NomeDaFe":
		saida.append(no)
	for filho in no.get_children():
		saida.append_array(_rotulos_sem_nome(filho))
	return saida


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("MODAIS_OK: painel, Arraial, Teia, Coleção, menu do Esc, Controles e Ajustes recolhem a interface do vale e a devolvem ao fechar, o tema tem os quatro papéis de tipografia, o chinês tem fonte de reserva declarada, os rótulos de seção dos Ajustes cabem em uma linha nos quatro idiomas, a página da fé tem o nome de cada fé em ouro na Cinzel e o corpo na sans de leitura em linhas curtas, o rodapé de teclas tem plaquetas, e o texto apagado passa de 4,5:1")
	else:
		print("modais_escondem_o_hud: %d falha(s)" % falhas)
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
