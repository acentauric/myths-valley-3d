extends "res://scripts/prototipo_3d/comodo.gd"
## A CASA HERDADA POR DENTRO — a casa de taipa do roçado, no lugar dela (#26, #50).
##
## "Implemente também a casa do jogador, com sua fazenda e ambiente interno,
## assim resolve a barreira encontrada." A barreira era o dia que não virava:
## o vale não tinha cama, e o calendário só andava quando o jogador caía. A
## cama mora aqui, e quem dorme nela é a `noite.gd`.
##
## Uma casa de taipa do Recôncavo de 1887, no tamanho da casca que a contém:
## chão de terra batida, parede caiada com a barra de barro onde a cal
## descasca, telha-vã com os caibros à mostra, a janela da fachada à esquerda
## da porta. Na parede do fundo, a cama e o baú; perto da porta, a água; debaixo
## da janela, a mesa com a lamparina.
##
##
## O QUE É PEÇA E O QUE É ARQUITETURA
##
## Como na igreja: a ARQUITETURA — parede, chão, telha-vã — é desta classe; os
## MÓVEIS saem do `CatalogoAssets`, no estilo escolhido. Os móveis da casa
## (#26: cama, mesa, banco, baú, barril, cantareira, fogão de barro, jirau,
## oratório, rede) chegam do Tripo; até lá, a cama e o baú — os dois que se usam
## — são caixas provisórias, como a #50 manda ("caixa cinza, como a oficina"),
## e os outros ficam de fora. O pote, a moringa, o cesto e o candeeiro já
## estavam no catálogo e entram desde já.

## QUEM MORA AQUI. "Cada um tem casa com interior, e o interior diz quem mora
## nela antes de o dono abrir a boca" (docs/mundo/MORADORES.md): a mesma casa
## de taipa por fora, e por dentro a de cada um — para as casas não serem
## iguais.
##
##   herdada     a casa do finado, que é do jogador: a cama que vira o dia e o
##               baú que se usa
##   pescador    a do Pedro: a rede de dormir no lugar da cama, a rede de pesca
##               e os remos, pouco móvel — pescador passa o dia no mar —, e a
##               barra azul de casa de beira de praia
##   rezadeira   a da Dona Zefa, que mora com o neto: a cama dela e a rede do
##               Cosme, o oratório com a luz acesa, as ervas secando, o
##               pilão, a gamela e o barril — "é onde o remédio se faz" —, e os
##               cestos que ela trança
var perfil := "herdada"

## O BARRO das partes baixas, onde a cal descasca.
const BARRO := Color("9a6e4c")
## A barra de cada perfil, e a cal de cima.
const BARRAS := {"herdada": Color("9a6e4c"), "pescador": Color("4f7896"), "rezadeira": Color("8a5a3c")}
const CAIS := {"herdada": Color("ece2cc"), "pescador": Color("f1ede3"), "rezadeira": Color("e9d8ad")}
const TELHA := Color("8f4a33")

## Os móveis da casa, com a medida de cada um no lugar dele: a caixa provisória
## tem esse tamanho, e o modelo do Tripo é posto nessa largura.
const CAMA := Vector3(1.9, 0.55, 0.95)
const BAU := Vector3(0.9, 0.55, 0.5)
const MESA := Vector3(1.1, 0.78, 0.65)
const CINZA_PROVISORIO := Color("8d9093")

## Onde ficou cada coisa, no cômodo (ver `_montar_dentro`).
var _cama := Vector3.ZERO
var _bau := Vector3.ZERO


func _init() -> void:
	camera_de_cima = true
	rampa_da_porta_inteira = true


func _comprimento_minimo() -> float:
	return 2.6


func _pe_direito_minimo() -> float:
	return 2.3


func _montar_dentro() -> void:
	_montar_telha_va()
	_montar_janela()
	_montar_moveis()


## ONDE SE DEITA: o meio da cama, na altura do colchão.
func ponto_da_cama() -> Vector3:
	return to_global(_cama + Vector3(0, CAMA.y, 0))


func ponto_do_bau() -> Vector3:
	return to_global(_bau + Vector3(0, BAU.y, 0))


## ONDE SE ACORDA: no chão, ao pé da cama, virado para a porta.
func lugar_de_acordar() -> Vector3:
	return to_global(_cama + Vector3(0.0, 0.05, CAMA.z * 0.5 + 0.55))


## O giro do corpo que acorda: de frente para a porta.
func giro_de_acordar() -> float:
	var para_a_porta := to_global(Vector3(porta_x, 0, 0)) - lugar_de_acordar()
	return atan2(para_a_porta.x, para_a_porta.z)


# --- a casca da casa ---------------------------------------------------------------

func _parede() -> Material:
	return _cal(CAIS.get(perfil, CAIS["herdada"]))


func _cor_da_barra() -> Color:
	return BARRAS.get(perfil, BARRO)


func _piso() -> Material:
	return _terra_batida()


func _forro() -> Material:
	return _telha_va()


## A barra de barro, meio metro de chão para cima, dos lados e no fundo.
func _barra_da_parede(lado: float) -> void:
	_caixa(Vector3(0.03, 0.45, comprimento), Vector3(lado * (largura * 0.5 - 0.015), 0.225, -comprimento * 0.5),
		_cal(_cor_da_barra()), false, "Barro")


func _barra_do_fundo() -> void:
	_caixa(Vector3(largura, 0.45, 0.03), Vector3(0, 0.225, -comprimento + 0.015), _cal(_cor_da_barra()), false, "Barro")


func _barra_da_fachada(largura_do_trecho: float, meio_x: float) -> void:
	_caixa(Vector3(largura_do_trecho, 0.45, 0.03), Vector3(meio_x, 0.225, -0.015), _cal(_cor_da_barra()), false, "Barro")


## Os caibros da telha-vã, da fachada ao fundo, por baixo das telhas.
func _montar_telha_va() -> void:
	var x := -largura * 0.5 + 0.3
	while x < largura * 0.5 - 0.2:
		_teto.append(_caixa(Vector3(0.08, 0.1, comprimento), Vector3(x, pe_direito - 0.05, -comprimento * 0.5), _cor(Color("3f2a1c")), false, "Caibro"))
		x += 0.55


## A JANELA da fachada, à esquerda da porta, onde a casca tem a dela pintada.
func _montar_janela() -> void:
	var x := -largura * 0.5 + maxf(0.75, (porta_x - largura_da_porta * 0.5 + largura * 0.5) * 0.45)
	_janela(Vector3(x, minf(1.55, pe_direito - 0.8), -0.04), Vector3(0, 0, -1), 0.85, 0.95)


# --- os móveis ------------------------------------------------------------------

func _montar_moveis() -> void:
	match perfil:
		"pescador":
			_moveis_do_pescador()
		"rezadeira":
			_moveis_da_rezadeira()
		_:
			_moveis_da_herdada()


func _moveis_da_herdada() -> void:
	# A CAMA, de comprido na parede do fundo, com a cabeceira na parede da
	# esquerda; o BAÚ ao lado dela, no fundo. Os dois têm colisão: são o que se
	# usa, e o corpo não atravessa.
	_cama = Vector3(-largura * 0.5 + CAMA.x * 0.5 + 0.05, 0.0, -comprimento + CAMA.z * 0.5 + 0.05)
	_movel("cama", _cama, 0.0, CAMA, true)
	_bau = Vector3(_cama.x + CAMA.x * 0.5 + 0.2 + BAU.x * 0.5, 0.0, -comprimento + BAU.z * 0.5 + 0.05)
	if _bau.x + BAU.x * 0.5 > largura * 0.5 - 0.05:
		_bau.x = largura * 0.5 - BAU.x * 0.5 - 0.05
	_movel("bau", _bau, 0.0, BAU, true)
	# A MESA debaixo da janela, com a lamparina e a moringa; o banco na frente.
	# Sem a mesa (ela chega do Tripo), a lamparina fica em cima do baú, e a
	# moringa no chão, junto do pote da água.
	var mesa := Vector3(-largura * 0.5 + MESA.x * 0.5 + 0.15, 0.0, -MESA.z * 0.5 - 0.1)
	var tem_mesa := _movel("mesa", mesa, 0.0, MESA, false) != null
	_movel("banco_tosco", mesa + Vector3(0, 0, -MESA.z * 0.5 - 0.35), 0.0, Vector3(1.0, 0.45, 0.32), false)
	var lamparina := mesa + Vector3(0.25, MESA.y, 0.0) if tem_mesa else _bau + Vector3(0.2, BAU.y, 0.0)
	_peca("candeeiro", lamparina, 0.0, 0.45)
	_vela("Lamparina", lamparina + Vector3(0, 0.45, 0.05), maxf(largura, comprimento) * 0.9, 1.1)
	# A ÁGUA perto da porta: a cantareira, e o pote em cima dela — até ela
	# chegar, o pote no chão.
	var agua := Vector3(largura * 0.5 - 0.35, 0.0, -0.45)
	if _movel("cantareira", agua, 0.0, Vector3(0.6, 0.9, 0.45), false) == null:
		_colisao_da_peca(_peca("pote", agua, 0.0, 0.6), "Pote")
	_peca("moringa", (mesa + Vector3(-0.25, MESA.y, 0.05)) if tem_mesa else (agua + Vector3(-0.3, 0.0, -0.45)), 0.4, 0.3)
	# O canto do FOGÃO, no fundo à direita; o jirau na parede de cima dele, e o
	# barril ao lado.
	# A boca do fogo é a frente do modelo (o +Z, como a dos outros móveis), e
	# ela olha para a sala: no fundo, para a porta; sem lugar no fundo, ao lado
	# do baú, o fogão vai para a parede da direita, de frente para o meio.
	var fogao := Vector3(largura * 0.5 - 0.55, 0.0, -comprimento + 0.45)
	var giro_do_fogao := 0.0
	if fogao.x - 0.5 < _bau.x + BAU.x * 0.5 + 0.2:
		fogao = Vector3(largura * 0.5 - 0.4, 0.0, -comprimento * 0.5)
		giro_do_fogao = -PI * 0.5
	_movel("fogao_barro", fogao, giro_do_fogao, Vector3(1.0, 0.8, 0.7), false)
	_movel("jirau", Vector3(largura * 0.5 - 0.25, 1.5, -comprimento * 0.5), -PI * 0.5, Vector3(1.2, 0.6, 0.4), false)
	_movel("barril", Vector3(largura * 0.5 - 0.35, 0.0, -comprimento * 0.5 + 0.7), 0.0, Vector3(0.55, 0.8, 0.55), false)
	# O ORATÓRIO na parede da esquerda, entre a mesa e a cama.
	_movel("oratorio", Vector3(-largura * 0.5 + 0.18, 1.25, -comprimento * 0.5), PI * 0.5, Vector3(0.45, 0.6, 0.3), false)
	# O CESTO no chão, ao pé da cama.
	_colisao_da_peca(_peca("cesto", _cama + Vector3(CAMA.x * 0.5 - 0.2, 0.0, CAMA.z * 0.5 + 0.25), 0.3, 0.35), "Cesto")


## A CASA DO PEDRO, pescador: a REDE de dormir de lado a lado no fundo, que
## pescador dorme de rede; o baú pequeno ao pé dela; na parede da direita, a
## rede de pesca pendurada e os remos no canto, perto da porta, que é por onde
## eles saem de madrugada; a água na entrada; o fogão no canto do fundo, e o
## banco com o barril fazendo de mesa, com o candeeiro em cima.
func _moveis_do_pescador() -> void:
	var rede := Vector3(0.0, 0.0, -comprimento + 0.55)
	_movel("rede", rede, 0.0, Vector3(minf(2.4, largura - 0.4), 1.0, 0.8), false)
	_cama = rede
	_bau = Vector3(-largura * 0.5 + BAU.x * 0.5 + 0.1, 0.0, -comprimento + 1.45)
	_movel("bau", _bau, PI * 0.5, Vector3(0.75, 0.45, 0.42), false)
	_movel("rede_de_pesca", Vector3(largura * 0.5 - 0.2, 1.0, -comprimento * 0.55), -PI * 0.5, Vector3(1.2, 1.4, 0.4), false)
	# Os remos vieram cruzados em X: na parede, ao comprido dela.
	_movel("remos", Vector3(largura * 0.5 - 0.3, 0.0, -0.8), -PI * 0.5, Vector3(1.2, 1.7, 0.45), false)
	var agua := Vector3(-largura * 0.5 + 0.35, 0.0, -0.5)
	_colisao_da_peca(_peca("pote", agua, 0.0, 0.6), "Pote")
	var barril := Vector3(-largura * 0.5 + 0.45, 0.0, -comprimento * 0.5)
	var o_barril := _movel("barril", barril, 0.0, Vector3(0.55, 0.8, 0.55), false)
	_movel("banco_tosco", barril + Vector3(0.75, 0.0, 0.0), PI * 0.5, Vector3(1.0, 0.45, 0.32), false)
	# O candeeiro EM CIMA do barril, na altura medida dele: o barril do Tripo tem
	# 0,72, e não os 0,8 de onde ele é pedido.
	var topo := caixa_no_comodo(o_barril).end.y if o_barril != null else 0.8
	_peca("candeeiro", barril + Vector3(0.0, topo, 0.0), 0.0, 0.45)
	_vela("Lamparina", barril + Vector3(0.0, topo + 0.45, 0.05), maxf(largura, comprimento) * 0.9, 1.0)
	_movel("fogao_barro", Vector3(largura * 0.5 - 0.55, 0.0, -comprimento + 0.45), 0.0, Vector3(1.0, 0.8, 0.7), false)
	_colisao_da_peca(_peca("cesto", Vector3(largura * 0.5 - 0.4, 0.0, -comprimento * 0.3), 0.6, 0.4), "Cesto")


## A CASA DA DONA ZEFA, rezadeira, que mora com o neto: a CAMA dela no fundo,
## com a cabeceira na parede da esquerda, e a REDE do Cosme atravessada perto
## da porta; o ORATÓRIO na parede do fundo, à direita da cama, com a luz
## quente acesa; as ERVAS secando na parede da direita, por cima do PILÃO e
## da GAMELA — e o barril ao lado, "que é onde o remédio se faz"; a mesa
## debaixo da janela; os cestos que ela trança empilhados no canto.
func _moveis_da_rezadeira() -> void:
	_cama = Vector3(-largura * 0.5 + CAMA.x * 0.5 + 0.05, 0.0, -comprimento + CAMA.z * 0.5 + 0.05)
	_movel("cama", _cama, 0.0, CAMA, false)
	var oratorio := Vector3(minf(_cama.x + CAMA.x * 0.5 + 0.6, largura * 0.5 - 0.6), 1.3, -comprimento + 0.18)
	_movel("oratorio", oratorio, 0.0, Vector3(0.45, 0.6, 0.3), false)
	# A luz quente do oratório, que a reza da casa não deixa apagar.
	_vela("LuzDoOratorio", oratorio + Vector3(0.0, -0.2, 0.3), 2.6, 0.5)
	_movel("rede", Vector3(0.0, 0.0, -0.9), 0.0, Vector3(minf(2.2, largura - 0.6), 1.0, 0.7), false)
	var remedio := Vector3(largura * 0.5 - 0.45, 0.0, -comprimento * 0.55)
	_movel("barril", remedio + Vector3(0.0, 0.0, 0.85), 0.0, Vector3(0.55, 0.8, 0.55), false)
	_movel("gamela", remedio, -PI * 0.5, Vector3(0.7, 0.25, 0.5), false)
	_movel("pilao", remedio + Vector3(0.0, 0.0, -0.8), 0.0, Vector3(0.4, 1.0, 0.4), false)
	_movel("ervas_secando", Vector3(largura * 0.5 - 0.15, 1.75, -comprimento * 0.55), -PI * 0.5, Vector3(1.4, 0.7, 0.3), false)
	var mesa := Vector3(-largura * 0.5 + MESA.x * 0.5 + 0.15, 0.0, -MESA.z * 0.5 - 0.1)
	var tem_mesa := _movel("mesa", mesa, 0.0, MESA, false) != null
	var lamparina := mesa + Vector3(0.25, MESA.y, 0.0) if tem_mesa else oratorio + Vector3(0.0, -0.35, 0.2)
	_peca("candeeiro", lamparina, 0.0, 0.45)
	_vela("Lamparina", lamparina + Vector3(0, 0.45, 0.05), maxf(largura, comprimento) * 0.8, 0.9)
	_movel("fogao_barro", Vector3(largura * 0.5 - 0.55, 0.0, -comprimento + 0.45), 0.0, Vector3(1.0, 0.8, 0.7), false)
	_movel("cantareira", Vector3(largura * 0.5 - 0.35, 0.0, -0.45), 0.0, Vector3(0.6, 0.9, 0.45), false)
	for i in 3:
		_colisao_da_peca(_peca("cesto", Vector3(-largura * 0.5 + 0.35 + 0.42 * float(i % 2), 0.0, -comprimento * 0.5 + 0.4 * float(i)), 0.4 * float(i), 0.35 + 0.05 * float(i)), "Cesto")


## Um MÓVEL da casa: o modelo do catálogo, na largura pedida, ou — para os que
## se usam (`de_uso`) — a caixa provisória cinza, até ele chegar. Todo móvel
## posto tem a colisão na medida dele (`_colisao_da_peca`). Devolve o nó posto,
## ou null.
func _movel(chave: String, onde: Vector3, giro: float, medida: Vector3, de_uso: bool) -> Node3D:
	var peca: Node3D = null
	if Estilo.tripo() and CatalogoAssets.tem_tripo(chave):
		peca = CatalogoAssets.instanciar(chave, self, onde, 1.0, giro)
		if peca != null:
			peca.set_meta("chave", chave)
		if peca != null and peca.has_meta("limites"):
			# O catálogo normaliza pela medida dele; aqui o móvel cabe no lugar.
			var caixa: AABB = peca.get_meta("limites")
			var maior := maxf(caixa.size.x, caixa.size.z)
			if maior > 0.01:
				peca.scale *= maxf(medida.x, medida.z) / maior
	if peca == null and de_uso:
		peca = _caixa(medida, onde + Vector3(0, medida.y * 0.5, 0), _cor(CINZA_PROVISORIO), false, chave.capitalize() + "Provisorio")
		peca.rotation.y = giro
	_colisao_da_peca(peca, chave.capitalize())
	return peca


# --- materiais da casa -------------------------------------------------------------

## Chão de terra batida: barro socado, com manchas e grãos.
func _terra_batida() -> ShaderMaterial:
	return _shader("""
shader_type spatial;
uniform vec3 terra : source_color;
float ruido(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float suave(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(ruido(i), ruido(i + vec2(1, 0)), f.x), mix(ruido(i + vec2(0, 1)), ruido(i + vec2(1, 1)), f.x), f.y);
}
varying vec3 mundo;
void vertex() { mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float mancha = suave(mundo.xz * 0.9) * 0.6 + suave(mundo.xz * 3.1) * 0.4;
	float grao = ruido(floor(mundo.xz * 60.0));
	ALBEDO = terra * (0.82 + 0.22 * mancha) * (0.95 + 0.08 * grao);
	ROUGHNESS = 0.95;
}
""", {"terra": Color("8a6a4b")})


## Telha-vã: o avesso das telhas-canal, em fileiras, visto de baixo.
func _telha_va() -> ShaderMaterial:
	return _shader("""
shader_type spatial;
uniform vec3 telha : source_color;
float ruido(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
varying vec3 mundo;
void vertex() { mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = vec2(mundo.x / 0.18, mundo.z / 0.42);
	p.y += step(1.0, mod(floor(p.x), 2.0)) * 0.5;
	vec2 q = fract(p);
	float canal = sin(q.x * 3.14159);
	float junta = 1.0 - step(0.05, q.y);
	vec3 cor = telha * (0.7 + 0.3 * canal) * (0.9 + 0.15 * ruido(floor(p)));
	ALBEDO = mix(cor, cor * 0.5, junta);
	ROUGHNESS = 0.9;
}
""", {"telha": TELHA})
