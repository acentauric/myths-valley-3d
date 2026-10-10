extends SceneTree
## Confere O SEGUNDO TUTORIAL — o quintal e o pomar (docs/projeto/MISSOES_DO_2D.md, 2;
## data/missoes_quintal.json; scripts/prototipo_3d/curral_vale.gd; #160).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/quintal.gd
##
## Oito perguntas:
##
##   1. A FILA ESPERA A SEXTA COLHEITA: com o tutorial acabado e cinco colheitas, ela não
##      começa; com seis, começa sozinha, como no 2D — sem E e sem aviso de fila trancada.
##   2. O POMAR: o passo entrega as mudas (duas de bananeira, uma de mangueira), e plantar
##      uma fruteira na lavoura fecha o passo e paga os beijus. Plantar mandioca não fecha.
##   3. O TALENTO: o passo do curral fecha quando o nó Curral sai da teia — e no mesmo
##      instante o galinheiro está de pé no quintal, com três galinhas, no lugar que o
##      `Lugares` promete ("galinheiro"), em terra firme, e com três ovos no ninho.
##   4. OS OVOS: o E no galinheiro recolhe os três; recolher de novo não dá nada ("volte
##      amanhã"); no dia seguinte há três de novo; e dois ovos fecharam o passo, com as
##      cocadas.
##   5. O CAPATAZ: falar com o Cosme fecha o passo (a resposta é dele); dormir fecha a
##      manhã, e a mandioca e a lenha entram na mochila, pagas por ele; a fila acaba.
##   6. O FOCO: ao lado do galinheiro, o E é do curral (`alvo_do_e`), e não de outra coisa.
##   7. O SAVE: o ninho, o dia da postura e o dia de serviço do Cosme vão e voltam; a lavoura leva a conta das colheitas.
##   8. A LÍNGUA: a dica do galinheiro sai nos três idiomas.
var falhas := 0
var vale
var pedro
var tecla
var inv
var dialogo


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("QUINTAL_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	vale = current_scene
	# O ACEITE É AUTOMÁTICO AQUI (08/10): este portão abre filas pelo E e segue; a tela de aceite
	# pausaria o vale no meio da medida (a tela tem portão próprio, tests/missao_a_vista.gd).
	if vale.get("aceite") != null:
		vale.aceite.automatico = true
	pedro = vale.get("pedro")
	tecla = vale.get("tecla_dos_moradores")
	inv = root.get_node("/root/Inventario")
	dialogo = root.get_node("/root/Dialogo")
	var jogador = vale.player
	var lavoura = vale.get("lavoura")
	var curral = vale.get("curral")
	var talentos = root.get_node("/root/Talentos")
	var relogio = root.get_node("/root/Relogio")
	var lugares = root.get_node("/root/Lugares")
	var mundo = vale.world
	root.get_node("/root/Dia").pausado = true
	var fila = vale._cadeias.get("pedro_quintal")
	var cosme = vale._achar_morador("cosme")
	_conferir(fila != null and lavoura != null and curral != null and pedro != null and cosme != null,
		"o vale não montou o quintal: fila %s, lavoura %s, curral %s, Pedro %s, Cosme %s" % [str(fila), str(lavoura), str(curral), str(pedro), str(cosme)])
	if fila == null or lavoura == null or curral == null or pedro == null or cosme == null:
		_fechar()
		return
	# A âncora do galinheiro fica posta desde o começo, levantado ou não.
	_conferir(lugares.resolve("galinheiro") and lugares.resolve("curral"), "o Lugares não resolve 'galinheiro' antes de o galinheiro subir")
	_conferir(not curral.levantado(), "o galinheiro está de pé sem o talento Curral")
	_conferir(mundo.is_on_land(curral.lugar()), "o lugar do galinheiro (%s) não é terra firme" % str(curral.lugar()))
	_conferir(curral.lugar().distance_to(mundo.ancoras.get("Casa de taipa", Vector3.INF)) < 12.0, "o galinheiro ficou longe da casa de taipa")

	# --- 1. A FILA ESPERA A SEXTA COLHEITA ---------------------------------------------------
	pedro.missao = pedro.MISSOES.size()
	pedro.set("_despedida_feita", true)
	lavoura.colheitas = 5
	await _ate(func() -> bool: return false, 1.5)
	_conferir(not fila.iniciado, "com cinco colheitas a fila do quintal começou")
	_conferir(not fila.esta_trancada() and str(fila.dica_da_trancada()) == "", "a fila do quintal é de aviso de fila trancada, e o Pedro já tem o da chapada a dar")
	jogador.teleportar(pedro.global_position + Vector3(1.0, 0.1, 0.6), 0.0)
	lavoura.colheitas = 6
	_conferir(await _ate(func() -> bool: return fila.iniciado, 6.0), "com seis colheitas a fila do quintal não começou sozinha")
	if not fila.iniciado:
		_fechar()
		return
	await _ate(func() -> bool: return fila.espera <= 0.0, 12.0)

	# --- 2. O POMAR ------------------------------------------------------------------------------
	_conferir(str(fila.passo_atual().get("id", "")) == "pomar", "o quintal não começou pelo pomar: '%s'" % str(fila.passo_atual().get("id", "")))
	_conferir(inv.quantidade("muda_bananeira") >= 2 and inv.quantidade("muda_mangueira") >= 1,
		"o pomar não entregou as mudas (bananeira %d, mangueira %d)" % [inv.quantidade("muda_bananeira"), inv.quantidade("muda_mangueira")])
	var beijus: int = inv.quantidade("beiju")
	var plantacao = lavoura.plantacao
	# Mandioca não fecha o pomar.
	plantacao.arar(Vector2i(0, 0))
	plantacao.plantar(Vector2i(0, 0), "mandioca")
	lavoura.plantou_cultura.emit("mandioca")
	await _quadros(4)
	_conferir(str(fila.passo_atual().get("id", "")) == "pomar", "plantar mandioca fechou o pomar")
	# A bananeira, pela tecla da lavoura: a muda na mão, o leito arado.
	plantacao.arar(Vector2i(1, 0))
	_conferir(_por_na_mao("muda_bananeira"), "não achei a muda de bananeira na mochila para pôr na mão")
	lavoura.usar(Vector2i(1, 0))
	_conferir(await _ate(func() -> bool: return str(fila.passo_atual().get("id", "")) != "pomar", 6.0), "plantar a bananeira não fechou o pomar")
	_conferir(plantacao.plantado(Vector2i(1, 0)) and plantacao.cultura_em(Vector2i(1, 0)) == "bananeira", "a bananeira não ficou no leito")
	_conferir(inv.quantidade("beiju") == beijus + 2, "o pomar não pagou os dois beijus")
	inv.selecionar(inv.MAO_LIVRE)

	# --- 3. O TALENTO ------------------------------------------------------------------------------
	await _ate(func() -> bool: return fila.espera <= 0.0, 12.0)
	_conferir(str(fila.passo_atual().get("id", "")) == "curral_aprender", "depois do pomar não veio o curral: '%s'" % str(fila.passo_atual().get("id", "")))
	_conferir(not curral.levantado(), "o galinheiro subiu antes do talento")
	talentos.pontos = maxi(int(talentos.pontos), 1)
	_conferir(talentos.pode("curral"), "o nó Curral não pode ser destravado com um ponto: %s" % str(talentos.impedimento("curral")))
	talentos.destravar("curral")
	_conferir(await _ate(func() -> bool: return str(fila.passo_atual().get("id", "")) == "curral", 8.0), "destravar o Curral não fechou o passo do talento: '%s'" % str(fila.passo_atual().get("id", "")))
	_conferir(curral.levantado(), "o talento Curral não levantou o galinheiro")
	_conferir(curral.galinhas() == 3, "o galinheiro tem %d galinhas, e eram 3" % curral.galinhas())
	_conferir(mundo.ancoras.get("Galinheiro", Vector3.INF) == curral.lugar(), "a âncora do galinheiro não é o lugar dele")
	_conferir(curral.ovos == 3, "o ninho começou com %d ovos, e eram 3" % curral.ovos)
	var galinheiro: Node3D = curral.get_node_or_null("Galinheiro")
	_conferir(galinheiro != null and galinheiro.global_position.distance_to(curral.lugar()) < 1.5, "o modelo do galinheiro não está no lugar do curral")

	# --- 4 e 6. OS OVOS E O FOCO ---------------------------------------------------------------------
	await _ate(func() -> bool: return fila.espera <= 0.0, 12.0)
	var lugar: Vector3 = curral.lugar()
	jogador.teleportar(lugar + Vector3(1.4, 0.1, 0.0), -PI * 0.5)
	await _quadros(4)
	_conferir(not curral.alvo_do_e().is_empty(), "ao lado do galinheiro o curral não responde ao E")
	var foco = get_first_node_in_group("foco_do_e")
	_conferir(foco != null and foco.dono() == curral, "ao lado do galinheiro o E é de %s, e não do curral" % (str(foco.dono()) if foco != null else "?"))
	var cocadas: int = inv.quantidade("cocada")
	var ovos_antes: int = inv.quantidade("ovo")
	_conferir(curral.recolher() == 3, "o E no galinheiro não recolheu os três ovos")
	_conferir(inv.quantidade("ovo") == ovos_antes + 3, "os ovos não entraram na mochila")
	_conferir(curral.recolher() == 0 and curral.ovos == 0, "recolher de novo no mesmo dia deu ovo")
	_conferir(await _ate(func() -> bool: return str(fila.passo_atual().get("id", "")) == "capataz", 8.0), "dois ovos não fecharam o passo do curral: '%s'" % str(fila.passo_atual().get("id", "")))
	_conferir(inv.quantidade("cocada") == cocadas + 2, "o curral não pagou as duas cocadas")
	# O dia seguinte: a postura.
	relogio.dia += 1
	relogio.dia_comecou.emit(relogio.dia, 0, 1)
	await _quadros(3)
	_conferir(curral.ovos == 3, "no dia seguinte o ninho tem %d ovos, e eram 3" % curral.ovos)
	relogio.dia += 1
	relogio.dia_comecou.emit(relogio.dia, 0, 1)
	await _quadros(3)
	_conferir(curral.ovos == 6, "dois dias sem recolher deram %d ovos, e o teto é 6" % curral.ovos)
	relogio.dia += 1
	relogio.dia_comecou.emit(relogio.dia, 0, 1)
	await _quadros(3)
	_conferir(curral.ovos == 6, "o ninho passou do teto: %d" % curral.ovos)

	# --- 5. O CAPATAZ ----------------------------------------------------------------------------------
	await _ate(func() -> bool: return fila.espera <= 0.0, 12.0)
	for i in 3:
		jogador.teleportar(cosme.global_position + Vector3(1.0, 0.1, 0.6), 0.0)
		await _quadros(3)
		tecla.usar(cosme)
		await _ate(func() -> bool: return str(fila.passo_atual().get("id", "")) == "capataz_manha", 2.0)
		if str(fila.passo_atual().get("id", "")) == "capataz_manha":
			break
		await _fechar_a_fala()
	_conferir(str(fila.passo_atual().get("id", "")) == "capataz_manha", "falar com o Cosme não fechou o capataz: '%s'" % str(fila.passo_atual().get("id", "")))
	await _fechar_a_fala()
	await _ate(func() -> bool: return fila.espera <= 0.0, 12.0)
	var mandioca: int = inv.quantidade("mandioca")
	var lenha: int = inv.quantidade("lenha")
	vale._ao_deitar("cama")
	_conferir(await _ate(func() -> bool: return fila.acabou(), 8.0), "dormir não fechou a manhã do capataz")
	_conferir(inv.quantidade("mandioca") == mandioca + 4 and inv.quantidade("lenha") == lenha + 2,
		"a manhã do capataz não trouxe a mandioca e a lenha (mandioca %d→%d, lenha %d→%d)" % [mandioca, inv.quantidade("mandioca"), lenha, inv.quantidade("lenha")])

	# --- 7. O SAVE ---------------------------------------------------------------------------------------
	var estado: Dictionary = vale.estado_para_salvar()
	_conferir((estado.get("curral", {}) as Dictionary).get("ovos", -1) == 6, "o save não leva os ovos do ninho: %s" % str(estado.get("curral")))
	_conferir(int((estado.get("lavoura", {}) as Dictionary).get("colheitas", -1)) == 6, "o save não leva a conta das colheitas: %s" % str((estado.get("lavoura", {}) as Dictionary).get("colheitas")))
	# O DIA DE SERVIÇO DO COSME vai no save com o ninho (servico_do_morador.gd): a manhã do capataz contou um.
	_conferir(int(((estado.get("curral", {}) as Dictionary).get("servico", {}) as Dictionary).get("cosme", 0)) == 1,
		"o save não leva o dia de serviço do Cosme: %s" % str((estado.get("curral", {}) as Dictionary).get("servico")))
	curral.restaurar({"ovos": 2, "dia_da_postura": relogio.dia_absoluto()})
	_conferir(curral.ovos == 2, "restaurar o ninho não trouxe os dois ovos")

	# --- 8. A LÍNGUA -----------------------------------------------------------------------------------
	var textos = JSON.parse_string(FileAccess.get_file_as_string("res://data/quintal.json"))
	var recolher: Dictionary = ((textos as Dictionary).get("acoes", {}) as Dictionary).get("recolher", {})
	_conferir(str(recolher.get("texto", "")).contains("%d") and str(recolher.get("texto_en", "")).contains("%d") and str(recolher.get("texto_es", "")).contains("%d"),
		"a dica do galinheiro não tem a conta nos três idiomas")
	_fechar()


## Põe o item na mão pela mochila (o índice do espaço dele).
func _por_na_mao(id: String) -> bool:
	for i in inv.espacos.size():
		var espaco: Dictionary = inv.espacos[i]
		if str(espaco.get("id", "")) == id:
			inv.selecionar(i)
			return inv.na_mao() == id
	return false


func _fechar_a_fala() -> void:
	var ate := Time.get_ticks_msec() + 6000
	while dialogo.ativo and Time.get_ticks_msec() < ate:
		dialogo._fechar()
		await process_frame
	await _quadros(3)


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("QUINTAL_OK: a fila do quintal espera a sexta colheita e começa sozinha nela; o pomar entrega as mudas e fecha com a fruteira plantada, pagando os beijus; o talento Curral levanta o galinheiro com três galinhas e três ovos, no lugar que o Lugares promete; o E recolhe os ovos, uma vez por dia, com o ninho no teto de seis; dois ovos pagam as cocadas; o Cosme aceita o dia de roçado e a manhã traz a mandioca e a lenha; o save leva o ninho e a conta das colheitas; e a dica sai nos três idiomas")
	else:
		print("quintal: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


## Roda quadros até `condicao` valer, com teto em SEGUNDO REAL.
func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicao.call():
			return true
		await process_frame
	return condicao.call()


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
