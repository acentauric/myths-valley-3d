extends Node3D
## A FAZENDA DO CONVITE E O DIA DELA (data/missoes_fazenda.json;
## docs/projeto/MISSOES_DO_2D.md, 4; o `Fazenda` do 2D, fatia 6.1, A IDA).
##
## O LUGAR fica do outro lado do rio grande, na ponta da Rua Principal, logo
## depois da ponte — escolhido no vale de hoje e revisado pelo autor. É o
## capítulo 6 ao pé da letra: o portão baixo de ferro fino entre dois pilares de
## pedra ("uns cinco metros de portão e não chega a um de altura"), a guarita de
## pedra velha ao lado, sem porta nem janela, o descampado de terra batida e o
## casarão no fundo, de frente para o portão, com a escadaria. Os três modelos são
## do Tripo (lotes de 05/10); o portão sai do gerador alto como os outros, e é
## achatado aqui à altura do capítulo.
##
## O DIA vem na manhã seguinte à fé escolhida, com a ponte de pé — a regra do
## vale, aprovada pelo autor (no 2D é também sem missão nenhuma aberta, e no vale
## correm frentes demais para isso valer). O arraial já está no pátio, nos
## banquinhos, entre as mesas cobertas e as cabras soltas; o Pedro vem à porta de
## casa — "acorda, que é hoje" — e conduz o jogador pela ponte até o portão. Lá
## ele fala do portão que não guarda nada, o escuro sobe e a voz do mundo conta a
## chegada (`narracao_do_vale.gd`); quando o escuro desce, os dois estão dentro do
## pátio, e o Pedro conduz até a escadaria. A fala dele fecha a fatia 6.1: o 2D
## para aqui. O vale segue na 6.2 (#114): o silêncio, as duas mulheres na
## escadaria, o chamado aos corajosos e o Pedro que vai; depois a subida, o salão
## redondo, a porta estreita e os cinco que voltam — e o Pedro, que fica. É o
## fim do capítulo 6 (`o_chamado_aos_corajosos`, `a_porta_estreita`).
##
## O que vai no save é da fila da fazenda, como acontecimentos dela: o dia marcado
## ("dia_da_fazenda"), o chamado na porta, o portão aberto, o pátio, e o arraial
## de volta para casa no dia seguinte.

const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")

## O portão, o pé da escadaria e o casarão, em metros a partir da praça.
const PORTAO_M := Vector3(480.0, 0.0, -1156.0)
const PATIO_M := Vector3(468.0, 0.0, -1252.0)
const CASARAO_M := Vector3(464.0, 0.0, -1296.0)
## As clareiras da fazenda na mata, em metros: o portão e a guarita, o pátio e o
## casarão (`world_builder._clareiras_das_frentes`).
const CLAREIRAS_M := [Vector2(480, -1156), Vector2(500, -1152), Vector2(472, -1192),
	Vector2(448, -1216), Vector2(496, -1216), Vector2(472, -1240), Vector2(440, -1292),
	Vector2(488, -1292), Vector2(464, -1320), Vector2(436, -1176), Vector2(508, -1184),
	Vector2(436, -1256), Vector2(504, -1256)]
## O portão do capítulo: a altura (o gerador o faz da altura de um homem e meio)
## e a grossura do corpo dele enquanto está fechado.
const ALTURA_DO_PORTAO := 1.1
## A guarita, a leste do portão, com a boca virada para a mata e não para a estrada.
const GUARITA := Vector3(5.6, 0.0, 0.6)
const GIRO_DA_GUARITA := PI * 0.5
## Do portão para dentro, onde o jogador e o Pedro ficam quando o escuro desce.
const ENTRADA := 3.5
## O descampado de terra batida: meia largura, e do portão até o pé da escadaria.
const MEIA_LARGURA_DO_PATIO := 9.0
## As cabras soltas no meio da gente.
const CABRAS := 3
const PASSEIO := Vector2(6.0, 7.0)
const PAUSA := 4.0
const PASSO := 0.7
## De quanto em quanto se confere o dia (a partida que volta do save).
const CONFERIR_A_CADA := 0.5
const ARQUIVO := "res://data/missoes_fazenda.json"
## As cabras andam com as pernas (o clipe de andar, na velocidade do chão), e não
## escorregam: `cabra_de_cena.gd`.
const CabraDeCena = preload("res://scripts/prototipo_3d/cabra_de_cena.gd")

var _mundo
var _vale
var _cadeia
var _portao := Vector3.INF
var _patio := Vector3.INF
var _casarao := Vector3.INF
var _corpo_do_portao: StaticBody3D = null
var _altura_do_portao := 0.0
var _festa: Node3D = null
var _cabras: Array[Node3D] = []
var _proximo_passeio: Array[float] = []
var _passeios: Array[Tween] = []
var _dia_montado := false
var _em_cena := false
var _conferir_em := 0.0
var _rng := RandomNumberGenerator.new()


func configurar(mundo, vale) -> void:
	_mundo = mundo
	_vale = vale
	_cadeia = (vale._cadeias as Dictionary).get("pedro_fazenda")
	add_to_group("fazenda")
	_portao = mundo.ancoras.get("Portão da fazenda", Vector3.INF)
	_patio = mundo.ancoras.get("Pátio da fazenda", Vector3.INF)
	_casarao = mundo.ancoras.get("Casarão", Vector3.INF)
	if not _portao.is_finite() or not _casarao.is_finite():
		return
	_rng.seed = 1888
	_levantar()
	if not Relogio.dia_comecou.is_connected(_ao_comecar_o_dia):
		Relogio.dia_comecou.connect(_ao_comecar_o_dia)
	acertar()


func _exit_tree() -> void:
	if Relogio.dia_comecou.is_connected(_ao_comecar_o_dia):
		Relogio.dia_comecou.disconnect(_ao_comecar_o_dia)


# --- o dia --------------------------------------------------------------------

## O DIA PODE VIR? A fé escolhida e a ponte de pé.
func pronta() -> bool:
	var cadeias: Dictionary = _vale._cadeias
	var ponte = cadeias.get("pedro_ponte")
	var fe = cadeias.get("pedro_fe")
	return ponte != null and ponte.acabou() and fe != null and fe.passou("fe_escolher")


## A altura do portão como ficou no vale (a do capítulo: menos de um de altura).
func altura_do_portao() -> float:
	return _altura_do_portao


func portao_aberto() -> bool:
	return _corpo_do_portao == null


func dia_marcado() -> bool:
	return _cadeia != null and _cadeia.aconteceu("dia_da_fazenda")


## Marca o dia da fazenda, que começa agora. É o que a manhã seguinte faz
## (`_ao_comecar_o_dia`); público para o portão chamar sem esperar a noite.
func marcar_o_dia() -> void:
	if _cadeia == null or dia_marcado():
		return
	_cadeia.registrar_evento("dia_da_fazenda")
	# O CARTÃO DO AMANHECER ("hoje é o dia da fazenda", `queda._lembretes_do_dia`) lê a
	# `Jornada`, e ninguém a marcava no 3D: o cartão nunca aparecia.
	Jornada.marcar()
	acertar()


func _ao_comecar_o_dia(_dia: int, _estacao: int, _ano: int) -> void:
	if _cadeia == null:
		return
	# O ARRAIAL VOLTA PARA CASA no dia seguinte ao da fazenda: o 2D para no pátio,
	# e o vale segue — os moradores têm as filas deles.
	if dia_marcado() and _cadeia.acabou() and not _cadeia.aconteceu("liberou"):
		_cadeia.registrar_evento("liberou")
		for morador in _moradores():
			morador.liberar()
			morador.ir_ao_posto_agora()
		return
	if pronta() and not dia_marcado():
		marcar_o_dia()


## A FAZENDA COMO O JOGO DIZ QUE ELA ESTÁ: o portão fechado até a chegada, a
## festa e o arraial no pátio desde o dia marcado, e a fila andando.
func acertar() -> void:
	if not _portao.is_finite():
		return
	var aberto: bool = _cadeia != null and _cadeia.aconteceu("portao")
	if aberto and _corpo_do_portao != null:
		_corpo_do_portao.queue_free()
		_corpo_do_portao = null
	elif not aberto and _corpo_do_portao == null:
		_corpo_do_portao = _corpo(Vector3(5.2, 1.4, 0.45), _portao + Vector3(0, 0.7, 0), "PortaoFechado")
	if not dia_marcado():
		return
	if not _dia_montado:
		_dia_montado = true
		_montar_a_festa()
		if not _cadeia.aconteceu("liberou"):
			_sentar_o_arraial()
		if not _cadeia.iniciado:
			_pedro_na_porta()
			_cadeia.comecar(1.0)


func _process(delta: float) -> void:
	_conferir_em -= delta
	if _conferir_em <= 0.0:
		_conferir_em = CONFERIR_A_CADA
		acertar()
		_ver_se_chama()
	_passear_as_cabras(delta)


## "ACORDA, QUE É HOJE": a fala longa do Pedro na caixa, uma vez, quando o jogador
## chega perto dele no passo da ida.
func _ver_se_chama() -> void:
	if _cadeia == null or not _cadeia.iniciado or _cadeia.aconteceu("chamou") or _em_cena:
		return
	if str(_cadeia.passo_atual().get("id", "")) != "fazenda_ida" or Dialogo.ocupado():
		return
	var pedro: Node3D = _vale.get("pedro")
	var jogador: Node3D = _vale.player
	if pedro == null or jogador == null or jogador.global_position.distance_to(pedro.global_position) > 5.0:
		return
	_cadeia.registrar_evento("chamou")
	Dialogo.falar(_nome_do_pedro(), _falas("chamado"))


## O PORTÃO SE ABRE (a `cena` do passo da ida): o Pedro fala do portão que não
## guarda nada, o escuro sobe e a voz do mundo conta a chegada; por trás do
## escuro o portão abre e os dois passam para dentro do pátio.
func o_portao_se_abre() -> void:
	if _em_cena or _cadeia == null:
		return
	_em_cena = true
	var espera_antes: float = _cadeia.espera
	_cadeia.espera = 1000.0
	var pedro: Node3D = _vale.get("pedro")
	var jogador: Node3D = _vale.player
	# Quem ficou para trás no caminho chega junto: o Pedro está no portão quando fala.
	if pedro != null and jogador != null and pedro.global_position.distance_to(jogador.global_position) > 6.0:
		pedro.global_position = _mundo.ground_position(jogador.global_position + Vector3(1.4, 0, 0.8), 0.05)
	await Dialogo.falar(_nome_do_pedro(), _falas("ida_fim"))
	var narracao = _vale.get("narracao")
	if jogador != null:
		jogador.set_physics_process(false)
	var por_tras := func() -> void:
		_cadeia.registrar_evento("portao")
		acertar()
		var dentro: Vector3 = _mundo.ground_position(_portao + Vector3(0, 0, -ENTRADA), 0.1)
		if jogador != null:
			jogador.teleportar(dentro, PI)
		if pedro != null:
			pedro.global_position = _mundo.ground_position(dentro + Vector3(1.3, 0, 0.3), 0.05)
	if narracao != null:
		narracao.escureceu.connect(por_tras, CONNECT_ONE_SHOT)
		narracao.narrar(_falas("narracao"))
		await narracao.terminou
	else:
		por_tras.call()
	if jogador != null:
		jogador.set_physics_process(true)
	_cadeia.espera = minf(espera_antes, 0.8) if espera_antes > 0.0 else 0.8
	_em_cena = false


## NO PÉ DA ESCADARIA (a `cena` do passo do pátio): a fala do Pedro que fecha a
## fatia — os avós nos banquinhos, as mesas cobertas, e quem apareceu.
func chegou_ao_patio() -> void:
	if _cadeia == null:
		return
	_cadeia.registrar_evento("patio")
	await Dialogo.falar(_nome_do_pedro(), _falas("chegada_fim"))


## O CHAMADO AOS CORAJOSOS (a `cena` do passo do chamado; #114, fatia 6.2 do
## capítulo 6): o silêncio, as duas mulheres no alto da escadaria, a fala da mais
## velha, os homens de pé — e o Pedro, que não fica para trás e chama o jogador
## (P3 do plano do 2D: a história é dele, e o jogador o acompanha).
func o_chamado_aos_corajosos() -> void:
	if _em_cena or _cadeia == null:
		return
	_em_cena = true
	var espera_antes: float = _cadeia.espera
	_cadeia.espera = 1000.0
	_cadeia.registrar_evento("corajosos")
	await _narrar(_falas("silencio"))
	await Dialogo.falar(_nome("anfitria"), _falas("chamado_aos_corajosos"))
	await _narrar(_falas("de_pe"))
	await Dialogo.falar(_nome_do_pedro(), _falas("pedro_vai"))
	_cadeia.espera = minf(espera_antes, 0.8) if espera_antes > 0.0 else 0.8
	_em_cena = false


## A PORTA ESTREITA (a `cena` do passo da porta; #114): a subida, o salão
## redondo, a fala da moça, as mulheres que cercam, a interrupção da mais velha
## ("só um"), a porta de onde vêm os gemidos, os cinco que voltam — e o Pedro,
## que fica. O capítulo 6 acaba aqui (P1 do plano do 2D: a sedução fica nas
## falas, nada de despir em cena); o 7 é a próxima fatia. O salão ainda não é um
## cômodo: a voz do mundo o conta, com o escuro.
func a_porta_estreita() -> void:
	if _em_cena or _cadeia == null:
		return
	_em_cena = true
	var espera_antes: float = _cadeia.espera
	_cadeia.espera = 1000.0
	_cadeia.registrar_evento("porta_estreita")
	await _narrar(_falas("subida"))
	await Dialogo.falar(_nome("moca"), _falas("desafio"))
	await _narrar(_falas("cerco"))
	await Dialogo.falar(_nome("anfitria"), _falas("so_um"))
	await _narrar(_falas("porta"))
	await Dialogo.falar(_nome_do_pedro(), _falas("pedro_fica"))
	_cadeia.espera = minf(espera_antes, 0.8) if espera_antes > 0.0 else 0.8
	_em_cena = false


## A voz do mundo conta, com o jogador parado, e devolve o corpo ao fim.
func _narrar(frases: Array) -> void:
	var narracao = _vale.get("narracao")
	if narracao == null or frases.is_empty():
		return
	var jogador: Node3D = _vale.player
	if jogador != null:
		jogador.set_physics_process(false)
	narracao.narrar(frases)
	await narracao.terminou
	if jogador != null:
		jogador.set_physics_process(true)


## O nome de quem fala, na língua do jogo ("anfitria", "moca").
func _nome(chave: String) -> String:
	return str(IdiomaMenu.campo(Jogo.dados(ARQUIVO).get(chave, {}), "nome", chave))


# --- quem está lá ---------------------------------------------------------------

func _moradores() -> Array:
	var lista: Array = []
	for morador in _vale.moradores:
		if is_instance_valid(morador) and morador.is_visible_in_tree() and morador.has_method("ir_ate"):
			lista.append(morador)
	return lista


## O ARRAIAL JÁ ESTÁ LÁ: cada morador num lugar dos bancos, de frente para a
## escadaria — "saiu gente de madrugada".
func _sentar_o_arraial() -> void:
	var lugares := _lugares_nos_bancos()
	var i := 0
	for morador in _moradores():
		if i >= lugares.size():
			break
		var lugar: Vector3 = lugares[i]
		morador.global_position = lugar + Vector3(0, 0.05, 0)
		morador.ir_ate(lugar)
		i += 1


func _lugares_nos_bancos() -> Array:
	var lugares: Array = []
	for fila in 2:
		for k in 5:
			var x := -4.8 + float(k) * 2.4
			lugares.append(_mundo.ground_position(_patio + Vector3(x, 0, 5.5 + float(fila) * 3.0)))
	return lugares


## O Pedro vem à porta de casa, do lado de fora, como na chegada.
func _pedro_na_porta() -> void:
	var pedro: Node3D = _vale.get("pedro")
	var interiores = _vale.get("interiores")
	if pedro == null or interiores == null:
		return
	var sala = interiores.sala_de("casa")
	if sala == null:
		return
	pedro.global_position = _mundo.ground_position(sala.lugar_de_esperar_fora(), 0.05)


func _nome_do_pedro() -> String:
	var pedro = _vale.get("pedro")
	return str(pedro.dados.get("nome", "Pedro")) if pedro != null else "Pedro"


## As falas de uma lista do arquivo da fazenda, na língua do jogo.
func _falas(chave: String) -> Array:
	var linhas: Array = []
	for fala in (Jogo.dados(ARQUIVO).get(chave, []) as Array):
		linhas.append(str(IdiomaMenu.campo(fala, "texto", "")))
	return linhas


# --- o lugar ----------------------------------------------------------------------

func _levantar() -> void:
	# O PORTÃO, achatado à altura do capítulo e assentado no chão.
	var portao := CatalogoAssets.instanciar("portao_fazenda", self, _portao, 1.0, 0.0)
	if portao != null and portao.has_meta("limites"):
		var limites: AABB = portao.get_meta("limites")
		var fator := ALTURA_DO_PORTAO / maxf(limites.size.y, 0.01)
		portao.position.y += limites.position.y * (1.0 - fator)
		portao.scale.y *= fator
		_altura_do_portao = limites.size.y * fator
	# A GUARITA, de pedra velha, ao lado.
	var na_guarita: Vector3 = _mundo.ground_position(_portao + GUARITA)
	var guarita := CatalogoAssets.instanciar("guarita_fazenda", self, na_guarita, 1.0, GIRO_DA_GUARITA)
	if guarita != null:
		CatalogoAssets.colisao("guarita_fazenda", guarita, self, na_guarita, 1.0, GIRO_DA_GUARITA)
	# O CASARÃO, de frente para o portão, com a escadaria.
	var casarao := CatalogoAssets.instanciar("casarao_fazenda", self, _casarao, 1.0, 0.0)
	if casarao != null:
		var corpo := CatalogoAssets.colisao("casarao_fazenda", casarao, self, _casarao, 1.0, 0.0)
		# REGISTRADO COMO AS OUTRAS CONSTRUÇÕES do vale (`world.construcoes` e a frente
		# em `ancoras`): é por aí que o `Interiores` o acha e abre por dentro, quando o
		# jogador chega perto — a caixa inteira sai e entram as paredes, a porta e a
		# escadaria de pedra (`interior_casarao.gd`). A frente é a +Z, na direção do portão.
		var construcoes = _mundo.get("construcoes")
		if construcoes is Dictionary:
			construcoes["Casarão"] = {"modelo": casarao, "colisao": corpo, "chave": "casarao_fazenda"}
		if not _mundo.ancoras.has("CasarãoFrente"):
			_mundo.ancoras["CasarãoFrente"] = Vector3.BACK
	# O DESCAMPADO DE TERRA BATIDA, do portão ao pé da escadaria.
	var regiao = _mundo.get("_region")
	if regiao != null and _mundo.has_method("_terreiro_material"):
		var de := _portao.z - 1.0
		var ate := _patio.z - 1.0
		var meio := (_portao.x + _patio.x) * 0.5
		var cantos := PackedVector2Array([Vector2(meio - MEIA_LARGURA_DO_PATIO, de), Vector2(meio + MEIA_LARGURA_DO_PATIO, de),
			Vector2(meio + MEIA_LARGURA_DO_PATIO, ate), Vector2(meio - MEIA_LARGURA_DO_PATIO, ate)])
		regiao._add_polygon("Terreiro da fazenda", cantos, 0.03, Color("958d79"), false, _mundo._terreiro_material())


## A FESTA: as mesas compridas, cobertas, os banquinhos e as cabras soltas.
func _montar_a_festa() -> void:
	_festa = Node3D.new()
	_festa.name = "Festa"
	add_child(_festa)
	var pano := StandardMaterial3D.new()
	pano.albedo_color = Color(0.9, 0.87, 0.8)
	pano.roughness = 1.0
	for lado in [-1.0, 1.0]:
		var centro: Vector3 = _mundo.ground_position(_patio + Vector3(lado * 6.5, 0, 9.0))
		var mesa := MeshInstance3D.new()
		var caixa := BoxMesh.new()
		caixa.size = Vector3(1.5, 0.8, 7.0)
		mesa.mesh = caixa
		mesa.material_override = pano
		_festa.add_child(mesa)
		mesa.global_position = centro + Vector3(0, 0.4, 0)
		_corpo(Vector3(1.5, 0.8, 7.0), centro + Vector3(0, 0.4, 0), "MesaColisao").reparent(_festa)
	for lugar: Vector3 in _lugares_nos_bancos():
		CatalogoAssets.instanciar("banco", _festa, lugar + Vector3(0, 0, 0.55), 0.6, 0.0)
	for i in CABRAS:
		var cabra: Node3D = CabraDeCena.new()
		_festa.add_child(cabra)
		cabra.global_position = _ponto_no_patio()
		cabra.rotation.y = _rng.randf() * TAU
		_cabras.append(cabra)
		_proximo_passeio.append(_rng.randf() * PAUSA)
		_passeios.append(null)


func _ponto_no_patio() -> Vector3:
	var meio := Vector3((_portao.x + _patio.x) * 0.5, 0, (_portao.z + _patio.z) * 0.5)
	return _mundo.ground_position(meio + Vector3(_rng.randf_range(-PASSEIO.x, PASSEIO.x), 0, _rng.randf_range(-PASSEIO.y, PASSEIO.y)))


func _passear_as_cabras(delta: float) -> void:
	for i in _cabras.size():
		var cabra := _cabras[i]
		if not is_instance_valid(cabra):
			continue
		_proximo_passeio[i] -= delta
		if _proximo_passeio[i] > 0.0:
			continue
		_proximo_passeio[i] = PAUSA + _rng.randf() * PAUSA
		# Ainda no passeio de antes: espera o próximo.
		if _passeios[i] != null and _passeios[i].is_running():
			continue
		var destino := _ponto_no_patio()
		var rumo := destino - cabra.global_position
		rumo.y = 0.0
		var andando := create_tween()
		if rumo.length() > 0.05:
			andando.tween_callback(CabraDeCena.parar_se_for.bind(cabra))
			andando.tween_property(cabra, "rotation:y", atan2(rumo.x, rumo.z), 0.3)
		andando.tween_callback(CabraDeCena.andar_se_for.bind(cabra, PASSO))
		andando.tween_property(cabra, "global_position", destino, maxf(rumo.length() / PASSO, 0.3))
		andando.tween_callback(CabraDeCena.parar_se_for.bind(cabra))
		_passeios[i] = andando


func _corpo(tamanho: Vector3, onde: Vector3, nome: String) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	corpo.name = nome
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = tamanho
	forma.shape = caixa
	corpo.add_child(forma)
	add_child(corpo)
	corpo.global_position = onde
	return corpo
