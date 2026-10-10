extends "res://tests/suite/caso.gd"
## Confere AS COLISÕES DO VALE E A CÂMERA QUE ANDA ENTRE ELAS.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste colisoes_do_vale
##
## Duas queixas do dono, na mesma noite: "revise todas as colisões, há
## anomalias" e "a câmera dá um pulo ao passar na frente do cruzeiro; mantenha a
## câmera do personagem coerente, como se espera nesse tipo de jogo". As duas
## tinham a mesma raiz: o corpo não estava onde estava o desenho, e o braço da
## câmera batia em tudo o que tinha corpo, sem suavizar. Quatro perguntas:
##
##   1. QUEM BARRA A CÂMERA: o braço só bate na camada `CAMERA` (`camadas.gd`).
##      Chão, chão do mar, borda do quadro, construções, pedras e paredes dos
##      cômodos têm o bit; troncos, moradores, postes, mastros, cruzeiro, cercas
##      e barcos não. E todo corpo do catálogo tem forma ligada.
##   2. O CORPO ESTÁ ONDE ESTÁ O DESENHO: a caixa de cada peça contra o que o
##      modelo ocupa na altura do corpo (até 0,25 m por lado); o cilindro de cada
##      tronco contra o eixo do tronco medido na malha, por espécie, no conjunto
##      da mata e nas árvores nomeadas (até 0,35 u); o poço cobre o anel de
##      pedra; e o convés do saveiro não tem vela nem retranca no caminho.
##   3. O CONJUNTO DE CILINDROS NÃO DEIXA TRONCO AO ALCANCE SEM CORPO, com a
##      escolha do próprio jogo (`troncos_para_o_conjunto`).
##   4. A CÂMERA NÃO SALTA: passando ao lado do cruzeiro, girando junto de um
##      tronco da mata, girando no convés do saveiro e cruzando com um morador,
##      a distância da câmera ao pivô não muda mais que 0,5 m de um quadro de
##      1/60 s para o outro (30 m/s) — salvo ENTRANDO em geometria da camada
##      `CAMERA`, que ela não atravessa; e não fica mais de 0,1 s (seis
##      quadros) dentro de um corpo dessa camada.
##
## FALSIFICAÇÃO (05/10/2026): rodado antes das correções, reprova no cruzeiro
## (caixa de 2,6 m e câmera saltando de 8 para 1 m), na casa de taipa (caixa do
## beiral), no lampião e no mastro (cilindro fora do poste), na mata_alta, na
## mata_larga e na aroeira (cilindro no meio da copa), no poço (raio curto), no
## convés do saveiro (a vela barra) e nas camadas (não existia a da câmera).

## Recebe o vale montado do zero: reprovava no vale deixado pelos casos anteriores (a suíte, #242).
const VALE_NOVO := true

const Camadas = preload("res://scripts/prototipo_3d/camadas.gd")

## Quanto a caixa pode sobrar ou faltar, por lado, contra o desenho (m).
const FOLGA_DA_CAIXA := 0.25
## Quanto o eixo do cilindro pode se afastar do eixo do tronco desenhado (u).
const DESVIO_DO_TRONCO := 0.35
## Espécies cujo tronco medido não é um fuste só, com a razão.
const TRONCO_SEM_EIXO_UNICO := {
	# O ingazeiro abre em vários fustes desde o pé: a faixa mais estreita é a
	# moita deles, e o "eixo" é o meio dela. O cilindro fica nesse meio.
	"ingazeiro": "vários fustes desde o pé",
}
## A partir de que velocidade a distância da câmera ao pivô é um salto (m/s):
## 0,5 m num quadro de 1/60 s.
const SALTO := 30.0
## Por quanto tempo a câmera pode estar dentro de um corpo da camada CAMERA (s).
const DENTRO_MAXIMO := 0.1

var falhas := 0
var vale
var world
var player
var regiao
var CoqueiroCortado


## O estilo do vale em que o portão roda: `colisoes_do_vale_procedural.gd` o troca.
func _estilo_do_portao() -> String:
	return "tripo"


func _initialize() -> void:
	_run.call_deferred()


func _conferir(ok: bool, rotulo: String) -> void:
	if not ok:
		push_error("COLISOES_FALHOU: " + rotulo)
		print("FALHA: ", rotulo)
		falhas += 1


func _run() -> void:
	_conferir(change_scene_to_file("res://scenes/prototipo_3d/vale.tscn") == OK, "a cena do vale carrega")
	await _frames(4)
	await _mundo_pronto()
	await _frames(10)
	vale = current_scene
	world = vale.get("world")
	player = vale.get("player")
	regiao = world.get("_region") if world != null else null
	if world == null or player == null or regiao == null:
		_conferir(false, "o vale não montou o mundo, o jogador ou a região")
		_fechar()
		return
	CoqueiroCortado = load("res://scripts/prototipo_3d/coqueiro_cortado.gd")
	var CatalogoAssets = load("res://scripts/prototipo_3d/catalogo_assets.gd")
	player.set_physics_process(false)

	await _camadas(CatalogoAssets)
	if _estilo_do_portao() == "tripo":
		await _caixas(CatalogoAssets)
		await _troncos_da_mata()
		_troncos_nomeados()
		_postes()
		_poco()
		await _conves()
	else:
		_paredes_procedurais()
	_cobertura()
	await _camera()
	_fechar()


# --- 1. QUEM BARRA A CÂMERA --------------------------------------------------------

func _camadas(CatalogoAssets) -> void:
	print("")
	print("1. camadas")
	var spring: SpringArm3D = player.spring
	_conferir(spring.collision_mask == Camadas.CAMERA,
		"o braço da câmera bate na máscara %d, e não só na camada da câmera (%d)" % [spring.collision_mask, Camadas.CAMERA])
	var de_catalogo := {}
	for chave in CatalogoAssets.PECAS:
		de_catalogo[String(chave).capitalize() + "Colisao"] = chave
	var contagem := {}
	var pilha: Array[Node] = [world]
	while not pilha.is_empty():
		var no: Node = pilha.pop_back()
		for filho in no.get_children():
			pilha.append(filho)
		if not (no is CollisionObject3D):
			continue
		var corpo := no as CollisionObject3D
		var nome := String(corpo.name)
		var camera := (corpo.collision_layer & Camadas.CAMERA) != 0
		var deve := -1
		var classe := ""
		if nome == "Chão do mar" or nome == "Borda do quadro" or nome == "Colisão da terra":
			deve = 1
			classe = nome
		elif corpo.get_parent() == regiao and nome.begins_with("Colisão ") and not nome.begins_with("Colisão de tronco"):
			deve = 1
			classe = "faixas do terreno"
		elif nome.begins_with("Colisão de tronco"):
			deve = 0
			classe = "conjunto de troncos"
		elif nome == "Colisão da canoa":
			deve = 0
			classe = "barcos"
		elif corpo.is_in_group("moradores") or corpo is CharacterBody3D:
			deve = 0
			classe = "moradores e bichos"
		else:
			var chave := _chave_do_corpo(nome, de_catalogo)
			if chave != "":
				deve = 1 if CatalogoAssets.barra_camera(chave) else 0
				classe = chave
				var ligadas := 0
				for forma in corpo.get_children():
					if forma is CollisionShape3D and (forma as CollisionShape3D).shape != null and not (forma as CollisionShape3D).disabled:
						ligadas += 1
				_conferir(ligadas > 0, "o corpo de '%s' não tem forma ligada" % nome)
		if deve < 0:
			continue
		contagem[classe] = int(contagem.get(classe, 0)) + 1
		_conferir(camera == (deve == 1),
			"'%s' (%s) %s a câmera e não devia" % [nome, classe, "barra" if camera else "não barra"] if camera != (deve == 1) else "")
	var partes: PackedStringArray = []
	for classe in contagem:
		partes.append("%s %d" % [classe, contagem[classe]])
	print("  conferidos: ", ", ".join(partes))
	var esperados := ["Colisão da terra", "Chão do mar", "Borda do quadro", "conjunto de troncos"]
	if _estilo_do_portao() == "tripo":
		esperados.append_array(["cruzeiro", "capela"])
	for classe in esperados:
		_conferir(contagem.has(classe), "não achei nenhum corpo de '%s' para conferir a camada" % classe)
	# Os moradores ficam fora do mundo, num nó próprio: conferidos à parte.
	var moradores := root.get_tree().get_nodes_in_group("moradores")
	var com_camera := 0
	for m in moradores:
		if m is CollisionObject3D and ((m as CollisionObject3D).collision_layer & Camadas.CAMERA) != 0:
			com_camera += 1
	print("  moradores: %d, com a camada da câmera: %d" % [moradores.size(), com_camera])
	_conferir(com_camera == 0, "%d morador(es) barram a câmera" % com_camera)
	await _frames(1)


func _chave_do_corpo(nome: String, de_catalogo: Dictionary) -> String:
	# O Godot numera irmãos de mesmo nome ("CercaColisao2", "@StaticBody3D@...").
	var limpo := nome
	while limpo.length() > 0 and limpo[limpo.length() - 1] in "0123456789":
		limpo = limpo.substr(0, limpo.length() - 1)
	return String(de_catalogo.get(limpo, ""))


# --- 2. O CORPO ESTÁ ONDE ESTÁ O DESENHO -------------------------------------------

## Cada peça com caixa: a primeira de cada chave, contra o modelo dela.
func _caixas(CatalogoAssets) -> void:
	print("")
	print("2a. caixas contra o desenho (até %.2f m por lado)" % FOLGA_DA_CAIXA)
	var vistas := {}
	for corpo in world.get_children():
		if not (corpo is StaticBody3D):
			continue
		var nome := String((corpo as Node).name)
		if not nome.contains("Colisao"):
			continue
		var chave := ""
		for k in CatalogoAssets.PECAS:
			if nome.begins_with(String(k).capitalize() + "Colisao"):
				chave = k
		if chave == "" or vistas.has(chave):
			continue
		var spec: Dictionary = CatalogoAssets.PECAS[chave]
		if not (spec.get("caixa", false) or spec.has("caixas")):
			continue
		var modelo := _modelo_perto(String(chave).capitalize() + "Tripo", (corpo as Node3D).global_position)
		if modelo == null:
			continue
		vistas[chave] = true
		var pontos := _vertices_em(modelo, (corpo as Node3D).global_transform.affine_inverse())
		var caixas: Array[AABB] = []
		for forma in (corpo as Node).get_children():
			if forma is CollisionShape3D and (forma as CollisionShape3D).shape is BoxShape3D:
				var tamanho: Vector3 = ((forma as CollisionShape3D).shape as BoxShape3D).size
				caixas.append(AABB((forma as CollisionShape3D).position - tamanho * 0.5, tamanho))
		if caixas.is_empty():
			_conferir(false, "'%s' não tem caixa" % chave)
			continue
		var fundo := INF
		for c in caixas:
			fundo = minf(fundo, c.position.y)
		# A pegada do desenho na altura do corpo, e a das caixas que a cruzam.
		var desenho := _pegada(pontos, fundo + 0.15, fundo + 2.0)
		var corpo_xz := Rect2()
		var primeira := true
		for c in caixas:
			if c.end.y < fundo + 0.15 or c.position.y > fundo + 2.0:
				continue
			var r := Rect2(c.position.x, c.position.z, c.size.x, c.size.z)
			corpo_xz = r if primeira else corpo_xz.merge(r)
			primeira = false
		var pior := maxf(maxf(absf(corpo_xz.position.x - desenho.position.x), absf(corpo_xz.end.x - desenho.end.x)),
			maxf(absf(corpo_xz.position.y - desenho.position.y), absf(corpo_xz.end.y - desenho.end.y)))
		print("  %-20s corpo %.2f × %.2f, desenho %.2f × %.2f, pior lado %.2f" % [chave, corpo_xz.size.x, corpo_xz.size.y, desenho.size.x, desenho.size.y, pior])
		_conferir(pior <= FOLGA_DA_CAIXA,
			"a caixa de '%s' se afasta %.2f m do desenho na altura do corpo (parede invisível ou desenho sem corpo)" % [chave, pior])
		# Cada parte de uma peça composta não passa do desenho na altura dela.
		if caixas.size() > 1:
			for c in caixas:
				var ali := _pegada(pontos, c.position.y, c.end.y)
				var sobra := maxf(maxf(ali.position.x - c.position.x, c.end.x - ali.end.x), maxf(ali.position.y - c.position.z, c.end.z - ali.end.y))
				_conferir(sobra <= FOLGA_DA_CAIXA,
					"uma parte de '%s' sobra %.2f m além do desenho entre %.1f e %.1f m" % [chave, sobra, c.position.y - fundo, c.end.y - fundo])
	for chave in ["cruzeiro", "casa_taipa_azul", "capela"]:
		_conferir(vistas.has(chave), "não achei '%s' no vale para conferir a caixa" % chave)
	await _frames(1)


## O tronco de cada espécie da mata: o cilindro que o conjunto põe nele contra o
## eixo medido na malha da própria instância (`medir_o_corte`, a regra do corte).
func _troncos_da_mata() -> void:
	print("")
	print("2b. troncos do conjunto contra o eixo desenhado (até %.2f u)" % DESVIO_DO_TRONCO)
	var por_especie := {}
	for t in regiao._tree_trunks:
		var e := String(t.get("especie", "?"))
		if not por_especie.has(e) and t.has("visual") and t.has("transformacao") and not bool(t.get("cortado", false)):
			por_especie[e] = t
	var nomes := por_especie.keys()
	nomes.sort()
	for e in nomes:
		var t: Dictionary = por_especie[e]
		var ponto: Vector2 = t["point"]
		var pe: Vector3 = regiao.to_global(Vector3(ponto.x, float(t["ground"]), ponto.y))
		var eixo := _eixo_medido_na_instancia(t, pe)
		if not eixo.is_finite():
			print("  %-12s sem tronco medível" % e)
			continue
		player.global_position = pe + Vector3(2.5, 0.5, 0.0)
		# O conjunto se renova a cada 0,25 s; aqui, na hora, e não por quadros
		# (a máquina rápida passa dos 30 quadros antes dos 0,25 s).
		regiao._refresh_tree_collisions()
		await _frames(2)
		var perto := INF
		var raio_do_perto := 0.0
		for slot in regiao._tree_collision_pool:
			if not slot.active:
				continue
			var base: Vector3 = (slot.body as Node3D).global_transform * Vector3(0, -float((slot.shape as CylinderShape3D).height) * 0.5, 0)
			var d := Vector2(base.x, base.z).distance_to(eixo)
			if d < perto:
				perto = d
				raio_do_perto = (slot.shape as CylinderShape3D).radius
		# O eixo desenhado dentro do cilindro: tronco torto tem um eixo diferente a
		# cada altura, e a medida da faixa mais estreita cai em outra a cada
		# escala. Passar do raio é o cilindro fora da madeira.
		var tolerancia := maxf(DESVIO_DO_TRONCO, raio_do_perto)
		var tolerado := TRONCO_SEM_EIXO_UNICO.has(e)
		print("  %-12s cilindro mais perto do eixo desenhado: %.2f u (raio %.2f)%s" % [e, perto, raio_do_perto, " (tolerado: %s)" % TRONCO_SEM_EIXO_UNICO[e] if tolerado else ""])
		if not tolerado:
			_conferir(perto <= tolerancia,
				"em '%s' (mata) o cilindro mais perto está a %.2f u do tronco desenhado, e tem raio %.2f: atravessa-se a madeira e bate-se no ar" % [e, perto, raio_do_perto])


func _eixo_medido_na_instancia(t: Dictionary, pe: Vector3) -> Vector2:
	var visual := t.get("visual") as MultiMeshInstance3D
	if visual == null:
		return Vector2.INF
	var malha: Mesh = visual.multimesh.mesh
	# `transformacao` é do referencial da região, e não do nó do MultiMesh.
	var transf: Transform3D = regiao.global_transform * (t["transformacao"] as Transform3D)
	var superficies: Array[Dictionary] = []
	for s in malha.get_surface_count():
		superficies.append({"transformacao": transf, "vertices": malha.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]})
	# O pé é o da malha (a árvore é posta um palmo afundada no chão).
	var fundo := INF
	for superficie in superficies:
		for v in (superficie["vertices"] as PackedVector3Array):
			fundo = minf(fundo, ((superficie["transformacao"] as Transform3D) * v).y)
	pe.y = fundo
	var corte: Dictionary = CoqueiroCortado.medir_o_corte(superficies, pe)
	if not is_finite(float(corte["tronco"])):
		return Vector2.INF
	var eixo: Vector2 = corte["eixo"]
	return Vector2(pe.x + eixo.x, pe.z + eixo.y)


func _eixo_medido_no_modelo(modelo: Node3D, pe: Vector3) -> Vector2:
	var superficies: Array[Dictionary] = []
	var malhas: Array = modelo.find_children("*", "MeshInstance3D", true, false)
	if modelo is MeshInstance3D:
		malhas.append(modelo)
	for mi in malhas:
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null:
			continue
		for s in m.get_surface_count():
			superficies.append({"transformacao": (mi as MeshInstance3D).global_transform, "vertices": m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]})
	# O pé é o do MODELO (a árvore nomeada é posta um palmo afundada no chão), que
	# é de onde a regra do corte conta as faixas.
	var fundo := INF
	for superficie in superficies:
		for v in (superficie["vertices"] as PackedVector3Array):
			fundo = minf(fundo, ((superficie["transformacao"] as Transform3D) * v).y)
	pe.y = fundo
	var corte: Dictionary = CoqueiroCortado.medir_o_corte(superficies, pe)
	if not is_finite(float(corte["tronco"])):
		return Vector2.INF
	var eixo: Vector2 = corte["eixo"]
	return Vector2(pe.x + eixo.x, pe.z + eixo.y)


## As árvores nomeadas: o cilindro delas contra o eixo do modelo delas.
func _troncos_nomeados() -> void:
	var vistos := {}
	for a in world.get("_arvores_nomeadas"):
		var e := String(a.get("especie", ""))
		var modelo = a.get("visual")
		var corpo = a.get("colisao")
		if vistos.has(e) or not (modelo is Node3D) or not (corpo is StaticBody3D) or not is_instance_valid(corpo):
			continue
		vistos[e] = true
		var forma := (corpo as Node).get_child(0) as CollisionShape3D
		if forma == null or not (forma.shape is CylinderShape3D):
			continue
		var c: Vector3 = (corpo as Node3D).global_position
		var pe: Vector3 = a["pos"]
		var eixo := _eixo_medido_no_modelo(modelo, pe)
		if not eixo.is_finite():
			continue
		var desvio := Vector2(c.x, c.z).distance_to(eixo)
		var tolerado := TRONCO_SEM_EIXO_UNICO.has(e) or e == "coqueiro"
		print("  %-12s (nomeada) cilindro a %.2f u do eixo desenhado%s" % [e, desvio, " (tolerado)" if tolerado else ""])
		if not tolerado:
			_conferir(desvio <= maxf(DESVIO_DO_TRONCO, (forma.shape as CylinderShape3D).radius), "a árvore nomeada '%s' tem o cilindro a %.2f u do tronco desenhado" % [e, desvio])


## O poste do lampião e o pau do mastro: o cilindro no pau, e não no meio da caixa.
func _postes() -> void:
	for chave in ["lampiao_poste", "mastro_pano"]:
		var prefixo := String(chave).capitalize()
		var achou := false
		for corpo in world.get_children():
			if not (corpo is StaticBody3D) or not String((corpo as Node).name).begins_with(prefixo + "Colisao"):
				continue
			var forma := (corpo as Node).get_child(0) as CollisionShape3D
			if forma == null or not (forma.shape is CylinderShape3D):
				continue
			var c: Vector3 = (corpo as Node3D).global_position
			var modelo := _modelo_perto(prefixo + "Tripo", c)
			if modelo == null:
				continue
			var pe := c - Vector3(0, (forma.shape as CylinderShape3D).height * 0.5, 0)
			var eixo := _eixo_medido_no_modelo(modelo, pe)
			if not eixo.is_finite():
				continue
			achou = true
			var desvio := Vector2(c.x, c.z).distance_to(eixo)
			print("  %-12s cilindro a %.2f u do pau desenhado" % [chave, desvio])
			_conferir(desvio <= DESVIO_DO_TRONCO, "o cilindro de '%s' está a %.2f u do pau desenhado" % [chave, desvio])
			break
		_conferir(achou, "não achei '%s' com modelo no vale para conferir o cilindro" % chave)


## O poço: o cilindro cobre o anel de pedra (o lado mais curto dele).
func _poco() -> void:
	for corpo in world.get_children():
		if not (corpo is StaticBody3D) or not String((corpo as Node).name).begins_with("PocoColisao"):
			continue
		var forma := (corpo as Node).get_child(0) as CollisionShape3D
		var c: Vector3 = (corpo as Node3D).global_position
		var modelo := _modelo_perto("PocoTripo", c)
		if modelo == null or forma == null or not (forma.shape is CylinderShape3D):
			continue
		var cilindro := forma.shape as CylinderShape3D
		var fundo := -cilindro.height * 0.5
		var anel := _pegada(_vertices_em(modelo, (corpo as Node3D).global_transform.affine_inverse()), fundo + 0.3, fundo + 1.1)
		var meio_lado := minf(anel.size.x, anel.size.y) * 0.5
		print("  poço: raio %.2f, meio lado curto do anel %.2f" % [cilindro.radius, meio_lado])
		_conferir(cilindro.radius >= meio_lado - 0.1, "o poço tem raio %.2f para um anel de meio lado %.2f: o corpo entra na pedra" % [cilindro.radius, meio_lado])
		return
	_conferir(false, "não achei o poço com modelo no vale")


## No convés do saveiro: da proa para a popa, na altura do peito e da cabeça, ao
## lado do mastro, não há parede (a vela e a retranca não têm corpo); e o mastro
## tem.
func _conves() -> void:
	print("")
	print("2c. convés do saveiro")
	var saveiro = vale.get("saveiro")
	if saveiro == null or saveiro.get("barco") == null:
		print("  sem saveiro no vale (estilo sem o modelo)")
		return
	var barco: Node3D = saveiro.barco
	if not barco.visible:
		saveiro.set("_presente", true)
		saveiro._ver_o_barco()
		await _fisica(3)
	var conves: Vector3 = saveiro.ponto_do_conves()
	if not conves.is_finite():
		print("  sem ponto de convés")
		return
	var espaco := barco.get_world_3d().direct_space_state
	var popa := (barco.global_transform.basis * Vector3(-1, 0, 0))
	popa.y = 0.0
	popa = popa.normalized()
	# Os raios correm paralelos ao eixo do barco, um palmo e meio (o raio do corpo
	# mais o do mastro) para cada lado do mastro: o que bate aí não é o mastro.
	var mastro := barco.get_node_or_null("Colisão da canoa/Mastro") as Node3D
	var z_do_mastro := mastro.position.z if mastro != null else 0.0
	var no_barco := barco.to_local(conves)
	for altura in [1.2, 1.5, 1.76]:
		for desvio in [0.65, -0.65]:
			var de: Vector3 = barco.to_global(Vector3(no_barco.x, no_barco.y, z_do_mastro + desvio)) + Vector3.UP * altura
			var raio := PhysicsRayQueryParameters3D.create(de, de + popa * 4.0, 1, [player.get_rid()])
			var bateu := espaco.intersect_ray(raio)
			var ate := 4.0 if bateu.is_empty() else de.distance_to(bateu["position"])
			print("  a %.2f m do convés, %+.2f do mastro: livre por %.2f m%s" % [altura, desvio, ate, "" if bateu.is_empty() else " (bate em %s)" % str((bateu["collider"] as Node).name)])
			_conferir(ate >= 3.0, "no convés, a %.2f m de altura, o corpo bate a %.2f m indo para a popa: a vela ou a retranca têm corpo" % [altura, ate])
	# O mastro barra: o raio pelo eixo do barco, à altura do peito, bate perto do meio.
	var meio: Vector3 = barco.global_transform * Vector3(0, 0, 0)
	var de2 := Vector3(conves.x, conves.y + 1.2, conves.z)
	var alvo := Vector3(meio.x, de2.y, meio.z)
	var pelo_mastro := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(de2 + (de2 - alvo).normalized() * 0.1, alvo + (alvo - de2).normalized() * 3.0, 1, [player.get_rid()]))
	print("  pelo eixo, rumo ao mastro: %s" % ("livre" if pelo_mastro.is_empty() else "bate em %s" % str((pelo_mastro["collider"] as Node).name)))
	_conferir(not pelo_mastro.is_empty(), "o mastro do saveiro não tem corpo")


## No estilo procedural as casas e a igreja são caixas de código
## (`WorldBuilder._house`, `_igreja_procedural`): as paredes barram a câmera, e
## a cerca e o poste não. Sem isso a câmera entraria nas casas.
func _paredes_procedurais() -> void:
	print("")
	print("2d. paredes procedurais")
	var paredes := 0
	var finos := 0
	var finos_com_camera := 0
	var sem_camera: Array[String] = []
	for corpo in world.get_children():
		if not (corpo is StaticBody3D):
			continue
		for forma in (corpo as Node).get_children():
			if not (forma is CollisionShape3D and (forma as CollisionShape3D).shape is BoxShape3D):
				continue
			var tamanho: Vector3 = ((forma as CollisionShape3D).shape as BoxShape3D).size
			var com_camera := ((corpo as CollisionObject3D).collision_layer & Camadas.CAMERA) != 0
			if tamanho.y > 2.8 and tamanho.x > 2.0 and tamanho.z > 2.0:
				paredes += 1
				if not com_camera:
					sem_camera.append(str(tamanho))
			elif tamanho.x < 0.3 and tamanho.z < 0.3 and tamanho.y > 0.5:
				finos += 1
				finos_com_camera += 1 if com_camera else 0
	print("  corpos de parede: %d; postes de cerca: %d" % [paredes, finos])
	_conferir(paredes >= 4, "só %d parede(s) procedural(is) achada(s): a casa e a igreja não foram montadas?" % paredes)
	_conferir(sem_camera.is_empty(), "parede(s) procedural(is) sem a camada da câmera: %s (a câmera entra na casa)" % str(sem_camera))
	_conferir(finos_com_camera == 0, "%d poste(s) de cerca barram a câmera" % finos_com_camera)


# --- 3. COBERTURA DO CONJUNTO -------------------------------------------------------

func _cobertura() -> void:
	print("")
	print("3. cobertura do conjunto de troncos")
	if not regiao.has_method("troncos_para_o_conjunto"):
		_conferir(false, "a região não diz quais troncos ganham corpo (`troncos_para_o_conjunto`)")
		return
	var inicio := Time.get_ticks_msec()
	var troncos: Array = regiao._tree_trunks
	var falhas_aqui := 0
	var exemplo := ""
	var conferidos := 0
	for i in range(troncos.size()):
		var t: Dictionary = troncos[i]
		if bool(t.get("cortado", false)):
			continue
		var base: Vector3 = regiao.base_do_tronco(t)
		var ponto := Vector2(base.x, base.z)
		var escolhidos: Array = regiao.troncos_para_o_conjunto(ponto)
		if escolhidos.size() < regiao.TREE_COLLISION_POOL_SIZE:
			continue
		conferidos += 1
		var tem := {}
		for e in escolhidos:
			tem[(e["base_tronco"] as Vector3).snapped(Vector3.ONE * 0.01)] = true
		var distancia_da_ultima: float = sqrt(float(escolhidos[escolhidos.size() - 1]["distance_squared"]))
		if distancia_da_ultima >= 3.0:
			continue
		# A última vaga ficou a menos de 3 u: algum tronco mais perto que 3 u ficou de fora?
		for outro in troncos:
			if bool(outro.get("cortado", false)):
				continue
			var b: Vector3 = regiao.base_do_tronco(outro)
			if Vector2(b.x, b.z).distance_to(ponto) < 3.0 and not tem.has(b.snapped(Vector3.ONE * 0.01)):
				falhas_aqui += 1
				exemplo = "%s em %s" % [String(t.get("especie", "")), str(ponto.round())]
				break
	print("  %d troncos, %d com o conjunto cheio em volta; %d pontos com tronco a < 3 u sem corpo (%d ms)" % [troncos.size(), conferidos, falhas_aqui, Time.get_ticks_msec() - inicio])
	_conferir(falhas_aqui == 0, "%d ponto(s) do mapa com tronco a menos de 3 u sem corpo; ex.: %s" % [falhas_aqui, exemplo])


# --- 4. A CÂMERA NÃO SALTA ----------------------------------------------------------

## As poses da câmera em que cada cena é percorrida: (inclinação, distância). A de
## sempre — atrás e um pouco acima, a 8 m — nunca aperta o braço; a de baixo e de
## perto (a câmera sob o horizonte, a 3 m) o encosta no chão e nas paredes.
const POSES_DA_CAMERA := [Vector2(-0.19, 8.0), Vector2(0.2, 3.0)]

var _pose: Vector2 = POSES_DA_CAMERA[0]


func _camera() -> void:
	print("")
	print("4. a câmera (saltos acima de %.0f m/s fora de geometria da câmera; dentro dela no máximo %.1f s)" % [SALTO, DENTRO_MAXIMO])
	for pose in POSES_DA_CAMERA:
		_pose = pose
		print("  pose: inclinação %+.2f, distância %.1f" % [pose.x, pose.y])
		await _camera_na_pose()


func _camera_na_pose() -> void:
	var cruz: Vector3 = world.ancoras.get("Cruzeiro", Vector3.INF)
	var igreja: Vector3 = world.ancoras.get("Igreja", Vector3.INF)
	_conferir(cruz.is_finite() and igreja.is_finite(), "o vale não tem âncora do cruzeiro ou da igreja")
	if cruz.is_finite() and igreja.is_finite():
		var frente := Vector3(cruz.x - igreja.x, 0, cruz.z - igreja.z).normalized()
		var lado := frente.cross(Vector3.UP).normalized()
		for lado_da_camera in [1.0, -1.0]:
			var rumo: Vector3 = lado * lado_da_camera
			await _encaixar(world.ground_position(cruz - rumo * 2.5 - frente * 3.5, 0.05), atan2(rumo.x, rumo.z))
			await _seguir("cruzeiro, câmera do lado %+d" % int(lado_da_camera), 90, func(i: int, _dt: float) -> void:
				player.global_position = world.ground_position(cruz - rumo * 2.5 + frente * (-3.5 + 7.0 * float(i) / 90.0), 0.05))
	# Girando junto de um tronco da mata.
	for especie in ["mata_alta", "mata_larga"]:
		var tronco: Dictionary = {}
		for t in regiao._tree_trunks:
			if String(t.get("especie", "")) == especie and not bool(t.get("cortado", false)):
				tronco = t
				break
		if tronco.is_empty():
			continue
		var base: Vector3 = regiao.to_global(regiao.base_do_tronco(tronco))
		var onde: Vector3 = world.ground_position(base + Vector3(1.6, 0, 0), 0.05)
		await _encaixar(onde, 0.0)
		regiao._refresh_tree_collisions()
		await _frames(2)
		await _seguir("mata (%s), girando 360°" % especie, 120, func(i: int, _dt: float) -> void:
			player._yaw = TAU * float(i) / 120.0)
	# No convés do saveiro, girando.
	var saveiro = vale.get("saveiro")
	if saveiro != null and saveiro.ponto_do_conves().is_finite():
		await _encaixar(saveiro.ponto_do_conves(), 0.0)
		await _seguir("convés do saveiro, girando 360°", 120, func(i: int, _dt: float) -> void:
			player._yaw = TAU * float(i) / 120.0)
	# Cruzando com um morador: o braço da câmera passa por ele.
	var morador: Node3D = null
	for m in root.get_tree().get_nodes_in_group("moradores"):
		if m is Node3D and (m as Node3D).is_visible_in_tree() and (m as Node).can_process():
			morador = m
			break
	_conferir(morador != null, "não achei morador no vale para cruzar com ele")
	if morador != null:
		var centro := morador.global_position
		var rumo := Vector3(1, 0, 0)
		var atras := Vector3(0, 0, 1)
		await _encaixar(world.ground_position(centro - atras * 1.2 - rumo * 3.0, 0.05), atan2(-atras.x, -atras.z))
		await _seguir("cruzando com um morador", 90, func(i: int, _dt: float) -> void:
			var c: Vector3 = morador.global_position
			player.global_position = world.ground_position(c - atras * 1.2 + rumo * (-3.0 + 6.0 * float(i) / 90.0), 0.05))


## Põe o jogador num lugar com a câmera encaixada, como num teleporte.
func _encaixar(onde: Vector3, yaw: float) -> void:
	player.global_position = onde
	player._yaw = yaw
	player._pitch = _pose.x
	player._distance = _pose.y
	player._apply_camera()
	if player.has_method("_encaixar_a_camera"):
		player._encaixar_a_camera()
	await _fisica(4)
	await _frames(4)


## Anda `quadros` quadros chamando `passo(i, dt)` antes de cada um, e mede a
## distância da câmera ao pivô a cada quadro.
func _seguir(rotulo_puro: String, quadros: int, passo: Callable) -> void:
	var rotulo := "%s [%+.2f, %.0f m]" % [rotulo_puro, _pose.x, _pose.y]
	var camera: Camera3D = player.camera
	var pivo: Node3D = player.camera_pivot
	var espaco: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var esfera := SphereShape3D.new()
	esfera.radius = 0.18
	var so_camera := PhysicsShapeQueryParameters3D.new()
	so_camera.shape = esfera
	so_camera.collision_mask = Camadas.CAMERA
	so_camera.exclude = [player.get_rid()]
	var dentro := PhysicsPointQueryParameters3D.new()
	dentro.collision_mask = Camadas.CAMERA
	var anterior := -1.0
	var saltos := 0
	var pior_salto := 0.0
	var tempo_dentro := 0.0
	var pior_dentro := 0.0
	var menor := INF
	var serie: PackedStringArray = []
	for i in quadros:
		passo.call(i, 1.0 / 60.0)
		await process_frame
		# Quadro rápido não encurta o limite: no mínimo 1/60 s, que é o 0,5 m do cabeçalho.
		var dt: float = maxf(player.get_process_delta_time(), 1.0 / 60.0)
		var d := camera.global_position.distance_to(pivo.global_position)
		menor = minf(menor, d)
		if anterior >= 0.0:
			var velocidade := absf(d - anterior) / dt
			if velocidade > SALTO:
				var permitido := false
				if d < anterior:
					# Entrando em geometria da câmera: o braço, só com a camada
					# CAMERA, para antes de onde a câmera estava?
					var origem := pivo.global_position
					var rumo := (camera.global_position - origem).normalized()
					so_camera.transform = Transform3D(Basis(), origem)
					so_camera.motion = rumo * anterior
					var r := espaco.cast_motion(so_camera)
					permitido = r.size() >= 2 and r[0] < 1.0 and anterior * r[0] < anterior - 0.3
				if not permitido:
					saltos += 1
					pior_salto = maxf(pior_salto, absf(d - anterior))
		dentro.position = camera.global_position
		if not espaco.intersect_point(dentro, 1).is_empty():
			tempo_dentro += dt
			pior_dentro = maxf(pior_dentro, tempo_dentro)
		else:
			tempo_dentro = 0.0
		if i % 10 == 0:
			serie.append("%.1f" % d)
		anterior = d
	print("  %-34s saltos %d (pior %.2f m), menor braço %.2f m, dentro da geometria por até %.2f s" % [rotulo, saltos, pior_salto, menor, pior_dentro])
	print("    braço a cada 10 quadros: ", " ".join(serie))
	_conferir(saltos == 0, "%s: a câmera saltou %d vez(es), o pior %.2f m de um quadro para o outro" % [rotulo, saltos, pior_salto])
	_conferir(pior_dentro <= DENTRO_MAXIMO, "%s: a câmera ficou %.2f s dentro de geometria que ela não atravessa" % [rotulo, pior_dentro])


# --- utilidades ---------------------------------------------------------------------

## O modelo com este prefixo de nome mais perto de `onde`, em todo o mundo.
func _modelo_perto(prefixo: String, onde: Vector3) -> Node3D:
	var melhor: Node3D = null
	var menor := INF
	for no in world.find_children(prefixo + "*", "Node3D", true, false):
		var d := (no as Node3D).global_position.distance_to(onde)
		if d < menor:
			menor = d
			melhor = no
	return melhor if menor < 30.0 else null


## Os vértices do modelo levados por `para` (do mundo para o referencial pedido).
func _vertices_em(modelo: Node3D, para: Transform3D) -> PackedVector3Array:
	var pontos := PackedVector3Array()
	var malhas: Array = modelo.find_children("*", "MeshInstance3D", true, false)
	if modelo is MeshInstance3D:
		malhas.append(modelo)
	for mi in malhas:
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null:
			continue
		var t: Transform3D = para * (mi as MeshInstance3D).global_transform
		for s in m.get_surface_count():
			for v in (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				pontos.append(t * v)
	return pontos


## A pegada em X/Z (Rect2 com X e Z) dos pontos entre as alturas `de` e `ate`.
func _pegada(pontos: PackedVector3Array, de: float, ate: float) -> Rect2:
	var menor := Vector2(INF, INF)
	var maior := Vector2(-INF, -INF)
	for p in pontos:
		if p.y < de or p.y > ate:
			continue
		menor = Vector2(minf(menor.x, p.x), minf(menor.y, p.z))
		maior = Vector2(maxf(maior.x, p.x), maxf(maior.y, p.z))
	if not is_finite(menor.x):
		return Rect2()
	return Rect2(menor, maior - menor)


func _fechar() -> void:
	print("")
	if falhas == 0:
		print("COLISOES_DO_VALE_OK (%s): só o chão, as paredes e a água barram a câmera; caixas, cilindros e o convés do saveiro estão onde está o desenho; nenhum tronco ao alcance fica sem corpo; e a câmera não salta no cruzeiro, na mata, no convés nem junto de um morador" % _estilo_do_portao())
	else:
		print("colisões do vale (%s): %d falha(s)" % [_estilo_do_portao(), falhas])
	quit(1 if falhas > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _mundo_pronto() -> void:
	for i in range(6000):
		var mundo := get_first_node_in_group("mundo")
		if mundo != null and mundo.construido:
			break
		await process_frame
	await process_frame
	await process_frame
