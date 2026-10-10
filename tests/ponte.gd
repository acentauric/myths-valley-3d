extends "res://tests/suite/caso.gd"
## Confere A PONTE DO RIO GRANDE, a frente da trilha do 2D (docs/projeto/MISSOES_DO_2D.md,
## 1.3; data/missoes_ponte.json; scripts/prototipo_3d/ponte_vale.gd).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste ponte
##
## Oito perguntas:
##
##   1. O RIO GRANDE TEM VAU E PONTE: os dois nomes resolvem; o vau é água rasa a
##      poucos passos da ponte, e não em cima dela.
##   2. A PONTE COMEÇA CERCADA, E CAÍDA (#94): uma cerca em cada cabeceira, atravessada na
##      estrada, e quem vem pela estrada bate nela.
##   3. A FRENTE ESPERA A CHEGADA E VEM ANTES DO MIRANTE: com a chegada em curso o
##      E no Pedro não a abre; acabada, o primeiro E abre a ponte, e o mirante não
##      abre enquanto ela não acabar.
##   4. VER E CONTAR: chegar ao vau fecha o primeiro passo; o E no Pedro fecha o
##      segundo, com a resposta dele no balão. OS MACHADOS DO AVÔ: chegar com ele
##      à porta da casa dele fecha o terceiro, e a lenha entrega o machado.
##   5. A LENHA CONTA O QUE JÁ VIROU TÁBUA: a conta sai das receitas — trinta e
##      seis, como a fala diz —; trinta lenhas não fecham, e três tábuas a mais sim.
##      E SEM FÔLEGO PARA BATER, a mungunzá da mãe do Pedro vem, uma vez só.
##   6. SERRAR: doze tábuas e quatro cordas fecham o passo, que paga três beijus e
##      ensina o plano da obra.
##   7. A OBRA TIRA A CERCA: ao pé da ponte o J tem a obra; feita, a cerca sai e o
##      passo fecha e paga; desfeita (a partida de antes da obra), a cerca volta.
##   8. O FIM NO PEDRO: o E nele fecha a frente, e o mirante passa a abrir.

## Recebe o vale montado do zero: reprovava no vale deixado pelos casos anteriores (a suíte, #242).
const VALE_NOVO := true

var falhas := 0
var vale
var tecla
var jogador
var pedro


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("PONTE_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	vale = current_scene
	# O ACEITE É AUTOMÁTICO AQUI (08/10): este portão abre filas pelo E e segue; a tela de aceite
	# pausaria o vale no meio da medida (a tela tem portão próprio, tests/missao_a_vista.gd).
	if vale.get("aceite") != null:
		vale.aceite.automatico = true
	tecla = vale.get("tecla_dos_moradores")
	jogador = vale.player
	pedro = vale.get("pedro")
	var mundo = vale.world
	var lugares = root.get_node("/root/Lugares")
	var inv = root.get_node("/root/Inventario")
	var obras = root.get_node("/root/Obras")
	# Carregados aqui, e não no topo: os dois citam autoloads, que no --script só
	# existem depois que a árvore sobe.
	var bancadas = load("res://scripts/prototipo_3d/bancadas_vale.gd")
	var cadeias = load("res://scripts/prototipo_3d/cadeia_de_missoes.gd")
	var receitas = root.get_node("/root/Receitas")
	root.get_node("/root/Dia").pausado = true
	var ponte = vale._cadeias.get("pedro_ponte")
	var arraial = vale._cadeias.get("pedro_arraial")
	var ponte_do_rio = vale.get("ponte_do_rio")
	_conferir(ponte != null and arraial != null and ponte_do_rio != null and pedro != null,
		"o vale não tem a frente da ponte (%s), o mirante (%s) ou a ponte do rio (%s)" % [str(ponte), str(arraial), str(ponte_do_rio)])
	if ponte == null or arraial == null or ponte_do_rio == null or pedro == null:
		_fechar()
		return

	# --- 1. O RIO GRANDE TEM PONTE, E NÃO TEM VAU (#81) ----------------------------------
	var na_ponte: Vector3 = lugares.ponto("ponte_do_rio_grande")
	_conferir(na_ponte.is_finite(), "a ponte do rio grande não resolve no vale")
	if not na_ponte.is_finite():
		_fechar()
		return
	_conferir(not lugares.ponto("vau").is_finite(), "o vau ainda resolve: o rio grande não dá passagem fora da ponte")
	var lamina: float = mundo.water_depth_at(na_ponte)
	_conferir(lamina >= jogador.character_height * jogador.NADA_A_PARTIR,
		"debaixo da ponte o rio dá pé: lâmina de %.2f u (o portão `rio_grande` mede o rio inteiro)" % lamina)
	# A cabeceira do lado de cá, para chegar à ponte pela estrada.
	var regiao = mundo.get("_region")
	var ao_longo_dados: Dictionary = ponte_do_rio.ponte()
	var de_ca: Vector3 = na_ponte
	if not ao_longo_dados.is_empty():
		var ponta: Vector3 = ao_longo_dados["ao_longo"] * (float(ao_longo_dados["comprimento"]) * 0.5 + 3.0)
		de_ca = na_ponte - ponta if float(regiao._lado_do_barranco(Vector2(na_ponte.x - ponta.x, na_ponte.z - ponta.z))) < 0.0 else na_ponte + ponta
		de_ca = mundo.ground_position(de_ca, 0.4)

	# --- 2. A PONTE COMEÇA CERCADA, E CAÍDA (#94) ---------------------------------------------
	var dados: Dictionary = ponte_do_rio.ponte()
	var modelos: Dictionary = (mundo.pontes.get("Ponte", {}) as Dictionary).get("modelos", {})
	_conferir(not modelos.is_empty(), "a ponte não tem os dois modelos, a caída e a de pé")
	_conferir(ponte_do_rio.interditada(), "a ponte não começou cercada")
	var cercas: Array = ponte_do_rio.cercas()
	_conferir(cercas.size() == 2, "a ponte tem %d cerca(s), e são duas, uma em cada cabeceira" % cercas.size())
	if not dados.is_empty():
		var centro: Vector3 = dados["centro"]
		var ao_longo: Vector3 = dados["ao_longo"]
		for cerca: Dictionary in cercas:
			var meio: Vector3 = (cerca["a"] + cerca["b"]) * 0.5
			var ate_o_meio := absf((meio - centro).dot(ao_longo))
			_conferir(absf(ate_o_meio - float(dados["comprimento"]) * 0.5) < 1.5,
				"a cerca está a %.1f u do meio da ponte, e a cabeceira a %.1f" % [ate_o_meio, float(dados["comprimento"]) * 0.5])
			var largura := Vector2(cerca["b"].x - cerca["a"].x, cerca["b"].z - cerca["a"].z).length()
			_conferir(largura >= float(dados["largura"]), "a cerca tem %.1f u e a ponte %.1f: sobra passagem" % [largura, float(dados["largura"])])
		# Quem vem pela estrada bate na cerca: um raio na altura do peito, de fora
		# para dentro da cabeceira.
		await physics_frame
		await physics_frame
		var cabeceira: Vector3 = centro + ao_longo * (float(dados["comprimento"]) * 0.5)
		# Na altura do peito de quem está na cabeceira: a ponte assenta num aterro
		# (#81), e um raio que descesse ao chão de debaixo do tabuleiro — que é o
		# rio — passaria por baixo da cerca.
		var peito: float = mundo.ground_height_at(cabeceira) + 0.6
		var de: Vector3 = cabeceira + ao_longo * 2.5
		de.y = peito
		var ate: Vector3 = cabeceira - ao_longo * 1.5
		ate.y = peito
		var consulta := PhysicsRayQueryParameters3D.create(de, ate)
		var batida: Dictionary = vale.get_world_3d().direct_space_state.intersect_ray(consulta)
		var na_cerca: bool = not batida.is_empty() and batida["collider"] is Node and ponte_do_rio.is_ancestor_of(batida["collider"])
		_conferir(na_cerca, "quem vem pela estrada não bate na cerca da cabeceira: o raio %s" % ("não bateu em nada" if batida.is_empty() else "bateu em " + str(batida["collider"])))
		# A PONTE CAÍDA (#94): até a obra o que há no vão é o modelo caído; o de pé
		# fica escondido com o tabuleiro desligado, e um raio de cima para baixo no
		# meio do vão não bate em tabuleiro nenhum.
		if not modelos.is_empty():
			_conferir(ponte_do_rio.caida() and (modelos["caida"] as Node3D).visible and not (modelos["de_pe"] as Node3D).visible,
				"antes da obra a ponte não está caída (caída visível: %s, de pé visível: %s)" % [str((modelos["caida"] as Node3D).visible), str((modelos["de_pe"] as Node3D).visible)])
			var no_vao: Dictionary = _tabuleiro(vale, centro)
			_conferir(no_vao.is_empty(), "antes da obra ainda há tabuleiro no vão: o raio bateu em '%s'" % str(no_vao.get("collider")))

	# --- 3. A FRENTE ESPERA A CHEGADA E VEM ANTES DO MIRANTE --------------------------------
	await _perto_do_pedro()
	for i in 3:
		tecla.usar(pedro)
		await _quadros(3)
	_conferir(not ponte.iniciado, "com a chegada em curso, o E no Pedro abriu a ponte")
	pedro.missao = pedro.MISSOES.size()
	pedro.set("_despedida_feita", true)
	await _perto_do_pedro()
	tecla.usar(pedro)
	_conferir(await _ate(func() -> bool: return ponte.iniciado, 4.0), "acabada a chegada, o primeiro E no Pedro não abriu a ponte")
	_conferir(not arraial.iniciado, "o E que abriu a ponte abriu o mirante junto")
	_conferir(arraial.o_que_o_e_faz(pedro) != "abrir", "o mirante abre com a ponte por fazer: no 2D ele é do arraial, depois do tutorial")

	# --- 4. VER E CONTAR -----------------------------------------------------------------
	await _ate(func() -> bool: return ponte.espera <= 0.0, 12.0)
	_conferir(str(ponte.passo_atual().get("id", "")) == "ponte_caida", "a frente não começou por ver a ponte: '%s'" % str(ponte.passo_atual().get("id", "")))
	jogador.teleportar(de_ca, 0.0)
	_conferir(await _ate(func() -> bool: return ponte.missao >= 1, 8.0), "chegar à cabeceira de cá não fechou o passo de ver a ponte")
	await _ate(func() -> bool: return ponte.espera <= 0.0, 12.0)
	await _perto_do_pedro()
	tecla.usar(pedro)
	_conferir(await _ate(func() -> bool: return ponte.missao >= 2, 8.0), "o E no Pedro não fechou o passo de contar o que viu")
	_conferir(_no_balao(pedro).contains("Cercada"), "o Pedro não respondeu sobre a cerca: '%s'" % _no_balao(pedro))
	# Os machados do avô: o Pedro vai na frente até a porta dele.
	await _ate(func() -> bool: return ponte.espera <= 0.0, 12.0)
	_conferir(str(ponte.passo_atual().get("id", "")) == "buscar_machado", "depois de contar não vieram os machados do avô: '%s'" % str(ponte.passo_atual().get("id", "")))
	_conferir(not inv.tem("machado"), "o machado chegou antes de o Pedro buscá-lo em casa")
	jogador.teleportar(pedro._destino_da_conducao(ponte) + Vector3(0, 0.4, 0), 0.0)
	_conferir(await _ate(func() -> bool: return ponte.missao >= 3, 8.0), "chegar à porta da casa do Pedro não fechou os machados do avô")
	await _ate(func() -> bool: return ponte.espera <= 0.0, 12.0)
	_conferir(inv.tem("machado"), "a lenha da ponte anunciou e o machado do avô não chegou")

	# --- 5. A LENHA CONTA O QUE JÁ VIROU TÁBUA -------------------------------------------------
	await _ate(func() -> bool: return ponte.espera <= 0.0, 12.0)
	var da_lenha: Dictionary = ponte.passo_atual()
	_conferir(str(da_lenha.get("id", "")) == "ponte_lenha", "depois de contar não veio a lenha: '%s'" % str(da_lenha.get("id", "")))
	var conta: int = cadeias.alvo_da_equivalencia(da_lenha.get("meta", {}))
	_conferir(conta == 36, "a conta da lenha da ponte saiu %d das receitas, e a fala diz trinta e seis" % conta)
	_conferir(str(da_lenha.get("texto", "")).contains("trinta e seis"), "a fala da lenha não diz a conta que a missão cobra")
	for item in ["lenha", "tabua", "corda"]:
		inv.consumir(item, inv.quantidade(item))
	# O SOCORRO: sem fôlego para bater (abaixo do custo de um golpe, e não zero,
	# que é desmaio) e sem nada para comer, as seis cuias, com a fala na caixa.
	var energia = root.get_node("/root/Energia")
	var dialogo = root.get_node("/root/Dialogo")
	inv.consumir("mungunza", inv.quantidade("mungunza"))
	energia.definir(energia.custo("bater", 1.0) * 0.5)
	_conferir(await _ate(func() -> bool: return inv.quantidade("mungunza") == 6, 3.0),
		"sem fôlego no meio da lenha, a mungunzá da mãe do Pedro não veio: %d cuia(s)" % inv.quantidade("mungunza"))
	_conferir(dialogo.ativo, "a mungunzá veio sem a fala do Pedro na caixa")
	var ate_fechar := Time.get_ticks_msec() + 4000
	while dialogo.ativo and Time.get_ticks_msec() < ate_fechar:
		dialogo._fechar()
		await process_frame
	inv.consumir("mungunza", 6)
	await _ate(func() -> bool: return false, 1.2)
	_conferir(inv.quantidade("mungunza") == 0, "a mungunzá veio duas vezes na mesma partida")
	energia.encher()
	var assados: int = inv.quantidade("peixe_assado")
	inv.adicionar("lenha", 30)
	await _quadros(8)
	_conferir(ponte.missao == 3, "trinta lenhas fecharam o passo dos trinta e seis")
	inv.adicionar("tabua", 3)
	_conferir(await _ate(func() -> bool: return ponte.missao >= 4, 8.0),
		"trinta lenhas e três tábuas — seis lenhas serradas — não fecharam o passo: a tábua não conta como lenha")
	_conferir(inv.quantidade("peixe_assado") == assados + 2, "a lenha não pagou os dois peixes assados")

	# --- 6. SERRAR -------------------------------------------------------------------------
	await _ate(func() -> bool: return ponte.espera <= 0.0, 12.0)
	_conferir(str(ponte.passo_atual().get("id", "")) == "tabuas", "depois da lenha não veio serrar: '%s'" % str(ponte.passo_atual().get("id", "")))
	_conferir(receitas.sabe("ponte_levantar"), "o passo de serrar não ensinou o plano da obra da ponte")
	var beijus: int = inv.quantidade("beiju")
	inv.adicionar("tabua", 9)
	await _quadros(8)
	_conferir(ponte.missao == 4, "doze tábuas sem as cordas fecharam o passo de serrar")
	inv.adicionar("corda", 4)
	_conferir(await _ate(func() -> bool: return ponte.missao >= 5, 8.0), "doze tábuas e quatro cordas não fecharam o passo de serrar")
	_conferir(inv.quantidade("beiju") == beijus + 3, "serrar não pagou os três beijus")

	# --- 7. A OBRA TIRA A CERCA ------------------------------------------------------------
	await _ate(func() -> bool: return ponte.espera <= 0.0, 12.0)
	_conferir(str(ponte.passo_atual().get("id", "")) == "ponte", "depois de serrar não veio a obra: '%s'" % str(ponte.passo_atual().get("id", "")))
	if not dados.is_empty():
		var ao_pe: Vector3 = dados["centro"] + dados["ao_longo"] * (float(dados["comprimento"]) * 0.5 + 1.5)
		_conferir(bancadas.obra_perto(mundo, ao_pe) == "ponte", "ao pé da ponte o J não tem a aba de obras dela: '%s'" % bancadas.obra_perto(mundo, ao_pe))
	_conferir(obras.disponiveis("ponte").has("ponte_levantar"), "a obra da ponte não está na lista dela: %s" % str(obras.disponiveis("ponte")))
	var piroes: int = inv.quantidade("pirao")
	var cocadas: int = inv.quantidade("cocada")
	_conferir(obras.executar("ponte", "ponte_levantar"), "a obra da ponte não saiu: %s" % str(obras.impedimento("ponte", "ponte_levantar")))
	_conferir(await _ate(func() -> bool: return not ponte_do_rio.interditada(), 3.0), "a obra feita não tirou a cerca da ponte")
	# E PÕE A PONTE DE PÉ (#94): o modelo de pé volta, com o tabuleiro.
	if not modelos.is_empty() and not dados.is_empty():
		_conferir(not ponte_do_rio.caida() and (modelos["de_pe"] as Node3D).visible and not (modelos["caida"] as Node3D).visible, "feita a obra, a ponte não ficou de pé")
		await physics_frame
		await physics_frame
		var tabuleiro: Dictionary = _tabuleiro(vale, dados["centro"])
		_conferir(not tabuleiro.is_empty() and (modelos["de_pe"] as Node).is_ancestor_of(tabuleiro["collider"]),
			"feita a obra, o tabuleiro não voltou: o raio %s" % ("não bateu em nada" if tabuleiro.is_empty() else "bateu em " + str(tabuleiro["collider"])))
		# ATRAVESSAR É ANDAR, NÃO NADAR (07/10: "ao atravessá-la, o boneco começou a nadar no
		# ar"): em cima do tabuleiro, com o rio fundo lá embaixo, o jogador fica de pé no chão.
		if not tabuleiro.is_empty():
			var em_cima: Vector3 = tabuleiro["position"]
			jogador.teleportar(em_cima + Vector3.UP * 0.3, 0.0)
			for i in 40:
				await physics_frame
			_conferir(not jogador.is_swimming(), "em cima do tabuleiro da ponte o jogador está nadando no ar")
			_conferir(jogador.is_on_floor(), "em cima do tabuleiro o jogador não está de pé no chão")
			_conferir(jogador.global_position.y >= em_cima.y - 0.5,
				"o jogador atravessou o tabuleiro e caiu no rio (y %.2f, tabuleiro %.2f)" % [jogador.global_position.y, em_cima.y])
	_conferir(await _ate(func() -> bool: return ponte.missao >= 6, 8.0), "a obra feita não fechou o passo da ponte")
	_conferir(inv.quantidade("pirao") == piroes + 2 and inv.quantidade("cocada") == cocadas + 2,
		"a ponte não pagou os dois pirões e as duas cocadas")
	var feitas: Dictionary = (obras.feitas as Dictionary).duplicate(true)
	obras.feitas.erase("ponte")
	ponte_do_rio.acertar()
	_conferir(ponte_do_rio.interditada(), "na partida de antes da obra, a cerca não voltou")
	obras.feitas = feitas
	ponte_do_rio.acertar()
	_conferir(not ponte_do_rio.interditada(), "devolvida a obra, a cerca não saiu de novo")

	# --- 8. O FIM NO PEDRO ---------------------------------------------------------------
	await _ate(func() -> bool: return ponte.espera <= 0.0, 12.0)
	await _perto_do_pedro()
	tecla.usar(pedro)
	_conferir(await _ate(func() -> bool: return ponte.acabou(), 8.0), "o E no Pedro não fechou a frente da ponte")
	_conferir(_no_balao(pedro).contains("De pé"), "o Pedro não disse o fim da ponte: '%s'" % _no_balao(pedro))
	_conferir(arraial.o_que_o_e_faz(pedro) == "abrir", "acabada a ponte, o mirante não abre no E do Pedro: '%s'" % arraial.o_que_o_e_faz(pedro))
	_fechar()


func _perto_do_pedro() -> void:
	jogador.teleportar(pedro.global_position + Vector3(1.0, 0.1, 0.6), 0.0)
	await _quadros(5)
	# Desde #121, fala ativa não oferece um novo E de conversar. A fixture
	# aguarda a duração real; mudar a missão não apaga a fala anterior.
	_conferir(await _ate(func() -> bool: return not pedro.falando_agora(), 60.0),
		"a fala anterior termina naturalmente antes do próximo E no Pedro")


func _no_balao(morador) -> String:
	var rotulo = morador.balao.get("_texto")
	return str(rotulo.text) if rotulo != null else ""


## O que um raio de cima para baixo encontra no meio do vão da ponte, do alto
## até pouco abaixo do tabuleiro (máscara do mundo): o tabuleiro de pé, ou nada.
func _tabuleiro(vale, centro: Vector3) -> Dictionary:
	var consulta := PhysicsRayQueryParameters3D.create(centro + Vector3.UP * 3.0, centro - Vector3.UP * 0.6, 1)
	return vale.get_world_3d().direct_space_state.intersect_ray(consulta)


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("PONTE_OK: o rio grande não tem vau, só a ponte, que começa cercada nas duas cabeceiras; a frente espera a chegada, abre no primeiro E do Pedro e segura o mirante; ver a ponte e contar ao Pedro fecham os dois primeiros passos; a lenha conta o que já virou tábua, na conta das receitas, e quem esgota nela ganha a mungunzá uma vez; serrar ensina o plano da obra e paga; a obra tira a cerca, e a partida de antes dela a põe de volta; e o fim no Pedro abre o mirante")
	else:
		print("ponte: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


## Roda quadros até `condicao` valer, com teto em SEGUNDO REAL.
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
