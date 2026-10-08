extends Node
## AS FALAS DO VIAJANTE (#187): o personagem do jogador deixa de ser mudo.
##
## Todos ao redor falavam — o Pedro conduz, os moradores comentam — e o viajante nunca reagia ao que
## acontecia com ele. Aqui ele ganha comentários curtos, ditos para si mesmo, SÓ EM VOZ: nenhum balão,
## nenhuma caixa de fala, nada na tela (`data/falas_viajante.json`, o texto pt/en/es/zh fica guardado lá
## para a legenda de um dia e para o tests/idiomas.gd).
##
##
## OS GATILHOS (o `_pedir("...")` de cada um; o portão tests/falas_do_viajante.gd confere a lista)
##
##   desceu_do_saveiro   saiu do convés do saveiro da chegada para o píer
##   cansou_correndo     o vigor zerou no esforço (a corrida, o pulo), em terra
##   entrou_no_mar       começou a nadar (`nado_mudou`)
##   entrou_em_casa      entrou na casa herdada (`Interiores.entrou`)
##   primeira_noite      a noite caiu e ele está do lado de fora
##   mochila_cheia       não coube o que ele quis guardar (`Inventario.sem_espaco`)
##   sem_ferramenta      bateu num alvo sem a ferramenta (`Recursos3D.sem_ferramenta`)
##   primeira_colheita   colheu na lavoura
##   chuva_comecando     a estação das chuvas (o inverno do `Relogio`, ver `Venda.ESTACAO`) começou: ele
##                       acorda no primeiro dia dela e diz que lá vem a chuva
##   perto_do_escuro     de noite, perto do cemitério ou dentro da mata fechada
##
## E O SONO E O DESPERTAR, com variações (`sono` e `despertar` no arquivo): ao deitar na cama, ao
## desmaiar de cansaço e ao bater o sono (a reserva baixa de noite), e ao acordar, quando a tela clareia.
## A variação nunca repete a anterior do mesmo grupo, e a que só vale num contexto (`quando`: o corpo
## `cansado`, a `chuva` do inverno, a `madrugada` de quem dormiu tarde) tem a prioridade sobre as comuns.
##
##
## QUANDO FALA
##
## O gatilho PEDE a fala (`_pedir`), e ela sai quando a palavra está livre: nunca por cima da narração,
## da caixa de fala, do Pedro nem de outro morador — a vez é da fila de falas (`fila_de_falas.gd`, classe
## PASSAGEM, a que não fura ninguém), e enquanto o Pedro tem o anúncio de um passo a anunciar ele passa
## na frente. O pedido vence em alguns segundos: o "Água morna" não sai com o jogador já em terra.
## Duas falas não saem coladas (`pausa` do arquivo; o sono e o despertar ficam de fora, que têm a tela
## deles), a `uma_vez` vai no save e as outras só voltam depois do `intervalo`.
## O volume é o de "Falas dos personagens" (Ajustes). Sem o arquivo de voz a fala fica muda e NÃO conta
## como dita: ela sai quando o áudio existir.

const FilaDeFalas = preload("res://scripts/prototipo_3d/fila_de_falas.gd")
const IdiomaMenu = preload("res://scripts/prototipo_3d/idioma_menu.gd")

const ARQUIVO := "res://data/falas_viajante.json"
const PASTA_VOZES := "res://assets/audio/vozes/"
## Entre duas falas do viajante (fora o sono e o despertar), no mínimo isto, em segundos de relógio.
const PAUSA_PADRAO := 20.0
## Um pulso a cada quanto: pedidos pendentes e as medidas por perto.
const PULSO := 0.25
## Do convés, mais longe que isto é ter descido; mais perto que aquilo é estar nele.
const NO_CONVES := 3.5
const DESCEU_DO_CONVES := 6.0
## A que distância do cemitério ele sente o arrepio, de noite.
const PERTO_DO_CEMITERIO := 14.0
## O vigor que conta como zerado, e o que o reabilita para uma próxima vez (a fração do máximo).
const VIGOR_ZERADO := 0.02
const VIGOR_RECUPERADO := 0.2
## A estação das chuvas: o inverno do `Relogio.Estacao`, o 3 da tabela de `Venda.ESTACAO`.
const ESTACAO_DAS_CHUVAS := 3
## A voz do viajante sai um pouco abaixo da dos outros: é um resmungo, e não uma fala para alguém.
const ABAFO_DB := -3.0

var _dados: Dictionary = {}
var _jogador: Node3D
var _mundo: Node
var _guia: Node
var _saveiro: Node
var _interiores: Node
var _voz: AudioStreamPlayer
## Chave do pedido -> {"fala": Dictionary, "ate": ms, "grupo": ""}. A chave é o gatilho, ou "sono"/"despertar".
var _pedidos: Dictionary = {}
## Gatilho -> true: o que era `uma_vez` e já foi dito (vai no save).
var _ditas: Dictionary = {}
## Gatilho -> quando foi dita pela última vez (ms): o `intervalo`.
var _quando: Dictionary = {}
var _ultima_ms := -1000000
## Grupo ("sono", "despertar") -> o áudio da última variação, para a próxima não repetir.
var _ultima_do_grupo: Dictionary = {}
## A fala no ar: {"fala": Dictionary, "grupo": String}.
var _no_ar: Dictionary = {}
var _relogio_do_pulso := 0.0
var _viu_o_conves := false
var _vigor_zerado := false
## Entre o "deitou" e o "acordou" da noite (`queda.gd`): os outros gatilhos calam, e ele sabe com que corpo deitou.
var _dormindo := false
var _dormiu_tarde := false
var _deitou_cansado := false
## Quem caiu (a vida no chão) acorda com a explicação do que houve na tela, e o viajante cala.
var _caiu := false
## O inverno começou durante o sono: de manhã ele diz que lá vem a chuva.
var _chuva_virou := false
var _dia_do_sono := -1
## Só para o portão: uma voz que vale no lugar do arquivo (que pode não existir ainda).
var voz_de_prova: AudioStream = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_voz = AudioStreamPlayer.new()
	_voz.name = "Voz"
	add_child(_voz)
	_aplicar_volume()
	Audio.volumes_alterados.connect(_aplicar_volume)
	Dia.periodo_mudou.connect(_ao_mudar_o_periodo)
	Relogio.estacao_mudou.connect(_ao_mudar_a_estacao)
	Inventario.sem_espaco.connect(_ao_faltar_espaco)
	Energia.cansou.connect(_ao_cansar)


func _exit_tree() -> void:
	if Audio.volumes_alterados.is_connected(_aplicar_volume):
		Audio.volumes_alterados.disconnect(_aplicar_volume)
	if Dia.periodo_mudou.is_connected(_ao_mudar_o_periodo):
		Dia.periodo_mudou.disconnect(_ao_mudar_o_periodo)
	if Relogio.estacao_mudou.is_connected(_ao_mudar_a_estacao):
		Relogio.estacao_mudou.disconnect(_ao_mudar_a_estacao)
	if Inventario.sem_espaco.is_connected(_ao_faltar_espaco):
		Inventario.sem_espaco.disconnect(_ao_faltar_espaco)
	if Energia.cansou.is_connected(_ao_cansar):
		Energia.cansou.disconnect(_ao_cansar)


## Liga o viajante ao vale: o jogador (e os sinais dele), o Pedro, o saveiro, os cômodos, a lavoura, os
## alvos de trabalho e a noite (`queda.gd`). Qualquer um pode faltar (um portão que monta uma peça só).
func configurar(jogador: Node3D, mundo: Node, guia: Node, saveiro: Node, interiores: Node, lavoura: Node,
		recursos: Node, noite: Node) -> void:
	_jogador = jogador
	_mundo = mundo
	_guia = guia
	_saveiro = saveiro
	_interiores = interiores
	var lido = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
	_dados = lido if lido is Dictionary else {}
	if jogador != null:
		if jogador.has_signal("nado_mudou"):
			jogador.connect("nado_mudou", _ao_nadar)
		if jogador.has_signal("vigor_mudou"):
			jogador.connect("vigor_mudou", _ao_mudar_o_vigor)
	if interiores != null and interiores.has_signal("entrou"):
		interiores.connect("entrou", _ao_entrar)
	if lavoura != null and lavoura.has_signal("colheu"):
		lavoura.connect("colheu", _ao_colher)
	if recursos != null and recursos.has_signal("sem_ferramenta"):
		recursos.connect("sem_ferramenta", _ao_faltar_ferramenta)
	if noite != null:
		if noite.has_signal("deitou"):
			noite.connect("deitou", _ao_deitar)
		if noite.has_signal("acordou"):
			noite.connect("acordou", _ao_acordar)


## --- o que vai no save ----------------------------------------------------------------------------

## O que ele já disse de uma vez só, para a partida carregada não repetir a primeira colheita.
func estado_para_salvar() -> Dictionary:
	return {"ditas": _ditas.keys()}


func restaurar(guardado: Dictionary) -> void:
	_ditas.clear()
	for gatilho in guardado.get("ditas", []):
		_ditas[str(gatilho)] = true


## --- os dados ---------------------------------------------------------------------------------------

## A fala do gatilho (`falas` no arquivo), ou {}.
func fala_do_gatilho(gatilho: String) -> Dictionary:
	for fala in _dados.get("falas", []):
		if fala is Dictionary and str((fala as Dictionary).get("gatilho", "")) == gatilho:
			return fala
	return {}


## Sorteia a variação do grupo ("sono" ou "despertar"): entre as que valem no contexto, se há alguma que
## não seja a anterior, e senão entre as comuns; nunca a mesma duas vezes seguidas do grupo. `contextos`
## são os `quando` que valem agora, do que tem mais prioridade ao que tem menos.
func sortear(grupo: String, contextos: Array) -> Dictionary:
	var lista: Array = _dados.get(grupo, [])
	var anterior := str(_ultima_do_grupo.get(grupo, ""))
	for contexto in contextos:
		var certas: Array = []
		for fala in lista:
			if fala is Dictionary and str((fala as Dictionary).get("quando", "")) == str(contexto) \
					and str((fala as Dictionary).get("audio", "")) != anterior:
				certas.append(fala)
		if not certas.is_empty():
			return certas[randi() % certas.size()]
	var comuns: Array = []
	for fala in lista:
		if fala is Dictionary and str((fala as Dictionary).get("quando", "")) == "" \
				and str((fala as Dictionary).get("audio", "")) != anterior:
			comuns.append(fala)
	if comuns.is_empty():
		return {}
	return comuns[randi() % comuns.size()]


## Pode falar o gatilho? A `uma_vez` só uma vez por partida; a de `intervalo`, depois dele.
func _pode(gatilho: String) -> bool:
	var fala := fala_do_gatilho(gatilho)
	if fala.is_empty():
		return false
	if bool(fala.get("uma_vez", false)) and _ditas.has(gatilho):
		return false
	var intervalo := float(fala.get("intervalo", 0.0))
	if intervalo > 0.0 and _quando.has(gatilho) and Time.get_ticks_msec() - int(_quando[gatilho]) < int(intervalo * 1000.0):
		return false
	return true


func _stream_da(fala: Dictionary) -> AudioStream:
	if voz_de_prova != null:
		return voz_de_prova
	var nome := str(fala.get("audio", ""))
	var caminho := PASTA_VOZES + nome + ".mp3"
	return load(caminho) as AudioStream if nome != "" and ResourceLoader.exists(caminho) else null


func _aplicar_volume() -> void:
	if _voz != null:
		_voz.volume_db = Audio.volume_vozes_db() + ABAFO_DB


## --- os pedidos ---------------------------------------------------------------------------------------

## O gatilho disparou: pede a fala, que sai quando a palavra estiver livre e vence em `validade` segundos.
func _pedir(gatilho: String, validade: float) -> void:
	if _dormindo or _pedidos.has(gatilho) or not _pode(gatilho):
		return
	_pedidos[gatilho] = {"fala": fala_do_gatilho(gatilho), "ate": Time.get_ticks_msec() + int(validade * 1000.0), "grupo": ""}


## Pede uma variação do grupo, já escolhida. O sono e o despertar têm a tela deles: sem a pausa entre falas.
func _pedir_variacao(grupo: String, contextos: Array, validade: float) -> void:
	var fala := sortear(grupo, contextos)
	if fala.is_empty():
		return
	_pedidos[grupo] = {"fala": fala, "ate": Time.get_ticks_msec() + int(validade * 1000.0), "grupo": grupo}


func _process(delta: float) -> void:
	_relogio_do_pulso += delta
	if _relogio_do_pulso < PULSO:
		return
	_relogio_do_pulso = 0.0
	_vigiar_o_jogador()
	_atender_os_pedidos()


## Um pulso: diz uma das falas pedidas, se a palavra está livre; larga as vencidas e as que já não valem.
func _atender_os_pedidos() -> void:
	if _pedidos.is_empty():
		return
	var agora := Time.get_ticks_msec()
	for chave: String in _pedidos.keys():
		var pedido: Dictionary = _pedidos[chave]
		var grupo := str(pedido.get("grupo", ""))
		if agora > int(pedido["ate"]) or (grupo == "" and not _vale_agora(chave)):
			_pedidos.erase(chave)
		elif _dizer(pedido):
			_pedidos.erase(chave)
			return


## O gatilho ainda faz sentido neste instante? (O pedido fica esperando a palavra livre; a cena muda.)
func _vale_agora(gatilho: String) -> bool:
	if not _pode(gatilho) or _jogador == null:
		return false
	match gatilho:
		"entrou_no_mar":
			return bool(_jogador.get("_nadando"))
		"primeira_noite":
			return Dia.periodo() == "noite" and not _dentro_de_algum_comodo()
		"perto_do_escuro":
			return _perto_do_escuro()
	return true


## A palavra está livre para o viajante? Nada em tela cheia, nenhuma caixa de fala, ninguém falando (a fila
## de falas diz: o Pedro, um morador, a narração), e o Pedro sem passo a anunciar.
## O sono (`do_sono`) fala com o jogador já deitado: `queda.gd` desliga o physics_process dele logo depois do
## aviso, e isso não pode calar a fala.
func _palavra_livre(do_sono: bool = false) -> bool:
	if not is_inside_tree() or get_tree().paused or Dialogo.ocupado():
		return false
	if not do_sono and _jogador != null and not _jogador.is_physics_processing():
		return false
	var fila := FilaDeFalas.da(self)
	if fila != null and not fila.livre():
		return false
	return not _pedro_vai_anunciar()


## O Pedro tem o anúncio de um passo à espera (`_cadeia.espera`)? Ele passa na frente.
func _pedro_vai_anunciar() -> bool:
	if _guia == null or not is_instance_valid(_guia) or not ("_cadeia" in _guia):
		return false
	var cadeia = _guia.get("_cadeia")
	return cadeia != null and float(cadeia.get("espera")) > 0.0


## Diz a fala do pedido AGORA, se a palavra está livre. Devolve se disse (ou se o pedido deve sair da lista
## porque não há o que dizer). Sem o arquivo de voz, calado: não gasta a vez nem conta como dita.
func _dizer(pedido: Dictionary) -> bool:
	var fala: Dictionary = pedido["fala"]
	var grupo := str(pedido.get("grupo", ""))
	var fluxo := _stream_da(fala)
	if fluxo == null:
		return false
	var agora := Time.get_ticks_msec()
	var pausa := float(_dados.get("pausa", PAUSA_PADRAO))
	if grupo == "" and agora - _ultima_ms < int(pausa * 1000.0):
		return false
	if not _palavra_livre(grupo == "sono"):
		return false
	var fila := FilaDeFalas.da(self)
	if fila == null:
		_tocar({"fala": fala, "grupo": grupo, "fluxo": fluxo})
		_marcar(fala, grupo, agora)
		return true
	var texto := String(IdiomaMenu.campo(fala, "texto", ""))
	var id: int = fila.pedir({
		"falante": self, "texto": texto, "classe": FilaDeFalas.Classe.PASSAGEM,
		"segundos": FilaDeFalas.duracao(texto, fluxo.get_length()),
		"comecar": _comecou.bind(fala, grupo, fluxo), "parar": _parou, "suspender": _suspendeu.bind(grupo),
	})
	# O cumprimento de quem passa nunca espera: sem a vez livre a fila o descarta (id 0), e ele pede de novo.
	if id <= 0:
		return false
	_marcar(fala, grupo, agora)
	return true


## A fila deu a vez: a voz toca. NENHUM balão, NENHUMA caixa — é só a voz (#187).
func _comecou(_pedido: Dictionary, fala: Dictionary, grupo: String, fluxo: AudioStream) -> void:
	_tocar({"fala": fala, "grupo": grupo, "fluxo": fluxo})


func _tocar(no_ar: Dictionary) -> void:
	_no_ar = no_ar
	_voz.stop()
	_voz.stream = no_ar["fluxo"]
	_voz.stream_paused = false
	_voz.play()


func _parou(_pedido: Dictionary, cortada: bool) -> void:
	if cortada:
		_voz.stop()
	_no_ar = {}


## A caixa ou uma tela cobriu o vale: a voz pausa e volta de onde parou. O SONO NÃO: ele é dito no escuro da
## queda, e o cartão do amanhecer que para a árvore não pode cortar o "cama, me espera".
func _suspendeu(_pedido: Dictionary, sim: bool, grupo: String) -> void:
	if grupo == "sono":
		return
	_voz.stream_paused = sim


## Registra que a fala saiu: a pausa entre falas, a lembrança de `uma_vez`, o intervalo e a variação.
func _marcar(fala: Dictionary, grupo: String, agora: int) -> void:
	if grupo != "":
		_ultima_do_grupo[grupo] = str(fala.get("audio", ""))
		return
	var gatilho := str(fala.get("gatilho", ""))
	_ultima_ms = agora
	_quando[gatilho] = agora
	if bool(fala.get("uma_vez", false)):
		_ditas[gatilho] = true


## --- o que o jogador faz ---------------------------------------------------------------------------

## Medidas por perto, a cada pulso: ter descido do saveiro e o arrepio do cemitério e da mata.
func _vigiar_o_jogador() -> void:
	if _jogador == null or _dormindo:
		return
	_vigiar_o_conves()
	if Dia.periodo() in ["noite", "madrugada"] and _perto_do_escuro():
		_pedir("perto_do_escuro", 6.0)


## DESCEU DO SAVEIRO: no dia da chegada o jogador nasce no convés; mais de DESCEU_DO_CONVES metros dele, já
## desceu. Quem carrega um jogo com o saveiro longe nunca esteve no convés: não conta.
func _vigiar_o_conves() -> void:
	if _saveiro == null or not _saveiro.has_method("na_chegada") or not bool(_saveiro.call("na_chegada")) \
			or _ditas.has("desceu_do_saveiro"):
		return
	var conves: Vector3 = _saveiro.call("ponto_do_conves")
	if not conves.is_finite():
		return
	var longe := Vector2(_jogador.global_position.x - conves.x, _jogador.global_position.z - conves.z).length()
	if longe <= NO_CONVES:
		_viu_o_conves = true
	elif _viu_o_conves and longe >= DESCEU_DO_CONVES:
		_pedir("desceu_do_saveiro", 90.0)


func _perto_do_escuro() -> bool:
	if _jogador == null:
		return false
	if Lugares.perto_de("cemiterio", _jogador, PERTO_DO_CEMITERIO):
		return true
	return _mundo != null and _mundo.has_method("na_mata_fechada") and bool(_mundo.call("na_mata_fechada", _jogador.global_position))


func _dentro_de_algum_comodo() -> bool:
	return _interiores != null and _jogador != null and _interiores.has_method("contem") \
		and str(_interiores.call("contem", _jogador.global_position)) != ""


func _ao_nadar(nadando: bool) -> void:
	if nadando:
		_pedir("entrou_no_mar", 5.0)


## O vigor mudou: zerou no esforço (a corrida), em terra. Só uma vez até ele se recuperar.
func _ao_mudar_o_vigor(valor: float) -> void:
	var maximo := 1.0
	if _jogador != null and _jogador.has_method("vigor_maximo"):
		maximo = maxf(float(_jogador.call("vigor_maximo")), 1.0)
	var fracao := valor / maximo
	if fracao <= VIGOR_ZERADO:
		if not _vigor_zerado:
			_vigor_zerado = true
			if _jogador != null and not bool(_jogador.get("_nadando")):
				_pedir("cansou_correndo", 6.0)
	elif fracao >= VIGOR_RECUPERADO:
		_vigor_zerado = false


func _ao_entrar(qual: String) -> void:
	if qual == "casa":
		_pedir("entrou_em_casa", 6.0)


func _ao_mudar_o_periodo(periodo: String) -> void:
	if periodo == "noite":
		_pedir("primeira_noite", 90.0)


func _ao_faltar_espaco(_id: String) -> void:
	_pedir("mochila_cheia", 4.0)


func _ao_faltar_ferramenta(_ferramenta: String) -> void:
	_pedir("sem_ferramenta", 4.0)


func _ao_colher() -> void:
	_pedir("primeira_colheita", 20.0)


## O inverno, a estação das chuvas, começou. O dia só vira dormindo: de manhã, ao acordar, ele diz.
func _ao_mudar_a_estacao(estacao: int) -> void:
	if estacao == ESTACAO_DAS_CHUVAS:
		_chuva_virou = true


## A reserva do dia baixou: de noite, é o sono batendo. Uma vez por dia do calendário.
func _ao_cansar() -> void:
	if _dormindo or Dia.periodo() not in ["noite", "madrugada"] or _dia_do_sono == Relogio.dia_absoluto():
		return
	_dia_do_sono = Relogio.dia_absoluto()
	_pedir_variacao("sono", ["cansado"], 8.0)


## --- o sono e o despertar -------------------------------------------------------------------------

## A noite começou a virar, por uma das três portas (`queda.gd`): a cama, o desmaio das duas ou a queda.
## Quem caiu não fala (apagou machucado); quem deita ou desmaia diz o sono, no escuro.
func _ao_deitar(motivo: String) -> void:
	_dormindo = true
	_pedidos.clear()
	_dormiu_tarde = Dia.periodo() == "madrugada" or motivo == "desmaio"
	_caiu = motivo == "queda"
	_deitou_cansado = Energia.cansado() or motivo == "desmaio"
	if _caiu:
		return
	var contextos: Array = ["cansado"] if _deitou_cansado else []
	# Pedido com validade, não fala direta: ao deitar na cama o diálogo "Dormir?" acabou de fechar e ainda
	# conta como ocupado neste quadro; o pulso seguinte acha a palavra livre.
	_pedir_variacao("sono", contextos, 3.0)


## A tela clareou, o dia é novo: ele acorda. A manhã em que o inverno começou ele diz que lá vem chuva; senão,
## o corpo e o tempo escolhem a variação (a madrugada de quem dormiu tarde, a chuva do inverno). A fala espera
## a palavra livre (a explicação do desmaio, o Pedro) por alguns segundos.
func _ao_acordar() -> void:
	_dormindo = false
	if _chuva_virou:
		_chuva_virou = false
		_pedir("chuva_comecando", 40.0)
		return
	if _caiu:
		return
	var contextos: Array = []
	if _dormiu_tarde:
		contextos.append("madrugada")
	if Relogio.estacao == ESTACAO_DAS_CHUVAS:
		contextos.append("chuva")
	_pedir_variacao("despertar", contextos, 40.0)


