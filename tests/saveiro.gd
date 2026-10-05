extends SceneTree
## Confere O SAVEIRO DO MESTRE QUIRINO e a missão da piaçava.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/saveiro.gd
##
## "Introduza uma missão de venda de piaçava 1x por mês para um NPC novo que
## chega ao porto. Na missão algum NPC irá ensinar ao jogador que o comprador
## de mercadorias vem 1x por estação do calendário do jogo e compra o que foi
## produzido no mês, dando a possibilidade do jogador levar algumas mercadorias
## para vender por um bom preço." Oito perguntas:
##
##   1. O MESTRE SÓ VEM NO DIA DELE: fora do dia 14 nem ele nem o saveiro estão
##      no vale; no dia, da manhã à tarde, os dois estão no píer.
##   2. A PIAÇAVA SE TIRA SEM DERRUBAR: com o facão na mão, a piaçabeira dá dois
##      feixes e fica de pé; não dá de novo na mesma estação, e a dica não diz
##      quando; na estação seguinte, dá.
##   3. O SEU BENEDITO ENSINA, e a cadeia se cumpre: ele dá o facão, manda ao
##      píer, pede os dez feixes, e a entrega ao mestre ESPERA o dia dele — fora
##      do dia, ao lado do posto dele, nada acontece; no dia, ele recebe e paga.
##   4. ELE COMPRA O QUE SE PRODUZIU, MAIS CARO QUE A VENDA: perto dele, o painel
##      tem a aba do saveiro; tudo o que ele compra paga mais que a venda, e
##      até o tanto que leva na viagem.
##   5. A ENCOMENDA VOLTA TODA ESTAÇÃO: na estação seguinte o caderno tem a
##      encomenda; os dez feixes no dia dele riscam a encomenda e dão o agrado;
##      e a encomenda que o saveiro levou embora sem receber sai do caderno.
##   6. A PARTIDA SALVA LEMBRA a visita, o que ele levou e a fibra tirada.
##   7. A PLACA DE NOME VAI COM ELE: no dia, olhando para ele, o nome aparece;
##      fora do dia, no mesmo lugar e olhando para o mesmo ponto, não.
##   8. SEM MODELO, CAIXA CINZA; COM MODELO, O DELE: no estilo Tripo, enquanto o
##      catálogo não tem o mestre, o corpo dele é a caixa provisória, e não o
##      boneco do procedural — nem no retrato do diário, que fica sem foto; com o
##      modelo no catálogo, é o modelo dele, com os clipes no animador autoral.
##   9. NA CHEGADA, O SAVEIRO ESTÁ ATRACADO: no primeiro dia do jogo o barco está
##      no píer — foi nele que o jogador veio —, sem o mestre e sem a aba de
##      compra; no dia seguinte, larga.

var falhas := 0
var relogio
var dia
var inventario
var energia
var caderno
var jogo
var venda


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("SAVEIRO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	relogio = root.get_node("/root/Relogio")
	dia = root.get_node("/root/Dia")
	inventario = root.get_node("/root/Inventario")
	energia = root.get_node("/root/Energia")
	caderno = root.get_node("/root/CadernoDoVale")
	jogo = root.get_node("/root/Jogo")
	venda = root.get_node("/root/Venda")
	dia.pausado = true
	var vale = current_scene
	var jogador = vale.player
	var mundo = vale.world
	var saveiro = vale.get("saveiro")
	var arvores = vale.get_node_or_null("ArvoresInfo")
	_conferir(saveiro != null and arvores != null, "o vale não tem o saveiro ou as árvores")
	if saveiro == null or arvores == null:
		_fechar()
		return
	var quirino: Node3D = saveiro.comprador
	var benedito: Node3D = null
	for morador in vale.moradores:
		if str(morador.dados.get("id", "")) == "benedito":
			benedito = morador
	_conferir(quirino != null and benedito != null, "o vale não tem o mestre Quirino ou o Seu Benedito")
	if quirino == null or benedito == null:
		_fechar()
		return

	# --- 8. SEM MODELO, CAIXA CINZA; COM MODELO, O DELE -----------------------------
	var estilo_tripo: bool = root.get_node("/root/Estilo").tripo()
	var tem_modelo: bool = load("res://scripts/prototipo_3d/catalogo_assets.gd").tem_tripo("quirino")
	if estilo_tripo and tem_modelo:
		var o_modelo = quirino.get("modelo")
		_conferir(o_modelo != null and str(o_modelo.name) == "QuirinoTripo" and quirino.get("animador") != null and quirino.animador.has_method("is_using_authored_clips"), "no estilo Tripo, com o modelo no catálogo, o mestre não usa o modelo dele com os clipes (é %s)" % (str(o_modelo.name) if o_modelo != null else "nada"))
	if estilo_tripo and not tem_modelo:
		var corpo = quirino.get("modelo")
		_conferir(corpo != null and str(corpo.name) == "CorpoProvisorio" and quirino.get("animador") == null, "no estilo Tripo, sem modelo no catálogo, o mestre não é a caixa cinza provisória (é %s)" % (str(corpo.name) if corpo != null else "nada"))
		# Nem o retrato do diário sai do boneco do procedural: sem modelo, sem foto.
		var estudio = vale.get("retratos")
		if estudio != null:
			var palco := Node3D.new()
			var foto = estudio._montar_modelo("quirino", palco)
			_conferir(foto == null, "no estilo Tripo, o retrato do mestre sem modelo sai do boneco do procedural")
			palco.free()

	# --- 9. NA CHEGADA, O SAVEIRO ESTÁ ATRACADO -------------------------------------
	await _no_dia(1, 9.0)
	_conferir(saveiro.na_chegada() and saveiro.barco.visible, "no primeiro dia do jogo, o da chegada, o saveiro não está no píer")
	_conferir(not saveiro.presente() and not quirino.visible and not saveiro.perto(saveiro.barco.global_position), "na chegada o saveiro veio com o mestre no píer e a aba de compra aberta: a compra é só no dia dele")
	await _no_dia(2, 9.0)
	_conferir(not saveiro.barco.visible, "no dia seguinte ao da chegada, o saveiro continua no píer")

	# --- 1. O MESTRE SÓ VEM NO DIA DELE --------------------------------------------
	await _no_dia(10, 9.0)
	_conferir(not saveiro.presente() and not quirino.visible and not saveiro.barco.visible, "fora do dia do saveiro, o mestre ou o barco estão no píer")
	await _no_dia(saveiro.dia, 9.0)
	_conferir(saveiro.presente() and quirino.visible and saveiro.barco.visible, "no dia do saveiro, de manhã, o mestre ou o barco não estão no píer")
	var piso: Vector3 = mundo.ancoras["PierPiso"]
	_conferir(Vector2(quirino.global_position.x - piso.x, quirino.global_position.z - piso.z).length() < 12.0, "o mestre não está no píer: %s" % str(quirino.global_position))
	await _no_dia(saveiro.dia, 18.0)
	_conferir(not saveiro.presente() and not quirino.visible, "o mestre não partiu no fim da tarde")

	# --- 2. A PIAÇAVA SE TIRA SEM DERRUBAR --------------------------------------------
	var palmeira := -1
	for i in arvores._cortaveis.size():
		if str(arvores._cortaveis[i]["especie"]) == "piacava" and not bool(arvores._cortaveis[i]["cortado"]):
			palmeira = i
			break
	_conferir(palmeira >= 0, "o vale não tem piaçabeira de pé")
	_por_o_facao()
	if palmeira >= 0:
		var pe: Vector3 = arvores._cortaveis[palmeira]["pos"]
		jogador.teleportar(mundo.ground_position(pe + Vector3(1.2, 0, 0.0), 0.07), PI * 0.5)
		await _quadros(5)
		_conferir(arvores._fibra_perto == palmeira, "com o facão na mão, ao lado da piaçabeira, a tecla não é de tirar a fibra (perto: %d)" % arvores._fibra_perto)
		energia.encher()
		var antes: int = inventario.quantidade("piacava")
		arvores._fibra_perto = palmeira
		arvores._unhandled_key_input(_tecla_e())
		_conferir(inventario.quantidade("piacava") == antes + 2, "a piaçabeira deu %d feixes, e são dois" % (inventario.quantidade("piacava") - antes))
		_conferir(not bool(arvores._cortaveis[palmeira]["cortado"]), "tirar a fibra derrubou a piaçabeira")
		_conferir(not arvores.fibra_pronta(palmeira), "a piaçabeira deu fibra e continua pronta para dar de novo")
		arvores._fibra_perto = palmeira
		arvores._unhandled_key_input(_tecla_e())
		_conferir(inventario.quantidade("piacava") == antes + 2, "a mesma piaçabeira deu fibra duas vezes na estação")
		var dica: String = arvores._texto_da_fibra(palmeira)
		_conferir(RegEx.create_from_string("[0-9]").search(dica) == null, "a dica da piaçabeira tirada diz quando ela volta: '%s'" % dica)
		var tirada_em: int = relogio.dia_absoluto()
		while relogio.dia_absoluto() < tirada_em + relogio.DIAS_POR_ESTACAO:
			relogio.dormir()
		_conferir(arvores.fibra_pronta(palmeira), "uma estação depois, a piaçabeira não tem fibra de novo")

	# --- 3. O SEU BENEDITO ENSINA ----------------------------------------------------
	var cadeia = benedito.get_node_or_null("CadeiaDeMissoes_benedito_saveiro")
	_conferir(cadeia != null, "o Seu Benedito não tem a cadeia do saveiro")
	if cadeia == null:
		_fechar()
		return
	var pedro = vale.get("pedro")
	jogador.teleportar(benedito.global_position + Vector3(1.2, 0.0, 1.0), 0.0)
	await _quadros(30)
	_conferir(not cadeia.iniciado, "a cadeia do saveiro abriu com o tutorial do Pedro em curso")
	pedro.missao = pedro.MISSOES.size()
	pedro.set("_despedida_feita", true)
	inventario.consumir("facao", inventario.quantidade("facao"))
	root.get_node("/root/Equipamento").desequipar("maos")
	inventario.consumir("facao", inventario.quantidade("facao"))
	jogador.teleportar(benedito.global_position + Vector3(1.2, 0.0, 1.0), 0.0)
	_conferir(await _ate(func() -> bool: return bool(cadeia.iniciado), 12.0), "ao lado do Seu Benedito, depois do tutorial, a cadeia do saveiro não abriu")
	_conferir(await _ate(func() -> bool: return inventario.tem("facao") or root.get_node("/root/Equipamento").no_encaixe("maos") == "facao", 6.0), "o Seu Benedito não deu o facão")
	var ponto_do_pier: Vector3 = root.get_node("/root/Lugares").ponto("pier")
	jogador.teleportar(mundo.ground_position(ponto_do_pier, 0.07) if mundo.is_on_land(ponto_do_pier) else ponto_do_pier, 0.0)
	_conferir(await _ate(func() -> bool: return cadeia.missao >= 1, 15.0), "no píer, o passo de ver onde o saveiro atraca não fechou")
	inventario.adicionar("piacava", 10)
	_conferir(await _ate(func() -> bool: return cadeia.missao >= 2, 15.0), "com os dez feixes, o passo da piaçava não fechou")
	# Fora do dia: ao lado do posto dele, nada. O passo da entrega só se anuncia
	# com a palavra livre — quem chega ao píer ouve o Tonho e o Pedro, e cada
	# saudação segura a palavra uns segundos —, e só depois do anúncio a cadeia
	# tenta a entrega. Espera-se o anúncio, e então passos de física com a cadeia
	# tentando: antes disso, "nada aconteceu" não prova nada.
	await _no_dia(10, 9.0)
	jogador.teleportar(_no_tabuado(quirino, mundo), 0.0)
	_conferir(await _ate(func() -> bool: return float(cadeia.espera) <= 0.0, 45.0), "o passo da entrega não se anunciou no píer")
	await _passos_de_fisica(30)
	_conferir(cadeia.missao == 2 and inventario.quantidade("piacava") >= 10, "fora do dia do saveiro, o mestre escondido recebeu a piaçava")
	# No dia: ele recebe e paga.
	var dinheiro_antes: int = jogo.dinheiro
	await _no_dia(saveiro.dia, 9.0)
	jogador.teleportar(_no_tabuado(quirino, mundo), 0.0)
	_conferir(await _ate(func() -> bool: return cadeia.acabou(), 15.0), "no dia do saveiro, ao lado do mestre, a entrega não aconteceu")
	_conferir(jogo.dinheiro - dinheiro_antes == 340, "o mestre pagou %d pela piaçava da cadeia, e são 340" % (jogo.dinheiro - dinheiro_antes))

	# --- 4. ELE COMPRA O QUE SE PRODUZIU, MAIS CARO QUE A VENDA ----------------------
	var painel = vale.get_node_or_null("Painel")
	var Bancadas = load("res://scripts/prototipo_3d/bancadas_vale.gd")
	if painel != null:
		Bancadas.aplicar(painel, mundo, jogador.global_position)
		_conferir(painel.saveiro == saveiro and painel.abas_validas().has(painel.Aba.SAVEIRO), "perto do mestre, no dia dele, o painel não tem a aba do saveiro")
		Bancadas.aplicar(painel, mundo, mundo.ancoras["Praça"])
		_conferir(painel.saveiro == null, "longe do mestre, o painel continua com a aba do saveiro")
	for id in saveiro.o_que_compra():
		_conferir(saveiro.paga(str(id)) > venda.preco_de_venda(str(id)), "o mestre paga %d por %s, e a venda paga %d: não é bom preço" % [saveiro.paga(str(id)), str(id), venda.preco_de_venda(str(id))])
	var leva_farinha: int = saveiro.leva("farinha") - saveiro.levou("farinha")
	inventario.adicionar("farinha", leva_farinha + 2)
	var antes_da_farinha: int = jogo.dinheiro
	for i in leva_farinha:
		_conferir(saveiro.vender("farinha") == "", "o mestre recusou a farinha número %d" % (i + 1))
	_conferir(jogo.dinheiro - antes_da_farinha == leva_farinha * saveiro.paga("farinha"), "a farinha não foi paga pelo preço do mestre")
	_conferir(saveiro.vender("farinha") != "", "o mestre levou mais farinha do que leva numa viagem")

	# --- 5. A ENCOMENDA VOLTA TODA ESTAÇÃO ---------------------------------------------
	var estacao_antes: int = relogio.estacao
	while relogio.estacao == estacao_antes:
		relogio.dormir()
	await _no_dia(1, 9.0)
	var id_encomenda: String = saveiro._id_da_encomenda()
	_conferir(caderno.tem(id_encomenda), "na estação seguinte o caderno não tem a encomenda do saveiro")
	inventario.adicionar("piacava", 10)
	await _no_dia(saveiro.dia, 9.0)
	var antes_do_agrado: int = jogo.dinheiro
	for i in 10:
		saveiro.vender("piacava")
	_conferir(jogo.dinheiro - antes_do_agrado == 10 * saveiro.paga("piacava") + int(saveiro.encomenda.get("agrado_reis", 0)), "a encomenda entregue não deu o agrado (%d)" % (jogo.dinheiro - antes_do_agrado))
	_conferir(caderno.cumprida(id_encomenda) and not caderno.tem(id_encomenda), "a encomenda entregue não foi riscada do caderno")
	# A estação seguinte: o saveiro vem e vai sem a encomenda.
	estacao_antes = relogio.estacao
	while relogio.estacao == estacao_antes:
		relogio.dormir()
	await _no_dia(1, 9.0)
	var a_perdida: String = saveiro._id_da_encomenda()
	_conferir(caderno.tem(a_perdida), "a encomenda da terceira estação não abriu")
	# A conta da encomenda anda uma vez por segundo (saveiro_vale._process): o
	# salto do dia 1 ao fim da tarde do 14 não passa pela partida dele.
	await _no_dia(saveiro.dia, 18.0)
	_conferir(await _ate(func() -> bool: return not caderno.tem(a_perdida), 4.0) and not caderno.cumprida(a_perdida), "a encomenda que o saveiro levou embora sem receber continua no caderno (ou entrou nas cumpridas)")

	# --- 6. A PARTIDA SALVA LEMBRA -------------------------------------------------------
	var estado: Dictionary = vale.estado_para_salvar()
	_conferir(estado.has("saveiro") and estado.has("piacava_tirada"), "o save não guarda o saveiro ou a fibra tirada")

	# --- 7. A PLACA DE NOME VAI COM ELE ----------------------------------------------------
	# Longe do cumprimento dele, que esconde a placa enquanto o balão fala, e perto
	# o bastante para ela: seis passos atrás, no tabuado. O balão de antes pode
	# ainda estar no fim quando ele volta, então a placa tem uns segundos.
	var placas = vale.get("placas")
	_conferir(placas != null and placas._placas.has(quirino), "o mestre não tem placa de nome")
	if placas != null and placas._placas.has(quirino):
		var placa: Control = placas._placas[quirino]
		await _no_dia(saveiro.dia, 9.0)
		await _de_frente_para(jogador, quirino, mundo)
		_conferir(await _ate(func() -> bool: return placa.visible, 15.0), "no dia do saveiro, de frente para o mestre, a placa com o nome dele não aparece")
		await _no_dia(saveiro.dia + 1, 9.0)
		_conferir(not await _ate(func() -> bool: return placa.visible, 1.5), "fora do dia do saveiro, a placa com o nome do mestre flutua sobre o píer vazio")
	_fechar()


## UM PASSO ATRÁS DO MESTRE, NO TABUADO DO PÍER, rumo à terra: de lado dele é
## água funda, e o corpo que cai lá o vale traz de volta ao começo. Sempre por
## `teleportar`, que recomeça a terra firme de referência ali: posto à mão, o
## corpo fica 2,5 m abaixo da última terra firme (a restinga, a praça) e a regra
## da queda no mar o devolve a ela meio segundo depois.
func _no_tabuado(quirino: Node3D, mundo) -> Vector3:
	var rumo: Vector3 = mundo.ancoras.get("PierDirecao", Vector3.FORWARD)
	rumo.y = 0.0
	return quirino.global_position - rumo.normalized() * 1.3 + Vector3.UP * 0.1


## DE FRENTE PARA O MESTRE, seis passos atrás dele no tabuado (rumo à terra, que
## o tabuado vai a -5,75): dos dois rumos ao longo do píer, o que deixa a cabeça
## dele à frente da câmera.
func _de_frente_para(jogador, quirino: Node3D, mundo) -> void:
	var rumo: Vector3 = mundo.ancoras.get("PierDirecao", Vector3.FORWARD)
	rumo.y = 0.0
	var giro := atan2(rumo.x, rumo.z)
	var atras := quirino.global_position - rumo.normalized() * 6.0 + Vector3.UP * 0.1
	for tentativa in [giro, giro + PI]:
		jogador.teleportar(atras, tentativa)
		await _quadros(5)
		var camera: Camera3D = jogador.get_viewport().get_camera_3d()
		if camera != null and not camera.is_position_behind(quirino.global_position + Vector3.UP * 1.8):
			return


## Põe o calendário num dia da estação e o relógio numa hora, e espera o vale ver.
func _no_dia(qual: int, hora: float) -> void:
	relogio.dia = qual
	dia.definir_hora(hora)
	await _quadros(3)


func _por_o_facao() -> void:
	if inventario.na_mao() == "facao":
		return
	inventario.adicionar("facao", 1)
	for i in inventario.ESPACOS_MAO:
		if str((inventario.espacos[i] as Dictionary).get("id", "")) == "facao":
			inventario.selecionar(i)
			return


func _tecla_e() -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = load("res://scripts/prototipo_3d/atalhos.gd").tecla("interagir")
	e.pressed = true
	return e


func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicao.call():
			return true
		await process_frame
	return condicao.call()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("SAVEIRO_OK: o mestre Quirino e o saveiro só estão no píer no dia 14, da manhã à tarde; a piaçava se tira no facão sem derrubar a palmeira, uma vez por estação; o Seu Benedito ensina, e a entrega espera o dia do mestre; perto dele o painel tem a aba do saveiro, que paga mais que a venda até o tanto que leva; a encomenda volta toda estação, dá o agrado e sai do caderno se o saveiro parte sem ela; o save lembra; a placa de nome some com ele; e no estilo Tripo ele é o modelo dele, com os clipes, ou, sem modelo, a caixa cinza; e no primeiro dia do jogo o saveiro está atracado sem o mestre, e larga no dia seguinte")
	else:
		print("saveiro: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _passos_de_fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _mundo_pronto() -> void:
	for i in 3000:
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
