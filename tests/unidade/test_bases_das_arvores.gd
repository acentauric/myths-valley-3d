extends "res://tests/unidade/base.gd"
## Confere que NENHUMA ÁRVORE VEM EM CIMA DE UMA LAJE DE TERRA (#141).
##
##     .\tools\prototipo_3d\testar.ps1 -Teste bases_das_arvores
##
## "O ingazeiro junto ao caminho apresenta uma base de terra/vegetação elevada e
## com bordas muito marcadas, parecendo uma peça colocada sobre o terreno." Era
## isso mesmo: o GLB do ingazeiro (e as versões leve e de longe) nasceu do Tripo
## de pé numa laje de terra de uns 7 m por 5 m e meio metro de espessura, com
## fundo reto e beiras retas. Posta no vale, ela boiava no declive e aparecia
## como plataforma no plano. A laje saiu do próprio GLB (`tools/tripo/
## tirar_base_de_terra.py`; textura, UVs, materiais e escala ficaram) e a
## `altura` do catálogo foi recalculada para a árvore seguir do tamanho que tinha.
##
## O que denuncia uma laje, e que uma raiz não tem: ÁREA VIRADA PARA BAIXO junto do
## chão. O fundo reto da laje é um piso de dezenas de metros quadrados; as raízes e o
## pé de uma árvore, mesmo largos, somam de 0 a 3,5 m². A medida: a soma da área dos
## triângulos de base (centro abaixo de 0,7 m, normal com pelo menos 70% para baixo)
## de cada árvore do catálogo, na altura do catálogo. Quem passa de `LIMITE` é laje,
## salvo as sapopemas da gameleira, que se abrem em abas de 4 a 5 m de raio e estão
## em `ABAS_DE_RAIZ`.
##
## FALSIFICAÇÃO: `-- --falsificar=limite` baixa o limite a 0,2 m² e deve reprovar em
## toda árvore de raiz larga; `-- --falsificar=abas` tira a exceção da gameleira.
##
## A GAMELEIRA TAMBÉM É COBERTA (#228): as abas são raízes, mas sem teto elas escondiam a árvore
## posta numa bandeja de 18 m (14 × 1,3). Ela segue fora do `LIMITE` de laje, e passa a ter o seu,
## `LIMITE_DAS_ABAS`, que o tamanho de 11 m cumpre e o de 14 m ou mais não (a altura posta em si é
## cobrada em `tests/gameleira.gd`).
## O CAVACO (#141): tirada a laje, sobrava sob as raízes do ingazeiro um resto de terra laranja de
## beiras vivas. Nos dois ingazeiros que o plantio usa de perto (`ingazeiro`, `ingazeiro_leve`) a área
## de triângulos de cor de terra laranja (matiz de 0,04 a 0,12, saturação de 0,5 para cima), quase
## planos e colados ao chão (todos os vértices abaixo de 0,3 m), tem de caber em `LIMITE_DO_CAVACO`.
## `tools/tripo/tirar_base_de_terra.py --cavaco 0.3` é quem os tira. `-- --falsificar=cavaco` baixa o
## limite a zero (o pouco que sobra de cor parecida sob as raízes reprova) e deve reprovar.

const Catalogo = preload("res://scripts/prototipo_3d/catalogo_assets.gd")

## Acima disto a base é uma laje (m²). O maior pé de árvore do catálogo (a mata
## larga, de raiz tabular) soma 3,5; uma laje, mais de vinte.
const LIMITE := 5.0
## Até onde a base conta, do pé para cima (m), e quanto da normal tem de olhar para baixo.
const ALTURA_DA_BASE := 0.7
const VIRADA_PARA_BAIXO := 0.7
## O teto das abas de raiz (m²): a gameleira de 11 m soma de 28 a 40 (segundo o lado da face que
## o Godot dá ao triângulo); aos 14 m somaria de 42 a 62, e aos 18 m, mais de 70.
const LIMITE_DAS_ABAS := 44.0
## O cavaco de terra laranja que pode sobrar sob as raízes do ingazeiro (m²), e as árvores em que se confere.
const LIMITE_DO_CAVACO := 0.25
const COM_CAVACO := ["ingazeiro", "ingazeiro_leve"]
const ALTURA_DO_CAVACO := 0.3
const ABAS_DE_RAIZ := {
	"gameleira": "sapopemas abertas em abas de 4 a 5 u de raio, de que o tronco sai (medido em 03/10/2026)",
}

var falsificar := ""


func test_bases_das_arvores() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--falsificar="):
			falsificar = arg.substr("--falsificar=".length())
	var limite := 0.2 if falsificar == "limite" else LIMITE
	var chaves: Array = []
	for chave: String in Catalogo.PECAS:
		var spec: Dictionary = Catalogo.PECAS[chave]
		if not String(spec.get("tripo", "")).begins_with("arvores/") or not spec.has("altura"):
			continue
		# As árvores de tronco e as versões de longe delas; planta rasteira não tem laje.
		if spec.has("tronco") or chave.ends_with("_longe"):
			chaves.append(chave)
	chaves.sort()
	_conferir(chaves.size() >= 40, "o catálogo tem árvores (achei %d)" % chaves.size())

	var medidas := 0
	var maior := 0.0
	var maior_chave := ""
	for chave: String in chaves:
		if not Catalogo.tem_tripo(chave):
			continue
		var area := _area_da_base(chave)
		if area < 0.0:
			_conferir(false, "'%s' não tem malha para medir" % chave)
			continue
		medidas += 1
		var abas := ABAS_DE_RAIZ.has(chave) and falsificar != "abas"
		if not abas and area > maior:
			maior = area
			maior_chave = chave
		print("  %-20s base virada para baixo: %5.2f m²%s" % [chave, area, "  (abas de raiz)" if abas else ""])
		if abas:
			var teto := 0.2 if falsificar == "limite" else LIMITE_DAS_ABAS
			_conferir(area <= teto, "'%s' tem %.2f m² de base virada para baixo (teto das abas de raiz %.1f): grande demais para a medida do catálogo" % [chave, area, teto])
		if not abas:
			_conferir(area <= limite, "'%s' tem %.2f m² de base virada para baixo (limite %.1f): vem em cima de uma laje de terra" % [chave, area, limite])
	_conferir(medidas >= 40, "mediu só %d árvores" % medidas)
	for chave: String in ABAS_DE_RAIZ:
		_conferir(Catalogo.PECAS.has(chave), "'%s' está em ABAS_DE_RAIZ mas não existe no catálogo" % chave)
	var limite_do_cavaco := 0.02 if falsificar == "cavaco" else LIMITE_DO_CAVACO
	for chave: String in COM_CAVACO:
		var terra := _area_de_terra_laranja(chave)
		_conferir(terra >= 0.0, "'%s': não consegui ler a textura de cor para medir o cavaco de terra" % chave)
		if terra < 0.0:
			continue
		print("  %-20s terra laranja colada ao chão: %5.2f m²" % [chave, terra])
		_conferir(terra <= limite_do_cavaco, "'%s' tem %.2f m² de terra laranja colada ao chão (limite %.2f): sobra cavaco da laje sob as raízes" % [chave, terra, limite_do_cavaco])


func _relativa(raiz: Node, no: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var atual: Node = no
	while atual != null and atual != raiz:
		t = (atual as Node3D).transform * t
		atual = atual.get_parent()
	return t


## A área (m²) dos triângulos de base virados para baixo, na altura do catálogo.
## -1 sem malha.
func _area_da_base(chave: String) -> float:
	var altura := float(Catalogo.PECAS[chave]["altura"])
	var cena: PackedScene = Catalogo.cena(chave)
	if cena == null:
		return -1.0
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
		return -1.0
	var menor := INF
	var maior := -INF
	for v in faces:
		menor = minf(menor, v.y)
		maior = maxf(maior, v.y)
	if maior - menor < 0.0001:
		return -1.0
	var escala := altura / (maior - menor)
	var area := 0.0
	for i in range(0, faces.size() - 2, 3):
		var centro_y := (faces[i].y + faces[i + 1].y + faces[i + 2].y) / 3.0
		if (centro_y - menor) * escala >= ALTURA_DA_BASE:
			continue
		var normal := (faces[i + 1] - faces[i]).cross(faces[i + 2] - faces[i])
		var dobro := normal.length()
		if dobro < 0.000001:
			continue
		# A normal por esta conta aponta para longe de quem vê o triângulo de frente
		# (a ordem é horária no Godot); virado para baixo é a normal para CIMA.
		if normal.y / dobro < VIRADA_PARA_BAIXO:
			continue
		area += dobro * 0.5 * escala * escala
	return area


## A área (m²) de triângulos de cor de terra laranja, quase planos e colados ao chão, na altura do
## catálogo (a medida do `tirar_base_de_terra.py --cavaco`). -1 sem malha ou sem textura de cor legível.
func _area_de_terra_laranja(chave: String) -> float:
	var altura := float(Catalogo.PECAS[chave]["altura"])
	var cena: PackedScene = Catalogo.cena(chave)
	if cena == null:
		return -1.0
	var raiz := cena.instantiate() as Node3D
	var menor := INF
	var maior := -INF
	# Cada triângulo: três vértices no espaço do modelo e a cor média da textura nos três.
	var triangulos: Array[PackedVector3Array] = []
	var cores: Array[Color] = []
	for filho in raiz.find_children("*", "MeshInstance3D", true, false):
		var instancia := filho as MeshInstance3D
		if instancia.mesh == null:
			continue
		var t := _relativa(raiz, instancia)
		for s in instancia.mesh.get_surface_count():
			if instancia.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var material := instancia.mesh.surface_get_material(s) as BaseMaterial3D
			var textura: Texture2D = material.albedo_texture if material != null else null
			var imagem: Image = textura.get_image() if textura != null else null
			if imagem == null:
				raiz.free()
				return -1.0
			if imagem.is_compressed():
				imagem.decompress()
			var dados := instancia.mesh.surface_get_arrays(s)
			var vertices: PackedVector3Array = dados[Mesh.ARRAY_VERTEX]
			var uvs: PackedVector2Array = dados[Mesh.ARRAY_TEX_UV]
			var indices := PackedInt32Array()
			if dados[Mesh.ARRAY_INDEX] != null:
				indices = dados[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for i in vertices.size():
					indices.append(i)
			for i in range(0, indices.size() - 2, 3):
				var trio := PackedVector3Array()
				var soma := Color(0.0, 0.0, 0.0)
				for k in 3:
					var vertice := t * vertices[indices[i + k]]
					trio.append(vertice)
					menor = minf(menor, vertice.y)
					maior = maxf(maior, vertice.y)
					var uv := uvs[indices[i + k]] if uvs.size() == vertices.size() else Vector2.ZERO
					var x := clampi(int(uv.x * float(imagem.get_width())), 0, imagem.get_width() - 1)
					var y := clampi(int(uv.y * float(imagem.get_height())), 0, imagem.get_height() - 1)
					var pixel := imagem.get_pixel(x, y)
					soma = Color(soma.r + pixel.r, soma.g + pixel.g, soma.b + pixel.b)
				triangulos.append(trio)
				cores.append(Color(soma.r / 3.0, soma.g / 3.0, soma.b / 3.0))
	raiz.free()
	if triangulos.is_empty() or maior - menor < 0.0001:
		return -1.0
	var escala := altura / (maior - menor)
	var area := 0.0
	for i in triangulos.size():
		var trio := triangulos[i]
		if (maxf(trio[0].y, maxf(trio[1].y, trio[2].y)) - menor) * escala >= ALTURA_DO_CAVACO:
			continue
		var normal := (trio[1] - trio[0]).cross(trio[2] - trio[0])
		var dobro := normal.length()
		if dobro < 0.000001 or absf(normal.y) / dobro < 0.6:
			continue
		var cor := cores[i]
		if cor.h < 0.04 or cor.h > 0.12 or cor.s < 0.5 or cor.v < 0.3 or cor.v > 0.7:
			continue
		area += dobro * 0.5 * escala * escala
	return area
