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
##      não passam do platô; a altura posta fica entre 9,5 e 12 m; o pano das fitas está centrado no
##      tronco e não o passa de mais de 0,7 m.

const RAIO_DO_ANEL := 5.5
const TOLERANCIA := 0.2
const ALTURA_MINIMA := 9.5
const ALTURA_MAXIMA := 12.0
## As raízes baixas: até esta altura do pé. O platô plano (`PLATO_RAIO` do renderer) as segura no chão.
const RAIZ_BAIXA := 0.7
const PLATO_PLANO := 7.0
const RAIO_MAXIMO_DO_PANO := 2.0

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


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("GAMELEIRA_OK: o chão em volta do sambaqui é plano, a borda do monte não flutua, o marco do caboclo é o tronco, e a árvore assenta no chão, na escala e com o pano no tronco")
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
