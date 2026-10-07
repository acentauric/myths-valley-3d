extends SceneTree
## Confere AS COLISÕES NO CHÃO, andando: o corpo do jogador anda os caminhos do
## vale e as portas das construções, e o portão diz onde ele prendeu.
##
##     Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/colisoes_de_passeio.gd
##
## `colisoes_de_passeio_procedural.gd` faz o outro estilo. "Tem diversos pontos
## ruins de colisão que precisam ser revisados", disse o dono, sem apontar nenhum:
## os portões de colisão de antes comparam UMA caixa por peça com o desenho dela, e
## não andam. Este anda, com o corpo de verdade (a cápsula do jogador, o degrau de
## 0,4 m, a descida da rampa), sem esperar o relógio — o `move_and_slide` roda no
## ritmo da máquina —, e acha o que só se acha andando:
##
##   1. OS CAMINHOS. O que a malha de navegação (`Navegacao`) traça entre as âncoras
##      do vale — a praça, a igreja, as casas, o píer, a mata, o cemitério — o corpo
##      anda, a passos de 0,1 m, e não pode parar: um ponto onde ele não avança é
##      PAREDE INVISÍVEL (uma caixa maior que o desenho) ou quina que prende.
##   2. O QUE FICA DEBAIXO DOS PÉS. Cada ponto desses caminhos, e o meio de cada
##      trecho, não pode estar DENTRO de um corpo que não seja o chão: um caminho que
##      atravessa corpo é caixa maior que o desenho, e quem anda por ele (os
##      moradores, o Pedro) bate nela.
##   3. AS PORTAS. De cada construção de dentro (`Interiores`), cinco passagens
##      paralelas pelo vão — da esquerda à direita da porta — e duas de viés, de fora
##      para dentro e de dentro para fora: o corpo atravessa todas.
##   4. OS BURACOS. Cada construção grande posta no vale (casa, galpão, igreja, cais:
##      a pasta `construcoes/`, `casas/` e os adereços grandes) tem de ter corpo no
##      miolo dela — se não tem, o jogador atravessa o que parece parede.
##
## O que é de morador e de bicho (`CharacterBody3D`) não conta: anda, e não é
## cenário. A mata (o conjunto de cilindros que o jogo move para perto do jogador)
## é posta junto do corpo a cada oito unidades de caminho.
##
## O QUE JÁ SE SABE E NÃO SE CORRIGE AQUI vai em `EXCECOES`, com a razão e as
## coordenadas, e o portão imprime o resto como lista para quem for revisar.
##
## FALSIFICAÇÃO: `-- --falsificar=parede` põe uma caixa invisível no meio do
## primeiro caminho, e o portão TEM de achá-la (e de reprovar); `-- --falsificar=degrau`
## desliga a subida de borda de face torta do corpo (`sobe_borda_torta`), e o portão TEM
## de achar o corpo preso na faixa de rua, na cabeceira da ponte e na areia.

const PASSO := 0.1
## Quantos passos sem avanço fazem um "preso" (1,2 m de caminho sem andar).
const PRESO_PASSOS := 12
## Quanto o corpo tem de avançar por passo para não contar como parado.
const AVANCO_MINIMO := 0.03
## Os pares de âncoras do vale: a praça é o centro, e cada ponto vai até ela.
const ANCORAS := ["Praça", "Igreja", "Cruzeiro", "PierPiso", "Casa de taipa", "Terreiro", "Gameleira", "Cemitério",
	"Poço", "Casa da estrada", "Lavoura", "Bar", "Casa de Carro Quebrado"]
## O que já se sabe e não se corrige aqui, com a razão e o lugar: o corpo (começo do nome,
## "pai/avô/nome") e a que distância (m) do ponto, em coordenadas do mundo. Cada uma é
## defeito de OUTRO arquivo, e o portão a lista para quem a corrigir.
const EXCECOES := [
	{"corpo": "PierTripo/", "perto": Vector3(85.2, -0.5, -5.6), "raio": 3.0,
		"razao": "o caminho da malha (Cruzeiro → PierPiso) sobe ao píer pela BORDA NORTE do tabuado, por cima de uma viga rente à água, 0,5 u acima do leito: a malha (células de 0,2 u de altura) acha o degrau de 0,5 passável e o corpo (degrau de 0,4) não sobe; o jogador sobe pela cabeceira (conferido na seção 5) (navegacao_vale.gd)"},
	{"corpo": "Vale3D/Cenario/@StaticBody3D@", "perto": Vector3(7.0, 4.0, -8.8), "raio": 9.0,
		"razao": "só no estilo procedural: o caminho da malha até o MEIO da Casa de Carro Quebrado (a âncora) passa pela parede dela, que a malha não corta"},
]
## Quantos presos reprovam o portão. Zero: qualquer ponto onde o corpo não anda é um
## defeito, ou está em `EXCECOES` com a razão.
const PRESOS_ACEITOS := 0
## As pontas de um caminho (m) ficam fora da conta de "dentro de corpo": a âncora de uma casa
## ou de um poço é o meio dele.
const PONTA_DO_CAMINHO := 3.0
## E, se aí ainda houver corpo (a casa grande do procedural), até quanto se corta.
const PONTA_MAXIMA := 9.0

var falhas := 0
var vale
var world
var jogador
var regiao
var navegacao
var espaco: PhysicsDirectSpaceState3D
var presos: Array[Dictionary] = []
var sobrepostos: Array[Dictionary] = []
var buracos: Array[Dictionary] = []
var _refresh_em := Vector3.INF
var _passos := 0
var _capsula := CapsuleShape3D.new()
var _consulta := PhysicsShapeQueryParameters3D.new()


## O estilo do vale em que o portão roda: `colisoes_de_passeio_procedural.gd` o troca.
func _estilo_do_portao() -> String:
	return "tripo"


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("COLISOES_DE_PASSEIO_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	root.get_node("/root/Estilo").modo = _estilo_do_portao()
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(10)
	vale = current_scene
	world = vale.get("world")
	jogador = vale.get("player")
	regiao = world.get("_region") if world != null else null
	navegacao = vale.get("navegacao")
	_conferir(world != null and jogador != null and regiao != null and navegacao != null, "o vale não montou o mundo, o jogador, a região ou a navegação")
	if falhas > 0:
		_fechar()
		return
	espaco = world.get_world_3d().direct_space_state
	jogador.set_physics_process(false)
	# Quem anda sozinho (moradores, bichos) não é parede: o corpo passa por eles.
	for no in vale.find_children("*", "CharacterBody3D", true, false):
		if no != jogador:
			jogador.add_collision_exception_with(no)
	_capsula.radius = 0.28
	_capsula.height = jogador.character_height
	_consulta.shape = _capsula
	_consulta.collision_mask = 1
	_consulta.exclude = [jogador.get_rid()]
	var pedro = vale.get("pedro")
	if pedro != null:
		pedro.ir_ao_passo("roca")
	vale._acertar_a_porta_da_casa()
	for qual in vale.interiores.get("_construcoes"):
		var sala: Node3D = vale.interiores.sala_de(qual)
		if sala != null and sala.has_method("trancar"):
			sala.trancar(false)
	var pronta := false
	for i in 1200:
		if navegacao.esta_pronta():
			pronta = true
			break
		await process_frame
	_conferir(pronta, "a malha de navegação não ficou pronta")
	if not pronta:
		_fechar()
		return

	print("")
	print("1+2. os caminhos entre as âncoras (passo %.2f m) e o que está sob os pés" % PASSO)
	await _caminhos()
	print("")
	print("3. as portas das construções de dentro")
	await _portas()
	if _estilo_do_portao() == "tripo":
		print("")
		print("4. construções grandes sem corpo na pegada")
		_buracos()
	print("")
	print("5. o cais e a ponte, de ponta a ponta, andando pelo eixo")
	await _pontes()
	_relatorio()
	_fechar()


# --- 1 e 2. OS CAMINHOS ---------------------------------------------------------------

func _caminhos() -> void:
	var ancoras: Dictionary = world.ancoras
	var pares: Array = []
	var nomes: Array = []
	for nome in ANCORAS:
		if ancoras.has(nome):
			nomes.append(nome)
	for i in range(1, nomes.size()):
		pares.append([nomes[0], nomes[i]])
	for i in range(1, nomes.size() - 1):
		pares.append([nomes[i], nomes[i + 1]])
	var total_m := 0.0
	var inicio := Time.get_ticks_msec()
	var falso := _falsificar_parede()
	for par in pares:
		var a: Vector3 = ancoras[par[0]]
		var b: Vector3 = ancoras[par[1]]
		var caminho: PackedVector3Array = navegacao.caminho(a, b)
		if caminho.size() < 2:
			print("  %-26s sem caminho" % ("%s → %s" % par))
			continue
		if falso != null and par == pares[0]:
			var meio: Vector3 = caminho[caminho.size() / 2]
			_pr_caixa_invisivel(falso, meio)
		var antes := presos.size()
		var comprimento := 0.0
		for i in range(1, caminho.size()):
			comprimento += caminho[i - 1].distance_to(caminho[i])
		total_m += comprimento
		_sobrepostos_do_caminho("%s → %s" % par, caminho)
		# As pontas ficam de fora: a âncora de uma casa, de um poço, de um cruzeiro é o MEIO
		# dele, e ninguém anda até o meio do que tem corpo.
		await _andar("%s → %s" % par, _sem_as_pontas(caminho, PONTA_DO_CAMINHO))
		print("  %-30s %6.1f m, presos %d" % ["%s → %s" % par, comprimento, presos.size() - antes])
	print("  %d caminhos, %.0f m andados em %d passos (%d ms)" % [pares.size(), total_m, _passos, Time.get_ticks_msec() - inicio])


## O caminho sem as pontas: o `corte` do começo e o do fim, e mais um metro por vez enquanto
## o ponto de corte ainda estiver dentro de corpo (a âncora de uma casa grande é o meio dela).
func _sem_as_pontas(caminho: PackedVector3Array, corte_minimo: float) -> PackedVector3Array:
	var comprimento := 0.0
	for i in range(1, caminho.size()):
		comprimento += caminho[i - 1].distance_to(caminho[i])
	var corte_do_comeco := _corte_livre(caminho, comprimento, corte_minimo, false)
	var corte_do_fim := _corte_livre(caminho, comprimento, corte_minimo, true)
	if comprimento < (corte_do_comeco + corte_do_fim) * 1.5:
		return caminho
	return _recortar(caminho, comprimento, corte_do_comeco, corte_do_fim)


## Quantos metros cortar de uma ponta para o corpo cair fora de qualquer corpo sólido.
func _corte_livre(caminho: PackedVector3Array, comprimento: float, corte_minimo: float, do_fim: bool) -> float:
	var corte := corte_minimo
	while corte < PONTA_MAXIMA and corte < comprimento * 0.4:
		var ponto := _ponto_a(caminho, (comprimento - corte) if do_fim else corte)
		_consulta.transform = Transform3D(Basis(), ponto + Vector3.UP * (jogador.character_height * 0.5 + 0.42))
		var livre := true
		for r in espaco.intersect_shape(_consulta, 8):
			var corpo := r["collider"] as Node
			if corpo != null and not (corpo is CharacterBody3D) and not _e_chao(corpo):
				livre = false
				break
		if livre:
			break
		corte += 1.0
	return corte


## O ponto do caminho a `distancia` metros do começo.
func _ponto_a(caminho: PackedVector3Array, distancia: float) -> Vector3:
	var andado := 0.0
	for i in range(1, caminho.size()):
		var seg := caminho[i - 1].distance_to(caminho[i])
		if andado + seg >= distancia:
			return caminho[i - 1].lerp(caminho[i], (distancia - andado) / maxf(seg, 0.0001))
		andado += seg
	return caminho[caminho.size() - 1]


func _recortar(caminho: PackedVector3Array, comprimento: float, corte: float, corte_do_fim: float) -> PackedVector3Array:
	var saida := PackedVector3Array()
	var andado := 0.0
	for i in caminho.size():
		if i > 0:
			var seg := caminho[i - 1].distance_to(caminho[i])
			# O ponto de entrada (a `corte` m do começo) e o de saída (a `corte` m do fim).
			if andado < corte and andado + seg >= corte:
				saida.append(caminho[i - 1].lerp(caminho[i], (corte - andado) / maxf(seg, 0.0001)))
			if andado < comprimento - corte_do_fim and andado + seg >= comprimento - corte_do_fim:
				saida.append(caminho[i - 1].lerp(caminho[i], (comprimento - corte_do_fim - andado) / maxf(seg, 0.0001)))
				return saida
			andado += seg
		if andado >= corte and andado < comprimento - corte_do_fim and i > 0:
			saida.append(caminho[i])
	return saida


## Anda o corpo por `pontos`, passo a passo, e anota onde ele não avança.
func _andar(rotulo: String, pontos: PackedVector3Array) -> void:
	jogador.global_position = pontos[0] + Vector3.UP * 0.1
	jogador.velocity = Vector3.ZERO
	await _mata_junto()
	for i in range(1, pontos.size()):
		var alvo := pontos[i]
		var parado := 0
		var resta := _plano(alvo - jogador.global_position).length()
		var limite := int(resta / PASSO * 4.0) + 30
		var n := 0
		while resta > 0.25 and n < limite:
			n += 1
			if jogador.global_position.distance_to(_refresh_em) > 8.0:
				await _mata_junto()
			var rumo := _plano(alvo - jogador.global_position).normalized()
			_passo(rumo)
			var nova := _plano(alvo - jogador.global_position).length()
			parado = parado + 1 if resta - nova < AVANCO_MINIMO else 0
			resta = nova
			if parado >= PRESO_PASSOS:
				_anotar_preso(rotulo, rumo)
				# O jogador pularia a quina; o portão põe o corpo adiante e segue.
				jogador.global_position = alvo + Vector3.UP * 0.2
				jogador.velocity = Vector3.ZERO
				break
		_sobreposto_aqui(rotulo)


## Um passo de PASSO metro, com o que o jogador faz na física: a velocidade horizontal, a
## gravidade (ou o encosto no chão) e o degrau de 0,4 m.
func _passo(rumo: Vector3) -> void:
	var dt: float = maxf(jogador.get_physics_process_delta_time() if Engine.is_in_physics_frame() else jogador.get_process_delta_time(), 0.001)
	jogador.velocity.x = rumo.x * PASSO / dt
	jogador.velocity.z = rumo.z * PASSO / dt
	if jogador.is_on_floor():
		jogador.velocity.y = -0.1
	else:
		jogador.velocity.y = -PASSO / dt
	jogador.move_and_slide()
	jogador._subir_degrau(rumo)
	_passos += 1


func _plano(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## A mata é um conjunto de cilindros que o jogo move para perto do jogador a cada
## 0,25 s: aqui, na hora, e esperando o quadro em que a troca vale.
func _mata_junto() -> void:
	regiao._refresh_tree_collisions()
	_refresh_em = jogador.global_position
	await process_frame
	await physics_frame


func _anotar_preso(rotulo: String, rumo: Vector3) -> void:
	var corpo := "?"
	var normal := Vector3.ZERO
	# A colisão que segura o corpo é a mais parecida com parede (a de menor normal.y);
	# o chão que ele pisa também está na lista e não é quem o prende.
	var menor_y := 2.0
	for i in jogador.get_slide_collision_count():
		var c: KinematicCollision3D = jogador.get_slide_collision(i)
		if c.get_normal().y < menor_y:
			menor_y = c.get_normal().y
			normal = c.get_normal()
			corpo = _nome_do_corpo(c.get_collider())
	presos.append({"onde": jogador.global_position, "caminho": rotulo, "corpo": corpo, "normal": normal, "rumo": rumo, "detalhe": _detalhe_do_preso(rumo)})


## O que prende, em números: as colisões do último passo, o chão à frente, e se um degrau
## de `DEGRAU` (0,4 m) o venceria — o que separa quina que prende de caminho que erra.
func _detalhe_do_preso(rumo: Vector3) -> String:
	var partes: PackedStringArray = []
	for i in jogador.get_slide_collision_count():
		var c: KinematicCollision3D = jogador.get_slide_collision(i)
		partes.append("%s n%s y%.2f" % [String(c.get_collider().name) if c.get_collider() is Node else "?", str(c.get_normal().snapped(Vector3.ONE * 0.01)), c.get_position().y - jogador.global_position.y])
	var na_frente: Array[String] = []
	for d in [0.3, 0.6]:
		var de: Vector3 = jogador.global_position + rumo * d
		var raio := PhysicsRayQueryParameters3D.create(de + Vector3.UP * 2.0, de - Vector3.UP * 1.5, 1)
		raio.exclude = [jogador.get_rid()]
		var r := espaco.intersect_ray(raio)
		na_frente.append("%+.2f" % (r["position"].y - jogador.global_position.y) if not r.is_empty() else "-")
	var degrau: bool = not jogador.test_move(jogador.global_transform.translated(Vector3.UP * 0.4), rumo * 0.3)
	return "no chão %s, parede %s, chão à frente (0,3 / 0,6 m) %s, degrau de 0,4 m %s; %s" % [jogador.is_on_floor(), jogador.is_on_wall(), "/".join(na_frente), "vence" if degrau else "NÃO vence", " | ".join(partes)]


## "pai/nome" de um corpo: o nome sozinho ("@StaticBody3D@8") não diz de quem é.
func _nome_do_corpo(corpo: Object) -> String:
	if not (corpo is Node):
		return str(corpo)
	var no := corpo as Node
	var pai := String(no.get_parent().name) if no.get_parent() != null else ""
	var avo := String(no.get_parent().get_parent().name) if no.get_parent() != null and no.get_parent().get_parent() != null else ""
	return "%s/%s/%s" % [avo, pai, String(no.name)]


## O corpo, num ponto, dentro de algo que não é o chão? (Corpo de morador e de bicho
## está na lista de exceções do `move_and_slide`; aqui é a pergunta ao motor.)
func _sobreposto_aqui(rotulo: String) -> void:
	_consulta.transform = Transform3D(Basis(), jogador.global_position + Vector3.UP * (jogador.character_height * 0.5 + 0.42))
	for r in espaco.intersect_shape(_consulta, 8):
		var corpo := r["collider"] as Node
		if corpo == null or corpo is CharacterBody3D or _e_chao(corpo):
			continue
		sobrepostos.append({"onde": jogador.global_position, "caminho": rotulo, "corpo": _nome_do_corpo(corpo)})


## Os vértices e os pontos médios de um caminho, o corpo parado ali: dentro de corpo?
## O que o corpo sobe sem pular (até `DEGRAU`, 0,4 m: o degrau, a rampa, a soleira) não
## é parede, e por isso a cápsula é medida 0,42 m acima do ponto; e as pontas do
## caminho — a âncora de uma casa, de um poço, de um cruzeiro, que é o MEIO dele — ficam
## de fora: o destino de um caminho até um objeto está dentro dele.
func _sobrepostos_do_caminho(rotulo: String, caminho: PackedVector3Array) -> void:
	var pontos: Array[Vector3] = []
	for i in caminho.size():
		pontos.append(caminho[i])
		if i > 0:
			pontos.append((caminho[i - 1] + caminho[i]) * 0.5)
	for p in pontos:
		if p.distance_to(caminho[0]) < PONTA_DO_CAMINHO or p.distance_to(caminho[caminho.size() - 1]) < PONTA_DO_CAMINHO:
			continue
		_consulta.transform = Transform3D(Basis(), p + Vector3.UP * (jogador.character_height * 0.5 + 0.42))
		for r in espaco.intersect_shape(_consulta, 8):
			var corpo := r["collider"] as Node
			if corpo == null or corpo is CharacterBody3D or _e_chao(corpo):
				continue
			sobrepostos.append({"onde": p, "caminho": rotulo, "corpo": _nome_do_corpo(corpo), "da_malha": true})


## O chão: a terra, as faixas de rua e de areia, o fundo do mar e a borda do quadro.
func _e_chao(corpo: Node) -> bool:
	var nome := String(corpo.name)
	return nome.begins_with("Colisão ") or nome == "Chão do mar" or nome == "Borda do quadro"


# --- 3. AS PORTAS -----------------------------------------------------------------------

func _portas() -> void:
	for qual in vale.interiores.get("_construcoes"):
		var sala: Node3D = vale.interiores.sala_de(qual)
		if sala == null:
			continue
		var antes := presos.size()
		var meia: float = maxf(sala.largura_da_porta * 0.5 - 0.28 - 0.04, 0.05)
		var retas: Array = []
		for k in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var x: float = sala.porta_x + k * meia
			retas.append(["reta %+.2f" % (k * meia), [Vector3(x, 0.0, 3.4), Vector3(x, 0.0, -2.4)]])
		# De viés (só no Tripo: o procedural é comparação, e o cruzeiro dele fica no caminho), a uns 23 graus do eixo: de 1,6 m antes da boca do túnel da porta, 0,7 m para o
		# lado, até alinhar com a boca — o túnel da torre da igreja procedural tem meio metro de
		# folga, e o cruzeiro dela fica a um passo da fachada: mais longe, o corpo bate nele.
		for lado in ([-1.0, 1.0] if _estilo_do_portao() == "tripo" else []):
			var boca: float = sala.PAREDE + sala.fundo_da_porta + 0.3
			retas.append(["viés %+.0f" % lado, [Vector3(sala.porta_x + lado * 0.7, 0.0, boca + 1.6), Vector3(sala.porta_x, 0.0, boca), Vector3(sala.porta_x, 0.0, -2.4)]])
		for reta in retas:
			var pontos := PackedVector3Array()
			for p in reta[1]:
				var no_mundo: Vector3 = sala.to_global(p)
				pontos.append(Vector3(no_mundo.x, world.ground_height_at(no_mundo) + 0.3 if p.z > 0.4 else sala.global_position.y + 0.3, no_mundo.z))
			await _andar("porta de %s, %s, entrando" % [qual, reta[0]], pontos)
			pontos.reverse()
			await _andar("porta de %s, %s, saindo" % [qual, reta[0]], pontos)
		print("  %-12s %d passagens (porta de %.2f m), presos %d" % [qual, retas.size() * 2, sala.largura_da_porta, presos.size() - antes])


# --- 5. O CAIS E A PONTE ---------------------------------------------------------------------

## O píer (e a ponte, que tiver a laje da câmera), andados pelo eixo comprido, de cinco metros antes de
## uma ponta a cinco metros depois da outra, e de volta: o corpo sobe pela cabeceira e
## desce pela outra. (A ponte do norte fica cercada nas duas cabeceiras até a obra, de
## propósito, e tem portão próprio; a do rio central é andada pelos caminhos da seção 1.) A medida e o giro são os da laje da câmera (`catalogo_assets._laje_da_camera`),
## que tem a pegada exata do modelo; a ponta que cai n'água (a do píer, mar adentro) é
## encurtada para a do tabuado, porque além dele o corpo só acharia as estacas.
func _pontes() -> void:
	var lajes: Array = world.find_children("*LajeDaCamera", "StaticBody3D", true, false)
	if lajes.is_empty():
		print("  sem laje da câmera (o píer e a ponte são do Tripo): nada a andar")
		return
	var ponte_do_norte: Vector3 = world.ancoras.get("Ponte", Vector3.INF)
	for laje in lajes:
		if ponte_do_norte.is_finite() and (laje as Node3D).global_position.distance_to(ponte_do_norte) < 20.0:
			continue
		var forma := (laje as Node).get_child(0) as CollisionShape3D
		var caixa := forma.shape as BoxShape3D
		var comprido := Vector3.RIGHT if caixa.size.x >= caixa.size.z else Vector3.BACK
		var comprimento := maxf(caixa.size.x, caixa.size.z)
		var eixo: Vector3 = (laje as Node3D).global_basis * comprido
		eixo = Vector3(eixo.x, 0.0, eixo.z).normalized()
		var centro: Vector3 = (laje as Node3D).global_position
		var a: Vector3 = centro - eixo * (comprimento * 0.5 + 5.0)
		var b: Vector3 = centro + eixo * (comprimento * 0.5 + 5.0)
		if not world.is_on_land(a):
			a = centro - eixo * (comprimento * 0.5 - 4.0)
		if not world.is_on_land(b):
			b = centro + eixo * (comprimento * 0.5 - 4.0)
		# Começa pela ponta de terra firme.
		if not world.is_on_land(a) and world.is_on_land(b):
			var troca := a
			a = b
			b = troca
		var antes := presos.size()
		var ida := PackedVector3Array([_chao(a) + Vector3.UP * 0.3, b])
		await _andar("%s, de ponta a ponta" % laje.name, ida)
		var volta := PackedVector3Array([_chao(b) + Vector3.UP * 0.3, a])
		await _andar("%s, de volta" % laje.name, volta)
		print("  %-22s %.1f m de eixo %s, de %s a %s, presos %d" % [laje.name, comprimento, str(eixo.snapped(Vector3.ONE * 0.01)), str(a.snapped(Vector3.ONE * 0.1)), str(b.snapped(Vector3.ONE * 0.1)), presos.size() - antes])
		for i in range(antes, presos.size()):
			print("      preso em %s no corpo %s: %s" % [str((presos[i]["onde"] as Vector3).snapped(Vector3.ONE * 0.1)), presos[i]["corpo"], presos[i]["detalhe"]])


## O chão firme (da terra, do fundo do mar ou do tabuado) sob `ponto`.
func _chao(ponto: Vector3) -> Vector3:
	var raio := PhysicsRayQueryParameters3D.create(ponto + Vector3.UP * 40.0, ponto - Vector3.UP * 40.0, 1)
	raio.exclude = [jogador.get_rid()]
	var bateu := espaco.intersect_ray(raio)
	return bateu["position"] if not bateu.is_empty() else world.ground_position(ponto)


# --- 4. OS BURACOS ------------------------------------------------------------------------

## Construção grande sem corpo na pegada: o jogador atravessa o que parece parede.
func _buracos() -> void:
	var CatalogoAssets = load("res://scripts/prototipo_3d/catalogo_assets.gd")
	var grandes := 0
	var caixa_do_corpo := BoxShape3D.new()
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = caixa_do_corpo
	consulta.collision_mask = 1
	consulta.exclude = [jogador.get_rid()]
	for no in world.get_children():
		if not (no is Node3D) or not String(no.name).ends_with("Tripo") and not String(no.name).contains("Tripo"):
			continue
		var chave := _chave_do_modelo(String(no.name), CatalogoAssets)
		if chave == "":
			continue
		var arquivo := String(CatalogoAssets.PECAS[chave].get("tripo", ""))
		if not (arquivo.begins_with("construcoes/") or arquivo.begins_with("casas/")):
			continue
		var caixa := AABB()
		var primeira := true
		for malha in (no as Node).find_children("*", "MeshInstance3D", true, false):
			var m := malha as MeshInstance3D
			if m.mesh == null or not m.is_visible_in_tree():
				continue
			var ab: AABB = m.global_transform * m.get_aabb()
			caixa = ab if primeira else caixa.merge(ab)
			primeira = false
		if primeira or caixa.size.y < 1.2 or maxf(caixa.size.x, caixa.size.z) < 1.2:
			continue
		grandes += 1
		# A pegada inteira, entre 0,4 e 2,0 m acima do pé: o mirante tem quatro pés e o miolo
		# vazio, e nem por isso é buraco.
		caixa_do_corpo.size = Vector3(maxf(caixa.size.x, 0.3), 1.6, maxf(caixa.size.z, 0.3))
		consulta.transform = Transform3D(Basis(), Vector3(caixa.get_center().x, caixa.position.y + 1.2, caixa.get_center().z))
		var achou := false
		for r in espaco.intersect_shape(consulta, 16):
			var corpo := r["collider"] as Node
			if corpo != null and not (corpo is CharacterBody3D) and not _e_chao(corpo):
				achou = true
				break
		if not achou:
			buracos.append({"onde": caixa.get_center(), "chave": chave, "tamanho": caixa.size})
	print("  %d construções grandes, %d sem corpo na pegada" % [grandes, buracos.size()])


func _chave_do_modelo(nome: String, CatalogoAssets) -> String:
	var limpo := nome
	while limpo.length() > 0 and limpo[limpo.length() - 1] in "0123456789":
		limpo = limpo.substr(0, limpo.length() - 1)
	if limpo.begins_with("@"):
		return ""
	for chave in CatalogoAssets.PECAS:
		if String(chave).capitalize() + "Tripo" == limpo:
			return chave
	return ""


# --- o relatório -------------------------------------------------------------------------

func _relatorio() -> void:
	print("")
	print("RELATÓRIO")
	var por_corpo := {}
	for p in presos:
		var chave := _sem_numero(String(p["corpo"]))
		if not por_corpo.has(chave):
			por_corpo[chave] = []
		(por_corpo[chave] as Array).append(p)
	print("  presos: %d" % presos.size())
	for chave in por_corpo:
		var lista: Array = por_corpo[chave]
		var p: Dictionary = lista[0]
		var razao := _razao_da_excecao(p)
		print("    %-34s %2d vez(es); primeiro em %s (%s), normal %s%s" % [chave, lista.size(), str((p["onde"] as Vector3).snapped(Vector3.ONE * 0.1)), p["caminho"], str((p["normal"] as Vector3).snapped(Vector3.ONE * 0.1)), (" [exceção: %s]" % razao) if razao != "" else ""])
		print("      detalhe: %s" % p["detalhe"])
	var sem_excecao := 0
	for p in presos:
		if _razao_da_excecao(p) == "":
			sem_excecao += 1
	var por_dentro := {}
	for s in sobrepostos:
		var chave := _sem_numero(String(s["corpo"]))
		por_dentro[chave] = int(por_dentro.get(chave, 0)) + 1
	print("  caminhos da malha que atravessam corpo (aviso, é do morador): %d pontos em %d corpo(s)" % [sobrepostos.size(), por_dentro.size()])
	for chave in por_dentro:
		var primeiro := {}
		for s in sobrepostos:
			if _sem_numero(String(s["corpo"])) == chave:
				primeiro = s
				break
		print("    %-34s %2d ponto(s); primeiro em %s (%s)" % [chave, por_dentro[chave], str((primeiro["onde"] as Vector3).snapped(Vector3.ONE * 0.1)), primeiro["caminho"]])
	for b in buracos:
		print("  BURACO: %s em %s, %.1f × %.1f × %.1f m, sem corpo na pegada" % [b["chave"], str((b["onde"] as Vector3).snapped(Vector3.ONE * 0.1)), b["tamanho"].x, b["tamanho"].y, b["tamanho"].z])
	_conferir(sem_excecao <= PRESOS_ACEITOS, "o corpo prendeu %d vez(es) em %d corpo(s): %s" % [sem_excecao, por_corpo.size(), ", ".join(por_corpo.keys())])
	# Os caminhos da malha que atravessam corpo são do morador, e não do jogador: ficam na lista,
	# para quem cuida da malha (`navegacao_vale.gd`), e não reprovam este portão.
	_conferir(buracos.is_empty(), "%d construção(ões) grande(s) sem corpo na pegada: %s" % [buracos.size(), ", ".join(buracos.map(func(b): return b["chave"]))])


## A razão pela qual este preso é de outro arquivo ("" se não é de ninguém ainda).
func _razao_da_excecao(preso: Dictionary) -> String:
	for e in EXCECOES:
		if String(preso["corpo"]).begins_with(String(e["corpo"])) and (preso["onde"] as Vector3).distance_to(e["perto"]) <= float(e["raio"]):
			return String(e["razao"])
	return ""


func _sem_numero(nome: String) -> String:
	var limpo := nome
	while limpo.length() > 0 and limpo[limpo.length() - 1] in "0123456789":
		limpo = limpo.substr(0, limpo.length() - 1)
	return limpo


# --- falsificação ---------------------------------------------------------------------------

func _falsificar_parede() -> StaticBody3D:
	var pedido := OS.get_environment("MV_FALSIFICAR")
	for argumento in OS.get_cmdline_user_args():
		if str(argumento).begins_with("--falsificar="):
			pedido = str(argumento).trim_prefix("--falsificar=")
	if pedido == "degrau":
		jogador.sobe_borda_torta = false
		print("  FALSIFICAÇÃO: o corpo não sobe borda de face torta (como antes): o portão TEM de achar os presos nelas")
		return null
	if pedido != "parede":
		return null
	print("  FALSIFICAÇÃO: uma caixa invisível no meio do primeiro caminho: o portão TEM de achá-la")
	var corpo := StaticBody3D.new()
	corpo.name = "ParedeInvisivelDoPortao"
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(0.6, 3.0, 6.0)
	forma.shape = caixa
	corpo.add_child(forma)
	return corpo


func _pr_caixa_invisivel(corpo: StaticBody3D, onde: Vector3) -> void:
	world.add_child(corpo)
	corpo.global_position = onde + Vector3.UP * 1.5


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("COLISOES_DE_PASSEIO_OK (%s): o corpo do jogador anda os caminhos entre as âncoras do vale e as portas das construções de dentro sem prender; nenhum caminho da malha atravessa corpo que não seja o chão; e nenhuma construção grande está sem corpo" % _estilo_do_portao())
	else:
		print("colisões de passeio (%s): %d falha(s)" % [_estilo_do_portao(), falhas])
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
