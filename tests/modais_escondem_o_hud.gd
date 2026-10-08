extends SceneTree
## Confere QUE TODO MODAL ESCONDE O HUD DO VALE e que os papéis da tipografia
## existem e valem (#199).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/modais_escondem_o_hud.gd
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
		print("MODAIS_OK: painel, Arraial, Teia, Coleção, menu do Esc, Controles e Ajustes recolhem a interface do vale e a devolvem ao fechar, o tema tem os quatro papéis de tipografia, a página da fé tem o nome de cada fé em ouro na Cinzel e o corpo na sans de leitura em linhas curtas, o rodapé de teclas tem plaquetas, e o texto apagado passa de 4,5:1")
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
