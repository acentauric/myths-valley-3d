extends "res://tests/suite/caso.gd"
## AS FILAS TRANCADAS DIZEM O QUE FALTA, E O MORADOR SEM CAMINHO ESPERA PARADO.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste filas_trancadas
##
## DOIS DEFEITOS PEQUENOS DA MESMA NOITE DE JOGO (Build 9B, 06/10/2026):
##
## 1. O Damião, o Tonho, a carroça do Seu Benedito, a lombada e a Dona Zefa/Candinha/Filó
##    antes do fim do tutorial só tinham a conversa de passagem no E. O jogador apertava o
##    E, ouvia um "o peixe está bom" e não sabia o que lhe faltava. Agora a fila trancada
##    (`CadeiaDeMissoes.esta_trancada`) escreve o aviso (`trancada`, nos três idiomas, no
##    arquivo dela) e o morador diz "volte depois de ..." no lugar da conversa, pela fila de
##    falas. Com uma fila dele andando, ou com a trancada já aberta, a conversa é a de sempre.
##    E o PEDRO, que tem muitas filas e as `falas_depois` dele, não perde as falas para o aviso: com
##    fila dele por abrir (a ponte, as armas, o ofício) o E é dela, e sem nenhuma por abrir nem andando
##    cada aviso sai uma vez só e ele volta às falas (`tests/saudacao.gd` reprovou com o aviso da chapada).
##
## 2. `npc._ponto_do_caminho` andava RETO até o destino por `REFAZER_CAMINHO` (4 s) sempre
##    que a malha de navegação respondia vazio — logo depois de ela reassar, por exemplo —, e
##    o reto passa por cima da água, do casco do saveiro e das paredes: o Pedro empacava na
##    frente do jogador. Agora o caminho vazio se refaz em 0,3 s e, enquanto isso, o morador
##    fica parado.
##
## Os dois se provam jogando o que o jogador faz: o E no morador (`tecla_dos_moradores`) e o
## relógio do jogo andando (`tests/fixtures/relogio_de_jogo.gd`: espera em segundos de JOGO).
##
## COMO SE FALSIFICA: apague o `if trancada != null` de `npc.conversar` e a seção 1 reprova;
## tire de `npc._fila_que_avisa` o `or ... == "abrir"` e a 1b reprova (e o `tests/saudacao.gd` também);
## faça `GuiaPedro._repete_o_aviso` devolver true e a 1b reprova de novo (o Pedro repete a chapada);
## volte `REFAZER_SEM_CAMINHO` para 4.0, ou tire o `if not _esperando_a_malha` do passo do
## morador, e a seção 2 reprova.

## Recebe o vale montado do zero: reprovava no vale deixado pelos casos anteriores (a suíte, #242).
const VALE_NOVO := true

const RelogioDeJogo = preload("res://tests/fixtures/relogio_de_jogo.gd")

## Quem tem fila trancada no começo da partida: {morador, fila}.
const TRANCADAS := [
	["zefa", "zefa"], ["candinha", "candinha"], ["filo", "filo"], ["damiao", "damiao"],
	["tonho", "tonho"], ["benedito", "benedito_saveiro"], ["cosme", "cosme_roca"],
]

const PovoadoLiberado = preload("res://tests/fixtures/povoado_liberado.gd")
const ConversaDoE = preload("res://tests/fixtures/conversa_do_e.gd")

var falhas := 0
var relogio: Node
const PASSOS_POR_SEGUNDO := 60


## A malha de navegação que responde vazio enquanto `vazia`, e depois a de verdade. Anota
## em que passo de física foi perguntada (o morador conta o tempo dele em passos de física) e se respondeu algo.
class MalhaFalsa extends Node:
	var vazia := true
	var verdadeira: Node = null
	var perguntas: Array = []

	func esta_pronta() -> bool:
		return true

	func caminho(de: Vector3, para: Vector3) -> PackedVector3Array:
		var resposta := PackedVector3Array()
		if not vazia and verdadeira != null:
			resposta = verdadeira.caminho(de, para)
		perguntas.append({"em": Engine.get_physics_frames(), "vazia": resposta.is_empty(), "para": para})
		return resposta


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("FILAS_TRANCADAS_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	for i in range(3000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await _quadros(8)
	relogio = RelogioDeJogo.new()
	root.add_child(relogio)
	relogio.ficar_lento()

	var vale := current_scene
	# O povoado se apresenta aos poucos na chegada (#155): este portão fala com moradores de longe.
	await PovoadoLiberado.todos(self, vale)
	# O ACEITE É AUTOMÁTICO AQUI (08/10): este portão abre filas pelo E e segue; a tela de aceite
	# pausaria o vale no meio da medida (a tela tem portão próprio, tests/missao_a_vista.gd).
	if vale.get("aceite") != null:
		vale.aceite.automatico = true
	var jogador = vale.get("player")
	var pedro = vale.get("pedro")
	var tecla = vale.get("tecla_dos_moradores")
	var fila := get_first_node_in_group("fila_de_falas")
	var dia := root.get_node("/root/Dia")
	var inventario := root.get_node("/root/Inventario")
	_conferir(jogador != null and pedro != null and tecla != null and fila != null,
		"o vale não tem o jogador, o Pedro, o E dos moradores ou a fila de falas")
	if jogador == null or pedro == null or tecla == null or fila == null:
		_fechar()
		return
	dia.pausado = true
	dia.definir_hora(9.0)
	await _quadros(4)

	# --- 1. O MORADOR DA FILA TRANCADA DIZ O QUE FAZER ANTES ------------------------------
	for par in TRANCADAS:
		var quem := str(par[0])
		var morador = vale._achar_morador(quem)
		var cadeia = vale._cadeias.get(str(par[1]))
		_conferir(morador != null and cadeia != null, "o vale não tem '%s' ou a fila '%s'" % [quem, par[1]])
		if morador == null or cadeia == null:
			continue
		_conferir(cadeia.esta_trancada(),
			"no começo da partida a fila '%s' devia estar trancada (tutorial, machado ou piaçava por fazer)" % par[1])
		var aviso := str(cadeia.dica_da_trancada())
		_conferir(aviso.strip_edges() != "", "a fila '%s' está trancada e não escreveu o aviso (`trancada` no arquivo dela)" % par[1])
		fila.calar_falante(morador)
		# E o anúncio do passo do Pedro, que ainda estiver no ar: a resposta do E espera a vez (não corta quem fala), e este
		# portão é do que o morador da fila trancada diz, e não da vez do Pedro.
		fila.calar_falante(pedro)
		await _quadros(2)
		jogador.teleportar(morador.global_position + Vector3(1.4, 0.0, 0.6), -2.0)
		await _quadros(3)
		await ConversaDoE.usar(tecla, morador)
		var falou: bool = await relogio.ate(func() -> bool:
			return fila.falando(morador) and str(fila.atual().get("texto", "")) == aviso, 14.0)
		_conferir(falou, "o E em '%s', de fila trancada, não disse '%s' (disse: '%s')" % [quem, aviso, str(fila.atual().get("texto", ""))])
		fila.calar_falante(morador)
		await _quadros(2)

	# COM UMA FILA DELE ANDANDO, a conversa de passagem: o objetivo está no HUD.
	var zefa = vale._achar_morador("zefa")
	var da_zefa = vale._cadeias["zefa"]
	da_zefa.iniciado = true
	da_zefa.missao = 0
	_conferir(not da_zefa.esta_trancada() and da_zefa.dica_da_trancada() == "" and zefa._dica_da_fila_trancada() == "",
		"com a fila andando, a Dona Zefa ainda diz o aviso de fila trancada")
	da_zefa.iniciado = false
	da_zefa.missao = -1
	_conferir(zefa._dica_da_fila_trancada() == str(da_zefa.trancada_texto), "desfeito o estado, o aviso não voltou")

	# ACABADO O TUTORIAL, as de depois do tutorial abrem, e as do machado seguem trancadas.
	var guia = pedro._cadeia
	guia.iniciado = true
	guia.missao = guia.passos.size()
	guia.despedida_feita = true
	await _quadros(3)
	_conferir(pedro.terminou_o_tutorial(), "o caso não se montou: o tutorial não acabou")
	# A PONTE ABRE SOZINHA com o tutorial acabado (07/10): é o enredo, e o Pedro a anuncia na
	# despedida. Em curso no primeiro passo, antes do machado: o Damião segue trancado.
	var da_ponte = vale._cadeias["pedro_ponte"]
	jogador.teleportar(pedro.global_position + Vector3(1.4, 0.0, 0.6), -2.0)
	_conferir(await relogio.ate(func() -> bool: return da_ponte.iniciado, 4.0), "acabado o tutorial, com o Pedro ao lado, a ponte do rio grande não abriu sozinha")
	_conferir(not da_zefa.esta_trancada() and zefa._dica_da_fila_trancada() == "",
		"acabado o tutorial, a Dona Zefa continua dizendo 'volte depois'")
	var do_damiao = vale._cadeias["damiao"]
	var damiao = vale._achar_morador("damiao")
	_conferir(do_damiao.esta_trancada() and damiao._dica_da_fila_trancada() != "",
		"acabado o tutorial e sem o machado, o Damião devia seguir dizendo o que falta")
	inventario.adicionar("machado", 1)
	await _quadros(3)
	_conferir(not do_damiao.esta_trancada() and damiao._dica_da_fila_trancada() == "",
		"com o machado na mochila, o Damião continua dizendo 'volte depois'")
	inventario.consumir("machado", 1)
	# E o E na Dona Zefa, destrancada, ABRE a fila dela (e não diz o aviso).
	jogador.teleportar(zefa.global_position + Vector3(1.4, 0.0, 0.6), -2.0)
	await _quadros(3)
	await ConversaDoE.usar(tecla, zefa)
	await _quadros(3)
	_conferir(da_zefa.iniciado, "o E na Dona Zefa, com a fila destrancada, não a abriu")

	# --- 1b. O PEDRO, ACABADO O TUTORIAL: O AVISO NÃO TOMA AS FALAS DELE --------------------
	# Ele tem a ponte, as armas e o ofício por abrir no E, e as da chapada, do mirante, da fé e da lapa
	# trancadas. O aviso da chapada ("volte depois de colher a primeira roça") tomava o E dele e escondia as
	# `falas_depois` — o `tests/saudacao.gd` reprovou: "depois do tutorial o Pedro disse 'A chapada vai
	# esperar...', que não é das falas de depois dele". Agora: com fila por abrir, o E é dela e a conversa é
	# a de depois do tutorial; sem nenhuma por abrir nem andando, cada aviso sai UMA vez e ele volta às falas.
	fila.calar_falante(zefa)
	fila.calar_falante(pedro)
	await _quadros(2)
	var de_depois_do_pedro: Array[String] = []
	for fala in (pedro.dados as Dictionary).get("falas_depois", []):
		for chave in ["texto", "texto_en", "texto_es"]:
			if str((fala as Dictionary).get(chave, "")) != "":
				de_depois_do_pedro.append(str(fala[chave]))
	_conferir(not de_depois_do_pedro.is_empty(), "o Pedro não tem `falas_depois` no npcs_3d.json")
	var da_chapada = vale._cadeias["pedro_chapada"]
	var das_armas = vale._cadeias["pedro_armas"]
	var aviso_da_chapada := str(da_chapada.dica_da_trancada())
	_conferir(da_chapada.esta_trancada() and aviso_da_chapada != "" and not das_armas.esta_trancada() and not das_armas.iniciado,
		"o caso do Pedro não se montou: a chapada devia estar trancada (com aviso) e as armas por abrir")
	# Com as armas por abrir, ele não tem aviso a dar: o E é delas.
	_conferir(pedro._dica_da_fila_trancada() == "",
		"com as armas por abrir, o Pedro ainda tem aviso de fila trancada a dar: '%s'" % pedro._dica_da_fila_trancada())
	jogador.teleportar(pedro.global_position + Vector3(1.4, 0.0, 0.6), -2.0)
	await _quadros(3)
	pedro.conversar()
	var com_a_ponte_por_abrir: bool = await relogio.ate(func() -> bool: return fila.falando(pedro), 14.0)
	var dito_com_a_ponte := str(fila.atual().get("texto", ""))
	_conferir(com_a_ponte_por_abrir and de_depois_do_pedro.has(dito_com_a_ponte),
		"com a ponte por abrir, conversar com o Pedro disse '%s', que não é das falas de depois do tutorial" % dito_com_a_ponte)
	fila.calar_falante(pedro)
	await _quadros(2)

	# Feitas as filas dele que abriam (e as que elas destrancam), só a chapada espera: o aviso sai uma vez.
	for chave in ["pedro_ponte", "pedro_arraial", "pedro_fe", "pedro_lombada", "pedro_armas", "pedro_oficio"]:
		var feita = vale._cadeias[chave]
		feita.iniciado = true
		feita.missao = feita.passos.size()
		# A despedida dada: sem ela a fila acabada fala o arremate pela boca do Pedro, e ele já estaria falando.
		feita.despedida_feita = true
	await _quadros(3)
	_conferir(da_chapada.esta_trancada() and pedro._dica_da_fila_trancada() == aviso_da_chapada,
		"com as outras filas feitas, o Pedro devia ter o aviso da chapada a dar, e tem '%s'" % pedro._dica_da_fila_trancada())
	fila.calar_falante(pedro)
	await _quadros(2)
	await ConversaDoE.usar(tecla, pedro)
	var avisou: bool = await relogio.ate(func() -> bool:
		return fila.falando(pedro) and str(fila.atual().get("texto", "")) == aviso_da_chapada, 14.0)
	_conferir(avisou, "o E no Pedro, sem fila por abrir nem andando, não disse o aviso da chapada (disse: '%s')" % str(fila.atual().get("texto", "")))
	fila.calar_falante(pedro)
	await _quadros(2)
	_conferir(pedro._dica_da_fila_trancada() == "", "o Pedro já deu o aviso da chapada e ainda o tem a dar: ele o repete")
	await ConversaDoE.usar(tecla, pedro)
	var voltou_as_falas: bool = await relogio.ate(func() -> bool: return fila.falando(pedro), 14.0)
	var dito_depois := str(fila.atual().get("texto", ""))
	_conferir(voltou_as_falas and dito_depois != aviso_da_chapada and de_depois_do_pedro.has(dito_depois),
		"dado o aviso da chapada, o Pedro devia voltar às falas de depois do tutorial, e disse '%s'" % dito_depois)
	fila.calar_falante(pedro)
	await _quadros(2)

	# --- 2. O CAMINHO VAZIO SE REFAZ LOGO, E O MORADOR ESPERA PARADO -----------------------
	var tonho = vale._achar_morador("tonho")
	var navegacao := get_first_node_in_group("navegacao")
	_conferir(tonho != null and navegacao != null, "o vale não tem o Tonho ou a malha de navegação")
	if tonho != null and navegacao != null:
		# A MALHA DE VERDADE TEM DE ESTAR ASSADA: ela assa em segundo plano depois de o vale subir e, com a máquina
		# cheia (a bateria roda vários portões juntos), demora — sem ela a "verdadeira" da malha falsa responde vazio
		# e o caso de "a malha voltou a responder" não se monta. Espera, e diz o que viu se ela não acha o caminho.
		var assou: bool = await relogio.ate(func() -> bool: return navegacao.esta_pronta(), 180.0)
		_conferir(assou, "a malha de navegação não ficou pronta em 180 s de jogo")
		tonho.liberar()
		tonho.ir_ao_posto_agora()
		await _quadros(4)
		var rota_real: PackedVector3Array = navegacao.caminho(tonho.global_position, root.get_node("/root/Lugares").ponto("praca"))
		_conferir(not rota_real.is_empty(), "a malha de verdade não acha caminho do Tonho (%s, posto de agora) à praça: o caso não se monta (pronta=%s)" % [str(tonho.global_position), str(navegacao.esta_pronta())])
		jogador.teleportar(tonho.global_position + Vector3(1.4, 0.2, 0.6), -2.0)
		await _quadros(4)
		var falsa := MalhaFalsa.new()
		falsa.verdadeira = navegacao
		navegacao.remove_from_group("navegacao")
		falsa.add_to_group("navegacao")
		root.add_child(falsa)
		var praca: Vector3 = root.get_node("/root/Lugares").ponto("praca")
		var saida: Vector3 = tonho.global_position
		tonho.ir_ate(praca, 2.6)
		# EM PASSOS DE FÍSICA, que é o relógio do morador: com a bateria cheia o quadro engorda e o
		# tempo de parede (ou de processo) não anda junto com ele.
		await _passos(PASSOS_POR_SEGUNDO)
		var andou_sem_malha: float = Vector2(tonho.global_position.x - saida.x, tonho.global_position.z - saida.z).length()
		_conferir(andou_sem_malha < 0.35,
			"com a malha respondendo vazio o Tonho andou %.2f u reto rumo ao destino (devia esperar parado, em até 0,35)" % andou_sem_malha)
		var perguntas_vazias := 0
		for p in falsa.perguntas:
			if bool(p["vazia"]) and (p["para"] as Vector3).distance_to(praca) < 0.5:
				perguntas_vazias += 1
		_conferir(perguntas_vazias >= 2,
			"o caminho vazio não se refez logo: só %d pergunta(s) à malha em 1 s de física (refaz a cada 0,3 s)" % perguntas_vazias)
		var passo_da_volta := Engine.get_physics_frames()
		falsa.vazia = false
		var voltou: bool = false
		var demorou := 0
		for i in range(PASSOS_POR_SEGUNDO * 3):
			await physics_frame
			for p in falsa.perguntas:
				if int(p["em"]) >= passo_da_volta and not bool(p["vazia"]) and (p["para"] as Vector3).distance_to(praca) < 0.5:
					voltou = true
					demorou = int(p["em"]) - passo_da_volta
					break
			if voltou:
				break
		_conferir(voltou and demorou < PASSOS_POR_SEGUNDO,
			"a malha voltou a responder e o Tonho levou %d passos de física (%.2f s) para refazer o caminho (devia ser menos de 1 s)" % [demorou, float(demorou) / PASSOS_POR_SEGUNDO])
		await _passos(PASSOS_POR_SEGUNDO * 2)
		var andou_com_malha: float = Vector2(tonho.global_position.x - saida.x, tonho.global_position.z - saida.z).length()
		_conferir(andou_com_malha > 1.5,
			"com o caminho refeito o Tonho andou só %.2f u em 2 s de física: ele ficou parado depois de a malha voltar" % andou_com_malha)
		# SEM RESPOSTA NENHUMA POR MUITO TEMPO, a malha não tem o que dizer: o morador volta ao reto
		# (o que era antes), e não fica parado para sempre.
		falsa.vazia = true
		tonho.liberar()
		tonho.global_position = saida
		tonho.velocity = Vector3.ZERO
		await _quadros(3)
		var de_novo: Vector3 = tonho.global_position
		tonho.ir_ate(praca, 2.6)
		await _passos(int(PASSOS_POR_SEGUNDO * 4.5))
		var reto: float = Vector2(tonho.global_position.x - de_novo.x, tonho.global_position.z - de_novo.z).length()
		_conferir(reto > 1.0,
			"depois de 4,5 s de física com a malha muda o Tonho andou só %.2f u: ele devia voltar ao caminho reto" % reto)
		tonho.liberar()
		falsa.remove_from_group("navegacao")
		navegacao.add_to_group("navegacao")
		falsa.queue_free()

	_fechar()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("FILAS_TRANCADAS_OK: o morador da fila trancada diz, no E e pela fila de falas, o que fazer antes (zefa, candinha, filo, damião, tonho, benedito, cosme), cala quando a fila anda ou abre (tutorial acabado, machado na mochila), o Pedro de depois do tutorial fica com as falas dele (o aviso de fila trancada só sai quando nenhuma fila dele abre ou anda, e uma vez cada), e o caminho vazio da malha se refaz em menos de 1 s com o morador parado, voltando ao reto se a malha continua muda")
	else:
		print("filas_trancadas: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


## Passa `quantos` passos de física.
func _passos(quantos: int) -> void:
	for i in range(quantos):
		await physics_frame


func _quadros(quantos: int) -> void:
	for i in range(quantos):
		await process_frame
