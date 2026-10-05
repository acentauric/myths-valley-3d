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
## da porta. Na parede do fundo, a cama e o baú; a água ao lado da entrada, sem
## tomar a passagem; o resto entra com as obras da casa (ver `_moveis_da_herdada`).
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

## A ENTRADA, da fachada para dentro, que nenhum móvel de chão toma; e a folga de
## cada lado do vão da porta (ver `_reservar_a_passagem`).
const ENTRADA := 1.4
const FOLGA_DA_PORTA := 0.2
## O que fica livre no fundo para a cama e o baú: o meio da sala vai da entrada
## até esta distância da parede do fundo.
const FUNDO_DA_DORMIDA := 1.2
## Peça pendurada na parede de pelo menos esta altura não toma chão: só não
## pode ficar por cima do vão da porta.
const NA_PAREDE := 0.9
## O chão reservado (a entrada e o meio da sala) e o chão já tomado, em x e z do
## cômodo (Rect2: x, z).
var _reservado: Array[Rect2] = []
var _tomado: Array[Rect2] = []
## Onde ficou o último móvel que `_por` conseguiu pôr.
var _ultimo := Vector3.ZERO
## Os nós que os móveis puseram, para refazê-los quando uma obra da casa fica
## pronta (`_refazer_os_moveis`), e as obras de mobília que eles mostram.
var _nos_dos_moveis: Array[Node] = []
var _obras_mostradas := ""
## A construção do painel de obras que é esta casa (`BancadasVale.OBRAS`).
const CONSTRUCAO := "casa"


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
	_reservar_a_passagem()
	var antes := get_children()
	match perfil:
		"pescador":
			_moveis_do_pescador()
		"rezadeira":
			_moveis_da_rezadeira()
		_:
			_moveis_da_herdada()
	_nos_dos_moveis.clear()
	for filho in get_children():
		if not antes.has(filho):
			_nos_dos_moveis.append(filho)
	_obras_mostradas = _assinatura_das_obras()
	# A casa do jogador acompanha as obras dela: a obra que fica pronta põe o
	# móvel na hora, e a partida carregada traz os dela.
	if perfil == "herdada" and not Obras.mudou.is_connected(_ao_mudar_as_obras):
		Obras.mudou.connect(_ao_mudar_as_obras)


# --- onde cabe cada coisa -----------------------------------------------------------

## O CHÃO QUE NENHUM MÓVEL TOMA: a entrada e o meio da sala.
##
## "Na casa (...) os móveis ficaram na porta para entrar na casa. É preciso
## reestruturar para fazer sentido." A disposição era escrita parede a parede
## — a água perto da porta, o barril do lado do fogão — e não sabia onde a
## porta ficava. O cômodo é medido na casca de cada casa, e a casa de taipa do
## Tripo dá 3,9 por 3,7 metros, com a porta na metade direita da fachada: a
## cantareira, o barril e o fogão caíam encostados no vão, e na casa da Dona
## Zefa a rede do Cosme atravessava a entrada.
##
## Agora todo móvel de chão pede lugar (`_por`), e cabe se não toma a ENTRADA
## (o vão da porta, com folga dos lados, até ENTRADA para dentro), o MEIO DA
## SALA (da entrada até a dormida, do vão para a esquerda) nem outro móvel. O que
## não cabe em nenhum dos lugares que pede fica de fora: melhor um móvel a menos
## do que uma porta fechada.
func _reservar_a_passagem() -> void:
	_reservado.clear()
	_tomado.clear()
	var esquerda := porta_x - largura_da_porta * 0.5 - FOLGA_DA_PORTA
	var direita := porta_x + largura_da_porta * 0.5 + FOLGA_DA_PORTA
	_reservado.append(Rect2(esquerda, -ENTRADA, direita - esquerda, ENTRADA))
	var fundo := -maxf(ENTRADA, comprimento - FUNDO_DA_DORMIDA)
	var meio := minf(esquerda, 0.0) - 0.35
	if fundo < -ENTRADA:
		_reservado.append(Rect2(meio, fundo, direita - meio, -ENTRADA - fundo))


## O chão que o móvel ocupa, em x e z do cômodo, com o giro dele (de quarto em
## quarto de volta, que é como a casa gira os móveis).
func _pegada(onde: Vector3, giro: float, medida: Vector3) -> Rect2:
	var de_lado := absf(sin(giro)) > 0.7
	var x := medida.z if de_lado else medida.x
	var z := medida.x if de_lado else medida.z
	return Rect2(onde.x - x * 0.5, onde.z - z * 0.5, x, z)


## O móvel cabe aqui? Dentro das paredes, fora da passagem e fora de outro
## móvel. O que é de parede, no alto, só não pode ficar por cima do vão.
func _cabe(pegada: Rect2, na_parede: bool) -> bool:
	if pegada.position.x < -largura * 0.5 - 0.01 or pegada.end.x > largura * 0.5 + 0.01 \
			or pegada.position.y < -comprimento - 0.01 or pegada.end.y > 0.01:
		return false
	if na_parede:
		var vao := Rect2(porta_x - largura_da_porta * 0.5, -ENTRADA, largura_da_porta, ENTRADA)
		return not pegada.intersects(vao)
	for livre in _reservado:
		if pegada.intersects(livre):
			return false
	for outro in _tomado:
		if pegada.intersects(outro):
			return false
	return true


## PÕE UM MÓVEL NO PRIMEIRO LUGAR QUE CABE, dos que ele pede: cada lugar é
## [onde, giro]. Devolve o nó posto, ou null — sem lugar, ou sem modelo (`_movel`).
func _por(chave: String, lugares: Array, medida: Vector3, de_uso: bool) -> Node3D:
	_ultimo = Vector3.INF
	for lugar: Array in lugares:
		var onde: Vector3 = lugar[0]
		var giro: float = lugar[1]
		var na_parede := onde.y >= NA_PAREDE
		var pegada := _pegada(onde, giro, medida)
		if not _cabe(pegada, na_parede):
			continue
		var peca := _movel(chave, onde, giro, medida, de_uso)
		if peca == null:
			return null
		_ultimo = onde
		if not na_parede:
			_tomado.append(pegada)
		return peca
	return null


## Uma PEÇA miúda de chão do catálogo (o pote, o cesto), sólida, no primeiro
## lugar que cabe.
func _por_peca(chave: String, lugares: Array, tamanho: float, medida: Vector3) -> Node3D:
	_ultimo = Vector3.INF
	for lugar: Array in lugares:
		var onde: Vector3 = lugar[0]
		var giro: float = lugar[1]
		var pegada := _pegada(onde, giro, medida)
		if not _cabe(pegada, false):
			continue
		var peca := _peca(chave, onde, giro, tamanho)
		if peca == null:
			return null
		_colisao_da_peca(peca, chave.capitalize())
		_ultimo = onde
		_tomado.append(pegada)
		return peca
	return null


# --- as obras da casa ------------------------------------------------------------

## A OBRA DESTA CASA ESTÁ FEITA? Só a herdada, que é a do jogador, tem obras: as
## outras são de quem mora e já vêm como são.
func _feita(obra: String) -> bool:
	return perfil == "herdada" and Obras.ja_feita(CONSTRUCAO, obra)


## As obras de mobília que a casa mostra agora, numa linha só: é por ela que se
## sabe se o que está posto ainda vale.
func _assinatura_das_obras() -> String:
	if perfil != "herdada":
		return ""
	var feitas: Array = []
	for obra in Obras.tudo_da(CONSTRUCAO):
		if str(obra).begins_with("mobilia_"):
			feitas.append(str(obra))
	feitas.sort()
	return ",".join(feitas)


func _ao_mudar_as_obras() -> void:
	if is_inside_tree() and _assinatura_das_obras() != _obras_mostradas:
		_refazer_os_moveis()


## TIRA OS MÓVEIS E PÕE DE NOVO, com as obras de agora. A arquitetura (parede,
## chão, telha, janela) fica; saem os nós que os móveis puseram, com os corpos,
## as chamas e o registro deles.
func _refazer_os_moveis() -> void:
	for no in _nos_dos_moveis:
		if not is_instance_valid(no):
			continue
		for corpo in no.find_children("*", "StaticBody3D", true, false):
			_corpos.erase((corpo as StaticBody3D).get_rid())
		if no is OmniLight3D:
			_velas.erase(no)
		remove_child(no)
		no.queue_free()
	_moveis.clear()
	_montar_moveis()
	for no in _nos_dos_moveis:
		if no is VisualInstance3D and not (no is Light3D):
			(no as VisualInstance3D).layers = CAMADA_DO_COMODO
		_por_na_camada(no)


# --- os móveis de cada casa ----------------------------------------------------------

## A CASA DO FINADO, que é a do jogador: SÓ O BÁSICO, e o resto pelas obras.
##
## "Lembre-se que pode implementar no futuro a compra de expansões e melhorias da
## casa. Logo não precisa ter tudo no início, apenas o básico. Cada expansão e
## melhoria deve dar XP ao jogador e melhorar atributos do personagem."
##
## O básico é o que o 2D põe na casa no primeiro dia ("Cama, baú e fogão de
## barro. É o que tem, e é o que basta pra começar"), com o fogo do lado de
## fora: a fogueira do terreiro é o fogão da casa até a cozinha ter lugar. Ficam
## a CAMA e o BAÚ no fundo, a ÁGUA (o pote, com a moringa) e a LAMPARINA.
##
## O resto é obra da casa (`data/construcoes/obras.json`, alvo "casa"), e cada
## obra já paga XP e atributo ao ser feita (`Obras.executar` e `ATRIBUTOS`):
##
##   mobilia_mesa_grande   a mesa debaixo da janela, com o banco
##   mobilia_altar         o oratório na parede
##   mobilia_guardado      a estante (o jirau) na parede do fundo
##   mobilia_cozinha       o fogão de barro e o barril, no canto do fundo
##   mobilia_rede          a rede no lugar da cama
##
## As de casca e de planta (a varanda, o sobrado, o quarto, o salão, o assoalho)
## e o tapete ainda não mudam o cômodo: a casca do Tripo é uma só, e o tapete não
## tem modelo.
func _moveis_da_herdada() -> void:
	# A DORMIDA, no fundo, com a cabeceira na parede da esquerda (ou da direita,
	# se a esquerda não couber). Com a obra da rede, a rede no mesmo canto.
	var fundo := -comprimento + CAMA.z * 0.5 + 0.05
	var cantos := [[Vector3(-largura * 0.5 + CAMA.x * 0.5 + 0.05, 0.0, fundo), 0.0],
		[Vector3(largura * 0.5 - CAMA.x * 0.5 - 0.05, 0.0, fundo), 0.0]]
	var dormida: Node3D = null
	if _feita("mobilia_rede"):
		dormida = _por("rede", cantos, Vector3(CAMA.x, 1.0, CAMA.z), false)
	if dormida == null:
		_por("cama", cantos, CAMA, true)
	_cama = _ultimo if _ultimo.is_finite() else cantos[0][0]
	# O BAÚ ao lado dela, no fundo, do lado da sala; ou ao pé dela, na parede.
	var lado := 1.0 if _cama.x < 0.0 else -1.0
	var parede := -largura * 0.5 if lado > 0.0 else largura * 0.5
	_por("bau", [
		[Vector3(_cama.x + lado * (CAMA.x * 0.5 + 0.2 + BAU.x * 0.5), 0.0, -comprimento + BAU.z * 0.5 + 0.05), 0.0],
		[Vector3(parede + lado * (BAU.z * 0.5 + 0.05), 0.0, _cama.z + CAMA.z * 0.5 + 0.1 + BAU.x * 0.5), PI * 0.5],
	], BAU, true)
	_bau = _ultimo if _ultimo.is_finite() else _cama
	# A ÁGUA, à esquerda da entrada: o pote no chão, a moringa do lado.
	var agua := _por_peca("pote", [
		[Vector3(porta_x - largura_da_porta * 0.5 - FOLGA_DA_PORTA - 0.3, 0.0, -0.35), 0.0],
		[Vector3(-largura * 0.5 + 0.3, 0.0, -comprimento * 0.5), 0.0],
	], 0.6, Vector3(0.5, 0.6, 0.5))
	var onde_da_agua := _ultimo
	# A MESA (obra), debaixo da janela, com o banco na frente.
	var mesa := Vector3(-largura * 0.5 + MESA.x * 0.5 + 0.15, 0.0, -MESA.z * 0.5 - 0.1)
	var tem_mesa := false
	if _feita("mobilia_mesa_grande"):
		tem_mesa = _por("mesa", [[mesa, 0.0]], MESA, false) != null
		if tem_mesa:
			_por("banco_tosco", [[mesa + Vector3(0, 0, -MESA.z * 0.5 - 0.35), 0.0]], Vector3(1.0, 0.45, 0.32), false)
	# A LAMPARINA na mesa, ou em cima do baú; a moringa na mesa, ou junto do pote.
	var lamparina := mesa + Vector3(0.25, MESA.y, 0.0) if tem_mesa else _bau + Vector3(0.2, BAU.y, 0.0)
	_peca("candeeiro", lamparina, 0.0, 0.45)
	_vela("Lamparina", lamparina + Vector3(0, 0.45, 0.05), maxf(largura, comprimento) * 0.9, 1.1)
	if tem_mesa:
		_peca("moringa", mesa + Vector3(-0.25, MESA.y, 0.05), 0.4, 0.3)
	elif agua != null:
		_peca("moringa", onde_da_agua + Vector3(0.0, 0.0, -0.4), 0.4, 0.3)
	# O ORATÓRIO (obra), na parede da esquerda.
	if _feita("mobilia_altar"):
		_por("oratorio", [
			[Vector3(-largura * 0.5 + 0.18, 1.25, -comprimento * 0.5), PI * 0.5],
			[Vector3(largura * 0.5 - 0.18, 1.25, -comprimento * 0.5), -PI * 0.5],
		], Vector3(0.45, 0.6, 0.3), false)
	# A ESTANTE (obra), o jirau na parede do fundo, por cima do baú.
	if _feita("mobilia_guardado"):
		_por("jirau", [
			[Vector3(_bau.x, 1.5, -comprimento + 0.22), 0.0],
			[Vector3(-largura * 0.5 + 0.22, 1.5, -comprimento * 0.5), PI * 0.5],
		], Vector3(1.2, 0.6, 0.4), false)
	# O CANTO DA COZINHA (obra): o fogão no canto do fundo, de lado, com a boca
	# para a sala, e o barril d'água onde couber.
	if _feita("mobilia_cozinha"):
		# Do lado do baú, que é o da sala: longe da cabeceira.
		var do_outro_lado := lado
		var parede_da_cozinha := largura * 0.5 * lado
		_por("fogao_barro", [
			[Vector3(parede_da_cozinha - do_outro_lado * 0.4, 0.0, -comprimento + 0.55), -PI * 0.5 * do_outro_lado],
			[Vector3(parede_da_cozinha - do_outro_lado * 0.6, 0.0, -comprimento + 0.4), 0.0],
		], Vector3(1.0, 0.8, 0.7), false)
		_por("barril", [
			[Vector3(-largura * 0.5 + 0.33, 0.0, -comprimento * 0.5), 0.0],
			[Vector3(parede_da_cozinha - do_outro_lado * 0.33, 0.0, -comprimento + 1.4), 0.0],
		], Vector3(0.55, 0.8, 0.55), false)


## A CASA DO PEDRO, pescador: a REDE de dormir de lado a lado no fundo, que
## pescador dorme de rede; o baú pequeno na parede da esquerda; o barril com o
## banco fazendo de mesa, e o candeeiro em cima; a água ao lado da entrada; a
## rede de pesca pendurada na parede e os remos no canto, onde couberem; o fogão
## no canto do fundo. Pouco móvel: pescador passa o dia no mar.
func _moveis_do_pescador() -> void:
	var rede := Vector3(0.0, 0.0, -comprimento + 0.5)
	_por("rede", [[rede, 0.0]], Vector3(minf(2.2, largura - 1.6), 1.0, 0.8), false)
	_cama = rede
	_por("bau", [[Vector3(-largura * 0.5 + 0.3, 0.0, -comprimento + 1.45), PI * 0.5]], Vector3(0.75, 0.45, 0.42), false)
	_bau = _ultimo if _ultimo.is_finite() else rede
	var barril := Vector3(-largura * 0.5 + 0.35, 0.0, -comprimento + 2.1)
	var o_barril := _por("barril", [[barril, 0.0], [Vector3(-largura * 0.5 + 0.35, 0.0, -1.0), 0.0]], Vector3(0.55, 0.8, 0.55), false)
	if o_barril != null:
		barril = _ultimo
		_por("banco_tosco", [[barril + Vector3(0.6, 0.0, 0.0), PI * 0.5]], Vector3(1.0, 0.45, 0.32), false)
	# O candeeiro EM CIMA do barril, na altura medida dele: o barril do Tripo tem
	# 0,72, e não os 0,8 de onde ele é pedido. Sem barril, em cima do baú.
	var apoio := barril if o_barril != null else _bau
	var topo := caixa_no_comodo(o_barril).end.y if o_barril != null else 0.45
	_peca("candeeiro", apoio + Vector3(0.0, topo, 0.0), 0.0, 0.45)
	_vela("Lamparina", apoio + Vector3(0.0, topo + 0.45, 0.05), maxf(largura, comprimento) * 0.9, 1.0)
	_por_peca("pote", [
		[Vector3(porta_x - largura_da_porta * 0.5 - FOLGA_DA_PORTA - 0.3, 0.0, -0.35), 0.0],
		[Vector3(-largura * 0.5 + 0.35, 0.0, -0.5), 0.0],
	], 0.6, Vector3(0.5, 0.6, 0.5))
	_por("rede_de_pesca", [
		[Vector3(largura * 0.5 - 0.2, 1.0, -comprimento + 1.3), -PI * 0.5],
		[Vector3(-largura * 0.5 + 0.2, 1.0, -1.0), PI * 0.5],
	], Vector3(1.2, 1.4, 0.4), false)
	_por("fogao_barro", [
		[Vector3(largura * 0.5 - 0.4, 0.0, -comprimento + 0.55), -PI * 0.5],
	], Vector3(1.0, 0.8, 0.7), false)
	_por("remos", [
		[Vector3(-largura * 0.5 + 0.25, 0.0, -0.75), PI * 0.5],
		[Vector3(largura * 0.5 - 0.25, 0.0, -comprimento + 1.75), -PI * 0.5],
	], Vector3(1.2, 1.7, 0.45), false)
	_por_peca("cesto", [
		[Vector3(-largura * 0.5 + 0.3, 0.0, -comprimento + 2.75), 0.6],
		[Vector3(largura * 0.5 - 0.3, 0.0, -comprimento + 1.3), 0.6],
	], 0.4, Vector3(0.4, 0.4, 0.4))


## A CASA DA DONA ZEFA, rezadeira, que mora com o neto: a CAMA dela no fundo,
## com a cabeceira na parede da esquerda, e o ORATÓRIO na parede do fundo, com a
## luz quente acesa; a REDE do Cosme armada ao comprido da parede da esquerda,
## longe da porta; o canto do REMÉDIO no fundo à direita — o barril, a gamela, o
## pilão e as ervas secando na parede, "que é onde o remédio se faz"; a mesa
## debaixo da janela e a cantareira ao lado da entrada; os cestos que ela trança
## onde couberem.
func _moveis_da_rezadeira() -> void:
	_cama = Vector3(-largura * 0.5 + CAMA.x * 0.5 + 0.05, 0.0, -comprimento + CAMA.z * 0.5 + 0.05)
	_por("cama", [[_cama, 0.0]], CAMA, false)
	var oratorio := Vector3(minf(_cama.x + CAMA.x * 0.5 + 0.6, largura * 0.5 - 0.6), 1.3, -comprimento + 0.18)
	if _por("oratorio", [[oratorio, 0.0]], Vector3(0.45, 0.6, 0.3), false) != null:
		# A luz quente do oratório, que a reza da casa não deixa apagar.
		_vela("LuzDoOratorio", oratorio + Vector3(0.0, -0.2, 0.3), 2.6, 0.5)
	# O REMÉDIO, no canto do fundo à direita.
	var direita := largura * 0.5
	_por("barril", [[Vector3(direita - 0.33, 0.0, -comprimento + 0.33), 0.0]], Vector3(0.55, 0.8, 0.55), false)
	_por("gamela", [[Vector3(direita - 1.0, 0.0, -comprimento + 0.3), 0.0]], Vector3(0.7, 0.25, 0.5), false)
	_por("pilao", [[Vector3(direita - 0.3, 0.0, -comprimento + 0.95), 0.0]], Vector3(0.4, 1.0, 0.4), false)
	_por("ervas_secando", [[Vector3(direita - 0.15, 1.75, -comprimento + 1.0), -PI * 0.5]], Vector3(1.4, 0.7, 0.3), false)
	# A REDE DO COSME, ao comprido da parede da esquerda, entre a cama e a mesa.
	var comprimento_da_rede := clampf(comprimento - CAMA.z - 1.2, 1.4, 2.2)
	_por("rede", [
		[Vector3(-largura * 0.5 + 0.4, 0.0, -comprimento + CAMA.z + 0.15 + comprimento_da_rede * 0.5), PI * 0.5],
	], Vector3(comprimento_da_rede, 1.0, 0.7), false)
	# A MESA debaixo da janela, com a lamparina; sem ela, a lamparina no oratório.
	var mesa := Vector3(-largura * 0.5 + MESA.x * 0.5 + 0.15, 0.0, -MESA.z * 0.5 - 0.1)
	var tem_mesa := _por("mesa", [[mesa, 0.0]], MESA, false) != null
	var lamparina := mesa + Vector3(0.25, MESA.y, 0.0) if tem_mesa else oratorio + Vector3(0.0, -0.35, 0.2)
	_peca("candeeiro", lamparina, 0.0, 0.45)
	_vela("Lamparina", lamparina + Vector3(0, 0.45, 0.05), maxf(largura, comprimento) * 0.8, 0.9)
	_por("cantareira", [
		[Vector3(porta_x - largura_da_porta * 0.5 - FOLGA_DA_PORTA - 0.35, 0.0, -0.3), 0.0],
	], Vector3(0.6, 0.9, 0.45), false)
	_por("fogao_barro", [[Vector3(direita - 0.4, 0.0, -comprimento + 1.75), -PI * 0.5]], Vector3(1.0, 0.8, 0.7), false)
	for i in 3:
		_por_peca("cesto", [
			[Vector3(-largura * 0.5 + 0.3, 0.0, -0.3 - 0.45 * float(i)), 0.4 * float(i)],
			[Vector3(direita - 0.3, 0.0, -comprimento + 1.5 + 0.45 * float(i)), 0.4 * float(i)],
		], 0.35 + 0.05 * float(i), Vector3(0.4, 0.4, 0.4))


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
