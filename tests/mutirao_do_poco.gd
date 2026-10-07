extends SceneTree
## O MUTIRÃO DO POÇO (#80): o trecho da chegada que travou o teste ao vivo de 05/10.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/mutirao_do_poco.gd
##     ... -- --falsificar      (sem o E no poço: tem de reprovar)
##
## "Não tá interagindo. A missão é consertar o poço." O passo `mutirao_poco`
## fecha por uma obra (`poco_corda`), que só se tocava pelo J; o resumo não
## dizia a tecla e o poço não respondia ao E. Agora a construção com obra
## disponível ganha o E (`tecla_das_bancadas.gd`: o sítio com `raio_do_e` e obra à
## mão, ou pedida pela missão — `_tem_obra`), e o resumo diz as duas ([E] e [J]).
##
##   1. A BOCA DO POÇO: o passo entrega a picareta, e três pedras o fecham.
##   2. CORDA NOVA: uma corda fecha.
##   3. O MUTIRÃO: ao abrir, o plano da obra entra na cabeça do jogador
##      (`Receitas`), a obra fica disponível, a Dona Zefa e o Cosme são chamados
##      à roda em volta do poço, e o resumo diz o E e o J.
##   4. O E NO POÇO: ao pé dele, entre os dois da roda, o E é do poço e abre o
##      painel na aba de obras do poço.
##   5. TOCAR A OBRA no painel cobra a corda e as três pedras, fecha o passo,
##      paga as duas cocadas da Dona Zefa e abre a janta.

const SEGUNDOS := 20.0
const PASSOS := ["pedra_do_poco", "corda", "mutirao_poco", "janta"]

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("MUTIRAO_DO_POCO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	var vale = current_scene
	var jogador = vale.player
	var mundo = vale.world
	var pedro = vale.get("pedro")
	var tecla = vale.get("tecla_das_bancadas")
	var inv = root.get_node("/root/Inventario")
	var obras = root.get_node("/root/Obras")
	var receitas = root.get_node("/root/Receitas")
	_conferir(pedro != null and tecla != null, "o vale não tem o Pedro ou o E das bancadas")
	if pedro == null or tecla == null:
		_fechar()
		return
	var cadeia = pedro.get("_cadeia")
	_conferir(cadeia != null and bool(pedro.get("_iniciado")), "a chegada não começou")
	if "--falsificar" in OS.get_cmdline_user_args():
		_falsificar(vale, tecla)
	for id in PASSOS:
		_conferir(cadeia.passos.any(func(p: Dictionary) -> bool: return str(p.get("id", "")) == id),
			"a chegada não tem o passo '%s'" % id)

	# --- 1. A BOCA DO POÇO ------------------------------------------------------
	_conferir(pedro.ir_ao_passo("pedra_do_poco"), "não consegui pular até a boca do poço")
	cadeia.espera = 0.0
	cadeia.anunciar()
	await _quadros(3)
	_conferir(inv.quantidade("picareta") >= 1, "a boca do poço não entregou a picareta")
	_ate_ter(inv, "pedra", 3)
	_conferir(await _ate(func() -> bool: return pedro.passo_em_curso() == "corda", SEGUNDOS),
		"três pedras não fecharam a boca do poço (está em '%s')" % pedro.passo_em_curso())

	# --- 2. CORDA NOVA ----------------------------------------------------------
	await _ate(func() -> bool: return cadeia.espera <= 0.0, SEGUNDOS)
	_ate_ter(inv, "corda", 1)
	_conferir(await _ate(func() -> bool: return pedro.passo_em_curso() == "mutirao_poco", SEGUNDOS),
		"a corda não fechou o passo da corda (está em '%s')" % pedro.passo_em_curso())

	# --- 3. O MUTIRÃO -----------------------------------------------------------
	await _ate(func() -> bool: return cadeia.espera <= 0.0, SEGUNDOS)
	await _quadros(3)
	_conferir(receitas.sabe("poco_corda"), "abrir o mutirão não ensinou o plano da boca do poço")
	_conferir(obras.disponiveis("poco").has("poco_corda"),
		"a obra da boca do poço não está disponível: %s" % str(obras.disponiveis("poco")))
	var poco: Vector3 = mundo.ancoras.get("Poço", Vector3.INF)
	_conferir(poco.is_finite(), "o vale não tem o poço")
	for quem in ["zefa", "cosme"]:
		var morador = vale._achar_morador(quem)
		var destino: Vector3 = morador.get("_destino_avulso") if morador != null else Vector3.INF
		_conferir(morador != null and destino.is_finite()
			and Vector2(destino.x - poco.x, destino.z - poco.z).length() <= float(cadeia.RAIO_DA_RODA) + 0.1,
			"%s não foi chamado à roda do poço (destino %s)" % [quem, str(destino)])
	var resumo: String = cadeia.resumo_do_passo(cadeia.passo_atual())
	_conferir(resumo.contains("[E]") and resumo.contains("[J]"), "o resumo do mutirão não diz o [E] e o [J]: '%s'" % resumo)
	# Com o plano aprendido (e o passo pedindo a obra), o poço tem o que fazer no E
	# (`tecla_das_bancadas._tem_obra`): é o que acende a dica e faz o E ser dele.
	_conferir(await _ate(func() -> bool: return bool(tecla._tem_obra("poco")), 3.0),
		"com o plano da boca do poço aprendido, o poço não tem obra no E (disponíveis: %s)" % str(obras.disponiveis("poco")))

	# --- 4. O E NO POÇO ---------------------------------------------------------
	# Entre os dois lugares da roda (ângulos 0,6 e 0,6 + π), de frente para o poço,
	# fora do tronco dele e dentro do raio da aba.
	var angulo := 0.6 + PI * 0.5
	var ponto := poco + Vector3(cos(angulo), 0.0, sin(angulo)) * 2.2
	jogador.teleportar(mundo.ground_position(ponto, 0.07), atan2(poco.x - ponto.x, poco.z - ponto.z))
	await _quadros(5)
	await _passos_de_fisica(5)
	_conferir(tecla.perto() == "poco", "ao pé do poço, no mutirão, o E não é do poço (é '%s')" % tecla.perto())
	var foco = load("res://scripts/prototipo_3d/foco_do_e.gd")
	_conferir(foco.e_dele(tecla), "de frente para o poço, o E ficou com outra coisa")
	tecla.usar("poco")
	await _quadros(3)
	var painel = vale.get("painel")
	_conferir(painel != null and painel.aberto and str(painel.obra_em_foco) == "poco" and int(painel.get("_aba")) == painel.Aba.OBRAS,
		"o E no poço não abriu as obras do poço (aberto %s, foco '%s')" % [str(painel.aberto), str(painel.obra_em_foco)])

	# --- 5. TOCAR A OBRA --------------------------------------------------------
	var cocadas: int = inv.quantidade("cocada")
	var lista: Array = obras.disponiveis("poco")
	painel.set("_cursor", lista.find("poco_corda"))
	painel._confirmar()
	_conferir(obras.ja_feita("poco", "poco_corda"),
		"tocar a obra no painel não consertou o poço: %s" % str(obras.impedimento("poco", "poco_corda")))
	_conferir(inv.quantidade("corda") == 0 and inv.quantidade("pedra") == 0, "a obra não cobrou a corda e as três pedras")
	if painel.aberto:
		vale.telas.abrir("painel")
		await _quadros(3)
	_conferir(await _ate(func() -> bool: return pedro.passo_em_curso() == "janta", SEGUNDOS),
		"o poço consertado não fechou o mutirão (está em '%s')" % pedro.passo_em_curso())
	_conferir(inv.quantidade("cocada") == cocadas + 2, "a Dona Zefa não pagou as duas cocadas")
	_fechar()


## SEM O E NO POÇO: a tecla das bancadas volta a conhecer só os lugares fixos — nenhum
## sítio de obra tem o que fazer no E (`_tem_obra`).
func _falsificar(vale, tecla) -> void:
	var original: Script = tecla.get_script()
	var quebrado := GDScript.new()
	quebrado.source_code = original.source_code.replace(
		"\treturn _a_missao_pede(qual) or not Obras.disponiveis(qual).is_empty()", "\treturn false")
	_conferir(quebrado.source_code != original.source_code, "a falsificação não encontrou o E das obras")
	_conferir(quebrado.reload() == OK, "a falsificação não compilou")
	tecla.set_script(quebrado)
	tecla.configurar(vale.world, vale.player, vale.hud, vale.abrir_o_painel,
		func() -> bool: return not vale._lendo() and (vale.telas == null or vale.telas.aberta() == ""))


func _ate_ter(inv: Node, item: String, quantos: int) -> void:
	while inv.quantidade(item) < quantos:
		inv.adicionar(item, 1)
	while inv.quantidade(item) > quantos:
		inv.consumir(item, 1)


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("MUTIRAO_DO_POCO_OK: a picareta e três pedras fecham a boca do poço, a corda fecha a corda, o mutirão ensina a obra e chama a Dona Zefa e o Cosme à roda, o E no poço abre as obras dele, e a obra tocada fecha o passo, paga as cocadas e abre a janta")
	else:
		print("mutirao_do_poco: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _passos_de_fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


## Roda quadros até `condicao` valer, com teto em segundo real.
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
	await process_frame
	await process_frame
