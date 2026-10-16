extends "res://tests/suite/caso.gd"
## A GAMELEIRA DO SAMBAQUI ASSENTA NO CHÃO (#87).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste gameleira
##
## O monte e a árvore eram assentados por uma amostra do terreno, no centro
## (`world_builder._build_gameleira`); com o chão novo de 05/10 a encosta ali
## ficou inclinada e a árvore apareceu desnivelada em relação ao mundo. Agora o
## terreno em volta é um platô (`GeoRegionRenderer`, PLATÔ DA GAMELEIRA).
##
##   1. O CHÃO EM VOLTA É PLANO: num anel de raio 5,5 em volta do marco, o chão
##      varia menos de 0,2 u do centro.
##   2. O MONTE NÃO FLUTUA: a borda do domo (raio 5, enterrado meia unidade)
##      fica abaixo do chão em todo o anel.
##   3. O MARCO É O TRONCO: `Lugares.ponto("gameleira")` é a âncora do tronco.
##   4. A ÁRVORE ASSENTA E TEM ESCALA (#228): o pé dela fica no chão do platô (e não no alto do monte,
##      que deixava as pontas das raízes pousadas numa bandeja); as raízes baixas (até 0,7 m do pé)
##      não passam do platô; a altura posta fica entre 9,5 e 12 m e na proporção do viajante, da casa branca
##      e do coqueiro (a maior da praia, sem esmagar a cena); o pano das fitas está centrado no
##      tronco e não o passa de mais de 0,7 m.
##   5. A COLISÃO E A NAVEGAÇÃO EM VOLTA DO TRONCO (#228): o cilindro do tronco (0,95 m) está no eixo dele e assenta
##      no chão; de um lado ao outro da árvore, a 7 m do eixo, o caminho
##      da malha dos moradores existe, chega, dá a volta por fora do cilindro do tronco (a colisão que
##      desceu junto com a altura) e não se alonga: o tronco é obstáculo, e a malha o sabe.

const RAIO_DO_ANEL := 5.5
const TOLERANCIA := 0.2
const ALTURA_MINIMA := 9.5
const ALTURA_MAXIMA := 12.0
## As raízes baixas: até esta altura do pé. O platô plano (`PLATO_RAIO` do renderer) as segura no chão.
const RAIZ_BAIXA := 0.7
const PLATO_PLANO := 7.0
const RAIO_MAXIMO_DO_PANO := 2.0
## O quanto o raio do pano pode passar do raio do tronco limpo (o pano amarra com 0,15 de folga).
const FOLGA_DO_PANO := 0.45
## A altura do tronco LIMPO (acima das sapopemas e abaixo dos galhos), do pé: onde se mede o tronco para o pano.
const ALTURA_DO_TRONCO_LIMPO := 2.3
## A PROPORÇÃO (#228): a altura da gameleira dividida pela do viajante (o Pedro do catálogo, 1,75 m), pela da casa de
## taipa branca (4,44 m) e pela do coqueiro (9,5 m). Com os 11 m de hoje: 6,3, 2,5 e 1,2. Com os 18,2 m de antes (14 x 1,3):
## 10,4, 4,1 e 1,9. A faixa de cada razão deixa passar os 10 a 12 m que a issue pediu e barra os de antes.
const VIAJANTE := Vector2(5.0, 8.0)
const CASA := Vector2(2.0, 3.0)
const COQUEIRO := Vector2(1.0, 1.4)
## A NAVEGAÇÃO EM VOLTA: os pontos opostos do anel a esta distância do eixo do tronco (o platô plano tem 7 u), e o
## quanto o caminho pode se alongar sobre a reta entre eles (a volta pelo tronco custa uns 5%).
const RAIO_DA_VOLTA := 7.0
const DESVIO_MAXIMO := 1.5

var falhas := 0


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("GAMELEIRA_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _quadros(4)
	await _mundo_pronto()
	await _quadros(8)
	var vale = current_scene
	var mundo = vale.world
	var lugares = root.get_node("/root/Lugares")
	var topo: Vector3 = mundo.ancoras.get("Gameleira", Vector3.INF)
	_conferir(topo.is_finite(), "o vale não tem a gameleira")
	if not topo.is_finite():
		_fechar()
		return
	var centro: float = mundo.ground_height_at(topo)

	# --- 1. O CHÃO EM VOLTA É PLANO ------------------------------------------------
	var desnivel := 0.0
	var mais_baixo := INF
	for i in 24:
		var angulo := TAU * float(i) / 24.0
		var ali := topo + Vector3(cos(angulo), 0.0, sin(angulo)) * RAIO_DO_ANEL
		var chao: float = mundo.ground_height_at(ali)
		desnivel = maxf(desnivel, absf(chao - centro))
		# --- 2. O MONTE NÃO FLUTUA: a borda do domo, a 5 u.
		var borda := topo + Vector3(cos(angulo), 0.0, sin(angulo)) * float(mundo.RAIO_DO_SAMBAQUI)
		mais_baixo = minf(mais_baixo, float(mundo.ground_height_at(borda)) - (centro - float(mundo.ENTERRADO)))
	_conferir(desnivel <= TOLERANCIA, "em volta da gameleira o chão varia %.2f u do centro (tolerância %.1f)" % [desnivel, TOLERANCIA])
	_conferir(mais_baixo >= -0.05, "a borda do sambaqui flutua %.2f u acima do chão" % -mais_baixo)

	# --- 3. O MARCO É O TRONCO -------------------------------------------------------
	var marco: Vector3 = lugares.ponto("gameleira")
	_conferir(marco.is_finite() and marco.distance_to(topo) < 0.01, "o marco da gameleira (%s) não é a âncora do tronco (%s)" % [str(marco), str(topo)])
	_a_arvore_assenta(mundo, topo, centro)
	_a_colisao_do_tronco(mundo, topo)
	await _a_navegacao_anda_em_volta(vale, mundo, topo)
	_fechar()


## Pergunta 4: a gameleira posta, medida pela malha (como a vê o jogador).
func _a_arvore_assenta(mundo, topo: Vector3, chao_do_centro: float) -> void:
	var arvore: Node3D = mundo.get_node_or_null("GameleiraTripo")
	if arvore == null:
		_conferir(false, "o vale não tem o modelo da gameleira (GameleiraTripo)")
		return
	var limites: AABB = arvore.get_meta("limites")
	_conferir(limites.size.y >= ALTURA_MINIMA and limites.size.y <= ALTURA_MAXIMA,
		"a gameleira posta tem %.1f m (esperado %.1f a %.1f)" % [limites.size.y, ALTURA_MINIMA, ALTURA_MAXIMA])
	_na_proporcao(limites.size.y)
	var pe_y := arvore.global_position.y + limites.position.y
	_conferir(pe_y <= chao_do_centro + 0.05 and pe_y >= chao_do_centro - 0.3,
		"o pé da gameleira está a %.2f m do chão do platô (esperado entre -0,3 e +0,05): ou boia sobre o monte, ou afunda" % (pe_y - chao_do_centro))
	var raiz_mais_longe := 0.0
	for no in arvore.find_children("*", "MeshInstance3D", true, false):
		var malha := (no as MeshInstance3D).mesh
		if malha == null:
			continue
		for superficie in malha.get_surface_count():
			var vertices: PackedVector3Array = malha.surface_get_arrays(superficie)[Mesh.ARRAY_VERTEX]
			for v in vertices:
				var global: Vector3 = (no as Node3D).global_transform * v
				if global.y - pe_y <= RAIZ_BAIXA:
					raiz_mais_longe = maxf(raiz_mais_longe, Vector2(global.x - topo.x, global.z - topo.z).length())
	_conferir(raiz_mais_longe <= PLATO_PLANO,
		"as raízes baixas da gameleira chegam a %.1f m do tronco, além do platô plano (%.1f m): as pontas pairam sobre o relevo" % [raiz_mais_longe, PLATO_PLANO])
	var pano: Node3D = mundo.get_node_or_null("Fitas GameleiraTripo")
	_conferir(pano != null, "o pano e as fitas da gameleira sumiram")
	if pano != null:
		# O nó da peça fica na origem do modelo; o meio dela é o meio da caixa (`limites`, sem giro).
		var caixa_do_pano: AABB = pano.get_meta("limites")
		var meio := pano.global_position + caixa_do_pano.get_center()
		var longe := Vector2(meio.x - topo.x, meio.z - topo.z).length()
		_conferir(longe <= 0.5, "o pano da gameleira está a %.2f m do eixo do tronco" % longe)
		var meia_largura := maxf(caixa_do_pano.size.x, caixa_do_pano.size.z) * 0.5
		_conferir(meia_largura <= RAIO_MAXIMO_DO_PANO, "o pano da gameleira tem %.2f m de raio (máximo %.1f): boia longe do tronco" % [meia_largura, RAIO_MAXIMO_DO_PANO])
		# O PANO ENCOSTA NO TRONCO (#228): o raio dele contra o do tronco LIMPO, acima das sapopemas (a ALTURA_DO_TRONCO_LIMPO
		# do pé, medida na malha como o `world_builder` mede para amarrar o pano), e não contra a altura em que o próprio
		# `world_builder` o amarrou: o pano posto na altura das sapopemas, onde o tronco "abre" a 2,5 m, se casaria com
		# elas e ficaria boiando longe do tronco de verdade (o defeito da #228). O certo é o tronco mais a folga de
		# amarrar (0,15) e a ondulação do tecido.
		var pe_da_malha := Vector3(topo.x, pe_y, topo.z)
		var raio_do_tronco: float = mundo._raio_do_tronco(arvore, pe_da_malha, ALTURA_DO_TRONCO_LIMPO)
		print("MEDIDA pano da gameleira: raio %.2f m contra o tronco de %.2f m a %.1f m do pé (folga %.2f m)" % [meia_largura, raio_do_tronco, ALTURA_DO_TRONCO_LIMPO, meia_largura - raio_do_tronco])
		_conferir(raio_do_tronco > 0.3, "não consegui medir o tronco da gameleira a %.1f m do pé" % ALTURA_DO_TRONCO_LIMPO)
		_conferir(meia_largura <= raio_do_tronco + FOLGA_DO_PANO,
			"o pano da gameleira tem %.2f m de raio e o tronco limpo %.2f m: sobram %.2f m (máximo %.2f), e o pano boia solto em volta dele" % [meia_largura, raio_do_tronco, meia_largura - raio_do_tronco, FOLGA_DO_PANO])


## Pergunta 4, a proporção: a gameleira é a maior da praia, e não esmaga a cena. Contra o viajante (o Pedro do
## catálogo, 1,75 m), a casa de taipa branca e o coqueiro, que a #228 apontou ("as raízes chegam quase à altura do
## viajante, a copa domina a paisagem"): com 18,2 m (14 x 1,3) ela dava 10,4 vezes o viajante, 4,1 a casa e 1,9 o
## coqueiro; com 11 m, 6,3, 2,5 e 1,2. As faixas separam os dois.
func _na_proporcao(altura_da_gameleira: float) -> void:
	var viajante := float(CatalogoAssets.PECAS["pedro"]["altura"])
	var casa := _altura_instanciada("casa_taipa")
	var coqueiro := _altura_instanciada("coqueiro")
	_conferir(viajante > 1.0 and casa > 1.0 and coqueiro > 1.0, "as medidas de comparação (viajante %.2f, casa %.2f, coqueiro %.2f) não vieram" % [viajante, casa, coqueiro])
	if viajante <= 1.0 or casa <= 1.0 or coqueiro <= 1.0:
		return
	var com_o_viajante := altura_da_gameleira / viajante
	var com_a_casa := altura_da_gameleira / casa
	var com_o_coqueiro := altura_da_gameleira / coqueiro
	print("MEDIDA gameleira %.1f m: %.1fx o viajante, %.1fx a casa branca, %.2fx o coqueiro" % [altura_da_gameleira, com_o_viajante, com_a_casa, com_o_coqueiro])
	_conferir(com_o_viajante >= VIAJANTE.x and com_o_viajante <= VIAJANTE.y,
		"a gameleira tem %.1fx a altura do viajante (faixa %.1f a %.1f): ou esmaga a cena, ou deixou de ser a árvore grande" % [com_o_viajante, VIAJANTE.x, VIAJANTE.y])
	_conferir(com_a_casa >= CASA.x and com_a_casa <= CASA.y,
		"a gameleira tem %.1fx a altura da casa branca (faixa %.1f a %.1f)" % [com_a_casa, CASA.x, CASA.y])
	_conferir(com_o_coqueiro >= COQUEIRO.x and com_o_coqueiro <= COQUEIRO.y,
		"a gameleira tem %.2fx a altura do coqueiro (faixa %.1f a %.1f): a maior da praia, sem esmagar" % [com_o_coqueiro, COQUEIRO.x, COQUEIRO.y])
	# A régua tem dentes: os 18,2 m de antes saem das três faixas.
	var antes := 14.0 * 1.3
	_conferir(antes / viajante > VIAJANTE.y and antes / casa > CASA.y and antes / coqueiro > COQUEIRO.y,
		"falsificação: a gameleira de 18,2 m (a de antes) devia reprovar nas três faixas")


## A altura da peça do catálogo posta na escala 1, medida na malha.
func _altura_instanciada(chave: String) -> float:
	var pai := Node3D.new()
	root.add_child(pai)
	var peca := CatalogoAssets.instanciar(chave, pai, Vector3.ZERO)
	var altura := 0.0
	if peca != null:
		altura = (peca.get_meta("limites") as AABB).size.y
	pai.free()
	return altura


## Pergunta 5, a navegação: ela anda em volta do tronco. Os pares são pontos opostos a RAIO_DA_VOLTA do eixo, os dois em
## chão que a malha cobre (a gameleira fica na beira da praia: do lado do mar o ponto pode cair na água).
func _a_navegacao_anda_em_volta(vale, mundo, topo: Vector3) -> void:
	var navegacao = vale.get("navegacao")
	_conferir(navegacao != null, "o vale não tem a malha de navegação")
	if navegacao == null:
		return
	var limite := Time.get_ticks_msec() + 90000
	while not (navegacao.esta_pronta() and navegacao.larga_pronta()) and Time.get_ticks_msec() < limite:
		await _quadros(10)
	_conferir(navegacao.esta_pronta() and navegacao.larga_pronta(), "a malha de navegação não ficou pronta em 90 s")
	if not navegacao.esta_pronta():
		return
	var mapa: RID = navegacao.get_world_3d().navigation_map
	var tronco := float(CatalogoAssets.PECAS["gameleira"]["tronco"]) * float(mundo.GAMELEIRA_TAMANHO)
	var pares := 0
	var mais_perto := INF
	var maior_desvio := 0.0
	for k in 8:
		var angulo := TAU * float(k) / 8.0 + 0.3
		var de := _na_volta(mundo, topo, angulo)
		var para := _na_volta(mundo, topo, angulo + PI)
		if not _na_malha(mapa, de) or not _na_malha(mapa, para):
			continue
		pares += 1
		var caminho: PackedVector3Array = navegacao.caminho(de, para)
		_conferir(caminho.size() >= 2, "não há caminho de um lado ao outro da gameleira (ângulo %.0f°)" % rad_to_deg(angulo))
		if caminho.size() < 2:
			continue
		var chega := Vector2(caminho[caminho.size() - 1].x - para.x, caminho[caminho.size() - 1].z - para.z).length()
		_conferir(chega <= 1.5, "o caminho de um lado ao outro da gameleira (ângulo %.0f°) para a %.1f m do destino" % [rad_to_deg(angulo), chega])
		var perto := _mais_perto_do_eixo(caminho, topo)
		mais_perto = minf(mais_perto, perto)
		_conferir(perto >= tronco, "o caminho de um lado ao outro da gameleira (ângulo %.0f°) passa a %.2f m do eixo: dentro do tronco (raio %.2f)" % [rad_to_deg(angulo), perto, tronco])
		var comprimento := 0.0
		for i in caminho.size() - 1:
			comprimento += Vector2(caminho[i + 1].x - caminho[i].x, caminho[i + 1].z - caminho[i].z).length()
		_conferir(comprimento <= 2.0 * RAIO_DA_VOLTA * DESVIO_MAXIMO,
			"o caminho de um lado ao outro da gameleira (ângulo %.0f°) tem %.1f m, mais que %.1fx a reta (%.1f m): o tronco empurra a malha para longe" % [rad_to_deg(angulo), comprimento, DESVIO_MAXIMO, 2.0 * RAIO_DA_VOLTA])
		maior_desvio = maxf(maior_desvio, comprimento / (2.0 * RAIO_DA_VOLTA))
		# A régua tem dentes: a reta de um lado ao outro atravessa o tronco, e a mesma conta a pega.
		_conferir(_mais_perto_do_eixo(PackedVector3Array([de, para]), topo) < tronco,
			"falsificação: a reta de um lado ao outro da gameleira devia passar dentro do tronco")
	_conferir(pares >= 3, "só %d par(es) de pontos em volta da gameleira cabem na malha (preciso de 3)" % pares)
	print("MEDIDA navegação em volta da gameleira: %d pares; o caminho passa a %.2f m do eixo no mínimo (tronco %.2f) e tem no máximo %.2fx a reta" % [pares, mais_perto, tronco, maior_desvio])


## O ponto do anel de RAIO_DA_VOLTA em volta do eixo, no chão.
func _na_volta(mundo, topo: Vector3, angulo: float) -> Vector3:
	var p := topo + Vector3(cos(angulo), 0.0, sin(angulo)) * RAIO_DA_VOLTA
	return Vector3(p.x, mundo.ground_height_at(p), p.z)


## O ponto está na malha (a menos de 0,6 m dela)?
func _na_malha(mapa: RID, p: Vector3) -> bool:
	return NavigationServer3D.map_get_closest_point(mapa, p).distance_to(p) < 0.6


## O quanto o caminho chega perto do eixo do tronco (no plano), amostrado de 0,25 em 0,25 m ao longo de cada trecho.
func _mais_perto_do_eixo(caminho: PackedVector3Array, topo: Vector3) -> float:
	var menor := INF
	var eixo := Vector2(topo.x, topo.z)
	for i in caminho.size() - 1:
		var a := Vector2(caminho[i].x, caminho[i].z)
		var b := Vector2(caminho[i + 1].x, caminho[i + 1].z)
		var passos := maxi(int(ceil(a.distance_to(b) / 0.25)), 1)
		for j in passos + 1:
			menor = minf(menor, a.lerp(b, float(j) / float(passos)).distance_to(eixo))
	return menor


## Pergunta 5, a colisão: o cilindro do tronco desceu junto com a altura (0,95, e não os 1,2 dos 14 m), está no eixo do
## tronco e assenta no chão. As sapopemas passam dele por projeto (#150), e quem barra o corpo é só o cilindro.
func _a_colisao_do_tronco(mundo, topo: Vector3) -> void:
	var corpo := mundo.get_node_or_null("GameleiraColisao") as StaticBody3D
	_conferir(corpo != null, "a gameleira não tem colisão (GameleiraColisao)")
	if corpo == null:
		return
	var cilindro: CylinderShape3D = null
	for filho in corpo.get_children():
		if filho is CollisionShape3D and (filho as CollisionShape3D).shape is CylinderShape3D:
			cilindro = (filho as CollisionShape3D).shape
	_conferir(cilindro != null, "a colisão da gameleira não é um cilindro de tronco")
	if cilindro == null:
		return
	var tronco := float(CatalogoAssets.PECAS["gameleira"]["tronco"]) * float(mundo.GAMELEIRA_TAMANHO)
	_conferir(is_equal_approx(cilindro.radius, tronco), "o cilindro do tronco tem %.2f m de raio (o catálogo manda %.2f)" % [cilindro.radius, tronco])
	var no_eixo := Vector2(corpo.global_position.x - topo.x, corpo.global_position.z - topo.z).length()
	_conferir(no_eixo <= 0.6, "o cilindro do tronco está a %.2f m do eixo do tronco" % no_eixo)
	var embaixo := corpo.global_position.y - cilindro.height * 0.5
	var chao: float = mundo.ground_height_at(corpo.global_position)
	_conferir(absf(embaixo - chao) <= 0.35, "o cilindro do tronco começa a %.2f m do chão (esperado ao nível dele)" % (embaixo - chao))


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("GAMELEIRA_OK: o chão em volta do sambaqui é plano, a borda do monte não flutua, o marco do caboclo é o tronco, e a árvore assenta no chão, na escala e na proporção do viajante, da casa e do coqueiro, com o pano no tronco, a colisão no eixo e a navegação dando a volta")
	else:
		print("gameleira: %d falha(s)" % falhas)
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
