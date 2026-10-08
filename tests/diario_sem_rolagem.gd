extends SceneTree
## Confere o DIÁRIO DE MISSÕES (J) QUE CABE NA TELA: sem coluna vazia, com a fala em
## resumo e o botão sempre à vista (#202).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/diario_sem_rolagem.gd
##
## A queixa: coluna das categorias com um item só, lista com duas missões, e a ficha
## espremida — a fala do Pedro em oito linhas de itálico empurrava os objetivos, o
## botão "Acompanhar" aparecia cortado pela borda e a ficha rolava. A regra: o modal
## quase nunca rola. Cinco perguntas:
##
##   1. O CORTE DA FALA é por frase inteira, cabe no limite e não mexe no que já é curto.
##   2. COM UMA ABA SÓ, a coluna das abas some e a página ganha a largura.
##   3. A FALA DA PÁGINA é o resumo, na sans de leitura (não na Cormorant itálica).
##   4. O BOTÃO ACOMPANHAR fica dentro da caixa do painel, inteiro, mesmo com a missão
##      cheia de objetivos cumpridos.
##   5. A FICHA NÃO ROLA: a coluna dos objetivos cabe sem barra de rolagem.

## Carregado no _run, não por preload: no --script o preload compila antes de os autoloads
## (o Afinidade da cadeia) virarem nomes globais, e o portão não abria.
var CadeiaDeMissoes: GDScript

var falhas := 0

const FALA_LONGA := "Toma. Esse tem mais idade que nós dois somados, e aguenta mais do que parece. Chega perto do tronco, encosta a mão e aperta E. Não precisa ter pressa nem força, que quem corta é a lâmina e não o braço. Depois volta aqui que eu te explico o resto, e traz o que sobrar do cavaco pra gente acender o fogo da casa."


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("DIARIO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	CadeiaDeMissoes = load("res://scripts/prototipo_3d/cadeia_de_missoes.gd")
	# --- 1. O CORTE DA FALA ----------------------------------------------------
	var curta := "Chega aqui. Aperta E."
	_conferir(CadeiaDeMissoes.fala_curta(curta) == curta, "a fala curta foi mexida")
	var cortada: String = CadeiaDeMissoes.fala_curta(FALA_LONGA)
	_conferir(cortada.length() <= CadeiaDeMissoes.LETRAS_DA_FALA_NO_DIARIO, "a fala cortada passa de %d letras: %d" % [CadeiaDeMissoes.LETRAS_DA_FALA_NO_DIARIO, cortada.length()])
	_conferir(cortada.ends_with(".") and FALA_LONGA.begins_with(cortada), "o corte não termina numa frase inteira: '%s'" % cortada)
	_conferir(cortada.contains("Toma."), "o corte perdeu a primeira frase")
	var sem_ponto := "Uma frase que não acaba nunca e continua e continua falando de tudo o que vem pela frente sem pontuação nenhuma pra segurar o fôlego de quem lê até que o texto passe, e muito, do limite da página do diário e ainda sobra bastante coisa pra dizer depois disso tudo"
	var palavra: String = CadeiaDeMissoes.fala_curta(sem_ponto)
	_conferir(palavra.ends_with("…") and palavra.length() <= CadeiaDeMissoes.LETRAS_DA_FALA_NO_DIARIO + 1, "sem frase para cortar, o corte não foi na palavra com reticência: '%s'" % palavra)

	# --- o vale e o painel ---------------------------------------------------
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
	var caderno = root.get_node("/root/CadernoDoVale")
	caderno.abrir_missao("diario_a", "A ponte do rio grande", "pedro", true, "Pedro: " + FALA_LONGA)
	caderno.descrever("diario_a", {
		"missao": "A ponte do rio grande", "quem": "Pedro", "resumo": "Encoste no tronco e aperte E (1/3)",
		"passo": 2, "passos": 5, "total": 3, "feito": 1,
		"fala_curta": CadeiaDeMissoes.fala_curta(FALA_LONGA),
		"feitos": ["Fale com o Pedro", "Pegue o machado na oficina", "Chegue até o tronco caído", "Corte a primeira tora"],
		"recompensa": {"reis": 12, "xp": 10},
	})
	vale.telas.fechar_tudo()
	await _frames(2)
	vale.telas.abrir("painel")
	await _frames(4)
	_conferir(painel.aberto, "o painel não abriu")
	var lista: Array = caderno.por_importancia()
	var indice := -1
	for i in lista.size():
		if str((lista[i] as Dictionary).get("id", "")) == "diario_a":
			indice = i
	_conferir(indice >= 0, "a missão de teste não entrou na lista")
	painel.escolher(maxi(indice, 0))
	await _frames(4)
	_conferir(painel.aba() == painel.Aba.MISSOES, "o painel não abriu em Missões")

	# --- 2. SEM COLUNA VAZIA -----------------------------------------------------
	var abas := painel.find_child("Abas", true, false) as Control
	if painel.abas_validas().size() == 1:
		_conferir(abas != null and not abas.visible, "com uma aba só, a coluna das abas continua à mostra")
	else:
		_conferir(abas != null and abas.visible and abas.custom_minimum_size.x < 200.0, "com várias abas, a coluna não encolheu no diário")

	# --- 3. A FALA É O RESUMO, EM LEITURA ------------------------------------------
	var fala := painel.find_child("Fala", true, false) as Label
	_conferir(fala != null, "a página não tem a fala")
	if fala != null:
		_conferir(fala.text.length() <= CadeiaDeMissoes.LETRAS_DA_FALA_NO_DIARIO + 2, "a fala da página não está em resumo: %d letras" % fala.text.length())
		var fonte := fala.get_theme_font("font") as FontVariation
		_conferir(fonte != null and fonte.base_font == ThemeDB.fallback_font, "a fala da página não está na sans de leitura")

	# --- 4. O BOTÃO NUNCA CORTADO --------------------------------------------------
	var caixa := painel.find_child("Caixa", true, false) as Control
	var botao := painel.find_child("Acompanhar", true, false) as Button
	_conferir(botao != null and caixa != null, "a página não tem o botão Acompanhar")
	if botao != null and caixa != null:
		var area := caixa.get_global_rect()
		var dele := botao.get_global_rect()
		_conferir(botao.is_visible_in_tree() and dele.size.y > 20.0, "o botão Acompanhar não aparece")
		_conferir(area.encloses(dele), "o botão Acompanhar sai da caixa do painel: botão %s, caixa %s" % [str(dele), str(area)])
		_conferir(root.get_visible_rect().encloses(dele), "o botão Acompanhar sai da janela")

	# --- 5. A FICHA NÃO ROLA ---------------------------------------------------------
	var objetivos := painel.find_child("ColunaDosObjetivos", true, false) as ScrollContainer
	_conferir(objetivos != null, "a página não tem a coluna dos objetivos")
	if objetivos != null:
		var barra := objetivos.get_v_scroll_bar()
		_conferir(barra.max_value <= barra.page + 1.0, "a coluna dos objetivos rola: conteúdo %.0f para %.0f de altura" % [barra.max_value, barra.page])

	caderno.concluir("diario_a")
	vale.telas.fechar_tudo()
	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("DIARIO_OK: a fala do diário é cortada em frase inteira, a coluna das abas some quando há uma só, a fala da página é o resumo na sans de leitura, o botão Acompanhar fica inteiro dentro da caixa e a coluna dos objetivos cabe sem rolagem")
	else:
		print("diario_sem_rolagem: %d falha(s)" % falhas)
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
