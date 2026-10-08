extends SceneTree
## Perfil isolado pelo runner. Todo campo de Ajustes tem o "?" de ajuda, em qualquer aba e
## em qualquer idioma (#168): o campo montado à mão ou com rótulo traduzido perdia o "?"
## sem ninguém ver, e o jogador ficava sem saber o que o ajuste faz.

var PainelAjustes
var AjudaMenu
var IdiomaMenu

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		falhas += 1
		print("FALHA: ", rotulo)


func _run() -> void:
	# load() dentro do _run e não preload: o painel usa os autoloads, que só existem depois do _initialize.
	PainelAjustes = load("res://scripts/prototipo_3d/painel_ajustes.gd")
	AjudaMenu = load("res://scripts/prototipo_3d/ajuda_menu.gd")
	IdiomaMenu = load("res://scripts/prototipo_3d/idioma_menu.gd")
	var tela: Node = root.get_node("/root/Tela")
	var campos_vistos := 0
	for idioma in [0, 1, 2]:
		IdiomaMenu.definir(idioma)
		for no_jogo in [false, true]:
			for aba in PainelAjustes.ABAS.size():
				var conteudo := VBoxContainer.new()
				root.add_child(conteudo)
				var painel = PainelAjustes.new(no_jogo)
				painel.construir(conteudo, root, aba)
				# #166: os botões de restaurar volumes ficam no cabeçalho, antes do ×, só em Geral e Sons
				# do vale; não há rodapé, e a aba ativa tem o foco sem a margem que fazia a moldura dupla.
				var cabecalho := conteudo.get_child(0) as HBoxContainer
				var fechar := cabecalho.get_child(cabecalho.get_child_count() - 1) as Button
				var restaurar := cabecalho.get_children().filter(func(no: Node) -> bool: return str(no.name).begins_with("Restaurar"))
				# #169: a aba Interface leva o seu próprio restaurar (Tamanho de cada interface) ao cabeçalho.
				var esperados := 2 if aba in [PainelAjustes.ABA_GERAL, PainelAjustes.ABA_SONS] else (1 if aba == PainelAjustes.ABA_INTERFACE else 0)
				_conferir(restaurar.size() == esperados, "restaurar no cabeçalho só nas abas com volumes ou tamanhos (aba %d)" % aba)
				if aba in [PainelAjustes.ABA_GERAL, PainelAjustes.ABA_SONS]:
					_conferir(restaurar[0].get_index() < restaurar[1].get_index() and restaurar[1].get_index() == fechar.get_index() - 1,
						"os dois restaurar ficam logo antes do × (aba %d)" % aba)
					_conferir(is_equal_approx(restaurar[0].custom_minimum_size.y, fechar.custom_minimum_size.y), "restaurar na altura do × (aba %d)" % aba)
				_conferir(conteudo.get_child(conteudo.get_child_count() - 1) is ScrollContainer, "sem rodapé depois da lista (aba %d)" % aba)
				var abas_botoes := (conteudo.get_child(2) as HBoxContainer).get_children()
				# #169: seis abas, só com ícone e o nome no tooltip traduzido; a aberta fica dourada e é a da chamada.
				_conferir(abas_botoes.size() == 6 and PainelAjustes.ABAS.size() == 6 and PainelAjustes.ICONES_ABAS.size() == 6, "são seis abas (aba %d)" % aba)
				for indice in abas_botoes.size():
					var tab := abas_botoes[indice] as Button
					var glifo := tab.get_child(0) as Control
					_conferir(tab.text.is_empty() and glifo != null and str(glifo.get("tipo")) == PainelAjustes.ICONES_ABAS[indice], "a aba %d é só o ícone '%s'" % [indice, PainelAjustes.ICONES_ABAS[indice]])
					var nome := str(PainelAjustes.ABAS[indice])
					_conferir(tab.tooltip_text == (nome if idioma == 0 else str((IdiomaMenu.EN if idioma == 1 else IdiomaMenu.ES).get(nome, "")) ) and not tab.tooltip_text.is_empty(), "a aba '%s' tem tooltip traduzido (idioma %d): '%s'" % [nome, idioma, tab.tooltip_text])
					_conferir(tab.button_pressed == (indice == aba) and bool(glifo.get("ativo")) == (indice == aba), "só a aba aberta fica pressionada e dourada (aba %d, botão %d)" % [aba, indice])
					# O foco do teclado ou do controle mostra a dica, e perdê-lo a esconde.
					var dica := tab.get_node("DicaDoFoco") as Control
					_conferir(dica != null and not dica.visible, "a dica da aba %d começa escondida" % indice)
				var por_foco := abas_botoes[(aba + 1) % abas_botoes.size()] as Button
				por_foco.grab_focus()
				_conferir((por_foco.get_node("DicaDoFoco") as Control).visible, "o foco numa aba mostra o nome dela (aba %d)" % aba)
				por_foco.release_focus()
				_conferir(not (por_foco.get_node("DicaDoFoco") as Control).visible, "perder o foco esconde o nome da aba (aba %d)" % aba)
				var foco_ativa := (abas_botoes[aba] as Button).get_theme_stylebox("focus") as StyleBoxFlat
				_conferir((abas_botoes[aba] as Button).has_theme_stylebox_override("focus") and foco_ativa != null and foco_ativa.expand_margin_left == 0.0 and foco_ativa.expand_margin_right == 0.0 and foco_ativa.expand_margin_top == 0.0 and foco_ativa.expand_margin_bottom == 0.0, "o foco da aba ativa não ganha segunda moldura (aba %d)" % aba)
				for caixa in conteudo.find_children("*", "VBoxContainer", true, false):
					if not is_equal_approx((caixa as Control).custom_minimum_size.y, PainelAjustes.ALTURA_CAMPO):
						continue
					campos_vistos += 1
					var linha := caixa.get_child(0) as HBoxContainer
					var rotulo := linha.get_child(linha.get_child_count() - 1) as Label
					var ajuda := linha.get_child(0) as Button
					_conferir(ajuda != null and ajuda.text == "?",
						"o campo '%s' (aba %d, idioma %d) tem o ? de ajuda" % [rotulo.text, aba, idioma])
				conteudo.queue_free()
	# #169: Interface reúne cursor, texto, HUD, monitor e os tamanhos de cada interface; Cenário
	# fica só com o vale (e o Menu), sem nenhum desses; "Sons do vale" virou "Sons".
	for no_jogo in [false, true]:
		var cenario := _rotulos_da_aba(PainelAjustes.ABA_CENARIO, no_jogo)
		var interface := _rotulos_da_aba(PainelAjustes.ABA_INTERFACE, no_jogo)
		for ajuste in ["Cursor do mouse", "Tamanho do texto", "Tamanho do HUD", "Monitor"]:
			_conferir(ajuste in interface and not ajuste in cenario, "'%s' mora em Interface e não em Cenário (no jogo: %s)" % [ajuste, str(no_jogo)])
		_conferir("Estilo visual" in cenario and "Sustos" in cenario and not "Estilo visual" in interface, "Cenário guarda os ajustes do vale (no jogo: %s)" % str(no_jogo))
		_conferir(interface.size() == 4 + tela.COMPONENTES.size(), "Interface tem os quatro ajustes e os %d tamanhos (tem %d)" % [tela.COMPONENTES.size(), interface.size()])
		_conferir(("Fonte do menu" in cenario) == (not no_jogo), "a seção Menu só aparece fora do jogo (no jogo: %s)" % str(no_jogo))
	_conferir(PainelAjustes.ABAS[PainelAjustes.ABA_SONS] == "Sons" and IdiomaMenu.EN.has("Sons") and IdiomaMenu.ES.has("Sons") and IdiomaMenu.EN.has("Esforço") and IdiomaMenu.ES.has("Esforço") and IdiomaMenu.EN.has("Sons voltam ao padrão.") and IdiomaMenu.ES.has("Sons voltam ao padrão."), "Sons e Esforço têm nome e frase de restaurar nos três idiomas")
	_conferir(campos_vistos > 200, "a varredura viu os campos de todas as abas (%d)" % campos_vistos)

	# O texto de cada ajuda existe nos três idiomas, e o chinês usa o inglês.
	var chaves: Array = AjudaMenu.TEXTOS.keys()
	for componente: String in tela.COMPONENTES:
		chaves.append("interface:" + componente)
	for chave: String in chaves:
		_conferir(AjudaMenu.tem(chave), "a ajuda '%s' existe" % chave)
		for idioma in [0, 1, 2]:
			_conferir(not AjudaMenu.texto(chave, idioma).strip_edges().is_empty(), "a ajuda '%s' tem texto no idioma %d" % [chave, idioma])
		_conferir(AjudaMenu.texto(chave, 3) == AjudaMenu.texto(chave, 1), "a ajuda '%s' em chinês usa o inglês" % chave)
		_conferir(AjudaMenu.texto(chave, 0) != AjudaMenu.texto(chave, 1), "a ajuda '%s' está traduzida para o inglês" % chave)
	_conferir(not AjudaMenu.tem("interface:inexistente"), "interface sem descrição não ganha ?")

	# Passos na água: o padrão é Original, e o ↺ do campo existe como nos vizinhos.
	_conferir(PainelAjustes.PADRAO_AGUA == 0, "o padrão dos passos na água é Original")
	if falhas == 0:
		print("AJUSTES_COM_AJUDA_OK: %d campos, todos com ? em pt/en/es" % campos_vistos)
	quit(falhas)


## Os títulos dos campos (rótulos com o "?") de uma aba, em português, na ordem em que aparecem.
func _rotulos_da_aba(aba: int, no_jogo: bool) -> Array:
	IdiomaMenu.definir(0)
	var conteudo := VBoxContainer.new()
	root.add_child(conteudo)
	var painel = PainelAjustes.new(no_jogo)
	painel.construir(conteudo, root, aba)
	var rotulos: Array = []
	for caixa in conteudo.find_children("*", "VBoxContainer", true, false):
		if not is_equal_approx((caixa as Control).custom_minimum_size.y, PainelAjustes.ALTURA_CAMPO):
			continue
		var linha := caixa.get_child(0) as HBoxContainer
		rotulos.append((linha.get_child(linha.get_child_count() - 1) as Label).text)
	conteudo.queue_free()
	return rotulos

