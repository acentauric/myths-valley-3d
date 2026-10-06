extends SceneTree
## JOGA A CADEIA DA DONA ZEFA — as ervas da serra e a história do Cosme.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/cadeia_da_zefa.gd
##
## Veio do jogo 2D (`data/dialogos/arraial.json`, passos zefa_ervas /
## zefa_cosme / zefa_conversa / zefa_terra). Ela manda subir a serra por cinco
## maços de erva; manda falar com o neto; o Cosme conta que tem emprego em
## Salvador e pede segredo; ela já sabia desde que a carta chegou, porque quem lê
## carta naquela casa é ela; e o fim é no píer, no saveiro das seis.
##
## A ORDEM É A DE LÁ, e as ervas vêm primeiro: a última linha do
## `zefa_ervas_fim` é ela mandando falar com o neto. A cadeia entrou aqui sem
## esse primeiro passo, e por isso ela pedia a conversa sem ter pedido nada
## antes — "do chão e da troca" sem a troca.
##
##
## A META DE FALAR COM ALGUÉM
##
## É a forma mais comum de missão do 2D — "Fale com o Tonho no pontal", "Volte à
## Dona Zefa" — e o vale não sabia fazer. As duas metas que existiam mediam o
## mundo: "juntar" conta item na mochila, "derrubar" conta pé cortado. Falar não
## deixa nada no mundo para contar depois; é ACONTECIMENTO, como a entrega.
##
## Por isso ela nasceu junto com a de entrega, no mesmo corpo: "levar" é "falar"
## com item na mão. Escrevê-las separadas seria ter a mesma travessia duas vezes,
## e a segunda ficaria para trás no primeiro conserto da primeira.
##
## Oito perguntas:
##
##   1. A CADEIA É DA DONA ZEFA, é de enredo, tem os quatro passos, e TODO passo
##      aponta lugar que o vale resolve — passo cujo lugar não resolve o `correr`
##      pula em silêncio, e o meio da cadeia sumiria sem ninguém saber.
##   2. ELA DÁ A FOICE AO PEDIR AS ERVAS, e a serra tem moita de erva que cai de
##      foice e rende maço. Sem isto a missão é impossível e a meta diria apenas
##      "faltam 5" para sempre.
##   3. QUATRO MAÇOS NÃO BASTAM. Ao lado dela com quatro, o passo não fecha e
##      nada sai da mochila.
##   4. CINCO FECHA, e os cinco saem — não um. Quem recebe responde.
##   5. CHEGAR PERTO DELA NÃO FECHA O PASSO QUE PEDE O COSME. Sem isto, "fale
##      com o Cosme" fecharia sozinho ao lado de quem mandou — que é o defeito
##      que a meta existe para não ter.
##   6. CHEGAR PERTO DO COSME FECHA, E É ELE QUEM RESPONDE. A fala do fim é de
##      quem recebe, não de quem pediu: a Dona Zefa fica na casa de taipa, e
##      ouvir a resposta dela de longe seria ouvir um balão que não se vê.
##   7. FALAR UMA VEZ BASTA, e voltar a ela fecha o passo da conversa.
##   8. A CADEIA SOBREVIVE A RECARREGAR — mesma armadilha do pirão: depois do
##      encontro não sobra nada no mundo que prove que ele houve.
##
##
## A ESPERA É EM SEGUNDOS DE JOGO, E NÃO DE PAREDE (`tests/fixtures/relogio_de_jogo.gd`).
##
## O golpe da foice leva 1,5 s de jogo, e este portão o esperava em 2,0 s de
## relógio. Com a física limitada a 3 passos por quadro (`project.godot`), o jogo
## anda mais devagar que a parede quando o quadro passa de 50 ms — e na bateria
## cheia passa. Resultado: o mesmo portão que passa sozinho reprovava com "cortei a
## moita e nenhum maço entrou na mochila" — e as três linhas seguintes, que são
## cascata: o golpe atrasado caía DURANTE o passo das quatro ervas e completava os
## cinco que a pergunta 3 queria ver faltando um. Com `MV_QUADRO_LENTO_MS=150` no
## ambiente o portão roda como na bateria no pior; com `MV_QUADRO_LENTO_MS=300` e
## `MV_FALSIFICAR=parede` ele volta a esperar em parede, e então TEM de reprovar com
## essas quatro linhas (a moita é de um golpe só, e o laço dela tem folga: a 150 ms
## ainda passa).

const RelogioDeJogo = preload("res://tests/fixtures/relogio_de_jogo.gd")

var falhas := 0
var relogio: Node
const SEGUNDOS_PARA_ANUNCIAR := 12.0
const SEGUNDOS_POR_PASSO := 15.0
## O golpe inteiro: o impacto cai em 1,5 s de jogo; o resto é folga, e o que se
## cobra aqui é o maço na mochila, e não a pressa do braço.
const SEGUNDOS_DO_GOLPE := 6.0
## Quantos maços a missão pede. Lido do dado e conferido contra isto: se o
## arquivo mudar o número, este portão não pode continuar medindo o antigo.
const MACOS_DA_MISSAO := 5


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("ZEFA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	relogio = RelogioDeJogo.new()
	root.add_child(relogio)
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK,
		"a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(3)
	relogio.ficar_lento()

	var jogo := current_scene
	var jogador = jogo.get("player")
	var inv := root.get_node("/root/Inventario")
	var energia := root.get_node("/root/Energia")
	var lugares := root.get_node("/root/Lugares")
	var recursos := jogo.get_node_or_null("Recursos3D")
	var zefa: Node3D = null
	var cosme: Node3D = null
	for morador in jogo.get("moradores"):
		match str((morador.dados as Dictionary).get("id", "")):
			"zefa":
				zefa = morador
			"cosme":
				cosme = morador
	_conferir(zefa != null, "o vale não tem a Dona Zefa")
	_conferir(cosme != null, "o vale não tem o Cosme: sem ele a conversa não acontece")
	_conferir(recursos != null, "o vale não montou os alvos de trabalho")
	if zefa == null or cosme == null or jogador == null or recursos == null:
		_fechar()
		return

	# --- 1. A CADEIA É DELA, DE ENREDO, DE QUATRO PASSOS, E TODOS RESOLVEM ---
	var cadeia := zefa.get_node_or_null("CadeiaDeMissoes")
	_conferir(cadeia != null, "a Dona Zefa não tem fila de missões")
	if cadeia == null:
		_fechar()
		return
	_conferir(cadeia.total() == 4,
		"a cadeia da Zefa tem %d passo(s), e são quatro: as ervas, o neto, a conversa e o saveiro"
			% cadeia.total())
	_conferir(cadeia.principal,
		"a conversa da Dona Zefa não está marcada como enredo: ela vem depois de um favor de vizinho na lista")
	if cadeia.total() != 4:
		_fechar()
		return
	for i in cadeia.passos.size():
		var onde := str((cadeia.passos[i] as Dictionary).get("lugar", ""))
		_conferir(lugares.resolve(onde),
			"o passo %d aponta '%s', que o vale não resolve: ele seria pulado em silêncio"
				% [i + 1, onde])

	# O NÚMERO É O DO DADO.
	var pedido: Dictionary = (cadeia.passos[0] as Dictionary).get("meta", {})
	_conferir(int(pedido.get("quantos", 1)) == MACOS_DA_MISSAO,
		"as ervas são %d no dado e este portão mede %d"
			% [int(pedido.get("quantos", 1)), MACOS_DA_MISSAO])

	# --- 2. A SERRA TEM ERVA, ANTES DE JOGAR --------------------------------
	var moitas: int = recursos.restantes("erva_da_serra")
	_conferir(moitas >= MACOS_DA_MISSAO,
		"a serra tem %d moita(s) de erva para uma meta de %d: a missão não caberia no vale"
			% [moitas, MACOS_DA_MISSAO])
	print("  moitas de erva postas na serra: %d" % moitas)

	jogador.global_position = zefa.global_position + Vector3(1.2, 0.0, 1.0)
	await _frames(3)
	# A FILA ESPERA A CHEGADA DO PEDRO (docs/mundo/CHEGADA_E_MUTIROES.md, regra 7):
	# ao lado do morador, com a chegada em curso, ela não abre; acabada, abre.
	var guia = current_scene.get("pedro")
	await _ate(func() -> bool: return false, 1.5)
	_conferir(not cadeia.iniciado, "ao lado da Dona Zefa, a fila dela abriu sozinha, sem o E")
	await _falar_com(zefa)
	_conferir(not cadeia.iniciado, "a fila da Dona Zefa abriu com a chegada do Pedro em curso")
	if guia != null:
		guia.missao = guia.MISSOES.size()
		guia.set("_despedida_feita", true)
	await _falar_com(zefa)
	var abriu := await _ate(func() -> bool: return bool(cadeia.iniciado), SEGUNDOS_PARA_ANUNCIAR)
	_conferir(abriu, "com o E na Dona Zefa, a conversa não abriu")
	if not abriu:
		_fechar()
		return
	var anunciou := await _ate(func() -> bool: return cadeia.espera <= 0.0, SEGUNDOS_PARA_ANUNCIAR)
	_conferir(anunciou, "o primeiro passo não chegou a anunciar")
	await _frames(2)

	# ELA DÁ A FOICE AO PEDIR O CORTE — na barra de mão, sem trocar o que está na
	# mão (`CadeiaDeMissoes._por_na_barra`): o jogador aperta o número dela.
	var da_foice := -1
	for i in inv.ESPACOS_MAO:
		if str((inv.espacos[i] as Dictionary).get("id", "")) == "foice":
			da_foice = i
	_conferir(da_foice >= 0, "a Dona Zefa pediu erva cortada e não deixou a foice na barra de mão")
	if da_foice >= 0:
		inv.selecionar(da_foice)
	_conferir(recursos._tem_ferramenta("foice"),
		"com o número da foice apertado, a foice da Dona Zefa não ficou à mão")

	# O CORTE É DE VERDADE: anda até uma moita e bate, como o jogador.
	var antes_de_cortar: int = inv.quantidade("erva_da_serra")
	var onde_a_moita: Vector3 = recursos.mais_perto_que_rende("erva_da_serra", jogador.global_position)
	_conferir(onde_a_moita != Vector3.ZERO, "não achei uma moita de erva para cortar")
	if onde_a_moita != Vector3.ZERO:
		jogador.global_position = onde_a_moita
		await _frames(4)
		var bateu := false
		for golpe in 10:
			energia.encher()
			if recursos.bater():
				bateu = true
				await _ate(func() -> bool: return relogio.golpe_acabou(recursos), relogio.janela(SEGUNDOS_DO_GOLPE, 2.0))
			if inv.quantidade("erva_da_serra") > antes_de_cortar:
				break
			await _frames(2)
		_conferir(bateu, "bati na moita com a foice à mão e o golpe não saiu")
		_conferir(inv.quantidade("erva_da_serra") > antes_de_cortar,
			"cortei a moita e nenhum maço entrou na mochila")

	# --- 3. QUATRO MAÇOS NÃO BASTAM -----------------------------------------
	var nas_ervas: int = cadeia.missao
	while inv.quantidade("erva_da_serra") > MACOS_DA_MISSAO - 1:
		inv.consumir("erva_da_serra", 1)
	while inv.quantidade("erva_da_serra") < MACOS_DA_MISSAO - 1:
		inv.adicionar("erva_da_serra", 1)
	_conferir(inv.quantidade("erva_da_serra") == MACOS_DA_MISSAO - 1,
		"não consegui deixar a mochila com %d maço(s)" % (MACOS_DA_MISSAO - 1))

	jogador.global_position = zefa.global_position + Vector3(1.0, 0.0, 0.8)
	await _frames(3)
	await _falar_com(zefa)
	await _ate(func() -> bool: return cadeia.missao > nas_ervas, 5.0)
	_conferir(cadeia.missao == nas_ervas,
		"cheguei com %d maços e a entrega de %d fechou: a conta da meta 'levar' não é feita"
			% [MACOS_DA_MISSAO - 1, MACOS_DA_MISSAO])
	_conferir(inv.quantidade("erva_da_serra") == MACOS_DA_MISSAO - 1,
		"a entrega que não aconteceu comeu erva: sobraram %d" % inv.quantidade("erva_da_serra"))

	# --- 4. CINCO FECHA, E OS CINCO SAEM -----------------------------------
	var respostas: Array[String] = []
	if zefa.has_signal("narrou"):
		zefa.narrou.connect(func(texto: String) -> void: respostas.append(texto))
	inv.adicionar("erva_da_serra", 1)
	var macos_antes: int = inv.quantidade("erva_da_serra")
	await _frames(3)
	await _falar_com(zefa)
	var entregou := await _ate(func() -> bool: return cadeia.missao > nas_ervas, SEGUNDOS_POR_PASSO)
	_conferir(entregou, "cheguei com os cinco maços e a entrega não fechou")
	print("  %-16s %s" % ["zefa_ervas", "fechou" if entregou else "PRESO"])
	if entregou:
		_conferir(inv.quantidade("erva_da_serra") == macos_antes - MACOS_DA_MISSAO,
			"a entrega tirou %d maço(s), e devia tirar %d"
				% [macos_antes - inv.quantidade("erva_da_serra"), MACOS_DA_MISSAO])
	if not respostas.is_empty():
		var dela := " ".join(respostas)
		_conferir(dela.contains("alecrim") or dela.contains("cheiro"),
			"a resposta das ervas não é a do 2D: '%s'" % respostas[0])

	var anunciou2 := await _ate(func() -> bool: return cadeia.espera <= 0.0, SEGUNDOS_PARA_ANUNCIAR)
	_conferir(anunciou2, "o passo do neto não chegou a anunciar")
	await _frames(2)
	print("")

	# --- 5. AO LADO DE QUEM MANDOU, O PASSO DO COSME NÃO FECHA -------------
	#
	# O jogador está encostado na Dona Zefa, e o passo pede o COSME. Se fechar
	# assim, "fale com fulano" vira "fique parado onde já está".
	_conferir(cadeia.missao == 1,
		"a cadeia pulou o passo do neto: está no passo %d" % (cadeia.missao + 1))
	var no_neto: int = cadeia.missao
	await _falar_com(zefa)
	await _ate(func() -> bool: return cadeia.missao != no_neto, 4.0)
	_conferir(cadeia.missao == no_neto,
		"o passo que pede o Cosme fechou ao lado da Dona Zefa: a meta de falar virou enfeite")

	# --- 6. PERTO DO COSME FECHA, E É ELE QUEM RESPONDE --------------------
	var do_cosme: Array[String] = []
	if cosme.has_signal("narrou"):
		cosme.narrou.connect(func(texto: String) -> void: do_cosme.append(texto))
	jogador.global_position = cosme.global_position + Vector3(1.0, 0.0, 0.8)
	await _frames(3)
	await _falar_com(cosme)
	var fechou := await _ate(func() -> bool: return cadeia.missao > no_neto, SEGUNDOS_POR_PASSO)
	_conferir(fechou, "com o E no Cosme, o passo não fechou")
	print("  %-16s %s" % ["zefa_cosme", "fechou" if fechou else "PRESO"])
	var do_balao := str(cosme.balao.get("_texto").text)
	_conferir(cosme._balao_tempo > 0.0 and do_balao.contains("Salvador"),
		"quem recebeu não respondeu: a fala do fim ficou na boca de quem pediu ('%s')" % do_balao)
	if not do_cosme.is_empty():
		_conferir(str(do_cosme[0]).contains("Salvador"),
			"a resposta do Cosme não é a do 2D: '%s'" % do_cosme[0])

	# --- 7. FALAR UMA VEZ BASTA, E VOLTAR A ELA FECHA A CONVERSA ----------
	_conferir(bool(cadeia._levados.get("zefa_cosme", false)),
		"a cadeia não lembra que a conversa com o Cosme aconteceu")
	_conferir(not cadeia.falta_a_meta(cadeia.passos[1]),
		"depois da conversa a meta do Cosme voltou a faltar: o passo pediria de novo")

	var anunciou3 := await _ate(func() -> bool: return cadeia.espera <= 0.0, SEGUNDOS_PARA_ANUNCIAR)
	_conferir(anunciou3, "o passo da conversa não chegou a anunciar")
	var na_conversa: int = cadeia.missao
	await _falar_com(cosme)
	await _ate(func() -> bool: return cadeia.missao != na_conversa, 4.0)
	_conferir(cadeia.missao == na_conversa,
		"o passo que manda voltar à Dona Zefa fechou com o jogador ao lado do Cosme")
	jogador.global_position = zefa.global_position + Vector3(1.0, 0.0, 0.8)
	await _frames(3)
	await _falar_com(zefa)
	var voltou := await _ate(func() -> bool: return cadeia.missao > na_conversa, SEGUNDOS_POR_PASSO)
	_conferir(voltou, "voltei à Dona Zefa e o passo não fechou")
	print("  %-16s %s" % ["zefa_conversa", "fechou" if voltou else "PRESO"])

	# --- 8. A CADEIA SOBREVIVE A RECARREGAR --------------------------------
	var guardado: Dictionary = jogo.estado_para_salvar()
	var guardadas: Dictionary = guardado.get("cadeias", {})
	_conferir(guardadas.has("zefa"), "o save não leva a fila da Dona Zefa")
	var dela_no_save: Dictionary = guardadas.get("zefa", {})
	var levados: Array = dela_no_save.get("levados", [])
	_conferir(levados.has("zefa_ervas"),
		"o save não lembra a entrega das ervas: recarregar mandaria subir a serra de novo")
	_conferir(levados.has("zefa_cosme"),
		"o save não lembra a conversa com o Cosme: recarregar mandaria falar com ele de novo")

	cadeia._levados.clear()
	cadeia.missao = 0
	jogo.restaurar_do_save(guardado)
	await _frames(2)
	_conferir(not cadeia.falta_a_meta(cadeia.passos[0]),
		"recarregar esqueceu a entrega das ervas")
	_conferir(not cadeia.falta_a_meta(cadeia.passos[1]),
		"recarregar esqueceu a conversa com o Cosme")

	_fechar()


## O E AO LADO DE QUEM SE FALA, pelo caminho do jogo (`tecla_dos_moradores.gd`):
## conversar, abrir a fila do morador, cumprir o passo que manda a ele.
func _falar_com(morador) -> void:
	current_scene.get("tecla_dos_moradores").usar(morador)
	await process_frame


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("ZEFA_OK: a fila é da Dona Zefa, é de enredo, tem os quatro passos e todos apontam lugar que o vale resolve; ela dá a foice e a serra tem moita de erva que cai de foice e rende maço; quatro maços NÃO fecham a entrega de cinco nem comem erva, e cinco fecham tirando os cinco; o passo que pede o Cosme não fecha ao lado de quem mandou, fecha ao chegar nele e quem responde é ele; voltar a ela fecha a conversa; e recarregar não manda subir a serra nem conversar de novo")
	else:
		print("zefa: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


## Espera `condicao` por até `segundos` DE JOGO (ver o cabeçalho): nunca menos, em
## parede, que os segundos de relógio que este portão esperava antes.
func _ate(condicao: Callable, segundos: float) -> bool:
	return await relogio.ate(condicao, segundos)


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
