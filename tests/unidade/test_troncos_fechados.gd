extends "res://tests/unidade/base.gd"
## Confere que O TRONCO DE CADA ÁRVORE SE VÊ POR FORA, e não pelo lado de dentro.
##
##     .\tools\prototipo_3d\testar.ps1 -Teste troncos_fechados
##
## "Árvores que parecem sem tronco ou com troncos vazados" (#156). Os GLBs do
## Tripo vêm com doubleSided e o catálogo liga o descarte de costas neles (-14 a
## -18 ms); em quase toda árvore isso não custa nada. Em algumas, porém, o Tripo
## fechou o fuste com os triângulos virados para DENTRO: de fora, a parede da
## frente é "de costas" e some, e o que se vê é o lado de dentro da parede do
## fundo, como um tronco oco ou fendido. Os GLBs têm doubleSided em todos os
## materiais, então a causa não é um material errado e sim o sentido da malha.
##
## A medida, por espécie: raios horizontais de 16 direções, de seis metros de
## distância, em 10 alturas do pé até metade da árvore (no máximo 2,5 m) e 9
## afastamentos de até 1,3 raio do tronco, no eixo dele. Para cada raio que
## acerta a malha, olha o PRIMEIRO triângulo: de costas (a frente da parede
## falta) ou de frente. As íntegras dão de 0 a 6%; as de costas, de 9% a 79%.
##
## O que se cobra, para cada árvore de tronco do catálogo:
##   · fração de costas acima do limite => está em `TRONCO_DE_COSTAS`, com as duas
##     faces; quem está na lista passa do piso (um pouco abaixo do limite, para a
##     fronteira não oscilar); íntegra e fora da lista segue com o descarte de
##     costas ligado (nada de duas faces global);
##   · o material de cada superfície confere com a lista (`cull_mode`).
##
## FALSIFICAÇÃO: `-- --falsificar=lista` esvazia a lista de quem tem as duas
## faces e `-- --falsificar=material` exige o descarte de costas em todas, como se
## nenhuma tivesse sido ajustada; os dois devem reprovar em pitangueira e ipê-amarelo.

const Catalogo = preload("res://scripts/prototipo_3d/catalogo_assets.gd")

## Acima disto o tronco é de costas e a árvore TEM de ter as duas faces. As
## íntegras ficam em até 6%, as de costas começam em 9%.
const LIMITE := 0.09
## Quem está em `TRONCO_DE_COSTAS` precisa passar disto: entre os dois, a medida
## é de fronteira (o ingazeiro leve dá 8,8%) e as duas escolhas valem.
const PISO := 0.07
const DIRECOES := 16
const ALTURAS := 10
const AFASTAMENTOS := 9
const DISTANCIA := 6.0

var falsificar := ""


func test_troncos_fechados() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--falsificar="):
			falsificar = arg.substr("--falsificar=".length())
	var lista: Array = [] if falsificar == "lista" else Catalogo.TRONCO_DE_COSTAS
	var chaves: Array = []
	for chave: String in Catalogo.PECAS:
		var spec: Dictionary = Catalogo.PECAS[chave]
		if not String(spec.get("tripo", "")).begins_with("arvores/") or not spec.has("altura"):
			continue
		# Árvore de tronco, e a versão de longe delas; planta rasteira não tem fuste.
		if spec.has("tronco") or chave.ends_with("_longe"):
			chaves.append(chave)
	chaves.sort()
	_conferir(chaves.size() >= 40, "o catálogo tem árvores de tronco (achei %d)" % chaves.size())

	var de_costas := 0
	for chave: String in chaves:
		if not Catalogo.tem_tripo(chave):
			continue
		var medida := _medir(chave)
		if medida.is_empty():
			_conferir(false, "'%s' não tem malha para medir" % chave)
			continue
		var fracao: float = medida["fracao"]
		var passa := fracao > LIMITE
		var na_lista := lista.has(chave)
		if passa:
			de_costas += 1
		print("  %-20s acertos=%4d  de costas=%5.1f%%  %s" % [chave, medida["acertos"], fracao * 100.0, "duas faces" if na_lista else ""])
		_conferir(int(medida["acertos"]) >= 100, "'%s' só tem %d raios acertando o tronco: a medida ficou vazia" % [chave, medida["acertos"]])
		if passa:
			_conferir(na_lista, "'%s' tem %.0f%% do tronco de costas e não tem as duas faces: aparece oco" % [chave, fracao * 100.0])
		elif na_lista:
			_conferir(fracao > PISO, "'%s' está em TRONCO_DE_COSTAS com só %.1f%% de costas: o ajuste é à toa" % [chave, fracao * 100.0])
		# O material do jogo confere com a lista (a medida decide a lista, acima).
		var esperado := BaseMaterial3D.CULL_DISABLED if na_lista else BaseMaterial3D.CULL_BACK
		if falsificar == "material":
			esperado = BaseMaterial3D.CULL_BACK
		for cull in _culls(chave):
			_conferir(cull == esperado,
				"'%s' tem cull_mode %d no material, e o tronco pede %d" % [chave, cull, esperado])
	_conferir(de_costas >= 5, "a medida acha árvores de tronco de costas (achei %d)" % de_costas)

	# Quem está na lista existe no catálogo (nome errado não ajusta nada).
	for chave: String in Catalogo.TRONCO_DE_COSTAS:
		_conferir(Catalogo.PECAS.has(chave), "'%s' está em TRONCO_DE_COSTAS mas não existe no catálogo" % chave)


## O `cull_mode` de cada superfície da cena do catálogo (já tratada por `cena`).
func _culls(chave: String) -> Array[int]:
	var resultado: Array[int] = []
	var cena: PackedScene = Catalogo.cena(chave)
	if cena == null:
		return resultado
	var raiz := cena.instantiate() as Node3D
	for filho in raiz.find_children("*", "MeshInstance3D", true, false):
		var instancia := filho as MeshInstance3D
		if instancia.mesh == null:
			continue
		for s in instancia.mesh.get_surface_count():
			var material := instancia.get_active_material(s) as BaseMaterial3D
			if material != null and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
				resultado.append(material.cull_mode)
	raiz.free()
	return resultado


func _relativa(raiz: Node, no: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var atual: Node = no
	while atual != null and atual != raiz:
		t = (atual as Node3D).transform * t
		atual = atual.get_parent()
	return t


## A fração dos raios cujo primeiro triângulo é de costas. {} sem malha.
func _medir(chave: String) -> Dictionary:
	var spec: Dictionary = Catalogo.PECAS[chave]
	var altura := float(spec["altura"])
	var raio_do_tronco := float(spec.get("tronco", 0.4))
	var cena: PackedScene = Catalogo.cena(chave)
	if cena == null:
		return {}
	var raiz := cena.instantiate() as Node3D
	var faces := PackedVector3Array()
	for filho in raiz.find_children("*", "MeshInstance3D", true, false):
		var instancia := filho as MeshInstance3D
		if instancia.mesh == null:
			continue
		var t := _relativa(raiz, instancia)
		for s in instancia.mesh.get_surface_count():
			if instancia.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var dados := instancia.mesh.surface_get_arrays(s)
			var vertices: PackedVector3Array = dados[Mesh.ARRAY_VERTEX]
			var indices := PackedInt32Array()
			if dados[Mesh.ARRAY_INDEX] != null:
				indices = dados[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for i in vertices.size():
					faces.append(t * vertices[i])
			else:
				for i in indices.size():
					faces.append(t * vertices[indices[i]])
	raiz.free()
	if faces.size() < 3:
		return {}
	var menor := INF
	var maior := -INF
	for v in faces:
		menor = minf(menor, v.y)
		maior = maxf(maior, v.y)
	if maior - menor < 0.0001:
		return {}
	var escala := altura / (maior - menor)

	# O eixo do tronco: a mediana do chão (x, z) dos vértices de 0,3 a 0,9 m do pé.
	var xs: Array[float] = []
	var zs: Array[float] = []
	for v in faces:
		var h := (v.y - menor) * escala
		if h > 0.3 and h < 0.9:
			xs.append(v.x)
			zs.append(v.z)
	var eixo := Vector2.ZERO
	if not xs.is_empty():
		xs.sort()
		zs.sort()
		eixo = Vector2(xs[int(xs.size() * 0.5)], zs[int(zs.size() * 0.5)])

	# Só os triângulos da faixa do tronco entram na malha de teste.
	var altura_maxima := minf(2.5, 0.5 * altura)
	var faixa := PackedVector3Array()
	for i in range(0, faces.size() - 2, 3):
		var alto := maxf(faces[i].y, maxf(faces[i + 1].y, faces[i + 2].y))
		var baixo := minf(faces[i].y, minf(faces[i + 1].y, faces[i + 2].y))
		if (alto - menor) * escala > 0.2 and (baixo - menor) * escala < altura_maxima + 0.2:
			faixa.append(faces[i])
			faixa.append(faces[i + 1])
			faixa.append(faces[i + 2])
	var malha := TriangleMesh.new()
	if faixa.is_empty() or not malha.create_from_faces(faixa):
		return {}

	var acertos := 0
	var de_costas := 0
	for d in DIRECOES:
		var angulo := TAU * float(d) / float(DIRECOES)
		var direcao := Vector3(cos(angulo), 0.0, sin(angulo))
		var lado := Vector3(-direcao.z, 0.0, direcao.x)
		for a in ALTURAS:
			var h := 0.3 + (altura_maxima - 0.3) * float(a) / float(ALTURAS - 1)
			for o in AFASTAMENTOS:
				var afastamento := raio_do_tronco * 1.3 * (-1.0 + 2.0 * float(o) / float(AFASTAMENTOS - 1))
				var origem := Vector3(eixo.x, 0.0, eixo.y) + (lado * afastamento - direcao * DISTANCIA) / escala
				origem.y = menor + h / escala
				var achado := malha.intersect_ray(origem, direcao)
				if achado.is_empty():
					continue
				acertos += 1
				var i := int(achado["face_index"]) * 3
				var normal := (faixa[i + 1] - faixa[i]).cross(faixa[i + 2] - faixa[i])
				# Triângulo de frente tem a ordem horária vista de quem o enxerga: a
				# normal por esta conta aponta para longe dele, e o raio anda no
				# mesmo sentido. Produto negativo: a frente está virada para dentro.
				if direcao.dot(normal) < 0.0:
					de_costas += 1
	return {"acertos": acertos, "fracao": float(de_costas) / float(maxi(acertos, 1))}
