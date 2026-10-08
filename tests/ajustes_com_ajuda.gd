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
				_conferir(restaurar.size() == (2 if aba in [0, 1] else 0), "restaurar no cabeçalho só nas abas com volumes (aba %d)" % aba)
				if aba in [0, 1]:
					_conferir(restaurar[0].get_index() < restaurar[1].get_index() and restaurar[1].get_index() == fechar.get_index() - 1,
						"os dois restaurar ficam logo antes do × (aba %d)" % aba)
					_conferir(is_equal_approx(restaurar[0].custom_minimum_size.y, fechar.custom_minimum_size.y), "restaurar na altura do × (aba %d)" % aba)
				_conferir(conteudo.get_child(conteudo.get_child_count() - 1) is ScrollContainer, "sem rodapé depois da lista (aba %d)" % aba)
				var abas_botoes := (conteudo.get_child(2) as HBoxContainer).get_children()
				var foco_ativa := (abas_botoes[aba] as Button).get_theme_stylebox("focus") as StyleBoxFlat
				_conferir(foco_ativa != null and foco_ativa.expand_margin_left == 0.0, "o foco da aba ativa não ganha segunda moldura (aba %d)" % aba)
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
