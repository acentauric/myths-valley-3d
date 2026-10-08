extends Control
## Divisas cadastrais projetadas pela câmera real do mapa, sem corpos no vale (#203).
##
## Parecem parte do mapa pintado, não uma caixa de debug:
##  - FORMA: o lote do cadastro (retângulo) vira um contorno orgânico de 48 pontos, cantos
##    arredondados e uma ondulação leve e fixa por lote. Só cerca de verdade é reta, e as
##    cercas já estão no vale; a divisa do mapa nunca é um retângulo que corta árvores.
##  - TRAÇO: tracejado fino em sépia/ouro (verde-musgo nas suas terras), com um filete
##    translúcido na borda e preenchimento quase imperceptível.
##  - LEGENDA: "Terra da Dona Zefa · à venda por 1800 réis", "… · de Seu Benedito" ou
##    "… · Sua terra", na sans de leitura (#199), com uma plaquinha desenhada do lado
##    (placa de venda, casa ou marco). A legenda foge de "Você" e dos marcadores dos lugares.
##  - QUANDO MOSTRAR: as suas terras e as que estão à venda aparecem sempre; as dos outros
##    só no zoom de perto (o de quando o mapa abre) e somem aos poucos ao afastar, para o
##    mapa geral não ficar poluído.
const Identidade = preload("res://scripts/prototipo_3d/identidade.gd")
const PONTOS := 48
const COR_ALHEIA := Color("c9a45c")
const COR_SUA := Color("8dbf7a")
const COR_VENDA := Color("e8c06a")
const TRACO := 9.0
const VAZIO := 6.0
const ICONE := 14.0
const MARGEM := 14.0

var world: Node3D
var camera: Camera3D
## Devolve os retângulos de tela que a legenda deve evitar (marcadores e "Você").
var ocupados: Callable = Callable()
var _nomes: Dictionary = {}
var _contornos: Dictionary = {}


func configurar(mundo: Node3D, olho: Camera3D, evitar: Callable = Callable()) -> void:
	world = mundo
	camera = olho
	ocupados = evitar
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for id in Jogo.dados(Terras.ARQUIVO).get("lotes", {}):
		var rotulo := Label.new()
		rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Identidade.papel_leitura(rotulo, 14)
		rotulo.add_theme_constant_override("outline_size", 5)
		rotulo.add_theme_color_override("font_outline_color", Color("19211e"))
		add_child(rotulo)
		_nomes[id] = rotulo
		_contornos[id] = contorno_organico(str(id), mundo)


func _process(_delta: float) -> void:
	queue_redraw()


## O retângulo do lote (`Terras.poligono`) vira um contorno arredondado e ondulado no
## mundo: uma superelipse que toca as quatro bordas, com duas ondas leves, de fase
## decidida pelo id do lote, para cada terra ter o seu jeito e nenhum quadro mudar.
static func contorno_organico(id: String, mundo: Node3D) -> PackedVector3Array:
	var cantos: PackedVector3Array = Terras.poligono(id, mundo)
	if cantos.size() != 4:
		return PackedVector3Array()
	var centro := (cantos[0] + cantos[1] + cantos[2] + cantos[3]) * 0.25
	var eixo_x := (cantos[1] - cantos[0]) * 0.5
	var eixo_z := (cantos[3] - cantos[0]) * 0.5
	var semente := float(absi(hash(id)) % 1000) / 1000.0 * TAU
	var pontos := PackedVector3Array()
	for i in PONTOS:
		var angulo := TAU * float(i) / float(PONTOS)
		var c := cos(angulo)
		var s := sin(angulo)
		# Expoente 2/4: quase um retângulo, mas de cantos redondos.
		var x := signf(c) * pow(absf(c), 0.5)
		var z := signf(s) * pow(absf(s), 0.5)
		var onda := 1.0 + 0.045 * sin(angulo * 3.0 + semente) + 0.03 * sin(angulo * 5.0 + semente * 1.7)
		pontos.append(centro + eixo_x * x * onda + eixo_z * z * onda)
	return pontos


func _draw() -> void:
	if not is_instance_valid(camera) or not is_instance_valid(world):
		return
	var tela := Rect2(Vector2.ZERO, get_viewport_rect().size)
	var evitar: Array[Rect2] = []
	if ocupados.is_valid():
		for retangulo: Rect2 in ocupados.call():
			evitar.append(retangulo)
	# Primeiro as suas e as à venda, para a legenda delas ter a primeira escolha de lugar.
	var ordem: Array = _nomes.keys()
	ordem.sort_custom(func(a, b) -> bool: return _prioridade(str(a)) > _prioridade(str(b)))
	for id in ordem:
		var rotulo: Label = _nomes[id]
		rotulo.visible = false
		var contorno: PackedVector3Array = _contornos.get(id, PackedVector3Array())
		var forca := _forca(str(id))
		if contorno.size() < 3 or forca <= 0.02:
			continue
		var pontos := PackedVector2Array()
		var centro := Vector2.ZERO
		for ponto in contorno:
			var pixel := camera.unproject_position(ponto)
			pontos.append(pixel)
			centro += pixel
		centro /= float(pontos.size())
		var caixa := Rect2(pontos[0], Vector2.ZERO)
		for pixel in pontos:
			caixa = caixa.expand(pixel)
		if not caixa.intersects(tela):
			continue
		var cor := COR_SUA if Terras.meu(str(id)) else (COR_VENDA if _a_venda(str(id)) else COR_ALHEIA)
		draw_colored_polygon(pontos, Color(cor, 0.05 * forca))
		var fechado := PackedVector2Array(pontos)
		fechado.append(pontos[0])
		draw_polyline(fechado, Color(cor, 0.10 * forca), 7.0, true)
		_tracejar(pontos, Color(cor, 0.9 * forca), TRACO, VAZIO, 1.6)
		_legenda(str(id), rotulo, cor, forca, pontos, centro, tela, evitar)


## Quanto a divisa aparece (0 a 1): as suas e as à venda sempre; as dos outros só de perto.
func _forca(id: String) -> float:
	if Terras.meu(id) or _a_venda(id):
		return 1.0
	var perto := 420.0 / maxf(0.001, world.get_meters_per_unit())
	return clampf(remap(camera.size, perto * 1.4, perto * 2.4, 1.0, 0.0), 0.0, 1.0)


func _prioridade(id: String) -> int:
	return 2 if Terras.meu(id) else (1 if _a_venda(id) else 0)


func _a_venda(id: String) -> bool:
	return Terras.oferta(str(Terras.dados(id).get("dono", ""))) == id


func _texto(id: String) -> String:
	var situacao := Terras.texto("sua")
	if not Terras.meu(id):
		if _a_venda(id):
			situacao = Terras.texto("a_venda") % Terras.preco(id)
		else:
			situacao = Terras.texto("de_dono") % _dono(id)
	return Terras.nome(id) + " · " + situacao


## Põe a legenda (plaquinha + texto) no primeiro lugar da borda interna ou do centro que
## não cubra marcador, "Você" nem a legenda de outro lote; se nenhum serve, a legenda some
## (a divisa continua desenhada e o nome volta quando houver espaço).
func _legenda(id: String, rotulo: Label, cor: Color, forca: float, pontos: PackedVector2Array, centro: Vector2, tela: Rect2, evitar: Array[Rect2]) -> void:
	rotulo.text = _texto(id)
	rotulo.add_theme_color_override("font_color", Color(Identidade.COR_LEITURA, forca))
	rotulo.add_theme_color_override("font_outline_color", Color(0.10, 0.13, 0.12, forca))
	rotulo.reset_size()
	var fator := Tela.escala_componente("mapa")
	rotulo.scale = Vector2.ONE * fator
	var altura := maxf(ICONE, rotulo.size.y * fator)
	var bloco := Vector2(ICONE + 4.0 + rotulo.size.x * fator, altura)
	var candidatos: Array[Vector2] = [centro]
	var passo := maxi(1, roundi(pontos.size() / 12.0))
	for i in range(0, pontos.size(), passo):
		candidatos.append(pontos[i].lerp(centro, 0.28))
	var minimo := Vector2(MARGEM, MARGEM)
	var maximo := (tela.size - bloco - minimo).max(minimo)
	var melhor := Rect2()
	var menor := INF
	for candidato in candidatos:
		var retangulo := Rect2((candidato - bloco * 0.5).clamp(minimo, maximo), bloco)
		var coberto := 0.0
		for outro in evitar:
			coberto += retangulo.intersection(outro).get_area()
		if coberto < menor:
			menor = coberto
			melhor = retangulo
		if coberto <= 0.0:
			break
	if menor > 0.0:
		return
	evitar.append(melhor.grow(4.0))
	rotulo.position = melhor.position + Vector2(ICONE + 4.0, (altura - rotulo.size.y * fator) * 0.5)
	rotulo.visible = true
	_icone(id, melhor.position + Vector2(ICONE * 0.5, altura * 0.5), cor, forca)


## Plaquinha da situação: casa (sua), placa de venda ou marco de divisa (dos outros).
func _icone(id: String, centro: Vector2, cor: Color, forca: float) -> void:
	var traco := Color(cor, forca)
	var fundo := Color(0.10, 0.13, 0.12, 0.85 * forca)
	if Terras.meu(id):
		var casa := PackedVector2Array([centro + Vector2(-6, 0), centro + Vector2(0, -6), centro + Vector2(6, 0), centro + Vector2(6, 6), centro + Vector2(-6, 6)])
		draw_colored_polygon(casa, fundo)
		casa.append(casa[0])
		draw_polyline(casa, traco, 1.6, true)
	elif _a_venda(id):
		draw_line(centro + Vector2(-4, 7), centro + Vector2(-4, -7), traco, 1.8, true)
		var placa := Rect2(centro + Vector2(-4, -7), Vector2(11, 7))
		draw_rect(placa, fundo)
		draw_rect(placa, traco, false, 1.4)
	else:
		var marco := PackedVector2Array([centro + Vector2(0, -6), centro + Vector2(6, 0), centro + Vector2(0, 6), centro + Vector2(-6, 0)])
		draw_colored_polygon(marco, fundo)
		marco.append(marco[0])
		draw_polyline(marco, traco, 1.6, true)


## Linha tracejada fechada, de traço e vazio medidos em pixels de tela.
func _tracejar(pontos: PackedVector2Array, cor: Color, traco: float, vazio: float, largura: float) -> void:
	var desenhando := true
	var restante := traco
	for i in pontos.size():
		var a := pontos[i]
		var b := pontos[(i + 1) % pontos.size()]
		var distancia := a.distance_to(b)
		var andado := 0.0
		while andado < distancia:
			var passo := minf(restante, distancia - andado)
			if desenhando:
				draw_line(a.lerp(b, andado / distancia), a.lerp(b, (andado + passo) / distancia), cor, largura, true)
			andado += passo
			restante -= passo
			if restante <= 0.001:
				desenhando = not desenhando
				restante = traco if desenhando else vazio


func _dono(id: String) -> String:
	var dono := str(Terras.dados(id).get("dono", ""))
	return Jogo.nome_do_morador(dono)
