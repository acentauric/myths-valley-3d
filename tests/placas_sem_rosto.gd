extends "res://tests/suite/caso.gd"
## A PLACA DE NOME NÃO CAI NO ROSTO DE NINGUÉM E ESMAECE ATRÁS DO QUE ESTÁ MAIS PERTO (#184).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste placas_sem_rosto
##     $env:MV_FALSIFICAR = "rosto"    (o portão TEM de reprovar: a placa sem a silhueta de ninguém)
##
## "'Dona Zefa' cobre o rosto e o chapéu dela, a poucos metros do jogador. O mesmo pode
## acontecer com a plaquinha passando na frente do viajante ou de outro morador mais próximo."
## A placa conhecia o HUD, o balão e a dica do E, mas não as silhuetas (`placas_nomes.gd`).
##
##   1. AS CONTAS, SEM MUNDO: `subida_do_rosto` sobe só o que falta (e empilha sobre vários
##      rostos), e `alfa_por_profundidade` só esmaece por quem está mais perto da câmera
##      e que a placa cobre — mais com mais cobertura e mais distância, nunca abaixo do piso, e
##      o piso de quem importa é mais alto.
##   2. O ROSTO DO DONO: com a câmera perto, média e longe, nenhuma placa ligada cobre a cabeça de
##      ninguém (a do dono, a de quem está ao lado, a do jogador).
##   3. O ROSTO DE QUEM ESTÁ PERTO: a cabeça de outro morador posta bem sob onde a placa cairia a
##      faz subir (acima da cabeça, sem cobri-la), com a câmera perto, média e longe; sem ela (o
##      controle) a conta crua de antes a cobriria.
##   4. A PROFUNDIDADE: a placa de quem está longe, passando sobre o tronco de um personagem mais perto
##      da câmera, fica transparente aos poucos — e volta ao alfa cheio quando ele sai da frente.
##   5. SEM PISCAR: com o jogador girando a câmera em volta, a placa não liga e desliga a cada
##      quadro: o número de trocas de vaga fica baixo e o alfa da profundidade nunca salta mais
##      que a janela de fade.
##   6. A PRAÇA CHEIA: com todos os moradores à mão em cacho, a câmera perto, média e longe e a
##      missão apontando o mais longe, nenhuma placa cai sobre uma cabeça e o alvo da missão
##      continua com a placa dele.
##   7. EM CONVERSA: com um morador falando, o balão tem prioridade e nenhuma placa fica na tela (#218).
##
## A cena do vale é a de `popups_na_tela.gd`: o jogador na praça, o Pedro fora do caminho, os
## moradores parados onde o portão os põe (`_quadro`).

## Recebe o vale montado do zero: reprovava no vale deixado pelos casos anteriores (a suíte, #242).
const VALE_NOVO := true

const PopupsDoMundo = preload("res://scripts/prototipo_3d/popups_do_mundo.gd")
const RelogioDeJogo = preload("res://tests/fixtures/relogio_de_jogo.gd")

## Carregado no _run, não por preload: no --script o preload compila antes de os autoloads (o Estilo
## das placas) virarem nomes globais, e o portão não abria.
var PlacasNomes: GDScript
## Roçar de um ou dois pixels (a mola e o arredondamento da posição da placa) não é cobrir.
const TOLERANCIA_DE_PX2 := 16.0
var falhas := 0
var falsificar := false
var relogio: Node
var vale
var jogador
var camera: Camera3D
var placas
## Quem o portão usa e onde os põe (reposto a cada quadro).
var fixos: Dictionary = {}
## Os três postos à frente do jogador, a mais de 5 m dele.
var postos: Array[Vector3] = []


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("PLACAS_SEM_ROSTO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	PlacasNomes = load("res://scripts/prototipo_3d/placas_nomes.gd")
	falsificar = OS.get_environment("MV_FALSIFICAR") == "rosto"
	if falsificar:
		print("  FALSIFICAÇÃO: a placa sem a silhueta de ninguém (MV_FALSIFICAR=rosto)")
	_as_contas()

	relogio = RelogioDeJogo.new()
	root.add_child(relogio)
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	relogio.ficar_lento()
	vale = current_scene
	jogador = vale.player
	placas = vale.get("placas")
	var dia = root.get_node("/root/Dia")
	dia.pausado = true
	dia.definir_hora(18.0)
	if placas == null:
		_conferir(false, "o vale não montou as placas")
		_fechar()
		return
	camera = jogador.get("camera")
	var fila = vale.get("fila_de_falas")
	if fila != null:
		await relogio.ate(func() -> bool: return fila.livre(), 30.0)
	if falsificar:
		placas.respeita_rostos = false
	var pedro = vale.get("pedro")
	if pedro != null:
		pedro.missao = pedro.MISSOES.size()
		pedro.set("_despedida_feita", true)
		pedro.visible = false
		pedro.process_mode = Node.PROCESS_MODE_DISABLED
	var praca: Vector3 = vale.world.ancoras.get("Praça", jogador.global_position)
	var aqui: Vector3 = vale.world.ground_position(praca + Vector3(3.0, 0.0, 3.0), 0.1)
	jogador.teleportar(aqui, 0.0)
	var livres: Array = []
	for morador in vale.moradores:
		if is_instance_valid(morador) and morador.can_process() and morador.is_visible_in_tree():
			livres.append(morador)
	_conferir(livres.size() >= 4, "só %d moradores no vale; o portão pede 4 ou mais" % livres.size())
	if livres.size() < 4:
		_fechar()
		return
	# Ninguém fala nem anda no meio da medida; quem sobra vai para longe, parado.
	for i in livres.size():
		var morador = livres[i]
		morador.set("_ultima_saudacao_ms", Time.get_ticks_msec())
		morador.set("intervalo_saudacao_ms", 100000000)
		# Sem o "!"/"?" de missão (#216), que também é obstáculo da placa: este portão mede os rostos e a
		# profundidade, e o marcador tem a medida dele em popups_na_tela.
		morador.set("_marcador_em", 1.0e9)
		morador.set("_marcador_texto", "")
		if i >= 3:
			morador.global_position = vale.world.ground_position(aqui + Vector3(0.0, 0.0, -80.0 - 4.0 * float(i)), 0.1)
			morador.process_mode = Node.PROCESS_MODE_DISABLED
	var a: Node3D = livres[0]
	var b: Node3D = livres[1]
	var c: Node3D = livres[2]
	await _quadros(4)
	await _so_estes(livres, aqui)
	# Três postos à frente do jogador, a mais de 5 m (a dica do E não identifica ninguém pelo nome).
	postos = [_chao(aqui, 0.0, 5.5), _chao(aqui, 3.5, 7.0), _chao(aqui, -3.5, 6.5)]

	await _o_rosto_do_dono(a, b, c, aqui)
	await _o_rosto_de_quem_esta_perto(a, b, c, aqui)
	await _a_profundidade(a, b, c, aqui)
	await _sem_piscar(a, b, c, aqui)
	await _praca_cheia(livres, aqui)
	await _em_conversa(livres, aqui)
	_fechar()


# --- 1. AS CONTAS, SEM MUNDO --------------------------------------------------------------------

func _as_contas() -> void:
	var placa := Rect2(100.0, 100.0, 80.0, 26.0)
	var cabeca: Array[Rect2] = [Rect2(110.0, 90.0, 40.0, 50.0)]
	var sobe: float = PlacasNomes.subida_do_rosto(placa, cabeca, 4.0)
	_conferir(absf(sobe - 40.0) <= 0.01, "a placa sobre uma cabeça devia subir 40 px (até 4 px acima dela), subiu %.2f" % sobe)
	var ao_lado: Array[Rect2] = [Rect2(200.0, 90.0, 40.0, 50.0)]
	_conferir(PlacasNomes.subida_do_rosto(placa, ao_lado, 4.0) == 0.0, "uma cabeça ao lado da placa a fez subir")
	var embaixo: Array[Rect2] = [Rect2(110.0, 130.0, 40.0, 50.0)]
	_conferir(PlacasNomes.subida_do_rosto(placa, embaixo, 4.0) == 0.0, "uma cabeça logo abaixo da placa a fez subir")
	var duas: Array[Rect2] = [Rect2(110.0, 90.0, 40.0, 50.0), Rect2(110.0, 40.0, 40.0, 30.0)]
	_conferir(absf(PlacasNomes.subida_do_rosto(placa, duas, 4.0) - 90.0) <= 0.01, "duas cabeças em fila não empilharam a subida: %.2f" % PlacasNomes.subida_do_rosto(placa, duas, 4.0))
	_conferir(PlacasNomes.subida_do_rosto(placa, [] as Array[Rect2], 4.0) == 0.0, "sem rosto nenhum a placa subiu")

	var cheia := Rect2(0.0, 0.0, 100.0, 26.0)
	var corpo := {"no": null, "caixa": Rect2(-20.0, -20.0, 200.0, 100.0), "distancia": 4.0}
	var piso: float = PlacasNomes.ALFA_ATRAS
	var tudo: float = PlacasNomes.alfa_por_profundidade(cheia, 10.0, [corpo], piso)
	_conferir(absf(tudo - piso) <= 0.01, "atrás de um corpo que a cobre inteira, 6 m mais perto, o alfa devia ser o piso %.2f, foi %.2f" % [piso, tudo])
	var quase_junto := {"no": null, "caixa": corpo["caixa"], "distancia": 9.8}
	_conferir(PlacasNomes.alfa_por_profundidade(cheia, 10.0, [quase_junto], piso) >= 0.99, "quem está a 0,2 m da placa a esmaeceu")
	var mais_longe := {"no": null, "caixa": corpo["caixa"], "distancia": 14.0}
	_conferir(PlacasNomes.alfa_por_profundidade(cheia, 10.0, [mais_longe], piso) >= 0.99, "quem está MAIS LONGE que a placa a esmaeceu")
	var no_meio := {"no": null, "caixa": corpo["caixa"], "distancia": 7.0}
	var meio: float = PlacasNomes.alfa_por_profundidade(cheia, 10.0, [no_meio], piso)
	_conferir(meio > piso + 0.05 and meio < 0.99, "a 3 m de diferença o alfa devia estar entre o piso e o cheio, foi %.2f" % meio)
	var a_um_terco := {"no": null, "caixa": Rect2(0.0, 0.0, 100.0, 4.0), "distancia": 4.0}
	var pouca: float = PlacasNomes.alfa_por_profundidade(cheia, 10.0, [a_um_terco], piso)
	_conferir(pouca > tudo + 0.1 and pouca < 0.99, "cobrir 15%% da placa devia esmaecer menos que cobrir tudo: %.2f contra %.2f" % [pouca, tudo])
	var dono := Node3D.new()
	var proprio := {"no": dono, "caixa": corpo["caixa"], "distancia": 4.0}
	_conferir(PlacasNomes.alfa_por_profundidade(cheia, 10.0, [proprio], piso, dono) >= 0.99, "o corpo do próprio dono esmaeceu a placa dele")
	dono.free()
	var importa: float = PlacasNomes.alfa_por_profundidade(cheia, 10.0, [corpo], PlacasNomes.ALFA_ATRAS_DE_QUEM_IMPORTA)
	_conferir(importa > tudo + 0.2, "o piso de quem importa devia ser mais alto que o comum: %.2f contra %.2f" % [importa, tudo])
	print("  contas: sobe %.0f px sobre uma cabeça, %.0f sobre duas; atrás de um corpo o alfa vai a %.2f (%.2f para quem importa)" % [sobe, PlacasNomes.subida_do_rosto(placa, duas, 4.0), tudo, importa])


# --- 2. O ROSTO DO DONO -------------------------------------------------------------------------

func _o_rosto_do_dono(a: Node3D, b: Node3D, c: Node3D, aqui: Vector3) -> void:
	_fixar(a, postos[0])
	_fixar(b, postos[1])
	_fixar(c, postos[2])
	var vistas := 0
	for distancia in [2.2, 6.0, 12.0]:
		await _camera_a(distancia)
		await _esperar(2.0)
		var ligadas := _placas_visiveis()
		vistas += ligadas.size()
		_conferir(ligadas.size() >= 1, "com a câmera a %.1f m nenhuma placa ficou ligada: o portão mediria o vazio (%s)" % [distancia, _porque()])
		var ruins := _rostos_cobertos()
		_conferir(ruins.is_empty(), "com a câmera a %.1f m: %s" % [distancia, "; ".join(ruins)])
	print("  rosto do dono: %d placas conferidas com a câmera perto, média e longe, nenhuma sobre uma cabeça" % vistas)


# --- 3. O ROSTO DE QUEM ESTÁ PERTO --------------------------------------------------------------

func _o_rosto_de_quem_esta_perto(a: Node3D, b: Node3D, c: Node3D, aqui: Vector3) -> void:
	var subiu := 0
	for distancia in [3.0, 6.0, 10.0]:
		await _camera_a(distancia)
		# Só A à vista: a placa dele assenta no lugar de sempre.
		_fixar(a, postos[0])
		_fixar(b, _chao(aqui, 0.0, -80.0))
		_fixar(c, _chao(aqui, 0.0, -84.0))
		await _esperar(2.0)
		var placa: Control = placas._placas[a]
		if not placa.visible:
			_conferir(false, "a placa de %s não acendeu com a câmera a %.1f m: o portão não monta a cena (%s)" % [a.name, distancia, _porque()])
			continue
		# Onde a placa de A cairia sem subir: a conta crua de antes, pela âncora da cabeça.
		var topo_a: Vector3 = a.global_position + Vector3(0.0, placas._altura_real(a) + PlacasNomes.ACIMA_DA_CABECA, 0.0)
		var tamanho: Vector2 = (placas._placas[a] as PanelContainer).get_combined_minimum_size()
		var crua := Rect2(camera.unproject_position(topo_a) - Vector2(tamanho.x * 0.5, tamanho.y), tamanho)
		# B, mais longe, com a cabeça bem onde a placa de A cairia: o rosto dele estaria sob a placa.
		var alvo_na_tela: Vector2 = crua.get_center()
		var fundo := camera.global_position.distance_to(a.global_position) + 4.0
		var altura_b: float = placas._altura_real(b)
		var cabeca := camera.project_ray_origin(alvo_na_tela) + camera.project_ray_normal(alvo_na_tela) * fundo
		_fixar(b, cabeca - Vector3.UP * (altura_b * (1.0 - PlacasNomes.FRACAO_DA_CABECA * 0.5)))
		await _esperar(2.5)
		var cabeca_de_b: Rect2 = PlacasNomes.encolhida(_cabeca_de(b), PlacasNomes.ENCOLHE_DO_ROSTO)
		_conferir(PopupsDoMundo.cobertura(crua, cabeca_de_b) > 20.0,
			"o portão não montou a cena a %.1f m: a placa de A, sem subir (%s), não cobriria a cabeça de B (%s)" % [distancia, str(crua), str(cabeca_de_b)])
		var agora := placa.get_global_rect()
		if placa.visible and placa.modulate.a > 0.05:
			_conferir(PopupsDoMundo.cobertura(agora, cabeca_de_b) <= TOLERANCIA_DE_PX2,
				"com a câmera a %.1f m a placa de A (%s) ficou sobre a cabeça de B (%s)" % [distancia, str(agora), str(cabeca_de_b)])
			_conferir(agora.end.y <= crua.end.y - 2.0, "a placa de A não subiu para liberar a cabeça de B: de y=%.0f para y=%.0f" % [crua.end.y, agora.end.y])
			subiu += 1
		var ruins := _rostos_cobertos()
		_conferir(ruins.is_empty(), "com a câmera a %.1f m: %s" % [distancia, "; ".join(ruins)])
		print("  rosto de outro: a %.1f m a placa de A subiu %.0f px (ou saiu) para liberar a cabeça de B" % [distancia, crua.end.y - agora.end.y if placa.visible else -1.0])
	_conferir(subiu >= 2, "a placa de A só ficou à vista e subiu em %d das 3 distâncias de câmera; o portão espera 2 ou mais" % subiu)


# --- 4. A PROFUNDIDADE --------------------------------------------------------------------------

func _a_profundidade(a: Node3D, b: Node3D, c: Node3D, aqui: Vector3) -> void:
	await _camera_a(8.0)
	_fixar(b, _chao(aqui, 0.0, -80.0))
	_fixar(c, _chao(aqui, 0.0, -84.0))
	# A, perto da câmera (uns 3 m), entre ela e o jogador; C, longe, atrás do jogador por uns 4 m, com a placa
	# sobre o tronco de A.
	var diante := -camera.global_basis.z
	diante.y = 0.0
	diante = diante.normalized()
	var perto_da_camera := camera.global_position + diante * 3.2
	perto_da_camera.y = aqui.y
	_fixar(a, perto_da_camera)
	await _esperar(1.0)
	var altura_a: float = placas._altura_real(a)
	var tronco: Rect2 = PlacasNomes.caixa_na_tela(camera, a.global_position, altura_a * (1.0 - PlacasNomes.FRACAO_DO_TRONCO), altura_a * (1.0 - PlacasNomes.FRACAO_DA_CABECA), PlacasNomes.MEIA_LARGURA_DO_TRONCO)
	_conferir(tronco.size != Vector2.ZERO, "A não está à vista da câmera: o portão não monta a profundidade")
	if tronco.size == Vector2.ZERO:
		return
	var alvo_na_tela: Vector2 = tronco.get_center()
	var colocou := false
	for fundo in [13.0, 12.0, 11.0, 10.0, 9.0]:
		var topo: Vector3 = camera.project_ray_origin(alvo_na_tela) + camera.project_ray_normal(alvo_na_tela) * fundo
		var altura_c: float = placas._altura_real(c)
		# A placa (≈ 26 px) fica logo acima do ponto da cabeça: sobe a cabeça uns centímetros.
		_fixar(c, topo - Vector3.UP * (altura_c + 0.1) - Vector3.UP * 0.1)
		await _quadros(2)
		if c.global_position.distance_to(jogador.global_position) < placas.PLACA_LONGE - 0.5:
			colocou = true
			break
	_conferir(colocou, "não achei onde pôr C, longe e à vista, com a placa sobre o tronco de A")
	if not colocou:
		return
	await _esperar(2.5)
	var placa_c: Control = placas._placas[c]
	_conferir(placa_c.visible, "a placa de C não acendeu atrás de A: o portão não monta a profundidade (%s)" % _porque())
	var atras := float(placas._alfa_atras.get(c, 1.0))
	var sobre_a := PopupsDoMundo.cobertura(placa_c.get_global_rect(), _corpo_de(a)) / maxf(placa_c.get_global_rect().get_area(), 1.0)
	_conferir(sobre_a >= 0.3, "o portão não montou a cena: a placa de C cobre só %.0f%% do corpo de A" % (sobre_a * 100.0))
	var distancia_a := camera.global_position.distance_to(a.global_position)
	var distancia_c := camera.global_position.distance_to(c.global_position)
	_conferir(distancia_c - distancia_a >= 5.0, "C devia estar 5 m mais longe da câmera que A, está a %.1f m" % (distancia_c - distancia_a))
	_conferir(atras <= 0.4, "a placa de C passa sobre A, mais perto, e o alfa da profundidade é %.2f (devia ser transparente)" % atras)
	_conferir(placa_c.modulate.a <= 0.45, "a placa de C passa sobre A e o alfa dela é %.2f" % placa_c.modulate.a)
	print("  profundidade: C a %.1f m da câmera, atrás de A (%.1f m), com %.0f%% da placa sobre ele: alfa %.2f" % [distancia_c, distancia_a, sobre_a * 100.0, atras])
	# A SAI DA FRENTE: o alfa volta ao cheio, aos poucos.
	_fixar(a, _chao(aqui, 6.0, -30.0))
	await _esperar(0.05)
	var primeiro := float(placas._alfa_atras.get(c, 1.0))
	await _esperar(2.0)
	var depois := float(placas._alfa_atras.get(c, 1.0))
	_conferir(depois >= 0.95, "A saiu da frente e o alfa da placa de C continua em %.2f" % depois)
	_conferir(primeiro < 0.95, "a placa de C voltou ao alfa cheio de uma vez, sem fade (%.2f)" % primeiro)


# --- 5. SEM PISCAR ------------------------------------------------------------------------------

func _sem_piscar(a: Node3D, b: Node3D, c: Node3D, aqui: Vector3) -> void:
	await _camera_a(5.0)
	_fixar(a, postos[0])
	_fixar(b, postos[1])
	_fixar(c, postos[2])
	await _esperar(1.5)
	var trocas := 0
	var pior := 0.0
	var maior_salto := 0.0
	var antes := _quem_tem_placa()
	var alfa_antes := _alfas_atras()
	for passo in 90:
		jogador.set("_yaw", float(jogador.get("_yaw")) + deg_to_rad(2.0))
		jogador.call("_apply_camera")
		var comeco: float = relogio.agora()
		await _quadro()
		var dt: float = maxf(relogio.agora() - comeco, 1.0 / 60.0)
		var agora := _quem_tem_placa()
		if agora != antes:
			trocas += 1
			antes = agora
		var alfas := _alfas_atras()
		for chave in alfas.keys():
			var salto := absf(float(alfas[chave]) - float(alfa_antes.get(chave, alfas[chave])))
			# O alfa da profundidade anda no máximo 1/SEGUNDOS_DO_ALFA_ATRAS por segundo de jogo.
			pior = maxf(pior, salto - dt / PlacasNomes.SEGUNDOS_DO_ALFA_ATRAS)
			maior_salto = maxf(maior_salto, salto)
		alfa_antes = alfas
	_conferir(pior <= 0.02, "o alfa da profundidade saltou além do fade num quadro (excesso de %.2f, maior salto %.2f)" % [pior, maior_salto])
	_conferir(trocas <= 8, "girando a câmera 180 graus a vaga das placas trocou %d vezes: piscando" % trocas)
	print("  sem piscar: %d troca(s) de vaga em meia volta, maior salto de alfa por quadro %.3f" % [trocas, maior_salto])


# --- 6. A PRAÇA CHEIA ---------------------------------------------------------------------------

func _praca_cheia(livres: Array, aqui: Vector3) -> void:
	# A volta da câmera de `_sem_piscar` deixou o jogador de costas: de frente para +Z de novo.
	jogador.teleportar(aqui, 0.0)
	# Do centro para fora, para os primeiros moradores ficarem sempre à vista.
	var grade: Array[Vector2] = [Vector2(0.0, 6.8), Vector2(-2.5, 5.5), Vector2(2.5, 5.5), Vector2(-1.5, 8.0), Vector2(1.5, 8.0),
		Vector2(0.0, 9.5), Vector2(-4.5, 6.8), Vector2(4.5, 6.8), Vector2(-4.0, 9.0), Vector2(4.0, 9.0), Vector2(-6.0, 5.5), Vector2(6.0, 5.5)]
	var no_cacho: Array[Node3D] = []
	for i in mini(livres.size(), grade.size()):
		var morador: Node3D = livres[i]
		morador.process_mode = Node.PROCESS_MODE_INHERIT
		_fixar(morador, _chao(aqui, grade[i].x, grade[i].y))
		no_cacho.append(morador)
	_conferir(no_cacho.size() >= 5, "só %d moradores no cacho da praça; o portão pede 5 ou mais" % no_cacho.size())
	# O mais longe do jogador leva a missão.
	var alvo: Node3D = no_cacho[0]
	for morador in no_cacho.slice(0, 6):
		if morador.global_position.distance_to(jogador.global_position) > alvo.global_position.distance_to(jogador.global_position):
			alvo = morador
	var seta = vale.get_node_or_null("SetaMissao")
	var conferidas := 0
	for distancia in [2.5, 6.0, 11.0]:
		await _camera_a(distancia)
		if seta != null:
			seta.definir_alvo(alvo.global_position, "")
		await _esperar(3.0)
		var ligadas := _placas_visiveis()
		conferidas += ligadas.size()
		_conferir(ligadas.size() >= 1 and ligadas.size() <= placas.MAXIMO_DE_PLACAS, "praça cheia com a câmera a %.1f m: %d placas ligadas (de 1 a %d)" % [distancia, ligadas.size(), placas.MAXIMO_DE_PLACAS])
		var ruins := _rostos_cobertos()
		_conferir(ruins.is_empty(), "praça cheia com a câmera a %.1f m: %s" % [distancia, "; ".join(ruins)])
		if seta != null:
			var da_missao: Control = placas._placas[alvo]
			_conferir(da_missao.visible and da_missao.modulate.a > 0.25,
				"praça cheia com a câmera a %.1f m: o alvo da missão (%s, a %.1f m) ficou sem a placa (%s)" % [distancia, alvo.name, alvo.global_position.distance_to(jogador.global_position), _porque()])
	if seta != null:
		seta.limpar()
	print("  praça cheia: %d moradores em cacho, %d placas conferidas com a câmera perto, média e longe, e o alvo da missão (%s) com a dele" % [no_cacho.size(), conferidas, alvo.name])


# --- 7. EM CONVERSA -----------------------------------------------------------------------------

func _em_conversa(livres: Array, aqui: Vector3) -> void:
	var quem: Node3D = livres[0]
	await _camera_a(6.0)
	quem.mostrar_balao("Bom dia, meu filho. Chegue mais perto.", 12.0)
	var falou: bool = await relogio.ate(func() -> bool: return quem.balao.visible and quem.balao.retangulo().size != Vector2.ZERO, 3.0)
	_conferir(falou, "%s não abriu o balão" % quem.name)
	await _esperar(2.5)
	var do_balao: Rect2 = quem.balao.retangulo()
	var ligadas := _placas_visiveis()
	# #218: o balão tem prioridade, e com ele no ar nenhuma placa de nome fica na tela.
	_conferir(ligadas.is_empty(), "com um balão no ar há %d placas de nome na tela; o balão tem prioridade e nenhuma fica" % ligadas.size())
	for dona in ligadas:
		var caixa: Rect2 = (placas._placas[dona] as Control).get_global_rect()
		_conferir(PopupsDoMundo.cobertura(caixa, do_balao) <= TOLERANCIA_DE_PX2, "a placa de %s (%s) fica sob o balão de %s (%s)" % [dona.name, str(caixa), quem.name, str(do_balao)])
	var ruins := _rostos_cobertos()
	_conferir(ruins.is_empty(), "em conversa: %s" % "; ".join(ruins))
	print("  em conversa: %s fala, %d placa(s) ligada(s), nenhuma sob o balão nem sobre uma cabeça" % [quem.name, ligadas.size()])
	quem.mostrar_balao("", 0.0)
	await _esperar(0.6)


# --- apoios -------------------------------------------------------------------------------------

func _cabeca_de(no: Node3D) -> Rect2:
	var altura: float = placas._altura_real(no)
	return PlacasNomes.caixa_na_tela(camera, no.global_position, altura * (1.0 - PlacasNomes.FRACAO_DA_CABECA), altura, PlacasNomes.MEIA_LARGURA_DA_CABECA)


func _corpo_de(no: Node3D) -> Rect2:
	var altura: float = placas._altura_real(no)
	return PlacasNomes.caixa_na_tela(camera, no.global_position, altura * (1.0 - PlacasNomes.FRACAO_DO_TRONCO), altura, PlacasNomes.MEIA_LARGURA_DO_TRONCO)


## Os personagens que podem ter cabeça na tela: os moradores com placa e o jogador.
func _personagens() -> Array:
	var todos: Array = placas._placas.keys()
	todos.append(jogador)
	return todos


## As placas que o jogador vê agora (ligadas e acesas o bastante).
func _placas_visiveis() -> Array:
	var saida: Array = []
	for morador in placas._placas.keys():
		var placa: Control = placas._placas[morador]
		if placa.visible and placa.modulate.a > 0.05:
			saida.append(morador)
	return saida


## As placas acesas que cobrem a cabeça de algum personagem, em texto.
func _rostos_cobertos() -> Array:
	var ruins: Array = []
	for dona in _placas_visiveis():
		var caixa: Rect2 = (placas._placas[dona] as Control).get_global_rect()
		for quem in _personagens():
			if not is_instance_valid(quem) or not (quem as Node3D).is_visible_in_tree():
				continue
			var cabeca: Rect2 = PlacasNomes.encolhida(_cabeca_de(quem as Node3D), PlacasNomes.ENCOLHE_DO_ROSTO)
			if cabeca.size == Vector2.ZERO:
				continue
			var coberta := PopupsDoMundo.cobertura(caixa, cabeca)
			if coberta > TOLERANCIA_DE_PX2:
				ruins.append("a placa de %s (%s) cobre %.0f px² da cabeça de %s (%s)" % [dona.name, str(caixa), coberta, quem.name, str(cabeca)])
	return ruins


func _alfas_atras() -> Dictionary:
	var saida := {}
	for morador in placas._placas.keys():
		if (placas._placas[morador] as Control).visible:
			saida[morador] = float(placas._alfa_atras.get(morador, 1.0))
	return saida


func _quem_tem_placa() -> String:
	var nomes: Array[String] = []
	for morador in _placas_visiveis():
		nomes.append(str(morador.name))
	nomes.sort()
	return ",".join(nomes)


## O estado que explica placa apagada: o que o portão não controla.
func _porque() -> String:
	var partes: Array[String] = ["permitido %s, mostrar_nomes %s, câmera do jogo %s" % [str(placas._permitido), str(root.get_node("/root/Estilo").mostrar_nomes), str(camera == jogador.get("camera"))]]
	for no in fixos.keys():
		if is_instance_valid(no):
			partes.append("%s a %.1f m (visível %s, nome %s, vaga %s, alfa %.2f)" % [no.name, no.global_position.distance_to(jogador.global_position),
				str(no.is_visible_in_tree()), str(no.nome_label.is_visible_in_tree()), str(placas._vaga.has(no)), float(placas._alfa.get(no, 0.0))])
	for no in fixos.keys():
		if is_instance_valid(no) and no.global_position.y > -200.0 and no.global_position.distance_to(jogador.global_position) < 20.0:
			var topo: Vector3 = no.global_position + Vector3(0.0, placas._altura_real(no) + PlacasNomes.ACIMA_DA_CABECA, 0.0)
			var tam: Vector2 = (placas._placas[no] as PanelContainer).get_combined_minimum_size()
			var ancora: Vector2 = camera.unproject_position(topo)
			var caixa := Rect2(ancora - Vector2(tam.x * 0.5, tam.y), tam)
			var rostos: Array[Rect2] = []
			for personagem in _personagens():
				if is_instance_valid(personagem) and (personagem as Node3D).is_visible_in_tree():
					var r: Rect2 = _cabeca_de(personagem as Node3D)
					if r.size != Vector2.ZERO:
						rostos.append(PlacasNomes.encolhida(r, PlacasNomes.ENCOLHE_DO_ROSTO))
			partes.append("%s: visível p/ câmera %s, identificado %s, âncora %s, caixa %s, sobe %.0f, cabeças %d, jogador %s" % [no.name,
				str(placas._visivel_para_camera(no, camera)), str(placas._nome_ja_identificado(no)), str(ancora), str(caixa),
				PlacasNomes.subida_do_rosto(caixa, rostos, PlacasNomes.FOLGA_DO_ROSTO), rostos.size(), str(jogador.global_position)])
	return "; ".join(partes)


func _camera_a(distancia: float) -> void:
	jogador.set("_distance", distancia)
	jogador.call("_apply_camera")
	await _quadros(2)


## O chão a (dx, dz) metros de `aqui`: o morador posto no ar ou sob o relevo não é visto pela câmera.
func _chao(aqui: Vector3, dx: float, dz: float) -> Vector3:
	return vale.world.ground_position(aqui + Vector3(dx, 0.0, dz), 0.1)


## Só estes ficam na cena: os outros moradores (que andam por conta do dia, e a Beata passa na frente da câmera
## no meio da medida) vão para longe, parados.
func _so_estes(ficam: Array, aqui: Vector3) -> void:
	for morador in vale.moradores:
		if not is_instance_valid(morador) or ficam.has(morador):
			continue
		morador.process_mode = Node.PROCESS_MODE_DISABLED
		morador.global_position = _chao(aqui, 0.0, -120.0)
		fixos[morador] = morador.global_position


func _fixar(morador: Node3D, onde: Vector3) -> void:
	fixos[morador] = onde
	# Quem o portão põe na cena conta como visto pela câmera: a parede da praça entre a câmera e o morador é
	# assunto da oclusão (`_visivel_para_camera`), e não da placa sobre o rosto.
	placas._oclusao[morador] = {"visivel": true, "candidato": true, "desde": 0.0, "proxima": 1.0e12}
	morador.ir_ate(onde, 1.0)
	morador.global_position = onde


func _quadro() -> void:
	for morador in fixos.keys():
		if is_instance_valid(morador):
			morador.global_position = fixos[morador]
			morador.velocity = Vector3.ZERO
	await process_frame


func _esperar(segundos: float) -> void:
	var ate: float = relogio.agora() + segundos
	var guarda := Time.get_ticks_msec() + int(maxf(segundos * 12.0, 60.0) * 1000.0)
	while relogio.agora() < ate and Time.get_ticks_msec() < guarda:
		await _quadro()


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("PLACAS_SEM_ROSTO_OK: a placa sobe só o que falta para liberar uma cabeça e esmaece só por quem está mais perto da câmera e que ela cobre; com a câmera perto, média e longe nenhuma placa cai no rosto do dono nem de quem está atrás; a cabeça de outro posta sob a placa a faz subir; a placa de quem está longe, sobre o tronco de quem está perto, fica transparente e volta ao cheio quando ele sai da frente; e girando a câmera a vaga não pisca")
	else:
		print("placas_sem_rosto: %d falha(s)" % falhas)
	quit(1 if falhas > 0 else 0)


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
