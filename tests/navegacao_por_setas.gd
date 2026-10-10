extends "res://tests/suite/caso.gd"
## AS SETAS NAVEGAM NOS PAINÉIS COM LISTA, E O ENTER CONFIRMA COMO O E (#227).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste navegacao_por_setas
##
## Na Oficina (painel do J) só W/S moviam a seleção; as setas, o jeito natural de andar num menu, ficavam mudas
## (o painel escutava as ações de movimento, e elas seguem "Teclas de movimento" de Ajustes: WASD no padrão), embora
## a Teia de talentos e o Almanaque já as aceitassem. Cinco perguntas:
##
##   1. O COMANDO: `TeclasDeLista` entende as setas (fixas), W/S/A/D pelas ações de movimento, o Enter, o Enter do
##      teclado numérico, o direcional e o A do controle; a tecla segurada (eco) e o que não é de lista, não.
##   2. A OFICINA: ↑↓ andam nas receitas (com a volta), ←→ trocam de aba como A/D, e W/S continuam valendo.
##   3. O DIÁRIO e as VAGAS: ↑↓ andam; o Enter acompanha a missão como o E; o E remapeado segue confirmando.
##   4. A MOCHILA: as setas andam o cursor (a mochila escuta ações que as têm de fábrica) e o Enter pega como o E.
##   5. OS RODAPÉS dizem as duas formas ("[↑↓ ou W/S] escolher · [E ou Enter]"), nos idiomas do jogo, e nenhum
##      rodapé de lista do painel fica só com "[W/S]".

var falhas := 0
var TeclasDeLista: GDScript


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("NAVEGACAO_POR_SETAS_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	TeclasDeLista = load("res://scripts/prototipo_3d/teclas_de_lista.gd")
	var teclas_movimento: GDScript = load("res://scripts/prototipo_3d/teclas_movimento.gd")
	# O padrão de fábrica (só WASD): é com ele que a Oficina ignorava as setas.
	teclas_movimento.aplicar()

	# --- 1. O COMANDO ---------------------------------------------------------------------------------
	_conferir(TeclasDeLista.comando(_tecla(KEY_UP)) == TeclasDeLista.CIMA, "a seta para cima não é CIMA")
	_conferir(TeclasDeLista.comando(_tecla(KEY_DOWN)) == TeclasDeLista.BAIXO, "a seta para baixo não é BAIXO")
	_conferir(TeclasDeLista.comando(_tecla(KEY_LEFT)) == TeclasDeLista.ESQUERDA, "a seta para a esquerda não é ESQUERDA")
	_conferir(TeclasDeLista.comando(_tecla(KEY_RIGHT)) == TeclasDeLista.DIREITA, "a seta para a direita não é DIREITA")
	_conferir(TeclasDeLista.comando(_tecla(KEY_ENTER)) == TeclasDeLista.CONFIRMAR, "o Enter não confirma")
	_conferir(TeclasDeLista.comando(_tecla(KEY_KP_ENTER)) == TeclasDeLista.CONFIRMAR, "o Enter do teclado numérico não confirma")
	_conferir(TeclasDeLista.comando(_tecla(KEY_W)) == TeclasDeLista.CIMA, "o W (ação de movimento) deixou de escolher")
	_conferir(TeclasDeLista.comando(_tecla(KEY_S)) == TeclasDeLista.BAIXO, "o S (ação de movimento) deixou de escolher")
	_conferir(TeclasDeLista.comando(_tecla(KEY_A)) == TeclasDeLista.ESQUERDA, "o A (ação de movimento) deixou de trocar")
	_conferir(TeclasDeLista.comando(_tecla(KEY_D)) == TeclasDeLista.DIREITA, "o D (ação de movimento) deixou de trocar")
	_conferir(TeclasDeLista.comando(_tecla(KEY_DOWN, true, true)) == "", "a seta segurada (eco) pulou linhas")
	_conferir(TeclasDeLista.comando(_tecla(KEY_DOWN, false)) == "", "soltar a seta virou comando")
	_conferir(TeclasDeLista.comando(_tecla(KEY_Q)) == "" and TeclasDeLista.comando(_tecla(KEY_SPACE)) == "", "uma tecla qualquer virou comando de lista")
	_conferir(TeclasDeLista.comando(_botao(JOY_BUTTON_DPAD_UP)) == TeclasDeLista.CIMA, "o direcional para cima do controle não é CIMA")
	_conferir(TeclasDeLista.comando(_botao(JOY_BUTTON_DPAD_DOWN)) == TeclasDeLista.BAIXO, "o direcional para baixo do controle não é BAIXO")
	_conferir(TeclasDeLista.comando(_botao(JOY_BUTTON_DPAD_LEFT)) == TeclasDeLista.ESQUERDA, "o direcional para a esquerda do controle não é ESQUERDA")
	_conferir(TeclasDeLista.comando(_botao(JOY_BUTTON_DPAD_RIGHT)) == TeclasDeLista.DIREITA, "o direcional para a direita do controle não é DIREITA")
	_conferir(TeclasDeLista.comando(_botao(JOY_BUTTON_A)) == TeclasDeLista.CONFIRMAR, "o botão A do controle não confirma")

	# --- 5. OS RODAPÉS (estático) -------------------------------------------------------------------
	var codigo := FileAccess.get_file_as_string("res://scripts/prototipo_3d/painel_vale.gd")
	_conferir(not codigo.contains("[W/S]"), "o painel ainda tem rodapé só com [W/S]")
	_conferir(codigo.count("[↑↓ ou W/S] escolher") >= 6, "os rodapés de lista do painel não dizem as duas formas")
	var idioma: GDScript = load("res://scripts/prototipo_3d/idioma_menu.gd")
	var rodapes: Array[String] = []
	var cursor := 0
	while true:
		var achou := codigo.find("\"[↑↓ ou W/S] escolher", cursor)
		if achou < 0:
			break
		var fim := codigo.find("\"", achou + 1)
		rodapes.append(codigo.substr(achou + 1, fim - achou - 1))
		cursor = fim
	_conferir(rodapes.size() >= 6, "não achei os rodapés de lista do painel (%d)" % rodapes.size())
	for rodape in rodapes:
		_conferir(idioma.EN.has(rodape) and idioma.ES.has(rodape), "o rodapé '%s' não está em inglês e espanhol" % rodape)
		_conferir(idioma.EN.get(rodape, "").contains("↑↓ or W/S") and idioma.ES.get(rodape, "").contains("↑↓ o W/S"), "o rodapé '%s' perdeu as duas formas na tradução" % rodape)
	for arquivo in ["res://data/saveiro.json", "res://data/vagas_no_jogo.json"]:
		var texto := FileAccess.get_file_as_string(arquivo)
		_conferir(not texto.contains("[W/S]") and texto.count("↑↓ ou W/S") >= 1 and texto.contains("↑↓ or W/S") and texto.contains("↑↓ o W/S"),
			"%s: o rodapé não diz as duas formas nos três idiomas" % arquivo)

	# --- 2 a 4. NO VALE -------------------------------------------------------------------------------
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(3)
	var jogo := current_scene
	var painel = jogo.get("painel")
	_conferir(painel != null, "não achei o painel (J) no vale")
	if painel == null:
		_fechar()
		return
	var Aba = painel.get_script().Aba
	var oficina: Node = root.get_node("/root/Oficina")
	var caderno: Node = root.get_node("/root/CadernoDoVale")

	# 2. A Oficina.
	_conferir(oficina.receitas().size() >= 2, "a Oficina precisa de duas receitas sabidas para o portão (%d)" % oficina.receitas().size())
	painel.obra_em_foco = "oficina"
	painel.abrir(Aba.OFICINA)
	_conferir(painel._cursor == 0 and painel.aba() == Aba.OFICINA, "a Oficina não abriu no primeiro item")
	painel._unhandled_input(_tecla(KEY_DOWN))
	_conferir(painel._cursor == 1, "a seta para baixo não escolheu a receita seguinte (cursor %d)" % painel._cursor)
	painel._unhandled_input(_tecla(KEY_UP))
	_conferir(painel._cursor == 0, "a seta para cima não voltou à receita anterior (cursor %d)" % painel._cursor)
	painel._unhandled_input(_tecla(KEY_UP))
	_conferir(painel._cursor == oficina.receitas().size() - 1, "a seta para cima no alto da lista não deu a volta (cursor %d)" % painel._cursor)
	painel._cursor = 0
	painel._unhandled_input(_tecla(KEY_S))
	_conferir(painel._cursor == 1, "o S deixou de escolher na Oficina (cursor %d)" % painel._cursor)
	painel._unhandled_input(_tecla(KEY_W))
	_conferir(painel._cursor == 0, "o W deixou de escolher na Oficina (cursor %d)" % painel._cursor)
	painel._unhandled_input(_botao(JOY_BUTTON_DPAD_DOWN))
	_conferir(painel._cursor == 1, "o direcional do controle não escolheu na Oficina (cursor %d)" % painel._cursor)
	painel._cursor = 0
	# ←→ trocam de aba como A/D (a coluna da esquerda do painel).
	var aba_antes: int = painel.aba()
	painel._unhandled_input(_tecla(KEY_RIGHT))
	var depois_da_direita: int = painel.aba()
	_conferir(depois_da_direita != aba_antes, "a seta para a direita não trocou de aba")
	painel._unhandled_input(_tecla(KEY_LEFT))
	_conferir(painel.aba() == aba_antes, "a seta para a esquerda não voltou à aba")
	painel._unhandled_input(_tecla(KEY_D))
	_conferir(painel.aba() == depois_da_direita, "o D deixou de trocar de aba")
	painel.fechar()
	painel.obra_em_foco = ""

	# 3. O Diário (missões) e as Vagas.
	caderno.limpar()
	caderno.abrir_missao("portao_setas_a", "Primeira do portão")
	caderno.abrir_missao("portao_setas_b", "Segunda do portão")
	painel.abrir(Aba.MISSOES)
	var lista: Array = caderno.por_importancia()
	_conferir(lista.size() >= 2, "o Diário precisa de duas missões para o portão (%d)" % lista.size())
	painel._cursor = 0
	painel._unhandled_input(_tecla(KEY_DOWN))
	_conferir(painel._cursor == 1, "a seta para baixo não escolheu a missão seguinte no Diário (cursor %d)" % painel._cursor)
	var escolhida := str((caderno.por_importancia()[1] as Dictionary).get("id", ""))
	painel._unhandled_input(_tecla(KEY_ENTER))
	_conferir(caderno.acompanhada(escolhida), "o Enter não acompanhou a missão escolhida, como o E")
	painel._unhandled_input(_tecla(KEY_UP))
	var outra := str((caderno.por_importancia()[0] as Dictionary).get("id", ""))
	painel._unhandled_input(_tecla(KEY_E))
	_conferir(caderno.acompanhada(outra), "o E deixou de acompanhar a missão escolhida")
	painel.fechar()
	caderno.limpar()
	painel.abrir(Aba.VAGAS)
	painel._cursor = 0
	painel._unhandled_input(_tecla(KEY_DOWN))
	_conferir(painel._cursor == 1, "a seta para baixo não escolheu a vaga seguinte (cursor %d)" % painel._cursor)
	painel._unhandled_input(_tecla(KEY_UP))
	_conferir(painel._cursor == 0, "a seta para cima não voltou à vaga anterior (cursor %d)" % painel._cursor)
	painel.fechar()

	# 4. A Mochila: abre pelo I, as setas andam o cursor e o Enter pega como o E.
	var mochila: Node = root.get_node("/root/Mochila")
	await _enviar(_tecla(KEY_I))
	await _enviar(_tecla(KEY_I, false))
	await _frames(2)
	_conferir(bool(mochila.get("aberta")), "o I não abriu a mochila para o portão")
	if bool(mochila.get("aberta")):
		_conferir(int(mochila._cursor) == 0, "a mochila não abriu com o cursor no primeiro espaço")
		await _enviar(_tecla(KEY_RIGHT))
		await _enviar(_tecla(KEY_RIGHT, false))
		await _frames(2)
		_conferir(int(mochila._cursor) == 1, "a seta para a direita não andou o cursor da mochila (%d)" % int(mochila._cursor))
		await _enviar(_tecla(KEY_DOWN))
		await _enviar(_tecla(KEY_DOWN, false))
		await _frames(2)
		_conferir(int(mochila._cursor) > 1, "a seta para baixo não andou o cursor da mochila (%d)" % int(mochila._cursor))
		await _enviar(_tecla(KEY_UP))
		await _enviar(_tecla(KEY_UP, false))
		await _frames(2)
		_conferir(int(mochila._cursor) == 1, "a seta para cima não voltou o cursor da mochila (%d)" % int(mochila._cursor))
		# O Enter pega como o E — se há o que pegar no espaço (a mochila do começo pode ter o 2 vazio).
		var inventario: Node = root.get_node("/root/Inventario")
		var tinha_item: bool = not inventario.vazio(1)
		await _enviar(_tecla(KEY_ENTER))
		await _enviar(_tecla(KEY_ENTER, false))
		await _frames(2)
		if tinha_item:
			_conferir(int(mochila._pego) == 1, "o Enter não pegou o item da mochila como o E (pego %d)" % int(mochila._pego))
		await _enviar(_tecla(KEY_ESCAPE))
		await _enviar(_tecla(KEY_ESCAPE, false))
		await _frames(2)
	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("NAVEGACAO_POR_SETAS_OK: as setas, o Enter e o direcional escolhem e confirmam na Oficina, no Diário, nas Vagas e na Mochila junto com W/S/A/D e o E, as teclas seguradas não pulam linhas, e os rodapés dizem as duas formas nos três idiomas")
	else:
		print("navegacao_por_setas: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _tecla(codigo: int, apertada: bool = true, eco: bool = false) -> InputEventKey:
	var evento := InputEventKey.new()
	evento.physical_keycode = codigo
	evento.keycode = codigo
	evento.pressed = apertada
	evento.echo = eco
	return evento


func _botao(indice: int) -> InputEventJoypadButton:
	var evento := InputEventJoypadButton.new()
	evento.button_index = indice
	evento.pressed = true
	return evento


func _enviar(evento: InputEvent) -> void:
	Input.parse_input_event(evento)
	await process_frame


func _frames(quantos: int) -> void:
	for i in quantos:
		await process_frame


func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
