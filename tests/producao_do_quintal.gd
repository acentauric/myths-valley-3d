extends SceneTree
## #160 (e #18): os talentos de produção do quintal têm quem os leia — `pastoreio`,
## `pressa_do_curral`, `rendimento_do_morador` e `pericia_do_morador`.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/producao_do_quintal.gd
##
## Sem o vale: a conta do serviço (`servico_do_morador.gd`), a postura adiantada
## (`curral_vale.gd`) e a recompensa do passo com `trabalho_do` (`cadeia_de_missoes.gd`).
##
##   1. O RENDIMENTO: a Palavra de patrão traz 50% a mais (4 mandiocas viram 6, 2 lenhas viram
##      3); o Empreiteiro soma 25% e a fé do Curimba, 50%; sem talento, a base.
##   2. A PERÍCIA: sem o Mestre de ofício um dia de serviço é um dia de prática e o ofício não
##      está aprendido; com ele o mesmo dia conta por dois e o ofício vem — e traz um quarto a
##      mais.
##   3. O PASSO DO COSME paga pela conta: o mesmo passo, três combinações de talento, três
##      mochilas. Um passo sem `trabalho_do` não passa pela conta.
##   4. A POSTURA ADIANTADA: sem o Trato do curral o dia de postura é o de hoje; com ele, a
##      partir das 17h é o de amanhã, e antes disso o de hoje.
##   5. O GALINHEIRO LÊ O CAMPO: `tem_pastoreio` é verdade com o Curral e falso sem.
##   6. O SAVE: os dias de prática vão e voltam.
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
	ServicoDoMorador.limpar()
	root.get_node("Inventario").espacos.fill({})


func _run() -> void:
	var talentos := root.get_node("Talentos")
	var fe := root.get_node("Fe")
	var inventario := root.get_node("Inventario")
	sem_rendimento = "--sem-rendimento" in OS.get_cmdline_user_args()
	sem_pericia = "--sem-pericia" in OS.get_cmdline_user_args()

	# --- 1. O RENDIMENTO --------------------------------------------------------------------
	_zerar()
	_conferir(ServicoDoMorador.pagamento(4, talentos.bonus("rendimento_do_morador"), false) == 4, "sem talento o pagamento não é a base")
	_dar_talento("palavra_de_patrao", sem_rendimento)
	var rendimento: float = talentos.bonus("rendimento_do_morador")
	_conferir(is_equal_approx(rendimento, 0.5), "a Palavra de patrão não dá 50%%: %s" % str(rendimento))
	_conferir(ServicoDoMorador.pagamento(4, rendimento, false) == 6, "quatro mandiocas não viram seis com a Palavra de patrão")
	_conferir(ServicoDoMorador.pagamento(2, rendimento, false) == 3, "duas lenhas não viram três com a Palavra de patrão")
	talentos.destravados.append("empreiteiro")
	_conferir(is_equal_approx(talentos.bonus("rendimento_do_morador"), 0.75), "o Empreiteiro não soma 25%%: %s" % str(talentos.bonus("rendimento_do_morador")))
	talentos.destravados.clear()
	fe.ativa = "candomble"
	fe._estados["candomble"] = {"total": 120.0, "teto": 10, "destravados": ["curimba"]}
	fe._espelhar()
	_conferir(is_equal_approx(talentos.bonus("rendimento_do_morador"), 0.5), "o Curimba não rende 50%% ao patrão: %s" % str(talentos.bonus("rendimento_do_morador")))
	fe.ativa = ""
	fe._espelhar()
	_conferir(ServicoDoMorador.pagamento(1, -3.0, false) == 1, "rendimento negativo tirou da base")

	# --- 2. A PERÍCIA --------------------------------------------------------------------------
	_zerar()
	_conferir(ServicoDoMorador.registrar_dia("cosme", talentos.bonus("pericia_do_morador")) == 1 and not ServicoDoMorador.aprendeu("cosme"),
		"um dia de serviço sem perícia já ensinou o ofício")
	_conferir(ServicoDoMorador.registrar_dia("cosme", talentos.bonus("pericia_do_morador")) == 2 and ServicoDoMorador.aprendeu("cosme"),
		"dois dias de serviço sem perícia não ensinaram o ofício")
	_zerar()
	_dar_talento("mestre_de_oficio", sem_pericia)
	_conferir(ServicoDoMorador.registrar_dia("cosme", talentos.bonus("pericia_do_morador")) == 2 and ServicoDoMorador.aprendeu("cosme"),
		"com o Mestre de ofício um dia de serviço não conta por dois")
	_conferir(ServicoDoMorador.pagamento(4, 0.0, true) == 5 and ServicoDoMorador.pagamento(2, 0.0, true) == 3,
		"o ofício aprendido não traz um quarto a mais (4→5, 2→3)")
	_conferir(not ServicoDoMorador.aprendeu("tonho"), "o ofício do Cosme ensinou o Tonho")

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
		fila.queue_free()
		await process_frame
	_conferir(ganhos["nenhum"] == [4, 2], "sem talento o Cosme não traz 4 e 2: %s" % str(ganhos["nenhum"]))
	_conferir(ganhos["palavra"] == [6, 3], "com a Palavra de patrão o Cosme não traz 6 e 3: %s" % str(ganhos["palavra"]))
	# Palavra (50%) e ofício aprendido no primeiro dia (25%): 4 × 1,75 = 7 e 2 × 1,75 = 3,5 → 4.
	_conferir(ganhos["palavra_e_mestre"] == [7, 4], "com a Palavra e o Mestre de ofício o Cosme não traz 7 e 4: %s" % str(ganhos["palavra_e_mestre"]))
	# Um passo SEM `trabalho_do` não passa pela conta, nem com os talentos.
	_zerar()
	talentos.destravados.append("palavra_de_patrao")
	var comum = CadeiaDeMissoes.new()
	root.add_child(comum)
	comum.set_process(false)
	comum._pagar({"id": "comum", "recompensa": {"mandioca": 4, "lenha": 2}})
	_conferir(inventario.quantidade("mandioca") == 4 and inventario.quantidade("lenha") == 2, "um passo comum passou pelo rendimento do morador")
	_conferir(ServicoDoMorador.dias.is_empty(), "um passo comum contou dia de serviço")
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

	# --- 6. O SAVE -------------------------------------------------------------------------------------------
	_zerar()
	ServicoDoMorador.registrar_dia("cosme", 0.0)
	var estado := ServicoDoMorador.estado_para_salvar()
	ServicoDoMorador.limpar()
	_conferir(ServicoDoMorador.dias.is_empty(), "limpar não zerou os dias")
	ServicoDoMorador.restaurar(estado)
	_conferir(int(ServicoDoMorador.dias.get("cosme", 0)) == 1, "os dias de serviço não voltaram do save")
	ServicoDoMorador.restaurar({})
	_conferir(ServicoDoMorador.dias.is_empty(), "restaurar vazio manteve os dias")

	_zerar()
	await process_frame
	print("PRODUCAO_DO_QUINTAL: %d falhas" % falhas)
	quit(1 if falhas else 0)


## Destrava o nó, a menos que o falsificador o tenha tirado.
func _dar_talento(no: String, tirar: bool) -> void:
	if not tirar:
		root.get_node("Talentos").destravados.append(no)
