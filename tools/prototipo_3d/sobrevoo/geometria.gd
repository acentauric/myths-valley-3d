extends RefCounted
## GEOMETRIA REAL DO VALE PARA PLANEJAR E MEDIR O SOBREVOO DO MENU, SEM MONTAR O VALE.
##
## Por que existe: a tentativa de contorno reprovada media obstaculo pela AABB de
## cada malha, e a AABB do coqueiro do Tripo e um bloco de 38 m de altura por 49 m
## de largura (copa alta, tronco fino). Com ela o voo "via" parede onde ha ar e
## subia ou desviava aos trancos. Aqui a geometria vem dos TRIANGULOS de verdade
## (extrair_geometria.gd), rasterizados numa grade de 0,5 m com faixas de 2 m de
## altura acima do chao local, e esta biblioteca responde rapido o que planejador
## e avaliador perguntam: chao, ocupacao, folga 3D.
##
## Tambem mora aqui a formula EXATA do voo de hoje (abertura.gd de HEAD, cc8f2e7)
## e a interpolacao Catmull-Rom periodica do formato de trajeto: quem planeja, quem
## mede e o jogo precisam interpolar igual, senao o que passou no portao nao e o
## que o jogador ve.
##
## USO (script sem class_name; carregue pelo caminho):
##   const Geometria = preload("res://tools/prototipo_3d/sobrevoo/geometria.gd")
##   var geo = Geometria.carregar("C:/.../geometria_tripo.json")   # null se falhar
##   geo.chao(x, z)                 # y do chao em unidades (bilinear entre centros)
##   geo.folga(olho)                # metros ate a geometria (exata na grade), teto = raio
##   geo.folga_rapida(x, z, 16.0)   # metros, campo pre-calculado (aprox., ate +1,24 m)
##   geo.folga_rapida_segura(x, z, 16.0)  # o mesmo menos MARGEM_CAMPO_M
##
## UNIDADES: posicoes em unidades do mundo (as do Godot); distancias e alturas que a
## API devolve, em METROS (unidade * escala). O vale usa 4 m por unidade.
##
## O QUE A GRADE GUARDA: celula (ix, iz) cobre x em [ox + ix*c, ox + (ix+1)*c] e z em
## [oz + iz*c, oz + (iz+1)*c] (c = celula, em unidades). O bit k da mascara diz que
## ha triangulo entre 2k e 2k+2 metros ACIMA do chao da celula (chao no centro dela);
## o bit 31 junta tudo de 62 m para cima. O terreno e o que fica rente a ele (ruas,
## agua, decalques) NAO entram na mascara: o chao e a referencia das faixas, e a
## altura sobre ele e restricao separada (H2). Triangulo abaixo do chao nao conta.

const VERSAO := 1
const FAIXAS := 32
const FAIXA_M := 2.0
## Lado do bloco (em celulas) do indice que poupa a busca da folga: 8 x 0,5 m = 4 m.
const BLOCO := 8
## Quanto folga_rapida pode passar da folga exata. Medido na geometria unida (outubro
## de 2026): em 2677 pontos a 12-20 m do chao com obstaculo a menos de 20 m, o campo
## errou de -0,86 a +1,24 m (mediana +0,26). A conta da o teto teorico perto de 1,7 m:
## centro x caixa (0,35) + bilinear (0,35) + camadas de 1 m (0,5) + chao do vizinho.
const MARGEM_CAMPO_M := 1.3
const CAMINHO := "res://tools/prototipo_3d/sobrevoo/geometria.gd"

## Copia literal das constantes do voo de hoje (scripts/prototipo_3d/abertura.gd, HEAD
## cc8f2e7). Se o abertura.gd mudar, a linha de base e a de HEAD, nao a nova.
const FLYOVER_SECONDS := 72.0
const ALTURA_SOBREVOO := 16.0
const OLHAR_ADIANTE := 56.0
const LATERAL_SOBREVOO := 40.0

var cabecalho: Dictionary = {}
## Metros por unidade do mundo.
var escala := 4.0
## Lado da celula em unidades.
var celula := 0.125
var origem := Vector2.ZERO
var nx := 0
var nz := 0
var mascara := PackedInt32Array()
## y absoluto do chao no centro de cada celula (unidades), de $Cenario.ground_height_at.
var chao_celula := PackedFloat32Array()
var pier := Vector3.ZERO
var praca := Vector3.ZERO
## Campo de folga pre-calculado (metros), camada a camada de altura sobre o chao.
var campo := PackedFloat32Array()
var campo_alturas := PackedFloat32Array()

## Onde parou a ultima busca de folga que achou algo dentro do raio.
var ultima_celula := Vector2i(-1, -1)
var ultima_faixa := -1

var _bnx := 0
var _bnz := 0
var _bloco_mascara := PackedInt32Array()
var _bloco_chao_min := PackedFloat32Array()
var _bloco_chao_max := PackedFloat32Array()
## Potencia de 2 -> expoente, para achar o bit mais baixo sem laco.
var _log2 := {}


static func carregar(caminho_json: String):
	var geo = (load(CAMINHO) as GDScript).new()
	return geo if geo.ler(caminho_json) else null


## Le cabecalho JSON + binario. O binario fica ao lado do JSON (campo "binario").
func ler(caminho_json: String) -> bool:
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho_json))
	if not dados is Dictionary:
		push_error("geometria: cabecalho ilegivel: " + caminho_json)
		return false
	cabecalho = dados
	if int(cabecalho.get("versao", 0)) != VERSAO:
		push_error("geometria: versao %s, esperava %d" % [cabecalho.get("versao"), VERSAO])
		return false
	var caminho_bin := caminho_json.get_base_dir().path_join(String(cabecalho["binario"]))
	var arquivo := FileAccess.open(caminho_bin, FileAccess.READ)
	if arquivo == null:
		push_error("geometria: binario ausente: " + caminho_bin)
		return false
	var bytes := arquivo.get_buffer(arquivo.get_length())
	arquivo.close()
	var n := int(cabecalho["nx"]) * int(cabecalho["nz"])
	var blocos := {}
	for bloco in cabecalho["blocos"]:
		blocos[String(bloco["nome"])] = bloco
	var b_mascara: Dictionary = blocos["mascara"]
	var b_chao: Dictionary = blocos["chao"]
	var m := bytes.slice(int(b_mascara["offset"]), int(b_mascara["offset"]) + 4 * n).to_int32_array()
	var g := bytes.slice(int(b_chao["offset"]), int(b_chao["offset"]) + 4 * n).to_float32_array()
	var o: Array = cabecalho["origem_u"]
	iniciar(Vector2(float(o[0]), float(o[1])), float(cabecalho["celula_u"]), int(cabecalho["nx"]), int(cabecalho["nz"]), float(cabecalho["metros_por_unidade"]), m, g)
	pier = _vetor(cabecalho.get("pier", [0, 0, 0]))
	praca = _vetor(cabecalho.get("praca", [0, 0, 0]))
	if blocos.has("campo"):
		var b_campo: Dictionary = blocos["campo"]
		campo_alturas = PackedFloat32Array(b_campo["alturas_m"])
		campo = bytes.slice(int(b_campo["offset"]), int(b_campo["offset"]) + 4 * n * campo_alturas.size()).to_float32_array()
	return true


## Monta a biblioteca sobre arrays ja na memoria (o extrator usa assim, sem arquivo).
func iniciar(origem_u: Vector2, celula_u: float, colunas: int, linhas: int, metros_por_unidade: float, mascara_celulas: PackedInt32Array, chao_celulas: PackedFloat32Array) -> void:
	origem = origem_u
	celula = celula_u
	nx = colunas
	nz = linhas
	escala = metros_por_unidade
	mascara = mascara_celulas
	chao_celula = chao_celulas
	for k in range(FAIXAS):
		_log2[1 << k] = k
	reindexar()


## Refaz o indice de blocos (OR das mascaras e chao min/max). Chame depois de mudar
## a mascara na memoria.
func reindexar() -> void:
	_bnx = (nx + BLOCO - 1) / BLOCO
	_bnz = (nz + BLOCO - 1) / BLOCO
	_bloco_mascara = PackedInt32Array()
	_bloco_mascara.resize(_bnx * _bnz)
	_bloco_chao_min = PackedFloat32Array()
	_bloco_chao_min.resize(_bnx * _bnz)
	_bloco_chao_min.fill(INF)
	_bloco_chao_max = PackedFloat32Array()
	_bloco_chao_max.resize(_bnx * _bnz)
	_bloco_chao_max.fill(-INF)
	for iz in range(nz):
		var linha := iz * nx
		var blinha := (iz / BLOCO) * _bnx
		for ix in range(nx):
			var b := blinha + ix / BLOCO
			var g := chao_celula[linha + ix]
			if g < _bloco_chao_min[b]:
				_bloco_chao_min[b] = g
			if g > _bloco_chao_max[b]:
				_bloco_chao_max[b] = g
			var m := mascara[linha + ix]
			if m != 0:
				_bloco_mascara[b] = _bloco_mascara[b] | m


func dentro(x: float, z: float) -> bool:
	return x >= origem.x and z >= origem.y and x < origem.x + nx * celula and z < origem.y + nz * celula


## Celula que contem (x, z); (-1, -1) fora da grade.
func celula_de(x: float, z: float) -> Vector2i:
	if not dentro(x, z):
		return Vector2i(-1, -1)
	return Vector2i(floori((x - origem.x) / celula), floori((z - origem.y) / celula))


func centro_da_celula(ix: int, iz: int) -> Vector2:
	return origem + Vector2((ix + 0.5) * celula, (iz + 0.5) * celula)


## y do chao (unidades) em (x, z): bilinear entre centros de celula; fora da grade,
## o valor da borda.
func chao(x: float, z: float) -> float:
	var fx := (x - origem.x) / celula - 0.5
	var fz := (z - origem.y) / celula - 0.5
	var ix := floori(fx)
	var iz := floori(fz)
	var tx := fx - ix
	var tz := fz - iz
	var x0 := clampi(ix, 0, nx - 1)
	var x1 := clampi(ix + 1, 0, nx - 1)
	var z0 := clampi(iz, 0, nz - 1) * nx
	var z1 := clampi(iz + 1, 0, nz - 1) * nx
	var a := lerpf(chao_celula[z0 + x0], chao_celula[z0 + x1], tx)
	var b := lerpf(chao_celula[z1 + x0], chao_celula[z1 + x1], tx)
	return lerpf(a, b, tz)


## Mesma assinatura de $Cenario.ground_height_at, para servir de Callable.
func chao_em(p: Vector3) -> float:
	return chao(p.x, p.z)


func altura_sobre_chao_m(p: Vector3) -> float:
	return (p.y - chao(p.x, p.z)) * escala


## Mascara (0 .. 2^32-1) da celula que contem (x, z); 0 fora da grade.
func mascara_em(x: float, z: float) -> int:
	var c := celula_de(x, z)
	if c.x < 0:
		return 0
	return mascara[c.y * nx + c.x] & 0xFFFFFFFF


static func faixa_de(altura_m: float) -> int:
	return clampi(floori(altura_m / FAIXA_M), 0, FAIXAS - 1)


## Ha geometria na faixa desta altura (metros sobre o chao da celula)?
func ocupado(x: float, z: float, altura_m: float) -> bool:
	if altura_m < 0.0:
		return false
	return (mascara_em(x, z) >> faixa_de(altura_m)) & 1 == 1


## Topo da faixa ocupada mais alta da celula, em metros sobre o chao; 0 se vazia.
func topo_m(x: float, z: float) -> float:
	var m := mascara_em(x, z)
	if m == 0:
		return 0.0
	var k := FAIXAS - 1
	while (m >> k) & 1 == 0:
		k -= 1
	return (k + 1) * FAIXA_M


## FOLGA 3D (metros) de um ponto ate a geometria: a menor distancia euclidiana ate uma
## caixa celula x faixa ocupada, buscando so dentro de `raio_m` (devolve `raio_m` se
## nada estiver mais perto). Como a rasterizacao e conservadora, nunca e MAIOR que a
## distancia ate o triangulo real; pode ser menor em ate ~0,7 m na horizontal e ~2 m
## na vertical (o tamanho da caixa). Grava em ultima_celula/ultima_faixa o que achou.
func folga(p: Vector3, raio_m: float = 15.0) -> float:
	ultima_celula = Vector2i(-1, -1)
	ultima_faixa = -1
	var s := escala
	var s2 := s * s
	var melhor2 := raio_m * raio_m
	var raio_u := raio_m / s
	var lado_bloco := celula * BLOCO
	var bx0 := maxi(floori((p.x - raio_u - origem.x) / lado_bloco), 0)
	var bx1 := mini(floori((p.x + raio_u - origem.x) / lado_bloco), _bnx - 1)
	var bz0 := maxi(floori((p.z - raio_u - origem.y) / lado_bloco), 0)
	var bz1 := mini(floori((p.z + raio_u - origem.y) / lado_bloco), _bnz - 1)
	if bx0 > bx1 or bz0 > bz1:
		return raio_m
	# Blocos do mais perto ao mais longe: o primeiro achado ja corta a maioria.
	var candidatos: Array = []
	for bz in range(bz0, bz1 + 1):
		var zb0 := origem.y + bz * lado_bloco
		var dz := maxf(maxf(zb0 - p.z, p.z - zb0 - lado_bloco), 0.0)
		for bx in range(bx0, bx1 + 1):
			var b := bz * _bnx + bx
			var bm := _bloco_mascara[b] & 0xFFFFFFFF
			if bm == 0:
				continue
			var xb0 := origem.x + bx * lado_bloco
			var dx := maxf(maxf(xb0 - p.x, p.x - xb0 - lado_bloco), 0.0)
			var dh2 := (dx * dx + dz * dz) * s2
			if dh2 >= melhor2:
				continue
			# Faixa de alturas do ponto sobre o chao dentro do bloco.
			var baixo := (p.y - _bloco_chao_max[b]) * s
			var alto := (p.y - _bloco_chao_min[b]) * s
			var dv := _distancia_vertical_intervalo(bm, baixo, alto)
			var lb2 := dh2 + dv * dv
			if lb2 < melhor2:
				candidatos.append(Vector2(lb2, b))
	if candidatos.is_empty():
		return raio_m
	candidatos.sort()
	for candidato: Vector2 in candidatos:
		if candidato.x >= melhor2:
			break
		var b := int(candidato.y)
		var bx := b % _bnx
		var bz := b / _bnx
		var ix0 := bx * BLOCO
		var iz0 := bz * BLOCO
		var ix1 := mini(ix0 + BLOCO, nx)
		var iz1 := mini(iz0 + BLOCO, nz)
		for iz in range(iz0, iz1):
			var zc0 := origem.y + iz * celula
			var dz := maxf(maxf(zc0 - p.z, p.z - zc0 - celula), 0.0)
			var dz2 := dz * dz * s2
			if dz2 >= melhor2:
				continue
			var linha := iz * nx
			for ix in range(ix0, ix1):
				var m := mascara[linha + ix]
				if m == 0:
					continue
				var xc0 := origem.x + ix * celula
				var dx := maxf(maxf(xc0 - p.x, p.x - xc0 - celula), 0.0)
				var dh2 := dz2 + dx * dx * s2
				if dh2 >= melhor2:
					continue
				m = m & 0xFFFFFFFF
				var yrel := (p.y - chao_celula[linha + ix]) * s
				# Distancia vertical ate a faixa ocupada mais proxima (0 se dentro de uma).
				var k := floori(yrel * 0.5)
				var dv := INF
				var faixa := -1
				if k >= 0 and k < FAIXAS and (m >> k) & 1 == 1:
					dv = 0.0
					faixa = k
				else:
					var inicio := maxi(k + 1, 0)
					if inicio < FAIXAS:
						var acima := m >> inicio
						if acima != 0:
							var kk: int = inicio + int(_log2[acima & -acima])
							dv = 2.0 * kk - yrel
							faixa = kk
					var fim := mini(k, FAIXAS)
					if fim > 0:
						var abaixo := m & ((1 << fim) - 1)
						if abaixo != 0:
							var kk := fim - 1
							while (abaixo >> kk) & 1 == 0:
								kk -= 1
							var d := yrel - 2.0 * (kk + 1)
							if d < dv:
								dv = d
								faixa = kk
				var d2 := dh2 + dv * dv
				if d2 < melhor2:
					melhor2 = d2
					ultima_celula = Vector2i(ix, iz)
					ultima_faixa = faixa
	return sqrt(melhor2)


## Distancia vertical (m) do intervalo [baixo, alto] (altura sobre o chao) ate a faixa
## ocupada mais proxima da mascara m (0 se alguma faixa encosta no intervalo).
func _distancia_vertical_intervalo(m: int, baixo: float, alto: float) -> float:
	var k0 := floori(baixo * 0.5)
	var k1 := floori(alto * 0.5)
	var a := clampi(k0, 0, FAIXAS - 1)
	var b := clampi(k1, 0, FAIXAS - 1)
	if k1 >= 0 and k0 < FAIXAS:
		var faixa_bits := ((1 << (b + 1)) - 1) ^ ((1 << a) - 1)
		if m & faixa_bits != 0:
			return 0.0
	var dv := INF
	var inicio := maxi(k1 + 1, 0)
	if inicio < FAIXAS:
		var acima := m >> inicio
		if acima != 0:
			dv = 2.0 * (inicio + int(_log2[acima & -acima])) - alto
	var fim := mini(k0, FAIXAS)
	if fim > 0:
		var abaixo := m & ((1 << fim) - 1)
		if abaixo != 0:
			var kk := fim - 1
			while (abaixo >> kk) & 1 == 0:
				kk -= 1
			dv = minf(dv, baixo - 2.0 * (kk + 1))
	return maxf(dv, 0.0)


## Folga pelo campo pre-calculado (metros): bilinear em (x, z) entre centros de celula
## e linear na altura entre camadas (altura em metros sobre o chao, presa ao intervalo
## das camadas). E O(1); erra em ate ~1 m para os dois lados (distancia horizontal
## entre centros, e o chao do ponto no lugar do chao do vizinho). Para o veredito use
## folga(). Sem campo no arquivo, cai em folga() com o raio do teto.
func folga_rapida(x: float, z: float, altura_m: float) -> float:
	if campo.is_empty():
		return folga(Vector3(x, chao(x, z) + altura_m / escala, z), 20.0)
	var camadas := campo_alturas.size()
	var h0 := campo_alturas[0]
	var passo := (campo_alturas[camadas - 1] - h0) / maxf(camadas - 1, 1)
	var fh := clampf((altura_m - h0) / maxf(passo, 0.0001), 0.0, camadas - 1)
	var l0 := mini(floori(fh), camadas - 1)
	var l1 := mini(l0 + 1, camadas - 1)
	var th := fh - l0
	var fx := (x - origem.x) / celula - 0.5
	var fz := (z - origem.y) / celula - 0.5
	var ix := floori(fx)
	var iz := floori(fz)
	var tx := fx - ix
	var tz := fz - iz
	var x0 := clampi(ix, 0, nx - 1)
	var x1 := clampi(ix + 1, 0, nx - 1)
	var z0 := clampi(iz, 0, nz - 1) * nx
	var z1 := clampi(iz + 1, 0, nz - 1) * nx
	var n := nx * nz
	var o0 := l0 * n
	var o1 := l1 * n
	var v0 := lerpf(lerpf(campo[o0 + z0 + x0], campo[o0 + z0 + x1], tx), lerpf(campo[o0 + z1 + x0], campo[o0 + z1 + x1], tx), tz)
	var v1 := lerpf(lerpf(campo[o1 + z0 + x0], campo[o1 + z0 + x1], tx), lerpf(campo[o1 + z1 + x0], campo[o1 + z1 + x1], tx), tz)
	return lerpf(v0, v1, th)


## folga_rapida menos MARGEM_CAMPO_M: nunca maior que a exata nos pontos medidos. Para
## podar candidatos depressa; o veredito continua sendo folga().
func folga_rapida_segura(x: float, z: float, altura_m: float) -> float:
	return maxf(folga_rapida(x, z, altura_m) - MARGEM_CAMPO_M, 0.0)


## Pre-calcula o campo de folga por camadas de altura sobre o chao (metros). Para cada
## camada h, f(q) = distancia vertical de h ate a faixa ocupada mais proxima da celula
## q (ao quadrado), e a transformada de distancia separavel de Felzenszwalb-Huttenlocher
## da min_q(|p - q|^2 + f(q)): a distancia 3D ate a geometria, com a distancia
## horizontal medida entre centros de celula. `teto_m` limita o valor guardado.
func calcular_campo(alturas_m: PackedFloat32Array, teto_m: float = 40.0) -> void:
	var n := nx * nz
	var teto2 := teto_m * teto_m
	var passo2 := (celula * escala) * (celula * escala)
	campo_alturas = alturas_m
	campo = PackedFloat32Array()
	campo.resize(n * alturas_m.size())
	var f := PackedFloat32Array()
	f.resize(n)
	var maior := maxi(nx, nz)
	var linha_f := PackedFloat32Array()
	linha_f.resize(maior)
	var linha_d := PackedFloat32Array()
	linha_d.resize(maior)
	var v := PackedInt32Array()
	v.resize(maior)
	var zz := PackedFloat32Array()
	zz.resize(maior + 1)
	for camada in range(alturas_m.size()):
		var h := alturas_m[camada]
		var kh := floori(h * 0.5)
		for q in range(n):
			var m := mascara[q]
			if m == 0:
				f[q] = teto2
				continue
			m = m & 0xFFFFFFFF
			var dv := INF
			if kh >= 0 and kh < FAIXAS and (m >> kh) & 1 == 1:
				dv = 0.0
			else:
				var inicio := maxi(kh + 1, 0)
				if inicio < FAIXAS:
					var acima := m >> inicio
					if acima != 0:
						dv = 2.0 * (inicio + int(_log2[acima & -acima])) - h
				var fim := mini(kh, FAIXAS)
				if fim > 0:
					var abaixo := m & ((1 << fim) - 1)
					if abaixo != 0:
						var kk := fim - 1
						while (abaixo >> kk) & 1 == 0:
							kk -= 1
						dv = minf(dv, h - 2.0 * (kk + 1))
			f[q] = minf(dv * dv, teto2)
		# Linhas (x), depois colunas (z), cada uma pela envoltoria inferior de parabolas.
		for iz in range(nz):
			var base := iz * nx
			for i in range(nx):
				linha_f[i] = f[base + i]
			_edt_1d(linha_f, linha_d, nx, passo2, v, zz)
			for i in range(nx):
				f[base + i] = linha_d[i]
		for ix in range(nx):
			for i in range(nz):
				linha_f[i] = f[i * nx + ix]
			_edt_1d(linha_f, linha_d, nz, passo2, v, zz)
			for i in range(nz):
				f[i * nx + ix] = linha_d[i]
		var deslocamento := camada * n
		for q in range(n):
			campo[deslocamento + q] = sqrt(minf(f[q], teto2))


## Transformada de distancia 1D (Felzenszwalb-Huttenlocher): d[p] = min_q (w*(p-q)^2 + f[q]).
static func _edt_1d(f: PackedFloat32Array, d: PackedFloat32Array, n: int, w: float, v: PackedInt32Array, z: PackedFloat32Array) -> void:
	var k := 0
	v[0] = 0
	z[0] = -INF
	z[1] = INF
	for q in range(1, n):
		var fq := f[q] + w * q * q
		var s := (fq - (f[v[k]] + w * v[k] * v[k])) / (2.0 * w * (q - v[k]))
		while s <= z[k]:
			k -= 1
			s = (fq - (f[v[k]] + w * v[k] * v[k])) / (2.0 * w * (q - v[k]))
		k += 1
		v[k] = q
		z[k] = s
		z[k + 1] = INF
	k = 0
	for q in range(n):
		while z[k + 1] < q:
			k += 1
		var dq := q - v[k]
		d[q] = w * dq * dq + f[v[k]]


# ---------------------------------------------------------------------------
# O voo de hoje (abertura.gd de HEAD cc8f2e7), copiado sem mudar a conta.
# pier/praca: $Cenario.ancoras["Pier"] e ["Praça"]; escala: get_meters_per_unit().
# `chao` e um Callable(Vector3) -> float: $Cenario.ground_height_at ou geo.chao_em.
# ---------------------------------------------------------------------------

## _flyover_route: a volta curva (elipse) do pier a praca e de volta pelo outro lado.
static func rota_base(pier_u: Vector3, praca_u: Vector3, escala_m: float, progresso: float) -> Vector3:
	var direction := praca_u - pier_u
	direction.y = 0.0
	var lateral := direction.normalized().cross(Vector3.UP) if direction.length_squared() > 0.001 else Vector3.RIGHT
	var angle := progresso * TAU
	var route := (pier_u + praca_u) * 0.5 - (praca_u - pier_u) * cos(angle) * 0.5
	return route + lateral * sin(angle) * LATERAL_SOBREVOO / escala_m


## _flyover_direction: tangente horizontal por diferenca central de +-0,001.
static func direcao_base(pier_u: Vector3, praca_u: Vector3, escala_m: float, progresso: float) -> Vector3:
	var direction := rota_base(pier_u, praca_u, escala_m, progresso + 0.001) - rota_base(pier_u, praca_u, escala_m, progresso - 0.001)
	direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.000001 else Vector3.FORWARD


## _flyover_eye: a rota a ALTURA_SOBREVOO metros do chao.
static func olho_base(pier_u: Vector3, praca_u: Vector3, escala_m: float, progresso: float, chao_de: Callable) -> Vector3:
	var eye := rota_base(pier_u, praca_u, escala_m, progresso)
	eye.y = float(chao_de.call(eye)) + ALTURA_SOBREVOO / escala_m
	return eye


## _flyover_target: OLHAR_ADIANTE metros a frente, inclinado de leve.
static func alvo_base(pier_u: Vector3, praca_u: Vector3, escala_m: float, progresso: float, chao_de: Callable) -> Vector3:
	var eye := olho_base(pier_u, praca_u, escala_m, progresso, chao_de)
	var target := eye + direcao_base(pier_u, praca_u, escala_m, progresso) * OLHAR_ADIANTE / escala_m
	target.y = maxf(eye.y - 5.0 / escala_m, float(chao_de.call(target)) + 4.0 / escala_m)
	return target


## Candidato no formato de trajeto (versao 1) amostrando o voo de hoje em n pontos.
static func trajeto_base(pier_u: Vector3, praca_u: Vector3, escala_m: float, chao_de: Callable, n: int = 720) -> Dictionary:
	var olhos: Array = []
	var alvos: Array = []
	for i in range(n):
		var progresso := float(i) / float(n)
		var olho := olho_base(pier_u, praca_u, escala_m, progresso, chao_de)
		var alvo := alvo_base(pier_u, praca_u, escala_m, progresso, chao_de)
		olhos.append([olho.x, olho.y, olho.z])
		alvos.append([alvo.x, alvo.y, alvo.z])
	return {
		"versao": 1, "amostras": n, "segundos": FLYOVER_SECONDS, "metros_por_unidade": escala_m,
		"pier": [pier_u.x, pier_u.y, pier_u.z], "praca": [praca_u.x, praca_u.y, praca_u.z],
		"olho": olhos, "alvo": alvos,
	}


# ---------------------------------------------------------------------------
# Formato de trajeto e interpolacao (a mesma que o jogo vai usar).
# {"versao":1,"amostras":N,"segundos":72.0,"metros_por_unidade":s,"pier":[x,y,z],
#  "praca":[x,y,z],"olho":[[x,y,z]...N],"alvo":[[x,y,z]...N]}, unidades do mundo.
# Amostra i vale no progresso i/N; progresso = fposmod(t / segundos, 1).
# ---------------------------------------------------------------------------

## Le um trajeto e converte olho/alvo em PackedVector3Array; {} se invalido.
static func carregar_trajeto(caminho: String) -> Dictionary:
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if not dados is Dictionary:
		push_error("trajeto ilegivel: " + caminho)
		return {}
	var t: Dictionary = dados
	if int(t.get("versao", 0)) != 1:
		push_error("trajeto: versao %s, esperava 1" % t.get("versao"))
		return {}
	var olho := PackedVector3Array()
	var alvo := PackedVector3Array()
	for p in t["olho"]:
		olho.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
	for p in t["alvo"]:
		alvo.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
	if olho.size() != int(t["amostras"]) or alvo.size() != olho.size() or olho.size() < 4:
		push_error("trajeto: amostras inconsistentes em " + caminho)
		return {}
	t["olho_v"] = olho
	t["alvo_v"] = alvo
	return t


static func salvar_json(caminho: String, dados: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(caminho.get_base_dir())
	var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
	if arquivo == null:
		push_error("nao gravou " + caminho)
		return false
	arquivo.store_string(JSON.stringify(dados, "  ", false))
	arquivo.close()
	return true


## Catmull-Rom uniforme PERIODICA: a amostra i vale no progresso i/N e a N-esima volta
## a 0, entao a curva fecha em C1 sem tratamento especial na emenda.
static func catmull_rom(amostras: PackedVector3Array, progresso: float) -> Vector3:
	var n := amostras.size()
	var u := fposmod(progresso, 1.0) * n
	var i := floori(u)
	var t := u - i
	i = posmod(i, n)
	return amostras[i].cubic_interpolate(amostras[(i + 1) % n], amostras[(i - 1 + n) % n], amostras[(i + 2) % n], t)


## Derivada da Catmull-Rom periodica em relacao ao PROGRESSO (unidades por ciclo).
static func catmull_rom_derivada(amostras: PackedVector3Array, progresso: float) -> Vector3:
	var n := amostras.size()
	var u := fposmod(progresso, 1.0) * n
	var i := floori(u)
	var t := u - i
	i = posmod(i, n)
	var p0 := amostras[(i - 1 + n) % n]
	var p1 := amostras[i]
	var p2 := amostras[(i + 1) % n]
	var p3 := amostras[(i + 2) % n]
	var d := 0.5 * ((p2 - p0) + 2.0 * (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t + 3.0 * (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t)
	return d * n


## Os dois lados da emenda do segmento s (fim do s-1 e comeco do s): posicao e
## derivada, para conferir C0/C1 de qualquer ponto de amostra, inclusive o 0.
static func catmull_rom_lados(amostras: PackedVector3Array, s: int) -> Dictionary:
	var n := amostras.size()
	var e := posmod(s - 1, n)
	var p0 := amostras[(e - 1 + n) % n]
	var p1 := amostras[e]
	var p2 := amostras[(e + 1) % n]
	var p3 := amostras[(e + 2) % n]
	var fim := p1.cubic_interpolate(p2, p0, p3, 1.0)
	var d_fim := 0.5 * ((p2 - p0) + 2.0 * (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) + 3.0 * (-p0 + 3.0 * p1 - 3.0 * p2 + p3)) * n
	var q0 := amostras[(s - 1 + n) % n]
	var q1 := amostras[posmod(s, n)]
	var q2 := amostras[(s + 1) % n]
	var q3 := amostras[(s + 2) % n]
	var inicio := q1.cubic_interpolate(q2, q0, q3, 0.0)
	var d_inicio := 0.5 * (q2 - q0) * n
	return {"fim": fim, "inicio": inicio, "d_fim": d_fim, "d_inicio": d_inicio}


static func _vetor(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
