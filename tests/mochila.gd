extends SceneTree
## Confere A MOCHILA NO VALE (#2) — a tela que veio do 2D, sobre o 3D.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/mochila.gd
##
## A regra de dentro dela — trinta espaços, o que se veste, o que se come — é
## dos autoloads compartilhados, com portão no 2D. A tela também é arquivo do
## 2D (`scripts/ui/mochila.gd`), e não se mexe nela daqui: o vale a estende só
## no desenho (`mochila_vale.gd`, 07/10). O que este portão
## pergunta é o que o VALE tem de fazer para ela funcionar em cima do 3D:
##
##   1. O I ABRE E FECHA, pelo dono das telas, e o vale para atrás dela. O Esc
##      também fecha.
##   2. ELA FICA POR CIMA DO HUD e no tamanho de gente. Desenhada para os
##      640×360 do 2D, no vale de 1280×720 ela abria com metade do tamanho e
##      por baixo do HUD, que ficava com os cliques. Grade à esquerda, o que se
##      veste à direita, tudo dentro da janela.
##   3. O TECLADO FUNCIONA DENTRO DELA. Ela escuta as ações do `Controles` do
##      2D (`equipar`, `interagir`, `mover_*`, `cancelar`), que o vale não
##      tinha: sem elas, só o mouse funcionava. Aqui as setas andam o cursor,
##      o F veste o chapéu e come a banana, e o E pega e solta.
##   4. A RODA TROCA A MÃO, como no 2D; Ctrl+roda e +/- dão o zoom. Com a
##      mochila aberta, a roda não mexe na mão.
##   5. AS TECLAS DO 3D CONTINUAM: T, M, R, F, Tab, 1–0 e Alt+1–8 no mesmo
##      lugar, e o F de fora da mochila continua sendo o de observar.

const Atalhos = preload("res://scripts/prototipo_3d/atalhos.gd")
## A barra de mão se lê com `load` depois de o vale subir, e não com
## `preload`: ela cita o `Inventario`, e o `preload` a compilaria junto com
## este portão, antes de os autoloads existirem.
const BARRA_DE_MAO := "res://scripts/prototipo_3d/barra_de_mao.gd"

var falhas := 0
var mochila
var inventario
var equipamento


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("MOCHILA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	mochila = root.get_node("/root/Mochila")
	inventario = root.get_node("/root/Inventario")
	equipamento = root.get_node("/root/Equipamento")
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(6)
	await _mundo_pronto()
	await _frames(10)
	var vale = current_scene
	if vale == null or not ("player" in vale) or vale.get("telas") == null:
		_conferir(false, "o vale não ficou de pé com o dono das telas")
		_fechar()
		return
	var player = vale.player

	# --- 1. O I ABRE E FECHA ---------------------------------------------------
	_conferir(Atalhos.tecla("mochila") == KEY_I, "a mochila não está no I")
	await _tecla(KEY_I)
	_conferir(mochila.aberta, "o I não abriu a mochila")
	_conferir(not vale.hud_layer.is_visible_in_tree(), "a mochila deixa interfaces externas ao fundo")
	_conferir(paused, "a mochila abriu com o vale andando atrás dela")
	await _tecla(KEY_I)
	_conferir(not mochila.aberta, "o I não fechou a mochila")
	_conferir(vale.hud_layer.is_visible_in_tree(), "fechar a mochila não devolve o HUD")
	_conferir(not paused, "fechar a mochila deixou o vale parado")
	await _tecla(KEY_I)
	await _tecla(KEY_ESCAPE)
	_conferir(not mochila.aberta, "o Esc não fechou a mochila")

	# --- 2. POR CIMA DO HUD, NO TAMANHO DE GENTE -----------------------------
	_conferir(mochila.layer > vale.hud.layer,
		"a mochila está na camada %d e o HUD na %d: o HUD desenha por cima dela e fica com os cliques" % [mochila.layer, vale.hud.layer])
	vale.telas.abrir("mochila")
	await _frames(3)
	var tela: Rect2 = root.get_visible_rect()
	var painel := _painel_da_mochila()
	_conferir(painel != null, "a mochila não tem o painel de fundo")
	if painel != null:
		var caixa := _na_tela(painel.get_global_rect())
		_conferir(tela.encloses(caixa.grow(-1.0)),
			"a mochila sai da janela: %s numa tela de %s" % [str(caixa), str(tela.size)])
		var grade := _na_tela(mochila._grade.get_global_rect())
		var encaixes := _na_tela(mochila._encaixes_coluna.get_global_rect())
		_conferir(grade.end.x <= encaixes.position.x,
			"a grade não fica à esquerda do que se veste: grade até x=%.0f, encaixes desde x=%.0f" % [grade.end.x, encaixes.position.x])
		var espaco := _na_tela((mochila._molduras[0] as Control).get_global_rect())
		var largura_da_mao: float = load(BARRA_DE_MAO).LARGURA
		_conferir(espaco.size.x >= largura_da_mao * 0.8,
			"cada espaço da mochila tem %.0f px na tela, e o da barra de mão tem %.0f: ela abriu no tamanho do 2D" % [espaco.size.x, largura_da_mao])
		# EM ALTA E NA IDENTIDADE DO VALE (07/10): desenhada na tela do vale, e não o
		# quadro do 2D esticado; com a talha de ouro dos painéis dele.
		_conferir(mochila.transform.get_scale().x <= 1.05,
			"a mochila é ampliada %.2f vezes: é o quadro do 2D esticado, e a letra serrilha" % mochila.transform.get_scale().x)
		_conferir(mochila.get_node_or_null("Moldura") != null, "a mochila não tem a moldura de talha dos painéis do vale")
	vale.telas.fechar_tudo()
	await _frames(2)

	# --- 3. O TECLADO DENTRO DELA ---------------------------------------------
	for acao in ["equipar", "interagir", "cancelar", "mover_cima", "mover_baixo", "mover_esquerda", "mover_direita"]:
		_conferir(InputMap.has_action(acao), "o vale não registrou a ação '%s' que a mochila escuta" % acao)
	var chapeu_antes: String = equipamento.no_encaixe("cabeca")
	if chapeu_antes != "":
		equipamento.desequipar("cabeca")
	inventario.espacos[0] = {"id": "chapeu", "qtd": 1}
	inventario.espacos[1] = {"id": "banana", "qtd": 3}
	inventario.espacos[2] = {}
	inventario.mudou.emit()
	vale.telas.abrir("mochila")
	await _frames(2)
	_conferir(mochila._cursor == 0, "a mochila não abriu com o cursor no primeiro espaço")
	await _tecla(KEY_F)
	_conferir(equipamento.no_encaixe("cabeca") == "chapeu", "o F não vestiu o chapéu que estava sob o cursor")
	_conferir(inventario.vazio(0), "o chapéu foi vestido e continuou no espaço")
	await _tecla(KEY_RIGHT)
	_conferir(mochila._cursor == 1, "a seta para a direita não andou o cursor (está no %d)" % mochila._cursor)
	await _tecla(KEY_F)
	if int(inventario.espacos[1].get("qtd", 0)) == 3 and mochila._confirmar == "banana":
		await _tecla(KEY_F)   # o corpo estava cheio: o segundo F confirma
	_conferir(int(inventario.espacos[1].get("qtd", 0)) == 2, "o F não comeu a banana sob o cursor")
	await _tecla(KEY_E)
	await _tecla(KEY_D)
	await _tecla(KEY_E)
	_conferir(str(inventario.espacos[2].get("id", "")) == "banana", "E, D e E não levaram a banana para o espaço ao lado")
	await _tecla(KEY_ESCAPE)
	_conferir(not mochila.aberta, "o Esc não fechou a mochila depois de usar o teclado")

	# --- 4. A RODA DÁ ZOOM; NÃO TROCA O ITEM DA MÃO ---------------------------
	inventario.selecionar(0)
	var zoom: float = player._distance
	await _roda(MOUSE_BUTTON_WHEEL_DOWN, false)
	_conferir(inventario.selecionado == 0, "a roda para baixo trocou o item da mão")
	_conferir(player._distance > zoom, "a roda para baixo não afastou a câmera: %.2f → %.2f" % [zoom, player._distance])
	zoom = player._distance
	await _roda(MOUSE_BUTTON_WHEEL_UP, false)
	_conferir(inventario.selecionado == 0, "a roda para cima trocou o item da mão")
	_conferir(player._distance < zoom, "a roda para cima não aproximou a câmera: %.2f → %.2f" % [zoom, player._distance])
	await _roda(MOUSE_BUTTON_WHEEL_UP, true)
	_conferir(player._distance < zoom, "Ctrl+roda para cima não aproximou a câmera")
	_conferir(inventario.selecionado == 0, "Ctrl+roda trocou a mão")
	zoom = player._distance
	await _tecla(KEY_MINUS)
	_conferir(player._distance > zoom, "o - não afastou a câmera")
	zoom = player._distance
	await _tecla(KEY_EQUAL)
	_conferir(player._distance < zoom, "o + (tecla do igual) não aproximou a câmera")
	vale.telas.abrir("mochila")
	await _frames(2)
	await _roda(MOUSE_BUTTON_WHEEL_DOWN, false)
	_conferir(inventario.selecionado == 0, "com a mochila aberta, a roda trocou a mão")
	vale.telas.fechar_tudo()
	await _frames(2)

	# --- 5. AS TECLAS DO 3D CONTINUAM -----------------------------------------
	_conferir(_responde("mv_time", KEY_T), "o T não avança mais a hora")
	_conferir(_responde("mv_mapa", KEY_M), "o M não abre mais o mapa")
	_conferir(_responde("mv_reset", KEY_R), "o R não reinicia mais")
	_conferir(_responde("mv_inspect", KEY_F), "o F não observa mais")
	_conferir(_responde("mv_cursor", KEY_TAB), "o Tab não alterna mais a câmera")
	for i in 10:
		_conferir(_responde("mv_mao_%d" % (i + 1), KEY_1 + i if i < 9 else KEY_0),
			"o %d não põe mais o espaço %d na mão" % [(i + 1) % 10, i + 1])
	for i in 8:
		_conferir(_responde("mv_animation_%d" % (i + 1), KEY_1 + i, true), "o Alt+%d não faz mais o gesto" % (i + 1))
	# O F de fora é o de observar, e não veste nada.
	inventario.espacos[0] = {"id": "chapeu", "qtd": 1}
	equipamento.desequipar("cabeca")
	inventario.mudou.emit()
	var observando: bool = player.inspecting
	await _tecla(KEY_F)
	_conferir(player.inspecting != observando, "com a mochila fechada, o F não observou")
	_conferir(equipamento.no_encaixe("cabeca") == "", "com a mochila fechada, o F vestiu o chapéu")
	await _tecla(KEY_F)

	_fechar()


## O painel de fundo da mochila: o PanelContainer filho direto dela.
func _painel_da_mochila() -> Control:
	for filho in mochila.get_children():
		if filho is PanelContainer:
			return filho
	return null


## Retângulo do canvas da mochila levado para a tela, pela transformação da camada.
func _na_tela(caixa: Rect2) -> Rect2:
	var t: Transform2D = mochila.transform
	return Rect2(t * caixa.position, caixa.size * t.get_scale())


func _tecla(codigo: int) -> void:
	for apertada in [true, false]:
		var evento := InputEventKey.new()
		evento.physical_keycode = codigo
		evento.keycode = codigo
		evento.pressed = apertada
		Input.parse_input_event(evento)
		await _frames(2)


func _roda(botao: MouseButton, com_ctrl: bool) -> void:
	for apertada in [true, false]:
		var evento := InputEventMouseButton.new()
		evento.button_index = botao
		evento.pressed = apertada
		evento.ctrl_pressed = com_ctrl
		# No meio da tela, onde fica o vale e não o HUD: com o mouse preso, é
		# onde a roda de verdade acontece.
		evento.position = root.get_visible_rect().size * 0.5
		evento.global_position = evento.position
		Input.parse_input_event(evento)
		await _frames(2)


func _responde(acao: String, codigo: int, com_alt := false) -> bool:
	var evento := InputEventKey.new()
	evento.physical_keycode = codigo
	evento.alt_pressed = com_alt
	evento.pressed = true
	return InputMap.has_action(acao) and InputMap.event_is_action(evento, acao, true)


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("MOCHILA_OK: o I abre e fecha a mochila e o vale para atrás dela, ela fica por cima do HUD e cabe na janela no tamanho da barra de mão, com a grade à esquerda e o que se veste à direita, o teclado anda, veste, come e arruma dentro dela, a roda afasta e aproxima a câmera sem trocar o item da mão, e as teclas do 3D continuam no lugar")
	else:
		print("mochila: %d falha(s)" % falhas)
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
