extends "res://tests/suite/caso.gd"
## Confere OS PONTOS DE RESTAURAÇÃO das vagas.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste pontos_de_restauracao
##
## "Aproveite e implemente uma política de 'ponto de restauração', assim impede
## a pessoa de perder o save caso encontre algum bug grave." Seis perguntas:
##
##   1. UM PONTO POR DIA DE JOGO: a primeira gravação de cada dia guarda o
##      ponto dele; gravar de novo no mesmo dia não gasta ponto; ficam os sete
##      dias mais novos.
##   2. APAGAR SE DESFAZ: a vaga apagada guarda o ponto "antes de apagar", e
##      restaurá-lo devolve a partida.
##   3. RESTAURAR SE DESFAZ: voltar a um dia velho guarda antes o ponto do que
##      a vaga tinha, e restaurá-lo devolve o dia novo; ficam os três pontos de
##      segurança mais novos.
##   4. PONTO QUE NÃO SE LÊ NÃO TOCA A VAGA.
##   5. A VAGA QUE NÃO ABRE VOLTA PELO PONTO: com o arquivo da vaga e a cópia
##      anterior estragados, o ponto do último dia a devolve.
##   6. PELA TELA: a seta do cartão abre os pontos da vaga, o primeiro clique
##      num ponto só avisa e o segundo restaura.
##
## OS SAVES DE VERDADE NÃO SÃO TOCADOS: as vagas, os pontos e os nomes vão para
## uma reserva no começo e voltam no fim, como no `salvamento.gd`.

const RESERVA := "user://reserva_do_teste_de_pontos"
const PONTOS := "user://pontos"
const NOMES := "user://vagas.json"

var falhas := 0
var salvamento
var partida
var relogio
var pontos


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("PONTOS_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	salvamento = root.get_node("/root/Salvamento")
	partida = root.get_node("/root/Partida")
	relogio = root.get_node("/root/Relogio")
	pontos = load("res://scripts/prototipo_3d/pontos_de_restauracao.gd")
	_devolver_a_reserva()
	_guardar_o_que_e_do_jogador()

	# --- 1. UM PONTO POR DIA DE JOGO ---------------------------------------------
	partida.comecar(1, true)
	for dia in range(1, 11):
		relogio.dia = dia
		_conferir(partida.salvar(), "não salvou o dia %d" % dia)
		if dia == 1:
			_conferir(_dos("dia").size() == 1, "a primeira gravação não guardou o ponto do dia 1")
			partida.salvar()
			_conferir(_dos("dia").size() == 1, "gravar de novo no mesmo dia gastou outro ponto")
	var diarios := _dos("dia")
	_conferir(diarios.size() == pontos.DIARIOS, "ficaram %d pontos diários, e são %d" % [diarios.size(), pontos.DIARIOS])
	_conferir(not diarios.is_empty() and int(diarios[0]["dia"]) == 10 and int(diarios[-1]["dia"]) == 4,
		"os pontos diários não são os sete dias mais novos (%s)" % str(diarios.map(func(p): return p["dia"])))

	# --- 2. APAGAR SE DESFAZ ---------------------------------------------------------
	partida.apagar_vaga(1)
	_conferir(not salvamento.existe_partida(1) and not FileAccess.file_exists(salvamento.anterior(1)), "apagar a vaga deixou a partida ou a cópia anterior")
	var de_antes := _dos(pontos.ANTES_DE_APAGAR)
	_conferir(de_antes.size() == 1 and int(de_antes[0]["dia"]) == 10, "a vaga apagada não guardou o ponto de antes de apagar (%s)" % str(de_antes))
	if not de_antes.is_empty():
		_conferir(pontos.restaurar(1, str(de_antes[0]["caminho"])), "o ponto de antes de apagar não restaurou")
		_conferir(salvamento.existe_partida(1) and int(salvamento.resumo(1).get("dia", 0)) == 10, "restaurar a vaga apagada não devolveu o dia 10")

	# --- 3. RESTAURAR SE DESFAZ --------------------------------------------------------
	var do_dia_5: Array = _dos("dia").filter(func(p: Dictionary) -> bool: return int(p["dia"]) == 5)
	_conferir(do_dia_5.size() == 1, "não há o ponto do dia 5")
	if not do_dia_5.is_empty():
		_conferir(pontos.restaurar(1, str(do_dia_5[0]["caminho"])), "o ponto do dia 5 não restaurou")
		_conferir(int(salvamento.resumo(1).get("dia", 0)) == 5, "restaurar o dia 5 deixou a vaga no dia %s" % str(salvamento.resumo(1).get("dia")))
		var de_antes_de_restaurar := _dos(pontos.ANTES_DE_RESTAURAR)
		_conferir(de_antes_de_restaurar.size() == 1 and int(de_antes_de_restaurar[0]["dia"]) == 10, "restaurar não guardou antes o dia 10 que a vaga tinha")
		if not de_antes_de_restaurar.is_empty():
			pontos.restaurar(1, str(de_antes_de_restaurar[0]["caminho"]))
			_conferir(int(salvamento.resumo(1).get("dia", 0)) == 10, "restaurar o ponto de antes não devolveu o dia 10")
	for i in 4:
		pontos.guardar(1, pontos.ANTES_DE_RESTAURAR)
	var de_seguranca: Array = pontos.listar(1).filter(func(p: Dictionary) -> bool: return str(p["tipo"]) != "dia")
	_conferir(de_seguranca.size() == pontos.DE_SEGURANCA, "ficaram %d pontos de segurança, e são %d" % [de_seguranca.size(), pontos.DE_SEGURANCA])

	# --- 4. PONTO QUE NÃO SE LÊ NÃO TOCA A VAGA -----------------------------------------
	var estragado: String = pontos.pasta(1).path_join("1_dia_dia99.save")
	var arquivo := FileAccess.open(estragado, FileAccess.WRITE)
	arquivo.store_string("isto não é partida")
	arquivo.close()
	var dia_antes := int(salvamento.resumo(1).get("dia", 0))
	_conferir(not pontos.restaurar(1, estragado), "um ponto que não se lê restaurou")
	_conferir(int(salvamento.resumo(1).get("dia", 0)) == dia_antes, "o ponto que não se lê mexeu na vaga")
	DirAccess.remove_absolute(estragado)

	# --- 5. A VAGA QUE NÃO ABRE VOLTA PELO PONTO -----------------------------------------
	for caminho in [salvamento.arquivo(1), salvamento.anterior(1)]:
		var ruim := FileAccess.open(caminho, FileAccess.WRITE)
		ruim.store_string("{ quebrado")
		ruim.close()
	_conferir(salvamento.ler(1).is_empty(), "o arquivo estragado da vaga ainda se lê: a pergunta não pergunta nada")
	var mais_novo: Array = _dos("dia")
	if not mais_novo.is_empty():
		_conferir(pontos.restaurar(1, str(mais_novo[0]["caminho"])), "o ponto do último dia não restaurou a vaga estragada")
		_conferir(not salvamento.ler(1).is_empty() and int(salvamento.resumo(1).get("dia", 0)) == 10, "a vaga estragada não voltou pelo ponto do dia 10")

	# --- 6. PELA TELA ------------------------------------------------------------------
	partida.comecar(0)
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/abertura.tscn") == OK, "a abertura não carregou")
	await _quadros(12)
	var abertura = current_scene
	abertura._vagas()
	await _quadros(2)
	var seta: Button = abertura.content.get_node_or_null("Vaga1/Linha/Pontos1")
	_conferir(seta != null, "o cartão da vaga com pontos não tem a seta dos pontos de restauração")
	if seta != null:
		seta.pressed.emit()
		await _quadros(2)
		var lista: Array = pontos.listar(1)
		var primeiro: Button = abertura.content.get_node_or_null("Ponto0")
		var ultimo: Button = abertura.content.get_node_or_null("Ponto%d" % (lista.size() - 1))
		_conferir(primeiro != null and ultimo != null and abertura.content.get_node_or_null("Ponto%d" % lista.size()) == null,
			"a tela não mostra os %d pontos da vaga" % lista.size())
		var do_dia_6: int = lista.find_custom(func(p: Dictionary) -> bool: return int(p["dia"]) == 6)
		var botao: Button = abertura.content.get_node_or_null("Ponto%d" % do_dia_6)
		_conferir(botao != null and botao.text.contains("6"), "o ponto do dia 6 não está na tela")
		if botao != null:
			botao.pressed.emit()
			await _quadros(2)
			_conferir(int(salvamento.resumo(1).get("dia", 0)) == 10, "o primeiro clique num ponto já restaurou")
			botao.pressed.emit()
			await _quadros(2)
			_conferir(int(salvamento.resumo(1).get("dia", 0)) == 6, "o segundo clique no ponto do dia 6 não restaurou (a vaga está no dia %s)" % str(salvamento.resumo(1).get("dia")))
			_conferir(abertura.content.get_node_or_null("Vaga1") != null, "depois de restaurar, a tela não voltou às vagas")
	_fechar()


## Os pontos da vaga 1 de um tipo, do mais novo ao mais velho.
func _dos(tipo: String) -> Array:
	return pontos.listar(1).filter(func(p: Dictionary) -> bool: return str(p["tipo"]) == tipo)


# --- os saves de verdade -----------------------------------------------------------

func _do_jogador() -> Array:
	var todos := [NOMES]
	for slot in range(1, salvamento.QUANTOS_SLOTS + 1):
		todos.append_array([salvamento.arquivo(slot), salvamento.anterior(slot), salvamento.rascunho(slot)])
	return todos


func _guardar_o_que_e_do_jogador() -> void:
	DirAccess.make_dir_recursive_absolute(RESERVA)
	for caminho in _do_jogador():
		if FileAccess.file_exists(caminho):
			DirAccess.rename_absolute(caminho, RESERVA.path_join(caminho.get_file()))
	if DirAccess.dir_exists_absolute(PONTOS):
		DirAccess.rename_absolute(PONTOS, RESERVA.path_join(PONTOS.get_file()))


func _devolver_a_reserva() -> void:
	var pasta := DirAccess.open(RESERVA)
	if pasta == null:
		return
	for caminho in _do_jogador():
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(caminho)
	_apagar_pasta(PONTOS)
	for nome in pasta.get_files():
		DirAccess.rename_absolute(RESERVA.path_join(nome), "user://".path_join(nome))
	for nome in pasta.get_directories():
		DirAccess.rename_absolute(RESERVA.path_join(nome), "user://".path_join(nome))
	DirAccess.remove_absolute(RESERVA)


func _apagar_pasta(caminho: String) -> void:
	var pasta := DirAccess.open(caminho)
	if pasta == null:
		return
	for dentro in pasta.get_directories():
		_apagar_pasta(caminho.path_join(dentro))
	for arquivo in pasta.get_files():
		DirAccess.remove_absolute(caminho.path_join(arquivo))
	DirAccess.remove_absolute(caminho)


func _fechar() -> void:
	partida.comecar(0)
	for caminho in _do_jogador():
		if FileAccess.file_exists(caminho):
			DirAccess.remove_absolute(caminho)
	_apagar_pasta(PONTOS)
	_devolver_a_reserva()
	print("")
	if falhas == 0:
		print("PONTOS_OK: cada dia de jogo guarda o seu ponto, um só, e ficam os sete mais novos; apagar e restaurar guardam o ponto de antes e se desfazem, com três de segurança; ponto que não se lê não toca a vaga; a vaga estragada volta pelo ponto; e pela tela a seta abre os pontos, e o segundo clique restaura")
	else:
		print("pontos: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame
