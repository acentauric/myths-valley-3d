extends SceneTree
## AS LÁPIDES ESTÃO NO CHÃO, NO SEU LUGAR, TODAS PARA O MESMO LADO.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/lapides_no_chao.gd
##
## "As lápides estão mal posicionadas, precisamos ajustar." A grade de 4 x 3 era a das
## lajes procedurais (compridas em Z); a do Tripo é comprida em X, com a cruz no -X, e
## sem giro as lajes ficavam de ponta com ponta, a 0,6 e 0,86 u uma da outra, com a
## base na altura do centro (uma ponta no ar) e dois pés de capim dentro de laje.
## Oito perguntas, nos dois estilos (`lapides_no_chao_procedural.gd`):
##
##   1. SÃO DOZE, e `lapides`, `lapides_pegada`, `tumulos` e as histórias de
##      `data/lapides_3d.json` têm o mesmo tamanho (a ordem é a das histórias).
##   2. TODAS PARA O MESMO LADO: o comprimento da laje corre leste-oeste e a cruz
##      (cabeceira) fica a oeste, em todas, dentro da tolerância do desvio de guinada.
##   3. DENTRO DO CERCADO que a missão do Damião levanta (`MEIO_LADO`), com folga.
##   4. SEM SE ENCOSTAR: o vão entre duas lajes da mesma fileira e o corredor entre duas
##      fileiras cabem o jogador (a cápsula tem 0,56 u).
##   5. NO CHÃO: a base de cada laje nos quatro cantos, medida com raio contra o chão
##      de verdade (a malha que o corpo pisa, e não a fórmula), não paira a mais de 8
##      cm nem afunda a mais de 15 cm.
##   6. NADA DENTRO DE LAJE: os pés de capim, as embaúbas, as pedras e as galhadas de
##      `data/recursos_3d.json`, e os postos do Damião, do padre e do sacristão de
##      `data/npcs_3d.json`, ficam a mais da folga de cada um de toda laje.
##   7. A PORTA DA CAPELINHA OLHA UM CORREDOR: nenhuma laje na faixa que sai da porta
##      para dentro do cemitério, e a capelinha não encosta em laje.
##   8. SE ANDA ENTRE ELAS: uma cápsula do jogador, de pé no meio de cada vão, de
##      cada corredor e da faixa da porta, não toca em nada (consulta de física).
##
## FALSIFICAÇÃO: com a grade antiga (4 x 3 a 2,3 x 3,0, a laje do Tripo sem giro) reprova
## o 4 (vão de 0,6 u), o 6 (capim e posto dentro de laje) e o 7 (laje na frente da
## porta); com a base no centro (`BASE_ENTRE_OS_CANTOS` = 1, sem afundar), o 5.

## O quanto a laje pode pairar sobre o chão, e afundar nele, nos cantos (u).
const PAIRA_MAXIMO := 0.08
const AFUNDA_MAXIMO := 0.15
## Folga mínima (u) entre duas lajes da mesma fileira e entre duas fileiras.
const VAO_MINIMO := 0.85
const CORREDOR_MINIMO := 1.2
## Folga do cercado: a laje fica a pelo menos isto da linha da cerca (u).
const FOLGA_DO_CERCADO := 2.0
## A cápsula do jogador (a de `player_controller`: raio e altura).
const RAIO_DO_CORPO := 0.28
const ALTURA_DO_CORPO := 1.6
## A faixa que sai da porta da capelinha: meia largura (u).
const MEIA_FAIXA_DA_PORTA := 0.5
## Até onde a laje pode ficar da capelinha (u), no mínimo.
const FOLGA_DA_CAPELINHA := 3.0
## O raio que cada coisa do cemitério pede livre em volta da laje (u).
const RAIO_DO_QUE_MORA := {"capim": 0.65, "embauba": 0.4, "pedra_solta": 0.35, "tronco_caido": 1.4}
const RAIO_DO_POSTO := 0.5

var falhas := 0
var vale
var world
var pegadas: Array[Rect2] = []


## O estilo do vale em que o portão roda: `lapides_no_chao_procedural.gd` o troca.
func _estilo_do_portao() -> String:
	return "tripo"


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("LAPIDES_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	create_timer(900.0).timeout.connect(func() -> void:
		push_error("LAPIDES_NO_CHAO: limite de 900 segundos excedido")
		quit(2))
	root.get_node("/root/Estilo").modo = _estilo_do_portao()
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(10)
	vale = current_scene
	world = vale.get("world")
	if world == null or not world.ancoras.has("Cemitério"):
		_conferir(false, "o vale não montou o mundo e o cemitério")
		_fechar()
		return
	var jogador = vale.get("player")
	if jogador != null:
		jogador.set_physics_process(false)
	# O chão tem de estar no espaço da física antes de qualquer raio.
	for i in 6:
		await physics_frame
	_quantas()
	var cemiterio := get_first_node_in_group("cemiterio")
	_pontas_no_ar(cemiterio)
	# As três lajes que a raiz levantou começam tortas (missão do Damião); o resto do
	# portão mede a laje reta, que é como ela fica assentada.
	if cemiterio != null:
		cemiterio._entortar(false)
	_para_o_mesmo_lado()
	_dentro_do_cercado()
	_sem_se_encostar()
	_no_chao()
	_nada_dentro_de_laje()
	_porta_da_capelinha()
	_se_anda_entre_elas()
	_fechar()


## As lajes tortas levantam uma PONTA (a do comprimento), e não rolam de lado: o eixo
## de levantar é o curto da laje de cada estilo, mesmo com a laje girada na fileira.
func _pontas_no_ar(cemiterio: Node) -> void:
	print("")
	print("2b. as lajes tortas levantam uma ponta")
	if cemiterio == null:
		print("   (sem o nó do cemitério: o jogo não montou a missão do Damião)")
		return
	var tortas: Array = cemiterio.lajes_tortas()
	_conferir(tortas.size() == 3, "três lajes começam tortas (%d)" % tortas.size())
	for indice in tortas:
		var tumulo: Node3D = world.tumulos[indice]
		var base := tumulo.global_transform.basis
		var comprida := base.x if tumulo.has_meta("limites") else base.z
		var curta := base.z if tumulo.has_meta("limites") else base.x
		_conferir(absf(comprida.y) > 0.15, "laje %d torta: uma ponta no ar (a comprida sobe %.2f)" % [indice, comprida.y])
		_conferir(absf(curta.y) < 0.05, "laje %d torta: não rola de lado (a curta sobe %.2f)" % [indice, curta.y])


## O retângulo da laje `i` nos eixos do mundo: centro e pegada que o corpo sólido usa.
func _retangulo(i: int) -> Rect2:
	var centro: Vector3 = world.lapides[i]
	var pegada: Vector3 = world.lapides_pegada[i]
	return Rect2(Vector2(centro.x - pegada.x * 0.5, centro.z - pegada.z * 0.5), Vector2(pegada.x, pegada.z))


func _distancia_ao_retangulo(p: Vector2, r: Rect2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, p.x - r.end.x), 0.0)
	var dz := maxf(maxf(r.position.y - p.y, p.y - r.end.y), 0.0)
	return Vector2(dx, dz).length()


# --- 1. SÃO DOZE ----------------------------------------------------------------

func _quantas() -> void:
	print("")
	print("1. as doze covas")
	var historias = JSON.parse_string(FileAccess.get_file_as_string("res://data/lapides_3d.json"))
	var quantas_historias: int = (historias["lapides"] as Array).size() if historias is Dictionary else -1
	var layout = load("res://scripts/prototipo_3d/cemiterio_layout.gd")
	_conferir(world.lapides.size() == quantas_historias, "uma laje para cada história (%d lajes, %d histórias)" % [world.lapides.size(), quantas_historias])
	_conferir(world.lapides.size() == layout.quantas(), "o layout põe %d covas e o mundo tem %d" % [layout.quantas(), world.lapides.size()])
	_conferir(world.lapides_pegada.size() == world.lapides.size() and world.tumulos.size() == world.lapides.size(), "lapides, pegadas e túmulos têm o mesmo tamanho")
	pegadas.clear()
	for i in world.lapides.size():
		_conferir(is_instance_valid(world.tumulos[i]), "o túmulo %d existe" % i)
		pegadas.append(_retangulo(i))


# --- 2. TODAS PARA O MESMO LADO -----------------------------------------------------

func _para_o_mesmo_lado() -> void:
	print("")
	print("2. todas para o mesmo lado")
	var tolerancia := cos(0.12)
	for i in world.tumulos.size():
		var tumulo: Node3D = world.tumulos[i]
		var do_tripo := tumulo.has_meta("limites")
		var base := tumulo.global_transform.basis
		# No Tripo a laje é comprida em X (a cruz no -X); na procedural, em Z (a cruz no -Z).
		var cabeceira := -base.x if do_tripo else -base.z
		# Só o rumo no chão conta: a laje torta (a missão do Damião) levanta uma ponta.
		cabeceira = Vector3(cabeceira.x, 0.0, cabeceira.z).normalized()
		_conferir(cabeceira.dot(Vector3.LEFT) > tolerancia, "laje %d: a cabeceira (a cruz) fica a oeste (%.2f)" % [i, cabeceira.dot(Vector3.LEFT)])
		var pegada: Vector3 = world.lapides_pegada[i]
		_conferir(pegada.x > pegada.z, "laje %d: o comprimento corre leste-oeste (%.2f x %.2f)" % [i, pegada.x, pegada.z])


# --- 3. DENTRO DO CERCADO -----------------------------------------------------------

func _dentro_do_cercado() -> void:
	print("")
	print("3. dentro do cercado")
	var cemiterio = load("res://scripts/prototipo_3d/cemiterio_vale.gd")
	var centro: Vector3 = world.ancoras["Cemitério"]
	var lado: float = cemiterio.MEIO_LADO
	for i in pegadas.size():
		var r := pegadas[i]
		var dentro := absf(r.position.x - centro.x) <= lado - FOLGA_DO_CERCADO and absf(r.end.x - centro.x) <= lado - FOLGA_DO_CERCADO \
			and absf(r.position.y - centro.z) <= lado - FOLGA_DO_CERCADO and absf(r.end.y - centro.z) <= lado - FOLGA_DO_CERCADO
		_conferir(dentro, "laje %d dentro do cercado de %.1f u, com %.1f u de folga" % [i, lado, FOLGA_DO_CERCADO])


# --- 4. SEM SE ENCOSTAR -------------------------------------------------------------

func _sem_se_encostar() -> void:
	print("")
	print("4. sem se encostar")
	var menor_vao := INF
	var menor_corredor := INF
	for i in pegadas.size():
		for j in range(i + 1, pegadas.size()):
			var a := pegadas[i]
			var b := pegadas[j]
			var vao_x := maxf(b.position.x - a.end.x, a.position.x - b.end.x)
			var vao_z := maxf(b.position.y - a.end.y, a.position.y - b.end.y)
			_conferir(vao_x > 0.0 or vao_z > 0.0, "laje %d e laje %d se sobrepõem" % [i, j])
			var mesma_fileira := absf((a.get_center().y) - (b.get_center().y)) < 0.8
			var fileira_vizinha := not mesma_fileira and absf((a.get_center().x) - (b.get_center().x)) < 1.4
			if mesma_fileira:
				menor_vao = minf(menor_vao, vao_x)
				_conferir(vao_x >= VAO_MINIMO, "lajes %d e %d, da mesma fileira, a %.2f u uma da outra (o mínimo é %.2f)" % [i, j, vao_x, VAO_MINIMO])
			elif fileira_vizinha and vao_z < 2.0:
				menor_corredor = minf(menor_corredor, vao_z)
				_conferir(vao_z >= CORREDOR_MINIMO, "lajes %d e %d, de fileiras vizinhas, a %.2f u (o corredor mínimo é %.2f)" % [i, j, vao_z, CORREDOR_MINIMO])
	print("   menor vão na fileira: %.2f u; menor corredor entre fileiras: %.2f u" % [menor_vao, menor_corredor])


# --- 5. NO CHÃO ---------------------------------------------------------------------

func _no_chao() -> void:
	print("")
	print("5. no chão")
	var espaco: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	# Fora do raio: o corpo sólido de cada laje (`_colisao_tumulo`, um StaticBody3D filho do
	# mundo no pé da laje; o Godot renomeia o repetido, então a busca é pela posição).
	var fora: Array[RID] = []
	for filho in world.get_children():
		if not (filho is StaticBody3D):
			continue
		for centro: Vector3 in world.lapides:
			if Vector2(filho.position.x - centro.x, filho.position.z - centro.z).length() < 0.02:
				fora.append((filho as StaticBody3D).get_rid())
				break
	_conferir(fora.size() == world.lapides.size(), "cada laje tem o corpo sólido dela (%d corpos para %d lajes)" % [fora.size(), world.lapides.size()])
	var pior_paira := -INF
	var pior_afunda := -INF
	var medidos := 0
	for i in world.tumulos.size():
		var tumulo: Node3D = world.tumulos[i]
		var caixa := CatalogoAssets.limites(tumulo) if tumulo.has_meta("limites") else AABB(Vector3(-0.36, 0.0, -0.725), Vector3(0.72, 0.15, 1.45))
		for sx in [0.0, 1.0]:
			for sz in [0.0, 1.0]:
				var canto := Vector3(caixa.position.x + caixa.size.x * sx, caixa.position.y, caixa.position.z + caixa.size.z * sz)
				var no_mundo := tumulo.global_transform * canto
				var consulta := PhysicsRayQueryParameters3D.create(no_mundo + Vector3(0, 2.0, 0), no_mundo - Vector3(0, 2.0, 0), 1)
				consulta.exclude = fora
				var achou := espaco.intersect_ray(consulta)
				if achou.is_empty():
					_conferir(false, "laje %d: o raio do canto %s não achou chão" % [i, str(no_mundo)])
					continue
				medidos += 1
				var chao_y := float((achou["position"] as Vector3).y)
				var paira := no_mundo.y - chao_y
				pior_paira = maxf(pior_paira, paira)
				pior_afunda = maxf(pior_afunda, -paira)
				_conferir(paira <= PAIRA_MAXIMO, "laje %d paira %.3f u sobre o chão no canto %s (o máximo é %.2f)" % [i, paira, str(canto), PAIRA_MAXIMO])
				_conferir(-paira <= AFUNDA_MAXIMO, "laje %d afunda %.3f u no chão no canto %s (o máximo é %.2f)" % [i, -paira, str(canto), AFUNDA_MAXIMO])
	_conferir(medidos == world.tumulos.size() * 4, "os quatro cantos de cada laje foram medidos (%d de %d)" % [medidos, world.tumulos.size() * 4])
	print("   pior canto no ar: %.3f u; pior canto enterrado: %.3f u" % [pior_paira, pior_afunda])


# --- 6. NADA DENTRO DE LAJE --------------------------------------------------------

## Tudo o que mora no cemitério, relativo ao centro dele: [{"nome", "ponto" (mundo), "raio"}].
func _moradores_do_cemiterio() -> Array[Dictionary]:
	var centro: Vector3 = world.ancoras["Cemitério"]
	var lista: Array[Dictionary] = []
	var recursos = JSON.parse_string(FileAccess.get_file_as_string("res://data/recursos_3d.json"))
	_varrer(recursos, "", centro, lista)
	var npcs = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs_3d.json"))
	_varrer(npcs, "", centro, lista)
	return lista


func _varrer(no: Variant, caminho: String, centro: Vector3, lista: Array[Dictionary]) -> void:
	if no is Dictionary:
		var d: Dictionary = no
		if str(d.get("lugar", "")) == "cemiterio" and d.has("desvio"):
			var desvio: Array = d["desvio"]
			lista.append({"nome": str(d.get("id", caminho)), "ponto": Vector2(centro.x + float(desvio[0]), centro.z + float(desvio[1])), "raio": float(RAIO_DO_QUE_MORA.get(str(d.get("peca", "")), 0.5))})
		elif str(d.get("lugar", "")) == "Cemitério" and d.has("desloc"):
			var desloc: Array = d["desloc"]
			lista.append({"nome": "posto " + caminho, "ponto": Vector2(centro.x + float(desloc[0]), centro.z + float(desloc[2])), "raio": RAIO_DO_POSTO})
		for chave in d:
			_varrer(d[chave], caminho + "/" + str(chave), centro, lista)
	elif no is Array:
		var a: Array = no
		if a.size() == 2 and str(a[0]) == "Cemitério" and a[1] is Array and (a[1] as Array).size() >= 3:
			var p: Array = a[1]
			lista.append({"nome": "posto " + caminho, "ponto": Vector2(centro.x + float(p[0]), centro.z + float(p[2])), "raio": RAIO_DO_POSTO})
		for i in a.size():
			_varrer(a[i], caminho + "[%d]" % i, centro, lista)


func _nada_dentro_de_laje() -> void:
	print("")
	print("6. nada dentro de laje")
	var moradores := _moradores_do_cemiterio()
	_conferir(moradores.size() >= 20, "achei o que mora no cemitério nos dados (%d coisas: capim, embaúbas, pedras, galhadas e postos)" % moradores.size())
	var folga_minima := INF
	for morador in moradores:
		var ponto: Vector2 = morador["ponto"]
		var raio: float = morador["raio"]
		for i in pegadas.size():
			var distancia := _distancia_ao_retangulo(ponto, pegadas[i])
			folga_minima = minf(folga_minima, distancia - raio)
			_conferir(distancia >= raio, "%s fica a %.2f u da laje %d, e pede %.2f" % [morador["nome"], distancia, i, raio])
	print("   %d coisas conferidas; a mais apertada sobra %.2f u" % [moradores.size(), folga_minima])


# --- 7. A PORTA DA CAPELINHA --------------------------------------------------------

func _porta_da_capelinha() -> void:
	print("")
	print("7. a porta da capelinha")
	var porta: Vector3 = world.ancoras.get("CapelinhaPorta", Vector3.INF)
	var frente: Vector3 = world.ancoras.get("CapelinhaFrente", Vector3.INF)
	_conferir(porta.is_finite() and frente.is_finite(), "a capelinha tem porta e frente")
	if not (porta.is_finite() and frente.is_finite()):
		return
	var dentro := Vector2(frente.x, frente.z).normalized()
	var lateral := Vector2(-dentro.y, dentro.x)
	for i in pegadas.size():
		var r := pegadas[i]
		# A laje entra na faixa se algum canto dela cai entre -meia faixa e +meia faixa de
		# lado, e do lado de dentro da porta.
		var no_corredor := false
		var menor_lado := INF
		var maior_lado := -INF
		var a_frente := false
		for canto in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			var rel: Vector2 = canto - Vector2(porta.x, porta.z)
			menor_lado = minf(menor_lado, rel.dot(lateral))
			maior_lado = maxf(maior_lado, rel.dot(lateral))
			if rel.dot(dentro) > 0.0:
				a_frente = true
		no_corredor = a_frente and menor_lado < MEIA_FAIXA_DA_PORTA and maior_lado > -MEIA_FAIXA_DA_PORTA
		_conferir(not no_corredor, "a laje %d está na faixa que sai da porta da capelinha" % i)
		var capelinha: Vector3 = world.ancoras.get("Capelinha", porta)
		_conferir(_distancia_ao_retangulo(Vector2(capelinha.x, capelinha.z), r) >= FOLGA_DA_CAPELINHA, "a laje %d fica a menos de %.1f u do meio da capelinha" % [i, FOLGA_DA_CAPELINHA])


# --- 8. SE ANDA ENTRE ELAS ----------------------------------------------------------

func _livre(p: Vector2) -> bool:
	var espaco: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var forma := CapsuleShape3D.new()
	forma.radius = RAIO_DO_CORPO
	forma.height = ALTURA_DO_CORPO
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	var chao: float = world.ground_height_at(Vector3(p.x, 0.0, p.y))
	consulta.transform = Transform3D(Basis(), Vector3(p.x, chao + ALTURA_DO_CORPO * 0.5 + 0.15, p.y))
	consulta.collision_mask = 1
	return espaco.intersect_shape(consulta, 4).is_empty()


func _se_anda_entre_elas() -> void:
	print("")
	print("8. se anda entre elas")
	var testados := 0
	# O meio de cada vão entre lajes vizinhas da mesma fileira.
	for i in pegadas.size():
		for j in range(i + 1, pegadas.size()):
			var a := pegadas[i]
			var b := pegadas[j]
			if absf(a.get_center().y - b.get_center().y) >= 0.8:
				continue
			var esquerda := a if a.get_center().x < b.get_center().x else b
			var direita := b if esquerda == a else a
			if direita.position.x - esquerda.end.x > 2.0:
				continue
			var meio := Vector2((esquerda.end.x + direita.position.x) * 0.5, (a.get_center().y + b.get_center().y) * 0.5)
			testados += 1
			_conferir(_livre(meio), "o vão entre as lajes %d e %d não deixa a cápsula passar (%s)" % [i, j, str(meio)])
	# O meio de cada corredor entre fileiras, sob o centro de cada laje.
	for i in pegadas.size():
		for j in pegadas.size():
			var a := pegadas[i]
			var b := pegadas[j]
			if absf(a.get_center().x - b.get_center().x) >= 0.6 or b.get_center().y <= a.get_center().y or b.position.y - a.end.y > 2.0:
				continue
			var meio := Vector2(a.get_center().x, (a.end.y + b.position.y) * 0.5)
			testados += 1
			_conferir(_livre(meio), "o corredor entre as lajes %d e %d não deixa a cápsula passar (%s)" % [i, j, str(meio)])
	# A faixa da porta da capelinha até o meio do cemitério.
	var porta: Vector3 = world.ancoras.get("CapelinhaPorta", Vector3.INF)
	var centro: Vector3 = world.ancoras["Cemitério"]
	if porta.is_finite():
		# Da frente da porta (a capelinha é de caixa: o ponto da porta é a parede dela) até o
		# meio do cemitério, pela faixa da porta.
		var frente: Vector3 = world.ancoras.get("CapelinhaFrente", Vector3.LEFT)
		var de := Vector2(porta.x, porta.z) + Vector2(frente.x, frente.z).normalized() * (RAIO_DO_CORPO + 0.5)
		var passos := 12
		for k in passos + 1:
			var p := de.lerp(Vector2(centro.x - 3.0, porta.z), float(k) / float(passos))
			testados += 1
			_conferir(_livre(p), "a faixa da porta da capelinha tem coisa no caminho (%s)" % str(p))
	_conferir(testados >= 20, "andei por pontos de passagem suficientes (%d)" % testados)
	print("   %d pontos de passagem conferidos" % testados)


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("LAPIDES_NO_CHAO_OK (%s): doze lajes para o mesmo lado, dentro do cercado, sem se encostar, assentadas no chão, sem capim nem posto dentro, com a porta da capelinha olhando o corredor, e a cápsula passa entre elas" % _estilo_do_portao())
	else:
		print("lapides_no_chao (%s): %d falha(s)" % [_estilo_do_portao(), falhas])
	quit(1 if falhas > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _mundo_pronto() -> void:
	for i in range(6000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
