extends "res://tests/unidade/base.gd"
## #18: bônus chegam aos consumidores nativos, sem carregar o vale inteiro.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste consumidores_dos_talentos
class Braco extends Node3D:
	func gastar_vigor(_quanto: float) -> bool:
		return true
	func vigor_atual() -> float:
		return 100.0
class Mata extends Node3D:
	var pode_cair := true
	func cortar_arvore(_ponto: Vector3, _toco: bool, _direcao: Vector3) -> bool:
		return pode_cair


func script_de(nome: String) -> GDScript:
	if "--antes" not in OS.get_cmdline_user_args():
		return load("res://scripts/prototipo_3d/" + nome + ".gd")
	# Cópias obtidas com git show c022e0f, sem substituir arquivos vivos.
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string("res://tools/temp/consumidores18-antes/" + nome + ".gd.txt")
	conferir(script.reload() == OK, "referência anterior não compilou: " + nome)
	return script


func test_consumidores_dos_talentos() -> void:
	var talentos = root.get_node("Talentos")
	var fe = root.get_node("Fe")
	var energia = root.get_node("Energia")
	var inventario = root.get_node("Inventario")
	var jogador = script_de("player_controller").new()
	talentos.destravados.clear()
	fe.ativa = ""
	energia.repor(10000.0)
	var base: float = jogador.call("multiplicador_do_passo") if jogador.has_method("multiplicador_do_passo") else 1.0
	talentos.destravados.append("pernas_de_andarilho")
	if "--sem-passo" in OS.get_cmdline_user_args():
		talentos.destravados.clear()
	conferir(jogador.has_method("multiplicador_do_passo"), "o controlador não tem consumidor do passo")
	if jogador.has_method("multiplicador_do_passo"):
		conferir(is_equal_approx(jogador.multiplicador_do_passo(), base * 1.08), "pernas de andarilho não muda passo em 8%")
	fe.ativa = "catolica"
	fe._estados["catolica"] = {"total": 120.0, "teto": 10, "destravados": ["romaria"]}
	fe._espelhar()
	if jogador.has_method("multiplicador_do_passo"):
		conferir(is_equal_approx(jogador.multiplicador_do_passo(), base * 1.14), "romaria e talento não somam no passo")
	energia.atual = 1.0
	if jogador.has_method("multiplicador_do_passo"):
		conferir(jogador.multiplicador_do_passo() < base, "bônus apagou cansaço")
	jogador.free()
	energia.repor(10000.0)
	fe.ativa = "caboclo"
	fe._estados["caboclo"] = {"total": 120.0, "teto": 10, "destravados": ["machado_de_antigo"]}
	fe._espelhar()
	var braco := Braco.new()
	if "--sem-lenha" in OS.get_cmdline_user_args():
		fe.ativa = ""
	pendurar(braco)
	var mata := Mata.new()
	var arvores = script_de("arvores_info").new()
	arvores._world = mata
	arvores._jogador = braco
	arvores._balao_vida = PanelContainer.new()
	arvores._madeiras = {"branca": {"rende": "lenha", "quantidade": 2, "golpes": 1}}
	arvores._especies = {"teste": {"madeira": "branca"}}
	for produto in ["lenha", "madeira_de_coqueiro"]:
		inventario.espacos.fill({})
		arvores._madeiras["branca"]["rende"] = produto
		arvores._cortaveis.clear()
		arvores._cortaveis.append({"pos": Vector3.ONE, "especie": "teste", "golpes": 0, "cortado": false})
		arvores._em_golpe = 0
		arvores._golpes_restantes_na_acao = 1
		arvores._ao_golpe_concluido()
		conferir(inventario.quantidade(produto) == (3 if produto == "lenha" else 2), "bônus de lenha não respeitou o produto: " + produto)
	# A animação chegar ao impacto não basta se o cenário recusa o corte.
	mata.pode_cair = false
	inventario.espacos.fill({})
	arvores._cortaveis.clear()
	arvores._cortaveis.append({"pos": Vector3.ONE, "especie": "teste", "golpes": 0, "cortado": false})
	arvores._em_golpe = 0
	arvores._golpes_restantes_na_acao = 1
	arvores._ao_golpe_concluido()
	conferir(inventario.quantidade("madeira_de_coqueiro") == 0, "corte recusado deu madeira")
	arvores._balao_vida.free()
	arvores.free()
	mata.free()
	var achados = script_de("achados_vale").new()
	achados._player = braco
	achados.no_chao.append({"tipo": "cordel", "ponto": Vector3(3, 0, 0)})
	talentos.destravados.clear()
	fe.ativa = ""
	conferir(achados.mais_perto() == null, "cordel a três metros alcançado sem talento")
	talentos.destravados.append("olho_de_colecionador")
	if "--sem-faro" in OS.get_cmdline_user_args():
		talentos.destravados.clear()
	conferir(achados.mais_perto() != null, "faro não permite perceber/interagir com cordel mais longe")
	achados.no_chao[0]["tipo"] = "carta"
	conferir(achados.mais_perto() == null, "faro de cordel aumentou alcance de carta")
	achados.no_chao.append({"tipo": "cordel", "ponto": Vector3(3, 0, 0)})
	achados.no_chao.append({"tipo": "carta", "ponto": Vector3(1, 0, 0)})
	conferir(str(achados.mais_perto().tipo) == "carta", "cordel distante roubou foco de achado mais perto")
	achados.free()
	braco.queue_free()
	await process_frame
