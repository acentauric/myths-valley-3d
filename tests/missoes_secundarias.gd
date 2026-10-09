extends SceneTree
## AS MISSÕES SECUNDÁRIAS DOS MORADORES (docs/projeto/MISSOES_SECUNDARIAS.md).
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/missoes_secundarias.gd
##
## O vale tem 22 moradores e só oito tinham fila de missão. Os favores de cada um
## (data/favores_dos_moradores.json, fase 1) entram pendurados pela tabela, trancados
## pela afinidade, e fechar um é o favor da afinidade. O que este portão pergunta:
##
##   1. TODO MORADOR DO ARRAIAL TEM UMA FILA: cada morador de npcs_3d.json (menos o
##      mestre do saveiro, que só vem no dia dele) é dono de ao menos uma fila viva.
##   2. AS DA TABELA ESTÃO PENDURADAS no dono certo, com `depois_de`, e o aviso da
##      trancada nos três idiomas, sem copiar o português.
##   3. TRANCADA ATÉ CONHECER: com a chegada feita e a afinidade em zero, o E no dono
##      não abre a fila e ele NÃO avisa — conversa como sempre (o aviso no primeiro
##      encontro tomava a fala do morador e a conversa que sobe a afinidade); com meio
##      caminho andado (5 pontos) o aviso dele existe; no grau da tabela, o E a abre.
##   4. UM FAVOR DO COMEÇO AO FIM (a rendeira): aberta a fila, com o lampião na
##      mochila, o E nela entrega, a recompensa é paga, a fila acaba e a afinidade
##      sobe o favor (Afinidade.POR_FAVOR).
##   5. SEM FAVOR NÃO HÁ SALTO: antes de fechar, a afinidade só tinha o que o portão
##      pôs — o favor é dado uma vez, no fim.
##   7. A HORA DO PASSO (fase 3): a roda na praia é de noite — na areia às 15 h, o
##      lugar não se risca; às 21 h, risca.
##   6. OS ARCOS SEGUEM O FAVOR (fase 2): a toalha do tio só abre com o favor da rendeira
##      feito e ela "Gente boa" (grau 2); a pedra do altar fica trancada enquanto o favor
##      do sacristão não foi feito. Aberta, a toalha vem na janela (entrega) e a oferenda
##      na mesa da casa de taipa fecha a fila. E os papéis dos arcos se leem: estão no
##      catálogo como documentos com texto em data/documentos.json.

const TABELA := "res://data/favores_dos_moradores.json"
const SO_NO_DIA_DO_SAVEIRO := ["quirino"]
const SEGUNDOS_PARA_ABRIR := 20.0
const SEGUNDOS_POR_PASSO := 30.0

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("SECUNDARIAS_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "o vale não carregou")
	await _frames(4)
	await _mundo_pronto()
	await _frames(4)
	var vale = current_scene
	# O ACEITE É AUTOMÁTICO AQUI (08/10): este portão abre filas pelo E e segue; a tela de aceite
	# pausaria o vale no meio da medida (a tela tem portão próprio, tests/missao_a_vista.gd).
	if vale.get("aceite") != null:
		vale.aceite.automatico = true
	var jogador = vale.player
	var afinidade = root.get_node("/root/Afinidade")
	var inv = root.get_node("/root/Inventario")
	var tecla = vale.get("tecla_dos_moradores")
	var tabela: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TABELA))
	var filas: Array = tabela.get("filas", [])
	_conferir(filas.size() >= 14, "a tabela tem %d favor(es), e são ao menos 14" % filas.size())

	# --- 1. TODO MORADOR DO ARRAIAL TEM UMA FILA ----------------------------------------
	var npcs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs_3d.json"))
	var donos := {}
	for chave in vale._cadeias:
		var cadeia = vale._cadeias[chave]
		if cadeia.dono != null and "dados" in cadeia.dono:
			donos[str(cadeia.dono.dados.get("id", ""))] = true
	var sem_fila: Array[String] = []
	for morador in npcs.get("moradores", []):
		var id := str((morador as Dictionary).get("id", ""))
		if id in SO_NO_DIA_DO_SAVEIRO or donos.has(id):
			continue
		sem_fila.append(id)
	_conferir(sem_fila.is_empty(), "morador(es) do arraial sem fila de missão: %s" % str(sem_fila))
	print("  donos de fila: %d de %d moradores" % [donos.size(), (npcs.get("moradores", []) as Array).size()])

	# --- 2. AS DA TABELA ESTÃO PENDURADAS -----------------------------------------------
	for entrada in filas:
		var chave := str(entrada.get("chave", ""))
		var dono_id := str(entrada.get("dono", ""))
		var cadeia = vale._cadeias.get(chave)
		_conferir(cadeia != null, "a fila '%s' da tabela não está pendurada no vale" % chave)
		if cadeia == null:
			continue
		_conferir(str(cadeia.dono.dados.get("id", "")) == dono_id, "a fila '%s' está pendurada em '%s', e a tabela diz '%s'" % [chave, str(cadeia.dono.dados.get("id", "")), dono_id])
		_conferir(cadeia.depois_de.is_valid(), "a fila '%s' não tem depois_de: abriria sem afinidade" % chave)
		_conferir(not bool(cadeia.principal), "a fila '%s' é de enredo, e favor de vizinho não é" % chave)
		var dado: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(entrada.get("arquivo", ""))))
		for campo in ["trancada", "trancada_en", "trancada_es"]:
			_conferir(str(dado.get(campo, "")) != "", "a fila '%s' não tem '%s'" % [chave, campo])
		_conferir(str(dado.get("trancada_en", "")) != str(dado.get("trancada", "")) and str(dado.get("trancada_es", "")) != str(dado.get("trancada", "")),
			"a fila '%s' tem o aviso da trancada copiado do português" % chave)
		_conferir((dado.get("passos", []) as Array).size() >= 1, "a fila '%s' não tem passo" % chave)

	# --- 3. TRANCADA ATÉ CONHECER (a rendeira) ------------------------------------------
	var da_rendeira = vale._cadeias.get("rendeira_favor")
	var rendeira: Node3D = vale._achar_morador("rendeira")
	_conferir(da_rendeira != null and rendeira != null, "não achei a fila da rendeira ou a rendeira")
	if da_rendeira == null or rendeira == null:
		_fechar()
		return
	# A chegada do Pedro, feita na mão, como o `missoes_elos` faz.
	var guia = vale.pedro._cadeia
	guia.iniciado = true
	guia.missao = guia.passos.size()
	guia.espera = 0.0
	guia.despedida_feita = true
	afinidade.pontos["rendeira"] = 0
	_conferir(afinidade.grau("rendeira") == 0, "zerada, a afinidade da rendeira não é 'Desconhecido' (grau %d)" % afinidade.grau("rendeira"))
	_conferir(da_rendeira.esta_trancada(), "sem afinidade, a fila da rendeira não está trancada")
	_conferir(str(da_rendeira.o_que_o_e_faz(rendeira)) == "", "sem afinidade, o E na rendeira já faz '%s'" % str(da_rendeira.o_que_o_e_faz(rendeira)))
	_conferir(str(da_rendeira.dica_da_trancada()) == "", "sem afinidade nenhuma a rendeira já avisa da fila trancada ('%s'): o aviso tomaria a conversa do primeiro encontro" % str(da_rendeira.dica_da_trancada()))
	_conferir(not bool(da_rendeira.aviso_repete), "o aviso da fila da rendeira se repete a cada E: a conversa dela sumiria")
	afinidade.somar("rendeira", vale.AFINIDADE_PARA_O_AVISO)
	_conferir(str(da_rendeira.dica_da_trancada()).contains("bilros"), "a meio caminho de conhecida, o aviso da trancada da rendeira não é o dela: '%s'" % str(da_rendeira.dica_da_trancada()))
	afinidade.pontos["rendeira"] = 0
	jogador.teleportar(rendeira.global_position + Vector3(1.2, 0.0, 1.0), 0.0)
	await _corpo_de_volta(jogador)
	await _usar(tecla, rendeira)
	await _frames(3)
	_conferir(not da_rendeira.iniciado, "sem afinidade, o E na rendeira abriu a fila dela")
	# Conhecido de vista: o grau 1 da tabela.
	afinidade.somar("rendeira", 10)
	var grau_da_tabela := 1
	for entrada in filas:
		if str(entrada.get("chave", "")) == "rendeira_favor":
			grau_da_tabela = int(entrada.get("grau", 1))
	_conferir(afinidade.grau("rendeira") >= grau_da_tabela, "dez pontos não fizeram a rendeira 'Conhecida de vista' (grau %d)" % afinidade.grau("rendeira"))
	_conferir(not da_rendeira.esta_trancada(), "conhecida, a fila da rendeira continua trancada")
	_conferir(str(da_rendeira.o_que_o_e_faz(rendeira)) == "abrir", "conhecida, o E na rendeira faz '%s', e devia abrir a fila" % str(da_rendeira.o_que_o_e_faz(rendeira)))

	# --- 4. UM FAVOR DO COMEÇO AO FIM ---------------------------------------------------
	var pontos_antes: int = afinidade.de("rendeira")
	await _usar(tecla, rendeira)
	var abriu := await _ate(func() -> bool: return bool(da_rendeira.iniciado), SEGUNDOS_PARA_ABRIR)
	_conferir(abriu, "com o E na rendeira conhecida, a fila dela não abriu")
	if not abriu:
		_fechar()
		return
	await _ate(func() -> bool: return da_rendeira.espera <= 0.0, SEGUNDOS_PARA_ABRIR)
	await _frames(2)
	# SEM O LAMPIÃO O E É CONVERSA, não entrega (a regra da Candinha: chegar sem a conta não
	# fecha); com ele na mochila, o E passa a ser a entrega.
	_conferir(str(da_rendeira.o_que_o_e_faz(rendeira)) != "entregar", "sem lampião, o E na rendeira já oferece a entrega")
	await _usar(tecla, rendeira)
	await _frames(3)
	_conferir(not da_rendeira.acabou(), "sem o lampião, a entrega fechou")
	inv.adicionar("lampiao", 1)
	await _frames(2)
	_conferir(str(da_rendeira.o_que_o_e_faz(rendeira)) == "entregar", "com o lampião na mochila, o E na rendeira faz '%s', e devia entregar" % str(da_rendeira.o_que_o_e_faz(rendeira)))
	await _usar(tecla, rendeira)
	var fechou := await _ate(func() -> bool: return bool(da_rendeira.acabou()), SEGUNDOS_POR_PASSO)
	_conferir(fechou, "com o lampião na mochila, o E na rendeira não fechou a entrega")
	_conferir(inv.quantidade("lampiao") == 0, "a entrega não tirou o lampião da mochila (%d)" % inv.quantidade("lampiao"))

	# --- 5. O FAVOR SOBE A AFINIDADE, UMA VEZ -------------------------------------------
	var por_favor: int = afinidade.POR_FAVOR
	var pontos_depois: int = afinidade.de("rendeira")
	_conferir(pontos_depois >= pontos_antes + por_favor, "fechar o favor da rendeira subiu a afinidade de %d para %d, e o favor vale %d" % [pontos_antes, pontos_depois, por_favor])
	_conferir(afinidade.grau("rendeira") >= 2, "com o favor feito a rendeira não virou 'Gente boa' (grau %d)" % afinidade.grau("rendeira"))
	await _frames(3)
	_conferir(afinidade.de("rendeira") == pontos_depois, "a afinidade continuou subindo depois do favor (%d → %d)" % [pontos_depois, afinidade.de("rendeira")])
	print("  rendeira: %d → %d pontos (favor %d), grau %d" % [pontos_antes, pontos_depois, por_favor, afinidade.grau("rendeira")])

	# --- 6. OS ARCOS SEGUEM O FAVOR ------------------------------------------------------
	var da_pedra = vale._cadeias.get("sacristao_pedra")
	_conferir(da_pedra != null, "o arco da pedra do altar não está pendurado")
	if da_pedra != null:
		afinidade.somar("sacristao", 40)
		_conferir(da_pedra.esta_trancada(), "sem o favor da garapa feito, o arco da pedra do altar já abre")
	var da_toalha = vale._cadeias.get("rendeira_toalha")
	_conferir(da_toalha != null, "o arco da toalha não está pendurado")
	if da_toalha != null:
		_conferir(not da_toalha.esta_trancada(), "com o favor feito e a rendeira 'Gente boa', o arco da toalha continua trancado")
		var catalogo = load("res://scripts/compartilhado/catalogo.gd")  # classe estática, não autoload
		_conferir(catalogo.existe("toalha_de_renda") and catalogo.existe("papel_dos_nomes") and catalogo.existe("tabua_lavrada"),
			"faltam itens dos arcos no catálogo")
		_conferir(catalogo.tipo("papel_dos_nomes") == "documento" and catalogo.tipo("tabua_lavrada") == "documento", "os papéis dos arcos não são documentos: não se leem")
		var documentos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/documentos.json"))
		_conferir(documentos.has("papel_dos_nomes") and documentos.has("tabua_lavrada"), "os papéis dos arcos não têm texto em data/documentos.json")
		jogador.teleportar(rendeira.global_position + Vector3(1.2, 0.0, 1.0), 0.0)
		await _frames(3)
		await _usar(tecla, rendeira)
		var abriu_a_toalha := await _ate(func() -> bool: return bool(da_toalha.iniciado), SEGUNDOS_PARA_ABRIR)
		_conferir(abriu_a_toalha, "com o E na rendeira, o arco da toalha não abriu")
		if abriu_a_toalha:
			var com_a_toalha := await _ate(func() -> bool: return inv.tem("toalha_de_renda"), SEGUNDOS_PARA_ABRIR)
			_conferir(com_a_toalha, "a rendeira não entregou a toalha ao abrir o arco")
			await _ate(func() -> bool: return da_toalha.missao >= 1, SEGUNDOS_POR_PASSO)
			_conferir(da_toalha.missao >= 1, "o passo da janela não fechou ao receber a toalha (missao %d)" % da_toalha.missao)
			var lugares = root.get_node("/root/Lugares")
			var mesa: Vector3 = lugares.ponto("casa_de_taipa")
			_conferir(mesa.is_finite(), "a casa de taipa não resolve no Lugares")
			if mesa.is_finite():
				jogador.teleportar(mesa + Vector3(1.0, 0.0, 1.0), 0.0)
				var ofereceu := await _ate(func() -> bool: return bool(da_toalha.acabou()), SEGUNDOS_POR_PASSO)
				_conferir(ofereceu, "na casa de taipa com a toalha na mochila, a oferenda da mesa não fechou o arco")
				_conferir(not inv.tem("toalha_de_renda"), "a toalha ficou na mochila depois de posta na mesa")

	# --- 7. A HORA DO PASSO (a roda na praia) --------------------------------------------
	var da_roda = vale._cadeias.get("menina_roda")
	_conferir(da_roda != null, "a roda na praia não está pendurada")
	if da_roda != null:
		var dia = root.get_node("/root/Dia")
		var hora_guardada: float = dia.hora
		var passo_da_praia := -1
		for i in da_roda.passos.size():
			if str((da_roda.passos[i] as Dictionary).get("id", "")) == "roda_na_praia":
				passo_da_praia = i
		_conferir(passo_da_praia >= 0, "a roda não tem o passo da praia")
		if passo_da_praia >= 0:
			var meta: Dictionary = (da_roda.passos[passo_da_praia] as Dictionary).get("meta", {})
			_conferir((meta.get("horas", []) as Array).size() == 2, "o passo da praia não tem a janela de horas")
			da_roda.iniciado = true
			da_roda.missao = passo_da_praia
			da_roda.espera = 0.0
			var lugares_do_vale = root.get_node("/root/Lugares")
			var areia: Vector3 = lugares_do_vale.ponto("areia")
			dia.hora = 15.0
			jogador.teleportar(areia + Vector3(0.5, 0.0, 0.5), 0.0)
			await _frames(6)
			_conferir(da_roda.falta_a_meta(da_roda.passos[passo_da_praia]), "às 15 h, na areia, a roda da noite riscou o lugar")
			dia.hora = 21.0
			jogador.teleportar(areia + Vector3(0.5, 0.0, -0.5), 0.0)
			var riscou := await _ate(func() -> bool: return not da_roda.falta_a_meta(da_roda.passos[passo_da_praia]), 6.0)
			_conferir(riscou, "às 21 h, na areia, a roda da noite não riscou o lugar")
			dia.hora = hora_guardada
	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("SECUNDARIAS_OK: todo morador do arraial tem fila; os favores da tabela estão no dono certo, trancados até a afinidade, com o aviso nos três idiomas; conhecida, a rendeira abre a fila no E, a entrega do lampião fecha e paga, e o favor sobe a afinidade uma vez")
	else:
		print("missoes_secundarias: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


## O corpo de volta depois de um teleporte ao pé de uma casa: o cômodo se monta e segura o
## jogador enquanto isso (`interiores._montar_de_perto`).
func _corpo_de_volta(jogador) -> void:
	var limite := Time.get_ticks_msec() + 4000
	while not jogador.is_physics_processing() and Time.get_ticks_msec() < limite:
		await process_frame
	await _frames(3)


## O E no morador quando a fala dele acaba: nova conversa espera o balão de quem ainda
## fala (#121, `TeclaDosMoradores.usar`).
func _usar(tecla: Node, morador: Node3D) -> void:
	await _ate(func() -> bool: return not morador.falando_agora(), 30.0)
	tecla.usar(morador)


func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if condicao.call():
			return true
		await process_frame
	return condicao.call()


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
