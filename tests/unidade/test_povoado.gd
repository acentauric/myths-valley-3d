extends "res://tests/unidade/base.gd"
## #9: o que os moradores POSTOS PARA TRABALHAR rendem por dia, e que nada disso se perde ao salvar.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste povoado
##
## A conta é a do 2D (`Povoado`): tabela do ofício, vezes o ritmo do idoso, vezes PERÍCIA, AMIZADE e
## OBRAS DO ARRAIAL, vezes o talento do patrão; o que sobra da fração vai para o dia seguinte. Este
## teste segura o que não dá erro nenhum quando quebra:
##
##   1. OS DADOS FECHAM. Obra do arraial que não existe no catálogo de obras, ofício que ela cita
##      e não existe, graus de amizade que não casam com os da `Afinidade`: a conta somaria zero e
##      ninguém veria, porque zero é uma resposta válida.
##   2. A PERÍCIA SOBE DE DEGRAU nos dias certos (1,0 / 1,35 / 1,8 / 2,4 em 0 / 12 / 30 / 70 dias),
##      por morador e por ofício. O Cosme mestre de roça é aprendiz de farinha.
##   3. A AMIZADE MULTIPLICA de 1,0 a 1,5, sem nunca zerar o estranho.
##   4. AS OBRAS DO ARRAIAL SOMAM, cada uma nos ofícios que serve (o trapiche, em todos), e só a obra
##      certa na peça certa conta (o mutirão do poço não é a roldana e a cacimba).
##   5. OS DOIS TALENTOS DO PATRÃO: Palavra de patrão rende mais; Mestre de ofício faz o dia valer
##      dois na perícia.
##   6. A CONTA INTEIRA, de ponta a ponta, contra um número feito à mão; e o idoso rende metade.
##   7. A SOBRA FECHA A CONTA: quem rende 0,4 por dia entrega 1 a cada 2,5 dias, e não zero para
##      sempre; perguntar quanto vai render não gasta a sobra.
##   8. O AMANHECER ENTREGA NA MOCHILA, conta o dia de serviço DEPOIS de entregar, não rende em terra
##      que não é do jogador, e o que não cabe na mochila espera no paiol em vez de sumir.
##   9. O SAVE LEVA A PERÍCIA, A SOBRA E O PAIOL, não passa de uma vaga para a outra, e cobre todo
##      campo público do `Povoado` e do `Terrenos`.
##
## FALSIFICAÇÃO (a regra quebrada tem de reprovar), numa cópia carregada em memória do script, sem
## tocar no arquivo. O GUT recusa argumento que não conhece, então o pedido vai por variável de
## ambiente (o `testar.ps1` a repassa ao Godot):
##
##     $env:TESTAR3D_FALSIFICAR = "sobra"; .\tools\prototipo_3d\testar.ps1 -Teste povoado
##
##   sobra           o resto da fração se perde todo dia: reprova em (7)
##   ritmo           o idoso rende como quem tem braço: reprova em (6)
##   afinidade       a amizade deixa de multiplicar: reprova em (3)
##   arraial         as obras do arraial deixam de somar: reprova em (4)
##   patrao          Palavra de patrão deixa de valer: reprova em (5)
##   mestre          Mestre de ofício deixa de dobrar o dia: reprova em (5)
##   ordem           o dia de serviço conta ANTES de entregar: reprova em (8)
##   paiol           o que não cabe na mochila é jogado fora: reprova em (8)
##   salvar_pericia  o save esquece a sobra fracionária: reprova em (9)
##
## Rodado direto com `--script`, vale também `-- --falsificar=sobra`.

var terrenos
var terras
var povoado
var jogo
var talentos
var afinidade
var obras
var inventario
var relogio
var salvamento
var partida
var falsificar := ""


func before_each() -> void:
	super.before_each()
	falsificar = OS.get_environment("TESTAR3D_FALSIFICAR")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--falsificar="):
			falsificar = arg.substr("--falsificar=".length())
	match falsificar:
		"sobra":
			_mutar("/root/Povoado", "res://scripts/compartilhado/povoado.gd",
				[["sobra[item] = maxf(0.0, com_a_sobra - float(inteiro))", "sobra[item] = 0.0"]])
		"ritmo":
			_mutar("/root/Povoado", "res://scripts/compartilhado/povoado.gd",
				[["quanto *= Terrenos.ritmo_do_idoso()", "quanto *= 1.0"]])
		"afinidade":
			_mutar("/root/Povoado", "res://scripts/compartilhado/povoado.gd",
				[["return por_pericia * por_afeto * (1.0 + rende_do_arraial(oficio))",
					"return por_pericia * (1.0 + rende_do_arraial(oficio))"]])
		"arraial":
			_mutar("/root/Povoado", "res://scripts/compartilhado/povoado.gd",
				[['soma += float(dado.get("rende", 0.0))', "soma += 0.0"]])
		"patrao":
			_mutar("/root/Povoado", "res://scripts/compartilhado/povoado.gd",
				[['quanto *= 1.0 + Talentos.bonus("rendimento_do_morador")', "quanto *= 1.0"]])
		"mestre":
			_mutar("/root/Povoado", "res://scripts/compartilhado/povoado.gd",
				[['var quanto := maxi(1, roundi(1.0 + Talentos.bonus("pericia_do_morador")))', "var quanto := 1"]])
		"ordem":
			_mutar("/root/Terrenos", "res://scripts/compartilhado/terrenos.gd", [
				["\tvar total: Dictionary = Povoado.entregar_o_dia()\n",
					"\tPovoado.contar_o_dia()\n\tvar total: Dictionary = Povoado.entregar_o_dia()\n"],
				["\tesvaziar_o_paiol()\n\tPovoado.contar_o_dia()\n", "\tesvaziar_o_paiol()\n"]])
		"paiol":
			_mutar("/root/Terrenos", "res://scripts/compartilhado/terrenos.gd",
				[["elif Inventario.adicionar(str(item), quanto):", "elif Inventario.adicionar(str(item), quanto) or true:"]])
		"salvar_pericia":
			_mutar("/root/Salvamento", "res://scripts/compartilhado/salvamento.gd",
				[['"Povoado": ["pericia", "sobra"],', '"Povoado": ["pericia"],']])
	terrenos = root.get_node("/root/Terrenos")
	terras = root.get_node("/root/Terras")
	povoado = root.get_node("/root/Povoado")
	jogo = root.get_node("/root/Jogo")
	talentos = root.get_node("/root/Talentos")
	afinidade = root.get_node("/root/Afinidade")
	obras = root.get_node("/root/Obras")
	inventario = root.get_node("/root/Inventario")
	relogio = root.get_node("/root/Relogio")
	salvamento = root.get_node("/root/Salvamento")
	partida = root.get_node("/root/Partida")
	_em_branco()


## Troca o script do autoload por uma cópia com cada `[de, para]` aplicado. A cópia tem de compilar
## e cada troca tem de pegar, senão a falsificação passaria em branco.
func _mutar(no: String, caminho: String, trocas: Array) -> void:
	var fonte := FileAccess.get_file_as_string(caminho)
	for troca in trocas:
		conferir(fonte.contains(str(troca[0])), "a falsificação %s não achou o trecho a trocar em %s" % [falsificar, caminho])
		fonte = fonte.replace(str(troca[0]), str(troca[1]))
	var mutante := GDScript.new()
	mutante.source_code = fonte
	conferir(mutante.reload() == OK, "a cópia falsificada de %s não compilou" % caminho)
	root.get_node(no).set_script(mutante)


## Partida em branco: só o roçado, sem talento, sem fé, ninguém com amizade, nenhuma obra, ninguém
## trabalhando, mochila vazia.
func _em_branco() -> void:
	terras.posses = {"rocado": true}
	talentos.destravados.clear()
	root.get_node("/root/Fe").ativa = ""
	afinidade.pontos.clear()
	obras.feitas.clear()
	povoado.pericia.clear()
	povoado.sobra.clear()
	terrenos.trabalho.clear()
	terrenos.no_paiol.clear()
	_esvaziar_a_mochila()
	jogo.dinheiro = 9000


func _esvaziar_a_mochila() -> void:
	for i in inventario.espacos.size():
		inventario.espacos[i] = {}


## A terra da Zefa e a do Benedito são do jogador, e cada um posto no ofício que o teste pede.
func _por_para_trabalhar(combinado: Dictionary) -> void:
	terras.posses["terreno_zefa"] = true
	terras.posses["terreno_benedito"] = true
	for morador in combinado:
		conferir(terrenos.mandar_trabalhar(str(morador), str(combinado[morador])),
			"o teste não conseguiu pôr %s no ofício '%s'" % [morador, combinado[morador]])


# --- 1. os dados fecham ----------------------------------------------------------------

func test_os_dados_do_povoado_fecham() -> void:
	var degraus: Array = povoado.degraus()
	conferir(degraus.size() >= 2, "o povoado tem %d degrau(s) de perícia" % degraus.size())
	conferir(int(degraus[0]["de"]) == 0, "o primeiro degrau tem de começar em zero dias: todo mundo começa aprendiz")
	conferir(is_equal_approx(float(degraus[0]["rende"]), 1.0), "o aprendiz rende o que o ofício rende, nem mais nem menos")
	for i in degraus.size():
		conferir(str(degraus[i].get("nome", "")) != "", "o degrau %d está sem nome" % i)
		conferir(is_equal_approx(povoado.rende_do_degrau(i), float(degraus[i]["rende"])), "rende_do_degrau(%d) não leu o dado" % i)
		if i > 0:
			conferir(int(degraus[i]["de"]) > int(degraus[i - 1]["de"]), "os degraus não estão em ordem de dias")
			conferir(float(degraus[i]["rende"]) > float(degraus[i - 1]["rende"]), "subir de degrau tem de render mais")

	var afetos: Array = povoado.por_grau_de_afinidade()
	conferir(afetos.size() == afinidade.GRAUS.size(),
		"há %d números de amizade e %d graus de afinidade: um por grau" % [afetos.size(), afinidade.GRAUS.size()])
	conferir(is_equal_approx(float(afetos[0]), 1.0), "o estranho tem de render o normal, e não zero")
	for i in range(1, afetos.size()):
		conferir(float(afetos[i]) >= float(afetos[i - 1]), "a amizade maior rende menos no grau %d" % i)

	var feitas: Dictionary = povoado.obras_do_arraial()
	conferir(feitas.size() == 5, "as obras do arraial são cinco: poço, forno, monjolo, carroça e trapiche")
	for obra in feitas:
		var dado: Dictionary = feitas[obra]
		conferir(not obras.dados(str(obra)).is_empty(), "a obra do arraial '%s' não existe em data/construcoes/obras.json" % obra)
		conferir((obras.dados(str(obra)).get("alvos", []) as Array).has(str(dado["construcao"])),
			"a obra '%s' se pendura em '%s', que não é peça que ela serve" % [obra, dado["construcao"]])
		conferir(float(dado["rende"]) > 0.0, "a obra '%s' rende %s" % [obra, str(dado["rende"])])
		for oficio in dado.get("oficios", []):
			conferir(terrenos.existe(str(oficio)), "a obra '%s' serve ao ofício '%s', que não existe" % [obra, oficio])
	conferir((feitas["arraial_trapiche"]["oficios"] as Array).is_empty(), "o trapiche serve a todos: lista vazia")


# --- 2. a perícia ----------------------------------------------------------------------

func test_a_pericia_sobe_de_degrau_por_morador_e_por_oficio() -> void:
	# dias de serviço -> [degrau, multiplicador]
	for caso in [[0, 0, 1.0], [11, 0, 1.0], [12, 1, 1.35], [29, 1, 1.35], [30, 2, 1.8], [69, 2, 1.8], [70, 3, 2.4], [500, 3, 2.4]]:
		povoado.pericia = {"cosme": {"roca": caso[0]}}
		conferir(povoado.grau_de_pericia("cosme", "roca") == caso[1],
			"com %d dias o degrau devia ser %d e é %d" % [caso[0], caso[1], povoado.grau_de_pericia("cosme", "roca")])
		conferir(is_equal_approx(povoado.rendimento("cosme", "roca"), caso[2]),
			"com %d dias o Cosme devia render x%s e rende x%s" % [caso[0], str(caso[2]), str(povoado.rendimento("cosme", "roca"))])

	# É por ofício: quarenta dias de roça não fazem mestre de farinha. E é por morador.
	povoado.pericia = {"cosme": {"roca": 70}}
	conferir(povoado.grau_de_pericia("cosme", "farinha") == 0, "a perícia da roça valeu na casa de farinha")
	conferir(is_equal_approx(povoado.rendimento("cosme", "farinha"), 1.0), "o Cosme de farinha devia ser aprendiz")
	conferir(povoado.grau_de_pericia("tonho", "roca") == 0, "a perícia do Cosme valeu para o Tonho")

	# Quanto falta para subir.
	povoado.pericia = {"cosme": {"roca": 5}}
	conferir(povoado.falta_para_o_proximo("cosme", "roca") == 7, "faltam 7 dias para o jeitoso: %d" % povoado.falta_para_o_proximo("cosme", "roca"))
	povoado.pericia = {"cosme": {"roca": 70}}
	conferir(povoado.falta_para_o_proximo("cosme", "roca") == -1, "o mestre não tem próximo degrau")

	# O degrau tem nome para o jogador, e o nome muda de degrau para degrau.
	var nomes := {}
	for dias in [0, 12, 30, 70]:
		povoado.pericia = {"cosme": {"roca": dias}}
		var nome: String = povoado.nome_da_pericia("cosme", "roca")
		conferir(nome != "" and not nomes.has(nome), "o degrau de %d dias está sem nome ou repete o de outro: '%s'" % [dias, nome])
		nomes[nome] = true


# --- 3. a amizade ----------------------------------------------------------------------

func test_a_amizade_multiplica_de_1_a_1_5() -> void:
	var pontos := [0, 10, 30, 60, 100]
	var fatores := [1.0, 1.05, 1.15, 1.3, 1.5]
	for i in pontos.size():
		afinidade.pontos["cosme"] = pontos[i]
		conferir(afinidade.grau("cosme") == i, "com %d pontos o grau devia ser %d" % [pontos[i], i])
		conferir(is_equal_approx(povoado.rendimento("cosme", "roca"), fatores[i]),
			"no grau %d o Cosme devia render x%s e rende x%s" % [i, str(fatores[i]), str(povoado.rendimento("cosme", "roca"))])
	# É por morador: a amizade com o Cosme não é amizade com o Tonho.
	conferir(is_equal_approx(povoado.rendimento("tonho", "roca"), 1.0), "a amizade do Cosme valeu para o Tonho")


# --- 4. as obras do arraial ------------------------------------------------------------

func test_as_obras_do_arraial_somam_nos_oficios_que_servem() -> void:
	var oficios := ["roca", "lenha", "farinha", "artesanato", "criacao"]
	var soma := func(esperado: Array, rotulo: String) -> void:
		for i in oficios.size():
			conferir(is_equal_approx(povoado.rende_do_arraial(oficios[i]), esperado[i]),
				"%s: em '%s' as obras somam %s e deviam somar %s" % [rotulo, oficios[i], str(povoado.rende_do_arraial(oficios[i])), str(esperado[i])])
	soma.call([0.0, 0.0, 0.0, 0.0, 0.0], "sem obra nenhuma")

	obras.feitas = {"poco": ["arraial_poco"]}
	soma.call([0.35, 0.0, 0.0, 0.0, 0.35], "com a roldana e a cacimba do poço")
	conferir(povoado.obra_do_arraial_feita("arraial_poco"), "a obra do poço está feita")
	conferir(not povoado.obra_do_arraial_feita("arraial_forno"), "a obra do forno não está feita")
	obras.feitas["monjolo"] = ["arraial_monjolo"]
	soma.call([0.70, 0.0, 0.35, 0.0, 0.35], "mais o monjolo (somam entre si)")
	obras.feitas["forno_barro"] = ["arraial_forno"]
	soma.call([0.70, 0.0, 0.85, 0.0, 0.35], "mais o forno")
	obras.feitas["carroca"] = ["arraial_carroca"]
	soma.call([0.70, 0.4, 0.85, 0.4, 0.35], "mais a carroça")
	obras.feitas["trapiche"] = ["arraial_trapiche"]
	soma.call([0.95, 0.65, 1.10, 0.65, 0.60], "mais o trapiche, que serve a todos")
	conferir(is_equal_approx(povoado.rende_do_arraial("nada"), 0.25), "o trapiche serve a TODOS os ofícios, inclusive os que ainda vêm")
	# Aprendiz sem amizade: o multiplicador é 1 + o que as obras somam.
	conferir(is_equal_approx(povoado.rendimento("cosme", "roca"), 1.95), "o Cosme na roça devia render x1,95 com as cinco obras")

	# Só vale a obra certa na peça certa. O mutirão do poço do começo não é a roldana, e a roldana
	# numa casa não conserta o poço da praça.
	obras.feitas = {"poco": ["poco_corda"]}
	soma.call([0.0, 0.0, 0.0, 0.0, 0.0], "só o mutirão do poço (poco_corda)")
	obras.feitas = {"casa": ["arraial_poco"]}
	soma.call([0.0, 0.0, 0.0, 0.0, 0.0], "a roldana registrada numa casa")


# --- 5. os dois talentos do patrão -----------------------------------------------------

func test_palavra_de_patrao_e_mestre_de_oficio() -> void:
	for no in ["palavra_de_patrao", "mestre_de_oficio", "empreiteiro"]:
		conferir(talentos.NOS.has(no), "o talento '%s' não existe mais: o teste precisa de outro nó" % no)
	conferir(is_equal_approx(float(povoado.renderia_exata("cosme", "roca")["mandioca"]), 2.0), "a roça rende 2 de mandioca por dia ao aprendiz")

	talentos.destravados = ["palavra_de_patrao"]
	conferir(is_equal_approx(float(povoado.renderia_exata("cosme", "roca")["mandioca"]), 3.0),
		"Palavra de patrão: quem trabalha para você rende 50%% a mais (3 e não 2): %s" % str(povoado.renderia_exata("cosme", "roca")))
	talentos.destravados = ["palavra_de_patrao", "empreiteiro"]
	conferir(is_equal_approx(float(povoado.renderia_exata("cosme", "roca")["mandioca"]), 3.5),
		"Palavra de patrão (+50%%) e Empreiteiro (+25%%) somam +75%%: 3,5 e não %s" % str(povoado.renderia_exata("cosme", "roca")))

	# Mestre de ofício: cada dia de serviço conta por dois. Sem ele, conta um.
	_por_para_trabalhar({"cosme": "roca"})
	talentos.destravados.clear()
	povoado.contar_o_dia()
	conferir(povoado.dias_de("cosme", "roca") == 1, "um dia de serviço devia contar 1: %d" % povoado.dias_de("cosme", "roca"))
	talentos.destravados = ["mestre_de_oficio"]
	povoado.contar_o_dia()
	conferir(povoado.dias_de("cosme", "roca") == 3, "Mestre de ofício: o dia conta por dois (1 + 2 = 3): %d" % povoado.dias_de("cosme", "roca"))
	conferir(povoado.dias_de("cosme", "farinha") == 0, "o dia de roça contou na farinha")


# --- 6. a conta inteira, e o idoso -----------------------------------------------------

func test_a_conta_inteira_e_o_idoso_rende_metade() -> void:
	_por_para_trabalhar({"cosme": "roca"})
	# Mestre (x2,4), da família (x1,5), poço e monjolo na roça (+0,70) e Palavra de patrão (+50%):
	# 2 de mandioca x 2,4 x 1,5 x 1,70 x 1,5 = 18,36.
	povoado.pericia = {"cosme": {"roca": 70}}
	afinidade.pontos["cosme"] = 100
	obras.feitas = {"poco": ["arraial_poco"], "monjolo": ["arraial_monjolo"]}
	talentos.destravados = ["palavra_de_patrao"]
	var a_mao := 2.0 * 2.4 * 1.5 * 1.70 * 1.5
	conferir(is_equal_approx(a_mao, 18.36), "a conta à mão devia dar 18,36 e deu %s" % str(a_mao))
	conferir(is_equal_approx(float(povoado.renderia_exata("cosme", "roca")["mandioca"]), a_mao),
		"a conta inteira devia dar %s e deu %s" % [str(a_mao), str(povoado.renderia_exata("cosme", "roca"))])
	conferir(povoado.renderia("cosme", "roca") == {"mandioca": 18}, "a vista arredondada: %s" % str(povoado.renderia("cosme", "roca")))
	conferir(povoado.producao_do_dia() == {"mandioca": 18}, "a produção do dia: %s" % str(povoado.producao_do_dia()))

	# Quatro manhãs: 18, 18, 19 e 18, que é o chão de 4 x 18,36 = 73,44 (e sobram 0,44).
	var entregue := 0
	var por_dia: Array = []
	for _dia in 4:
		var hoje: int = int(povoado.entregar_o_dia().get("mandioca", 0))
		por_dia.append(hoje)
		entregue += hoje
	conferir(por_dia == [18, 18, 19, 18], "a entrega das quatro manhãs: %s" % str(por_dia))
	conferir(entregue == 73, "em quatro manhãs deviam sair 73 e saíram %d" % entregue)
	conferir(is_equal_approx(float(povoado.sobra.get("mandioca", -1.0)), 0.44), "a sobra devia ser 0,44: %s" % str(povoado.sobra))

	# O IDOSO rende a metade do que rende quem tem braço, em tudo o mais igual.
	_em_branco()
	_por_para_trabalhar({"cosme": "farinha", "zefa": "farinha"})
	povoado.pericia = {"cosme": {"farinha": 70}, "zefa": {"farinha": 70}}
	afinidade.pontos["cosme"] = 100
	afinidade.pontos["zefa"] = 100
	var dele := float(povoado.renderia_exata("cosme", "farinha")["farinha"])
	var dela := float(povoado.renderia_exata("zefa", "farinha")["farinha"])
	conferir(is_equal_approx(dele, 2.0 * 2.4 * 1.5), "o Cosme na farinha: %s" % str(dele))
	conferir(is_equal_approx(dela, dele * terrenos.ritmo_do_idoso()), "a Zefa devia render %s do Cosme, e rende %s de %s" % [str(terrenos.ritmo_do_idoso()), str(dela), str(dele)])
	conferir(is_equal_approx(dela, dele * 0.5), "o idoso rende a metade (x0,5): %s contra %s" % [str(dela), str(dele)])


# --- o retrato do arraial -------------------------------------------------------------

func test_o_retrato_do_arraial() -> void:
	var vazio: Dictionary = povoado.retrato()
	conferir(vazio == {"terras": 0, "trabalhando": 0, "mestres": 0, "comunitarias": 0, "por_dia": {}},
		"o arraial sem nada devia ter o retrato zerado, e o roçado que já era do jogador não conta como terra tomada: %s" % str(vazio))
	_por_para_trabalhar({"cosme": "roca", "zefa": "farinha"})
	povoado.pericia = {"cosme": {"roca": 70}}
	obras.feitas = {"poco": ["arraial_poco"], "trapiche": ["arraial_trapiche"]}
	var retrato: Dictionary = povoado.retrato()
	conferir(retrato["terras"] == 2, "terras tomadas: %s" % str(retrato["terras"]))
	conferir(retrato["trabalhando"] == 2, "gente trabalhando: %s" % str(retrato["trabalhando"]))
	conferir(retrato["mestres"] == 1, "mestres (só o Cosme na roça): %s" % str(retrato["mestres"]))
	conferir(retrato["comunitarias"] == 2, "obras do arraial feitas: %s" % str(retrato["comunitarias"]))
	conferir(retrato["por_dia"] == povoado.producao_do_dia() and not (retrato["por_dia"] as Dictionary).is_empty(),
		"o retrato tem de mostrar a mesma produção do dia que a tela: %s" % str(retrato["por_dia"]))


# --- 7. a sobra fecha a conta ----------------------------------------------------------

func test_a_sobra_fecha_a_conta() -> void:
	# O Seu Benedito na cestaria, "conhecido de vista" (x1,05): 1 de corda x 0,5 do idoso x 1,05.
	_por_para_trabalhar({"benedito": "artesanato"})
	afinidade.pontos["benedito"] = 10
	var por_dia := 1.0 * 0.5 * 1.05
	conferir(is_equal_approx(float(povoado.renderia_exata("benedito", "artesanato")["corda"]), por_dia), "o Benedito devia render 0,525 de corda por dia")
	var entregue := 0
	var maior_dia := 0
	for _dia in 40:
		var hoje: int = int(povoado.entregar_o_dia().get("corda", 0))
		entregue += hoje
		maior_dia = maxi(maior_dia, hoje)
	conferir(entregue == 21, "em 40 dias a 0,525 por dia devem sair 21 de corda e saíram %d: sem a sobra, a fração se perde" % entregue)
	conferir(maior_dia <= 1, "nenhum dia rende mais que 1 de corda (saiu %d num dia)" % maior_dia)
	conferir(absf(float(entregue) + float(povoado.sobra.get("corda", 0.0)) - 40.0 * por_dia) < 0.000001,
		"o que saiu mais o que sobrou tem de fechar com 40 x 0,525: %d + %s" % [entregue, str(povoado.sobra)])
	conferir(float(povoado.sobra.get("corda", 0.0)) >= 0.0 and float(povoado.sobra.get("corda", 0.0)) < 1.0, "a sobra tem de ficar entre 0 e 1: %s" % str(povoado.sobra))

	# QUEM RENDE 0,4 POR DIA: um item a cada dois dias e meio, e não zero para sempre.
	# O dado é mexido em memória (o cache de dados volta ao normal antes do teste seguinte).
	povoado.sobra.clear()
	afinidade.pontos.clear()
	jogo.dados(terras.ARQUIVO)["oficios"]["artesanato"]["rende"] = {"corda": 0.8}
	conferir(is_equal_approx(float(povoado.renderia_exata("benedito", "artesanato")["corda"]), 0.4), "o teste devia render 0,4 por dia")
	var cinco_dias: Array = []
	for _dia in 5:
		cinco_dias.append(int(povoado.entregar_o_dia().get("corda", 0)))
	conferir(cinco_dias == [0, 0, 1, 0, 1], "a 0,4 por dia a entrega devia ser [0, 0, 1, 0, 1] e foi %s" % str(cinco_dias))

	# PERGUNTAR NÃO GASTA: a tela consulta o quanto vai render, e a mochila recebe o mesmo.
	povoado.sobra = {"corda": 0.7}
	var antes: Dictionary = povoado.sobra.duplicate(true)
	for _vez in 5:
		povoado.producao_do_dia()
		povoado.renderia("benedito", "artesanato")
	conferir(povoado.sobra == antes, "consultar a produção mexeu na sobra: %s" % str(povoado.sobra))
	var prometido: Dictionary = povoado.producao_do_dia()
	conferir(povoado.entregar_o_dia() == prometido, "a mochila recebeu %s e a tela prometia %s" % [str(prometido), str(povoado.producao_do_dia())])


# --- 8. o amanhecer --------------------------------------------------------------------

func test_o_amanhecer_entrega_na_mochila_e_conta_o_dia_depois() -> void:
	var recebidos: Array = []
	terrenos.renderam.connect(func(colhido: Dictionary) -> void: recebidos.append(colhido))

	# SEM NINGUÉM TRABALHANDO nada entra, nada se conta, e ninguém é avisado.
	relogio.dormir()
	conferir(inventario.quantidade("mandioca") == 0 and recebidos.is_empty(), "o amanhecer entregou sem ninguém trabalhando")
	conferir(povoado.pericia.is_empty(), "o amanhecer contou dia de serviço sem ninguém trabalhando")

	_por_para_trabalhar({"cosme": "roca", "zefa": "farinha"})
	relogio.dormir()
	conferir(inventario.quantidade("mandioca") == 2, "o Cosme devia deixar 2 de mandioca na mochila: %d" % inventario.quantidade("mandioca"))
	conferir(inventario.quantidade("farinha") == 1, "a Zefa devia deixar 1 de farinha (idosa) na mochila: %d" % inventario.quantidade("farinha"))
	conferir(recebidos == [{"mandioca": 2, "farinha": 1}], "o aviso do amanhecer: %s" % str(recebidos))
	conferir(povoado.dias_de("cosme", "roca") == 1 and povoado.dias_de("zefa", "farinha") == 1, "o dia de serviço não entrou na perícia: %s" % str(povoado.pericia))
	conferir(terrenos.no_paiol.is_empty(), "o paiol devia estar vazio com a mochila vazia")

	# O DIA DE SERVIÇO CONTA DEPOIS DE ENTREGAR. Com 11 dias de roça, a manhã entrega ainda a x1,0
	# (2 inteiros, nada sobra) e a perícia passa a 12; a manhã seguinte já é x1,35 (2,7: sai 2, sobra 0,7).
	_em_branco()
	_por_para_trabalhar({"cosme": "roca"})
	povoado.pericia = {"cosme": {"roca": 11}}
	relogio.dormir()
	conferir(inventario.quantidade("mandioca") == 2, "a manhã do dia 12 entregou %d, e devia ser 2 (ainda x1,0)" % inventario.quantidade("mandioca"))
	conferir(absf(float(povoado.sobra.get("mandioca", 0.0))) < 0.000001,
		"a entrega já usou o degrau novo: sobrou %s e devia ser zero (o dia só conta depois de entregar)" % str(povoado.sobra))
	conferir(povoado.dias_de("cosme", "roca") == 12, "o dia de serviço não entrou: %d" % povoado.dias_de("cosme", "roca"))
	relogio.dormir()
	conferir(is_equal_approx(float(povoado.sobra.get("mandioca", 0.0)), 0.7), "a manhã seguinte devia render x1,35 (2,7) e sobrar 0,7: %s" % str(povoado.sobra))
	conferir(inventario.quantidade("mandioca") == 4, "duas manhãs deviam somar 4 de mandioca: %d" % inventario.quantidade("mandioca"))

	# TERRA QUE NÃO É DO JOGADOR não rende nem conta. O ofício fica guardado.
	_em_branco()
	_por_para_trabalhar({"cosme": "roca"})
	terras.posses.erase("terreno_zefa")
	relogio.dormir()
	conferir(inventario.quantidade("mandioca") == 0, "o morador rendeu em terra que deixou de ser do jogador")
	conferir(povoado.dias_de("cosme", "roca") == 0, "contou dia de serviço em terra que deixou de ser do jogador")
	conferir(terrenos.trabalho_de("cosme") == "roca", "o combinado devia ficar guardado")


func test_o_que_nao_cabe_na_mochila_espera_no_paiol() -> void:
	_por_para_trabalhar({"cosme": "roca"})
	# Mochila toda ocupada por outra coisa.
	for i in inventario.espacos.size():
		inventario.espacos[i] = {"id": "pedra", "qtd": 99}
	relogio.dormir()
	conferir(inventario.quantidade("mandioca") == 0, "a mandioca entrou numa mochila sem espaço")
	conferir(terrenos.no_paiol == {"mandioca": 2}, "o que não coube devia esperar no paiol, e o paiol tem %s" % str(terrenos.no_paiol))
	conferir(povoado.dias_de("cosme", "roca") == 1, "a mochila cheia não pode impedir o dia de contar")

	# A TELA pode pedir antes da próxima manhã: com espaço, o paiol entra.
	terrenos.esvaziar_o_paiol()
	conferir(terrenos.no_paiol == {"mandioca": 2}, "o paiol esvaziou numa mochila sem espaço")
	inventario.espacos[7] = {}
	terrenos.esvaziar_o_paiol()
	conferir(terrenos.no_paiol.is_empty() and inventario.quantidade("mandioca") == 2, "abriu espaço e o paiol não entrou")

	# E na manhã seguinte, o que esperava entra junto com a colheita nova.
	_em_branco()
	_por_para_trabalhar({"cosme": "roca"})
	terrenos.no_paiol = {"mandioca": 3}
	relogio.dormir()
	conferir(inventario.quantidade("mandioca") == 5 and terrenos.no_paiol.is_empty(), "paiol 3 + colheita 2 devia dar 5 na mochila: %d" % inventario.quantidade("mandioca"))

	# Item que o jogo não tem mais não fica esperando para sempre (nem reclama).
	terrenos.no_paiol = {"item_que_nao_existe": 4}
	terrenos.esvaziar_o_paiol()
	conferir(terrenos.no_paiol.is_empty(), "o paiol guarda item que o jogo não tem mais")

	# E o save que traz um item assim o perde ao carregar, dizendo qual foi.
	var gravado := _como_no_disco()
	gravado["Terrenos"]["no_paiol"] = {"item_que_nao_existe": 4, "lenha": 3}
	salvamento.ultimo_relato = []
	conferir(salvamento.carregar(gravado), "o carregar recusou a partida")
	conferir(terrenos.no_paiol == {"lenha": 3}, "o paiol depois de carregar: %s" % str(terrenos.no_paiol))
	conferir("\n".join(salvamento.ultimo_relato).contains("item_que_nao_existe"),
		"o relato do carregar não diz que o item saiu do paiol: %s" % str(salvamento.ultimo_relato))


# --- 9. o save -------------------------------------------------------------------------

func _como_no_disco() -> Dictionary:
	var lido = salvamento.decodificar_dados(var_to_str(partida.instantaneo()))
	conferir(lido is Dictionary, "o instantâneo da partida não voltou do texto")
	return lido if lido is Dictionary else {}


func test_a_pericia_a_sobra_e_o_paiol_ficam_na_vaga() -> void:
	_por_para_trabalhar({"cosme": "roca", "zefa": "farinha"})
	povoado.pericia = {"cosme": {"roca": 33, "farinha": 4}, "zefa": {"farinha": 71}}
	povoado.sobra = {"mandioca": 0.36, "farinha": 0.7}
	terrenos.no_paiol = {"lenha": 3}
	var pericia: Dictionary = povoado.pericia.duplicate(true)
	var gravado := _como_no_disco()
	conferir((gravado.get("Povoado", {}) as Dictionary).get("pericia", {}) == pericia, "o save não leva a perícia: %s" % str(gravado.get("Povoado", "sem seção")))
	conferir(((gravado.get("Povoado", {}) as Dictionary).get("sobra", {}) as Dictionary).has("mandioca"), "o save não leva a sobra: %s" % str(gravado.get("Povoado", "sem seção")))
	conferir((gravado.get("Terrenos", {}) as Dictionary).get("no_paiol", {}) == {"lenha": 3}, "o save não leva o paiol: %s" % str(gravado.get("Terrenos", "sem seção")))

	# VOLTA: some tudo e o carregar devolve.
	povoado.pericia.clear()
	povoado.sobra.clear()
	terrenos.no_paiol.clear()
	terrenos.trabalho.clear()
	conferir(salvamento.carregar(gravado), "o carregar recusou a partida")
	conferir(povoado.pericia == pericia, "a perícia não voltou do save: %s" % str(povoado.pericia))
	conferir(is_equal_approx(float(povoado.sobra.get("mandioca", -1.0)), 0.36) and is_equal_approx(float(povoado.sobra.get("farinha", -1.0)), 0.7),
		"a sobra fracionária não voltou do save: %s" % str(povoado.sobra))
	conferir(terrenos.no_paiol == {"lenha": 3}, "o paiol não voltou do save: %s" % str(terrenos.no_paiol))
	conferir(povoado.grau_de_pericia("zefa", "farinha") == 3 and povoado.dias_de("cosme", "roca") == 33, "a perícia voltou mas não vale")
	# A sobra que voltou continua a conta de ontem. Cosme aprendiz na roça: 2 + 0,36 = 2,36, sai 2.
	# A Zefa mestra na farinha: 2 x 0,5 (idosa) x 2,4 = 2,4, e com os 0,7 que sobraram sai 3, e não 2.
	povoado.pericia["cosme"]["roca"] = 0
	var amanha: Dictionary = povoado.producao_do_dia()
	conferir(amanha == {"mandioca": 2, "farinha": 3}, "a sobra guardada devia entrar na conta de amanhã (2 de mandioca e 3 de farinha): %s" % str(amanha))
	# O que veio do arquivo é do sistema: mexer nele não mexe no arquivo lido.
	povoado.pericia["cosme"]["roca"] = 999
	conferir(gravado["Povoado"]["pericia"]["cosme"]["roca"] == 33, "o carregar compartilhou o dicionário do arquivo")

	# VAGA NOVA volta à fábrica: ninguém com perícia, sem sobra, sem paiol.
	partida.comecar(2)
	conferir(povoado.pericia.is_empty() and povoado.sobra.is_empty() and terrenos.no_paiol.is_empty(),
		"a vaga nova herdou o povoado: %s %s %s" % [str(povoado.pericia), str(povoado.sobra), str(terrenos.no_paiol)])
	conferir(salvamento.carregar(gravado) and povoado.pericia == pericia, "voltar à vaga gravada perdeu a perícia")

	# SAVE DE ANTES DO POVOADO: sem a seção, os moradores voltam aprendizes, sem inventar dia nenhum.
	var antigo := gravado.duplicate(true)
	antigo.erase("Povoado")
	partida.comecar(2)
	conferir(salvamento.carregar(antigo) and povoado.pericia.is_empty() and povoado.sobra.is_empty(), "o save sem a seção devia deixar todos aprendizes")

	# O ARQUIVO DE VERDADE, só com o perfil descartável (nunca por cima do save de quem joga).
	if Estado.perfil_descartavel():
		povoado.pericia = pericia.duplicate(true)
		povoado.sobra = {"mandioca": 0.36}
		conferir(salvamento.salvar(3), "o save de verdade falhou")
		var do_disco: Dictionary = salvamento.ler(3)
		povoado.pericia.clear()
		povoado.sobra.clear()
		conferir(salvamento.carregar(do_disco) and povoado.pericia == pericia and is_equal_approx(float(povoado.sobra.get("mandioca", -1.0)), 0.36),
			"o arquivo gravado não devolveu a perícia e a sobra")


func test_o_save_cobre_tudo_que_o_povoado_e_o_terrenos_guardam() -> void:
	for nome in ["Povoado", "Terrenos"]:
		var sistema: Node = root.get_node("/root/" + nome)
		var guardados: Array = salvamento.O_QUE_GUARDAR.get(nome, [])
		var campos := 0
		for p in sistema.get_property_list():
			if not (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			var campo: String = p["name"]
			if campo.begins_with("_"):
				continue
			campos += 1
			conferir(guardados.has(campo), "%s.%s não está na tabela do Salvamento: ao recarregar ela volta ao começo" % [nome, campo])
		conferir(campos > 0, "não achei nenhum campo público em %s: a varredura não está pegando" % nome)
		for campo in guardados:
			conferir(campo in sistema, "a tabela do Salvamento guarda %s.%s, que não existe: o save escreveria nulo" % [nome, campo])
