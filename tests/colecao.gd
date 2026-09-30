extends SceneTree
## Confere a COLEÇÃO da tecla L no vale (#20, a parte da coleção).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/colecao.gd
##
## A regra é o `Colecao` compartilhado. Este portão pergunta o que é do vale:
##
##   1. OS DADOS SÃO OS DO 2D. `data/colecionaveis/` é cópia — o `Colecao` lê
##      `res://`, que aqui é a pasta do protótipo — e cópia é regra sem portão
##      se ninguém a confere (ver MIGRACAO_2D_3D.md). Byte a byte, contra o
##      original na raiz do repositório: o dono do cordel é o 2D.
##   2. O L É DA COLEÇÃO, e abrir para o jogador e o relógio como o painel.
##      Com ela aberta, o J não abre o painel por cima.
##   3. AS TRÊS COLEÇÕES, com a VAGA EM BRANCO de quem falta achar, e o Tab
##      girando entre elas.
##   4. O QUE SE ACHA APARECE: o cordel com título e preço, o sinal sem nome
##      até o encontro, e o bicho derrubado na luta com a conta de quantos
##      caíram — que é o que a luta (#14) não conseguia abrir sem os dados.

const ARQUIVOS := ["cordeis.json", "sinais.json", "bichos.json"]

var falhas := 0
var colecao_regra
var regra
var jogo
var dia
var vida


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("COLECAO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	colecao_regra = root.get_node("/root/Colecao")
	regra = root.get_node("/root/Luta")
	jogo = root.get_node("/root/Jogo")
	dia = root.get_node("/root/Dia")
	vida = root.get_node("/root/Vida")

	# --- 1. OS DADOS SÃO OS DO 2D ----------------------------------------------
	var raiz_do_2d := ProjectSettings.globalize_path("res://").path_join("../data/colecionaveis")
	for nome in ARQUIVOS:
		var copia := FileAccess.get_file_as_bytes("res://data/colecionaveis/" + nome)
		var original := FileAccess.get_file_as_bytes(raiz_do_2d.path_join(nome))
		_conferir(not copia.is_empty(), "o vale não tem data/colecionaveis/%s" % nome)
		_conferir(not original.is_empty(), "não achei o original do 2D: %s" % raiz_do_2d.path_join(nome))
		_conferir(copia == original,
			"data/colecionaveis/%s divergiu do 2D: o dono é o 2D, copie de lá de novo" % nome)

	# --- 2. O L É DA COLEÇÃO ---------------------------------------------------
	var Atalhos = load("res://scripts/prototipo_3d/atalhos.gd")
	_conferir(Atalhos.tecla("colecao") == KEY_L, "a coleção não está no L")
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(6)
	await _mundo_pronto()
	await _frames(10)
	var vale = current_scene
	var player = vale.player
	var tela = vale.get_node_or_null("Colecao")
	_conferir(tela != null, "o vale não montou a coleção")
	if tela == null:
		_fechar()
		return
	dia.pausado = false
	vale.abrir_a_colecao()
	await _frames(2)
	_conferir(tela.aberta and tela.visible, "abrir_a_colecao não abriu a coleção")
	_conferir(tela.layer > vale.hud.layer, "a coleção ficou por baixo do HUD")
	_conferir(not player.is_physics_processing(), "com a coleção aberta o jogador continua andando")
	_conferir(dia.pausado, "com a coleção aberta o relógio continua andando")
	_conferir(vida.esta_lendo.call(), "a peçonha não sabe que o jogador está lendo a coleção")
	vale._unhandled_key_input(_evento(KEY_J))
	_conferir(not vale.painel.aberto, "com a coleção aberta, o J abriu o painel por cima")

	# --- 3. AS TRÊS COLEÇÕES, COM A VAGA EM BRANCO -----------------------------
	_conferir(tela.colecao() == "cordeis", "a coleção não abre nos cordéis")
	var total: int = colecao_regra.total("cordeis")
	_conferir(total > 0, "os cordéis estão vazios: os dados não chegaram")
	_conferir(tela._linhas.size() == total, "a lista tem %d linhas e há %d cordéis" % [tela._linhas.size(), total])
	var em_branco := 0
	for linha in tela._linhas:
		if linha.text.contains("— — —"):
			em_branco += 1
	_conferir(em_branco == total, "sem nada achado, só %d de %d vagas em branco" % [em_branco, total])
	var vistas := [tela.colecao()]
	for i in 3:
		tela._unhandled_input(_evento(KEY_TAB))
		vistas.append(tela.colecao())
	_conferir(vistas == ["cordeis", "sinais", "bichos", "cordeis"], "o Tab girou por %s" % str(vistas))

	# --- 4. O QUE SE ACHA APARECE ----------------------------------------------
	var cordel := str(colecao_regra.ordem("cordeis")[0])
	var dado: Dictionary = colecao_regra.dados("cordeis", cordel)
	var reis: int = jogo.dinheiro
	colecao_regra.achar("cordeis", cordel)
	await _frames(1)
	_conferir(jogo.dinheiro == reis + int(dado.get("valor", 0)), "achar o cordel não pagou o valor dele")
	_conferir(tela._linhas[0].text.contains(str(dado.get("titulo", ""))), "o cordel achado não saiu da vaga em branco")
	var ficha: String = tela.ficha(cordel)
	_conferir(ficha.contains(str(dado.get("titulo", ""))) and ficha.contains("réis"), "a ficha do cordel não diz o que é e quanto vale")

	tela.proxima_colecao()
	var sinal := str(colecao_regra.ordem("sinais")[0])
	colecao_regra.achar("sinais", sinal)
	await _frames(1)
	if not colecao_regra.nomeia("sinais", sinal):
		_conferir(tela.ficha(sinal).contains("não sabe de quem era"), "o sinal diz de quem é antes do encontro")

	tela.proxima_colecao()
	regra.acertou.emit("golpe", "caititu", true, false)
	await _frames(1)
	_conferir(colecao_regra.tem("bichos", "caititu"), "derrubar o caititu não abriu a página dele")
	_conferir(tela.ficha("caititu").contains("Já caíram: %d" % regra.abatidos("caititu")), "a página do caititu não conta quantos caíram")

	tela._unhandled_input(_evento(Atalhos.tecla("colecao")))
	await _frames(2)
	_conferir(not tela.aberta, "o L não fechou a coleção")
	_conferir(player.is_physics_processing(), "fechou a coleção e o jogador continuou parado")
	_conferir(not dia.pausado, "fechou a coleção e o relógio continuou parado")
	_fechar()


func _evento(codigo: int) -> InputEventKey:
	var evento := InputEventKey.new()
	evento.physical_keycode = codigo
	evento.keycode = codigo
	evento.pressed = true
	return evento


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("COLECAO_OK: os dados são os do 2D byte a byte; o L abre para o jogador e o relógio, sem painel por cima; três coleções com a vaga em branco e o Tab girando; o cordel achado mostra título e preço, o sinal não tem nome antes do encontro, e o bicho derrubado abre a página com a conta")
	else:
		print("colecao: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _mundo_pronto() -> void:
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
