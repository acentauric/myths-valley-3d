extends SceneTree
## O MENU DA ESQUERDA DO DIÁRIO RECOLHE, E A FALA E OS OBJETIVOS TÊM A MESMA LETRA (#221).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/diario_menu_recolhivel.gd
##
## No Diário (J), mesmo depois da #202, as colunas da esquerda (as abas e a lista de missões) ocupavam quase metade da
## largura com uma missão só, a fala de quem pediu saía maior que os objetivos, e os objetivos ainda rolavam. Cinco
## perguntas:
##
##   1. O MENU RECOLHE E EXPANDE: por padrão aberto; o botão do alto, o ▸ da faixa e o Backspace alternam; recolhido,
##      a lista e as abas somem e só fica a faixa estreita, com os ícones das categorias e o "n/N" da missão.
##   2. A ESCOLHA FICA SALVA: esquecida a da sessão, o arquivo de preferências devolve o mesmo.
##   3. A FICHA USA A LARGURA LIBERADA: a página do Diário fica mais de 150 px mais larga com o menu recolhido.
##   4. A MESMA LETRA: a fala e os objetivos (os cumpridos e o de agora) têm a mesma fonte e o mesmo tamanho de
##      leitura; muda só a cor.
##   5. SEM ROLAGEM, e o TECLADO segue: os objetivos não rolam, aberto ou recolhido, na janela de 1280×720 e na de
##      1920×1080; ↑↓/W/S trocam de missão e o Esc fecha com o menu recolhido.

const FALA := "Toma. Esse tem mais idade que nós dois somados, e aguenta mais do que parece. Chega perto do tronco, encosta a mão e aperta E. Não precisa ter pressa nem força, que quem corta é a lâmina e não o braço."

## Carregado no _run, não por preload: no --script o preload compila antes de os autoloads virarem nomes globais.
var CadeiaDeMissoes: GDScript
var Identidade: GDScript

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("DIARIO_MENU_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	CadeiaDeMissoes = load("res://scripts/prototipo_3d/cadeia_de_missoes.gd")
	Identidade = load("res://scripts/prototipo_3d/identidade.gd")
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(6)
	await _mundo_pronto()
	await _frames(10)
	var vale = current_scene
	var painel = vale.get_node_or_null("Painel") if vale != null else null
	if painel == null:
		_conferir(false, "o vale não montou o painel")
		_fechar()
		return
	# O padrão de fábrica: aberto (o profile do runner não tem a escolha).
	painel.esquecer_o_menu()
	var antes: bool = painel.menu_recolhido()
	painel.definir_menu_recolhido(false)
	var caderno = root.get_node("/root/CadernoDoVale")
	caderno.abrir_missao("menu_a", "A ponte do rio grande", "pedro", true, "Pedro: " + FALA)
	caderno.descrever("menu_a", {
		"missao": "A ponte do rio grande", "quem": "Pedro", "resumo": "Encoste no tronco e aperte E (1/3)",
		"passo": 2, "passos": 5, "total": 3, "feito": 1,
		"fala_curta": CadeiaDeMissoes.fala_curta(FALA),
		"feitos": ["Fale com o Pedro", "Pegue o machado na oficina", "Chegue até o tronco caído", "Corte a primeira tora"],
		"recompensa": {"reis": 12, "xp": 10},
	})
	caderno.abrir_missao("menu_b", "Lenha para o forno", "zefa", false, "Zefa: Traz lenha.")
	vale.telas.fechar_tudo()
	await _frames(2)
	vale.telas.abrir("painel")
	await _frames(4)
	_conferir(painel.aberto, "o painel não abriu")
	var lista: Array = caderno.por_importancia()
	var indice := -1
	for i in lista.size():
		if str((lista[i] as Dictionary).get("id", "")) == "menu_a":
			indice = i
	painel.escolher(maxi(indice, 0))
	await _frames(4)
	_conferir(painel.aba() == painel.Aba.MISSOES, "o painel não abriu em Missões")

	# --- 1. O MENU RECOLHE E EXPANDE ----------------------------------------------------------------
	var faixa := painel.find_child("FaixaDoMenu", true, false) as Control
	var abas := painel.find_child("Abas", true, false) as Control
	var diario := painel.find_child("Diario", true, false) as Control
	var botao_do_alto := painel.find_child("BotaoDoMenu", true, false) as Button
	_conferir(faixa != null and abas != null and diario != null and botao_do_alto != null, "faltam a faixa, as abas, o diário ou o botão do menu")
	if faixa == null or diario == null or botao_do_alto == null:
		_fechar()
		return
	_conferir(not painel.menu_recolhido() and not faixa.visible and botao_do_alto.visible, "o padrão devia ser o menu aberto, com o botão no alto")
	var rolagem_da_lista := painel._rolagem as Control
	_conferir(rolagem_da_lista.visible, "com o menu aberto, a lista de missões devia aparecer")
	var largura_aberto := diario.size.x
	await _conferir_letras(painel, "menu aberto")
	await _conferir_sem_rolagem(painel, "menu aberto, 1280×720")

	botao_do_alto.pressed.emit()
	await _frames(4)
	_conferir(painel.menu_recolhido() and faixa.visible, "o botão do alto não recolheu o menu")
	_conferir(not rolagem_da_lista.visible and (abas == null or not abas.visible), "recolhido, a lista e as abas continuam à mostra")
	_conferir(faixa.size.x <= 60.0, "a faixa do menu recolhido é larga demais: %.0f px" % faixa.size.x)
	var icones := painel.find_child("IconesDaFaixa", true, false) as Control
	_conferir(icones != null and icones.get_child_count() >= 1, "a faixa não traz os ícones das categorias")
	if icones != null and icones.get_child_count() >= 1:
		var primeiro := icones.get_child(0) as Button
		_conferir(primeiro != null and primeiro.icon != null and primeiro.tooltip_text != "", "o ícone da categoria na faixa não tem figura e nome")
	var contador := painel.find_child("ContadorDoMenu", true, false) as Label
	_conferir(contador != null and contador.text == "%d/%d" % [painel._cursor + 1, caderno.por_importancia().size()],
		"a faixa não diz em que missão se está (%s)" % (contador.text if contador != null else "sem contador"))

	# --- 3. A FICHA USA A LARGURA LIBERADA ------------------------------------------------------------
	var largura_recolhido := diario.size.x
	_conferir(largura_recolhido > largura_aberto + 150.0, "a ficha não ganhou a largura do menu: %.0f px antes, %.0f depois" % [largura_aberto, largura_recolhido])
	await _conferir_letras(painel, "menu recolhido")
	await _conferir_sem_rolagem(painel, "menu recolhido, 1280×720")
	var janela := root.size
	root.size = Vector2i(1920, 1080)
	await _frames(6)
	await _conferir_sem_rolagem(painel, "menu recolhido, 1920×1080")
	root.size = janela
	await _frames(4)

	# --- 2. A ESCOLHA FICA SALVA ---------------------------------------------------------------------------
	painel.esquecer_o_menu()
	_conferir(painel.menu_recolhido(), "a escolha de recolher não ficou no arquivo de preferências")

	# --- 5. O TECLADO CONTINUA -------------------------------------------------------------------------------
	var cursor_antes: int = painel._cursor
	painel._unhandled_input(_tecla(KEY_DOWN))
	await _frames(2)
	_conferir(painel._cursor != cursor_antes, "com o menu recolhido, a seta para baixo não troca de missão")
	painel._unhandled_input(_tecla(KEY_BACKSPACE))
	await _frames(4)
	_conferir(not painel.menu_recolhido() and not faixa.visible and rolagem_da_lista.visible, "o Backspace não abriu o menu recolhido")
	painel._unhandled_input(_tecla(KEY_BACKSPACE))
	await _frames(4)
	_conferir(painel.menu_recolhido() and faixa.visible, "o Backspace não recolheu o menu")
	var abrir := painel.find_child("AbrirMenu", true, false) as Button
	_conferir(abrir != null, "a faixa não tem o ▸ para expandir")
	if abrir != null:
		abrir.pressed.emit()
		await _frames(4)
		_conferir(not painel.menu_recolhido() and rolagem_da_lista.visible, "o ▸ da faixa não expandiu o menu")
	painel.alternar_o_menu()
	await _frames(2)
	painel._unhandled_input(_tecla(KEY_ESCAPE))
	await _frames(2)
	_conferir(not painel.aberto, "o Esc não fechou o painel com o menu recolhido")

	# O menu só existe no Diário: nas outras abas o botão do alto some.
	painel.abrir(painel.Aba.CARTAS)
	await _frames(2)
	_conferir(not botao_do_alto.visible and not faixa.visible, "o botão do menu apareceu fora do Diário")
	painel.fechar()

	painel.definir_menu_recolhido(antes)
	painel.esquecer_o_menu()
	caderno.concluir("menu_a")
	caderno.concluir("menu_b")
	vale.telas.fechar_tudo()
	_fechar()


## 4. A fala e os objetivos: a mesma fonte e o mesmo tamanho de leitura; só a cor muda.
func _conferir_letras(painel: Node, quando: String) -> void:
	var fala := painel.find_child("Fala", true, false) as Label
	var objetivo := painel.find_child("ObjetivoDeAgora", true, false) as Label
	var feitos := painel.find_children("*Feito*", "Label", true, false)
	_conferir(fala != null and objetivo != null and not feitos.is_empty(), "%s: a página não tem a fala, o objetivo de agora e os cumpridos" % quando)
	if fala == null or objetivo == null:
		return
	var tamanho_da_fala := fala.get_theme_font_size("font_size")
	_conferir(tamanho_da_fala == int(Identidade.TAMANHO_LEITURA), "%s: a fala não usa o tamanho de leitura (%d)" % [quando, tamanho_da_fala])
	_conferir(objetivo.get_theme_font_size("font_size") == tamanho_da_fala, "%s: o objetivo de agora (%d) tem tamanho diferente da fala (%d)" % [quando, objetivo.get_theme_font_size("font_size"), tamanho_da_fala])
	_conferir(_mesma_fonte(objetivo.get_theme_font("font"), fala.get_theme_font("font")), "%s: o objetivo de agora e a fala usam fontes diferentes" % quando)
	for feito: Label in feitos:
		_conferir(feito.get_theme_font_size("font_size") == tamanho_da_fala, "%s: um objetivo cumprido (%d) tem tamanho diferente da fala (%d)" % [quando, feito.get_theme_font_size("font_size"), tamanho_da_fala])
		_conferir(_mesma_fonte(feito.get_theme_font("font"), fala.get_theme_font("font")), "%s: um objetivo cumprido e a fala usam fontes diferentes" % quando)
		_conferir(feito.get_theme_color("font_color") != objetivo.get_theme_color("font_color"), "%s: o cumprido devia ser apagado, e tem a cor do objetivo de agora" % quando)
	_conferir(fala.get_theme_constant("line_spacing") == objetivo.get_theme_constant("line_spacing"), "%s: o respiro entre linhas da fala e do objetivo difere" % quando)


## 5. Os objetivos não rolam.
func _conferir_sem_rolagem(painel: Node, quando: String) -> void:
	var objetivos := painel.find_child("ColunaDosObjetivos", true, false) as ScrollContainer
	_conferir(objetivos != null, "%s: a página não tem a coluna dos objetivos" % quando)
	if objetivos == null:
		return
	var barra := objetivos.get_v_scroll_bar()
	_conferir(barra.max_value <= barra.page + 1.0, "%s: a coluna dos objetivos rola: conteúdo %.0f para %.0f de altura" % [quando, barra.max_value, barra.page])
	var botao := painel.find_child("Acompanhar", true, false) as Button
	var caixa := painel.find_child("Caixa", true, false) as Control
	if botao != null and caixa != null:
		_conferir(caixa.get_global_rect().encloses(botao.get_global_rect()), "%s: o botão Acompanhar sai da caixa do painel" % quando)


## A MESMA LETRA, e não o mesmo objeto: `Identidade.fonte_do_hud()` monta uma FontVariation nova a cada rótulo,
## então se comparam a fonte de base, as reservas e a variação.
func _mesma_fonte(a: Font, b: Font) -> bool:
	if a == b:
		return true
	if a is FontVariation and b is FontVariation:
		var va := a as FontVariation
		var vb := b as FontVariation
		var mesma_base: bool = va.base_font == vb.base_font and va.fallbacks == vb.fallbacks
		return mesma_base and va.variation_opentype == vb.variation_opentype and is_equal_approx(va.variation_embolden, vb.variation_embolden)
	return false


func _tecla(codigo: int) -> InputEventKey:
	var evento := InputEventKey.new()
	evento.physical_keycode = codigo
	evento.keycode = codigo
	evento.pressed = true
	return evento


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("DIARIO_MENU_OK: o menu da esquerda do Diário recolhe numa faixa e expande (botão, ▸ e Backspace), a escolha fica salva, a ficha ganha a largura, a fala e os objetivos têm a mesma letra de leitura, os objetivos não rolam em 1280×720 nem em 1920×1080, e o teclado segue")
	else:
		print("diario_menu_recolhivel: %d falha(s)" % falhas)
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
