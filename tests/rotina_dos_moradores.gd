extends "res://tests/suite/caso.gd"
## Confere A ROTINA DOS MORADORES NOVOS: quem são, onde moram, o que fazem a cada hora.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste rotina_dos_moradores
##     ... -- --falsificar-rotina        (o portão TEM de reprovar: ver `_falsificar`)
##
## "Novos NPCs sem diálogos mas com jornadas diárias, com novas casas para eles, cada NPC
## vinculado a uma casa; também padre, mercador, guarda e outros." E: "um varal novo para
## cada casa, posicionado inteligentemente". Sete perguntas:
##
##   1. O ELENCO: os catorze estão no vale, com nome, ofício nos três idiomas, falantes (até
##      06/10/2026 eram mudos e sem falas: as falas deles são do portão `falas_dos_moradores`)
##      e — desde a #85, na teia social — com fé; cada um tem casa, e a casa foi erguida
##      (nenhum chama "Casa do arraial").
##   2. A AGENDA RESOLVE: todo lugar dela existe no cenário (inclusive "Casa/Varal"), e a
##      malha de navegação leva até 1,5 u de cada posto.
##   3. A HORA MANDA: de meia em meia hora das 24, cada um está no posto da entrada de
##      agora, e quem se recolhe está invisível e sem colisão.
##   4. O SALTO DE HORA: o relógio pula seis horas com o jogador longe e, passados os
##      segundos do salto do caminho longo (#84: FORA_DA_VISTA_POR), o morador já está
##      no lugar da hora nova (a lavadeira, que leva uma tarde a pé até o varal).
##   5. O TRABALHO: parado no posto, o corpo toca o clipe do ofício e leva o que a agenda
##      manda (a vassoura do sacristão).
##   6. O MUDO NÃO FALA: nem balão, nem aviso no HUD, nem toma a palavra dos vizinhos — e o
##      de sempre, o Benedito, ainda fala. Hoje ninguém no vale é mudo, e o MECANISMO segue
##      coberto por um mudo sintético: o portão cala o pescador na hora (`dados["mudo"]`).
##   7. A CASA É DELES, E O VARAL TAMBÉM: o Pedro e a Zefa ficam nas casas deles; toda casa
##      tem varal fora da faixa da porta, e as casas com galinha ou porco têm galinheiro e
##      chiqueiro no quintal.

const NOVOS := ["padre", "sacristao", "beata", "mercador", "guarda", "pescador", "marisqueira", "lavadeira",
	"rendeira", "quituteira", "carpinteiro", "menino", "menina", "mestre_saveiro"]
const CASAS_DO_PEDRO_E_DA_ZEFA := {"pedro": "Casa do arraial 8", "zefa": "Casa do arraial 6"}
const GALINHAS := ["galinha", "galo", "pintinho", "galinha_dangola", "peru"]

var falhas := 0
var falsificar := ""


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("ROTINA_DOS_MORADORES_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	for argumento in OS.get_cmdline_user_args():
		if argumento == "--falsificar-rotina":
			falsificar = "tudo"
		elif argumento.begins_with("--falsificar="):
			falsificar = argumento.trim_prefix("--falsificar=")
	root.get_node("/root/Estilo").modo = "tripo"
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	var vale = current_scene
	# A rotina completa exige o elenco inteiro, além da apresentação inicial
	# conferida separadamente em apresentacao_do_povoado.
	while vale.apresentacao_do_povoado == null:
		await process_frame
	vale.apresentacao_do_povoado.liberar_todos()
	var mundo = vale.world
	var jogador = vale.player
	var dia = root.get_node("/root/Dia")
	var afinidade = root.get_node("/root/Afinidade")
	dia.pausado = true
	var por_id := {}
	for morador in vale.moradores:
		por_id[str(morador.dados.get("id", ""))] = morador

	# --- 1. O ELENCO --------------------------------------------------------------
	var nomes := {}
	for id in NOVOS:
		var m = por_id.get(id)
		_conferir(m != null, "o morador '%s' não está no vale" % id)
		if m == null:
			continue
		var d: Dictionary = m.dados
		var nome := str(d.get("nome", ""))
		_conferir(nome != "" and not nomes.has(nome), "'%s' não tem nome próprio, ou repete o de outro" % id)
		nomes[nome] = true
		for campo in ["oficio", "oficio_en", "oficio_es"]:
			_conferir(str(d.get(campo, "")) != "", "'%s' não tem o campo %s" % [id, campo])
		_conferir(not bool(d.get("mudo", false)), "'%s' ainda é mudo, e agora tem fala (falas_dos_moradores.gd)" % id)
		_conferir(not (d.get("falas", []) as Array).is_empty() and not (d.get("saudacoes", []) as Array).is_empty(),
			"'%s' não tem as falas e as saudações que o tiraram do mudo" % id)
		# Desde a #85 (06/10) os catorze estão na teia social, com a fé do `aldeoes.json`.
		_conferir(afinidade.fe_de(id) != "", "'%s' não tem fé no aldeoes.json" % id)
		var casa := str(d.get("casa", ""))
		_conferir(casa != "" and not casa.begins_with("Casa do arraial 6") and casa != "Casa do arraial 8",
			"'%s' mora na casa '%s', que é do Pedro ou da Zefa, ou não tem casa" % [id, casa])
		_conferir(mundo.ancoras.has(casa) and mundo.ancoras.has(casa + "Frente"), "a casa '%s' de '%s' não existe no vale" % [casa, id])
		_conferir(mundo.construcoes.has(casa) or casa in ["Venda do Bar"], "a casa '%s' de '%s' não foi erguida" % [casa, id])
		_conferir(not (d.get("agenda", []) as Array).is_empty(), "'%s' não tem agenda" % id)
		# Nenhum cativo e nada de arma: o guarda leva, no máximo, o candeeiro.
		for entrada in d.get("agenda", []):
			_conferir(not str(entrada.get("mao", "")).contains("arma") and not str(entrada.get("mao", "")).contains("chicote"),
				"'%s' leva arma na agenda" % id)
	_conferir(por_id.size() >= 8 + NOVOS.size(), "o vale devia ter ao menos %d moradores, e tem %d" % [8 + NOVOS.size(), por_id.size()])
	for casa_do in CASAS_DO_PEDRO_E_DA_ZEFA:
		_conferir(str(mundo.casas_dos_moradores.get(casa_do, "")) != "", "o vale não escolheu a casa do %s" % casa_do)
	var vistas := {}
	for quem in mundo.casas_dos_moradores:
		vistas[quem] = mundo.casas_dos_moradores[quem]
	_conferir(vistas.get("pedro", "") != vistas.get("zefa", ""), "o Pedro e a Zefa ficaram na mesma casa")
	if not (por_id.has("lavadeira") and por_id.has("pescador") and por_id.has("benedito")):
		_fechar()
		return

	# O MUDO SINTÉTICO: ninguém no vale é mudo desde que os catorze ganharam fala, e o mecanismo
	# (`npc._eh_mudo`: acena, sem balão, sem aviso, sem tomar a palavra) continua valendo para
	# quem vier a ter `"mudo": true`. O pescador é calado aqui, ANTES da falsificação.
	por_id["pescador"].dados["mudo"] = true

	# FALSIFICAÇÃO: a lavadeira ganha um lugar que o cenário não tem, o pescador volta a falar
	# e o varal do guarda vai para a porta. O portão TEM de reprovar nos três.
	_falsificar(mundo, por_id)

	# --- 2. A AGENDA RESOLVE, E A MALHA CHEGA --------------------------------------
	var navegacao = vale.get("navegacao")
	var pronta: bool = navegacao != null and await _ate(func() -> bool: return navegacao.esta_pronta(), 60.0)
	_conferir(pronta, "a malha de navegação não ficou pronta em 60 s")
	var praca: Vector3 = mundo.ground_position(mundo.ancoras["Praça"], 0.0)
	var postos := 0
	for id in NOVOS:
		var m = por_id.get(id)
		if m == null:
			continue
		for i in m._agenda.size():
			var entrada: Dictionary = m._agenda[i]
			var lugar := str(entrada.get("lugar", ""))
			var real := lugar
			if lugar == "Casa" or lugar.begins_with("Casa/"):
				real = str(m.dados.get("casa", "")) + lugar.substr(4)
			_conferir(mundo.ancoras.has(real), "'%s': o lugar '%s' (%s) da agenda não existe no cenário" % [id, lugar, real])
			_conferir(ACOES_VALIDAS.has(str(entrada.get("acao", ""))) or str(entrada.get("acao", "")) == "",
				"'%s': a ação '%s' não existe" % [id, entrada.get("acao", "")])
			var alvo: Vector3 = m._lugar_da_entrada(i)
			_conferir(alvo != Vector3.ZERO and alvo.is_finite(), "'%s': o posto %d da agenda não tem posição" % [id, i])
			if pronta and alvo != Vector3.ZERO:
				var caminho: PackedVector3Array = navegacao.caminho(praca if i == 0 else m._lugar_da_entrada(i - 1), alvo)
				var chega := caminho.size() > 0 and Vector2(caminho[caminho.size() - 1].x - alvo.x, caminho[caminho.size() - 1].z - alvo.z).length() <= 1.5
				_conferir(chega, "'%s': a malha não leva até 1,5 u do posto %d da agenda ('%s', %s)" % [id, i, lugar, str(alvo)])
			postos += 1

	# --- 3. A HORA MANDA ----------------------------------------------------------
	# O jogador longe de todos: ninguém o vê, e a economia é a de quem está longe.
	jogador.global_position = mundo.ground_position(Vector3(-60.0, 0.0, 150.0), 1.0)
	var checados := 0
	for passo in 48:
		var hora := float(passo) * 0.5
		dia.definir_hora(hora)
		for id in NOVOS:
			var m = por_id.get(id)
			if m == null:
				continue
			m.ir_ao_posto_agora()
			var n: int = m._agenda.size()
			var atual := n - 1
			for i in n:
				if float(m._agenda[i]["de"]) <= hora:
					atual = i
			var indice: int = m._entrada
			_conferir(indice == atual, "às %.1f h '%s' está na entrada %d da agenda, e devia estar na %d" % [hora, id, indice, atual])
			var onde: Vector3 = m._lugar_da_entrada(indice)
			var longe := Vector2(m.global_position.x - onde.x, m.global_position.z - onde.z).length()
			_conferir(longe < 1.5, "às %.1f h '%s' está a %.1f u do posto da agenda" % [hora, id, longe])
			var deve_sumir: bool = str(m._agenda[indice].get("acao", "")) == "recolhido" and bool(m.dados.get("recolhe", false))
			_conferir(m.esta_recolhido() == deve_sumir, "às %.1f h '%s' %s" % [hora, id, "devia estar em casa" if deve_sumir else "devia estar na rua"])
			_conferir(m.visible != deve_sumir, "às %.1f h a visibilidade de '%s' não bate com estar em casa" % [hora, id])
			_conferir((m.collision_layer == 0) == deve_sumir, "às %.1f h a colisão de '%s' não bate com estar em casa" % [hora, id])
			checados += 1

	# --- 4. O SALTO DE HORA -------------------------------------------------------
	var lavadeira = por_id["lavadeira"]
	dia.definir_hora(9.0)
	lavadeira.ir_ao_posto_agora()
	await _passos(6)
	var antes: Vector3 = lavadeira.global_position
	# Com o jogador longe e fora da vista: o salto espera FORA_DA_VISTA_POR segundos
	# de física (#84) antes de pôr o morador no lugar, como em `caminho_longo`.
	jogador.teleportar(mundo.ground_position(mundo.ancoras["Gameleira"] + Vector3(0.0, 0.0, 6.5), 0.05), 0.0)
	dia.definir_hora(13.0)
	await _passos(int(float(lavadeira.FORA_DA_VISTA_POR) * 60.0) + 30)
	var varal: Vector3 = lavadeira._lugar_da_entrada(lavadeira._entrada)
	_conferir(str(lavadeira._agenda[lavadeira._entrada].get("acao", "")) == "estender", "às 13 h a lavadeira devia estar estendendo a roupa, e está em '%s'" % str(lavadeira._agenda[lavadeira._entrada].get("acao", "")))
	var distancia := Vector2(lavadeira.global_position.x - varal.x, lavadeira.global_position.z - varal.z).length()
	_conferir(distancia < 2.0, "o relógio pulou seis horas e a lavadeira ficou a %.1f u do varal (saiu de %s)" % [distancia, str(antes)])

	# --- 5. O TRABALHO ------------------------------------------------------------
	var sacristao = por_id["sacristao"]
	dia.definir_hora(5.6)
	sacristao.ir_ao_posto_agora()
	jogador.global_position = mundo.ground_position(sacristao.global_position + Vector3(6.0, 0.0, 0.0), 0.5)
	await _passos(30)
	var animador = sacristao.animador
	_conferir(animador != null and animador.has_method("trabalhando") and animador.trabalhando(), "o sacristão parado no posto devia estar tocando o clipe do ofício")
	_conferir(sacristao._levados.size() == 1, "o sacristão devia levar a vassoura na mão (leva %d coisas)" % sacristao._levados.size())

	# --- 6. O MUDO NÃO FALA ---------------------------------------------------------
	# Os catorze falam desde a #85: o mudo de controle é o pescador, calado lá no começo
	# (o MUDO SINTÉTICO, antes da falsificação, que o faz falar de novo).
	var pescador = por_id["pescador"]
	var benedito = por_id["benedito"]
	var avisos := [0]
	pescador.saudou.connect(func(_m, _t) -> void: avisos[0] += 1)
	dia.definir_hora(16.5)
	pescador.ir_ao_posto_agora()
	jogador.global_position = pescador.global_position + Vector3(1.0, 0.0, 0.0)
	await _passos(4)
	pescador.saudar()
	await _passos(2)
	_conferir(avisos[0] == 0, "o morador mudo emitiu o aviso do HUD")
	_conferir(not benedito.fala_perto_de(pescador.global_position), "o morador mudo tomou a palavra dos vizinhos")
	var falou := [0]
	benedito.saudou.connect(func(_m, _t) -> void: falou[0] += 1)
	jogador.global_position = benedito.global_position + Vector3(1.0, 0.0, 0.0)
	benedito.saudar()
	_conferir(falou[0] == 1, "o Benedito, que não é mudo, devia ter falado (controle do portão)")
	pescador.dados.erase("mudo")

	# --- 7. A CASA É DELES, E O VARAL TAMBÉM -------------------------------------------
	var com_varal := 0
	for nome in mundo._casas_autorais.keys():
		var chave := str(mundo._casas_autorais[nome].get("chave", ""))
		if not mundo._is_house_key(chave) or str(nome) in ["Casa de taipa", "Casa de farinha"]:
			continue
		var varal_da_casa: String = str(nome) + "/Varal"
		if not mundo.ancoras.has(varal_da_casa):
			_conferir(false, "a casa '%s' não tem varal" % nome)
			continue
		com_varal += 1
		var base: Vector3 = mundo.ancoras[nome]
		var frente: Vector3 = mundo.ancoras.get(str(nome) + "Frente", Vector3.BACK)
		var local: Vector3 = (mundo.ancoras[varal_da_casa] - base).rotated(Vector3.UP, -atan2(frente.x, frente.z))
		_conferir(not (local.z > 0.0 and absf(local.x) < 2.5), "o varal da '%s' está na faixa da porta (local %s)" % [nome, str(local)])
		_conferir(Vector2(local.x, local.z).length() < 9.0 and Vector2(local.x, local.z).length() > 2.0, "o varal da '%s' está fora do quintal (a %.1f u)" % [nome, Vector2(local.x, local.z).length()])
	_conferir(com_varal >= 18, "devia haver varal em ao menos 18 casas, e há em %d" % com_varal)
	var bichos = JSON.parse_string(FileAccess.get_file_as_string("res://data/bichos_de_casa.json"))
	for item in (bichos as Dictionary).get("casas", []):
		var nome := _da_composicao(mundo, str(item.get("casa", "")))
		if nome == "":
			continue
		var tem_galinha := false
		var tem_porco := false
		for bicho in item.get("bichos", []):
			if str(bicho.get("especie", "")) in ["porco", "leitao"]:
				tem_porco = true
			for ave in bicho.get("aves", []):
				if str(ave.get("especie", "")) in GALINHAS:
					tem_galinha = true
		var chaves: Array = []
		for peca in mundo._pecas_da_casa(nome):
			chaves.append(str(peca.get("chave", "")))
		_conferir(not tem_galinha or "galinheiro" in chaves, "a casa '%s' tem galinha e não tem galinheiro no quintal" % nome)
		_conferir(not tem_porco or "chiqueiro" in chaves, "a casa '%s' tem porco e não tem chiqueiro no quintal" % nome)

	print("rotina: %d moradores novos, %d postos de agenda, %d conferências de hora, %d casas com varal" % [NOVOS.size(), postos, checados, com_varal])
	_fechar()


const ACOES_VALIDAS := ["varrer", "lavar", "mariscar", "capinar", "rachar", "carregar", "estender", "recolher", "balcao", "vigiar",
	"esperar", "rezar", "benzer", "conversar", "olhar", "remendar", "renda", "descansar", "brincar", "pescar", "vender", "recolhido"]


## O nome da casa na composição para o nome que o JSON dos bichos usa.
func _da_composicao(mundo, nome: String) -> String:
	if mundo._casas_autorais.has(nome):
		return nome
	if not mundo.ancoras.has(nome):
		return ""
	for outro in mundo._casas_autorais:
		if mundo.ancoras.has(outro) and (mundo.ancoras[outro] as Vector3).distance_to(mundo.ancoras[nome]) < 0.5:
			return str(outro)
	return ""


## FALSIFICAÇÃO. Sem o argumento não mexe em nada. Com `-- --falsificar-rotina`: a lavadeira
## ganha um lugar que não existe, o pescador deixa de ser mudo e o varal do guarda vai para
## a frente da porta; o portão tem de reprovar nas três perguntas.
func _falsificar(mundo, por_id: Dictionary) -> void:
	if falsificar == "":
		return
	if falsificar in ["tudo", "lugar"]:
		var lavadeira = por_id["lavadeira"]
		lavadeira._agenda[1]["lugar"] = "Lugar que não existe"
		lavadeira._alvos_da_agenda.clear()
	if falsificar in ["tudo", "mudo"]:
		por_id["pescador"].dados["mudo"] = false
	if falsificar in ["tudo", "varal"]:
		var base: Vector3 = mundo.ancoras["Casa do guarda"]
		mundo.ancoras["Casa do guarda/Varal"] = base + (mundo.ancoras["Casa do guardaFrente"] as Vector3) * 3.0


func _ate(condicao: Callable, segundos: float) -> bool:
	var limite := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < limite:
		if bool(condicao.call()):
			return true
		await process_frame
	return bool(condicao.call())


func _passos(n: int) -> void:
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


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("ROTINA_DOS_MORADORES_OK: os catorze moradores novos moram numa casa erguida, falantes, com ofício nos três idiomas; todo lugar da agenda existe e a malha chega até ele; de meia em meia hora cada um está no posto da hora e quem se recolhe some; o relógio que pula seis horas deixa a lavadeira no varal; parado, o corpo toca o clipe do ofício e leva a vassoura (o sacristão); quem é marcado mudo não fala (o pescador, sintético) e o Benedito fala; toda casa tem varal fora da faixa da porta, e galinheiro e chiqueiro onde há galinha e porco")
	else:
		print("rotina_dos_moradores: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)
