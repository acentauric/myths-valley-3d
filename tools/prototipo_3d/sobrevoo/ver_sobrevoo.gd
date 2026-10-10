extends Node3D
## VER O SOBREVOO DO MENU, só ele: abra `ver_sobrevoo.tscn` no editor e rode a cena (F6).
##
## Monta o vale como a abertura monta (o `Cenario`, sem jogador, HUD nem moradores) e
## voa o trajeto gravado em `data/sobrevoo_menu.json`, com a mesma Catmull-Rom do menu.
## A linha do voo fica desenhada no vale: dourada onde há folga, amarela onde uma copa
## passa a menos de AVISO_M e vermelha a menos de PERIGO_M. Cada árvore que aperta o
## voo ganha um marcador com o nome dela na composição (`Coqueiro da orla 45`): é essa
## peça que se move em `scenes/prototipo_3d/composicao_vale.tscn` (Avulsos).
##
## A medida aqui é um guia (a distância até o tronco e a copa, em linha reta). Quem
## decide é o portão: `.\tools\prototipo_3d\testar.ps1 -Teste sobrevoo_livre`, que
## mede contra os triângulos reais e cobra 5 m de folga.
##
## TECLAS
##   Espaço       pausa e continua
##   ← / →        volta e avança 1 s (com Shift, 5 s)
##   ↑ / ↓        mais rápido / mais devagar (0,25× a 4×)
##   1            câmera do voo (o que o menu mostra)
##   2            câmera de fora, por cima e atrás, para ver por onde a linha passa
##   N            pula para o próximo trecho vermelho ou amarelo
##   L            liga e desliga a linha e os marcadores
##
## Mexeu na composição? Salve-a e rode esta cena de novo (F6).
##
## Os pontos do vão norte do voo (`VAO_NORTE_DO_SOBREVOO_M`, no world_builder.gd) não
## plantam tronco sorteado; o coqueiro posto à mão planta onde o autor pôs.

const TRAJETO := "res://data/sobrevoo_menu.json"
const SEGUNDOS := 72.0
## Folga, em metros, da copa ao olho: abaixo de PERIGO_M a linha fica vermelha.
const PERIGO_M := 5.0
const AVISO_M := 9.0
## A copa fica em volta do alto do tronco; o raio dela entra na conta (metros).
const RAIO_DA_COPA_M := 5.0
## As palmeiras abrem as folhas mais longe do alto do tronco.
const RAIO_DA_PALMEIRA_M := 7.0
const PALMEIRAS := ["coqueiro", "dendezeiro", "piacava"]
## Onde fica o meio da copa, na altura normalizada do GLB (0,98 é o topo).
const ALTO_DO_MODELO := 0.85

var _olho := PackedVector3Array()
var _alvo := PackedVector3Array()
var _t := 0.0
var _velocidade := 1.0
var _pausado := false
var _camera_de_fora := false
var _pronto := false
var _mpu := 1.0
var _folga_m := PackedFloat32Array()
var _culpado := []
var _camera: Camera3D
var _rotulo: Label
var _desenho: Node3D

@onready var _cenario: Node3D = $Cenario


func _ready() -> void:
	_camera = Camera3D.new()
	_camera.fov = 62.0
	_camera.far = 4000.0
	add_child(_camera)
	_camera.current = true
	var camada := CanvasLayer.new()
	add_child(camada)
	_rotulo = Label.new()
	_rotulo.position = Vector2(16, 12)
	_rotulo.add_theme_font_size_override("font_size", 18)
	_rotulo.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	_rotulo.add_theme_color_override("font_outline_color", Color.BLACK)
	_rotulo.add_theme_constant_override("outline_size", 6)
	camada.add_child(_rotulo)
	_rotulo.text = "montando o vale…"
	_carregar_trajeto()
	while not bool(_cenario.get("construido")):
		await get_tree().process_frame
	await get_tree().process_frame
	_mpu = float(_cenario.call("get_meters_per_unit")) if _cenario.has_method("get_meters_per_unit") else 1.0
	_medir_folgas()
	_desenhar()
	_pronto = true


func _carregar_trajeto() -> void:
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(TRAJETO))
	if not dados is Dictionary:
		push_error("ver_sobrevoo: %s ilegível" % TRAJETO)
		return
	for p in dados.get("olho", []):
		_olho.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
	for p in dados.get("alvo", []):
		_alvo.append(Vector3(float(p[0]), float(p[1]), float(p[2])))


## A mesma conta do menu (abertura.gd, `_catmull_rom`).
static func _catmull_rom(amostras: PackedVector3Array, progresso: float) -> Vector3:
	var n := amostras.size()
	var u := fposmod(progresso, 1.0) * n
	var i := floori(u)
	var t := u - i
	i = posmod(i, n)
	return amostras[i].cubic_interpolate(amostras[(i + 1) % n], amostras[(i - 1 + n) % n], amostras[(i + 2) % n], t)


# ---------------------------------------------------------------------------
# A MEDIDA: para cada amostra do voo, a copa mais perto.

## Os troncos do vale, em coordenadas do mundo: a base, o alto e quem é (nome na composição).
func _troncos() -> Array:
	var regiao: Node3D = _cenario.get("_region")
	if regiao == null:
		return []
	var nomes := {}
	var autorais: Variant = _cenario.get("_avulsos_autorais")
	if autorais is Dictionary:
		for id in autorais:
			var t: Transform3D = autorais[id]["transform"]
			nomes[Vector2i(roundi(t.origin.x * 100.0), roundi(t.origin.z * 100.0))] = String(id)
	var lista := []
	for tronco: Dictionary in regiao.get("_tree_trunks"):
		var ponto: Vector2 = tronco["point"]
		var base_local: Vector3 = tronco.get("base_tronco", Vector3(ponto.x, float(tronco["ground"]), ponto.y))
		var alto_local: Vector3 = tronco.get("alto_tronco", base_local + Vector3.UP)
		var eixo := (alto_local - base_local).normalized()
		if eixo.length_squared() < 0.5:
			eixo = Vector3.UP
		var base := regiao.to_global(base_local)
		var alto := regiao.to_global(base_local + eixo * float(tronco["height"]))
		# A copa é a do modelo, e não a do tronco de colisão (cortado em 4 u): o GLB do
		# Tripo chega com 0,98 no maior eixo, e a transformação da instância leva escala,
		# giro e inclinação. O alto fica a ALTO_DO_MODELO dessa altura.
		if tronco.has("transformacao"):
			var tf: Transform3D = tronco["transformacao"]
			alto = regiao.to_global(tf * Vector3(0.0, ALTO_DO_MODELO, 0.0))
		var nome := String(nomes.get(Vector2i(roundi(ponto.x * 100.0), roundi(ponto.y * 100.0)), ""))
		lista.append({"base": base, "alto": alto, "especie": String(tronco.get("especie", "")), "nome": nome, "ponto": ponto})
	return lista


func _medir_folgas() -> void:
	var troncos := _troncos()
	_folga_m.resize(_olho.size())
	var apertam := {}
	for i in _olho.size():
		var olho := _olho[i]
		var menor := INF
		var quem := -1
		for k in troncos.size():
			var tr: Dictionary = troncos[k]
			# Pula o que está longe na horizontal antes da conta do segmento.
			var dx := olho.x - (tr["alto"] as Vector3).x
			var dz := olho.z - (tr["alto"] as Vector3).z
			if dx * dx + dz * dz > 400.0:
				continue
			var perto := Geometry3D.get_closest_point_to_segment(olho, tr["base"], tr["alto"])
			var raio := RAIO_DA_PALMEIRA_M if PALMEIRAS.has(tr["especie"]) else RAIO_DA_COPA_M
			var d := (olho.distance_to(perto) * _mpu) - raio
			if d < menor:
				menor = d
				quem = k
		_folga_m[i] = menor
		if quem >= 0 and menor < AVISO_M:
			var atual: Dictionary = apertam.get(quem, {"folga": INF, "t": 0.0})
			if menor < float(atual["folga"]):
				apertam[quem] = {"folga": menor, "t": float(i) / _olho.size() * SEGUNDOS}
	_culpado = []
	for k in apertam:
		var tr: Dictionary = troncos[k]
		_culpado.append({"tronco": tr, "folga": float(apertam[k]["folga"]), "t": float(apertam[k]["t"])})
	_culpado.sort_custom(func(a, b) -> bool: return a["folga"] < b["folga"])
	print("VER_SOBREVOO: %d árvore(s) a menos de %.0f m do voo" % [_culpado.size(), AVISO_M])
	for c in _culpado:
		var tr: Dictionary = c["tronco"]
		print("  %-28s %-10s copa a %5.1f m do olho, aos %4.1f s, ponto %s, copa a %.0f m do chão" % [tr["nome"] if tr["nome"] != "" else "(sorteada)", tr["especie"], c["folga"], c["t"], str(tr["ponto"]), ((tr["alto"] as Vector3).y - (tr["base"] as Vector3).y) * _mpu])


# ---------------------------------------------------------------------------
# O DESENHO: a linha do voo e os marcadores.

func _desenhar() -> void:
	if _desenho != null:
		_desenho.queue_free()
	_desenho = Node3D.new()
	add_child(_desenho)
	var malha := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	malha.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
	for i in _olho.size() + 1:
		var k := i % _olho.size()
		malha.surface_set_color(_cor(_folga_m[k]))
		malha.surface_add_vertex(_olho[k])
	malha.surface_end()
	var linha := MeshInstance3D.new()
	linha.mesh = malha
	_desenho.add_child(linha)
	for c in _culpado:
		var tr: Dictionary = c["tronco"]
		var marca := MeshInstance3D.new()
		var esfera := SphereMesh.new()
		esfera.radius = (RAIO_DA_PALMEIRA_M if PALMEIRAS.has(tr["especie"]) else RAIO_DA_COPA_M) / _mpu
		esfera.height = esfera.radius * 2.0
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(_cor(c["folga"]), 0.35)
		esfera.material = mat
		marca.mesh = esfera
		_desenho.add_child(marca)
		marca.global_position = tr["alto"]
		var texto := Label3D.new()
		texto.text = "%s\ncopa a %.1f m (%.0f s)" % [tr["nome"] if tr["nome"] != "" else tr["especie"] + " sorteada", c["folga"], c["t"]]
		texto.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		texto.no_depth_test = true
		texto.font_size = 48
		texto.outline_size = 12
		texto.modulate = _cor(c["folga"])
		_desenho.add_child(texto)
		texto.global_position = (tr["alto"] as Vector3) + Vector3.UP * (2.0 + esfera.radius)


func _cor(folga: float) -> Color:
	if folga < PERIGO_M:
		return Color(1.0, 0.25, 0.2)
	if folga < AVISO_M:
		return Color(1.0, 0.85, 0.2)
	return Color(0.91, 0.77, 0.42)


# ---------------------------------------------------------------------------
# O VOO E AS TECLAS.

func _process(delta: float) -> void:
	if _olho.size() < 4:
		return
	if not _pausado and _pronto:
		_t = fposmod(_t + delta * _velocidade, SEGUNDOS)
	var progresso := _t / SEGUNDOS
	var olho := _catmull_rom(_olho, progresso)
	var alvo := _catmull_rom(_alvo, progresso)
	if _camera_de_fora:
		var adiante := (alvo - olho)
		adiante.y = 0.0
		adiante = adiante.normalized() if adiante.length() > 0.01 else Vector3.FORWARD
		_camera.global_position = olho - adiante * (40.0 / _mpu) + Vector3.UP * (30.0 / _mpu)
		_camera.look_at(olho)
	else:
		_camera.global_position = olho
		_camera.look_at(alvo)
	if not _pronto:
		return
	var i := posmod(roundi(progresso * _olho.size()), _olho.size())
	var folga := _folga_m[i]
	var chao: float = float(_cenario.call("ground_height_at", olho)) if _cenario.has_method("ground_height_at") else 0.0
	_rotulo.text = "SOBREVOO DO MENU   %4.1f / %.0f s   %s   %.2fx   câmera %s\naltura %.1f m   copa mais perto: %s\n%d árvore(s) a menos de %.0f m (a lista está na saída)   ·   Espaço pausa · ←/→ tempo · ↑/↓ velocidade · 1/2 câmera · N próximo aperto · L linha" % [
		_t, SEGUNDOS, "PAUSADO" if _pausado else "", _velocidade, "de fora" if _camera_de_fora else "do voo",
		(olho.y - chao) * _mpu, ("%.1f m" % folga) if folga < INF else "longe", _culpado.size(), AVISO_M]
	_rotulo.add_theme_color_override("font_color", _cor(folga) if folga < AVISO_M else Color(1, 0.95, 0.8))


func _unhandled_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey and evento.pressed and not evento.echo):
		return
	var passo := 5.0 if evento.shift_pressed else 1.0
	match evento.keycode:
		KEY_SPACE:
			_pausado = not _pausado
		KEY_LEFT:
			_t = fposmod(_t - passo, SEGUNDOS)
		KEY_RIGHT:
			_t = fposmod(_t + passo, SEGUNDOS)
		KEY_UP:
			_velocidade = minf(_velocidade * 2.0, 4.0)
		KEY_DOWN:
			_velocidade = maxf(_velocidade * 0.5, 0.25)
		KEY_1:
			_camera_de_fora = false
		KEY_2:
			_camera_de_fora = true
		KEY_N:
			_proximo_aperto()
		KEY_L:
			if _desenho != null:
				_desenho.visible = not _desenho.visible


## Pula para o começo do próximo trecho amarelo ou vermelho depois do instante atual.
func _proximo_aperto() -> void:
	var n := _olho.size()
	var inicio := posmod(roundi(_t / SEGUNDOS * n) + 1, n)
	var estava_apertado := _folga_m[posmod(inicio - 1, n)] < AVISO_M
	for passo in n:
		var i := (inicio + passo) % n
		var apertado := _folga_m[i] < AVISO_M
		if apertado and not estava_apertado:
			_t = float(i) / n * SEGUNDOS - 2.0
			_pausado = true
			return
		estava_apertado = apertado
