extends "res://tests/suite/caso.gd"
## OS PAVÕES NÃO PISCAM (#193): o jogador anda e corre pela estrada da igreja, de 110 u
## do adro até colado nele e de volta, com a câmera atrás, girada para a frente e longe,
## e o gerente dos bichos de casa e a apresentação do povoado decidem a cada quadro quem
## se vê. O portão registra QUADRO A QUADRO a opacidade de cada malha de cada ave (e de
## cada bicho de quatro patas) e reprova:
##
##   1. UM CORTE SECO À VISTA: a opacidade da malha dá um salto maior que 0,3 num quadro.
##      A opacidade é o que o script decide (`visible` na árvore, `transparency` da
##      apresentação) vezes o fade do motor pelo alcance da própria malha
##      (`visibility_range_fade_mode`), que é contínuo; o que pisca é o script.
##   2. UM BURACO NA TROCA DO LEQUE: um quadro em que o pavão tem os dois modelos, o
##      normal e o de cauda aberta, invisíveis ao mesmo tempo.
##   3. PISCAR: uma ave que liga e desliga mais de duas vezes numa travessia só.
##
##   .\tools\prototipo_3d\testar.ps1 -Teste aves_sem_piscar
##   ... -- --falsificar-corte   volta ao corte de antes: `bando.visible` pela distância do
##                               CENTRO do terreiro a 80 u, sem o fade. O portão TEM de reprovar.
##   ... -- --sem-leque          não abre nem fecha o leque (só para medir o resto).

## Recebe o vale montado do zero: reprovava no vale deixado pelos casos anteriores (a suíte, #242).
const VALE_NOVO := true

## O maior salto de opacidade que um quadro pode dar: o fade do motor e o da apresentação
## (0,8 s) andam poucos centésimos por quadro; passar de 0 a 1 de uma vez é o pisca.
const SALTO_MAXIMO := 0.3
const PASSO_CAMINHANDO := 4.5
const PASSO_CORRENDO := 9.0
const DE_LONGE := 110.0
const ATE_PERTO := 6.0

var falhas := 0
var verificacoes := 0
var _falsificar := false
var _vale: Node
var _camera: Camera3D
var _gerente: Node
## id da malha → {opaco: bool, ligadas: int, bicho: String}
var _estado: Dictionary = {}
var _quadros := 0
var _cortes_secos := 0
var _piores := ""
var _maior_distancia_do_corte := 0.0
## Quantas vezes algum ator entrou ou saiu de cena durante as travessias, e quantos
## quadros o leque do pavão ficou aberto: sem isso o portão passaria sem exercitar nada.
var _entradas_e_saidas := 0
var _quadros_de_leque := 0


func _initialize() -> void:
	_run.call_deferred()
	create_timer(900.0).timeout.connect(func() -> void:
		print("FALHA: tempo esgotado")
		quit(2))


func _conferir(ok: bool, texto: String) -> void:
	verificacoes += 1
	if not ok:
		falhas += 1
		print("FALHA: ", texto)


func _run() -> void:
	_falsificar = "--falsificar-corte" in OS.get_cmdline_user_args()
	# 60 quadros por segundo no relógio da tela e o dobro no do jogo (cada quadro vale 1/30 s):
	# a metade do tempo de parede, e o pior caso de quadro lento para o corte de distância.
	Engine.max_fps = 60
	Engine.time_scale = 2.0
	await process_frame
	change_scene_to_file("res://scenes/prototipo_3d/vale.tscn")
	await process_frame
	while current_scene == null or current_scene.get("carga_ok") != true:
		await process_frame
	_vale = current_scene
	var dia := root.get_node("Dia")
	dia.pausado = true
	# 08:51, a hora do relato.
	dia.definir_hora(8.85)
	_vale.player.set_physics_process(false)
	for i in 3000:
		_gerente = _vale.get_node_or_null("BichosDeCasa")
		if _gerente != null and _gerente.bandos.size() > 0 and _gerente.bichos.size() > 0:
			break
		await process_frame
	_conferir(_gerente != null, "o vale não criou o BichosDeCasa")
	if _gerente == null:
		_fechar()
		return
	var adro = null
	for bando in _gerente.bandos:
		if bando.casa == "Igreja":
			adro = bando
	_conferir(adro != null and adro._o_pavao().size() > 0, "o adro da Igreja não tem o pavão")
	if adro == null:
		_fechar()
		return
	_camera = Camera3D.new()
	_vale.add_child(_camera)
	_camera.make_current()
	for i in 20:
		await process_frame
	var centro: Vector3 = adro.centro
	var rumo := _rumo_da_estrada(centro)
	print("AVES: adro em %s, rumo da estrada %s" % [str(centro.snapped(Vector3.ONE * 0.1)), str(rumo.snapped(Vector3.ONE * 0.01))])
	var passadas := [
		["a pé, câmera atrás", PASSO_CAMINHANDO, "atras"],
		["correndo, câmera atrás", PASSO_CORRENDO, "atras"],
		["a pé, câmera à frente", PASSO_CAMINHANDO, "frente"],
		["correndo, câmera longe e alta", PASSO_CORRENDO, "longe"],
	]
	for passada in passadas:
		_estado.clear()
		await _atravessar(adro, centro, rumo, float(passada[1]), String(passada[2]), String(passada[0]))
	_conferir(_entradas_e_saidas >= 8, "as travessias exercitaram a entrada e a saída de cena (%d trocas)" % _entradas_e_saidas)
	_conferir(_quadros_de_leque > 100, "o leque do pavão ficou aberto durante a travessia (%d quadros)" % _quadros_de_leque)
	print("AVES: %d quadros, %d cortes secos, maior distância de um corte %.1f u" % [_quadros, _cortes_secos, _maior_distancia_do_corte])
	_fechar()


## A direção, a partir do adro, da rua mais próxima que se afasta dele (a estrada da
## igreja); sem rua, para o centro da praça.
func _rumo_da_estrada(centro: Vector3) -> Vector3:
	var regiao = _vale.world.get("_region")
	var melhor := Vector3.ZERO
	var menor := INF
	if regiao != null:
		for rota: Dictionary in regiao.get("_roads"):
			var pontos: PackedVector2Array = rota.points
			for i in pontos.size():
				var d := Vector2(centro.x, centro.z).distance_to(pontos[i])
				if d > 30.0 and d < menor and String(rota.get("name", "")).contains("Igreja"):
					menor = d
					melhor = Vector3(pontos[i].x - centro.x, 0.0, pontos[i].y - centro.z)
	if melhor == Vector3.ZERO:
		var praca: Vector3 = _vale.world.ancoras.get("Praça", centro + Vector3.RIGHT * 50.0)
		melhor = Vector3(praca.x - centro.x, 0.0, praca.z - centro.z)
	return melhor.normalized()


func _atravessar(adro, centro: Vector3, rumo: Vector3, passo: float, camera_em: String, nome: String) -> void:
	# Ida (de longe até perto) e volta: a ave entra e sai de cena.
	for sentido in [1, -1]:
		var distancia := DE_LONGE if sentido == 1 else ATE_PERTO
		# Aquecimento: o jogador chega ao ponto de partida e a apresentação do povoado e o
		# gerente dos bichos assentam (quem aparece por ter chegado ali não conta).
		for i in 150:
			_por_o_jogador(centro, rumo, distancia, camera_em)
			await process_frame
		_estado.clear()
		var leque_abre_em := [70.0, 62.0]
		var anterior := Time.get_ticks_usec()
		while (sentido == 1 and distancia > ATE_PERTO) or (sentido == -1 and distancia < DE_LONGE):
			await process_frame
			var agora := Time.get_ticks_usec()
			var dt := minf(float(agora - anterior) / 1000000.0 * Engine.time_scale, 0.1)
			anterior = agora
			distancia -= sentido * passo * dt
			_por_o_jogador(centro, rumo, distancia, camera_em)
			if _falsificar:
				# O corte de antes: o bando inteiro pela distância do centro, a 80 u, sem fade.
				var olho := _camera.global_position
				adro.visible = Vector2(centro.x - olho.x, centro.z - olho.z).length() < 80.0
			if "--sem-leque" not in OS.get_cmdline_user_args() and sentido == 1:
				if not leque_abre_em.is_empty() and distancia < float(leque_abre_em[0]):
					leque_abre_em.pop_front()
					adro.abrir_leque()
				if adro.leque_aberto() and distancia < 40.0:
					adro.fechar_leque()
			_registrar(nome)
	_conferir(true, "%s: travessia registrada" % nome)


func _por_o_jogador(centro: Vector3, rumo: Vector3, distancia: float, camera_em: String) -> void:
	var no_chao: Vector3 = _vale.world.ground_position(centro + rumo * distancia, 0.1)
	_vale.player.global_position = no_chao
	_vale.player.velocity = Vector3.ZERO
	_por_a_camera(no_chao, rumo, camera_em)


func _por_a_camera(jogador: Vector3, rumo: Vector3, onde: String) -> void:
	# O rumo aponta do adro para fora: quem vem de longe olha para o adro (-rumo).
	var para_o_adro := -rumo
	match onde:
		"atras":
			_camera.global_position = jogador - para_o_adro * 8.0 + Vector3(0.0, 5.0, 0.0)
		"frente":
			_camera.global_position = jogador + para_o_adro * 14.0 + Vector3(0.0, 6.0, 0.0)
		_:
			_camera.global_position = jogador + Vector3(rumo.z, 0.0, -rumo.x) * 25.0 + Vector3(0.0, 22.0, 0.0)
	_camera.look_at(jogador + Vector3.UP)


## Um quadro: a opacidade de cada ave e de cada bicho, e o que mudou desde o quadro anterior.
## O ator vale pela malha MAIS opaca dele: a troca do pavão para o leque, ou do cão em pé
## para o deitado, apaga um modelo e acende o outro no mesmo quadro, e isso não é piscar.
func _registrar(nome: String) -> void:
	_quadros += 1
	for bando in _gerente.bandos:
		if bando.leque_aberto():
			_quadros_de_leque += 1
	var olho := _camera.global_position
	var Animador = load("res://scripts/prototipo_3d/animador_bicho.gd")
	for bando in _gerente.bandos:
		for ave: Dictionary in bando.aves:
			var modelos: Array = [ave["modelo"]]
			if ave.has("modelo_leque"):
				modelos.append(ave["modelo_leque"])
			var malhas: Array = []
			for modelo: Node3D in modelos:
				malhas.append_array(Animador.malhas(modelo))
			_comparar_ator(ave["no"].get_instance_id(), malhas, olho, "%s da %s (%s)" % [ave["chave"], bando.casa, nome])
			# O leque: se a ave está à vista (o nó dela), um dos modelos está.
			if ave.has("modelo_leque") and ave["no"].is_visible_in_tree():
				if not ave["modelo"].visible and not ave["modelo_leque"].visible:
					_conferir(false, "%s: buraco na troca do leque (nenhum dos dois modelos aparece)" % nome)
	for bicho in _gerente.bichos:
		if is_instance_valid(bicho):
			_comparar_ator(bicho.get_instance_id(), Animador.malhas(bicho), olho, "%s da %s (%s)" % [bicho.chave, bicho.casa, nome])


## A opacidade de uma malha agora: o que o script decide (`visible` na árvore, e
## `transparency`, que a apresentação do povoado leva a zero em 0,8 s ao mostrar) vezes o
## fade do motor pelo alcance da própria malha (`visibility_range_end` e a margem dela).
func _opacidade(malha: GeometryInstance3D, olho: Vector3) -> Array:
	var script_alpha := (1.0 - malha.transparency) if malha.is_visible_in_tree() else 0.0
	var distancia := olho.distance_to(malha.global_transform * malha.get_aabb().get_center())
	var alpha_do_motor := 1.0
	if malha.visibility_range_end > 0.0:
		alpha_do_motor = 1.0 - clampf((distancia - malha.visibility_range_end) / maxf(malha.visibility_range_end_margin, 0.001), 0.0, 1.0)
	return [script_alpha * alpha_do_motor, script_alpha, distancia]


func _comparar_ator(id: int, malhas: Array, olho: Vector3, quem: String) -> void:
	var opaco := 0.0
	var script_alpha := 0.0
	var distancia := INF
	for malha: GeometryInstance3D in malhas:
		var o := _opacidade(malha, olho)
		opaco = maxf(opaco, float(o[0]))
		script_alpha = maxf(script_alpha, float(o[1]))
		distancia = minf(distancia, float(o[2]))
	if not _estado.has(id):
		_estado[id] = {"opaco": opaco, "aparece": script_alpha > 0.0, "trocas": 0}
		return
	var e: Dictionary = _estado[id]
	var antes: float = e["opaco"]
	e["opaco"] = opaco
	var aparece := script_alpha > 0.0
	if aparece != e["aparece"]:
		e["aparece"] = aparece
		_entradas_e_saidas += 1
		e["trocas"] = int(e["trocas"]) + 1
		if int(e["trocas"]) == 5:
			_conferir(false, "%s liga e desliga mais de duas vezes numa travessia (piscando)" % quem)
	if absf(opaco - antes) > SALTO_MAXIMO:
		_cortes_secos += 1
		_maior_distancia_do_corte = maxf(_maior_distancia_do_corte, distancia)
		_conferir(false, "%s %s de repente (%.2f para %.2f num quadro) a %.1f u da câmera" % [quem, "apareceu" if opaco > antes else "sumiu", antes, opaco, distancia])


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("AVES_SEM_PISCAR_OK: %d verificações em %d quadros — nenhuma ave nem bicho de casa liga ou desliga à vista quando o jogador anda ou corre pela estrada da igreja, com a câmera atrás, à frente e longe, e o pavão troca para o leque sem buraco" % [verificacoes, _quadros])
	else:
		print("aves_sem_piscar: %d falha(s) em %d verificações" % [falhas, verificacoes])
	quit(1 if falhas > 0 else 0)
