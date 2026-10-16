extends "res://tests/suite/caso.gd"
## #160 (e #18): os talentos de produção do quintal têm quem os leia — `pastoreio`,
## `pressa_do_curral`, `rendimento_do_morador` e `pericia_do_morador`.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste producao_do_quintal
##
## Sem o vale: a conta do serviço (`povoado.gd`, a mesma da aba Trabalho, #9), a postura adiantada
## (`curral_vale.gd`) e a recompensa do passo com `trabalho_do` (`cadeia_de_missoes.gd`).
##
##   1. O RENDIMENTO: a Palavra de patrão traz 50% a mais (4 mandiocas viram 6, 2 lenhas viram
##      3); o Empreiteiro soma 25% e a fé do Curimba, 50%; sem talento, a base.
##   2. A PERÍCIA: sem o Mestre de ofício um dia de serviço é um dia de prática; com ele o mesmo
##      dia conta por dois. Doze dias de roçado levam o Cosme a "jeitoso" (x1,35) e o dia de
##      roçado passa a pagar mais (4 mandiocas viram 5, 2 lenhas viram 3).
##   3. O PASSO DO COSME é a primeira designação: põe o Cosme na roça (`Terrenos`), conta o dia na
##      perícia dele e paga pela conta: o mesmo passo, três combinações de talento, três
##      mochilas. Um passo sem `trabalho_do` não passa pela conta.
##   4. A POSTURA ADIANTADA: sem o Trato do curral o dia de postura é o de hoje; com ele, a
##      partir das 17h é o de amanhã, e antes disso o de hoje.
##   5. O GALINHEIRO LÊ O CAMPO: `tem_pastoreio` é verdade com o Curral e falso sem.
##   6. O SAVE ANTIGO: os dias de prática da vaga antiga viram dias de roçado na perícia, sem
##      rebaixar quem já tem mais, e o curral não guarda mais `servico`.
##
## FALSIFICAR: `-- --sem-rendimento` e `-- --sem-pericia` tiram o talento no meio do portão, e
## ele tem que reprovar.
const ServicoDoMorador = preload("res://scripts/prototipo_3d/servico_do_morador.gd")
## O curral e a cadeia falam com os autoloads (`Talentos`, `Afinidade`) pelo nome: no `--script` eles só
## compilam depois que a árvore sobe, e por isso se carregam em `_initialize`, e não por `preload`.
var CurralVale: GDScript
var CadeiaDeMissoes: GDScript
const PASSO := {"id": "capataz_manha", "trabalho_do": "cosme", "recompensa": {"xp": 10, "mandioca": 4, "lenha": 2}}

var falhas := 0
var sem_rendimento := false
var sem_pericia := false


func _initialize() -> void:
	CurralVale = load("res://scripts/prototipo_3d/curral_vale.gd")
	CadeiaDeMissoes = load("res://scripts/prototipo_3d/cadeia_de_missoes.gd")
	_run.call_deferred()


func _conferir(ok: bool, texto: String) -> void:
	if not ok:
		falhas += 1
		push_error("PRODUCAO_FALHOU: " + texto)
		print("FALHA: ", texto)


func _zerar() -> void:
	root.get_node("Talentos").destravados.clear()
	root.get_node("Fe").ativa = ""
	root.get_node("Povoado").pericia.clear()
	root.get_node("Povoado").sobra.clear()
	root.get_node("Terrenos").trabalho.clear()
	root.get_node("Inventario").espacos.fill({})


func _run() -> void:
	var talentos := root.get_node("Talentos")
	var fe := root.get_node("Fe")
	var inventario := root.get_node("Inventario")
	sem_rendimento = "--sem-rendimento" in OS.get_cmdline_user_args()
	sem_pericia = "--sem-pericia" in OS.get_cmdline_user_args()

	var povoado := root.get_node("Povoado")
	# --- 1. O RENDIMENTO --------------------------------------------------------------------
	_zerar()
	_conferir(povoado.pagamento("cosme", "roca", 4) == 4, "sem talento o pagamento não é a base")
	_dar_talento("palavra_de_patrao", sem_rendimento)
	var rendimento: float = talentos.bonus("rendimento_do_morador")
	_conferir(is_equal_approx(rendimento, 0.5), "a Palavra de patrão não dá 50%%: %s" % str(rendimento))
	_conferir(povoado.pagamento("cosme", "roca", 4) == 6, "quatro mandiocas não viram seis com a Palavra de patrão")
	_conferir(povoado.pagamento("cosme", "roca", 2) == 3, "duas lenhas não viram três com a Palavra de patrão")
	talentos.destravados.append("empreiteiro")
	_conferir(is_equal_approx(talentos.bonus("rendimento_do_morador"), 0.75), "o Empreiteiro não soma 25%%: %s" % str(talentos.bonus("rendimento_do_morador")))
	talentos.destravados.clear()
	fe.ativa = "candomble"
	fe._estados["candomble"] = {"total": 120.0, "teto": 10, "destravados": ["curimba"]}
	fe._espelhar()
	_conferir(is_equal_approx(talentos.bonus("rendimento_do_morador"), 0.5), "o Curimba não rende 50%% ao patrão: %s" % str(talentos.bonus("rendimento_do_morador")))
	fe.ativa = ""
	fe._espelhar()
	_conferir(povoado.pagamento("cosme", "roca", 1) >= 1, "o pagamento ficou abaixo da base")

	# --- 2. A PERÍCIA --------------------------------------------------------------------------
	_zerar()
	_conferir(povoado.registrar_dia("cosme", "roca") == 1, "um dia de serviço sem perícia não contou um")
	_conferir(povoado.registrar_dia("cosme", "roca") == 2, "dois dias de serviço sem perícia não contaram dois")
	_conferir(povoado.dias_de("tonho", "roca") == 0, "o ofício do Cosme ensinou o Tonho")
	_conferir(povoado.dias_de("cosme", "farinha") == 0, "o roçado do Cosme ensinou a farinha")
	for i in 10:
		povoado.registrar_dia("cosme", "roca")
	_conferir(povoado.dias_de("cosme", "roca") == 12, "doze dias de serviço não contaram doze")
	_conferir(povoado.pagamento("cosme", "roca", 4) == 5 and povoado.pagamento("cosme", "roca", 2) == 3,
		"o Cosme jeitoso não traz mais no dia de roçado (4→5, 2→3)")
	_zerar()
	_dar_talento("mestre_de_oficio", sem_pericia)
	_conferir(povoado.registrar_dia("cosme", "roca") == 2, "com o Mestre de ofício um dia de serviço não conta por dois")

	# --- 3. O PASSO DO COSME ----------------------------------------------------------------------
	var ganhos := {}
	for caso in ["nenhum", "palavra", "palavra_e_mestre"]:
		_zerar()
		if caso != "nenhum":
			_dar_talento("palavra_de_patrao", sem_rendimento)
		if caso == "palavra_e_mestre":
			_dar_talento("mestre_de_oficio", sem_pericia)
		var fila = CadeiaDeMissoes.new()
		root.add_child(fila)
		fila.set_process(false)
		fila._pagar(PASSO)
		ganhos[caso] = [inventario.quantidade("mandioca"), inventario.quantidade("lenha")]
		_conferir(root.get_node("Terrenos").trabalho_de("cosme") == "roca", "o dia de roçado não pôs o Cosme na roça (%s)" % caso)
		_conferir(root.get_node("Povoado").dias_de("cosme", "roca") == (2 if caso == "palavra_e_mestre" else 1), "o dia de roçado não contou na perícia (%s)" % caso)
		fila.queue_free()
		await process_frame
	_conferir(ganhos["nenhum"] == [4, 2], "sem talento o Cosme não traz 4 e 2: %s" % str(ganhos["nenhum"]))
	_conferir(ganhos["palavra"] == [6, 3], "com a Palavra de patrão o Cosme não traz 6 e 3: %s" % str(ganhos["palavra"]))
	# O Mestre de ofício conta dois dias de serviço, e dois dias ainda são de aprendiz: a mesma mochila.
	_conferir(ganhos["palavra_e_mestre"] == [6, 3], "com a Palavra e o Mestre de ofício o Cosme não traz 6 e 3: %s" % str(ganhos["palavra_e_mestre"]))
	# Um passo SEM `trabalho_do` não passa pela conta, nem com os talentos.
	_zerar()
	talentos.destravados.append("palavra_de_patrao")
	var comum = CadeiaDeMissoes.new()
	root.add_child(comum)
	comum.set_process(false)
	comum._pagar({"id": "comum", "recompensa": {"mandioca": 4, "lenha": 2}})
	_conferir(inventario.quantidade("mandioca") == 4 and inventario.quantidade("lenha") == 2, "um passo comum passou pelo rendimento do morador")
	_conferir(root.get_node("Povoado").pericia.is_empty() and root.get_node("Terrenos").trabalho.is_empty(), "um passo comum pôs alguém para trabalhar")
	comum.queue_free()

	# --- 4. A POSTURA ADIANTADA -----------------------------------------------------------------------
	_conferir(CurralVale.dia_da_postura_vigente(10, 23, false) == 10, "sem o Trato do curral a postura adiantou")
	_conferir(CurralVale.dia_da_postura_vigente(10, 16, true) == 10, "o Trato do curral adiantou antes da hora")
	_conferir(CurralVale.dia_da_postura_vigente(10, 17, true) == 11, "o Trato do curral não adiantou às 17h")
	_conferir(CurralVale.dia_da_postura_vigente(10, 0, true) == 10, "na madrugada o Trato do curral adiantou de novo")
	var fonte := FileAccess.get_file_as_string("res://scripts/prototipo_3d/curral_vale.gd")
	_conferir(fonte.contains('bonus("pressa_do_curral")') and fonte.contains('bonus("pastoreio")'), "o curral não lê os campos dos talentos")

	# --- 5. O GALINHEIRO LÊ O CAMPO ----------------------------------------------------------------------
	_zerar()
	var curral = CurralVale.new()
	root.add_child(curral)
	curral.set_process(false)
	_conferir(not curral.tem_pastoreio(), "sem o Curral o galinheiro tem pastoreio")
	talentos.destravados.append("curral")
	_conferir(curral.tem_pastoreio(), "com o Curral o galinheiro não tem pastoreio")
	curral.queue_free()

	# --- 6. O SAVE ANTIGO -------------------------------------------------------------------------------
	_zerar()
	ServicoDoMorador.migrar({"cosme": 5, "tonho": 0}, povoado)
	_conferir(povoado.dias_de("cosme", "roca") == 5, "os dias da vaga antiga não viraram dias de roçado")
	_conferir(povoado.dias_de("tonho", "roca") == 0, "dia zero virou dia de roçado")
	ServicoDoMorador.migrar({"cosme": 2}, povoado)
	_conferir(povoado.dias_de("cosme", "roca") == 5, "a vaga antiga rebaixou a perícia do Cosme")
	var curral_novo = CurralVale.new()
	_conferir(not curral_novo.estado_para_salvar().has("servico"), "o curral ainda guarda os dias de serviço")
	curral_novo.free()

	_zerar()
	await process_frame
	print("PRODUCAO_DO_QUINTAL: %d falhas" % falhas)
	quit(1 if falhas else 0)


## Destrava o nó, a menos que o falsificador o tenha tirado.
func _dar_talento(no: String, tirar: bool) -> void:
	if not tirar:
		root.get_node("Talentos").destravados.append(no)
