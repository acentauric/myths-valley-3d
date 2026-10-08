extends RefCounted
## MAPA DE SOLO: o que há no chão de cada metro do vale, para o shader do terreno
## (assets/prototipo_3d/materiais/terreno.gdshader) misturar as camadas, e para os
## passos saberem onde pisam (geo_region_renderer.surface_at). Ver
## docs/mundo/SOLO_E_FRANJAS.md.
##
## Uma imagem L8 por camada, 1 pixel por unidade, sobre o retângulo da terra (pintada
## em ESCALA x ESCALA subamostras por pixel, para a fronteira cair entre pixels em vez
## de em degrau). As camadas fixas (ruas, praça, costa, rios, fazenda, vila) nascem
## com a região, logo depois das ruas em curva; a copa das árvores e as trilhas de pé das casas, quando
## o mundo termina de plantar e construir (`pintar_vida`). Sai sempre do KML, da
## composição e das casas do momento: mudou o mapa, o chão acompanha.
##
## SÓ PRIMITIVAS EM C++. Nada de laço por pixel em GDScript (são 300 mil pixels por
## camada): as faixas viram polígonos pelo `Geometry2D.offset_polyline`, os
## polígonos se pintam linha a linha com `intersect_polyline_with_polygon` e
## `fill_rect`, e a suavização é `shrink_x2` seguido de `resize` cúbico — rampas de
## 2 a 4 u, que o shader ainda recorta com ruído.
##
## REGRA DO CHÃO (#197): nenhuma transição em ângulo reto. Só o que é humano e reto de
## propósito (piso de casa, calçada da igreja, canteiro, cerca) fica reto, e isso não
## é pintado aqui: são malhas e decalques próprios, por cima do chão. Aqui toda
## fronteira é orgânica: manchas redondas e irregulares (`mancha`), subamostragem na
## pintura, rampa de ~4 u em tudo que é largo e o desvio de borda do shader por cima.

## TRILHA é terra estreita (trilha de pé, pé de árvore, terreiro): rampa de 2 u para o
## traço de ~2 u de largura não se diluir. `peso(TERRA)` devolve o maior dos dois.
enum Camada { TERRA, AREIA, LAMA, PASTO, COPA, TRILHA }
const NOMES := ["terra", "areia", "lama", "pasto", "copa", "trilha"]
## Quantas vezes cada camada encolhe pela metade antes de voltar ao tamanho: 1 dá
## rampa de ~2 u (só a trilha, estreita demais para mais), 2 dá ~4 u.
const SUAVIZACAO := [2, 2, 2, 2, 2, 1]
## Subamostras por pixel em cada eixo na pintura: a imagem crua é ESCALA vezes maior e
## a primeira redução é a média das subamostras (borda com cobertura parcial).
## (Vale 2: a redução de `publicar` é uma só.)
const ESCALA := 2
## O lado da imagem é múltiplo disto, para as duas metades voltarem ao mesmo pixel.
const MULTIPLO := 4

var origem := Vector2.ZERO
var tamanho := Vector2i.ZERO
## A textura que o shader lê: as camadas suaves, na ordem de `Camada`.
var textura: Texture2DArray = null
## Passos de suavização de cada camada. Os portões zeram para provar que medem o degrau.
var passos: Array = SUAVIZACAO.duplicate()
var _cruas: Array[Image] = []
var _suaves: Array[Image] = []


## Começa um mapa em branco que cobre `limites` (unidades do mundo).
func comecar(limites: Rect2) -> void:
	origem = limites.position.floor() - Vector2.ONE * 2.0
	var lado := (limites.size + Vector2.ONE * 4.0).ceil()
	tamanho = Vector2i(int(ceilf(lado.x / MULTIPLO)) * MULTIPLO, int(ceilf(lado.y / MULTIPLO)) * MULTIPLO)
	_cruas.clear()
	_suaves.clear()
	for i in NOMES.size():
		_cruas.append(Image.create_empty(tamanho.x * ESCALA, tamanho.y * ESCALA, false, Image.FORMAT_L8))
	textura = null


func pronto() -> bool:
	return textura != null


## Faixa de `meia_largura` para cada lado de uma linha, com as pontas redondas.
func faixa(camada: int, pontos: PackedVector2Array, meia_largura: float, valor: float = 1.0) -> void:
	if pontos.size() < 2 or meia_largura <= 0.0:
		return
	var local := _no_mapa(pontos)
	for contorno in Geometry2D.offset_polyline(local, meia_largura * ESCALA, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
		_preencher(camada, contorno, valor)


## Polígono cheio (em unidades do mundo).
func poligono(camada: int, pontos: PackedVector2Array, valor: float = 1.0) -> void:
	if pontos.size() >= 3:
		_preencher(camada, _no_mapa(pontos), valor)


## Mancha redonda de `lado` u (a área de um quadrado de `lado`), com os dois semi-eixos
## sorteados pela posição entre 0,88 e 1,12: nunca é um círculo de compasso nem um
## quadrado. É a copa de cada árvore, uma chamada por árvore (são ~6 mil na mata), então
## cada faixa de um pixel do mapa é um único `fill_rect`.
func mancha(camada: int, centro: Vector2, lado: float, valor: float = 1.0) -> void:
	var c := (centro - origem) * ESCALA
	var h1 := fposmod(sin(centro.x * 12.9898 + centro.y * 78.233) * 43758.5453, 1.0)
	var h2 := fposmod(sin(centro.x * 39.346 + centro.y * 11.135) * 24634.6345, 1.0)
	var semi := maxf(lado, 0.5) * 0.5642 * ESCALA
	var rx := semi * (0.88 + 0.24 * h1)
	var ry := semi * (0.88 + 0.24 * h2)
	var imagem := _cruas[camada]
	var cor := Color(valor, valor, valor)
	var limite := Rect2i(Vector2i.ZERO, imagem.get_size())
	var y := int(floorf((c.y - ry) / ESCALA)) * ESCALA
	while y < c.y + ry:
		var dy := (float(y) + ESCALA * 0.5 - c.y) / ry
		if absf(dy) < 1.0:
			var meia := rx * sqrt(1.0 - dy * dy)
			var faixa_cheia := Rect2i(int(roundf(c.x - meia)), y, int(roundf(c.x + meia)) - int(roundf(c.x - meia)), ESCALA).intersection(limite)
			if faixa_cheia.has_area():
				imagem.fill_rect(faixa_cheia, cor)
		y += ESCALA


## Apaga uma camada inteira (antes de repintar a copa e as trilhas).
func limpar(camada: int) -> void:
	_cruas[camada].fill(Color.BLACK)


## Suaviza as camadas cruas e monta (ou atualiza) a textura do shader.
func publicar(camadas: Array = []) -> void:
	if _suaves.size() != NOMES.size():
		_suaves.clear()
		for i in NOMES.size():
			_suaves.append(null)
	var quais: Array = camadas if not camadas.is_empty() else range(NOMES.size())
	for i in quais:
		var imagem := _cruas[i].duplicate() as Image
		# A média das subamostras dá a cobertura parcial da borda; só depois a rampa.
		imagem.shrink_x2()
		for passo in passos[i]:
			imagem.shrink_x2()
		imagem.resize(tamanho.x, tamanho.y, Image.INTERPOLATE_CUBIC)
		_suaves[i] = imagem
	if textura == null or camadas.is_empty():
		textura = Texture2DArray.new()
		textura.create_from_images(_suaves)
	else:
		for i in quais:
			textura.update_layer(_suaves[i], i)


## Peso de 0 a 1 da camada no ponto (unidades do mundo), interpolado como o shader
## lê (filtro linear). Fora do mapa, ou antes de publicar, 0.
func peso(camada: int, ponto: Vector2) -> float:
	if camada == Camada.TERRA:
		return maxf(_peso_da_camada(Camada.TERRA, ponto), _peso_da_camada(Camada.TRILHA, ponto))
	return _peso_da_camada(camada, ponto)


## O maior degrau entre dois pixels vizinhos da camada já suave (0 a 1): um corte seco
## de 1 pixel dá 1; uma rampa de n pixels dá perto de 1/n. É o que o portão mede para
## reprovar quina e escada (#197).
func degrau_maximo(camada: int) -> float:
	if _suaves.size() <= camada or _suaves[camada] == null:
		return 0.0
	var imagem := _suaves[camada]
	var dados := imagem.get_data()
	var largura := imagem.get_width()
	var altura := imagem.get_height()
	var maior := 0
	for y in altura - 1:
		var linha := y * largura
		for x in largura - 1:
			var v := dados[linha + x]
			maior = maxi(maior, absi(v - dados[linha + x + 1]))
			maior = maxi(maior, absi(v - dados[linha + largura + x]))
	return float(maior) / 255.0


func _peso_da_camada(camada: int, ponto: Vector2) -> float:
	if _suaves.size() <= camada or _suaves[camada] == null:
		return 0.0
	var p := ponto - origem - Vector2(0.5, 0.5)
	var x0 := int(floorf(p.x))
	var y0 := int(floorf(p.y))
	if x0 < 0 or y0 < 0 or x0 + 1 >= tamanho.x or y0 + 1 >= tamanho.y:
		return 0.0
	var f := p - Vector2(x0, y0)
	var imagem := _suaves[camada]
	var a := lerpf(imagem.get_pixel(x0, y0).r, imagem.get_pixel(x0 + 1, y0).r, f.x)
	var b := lerpf(imagem.get_pixel(x0, y0 + 1).r, imagem.get_pixel(x0 + 1, y0 + 1).r, f.x)
	return lerpf(a, b, f.y)


func _no_mapa(pontos: PackedVector2Array) -> PackedVector2Array:
	var local := PackedVector2Array()
	local.resize(pontos.size())
	for i in pontos.size():
		local[i] = (pontos[i] - origem) * ESCALA
	return local


## Linha a linha (da imagem subamostrada): a horizontal no meio de cada fileira corta o polígono
## em trechos (côncavo dá vários), e cada trecho é um fill_rect.
func _preencher(camada: int, contorno: PackedVector2Array, valor: float) -> void:
	if contorno.size() < 3:
		return
	var caixa := Rect2(contorno[0], Vector2.ZERO)
	for p in contorno:
		caixa = caixa.expand(p)
	var imagem := _cruas[camada]
	var cor := Color(valor, valor, valor)
	var y_ini := maxi(int(floorf(caixa.position.y)), 0)
	var y_fim := mini(int(ceilf(caixa.end.y)), tamanho.y * ESCALA - 1)
	var x_max := tamanho.x * ESCALA
	var x_ini := caixa.position.x - 1.0
	var x_fim := caixa.end.x + 1.0
	for y in range(y_ini, y_fim + 1):
		var linha := PackedVector2Array([Vector2(x_ini, y + 0.5), Vector2(x_fim, y + 0.5)])
		for trecho: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(linha, contorno):
			var a := clampi(int(roundf(minf(trecho[0].x, trecho[-1].x))), 0, x_max)
			var b := clampi(int(roundf(maxf(trecho[0].x, trecho[-1].x))), 0, x_max)
			if b > a:
				imagem.fill_rect(Rect2i(a, y, b - a, 1), cor)
